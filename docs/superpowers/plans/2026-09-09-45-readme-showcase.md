# README Showcase (#45) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give the README a colorset gallery, an animated navigation GIF, and real-asset screenshots, backed by a reproducible regeneration script and a guard that the referenced images actually exist.

**Architecture:** A new `VIEW=record` mode in the existing container script runs a background uniform-interval capture loop while a foreground key script drives navigation, then encodes the frames to GIF with the ImageMagick already in the image. A host wrapper `scripts/record.sh` mirrors `render.sh`. A single `scripts/render-readme-assets.sh` regenerates every committed README image, reading the colorset list from `theme.xml` so it cannot drift.

**Tech Stack:** bash, Docker, Xvfb, xdotool, ImageMagick 6.9 (already in `es-xmb-harness:knulli-9bbb16a-r2`), python3 for test guards.

**Spec:** `docs/superpowers/specs/2026-09-09-45-readme-showcase-design.md`

## Global Constraints

- **Do not modify anything under `docker/` except `run-in-container.sh`.** That file is bind-mounted at run time, never `COPY`d into the image. Touching `Dockerfile` or `patches/` would require a `HARNESS_REV` bump and force every contributor to rebuild.
- `ES_PIN="9bbb16a"`, `HARNESS_REV="r2"`, `IMAGE="es-xmb-harness:knulli-${ES_PIN}-${HARNESS_REV}"` — copied verbatim from `scripts/render.sh:15-17`. `record.sh` must use the same values.
- **Weight budget: ≤4 MB added total.** GIF ≤3 MB, 12 colorset thumbnails ≤600 KB combined.
- **Gamelist renders use `/tmp/library` only.** Never `tests/fixtures/library` — its longest description is 74 chars and it makes the layout look better than it is.
- Every integer read from the environment is validated against `^[0-9]+$` **before** reaching a `(( ))` context; a leading zero is parsed as octal there.
- Test scripts use `set -uo pipefail` (never `set -e`) and the `check()` helper, matching `scripts/tests/test-no-halo.sh:26-35`.
- Commit trailer on every commit: `Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>`

---

### Task 1: Shared subset-list helper

`render.sh` already parses `theme.xml`'s `<subset>` blocks in `subset_values()` (`scripts/render.sh:199-206`). Tasks 4 and 7 need the same twelve colorset names. Extract rather than copy, so the gallery, the regeneration script and the guard all read one source of truth.

**Files:**
- Create: `scripts/lib/theme-subsets.sh`
- Modify: `scripts/render.sh:199-206` (replace the inline function with a `source`)
- Test: `scripts/tests/test-readme-assets.sh` (created here, extended in Tasks 3 and 7)

**Interfaces:**
- Produces: `subset_values <subset-name>` — prints one `<include name="...">` value per line, in document order, for the named subset in `${REPO_ROOT}/theme.xml`. Requires `REPO_ROOT` to be set by the caller.

- [ ] **Step 1: Write the failing test**

Create `scripts/tests/test-readme-assets.sh`:

```bash
#!/usr/bin/env bash
# Guards for the README's committed showcase assets (issue #45).
#
# The README is the product for a theme repo, and its failure mode is silent:
# a renamed screenshot renders as a broken image on the repo's front page and
# no build step notices. These guards make that a test failure instead.
#
# NOTE: deliberately NOT `set -e` — see the note in test-gamelist-styles.sh.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
fail=0
check() { # check <description> <condition-exit-code>
  if [[ "$2" -eq 0 ]]; then echo "  ok   - $1"; else echo "  FAIL - $1"; fi
  [[ "$2" -eq 0 ]] || fail=1
}

# `check "$(cmd)" $?` would report the SUBSTITUTION's status, because bash
# expands arguments left to right — so each guard stores its exit status in
# `rc` on its own line and passes that.

echo "shared subset helper:"

source "${REPO_ROOT}/scripts/lib/theme-subsets.sh"
names="$(subset_values colorset)"; rc=$?
check "subset_values colorset exits 0" "${rc}"

count="$(printf '%s\n' "${names}" | grep -c .)"
[[ "${count}" -eq 12 ]]
check "theme.xml declares exactly 12 colorsets (got ${count})" $?

grep -Fxq "January Blue" <<<"${names}"
check "the list contains January Blue" $?

grep -Fxq "December Aqua" <<<"${names}"
check "the list contains December Aqua" $?

# A subset that does not exist must come back empty rather than printing the
# whole file — otherwise a typo'd subset name silently yields a plausible list.
missing="$(subset_values noSuchSubset)"
[[ -z "${missing}" ]]
check "an unknown subset name yields nothing" $?

echo
if [[ "${fail}" -eq 0 ]]; then echo "ALL CHECKS PASSED"; else echo "SOME CHECKS FAILED"; fi
exit "${fail}"
```

- [ ] **Step 2: Run it to verify it fails**

Run: `chmod +x scripts/tests/test-readme-assets.sh && ./scripts/tests/test-readme-assets.sh`
Expected: FAIL — `scripts/lib/theme-subsets.sh: No such file or directory`

- [ ] **Step 3: Create the helper**

Create `scripts/lib/theme-subsets.sh`:

```bash
#!/usr/bin/env bash
# Shared reader for theme.xml's <subset> blocks.
#
# Extracted from render.sh so the render harness, the README asset generator
# and the README guard all read the SAME source of truth. A hard-coded copy of
# the colorset list in any of them would let a thirteenth palette ship with a
# twelve-row gallery and nothing to catch it.
#
# Requires REPO_ROOT to be set by the caller.

subset_values() { # subset_values <subset-name>
  awk -v want="$1" '
    $0 ~ "<subset name=\"" want "\"" { inblk = 1; next }
    inblk && /<\/subset>/ { exit }
    inblk && match($0, /<include name="[^"]*"/) {
      print substr($0, RSTART + 15, RLENGTH - 16)
    }
  ' "${REPO_ROOT}/theme.xml"
}
```

- [ ] **Step 4: Point render.sh at the helper**

In `scripts/render.sh`, delete the inline `subset_values()` definition (the comment block above it explaining *why* the values are checked against `theme.xml` stays — it documents `check_pin`, not the parser) and add above `check_pin`:

```bash
# shellcheck source=lib/theme-subsets.sh
source "${SCRIPT_DIR}/lib/theme-subsets.sh"
```

- [ ] **Step 5: Run the test and a render.sh regression check**

Run: `./scripts/tests/test-readme-assets.sh`
Expected: PASS, 5 checks.

Run: `GAMELIST_STYLE="Not A Style" ./scripts/render.sh --view gamelist 2>&1 | head -5`
Expected: still exits 2 with "is not a value of the 'gamelistStyle' subset" and lists the valid values — proving the extraction did not break `check_pin`.

- [ ] **Step 6: Commit**

```bash
git add scripts/lib/theme-subsets.sh scripts/render.sh scripts/tests/test-readme-assets.sh
git commit -m "refactor: extract subset_values into a shared helper (#45)"
```

---

### Task 2: `VIEW=record` in the container script

**Files:**
- Modify: `docker/run-in-container.sh` — move `require_es_alive` above the `case "${VIEW}"` block, add `record` to the case, add the capture loop and encode step.

**Interfaces:**
- Consumes: the existing `key()` helper (`docker/run-in-container.sh:256-268`), `CONFIRM_KEY` (`:285-289`), `require_es_alive`, `ES_PID`, `XVFB_PID`.
- Produces: env contract `VIEW=record`, `RECORD_SCRIPT`, `RECORD_FPS`, `RECORD_WIDTH`, `RECORD_COLORS`, `KEEP_FRAMES`; writes `/harness-out/${OUTNAME}` (a `.gif`), and `/harness-out/frames/` when `KEEP_FRAMES=1`.

- [ ] **Step 1: Add and validate the new env vars**

After the existing `SPLASH_AT` line (`docker/run-in-container.sh:17`):

```bash
RECORD_SCRIPT="${RECORD_SCRIPT:-}"
RECORD_FPS="${RECORD_FPS:-10}"
RECORD_WIDTH="${RECORD_WIDTH:-640}"
RECORD_COLORS="${RECORD_COLORS:-128}"
KEEP_FRAMES="${KEEP_FRAMES:-0}"
```

Add `RECORD_FPS RECORD_WIDTH RECORD_COLORS KEEP_FRAMES` to the existing octal-validation loop's variable list (`:22`), so they get the same `^[0-9]+$` check and base-10 re-print as `FRAMES`.

Then, immediately after that loop, reject the values that are numeric but still nonsense:

```bash
# Zero would divide by zero when the frame period is computed, and a 1px-wide
# GIF or a 1-colour palette is a silently useless artifact rather than an
# error. The octal loop above only proves they are digits.
if [[ "${VIEW}" == "record" ]]; then
  (( RECORD_FPS >= 1 ))    || { echo "ERROR: RECORD_FPS must be >= 1" >&2; exit 2; }
  (( RECORD_WIDTH >= 16 )) || { echo "ERROR: RECORD_WIDTH must be >= 16" >&2; exit 2; }
  (( RECORD_COLORS >= 2 && RECORD_COLORS <= 256 )) \
    || { echo "ERROR: RECORD_COLORS must be 2..256" >&2; exit 2; }
fi
```

- [ ] **Step 2: Move `require_es_alive` above the navigation case**

Cut the `require_es_alive()` definition (`docker/run-in-container.sh:329-336`, the comment block above it included) and paste it immediately **before** `echo "navigating: VIEW=${VIEW} ..."` (`:288`).

Reason: record mode starts its capture loop *before* navigation, so the function must already be defined. Nothing else changes — the existing call sites are all further down and a function definition has no side effects.

- [ ] **Step 3: Add the `record` branch to the navigation case**

In the `case "${VIEW}"` block, add before `menu)`:

```bash
  record)
    # Handled after this case: recording drives its own navigation, because
    # the keys have to be pressed WHILE the capture loop is already running.
    : ;;
```

- [ ] **Step 4: Add the recording block**

Insert immediately after the `case`/`esac` and the `[[ "${VIEW}" == "splash" ]] || sleep 2` settle line, guarded so every other view is untouched:

```bash
# --- recording ---
# A background capture loop plus a foreground key script. They are separate
# because their timing requirements conflict: the wave animates on 30s/20s/12s
# loops and needs EVENLY spaced frames or playback speed wobbles, while
# navigation needs UNEVEN pauses (dwell on a system, then move). One loop doing
# both serves neither.
if [[ "${VIEW}" == "record" ]]; then
  mkdir -p /harness-out/frames
  rm -f /harness-out/frames/f-*.png

  period="$(awk -v f="${RECORD_FPS}" 'BEGIN{printf "%.4f", 1/f}')"
  echo "recording at ${RECORD_FPS}fps (period ${period}s)" >&2

  # The loop is DEADLINE-scheduled: it sleeps until start + i*period rather
  # than sleeping a fixed period each pass. `import` costs ~90ms at 1280x720,
  # so a fixed sleep would accumulate that into drift and stretch a 12s
  # recording well past its intended length — and the wave would then play
  # back slower than it really moves.
  capture_loop() {
    local i=0 start now target
    start="$(date +%s.%N)"
    while [[ ! -e /tmp/record.stop ]]; do
      i=$((i + 1))
      import -window root "$(printf '/harness-out/frames/f-%04d.png' "${i}")" \
        2>/dev/null || break
      target="$(awk -v s="${start}" -v i="${i}" -v p="${period}" \
                    'BEGIN{printf "%.4f", s + i*p}')"
      now="$(date +%s.%N)"
      # Command substitution, NOT a pipe into `read` — a pipeline runs `read`
      # in a subshell and the variable never reaches this loop.
      remain="$(awk -v t="${target}" -v n="${now}" \
                    'BEGIN{d = t - n; printf "%.4f", (d > 0 ? d : 0)}')"
      [[ "${remain}" != "0.0000" ]] && sleep "${remain}"
    done
    echo "${i}" > /tmp/record.count
  }

  rm -f /tmp/record.stop /tmp/record.count
  record_start="$(date +%s.%N)"
  capture_loop &
  CAPTURE_PID=$!

  # Navigation script: comma-separated `key:seconds` steps. `confirm` and
  # `back` resolve through CONFIRM_KEY so the INVERT_BUTTONS inversion is
  # handled in exactly one place, the same as every other view.
  IFS=',' read -ra _steps <<< "${RECORD_SCRIPT}"
  for _step in "${_steps[@]}"; do
    [[ -z "${_step}" ]] && continue
    _sym="${_step%%:*}"
    _wait="${_step#*:}"
    [[ "${_sym}" == "${_wait}" ]] && _wait=1
    if [[ ! "${_wait}" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
      echo "ERROR: bad wait '${_wait}' in step '${_step}'" >&2
      touch /tmp/record.stop; exit 2
    fi
    case "${_sym}" in
      confirm) _sym="${CONFIRM_KEY}" ;;
      back)    _sym="$([[ "${CONFIRM_KEY}" == "Return" ]] && echo Escape || echo Return)" ;;
    esac
    require_es_alive "during the recording script"
    key "${_sym}" "${_wait}"
  done

  touch /tmp/record.stop
  wait "${CAPTURE_PID}" 2>/dev/null || true
  record_end="$(date +%s.%N)"
  frame_count="$(cat /tmp/record.count 2>/dev/null || echo 0)"
  require_es_alive "after the recording script"

  if (( frame_count < 2 )); then
    echo "ERROR: captured ${frame_count} frames — nothing to encode" >&2
    exit 1
  fi

  # The GIF delay comes from the MEASURED elapsed time, not from RECORD_FPS.
  # If the harness under-delivers (slower host, larger resolution) a delay
  # derived from the requested rate plays the GIF faster than the theme
  # actually moves. Measuring keeps playback truthful and puts the shortfall
  # in the log instead of silently inside the artifact.
  elapsed="$(awk -v a="${record_start}" -v b="${record_end}" 'BEGIN{printf "%.3f", b-a}')"
  actual_fps="$(awk -v n="${frame_count}" -v e="${elapsed}" 'BEGIN{printf "%.2f", n/e}')"
  delay_cs="$(awk -v n="${frame_count}" -v e="${elapsed}" 'BEGIN{d=100*e/n; printf "%d", (d<1?1:d+0.5)}')"
  echo "captured ${frame_count} frames in ${elapsed}s = ${actual_fps}fps (requested ${RECORD_FPS}); GIF delay ${delay_cs}cs" >&2

  convert -delay "${delay_cs}" -loop 0 /harness-out/frames/f-*.png \
          -resize "${RECORD_WIDTH}" -colors "${RECORD_COLORS}" \
          -layers OptimizeTransparency \
          "/harness-out/${OUTNAME}"

  (( KEEP_FRAMES == 1 )) || rm -rf /harness-out/frames

  kill "${ES_PID}" 2>/dev/null || true
  kill "${XVFB_PID}" 2>/dev/null || true
  echo "recorded ${VIEW} @ ${RESOLUTION} -> /harness-out/${OUTNAME}"
  exit 0
fi
```

- [ ] **Step 5: Verify no other view regressed**

Run: `./scripts/render.sh --view system --out .dev/probe/regress.png`
Expected: exits 0, `.dev/probe/regress.png` written. Read the PNG and confirm it shows the carousel — the `require_es_alive` move is the risk here, and a blank frame is exactly what it guards against.

- [ ] **Step 6: Commit**

```bash
git add docker/run-in-container.sh
git commit -m "feat: add VIEW=record to the harness container script (#45)"
```

---

### Task 3: `scripts/record.sh` host wrapper

**Files:**
- Create: `scripts/record.sh`
- Modify: `scripts/tests/test-readme-assets.sh` (add an argument-validation section)

**Interfaces:**
- Consumes: `VIEW=record` env contract from Task 2; `subset_values` from Task 1.
- Produces: `scripts/record.sh [--resolution WxH] [--colorset NAME] [--library PATH] [--fps N] [--script SPEC] [--width N] [--colors N] [--out FILE] [--keep-frames]`

- [ ] **Step 1: Write the failing tests**

Append to `scripts/tests/test-readme-assets.sh`, before the final summary block:

```bash
echo
echo "record.sh argument validation:"

REC="${REPO_ROOT}/scripts/record.sh"

[[ -x "${REC}" ]]
check "record.sh exists and is executable" $?

# Each of these must be rejected BEFORE docker is invoked, so they must fail
# fast. A 30s timeout means a failure to reject shows up as a timeout rather
# than hanging the suite on an image build.
for bad in "--fps 0" "--fps 08" "--colors 999" "--width 4" "--colorset Nonesuch"; do
  out="$(timeout 30 "${REC}" ${bad} --out /tmp/nope.gif 2>&1)"; rc=$?
  [[ "${rc}" -eq 2 ]]
  check "rejects '${bad}' with exit 2 (got ${rc})" $?
done

# The octal trap is the specific reason the guard above tests 08: `(( 08 ))` is
# a parse error, not eight. Confirm the message names the flag rather than
# leaking a bash error.
out="$(timeout 30 "${REC}" --fps 08 --out /tmp/nope.gif 2>&1)"
grep -qi "fps" <<<"${out}"
check "the --fps 08 message names the flag" $?
```

- [ ] **Step 2: Run to verify it fails**

Run: `./scripts/tests/test-readme-assets.sh`
Expected: FAIL — "record.sh exists and is executable" and all six validation checks fail.

- [ ] **Step 3: Write `scripts/record.sh`**

Model it on `scripts/render.sh` — same header comment style, same `ES_PIN`/`HARNESS_REV`/`IMAGE` constants, same "build only when the image is missing" block, same `DOCKER_ARGS` array shape. The parts that differ:

```bash
#!/usr/bin/env bash
# record.sh — record an animated GIF of es-theme-xmb-psp navigating, via the
# same headless harness render.sh uses. Its output is the README's showcase
# animation; it is a documentation tool, not a release gate.
#
# Separate from render.sh rather than another flag on it: the flag sets barely
# overlap (fps, palette, key script vs. aspect sweeps and battery fakes) and
# render.sh is already 300 lines.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
# shellcheck source=lib/theme-subsets.sh
source "${SCRIPT_DIR}/lib/theme-subsets.sh"

# Must match docker/Dockerfile and render.sh. Recording adds no image content,
# so this deliberately does NOT bump: nobody rebuilds for this feature.
ES_PIN="9bbb16a"
HARNESS_REV="r2"
IMAGE="es-xmb-harness:knulli-${ES_PIN}-${HARNESS_REV}"

RESOLUTION="1280x720"
COLORSET="January Blue"
LIBRARY=""
FPS=10
WIDTH=640
COLORS=128
KEEP_FRAMES=0
OUT="${REPO_ROOT}/.dev/record.gif"
# Default sequence: dwell on the carousel long enough for the wave to move,
# walk several systems, drop into a gamelist, walk a few games, come back out.
SCRIPT_SPEC="right:1.6,right:1.6,right:1.6,confirm:3,down:1.2,down:1.2,down:1.2,back:2,right:1.6"
```

Argument parsing follows `render.sh`'s `while [[ $# -gt 0 ]]; case "$1" in ... esac` shape. After parsing, validate — this is what Step 1's tests exercise:

```bash
# Validated here as well as in the container so a typo costs a second rather
# than a container start. `^[0-9]+$` before any (( )) — a leading zero is
# octal there, so --fps 08 is a parse error rather than eight frames a second.
check_int() { # check_int <flag> <value> <min> <max>
  local flag="$1" val="$2" min="$3" max="$4"
  if [[ ! "${val}" =~ ^[0-9]+$ ]]; then
    echo "bad ${flag}: '${val}' — expected a non-negative integer" >&2; exit 2
  fi
  if (( 10#${val} < min || 10#${val} > max )); then
    echo "bad ${flag}: ${val} — expected ${min}..${max}" >&2; exit 2
  fi
}
check_int --fps    "${FPS}"    1  60
check_int --width  "${WIDTH}"  16 4096
check_int --colors "${COLORS}" 2  256

# The colorset name reaches ES as a subset value, and ES silently falls back to
# the theme default when it cannot find one — so a typo would otherwise produce
# a perfectly good GIF of the wrong palette.
valid_colorsets="$(subset_values colorset)"
if ! grep -Fxq -- "${COLORSET}" <<<"${valid_colorsets}"; then
  echo "bad --colorset: '${COLORSET}' is not a colorset." >&2
  sed 's/^/    /' <<<"${valid_colorsets}" >&2
  exit 2
fi

if (( FPS > 11 )); then
  echo "WARNING: --fps ${FPS} is above the measured harness ceiling (~11fps at" >&2
  echo "  1280x720; import costs ~90ms/frame). The GIF's delay is derived from" >&2
  echo "  the measured rate, so it will still play back at true speed." >&2
fi
```

`DOCKER_ARGS` mirrors `render.sh`'s, minus the battery mount, plus:

```bash
  -e VIEW=record -e RECORD_SCRIPT="${SCRIPT_SPEC}" -e RECORD_FPS="${FPS}"
  -e RECORD_WIDTH="${WIDTH}" -e RECORD_COLORS="${COLORS}"
  -e KEEP_FRAMES="${KEEP_FRAMES}"
```

- [ ] **Step 4: Run the tests**

Run: `chmod +x scripts/record.sh && ./scripts/tests/test-readme-assets.sh`
Expected: PASS, all validation checks green.

- [ ] **Step 5: Smoke-test a real short recording**

Run: `./scripts/record.sh --fps 8 --script "right:1,right:1" --out .dev/probe/smoke.gif --keep-frames`
Expected: exits 0, logs a measured fps line, writes `.dev/probe/smoke.gif`.
**Read the GIF and the retained frames.** A render that "succeeded" is not verification — confirm the frames show the carousel and that frame 1 differs from the last.

- [ ] **Step 6: Commit**

```bash
git add scripts/record.sh scripts/tests/test-readme-assets.sh
git commit -m "feat: add scripts/record.sh (#45)"
```

---

### Task 4: `scripts/render-readme-assets.sh`

**Files:**
- Create: `scripts/render-readme-assets.sh`

**Interfaces:**
- Consumes: `subset_values` (Task 1), `render.sh`, `record.sh` (Task 3).
- Produces: `scripts/render-readme-assets.sh [--library PATH] [--out-dir DIR] [--skip-gif]`, writing into `docs/screenshots/` by default.

- [ ] **Step 1: Write the script**

```bash
#!/usr/bin/env bash
# render-readme-assets.sh — regenerate EVERY image the README commits.
#
# One entry point on purpose. The README's screenshots are its documentation,
# and a future contributor should not have to work out which of render.sh's
# flag combinations produced which file. Running this reproduces the whole set.
#
# Needs a real scraped library for the gamelist shots. /tmp/library (the KNULLI
# slice) has real art and descriptions up to 1252 chars; tests/fixtures/library
# is deliberately degenerate (74-char maximum description) and would make the
# layout look better than it is. It is the regression corpus, not the
# marketing corpus.
set -euo pipefail
```

Body: resolve `REPO_ROOT`, source the helper, then

1. **Colorset thumbnails** — loop `subset_values colorset`, slugify each name (`January Blue` → `january-blue`), call `render.sh --view system --resolution 1024x768 --colorset "$name"`, then downscale to 320px wide into `docs/screenshots/colorsets/<slug>.png`.
2. **Aspect rows** — `system-{4x3,16x9,3x2,1x1,8x7}.png` and the matching `gamelist-*.png`, the latter with `--library`.
3. **Per-style shots** — `GAMELIST_STYLE` set to each value of `subset_values gamelistStyle`.
4. **GIF** — `record.sh`, unless `--skip-gif`.

Fail loudly if `--library` is missing when a gamelist asset is requested, rather than rendering an empty list:

```bash
if [[ -z "${LIBRARY}" ]]; then
  echo "ERROR: --library is required (gamelist assets need real scraped media)." >&2
  echo "  Use the KNULLI slice, e.g. --library /tmp/library." >&2
  echo "  Do NOT use tests/fixtures/library — it is deliberately degenerate." >&2
  exit 2
fi
```

- [ ] **Step 2: Verify it runs**

Run: `./scripts/render-readme-assets.sh --library /tmp/library --skip-gif --out-dir .dev/probe/assets`
Expected: exits 0; 12 colorset thumbnails plus the aspect and style shots exist under `.dev/probe/assets`.

- [ ] **Step 3: Commit**

```bash
git add scripts/render-readme-assets.sh
git commit -m "feat: add scripts/render-readme-assets.sh (#45)"
```

---

### Task 5: Generate and tune the GIF

Iterate in `.dev/` (gitignored). Plain git keeps every version of a committed binary forever, so the GIF is committed **once**, when it is right.

**Files:**
- Create: `docs/screenshots/xmb-navigation.gif` (committed only at the end of this task)

- [ ] **Step 1: Record a full-length take**

Run `record.sh --library /tmp/library --keep-frames` with the default script. The wave's fastest layer loops every 12s, so the take must run at least that long for the motion to read.

- [ ] **Step 2: Read the frames**

Open several retained frames spread across the take. Confirm: the carousel moves, the gamelist is entered, real box art and metadata are visible, and the take returns to the carousel. If navigation drifted, adjust the per-step waits — do not adjust the fps.

- [ ] **Step 3: Compare palette sizes**

Encode the same frames at `--colors 256`, `128` and `64`. **Read all three.** The wave is a smooth gradient and is the first thing quantisation bands. Pick the smallest that does not band visibly.

- [ ] **Step 4: Check the budget**

Run: `ls -l .dev/*.gif`
The chosen GIF must be ≤3 MB. If it is not, trim the sequence or drop `--width` to 560 — in that order, since length is cheaper to lose than resolution.

- [ ] **Step 5: Commit the final artifact**

```bash
cp .dev/<chosen>.gif docs/screenshots/xmb-navigation.gif
git add docs/screenshots/xmb-navigation.gif
git commit -m "docs: add the README navigation GIF (#45)"
```

---

### Task 6: Generate the stills

**Files:**
- Create: `docs/screenshots/colorsets/*.png` (12)
- Modify: `docs/screenshots/system-*.png`, `docs/screenshots/gamelist-*.png` (regenerated from real assets)

- [ ] **Step 1: Generate**

Run: `./scripts/render-readme-assets.sh --library /tmp/library --skip-gif`

- [ ] **Step 2: Read the output**

Open all twelve colorset thumbnails and every regenerated gamelist still. Confirm each thumbnail is visibly a different palette (a silently-ignored `--colorset` would give twelve identical blue frames — the exact failure `record.sh`'s colorset validation exists to prevent) and that the gamelist shots show real box art and long descriptions, not fixture placeholders.

- [ ] **Step 3: Check the budget**

Run: `du -ch docs/screenshots/colorsets/ | tail -1`
Expected: ≤600 KB.

- [ ] **Step 4: Commit**

```bash
git add docs/screenshots/
git commit -m "docs: regenerate README screenshots from real scraped assets (#45)"
```

---

### Task 7: README restructure and the asset guard

**Files:**
- Modify: `README.md`
- Modify: `scripts/tests/test-readme-assets.sh`

- [ ] **Step 1: Write the failing guards**

Append to `scripts/tests/test-readme-assets.sh` before the summary:

```bash
echo
echo "README asset integrity:"

# The guard that matters most: a renamed or deleted screenshot renders as a
# broken image on the repo's front page and nothing else in this repo notices.
python3 - "${REPO_ROOT}" <<'PY'
import os, re, sys
root = sys.argv[1]
text = open(os.path.join(root, "README.md"), encoding="utf-8").read()
refs = re.findall(r'!\[[^\]]*\]\(([^)]+)\)', text)
if len(refs) < 20:
    print(f"only found {len(refs)} image refs — the regex is wrong, the rest "
          "of this check would pass vacuously")
    sys.exit(1)
missing = [r for r in refs
           if not r.startswith(("http://", "https://"))
           and not os.path.exists(os.path.join(root, r))]
for m in missing:
    print(f"README references a missing image: {m}")
sys.exit(1 if missing else 0)
PY
rc=$?
check "every image README.md references exists in-tree" "${rc}"

# The gallery and the theme must not drift apart in either direction.
python3 - "${REPO_ROOT}" <<'PY'
import os, re, sys
root = sys.argv[1]
theme = open(os.path.join(root, "theme.xml"), encoding="utf-8").read()
block = re.search(r'<subset name="colorset".*?</subset>', theme, re.S)
names = re.findall(r'<include name="([^"]+)"', block.group(0))
readme = open(os.path.join(root, "README.md"), encoding="utf-8").read()
missing = [n for n in names if n not in readme]
for n in missing:
    print(f"colorset missing from the README gallery: {n}")
sys.exit(1 if missing else 0)
PY
rc=$?
check "the gallery names every colorset theme.xml declares" "${rc}"

gif="${REPO_ROOT}/docs/screenshots/xmb-navigation.gif"
[[ -f "${gif}" ]] && file -b "${gif}" | grep -q "GIF image data"
check "the navigation GIF exists and is a GIF" $?

gifkb=$(( $(stat -c%s "${gif}" 2>/dev/null || echo 99999999) / 1024 ))
[[ "${gifkb}" -le 3072 ]]
check "the GIF is within the 3MB budget (${gifkb}KB)" $?

thumbkb=$(du -sk "${REPO_ROOT}/docs/screenshots/colorsets" 2>/dev/null | cut -f1)
[[ -n "${thumbkb}" && "${thumbkb}" -le 600 ]]
check "the colorset thumbnails are within the 600KB budget (${thumbkb}KB)" $?
```

- [ ] **Step 2: Run to verify it fails**

Run: `./scripts/tests/test-readme-assets.sh`
Expected: the gallery check FAILS (the README has no gallery yet).

- [ ] **Step 3: Restructure the README**

Order becomes title → GIF → description → colorset gallery → aspect and style screenshots → the rest. Concretely:

- Put `![](docs/screenshots/xmb-navigation.gif)` immediately under the `# es-theme-xmb-psp` title and its one-line description.
- Add a **Colorsets** section: a table of the twelve thumbnails, captioned with the exact names from `theme.xml`. Use a 4-column × 3-row layout — a 12-column single row is unreadable on a phone, and GitHub does not wrap table columns.
- **Delete** the stale-screenshot disclaimer ("Screenshots below predate the v0.12 media-block/metadata recomposition… Regenerate before the next screenshot refresh"). Task 6 regenerated them; leaving the paragraph would now be false.
- Add a short **Regenerating the screenshots** note pointing at `scripts/render-readme-assets.sh` and stating the `/tmp/library` requirement.

- [ ] **Step 4: Run the tests**

Run: `./scripts/tests/test-readme-assets.sh`
Expected: PASS, every check green.

- [ ] **Step 5: Mutation-test the guards**

A guard that cannot fail is worse than no guard. Verify each of these is *caught*, restoring after each:

1. Rename `docs/screenshots/colorsets/january-blue.png` → the missing-image check must fail.
2. Delete one colorset row from the README table → the gallery check must fail.
3. Truncate the GIF to 0 bytes → the "is a GIF" check must fail.
4. Change the README's image regex target by renaming `docs/screenshots` → the `< 20 refs` vacuity guard must fire rather than passing with zero refs.

Record the pass/caught counts in the commit message.

- [ ] **Step 6: Commit**

```bash
git add README.md scripts/tests/test-readme-assets.sh
git commit -m "docs: restructure the README around the showcase assets (#45)"
```

---

### Task 8: Cross-reference the docs and report the weight

**Files:**
- Modify: `docker/README.md` (document `VIEW=record`)

- [ ] **Step 1: Document the record mode**

Add a `record` entry to `docker/README.md`'s view list, covering: the background-loop/foreground-script split, the `key:seconds` script vocabulary, the ~11fps ceiling with its measurement, and that the GIF delay is derived from the measured rate.

- [ ] **Step 2: Measure the added weight**

Run:

```bash
git diff --stat main...HEAD -- docs/screenshots
du -ch docs/screenshots/xmb-navigation.gif docs/screenshots/colorsets | tail -1
```

- [ ] **Step 3: Run the full test suite**

Run every `scripts/tests/test-*.sh`. All must pass — Task 1 touched `render.sh`, which several of them drive.

- [ ] **Step 4: Commit**

```bash
git add docker/README.md
git commit -m "docs: document the harness record mode (#45)"
```

- [ ] **Step 5: Report on the issue**

Comment on #45 with the measured total added weight and the video-beat exclusion and its reason, per the issue's "Done when" clause.
