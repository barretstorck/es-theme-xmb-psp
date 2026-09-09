#!/usr/bin/env bash
# Structural test for gamelist body text — metadata rows and descriptions
# across all three gamelist styles (issue #42).
#
# #42's complaint was that this text is hard to read on the device, and the
# fix moved four factors at once: weight, two opacity cuts, size, and colour.
# What makes it worth a guard file is that every one of those factors is
# expressed somewhere that does NOT look load-bearing:
#
#  * The card's font sizes are declared THREE times — _inc/common.xml,
#    icon-size-boxart.xml and icon-size-compact.xml. The iconSize subset
#    parses after common.xml, so in the harness (where an unselected subset
#    still applies its first include) the subset value is the live one and
#    common.xml's is dead. On the device it is the other way round: ES v39
#    applies NO include for a subset the user has never opened, so common.xml
#    is live there. Editing one changes nothing in a render and everything on
#    a fresh install. Boxart and common.xml must therefore agree exactly.
#  * `${fontBody}`, `${starTrackOpacity}` and `${metaSecondaryOpacity}` only
#    mean anything while every body element actually references them. An
#    element added later that hard-codes ${fontLight} silently leaves the
#    scope, and nothing about the render says so.
#  * The five-glyph rating track is height-normalised while the columns it
#    must fit between are width-normalised, so a size that fits at 4:3 can
#    overrun at 1:1. The card and list cases are guarded in
#    test-gamelist-styles.sh; the grid's own bound (gridStarW) is guarded
#    here.
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

# `check "$(cmd)" $?` would report the SUBSTITUTION's status, because bash
# expands arguments left to right — so each python guard stores its exit
# status in `rc` on its own line and passes that.

echo "body-text scope is complete:"

python3 - "${REPO_ROOT}" <<'PY'
import re, sys
repo = sys.argv[1]

# Every element whose legibility #42 is about, and the colour role it carries.
# "body"    -> ${textSecondary}, the colour the issue lifted
# "primary" -> ${textPrimary}, the filled half of a rating pair
BODY = {
    "_inc/gamelist-card.xml": {
        "cardGenre": "body", "cardStarTrack": "body", "cardStars": "primary",
        "cardPlayers": "body", "cardMeta2": "body", "cardDesc": "body",
    },
    "_inc/gamelist-list.xml": {
        "listYearDev": "body", "listStarTrack": "body", "listStars": "primary",
        "listMeta": "body", "listDesc": "body",
    },
    "_inc/gamelist-grid.xml": {
        "gridMeta": "body", "gridStarTrack": "body", "gridStars": "primary",
    },
}
COLOUR = {"body": "${textSecondary}", "primary": "${textPrimary}"}

bad = []
for path, elems in BODY.items():
    text = open(f"{repo}/{path}").read()
    for name, role in elems.items():
        m = re.search(r'<text name="%s"[^>]*>(.*?)</text>' % name, text, re.S)
        if not m:
            bad.append(f"{path}: no <text name=\"{name}\">"); continue
        body = m.group(1)
        font = re.search(r"<fontPath>([^<]+)</fontPath>", body)
        if not font or font.group(1) != "${fontBody}":
            bad.append(f"{path}:{name} fontPath is "
                       f"{font.group(1) if font else 'unset'}, want ${{fontBody}}")
        col = re.search(r"<color>([^<]+)</color>", body)
        if not col or col.group(1) != COLOUR[role]:
            bad.append(f"{path}:{name} color is "
                       f"{col.group(1) if col else 'unset'}, want {COLOUR[role]}")
if bad:
    print("\n".join(bad), file=sys.stderr); sys.exit(1)
PY
rc=$?
check "every body element uses \${fontBody} and its role colour" "${rc}"

# The inverse: nothing in a gamelist style may quietly fall back to the Light
# face. The three names below are chrome, not body text, and are allowed.
python3 - "${REPO_ROOT}" <<'PY'
import re, sys
repo = sys.argv[1]
ALLOWED = {"md_systemName", "tplPeekTitle", "gridSystemName"}
bad = []
for path in ("_inc/gamelist-card.xml", "_inc/gamelist-list.xml",
             "_inc/gamelist-grid.xml"):
    text = open(f"{repo}/{path}").read()
    # Strip comments first: the style files discuss ${fontLight} in prose.
    text = re.sub(r"<!--.*?-->", "", text, flags=re.S)
    for m in re.finditer(r'<text name="([^"]+)"[^>]*>(.*?)</text>', text, re.S):
        if "${fontLight}" in m.group(2) and m.group(1) not in ALLOWED:
            bad.append(f"{path}:{m.group(1)} still uses ${{fontLight}}")
if bad:
    print("\n".join(bad), file=sys.stderr); sys.exit(1)
PY
rc=$?
check "no gamelist body element still hard-codes \${fontLight}" "${rc}"

python3 - "${REPO_ROOT}" <<'PY'
import re, sys
repo = sys.argv[1]
common = open(f"{repo}/_inc/common.xml").read()
bad = []
for var in ("fontBody", "starTrackOpacity", "metaSecondaryOpacity",
            "listMetaFontSize"):
    if not re.search(r"<%s>[^<]+</%s>" % (var, var), common):
        bad.append(f"common.xml does not declare ${{{var}}}")

st = float(re.search(r"<starTrackOpacity>([^<]+)<", common).group(1))
# The track is the EMPTY half of the rating pair. At 1 it is indistinguishable
# from the filled glyphs drawn over it and every game reads as five stars.
if not 0 < st < 1:
    bad.append(f"starTrackOpacity {st} must be strictly between 0 and 1")

# The two opacity properties must actually be driven by the variables.
for path, name, var in (
        ("_inc/gamelist-card.xml", "cardStarTrack", "starTrackOpacity"),
        ("_inc/gamelist-list.xml", "listStarTrack", "starTrackOpacity"),
        ("_inc/gamelist-grid.xml", "gridStarTrack", "starTrackOpacity"),
        ("_inc/gamelist-card.xml", "cardMeta2", "metaSecondaryOpacity")):
    text = open(f"{repo}/{path}").read()
    body = re.search(r'<text name="%s"[^>]*>(.*?)</text>' % name, text, re.S).group(1)
    if f"<opacity>${{{var}}}</opacity>" not in body:
        bad.append(f"{path}:{name} does not read ${{{var}}}")
if bad:
    print("\n".join(bad), file=sys.stderr); sys.exit(1)
PY
rc=$?
check "the weight and opacity knobs exist and are wired to the elements" "${rc}"

echo
echo "harness/device divergence on card font sizes:"

python3 - "${REPO_ROOT}" <<'PY'
import re, sys
repo = sys.argv[1]

def vars_of(path):
    return dict(re.findall(r"<(card[A-Za-z0-9]+)>([^<]+)<",
                           open(f"{repo}/{path}").read()))

common = vars_of("_inc/common.xml")
boxart = vars_of("_inc/icon-size-boxart.xml")

# Boxart is the DEFAULT icon size, i.e. what a user who never opens the
# subset is meant to see. In the harness the subset's first include applies
# and boxart wins; on the device no include applies and common.xml wins. Any
# card variable declared in both must therefore carry the same value, or the
# two disagree and only one of them is ever verified.
# cardBoxartW/H already disagree (common.xml 0.234/0.3125 vs boxart
# 0.22/0.29) and have since v0.11 — a fresh device shows a boxart ~7% larger
# than every render ever taken. That is a real divergence of exactly the kind
# this guard exists to prevent, but resizing the selected boxart is a visual
# change with nothing to do with #42's text legibility, so it is recorded
# here as a known exception rather than silently fixed or silently ignored.
KNOWN_DIVERGENT = {"cardBoxartW", "cardBoxartH"}

bad = [f"{k}: common.xml {common[k]} != icon-size-boxart.xml {v}"
       for k, v in boxart.items()
       if k in common and common[k] != v and k not in KNOWN_DIVERGENT]
if bad:
    print("\n".join(bad), file=sys.stderr); sys.exit(1)
print(f"  ({len(set(boxart) & set(common))} shared card variables agree)")
PY
rc=$?
check "common.xml and icon-size-boxart.xml agree on every shared card variable" "${rc}"

python3 - "${REPO_ROOT}" <<'PY'
import re, sys
repo = sys.argv[1]
def get(path, var):
    m = re.search(r"<%s>([^<]+)<" % var, open(f"{repo}/{path}").read())
    return float(m.group(1)) if m else None

# Compact exists to be denser than Boxart. If a size bump is applied to one
# and not the other the two modes converge and the setting stops meaning
# anything.
bad = []
for var in ("cardMetaFontSize", "cardDescFontSize", "cardTitleFontSize"):
    b, c = get("_inc/icon-size-boxart.xml", var), get("_inc/icon-size-compact.xml", var)
    if b is None or c is None:
        bad.append(f"{var} missing from one of the icon-size files")
    elif not c < b:
        bad.append(f"Compact {var} {c} is not smaller than Boxart {b}")

# The card's second metadata line is subordinate to the first; with
# metaSecondaryOpacity at 1 that hierarchy rests entirely on size.
card = open(f"{repo}/_inc/gamelist-card.xml").read()
meta2 = float(re.search(r'name="cardMeta2".*?<fontSize>([^<]+)<', card, re.S).group(1))
meta1 = get("_inc/common.xml", "cardMetaFontSize")
if not meta2 < meta1:
    bad.append(f"cardMeta2 {meta2} must stay below cardMetaFontSize {meta1}")
if bad:
    print("\n".join(bad), file=sys.stderr); sys.exit(1)
PY
rc=$?
check "Compact stays denser than Boxart, and meta line 2 below line 1" "${rc}"

echo
echo "rating track fits its column at every ratio:"

python3 - "${REPO_ROOT}" <<'PY'
import re, sys
repo = sys.argv[1]
common = open(f"{repo}/_inc/common.xml").read()
grid = open(f"{repo}/_inc/gamelist-grid.xml").read()

fs = float(re.search(r'name="gridStarTrack".*?<fontSize>([^<]+)<', grid, re.S).group(1))
w_bound = float(re.search(r"<gridStarW>([^<]+)<", common).group(1))

# Same advance model the card and list guards use: five glyphs plus four 25%
# gaps, each glyph ~0.85 of the font size, which is a fraction of screen
# HEIGHT while gridStarW is a fraction of WIDTH.
DIMS = {"4:3": (1024, 768), "8x7": (1024, 896), "3x2": (1280, 854),
        "16x9": (1280, 720), "1x1": (720, 720)}
bad = []
for ratio, (w, h) in DIMS.items():
    track = (5 * fs * 0.85 * h + 4 * fs * 0.85 * h * 0.25) / w
    if track > w_bound:
        bad.append(f"{ratio}: track {track:.4f} exceeds gridStarW {w_bound} "
                   "- ES abbreviates a single-line text to its <size>, so a "
                   "star would be dropped from the track")
if bad:
    print("\n".join(bad), file=sys.stderr); sys.exit(1)
print(f"  (worst ratio leaves {w_bound - max((5*fs*0.85*h + 4*fs*0.85*h*0.25)/w for w, h in DIMS.values()):.4f} spare)")
PY
rc=$?
check "grid star track fits gridStarW at all five ratios" "${rc}"

echo
echo "colorset body ink:"

python3 - "${REPO_ROOT}" <<'PY'
import glob, os, re, sys
repo = sys.argv[1]

def luminance(hexstr):
    def lin(v):
        v /= 255.0
        return v / 12.92 if v <= 0.04045 else ((v + 0.055) / 1.055) ** 2.4
    r, g, b = (int(hexstr[i:i + 2], 16) for i in (0, 2, 4))
    return 0.2126 * lin(r) + 0.7152 * lin(g) + 0.0722 * lin(b)

# #42 lifted every colorset's textSecondary 55% toward white. The floor below
# is the darkest value that transform produces (September Red, L=0.740),
# rounded down. It is a "did someone add a mid-tone colorset" guard, not a
# WCAG one: six colorsets have accents so light that no ink colour reaches
# 3:1 on their own wave, which is a palette problem and out of #42's scope.
FLOOR = 0.72
bad = []
files = sorted(glob.glob(f"{repo}/colors/psp-*.xml")) + [f"{repo}/_inc/common.xml"]
for path in files:
    m = re.search(r"<textSecondary>([0-9A-Fa-f]{6})</textSecondary>", open(path).read())
    if not m:
        bad.append(f"{os.path.basename(path)} declares no textSecondary"); continue
    L = luminance(m.group(1))
    if L < FLOOR:
        bad.append(f"{os.path.basename(path)}: textSecondary #{m.group(1)} "
                   f"L={L:.3f} below the {FLOOR} body-ink floor")
if len(files) != 13:
    bad.append(f"expected 12 colorsets + common.xml, found {len(files)}")
if bad:
    print("\n".join(bad), file=sys.stderr); sys.exit(1)
PY
rc=$?
check "all 12 colorsets and the fallback carry light-enough body ink" "${rc}"

echo
echo "docs:"
grep -q 'fontBody' "${REPO_ROOT}/docs/psp-xmb-style-guidelines.md"
check "style guide documents \${fontBody}" $?
grep -q 'starTrackOpacity' "${REPO_ROOT}/docs/psp-xmb-style-guidelines.md"
check "style guide documents \${starTrackOpacity}" $?

echo
if [[ "${fail}" -eq 0 ]]; then echo "all checks passed"; else echo "FAILURES"; fi
exit "${fail}"
