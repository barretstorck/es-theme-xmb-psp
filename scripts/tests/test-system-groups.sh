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
#      (SystemData::createGroupedSystems, SystemData.cpp:426-475). "atari8bit"
#      is the only such group in batocera/Knulli, and the theme shipped no
#      atari8bit.png -- so it rendered with ES's built-in dark logoText and the
#      caption "ATARI8BIT".
#
# Both failures are silent: ES logs nothing for a missing carousel logo, and a
# wrong <theme> in a generated harness library just renders a different-but-
# plausible icon. Hence a structural guard.
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

# Theme folder each <group> in batocera/Knulli es_systems.yml resolves to.
# Where a system of the same name exists, ES reuses it and its OWN theme folder
# wins (jaguar -> atarijaguar); where none exists, the raw group string is the
# theme folder (atari8bit, amiga). Verified against Knulli's shipped
# es_systems.cfg and batocera master's es_systems.yml on 2026-09-08.
GROUP_THEME_FOLDERS=(
  amiga        # no 'amiga' system on batocera master; synthetic
  atari8bit    # synthetic on both — the entry this issue was about
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

echo
echo "the atari8bit caption override is wired up:"

OVERRIDE="${REPO_ROOT}/_inc/group-name/atari8bit.xml"
check "_inc/group-name/atari8bit.xml exists" "$([[ -f "${OVERRIDE}" ]]; echo $?)"
check "theme.xml includes it conditionally on \${system.theme}" \
  "$(grep -q "system.theme} == 'atari8bit'" "${THEME}"; echo $?)"
# Property merge is last-write-wins, so an include placed before system.xml is
# silently overwritten — the exact trap PR #37 documented for the collections.
check "the include lands AFTER _inc/system.xml in theme.xml" \
  "$(python3 - "${THEME}" <<'PY'
import sys
lines = open(sys.argv[1]).read().splitlines()
sysline = next(i for i, l in enumerate(lines) if "./_inc/system.xml" in l)
ovline = next(i for i, l in enumerate(lines) if "group-name/atari8bit.xml" in l)
sys.exit(0 if ovline > sysline else 1)
PY
)"
# Overriding anything but <text> would drop system.xml's geometry and font.
check "the override sets only <text>, inheriting geometry from system.xml" \
  "$(python3 - "${OVERRIDE}" <<'PY'
import sys, xml.etree.ElementTree as ET
el = ET.parse(sys.argv[1]).getroot().find("view/text")
kids = [c.tag for c in el]
sys.exit(0 if kids == ["text"] else 1)
PY
)"

echo
if [[ "${fail}" -eq 0 ]]; then echo "all checks passed"; else echo "FAILURES"; fi
exit "${fail}"
