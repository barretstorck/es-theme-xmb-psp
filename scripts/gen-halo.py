#!/usr/bin/env python3
"""Generate the soft radial halo that sits behind the selected system
carousel icon. Pure white-to-transparent radial; runtime tint via
<color>${accent}</color> in _inc/system.xml.

Profile: white core covers ~30% of the radius, gaussian falloff to 0
at the edge. 256x256 source (slightly larger than the largest selected
icon at any aspect ratio, leaving falloff room).
"""
import math
from pathlib import Path
from PIL import Image

W, H = 256, 256
CX, CY = W / 2, H / 2
CORE_RADIUS = 38   # ~30% of half-width: solid-white core
SIGMA = 55         # gaussian std-dev for the falloff tail
MAX_RADIUS = min(CX, CY)  # falloff reaches 0 by image edge
OUT_PATH = Path(__file__).resolve().parent.parent / "art" / "halo.png"


def alpha_at(x: float, y: float) -> int:
    dx, dy = x - CX, y - CY
    dist = math.sqrt(dx * dx + dy * dy)
    if dist <= CORE_RADIUS:
        return 255
    if dist >= MAX_RADIUS:
        return 0
    tail = dist - CORE_RADIUS
    falloff = math.exp(-(tail * tail) / (2 * SIGMA * SIGMA))
    # Force smooth fade-to-zero at the image edge: multiply by a linear
    # taper that hits 1.0 just outside the core and 0.0 at MAX_RADIUS.
    # Without this, border pixels (dist ~ 127.5) keep alpha ~ 67 from the
    # Gaussian tail alone, producing a visible hard circular clip at the
    # NSEW edges of the image.
    taper = (MAX_RADIUS - dist) / (MAX_RADIUS - CORE_RADIUS)
    falloff *= taper
    return int(255 * falloff)


def assert_valid(img: Image.Image) -> None:
    assert img.size == (W, H), f"unexpected size {img.size}"
    assert img.mode == "RGBA", f"unexpected mode {img.mode}"
    assert img.getpixel((W // 2, H // 2)) == (255, 255, 255, 255), \
        "center should be fully opaque white"
    assert img.getpixel((0, 0))[3] == 0, "corner should be transparent"
    # I1 regression guard: image edge must be fully transparent everywhere
    # (linear taper must drive alpha to 0 at dist == MAX_RADIUS).
    for x in range(W):
        assert img.getpixel((x, 0))[3] == 0, f"top edge x={x} not transparent"
        assert img.getpixel((x, H - 1))[3] == 0, f"bottom edge x={x} not transparent"
    for y in range(H):
        assert img.getpixel((0, y))[3] == 0, f"left edge y={y} not transparent"
        assert img.getpixel((W - 1, y))[3] == 0, f"right edge y={y} not transparent"


def main() -> None:
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    pixels = img.load()
    for y in range(H):
        for x in range(W):
            a = alpha_at(x + 0.5, y + 0.5)  # sample at pixel center
            if a > 0:
                pixels[x, y] = (255, 255, 255, a)
    assert_valid(img)
    OUT_PATH.parent.mkdir(parents=True, exist_ok=True)
    img.save(OUT_PATH)
    print(f"wrote {OUT_PATH} ({W}x{H}, core radius {CORE_RADIUS}, sigma {SIGMA})")


if __name__ == "__main__":
    main()
