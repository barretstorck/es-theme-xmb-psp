# PSP XMB Authenticity Audit

A standing reference catalog of every observable PSP XMB feature that this
theme could plausibly approximate, scored against the current `v0.9.3`
implementation. Used as a wishlist / decision tool — entries here may or
may not graduate into a versioned roadmap.

**Inclusion rule:** An entry is listed in the active sections
(S / G / ST / A / X) only if a meaningful partial workaround exists
within EmulationStation's theme XML or asset surface. Features that are
*technically* unsupportable in ES are cataloged separately in the
`Unsupportable in EmulationStation` section with the technical reason
given for each. Items considered and dropped for *non-technical* reasons
— already shipped, settled design decision, not actually a PSP feature —
are listed in `Deliberately omitted`.

**Scope:** Knulli Scarab on TrimUI Brick, 4:3 (1024×768) primary; other
aspect ratios should inherit any change unless noted.

**Companion docs:**
- [`v0.10-roadmap.md`](v0.10-roadmap.md) — current versioned roadmap.
  Entries G4, G5, G6, X1 in this audit are the audit-lens re-entries of
  roadmap items 2, 3+5, 1, and 4 respectively.
- [`superpowers/specs/`](superpowers/specs/) — per-version design specs.

**Primary visual references:**
- Four user-provided PSP XMB stills (cited as "PSP screenshot 1/2/3/4"
  in early entries).
- YouTube video A — `https://www.youtube.com/watch?v=uNBPVgcvGpw` —
  a PS2 XMB-style launcher (FreeMcBoot + Open PS2 Loader). PSP-style
  aesthetic on PS2 hardware. Treated as secondary reference.
- YouTube video B — `https://www.youtube.com/watch?v=8vS2gBVJr7s` —
  real PSP firmware, Italian locale, ~6.x era (Skype + PSN visible).
  Primary canonical reference for PSP UI behaviour.
- YouTube video C — `https://www.youtube.com/watch?v=UsXQMTDMuQQ` —
  real PSP firmware, English locale, focused on the Theme/Color
  picker. Particularly useful for live colorset-preview behaviour and
  branded-item icon style. 3:23 total runtime.

Frame timestamps in `Reference:` fields use the form
`video {A,B} @ M:SS` (e.g. `video B @ 4:30`). For 30-second-spaced
extracted frames the mapping is frame N → (N−1)·30s into the video.

## Spike-round-1 findings (incorporated)

A round of four parallel research/prototype spikes against the
batocera-emulationstation source at `/tmp/bes-source` and the
existing Docker render harness produced the following verdict shifts.
Citations and prototype evidence live in the affected entries
below; this section is the change-log.

**Resolved (moved out of Unsupportable):**
- **U6 → S6.** Continuous wave across system carousel navigation is
  achievable today via an undocumented `name="staticBackground*"`
  prefix in `<view name="system">`. Verified with a two-shot render
  diff (baseline 24% pixel diff = reset; spike 0.45% = continuous).
- **U7 → Deliberately omitted.** Per-row cursor memory across
  cross-axis navigation is the ES default. `ViewController` caches
  game-list views by `SystemData*` and cursors persist inside the
  cached views.

**Reword without changing verdict:**
- **U1.** A static themed boot splash IS supported via `splash.xml`
  (one of `sSupportedViews`); only *animation* is blocked because
  `Splash::render` doesn't tick storyboards. New active entry S7
  added for the static splash.
- **U3.** Color animations DO parse and work
  (`ThemeColorAnimation` is first-class). The real blocker is
  event-routing: the only storyboard event names ever fired
  anywhere in the codebase are `activate`, `deactivate`, `scroll`,
  `open`, plus the unnamed default — none bridges menu-interaction
  to system-view extras.
- **U2, U5, U10.** Tightened evidence citations.

**Demoted (active → Unsupportable):**
- **S2 → U11.** `<format>` on the clock element is rejected;
  `<datetime>` missing from `createExtraComponent`. No theme-XML
  path to render the date next to the clock. X3 (battery-hide
  re-tune) dies with S2.
- **ST2 → U12.** `GlobalBinding::getProperty` exhaustive list has
  no wifi-strength / signal binding.
- **G9 → U13.** `MenuComponent::updateSize()` hardcodes menu
  position; the PSP right-side sidebar layout has no analog.

**Promoted (spike-needed → Ship-it):**
- **ST1.** `<batteryText>` element OR `{global:batteryLevel}`
  binding — both verified.
- **G3.** Native `<reflexion>` attribute (better than flipVertical;
  does the PSP fade-out mirror automatically).
- **G4.** `<itemTemplate>` works in `<gamecarousel>` with per-slot
  binding resolution.
- **G7 + G8.** Same `<itemTemplate>` mechanism plus
  `event="activate"` / `event="deactivate"` storyboards on template
  children. The audit's earlier "selector-tracked overlay text"
  framing was the wrong mental model.

**Cross-cutting constraints surfaced by the spikes:**
- Storyboard events ever emitted by ES: **`activate`, `deactivate`,
  `scroll`, `open`, default (unnamed).** Any future wishlist entry
  implying `event="boot"`, `event="select"`, `event="idle"`, etc.
  fails immediately on this constraint.
- `extra="true"` images and `<itemTemplate>` children get
  `ThemeFlags::ALL`. Carousel-managed intrinsic logos
  (`<image name="logo">`) get only `COLOR | ALIGNMENT | VISIBLE`.
  Wrap or use a template to unlock advanced attributes like
  `reflexion`, `flipY`, full storyboards.
- Pre-existing theme bug noticed during the S2 spike: the current
  theme uses `<horizontalAlignment>` which is a typo. The correct
  attribute is `<alignment>` (per `TextComponent.cpp:585`). Logs
  show ~80 parse warnings per render. Out of scope for the audit
  doc but worth fixing in a follow-up commit.

**Entry template:**

- **PSP behaviour** — what the real PSP firmware does.
- **Current theme** — what ships in `v0.9.3` today.
- **Reference** — which provided PSP screenshot demonstrates it, when
  applicable.
- **Feasibility** — `Ship-it` / `Partial workaround` / `Needs research`.
- **Workaround sketch** — the approximation we'd build.
- **Effort** — `Trivial` / `Small` / `Medium` / `Large`.
- **Dependencies** — other audit items this couples to.
- **Evidence** — file / code / commit pointers.

---

## System view (S)

### S1. PSP line-art system iconography

**PSP behaviour:** Category icons in the top row are a coherent set of
single-weight line drawings — a wrench/toolbox for Settings, a filmstrip
for Video, a controller for Game, a globe for Network, etc. Each is
drawn at the same line weight, fits inside a square footprint, and is
read as a silhouette.

**Current theme:** Knulli's per-system icon set (which the repo
bundles in `art/system-icons/`) is mostly chunky controller / console
silhouettes with mixed weights and styles. They read but they don't
hang together visually the way the PSP set does.

**Reference:** PSP screenshots 1 (briefcase Settings icon) and 4 (game
controller, filmstrip, globe).

**Feasibility:** Partial workaround — pure art work, no ES limit.

**Workaround sketch:** Authoring pass over `art/system-icons/*.png`,
replacing the current set with a unified PSP-style line-art treatment.
Group by physical media / vendor families (Nintendo carts, Sega
consoles, Sony consoles, computers, handhelds) and design one icon per
family that can be tinted slightly per-system or used identically.
Couples cleanly with G5: an entry-shared icon set means the
"per-system media fallback" icons in the gamecarousel can come from
the same library at smaller sizes.

**Effort:** Large (~180 system shortnames; even with grouping, ~30-50
hand-drawn icons).

**Dependencies:** G5 (fallback icons share the same art language).

**Evidence:** `art/system-icons/` listing; `_inc/system.xml:128-132`
(per-system icon binding via `${system.theme}`).

---

### S2. ~~Date next to clock~~ — DEMOTED to U11

This entry was demoted from active to **Unsupportable** by the
spike-round-1 verification. See **U11** in the Unsupportable
section below. The corollary entry X3 (battery-hide layout
re-tune) is also dropped — it was a dependency of S2 only.

Reason summary: `<text name="clock">`'s element has no `format`
property in the parser map; `<format>` is rejected at parse with
`Unknown property : text.format` (verified at
`ThemeData.cpp:231-278`). The `<datetime>` element exists as a
type with `format` support, but is missing from
`createExtraComponent` (`ThemeData.cpp:2123-2163`), so a free
`<datetime extra="true">` parses without warning but is never
instantiated. No theme-XML path to render the date alongside the
clock in `screen` view.

---

### S3. Drop shadow on selected carousel icon

**PSP behaviour:** Category and sub-item icons sit on the wave with a
subtle soft drop shadow. Not a hard outline — a low-opacity
downward-offset blurred copy that reads as depth against the moving
background.

**Current theme:** Flat icons. The selected icon gets a halo glow
behind it (the gaussian `halo.png`), but unselected icons are
completely flat against the wave, and the selected icon's shadow is
masked by the halo's center brightness.

**Reference:** Subtle but visible in PSP screenshots 1, 2, 4 — note
the slight darkening to the lower-right of each icon's silhouette.

**Feasibility:** Partial workaround — ES has no drop-shadow attribute;
fake it with pre-rendered shadow art.

**Workaround sketch:** Two options:
1. **Pre-burn the shadow into every icon PNG.** Cheap, no XML change.
   Couples to S1 — if we're redrawing the icon set anyway, the
   shadow becomes part of the asset. Risk: the shadow looks wrong
   against very-dark colorsets (October Crimson, November Slate).
2. **Stacked element approach.** Define a second `<image
   name="logoShadow">` per icon, offset by a few pixels and dimmed.
   ES carousel doesn't natively support per-logo additional layers,
   so this would only work for the *selected* slot via a screen-view
   extra. Probably not worth the XML complexity.

Recommend option 1 if S1 is in scope; defer otherwise.

**Effort:** Small (incidental to S1) / Medium (standalone if asset
regeneration is needed across all 180 icons).

**Dependencies:** S1.

**Evidence:** N/A — this is purely an art / asset decision.

---

### S4. Helpsystem button icons in PSP shapes

**PSP behaviour:** Button affordances along the bottom of menus
use the PSP face-button glyphs: ✕ (cross / confirm), ○ (circle /
back), □ (square), △ (triangle). They're rendered at small size with
short labels next to them ("✕ Enter  ○ Back").

**Current theme:** ES's `helpsystem` already renders bottom button
hints, styled via `<helpsystem name="help">` in `_inc/common.xml` —
position, font, colors are themed. The button glyphs themselves come
from ES's built-in icon set: directional pad chevrons, A/B/X/Y or
generic 1/2/3/4 depending on input device.

**Reference:** Not strongly visible in the provided screenshots
(PSP's settings/photo views show the buttons sometimes in different
poses); generic PSP UI behaviour.

**Feasibility:** Partial workaround — ES helpsystem accepts custom
icon paths.

**Workaround sketch:** Override each named helpsystem icon via
`<helpsystem>` child elements pointing at PSP-glyph PNGs:

    <helpsystem name="help">
      <iconUpDown>./art/help/pad-updown.png</iconUpDown>
      <iconLeftRight>./art/help/pad-leftright.png</iconLeftRight>
      <iconA>./art/help/cross.png</iconA>
      <iconB>./art/help/circle.png</iconB>
      <iconX>./art/help/square.png</iconX>
      <iconY>./art/help/triangle.png</iconY>
      ...
    </helpsystem>

Author 6-10 small PNG glyphs (~32×32 px) at the same line-art weight
as the system icon redraw. Verify exact attribute names against the
batocera-emulationstation `THEMES.md` helpsystem section, since some
forks rename them.

**Effort:** Small (XML) + Small-Medium (art).

**Dependencies:** S1 (visual consistency).

**Evidence:** `_inc/common.xml:131-137` (current helpsystem block);
batocera-emulationstation `THEMES.md` helpsystem section.

---

### S5. ◀ pointer next to selected sub-item

**PSP behaviour:** In drilled-in sub-item lists (Settings / Game /
Network sub-menus), the selected row carries a small left-pointing
chevron `◀` immediately to the LEFT of the row's icon. Pointer
nudges into the row from the category column, visually "tying" the
selected sub-item back to its parent category up the left edge.
Distinct from item scale or halo — it's a chevron-shaped UI glyph.

**Current theme:** No directional pointer chrome on selected
sub-items. The system carousel uses `logoScale=1.5` + halo to mark
selection; the gamecarousel uses `logoScale=1.5` + dimmed
neighbours. Neither shows a chevron.

**Reference:** video A @ 2:30 (Theme/Color selected with `◀` left of
the wrench icon); video A @ 3:30 (Display/Video Output Mode); video
B @ 4:30 (Pannello visore); video B @ 5:30 (Cambia uscita video);
video B @ 7:00 (Ora legale).

**Feasibility:** Ship-it.

**Workaround sketch:** For the gamecarousel selected slot, add a
small `<image>` element positioned to the left of the centred
selected slot, source `art/ui/chevron-left.png`. Pin to the same
y-coordinate as the slot's vertical center. Optional storyboard:
fade-in 100ms on selection-settle for parity with the halo's
fade-in cadence.

For the system carousel, the chevron doesn't fit as cleanly — PSP's
top-level XMB cross doesn't show the chevron either (it appears
only on vertical sub-item rows). Skip it for the horizontal
carousel; apply only to the vertical gamecarousel (and potentially
the `detailed`-style textlist's selected row, where ES already
provides a `<selectorImage>` slot — bind that to the chevron art
instead of the current gradient).

**Effort:** Small (XML + one PNG glyph).

**Dependencies:** S1 (chevron art-style consistency).

**Spike-round-1 verification:** Confirmed supported. `<textlist>`
accepts `<selectorImagePath>` (note: that's the spelled-out
property name, not `<selectorImage>`) plus
`<selectorImageTile>`, `<selectorHeight>`, `<selectorOffsetY>`
(`TextListComponent.h:778-789`, `THEMES.md:1027-1035`).
**Constraint:** the selector image's width is forced to the full
textlist width (`setSize(mSize.x(), mSelectorHeight)`). To get a
"chevron-next-to-the-row" look, author the PNG with the chevron at
the LEFT edge of a wide transparent canvas — the image stretches
horizontally otherwise. `selectorColor` tints the image (recolor
single white chevron per colorset).

For the gamecarousel there's no equivalent `selectorImagePath` —
its selection-indicator mechanism is the centred + logoScale-
enlarged slot. Use an `extra="true"` chevron pinned to
`crossX` / selected-slot Y instead.

**Evidence:** `TextListComponent.h:778-789`; `THEMES.md:1027-1035`;
prototype render at `/tmp/spike-carousel-s5/s5.png`.

---

### S6. Continuous wave animation across system carousel navigation

**PSP behaviour:** XMB wave animates continuously, completely
independent of menu navigation. Wave on its own timeline; icon
carousel on a separate one.

**Current theme (v0.9.3):** Wave layers are declared as
`extra="true"` images in `<view name="system">`. Their storyboards
restart at `t=0` on every system change because the per-system
`backgroundExtras` lifecycle calls `extra->onShow()` →
`mStoryboardAnimator->reset()` on cursor change
(`SystemView.cpp:852, 1534`; `GuiComponent.cpp:942`). Documented
since v0.3 in the README as a known limitation.

**Reference:** PSP / video A / video B / video C all show the wave
animating without ever restarting during navigation.

**Feasibility:** Ship-it. Workaround discovered + verified during
spike round 1.

**Workaround sketch:** Use the undocumented `staticBackground*`
name-prefix mechanism (`SystemView::getViewElements`,
`SystemView.cpp:1045-1065`). Elements whose `name` starts with the
literal string `"staticBackground"` are stored in a single
`mStaticBackgrounds` vector loaded ONCE at view construction (not
per-system). Their `update()` ticks every frame; their `onShow()`
is only invoked on view-show, **not** on cursor change. The
storyboard `reset()` cascade never fires.

Rename in `_inc/system.xml`:
- `waveBackground` → `staticBackgroundWave` (drop `extra="true"`)
- (the three motion wave layers, brought inline here from
  `_inc/wave-motion.xml`) → `staticBackgroundLayer{1,2,3}`
- `selectedHalo` → `staticBackgroundHalo` (drop `extra="true"`,
  drop both `<storyboard>` blocks — see X1 update below — and
  bump `<zIndex>` to 10 so it renders strictly above the wave but
  below the carousel icon).

In `_inc/wave-motion.xml`, change `<view name="system,detailed,gamecarousel">`
to `<view name="detailed,gamecarousel">` — gamelist views are
unaffected by the cursor-reset issue and keep their existing
declarations.

**Effort:** Small (~1 hour, mostly on-device verification — the
Docker harness uses desktop GL21 while the device uses GLES2; one
final TrimUI Brick render check is warranted before the v0.10
ship.)

**Dependencies:** Couples with X1 — the halo's
`<storyboard event="scroll">` was dead code on this build
(`CarouselComponent.cpp:267, 652` shows the `scroll` event fires
only on the carousel's intrinsic logos, never on extras); after
the rename it can be deleted outright.

**Evidence:** `SystemView.cpp:889` (mStaticBackgrounds render),
`:1045-1065` (name-prefix parse), `:852, 1534` (activateExtras →
onShow on cursor change); `GuiComponent.cpp:937-944` (onShow resets
storyboard); two-shot render diff in `/tmp/spike-u6-1/.dev/` —
baseline 24.15% pixel diff (RESET) vs spike 0.45% (CONTINUOUS, at
the sub-pixel sampling noise floor).

---

### S7. Static themed boot splash (single frame)

**PSP behaviour:** ~3 seconds of branded boot animation between
power-on and the main XMB. Animation is U1's territory (still
unsupportable). But the *static* component — a PSP-branded image
on a coloured background — IS achievable as a single frame held
for the duration of ES's boot.

**Current theme:** No `splash.xml` ships. Knulli falls back to its
own bootloader-level splash (which is what shows during the kernel
boot before ES starts).

**Reference:** PSP boot — generic firmware behaviour, not in the
captured reference videos.

**Feasibility:** Ship-it (static only — animation is U1).

**Workaround sketch:** Author `splash.xml` at the theme root.
`Splash::loadTheme` parses it as the `splash` view (one of
`sSupportedViews`, `ThemeData.cpp:31`) and applies a `background`
image, a `label` text, a `progressbar`, and theme extras
(`Splash.cpp:25-45`). Static frame only — `Splash::render` writes
opacity and re-renders extras but doesn't run an animation tick
(`Splash.cpp:254-330`), so storyboards on splash extras don't
advance. A single PSP-blue background with the "PSP" wordmark in
white at center is the practical scope.

**Effort:** Small (one PNG + one XML file).

**Dependencies:** none.

**Evidence:** `ThemeData.cpp:31` (`splash` in `sSupportedViews`);
`Splash.cpp:25-45` (theme loading); `Splash.cpp:254-330` (render
without storyboard tick); `main.cpp:557-566` (boot hook).

---

## Gamelist (G)

### G1. Game-select promo overlay (Daxter-style splash)

**PSP behaviour:** When the user selects a game on the XMB and
presses ✕, the system shows a short branded splash (publisher logo +
key art + tagline) before the game launches. The Daxter screen is the
canonical example — Ready At Dawn logo bottom-left, key art covering
most of the screen, large game logo.

**Current theme:** Nothing custom — the game launches via Knulli's
default launch sequence (which on TrimUI Brick is a brief black
"launching…" screen).

**Reference:** PSP screenshot 2 (Daxter title with Ready At Dawn
logo + corner video).

**Feasibility:** Partial workaround — Knulli has a
`launching-screen` / `launch image` feature separate from the theme.
A theme can ship default art used during launch; per-game art is
scraped via media-management. ES storyboard `event="select"` may or
may not fire on game-launch in this ES build (needs spike).

**Workaround sketch:** Two stacked solutions:
1. **Theme-level static launch art.** Ship a single PSP-style
   "launching" PNG at `art/launching.png`. Knulli's
   `LaunchingExtensionPath` or equivalent config points at it. Shows
   the same art for every game, but matches PSP's branded-feel.
2. **Per-game art via scraper.** If the user has the optional
   `media/launching.*` field populated per-system or per-game, Knulli
   uses that. Theme work here is zero — it's a documentation /
   media-scraping recommendation in `README.md`.

Recommend (1) as the theme deliverable + (2) as a README note.

**Effort:** Medium (research Knulli's launch-image API + author one
splash PNG) + (2) is doc-only.

**Dependencies:** none (independent of other entries).

**Evidence:** Knulli docs `launch-image` (verify exact config key);
ES `THEMES.md` storyboard events section.

---

### G2. Metadata key-value sidebar

**PSP behaviour:** When a media item is selected (photo, music,
video, game), metadata is rendered as labelled key-value pairs next
to the thumbnail: filename, date, time, format/region. Short white
labels left, values right, one pair per line. Compact.

**Current theme:** Right info panel shows: game name (large bold,
centered), rating (5 stars), video preview, scrolling description.
No genre/year/players/region rendering, even though ES scrapes those
into the metadata.

**Reference:** PSP screenshot 3 (PIC_0000 / `12/3/2021 18:39` / BMP
tag — exact key-value rendering).

**Feasibility:** Partial workaround — ES supports `<text>` elements
bound to `{game:releasedate}`, `{game:genre}`, `{game:players}` (and
others depending on ES build). Region tag requires either a
ROM-filename parse (not feasible in theme XML) or a custom scraped
field.

**Workaround sketch:** Insert a small key-value block in the info
panel above the description, between the rating row and the video.
Three rows at minimum: `Year · {game:releasedate}`, `Genre ·
{game:genre}`, `Players · {game:players}`. Label in
`${textSecondary}`, value in `${textPrimary}`, mid-dot separator.
Optional fourth row for `Region` if scraped data is reliable
(probably skip for v1).

Layout-wise these rows live between y=0.20 and y=0.36 in the right
panel, which currently has only the rating. The video element at
`mdVideoY=0.39` is the constraint — the new rows go above it, the
rating still leads.

**Effort:** Small.

**Dependencies:** G6 (adaptive layout: empty metadata rows should
hide so the layout doesn't reserve dead space; bindings need
`<visible>exists({game:releasedate})</visible>`-style guards).

**Evidence:** `_inc/gamelist.xml:115-154` (info panel layout);
`THEMES_BINDINGS.md` `{game:*}` bindings list.

---

### G3. Box-art reflection beneath selected gamecarousel image

**PSP behaviour:** Selected media (boxart, photo, video thumbnail)
has a soft mirrored reflection directly beneath it, fading to
transparent. Adds a "floating on glass" feel to the centered
selected item.

**Current theme:** Selected boxart has the halo (white gaussian)
behind it; no reflection.

**Reference:** PSP screenshot 2 (Daxter title bottom-left has a soft
reflection trailing the logo down).

**Feasibility:** Ship-it. Spike-round-1 found the native primitive
is `<reflexion>` (yes, that spelling), which renders the PSP-style
faded mirror automatically — better than `flipY` because it includes
the alpha gradient.

**Workaround sketch:**

```xml
<image name="boxArt" extra="true">
  <path>{game:thumbnail}</path>
  <pos>0.5 0.5</pos>
  <maxSize>0.2 0.2</maxSize>
  <origin>0.5 0.5</origin>
  <reflexion>0.7 0.0</reflexion>
  <!-- first=top alpha, second=bottom alpha -->
</image>
```

Or, when moving the gamecarousel to an `<itemTemplate>`
(see G4), use the same `<reflexion>` inside the template's
`<image>` child. This is the cleanest path because it combines
per-slot box-art rendering with the PSP-style mirror.

**Effort:** Small (no new art needed — ES generates the mirror
from the source image).

**Dependencies:** Couples cleanly with G4 (`<itemTemplate>`
adoption). If G4 ships first, G3 is a one-line addition to the
template.

**Limitations:** `<reflexion>` extends the painted area downward
beyond the image rectangle. Slot height needs ~30-40% extra below
the icon, or the reflection clips. Plain `<image name="logo">`
styled directly through the carousel does NOT honor `reflexion`
(carousel logos get only `COLOR | ALIGNMENT | VISIBLE` flags per
`CarouselComponent.cpp:740`) — must wrap in `extra="true"` or
`<itemTemplate>` to unlock it.

**Evidence:** `ImageComponent.cpp:820-825` (`reflexion`
`NORMALIZED_PAIR`); `ThemeData.cpp:2205` (extras get
`ThemeFlags::ALL`); `THEMES.md:820-825`; prototype renders at
`/tmp/spike-carousel-g3/g3.png` and
`/tmp/spike-carousel-g3-real/g3-real.png`.

---

### G4. Per-logo titles in gamecarousel

**Audit-lens re-entry of v0.10 roadmap item 2.** See [v0.10-roadmap.md
§2](v0.10-roadmap.md) for the deferred-item framing.

**PSP behaviour:** Every visible item in PSP's vertical sub-item list
has its label rendered alongside the icon — selected and unselected
alike.

**Current theme:** Built-in `gamecarouselLogoText` only renders as a
*fallback* when a game has no thumbnail.

**Reference:** PSP screenshots 1 + 4; video B @ 0:30; video C @ 0:00.

**Feasibility:** Ship-it. Spike-round-1 confirmed `<itemTemplate>`
is supported in `<gamecarousel>` with per-slot binding resolution.

**Workaround sketch:**

```xml
<gamecarousel name="gamecarousel">
  <type>vertical</type>
  <imageSource>thumbnail</imageSource>
  <pos>${gameColX} ${gameColCarY}</pos>
  <size>${gameColW} ${gameColH}</size>
  <logoSize>${gameCarLogoW} ${gameCarLogoH}</logoSize>
  <logoScale>${gameCarLogoScale}</logoScale>
  <maxLogoCount>5</maxLogoCount>
  <minLogoOpacity>0.6</minLogoOpacity>
  <itemTemplate>
    <image name="tplIcon">
      <pos>0.0 0.0</pos>
      <maxSize>0.4 0.4</maxSize>
      <origin>0 0.5</origin>
      <path>{game:thumbnail}</path>
      <!-- For G3 reflection, add <reflexion>0.7 0.0</reflexion> here -->
    </image>
    <text name="tplLabel">
      <pos>0.45 0.0</pos>
      <size>0.55 0.4</size>
      <origin>0 0.5</origin>
      <fontPath>${fontLight}</fontPath>
      <fontSize>0.030</fontSize>
      <color>${textPrimary}</color>
      <text>{game:name}</text>
      <alignment>left</alignment>
      <verticalAlignment>center</verticalAlignment>
    </text>
  </itemTemplate>
</gamecarousel>
```

`{game:name}`, `{game:thumbnail}`, `{game:desc}`, `{game:genre}` all
resolve PER-SLOT inside the template — confirmed in a multi-game
render showing ALPHA-GAME, BRAVO-QUEST, CHARLIE-SAGA, DELTA-FORCE,
ECHO-TALES each with their own label.

**Limitations:**
- Adopting `<itemTemplate>` replaces the carousel's intrinsic
  `<image name="logo">` and `<text name="gamecarouselLogoText">`
  slots. Lose the built-in text fallback for no-thumbnail games —
  add a fallback `<text>` inside the template instead, or pair
  with G5 (per-system media fallback icons).
- Template coordinates are slot-relative (not container-relative,
  not screen-relative). The slot is `logoSize.x × logoSize.y`
  before the `logoScale` boost.
- `logoScale` and `minLogoOpacity` still work (template root is
  scaled / opacity-modulated). For per-state styling of template
  children, use `<storyboard event="activate">` and
  `<storyboard event="deactivate">` (see G7+G8 for working
  example).

**Effort:** Medium (one-time XML rework of the gamecarousel block;
G7 and G8 ride along).

**Dependencies:** Couples with G3, G7, G8, G5. The `<itemTemplate>`
adoption unlocks all four at once — recommend shipping as a single
v0.10 task.

**Evidence:** `ThemeData.cpp:30` (`sSupportedItemTemplate`
includes `gamecarousel`); `CarouselComponent.cpp:697-711, 770`
(template per-entry instantiation + per-entry `updateBindings`);
`BindingManager.cpp:447-480` (`GridTemplateBinding` falls through
to FileData → `{game:*}` resolution); prototype render at
`/tmp/spike-carousel-g4/g4.png`.

---

### G5. Selected-game halo + per-system fallback icons (coupled)

**Audit-lens re-entry of v0.10 roadmap items 3 + 5.** See
[v0.10-roadmap.md §3 and §5](v0.10-roadmap.md). The two items couple
naturally because a no-thumbnail game gets a system-media fallback
icon instead of a white text label, which means the white halo no
longer obscures readable text.

**PSP behaviour:** Selected sub-items get a soft glow behind them,
regardless of whether the slot is showing a thumbnail or a generic
icon (Photos browser uses a generic camera/photo icon when an image
is unprocessed). The glow is consistent.

**Current theme:** Selected system in the system carousel gets a
soft white halo (`art/halo.png`). The gamecarousel does NOT — a
v0.9.3 round 4 attempt to add one was reverted because the carousel
falls back to large white text when a game lacks a thumbnail, and
the white halo behind the white text was unreadable.

**Reference:** PSP screenshots 1 and 3 — the selected `AVLS` row and
the selected `PIC_0000` photo each have a subtle highlight bar /
glow behind them.

**Feasibility:** Partial workaround — two coupled changes.

**Workaround sketch:**
1. **Per-system media fallback icons.** Author 5-8 media-type icons
   (CD-ROM, cartridge, floppy, handheld-cart, computer-media,
   generic-ROM, arcade-board, virtual). Mapping table from
   `${system.theme}` → icon-name, materialized as a per-system
   include file or a giant `<variables>` block in `common.xml`. The
   chosen icon element renders only when `<visible>!exists({game:thumbnail})</visible>`,
   replacing the white-text fallback.
2. **Conditional halo in the gamecarousel.** Once the fallback is an
   icon (not text), the existing system-halo design works. Re-add
   the `<image name="selectedGameHalo">` at the selected slot
   position, white gaussian, same `halo.png` source.

**Effort:** Medium (art for icons + theme XML wiring).

**Dependencies:** S1 (icon design language matches);
G6 (visibility-binding pattern is the same primitive).

**Evidence:** v0.9.3 round 4 commit history;
`CarouselComponent.cpp:730-767` (imageSource + text-fallback path).

---

### G6. Adaptive layout on metadata absence

**Audit-lens re-entry of v0.10 roadmap item 1.** See
[v0.10-roadmap.md §1](v0.10-roadmap.md) for the existing
deferred-item analysis.

**PSP behaviour:** Empty metadata fields don't leave blank space.
Items adapt — if a photo has no caption, the metadata block shrinks;
if there's no preview, the thumbnail expands. No "dead reserved
zone" visible.

**Current theme:** All info-panel elements render at fixed
positions whether or not the game has metadata. A game with no
description leaves the lower-right ~30% of the panel empty; a game
with no scraped video leaves the upper-right ~25% empty.

**Reference:** PSP screenshots 1 (settings rows have no images;
text expands) and 3 (photo browser shows compact metadata block).

**Feasibility:** Partial workaround — `<visible>exists({game:*})</visible>`
bindings can HIDE empty elements, but `<pos>` / `<size>` are not
bindable to expressions (verified in
`docs/v0.10-roadmap.md` evidence: `THEMES.md:1398`,
`ThemeData.cpp:1083`), so remaining elements can't REFLOW to fill
the gap.

**Workaround sketch:** Hide-only. Add `<visible>` bindings on
`md_video`, `md_description`, `md_image`. Empty elements vanish;
remaining elements stay in place. Better than the current "render an
empty container" state, even if it's not full PSP-style reflow.

Alternative: ship 3-4 view variants (`detailed-full`,
`detailed-no-video`, `detailed-text-only`) and let the user pick via
a theme subset. Honest but rigid. See v0.10-roadmap item 1
discussion for the full tradeoff analysis.

**Effort:** Medium.

**Dependencies:** G2 (the new key-value rows from G2 each need the
same `<visible>exists(...)</visible>` guards).

**Evidence:** `docs/v0.10-roadmap.md` §1; `THEMES_BINDINGS.md:264-302`.

---

### G7. Two-line selected-item layout (title + inline description)

**PSP behaviour:** In list / sub-item views, the selected row
renders as TWO STACKED LINES: the title in normal-weight white text
on line 1, and an italic-looking lower-contrast description on line
2 (smaller font, dimmed colour). Unselected rows show only the
title. A thin horizontal underline visually separates the selected
row's title from its description.

The second line is also used for **metadata-style status info** on
some rows. Video C @ 1:00 shows "Memory Stick™" as title with
"Free Space  542 MB" as the second line — title + metadata
(label + right-aligned value) combined on a single row. So G7's
second-line slot is reused for either prose description (settings)
or labelled metadata (status items).

This is distinct from a side-panel description (which the audit's
G2 covers) — it's the row itself expanding to two lines when
selected.

**Current theme:** Right info panel shows the game description in a
*separate* panel to the right of the list (gamelist `detailed` and
`gamecarousel` views). The selected row in the textlist is a single
line — no inline expand.

**Reference:** video A @ 1:30 ("Ajustes de Sistema / Ajusta la
configuración…"); video B @ 4:30 ("Pannello visore / ma PSP™
risponde alla chiusura del pannello visore"); video B @ 5:30
("Cambia uscita video / ta la visualizzazione dell'uscita video
sullo schermo"); user screenshot 1 (AVLS row).

**Feasibility:** Ship-it. The spike-round-1 framing of "selector-
tracked overlay text" was the wrong mental model — there's no such
primitive. The CORRECT mechanism is `<itemTemplate>` plus
`event="activate"` / `event="deactivate"` storyboards on the
template's description text element. Verified by prototype.

**Workaround sketch:**

```xml
<textlist name="gamelist">
  <pos>${gameColX} ${gameColTextY}</pos>
  <size>${gameColW} ${gameColH}</size>
  <fontPath>${fontRegular}</fontPath>
  <fontSize>0.032</fontSize>
  <alignment>left</alignment>
  <selectorColor>00000000</selectorColor>
  <!-- bump lineSpacing so the per-row template has vertical room
       for both title and description on selected rows -->
  <lineSpacing>1.8</lineSpacing>
  <zIndex>5</zIndex>
  <itemTemplate>
    <!-- G7 line 1: title -->
    <text name="row_title">
      <pos>0.0 0.0</pos>
      <size>0.65 0.55</size>
      <fontPath>${fontRegular}</fontPath>
      <fontSize>0.030</fontSize>
      <color>${textPrimary}</color>
      <text>{game:name}</text>
      <alignment>left</alignment>
    </text>
    <!-- G8 (paired): right-aligned value column. See G8 entry. -->
    <text name="row_value">
      <pos>0.65 0.0</pos>
      <size>0.34 0.55</size>
      <fontPath>${fontLight}</fontPath>
      <fontSize>0.026</fontSize>
      <color>${textSecondary}</color>
      <text>{game:genre}</text>
      <alignment>right</alignment>
    </text>
    <!-- G7 line 2: description, fades in only on the selected row -->
    <text name="row_desc">
      <pos>0.0 0.55</pos>
      <size>0.99 0.45</size>
      <fontPath>${fontLight}</fontPath>
      <fontSize>0.022</fontSize>
      <color>${textSecondary}</color>
      <text>{game:desc}</text>
      <alignment>left</alignment>
      <opacity>0</opacity>
      <storyboard event="activate">
        <animation property="opacity" from="0" to="1"
                   duration="150" mode="linear"/>
      </storyboard>
      <storyboard event="deactivate">
        <animation property="opacity" from="1" to="0"
                   duration="150" mode="linear"/>
      </storyboard>
    </text>
  </itemTemplate>
</textlist>
```

Prototype rendered 5 rows; only the selected row shows the
description fade-in. Confirms `activate`/`deactivate` storyboards
fire correctly for per-row selection.

**Limitations:**
- All rows pre-render the description text (just at opacity 0).
  Cheap for a few hundred entries; tens of thousands of long
  descriptions would add memory cost.
- `<textlist>` `primaryColor` / `secondaryColor` / `selectorColor`
  no longer apply when `<itemTemplate>` is in use — style per text
  element instead.
- No native truncation binding; long descriptions render full
  width within the row's `0.45` vertical band.

**Effort:** Small if G4 (`<itemTemplate>` adoption) is done in the
same task. Standalone for the `detailed` textlist: Medium (the
textlist needs its own template even if the gamecarousel doesn't
yet use one).

**Dependencies:** G8 (right-aligned value column shares the same
template). G4 (same `<itemTemplate>` mechanism).

**Evidence:** `TextListComponent.h:274-340` (per-entry render +
`updateBindings(bindable)` at :316 — per-row binding resolution);
`TextListComponent.h:637-660` (`activate`/`deactivate` storyboards
on cursor change); `TextListComponent.h:682-684` (itemTemplate
parsing); prototype render at `/tmp/spike-carousel-g78/g78.png`.

---

### G8. Right-aligned current-value display per row

**PSP behaviour:** Settings rows render as `<Title>  |  <Value>`
with the value right-aligned at the row's right edge. Title in
white, value in slightly lower-contrast white. The visual separator
is whitespace, not a divider — `Formato dell'ora` … `24 ore`,
`Fuso orario` … `GMT+01:00…`, `Dynamic Normalizer` … `Off`.

For a game library, the conceptual analog is per-row metadata:
year, genre, rating short-form — anything compactly summarisable.

**Current theme:** Game rows in the `detailed` textlist show the
game NAME only. Year, genre, players, rating live in the side info
panel (and currently not all of them are rendered — see G2).

**Reference:** video A @ 3:30 (NTSC/PAL/DTV picker — the picker
panel is U10's territory, but rows in same view show value-right);
video B @ 4:30 (settings rows); video B @ 7:00 (date/time rows);
video B @ 7:30 (AVLS Off / Dynamic Normalizer Off); video C @ 2:30
(Date Format `DD/MM/YYY...`, Time Format `24 Hour Clo...` — both
showing **truncation with `...`** when the value is wider than its
slot, and a **multi-line value** on the Date and Time row showing
`7/4/2025` on line 1 stacked with `0:16` on line 2 at right-aligned).

**Feasibility:** Ship-it. Same mechanism as G7 —
`<itemTemplate>` with a right-aligned `<text>` element bound to
`{game:genre}` (or `{game:releasedate}`, `{game:players}`).

Bonus observation from video C (frame v3-011): real PSP shows the
**value column on ALL rows**, not just the selected row. So unlike
G7's description (selected-row only), the value column in PSP
doesn't need `activate`/`deactivate` storyboards — it's always
visible. The XML snippet in G7's workaround already reflects this:
the `row_value` text has no storyboard.

**Workaround sketch:** See G7's full template snippet. The
`row_value` element handles G8.

For multi-line values (e.g., the PSP `7/4/2025 0:16` date+time
stacked observed in video C @ 2:30): use a single `<text>` with
multiline content (`{game:releasedate}\n{game:lastplayed}`) — or
two separate `<text>` elements stacked. Verify the newline literal
behaviour in this build before committing to one path.

**Limitations:**
- Long values: PSP truncates with `...` when overflow (video C @
  2:30 shows `DD/MM/YYY...`, `24 Hour Clo...`). ES `<text>` either
  truncates or wraps; verify which is the default and whether
  `<container>true</container>` enables the marquee.
- All-rows rendering: same memory note as G7. Negligible for
  typical libraries.

**Effort:** Trivial if G7 ships in the same task.

**Dependencies:** G7 (shared `<itemTemplate>`).

**Evidence:** Same as G7 (`TextListComponent.h:274-340, 682-684`);
prototype renders all rows with both title + right-aligned genre.

---

### G9. ~~Right-side value picker~~ — DEMOTED to U13

This entry was demoted from active to **Unsupportable** by the
spike-round-1 verification. See **U13** in the Unsupportable
section below.

Reason summary: `MenuComponent::updateSize()` hardcodes menu
position to horizontal-centered, width = `min(screenHeight,
screenWidth * 0.90f)`. `OptionListPopup` is positioned by the
same hardcoded math. No theme primitive controls menu layout.
The PSP right-side sidebar form factor has no ES analog.

A reduced-scope offshoot — "more aggressively style the menu
chrome within what IS themable" (cornerSize, scrollbarColor,
menuIcons, menuSwitch, menuButton paths, selectorImagePath) — is
viable and could become its own entry (G9a) if pursued. Left
unfiled until a v0.11 brainstorm decides whether to invest there.

---

### G10. Branded item icons (colour, not monochrome)

**PSP behaviour:** Top-level category icons (Music, Video, Game,
Settings, Network) are flat monochrome white silhouettes. But
*items inside those categories* that represent third-party apps,
storefronts, or services — PlayStation Network, PS Store, Skype,
Information Board, Internet Search — use **full-colour 3D-rendered
icons**, each with its own brand identity. The visual hierarchy is
"category = silhouette, item = brand."

**Current theme:** All system icons in `art/system-icons/` are
white silhouettes (via Knulli's icon pack). The auto-collections
(`auto-favorites`, `auto-lastplayed`, `auto-allgames`) use the
same monochrome style as system icons. There's no "branded item"
treatment for special entries.

**Reference:** video C @ 0:00 (Network category sub-item: blue/
purple PSN swirl icon next to monochrome Network globe — clear
two-tier hierarchy visible in the same frame); video C @ 3:00
(PSN landing showing PlayStation Network swirl, blue shopping-bag
PS Store icon, orange Information Board icon — all full colour);
video B @ 0:30 (Skype `S` logo in blue circle next to monochrome
Game/Network icons).

**Feasibility:** Ship-it — purely an art / asset decision.

**Workaround sketch:** Identify which ES "system" entries should
get branded treatment versus silhouette treatment. Candidates:
- `auto-favorites.png` — could be a coloured heart/star (e.g.
  gold/yellow), distinct from the silhouette category icons.
- `auto-lastplayed.png` — could be a coloured clock or "recent"
  badge.
- Special launchers: `retroarch.png`, `ports.png`, `tools.png` —
  could carry the host emulator/app's brand colour rather than
  white silhouette.
- Cloud/online services if Knulli ships them.

Drop replacement PNGs into `art/system-icons/` with the same
naming. The theme automatically picks them up. Keep silhouette
icons for hardware-system entries (NES, SNES, etc.) so the
hierarchy reads as "hardware = silhouette, service = branded."

**Effort:** Small (per icon) — but the *decision* of which entries
to brand is the design work.

**Dependencies:** S1 (the silhouette pass; branded icons are
defined as the *contrast* to the silhouette baseline).

**Evidence:** N/A in current code; `art/system-icons/` directory
naming convention from README ("To add a specific icon for any
system, drop `<system-shortname>.png` into `art/system-icons/`").

---

## Status bar (ST)

### ST1. Battery percentage numeric next to glyph

**PSP behaviour:** When the battery is the active focus (e.g. when
unplugged or in a low-battery state), PSP shows the numeric
percentage next to the icon.

**Current theme:** Glyph only — the `<batteryIcon>` element
auto-selects between 6 image states. No numeric.

**Reference:** Not visible in the captured reference videos — this
is a known PSP firmware feature, optional.

**Feasibility:** Ship-it. Spike-round-1 confirmed two supported
paths.

**Workaround sketch (recommended — native batteryText element):**

```xml
<view name="screen">
  <batteryText name="batteryPercent">
    <pos>0.88 0.03</pos>
    <size>0.05 0.06</size>
    <fontPath>${fontRegular}</fontPath>
    <fontSize>0.030</fontSize>
    <color>${textPrimary}</color>
    <alignment>right</alignment>
  </batteryText>
</view>
```

`<batteryText>` is in `_autoExtraTypes` (`ThemeData.cpp:34`); no
`extra="true"` needed. Auto-hides via
`setVisible(hasBattery && level >= 0)`. Honors the existing user
`ShowBattery=text` setting — consistent with how `<batteryIcon>`
honors `ShowBattery=icon`.

**Alternative path (binding-based, no `ShowBattery` requirement):**

```xml
<text name="batteryPercent" extra="true">
  <pos>0.88 0.03</pos>
  <size>0.05 0.06</size>
  <fontPath>${fontRegular}</fontPath>
  <fontSize>0.030</fontSize>
  <color>${textPrimary}</color>
  <alignment>right</alignment>
  <value>{global:batteryLevel}%</value>
  <visible>{global:battery}</visible>
</text>
```

`{global:batteryLevel}` returns the int level from
`Utils::Platform::queryBatteryInformation().level`
(`BindingManager.cpp:52-53`); `{global:battery}` is the `hasBattery`
bool.

**Effort:** Trivial.

**Dependencies:** none (S2 dependency removed since S2 was
demoted).

**Evidence:** `BatteryTextComponent.{h,cpp}`; `ThemeData.cpp:34`
(auto-extra registration), `:2147-2148` (createExtraComponent
dispatch); `BindingManager.cpp:52-53` (battery binding
registration).

---

### ST2. ~~Wifi-strength bars~~ — DEMOTED to U12

This entry was demoted from active to **Unsupportable** by the
spike-round-1 verification. See **U12** in the Unsupportable
section below.

Reason summary: `GlobalBinding::getProperty`
(`BindingManager.cpp:18-71`) registers an exhaustive global-
binding list with no wifi-strength entry — only the binary
`{global:network}` (is IP set?) and `{global:ip}`. Knulli's
`knulli-wifi` CLI handles enable/disable but exposes no scan/level
interface to the theme layer. Closest achievable is the binary
present/absent which is what ES's built-in `<networkIcon>` already
shows.

---

## Audio (A)

### A1. Audit existing sound assets for PSP-authentic timbre

**PSP behaviour:** PSP XMB navigation sounds are distinctive: a
short bright "tick" on horizontal cross moves, a soft mid-pitch
"select" on confirm, a low descending "back" on cancel. They're
synthesized — not sampled — and have a recognizable PSP/Sony
sound-design signature.

**Current theme:** `sounds/navigate.wav` (41 KB), `sounds/select.wav`
(50 KB), `sounds/back.wav` (71 KB) ship today. Bindings are wired
via `<sound name="systemscroll">`, `name="scroll"`, `name="select"`,
`name="back"` in `_inc/common.xml:117-128`. The audit question is:
how PSP-authentic are the current sounds?

**Reference:** Audio, not visual — no screenshot reference.

**Feasibility:** Quality check — possibly already done. Listen to
the existing assets; if they're already PSP-style, close this entry.
If they're generic UI bleeps, source or generate replacements.

**Workaround sketch:** Compare existing `.wav` files (waveform +
listen) to PSP XMB sound clips on YouTube / archive.org. If they
already match the PSP timbre, mark this entry shipped. If they
don't, either:
1. Source CC-licensed PSP-style synth bleeps from freesound.org or
   similar.
2. Generate via a short Python `numpy` + `wavfile` script — the PSP
   tick is approximately a sine-wave at ~3 kHz with a 5 ms
   exponential decay envelope; the back sound is a downward sweep
   from 1500 Hz to 600 Hz over 80 ms. (Don't ship verbatim PSP
   samples — copyright; aim for PSP-*style*.)

**Effort:** Trivial (if existing assets are fine) / Small (if regen
needed).

**Dependencies:** A2 (`systemscroll` may want a distinct "swoosh"
rather than reusing `navigate.wav`).

**Evidence:** `_inc/common.xml:117-128`; `sounds/` directory listing.

---

### A2. Distinct system-change "swoosh"

**PSP behaviour:** Horizontal cross moves (between top-level
categories) sound different from vertical sub-item moves — the
horizontal is more of a soft "swoosh" with a low-frequency
component, the vertical is the bright tick.

**Current theme:** `_inc/common.xml:117-119` binds *both*
`systemscroll` and `scroll` to the same `${soundNavigate}` file. So
horizontal carousel scroll and vertical menu scroll use the same
audio.

**Reference:** Audio, not visual — PSP behaviour.

**Feasibility:** Ship-it — different `.wav` files for the two `<sound>`
elements.

**Workaround sketch:** Add `${soundSystemScroll}` variable to
`_inc/common.xml`'s `<variables>` block pointing at e.g.
`./sounds/system-scroll.wav`. Update the `<sound
name="systemscroll">` binding to use it. Source / generate the
swoosh sound (see A1 generation notes — about 200 ms duration,
center frequency ~800 Hz, with a slight pitch bend).

**Effort:** Small (XML rewire + one new sound asset).

**Dependencies:** A1 (consistent timbre across the set).

**Evidence:** `_inc/common.xml:117-119`.

---

## Cross-cutting (X)

### X1. ~~Halo fade on carousel scroll~~ — DEAD CODE, delete with S6

**Audit-lens re-entry of v0.10 roadmap item 4.** See
[v0.10-roadmap.md §4](v0.10-roadmap.md).

**PSP behaviour:** The selected-item glow doesn't persist as a
static dot during cross-axis movement. It fades out during the
transition and back in once the new selection settles.

**Current theme:** v0.9.3 round 4 added `<storyboard event="scroll">`
to the `selectedHalo` element in `_inc/system.xml:53-58`. Spike-
round-1 verified by source inspection that this is **dead code on
this ES build**: `CarouselComponent` only fires the `"scroll"`
event on its own intrinsic logos (`CarouselComponent.cpp:267, 652`
— `mLogo[i]->selectStoryboard("scroll")`), never on extras. The
halo is declared as `extra="true"` (not as an intrinsic logo), so
the storyboard never receives the event. The fade-in default
storyboard runs once at view-show (covering the initial system
view appearance), then never again.

**Recommended action:** Delete both `<storyboard>` blocks on the
halo element when applying the S6 workaround (the halo will be
renamed to `staticBackgroundHalo` as part of S6's
`staticBackground*` rename pass). The visible behaviour is "halo
sits static behind the selected icon" — same as v0.9.2 — which is
acceptable per the original "Worst case" framing.

**Effort:** Trivial (delete the two storyboard blocks; happens
inside S6's edits anyway).

**Dependencies:** S6 (apply together).

**Evidence:** `CarouselComponent.cpp:267, 652` — scroll event is
emitted only on intrinsic logos via `mLogo[i]->selectStoryboard
("scroll")`, never on the surrounding extras vector.
`_inc/system.xml:53-58` — the storyboards that were unreachable.

---

### X2. Description scroll affordance (▼ / ▲)

**PSP behaviour:** When a text block exceeds its container, PSP
shows a small triangle at the cut edge indicating "more text below"
(or above). Subtle but consistent across all PSP UI.

**Current theme:** The description text element has
`<container>true</container>` in `_inc/gamelist.xml:152`, which
enables ES's built-in scroll behaviour. The text *does* scroll on
selection, but there's no visual cue that text is being cut at the
container edge.

**Reference:** Subtle in screenshot 1 — the description text wraps
mid-word at the right edge, suggesting more text exists; PSP's
firmware would normally show a triangle.

**Feasibility:** Ship-it.

**Workaround sketch:** Two static `<image>` elements pinned at
container top + bottom edges, sized ~12×8 px, with a downward /
upward chevron PNG. Always visible — spike-round-1 confirmed there
is no `descriptionoverflow` / scroll-state binding:
`FileData::getProperty`'s static map
(`FileData.cpp:40-61`) has no description-state entry, and
`ScrollableContainer` exposes no `applyTheme` integration nor any
binding hook for `mScrollPos` / `mAtEnd`. Slight visual overhang on
short descriptions is the accepted tradeoff.

Apply to both `detailed` and `gamecarousel` views — both share the
same description container.

**Effort:** Small.

**Dependencies:** none.

**Evidence:** `_inc/gamelist.xml:146-154` (description container).

---

### X3. ~~Battery-Hide layout re-tune after S2~~ — DROPPED

This entry was a corollary of S2 (date next to clock). With S2
demoted to U11 (technically unsupportable in Knulli ES), X3 has
no trigger and is dropped from the audit.

---

## Unsupportable in EmulationStation

PSP XMB features that this theme cannot meaningfully approximate, with
the technical reason recorded. The point of listing them is so future
iterations don't waste a research spike re-discovering the same dead
end, and so a reader of the audit knows *what's missing and why*, not
just what's present.

### U1. PSP boot animation (wave intro + "PSP" text wipe)

**PSP behaviour:** Roughly three seconds of branded boot animation
between power-on and the main XMB — wave fades in from black, "PSP"
wordmark performs a left-to-right reveal, then settles into the
running XMB.

**Why unsupportable:** ES *does* support a themable boot splash via
`splash.xml` at theme root — `splash` is in `sSupportedViews`
(`ThemeData.cpp:31`), and `Splash::loadTheme`
(`Splash.cpp:25-45`) applies background image, label text, progress
bar, and theme extras. So the static aesthetic side IS achievable —
that's now covered by the active entry **S7**. What's unsupportable
is the **animation**: `Splash::render` (`Splash.cpp:254-330`) only
writes opacity and re-renders extras — it doesn't tick the
storyboard clock. Storyboards on splash extras never advance, so
the "wave fades in / PSP wordmark wipes" timed sequence can't be
reproduced. Additionally, no `event="boot"` / `event="startup"`
trigger exists; the only storyboard event names ever emitted are
`activate`, `deactivate`, `scroll`, `open`, plus the unnamed
default.

**Closest we could get:** Ship a static branded splash via S7 — a
single PSP-blue background with the wordmark held for ES's boot
duration. No animation.

**Evidence:** `ThemeData.cpp:31` (sSupportedViews includes splash);
`Splash.cpp:25-45` (theme loading); `Splash.cpp:254-330` (render
without storyboard tick); `main.cpp:557-566` (boot hook).

---

### U2. Dynamic per-game layout reflow

**PSP behaviour:** When an item lacks metadata (no caption, no
preview, no description), the *remaining* elements REFLOW to fill
the gap — not just hide. Selecting a photo with no caption makes the
thumbnail expand; an audio track with no album art makes the title
text take the cover slot.

**Why unsupportable:** ES theme XML resolves `<pos>` and `<size>` at
parse time as static floats. They are not bindable to expressions or
metadata predicates. ES has `<visible>` bindings (which support
`exists({game:*})` predicates), but visibility only HIDES — it
doesn't shift sibling positions.

**Closest we could get:** Hide-only reflow via `<visible>` bindings —
this is what audit entry G6 implements. Empty elements disappear;
the layout has gaps. Better than the current "render empty
container" but not the PSP reflow.

**Evidence:** `ThemeData.cpp:1647-1649` — `processElement` for
`NORMALIZED_PAIR` calls `Vector2f::parseString(str)`
unconditionally, with no `_binding` fallback path (contrast with
`STRING`/`FLOAT`/`BOOLEAN` types at `:1622`, `:1633`, `:1656` which
DO check for `{...:...}` patterns and store as `name_binding`).
`Vector2f::parseString` at `math/Vector2f.cpp:22-34` calls
`Utils::String::toFloat` per half, silently returning `0.0` for
non-numeric tokens. Prototype: `<pos>{game:width} {game:height}</pos>`
silently coerces to `(0,0)` with no parse warning logged.
v0.10-roadmap.md §1 evidence trail.

---

### U3. Live colorset preview (wave updates during settings change)

**PSP behaviour:** In the Settings → Theme → Color picker, the
wave background updates **immediately** as the user scrolls through
the colour swatches in the sidebar — no commit step, no
intermediate "applying…" message. Highlight gold in the sidebar →
wave is gold. Highlight red → wave is red. Highlight teal → wave is
teal. The transition between swatches looks close to instant in the
captured frames; whether it has a short cross-fade (<100ms) or is
truly instant isn't resolvable at the 15-second extraction interval.

(Note: a *separate* claim — that the PSP wave cross-fades between
top-level XMB categories at navigation time — is sometimes
reported as PSP behaviour but is **not directly verified** in any
of the three reference videos here. Across multiple category
navigations in videos A, B, and C the wave appears to stay the same
hue. If a future reference confirms category-level cross-fade,
extend this entry; for now the verified phenomenon is the
Color-picker live preview.)

**Why unsupportable:** Originally claimed "Storyboards can't
animate color." Spike-round-1 disproved that — color animations DO
parse and work (`ThemeStoryboard.cpp:108-112` dispatches
`ThemeColorAnimation` for any property typed `COLOR`, which most
visual elements expose). The actual blocker is **event-routing**:
the only storyboard event names ever emitted across the codebase
are `activate`, `deactivate`, `scroll`, `open`, plus the unnamed
default. None bridges menu-interaction (the user scrolling the
Color picker) to system-view extras (the wave). Even if the wave
had `<storyboard event="someEvent"><animation property="color"
from="..." to="..."/></storyboard>`, nothing would ever fire
`someEvent`. Additionally, switching `${waveTint}` between
subset values requires a theme reload because the variable is
resolved at parse time (`ThemeData.cpp:1615`).

(There IS a useful side-effect of this finding: a color-storyboard
on `event="activate"` is a legitimate technique the theme could
exploit elsewhere — e.g., tinting the selected-system halo on
cursor-settle. Worth a separate exploration, not part of U3.)

**Closest we could get:** Ship the 12 fixed colorsets (current
behaviour). Each selection requires a Quit → Restart ES cycle for
the change to take effect; PSP's no-restart live preview is
unsupportable.

**Evidence:** Video C @ 2:00-3:00 (wave changing red → orange →
teal → cyan as the user scrolls the Color-picker sidebar);
`ThemeStoryboard.cpp:108-112` (color animations DO work); grep
across source for `selectStoryboard("` shows only `activate`,
`deactivate`, `scroll`, `open` event emitters; subset mechanism in
`theme.xml:31-44` requires full reload.

---

### U4. Photos / Music / Video / Network top-level browsers

**PSP behaviour:** XMB has dedicated top-level categories — Photos,
Music, Video, Network — each with its own browser UI styled
identically to the Game category but adapted to the media type.

**Why unsupportable in a theme:** ES themes style *systems*. The
core ES architecture treats a system as a games folder with a
configuration entry; there is no theme primitive for "create a new
top-level category that isn't backed by a system folder." Knulli /
Batocera ship separate features (Image Viewer, Media Player) for
photos / music / video, but they're invoked from a different code
path (the main menu) and don't use the theme's view definitions.

**Closest we could get:** Treat each scraped game system as a
category (the working analogue, currently shipping). For PC photos /
music browsers, the user uses Knulli's separate viewers — those
appear briefly outside the theme.

**Evidence:** ES `SystemData` architecture — themes style systems,
not custom top-level entries; Knulli media-viewer apps are separate
ELF binaries, not ES extensions.

---

### U5. Wave-colour shifts during boot warmup

**PSP behaviour:** Reported lore: during the first ~5-10 seconds
after boot, the wave colours warm up — desaturated → full saturation
— as part of the "system starting" cue. **Not directly verified in
any of the reference videos.** Kept here because the technical
unsupportability holds regardless.

**Why unsupportable:** With U3 corrected (color animations DO work),
the real blocker shifts: (a) splash render path doesn't tick
storyboards — `Splash::render` (`Splash.cpp:254-330`) only writes
opacity, no animation update, so the time-base needed to drive
`from → to` over `duration` is absent during the splash window;
(b) the post-splash system view doesn't expose any "first N seconds
of XMB lifetime" event a storyboard could hook. Net: the warmup
animation has no clock available to it.

**Closest we could get:** Nothing. Ship a static colorset.

**Evidence:** `Splash.cpp:254-330` (no storyboard tick on splash);
U3 (color animation primitive exists but needs a triggering event);
grep across source confirms no `event="boot"` /
`event="warmup"` / `event="idle"` emitters.

---

### U6. ~~Continuous wave animation across system carousel navigation~~ — RESOLVED

This entry was wrong. Spike-round-1 found a working theme-XML-only
solution that was missed by v0.3's "exhaustively verified"
investigation: the **`name="staticBackground*"` prefix mechanism**
(`SystemView::getViewElements`, `SystemView.cpp:1045-1065`).
Elements whose `name` attribute begins with the literal string
`"staticBackground"` are kept in a separate `mStaticBackgrounds`
vector that is loaded ONCE at view construction, rendered with the
bare view transform (no carousel cursor offset), and ticked every
frame regardless of cursor — crucially, `onShow()` is only called
on view-show, not on cursor change, so the storyboard `reset()`
cascade never fires.

The active entry **S6** carries the implementation sketch.

**Verification:** Two-shot Docker render diff —
baseline (current `extra="true"` declarations) shows 24.15% pixel
diff between a no-nav and an 8-nav scenario at the same wall clock
(RESET); spike (`staticBackground*` rename) shows 0.45% pixel diff
(CONTINUOUS, at sub-pixel sampling noise floor). Halo's
`<storyboard event="scroll">` was a separate finding from this
spike — it was dead code on this build because
`CarouselComponent` only fires the `scroll` event on its own
intrinsic logos, not on extras (`CarouselComponent.cpp:267, 652`).

**Evidence:** `SystemView.cpp:889` (mStaticBackgrounds render),
`:1045-1065` (name-prefix parse), `:852, 1534` (activateExtras →
onShow on cursor change); `GuiComponent.cpp:937-944` (onShow resets
storyboard); spike data in `/tmp/spike-u6-1/.dev/`. README's
"Known limitations" §1 needs to be revised when S6 ships.

---

### U7. ~~Per-row cursor memory across cross-axis navigation~~ — ALREADY SHIPPED

Spike-round-1 disproved the claim by reading the source. ES
already remembers cursor position across system-to-system
navigation by virtue of `ViewController` caching the gamelist
view per system (`mGameListViews[system] = view` at
`ViewController.cpp:826`; cache hit at `:673-675`). Cursor state
lives inside the cached `IGameListView` (e.g., `mCursor` in
`IList`/`TextListComponent`) and persists with the cached view.

Even on theme reload (`reloadAll`), cursors are snapshotted into
`cursorMap` and restored via `setCursor` after rebuild
(`ViewController.cpp:1149-1153, 1216-1220`).

Moved to **Deliberately omitted** (already-shipped category).
This entry is left here as a placeholder so future readers
searching for "cursor memory" find the answer.

**Verification spike** (worthwhile but not blocking): on-device,
navigate System A → game X → back → System B → game Y → back to
System A; cursor should still be on game X.

---

### U8. Inline expand-on-select for settings rows

**PSP behaviour:** Pressing ✕ on a settings row in PSP expands an
inline help panel directly below the row, pushing later rows down.
The expansion is animated and stays expanded until you select
another row.

**Why unsupportable:** ES list and carousel components are
fixed-slot — slot heights are computed once at view construction.
There's no primitive for "expand slot N from height H to height 2H
animated" that pushes neighbours. Adjacent rows can't be made aware
of one row's expanded state.

**Closest we could get:** ES's helpsystem strip already shows
context-specific button hints at the bottom of the screen. It's
*conceptually* similar (selecting a row updates the help strip), but
it's a single global element, not an inline expansion.

**Evidence:** ES `TextListComponent` and `IList` slot height
model — `mFont->getHeight()` cached at construction.

---

### U9. Idle screensaver with full PSP styling

**PSP behaviour:** After idle timeout (~3 min by default), the
screen dims to a low-energy clock-only screensaver — slow-scrolling
wave at reduced opacity, large clock centered.

**Why unsupportable in pure theme:** `screensaver` is **not** in
`sSupportedViews` (`ThemeData.cpp:31` lists `system, basic,
detailed, grid, video, gamecarousel, menu, screen, splash` — and
that's the complete list). `parseViewElement` silently skips view
names not in this set (`ThemeData.cpp:1146`). `SystemScreenSaver`
consults `Settings::getString("ScreenSaverBehavior")` directly
(values: `black`, `dim`, `slideshow`, `random video`, `suspend`)
and renders via its own component classes — no theme hookup.
Knulli's screensaver does fire a `Scripting::fireEvent
("screensaver-start", behavior)` (`SystemScreenSaver.cpp:80`) but
that's a userland scripting hook, not a theme hook.

(Adjacent finding: `splash` IS a themable view — see active entry
**S7** for static-splash deliverables. Don't confuse "no
screensaver hook" with "no startup hook"; the latter exists for
the static case.)

**Prototype:** Adding `<view name="screensaver">` with a magenta
"PSP SCREENSAVER" text element to the theme: silently dropped at
parse time, screensaver activated `dim` mode normally. View
definition never instantiated.

**Closest we could get:** Configure ES's built-in screensaver to
`dim` mode in user settings — keeps the last XMB frame visible at
~30% brightness. Per-user setting, not a theme deliverable.

**Evidence:** `ThemeData.cpp:31` (sSupportedViews, no screensaver);
`:1146` (silent skip); `SystemScreenSaver.cpp:1-100` (no theme
calls); spike at `/tmp/spike-unsupportable-U9/`.

---

### U10. Multi-level breadcrumb (cross collapses to faded vertical strip on drill-in)

**PSP behaviour:** When the user navigates from the top-level XMB
cross into a sub-category, then into a deeper sub-item, the prior
levels remain visible as a faded vertical breadcrumb on the LEFT
edge. video A @ 2:30 shows three levels at once: the briefcase
(Settings) at top-left, the Theme icon mid-left (current parent),
and the Color row selected with a `◀` and a sidebar of swatches.
Same effect at video A @ 3:30 (Settings > Display > Video Output)
and video B @ 4:30 (Settings > System > Pannello visore).

**Why unsupportable:** `ViewController::render`
(`ViewController.cpp:949-979`) renders only `mCurrentView` in
steady state (`:959-961`); during transition animations it renders
both `getSystemListView()` and visible `mGameListViews` together
(`:963-979`), but only as part of a single camera-pan. After the
animation settles it's single-view again. No theme primitive
declares "render parent view at 30% opacity to the left while
child view renders centered" persistently. ES navigation is
two-level (systems ↔ games); the PSP three-level breadcrumb
(Settings > Display > Video Output) has no analog because there's
no intermediate level in ES's model.

**Closest we could get:** Today the gamelist view pins the
selected system's icon at `crossX, crossY` (top-left), which gives
a *single-level* breadcrumb — you see "which system you're in"
while browsing its games. That's the achievable scope.

**Evidence:** Video A @ 2:00 (theme/color sidebar), 3:00 (display /
video output sidebar), 5:00 (game / PS1 folder browser);
`ViewController.cpp:949-979` (render model, steady state vs.
transition split).

---

### U11. Date next to clock in status bar (demoted from S2)

**PSP behaviour:** Top-right status carries date + time as a single
text run (`M/D HH:MM` on real PSP). Currently the theme shows time
only.

**Why unsupportable:** Three blockers, all in `ThemeData.cpp`:
1. `<text name="clock">`'s element has no `format` property in
   the parser map (`ThemeData.cpp:231-278` — only color, font,
   size, etc. are valid `<text>` children). Adding
   `<format>%-m/%-d %H:%M</format>` is rejected at parse with the
   warning `Unknown property : text.format`.
2. `ClockComponent::update` hardcodes the strftime pattern to
   `"%I:%M %p"` (12-hour) or `"%H:%M"` (24-hour) based on the
   `ClockMode12` setting (`ClockComponent.cpp:30-34`). No per-
   instance override.
3. The element type `datetime` DOES have `format` property
   support (`ThemeData.cpp:371-397` registers it), but is missing
   from `createExtraComponent` (`ThemeData.cpp:2123-2163` — the
   factory dispatching extra-component types doesn't handle
   `datetime`). A free `<datetime extra="true">` parses without
   warning but is never instantiated. It's only created for the
   pre-wired `md_releasedate` / `md_lastplayed` slots in the
   `detailed` gamelist view.

Net: no theme-XML path renders a date alongside the clock in the
screen view. Re-validate if Knulli adds a `date` global binding or
extends `createExtraComponent` to dispatch `datetime`.

**Closest we could get:** Status bar shows time only (current
behaviour). Corollary entry X3 (battery-hide layout re-tune) also
dies with this entry.

**Evidence:** `ClockComponent.cpp:30-34`; `ThemeData.cpp:231-278,
371-397, 2123-2163`; prototype log shows `Unknown property :
text.format` on the clock element.

---

### U12. Wifi signal-strength indicator (demoted from ST2)

**PSP behaviour:** PSP shows wifi as a 4-bar signal-strength
indicator. Theme today shows only ES's built-in binary
(connected/not).

**Why unsupportable:** `GlobalBinding::getProperty`
(`BindingManager.cpp:18-71`) is an exhaustive global-binding
registry. The complete list of registered keys is `help`, `clock`,
`architecture`, `cheevos`, `cheevosUser`, `netplay`,
`netplay.username`, `ip`, `network` (bool — "is IP set?"),
`battery`, `batteryLevel`, `screenWidth`, `screenHeight`,
`screenRatio`, `vertical`. **No `wifi`, no `signal`, no
`strength`, no `level` for network anywhere.** `THEMES_BINDINGS.md`
global table confirms the same list. Knulli's `knulli-wifi` CLI
(`ApiSystem.cpp:480`) exposes only enable/disable — no scan / level
interface to the theme layer.

**Closest we could get:** Binary present/absent via
`{global:network}` — which is what ES's built-in `<networkIcon>`
already shows.

**Evidence:** `BindingManager.cpp:18-71` (exhaustive registry);
`ApiSystem.cpp:480` (knulli-wifi CLI surface); spike probe
rendered `wifi:strength=[Unknown]` confirming no binding resolves.

---

### U13. Right-side value picker / menu sidebar (demoted from G9)

**PSP behaviour:** Settings rows with multiple discrete values
open a vertical sidebar on the right with the option list — Color
swatches, Video Output Mode (NTSC/PAL/DTV 480p/.../1080i),
Theme picker (Originale/Classico/Croccante/...).

**Why unsupportable for the right-side sidebar layout:**
`MenuComponent::updateSize()` (`MenuComponent.cpp:334-362`)
hardcodes the menu width to `min(screenHeight, screenWidth * 0.90f)`
and height to the row-sum capped at `0.75 * screenHeight`. No theme
hook. `OptionListPopup` (the popup that appears when you select an
option-having row) is positioned by the same hardcoded math
(`OptionListComponent.h:183-186` — horizontally centered at
`(screenWidth - menu.size.x) / 2`, vertically at
`screenHeight * 0.15`). Nothing in `<menu>` element theming
controls position, size, or orientation.

The themable surface for menus is exhaustively: `menuBackground`
(color, cornerSize, scrollbar), `menuIcons` (per-icon path),
`menuSwitch` / `menuSlider` / `menuButton` (path assets and
chrome), `menuText` (font, colors, selectorImagePath), and
`menuTextSmall` — all only chrome, never layout. See
`ThemeData.cpp:629-661` for the exhaustive themed-element list.

**Closest we could get:** The reduced-scope "more aggressively
style the menu chrome" is achievable but is a different feature
from the PSP sidebar — would be filed as a separate active entry
(G9a or similar) if pursued. Worth doing in a future round.

**Evidence:** `MenuComponent.cpp:334-362` (hardcoded layout);
`OptionListComponent.h:183-186` (hardcoded popup position);
`ThemeData.cpp:629-661` (exhaustive themed-element list); spike at
`/tmp/spike-carousel-g9/`.

---

## Deliberately omitted

These items were considered and dropped for **non-technical** reasons
— already shipped, settled design decisions, or not actually PSP
features. Listed so future audits don't re-discover them.

- **Selected-icon scale-up.** Already shipped — `logoScale=1.5` in
  both carousels (`_inc/system.xml:76`, common var
  `gameCarLogoScale`).
- **Category band behind icon row.** Re-examination of the PSP
  screenshots shows icons sit directly on the coloured background /
  wave; no horizontal band exists. Not a PSP feature.
- **Accent-tinted halo (not white).** v0.9.1 actively chose white
  over accent-tinted after on-device testing
  (`fix/v0.9.1-halo-and-statusbar` branch). Settled design decision,
  not a regression.
- **Per-firmware-version aesthetics** (PSP 1.x vs. 6.x XMB design
  shifts). Out of scope; we target the canonical mid-firmware
  (~3.x-5.x) PSP XMB design. (This is a scope choice, not a
  technical limit — pick one era and commit.)
- **Diagonal cross navigation.** PSP's cross is rigidly
  4-directional; ES carousels also are. No gap exists.
- **PSP DRM / Memory Stick / friend list / store UI.** PSP-specific
  concepts with no ES analog (and no reason to fake one).
- **Per-row cursor memory across cross-axis navigation.** Already
  shipped — ES caches gamelist views in `ViewController::mGameListViews`
  keyed by `SystemData*` (`ViewController.cpp:826`, cache hit at
  `:673-675`), and the cursor (held by `IList::mCursor` in the
  cached view) persists across system switches. Cursors are also
  snapshotted into `cursorMap` and restored on theme reload
  (`:1149-1153, :1216-1220`). The audit's prior U7 framing was
  wrong; see the U7 placeholder for cross-reference.
- **Subtler wave profile (PSP's lower-contrast curve vs. our 3-layer
  stack).** PSP firmware ran on a 480×272 display where a high-
  contrast wave would dominate; our target is 1024×768+ where the
  current wave reads as a feature, not noise. Considered dialling
  back the layer opacity to ~0.5 (from 0.85), but the on-device
  readability tradeoff at 4:3 and below favours keeping prominence.
  Settled design choice.
- **Composed sub-item icons (wrench + context glyph).** PSP renders
  each settings sub-item with a wrench-in-circle glyph layered with a
  smaller context icon (monitor for display, clock for date/time,
  speaker for audio). Our analogue surface is the ES menu, not the
  system / gamelist views. Folded into S4's scope rather than its
  own entry — if S4 ships, the helpsystem icons and any menu icons
  inherit the composed style.

---

## Process notes

- Entries are independent unless dependencies are called out — the
  audit is a wishlist, not a sequence.
- Recommended grouping (post-spike-round-1):
  - **Highest-impact / verified-ship-it cluster (target v0.10):**
    S6 (continuous wave — RESOLVED), ST1 (battery %),
    X2 (description chevrons, always-on), X1 (halo storyboard
    cleanup — was dead code, delete with S6).
  - **`<itemTemplate>` adoption cluster (target v0.10 or v0.11 — one
    coordinated XML rework unlocks G4, G7, G8, and the gamecarousel
    side of G3):** G4 (per-logo titles) + G7 (two-line selected
    row) + G8 (right-aligned value column) + G3 (boxart reflection
    via `<reflexion>` in the template).
  - **Selection-chrome cluster:** S5 (chevron via `selectorImagePath`,
    width-stretched constraint noted).
  - **Per-game polish cluster:** G2 (key-value metadata sidebar),
    G5 (per-system media fallback icons + coupled halo), G6 (hide-
    only adaptive layout).
  - **Art-heavy cluster:** S1 (silhouette icon redraw),
    S3 (drop shadow — incidental to S1), S4 (helpsystem PSP glyphs),
    G1 (launch-image splash), S7 (static boot splash via
    `splash.xml`), G10 (branded-vs-silhouette icon dichotomy).
- **Constraint to apply when screening new wishlist items:** ES
  emits only `activate`, `deactivate`, `scroll`, `open` storyboard
  events plus the unnamed default. Any new entry that relies on a
  different event (`event="boot"`, `event="select"`,
  `event="idle"`, etc.) fails immediately. Surface this in the
  preamble has been added.
- Re-run this audit after any major version ships — the
  "Deliberately omitted" list captures decisions that should stick;
  the "Unsupportable in EmulationStation" list captures dead ends
  that future spikes shouldn't re-discover; the active entries get
  pruned as they ship or are deemed not-worth-it.
- Re-run this audit after any major version ships — the
  "Deliberately omitted" list captures decisions that should stick;
  the "Unsupportable in EmulationStation" list captures dead ends
  that future spikes shouldn't re-discover; the active entries get
  pruned as they ship or are deemed not-worth-it.
