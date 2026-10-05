"""2D finish for the rendered icons: thick sticker outline, soft drop shadow, sparkles.

Usage: python3 post.py SRC_DIR OUT_DIR [size]
"""
import sys, os, math
import numpy as np
from PIL import Image, ImageFilter, ImageDraw

INK = (29, 24, 48)
SPARKLE = {   # icon -> list of (x, y, r) in 0..1 of the canvas
    "gem": [(0.80, 0.22, 0.085), (0.20, 0.70, 0.05)],
    "star": [(0.84, 0.18, 0.07)],
    "level": [(0.84, 0.18, 0.07)],
    "rebirth_star": [(0.84, 0.18, 0.07)],
    "cash": [(0.83, 0.20, 0.07)],
    "coins": [(0.20, 0.22, 0.07)],
    "up_cash": [(0.20, 0.22, 0.07)],
    "store": [(0.84, 0.20, 0.075), (0.16, 0.30, 0.05)],
    "gift": [(0.85, 0.20, 0.07)],
    "up_luck": [(0.84, 0.18, 0.065)],
    "codes": [(0.86, 0.26, 0.06)],
    "spin": [(0.88, 0.16, 0.06)],
    "upgrades": [(0.82, 0.20, 0.06)],
    "rebirth": [(0.86, 0.18, 0.06)],
}

def dilate(a, r):
    """Round, anti-aliased dilation of an alpha mask (float 0..1) by r pixels."""
    out = np.zeros_like(a)
    R = int(math.ceil(r)) + 1
    H, W = a.shape
    pad = np.pad(a, R)
    for dy in range(-R, R + 1):
        for dx in range(-R, R + 1):
            d = math.hypot(dx, dy)
            w = min(1.0, max(0.0, r + 0.5 - d))
            if w <= 0:
                continue
            sh = pad[R + dy:R + dy + H, R + dx:R + dx + W]
            np.maximum(out, sh * w, out=out)
    return out

def sparkle(draw, cx, cy, r, ink_w):
    pts = []
    for i in range(16):
        a = i * math.pi / 8 - math.pi / 2
        k = i % 4
        rr = r if k == 0 else (r * 0.16 if k == 2 else r * 0.26)
        pts.append((cx + math.cos(a) * rr, cy + math.sin(a) * rr))
    draw.polygon(pts, fill=(255, 255, 255, 255), outline=INK + (255,), width=ink_w)

def finish(src, out_size):
    im = Image.open(src).convert("RGBA")
    S = im.width
    pad = int(S * 0.0)
    a = np.asarray(im, dtype=np.float32)[..., 3] / 255.0
    ow = S * 0.026                          # outer outline width
    outline = dilate(a, ow)
    # drop shadow: the outlined shape, pushed down and blurred
    sh = Image.fromarray((outline * 255).astype(np.uint8), "L")
    sh = sh.transform(sh.size, Image.AFFINE, (1, 0, 0, 0, 1, -S * 0.035), resample=Image.BILINEAR)
    sh = sh.filter(ImageFilter.GaussianBlur(S * 0.018))
    canvas = Image.new("RGBA", im.size, (0, 0, 0, 0))
    shadow = Image.new("RGBA", im.size, INK + (0,))
    shadow.putalpha(sh.point(lambda v: int(v * 0.55)))
    canvas = Image.alpha_composite(canvas, shadow)
    ol = Image.new("RGBA", im.size, INK + (0,))
    ol.putalpha(Image.fromarray((outline * 255).astype(np.uint8), "L"))
    canvas = Image.alpha_composite(canvas, ol)
    canvas = Image.alpha_composite(canvas, im)
    name = os.path.splitext(os.path.basename(src))[0]
    if name in SPARKLE:
        d = ImageDraw.Draw(canvas)
        for x, y, r in SPARKLE[name]:
            sparkle(d, x * S, y * S, r * S * 1.55, max(2, int(S * 0.009)))
    return canvas.resize((out_size, out_size), Image.LANCZOS)

if __name__ == "__main__":
    src, out = sys.argv[1], sys.argv[2]
    size = int(sys.argv[3]) if len(sys.argv) > 3 else 256
    os.makedirs(out, exist_ok=True)
    for f in sorted(os.listdir(src)):
        if f.endswith(".png"):
            finish(os.path.join(src, f), size).save(os.path.join(out, f))
    print("done")
