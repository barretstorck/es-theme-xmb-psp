# ES Docker Test Harness — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a local developer harness that renders `es-theme-xmb-psp` by running batocera-emulationstation headless in Docker, capturing screenshots without the physical device, at arbitrary resolutions.

**Architecture:** A build-once cached Docker image (Ubuntu 24.04 + the pinned Knulli ES build + Xvfb/Mesa/ImageMagick/xdotool) plus two scripts: `scripts/render.sh` (host entry point — parses flags, builds the image if missing, runs a throwaway container, copies the PNG out) and `docker/run-in-container.sh` (the in-container routine — starts Xvfb, writes ES config, launches ES, navigates, screenshots). The harness is a development aid, not a release gate (it renders via desktop GL21, the device via GLES2).

**Tech Stack:** Docker, bash, batocera-emulationstation (CMake/C++), Xvfb + Mesa software GL, ImageMagick, xdotool.

**Spec:** `docs/superpowers/specs/2026-05-21-es-docker-test-harness-design.md`

**Branch:** `es-docker-harness` (already created off `main`; contains the spec commit `88c706c`).

---

## Operating notes for the implementer

- **Working directory:** the repo root (here, `/tmp/es-theme-xmb-psp`). All paths are relative to it. Branch `es-docker-harness` is checked out — do NOT switch branches.
- **Docker** is available (`docker` CLI, x86_64 host). The image build is slow (~5–10 min) and large (~2–3 GB) but one-time and cached. A research-phase image `es-headless:latest` may exist from the feasibility PoC — ignore it; this plan builds its own tagged image.
- **No automated test framework.** Each task is verified functionally: the image builds, the harness runs, and the captured PNG is inspected with the Read tool (it renders images). "Verify" steps mean: run the command, Read the output PNG, confirm it shows what is expected.
- **`.env.local`** at the repo root is gitignored and holds device + NAS credentials. The NAS credentials (`NAS_HOST`, `NAS_USER`, `NAS_PASS`) are already present for Task 3. NEVER print the NAS password or commit it.
- **Frequent commits:** one commit per task, message prefixed `harness:`, ending with the `Co-Authored-By` trailer shown in each task.
- **No pushing.** All commits and the final merge are local.
- **Genuine unknowns are expected** in Tasks 2 and 4 (ES config-key formats, xdotool navigation timing). The plan gives concrete starting points and a verify-then-tune loop, the same way earlier theme spikes were handled. When a config key is unknown, the ES source is in the image at `/opt/es` — grep it for the authoritative answer.

---

## Task 1: The Docker image

Build the batocera-emulationstation Docker image, pinned to the Knulli Scarab ES commit.

**Files:**
- Create: `docker/Dockerfile`

- [ ] **Step 1: Write `docker/Dockerfile`**

```dockerfile
# Headless batocera-emulationstation for es-theme-xmb-psp theme testing.
# Renders via desktop GL21 (Mesa software) — a dev aid, NOT a release gate.
FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

# Build deps for batocera-emulationstation + headless render/screenshot tools.
RUN apt-get update && apt-get install -y --no-install-recommends \
      build-essential cmake git pkg-config ca-certificates curl \
      libsdl2-dev libsdl2-mixer-dev \
      libfreeimage-dev libfreetype6-dev \
      libcurl4-openssl-dev rapidjson-dev \
      libvlc-dev vlc-bin \
      libgl1-mesa-dev libgles2-mesa-dev libgl1-mesa-dri \
      libasound2-dev libboost-all-dev libpugixml-dev gettext \
      xvfb x11-utils mesa-utils imagemagick xdotool \
    && rm -rf /var/lib/apt/lists/*

# Pinned Knulli batocera-emulationstation commit (Knulli Scarab 2026-05-11).
ARG ES_PIN=9bbb16a
RUN git clone --recursive \
      https://github.com/knulli-cfw/batocera-emulationstation.git /opt/es \
    && git -C /opt/es checkout "${ES_PIN}" \
    && git -C /opt/es submodule update --init --recursive

WORKDIR /opt/es
RUN cmake -DBATOCERA=ON -DKNULLI=ON -DGL=ON -DDISABLE_KODI=ON \
          -DENABLE_PULSE=OFF -DUSE_SYSTEM_PUGIXML=ON . \
    && make -j"$(nproc)" \
    && cp emulationstation /usr/local/bin/emulationstation

# es_input.cfg (keyboard + controller map) so injected keystrokes drive ES.
RUN mkdir -p /usr/share/emulationstation \
    && curl -fsSL -o /usr/share/emulationstation/es_input.cfg \
       https://raw.githubusercontent.com/knulli-cfw/distribution/knulli-main/package/batocera/emulationstation/batocera-emulationstation/controllers/es_input.cfg \
    || echo "WARNING: es_input.cfg fetch failed; Task 4 will supply a keyboard map"

CMD ["bash"]
```

- [ ] **Step 2: Build the image**

Run:
```bash
docker build -t es-xmb-harness:knulli-9bbb16a ./docker
```
Expected: build succeeds (~5–10 min). If `cmake` fails on a missing dependency, add the dependency to the `apt-get install` list and rebuild. If the `git checkout 9bbb16a` fails (commit not found), the branch history changed — use `git -C /opt/es log` to find the commit, or fall back to the `knulli` branch tip and note it in the commit message.

- [ ] **Step 3: Verify the ES binary and resources exist in the image**

Run:
```bash
docker run --rm es-xmb-harness:knulli-9bbb16a bash -c \
  'test -x /usr/local/bin/emulationstation && test -d /opt/es/resources && echo IMAGE_OK'
```
Expected: prints `IMAGE_OK`.

- [ ] **Step 4: Commit**

```bash
git add docker/Dockerfile
git commit -m "$(cat <<'EOF'
harness: Knulli batocera-emulationstation Docker image

Ubuntu 24.04 base; builds batocera-emulationstation (knulli branch,
pinned commit 9bbb16a) with the desktop-GL CMake flags, plus the headless
render/screenshot toolchain (Xvfb, Mesa, ImageMagick, xdotool).

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 2: The render script — system view

Create the host entry script and the in-container routine, supporting the `system` view at arbitrary resolution and colorset. No game library is needed for the system view.

**Files:**
- Create: `scripts/render.sh`
- Create: `docker/run-in-container.sh`

- [ ] **Step 1: Write `docker/run-in-container.sh`**

This runs inside the container. It reads env vars (`VIEW`, `RESOLUTION`, `COLORSET`, `OUTNAME`, `HAS_LIBRARY`), sets ES up, renders, and screenshots. For Task 2 it handles `VIEW=system`; Task 4 extends it.

```bash
#!/usr/bin/env bash
# Runs INSIDE the harness container. Starts Xvfb, configures ES, launches it,
# captures a screenshot of the requested view to /harness-out/$OUTNAME.
set -euo pipefail

VIEW="${VIEW:-system}"
RESOLUTION="${RESOLUTION:-1024x768}"
COLORSET="${COLORSET:-January Blue}"
OUTNAME="${OUTNAME:-render.png}"
HAS_LIBRARY="${HAS_LIBRARY:-0}"

THEME_DIR="/userdata/themes/es-theme-xmb-psp"
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
# ThemeSet selects the theme. The colorset subset key is build-specific:
# Task 2 writes a best-guess key; if the colorset does not apply, grep the ES
# source at /opt/es for how theme subset selections are persisted and correct
# the key name here.
cat > "${ES_CFG}/es_settings.cfg" <<XML
<?xml version="1.0"?>
<config>
  <string name="ThemeSet" value="es-theme-xmb-psp" />
  <string name="subset.es-theme-xmb-psp.colorset" value="${COLORSET}" />
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
  *) echo "VIEW=${VIEW} not supported yet (Task 4)"; ;;
esac
sleep 1

# --- screenshot ---
import -window root "/harness-out/${OUTNAME}"

kill "${ES_PID}" 2>/dev/null || true
kill "${XVFB_PID}" 2>/dev/null || true
echo "rendered ${VIEW} @ ${RESOLUTION} -> /harness-out/${OUTNAME}"
```

- [ ] **Step 2: Make `run-in-container.sh` executable**

Run: `chmod +x docker/run-in-container.sh`

- [ ] **Step 3: Write `scripts/render.sh`**

```bash
#!/usr/bin/env bash
# render.sh — render es-theme-xmb-psp via headless batocera-emulationstation in
# Docker and capture a screenshot. A development aid, NOT a release gate: this
# renders via desktop GL21, the device via GLES2. See docker/README.md.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Pinned Knulli batocera-emulationstation commit (must match docker/Dockerfile).
ES_PIN="9bbb16a"
IMAGE="es-xmb-harness:knulli-${ES_PIN}"

VIEW="system"
RESOLUTION="1024x768"
COLORSET="January Blue"
LIBRARY=""
OUT="${REPO_ROOT}/.dev/render.png"

usage() {
  cat <<EOF
Usage: render.sh [--view V] [--resolution WxH] [--colorset NAME]
                 [--library PATH] [--out FILE]

  --view        system | gamelist | gamecarousel | menu   (default: system)
  --resolution  Xvfb geometry, e.g. 1024x768 (4:3) or 1280x720 (16:9)
  --colorset    PSP colorset name, e.g. "August Orange"   (default: January Blue)
  --library     path to a Knulli userdata-shaped library  (gamelist views need this)
  --out         host path for the captured PNG            (default: .dev/render.png)
EOF
  exit "${1:-0}"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --view)       VIEW="${2:?}"; shift 2 ;;
    --resolution) RESOLUTION="${2:?}"; shift 2 ;;
    --colorset)   COLORSET="${2:?}"; shift 2 ;;
    --library)    LIBRARY="${2:?}"; shift 2 ;;
    --out)        OUT="${2:?}"; shift 2 ;;
    -h|--help)    usage 0 ;;
    *) echo "unknown argument: $1" >&2; usage 1 ;;
  esac
done

case "${VIEW}" in
  system|gamelist|gamecarousel|menu) ;;
  *) echo "bad --view: ${VIEW}" >&2; exit 2 ;;
esac
if [[ "${VIEW}" == gamelist || "${VIEW}" == gamecarousel ]] && [[ -z "${LIBRARY}" ]]; then
  echo "--library is required for --view ${VIEW}" >&2; exit 2
fi
if [[ ! "${RESOLUTION}" =~ ^[0-9]+x[0-9]+$ ]]; then
  echo "bad --resolution: ${RESOLUTION} (expected WxH)" >&2; exit 2
fi

# Build the image on first use.
if ! docker image inspect "${IMAGE}" >/dev/null 2>&1; then
  echo "Building ${IMAGE} (one-time, ~5-10 min)..."
  docker build -t "${IMAGE}" --build-arg ES_PIN="${ES_PIN}" "${REPO_ROOT}/docker"
fi

mkdir -p "$(dirname "${OUT}")"
OUTDIR="$(cd "$(dirname "${OUT}")" && pwd)"
OUTNAME="$(basename "${OUT}")"

HAS_LIBRARY=0
DOCKER_ARGS=(
  --rm
  -v "${REPO_ROOT}:/userdata/themes/es-theme-xmb-psp:ro"
  -v "${OUTDIR}:/harness-out"
)
if [[ -n "${LIBRARY}" ]]; then
  LIBRARY_ABS="$(cd "${LIBRARY}" && pwd)"
  DOCKER_ARGS+=( -v "${LIBRARY_ABS}:/harness-library:ro" )
  HAS_LIBRARY=1
fi
DOCKER_ARGS+=(
  -e VIEW="${VIEW}" -e RESOLUTION="${RESOLUTION}" -e COLORSET="${COLORSET}"
  -e OUTNAME="${OUTNAME}" -e HAS_LIBRARY="${HAS_LIBRARY}"
)

docker run "${DOCKER_ARGS[@]}" "${IMAGE}" \
  bash /userdata/themes/es-theme-xmb-psp/docker/run-in-container.sh

echo "Saved ${OUT}"
```

- [ ] **Step 4: Make `render.sh` executable**

Run: `chmod +x scripts/render.sh`

- [ ] **Step 5: Render the system view and verify**

Run: `./scripts/render.sh --view system --out .dev/render-system.png`
Then Read `.dev/render-system.png`.
Expected: the PSP XMB theme's system view — the dark wave background (January Blue tint), the system carousel. If the screen is black, check `/tmp/es.log` (re-run with `docker run ... bash` interactively) — common causes: theme not found, ES crashed. Tune the `sleep 10` in `run-in-container.sh` upward if the theme had not finished loading.

- [ ] **Step 6: Verify the resolution flag**

Run: `./scripts/render.sh --view system --resolution 1280x720 --out .dev/render-16x9.png`
Then Read `.dev/render-16x9.png`.
Expected: a 1280×720 image (16:9) of the system view. This proves the aspect-ratio knob.

- [ ] **Step 7: Verify the colorset flag**

Run: `./scripts/render.sh --view system --colorset "August Orange" --out .dev/render-orange.png`
Then Read `.dev/render-orange.png`.
Expected: the system view with an orange wave tint instead of blue. **If the colorset did NOT change**, the `subset.es-theme-xmb-psp.colorset` key in `run-in-container.sh` is wrong for this build. Grep the ES source for the correct persisted-subset key: `docker run --rm es-xmb-harness:knulli-9bbb16a grep -rn "subset" /opt/es/es-app/src /opt/es/es-core/src | grep -i setting` — find how theme subset selections are written to `es_settings.cfg`, correct the key in `run-in-container.sh`, and re-test. As a fallback, the colorset can be left at the theme default (January Blue) and `--colorset` documented as best-effort; but attempt the key discovery first.

- [ ] **Step 8: Commit**

```bash
git add scripts/render.sh docker/run-in-container.sh
git commit -m "$(cat <<'EOF'
harness: render.sh + in-container routine (system view)

scripts/render.sh runs a throwaway container that renders the theme's
system view headless and captures a screenshot; --resolution sets the
Xvfb geometry and --colorset selects a PSP colorset.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 3: Acquire a test library from the NAS

Pull a small real Knulli game library subset from the NAS Samba share into the gitignored `.dev/library/`, for rendering the gamelist views.

**Files:**
- Create: `.dev/library/` (gitignored content — not committed)

- [ ] **Step 1: Confirm NAS credentials are available**

The repo-root `.env.local` (gitignored) contains `NAS_HOST`, `NAS_USER`, `NAS_PASS`. Confirm:
```bash
set -a && source .env.local && set +a && echo "NAS_HOST=${NAS_HOST} NAS_USER=${NAS_USER} NAS_PASS=${NAS_PASS:+SET}"
```
Expected: `NAS_HOST` and `NAS_USER` print, `NAS_PASS` shows `SET`. Never print the password itself.

- [ ] **Step 2: List the NAS shares and locate the game library**

Install an SMB client if needed (`apt-get install -y smbclient` or use the harness image which can be extended). List shares:
```bash
smbclient -L "//${NAS_HOST}" -U "${NAS_USER}%${NAS_PASS}" -g 2>/dev/null
```
Then browse to find the Knulli library — a tree with per-system directories (`roms/<system>/`) each containing game files, a `gamelist.xml`, and scraped media. The systems seen on the device include `ports` (DOOM, MrBoom, SdlPop) and `pcengine`. Identify the share and path holding these.

- [ ] **Step 3: Copy a subset into `.dev/library/`**

Create `.dev/library/` and copy **two or three systems** (~10 games total) with their `gamelist.xml` and scraped media. Choose systems so that at least one game **has no scraped thumbnail** (to exercise the gamecarousel text fallback) and several **do** have boxart. Example using `smbclient` recursive get, or mount with `mount -t cifs` if available:
```bash
mkdir -p .dev/library
# per system, e.g. ports and pcengine:
smbclient "//${NAS_HOST}/<share>" -U "${NAS_USER}%${NAS_PASS}" \
  -c 'prompt OFF; recurse ON; lcd .dev/library; cd <path>/roms; mget ports; mget pcengine' 2>/dev/null
```
Adjust share/path names to what Step 2 found. Keep the total under a few hundred MB.

- [ ] **Step 4: Verify the library shape**

Run:
```bash
find .dev/library -maxdepth 2 -type d | head -20
find .dev/library -name 'gamelist.xml'
```
Expected: per-system directories, each with a `gamelist.xml`. Open one `gamelist.xml` and confirm it references game files and media paths, and that at least one `<game>` has no `<thumbnail>`.

- [ ] **Step 5: No commit**

`.dev/library/` is gitignored content (the ignore rule is added in Task 5) and is NOT committed. This task produces no commit. Report the systems and game count acquired so Task 4 knows what is available.

---

## Task 4: Library mount and the gamelist / gamecarousel / menu views

Extend the harness so it mounts the acquired library and renders the gamelist, gamecarousel, and menu views, navigating via xdotool.

**Files:**
- Modify: `docker/run-in-container.sh`
- Modify: `scripts/render.sh` (only if navigation tuning requires new env vars)

- [ ] **Step 1: Replace the es_systems.cfg / library section of `run-in-container.sh`**

In `docker/run-in-container.sh`, replace the Task-2 `--- es_systems.cfg ---` block (the dummy `snes` system) with library-aware logic: when `HAS_LIBRARY=1`, populate `/userdata/roms` from the mounted library and generate `es_systems.cfg` from the systems present; otherwise keep the dummy system.

```bash
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
    SYSTEMS_XML+="<platform>${sysname}</platform><theme>${sysname}</theme></system>\n"
  done
fi
if [[ -z "${SYSTEMS_XML}" ]]; then
  mkdir -p /userdata/roms/snes && touch /userdata/roms/snes/placeholder.smc
  SYSTEMS_XML="  <system><name>snes</name><fullname>Super Nintendo</fullname><path>/userdata/roms/snes</path><extension>.smc</extension><command>echo %ROM%</command><platform>snes</platform><theme>snes</theme></system>"
fi
printf '<?xml version="1.0"?>\n<systemList>\n%b</systemList>\n' "${SYSTEMS_XML}" \
  > "${ES_CFG}/es_systems.cfg"
```

- [ ] **Step 2: Add the gamelist-view-style setting to es_settings.cfg**

In `run-in-container.sh`, the `es_settings.cfg` heredoc selects the gamelist view style based on `VIEW`. Add a line so `VIEW=gamecarousel` forces the carousel style and `VIEW=gamelist` forces `detailed`. Compute it before the heredoc and insert it:

```bash
# Gamelist view style: gamecarousel view -> the boxart carousel, else detailed.
case "${VIEW}" in
  gamecarousel) GLVIEW="gamecarousel" ;;
  gamelist)     GLVIEW="detailed" ;;
  *)            GLVIEW="automatic" ;;
esac
```
and add inside the `es_settings.cfg` `<config>` block:
```
  <string name="GamelistViewStyle" value="${GLVIEW}" />
```
The exact setting name for the gamelist view style is build-specific. If `gamecarousel` does not take effect, grep the ES source for the gamelist-view-style setting: `docker run --rm es-xmb-harness:knulli-9bbb16a grep -rn -i "viewstyle\|GamelistView" /opt/es/es-app/src` and correct the key. (The theme exposes `detailed` and `gamecarousel` as gamelist views.)

- [ ] **Step 3: Replace the navigation `case` block in `run-in-container.sh`**

Replace the Task-2 `--- navigate to the requested view ---` block with xdotool navigation macros. ES launches on the system carousel; from there:

```bash
# --- navigate to the requested view ---
# ES default keyboard map: arrows = d-pad, Return = confirm/select,
# Esc = back. xdotool sends keystrokes to the Xvfb display.
key() { xdotool key --window "$(xdotool search --name 'EmulationStation' | head -1)" "$1" 2>/dev/null || xdotool key "$1"; sleep "${2:-1}"; }

case "${VIEW}" in
  system)
    : ;;                                   # already on the system carousel
  gamelist|gamecarousel)
    key Return 4 ;;                        # enter the selected system's gamelist
  menu)
    # Open the main menu. The menu key on the ES keyboard map is typically the
    # mapped "start" button; if Return opens a game instead, try F1 / space and
    # confirm against /tmp/es.log + the screenshot.
    key F1 3 ;;
esac
sleep 2
```

This navigation is timing-sensitive — the most fragile part of the harness. The `key` waits and the exact keysyms are tuned in Step 5. If `xdotool search --name 'EmulationStation'` finds no window, ES may title its window differently — use `xdotool search --onlyvisible --class ''` or send keys to the focused display (`xdotool key` with no `--window`).

- [ ] **Step 4: Render the gamecarousel view and verify**

Run:
```bash
./scripts/render.sh --view gamecarousel --library .dev/library --out .dev/render-carousel.png
```
Read `.dev/render-carousel.png`.
Expected: a gamelist screen — the boxart carousel column on the left, the right info panel (title/rating/video/description). If it shows the system carousel instead, navigation did not enter the gamelist — proceed to Step 5.

- [ ] **Step 5: Tune navigation until each view renders**

Iterate on the `key` calls and waits in `run-in-container.sh` until:
- `--view gamelist` shows the detailed text-list gamelist,
- `--view gamecarousel` shows the boxart carousel,
- `--view menu` shows the ES Start menu.

For each, run the corresponding `render.sh` command and Read the PNG. Use `/tmp/es.log` (add `docker run ... bash` interactive debugging if needed) to see what ES did. Adjust keysyms (`Return`, `F1`, `space`, `KP_Enter`), counts, and `sleep` durations. When a view renders correctly, lock in the values. Tuning navigation timing here is expected and is the task's main work.

- [ ] **Step 6: Verify the menu and gamelist views**

Run and Read each:
```bash
./scripts/render.sh --view gamelist --library .dev/library --out .dev/render-gamelist.png
./scripts/render.sh --view menu --out .dev/render-menu.png
```
Expected: `render-gamelist.png` shows the detailed text-list gamelist; `render-menu.png` shows the colorset-themed Start menu.

- [ ] **Step 7: Commit**

```bash
git add docker/run-in-container.sh scripts/render.sh
git commit -m "$(cat <<'EOF'
harness: library mount + gamelist/gamecarousel/menu views

run-in-container.sh now populates es_systems.cfg from a mounted Knulli
library, forces the gamelist view style per --view, and navigates to the
gamelist/gamecarousel/menu views with xdotool. Navigation timing tuned
against rendered screenshots.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 5: Documentation and .gitignore

Document the harness and ensure its artefacts stay untracked.

**Files:**
- Create: `docker/README.md`
- Modify: `.gitignore`

- [ ] **Step 1: Update `.gitignore`**

Read `.gitignore`. Ensure these patterns are present (add any that are missing):
```
.dev/
```
If `.dev/` is already ignored, confirm it covers `.dev/library/` and `.dev/render*.png`. If `.dev/` is only partially ignored (e.g. a specific file), add `.dev/library/` and `.dev/render*.png` explicitly.

- [ ] **Step 2: Write `docker/README.md`**

```markdown
# ES Docker test harness

Renders `es-theme-xmb-psp` by running batocera-emulationstation headless in
Docker, so the theme can be screenshotted without the physical device, at any
resolution.

## ⚠️ Not a release gate

This harness renders via **desktop GL21** (Mesa software rendering). The device
renders via **GLES2** (programmable shaders). The harness reliably catches XML
errors, layout/sizing mistakes, colorset resolution, and storyboard logic — and
is ideal for fast iteration and multi-resolution layout work. It does **not**
guarantee pixel-level colour fidelity, and build-specific device quirks may not
reproduce. **Validate on the device before any release.**

## Usage

    ./scripts/render.sh [--view V] [--resolution WxH] [--colorset NAME] \
                        [--library PATH] [--out FILE]

- `--view` — `system` (default), `gamelist`, `gamecarousel`, or `menu`
- `--resolution` — Xvfb geometry, e.g. `1024x768` (4:3, default) or `1280x720`
- `--colorset` — PSP colorset name, e.g. `"August Orange"`
- `--library` — path to a Knulli `userdata`-shaped library; required for the
  `gamelist` and `gamecarousel` views
- `--out` — host path for the PNG (default `.dev/render.png`)

The first run builds the Docker image (~5–10 min, ~2–3 GB), cached thereafter.

## Test library

`gamelist`/`gamecarousel` views need a real Knulli library — per-system
directories with `gamelist.xml` and scraped media. It is not committed; place
one under `.dev/library/` (gitignored). Acquire a small subset (a few systems,
~10 games, including at least one with no scraped thumbnail) by copying from a
Knulli device or NAS.

## How it works

`scripts/render.sh` builds/caches the image (`docker/Dockerfile` — Knulli
batocera-emulationstation pinned to commit `9bbb16a`), then runs a throwaway
container that executes `docker/run-in-container.sh`: Xvfb + Mesa software GL,
ES config, launch, xdotool navigation, ImageMagick screenshot.
```

- [ ] **Step 3: Verify**

Run `git status --short` — confirm `.dev/` artefacts (`.dev/library/`, `.dev/render*.png`) do NOT appear as untracked. Read `docker/README.md` and confirm it is accurate against the final `render.sh` flags.

- [ ] **Step 4: Commit**

```bash
git add .gitignore docker/README.md
git commit -m "$(cat <<'EOF'
harness: docs + gitignore

docker/README.md documents usage and the GL21-vs-GLES2 divergence caveat
(the harness is a dev aid, not a release gate); .gitignore keeps .dev/
harness artefacts untracked.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 6: Acceptance validation and merge

Run the spec's acceptance checklist, then merge the harness to `main`.

**Files:** none (validation + git only).

- [ ] **Step 1: Run the acceptance checklist**

Run each and Read the PNG, confirming the described result:

| Command | Expected |
|---|---|
| `./scripts/render.sh --view system --out .dev/a1.png` | system view at 1024×768 |
| `./scripts/render.sh --view system --resolution 1280x720 --out .dev/a2.png` | system view at 16:9 |
| `./scripts/render.sh --view gamecarousel --library .dev/library --out .dev/a3.png` | boxart carousel + info panel |
| `./scripts/render.sh --view menu --out .dev/a4.png` | colorset-themed Start menu |
| `./scripts/render.sh --view system --colorset "August Orange" --out .dev/a5.png` | orange-tinted system view |

If any fails, return to the relevant task, fix, and re-run. Do not proceed until all five pass.

- [ ] **Step 2: Final review of the branch**

Review the full `es-docker-harness` branch diff against `main` (`git diff main...es-docker-harness`): `docker/Dockerfile`, `docker/run-in-container.sh`, `docker/README.md`, `scripts/render.sh`, `.gitignore`, and the spec/research docs. Confirm both scripts have a `#!/usr/bin/env bash` shebang and are executable (`git ls-files -s scripts/render.sh docker/run-in-container.sh` shows mode `100755`), no credentials are committed, and `bash -n scripts/render.sh docker/run-in-container.sh` reports no syntax errors. Fix and re-commit anything found.

- [ ] **Step 3: Merge to `main`**

```bash
git checkout main
git merge --no-ff es-docker-harness -m "$(cat <<'EOF'
Merge es-docker-harness into main

Adds a headless batocera-emulationstation Docker harness (scripts/render.sh
+ docker/) for rendering and screenshotting the theme without the physical
device, at arbitrary resolutions.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

- [ ] **Step 4: Report completion**

Confirm to the user: the harness is merged to `main` (local only, not pushed). Note that v0.7 can now resume — its branch `v0.7-gamelist-menu` should merge `main` to pick up the harness, then use `render.sh` to produce v0.7's screenshots and smoke test, and complete v0.7 Tasks 7–8.

---

## Self-review

**Spec coverage:**
- Component 1 (Docker image) → Task 1. ✓
- Component 2 (render script) → Task 2 (core: system view, `--resolution`, `--colorset`, `--out`) + Task 4 (`--library`, other views). ✓
- Component 3 (view navigation) → Task 4 (xdotool macros). ✓
- Component 4 (test library) → Task 3 (acquisition) + Task 4 (mount + es_systems.cfg generation). ✓
- Component 5 (repo layout + docs) → Task 5 (`docker/README.md`, `.gitignore`); files land in `docker/` and `scripts/` throughout. ✓
- Divergence caveat → Task 5 (`docker/README.md`). ✓
- Acceptance / validation → Task 6 Step 1. ✓
- Merge to `main` → Task 6 Step 3. ✓
- v0.7 resumption → Task 6 Step 4 hands off (v0.7 has its own plan; not re-implemented here). ✓

**Placeholder scan:** No "TBD"/"handle errors appropriately". The build-specific unknowns (colorset key in Task 2 Step 7, gamelist-view-style key in Task 4 Step 2, navigation keysyms in Task 4 Step 5) each give a concrete starting value plus an exact discovery command (grep `/opt/es`) and a verify-then-tune loop — they are discovery steps, not placeholders.

**Type/name consistency:** The image tag `es-xmb-harness:knulli-9bbb16a` and the pin `9bbb16a` match across `docker/Dockerfile` (`ARG ES_PIN`), `scripts/render.sh` (`ES_PIN`/`IMAGE`), and `docker/README.md`. Env vars (`VIEW`, `RESOLUTION`, `COLORSET`, `OUTNAME`, `HAS_LIBRARY`) are set identically in `render.sh` and consumed in `run-in-container.sh`. Mount points (`/userdata/themes/es-theme-xmb-psp`, `/harness-out`, `/harness-library`) are consistent between the two scripts. The library path `.dev/library/` is consistent across Tasks 3, 4, 5, 6.
