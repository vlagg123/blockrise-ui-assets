"""Mock a menu with the skin atlas (9-slice + tint, like Roblox does) to judge the look before uploading."""
import sys
from PIL import Image, ImageDraw, ImageFont, ImageChops

A = Image.open(sys.argv[1]).convert("RGBA")
CELLS = {"panel": (0, 0, 44), "button": (128, 0, 40), "tile": (256, 0, 40), "gloss": (384, 0, 30), "pill": (0, 128, 34),
         "inset": (128, 128, 28), "shadow": (256, 128, 44), "circle": (384, 128, 63), "fill": (0, 256, 28)}


def nine(name, w, h, tint=(255, 255, 255), scale=0.5, alpha=1.0):
    x0, y0, c = CELLS[name]
    src = A.crop((x0, y0, x0 + 128, y0 + 128))
    if tint != (255, 255, 255):
        r, g, b, a = src.split()
        r = r.point(lambda v: v * tint[0] // 255); g = g.point(lambda v: v * tint[1] // 255); b = b.point(lambda v: v * tint[2] // 255)
        src = Image.merge("RGBA", (r, g, b, a))
    cs = int(c * scale)
    out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    xs = [(0, c, 0, cs), (c, 128 - c, cs, w - cs), (128 - c, 128, w - cs, w)]
    ys = [(0, c, 0, cs), (c, 128 - c, cs, h - cs), (128 - c, 128, h - cs, h)]
    for sx0, sx1, dx0, dx1 in xs:
        for sy0, sy1, dy0, dy1 in ys:
            if dx1 - dx0 <= 0 or dy1 - dy0 <= 0:
                continue
            piece = src.crop((sx0, sy0, sx1, sy1)).resize((dx1 - dx0, dy1 - dy0), Image.LANCZOS)
            out.alpha_composite(piece, (dx0, dy0))
    if alpha < 1:
        out.putalpha(out.split()[3].point(lambda v: int(v * alpha)))
    return out


def font(size, bold=True):
    for p in ("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",):
        try:
            return ImageFont.truetype(p, size)
        except Exception:
            pass
    return ImageFont.load_default()


def text(im, xy, s, size, fill=(255, 255, 255), stroke=3):
    d = ImageDraw.Draw(im)
    d.text(xy, s, font=font(size), fill=fill, stroke_width=stroke, stroke_fill=(20, 17, 32))


W, H = 900, 620
bg = Image.new("RGBA", (W, H), (120, 170, 120, 255))
win = (60, 40, 840, 590)
bg.alpha_composite(nine("shadow", win[2] - win[0] + 30, win[3] - win[1] + 30, alpha=0.8), (win[0] - 10, win[1] - 2))
body = nine("panel", win[2] - win[0], win[3] - win[1], tint=(52, 58, 120))
bg.alpha_composite(body, win[:2])
pat = Image.open(sys.argv[2]).convert("RGBA")
# header
hx, hy, hw, hh = win[0] + 14, win[1] + 14, win[2] - win[0] - 28, 66
bg.alpha_composite(nine("button", hw, hh, tint=(255, 176, 40)), (hx, hy))
bg.alpha_composite(nine("gloss", hw, hh), (hx, hy))
text(bg, (hx + 90, hy + 12), "EQUIPMENT STORE", 32)
# close
bg.alpha_composite(nine("circle", 56, 56, tint=(240, 70, 80), scale=0.44), (win[2] - 46, win[1] - 14))
text(bg, (win[2] - 28, win[1] - 2), "X", 26)
# tabs
tx = win[0] + 20
for i, (t, col) in enumerate((("TOOLS", (90, 170, 255)), ("TRAINING", (90, 90, 140)), ("MACHINES", (90, 90, 140)), ("CREW", (90, 90, 140)))):
    bg.alpha_composite(nine("button", 180, 48, tint=col), (tx + i * 188, win[1] + 92))
    text(bg, (tx + i * 188 + 40, win[1] + 102), t, 18, fill=(255, 255, 255) if i == 0 else (200, 200, 230))
# tiles
cols = [(255, 190, 70), (110, 200, 255), (170, 120, 255)]
for i in range(3):
    x = win[0] + 20 + i * 250
    y = win[1] + 160
    bg.alpha_composite(nine("tile", 236, 300, tint=(236, 238, 255)), (x, y))
    bg.alpha_composite(nine("tile", 212, 150, tint=cols[i]), (x + 12, y + 12))
    bg.alpha_composite(nine("gloss", 212, 150), (x + 12, y + 12))
    text(bg, (x + 20, y + 172), ["Pro Tools", "Heavy Kit", "Master Set"][i], 22, fill=(255, 255, 255))
    bg.alpha_composite(nine("pill", 120, 30, tint=(255, 214, 90)), (x + 18, y + 206))
    text(bg, (x + 30, y + 211), "x2 POWER", 13, stroke=2)
    bg.alpha_composite(nine("button", 210, 50, tint=(80, 210, 90)), (x + 13, y + 240))
    bg.alpha_composite(nine("gloss", 210, 50), (x + 13, y + 240))
    text(bg, (x + 80, y + 250), "$120", 22)
# progress
bg.alpha_composite(nine("inset", 400, 28), (win[0] + 20, win[3] - 60))
bg.alpha_composite(nine("fill", 240, 28, tint=(255, 200, 60)), (win[0] + 20, win[3] - 60))
bg.save(sys.argv[3])
print("preview saved")
