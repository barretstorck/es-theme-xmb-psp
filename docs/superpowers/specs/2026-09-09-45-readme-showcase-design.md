# Issue #45 — README showcase: colorset gallery + navigation GIF

Date: 2026-09-09
Issue: [#45](https://github.com/barretstorck/es-theme-xmb-psp/issues/45)
Milestone: v1.0 — public release

## Problem

For a theme, the README **is** the product. Today's README undersells the
theme and, in places, misrepresents it:

- There is no colorset gallery, so the twelve PSP-month palettes — one of
  the theme's headline features — are invisible to anyone reading the repo.
- There is no motion anywhere, so the continuous XMB wave (the single most
  distinctive thing the theme does) cannot be seen at all.
- The gamelist screenshots predate the v0.12 media-block/metadata
  recomposition. The README says so in prose, which documents the staleness
  rather than fixing it.
- Nothing verifies that the images the README references still exist. A
  renamed or deleted screenshot produces a broken image on the repo's front
  page and no test fails.

## Measured facts this design rests on

Both were measured in the harness on 2026-09-09, not assumed. The issue
text guessed differently on both counts.

1. **An encoder is already present.** `es-xmb-harness:knulli-9bbb16a-r2`
   ships ImageMagick 6.9.12-98, which encodes GIF. The issue assumed
   ffmpeg or gifski would have to be added. Nothing in `docker/` changes,
   so **`HARNESS_REV` is not bumped and nobody rebuilds the image.**
2. **Capture costs ~90 ms/frame** at 1280x720 (`import -window root` plus
   PNG write). Two runs of `render.sh --frames 24` against a `--frames 1`
   baseline gave 87 ms and 92 ms per frame. That is a hard ceiling near
   11 fps, so **10 fps is the target** — not the 12-15 fps the issue
   suggested.
3. **The wave animates under software Mesa.** Consecutive frames of a
   static carousel differ (238k pixels at frame 2, rising to 507k by frame
   24), so a recording captures real motion rather than a still.

## Decisions

Locked with the user before implementation:

| Decision | Choice | Rationale |
|---|---|---|
| Gallery view | **System carousel** | The wave fills most of the frame, so the palette difference is what the eye reads. A gamelist covers the wave with box art and twelve tiles would look alike. |
| Delivery | **One PR, both halves** | The README ends up coherent in a single pass. |
| Storage | **Plain git, outputs committed** | Per the user's decision comment on #45. No LFS, no external hosting. |
| Preview video in the GIF | **Omitted** | See "Scope exclusion" below. |

### Scope exclusion: no preview video in the GIF

The issue asks the GIF to let the card's preview video start, and gates
that on #40. #40 shipped, but what it added were **synthetic** clips —
`tests/fixtures/gen-videos.py` generates 320x240 and 256x224 test patterns.
`/tmp/library`, the only source of real scraped media, contains 296 real
images and **zero videos**.

Putting a generated test pattern in the repo's headline marketing GIF would
misrepresent the theme to a first-time reader. The GIF therefore shows
carousel navigation, entry into a gamelist, several games with real box
art, screenshots and metadata, and the way back out — and skips the video
beat. This is recorded on #45 rather than left implicit.

## Architecture

Four units, each independently usable and testable.

### 1. `scripts/record.sh` — host wrapper

Sibling of `render.sh`, deliberately not an extension of it: the flag sets
barely overlap, and `render.sh` is already 305 lines. Shares `ES_PIN` /
`HARNESS_REV` / `IMAGE` and the same "build only when the image is missing"
behaviour.

| Flag | Default | Purpose |
|---|---|---|
| `--resolution WxH` | `1280x720` | Xvfb geometry. 16:9 per the issue. |
| `--colorset NAME` | `January Blue` | Theme default. |
| `--library PATH` | (none) | Needed for the gamelist leg. |
| `--fps N` | `10` | Requested rate; the ceiling is ~11. |
| `--script SPEC` | (see below) | Navigation to perform while recording. |
| `--width N` | `640` | GIF output width; downscaled from the capture. |
| `--colors N` | `128` | Palette size. |
| `--out FILE` | `.dev/record.gif` | Host output path. |
| `--keep-frames` | off | Retain the PNG frames for inspection. |

Validation follows the traps `render.sh` already documents: integers are
checked against `^[0-9]+$` **before** reaching any `(( ))` context, because
a leading zero is parsed as octal (`08` is an error, not eight); `--fps`
must be >= 1; decimals are validated as decimals.

### 2. `VIEW=record` in `docker/run-in-container.sh`

Boot and colorset/subset setup are unchanged — this is one more case in the
existing `case "${VIEW}"` block, so it inherits `SHOW_HELP`, the battery
mount, the settings pins and `require_es_alive` for free.

The recording itself is **a background capture loop plus a foreground key
script**:

```
start capture loop (background)  ──┐
                                   │  uniform period, deadline-scheduled
run navigation script (foreground) │
                                   │
script ends → signal loop to stop ─┘
```

They are decoupled because their timing requirements conflict. The wave
needs **evenly spaced** frames or playback speed wobbles; navigation needs
**unevenly spaced** pauses (dwell on a system, then move). Interleaving
capture with keystrokes in one loop couples them and produces neither.

The loop is **deadline-scheduled** — it computes `next = start + i*period`
and sleeps the remainder — rather than `sleep period` per iteration, which
would accumulate the ~90 ms capture cost into drift and stretch a 12-second
recording well past its intended length.

**Navigation script vocabulary.** A comma-separated list of `key:seconds`
steps, e.g. `right:1.5,right:1.5,confirm:2,down:1,down:1,back:1.5`. Keys map
onto the existing `key()` helper. `confirm` and `back` resolve through the
existing `INVERT_BUTTONS` -> `CONFIRM_KEY` logic, so the inversion that
already bit the gamelist views is handled in exactly one place.

**On the "never inject confirm into a gamelist" warning in the issue:** that
warning is about `scripts/ui.sh` on real hardware, where a stray confirm
launches a game. In the container there is no emulator binary to launch, so
the risk does not transfer. The script vocabulary is not restricted; the
distinction is documented instead.

### 3. Encoding

Runs in the same container invocation, so the pipeline is one reproducible
step:

```
convert -delay <cs> -loop 0 frames/*.png -resize <width> -colors <n> \
        -layers OptimizeTransparency out.gif
```

**The delay is computed from the measured elapsed time and frame count, not
from `--fps`.** If the harness under-delivers — a slower host, a larger
resolution — a delay derived from the *requested* rate would play the GIF
faster than the theme actually moves. Deriving it from measurement keeps
playback truthful and makes the shortfall visible in the log instead of
silently baked into the artifact.

Palette size is compared at 256 / 128 / 64 in `.dev/` before anything is
committed. The wave is a smooth gradient and is the first thing
quantisation damages.

### 4. `scripts/render-readme-assets.sh` — one regeneration entry point

Regenerates **every committed README image**: the twelve colorset
thumbnails, the five-aspect rows, the per-style shots, and the GIF. The
issue asks that a future contributor not be left guessing which script
produced what; a single script that reproduces the whole set answers that
better than a prose note.

Reads the twelve colorset names from `theme.xml`'s `colorset` subset rather
than hard-coding them, so adding a thirteenth palette cannot leave the
gallery silently short.

## Assets and layout

- Colorset thumbnails: `docs/screenshots/colorsets/<slug>.png`, system view,
  rendered at 1024x768 and downscaled for the table.
- GIF: `docs/screenshots/xmb-navigation.gif`, 16:9.
- Regenerated stills replace the existing paths, so the stale-screenshot
  disclaimer in the README is deleted rather than reworded.
- Gamelist renders use `/tmp/library` (real art, descriptions up to 1252
  chars). **Never `tests/fixtures/library`** — it is deliberately degenerate
  (74-char maximum description) and makes the layout look better than it is.
  It stays the regression corpus, not the marketing corpus.

README order becomes: title -> GIF -> description -> colorset gallery ->
aspect and style screenshots -> the rest.

## Testing

`scripts/tests/test-readme-assets.sh`, following the repo's guard plus
mutation-testing convention.

1. **Every image path referenced in `README.md` exists in-tree.** This is
   the guard that matters most and the one nothing currently provides: a
   broken table row is a defect on the repo's front page, and today no test
   catches it.
2. The colorset table has exactly twelve rows, and its names match
   `theme.xml`'s `colorset` subset exactly — catching drift in either
   direction.
3. The committed GIF exists, is actually a GIF, and is within budget.
4. `record.sh` rejects out-of-range and malformed numeric arguments —
   `--fps 0`, `--fps 08` (the leading-zero/octal case), a non-numeric
   `--colors` — before any of them reaches a `(( ))` context.

Known guard traps in this repo, all of which apply here and are avoided
deliberately: `check "...$(cmd)..." $?` reports the *substitution's* status
because bash expands arguments left to right, so `rc=$?` is captured first;
`! grep -q` against a **missing** file returns 0 and passes vacuously; and
guards that scan raw XML text match `${vars}` inside comments.

## Weight budget

Set before generating, per the user's decision comment:

| Item | Budget |
|---|---|
| GIF | <= 3 MB |
| 12 colorset thumbnails | <= 600 KB total |
| Regenerated stills | replace existing paths, roughly neutral |
| **Total added** | **<= 4 MB** |

For scale: the repo is currently 48 MB packed with 13 MB already in
`docs/screenshots`. Plain git keeps every version forever, so the GIF is
iterated in `.dev/` (gitignored) and committed **once**. The actual
measured weight is reported on #45 so the cost is a stated decision rather
than a surprise.

## Out of scope

- Preview video in the GIF (see above).
- Any change to `docker/`, which would force a `HARNESS_REV` bump and a
  rebuild for every contributor.
- The remaining v1.0 milestone issues (#46 compatibility matrix, #47
  go-public gate). #45 does not close them.
