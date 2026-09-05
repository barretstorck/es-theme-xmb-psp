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

echo
echo "style A — card geometry:"

CARD="${REPO_ROOT}/_inc/gamelist-card.xml"
COMMON="${REPO_ROOT}/_inc/common.xml"

var() { # var <name> -> value from common.xml
  grep -oP "(?<=<$1>)[^<]*" "${COMMON}" | head -1
}

# Slot centres are FORCED even by <lines>3</lines>:
#   centre_i = glListTop + glListH * (i + 0.5) / 3
# cardY must equal the middle centre or the card detaches from the cursor row.
python3 - "$(var glListTop)" "$(var glListH)" "$(var cardY)" <<'PY'
import sys
top, h, cardy = (float(x) for x in sys.argv[1:4])
mid = top + h * 1.5 / 3
assert abs(mid - cardy) < 1e-6, f"middle slot {mid} != cardY {cardy}"
PY
check "cardY sits on the middle textlist slot" $?

# Column budget: five fontawesome glyphs must not reach the players column.
python3 - "$(var cardStarX)" "$(var cardPlayersX)" "$(var cardMetaFontSize)" <<'PY'
import sys
sx, px, fs = (float(x) for x in sys.argv[1:4])
# glyph advance ~= fontSize (height-normalised) * 768 / 1024 width-normalised,
# five glyphs plus four 25% gaps. Matches the mockup generator's measurement.
w = fs * 0.85 * 768
track = (5 * w + 4 * w * 0.25) / 1024
assert sx + track < px, f"star track {sx}..{sx+track:.4f} collides with players at {px}"
PY
check "star track clears the players column" $?

# Nothing may reach the helpsystem strip at 0.94.
python3 - "$(var glListTop)" "$(var glListH)" <<'PY'
import sys
top, h = (float(x) for x in sys.argv[1:3])
bottom_peek = top + h * 2.5 / 3
title = bottom_peek + 0.076 + 0.013   # peek title centre + half its line height
assert title < 0.94, f"bottom peek title reaches {title}, help strip starts at 0.94"
PY
check "bottom peek title clears the help strip" $?

# The screenshot->video handoff is ONE <video>, not a paired image swap.
for prop in 'snapshotSource>image' 'showSnapshotDelay>true' 'showSnapshotNoVideo>true'; do
  grep -q "<${prop}<" "${CARD}"
  check "cardMedia sets ${prop%%>*}" $?
done

grep -q '<delay>${videoDelay}</delay>' "${CARD}"
check "cardMedia delay is driven by the videoDelay subset" $?

# maxSize never breaks aspect ratio; size would stretch the video.
python3 - "${CARD}" <<'PY'
import sys, xml.etree.ElementTree as ET
root = ET.parse(sys.argv[1]).getroot()
v = root.find(".//video[@name='cardMedia']")
assert v is not None, "no cardMedia video element"
assert v.find("maxSize") is not None, "cardMedia must use maxSize"
assert v.find("size") is None, "cardMedia must NOT use size (stretches video)"
PY
check "cardMedia uses maxSize, not size" $?

# {game:stars} emits filled glyphs only, so a dim 5-glyph track sits behind it.
python3 - "${CARD}" <<'PY'
import sys, xml.etree.ElementTree as ET
root = ET.parse(sys.argv[1]).getroot()
track = root.find(".//text[@name='cardStarTrack']")
stars = root.find(".//text[@name='cardStars']")
assert track is not None and stars is not None, "missing cardStarTrack/cardStars"
assert track.findtext("text").count("") == 5, "track must be exactly 5 glyphs"
assert stars.findtext("text").strip() == "{game:stars}"
# They must align exactly: same anchor, font and size.
for tag in ("pos", "origin", "fontPath", "fontSize"):
    assert track.findtext(tag) == stars.findtext(tag), f"{tag} differs between track and stars"
assert float(stars.findtext("zIndex")) > float(track.findtext("zIndex")), "stars must paint over track"
PY
check "star track and filled stars align and layer correctly" $?

# The harness ES binary has zero VideoVlcComponent symbols / no libvlc, so
# <video> draws nothing there — cardScreenshot is the always-present fallback
# that must share cardMedia's anchor/envelope and sit behind it.
python3 - "${CARD}" <<'PY'
import sys, xml.etree.ElementTree as ET
root = ET.parse(sys.argv[1]).getroot()
shot = root.find(".//image[@name='cardScreenshot']")
media = root.find(".//video[@name='cardMedia']")
assert shot is not None and media is not None, "missing cardScreenshot/cardMedia"
assert shot.findtext("path").strip() == "{game:image}", "cardScreenshot must bind {game:image}"
for tag in ("pos", "maxSize", "origin"):
    assert shot.findtext(tag) == media.findtext(tag), f"{tag} differs between cardScreenshot and cardMedia"
assert float(media.findtext("zIndex")) > float(shot.findtext("zIndex")), "cardMedia must paint over cardScreenshot"
PY
check "cardScreenshot and cardMedia align and layer correctly" $?

# The v0.11 fault: an unbounded description ran under the help strip.
python3 - "${CARD}" "${COMMON}" <<'PY'
import sys, re, xml.etree.ElementTree as ET
card, common = sys.argv[1], sys.argv[2]
src = open(common).read()
def resolve(tok):
    """Turn '${name}' into its numeric value from common.xml; pass numbers through."""
    m = re.fullmatch(r"\$\{(\w+)\}", tok.strip())
    if not m:
        return float(tok)
    v = re.search(rf"<{m.group(1)}>([^<]+)<", src)
    assert v, f"{tok} is not defined in common.xml"
    return float(v.group(1))
root = ET.parse(card).getroot()
d = root.find(".//text[@name='cardDesc']")
assert d is not None, "no cardDesc"
y = resolve(d.findtext("pos").split()[1])
h = resolve(d.findtext("size").split()[1])
assert y + h <= 0.94, f"cardDesc bottom {y + h:.3f} reaches the help strip at 0.94"
PY
check "cardDesc is height-bounded above the help strip" $?

exit "${fail}"
