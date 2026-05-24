#!/usr/bin/env python3
"""Generate the soft halo that sits behind the selected system carousel
icon. Pure white-to-transparent, runtime tinted to <color>FFFFFF</color>
in _inc/system.xml (v0.9.1 dropped the ${accent} tint — tinting white
on a same-hue background produced low contrast that read as darker, not
brighter).

Profile: gaussian bell-curve centered on PEAK_RADIUS. Both inner and
outer edges fade smoothly — no hard step at the inner boundary.
PEAK_RADIUS=100 sits just outside the icon's apparent edge (icon edge
in halo coords ≈ 82 source pixels at the current haloW=0.28 and
icon apparent width=0.18); SIGMA=18 gives a ~36-pixel soft zone on
each side of the peak.

Inner side (dist < PEAK_RADIUS): pure gaussian — smoothly ramps from
near-zero at center to 255 at the peak ring.

Outer side (dist > PEAK_RADIUS): gaussian multiplied by a cosine
taper that forces the value to exactly 0 at MAX_RADIUS=128. This
ensures clean image-edge transparency while preserving the soft outer
feathering out to ≈r=118 where the combined profile is already near-zero.

256x256 source. v0.9 used half-cosine with a hard inner step at
INNER_RADIUS=80; v0.9.1 switched to gaussian+taper for symmetric
feathering on both sides of the peak.
"""
import math
from pathlib import Path
from PIL import Image

W, H = 256, 256
CX, CY = W / 2, H / 2
PEAK_RADIUS = 100   # radius of brightest ring (just outside icon edge)
SIGMA = 18          # gaussian std-dev — controls feathering width
MAX_RADIUS = min(CX, CY)  # = 128; image-edge clamp
OUT_PATH = Path(__file__).resolve().parent.parent / "art" / "halo.png"


def alpha_at(x: float, y: float) -> int:
    dx, dy = x - CX, y - CY
    dist = math.sqrt(dx * dx + dy * dy)
    if dist >= MAX_RADIUS:
        return 0
    tail = dist - PEAK_RADIUS
    gaussian = math.exp(-(tail * tail) / (2 * SIGMA * SIGMA))
    if dist > PEAK_RADIUS:
        # Outer cosine taper: forces value smoothly to 0 at MAX_RADIUS,
        # preventing a visible hard clip at the image boundary.
        outer_t = (dist - PEAK_RADIUS) / (MAX_RADIUS - PEAK_RADIUS)  # 0..1
        taper = 0.5 * (1.0 + math.cos(math.pi * outer_t))            # 1→0
        return int(255 * gaussian * taper)
    return int(255 * gaussian)


def assert_valid(img: Image.Image) -> None:
    assert img.size == (W, H), f"unexpected size {img.size}"
    assert img.mode == "RGBA", f"unexpected mode {img.mode}"
    # Peak ring (just outside the icon edge) must be bright
    peak_pixel = img.getpixel((int(CX + PEAK_RADIUS), int(CY)))
    assert peak_pixel[3] >= 240, \
        f"peak ring should be bright (alpha >= 240), got {peak_pixel[3]}"
    # Center must be near-transparent (well inside the gaussian's near-zero tail)
    center_alpha = img.getpixel((W // 2, H // 2))[3]
    assert center_alpha < 15, \
        f"center should be near-transparent (alpha < 15), got {center_alpha}"
    # Image edge must be fully transparent everywhere
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
    print(f"wrote {OUT_PATH} ({W}x{H}, peak radius {PEAK_RADIUS}, sigma {SIGMA})")


if __name__ == "__main__":
    main()
