#!/usr/bin/env python3
"""gen-splash-wordmark.py — generate the boot splash lockup (issue #10).

Mirrors the procedural-asset pattern of scripts/gen-battery-icons.py and
scripts/gen-chevrons.py. Produces:
  art/ui/splash-wordmark.png — "XMB for EmulationStation" over a hairline
                               rule, with the theme name beneath it

Re-run after editing this script:
  python3 scripts/gen-splash-wordmark.py

WHY THIS IS AN IMAGE AND NOT A <text> ELEMENT
---------------------------------------------
The approved design is letterspaced. EmulationStation has no letterspacing
property — TextComponent::applyTheme handles alignment, lineSpacing, glow,
autoScroll and colour, and nothing anywhere in es-core sets per-character
advance. Faking it with literal spaces ("X M B  f o r") wrecks word spacing
and hyphenation, so the lockup is drawn here instead, where tracking is just
arithmetic.

It also turns out to be the more robust choice across the five shipped aspect
ratios. A <text> element's fontSize is a fraction of screen HEIGHT, so on the
squarer ratios the string grows relative to a narrower screen and overruns it:
this wordmark at 0.075 height renders 100% of screen width at 1:1 (720x720).
As an image with <maxSize>, the same lockup fits itself to whatever box it is
given, at every ratio, with no per-ratio overrides.

WHY THE INK IS PURE WHITE
-------------------------
The theme tints this at runtime with <color>${textPrimary}</color> so the
splash tracks the user's chosen colorset. ES's <color> MULTIPLIES the texture's
RGB and leaves its alpha alone, so any ink that is not white would darken the
tint — grey ink under a blue tint comes out muddy, not blue. Every tone
difference in this lockup therefore lives in the ALPHA channel: the descriptor
is not a dimmer grey, it is white at lower alpha.

That is also why the text is composited through an L-mode mask rather than
drawn straight onto an RGBA canvas. Drawing white-with-alpha directly lets
PIL blend RGB toward the transparent black background at glyph edges, leaving
dark antialiasing fringes that the multiply would then bake in.
"""

from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

REPO_ROOT = Path(__file__).resolve().parent.parent
FONT_DIR = REPO_ROOT / "fonts"
OUT_PATH = REPO_ROOT / "art" / "ui" / "splash-wordmark.png"

WORDMARK = "XMB for EmulationStation"
DESCRIPTOR = "es-theme-xmb-psp"

# Authored at 2x the largest size it is drawn at (0.78 of a 1024px-wide screen
# is ~800px), so the on-screen lockup is always downsampled, never stretched.
WORDMARK_PX = 116
DESCRIPTOR_PX = 43
WORDMARK_TRACKING = 17          # extra advance per character, in px
DESCRIPTOR_TRACKING = 8
RULE_H = 2

# Alpha, not colour — see the module docstring.
WORDMARK_ALPHA = 0.95
RULE_ALPHA = 0.45
DESCRIPTOR_ALPHA = 0.62

GAP_ABOVE_RULE = 34
GAP_BELOW_RULE = 26
PAD = 8                         # keeps antialiasing off the texture edge


def tracked_mask(text: str, font: ImageFont.FreeTypeFont, tracking: int) -> Image.Image:
    """Render `text` to an L-mode mask, one glyph at a time, adding `tracking`
    px of advance between glyphs. ES cannot do this; PIL will not do it either,
    hence the per-character loop."""
    probe = ImageDraw.Draw(Image.new("L", (1, 1)))
    widths = [probe.textlength(ch, font=font) for ch in text]
    total = int(sum(widths) + tracking * (len(text) - 1))
    ascent, descent = font.getmetrics()
    mask = Image.new("L", (total, ascent + descent), 0)
    draw = ImageDraw.Draw(mask)
    x = 0.0
    for ch, w in zip(text, widths):
        draw.text((x, 0), ch, font=font, fill=255)
        x += w + tracking
    return mask


def scale_alpha(mask: Image.Image, factor: float) -> Image.Image:
    return mask.point(lambda v: int(v * factor))


# Pillow picks its text layout engine from what it was BUILT with: Raqm if the
# wheel bundles it, basic layout if not. The two rasterize the same glyphs at
# the same size to different pixels, so "regenerate and diff" -- which
# test-splash.sh asserts byte-for-byte -- silently depended on which Pillow the
# person running it happened to have. Raqm-enabled builds (the pip manylinux
# wheels, and Debian/Ubuntu's python3-pil) emit 18573 bytes; builds without it
# emit the committed 18585, and CI found this the first time it ran.
#
# Pinning to BASIC costs nothing here. Raqm exists for complex-script shaping --
# ligatures, bidi, cursive joining -- and tracked_mask() below draws ONE
# CHARACTER AT A TIME so it can apply letter tracking, which defeats shaping by
# construction. There is no shaping to lose.
LAYOUT = ImageFont.Layout.BASIC


def main() -> None:
    light = ImageFont.truetype(
        str(FONT_DIR / "RobotoCondensed-Light.ttf"), WORDMARK_PX, layout_engine=LAYOUT
    )
    regular = ImageFont.truetype(
        str(FONT_DIR / "RobotoCondensed-Regular.ttf"), DESCRIPTOR_PX, layout_engine=LAYOUT
    )

    word = scale_alpha(tracked_mask(WORDMARK, light, WORDMARK_TRACKING), WORDMARK_ALPHA)
    desc = scale_alpha(tracked_mask(DESCRIPTOR, regular, DESCRIPTOR_TRACKING), DESCRIPTOR_ALPHA)

    # The rule spans the wordmark, which is the widest element and so sets the
    # lockup's width. Everything else centres on it.
    rule_w = word.width
    width = rule_w + 2 * PAD
    height = PAD + word.height + GAP_ABOVE_RULE + RULE_H + GAP_BELOW_RULE + desc.height + PAD

    alpha = Image.new("L", (width, height), 0)
    y = PAD
    alpha.paste(word, (PAD, y))
    y += word.height + GAP_ABOVE_RULE
    rule = Image.new("L", (rule_w, RULE_H), int(255 * RULE_ALPHA))
    alpha.paste(rule, (PAD, y))
    y += RULE_H + GAP_BELOW_RULE
    alpha.paste(desc, (PAD + (rule_w - desc.width) // 2, y))

    # Pure white everywhere; the mask above is the only thing that varies.
    white = Image.new("RGB", (width, height), (255, 255, 255))
    out = Image.merge("RGBA", (*white.split(), alpha))

    OUT_PATH.parent.mkdir(parents=True, exist_ok=True)
    out.save(OUT_PATH)
    print(f"wrote {OUT_PATH.relative_to(REPO_ROOT)} ({width}x{height}, aspect {width/height:.2f}:1)")


if __name__ == "__main__":
    main()
