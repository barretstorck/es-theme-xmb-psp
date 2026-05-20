#!/usr/bin/env bash
# populate-fallback-icons.sh — for every system shortname in
# scripts/knulli-systems.txt that lacks a dedicated icon, copy
# art/system-icons/_default.png to art/system-icons/<shortname>.png.
# Idempotent: re-running skips systems that already have an icon.
set -euo pipefail

ICON_DIR="art/system-icons"
DEFAULT_ICON="${ICON_DIR}/_default.png"
SYSTEM_LIST="scripts/knulli-systems.txt"

if [[ ! -f "$DEFAULT_ICON" ]]; then
  echo "Missing $DEFAULT_ICON — nothing to copy from." >&2
  exit 1
fi
if [[ ! -f "$SYSTEM_LIST" ]]; then
  echo "Missing $SYSTEM_LIST — generate it first (see Task 4)." >&2
  exit 1
fi

existing=0
created=0
while IFS= read -r system; do
  [[ -z "$system" ]] && continue
  target="${ICON_DIR}/${system}.png"
  if [[ -f "$target" ]]; then
    existing=$((existing + 1))
  else
    cp "$DEFAULT_ICON" "$target"
    created=$((created + 1))
    echo "  + ${system}.png"
  fi
done < "$SYSTEM_LIST"

echo
echo "Summary: ${existing} systems already covered, ${created} new fallback files created."
