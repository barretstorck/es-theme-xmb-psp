#!/usr/bin/env bash
set -euo pipefail

# Defaults (override via env or .env.local at repo root)
DEVICE_IP="${DEVICE_IP:-192.168.1.4}"
DEVICE_USER="${DEVICE_USER:-root}"
THEME_NAME="${THEME_NAME:-es-theme-xmb-psp}"

if [[ -f .env.local ]]; then
  set -a
  # shellcheck disable=SC1091
  source .env.local
  set +a
fi

DEVICE="${DEVICE_USER}@${DEVICE_IP}"
THEME_PATH="/userdata/themes/${THEME_NAME}/"

usage() {
  cat <<EOF
Usage: $(basename "$0") <subcommand>

Subcommands:
  sync       rsync theme files to device
  restart    restart EmulationStation on device
  push       sync + restart  (deploy a change end-to-end)
  logs       tail ES log on device
  shot       capture a screenshot, pull to .dev/last-shot.png
  shell      interactive SSH session
  setup      one-time: ssh-copy-id for passwordless access
  fallback   force device back to built-in 'carbon' theme

Config (env or .env.local at repo root):
  DEVICE_IP    (current: $DEVICE_IP)
  DEVICE_USER  (current: $DEVICE_USER)
  THEME_NAME   (current: $THEME_NAME)
EOF
}

cmd="${1:-}"
case "$cmd" in
  sync)
    rsync -avz --delete \
      --exclude='.git' \
      --exclude='docs' \
      --exclude='scripts' \
      --exclude='.dev' \
      --exclude='.env.local' \
      --exclude='.env.local.example' \
      --exclude='.gitignore' \
      --exclude='README.md' \
      --exclude='CREDITS.md' \
      --exclude='LICENSE' \
      ./ "${DEVICE}:${THEME_PATH}"
    ;;
  restart)
    ssh "${DEVICE}" 'batocera-es-swissknife --restart'
    ;;
  push)
    "$0" sync
    "$0" restart
    ;;
  logs)
    ssh "${DEVICE}" 'tail -f /userdata/system/logs/es_log.txt'
    ;;
  shot)
    mkdir -p .dev
    ssh "${DEVICE}" 'batocera-screenshot'
    sleep 1
    latest=$(ssh "${DEVICE}" 'ls -t /userdata/screenshots/ 2>/dev/null | head -1')
    if [[ -z "$latest" ]]; then
      echo "No screenshots found on device" >&2
      exit 1
    fi
    scp "${DEVICE}:/userdata/screenshots/${latest}" .dev/last-shot.png
    echo "Saved .dev/last-shot.png (was ${latest} on device)"
    ;;
  shell)
    ssh "${DEVICE}"
    ;;
  setup)
    ssh-copy-id "${DEVICE}"
    ;;
  fallback)
    ssh "${DEVICE}" 'batocera-settings-set theme.set carbon && batocera-es-swissknife --restart'
    ;;
  -h|--help|"")
    usage
    ;;
  *)
    echo "Unknown subcommand: $cmd" >&2
    usage
    exit 1
    ;;
esac
