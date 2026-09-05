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

### Making the library Knulli-accurate

By default the harness synthesises one `<system>` entry per directory, using the
directory name as the fullname and a fixed extension list
(`.zip .bin .iso .chd .pce .nes .smc .sh`). That renders, but it is not what the
device looks like, and a theme that keys off fullnames, theme folders or
per-system extensions will behave differently here than on hardware.

Generate a real `es_systems.cfg` into the library instead:

```sh
./scripts/make-library-systems.py .dev/library
```

It pulls definitions from batocera's canonical `es_systems.yml` (which Knulli
inherits) and writes `es_systems.cfg` into the library root, giving proper
fullnames (`Super Nintendo Entertainment System`, not `snes`), the real
per-system extension list, and theme folder names. `run-in-container.sh` uses it
verbatim when present and logs `using library-provided es_systems.cfg`. The
definitions are cached beside the script, so it works offline after the first run.

Systems batocera does not know about fall back to the directory name rather than
being dropped, so ports collections and Knulli-only entries still appear.

The container also writes a representative `/userdata/system/knulli.conf`
(language, timezone, LED, background music) rather than an empty file.

## How it works

`scripts/render.sh` builds/caches the image (`docker/Dockerfile` — Knulli
batocera-emulationstation pinned to commit `9bbb16a`), then runs a throwaway
container that executes `docker/run-in-container.sh`: Xvfb + Mesa software GL,
ES config, launch, xdotool navigation, ImageMagick screenshot.
