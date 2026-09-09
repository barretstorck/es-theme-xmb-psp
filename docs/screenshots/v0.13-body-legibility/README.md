# #42 — gamelist body-text legibility

Renders behind the #42 decision and its verification. All taken with
`scripts/render.sh` against the **real** `/tmp/library` slice (1252-character
descriptions), not `tests/fixtures/library`, whose 74-character maximum cannot
show the problem the issue reports.

| File | What it shows |
|:---|:---|
| `ladder-card-4x3.png` | The ladder the issue asked for: baseline, then one factor added per step — weight, the two opacity cuts, metadata size, colour. The decision was taken from these pixels, not from the description. |
| `before-after-card-4x3.png` | PSP Card, 4:3, January Blue. Metadata row and description. |
| `before-after-card-16x9.png` | Same at 1280x720 — the harder case, since font sizes are a fraction of screen *height*. |
| `before-after-card-slate.png` | The dark colorset (November Slate). |
| `before-after-list-4x3.png` | List + Details info panel, including the year/developer and players/genre lines that moved off `${selectorGlow}`. |
| `before-after-grid-4x3.png` | Box Art Grid info bar. |

## Measured contrast, January Blue at 4:3

Measured off the rendered pixels — 97th-percentile ink against the median
background inside each text band — not computed from the hex values, because
the background is the *wave crest*, not `waveTint`. See §3.5 of the style
guide for why that distinction is worth two full contrast points.

| Band | Before | After |
|:---|---:|---:|
| Card genre / stars / players | 2.61:1 | 3.70:1 |
| Card year · developer | 2.18:1 | 4.01:1 |
| Card description | 3.46:1 | 5.38:1 |
| List year • developer | **1.82:1** | 3.81:1 |
| List description | 3.44:1 | 5.14:1 |

## Two things these renders do not settle

- **The clipped last description line.** The description faces grew; their
  boxes did not. The last visible line is cut mid-glyph until auto-scroll
  moves it. Raised with the measurement and accepted as a trade rather than
  re-deriving box heights for five aspect ratios × two icon sizes.
- **Four colorsets still miss 3:1.** April Green, May Yellow-Green, June
  Yellow and July Amber have accents light enough that even pure white tops
  out at 2.6–3.3:1 on their own wave crest. Lifting light ink on a light wave
  is the wrong direction; the fix is a palette change, out of #42's scope.

## Device verification — TrimUI Brick (.52), 2026-09-09

| File | What it shows |
|:---|:---|
| `device-grid-before-after.png` | The device's own configuration (April Green, Box Art Grid), captured before and after the change. |
| `device-card-4x3.png` | PSP Card on hardware. |
| `device-list-4x3.png` | List + Details on hardware, including the two lines that were at 1.82:1. |

Measured on the device pixels, grid info bar: **7.96 → 10.16:1**, metadata
glyph band **15 → 17px**, ink coverage **+38%**.

That 15 → 17px is the part only hardware could show. The device has no
`subset.iconSize` in `es_settings.cfg`, so ES v39 applies no include for the
Icon Size subset and `_inc/common.xml`'s `cardMetaFontSize` is the live value
there — while the harness renders `icon-size-boxart.xml`'s. Had the size been
raised in only one of the two files, one of these two targets would have
shown no change at all. It measured as exactly that no-op the first time
round; see `scripts/tests/test-body-legibility.sh`.

April Green is one of the four colorsets flagged above as unreachable by
lightening, and it is what the device happens to be set to — so these shots
are the *weakest* case for the colour half of the change, not the strongest.
Settings were restored byte-identical afterwards.

Harness renders are desktop GL21 and the device is GLES2, so the harness
shots are evidence, not a release gate — see `docker/README.md`.
