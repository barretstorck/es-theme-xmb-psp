#!/usr/bin/env bash
# Structural test for the Box Art Grid's selection cue and info bar (issue #43).
#
# Every fault this guards against was SILENT on this ES build — nothing logged,
# and each one looked plausible in a screenshot:
#
#  * `art/line-1px.png` used as the info-bar fill. That asset is 256x4 with
#    rows 0 and 3 fully TRANSPARENT (bleed rows that make it a crisp hairline
#    where it is used as a rule). Stretched to a 0.110-tall panel, only the
#    middle 50% is opaque, so the bar drew at 0.8229-0.8776 instead of the
#    declared 0.795-0.905 and the metadata row fell outside it. Hence the
#    opacity guard below: any fill asset must be opaque in EVERY row.
#  * `gridTileW`/`gridTileH` looked load-bearing but are dead. With
#    <autoLayout> set, ImageGridComponent::calcGridDimension (:1442-1447)
#    overwrites mTileSize from mSize/autoLayout, discarding <gridtile><size>.
#  * The grid rect is its own render clip (ImageGridComponent.h:733), so a
#    zoomed tile in the top row was cut flat at the grid edge. The fix is
#    <padding> equal to the zoom overhang, with pos/size grown to match — which
#    leaves four literals that must stay consistent with margin and zoom. The
#    geometry section below recomputes them rather than trusting them.
#  * Deleting `backgroundColor` does NOT remove the tile background. It falls
#    back to `:/frame.png` tinted 0xAAAAEEFF on the default tile and
#    0xFFFFFFFF on the selected one (GridTileComponent.cpp:67 sets only
#    mDefaultProperties), and renderBackground draws unconditionally. Both
#    states must therefore set a fully transparent colour explicitly.
#
# NOTE: deliberately NOT `set -e` — see the note in test-gamelist-styles.sh.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
fail=0
check() { # check <description> <condition-exit-code>
  if [[ "$2" -eq 0 ]]; then echo "  ok   - $1"; else echo "  FAIL - $1"; fi
  [[ "$2" -eq 0 ]] || fail=1
}

GRID="${REPO_ROOT}/_inc/gamelist-grid.xml"
COMMON="${REPO_ROOT}/_inc/common.xml"

# `check "$(cmd)" $?` would report the SUBSTITUTION's status, because bash
# expands arguments left to right — so each python guard below stores its exit
# status in `rc` on its own line and passes that.
echo "selection cue is size only:"

# Unselected tiles must not be dimmed. imageColor's alpha is the fade.
grep -qE '<imageColor>FFFFFFFF</imageColor>' "${GRID}"
check "some gridtile sets imageColor to fully opaque white" $?

python3 - "${GRID}" <<'PY'; rc=$?
import re, sys, xml.etree.ElementTree as ET
root = ET.parse(sys.argv[1]).getroot()
view = root.find("view")
tiles = {t.get("name"): t for t in view.findall("gridtile")}
bad = []
for name in ("default", "selected"):
    t = tiles.get(name)
    if t is None:
        bad.append(f"{name}: no <gridtile> declared"); continue
    ic = t.findtext("imageColor")
    if name == "default" and (ic is None or ic.upper() != "FFFFFFFF"):
        bad.append(f"default imageColor={ic!r}, want FFFFFFFF (any other alpha fades unselected tiles)")
    bc = t.findtext("backgroundColor")
    if bc is None:
        bad.append(f"{name}: no backgroundColor — ES falls back to :/frame.png, which still draws")
    elif not re.fullmatch(r"[0-9A-Fa-f]{6}00", bc or ""):
        bad.append(f"{name} backgroundColor={bc!r}, want a RRGGBB00 (alpha 00) value")
    if t.find("backgroundCornerSize") is not None:
        bad.append(f"{name}: backgroundCornerSize is left over from the filled-box selector")
for b in bad:
    print("        " + b, file=sys.stderr)
sys.exit(1 if bad else 0)
PY
check "both gridtiles suppress the background explicitly; no fade, no corner size" "${rc}"

grep -qE '<animateSelection>true</animateSelection>' "${GRID}"
check "animateSelection stays true — the size change is animated" $?

echo
echo "grid geometry: rect, margin, padding and zoom stay mutually consistent:"

# The single source of truth for this style's geometry. The tiles occupy the
# cell band below; the imagegrid rect is that band grown by the zoom overhang
# on every side, with <padding> equal to the growth so the cells do not move
# (startPosition = mTileSize/2 + mPadding, ImageGridComponent.h:283).
python3 - "${GRID}" <<'PY'; rc=$?
import sys, xml.etree.ElementTree as ET

CELL_X, CELL_W = 0.04, 0.92     # band the tiles occupy, unchanged since v0.12
CELL_Y, CELL_H = 0.16, 0.60
COLS, ROWS = 4, 2
PANEL_TOP = 0.795               # gridInfoY; the enlarged bottom row must clear it
TOL = 5e-5                      # literals are the computed values at 4 decimals

root = ET.parse(sys.argv[1]).getroot()
grid = root.find("view").find("imagegrid")
if grid is None:
    print("        no <imagegrid> element", file=sys.stderr); sys.exit(1)

def vec(tag, n):
    txt = grid.findtext(tag)
    if txt is None:
        raise SystemExit(f"        <imagegrid> has no <{tag}>")
    parts = [float(v) for v in txt.split()]
    if len(parts) != n:
        raise SystemExit(f"        <{tag}> wants {n} numbers, got {txt!r}")
    return parts

pos, size, pad, margin = vec("pos", 2), vec("size", 2), vec("padding", 4), vec("margin", 2)
zoom = float(grid.findtext("autoLayoutSelectedZoom"))
bad = []

# What ES will actually compute for a tile, from the declared rect.
tile_w = (size[0] - margin[0] * (COLS - 1) - pad[0] - pad[2]) / COLS
tile_h = (size[1] - margin[1] * (ROWS - 1) - pad[1] - pad[3]) / ROWS
want_w = (CELL_W - margin[0] * (COLS - 1)) / COLS
want_h = (CELL_H - margin[1] * (ROWS - 1)) / ROWS
if abs(tile_w - want_w) > TOL:
    bad.append(f"tile width resolves to {tile_w:.6f}, cell band wants {want_w:.6f}")
if abs(tile_h - want_h) > TOL:
    bad.append(f"tile height resolves to {tile_h:.6f}, cell band wants {want_h:.6f}")

# Cells must land back on the band: first cell centre = pos + pad + tile/2.
for axis, p, pd, t, c in ((0, pos[0], pad[0], tile_w, CELL_X), (1, pos[1], pad[1], tile_h, CELL_Y)):
    got = p + pd
    if abs(got - c) > TOL:
        bad.append(f"cell band starts at {got:.6f} on axis {axis}, want {c:.6f}")

# Padding must cover the zoom overhang, or the grid rect clips the selected tile.
for axis, pd, t in ((0, pad[0], tile_w), (1, pad[1], tile_h)):
    need = (zoom - 1) * t / 2
    if pd + TOL < need:
        bad.append(f"padding {pd:.6f} on axis {axis} is below the {need:.6f} zoom overhang — tile will be clipped")
    if pd > need + 0.002:
        bad.append(f"padding {pd:.6f} on axis {axis} far exceeds the {need:.6f} overhang — dead space")
if abs(pad[0] - pad[2]) > TOL or abs(pad[1] - pad[3]) > TOL:
    bad.append("padding is not symmetric; the zoom grows in both directions")

# Neighbour clearance. maxSize-fit art fills its cell in the binding axis, so
# the worst case per axis is art as large as the cell in that axis.
for axis, m, t, name in ((0, margin[0], tile_w, "horizontal"), (1, margin[1], tile_h, "vertical")):
    gap = (t + m) - t * (zoom + 1) / 2
    if gap <= 0:
        bad.append(f"{name} gap is {gap:.6f} at zoom {zoom}: the selected tile overlaps its neighbour")

# On-screen, and clear of the info bar.
if pos[0] < 0 or pos[1] < 0:
    bad.append(f"grid rect starts off screen at {pos}")
if pos[0] + size[0] > 1.0 + TOL or pos[1] + size[1] > 1.0 + TOL:
    bad.append(f"grid rect ends off screen at {pos[0]+size[0]:.4f},{pos[1]+size[1]:.4f}")
bottom = CELL_Y + CELL_H + (zoom - 1) * tile_h / 2
if bottom > PANEL_TOP:
    bad.append(f"enlarged bottom-row tile reaches {bottom:.6f}, past the info bar at {PANEL_TOP}")

for b in bad:
    print("        " + b, file=sys.stderr)
sys.exit(1 if bad else 0)
PY
check "imagegrid rect/padding/margin/zoom are self-consistent and collision-free" "${rc}"

echo
echo "the dead per-ratio tile variables are gone:"

# gridTileW/gridTileH are ignored whenever <autoLayout> is set. Overriding them
# per ratio is what made issue #43 believe the tiles differ by aspect ratio.
offenders="$(grep -l 'gridTile[WH]' "${REPO_ROOT}"/_inc/aspect-*.xml 2>/dev/null)"
[[ -z "${offenders}" ]]
check "no aspect-*.xml overrides gridTileW or gridTileH" $?
[[ -z "${offenders}" ]] || { echo "        still overridden in:" >&2; sed 's|^|          |' <<<"${offenders}" >&2; }

grep -q 'autoLayout' "${GRID}"
check "the grid still uses autoLayout (which is what makes those variables dead)" $?

echo
echo "info bar: an opaque fill, sized to hold its text:"

panel_path="$(sed -n '/<image name="gridInfoPanel"/,/<\/image>/p' "${GRID}" \
  | sed -n 's|.*<path>\./\(.*\)</path>.*|\1|p')"
[[ -n "${panel_path}" ]]
check "gridInfoPanel declares a <path>" $?

[[ "${panel_path}" != "art/line-1px.png" ]]
check "gridInfoPanel does not use the hairline asset as a fill" $?

python3 - "${REPO_ROOT}/${panel_path}" <<'PY'; rc=$?
import sys
from PIL import Image
im = Image.open(sys.argv[1]).convert("RGBA")
w, h = im.size
thin = [y for y in range(h) if min(im.getpixel((x, y))[3] for x in range(w)) < 255]
if thin:
    print(f"        rows with transparency: {thin} of {h} — a stretched fill would render "
          f"only its opaque band, at {(h-len(thin))/h:.0%} of the declared height",
          file=sys.stderr)
sys.exit(1 if thin else 0)
PY
check "the info-bar fill asset is opaque in every row" "${rc}"

python3 - "${GRID}" "${COMMON}" <<'PY'; rc=$?
import re, sys, xml.etree.ElementTree as ET

grid_path, common_path = sys.argv[1], sys.argv[2]
# Resolve ${vars} from common.xml so the guard reads the same numbers ES will.
vars_ = {}
croot = ET.parse(common_path).getroot()
for block in croot.findall("variables"):
    for el in block:
        if el.text:
            vars_[el.tag] = el.text.strip()

def resolve(txt):
    if txt is None:
        return None
    out = re.sub(r"\$\{([A-Za-z0-9_.]+)\}", lambda m: vars_.get(m.group(1), m.group(0)), txt)
    return None if "${" in out else out

def nums(txt, n):
    vals = [float(v) for v in (txt or "").split()]
    return vals if len(vals) == n else None

view = ET.parse(grid_path).getroot().find("view")
els = {}
for el in view:
    if el.get("name"):
        els[el.get("name")] = el

bad = []
panel = els.get("gridInfoPanel")
p_pos = nums(resolve(panel.findtext("pos")), 2) if panel is not None else None
p_size = nums(resolve(panel.findtext("size")), 2) if panel is not None else None
if not p_pos or not p_size:
    bad.append("gridInfoPanel pos/size do not resolve to numbers")
else:
    p_top, p_bottom = p_pos[1], p_pos[1] + p_size[1]
    p_left, p_right = p_pos[0], p_pos[0] + p_size[0]

    # Every text element in the bar must be bounded AND inside the bar.
    for name in ("gridTitle", "gridMeta", "gridStarTrack", "gridStars"):
        el = els.get(name)
        if el is None:
            bad.append(f"{name} is missing"); continue
        if nums(resolve(el.findtext("size")), 2) is None:
            bad.append(f"{name} has no resolvable <size>")
        clip = nums(resolve(el.findtext("clipRect")), 4)
        if clip is None:
            bad.append(f"{name} has no clipRect — <size> alone does not clip on this build")
            continue
        cx, cy, cw, ch = clip
        if cy < p_top - 1e-9 or cy + ch > p_bottom + 1e-9:
            bad.append(f"{name} clipRect spans {cy:.4f}-{cy+ch:.4f}, outside the bar {p_top:.4f}-{p_bottom:.4f}")
        if cx < p_left - 1e-9 or cx + cw > p_right + 1e-9:
            bad.append(f"{name} clipRect spans {cx:.4f}-{cx+cw:.4f}, outside the bar {p_left:.4f}-{p_right:.4f}")

    # The metadata run must stop before the star column, which is what makes a
    # long genre/developer string structurally unable to collide with it.
    def clip_of(name):
        el = els.get(name)
        return None if el is None else nums(resolve(el.findtext("clipRect")), 4)
    meta, star = clip_of("gridMeta"), clip_of("gridStars")
    if meta and star and meta[0] + meta[2] > star[0] + 1e-9:
        bad.append(f"gridMeta clipRect reaches {meta[0]+meta[2]:.4f}, at or past the star column at {star[0]:.4f}")

for b in bad:
    print("        " + b, file=sys.stderr)
sys.exit(1 if bad else 0)
PY
check "every info-bar text element is bounded and sits inside the bar" "${rc}"

echo
echo "a fixture can actually show the title overflow:"

# The longest name in the real /tmp/library slice is 44 characters, which fits
# the title box — so without a deliberate fixture the clipRect is untested.
python3 - "${REPO_ROOT}/tests/fixtures/library" <<'PY'; rc=$?
import glob, sys, xml.etree.ElementTree as ET
LIMIT = 70
longest = ("", 0)
for f in glob.glob(sys.argv[1] + "/*/gamelist.xml"):
    for g in ET.parse(f).getroot().findall("game"):
        n = g.findtext("name") or ""
        if len(n) > longest[1]:
            longest = (n, len(n))
if longest[1] < LIMIT:
    print(f"        longest fixture title is {longest[1]} chars ({longest[0]!r}); "
          f"want >= {LIMIT} to overflow the title box", file=sys.stderr)
    sys.exit(1)
if not any(c in longest[0] for c in "gjpqy"):
    print(f"        {longest[0]!r} has no descender; the clipRect height is untested",
          file=sys.stderr)
    sys.exit(1)
PY
check "a fixture game has a title long enough (with descenders) to overflow" "${rc}"

echo
echo "the theme files still parse:"

# `--` inside an XML comment is illegal XML, and pugixml (what ES uses) accepts
# it — so a malformed file renders fine on device and only breaks tooling.
for f in "${GRID}" "${COMMON}" "${REPO_ROOT}"/_inc/aspect-*.xml; do
  python3 -c 'import sys,xml.etree.ElementTree as ET; ET.parse(sys.argv[1])' "${f}" 2>/dev/null
  check "${f#${REPO_ROOT}/} parses as strict XML" $?
done

echo
if [[ "${fail}" -eq 0 ]]; then echo "all checks passed"; else echo "FAILURES"; fi
exit "${fail}"
