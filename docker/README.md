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
- `--carousel-right N` — press Right N times on the system carousel before
  entering a gamelist, to land on a system other than the first
- `--settle N` — wait N more seconds after navigating, before capturing
- `--frames N` / `--frame-interval S` — capture a sequence instead of one still,
  to `<out>-1.png` … `<out>-N.png`
- `--video` — use the video-capable image (see below)

Subsets can be pinned per render with the `ICON_SIZE`, `TITLE_VISIBILITY`,
`GAMELIST_STYLE`, `VIDEO_DELAY` and `VIDEO_AUDIO` environment variables.

The first run builds the Docker image (~5–10 min, ~2–3 GB), cached thereafter.

## Video

There are two images, both built from this one `Dockerfile` at the **same ES
pin**, selected by the `WITH_VIDEO` build arg:

| image | built by | use it for |
|---|---|---|
| `es-xmb-harness:knulli-9bbb16a` | `render.sh` (default) | everything: layout, colorsets, `scripts/tests/` |
| `es-xmb-harness:knulli-9bbb16a-video` | `render.sh --video` | preview video only (`<video>` elements) |

The default image links `libvlc` but installs none of VLC's plugins, so
`libvlc_new()` returns an instance that cannot open a single file and every
`<video>` element stays dark. The video image adds `vlc-plugin-base` and one
source patch, `docker/patches/vlc-parse-no-block.patch`.

That patch is needed because of a hang, not a missing feature. In this ES build
`VideoVlcComponent::startVideo()` waits for `libvlc_media_parsed_status_done`
and *only* that status:

    libvlc_media_parse_with_options(mMedia, libvlc_media_parse_local, 0);
    while (libvlc_media_get_parsed_status(mMedia) != libvlc_media_parsed_status_done)
        std::this_thread::sleep_for(std::chrono::milliseconds(10));

libvlc answers `failed` (2) for anything that is not a media file, so that loop
never ends and it runs on the **main thread**. A `<video extra="true">` bound to
`{game:video}` holds the literal string `{game:video}` as its path until
`BindingManager` resolves it (`VideoComponent.cpp:326` keeps any path starting
with `{`), and if the view is shown first, ES freezes with the last frame still
on screen — it looks exactly like a keystroke that did not land. Upstream
batocera has since replaced the whole blocking wait with an async
`mIsParsing` poll in `update()`; the patch is the minimal equivalent, leaving
the loop on any terminal status.

**The patch is why the video image is not authoritative for layout.** Keep
using the default image for everything else, so layout renders come from an
unmodified build of what the device runs.

Preview video only starts after the theme's `<delay>`, so a capture has to
outlast it:

    GAMELIST_STYLE="PSP Card" VIDEO_DELAY=Instant \
      ./scripts/render-fixtures.sh --video --view gamelist \
        --carousel-right 1 --settle 4 --out .dev/video.png

`tests/fixtures/library` ships two short clips (psx/ff7, snes/super-metroid)
alongside games that have a screenshot but no video, which is what exercises
`showSnapshotNoVideo`. See `tests/fixtures/README.md`.

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
