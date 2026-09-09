#!/usr/bin/env bash
# record.sh — record an animated GIF of es-theme-xmb-psp navigating, via the
# same headless harness render.sh uses. Its output is the README's showcase
# animation; it is a documentation tool, NOT a release gate: this renders via
# desktop GL21, the device via GLES2. See docker/README.md.
#
# Separate from render.sh rather than another flag on it: the flag sets barely
# overlap (fps, palette and a key script here; aspect sweeps, battery fakes and
# subset pins there) and render.sh is already 300 lines.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
# shellcheck source=lib/theme-subsets.sh
source "${SCRIPT_DIR}/lib/theme-subsets.sh"

# Recording adds no image content — the encode uses the ImageMagick the image
# already ships — so HARNESS_REV deliberately does not bump for this feature.
# shellcheck source=lib/harness-image.sh
source "${SCRIPT_DIR}/lib/harness-image.sh"

RESOLUTION="1280x720"
COLORSET="January Blue"
LIBRARY=""
FPS=10
WIDTH=640
COLORS=96
KEEP_FRAMES=0
OUT="${REPO_ROOT}/.dev/record.gif"
# Default sequence: dwell on the carousel long enough for the wave to move,
# walk several systems, drop into a gamelist, walk a few games, come back out.
# The wave's fastest layer loops every 12s, so a take much shorter than that
# shows almost no motion.
SCRIPT_SPEC="right:1.4,right:1.4,right:1.4,confirm:2.5,down:1.1,down:1.1,down:1.1,back:1.5,right:1.4"

usage() {
  cat <<EOF
Usage: record.sh [--resolution WxH] [--colorset NAME] [--library PATH]
                 [--fps N] [--script SPEC] [--width N] [--colors N]
                 [--out FILE] [--keep-frames]

  --resolution  Xvfb geometry            (default: 1280x720, 16:9)
  --colorset    PSP colorset name        (default: January Blue)
  --library     path to a Knulli userdata-shaped library. Required for any
                script that enters a gamelist.
  --fps N       requested capture rate   (default: 10). The measured harness
                ceiling is ~11fps at 1280x720 — 'import' costs ~90ms a frame.
                The GIF's delay is derived from the ACHIEVED rate, so asking
                for more than the harness can deliver slows the capture down
                rather than speeding the playback up.
  --script SPEC comma-separated 'key:seconds' steps driving navigation while
                the capture loop runs. The keys are a CLOSED set — up, down,
                left, right, start, confirm, back — not raw xdotool keysyms;
                see the note above RECORD_KEYS for why. 'confirm' and 'back'
                resolve through the same INVERT_BUTTONS logic every other view
                uses.
                (default: ${SCRIPT_SPEC})
  --width N     GIF output width in px   (default: 640, downscaled from the
                capture resolution)
  --colors N    GIF palette size, 2..256 (default: 96). The wave is a smooth
                gradient and is the first thing quantisation bands, so this was
                chosen by comparing encodes rather than by taste: measured on a
                139-frame take, 128 -> 64 colours saved only 5% (2.97MB ->
                2.81MB), because every pixel of the wave changes every frame
                and neither palette reduction nor frame-differencing has much
                to work with. Length and --width are the real size levers.
  --out FILE    host path for the GIF    (default: .dev/record.gif)
  --keep-frames retain the captured PNGs next to the GIF, for inspecting a
                take that navigated wrong
EOF
}

# Every --flag below dereferences $2. Under `set -u` a missing value dies with
# "$2: unbound variable" and exit 1, instead of the exit-2 usage error the rest
# of the argument handling is careful to give.
need_val() { # need_val <flag> <count-remaining>
  (( $2 >= 2 )) || { echo "bad $1: missing value" >&2; exit 2; }
}
while [[ $# -gt 0 ]]; do
  case "$1" in
    --resolution) need_val --resolution $#; RESOLUTION="$2"; shift 2 ;;
    --colorset) need_val --colorset $#; COLORSET="$2";   shift 2 ;;
    --library) need_val --library $#; LIBRARY="$2";    shift 2 ;;
    --fps) need_val --fps $#; FPS="$2";        shift 2 ;;
    --script) need_val --script $#; SCRIPT_SPEC="$2";shift 2 ;;
    --width) need_val --width $#; WIDTH="$2";      shift 2 ;;
    --colors) need_val --colors $#; COLORS="$2";     shift 2 ;;
    --out) need_val --out $#; OUT="$2";        shift 2 ;;
    --keep-frames) KEEP_FRAMES=1;   shift ;;
    -h|--help)     usage; exit 0 ;;
    *) echo "unknown argument: $1" >&2; usage >&2; exit 2 ;;
  esac
done

# Validated here as well as in the container so a typo costs a second rather
# than a container start. `^[0-9]+$` before any (( )) — a leading zero is
# OCTAL there, so --fps 08 would be a parse error rather than eight a second.
check_int() { # check_int <flag> <value> <min> <max>
  local flag="$1" val="$2" min="$3" max="$4"
  if [[ ! "${val}" =~ ^[0-9]+$ ]]; then
    echo "bad ${flag}: '${val}' — expected a non-negative integer" >&2; exit 2
  fi
  # A leading zero is ambiguous: bash reads it as OCTAL inside (( )), so
  # --fps 08 is a parse error and --colors 010 is eight, not ten. Rejecting it
  # outright beats guessing which the caller meant.
  if [[ "${val}" =~ ^0[0-9] ]]; then
    echo "bad ${flag}: '${val}' — leading zeros are ambiguous (octal in (( )))" >&2
    exit 2
  fi
  if (( 10#${val} < min || 10#${val} > max )); then
    echo "bad ${flag}: ${val} — expected ${min}..${max}" >&2; exit 2
  fi
}
check_int --fps    "${FPS}"    1  60
check_int --width  "${WIDTH}"  16 4096
check_int --colors "${COLORS}" 2  256

if [[ ! "${RESOLUTION}" =~ ^[0-9]+x[0-9]+$ ]]; then
  echo "bad --resolution: '${RESOLUTION}' — expected WxH, e.g. 1280x720" >&2
  exit 2
fi

# The colorset name reaches ES as a subset value, and ES silently falls back to
# the theme default when it cannot find one — so a typo would otherwise produce
# a perfectly good GIF of the wrong palette.
valid_colorsets="$(subset_values colorset)"
if ! grep -Fxq -- "${COLORSET}" <<<"${valid_colorsets}"; then
  echo "bad --colorset: '${COLORSET}' is not a colorset." >&2
  echo "  valid values:" >&2
  sed 's/^/    /' <<<"${valid_colorsets}" >&2
  exit 2
fi

if [[ -z "${SCRIPT_SPEC}" ]]; then
  echo "bad --script: empty. A recording with no navigation is a still." >&2
  exit 2
fi

# The script vocabulary is a closed set. xdotool keysyms are case-sensitive and
# the container's key() helper swallows an unknown one, so a typo would record
# a flawless GIF in which nothing navigates — which is exactly what the first
# take of this feature produced. Reject it here instead.
RECORD_KEYS="$(printf '%s\n' up down left right start confirm back)"
IFS=',' read -ra _steps <<< "${SCRIPT_SPEC}"
for _step in "${_steps[@]}"; do
  [[ -z "${_step}" ]] && continue
  _sym="${_step%%:*}"
  _wait="${_step#*:}"
  [[ "${_sym}" == "${_wait}" ]] && _wait=1
  # -Fxq against a newline-delimited list, matching the colorset check above.
  # `grep -qw` treated the key as a REGEX: "righ." and "r.ght" both passed
  # host-side validation and only died after a ~15s container boot, which
  # defeats the point of validating here at all.
  if ! grep -Fxq -- "${_sym}" <<<"${RECORD_KEYS}"; then
    echo "bad --script: unknown key '${_sym}' in step '${_step}'." >&2
    echo "  valid keys: $(tr '\n' ' ' <<<"${RECORD_KEYS}")" >&2
    exit 2
  fi
  if [[ ! "${_wait}" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
    echo "bad --script: '${_wait}' in step '${_step}' is not a number of seconds" >&2
    exit 2
  fi
done

# A script that enters a gamelist against no library records an empty list,
# which looks like a theme bug rather than a missing flag.
if [[ -z "${LIBRARY}" ]] && grep -q "confirm" <<<"${SCRIPT_SPEC}"; then
  echo "bad --script: it contains 'confirm' (enters a gamelist) but no" >&2
  echo "  --library was given, so the gamelist would record empty." >&2
  exit 2
fi

# render.sh validates these before every render; forwarding them unchecked put
# record.sh back in exactly the failure mode its own --colorset check exists to
# prevent. ES silently ignores an unknown subset value and falls back to the
# theme default, so GAMELIST_STYLE="Box Art Gird" produced a flawless
# several-minute GIF of the DEFAULT style, exit 0.
check_pin GAMELIST_STYLE   gamelistStyle
check_pin ICON_SIZE        iconSize
check_pin TITLE_VISIBILITY titleVisibility
check_bool SHOW_HELP
check_bool INVERT_BUTTONS
check_bool CLOCK_12H

# SHOW_BATTERY is render.sh's, not ours: it only does anything alongside the
# synthetic /sys/class/power_supply mount, which record.sh does not set up. The
# container has no battery, so the widget auto-hides and the setting renders
# nothing. Rejecting it beats honouring it in name only.
if [[ -n "${SHOW_BATTERY:-}" ]]; then
  echo "bad SHOW_BATTERY: record.sh has no --battery, so the status-bar" >&2
  echo "  battery would auto-hide and render nothing. Use render.sh for" >&2
  echo "  battery captures." >&2
  exit 2
fi

if (( FPS > 11 )); then
  echo "WARNING: --fps ${FPS} is above the measured harness ceiling (~11fps at" >&2
  echo "  1280x720; import costs ~90ms/frame). The GIF's delay is derived from" >&2
  echo "  the measured rate, so it will still play back at true speed." >&2
fi

# Build the image on first use.
if ! docker image inspect "${IMAGE}" >/dev/null 2>&1; then
  echo "Building ${IMAGE} (one-time, ~5-10 min)..."
  docker build -t "${IMAGE}" --build-arg ES_PIN="${ES_PIN}" "${REPO_ROOT}/docker"
fi

mkdir -p "$(dirname "${OUT}")"
OUTDIR="$(cd "$(dirname "${OUT}")" && pwd)"
OUTNAME="$(basename "${OUT}")"

HAS_LIBRARY=0
DOCKER_ARGS=(
  --rm
  -v "${REPO_ROOT}:/userdata/themes/es-theme-xmb-psp:ro"
  -v "${OUTDIR}:/harness-out"
)
if [[ -n "${LIBRARY}" ]]; then
  LIBRARY_ABS="$(cd "${LIBRARY}" && pwd)"
  DOCKER_ARGS+=( -v "${LIBRARY_ABS}:/harness-library:ro" )
  HAS_LIBRARY=1
fi
DOCKER_ARGS+=(
  -e VIEW=record -e RESOLUTION="${RESOLUTION}" -e COLORSET="${COLORSET}"
  -e OUTNAME="${OUTNAME}" -e HAS_LIBRARY="${HAS_LIBRARY}"
  -e RECORD_SCRIPT="${SCRIPT_SPEC}" -e RECORD_FPS="${FPS}"
  -e RECORD_WIDTH="${WIDTH}" -e RECORD_COLORS="${COLORS}"
  -e KEEP_FRAMES="${KEEP_FRAMES}"
  -e GAMELIST_STYLE="${GAMELIST_STYLE:-}" -e ICON_SIZE="${ICON_SIZE:-}"
  -e TITLE_VISIBILITY="${TITLE_VISIBILITY:-}"
  -e SHOW_HELP="${SHOW_HELP:-false}" -e INVERT_BUTTONS="${INVERT_BUTTONS:-true}"
  -e CLOCK_12H="${CLOCK_12H:-}"
)

docker run "${DOCKER_ARGS[@]}" "${IMAGE}" \
  bash /userdata/themes/es-theme-xmb-psp/docker/run-in-container.sh

echo "Saved ${OUT}"
