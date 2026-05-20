# Design: PSP XMB theme for Knulli/Batocera (TrimUI Brick)

**Date:** 2026-05-20
**Repo:** `es-theme-xmb-psp`
**Target:** Knulli Scarab on TrimUI Brick (4:3, 1024×768)
**Source theme being ported:** [`anthonycaccese/xmb-menu-es-de`](https://github.com/anthonycaccese/xmb-menu-es-de) (CC-BY-NC-SA 2.0)
**Approach:** Reference-and-reimplement — reuse source's visual blueprint and assets; write fresh `theme.xml` against batocera-emulationstation schema (formatVersion 7).

---

## 1. Scope & out-of-scope

### In scope
- Single PSP-style variant.
- 4:3 aspect ratio only, tuned for 1024×768.
- Animated wave background (storyboard).
- Twelve user-selectable colorsets (PSP-month palette) surfaced via batocera subset.
- Three view types: `system`, `detailed` (gamelist), `menu`.
- Helpsystem (button hints), navigate/select/back sounds.
- `scripts/deploy.sh` developer workflow targeting `root@192.168.1.4`.

### Out of scope (deferred)
- Other carousel variants from the source theme.
- Other aspect ratios (1:1, 16:9, 16:10, 3:2, 8:7, 20:9).
- Month-auto color shifting (user picks a colorset; no automatic month mapping).
- `grid` and `video` view types.
- Physical media icons, controller icons.
- Other subsets (iconset, font-size).
- Watch-and-auto-sync, CI, multi-device support.

### Constraint dictating the whole port
True single-scene XMB navigation (horizontal cycles systems *while* viewing a vertical game list) requires modifying batocera-emulationstation's C++ source. **Not achievable in theme XML alone.** Both scenes will visually mimic XMB, but navigation remains two-stage (system view ↔ gamelist view, joined by A/B).

---

## 2. Repo & theme file layout

The repo doubles as both the GitHub source and the installable theme. On the Brick it lives at `/userdata/themes/es-theme-xmb-psp/` (the folder name *is* the theme name in Batocera UI Settings).

```
es-theme-xmb-psp/
├── README.md
├── LICENSE                    # CC-BY-NC-SA 2.0 + modifications stanza
├── CREDITS.md
├── theme.xml                  # entry point: formatVersion 7, subsets, view includes
├── _inc/
│   ├── system.xml             # system view (PSP top row)
│   ├── gamelist.xml           # detailed view (frozen system bar + vertical list + art panel)
│   ├── menu.xml               # Batocera menu theming
│   └── common.xml             # helpsystem, sounds, shared elements
├── colors/
│   ├── psp-jan-blue.xml
│   ├── psp-feb-violet.xml
│   ├── psp-mar-pink.xml
│   ├── psp-apr-green.xml
│   ├── psp-may-yellowgreen.xml
│   ├── psp-jun-yellow.xml
│   ├── psp-jul-amber.xml
│   ├── psp-aug-orange.xml
│   ├── psp-sep-red.xml
│   ├── psp-oct-crimson.xml
│   ├── psp-nov-slate.xml
│   └── psp-dec-aqua.xml
├── art/
│   ├── wave/                  # wave background asset(s) for storyboard
│   ├── system-icons/          # one per Batocera system shortname
│   ├── badges/
│   └── ui/                    # selector highlight, separators
├── fonts/                     # 3 weights from source (per-font license verified)
├── sounds/                    # navigate/select/back from source
├── docs/superpowers/specs/    # design specs (this file)
└── scripts/
    └── deploy.sh              # dev workflow (sync, restart, logs, screenshot)
```

Notes:
- `_inc/` for view XML keeps `theme.xml` as a small entry point.
- `art/` rather than `resources/` avoids collision with batocera-ES's own `resources/` override directory; reserves that name for future use.
- `CREDITS.md` separate from `README.md` so the multi-party attribution chain doesn't bury install instructions.

---

## 3. Visual blueprint per view

### `system` view — PSP top row

Full-screen animated wave background; horizontal carousel of system icons positioned in the upper third (giving the impression of XMB's "category row at the top"); selected system enlarged with its full name caption directly beneath; datetime clock top-right; helpsystem bar at the bottom.

Elements (batocera-ES):
- `<image>` for wave (storyboard-animated position/opacity, tint via colorset variable).
- `<carousel>` (horizontal type, vertically positioned around the upper third).
- `<text>` for selected system name caption below carousel.
- `<datetime>` top-right, 24h, time-only.
- `<helpsystem>` bottom.

### `detailed` view — gamelist

The **same horizontal system bar at the top** (frozen, current system enlarged and highlighted) — visual continuity from the system view. Below it on the left: vertical `<textlist>` of games with the selected row offset right and accented. On the right: art panel with boxart (with fallback to title screen), and metadata block (release date, players, `<rating>`). Wave background continues animating with the same colorset tint. Clock and helpsystem persist.

Elements:
- `<image>` wave (identical to system view).
- "Frozen" system bar — rendered as a row of `<image>` per Batocera system using `system.theme` bindings, with the current system visually enlarged. (Implementation detail: this is decorative; user input does not cycle it. Pressing B/Back returns to the system view where the live carousel re-engages.)
- `<textlist>` for games (left half).
- `<image>` for boxart with fallback to title screen (right half).
- `<text>` for game metadata, `<rating>` for stars.
- `<datetime>`, `<helpsystem>` consistent with system view.

### `menu` view

Light theming of Batocera's settings/options dialogs: same wave background (dimmed), colorset accent on selected items, theme fonts. Minimum effort to avoid visual clash; not a deep redesign of Batocera's menu system.

### Cross-view consistency
- Same wave animation, same colorset tint across all views.
- Three font weights (light/regular/bold) from source.
- Three sound events: navigate (click), select (ascending), back (descending).
- PSP-style rounded-box selector reused across views.
- Helpsystem button glyphs **come from batocera-ES**, not the theme. The Brick's printed A/B/X/Y labels render correctly without us shipping PSP `△○□×` glyphs.

---

## 4. Customization model

Single subset: `colorset`. No `iconset`, no `font-size`, no `aspect-ratio` subset.

```xml
<subset name="colorset" displayName="PSP Color">
  <include name="January Blue">./colors/psp-jan-blue.xml</include>
  <include name="February Violet">./colors/psp-feb-violet.xml</include>
  <!-- ... twelve total ... -->
</subset>
```

Each colorset XML defines the same variables: primary tint, accent, text color, selector glow, helpsystem color, wave tint. Only values differ.

| Slot | Color | PSP month |
|---|---|---|
| 1 | Deep blue | January |
| 2 | Violet | February |
| 3 | Pink | March |
| 4 | Green | April |
| 5 | Yellow-green | May |
| 6 | Yellow | June |
| 7 | Amber | July |
| 8 | Orange | August |
| 9 | Red | September |
| 10 | Crimson | October |
| 11 | Slate | November |
| 12 | Aqua | December |

**Default:** January Blue.

Variables affect only tinted/accent surfaces (wave, selector glow, helpsystem accent, carousel-name caption, selected-game text). Icons, neutral text, fonts remain consistent across colorsets so readability is independent of choice.

Users select the colorset in **UI Settings → Theme Configuration → PSP Color**.

---

## 5. Asset reuse & attribution

### Copied directly from source

| Asset | Source location | Our location |
|---|---|---|
| Wave background | source `resources/wave/` | `art/wave/` |
| System icons (PSP-style) | source `resources/systems/` | `art/system-icons/` (renamed to Batocera shortnames) |
| Fonts (3 weights) | source `resources/fonts/` | `fonts/` |
| Sound effects | source `resources/sounds/` | `sounds/` |
| UI chrome | source `resources/ui/` | `art/ui/` |

### Not copied
- `capabilities.xml` — ES-DE-only, no batocera equivalent.
- Aspect-ratio XMLs and variant XMLs — out of scope.
- Physical media icons, controller icons — not used by our view set; if added later, re-add corresponding credits.

### System icon rename map (known divergences ES-DE → Batocera)

| ES-DE name | Batocera name |
|---|---|
| `genesis` | `megadrive` |
| `gameboyadvance` | `gba` |
| `gameboycolor` | `gbc` |
| `nintendo64` | `n64` |

Full inventory locked during implementation by listing the source's `resources/systems/` against `batocera.linux/board/batocera/fsoverlay/usr/share/batocera/configgen/data/systemlist.xml`. Systems source covers but Batocera lacks: drop. Systems Batocera covers but source lacks: fall back to batocera-ES's built-in generic icon.

### Font licensing

Each font in the source's `resources/fonts/` may carry its own license (SIL OFL, Apache, or proprietary). During implementation, verify each font; the verified license goes in the `CREDITS.md` table. Drop any font with a license incompatible with redistribution and substitute an OFL alternative.

### Attribution chain

`CREDITS.md` lists, in lineage order:
1. **Sony Computer Entertainment** — PSP XMB design inspiration (no assets used).
2. **InitialDin** — XMB-Easy-Theme, original ES XML.
3. **Ant / anthonycaccese** — XMB Menu ES-DE refactor (the direct parent, CC-BY-NC-SA 2.0).
4. **Barret Storck** — this port (CC-BY-NC-SA 2.0).

Not yet listed (would be re-added if their assets get used):
- RobZombie9043 — controller icons.
- RetroArch XMB monochrome theme contributors — physical media icons.

---

## 6. Licensing files

### `LICENSE`

Full canonical CC-BY-NC-SA 2.0 legal text, followed by:

```
This work is a derivative of "XMB Menu ES-DE" by Ant (anthonycaccese),
licensed under CC-BY-NC-SA 2.0 — https://github.com/anthonycaccese/xmb-menu-es-de
itself derived from "XMB-Easy-Theme" by InitialDin.

Modifications by Barret Storck (2026-): port to batocera-emulationstation
(Knulli Scarab on TrimUI Brick); XML rewrite; restricted to single
variant and 4:3 layout; colorset subset model.

Derivative is also licensed under CC-BY-NC-SA 2.0.
```

The "Modifications by" line satisfies CC's statement-of-changes requirement.

### `README.md`

Sections:
- Title + one-line description (PSP XMB-style theme for Knulli/Batocera, 4:3 1024×768).
- Status (PSP variant only, 4:3 only, 12 colorsets).
- Screenshots (system view + gamelist view).
- Install (SSH, clone to `/userdata/themes/`, select in UI Settings, restart ES).
- Compatibility (tested on Knulli Scarab + TrimUI Brick; likely works on any Batocera/Knulli device at 4:3 with formatVersion 7 support; other aspect ratios will letterbox or stretch).
- Customization (point at UI Settings → Theme Configuration → PSP Color).
- Troubleshooting (the carbon-fallback recovery command).
- Credits + license summary, pointer to `CREDITS.md` and `LICENSE`.

### Per-XML header comment

Every committed XML file begins with:

```xml
<!--
  es-theme-xmb-psp - PSP XMB theme for batocera-emulationstation
  Derivative of "XMB Menu ES-DE" by Ant (anthonycaccese), itself derived
  from "XMB-Easy-Theme" by InitialDin. CC-BY-NC-SA 2.0.
  Full attribution: see CREDITS.md
-->
```

### Deliberately not included

`CONTRIBUTING.md`, `CODE_OF_CONDUCT.md`, `CHANGELOG.md`, GitHub Actions. Premature for a personal port; git log is the changelog until releases matter.

---

## 7. Developer workflow

### Iteration loop

```
edit on Mac → rsync to Brick → restart ES → tail log / pull screenshot → look at result
```

### `scripts/deploy.sh` subcommands

- `sync` — `rsync -avz --delete --exclude='.git' --exclude='docs' --exclude='scripts' ./ root@192.168.1.4:/userdata/themes/es-theme-xmb-psp/`
- `restart` — `ssh root@192.168.1.4 'batocera-es-swissknife --restart'`
- `push` — `sync` + `restart` (the common one)
- `logs` — `ssh root@192.168.1.4 'tail -f /userdata/system/logs/es_log.txt'`
- `shot` — runs `batocera-screenshot` on device, pulls newest PNG to `./.dev/last-shot.png`
- `shell` — interactive ssh session

Defaults baked in: `DEVICE_IP=192.168.1.4`, `DEVICE_USER=root`, `THEME_NAME=es-theme-xmb-psp`. Overridable via env vars or a gitignored `.env.local`. First-time setup runs `ssh-copy-id` so subsequent commands skip the password (`linux`) prompt.

### Smoke test per iteration

1. `push` exits 0 (rsync + restart succeeded).
2. `es_log.txt` shows ES boot with **no `ERROR` or `WARN` lines naming our theme**.
3. Visual confirmation via `shot` (or by looking at the Brick): system view renders, wave animates, carousel responds to d-pad, A/B toggle works between views, active colorset matches selection.

### Bail-out (recover from a theme that breaks ES startup)

ES crashes don't take the system down on Knulli; SSH still works. From the Mac:

```
ssh root@192.168.1.4 'batocera-settings-set theme.set carbon && batocera-es-swissknife --restart'
```

Forces Batocera back to the built-in `carbon` theme. Documented in README troubleshooting.

### Deliberately not built

- No watch-and-auto-sync — push is intentional; auto-sync would make accidental half-edits visible on the device.
- No CI / theme validators — batocera-ES is the validator; the device is the test bed.
- No multi-device support — single IP, env-overridable.

---

## 8. Build order (for the writing-plans skill)

The implementation plan should sequence work roughly as follows (this is direction for the next skill, not a binding plan):

1. Repo skeleton — `README.md`, `LICENSE`, `CREDITS.md`, `.gitignore`, `scripts/deploy.sh`. First commit gets the repo out of "no commits yet" state.
2. `scripts/deploy.sh` working end-to-end against the Brick before any XML is written, so we have a feedback loop ready when XML lands.
3. Asset migration: copy source `resources/` into `art/`/`fonts/`/`sounds/` with the rename map and per-font license verification.
4. Minimal `theme.xml` that loads (formatVersion 7, no errors in log) — even if it renders nothing useful. Confirms the entry-point parses.
5. `_inc/common.xml` — wave background, helpsystem, sounds, fonts wired up via variables.
6. `_inc/system.xml` — system carousel + clock. First visually meaningful milestone.
7. Twelve colorset XML files + `<subset>` declaration. Test selecting each via UI Settings.
8. `_inc/gamelist.xml` — frozen system bar, vertical textlist, art panel, metadata.
9. `_inc/menu.xml` — Batocera menu theming pass.
10. Wave storyboard animation — last, since it's performance-sensitive on the Brick and easier to tune once the static layout is locked.
11. README screenshots, smoke-test pass, version 0.1 tag.

---

## 9. Open questions deferred to implementation

These are intentionally not decided now and should be resolved during implementation when there's evidence to decide on:

- **Exact wave storyboard timing and easing.** Tune by feel on the Brick once it renders; storyboards are performance-sensitive and the right answer is "what looks right and doesn't drop frames."
- **Font filenames and license per-font.** Locked when copying assets; affects `CREDITS.md` table.
- **Full system-icon coverage map.** Locked when inventorying source `resources/systems/` against the Brick's enabled systems.
- **"Frozen system bar" layout details on gamelist** (icon size, spacing, current-system enlargement ratio). Locked by experiment on the Brick — the source theme's ES-DE layout doesn't translate by formula.
- **"Frozen system bar" technique feasibility.** The gamelist view's variable scope in batocera-ES is the *current* system; rendering icons of *other* systems alongside it likely requires N individually-declared `<image>` elements (one per system shortname) with conditional sizing/visibility for the current system, rather than a single iterable carousel. If this proves too brittle or too costly to maintain (e.g., breaks when the user enables a new system), the **fallback is the "single current-system icon top-left"** anchor (the alternative the user weighed and rejected earlier). The fallback is purely a visual change — the rest of the design is unaffected. Decide on the device once the layout is wired.
