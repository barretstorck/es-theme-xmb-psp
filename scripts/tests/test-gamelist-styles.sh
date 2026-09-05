#!/usr/bin/env bash
# Structural smoke test for the v0.12 gamelist styles.
# Asserts wiring invariants that a render cannot catch cheaply:
# harness plumbing, style-file structure, subset wiring, include order.
# NOTE: deliberately NOT `set -e`. Every assertion is `<cmd>; check "..." $?`,
# and under `set -e` a failing <cmd> aborts the script before check() runs —
# so only the first failure is ever reported and `fail` accumulation is dead
# code. Without -e, all checks run and `exit "${fail}"` still gates the run.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
fail=0
check() { # check <description> <condition-exit-code>
  if [[ "$2" -eq 0 ]]; then echo "  ok   - $1"; else echo "  FAIL - $1"; fail=1; fi
}

echo "harness plumbing:"

grep -q 'GAMELIST_STYLE' "${REPO_ROOT}/scripts/render.sh"
check "render.sh passes GAMELIST_STYLE through" $?

grep -q 'subset.gamelistStyle' "${REPO_ROOT}/docker/run-in-container.sh"
check "run-in-container.sh writes subset.gamelistStyle" $?

# The theme's defaultView only wins when ES's own preference is automatic or
# names a view the active style does not define (ViewController.cpp:697-720).
# Pinning "detailed" would mask that mechanism for the card style.
grep -qE 'gamelist\)[[:space:]]*GLVIEW="automatic"' "${REPO_ROOT}/docker/run-in-container.sh"
check "gamelist view uses GamelistViewStyle=automatic" $?

echo
echo "style files:"

STYLES=("card:detailed" "list:detailed" "grid:grid")
for entry in "${STYLES[@]}"; do
  name="${entry%%:*}"; want_view="${entry##*:}"
  f="${REPO_ROOT}/_inc/gamelist-${name}.xml"

  [[ -f "${f}" ]]
  check "_inc/gamelist-${name}.xml exists" $?

  python3 -c "import xml.etree.ElementTree as ET,sys; ET.parse(sys.argv[1])" "${f}" 2>/dev/null
  check "gamelist-${name}.xml is well-formed XML" $?

  # Root <theme defaultView="..."> is what selects the view type.
  got="$(python3 -c "
import xml.etree.ElementTree as ET,sys
print(ET.parse(sys.argv[1]).getroot().get('defaultView',''))" "${f}" 2>/dev/null)"
  [[ "${got}" == "${want_view}" ]]
  check "gamelist-${name}.xml declares defaultView='${want_view}' (got '${got}')" $?

  # Exactly one <view> element — two would let styles leak into each other.
  n="$(python3 -c "
import xml.etree.ElementTree as ET,sys
print(len(ET.parse(sys.argv[1]).getroot().findall('view')))" "${f}" 2>/dev/null)"
  [[ "${n}" == "1" ]]
  check "gamelist-${name}.xml has exactly one <view> (got ${n})" $?

  grep -q 'CC-BY-NC-SA' "${f}"
  check "gamelist-${name}.xml carries the licence header" $?

  # Knulli quirk: animated wave layers must sit inside the view block.
  # Count ELEMENTS, not lines containing the word — the header prose mentions
  # "waveLayer" twice, so a line count of >=3 would still pass with two of the
  # three real elements deleted, which is exactly the regression this guards.
  w="$(grep -c '<image name="waveLayer' "${f}" || true)"
  [[ "${w}" -eq 3 ]]
  check "gamelist-${name}.xml has all 3 waveLayer elements (found ${w})" $?
done

echo
echo "theme.xml wiring:"

[[ ! -f "${REPO_ROOT}/_inc/gamelist.xml" ]]
check "old _inc/gamelist.xml is gone" $?

! grep -q '_inc/gamelist\.xml' "${REPO_ROOT}/theme.xml"
check "theme.xml no longer includes _inc/gamelist.xml" $?

grep -q 'subset name="gamelistStyle"' "${REPO_ROOT}/theme.xml"
check "theme.xml declares the gamelistStyle subset" $?

for v in "PSP Card" "List + Details" "Box Art Grid"; do
  grep -qF "<include name=\"${v}\">" "${REPO_ROOT}/theme.xml"
  check "gamelistStyle offers '${v}'" $?
done

# First variant is the default (matches the videoDelay convention).
first="$(grep -A4 'subset name="gamelistStyle"' "${REPO_ROOT}/theme.xml" \
         | grep -o 'name="[^"]*"' | sed -n 2p)"
[[ "${first}" == 'name="PSP Card"' ]]
check "PSP Card is the first/default variant (got ${first})" $?

# ORDER: the style subset must parse AFTER aspect-*.xml, or per-ratio
# overrides are silently lost (the v0.11 icon-size clobbering bug).
aspect_line="$(grep -n 'aspect-1x1.xml' "${REPO_ROOT}/theme.xml" | cut -d: -f1)"
style_line="$(grep -n 'subset name="gamelistStyle"' "${REPO_ROOT}/theme.xml" | cut -d: -f1)"
[[ -n "${aspect_line}" && -n "${style_line}" && "${style_line}" -gt "${aspect_line}" ]]
check "gamelistStyle subset (line ${style_line}) parses after aspect-*.xml (line ${aspect_line})" $?

exit "${fail}"
