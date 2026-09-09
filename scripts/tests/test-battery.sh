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

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
fail=0
check() { # check <description> <condition-exit-code>
  if [[ "$2" -eq 0 ]]; then echo "  ok   - $1"; else echo "  FAIL - $1"; fi
  [[ "$2" -eq 0 ]] || fail=1
}

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
txt = [e for v in screen for e in v.findall('batteryText')]
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
echo "== cluster geometry, at every aspect ratio the theme ships =="

python3 - "${STATUS}" "${REPO_ROOT}" <<'PYGEO'
import sys, os, xml.etree.ElementTree as ET
from PIL import Image

status, repo = sys.argv[1], sys.argv[2]

# The five design surfaces, and the aspect file that overrides each. 4:3 has no
# aspect file — it is common.xml's default.
SURFACES = [
    ("4:3",  1024, 768, None),
    ("8:7",  1024, 896, "aspect-8x7.xml"),
    ("3:2",   720, 480, "aspect-3x2.xml"),
    ("16:9", 1280, 720, "aspect-16x9.xml"),
    ("1:1",   720, 720, "aspect-1x1.xml"),
]

# WIDTH OF "100%" AS ES ACTUALLY RENDERS IT, as a fraction of screen width,
# measured from `render.sh --view system --battery 100 --resolution WxH` and
# recorded in docs/screenshots/v0.13-battery-widget/README.md.
#
# Measured, not computed: PIL's metrics for this font disagree with ES's
# rasteriser by -12% to +23% across these sizes, so a computed width is not a
# safe oracle in either direction. The guard below therefore checks that the
# theme still RESERVES enough room for the measured width. The fontPath and
# fontSize assertions underneath are what keep this table honest — change
# either and the numbers must be re-measured.
PCT_INK_W = {"4:3": 0.0449, "8:7": 0.0520, "3:2": 0.0514, "16:9": 0.0321, "1:1": 0.0575}
MEASURED_AT_FONT = ("${fontRegular}", "0.030")

CLOCK_INK_CY = 0.0612   # clock glyph rows 36..58 at 1024x768

# Two minimums, because the clock's bound is a different kind of thing. The
# clock is right-aligned inside a fixed 0.14 box, so its BOX edge is the
# worst case its ink can reach (on device, "12:35 PM" ink stops 0.0036 short
# of it); the other three are ink-to-ink. Shipped worst cases at 4:3 are
# 0.0115 box-to-ink and 0.0137 ink-to-ink. Both defects this section exists
# to catch were far below either: 0.0059 at 3:2 and 0.003 at 1:1.
MIN_BOX_GAP = 0.010     # clock box edge -> network glyph ink
MIN_INK_GAP = 0.012     # ink -> ink

root = ET.parse(status).getroot()
def el(tag, name):
    for e in root.iter(tag):
        if e.get('name') == name:
            return e
    raise AssertionError(f"no <{tag} name='{name}'>")

def pair(e, tag):
    v = e.findtext(tag)
    return None if v is None else tuple(v.split())

def read_vars(path):
    r = ET.parse(path).getroot()
    return {c.tag: (c.text or '').strip() for v in r.findall('variables') for c in v}

def fitted(png, maxw, maxh, W, H):
    im = Image.open(os.path.join(repo, png.lstrip('./')))
    scale = min(float(maxw) * W / im.width, float(maxh) * H / im.height)
    return im.width * scale / W

clock = el('text', 'clock')
net   = el('networkIcon', 'networkStatus')
pct   = el('batteryText', 'batteryPercent')
icon  = el('batteryIcon', 'batteryStatus')

assert pct.findtext('fontPath').strip() == MEASURED_AT_FONT[0], \
    f"batteryText fontPath changed; PCT_INK_W must be re-measured"
assert pct.findtext('fontSize').strip() == MEASURED_AT_FONT[1], \
    f"batteryText fontSize changed; PCT_INK_W must be re-measured"

# Every element must be anchored to the clock's ink centre, in every ratio —
# these are literals in the element, not per-ratio.
for name, e in (("networkIcon", net), ("batteryText", pct), ("batteryIcon", icon)):
    o = pair(e, 'origin')
    assert o and float(o[1]) == 0.5, f"{name} needs origin y=0.5"
    y = float(pair(e, 'pos')[1])
    assert abs(y - CLOCK_INK_CY) < 1e-6, f"{name} pos.y is {y}, expected {CLOCK_INK_CY}"
assert float(pair(net, 'origin')[0]) == 1.0 and float(pair(icon, 'origin')[0]) == 1.0, \
    "networkIcon and batteryIcon anchor from their RIGHT edge (origin x = 1)"

base = read_vars(os.path.join(repo, '_inc', 'common.xml'))
for label, W, H, afile in SURFACES:
    v = dict(base)
    if afile:
        over = read_vars(os.path.join(repo, '_inc', afile))
        # A new aspect file that forgets these silently inherits the 4:3
        # values, which is the exact defect this section exists to catch.
        for k in ('statusClockX', 'statusNetX', 'statusPctX'):
            assert k in over, f"{afile} does not override {k}"
        v.update(over)

    def x(e, tag='pos'):
        raw = pair(e, tag)[0]
        return float(v[raw[2:-1]]) if raw.startswith('${') else float(raw)

    clock_right = x(clock) + float(pair(clock, 'size')[0])
    net_w  = fitted(net.findtext('path'), *pair(net, 'maxSize'), W, H)
    net_right, net_left = x(net), x(net) - net_w
    pct_left = x(pct)
    pct_right = pct_left + PCT_INK_W[label]
    icon_w = fitted(icon.findtext('full'), *pair(icon, 'maxSize'), W, H)
    icon_right, icon_left = x(icon), x(icon) - icon_w

    assert abs(icon_right - 0.98) < 1e-6, \
        f"{label}: glyph right edge is {icon_right}, expected the 0.98 margin"
    for (an, ar), (bn, bl), floor in (
            (("clock", clock_right), ("network", net_left), MIN_BOX_GAP),
            (("network", net_right), ("percent", pct_left), MIN_INK_GAP),
            (("percent", pct_right), ("glyph", icon_left), MIN_INK_GAP)):
        gap = bl - ar
        assert gap >= floor, \
            f"{label}: {an} -> {bn} gap is {gap:.4f} at '100%' (min {floor})"
    print(f"    {label:5s} ok: clock<={clock_right:.4f} net {net_left:.4f}..{net_right:.4f} "
          f"pct {pct_left:.4f}..{pct_right:.4f} glyph {icon_left:.4f}..{icon_right:.4f}")
PYGEO
check "the cluster clears itself at '100%' in all five aspect ratios" $?

# The status bar CANNOT live in common.xml: ES resolves ${variables} at
# element-parse time, and common.xml is included long before aspect-*.xml, so a
# screen view declared there pins every ratio to the 4:3 values — silently, and
# only visibly wrong on the squarer screens.
python3 - "${REPO_ROOT}/theme.xml" <<'PYORDER'
import sys
t = open(sys.argv[1]).read()
status = t.index('./_inc/status-bar.xml')
for a in ('aspect-8x7.xml', 'aspect-3x2.xml', 'aspect-16x9.xml', 'aspect-1x1.xml'):
    assert t.index(a) < status, f"status-bar.xml must be included after {a}"
PYORDER
check "theme.xml includes status-bar.xml after every aspect-*.xml" $?

! grep -q 'batteryIcon\|batteryText\|networkIcon\|batteryIndicator' "${COMMON}"
check "common.xml declares no status-cluster element (it parses too early for the per-ratio variables)" $?

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
