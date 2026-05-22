# ES Docker Test Harness

**Status:** Design approved 2026-05-21. Implementation pending.

**Builds on:** the feasibility investigation
`docs/superpowers/research/2026-05-21-es-docker-testing-feasibility.md`, which
produced a working proof-of-concept (Knulli `batocera-emulationstation` built
and rendering the theme headless in Docker).

## Goal

Build a local developer harness that renders `es-theme-xmb-psp` by running
batocera-emulationstation **headless in Docker**, so theme layout can be
verified — and screenshots captured — **without the physical device**, at
**arbitrary screen resolutions**.

This removes the hard dependency on the TrimUI Brick (whose SSH became
unreliable mid-iteration) for day-to-day theme work, and provides the
multi-resolution rendering needed to support additional screen aspect ratios
in future.

## Context and constraints

- The theme targets **batocera-emulationstation**, theme `formatVersion 7`,
  on **Knulli Scarab** firmware. The harness must build the *same* ES the
  device runs: the `knulli` branch of `knulli-cfw/batocera-emulationstation`,
  pinned to commit **`9bbb16a`** (the branch tip at the Knulli Scarab
  2026-05-11 release).
- Dev environment: Alpine x86_64 container with Docker available; the device
  is aarch64. Architecture does not affect ES theme rendering (pure C++).
- **Rendering-backend divergence (critical).** The device renders via the
  **GLES2** path (PowerVR, programmable shaders); a Docker build on x86_64
  renders via the **desktop GL21** path (Mesa software rendering,
  fixed-function). The harness is therefore a development aid, **not a release
  gate** — see "Divergence caveat" below.
- No automated test framework in this repo; verification is reading rendered
  screenshots.
- Local-only: no CI integration in this sub-project (a clearly-scoped future
  follow-up).

## Current state

- Theme work has relied entirely on `scripts/deploy.sh` (rsync + framebuffer
  screenshot over SSH) and `scripts/ui.sh` (evdev input injection over SSH) to
  the physical device.
- No way to render the theme without the device.
- The feasibility PoC confirmed: `ubuntu:24.04` + the pinned Knulli ES build +
  Xvfb + Mesa `llvmpipe` (`LIBGL_ALWAYS_SOFTWARE=1`) renders the theme; the
  system view was captured at 1280x720 with the wave animating. The gamelist
  views and input injection were not exercised in the PoC.

## Design

The harness is a build-once cached Docker image plus a thin per-invocation
render script, mirroring how `deploy.sh`/`ui.sh` are thin scripts over a
stable target.

### Component 1 — The Docker image

**File:** `docker/Dockerfile`

- Base `ubuntu:24.04` (Ubuntu 22.04's libcurl is too old to build this ES).
- Installs build dependencies (SDL2 + SDL2_mixer, FreeImage, FreeType,
  libcurl, rapidjson, VLC, Mesa GL/GLES, boost, pugixml, gettext,
  build-essential, cmake, git, pkg-config) and headless tooling (Xvfb,
  x11-utils, mesa-utils, ImageMagick, xdotool).
- Clones `https://github.com/knulli-cfw/batocera-emulationstation` branch
  `knulli` and checks out the pinned commit `9bbb16a`.
- Builds with:
  `cmake -DBATOCERA=ON -DKNULLI=ON -DGL=ON -DDISABLE_KODI=ON
  -DENABLE_PULSE=OFF -DUSE_SYSTEM_PUGIXML=ON .` then `make -j`.
- The built `emulationstation` binary and the source tree's `resources/`
  directory remain available in the image.

The image is tagged with the pinned commit embedded, e.g.
`es-xmb-harness:knulli-9bbb16a`. Bumping the pinned commit changes the tag,
so a stale image is never silently reused. Build is one-time (~5 minutes,
~2–3 GB), cached locally; `render.sh` rebuilds only when the image for the
current pin is absent.

### Component 2 — The render script

**File:** `scripts/render.sh`

A thin script alongside `deploy.sh` and `ui.sh`. It ensures the image exists
(building it if not), then runs a **throwaway container per invocation** and
copies the resulting PNG to the host.

Flags:

| Flag | Default | Purpose |
|------|---------|---------|
| `--view system\|gamelist\|gamecarousel\|menu` | `system` | which screen to capture |
| `--resolution WxH` | `1024x768` | Xvfb geometry — the aspect-ratio knob |
| `--colorset NAME` | January Blue | PSP colorset to select |
| `--library PATH` | — | real Knulli library to mount (required for `gamelist`/`gamecarousel`) |
| `--out FILE` | `.dev/render.png` | host path for the captured PNG |
| `-h`/`--help` | — | usage |

Per invocation, inside the container the script:

1. Starts `Xvfb :99 -screen 0 <WxH>x24`; exports `DISPLAY=:99`,
   `LIBGL_ALWAYS_SOFTWARE=1`, `SDL_AUDIODRIVER=dummy`.
2. Creates the KNULLI directory layout under `/userdata/` and
   `/usr/share/emulationstation/`, copies the ES `resources/` from the image,
   and writes:
   - an empty `/userdata/system/knulli.conf`;
   - `es_systems.cfg` **generated to match the systems present in the mounted
     `--library`** (so the harness works with whatever subset is mounted);
   - `es_settings.cfg` with `ThemeSet = es-theme-xmb-psp`, the requested
     `--colorset`, and the gamelist view style implied by `--view`.
3. Mounts the theme repo **read-only** at
   `/userdata/themes/es-theme-xmb-psp`, and the `--library` at the Knulli
   library location.
4. Launches `emulationstation`, waits for theme load, runs the navigation
   macro for `--view` (Component 3), and captures the screen with ImageMagick
   `import -window root`.
5. Copies the PNG to `--out` on the host.

**Colorset / gamelist-view-style selection.** These are theme subsets ES
normally selects through its UI. The script's first choice is to set them via
the correct `es_settings.cfg` keys. If those keys cannot be set directly on
this build, the fallback is xdotool navigation through Theme Configuration.
Which mechanism works is settled on-device-equivalent during implementation
(a small config-key discovery, like the device theme quirks were).

Device config (`DEVICE_*`, `SSHPASS`) and the NAS credentials live in the
gitignored `.env.local`; `render.sh` does not need device credentials but
shares the `.env.local` convention for any NAS access.

### Component 3 — View navigation (input injection)

The script drives ES with `xdotool` keystrokes sent to the Xvfb display — the
Docker analogue of `ui.sh`'s evdev injection. One macro per `--view`:

- `system` — ES launches on the system carousel; no navigation. Wait for
  theme load, screenshot.
- `gamelist` / `gamecarousel` — press confirm to enter the selected system's
  gamelist; the *style* (text list vs boxart carousel) is set via the ES
  config from Component 2. Wait, screenshot.
- `menu` — press the menu key to open the Start menu. Wait, screenshot.

Macros use generous fixed waits and are verified by inspecting the captured
frame (navigation timing is the most fragile part of the harness). The exact
key sequences and waits are tuned during implementation, the same way
`ui.sh`'s macros were tuned against the device.

### Component 4 — The test library

The harness renders a **real Knulli `userdata`-shaped library**, mounted via
`--library`, never committed:

- Shape: `roms/<system>/` containing the game files, each system's
  `gamelist.xml`, and scraped media (boxart/thumbnail/image/video) at the
  paths the `gamelist.xml` references.
- Stored on the host in the gitignored `.dev/library/` — kept out of the repo
  for size and game/media licensing reasons.
- The `system` view renders without a library; `gamelist`/`gamecarousel`
  require one.

**Acquisition.** A one-time pull of a **small subset** from the user's NAS
Samba share — two or three systems, roughly ten games, with their scraped
media, and deliberately including **at least one game with no thumbnail** so
the gamecarousel text-fallback is exercised. NAS host/credentials go in
`.env.local`. `docker/README.md` documents this acquisition step so the
harness is reproducible for anyone holding a library.

### Component 5 — Repo layout and docs

- `docker/Dockerfile` — the image definition.
- `docker/` — any static ES config the script needs (e.g. a base
  `es_settings.cfg`); `es_systems.cfg` is generated at run time.
- `scripts/render.sh` — the entry point.
- `docker/README.md` — harness usage and the divergence caveat.
- `.gitignore` — `.dev/library/` and `render.sh` output kept untracked
  (the `.dev/` directory is already used for dev artefacts).

## Divergence caveat

`docker/README.md` must state plainly: the harness renders via desktop
**GL21** (Mesa software, fixed-function); the device renders via **GLES2**
(programmable shaders). The harness **reliably catches** XML errors, element
layout and sizing, `<subset>` colorset resolution, `<include>` resolution,
and storyboard *logic* — and is ideal for fast iteration and multi-resolution
layout work. It is **not a release gate**: pixel-level colour fidelity is not
guaranteed, and build-specific quirks (notably the gamecarousel `textColor`
being ignored and storyboard-in-include not animating on gamelist views) may
not reproduce. **On-device validation remains required before any release.**

## Out of scope

- CI integration (a future follow-up).
- A committed synthetic game-library fixture — the harness uses a real
  mounted library.
- A built-in multi-resolution "matrix" command — `--resolution` is a single
  flag; rendering several resolutions is a trivial shell loop the user can
  run, and a matrix wrapper is deferred unless it proves needed.
- GLES2-mode rendering in Docker (requires complex EGL setup; the GL21 path
  is sufficient for the harness's purpose).
- Replacing `deploy.sh`/`ui.sh` — the device workflow remains the release
  gate; the harness complements it.

## Acceptance / validation

The harness is validated by, in order:

1. The image builds from `docker/Dockerfile`.
2. `render.sh --view system` produces a PNG showing the theme's system view
   (wave background, system carousel) at the default 1024x768.
3. `render.sh --view system --resolution 1280x720` produces a 16:9 render —
   proving the aspect-ratio knob.
4. With a library mounted, `render.sh --view gamecarousel --library …`
   produces a PNG showing the boxart carousel and the right info panel, and
   `--view menu` shows the colorset-themed menu.
5. `render.sh --colorset "August Orange"` visibly re-tints the render.

Its first real job is to render v0.7's two README screenshots and a smoke
test (see below).

## How v0.7 resumes

v0.7 (branch `v0.7-gamelist-menu`, Tasks 1–6 complete and **already verified
on-device** before the device went offline, plus the Task 7 README-text
commit) is blocked only on device-dependent screenshots and a smoke test.
Once this harness is built and merged:

1. v0.7's branch takes in the harness (merge `main`).
2. `render.sh` produces `docs/screenshots/system.png` and
   `docs/screenshots/gamelist.png` at 1024x768, and a smoke-test sweep
   (system / gamelist / gamecarousel / menu) is eyeballed for gross
   regressions.
3. v0.7 Task 7 (commit screenshots) and Task 8 (final review, merge to
   `main`, tag `v0.7`) complete.

v0.7's functional correctness is already device-validated; the harness only
supplies the final screenshots and the layout smoke test. The screenshots
will be GL21-rendered — layout-faithful, acceptable for documentation.

## Branching

The harness is its own sub-project: implemented on a branch off `main`
(e.g. `es-docker-harness`), reviewed, and merged to `main`. v0.7 then merges
`main` to pick up the harness and completes. The harness is developer
tooling and does not take a theme version tag.
