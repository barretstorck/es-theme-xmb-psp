#!/usr/bin/env bash
# Runs INSIDE the harness container. Starts Xvfb, configures ES, launches it,
# captures a screenshot of the requested view to /harness-out/$OUTNAME.
set -euo pipefail

VIEW="${VIEW:-system}"
RESOLUTION="${RESOLUTION:-1024x768}"
COLORSET="${COLORSET:-January Blue}"
OUTNAME="${OUTNAME:-render.png}"
HAS_LIBRARY="${HAS_LIBRARY:-0}"

ES_CFG="/userdata/system/configs/emulationstation"

# --- virtual display + software GL ---
Xvfb :99 -screen 0 "${RESOLUTION}x24" >/tmp/xvfb.log 2>&1 &
XVFB_PID=$!
sleep 2
export DISPLAY=:99
export LIBGL_ALWAYS_SOFTWARE=1
export SDL_AUDIODRIVER=dummy

# --- KNULLI directory layout ---
mkdir -p "${ES_CFG}" /userdata/system/logs /userdata/roms \
         /usr/share/emulationstation/resources
cp -r /opt/es/resources/* /usr/share/emulationstation/resources/ 2>/dev/null || true
touch /userdata/system/knulli.conf

# --- es_systems.cfg + roms ---
SYSTEMS_XML=""
if [[ "${HAS_LIBRARY}" == "1" ]] && [[ -d /harness-library ]]; then
  # The library is mounted read-only; copy it so ES can write gamelist caches.
  cp -r /harness-library/. /userdata/roms/
  for sysdir in /userdata/roms/*/; do
    sysname="$(basename "${sysdir}")"
    [[ -d "${sysdir}" ]] || continue
    SYSTEMS_XML+="  <system><name>${sysname}</name><fullname>${sysname}</fullname>"
    SYSTEMS_XML+="<path>/userdata/roms/${sysname}</path>"
    SYSTEMS_XML+="<extension>.zip .bin .iso .chd .pce .nes .smc .sh</extension>"
    SYSTEMS_XML+="<command>echo %ROM%</command>"
    SYSTEMS_XML+="<platform>${sysname}</platform><theme>${sysname}</theme></system>"$'\n'
  done
elif [[ "${HAS_LIBRARY}" == "1" ]]; then
  echo "WARNING: HAS_LIBRARY=1 but /harness-library is not a directory; using dummy system" >&2
fi
if [[ -z "${SYSTEMS_XML}" ]]; then
  mkdir -p /userdata/roms/snes && touch /userdata/roms/snes/placeholder.smc
  SYSTEMS_XML="  <system><name>snes</name><fullname>Super Nintendo</fullname><path>/userdata/roms/snes</path><extension>.smc</extension><command>echo %ROM%</command><platform>snes</platform><theme>snes</theme></system>"
fi
printf '<?xml version="1.0"?>\n<systemList>\n%s</systemList>\n' "${SYSTEMS_XML}" \
  > "${ES_CFG}/es_systems.cfg"

# --- es_settings.cfg ---
# ThemeColorSet is the persisted key for the "colorset" subset in this ES build.
# Discovered by grepping /opt/es/es-app/src/guis/GuiMenu.cpp:
#   if (subset == "colorset") settingName = "ThemeColorSet";
# and /opt/es/es-core/src/ThemeData.cpp:
#   mColorset = Settings::getInstance()->getString("ThemeColorSet");
# All other (non-special) subsets use the generic key "subset.<name>" per
# GuiMenu.cpp:3276 — that is why battery uses "subset.battery" and not a
# named constant.

# Gamelist view style: gamecarousel view -> the boxart carousel, else detailed.
# Setting name confirmed from ViewController.cpp: getString("GamelistViewStyle"),
# with values "gamecarousel" / "detailed" (CarouselGameListView / DetailedGameListView).
case "${VIEW}" in
  gamecarousel) GLVIEW="gamecarousel" ;;
  gamelist)     GLVIEW="detailed" ;;
  *)            GLVIEW="automatic" ;;   # system/menu views: gamelist style irrelevant
esac

cat > "${ES_CFG}/es_settings.cfg" <<XML
<?xml version="1.0"?>
<config>
  <string name="ThemeSet" value="es-theme-xmb-psp" />
  <string name="ThemeColorSet" value="${COLORSET}" />
  <string name="GamelistViewStyle" value="${GLVIEW}" />
  <bool name="ShowHelpPrompts" value="false" />
  <bool name="MusicEnabled" value="false" />
</config>
XML

# --- launch ES ---
emulationstation --no-splash --windowed >/tmp/es.log 2>&1 &
ES_PID=$!

# Wait for the theme to load and the first frame to settle.
sleep 10

# --- navigate to the requested view ---
# ES keyboard map (from /usr/share/emulationstation/es_input.cfg):
#   b (confirm/select) = key id 13 = Return
#   a (back)           = key id 27 = Escape
#   start              = key id 32 = space
#   up/down/left/right = arrow keys
# xdotool sends keystrokes to the Xvfb display.
key() {
  local sym="$1" wait="${2:-1}"
  # Try to target the ES window; fall back to sending to the active display.
  local winid
  winid="$(xdotool search --onlyvisible --name 'EmulationStation' 2>/dev/null | head -1 || true)"
  if [[ -n "${winid}" ]]; then
    xdotool key --window "${winid}" "${sym}" 2>/dev/null || xdotool key "${sym}" 2>/dev/null || true
  else
    xdotool key "${sym}" 2>/dev/null || true
  fi
  sleep "${wait}"
}

echo "navigating: VIEW=${VIEW}" >&2
case "${VIEW}" in
  system)
    : ;;                                   # already on the system carousel
  gamelist|gamecarousel)
    key Return 4
    for _i in $(seq 1 "${GAMELIST_DOWN:-0}"); do key Down 1; done ;;  # diagnostic: move cursor down N times
  menu)
    # "start" button in the ES keyboard map is Space (key id 32).
    key space 3 ;;
esac
sleep 2

# Fail loudly if ES died before we could screenshot, instead of capturing a
# blank frame and reporting success.
if ! kill -0 "${ES_PID}" 2>/dev/null; then
  echo "ERROR: emulationstation exited before the screenshot. ES log:" >&2
  cat /tmp/es.log >&2 || true
  kill "${XVFB_PID}" 2>/dev/null || true
  exit 1
fi

# --- screenshot ---
import -window root "/harness-out/${OUTNAME}"

kill "${ES_PID}" 2>/dev/null || true
kill "${XVFB_PID}" 2>/dev/null || true
echo "rendered ${VIEW} @ ${RESOLUTION} -> /harness-out/${OUTNAME}"
