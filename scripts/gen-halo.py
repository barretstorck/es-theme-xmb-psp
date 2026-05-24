#!/usr/bin/env python3
"""Generate the soft radial halo (ring shape) that sits behind the
selected system carousel icon. Pure white-to-transparent, runtime
tint via <color>${accent}</color> in _inc/system.xml.

Profile: transparent center (inside INNER_RADIUS) where the icon
sits, peak alpha just outside the icon edge, half-cosine fade to
0 at MAX_RADIUS. The annular shape concentrates the visible alpha
where it's actually visible (around the icon), not hidden under
it — fixes the v0.9 spec-review finding that a center-bright halo
was perceptually invisible because its brightest pixels were
obscured by the icon at higher zIndex.

256x256 source.
"""
import math
from pathlib import Path
from PIL import Image

W, H = 256, 256
CX, CY = W / 2, H / 2
INNER_RADIUS = 80   # transparent center matching where icon sits (~63% of MAX_RADIUS)
MAX_RADIUS = min(CX, CY)  # = 128
OUT_PATH = Path(__file__).resolve().parent.parent / "art" / "halo.png"


def alpha_at(x: float, y: float) -> int:
    dx, dy = x - CX, y - CY
    dist = math.sqrt(dx * dx + dy * dy)
    if dist <= INNER_RADIUS:
        return 0           # transparent center where icon sits
    if dist >= MAX_RADIUS:
        return 0
    # Smooth ring profile: peak alpha just outside INNER_RADIUS, fade to 0 at MAX_RADIUS
    t = (dist - INNER_RADIUS) / (MAX_RADIUS - INNER_RADIUS)  # 0..1
    # Half-cosine: 1.0 at t=0 (peak just outside icon edge) → 0.0 at t=1 (image edge)
    falloff = 0.5 + 0.5 * math.cos(math.pi * t)
    return int(255 * falloff)


def assert_valid(img: Image.Image) -> None:
    assert img.size == (W, H), f"unexpected size {img.size}"
    assert img.mode == "RGBA", f"unexpected mode {img.mode}"
    assert img.getpixel((W // 2, H // 2))[3] == 0, \
        "center should be transparent (ring design — center is hidden under icon)"
    assert img.getpixel((0, 0))[3] == 0, "corner should be transparent"
    # Ring must have a bright peak somewhere in the annular region
    peak_check_radius = INNER_RADIUS + 5  # just outside the inner edge
    peak_pixel = img.getpixel((int(W // 2 + peak_check_radius), H // 2))
    assert peak_pixel[3] >= 200, \
        f"ring peak should be bright (alpha >= 200), got {peak_pixel[3]}"
    # I1 regression guard: image edge must be fully transparent everywhere
    # (half-cosine profile must drive alpha to 0 at dist == MAX_RADIUS).
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
    print(f"wrote {OUT_PATH} ({W}x{H}, inner radius {INNER_RADIUS}, max radius {MAX_RADIUS})")


if __name__ == "__main__":
    main()
