#!/usr/bin/env bash
# The assertion helper every structural test suite shares, plus REPO_ROOT.
#
# Twelve suites each carried a byte-identical copy of `check`, `fail=0` and the
# two-line REPO_ROOT derivation. That is not just duplication — it meant the
# assertion primitive itself could never be FIXED, because a fix had to land in
# twelve places at once, and the copies had already drifted into two spellings.
#
#   check      assert, from an exit status captured by the caller
#   REPO_ROOT  the repo root, derived from this file's own location
#   fail       0 until some check fails; suites exit on it
#
# WHY check VALIDATES ITS SECOND ARGUMENT
#
# The old copy was `[[ "$2" -eq 0 ]]`, and bash's arithmetic context makes that
# TRUE for the empty string. So `check "some assertion" ""` printed `ok` and the
# suite passed while asserting nothing at all. That is not a hypothetical: it is
# exactly what
#
#     check "the thing holds $(some_command)" $?
#
# produces, because bash expands arguments left to right, so `$?` is the status
# of the SUBSTITUTION — which succeeded — and not of the guard the author meant.
# Two guards shipped passing vacuously this way and were only caught by mutation
# testing. The correct idiom is to capture the status on its own line:
#
#     some_command
#     rc=$?
#     check "the thing holds" "${rc}"
#
# A non-numeric second argument is a different failure with a worse symptom:
# `[[ abc -eq 0 ]]` makes bash resolve `abc` as a VARIABLE NAME, so under
# `set -u` the suite aborts with "abc: unbound variable" citing this file rather
# than the caller's guard. Both cases are now loud, attributed failures.
#
# NOT ADOPTED BY test-import-ra-icons.sh. That suite is a behavioural smoke test
# with a deliberately different contract — `check <desc> <condition-string>`,
# eval'd, printing PASS:/FAIL: — and folding it in here would change what its
# assertions mean for no benefit. It keeps its own local helper on purpose.

# Both REPO_ROOT and fail are consumed by the suite that sources this file.
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

fail=0

check() { # check <description> <condition-exit-code>
  local desc="${1-}" rc="${2-}"

  if [[ ! "${rc}" =~ ^[0-9]+$ ]]; then
    echo "  FAIL - ${desc}"
    echo "         ^ malformed assertion: exit status was '${rc}', not a number." >&2
    echo "           Capture it on its own line:  cmd; rc=\$?; check \"...\" \"\${rc}\"" >&2
    fail=1
    return 0
  fi

  if [[ "${rc}" -eq 0 ]]; then
    echo "  ok   - ${desc}"
  else
    echo "  FAIL - ${desc}"
    fail=1
  fi
}
