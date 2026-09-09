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

- `--view` — `system` (default), `gamelist`, `gamecarousel`, `menu`, or
  `splash`. There is also `record`, which is not reached through `render.sh` —
  see the Recording section below.
- `--view splash` renders the boot splash, and behaves unlike every other view.
  ES is launched WITHOUT the flag that suppresses the splash (the harness passes
  it for all other views so the splash cannot cover the capture window), and the
  frame is grabbed `SPLASH_AT` seconds after launch (default `0.4`). The splash is transient —
  it exists from `main.cpp:566` to `main.cpp:628` and is then replaced by the
  carousel — so there is no settled state to wait for and the capture is a race.
  An all-black frame means ES had not opened its window yet; a carousel means
  the splash was already over. Sweep with `--frames N --frame-interval 0.2`.
  `SPLASH_AT` and `--frame-interval` both accept fractions: the window is well
  under a second, and passing `--library` lengthens it by giving ES more to
  preload, which is also closer to what the device does. The default is kept
  sub-second on purpose — overshooting does not error, it returns a clean
  screenshot of the carousel — and 0.4 is tuned for 1024x768, so smaller
  resolutions may need less.
- `--resolution` — Xvfb geometry, e.g. `1024x768` (4:3, default) or `1280x720`
- `--colorset` — PSP colorset name, e.g. `"August Orange"` (default: `January Blue`)
- `--library` — path to a Knulli `userdata`-shaped library; required for the
  `gamelist` and `gamecarousel` views
- `--out` — host path for the PNG (default `.dev/render.png`)
- `--carousel-right N` — press Right N times on the system carousel. Picks
  which system a `--view system` capture shows, and which gamelist the other
  views enter
- `--settle N` — wait N more seconds after navigating, before capturing
- `--frames N` / `--frame-interval S` — capture a sequence instead of one still,
  to `<out>-1.png` … `<out>-N.png`

Subsets can be pinned per render with the `ICON_SIZE`, `TITLE_VISIBILITY`,
`GAMELIST_STYLE`, `VIDEO_DELAY` and `VIDEO_AUDIO` environment variables.

The first run builds the Docker image (~5–10 min, ~2–3 GB), cached thereafter.

## Recording (animated GIF)

`scripts/record.sh` produces the README's navigation GIF. It uses the same
image, the same pin and the same container script as `render.sh` — recording
added no image content, so **`HARNESS_REV` was deliberately not bumped and
nobody has to rebuild** for it. The encode uses the ImageMagick the image has
shipped all along.

    ./scripts/record.sh --library /tmp/library
    ./scripts/record.sh --script "right:1.5,right:1.5" --fps 8 --keep-frames

### A background capture loop and a foreground key script

`VIEW=record` starts a capture loop in the background and plays the navigation
script in the foreground. The two are separate because their timing
requirements conflict: the wave animates on 30s / 20s / 12s loops and needs
**evenly spaced** frames or playback speed wobbles, while navigation needs
**uneven** pauses — dwell on a system, then move. A single loop doing both
serves neither.

The loop is **deadline-scheduled**: it sleeps until `start + i*period` rather
than sleeping a fixed period each pass. A screen grab costs about 90 ms at
1280×720, and a fixed sleep would accumulate that into drift and stretch the
take well past its intended length.

### The script vocabulary is a closed set

Steps are `key:seconds`, comma-separated. The keys are `up`, `down`, `left`,
`right`, `start`, `confirm` and `back`; `confirm` and `back` resolve through
the same `INVERT_BUTTONS` logic every other view uses.

They are **not** raw xdotool keysyms, and that is deliberate. Keysyms are
case-sensitive — `Right` is the arrow key, `right` is not a keysym at all —
and the container's `key()` helper swallows an unknown symbol with `|| true`.
The first take of this feature recorded a flawless GIF in which nothing
navigated. An unrecognised key is now an error in both `record.sh` and the
container.

### The frame rate is measured, not assumed

The capture ceiling is about **11 fps** at 1280×720, measured rather than
guessed: `import -window root` plus the PNG write costs ~90 ms a frame, twice
measured at 87 ms and 92 ms. The default is 10 fps and a take typically
achieves ~9.1.

The GIF's frame delay is derived from the rate **actually achieved**, not from
`--fps`. A delay computed from the requested rate would make a slow machine's
GIF play faster than the theme really moves; deriving it from measurement keeps
playback truthful and puts the shortfall in the log instead of inside the
artifact.

### Size

Take **length** and `--width` are the only real levers. Palette reduction
barely helps: measured on a 139-frame take, dropping 128 → 64 colours saved 5%
(2.97 MB → 2.81 MB). Every pixel of the wave changes every frame, so neither
quantisation nor frame differencing has much to work with. A take also cannot
be much shorter than ~12 s, because that is the period of the fastest wave
layer and a shorter one shows no motion.

Note that `-layers OptimizeTransparency` leaves individual frames carrying only
their changed pixels, so extracting one frame from the GIF shows garbage unless
you `-coalesce` first. That is an artifact of the extraction, not of playback.

## Video

Preview video plays here. That took two things, neither of them a rebuild at a
newer pin:

**VLC's plugins.** The ES binary always exported `VideoVlcComponent` and always
linked `libvlc` — video was never "compiled out", whatever older comments in
this repo said. But `libvlc-dev` ships the library and headers and not one
demuxer or decoder, so `libvlc_new()` returned an instance that could not open a
single file and every `<video>` stayed dark. `vlc-plugin-base` fixes that, for
7 MB.

**One source patch**, `docker/patches/vlc-parse-no-block.patch`, because the
plugins alone freeze ES. This build waits for `libvlc_media_parsed_status_done`
and *only* that status:

    libvlc_media_parse_with_options(mMedia, libvlc_media_parse_local, 0);
    while (libvlc_media_get_parsed_status(mMedia) != libvlc_media_parsed_status_done)
        std::this_thread::sleep_for(std::chrono::milliseconds(10));

libvlc answers `failed` (2) for anything that is not a media file, so that loop
never ends — on the **main thread**. A `<video extra="true">` bound to
`{game:video}` holds the literal string `{game:video}` as its path until
`BindingManager` resolves it (`VideoComponent.cpp:326` keeps any path starting
with `{`), and if the view is shown first, ES freezes with the last frame still
on screen — it looks exactly like a keystroke that did not land. Upstream
batocera has since replaced the whole blocking wait with an async `mIsParsing`
poll in `update()`; the patch is the minimal equivalent, leaving the loop on any
terminal status. It changes no rendering behaviour: it only decides whether ES
carries on or hangs.

### Renders stay still by default

`run-in-container.sh` pins the **Video Delay** subset to `10 seconds` unless
`VIDEO_DELAY` says otherwise. A capture happens roughly 6s after entering a
gamelist, which is *after* the theme's own 5s default — so without the pin,
every render of a game with a scraped video would catch an arbitrary frame and
differ run to run. To see the video instead, ask for it:

    GAMELIST_STYLE="PSP Card" VIDEO_DELAY=Instant \
      ./scripts/render-fixtures.sh --view gamelist \
        --carousel-right 1 --settle 4 --out .dev/video.png

To watch the handoff itself, capture a sequence across the delay:

    GAMELIST_STYLE="PSP Card" VIDEO_DELAY="10 seconds" \
      ./scripts/render-fixtures.sh --view gamelist --carousel-right 1 \
        --frames 3 --frame-interval 4 --out .dev/handoff.png

`tests/fixtures/library` ships two short clips (psx/ff7, snes/super-metroid)
alongside games that have a screenshot but no video, which is what exercises
`showSnapshotNoVideo`. See `tests/fixtures/README.md`.

### Rebuilding

`render.sh` builds only when the image is **missing**, so the tag carries a
harness revision — `es-xmb-harness:knulli-9bbb16a-r2` — that gets bumped
whenever anything in `docker/` changes what lands in the image. Without that,
an existing image keeps being reused and the change never takes effect. Older
tags (`knulli-9bbb16a`, `knulli-9bbb16a-video`) are safe to delete.

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

#### `<theme>` and `<group>` are not the same thing

`es_systems.yml` has two separate keys and the generator emits both:

- `theme:` — the art folder the theme renders as `${system.theme}`. Only present
  when it differs from the system key (`lynx` → `atarilynx`).
- `group:` — folds the system into a *parent* carousel entry
  (`sdlpop` → `ports`). The child keeps its own theme folder and stops being a
  carousel entry at all.

Until issue #39 the generator read `group:` and wrote it into `<theme>`, and
never emitted `<group>`. That invented ~73 theme-folder collisions no real
`es_systems.cfg` has — Knulli's 183-system file has zero — and meant grouping
was never exercised here at all, while every port rendered as its own top-level
carousel entry. `scripts/tests/test-system-groups.sh` guards both.

Grouping matters for what the carousel looks like: ES folds the children away
and shows one parent. Where a system of the group's name already exists it is
reused and keeps its own theme folder (`jaguar` → `atarijaguar`); where none
exists, ES fabricates one whose name *and* theme folder are the raw group
string. `atari8bit` is the only such group on Knulli; batocera master also
makes `amiga` synthetic and adds a `windows` group Knulli does not have.

The container also writes a representative `/userdata/system/knulli.conf`
(language, timezone, LED, background music) rather than an empty file.

## How it works

`scripts/render.sh` builds/caches the image (`docker/Dockerfile` — Knulli
batocera-emulationstation pinned to commit `9bbb16a`), then runs a throwaway
container that executes `docker/run-in-container.sh`: Xvfb + Mesa software GL,
ES config, launch, xdotool navigation, ImageMagick screenshot.
