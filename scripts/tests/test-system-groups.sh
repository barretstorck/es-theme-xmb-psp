#!/usr/bin/env bash
# Structural test for ES system GROUPS in the carousel (issue #39).
#
# Two distinct es_systems.cfg keys decide what a carousel entry looks like, and
# they are easy to confuse:
#
#   <theme>  names the art folder the theme renders (${system.theme}).
#   <group>  folds the system into a PARENT carousel entry; the child keeps its
#            own theme folder and stops being a carousel entry at all.
#
# Two bugs came out of confusing them:
#
#   1. make-library-systems.py read batocera's `group:` key and wrote it into
#      <theme>, inventing ~73 theme-folder collisions that no real
#      es_systems.cfg has (Knulli's 183-system cfg has ZERO). That is where
#      issue #39's "sdlpop renders as PORTS" came from -- it is a harness
#      artefact; on hardware sdlpop's theme folder is sdlpop.
#   2. When a <group> value is NOT itself a system, ES fabricates a carousel
#      entry whose name AND theme folder are the raw group string
#      (SystemData::createGroupedSystems, SystemData.cpp:426-475). atari8bit is
#      the only such group on Knulli (batocera master also makes 'amiga'
#      synthetic), and the theme shipped no atari8bit.png -- so it rendered with
#      ES's built-in dark logoText and the caption "ATARI8BIT".
#
# Both failures are silent: ES logs nothing for a missing carousel logo, and a
# wrong <theme> in a generated harness library just renders a different-but-
# plausible icon. Hence a structural guard.
#
# NOTE: deliberately NOT `set -e` — see the note in test-gamelist-styles.sh.
set -uo pipefail

# shellcheck source=scripts/lib/test-lib.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../lib" && pwd)/test-lib.sh"

ICONS="${REPO_ROOT}/art/system-icons"
THEME="${REPO_ROOT}/theme.xml"
GEN="${REPO_ROOT}/scripts/make-library-systems.py"

echo "the generator must keep theme: and group: apart:"

# A miniature es_systems.yml exercising all four shapes: plain, theme-only,
# group-only, and both. Inline so the test needs no network and no cache.
TMP="$(mktemp -d)"
trap 'rm -rf "${TMP}"' EXIT
cat > "${TMP}/mini.yml" <<'YML'
snes:
  name: Super Nintendo
  extensions: [smc, sfc]
  group: snes
sdlpop:
  name: SdlPop
  extensions: [sdlpop]
  group: ports
lynx:
  name: Atari Lynx
  extensions: [lnx]
  theme: atarilynx
jaguar:
  name: Jaguar
  extensions: [j64]
  theme: atarijaguar
  group: jaguar
YML
mkdir -p "${TMP}/lib"/{snes,sdlpop,lynx,jaguar}
"${GEN}" "${TMP}/lib" --yml "${TMP}/mini.yml" >/dev/null 2>&1
CFG="${TMP}/lib/es_systems.cfg"

sys_field() { # sys_field <name> <tag>  -> the tag's text, empty if absent
  python3 - "$1" "$2" "${CFG}" <<'PY'
import sys, xml.etree.ElementTree as ET
name, tag, path = sys.argv[1], sys.argv[2], sys.argv[3]
for s in ET.parse(path).getroot().findall("system"):
    if s.findtext("name") == name:
        print(s.findtext(tag) or "")
        break
PY
}

check "generated a cfg at all" "$([[ -f "${CFG}" ]]; echo $?)"
# The regression itself: group: must never become the theme folder.
check "sdlpop keeps its own theme folder (not 'ports')" \
  "$([[ "$(sys_field sdlpop theme)" == "sdlpop" ]]; echo $?)"
check "sdlpop carries <group>ports</group>" \
  "$([[ "$(sys_field sdlpop group)" == "ports" ]]; echo $?)"
# theme: was previously ignored entirely, so name!=theme systems were wrong too.
check "lynx uses its explicit theme: (atarilynx)" \
  "$([[ "$(sys_field lynx theme)" == "atarilynx" ]]; echo $?)"
check "lynx has no <group>" \
  "$([[ -z "$(sys_field lynx group)" ]]; echo $?)"
check "jaguar takes theme and group from different keys" \
  "$([[ "$(sys_field jaguar theme)" == "atarijaguar" && "$(sys_field jaguar group)" == "jaguar" ]]; echo $?)"
check "snes (group == its own name) is unchanged" \
  "$([[ "$(sys_field snes theme)" == "snes" && "$(sys_field snes group)" == "snes" ]]; echo $?)"

echo
echo "every carousel entry a group can produce needs an icon:"

# Theme folder each <group> resolves to. Where a system of the group's name
# exists ES reuses it and that system's OWN theme folder wins (jaguar ->
# atarijaguar); where none exists, the raw group string becomes the theme
# folder. Knulli's shipped es_systems.cfg has 11 groups and exactly ONE
# synthetic: atari8bit. batocera master differs - 'amiga' is synthetic there
# (no amiga: system) and it has a 'windows' group Knulli lacks. Verified
# against Knulli's es_systems.cfg and batocera master's es_systems.yml,
# 2026-09-08.
GROUP_THEME_FOLDERS=(
  amiga        # real system on Knulli, synthetic on batocera master
  atari8bit    # synthetic on both - the entry this issue was about
  c64
  atarijaguar  # group 'jaguar' reuses the real jaguar system
  lcdgames
  megadrive
  nes
  ports
  snes
  tools        # Knulli-only group
  emulators    # Knulli-only group
)
for folder in "${GROUP_THEME_FOLDERS[@]}"; do
  check "art/system-icons/${folder}.png exists" "$([[ -f "${ICONS}/${folder}.png" ]]; echo $?)"
done

# A group the theme knowingly does not cover, asserted as STILL missing rather
# than quietly dropped from the list above. 'windows' exists only on batocera
# master, which the theme does not target - it is one of 81 batocera-only
# systems with no icon, tracked as a whole in #46 (compatibility matrix). Ship
# the art and this check fails, telling you to promote it.
KNOWN_MISSING=(windows)
for folder in "${KNOWN_MISSING[@]}"; do
  check "${folder}.png still absent, batocera-only, see #46 - promote it to GROUP_THEME_FOLDERS if you ship one" \
    "$([[ ! -f "${ICONS}/${folder}.png" ]]; echo $?)"
done

# knulli-systems.txt is the icon set's manifest, and honouring theme: can remap
# a system onto a folder the set never had (imageviewer -> screenshots). That
# turns a working icon into ES's dark logoText fallback - the very symptom #39
# is about - so sweep the whole manifest rather than spot-checking.
if [[ -f "${REPO_ROOT}/scripts/es_systems.yml.cache" ]]; then
  missing="$(python3 - "${REPO_ROOT}" <<'PYEOF'
import os, re, sys
root = sys.argv[1]
text = open(os.path.join(root, "scripts/es_systems.yml.cache")).read()
themes = {}
for block in re.split(r"\n(?=\S[^\s:]*:\s*\n)", text):
    key = re.match(r"([A-Za-z0-9_\-]+):\s*\n", block)
    if not key:
        continue
    th = re.search(r"^\s+theme:\s*(\S+)", block, re.M)
    themes[key.group(1)] = th.group(1) if th else key.group(1)
icons = set(os.listdir(os.path.join(root, "art/system-icons")))
manifest = [l.strip() for l in open(os.path.join(root, "scripts/knulli-systems.txt"))
            if l.strip() and not l.startswith("#")]
print(" ".join(f"{s}->{themes[s]}" for s in manifest
                if s in themes and themes[s] + ".png" not in icons))
PYEOF
)"
  check "every knulli-systems.txt entry still resolves to an icon after theme: remapping${missing:+ (missing: ${missing})}" \
    "$([[ -z "${missing}" ]]; echo $?)"
else
  echo "  skip - theme: remapping sweep (no scripts/es_systems.yml.cache; run make-library-systems.py once)"
fi

echo
echo "the atari8bit caption override is wired up:"

OVERRIDE="${REPO_ROOT}/_inc/group-name/atari8bit.xml"
check "_inc/group-name/atari8bit.xml exists" "$([[ -f "${OVERRIDE}" ]]; echo $?)"
check "theme.xml includes it conditionally on \${system.theme}" \
  "$(grep -q "system.theme} == 'atari8bit'" "${THEME}"; echo $?)"
# Property merge is last-write-wins, so an include placed before system.xml is
# silently overwritten - the exact trap PR #37 documented for the collections.
#
# NOTE: these two run python3 as a STATEMENT and read $?. Wrapping a heredoc in
# $( ... ) captures stdout, which is empty here, and `[[ "" -eq 0 ]]` is true -
# so both checks passed unconditionally in the first version of this file.
python3 - "${THEME}" <<'PYEOF'
import sys
lines = open(sys.argv[1]).read().splitlines()
sysline = next(i for i, l in enumerate(lines) if "./_inc/system.xml" in l)
ovline = next(i for i, l in enumerate(lines) if "group-name/atari8bit.xml" in l)
sys.exit(0 if ovline > sysline else 1)
PYEOF
check "the include lands AFTER _inc/system.xml in theme.xml" $?

# Overriding anything but <text> would drop system.xml's geometry and font.
python3 - "${OVERRIDE}" <<'PYEOF'
import sys, xml.etree.ElementTree as ET
el = ET.parse(sys.argv[1]).getroot().find("view/text")
sys.exit(0 if [c.tag for c in el] == ["text"] else 1)
PYEOF
check "the override sets only <text>, inheriting geometry from system.xml" $?

echo
if [[ "${fail}" -eq 0 ]]; then echo "all checks passed"; else echo "FAILURES"; fi
exit "${fail}"
