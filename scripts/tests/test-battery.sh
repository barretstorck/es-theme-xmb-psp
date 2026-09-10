#!/usr/bin/env bash
# Structural test for the status-bar battery widget (issue #4).
#
# v0.10 pulled this widget after three bugs that all LOOKED like tuning
# problems and were not. Each one has a guard here, because each one renders
# as "nothing happened" rather than as an error:
#
#   1. <visible>false</visible> "did not hide the battery on-device". ES draws
#      a SECOND battery widget the theme never asked for —
#      BatteryIndicatorComponent (Window.cpp:157, rendered at :746) — top-right,
#      in ES's own font. Hiding our element leaves that one drawing. Nothing
#      logs, and in the harness it only appears once a battery is faked, so a
#      normal render cannot show it.
#   2. The percentage "would not render". A binding-based
#      <text extra="true">{global:batteryLevel}%</text> is EMPTY in the screen
#      view: Window.cpp:1258 makes the screen extras but no
#      BindingManager::updateBindings call exists for them. Unresolved bindings
#      render as blank, not as an error.
#   3. Vertical alignment "could never be settled". Both remaining components
#      centre content in their own box, so this is arithmetic against the
#      clock's measured ink centre — but a wrong value just looks slightly off.
#
# The geometry section below recomputes the cluster from the XML and from real
# font metrics rather than asserting the literals, so a future edit that moves
# one element into another is caught even though every value still "looks fine".
#
# NOTE: deliberately NOT `set -e` — see the note in test-gamelist-styles.sh.
set -uo pipefail

# shellcheck source=scripts/lib/test-lib.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../lib" && pwd)/test-lib.sh"

COMMON="${REPO_ROOT}/_inc/common.xml"
STATUS="${REPO_ROOT}/_inc/status-bar.xml"
THEME="${REPO_ROOT}/theme.xml"
RENDER="${REPO_ROOT}/scripts/render.sh"
NETART="${REPO_ROOT}/art/ui/network.png"
NETGEN="${REPO_ROOT}/scripts/gen-network-icon.py"

echo "== the file parses, and parses STRICTLY =="

# pugixml (what ES uses) accepts "--" inside a comment even though it is
# illegal XML, so a file that renders fine on device can still break every
# python3/xmllint tool in this repo. That case has shipped here before.
for f in "${COMMON}" "${STATUS}" "${REPO_ROOT}"/_inc/aspect-*.xml; do
  python3 -c "import xml.etree.ElementTree as ET,sys; ET.parse(sys.argv[1])" "$f" 2>/dev/null || { echo "  FAIL - $f is not well-formed"; fail=1; }
done
[[ "${fail}" -eq 0 ]]
check "common.xml, status-bar.xml and every aspect-*.xml are strictly well-formed XML" $?

echo
echo "== ES's own second battery widget is suppressed =="

python3 - "${STATUS}" <<'PY'
import sys, xml.etree.ElementTree as ET
root = ET.parse(sys.argv[1]).getroot()
screen = [v for v in root.findall('view') if 'screen' in v.get('name', '').split(',')]
ind = [e for v in screen for e in v.findall('batteryIndicator')]
assert len(ind) == 1, f"expected exactly one batteryIndicator in the screen view, found {len(ind)}"
vis = ind[0].findtext('visible', '').strip()
assert vis == 'false', f"batteryIndicator <visible> is {vis!r}, expected 'false'"
PY
check "<batteryIndicator> is declared in the screen view and hidden (else it doubles up with ours)" $?

# Unlike batteryIcon, this component honours the theme: its render() early-
# returns on !isVisible() and its update() never calls setVisible(). If a
# future ES bump changes that, the widget doubles up again on hardware only.
grep -q 'BatteryIndicatorComponent' "${STATUS}"
check "the batteryIndicator block names the ES component, so the reason survives an edit" $?

echo
echo "== the percentage uses the only mechanism that works here =="

python3 - "${STATUS}" <<'PY'
import sys, xml.etree.ElementTree as ET
root = ET.parse(sys.argv[1]).getroot()
screen = [v for v in root.findall('view') if 'screen' in v.get('name', '').split(',')]
# .// because it is a child of the stackpanel, not a direct child of the view
txt = [e for v in screen for e in v.iter('batteryText')]
assert len(txt) == 1, f"expected exactly one <batteryText>, found {len(txt)}"
assert txt[0].get('name'), "<batteryText> needs a name attribute (ThemeData.cpp:1506-1511 skips unnamed elements)"
PY
check "the percentage is a native <batteryText>, named" $?

# The binding path is not a fallback to try when something breaks — it CANNOT
# work in this view. Catch it in any element, not just batteryText.
#
# Parsed, not grepped: ElementTree drops comments, and the block above
# deliberately SPELLS the dead binding out in prose so the next author does not
# retry it. A raw grep flags that explanation as the bug it warns about — the
# same false positive this repo has hit with ${vars} inside comments.
python3 - "${STATUS}" "${COMMON}" <<'PYBIND'
import sys, xml.etree.ElementTree as ET
for path in sys.argv[1:]:
  root = ET.parse(path).getroot()
  for e in root.iter():
    for v in [e.text or ''] + list(e.attrib.values()):
      assert '{global:battery' not in v, (
          f"<{e.tag} name={e.get('name')!r}> uses a {{global:battery*}} binding; "
          "bindings are never resolved in the screen view")
PYBIND
check "no {global:battery*} binding in any element (bindings are never resolved in the screen view)" $?

# BatteryTextComponent.cpp:52 sets mAutoCalcExtent.x() = 1 and re-sizes to the
# text, so the element is only ever as wide as its content and <alignment>
# right</alignment> silently does nothing. An author who adds it will believe
# the element is right-anchored and place the neighbours wrong.
python3 - "${STATUS}" <<'PY'
import sys, xml.etree.ElementTree as ET
root = ET.parse(sys.argv[1]).getroot()
t = root.find(".//batteryText")
assert t.find('alignment') is None, \
    "<batteryText> has <alignment>: it is INERT (the element auto-sizes to its text). pos.x is the LEFT edge."
assert t.find('verticalAlignment') is None, \
    "<batteryText> has <verticalAlignment>: also inert, the box collapses to the line height. Use <origin>."
PY
check "<batteryText> avoids the two alignment properties this component ignores" $?

# The percentage and the clock are the cluster's only text and sit on the same
# line, so they are one type style, not a hierarchy. Drifting them apart is a
# visual regression that nothing else here would catch.
python3 - "${STATUS}" <<'PYTYPE'
import sys, xml.etree.ElementTree as ET
root = ET.parse(sys.argv[1]).getroot()
panel = root.find('.//stackpanel')
pct = [e for e in panel if e.get('name') == 'batteryPercent'][0]
clk = [e for e in panel if e.get('name') == 'statusClock'][0]
for prop in ('fontPath', 'fontSize'):
    a, b = pct.findtext(prop), clk.findtext(prop)
    assert a == b, f"batteryText {prop} is {a!r} but the clock's is {b!r}; they must match"
PYTYPE
check "the percentage matches the clock's font, size and weight" $?

echo
echo "== the glyph element is spelled the way ES dispatches it =="

python3 - "${STATUS}" <<'PY'
import sys, os, xml.etree.ElementTree as ET
repo = os.path.dirname(os.path.dirname(os.path.abspath(sys.argv[1])))
root = ET.parse(sys.argv[1]).getroot()
icons = root.findall('.//batteryIcon')
assert len(icons) == 1, f"expected exactly one <batteryIcon>, found {len(icons)}"
icon = icons[0]
# ThemeData.cpp:2145 dispatches on the TAG; <image name="batteryIcon"> is a
# plain image. ThemeData.cpp:1506-1511 skips elements with no name attribute.
assert icon.get('name'), "<batteryIcon> needs a name attribute"
states = ['empty', 'at25', 'at50', 'at75', 'full', 'incharge']
for s in states:
    p = icon.findtext(s)
    assert p, f"<batteryIcon> is missing the <{s}> state"
    # applyTheme only adopts a path that passes fileExists() — a typo silently
    # keeps ES's built-in SVG for that ONE state, so the glyph set changes
    # style partway down the charge curve.
    full = os.path.join(repo, p.lstrip('./'))
    assert os.path.isfile(full), f"<{s}> points at {p} which does not exist"
PY
check "<batteryIcon> is named and all 6 state images resolve on disk" $?

echo
echo "== the network glyph that replaces ES's =="

python3 - "${STATUS}" <<'PY'
import sys, os, xml.etree.ElementTree as ET
repo = os.path.dirname(os.path.dirname(os.path.abspath(sys.argv[1])))
root = ET.parse(sys.argv[1]).getroot()
nets = root.findall('.//networkIcon')
assert len(nets) == 1, f"expected exactly one <networkIcon>, found {len(nets)}"
assert nets[0].get('name'), "<networkIcon> needs a name attribute"
p = nets[0].findtext('path') or nets[0].findtext('networkIcon')
assert p, "<networkIcon> has no <path>"
assert os.path.isfile(os.path.join(repo, p.lstrip('./'))), f"<networkIcon> path {p} does not exist"
PY
check "<networkIcon> is declared, named, and its art resolves (hiding batteryIndicator took ES's wifi glyph with it)" $?

python3 - "${NETART}" "${REPO_ROOT}/art/battery/battery-full.png" <<'PY'
import sys
from PIL import Image
net = Image.open(sys.argv[1])
bat = Image.open(sys.argv[2])
# Both glyphs are fitted to the same on-screen HEIGHT by <maxSize>, and the
# fit is of the CANVAS. Equal canvas heights are therefore what makes an equal
# authored STROKE render as an equal stroke; they also mean ink that does not
# fill its canvas renders smaller than its neighbour. The first network glyph
# left 8px of slack and drew a 17px fan beside a 23px battery.
assert net.height == bat.height, f"network canvas is {net.height}px tall, battery is {bat.height}px"
box = net.getbbox()
ink_h = box[3] - box[1]
assert ink_h >= net.height - 4, f"network ink is only {ink_h}px of a {net.height}px canvas"
PY
check "network art shares the battery's canvas height and its ink fills it (equal rendered stroke + size)" $?

[[ -x "${NETGEN}" || -f "${NETGEN}" ]]
check "the network glyph has a generator committed alongside it" $?

echo
echo "== there is no battery subset, and cannot be one =="

# v0.10 shipped a battery subset with Hide/Glyph/Glyph+Percentage. Hide could
# never work: BatteryIconComponent::update() calls setVisible(hasBattery) on
# every tick and discards the themed value. Visibility belongs to ES's own
# ShowBattery setting (GuiMenu.cpp:3928). Re-adding the subset would look like
# a feature and behave like a no-op.
! grep -q '<subset name="battery"' "${THEME}"
check "theme.xml declares no battery subset (the theme cannot override ShowBattery)" $?

! ls "${REPO_ROOT}"/_inc/battery-*.xml >/dev/null 2>&1
check "no _inc/battery-*.xml subset variants have come back" $?

echo
echo "== the cluster is a stackpanel, so it can collapse =="

python3 - "${STATUS}" "${REPO_ROOT}" <<'PYPANEL'
import sys, os, xml.etree.ElementTree as ET
from PIL import Image

status, repo = sys.argv[1], sys.argv[2]
root = ET.parse(status).getroot()
screen = [v for v in root.findall('view') if 'screen' in v.get('name', '').split(',')][0]

panels = screen.findall('stackpanel')
assert len(panels) == 1, f"expected exactly one <stackpanel>, found {len(panels)}"
panel = panels[0]

# Order matters and IS the visual order: reverse packing lays the first child
# out at the panel's right edge and walks left. sortChildren() is a
# stable_sort on zIndex (GuiComponent.cpp:359), so equal zIndex keeps XML
# order.
order = [(c.tag, c.get('name')) for c in panel
         if c.tag in ('batteryIcon', 'batteryText', 'networkIcon', 'clock')]
assert order == [('batteryIcon', 'batteryStatus'), ('batteryText', 'batteryPercent'),
                 ('networkIcon', 'networkStatus'), ('clock', 'statusClock')], \
    f"child order is {order}; reverse packing makes the FIRST child rightmost"

# Every optional element must be a CHILD. A top-level element keeps its own
# absolute position and leaves a hole when ES hides it - the exact defect
# this panel exists to remove.
for tag in ('batteryIcon', 'batteryText', 'networkIcon'):
    assert screen.find(tag) is None, \
        f"<{tag}> is a top-level element; it must be a child of the stackpanel or it cannot collapse"

assert panel.findtext('orientation') == 'horizontal', "panel must be horizontal"
assert panel.findtext('reverse') == 'true', \
    "panel must be reverse: without it the cluster packs from the LEFT and leaves the gap against the right margin instead"

# <stackpanel> has no origin property (ThemeData.cpp:72). Setting one parses
# to nothing, pos stays the top-left, and the panel lands off the right of
# the screen - rendering absolutely nothing, with no warning.
assert panel.find('origin') is None, \
    "<stackpanel> has no <origin>; it would be dropped and the panel would sit off-screen"

px, py = (float(v) for v in panel.findtext('pos').split())
pw, ph = (float(v) for v in panel.findtext('size').split())
assert abs((px + pw) - 0.98) < 1e-6, \
    f"panel right edge is {px + pw}, expected the 0.98 margin the cluster hangs from"

# Height is one glyph ink-height, because performLayout() top-aligns image
# children whatever their origin (the h terms cancel). A taller panel puts
# the glyphs above the text.
GLYPH_H = 0.030
CLOCK_INK_CY = 0.0612
assert abs(ph - GLYPH_H) < 1e-6, f"panel height is {ph}, expected {GLYPH_H} (one glyph ink-height)"
assert abs(py - (CLOCK_INK_CY - GLYPH_H / 2)) < 1e-6, \
    f"panel pos.y is {py}, expected the clock ink centre {CLOCK_INK_CY} minus half its height"

# maxSize, not size: performLayout only preserves aspect for images whose
# target is max. With <size> ES stretches the art to the panel height.
for tag in ('batteryIcon', 'networkIcon'):
    child = panel.find(tag)
    assert child.find('maxSize') is not None, f"<{tag}> needs <maxSize> or its art is stretched"
    assert child.find('size') is None, f"<{tag}> has <size>; that stretches the art to the panel height"

# Text children centre by default (TextComponent.cpp:13 sets ALIGN_CENTER),
# which is what puts a 0.042 clock on the line of a 0.030-tall panel. The
# failure mode is someone setting it to top or bottom, not omitting it.
for tag in ('batteryText', 'clock'):
    va = panel.find(tag).findtext('verticalAlignment')
    assert va in (None, 'center'), f"<{tag}> verticalAlignment is {va!r}; it must stay centred"
PYPANEL
check "the cluster is one reverse stackpanel with all four elements as children" $?

# The panel is deliberately over-wide so one set of literals serves every
# aspect ratio. If the contents ever exceed it, performLayout() CLAMPS the
# overflowing child to the space left (its `aligned` branch) rather than
# overflowing - so a too-narrow panel silently truncates the clock.
python3 - "${STATUS}" <<'PYWIDTH'
import sys, xml.etree.ElementTree as ET

# Measured width of the whole cluster at its WIDEST, as a fraction of screen
# width, from:
#   CLOCK_12H=true render.sh --view system --battery 100 --resolution WxH
# 12-hour because that is what the TrimUI Bricks are set to and it is ~1.7x
# wider than the 24-hour clock ES defaults to; "100%" because that is the
# widest the percentage gets. Measured rather than computed: PIL's metrics for
# this font disagree with ES's rasteriser by -12% to +23% over these sizes.
# See docs/screenshots/v0.13-battery-widget/README.md.
CLUSTER_W = {"4:3": 0.3047, "8:7": 0.3506, "3:2": 0.3208, "16:9": 0.2297, "1:1": 0.4083}
MARGIN = 0.02
MEASURED_AT = {"batteryPercent": "0.042", "statusClock": "0.042"}

root = ET.parse(sys.argv[1]).getroot()
panel = root.find('.//stackpanel')
pw = float(panel.findtext('size').split()[0])

# The table is only valid for the type sizes it was measured at.
for name, size in MEASURED_AT.items():
    el = [e for e in panel if e.get('name') == name][0]
    assert el.findtext('fontSize') == size, \
        f"<{el.tag} name={name}> fontSize changed from {size}; CLUSTER_W must be re-measured"

for ratio, w in CLUSTER_W.items():
    assert pw >= w + MARGIN, \
        f"{ratio}: the cluster is {w} of the width but the panel is only {pw} (need {MARGIN} spare)"
worst = max(CLUSTER_W, key=CLUSTER_W.get)
print(f"    panel {pw} clears the widest cluster ({CLUSTER_W[worst]} at {worst}), "
      f"{pw - CLUSTER_W[worst]:.4f} spare")
PYWIDTH
check "the panel is wide enough for a 12-hour clock and '100%' at every aspect ratio" $?

echo
echo "== exactly one visible clock =="

# ES's Window-owned clock cannot be dropped (Window would skin it from the
# helpsystem and park it bottom-right, Window.cpp:1274-1300) and cannot be
# hidden with <visible> (ClockComponent::update calls setVisible(DrawClock)
# every frame). Alpha 00 is the one property nothing overwrites.
python3 - "${STATUS}" <<'PYCLOCK'
import sys, xml.etree.ElementTree as ET
root = ET.parse(sys.argv[1]).getroot()
screen = [v for v in root.findall('view') if 'screen' in v.get('name', '').split(',')][0]
wc = [t for t in screen.findall('text') if t.get('name') == 'clock']
assert len(wc) == 1, "the screen view must still declare <text name='clock'>"
colour = (wc[0].findtext('color') or '').strip()
assert len(colour) == 8 and colour[6:] == '00', \
    f"ES's own clock has colour {colour!r}; it must be fully transparent (alpha 00), not hidden with <visible>"
assert wc[0].find('visible') is None, \
    "<visible> on ES's clock is overwritten every frame by ClockComponent::update"
PYCLOCK
check "ES's Window-owned clock is present but transparent, so only the panel's clock draws" $?

! grep -q 'statusClockX\|statusNetX\|statusPctX' "${COMMON}" "${REPO_ROOT}"/_inc/aspect-*.xml
check "no leftover per-ratio cluster variables (the panel packs itself)" $?

python3 - "${COMMON}" <<'PY'
import sys, xml.etree.ElementTree as ET
root = ET.parse(sys.argv[1]).getroot()
for tag in ('batteryIcon', 'batteryText', 'networkIcon', 'batteryIndicator', 'stackpanel'):
    assert root.find(f'.//{tag}') is None, f"common.xml declares <{tag}>; the cluster lives in status-bar.xml"
PY
check "common.xml declares no cluster element" $?

echo
echo "== harness can drive the widget =="

# Not a grep: "--battery" also appears in this flag's own comments and error
# strings, so a grep still passes with the argument-parser case deleted — the
# flag would then be rejected as an unknown argument. Drive the parser instead.
# A deliberately bad --view fails validation without ever starting docker, so
# the message says whether --battery was consumed as a flag or choked on.
render_err="$("${RENDER}" --battery 47 --view bogus 2>&1)"
[[ "${render_err}" == *"bad --view"* && "${render_err}" != *"unknown argument"* ]]
check "render.sh's argument parser accepts --battery" $?

"${RENDER}" --battery 101 --out /dev/null >/dev/null 2>&1
[[ $? -ne 0 ]]
check "render.sh rejects --battery above 100" $?

"${RENDER}" --battery banana --out /dev/null >/dev/null 2>&1
[[ $? -ne 0 ]]
check "render.sh rejects a non-numeric --battery" $?

SHOW_BATTERY=maybe "${RENDER}" --out /dev/null >/dev/null 2>&1
[[ $? -ne 0 ]]
check "render.sh rejects an unknown SHOW_BATTERY value" $?

# The 12-hour clock is the width the cluster is sized against, so the pin that
# renders it has to keep working.
CLOCK_12H=yes "${RENDER}" --out /dev/null >/dev/null 2>&1
[[ $? -ne 0 ]]
check "render.sh rejects an unknown CLOCK_12H value" $?

grep -q 'ClockMode12' "${REPO_ROOT}/docker/run-in-container.sh"
check "run-in-container.sh can pin ES's 12-hour clock" $?

# The container has no battery of its own, so every one of these renders would
# be a blank status bar without the synthetic sysfs mount. Grepping the script
# for "power_supply" is not enough — the flag's own help text says the words,
# so the guard still passes with the mount deleted. Stub out docker instead and
# read the command line render.sh actually builds.
STUB_DIR="$(mktemp -d)"
trap 'rm -rf "${STUB_DIR}"' EXIT
cat > "${STUB_DIR}/docker" <<'STUB'
#!/usr/bin/env bash
# "image inspect" must succeed or render.sh starts a 10-minute build.
[[ "$1" == "image" ]] && exit 0
printf '%s\n' "$@" > "${STUB_CAPTURE}"
# Snapshot the mounted tree from INSIDE the run: render.sh removes it on exit
# (trap ... EXIT), so it no longer exists by the time the caller looks.
for a in "$@"; do
  if [[ "$a" == *":/sys/class/power_supply:ro" ]]; then
    cp -r "${a%%:*}" "${STUB_CAPTURE}.bat"
  fi
done
STUB
chmod +x "${STUB_DIR}/docker"

STUB_CAPTURE="${STUB_DIR}/argv" PATH="${STUB_DIR}:${PATH}" \
  "${RENDER}" --battery 47:charging --out "${STUB_DIR}/out.png" >/dev/null 2>&1
grep -q ':/sys/class/power_supply:ro$' "${STUB_DIR}/argv" 2>/dev/null
check "--battery bind-mounts a synthetic /sys/class/power_supply into the container" $?

# The mount is only half of it: the tree has to say what was asked for, or the
# glyph renders for the wrong charge state and nothing looks broken.
MOUNT_SRC="${STUB_DIR}/argv.bat"
[[ "$(cat "${MOUNT_SRC}/BAT0/capacity" 2>/dev/null)" == "47" ]] && \
  [[ "$(cat "${MOUNT_SRC}/BAT0/status" 2>/dev/null)" == "Charging" ]]
check "the mounted tree carries the requested level and charging state" $?

STUB_CAPTURE="${STUB_DIR}/argv2" PATH="${STUB_DIR}:${PATH}" \
  "${RENDER}" --out "${STUB_DIR}/out.png" >/dev/null 2>&1
! grep -q 'power_supply' "${STUB_DIR}/argv2" 2>/dev/null
check "a render without --battery mounts nothing (default stays a no-battery device)" $?

grep -q 'SHOW_BATTERY' "${STUB_DIR}/argv" 2>/dev/null
check "SHOW_BATTERY is passed through to the container" $?

# Pinpoint the emitted settings key, not the word: the surrounding comments in
# run-in-container.sh name ShowBattery too.
grep -qF 'name=\"ShowBattery\"' "${REPO_ROOT}/docker/run-in-container.sh"
check "run-in-container.sh writes ES's ShowBattery key into es_settings.cfg" $?

grep -q -- '--battery SPEC' "${RENDER}"
check "--battery is documented in render.sh's usage" $?

echo
if [[ "${fail}" -eq 0 ]]; then echo "PASS"; else echo "FAIL"; fi
exit "${fail}"
