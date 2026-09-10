#!/usr/bin/env bash
# Structural guard: the selected-icon halo stays removed (issue #34).
#
# The halo was tuned and pulled three times. Twice it came back, because the
# scaffold survived each removal — an asset, two variable pairs and a
# commented-out element block sitting in _inc/system.xml look like an
# unfinished feature rather than a settled decision, and #34's own history is
# two people reading them that way. v1.0 deleted all of it; this file is what
# stops it growing back by accident.
#
# The guard is deliberately structural rather than textual. A plain
# `grep -q halo` over the theme XML matches the word inside comments and inside
# the docs' own explanation of why there is no halo, so it would either fire on
# prose or, written as a negation, pass vacuously the moment someone renames
# the element. The element check therefore parses the XML and inspects real
# `name` attributes.
#
# That still only catches things spelled "halo". A re-added glow called
# something else is caught by two different checks instead: the system view's
# mStaticBackgrounds membership is pinned to exactly the four wave elements,
# and zIndex 4 - the band the halo occupied, between the wave layers and the
# carousel - is asserted to stay empty. Those are the two properties any
# back-layer glow must have, whatever it is named.
#
# NOTE: deliberately NOT `set -e` — see the note in test-gamelist-styles.sh.
set -uo pipefail

# shellcheck source=scripts/lib/test-lib.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../lib" && pwd)/test-lib.sh"

# `check "$(cmd)" $?` would report the SUBSTITUTION's status, because bash
# expands arguments left to right — so each python guard stores its exit
# status in `rc` on its own line and passes that.

echo "the halo scaffold is gone:"

python3 - "${REPO_ROOT}" <<'PY'
import glob, os, sys, xml.etree.ElementTree as ET
root = sys.argv[1]
bad = []
files = sorted(glob.glob(os.path.join(root, "*.xml")) +
               glob.glob(os.path.join(root, "_inc", "**", "*.xml"), recursive=True) +
               glob.glob(os.path.join(root, "colors", "*.xml")))
if len(files) < 20:
    bad.append(f"only found {len(files)} theme XML files — glob is wrong, "
               "the rest of this check would pass vacuously")
for path in files:
    try:
        tree = ET.parse(path)                      # comments are dropped here
    except ET.ParseError as e:
        bad.append(f"{os.path.relpath(path, root)}: not well-formed XML: {e}")
        continue
    for el in tree.iter():
        name = el.get("name") or ""
        if "halo" in name.lower():
            bad.append(f"{os.path.relpath(path, root)}: live <{el.tag} "
                       f"name=\"{name}\"> — the halo is settled won't-do (#34)")
        # variable declarations are elements named after the variable
        if el.tag.lower().startswith(("halo", "rowhalo")):
            bad.append(f"{os.path.relpath(path, root)}: live <{el.tag}> "
                       "halo variable — removed in v1.0 (#34)")
        for attr, val in el.attrib.items():
            if "halo" in val.lower():
                bad.append(f"{os.path.relpath(path, root)}: <{el.tag} "
                           f"{attr}=\"{val}\"> still refers to the halo")
    # <path> bodies are text, not attributes
    for el in tree.iter():
        if el.text and "halo" in el.text.lower():
            bad.append(f"{os.path.relpath(path, root)}: <{el.tag}> body "
                       f"references the halo: {el.text.strip()[:60]}")
if bad:
    print("\n".join(bad), file=sys.stderr); sys.exit(1)
PY
rc=$?
check "no live halo element, variable or reference in any theme XML" "${rc}"

[[ ! -e "${REPO_ROOT}/art/halo.png" ]]
check "art/halo.png is deleted" $?

# A resurrected element would most plausibly arrive commented out again, the
# way it sat on main for three releases. Catch that shape specifically.
! grep -rq 'staticBackgroundHalo' "${REPO_ROOT}/_inc" "${REPO_ROOT}/theme.xml" "${REPO_ROOT}/splash.xml"
check "no staticBackgroundHalo left in the theme XML, commented or otherwise" $?

[[ ! -e "${REPO_ROOT}/scripts/gen-halo.py" ]]
check "the generator that recreates art/halo.png is deleted" $?

echo
echo "the back-layer slot it occupied stays empty:"

python3 - "${REPO_ROOT}" <<'PY'
import os, sys, xml.etree.ElementTree as ET
root = sys.argv[1]
bad = []
# SystemView routes every element whose name starts with staticBackground into
# mStaticBackgrounds and paints the group beneath the carousel. That set is the
# wave, and only the wave.
WAVE = {"staticBackgroundWave", "staticBackgroundLayer1",
        "staticBackgroundLayer2", "staticBackgroundLayer3"}
tree = ET.parse(os.path.join(root, "_inc", "system.xml"))
found = {el.get("name") for el in tree.iter()
         if (el.get("name") or "").startswith("staticBackground")}
if found != WAVE:
    bad.append(f"mStaticBackgrounds is {sorted(found)}, expected the four wave "
               f"elements {sorted(WAVE)} - extra: {sorted(found - WAVE)}, "
               f"missing: {sorted(WAVE - found)}")
# zIndex 4 sat between the wave layers (0-3) and the carousel (5+). It is the
# only band from which an element can light the selected icon from behind, so
# anything landing there is the halo again under another name.
for el in tree.iter():
    z = el.find("zIndex")
    if z is not None and (z.text or "").strip() == "4":
        bad.append(f"<{el.tag} name={el.get('name')!r}> claims zIndex 4, the "
                   "band the halo occupied - it is documented as free (2.4)")
if bad:
    print("\n".join(bad), file=sys.stderr); sys.exit(1)
PY
rc=$?
check "system view holds only the four wave staticBackgrounds, and zIndex 4 is free" "${rc}"

echo
echo "the decision is documented where someone would look:"

grep -q '### 6.2 Selected-icon halo — removed' "${REPO_ROOT}/docs/psp-xmb-style-guidelines.md"
check "style guide §6.2 records the removal" $?

grep -q 'There is no selected-icon halo, in either view' "${REPO_ROOT}/docs/psp-xmb-style-guidelines.md"
check "style guide §10 lists it as settled — do not re-litigate" $?

grep -q 'Any selected-icon halo, tinted or white' "${REPO_ROOT}/docs/psp-authenticity-audit.md"
check "audit lists it under deliberately omitted" $?

echo
if [[ "${fail}" -eq 0 ]]; then echo "all checks passed"; else echo "FAILURES"; fi
exit "${fail}"
