#!/usr/bin/env bash
# Guards for the README's committed showcase assets (issue #45).
#
# The README is the product for a theme repo, and its failure mode is silent:
# a renamed screenshot renders as a broken image on the repo's front page and
# no build step notices. These guards make that a test failure instead.
#
# NOTE: deliberately NOT `set -e` — see the note in test-gamelist-styles.sh.
set -uo pipefail

# shellcheck source=scripts/lib/test-lib.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../lib" && pwd)/test-lib.sh"

# `check "$(cmd)" $?` would report the SUBSTITUTION's status, because bash
# expands arguments left to right. Guards whose MESSAGE contains a command
# substitution therefore store the status in `rc` on its own line first. Guards
# whose message is only parameter expansion pass `$?` directly, which is safe —
# no command runs between the test and the read.

echo "shared subset helper:"

source "${REPO_ROOT}/scripts/lib/theme-subsets.sh"
names="$(subset_values colorset)"; rc=$?
check "subset_values colorset exits 0" "${rc}"

count="$(printf '%s\n' "${names}" | grep -c .)"
[[ "${count}" -eq 12 ]]
check "theme.xml declares exactly 12 colorsets (got ${count})" $?

grep -Fxq "January Blue" <<<"${names}"
check "the list contains January Blue" $?

grep -Fxq "December Aqua" <<<"${names}"
check "the list contains December Aqua" $?

# Without this, the "unknown subset yields nothing" check below passes
# vacuously whenever the helper is missing entirely — a missing function also
# produces no output.
declare -F subset_values >/dev/null
check "subset_values is defined by the helper" $?

# A subset that does not exist must come back empty rather than printing the
# whole file — otherwise a typo'd subset name silently yields a plausible list.
missing="$(subset_values noSuchSubset)"
[[ -z "${missing}" ]]
check "an unknown subset name yields nothing" $?

echo
echo "record.sh argument validation:"

REC="${REPO_ROOT}/scripts/record.sh"

[[ -x "${REC}" ]]
check "record.sh exists and is executable" $?

# Each of these must be rejected BEFORE docker is invoked, so they must fail
# fast. A 30s timeout means a failure to reject shows up as a timeout rather
# than hanging the suite on an image build.
#
# Every case asserts on the MESSAGE as well as the exit status, because an
# exit-status-only guard passed here for the wrong reason: record.sh also exits
# 2 when a script enters a gamelist with no --library, and the DEFAULT script
# contains `confirm`. "--fps 08" was green while the fps check did nothing —
# back then check_int accepted 08 as 8, so the run fell through to the library
# guard. Rejecting leading zeros fixed that case, and the other five do now
# fail at their own named check even with no --script; the message assertions
# are what keep all six honest, and `--script right:1` is belt-and-braces so
# the library guard can never mask a future one.
#
# "--fps 08" is the octal case: `(( 08 ))` is a parse error, not eight, and
# `10#08` would silently accept it as eight. It must be rejected by name.
while IFS='|' read -r bad want; do
  [[ -z "${bad}" ]] && continue
  out="$(timeout 30 "${REC}" ${bad} --script "right:1" --out /tmp/nope.gif 2>&1)"; rc=$?
  [[ "${rc}" -eq 2 ]] && grep -qi -- "${want}" <<<"${out}"
  check "rejects '${bad}' with exit 2 naming '${want}' (got ${rc})" $?
done <<'CASES'
--fps 0|fps
--fps 08|fps
--colors 999|colors
--width 4|width
--colorset Nonesuch|colorset
--resolution 1280|resolution
CASES

# A key name outside the vocabulary must be an error, not a silent no-op.
# This is the regression guard for the feature's first take, which recorded a
# clean GIF in which nothing moved because xdotool keysyms are case-sensitive
# ("Right", not "right") and key() swallows an unknown symbol.
out="$(timeout 30 "${REC}" --script "rihgt:1" --out /tmp/nope.gif 2>&1)"; rc=$?
[[ "${rc}" -eq 2 ]] && grep -qi "unknown key" <<<"${out}"
check "rejects an unknown key name in --script (got ${rc})" $?

out="$(timeout 30 "${REC}" --script "right:soon" --out /tmp/nope.gif 2>&1)"; rc=$?
[[ "${rc}" -eq 2 ]] && grep -qi "seconds" <<<"${out}"
check "rejects a non-numeric wait in --script (got ${rc})" $?

# The default script must itself be spelled in the vocabulary — a default that
# silently no-ops is the same bug shipped one level further back.
#
# Getting this guard right is fiddly, and the first attempt was VACUOUS: it
# passed `--colorset Nonesuch`, which record.sh rejects BEFORE it ever reaches
# the script-vocabulary loop, and then asserted only that the word "colorset"
# appeared in the output. Breaking the default script to "rihgt:1.4" left the
# check green.
#
# This version relies on record.sh's validation ORDER instead. The vocabulary
# loop runs BEFORE the library/confirm cross-check, so invoking with the real
# default script and no --library must fail at the LIBRARY check. If the
# default script contained a bad key it would fail earlier, with a different
# message — so asserting on which message appears actually exercises the
# default.
out="$(timeout 30 "${REC}" --out /tmp/nope.gif 2>&1)"; rc=$?
[[ "${rc}" -eq 2 ]] && grep -qi "library" <<<"${out}" && ! grep -qi "unknown key" <<<"${out}"
check "the DEFAULT --script passes vocabulary validation (got ${rc})" $?

# The no-library guard is itself worth pinning: a script that enters a gamelist
# with no library records an empty list, which reads as a theme bug.
out="$(timeout 30 "${REC}" --script "confirm:1" --out /tmp/nope.gif 2>&1)"; rc=$?
[[ "${rc}" -eq 2 ]] && grep -qi "library" <<<"${out}"
check "rejects a gamelist script with no --library (got ${rc})" $?

echo
echo "README asset integrity:"

# The guard that matters most: a renamed or deleted screenshot renders as a
# broken image on the repo's front page and nothing else in this repo notices.
python3 - "${REPO_ROOT}" <<'PYEOF'
import os, re, sys
root = sys.argv[1]
text = open(os.path.join(root, "README.md"), encoding="utf-8").read()
refs = re.findall(r'!\[[^\]]*\]\(([^)]+)\)', text)
if len(refs) < 20:
    print(f"only found {len(refs)} image refs — the regex is wrong, or the "
          "README lost its galleries; the rest of this check would pass "
          "vacuously")
    sys.exit(1)
missing = [r for r in refs
           if not r.startswith(("http://", "https://"))
           and not os.path.exists(os.path.join(root, r))]
for m in missing:
    print(f"README references a missing image: {m}")
sys.exit(1 if missing else 0)
PYEOF
rc=$?
check "every image README.md references exists in-tree" "${rc}"

# The gallery and the theme must not drift apart in either direction.
python3 - "${REPO_ROOT}" <<'PYEOF'
import os, re, sys
root = sys.argv[1]
theme = open(os.path.join(root, "theme.xml"), encoding="utf-8").read()
block = re.search(r'<subset name="colorset".*?</subset>', theme, re.S)
if not block:
    print("theme.xml has no colorset subset — guard cannot run")
    sys.exit(1)
names = re.findall(r'<include name="([^"]+)"', block.group(0))
if len(names) < 2:
    print(f"parsed only {len(names)} colorsets from theme.xml — guard is wrong")
    sys.exit(1)
readme = open(os.path.join(root, "README.md"), encoding="utf-8").read()
missing = [n for n in names if n not in readme]
for n in missing:
    print(f"colorset missing from the README gallery: {n}")
sys.exit(1 if missing else 0)
PYEOF
rc=$?
check "the gallery names every colorset theme.xml declares" "${rc}"

# Each gallery name also needs its thumbnail on disk. The check above only
# proves the NAME appears somewhere in the README.
python3 - "${REPO_ROOT}" <<'PYEOF'
import os, re, sys
root = sys.argv[1]
theme = open(os.path.join(root, "theme.xml"), encoding="utf-8").read()
block = re.search(r'<subset name="colorset".*?</subset>', theme, re.S)
names = re.findall(r'<include name="([^"]+)"', block.group(0))
def slug(n):
    return re.sub(r'-+', '-', re.sub(r'[^a-z0-9]', '-', n.lower())).strip('-')
missing = [n for n in names
           if not os.path.exists(
               os.path.join(root, "docs/screenshots/colorsets", slug(n) + ".png"))]
for n in missing:
    print(f"no thumbnail for colorset: {n} (expected {slug(n)}.png)")
sys.exit(1 if missing else 0)
PYEOF
rc=$?
check "every colorset has a thumbnail on disk" "${rc}"

gif="${REPO_ROOT}/docs/screenshots/xmb-navigation.gif"
[[ -f "${gif}" ]] && file -b "${gif}" | grep -q "GIF image data"
check "the navigation GIF exists and is a GIF" $?

gifkb=$(( $(stat -c%s "${gif}" 2>/dev/null || echo 99999999) / 1024 ))
[[ "${gifkb}" -le 3072 ]]
check "the GIF is within the 3MB budget (${gifkb}KB)" $?

# APPARENT bytes via stat, not `du`. du reports allocated blocks, and on this
# filesystem it reported 818KB for a directory whose files summed to 1.5MB —
# a size guard that reads stale allocation is a size guard that does not fire.
# Found by mutation-testing the style budget below, which stayed green after
# the file it guards was inflated to 1.15MB.
sum_bytes() { # sum_bytes <file>...
  local t=0 f
  for f in "$@"; do [[ -f "${f}" ]] && t=$(( t + $(stat -c%s "${f}") )); done
  echo $(( t / 1024 ))
}

thumbkb="$(sum_bytes "${REPO_ROOT}"/docs/screenshots/colorsets/*.png)"
[[ -n "${thumbkb}" && "${thumbkb}" -le 600 ]]
check "the colorset thumbnails are within the 600KB budget (${thumbkb:-?}KB)" $?

# The two guards above cover 2.8MB of the 4.15MB this work added; the style
# shots and aspect rows had none. That is the wrong half to guard: the style
# shots are the ones that were downscaled to fit, and nothing stopped a
# regeneration from restoring Box Art Grid to the 805KB it started at. A
# directory-wide ceiling catches whichever file grows.
totalkb="$(sum_bytes "${REPO_ROOT}"/docs/screenshots/*.png \
                     "${REPO_ROOT}"/docs/screenshots/*.gif \
                     "${REPO_ROOT}"/docs/screenshots/*/*.png)"
[[ -n "${totalkb}" && "${totalkb}" -le 18432 ]]
check "docs/screenshots stays within its 18MB ceiling (${totalkb:-?}KB)" $?

stylekb="$(sum_bytes "${REPO_ROOT}"/docs/screenshots/style-*.png)"
[[ -n "${stylekb}" && "${stylekb}" -le 1024 ]]
check "the style comparison shots stay within 1MB (${stylekb:-?}KB)" $?

# The README told readers its gamelist shots were stale. Those shots have been
# regenerated, so that paragraph is now false — and a false disclaimer is worse
# than none, because it tells readers to distrust accurate screenshots.
! grep -q "predate the v0.12" "${REPO_ROOT}/README.md"
check "the stale-screenshot disclaimer is gone" $?

echo
if [[ "${fail}" -eq 0 ]]; then echo "ALL CHECKS PASSED"; else echo "SOME CHECKS FAILED"; fi
exit "${fail}"
