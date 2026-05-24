#!/usr/bin/env python3
"""Generate PSP-authentic battery state icons for art/battery/.

Produces 6 PNGs (empty, at25, at50, at75, full, incharge), each 80x40 px
with transparent background. White outline + white segment fill. The
runtime <color>${textPrimary}</color> tint in the theme XML re-colors
them to match the active colorset.

Style: 3 horizontal segments inside a rounded rectangle body with a
right-side nub, matching the PSP XMB battery glyph.
"""
from pathlib import Path
from PIL import Image, ImageDraw

W, H = 80, 40
STROKE = 3
NUB_W, NUB_H = 5, 18
SEG_GAP = 3
OUT_DIR = Path(__file__).resolve().parent.parent / "art" / "battery"


def make_battery(filled: int, charging: bool = False) -> Image.Image:
    """Return an RGBA Image: outline + `filled` (0..3) segments + optional bolt."""
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    body_w = W - NUB_W  # right edge of the rectangle body
    white = (255, 255, 255, 255)
    # Body outline (filled with transparent — we want only the stroke visible)
    d.rectangle([0, 0, body_w - 1, H - 1], outline=white, width=STROKE)
    # Right-side nub
    nub_y0 = (H - NUB_H) // 2
    d.rectangle(
        [body_w, nub_y0, W - 1, nub_y0 + NUB_H - 1],
        fill=white,
    )
    # Inner area for segments (inside the stroke + gap)
    inner_x0 = STROKE + SEG_GAP
    inner_y0 = STROKE + SEG_GAP
    inner_x1 = body_w - 1 - STROKE - SEG_GAP
    inner_y1 = H - 1 - STROKE - SEG_GAP
    seg_total_w = inner_x1 - inner_x0
    # 3 segments + 2 gaps between them
    seg_w = (seg_total_w - 2 * SEG_GAP) // 3
    for i in range(filled):
        x0 = inner_x0 + i * (seg_w + SEG_GAP)
        x1 = x0 + seg_w
        d.rectangle([x0, inner_y0, x1, inner_y1], fill=white)
    if charging:
        # Lightning-bolt polygon centered on the body
        cx, cy = body_w // 2, H // 2
        s = 10  # half-height of the bolt
        bolt = [
            (cx - s * 0.4, cy - s),
            (cx + s * 0.35, cy - s),
            (cx + s * 0.05, cy - s * 0.15),
            (cx + s * 0.35, cy - s * 0.15),
            (cx - s * 0.35, cy + s),
            (cx - s * 0.05, cy + s * 0.15),
            (cx - s * 0.4, cy + s * 0.15),
        ]
        # Paint with transparent RGBA to KNOCK OUT (not add to) the white
        # segment fill — gives the charging icon a bolt-shaped void that's
        # visually distinct from the fully-filled `full` state.
        d.polygon(bolt, fill=(0, 0, 0, 0))
    return img


def assert_valid(img: Image.Image, name: str) -> None:
    assert img.size == (W, H), f"{name}: expected {(W, H)}, got {img.size}"
    assert img.mode == "RGBA", f"{name}: expected RGBA, got {img.mode}"
    # Sanity: at least some opaque pixels (we drew an outline)
    alpha = img.getchannel("A")
    opaque_pixels = sum(1 for p in alpha.getdata() if p > 0)
    assert opaque_pixels > 50, f"{name}: too few opaque pixels ({opaque_pixels})"


def main() -> None:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    specs = [
        ("battery-empty.png", 0, False),
        ("battery-25.png", 1, False),
        ("battery-50.png", 2, False),
        ("battery-75.png", 3, False),
        ("battery-full.png", 3, False),
        ("battery-incharge.png", 3, True),
    ]
    for name, filled, charging in specs:
        img = make_battery(filled, charging)
        assert_valid(img, name)
        path = OUT_DIR / name
        img.save(path)
        print(f"wrote {path} ({W}x{H}, {filled} segments, charging={charging})")

    # Sanity: incharge must be visually distinct from full (else the bolt is invisible)
    incharge_bytes = (OUT_DIR / "battery-incharge.png").read_bytes()
    full_bytes = (OUT_DIR / "battery-full.png").read_bytes()
    assert incharge_bytes != full_bytes, \
        "battery-incharge.png is byte-identical to battery-full.png — bolt invisible?"


if __name__ == "__main__":
    main()
