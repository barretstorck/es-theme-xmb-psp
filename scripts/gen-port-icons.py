"""Generate 8 hand-authored port icons in PSP-XMB filled-silhouette style.

The PSP XMB style: 256x256 transparent canvas, single filled white
silhouette glyph centered, ~70% of canvas height. No outline, no
gradient. Pure alpha-on-transparent.

Run from repo root:
    python3 scripts/gen-port-icons.py
"""
from PIL import Image, ImageDraw
from pathlib import Path

OUT = Path("art/system-icons")

# Each glyph is drawn into a 256x256 transparent RGBA canvas as a
# single filled-white shape. Shapes are intentionally simple — these
# are silhouettes, not illustrations.

def crosshair(draw):
    # Centered crosshair: thick ring + crosshairs. Stands in for FPS ports.
    draw.ellipse((68, 68, 188, 188), outline=(255, 255, 255, 255), width=18)
    draw.rectangle((118, 32, 138, 100), fill=(255, 255, 255, 255))
    draw.rectangle((118, 156, 138, 224), fill=(255, 255, 255, 255))
    draw.rectangle((32, 118, 100, 138), fill=(255, 255, 255, 255))
    draw.rectangle((156, 118, 224, 138), fill=(255, 255, 255, 255))

def sword(draw):
    # Vertical sword silhouette. Stands in for ARPG ports.
    draw.polygon([(128, 24), (140, 36), (140, 188), (128, 200), (116, 188), (116, 36)], fill=(255, 255, 255, 255))
    draw.rectangle((92, 188, 164, 204), fill=(255, 255, 255, 255))
    draw.rectangle((122, 200, 134, 232), fill=(255, 255, 255, 255))

def bomb(draw):
    # Round bomb + fuse. Stands in for Bomberman clones.
    draw.ellipse((68, 80, 188, 200), fill=(255, 255, 255, 255))
    draw.rectangle((124, 56, 132, 84), fill=(255, 255, 255, 255))
    draw.polygon([(128, 36), (140, 56), (116, 56)], fill=(255, 255, 255, 255))

def runner(draw):
    # Stylised running figure. Stands in for Mario/Jazz-style platformers.
    draw.ellipse((104, 36, 152, 84), fill=(255, 255, 255, 255))                # head
    draw.polygon([(120, 84), (136, 84), (148, 168), (108, 168)], fill=(255, 255, 255, 255))   # torso
    draw.polygon([(108, 168), (136, 168), (88, 224), (60, 220)],   fill=(255, 255, 255, 255)) # back leg
    draw.polygon([(132, 168), (160, 168), (184, 224), (160, 224)], fill=(255, 255, 255, 255)) # front leg
    draw.polygon([(148, 88), (164, 96), (200, 132), (188, 144)],   fill=(255, 255, 255, 255)) # arm

GLYPHS = {
    "gzdoom":       crosshair,
    "prboom":       crosshair,
    "eduke32":      crosshair,
    "devilutionx":  sword,
    "fallout1-ce":  crosshair,
    "fallout2-ce":  crosshair,
    "mrboom":       bomb,
    "openjazz":     runner,
}

def main():
    OUT.mkdir(parents=True, exist_ok=True)
    for shortname, glyph_fn in GLYPHS.items():
        img = Image.new("RGBA", (256, 256), (0, 0, 0, 0))
        draw = ImageDraw.Draw(img)
        glyph_fn(draw)
        path = OUT / f"{shortname}.png"
        img.save(path)
        print(f"wrote {path}")

if __name__ == "__main__":
    main()
