# Box Art Grid — selection cue and info bar (issue #43)

Verification renders for the fix. All produced by `scripts/render.sh` against
the Docker harness (desktop GL21), so they are a development aid rather than a
release gate — the device renders via GLES2. **Not yet verified on hardware.**

| File | What it shows |
|---|---|
| `before-after-4x3.png` | The `main` behaviour beside the fix, plus the fix with the cursor at a column edge and in the bottom row. 4:3, real scraped Game Boy art. |
| `long-title-4x3.png` | The `nes/long-title` fixture (89 characters, with descenders) selected. ES abbreviates it with `...` at `<size>`'s 0.95, inside the panel's 0.97 — no clip rect involved; see the note below. |
| `aspect-ratios.png` | All five supported ratios, rendered against solid-colour calibration tiles so the drawn rects can be measured exactly. |

## Why the calibration tiles

Real box art cannot answer "does the enlarged tile overlap its neighbour, or
is it being clipped?" — its edges are indistinguishable from its neighbour's.
Replacing every `<thumbnail>` with a distinct flat colour makes each drawn
rect measurable to the pixel, which is how these two facts were established:

* At v0.12's zoom `1.14` the selected tile rendered **254×238** instead of
  254×254 — the grid rect is its own render clip, so the top row's growth was
  cut flat at the band edge.
* Raising the zoom clips the *neighbours* instead: their visible width shrinks
  by exactly what the selected tile gains, because the selected tile is drawn
  last and on top.

After the fix, at every ratio, the selected tile measures square at 1.20× and
no neighbour is narrower than a tile far from the cursor.

## What the long-title render actually shows

Issue #43 asked for a `clipRect` on `gridTitle`, on the reading that a long
title "runs to the screen edge and past the box". It does not, and never did:
`<size>` bounds single-line non-scrolling text because ES abbreviates it to
`mSize.x` with `...` (TextComponent.cpp:376-379). Renders with and without a
`clipRect` on that element are **pixel-identical**, so none is shipped.

What escaped the box was the box. The panel drew at half height, so the title's
band (top 0.808) sat *above* the visible bar top at 0.8229 — which looks exactly
like a title overflowing a panel that is actually the wrong size.

The calibration library is throwaway — it is a copy of a scraped library with
each thumbnail overwritten by a flat colour, not a committed fixture.
