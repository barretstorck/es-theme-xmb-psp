# ES Docker test harness

Renders `es-theme-xmb-psp` by running batocera-emulationstation headless in
Docker, so the theme can be screenshotted without the physical device, at any
resolution.

## The project's testing method

This harness is the project's primary way to verify the theme — physical-device
testing has been retired in its favour.

⚠️ One caveat to keep in mind: the harness renders via **desktop GL21** (Mesa
software rendering), while a real device renders via **GLES2** (programmable
shaders). The harness reliably catches XML errors, layout/sizing mistakes,
colorset resolution, `<include>` resolution, and storyboard logic, and is ideal
for fast iteration and multi-resolution layout work. It does **not** guarantee
pixel-level colour fidelity, and a few build-specific device quirks may not
reproduce — judge colour-critical changes with that in mind.

## Usage

    ./scripts/render.sh [--view V] [--resolution WxH] [--colorset NAME] \
                        [--library PATH] [--out FILE]

- `--view` — `system` (default), `gamelist`, `gamecarousel`, or `menu`
- `--resolution` — Xvfb geometry, e.g. `1024x768` (4:3, default) or `1280x720`
- `--colorset` — PSP colorset name, e.g. `"August Orange"` (default: `January Blue`)
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

The harness recognises a fixed set of ROM extensions
(`.zip .bin .iso .chd .pce .nes .smc .sh`); games whose files use a different
extension will not appear in the generated gamelist.

## How it works

`scripts/render.sh` builds/caches the image (`docker/Dockerfile` — Knulli
batocera-emulationstation pinned to commit `9bbb16a`), then runs a throwaway
container that executes `docker/run-in-container.sh`: Xvfb + Mesa software GL,
ES config, launch, xdotool navigation, ImageMagick screenshot.
