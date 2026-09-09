#!/usr/bin/env bash
# render-readme-assets.sh — regenerate EVERY image the README commits.
#
# One entry point on purpose. The README's screenshots are its documentation,
# and a future contributor should not have to work out which of render.sh's
# flag combinations produced which file. Running this reproduces the whole set.
#
# Needs a real scraped library for the gamelist shots. /tmp/library (the KNULLI
# slice) has real art and descriptions up to 1252 chars; tests/fixtures/library
# is deliberately degenerate — its longest description is 74 characters, which
# makes the layout look better than it is. It is the regression corpus, not the
# marketing corpus.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
# shellcheck source=lib/theme-subsets.sh
source "${SCRIPT_DIR}/lib/theme-subsets.sh"

LIBRARY=""
OUT_DIR="${REPO_ROOT}/docs/screenshots"
SKIP_GIF=0
ONLY=""
# Colorset tiles are table thumbnails, not full-size shots. 320px keeps twelve
# of them inside the 600KB budget while staying legible on a phone.
THUMB_WIDTH=320

usage() {
  cat <<EOF
Usage: render-readme-assets.sh --library PATH [--out-dir DIR] [--skip-gif]
                               [--only colorsets|aspects|styles|gif]

  --library PATH  Knulli userdata-shaped library with REAL scraped media.
                  Use the KNULLI slice, e.g. /tmp/library.
  --out-dir DIR   where to write     (default: docs/screenshots)
  --skip-gif      skip the animated GIF, which is by far the slowest step
  --only WHAT     regenerate one group only
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --library) LIBRARY="$2"; shift 2 ;;
    --out-dir) OUT_DIR="$2"; shift 2 ;;
    --skip-gif) SKIP_GIF=1; shift ;;
    --only)    ONLY="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "unknown argument: $1" >&2; usage >&2; exit 2 ;;
  esac
done

if [[ -z "${LIBRARY}" ]]; then
  echo "ERROR: --library is required (gamelist assets need real scraped media)." >&2
  echo "  Use the KNULLI slice, e.g. --library /tmp/library." >&2
  echo "  Do NOT use tests/fixtures/library — it is deliberately degenerate" >&2
  echo "  (74-char maximum description) and exists to catch regressions, not" >&2
  echo "  to sell the theme." >&2
  exit 2
fi
if [[ ! -d "${LIBRARY}" ]]; then
  echo "ERROR: --library '${LIBRARY}' is not a directory" >&2; exit 2
fi
if [[ -n "${ONLY}" && ! "${ONLY}" =~ ^(colorsets|aspects|styles|gif)$ ]]; then
  echo "ERROR: --only must be colorsets, aspects, styles or gif" >&2; exit 2
fi

want() { [[ -z "${ONLY}" || "${ONLY}" == "$1" ]]; }

RENDER="${SCRIPT_DIR}/render.sh"
RECORD="${SCRIPT_DIR}/record.sh"
mkdir -p "${OUT_DIR}"

# "January Blue" -> "january-blue". Used for both the filename and the README
# table's link, so the two cannot drift.
slugify() { tr '[:upper:]' '[:lower:]' <<<"$1" | tr -c 'a-z0-9' '-' | sed 's/-\+/-/g; s/^-//; s/-$//'; }

# ImageMagick lives in the harness image, not necessarily on the host, so the
# downscale runs in the same container everything else does. Must match
# docker/Dockerfile, render.sh and record.sh.
ES_PIN="9bbb16a"
HARNESS_REV="r2"
IMAGE="es-xmb-harness:knulli-${ES_PIN}-${HARNESS_REV}"
downscale() { # downscale <file> <width>
  docker run --rm -v "$(cd "$(dirname "$1")" && pwd):/w" "${IMAGE}" \
    convert "/w/$(basename "$1")" -resize "$2" "/w/$(basename "$1")"
}

# --- 1. colorset gallery -----------------------------------------------------
# The names come from theme.xml's own subset, so a thirteenth palette cannot
# ship alongside a twelve-row gallery.
#
# The system view takes --library too, even though it shows no games: without
# it the carousel falls back to the fixture corpus and the gallery advertises
# placeholder icons instead of the real 199-icon set.
if want colorsets; then
  mkdir -p "${OUT_DIR}/colorsets"
  echo "== colorset gallery (system view, 1024x768 -> ${THUMB_WIDTH}px) =="
  while IFS= read -r name; do
    [[ -z "${name}" ]] && continue
    slug="$(slugify "${name}")"
    out="${OUT_DIR}/colorsets/${slug}.png"
    echo "-- ${name} -> ${slug}.png"
    "${RENDER}" --view system --resolution 1024x768 --colorset "${name}" \
                --library "${LIBRARY}" --out "${out}" >/dev/null
    downscale "${out}" "${THUMB_WIDTH}"
  done < <(subset_values colorset)
fi

# --- 2. aspect-ratio rows ----------------------------------------------------
if want aspects; then
  echo "== aspect rows =="
  for spec in "4x3:1024x768" "16x9:1280x720" "3x2:720x480" "1x1:720x720" "8x7:1024x896"; do
    label="${spec%%:*}"; res="${spec#*:}"
    echo "-- system ${label} (${res})"
    "${RENDER}" --view system --resolution "${res}" --library "${LIBRARY}" \
                --out "${OUT_DIR}/system-${label}.png" >/dev/null
    echo "-- gamelist ${label} (${res})"
    "${RENDER}" --view gamelist --resolution "${res}" --library "${LIBRARY}" \
                --out "${OUT_DIR}/gamelist-${label}.png" >/dev/null
  done
fi

# --- 3. one shot per gamelist style ------------------------------------------
if want styles; then
  echo "== gamelist styles (4:3) =="
  while IFS= read -r style; do
    [[ -z "${style}" ]] && continue
    slug="$(slugify "${style}")"
    echo "-- ${style} -> style-${slug}.png"
    GAMELIST_STYLE="${style}" "${RENDER}" --view gamelist --resolution 1024x768 \
      --library "${LIBRARY}" --out "${OUT_DIR}/style-${slug}.png" >/dev/null
  done < <(subset_values gamelistStyle)
fi

# --- 4. the navigation GIF ---------------------------------------------------
if want gif && (( SKIP_GIF == 0 )); then
  echo "== navigation GIF (16:9) =="
  "${RECORD}" --library "${LIBRARY}" --resolution 1280x720 \
              --out "${OUT_DIR}/xmb-navigation.gif"
fi

echo
echo "README assets written to ${OUT_DIR}"
