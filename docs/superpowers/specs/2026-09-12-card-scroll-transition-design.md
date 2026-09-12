# PSP Card gamelist — scroll transition for the selected box art

Date: 2026-09-12
Issue: none (see "Tracking" below)
Style affected: A — PSP Card (`_inc/gamelist-card.xml`) only

## Problem

Scrolling between games in the PSP Card style is a hard cut. The selected
game's box art is already larger than its neighbours, but nothing conveys
the *movement* from one game to the next: the big card simply swaps its
pixels in place while the peek icons snap to their new slots.

Measured on 2026-09-12 against `main` (`0521297`): a cursor move is a
**single-frame** step change — mean absolute difference 14.5 and 18.6 out of
255 across the card column, with the surrounding frames at ~0.05 noise.
There are no intermediate states at all.

The system carousel, by contrast, animates its scroll (that motion is
internal to `CarouselComponent`, not themed). The gamelist should read the
same way: the outgoing box art should scale down and shift toward the peek
slot it is being demoted into, while the incoming art grows into the card
position.

## Measured facts this design rests on

Everything below was measured in the harness on 2026-09-12 via a throwaway
spike, not inferred from the ES source. The spike used deliberately
exaggerated values (1500 ms, linear, no opacity animation) so that a 10 fps
capture would land many intermediate frames.

### 1. ES supports direction-aware gamelist transitions natively

`DetailedGameListView::updateInfoPanel` passes
`moveBy = mList.getCursorIndex() - mList.getLastCursor()` into
`DetailedContainer::updateControls` (`DetailedGameListView.cpp:46`).
`handleStoryBoard` (`DetailedContainer.cpp:1106-1160`) then selects, in
order of preference:

| `moveBy` | event chosen |
|---|---|
| `> 0` | `activateNext` / `deactivateNext` |
| `< 0` | `activatePrev` / `deactivatePrev` |
| `!= 0`, no direction variant declared | `activate` / `deactivate` |
| `== 0` | `open`, then the unnamed default |

**Verified on pixels:** the spike declared *only* the four direction
variants. A Down press produced correctly-signed motion, and an Up press
produced the mirrored motion. Both branches are reached.

### 2. ES double-buffers the container so the outgoing art stays on screen

When any component in the container has an activation storyboard,
`DetailedContainerHost::updateControls` (`DetailedContainer.cpp:1358-1395`)
pushes the current `DetailedContainer` onto a list, builds a fresh one for
the incoming game, runs `deactivate*` on the old and `activate*` on the new,
and deletes the old one once its storyboard stops
(`DetailedContainerHost::update`, `:1322-1350`, also culling beyond 4).

**Verified on pixels:** mid-transition frames show the outgoing game's box
art large and travelling while the incoming game's art is small and rising,
with the text block already swapped to the incoming game.

### 3. `scale` and `offsetY` both animate on a gamelist extra

- `scale` is a `FLOAT` property in every element type map and is applied by
  `GuiComponent::setProperty` (`:1196`).
- `mScaleOrigin` defaults to `(0.5, 0.5)` (`GuiComponent.cpp:21`), so scale
  shrinks the component toward its own centre. **No `scaleOrigin` override
  is needed**, and none should be added.
- `offsetY` writes `mScreenOffset` (`:1201`), applied as a plain translate
  at `:434` — *before* the scale block at `:437-447`. It is screen-space and
  touches neither layout nor `<pos>`.

**Verified on pixels:** 16 frames of continuous change against baseline's 1,
spanning exactly the declared 1500 ms. At 13% of the animation the outgoing
card had moved −20 px against a predicted −25 px, and the incoming card sat
at y ≈ 617 against a predicted 615.

This matters because the v0.11 spike found `property="position"` silently
does *not* animate while `x`/`y` do. `offsetY` was not safe to assume.

### 4. Adding the storyboard moves the element to a different owner

`ThemeData::makeExtras` partitions extras on exactly "has an activation
storyboard":

- `DetailedGameListView` sets `mExtraMode = WITHOUT_ACTIVATESTORYBOARD`
  (`DetailedGameListView.cpp:14`), so the **view** takes extras with no
  activation storyboard.
- `DetailedContainer` takes `WITH_ACTIVATESTORYBOARD | PERGAMEEXTRAS`
  (`DetailedContainer.cpp:523`).

So `cardBoxart` and `cardFallback` leave `ISimpleGameListView::mThemeExtras`
— and therefore stop being rebound by `updateThemeExtrasBindings()` — and
join the container's own extras, which are rebound at
`DetailedContainer.cpp:1025`. **Verified on pixels:** the art still tracks
the cursor correctly, including the `<visible>` guard on `cardFallback`.

### 5. No accidental fades are introduced

`DetailedContainer`'s constructor sets `mState(true)`
(`DetailedContainer.cpp:37`), so a freshly-built container hits the
`if (state == mState) return;` early-out at `:1051` and **skips** the
generic 250 ms opacity `LambdaAnimation` at `:1077-1095`. On the outgoing
container, components *without* an activation storyboard take the
`setOpacity(0)` + `disableComponent` branch at `:1063-1068` and vanish
immediately rather than lingering.

Net effect: only the elements we explicitly animate change behaviour.

### 6. The transition must not fire on gamelist entry

Entering a gamelist is `moveBy == 0`, which falls through to the `open` and
unnamed-default branches. Since this design declares neither, entry stays a
hard cut. **Verified on pixels:** gamelist entry remained a single-frame
change in the spike, identical to baseline.

### 7. Fast scrolling stacks containers but renders cleanly

Seven Down presses at 250 ms intervals against 1500 ms animations produced a
visible fan of 3–4 box arts at different scales. No corruption, no crash, no
dropped card. At the shipping 150 ms the animation completes before a
typical repeat, so at most 1–2 containers should ever coexist.

### 8. The travel distance is exactly one slot

Measured slot centres at 1024×768: **0.3340 / 0.5846 / 0.8340**, a pitch of
0.2503 against the declared `glListH / 3 = 0.25`. The card's own centre
measured **0.5846** — identical to the middle slot's centre. So `offsetY` of
±0.25 lands the card centre exactly on the adjacent peek centre.

### 9. `common.xml`'s card size variables are dead — the scale is not 0.375

This design's first draft used `scale` 0.375, derived from `common.xml`'s
`cardBoxartW` 0.234 / `cardBoxartH` 0.3125. **Those values never render.**
`_inc/icon-size-boxart.xml:17-18` overrides them with 0.22 / 0.29, and
`icon-size-compact.xml:18-19` with 0.155 / 0.205. This is the same
`common.xml`-versus-`icon-size-*.xml` trap that has cost this repo a debug
cycle before.

Measured with a flat-colour calibration library (the method from #43 — real
art cannot distinguish a fitted edge from a trimmed one; flat colours bbox
to the pixel), rendering the *same* art at both sizes:

| `ICON_SIZE` | card (450×600 art) | peek (same art) | ratio |
|---|---|---|---|
| Boxart | 167×223 | 73×98 | **0.439** |
| Compact | 118×157 | 61×82 | **0.522** |

The peek and card boxes have different aspect ratios, so the ratio depends
on which `maxSize` cap each slot hits:

- both width-limited → `peekIconW / cardBoxartW`
- both height-limited → `(peekIconH × glListH / 3) / cardBoxartH`

| `ICON_SIZE` | landscape | square | portrait |
|---|---|---|---|
| Boxart | 0.4000 | 0.404 | 0.4397 |
| Compact | 0.4710 | 0.477 | 0.5183 |

**Both bounds are pure ratios of theme variables, so they are independent of
screen aspect ratio.** Confirmed algebraically and consistent with the
measurements: no per-aspect override is needed, and none should be added to
`aspect-*.xml`.

No single uniform `scale` lands exactly for every art aspect; the spread is
about 10%. Since the card is at opacity 0 by the time it arrives, the
endpoint is not visible and the trajectory is what reads.

## Decisions

Locked with the user before implementation.

| Decision | Choice | Rationale |
|---|---|---|
| Scope | **Box art only** | `cardBoxart` + `cardFallback`. Title, line, metadata and description keep swapping instantly. Smallest blast radius. |
| Travel | **Full demotion** | One slot (±0.25) and down to peek scale, so the art lands where and how big its peek icon now is. Closest analogue to the carousel. |
| Duration | **150 ms, `easeOut`** | Matches the existing peek-icon fades exactly and the PSP's own ~150 ms intercategory transition. §7.2 rejected ES's 500–700 ms slide as "molasses". |
| User knob | **Always on, no subset** | There are already seven subsets. Escape hatch is switching gamelist style. |
| `scale` value | **Per-`ICON_SIZE` variable** | See fact 9. A constant cannot be right for both subsets. |
| Plain `activate`/`deactivate` | **Deliberately omitted** | `handleStoryBoard` only falls back to them when no direction variant exists, and a direction-blind version of this animation is wrong half the time. |

## Architecture

One file changes behaviour: `_inc/gamelist-card.xml`. Three variable files
gain declarations: both icon-size subsets (`cardPeekScale`) and `common.xml`
(`cardPeekShift` and `cardPeekScale`).

### 1. New variable: `cardPeekScale`

Declared in **both** icon-size subsets, because the correct value is a
function of that subset's own `peekIconW/H` and `cardBoxartW/H`:

| File | Value | Derivation |
|---|---|---|
| `_inc/icon-size-boxart.xml` | `0.42` | midpoint of 0.4000 (landscape) and 0.4397 (portrait) |
| `_inc/icon-size-compact.xml` | `0.495` | midpoint of 0.4710 and 0.5183 |
| `_inc/common.xml` | `0.42` | must equal the boxart value; see below |

Midpoint rather than exact-for-portrait because the ±5% residual is masked
by the opacity ramp, and a midpoint bounds the error for *every* aspect
rather than minimising it for one.

**`common.xml` must also declare it, at the same 0.42.** An earlier draft of
this spec argued the opposite — that a `common.xml` value would be dead the
way `cardBoxartW/H` are dead. That reasoning rested on a false premise and is
reversed here.

`test-body-legibility.sh:150-157` records the actual behaviour: *"In the
harness the subset's first include applies and boxart wins; on the device no
include applies and common.xml wins."* That is why `cardBoxartW/H` diverge,
and why a fresh device shows a box art ~7% larger than every render ever
taken. So on a fresh device the card renders **fine** from `common.xml` — it
is not broken, and `${cardPeekScale}` would resolve to the empty string.
`toFloat("")` is 0, so `scale` would animate to **0**: the box art shrinks to
nothing and vanishes on every cursor move. Device-only, and invisible to the
harness.

The value is 0.42 (matching `icon-size-boxart.xml`) rather than 0.392
(`common.xml`'s own midpoint, from its own dead `cardBoxartW/H`). The existing
guard's entire purpose is that these two files agree on every shared `card*`
variable; the `cardBoxartW/H` divergence is recorded there as a **bug**, not a
pattern to copy. Agreeing also means that existing guard enforces the pairing
for free, with no new check.

This claim about fresh-device include behaviour is inherited from that suite's
comment and from prior device sessions. It has not been re-verified on
hardware for this change, and it is the one thing device verification should
confirm first.

While editing these two files, correct their header comments, which still
derive the peek sizes from `glListH=0.69`. `common.xml` has held `0.75`
since v0.12. The stale figure sits directly above where `cardPeekScale`'s
derivation will be written.

### 2. New variable: `cardPeekShift`

Declared once in `_inc/common.xml` as `0.25`, the one-slot travel. Unlike
`cardPeekScale` this does **not** vary by icon size — it is `glListH / 3`,
and `glListH` is defined only in `common.xml` (0.75) and overridden nowhere.
A test guard asserts the identity so the two cannot drift apart.

### 3. Storyboards on `cardBoxart` and `cardFallback`

Both elements get the identical set, so unscraped games transition too.
Values are shown resolved; the XML uses `${cardPeekShift}` and
`${cardPeekScale}`.

| Event | `offsetY` | `scale` | `opacity` |
|---|---|---|---|
| `deactivateNext` | `0 → -0.25` | `1 → ${cardPeekScale}` | `1 → 0`, `begin=30 duration=120` |
| `deactivatePrev` | `0 → +0.25` | `1 → ${cardPeekScale}` | `1 → 0`, `begin=30 duration=120` |
| `activateNext` | `+0.25 → 0` | `${cardPeekScale} → 1` | `0 → 1`, `begin=0 duration=110` |
| `activatePrev` | `-0.25 → 0` | `${cardPeekScale} → 1` | `0 → 1`, `begin=0 duration=110` |

`offsetY` and `scale` run the full `duration=150 mode="easeOut"`.

### 4. Why the opacity ramps are load-bearing, and asymmetric

The spike ran with no opacity animation, and the result showed the defect
plainly: the incoming card visibly collides with and stacks on top of the
peek icon it passes over. The cross-dissolve is not polish.

The two ends are **not** symmetric, and the reason is which art each end
overlaps:

- The **outgoing** card travels toward the slot where *its own* peek icon is
  simultaneously fading in (the existing `deactivate` storyboard on
  `tplPeekIcon`, opacity 0 → 1 over 150 ms). Those are the *same image at
  the same place at the same size*, so the cross-dissolve is between
  identical pixels and needs no hiding. Hence a late, slow fade
  (`begin=30`): the card stays solid for most of its journey.
- The **incoming** card starts at the far slot, where a *different* game's
  peek icon is now drawn. That overlap is the ugly one, so opacity ramps
  from 0 immediately (`begin=0`) and is solid well before arrival.

The `begin` values above are a starting point to be tuned from rendered
frames, not asserted. The *asymmetry* is the design decision; the exact
milliseconds are an implementation detail.

### 5. What does not change

- **The peek textlist.** `TextListComponent::updateCameraOffset()` sets
  `mCameraOffset` instantly — there is no lerp, so peek icons snap and
  cannot be made to travel. Their existing `activate`/`deactivate` opacity
  storyboards are untouched. They live on the textlist's `itemTemplate`,
  which is not part of `DetailedContainer`, so double-buffering does not
  reach them.
- **`<pos>`, `<maxSize>`, `<origin>`, `<zIndex>`** on both elements.
  `offsetY` is applied on top of the transform and does not disturb layout.
- **Styles B and D** and all five `aspect-*.xml` files. `common.xml` gains
  `cardPeekShift` and nothing else — no existing value in it changes.
- **The wave.** It is declared in `wave-motion.xml` with no activation
  storyboard, so it stays in the view's extras, is not duplicated, and its
  storyboard is not reset.

## Risks

| Risk | Severity | Mitigation |
|---|---|---|
| `md_video` is rebuilt on every cursor move, because a whole new `DetailedContainer` is constructed | **High — the main one** | Cannot be measured in the harness: it renders desktop GL21, the device GLES2. **Device verification on the Brick is a merge gate**, not a nice-to-have. |
| Held d-pad stacks containers | Low | Measured safe at 1500 ms, which is 10× the shipping duration. Re-check on device. |
| `cardPeekScale` missing from any of the three files | **High on device, invisible in harness** | An unresolved `${cardPeekScale}` becomes `toFloat("") = 0`, animating the card to nothing. The `common.xml` copy is what covers a fresh device with no icon-size subset selected. Guarded by test in all three files. |
| The 8 doc citations into `gamelist-card.xml` all shift | Certain | Every citation in `psp-authenticity-audit.md` is at line ≥ 123 and the insert is at ~line 112. Re-point them all; this class of breakage has cost time twice. |

## Verification

1. **Harness, structural:** `scripts/tests/test-card-transition.sh`, following
   the house pattern — `check_pin`/`check_bool` from `lib/theme-subsets.sh`,
   the `docker image inspect || docker build` guard, strict XML parse, and a
   mutation table run in **both** halves (should-pass and should-fail; the
   `(?i)` allowlist bug in #47 was caught only by the should-fail half).
2. **Harness, pixels:** frame-diff a recording against the `main` baseline.
   The pass condition is a *run* of changed frames spanning the declared
   duration where `main` has exactly one. Measure the actual travel and
   landing scale rather than asserting them.
3. **Device, the Brick:** deploy, compare against `main` captured from the
   same device, and specifically watch the media slot for video-rebuild
   stutter under both single presses and a held d-pad.

Guards must key on the *properties* the thing must have, not on a substring
that happens to spell it — a `grep -q 'storyboard'` passes against a comment.

## Out of scope

- Styles B (List + Details) and D (Box Art Grid).
- Animating the text block, metadata or description.
- Making the peek icons travel — structurally impossible (fact: no lerp in
  `updateCameraOffset`).
- A `cardTransition` on/off subset.
- Any change to `defaultTransition` or the system carousel.

## Tracking

This repo's convention is one issue per change, but every issue is closed
following the v1.0 go-public milestone and the repository is now public.
Filing an issue is an outward-facing action, so it is left to the user
rather than done silently. The spec and plan stand on their own if no issue
is filed.
