"""Draw the placeholder Spellbook icon: an open book whose pages glow.

Writes assets/spellbook.ico (16, 20, 24, 32, 40, 48, 64, 256 px) and
assets/spellbook-256.png. This is a placeholder until a designed icon lands
(todo/05-ship/TODO-02 §1); rerun it after changing the drawing:

    python scripts/generate-icon.py

Needs Pillow (pip install pillow). Not part of any gate: the outputs are committed.
"""
from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parent.parent
ASSETS = ROOT / "assets"
CANVAS = 1024

COVER = (74, 44, 122, 255)        # deep violet
COVER_EDGE = (46, 26, 82, 255)
PAGE = (250, 244, 228, 255)       # parchment
PAGE_SHADE = (226, 214, 188, 255)
GLOW = (255, 196, 92)             # warm gold
TEXT = (232, 160, 60, 255)


def draw() -> Image.Image:
    img = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))

    # Soft glow rising from the pages.
    glow = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
    g = ImageDraw.Draw(glow)
    g.ellipse((212, 150, 812, 700), fill=GLOW + (190,))
    glow = glow.filter(ImageFilter.GaussianBlur(90))
    img.alpha_composite(glow)

    d = ImageDraw.Draw(img)
    # Cover, slightly wider than the pages.
    d.rounded_rectangle((96, 380, 928, 860), radius=48, fill=COVER, outline=COVER_EDGE, width=16)
    # Left and right pages, curving down to the spine.
    d.polygon([(140, 330), (500, 400), (500, 820), (140, 760)], fill=PAGE)
    d.polygon([(884, 330), (524, 400), (524, 820), (884, 760)], fill=PAGE)
    d.polygon([(140, 760), (500, 820), (500, 836), (140, 780)], fill=PAGE_SHADE)
    d.polygon([(884, 760), (524, 820), (524, 836), (884, 780)], fill=PAGE_SHADE)
    # Spine.
    d.rectangle((500, 396, 524, 840), fill=COVER_EDGE)
    # Glowing lines of text.
    for i, y in enumerate(range(440, 720, 56)):
        inset = 24 if i % 2 else 0
        d.line([(196 + inset, y + (y - 440) // 12), (452, y + 36 + (y - 440) // 12)], fill=TEXT, width=22)
        d.line([(828 - inset, y + (y - 440) // 12), (572, y + 36 + (y - 440) // 12)], fill=TEXT, width=22)
    # A spark above the spine.
    d.polygon([(512, 120), (540, 210), (630, 238), (540, 266), (512, 356), (484, 266), (394, 238), (484, 210)],
              fill=(255, 236, 170, 255))
    return img


def main() -> None:
    ASSETS.mkdir(exist_ok=True)
    art = draw()
    art.resize((256, 256), Image.LANCZOS).save(ASSETS / "spellbook-256.png")
    sizes = [(s, s) for s in (16, 20, 24, 32, 40, 48, 64, 256)]
    art.save(ASSETS / "spellbook.ico", sizes=sizes)
    print(f"wrote {ASSETS / 'spellbook.ico'} and {ASSETS / 'spellbook-256.png'}")


if __name__ == "__main__":
    main()
