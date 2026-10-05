"""Mock of the new window look (front-page simulator style), built only from the skin atlas pieces + real icons,
so what we see here is what Roblox will draw with 9-slices and tints."""
import sys, math
from PIL import Image, ImageDraw, ImageFont

ROOT = "/home/claude/blockrise-ui-assets"
A = Image.open(f"{ROOT}/ui/ui_skin.png").convert("RGBA")
PAT = Image.open(f"{ROOT}/ui/ui_pattern.png").convert("RGBA")
ICON = lambda n: Image.open(f"{ROOT}/icons/png/{n}.png").convert("RGBA")
CELLS = {"panel": (0, 0, 44), "button": (128, 0, 40), "tile": (256, 0, 40), "gloss": (384, 0, 30), "pill": (0, 128, 34),
         "inset": (128, 128, 28), "shadow": (256, 128, 44), "circle": (384, 128, 63), "fill": (0, 256, 28),
         "rays": (128, 256, 0), "glow": (256, 256, 0), "face": (384, 256, 40)}
INK = (20, 17, 32)


def cell(name):
    x0, y0, _ = CELLS[name]
    return A.crop((x0, y0, x0 + 128, y0 + 128))


def tint(im, t, alpha=1.0):
    r, g, b, a = im.split()
    r = r.point(lambda v: v * t[0] // 255); g = g.point(lambda v: v * t[1] // 255); b = b.point(lambda v: v * t[2] // 255)
    if alpha < 1:
        a = a.point(lambda v: int(v * alpha))
    return Image.merge("RGBA", (r, g, b, a))


def vgrad_tint(im, top, bot):
    """like ImageColor3 white + UIGradient(top->bottom)"""
    w, h = im.size
    g = Image.new("RGB", (1, h))
    for y in range(h):
        t = y / max(1, h - 1)
        g.putpixel((0, y), tuple(int(top[i] + (bot[i] - top[i]) * t) for i in range(3)))
    g = g.resize((w, h))
    r, gg, b, a = im.split()
    base = Image.merge("RGB", (r, gg, b))
    from PIL import ImageChops
    out = ImageChops.multiply(base, g)
    return Image.merge("RGBA", (*out.split(), a))


def nine(name, w, h, t=(255, 255, 255), scale=0.5, alpha=1.0):
    x0, y0, c = CELLS[name]
    src = tint(cell(name), t, alpha)
    if c == 0:
        return src.resize((w, h), Image.LANCZOS)
    cs = int(c * scale)
    out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    xs = [(0, c, 0, cs), (c, 128 - c, cs, w - cs), (128 - c, 128, w - cs, w)]
    ys = [(0, c, 0, cs), (c, 128 - c, cs, h - cs), (128 - c, 128, h - cs, h)]
    for sx0, sx1, dx0, dx1 in xs:
        for sy0, sy1, dy0, dy1 in ys:
            if dx1 - dx0 <= 0 or dy1 - dy0 <= 0:
                continue
            out.alpha_composite(src.crop((sx0, sy0, sx1, sy1)).resize((dx1 - dx0, dy1 - dy0), Image.LANCZOS), (dx0, dy0))
    return out


def F(size, kind="fredoka", wght=650):
    if kind == "lucky":
        return ImageFont.truetype("/home/claude/fonts/LuckiestGuy-Regular.ttf", size)
    f = ImageFont.truetype("/home/claude/fonts/Fredoka[wdth,wght].ttf", size)
    f.set_variation_by_axes([wght, 100])
    return f


def text(im, xy, s, font, fill=(255, 255, 255), stroke=0, anchor="la", grad=None):
    d = ImageDraw.Draw(im)
    if grad:
        # gradient-filled text with an ink stroke (UIGradient on a TextLabel)
        layer = Image.new("RGBA", im.size, (0, 0, 0, 0))
        ImageDraw.Draw(layer).text(xy, s, font=font, fill=(0, 0, 0, 255), stroke_width=stroke, stroke_fill=INK + (255,), anchor=anchor)
        im.alpha_composite(layer)
        m = Image.new("L", im.size, 0)
        ImageDraw.Draw(m).text(xy, s, font=font, fill=255, anchor=anchor)
        bb = m.getbbox()
        g = Image.new("RGBA", im.size, (0, 0, 0, 0))
        gd = ImageDraw.Draw(g)
        for y in range(bb[1], bb[3]):
            t = (y - bb[1]) / max(1, bb[3] - bb[1] - 1)
            c = tuple(int(grad[0][i] + (grad[1][i] - grad[0][i]) * t) for i in range(3))
            gd.line((bb[0], y, bb[2], y), fill=c + (255,))
        im.paste(g, (0, 0), m)
        return
    d.text(xy, s, font=font, fill=fill, stroke_width=stroke, stroke_fill=INK, anchor=anchor)


W, H = 1280, 720
scr = Image.new("RGBA", (W, H), (0, 0, 0, 255))
# fake game backdrop: sky + grass, dimmed like the modal backdrop
sky = Image.new("RGBA", (W, H))
sd = ImageDraw.Draw(sky)
for y in range(H):
    t = y / H
    sd.line((0, y, W, y), fill=(int(120 + 60 * t), int(190 + 20 * t), 255, 255) if y < 420 else (96, 170, 80, 255))
scr.alpha_composite(sky)
scr.alpha_composite(Image.new("RGBA", (W, H), (10, 10, 30, 110)))

WW, WH = 860, 560
wx, wy = (W - WW) // 2, (H - WH) // 2 + 20
# shadow
scr.alpha_composite(nine("shadow", WW + 30, WH + 30, alpha=0.9), (wx - 9, wy - 2))
# body (tinted white + vertical gradient) + stripes
body = vgrad_tint(nine("panel", WW, WH), (92, 116, 236), (48, 54, 146))
pat = Image.new("RGBA", (WW, WH))
for x in range(0, WW, 128):
    for y in range(0, WH, 128):
        pat.alpha_composite(PAT, (x, y))
pa = pat.split()[3].point(lambda v: int(v * 0.35))
pat.putalpha(Image.composite(pa, Image.new("L", (WW, WH), 0), body.split()[3].point(lambda v: 255 if v > 250 else 0)))
body.alpha_composite(pat)
scr.alpha_composite(body, (wx, wy))

# header ribbon sticking out above the window
theme = (255, 168, 40)
hx, hy, hw, hh = wx + 70, wy - 26, WW - 140, 74
hdr = nine("button", hw, hh, theme)
stripes = Image.new("RGBA", (hw, hh))
for x in range(0, hw, 128):
    stripes.alpha_composite(PAT, (x, 0))
mask = nine("face", hw, hh).split()[3]
stripes.putalpha(Image.composite(stripes.split()[3].point(lambda v: int(v * 0.8)), Image.new("L", (hw, hh), 0), mask))
hdr.alpha_composite(stripes)
hdr.alpha_composite(nine("gloss", hw, hh))
scr.alpha_composite(hdr, (hx, hy))
text(scr, (hx + hw // 2 + 20, hy + 30), "SHOP", F(46, "lucky"), stroke=5, anchor="mm", grad=((255, 255, 255), (255, 232, 140)))
# header icon, popping out on the left, tilted
ic = ICON("shop").resize((118, 118), Image.LANCZOS).rotate(8, resample=Image.BICUBIC, expand=True)
scr.alpha_composite(ic, (hx - 44, hy - 40))
# close button
cx, cy = wx + WW - 46, wy - 18
scr.alpha_composite(nine("button", 60, 60, (240, 64, 72)), (cx, cy))
scr.alpha_composite(nine("gloss", 60, 60), (cx, cy))
text(scr, (cx + 30, cy + 25), "X", F(32, "lucky"), stroke=4, anchor="mm")

# tabs
tabs = [("TOOLS", "jobs", (80, 170, 255)), ("TRAINING", "gym", None), ("MACHINES", "upgrades", None), ("CREW", "crew", None)]
tx, ty, tw, th, gap = wx + 22, wy + 64, (WW - 44 - 3 * 10) // 4, 52, 10
for i, (lbl, icn, col) in enumerate(tabs):
    on = col is not None
    c = col if on else (66, 72, 156)
    x = tx + i * (tw + gap)
    scr.alpha_composite(nine("button", tw, th, c), (x, ty))
    scr.alpha_composite(nine("gloss", tw, th, alpha=1 if on else 0.5), (x, ty))
    ii = ICON(icn).resize((44, 44), Image.LANCZOS)
    if not on:
        ii.putalpha(ii.split()[3].point(lambda v: int(v * 0.75)))
    scr.alpha_composite(ii, (x + 10, ty + 1))
    text(scr, (x + 60, ty + 22), lbl, F(21, wght=700), fill=(255, 255, 255) if on else (196, 202, 240), stroke=3 if on else 2, anchor="lm")

# content well
cx0, cy0, cw, ch = wx + 16, wy + 128, WW - 32, WH - 128 - 16
scr.alpha_composite(nine("inset", cw, ch, alpha=0.32, scale=0.5), (cx0, cy0))

# tiles
items = [
    ("Hammer", "jobs", (255, 186, 60), "COMMON", (150, 150, 170), "+1 power", "$0", "EQUIPPED"),
    ("Drill", "upgrades", (86, 190, 255), "RARE", (60, 140, 255), "+5 power", "$1.2K", None),
    ("Jackhammer", "up_power", (178, 112, 255), "EPIC", (160, 80, 255), "+15 power", "$9.5K", None),
    ("Crane Kit", "mega", (255, 110, 120), "LEGEND", (255, 170, 30), "+50 power", "$85K", "LOCK"),
]
cols, gx = 4, 12
tw = (cw - 24 - gx * (cols - 1)) // cols
tH = 300
for i, (name, icn, col, rar, rcol, sub, price, state) in enumerate(items):
    x = cx0 + 12 + i * (tw + gx)
    y = cy0 + 12
    tile = nine("tile", tw, tH, (248, 248, 255))
    scr.alpha_composite(tile, (x, y))
    ax, ay, aw, ah = x + 8, y + 8, tw - 16, 150
    art = vgrad_tint(nine("tile", aw, ah), tuple(min(255, int(v * 1.0 + 50)) for v in col), tuple(int(v * 0.78) for v in col))
    rays = nine("rays", ah + 70, ah + 70, alpha=0.55)
    art_l = Image.new("RGBA", (aw, ah))
    art_l.alpha_composite(rays, ((aw - ah - 70) // 2, -35))
    art_l.alpha_composite(nine("glow", 130, 130, alpha=0.6), ((aw - 130) // 2, 10))
    mask = nine("face", aw, ah).split()[3]
    art_l.putalpha(Image.composite(art_l.split()[3], Image.new("L", (aw, ah), 0), art.split()[3].point(lambda v: 255 if v > 200 else 0)))
    art.alpha_composite(art_l)
    art.alpha_composite(nine("gloss", aw, ah, alpha=0.6))
    ic = ICON(icn).resize((150, 150), Image.LANCZOS)
    art.alpha_composite(ic, ((aw - 150) // 2, -2))
    scr.alpha_composite(art, (ax, ay))
    # rarity chip
    rw = 22 + len(rar) * 10
    scr.alpha_composite(nine("pill", rw, 26, rcol, scale=0.36), (ax + 6, ay + 6))
    text(scr, (ax + 6 + rw // 2, ay + 19), rar, F(15, "lucky"), stroke=2, anchor="mm")
    # name + sub
    text(scr, (x + 14, y + 172), name, F(23, wght=700), fill=(40, 34, 70), anchor="lm")
    scr.alpha_composite(nine("pill", 110, 28, (255, 206, 70), scale=0.36), (x + 12, y + 192))
    text(scr, (x + 67, y + 206), sub.upper(), F(14, "lucky"), stroke=2, anchor="mm")
    # button
    bx, by, bw, bh = x + 10, y + tH - 62, tw - 20, 52
    if state == "EQUIPPED":
        scr.alpha_composite(nine("pill", bw, bh - 4, (150, 156, 196), scale=0.4), (bx, by + 2))
        text(scr, (bx + bw // 2, by + bh // 2), "EQUIPPED", F(20, wght=700), stroke=2, anchor="mm")
    elif state == "LOCK":
        scr.alpha_composite(nine("button", bw, bh, (110, 116, 170)), (bx, by))
        text(scr, (bx + bw // 2, by + 21), "🔒 Lvl 20", F(20, wght=700), fill=(225, 228, 250), stroke=2, anchor="mm")
    else:
        scr.alpha_composite(nine("button", bw, bh, (70, 214, 96)), (bx, by))
        scr.alpha_composite(nine("gloss", bw, bh), (bx, by))
        # moving shine band
        band = Image.new("RGBA", (bw, bh), (0, 0, 0, 0))
        bd = ImageDraw.Draw(band)
        bd.polygon([(bw * 0.55, 0), (bw * 0.7, 0), (bw * 0.55, bh), (bw * 0.4, bh)], fill=(255, 255, 255, 90))
        fm = nine("face", bw, bh).split()[3]
        band.putalpha(Image.composite(band.split()[3], Image.new("L", (bw, bh), 0), fm))
        scr.alpha_composite(band, (bx, by))
        coin = ICON("cash").resize((40, 40), Image.LANCZOS)
        scr.alpha_composite(coin, (bx + 14, by + 2))
        text(scr, (bx + bw // 2 + 16, by + 21), price, F(25, wght=700), stroke=3, anchor="mm")

# second row peeking
for i in range(4):
    x = cx0 + 12 + i * (tw + gx)
    y = cy0 + 12 + tH + 12
    t = nine("tile", tw, tH, (248, 248, 255)).crop((0, 0, tw, cy0 + ch - y - 6))
    scr.alpha_composite(t, (x, y))
# thin scroll indicator
scr.alpha_composite(nine("pill", 8, 120, (255, 255, 255), scale=0.12, alpha=0.6), (cx0 + cw - 9, cy0 + 14))

scr.convert("RGB").save(sys.argv[1])
print("ok")
