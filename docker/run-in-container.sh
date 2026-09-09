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
GAMELIST_RIGHT="${GAMELIST_RIGHT:-0}"
SPLASH_AT="${SPLASH_AT:-0.4}"
RECORD_SCRIPT="${RECORD_SCRIPT:-}"
AUDIO_SCRIPT="${AUDIO_SCRIPT:-}"
RECORD_FPS="${RECORD_FPS:-10}"
RECORD_WIDTH="${RECORD_WIDTH:-640}"
# Must match record.sh's COLORS default; this fallback only applies to a
# direct `VIEW=record docker run`, which is exactly why the drift went
# unnoticed — record.sh always passes the value explicitly.
RECORD_COLORS="${RECORD_COLORS:-96}"
KEEP_FRAMES="${KEEP_FRAMES:-0}"

# These arrive as strings and are all used in `(( ))`, which reads a leading
# zero as OCTAL — FRAMES=08 is a parse error, not eight frames. Validate and
# re-print base-10 so a zero-padded value cannot silently change behaviour.
for _n in CAROUSEL_RIGHT SETTLE FRAMES GAMELIST_DOWN GAMELIST_RIGHT \
         RECORD_FPS RECORD_WIDTH RECORD_COLORS KEEP_FRAMES; do
  if [[ ! "${!_n}" =~ ^[0-9]+$ ]]; then
    echo "ERROR: ${_n} must be a non-negative integer (got '${!_n}')" >&2
    exit 2
  fi
  printf -v "${_n}" '%d' "$((10#${!_n}))"
done
# FRAME_INTERVAL and SPLASH_AT reach nothing but `sleep`, and the boot splash
# needs sub-second resolution to catch at all - so they are validated as
# numbers, not integers, and deliberately not re-printed through `(( ))`.
for _n in FRAME_INTERVAL SPLASH_AT; do
  if [[ ! "${!_n}" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
    echo "ERROR: ${_n} must be a non-negative number (got '${!_n}')" >&2
    exit 2
  fi
done

# Zero would divide by zero when the frame period is computed, and a 1px-wide
# GIF or a 1-colour palette is a silently useless artifact rather than an
# error. The octal loop above only proves they are digits.
if [[ "${VIEW}" == "record" ]]; then
  (( RECORD_FPS >= 1 ))    || { echo "ERROR: RECORD_FPS must be >= 1" >&2; exit 2; }
  (( RECORD_WIDTH >= 16 )) || { echo "ERROR: RECORD_WIDTH must be >= 16" >&2; exit 2; }
  (( RECORD_COLORS >= 2 && RECORD_COLORS <= 256 )) \
    || { echo "ERROR: RECORD_COLORS must be 2..256" >&2; exit 2; }
fi

ES_CFG="/userdata/system/configs/emulationstation"

# --- virtual display + software GL ---
Xvfb :99 -screen 0 "${RESOLUTION}x24" >/tmp/xvfb.log 2>&1 &
XVFB_PID=$!
sleep 2
export DISPLAY=:99
export LIBGL_ALWAYS_SOFTWARE=1

# VIEW=audio captures what ES actually SENDS TO THE MIXER, which is the only
# way to check a sound binding: a theme <sound> element that ES never asks for
# is indistinguishable from a working one by reading the XML, and every other
# view in this harness is a screenshot. SDL's "disk" driver runs the normal
# audio callback and writes the mixed output to a file instead of a device,
# pacing itself to real time — so byte offsets in that file ARE timestamps.
# Format is fixed by AudioManager's Mix_OpenAudio(44100, MIX_DEFAULT_FORMAT, 2)
# (AudioManager.cpp:71) = signed 16-bit little-endian stereo at 44100 Hz.
ES_AUDIO_RAW=/tmp/es-audio.raw
if [[ "${VIEW}" == "audio" ]]; then
  export SDL_AUDIODRIVER=disk
  export SDL_DISKAUDIOFILE="${ES_AUDIO_RAW}"
else
  export SDL_AUDIODRIVER=dummy
fi

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
# GuiMenu.cpp:3276 — hence the "subset.<name>" lines built below.
#
# The battery widget is deliberately NOT one of them. It has no theme subset:
# visibility is ES's own ShowBattery setting (GuiMenu.cpp:3928 offers
# NO / ICON / ICON AND TEXT as "" / "icon" / "text"), and a theme cannot
# override it — BatteryIconComponent::update() calls setVisible() from
# hasBattery on every tick, discarding whatever the theme asked for.

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

# ShowBattery gates the status-bar battery elements. Written only when asked
# for, so an unpinned render keeps ES's own default of "text" (Settings.cpp:180)
# — the same value a stock device has. "none" is spelled as the empty string
# because that is what ES stores for the menu's "NO" (GuiMenu.cpp:3928); an
# absent key and an empty value are NOT the same thing here.
SHOW_BATTERY="${SHOW_BATTERY:-}"
BATTERY_LINE=""
if [[ -n "${SHOW_BATTERY}" ]]; then
  [[ "${SHOW_BATTERY}" == "none" ]] && SHOW_BATTERY=""
  BATTERY_LINE="  <string name=\"ShowBattery\" value=\"${SHOW_BATTERY}\" />"$'\n'
fi

# Sound::getFromTheme logs " req sound [<view>.<element>]" and "   (missing)"
# at LogInfo (Sound.cpp:32-38), which is a complete record of which element
# names ES asked the theme for and which resolved — the one oracle that can see
# the "launch" and "menuOpen" bindings, since both fire on transitions that
# reopen or tear down the audio device and so cannot be caught in the PCM
# capture. ES's own default is "error" (Log.cpp:41), so this has to be pinned.
LOG_LEVEL="${LOG_LEVEL:-}"
[[ "${VIEW}" == "audio" && -z "${LOG_LEVEL}" ]] && LOG_LEVEL=information
LOGLEVEL_LINE=""
if [[ -n "${LOG_LEVEL}" ]]; then
  LOGLEVEL_LINE="  <string name=\"LogLevel\" value=\"${LOG_LEVEL}\" />"$'\n'
fi

# ES ships navigation sounds OFF: Settings.cpp:168 sets EnableSounds=false, and
# Sound::init/Sound::play both bail on it (Sound.cpp:70, 97), so with it unset
# NOTHING the theme declares can make a noise. The TrimUI Brick's own
# es_settings.cfg does not carry the key either, so a stock device is silent
# until the user turns on Menu > Sound Settings > "Enable Navigation Sounds".
# Written only when asked for, so an unpinned render keeps that stock silence
# rather than quietly testing a configuration no device has.
ENABLE_SOUNDS="${ENABLE_SOUNDS:-}"
SOUNDS_LINE=""
if [[ -n "${ENABLE_SOUNDS}" ]]; then
  SOUNDS_LINE="  <bool name=\"EnableSounds\" value=\"${ENABLE_SOUNDS}\" />"$'\n'
fi

# 12-hour clock. Off by default (ES's own default), but the Bricks are set to
# it and it is ~1.7x wider, so it is the width the status cluster must fit.
CLOCK_LINE=""
if [[ -n "${CLOCK_12H:-}" ]]; then
  CLOCK_LINE="  <bool name=\"ClockMode12\" value=\"${CLOCK_12H}\" />"$'\n'
fi

cat > "${ES_CFG}/es_settings.cfg" <<XML
<?xml version="1.0"?>
<config>
  <string name="ThemeSet" value="es-theme-xmb-psp" />
  <string name="ThemeColorSet" value="${COLORSET}" />
  <string name="GamelistViewStyle" value="${GLVIEW}" />
${SUBSET_LINES}${BATTERY_LINE}${CLOCK_LINE}${SOUNDS_LINE}${LOGLEVEL_LINE}  <bool name="ShowHelpPrompts" value="${SHOW_HELP}" />
  <bool name="InvertButtons" value="${INVERT_BUTTONS}" />
  <bool name="MusicEnabled" value="false" />
</config>
XML

# --- launch ES ---
# Every view but one wants the boot splash gone: it would otherwise cover the
# opening seconds of the capture window. VIEW=splash is the exception - it is
# the splash we are here to photograph, so ES is launched without the flag that
# suppresses it. (Settings.cpp:128 has SplashScreen defaulting to true, which is
# also why the device shows it; the harness was the only thing turning it off.)
ES_FLAGS=( --no-splash --windowed )
if [[ "${VIEW}" == "splash" ]]; then
  ES_FLAGS=( --windowed )
fi
emulationstation "${ES_FLAGS[@]}" >/tmp/es.log 2>&1 &
ES_PID=$!

if [[ "${VIEW}" == "splash" ]]; then
  # The splash is TRANSIENT. It lives from main.cpp:566 to main.cpp:628 and
  # then goToStart replaces it with the carousel, so unlike every other view
  # there is no settled state to wait for - the capture is a race against ES
  # finishing its own boot, and SPLASH_AT picks the moment. How long the window
  # actually is depends on how much there is to preload, so a library makes it
  # longer and more device-like. Use --frames to sweep if a single grab misses.
  #
  # The default is 0.4s and deliberately sub-second: the window closes by about
  # a second, so anything larger does not fail - it silently returns a perfectly
  # good screenshot of the CAROUSEL, which is the one outcome worth engineering
  # against here (a 3s default did exactly that). 0.4 is tuned for 1024x768;
  # smaller framebuffers boot faster and want less.
  echo "splash: capturing ${SPLASH_AT}s after launch (transient frame)" >&2
  sleep "${SPLASH_AT}"
else
  # Wait for the theme to load and the first frame to settle.
  sleep 10
fi

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

# Script vocabulary -> xdotool keysym. Shared by VIEW=record and VIEW=audio so
# the two cannot drift; see the case body for why this is a closed set rather
# than raw keysyms. Returns non-zero for an unknown name, leaving the caller to
# report it with its own context.
map_key_symbol() { # map_key_symbol <name>
  case "$1" in
    up)      printf 'Up' ;;
    down)    printf 'Down' ;;
    left)    printf 'Left' ;;
    right)   printf 'Right' ;;
    start)   printf 'space' ;;
    select)  printf 'BackSpace' ;;
    confirm) printf '%s' "${CONFIRM_KEY}" ;;
    back)    printf '%s' "$([[ "${CONFIRM_KEY}" == "Return" ]] && echo Escape || echo Return)" ;;
    *)       return 1 ;;
  esac
}

# ES parses these through pugixml's as_bool(), which accepts "true", "1", "yes"
# and any leading-T/Y spelling. A bare == "true" here would disagree with ES on
# INVERT_BUTTONS=1 — ES would invert, the harness would still send Return, and
# every gamelist render would silently stop on the system carousel. That is the
# exact bug this block was added to fix, so match as_bool()'s rule instead of
# guessing. render.sh rejects anything outside true/false up front; this stays
# permissive for direct container invocations.
es_as_bool() { # es_as_bool <value>
  case "$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')" in
    true|1|yes|y|t) return 0 ;;
    *) return 1 ;;
  esac
}

if es_as_bool "${INVERT_BUTTONS}"; then
  CONFIRM_KEY="Escape"
else
  CONFIRM_KEY="Return"
fi

# Fail loudly if ES died, instead of capturing a blank frame and reporting
# success. Checked before EVERY capture: a --frames sequence can span minutes,
# so a single check up front would let a mid-sequence crash through as a run of
# blank PNGs and exit 0 — the exact outcome this guard exists to prevent.
#
# Defined up here rather than beside the capture below because the VIEW=record
# block sits above the screenshot section and calls it from the navigation
# script. (The capture loop itself inlines the same `kill -0` test, because it
# runs in a background subshell where this function's `exit` would kill only
# the subshell.)
require_es_alive() { # require_es_alive <when>
  kill -0 "${ES_PID}" 2>/dev/null && return 0
  echo "ERROR: emulationstation exited ${1}. ES log:" >&2
  cat /tmp/es.log >&2 || true
  kill "${XVFB_PID}" 2>/dev/null || true
  exit 1
}

echo "navigating: VIEW=${VIEW} (confirm=${CONFIRM_KEY})" >&2
case "${VIEW}" in
  splash)
    # Nothing to navigate to: the frame is already on screen, and any keystroke
    # would only be queued for the carousel that replaces it.
    : ;;
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
    # Diagnostic cursor moves inside the gamelist. Down walks rows in a grid
    # (and rows in a textlist); Right walks columns, which only the Box Art
    # Grid has -- it is how a render reaches a tile at a column edge instead of
    # always photographing the top-left corner.
    for _i in $(seq 1 "${GAMELIST_DOWN}"); do key Down 1; done
    for _i in $(seq 1 "${GAMELIST_RIGHT}"); do key Right 1; done ;;
  record|audio)
    # Handled after this case: both drive their own navigation, because the
    # keys have to be pressed WHILE the capture is already running.
    : ;;
  menu)
    # "start" button in the ES keyboard map is Space (key id 32).
    key space 3 ;;
esac
# Settling time for a view that just finished navigating. Skipped for splash:
# two more seconds there is two seconds nearer to the splash being gone, and
# SPLASH_AT has already placed the capture deliberately.
[[ "${VIEW}" == "splash" ]] || sleep 2

# Video previews only appear after the theme's <delay> seconds of still
# snapshot (VideoComponent.cpp:282 converts it to ms), so a capture taken
# immediately shows the snapshot, never a playing frame. --settle waits it out.
if (( SETTLE > 0 )); then
  echo "settling ${SETTLE}s before capture" >&2
  sleep "${SETTLE}"
fi

# --- audio capture ---
# The output is one continuous real-time PCM stream plus a manifest of the byte
# offset at which each key was pressed. Offsets are taken from the file itself
# rather than from a wall clock, so the two can never drift apart: the analyser
# converts an offset straight to a timestamp and looks for sound in the window
# after it. Silence in that window is the finding — it is what a theme <sound>
# element ES never asks for produces.
if [[ "${VIEW}" == "audio" ]]; then
  if [[ -z "${AUDIO_SCRIPT}" ]]; then
    echo "ERROR: VIEW=audio needs AUDIO_SCRIPT" >&2
    exit 2
  fi

  # ES opens the audio device during startup, well before the 10s settle above,
  # so by here the file should exist and be growing. If it never appears, SDL
  # fell back or Mix_OpenAudio failed, and every event below would record a
  # perfectly clean run of nothing — a false PASS for "no sound is expected"
  # and a false FAIL for everything else. Refuse to produce that artifact.
  if [[ ! -f "${ES_AUDIO_RAW}" ]]; then
    echo "ERROR: SDL wrote no audio file at ${ES_AUDIO_RAW}." >&2
    echo "  Mix_OpenAudio probably failed; ES log:" >&2
    grep -i 'audio\|sdl' /tmp/es.log >&2 || true
    exit 1
  fi
  _size_a="$(stat -c%s "${ES_AUDIO_RAW}")"
  sleep 1
  _size_b="$(stat -c%s "${ES_AUDIO_RAW}")"
  if (( _size_b <= _size_a )); then
    echo "ERROR: ${ES_AUDIO_RAW} is not growing (${_size_a} -> ${_size_b} bytes)." >&2
    echo "  The SDL callback is not running, so nothing can be captured." >&2
    exit 1
  fi

  MANIFEST=/tmp/es-audio-events.tsv
  printf 'offset_bytes\tkey\n' > "${MANIFEST}"

  IFS=',' read -ra _steps <<< "${AUDIO_SCRIPT}"
  for _step in "${_steps[@]}"; do
    [[ -z "${_step}" ]] && continue
    _sym="${_step%%:*}"
    _wait="${_step#*:}"
    [[ "${_sym}" == "${_wait}" ]] && _wait=2
    if [[ ! "${_wait}" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
      echo "ERROR: bad wait '${_wait}' in step '${_step}'" >&2
      exit 2
    fi
    _name="${_sym}"
    if ! _sym="$(map_key_symbol "${_sym}")"; then
      echo "ERROR: unknown key '${_name}' in step '${_step}'" >&2
      exit 2
    fi
    require_es_alive "during the audio script"
    # Read the offset BEFORE pressing, so the recorded position is the last
    # sample that is certainly pre-keystroke. The analyser's window opens here.
    printf '%s\t%s\n' "$(stat -c%s "${ES_AUDIO_RAW}")" "${_name}" >> "${MANIFEST}"
    key "${_sym}" "${_wait}"
  done
  require_es_alive "after the audio script"

  # ES holds the last buffer until it exits; stopping it first flushes and
  # closes the stream so the capture ends on a sample boundary.
  kill "${ES_PID}" 2>/dev/null || true
  wait "${ES_PID}" 2>/dev/null || true

  cp "${ES_AUDIO_RAW}" "/harness-out/${OUTNAME%.raw}.raw"
  cp "${MANIFEST}" "/harness-out/${OUTNAME%.raw}.events.tsv"
  # Best-effort: the log is a second oracle, not the artifact. ES writes it to
  # its user path, which Paths.cpp resolves differently per build, so find it
  # rather than hardcoding a location that could silently stop matching.
  ES_LOG="$(find /userdata -name es_log.txt -type f 2>/dev/null | head -1)"
  if [[ -n "${ES_LOG}" ]]; then
    cp "${ES_LOG}" "/harness-out/${OUTNAME%.raw}.es_log.txt"
  else
    echo "WARNING: no es_log.txt found; the sound-request report will be empty" >&2
  fi
  kill "${XVFB_PID}" 2>/dev/null || true
  echo "captured $(stat -c%s "${ES_AUDIO_RAW}") bytes of s16le/44100/stereo" \
       "-> /harness-out/${OUTNAME%.raw}.raw"
  exit 0
fi

# --- recording ---
# A background capture loop plus a foreground key script. They are separate
# because their timing requirements conflict: the wave animates on 30s/20s/12s
# loops and needs EVENLY spaced frames or playback speed wobbles, while
# navigation needs UNEVEN pauses (dwell on a system, then move). One loop doing
# both serves neither.
if [[ "${VIEW}" == "record" ]]; then
  # Frames are written INSIDE the container, never to /harness-out. That
  # directory is a bind mount of whatever the caller passed to --out, so a
  # hardcoded "frames" subdirectory under it meant `--out ~/captures/x.gif`
  # would `rm -rf ~/captures/frames` as root — and render-readme-assets.sh
  # points --out at docs/screenshots, so a failed take left 100-200MB of PNGs
  # sitting inside the repo. Keeping them container-side makes both impossible.
  FRAMES_DIR=/tmp/record-frames
  rm -rf "${FRAMES_DIR}"
  mkdir -p "${FRAMES_DIR}"

  period="$(awk -v f="${RECORD_FPS}" 'BEGIN{printf "%.4f", 1/f}')"
  echo "recording at ${RECORD_FPS}fps (period ${period}s)" >&2

  # The loop is DEADLINE-scheduled: it sleeps until start + i*period rather
  # than sleeping a fixed period each pass. `import` costs ~90ms at 1280x720,
  # so a fixed sleep would accumulate that into drift and stretch a 12s
  # recording well past its intended length — and the wave would then play
  # back slower than it really moves.
  capture_loop() {
    local i=0 start now target remain
    start="$(date +%s.%N)"
    while [[ ! -e /tmp/record.stop ]]; do
      i=$((i + 1))
      # The rule above this function says the liveness check runs before EVERY
      # capture, and a recording is a few hundred captures. Without this, ES
      # dying between the last keystroke and the end of the take produced a run
      # of blank frames that the post-take check could only reject wholesale.
      # Recorded as a flag rather than exiting: this runs in a background
      # subshell, so `exit` here would kill only the subshell.
      if ! kill -0 "${ES_PID}" 2>/dev/null; then
        echo "ERROR: emulationstation exited during the recording" >&2
        touch /tmp/record.grabfail
        break
      fi
      # NOT `|| break` with stderr discarded. A swallowed failure used to end
      # the loop silently while the key script ran on, so `elapsed` covered the
      # whole take but `frame_count` covered only part of it — a break at frame
      # 5 of a 15s take produced a 5-frame GIF at 3 SECONDS per frame, written
      # to docs/screenshots and reported as success with exit 0. Record the
      # failure so the foreground can abort instead.
      if ! import -window root "$(printf "${FRAMES_DIR}/f-%06d.png" "${i}")"; then
        echo "ERROR: frame grab ${i} failed" >&2
        rm -f "$(printf "${FRAMES_DIR}/f-%06d.png" "${i}")"
        touch /tmp/record.grabfail
        break
      fi
      target="$(awk -v s="${start}" -v i="${i}" -v p="${period}" \
                    'BEGIN{printf "%.4f", s + i*p}')"
      now="$(date +%s.%N)"
      # Command substitution, NOT a pipe into `read` — a pipeline runs `read`
      # in a subshell and the value would never reach this loop.
      remain="$(awk -v t="${target}" -v n="${now}" \
                    'BEGIN{d = t - n; printf "%.4f", (d > 0 ? d : 0)}')"
      [[ "${remain}" != "0.0000" ]] && sleep "${remain}"
    done
  }

  rm -f /tmp/record.stop /tmp/record.grabfail
  record_start="$(date +%s.%N)"
  capture_loop &
  CAPTURE_PID=$!

  # Navigation script: comma-separated `key:seconds` steps. `confirm` and
  # `back` resolve through CONFIRM_KEY so the INVERT_BUTTONS inversion is
  # handled in exactly one place, the same as every other view.
  IFS=',' read -ra _steps <<< "${RECORD_SCRIPT}"
  for _step in "${_steps[@]}"; do
    [[ -z "${_step}" ]] && continue
    _sym="${_step%%:*}"
    _wait="${_step#*:}"
    [[ "${_sym}" == "${_wait}" ]] && _wait=1
    if [[ ! "${_wait}" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
      echo "ERROR: bad wait '${_wait}' in step '${_step}'" >&2
      touch /tmp/record.stop; exit 2
    fi
    # xdotool keysyms are CASE-SENSITIVE — "Right" is the arrow key, "right"
    # is not a keysym at all. key() swallows a bad symbol with `|| true`, so an
    # unmapped name is a SILENT no-op: the first take of this feature recorded
    # a perfectly good GIF in which no navigation happened. The script
    # vocabulary is therefore a closed set, mapped here and validated in
    # record.sh, rather than raw keysyms passed through.
    if ! _sym="$(map_key_symbol "${_sym}")"; then
      echo "ERROR: unknown key '${_step%%:*}' in step '${_step}'" >&2
      touch /tmp/record.stop; exit 2
    fi
    require_es_alive "during the recording script"
    key "${_sym}" "${_wait}"
  done

  touch /tmp/record.stop
  wait "${CAPTURE_PID}" 2>/dev/null || true
  record_end="$(date +%s.%N)"
  # Counted from the files actually on disk, not from a counter the loop wrote
  # on its way out. A loop that died any other way left no counter at all, so
  # frame_count fell back to 0 and the run aborted with "captured 0 frames"
  # while hundreds of good PNGs sat in the directory.
  frame_count="$(find "${FRAMES_DIR}" -name 'f-*.png' | wc -l)"
  require_es_alive "after the recording script"

  if [[ -e /tmp/record.grabfail ]]; then
    echo "ERROR: the capture loop aborted after ${frame_count} frames." >&2
    echo "  Encoding anyway would time the GIF from a full-length take's" >&2
    echo "  elapsed seconds over a partial frame count." >&2
    exit 1
  fi

  if (( frame_count < 2 )); then
    echo "ERROR: captured ${frame_count} frames — nothing to encode" >&2
    exit 1
  fi

  # The GIF delay comes from the MEASURED elapsed time, not from RECORD_FPS.
  # If the harness under-delivers (slower host, larger resolution) a delay
  # derived from the requested rate plays the GIF faster than the theme
  # actually moves. Measuring keeps playback truthful and puts the shortfall
  # in the log instead of silently inside the artifact.
  elapsed="$(awk -v a="${record_start}" -v b="${record_end}" 'BEGIN{printf "%.3f", b-a}')"
  actual_fps="$(awk -v n="${frame_count}" -v e="${elapsed}" 'BEGIN{printf "%.2f", n/e}')"
  delay_cs="$(awk -v n="${frame_count}" -v e="${elapsed}" 'BEGIN{d=100*e/n; printf "%d", (d<1?1:d+0.5)}')"
  echo "captured ${frame_count} frames in ${elapsed}s = ${actual_fps}fps (requested ${RECORD_FPS}); GIF delay ${delay_cs}cs" >&2

  convert -delay "${delay_cs}" -loop 0 "${FRAMES_DIR}"/f-*.png \
          -resize "${RECORD_WIDTH}" -colors "${RECORD_COLORS}" \
          -layers OptimizeTransparency \
          "/harness-out/${OUTNAME}"

  # Copied out only when asked, and only ever ADDING files — nothing under the
  # caller's --out directory is removed.
  if (( KEEP_FRAMES >= 1 )); then
    mkdir -p /harness-out/frames
    cp "${FRAMES_DIR}"/f-*.png /harness-out/frames/
    echo "kept ${frame_count} frames in /harness-out/frames" >&2
  fi

  kill "${ES_PID}" 2>/dev/null || true
  kill "${XVFB_PID}" 2>/dev/null || true
  echo "recorded ${VIEW} @ ${RESOLUTION} -> /harness-out/${OUTNAME}"
  exit 0
fi

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
