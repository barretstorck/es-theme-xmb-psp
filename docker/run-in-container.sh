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

# --- es_systems.cfg ---
# Task 2: a single dummy system so the system view has something to show.
# Task 4 regenerates this from the mounted library.
mkdir -p "/userdata/roms/snes"
touch "/userdata/roms/snes/placeholder.smc"
cat > "${ES_CFG}/es_systems.cfg" <<XML
<?xml version="1.0"?>
<systemList>
  <system>
    <name>snes</name>
    <fullname>Super Nintendo</fullname>
    <path>/userdata/roms/snes</path>
    <extension>.smc</extension>
    <command>echo %ROM%</command>
    <platform>snes</platform>
    <theme>snes</theme>
  </system>
</systemList>
XML

# --- es_settings.cfg ---
# ThemeColorSet is the persisted key for the "colorset" subset in this ES build.
# Discovered by grepping /opt/es/es-app/src/guis/GuiMenu.cpp:
#   if (subset == "colorset") settingName = "ThemeColorSet";
# and /opt/es/es-core/src/ThemeData.cpp:
#   mColorset = Settings::getInstance()->getString("ThemeColorSet");
cat > "${ES_CFG}/es_settings.cfg" <<XML
<?xml version="1.0"?>
<config>
  <string name="ThemeSet" value="es-theme-xmb-psp" />
  <string name="ThemeColorSet" value="${COLORSET}" />
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
case "${VIEW}" in
  system) : ;;  # ES launches on the system carousel; no navigation
  *) echo "VIEW=${VIEW} not supported yet (Task 4)" >&2; exit 1 ;;
esac
sleep 1

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
