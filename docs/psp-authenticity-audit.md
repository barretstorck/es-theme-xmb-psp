# PSP XMB Authenticity Audit

A standing reference catalog of every observable PSP XMB feature that this
theme could plausibly approximate, scored against the current `v0.9.3`
implementation. Used as a wishlist / decision tool — entries here may or
may not graduate into a versioned roadmap.

**Inclusion rule:** an entry is listed only if a meaningful partial
workaround exists within EmulationStation's theme XML or asset surface.
Items that are pure "not possible in ES" (e.g. the PSP boot animation,
firmware-driven cross-fade between top-level categories) are omitted by
design — they're rationalized in the `Deliberately omitted` section at
the bottom.

**Scope:** Knulli Scarab on TrimUI Brick, 4:3 (1024×768) primary; other
aspect ratios should inherit any change unless noted.

**Companion docs:**
- [`v0.10-roadmap.md`](v0.10-roadmap.md) — current versioned roadmap.
  Entries G4, G5, G6, X1 in this audit are the audit-lens re-entries of
  roadmap items 2, 3+5, 1, and 4 respectively.
- [`superpowers/specs/`](superpowers/specs/) — per-version design specs.

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

### S2. Date next to clock

**PSP behaviour:** Top-right status reads `M/D HH:MM` — month/day,
space, time, in a single text run. Always present whenever the clock
is.

**Current theme:** Time only (`HH:MM`) via the screen-view `<text
name="clock">` element. Date is absent.

**Reference:** PSP screenshots 1 (`4/4 11:04`), 2 (`4/4 10:55`), 3
(`4/4 11:02`), 4 (`12/3 16:43`).

**Feasibility:** Ship-it.

**Workaround sketch:** Add a `<format>` child to the `clock` element
(if Knulli's ES supports `strftime`-style formats — needs a quick
research spike; falling back to a second `<datetime>` element if not).
Re-validate the clock-slot width: today the clock is sized
`0.14×0.06` at `pos=0.78,0.03` with `horizontalAlignment=right`;
adding `M/D ` will push the left edge of the rendered string left,
which is fine for `Battery: Show` but needs a width re-tune for
`Battery: Hide` (X3).

**Effort:** Trivial.

**Dependencies:** X3 (battery-hide layout math).

**Evidence:** `_inc/common.xml:151-159` (clock element);
`_inc/battery-show.xml`, `_inc/battery-hide.xml` (clock-shift math).

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
selected item without obscuring the unselected slots above/below.

**Current theme:** Selected boxart has the halo (white gaussian)
behind it; no reflection. Unselected boxart slots above/below are
dimmed via `minLogoOpacity=0.3` — they're visible but recessed.

**Reference:** PSP screenshot 2 (Daxter title bottom-left has a soft
reflection trailing the logo down).

**Feasibility:** Partial workaround — ES carousels don't have a
"reflect" attribute. A general solution needs ES code; a per-image
fake is possible.

**Workaround sketch:** Pre-render each system's boxart with a
gradient-faded mirror tile already baked in. Out of scope — we don't
control scraped media.

Better: leverage ES's vertical carousel slot below the selected
item. With `maxLogoCount=3`, the slot below the selection currently
shows the *next* game's boxart at `minLogoOpacity=0.3`. PSP-style
reflection is visually similar: a dimmed flipped version of the
selected item. But making the slot show a *flipped copy of the
selected* requires a code change to `CarouselComponent`.

Alternative: a third `<image>` element overlaid at the slot's
position, source bound to `{game:thumbnail}`, vertically flipped (if
ES supports `<flipVertical>true</flipVertical>` on `<image>` — needs
verification, ES 2.x branch has it, batocera-fork may not), with
gradient mask via PNG overlay. If `flipVertical` isn't available,
this entry collapses to "not feasible without ES code change" and
should be removed from the audit on next revision.

**Effort:** Small (if `flipVertical` exists) / N/A (if it doesn't).

**Dependencies:** none — but contingent on a feasibility spike.

**Evidence:** `CarouselComponent.cpp:394` (slot height math, already
cited in G4); ES `THEMES.md` `<image>` element attributes (search
for `flip*`).

---

### G4. Per-logo titles in gamecarousel

**Audit-lens re-entry of v0.10 roadmap item 2.** See [v0.10-roadmap.md
§2](v0.10-roadmap.md) for the deferred-item framing.

**PSP behaviour:** Every visible item in PSP's vertical sub-item list
has its label rendered alongside the icon — selected and unselected
alike. Not just a tooltip-for-selected affordance.

**Current theme:** Built-in `gamecarouselLogoText` only renders as a
*fallback* when a game has no thumbnail. Multiple visible boxart
slots show as just images; only the selected game's name might be
shown via a separate overlay (and even that is not currently themed).

**Reference:** PSP screenshots 1 + 4 — every sub-item (AVLS, Dynamic
Normalizer, Key Tone in #1; Game Sharing in #4) renders its label
visibly even when unselected (#1's items use lower-contrast text for
unselected, but they're present).

**Feasibility:** Partial workaround — ES `<itemTemplate>` may allow
per-slot custom layouts inside `<gamecarousel>`. Unverified.

**Workaround sketch:**
1. **Spike `<itemTemplate>` viability** in this ES build. Author a
   minimal template that places an image and a text label per slot.
   If component bindings (`{game:name}`) resolve per-slot inside the
   template, ship it.
2. **Fallback if itemTemplate doesn't bind per-slot:** accept the
   PSP-faithful limitation. PSP's *video* item carousel actually
   only shows the selected item's label, mirroring ES's current
   behaviour. Document this as a tradeoff and close the entry.

**Effort:** Medium (spike) + Small (implementation if viable).

**Dependencies:** none.

**Evidence:** `CarouselComponent.cpp:748-767` (text-fallback path);
`THEMES.md:1398` (`itemTemplate` section, if present).

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

## Status bar (ST)

### ST1. Battery percentage numeric next to glyph

**PSP behaviour:** When the battery is the active focus (e.g. when
unplugged or in a low-battery state), PSP shows the numeric
percentage next to the icon. In some firmware versions it shows
percentage always.

**Current theme:** Glyph only — the `<batteryIcon>` element auto-
selects between 6 image states (`empty` / `25` / `50` / `75` /
`full` / `incharge`) based on Knulli's reported charge level. No
numeric.

**Reference:** Not visible in provided PSP screenshots (those show
icon-only too) — this is a known PSP firmware feature, optional.

**Feasibility:** Needs research — depends on whether Knulli's ES
exposes a `{global:battery:level}` or similar binding for a `<text>`
element.

**Workaround sketch:** Add a `<text>` element at e.g.
`pos="0.98 0.065"` (right of the battery icon, same vertical
center), `format="{global:battery:level}%"`, fontSize matching the
clock. Visible only when battery is reported (same condition as the
icon).

Spike: grep batocera-emulationstation source for `battery` /
`getBatteryLevel` bindings; check whether an existing theme
exercises this. If no binding exists, drop this entry.

**Effort:** Small (if binding exists) / N/A (if not).

**Dependencies:** S2 (layout math: percentage takes ~30 px right of
the icon, which is currently the screen edge — clock+date+battery
all need a unified right-edge re-tune).

**Evidence:** `_inc/common.xml:180-198` (current batteryIcon block).
Binding to verify: `{global:battery:level}` /
`{global:battery:percent}` / similar.

---

### ST2. Wifi-strength bars rather than binary

**PSP behaviour:** PSP shows wifi as a 4-bar signal strength
indicator (0-3 bars), not a binary present/absent icon.

**Current theme:** Wifi indicator is ES's built-in (visible in
screenshots top-right of every shipped render). It appears binary —
icon shows when connected, hides when not.

**Reference:** PSP screenshots all show the wifi icon (single state)
top-right; the multi-bar treatment isn't visible in these particular
screenshots but is canonical PSP behaviour.

**Feasibility:** Needs research — does Knulli's ES expose a
`{global:wifi:strength}` binding? Most ES forks don't.

**Workaround sketch:** If a strength binding exists, replace ES's
built-in network indicator with a custom `<image>` element whose
path is `./art/wifi-${global:wifi:strength}.png`, plus four
4-bar-fill PNGs in `art/`. If no binding exists, drop the entry.

**Effort:** Small (if binding exists) / N/A (if not).

**Dependencies:** none.

**Evidence:** batocera-emulationstation `THEMES_BINDINGS.md` —
search `wifi` / `network`. Likely absent.

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

### X1. Halo fade on carousel scroll — verification

**Audit-lens re-entry of v0.10 roadmap item 4.** See
[v0.10-roadmap.md §4](v0.10-roadmap.md).

**PSP behaviour:** The selected-item glow doesn't persist as a
static dot during cross-axis movement. It fades out during the
transition and back in once the new selection settles. Avoids the
"glow following the icon at lag" artifact.

**Current theme:** v0.9.3 round 4 added `<storyboard event="scroll">`
to the `selectedHalo` element in `_inc/system.xml:53-58` — fades
opacity 1→0 in 120 ms on scroll, then a default storyboard fades
0→1 in 220 ms after settle. Mechanism is *theoretically* correct per
`CarouselComponent.cpp:182, 267-268, 799-803` (carousel emits a
`"scroll"` event on cursor change). Not on-device verified yet.

**Reference:** Animation, not visual — no screenshot reference.

**Feasibility:** Already-shipped pending verification.

**Workaround sketch:** Verify on-device. If the `event="scroll"`
firing reaches `extra="true"` screen-view elements (not only
carousel-internal logos), close this entry as shipped. If it doesn't
reach, the fallback is to bind halo opacity to a carousel-state
binding if such a binding exists — likely doesn't. Worst case: the
halo just sits static during scroll, which is the v0.9.2 state — not
a regression.

**Effort:** Trivial (verification only).

**Dependencies:** none.

**Evidence:** `_inc/system.xml:53-58`;
`CarouselComponent.cpp:182, 267-268, 799-803`.

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
upward chevron PNG. Visible always (cheap, slight overhang). For a
"only when overflow exists" treatment we'd need a binding
(`{game:descriptionoverflow}`) that probably doesn't exist; live
with always-visible.

Apply to both `detailed` and `gamecarousel` views — both share the
same description container.

**Effort:** Small.

**Dependencies:** none.

**Evidence:** `_inc/gamelist.xml:146-154` (description container).

---

### X3. Battery-Hide layout re-tune after S2 (date+time)

**PSP behaviour:** N/A — this is purely internal layout math
fallout from S2.

**Current theme:** `_inc/battery-hide.xml` shifts the clock right to
fill the slot left empty by a hidden battery icon. The shift is
computed for a clock width matching `HH:MM`. Adding date to the
clock (S2) makes the clock wider, so the right-shift overshoots and
the date+time runs to the screen edge or off it.

**Reference:** N/A — internal math.

**Feasibility:** Ship-it (corollary of S2).

**Workaround sketch:** Once S2 is implemented, re-measure the clock
text width via the Docker render harness and adjust the
`<pos>` x-value in `_inc/battery-hide.xml` so the right edge of the
new `M/D HH:MM` string lands at the same place as today's `HH:MM`
(rendered at x=0.94 alignment-right). Same one-time tuning as v0.9.1
did for the original battery slot.

**Effort:** Trivial (one number).

**Dependencies:** S2.

**Evidence:** `_inc/battery-hide.xml`;
`docs/superpowers/specs/2026-05-24-v0.9-xmb-authenticity-design.md`
(clock-shift derivation).

---

## Deliberately omitted

These were considered and dropped during the audit pass. Listed here
so future iterations don't re-discover them.

- **Selected-icon scale-up.** Already shipped — `logoScale=1.5` in
  both carousels (`_inc/system.xml:76`, common var `gameCarLogoScale`).
- **Category band behind icon row.** Re-examination of the PSP
  screenshots shows icons sit directly on the colored
  background / wave; no horizontal band exists. Not a PSP feature.
- **Accent-tinted halo (not white).** v0.9.1 actively chose white
  over accent-tinted after on-device testing (`fix/v0.9.1-halo-and-statusbar`
  branch). Settled design decision, not a regression.
- **PSP boot animation (wave intro / "PSP" text wipe).** ES has no
  startup-event hook for theme storyboards. Pure infeasible.
- **Per-firmware-version aesthetics** (PSP 1.x vs. 6.x XMB design
  shifts). Out of scope; we target the canonical mid-firmware
  (~3.x-5.x) PSP XMB design.
- **Music / Photos / Video category browsers.** PSP has these as
  top-level XMB categories; ES has them as separate Knulli features
  (Media Player, Image Viewer). Treating systems-as-categories is
  the working analogue; no need to fake additional categories.
- **PSP wave-color shifts during system boot warmup.** PSP fades the
  wave between two close colorset tones during boot; ES has no
  conditional storyboard targeting boot state.
- **Diagonal cross navigation.** PSP's cross is rigidly 4-directional;
  ES carousels also are. No gap.

---

## Process notes

- Entries are independent unless dependencies are called out — the
  audit is a wishlist, not a sequence.
- Author the recommended grouping for a v0.10+v0.11 split, if used:
  - **High-impact / low-effort cluster:** S2, A1, X2, X3, X1 (verify)
  - **Per-game polish cluster:** G2, G5, G6
  - **Art-heavy cluster:** S1, S3, S4, G1
  - **Spike-first cluster:** G3, G4, ST1, ST2
- Re-run this audit after any major version ships — the
  "Deliberately omitted" list captures decisions that should stick;
  the active entries get pruned as they ship or are deemed
  not-worth-it.
