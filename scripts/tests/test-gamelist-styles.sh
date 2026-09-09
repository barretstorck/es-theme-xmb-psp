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

# A bare 'GAMELIST_STYLE' also matches the usage heredoc (render.sh:30-34) --
# deleting the functional -e passthrough would still pass. Require the
# passthrough itself.
grep -q '\-e GAMELIST_STYLE=' "${REPO_ROOT}/scripts/render.sh"
check "render.sh passes GAMELIST_STYLE through" $?

grep -q 'subset.gamelistStyle' "${REPO_ROOT}/docker/run-in-container.sh"
check "run-in-container.sh writes subset.gamelistStyle" $?

# The theme's defaultView only wins when ES's own preference is automatic or
# names a view the active style does not define (ViewController.cpp:697-720).
# Pinning "detailed" would mask that mechanism for the card style.
grep -qE 'gamelist\)[[:space:]]*GLVIEW="automatic"' "${REPO_ROOT}/docker/run-in-container.sh"
check "gamelist view uses GamelistViewStyle=automatic" $?

echo
echo "well-formedness (every theme XML in the repo):"

# ES parses with pugixml, which tolerates things the XML spec forbids -- most
# easily a literal "--" inside a <!-- comment -->. That means a malformed file
# renders fine on device and only bites the tooling: every python3 check in
# THIS file, and anyone reaching for xmllint. Checked repo-wide rather than
# per-style, because the file that first hit this (_inc/aspect-8x7.xml) is
# neither a style file nor otherwise parsed here.
python3 - "${REPO_ROOT}" <<'INNER_PY'
import pathlib, sys, xml.etree.ElementTree as ET

root = pathlib.Path(sys.argv[1])
paths = sorted(root.glob("theme.xml")) + sorted(root.glob("_inc/**/*.xml"))
assert paths, "no theme XML found -- glob is wrong"
failures = []
for p in paths:
    try:
        ET.parse(p)
    except ET.ParseError as e:
        failures.append(f"{p.relative_to(root)}: {e}")
if failures:
    print("\n".join(failures), file=sys.stderr)
    sys.exit(1)
INNER_PY
check "every theme XML file is well-formed to a strict parser" $?

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
echo "shared chrome (help strip + sounds):"

# The shared <helpsystem name="help"> and the three sounds live in ONE <view>
# block per file (ThemeData::getElement returns NULL for a view name absent
# from that list, with no cross-view fallback), so every gamelist view name
# must appear in some file's chrome block or that view gets ES's built-in
# help strip and default click sounds.
#
# "grid" must be in gamelist-grid.xml's OWN block, NOT common.xml's shared
# one. Declaring grid in the shared list makes hasView("grid") true even when
# Box Art Grid is not selected, which hijacks a user who pinned ES's Gamelist
# View Style to "grid" into an unstyled built-in grid instead of falling back
# to the theme's defaultView. Found on real hardware.
python3 - "${REPO_ROOT}/_inc/common.xml" "${REPO_ROOT}/_inc/gamelist-grid.xml" <<'PY'
import sys, xml.etree.ElementTree as ET

def chrome_view(path):
    root = ET.parse(path).getroot()
    for v in root.findall("view"):
        if v.find("helpsystem[@name='help']") is not None:
            return v
    return None

shared = chrome_view(sys.argv[1])
assert shared is not None, "no <view> in common.xml declares <helpsystem name='help'>"
names = {n.strip() for n in shared.get("name", "").split(",")}

required = {"system", "detailed", "gamecarousel", "menu"}
missing = required - names
assert not missing, f"common.xml chrome view is missing: {sorted(missing)} (has {sorted(names)})"

assert "grid" not in names, (
    "common.xml's shared chrome view must NOT list 'grid' — that makes "
    "hasView('grid') unconditionally true and hijacks a user pinned to "
    "GamelistViewStyle=grid into an unstyled built-in grid")

grid = chrome_view(sys.argv[2])
assert grid is not None, (
    "gamelist-grid.xml must declare its own <helpsystem name='help'> so the "
    "grid style still gets themed chrome")
assert grid.get("name", "").strip() == "grid", (
    f"gamelist-grid.xml chrome must be in <view name='grid'>, got "
    f"{grid.get('name')!r}")
# Derived from common.xml rather than hardcoded. This assertion used to name
# the four sounds literally, and three of them ("systemscroll", "scroll",
# "select") were names ES never asks for — so the guard was pinning a bug in
# place and would have failed the fix for it (#21). Reading the expected set
# from the shared chrome view means the two copies cannot drift, and there is
# no third list to forget to update. scripts/tests/test-sounds.sh is what
# checks that the names are ones ES actually plays.
shared_sounds = {s.get("name") for s in shared.findall("sound")}
grid_sounds = {s.get("name") for s in grid.findall("sound")}
assert shared_sounds, "common.xml's chrome view declares no <sound> elements"
assert grid_sounds == shared_sounds, (
    f"gamelist-grid.xml's sounds have drifted from common.xml's — "
    f"missing {sorted(shared_sounds - grid_sounds)}, "
    f"extra {sorted(grid_sounds - shared_sounds)}")
PY
check "grid chrome is in gamelist-grid.xml, NOT in common.xml's shared list" $?

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
# A bare '<' is satisfied by a layout that is visually touching (zero
# clearance is not clearance). MIN_COL_GAP demands real, measurable margin.
MIN_COL_GAP = 0.010  # normalized; a bare '<' let 8x7 pass by 0.05px
assert sx + track + MIN_COL_GAP < px, f"star track {sx}..{sx+track:.4f} collides with players at {px}"
PY
check "star track clears the players column" $?

# Nothing may reach the helpsystem strip at 0.94. Modeled from the ACTUAL
# element: tplPeekTitle is TOP-anchored (origin.y=0), not centred, and its
# <pos>/<size> are row-relative (0..1 within its own textlist slot, per the
# peekIconH design comment above) while <fontSize> is screen-normalized like
# every other font in this theme. peekTitleFontSize is read from
# icon-size-boxart.xml (the default Icon Size variant), not hardcoded.
python3 - "$(var glListTop)" "$(var glListH)" "${CARD}" "${REPO_ROOT}/_inc/icon-size-boxart.xml" <<'PY'
import sys, xml.etree.ElementTree as ET
top, h, card, boxart = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]
top, h = float(top), float(h)

root = ET.parse(card).getroot()
tpl = root.find(".//text[@name='tplPeekTitle']")
assert tpl is not None, "no tplPeekTitle"
pos_y = float(tpl.findtext("pos").split()[1])
origin_y = float(tpl.findtext("origin").split()[1])
size_h = float(tpl.findtext("size").split()[1])

font_size = float(
    __import__("re").search(r"<peekTitleFontSize>([^<]+)<", open(boxart).read()).group(1)
)

# Last (bottom) row is slot index 2 of 3; row_top = glListTop + glListH*2/3.
row_h = h / 3
row_top = top + h * 2 / 3
# pos/origin are row-relative: the text box's top edge, in row-relative
# units, is pos_y - origin_y * size_h (origin_y=0 here means pos_y IS the
# top edge already).
box_top = row_top + (pos_y - origin_y * size_h) * row_h
# Single-line text bottom approximated as top + fontSize (screen-normalized),
# matching the convention used elsewhere in this file for line-height.
bottom = box_top + font_size
assert bottom < 0.94, f"bottom peek title reaches {bottom:.4f}, help strip starts at 0.94"
PY
check "bottom peek title clears the help strip" $?

# The screenshot->video handoff is ONE <video>, not a paired image swap.
for prop in 'snapshotSource>image' 'showSnapshotDelay>true' 'showSnapshotNoVideo>true'; do
  grep -q "<${prop}<" "${CARD}"
  check "card md_video sets ${prop%%>*}" $?
done

grep -q '<delay>${videoDelay}</delay>' "${CARD}"
check "card md_video delay is driven by the videoDelay subset" $?

# maxSize never breaks aspect ratio; size would stretch the video.
python3 - "${CARD}" <<'PY'
import sys, xml.etree.ElementTree as ET
root = ET.parse(sys.argv[1]).getroot()
v = root.find(".//video[@name='md_video']")
assert v is not None, "no md_video element"
assert v.find("maxSize") is not None, "md_video must use maxSize"
assert v.find("size") is None, "md_video must NOT use size (stretches video)"
PY
check "card md_video uses maxSize, not size" $?

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

# cardMediaFallback covers the unscraped case: md_video's snapshot is
# {game:image}, which an unscraped game does not have, so without this the
# upper-right art slot sits blank. Same anchor/envelope, guarded on
# !exists({game:image}), painted UNDER md_video so a real still wins when
# present.
python3 - "${CARD}" <<'PY'
import sys, xml.etree.ElementTree as ET
root = ET.parse(sys.argv[1]).getroot()
fb = root.find(".//image[@name='cardMediaFallback']")
media = root.find(".//video[@name='md_video']")
assert fb is not None, "no cardMediaFallback"
assert media is not None, "no md_video"
assert fb.findtext("path").strip() == "${mediaFallbackPath}", \
    f"cardMediaFallback must bind ${{mediaFallbackPath}}, got {fb.findtext('path')!r}"
# Two-part guard: ES resolves md_video's snapshot to the THUMBNAIL when
# <image> is empty (DetailedContainer.cpp:786-807), so guarding on the image
# alone leaves this icon visible behind a box-art-only still.
assert fb.findtext("visible") == "!exists({game:image}) && !exists({game:thumbnail})", \
    f"cardMediaFallback visible guard is {fb.findtext('visible')!r}"
for tag in ("pos", "maxSize", "origin"):
    assert fb.findtext(tag) == media.findtext(tag), f"{tag} differs between cardMediaFallback and md_video"
assert float(fb.findtext("zIndex")) < float(media.findtext("zIndex")), \
    "cardMediaFallback must sit BELOW md_video (lower zIndex)"
PY
check "cardMediaFallback exists, binds mediaFallbackPath, guards !exists(image), sits under md_video" $?

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

echo
echo "style B — list + details:"

LIST="${REPO_ROOT}/_inc/gamelist-list.xml"

python3 - "${LIST}" <<'PY'
import sys, xml.etree.ElementTree as ET
root = ET.parse(sys.argv[1]).getroot()
tl = root.find(".//textlist[@name='gamelist']")
assert tl is not None, "style B needs a real textlist"
assert tl.findtext("lines") == "10", f"expected 10 lines, got {tl.findtext('lines')}"
# Style B shows real titles, unlike the card style's transparent peek list.
assert tl.findtext("fontSize") != "0.0001", "style B must not hide its own text"
PY
check "style B textlist shows 10 real rows" $?

python3 - "${LIST}" <<'PY'
import sys, xml.etree.ElementTree as ET
root = ET.parse(sys.argv[1]).getroot()
v = root.find(".//video[@name='md_video']")
assert v is not None, "no md_video"
for tag, want in (("snapshotSource","image"),("showSnapshotDelay","true"),
                  ("showSnapshotNoVideo","true")):
    assert v.findtext(tag) == want, f"md_video {tag} is {v.findtext(tag)}, want {want}"
assert v.findtext("delay") == "${videoDelay}"
assert v.find("maxSize") is not None and v.find("size") is None
PY
check "list md_video does screenshot->video at correct aspect" $?

python3 - "${LIST}" <<'PY'
import sys, xml.etree.ElementTree as ET
root = ET.parse(sys.argv[1]).getroot()
t = root.find(".//text[@name='listStarTrack']")
s = root.find(".//text[@name='listStars']")
assert t is not None and s is not None, "missing listStarTrack/listStars"
assert t.findtext("text").count("") == 5
for tag in ("pos","origin","fontPath","fontSize"):
    assert t.findtext(tag) == s.findtext(tag), f"{tag} differs"
PY
check "style B star track aligns with filled stars" $?

# Style B does not use the XMB spine; the card elements must be gone.
! grep -qE 'name="(cardBoxart|cardMediaFallback|cardStars|tplPeekIcon)"' "${LIST}"
check "style B does not carry leftover card elements" $?

# Style B has NO OTHER art slot, so an unscraped game (no {game:image}, hence
# no md_video snapshot) would leave the entire right half of the screen blank.
# listMediaFallback must cover it, at the same anchor/envelope, guarded on
# !exists({game:image}), and painted UNDER md_video so a real still wins when
# present.
python3 - "${LIST}" <<'PY'
import sys, xml.etree.ElementTree as ET
root = ET.parse(sys.argv[1]).getroot()
fb = root.find(".//image[@name='listMediaFallback']")
media = root.find(".//video[@name='md_video']")
assert fb is not None, "no listMediaFallback"
assert media is not None, "no md_video"
assert fb.findtext("path").strip() == "${mediaFallbackPath}", \
    f"listMediaFallback must bind ${{mediaFallbackPath}}, got {fb.findtext('path')!r}"
# Two-part guard: ES resolves md_video's snapshot to the THUMBNAIL when
# <image> is empty (DetailedContainer.cpp:786-807), so guarding on the image
# alone leaves this icon visible behind a box-art-only still.
assert fb.findtext("visible") == "!exists({game:image}) && !exists({game:thumbnail})", \
    f"listMediaFallback visible guard is {fb.findtext('visible')!r}"
for tag in ("pos", "maxSize", "origin"):
    assert fb.findtext(tag) == media.findtext(tag), f"{tag} differs between listMediaFallback and md_video"
assert float(fb.findtext("zIndex")) < float(media.findtext("zIndex")), \
    "listMediaFallback must sit BELOW md_video (lower zIndex)"
PY
check "listMediaFallback exists, binds mediaFallbackPath, guards !exists(image), sits under md_video" $?

# Mirrors the style-A cardDesc check: an unbounded description ran under the
# help strip in v0.11. Style B uses clipRect (not size) to bound it — assert
# the clipRect exists and its box stays above the 0.94 help strip.
python3 - "${LIST}" "${COMMON}" <<'PY'
import sys, re, xml.etree.ElementTree as ET
listf, common = sys.argv[1], sys.argv[2]
src = open(common).read()
def resolve(tok):
    """Turn '${name}' into its numeric value from common.xml; pass numbers through."""
    m = re.fullmatch(r"\$\{(\w+)\}", tok.strip())
    if not m:
        return float(tok)
    v = re.search(rf"<{m.group(1)}>([^<]+)<", src)
    assert v, f"{tok} is not defined in common.xml"
    return float(v.group(1))
root = ET.parse(listf).getroot()
d = root.find(".//text[@name='listDesc']")
assert d is not None, "no listDesc"
clip = d.findtext("clipRect")
assert clip, "listDesc must have a clipRect"
x, y, w, h = (resolve(tok) for tok in clip.split())
assert y + h <= 0.94, f"listDesc clipRect bottom {y + h:.3f} reaches the help strip at 0.94"
PY
check "listDesc clipRect is height-bounded above the help strip" $?

echo
echo "style D — box art grid:"

GRID="${REPO_ROOT}/_inc/gamelist-grid.xml"

python3 - "${GRID}" <<'PY'
import sys, xml.etree.ElementTree as ET
root = ET.parse(sys.argv[1]).getroot()
assert root.get("defaultView") == "grid"
view = root.find("view")
assert view.get("name") == "grid", f"view name is {view.get('name')}"
ig = root.find(".//imagegrid[@name='gamegrid']")
assert ig is not None, "no imagegrid"
gt = root.find(".//gridtile")
assert gt is not None, "no gridtile"
# selectionMode/imageSizeMode confirmed present in this build (ThemeData.cpp:196-207)
assert gt.findtext("imageSizeMode") == "maxSize", "tiles must preserve box-art aspect"
PY
check "style D declares imagegrid + gridtile in a grid view" $?

python3 - "${GRID}" <<'PY'
import sys, xml.etree.ElementTree as ET
root = ET.parse(sys.argv[1]).getroot()
t = root.find(".//text[@name='gridStarTrack']")
s = root.find(".//text[@name='gridStars']")
assert t is not None and s is not None, "missing gridStarTrack/gridStars"
assert t.findtext("text").count("") == 5
for tag in ("pos","origin","fontPath","fontSize"):
    assert t.findtext(tag) == s.findtext(tag), f"{tag} differs"
PY
check "style D star track aligns with filled stars" $?

# A grid has no textlist and must not carry the card spine.
! grep -qE '<textlist|name="(cardBoxart|cardMediaFallback|tplPeekIcon)"' "${GRID}"
check "style D has no textlist or leftover card elements" $?

echo
echo "emptyTextDefaults -- every {game:*}-binding text element must disable it:"

# BindingManager.cpp:126 substitutes "Unknown"/"None" for ANY empty {game:*}
# binding when the TextComponent has mBindingDefaults set, and
# TextComponent.cpp:625 defaults that to TRUE for extra="true" elements
# (ThemeData.cpp:252's comment claiming the default is false is wrong).
# Every extra="true" <text> that binds {game:*} must explicitly disable it
# so an unscraped game renders blank fields, not a fake "Unknown"/"None".
# Enumerated explicitly (not grepped) so a future style file -- or a new
# bound element added to an existing one -- that forgets this fails loudly
# instead of silently passing.
python3 - "${REPO_ROOT}" <<'INNER_PY'
import sys, xml.etree.ElementTree as ET

EXPECT = {
    "_inc/gamelist-grid.xml": ["gridTitle", "gridMeta", "gridStars"],
    "_inc/gamelist-card.xml": ["cardTitle", "cardGenre", "cardPlayers", "cardMeta2", "cardStars", "cardDesc"],
    "_inc/gamelist-list.xml": ["listYearDev", "listMeta", "listStars", "listDesc"],
}

repo_root = sys.argv[1]
failures = []
for relpath, names in EXPECT.items():
    root = ET.parse(f"{repo_root}/{relpath}").getroot()
    for name in names:
        el = root.find(f".//text[@name='{name}']")
        if el is None:
            failures.append(f"{relpath}: no <text name='{name}'>")
            continue
        val = el.findtext("emptyTextDefaults")
        if val != "false":
            failures.append(f"{relpath}: {name} has emptyTextDefaults={val!r}, want 'false'")

if failures:
    print("\n".join(failures), file=sys.stderr)
    sys.exit(1)
INNER_PY
check "every {game:*}-binding text element disables emptyTextDefaults" $?

# #41. snapshotSource / showSnapshotDelay / showSnapshotNoVideo are parsed for
# ANY <video> (VideoComponent.cpp:285-310) but only ever ACTED ON for the view's
# built-in md_video: the snapshot's path is fed in by
# DetailedContainer::updateControls, which only knows about its own mVideo
# (DetailedContainer.cpp:786-807). An extra video's {game:video} binding reaches
# setVideo() alone (VideoComponent::setProperty, :589), so its mStaticImage
# never gets a path and the still simply does not draw -- silently, and only for
# the delay window, which is exactly the kind of thing a single render misses.
#
# Splitting the slot back into an image + a video is the other half of the same
# trap: <maxSize> preserves each FILE's aspect, so the two land on different
# rectangles and the still's edges show around the video.
#
# So: the media slot is md_video, and no extra video may claim to do snapshots.
python3 - "${REPO_ROOT}" <<'INNER_PY'
import sys, xml.etree.ElementTree as ET

SNAPSHOT_PROPS = ("snapshotSource", "showSnapshotDelay", "showSnapshotNoVideo")
# style file -> does this style show a preview video at all?
STYLES = {
    "_inc/gamelist-card.xml": True,
    "_inc/gamelist-list.xml": True,
    "_inc/gamelist-grid.xml": False,   # art-first; no media slot
}

repo_root = sys.argv[1]
failures = []
for relpath, has_media in STYLES.items():
    root = ET.parse(f"{repo_root}/{relpath}").getroot()
    videos = root.findall(".//video")

    for v in videos:
        name = v.get("name")
        claims = [p for p in SNAPSHOT_PROPS if v.findtext(p) is not None]
        if claims and name != "md_video":
            failures.append(
                f"{relpath}: <video name='{name}'> sets {', '.join(claims)}, "
                "which ES only honours on md_video")
        if name == "md_video" and v.get("extra") == "true":
            failures.append(f"{relpath}: md_video must not be extra='true'")

    # An extra video bound to {game:video} is a media slot by another name.
    strays = [v.get("name") for v in videos
              if v.get("extra") == "true" and (v.findtext("path") or "").strip() == "{game:video}"]
    if strays:
        failures.append(
            f"{relpath}: extra video(s) {strays} bind {{game:video}} -- the media "
            "slot must be md_video so the still and the clip share one rectangle")

    md = root.find(".//video[@name='md_video']")
    if md is None:
        failures.append(f"{relpath}: no md_video declaration at all")
    elif has_media:
        if md.findtext("visible") == "false":
            failures.append(f"{relpath}: md_video is hidden, but this style has a media slot")
        for p in SNAPSHOT_PROPS:
            if md.findtext(p) is None:
                failures.append(f"{relpath}: md_video does not set {p}")
    elif md.findtext("visible") != "false":
        failures.append(f"{relpath}: md_video must stay hidden in a style with no media slot")

if failures:
    print("\n".join(failures), file=sys.stderr)
    sys.exit(1)
INNER_PY
check "the media slot is md_video, and no extra video claims snapshot handling" $?

echo
echo "per-aspect overrides:"

for ratio in 8x7 3x2 16x9 1x1; do
  f="${REPO_ROOT}/_inc/aspect-${ratio}.xml"

  grep -q 'cardMediaW' "${f}"
  check "aspect-${ratio}.xml sets cardMediaW" $?

  # Every ratio that changes cardMetaFontSize MUST re-check the star budget,
  # or a wider track runs into the players column. Must use THIS ratio's own
  # (w, h) design surface, not 4:3's -- fontSize is height-normalised, so
  # computing at the wrong dimensions understates/overstates the track and
  # can silently pass a genuinely colliding layout.
  python3 - "${ratio}" "${f}" "${REPO_ROOT}/_inc/common.xml" <<'PY'
import sys, re
def vals(path):
    t = open(path).read()
    return {k: v for k, v in re.findall(r"<(card(?:MetaFontSize|StarX|PlayersX))>([^<]+)<", t)}
ratio = sys.argv[1]
override, base = vals(sys.argv[2]), vals(sys.argv[3])
fs = float(override.get("cardMetaFontSize", base["cardMetaFontSize"]))
sx = float(override.get("cardStarX", base["cardStarX"]))
px = float(override.get("cardPlayersX", base["cardPlayersX"]))
# (width, height) of each ratio's design surface, matching the render matrix.
DIMS = {"8x7": (1024, 896), "3x2": (1280, 854), "16x9": (1280, 720), "1x1": (720, 720)}
w_screen, h_screen = DIMS[ratio]
glyph_w = fs * 0.85 * h_screen
track = (5 * glyph_w + 4 * glyph_w * 0.25) / w_screen
# A bare '<' is satisfied by a layout that is visually touching (zero
# clearance is not clearance). MIN_COL_GAP demands real, measurable margin.
MIN_COL_GAP = 0.010  # normalized; a bare '<' let 8x7 pass by 0.05px
assert sx + track + MIN_COL_GAP < px, (
    f"{sys.argv[2]}: track {sx:.3f}..{sx+track:.3f} collides with players at {px}")
PY
  check "aspect-${ratio}.xml star budget holds" $?
done

echo
echo "style B list-style star/meta budget:"

# listStars/listStarTrack take their size from ${listMetaFontSize} (#42;
# before that it was a literal 0.028 on each element, which could not be
# overridden per ratio at all). The track's pixel width scales with screen
# HEIGHT while listStarX/listMetaX are fractions of WIDTH, so the squarer the
# surface the larger the track's share of the gap between the two columns --
# a ratio can collide with no fontSize change at all. Render verification
# caught this touching/overlapping at 1024x896 and 720x720.
python3 - "${REPO_ROOT}" <<'PY'
import re, sys

repo = sys.argv[1]
list_xml = open(f"{repo}/_inc/gamelist-list.xml").read()
size_expr = re.search(r'name="listStars".*?<fontSize>([^<]+)<', list_xml, re.S).group(1)
assert size_expr == "${listMetaFontSize}", (
    f"listStars fontSize is {size_expr!r}; this guard resolves "
    "${listMetaFontSize} and would silently skip a literal")

common = open(f"{repo}/_inc/common.xml").read()
base = dict(re.findall(r"<(listStarX|listMetaX|listMetaFontSize)>([^<]+)<", common))

# (width, height) of each ratio's design surface, matching the render matrix.
# 4:3 has no aspect file and was originally left out of this loop entirely --
# so the ratio the theme SHIPS at, and the one the TrimUI Brick runs, was the
# only one the list budget never checked. The card guard above tests it
# explicitly; this one now does too, with an empty override map.
DIMS = {"4:3": (1024, 768), "8x7": (1024, 896), "3x2": (1280, 854),
        "16x9": (1280, 720), "1x1": (720, 720)}

failures = []
for ratio, (w, h) in DIMS.items():
    override = {} if ratio == "4:3" else dict(re.findall(
        r"<(listStarX|listMetaX|listMetaFontSize)>([^<]+)<",
        open(f"{repo}/_inc/aspect-{ratio}.xml").read()))
    sx = float(override.get("listStarX", base["listStarX"]))
    mx = float(override.get("listMetaX", base["listMetaX"]))
    fs = float(override.get("listMetaFontSize", base["listMetaFontSize"]))
    glyph_w = fs * 0.85 * h
    track = (5 * glyph_w + 4 * glyph_w * 0.25) / w
    # A bare '<' is satisfied by a layout that is visually touching (zero
    # clearance is not clearance). MIN_COL_GAP demands real, measurable
    # margin -- without it, the un-overridden base listStarX (0.575) at 8x7
    # computes end=0.69995 against listMetaX=0.700 and passes by 0.05px.
    MIN_COL_GAP = 0.010  # normalized
    if not (sx + track + MIN_COL_GAP < mx):
        failures.append(
            f"aspect-{ratio}.xml: list star track {sx:.3f}..{sx+track:.3f} "
            f"collides with listMeta at {mx}")

if failures:
    print("\n".join(failures), file=sys.stderr)
    sys.exit(1)
PY
check "list style star track clears listMeta at every ratio" $?

echo
echo "guard: no duplicate variable declarations:"

python3 - "${REPO_ROOT}/_inc/common.xml" <<'PY'
import sys, xml.etree.ElementTree as ET

root = ET.parse(sys.argv[1]).getroot()
all_vars = []
for var_block in root.findall("variables"):
    for child in var_block:
        # Direct children of <variables> are simple variable declarations.
        # Skip any that are not simple text elements (comments, etc.).
        all_vars.append(child.tag)

duplicates = []
seen = {}
for var in all_vars:
    if var in seen:
        if var not in duplicates:
            duplicates.append(var)
    else:
        seen[var] = True

assert not duplicates, f"Duplicate variable declarations: {', '.join(sorted(set(duplicates)))}"
PY
check "no variable is declared more than once in <variables> blocks" $?

echo
echo "docs and subset fold:"

GUIDE="${REPO_ROOT}/docs/psp-xmb-style-guidelines.md"

grep -q 'gamelistStyle' "${GUIDE}"
check "style guide §8 documents the gamelistStyle subset" $?

# A plain `grep -qi supersede "${GUIDE}"` passes before any implementation
# work: "superseded" already appears elsewhere in the guide (§1.3's "Largely
# superseded", §7.4/§7.5's own "Superseded in v0.12" markers), so that check
# is a false-positive proxy, not a real assertion. Scope it to the §10 table
# and require the two rows this task's §10 rewrite actually produced.
SEC10="$(sed -n '/^## 10\. Settled decisions/,/^## 11\./p' "${GUIDE}")"

grep -q 'Single PSP-card gamelist.*Superseded in v0\.12' <<<"${SEC10}"
check "§10 records the single-PSP-card-gamelist decision as superseded" $?

grep -q 'Three visible game rows.*style A only' <<<"${SEC10}"
check "§10 scopes the three-visible-rows decision to style A" $?

# The old subsets were flagged as no-ops in §8; they must now be real.
grep -q 'videoAudioEnabled' "${REPO_ROOT}/_inc/video-audio-on.xml"
check "videoAudio subset sets videoAudioEnabled" $?

# The subset must work through ${videoAudioEnabled}, not by overriding a video
# element -- when it did the latter the target was hidden and the subset was a
# no-op. A bare `grep -q md_video` would be a false positive on any comment
# that merely NAMES the element, so assert the structure: no <video> element in
# either variant file, and the variable set in both.
python3 - "${REPO_ROOT}" <<'INNER_PY'
import sys, xml.etree.ElementTree as ET
failures = []
for rel, want in (("_inc/video-audio-on.xml", "true"), ("_inc/video-audio-off.xml", "false")):
    root = ET.parse(f"{sys.argv[1]}/{rel}").getroot()
    if root.findall(".//video"):
        failures.append(f"{rel}: declares a <video> element; it must only set the variable")
    got = root.findtext(".//variables/videoAudioEnabled")
    if got != want:
        failures.append(f"{rel}: videoAudioEnabled is {got!r}, want {want!r}")
if failures:
    print("\n".join(failures), file=sys.stderr)
    sys.exit(1)
INNER_PY
check "videoAudio drives the media slot through \${videoAudioEnabled}, not a video override" $?

grep -q 'Gamelist Style' "${REPO_ROOT}/README.md"
check "README documents the Gamelist Style knob" $?

exit "${fail}"
