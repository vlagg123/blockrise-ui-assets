"""2D finish for the icons with numpy only (runs inside Blender, which has no PIL):
thick sticker outline, soft drop shadow, sparkles, 3x supersampled downscale, atlas packing.
Same look as post.py."""
import math
import numpy as np

INK = np.array([29, 24, 48], dtype=np.float32) / 255.0
WHITE = np.ones(3, dtype=np.float32)

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
    "portfolio": [(0.86, 0.2, 0.07), (0.14, 0.34, 0.045)],
    "vip": [(0.86, 0.2, 0.075), (0.14, 0.3, 0.05)],
}


def load(path):
    """PNG -> float array (H, W, 4), top row first, straight alpha."""
    import bpy
    img = bpy.data.images.load(path, check_existing=False)
    w, h = img.size
    a = np.empty(w * h * 4, dtype=np.float32)
    img.pixels.foreach_get(a)
    bpy.data.images.remove(img)
    return a.reshape(h, w, 4)[::-1].copy()


def save(arr, path):
    import bpy
    h, w = arr.shape[:2]
    img = bpy.data.images.new("br_tmp_save", w, h, alpha=True)
    img.pixels.foreach_set(np.ascontiguousarray(np.clip(arr[::-1], 0, 1), dtype=np.float32).ravel())
    img.filepath_raw = path
    img.file_format = "PNG"
    img.save()
    bpy.data.images.remove(img)


def dilate(a, r):
    """Round, anti-aliased dilation of an alpha mask by r pixels."""
    out = np.zeros_like(a)
    R = int(math.ceil(r)) + 1
    H, W = a.shape
    pad = np.pad(a, R)
    for dy in range(-R, R + 1):
        for dx in range(-R, R + 1):
            w = min(1.0, max(0.0, r + 0.5 - math.hypot(dx, dy)))
            if w <= 0:
                continue
            np.maximum(out, pad[R + dy:R + dy + H, R + dx:R + dx + W] * w, out=out)
    return out


def blur(m, sigma):
    r = int(3 * sigma) + 1
    k = np.exp(-0.5 * (np.arange(-r, r + 1) / sigma) ** 2)
    k /= k.sum()
    H, W = m.shape
    p = np.pad(m, ((0, 0), (r, r)))
    h = sum(k[i] * p[:, i:i + W] for i in range(2 * r + 1))
    p = np.pad(h, ((r, r), (0, 0)))
    return sum(k[i] * p[i:i + H, :] for i in range(2 * r + 1))


def shift_down(m, dy):
    out = np.zeros_like(m)
    out[dy:] = m[:-dy]
    return out


def solid(rgb, alpha):
    return np.concatenate([np.broadcast_to(rgb, alpha.shape + (3,)), alpha[..., None]], -1).astype(np.float32)


def over(dst, src):
    sa, da = src[..., 3:4], dst[..., 3:4]
    oa = sa + da * (1 - sa)
    rgb = (src[..., :3] * sa + dst[..., :3] * da * (1 - sa)) / np.maximum(oa, 1e-6)
    return np.concatenate([rgb, oa], -1)


def poly_mask(H, W, pts, ss=4):
    xs = [p[0] for p in pts]
    ys = [p[1] for p in pts]
    x0, x1 = max(0, int(min(xs)) - 1), min(W, int(max(xs)) + 2)
    y0, y1 = max(0, int(min(ys)) - 1), min(H, int(max(ys)) + 2)
    gx, gy = np.meshgrid(x0 + (np.arange((x1 - x0) * ss) + 0.5) / ss, y0 + (np.arange((y1 - y0) * ss) + 0.5) / ss)
    inside = np.zeros(gx.shape, bool)
    n = len(pts)
    for i in range(n):
        xa, ya = pts[i]
        xb, yb = pts[(i + 1) % n]
        if ya == yb:
            continue
        cond = ((ya > gy) != (yb > gy)) & (gx < (xb - xa) * (gy - ya) / (yb - ya) + xa)
        inside ^= cond
    m = inside.reshape(y1 - y0, ss, x1 - x0, ss).mean((1, 3))
    full = np.zeros((H, W), np.float32)
    full[y0:y1, x0:x1] = m
    return full


def sparkle(canvas, cx, cy, r, ink_w):
    pts = []
    for i in range(16):
        a = i * math.pi / 8 - math.pi / 2
        k = i % 4
        rr = r if k == 0 else (r * 0.16 if k == 2 else r * 0.26)
        pts.append((cx + math.cos(a) * rr, cy + math.sin(a) * rr))
    H, W = canvas.shape[:2]
    m = poly_mask(H, W, pts)
    canvas = over(canvas, solid(INK, dilate(m, ink_w)))
    return over(canvas, solid(WHITE, m))


def finish(raw, name, out_size=124):
    S = raw.shape[0]
    a = raw[..., 3]
    outline = dilate(a, S * 0.026)
    sh = blur(shift_down(outline, int(S * 0.035)), S * 0.018) * 0.55
    canvas = solid(INK, sh)
    canvas = over(canvas, solid(INK, outline))
    canvas = over(canvas, raw)
    for x, y, r in SPARKLE.get(name, []):
        canvas = sparkle(canvas, x * S, y * S, r * S * 1.55, max(2.0, S * 0.009))
    f = S // out_size
    pm = canvas[..., :3] * canvas[..., 3:4]
    pm = pm.reshape(out_size, f, out_size, f, 3).mean((1, 3))
    al = canvas[..., 3].reshape(out_size, f, out_size, f).mean((1, 3))[..., None]
    return np.concatenate([pm / np.maximum(al, 1e-6), al], -1)


def atlas(cells, names, size=1024, cell=128, pad=2):
    """cells: name -> (124,124,4). Packed alphabetically, 8 per row, like Icons.cells."""
    out = np.zeros((size, size, 4), np.float32)
    pos = {}
    for i, n in enumerate(sorted(names)):
        x, y = (i % 8) * cell, (i // 8) * cell
        c = cells[n]
        out[y + pad:y + pad + c.shape[0], x + pad:x + pad + c.shape[1]] = c
        pos[n] = (x, y)
    return out, pos


def preview(at, rows, bg=(92, 104, 140), card=(70, 80, 112)):
    """The atlas over a dark card grid, for checking by eye."""
    H = rows * 128
    out = np.zeros((H, 1024, 4), np.float32)
    out[..., :3] = np.array(bg, np.float32) / 255
    out[..., 3] = 1
    for r in range(rows):
        for c in range(8):
            out[r * 128 + 4:r * 128 + 124, c * 128 + 4:c * 128 + 124, :3] = np.array(card, np.float32) / 255
    return over(out, at[:H])
