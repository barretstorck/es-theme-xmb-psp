#!/usr/bin/env bash
# Smoke test for import-ra-icons.sh
# Builds a tiny isolated RA tree + TSV, runs the script, verifies behaviour.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
IMPORT="${REPO_ROOT}/scripts/import-ra-icons.sh"

# Set up a sandbox that mimics the layout the script expects.
SANDBOX="$(mktemp -d)"
trap 'rm -rf "${SANDBOX}"' EXIT

mkdir -p "${SANDBOX}/ra/xmb/automatic/png"
mkdir -p "${SANDBOX}/out"

# Fake RA sources — three real files, one row will MISS.
printf 'present-1' > "${SANDBOX}/ra/xmb/automatic/png/Foo - One.png"
printf 'present-2' > "${SANDBOX}/ra/xmb/automatic/png/Foo - Two.png"
printf 'present-3' > "${SANDBOX}/ra/xmb/automatic/png/database.png"

# Test TSV: tab-separated; comments and blank lines skipped.
cat > "${SANDBOX}/mapping.tsv" <<TSV
# header comment, must be ignored
foo1	Foo - One
foo2	Foo - Two
auto-allgames	database

# the next row should MISS — no such RA source
ghost	Nonexistent Source
TSV

# Run the script with overrides for sandbox paths.
output="$(RA_DIR="${SANDBOX}/ra/xmb/automatic/png" \
          OUT_DIR="${SANDBOX}/out" \
          MAPPING_TSV="${SANDBOX}/mapping.tsv" \
          bash "${IMPORT}" 2>&1)"

# Assertions.
fail=0
check() { local desc="$1" cond="$2"; if eval "${cond}"; then echo "PASS: ${desc}"; else echo "FAIL: ${desc}"; fail=1; fi; }

check "foo1.png created"              '[[ -f "${SANDBOX}/out/foo1.png" ]]'
check "foo2.png created"              '[[ -f "${SANDBOX}/out/foo2.png" ]]'
check "auto-allgames.png created"     '[[ -f "${SANDBOX}/out/auto-allgames.png" ]]'
check "ghost.png NOT created"         '[[ ! -f "${SANDBOX}/out/ghost.png" ]]'
check "MISS line surfaces ghost"      'echo "${output}" | grep -q "MISS:.*ghost"'
check "foo1 content copied verbatim"  '[[ "$(cat ${SANDBOX}/out/foo1.png)" == "present-1" ]]'

# Re-run: must remain idempotent (no errors, files still present).
output2="$(RA_DIR="${SANDBOX}/ra/xmb/automatic/png" \
           OUT_DIR="${SANDBOX}/out" \
           MAPPING_TSV="${SANDBOX}/mapping.tsv" \
           bash "${IMPORT}" 2>&1)"
check "second run still creates foo1" '[[ -f "${SANDBOX}/out/foo1.png" ]]'
check "second run still misses ghost" 'echo "${output2}" | grep -q "MISS:.*ghost"'

# Preflight failure: missing RA dir must exit non-zero with clear message.
set +e
preflight_output="$(RA_DIR="${SANDBOX}/nonexistent" \
                   OUT_DIR="${SANDBOX}/out" \
                   MAPPING_TSV="${SANDBOX}/mapping.tsv" \
                   bash "${IMPORT}" 2>&1)"
preflight_rc=$?
set -e
check "preflight exits non-zero on missing RA dir"  '[[ ${preflight_rc} -ne 0 ]]'
check "preflight error mentions RA_DIR"             'echo "${preflight_output}" | grep -qi "ra_dir\|retroarch"'

if [[ ${fail} -ne 0 ]]; then
  echo "TEST FAILED" >&2
  exit 1
fi
echo "ALL TESTS PASSED"
