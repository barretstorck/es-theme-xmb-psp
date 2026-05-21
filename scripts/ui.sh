#!/usr/bin/env bash
set -euo pipefail

# Sends controller input to the device by writing evdev events directly into
# the real controller's input node. ES reads from that node, so injected
# events are indistinguishable from physical button presses.
#
# Usage:
#   ./scripts/ui.sh <macro>
#   ./scripts/ui.sh <token> [<token> ...]
#
# Raw tokens:
#   a b x y                          face buttons
#   l r l2 r2                        shoulders / triggers
#   start select hotkey              labelled buttons
#   up down left right               d-pad
#   sleep:NNN                        pause NNN milliseconds between inputs
#
# Macros (expanded to a token sequence):
#   reload-theme   Main Menu → UI Settings → Theme Configuration → Reset
#                  Customizations. Resetting forces ES to rebuild the theme,
#                  which is the cheapest way to pick up edited theme files
#                  without restarting emulationstation.
#
# Implementation notes:
#   We open /dev/input/<controller> on the device and write input_event structs.
#   The kernel input subsystem distributes those events to all readers of the
#   same node, so emulationstation sees them on the same stream as physical
#   presses. The button codes below match what ES has configured for this
#   controller in /userdata/system/configs/emulationstation/es_input.cfg.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

DEVICE_IP="${DEVICE_IP:-192.168.1.4}"
DEVICE_USER="${DEVICE_USER:-root}"
if [[ -f "${REPO_ROOT}/.env.local" ]]; then
  set -a
  # shellcheck disable=SC1091
  source "${REPO_ROOT}/.env.local"
  set +a
fi
DEVICE="${DEVICE_USER}@${DEVICE_IP}"

if [[ -n "${SSHPASS:-}" ]]; then
  if ! command -v sshpass >/dev/null 2>&1; then
    echo "SSHPASS is set but 'sshpass' is not installed." >&2
    echo "Install with: brew install hudochenkov/sshpass/sshpass" >&2
    exit 1
  fi
  export SSHPASS
  SSH=(sshpass -e ssh -o PreferredAuthentications=password -o PubkeyAuthentication=no -o StrictHostKeyChecking=accept-new)
else
  SSH=(ssh)
fi

usage() {
  sed -n '3,21p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
  exit 1
}

[[ $# -ge 1 ]] || usage
case "${1:-}" in -h|--help) usage ;; esac

# Macro expansion. Sequences are determined empirically against Knulli's ES
# menu layout; add them here once verified against the actual UI.
# (case rather than associative array — macOS ships bash 3.2.)
macro_expand() {
  case "$1" in
    reload-theme)
      # Main Menu -> User Interface Settings -> Theme Configuration ->
      # Reset Customizations (3rd item below GAMELIST VIEW STYLE), then
      # back out. Reset is what forces ES to re-read theme files from
      # disk; toggling a subset (colorset/view-style) only re-applies
      # from a cached parse and will NOT pick up edited files. Reset also
      # returns the theme subsets to their defaults.
      echo "start sleep:700 down sleep:250 down sleep:250 a sleep:800 down sleep:250 a sleep:800 down sleep:250 down sleep:250 down sleep:250 a sleep:2500 b sleep:400 b"
      ;;
    *) return 1 ;;
  esac
}

if [[ $# -eq 1 ]] && expanded=$(macro_expand "$1"); then
  # shellcheck disable=SC2206 # intentional word split on macro tokens
  TOKENS=($expanded)
else
  TOKENS=("$@")
fi

# Validate tokens client-side so a typo errors out before we ssh.
for tok in "${TOKENS[@]}"; do
  case "$tok" in
    a|b|x|y|l|r|l2|r2|start|select|hotkey|up|down|left|right) ;;
    sleep:*[!0-9]*|sleep:) echo "bad sleep token: $tok (use sleep:NNN ms)" >&2; exit 2 ;;
    sleep:*) ;;
    *) echo "unknown token: $tok" >&2; exit 2 ;;
  esac
done

"${SSH[@]}" "${DEVICE}" "python3 - ${TOKENS[*]}" <<'PYEOF'
import struct, os, sys, time

# Token -> ('btn'|'hat', code, value). Codes match the TRIMUI Brick Controller's
# es_input.cfg mapping; buttons use evdev codes, dpad uses the HAT axes.
BTN, HAT = 'btn', 'hat'
ACTIONS = {
    'a':      (BTN, 305, 1),  # right face  (ES "a")
    'b':      (BTN, 304, 1),  # bottom face (ES "b")
    'x':      (BTN, 307, 1),  # top face
    'y':      (BTN, 308, 1),  # left face
    'l':      (BTN, 310, 1),  # L1 shoulder ("pageup" in ES)
    'r':      (BTN, 311, 1),  # R1 shoulder ("pagedown" in ES)
    'l2':     (BTN, 312, 1),  # L2 trigger
    'r2':     (BTN, 313, 1),  # R2 trigger
    'hotkey': (BTN, 316, 1),
    'select': (BTN, 314, 1),
    'start':  (BTN, 315, 1),
    'up':     (HAT, 0x11, -1),  # ABS_HAT0Y
    'down':   (HAT, 0x11,  1),
    'left':   (HAT, 0x10, -1),  # ABS_HAT0X
    'right':  (HAT, 0x10,  1),
}

EV_SYN, EV_KEY, EV_ABS = 0x00, 0x01, 0x03
FMT = "qqHHi"  # tv_sec(s64) tv_usec(s64) type(u16) code(u16) value(s32) = 24B on aarch64

def find_event_node(name="TRIMUI Brick Controller"):
    cur = {}
    with open("/proc/bus/input/devices") as f:
        for line in f:
            line = line.rstrip()
            if not line:
                cur = {}; continue
            if line.startswith("N: Name="):
                cur['name'] = line.split("=", 1)[1].strip().strip('"')
            elif line.startswith("H: Handlers="):
                for h in line.split("=", 1)[1].split():
                    if h.startswith("event"):
                        cur['event'] = h
            if cur.get('name') == name and 'event' in cur:
                return "/dev/input/" + cur['event']
    raise RuntimeError("controller %r not found" % name)

path = find_event_node()
fd = os.open(path, os.O_WRONLY)

def emit(ev_type, code, value):
    now_s = int(time.time())
    os.write(fd, struct.pack(FMT, now_s, 0, ev_type, code, value))
    os.write(fd, struct.pack(FMT, now_s, 0, EV_SYN, 0, 0))

TAP_MS, GAP_MS = 120, 80

for tok in sys.argv[1:]:
    if tok.startswith('sleep:'):
        time.sleep(int(tok.split(':', 1)[1]) / 1000.0)
        continue
    kind, code, value = ACTIONS[tok]
    ev_type = EV_KEY if kind == BTN else EV_ABS
    emit(ev_type, code, value)
    time.sleep(TAP_MS / 1000.0)
    emit(ev_type, code, 0)
    time.sleep(GAP_MS / 1000.0)

os.close(fd)
PYEOF
