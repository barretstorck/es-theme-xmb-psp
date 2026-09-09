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
GAMELIST_DOWN="${GAMELIST_DOWN:-0}"

# These arrive as strings and are all used in `(( ))`, which reads a leading
# zero as OCTAL — FRAMES=08 is a parse error, not eight frames. Validate and
# re-print base-10 so a zero-padded value cannot silently change behaviour.
for _n in CAROUSEL_RIGHT SETTLE FRAMES FRAME_INTERVAL GAMELIST_DOWN; do
  if [[ ! "${!_n}" =~ ^[0-9]+$ ]]; then
    echo "ERROR: ${_n} must be a non-negative integer (got '${!_n}')" >&2
    exit 2
  fi
  printf -v "${_n}" '%d' "$((10#${!_n}))"
done

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

# Optional subset pins (ICON_SIZE / TITLE_VISIBILITY / GAMELIST_STYLE /
# SCROLL_SPEED envs). Generic subsets persist as "subset.<name>"
# (GuiMenu.cpp:3276); empty env = theme default.
SUBSET_LINES=""
[[ -n "${ICON_SIZE:-}" ]] && SUBSET_LINES+="  <string name=\"subset.iconSize\" value=\"${ICON_SIZE}\" />"$'\n'
[[ -n "${TITLE_VISIBILITY:-}" ]] && SUBSET_LINES+="  <string name=\"subset.titleVisibility\" value=\"${TITLE_VISIBILITY}\" />"$'\n'
[[ -n "${GAMELIST_STYLE:-}" ]] && SUBSET_LINES+="  <string name=\"subset.gamelistStyle\" value=\"${GAMELIST_STYLE}\" />"$'\n'
# scrollSpeed sets the description auto-scroll cadence in ms per pixel step.
# Unpinned it falls to the subset's first include (Normal, 150ms) — so a
# render only ever exercises one of the three without this.
[[ -n "${SCROLL_SPEED:-}" ]] && SUBSET_LINES+="  <string name=\"subset.scrollSpeed\" value=\"${SCROLL_SPEED}\" />"$'\n'
# videoDelay is pinned rather than left at the theme's own 5s default. Video
# plays here now, and a capture taken ~6s after entering a gamelist lands
# mid-playback on an arbitrary frame, so any render of a game with a scraped
# video would differ run to run. 10s outlasts the default capture; ask for a
# shorter delay (and --settle past it) when the video is what you want to see.
[[ -n "${VIDEO_DELAY:-}" ]] || VIDEO_DELAY="10 seconds"
SUBSET_LINES+="  <string name=\"subset.videoDelay\" value=\"${VIDEO_DELAY}\" />"$'\n'
[[ -n "${VIDEO_AUDIO:-}" ]] && SUBSET_LINES+="  <string name=\"subset.videoAudio\" value=\"${VIDEO_AUDIO}\" />"$'\n'
# buttonGlyphs picks the helpsystem face-button glyph set (PSP / Nintendo /
# Xbox). Unpinned it falls to the subset's first include (Nintendo, the
# default — the TrimUI Brick's physical buttons carry the Nintendo layout).
[[ -n "${BUTTON_GLYPHS:-}" ]] && SUBSET_LINES+="  <string name=\"subset.buttonGlyphs\" value=\"${BUTTON_GLYPHS}\" />"$'\n'

# ShowHelpPrompts gates ES's bottom help strip entirely (HelpComponent.cpp:
# updateGrid() returns early and clears the grid when it is false). The harness
# kept it off so the strip never intruded on layout captures; it must be ON to
# see the helpsystem glyphs at all, so it is now a flag. Default stays "false"
# so every pre-existing render is byte-for-byte unchanged.
: "${SHOW_HELP:=false}"

# InvertButtons is load-bearing for anything touching <helpsystem>, not a
# comfort setting. It decides which physical button confirms
# (BUTTON_OK = invertButtons ? "a"/east : "b"/south), and therefore which GLYPH
# the CONFIRM and BACK labels sit next to in the help strip.
#
# It does NOT move a glyph between buttons. InputConfig::buttonLabel(), which
# picks the icon, holds an a/b swap keyed on this setting — but that swap is
# inside "#ifdef INVERTEDINPUTCONFIG", which InputConfig.h:12-14 defines only
# "#ifdef WIN32". Here it is dead code and buttonLabel() is the identity, so
# each of the four face slots stays nailed to a position. Worth stating
# because the source reads the other way at a glance; both states were
# rendered with probe glyphs to settle it.
#
# ES's own default is false (Settings.cpp:188), but the TrimUI Brick ships
# "true" in /userdata/system/configs/emulationstation/es_settings.cfg, and the
# harness exists to predict the device — at ES's default the strip would show
# the confirm glyph on the wrong side of the two. INVERT_BUTTONS=false renders
# what a user who flipped Menu > Invert Buttons sees.
: "${INVERT_BUTTONS:=true}"

cat > "${ES_CFG}/es_settings.cfg" <<XML
<?xml version="1.0"?>
<config>
  <string name="ThemeSet" value="es-theme-xmb-psp" />
  <string name="ThemeColorSet" value="${COLORSET}" />
  <string name="GamelistViewStyle" value="${GLVIEW}" />
${SUBSET_LINES}  <bool name="ShowHelpPrompts" value="${SHOW_HELP}" />
  <bool name="InvertButtons" value="${INVERT_BUTTONS}" />
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
#   ES button "b" = key id 13 = Return
#   ES button "a" = key id 27 = Escape
#   start         = key id 32 = space
#   up/down/left/right = arrow keys
#
# WHICH of "a"/"b" confirms is decided by InvertButtons, not by the key map:
# InputConfig::AssignActionButtons() (InputConfig.cpp:404-414) sets
#   BUTTON_OK = invertButtons ? ABUTTON : BBUTTON
# on every non-Windows build, INVERTEDINPUTCONFIG being #ifdef WIN32
# (InputConfig.h:12-14). So confirm is "a"/Escape when InvertButtons is true
# and "b"/Return when it is false. This used to be hardcoded to Return, which
# was correct only because the harness had no InvertButtons line and ES's
# built-in default is false; pinning the device's "true" silently left every
# gamelist render sitting on the system carousel until this was derived.
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

if [[ "${INVERT_BUTTONS}" == "true" ]]; then
  CONFIRM_KEY="Escape"
else
  CONFIRM_KEY="Return"
fi

echo "navigating: VIEW=${VIEW} (confirm=${CONFIRM_KEY})" >&2
case "${VIEW}" in
  system)
    # Already on the system carousel; Right walks it so a specific system can
    # be captured. Without this the system view ignored CAROUSEL_RIGHT and
    # every position rendered the first system.
    for _i in $(seq 1 "${CAROUSEL_RIGHT}"); do key Right 1; done ;;
  gamelist|gamecarousel)
    # Right walks the system carousel; the harness enters whichever system is
    # selected. Needed to reach a system whose games have scraped video.
    for _i in $(seq 1 "${CAROUSEL_RIGHT}"); do key Right 1; done
    key "${CONFIRM_KEY}" 4
    for _i in $(seq 1 "${GAMELIST_DOWN}"); do key Down 1; done ;;  # diagnostic: move cursor down N times
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

# Fail loudly if ES died, instead of capturing a blank frame and reporting
# success. Checked before EVERY capture: a --frames sequence can span minutes,
# so a single check up front would let a mid-sequence crash through as a run of
# blank PNGs and exit 0 — the exact outcome this guard exists to prevent.
require_es_alive() { # require_es_alive <when>
  kill -0 "${ES_PID}" 2>/dev/null && return 0
  echo "ERROR: emulationstation exited ${1}. ES log:" >&2
  cat /tmp/es.log >&2 || true
  kill "${XVFB_PID}" 2>/dev/null || true
  exit 1
}

# --- screenshot ---
# One frame by default. --frames captures a sequence FRAME_INTERVAL seconds
# apart, which is how a *transition* (snapshot -> video) gets verified: a
# single still cannot show a handoff.
if (( FRAMES > 1 )); then
  for i in $(seq 1 "${FRAMES}"); do
    require_es_alive "before frame ${i}/${FRAMES}"
    import -window root "/harness-out/${OUTNAME%.png}-${i}.png"
    if (( i < FRAMES )); then sleep "${FRAME_INTERVAL}"; fi
  done
else
  require_es_alive "before the screenshot"
  import -window root "/harness-out/${OUTNAME}"
fi

kill "${ES_PID}" 2>/dev/null || true
kill "${XVFB_PID}" 2>/dev/null || true
if (( FRAMES > 1 )); then
  echo "rendered ${VIEW} @ ${RESOLUTION} -> /harness-out/${OUTNAME%.png}-1.png .. ${OUTNAME%.png}-${FRAMES}.png"
else
  echo "rendered ${VIEW} @ ${RESOLUTION} -> /harness-out/${OUTNAME}"
fi
