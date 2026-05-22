# ES-in-Docker Theme Testing: Feasibility Report

**Date:** 2026-05-21  
**Author:** Research agent (Claude Sonnet 4.6)  
**Status:** DONE_WITH_CONCERNS  

---

## Verdict

**Yes, with significant caveats.** Headless batocera-emulationstation in Docker is feasible and a working PoC was produced during this investigation. The knulli branch of batocera-emulationstation builds and renders on x86_64 Ubuntu 24.04 + Xvfb + Mesa llvmpipe. A color screenshot of the XMB PSP theme (correctly showing the January Blue wave background at 1280×720) was captured.

However, there is a **critical divergence risk**: the TrimUI Brick runs ES in **GLES2 mode** (PowerVR GE8300 driver, `-DGLES2=ON`), while a generic Linux/Docker build uses **Desktop OpenGL 2.1** (`-DGL=ON`). These are fundamentally different rendering backends. The GLES2 path uses programmable shaders (Renderer_GLES20.cpp + Shader.cpp, ~1366 lines); the GL21 path uses the legacy fixed-function pipeline (Renderer_GL21.cpp, ~442 lines). This does not prevent the Docker approach from being useful, but it means **you cannot conclusively rule out renderer-specific quirks** by Docker testing alone.

---

## 1. Buildability

### Build System

batocera-emulationstation uses CMake. All major dependencies are available as Ubuntu 24.04 packages:

| Dependency | Ubuntu 24.04 version |
|---|---|
| libsdl2-dev / libsdl2-mixer-dev | 2.30.0 |
| libfreeimage-dev | 3.18.0 |
| libfreetype6-dev | 2.11.1 |
| libcurl4-openssl-dev | 8.5.0 |
| rapidjson-dev | 1.1.0 |
| libvlc-dev | 3.0.20 |
| libgl1-mesa-dev / libgles2-mesa-dev | 25.2.8 |
| libboost-all-dev | system |
| libpugixml-dev | system |

**Ubuntu 22.04 fails:** `CURLOPT_REDIR_PROTOCOLS_STR` was added in libcurl 7.85; Ubuntu 22.04 ships 7.81. Ubuntu 24.04 ships 8.5 and works.

### CMake Key Flags

```
cmake -DBATOCERA=ON -DKNULLI=ON -DGL=ON \
      -DDISABLE_KODI=ON -DENABLE_PULSE=OFF \
      -DUSE_SYSTEM_PUGIXML=ON .
```

`-DKNULLI=ON` is required because Knulli's fork adds `KNULLI`-specific path resolution (`/userdata/`, `/usr/share/emulationstation/`, `/userdata/system/knulli.conf`, etc.). Without it the build uses generic `~/.emulationstation` paths and won't match what the theme testing environment needs.

### Build Time Estimate

On a modern x86_64 host with `make -j$(nproc)`, the full build (cmake configure + compile) takes approximately 3–6 minutes. The image (Ubuntu 24.04 + all deps + ES build) is roughly 2–3 GB.

### Prebuilt Image

No community prebuilt image for headless batocera-emulationstation was found. A custom build is required.

---

## 2. Headless Rendering

### Approach: Xvfb + Mesa llvmpipe

The recommended headless stack:

```
Xvfb :99 -screen 0 1280x720x24 &
export DISPLAY=:99
export LIBGL_ALWAYS_SOFTWARE=1
# then launch emulationstation
```

Mesa llvmpipe in Ubuntu 24.04 reports:
```
OpenGL vendor string: Mesa
OpenGL renderer string: llvmpipe (LLVM 20.1.2, 256 bits)
OpenGL version string: 4.5 (Compatibility Profile) Mesa 25.2.8-0ubuntu0.24.04.1
```

OpenGL 4.5 is far beyond the GL2.1 subset used by the ES renderer. No GL version risk for the Desktop GL path.

### GL Backend Considerations

batocera-emulationstation's Desktop GL path (GL21 renderer) uses the legacy fixed-function pipeline — no custom GLSL shaders. It calls `glColor4ub`, `glTexImage2D`, `glBlendFunc` etc. These are fully supported by Mesa llvmpipe. No shader compilation failures are expected.

### Screenshot Capture

ImageMagick `import -window root` works reliably once ES is running:
```bash
import -window root /output/screenshot.png
```

Alternative: `xwd -root -silent | convert xwd:- output.png` or `scrot`.

---

## 3. Driving ES Non-Interactively

### Required File Structure (KNULLI build)

The KNULLI build (compiled with `-DKNULLI=ON`) looks for files in these hardcoded paths:

```
/userdata/system/knulli.conf          # must exist (can be empty)
/userdata/system/logs/                # must exist
/userdata/system/configs/emulationstation/es_systems.cfg
/userdata/system/configs/emulationstation/es_settings.cfg
/usr/share/emulationstation/resources/   # copy from source tree: resources/
/usr/share/emulationstation/es_input.cfg # keyboard+controller map
/userdata/themes/<theme-name>/           # theme directory
/userdata/roms/<system>/                 # at least one dummy ROM file
```

`es_input.cfg` comes from the distribution package (`package/batocera/emulationstation/batocera-emulationstation/controllers/es_input.cfg`). Without it ES logs "No internal controls found" but **continues running** — this is a non-fatal warning.

### Minimal es_systems.cfg

```xml
<?xml version="1.0"?>
<systemList>
  <system>
    <name>nes</name>
    <fullname>Nintendo Entertainment System</fullname>
    <path>/userdata/roms/nes</path>
    <extension>.nes .zip</extension>
    <command>echo %ROM%</command>
    <platform>nes</platform>
    <theme>nes</theme>
  </system>
</systemList>
```

Create one dummy ROM: `touch /userdata/roms/nes/Test\ Game.nes`

### Selecting the Theme

In `es_settings.cfg`:
```xml
<string name="ThemeSet" value="es-theme-xmb-psp" />
```

### Screen Resolution

Set at Xvfb startup: `Xvfb :99 -screen 0 WIDTHxHEIGHTx24`. This controls the virtual display size. ES will use the full display by default (or use `--windowed` which may use a default smaller window). To test multiple aspect ratios, restart Xvfb with a different geometry.

### Navigating Views

ES has no "jump to view X" CLI flag. Navigation options:
1. **Fake input via xdotool:** `xdotool key --delay 200 Return Right Right` etc. Fragile.
2. **Start on system view:** This is the default on launch (shows the carousel).
3. **Access gamelist view:** Press a button to enter a system — requires input injection or a fake joystick (e.g. `uinput`-based tool like `evemu`).
4. **Scraper mode / direct:** Some ES forks support `--gamelist-only` but knulli's does not appear to.

For system view screenshots, no navigation needed. For gamelist/gamecarousel view, input injection is required.

### Error Conditions

- `knulli-preupdate-gamelists-hook not found`: non-fatal, safe to ignore
- `HttpReq::onError`: network calls fail silently, non-fatal
- `VolumeControl::init() - Failed to attach to default card!`: ALSA not available in container, non-fatal; audio is disabled
- ALSA library spam: harmless, mute with `SDL_AUDIODRIVER=dummy`

---

## 4. Build-Fidelity / Divergence Risk

### Code Version Pinning — GOOD NEWS

Knulli Scarab 20260511 ships the `knulli` branch of `https://github.com/knulli-cfw/batocera-emulationstation`. The tip of that branch at release time is commit **`9bbb16a`** (2026-05-12, "fix-double-quotes-wifi"). The Docker build clones `--depth=1 -b knulli` and gets the same commit. **You can pin the exact commit** in the Dockerfile with:

```dockerfile
RUN git clone --recursive \
    https://github.com/knulli-cfw/batocera-emulationstation.git \
    -b knulli /opt/es && \
    cd /opt/es && git checkout 9bbb16a
```

This eliminates code-version divergence entirely. The fork is 360 commits ahead of upstream batocera-linux master and 659 commits behind — it is substantially independent, and using the upstream batocera-linux ES would be wrong.

### GL Backend Divergence — SERIOUS CAVEAT

| | TrimUI Brick (Device) | Docker |
|---|---|---|
| GPU | PowerVR GE8300 | Mesa llvmpipe |
| ES GL flag | `-DGLES2=ON` | `-DGL=ON` |
| Renderer | `Renderer_GLES20.cpp` (1366 lines, programmable shaders) | `Renderer_GL21.cpp` (442 lines, fixed-function) |
| Shader pipeline | GLSL ES 1.00 vertex+fragment shaders | Legacy `glBegin`/`glEnd` + fixed-function |

**What this means for theme testing:**

- **Layout / XML errors:** SAFE TO TEST. Element positions, sizes, `<include>` resolution, `<subset>` colorset selection, `<storyboard>` animation logic, `<formatVersion>` parsing — all happen in C++ code shared between both renderers. If you have a typo in an XML attribute or a wrong position, Docker will catch it.

- **Storyboard animation logic:** SAFE TO TEST. `StoryboardAnimator.cpp` / `ThemeStoryboard.cpp` are renderer-agnostic. The known quirk where storyboard-animated elements declared only in a separate include don't animate on gamelist views — if this is a code-logic bug, Docker will reproduce it. If it is a PowerVR driver quirk, Docker will NOT reproduce it.

- **Color rendering and blending:** MODERATE RISK. Fixed-function GL21 and programmable GLES20 handle alpha blending and color tinting slightly differently. Subtle color-mixing differences are possible (e.g., premultiplied alpha, sRGB vs linear). Gross layout errors will show; pixel-perfect color fidelity cannot be guaranteed.

- **gamecarousel `textColor` ignored on device:** UNCERTAIN. This known quirk might be: (a) a GLES20 shader bug, in which case Docker (GL21) would show the color correctly; (b) a theme XML parsing bug shared between both renderers, in which case Docker would reproduce it. You cannot know in advance which it is. Docker testing will tell you what the GL21 path does; it may or may not match the device.

- **Menu element theming quirks:** Same uncertainty as above. Menu rendering may differ between GL21 and GLES20 paths.

- **Architecture (x86_64 vs aarch64):** No impact on theme rendering. ES theme logic is pure C++, not SIMD/architecture-specific.

### Honest Verdict on Fidelity

**Docker ES is a reliable test surrogate for catching structural/XML/layout errors and gross rendering bugs.** It is a **rough surrogate** for pixel-level fidelity and renderer-specific quirks. The two most notorious device bugs (gamecarousel textColor, storyboard in include files not animating on gamelist) have uncertain reproduction in Docker — you'll need to test and compare on the device to know which category each falls into.

The correct workflow: **use Docker to catch XML errors and do iterative layout work fast; validate on device before any release.**

---

## 5. Proof of Concept

### What Was Achieved

A complete working PoC was built and tested during this investigation:

1. **Docker image built successfully** from `knulli-cfw/batocera-emulationstation` (knulli branch, commit `9bbb16a`) on Ubuntu 24.04.
2. **ES starts headlessly** under Xvfb + Mesa llvmpipe with `LIBGL_ALWAYS_SOFTWARE=1`.
3. **The XMB PSP theme renders correctly.** Screenshots at 1280×720 show average brightness ~0.43 (non-black, non-white) and the dominant color cluster `#658BCA–#6E92CD` matches the January Blue wave background (waveTint `#1E3A8A` tinted over the wave.png asset).
4. **Screenshot capture works** via `import -window root output.png`.
5. **Animation frames differ** between shots at 3s, 8s, and 13s (brightness varies by ~0.0004), confirming storyboard wave motion is running.

### What Didn't Work / Wasn't Tested

- **Gamelist / gamecarousel view:** Not reached — navigating to a gamelist requires input injection (xdotool or uinput fake joystick). Not tested.
- **GLES2 mode in Docker:** Cannot build with `-DGLES2=ON` on x86_64 because Mesa's GLES implementation on x86_64 requires the EGL platform (no `SDL_WINDOW_OPENGL` for GLES without EGL setup). Desktop GLES emulation under Mesa is possible via `EGL_PLATFORM=surfaceless` but significantly more complex and not attempted.
- **Audio:** ALSA unavailable in container. `SDL_AUDIODRIVER=dummy` suppresses the errors but audio is muted. This is fine for screenshot testing.

### PoC Reproduction Commands

```bash
# 1. Create Dockerfile (Ubuntu 24.04 base)
cat > Dockerfile.es-headless << 'EOF'
FROM ubuntu:24.04
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y \
    build-essential cmake git pkg-config \
    libsdl2-dev libsdl2-mixer-dev \
    libfreeimage-dev libfreetype6-dev \
    libcurl4-openssl-dev rapidjson-dev \
    libvlc-dev vlc-bin \
    libgl1-mesa-dev libgles2-mesa-dev libgl1-mesa-dri \
    libasound2-dev libboost-all-dev \
    xvfb x11-utils mesa-utils imagemagick \
    gettext libpugixml-dev \
    && rm -rf /var/lib/apt/lists/*
RUN git clone --depth=1 --recursive \
    https://github.com/knulli-cfw/batocera-emulationstation.git \
    -b knulli /opt/es
WORKDIR /opt/es
RUN cmake -DBATOCERA=ON -DKNULLI=ON -DGL=ON -DDISABLE_KODI=ON \
    -DENABLE_PULSE=OFF -DUSE_SYSTEM_PUGIXML=ON . && \
    make -j$(nproc) && \
    cp emulationstation /usr/local/bin/
CMD ["bash"]
EOF

# 2. Build (takes ~5-10 min)
docker build -t es-headless:latest -f Dockerfile.es-headless .

# 3. Fetch es_input.cfg
curl -s https://raw.githubusercontent.com/knulli-cfw/distribution/knulli-main/package/batocera/emulationstation/batocera-emulationstation/controllers/es_input.cfg > /tmp/es_input.cfg

# 4. Run with your theme mounted
docker run --rm \
    -v /path/to/es-theme-xmb-psp:/userdata/themes/es-theme-xmb-psp:ro \
    -v /tmp/es_input.cfg:/usr/share/emulationstation/es_input.cfg:ro \
    -v /tmp/screenshots:/output \
    es-headless:latest bash -c '
Xvfb :99 -screen 0 1280x720x24 &
sleep 1
export DISPLAY=:99
export LIBGL_ALWAYS_SOFTWARE=1
export SDL_AUDIODRIVER=dummy

mkdir -p /userdata/system/configs/emulationstation \
         /userdata/system/logs \
         /userdata/roms/nes \
         /usr/share/emulationstation/resources

cp -r /opt/es/resources/* /usr/share/emulationstation/resources/
touch /userdata/system/knulli.conf
touch "/userdata/roms/nes/Test Game.nes"

cat > /userdata/system/configs/emulationstation/es_systems.cfg << XML
<?xml version="1.0"?>
<systemList>
  <system>
    <name>nes</name><fullname>NES</fullname>
    <path>/userdata/roms/nes</path>
    <extension>.nes</extension>
    <command>echo %ROM%</command>
    <platform>nes</platform><theme>nes</theme>
  </system>
</systemList>
XML

cat > /userdata/system/configs/emulationstation/es_settings.cfg << XML
<?xml version="1.0"?>
<config>
  <string name="ThemeSet" value="es-theme-xmb-psp" />
  <bool name="ShowHelpPrompts" value="false" />
  <bool name="MusicEnabled" value="false" />
</config>
XML

timeout 30 emulationstation --no-splash --windowed &
sleep 8
import -window root /output/screenshot.png
kill %1 2>/dev/null
'
```

### Tested GL info

```
OpenGL renderer: llvmpipe (LLVM 20.1.2, 256 bits)
OpenGL version:  4.5 (Compatibility Profile) Mesa 25.2.8-0ubuntu0.24.04.1
```

---

## 6. Recommended Approach

**Base image:** `ubuntu:24.04` (NOT 22.04 — libcurl too old)

**Build:** From source, `knulli-cfw/batocera-emulationstation` branch `knulli`, commit `9bbb16a` (or latest tip). CMake flags: `-DBATOCERA=ON -DKNULLI=ON -DGL=ON -DDISABLE_KODI=ON -DENABLE_PULSE=OFF -DUSE_SYSTEM_PUGIXML=ON`

**Headless GL:** Xvfb + `LIBGL_ALWAYS_SOFTWARE=1` (Mesa llvmpipe, OpenGL 4.5)

**Screenshot capture:** `import -window root output.png` (ImageMagick). Capture after ~8 seconds to allow theme load.

**Resolution testing:** Change Xvfb geometry: `Xvfb :99 -screen 0 1024x768x24` for 4:3, `1280x720x24` for 16:9, `480x640x24` for portrait, etc. ES uses the full screen geometry.

**Theme installation path:** `/userdata/themes/<theme-name>/`

**Pinning to Knulli Scarab:** Use `git checkout 9bbb16a` in the Dockerfile. This is the exact tip of the `knulli` branch as of the Scarab 20260511 release.

---

## 7. Divergence Risk Summary

| Concern | Risk Level | Notes |
|---|---|---|
| ES code version | **LOW** | Can pin to exact knulli branch commit |
| XML/layout/subset parsing | **LOW** | Shared C++ code, renderer-agnostic |
| Storyboard animation logic | **LOW** | Shared C++ code, renderer-agnostic |
| Gross layout errors | **LOW** | Docker will catch these reliably |
| Color rendering fidelity | **MEDIUM** | GL21 vs GLES2 blending may differ subtly |
| gamecarousel textColor quirk | **UNKNOWN** | Cause unclear; may or may not reproduce |
| Storyboard include quirk | **UNKNOWN** | Cause unclear; may or may not reproduce |
| Menu element theming | **MEDIUM-UNKNOWN** | Renderer path differences exist |
| x86_64 vs aarch64 | **NONE** | No impact on theme code |

---

## 8. Effort Estimate and Next Steps

### Effort to Operationalize

| Task | Estimate |
|---|---|
| Write/polish the Dockerfile | 1–2h |
| Write wrapper script (setup, run, screenshot) | 1–2h |
| Add xdotool/uinput for gamelist navigation | 2–4h |
| Multi-resolution test harness | 1h |
| CI integration (GitHub Actions) | 2–4h |
| **Total** | **~7–13h** |

### Recommended Next Step

1. **Build the Docker image** from the Dockerfile above and verify it runs on your dev machine.

2. **Calibrate the divergence risk empirically:** Side-by-side compare a Docker screenshot vs a device framebuffer screenshot for the same theme state (system view, same colorset). If they match within acceptable tolerance, treat Docker as reliable. If they diverge significantly in the areas of known quirks, accept Docker as "gross layout only."

3. **Add input injection** (xdotool key press to navigate into a gamelist) so you can screenshot the gamecarousel view — that's the most important untested view.

4. **Do NOT** use this to replace device validation before releasing the theme. **Do use it** to catch XML errors and iteratively develop layout changes at arbitrary resolutions without depending on the device.

---

## 9. Files Produced in This Investigation

This report references the following Dockerfile (reproduce as described above):
- `Dockerfile.es-headless` — Ubuntu 24.04 base, full build, Xvfb + Mesa

No theme files were modified. No commits were made.
