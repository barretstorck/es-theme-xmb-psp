#!/usr/bin/env bash
# Structural test for the themed boot splash (issue #10).
#
# Every failure mode this guards against is SILENT. Splash::loadTheme wraps the
# parse in `try { theme->loadFile("splash", ...) } catch(...) { }`
# (Splash.cpp:38-42), so a malformed splash.xml raises nothing, logs nothing,
# and simply leaves the theme unapplied. What the user then gets is not a
# missing splash but EmulationStation's OWN logo painted full-screen, because
# an absent <image name="background"> sends imagePath to DEFAULT_SPLASH_IMAGE
# (":/logo.png", Splash.h:15) with setMinSize(screen) — a cropped-to-fill ES
# logo. A wrong splash is worse than no splash, and nothing in the logs says so.
#
# Pixel checks cannot cover this either: the splash exists for a few seconds at
# boot and the harness has to be asked specially to render it at all
# (VIEW=splash). Hence a structural guard.
#
# NOTE: deliberately NOT `set -e` — see the note in test-gamelist-styles.sh.
set -uo pipefail

# shellcheck source=scripts/lib/test-lib.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../lib" && pwd)/test-lib.sh"

SPLASH="${REPO_ROOT}/splash.xml"
WORDMARK="${REPO_ROOT}/art/ui/splash-wordmark.png"
GENERATOR="${REPO_ROOT}/scripts/gen-splash-wordmark.py"

echo "== splash.xml is present, at the path ES actually looks for =="

# Splash.cpp:31-34 builds `themeset->second.path + "/splash.xml"`. The theme
# root is the ONLY location consulted — an _inc/ copy is never read.
[[ -f "${SPLASH}" ]]
check "splash.xml exists at the theme root (Splash.cpp:31-34 looks nowhere else)" $?

[[ ! -f "${REPO_ROOT}/_inc/splash.xml" ]]
check "no decoy _inc/splash.xml (ES would never load it)" $?

echo
echo "== the file parses, and parses STRICTLY =="

# ES uses pugixml, which tolerates "--" inside a comment even though that is
# illegal XML. A file that renders fine on device can still break python3 and
# xmllint — that exact case shipped in _inc/aspect-8x7.xml. Parse strictly so
# tooling breakage is caught here rather than by the next person to write a
# script over the theme.
python3 -c "
import xml.etree.ElementTree as ET, sys
ET.parse('${SPLASH}')
" 2>/dev/null
check "splash.xml is strictly well-formed XML (no '--' inside comments)" $?

# loadFile throws 'formatVersion tag missing' without this, and Splash swallows
# the exception — leaving the ES logo with no diagnostic anywhere.
python3 -c "
import xml.etree.ElementTree as ET, sys
r = ET.parse('${SPLASH}').getroot()
sys.exit(0 if r.tag == 'theme' and r.findtext('formatVersion', '').strip() == '7' else 1)
" 2>/dev/null
check "root is <theme> with <formatVersion>7</formatVersion>" $?

echo
echo "== the view and the background element ES requires =="

python3 -c "
import xml.etree.ElementTree as ET, sys
r = ET.parse('${SPLASH}').getroot()
sys.exit(0 if any(v.get('name') == 'splash' for v in r.findall('view')) else 1)
" 2>/dev/null
check "declares <view name=\"splash\"> (the only view Splash reads)" $?

# THE load-bearing guard. No themed background => ES paints its own logo.
python3 -c "
import xml.etree.ElementTree as ET, sys
r = ET.parse('${SPLASH}').getroot()
for v in r.findall('view'):
    if v.get('name') == 'splash':
        for img in v.findall('image'):
            if img.get('name') == 'background' and img.findtext('path'):
                sys.exit(0)
sys.exit(1)
" 2>/dev/null
check "declares <image name=\"background\"> with a <path> (else ES draws :/logo.png)" $?

# A background <path> that does not resolve puts us back on the ES logo:
# Splash.cpp:50-55 only adopts the themed path if the file actually exists.
python3 - <<PY 2>/dev/null
import xml.etree.ElementTree as ET, os, sys
root = "${REPO_ROOT}"
r = ET.parse("${SPLASH}").getroot()
missing = []
for v in r.findall("view"):
    if v.get("name") != "splash":
        continue
    for el in list(v.findall("image")) + list(v.findall("video")):
        p = (el.findtext("path") or "").strip()
        if not p or p.startswith("{") or "\${" in p:
            continue
        if not os.path.isfile(os.path.join(root, p.lstrip("./"))):
            missing.append((el.get("name"), p))
sys.exit(1 if missing else 0)
PY
check "every <path> in the splash view resolves to a file in the repo" $?

echo
echo "== extras: flagged, and stacked into the right z-band =="

# ThemeData::makeExtras only collects elements carrying extra="true"; anything
# else in the view is looked up by name and our decorative elements have names
# ES has never heard of, so without the flag they are silently dropped.
python3 - <<PY 2>/dev/null
import xml.etree.ElementTree as ET, sys
KNOWN = {"background", "label", "progressbar", "progressbar:active", "splash"}
r = ET.parse("${SPLASH}").getroot()
bad = []
for v in r.findall("view"):
    if v.get("name") != "splash":
        continue
    for el in v:
        if not isinstance(el.tag, str) or el.tag == "splash":
            continue
        if el.get("name") in KNOWN:
            continue
        if el.get("extra") != "true":
            bad.append((el.tag, el.get("name")))
sys.exit(1 if bad else 0)
PY
check "every decorative element carries extra=\"true\" (makeExtras ignores the rest)" $?

# Splash::render draws extras with zIndex < 5 BEFORE mBackground, so a
# decorative extra left at a low zIndex renders underneath an opaque background
# and vanishes without a trace (Splash.cpp, render order:
# extras<5 -> background -> extras 5..9 -> progressbar -> label -> extras>=10).
python3 - <<PY 2>/dev/null
import xml.etree.ElementTree as ET, sys
KNOWN = {"background", "label", "progressbar", "progressbar:active", "splash"}
r = ET.parse("${SPLASH}").getroot()
bad = []
for v in r.findall("view"):
    if v.get("name") != "splash":
        continue
    for el in v:
        if not isinstance(el.tag, str) or el.get("name") in KNOWN or el.tag == "splash":
            continue
        z = el.findtext("zIndex")
        if z is None or float(z) < 5:
            bad.append((el.get("name"), z))
sys.exit(1 if bad else 0)
PY
check "every extra sets zIndex >= 5 (below 5 renders behind the background)" $?

echo
echo "== nothing here pretends to animate =="

# Splash::update sets only text and percent; it never calls update() on the
# extras, so no storyboard advances (this is why audit U1 stays unsupportable).
# A storyboard in this file is dead code that reads as intent — and it would
# freeze at its `from` value, which is rarely the composition anyone designed.
# The -f test is load-bearing: `! grep -q` on a MISSING file also returns 0, so
# without it this guard reports "ok" for a splash.xml that does not exist.
[[ -f "${SPLASH}" ]] && ! grep -q "<storyboard" "${SPLASH}"
check "no <storyboard> in splash.xml (Splash::update never ticks extras)" $?

echo
echo "== the splash tracks the user's colorset =="

# mColorset comes from the global "ThemeColorSet" setting (ThemeData.cpp:684),
# which a freshly constructed ThemeData reads, so the chosen colorset does
# reach the splash — but only if this file declares the subset itself.
# splash.xml is parsed standalone (Splash.cpp:41 passes it to loadFile directly),
# so it inherits NOTHING from theme.xml.
grep -q '<subset name="colorset"' "${SPLASH}"
check "splash.xml declares the colorset subset itself (it inherits nothing from theme.xml)" $?

# Same belt-and-braces ordering theme.xml uses for the button-glyph sets: on the
# device's ES build a never-chosen subset value can leave variables unresolved
# rather than falling back to the first include. A plain include first makes the
# default unconditional.
python3 - <<PY 2>/dev/null
import xml.etree.ElementTree as ET, sys
r = ET.parse("${SPLASH}").getroot()
seen_plain = False
for el in r:
    if not isinstance(el.tag, str):
        continue
    if el.tag == "include" and (el.text or "").strip().endswith(".xml") and "colors/" in (el.text or ""):
        seen_plain = True
    if el.tag == "subset" and el.get("name") == "colorset":
        sys.exit(0 if seen_plain else 1)
sys.exit(1)
PY
check "a plain colorset include precedes the subset (unchosen value must still resolve)" $?

# Every colorset the theme ships has to be offered here too, or picking one of
# the missing ones silently drops the splash back to the default palette.
python3 - <<PY 2>/dev/null
import xml.etree.ElementTree as ET, os, sys
root = "${REPO_ROOT}"
shipped = {f for f in os.listdir(os.path.join(root, "colors")) if f.endswith(".xml")}
r = ET.parse("${SPLASH}").getroot()
declared = set()
for sub in r.findall("subset"):
    if sub.get("name") == "colorset":
        for inc in sub.findall("include"):
            declared.add(os.path.basename((inc.text or "").strip()))
sys.exit(0 if declared == shipped else 1)
PY
# Capture the status IMMEDIATELY. Writing `check "...$(ls ...)..." $?` instead
# would report the command substitution's status, not Python's — bash expands
# arguments left to right, so the $(...) runs first and clobbers $?. That makes
# the guard pass unconditionally; it is a mistake this suite has shipped before.
rc=$?
n_colorsets="$(find "${REPO_ROOT}/colors" -name '*.xml' | wc -l | tr -d ' ')"
check "the splash colorset subset offers all ${n_colorsets} shipped colorsets" "${rc}"

# theme.xml and splash.xml both present a subset called "colorset" to the same
# ThemeColorSet setting. If the display names drift apart, the same stored value
# means two different things and the splash silently mismatches the UI.
python3 - <<PY 2>/dev/null
import xml.etree.ElementTree as ET, sys
def names(path):
    r = ET.parse(path).getroot()
    for sub in r.findall("subset"):
        if sub.get("name") == "colorset":
            return [i.get("name") for i in sub.findall("include")]
    return None
a, b = names("${REPO_ROOT}/theme.xml"), names("${SPLASH}")
sys.exit(0 if a and a == b else 1)
PY
check "splash colorset variant names match theme.xml exactly (same ThemeColorSet value)" $?

echo
echo "== no variable is left unresolved =="

# ES substitutes ${...} at element-parse time and prints nothing when a name has
# no value — the literal text lands in the property. On a colour that is a
# silently wrong colour; on a path it is a missing image.
python3 - <<PY 2>/dev/null
import re, os, sys, xml.etree.ElementTree as ET
root = "${REPO_ROOT}"
splash = "${SPLASH}"
defined = set()
r = ET.parse(splash).getroot()
files = [splash]
for inc in r.iter("include"):
    p = (inc.text or "").strip()
    if p:
        files.append(os.path.join(root, p.lstrip("./")))
for f in files:
    if not os.path.isfile(f):
        continue
    fr = ET.parse(f).getroot()
    for block in fr.findall("variables"):
        for var in block:
            defined.add(var.tag)
# Strip comments first. ES substitutes nothing inside them, and this file's
# comments legitimately NAME variables it does not use (explaining why
# _inc/common.xml is not included). Scanning raw text reports those as missing.
body = re.sub(r"<!--.*?-->", "", open(splash).read(), flags=re.S)
used = set(re.findall(r"\\\$\{([A-Za-z0-9_.]+)\}", body))
builtin = {"themePath", "currentPath", "lang", "region", "global.language"}
missing = used - defined - builtin
sys.exit(1 if missing else 0)
PY
check "every \${variable} used in splash.xml is defined by an included file" $?

echo
echo "== the fonts duplicated out of common.xml =="

# splash.xml re-declares the two font paths instead of including _inc/common.xml
# (which would drag in views and helpsystem variables it never renders). That is
# a deliberate duplication, so it needs a guard: if common.xml repoints a font
# and this file does not follow, the splash silently keeps rendering the old one.
python3 - <<PY 2>/dev/null
import xml.etree.ElementTree as ET, sys
def fonts(path):
    out = {}
    for block in ET.parse(path).getroot().findall("variables"):
        for var in block:
            if var.tag.startswith("font"):
                out[var.tag] = (var.text or "").strip()
    return out
common, splash = fonts("${REPO_ROOT}/_inc/common.xml"), fonts("${SPLASH}")
if not splash:
    sys.exit(1)
sys.exit(0 if all(common.get(k) == v for k, v in splash.items()) else 1)
PY
check "splash.xml font paths match _inc/common.xml (duplicated on purpose, must not drift)" $?

echo
echo "== the wordmark asset =="

[[ -f "${WORDMARK}" ]]
check "art/ui/splash-wordmark.png exists" $?

[[ -f "${GENERATOR}" ]]
check "scripts/gen-splash-wordmark.py exists (asset is reproducible, not hand-drawn)" $?

# The wordmark is tinted at runtime via <color>: ES multiplies the texture's RGB
# and keeps its alpha. A flattened, opaque asset would paint a coloured BLOCK
# over the wave instead of letterforms, and would ignore the colorset entirely.
python3 - <<PY 2>/dev/null
import sys
from PIL import Image
im = Image.open("${WORDMARK}")
if im.mode != "RGBA":
    sys.exit(1)
a = im.getchannel("A")
lo, hi = a.getextrema()
# needs real transparency AND real ink
sys.exit(0 if lo == 0 and hi > 200 else 1)
PY
check "wordmark is RGBA with a real alpha channel (runtime <color> tint needs it)" $?

# <color> multiplies, so any non-white ink darkens the tint: a grey pixel tinted
# with textPrimary comes out grey-blue, not the colorset colour. Ink must be
# white and carry its shading in ALPHA instead.
python3 - <<PY 2>/dev/null
import sys
from PIL import Image
im = Image.open("${WORDMARK}").convert("RGBA")
px = im.load()
for y in range(im.height):
    for x in range(im.width):
        r, g, b, a = px[x, y]
        if a > 8 and not (r > 246 and g > 246 and b > 246):
            sys.exit(1)
sys.exit(0)
PY
check "wordmark ink is pure white (<color> multiplies; shading must live in alpha)" $?

# Re-running the generator must reproduce the committed asset, or the two drift
# and the script stops being the source of truth.
if command -v python3 >/dev/null && python3 -c "import PIL" 2>/dev/null; then
  TMPD="$(mktemp -d)"
  cp "${WORDMARK}" "${TMPD}/before.png"
  python3 "${GENERATOR}" >/dev/null 2>&1
  cmp -s "${TMPD}/before.png" "${WORDMARK}"
  check "generator reproduces the committed wordmark byte-for-byte" $?
  cp "${TMPD}/before.png" "${WORDMARK}"
  rm -rf "${TMPD}"
else
  echo "  skip - generator reproducibility (python3 + Pillow unavailable)"
fi

echo
echo "== the mark keeps clear of ES's own two slots =="

# ES owns two bands of this screen and the theme cannot move them meaningfully:
# the label at y = 0.78*H (Splash.cpp:104) and, because SplashScreenProgress
# also defaults true (Settings.cpp:130), the progress bar at y = H - 3*0.036*H
# = 0.892*H with height 0.036*H (Splash.cpp:143-147). Art that strays below
# 0.75 collides with text drawn AFTER it, and the collision only appears on a
# real boot, never in a static view render.
python3 - <<PY 2>/dev/null
import xml.etree.ElementTree as ET, sys
KNOWN = {"background", "label", "progressbar", "progressbar:active", "splash"}
r = ET.parse("${SPLASH}").getroot()
bad = []
for v in r.findall("view"):
    if v.get("name") != "splash":
        continue
    for el in v:
        if not isinstance(el.tag, str) or el.get("name") in KNOWN or el.tag == "splash":
            continue
        pos = (el.findtext("pos") or "").split()
        size = (el.findtext("size") or el.findtext("maxSize") or "").split()
        org = (el.findtext("origin") or "0 0").split()
        if len(pos) != 2 or len(size) != 2 or len(org) != 2:
            continue
        # Full-bleed elements are background, not mark: the wave layers are two
        # screens wide and deliberately span top to bottom. Only art narrower
        # than the screen is competing with the label for space.
        if float(size[0]) >= 1.0:
            continue
        y, h, oy = float(pos[1]), float(size[1]), float(org[1])
        if y - oy * h + h > 0.75:
            bad.append((el.get("name"), y - oy * h + h))
sys.exit(1 if bad else 0)
PY
check "no extra extends below y=0.75 (ES's label sits at 0.78, progress bar at 0.892)" $?

echo
if [[ "${fail}" -eq 0 ]]; then
  echo "PASS"
else
  echo "FAIL"
fi
exit "${fail}"
