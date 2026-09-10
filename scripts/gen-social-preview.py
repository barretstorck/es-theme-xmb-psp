#!/usr/bin/env python3
"""gen-social-preview.py — generate the repository's social preview card.

Mirrors the procedural-asset pattern of scripts/gen-splash-wordmark.py. Produces:
  docs/social-preview.png — 1280x640, the card GitHub renders whenever this
                            repository is linked anywhere.

Re-run after editing this script:
  python3 scripts/gen-social-preview.py

WHY THIS EXISTS AT ALL
----------------------
GitHub's default card is the owner's avatar, a truncated description and the
star count. For a repository whose entire value is visual that is the worst
possible asset: every link posted to Reddit, a forum or a Discord leads with a
photograph of a person and the number 0. This replaces it with the theme.

WHY IT LIVES IN docs/ AND NOT art/
----------------------------------
`art/` ships. .gitattributes trims the install archive to the theme payload ES
actually loads, and `art/` is part of that payload, so anything put there lands
on every user's SD card. This card has no runtime use — it exists only for
GitHub — and `docs/` is already export-ignore'd. Putting it in `art/` would add
~120 KB to every install for nothing.

WHY THE SWATCHES ARE SAMPLED, NOT HARD-CODED
--------------------------------------------
The twelve colour chips are sampled from docs/screenshots/colorsets/*.png at
generation time, picking each colorset's most chromatic pixel. That means the
card tracks the colorsets: change a colorset, re-render its screenshot, re-run
this, and the chips follow. A hard-coded palette would drift from the theme
silently, which is the same failure mode the no-dead-variables gate exists for.

They are sampled from the upper-middle band of each tile, NOT the bottom. The
bottom of the wave is the darkest part of its gradient, and sampling there
produced muddy chips that read as grey-ish at thumbnail size.

WHY THE LOCKUP IS REBUILT HERE RATHER THAN art/ui/splash-wordmark.png PASTED IN
------------------------------------------------------------------------------
The splash wordmark bakes a hairline rule between the title and the theme name.
This card puts the colour chips in that slot instead, so the rule has to go —
and it cannot be removed from a flattened PNG without leaving a scar. The
lockup is therefore reconstructed from the same constants the splash generator
uses, so the typography stays identical to the boot splash: same face, same
tracking, same alpha relationship between title and descriptor.

Unlike the splash, the ink here is NOT constrained to pure white. The splash is
tinted at runtime by ES's <color>, which multiplies; this card is composited
once onto a fixed background, so the chips can carry real colour.

WHY THE LAYOUT ENGINE IS PINNED
-------------------------------
Same trap as gen-splash-wordmark.py: Pillow selects Raqm or basic layout from
what it was BUILT with, and the two rasterize identical glyphs to different
pixels. tracked_text() draws one character at a time to apply tracking, which
defeats shaping anyway, so BASIC costs nothing and keeps output stable across
Pillow builds.

Note that this card is deliberately NOT asserted byte-for-byte by the test
suite, unlike the splash wordmark. It resamples photographic gradients with
LANCZOS, and resampling is far more likely to shift between Pillow releases
than glyph rasterization is. A byte-for-byte gate here would be a tripwire for
Pillow upgrades rather than a guard against real drift.
"""

from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

REPO_ROOT = Path(__file__).resolve().parent.parent
FONT_DIR = REPO_ROOT / "fonts"
SHOTS = REPO_ROOT / "docs" / "screenshots"
OUT_PATH = REPO_ROOT / "docs" / "social-preview.png"

# GitHub renders social previews at 1280x640 and rejects anything over 1 MB.
CARD_W, CARD_H = 1280, 640

# The background is the 16:9 system view. The source is 1280x720, so 80 is the
# largest possible top crop — it lifts the icon row and the "GB" label as far
# out of the lockup's way as the screenshot allows.
BACKGROUND = SHOTS / "system-16x9.png"
CROP_TOP = 80

# --- lockup, sharing gen-splash-wordmark.py's typography ---------------------
WORDMARK = "XMB for EmulationStation"
DESCRIPTOR = "es-theme-xmb-psp"
WORDMARK_PX = 116
DESCRIPTOR_PX = 43
WORDMARK_TRACKING = 17
DESCRIPTOR_TRACKING = 8
WORDMARK_ALPHA = 0.95
DESCRIPTOR_ALPHA = 0.62
PAD = 8

# The splash's rule is 2px. The chips that replace it render ~9px on the card,
# four times that visual weight, so the splash's 34/26 gaps left the descriptor
# looking crowded against them. Widened to suit the heavier divider.
GAP_ABOVE_BAR = 44
GAP_BELOW_BAR = 38
SWATCH_H = 20
SWATCH_GAP = 10
SWATCH_RADIUS = 6

# Authored at 1572px wide (the wordmark's natural tracked width) and downsampled
# to this, so the type is never rendered small or stretched.
LOCKUP_W = 900

# Vertical anchor, as a fraction of card height, for the CENTRE of the chip row.
# The lockup hangs off this: the title sits above the chips, so this number sets
# where the title lands too. Below ~0.58 the title collides with the "GB" label;
# at 0.70 it straddles the wave crest and the crest line cuts through the
# letterforms. 0.75 clears the crest entirely, putting letterspaced Light type on
# smooth gradient, which is what keeps it legible at thumbnail size.
BAR_CENTRE = 0.75

COLORSETS = [
    "january-blue", "february-violet", "march-pink", "april-green",
    "may-yellow-green", "june-yellow", "july-amber", "august-orange",
    "september-red", "october-crimson", "november-slate", "december-aqua",
]

LAYOUT = ImageFont.Layout.BASIC


def tracked_text(text: str, font: ImageFont.FreeTypeFont, tracking: int) -> Image.Image:
    """An L-mode mask of `text` with `tracking` px of extra advance per character."""
    probe = ImageDraw.Draw(Image.new("L", (1, 1)))
    widths = [probe.textlength(ch, font=font) for ch in text]
    total = int(sum(widths) + tracking * (len(text) - 1))
    ascent, descent = font.getmetrics()
    mask = Image.new("L", (total, ascent + descent), 0)
    draw = ImageDraw.Draw(mask)
    x = 0
    for ch, w in zip(text, widths):
        draw.text((x, 0), ch, font=font, fill=255)
        x += int(w) + tracking
    return mask


def scale_alpha(mask: Image.Image, factor: float) -> Image.Image:
    return mask.point(lambda v: int(v * factor))


def colorset_swatch(name: str) -> tuple:
    """The most chromatic pixel in a colorset screenshot — its identity colour.

    Iterates tobytes() rather than getdata(): getdata() is deprecated in Pillow
    12 and removed in 14, and this script should not need editing for that.
    """
    tile = Image.open(SHOTS / "colorsets" / f"{name}.png").convert("RGB")
    band = tile.crop((0, int(tile.height * 0.35), tile.width, int(tile.height * 0.95)))
    band = band.resize((60, 40), Image.LANCZOS)
    raw = band.tobytes()
    best, best_score = (0, 0, 0), -1.0
    for i in range(0, len(raw), 3):
        r, g, b = raw[i] / 255, raw[i + 1] / 255, raw[i + 2] / 255
        hi, lo = max(r, g, b), min(r, g, b)
        sat = 0.0 if hi == 0 else (hi - lo) / hi
        score = sat * 1.6 + hi * 0.6      # chroma first, but keep it bright
        if score > best_score:
            best_score, best = score, (raw[i], raw[i + 1], raw[i + 2])
    return best


def build_lockup() -> tuple:
    """The title / chip row / descriptor stack. Returns (image, chip-row centre y)."""
    light = ImageFont.truetype(
        str(FONT_DIR / "RobotoCondensed-Light.ttf"), WORDMARK_PX, layout_engine=LAYOUT
    )
    regular = ImageFont.truetype(
        str(FONT_DIR / "RobotoCondensed-Regular.ttf"), DESCRIPTOR_PX, layout_engine=LAYOUT
    )
    word = scale_alpha(tracked_text(WORDMARK, light, WORDMARK_TRACKING), WORDMARK_ALPHA)
    desc = scale_alpha(tracked_text(DESCRIPTOR, regular, DESCRIPTOR_TRACKING), DESCRIPTOR_ALPHA)

    # The title is the widest element and sets the lockup's width, exactly as the
    # rule does in the splash. The chip row spans it; the descriptor centres on it.
    bar_w = word.width
    width = bar_w + 2 * PAD
    height = (PAD + word.height + GAP_ABOVE_BAR + SWATCH_H
              + GAP_BELOW_BAR + desc.height + PAD)

    # Text goes down as white through an alpha mask, not as white-with-alpha onto
    # a transparent canvas — the latter blends glyph edges toward the transparent
    # black and leaves dark fringes. Same reasoning as the splash generator.
    ink = Image.new("L", (width, height), 0)
    y = PAD
    ink.paste(word, (PAD, y))
    y += word.height + GAP_ABOVE_BAR
    bar_y = y
    y += SWATCH_H + GAP_BELOW_BAR
    ink.paste(desc, (PAD + (bar_w - desc.width) // 2, y))
    lockup = Image.merge("RGBA", (*Image.new("RGB", (width, height), (255, 255, 255)).split(), ink))

    draw = ImageDraw.Draw(lockup)
    n = len(COLORSETS)
    chip_w = (bar_w - SWATCH_GAP * (n - 1)) / n
    for i, name in enumerate(COLORSETS):
        x = PAD + i * (chip_w + SWATCH_GAP)
        draw.rounded_rectangle(
            [x, bar_y, x + chip_w, bar_y + SWATCH_H],
            radius=SWATCH_RADIUS, fill=colorset_swatch(name) + (255,),
        )
    return lockup, bar_y + SWATCH_H / 2


def main() -> None:
    lockup, bar_offset = build_lockup()
    scale = LOCKUP_W / lockup.width
    lockup = lockup.resize(
        (LOCKUP_W, round(lockup.height * scale)), Image.LANCZOS
    )

    background = Image.open(BACKGROUND).convert("RGB")
    card = background.crop((0, CROP_TOP, CARD_W, CROP_TOP + CARD_H)).convert("RGBA")
    y = round(CARD_H * BAR_CENTRE - bar_offset * scale)
    card.alpha_composite(lockup, ((CARD_W - LOCKUP_W) // 2, y))

    out = card.convert("RGB")
    OUT_PATH.parent.mkdir(parents=True, exist_ok=True)
    out.save(OUT_PATH)
    kb = OUT_PATH.stat().st_size / 1024
    print(f"wrote {OUT_PATH.relative_to(REPO_ROOT)} ({out.width}x{out.height}, {kb:.0f} KB)")
    if kb > 1024:
        raise SystemExit("card exceeds GitHub's 1 MB social-preview limit")


if __name__ == "__main__":
    main()
