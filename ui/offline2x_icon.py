"""BlockRise Empire - the picture of the "2x Offline Cash" developer product (2026-10-08).

A night card (no sparkles: the owner doesn't want the little stars): a golden crescent moon behind a brick of cash and
a red "x2" badge, in the game's sticker style (thick ink outline, Luckiest Guy).

    python3 ui/offline2x_icon.py <LuckiestGuy.ttf>   ->  ui/offline2x_card.png (512 x 512, opaque, for the Creator Hub)
                                                         ui/offline2x_game.png (256 x 256, transparent)
The cash brick is icons/png/cash.png without its sparkle.
"""
import math
import os
import sys

from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
SS = 4                      # supersampling
S = 512 * SS
INK = (27, 21, 48, 255)


def radial(size, c0, c1, power=1.15, reach=0.62):
    """opaque square: c0 in the middle, c1 at the edge"""
    im = Image.new("RGB", (size, size))
    px = im.load()
    cx = cy = (size - 1) / 2
    for y in range(size):
        for x in range(size):
            d = min(1.0, math.hypot(x - cx, y - cy) / (size * reach)) ** power
            px[x, y] = tuple(int(c0[i] * (1 - d) + c1[i] * d) for i in range(3))
    return im


def rays(size, n=12, strength=26):
    """soft light rays from the middle, fading out (no stars)"""
    m = Image.new("L", (size, size), 0)
    d = ImageDraw.Draw(m)
    cx = cy = size / 2
    R = size * 0.75
    for k in range(n):
        a0 = (k / n) * math.tau
        a1 = a0 + math.tau / n * 0.42
        d.polygon([(cx, cy), (cx + R * math.cos(a0), cy + R * math.sin(a0)), (cx + R * math.cos(a1), cy + R * math.sin(a1))], fill=strength)
    fade = Image.new("L", (size, size), 0)
    fd = ImageDraw.Draw(fade)
    for i in range(60, 0, -1):
        r = size * 0.62 * i / 60
        fd.ellipse([cx - r, cy - r, cx + r, cy + r], fill=int(255 * (1 - i / 60) ** 0.8))
    return ImageChops.multiply(m, fade).filter(ImageFilter.GaussianBlur(size / 160))


def vgrad(size, top, bottom):
    g = Image.new("RGBA", size)
    px = g.load()
    for y in range(size[1]):
        t = y / max(1, size[1] - 1)
        c = tuple(int(top[i] * (1 - t) + bottom[i] * t) for i in range(3)) + (255,)
        for x in range(size[0]):
            px[x, y] = c
    return g


def crescent(cx, cy, r, off, r2):
    """a crescent mask: the circle (cx, cy, r) minus the circle shifted by off with radius r2"""
    m = Image.new("L", (S, S), 0)
    d = ImageDraw.Draw(m)
    d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=255)
    d.ellipse([cx + off[0] - r2, cy + off[1] - r2, cx + off[0] + r2, cy + off[1] + r2], fill=0)
    return m


def sticker(mask, fill, outline_px):
    """the fill inside the mask with a thick ink outline around it (the game's sticker look)"""
    out = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    grown = mask.filter(ImageFilter.MaxFilter(outline_px * 2 + 1))
    ink = Image.new("RGBA", (S, S), INK)
    out.paste(ink, (0, 0), grown)
    out.paste(fill, (0, 0), mask)
    return out


def moon_layer():
    cx, cy, r = 206 * SS, 196 * SS, 122 * SS
    m = crescent(cx, cy, r, (72 * SS, -44 * SS), 104 * SS)
    gold = vgrad((S, S), (255, 238, 140), (255, 168, 36))
    lay = sticker(m, gold, 9 * SS)
    # a soft shine along the lit edge
    shine = crescent(cx - 13 * SS, cy + 9 * SS, r - 32 * SS, (61 * SS, -37 * SS), 96 * SS)
    shine = ImageChops.multiply(shine, m).filter(ImageFilter.GaussianBlur(10 * SS))
    lay.paste(Image.new("RGBA", (S, S), (255, 252, 220, 255)), (0, 0), shine.point(lambda v: int(v * 0.55)))
    # a glow behind it
    glow = m.filter(ImageFilter.GaussianBlur(40 * SS)).point(lambda v: int(v * 0.55))
    g = Image.new("RGBA", (S, S), (255, 214, 110, 0))
    g.putalpha(glow)
    return Image.alpha_composite(g, lay)


def cash_layer():
    cash = Image.open(os.path.join(ROOT, "icons", "png", "cash.png")).convert("RGBA")
    # the sparkle goes: only the biggest piece of the picture (the notes and the coin) is kept
    a = cash.getchannel("A")
    w, h = a.size
    px = a.load()
    seen, best = set(), []
    for y in range(h):
        for x in range(w):
            if px[x, y] > 8 and (x, y) not in seen:
                comp, todo = [], [(x, y)]
                seen.add((x, y))
                while todo:
                    cx, cy = todo.pop()
                    comp.append((cx, cy))
                    for nx, ny in ((cx + 1, cy), (cx - 1, cy), (cx, cy + 1), (cx, cy - 1)):
                        if 0 <= nx < w and 0 <= ny < h and (nx, ny) not in seen and px[nx, ny] > 8:
                            seen.add((nx, ny))
                            todo.append((nx, ny))
                if len(comp) > len(best):
                    best = comp
    keep = Image.new("L", a.size, 0)
    kp = keep.load()
    for x, y in best:
        kp[x, y] = 255
    keep = keep.filter(ImageFilter.MaxFilter(3))
    cash.putalpha(ImageChops.multiply(a, keep))
    size = 344 * SS
    big = cash.resize((size, size), Image.LANCZOS)
    lay = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    lay.alpha_composite(big, (92 * SS, 168 * SS))
    return lay


def badge_layer(font_path):
    cx, cy, r = 392 * SS, 128 * SS, 78 * SS
    lay = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    m = Image.new("L", (S, S), 0)
    ImageDraw.Draw(m).ellipse([cx - r, cy - r, cx + r, cy + r], fill=255)
    red = vgrad((S, S), (255, 104, 112), (214, 30, 52))
    lay = sticker(m, red, 8 * SS)
    # a white ring inside
    ring = Image.new("L", (S, S), 0)
    rd = ImageDraw.Draw(ring)
    rd.ellipse([cx - r + 9 * SS, cy - r + 9 * SS, cx + r - 9 * SS, cy + r - 9 * SS], outline=255, width=5 * SS)
    lay.paste(Image.new("RGBA", (S, S), (255, 255, 255, 230)), (0, 0), ring)
    font = ImageFont.truetype(font_path, 92 * SS)
    d = ImageDraw.Draw(lay)
    # Luckiest Guy draws its capitals high: centred on the ink box
    bb = d.textbbox((0, 0), "x2", font=font, stroke_width=7 * SS)
    tw, th = bb[2] - bb[0], bb[3] - bb[1]
    d.text((cx - tw / 2 - bb[0], cy - th / 2 - bb[1] + 2 * SS), "x2", font=font, fill=(255, 255, 255, 255), stroke_width=7 * SS, stroke_fill=INK)
    return lay


def render(font_path):
    bg = radial(S // 4, (98, 112, 255), (16, 20, 74)).resize((S, S), Image.BICUBIC).convert("RGBA")
    light = rays(S)
    bg.paste(Image.new("RGBA", (S, S), (210, 220, 255, 255)), (0, 0), light)
    art = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    for lay in (moon_layer(), cash_layer(), badge_layer(font_path)):
        art = Image.alpha_composite(art, lay)
    card = Image.alpha_composite(bg, art).convert("RGB").resize((512, 512), Image.LANCZOS)
    card.save(os.path.join(HERE, "offline2x_card.png"))
    art.resize((256, 256), Image.LANCZOS).save(os.path.join(HERE, "offline2x_game.png"))


if __name__ == "__main__":
    render(sys.argv[1])
