"""Add a subtle PSP-XMB-style drop shadow to every PNG in art/system-icons/.

Shadow parameters (settled by audit S3):
  - 4px Gaussian blur
  - 3px Y-offset (positive = downward)
  - 35% black alpha (rgba 0,0,0,89)

Idempotent: re-running will compound shadows. Run ONCE after icon
adoption (PR A Task 3) and icon authoring (PR A Task 4); commit; never
rerun without resetting the icons.

Run from repo root:
    python3 scripts/apply-shadow.py
"""
from PIL import Image, ImageFilter
from pathlib import Path

ICON_DIR = Path("art/system-icons")
BLUR_RADIUS = 4
Y_OFFSET = 3
SHADOW_ALPHA = 89  # 0.35 * 255 rounded

def add_shadow(src_path: Path):
    img = Image.open(src_path).convert("RGBA")
    alpha = img.split()[3]
    shadow = Image.new("RGBA", img.size, (0, 0, 0, 0))
    shadow_mask = Image.new("L", img.size, 0)
    shadow_mask.paste(alpha, (0, Y_OFFSET))
    shadow_mask = shadow_mask.filter(ImageFilter.GaussianBlur(BLUR_RADIUS))
    shadow.putalpha(shadow_mask.point(lambda p: min(p, SHADOW_ALPHA)))
    composite = Image.alpha_composite(shadow, img)
    composite.save(src_path)

def main():
    icons = sorted(ICON_DIR.glob("*.png"))
    print(f"applying shadow to {len(icons)} icons")
    for path in icons:
        add_shadow(path)
    print("done")

if __name__ == "__main__":
    main()
