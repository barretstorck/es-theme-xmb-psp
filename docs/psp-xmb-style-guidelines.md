# PSP XMB Style Guidelines

Canonical reference for designing and tuning `es-theme-xmb-psp`. Models its
structure on Material Design and Apple Human Interface Guidelines: principle
+ measurement, not principle alone. Every claim about a position, size,
colour, or timing resolves either to a Sony-authored value, a value
verifiable in one of the three reference videos, or a value the theme has
empirically settled on across eleven releases (v0.1 → v0.11 partial).

**Document status:** v0.11-partial baseline (July 2026). Re-check after any major
theme release. Cross-references to
[`docs/psp-authenticity-audit.md`](psp-authenticity-audit.md) use the audit
section codes (S, G, ST, A, X, U).

**Audience:** future contributors editing `_inc/common.xml`, the
per-aspect-ratio files, the colorset definitions, or the view templates.
You do not need to re-derive any of these from the reference videos
yourself — those derivations are recorded here.

---

## Table of contents

1. [Foundation](#1-foundation)
   - 1.1 [Authoritative sources and what they cover](#11-authoritative-sources-and-what-they-cover)
   - 1.2 [Design principles](#12-design-principles)
   - 1.3 [Aspect-ratio philosophy](#13-aspect-ratio-philosophy)
   - 1.4 [Native resolution context](#14-native-resolution-context)
   - 1.5 [Coordinate system](#15-coordinate-system)
2. [Layout](#2-layout)
   - 2.1 [The XMB cross](#21-the-xmb-cross)
   - 2.2 [Cross anchor per aspect ratio](#22-cross-anchor-per-aspect-ratio)
   - 2.3 [Safe zones and reserved regions](#23-safe-zones-and-reserved-regions)
   - 2.4 [Z-index stack](#24-z-index-stack)
3. [Color](#3-color)
   - 3.1 [Semantic color tokens](#31-semantic-color-tokens)
   - 3.2 [The twelve monthly colorsets](#32-the-twelve-monthly-colorsets)
   - 3.3 [Authoring a new colorset](#33-authoring-a-new-colorset)
   - 3.4 [Halo / glow tinting](#34-halo--glow-tinting)
   - 3.5 [Readability minimums](#35-readability-minimums)
4. [Typography](#4-typography)
   - 4.1 [Font family and weights](#41-font-family-and-weights)
   - 4.2 [Type scale](#42-type-scale)
   - 4.3 [Alignment](#43-alignment)
   - 4.4 [Why not the PSP's font](#44-why-not-the-psps-font)
5. [Iconography](#5-iconography)
   - 5.1 [Two-tier hierarchy](#51-two-tier-hierarchy)
   - 5.2 [Canvas and rendering sizes](#52-canvas-and-rendering-sizes)
   - 5.3 [Per-slot rendering size](#53-per-slot-rendering-size)
   - 5.4 [Helpsystem glyphs](#54-helpsystem-glyphs)
6. [Components](#6-components)
   - 6.1 [Category icons (system carousel)](#61-category-icons-system-carousel)
   - 6.2 [Selected-icon halo](#62-selected-icon-halo)
   - 6.3 [System name caption](#63-system-name-caption)
   - 6.4 [Game count caption (optional)](#64-game-count-caption-optional)
   - 6.5 [Top-right status cluster](#65-top-right-status-cluster)
   - 6.6 [Helpsystem strip](#66-helpsystem-strip)
   - 6.7 [Gamelist — detailed (text list)](#67-gamelist--detailed-text-list)
   - 6.8 [Gamelist — gamecarousel (boxart column)](#68-gamelist--gamecarousel-boxart-column)
   - 6.9 [Info panel (title / rating / video / description)](#69-info-panel-title--rating--video--description)
   - 6.10 [Menu chrome](#610-menu-chrome)
7. [Motion](#7-motion)
   - 7.1 [Wave animation](#71-wave-animation)
   - 7.2 [Carousel transition style](#72-carousel-transition-style)
   - 7.3 [Halo scroll fade](#73-halo-scroll-fade)
   - 7.4 [Description auto-scroll](#74-description-auto-scroll)
   - 7.5 [Video preview delay](#75-video-preview-delay)
   - 7.6 [What we cannot animate](#76-what-we-cannot-animate)
8. [Subsets and user knobs](#8-subsets-and-user-knobs)
9. [Sound](#9-sound)
10. [Settled decisions — do not re-litigate](#10-settled-decisions--do-not-re-litigate)
11. [References](#11-references)

---

## 1. Foundation

### 1.1 Authoritative sources and what they cover

Sony published exactly one document that constitutes a primary source for
PSP XMB visual specs: the **PSP™ Custom Theme Creation Guidelines** (v3.70,
v5.00; v5.00 is the canonical late-firmware revision). It is the basis
for every measurement in §5.2 and the canonical-month observation in §3.2.
It is, however, narrow in scope: it specifies *only* the asset side of the
theming surface (icon bitmaps, focus bitmaps, wallpaper, preview, and the
list of twelve month-color selectors). It does **not** specify:

- The screen-coordinate placement of the cross (no x/y for icons).
- The size at which icons are rendered on screen (only the source bitmap
  resolution).
- The wave background motion (timing, layer count, opacity).
- Font face, size, leading, or hierarchy.
- Helpsystem strip layout.
- Sub-item row layout, halo gaussian size, focus-pulse cadence.

For each of those, the reference videos in
[`/tmp/psp-xmb-videos/frames/`](#) (video B real PSP at 1920×1080, video C
real PSP at 1280×720, video A PS2 XMB clone at 1280×720) and this theme's
own eleven-release iteration history are the working source of truth. Where
a measurement is derived from a video frame this document cites the
specific frame; where a measurement is settled by on-device testing it
cites the relevant XML file.

Two additional sources of partial authority are referenced:

- **psdevwiki** (https://www.psdevwiki.com/psp/ and /ps3/) — community
  reverse-engineering wiki. Used for the canonical PS3-era month colour
  hex codes in §3.2 and the PSP filesystem layout in §3.2's discussion.
  Treated as semi-authoritative: psdevwiki staff have direct experience
  with extracted firmware files, and the hex codes are testable against
  the videos.
- **RetroArch's `xmb.c`** (https://github.com/libretro/RetroArch/blob/master/menu/drivers/xmb.c)
  and its `monochrome` icon theme — open-source XMB-style implementation
  with measurable defaults. Used as a corroborating cross-reference for
  filled-silhouette icon conventions only; its layout maths differ from
  EmulationStation's and are not a layout source for this theme.

If a future contributor uncovers a SCEI-internal layout doc, an
authoritative monthly hex palette beyond psdevwiki's, or extracted
firmware RCOXML that fixes the wave timing constants, the relevant
section of this document should be revised and the new source cited
in §11.

### 1.2 Design principles

The PSP XMB has a recognizable feel that this theme aims to reproduce.
Four principles, in order of importance:

**1. Quiet.** The interface never raises its voice. There is no flashing,
no high-saturation accent, no "call-out" element that out-shouts the
content. Text is white on a dark wave. The wave itself moves slowly
enough that you only notice the motion when looking for it.

**2. Glassy.** Every solid element reads as semi-translucent or has a
soft luminous edge. The wave appears refractive. The selected icon
appears to be lit from behind, not from above (the halo is a back-light,
not a frame). The right-side info panel does not have an opaque
background.

**3. Dimensional.** The cross is the depth metaphor: horizontal axis is
"breadth of categories," vertical axis is "depth into a category." The
selected slot in either axis is the focal point; everything else fades
outward in opacity, not in position. There is no z-axis perspective
trick — the dimensionality is in the navigation model, not in 3D
rendering.

**4. Settled.** The interface, when idle, looks composed — not animated,
not loading, not waiting. Motion is reserved for the wave (continuous
and slow) and selection transitions (fast, ~150ms). No element fades in
or out arbitrarily. No element pulses for attention. (The PSP focus
pulse on the selected icon is an exception we do not replicate — see
§7.6.)

### 1.3 Aspect-ratio philosophy

EmulationStation themes specify positions and sizes as normalized
fractions of the screen (0.0 to 1.0 per axis). On a non-square screen
this means horizontal and vertical units are not equal in pixels.
A "square" element with `<size>0.10 0.10</size>` on a 1280×720 screen
renders as a 128×72-pixel rectangle.

This theme works around that by defining 26 named geometry variables
in `_inc/common.xml` and overriding them per aspect ratio in
`_inc/aspect-{8x7,3x2,16x9,1x1}.xml`. The override files are loaded
conditionally by `theme.xml`:

```xml
<include if="${screen.ratio} == '16/9'">./_inc/aspect-16x9.xml</include>
```

Four principles govern when a value should differ per aspect ratio:

- **P1 — Squareness in pixels.** Icons should look square (or square-ish)
  on every device. A `<maxSize>0.12 0.16</maxSize>` works at 4:3 because
  `0.12 × 1024 = 123px` and `0.16 × 768 = 123px` happen to coincide. On
  16:9 the same fractions would yield 154×115px (visibly squat), so
  16:9 overrides both halves to `0.10 0.17`.
- **P2 — Cross balance.** The cross anchor `(crossX, crossY)` shifts
  per ratio so the right-side info panel doesn't push the cross off the
  left edge. Wider screens (16:9): `crossX=0.20`. Narrower (1:1):
  `crossX=0.22`. Default (4:3, 3:2, 8:7): `crossX=0.24`.
- **P3 — Info-panel fit.** Wider screens get a wider info panel. 4:3 →
  `panelW=0.55`. 16:9 → `panelW=0.58`. 1:1 → `panelW=0.56`.
- **P4 — Video aspect.** The `<video>` element's `(W, H)` fractions
  must produce a 4:3 video box in pixels — `W/H = (4/3) × (screenH/screenW)`.
  At 1:1 that's `(4/3) × (1/1) = 4/3` → `mdVideoW=0.44, mdVideoH=0.33`.

The full per-ratio override table is in §2.2 (cross anchor) and §5.3
(icon sizes). The reasoning trail is in
[`docs/superpowers/specs/2026-05-23-v0.8-multi-aspect-ratio-design.md`](superpowers/specs/2026-05-23-v0.8-multi-aspect-ratio-design.md).

### 1.4 Native resolution context

The original PSP firmware ran at **480×272 pixels** (the LCD's native
resolution; the PSP-2000/3000 series shared this resolution).
EmulationStation themes built today target a range from 720×480
(small handhelds) up to 1920×1080 (TV-tethered setups). The five
verified targets:

| Aspect | Display surface | Example device |
|:---|:---:|:---|
| 4:3 | 1024×768 | TrimUI Brick (primary target — Knulli Scarab) |
| 16:9 | 1280×720 | TV / desktop docked |
| 3:2 | 720×480 | RG35XX class |
| 1:1 | 720×720 | RG Cube X |
| 8:7 | 1024×896 | Vertical Anbernic handhelds |

Other ratios silently fall back to the 4:3 layout. The theme will render
but may letterbox or stretch. Don't expand the supported list without
authoring and committing a verified `aspect-*.xml` override file plus a
screenshot in `docs/screenshots/`.

### 1.5 Coordinate system

ES uses normalized coords with origin at the top-left:

- `(0.0, 0.0)` — top-left pixel
- `(1.0, 0.0)` — top-right
- `(0.5, 0.5)` — center
- `(1.0, 1.0)` — bottom-right

`<origin>` defaults to `(0, 0)` (the element's top-left anchors at
`<pos>`); set `<origin>0.5 0.5</origin>` to center-anchor.

`<size>` is the element's bounding box; `<maxSize>` is an
aspect-preserving fit (an image scales down to fit but never up).
`<size>` overrides `<maxSize>` when both are set.

Z-order is `<zIndex>` — higher renders on top. Default is `0`.

---

## 2. Layout

### 2.1 The XMB cross

The cross is two perpendicular axes meeting at the **cross anchor**,
the point `(crossX, crossY)`. The selected category icon centers
exactly on the anchor.

- **Horizontal axis (top row).** All category icons share one
  `<carousel>` element whose center registration point sits at
  `(crossX, 0.291)` (= `(crossX, crossY)`). The carousel container
  spans the full screen width or wider so unselected icons extend
  off-screen left and right. As the user navigates left/right, icons
  slide horizontally through the anchor point; the icon at the anchor
  is the selected one.

- **Vertical axis (sub-item column).** For the gamelist views,
  sub-items render in a vertical carousel or textlist whose
  horizontal center sits at `crossX` (well, technically `gameColX`,
  which is slightly to the left of `crossX` — see §2.2). The selected
  sub-item centers on its own y-coordinate (`gameColTextY` for textlist,
  the centred slot for `gamecarousel`).

- **Caption.** Directly below the selected category icon sits the
  system-name caption at `(crossX, captionY)`. `captionY` (`0.401` in
  4:3) is offset down from `crossY` (`0.291`) by ~`0.110` — i.e., the
  caption baseline sits ~11% of screen height below the icon center.
  Optional second caption (game count) at `countY` (`0.456`) when the
  Game Count subset is set to Show.

Reference: video C @ 0:15 (frame v3-001 region) — the Settings icon
sits at horizontal center ~0.23 of frame, vertical center ~0.30; its
caption "Settings" reads at vertical ~0.40. Matches `crossX=0.24,
crossY=0.291, captionY=0.401` within rounding.

### 2.2 Cross anchor per aspect ratio

The cross anchor and the geometry that depends on it varies per
aspect ratio. **This table is the canonical lookup.** Cite
`_inc/aspect-*.xml` when grounding any of these.

| Variable | 4:3 (default) | 16:9 | 3:2 | 1:1 | 8:7 |
|:---|:---:|:---:|:---:|:---:|:---:|
| `crossX` | `0.24` | `0.20` | `0.24` | `0.22` | `0.24` |
| `crossY` | `0.291` | `0.291` | `0.291` | `0.27` | `0.291` |
| `captionY` | `0.401` | `0.401` | `0.401` | `0.38` | `0.401` |
| `countY` | `0.456` | `0.456` | `0.456` | `0.456` | `0.456` |
| `gameColX` | `0.08` | `0.06` | `0.08` | `0.06` | `0.08` |
| `gameColW` | `0.32` | `0.32` | `0.32` | `0.32` | `0.32` |
| `gameColTextY` | `0.50` | `0.50` | `0.50` | `0.47` | `0.50` |
| `gameColCarY` | `0.46` | `0.46` | `0.46` | `0.33` | `0.46` |
| `gameColH` | `0.42` | `0.42` | `0.42` | `0.46` | `0.42` |
| `panelX` | `0.43` | `0.40` | `0.42` | `0.40` | `0.43` |
| `panelW` | `0.55` | `0.58` | `0.56` | `0.56` | `0.55` |
| `panelDescY` | `0.60` | `0.60` | `0.60` | `0.58` | `0.60` |
| `panelDescH` | `0.32` | `0.32` | `0.32` | `0.36` | `0.32` |
| `mdRatingX` | `0.615` | `0.615` | `0.615` | `0.59` | `0.615` |
| `mdVideoX` | `0.705` | `0.705` | `0.705` | `0.68` | `0.705` |
| `mdVideoY` | `0.39` | `0.39` | `0.39` | `0.37` | `0.39` |
| `mdVideoW` | `0.50` | `0.50` | `0.50` | `0.44` | `0.50` |
| `mdVideoH` | `0.34` | `0.34` | `0.34` | `0.33` | `0.34` |

**Anchor points (fixed across aspect ratios — do not override per-ratio
without strong reason):** `countY`, `gameColW`, `panelDescY`,
`mdVideoY`, `mdVideoH`. These are anchors because they're tied either
to the help-strip top edge or to the visual rhythm of the right
panel, both of which are preserved across ratios.

**Width-coupled per-ratio overrides:** anything in the `panel*`,
`gameCol*`, `crossX` rows — these track the available horizontal
real estate after the cross is positioned.

**Height-coupled per-ratio overrides:** anything in the `*H` rows
plus `crossY`, `captionY`, `gameColTextY`, `gameColCarY` — these
shift when vertical real estate changes, principally at 1:1.

### 2.3 Safe zones and reserved regions

| Region | y-range | x-range | Used by |
|:---|:---:|:---:|:---|
| Top status bar | `0.00 – 0.10` | `0.75 – 0.98` | Clock only (top-right cluster; battery glyph pulled in v0.10, restoration tracked as #4) |
| Cross top row | `0.14 – 0.44` | full width | System carousel container (`pos.y=0.141, size.y=0.30`) |
| Sub-item column | `0.46 – 0.92` | `0.06 – 0.40` | Gamecarousel / textlist |
| Right info panel | `0.10 – 0.92` | `0.40 – 0.98` | md_name, md_rating, md_video, md_description |
| Bottom help strip | `0.94 – 1.00` | `0.02 – 0.98` | Helpsystem buttons |

Reserved regions (do not place new content here):

- **Top 0.10 vertical strip** — owned by the status bar. The clock at
  `(0.84, 0.03)`, size `(0.14, 0.06)`, pins the right edge at
  `0.84 + 0.14 = 0.98`.
  Left-of-`x=0.75` of the top strip is technically free but
  conventionally empty — PSP doesn't put anything there either.
- **Bottom 0.06 vertical strip** — owned by the helpsystem
  (`<helpsystem>` at `(0.02, 0.94)`). Don't overlay content here.
- **Cross anchor region `(crossX±0.10, crossY±0.10)`** — owned by the
  selected category icon + its halo. The halo `<maxSize>` of `0.28`
  square means the halo's footprint extends ~`±0.14` around the
  anchor in 4:3. Any element placed inside that radius competes
  visually with the selected icon's glow.

### 2.4 Z-index stack

ES renders elements in `<zIndex>` order. The stack:

| zIndex | Element | Reason |
|:---:|:---|:---|
| 0 | `staticBackgroundWave` (base tint layer) | Bottom canvas |
| 1 | `staticBackgroundLayer1` (top crest, slow) | Wave parallax — top |
| 2 | `staticBackgroundLayer2` (middle crest, medium) | Wave parallax — middle |
| 3 | `staticBackgroundLayer3` (bottom crest, fast) | Wave parallax — bottom |
| 4 | `staticBackgroundHalo` (system view only) | Above all wave layers, still behind the carousel logo |
| 5 | `systemcarousel`, gamelist `textlist` / `gamecarousel`, `md_*` info panel | Foreground content |
| 6 | `logo` (selected category icon in system view), `systemInfo` (count caption) | One above carousel, so the icon paints over the carousel's centered slot reliably |
| 7 | `systemName` (extra caption) | Above systemInfo for the Hide subset |
| 8 | `logo` (selected category icon in gamelist views) | One above the gamecarousel so the icon never gets hidden by a boxart that escapes its container — Knulli build quirk noted in `_inc/gamelist.xml:90-96` |

The `staticBackground*` elements route through ES's
`SystemView::mStaticBackgrounds` list; paint order within that group
is a `stable_sort` by `zIndex`, ascending (`SystemView.cpp:1065`) —
lower paints first / underneath. The gamelist views keep the older
`waveBackground` / `waveLayer{1,2,3}` extra-element names at the same
zIndex values (see §7.1).

**Rule:** new elements default to `zIndex=5` (the foreground content
layer). Bump to `6` only if you need to paint over the carousel
itself. Use `>=8` only for safety against the container-escape bug.

---

## 3. Color

### 3.1 Semantic color tokens

The theme defines six color slots in `<variables>`. Every visual
element should reference one of these, not a hardcoded hex.

| Token | Default (January Blue) | Used by |
|:---|:---:|:---|
| `${waveTint}` | `1E3A8A` | Base wave color; menu panel `${waveTint}F0` |
| `${accent}` | `3B82F6` | Wave layers 1-3 tint; ratings stars |
| `${textPrimary}` | `FFFFFF` | All readable copy: system name, game title, scrolling description, clock |
| `${textSecondary}` | `B0C4DE` | Sub-labels, unselected list items, helpsystem text |
| `${selectorGlow}` | `60A5FA` | Textlist selector glow (when used) |
| `${helpAccent}` | `93C5FD` | Helpsystem icon tint |

Defined at `_inc/common.xml:13-19`; overridden per-colorset by the
twelve files in `colors/`.

**Rules:**

- `textPrimary` is always `FFFFFF`. Don't ever set it to a colored
  value — readability against the wave depends on it.
- `textSecondary` should be a desaturated, lightened variant of
  `accent` (typically `accent` family hue + high luminance). The
  current 12 colorsets follow this convention; new ones should too.
- `waveTint` is the *dark* anchor of the colorset palette; `accent`
  is the *bright* anchor. The wave layers (which are tinted
  `${accent}`) sit on top of the `${waveTint}` base; that contrast
  is what gives the wave its visible crest.
- `selectorGlow` is reserved for textlist selectors and any future
  selection-pulse elements; halo `<color>` remains hardcoded white
  (see §3.4, §6.2).

### 3.2 The twelve monthly colorsets

The PSP firmware ships twelve theme-color presets, indexed 1-12 (with
0 = "change monthly," which auto-rotates through the twelve). Per the
Sony Custom Theme Creation Guidelines v5.00 §3 Theme Color table,
this is canonical: a custom theme can declare a preferred index but
cannot override the colors themselves.

The exact hex codes Sony shipped were extracted from firmware files
(`FLASH0:/VSH/RESOURCE/01-12.bmp` per the PS3-era schema documented at
psdevwiki). Both the PSP and PS3 sets exist; this theme's twelve
colorsets are **not** byte-identical to either, because the PSP wave
was 480×272 and a literal port to 1024×768+ devices makes the
palettes look muddy. Instead, the theme uses a curated rebuilt
palette: each colorset's `waveTint` is a Tailwind-family `900` shade
of the corresponding hue, and `accent` is the `500` shade.

| # | Name | `waveTint` | `accent` | `textSecondary` | `selectorGlow` | `helpAccent` | PS3-era reference hex |
|:---:|:---|:---:|:---:|:---:|:---:|:---:|:---:|
| 1 | January Blue | `1E3A8A` | `3B82F6` | `B0C4DE` | `60A5FA` | `93C5FD` | `CBCBCB` (PS3 was grey) |
| 2 | February Violet | `4C1D95` | `8B5CF6` | `C4B5FD` | `A78BFA` | `C4B5FD` | `D8BF1A` (PS3 was yellow) |
| 3 | March Pink | `9D174D` | `EC4899` | `FBCFE8` | `F472B6` | `FBCFE8` | `6DB217` (PS3 was green) |
| 4 | April Green | `14532D` | `22C55E` | `BBF7D0` | `4ADE80` | `BBF7D0` | `E17E9A` (PS3 was pink) |
| 5 | May Yellow-Green | `3F6212` | `84CC16` | `D9F99D` | `A3E635` | `D9F99D` | `178816` (PS3 was dark green) |
| 6 | June Yellow | `78350F` | `EAB308` | `FEF08A` | `FACC15` | `FEF08A` | `9A61C8` (PS3 was light-purple) |
| 7 | July Amber | `7C2D12` | `F59E0B` | `FED7AA` | `FBBF24` | `FED7AA` | `02CDC7` (PS3 was light-blue) |
| 8 | August Orange | `9A3412` | `F97316` | `FED7AA` | `FB923C` | `FED7AA` | `0C76C0` (PS3 was blue) |
| 9 | September Red | `7F1D1D` | `EF4444` | `FCA5A5` | `F87171` | `FCA5A5` | `B444C0` (PS3 was purple) |
| 10 | October Crimson | `881337` | `E11D48` | `FECDD3` | `FB7185` | `FECDD3` | `E5A708` (PS3 was yellow) |
| 11 | November Slate | `334155` | `64748B` | `CBD5E1` | `94A3B8` | `CBD5E1` | `875B1E` (PS3 was brown) |
| 12 | December Aqua | `134E4A` | `14B8A6` | `99F6E4` | `2DD4BF` | `99F6E4` | `E3412A` (PS3 was red) |

The right-hand column is psdevwiki's documented PS3-firmware-extracted
filter color per month (https://www.psdevwiki.com/ps3/Template:XMB_colors).
**Note: the theme's hue rotation differs deliberately from the
PS3 sequence.** A future revision may want to re-align — see §10 for
the design choice trail.

Defined per file in `colors/psp-*.xml`:

```xml
<theme>
  <formatVersion>7</formatVersion>
  <variables>
    <waveTint>1E3A8A</waveTint>
    <accent>3B82F6</accent>
    <textPrimary>FFFFFF</textPrimary>
    <textSecondary>B0C4DE</textSecondary>
    <selectorGlow>60A5FA</selectorGlow>
    <helpAccent>93C5FD</helpAccent>
  </variables>
</theme>
```

User selects a colorset via **UI Settings → Theme Configuration → PSP
Color**. The default is **January Blue** (`colors/psp-jan-blue.xml`).
Changing the colorset requires an ES restart — see audit U3 for why a
live preview is unsupportable.

### 3.3 Authoring a new colorset

A custom colorset is six lines in a new `colors/psp-<name>.xml`
plus one `<include>` line in `theme.xml`'s `<subset name="colorset">`
block. Five rules:

1. `textPrimary` MUST be `FFFFFF`. The theme assumes white-on-wave
   contrast everywhere; deviating breaks readability across all
   gamelist views.
2. `waveTint` should be a saturated dark shade (HSL lightness ~25%).
   Going too light makes `textPrimary` unreadable over the wave;
   going too dark makes the wave layers (which are `${accent}`-tinted)
   muddy.
3. `accent` should be the same hue as `waveTint`, lightness ~55%.
   The wave's "crest brightness" is `accent` over the `waveTint`
   base; if the two don't share a hue family the wave looks tinted-
   over-painted rather than illuminated.
4. `textSecondary` should be the same hue, lightness ~85%, saturation
   ~50%. Used for the system-name caption and helpsystem text — must
   read against the wave but not compete with `textPrimary`.
5. `selectorGlow` should be `accent`-family, lightness ~65%.
   `helpAccent` typically equals `textSecondary` (the two existing
   colorsets that diverged got revised — see commit history).

Reference: pick a Tailwind 4 color family for the new hue. Use
`-900` for `waveTint`, `-500` for `accent`, `-200` for `textSecondary`
and `helpAccent`, `-400` for `selectorGlow`. The twelve shipped
colorsets follow this rule with the single exception of November
Slate, which uses lower-saturation Tailwind Slate.

### 3.4 Halo / glow tinting

The selected category icon's halo (`art/halo.png`) is a center-bright
radial gaussian. It is tinted **white at runtime, not by colorset.**

Settled v0.9.1 decision (see audit "Deliberately omitted" → "Accent-
tinted halo"): on-device testing of an accent-tinted halo (color =
`${accent}`) showed it competed visually with the icon itself and
made the colorset feel over-saturated. The white halo reads as a
universal "selection light" and stays out of the colorset's way.

```xml
<image name="staticBackgroundHalo">
  <color>FFFFFF</color>  <!-- hardcoded; do not bind to ${accent} -->
  ...
</image>
```

The halo's apparent color is white throughout. The visible portion
(the gaussian shoulder around the icon — see §6.2) reads as a soft
white glow. Against any colorset's wave tint, white reads as light.

### 3.5 Readability minimums

Against any of the twelve colorsets' wave background, text must
remain readable. The de-facto contrast minimums:

- `textPrimary` (white) on `waveTint`: contrast ≥ 7:1 (WCAG AAA).
  All twelve colorsets clear this.
- `textSecondary` on `waveTint`: contrast ≥ 4.5:1 (WCAG AA-large).
  Eleven colorsets clear this; November Slate's
  `textSecondary=CBD5E1` over `waveTint=334155` is ~4.2:1 — at the
  edge. Acceptable because Slate is a deliberately low-key palette.
- `accent` on `waveTint` for the wave layers themselves: contrast
  ratio is intentionally low (~1.5-2:1). The wave should be visible
  but not insistent. If you raise it, the wave starts to feel like a
  highlight color rather than a background.

When designing a new colorset, render the test card at all five
aspect ratios via `scripts/render.sh` and check readability of
the system-name caption (which uses `textSecondary`) on each.

---

## 4. Typography

### 4.1 Font family and weights

This theme uses **Roboto Condensed** in three weights:

- `RobotoCondensed-Light.ttf` (`fontLight` token) — system-name
  caption, count caption, gamecarousel logo text, description body.
- `RobotoCondensed-Regular.ttf` (`fontRegular` token) — clock,
  helpsystem, gamelist textlist rows.
- `RobotoCondensed-Bold.ttf` (`fontBold` token) — info-panel
  `md_name` (the selected game's title).

Defined at `_inc/common.xml:21-23`. License: Open Font License (see
`fonts/OFL.txt`).

Roboto Condensed was chosen as a Sony-VAG-Rounded substitute that is
freely licensed for redistribution. Its narrow letterforms preserve
the PSP firmware's slightly-compressed feel without literally cloning
the original face.

### 4.2 Type scale

All `<fontSize>` values are normalized to screen height (0.0-1.0):

| Element | Token | Size | Approx px @ 768px | Use |
|:---|:---:|:---:|:---:|:---|
| Info-panel `md_name` (game title) | `fontBold` | `0.035` | 27 | Largest copy. Centered. |
| Clock | `fontRegular` | `0.042` | 32 | Largest copy in the status bar. Right-aligned. |
| System-name caption | `fontLight` | `0.034` | 26 | Below the selected category icon. |
| Count caption | `fontLight` | `0.034` | 26 | When Game Count: Show. |
| Textlist row (`detailed`) | `fontRegular` | `0.032` | 25 | Sub-items in the textlist. |
| Gamecarousel logo text | `fontLight` | `0.030` | 23 | Fallback when no thumbnail. |
| Description body | `fontLight` | `0.028` | 22 | The scrolling text container. |
| Helpsystem | `fontRegular` | `0.025` | 19 | Bottom-strip button labels. |

The cluster of sizes between `0.025` and `0.035` is deliberate:
within that 10-pixel band on a 768-line display, all text reads as
"PSP-scale UI text." Outside that band (larger or smaller) the
interface stops feeling PSP-like — too small reads as desktop UI;
too large reads as television.

**Don't introduce a font size outside this scale** without justifying
it in a versioned spec (`docs/superpowers/specs/`).

### 4.3 Alignment

| Element | Alignment | Why |
|:---|:---:|:---|
| System-name caption | `center` | Under the centered category icon. |
| Game title (info panel) | `center` | Anchors the right panel; symmetric. |
| Description | `left` (implicit) | Long-form body text reads left-justified. |
| Textlist rows | `center` | PSP-XMB sub-items are centered under the cross (see audit S5 for the cross-axis pointer that hangs off the left edge of selected rows; not yet implemented). |
| Clock | `right` | Right-anchored status bar. |
| Helpsystem | `left` (default) | Left-anchored cluster at bottom-left. |
| Rating | `left` (default) | Anchored to `mdRatingX` left edge. |

Note: the existing theme uses `<horizontalAlignment>` in some places
where `<alignment>` is correct. See audit "Cross-cutting constraints"
— this generates ~80 parse warnings on every render but is non-fatal.
Fixing this is a documented separate task.

### 4.4 Why not the PSP's font

The PSP firmware uses **Sony's proprietary `LTN0.PGF`** (Sony's
licensed `VAGRundschriftDLig` / `Sony-CC` from urwpp; see
psdevwiki's `XMB Fonts` page). This font is non-redistributable
under the theme's CC-BY-NC-SA 2.0 license, and shipping a binary copy
of it would violate Sony's IP. Roboto Condensed Light at `0.030` is a
close enough substitute that side-by-side comparisons on-device
(v0.5 testing) read as "PSP-style" to a non-expert observer.

If a future Sony-licensed open release ever ships the PSP font, the
swap is one variable change in `common.xml` plus copying the file
into `fonts/`.

---

## 5. Iconography

### 5.1 Two-tier hierarchy

Per Sony's Custom Theme Creation Guidelines v5.00 and visible across
all three reference videos, the PSP XMB uses a **two-tier icon
hierarchy**:

- **Category icons** (top row, horizontal): flat **monochrome
  silhouettes** in a single line weight. Examples from video C @ 0:15:
  the Settings briefcase, the Photo camera, the Music note, the
  Video filmstrip — all white-on-transparent, no internal detail,
  no gradients.
- **Item icons** (sub-items + branded apps): **full-color, 3D-ish
  rendering**. Examples from video B @ 0:30 (the Skype "S" in a blue
  circle), video C @ 3:00 (the PlayStation Network swirl in deep
  blue/purple, the orange Information Board icon, the blue
  PS Store shopping bag).

This theme follows that hierarchy:

- **Hardware-system icons** (NES, SNES, PSX, etc.) — filled-silhouette
  treatment. Served by a hybrid set: Knulli's per-system silhouettes
  retained where they read as PSP-style, with ~134 shortnames adopted
  from RetroArch's `monochrome` icon set (CC-BY 4.0 filled-silhouette,
  see audit S1a and #23) for visual coherence, plus 8 hand-authored
  port icons in matching style.
- **Auto-collection icons** (`auto-favorites`, `auto-lastplayed`,
  `auto-allgames`, `tools`, `ports`, etc.) — branded treatment.
  Served by RetroArch's `favorites.png` (heart), `history.png`
  (clock-arrow), `database.png` (stacked discs), etc. — graphically
  distinct from hardware systems, which is the whole point.
- **Media-type fallback icons** (`art/system-media/`) — a third tier
  of seven generic silhouettes (`_default`, `arcade-board`,
  `cartridge`, `cd`, `computer`, `floppy`, `handheld-cart`) for
  systems with no dedicated icon. Authored but **not yet wired** into
  any view template.

See audit S1, S1a, G10 for the migration trail.

### 5.2 Canvas and rendering sizes

Sony's authoritative source bitmap dimensions (Custom Theme Creation
Guidelines v5.00 §3):

| Sony tier | Source canvas | Format | Used as |
|:---|:---:|:---|:---|
| Category icon (horizontal) | **64 × 48 px** | 256-color 32-bit CLUT PNG/TGA/GIM | Top-row PSP icons |
| First-level icon body | **48 × 48 px** | same | Sub-item icons |
| First-level icon focus | **64 × 64 px** | same | The glow halo around the focused sub-item |
| Second-level icon body | **32 × 32 px** | same | Sub-sub items (Settings rows) |
| Second-level icon focus | **48 × 48 px** | same | Focus on Settings rows |
| Wallpaper | **480 × 272 px** | 24-bit RLE BMP | Full-screen background |
| Preview icon | **16 × 16 px** | 256-color CLUT PNG | The theme's selector preview |
| Preview image | **300 × 170 px** | 24-bit BMP | The theme's preview image |

This theme renders at much higher resolutions than the PSP's native
480×272, so the source-bitmap sizes above are *information* but not
*constraints*. The theme uses **256×256 px** white-on-transparent PNGs
for category icons (drop-in compatible with RetroArch's `monochrome`
set, see audit S1a). The `halo.png` source is also 256×256 (square)
and ES scales it via `<maxSize>` at render time.

If you author a new icon for `art/system-icons/`, target **256×256
PNG with transparency**. The square canvas matches the RA convention;
the actual rendered footprint is normalized via `<maxSize>`.

All shipped `art/system-icons/*.png` carry a **pre-burned drop
shadow** (4px Gaussian blur, 3px Y-offset, 35% black — audit S3),
baked into the PNGs by `scripts/apply-shadow.py`. A new icon must be
run through that script **exactly once** before committing. The
script is **not idempotent** — re-running compounds shadows, so never
rerun it over already-shadowed icons without resetting them first.

### 5.3 Per-slot rendering size

Source bitmaps render at a normalized fraction of screen, varying by
slot type. **This is the rendered-size table**, cite when adjusting:

| Slot | Variable | 4:3 | 16:9 | 3:2 | 1:1 | 8:7 |
|:---|:---|:---:|:---:|:---:|:---:|:---:|
| System carousel icon (unselected) | `(sysCarouselLogoW, sysCarouselLogoH)` | `0.10 × 0.14` | `0.08 × 0.14` | `0.09 × 0.14` | `0.13 × 0.13` | `0.10 × 0.12` |
| System view selected icon (`logoScale=1.5`) | `(sysIconMaxW, sysIconMaxH) × 1.5` | `0.18 × 0.24` | `0.15 × 0.255` | `0.165 × 0.255` | `0.24 × 0.24` | `0.18 × 0.21` |
| Halo footprint (selected only) | `(haloW, haloH)` | `0.28 × 0.28` | `0.28 × 0.28` | `0.28 × 0.28` | `0.28 × 0.28` | `0.28 × 0.28` |
| Gamelist pinned system icon | `(glIconMaxW, glIconMaxH)` | `0.15 × 0.21` | `0.12 × 0.21` | `0.13 × 0.21` | `0.20 × 0.20` | `0.15 × 0.18` |
| Gamecarousel selected boxart | `(gameCarLogoW, gameCarLogoH) × 1.5` | `0.525 × 0.42` | `0.495 × 0.585` | `0.495 × 0.57` | `0.54 × 0.51` | `0.525 × 0.48` |

`logoScale=1.5` is the **selected/unselected multiplier**. Don't
adjust it without re-tuning every dependent slot — see the v0.9.3
round-4 commits where the gamecarousel's `gameCarLogoH` was reduced
from 0.37 to 0.28 because slot overflow exceeded 100% on-device.

**Aspect-ratio rule (P1):** an icon's rendered footprint should be
approximately square in pixels. To check: `width_norm × screen_w_px
≈ height_norm × screen_h_px`. The 16:9 override of `sysIconMaxW=0.10,
sysIconMaxH=0.17` resolves to `128px × 122px` on a 1280×720 surface —
close to square. The default 4:3 `0.12 × 0.16` resolves to `123px ×
123px` on 1024×768 — square by coincidence.

### 5.4 Helpsystem glyphs

PSP face buttons are: **✕ Cross (confirm), ○ Circle (back), □ Square,
△ Triangle**, plus directional pad chevrons.

This theme currently uses ES's built-in helpsystem icons (not
PSP-shaped). Future migration is audit S4: author 6-10 small PNG
glyphs (~32×32 px source, rendered at `fontSize=0.025` ≈ 19px tall)
in the same filled-silhouette weight as the shipped system icons,
then bind via:

```xml
<helpsystem name="help">
  <iconA>./art/help/cross.png</iconA>
  <iconB>./art/help/circle.png</iconB>
  <iconX>./art/help/square.png</iconX>
  <iconY>./art/help/triangle.png</iconY>
  <iconUpDown>./art/help/pad-updown.png</iconUpDown>
  <iconLeftRight>./art/help/pad-leftright.png</iconLeftRight>
</helpsystem>
```

Source canvas: **32×32 PNG, white-on-transparent**. Tinted at render
time by `<iconColor>${helpAccent}</iconColor>` in
`_inc/common.xml:134`.

---

## 6. Components

### 6.1 Category icons (system carousel)

Top horizontal row. Defined in `_inc/system.xml:98-119`.

```xml
<carousel name="systemcarousel">
  <defaultTransition>fade</defaultTransition>
  <type>horizontal</type>
  <pos>${sysCarouselPosX} 0.141</pos>
  <size>${sysCarouselSizeW} 0.30</size>
  <logoSize>${sysCarouselLogoW} ${sysCarouselLogoH}</logoSize>
  <logoScale>1.5</logoScale>
  <maxLogoCount>11</maxLogoCount>
  ...
</carousel>
```

**Key measurements:**

- Container `pos.y = 0.141`, `size.y = 0.30` → vertical centerline =
  `0.141 + 0.15 = 0.291` = `crossY`. The carousel's vertical center
  is the cross row.
- Container `pos.x = sysCarouselPosX`, `size.x = sysCarouselSizeW` →
  horizontal centerline = `pos.x + size.x / 2` = `crossX`. So the
  carousel center sits on the cross anchor; the **selected logo** in
  a horizontal carousel is whichever sits at the container's
  horizontal center.
- `maxLogoCount=11` — the slot count along the bar. Eleven gives
  PSP-like density: a wide enough bar that 4-5 icons are visible
  off each side of the selected one, with breathing room.
- `logoScale=1.5` — the selected logo is 1.5× the unselected size.
  Larger looks too aggressive; smaller breaks the selection signal.
- Per-aspect-ratio `sysCarouselSizeW` is derived: `K × logoW ×
  maxLogoCount` where `K=1.62` (the gap-to-icon constant chosen so
  spacing reads consistently across aspect ratios). For 4:3:
  `1.62 × 0.10 × 11 = 1.782 ≈ 1.78`. For 16:9: `1.62 × 0.08 × 11 =
  1.43`. See the formula commented in each `aspect-*.xml` file.

**Selected logo z-order** sits above the carousel container so the
selected icon paints over its slot reliably. The `<image name="logo">`
element in `_inc/system.xml:164-168` has `<zIndex>6</zIndex>`; the
carousel has `<zIndex>5</zIndex>`.

### 6.2 Selected-icon halo

Soft white center-bright gaussian behind the selected category icon.
Defined in `_inc/system.xml:87-95`.

```xml
<image name="staticBackgroundHalo">
  <path>./art/halo.png</path>
  <pos>${crossX} ${crossY}</pos>
  <origin>0.5 0.5</origin>
  <maxSize>${haloW} ${haloH}</maxSize>
  <color>FFFFFF</color>
  <opacity>0.6</opacity>
  <zIndex>4</zIndex>
</image>
```

**History:** the halo was pulled in v0.10 and restored + re-tuned in
v0.11 (PR #28). The `staticBackground*` name prefix routes it through
`SystemView::mStaticBackgrounds` so it ticks every frame and paints
as a group with the wave layers.

**Key measurements:**

- `haloW = haloH = 0.28` (normalized; same value all aspect ratios).
  This is ~1.56× the icon's apparent width
  (`sysIconMaxW × logoScale = 0.12 × 1.5 = 0.18` at 4:3). The icon
  obscures the bright center of the gaussian; the visible portion is
  the outer shoulder, which reads as a diffuse glow.
- `opacity=0.6`. The PR #28 re-tune found the original `0.40`
  footprint at full opacity read as a blown-out blob; the shipped
  combination is the smaller `0.28` footprint at 60% opacity.
- Color is always white (`FFFFFF`) — see §3.4.
- `zIndex=4` sits the halo above all four wave layers (`zIndex 0-3`)
  but below the carousel (`zIndex=5+`) so the icon paints over the
  halo's brightest pixel. Within `mStaticBackgrounds`, paint order is
  a `stable_sort` by `zIndex` (`SystemView.cpp:1065`) — see §2.4.
- No storyboards. The v0.9-era scroll-fade/fade-in storyboards were
  removed with the staticBackground migration (see §7.3).

**Source asset:** `art/halo.png`, 256×256 square white-on-transparent
center-bright gaussian. Re-render the gaussian if redesigning;
`<maxSize>` will scale it to `haloW × haloW` regardless of source
aspect.

### 6.3 System name caption

Below the selected category icon, displaying the system's `theme`
shortname (e.g., "NES", "SNES", "PSX"). Defined in
`_inc/system.xml:147-159`.

```xml
<text name="systemName" extra="true">
  <pos>${crossX} ${captionY}</pos>
  <origin>0.5 0</origin>
  <size>0.5 0.055</size>
  <fontPath>${fontLight}</fontPath>
  <fontSize>0.034</fontSize>
  <color>${textSecondary}</color>
  <alignment>center</alignment>
  <forceUppercase>true</forceUppercase>
  <text>${system.theme}</text>
  <zIndex>7</zIndex>
</text>
```

- `pos = (crossX, captionY)` = `(0.24, 0.401)` in 4:3. Caption top
  edge sits ~0.11 of screen height below the icon center.
- `origin = (0.5, 0)` — horizontally center-anchored, vertically
  top-anchored. The caption text top-aligns to `captionY`.
- `forceUppercase=true` — converts `${system.theme}` to uppercase
  display, matching PSP's all-caps category labels (video C @ 0:15,
  "Settings" — actually mixed-case in PSP, but the theme uses
  uppercase as a visual marker that this is the category, not a
  sub-item).
- Color `${textSecondary}` for "this is the category context, not
  the selected item." `textPrimary` is reserved for the selected
  game's title in the info panel.

### 6.4 Game count caption (optional)

When the user enables Game Count: Show, a second caption appears
below the system name, cycling between the count text. Defined in
`_inc/system.xml:125-135` (the carousel's `systemInfo` slot) and the
gamecount-show subset variant in `_inc/gamecount-show.xml`.

```xml
<text name="systemInfo">
  <pos>${crossX} ${countY}</pos>
  <fontPath>${fontLight}</fontPath>
  <fontSize>0.034</fontSize>
  <color>${textSecondary}</color>
  <alignment>center</alignment>
  <zIndex>6</zIndex>
</text>
```

- `pos = (crossX, countY)` = `(0.24, 0.456)` in 4:3 — 5.5% of
  screen height below the systemName caption.
- Same font size and color as systemName. Visually a sibling, not a
  secondary label.
- Hidden by default (Game Count: Hide); enabled by the
  `gamecount-show.xml` subset.

### 6.5 Top-right status cluster

The status bar is **clock-only** as of v0.10. Defined in
`_inc/common.xml:153-161`.

| Element | Pos | Size | Notes |
|:---|:---:|:---:|:---|
| Clock | `(0.84, 0.03)` | `(0.14, 0.06)` | `<fontSize>0.042</fontSize>` (largest text in UI), `alignment=right` — right edge at `0.84 + 0.14 = 0.98` |

The battery glyph was pulled in v0.10: vertical-alignment and
percentage-rendering bugs surfaced on-device and couldn't be
resolved in that iteration. Restoration is tracked as issue #4;
the `art/battery/battery-{empty,25,50,75,full,incharge}.png`
assets and the batteryIcon syntax notes are retained in the tree
for that attempt (ES picks the glyph automatically from
`Utils::Platform::queryBatteryInformation().level` once a
`batteryIcon` element is themed again).

ES renders the clock from `Settings::ClockMode12` (per
`ClockComponent.cpp:30-34`) — either `%I:%M %p` (12-hour) or
`%H:%M` (24-hour). The theme cannot override the format string
(audit U11).

### 6.6 Helpsystem strip

Bottom-left button hints. Defined in `_inc/common.xml:131-137`.

```xml
<helpsystem name="help">
  <pos>0.02 0.94</pos>
  <textColor>${textPrimary}</textColor>
  <iconColor>${helpAccent}</iconColor>
  <fontPath>${fontRegular}</fontPath>
  <fontSize>0.025</fontSize>
</helpsystem>
```

- `pos.y = 0.94` — sits in the bottom 6% strip.
- Icon-text pairs are spaced according to ES defaults; the theme
  does not override `<iconWidth>`, `<entrySpacing>`, etc.
- Glyphs are ES built-ins; future PSP-style glyph migration is audit
  S4 (see §5.4).

### 6.7 Gamelist — detailed (text list)

Defined in `_inc/gamelist.xml:161-178`.

```xml
<textlist name="gamelist">
  <pos>${gameColX} ${gameColTextY}</pos>
  <size>${gameColW} ${gameColH}</size>
  <fontPath>${fontRegular}</fontPath>
  <fontSize>0.032</fontSize>
  <alignment>center</alignment>
  <primaryColor>${textSecondary}</primaryColor>
  <secondaryColor>${textSecondary}</secondaryColor>
  <selectorColor>${selectorGlow}</selectorColor>
  <selectedColor>${textPrimary}</selectedColor>
  <lineSpacing>1.4</lineSpacing>
  <zIndex>5</zIndex>
</textlist>
```

- `pos = (gameColX, gameColTextY)` = `(0.08, 0.50)` in 4:3.
  Container top-edge at y=0.50; bottom at y=0.92. The textlist is
  centered horizontally inside its `gameColW=0.32` box at `gameColX`.
- Unselected rows: `${textSecondary}` (dimmer).
- Selected row: `${textPrimary}` (full white).
- Selector glow: `${selectorGlow}` (accent-family tint).
- `lineSpacing=1.4` — fits ~9 rows in the 0.42-tall container.

The textlist is centered (`alignment=center`) under the system icon's
column, matching the PSP cross's center-aligned vertical arm.

Future `<itemTemplate>` work (audit G4 + G7 + G8) replaces the
single-line center-aligned textlist with a per-row template
containing title + right-aligned value + selected-row description
fade-in. Not yet shipped.

### 6.8 Gamelist — gamecarousel (boxart column)

Defined in `_inc/gamelist.xml:197-216`.

```xml
<gamecarousel name="gamecarousel">
  <type>vertical</type>
  <imageSource>thumbnail</imageSource>
  <pos>${gameColX} ${gameColCarY}</pos>
  <size>${gameColW} ${gameColH}</size>
  <logoSize>${gameCarLogoW} ${gameCarLogoH}</logoSize>
  <logoScale>${gameCarLogoScale}</logoScale>
  <maxLogoCount>3</maxLogoCount>
  <minLogoOpacity>0.3</minLogoOpacity>
  <zIndex>5</zIndex>
</gamecarousel>
```

- `pos = (gameColX, gameColCarY)` = `(0.08, 0.46)` in 4:3.
  `gameColCarY = 0.46` positions the container so the slot
  immediately above the centered selected slot doesn't peek into the
  caption area (see `_inc/common.xml:77-87` comment for the
  derivation math).
- `maxLogoCount=3` — three slots visible: unselected-above, selected
  (centered + scaled), unselected-below.
- `minLogoOpacity=0.3` — unselected slots dim to 30% opacity. The
  selected slot's `logoScale=1.5` and full opacity make it
  unmistakably the focal point.
- `imageSource=thumbnail` — uses the game's scraped thumbnail. Games
  without a thumbnail fall back to the styled text shown by the
  `gamecarouselLogoText` text element (defined immediately after
  the carousel block).
- `logoSize` units are CONTAINER-relative, not screen-relative
  (ES quirk per `CarouselComponent.cpp`). `gameCarLogoH` must be ≤
  `1/maxLogoCount` = `0.333` to avoid slot overflow — that's why
  the 4:3 default is `0.28`, leaving ~`0.053` of vertical gap per
  slot.

A v0.9.3 round 4 attempt to add a halo behind the selected boxart
was reverted (audit G5): the halo plus a text-fallback white title
made the title unreadable. Re-introduction requires per-system
fallback icons replacing the text fallback first (audit G5 is the
coupled spec).

### 6.9 Info panel (title / rating / video / description)

Right-side metadata panel. Defined in `_inc/gamelist.xml:115-154`.

Five elements stack vertically in the `panelX..panelX+panelW`
horizontal band:

| Element | y position | y size | Source |
|:---|:---:|:---:|:---|
| `md_name` (title) | `0.10` | `0.06` | `${game:name}` |
| `md_rating` | `0.17` | `0.04` | `${game:rating}` |
| (gap for metadata key-value rows — audit G2, not yet shipped) | `0.20-0.36` | `0.16` | (G2) |
| `md_video` | `mdVideoY = 0.39` | `mdVideoH = 0.34` | `${game:video}` (or snapshot during delay) |
| `md_description` | `panelDescY = 0.60` | `panelDescH = 0.32` | `${game:desc}` |

**Title (`md_name`).** Centered. Largest weight font (`fontBold`),
size `0.035` (slightly smaller than the clock at `0.042` — the
clock sits in the status bar, where a larger size doesn't compete
with body content).

**Rating (`md_rating`).** Five stars. Color `${accent}` (tinted to
the colorset). Position at `mdRatingX = 0.615` (4:3).

**Video (`md_video`).** Shows the scraped snapshot for `<delay>`
seconds, then plays the preview video. Centered at `(mdVideoX,
mdVideoY) = (0.705, 0.39)` with `<origin>0.5 0.5</origin>` (so the
position values are the box's center, not its top-left). Box is
`(mdVideoW, mdVideoH) = (0.50, 0.34)` in 4:3 — a 4:3-aspect video
window per §1.3 P4.

**Description (`md_description`).** Scrolls (`<container>true</container>`)
with cadence controlled by the `scrollSpeed` subset. Font
`fontLight` size `0.028`, color `${textSecondary}`.

### 6.10 Menu chrome

ES's settings menu inherits the active colorset. Defined in
`_inc/menu.xml`.

| Element | Bound to | Effect |
|:---|:---:|:---|
| `<menuBackground>` | `${waveTint}F0` | Panel background, 94% opaque colorset tint |
| `<menuText>` color | `${textPrimary}` | Row text |
| `<menuText>` selectorColor | `${accent}` | Selection bar tint |
| `<menuTextSmall>` color | `${textPrimary}` | Section headers |

**Not themeable on this Knulli build** (verified during v0.5 spike,
documented in spec): `<menuTitle>`, `<menuFooter>`, `<menuSwitch>`,
`<menuSlider>`, `<menuButton>`. These keep ES defaults. PSP's
right-side sidebar option-picker style is unsupportable (audit U13).

---

## 7. Motion

### 7.1 Wave animation

Three semi-transparent crest layers slide left at different rates,
parallax-stacked over a static base tint. Defined in
`_inc/wave-motion.xml` (duplicated into `_inc/gamelist.xml:39-84`
due to a Knulli build quirk — see file comments).

| Layer | Source | Color | Opacity | Cycle duration | Crest y |
|:---|:---:|:---:|:---:|:---:|:---:|
| `waveBackground` | `wave.png` | `${waveTint}` | `1.00` (static) | — | full screen |
| `waveLayer1` | `wave-layer-1.png` | `${accent}` | `0.85` | **30 000 ms** (30 s/cycle) | ~`y=0.44` |
| `waveLayer2` | `wave-layer-2.png` | `${accent}` | `0.85` | **20 000 ms** (20 s/cycle) | ~`y=0.50` |
| `waveLayer3` | `wave-layer-3.png` | `${accent}` | `0.85` | **12 000 ms** (12 s/cycle) | ~`y=0.56` |

Element names above are the gamelist-view / `wave-motion.xml` ones.
The **system view** declares the same four layers directly in
`_inc/system.xml` under the `staticBackground{Wave,Layer1,Layer2,
Layer3}` names (the S6 continuity mechanism — see §2.4 and the
known-limitation note below); geometry, tint, and timings are
identical.

All three layers are **2.00 screen-widths wide** (`<size>2.00 1.10</size>`)
with horizontally-seamless patterns and animate `x` from `0.0` to
`-1.0` with `repeat=forever` linear. The seamless wrap makes the
repeat invisible.

The cycle ratios (30 / 20 / 12) produce the parallax depth: slowest
on top, fastest on bottom, simulating a wave receding into the
horizon. The absolute durations chosen are slow enough that the
motion reads as ambient (quiet, per §1.2) but fast enough that you
notice it after ~5-10 seconds of idle.

The base `waveBackground` (`<size>1.10 1.10</size>`) is 10%
over-scanned so any rounding error or storyboard subpixel drift
doesn't reveal a PNG edge.

**Resolved limitation (audit S6):** through v0.9.x the wave restarted
at `t=0` on every system carousel navigation. The `staticBackground*`
name-prefix workaround **shipped in v0.10**: the system view's wave
elements route through `SystemView::mStaticBackgrounds`, loaded once
at view construction and never reset on cursor change, so the wave
now persists continuously across navigation.

### 7.2 Carousel transition style

`theme.xml:12` declares `<theme defaultTransition="instant">`. This is
the theme's preference; ES uses it only when the global
`TransitionStyle` setting is `auto`. An explicit user override (set
under Main Menu → UI Settings) overrides this.

`instant` was chosen because PSP's intercategory transition is fast
(~150ms with a soft cross-fade); ES's `slide` is much longer
(~500-700ms) and reads as molasses. `instant` plus the carousel's
own internal `fade` (`<defaultTransition>fade</defaultTransition>` in
`_inc/system.xml:99`) gives a feel closer to PSP than either
extreme.

### 7.3 Halo scroll fade

**Historical note.** Through v0.9.x the halo carried two storyboards
(an `event="scroll"` 120ms fade-out and a 220ms default fade-in). The
`event="scroll"` one was dead code on extras in this ES build (audit
X1); both were removed with the `staticBackground*` migration when the
halo was restored in v0.11 (PR #28). On main the halo has **no fade
behaviour** — it renders at a constant `opacity=0.6` (§6.2). The old
citation `_inc/system.xml:53-58` now lands in a wave-layer scroll
storyboard, not the halo.

### 7.4 Description auto-scroll

The `md_description` container scrolls long text vertically.
`autoScrollSpeed` controls cadence (ms per line):

| Subset | `autoScrollSpeed` | Use case |
|:---|:---:|:---|
| Normal (default) | `150` | ES's stock default |
| Slow | `300` | Easier reading |
| Fast | `75` | Skim mode |

Per `_inc/scroll-speed-*.xml`. User-selectable via UI Settings → Theme
Configuration → Scroll Speed.

### 7.5 Video preview delay

`md_video` defaults to showing the snapshot for 5 seconds, then
transitioning to the scraped preview video. Configurable:

| Subset | `<delay>` | Behavior |
|:---|:---:|:---|
| 5 seconds (default) | `5` | Snapshot for 5s, then video |
| Instant | `0` | Video starts immediately |
| 2 seconds | `2` | Brief snapshot |
| 10 seconds | `10` | Long snapshot phase |

Per `_inc/video-delay-*.xml`.

Audio is force-off by default (`video-audio-off.xml` →
`<audio>false</audio>`); the user can enable via UI Settings →
Theme Configuration → Video Audio → On, but ES's global
"Enable video preview audio" setting must also be on for actual sound.

### 7.6 What we cannot animate

Six classes of animation that PSP does and ES cannot. See the audit's
Unsupportable section for full evidence; this is the operationally-
relevant summary:

| PSP behavior | Why not in ES | Closest we get |
|:---|:---|:---|
| Boot wave-in / wordmark wipe | Splash render path doesn't tick storyboards (`Splash.cpp:254-330`) | Static splash via `splash.xml` (audit S7) |
| Dynamic per-game layout reflow | `<pos>`/`<size>` are static floats, not bindable | `<visible>` hide-only (audit G6) |
| **Live colorset preview during settings change** | No event-routing from menu-interaction to system-view extras; variables resolve at parse time | Fixed 12 colorsets, restart required (audit U3) |
| Continuous wave during system change | Carousel's per-system extra lifecycle resets storyboard | `staticBackground*` prefix workaround, shipped in v0.10 (audit S6) |
| Selection-focus pulse on PSP first-level icons | No `event="settle"` / `event="focus"` in ES | Static halo only (§6.2; the v0.9-era fade storyboards are gone, §7.3) |
| Inline expand-on-select for settings rows | Fixed slot heights in IList | Helpsystem strip update (PSP's row expansion replaced by global help-strip text change) |

These are all audit U-entries (technically unsupportable). Don't
propose them as theme features.

---

## 8. Subsets and user knobs

ES subsets let the user pick between mutually-exclusive variants at
runtime (UI Settings → Theme Configuration). This theme exposes
**five** subsets:

| Subset | Variants | Default | Purpose |
|:---|:---:|:---:|:---|
| `colorset` (PSP Color) | 12 monthly palettes | January Blue | Color scheme |
| `gamecount` (Game Count) | Hide / Show | Hide | Whether to show "X GAMES" count caption |
| `videoDelay` (Video Delay) | 5s / Instant / 2s / 10s | 5 seconds | Snapshot → video timing |
| `videoAudio` (Video Audio) | Off / On | Off | Audio mute on preview video |
| `scrollSpeed` (Scroll Speed) | Normal / Slow / Fast | Normal | Description auto-scroll cadence |

Each subset variant lives in a small XML file in `_inc/`. **Rule:**
keep subset variants surgical. A subset variant should change at
most 3-5 properties. Larger variants belong in `common.xml` (single
default) or split into multiple subsets.

A sixth subset, `gamelistView` (Gamelist View Style: detailed /
gamecarousel / automatic), is built into ES rather than defined here;
the theme supports both styles via the shared
`<view name="detailed,gamecarousel">` block plus per-style
specializations.

---

## 9. Sound

PSP XMB navigation has three distinct sounds: a horizontal-scroll
"swoosh" (lower, broader), a vertical-scroll "tick" (bright, short),
and a select-confirm (mid-pitch). Plus a separate "back" sound
(descending sweep).

This theme ships:

- `sounds/navigate.wav` (41 KB) — bound to both `systemscroll` and
  `scroll` events (`_inc/common.xml:117-122`).
- `sounds/select.wav` (50 KB) — bound to `select` event.
- `sounds/back.wav` (71 KB) — bound to `back` event.

**Open audit:** A1 + A2 — `navigate.wav` is used for both horizontal
and vertical scroll, but PSP distinguishes them (horizontal "swoosh"
vs. vertical "tick"). Adding a `system-scroll.wav` is a future task.

**Don't ship verbatim PSP samples** — copyright. Synthesize or use
freesound.org CC-licensed PSP-style alternatives. Audit A1 has
generation notes (~3 kHz sine for the tick with 5 ms exponential
decay; ~1500→600 Hz sweep over 80 ms for back).

---

## 10. Settled decisions — do not re-litigate

Decisions that hard-cost time across multiple revisions and have
ship-state in the current build. Do not revisit without strong new
evidence:

| Decision | Settled in | Reason |
|:---|:---:|:---|
| **Halo is white, not accent-tinted.** | v0.9.1 | Accent-tinted halo competed with the icon; over-saturated the colorset visually. White reads as universal selection light. |
| **Wave layers tinted `${accent}`, not `${waveTint}`.** | v0.3 | If layers tint waveTint they read as faint shadow ripples, not crests. Accent gives the bright luminous edge that defines PSP wave. |
| **Carousel `<defaultTransition>fade</defaultTransition>`, not slide.** | v0.4 | Slide reads as too-mechanical; fade matches PSP's soft category cross-fade. |
| **`logoScale=1.5` (not 2.0 or 1.2).** | v0.6 | 1.2 doesn't signal selection; 2.0 is aggressive and crowds neighbors. 1.5 reads as PSP-correct. |
| **Roboto Condensed (not Noto Condensed, not Inter Tight, not the original PSP font).** | v0.5 | Licensed for redistribution; reads as PSP-style; three weights match the type scale. |
| **12 monthly colorsets with Tailwind-family palettes (not the PS3-extracted hex codes).** | v0.7 | Direct PS3 codes desaturate when scaled to 1024×768+; Tailwind family colors hold saturation. The hue rotation differs from PS3 (see §3.2 table). |
| **`maxLogoCount=3` for gamecarousel (not 1 or 5).** | v0.9.3 round 4 | 1 hides peer context; 5 over-crowds the column. 3 matches PSP's typical 3-visible sub-item layout. |
| **`maxLogoCount=11` for system carousel.** | v0.7 | Enough slots to show the wide PSP-style horizontal density without making icons tiny. |
| **`logoSize` aspect-ratio overrides (P1: pixels-square not fractions-square).** | v0.8 | Otherwise icons stretch on non-4:3 displays. |
| **Selected-icon halo on system carousel only, not gamecarousel.** | v0.9.3 round 4 | Adding the halo behind a text-fallback white title made it unreadable. Re-add only when audit G5 (per-system fallback icons) ships first. (The system-view halo itself was pulled in v0.10 and restored + re-tuned in v0.11, PR #28 — see §6.2.) |
| **`textPrimary = FFFFFF` always.** | v0.1 | Readable on every colorset's wave. Other primaries fail contrast on at least one of the 12. |
| **Battery glyph + clock + (nothing) cluster in top-right.** | v0.9 — **battery glyph pulled in v0.10**, restoration tracked as #4 | PSP's status-bar pattern. Wifi-strength indicator is unsupportable (audit U12); date next to clock is unsupportable (audit U11). Status bar is clock-only on main (§6.5). |
| **The wave never opts out.** | v0.3 | The wave IS the theme. No `<subset name="wave">` for "wave off" because the result would be a static colored background, which isn't what PSP-XMB-theme means. |
| **Cross anchor on `(crossX, crossY)`, not on absolute pixel offsets.** | v0.6 | Pixel offsets break on non-4:3. Anchor + per-ratio override is the working pattern. |
| **`defaultTransition="instant"` at theme root.** | v0.6 | ES auto-transition falls back to slide otherwise; PSP feel is instant. |

---

## 11. References

### 11.1 Authoritative Sony sources

- **PSP™ (PlayStation®Portable) Custom Theme Creation Guidelines,
  Version 5.00**, © 2008 Sony Computer Entertainment Inc. The
  canonical source for icon dimensions (§5.2), wallpaper format,
  preview format, theme color picker semantics (§3.2), and the
  `.ptf` file format.
  Mirror: https://cdn.us.playstation.com/pscomauth/groups/public/documents/webasset/ps_custom_theme-english_pp.pdf
- **PSP™ Custom Theme Creation Guidelines, Version 3.70** —
  earlier revision. Substantively identical for icon dimensions.
  Mirror: http://psphacks.pbworks.com/f/psp-xmb-custom-theme.pdf
- **PSP Instruction Manual (Sony)** — describes user-facing XMB
  navigation. Provides no measurements.
  https://www.manualslib.com/manual/757165/Sony-Psp.html?page=16

### 11.2 Semi-authoritative community sources

- **psdevwiki — PSP XrossMediaBar**:
  https://www.psdevwiki.com/psp/XrossMediaBar — discusses VSH /
  paf.prx / topmenu_plugin.rco internals; confirms monthly color
  rotation; confirms PSP Slim has 27 backgrounds vs original 12.
- **psdevwiki — PS3 XMB colors template**:
  https://www.psdevwiki.com/ps3/Template:XMB_colors — the source of
  the right-hand "PS3-era reference hex" column in §3.2.
- **psdevwiki — PSP VSH**:
  https://www.psdevwiki.com/psp/VSH — file system layout for
  PSP firmware visual resources.
- **psdevwiki — PS3 XMB Fonts**:
  https://www.psdevwiki.com/ps3/XMB_Fonts — confirms Sony's
  proprietary VAGRundschriftDLig (Sony-CC) font family; reason this
  theme uses Roboto Condensed (§4.4).
- **psdevwiki — PSP Installing Themes**:
  https://www.psdevwiki.com/psp/Installing_Themes — CXMB / CTF
  workflow; confirms 3.70+ PTF and 6.x CTF eras.

### 11.3 Cross-referenceable open implementations

- **RetroArch `xmb.c`**:
  https://github.com/libretro/RetroArch/blob/master/menu/drivers/xmb.c
- **RetroArch `monochrome` icon set** (CC-BY 4.0):
  https://github.com/libretro/retroarch-assets/tree/master/xmb/monochrome/png
  — drop-in filled-silhouette replacement for hardware-system icons
  (audit S1a, #23 research conclusion). Historical note: PR #22 tried
  the `automatic` (line-art) set and rolled back — see #23 for why.
- **Libretro XMB Interface docs**:
  https://docs.libretro.com/guides/xmb/

### 11.4 Reference videos

| Video | Source | Frames at | Resolution | Notes |
|:---|:---:|:---:|:---:|:---|
| A | https://www.youtube.com/watch?v=uNBPVgcvGpw | `/tmp/psp-xmb-videos/frames/v1-30s/v1-NNN.png` | 1280×720 | PS2 XMB-style launcher (Open PS2 Loader). PSP-style aesthetic on PS2. Secondary reference. |
| B | https://www.youtube.com/watch?v=8vS2gBVJr7s | `v2-30s/v2-NNN.png` | 1920×1080 | Real PSP firmware, Italian locale, ~6.x. Primary reference for PSP UI behaviour. |
| C | https://www.youtube.com/watch?v=UsXQMTDMuQQ | `v3-15s/v3-NNN.png` | 1280×720 | Real PSP firmware, English, focused on Theme/Color picker. Best reference for live-colorset-preview behaviour (audit U3). |

Frame timestamps in cited references use the form
`video {A,B,C} @ M:SS` — e.g., `video C @ 0:15` references frame
v3-001 (15-second intervals: frame N → (N-1)·15s).

### 11.5 Internal references

- [`docs/psp-authenticity-audit.md`](psp-authenticity-audit.md) — full
  catalog of PSP XMB features with feasibility analysis.
- [`docs/v0.10-roadmap.md`](v0.10-roadmap.md) — historical (v0.10)
  roadmap.
- [`docs/superpowers/specs/`](superpowers/specs/) — per-version
  design specs (single-source-of-truth for decisions).
- [`docs/screenshots/`](screenshots/) — per-aspect-ratio rendered
  samples (the visual ground truth for any future regression
  comparison).
- `_inc/common.xml` — variable definitions; canonical source for the
  defaults cited in this document.
- `_inc/aspect-{8x7,3x2,16x9,1x1}.xml` — per-ratio overrides.
- `colors/psp-*.xml` — colorset definitions.
- `theme.xml` — top-level include order, subset declarations,
  `defaultTransition`.

---

*End of guidelines. Last revised against theme v0.11-partial (July
2026). The v0.10 ship cluster has landed: S6 and X1 shipped, X2 was
design-rejected, ST1 remains blocked on #4. Re-evaluate after the
v0.11 gamelist redesign (PR #32) lands.*
