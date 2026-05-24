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
BATTERY="Show"
LIBRARY=""
OUT="${REPO_ROOT}/.dev/render.png"

usage() {
  cat <<EOF
Usage: render.sh [--view V] [--resolution WxH] [--colorset NAME]
                 [--battery Show|Hide] [--library PATH] [--out FILE]

  --view        system | gamelist | gamecarousel | menu   (default: system)
  --resolution  Xvfb geometry, e.g. 1024x768 (4:3) or 1280x720 (16:9)
  --colorset    PSP colorset name, e.g. "August Orange"   (default: January Blue)
  --battery     Battery subset variant: Show | Hide       (default: Show)
  --library     path to a Knulli userdata-shaped library  (gamelist views need this)
  --out         host path for the captured PNG            (default: .dev/render.png)
EOF
  exit "${1:-0}"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --view)       VIEW="${2:?}"; shift 2 ;;
    --resolution) RESOLUTION="${2:?}"; shift 2 ;;
    --colorset)   COLORSET="${2:?}"; shift 2 ;;
    --battery)    BATTERY="${2:?}"; shift 2 ;;
    --library)    LIBRARY="${2:?}"; shift 2 ;;
    --out)        OUT="${2:?}"; shift 2 ;;
    -h|--help)    usage 0 ;;
    *) echo "unknown argument: $1" >&2; usage 1 ;;
  esac
done

case "${VIEW}" in
  system|gamelist|gamecarousel|menu) ;;
  *) echo "bad --view: ${VIEW}" >&2; exit 2 ;;
esac
case "${BATTERY}" in
  Show|Hide) ;;
  *) echo "bad --battery: ${BATTERY} (expected Show or Hide)" >&2; exit 2 ;;
esac
if [[ "${VIEW}" == gamelist || "${VIEW}" == gamecarousel ]] && [[ -z "${LIBRARY}" ]]; then
  echo "--library is required for --view ${VIEW}" >&2; exit 2
fi
if [[ ! "${RESOLUTION}" =~ ^[0-9]+x[0-9]+$ ]]; then
  echo "bad --resolution: ${RESOLUTION} (expected WxH)" >&2; exit 2
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
  -e VIEW="${VIEW}" -e RESOLUTION="${RESOLUTION}" -e COLORSET="${COLORSET}"
  -e BATTERY="${BATTERY}" -e OUTNAME="${OUTNAME}" -e HAS_LIBRARY="${HAS_LIBRARY}"
)

docker run "${DOCKER_ARGS[@]}" "${IMAGE}" \
  bash /userdata/themes/es-theme-xmb-psp/docker/run-in-container.sh

echo "Saved ${OUT}"
