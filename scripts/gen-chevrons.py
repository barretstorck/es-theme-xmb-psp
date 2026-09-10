#!/usr/bin/env python3
"""gen-chevrons.py — generate the description scroll affordance glyphs.

PARKED: no theme XML consumes these glyphs. The scroll affordance is issue
#9 (S5), deliberately parked outside the v1.0 milestone. The generated PNGs
were removed from art/ in the v1.0 audit cleanup rather than shipping two
unreferenced files to every device — art/ is installed verbatim. This
generator is kept so #9 can recreate them byte-identically: run it, and the
outputs land back in art/ui/. Do not commit the outputs until an element
actually references them.

Mirrors the procedural-asset pattern of scripts/gen-battery-icons.py and
scripts/gen-battery-icons.py. Produces:
  art/ui/chevron-up.png   — white triangle, apex at top center
  art/ui/chevron-down.png — white triangle, apex at bottom center

Each glyph is 32x24 on a transparent canvas with 4-pixel padding on
all sides. The triangle's white fill is later tinted to
${textSecondary} via the theme XML's <color> attribute.

Re-run after editing this script:
  python3 scripts/gen-chevrons.py
"""

from pathlib import Path
from PIL import Image, ImageDraw

OUT_DIR = Path(__file__).resolve().parent.parent / "art" / "ui"
SIZE = (32, 24)


def make_chevron(direction: str, out_path: Path) -> None:
    """direction: 'up' (apex at top) or 'down' (apex at bottom)."""
    img = Image.new("RGBA", SIZE, (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    if direction == "up":
        # apex at (16, 4); base from (4, 20) to (28, 20)
        triangle = [(16, 4), (4, 20), (28, 20)]
    elif direction == "down":
        # apex at (16, 20); base from (4, 4) to (28, 4)
        triangle = [(16, 20), (4, 4), (28, 4)]
    else:
        raise ValueError(f"unknown direction: {direction}")
    draw.polygon(triangle, fill=(255, 255, 255, 255))
    img.save(out_path, "PNG")


def assert_valid(img: "Image.Image") -> None:
    assert img.size == SIZE, f"unexpected size {img.size}"
    assert img.mode == "RGBA", f"unexpected mode {img.mode}"
    # At least some pixels must be fully-opaque white (triangle fill).
    opaque_white = [
        img.getpixel((x, y))
        for x in range(SIZE[0])
        for y in range(SIZE[1])
        if img.getpixel((x, y)) == (255, 255, 255, 255)
    ]
    assert opaque_white, "no fully-opaque white pixels found — PNG may be blank or transparent"


def main() -> None:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    for direction, name in (("up", "chevron-up.png"), ("down", "chevron-down.png")):
        out_path = OUT_DIR / name
        make_chevron(direction, out_path)
        img = Image.open(out_path)
        assert_valid(img)
        print(f"wrote {out_path}")


if __name__ == "__main__":
    main()
