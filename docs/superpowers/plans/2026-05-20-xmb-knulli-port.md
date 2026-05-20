# PSP XMB Theme Port (Knulli/Batocera/TrimUI Brick) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship a working PSP-XMB-style theme for batocera-emulationstation running on a TrimUI Brick under Knulli Scarab, with twelve user-selectable colorsets and an animated wave background.

**Architecture:** Port of [`anthonycaccese/xmb-menu-es-de`](https://github.com/anthonycaccese/xmb-menu-es-de) (an ES-DE theme, CC-BY-NC-SA 2.0). Approach is reference-and-reimplement: reuse the source's assets and visual blueprint under attribution; write fresh XML against batocera-emulationstation `formatVersion 7`. Single PSP variant, 4:3 only. Dev loop is `rsync`+`ssh`+`batocera-screenshot` against the Brick at `192.168.1.4`.

**Tech Stack:** batocera-emulationstation (formatVersion 7) theme XML; bash for the dev script; `rsync`, `ssh`, `scp` over LAN; no build system, no runtime tests (the device is the test bed).

**Reference:** Design spec at `docs/superpowers/specs/2026-05-20-xmb-knulli-port-design.md`. Read it before starting.

**Preconditions before Task 1:**
- The TrimUI Brick is powered on, on the same LAN as the dev machine, reachable at `192.168.1.4`.
- SSH credentials: `root` / `linux` (Knulli default).
- The dev machine has `rsync`, `ssh`, `scp`, `ssh-copy-id` installed (standard on macOS).

---

## File map

Files this plan creates (in order of first appearance):

| Path | Created in task | Purpose |
|---|---|---|
| `.gitignore` | 1 | Ignore `.dev/`, `.env.local`, OS junk |
| `README.md` | 1 | User-facing docs |
| `LICENSE` | 1 | CC-BY-NC-SA 2.0 + modifications stanza |
| `CREDITS.md` | 1 | Full attribution chain |
| `scripts/deploy.sh` | 2 | Sync/restart/log/screenshot dev loop |
| `.env.local.example` | 2 | Template for device overrides |
| `art/wave/wave.png` | 5 | Wave background image (from source) |
| `art/ui/*` | 5 | Selector, separators (from source) |
| `fonts/*` | 5 | 3 weights (from source) |
| `sounds/*` | 5 | navigate/select/back (from source) |
| `art/system-icons/*.png` | 6 | System icons, renamed to Batocera shortnames |
| `theme.xml` | 7 | Entry point: formatVersion, includes, subset declaration |
| `_inc/common.xml` | 8 | Shared variables, fonts, sounds, helpsystem base |
| `_inc/system.xml` | 9 | System view (PSP top row + wave) |
| `colors/psp-*.xml` | 10 | Twelve colorset files |
| `_inc/gamelist.xml` | 11 | Detailed view (textlist + art panel) |
| `_inc/gamelist.xml` (edited) | 12 | Add frozen system bar (or single-icon fallback) |
| `_inc/menu.xml` | 13 | Batocera menu theming pass |
| `_inc/system.xml`, `_inc/gamelist.xml` (edited) | 14 | Wave storyboard animation |
| (screenshots in README) | 15 | v0.1 release |

---

### Task 1: Repo meta files (README, LICENSE, CREDITS, .gitignore)

**Files:**
- Create: `.gitignore`
- Create: `README.md`
- Create: `LICENSE`
- Create: `CREDITS.md`

- [ ] **Step 1: Create `.gitignore`**

Write `.gitignore`:

```
# dev workflow scratch
.dev/

# local config overrides
.env.local

# macOS
.DS_Store

# editor swap files
*.swp
*~
```

- [ ] **Step 2: Create `README.md`**

Write `README.md`:

```markdown
# es-theme-xmb-psp

A PSP XMB-style theme for [batocera-emulationstation](https://github.com/batocera-linux/batocera-emulationstation), built and tuned for **Knulli Scarab on the TrimUI Brick** (4:3, 1024×768).

> Status: PSP-style variant only. 4:3 only. Twelve user-selectable PSP-month colorsets.

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
4. Pick a colorset: **UI Settings → Theme Configuration → PSP Color → choose one**.
5. Restart EmulationStation: **Main Menu → Quit → Restart Emulation Station**.

## Compatibility

- **Tested:** Knulli Scarab on TrimUI Brick (4:3, 1024×768).
- **Likely works:** any Batocera/Knulli device at 4:3 running batocera-emulationstation with `formatVersion 7` support. Other aspect ratios will letterbox or stretch.

## Customization

The only configurable knob is colorset (PSP-authentic month-tinted palettes). Change it under **UI Settings → Theme Configuration → PSP Color**. No per-system or per-device overrides — the theme intentionally ships minimal.

## Troubleshooting

If the theme breaks EmulationStation on startup, SSH still works. To force Batocera back to the built-in `carbon` theme:

```
ssh root@<your-device-ip> 'batocera-settings-set theme.set carbon && batocera-es-swissknife --restart'
```

## Credits and license

This is a derivative work. See [CREDITS.md](CREDITS.md) for the full attribution chain.

Licensed under **Creative Commons CC-BY-NC-SA 2.0** — see [LICENSE](LICENSE). You may share and adapt this theme for non-commercial purposes, must credit the upstream authors, and must license derivatives under the same terms.
```

- [ ] **Step 3: Create `LICENSE`**

Fetch the canonical CC-BY-NC-SA 2.0 legal text from the source theme's LICENSE file (the lineage uses the same license):

```bash
curl -fsSL https://raw.githubusercontent.com/anthonycaccese/xmb-menu-es-de/main/LICENSE -o LICENSE
```

If the source repo doesn't have a LICENSE file at that path, fall back to:

```bash
curl -fsSL https://creativecommons.org/licenses/by-nc-sa/2.0/legalcode.txt -o LICENSE
```

Then append the modifications stanza. Open `LICENSE`, scroll to the end, and add a blank line then this block:

```
====

This work is a derivative of "XMB Menu ES-DE" by Ant (anthonycaccese),
licensed under CC-BY-NC-SA 2.0 — https://github.com/anthonycaccese/xmb-menu-es-de
itself derived from "XMB-Easy-Theme" by InitialDin.

Modifications by Barret Storck (2026-): port to batocera-emulationstation
(Knulli Scarab on TrimUI Brick); XML rewrite; restricted to single
variant and 4:3 layout; colorset subset model.

Derivative is also licensed under CC-BY-NC-SA 2.0.
```

- [ ] **Step 4: Create `CREDITS.md`**

Write `CREDITS.md`:

```markdown
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
| System icons | XMB Menu ES-DE | Ant — CC-BY-NC-SA 2.0 |
| UI chrome (selector, separators) | XMB Menu ES-DE | Ant — CC-BY-NC-SA 2.0 |
| Sound effects | XMB Menu ES-DE | Ant — CC-BY-NC-SA 2.0 |
| Fonts | XMB Menu ES-DE | _(per-font license verified in Task 5; see notes below)_ |

## Not yet used (would re-add credit if included later)

- **Physical media icons** — RetroArch XMB monochrome theme contributors. (Not currently in any view.)
- **Controller icons** — RobZombie9043. (Not currently in any view.)
```

- [ ] **Step 5: Commit**

```bash
git add .gitignore README.md LICENSE CREDITS.md
git commit -m "Add repo meta files (README, LICENSE, CREDITS, .gitignore)"
```

---

### Task 2: Dev workflow script (`scripts/deploy.sh`)

**Files:**
- Create: `scripts/deploy.sh`
- Create: `.env.local.example`

- [ ] **Step 1: Create `scripts/deploy.sh`**

```bash
mkdir -p scripts
```

Write `scripts/deploy.sh` with the following content:

```bash
#!/usr/bin/env bash
set -euo pipefail

# Defaults (override via env or .env.local at repo root)
DEVICE_IP="${DEVICE_IP:-192.168.1.4}"
DEVICE_USER="${DEVICE_USER:-root}"
THEME_NAME="${THEME_NAME:-es-theme-xmb-psp}"

if [[ -f .env.local ]]; then
  set -a
  # shellcheck disable=SC1091
  source .env.local
  set +a
fi

DEVICE="${DEVICE_USER}@${DEVICE_IP}"
THEME_PATH="/userdata/themes/${THEME_NAME}/"

usage() {
  cat <<EOF
Usage: $(basename "$0") <subcommand>

Subcommands:
  sync       rsync theme files to device
  restart    restart EmulationStation on device
  push       sync + restart  (deploy a change end-to-end)
  logs       tail ES log on device
  shot       capture a screenshot, pull to .dev/last-shot.png
  shell      interactive SSH session
  setup      one-time: ssh-copy-id for passwordless access
  fallback   force device back to built-in 'carbon' theme

Config (env or .env.local at repo root):
  DEVICE_IP    (current: $DEVICE_IP)
  DEVICE_USER  (current: $DEVICE_USER)
  THEME_NAME   (current: $THEME_NAME)
EOF
}

cmd="${1:-}"
case "$cmd" in
  sync)
    rsync -avz --delete \
      --exclude='.git' \
      --exclude='docs' \
      --exclude='scripts' \
      --exclude='.dev' \
      --exclude='.env.local' \
      --exclude='.env.local.example' \
      --exclude='.gitignore' \
      --exclude='README.md' \
      --exclude='CREDITS.md' \
      --exclude='LICENSE' \
      ./ "${DEVICE}:${THEME_PATH}"
    ;;
  restart)
    ssh "${DEVICE}" 'batocera-es-swissknife --restart'
    ;;
  push)
    "$0" sync
    "$0" restart
    ;;
  logs)
    ssh "${DEVICE}" 'tail -f /userdata/system/logs/es_log.txt'
    ;;
  shot)
    mkdir -p .dev
    ssh "${DEVICE}" 'batocera-screenshot'
    sleep 1
    latest=$(ssh "${DEVICE}" 'ls -t /userdata/screenshots/ 2>/dev/null | head -1')
    if [[ -z "$latest" ]]; then
      echo "No screenshots found on device" >&2
      exit 1
    fi
    scp "${DEVICE}:/userdata/screenshots/${latest}" .dev/last-shot.png
    echo "Saved .dev/last-shot.png (was ${latest} on device)"
    ;;
  shell)
    ssh "${DEVICE}"
    ;;
  setup)
    ssh-copy-id "${DEVICE}"
    ;;
  fallback)
    ssh "${DEVICE}" 'batocera-settings-set theme.set carbon && batocera-es-swissknife --restart'
    ;;
  -h|--help|"")
    usage
    ;;
  *)
    echo "Unknown subcommand: $cmd" >&2
    usage
    exit 1
    ;;
esac
```

Then make it executable:

```bash
chmod +x scripts/deploy.sh
```

- [ ] **Step 2: Create `.env.local.example`**

Write `.env.local.example`:

```
# Copy this to .env.local to override defaults.
# .env.local is gitignored.

DEVICE_IP=192.168.1.4
DEVICE_USER=root
THEME_NAME=es-theme-xmb-psp
```

- [ ] **Step 3: Smoke test — usage prints**

Run: `./scripts/deploy.sh --help`

Expected output: the usage block printing all subcommands, ending with the config block showing `DEVICE_IP: 192.168.1.4`, etc. Exit code 0.

- [ ] **Step 4: Commit**

```bash
git add scripts/deploy.sh .env.local.example
git commit -m "Add scripts/deploy.sh dev workflow"
```

---

### Task 3: First contact with the device

**Files:** none modified — this is a connectivity verification task.

- [ ] **Step 1: Set up SSH key**

Run: `./scripts/deploy.sh setup`

When prompted for the password, type `linux`.

Expected: "Number of key(s) added: 1" message.

If this fails (e.g. ssh-copy-id not found), fall back to:
```bash
ssh root@192.168.1.4 'mkdir -p ~/.ssh && cat >> ~/.ssh/authorized_keys' < ~/.ssh/id_*.pub
```

- [ ] **Step 2: Verify passwordless SSH**

Run: `ssh root@192.168.1.4 'uname -a; batocera-es-swissknife --version 2>/dev/null || echo "swissknife exists: $(command -v batocera-es-swissknife || echo no)"'`

Expected: kernel/uname info plus either a version string or a "swissknife exists: /usr/bin/batocera-es-swissknife"-ish line. **No password prompt.**

- [ ] **Step 3: First sync (creates empty theme dir on device)**

Run: `./scripts/deploy.sh sync`

Expected: rsync output showing zero files transferred (we have nothing to sync yet, just `.gitignore`/README which are excluded). The directory `/userdata/themes/es-theme-xmb-psp/` is created on the device.

Verify directly:
```bash
ssh root@192.168.1.4 'ls -la /userdata/themes/es-theme-xmb-psp/ 2>&1 | head -5'
```

Expected: directory listing with at least `.` and `..` present.

- [ ] **Step 4: Test screenshot pull**

Run: `./scripts/deploy.sh shot`

Expected: a PNG file appears at `.dev/last-shot.png` on the Mac. Open it (`open .dev/last-shot.png`). It should show the device's current screen (whatever theme is currently loaded — likely a stock Knulli theme, since ours has no theme.xml yet).

No commit. This is a connectivity gate, not a code change.

---

### Task 4: Clone source theme and inventory assets

**Files:** none in our repo — staging only.

- [ ] **Step 1: Clone source to scratch directory**

```bash
mkdir -p .dev/source
git clone --depth=1 https://github.com/anthonycaccese/xmb-menu-es-de.git .dev/source/xmb-menu-es-de
```

`.dev/` is gitignored, so the clone won't be committed.

- [ ] **Step 2: Inventory source's resource directories**

Run:
```bash
ls -la .dev/source/xmb-menu-es-de/
find .dev/source/xmb-menu-es-de -type d | head -30
```

Expected: see directories matching the spec — `_inc`, `resources`, `theme-customizations`, plus aspect-ratio XMLs. Note the actual paths for wave, fonts, sounds, system icons (the spec's paths like `resources/wave/` are best-guess and may differ slightly).

- [ ] **Step 3: Read the source's LICENSE and any per-font NOTICE files**

```bash
cat .dev/source/xmb-menu-es-de/LICENSE 2>/dev/null || echo "(no LICENSE at root)"
find .dev/source/xmb-menu-es-de -iname "*license*" -o -iname "*notice*" -o -iname "*readme*" | head -20
```

Make notes of any per-font license files. These get reflected in `CREDITS.md` in Task 5.

No commit yet.

---

### Task 5: Copy wave, UI chrome, fonts, and sounds from source

**Files:**
- Create: `art/wave/wave.png` (and any companion files)
- Create: `art/ui/*` (selector, separators)
- Create: `fonts/*`
- Create: `sounds/*`
- Modify: `CREDITS.md` (per-font licenses)

- [ ] **Step 1: Create destination directories**

```bash
mkdir -p art/wave art/ui art/system-icons fonts sounds
```

(`art/system-icons/` is for Task 6.)

- [ ] **Step 2: Copy the wave background asset(s)**

Locate the wave file(s) in the source (Task 4's inventory should have shown the path). Common locations: `resources/wave/`, `_inc/`, or a top-level `wave.png`. Copy:

```bash
# Adjust source path to whatever the inventory revealed
cp .dev/source/xmb-menu-es-de/resources/wave/*.png art/wave/ 2>/dev/null \
  || cp .dev/source/xmb-menu-es-de/_inc/wave*.png art/wave/ 2>/dev/null \
  || echo "Wave not found — check inventory and adjust path"
ls -la art/wave/
```

Expected: at least one PNG in `art/wave/`. If multiple, keep them all (some may be alternate styles).

- [ ] **Step 3: Copy UI chrome (selectors, separators)**

```bash
# Adjust to actual inventory paths
cp -r .dev/source/xmb-menu-es-de/resources/ui/* art/ui/ 2>/dev/null \
  || cp -r .dev/source/xmb-menu-es-de/resources/selectors/* art/ui/ 2>/dev/null \
  || echo "UI chrome not found at expected paths — inspect source structure"
ls -la art/ui/
```

- [ ] **Step 4: Copy fonts**

```bash
cp -r .dev/source/xmb-menu-es-de/resources/fonts/* fonts/
ls -la fonts/
```

- [ ] **Step 5: Verify per-font licensing**

For each font file in `fonts/`, identify the font name and check its license. The source repo may include `.txt` / `.md` files describing fonts; if not, look up each font by name (Google Fonts, Font Squirrel, the source's README/CREDITS).

Common families used in PSP-style themes:
- **SCE-PS3** (proprietary Sony font — **do not redistribute**; substitute an SIL OFL look-alike like "Saira Semi Condensed" or "Sansation")
- **Liberation Sans**, **DejaVu Sans** (SIL OFL — redistributable)
- **Open Sans**, **Roboto** (SIL OFL / Apache 2.0 — redistributable)

If any font is proprietary (e.g., SCE-PS3), **delete it from `fonts/` and substitute an OFL alternative**. Update Task 8's font variable references accordingly.

Make notes of each font's license — they go in Step 7 below.

- [ ] **Step 6: Copy sound effects**

```bash
cp -r .dev/source/xmb-menu-es-de/resources/sounds/* sounds/
ls -la sounds/
```

Expected: at least three sounds matching navigate/select/back patterns. Note the actual filenames (e.g., `select.wav`, `back.wav`, `move.wav`); they get referenced in Task 8.

- [ ] **Step 7: Update `CREDITS.md` with per-font licenses**

Open `CREDITS.md` and replace the fonts table row with concrete per-font entries. Example (adjust to actual fonts):

Find:
```markdown
| Fonts | XMB Menu ES-DE | _(per-font license verified in Task 5; see notes below)_ |
```

Replace with:
```markdown
| Font: [Saira Semi Condensed Regular] | Google Fonts (SIL OFL 1.1) | Omnibus-Type — SIL OFL 1.1 |
| Font: [Saira Semi Condensed Light]   | Google Fonts (SIL OFL 1.1) | Omnibus-Type — SIL OFL 1.1 |
| Font: [Saira Semi Condensed Bold]    | Google Fonts (SIL OFL 1.1) | Omnibus-Type — SIL OFL 1.1 |
```

(Substitute the actual font names you ended up with.)

- [ ] **Step 8: Commit**

```bash
git add art/ fonts/ sounds/ CREDITS.md
git commit -m "Import wave, UI chrome, fonts, and sounds from source theme"
```

---

### Task 6: Copy and rename system icons to Batocera shortnames

**Files:**
- Create: `art/system-icons/*.png` (or `.svg`)

- [ ] **Step 1: Inventory source's system icons**

```bash
ls .dev/source/xmb-menu-es-de/resources/systems/ 2>/dev/null \
  || ls .dev/source/xmb-menu-es-de/_inc/systems/ 2>/dev/null \
  || find .dev/source/xmb-menu-es-de -iname "*system*" -type d
```

Note the directory and the file extension (most likely `.svg` or `.png`). Capture the full list of system icon filenames.

- [ ] **Step 2: Fetch Batocera's system shortname list**

```bash
ssh root@192.168.1.4 'ls /usr/share/batocera/datainit/system/configgen/data/ 2>/dev/null | head -40 \
  || ls /etc/emulationstation/es_systems.cfg 2>/dev/null \
  || grep -oE "<name>[^<]+</name>" /etc/emulationstation/es_systems.cfg 2>/dev/null | head -40'
```

Or simpler — list the directories under `/userdata/roms/` (each is a Batocera system shortname the device knows about):

```bash
ssh root@192.168.1.4 'ls /userdata/roms/ 2>/dev/null'
```

Capture this list. It's the authoritative set of system shortnames we need icons for.

- [ ] **Step 3: Copy and rename icons**

Bulk-copy with rename, using the divergence map from the spec:

```bash
SRC=".dev/source/xmb-menu-es-de/resources/systems"
DST="art/system-icons"

# Direct copies (same name in ES-DE and Batocera)
for name in nes snes n64 psx psp gba gbc gameboy genesis sega32x segacd mastersystem gamegear dreamcast saturn neogeo arcade atari2600 atari7800 atarilynx ; do
  if [[ -f "$SRC/$name.svg" ]]; then
    cp "$SRC/$name.svg" "$DST/$name.svg"
  elif [[ -f "$SRC/$name.png" ]]; then
    cp "$SRC/$name.png" "$DST/$name.png"
  fi
done

# ES-DE → Batocera renames
declare -A renames=(
  [genesis]=megadrive
  [gameboyadvance]=gba
  [gameboycolor]=gbc
  [nintendo64]=n64
)
for esde in "${!renames[@]}"; do
  bat="${renames[$esde]}"
  for ext in svg png ; do
    if [[ -f "$SRC/$esde.$ext" ]]; then
      cp "$SRC/$esde.$ext" "$DST/$bat.$ext"
    fi
  done
done
```

Run this. Expected: `art/system-icons/` populated with the systems present in both source and Batocera. Verify:
```bash
ls art/system-icons/
```

- [ ] **Step 4: Reconcile against the device's actual systems**

Compare the icons we have against the device's installed systems (from Step 2). For systems the device has but we lack an icon for, batocera-ES will fall back to its built-in generic icon — that's acceptable per the spec. For systems we have icons for but the device doesn't, the icons sit unused — also fine; leave them in case the user adds roms later.

No action required unless you spot something obviously wrong (e.g., zero icons copied).

- [ ] **Step 5: Commit**

```bash
git add art/system-icons/
git commit -m "Import and rename system icons (ES-DE -> Batocera shortnames)"
```

---

### Task 7: Minimal `theme.xml` that loads

**Files:**
- Create: `theme.xml`

- [ ] **Step 1: Write minimal `theme.xml`**

Write `theme.xml`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!--
  es-theme-xmb-psp - PSP XMB theme for batocera-emulationstation
  Derivative of "XMB Menu ES-DE" by Ant (anthonycaccese), itself derived
  from "XMB-Easy-Theme" by InitialDin. CC-BY-NC-SA 2.0.
  Full attribution: see CREDITS.md
-->
<theme>
  <formatVersion>7</formatVersion>

  <!-- Includes will be uncommented in later tasks. -->
  <!-- <include>./_inc/common.xml</include> -->
  <!-- <include>./_inc/system.xml</include> -->
  <!-- <include>./_inc/gamelist.xml</include> -->
  <!-- <include>./_inc/menu.xml</include> -->

  <!-- Empty stub views so ES has something to parse. -->
  <view name="system">
    <text name="placeholder">
      <text>es-theme-xmb-psp loaded</text>
      <pos>0.4 0.45</pos>
      <size>0.2 0.1</size>
      <color>ffffffff</color>
    </text>
  </view>

  <view name="detailed">
    <text name="placeholder">
      <text>(gamelist not yet implemented)</text>
      <pos>0.3 0.45</pos>
      <size>0.4 0.1</size>
      <color>ffffffff</color>
    </text>
  </view>
</theme>
```

- [ ] **Step 2: Deploy and verify it loads cleanly**

Run: `./scripts/deploy.sh push`

Expected: rsync succeeds, restart command issued.

On the device (via SSH or via the Brick's screen): in EmulationStation, select **UI Settings → Theme Set → es-theme-xmb-psp**, then restart ES.

- [ ] **Step 3: Inspect log for parse errors**

Run: `ssh root@192.168.1.4 'grep -iE "error|warn" /userdata/system/logs/es_log.txt | tail -30'`

Expected: no errors or warnings mentioning `es-theme-xmb-psp`, `theme.xml`, or any of our files. (Other unrelated warnings from Batocera are okay.)

If there are theme-related errors, fix the XML and re-push. Common issues: bad `<pos>` / `<size>` ranges (must be 0.0–1.0), missing closing tags.

- [ ] **Step 4: Visual confirmation**

Run: `./scripts/deploy.sh shot && open .dev/last-shot.png`

Expected: the screen shows the "es-theme-xmb-psp loaded" placeholder text on a default background (no wave yet, no carousel — that's expected).

- [ ] **Step 5: Commit**

```bash
git add theme.xml
git commit -m "Add minimal theme.xml that loads cleanly on Batocera"
```

---

### Task 8: `_inc/common.xml` — shared variables, fonts, sounds, helpsystem

**Files:**
- Create: `_inc/common.xml`
- Modify: `theme.xml` (uncomment the include)

- [ ] **Step 1: Create `_inc/common.xml`**

```bash
mkdir -p _inc
```

Write `_inc/common.xml` (adjust the font filenames and sound filenames to what you actually have in `fonts/` and `sounds/` from Task 5):

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!--
  es-theme-xmb-psp - shared variables, fonts, sounds, helpsystem base.
  CC-BY-NC-SA 2.0. See CREDITS.md.
-->
<theme>
  <formatVersion>7</formatVersion>

  <!-- Default colorset values; overridden by any selected colorset file. -->
  <variables>
    <waveTint>FFFFFF</waveTint>
    <accent>3B82F6</accent>
    <textPrimary>FFFFFF</textPrimary>
    <textSecondary>B0C4DE</textSecondary>
    <selectorGlow>60A5FA</selectorGlow>
    <helpAccent>93C5FD</helpAccent>

    <fontLight>./fonts/SairaSemiCondensed-Light.ttf</fontLight>
    <fontRegular>./fonts/SairaSemiCondensed-Regular.ttf</fontRegular>
    <fontBold>./fonts/SairaSemiCondensed-Bold.ttf</fontBold>

    <soundNavigate>./sounds/navigate.wav</soundNavigate>
    <soundSelect>./sounds/select.wav</soundSelect>
    <soundBack>./sounds/back.wav</soundBack>
  </variables>

  <view name="system,detailed,menu">
    <!-- Sounds (replace ES default click sounds) -->
    <sound name="systemscroll">
      <path>${soundNavigate}</path>
    </sound>
    <sound name="scroll">
      <path>${soundNavigate}</path>
    </sound>
    <sound name="select">
      <path>${soundSelect}</path>
    </sound>
    <sound name="back">
      <path>${soundBack}</path>
    </sound>

    <!-- Helpsystem styling shared across all views -->
    <helpsystem name="help">
      <pos>0.02 0.94</pos>
      <textColor>${textPrimary}</textColor>
      <iconColor>${helpAccent}</iconColor>
      <fontPath>${fontRegular}</fontPath>
      <fontSize>0.025</fontSize>
    </helpsystem>
  </view>
</theme>
```

- [ ] **Step 2: Wire include into `theme.xml`**

Edit `theme.xml`: uncomment the `<!-- <include>./_inc/common.xml</include> -->` line so it becomes:

```xml
<include>./_inc/common.xml</include>
```

- [ ] **Step 3: Deploy and verify**

```bash
./scripts/deploy.sh push
ssh root@192.168.1.4 'grep -iE "error|warn" /userdata/system/logs/es_log.txt | tail -30'
```

Expected: no parse errors. The "es-theme-xmb-psp loaded" text still shows, now in the configured font (if the font file is found). If you hear different navigation sounds, even better.

Common failure: a font or sound path is wrong. The log will say "Could not find file: ./fonts/...". Fix the variable in `_inc/common.xml` to match the actual filename in `fonts/`, then re-push.

- [ ] **Step 4: Commit**

```bash
git add _inc/common.xml theme.xml
git commit -m "Add _inc/common.xml with shared variables, fonts, sounds, helpsystem"
```

---

### Task 9: `_inc/system.xml` — system view (wave + carousel + clock + helpsystem)

**Files:**
- Create: `_inc/system.xml`
- Modify: `theme.xml` (uncomment include, remove placeholder)

- [ ] **Step 1: Write `_inc/system.xml`**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!--
  es-theme-xmb-psp - system view (PSP XMB top row + wave background).
  CC-BY-NC-SA 2.0. See CREDITS.md.
-->
<theme>
  <formatVersion>7</formatVersion>

  <view name="system">

    <!-- Animated wave background (storyboard added in Task 14). -->
    <image name="waveBackground" extra="true">
      <path>./art/wave/wave.png</path>
      <pos>0 0</pos>
      <size>1 1</size>
      <color>${waveTint}</color>
      <zIndex>0</zIndex>
    </image>

    <!-- Top-right clock, PSP-style (24h, time only). -->
    <datetime name="clock" extra="true">
      <pos>0.88 0.03</pos>
      <size>0.10 0.04</size>
      <fontPath>${fontRegular}</fontPath>
      <fontSize>0.030</fontSize>
      <color>${textPrimary}</color>
      <format>%H:%M</format>
      <horizontalAlignment>right</horizontalAlignment>
      <zIndex>10</zIndex>
    </datetime>

    <!-- Horizontal carousel of system icons (PSP "category row"), upper third. -->
    <carousel name="systemcarousel">
      <type>horizontal</type>
      <pos>0 0.20</pos>
      <size>1 0.30</size>
      <color>00000000</color>
      <logoSize>0.10 0.14</logoSize>
      <logoScale>1.5</logoScale>
      <logoRotation>0</logoRotation>
      <logoAlignment>center</logoAlignment>
      <maxLogoCount>7</maxLogoCount>
      <zIndex>5</zIndex>
    </carousel>

    <!-- Selected system name caption, just below carousel. -->
    <text name="systemInfo">
      <pos>0 0.50</pos>
      <size>1 0.06</size>
      <fontPath>${fontBold}</fontPath>
      <fontSize>0.045</fontSize>
      <color>${textPrimary}</color>
      <alignment>center</alignment>
      <zIndex>5</zIndex>
    </text>

  </view>
</theme>
```

- [ ] **Step 2: Wire include into `theme.xml`**

Edit `theme.xml`:
- Uncomment `<include>./_inc/system.xml</include>`
- **Delete** the `<view name="system">` placeholder block — `_inc/system.xml` now owns it.

After edit, `theme.xml` should look like:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!--
  es-theme-xmb-psp - PSP XMB theme for batocera-emulationstation
  Derivative of "XMB Menu ES-DE" by Ant (anthonycaccese), itself derived
  from "XMB-Easy-Theme" by InitialDin. CC-BY-NC-SA 2.0.
  Full attribution: see CREDITS.md
-->
<theme>
  <formatVersion>7</formatVersion>

  <include>./_inc/common.xml</include>
  <include>./_inc/system.xml</include>
  <!-- <include>./_inc/gamelist.xml</include> -->
  <!-- <include>./_inc/menu.xml</include> -->

  <view name="detailed">
    <text name="placeholder">
      <text>(gamelist not yet implemented)</text>
      <pos>0.3 0.45</pos>
      <size>0.4 0.1</size>
      <color>ffffffff</color>
    </text>
  </view>
</theme>
```

- [ ] **Step 3: Deploy and verify**

```bash
./scripts/deploy.sh push
ssh root@192.168.1.4 'grep -iE "error|warn" /userdata/system/logs/es_log.txt | tail -30'
./scripts/deploy.sh shot && open .dev/last-shot.png
```

Expected: screen shows a full-screen white-tinted wave background (static, since storyboard comes in Task 14), a clock in the top-right, and a horizontal row of system icons across the upper third. Use the d-pad on the device to scroll left/right — different system icons should highlight, and the system name caption below the carousel should update.

- [ ] **Step 4: Tune (likely needed)**

Numbers in Step 1 are best-guess starting points. After visual inspection, you may need to adjust:
- `<logoSize>` if icons are too small/large.
- `<pos>` / `<size>` on the carousel if it sits too high or too low.
- `<fontSize>` on the caption.

Adjust, `./scripts/deploy.sh push`, re-screenshot until it looks right. **Don't spend more than 15 minutes on aesthetic tuning at this stage** — there's more functionality to add first. Lock when it's recognizably PSP-row-shaped, then move on.

- [ ] **Step 5: Commit**

```bash
git add _inc/system.xml theme.xml
git commit -m "Add _inc/system.xml (wave background + system carousel + clock)"
```

---

### Task 10: Twelve colorset XML files + subset declaration

**Files:**
- Create: `colors/psp-jan-blue.xml` through `colors/psp-dec-aqua.xml` (12 files)
- Modify: `theme.xml` (add `<subset>` declaration)

- [ ] **Step 1: Create the `colors/` directory and one colorset**

```bash
mkdir -p colors
```

Write `colors/psp-jan-blue.xml`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!--
  es-theme-xmb-psp - colorset "January Blue" (PSP default).
  CC-BY-NC-SA 2.0. See CREDITS.md.
-->
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

- [ ] **Step 2: Create the other eleven**

Write each file in `colors/` with the same structure, only the hex values changing. Use these PSP-month palettes (each row is a colorset's tint values):

| Filename | waveTint | accent | textSecondary | selectorGlow | helpAccent |
|---|---|---|---|---|---|
| `psp-jan-blue.xml` | `1E3A8A` | `3B82F6` | `B0C4DE` | `60A5FA` | `93C5FD` |
| `psp-feb-violet.xml` | `4C1D95` | `8B5CF6` | `C4B5FD` | `A78BFA` | `C4B5FD` |
| `psp-mar-pink.xml` | `9D174D` | `EC4899` | `FBCFE8` | `F472B6` | `FBCFE8` |
| `psp-apr-green.xml` | `14532D` | `22C55E` | `BBF7D0` | `4ADE80` | `BBF7D0` |
| `psp-may-yellowgreen.xml` | `3F6212` | `84CC16` | `D9F99D` | `A3E635` | `D9F99D` |
| `psp-jun-yellow.xml` | `78350F` | `EAB308` | `FEF08A` | `FACC15` | `FEF08A` |
| `psp-jul-amber.xml` | `7C2D12` | `F59E0B` | `FED7AA` | `FBBF24` | `FED7AA` |
| `psp-aug-orange.xml` | `9A3412` | `F97316` | `FED7AA` | `FB923C` | `FED7AA` |
| `psp-sep-red.xml` | `7F1D1D` | `EF4444` | `FCA5A5` | `F87171` | `FCA5A5` |
| `psp-oct-crimson.xml` | `881337` | `E11D48` | `FECDD3` | `FB7185` | `FECDD3` |
| `psp-nov-slate.xml` | `334155` | `64748B` | `CBD5E1` | `94A3B8` | `CBD5E1` |
| `psp-dec-aqua.xml` | `134E4A` | `14B8A6` | `99F6E4` | `2DD4BF` | `99F6E4` |

For each row, copy the structure from `psp-jan-blue.xml`, swap the five variables, and update the comment with the colorset name.

- [ ] **Step 3: Declare the subset in `theme.xml`**

Edit `theme.xml`. After `<formatVersion>7</formatVersion>`, before the existing `<include>` lines, add:

```xml
  <subset name="colorset" displayName="PSP Color">
    <include name="January Blue">./colors/psp-jan-blue.xml</include>
    <include name="February Violet">./colors/psp-feb-violet.xml</include>
    <include name="March Pink">./colors/psp-mar-pink.xml</include>
    <include name="April Green">./colors/psp-apr-green.xml</include>
    <include name="May Yellow-Green">./colors/psp-may-yellowgreen.xml</include>
    <include name="June Yellow">./colors/psp-jun-yellow.xml</include>
    <include name="July Amber">./colors/psp-jul-amber.xml</include>
    <include name="August Orange">./colors/psp-aug-orange.xml</include>
    <include name="September Red">./colors/psp-sep-red.xml</include>
    <include name="October Crimson">./colors/psp-oct-crimson.xml</include>
    <include name="November Slate">./colors/psp-nov-slate.xml</include>
    <include name="December Aqua">./colors/psp-dec-aqua.xml</include>
  </subset>
```

- [ ] **Step 4: Deploy and verify subset appears in UI**

```bash
./scripts/deploy.sh push
```

On the device: **Main Menu → UI Settings → Theme Configuration**. Expected: a new option "PSP Color" appears with a dropdown of all twelve names.

- [ ] **Step 5: Smoke-test color switching**

Switch to "March Pink", confirm the wave background turns pinkish (since the wave's `<color>` is `${waveTint}`). Switch to "August Orange", confirm it changes again.

If colors don't change visibly, the most likely cause is that the wave image is fully opaque and the `<color>` tint isn't taking effect — `<color>` only tints non-opaque parts. Workaround: ensure the wave PNG has alpha (transparent background). If it doesn't, swap to a wave PNG with proper alpha (the source may have a "wave_mask" variant).

- [ ] **Step 6: Commit**

```bash
git add colors/ theme.xml
git commit -m "Add twelve PSP-month colorsets surfaced via Batocera subset"
```

---

### Task 11: `_inc/gamelist.xml` — detailed view (textlist + art panel + metadata)

**Files:**
- Create: `_inc/gamelist.xml`
- Modify: `theme.xml` (uncomment include, remove placeholder)

This task implements gamelist *without* the frozen system bar. Task 12 adds the frozen bar (or its fallback).

- [ ] **Step 1: Write `_inc/gamelist.xml`**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!--
  es-theme-xmb-psp - detailed view (gamelist).
  CC-BY-NC-SA 2.0. See CREDITS.md.
-->
<theme>
  <formatVersion>7</formatVersion>

  <view name="detailed">

    <!-- Same wave background as system view -->
    <image name="waveBackground" extra="true">
      <path>./art/wave/wave.png</path>
      <pos>0 0</pos>
      <size>1 1</size>
      <color>${waveTint}</color>
      <zIndex>0</zIndex>
    </image>

    <!-- Top-right clock -->
    <datetime name="clock" extra="true">
      <pos>0.88 0.03</pos>
      <size>0.10 0.04</size>
      <fontPath>${fontRegular}</fontPath>
      <fontSize>0.030</fontSize>
      <color>${textPrimary}</color>
      <format>%H:%M</format>
      <horizontalAlignment>right</horizontalAlignment>
      <zIndex>10</zIndex>
    </datetime>

    <!-- Game list (left half) -->
    <textlist name="gamelist">
      <pos>0.04 0.22</pos>
      <size>0.45 0.65</size>
      <fontPath>${fontRegular}</fontPath>
      <fontSize>0.035</fontSize>
      <horizontalMargin>0.02</horizontalMargin>
      <alignment>left</alignment>
      <primaryColor>${textSecondary}</primaryColor>
      <secondaryColor>${textSecondary}</secondaryColor>
      <selectorColor>${selectorGlow}</selectorColor>
      <selectorImagePath>./art/ui/selector.png</selectorImagePath>
      <selectorImageTile>false</selectorImageTile>
      <selectedColor>${textPrimary}</selectedColor>
      <lineSpacing>1.3</lineSpacing>
      <zIndex>5</zIndex>
    </textlist>

    <!-- Right panel: boxart -->
    <image name="md_image">
      <pos>0.55 0.22</pos>
      <maxSize>0.40 0.40</maxSize>
      <color>FFFFFFFF</color>
      <zIndex>5</zIndex>
    </image>

    <!-- Right panel: metadata labels and values -->
    <text name="md_lbl_releasedate">
      <pos>0.55 0.66</pos>
      <size>0.20 0.04</size>
      <fontPath>${fontLight}</fontPath>
      <fontSize>0.025</fontSize>
      <color>${textSecondary}</color>
      <text>Released</text>
      <zIndex>5</zIndex>
    </text>
    <datetime name="md_releasedate">
      <pos>0.75 0.66</pos>
      <size>0.20 0.04</size>
      <fontPath>${fontRegular}</fontPath>
      <fontSize>0.025</fontSize>
      <color>${textPrimary}</color>
      <format>%Y</format>
      <zIndex>5</zIndex>
    </datetime>

    <text name="md_lbl_players">
      <pos>0.55 0.71</pos>
      <size>0.20 0.04</size>
      <fontPath>${fontLight}</fontPath>
      <fontSize>0.025</fontSize>
      <color>${textSecondary}</color>
      <text>Players</text>
      <zIndex>5</zIndex>
    </text>
    <text name="md_players">
      <pos>0.75 0.71</pos>
      <size>0.20 0.04</size>
      <fontPath>${fontRegular}</fontPath>
      <fontSize>0.025</fontSize>
      <color>${textPrimary}</color>
      <zIndex>5</zIndex>
    </text>

    <text name="md_lbl_rating">
      <pos>0.55 0.76</pos>
      <size>0.20 0.04</size>
      <fontPath>${fontLight}</fontPath>
      <fontSize>0.025</fontSize>
      <color>${textSecondary}</color>
      <text>Rating</text>
      <zIndex>5</zIndex>
    </text>
    <rating name="md_rating">
      <pos>0.75 0.76</pos>
      <size>0.15 0.04</size>
      <color>${accent}</color>
      <zIndex>5</zIndex>
    </rating>

  </view>
</theme>
```

- [ ] **Step 2: Wire include into `theme.xml`**

Edit `theme.xml`:
- Uncomment `<include>./_inc/gamelist.xml</include>`
- **Delete** the `<view name="detailed">` placeholder block.

- [ ] **Step 3: Deploy and verify**

```bash
./scripts/deploy.sh push
ssh root@192.168.1.4 'grep -iE "error|warn" /userdata/system/logs/es_log.txt | tail -30'
```

On the device: pick a system from the system view, press A (select). You should land in the gamelist view: wave + clock + textlist of games on the left, boxart and metadata on the right.

- [ ] **Step 4: Visual confirmation**

```bash
./scripts/deploy.sh shot && open .dev/last-shot.png
```

Tune `<pos>`/`<size>`/`<fontSize>` as needed. Same 15-minute tuning budget.

If `./art/ui/selector.png` doesn't exist (Task 5 may not have copied a matching file), the textlist will render without a selector image — that's fine for now, the `selectedColor` still highlights the row. Either drop the `selectorImagePath` line or substitute a real path once an asset exists.

- [ ] **Step 5: Commit**

```bash
git add _inc/gamelist.xml theme.xml
git commit -m "Add _inc/gamelist.xml (textlist + boxart + metadata, no system bar yet)"
```

---

### Task 12: Frozen system bar on gamelist (or fallback to single-icon anchor)

**Files:**
- Modify: `_inc/gamelist.xml`

The spec (§9) flags this as the technique with the highest implementation risk. **Try the frozen bar first; if it doesn't work cleanly, switch to the single-icon fallback.** Both options are documented below; pick one based on what works on the device.

- [ ] **Step 1: Inventory system shortnames currently on the device**

```bash
ssh root@192.168.1.4 'ls /userdata/roms/ | sort'
```

Capture this list — these are the shortnames you'll need icon entries for.

- [ ] **Step 2 (Option A — Frozen bar): Add per-system icon images to `_inc/gamelist.xml`**

Open `_inc/gamelist.xml`. Inside `<view name="detailed">`, **above** the existing `<textlist>` element, add a block of `<image>` entries — one per system on the device. Example (substitute the actual shortnames from Step 1):

```xml
    <!-- Frozen system bar at top (decorative, mirrors system view's carousel layout).
         The currently-active system gets an enlarged variant below. -->
    <image name="sysbar_nes" extra="true">
      <path>./art/system-icons/nes.png</path>
      <pos>0.06 0.05</pos>
      <maxSize>0.06 0.08</maxSize>
      <color>FFFFFF80</color>
      <zIndex>5</zIndex>
    </image>
    <image name="sysbar_snes" extra="true">
      <path>./art/system-icons/snes.png</path>
      <pos>0.14 0.05</pos>
      <maxSize>0.06 0.08</maxSize>
      <color>FFFFFF80</color>
      <zIndex>5</zIndex>
    </image>
    <!-- ... one entry per system, advancing pos.x by 0.08 each time ... -->

    <!-- Enlarged current-system icon (the "you are here" anchor).
         Drawn at higher zIndex so it occludes the small frozen icon for the same system. -->
    <image name="md_logo" extra="false">
      <pos>0.04 0.07</pos>
      <maxSize>0.10 0.12</maxSize>
      <color>${textPrimary}</color>
      <zIndex>7</zIndex>
    </image>
```

Notes:
- `md_logo` is a batocera-ES *metadata image* that ES auto-fills with the current system's logo when in gamelist view. We use it as the enlarged overlay.
- The small icons get a 50% alpha (`FFFFFF80`) so the active one stands out under `md_logo`.
- This is a hand-laid-out row. The spec calls out that maintenance (adding new systems) requires editing this list.
- **Match the file extension to what Task 6 produced.** If your icons in `art/system-icons/` are `.svg`, use `.svg` in the `<path>` lines instead of `.png`. The example block uses `.png` for readability.

Deploy and check (`./scripts/deploy.sh push && ./scripts/deploy.sh shot && open .dev/last-shot.png`). If the layout looks right and `md_logo` properly highlights the current system, **commit this as Option A** and skip Step 3.

If the layout is broken (e.g., `md_logo` doesn't render, or the small icons stack on top of each other, or batocera-ES errors on `extra="true"` for many images), **abandon Option A** and revert the changes (`git checkout _inc/gamelist.xml`). Proceed to Step 3.

- [ ] **Step 3 (Option B — Fallback): Single current-system icon top-left**

Open `_inc/gamelist.xml`. Inside `<view name="detailed">`, **above** the `<textlist>` element, add just one image:

```xml
    <!-- Current-system icon as "you are here" anchor, top-left. -->
    <image name="md_logo">
      <pos>0.04 0.05</pos>
      <maxSize>0.12 0.10</maxSize>
      <color>${textPrimary}</color>
      <zIndex>5</zIndex>
    </image>

    <!-- Current system name, to the right of the icon. -->
    <text name="md_name">
      <pos>0.18 0.07</pos>
      <size>0.40 0.06</size>
      <fontPath>${fontBold}</fontPath>
      <fontSize>0.035</fontSize>
      <color>${textPrimary}</color>
      <zIndex>5</zIndex>
    </text>
```

This is the fallback per spec §9. Smaller surface, no per-system entries needed.

- [ ] **Step 4: Deploy and verify whichever option was chosen**

```bash
./scripts/deploy.sh push
./scripts/deploy.sh shot && open .dev/last-shot.png
```

Visually confirm: in gamelist view, the current system is anchored visibly (either as the enlarged icon in a row of muted icons, or as a single icon + name in the top-left).

- [ ] **Step 5: Commit**

```bash
git add _inc/gamelist.xml
git commit -m "Add system-bar anchor to gamelist view"
```

In the commit message, note which option (A or B) you ended up with for future reference.

---

### Task 13: `_inc/menu.xml` — Batocera menu theming pass

**Files:**
- Create: `_inc/menu.xml`
- Modify: `theme.xml` (uncomment include)

- [ ] **Step 1: Write `_inc/menu.xml`**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!--
  es-theme-xmb-psp - menu view (Batocera settings dialogs themed lightly).
  CC-BY-NC-SA 2.0. See CREDITS.md.
-->
<theme>
  <formatVersion>7</formatVersion>

  <view name="menu">

    <!-- Dimmed wave background to avoid clashing with menu text. -->
    <image name="menuBackground" extra="true">
      <path>./art/wave/wave.png</path>
      <pos>0 0</pos>
      <size>1 1</size>
      <color>${waveTint}80</color>
      <zIndex>0</zIndex>
    </image>

    <menuText name="menuTitle">
      <fontPath>${fontBold}</fontPath>
      <fontSize>0.045</fontSize>
      <color>${textPrimary}</color>
    </menuText>

    <menuText name="menuTextSmall">
      <fontPath>${fontRegular}</fontPath>
      <fontSize>0.028</fontSize>
      <color>${textPrimary}</color>
      <selectedColor>${selectorGlow}</selectedColor>
      <selectorColor>${accent}</selectorColor>
    </menuText>

  </view>
</theme>
```

The `${waveTint}80` appends `80` (50% alpha) to the colorset's tint so the menu background is visibly dimmed.

- [ ] **Step 2: Wire include into `theme.xml`**

Uncomment the `<include>./_inc/menu.xml</include>` line.

- [ ] **Step 3: Deploy and verify**

```bash
./scripts/deploy.sh push
```

On the device: open Main Menu (typically the Start button). Expected: the menu background shows a dimmed wave (instead of solid black or the default Batocera menu background), text uses the theme font, selected items use the colorset accent.

If `<menuText>` elements aren't recognized by your batocera-ES version, batocera-ES will warn in the log and fall back to defaults. Check log:

```bash
ssh root@192.168.1.4 'grep -iE "error|warn" /userdata/system/logs/es_log.txt | tail -20'
```

If `<menuText>` is unsupported, remove those blocks — the dimmed wave background alone is enough to satisfy "Minimum effort to avoid visual clash" from the spec.

- [ ] **Step 4: Commit**

```bash
git add _inc/menu.xml theme.xml
git commit -m "Add _inc/menu.xml (light theming of Batocera menu dialogs)"
```

---

### Task 14: Wave storyboard animation

**Files:**
- Modify: `_inc/system.xml`
- Modify: `_inc/gamelist.xml`

This is intentionally last — animations are performance-sensitive on the Brick, and tuning them is easier once everything else is locked.

- [ ] **Step 1: Add storyboard to `_inc/system.xml`'s `waveBackground`**

Edit `_inc/system.xml`. Inside the `<image name="waveBackground" ...>` block, before the closing `</image>`, add:

```xml
      <storyboard event="activate">
        <animation property="pos" duration="4000" repeat="forever" autoReverse="true">
          <keyframe time="0">0 0</keyframe>
          <keyframe time="4000">-0.02 0.01</keyframe>
        </animation>
      </storyboard>
```

This drifts the wave by ~2% horizontally and 1% vertically over 4 seconds, reversing, repeating forever — a subtle PSP-wave-like motion.

- [ ] **Step 2: Add the same storyboard to `_inc/gamelist.xml`'s `waveBackground`**

Make the same change inside the `<image name="waveBackground" ...>` block in `_inc/gamelist.xml`. (Two separate XML elements, one per view; the spec acknowledges this.)

- [ ] **Step 3: Deploy and verify animation**

```bash
./scripts/deploy.sh push
```

On the device: enter system view, watch the wave background. It should drift subtly. Switch to gamelist view, watch again — same motion continues.

- [ ] **Step 4: Performance check**

The TrimUI Brick can drop frames under load. Enable Batocera's FPS overlay temporarily:

```bash
ssh root@192.168.1.4 'batocera-settings-set system.es.fpscounter 1 && batocera-es-swissknife --restart'
```

Look at the FPS counter on-device. Should be ~60 FPS in both views.

If FPS drops noticeably below 30 (visible stutter), **back off the animation**:
- Increase `duration` (slower = less per-frame work).
- Reduce the keyframe delta (less movement = simpler interpolation).
- As a last resort, remove the storyboard from `_inc/gamelist.xml` only (gamelist scene has more elements competing for GPU time).

Disable the FPS counter when done:
```bash
ssh root@192.168.1.4 'batocera-settings-set system.es.fpscounter 0 && batocera-es-swissknife --restart'
```

- [ ] **Step 5: Commit**

```bash
git add _inc/system.xml _inc/gamelist.xml
git commit -m "Add subtle wave storyboard animation to system and gamelist views"
```

---

### Task 15: README screenshots, final smoke test, v0.1 tag

**Files:**
- Create: `docs/screenshots/system.png`
- Create: `docs/screenshots/gamelist.png`
- Modify: `README.md` (embed screenshots)

- [ ] **Step 1: Capture screenshots on the device**

```bash
./scripts/deploy.sh shot && cp .dev/last-shot.png docs/screenshots/system.png
```

(First navigate to the system view on the device, then run the command. Repeat for gamelist view.)

For gamelist:
1. On device, enter a system (any with games in it).
2. `./scripts/deploy.sh shot && cp .dev/last-shot.png docs/screenshots/gamelist.png`

Create the directory first if needed: `mkdir -p docs/screenshots`.

- [ ] **Step 2: Embed screenshots in `README.md`**

Open `README.md`. After the opening status line, before the `## Install` section, add:

```markdown

![System view](docs/screenshots/system.png)
![Gamelist view](docs/screenshots/gamelist.png)

```

- [ ] **Step 3: Final smoke-test pass**

Run through the smoke test from spec §7 explicitly:

1. `./scripts/deploy.sh push` — exits 0.
2. `ssh root@192.168.1.4 'grep -iE "error|warn" /userdata/system/logs/es_log.txt | tail -30'` — no theme-related errors/warnings.
3. On device: system view renders with wave, carousel scrolls, selecting a system enters gamelist, gamelist shows games + art + metadata, B returns to system view.
4. UI Settings → Theme Configuration → PSP Color: switching colorsets visibly changes the tint.
5. The bail-out `./scripts/deploy.sh fallback` works (it should return ES to the `carbon` theme; then manually re-select `es-theme-xmb-psp` to verify recovery).

If any step fails, capture details, fix, re-run the smoke test from step 1.

- [ ] **Step 4: Commit screenshots**

```bash
git add docs/screenshots/ README.md
git commit -m "Add README screenshots and tag v0.1"
```

- [ ] **Step 5: Tag v0.1**

```bash
git tag -a v0.1 -m "v0.1 - first working PSP XMB port on Knulli/TrimUI Brick"
```

- [ ] **Step 6 (optional): Push to remote**

Ask the user: "What's the GitHub remote URL for this repo (or should we set one up now)?"

If a URL is provided:
```bash
git remote add origin <url>
git push -u origin main
git push origin v0.1
```

If not provided, leave the repo local. The user can push at their leisure.

---

## Post-implementation checklist

After Task 15, the following are true:
- [ ] `theme.xml`, `_inc/*.xml`, `colors/*.xml`, `art/*`, `fonts/*`, `sounds/*` all present and loadable.
- [ ] `./scripts/deploy.sh push` deploys end-to-end in <10 seconds.
- [ ] Wave background animates (or static fallback documented if performance forced it).
- [ ] Twelve colorsets selectable from UI Settings → Theme Configuration.
- [ ] System view: wave + carousel + clock + helpsystem.
- [ ] Gamelist view: wave + clock + system anchor + textlist + boxart + metadata.
- [ ] Menu view: dimmed wave background.
- [ ] No theme-related errors/warnings in `es_log.txt`.
- [ ] README has install instructions, troubleshooting, attribution, license summary.
- [ ] CREDITS.md lists InitialDin, Ant/anthonycaccese, Barret Storck, per-font licenses.
- [ ] LICENSE has full CC-BY-NC-SA 2.0 text + modifications stanza.
- [ ] `v0.1` tag exists.
