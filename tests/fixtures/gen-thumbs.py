"""Generate placeholder PNGs for the fixture library.

Two kinds, because a real scrape produces two kinds:

* **Box art** (`media/box/`, `<thumbnail>`) — 256x256, solid colour, centred
  label. Not real box art, just something recognisable for the carousel and
  the gamelist's boxart slot.
* **Screenshots** (`media/screenshots/`, `<image>`) — the gameplay still that
  feeds the media slot. Deliberately at *gameplay* aspect ratios, not square,
  and deliberately not matching their game's video: `<maxSize>` fits each file
  to its own rectangle, so a 16:9 still and a 4:3 clip in one slot land on
  different rectangles. That mismatch is what issue #41 was about, and it is
  the only way the regression can be seen in a render.

Screenshots carry a magenta border, a colour that appears nowhere else in the
theme, so any pixel of one surviving behind the video is unmistakable.

Run from repo root:
    python3 tests/fixtures/gen-thumbs.py
"""
from PIL import Image, ImageDraw, ImageFont
from pathlib import Path

ROOT = Path(__file__).parent / "library"

THUMBS = {
    "snes/media/box/super-metroid.png": ("Super Metroid",   (220,  60,  60)),
    "snes/media/box/zelda3.png":        ("Zelda: ALttP",    ( 60, 180,  90)),
    "snes/media/box/no-desc.png":       ("No-Desc Game",    (200, 200,  80)),
    "psx/media/box/ff7.png":            ("Final Fantasy 7", ( 70,  70, 200)),
    "psx/media/box/mgs.png":            ("Metal Gear",      (110, 110, 110)),
    "psx/media/box/no-video.png":       ("No-Video Game",   (180, 110,  60)),
    "nes/media/box/smb3.png":           ("Mario 3",         (220,  50,  50)),
    "nes/media/box/contra.png":         ("Contra",          ( 50,  50,  50)),
    "nes/media/box/no-genre.png":       ("No-Genre Game",   ( 90, 140, 180)),
}

# rel path -> (label, background rgb, (width, height))
# Sizes are deliberately WIDER than the matching clip in gen-videos.py, so the
# still fits to a rectangle the video cannot cover. See the module docstring.
SCREENSHOTS = {
    # 16:9 still vs a 4:3 clip — the widest mismatch, and the #41 repro case.
    "psx/media/screenshots/ff7.png":            ("FF7 shot",     ( 40,  40, 150), (480, 270)),
    # 4:3 still vs an 8:7 clip — the same fault, milder.
    "snes/media/screenshots/super-metroid.png": ("Metroid shot", (150,  40,  40), (320, 240)),
}

def font(size):
    try:
        return ImageFont.truetype(
            "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", size
        )
    except OSError:
        return ImageFont.load_default()


def placeholder(label, rgb, size, border=None):
    """A solid rectangle with a centred label, optionally outlined."""
    w, h = size
    img = Image.new("RGB", size, rgb)
    draw = ImageDraw.Draw(img)
    if border:
        draw.rectangle([0, 0, w - 1, h - 1], outline=border, width=4)
    fnt = font(22)
    bbox = draw.textbbox((0, 0), label, font=fnt)
    tw, th = bbox[2] - bbox[0], bbox[3] - bbox[1]
    draw.text(((w - tw) / 2, (h - th) / 2), label, fill="white", font=fnt)
    return img


def write(rel, img):
    path = ROOT / rel
    path.parent.mkdir(parents=True, exist_ok=True)
    img.save(path)
    print(f"wrote {rel}")


def main():
    for rel, (label, rgb) in THUMBS.items():
        write(rel, placeholder(label, rgb, (256, 256)))
    for rel, (label, rgb, size) in SCREENSHOTS.items():
        write(rel, placeholder(label, rgb, size, border=(255, 0, 255)))

if __name__ == "__main__":
    main()
