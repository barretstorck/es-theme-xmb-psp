"""Generate placeholder PNGs for the fixture library.

Each PNG is 256x256 with a solid colour and a centred text label naming
the source game. Not real box art — just a recognisable placeholder so
the harness has something to render in the gamecarousel/gamelist views.

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

def main():
    for rel, (label, rgb) in THUMBS.items():
        path = ROOT / rel
        path.parent.mkdir(parents=True, exist_ok=True)
        img = Image.new("RGB", (256, 256), rgb)
        draw = ImageDraw.Draw(img)
        try:
            font = ImageFont.truetype(
                "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 22
            )
        except OSError:
            font = ImageFont.load_default()
        bbox = draw.textbbox((0, 0), label, font=font)
        w, h = bbox[2] - bbox[0], bbox[3] - bbox[1]
        draw.text(((256 - w) / 2, (256 - h) / 2), label, fill="white", font=font)
        img.save(path)
        print(f"wrote {rel}")

if __name__ == "__main__":
    main()
