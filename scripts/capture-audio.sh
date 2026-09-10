#!/usr/bin/env bash
# capture-audio.sh — record what EmulationStation actually sends to the mixer
# while navigating es-theme-xmb-psp, using the same headless harness render.sh
# uses, then measure it with scripts/analyze-audio.py.
#
# Why this exists: every other capture in this harness is a screenshot, and a
# sound binding is invisible in one. A theme <sound> element ES never asks for
# reads exactly like a working one in the XML — the difference only shows up in
# the mixer's output. SDL's "disk" audio driver writes that output to a file
# instead of a device, so the harness can hear itself.
#
# Separate from render.sh rather than another flag on it, for the same reason
# record.sh is: the flag sets barely overlap (a key script and an expectation
# list here; aspect sweeps, battery fakes and frame bursts there).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
# shellcheck source=lib/theme-subsets.sh
source "${SCRIPT_DIR}/lib/theme-subsets.sh"

# Capturing adds no image content — SDL's disk driver is built into the SDL2
# the image already ships — so HARNESS_REV deliberately does not bump for this.
# shellcheck source=lib/harness-image.sh
source "${SCRIPT_DIR}/lib/harness-image.sh"

RESOLUTION="1024x768"
COLORSET="January Blue"
LIBRARY=""
OUT="${REPO_ROOT}/.dev/audio.raw"
WINDOW=1.5
EXPECT=""
# ES's own default is OFF (Settings.cpp:168) and a stock Brick does not carry
# the key, so "true" here is deliberately NOT the device's out-of-the-box state
# — it is the state in which a sound binding can be observed at all. Pass
# --enable-sounds false to capture what a stock device sounds like.
ENABLE_SOUNDS=true
ANALYSE=1
# Default sequence: three horizontal carousel moves, into a gamelist, three
# vertical moves, back out. That is exactly the horizontal-vs-vertical contrast
# the theme's navigation sounds are supposed to make audible.
SCRIPT_SPEC="right:2,right:2,right:2,confirm:3,down:2,down:2,down:2,back:2"

usage() {
  cat <<EOF
Usage: capture-audio.sh [--resolution WxH] [--colorset NAME] [--library PATH]
                        [--script SPEC] [--out FILE] [--window S]
                        [--expect LIST] [--no-analyse]

  --resolution  Xvfb geometry               (default: ${RESOLUTION})
  --colorset    PSP colorset name           (default: ${COLORSET})
  --library     path to a Knulli userdata-shaped library. Required for any
                script that enters a gamelist — which the default one does.
  --script SPEC comma-separated key:dwell steps. Keys are the closed set
                up, down, left, right, confirm, back, start, select; dwell is
                seconds
                and defaults to 2. Dwell must exceed the longest sound in
                sounds/ (back.wav is ~0.8s) or one event's audio spills into
                the next window.
                (default: ${SCRIPT_SPEC})
  --out FILE    host path for the capture    (default: .dev/audio.raw)
                The event manifest lands beside it as <out>.events.tsv.
  --window S    seconds after each keypress to examine  (default: ${WINDOW})
  --enable-sounds true|false
                pin ES's EnableSounds setting (default: true). ES defaults it
                to FALSE and a stock TrimUI Brick has no such key, so a user
                hears nothing until Menu > Sound Settings > "Enable Navigation
                Sounds" is turned on. Pass false to capture that stock state.
  --expect LIST comma-separated 'sound' / 'silence' / 'any', one per step.
                Non-zero exit on any mismatch — this is what makes the capture
                a test rather than a printout.
  --no-analyse  capture only; skip scripts/analyze-audio.py

The stream is signed 16-bit little-endian stereo at 44100 Hz. To listen to it:
  ffplay -f s16le -ar 44100 -ch_layout stereo .dev/audio.raw
EOF
  exit "${1:-0}"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --resolution) RESOLUTION="${2:?}"; shift 2 ;;
    --colorset)   COLORSET="${2:?}"; shift 2 ;;
    --library)    LIBRARY="${2:?}"; shift 2 ;;
    --script)     SCRIPT_SPEC="${2:?}"; shift 2 ;;
    --out)        OUT="${2:?}"; shift 2 ;;
    --window)     WINDOW="${2:?}"; shift 2 ;;
    --enable-sounds) ENABLE_SOUNDS="${2:?}"; shift 2 ;;
    --expect)     EXPECT="${2:?}"; shift 2 ;;
    --no-analyse) ANALYSE=0; shift ;;
    -h|--help)    usage 0 ;;
    *) echo "unknown argument: $1" >&2; usage 1 ;;
  esac
done

if [[ ! "${RESOLUTION}" =~ ^[0-9]+x[0-9]+$ ]]; then
  echo "bad --resolution: ${RESOLUTION} (expected WxH)" >&2; exit 2
fi
if [[ ! "${WINDOW}" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
  echo "bad --window: ${WINDOW} (expected a number of seconds)" >&2; exit 2
fi
if [[ "${ENABLE_SOUNDS}" != "true" && "${ENABLE_SOUNDS}" != "false" ]]; then
  echo "bad --enable-sounds: ${ENABLE_SOUNDS} (expected true or false)" >&2; exit 2
fi

# The colorset name reaches ES as a subset value, and ES silently falls back to
# the theme default when it cannot find one — so a typo would otherwise produce
# a perfectly good capture of the wrong palette.
valid_colorsets="$(subset_values colorset)"
if ! grep -Fxq -- "${COLORSET}" <<<"${valid_colorsets}"; then
  echo "bad --colorset: '${COLORSET}' is not a colorset." >&2
  echo "  valid values:" >&2
  sed 's/^/    /' <<<"${valid_colorsets}" >&2
  exit 2
fi

# Same silent-fallback rule for the env pins, and it bites harder here than in
# render.sh or record.sh: this tool's entire output is "did a sound play", so a
# mistyped style pin yields a confident measurement of the wrong style rather
# than a visibly wrong picture. record.sh shipped without these once and PR #58
# caught it; this is the same list.
check_pin GAMELIST_STYLE   gamelistStyle
check_pin ICON_SIZE        iconSize
check_pin TITLE_VISIBILITY titleVisibility
check_pin SCROLL_SPEED     scrollSpeed
check_pin BUTTON_GLYPHS    buttonGlyphs
check_bool SHOW_HELP
check_bool INVERT_BUTTONS

# Validated here as well as in the container so a typo costs a second rather
# than a two-minute run. xdotool swallows an unknown keysym, which would make a
# bad step a SILENT no-op — and silence is precisely what this tool measures,
# so an unvalidated script could report a missing sound that was really a
# missing keypress.
STEPS=0
ENTERS_GAMELIST=0
IFS=',' read -ra _steps <<< "${SCRIPT_SPEC}"
for _step in "${_steps[@]}"; do
  [[ -z "${_step}" ]] && continue
  _sym="${_step%%:*}"
  _wait="${_step#*:}"
  [[ "${_sym}" == "${_wait}" ]] && _wait=2
  case "${_sym}" in
    up|down|left|right|start|select|back) ;;
    confirm) ENTERS_GAMELIST=1 ;;
    *) echo "bad key '${_sym}' in step '${_step}' (expected up, down, left, right, confirm, back, start or select)" >&2; exit 2 ;;
  esac
  if [[ ! "${_wait}" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
    echo "bad dwell '${_wait}' in step '${_step}'" >&2; exit 2
  fi
  STEPS=$((STEPS + 1))
done
if (( STEPS == 0 )); then
  echo "--script has no steps" >&2; exit 2
fi
if (( ENTERS_GAMELIST == 1 )) && [[ -z "${LIBRARY}" ]]; then
  echo "--library is required: the script uses 'confirm', which enters a gamelist" >&2
  exit 2
fi
if [[ -n "${EXPECT}" ]]; then
  IFS=',' read -ra _want <<< "${EXPECT}"
  if (( ${#_want[@]} != STEPS )); then
    echo "--expect lists ${#_want[@]} outcomes but --script has ${STEPS} steps" >&2
    exit 2
  fi
fi

# Build the image on first use.
ensure_harness_image

mkdir -p "$(dirname "${OUT}")"
OUTDIR="$(cd "$(dirname "${OUT}")" && pwd)"
OUTNAME="$(basename "${OUT}")"
[[ "${OUTNAME}" == *.raw ]] || OUTNAME="${OUTNAME}.raw"

DOCKER_ARGS=(
  --rm
  -v "${REPO_ROOT}:/userdata/themes/es-theme-xmb-psp:ro"
  -v "${OUTDIR}:/harness-out"
)
HAS_LIBRARY=0
if [[ -n "${LIBRARY}" ]]; then
  LIBRARY_ABS="$(cd "${LIBRARY}" && pwd)"
  DOCKER_ARGS+=( -v "${LIBRARY_ABS}:/harness-library:ro" )
  HAS_LIBRARY=1
fi
DOCKER_ARGS+=(
  -e VIEW=audio -e RESOLUTION="${RESOLUTION}" -e COLORSET="${COLORSET}"
  -e OUTNAME="${OUTNAME}" -e HAS_LIBRARY="${HAS_LIBRARY}"
  -e AUDIO_SCRIPT="${SCRIPT_SPEC}" -e ENABLE_SOUNDS="${ENABLE_SOUNDS}"
  -e GAMELIST_STYLE="${GAMELIST_STYLE:-}" -e ICON_SIZE="${ICON_SIZE:-}"
  -e TITLE_VISIBILITY="${TITLE_VISIBILITY:-}" -e SCROLL_SPEED="${SCROLL_SPEED:-}"
  -e BUTTON_GLYPHS="${BUTTON_GLYPHS:-}" -e SHOW_HELP="${SHOW_HELP:-false}"
  -e INVERT_BUTTONS="${INVERT_BUTTONS:-true}"
)

docker run "${DOCKER_ARGS[@]}" "${IMAGE}" \
  bash /userdata/themes/es-theme-xmb-psp/docker/run-in-container.sh

CAPTURE="${OUTDIR}/${OUTNAME}"
echo "Saved ${CAPTURE} and ${CAPTURE%.raw}.events.tsv"

# ES's own record of which theme sound elements it asked for. This is the only
# view onto the "launch" and "menuOpen" bindings: both fire on transitions that
# reopen the audio device, which makes SDL's disk driver truncate and restart
# the capture file, so the PCM path cannot reach them. "(missing)" here is the
# signature of a <sound> element ES wants and the theme does not declare — and
# a name the theme declares that never appears at all is one ES never asks for.
ES_LOG="${CAPTURE%.raw}.es_log.txt"
if [[ -f "${ES_LOG}" ]]; then
  echo
  echo "sound elements ES requested from the theme:"
  # Each request is one line; ES logs "   (missing)" on the NEXT line when the
  # theme has no such element. awk pairs the two so a name is reported with its
  # outcome rather than the two being counted separately.
  awk '
    /req sound \[/ {
      name = $0; sub(/.*req sound \[/, "", name); sub(/\].*/, "", name)
      pending = name; count[name]++; total++; next
    }
    /\(missing\)/ && pending != "" { missing[pending]++; pending = "" ; next }
    { pending = "" }
    END {
      # A separate counter, not length(count): mawk and busybox awk do not
      # support length() on an array and abort with "attempt to use scalar".
      if (total == 0)
        print "  (none - LogLevel was not high enough, or ES asked for nothing)"
      for (n in count)
        printf "  %-24s %3d request(s)%s\n", n, count[n],
               (missing[n] ? "  <- MISSING from the theme" : "")
    }
  ' "${ES_LOG}" | sort
fi

if (( ANALYSE == 1 )); then
  ANALYSE_ARGS=( "${CAPTURE}" --window "${WINDOW}" )
  [[ -n "${EXPECT}" ]] && ANALYSE_ARGS+=( --expect "${EXPECT}" )
  python3 "${SCRIPT_DIR}/analyze-audio.py" "${ANALYSE_ARGS[@]}"
fi
