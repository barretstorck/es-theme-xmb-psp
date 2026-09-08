#!/usr/bin/env bash
# Runs INSIDE the harness container. Starts Xvfb, configures ES, launches it,
# captures a screenshot of the requested view to /harness-out/$OUTNAME.
set -euo pipefail

VIEW="${VIEW:-system}"
RESOLUTION="${RESOLUTION:-1024x768}"
COLORSET="${COLORSET:-January Blue}"
OUTNAME="${OUTNAME:-render.png}"
HAS_LIBRARY="${HAS_LIBRARY:-0}"
CAROUSEL_RIGHT="${CAROUSEL_RIGHT:-0}"
SETTLE="${SETTLE:-0}"
FRAMES="${FRAMES:-1}"
FRAME_INTERVAL="${FRAME_INTERVAL:-1}"

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
# A representative knulli.conf. ES and configgen read settings from here; an
# empty file is not what the device looks like.
cat > /userdata/system/knulli.conf <<'KNULLI'
system.language=en_US
system.kblayout=us
system.timezone=America/Chicago
system.power.led=1
audio.bgmusic=0
KNULLI

# --- es_systems.cfg + roms ---
# If the library ships its own es_systems.cfg, use it verbatim. Knulli's real
# one carries proper fullnames ("Super Nintendo Entertainment System", not
# "snes"), per-system extension lists and theme folder names. Synthesising
# <fullname>${sysname}</fullname> hides any theme that keys off those - a theme
# can render blank here and fine on the device, or vice versa.
SYSTEMS_XML=""
if [[ "${HAS_LIBRARY}" == "1" ]] && [[ -d /harness-library ]]; then
  # The library is mounted read-only; copy it so ES can write gamelist caches.
  cp -r /harness-library/. /userdata/roms/
  if [[ -f /userdata/roms/es_systems.cfg ]]; then
    mv /userdata/roms/es_systems.cfg "${ES_CFG}/es_systems.cfg"
    echo "using library-provided es_systems.cfg" >&2
  fi
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
if [[ ! -f "${ES_CFG}/es_systems.cfg" ]]; then
  printf '<?xml version="1.0"?>\n<systemList>\n%s</systemList>\n' "${SYSTEMS_XML}" \
    > "${ES_CFG}/es_systems.cfg"
fi

# --- es_settings.cfg ---
# ThemeColorSet is the persisted key for the "colorset" subset in this ES build.
# Discovered by grepping /opt/es/es-app/src/guis/GuiMenu.cpp:
#   if (subset == "colorset") settingName = "ThemeColorSet";
# and /opt/es/es-core/src/ThemeData.cpp:
#   mColorset = Settings::getInstance()->getString("ThemeColorSet");
# All other (non-special) subsets use the generic key "subset.<name>" per
# GuiMenu.cpp:3276 — that is why battery uses "subset.battery" and not a
# named constant.

# Gamelist view style. v0.12: use "automatic" for the plain gamelist view so
# the theme's own root defaultView attribute selects the view type — that is
# the mechanism the gamelistStyle subset relies on (ThemeData.cpp:1329 sets
# mDefaultView; ViewController.cpp:715-720 substitutes it when the preference
# is "automatic"). Pinning "detailed" here would mask it.
case "${VIEW}" in
  gamecarousel) GLVIEW="gamecarousel" ;;
  gamelist)     GLVIEW="automatic" ;;
  *)            GLVIEW="automatic" ;;
esac

# Optional subset pins (ICON_SIZE / TITLE_VISIBILITY / GAMELIST_STYLE envs).
# Generic subsets persist as "subset.<name>" (GuiMenu.cpp:3276); empty env =
# theme default.
SUBSET_LINES=""
[[ -n "${ICON_SIZE:-}" ]] && SUBSET_LINES+="  <string name=\"subset.iconSize\" value=\"${ICON_SIZE}\" />"$'\n'
[[ -n "${TITLE_VISIBILITY:-}" ]] && SUBSET_LINES+="  <string name=\"subset.titleVisibility\" value=\"${TITLE_VISIBILITY}\" />"$'\n'
[[ -n "${GAMELIST_STYLE:-}" ]] && SUBSET_LINES+="  <string name=\"subset.gamelistStyle\" value=\"${GAMELIST_STYLE}\" />"$'\n'
[[ -n "${VIDEO_DELAY:-}" ]] && SUBSET_LINES+="  <string name=\"subset.videoDelay\" value=\"${VIDEO_DELAY}\" />"$'\n'
[[ -n "${VIDEO_AUDIO:-}" ]] && SUBSET_LINES+="  <string name=\"subset.videoAudio\" value=\"${VIDEO_AUDIO}\" />"$'\n'

cat > "${ES_CFG}/es_settings.cfg" <<XML
<?xml version="1.0"?>
<config>
  <string name="ThemeSet" value="es-theme-xmb-psp" />
  <string name="ThemeColorSet" value="${COLORSET}" />
  <string name="GamelistViewStyle" value="${GLVIEW}" />
${SUBSET_LINES}  <bool name="ShowHelpPrompts" value="false" />
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
    # Right walks the system carousel; the harness enters whichever system is
    # selected. Needed to reach a system whose games have scraped video.
    for _i in $(seq 1 "${CAROUSEL_RIGHT}"); do key Right 1; done
    key Return 4
    for _i in $(seq 1 "${GAMELIST_DOWN:-0}"); do key Down 1; done ;;  # diagnostic: move cursor down N times
  menu)
    # "start" button in the ES keyboard map is Space (key id 32).
    key space 3 ;;
esac
sleep 2

# Video previews only appear after the theme's <delay> seconds of still
# snapshot (VideoComponent.cpp:282 converts it to ms), so a capture taken
# immediately shows the snapshot, never a playing frame. --settle waits it out.
if (( SETTLE > 0 )); then
  echo "settling ${SETTLE}s before capture" >&2
  sleep "${SETTLE}"
fi

# Fail loudly if ES died before we could screenshot, instead of capturing a
# blank frame and reporting success.
if ! kill -0 "${ES_PID}" 2>/dev/null; then
  echo "ERROR: emulationstation exited before the screenshot. ES log:" >&2
  cat /tmp/es.log >&2 || true
  kill "${XVFB_PID}" 2>/dev/null || true
  exit 1
fi

# --- screenshot ---
# One frame by default. --frames captures a sequence FRAME_INTERVAL seconds
# apart, which is how a *transition* (snapshot -> video) gets verified: a
# single still cannot show a handoff.
if (( FRAMES > 1 )); then
  for i in $(seq 1 "${FRAMES}"); do
    import -window root "/harness-out/${OUTNAME%.png}-${i}.png"
    if (( i < FRAMES )); then sleep "${FRAME_INTERVAL}"; fi
  done
else
  import -window root "/harness-out/${OUTNAME}"
fi

kill "${ES_PID}" 2>/dev/null || true
kill "${XVFB_PID}" 2>/dev/null || true
echo "rendered ${VIEW} @ ${RESOLUTION} -> /harness-out/${OUTNAME}"
