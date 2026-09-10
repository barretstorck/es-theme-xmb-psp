#!/usr/bin/env bash
# Structural test for the Scroll Speed subset and auto-scrolling descriptions
# (issue #38).
#
# The subset shipped dead twice over: it named an element that no longer
# existed (md_description -> tplDesc -> cardDesc), and even the right name
# would have done nothing, because <autoScrollSpeed> is only read once
# <autoScroll> has switched the component out of AutoScrollType::NONE. Both
# failures are silent — ES logs nothing when a theme property lands on no
# element, and nothing when a speed is set on a component that never scrolls.
# Hence a structural guard rather than a pixel check.
#
# NOTE: deliberately NOT `set -e` — see the note in test-gamelist-styles.sh.
set -uo pipefail

# shellcheck source=scripts/lib/test-lib.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../lib" && pwd)/test-lib.sh"

CARD="${REPO_ROOT}/_inc/gamelist-card.xml"
LIST="${REPO_ROOT}/_inc/gamelist-list.xml"
GRID="${REPO_ROOT}/_inc/gamelist-grid.xml"
STYLE_FILES=("${CARD}" "${LIST}" "${GRID}")
SPEED_FILES=("${REPO_ROOT}"/_inc/scroll-speed-*.xml)

# Print one named element's block. Names are unique across a style file, so
# "from the opening tag that carries the name" is unambiguous. The close has to
# be a line that is ONLY a closing tag: a <text> element's body contains a
# <text>{game:desc}</text> property tag, and matching that ends the block four
# lines early — which silently hid the clipRect from an earlier version of this
# guard. One-line elements (<text name="md_name"><visible>false</visible></text>)
# close on their opening line.
text_block() { # text_block <file> <element-name>
  awk -v want="name=\"$2\"" '
    !inblk && index($0, want) && /<text/ {
      inblk = 1
      print
      if ($0 ~ /<\/text>/) inblk = 0
      next
    }
    inblk {
      print
      if ($0 ~ /^[[:space:]]*<\/text>[[:space:]]*$/) inblk = 0
    }
  ' "$1"
}

echo "the drift guard — every element a subset targets must exist:"

# The class of bug that produced this issue: a subset file naming an element
# that no style file defines. Generic on purpose, so the next rename is caught
# by CI rather than by someone noticing a setting does nothing.
declared_names="$(grep -ohE '<[a-z]+ name="[^"]+"' "${STYLE_FILES[@]}" \
  | sed -E 's/.*name="([^"]+)".*/\1/' | sort -u)"
orphans=""
for f in "${SPEED_FILES[@]}"; do
  while read -r name; do
    [[ -z "${name}" ]] && continue
    grep -qxF "${name}" <<<"${declared_names}" || orphans+="  ${f##*/} -> ${name}"$'\n'
  done < <(grep -ohE '<[a-z]+ name="[^"]+"' "${f}" | sed -E 's/.*name="([^"]+)".*/\1/')
done
[[ -z "${orphans}" ]]
check "no scroll-speed subset targets an element absent from every style file" $?
[[ -z "${orphans}" ]] || { echo "         orphaned targets:" >&2; printf '%s' "${orphans}" >&2; }

# The specific corpse. Renamed to cardDesc in v0.11; the subset was never chased.
! grep -rq 'tplDesc' "${REPO_ROOT}/_inc" "${REPO_ROOT}/theme.xml" "${REPO_ROOT}/README.md"
check "tplDesc appears nowhere in the theme or README" $?

echo
echo "descriptions actually scroll:"

# mAutoScroll defaults to AutoScrollType::NONE (TextComponent.cpp:15).
# <autoScrollSpeed> is read only by the VERTICAL branch (TextComponent.cpp:471);
# the horizontal marquee derives its speed from font metrics and ignores the
# property entirely (:449). So vertical is the only mode the subset can drive.
grep -q '<autoScroll>vertical</autoScroll>' <(text_block "${CARD}" cardDesc)
check "cardDesc opts into vertical auto-scroll" $?

grep -q '<autoScroll>vertical</autoScroll>' <(text_block "${LIST}" listDesc)
check "listDesc opts into vertical auto-scroll" $?

# Decided on #38: the grid stays art-first, its info bar is a caption and gets
# no description at all, so there is nothing there to scroll.
! grep -q '<autoScroll>' "${GRID}"
check "Box Art Grid opts nothing into auto-scroll" $?

echo
echo "scrolling stays inside its bounds:"

# The reason v0.12 removed the marquee in the first place: v0.11's description
# ran under the help strip on-device, because <size> does not clip on this
# build. clipRect was the fix and must survive the restoration — scroll WITHIN
# the box, do not go back to the narrow overflowing strip.
grep -q '<clipRect>' <(text_block "${CARD}" cardDesc)
check "cardDesc still carries a clipRect" $?

grep -q '<clipRect>' <(text_block "${LIST}" listDesc)
check "listDesc still carries a clipRect" $?

# Vertical scrolling is skipped outright unless mSize.y() > 0
# (TextComponent.cpp:471), and the overflow it scrolls is measured against
# that same height (:483).
grep -q '<size>${cardTextW} ${cardDescH}</size>' <(text_block "${CARD}" cardDesc)
check "cardDesc keeps a non-zero height for the scroll to measure against" $?

grep -q '<size>0.395 ${listDescH}</size>' <(text_block "${LIST}" listDesc)
check "listDesc keeps a non-zero height for the scroll to measure against" $?

echo
echo "the subset drives both scrolling styles:"

for f in "${SPEED_FILES[@]}"; do
  name="${f##*/}"

  grep -q 'name="cardDesc"' "${f}"
  check "${name} targets cardDesc" $?

  grep -q 'name="listDesc"' "${f}"
  check "${name} targets listDesc" $?

  # Both scrolling styles declare <view name="detailed,gamecarousel">; the grid
  # is on its own view name. Naming a gamelist view here that a user has pinned
  # as their Gamelist View Style is how b5e2063's regression happened — a view
  # registered by any parsed file makes hasView() true and ES builds it
  # unstyled. Keep this list matching the styles the subset can actually reach.
  grep -q '<view name="detailed,gamecarousel">' "${f}"
  check "${name} registers only the two scrolling styles' view" $?

  ! grep -qE '<view name="[^"]*grid' "${f}"
  check "${name} never registers the grid view" $?

  # Stale headers are how this drifted unnoticed for two releases.
  ! grep -q 'tplDesc\|md_description' "${f}"
  check "${name}'s header does not cite a long-dead element" $?
done

# ES's own defaults are 150ms between one-pixel steps (AUTO_SCROLL_SPEED,
# TextComponent.cpp:9); Slow/Fast bracket it. Guard the values so a later
# retune is a deliberate edit rather than a typo.
grep -q '<autoScrollSpeed>150</autoScrollSpeed>' "${REPO_ROOT}/_inc/scroll-speed-normal.xml"
check "Normal is ES's stock 150ms cadence" $?

grep -q '<autoScrollSpeed>300</autoScrollSpeed>' "${REPO_ROOT}/_inc/scroll-speed-slow.xml"
check "Slow is 300ms" $?

grep -q '<autoScrollSpeed>75</autoScrollSpeed>' "${REPO_ROOT}/_inc/scroll-speed-fast.xml"
check "Fast is 75ms" $?

echo
echo "include order:"

# Element properties merge last-write-wins at parse time, so the subset only
# overrides the style's own autoScrollSpeed if it is parsed afterwards. This is
# the same trap that silently ate the per-ratio card overrides in v0.11.
style_line="$(grep -n '<subset name="gamelistStyle"' "${REPO_ROOT}/theme.xml" | cut -d: -f1)"
speed_line="$(grep -n '<subset name="scrollSpeed"' "${REPO_ROOT}/theme.xml" | cut -d: -f1)"
[[ -n "${style_line}" && -n "${speed_line}" && "${speed_line}" -gt "${style_line}" ]]
check "scrollSpeed is declared after gamelistStyle in theme.xml" $?

echo
echo "docs match the shipped behaviour:"

! grep -q 'Scroll Speed.*no-op' "${REPO_ROOT}/README.md"
check "README no longer calls Scroll Speed a no-op" $?

grep -qi 'Scroll Speed.*Box Art Grid\|Box Art Grid.*scroll' "${REPO_ROOT}/README.md"
check "README says Scroll Speed does not apply to Box Art Grid" $?

GUIDE="${REPO_ROOT}/docs/psp-xmb-style-guidelines.md"
! grep -q 'has had no effective target\|currently a no-op\|kept for forward compatibility' "${GUIDE}"
check "style guide no longer documents the subset as dead" $?

grep -qi 'autoScroll' "${GUIDE}"
check "style guide documents the autoScroll property" $?

echo
if [[ "${fail}" -eq 0 ]]; then echo "all checks passed"; else echo "FAILURES"; fi
exit "${fail}"
