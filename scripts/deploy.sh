#!/usr/bin/env bash
set -euo pipefail

# Which of these came from the ENVIRONMENT, recorded before any default is
# applied: `${VAR+y}` is set only if VAR was already defined, so an env value
# that happens to equal a default is still honoured, and a var that was never
# set still falls through to .env.local.
#
# The precedence matters. Sourcing .env.local unconditionally made the FILE win
# over the environment, the opposite of what the usage text promises, so
# `DEVICE_IP=192.168.0.52 ./scripts/ui.sh a` silently drove the .env.local
# device instead. When that host is off it reads as the tool hanging or the
# keypress being ignored, not as talking to the wrong machine.
_had_ip="${DEVICE_IP+y}"; _had_user="${DEVICE_USER+y}"; _had_theme="${THEME_NAME+y}"
_env_ip="${DEVICE_IP:-}"; _env_user="${DEVICE_USER:-}"; _env_theme="${THEME_NAME:-}"

if [[ -f .env.local ]]; then
  set -a
  # shellcheck disable=SC1091
  source .env.local
  set +a
fi

[[ -n "${_had_ip}" ]]    && DEVICE_IP="${_env_ip}"
[[ -n "${_had_user}" ]]  && DEVICE_USER="${_env_user}"
[[ -n "${_had_theme}" ]] && THEME_NAME="${_env_theme}"
unset _had_ip _had_user _had_theme _env_ip _env_user _env_theme

# Defaults last, for anything neither the environment nor .env.local supplied.
DEVICE_IP="${DEVICE_IP:-192.168.1.4}"
DEVICE_USER="${DEVICE_USER:-root}"
THEME_NAME="${THEME_NAME:-es-theme-xmb-psp}"

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
  push       sync, pause, then screenshot - review .dev/last-shot.png and
             reload manually with 'ui.sh reload-theme' once ES is confirmed
             on the system carousel
  logs       tail ES log on device
  shot       capture a screenshot, pull to .dev/last-shot.png
  shell      interactive SSH session
  fallback   force device back to built-in 'carbon' theme (use when ES is
             stuck in a restart loop and input injection wouldn't reach it)

Config (environment overrides .env.local at repo root):
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
  push)
    "$0" sync
    # A reload fired too soon after sync, or while ES is on an unexpected
    # screen, has been linked to ES crash loops. Pause for the sync to
    # settle, then screenshot so the operator can confirm ES is on the
    # system carousel BEFORE running the reload-theme input macro.
    echo "Sync done; pausing 5s before screenshot..."
    sleep 5
    "$0" shot
    echo
    echo "Review .dev/last-shot.png before reloading:"
    echo "  ES should be on the SYSTEM CAROUSEL (not a menu or gamelist)."
    echo "  If it is:   ./scripts/ui.sh reload-theme"
    echo "  If not:     navigate ES back to the carousel, then reload."
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
