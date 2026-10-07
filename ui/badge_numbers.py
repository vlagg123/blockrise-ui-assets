"""BlockRise Empire - the numbers on the red notification badges (2026-10-08).

Roblox's own text drawing put the badge numbers a pixel or two off the middle of the red circle (more with an
outline, and different on every screen size), so the numbers are pictures: 1..9 and +9, white Fredoka One with an
ink outline, each one centred on its cell by its own pixels.

    python3 ui/badge_numbers.py <FredokaOne.ttf>      ->  ui/badge_numbers.png  (5 x 2 cells of 128 px)

Font: Fredoka One (OFL), e.g. `npm pack @fontsource/fredoka-one` and convert the woff to ttf with fontTools.
A cell is the whole 28 px badge (scale 128 / 28): the number is as big as the old TextSize 18 label with a 1.5 px
outline. Cells, left to right, top to bottom: 1 2 3 4 5 / 6 7 8 9 +9 (UIKit.BADGE_CELL).
Centring: by the ink box, and for a single digit half way to its centre of mass (a "1" or a "7" then looks centred,
not pushed to the side of its flag).
"""
import os
import sys
from PIL import Image, ImageDraw, ImageFont

LABELS = ["1", "2", "3", "4", "5", "6", "7", "8", "9", "+9"]
CELL, COLS = 128, 5
SS = 4  # supersampling
INK = (20, 17, 32)
BADGE_PX = 28.0
TEXT_SIZE = 18.0  # the old label: Roblox TextSize = the line height (ascender + descender = 1.21 em)
OUTLINE = 1.5


def render(font_path, out):
    k = CELL * SS / BADGE_PX                       # supersampled px per badge px
    em = TEXT_SIZE / 1.21 * k
    font = ImageFont.truetype(font_path, round(em))
    sw = round(OUTLINE * k)
    rows = (len(LABELS) + COLS - 1) // COLS
    atlas = Image.new("RGBA", (CELL * COLS, CELL * rows), INK + (0,))
    report = []
    for i, t in enumerate(LABELS):
        big = CELL * SS
        # draw on a wide canvas, find the ink, then place it so its centre is the cell's centre
        tmp = Image.new("RGBA", (big * 2, big * 2), INK + (0,))
        ImageDraw.Draw(tmp).text((big // 2, big // 2), t, font=font, fill=(255, 255, 255, 255),
                                 stroke_width=sw, stroke_fill=INK + (255,))
        a = tmp.getchannel("A")
        x0, y0, x1, y1 = a.getbbox()
        cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
        if len(t) == 1:
            # centre of mass of the ink (x only)
            w, h = a.size
            px = a.load()
            sm = sx = 0
            for y in range(y0, y1):
                for x in range(x0, x1):
                    v = px[x, y]
                    if v:
                        sm += v
                        sx += v * x
            cx = (cx + sx / sm) / 2
        dx, dy = round(big / 2 - cx), round(big / 2 - cy)
        cell = tmp.crop((-dx, -dy, -dx + big, -dy + big))
        # premultiplied downscale (no dark or light fringes)
        small = cell.convert("RGBa").resize((CELL, CELL), Image.LANCZOS).convert("RGBA")
        # fully clear pixels keep the ink colour (Roblox filters the colour of clear pixels too)
        px = small.load()
        for y in range(CELL):
            for x in range(CELL):
                if px[x, y][3] == 0:
                    px[x, y] = INK + (0,)
        atlas.paste(small, ((i % COLS) * CELL, (i // COLS) * CELL))
        bb = small.getchannel("A").point(lambda v: 255 if v > 24 else 0).getbbox()
        report.append("%-3s ink box %s centre (%.1f, %.1f)" % (t, bb, (bb[0] + bb[2]) / 2, (bb[1] + bb[3]) / 2))
    atlas.save(out)
    return report


if __name__ == "__main__":
    here = os.path.dirname(os.path.abspath(__file__))
    for line in render(sys.argv[1], os.path.join(here, "badge_numbers.png")):
        print(line)
