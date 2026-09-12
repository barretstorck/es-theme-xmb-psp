#!/usr/bin/env python3
"""Generate the three XMB wave layers in art/wave/.

Re-run after editing this script:
  python3 scripts/gen-wave-layers.py

## Provenance

The original generator was never committed. README.md long claimed the layers
were "generated procedurally by a small Python script", but no such file exists
anywhere in the object database -- reachable or dangling -- so the wave's actual
maths was lost when e46d005 landed the PNGs alone.

The parameters below were recovered by running an FFT over the committed PNGs'
crest boundary. Each boundary turns out to be a sum of exactly two sinusoids:

    b(x) = mean + SUM_k  amp_k * cos(2*pi*k*x/W + phase_k)

with k in cycles per image width (W = 2 * screen width), so every component
completes an integer number of cycles per screen width and the layer tiles
seamlessly when scrolled left by exactly one screen width -- which is what makes
the storyboard's `repeat="forever"` invisible. The reconstruction matches the
committed art to 0.53px, i.e. within the boundary's own quantisation.

## Shape

Above b(x): a flat grey body. The RIM_PX immediately above b(x): pure white,
the highlight that makes the crest read against the body. Below b(x): white
fading linearly to alpha 0 -- over a fixed FADE_PX for layers 1 and 2, and all
the way to the bottom edge for layer 3.

The rim edge is ANTI-ALIASED. The original PNGs used a binary `y >= b - RIM_PX`
test, so the grey/white transition held exactly two values (190 and 255) and the
rim snapped to whole pixel rows. On an edge this close to horizontal that reads
as pronounced stair-stepping along the crest. Fractional pixel coverage removes
it; it is the single biggest visible difference between this art and the art it
replaces.

## On SVG

Rendering these as SVG was evaluated and rejected -- see the pull request for
"fix: anti-alias the wave rim". ES does support SVG (nanosvg, rasterised at the
element's pixel size), but nanosvg has no way to express a gradient that follows
a curve -- no masks, no clipPath, no filters -- and the wave's fade must follow
the crest. Every workaround trades one artefact for another: exact per-strip
gradients leave anti-aliasing seams between abutting shapes, nested opacity
bands leave contour banding, and a single global gradient gets the fade shape
wrong. It also cost 658ms of rasterisation on a TrimUI Brick and grows VRAM ~5x
at 4K. The wave carries almost no high-frequency detail, so once the rim is
anti-aliased the raster loses nothing worth recovering.
"""

import argparse
import math
import pathlib

import numpy as np
from PIL import Image

W, H = 2048, 1080          # 2x screen width, so one scroll cycle wraps seamlessly
BODY_GREY = 0xBE           # 190/255 — the wave body under ${accent}
RIM_PX = 4                 # white crest highlight, per docs/psp-xmb-style-guidelines.md

# layer: (mean, [(cycles_per_W, amp, phase)], fade_px | None -> fade to bottom)
LAYERS = {
    1: (475.70, [(4, 22.981, -1.5711), (6, 4.051, -0.3688)], 54.0),
    2: (540.51, [(4, 32.819, +0.1296), (6, 8.220, -1.1715)], 54.0),
    3: (605.29, [(2, 45.899, +1.6293), (4, 8.109, -0.0707)], None),
}


def boundary(xs):
    """Crest boundary b(x) for each layer, as an (x,) array."""
    return {
        n: mean + sum(a * np.cos(2 * np.pi * k * xs / W + p) for k, a, p in comps)
        for n, (mean, comps, _) in LAYERS.items()
    }


def render(n):
    """One layer as an (H, W, 4) uint8 RGBA array."""
    _, _, fade_px = LAYERS[n]
    xs = np.arange(W, dtype=np.float64)
    b = boundary(xs)[n]
    end = b + fade_px if fade_px is not None else np.full(W, float(H))
    ys = np.arange(H, dtype=np.float64)[:, None]

    alpha = np.clip((end[None, :] - ys) / (end - b)[None, :], 0.0, 1.0)
    alpha[ys < b[None, :]] = 1.0

    # Fractional coverage of the white rim over each pixel row, rather than a
    # binary test — see the module docstring.
    cov = np.clip((ys + 1.0) - (b - RIM_PX)[None, :], 0.0, 1.0)

    rgba = np.zeros((H, W, 4), np.uint8)
    rgba[..., :3] = np.round(BODY_GREY + (255 - BODY_GREY) * cov)[..., None]
    rgba[..., 3] = np.round(alpha * 255)
    # Fully transparent pixels carry no colour. Verified to make no difference
    # once composited, but it keeps the files small and matches the art this
    # replaces, so the only meaningful diff is the rim itself.
    rgba[..., :3][rgba[..., 3] == 0] = 0
    return rgba


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--outdir", default=None,
                    help="default: art/wave/ next to this script's repo root")
    args = ap.parse_args()

    out = pathlib.Path(args.outdir) if args.outdir else \
        pathlib.Path(__file__).resolve().parent.parent / "art" / "wave"
    out.mkdir(parents=True, exist_ok=True)

    for n in LAYERS:
        path = out / f"wave-layer-{n}.png"
        Image.fromarray(render(n), "RGBA").save(path)
        print(f"wrote {path} ({path.stat().st_size:,} bytes)")


if __name__ == "__main__":
    main()
