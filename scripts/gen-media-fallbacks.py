"""Generate 7 PSP-XMB-style filled-silhouette media-fallback icons.

Used when a game in the gamecarousel has no scraped thumbnail. The
glyph is system-media-typical (disc, cart, floppy, etc.). All 256x256
filled white on transparent. Pre-burned shadow is applied later by
scripts/apply-shadow.py (PR A) — these are flat alpha sources.

Run from repo root:
    python3 scripts/gen-media-fallbacks.py
"""
from PIL import Image, ImageDraw
from pathlib import Path

OUT = Path("art/system-media")

def cd(draw):
    # Optical disc: outer ring + center hole.
    draw.ellipse((28, 28, 228, 228), fill=(255, 255, 255, 255))
    draw.ellipse((108, 108, 148, 148), fill=(0, 0, 0, 0))   # center hole

def cartridge(draw):
    # SNES-style cartridge: rectangle with top label notch.
    draw.rectangle((40, 60, 216, 196), fill=(255, 255, 255, 255))
    # Cutout for label notch top
    draw.rectangle((60, 60, 196, 92), fill=(0, 0, 0, 0))
    # Re-add bottom corners as squared outline by filling small triangles
    draw.rectangle((40, 84, 60, 196), fill=(255, 255, 255, 255))
    draw.rectangle((196, 84, 216, 196), fill=(255, 255, 255, 255))

def floppy(draw):
    # 3.5" floppy: square with metal shutter notch on top.
    draw.rectangle((40, 40, 216, 216), fill=(255, 255, 255, 255))
    draw.rectangle((80, 56, 176, 100), fill=(0, 0, 0, 0))   # metal shutter cutout
    draw.rectangle((100, 56, 156, 88), fill=(255, 255, 255, 255))  # shutter window
    draw.rectangle((68, 132, 188, 200), fill=(0, 0, 0, 0))  # label panel cutout
    draw.rectangle((76, 140, 180, 192), fill=(255, 255, 255, 255))  # label panel face

def handheld_cart(draw):
    # Game Boy-style cartridge: rectangle with diagonal corner.
    draw.polygon([
        (60, 40), (216, 40), (216, 216), (60, 216), (40, 200), (40, 56)
    ], fill=(255, 255, 255, 255))

def arcade_board(draw):
    # Arcade PCB: rectangle with chip array.
    draw.rectangle((28, 80, 228, 176), fill=(255, 255, 255, 255))
    for x in (60, 100, 140, 180):
        draw.rectangle((x - 12, 108, x + 12, 148), fill=(0, 0, 0, 0))

def computer(draw):
    # Floppy + monitor combo: simplified PC monitor outline.
    draw.rectangle((40, 48, 216, 176), fill=(255, 255, 255, 255))
    draw.rectangle((56, 64, 200, 160), fill=(0, 0, 0, 0))    # screen
    draw.rectangle((92, 176, 164, 200), fill=(255, 255, 255, 255))   # stand
    draw.rectangle((68, 200, 188, 216), fill=(255, 255, 255, 255))   # base

def default(draw):
    # Generic ROM placeholder: rounded rectangle.
    draw.rounded_rectangle((48, 48, 208, 208), radius=20, fill=(255, 255, 255, 255))
    draw.rounded_rectangle((72, 72, 184, 184), radius=10, fill=(0, 0, 0, 0))

GLYPHS = {
    "cd":            cd,
    "cartridge":     cartridge,
    "floppy":        floppy,
    "handheld-cart": handheld_cart,
    "arcade-board":  arcade_board,
    "computer":      computer,
    "_default":      default,
}

def main():
    OUT.mkdir(parents=True, exist_ok=True)
    for name, fn in GLYPHS.items():
        img = Image.new("RGBA", (256, 256), (0, 0, 0, 0))
        fn(ImageDraw.Draw(img))
        path = OUT / f"{name}.png"
        img.save(path)
        print(f"wrote {path}")

if __name__ == "__main__":
    main()
