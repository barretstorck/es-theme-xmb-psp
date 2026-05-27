#!/usr/bin/env python3
"""gen-chevrons.py — generate the description scroll affordance glyphs.

Mirrors the procedural-asset pattern of scripts/gen-halo.py and
scripts/gen-battery-icons.py. Produces:
  art/ui/chevron-up.png   — white triangle, apex at top center
  art/ui/chevron-down.png — white triangle, apex at bottom center
  art/chevron.png         — selector chevron for textlist + gamecarousel
                            (256x32 wide canvas, left-pointing glyph at LEFT
                            edge; required because <selectorImagePath>
                            stretches to the textlist's full width)

Each scroll glyph is 32x24 on a transparent canvas with 4-pixel padding
on all sides. The triangle's white fill is later tinted to
${textSecondary} via the theme XML's <color> attribute.

Re-run after editing this script:
  python3 scripts/gen-chevrons.py
"""

from pathlib import Path
from PIL import Image, ImageDraw

ART_DIR = Path(__file__).resolve().parent.parent / "art"
OUT_DIR = ART_DIR / "ui"
SIZE = (32, 24)
SELECTOR_SIZE = (256, 32)


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


def gen_selector_chevron() -> None:
    """Selector chevron used by detailed-textlist <selectorImagePath>
    and the gamecarousel extra overlay (v0.11 / PR C / #9).

    The canvas is wide (256x32) because <selectorImagePath> stretches
    the image to the textlist's full width, so the chevron must
    occupy only the leftmost ~10% of the canvas; the rest is
    transparent.

    The chevron is drawn as a thick "<" stroke, pure-opaque white so
    that <selectorColor>/<color> in the XML can recolor it per
    colorset.
    """
    out_path = ART_DIR / "chevron.png"
    W, H = SELECTOR_SIZE
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    # Thick chevron stroke as a hex polygon forming a "<" shape,
    # anchored to x=4 with a small left padding.
    tip_x = 4
    base_x = 18
    top_y = 4
    bot_y = 28
    mid_y = 16
    inner_tip_x = 10
    draw.polygon([
        (tip_x, mid_y),
        (base_x, top_y),
        (base_x, top_y + 5),
        (inner_tip_x + 2, mid_y),
        (base_x, bot_y - 5),
        (base_x, bot_y),
    ], fill=(255, 255, 255, 255))
    img.save(out_path, "PNG")
    # Validate: size, mode, and that we have opaque-white pixels in
    # the leftmost band only (right band should be fully transparent).
    check = Image.open(out_path)
    assert check.size == SELECTOR_SIZE, f"unexpected size {check.size}"
    assert check.mode == "RGBA", f"unexpected mode {check.mode}"
    left_opaque = any(
        check.getpixel((x, y)) == (255, 255, 255, 255)
        for x in range(0, 32)
        for y in range(H)
    )
    assert left_opaque, "selector chevron has no opaque pixels at left edge"
    right_transparent = all(
        check.getpixel((x, y))[3] == 0
        for x in range(64, W)
        for y in range(H)
    )
    assert right_transparent, "selector chevron right band is not fully transparent"
    print(f"wrote {out_path}")


def main() -> None:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    for direction, name in (("up", "chevron-up.png"), ("down", "chevron-down.png")):
        out_path = OUT_DIR / name
        make_chevron(direction, out_path)
        img = Image.open(out_path)
        assert_valid(img)
        print(f"wrote {out_path}")
    gen_selector_chevron()


if __name__ == "__main__":
    main()
