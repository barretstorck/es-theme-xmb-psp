# Credits

## Design lineage

- **PSP XMB (Cross Media Bar)** — Sony Computer Entertainment, 2004.
  Visual design inspiration only; no assets used.

## Theme lineage

- **XMB-Easy-Theme** — InitialDin. Original EmulationStation XML; the lineage starts here.
- **XMB Menu ES-DE** — Ant (anthonycaccese). ES-DE refactor with refreshed assets, color schemes, aspect-ratio support. CC-BY-NC-SA 2.0. https://github.com/anthonycaccese/xmb-menu-es-de
- **es-theme-xmb-psp** — Barret Storck. Port to batocera-emulationstation for Knulli Scarab / TrimUI Brick. CC-BY-NC-SA 2.0.

## Assets used in this port

| Asset | Source | Origin author / license |
|---|---|---|
| Wave background | XMB Menu ES-DE | Ant — CC-BY-NC-SA 2.0 |
| System icons (majority, v0.11+) | RetroArch `monochrome` XMB set | RetroArch/libretro contributors — CC-BY 4.0 (modified: pre-burned drop shadows via `scripts/apply-shadow.py`; see "RetroArch `monochrome` icon set" section below) |
| System icons (remainder) | XMB Menu ES-DE | Ant — CC-BY-NC-SA 2.0 (see "Icon attribution (v0.4)" section below) |
| UI chrome (selector, separators) | XMB Menu ES-DE | Ant — CC-BY-NC-SA 2.0 |
| Sound effects | XMB Menu ES-DE | Ant — CC-BY-NC-SA 2.0 |
| Font: Roboto Condensed (Light/Regular/Bold) | [Google Fonts](https://fonts.google.com/specimen/Roboto+Condensed) | The Roboto Project Authors — SIL OFL 1.1 (see `fonts/OFL.txt`) |

**Font substitution:** the PSP/PS3 XMB and the source theme use proprietary Sony / Fontworks fonts (the *New Rodin* family), which are not redistributable. This port uses [Roboto Condensed](https://fonts.google.com/specimen/Roboto+Condensed) — the same free, OFL-licensed font the PPSSPP PSP emulator ships as its substitute for the original PSP system font, so it carries a close PSP-XMB feel. The Light/Regular/Bold weights bundled in `fonts/` are static instances generated from the official OFL variable font (`RobotoCondensed[wght].ttf` from Google Fonts) at weights 300 / 400 / 700.

## Not yet used (would re-add credit if included later)

- **Physical media icons** — 7 media-type fallback icons now generated procedurally into `art/system-media/` (`scripts/gen-media-fallbacks.py`), but not yet wired into any view.
- **Controller icons** — RobZombie9043. (Not currently in any view.)

## Icon attribution (v0.4)

Most system icons in `art/system-icons/` are inherited from the parent
theme chain documented above (same CC-BY-NC-SA 2.0 license).

The following icons were additionally harvested in v0.4 from
[xmb-menu-es-de](https://github.com/anthonycaccese/xmb-menu-es-de) by
**anthonycaccese**, CC-BY-NC-SA 2.0, for systems that were previously
falling back to a generic placeholder:

amiga, astrocade, atarijaguar, atarijaguarcd, atarilynx, auto-favorites,
auto-lastplayed, bbcmicro, msx, odyssey2, pc, sg-1000, wonderswan,
wonderswancolor

Note: ES auto-collections (all, favorites, recent) actually use theme
folder names `auto-allgames`, `auto-favorites`, `auto-lastplayed` per
batocera-emulationstation's `CollectionSystemManager.cpp`. Our icons
are saved under those longer names so the carousel renders them as
icons rather than text. `auto-allgames.png` falls back to `_default.png`
(upstream's `auto-allgames.png` is byte-identical to `_default.png`).

Systems without a hand-tuned or harvested icon use a generic `_default.png`
placeholder (which itself comes from the upstream parent-theme chain).
To override: drop a hand-tuned `<system-shortname>.png` into
`art/system-icons/`.

## RetroArch `monochrome` icon set

Icons in `art/system-icons/` derived from the RetroArch `monochrome`
XMB icon set:

- Source: [libretro/retroarch-assets](https://github.com/libretro/retroarch-assets) → `xmb/monochrome/png/`
- License: CC-BY 4.0
- Used for: 134 system-specific icons (mapping manifest:
  `scripts/ra-mapping.tsv`, imported via `scripts/import-ra-icons.sh`),
  utility/auto-collection icons, and as the design reference for 8
  hand-authored port icons (`scripts/gen-port-icons.py`).
- Modifications (per CC-BY 4.0 attribution requirements): files renamed
  to Knulli `es_systems.cfg` shortnames, and a drop shadow (4px blur,
  3px Y offset, 35% black) pre-burned into every icon via
  `scripts/apply-shadow.py`. No other visual edits.

