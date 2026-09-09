#!/usr/bin/env python3
"""gen-help-icons.py — generate the helpsystem button glyphs (audit S4, #8).

Mirrors the procedural-asset pattern of scripts/gen-chevrons.py,
scripts/gen-halo.py and scripts/gen-battery-icons.py. Writes into art/help/.

Re-run after editing this script:
  python3 scripts/gen-help-icons.py

WHAT GETS GENERATED
-------------------
Face buttons, per glyph set:
  psp-cross.png  psp-circle.png  psp-square.png  psp-triangle.png
  btn-a.png      btn-b.png       btn-x.png       btn-y.png

  The four lettered glyphs serve BOTH the Nintendo and the Xbox sets. The two
  layouts use identical artwork and differ only in which physical button each
  letter sits on, so the difference lives entirely in the slot assignment made
  by _inc/buttons-nintendo.xml vs _inc/buttons-xbox.xml — not in the pixels.
  That is why three selectable sets cost eight face PNGs rather than twelve.

Shared, layout-independent (one copy, referenced by all three sets):
  dpad-updown.png  dpad-leftright.png  dpad-all.png
  shoulder-l.png   shoulder-r.png
  btn-start.png    btn-select.png      key-f1.png

  These are declared directly on <helpsystem> in _inc/common.xml and
  _inc/gamelist-grid.xml rather than routed through the subset: a d-pad is a
  d-pad on all three platforms. Shoulders stay "L"/"R" rather than becoming
  "LB"/"RB" for the Xbox set — two glyphs' worth of extra art to render a
  two-character label into a ~19px-tall box, which does not survive the
  downscale. The TrimUI Brick's shoulders are silkscreened L/R regardless.

SIZING
------
Source canvases are 128x128 (the pill-shaped buttons are 128x80). ES ignores
the source dimensions and rescales every help icon to
`font->getLetterHeight() * 1.25` px, preserving aspect
(HelpComponent.cpp:updateGrid -> icon->setResize(0, height)). At this theme's
helpsystem fontSize of 0.025 that is ~19px tall on the device's 768px-high
panel. Authoring at 128 and letting ES downscale — with linear filtering, which
HelpComponent switches on explicitly (icon->setIsLinear(true)) — gives a
cleaner result than authoring at final size, and holds up on a 1080p panel too.

Everything is drawn WHITE on transparent. ES tints each icon with the
helpsystem's <iconColor> via ImageComponent::setColorShift, which multiplies —
so a coloured source can only ever come out darker. That rules out the
colour-coded Xbox face buttons (green A / red B / blue X / yellow Y): they
would multiply against ${helpAccent} into four muddy variations of one hue.
Monochrome line art is also what §5.1 of the style guide asks for.
"""

from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent.parent
OUT_DIR = ROOT / "art" / "help"
FONT_PATH = ROOT / "fonts" / "RobotoCondensed-Bold.ttf"

SQUARE = (128, 128)
PILL = (128, 80)

# Stroke weight at 128px source. 8px reads as a ~1.2px hairline once ES scales
# the glyph down to ~19px, which matches the line weight of the shipped
# chevrons (art/ui/chevron-*.png) at their rendered size.
STROKE = 8
WHITE = (255, 255, 255, 255)


def _canvas(size):
    img = Image.new("RGBA", size, (0, 0, 0, 0))
    return img, ImageDraw.Draw(img)


def _centered_text(draw, box, text, font):
    """Draw `text` centered inside `box` = (x0, y0, x1, y1)."""
    x0, y0, x1, y1 = box
    left, top, right, bottom = draw.textbbox((0, 0), text, font=font)
    x = x0 + ((x1 - x0) - (right - left)) / 2 - left
    y = y0 + ((y1 - y0) - (bottom - top)) / 2 - top
    draw.text((x, y), text, font=font, fill=WHITE)


# --- PSP face buttons -------------------------------------------------------
# Drawn as the bare symbols, with no enclosing ring. That is how the PSP itself
# renders them in XMB help text, and it keeps this set visually distinct from
# the two lettered sets, which need a ring to read as buttons at all.

def psp_circle(path):
    img, d = _canvas(SQUARE)
    d.ellipse([20, 20, 108, 108], outline=WHITE, width=STROKE)
    img.save(path, "PNG")


def psp_cross(path):
    img, d = _canvas(SQUARE)
    d.line([26, 26, 102, 102], fill=WHITE, width=STROKE)
    d.line([102, 26, 26, 102], fill=WHITE, width=STROKE)
    img.save(path, "PNG")


def psp_square(path):
    img, d = _canvas(SQUARE)
    d.rectangle([26, 26, 102, 102], outline=WHITE, width=STROKE)
    img.save(path, "PNG")


def psp_triangle(path):
    img, d = _canvas(SQUARE)
    # Optically centered: an equilateral triangle in a square box sits low, so
    # the apex starts at 22 rather than 26 and the base ends at 100.
    d.polygon([(64, 22), (104, 100), (24, 100)], outline=WHITE, width=STROKE)
    img.save(path, "PNG")


# --- Lettered face buttons (Nintendo + Xbox) --------------------------------

def lettered_button(path, letter):
    img, d = _canvas(SQUARE)
    d.ellipse([12, 12, 116, 116], outline=WHITE, width=STROKE)
    font = ImageFont.truetype(str(FONT_PATH), 76)
    _centered_text(d, (12, 12, 116, 116), letter, font)
    img.save(path, "PNG")


# --- Shoulders, start/select, F1 -------------------------------------------

def _pill(draw, box, radius):
    draw.rounded_rectangle(box, radius=radius, outline=WHITE, width=STROKE)


def shoulder(path, letter):
    img, d = _canvas(PILL)
    _pill(d, [8, 8, 120, 72], 26)
    font = ImageFont.truetype(str(FONT_PATH), 46)
    _centered_text(d, (8, 8, 120, 72), letter, font)
    img.save(path, "PNG")


def start_button(path):
    """Pill with a right-pointing triangle."""
    img, d = _canvas(PILL)
    _pill(d, [8, 8, 120, 72], 26)
    d.polygon([(52, 26), (52, 54), (80, 40)], fill=WHITE)
    img.save(path, "PNG")


def select_button(path):
    """Pill with a filled dot.

    START and SELECT are physically the same small oval on a PSP and on the
    Brick, distinguished only by the word engraved on them — which does not
    survive the downscale to ~19px. The two inner marks exist purely to make
    the silhouettes tell apart at a glance; ES already prints a text label
    ("MENU", "OPTIONS") next to every glyph, so the glyph only has to identify
    the button, not describe the action.
    """
    img, d = _canvas(PILL)
    _pill(d, [8, 8, 120, 72], 26)
    d.ellipse([52, 28, 78, 54], fill=WHITE)
    img.save(path, "PNG")


def f1_key(path):
    """Keyboard F1 — ES's file-manager prompt. Squarer than a gamepad pill."""
    img, d = _canvas(PILL)
    _pill(d, [16, 8, 112, 72], 14)
    font = ImageFont.truetype(str(FONT_PATH), 40)
    _centered_text(d, (16, 8, 112, 72), "F1", font)
    img.save(path, "PNG")


# --- Directional ------------------------------------------------------------
# Chevrons rather than a d-pad cross: the style guide calls for "directional
# pad chevrons" (§5.4), and the theme already speaks that language in
# art/ui/chevron-{up,down}.png.

def _chevron(draw, cx, cy, size, direction):
    """A solid chevron pointing `direction`, apex `size`/2 from (cx, cy).

    Filled rather than an outlined "V" on purpose. art/ui/chevron-{up,down}.png
    — the theme's existing scroll affordance, from gen-chevrons.py — are solid
    triangles, and at the ~19px ES renders these at, an open stroke of the same
    weight closes up into a blob anyway.
    """
    h = size / 2
    w = size * 0.42          # half-width of the base
    if direction == "up":
        pts = [(cx, cy - h), (cx - w, cy + h * 0.6), (cx + w, cy + h * 0.6)]
    elif direction == "down":
        pts = [(cx, cy + h), (cx - w, cy - h * 0.6), (cx + w, cy - h * 0.6)]
    elif direction == "left":
        pts = [(cx - h, cy), (cx + h * 0.6, cy - w), (cx + h * 0.6, cy + w)]
    elif direction == "right":
        pts = [(cx + h, cy), (cx - h * 0.6, cy - w), (cx - h * 0.6, cy + w)]
    else:
        raise ValueError(f"unknown direction: {direction}")
    draw.polygon(pts, fill=WHITE)


def dpad_updown(path):
    img, d = _canvas(SQUARE)
    _chevron(d, 64, 34, 56, "up")
    _chevron(d, 64, 94, 56, "down")
    img.save(path, "PNG")


def dpad_leftright(path):
    img, d = _canvas(SQUARE)
    _chevron(d, 34, 64, 56, "left")
    _chevron(d, 94, 64, 56, "right")
    img.save(path, "PNG")


def dpad_all(path):
    """Four chevrons around a hollow centre.

    The gap is the whole design problem here. An earlier pass used the same
    56px chevrons as the two-way glyphs at centres 30/98, and adjacent apexes
    landed ~1px apart — the four merged into a single diamond outline, which is
    not what "up/down/left/right" should look like. 40px chevrons pushed out to
    centres 26/102 leave a clear cross-shaped void that survives the downscale.
    """
    img, d = _canvas(SQUARE)
    _chevron(d, 64, 26, 40, "up")
    _chevron(d, 64, 102, 40, "down")
    _chevron(d, 26, 64, 40, "left")
    _chevron(d, 102, 64, 40, "right")
    img.save(path, "PNG")


def assert_valid(path):
    """Guard against the failure mode that is invisible in a render: a glyph
    that is fully transparent still draws as 'nothing', which looks exactly
    like ES falling back to its built-in icon."""
    with Image.open(path) as img:
        if img.mode != "RGBA":
            raise AssertionError(f"{path.name}: mode {img.mode}, expected RGBA")
        alpha = img.getchannel("A")
        opaque = sum(count for value, count in
                     zip(range(256), alpha.histogram()) if value > 0)
        if opaque == 0:
            raise AssertionError(f"{path.name}: fully transparent")
        coverage = opaque / (img.width * img.height)
        if coverage > 0.75:
            raise AssertionError(
                f"{path.name}: {coverage:.0%} opaque — a filled block, not line art")


def main():
    OUT_DIR.mkdir(parents=True, exist_ok=True)

    psp_circle(OUT_DIR / "psp-circle.png")
    psp_cross(OUT_DIR / "psp-cross.png")
    psp_square(OUT_DIR / "psp-square.png")
    psp_triangle(OUT_DIR / "psp-triangle.png")

    for letter in ("A", "B", "X", "Y"):
        lettered_button(OUT_DIR / f"btn-{letter.lower()}.png", letter)

    shoulder(OUT_DIR / "shoulder-l.png", "L")
    shoulder(OUT_DIR / "shoulder-r.png", "R")
    start_button(OUT_DIR / "btn-start.png")
    select_button(OUT_DIR / "btn-select.png")
    f1_key(OUT_DIR / "key-f1.png")

    dpad_updown(OUT_DIR / "dpad-updown.png")
    dpad_leftright(OUT_DIR / "dpad-leftright.png")
    dpad_all(OUT_DIR / "dpad-all.png")

    written = sorted(OUT_DIR.glob("*.png"))
    for path in written:
        assert_valid(path)
    print(f"wrote and validated {len(written)} glyphs in {OUT_DIR}")


if __name__ == "__main__":
    main()
