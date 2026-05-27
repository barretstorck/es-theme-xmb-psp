#!/usr/bin/env bash
# render-fixtures.sh — convenience wrapper that calls scripts/render.sh
# with --library pointed at tests/fixtures/library/. Pass through any
# other render.sh arguments unchanged.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
FIXTURE="${REPO_ROOT}/tests/fixtures/library"

if [[ ! -d "${FIXTURE}" ]]; then
  echo "fixture library missing: ${FIXTURE}" >&2; exit 2
fi

exec "${SCRIPT_DIR}/render.sh" --library "${FIXTURE}" "$@"
