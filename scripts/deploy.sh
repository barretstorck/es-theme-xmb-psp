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

# Knulli runs dropbear over an exFAT /userdata partition. Permissions can't be
# tightened on fuseblk mounts, so dropbear rejects public-key auth. If SSHPASS
# is set, route ssh/scp/rsync through sshpass for password auth.
if [[ -n "${SSHPASS:-}" ]]; then
  if ! command -v sshpass >/dev/null 2>&1; then
    echo "SSHPASS is set but 'sshpass' is not installed." >&2
    echo "Install with: brew install hudochenkov/sshpass/sshpass" >&2
    exit 1
  fi
  export SSHPASS
  SSH="sshpass -e ssh -o PreferredAuthentications=password -o PubkeyAuthentication=no"
  SCP="sshpass -e scp -o PreferredAuthentications=password -o PubkeyAuthentication=no"
  export RSYNC_RSH="sshpass -e ssh -o PreferredAuthentications=password -o PubkeyAuthentication=no -o StrictHostKeyChecking=accept-new"
else
  SSH="ssh"
  SCP="scp"
fi

usage() {
  cat <<EOF
Usage: $(basename "$0") <subcommand>

Subcommands:
  sync       rsync theme files to device
  restart    restart EmulationStation on device
  push       sync + restart  (deploy a change end-to-end)
  activate   atomically set BOTH theme.set (knulli.conf) and
             ThemeSet (es_settings.cfg) to this theme, then restart ES.
             A mismatch between the two causes an ES restart loop.
  logs       tail ES log on device
  shot       capture a screenshot, pull to .dev/last-shot.png
  shell      interactive SSH session
  fallback   force device back to built-in 'carbon' theme

Config (env or .env.local at repo root):
  DEVICE_IP    (current: $DEVICE_IP)
  DEVICE_USER  (current: $DEVICE_USER)
  THEME_NAME   (current: $THEME_NAME)
  SSHPASS      (set in .env.local to use password auth via sshpass)
EOF
}

cmd="${1:-}"
case "$cmd" in
  sync)
    # fuseblk doesn't support chown/chmod; --no-perms/owner/group avoids errors.
    rsync -rltvz --delete --no-perms --no-owner --no-group \
      --exclude='.git' \
      --exclude='.claude' \
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
    $SSH "${DEVICE}" '(command -v knulli-es-swissknife >/dev/null && knulli-es-swissknife --restart) || batocera-es-swissknife --restart'
    ;;
  push)
    "$0" sync
    "$0" restart
    ;;
  activate)
    # On Knulli, the theme name lives in TWO places: knulli.conf's theme.set
    # (used by the system) and es_settings.cfg's ThemeSet (used by ES). If
    # they diverge, the emulationstation-standalone wrapper restarts ES in a
    # tight loop trying to reconcile them. Set both, then restart.
    $SSH "${DEVICE}" "
      if command -v knulli-settings-set >/dev/null 2>&1; then
        knulli-settings-set theme.set ${THEME_NAME}
      else
        batocera-settings-set theme.set ${THEME_NAME}
      fi
      sed -i 's|<string name=\"ThemeSet\" value=\"[^\"]*\"|<string name=\"ThemeSet\" value=\"${THEME_NAME}\"|' /userdata/system/configs/emulationstation/es_settings.cfg
      (command -v knulli-es-swissknife >/dev/null && knulli-es-swissknife --restart) || batocera-es-swissknife --restart
    "
    ;;
  logs)
    # Knulli stores ES log under configs/, not system/logs/.
    $SSH "${DEVICE}" 'tail -f /userdata/system/configs/emulationstation/es_log.txt 2>/dev/null || tail -f /userdata/system/logs/es_log.txt'
    ;;
  shot)
    mkdir -p .dev
    # Knulli ships knulli-screenshot; Batocera ships batocera-screenshot;
    # fbgrab is the universal fallback. Prefer whichever exists.
    $SSH "${DEVICE}" '
      if command -v knulli-screenshot >/dev/null 2>&1; then
        knulli-screenshot
      elif command -v batocera-screenshot >/dev/null 2>&1; then
        batocera-screenshot
      else
        fbgrab "/userdata/screenshots/manual-$(date +%s).png"
      fi
    '
    sleep 1
    latest=$($SSH "${DEVICE}" 'ls -t /userdata/screenshots/ 2>/dev/null | grep -iE "\.(png|jpg)$" | head -1')
    if [[ -z "$latest" ]]; then
      echo "No screenshots found on device" >&2
      exit 1
    fi
    $SCP "${DEVICE}:/userdata/screenshots/${latest}" .dev/last-shot.png
    echo "Saved .dev/last-shot.png (was ${latest} on device)"
    ;;
  shell)
    $SSH "${DEVICE}"
    ;;
  fallback)
    # Atomic sync of theme.set and ThemeSet to the default 'carbon' theme.
    $SSH "${DEVICE}" "
      if command -v knulli-settings-set >/dev/null 2>&1; then
        knulli-settings-set theme.set carbon
      else
        batocera-settings-set theme.set carbon
      fi
      sed -i 's|<string name=\"ThemeSet\" value=\"[^\"]*\"|<string name=\"ThemeSet\" value=\"carbon\"|' /userdata/system/configs/emulationstation/es_settings.cfg
      (command -v knulli-es-swissknife >/dev/null && knulli-es-swissknife --restart) || batocera-es-swissknife --restart
    "
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
