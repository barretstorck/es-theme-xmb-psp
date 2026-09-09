#!/usr/bin/env bash
# render.sh — render es-theme-xmb-psp via headless batocera-emulationstation in
# Docker and capture a screenshot. A development aid, NOT a release gate: this
# renders via desktop GL21, the device via GLES2. See docker/README.md.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Pinned Knulli batocera-emulationstation commit (must match docker/Dockerfile).
# HARNESS_REV is bumped whenever docker/ changes the image's contents: the build
# below only fires when the image is MISSING, so without a new tag everyone
# keeps silently running whatever they built first. r2 = VLC plugins + the
# parse patch, i.e. preview video actually plays.
ES_PIN="9bbb16a"
HARNESS_REV="r2"
IMAGE="es-xmb-harness:knulli-${ES_PIN}-${HARNESS_REV}"

VIEW="system"
RESOLUTION="1024x768"
COLORSET="January Blue"
LIBRARY=""
OUT="${REPO_ROOT}/.dev/render.png"
CAROUSEL_RIGHT=0
SETTLE=0
FRAMES=1
FRAME_INTERVAL=1
SPLASH_AT="${SPLASH_AT:-0.4}"

usage() {
  cat <<EOF
Usage: render.sh [--view V] [--resolution WxH] [--colorset NAME]
                 [--library PATH] [--out FILE]

  --view        system | gamelist | gamecarousel | menu | splash
                (default: system). "splash" is the boot splash: ES is launched
                WITHOUT the flag that suppresses it, and the frame is grabbed
                SPLASH_AT seconds in (default 0.4, and it must stay well under
                a second - the splash is gone by ~1s, so a larger default would
                quietly photograph the carousel instead). It is transient, so
                that moment is a race: smaller resolutions boot faster and need
                a smaller value. Use --frames to sweep if it lands wrong.
  --resolution  Xvfb geometry, e.g. 1024x768 (4:3) or 1280x720 (16:9)
  --colorset    PSP colorset name, e.g. "August Orange"   (default: January Blue)
  --library     path to a Knulli userdata-shaped library  (gamelist views need this)
  --out         host path for the captured PNG            (default: .dev/render.png)
  --carousel-right N  press Right N times on the system carousel. Selects which
                      system a --view system capture shows, and which gamelist
                      the other views enter  (default: 0 — the first system)
  --settle N    extra seconds to wait after navigating, before capturing. Video
                previews need this: the still shows for <delay> seconds first
                (default: 0)
  --frames N    capture N frames instead of one, --frame-interval seconds apart,
                to <out>-1.png .. <out>-N.png  (default: 1)
  --frame-interval S  seconds between frames when --frames > 1  (default: 1)

  Env pins (optional, empty = theme default):
    ICON_SIZE=Boxart|Compact
    TITLE_VISIBILITY="PSP-Faithful"|"With Titles"
    GAMELIST_STYLE="PSP Card"|"List + Details"|"Box Art Grid"
    SCROLL_SPEED=Normal|Slow|Fast
                (description auto-scroll cadence, ms per pixel step — larger
                 is slower. Scrolling starts after ES's 6s autoScrollDelay, so
                 pair with --settle 8 and --frames to see it move.)
    VIDEO_DELAY=Instant|"2 seconds"|"5 seconds"|"10 seconds"
                (unset pins "10 seconds", so a capture lands on the still —
                 see docker/run-in-container.sh)
    VIDEO_AUDIO=On|Off
    BUTTON_GLYPHS=PSP|Nintendo|Xbox
                (helpsystem face-button glyph set; needs SHOW_HELP=true to be
                 visible at all)
    SHOW_HELP=true|false
                (ES's bottom help strip. Default false, matching every render
                 taken before the glyph sets existed.)
    INVERT_BUTTONS=true|false
                (default true, matching the TrimUI Brick. Decides which theme
                 icon slot a prompt uses -- see docker/run-in-container.sh.)
EOF
  exit "${1:-0}"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --view)       VIEW="${2:?}"; shift 2 ;;
    --resolution) RESOLUTION="${2:?}"; shift 2 ;;
    --colorset)   COLORSET="${2:?}"; shift 2 ;;
    --library)    LIBRARY="${2:?}"; shift 2 ;;
    --out)        OUT="${2:?}"; shift 2 ;;
    --carousel-right) CAROUSEL_RIGHT="${2:?}"; shift 2 ;;
    --settle)     SETTLE="${2:?}"; shift 2 ;;
    --frames)     FRAMES="${2:?}"; shift 2 ;;
    --frame-interval) FRAME_INTERVAL="${2:?}"; shift 2 ;;
    -h|--help)    usage 0 ;;
    *) echo "unknown argument: $1" >&2; usage 1 ;;
  esac
done

case "${VIEW}" in
  system|gamelist|gamecarousel|menu|splash) ;;
  *) echo "bad --view: ${VIEW}" >&2; exit 2 ;;
esac
if [[ "${VIEW}" == gamelist || "${VIEW}" == gamecarousel ]] && [[ -z "${LIBRARY}" ]]; then
  echo "--library is required for --view ${VIEW}" >&2; exit 2
fi
if [[ ! "${RESOLUTION}" =~ ^[0-9]+x[0-9]+$ ]]; then
  echo "bad --resolution: ${RESOLUTION} (expected WxH)" >&2; exit 2
fi
for n in CAROUSEL_RIGHT SETTLE FRAMES; do
  if [[ ! "${!n}" =~ ^[0-9]+$ ]]; then
    echo "bad ${n}: ${!n} (expected a non-negative integer)" >&2; exit 2
  fi
  # Re-print base-10. `(( ))` reads a leading zero as OCTAL, so without this
  # `--frames 08` is a parse error the shell swallows into "capture one frame,
  # exit 0" and `--settle 08` skips the settle entirely.
  printf -v "${n}" '%d' "$((10#${!n}))"
done
# These two are only ever handed to `sleep`, never to `(( ))`, so they take
# fractions - and need to. The boot splash is on screen for well under a second
# in the harness, so an integer-only --frame-interval cannot sweep it at all:
# every frame of a back-to-back burst lands before ES has opened its window,
# and one second later the carousel has already replaced the splash.
for n in FRAME_INTERVAL SPLASH_AT; do
  if [[ ! "${!n}" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
    echo "bad ${n}: ${!n} (expected a non-negative number)" >&2; exit 2
  fi
done
if (( FRAMES < 1 )); then echo "--frames must be >= 1" >&2; exit 2; fi

# Env pins must name a real subset value, checked against theme.xml itself so
# this list cannot drift from the theme.
# ES silently ignores a subset value it cannot find and falls back to the
# theme's own default. For VIDEO_DELAY that is the difference between a
# deterministic capture and a random mid-playback frame, so a typo has to be
# an error here rather than a puzzling screenshot later.
subset_values() { # subset_values <subset-name>
  awk -v want="$1" '
    $0 ~ "<subset name=\"" want "\"" { inblk = 1; next }
    inblk && /<\/subset>/ { exit }
    inblk && match($0, /<include name="[^"]*"/) {
      print substr($0, RSTART + 15, RLENGTH - 16)
    }
  ' "${REPO_ROOT}/theme.xml"
}

check_pin() { # check_pin <env-var-name> <subset-name>
  local var="$1" subset="$2" val="${!1:-}" valid
  [[ -n "${val}" ]] || return 0            # empty = theme default, always fine
  valid="$(subset_values "${subset}")"
  if [[ -z "${valid}" ]]; then
    echo "bad ${var}: theme.xml declares no '${subset}' subset" >&2; exit 2
  fi
  if ! grep -Fxq -- "${val}" <<<"${valid}"; then
    echo "bad ${var}: '${val}' is not a value of the '${subset}' subset." >&2
    echo "  valid values:" >&2
    sed 's/^/    /' <<<"${valid}" >&2
    exit 2
  fi
}

check_pin ICON_SIZE        iconSize
check_pin TITLE_VISIBILITY titleVisibility
check_pin GAMELIST_STYLE   gamelistStyle
check_pin VIDEO_DELAY      videoDelay
check_pin VIDEO_AUDIO      videoAudio
check_pin SCROLL_SPEED     scrollSpeed
check_pin BUTTON_GLYPHS    buttonGlyphs

# These two are ES settings rather than theme subsets, so check_pin cannot
# validate them — but they are just as easy to get wrong, and both fail
# silently. A rejected value is better than a render that quietly shows the
# wrong thing. See the es_as_bool note in docker/run-in-container.sh for why
# only these two spellings are allowed through.
check_bool() { # check_bool <env-var-name>
  local var="$1" val="${!1:-}"
  [[ -z "${val}" ]] && return 0
  if [[ "${val}" != "true" && "${val}" != "false" ]]; then
    echo "bad ${var}: '${val}' — expected true or false" >&2; exit 2
  fi
}
check_bool SHOW_HELP
check_bool INVERT_BUTTONS

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
  -e VIEW="${VIEW}" -e RESOLUTION="${RESOLUTION}" -e COLORSET="${COLORSET}"
  -e OUTNAME="${OUTNAME}" -e HAS_LIBRARY="${HAS_LIBRARY}"
  -e GAMELIST_DOWN="${GAMELIST_DOWN:-0}"
  -e GAMELIST_RIGHT="${GAMELIST_RIGHT:-0}"
  -e ICON_SIZE="${ICON_SIZE:-}" -e TITLE_VISIBILITY="${TITLE_VISIBILITY:-}"
  -e GAMELIST_STYLE="${GAMELIST_STYLE:-}" -e SCROLL_SPEED="${SCROLL_SPEED:-}"
  -e VIDEO_DELAY="${VIDEO_DELAY:-}" -e VIDEO_AUDIO="${VIDEO_AUDIO:-}"
  -e BUTTON_GLYPHS="${BUTTON_GLYPHS:-}" -e SHOW_HELP="${SHOW_HELP:-false}"
  -e INVERT_BUTTONS="${INVERT_BUTTONS:-true}"
  -e CAROUSEL_RIGHT="${CAROUSEL_RIGHT}" -e SETTLE="${SETTLE}"
  -e FRAMES="${FRAMES}" -e FRAME_INTERVAL="${FRAME_INTERVAL}"
  -e SPLASH_AT="${SPLASH_AT}"
)

docker run "${DOCKER_ARGS[@]}" "${IMAGE}" \
  bash /userdata/themes/es-theme-xmb-psp/docker/run-in-container.sh

if (( FRAMES > 1 )); then
  echo "Saved ${OUT%.png}-1.png .. ${OUT%.png}-${FRAMES}.png"
else
  echo "Saved ${OUT}"
fi
