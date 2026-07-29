#!/usr/bin/env bash
# import-ra-icons.sh — copy RetroArch `monochrome` XMB icons into
# art/system-icons/ per the row mappings in scripts/ra-mapping.tsv.
#
# Env overrides (used by smoke test):
#   RA_DIR       source dir; default ${HOME}/retroarch-assets/xmb/monochrome/png
#   OUT_DIR      destination dir; default art/system-icons (repo-relative)
#   MAPPING_TSV  mapping file; default scripts/ra-mapping.tsv (repo-relative)
#
# Idempotent. A `MISS:` line on stderr per row whose RA source doesn't exist.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

RA_DIR="${RA_DIR:-${HOME}/retroarch-assets/xmb/monochrome/png}"
OUT_DIR="${OUT_DIR:-${REPO_ROOT}/art/system-icons}"
MAPPING_TSV="${MAPPING_TSV:-${REPO_ROOT}/scripts/ra-mapping.tsv}"

# Preflight.
if [[ ! -d "${RA_DIR}" ]]; then
  echo "ERROR: RA_DIR not found: ${RA_DIR}" >&2
  echo "  Clone the RetroArch assets first:" >&2
  echo "  git clone --depth=1 https://github.com/libretro/retroarch-assets.git ~/retroarch-assets" >&2
  exit 1
fi
if [[ ! -f "${MAPPING_TSV}" ]]; then
  echo "ERROR: MAPPING_TSV not found: ${MAPPING_TSV}" >&2
  exit 1
fi
mkdir -p "${OUT_DIR}"

copied=0
missed=0
while IFS=$'\t' read -r short ra || [[ -n "${short:-}" ]]; do
  [[ -z "${short}" || "${short}" == \#* ]] && continue
  src="${RA_DIR}/${ra}.png"
  dst="${OUT_DIR}/${short}.png"
  if [[ -f "${src}" ]]; then
    cp "${src}" "${dst}"
    copied=$((copied + 1))
  else
    echo "MISS: ${short} -> ${ra}" >&2
    missed=$((missed + 1))
  fi
done < "${MAPPING_TSV}"

echo "import-ra-icons: copied=${copied} missed=${missed}"
