#!/usr/bin/env python3
"""Generate the soft halo that sits behind the selected system carousel
icon. Pure white-to-transparent, runtime tinted to <color>FFFFFF</color>
in _inc/system.xml.

v0.9.2 PROFILE: simple center-bright gaussian with smooth outer taper.
The icon (zIndex 5/6) sits on top of the bright center pixels; the
visible portion AROUND the icon is the diffuse feathered shoulder.
This is what reads as a 'soft white dot' rather than a 'ring' —
v0.9.1's gaussian-around-peak with transparent center produced a
discrete ring shape, which read as too literal a halo.

For the visible shoulder to be bright (not a thin dim rim), the halo
must be sized substantially larger than the icon. Defaults pair with
haloW=haloH=0.40 in common.xml, which is ~2.5× the icon's apparent
width (sysIconMaxW × logoScale = 0.18 at 4:3). The icon then obscures
only the central ~45% of the halo's diameter; the outer 55% — the
bright gaussian shoulder — is what you see as the soft glow.

256x256 source. SIGMA=45 chosen so:
  - At the icon's edge in halo coords (r ≈ 58): alpha ≈ 111 (visible)
  - At the immediate-neighbour icon's center (r ≈ 104 at the v0.9
    carousel spacing): alpha ≈ 18 (minimal bleed)
  - At MAX_RADIUS=128: alpha ≈ 4 (essentially zero)

Outer cosine taper (dist > SIGMA) drives the small residual at the
image edge cleanly to 0, preventing any visible boundary.
"""
import math
from pathlib import Path
from PIL import Image

W, H = 256, 256
CX, CY = W / 2, H / 2
SIGMA = 45          # gaussian std-dev — controls feathering breadth
MAX_RADIUS = min(CX, CY)  # = 128; image-edge clamp
OUT_PATH = Path(__file__).resolve().parent.parent / "art" / "halo.png"


def alpha_at(x: float, y: float) -> int:
    dx, dy = x - CX, y - CY
    dist = math.sqrt(dx * dx + dy * dy)
    if dist >= MAX_RADIUS:
        return 0
    gaussian = math.exp(-(dist * dist) / (2 * SIGMA * SIGMA))
    # Outer cosine taper from dist=SIGMA to dist=MAX_RADIUS — drives the
    # gaussian's small residual cleanly to 0 at the image edge.
    if dist > SIGMA:
        outer_t = (dist - SIGMA) / (MAX_RADIUS - SIGMA)  # 0..1
        taper = 0.5 * (1.0 + math.cos(math.pi * outer_t))  # 1→0
        return int(255 * gaussian * taper)
    return int(255 * gaussian)


def assert_valid(img: Image.Image) -> None:
    assert img.size == (W, H), f"unexpected size {img.size}"
    assert img.mode == "RGBA", f"unexpected mode {img.mode}"
    # Center pixel must be fully opaque (center-bright design).
    # We sample at pixel center (x+0.5, y+0.5), so pixel (W//2, H//2) is
    # at distance sqrt(0.5^2+0.5^2)=0.707 from the gaussian peak — its
    # alpha is int(255*exp(-0.707^2/(2*45^2))) = 254, which is effectively
    # fully opaque. Accept >=254.
    center_pixel = img.getpixel((W // 2, H // 2))
    assert center_pixel[3] >= 254, \
        f"center should be fully opaque (alpha>=254), got {center_pixel[3]}"
    # Image edge must be fully transparent everywhere — the taper ensures this
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
    print(f"wrote {OUT_PATH} ({W}x{H}, sigma {SIGMA})")


if __name__ == "__main__":
    main()
