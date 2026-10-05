"""BlockRise Empire - UI skin atlas for 9-slice frames (windows, buttons, tiles, pills...).

Everything is drawn in grey-scale so Roblox can tint it with ImageColor3 (white -> the colour, darker greys ->
darker shades of it). The dark ink outline stays dark whatever the tint. Drawn at 4x and downsampled for clean edges.
Cells are 128x128 in a 512x512 atlas; use SliceScale 0.5 in Roblox (so a 40 px radius shows as 20 px).
"""
import math
from PIL import Image, ImageDraw, ImageFilter, ImageChops

SS = 4                      # supersampling
CELL = 128
INK = (20, 17, 32, 255)


def canvas(w=CELL, h=CELL):
    return Image.new("RGBA", (w * SS, h * SS), (0, 0, 0, 0))


def rrect_mask(w, h, r, inset=0):
    m = Image.new("L", (w * SS, h * SS), 0)
    d = ImageDraw.Draw(m)
    i = inset * SS
    d.rounded_rectangle((i, i, w * SS - 1 - i, h * SS - 1 - i), radius=max(1, (r - inset) * SS), fill=255)
    return m


def vgrad(w, h, top, bottom, y0=0, y1=None):
    """vertical grey gradient image (L) from top value to bottom value between rows y0..y1 (in 1x px)"""
    y1 = h if y1 is None else y1
    g = Image.new("L", (w * SS, h * SS), top)
    px = g.load()
    for y in range(h * SS):
        t = min(1, max(0, (y / SS - y0) / max(1, (y1 - y0))))
        v = int(top + (bottom - top) * t)
        for x in range(w * SS):
            px[x, y] = v
    return g


def down(im):
    return im.resize((im.width // SS, im.height // SS), Image.LANCZOS)


def framed(fill_l, r, outline, w=CELL, h=CELL):
    """grey fill inside a rounded rect with an ink outline"""
    out = canvas(w, h)
    outer = rrect_mask(w, h, r)
    inner = rrect_mask(w, h, r, inset=outline)
    ink = Image.new("RGBA", out.size, INK)
    out.paste(ink, (0, 0), outer)
    face = Image.merge("RGBA", (fill_l, fill_l, fill_l, Image.new("L", out.size, 255)))
    out.paste(face, (0, 0), inner)
    return out, inner


def panel():
    # window / card body: soft top-to-bottom shading and a thin bright rim inside the outline
    fill = vgrad(CELL, CELL, 255, 222)
    out, inner = framed(fill, 40, 8)
    rim = ImageChops.subtract(inner, rrect_mask(CELL, CELL, 40, inset=11))
    hl = Image.new("RGBA", out.size, (255, 255, 255, 150))
    out.paste(hl, (0, 0), rim)
    return down(out)


def button():
    # chunky button: face + darker 3D lip at the bottom
    r, o, lip = 32, 7, 16
    fill = vgrad(CELL, CELL, 255, 228, 0, CELL - lip)
    px = fill.load()
    for y in range((CELL - lip - o) * SS, CELL * SS):
        for x in range(CELL * SS):
            px[x, y] = 150
    out, inner = framed(fill, r, o)
    # crisp line between face and lip
    d = ImageDraw.Draw(out)
    y = (CELL - lip - o) * SS
    line = Image.new("L", out.size, 0)
    ImageDraw.Draw(line).rectangle((0, y - 2 * SS, CELL * SS, y), fill=255)
    out.paste(Image.new("RGBA", out.size, (110, 110, 110, 255)), (0, 0), ImageChops.multiply(line, inner))
    return down(out)


def tile():
    # item card: bright centre, soft vignette towards the edges
    fill = Image.new("L", (CELL * SS, CELL * SS), 255)
    px = fill.load()
    c = CELL * SS / 2
    for y in range(CELL * SS):
        for x in range(CELL * SS):
            dx = max(0, abs(x - c) - c * 0.55) / (c * 0.45)
            dy = max(0, abs(y - c) - c * 0.55) / (c * 0.45)
            v = 255 - int(40 * min(1, math.hypot(dx, dy)) ** 1.6)
            px[x, y] = v
    out, inner = framed(fill, 34, 6)
    rim = ImageChops.subtract(inner, rrect_mask(CELL, CELL, 34, inset=9))
    out.paste(Image.new("RGBA", out.size, (255, 255, 255, 170)), (0, 0), rim)
    return down(out)


def gloss():
    # white highlight for the top of buttons / tiles (used untinted, on top)
    out = canvas()
    m = rrect_mask(CELL, CELL, 26, inset=10)
    a = vgrad(CELL, CELL, 150, 0, 10, 62)
    alpha = ImageChops.multiply(m, a)
    cut = Image.new("L", out.size, 0)
    ImageDraw.Draw(cut).rectangle((0, 0, CELL * SS, 64 * SS), fill=255)
    alpha = ImageChops.multiply(alpha, cut)
    out.putalpha(alpha)
    out = Image.merge("RGBA", (Image.new("L", out.size, 255),) * 3 + (alpha,))
    return down(out)


def pill():
    fill = vgrad(CELL, CELL, 255, 225)
    out, _ = framed(fill, 30, 6)
    return down(out)


def inset():
    # dark well (progress bar background, text fields): darker at the top, like a hole
    out = canvas()
    m = rrect_mask(CELL, CELL, 24)
    a = vgrad(CELL, CELL, 170, 110)
    out = Image.merge("RGBA", (Image.new("L", out.size, 10),) * 3 + (ImageChops.multiply(m, a),))
    edge = ImageChops.subtract(m, rrect_mask(CELL, CELL, 24, inset=5))
    out.paste(Image.new("RGBA", out.size, (20, 17, 32, 255)), (0, 0), edge)
    return down(out)


def shadow():
    out = Image.new("RGBA", (CELL, CELL), (0, 0, 0, 0))
    m = Image.new("L", (CELL, CELL), 0)
    ImageDraw.Draw(m).rounded_rectangle((16, 16, CELL - 17, CELL - 17), radius=28, fill=190)
    m = m.filter(ImageFilter.GaussianBlur(9))
    out.putalpha(m)
    return out


def circle():
    r, o, lip = 64, 7, 12
    fill = vgrad(CELL, CELL, 255, 225, 0, CELL - lip)
    px = fill.load()
    for y in range((CELL - lip - o) * SS, CELL * SS):
        for x in range(CELL * SS):
            px[x, y] = 150
    out = canvas()
    outer = Image.new("L", out.size, 0)
    ImageDraw.Draw(outer).ellipse((0, 0, CELL * SS - 1, CELL * SS - 1), fill=255)
    inner = Image.new("L", out.size, 0)
    ImageDraw.Draw(inner).ellipse((o * SS, o * SS, (CELL - o) * SS - 1, (CELL - o) * SS - 1), fill=255)
    out.paste(Image.new("RGBA", out.size, INK), (0, 0), outer)
    out.paste(Image.merge("RGBA", (fill, fill, fill, Image.new("L", out.size, 255))), (0, 0), inner)
    return down(out)


def fillbar():
    # progress fill: bright band on the top third
    fill = vgrad(CELL, CELL, 255, 205)
    out = canvas()
    m = rrect_mask(CELL, CELL, 24)
    out = Image.merge("RGBA", (fill, fill, fill, m))
    band = rrect_mask(CELL, CELL, 18, inset=8)
    cut = Image.new("L", out.size, 0)
    ImageDraw.Draw(cut).rectangle((0, 0, CELL * SS, 46 * SS), fill=110)
    out.paste(Image.new("RGBA", out.size, (255, 255, 255, 255)), (0, 0), ImageChops.multiply(band, cut))
    return down(out)


def rays():
    # sunburst behind item art (white, fades out from the centre); used stretched, not sliced
    S = CELL * SS
    out = Image.new("L", (S, S), 0)
    d = ImageDraw.Draw(out)
    n = 14
    c = S / 2
    for i in range(n):
        a0 = (i / n) * 2 * math.pi
        a1 = a0 + math.pi / n * 0.9
        d.polygon([(c, c), (c + math.cos(a0) * S, c + math.sin(a0) * S), (c + math.cos(a1) * S, c + math.sin(a1) * S)], fill=255)
    # radial fade
    fade = Image.new("L", (S, S), 0)
    px = fade.load()
    for y in range(S):
        for x in range(S):
            r = math.hypot(x - c, y - c) / c
            px[x, y] = int(255 * max(0, 1 - r) ** 1.3)
    a = ImageChops.multiply(out, fade)
    im = Image.merge("RGBA", (Image.new("L", (S, S), 255),) * 3 + (a,))
    return down(im)


def glow():
    # soft round light (behind icons, on featured cards)
    S = CELL
    im = Image.new("L", (S, S), 0)
    px = im.load()
    c = S / 2
    for y in range(S):
        for x in range(S):
            r = math.hypot(x + 0.5 - c, y + 0.5 - c) / c
            px[x, y] = int(255 * max(0, 1 - r) ** 2)
    return Image.merge("RGBA", (Image.new("L", (S, S), 255),) * 3 + (im,))


def face():
    # white mask of a button's face (inside the outline, above the lip): carries the moving shine
    r, o, lip = 32, 7, 16
    out = canvas()
    m = Image.new("L", out.size, 0)
    ImageDraw.Draw(m).rounded_rectangle((o * SS, o * SS, (CELL - o) * SS - 1, (CELL - lip - o) * SS - 1), radius=(r - o) * SS, fill=255)
    out = Image.merge("RGBA", (Image.new("L", out.size, 255),) * 3 + (m,))
    return down(out)


def pattern():
    # seamless diagonal stripes, very faint white (tiled over window bodies)
    S = 128
    im = Image.new("RGBA", (S * SS, S * SS), (255, 255, 255, 0))
    d = ImageDraw.Draw(im)
    step = 32 * SS
    w = 12 * SS
    for k in range(-S * SS, 2 * S * SS, step):
        d.polygon([(k, 0), (k + w, 0), (k + w + S * SS, S * SS), (k + S * SS, S * SS)], fill=(255, 255, 255, 255))
    a = im.split()[3].point(lambda v: int(v * 0.22))
    im.putalpha(a)
    return down(im)


CELLS = {
    "panel": (0, 0, panel), "button": (128, 0, button), "tile": (256, 0, tile), "gloss": (384, 0, gloss),
    "pill": (0, 128, pill), "inset": (128, 128, inset), "shadow": (256, 128, shadow), "circle": (384, 128, circle),
    "fill": (0, 256, fillbar), "rays": (128, 256, rays), "glow": (256, 256, glow), "face": (384, 256, face),
}

if __name__ == "__main__":
    import sys, os
    out = sys.argv[1] if len(sys.argv) > 1 else "."
    atlas = Image.new("RGBA", (512, 512), (0, 0, 0, 0))
    for name, (x, y, fn) in CELLS.items():
        atlas.alpha_composite(fn(), (x, y))
        print("drew", name)
    atlas.save(os.path.join(out, "ui_skin.png"))
    pattern().save(os.path.join(out, "ui_pattern.png"))
    # preview: each piece stretched as a 9-slice would be, tinted
    print("ok")
