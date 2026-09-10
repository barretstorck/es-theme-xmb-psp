# Development

You do not need a handheld to work on this theme. Development and verification
run through the **Docker render harness**, which runs batocera-emulationstation
headless in Docker and screenshots the theme at any resolution. Full details are
in [`docker/README.md`](../docker/README.md); this page is the working summary.

See [CONTRIBUTING.md](../CONTRIBUTING.md) before opening a pull request.

## Rendering

```
./scripts/render.sh --view system
./scripts/render.sh --view gamelist --library <path> --resolution 1280x720
VIDEO_DELAY=Instant ./scripts/render.sh --view gamelist --library <path> --settle 4
./scripts/render.sh --view splash --library <path>          # SPLASH_AT=0.4 by default
```

`--view splash` is the odd one out: it launches ES *with* the boot splash the
harness otherwise suppresses, and grabs the frame `SPLASH_AT` seconds later. That
frame is transient — gone within about a second, sooner at smaller resolutions —
so the capture is a race rather than a settled state. Sweep it with
`--frames N --frame-interval 0.2` (both accept fractions) and keep the frame that
lands. An all-black capture means ES had not opened its window yet; a carousel
means the splash was already over.

Preview video plays in the harness. Renders pin Video Delay to 10s so a capture
lands on the still screenshot rather than an arbitrary video frame; pass
`VIDEO_DELAY` and `--settle` when the video is what you want to see.

Theme settings are pinned through the environment — `GAMELIST_STYLE`, `ICON_SIZE`,
`TITLE_VISIBILITY`, `SCROLL_SPEED`, `VIDEO_DELAY`, `VIDEO_AUDIO`, `BUTTON_GLYPHS`,
`SHOW_BATTERY`, `CLOCK_12H` — and validated against `theme.xml`'s own subsets, so
a typo is an error rather than a flawless render of the wrong thing.

## Audio

The harness can also **hear** itself, which a screenshot cannot.
`scripts/capture-audio.sh` runs ES under SDL's `disk` audio driver and measures
the mixer's actual output, so a sound binding can be verified rather than assumed.
`--expect` turns a capture into a pass/fail test.

```
./scripts/capture-audio.sh --library /tmp/library
./scripts/capture-audio.sh --library /tmp/library \
  --script "right:2,confirm:3,down:2" --expect sound,any,sound
```

ES ships navigation sounds **off**, so the tool pins `EnableSounds` on by default —
otherwise every capture would be silent and pass vacuously.

## Regenerating the README's screenshots

Every image the README commits is produced by one script, so no one has to work
out which flag combination made which file:

```
./scripts/render-readme-assets.sh --library /tmp/library
./scripts/render-readme-assets.sh --library /tmp/library --only colorsets
./scripts/render-readme-assets.sh --library /tmp/library --skip-gif
```

It needs a library with **real scraped media** — box art, screenshots, ratings and
full-length descriptions. `tests/fixtures/library` is deliberately degenerate (its
longest description is 74 characters) and would make the layout look better than
it is; it is the regression corpus, not the marketing corpus. The script refuses
to run without `--library` for that reason.

The animated GIF comes from `scripts/record.sh`, which drives navigation with a
scripted key sequence while capturing frames on a uniform interval:

```
./scripts/record.sh --library /tmp/library --keep-frames
./scripts/record.sh --library /tmp/library --script "right:1.5,right:1.5" --fps 8
```

Its defaults reproduce the committed GIF. The capture rate tops out near 11fps — a
screen grab costs about 90ms at 1280×720 — and the GIF's frame delay is derived
from the rate actually achieved, so a slower machine produces a longer capture
rather than a GIF that plays too fast.

`scripts/tests/test-readme-assets.sh` guards the result: it fails if the README
references an image that is not in the tree, if the colorset gallery drifts from
`theme.xml`, or if either committed artifact exceeds its size budget.

`docs/screenshots/v0.11/` and the other versioned subdirectories are point-in-time
records of past redesigns. They are deliberately **not** regenerated — re-rendering
them against today's theme would silently change what they document.

## On-device scripts

`scripts/deploy.sh` and `scripts/ui.sh` are retained as a dormant fallback for
working against real hardware. They are no longer part of the routine workflow.
