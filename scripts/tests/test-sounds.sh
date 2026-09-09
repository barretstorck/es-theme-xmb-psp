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
# The carousel gets the swoosh and the three list components get the tick:
# that IS the horizontal-vs-vertical distinction issue #21 asked for. Binding
# both to one variable is the state the theme shipped in, and it is why A2 was
# filed, so the variable is pinned per component rather than merely required
# to be non-empty.
REQUIRED = [
    ("_inc/system.xml",        "carousel",  "systemcarousel", "${soundSystemScroll}"),
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
check "carousel takes the swoosh; all three gamelist styles take the tick" "${rc}"

echo
echo "the sound variables resolve to files that exist:"

python3 - "${REPO_ROOT}" <<'PY'
import os, sys, xml.etree.ElementTree as ET

# An empty or misspelled path is not an error in ES: ThemeData drops an empty
# PATH property outright (ThemeData.cpp:1671) and Sound::init returns early for
# one that does not exist (Sound.cpp:67). Both are silent, which is the exact
# failure mode this whole issue was about.
WANT = {
    "soundSystemScroll": "sounds/system-scroll.wav",
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
check "all four sound variables exist and point at real files" "${rc}"

echo
echo "the swoosh is distinguishable from the tick:"

python3 - "${REPO_ROOT}" <<'PY'
import os, sys, wave
import numpy as np

# The point of A2 is that a user can TELL the two apart. Two sounds that are
# both correctly wired and both bright ticks would pass every check above and
# still not deliver the issue. So this measures them.
#
# Thresholds are loose on purpose: they are asserting "these occupy different
# ends of the spectrum", not pinning gen-swoosh.py's exact output, which would
# turn any retune into a test edit.
root = sys.argv[1]
bad = []

def spectrum(rel):
    with wave.open(os.path.join(root, rel)) as w:
        p = w.getparams()
        d = np.frombuffer(w.readframes(p.nframes), dtype="<i2").astype(np.float64)
    if p.nchannels == 2:
        d = d.reshape(-1, 2).mean(axis=1)
    mag = np.abs(np.fft.rfft(d * np.hanning(d.size)))
    mag[0] = 0.0
    freq = np.fft.rfftfreq(d.size, 1 / p.framerate)
    return freq, mag, d.size / p.framerate

for rel in ("sounds/system-scroll.wav", "sounds/navigate.wav"):
    if not os.path.isfile(os.path.join(root, rel)):
        bad.append(f"{rel} is missing")
if bad:
    print("\n".join(bad), file=sys.stderr); sys.exit(1)

sf, sm, sdur = spectrum("sounds/system-scroll.wav")
nf, nm, _ = spectrum("sounds/navigate.wav")

swoosh_low = sm[sf < 2000].sum() / sm.sum()
tick_high = nm[nf > 5000].sum() / nm.sum()
swoosh_peak = sf[int(np.argmax(sm))]
tick_peak = nf[int(np.argmax(nm))]

if swoosh_low < 0.60:
    bad.append(f"system-scroll.wav has only {swoosh_low:.0%} of its energy "
               f"under 2 kHz — A2 calls for a low swoosh, not another tick")
if tick_high < 0.50:
    bad.append(f"navigate.wav has only {tick_high:.0%} of its energy over "
               f"5 kHz — it is meant to be the bright one")
if swoosh_peak > tick_peak / 2:
    bad.append(f"the two peaks are {swoosh_peak:.0f} Hz and {tick_peak:.0f} Hz "
               f"— less than an octave apart, so they will not read as "
               f"different sounds")
# A2 asks for "about 200 ms". Anything much longer overruns the dwell between
# two fast carousel presses and the sounds pile up on each other.
if not 0.10 <= sdur <= 0.35:
    bad.append(f"system-scroll.wav is {sdur * 1000:.0f}ms; A2 specifies about "
               f"200ms and over ~350ms consecutive moves overlap")

if bad:
    print("\n".join(bad), file=sys.stderr); sys.exit(1)
PY
rc=$?
check "the swoosh is low and short, the tick is bright, an octave-plus apart" "${rc}"

echo
echo "the generator for the shipped asset is present:"

# Deleting a generated asset means deleting its generator, and keeping one
# means keeping the other — the reverse of the lesson gen-halo.py taught in
# #34, where the generator outlived the asset and could have recreated it.
[[ -f "${REPO_ROOT}/scripts/gen-swoosh.py" ]]
check "scripts/gen-swoosh.py accompanies sounds/system-scroll.wav" $?

grep -q 'system-scroll.wav' "${REPO_ROOT}/CREDITS.md"
check "CREDITS.md accounts for system-scroll.wav" $?

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
