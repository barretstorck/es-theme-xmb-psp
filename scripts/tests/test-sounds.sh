#!/usr/bin/env bash
# Structural guard: the theme's sounds are bound to things ES actually plays
# (issue #21).
#
# The bug this file exists to prevent is invisible by inspection. Before v1.0
# the theme declared <sound name="systemscroll">, "scroll" and "select" — three
# names Sound::getFromTheme is never called with — so navigate.wav and
# select.wav had never played, and a reviewer reading the XML would see four
# tidy, plausible bindings. Issue #20 closed as "sounds accepted" on exactly
# that reading, after measuring the wav files themselves.
#
# So the guards below are keyed to ES's SOURCE, not to whether the XML looks
# reasonable: the element names are pinned to the closed set ES asks for, and
# scroll sounds are asserted to be a <scrollSound> PROPERTY rather than a
# <sound> element, which is the distinction the original bug turned on.
#
# What this file cannot check is whether any of it makes a noise. That needs
# scripts/capture-audio.sh, which runs ES under SDL's disk audio driver and
# measures the mixer's output; see the end of this file for the exact commands
# and their expected results.
#
# NOTE: deliberately NOT `set -e` — see the note in test-gamelist-styles.sh.
set -uo pipefail

# shellcheck source=scripts/lib/test-lib.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../lib" && pwd)/test-lib.sh"

# `check "$(cmd)" $?` would report the SUBSTITUTION's status, because bash
# expands arguments left to right — so each python guard stores its exit
# status in `rc` on its own line and passes that.

echo "every <sound> element is one ES actually asks for:"

python3 - "${REPO_ROOT}" <<'PY'
import glob, os, sys, xml.etree.ElementTree as ET

# Sound::getFromTheme's complete call-site set in the pinned build:
#   ISimpleGameListView.cpp:231,401   "back"
#   ISimpleGameListView.cpp:335,346,367 + GridGameListView.cpp:104  "menuOpen"
#   ISimpleGameListView.cpp:371,412,422 "launch"
# Anything else is inert. Update this set only alongside an ES pin bump, with
# a fresh grep of the call sites — not because a name "looks like" it works.
LIVE = {"back", "menuOpen", "launch"}
# The three that shipped broken. Named explicitly so the failure message can
# say WHY rather than just "unknown name", since these are the ones a
# well-meaning edit is most likely to reintroduce.
DEAD = {"systemscroll", "scroll", "select"}

root = sys.argv[1]
files = sorted(glob.glob(os.path.join(root, "*.xml")) +
               glob.glob(os.path.join(root, "_inc", "**", "*.xml"), recursive=True))
bad = []
if len(files) < 20:
    bad.append(f"only found {len(files)} theme XML files — the glob is wrong, "
               "and the rest of this check would pass vacuously")

blocks = 0
for path in files:
    rel = os.path.relpath(path, root)
    try:
        tree = ET.parse(path)              # comments are dropped here
    except ET.ParseError as e:
        bad.append(f"{rel}: not well-formed XML: {e}")
        continue
    # Per <view> block, not per file and not pooled across the tree. ES
    # resolves a sound against the view it is playing in, so a block holding
    # two of the three silently loses the third — and _inc/gamelist-grid.xml
    # deliberately keeps its own copy of the shared chrome, which would mask a
    # deletion from _inc/common.xml if these were pooled. That exact mutation
    # escaped the first version of this guard.
    for view in tree.iter("view"):
        sounds = list(view.iter("sound"))
        if not sounds:
            continue
        blocks += 1
        view_name = view.get("name", "?")
        found = set()
        for el in sounds:
            name = el.get("name") or ""
            found.add(name)
            if name in DEAD:
                bad.append(f"{rel}: <sound name=\"{name}\"> is INERT — ES never "
                           f"asks for that name. Scroll sounds are a <scrollSound> "
                           f"property; confirm is \"launch\". (#21)")
            elif name not in LIVE:
                bad.append(f"{rel}: <sound name=\"{name}\"> is not one of the "
                           f"{sorted(LIVE)} ES requests, so it can never play")
            if el.find("path") is None:
                bad.append(f"{rel}: <sound name=\"{name}\"> has no <path>")
        # The converse: a name ES asks for that this block omits falls back to
        # ES's silent default, a regression nothing else would surface.
        missing = LIVE - found
        if missing:
            bad.append(f"{rel}: <view name=\"{view_name}\"> declares no "
                       f"{sorted(missing)} — ES asks for {sorted(LIVE)} in every "
                       f"gamelist view and plays nothing for any it cannot find")

if blocks < 2:
    bad.append(f"only {blocks} <view> block(s) declare sounds — expected the "
               f"shared chrome in _inc/common.xml and the grid's own copy in "
               f"_inc/gamelist-grid.xml, so this check is not seeing the tree")

if bad:
    print("\n".join(bad), file=sys.stderr); sys.exit(1)
PY
rc=$?
check "only launch / back / menuOpen are declared, and all three are" "${rc}"

echo
echo "scroll sounds are a property on the scrolling component:"

python3 - "${REPO_ROOT}" <<'PY'
import os, sys, xml.etree.ElementTree as ET

# scrollSound is read by CarouselComponent (cpp:566), TextListComponent
# (h:727) and ImageGridComponent, and defaults to EMPTY in each — an unset
# component navigates in silence. Each entry is the file, the element tag, its
# name attribute, and which variable it must reference.
#
# All four take the SAME tick, a deliberate reversal of audit A2: a distinct
# horizontal swoosh was built, shipped to hardware and rejected by ear (style
# guide section 10). The variable is still pinned per component rather than
# merely required to be non-empty, so a future edit cannot quietly point one
# of them somewhere else.
REQUIRED = [
    ("_inc/system.xml",        "carousel",  "systemcarousel", "${soundNavigate}"),
    ("_inc/gamelist-card.xml", "textlist",  "gamelist",       "${soundNavigate}"),
    ("_inc/gamelist-list.xml", "textlist",  "gamelist",       "${soundNavigate}"),
    ("_inc/gamelist-grid.xml", "imagegrid", "gamegrid",       "${soundNavigate}"),
]

root = sys.argv[1]
bad = []
for rel, tag, name, want in REQUIRED:
    path = os.path.join(root, rel)
    if not os.path.isfile(path):
        bad.append(f"{rel}: missing — this check would pass vacuously")
        continue
    els = [e for e in ET.parse(path).iter(tag) if e.get("name") == name]
    if not els:
        bad.append(f"{rel}: no <{tag} name=\"{name}\">")
        continue
    for el in els:
        node = el.find("scrollSound")
        if node is None:
            bad.append(f"{rel}: <{tag} name=\"{name}\"> has no <scrollSound> — "
                       f"the property defaults to empty, so it is silent (#21)")
        elif (node.text or "").strip() != want:
            bad.append(f"{rel}: <{tag} name=\"{name}\"> scrollSound is "
                       f"{(node.text or '').strip()!r}, expected {want!r}")

if bad:
    print("\n".join(bad), file=sys.stderr); sys.exit(1)
PY
rc=$?
check "carousel and all three gamelist styles take the one shared tick" "${rc}"

echo
echo "the sound variables resolve to files that exist:"

python3 - "${REPO_ROOT}" <<'PY'
import os, sys, xml.etree.ElementTree as ET

# An empty or misspelled path is not an error in ES: ThemeData drops an empty
# PATH property outright (ThemeData.cpp:1671) and Sound::init returns early for
# one that does not exist (Sound.cpp:67). Both are silent, which is the exact
# failure mode this whole issue was about.
WANT = {
    "soundNavigate":     "sounds/navigate.wav",
    "soundSelect":       "sounds/select.wav",
    "soundBack":         "sounds/back.wav",
}

root = sys.argv[1]
bad = []
tree = ET.parse(os.path.join(root, "_inc", "common.xml"))
declared = {}
for block in tree.iter("variables"):
    for el in block:
        if el.tag in WANT:
            declared[el.tag] = (el.text or "").strip()

for var, rel in WANT.items():
    if var not in declared:
        bad.append(f"_inc/common.xml declares no <{var}> variable")
        continue
    value = declared[var]
    if not value:
        bad.append(f"<{var}> is empty — ThemeData drops an empty PATH, so the "
                   f"binding silently does nothing")
        continue
    path = os.path.join(root, value.lstrip("./"))
    if not os.path.isfile(path):
        bad.append(f"<{var}> points at {value}, which does not exist")

if bad:
    print("\n".join(bad), file=sys.stderr); sys.exit(1)
PY
rc=$?
check "all three sound variables exist and point at real files" "${rc}"

echo
echo "the rejected swoosh has not grown back:"

python3 - "${REPO_ROOT}" <<'GUARD'
import glob, os, sys, xml.etree.ElementTree as ET

# Audit A2 asked for a distinct horizontal swoosh. One was built
# (scripts/gen-swoosh.py -> sounds/system-scroll.wav, 870 Hz over 200 ms),
# deployed to the TrimUI Brick and rejected by ear as out of place against
# Ant's existing set. Both axes now share sounds/navigate.wav.
#
# This guard exists because the #34 halo went round the same loop three
# times: a leftover asset and its generator read as an unfinished feature
# rather than a settled decision. Deleting an asset means deleting its
# generator - the gen-*.py scripts cite each other as the pattern to copy,
# so a surviving one would recreate the asset.
root = sys.argv[1]
bad = []

for gone in ("sounds/system-scroll.wav", "scripts/gen-swoosh.py"):
    if os.path.exists(os.path.join(root, gone)):
        bad.append(f"{gone} is back - a distinct horizontal swoosh is a "
                   f"settled will-not-do, rejected on hardware (style guide 10)")

# Keyed on the PROPERTY rather than the spelling: a second scroll sound under
# any name is the same decision being re-litigated. Every scrollSound in the
# tree must resolve to the one shared variable.
files = sorted(glob.glob(os.path.join(root, "_inc", "**", "*.xml"), recursive=True))
if len(files) < 20:
    bad.append(f"only found {len(files)} _inc XML files - glob is wrong, and "
               f"the rest of this check would pass vacuously")
found = 0
for path in files:
    rel = os.path.relpath(path, root)
    for el in ET.parse(path).iter("scrollSound"):
        found += 1
        value = (el.text or "").strip()
        if value != "${soundNavigate}":
            bad.append(f"{rel}: a <scrollSound> resolves to {value!r}, not "
                       f"the shared soundNavigate - a second scroll sound "
                       f"was tried on hardware and rejected (style guide 10)")
if found < 4:
    bad.append(f"found {found} <scrollSound> properties, expected 4 (the "
               f"carousel plus one per gamelist style)")

# And no variable may point at a second scroll asset.
for block in ET.parse(os.path.join(root, "_inc", "common.xml")).iter("variables"):
    for el in block:
        if el.tag == "soundSystemScroll":
            bad.append("_inc/common.xml still declares <soundSystemScroll> - "
                       "removed with the swoosh")

if bad:
    print("\n".join(bad), file=sys.stderr); sys.exit(1)
GUARD
rc=$?
check "no second scroll sound, and its generator is gone too" "${rc}"

echo
echo "ES's own master switch is documented:"

# EnableSounds defaults to FALSE (Settings.cpp:168) and a stock TrimUI Brick
# carries no such key, so every sound in this theme is off out of the box. A
# user who cannot hear the feature will file a bug against the theme unless
# the README says where the switch is.
grep -qi 'Enable Navigation Sounds' "${REPO_ROOT}/README.md"
check "README tells users where ES's navigation-sound switch is" $?

echo
if [[ "${fail}" -eq 0 ]]; then
  cat <<'EOF'
all checks passed

These are structural only — none of them can hear anything. To verify that ES
actually plays these sounds, run the capture harness (needs Docker and a
scraped library):

  scripts/capture-audio.sh --library /tmp/library \
    --expect sound,sound,sound,any,sound,sound,sound,any

  expected: the three carousel moves at ~870 Hz for ~200 ms (the swoosh),
            the three gamelist moves at ~6450 Hz (the tick)

  scripts/capture-audio.sh --library /tmp/library --enable-sounds false \
    --expect silence,silence,silence,silence,silence,silence,silence,silence

  expected: total silence — ES's master switch gates every one of them
EOF
else
  echo "FAILURES"
fi
exit "${fail}"
