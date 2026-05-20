# XMB Animated Wave — v0.3 Design

**Date:** 2026-05-20
**Targets:** Knulli Scarab on TrimUI Brick (4:3, 1024×768), batocera-emulationstation `formatVersion 7`
**Builds on:** `2026-05-20-xmb-knulli-port-design.md` (v0.1) + the v0.2 polish pass
**Goal:** Add a continuously-animating PSP-XMB-style wave background that doesn't stop, doesn't reset on system navigation, and lets the user pick a motion style from UI Settings.

## Revision 2026-05-20 (during implementation)

The original spec proposed moving the wave element into `<view name="screen">` so its animation state would persist across system → gamelist transitions. **This was wrong** — `<view name="screen">` is the OVERLAY layer (intended for OSD elements like controllerActivity hides and persistent clocks). Putting a full-screen image there covers everything, including the carousel and the main menu. Verified by device test during Task 1.

**Corrected approach:** Define the wave element in each per-view block (`<view name="system">` in `_inc/system.xml`, `<view name="detailed">` in `_inc/gamelist.xml`) with matching `pos/size/origin/color/zIndex` so the visual feel matches across views. Motion files target a combined `<view name="system,detailed">` block to apply the same storyboard to both. The element name remains `waveBackground` everywhere; storyboard overrides via element-name match.

**Consequence:** Animation state resets when transitioning between the system view and a gamelist (a separate `waveBackground` instance is created per view). Scrolling *within* the system carousel does NOT reset the animation, because the system view itself isn't reinstantiated. This is the v0.3 limitation; the cross-view reset is acceptable given that scrolling between systems was the primary motion-disruption case reported in v0.2.

Sections 2, 5, and 6 below describe the original (wrong) architecture; treat them as historical context. The plan at `docs/superpowers/plans/2026-05-20-xmb-animated-wave.md` has been updated to reflect the corrected architecture.

---

## 1. Problem statement

The static `art/wave/wave.png` shipped in v0.2 is the placeholder we landed after two failed animation attempts:

- `wave.mp4` (video element): too resource intensive on the Brick, and the loop reset every time the user navigated between systems.
- `wave.gif` (animated image element): looked correct initially, but the animation stopped on the last frame (often black) and also reset on system navigation.

The root cause of both problems is that the underlying ES build's image and video elements were animating by walking frames of the encoded media, and that frame walker (a) doesn't repeat reliably and (b) gets re-instantiated whenever the per-system view re-mounts.

## 2. Approach

Three orthogonal changes, each addressing one observed problem:

1. **Replace the encoded animation with ES storyboard property animation on the static `wave.png`.**
   The PNG is decoded once. ES drives motion by animating `x` / `y` / `scale` / `opacity` on the still image via `<storyboard repeat="forever">`. No codec frame counter to exhaust → no "stops on black frame".
   *Evidence:* `FakeXMB/main/views/content.xml`, `Neon-Blast/gametriangle.xml`, and `Artflix-Cobalto/theme.xml` in `.dev/themes/` all use this pattern successfully.

2. **Move the wave element from `<view name="system">` / `<view name="detailed">` into `<view name="screen">`.**
   `screen` is the top-level overlay view (we already use it to hide ES's built-in `controllerActivity` and duplicate clock). Elements declared there persist across view transitions, so navigating from the system carousel into a gamelist does not reinstantiate the wave, and the storyboard's animation state continues uninterrupted.

3. **Set `<defaultTransition>fade</defaultTransition>` on the system carousel.**
   The implicit `fade & slide` transition was visually distinct from the wave animation; switching to plain fade gives a cleaner cross-system handoff.

The `wave.png` itself, and the per-month `${waveTint}` colorset variable, both remain exactly as they are in v0.2.

## 3. Motion style is a user-selectable subset

A new subset `motion` (display name **Wave Motion**) is added alongside the existing `colorset` subset. The user picks one from **UI Settings → Theme Configuration → Wave Motion** — same UX as PSP Color.

Four options ship in v0.3, ordered so the first listed becomes the default:

| Display name | File | Visual character |
|---|---|---|
| Parallax (default) | `motion/parallax.xml` | Two wave layers, different speeds/opacities/phases, drifting against each other |
| Slide | `motion/slide.xml` | Single wave, slow horizontal autoreverse |
| Pulse | `motion/pulse.xml` | Single wave, no translation, gentle scale + opacity breathing |
| Static | `motion/static.xml` | No animation. Equivalent to v0.2 behavior. Also the user-facing rollback path. |

**Diagonal** motion (continuous one-way scroll, most PSP-authentic) is deferred to v0.4 because it requires a seamlessly-tileable wave texture — the current `wave.png` is not tileable, and shipping it with visible seams would look worse than no motion at all.

## 4. File layout

```
theme.xml                          (add motion subset declaration; list Parallax first)
_inc/
  common.xml                       (wave element moved here, into <view name="screen">)
  system.xml                       (wave element removed; <defaultTransition>fade</defaultTransition> added to systemcarousel)
  gamelist.xml                     (wave element removed)
  menu.xml                         (unchanged)
motion/                            ★ NEW DIRECTORY
  static.xml                       ★ no storyboard (= v0.2 behavior)
  parallax.xml                     ★ adds 2nd wave layer + storyboards on both
  slide.xml                        ★ overrides storyboard on the wave
  pulse.xml                        ★ overrides storyboard on the wave
colors/                            (unchanged)
art/wave/wave.png                  (unchanged)
```

## 5. Shared wave-element base (in `_inc/common.xml`)

Center-anchored and 10% over-scanned so x/scale motion of a few percent never reveals seams:

```xml
<view name="screen">
  <image name="waveBackground" extra="true">
    <path>./art/wave/wave.png</path>
    <pos>0.5 0.5</pos>
    <size>1.10 1.10</size>
    <origin>0.5 0.5</origin>
    <color>${waveTint}</color>
    <zIndex>0</zIndex>
  </image>
  <!-- existing controllerActivity and clock hides remain here unchanged -->
</view>
```

## 6. Motion files

### 6.1 Parallax (`motion/parallax.xml`)

Two layers of the same PNG and tint; differ in opacity, scale, period, and start phase. They drift, diverge, and converge over time — reads to the eye as parallax depth without needing a seamless texture.

```xml
<theme>
  <formatVersion>7</formatVersion>
  <view name="screen">
    <!-- Back layer: overrides storyboard on the common waveBackground -->
    <image name="waveBackground" extra="true">
      <opacity>0.55</opacity>
      <storyboard>
        <animation property="x" from="0.48" to="0.52"
                   duration="28000" mode="easeInOut"
                   autoreverse="true" repeat="forever"/>
      </storyboard>
    </image>
    <!-- Front layer: new element -->
    <image name="waveBackground2" extra="true">
      <path>./art/wave/wave.png</path>
      <pos>0.5 0.5</pos>
      <size>1.10 1.10</size>
      <origin>0.5 0.5</origin>
      <color>${waveTint}</color>
      <opacity>0.85</opacity>
      <scale>1.05</scale>
      <zIndex>1</zIndex>
      <storyboard>
        <animation property="x" from="0.52" to="0.48"
                   duration="18000" mode="easeInOut"
                   autoreverse="true" repeat="forever"/>
      </storyboard>
    </image>
  </view>
</theme>
```

### 6.2 Slide (`motion/slide.xml`)

```xml
<view name="screen">
  <image name="waveBackground" extra="true">
    <storyboard>
      <animation property="x" from="0.48" to="0.52"
                 duration="22000" mode="easeInOut"
                 autoreverse="true" repeat="forever"/>
    </storyboard>
  </image>
</view>
```

### 6.3 Pulse (`motion/pulse.xml`)

```xml
<view name="screen">
  <image name="waveBackground" extra="true">
    <storyboard>
      <animation property="scale" from="1.00" to="1.04"
                 duration="6000" mode="easeInOut"
                 autoreverse="true" repeat="forever"/>
      <animation property="opacity" from="0.85" to="1.00"
                 duration="6000" mode="easeInOut"
                 autoreverse="true" repeat="forever"/>
    </storyboard>
  </image>
</view>
```

### 6.4 Static (`motion/static.xml`)

```xml
<view name="screen">
  <!-- intentionally empty: inherits common.xml waveBackground unchanged -->
</view>
```

## 7. Subset declaration in `theme.xml`

```xml
<subset name="motion" displayName="Wave Motion">
  <include name="Parallax">./motion/parallax.xml</include>
  <include name="Slide">./motion/slide.xml</include>
  <include name="Pulse">./motion/pulse.xml</include>
  <include name="Static">./motion/static.xml</include>
</subset>
```

Listed first → default when no selection has been made.

## 8. Build order and testing protocol

Each step is one `./scripts/deploy.sh sync`, one user-driven ES reload, one observation cycle. Per the Knulli ES quirks memory: I do not auto-restart ES from the dev machine — the user reloads manually after I sync.

1. **Move wave element from `system`/`detailed` views into `<view name="screen">` in `common.xml`.** No motion yet. Validates that the wave still renders and tints correctly from the screen view. Isolates the architectural change.
2. **Set `<defaultTransition>fade</defaultTransition>` on the systemcarousel** in `system.xml`. Subjective check on cross-system handoff feel.
3. **Add `motion` subset declaration to `theme.xml` with only `Static` listed.** Verifies the subset surfaces in UI Settings → Theme Configuration → Wave Motion.
4. **Add `motion/parallax.xml` and list it first in the subset.** First real animation test. User selects Parallax, reloads, reports.
5. **Add `motion/slide.xml`.** User switches, reloads, reports.
6. **Add `motion/pulse.xml`.** User switches, reloads, reports.
7. **README update + per-motion screenshots + `git tag v0.3`.**

## 9. Risks and rollback

| Risk | Symptom | Recovery |
|---|---|---|
| `<view name="screen">` doesn't persist across system → gamelist transitions on this ES build | Animation still resets on view changes | Fall back to defining wave in `system,detailed` views — loses Problem-2 fix but keeps Problem-1 fix |
| `<opacity>` alongside `<color>` tinting fights | Wave looks pale/grey instead of richly tinted | Drop `<opacity>` and use 8-hex color with alpha (`${waveTint}A0`-style) |
| Storyboard on screen-view element ignored | No motion at all | Move storyboard into `system,detailed` views |
| Two-layer parallax too heavy for the Brick | UI lag / frame drops | Drop second layer (effectively becomes Slide) |
| Any motion file crashes ES on activation | Theme enters restart loop | User selects Wave Motion → Static via UI, or runs `./scripts/deploy.sh fallback` to drop back to `carbon` |

**Always-available rollback:** UI Settings → Theme Configuration → Wave Motion → Static restores v0.2 behavior with no file changes and no SSH required.

## 10. Out of scope for v0.3

- Diagonal motion (deferred to v0.4 pending seamless wave texture).
- Shader-based motion (`shader.waveTime`, `shader.noiseTime`) — exotic, GPU-dependent, deferred indefinitely.
- Per-system wave variants.
- Wave motion coupled to carousel scroll (would re-introduce the reset-on-scroll problem we are explicitly avoiding).

## 11. Acceptance criteria for v0.3 release

- Default theme load (no Wave Motion picked) shows Parallax animation continuously, with no black frames.
- Scrolling within the system carousel does not visibly reset the wave animation.
- Navigating from the system view into a gamelist does not visibly reset the wave animation.
- All four Wave Motion options are switchable from UI Settings without restarting ES from the device (only reload via UI).
- Static option visibly stops all animation and matches v0.2 appearance.
- No measurable lag introduced on system navigation compared to v0.2 (subjective: feels at least as responsive).
- README documents Wave Motion under Customization with screenshots of each style.
