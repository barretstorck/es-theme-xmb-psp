#!/usr/bin/env bash
# Structural test for the Button Icons subset and the helpsystem glyphs
# (audit S4, issue #8).
#
# Everything this guards fails SILENTLY in ES. There is no log line for any of
# it, and all three failures look identical on screen — ES just draws its own
# built-in glyph:
#
#   * a misspelled property name. ThemeData.cpp:493-514 lists exactly 12 icon
#     properties for <helpsystem>; anything else is dropped at parse time.
#   * a path that does not resolve. HelpComponent::updateGrid only takes the
#     themed icon when ResourceManager::fileExists() passes.
#   * an unsubstituted ${helpIcon*} variable, which is just the previous case
#     with a stranger filename.
#
# And one that does NOT fall back, but renders confidently wrong: a glyph
# assigned to the wrong slot. ES nails each of the four face slots to a
# physical button position — iconA=EAST, iconB=SOUTH, iconX=NORTH, iconY=WEST
# — so swapping two is invisible to every check except an explicit table.
# That table is the core of this file.
#
# NOTE: deliberately NOT `set -e` — see the note in test-gamelist-styles.sh.
set -uo pipefail

# shellcheck source=scripts/lib/test-lib.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../lib" && pwd)/test-lib.sh"

THEME="${REPO_ROOT}/theme.xml"
COMMON="${REPO_ROOT}/_inc/common.xml"
GRID="${REPO_ROOT}/_inc/gamelist-grid.xml"
SET_FILES=("${REPO_ROOT}"/_inc/buttons-*.xml)
HELP_ART="${REPO_ROOT}/art/help"

# The 12 icon properties ES actually understands, verbatim from the helpsystem
# entry of ThemeData.cpp's element property map (:493-514) in the pinned build.
# Note there is no iconLR, though ICON_PATH_MAP does have an "lr" prompt.
ES_ICON_PROPS=(iconUpDown iconLeftRight iconUpDownLeftRight iconA iconB iconX
               iconY iconL iconR iconStart iconSelect iconF1)

# Print the <helpsystem> block of a file.
help_block() { # help_block <file>
  awk '/<helpsystem/ { inblk = 1 } inblk { print } /<\/helpsystem>/ { inblk = 0 }' "$1"
}

# Print "<prop> <value>" for every icon PATH property in a file's helpsystem
# block. iconColor is filtered out: it starts with "icon" but is a COLOR, not a
# PATH, so an exists-on-disk check would fail on a perfectly correct theme.
#
# NO BACKREFERENCE in the closing tag, deliberately. Alpine ships busybox sed,
# whose -E does not support \1 in the PATTERN — it silently matches nothing
# rather than erroring, so the first version of this function returned zero
# lines and every check built on it passed against an empty string. Two guards
# here were green and vacuous before a count assertion caught them. Same class
# of bug as the two vacuous checks fixed in the #39 review; if you add a check,
# break the thing it guards and watch it go red before trusting it.
icon_pairs() { # icon_pairs <file>
  help_block "$1" \
    | sed -nE 's|^[[:space:]]*<(icon[A-Za-z0-9]+)>([^<]*)</icon[A-Za-z0-9]+>[[:space:]]*$|\1 \2|p' \
    | grep -v '^iconColor '
}

# Same shape, for the <helpIcon*> variable definitions in the subset files.
set_pairs() { # set_pairs <file>
  sed -nE 's|^[[:space:]]*<(helpIcon[ABXY])>([^<]*)</helpIcon[ABXY]>[[:space:]]*$|\1 \2|p' "$1"
}

# Strip XML comments. These files document the very traps they avoid — the
# phrase <view name="grid"> appears in buttons-nintendo.xml's header explaining
# why it must NOT be there — so a naive grep flags the explanation as the bug.
# awk, not python3: the glyph-content check further down is skipped when
# Pillow is absent, which is fine because it announces the skip. This guard
# must never be skippable — a set file that declared a view would then pass
# silently on a python3-less host, and that regression ships to every user who
# pinned Gamelist View Style = grid.
strip_comments() { # strip_comments <file>
  awk '{
    while (1) {
      if (incomment) {
        i = index($0, "-->")
        if (i == 0) { $0 = ""; break }
        $0 = substr($0, i + 3); incomment = 0
      }
      i = index($0, "<!--")
      if (i == 0) break
      rest = substr($0, i + 4); $0 = substr($0, 1, i - 1)
      j = index(rest, "-->")
      if (j == 0) { incomment = 1; break }
      $0 = $0 substr(rest, j + 3)
    }
    print
  }' "$1"
}

echo "the property names must be ones ES actually reads:"

for f in "${COMMON}" "${GRID}"; do
  rel="${f#"${REPO_ROOT}/"}"
  bad=""
  while read -r prop _; do
    [[ -z "${prop}" ]] && continue
    found=1
    for known in "${ES_ICON_PROPS[@]}"; do
      [[ "${prop}" == "${known}" ]] && found=0 && break
    done
    [[ "${found}" -eq 0 ]] || bad+=" ${prop}"
  done < <(icon_pairs "${f}")
  check "${rel} uses only ES helpsystem icon properties (${bad:-none unknown})" \
    "$([[ -z "${bad}" ]]; echo $?)"
done

echo
echo "both helpsystem declarations must stay in step:"

# Box Art Grid declares its own <helpsystem> inside <view name="grid">
# (deliberately, b5e2063). Nothing makes the two blocks agree, so a slot added
# to one and not the other would give correct glyphs in two gamelist styles and
# stock ones in the third — the exact split the issue called out.
common_props="$(icon_pairs "${COMMON}" | awk '{print $1}' | sort)"
grid_props="$(icon_pairs "${GRID}" | awk '{print $1}' | sort)"
check "common.xml and gamelist-grid.xml declare the same icon slots" \
  "$([[ "${common_props}" == "${grid_props}" ]]; echo $?)"
check "common.xml and gamelist-grid.xml point them at the same art" \
  "$([[ "$(icon_pairs "${COMMON}" | sort)" == "$(icon_pairs "${GRID}" | sort)" ]]; echo $?)"
check "all 12 of ES's icon slots are themed" \
  "$([[ "$(wc -l <<<"${common_props}")" -eq 12 ]]; echo $?)"

echo
echo "every path must resolve — an unresolvable one silently falls back:"

missing=""
unresolved=""
while read -r prop value; do
  [[ -z "${prop}" ]] && continue
  if [[ "${value}" == *'${'* ]]; then
    # A variable reference is fine here; it is checked against the subset
    # files below. What must never survive is a variable in a LITERAL slot.
    continue
  fi
  [[ -f "${REPO_ROOT}/${value#./}" ]] || missing+=" ${prop}=${value}"
done < <(icon_pairs "${COMMON}")
check "every literal icon path in common.xml exists on disk (${missing:-all present})" \
  "$([[ -z "${missing}" ]]; echo $?)"

for f in "${SET_FILES[@]}"; do
  rel="${f#"${REPO_ROOT}/"}"
  bad=""
  while read -r _ value; do
    [[ -z "${value}" ]] && continue
    [[ -f "${REPO_ROOT}/${value#./}" ]] || bad+=" ${value}"
  done < <(set_pairs "${f}")
  check "${rel}: every glyph path exists (${bad:-all present})" \
    "$([[ -n "$(set_pairs "${f}")" && -z "${bad}" ]]; echo $?)"
done

echo
echo "the variables the helpsystem consumes must be defined by every set:"

# ${helpIconA} left unsubstituted is not an error in ES — it becomes a literal
# path that fails fileExists, i.e. the stock glyph again.
consumed="$(icon_pairs "${COMMON}" | grep -oE '\$\{helpIcon[A-Za-z]+\}' \
            | tr -d '${}' | sort -u)"
check "common.xml consumes exactly 4 helpIcon variables" \
  "$([[ "$(wc -l <<<"${consumed}")" -eq 4 ]]; echo $?)"

for f in "${SET_FILES[@]}"; do
  rel="${f#"${REPO_ROOT}/"}"
  defined="$(grep -oE '<helpIcon[A-Za-z]+>' "${f}" | tr -d '<>' | sort -u)"
  check "${rel} defines every variable common.xml consumes" \
    "$([[ "${defined}" == "${consumed}" ]]; echo $?)"
done

echo
echo "slot -> physical button, per set (iconA=EAST, iconB=SOUTH, iconX=NORTH, iconY=WEST):"

# The whole correctness argument, written out. Derived from the pinned ES
# source and confirmed by rendering probe glyphs into the help strip; see the
# header of _inc/buttons-nintendo.xml.
#
#   position   Nintendo   PSP         Xbox
#   EAST       A          circle      B
#   SOUTH      B          cross       A
#   NORTH      X          triangle    Y
#   WEST       Y          square      X
expect() { # expect <set-file> <slot> <expected-basename>
  local f="${REPO_ROOT}/_inc/buttons-$1.xml" slot="$2" want="$3" got
  got="$(grep -oE "<helpIcon${slot}>[^<]*</helpIcon${slot}>" "${f}" \
         | sed -E "s|<helpIcon${slot}>([^<]*)</helpIcon${slot}>|\1|")"
  check "$1: ${slot} (${4}) = ${want}" \
    "$([[ "${got}" == "./art/help/${want}.png" ]]; echo $?)"
}

expect nintendo A btn-a EAST
expect nintendo B btn-b SOUTH
expect nintendo X btn-x NORTH
expect nintendo Y btn-y WEST

expect psp A psp-circle EAST
expect psp B psp-cross SOUTH
expect psp X psp-triangle NORTH
expect psp Y psp-square WEST

expect xbox A btn-b EAST
expect xbox B btn-a SOUTH
expect xbox X btn-y NORTH
expect xbox Y btn-x WEST

# Called out separately because it is the specific mistake the issue text, and
# style guide §5.4, both made: Cross is the SOUTH button, so it belongs on
# iconB. On iconA it renders on the east button instead — no error, just wrong.
psp_a="$(grep -oE '<helpIconA>[^<]*</helpIconA>' "${REPO_ROOT}/_inc/buttons-psp.xml")"
check "psp: Cross is NOT on iconA (the documented trap)" \
  "$([[ "${psp_a}" != *"psp-cross"* ]]; echo $?)"

# Nintendo and Xbox must genuinely differ, or the subset is decorative.
for slot in A B X Y; do
  n="$(grep -oE "<helpIcon${slot}>[^<]*<" "${REPO_ROOT}/_inc/buttons-nintendo.xml")"
  x="$(grep -oE "<helpIcon${slot}>[^<]*<" "${REPO_ROOT}/_inc/buttons-xbox.xml")"
  check "nintendo and xbox disagree on icon${slot}" \
    "$([[ "${n}" != "${x}" ]]; echo $?)"
done

echo
echo "the subset wiring:"

check "theme.xml declares a buttonGlyphs subset" \
  "$(grep -q '<subset name="buttonGlyphs"' "${THEME}"; echo $?)"

# Load-bearing: these files set variables that common.xml's <helpsystem>
# substitutes, and ES resolves ${...} at element-parse time. Declared after the
# common.xml include, all four face slots would resolve to literals and every
# set would silently render ES's stock glyphs.
subset_line="$(grep -n '<subset name="buttonGlyphs"' "${THEME}" | cut -d: -f1)"
common_line="$(grep -n '<include>./_inc/common.xml</include>' "${THEME}" | cut -d: -f1)"
check "the subset is declared BEFORE the common.xml include (${subset_line} < ${common_line})" \
  "$([[ -n "${subset_line}" && -n "${common_line}" && "${subset_line}" -lt "${common_line}" ]]; echo $?)"

# ES falls back to a subset's first <include> when the setting is unset, so
# ordering IS the default. Nintendo, per the decision on #8: the Brick's
# buttons carry that layout.
first_include="$(awk '/<subset name="buttonGlyphs"/ { inblk = 1; next }
                      inblk && /<include name=/ { print; exit }' "${THEME}")"
check "Nintendo is the first include, i.e. the default" \
  "$([[ "${first_include}" == *'name="Nintendo"'* ]]; echo $?)"

# The device build does NOT fall back to a subset's first <include> when the
# setting has never been chosen, so include order alone does not make Nintendo
# the default there — it made a fresh install render stock glyphs everywhere.
# A plain include of the default file, before the subset, is what actually
# guarantees the variables resolve. See the comment in theme.xml.
default_line="$(grep -n '<include>./_inc/buttons-nintendo.xml</include>' "${THEME}" | cut -d: -f1)"
check "the default set is also included outright, not just first in the subset" \
  "$([[ -n "${default_line}" ]]; echo $?)"
check "that include lands BEFORE the subset (${default_line:-none} < ${subset_line})" \
  "$([[ -n "${default_line}" && "${default_line}" -lt "${subset_line}" ]]; echo $?)"
check "and before the common.xml include (${default_line:-none} < ${common_line})" \
  "$([[ -n "${default_line}" && "${default_line}" -lt "${common_line}" ]]; echo $?)"

check "all three sets are wired into the subset" \
  "$([[ "$(awk '/<subset name="buttonGlyphs"/ { inblk = 1; next }
                inblk && /<\/subset>/ { exit }
                inblk && /<include name=/ { n++ } END { print n+0 }' "${THEME}")" -eq 3 ]]; echo $?)"

# The b5e2063 regression, generalised: ANY parsed file that names a view makes
# hasView() true for it, and a theme-wide include naming "grid" hands an
# unstyled built-in grid to every user who pinned Gamelist View Style = grid.
# These files carry variables only, which is what keeps that from happening.
viewful=""
for f in "${SET_FILES[@]}"; do
  strip_comments "${f}" | grep -q '<view ' && viewful+=" ${f##*/}"
done
check "no buttons-*.xml declares a <view> (${viewful:-none do})" \
  "$([[ -z "${viewful}" ]]; echo $?)"

echo
echo "the art:"

check "art/help/ exists" "$([[ -d "${HELP_ART}" ]]; echo $?)"
check "the generator ships alongside it" \
  "$([[ -f "${REPO_ROOT}/scripts/gen-help-icons.py" ]]; echo $?)"

# Every glyph must have real pixels. A fully transparent PNG passes an
# exists-on-disk check and renders as nothing, which reads as "the icon is
# broken" rather than "the file is empty" — the same class of trap as the
# zero-byte fixture videos found in #40.
if command -v python3 >/dev/null 2>&1; then
  python3 - "${HELP_ART}" <<'PY'
import sys, pathlib
try:
    from PIL import Image
except ImportError:
    print("  skip - Pillow not installed, cannot check glyph contents")
    sys.exit(0)
bad = []
for p in sorted(pathlib.Path(sys.argv[1]).glob("*.png")):
    with Image.open(p) as im:
        if im.mode != "RGBA" or not any(
            c for v, c in zip(range(256), im.getchannel("A").histogram()) if v > 0
        ):
            bad.append(p.name)
print(f"  {'FAIL' if bad else 'ok  '} - every glyph is RGBA with opaque pixels"
      f" ({', '.join(bad) if bad else 'all 16 ok'})")
sys.exit(1 if bad else 0)
PY
  [[ $? -eq 0 ]] || fail=1
fi

echo
echo "the harness must be able to show the strip at all:"

# ShowHelpPrompts was hardcoded false, so no render before this change could
# have shown a single one of these glyphs.
check "run-in-container.sh takes SHOW_HELP" \
  "$(grep -q 'SHOW_HELP' "${REPO_ROOT}/docker/run-in-container.sh"; echo $?)"
check "run-in-container.sh takes BUTTON_GLYPHS" \
  "$(grep -q 'subset.buttonGlyphs' "${REPO_ROOT}/docker/run-in-container.sh"; echo $?)"
check "render.sh validates BUTTON_GLYPHS against the subset" \
  "$(grep -q 'check_pin BUTTON_GLYPHS' "${REPO_ROOT}/scripts/render.sh"; echo $?)"

# InvertButtons decides which POSITION confirms, so it changes which glyph the
# CONFIRM label sits next to. The device ships true; a harness left at ES's
# false default would have shown a different strip than the Brick.
check "run-in-container.sh pins InvertButtons" \
  "$(grep -q '<bool name="InvertButtons"' "${REPO_ROOT}/docker/run-in-container.sh"; echo $?)"
check "the harness defaults InvertButtons to the device's value (true)" \
  "$(grep -q 'INVERT_BUTTONS:=true' "${REPO_ROOT}/docker/run-in-container.sh"; echo $?)"
# BUTTON_OK follows InvertButtons, so the confirm KEY has to follow it too, or
# every gamelist render silently stops on the system carousel.
check "the confirm key follows InvertButtons rather than being hardcoded" \
  "$(grep -q 'CONFIRM_KEY' "${REPO_ROOT}/docker/run-in-container.sh"; echo $?)"

echo
echo "docs:"

check "README documents the Button Icons knob" \
  "$(grep -q 'Button Icons' "${REPO_ROOT}/README.md"; echo $?)"
check "the style guide no longer maps Cross to iconA" \
  "$(! grep -qE '<iconA>\./art/help/cross\.png' "${REPO_ROOT}/docs/psp-xmb-style-guidelines.md"; echo $?)"
check "the style guide records the slot->position mapping" \
  "$(grep -q 'iconA' "${REPO_ROOT}/docs/psp-xmb-style-guidelines.md" \
     && grep -qi 'EAST' "${REPO_ROOT}/docs/psp-xmb-style-guidelines.md"; echo $?)"
# Anchored on the S4 heading rather than a bare "S4" match: the audit mentions
# S4 in several unrelated dependency lists, and a loose grep found "SHIPPED"
# belonging to some other entry entirely.
s4_block="$(awk '/^#+ .*S4/ { inblk = 1; print; next }
                 inblk && /^#+ / { exit }
                 inblk { print }' "${REPO_ROOT}/docs/psp-authenticity-audit.md")"
check "the authenticity audit has an S4 section" \
  "$([[ -n "${s4_block}" ]]; echo $?)"
check "the authenticity audit marks S4 shipped" \
  "$(grep -qi 'shipped' <<<"${s4_block}"; echo $?)"

echo
if [[ "${fail}" -eq 0 ]]; then
  echo "all checks passed"
else
  echo "FAILURES — see above"
fi
exit "${fail}"
