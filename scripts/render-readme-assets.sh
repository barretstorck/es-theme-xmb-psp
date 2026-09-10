#!/usr/bin/env bash
# render-readme-assets.sh — regenerate the images the README commits.
#
# One entry point on purpose. The README's screenshots are its documentation,
# and a future contributor should not have to work out which of render.sh's
# flag combinations produced which file. Running this reproduces the colorset
# gallery, the aspect rows, the per-style shots, the row-toggle matrix, the
# boot-splash table and the navigation GIF.
#
# The exception is docs/screenshots/v0.11/*, three toggle mockups kept as a
# point-in-time record of that redesign. They are deliberately NOT regenerated:
# re-rendering them against today's theme would silently change what they
# document.
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
# The three style shots sit in a 3-column table, which GitHub renders about
# 280px wide, so a full 1024px render is mostly wasted bytes: the Box Art Grid
# one is a wall of eight detailed covers and weighed 805KB on its own — a fifth
# of the whole page budget for one image. 640px still gives a reader something
# worth clicking through to.
STYLE_WIDTH=640
# The toggle matrix is a 2x2 table, so GitHub renders each cell about 440px
# wide. 512 is the nearest size that still has detail left when clicked.
TOGGLE_WIDTH=512

usage() {
  cat <<EOF
Usage: render-readme-assets.sh --library PATH [--out-dir DIR] [--skip-gif]
                               [--only colorsets|aspects|styles|toggles|splash|gif]

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
if [[ -n "${ONLY}" && ! "${ONLY}" =~ ^(colorsets|aspects|styles|toggles|splash|gif)$ ]]; then
  echo "ERROR: --only must be colorsets, aspects, styles, toggles, splash or gif" >&2; exit 2
fi

want() { [[ -z "${ONLY}" || "${ONLY}" == "$1" ]]; }

RENDER="${SCRIPT_DIR}/render.sh"
RECORD="${SCRIPT_DIR}/record.sh"
mkdir -p "${OUT_DIR}"

# "January Blue" -> "january-blue". Used for both the filename and the README
# table's link, so the two cannot drift.
slugify() { tr '[:upper:]' '[:lower:]' <<<"$1" | tr -c 'a-z0-9' '-' | sed 's/-\+/-/g; s/^-//; s/-$//'; }

# ImageMagick lives in the harness image, not necessarily on the host, so the
# downscale runs in the same container everything else does.
# shellcheck source=lib/harness-image.sh
source "${SCRIPT_DIR}/lib/harness-image.sh"
downscale() { # downscale <file> <width>
  docker run --rm -v "$(cd "$(dirname "$1")" && pwd):/w" "${IMAGE}" \
    convert "/w/$(basename "$1")" -resize "$2" "/w/$(basename "$1")"
}

# --- 1. colorset gallery -----------------------------------------------------
# The names come from theme.xml's own subset, so a thirteenth palette cannot
# ship alongside a twelve-row gallery.
#
# The system view takes --library too, even though it shows no games. Without
# it run-in-container.sh synthesizes a single dummy `snes` system with a
# touched placeholder ROM, so the gallery would advertise a one-icon carousel
# instead of the real spread of system icons.
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

  # The README shows ONE combined contact sheet rather than a twelve-cell table:
  # the table needed an empty header row to render at all, and GitHub draws that
  # as a blank strip above the gallery. The individual tiles stay on disk — they
  # are this montage's source, and test-readme-assets.sh asserts one exists per
  # colorset theme.xml declares.
  echo "-- contact sheet -> colorsets.png"
  montage_args=()
  while IFS= read -r name; do
    [[ -z "${name}" ]] && continue
    montage_args+=(-label "${name}" "colorsets/$(slugify "${name}").png")
  done < <(subset_values colorset)
  docker run --rm -v "${OUT_DIR}:/w" -w /w "${IMAGE}" \
    montage "${montage_args[@]}" -tile 4x3 -geometry +8+8 \
    -background '#161b22' -fill '#e6edf3' -font DejaVu-Sans -pointsize 17 \
    colorsets.png
fi

# --- 1b. the Icon Size x Title Visibility matrix -----------------------------
# Both toggles only affect UNSELECTED rows, so a shot with the selection at the
# top of the list shows one row below and nothing above — the previous README
# used exactly that and the toggles were near-invisible. GAMELIST_DOWN=2 moves
# the selection into the middle so a row is visible on either side, and all four
# cells are rendered at the same position so the table compares like with like.
if want toggles; then
  echo "== gamelist row toggles (4:3, 1024x768 -> ${TOGGLE_WIDTH}px) =="
  while IFS= read -r icon; do
    [[ -z "${icon}" ]] && continue
    while IFS= read -r title; do
      [[ -z "${title}" ]] && continue
      out="${OUT_DIR}/toggle-$(slugify "${icon}")-$(slugify "${title}").png"
      echo "-- ${icon} / ${title} -> $(basename "${out}")"
      GAMELIST_DOWN=2 ICON_SIZE="${icon}" TITLE_VISIBILITY="${title}" \
        "${RENDER}" --view gamelist --resolution 1024x768 \
                    --library "${LIBRARY}" --out "${out}" >/dev/null
      downscale "${out}" "${TOGGLE_WIDTH}"
    done < <(subset_values titleVisibility)
  done < <(subset_values iconSize)
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
    downscale "${OUT_DIR}/style-${slug}.png" "${STYLE_WIDTH}"
  done < <(subset_values gamelistStyle)
fi

# --- 4. boot splash ----------------------------------------------------------
# The three shots the README's Boot splash table commits. Without these the
# script's "regenerates every committed image" claim was false: they were added
# by #53 and had no path through here, so a splash change would have left the
# README showing the old one with nothing to catch it.
#
# The splash is transient — gone within about a second — so render.sh grabs it
# SPLASH_AT seconds in. That default is tuned for 1024x768; smaller screens
# boot faster.
if want splash; then
  echo "== boot splash =="
  # Bursts land in a temp dir, never in OUT_DIR: OUT_DIR is docs/screenshots by
  # default, and a failed run would otherwise leave a dozen stray frames in a
  # tracked directory.
  TMP_SPLASH="$(mktemp -d)"
  trap 'rm -rf "${TMP_SPLASH}"' EXIT
  for spec in "splash-4x3:January Blue:1024x768" \
              "splash-4x3-august-orange:August Orange:1024x768" \
              "splash-1x1:December Aqua:720x720"; do
    name="${spec%%:*}"; rest="${spec#*:}"
    colorset="${rest%%:*}"; res="${rest#*:}"
    echo "-- ${name} (${colorset}, ${res})"
    # The splash capture is a RACE, and it loses under load: the first run of
    # this group produced three all-black frames and overwrote three good
    # committed screenshots without a word. render.sh cannot tell the
    # difference — an all-black grab means ES had not opened its window yet,
    # which is a successful screenshot of nothing.
    #
    # So retry with a later SPLASH_AT until the frame has actual content, and
    # fail loudly rather than commit black.
    # ONE boot, then a fast burst of frames — not a ladder of separate boots.
    # The window is narrower than a ladder can aim at: at 720x720 SPLASH_AT=0.25
    # was still black and 0.40 was already the carousel, so the splash lives in
    # a ~0.15s gap and six boots probing single instants kept missing it. A
    # burst costs one boot and samples the whole window at the capture rate
    # (~90ms), which is finer than the window is wide.
    burst="${TMP_SPLASH}/${name}"
    rm -rf "${burst}"; mkdir -p "${burst}"
    SPLASH_AT=0.20 "${RENDER}" --view splash --resolution "${res}" \
      --colorset "${colorset}" --library "${LIBRARY}" \
      --frames 14 --frame-interval 0.01 --out "${burst}/f.png" >/dev/null

    # Two failure modes, and a brightness test alone only catches one.
    #   luma ~0      -> ES had not opened its window; an all-black grab.
    #   corner busy  -> the splash was already over and this is the CAROUSEL,
    #                   which draws a CLOCK in the top-right. The splash draws
    #                   no status bar at all, so its top-right corner is flat
    #                   wave gradient. Measured: splash 5e-09, carousel 0.11.
    # Checking brightness alone silently committed a carousel frame as the 1:1
    # splash screenshot, so this asserts what the splash IS, not merely that
    # something rendered.
    #
    # Metrics are captured as one string and split, NOT `read ... < <(...)`:
    # ImageMagick's -format output has no trailing newline, so `read` returns 1
    # even though it assigned both variables, and `set -e` killed the run with
    # no message at all.
    ok=0
    for f in "${burst}"/f-*.png; do
      metrics="$(docker run --rm -v "${burst}:/w" "${IMAGE}" bash -c \
        "convert /w/$(basename "${f}") -colorspace Gray -format '%[fx:mean] ' info:; \
         convert /w/$(basename "${f}") -gravity NorthEast -crop 22%x9%+0+0 +repage \
                 -colorspace Gray -format '%[fx:standard_deviation]' info:")"
      luma="${metrics%% *}"; corner="${metrics##* }"
      if awk -v l="${luma}" -v c="${corner}" 'BEGIN{exit !(l > 0.05 && c < 0.01)}'; then
        cp "${f}" "${OUT_DIR}/${name}.png"
        echo "   (caught the splash in $(basename "${f}"), luma=${luma})"
        ok=1; break
      fi
    done
    if (( ok == 0 )); then
      echo "ERROR: no SPLASH_AT attempt for ${name} caught the splash." >&2
      echo "  It is gone within ~1s, so the capture is a race this machine is" >&2
      echo "  losing. Re-run when it is quieter, or sweep by hand:" >&2
      echo "    ./scripts/render.sh --view splash --frames 20 --frame-interval 0.01" >&2
      exit 1
    fi
  done
fi

# --- 5. the navigation GIF ---------------------------------------------------
if want gif && (( SKIP_GIF == 0 )); then
  echo "== navigation GIF (16:9) =="
  "${RECORD}" --library "${LIBRARY}" --resolution 1280x720 \
              --out "${OUT_DIR}/xmb-navigation.gif"
fi

echo
echo "README assets written to ${OUT_DIR}"
