"""BlockRise Empire - premium thumbnails for the Roblox game page (game passes) and the Creator Hub (products), 2026-10-07.

The old cards (robux.card) were pale: a light pastel glow, rays and sparkles round an icon rendered at 768 px. These are:
  * rendered at 1024 px with more samples, then brought down to 512 px (sharp), with a light unsharp mask;
  * the object graded a touch richer (saturation, contrast);
  * on a deep, saturated round backdrop (Roblox shows game passes in a circle): a spotlight behind the object, a soft
    floor shadow under it, a thin gold ring at the edge; no rays, no sparkles, no stars.

    import thumbs; thumbs.render()                  # every pass
    thumbs.render(["vip", "luck"])                  # some
Output: OUT/thumbs/<key>.png (512 x 512, opaque).

Four passes had no 3D icon yet: Lucky Builder (luck), Ultra Lucky (ultraluck), Night Shift (offline), Secret Hunter
(hunter). They are made here.
"""
import math, os
import numpy as np
import icons as I
import icons3 as I3
import items as T
import postnp
import robux as R
import setcrates  # (registers the three new crates' icons in robux.ICONS)
from robux import candy, gold, gold_dark, glow, sphere, torus, cyl, box, poly, gem, coin, badge, track, pbr

OUT = os.path.join(I3.OUT, "thumbs")
TAU = math.tau

# the backdrop of each thumbnail: (spotlight colour in the middle, deep colour at the edge)
LOOK = {
    "vip": ("#ffb12e", "#3a0f00"), "bigcrew": ("#ff9a2e", "#3a1200"), "cash2x": ("#2fd06a", "#032a12"),
    "strength2x": ("#ff5a3c", "#3a0606"), "autobuild": ("#3f9bff", "#04123a"), "autotrain": ("#56d84a", "#062a08"),
    "gems2x": ("#3fb8ff", "#05164a"), "fasttools": ("#ffab2e", "#3a1400"), "teleporter": ("#2fe0ff", "#032a3a"),
    "skipanim": ("#4f8dff", "#081446"), "quickopen": ("#ffcf2e", "#3a2200"), "autoopen": ("#56d84a", "#062a10"),
    "luck": ("#3fe07a", "#03300f"), "ultraluck": ("#ffd23a", "#2a2a00"), "offline": ("#6a5cff", "#0a0630"),
    "hunter": ("#b05cff", "#16063a"),
    "crate_legends": ("#3f8cff", "#06123a"), "crate_pirate": ("#2fb0ff", "#04203a"), "crate_temple": ("#56e04a", "#082a06"),
    "crate_exclusive": ("#ff4fc8", "#2a0630"), "crate_golden": ("#ffc534", "#3a2200"), "crate_builder": ("#3f8cff", "#06143a"),
    "stormhammer": ("#4fb2ff", "#060f3a"), "monster": ("#ff4a5a", "#3a0610"), "goldcar": ("#ffd23a", "#3a2600"),
}
VIEW = {"luck": (0, -1, 0.3), "ultraluck": (0, -1, 0.3), "offline": (0, -1, 0.25), "hunter": (-0.1, -1, 0.25)}
PASSES = ["vip", "bigcrew", "cash2x", "strength2x", "autobuild", "autotrain", "gems2x", "fasttools", "teleporter", "skipanim",
          "quickopen", "autoopen", "luck", "ultraluck", "offline", "hunter"]
PRODUCTS = ["crate_legends", "crate_pirate", "crate_temple"]
# how much of the card the object takes (the crown and the skip button are wider than the rest)
FILL = {"vip": 0.7, "skipanim": 0.62}


# ------------------------------------------------------------------------------------------- the four new pass icons
def clover(loc=(0, 0, 0), s=1.0, leaf="#3fd36a", vein="#2aa850", stem=None, rot=0.0, mat=None, vmat=None):
    """a four-leaf clover facing the camera: four heart leaves (two round lobes each), a stem"""
    m = mat or candy(leaf, rough=0.2, emit=0.2)
    mv = vmat or candy(vein, rough=0.3, emit=0.15)
    x0, y0, z0 = loc
    for k in range(4):
        a = math.radians(45 + 90 * k + rot)
        c, sn = math.cos(a), math.sin(a)
        # the heart: two lobes side by side, pointing out from the middle
        for side in (-1, 1):
            px = c * 0.7 * s - sn * side * 0.2 * s
            pz = sn * 0.7 * s + c * side * 0.2 * s
            sphere(0.31 * s, m, loc=(x0 + px, y0, z0 + pz), scale=(1, 0.32, 1))
        # the point of the heart: two smaller balls towards the middle
        sphere(0.24 * s, m, loc=(x0 + c * 0.42 * s, y0, z0 + sn * 0.42 * s), scale=(1, 0.32, 1))
        sphere(0.14 * s, m, loc=(x0 + c * 0.24 * s, y0, z0 + sn * 0.24 * s), scale=(1, 0.32, 1))
        box((0.05 * s, 0.05 * s, 0.6 * s), mv, loc=(x0 + c * 0.5 * s, y0 - 0.12 * s, z0 + sn * 0.5 * s), rot=(0, -math.degrees(a) + 90, 0), bevel=0.02, outline=False)
    sphere(0.2 * s, mv, loc=(x0, y0 - 0.05 * s, z0), scale=(1, 0.5, 1))
    cyl(0.07 * s, 1.1 * s, stem or mv, loc=(x0 + 0.25 * s, y0 + 0.05 * s, z0 - 0.95 * s), rot=(0, -22, 0), bevel=0.02)


def i_luck():
    """Lucky Builder: a big green four-leaf clover in front of a gold coin"""
    coin(loc=(0.15, 0.6, 0.2), rot=(90, 0, 0), r=1.25)
    clover(loc=(0, -0.3, 0.25), s=1.0)
    track(badge, "2x", (1.25, -0.9, -0.85), s=0.7, col="#3fd36a", rot=(-10, 0, 0))


def i_ultraluck():
    """Ultra Lucky: a golden clover, two green ones behind it, a 3x badge"""
    clover(loc=(-1.05, 0.6, 0.75), s=0.62, rot=12)
    clover(loc=(1.1, 0.6, 0.7), s=0.6, rot=-14)
    clover(loc=(0, -0.3, 0.1), s=1.0, mat=gold(), vmat=gold_dark(), stem=gold_dark())
    track(badge, "3x", (1.3, -1.0, -0.9), s=0.72, col="#ff9a1c", rot=(-10, 0, 0))


def i_offline():
    """Night Shift: a crescent moon over a little house with a lit window, coins, zZ"""
    # the crescent: a circle minus a circle, as a flat outline
    pts = []
    for i in range(48):
        a = math.radians(60 + 240 * i / 47)          # the outer edge, round the left side
        pts.append((math.cos(a) * 1.0, math.sin(a) * 1.0))
    for i in range(48):
        a = math.radians(250 - 140 * i / 47)         # the inner edge, back up its left side
        pts.append((0.42 + math.cos(a) * 0.78, math.sin(a) * 0.78))
    moon = candy("#ffe27a", rough=0.25, emit=0.6)
    poly(pts, 0.35, moon, loc=(-0.55, 0.3, 0.75), rot=(0, -20, 0), bevel=0.06)
    wall = candy("#f6efe2", rough=0.4, emit=0.2)
    roof = candy("#ff5a4a", rough=0.3, emit=0.15)
    box((1.3, 1.0, 1.0), wall, loc=(0.75, -0.2, -0.9), bevel=0.05)
    poly([(-0.8, 0), (0.8, 0), (0, 0.62)], 1.15, roof, loc=(0.75, -0.2 + 0.55, -0.4), bevel=0.05)
    box((0.36, 0.06, 0.36), glow("#ffd860", 2.6), loc=(0.45, -0.73, -0.85), bevel=0.02, outline=False)
    box((0.3, 0.06, 0.5), candy("#7a4a26", rough=0.5), loc=(1.05, -0.73, -1.15), bevel=0.02)
    for (x, z, r) in ((-1.25, -1.2, 0.36), (-0.75, -1.35, 0.3)):
        coin(loc=(x, -0.6, z), rot=(80, 0, 15), r=r)
    zmat = candy("#c9d4ff", rough=0.3, emit=0.5)
    R.text("z", 0.55, 0.12, zmat, loc=(0.85, -0.2, 0.75), rot=(90, 0, 0))
    R.text("Z", 0.75, 0.14, zmat, loc=(1.25, -0.2, 1.2), rot=(90, 0, 0))


def i_hunter():
    """Secret Hunter: a gold magnifying glass over a dark Secret gem"""
    secret = ("#d8c8ff", "#8a6ae0", "#5a3ab8", "#3a2290", "#24146a", "#4a2aa8")
    gem(secret, loc=(0.35, 0.6, 0.05), rot=(12, 0, 15), s=0.95)
    g = gold()
    torus(0.95, 0.13, g, loc=(-0.15, -0.2, 0.25), rot=(90, 0, 0))
    lens = pbr("lens", "#cfefff", rough=0.02, coat=1.0, emit=0.1)
    lens.node_tree.nodes["Principled BSDF"].inputs["Alpha"].default_value = 0.28
    try:
        lens.surface_render_method = "BLENDED"
    except Exception:
        pass
    sphere(0.88, lens, loc=(-0.15, -0.2, 0.25), scale=(1, 0.12, 1), outline=False)
    cyl(0.16, 1.25, candy("#3a2a5a", rough=0.4), loc=(0.85, -0.2, -0.95), rot=(0, 40, 0), bevel=0.05)
    cyl(0.19, 0.18, g, loc=(0.52, -0.2, -0.6), rot=(0, 40, 0), bevel=0.03)
    track(badge, "2x", (-1.15, -0.9, -1.0), s=0.66, col="#9a5cff", rot=(-10, 0, 0))


ICONS = dict(R.ICONS)
ICONS.update({"luck": i_luck, "ultraluck": i_ultraluck, "offline": i_offline, "hunter": i_hunter})


# ------------------------------------------------------------------------------------------- 2D: the premium card
def _hex(h):
    h = h.lstrip("#")
    return np.array([int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)], np.float32)


def _grade(img, sat=1.16, con=1.07):
    """a touch richer and crisper: saturation and contrast on the colour, alpha kept"""
    rgb = img[..., :3]
    lum = (rgb * np.array([0.299, 0.587, 0.114], np.float32)).sum(-1, keepdims=True)
    rgb = lum + (rgb - lum) * sat
    rgb = (rgb - 0.5) * con + 0.5
    return np.concatenate([np.clip(rgb, 0, 1), img[..., 3:4]], -1)


def _sharpen(img, amount=0.55, sigma=1.0):
    rgb = img[..., :3]
    out = np.empty_like(rgb)
    for c in range(3):
        out[..., c] = rgb[..., c] + amount * (rgb[..., c] - postnp.blur(rgb[..., c], sigma))
    return np.concatenate([np.clip(out, 0, 1), img[..., 3:4]], -1)


def premium_card(icon_canvas, key, size=512, fill=0.8):
    c0, c1 = (_hex(c) for c in LOOK.get(key, ("#5a7dff", "#0a1240")))
    yy, xx = np.mgrid[0:size, 0:size].astype(np.float32)
    cx, cy = (size - 1) / 2, (size - 1) / 2
    d = np.sqrt((xx - cx) ** 2 + (yy - cy) ** 2) / (size / 2)
    # deep backdrop: the colour in the middle, very dark at the edge (round: Roblox shows passes in a circle)
    t = np.clip((d - 0.08) / 0.92, 0, 1) ** 1.25
    rgb = c0[None, None] * (1 - t[..., None]) + c1[None, None] * t[..., None]
    # a spotlight behind the object, a little above the middle
    ds = np.sqrt((xx - cx) ** 2 + (yy - cy * 0.9) ** 2) / (size / 2)
    spot = np.exp(-(ds / 0.42) ** 2)[..., None]
    rgb = rgb + (np.clip(c0 * 1.35, 0, 1) - rgb) * spot * 0.55
    # a soft floor shadow under it
    sh = np.exp(-(((xx - cx) / (size * 0.3)) ** 2 + ((yy - size * 0.84) / (size * 0.05)) ** 2))[..., None]
    rgb = rgb * (1 - sh * 0.45)
    out = np.concatenate([np.clip(rgb, 0, 1), np.ones((size, size, 1), np.float32)], -1)
    # the object: graded, brought down to its size, sharpened
    n = int(size * fill)
    ic = _sharpen(postnp.resize(_grade(icon_canvas), n))
    o = (size - n) // 2
    oy = o - int(size * 0.02)
    out[oy:oy + n, o:o + n] = postnp.over(out[oy:oy + n, o:o + n], ic)
    # a thin gold ring just inside the circle, lighter at the top
    ring = np.clip(1 - np.abs(d - 0.955) / 0.012, 0, 1)
    gold_c = _hex("#ffe08a") * (1 - (yy / size)[..., None] * 0.5) + _hex("#b8740e") * ((yy / size)[..., None] * 0.5)
    out[..., :3] = out[..., :3] * (1 - ring[..., None]) + gold_c * ring[..., None]
    # outside the ring: the deepest colour (the corners Roblox cuts away on passes, kept clean on products)
    outside = np.clip((d - 0.967) / 0.01, 0, 1)[..., None]
    out[..., :3] = out[..., :3] * (1 - outside) + (c1 * 0.7) * outside
    out[..., 3] = 1
    return out


# ------------------------------------------------------------------------------------------- run
def render(names=None, size=1024, samples=160):
    import bpy
    names = names or (PASSES + PRODUCTS)
    for sub in ("raw", ""):
        os.makedirs(os.path.join(OUT, sub), exist_ok=True)
    R.AIR_STARS = False
    done = []
    for n in names:
        I3.reset()
        T._M.clear()
        I.OUTLINE = 0.034
        R.GROUPS.clear()
        R.CRATE_O.clear()
        ICONS[n]()
        I.add_outlines()
        scn = I3.iscene()
        scn.render.resolution_x = scn.render.resolution_y = size
        scn.cycles.samples = samples
        raw = os.path.join(OUT, "raw", n + ".png")
        I.frame_and_render(raw, view=VIEW.get(n) or R.VIEW.get(n, (-0.2, -1, 0.32)), margin=1.08)
        key = "thumb_" + n
        postnp.SPARKLE[key] = []
        rawpx = postnp.load(raw)
        canvas = postnp.canvas_of(rawpx, key)
        postnp.save(premium_card(canvas, n, fill=FILL.get(n, 0.8)), os.path.join(OUT, n + ".png"))
        done.append(n)
    I3.clear()
    return done
