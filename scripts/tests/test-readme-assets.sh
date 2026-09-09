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
if [[ "${fail}" -eq 0 ]]; then echo "ALL CHECKS PASSED"; else echo "SOME CHECKS FAILED"; fi
exit "${fail}"
