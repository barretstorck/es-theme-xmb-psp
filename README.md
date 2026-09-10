# es-theme-xmb-psp

A PSP XMB-style theme for [batocera-emulationstation](https://github.com/batocera-linux/batocera-emulationstation), built and tuned for **Knulli Scarab on the TrimUI Brick** (4:3, 1024×768).

![Navigating the XMB carousel and a gamelist](docs/screenshots/xmb-navigation.gif)

> Status: **v0.13, working toward v1.0** (see [CHANGELOG.md](CHANGELOG.md)) — PSP-style variant only. **System icons adopted from the RetroArch `monochrome` XMB set** (filled-silhouette style, CC-BY 4.0): 150 system shortnames mapped from the RA set plus 8 hand-authored port icons in the same style, all with pre-burned drop shadows. **Three user-selectable gamelist styles** (see Gamelist Style below): a PSP-card layout where each game is a collapsed row that expands into a card with box art, a screenshot that becomes a preview video, and a bounded description; a ten-row list with metadata and description; and a box-art grid. Five tuned aspect ratios (4:3, 16:9, 3:2, 1:1, 8:7), with constant gap-to-icon ratio for the system carousel across all ratios. Twelve user-selectable PSP-month colorsets, **continuous PSP XMB wave animation that no longer resets on system carousel navigation**, XMB cross layout, optional game counter, a colorset-themed EmulationStation menu, universal system icon coverage. **Status bar with clock, network glyph and battery glyph + percentage**, the battery elements driven by ES's own Show Battery Status setting. **A themed boot splash**, **three selectable face-button glyph sets** (Nintendo / PSP / Xbox), **navigation sounds on both axes**, and a **Scroll Speed** knob for the auto-scrolling description. Default colorset is January Blue.

## Colorsets

Twelve PSP-month palettes, picked in **UI Settings → Theme Configuration → PSP
Color**. Every one retints the wave, the icons, the captions and the boot
splash together. Default is January Blue.

| | | | |
|:---:|:---:|:---:|:---:|
| ![](docs/screenshots/colorsets/january-blue.png)<br>**January Blue** | ![](docs/screenshots/colorsets/february-violet.png)<br>**February Violet** | ![](docs/screenshots/colorsets/march-pink.png)<br>**March Pink** | ![](docs/screenshots/colorsets/april-green.png)<br>**April Green** |
| ![](docs/screenshots/colorsets/may-yellow-green.png)<br>**May Yellow-Green** | ![](docs/screenshots/colorsets/june-yellow.png)<br>**June Yellow** | ![](docs/screenshots/colorsets/july-amber.png)<br>**July Amber** | ![](docs/screenshots/colorsets/august-orange.png)<br>**August Orange** |
| ![](docs/screenshots/colorsets/september-red.png)<br>**September Red** | ![](docs/screenshots/colorsets/october-crimson.png)<br>**October Crimson** | ![](docs/screenshots/colorsets/november-slate.png)<br>**November Slate** | ![](docs/screenshots/colorsets/december-aqua.png)<br>**December Aqua** |

## Screenshots

### Gamelist styles (4:3, January Blue)

Three user-selectable layouts, all shown with real scraped media —
box art, screenshots, ratings and descriptions.

| PSP Card (default) | List + Details | Box Art Grid |
|:---:|:---:|:---:|
| ![](docs/screenshots/style-psp-card.png) | ![](docs/screenshots/style-list-details.png) | ![](docs/screenshots/style-box-art-grid.png) |

### System view (XMB cross + system carousel)

| 4:3 (1024×768) | 16:9 (1280×720) | 3:2 (720×480) | 1:1 (720×720) | 8:7 (1024×896) |
|:---:|:---:|:---:|:---:|:---:|
| ![](docs/screenshots/system-4x3.png) | ![](docs/screenshots/system-16x9.png) | ![](docs/screenshots/system-3x2.png) | ![](docs/screenshots/system-1x1.png) | ![](docs/screenshots/system-8x7.png) |

### Gamelist — PSP Card style (default: Boxart icons, PSP-Faithful titles)

| 4:3 | 16:9 | 3:2 | 1:1 | 8:7 |
|:---:|:---:|:---:|:---:|:---:|
| ![](docs/screenshots/gamelist-4x3.png) | ![](docs/screenshots/gamelist-16x9.png) | ![](docs/screenshots/gamelist-3x2.png) | ![](docs/screenshots/gamelist-1x1.png) | ![](docs/screenshots/gamelist-8x7.png) |

### Gamelist toggles (4:3, January Blue)

| Boxart + With Titles | Compact + PSP-Faithful | Compact + With Titles |
|:---:|:---:|:---:|
| ![](docs/screenshots/v0.11/redesign-boxart-friendly-4x3-january-blue.png) | ![](docs/screenshots/v0.11/redesign-compact-strict-4x3-january-blue.png) | ![](docs/screenshots/v0.11/redesign-compact-friendly-4x3-january-blue.png) |

### Boot splash

Shown for the whole of EmulationStation's boot, tinted by whichever colorset is
selected. The mark is the theme's own — there is no Sony wordmark anywhere in
this repo. The label and the progress bar are ES's; the theme styles them but
deliberately leaves their positions alone.

| 4:3 — January Blue | 4:3 — August Orange | 1:1 — December Aqua |
|:---:|:---:|:---:|
| ![](docs/screenshots/splash-4x3.png) | ![](docs/screenshots/splash-4x3-august-orange.png) | ![](docs/screenshots/splash-1x1.png) |

## Known limitations

- System icon coverage is mixed-source. Of the 201 icons in `art/system-icons/`: 150 shortnames use icons from the RetroArch `monochrome` XMB set, 8 ports use hand-authored icons in the same style (`scripts/gen-port-icons.py`), 13 less-common shortnames retain distinct icons from the previous XMB Menu ES-DE set, and the remaining 30 are the generic `_default.png` placeholder and copies of it, standing in for systems with no dedicated icon. To add or replace an icon, drop `<system-shortname>.png` into `art/system-icons/` — but run it through `scripts/apply-shadow.py` once (the script is not idempotent; don't re-run it on an already-shadowed icon) so it matches the pre-burned drop-shadow treatment of the shipped icons. See [CREDITS.md](CREDITS.md) for icon sources and licenses. Note: ES auto-collections use theme-folder names with an `auto-` prefix (e.g., `auto-allgames.png`, `auto-favorites.png`, `auto-lastplayed.png`) rather than the short collection name.
- Gamelist rows show each game's scraped `thumbnail` (box art) when Icon Size is `Boxart`. A game with no thumbnail scraped falls back to its system's media-type silhouette (cartridge, CD, floppy, etc. — see `art/system-media/`). Scrape your library with box/thumbnail media for full boxart rows, or use the `Compact` icon size.

## Install

1. SSH into your device. The Knulli default credentials are `root` / `linux`:
   ```
   ssh root@<your-device-ip>
   ```
2. Clone (or copy) this repo into `/userdata/themes/`:
   ```
   cd /userdata/themes && git clone <repo-url> es-theme-xmb-psp
   ```
3. In EmulationStation: **Main Menu → UI Settings → Theme Set → `es-theme-xmb-psp`**.
4. (Optional) pick a colorset: **UI Settings → Theme Configuration → PSP Color → choose one**.
5. Restart EmulationStation: **Main Menu → Quit → Restart Emulation Station**.

## Compatibility

- **Verified on-device:** Knulli Scarab on TrimUI Brick (4:3, 1024×768).
- **Verified via Docker harness:** aspect ratios 4:3, 16:9, 3:2, 1:1, and 8:7 (render samples in the Screenshots section above).
- **Likely works:** any Batocera/Knulli device whose screen falls into one of the verified ratios at any resolution, running batocera-emulationstation with `formatVersion 7` support.
- **Other ratios** (21:9, 5:4, vertical, etc.) silently fall back to the 4:3 layout — may letterbox or stretch.
- **Not verified:** ES-DE and other EmulationStation forks. The theme is written against batocera-emulationstation's `formatVersion 7`; other forks parse a different dialect and are known to ignore or mis-render parts of it. Establishing which forks actually work is tracked in [#46](https://github.com/barretstorck/es-theme-xmb-psp/issues/46) — reports welcome.

## Customization

Configurable knobs, all under **UI Settings → Theme Configuration**:
- **Gamelist Style** — PSP Card / List + Details / Box Art Grid; see below
- **PSP Color** — colorset (twelve PSP-month palettes; default January Blue)
- **Icon Size** — PSP Card gamelist row icons as scraped boxart (`Boxart`, default) or small uniform icons (`Compact`)
- **Title Visibility** — PSP Card unselected rows show icon only (`PSP-Faithful`, default) or icon + title (`With Titles`)
- **Video Delay** — how long a game stays selected before its screenshot becomes a preview video (Instant / 2s / 5s / 10s)
- **Video Audio** — mute or allow audio on that preview video (also subject to ES's own global "Enable video preview audio" setting)
- **Game Count** — whether the system-name caption stays on the name only (Hide, default) or also cycles to an "X GAMES" counter (Show)
- **Scroll Speed** — how fast a long game description scrolls through its box (Normal / Slow / Fast). Applies to the PSP Card and List + Details styles; it has **no effect in Box Art Grid**, which shows a caption rather than a description
- **Button Icons** — which face-button glyphs the bottom help strip uses: `Nintendo` (default), `PSP` or `Xbox`; see below

### Navigation sounds

The theme ships three sounds: a **tick** whenever the selection moves, in any
direction and in any view; a **confirm** on launching a game or opening a
gamelist menu; and a **back** sound when you leave a subfolder.

The real PSP XMB uses a lower, softer sweep for sideways moves than for
up/down ones. That was built and tried on hardware, and it sounded out of
place against the rest of this set — so both axes share the one tick. See
[`docs/psp-authenticity-audit.md`](docs/psp-authenticity-audit.md) entry A2.

Note that `back` is narrower than it sounds: EmulationStation only plays it
when you leave a **subfolder** inside a gamelist, not when you leave a
gamelist for the system carousel. Most libraries never trigger it.

**You will hear none of them until you turn navigation sounds on.** This is
EmulationStation's own switch, not a theme option, and it ships **off**:

> **Main Menu → Sound Settings → Enable Navigation Sounds**

There is no theme-side toggle, because that switch already gates every sound
this theme can make — a second control would only be able to turn things off
that ES had already silenced.

### Button Icons

UI Settings → Theme Configuration → **Button Icons** picks the face-button
glyphs in the help strip along the bottom of the screen:

| | shown on the east / south / north / west buttons |
|---|---|
| **Nintendo** (default) | A · B · X · Y |
| **PSP** | ○ Circle · ✕ Cross · △ Triangle · □ Square |
| **Xbox** | B · A · Y · X |

Nintendo is the default because the theme's primary target, the TrimUI Brick,
silkscreens its buttons in that layout — a help strip reading "✕ Enter" tells a
Brick owner nothing about which button to press. Pick **PSP** for full XMB
authenticity, or **Xbox** for a controller in the Xbox/SDL layout (most USB and
Bluetooth gamepads).

Each glyph is pinned to a physical button position rather than to a label, so
the setting stays correct whichever way **Menu → Invert Buttons** is set. That
option changes which button confirms and which goes back, and the help strip's
*text* follows it — but a given shape never moves to a different button.

The d-pad, shoulder, START and SELECT glyphs are shared by all three sets:
those are the same on every layout. Shoulders stay `L`/`R` rather than becoming
`LB`/`RB` for the Xbox set, which is also what the Brick's own shoulders say.
The glyphs are monochrome and tinted with the colorset, so Xbox's green/red/
blue/yellow colour coding is not reproduced — ES multiplies help icons by the
theme's icon colour, which cannot preserve four separate hues.

### Gamelist Style

UI Settings → Theme Configuration → **Gamelist Style**:

- **PSP Card** (default) — the XMB card layout. Selected game expands into a
  large card with box art, screenshot/video, and a bounded description.
- **List + Details** — a ten-row title list with art, metadata and description.
- **Box Art Grid** — a wall of cover art with an info bar. The selected
  game is shown by being **enlarged**, and nothing else: no highlight box,
  and the other covers are not dimmed. A game title too long for the info
  bar is trimmed at the bar's edge rather than spilling past it.

In **PSP Card** and **List + Details** (Box Art Grid has no media slot by
design), the screenshot becomes a video preview after the delay set by
**Video Delay**. Videos play at their own aspect ratio; a clip that was
scraped with letterboxing baked in will keep it. Whether that slot shows an
actual screenshot or a second copy of the box art depends on your scraper:
it's driven by the game's `<image>` tag, which most scrapers fill
separately from `<thumbnail>` — if your scraper (or a manual edit) points
both at the same file, the media slot will just mirror the box art.

**Box Art Grid requires UI Settings → Gamelist View Style = Automatic**
(ES's own default, under a different menu from this theme's settings). If
that setting is pinned to Detailed or Gamecarousel, ES ignores this theme's
requested view and renders an unstyled gamelist instead of the grid — this
theme cannot detect or override that preference. Switching back to
Automatic restores the grid.

The old Gamelist View Style knob this theme used to expose (`detailed` /
`gamecarousel`) was removed in v0.11, when both view-style names resolved
to the same single card layout. v0.12's Gamelist Style is a different,
theme-level choice — it doesn't read ES's own Gamelist View Style setting
at all (except for the Box Art Grid interaction above).

The wave animation is always on with no opt-out. No per-system or per-device overrides — the theme intentionally ships minimal.

The status bar runs clock, network glyph, battery percentage and battery glyph as one right-anchored cluster that **re-packs itself around whatever is showing**. **The battery elements are controlled by EmulationStation's own setting, not by the theme** — *UI Settings > Show Battery Status*: NO hides both, ICON shows the glyph alone, ICON AND TEXT (the ES default) shows the glyph and the percentage. A device with no battery shows neither, automatically. In every case the cluster simply gets shorter and stays flush to the right margin — no gaps are left behind, and the same is true when *Show Clock* is off or there is no network connection. The network glyph is EmulationStation's binary connected/not-connected indicator, redrawn in the theme's style; a PSP-style 4-bar signal strength is not available to themes at all.

## How the wave is built

The PSP XMB wave is rendered entirely via ES storyboard property animation on static PNGs — no video, no animated GIF (animated images aren't supported in this ES build):

- A flat dark colorset-tinted `wave.png` provides the canvas.
- Three transparency-channel PNGs (`wave-layer-{1,2,3}.png`) are stacked on top, each with a sine-shaped opaque-to-transparent boundary at a different vertical position. Tinted with `${accent}` so each appears as a bright wave band.
- Each layer is 2× screen width with a horizontally-seamless pattern (integer cycles per screen width) and scrolls left at a different rate (30s / 20s / 12s per full cycle). The seamless wrap makes the storyboard repeat visually invisible.
- A pure-white 4-pixel rim highlight at each wave's upper edge makes the crest pop against the body.

The PNGs are generated procedurally by a small Python script (see commit history for `wave-layer-*.png` for parameters). They're sized at 2048×1080 so the design scales cleanly to higher-resolution devices than the 1024×768 Brick this was developed on.

## Troubleshooting

If the theme breaks EmulationStation on startup, SSH still works. To force the device back to the built-in `carbon` theme:

**Knulli:**
```
ssh root@<your-device-ip> "knulli-settings-set theme.set carbon && sed -i 's|<string name=\"ThemeSet\" value=\"[^\"]*\"|<string name=\"ThemeSet\" value=\"carbon\"|' /userdata/system/configs/emulationstation/es_settings.cfg && knulli-es-swissknife --restart"
```

**Batocera:**
```
ssh root@<your-device-ip> 'batocera-settings-set theme.set carbon && batocera-es-swissknife --restart'
```

Knulli stores the theme name in two places (`theme.set` in `knulli.conf` and `ThemeSet` in `es_settings.cfg`) — if they diverge, ES enters a restart loop. The Knulli command above updates both atomically.

**No sounds at all?** EmulationStation ships with navigation sounds turned
**off** — see [Navigation sounds](#navigation-sounds) above. Turn on *Main
Menu → Sound Settings → Enable Navigation Sounds*.

**Still nothing after turning it on?** Restart EmulationStation. ES skips
loading a sound file entirely while that setting is off, and switching it on
does not reload the ones it already skipped — they are only re-read when the
audio system restarts, which happens at ES startup and on returning from a
game. Launching and quitting any game works too.

## Development

Theme development and verification use the **Docker render harness** — it runs batocera-emulationstation headless in Docker and screenshots the theme at any resolution, with no physical device required. See [`docker/README.md`](docker/README.md):

```
./scripts/render.sh --view system
./scripts/render.sh --view gamelist --library <path> --resolution 1280x720
VIDEO_DELAY=Instant ./scripts/render.sh --view gamelist --library <path> --settle 4
./scripts/render.sh --view splash --library <path>          # SPLASH_AT=0.4 by default
```

`--view splash` is the odd one out: it launches ES *with* the boot splash the
harness otherwise suppresses, and grabs the frame `SPLASH_AT` seconds later.
That frame is transient — it is gone within about a second, sooner at smaller
resolutions — so the capture is a race rather than a settled state. Sweep it
with `--frames N --frame-interval 0.2` (both accept fractions) and keep the
frame that lands; an all-black capture means ES had not opened its window yet,
and a carousel means the splash was already over.

Preview video plays in the harness. Renders pin the Video Delay to 10s so a
capture lands on the still screenshot rather than an arbitrary video frame;
pass `VIDEO_DELAY` and `--settle` when the video is what you want to see.

The harness can also **hear** itself, which a screenshot cannot:
`scripts/capture-audio.sh` runs ES under SDL's `disk` audio driver and
measures the mixer's actual output, so a sound binding can be verified rather
than assumed. `--expect` turns a capture into a pass/fail test.

```
./scripts/capture-audio.sh --library /tmp/library
./scripts/capture-audio.sh --library /tmp/library \
  --script "right:2,confirm:3,down:2" --expect sound,any,sound
```

Note that ES ships navigation sounds **off**, so the tool pins `EnableSounds`
on by default — otherwise every capture would be silent and pass vacuously.
See [`docker/README.md`](docker/README.md) for the details.


### Regenerating the README's screenshots

Every image this README commits is produced by one script, so no one has to
work out which flag combination made which file:

```
./scripts/render-readme-assets.sh --library /tmp/library
./scripts/render-readme-assets.sh --library /tmp/library --only colorsets
./scripts/render-readme-assets.sh --library /tmp/library --skip-gif
```

It needs a library with **real scraped media** — box art, screenshots,
ratings and full-length descriptions. `tests/fixtures/library` is deliberately
degenerate (its longest description is 74 characters) and would make the
layout look better than it is; it is the regression corpus, not the marketing
corpus. The script refuses to run without `--library` for that reason.

The animated GIF comes from `scripts/record.sh`, which drives navigation with
a scripted key sequence while capturing frames on a uniform interval:

```
./scripts/record.sh --library /tmp/library --keep-frames
./scripts/record.sh --library /tmp/library --script "right:1.5,right:1.5" --fps 8
```

Its defaults reproduce the committed GIF. The capture rate tops out near 11fps
— a screen grab costs about 90ms at 1280×720 — and the GIF's frame delay is
derived from the rate actually achieved, so a slower machine produces a longer
capture rather than a GIF that plays too fast.

`scripts/tests/test-readme-assets.sh` guards the result: it fails if the README
references an image that is not in the tree, if the colorset gallery drifts
from `theme.xml`, or if either committed artifact exceeds its size budget.

The legacy on-device scripts (`scripts/deploy.sh`, `scripts/ui.sh`) are retained as a dormant fallback only and are no longer part of the routine workflow.

## Contributing

Bug reports, renders and pull requests are welcome — see [CONTRIBUTING.md](CONTRIBUTING.md). You do not need a handheld to work on this theme: `scripts/render.sh` runs EmulationStation headless in Docker and screenshots the result.

## Credits and license

This is a derivative work. See [CREDITS.md](CREDITS.md) for the full attribution chain.

Licensed under **Creative Commons CC-BY-NC-SA 2.0** — see [LICENSE](LICENSE). You may share and adapt this theme for non-commercial purposes, must credit the upstream authors, and must license derivatives under the same terms.
