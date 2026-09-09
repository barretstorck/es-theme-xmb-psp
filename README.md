# es-theme-xmb-psp

A PSP XMB-style theme for [batocera-emulationstation](https://github.com/batocera-linux/batocera-emulationstation), built and tuned for **Knulli Scarab on the TrimUI Brick** (4:3, 1024×768).

> Status: **v0.12** — PSP-style variant only. **System icons adopted from the RetroArch `monochrome` XMB set** (filled-silhouette style, CC-BY 4.0): 134 system shortnames mapped from the RA set plus 8 hand-authored port icons in the same style, all with pre-burned drop shadows. **The selected-icon halo is currently disabled** (re-tuned in PR #28, then pulled again during PR #32's on-device rounds as still too bright — re-enable tracked in issue #34). **Three user-selectable gamelist styles** (see Gamelist Style below): a PSP-card layout where each game is a collapsed row that expands into a card with box art, a screenshot that becomes a preview video, and a bounded description; a ten-row list with metadata and description; and a box-art grid. Five tuned aspect ratios (4:3, 16:9, 3:2, 1:1, 8:7), with constant gap-to-icon ratio for the system carousel across all ratios. Twelve user-selectable PSP-month colorsets, **continuous PSP XMB wave animation that no longer resets on system carousel navigation**, XMB cross layout, optional game counter, a colorset-themed EmulationStation menu, universal system icon coverage. Clock-only status bar (the battery widget remains pulled pending redesign, issue #4). Default colorset is January Blue.

## Screenshots

### System view (XMB cross + system carousel)

| 4:3 (1024×768) | 16:9 (1280×720) | 3:2 (720×480) | 1:1 (720×720) | 8:7 (1024×896) |
|:---:|:---:|:---:|:---:|:---:|
| ![](docs/screenshots/system-4x3.png) | ![](docs/screenshots/system-16x9.png) | ![](docs/screenshots/system-3x2.png) | ![](docs/screenshots/system-1x1.png) | ![](docs/screenshots/system-8x7.png) |

### Gamelist — PSP Card style (default: Boxart icons, PSP-Faithful titles)

Screenshots below predate the v0.12 media-block/metadata recomposition
(§6.7 of the style guide) and the List + Details / Box Art Grid styles;
they still show the general PSP-card shape. Regenerate before the next
screenshot refresh.

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

- System icon coverage is mixed-source: 134 shortnames use icons from the RetroArch `monochrome` XMB set, 8 ports use hand-authored icons in the same style (`scripts/gen-port-icons.py`), and ~56 less-common shortnames retain icons from the previous XMB Menu ES-DE set. Systems still without a specific icon fall back to a generic `_default.png` placeholder. To add or replace an icon, drop `<system-shortname>.png` into `art/system-icons/` — but run it through `scripts/apply-shadow.py` once (the script is not idempotent; don't re-run it on an already-shadowed icon) so it matches the pre-burned drop-shadow treatment of the shipped icons. See [CREDITS.md](CREDITS.md) for icon sources and licenses. Note: ES auto-collections use theme-folder names with an `auto-` prefix (e.g., `auto-allgames.png`, `auto-favorites.png`, `auto-lastplayed.png`) rather than the short collection name.
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
- **Box Art Grid** — a wall of cover art with an info bar.

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

The status bar is clock-only. The selected-icon halo remains pulled: restored and re-tuned during v0.11 (PR #28, 0.28 footprint / 0.6 opacity), it was disabled again in PR #32's on-device tuning as still too bright — re-enable is tracked in issue #34. The battery widget also remains pulled, pending redesign (issue #4).

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

The legacy on-device scripts (`scripts/deploy.sh`, `scripts/ui.sh`) are retained as a dormant fallback only and are no longer part of the routine workflow.

## Credits and license

This is a derivative work. See [CREDITS.md](CREDITS.md) for the full attribution chain.

Licensed under **Creative Commons CC-BY-NC-SA 2.0** — see [LICENSE](LICENSE). You may share and adapt this theme for non-commercial purposes, must credit the upstream authors, and must license derivatives under the same terms.
