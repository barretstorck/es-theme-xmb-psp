# XMB Animated Wave (v0.3) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a continuously-animating PSP XMB-style wave background to the theme with four user-selectable motion styles (Parallax / Slide / Pulse / Static), surviving system navigation without resets and without stopping on a black frame.

**Architecture:** Replace v0.2's frame-based animation attempt (GIF/MP4) with ES property animation via `<storyboard repeat="forever">` on the existing static `wave.png`. Move the wave element from per-system views into `<view name="screen">` so its state persists across view transitions. Expose motion style as a new `motion` subset alongside the existing `colorset` subset — the user picks one from UI Settings → Theme Configuration → Wave Motion.

**Tech Stack:** XML theme files (`formatVersion 7`), batocera-emulationstation on Knulli Scarab, deploy via `scripts/deploy.sh sync`. No automated test framework — verification is the user manually reloading ES on the TrimUI Brick (192.168.1.5) and reporting visual behavior.

---

## Testing model — read this before starting any task

This is a theme project with no automated test suite. The "test" for each task is the user's visual verification on the TrimUI Brick. Per the project memory `Knulli ES quirks for theme development`:

- **The dev machine never auto-restarts ES.** After each `./scripts/deploy.sh sync`, the agent prompts the user to reload ES manually (Main Menu → Quit → Restart Emulation Station). The agent must NOT run `./scripts/deploy.sh restart`, `activate`, or `push`.
- **The user is at the device** and describes what they see when asked.
- **If the device enters a crash loop:** the agent may run `./scripts/deploy.sh fallback` only when the user explicitly confirms a crash loop is in progress.

Each task below has a **Sync** step (agent runs), a **User verification** step (user reloads ES and reports), and a **Commit** step (agent runs after user confirms success).

---

## Task 1: Move wave element from per-view to screen view

**Files:**
- Modify: `_inc/common.xml` — add `waveBackground` image inside the existing `<view name="screen">` block
- Modify: `_inc/system.xml` — remove the `waveBackground` image element (lines 16–22)
- Modify: `_inc/gamelist.xml` — remove the `waveBackground` image element (lines 12–18)

- [ ] **Step 1: Edit `_inc/common.xml` — replace the existing `<view name="screen">` block**

Replace this existing block:
```xml
  <view name="screen">
    <controllerActivity name="controllerActivity">
      <visible>false</visible>
    </controllerActivity>
    <text name="clock">
      <visible>false</visible>
    </text>
  </view>
```
with:
```xml
  <view name="screen">
    <!-- Global wave background. Lives in screen view so its animation
         state persists across system / gamelist transitions. -->
    <image name="waveBackground" extra="true">
      <path>./art/wave/wave.png</path>
      <pos>0.5 0.5</pos>
      <size>1.10 1.10</size>
      <origin>0.5 0.5</origin>
      <color>${waveTint}</color>
      <zIndex>0</zIndex>
    </image>

    <!-- Hide ES's built-in OSD overlays so they don't double up with our
         theme. controllerActivity is the white-pink square top-left;
         the built-in clock is the duplicate bottom-right one. -->
    <controllerActivity name="controllerActivity">
      <visible>false</visible>
    </controllerActivity>
    <text name="clock">
      <visible>false</visible>
    </text>
  </view>
```

- [ ] **Step 2: Edit `_inc/system.xml` — delete the wave image block**

Delete this entire block (currently lines 11–22):
```xml
    <!-- Static wave background. Attempted animation via <video> and
         animated <image> (GIF/APNG); both play once and stop on the
         last frame in this batocera-ES build (often a black frame).
         No image-element format we've tested natively repeats.
         Static is the reliable choice; v0.3 may revisit. -->
    <image name="waveBackground" extra="true">
      <path>./art/wave/wave.png</path>
      <pos>0 0</pos>
      <size>1 1</size>
      <color>${waveTint}</color>
      <zIndex>0</zIndex>
    </image>
```

The clock and carousel elements below it stay.

- [ ] **Step 3: Edit `_inc/gamelist.xml` — delete the wave image block**

Delete this entire block (currently lines 11–18):
```xml
    <!-- Same static wave background as system view -->
    <image name="waveBackground" extra="true">
      <path>./art/wave/wave.png</path>
      <pos>0 0</pos>
      <size>1 1</size>
      <color>${waveTint}</color>
      <zIndex>0</zIndex>
    </image>
```

- [ ] **Step 4: Sync to device**

Run: `./scripts/deploy.sh sync`
Expected: rsync completes without errors. Do NOT restart ES from the dev machine.

- [ ] **Step 5: Prompt user to verify**

Send to user: *"Synced. Please reload ES (Main Menu → Quit → Restart Emulation Station). When it comes back up, navigate to a system view, then into a gamelist, then back out. Report what you see — specifically: (a) is the wave still visible? (b) does it still have the colorset tint? (c) does anything look broken in the layout?"*

Wait for user confirmation that the wave renders correctly in both views with no regressions. If anything is broken, debug before proceeding (do not commit broken state).

- [ ] **Step 6: Commit**

```bash
git add _inc/common.xml _inc/system.xml _inc/gamelist.xml
git commit -m "$(cat <<'EOF'
Move wave element from per-view to screen view

Lives in <view name="screen"> so its state persists across system /
gamelist transitions. Foundation for v0.3 storyboard motion that won't
reset on navigation.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 2: Fade carousel transition

**Files:**
- Modify: `_inc/system.xml` — add `<defaultTransition>fade</defaultTransition>` to the `<carousel name="systemcarousel">` element

- [ ] **Step 1: Edit `_inc/system.xml` — add the transition element**

Inside the `<carousel name="systemcarousel">` block (currently around lines 25–38 after Task 1's deletions), add `<defaultTransition>fade</defaultTransition>` as the first child element. The carousel should look like:

```xml
    <carousel name="systemcarousel">
      <defaultTransition>fade</defaultTransition>
      <type>horizontal</type>
      <pos>0 0.20</pos>
      <size>1 0.30</size>
      <color>00000000</color>
      <logoSize>0.10 0.14</logoSize>
      <logoScale>1.5</logoScale>
      <logoRotation>0</logoRotation>
      <logoAlignment>center</logoAlignment>
      <maxLogoCount>7</maxLogoCount>
      <textColor>${textSecondary}</textColor>
      <selectedTextColor>${textPrimary}</selectedTextColor>
      <zIndex>5</zIndex>
    </carousel>
```

- [ ] **Step 2: Sync to device**

Run: `./scripts/deploy.sh sync`

- [ ] **Step 3: Prompt user to verify**

Send to user: *"Synced. Please reload ES, then scroll left/right through systems on the main carousel. Report: does the system-to-system transition look like a fade (smoother, no horizontal slide motion) compared to before? Anything jarring?"*

Wait for user confirmation. If they prefer the slide, we can revert and skip; the rest of the plan does not depend on this task.

- [ ] **Step 4: Commit**

```bash
git add _inc/system.xml
git commit -m "$(cat <<'EOF'
Use fade transition on system carousel

Smoother cross-system handoff than the implicit fade & slide, and
removes a separate visual reset that compounded with the wave reset.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 3: Add motion subset framework with Static option

**Files:**
- Create: `motion/static.xml`
- Modify: `theme.xml` — add `motion` subset declaration

- [ ] **Step 1: Create `motion/static.xml`**

Write the file with this exact content:
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!--
  es-theme-xmb-psp - "Static" wave motion option.
  Intentionally empty: inherits the common.xml waveBackground with no
  storyboard override. Equivalent to v0.2 behavior. Also acts as the
  user-facing rollback path if other motions misbehave.
-->
<theme>
  <formatVersion>7</formatVersion>
  <view name="screen">
  </view>
</theme>
```

- [ ] **Step 2: Edit `theme.xml` — add motion subset block**

Insert this block immediately after the closing `</subset>` of the existing colorset block (currently line 24), before the `<include>./_inc/common.xml</include>` line:

```xml

  <subset name="motion" displayName="Wave Motion">
    <include name="Static">./motion/static.xml</include>
  </subset>
```

(Note the leading blank line for readability.)

- [ ] **Step 3: Sync to device**

Run: `./scripts/deploy.sh sync`

- [ ] **Step 4: Prompt user to verify**

Send to user: *"Synced. Please reload ES, then go to Main Menu → UI Settings → Theme Configuration. Report: (a) is there a new 'Wave Motion' option listed alongside 'PSP Color'? (b) when you open Wave Motion, do you see 'Static' as the only choice? (c) selecting Static and reloading — does the theme look exactly like before, no changes?"*

Wait for confirmation that the subset surfaces in UI Settings and Static produces no visual change.

- [ ] **Step 5: Commit**

```bash
git add motion/static.xml theme.xml
git commit -m "$(cat <<'EOF'
Add Wave Motion subset framework with Static option

Motion subset surfaces in UI Settings -> Theme Configuration -> Wave
Motion. Static is the user-facing rollback path: equivalent to v0.2
behavior, no storyboard. Real motion options land in following commits.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 4: Add Parallax motion (default)

**Files:**
- Create: `motion/parallax.xml`
- Modify: `theme.xml` — list Parallax FIRST in the motion subset

- [ ] **Step 1: Create `motion/parallax.xml`**

Write the file with this exact content:
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!--
  es-theme-xmb-psp - "Parallax" wave motion.
  Two layers of wave.png, different opacity / scale / period / phase.
  They drift, diverge, and converge over time, reading as parallax
  depth without needing a seamless texture.
-->
<theme>
  <formatVersion>7</formatVersion>
  <view name="screen">

    <!-- Back layer: override of the common waveBackground -->
    <image name="waveBackground" extra="true">
      <opacity>0.55</opacity>
      <storyboard>
        <animation property="x" from="0.48" to="0.52"
                   duration="28000" mode="easeInOut"
                   autoreverse="true" repeat="forever"/>
      </storyboard>
    </image>

    <!-- Front layer: new element, slightly larger, faster, reversed phase -->
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

- [ ] **Step 2: Edit `theme.xml` — add Parallax FIRST in subset**

Replace the motion subset block from Task 3:
```xml
  <subset name="motion" displayName="Wave Motion">
    <include name="Static">./motion/static.xml</include>
  </subset>
```
with:
```xml
  <subset name="motion" displayName="Wave Motion">
    <include name="Parallax">./motion/parallax.xml</include>
    <include name="Static">./motion/static.xml</include>
  </subset>
```

Listing Parallax first makes it the default when no selection has been made.

- [ ] **Step 3: Sync to device**

Run: `./scripts/deploy.sh sync`

- [ ] **Step 4: Prompt user to verify**

Send to user: *"Synced. Please reload ES, then UI Settings → Theme Configuration → Wave Motion → Parallax, and reload again. Watch the system view for 60 seconds, then navigate into a gamelist and back. Report: (a) do you see continuous wave motion? (b) does it ever stop or go black? (c) does it reset when you navigate between systems or into a gamelist? (d) does it feel smooth or laggy? (e) general aesthetic — anything you'd change about speed / opacity / scale?"*

Wait for confirmation. If user wants to tune, iterate on the storyboard parameters here before committing — adjustments don't need separate tasks. Common tuning knobs:
- Slower motion → increase `duration` (e.g., 28000 → 40000)
- More dramatic motion → widen `from`/`to` range (e.g., 0.48–0.52 → 0.46–0.54)
- Quieter back layer → lower `<opacity>0.55</opacity>` (e.g., to 0.40)
- Brighter front layer → raise `<opacity>0.85</opacity>` toward 1.00

If Parallax misbehaves badly (crash loop, washed-out tint, etc.), apply the rollback documented in spec §9 risk table.

- [ ] **Step 5: Commit**

```bash
git add motion/parallax.xml theme.xml
git commit -m "$(cat <<'EOF'
Add Parallax wave motion (default)

Two layers of wave.png with different speeds, opacities, scales, and
start phases. Drives motion via <storyboard repeat="forever"> on a
static PNG, so no codec frame counter to exhaust. Listed first in the
Wave Motion subset to make it the default.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 5: Add Slide motion

**Files:**
- Create: `motion/slide.xml`
- Modify: `theme.xml` — add Slide to motion subset (between Parallax and Static)

- [ ] **Step 1: Create `motion/slide.xml`**

Write the file with this exact content:
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!--
  es-theme-xmb-psp - "Slide" wave motion.
  Single wave layer, slow horizontal autoreverse. Flatter than Parallax,
  more PSP-swell-like than Pulse.
-->
<theme>
  <formatVersion>7</formatVersion>
  <view name="screen">
    <image name="waveBackground" extra="true">
      <storyboard>
        <animation property="x" from="0.48" to="0.52"
                   duration="22000" mode="easeInOut"
                   autoreverse="true" repeat="forever"/>
      </storyboard>
    </image>
  </view>
</theme>
```

- [ ] **Step 2: Edit `theme.xml` — add Slide to subset**

Replace the motion subset block from Task 4:
```xml
  <subset name="motion" displayName="Wave Motion">
    <include name="Parallax">./motion/parallax.xml</include>
    <include name="Static">./motion/static.xml</include>
  </subset>
```
with:
```xml
  <subset name="motion" displayName="Wave Motion">
    <include name="Parallax">./motion/parallax.xml</include>
    <include name="Slide">./motion/slide.xml</include>
    <include name="Static">./motion/static.xml</include>
  </subset>
```

- [ ] **Step 3: Sync to device**

Run: `./scripts/deploy.sh sync`

- [ ] **Step 4: Prompt user to verify**

Send to user: *"Synced. Please reload, then UI Settings → Wave Motion → Slide, reload. Report: (a) is there motion? (b) does the wave glide slowly side to side? (c) does it stop or reset? (d) anything to tune — speed, range?"*

Wait for confirmation. Tunable similarly to Task 4.

- [ ] **Step 5: Commit**

```bash
git add motion/slide.xml theme.xml
git commit -m "$(cat <<'EOF'
Add Slide wave motion

Single-layer horizontal autoreverse. Flatter and lighter than Parallax;
a good fallback if two-layer parallax is too heavy on weaker devices.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 6: Add Pulse motion

**Files:**
- Create: `motion/pulse.xml`
- Modify: `theme.xml` — add Pulse to motion subset (between Slide and Static)

- [ ] **Step 1: Create `motion/pulse.xml`**

Write the file with this exact content:
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!--
  es-theme-xmb-psp - "Pulse" wave motion.
  No translation. Wave gently breathes via scale + opacity autoreverse.
  Calmest motion option.
-->
<theme>
  <formatVersion>7</formatVersion>
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
</theme>
```

- [ ] **Step 2: Edit `theme.xml` — add Pulse to subset**

Replace the motion subset block from Task 5:
```xml
  <subset name="motion" displayName="Wave Motion">
    <include name="Parallax">./motion/parallax.xml</include>
    <include name="Slide">./motion/slide.xml</include>
    <include name="Static">./motion/static.xml</include>
  </subset>
```
with:
```xml
  <subset name="motion" displayName="Wave Motion">
    <include name="Parallax">./motion/parallax.xml</include>
    <include name="Slide">./motion/slide.xml</include>
    <include name="Pulse">./motion/pulse.xml</include>
    <include name="Static">./motion/static.xml</include>
  </subset>
```

- [ ] **Step 3: Sync to device**

Run: `./scripts/deploy.sh sync`

- [ ] **Step 4: Prompt user to verify**

Send to user: *"Synced. Please reload, then UI Settings → Wave Motion → Pulse, reload. Report: (a) does the wave gently grow/shrink and brighten/dim in sync? (b) does it stop or stutter? (c) too subtle / too obvious — anything to tune?"*

Wait for confirmation. Tunable knobs: scale range (1.00–1.04), opacity range (0.85–1.00), duration (6000ms).

- [ ] **Step 5: Commit**

```bash
git add motion/pulse.xml theme.xml
git commit -m "$(cat <<'EOF'
Add Pulse wave motion

Scale + opacity autoreverse, no translation. Calmest of the four motion
options; useful when the user wants ambient life without movement.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 7: README update, screenshots, and tag v0.3

**Files:**
- Modify: `README.md` — add Wave Motion to Customization, drop the "no animated wave" limitation, refresh the version banner
- Create: `docs/screenshots/motion-parallax.png`
- Create: `docs/screenshots/motion-slide.png`
- Create: `docs/screenshots/motion-pulse.png`

- [ ] **Step 1: Capture per-motion screenshots**

For each of Parallax, Slide, Pulse:

1. Prompt user: *"Set Wave Motion to <Parallax|Slide|Pulse> and reload. When you're on the system view, tell me 'capture'."*
2. When user says capture, run: `./scripts/deploy.sh shot motion-<style>` which pulls a screenshot from the device into `docs/screenshots/motion-<style>.png`.

(If the `shot` subcommand doesn't take a name argument, capture into a default path and `mv` into place.)

- [ ] **Step 2: Edit `README.md`**

Replace the version banner line:
```markdown
> Status: **v0.2** — PSP-style variant only. 4:3 only. Twelve user-selectable PSP-month colorsets. Default colorset is January Blue.
```
with:
```markdown
> Status: **v0.3** — PSP-style variant only. 4:3 only. Twelve user-selectable PSP-month colorsets, four user-selectable wave motion styles. Default colorset is January Blue; default motion is Parallax.
```

Replace this Known v0.2 limitations bullet:
```markdown
- **No animated wave background.** Tested `<video>` and animated `<image>` (GIF, APNG) — all play once and stop on the last frame in this batocera-emulationstation build, often a black frame. Static PNG is the reliable choice for now.
```
with:
```markdown
- **Diagonal wave scroll not yet shipped.** The four motion styles in v0.3 (Parallax / Slide / Pulse / Static) all use either bounded translation or scale/opacity to stay visually correct with the current non-seamless `wave.png`. Continuous one-way diagonal scrolling needs a seamlessly-tileable source and is on the v0.4 roadmap.
```

In the Customization section, replace the current single-paragraph customization description:
```markdown
The only configurable knob is colorset (PSP-authentic month-tinted palettes). Change it under **UI Settings → Theme Configuration → PSP Color**. No per-system or per-device overrides — the theme intentionally ships minimal.
```
with:
```markdown
Two configurable knobs, both under **UI Settings → Theme Configuration**:

- **PSP Color** — twelve PSP-authentic month-tinted palettes for the wave and accent colors.
- **Wave Motion** — animation style for the background:
  - **Parallax** (default) — two wave layers drifting at different speeds.
  - **Slide** — single wave gliding slowly side to side.
  - **Pulse** — wave gently breathing via scale + opacity, no translation.
  - **Static** — no animation. Also the rollback path if a motion option misbehaves on your device.

No per-system or per-device overrides — the theme intentionally ships minimal.
```

- [ ] **Step 3: Commit README + screenshots**

```bash
git add README.md docs/screenshots/motion-parallax.png docs/screenshots/motion-slide.png docs/screenshots/motion-pulse.png
git commit -m "$(cat <<'EOF'
Document v0.3 Wave Motion: README, per-motion screenshots, version banner

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

- [ ] **Step 4: Tag v0.3**

```bash
git tag -a v0.3 -m "$(cat <<'EOF'
v0.3 - User-selectable animated wave motion

Replace v0.2's static wave with ES storyboard-driven property animation
on the same wave.png. Wave element lives in <view name="screen"> so its
animation state persists across system and gamelist navigation.

Four motion styles ship as a Wave Motion subset under UI Settings ->
Theme Configuration:
  - Parallax (default): two layers, drift against each other
  - Slide: single layer, horizontal autoreverse
  - Pulse: scale + opacity breathing, no translation
  - Static: no animation, equivalent to v0.2

System carousel transition switched from "fade & slide" to plain fade
for smoother cross-system handoff.

Diagonal motion deferred to v0.4 (requires seamless wave texture).
EOF
)"
```

- [ ] **Step 5: Prompt user for final verification**

Send to user: *"v0.3 tagged. Please reload one more time and cycle through the four Wave Motion options to confirm everything works end-to-end. Anything you'd like to revise before we close v0.3?"*

If user requests changes, make them and amend or add follow-up commits before considering v0.3 closed.

---

## Out of scope (for this plan)

- **Diagonal motion** — needs seamless `wave.png`. v0.4.
- **Shader-based motion** (`shader.waveTime`, `shader.noiseTime`) — deferred indefinitely; GPU-dependent and exotic.
- **Per-system wave variants.**
- **Push to a remote / GitHub release.** Local-only until user requests a remote.
