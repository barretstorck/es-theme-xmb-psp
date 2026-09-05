#!/usr/bin/env bash
# Structural smoke test for the v0.12 gamelist styles.
# Asserts wiring invariants that a render cannot catch cheaply:
# harness plumbing, style-file structure, subset wiring, include order.
# NOTE: deliberately NOT `set -e`. Every assertion is `<cmd>; check "..." $?`,
# and under `set -e` a failing <cmd> aborts the script before check() runs —
# so only the first failure is ever reported and `fail` accumulation is dead
# code. Without -e, all checks run and `exit "${fail}"` still gates the run.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
fail=0
check() { # check <description> <condition-exit-code>
  if [[ "$2" -eq 0 ]]; then echo "  ok   - $1"; else echo "  FAIL - $1"; fail=1; fi
}

echo "harness plumbing:"

grep -q 'GAMELIST_STYLE' "${REPO_ROOT}/scripts/render.sh"
check "render.sh passes GAMELIST_STYLE through" $?

grep -q 'subset.gamelistStyle' "${REPO_ROOT}/docker/run-in-container.sh"
check "run-in-container.sh writes subset.gamelistStyle" $?

# The theme's defaultView only wins when ES's own preference is automatic or
# names a view the active style does not define (ViewController.cpp:697-720).
# Pinning "detailed" would mask that mechanism for the card style.
grep -qE 'gamelist\)[[:space:]]*GLVIEW="automatic"' "${REPO_ROOT}/docker/run-in-container.sh"
check "gamelist view uses GamelistViewStyle=automatic" $?

exit "${fail}"
