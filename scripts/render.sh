#!/usr/bin/env bash
# render.sh — render es-theme-xmb-psp via headless batocera-emulationstation in
# Docker and capture a screenshot. A development aid, NOT a release gate: this
# renders via desktop GL21, the device via GLES2. See docker/README.md.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Pinned Knulli batocera-emulationstation commit (must match docker/Dockerfile).
ES_PIN="9bbb16a"
IMAGE="es-xmb-harness:knulli-${ES_PIN}"

VIEW="system"
RESOLUTION="1024x768"
COLORSET="January Blue"
LIBRARY=""
OUT="${REPO_ROOT}/.dev/render.png"
CAROUSEL_RIGHT=0
VIDEO=0
SETTLE=0
FRAMES=1
FRAME_INTERVAL=1

usage() {
  cat <<EOF
Usage: render.sh [--view V] [--resolution WxH] [--colorset NAME]
                 [--library PATH] [--out FILE]

  --view        system | gamelist | gamecarousel | menu   (default: system)
  --resolution  Xvfb geometry, e.g. 1024x768 (4:3) or 1280x720 (16:9)
  --colorset    PSP colorset name, e.g. "August Orange"   (default: January Blue)
  --library     path to a Knulli userdata-shaped library  (gamelist views need this)
  --out         host path for the captured PNG            (default: .dev/render.png)
  --carousel-right N  press Right N times on the system carousel before entering
                      a gamelist  (default: 0 — the first system)
  --settle N    extra seconds to wait after navigating, before capturing. Video
                previews need this: the still shows for <delay> seconds first
                (default: 0)
  --frames N    capture N frames instead of one, --frame-interval seconds apart,
                to <out>-1.png .. <out>-N.png  (default: 1)
  --frame-interval S  seconds between frames when --frames > 1  (default: 1)
  --video       render with the video-capable image instead of the default one,
                so <video> elements actually play. Slower, and NOT authoritative
                for layout — see docker/README.md

  Env pins (optional, empty = theme default):
    ICON_SIZE=Boxart|Compact
    TITLE_VISIBILITY="PSP-Faithful"|"With Titles"
    GAMELIST_STYLE="PSP Card"|"List + Details"|"Box Art Grid"
    VIDEO_DELAY=Instant|"2 seconds"|"5 seconds"|"10 seconds"
    VIDEO_AUDIO=On|Off
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
    --video)      VIDEO=1; shift ;;
    -h|--help)    usage 0 ;;
    *) echo "unknown argument: $1" >&2; usage 1 ;;
  esac
done

case "${VIEW}" in
  system|gamelist|gamecarousel|menu) ;;
  *) echo "bad --view: ${VIEW}" >&2; exit 2 ;;
esac
if [[ "${VIEW}" == gamelist || "${VIEW}" == gamecarousel ]] && [[ -z "${LIBRARY}" ]]; then
  echo "--library is required for --view ${VIEW}" >&2; exit 2
fi
if [[ ! "${RESOLUTION}" =~ ^[0-9]+x[0-9]+$ ]]; then
  echo "bad --resolution: ${RESOLUTION} (expected WxH)" >&2; exit 2
fi
for n in CAROUSEL_RIGHT SETTLE FRAMES FRAME_INTERVAL; do
  if [[ ! "${!n}" =~ ^[0-9]+$ ]]; then
    echo "bad ${n}: ${!n} (expected a non-negative integer)" >&2; exit 2
  fi
done
if (( FRAMES < 1 )); then echo "--frames must be >= 1" >&2; exit 2; fi

# Same pin, same Dockerfile; the video image adds VLC's plugins and one ES
# source patch (docker/patches) on top.
BUILD_ARGS=( --build-arg ES_PIN="${ES_PIN}" )
if (( VIDEO )); then
  IMAGE="${IMAGE}-video"
  BUILD_ARGS+=( --build-arg WITH_VIDEO=1 )
fi

# Build the image on first use.
if ! docker image inspect "${IMAGE}" >/dev/null 2>&1; then
  echo "Building ${IMAGE} (one-time, ~5-10 min)..."
  docker build -t "${IMAGE}" "${BUILD_ARGS[@]}" "${REPO_ROOT}/docker"
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
  -e ICON_SIZE="${ICON_SIZE:-}" -e TITLE_VISIBILITY="${TITLE_VISIBILITY:-}"
  -e GAMELIST_STYLE="${GAMELIST_STYLE:-}"
  -e VIDEO_DELAY="${VIDEO_DELAY:-}" -e VIDEO_AUDIO="${VIDEO_AUDIO:-}"
  -e CAROUSEL_RIGHT="${CAROUSEL_RIGHT}" -e SETTLE="${SETTLE}"
  -e FRAMES="${FRAMES}" -e FRAME_INTERVAL="${FRAME_INTERVAL}"
)

docker run "${DOCKER_ARGS[@]}" "${IMAGE}" \
  bash /userdata/themes/es-theme-xmb-psp/docker/run-in-container.sh

if (( FRAMES > 1 )); then
  echo "Saved ${OUT%.png}-1.png .. ${OUT%.png}-${FRAMES}.png"
else
  echo "Saved ${OUT}"
fi
