#!/usr/bin/env bash
# Guards for the README's committed showcase assets (issue #45).
#
# The README is the product for a theme repo, and its failure mode is silent:
# a renamed screenshot renders as a broken image on the repo's front page and
# no build step notices. These guards make that a test failure instead.
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
# expands arguments left to right — so each guard stores its exit status in
# `rc` on its own line and passes that.

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
# Every case asserts on the MESSAGE as well as the exit status. Exit-status-only
# guards passed here for the wrong reason during development: record.sh also
# exits 2 when a script enters a gamelist with no --library, so five of six
# "rejects X" checks were green while the validation they named did nothing.
# `--script right:1` keeps that unrelated guard from firing first.
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
out="$(timeout 30 "${REC}" --library /tmp/library --colorset Nonesuch 2>&1)"
grep -qi "colorset" <<<"${out}"
check "the DEFAULT --script passes vocabulary validation" $?

# The no-library guard is itself worth pinning: a script that enters a gamelist
# with no library records an empty list, which reads as a theme bug.
out="$(timeout 30 "${REC}" --script "confirm:1" --out /tmp/nope.gif 2>&1)"; rc=$?
[[ "${rc}" -eq 2 ]] && grep -qi "library" <<<"${out}"
check "rejects a gamelist script with no --library (got ${rc})" $?

echo
if [[ "${fail}" -eq 0 ]]; then echo "ALL CHECKS PASSED"; else echo "SOME CHECKS FAILED"; fi
exit "${fail}"
