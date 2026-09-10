# Credits

## Design lineage

- **PSP XMB (Cross Media Bar)** — Sony Computer Entertainment, 2004.
  Visual design inspiration only; no assets used.

## Theme lineage

- **XMB-Easy-Theme** — InitialDin. Original EmulationStation XML; the lineage starts here.
- **XMB Menu ES-DE** — Ant (anthonycaccese). ES-DE refactor with refreshed assets, color schemes, aspect-ratio support. CC-BY-NC-SA 2.0. https://github.com/anthonycaccese/xmb-menu-es-de
- **es-theme-xmb-psp** — Barret Storck. Port to batocera-emulationstation for Knulli Scarab / TrimUI Brick. CC-BY-NC-SA 2.0.

## Licence chain

The theme ships under **CC-BY-NC-SA 2.0** (`LICENSE`). This is not a free
choice: the parent theme, XMB Menu ES-DE, is CC-BY-NC-SA 2.0, and its
ShareAlike clause requires derivatives to carry the same licence (or a later
version of it). The NonCommercial term is inherited along with the assets.

Practical consequence: **this theme cannot be bundled into a commercially
distributed image.** Non-commercial distro images and individual users are
unaffected.

Inputs under other licences, and why they are compatible:

| Input | Licence | Why it composes |
|---|---|---|
| RetroArch `monochrome` XMB icons | CC-BY 4.0 | Permissive; may be incorporated into a more restrictive work provided attribution is retained (see below). |
| Roboto Condensed | SIL OFL 1.1 | Fonts are licensed independently and redistributed verbatim under `fonts/OFL.txt`; the OFL does not extend to the theme. |
| XMB Menu ES-DE assets | CC-BY-NC-SA 2.0 | Same licence as this work. |

## Assets used in this port

Every directory under `art/` appears here. "This port" means authored for this
repository and covered by its CC-BY-NC-SA 2.0 licence.

| Asset | Path | Source | Origin author / licence |
|---|---|---|---|
| Wave background (3 parallax layers + composite) | `art/wave/` | XMB Menu ES-DE | Ant — CC-BY-NC-SA 2.0 |
| System icons — majority (v0.11+) | `art/system-icons/` | RetroArch `monochrome` XMB set | RetroArch/libretro contributors — CC-BY 4.0 (modified; see "RetroArch `monochrome` icon set" below) |
| System icons — remainder and `_default.png` | `art/system-icons/` | XMB Menu ES-DE | Ant — CC-BY-NC-SA 2.0 (see "Icon attribution (v0.4)" below) |
| System icons — 8 port icons | `art/system-icons/` | This port (`scripts/gen-port-icons.py`) | Barret Storck — CC-BY-NC-SA 2.0; drawn against the RA `monochrome` set as a style reference |
| UI chrome — selector fill, hairline separator | `art/ui/panel-fill.png`, `art/line-1px.png` | This port | Barret Storck — CC-BY-NC-SA 2.0 |
| UI chrome — network glyph | `art/ui/network.png` | This port (`scripts/gen-network-icon.py`) | Barret Storck — CC-BY-NC-SA 2.0 |
| Boot-splash wordmark | `art/ui/splash-wordmark.png` | This port (`scripts/gen-splash-wordmark.py`) | Barret Storck — CC-BY-NC-SA 2.0; set in Roboto Condensed (OFL 1.1) |
| Battery glyphs (6 states) | `art/battery/` | This port (`scripts/gen-battery-icons.py`) | Barret Storck — CC-BY-NC-SA 2.0 |
| Helpsystem button glyphs (16) | `art/help/` | This port (`scripts/gen-help-icons.py`) | Barret Storck — CC-BY-NC-SA 2.0; PSP face-button shapes are generic geometry, not Sony artwork |
| Physical-media fallback icons (7) | `art/system-media/` | This port (`scripts/gen-media-fallbacks.py`) | Barret Storck — CC-BY-NC-SA 2.0 |
| Sound effects (`navigate` / `select` / `back`) | `sounds/` | XMB Menu ES-DE | Ant — CC-BY-NC-SA 2.0 |
| Font: Roboto Condensed (Light/Regular/Bold) | `fonts/` | [Google Fonts](https://fonts.google.com/specimen/Roboto+Condensed) | The Roboto Project Authors — SIL OFL 1.1 (see `fonts/OFL.txt`) |

No Sony-authored asset — icon, font, sound or wave frame — ships in this
repository. The sound effects are Ant's originals from XMB Menu ES-DE, not
samples ripped from PSP or PS3 firmware.

**Font substitution:** the PSP/PS3 XMB and the source theme use proprietary Sony / Fontworks fonts (the *New Rodin* family), which are not redistributable. This port uses [Roboto Condensed](https://fonts.google.com/specimen/Roboto+Condensed) — the same free, OFL-licensed font the PPSSPP PSP emulator ships as its substitute for the original PSP system font, so it carries a close PSP-XMB feel. The Light/Regular/Bold weights bundled in `fonts/` are static instances generated from the official OFL variable font (`RobotoCondensed[wght].ttf` from Google Fonts) at weights 300 / 400 / 700.

## Inherited credits carried forward

XMB Menu ES-DE credits two upstream sources whose assets this port does **not**
ship. They are recorded so the lineage stays complete, and would need crediting
if either were ever pulled in:

- **System controller icons** — RobZombie9043 (XMB ES-DE project). Not present in this repository.
- **System physical-media icons** — RetroArch `monochrome` set, via XMB Menu ES-DE. Not present in this repository; `art/system-media/` is this port's own procedurally generated set (`scripts/gen-media-fallbacks.py`), drawn independently.

## Icon accounting

`art/system-icons/` ships **201** PNGs. Every one traces to a licensed source:

| Count | Origin | Licence |
|---:|---|---|
| 150 | RetroArch `monochrome` XMB set (137 hardware systems + 13 utility / auto-collection / media graphics), mapped by `scripts/ra-mapping.tsv` | CC-BY 4.0 |
| 13 | Distinct icons inherited from XMB Menu ES-DE | CC-BY-NC-SA 2.0 |
| 30 | `_default.png` (inherited from XMB Menu ES-DE) and 29 byte-identical copies of it, standing in for systems with no dedicated icon | CC-BY-NC-SA 2.0 |
| 8 | Hand-authored port icons (`scripts/gen-port-icons.py`) | CC-BY-NC-SA 2.0 (this port) |
| **201** | | |

To re-derive these counts against the tree, see `scripts/tests/test-credits-accounting.sh`.

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

Several of these were later re-sourced from the RetroArch `monochrome` set in
v0.11; the attribution is retained because the v0.4 assets are still in the
repository's history.

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
- Used for: **150** icons — 137 hardware systems and 13 utility /
  auto-collection / media graphics (mapping manifest:
  `scripts/ra-mapping.tsv`, imported via `scripts/import-ra-icons.sh`) —
  and as the design reference for 8 hand-authored port icons
  (`scripts/gen-port-icons.py`).
- Modifications (per CC-BY 4.0 attribution requirements): files renamed
  to Knulli `es_systems.cfg` shortnames, and a drop shadow (4px blur,
  3px Y offset, 35% black) pre-burned into every icon via
  `scripts/apply-shadow.py`. No other visual edits.
