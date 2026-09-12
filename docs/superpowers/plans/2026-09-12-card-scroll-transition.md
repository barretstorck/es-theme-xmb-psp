# PSP Card Scroll Transition Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** When the cursor moves in the PSP Card gamelist, the outgoing box art scales down and shifts into the peek slot it is demoted into, while the incoming art grows into the card position.

**Architecture:** Four direction-aware storyboards (`activateNext`/`activatePrev`/`deactivateNext`/`deactivatePrev`) on `cardBoxart` and `cardFallback`, animating `offsetY`, `scale` and `opacity`. ES supplies the mechanism: it double-buffers the whole `DetailedContainer` so the outgoing game's art stays on screen to animate away. Two new theme variables carry the travel distance and the target scale.

**Tech Stack:** batocera-emulationstation theme XML (formatVersion 7), bash structural test suites, a Docker/Xvfb render harness, Python 3 + numpy + Pillow for frame measurement.

**Spec:** `docs/superpowers/specs/2026-09-12-card-scroll-transition-design.md` — read it first; every task argues from it.

## Global Constraints

- **Style A only.** `_inc/gamelist-card.xml`. Do not touch `gamelist-list.xml`, `gamelist-grid.xml`, or any `aspect-*.xml`.
- **Duration is 150 ms, easing `easeOut`** for `offsetY` and `scale`.
- **Never declare plain `activate` or `deactivate`** on `cardBoxart` or `cardFallback`. `handleStoryBoard` falls back to them only when no direction variant exists, and a direction-blind version of this animation is wrong half the time.
- **Never add `scaleOrigin`.** It defaults to `(0.5, 0.5)` (`GuiComponent.cpp:21`), which is what this design needs.
- **`cardPeekScale` must be declared in all THREE files** — `common.xml`, `icon-size-boxart.xml`, `icon-size-compact.xml` — and the `common.xml` value must **equal the boxart value exactly** (`0.42`). On a fresh device no icon-size include applies and `common.xml` wins (`test-body-legibility.sh:150-157`); an unresolved `${cardPeekScale}` becomes `toFloat("") = 0`, animating the box art to nothing on every cursor move. `test-body-legibility.sh` already fails if the two values disagree.
- **`run-all.sh` has two whole-tree variable gates.** `no-undeclared-variables` fails if a `${var}` is never declared; `no-dead-variables` fails if a declared variable is never consumed. A commit that declares a variable without consuming it **will fail CI**. Declaration and consumption must land in the same commit.
- **Commit before mutation testing.** This has destroyed uncommitted work in this repo twice.
- **Verify a mutation actually applied** before believing it escaped. A no-op mutation reports a false escape; this has produced false results three times here.
- Licence header on any new file: `CC-BY-NC-SA 2.0. See CREDITS.md.`
- Commit trailer: `Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>`
- Git identity for commits: `Barret Storck <113543095+barretstorck@users.noreply.github.com>`.

## File Structure

| File | Change | Responsibility |
|---|---|---|
| `_inc/common.xml` | Modify (~line 182) | Declares `cardPeekShift` and the fresh-device `cardPeekScale` default |
| `_inc/icon-size-boxart.xml` | Modify | Declares `cardPeekScale` 0.42; header comment corrected |
| `_inc/icon-size-compact.xml` | Modify | Declares `cardPeekScale` 0.495; header comment corrected |
| `_inc/gamelist-card.xml` | Modify (lines 114-131) | The four storyboards, on `cardBoxart` and `cardFallback` |
| `scripts/tests/test-card-transition.sh` | Create | Structural guards; auto-registered by `run-all.sh`'s `test-*.sh` glob |
| `docs/psp-xmb-style-guidelines.md` | Modify (§6.7, §7) | Documents the motion and why the opacity ramps are asymmetric |
| `docs/psp-authenticity-audit.md` | Modify | 8 shifted `file:line` citations |
| `CHANGELOG.md` | Modify | Rolling record |

---

### Task 1: Variables and storyboards

The variables and their consumers must land together — see Global Constraints. `cardBoxart` and `cardFallback` get byte-identical storyboard sets, because a state where only one of them animates is a bug a reviewer would reject.

**Files:**
- Modify: `_inc/common.xml:178-183`
- Modify: `_inc/icon-size-boxart.xml:7-9,17-18`
- Modify: `_inc/icon-size-compact.xml:8-10,18-19`
- Modify: `_inc/gamelist-card.xml:114-131`
- Test: `scripts/tests/test-card-transition.sh` (created in Task 2; this task is verified by `run-all.sh` plus a render)

**Interfaces:**
- Produces: theme variables `cardPeekShift` (float, `0.25`, declared in `common.xml` only) and `cardPeekScale` (float, declared in **all three** variable files: `0.42` in `common.xml`, `0.42` in icon-size-boxart, `0.495` in icon-size-compact). Task 2's guards assert all of them by name.
- Produces: storyboard event names `deactivateNext`, `deactivatePrev`, `activateNext`, `activatePrev` on elements `cardBoxart` and `cardFallback`.

- [ ] **Step 1: Add `cardPeekShift` to `_inc/common.xml`**

Insert immediately after the `cardBoxartH` line (currently line 183). Note the existing comment above `cardBoxartW` claims "240px square … 0.234 x 0.3125" — those values are overridden by both icon-size subsets and never render. Leave that comment alone in this step; Step 5 corrects it, together with the matching stale figures in the icon-size files.

```xml
    <!-- Scroll-transition travel: one peek slot, = glListH / 3 = 0.25. The
         card's centre and the middle peek slot's centre are the same point
         (both measured at 0.5846 of screen height at 4:3), so an offsetY of
         exactly this lands the travelling card on the adjacent peek icon.
         NOT overridden per icon size or per aspect ratio: glListH is declared
         only here, and the slot pitch is a fraction of the same screen
         dimension at every ratio. -->
    <cardPeekShift>0.25</cardPeekShift>
```

- [ ] **Step 2: Add the fresh-device `cardPeekScale` default to `_inc/common.xml`**

Immediately after `cardPeekShift`:

```xml
    <!-- Fresh-device default for the transition's target scale. Both icon-size
         subsets override this, so in the harness it never renders - but on the
         device no include applies unless the user has opened the Icon Size
         setting, and then common.xml wins (see test-body-legibility.sh:150).
         Without a value here ${cardPeekScale} resolves to the empty string,
         toFloat("") is 0, and the box art animates to nothing on every cursor
         move. MUST equal icon-size-boxart.xml's value: Boxart is the default a
         user is meant to see, and test-body-legibility.sh fails if any shared
         card* variable disagrees between the two files. -->
    <cardPeekScale>0.42</cardPeekScale>
```

This deliberately does **not** match `common.xml`'s own bounds (0.3761-0.408,
computed from its own `cardBoxartW/H`, which are themselves a recorded
divergence). Matching boxart is the point; copying the divergence would not be.

- [ ] **Step 3: Add `cardPeekScale` to `_inc/icon-size-boxart.xml`**

Insert after the `peekIconH` line, inside `<variables>`:

```xml
    <!-- Scroll-transition target scale: what the card shrinks to so it lands
         at peek size. Not derivable at runtime — the peek and card boxes have
         different aspect ratios, so which maxSize cap each hits depends on the
         art:
           both width-limited  -> peekIconW / cardBoxartW              = 0.4000
           both height-limited -> (peekIconH * glListH/3) / cardBoxartH = 0.4397
         Measured 0.439 for 450x600 art, 0.404 for square. 0.42 is the midpoint,
         which bounds the error for every aspect rather than minimising it for
         one; the ~5% residual is covered by the opacity ramp, which reaches 0
         before the card arrives. Both bounds are pure ratios of these
         variables, so this value is independent of screen aspect ratio. -->
    <cardPeekScale>0.42</cardPeekScale>
```

- [ ] **Step 4: Add `cardPeekScale` to `_inc/icon-size-compact.xml`**

Same position, different value and figures:

```xml
    <!-- Scroll-transition target scale; see the note in icon-size-boxart.xml.
         Compact's own bounds:
           both width-limited  -> peekIconW / cardBoxartW              = 0.4710
           both height-limited -> (peekIconH * glListH/3) / cardBoxartH = 0.5183
         Measured 0.522 for 450x600 art, 0.477 for square. 0.495 is the
         midpoint. -->
    <cardPeekScale>0.495</cardPeekScale>
```

- [ ] **Step 5: Correct the stale header comments in both icon-size files**

Both headers derive the peek sizes from `glListH=0.69`; `common.xml` has held
`0.75` since v0.12. Both also quote card sizes that no longer match their own
variables - boxart says "240px (0.234 x 0.3125)" against its actual 0.22/0.29
(225x223 px), and compact says "165px (0.161 x 0.215)" against its actual
0.155/0.205 (159x157 px). Those stale figures sit directly above where
`cardPeekScale`'s derivation now lives, so leaving them would put a correct
derivation next to a wrong one.

Rewrite both to quote each file's own current values, recomputing the pixel
figures from the variables rather than copying any number out of this plan.
`common.xml`'s own `cardBoxartW` and `peekIconW` comments carry the same stale
`glListH=0.69` and the same dead "240px square" claim - correct them too, in
the same commit, for the same reason.

- [ ] **Step 6: Add the storyboards to `cardBoxart`**

Replace the whole `cardBoxart` element (currently `_inc/gamelist-card.xml:114-121`) with:

```xml
    <image name="cardBoxart" extra="true">
      <path>{game:thumbnail}</path>
      <pos>${crossX} ${cardY}</pos>
      <maxSize>${cardBoxartW} ${cardBoxartH}</maxSize>
      <origin>0.5 0.5</origin>
      <zIndex>8</zIndex>
      <!-- Scroll transition. ES picks one of four direction-aware events from
           moveBy = cursorIndex - lastCursor (DetailedGameListView.cpp:46 into
           DetailedContainer.cpp:1106-1160). When any extra carries an
           activation storyboard, DetailedContainerHost keeps the OUTGOING
           game's container alive and runs deactivate* on it (:1358-1395) —
           that is what puts the previous box art on screen to animate away,
           and it is why this effect needs no duplicate "ghost" element.

           Declaring these MOVES this element out of the view's extras and into
           DetailedContainer's own: ThemeData::makeExtras partitions on exactly
           "has an activation storyboard", and DetailedGameListView asks for
           WITHOUT_ACTIVATESTORYBOARD (DetailedGameListView.cpp:14). So
           {game:thumbnail} is now refreshed at DetailedContainer.cpp:1025
           rather than by ISimpleGameListView::updateThemeExtrasBindings().

           Plain activate/deactivate are deliberately absent: handleStoryBoard
           falls back to them only when no direction variant exists, and a
           direction-blind version of this travel is wrong half the time.
           moveBy == 0 (entering the gamelist) reaches neither branch, so entry
           stays a hard cut, which is intended.

           scale needs no scaleOrigin — it defaults to (0.5, 0.5), the
           element's own centre (GuiComponent.cpp:21). offsetY writes
           mScreenOffset, a screen-space translate applied at
           GuiComponent.cpp:434 BEFORE the scale block at :437, so it moves the
           card without disturbing <pos>.

           The opacity ramps are asymmetric on purpose and are load-bearing,
           not decoration: see the style guide's motion section. -->
      <storyboard event="deactivateNext">
        <animation property="offsetY" from="0" to="-${cardPeekShift}" duration="150" mode="easeOut"/>
        <animation property="scale" from="1" to="${cardPeekScale}" duration="150" mode="easeOut"/>
        <animation property="opacity" from="1" to="0" begin="30" duration="120" mode="linear"/>
      </storyboard>
      <storyboard event="deactivatePrev">
        <animation property="offsetY" from="0" to="${cardPeekShift}" duration="150" mode="easeOut"/>
        <animation property="scale" from="1" to="${cardPeekScale}" duration="150" mode="easeOut"/>
        <animation property="opacity" from="1" to="0" begin="30" duration="120" mode="linear"/>
      </storyboard>
      <storyboard event="activateNext">
        <animation property="offsetY" from="${cardPeekShift}" to="0" duration="150" mode="easeOut"/>
        <animation property="scale" from="${cardPeekScale}" to="1" duration="150" mode="easeOut"/>
        <animation property="opacity" from="0" to="1" begin="0" duration="110" mode="linear"/>
      </storyboard>
      <storyboard event="activatePrev">
        <animation property="offsetY" from="-${cardPeekShift}" to="0" duration="150" mode="easeOut"/>
        <animation property="scale" from="${cardPeekScale}" to="1" duration="150" mode="easeOut"/>
        <animation property="opacity" from="0" to="1" begin="0" duration="110" mode="linear"/>
      </storyboard>
    </image>
```

The signs: `Next` means the cursor moved *down* the list, so the outgoing card leaves *upward* (negative `offsetY`) and the incoming one arrives from *below* (positive start). `Prev` mirrors it. `ThemeVariables::resolvePlaceholders` is prefix-preserving string substitution, so `-${cardPeekShift}` resolves to the literal `-0.25`.

- [ ] **Step 7: Add the same storyboards to `cardFallback`**

`cardFallback` is the media-fallback icon shown when the selected game has no thumbnail. Without this an unscraped game gets no transition at all. Keep its existing `<visible>` guard. Append the identical four `<storyboard>` blocks from Step 6 before `</image>`, with this shorter comment instead of the long one:

```xml
      <!-- Same four transitions as cardBoxart, so an unscraped game animates
           identically to a scraped one. See the comment there for the
           mechanism. The <visible> guard still resolves: container extras are
           rebound at DetailedContainer.cpp:1025. -->
```

- [ ] **Step 8: Verify the XML parses strictly**

pugixml (what ES uses) accepts constructs that are illegal XML, so a malformed file renders fine on device and breaks only the tooling.

Run: `python3 -c "import glob,xml.etree.ElementTree as ET; [ET.parse(f) for f in glob.glob('_inc/*.xml')]; print('ok')"`
Expected: `ok`

- [ ] **Step 9: Verify the whole-tree gates still pass**

Run: `scripts/tests/run-all.sh`
Expected: all suites pass. Specifically `no-undeclared-variables` and `no-dead-variables` must both pass — they are the reason Steps 1-7 are one commit.

- [ ] **Step 10: Verify it actually animates, on pixels**

Run from the repo root:

```bash
mkdir -p .dev/verify
GAMELIST_STYLE="PSP Card" ./scripts/record.sh --resolution 1024x768 \
  --library /tmp/library --fps 10 \
  --script "confirm:2.0,down:2.0,up:2.0" \
  --keep-frames --out .dev/verify/after.gif
```

Note `/tmp/library` is ephemeral (it does not survive a container restart). If it is missing, say so and stop rather than falling back to `tests/fixtures/library`, whose art is degenerate.

Expected: the run completes and `.dev/verify/frames/` holds ~60 PNGs. Frames written by the container are root-owned, so always write to a **fresh** output directory rather than `rm -rf`-ing an old one.

- [ ] **Step 11: Commit**

```bash
git add _inc/common.xml _inc/icon-size-boxart.xml _inc/icon-size-compact.xml _inc/gamelist-card.xml
git -c user.name="Barret Storck" -c user.email="113543095+barretstorck@users.noreply.github.com" \
  commit -m "$(cat <<'EOF'
feat: animate the PSP Card box art on cursor change

The outgoing box art scales down and shifts into the peek slot it is
demoted into; the incoming art grows into the card position. Uses ES's
direction-aware activateNext/Prev + deactivateNext/Prev events, which
make it keep the outgoing game's container alive to animate away.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 2: Structural test suite

**Files:**
- Create: `scripts/tests/test-card-transition.sh`

**Interfaces:**
- Consumes: variable names `cardPeekShift`, `cardPeekScale`; element names `cardBoxart`, `cardFallback`; the four event names from Task 1.
- Produces: a suite auto-registered by `run-all.sh`'s `test-*.sh` glob. No registration edit is needed.

House conventions this suite must follow, all of them learned the hard way here:
- Source `scripts/lib/test-lib.sh` for `check`, `fail` and `REPO_ROOT`. Do not write a local copy.
- **Capture exit status on its own line.** `check "... $(cmd)" $?` reports the *substitution's* status, because bash expands arguments left to right. Two guards shipped vacuously passing this way.
- **Guard the properties a thing must have, not a substring that spells it.** A `grep -q 'storyboard'` passes against a comment. This exact failure let a live element through the first `test-no-halo.sh`.
- `! grep -q` against a **missing** file returns 0, so any negative assertion must be on a file known to exist.

- [ ] **Step 1: Write the suite**

```bash
cat > scripts/tests/test-card-transition.sh <<'EOF'
#!/usr/bin/env bash
# Structural test for the PSP Card scroll transition.
#
# Everything here fails SILENTLY on device if it regresses. ES logs nothing
# when a storyboard names an event no call site raises, nothing when a
# ${variable} fails to resolve (it becomes the empty string, and toFloat("")
# is 0 — so a typo'd shift is a transition that travels nowhere), and nothing
# when a theme property lands on no element. Hence structural guards; the
# pixel behaviour is verified separately by a render.
#
# NOTE: deliberately NOT `set -e` — every failure must be reported, not just
# the first.
set -uo pipefail

# shellcheck source=scripts/lib/test-lib.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../lib" && pwd)/test-lib.sh"

CARD="${REPO_ROOT}/_inc/gamelist-card.xml"
COMMON="${REPO_ROOT}/_inc/common.xml"
BOXART="${REPO_ROOT}/_inc/icon-size-boxart.xml"
COMPACT="${REPO_ROOT}/_inc/icon-size-compact.xml"
ANIMATED=(cardBoxart cardFallback)

# Print one named <image> element's block. The close has to be a line that is
# ONLY a closing tag, so a nested property tag cannot end the block early.
image_block() { # image_block <file> <element-name>
  awk -v want="name=\"$2\"" '
    !inblk && index($0, want) && /<image/ {
      inblk = 1; print
      if ($0 ~ /<\/image>/) inblk = 0
      next
    }
    inblk { print; if ($0 ~ /^[[:space:]]*<\/image>[[:space:]]*$/) inblk = 0 }
  ' "$1"
}

# Strip comments before matching, so a guard can never be satisfied by prose.
# This is the failure that let a live <image> through the first no-halo guard.
uncommented() { # uncommented <file>
  python3 - "$1" <<'PY'
import re, sys
print(re.sub(r'<!--.*?-->', '', open(sys.argv[1], encoding='utf-8').read(), flags=re.S))
PY
}

echo "both media elements carry all four direction-aware events:"

for el in "${ANIMATED[@]}"; do
  # Via a temp file, NOT by interpolating the block into a Python string:
  # the XML contains quotes of every kind and would break the literal.
  tmp="$(mktemp)"
  image_block "${CARD}" "${el}" > "${tmp}"
  body="$(uncommented "${tmp}")"
  rm -f "${tmp}"
  for ev in deactivateNext deactivatePrev activateNext activatePrev; do
    grep -q "<storyboard event=\"${ev}\">" <<<"${body}"
    rc=$?
    check "${el} declares event=\"${ev}\"" "${rc}"
  done

  # The direction-blind fallback. handleStoryBoard reaches plain
  # activate/deactivate only when no direction variant exists; declaring one
  # here would silently take over and travel the wrong way half the time.
  ! grep -qE '<storyboard event="(activate|deactivate)">' <<<"${body}"
  rc=$?
  check "${el} declares no direction-blind activate/deactivate" "${rc}"

  # scaleOrigin defaults to the element centre, which is what the design
  # needs. An override is always a mistake here.
  ! grep -q '<scaleOrigin>' <<<"${body}"
  rc=$?
  check "${el} does not override scaleOrigin" "${rc}"

  # Guard the PROPERTIES, not the word "storyboard".
  for prop in offsetY scale opacity; do
    n="$(grep -c "property=\"${prop}\"" <<<"${body}")"
    [[ "${n}" -eq 4 ]]
    rc=$?
    check "${el} animates ${prop} in all 4 events (found ${n})" "${rc}"
  done
done

echo
echo "the travel is one slot, in the right direction:"

# Next = cursor moved down the list, so the outgoing card leaves UPWARD.
# Getting a sign wrong is invisible to every other guard and produces a
# transition that travels into the slot it came from.
card_body="$(uncommented "${CARD}")"

grep -q 'event="deactivateNext">' <<<"${card_body}"
rc=$?
check "deactivateNext exists to check signs against" "${rc}"

for pair in 'deactivateNext:to="-${cardPeekShift}"' \
            'deactivatePrev:to="${cardPeekShift}"' \
            'activateNext:from="${cardPeekShift}"' \
            'activatePrev:from="-${cardPeekShift}"'; do
  ev="${pair%%:*}"; want="${pair#*:}"
  python3 - "${CARD}" "${ev}" "${want}" <<'PY'
import re, sys
path, ev, want = sys.argv[1], sys.argv[2], sys.argv[3]
t = re.sub(r'<!--.*?-->', '', open(path, encoding='utf-8').read(), flags=re.S)
blocks = re.findall(r'<storyboard event="%s">(.*?)</storyboard>' % ev, t, re.S)
offs = [b for b in blocks if 'property="offsetY"' in b]
sys.exit(0 if offs and all(want in b for b in offs) else 1)
PY
  rc=$?
  check "${ev} offsetY carries ${want}" "${rc}"
done

echo
echo "the variables exist, in the right files, with the right values:"

# cardPeekShift is glListH / 3. Recomputed rather than compared to a literal,
# so the two cannot drift apart -- the #43 lesson.
python3 - "${COMMON}" <<'PY'
import re, sys
t = open(sys.argv[1], encoding='utf-8').read()
t = re.sub(r'<!--.*?-->', '', t, flags=re.S)
def val(name):
    m = re.search(r'<%s>([\d.]+)</%s>' % (name, name), t)
    return float(m.group(1)) if m else None
h, shift = val('glListH'), val('cardPeekShift')
if h is None or shift is None:
    print("glListH or cardPeekShift missing from common.xml"); sys.exit(1)
if abs(shift - h / 3) > 1e-9:
    print("cardPeekShift %s != glListH/3 %s" % (shift, h / 3)); sys.exit(1)
PY
rc=$?
check "cardPeekShift equals glListH / 3" "${rc}"

# A subset variable that fails to resolve does not just blank one property:
# ES drops sibling properties on the element (the buttonGlyphs failure found
# on hardware). Both subsets must carry it or one Icon Size setting breaks.
for f in "${BOXART}" "${COMPACT}"; do
  grep -q '<cardPeekScale>' "${f}"
  rc=$?
  check "$(basename "${f}") declares cardPeekScale" "${rc}"
done

# common.xml MUST carry it too, and must agree with Boxart. On the device no
# icon-size include applies until the user opens the setting, and then
# common.xml wins (test-body-legibility.sh:150). Without a value here
# ${cardPeekScale} resolves empty, toFloat("") is 0, and the card animates to
# nothing -- a device-only regression the harness cannot see.
grep -q '<cardPeekScale>' "${COMMON}"
rc=$?
check "common.xml declares the fresh-device cardPeekScale default" "${rc}"

python3 - "${COMMON}" "${BOXART}" <<'PY'
import re, sys
def val(p):
    t = re.sub(r'<!--.*?-->', '', open(p, encoding='utf-8').read(), flags=re.S)
    m = re.search(r'<cardPeekScale>([\d.]+)</cardPeekScale>', t)
    return float(m.group(1)) if m else None
c, b = val(sys.argv[1]), val(sys.argv[2])
if c is None or b is None:
    print("cardPeekScale missing from common.xml or icon-size-boxart.xml"); sys.exit(1)
if abs(c - b) > 1e-9:
    print("common.xml %s != icon-size-boxart.xml %s" % (c, b)); sys.exit(1)
PY
rc=$?
check "common.xml cardPeekScale equals icon-size-boxart.xml's" "${rc}"

# Each subset's value must sit inside ITS OWN bounds, recomputed from its own
# variables. A literal comparison would pass a value copied from the other file.
for f in "${BOXART}" "${COMPACT}"; do
  python3 - "${f}" "${COMMON}" <<'PY'
import re, sys
def load(p):
    t = re.sub(r'<!--.*?-->', '', open(p, encoding='utf-8').read(), flags=re.S)
    return {k: float(v) for k, v in re.findall(r'<(\w+)>([\d.]+)</\1>', t)}
sub, common = load(sys.argv[1]), load(sys.argv[2])
g = {**common, **sub}
need = ('peekIconW', 'cardBoxartW', 'peekIconH', 'cardBoxartH', 'glListH', 'cardPeekScale')
missing = [n for n in need if n not in g]
if missing:
    print("missing: " + ", ".join(missing)); sys.exit(1)
lo = g['peekIconW'] / g['cardBoxartW']                      # both width-limited
hi = (g['peekIconH'] * g['glListH'] / 3) / g['cardBoxartH']  # both height-limited
if not (min(lo, hi) - 1e-9 <= g['cardPeekScale'] <= max(lo, hi) + 1e-9):
    print("cardPeekScale %.4f outside [%.4f, %.4f] for %s"
          % (g['cardPeekScale'], min(lo, hi), max(lo, hi), sys.argv[1]))
    sys.exit(1)
PY
  rc=$?
  check "$(basename "${f}") cardPeekScale lies within its own peek/card bounds" "${rc}"
done

echo
echo "the transition is scoped to Style A:"

for other in gamelist-list gamelist-grid; do
  ! grep -qE 'event="(activate|deactivate)(Next|Prev)"' "${REPO_ROOT}/_inc/${other}.xml"
  rc=$?
  check "${other}.xml declares no direction-aware events" "${rc}"
done

! grep -l 'cardPeekScale\|cardPeekShift' "${REPO_ROOT}"/_inc/aspect-*.xml >/dev/null 2>&1
rc=$?
check "no aspect-*.xml overrides the transition variables" "${rc}"

echo
echo "docs describe the shipped behaviour:"

GUIDE="${REPO_ROOT}/docs/psp-xmb-style-guidelines.md"
grep -q 'deactivateNext' "${GUIDE}"
rc=$?
check "style guide names the direction-aware events" "${rc}"

grep -qi 'cardPeekScale' "${GUIDE}"
rc=$?
check "style guide documents cardPeekScale" "${rc}"

echo
if [[ "${fail}" -eq 0 ]]; then echo "all checks passed"; else echo "FAILURES"; fi
exit "${fail}"
EOF
chmod +x scripts/tests/test-card-transition.sh
```

- [ ] **Step 2: Run it — expect the two doc guards to fail**

Run: `bash scripts/tests/test-card-transition.sh`
Expected: every structural guard passes (Task 1 implemented them), and exactly **two** fail — `style guide names the direction-aware events` and `style guide documents cardPeekScale`. Task 4 makes those pass.

If any *other* guard fails, the guard is wrong or Task 1 is incomplete. Fix before continuing; do not weaken a guard to make it pass.

- [ ] **Step 3: Verify shellcheck is clean**

Run: `shellcheck -x -S warning -e SC2319,SC2034 scripts/tests/test-card-transition.sh`
Expected: no output. (`run-all.sh` runs this with the same two exclusions.)

- [ ] **Step 4: Commit before mutation testing**

```bash
git add scripts/tests/test-card-transition.sh
git -c user.name="Barret Storck" -c user.email="113543095+barretstorck@users.noreply.github.com" \
  commit -m "$(cat <<'EOF'
test: structural guards for the card scroll transition

Two doc guards fail until the style guide is written in a later commit.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 3: Mutation-test the suite

A guard that cannot fail is worse than no guard: it reports safety. Every mutation below must be **confirmed to have applied** before its result is believed — a no-op mutation reports a false escape, which has happened three times in this repo.

**Files:**
- Modify (temporarily, then restore): `_inc/gamelist-card.xml`, `_inc/icon-size-boxart.xml`, `_inc/common.xml`

**Interfaces:**
- Consumes: the suite from Task 2.
- Produces: nothing new; may produce fixes to Task 2's suite.

- [ ] **Step 1: Confirm the tree is clean**

Run: `git status --short`
Expected: empty. If not, stop and commit — `git checkout` to undo a mutation has destroyed uncommitted work here twice.

- [ ] **Step 2: Run the mutation table**

For each row: apply the mutation, **assert it applied**, run `bash scripts/tests/test-card-transition.sh`, record whether it failed, then `git checkout -- <file>`.

| # | File | Mutation | Must be CAUGHT by |
|---|---|---|---|
| 1 | `gamelist-card.xml` | Delete the `activatePrev` storyboard from `cardBoxart` | "cardBoxart declares event=activatePrev" |
| 2 | `gamelist-card.xml` | Delete all four storyboards from `cardFallback` | the four `cardFallback` event guards |
| 3 | `gamelist-card.xml` | Change `event="deactivateNext"` to `event="deactivate"` | the direction-blind guard **and** the event guard |
| 4 | `gamelist-card.xml` | Flip `to="-${cardPeekShift}"` to `to="${cardPeekShift}"` in `deactivateNext` | "deactivateNext offsetY carries …" |
| 5 | `gamelist-card.xml` | Remove the `opacity` animation from `activateNext` | "cardBoxart animates opacity in all 4 events" |
| 6 | `gamelist-card.xml` | Add `<scaleOrigin>0 0</scaleOrigin>` to `cardBoxart` | "does not override scaleOrigin" |
| 7 | `icon-size-compact.xml` | Change `cardPeekScale` to `0.42` (boxart's value) | "lies within its own peek/card bounds" |
| 8 | `icon-size-boxart.xml` | Delete the `cardPeekScale` line | "icon-size-boxart.xml declares cardPeekScale" |
| 9 | `common.xml` | Change `cardPeekShift` to `0.30` | "cardPeekShift equals glListH / 3" |
| 10 | `common.xml` | Delete the `cardPeekScale` line | "common.xml declares the fresh-device cardPeekScale default" |
| 11 | `common.xml` | Change `cardPeekScale` to `0.39` | "common.xml cardPeekScale equals icon-size-boxart.xml's" (and `test-body-legibility.sh`) |

Use a helper that refuses to proceed on a no-op:

```bash
# Reads the mutating Python on stdin; that script gets the target path as
# argv[1] and must rewrite the file in place. Refuses to let a no-op pass as
# a result.
mutate() { # mutate <file>   (mutating python script on stdin)
  local f="$1" before after
  before="$(md5sum "${f}" | cut -d' ' -f1)"
  python3 - "${f}" || return 1
  after="$(md5sum "${f}" | cut -d' ' -f1)"
  if [[ "${before}" == "${after}" ]]; then
    echo "MUTATION DID NOT APPLY to ${f} - result is meaningless" >&2
    return 1
  fi
}

# Example - mutation 4, flipping a sign:
mutate _inc/gamelist-card.xml <<'MUT'
import re, sys
path = sys.argv[1]
s = open(path).read()
i = s.index('<theme')                      # never anchor from 0: the header
body = s[i:]                               # comment contains the same strings
blk = re.search(r'<storyboard event="deactivateNext">.*?</storyboard>', body, re.S)
assert blk, "anchor not found"
new = blk.group(0).replace('to="-${cardPeekShift}"', 'to="${cardPeekShift}"')
assert new != blk.group(0), "replacement was a no-op"
open(path, 'w').write(s[:i] + body.replace(blk.group(0), new, 1))
MUT
```

Anchor every string replacement from `s.index('<theme')` forward. Both `s.index('<view name="...">')` and `sed '0,/pattern/'` hit the string inside the **header comment** first, landing the mutation in a comment where it changes nothing and the guard "passes".

- [ ] **Step 3: Record the results and fix any escapes**

Expected: 11 of 11 caught. Any escape means the guard is wrong — fix the guard, re-run the whole table, and say so plainly in the commit. Do not adjust the mutation to suit the guard.

- [ ] **Step 4: Confirm the tree is restored**

Run: `git status --short && bash scripts/tests/test-card-transition.sh`
Expected: empty status; the same two doc guards failing and nothing else.

- [ ] **Step 5: Commit only if a guard changed**

If no guard changed there is nothing to commit and that is the correct outcome — say so rather than making an empty commit.

---

### Task 4: Pixel verification and tuning

The spec fixes the *asymmetry* of the opacity ramps as a design decision but explicitly leaves the exact `begin` values to be set from rendered frames. This task measures rather than asserts.

**Files:**
- Create: `.dev/verify/` output (gitignored; not committed)
- Modify (only if measurement says so): `_inc/gamelist-card.xml`

**Interfaces:**
- Consumes: Task 1's storyboards.
- Produces: measured travel and duration numbers, quoted in Task 5's docs and in the PR body.

- [ ] **Step 1: Understand what the harness can and cannot resolve**

The capture ceiling is ~11 fps (`import` costs ~90 ms/frame), so a 150 ms
animation spans **1-2 frames**. Baseline `main` spans exactly 1. That is not
enough separation to verify the *shape* of the motion, and reporting "2 frames
instead of 1" as proof would be an overclaim.

So this task splits the question in two:

- **Shape, direction and landing** are verified at **10x durations** (1500 ms),
  which yields ~15 frames of motion. This is how the original spike proved the
  mechanism. The 10x values are temporary and must not be committed.
- **The shipped 150 ms values** are verified *structurally* (they are literals
  in the XML, guarded by Task 2) plus a weaker pixel check that a multi-frame
  run exists at all.

- [ ] **Step 2: Capture a `main` baseline from a separate worktree**

Do not switch branches in place — the render harness reads the working tree,
and a half-applied checkout silently renders the wrong theme.

```bash
git worktree add ../verify-main main
mkdir -p .dev/verify
GAMELIST_STYLE="PSP Card" ../verify-main/scripts/record.sh \
  --resolution 1024x768 --library /tmp/library --fps 10 \
  --script "confirm:2.0,down:2.0,up:2.0" \
  --keep-frames --out .dev/verify/main.gif
```

Run `record.sh` from the worktree so it renders that worktree's theme. Verify
you got the right one before trusting the numbers: `main` must show 1-frame
change runs in Step 4. If it shows more, you rendered the branch.

- [ ] **Step 3: Capture the branch at 10x durations**

Temporarily multiply every `duration` and `begin` in the four `cardBoxart`
storyboards by 10 (150->1500, 30->300, 120->1200, 110->1100). Leave
`cardFallback` alone; the scraped test library exercises `cardBoxart`.

```bash
GAMELIST_STYLE="PSP Card" ./scripts/record.sh --resolution 1024x768 \
  --library /tmp/library --fps 10 --script "confirm:2.0,down:2.5,up:2.5" \
  --keep-frames --out .dev/verify/branch10x.gif
```

`/tmp/library` is ephemeral and does not survive a container restart. If it is
missing, stop and say so — do **not** fall back to `tests/fixtures/library`,
whose art is degenerate and cannot show this.

Container-written frames are root-owned. Always write to a **fresh** output
directory; `rm -rf` on an old one fails with permission errors.

- [ ] **Step 4: Measure the change runs**

```python
# .dev/verify/measure.py
import sys, glob, numpy as np
from PIL import Image
d = sys.argv[1]
X0, X1 = 100, 400          # the card column at 1024x768
arr = [np.asarray(Image.open(f).convert("RGB"), dtype=np.float32)
       for f in sorted(glob.glob(d + "/f-*.png"))]
prev, run = None, 0
for i, a in enumerate(arr):
    if prev is not None:
        dband = np.abs(a[:, X0:X1] - prev[:, X0:X1]).mean()
        if dband > 2.0:
            run += 1
        elif run:
            print(f"change run ended at frame {i}: {run} frames "
                  f"(~{run * 100} ms at 10 fps)")
            run = 0
    prev = a
```

Run it against both frame directories.

Expected: `main` reports runs of **1 frame**. The 10x branch reports runs of
**~15 frames** for both the down press and the up press. If the branch also
reports 1, the storyboard is not firing — stop and diagnose rather than
proceeding.

- [ ] **Step 5: Read the actual frames**

"The render succeeded" is not verification. Open the mid-transition PNGs and look at them. Specifically check: the incoming card does not visibly stack on the peek icon it passes over, and the outgoing card's cross-dissolve with its own peek icon reads as one object rather than two.

- [ ] **Step 6: Restore the durations, then adjust the ramps only if the frames call for it**

**First restore the shipped durations** (undo the 10x multiplication from
Step 3) and confirm with `git diff _inc/gamelist-card.xml` that the only
remaining differences are intentional. Committing the 10x values would ship a
1.5-second transition.

Then: if the frames looked right, there is nothing further to commit — say so
rather than inventing a change. If they did not, adjust only the `begin` and
`duration` attributes, re-run Steps 3-5, and put the measured justification in
the commit message.

Finally, remove the verification worktree: `git worktree remove ../verify-main`.

---

### Task 5: Documentation

**Files:**
- Modify: `docs/psp-xmb-style-guidelines.md` (§6.7 Style A, new subsection in §7)
- Modify: `docs/psp-authenticity-audit.md` (8 shifted citations)
- Modify: `CHANGELOG.md`

**Interfaces:**
- Consumes: measured numbers from Task 4.
- Produces: the two doc guards in Task 2's suite go green.

- [ ] **Step 1: Re-point the shifted citations**

Task 1 inserted ~45 lines at `_inc/gamelist-card.xml:114`. Every `_inc/gamelist-card.xml:NNN` citation in `docs/psp-authenticity-audit.md` is at a line ≥ 123 and has therefore moved. There are 8, at audit lines 642, 675, 728, 759, 831, 880, 1408, 1446.

Do not add a fixed offset — re-resolve each one by finding the element it names and reading its current line. This class of breakage has cost time twice here, once landing a citation inside an unrelated element.

Run: `grep -n '_inc/gamelist-card\.xml:[0-9]' docs/psp-authenticity-audit.md`
Then for each, confirm the cited line still holds what the surrounding prose claims.

- [ ] **Step 2: Verify the citation gate passes**

Run: `scripts/tests/run-all.sh doc-citations` — or `scripts/tests/run-all.sh` and check the `doc-citations-resolve` gate.
Expected: pass. Note this gate only catches citations past end-of-file; a citation that now points at the *wrong* line still resolves. Step 1's manual check is the real guard.

- [ ] **Step 3: Add the style guide motion subsection**

Add as a **new §7.7 at the end of §7**, after §7.6. Deliberately not inserted
mid-section: renumbering §7.4-§7.6 would churn the table of contents and every
cross-reference to them, and this repo already has a standing problem with
stale doc references. It must cover the following, and Task 2's guards require
the first two:

1. The four event names and how `moveBy` selects them.
2. `cardPeekScale`, its two bounds, and why it is per-icon-size and not in `common.xml`.
3. That declaring an activation storyboard **moves the element into `DetailedContainer`**, and that this rebuilds `md_video` on every cursor move.
4. Why the opacity ramps are asymmetric — the incoming card overlaps a *different* game's peek icon, the outgoing card overlaps *its own*.
5. That the peek icons cannot travel: `updateCameraOffset()` sets `mCameraOffset` with no lerp.

Also update §7.2's rationale for `defaultTransition="instant"` to cross-reference this, and §6.7's Style A description.

- [ ] **Step 4: Add the CHANGELOG entry**

`CHANGELOG.md` is a rolling record — there are no version tags in this repo and `main` always holds a release-ready copy. Follow the existing entry format.

- [ ] **Step 5: Verify the full suite is green**

Run: `scripts/tests/run-all.sh`
Expected: everything passes, including the two doc guards that were failing since Task 2.

- [ ] **Step 6: Commit**

```bash
git add docs/psp-xmb-style-guidelines.md docs/psp-authenticity-audit.md CHANGELOG.md
git -c user.name="Barret Storck" -c user.email="113543095+barretstorck@users.noreply.github.com" \
  commit -m "$(cat <<'EOF'
docs: record the card scroll transition and re-point shifted citations

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 6: Pull request

**Files:** none.

- [ ] **Step 1: Final full run**

Run: `scripts/tests/run-all.sh`
Expected: green. CI runs exactly this on the PR (`.github/workflows/tests.yml`).

- [ ] **Step 2: Push and open the PR**

The PR body must state plainly:
- What was **verified in the harness** (structural guards, mutation table, frame counts) and what those numbers were.
- What is **not verified**: device behaviour, and specifically the `md_video` rebuild cost on the Brick. The harness renders desktop GL21, the device GLES2 — the harness cannot answer it.
- That device verification is a **merge gate**, needing the TrimUI Brick.

Do not describe the change as device-verified. Every previous PR in this repo that carried an honest "harness-verified, NOT device-verified" line was right to.

---

## Device verification (not a subagent task)

Requires the physical TrimUI Brick and is the merge gate for the `md_video`
risk. Recorded here so it is not forgotten, not so an agent attempts it.

- `.env.local` points at **.53 (hammer)**; the brick is **.52**. Environment wins over `.env.local` since PR #54.
- `es_settings.cfg` is written by ES **on exit**, from memory. The order is **stop → edit → start**, never edit-then-restart.
- Use `pidof emulationstation`. `pgrep -x emulationstation` exceeds pgrep's 15-char limit and errors out, which reads as "ES stopped" when it is still running.
- Do **not** use `scripts/ui.sh reload-theme` — it is a blind evdev macro that has launched a game. Use `/etc/init.d/S31emulationstation restart`.
- Inside a gamelist, inject d-pad only. The .52 brick has `InvertButtons=true`, so `a` is SELECT and **launches the highlighted game**.
- Test on a **square-boxart** system (gb/snes). 16:9 art never fills a slot vertically and hides exactly this class of geometry defect.
