# PSP XMB Authenticity Audit

A standing reference catalog of every observable PSP XMB feature that this
theme could plausibly approximate, scored against the v0.11 baseline
**including the gamelist redesign (PR #32)** — single PSP-card row
gamelist, right info panel removed, iconSize / titleVisibility /
videoDelay subsets, per-system media fallbacks wired — on top of the
earlier v0.11 work (PR #27 monochrome icons, PR #28 system halo).
Used as a wishlist / decision tool — entries here may or
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
- [`v0.10-roadmap.md`](v0.10-roadmap.md) — **historical** (v0.10 has
  shipped). Entries G4, G5, G6, X1 in this audit are the audit-lens
  re-entries of roadmap items 2, 3+5, 1, and 4 respectively.
- [`superpowers/specs/`](superpowers/specs/) — per-version design specs.
- This audit is scoped to the v0.11 baseline, so its `_inc/gamelist.xml`
  citations are historical evidence, not live paths: v0.12 split that file
  into `_inc/gamelist-{card,list,grid}.xml` (PSP Card / List + Details /
  Box Art Grid). See `superpowers/specs/2026-09-05-v0.12-gamelist-styles-design.md`.

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

## Cross-cutting constraints

Useful facts to screen wishlist items against:

- **Storyboard events ever emitted by ES:** `activate`,
  `deactivate`, `scroll`, `open`, default (unnamed). Any entry
  implying `event="boot"`, `event="select"`, `event="idle"`, etc.
  fails immediately on this constraint.
- **`extra="true"` images and `<itemTemplate>` children get
  `ThemeFlags::ALL`.** Carousel-managed intrinsic logos
  (`<image name="logo">`) get only `COLOR | ALIGNMENT | VISIBLE`.
  Wrap or use a template to unlock advanced attributes like
  `reflexion`, `flipY`, full storyboards.
- **Resolved theme bug:** older revisions used
  `<horizontalAlignment>` (a typo for `<alignment>`, per
  `TextComponent.cpp:585`), producing ~80 parse warnings per render.
  Fixed — no `<horizontalAlignment>` remains in the tree as of the
  v0.11 gamelist redesign. Use `<alignment>` in new elements.

**Entry template:**

- **PSP behaviour** — what the real PSP firmware does.
- **Current theme** — what ships at the v0.11 baseline (incl. PR #32) today.
- **Reference** — which provided PSP screenshot demonstrates it, when
  applicable.
- **Feasibility** — `Ship-it` / `Partial workaround` / `Needs research`.
- **Workaround sketch** — the approximation we'd build.
- **Effort** — `Trivial` / `Small` / `Medium` / `Large`.
- **Dependencies** — other audit items this couples to.
- **Evidence** — file / code / commit pointers.

---

## System view (S)

### S1. PSP filled-silhouette system iconography

**PSP behaviour:** Category icons in the top row are a coherent set of
single-weight line drawings — a wrench/toolbox for Settings, a filmstrip
for Video, a controller for Game, a globe for Network, etc. Each is
drawn at the same line weight, fits inside a square footprint, and is
read as a silhouette.

**Current theme:** Shipped in v0.11 (PR #27). `art/system-icons/`
now carries 198 icons: 134 shortnames adopted from the RetroArch
`monochrome` set (f170f40) plus 8 hand-authored port icons in the
same filled-silhouette style via `scripts/gen-port-icons.py`
(0afbb62), all with a pre-burned drop shadow (see S3). Roughly 56
legacy Knulli icons remain for shortnames neither mapped nor
hand-authored.

**Reference:** PSP screenshots 1 (briefcase Settings icon) and 4 (game
controller, filmstrip, globe).

**Feasibility:** Shipped in v0.11 (PR #27) via the RetroArch
`monochrome` set (CC-BY 4.0). The `automatic` line-art set was
tried first (PR #22) and rolled back per #23 — `monochrome`'s
filled silhouettes are the house style now.

**Workaround sketch (as landed):** Adopted the RetroArch
`monochrome` XMB icon set via the S1a workflow. Of the shortnames
that had no RA equivalent, 8 popular ports were hand-authored in
the filled-silhouette style (`scripts/gen-port-icons.py`, 0afbb62);
the residual gap is ~29 unmatched homebrew / ports (full list in
S1a). The 5 retro micros the old plan worried about (CoCo, Acorn
Electron, Game & Watch, NEC PC-88, TI-99) ARE present in
`monochrome`, so the earlier "do not backfill" caveat is void.
Remaining stragglers fall back to `_default.png` / Knulli's
existing icon; hand-craft per-app art only if the user wants them
themed (G10's territory).

**Effort:** Spent. Optional follow-up for the ~29 residual
stragglers if a fully unified set is desired.

**Dependencies:** S1a (mechanical adoption); G5 (fallback icons can
reuse the same `monochrome` icons at smaller sizes); G10 (the
residual homebrew/port entries overlap with G10's
branded-item-icon territory).

**Evidence:** `art/system-icons/` listing (198 files);
`_inc/system.xml:164-170` (per-system icon binding via
`${system.theme}`); `libretro/retroarch-assets` →
`xmb/monochrome/png/` (256×256 white-on-transparent filled
silhouettes); commits f170f40, 0afbb62.

---

### S1a. RetroArch `monochrome` icon-set adoption workflow

**PSP behaviour:** N/A — this entry is the *delivery vehicle* for
S1 (PSP-style filled-silhouette iconography) and partially for G10
(branded auto-collection icons).

**Current theme:** Shipped in v0.11 (PR #27). 134 RetroArch
`monochrome` icons are in `art/system-icons/`;
`scripts/ra-mapping.tsv` (191 lines) and
`scripts/import-ra-icons.sh` landed on main via d520928. Note: the
shipped TSV/script header still defaulted to `automatic` — being
fixed in this same branch.

**Reference:** None — this is an internal delivery-mechanism entry.

**Feasibility:** Shipped (v0.11). License-compatible
(CC-BY 4.0 → CC-BY-NC-SA 2.0 is one-way OK; only requirement is
CREDITS.md attribution).

**Workaround sketch (steps 1-5 done; step 6 outstanding):**

1. **Clone RetroArch assets** — DONE (one-time, into the repo as a
   gitignored sibling so updates can be pulled):
   ```bash
   git clone --depth=1 \
     https://github.com/libretro/retroarch-assets.git \
     ~/retroarch-assets
   ```

2. **Author a mapping TSV** at `scripts/ra-mapping.tsv` — DONE
   (d520928; 134 mapped shortnames). Two tab-separated columns:
   Knulli shortname, RetroArch filename-without-extension. Examples:
   ```
   snes	Nintendo - Super Nintendo Entertainment System
   nes	Nintendo - Nintendo Entertainment System
   psx	Sony - PlayStation
   psp	Sony - PlayStation Portable
   megadrive	Sega - Mega Drive - Genesis
   pcengine	NEC - PC Engine - TurboGrafx 16
   amiga	Commodore - Amiga
   amiga500	Commodore - Amiga
   amiga1200	Commodore - Amiga
   auto-favorites	favorites
   auto-lastplayed	history
   auto-allgames	database
   tools	menu_drivers
   ports	core
   imageviewer	images
   mpv	movie
   vgmplay	music
   ```
   Full mapping is ~148 rows.
   Family aliases (multiple shortnames → same RA icon) are explicit
   per row.

3. **Author a copy script** at `scripts/import-ra-icons.sh` — DONE
   (d520928; note the `automatic` default path below is what
   shipped — see Current theme):
   ```bash
   #!/usr/bin/env bash
   set -euo pipefail
   RA_DIR="${HOME}/retroarch-assets/xmb/automatic/png"
   OUT_DIR="art/system-icons"
   while IFS=$'\t' read -r short ra; do
     [[ -z "$short" || "$short" == \#* ]] && continue
     src="${RA_DIR}/${ra}.png"
     [[ -f "$src" ]] || { echo "MISS: $short -> $ra" >&2; continue; }
     cp "$src" "${OUT_DIR}/${short}.png"
   done < scripts/ra-mapping.tsv
   ```
   Idempotent. A `MISS` line surfaces mapping errors immediately.

4. **A/B-test before swap** — DONE (the A/B on-device pass is what
   rejected `automatic` (PR #22, #23) and selected `monochrome`;
   the real swap landed as f170f40).

5. **Update CREDITS.md** — DONE (c07eca2, `CREDITS.md:57-66`). The
   block originally proposed here cited the *automatic* set; the
   shipped block credits the **`monochrome`** set
   (`xmb/monochrome/png/`, CC-BY 4.0), covering the ~134 mapped
   icons, the utility/auto-collection icons, and its role as design
   reference for the 8 hand-authored port icons
   (`scripts/gen-port-icons.py`).

6. **Update README.md** "Known limitations" — OUTSTANDING — the
   "fallback placeholder" note becomes "drop-in-replaceable for any
   system the user wants to customise."

**Effort:** Spent (README step 6 remains, Trivial).

**Dependencies:** S1 (this entry is its delivery). Couples
indirectly with G5 and G10.

**Style caveats:** An earlier revision warned against backfilling
the 5 retro micros from `monochrome` because its filled-silhouette
style "clashes with `automatic`'s line-art". That caveat is now
inverted: `monochrome` IS the house style, and those 5 micros
(CoCo, Electron, G&W, PC-88, TI-99) shipped from it like every
other mapped shortname.

**Truly-unmatched homebrew / ports:** 8 of the original 37 gaps
were hand-authored in v0.11 in the filled-silhouette style via
`scripts/gen-port-icons.py` (0afbb62): `gzdoom`, `prboom`,
`eduke32`, `devilutionx`, `fallout1-ce`, `fallout2-ce`, `mrboom`,
`openjazz`. Residual gap is ~29 ports (the enumeration below keeps
a few extra names the original count tracked loosely): `abuse`,
`bennugd`, `camplynx`, `cdogs`, `cgenius`, `commanderx16`,
`corsixth`, `easyrpg`, `flash`, `fury`, `gamate`, `hcl`,
`hurrican`, `laser310`, `lcdgames`, `moonlight`, `multivision`,
`namco22`, `openbor`, `pdp1`, `pico8`, `plugnplay`, `pygame`,
`reminiscence`, `samcoupe`, `sdlpop`, `socrates`, `solarus`,
`superbroswar`, `systemsp`, `thextech`, `tyrian`, `zeldac`. These
are G10's territory if the user wants branded icons; otherwise
fall back to `_default.png`.

**Evidence:** `libretro/retroarch-assets` repo →
`xmb/monochrome/png/` (256×256 white-on-transparent filled
silhouettes) and `COPYING` (CC-BY 4.0 license); commits d520928,
f170f40, 0afbb62, c07eca2.

---

### S3. Drop shadow on selected carousel icon

**PSP behaviour:** Category and sub-item icons sit on the wave with a
subtle soft drop shadow. Not a hard outline — a low-opacity
downward-offset blurred copy that reads as depth against the moving
background.

**Current theme:** Shipped in v0.11 (PR #27). Every icon in
`art/system-icons/*.png` carries a pre-burned drop shadow —
4px-blur, 3px Y-offset, 35%-black — applied by
`scripts/apply-shadow.py` (00124cf).

**Reference:** Subtle but visible in PSP screenshots 1, 2, 4 — note
the slight darkening to the lower-right of each icon's silhouette.

**Feasibility:** Shipped — via the pre-rendered-art route (option 1
below was taken; ES has no drop-shadow attribute, so the shadow is
baked into the assets).

**Workaround sketch:** Two options were considered:
1. **Pre-burn the shadow into every icon PNG** (TAKEN). Cheap, no
   XML change. Coupled to S1 — the set was redrawn anyway, so the
   shadow became part of the asset. **Open verification item:** the
   shadow may look wrong against very-dark colorsets (October
   Crimson, November Slate) — not yet checked on-device.
2. **Stacked element approach** (rejected). A second `<image
   name="logoShadow">` per icon, offset by a few pixels and dimmed.
   ES carousel doesn't natively support per-logo additional layers,
   so it would only have worked for the *selected* slot via a
   screen-view extra. Not worth the XML complexity.

**Effort:** Done (rode along with S1). ⚠️ `scripts/apply-shadow.py`
is NOT idempotent — re-running it compounds shadows on
already-shadowed PNGs. Only run it on freshly imported/authored
shadowless icons.

**Dependencies:** S1.

**Evidence:** `scripts/apply-shadow.py`; commit 00124cf
(pre-burned shadow across `art/system-icons/`).

---

### S4. Helpsystem button icons in PSP shapes

**Status: SHIPPED for v1.0 (issue #8), gated behind a subset — and
delivered wider than this entry originally scoped.**

**PSP behaviour:** Button affordances along the bottom of menus
use the PSP face-button glyphs: ✕ (cross / confirm), ○ (circle /
back), □ (square), △ (triangle). They're rendered at small size with
short labels next to them ("✕ Enter  ○ Back").

**What shipped:** all twelve of ES's themeable helpsystem icons, drawn
by `scripts/gen-help-icons.py` into `art/help/`, with the four face
slots selectable between **three** glyph sets via the `buttonGlyphs`
subset ("Button Icons"): **Nintendo (default)**, **PSP**, **Xbox**.

The scope change is deliberate and is the substance of the decision on
#8. Hardcoding Sony's shapes, as this entry proposed, is maximally
authentic and actively misleading on the TrimUI Brick, whose buttons
are silkscreened A/B/X/Y — "✕ Enter" tells that user nothing about
which button to press. Nintendo is therefore the default and PSP is one
menu away. The three sets cost only eight face PNGs, because Nintendo
and Xbox draw the *same* four lettered buttons and differ purely in
which position each letter occupies.

**Two corrections to what this entry originally said.**

1. *The workaround sketch below had the mapping backwards.* ES's face
   slots are pinned to physical positions — `iconA`=east, `iconB`=south,
   `iconX`=north, `iconY`=west — so Cross belongs on `iconB`, not
   `iconA`. Binding it as sketched puts Cross on the east button and
   Circle on the south one. Nothing errors. See §5.4 of the style guide
   for the derivation from `_sdlToEsMapping`, the Brick's
   `es_input.cfg` evdev codes, and `buttonDisplayName`.
2. *"Verify against batocera's `THEMES.md`" is the wrong instruction* —
   that file has been wrong about this codebase before. The names were
   taken from the pinned build's own property map
   (`ThemeData.cpp:493-514`) and confirmed by rendering probe glyphs.
   That map has twelve icon properties and **no `iconLR`**, so ES's
   `"lr"` prompt is not themeable and keeps its stock glyph.

**Feasibility:** Ship-it (delivered).

**Dependencies:** S1 (visual consistency) — met; the glyphs are
monochrome line art in the shipped icon language. Xbox's colour coding
is deliberately not reproduced: ES tints help icons with a multiply
(`ImageComponent::setColorShift`), which cannot preserve four hues.

**Evidence:** `_inc/common.xml` and `_inc/gamelist-grid.xml`
(helpsystem blocks); `_inc/buttons-{nintendo,psp,xbox}.xml`;
`scripts/gen-help-icons.py`; `scripts/tests/test-button-glyphs.sh`;
`docs/psp-xmb-style-guidelines.md` §5.4.

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
selection; the v0.11 card-list gamelist marks selection by expanding
the selected row into the dominant card (the peek icon fades out and
the big boxart + title take over). Neither shows a chevron.

**Reference:** video A @ 2:30 (Theme/Color selected with `◀` left of
the wrench icon); video A @ 3:30 (Display/Video Output Mode); video
B @ 4:30 (Pannello visore); video B @ 5:30 (Cambia uscita video);
video B @ 7:00 (Ora legale).

**Feasibility:** Ship-it.

**Workaround sketch (updated for the v0.11 card list):** Add a small
`extra="true"` `<image>` pinned left of the selected card's boxart —
e.g. at `(crossX - cardBoxartW/2 - gap, cardY)` — source
`art/ui/chevron-left.png`. Because the card is a fixed-anchor extra
(always at `cardY`), the chevron needs no per-row logic. Optional
100ms fade storyboard for parity with the peek-fade cadence.

For the system carousel, the chevron doesn't fit as cleanly — PSP's
top-level XMB cross doesn't show the chevron either (it appears
only on vertical sub-item rows). Skip it for the horizontal
carousel. The peek textlist's `<selectorImagePath>` slot is another
possible host (currently set empty), with the width-stretch
constraint below.

**Effort:** Small (XML + one PNG glyph).

**Dependencies:** S1 (chevron art-style consistency).

**Implementation notes:** `<textlist>` accepts `<selectorImagePath>`
(note: spelled-out, not `<selectorImage>`) plus
`<selectorImageTile>`, `<selectorHeight>`, `<selectorOffsetY>`
(`TextListComponent.h:778-789`, `THEMES.md:1027-1035`).
**Constraint:** the selector image's width is forced to the full
textlist width (`setSize(mSize.x(), mSelectorHeight)`). To get a
"chevron-next-to-the-row" look, author the PNG with the chevron at
the LEFT edge of a wide transparent canvas — the image stretches
horizontally otherwise. `selectorColor` tints the image (recolor
single white chevron per colorset).

The `extra="true"` chevron pinned at `crossX`-offset / `cardY` (the
primary sketch above) avoids the selector-image width-stretch
constraint entirely and matches how the v0.11 card itself is
anchored.

**Evidence:** `TextListComponent.h:778-789`; `THEMES.md:1027-1035`.

---

### S6. Continuous wave animation across system carousel navigation

**PSP behaviour:** XMB wave animates continuously, completely
independent of menu navigation. Wave on its own timeline; icon
carousel on a separate one.

**Current theme:** Shipped in v0.10. `_inc/system.xml:16-73`
declares `staticBackgroundWave` plus
`staticBackgroundLayer{1,2,3}`, so the wave ticks on its own
timeline and no longer restarts on system change. (The v0.9.3
failure mode, for the record: wave layers were `extra="true"`
images whose storyboards restarted at `t=0` on every system change
because the per-system `backgroundExtras` lifecycle calls
`extra->onShow()` → `mStoryboardAnimator->reset()` on cursor
change — `SystemView.cpp:852, 1534`; `GuiComponent.cpp:942`.
Documented since v0.3 in the README as a known limitation.)

**Reference:** PSP / video A / video B / video C all show the wave
animating without ever restarting during navigation.

**Feasibility:** Shipped (v0.10).

**Workaround sketch (as landed):** Uses the undocumented `staticBackground*`
name-prefix mechanism (`SystemView::getViewElements`,
`SystemView.cpp:1045-1065`). Elements whose `name` starts with the
literal string `"staticBackground"` are stored in a single
`mStaticBackgrounds` vector loaded ONCE at view construction (not
per-system). Their `update()` ticks every frame; their `onShow()`
is only invoked on view-show, **not** on cursor change. The
storyboard `reset()` cascade never fires.

Renames landed in `_inc/system.xml`:
- `waveBackground` → `staticBackgroundWave` (dropped `extra="true"`)
- (the three motion wave layers, brought inline from
  `_inc/wave-motion.xml`) → `staticBackgroundLayer{1,2,3}`
- `selectedHalo` → `staticBackgroundHalo` (dropped `extra="true"`,
  dropped both `<storyboard>` blocks — see X1 update below). The
  sketch originally called for `<zIndex>` 10; the actual landed
  value is **4** (b8649c8 corrected 10 → 4, re-confirmed in the
  v0.11 restoration 3d4a602) — above all wave layers, below the
  carousel.

In `_inc/wave-motion.xml`, `<view name="system,detailed,gamecarousel">`
became `<view name="detailed,gamecarousel">` — gamelist views are
unaffected by the cursor-reset issue and keep their existing
declarations.

**Effort:** Spent.

**Dependencies:** none. The halo's old
`<storyboard event="scroll">` blocks were deleted along with the
rename — they were dead code on this build
(`CarouselComponent.cpp:267, 652` shows the `scroll` event fires
only on the carousel's intrinsic logos, never on extras).

**Evidence:** `SystemView.cpp:889` (mStaticBackgrounds render),
`:1045-1065` (name-prefix parse), `:852, 1534` (activateExtras →
onShow on cursor change); `GuiComponent.cpp:937-944` (onShow resets
storyboard).

---

### S7. Static themed boot splash (single frame)

**PSP behaviour:** ~3 seconds of branded boot animation between
power-on and the main XMB. Animation is U1's territory (still
unsupportable). But the *static* component — a PSP-branded image
on a coloured background — IS achievable as a single frame held
for the duration of ES's boot.

**Current theme:** SHIPPED in v1.0. `splash.xml` at the theme root
declares the `splash` view: the system view's wave as `background`
tinted `${waveTint}`, its three crest layers as extras tinted
`${accent}`, and an original wordmark lockup
(`art/ui/splash-wordmark.png`, generated by
`scripts/gen-splash-wordmark.py`). Knulli's own bootloader splash
still covers the kernel boot; this covers ES's, which is the longer
half.

Three findings from building it, none of which the sketch below
anticipated:

1. **The splash tracks the user's colorset.** The open question was
   whether it could, since the splash loads before any view does.
   It can: `mColorset` is read from the global `ThemeColorSet`
   setting in the ThemeData constructor (`ThemeData.cpp:684`), and
   `splash.xml` is parsed at `formatVersion` 7, where `parseTheme`
   handles `<include>` and `<subset>` in document order. Because the
   file is parsed STANDALONE on a throwaway ThemeData
   (`Splash.cpp:40`), it inherits nothing from `theme.xml` and has
   to re-declare the colorset subset itself — but once it does, the
   chosen colorset reaches it. No fixed palette needed.

2. **`<image name="background">` is mandatory, not decorative.**
   Without it `Splash` leaves `imagePath` at `DEFAULT_SPLASH_IMAGE`
   (`":/logo.png"`, `Splash.h:15`) and draws EmulationStation's own
   logo at `setMinSize(screen)`. The failure mode of a broken
   `splash.xml` is not a missing splash; it is ES's logo, full
   screen. Worse, `loadFile` is called inside
   `try { } catch(...) { }` (`Splash.cpp:38-42`), so a malformed
   file produces no error and no log line at all. This is what
   `scripts/tests/test-splash.sh` guards.

3. **Two bands of the screen belong to ES.** The label sits at
   `y = 0.78 * H` (`Splash.cpp:102`) and, since `SplashScreenProgress`
   also defaults true (`Settings.cpp:130`), a progress bar at
   `y = 0.892 * H` (`Splash.cpp:143-147`). Both are themeable, but
   moving the bar means re-positioning `progressbar` AND
   `progressbar:active` together — `Splash::render` sizes the fill
   from the track's width while drawing each at its own position, so
   theming one alone detaches the fill from its track. The theme
   sets colour only and leaves the geometry to ES.

The mark is the theme's own, not Sony's: shipping a "PSP" wordmark
from a public CC-licensed repo was rejected on the same reasoning
that substituted OFL Roboto Condensed for Fontworks New Rodin (see
`CREDITS.md`). It is an image rather than a `<text>` element because
the design is letterspaced and ES has no letterspacing property
anywhere in es-core — and, as it turns out, because `<maxSize>` on
an image fits one asset to all five shipped ratios, where a `<text>`
element's height-derived `fontSize` renders this string at 100% of
screen width at 1:1.

**Reference:** PSP boot — generic firmware behaviour, not in the
captured reference videos.

**Feasibility:** SHIPPED (static only — animation remains U1).

**Workaround sketch (as written before implementation; superseded by
"Current theme" above, which corrects the wordmark scope and answers
the colorset question):** Author `splash.xml` at the theme root.
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
Added while implementing: `ThemeData.cpp:684` (`mColorset` from the
global `ThemeColorSet`); `Splash.h:15` + `Splash.cpp:50-53` (the
`:/logo.png` fallback); `Splash.cpp:38-42` (the silent catch);
`Settings.cpp:128,130` (`SplashScreen` and `SplashScreenProgress`
both default true); `Splash.cpp:102,143-147` (ES's two reserved
bands). Confirmed on the device side too: Knulli's
`/usr/bin/emulationstation-standalone` launches ES with no
splash-suppressing flag, and neither Brick overrides `SplashScreen`.

---

## Gamelist (G)

### G1. Game-select promo overlay (Daxter-style splash)

**PSP behaviour:** When the user selects a game on the XMB and
presses ✕, the system shows a short branded splash (publisher logo +
key art + tagline) before the game launches. The Daxter screen is the
canonical example — Ready At Dawn logo bottom-left, key art covering
most of the screen, large game logo.

**Current theme:** Nothing custom — pressing ✕ on a selected card in
the v0.11 card-list gamelist launches via Knulli's default launch
sequence (which on TrimUI Brick is a brief black "launching…"
screen). The gamelist redesign did not touch launch behaviour; this
entry is unaffected by PR #32 and **still open**.

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

**Status: SUPERSEDED by the v0.11 gamelist redesign (PR #32,
issue #12), partially delivered.** The right info panel this entry
wanted to extend no longer exists, so a "sidebar" of key-value rows
is moot. What the redesign actually ships is a single metadata line
on the expanded card: `{game:genre} · {game:stars}` (`cardMetadata`,
`_inc/gamelist.xml:202-213`) — genre plus Unicode star glyphs. No
labelled key-value block; no year / players / region rows.

**PSP behaviour:** When a media item is selected (photo, music,
video, game), metadata is rendered as labelled key-value pairs next
to the thumbnail: filename, date, time, format/region. Short white
labels left, values right, one pair per line. Compact.

**Current theme:** The selected card renders title above the
horizontal rule and `{game:genre} · {game:stars}` below it (with
the marquee description to the right). `{game:lastplayed}` was
deliberately omitted (epoch leak on this build). Empty genre is not
guarded — a genre-less game renders a bare `· ★★★` line.

**Reference:** PSP screenshot 3 (PIC_0000 / `12/3/2021 18:39` / BMP
tag — exact key-value rendering).

**Feasibility:** The residual idea — labelled `Year` / `Players`
rows — would now have to live on the card, not in a panel. Possible
(same `{game:*}` text bindings), but competes with the card's
deliberately sparse PSP look; treat as a new proposal, not this
entry.

**Effort:** Spent (as redesigned).

**Dependencies:** none remaining (the old G6 coupling dissolved with
the panel).

**Evidence:** `_inc/gamelist.xml:202-213` (`cardMetadata`);
`THEMES_BINDINGS.md` `{game:*}` bindings list; PR #32.

---

### G3. Box-art reflection beneath selected boxart

**Status: SUPERSEDED by the v0.11 gamelist redesign (PR #32,
issue #13) — NOT shipped.** The gamecarousel this entry targeted is
gone, and the shipped card list contains **no** `<reflexion>` on any
element (verified: zero occurrences in `_inc/gamelist.xml` or
anywhere in `_inc/`). If a reflection is still wanted, it is a new
one-line proposal against `cardBoxart` (see sketch below), not a
pending item of the old design.

**PSP behaviour:** Selected media (boxart, photo, video thumbnail)
has a soft mirrored reflection directly beneath it, fading to
transparent. Adds a "floating on glass" feel to the centered
selected item.

**Current theme:** The selected card's boxart (`cardBoxart`, an
`extra="true"` image at `(crossX, cardY)`) renders with no
reflection. Note the card's horizontal rule bisects the boxart at
its vertical midpoint — a reflection extending below the boxart
would land in the metadata/description band, which is likely why
the redesign omitted it.

**Reference:** PSP screenshot 2 (Daxter title bottom-left has a soft
reflection trailing the logo down).

**Feasibility (if revived):** Ship-it mechanically. `cardBoxart` is
already `extra="true"`, so it gets `ThemeFlags::ALL` and honors
`<reflexion>0.7 0.0</reflexion>` (first=top alpha, second=bottom
alpha) as a one-line addition. The design conflict with the
metadata band below the rule is the real question.

**Effort:** Trivial (XML) + design decision.

**Dependencies:** none (the old G4-itemTemplate coupling dissolved).

**Evidence:** `ImageComponent.cpp:820-825` (`reflexion`
`NORMALIZED_PAIR`); `ThemeData.cpp:2205` (extras get
`ThemeFlags::ALL`); `THEMES.md:820-825`; grep of `_inc/` confirming
no `reflexion` usage post-PR #32.

---

### G4. Per-row titles in the game list

**Status: SHIPPED in the v0.11 gamelist redesign (PR #32,
issue #14), gated behind a subset.** The card list's peek rows carry
a per-row title element (`tplPeekTitle`, bound to `{game:name}`,
`_inc/gamelist.xml:329-346`) rendered beside every row's icon via
the textlist `<itemTemplate>`. Its opacity is
`${titleUnselectedOpacity}`: **1** under Title Visibility = "With
Titles" (Friendly) — every visible row shows icon + title, the PSP
behaviour this entry asked for — and **0** under the default
"PSP-Faithful" (Strict), which deliberately shows icon-only rows.
The selected game's title always shows on the expanded card
regardless of the subset.

**Audit-lens re-entry of v0.10 roadmap item 2.** See [v0.10-roadmap.md
§2](v0.10-roadmap.md) for the historical deferred-item framing (the
roadmap's gamecarousel-itemTemplate route was superseded; the
mechanism that shipped is the *textlist* itemTemplate).

**PSP behaviour:** Every visible item in PSP's vertical sub-item list
has its label rendered alongside the icon — selected and unselected
alike.

**Current theme:** As above. Unselected peek titles render dim
(`${textSecondary}`, `peekTitleFontSize` 0.030/0.026) and fade out
on the selected row (`event="activate"` storyboard) so they don't
double up with the card title.

**Reference:** PSP screenshots 1 + 4; video B @ 0:30; video C @ 0:00.

**Feasibility:** Shipped.

**Effort:** Spent.

**Dependencies:** none remaining.

**Evidence:** `_inc/gamelist.xml:329-346` (`tplPeekTitle` +
activate/deactivate storyboards);
`_inc/title-visibility-{strict,friendly}.xml`
(`titleUnselectedOpacity` 0/1); `theme.xml:140-143` (subset
declaration); `TextListComponent.h:274-340` (per-row binding
resolution).

---

### G5. Selected-game halo + per-system fallback icons (coupled)

**Status (v0.11 redesign, PR #32 / issue #15): SPLIT.**
- **Media fallbacks: SHIPPED and wired.** `theme.xml:39-114`
  conditionally includes one of 75 per-system files in
  `_inc/media-fallback/` (matching `${system.theme}`;
  `_default.xml` loads first as the catch-all — nested variable
  indirection was spiked and failed on this build), each setting
  `${mediaFallbackPath}` to one of the 7 silhouettes in
  `art/system-media/`. Games without a scraped thumbnail render it
  via `cardFallback` (expanded card) and `tplPeekFallback` (peek
  rows), both guarded by
  `<visible>!exists({game:thumbnail})</visible>`.
- **Gamelist halo: NOT shipped — superseded.** The shipped
  `_inc/gamelist.xml` contains **no halo element** (no `tplHalo`,
  no `selectedGameHalo`; the peek textlist's selector is fully
  transparent). The redesign's selection signal is the expanded
  card itself — the selected row's peek icon fades out and the
  ~2.7×-larger card boxart + oversized title take over — which
  makes a glow redundant. Leftover: `rowHaloW` / `rowHaloH` in
  `_inc/common.xml:85-86` still reference a `tplHalo` consumer
  that does not exist (cleanup candidate). The style guidelines §10
  record "no gamelist halo" as settled.

**Audit-lens re-entry of v0.10 roadmap items 3 + 5.** See
[v0.10-roadmap.md §3 and §5](v0.10-roadmap.md) (historical — v0.10
shipped). The original coupling — fallback icons must replace the
white-text fallback before a white halo is readable — was satisfied
by the fallback half, but the redesign then removed the halo's
*motivation* rather than adding the halo.

**PSP behaviour:** Selected sub-items get a soft glow behind them,
regardless of whether the slot is showing a thumbnail or a generic
icon. The glow is consistent.

**Current theme:** The system carousel's soft white halo
(`staticBackgroundHalo`, restored + re-tuned in PR #28 to
`haloW=0.28` / `opacity=0.6`) is **currently disabled** — commented
out in PR #32's round-4 on-device tuning as still too bright;
re-enable tracked in issue #34. The gamelist has none, per the
settled decision above.

**Reference:** PSP screenshots 1 and 3 — the selected `AVLS` row and
the selected `PIC_0000` photo each have a subtle highlight bar /
glow behind them.

**Feasibility:** Fallback half shipped; halo half superseded (would
now be a deliberate design re-litigation, not an outstanding task).

**Effort:** Spent (fallbacks); n/a (halo).

**Dependencies:** S1 (icon design language — satisfied).

**Evidence:** `theme.xml:39-114` (per-system includes);
`_inc/media-fallback/` (75 files + `_default.xml`);
`art/system-media/` (7 glyphs, b616057);
`_inc/gamelist.xml:145-152, 310-324` (`cardFallback`,
`tplPeekFallback`); absence of any halo element in
`_inc/gamelist.xml` (verified by grep); 3d4a602 + 3396428
(system-halo restoration + tuning).

---

### G6. Adaptive layout on metadata absence

**Status: LARGELY SUPERSEDED by the v0.11 gamelist redesign (PR #32,
issue #16); the hide-only pattern shipped where it still applies.**
The "dead reserved zones" that motivated this entry were properties
of the removed info panel (empty description band, empty video box).
The card list has no reserved panel regions, and the elements that
can be empty carry `exists()` guards:
- `cardVideo` — `<visible>exists({game:video})</visible>` (no empty
  video box; the boxart simply stays).
- `cardFallback` / `tplPeekFallback` —
  `<visible>!exists({game:thumbnail})</visible>` (silhouette swaps
  in for the missing thumbnail).

Not guarded: `cardMetadata` and `cardDesc` render unconditionally —
a game with no genre shows a bare `· ★★★` line, and an empty
description just renders nothing visible. Cosmetic residual, not a
reserved-zone problem.

**Audit-lens re-entry of v0.10 roadmap item 1.** See
[v0.10-roadmap.md §1](v0.10-roadmap.md) for the historical analysis.

**PSP behaviour:** Empty metadata fields don't leave blank space.
Items adapt — if a photo has no caption, the metadata block shrinks;
if there's no preview, the thumbnail expands. No "dead reserved
zone" visible.

**Current theme:** As above — hide-only guards on video and
thumbnail-fallback; true PSP-style REFLOW remains unsupportable
(`<pos>` / `<size>` are parse-time floats, see U2).

**Reference:** PSP screenshots 1 (settings rows have no images;
text expands) and 3 (photo browser shows compact metadata block).

**Feasibility:** Delivered to the extent ES allows (hide-only);
reflow is U2's dead end.

**Effort:** Spent. Optional follow-up: `exists({game:genre})` guard
on `cardMetadata` to suppress the bare-dot case.

**Dependencies:** none remaining.

**Evidence:** `_inc/gamelist.xml:150, 172, 315` (the three
`exists()` guards); U2 (reflow unsupportable);
`THEMES_BINDINGS.md:264-302`.

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
G2 covered) — it's the row itself expanding when selected.

**Current theme:** Delivered by the redesign (see Status above): the
selected row visually expands into title-above-the-rule +
metadata/description-below-the-rule; unselected rows stay one line
(icon, or icon + dim title).

**Reference:** video A @ 1:30 ("Ajustes de Sistema / Ajusta la
configuración…"); video B @ 4:30 ("Pannello visore / ma PSP™
risponde alla chiusura del pannello visore"); video B @ 5:30
("Cambia uscita video / ta la visualizzazione dell'uscita video
sullo schermo"); user screenshot 1 (AVLS row).

**Feasibility:** Ship-it. The mechanism is `<itemTemplate>` plus
`event="activate"` / `event="deactivate"` storyboards on the
template's description text element.

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
parsing).

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

### G10. Branded item icons (colour, not monochrome)

**PSP behaviour:** Top-level category icons (Music, Video, Game,
Settings, Network) are flat monochrome white silhouettes. But
*items inside those categories* that represent third-party apps,
storefronts, or services — PlayStation Network, PS Store, Skype,
Information Board, Internet Search — use **full-colour 3D-rendered
icons**, each with its own brand identity. The visual hierarchy is
"category = silhouette, item = brand."

**Current theme:** All system icons in `art/system-icons/` are
white silhouettes — now predominantly from the RetroArch
`monochrome` set (v0.11, PR #27), with legacy Knulli icons only
for unmapped stragglers. The auto-collections (`auto-favorites`,
`auto-lastplayed`, `auto-allgames`) on main also come from
`monochrome`, in the same style as the system icons. There's no
"branded item" (full-colour) treatment for special entries.

**Reference:** video C @ 0:00 (Network category sub-item: blue/
purple PSN swirl icon next to monochrome Network globe — clear
two-tier hierarchy visible in the same frame); video C @ 3:00
(PSN landing showing PlayStation Network swirl, blue shopping-bag
PS Store icon, orange Information Board icon — all full colour);
video B @ 0:30 (Skype `S` logo in blue circle next to monochrome
Game/Network icons).

**Feasibility:** Ship-it — purely an art / asset decision.

**Workaround sketch:** Identify which ES "system" entries should
get branded treatment versus silhouette treatment.

**Partial source: RetroArch `monochrome` set** (CC-BY 4.0, see
S1a). The RA set ALREADY ships dedicated icons for the system-tier
auto-collections we'd want branded. Note the original two-tier
contrast argument no longer holds: with `monochrome` (not
`automatic`) as the source, hardware icons and auto-collection
icons are BOTH filled silhouettes — the outline-vs-filled hierarchy
this entry hoped for doesn't exist on main. Any true PSP-style
"brand" tier would need colour art on top:
- `auto-favorites.png` ← RA `favorites.png` (filled outline heart)
- `auto-lastplayed.png` ← RA `history.png` (clock + reverse arrow)
- `auto-allgames.png` ← RA `database.png` (stacked discs)
- `tools.png` / `vaixterm.png` ← RA `menu_drivers.png`
- `emulators.png` / `ports.png` ← RA `core.png`
- `imageviewer.png` ← RA `images.png`
- `mpv.png` / `recordings.png` ← RA `movie.png`
- `vgmplay.png` ← RA `music.png`
- `library.png` ← RA `database.png`
- `odcommander.png` ← RA `file.png`

These are in S1a's mapping TSV and shipped with it (d520928 /
f170f40). They are consistent with the hardware icons, but — per
the note above — not visually *distinct* from them the way the
old `automatic` plan promised.

**Homebrew / port games (the unmatched from S1a):** Not provided
by RA; only hand-crafted per-app art applies. The v0.11 art pass
happened: 8 ports were hand-authored in the filled-silhouette
style (`gzdoom`, `prboom`, `eduke32`, `devilutionx`,
`fallout1-ce`, `fallout2-ce`, `mrboom`, `openjazz` —
`scripts/gen-port-icons.py`, 0afbb62). Those are silhouettes, not
branded colour icons; the remaining ~29 (`pico8`, `openbor`,
`solarus`, `tyrian`, …) and any true branded treatment stay open.

**Effort:** Small (auto-collections rode along with S1a — done);
Medium-Large if hand-crafting branded per-app art for the
remaining unmatched.

**Dependencies:** S1a (the auto-collection mappings ride in the
same TSV); S1 (overall icon-style direction).

**Evidence:** `libretro/retroarch-assets` → `xmb/monochrome/png/`
contains `favorites.png`, `history.png`, `database.png`,
`core.png`, `menu_drivers.png`, `images.png`, `movie.png`,
`music.png`, `file.png` — all present, all in the same
filled-silhouette style as the hardware-system icons.

---

## Status bar (ST)

### ST1. Battery percentage numeric next to glyph

**PSP behaviour:** When the battery is the active focus (e.g. when
unplugged or in a low-battery state), PSP shows the numeric
percentage next to the icon.

**Current theme:** No battery widget at all — the entire widget
(glyph included) was pulled in v0.10 (8292b54). The assets survive
(`art/battery/*`, `scripts/gen-battery-icons.py`); restoring the
glyph is tracked as issue #4. This entry now DEPENDS on #4 landing
the glyph first — there is currently nothing to put a numeric
"next to".

**Reference:** Not visible in the captured reference videos — this
is a known PSP firmware feature, optional.

**Feasibility:** Ship-it once issue #4 restores the battery glyph.
Two supported paths, both still valid.

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

**Effort:** Trivial (after #4).

**Dependencies:** issue #4 (battery-glyph restoration).

**Evidence:** 8292b54 (widget removal); `BatteryTextComponent.{h,cpp}`; `ThemeData.cpp:34`
(auto-extra registration), `:2147-2148` (createExtraComponent
dispatch); `BindingManager.cpp:52-53` (battery binding
registration).

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

### X2. Description scroll affordance (▼ / ▲)

**PSP behaviour:** When a text block exceeds its container, PSP
shows a small triangle at the cut edge indicating "more text below"
(or above). Subtle but consistent across all PSP UI.

**Current theme:** The description text element has
`<container>true</container>` in `_inc/gamelist.xml:152`, which
enables ES's built-in scroll behaviour. The text *does* scroll on
selection, but there's no visual cue that text is being cut at the
container edge. This entry WAS implemented (4f003bc) and then
deliberately reverted after on-device review (4fbc7ca): the
chevrons were "too small to read at typical viewing distance", and
the decision is to deviate from PSP style on this element. The
assets survive orphaned (`art/ui/chevron-{up,down}.png`,
`scripts/gen-chevrons.py`).

**Reference:** Subtle in screenshot 1 — the description text wraps
mid-word at the right edge, suggesting more text exists; PSP's
firmware would normally show a triangle.

**Feasibility:** **Design-rejected on-device** (this note is the
follow-up audit update promised in 4fbc7ca). Technically it works
exactly as sketched below; it was rejected on legibility, not
feasibility. Any re-attempt must use substantially larger chevrons
than the ~12×8 px sketch. Not to be confused with branch
`feat/v0.11-chevron`, which is S5's selected-row pointer
(issue #9) — unrelated to this entry.

**Workaround sketch (as built, then reverted):** Two static `<image>` elements pinned at
container top + bottom edges, sized ~12×8 px, with a downward /
upward chevron PNG. Always visible — there is no
`descriptionoverflow` / scroll-state binding:
`FileData::getProperty`'s static map (`FileData.cpp:40-61`) has
no description-state entry, and `ScrollableContainer` exposes no
`applyTheme` integration nor any binding hook for `mScrollPos` /
`mAtEnd`. Slight visual overhang on short descriptions is the
accepted tradeoff.

Apply to both `detailed` and `gamecarousel` views — both share the
same description container.

**Effort:** Small.

**Dependencies:** none.

**Evidence:** `_inc/gamelist.xml:146-154` (description container);
4f003bc (implementation), 4fbc7ca (design revert).

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
animate color." That's incorrect — color animations DO
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
calls).

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

### U11. Date next to clock in status bar

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
behaviour).

**Evidence:** `ClockComponent.cpp:30-34`; `ThemeData.cpp:231-278,
371-397, 2123-2163`; prototype log shows `Unknown property :
text.format` on the clock element.

---

### U12. Wifi signal-strength indicator

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

### U13. Right-side value picker / menu sidebar

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
`ThemeData.cpp:629-661` (exhaustive themed-element list).

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
  (`:1149-1153, :1216-1220`).
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
- Recommended grouping:
  - **Highest-impact / verified-ship-it cluster (was: target
    v0.10):** S6 (continuous wave) + X1 (halo storyboard cleanup)
    SHIPPED in v0.10; X2 (description chevrons) shipped then
    design-rejected on-device (4fbc7ca); ST1 (battery %) now
    blocked on issue #4 restoring the battery glyph.
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
  - **Art-heavy cluster:** S1 + S1a + S3 SHIPPED in v0.11 via the
    RA `monochrome` set (G10's auto-collection icons rode along
    with S1a's TSV, though as silhouettes, not a branded tier).
    Remaining: S4 (helpsystem PSP glyphs — not in RA set, still
    hand-draw), G1 (launch-image splash), S7 (static boot splash
    via `splash.xml`).
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
