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
    return int(255 * falloff)


def main() -> None:
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    pixels = img.load()
    for y in range(H):
        for x in range(W):
            a = alpha_at(x + 0.5, y + 0.5)  # sample at pixel center
            if a > 0:
                pixels[x, y] = (255, 255, 255, a)
    # Assertions
    assert img.size == (W, H), f"unexpected size {img.size}"
    assert img.mode == "RGBA", f"unexpected mode {img.mode}"
    # Center pixel must be fully opaque (we're in the core)
    assert img.getpixel((W // 2, H // 2)) == (255, 255, 255, 255), \
        "center should be fully opaque white"
    # Corner pixel must be fully transparent (well outside MAX_RADIUS)
    assert img.getpixel((0, 0))[3] == 0, "corner should be transparent"
    OUT_PATH.parent.mkdir(parents=True, exist_ok=True)
    img.save(OUT_PATH)
    print(f"wrote {OUT_PATH} ({W}x{H}, core radius {CORE_RADIUS}, sigma {SIGMA})")


if __name__ == "__main__":
    main()
