#!/usr/bin/env python3
"""Generate the status-bar network glyph for art/ui/network.png.

ES draws its own binary connected/not-connected wifi glyph as part of
BatteryIndicatorComponent. Issue #4 hides that whole component (it is a
second, unstyled battery widget that would double up with ours), which
takes the wifi glyph with it — so the theme draws its own via a
<networkIcon> element and keeps the capability.

Style follows scripts/gen-battery-icons.py: white ink on transparency,
re-tinted at runtime by <color>${textPrimary}</color>.

Canvas height matches the battery art (40 px) on purpose. Both glyphs are
fitted to the same on-screen height by <maxSize>, so equal source heights
plus an equal STROKE means equal *rendered* stroke weight — author them at
different heights and the two glyphs sit side by side at visibly different
line weights.

For the same reason the arcs are sized to very nearly fill those 40 px. The
fitted height is the CANVAS's, not the ink's, so slack at the top of the
canvas comes straight off the drawn glyph: the first pass left 8 px of it
and rendered a 17 px fan next to a 23 px battery.
"""
from pathlib import Path
from PIL import Image, ImageDraw

W, H = 56, 40
STROKE = 3          # matches gen-battery-icons.py at the same canvas height
ARC_RADII = (12, 22, 32)
ARC_SPAN = (222, 318)   # PIL degrees: 0 = 3 o'clock, clockwise. Upward fan.
DOT_R = 3
OUT = Path(__file__).resolve().parent.parent / "art" / "ui" / "network.png"


def make_network() -> Image.Image:
    """Return an RGBA Image: three arcs over a dot, bottom-centre origin."""
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    white = (255, 255, 255, 255)
    # Origin sits STROKE above the bottom edge so the dot's stroke stays inside
    # the canvas; anything drawn past the edge is silently cropped by PIL and
    # would shift the glyph's optical centre once maxSize scales it.
    cx, cy = W // 2, H - 1 - DOT_R - STROKE // 2
    for r in ARC_RADII:
        d.arc([cx - r, cy - r, cx + r, cy + r], ARC_SPAN[0], ARC_SPAN[1],
              fill=white, width=STROKE)
    d.ellipse([cx - DOT_R, cy - DOT_R, cx + DOT_R, cy + DOT_R], fill=white)
    return img


def main() -> None:
    OUT.parent.mkdir(parents=True, exist_ok=True)
    img = make_network()
    img.save(OUT)
    bbox = img.getbbox()
    print(f"wrote {OUT} ({W}x{H}), ink bbox {bbox}")


if __name__ == "__main__":
    main()
