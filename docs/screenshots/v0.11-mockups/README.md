# v0.11 Redesign v2 — Proposed layout mockup

**Status:** Awaiting sign-off. No XML changes yet — see `feedback_mockup_first_for_layouts.md` rationale.

## What changes vs the current PR #32

The current implementation has `<lines>3</lines>` with three equally-sized rows. Each row has a small boxart (~100 px), small text, and lots of empty wave background. User feedback: "the newer PSP XMB game carousel screen leaves lots of empty screen space" — the layout is too sparse.

**Proposed:** "Selected dominates" — drop to `<lines>2</lines>` so two rows are visible, and use activate/deactivate storyboards (opacity-driven swap or scale-aware) so the selected row's content is much bigger than the unselected peek row's. Concretely:

- **Selected row:** ~200×200 px boxart on the left (anchored at X=crossX=0.24 under the system icon); large title above a horizontal line; metadata + scrolling description below the line on the right.
- **Unselected peek row:** ~90×90 px boxart only, with a small dimmed title to the right (Friendly mode) or nothing (Strict mode).

The peek row gives the user a sense of "what's next" without taking up half the screen.

## Key dimensions in the mockup

| Element | Position | Size |
|---|---|---|
| System icon | (X=0.24, Y=0.18) | 0.18 × 0.24 (~184×184 px at 4:3) |
| NES caption | (X=0.24, Y=0.40) | text |
| Selected slot | y=[0.50, 0.78] | full width × 28% screen height |
| Selected boxart | center X=0.24, slot-centered Y | ~200×200 px |
| Selected title | right of boxart, above line | font size ~0.07 of screen |
| Selected line | from right-of-boxart to (X=0.97) | 2 px thick |
| Selected metadata | below line, left half | small font, stars + genre |
| Selected description | below line, right half | scrolling marquee |
| Unselected peek slot | y=[0.80, 0.95] | full width × 15% screen height |
| Unselected boxart | center X=0.24, slot-centered Y | ~90×90 px |
| Unselected title (Friendly) | right of small boxart | small dim font |

## Caveats this mockup hides

- The stars in the mockup render as empty boxes because the mockup uses Roboto Condensed (no star glyph). In the real theme, `{game:stars}` uses ES's bundled fontawesome and renders as filled ★ glyphs (verified in earlier round-2/3 renders).
- The wave background is flattened above the textlist area in the mockup (the real theme's continuous wave animation will paint here).
- The scrolling description is shown as truncated text with a small arrow indicator. On-device, this will marquee-scroll via `<autoScrollSpeed>200</autoScrollSpeed>` (round 4 wired this binding).

## Implementation hooks

If approved, the implementation requires:
1. Change `<lines>3</lines>` → `<lines>2</lines>` in the textlist.
2. Use a paired-element trick for boxart-size-by-state:
   - Two `<image>` elements per row: `tplIconBig` (opacity-0 default, fade to 1 on activate) and `tplIconSmall` (opacity-1 default, fade to 0 on activate).
   - Same for halo (currently disabled), title, line, metadata, description — all toggled by activate/deactivate opacity.
3. Subset overrides remain (`iconSize`, `titleVisibility`) but with new sizes:
   - Boxart subset: tplIconBig at 0.20×0.27, tplIconSmall at 0.09×0.12
   - Compact subset: tplIconBig at 0.14×0.18, tplIconSmall at 0.06×0.08
4. Verify on-device after implementing (the harness can't show marquee or video playback).

## How to view the mockup

[`proposed-v2-selected-dominates.png`](./proposed-v2-selected-dominates.png) — opens in GitHub's blob viewer.
