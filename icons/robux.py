"""BlockRise Empire - icons for everything sold for Robux (13 game passes + 15 developer products).

Same pipeline as the material icons (items.py): PBR "candy" materials under the studio HDRI and suns, inverted-hull
outline, 2D sticker finish. Two outputs per item:
  * OUT/game/<key>.png  256 px, transparent: used inside the game (Store, HUD...)
  * OUT/card/<key>.png  512 px, opaque premium card (radial glow + rays): for the Creator Hub (game pass / product image;
    passes are shown in a circle there, so the art stays inside the middle 80 %)

    import robux; robux.render()              # all
    robux.render(["vip", "gems100"])          # some
"""
import bpy, bmesh, math, os, random
import numpy as np
from mathutils import Vector, Matrix
import icons as I
import icons3 as I3
import postnp
import items as T
from items import pbr, obj, bm_box, bm_cyl, bm_prism, bm_hull, bm_tube, circle, _xf

OUT = os.path.join(I3.OUT, "robux")
TAU = math.tau


# ------------------------------------------------------------------------------------------- materials
def candy(hexcol, rough=0.28, coat=0.8, emit=0.16, **kw):
    return pbr("c" + hexcol + str(rough), hexcol, rough=rough, coat=coat, emit=emit, **kw)


def gold():
    return pbr("gold", "#ffc534", metal=1.0, rough=0.14, coat=0.45, tex="hammered", scale=3.0, bump=0.04, dark="#f2ae22", light="#ffd86a", emit=0.32)


def gold_dark():
    return pbr("gold_dark", "#e39a1a", metal=1.0, rough=0.22, coat=0.3, emit=0.25)


def chrome():
    return pbr("chrome", "#eef2f8", metal=1.0, rough=0.12, coat=0.6, emit=0.2)


def rubber():
    return pbr("rubber", "#2b2d38", rough=0.55, coat=0.1, emit=0.05)


def glow(hexcol, s=2.5):
    return pbr("glow" + hexcol, hexcol, rough=0.3, coat=0.0, emit=s)


def repaint(root, metal_hex=("#9aa3b8", "#c9d1de", "#454c5e")):
    """objects made with the old toon helpers (icons.py) get the PBR candy look, same colours"""
    obs = [root] + list(root.children_recursive) if root else []
    for ob in obs:
        if ob.type != "MESH":
            continue
        for slot in ob.material_slots:
            m = slot.material
            if m and m.name.startswith("m#"):
                h = m.name[1:8]
                slot.material = pbr("metal" + h, h, metal=1.0, rough=0.18, coat=0.5, emit=0.2) if h in metal_hex else candy(h)
    return root


# ------------------------------------------------------------------------------------------- shapes
_FONT = None


def font():
    global _FONT
    if _FONT is None:
        for f in ("C:/Windows/Fonts/ariblk.ttf", "C:/Windows/Fonts/impact.ttf", "C:/Windows/Fonts/arialbd.ttf"):
            if os.path.exists(f):
                _FONT = bpy.data.fonts.load(f, check_existing=True)
                break
    return _FONT


def text(s, size, depth, mat, loc=(0, 0, 0), rot=(90, 0, 0), bevel=0.02, outline=True):
    cu = bpy.data.curves.new("txt", "FONT")
    cu.body = s
    cu.size = size
    cu.extrude = depth
    cu.bevel_depth = bevel
    cu.bevel_resolution = 2
    cu.align_x, cu.align_y = "CENTER", "CENTER"
    f = font()
    if f:
        cu.font = f
    ob = bpy.data.objects.new("txt", cu)
    I3.iscene().collection.objects.link(ob)
    bpy.context.view_layer.update()
    dg = bpy.context.evaluated_depsgraph_get()
    me = bpy.data.meshes.new_from_object(ob.evaluated_get(dg), depsgraph=dg)
    bpy.data.objects.remove(ob, do_unlink=True)
    bpy.data.curves.remove(cu)
    me.materials.clear()
    me.materials.append(mat)
    t = bpy.data.objects.new("txt", me)
    I3.iscene().collection.objects.link(t)
    t.matrix_world = _xf(loc, rot)
    if not outline:
        t["no_outline"] = True
    return t


def sphere(r, mat, loc=(0, 0, 0), scale=(1, 1, 1), rot=(0, 0, 0), outline=True):
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=40, v_segments=20, radius=r)
    return obj("sphere", bm, mat, loc=loc, rot=rot, scale=scale, smooth=80, outline=outline)


def torus(R, r, mat, loc=(0, 0, 0), rot=(0, 0, 0), seg=64, ring=14, a0=0.0, a1=TAU, outline=True):
    closed = abs(a1 - a0 - TAU) < 1e-6
    n = seg if closed else seg + 1
    path = [(math.cos(a0 + (a1 - a0) * i / seg) * R, math.sin(a0 + (a1 - a0) * i / seg) * R, 0) for i in range(n)]
    bm = bmesh.new()
    if closed:
        # a closed ring: build the rings by hand and join the last to the first
        rings = []
        for i in range(seg):
            a = TAU * i / seg
            c = Vector((math.cos(a) * R, math.sin(a) * R, 0))
            nn = Vector((math.cos(a), math.sin(a), 0))
            rings.append([bm.verts.new(c + (nn * math.cos(TAU * j / ring) + Vector((0, 0, 1)) * math.sin(TAU * j / ring)) * r) for j in range(ring)])
        for i in range(seg):
            r0, r1 = rings[i], rings[(i + 1) % seg]
            for j in range(ring):
                bm.faces.new((r0[j], r0[(j + 1) % ring], r1[(j + 1) % ring], r1[j]))
    else:
        bm_tube(path, r, ring=ring, bm=bm)
    return obj("torus", bm, mat, loc=loc, rot=rot, smooth=80, outline=outline)


def box(size, mat, loc=(0, 0, 0), rot=(0, 0, 0), bevel=0.06, outline=True, parent=None):
    return obj("box", bm_box(*size), mat, loc=loc, rot=rot, bevel=bevel, outline=outline, parent=parent)


def cyl(r, depth, mat, loc=(0, 0, 0), rot=(0, 0, 0), r2=None, segs=48, bevel=0.03, axis="Z", outline=True, parent=None):
    return obj("cyl", bm_cyl(r, depth, segs, r2=r2, axis=axis), mat, loc=loc, rot=rot, smooth=40, bevel=bevel, outline=outline, parent=parent)


def poly(pts, depth, mat, loc=(0, 0, 0), rot=(0, 0, 0), bevel=0.04, outline=True):
    """2D outline in the picture plane (x right, y up), facing the camera (-Y)"""
    bm = bm_prism(pts, depth, axis="Y")
    for v in bm.verts:
        v.co.z = -v.co.z
    return obj("poly", bm, mat, loc=loc, rot=rot, bevel=bevel, outline=outline)


def star_pts(r1, r2, n=5, rot=90):
    return [(math.cos(math.radians(rot) + i * math.pi / n) * (r1 if i % 2 == 0 else r2),
             math.sin(math.radians(rot) + i * math.pi / n) * (r1 if i % 2 == 0 else r2)) for i in range(2 * n)]


BOLT = [(0.15, 1.0), (-0.55, -0.05), (-0.05, -0.05), (-0.3, -1.0), (0.6, 0.15), (0.08, 0.15), (0.42, 1.0)]


def gem(cols, loc=(0, 0, 0), rot=(0, 0, 0), s=1.0, glow_=0.42):
    """brilliant cut: table, crown, girdle, pavilion; cols = 6 tints light -> dark"""
    bm = bmesh.new()
    TOP, GT, GB, CUL = 0.5, 0.14, 0.04, -1.05
    table = [bm.verts.new((math.cos(TAU * i / 8 + math.pi / 8) * 0.56 * s, math.sin(TAU * i / 8 + math.pi / 8) * 0.56 * s, TOP * s)) for i in range(8)]
    gt = [bm.verts.new((math.cos(TAU * k / 16 + math.pi / 8) * s, math.sin(TAU * k / 16 + math.pi / 8) * s, GT * s)) for k in range(16)]
    gb = [bm.verts.new((v.co.x, v.co.y, GB * s)) for v in gt]
    mid = [bm.verts.new((math.cos(TAU * k / 8 + math.pi / 4) * 0.52 * s, math.sin(TAU * k / 8 + math.pi / 4) * 0.52 * s, -0.5 * s)) for k in range(8)]
    culet = bm.verts.new((0, 0, CUL * s))
    faces = [(bm.faces.new(table), 0)]
    for i in range(8):
        t0, t1 = table[i], table[(i + 1) % 8]
        g0, g1, g2 = gt[2 * i], gt[2 * i + 1], gt[(2 * i + 2) % 16]
        faces += [(bm.faces.new((t0, g0, g1)), 1), (bm.faces.new((t0, g1, t1)), 2), (bm.faces.new((t1, g1, g2)), 1)]
    for k in range(16):
        faces.append((bm.faces.new((gt[k], gb[k], gb[(k + 1) % 16], gt[(k + 1) % 16])), 3))
    for i in range(8):
        a, b, c3 = gb[2 * i], gb[2 * i + 1], gb[(2 * i + 2) % 16]
        m = mid[i]
        faces += [(bm.faces.new((a, m, b)), 4), (bm.faces.new((b, m, c3)), 5), (bm.faces.new((a, culet, m)), 5 if i % 2 else 4),
                  (bm.faces.new((m, culet, c3)), 4 if i % 2 else 5)]
    for f, mi in faces:
        f.material_index = mi
    mats = [pbr("gem" + c, c, rough=0.06, coat=1.0, emit=glow_ if k < 4 else glow_ + 0.25) for k, c in enumerate(cols)]
    return obj("gem", bm, mats, loc=loc, rot=rot)


BLUE_GEM = ("#c8f6ff", "#62d8ff", "#2cb4ff", "#1c8cf0", "#1667ff", "#2a8cff")
PINK_GEM = ("#ffd2ef", "#ff7ccc", "#ff4aa8", "#e8308c", "#c4206e", "#e83a8c")
GREEN_GEM = ("#d4ffd9", "#7ef09a", "#3fd36a", "#22b14e", "#178a3b", "#26a64c")
PURPLE_GEM = ("#ecd8ff", "#c08bff", "#9a5cff", "#7a3ee6", "#5b28c2", "#7c40e8")
RED_GEM = ("#ffd2d6", "#ff7a86", "#ff3d50", "#e0223a", "#b5122a", "#e3283f")


def coin(loc=(0, 0, 0), rot=(75, 0, 15), r=0.8):
    g = gold()
    P = _xf(loc, rot)
    obj("coin", bm_cyl(r, 0.24, 64), g, parent=P, smooth=40, bevel=0.05)
    obj("coin_in", bm_cyl(r * 0.76, 0.27, 64), gold_dark(), parent=P, smooth=40, bevel=0.02, outline=False)
    t = text("$", r * 1.15, 0.04, g, rot=(0, 0, 0), outline=False)
    t.matrix_world = P @ Matrix.Translation((0, 0, 0.14)) @ t.matrix_world
    t2 = text("$", r * 1.15, 0.04, g, rot=(0, 180, 0), outline=False)
    t2.matrix_world = P @ Matrix.Translation((0, 0, -0.14)) @ t2.matrix_world


def bills(loc=(0, 0, 0), rot=(0, 0, 0), n=7, s=1.0, band="#ffffff"):
    """a brick of green bank notes with a paper band and a $ seal on top"""
    P = _xf(loc, rot, s)
    random.seed(n)
    g1 = candy("#56c46a", rough=0.5, coat=0.3)
    g2 = candy("#7fdc8a", rough=0.5, coat=0.3)
    for i in range(n):
        obj("bill", bm_box(1.9, 0.95, 0.06), g1 if i % 2 else g2, loc=(random.uniform(-0.04, 0.04), random.uniform(-0.03, 0.03), 0.03 + i * 0.065),
            rot=(0, 0, random.uniform(-2.5, 2.5)), parent=P, bevel=0.01, outline=i == n - 1)
    top = 0.065 * n
    obj("bill_border", bm_box(1.62, 0.7, 0.02), candy("#3fa856", rough=0.5, coat=0.3), loc=(0, 0, top + 0.012), parent=P, bevel=0.005, outline=False)
    obj("bill_face", bm_box(1.5, 0.6, 0.025), candy("#8fe39a", rough=0.5, coat=0.3), loc=(0, 0, top + 0.02), parent=P, bevel=0.005, outline=False)
    obj("band", bm_box(0.42, 1.0, 0.065 * n + 0.08), candy(band, rough=0.45, coat=0.3), loc=(0, 0, top / 2 + 0.02), parent=P, bevel=0.01)
    obj("seal", bm_cyl(0.26, 0.05, 40), candy("#2f9a4a", rough=0.4), loc=(0.55, 0, top + 0.035), parent=P, smooth=40, outline=False)
    t = text("$", 0.4, 0.02, candy("#e9fbe9", rough=0.4), rot=(0, 0, 90), outline=False)
    t.matrix_world = P @ Matrix.Translation((0.55, 0, top + 0.065)) @ t.matrix_world


def money_bag(loc=(0, 0, 0), rot=(0, 0, 0), s=1.0, cloth="#d6a35a", sign="#2e9e4a"):
    P = _xf(loc, rot, s)
    c = pbr("bagcloth", cloth, rough=0.65, coat=0.1, tex="leaf", scale=5.0, bump=0.15, dark="#cf9a52", light="#dfae66", emit=0.18)
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=48, v_segments=24, radius=1.0)
    for v in bm.verts:
        z = v.co.z
        k = 1.0 + 0.18 * max(0.0, -z)          # fuller at the bottom
        v.co.x *= k
        v.co.y *= k * 0.92
        if z < -0.55:
            v.co.z = -0.55 + (z + 0.55) * 0.4  # flat-ish bottom
    obj("bag", bm, c, loc=(0, 0, 0.9), parent=P, smooth=80)
    obj("neck", bm_cyl(0.32, 0.4, 32, r2=0.42), c, loc=(0, 0, 1.95), parent=P, smooth=40)
    # the gathered top flares out above the tie
    obj("ruffle", bm_cyl(0.34, 0.5, 40, r2=0.62), c, loc=(0, 0, 2.3), parent=P, smooth=40, bevel=0.06)
    torus(0.4, 0.11, candy("#8a4a20", rough=0.6, coat=0.1)).matrix_world = P @ _xf((0, 0, 1.98))
    # the $ sits in the middle of the round part, facing the camera, bent to follow the cloth
    t = text("$", 1.05, 0.1, candy(sign, rough=0.3), rot=(90, 0, 0))
    for v in t.data.vertices:
        v.co.z -= (v.co.x ** 2 + v.co.y ** 2) / 2.0
    t.matrix_world = P @ _xf((0, -0.89, 1.26), (70.6, 0, 0))


def badge(label, loc, s=1.0, col="#ff3b4a", txt="#ffffff", rot=(0, 0, 0), shape="circle"):
    """a round (or star) sticker with big text: 2X, +3, x5 ..."""
    P = _xf(loc, rot, s)
    pts = star_pts(0.95, 0.78, 12, 90) if shape == "burst" else circle(0.82, 64)
    bm = bm_prism(pts, 0.28, axis="Y")
    obj("badge", bm, candy(col, rough=0.25), parent=P, bevel=0.06)
    bm2 = bm_prism([(x * 0.86, y * 0.86) for x, y in (pts)], 0.3, axis="Y")
    obj("badge_in", bm2, candy(col, rough=0.18, emit=0.3), loc=(0, -0.02, 0), parent=P, bevel=0.03, outline=False)
    t = text(label, 0.78 if len(label) <= 2 else 0.6, 0.12, candy(txt, rough=0.3, emit=0.4))
    t.matrix_world = P @ _xf((0, -0.2, -0.02), (90, 0, 0))


def arrow_loop(loc, rot=(0, 0, 0), R=1.25, col="#3fd36a"):
    """two curved arrows going round (auto / repeat)"""
    m = candy(col, rough=0.25)
    P = _xf(loc, rot)
    for a0 in (0.25, math.pi + 0.25):
        t = torus(R, 0.12, m, a0=a0, a1=a0 + 2.3, seg=40)
        t.matrix_world = P @ _xf((0, 0, 0), (90, 0, 0)) @ t.matrix_world
        a = a0 + 2.3
        head = obj("head", bm_cyl(0.3, 0.55, 32, r2=0.0), m, smooth=40)
        # cone pointing along the tangent at the arrow's end
        tip = Vector((math.cos(a) * R, math.sin(a) * R, 0))
        tan = Vector((-math.sin(a), math.cos(a), 0))
        q = Vector((0, 0, 1)).rotation_difference(tan).to_matrix().to_4x4()
        head.matrix_world = P @ _xf((0, 0, 0), (90, 0, 0)) @ Matrix.Translation(tip + tan * 0.2) @ q


def hardhat(loc, rot=(0, 0, 0), col="#ffc534", s=1.0):
    root = I.hardhat(loc=loc, rot=rot, color=col)
    root.scale = (s, s, s)
    return repaint(root)


def wheel_(loc, r=0.55, w=0.45, rim=None, rot=(90, 0, 0), tread=True, parent=None):
    P = _xf(loc, rot)
    if parent is not None:
        P = parent @ P
    obj("tire", bm_cyl(r, w, 48), rubber(), parent=P, smooth=40, bevel=0.08)
    if tread:
        for k in range(18):
            a = TAU * k / 18
            obj("tread", bm_box(0.16 * r / 0.55, 0.1, w * 0.95), rubber(), loc=(math.cos(a) * r, math.sin(a) * r, 0), rot=(0, 0, math.degrees(a)), parent=P,
                bevel=0.02, outline=False)
    obj("rim", bm_cyl(r * 0.6, w + 0.04, 40), rim or chrome(), parent=P, smooth=40, bevel=0.03)
    obj("hub", bm_cyl(r * 0.22, w + 0.08, 24), gold_dark() if rim is None else chrome(), parent=P, smooth=40, bevel=0.02, outline=False)


# ------------------------------------------------------------------------------------------- the icons
def i_skipanim():
    """a big glossy play button with a skip-forward symbol"""
    cyl(1.25, 0.4, candy("#2f8cff"), rot=(90, 0, 0), bevel=0.12, segs=72)
    cyl(1.05, 0.44, candy("#58b0ff", rough=0.18, emit=0.3), loc=(0, -0.03, 0), rot=(90, 0, 0), bevel=0.06, segs=72, outline=False)
    w = candy("#ffffff", rough=0.25, emit=0.5)
    poly([(-0.62, 0.48), (0.02, 0.0), (-0.62, -0.48)], 0.3, w, loc=(0.0, -0.3, 0))
    poly([(-0.06, 0.48), (0.58, 0.0), (-0.06, -0.48)], 0.3, w, loc=(0.0, -0.3, 0))
    box((0.16, 0.3, 0.96), w, loc=(0.66, -0.3, 0), bevel=0.04)


def i_stormhammer():
    """the Thunderclap Hammer: rendered from its spec (hammers/bl_build.py), with lightning bolts behind"""
    import bl_build as B
    spec = B.load_spec()
    h = [x for x in spec["hammers"] if x["key"] == "thunder"][0]
    B._M.clear()
    B.build(h, spec["palette"])
    yb = glow("#ffe14a", 3.5)
    poly(BOLT, 0.25, yb, loc=(0.85, 0.8, 0.95), rot=(0, 18, 0)).scale = (0.55, 0.55, 0.55)
    poly(BOLT, 0.25, glow("#7fd4ff", 3.5), loc=(-0.95, 0.8, 0.55), rot=(0, -20, 0)).scale = (0.45, 0.45, 0.45)


def i_teleporter():
    pad = pbr("pad", "#3b4256", metal=0.7, rough=0.3, coat=0.5, emit=0.1)
    cyl(1.35, 0.3, pad, loc=(0, 0, 0.15), bevel=0.08, segs=72)
    cyl(1.1, 0.34, glow("#4fe3ff", 2.2), loc=(0, 0, 0.17), segs=72, bevel=0.02, outline=False)
    cyl(0.95, 0.38, pad, loc=(0, 0, 0.18), segs=72, bevel=0.04, outline=False)
    beam = pbr("beam", "#8ff0ff", rough=0.3, emit=1.6)
    beam.node_tree.nodes["Principled BSDF"].inputs["Alpha"].default_value = 0.45
    try:
        beam.surface_render_method = "BLENDED"
    except Exception:
        pass
    cyl(0.85, 1.6, beam, loc=(0, 0, 1.15), r2=0.66, segs=64, bevel=0.0, outline=False)
    for z, r in ((0.75, 0.86), (1.35, 0.74)):
        torus(r, 0.04, glow("#c9fbff", 3.0), loc=(0, 0, z), outline=False)
    # location pin floating in the beam
    red = candy("#ff3b4a")
    sphere(0.62, red, loc=(0, 0, 2.75))
    cyl(0.54, 0.95, red, loc=(0, 0, 2.08), r2=0.0, rot=(180, 0, 0), segs=48, bevel=0.0)
    sphere(0.25, candy("#ffffff"), loc=(0, -0.48, 2.82), scale=(1, 0.5, 1))


def i_vip():
    """a gold crown with rubies and a sapphire, velvet inside"""
    g = gold()
    obj("band", bm_prism(circle(1.15, 72), 0.62, holes=circle(0.98, 72)), g, loc=(0, 0, 0.3), smooth=40, bevel=0.04)
    obj("rim_low", bm_prism(circle(1.2, 72), 0.14, holes=circle(0.98, 72)), gold_dark(), loc=(0, 0, 0.02), smooth=40, bevel=0.03)
    sphere(1.0, candy("#a3122e", rough=0.55, coat=0.2), loc=(0, 0, 0.55), scale=(1, 1, 0.55), outline=False)
    for k in range(5):
        a = TAU * k / 5 - math.pi / 2
        x, y = math.cos(a) * 1.06, math.sin(a) * 1.06
        cyl(0.3, 0.95, g, loc=(x, y, 1.05), r2=0.04, segs=4, rot=(0, 0, math.degrees(a) + 45), bevel=0.03)
        sphere(0.14, candy("#fff3d0", rough=0.1, emit=0.4), loc=(x * 1.02, y * 1.02, 1.56))
    for k, cols in enumerate((RED_GEM, BLUE_GEM, RED_GEM)):
        a = -math.pi / 2 + (k - 1) * 0.62
        gem(cols, loc=(math.cos(a) * 1.18, math.sin(a) * 1.18, 0.32), rot=(90, 0, math.degrees(a) + 90), s=0.24)


def i_bigcrew():
    hardhat((-0.85, 0.9, 0.75), rot=(-25, 0, 25), col="#ff8a26", s=0.75)
    hardhat((0.85, 0.9, 0.75), rot=(-25, 0, -25), col="#3d8cff", s=0.75)
    hardhat((0, -0.4, 0.0), rot=(-22, 0, 0), col="#ffc534", s=1.0)
    badge("+3", (1.25, -1.2, 1.15), s=0.8, col="#3fd36a", rot=(-24, 0, 0))


def i_cash2x():
    bills((-0.2, 0.25, 0), rot=(0, 0, 12), n=8)
    bills((0.25, -0.35, 0.0), rot=(0, 0, -8), n=5, s=0.95)
    coin(loc=(-1.25, -0.55, 0.35), rot=(72, 0, 25), r=0.55)
    badge("2X", (1.15, -1.0, 1.05), s=0.8, rot=(-36, 0, 0))


def dumbbell(loc, rot=(0, 0, 0), plate="#ff3b4a", s=1.0):
    P = _xf(loc, rot, s)
    obj("bar", bm_cyl(0.13, 2.5, 32, axis="X"), chrome(), parent=P, smooth=40, bevel=0.02)
    for sx in (-1, 1):
        obj("plate", bm_cyl(0.68, 0.32, 48, axis="X"), candy(plate), loc=(sx * 0.82, 0, 0), parent=P, smooth=40, bevel=0.07)
        obj("plate2", bm_cyl(0.52, 0.22, 48, axis="X"), candy(plate), loc=(sx * 1.08, 0, 0), parent=P, smooth=40, bevel=0.06)
        obj("collar", bm_cyl(0.2, 0.12, 32, axis="X"), chrome(), loc=(sx * 1.24, 0, 0), parent=P, smooth=40, bevel=0.02)


def i_strength2x():
    dumbbell((0, 0, 0.3), rot=(0, -25, -15), plate="#ff6a2b")
    badge("2X", (1.1, -0.9, 1.25), s=0.8, rot=(-16, 0, 0))


def robot(loc=(0, 0, 0), rot=(0, 0, 0), s=1.0):
    P = _xf(loc, rot, s)
    body = candy("#e9eef7", rough=0.25)
    trim = candy("#3d8cff", rough=0.25)
    obj("torso", bm_box(1.3, 0.9, 1.0), body, loc=(0, 0, 0.6), parent=P, bevel=0.18)
    obj("chest", bm_box(0.7, 0.1, 0.45), trim, loc=(0, -0.45, 0.65), parent=P, bevel=0.05)
    obj("head", bm_box(1.25, 1.0, 0.9), body, loc=(0, 0, 1.65), parent=P, bevel=0.22)
    obj("face", bm_box(1.0, 0.12, 0.62), candy("#1d2133", rough=0.15), loc=(0, -0.48, 1.65), parent=P, bevel=0.08)
    for x in (-0.24, 0.24):
        obj("eye", bm_box(0.2, 0.08, 0.26), glow("#5ff0ff", 3.0), loc=(x, -0.56, 1.7), parent=P, bevel=0.06, outline=False)
    obj("antenna", bm_cyl(0.05, 0.4, 16), chrome(), loc=(0, 0, 2.25), parent=P, smooth=40)
    s2 = sphere(0.14, glow("#ff4a5a", 2.0))
    s2.matrix_world = P @ _xf((0, 0, 2.5))
    # hard hat on its head
    hh = I.hardhat(color="#ffc534")
    repaint(hh)
    hh.matrix_world = P @ _xf((0, 0, 2.05), (-5, 0, 0), 0.62)
    # arm with a hammer
    obj("arm", bm_box(0.3, 0.3, 0.8), body, loc=(0.85, -0.1, 0.75), rot=(0, -40, 0), parent=P, bevel=0.1)
    hm = I.hammer(s=0.85)
    repaint(hm)
    hm.matrix_world = P @ _xf((1.2, -0.25, 1.2), (0, -35, 0))
    for x in (-0.38, 0.38):
        obj("leg", bm_box(0.36, 0.4, 0.35), trim, loc=(x, 0, 0.0), parent=P, bevel=0.08)


def i_autobuild():
    robot(rot=(0, 0, -12))
    badge("AUTO", (-1.15, -0.8, 0.45), s=0.62, col="#3fd36a", rot=(-16, 0, 0))


def i_autotrain():
    dumbbell((0, 0, 0.1), rot=(0, -20, -10), plate="#ff8a26", s=0.85)
    arrow_loop((0, -0.2, 0.1), R=1.55, col="#3fd36a")


def i_gems2x():
    gem(BLUE_GEM, loc=(-0.35, 0.3, 0.2), rot=(10, 0, 12), s=1.0)
    gem(PINK_GEM, loc=(0.75, -0.2, -0.2), rot=(10, 0, -18), s=0.72)
    badge("2X", (1.1, -0.9, 0.95), s=0.75, rot=(-16, 0, 0))


def i_fasttools():
    hm = I.hammer(s=1.7)
    repaint(hm)
    for ob in hm.children_recursive:
        if ob.type == "MESH" and ob.data.materials and "9aa3b8" in ob.data.materials[0].name:
            ob.data.materials[0] = gold()
    hm.matrix_world = _xf((0.3, 0, 0), (0, -40, 0))
    for k, (z, l, c) in enumerate(((0.95, 1.6, "#ffc534"), (0.45, 2.1, "#ff8a26"), (-0.05, 1.4, "#ffc534"))):
        box((l, 0.12, 0.16), candy(c, emit=0.5), loc=(-1.25 - l * 0.25, 0.35, z), bevel=0.06)
    poly(BOLT, 0.25, glow("#ffe14a", 2.5), loc=(1.35, -0.5, -0.9), rot=(0, 15, 0)).scale = (0.7, 0.7, 0.7)


def i_monster():
    red = candy("#ff3b4a")
    P = _xf((0, 0, 0), (0, 0, -24))
    obj("body", bm_box(2.6, 1.3, 0.55), red, loc=(0, 0, 1.25), parent=P, bevel=0.16)
    obj("cab", bm_box(1.25, 1.2, 0.75), red, loc=(-0.25, 0, 1.85), parent=P, bevel=0.18)
    obj("win", bm_box(1.05, 1.24, 0.45), candy("#bfe6ff", rough=0.08), loc=(-0.25, 0, 1.9), parent=P, bevel=0.1)
    obj("bumper", bm_box(0.25, 1.4, 0.3), chrome(), loc=(1.35, 0, 1.05), parent=P, bevel=0.08)
    obj("frame", bm_box(2.2, 0.8, 0.25), candy("#2b2d38"), loc=(0, 0, 0.85), parent=P, bevel=0.05)
    for x in (-0.95, 0.95):
        for y in (-0.85, 0.85):
            wheel_((x, y, 0.62), r=0.62, w=0.55, parent=P, rim=chrome())
    obj("flame", bm_box(0.9, 0.04, 0.2), candy("#ffc534", emit=0.4), loc=(0.6, -0.66, 1.25), parent=P, bevel=0.03, outline=False)


def i_goldcar():
    g = gold()
    P = _xf((0, 0, 0), (0, 0, -38))
    # low wedge body: hull of a few points
    pts = [(-1.5, -0.62, 0.2), (1.55, -0.6, 0.2), (-1.5, 0.62, 0.2), (1.55, 0.6, 0.2), (-1.45, -0.6, 0.62), (-1.45, 0.6, 0.62),
           (1.6, -0.5, 0.42), (1.6, 0.5, 0.42), (0.5, -0.58, 0.68), (0.5, 0.58, 0.68)]
    obj("body", bm_hull(pts), g, parent=P, bevel=0.08)
    cab = [(-0.9, -0.5, 0.6), (0.55, -0.5, 0.6), (-0.9, 0.5, 0.6), (0.55, 0.5, 0.6), (-0.55, -0.38, 1.0), (0.05, -0.38, 1.0), (-0.55, 0.38, 1.0), (0.05, 0.38, 1.0)]
    obj("cab", bm_hull(cab), candy("#1d2133", rough=0.1), parent=P, bevel=0.06)
    obj("spoiler", bm_box(0.35, 1.3, 0.08), g, loc=(-1.45, 0, 0.98), parent=P, bevel=0.03)
    for y in (-0.45, 0.45):
        obj("post", bm_box(0.08, 0.08, 0.32), gold_dark(), loc=(-1.42, y, 0.78), parent=P, bevel=0.02)
    for x in (-0.95, 1.0):
        for y in (-0.62, 0.62):
            wheel_((x, y, 0.32), r=0.36, w=0.26, parent=P, rim=g, tread=False)
    for y in (-0.38, 0.38):
        obj("light", bm_box(0.06, 0.28, 0.1), glow("#fff6c8", 3.0), loc=(1.6, y, 0.45), parent=P, bevel=0.02, outline=False)


def gift(loc=(0, 0, 0), rot=(0, 0, 0), s=1.0, col="#ff4fa8"):
    P = _xf(loc, rot, s)
    c = candy(col)
    g = gold()
    obj("box", bm_box(1.6, 1.6, 1.2), c, loc=(0, 0, 0.6), parent=P, bevel=0.08)
    obj("lid", bm_box(1.75, 1.75, 0.36), candy("#ff7cc6"), loc=(0, 0, 1.3), parent=P, bevel=0.08)
    obj("rib1", bm_box(0.3, 1.78, 1.6), g, loc=(0, 0, 0.8), parent=P, bevel=0.02)
    obj("rib2", bm_box(1.78, 0.3, 1.6), g, loc=(0, 0, 0.8), parent=P, bevel=0.02)
    for sx in (-1, 1):
        t = torus(0.34, 0.12, g)
        t.matrix_world = P @ _xf((sx * 0.32, 0, 1.68), (90, 0, sx * 30)) @ t.matrix_world


def i_starter():
    gift(rot=(0, 0, 18))
    gem(BLUE_GEM, loc=(1.15, -0.85, 0.55), rot=(10, 0, -15), s=0.48)
    coin(loc=(-1.2, -0.9, 0.45), rot=(75, 0, 20), r=0.5)
    bills((-0.1, -1.25, 0.0), rot=(0, 0, 4), n=3, s=0.55)


def i_rushcrew():
    hh = hardhat((0, 0.2, 0), rot=(-8, 0, 28), col="#ffa91a", s=1.2)
    # a round blue badge with a lightning bolt: 2x speed
    # in front of the hat, up at its top right, turned to the camera (never hidden behind the brim)
    P = _xf((1.2, -1.35, 1.05), (-23, 0, 0), 0.8)
    obj("bb", bm_prism(circle(0.82, 64), 0.28, axis="Y"), candy("#2f8cff", rough=0.25), parent=P, bevel=0.06)
    b = poly(BOLT, 0.3, candy("#ffe14a", rough=0.25, emit=0.6), rot=(0, 0, 0), bevel=0.03)
    b.matrix_world = P @ _xf((0, -0.2, 0)) @ Matrix.Diagonal((0.62, 1, 0.62, 1))
    for k, (z, l) in enumerate(((1.1, 1.2), (0.65, 1.7), (0.2, 1.0))):
        box((l, 0.1, 0.13), candy("#ff8a26", emit=0.5), loc=(-1.6 - l * 0.2, 0.5, z), bevel=0.05)


def i_cashpack():
    money_bag()
    # the coins lean in front of the bag (clear of the cloth)
    coin(loc=(0.98, -1.28, 0.36), rot=(75, 0, -25), r=0.5)
    coin(loc=(-1.02, -1.12, 0.3), rot=(72, 0, 30), r=0.42)


def i_cashstack():
    bills((-0.55, 0.45, 0), rot=(0, 0, 10), n=12)
    bills((0.6, 0.35, 0), rot=(0, 0, -8), n=9)
    bills((0.0, -0.55, 0), rot=(0, 0, 4), n=6)


def vault(loc=(0, 0, 0), rot=(0, 0, 0), s=1.0):
    P = _xf(loc, rot, s)
    steel = pbr("vault", "#5f6f8f", metal=0.85, rough=0.3, coat=0.5, tex="brushed", axis="Z", dark="#4d5c7a", light="#7d8db0", emit=0.18)
    obj("vault", bm_box(2.2, 1.8, 2.2), steel, loc=(0, 0, 1.1), parent=P, bevel=0.14)
    g = gold()
    obj("door", bm_cyl(0.82, 0.2, 64, axis="Y"), pbr("door", "#8191b4", metal=0.9, rough=0.25, coat=0.5, emit=0.18), loc=(0, -0.92, 1.1), parent=P, smooth=40, bevel=0.04)
    t = torus(0.86, 0.07, g)
    t.matrix_world = P @ _xf((0, -0.98, 1.1), (90, 0, 0)) @ t.matrix_world
    t2 = torus(0.36, 0.06, g)
    t2.matrix_world = P @ _xf((0, -1.08, 1.1), (90, 0, 0)) @ t2.matrix_world
    for k in range(3):
        a = k * 60
        obj("spoke", bm_box(0.86, 0.06, 0.08), g, loc=(0, -1.08, 1.1), rot=(0, a, 0), parent=P, bevel=0.02)
    obj("knob", bm_cyl(0.12, 0.2, 24, axis="Y"), g, loc=(0, -1.12, 1.1), parent=P, smooth=40, bevel=0.02)
    for x in (-0.9, 0.9):
        for z in (0.25, 1.95):
            obj("bolt", bm_cyl(0.08, 0.06, 16, axis="Y"), chrome(), loc=(x, -0.92, z), parent=P, smooth=40, outline=False)


def i_cashvault():
    vault(rot=(0, 0, 14))
    for k, (x, z) in enumerate(((-1.25, 0.0), (1.2, 0.0))):
        coin(loc=(x, -1.15, 0.45), rot=(75, 0, 25 * (1 if x < 0 else -1)), r=0.45)
    bills((0.0, -1.35, 0.0), rot=(0, 0, 3), n=4, s=0.6)


def i_cashbank():
    """Cash Empire: a golden bank with columns, cash and coins piled at its steps"""
    g = gold()
    marble = pbr("bank_marble", "#f7f4ef", rough=0.08, coat=0.9, tex="marble", scale=1.2, emit=0.2)
    obj("steps1", bm_box(3.0, 1.6, 0.22), marble, loc=(0, 0, 0.11), bevel=0.04)
    obj("steps2", bm_box(2.7, 1.4, 0.22), marble, loc=(0, 0.05, 0.33), bevel=0.04)
    for k in range(4):
        x = -0.9 + k * 0.6
        cyl(0.18, 1.5, marble, loc=(x, -0.35, 1.19), segs=24, bevel=0.02)
        box((0.46, 0.46, 0.12), marble, loc=(x, -0.35, 0.5), bevel=0.02)
        box((0.46, 0.46, 0.12), marble, loc=(x, -0.35, 1.96), bevel=0.02)
    obj("wall", bm_box(2.5, 0.8, 1.6), candy("#e9e3d8", rough=0.4), loc=(0, 0.3, 1.2), bevel=0.04)
    obj("beam", bm_box(2.8, 1.3, 0.28), g, loc=(0, 0.05, 2.15), bevel=0.04)
    poly([(-1.45, 0), (1.45, 0), (0, 0.85)], 1.2, g, loc=(0, 0.1, 2.28))
    t = text("$", 0.55, 0.06, candy("#2e9e4a", rough=0.3), loc=(0, -0.55, 2.55))
    bills((-1.05, -1.05, 0.0), rot=(0, 0, 8), n=5, s=0.6)
    bills((1.05, -1.05, 0.0), rot=(0, 0, -8), n=7, s=0.6)
    coin(loc=(0, -1.3, 0.35), rot=(75, 0, 0), r=0.42)


def stopwatch(loc=(0, 0, 0), rot=(0, 0, 0), s=1.0):
    P = _xf(loc, rot, s)
    obj("case", bm_cyl(1.0, 0.36, 64, axis="Y"), chrome(), parent=P, smooth=40, bevel=0.08)
    obj("face", bm_cyl(0.84, 0.4, 64, axis="Y"), candy("#ffffff", rough=0.3), loc=(0, -0.01, 0), parent=P, smooth=40, bevel=0.02, outline=False)
    obj("crown", bm_cyl(0.16, 0.3, 24), chrome(), loc=(0, 0, 1.12), parent=P, smooth=40, bevel=0.03)
    obj("btn", bm_box(0.32, 0.28, 0.14), candy("#ff3b4a"), loc=(0, 0, 1.3), parent=P, bevel=0.04)
    for k in range(12):
        a = TAU * k / 12
        obj("tick", bm_box(0.05, 0.05, 0.14 if k % 3 else 0.22), candy("#2b2d38"), loc=(math.sin(a) * 0.68, -0.22, math.cos(a) * 0.68),
            rot=(0, math.degrees(a), 0), parent=P, bevel=0.0, outline=False)
    # 30 minutes: half the face lit
    bm = bm_prism([(0, 0)] + [(math.sin(TAU * k / 32 * 0.5 + math.pi) * 0.6, math.cos(TAU * k / 32 * 0.5 + math.pi) * 0.6) for k in range(33)], 0.02, axis="Y")
    obj("half", bm, candy("#5fd36f", rough=0.4, emit=0.3), loc=(0, -0.21, 0), parent=P, outline=False)
    obj("hand", bm_box(0.06, 0.05, 0.62), candy("#ff3b4a"), loc=(0, -0.24, 0.28), parent=P, bevel=0.0, outline=False)
    obj("pin", bm_cyl(0.08, 0.1, 16, axis="Y"), candy("#2b2d38"), loc=(0, -0.26, 0), parent=P, smooth=40, outline=False)


def i_cashboost():
    bills((-0.55, 0.5, -0.1), rot=(0, 0, 14), n=8)
    stopwatch((0.55, -0.55, 0.75), rot=(0, 0, -10), s=0.85)
    badge("2X", (-1.15, -1.1, -0.35), s=0.68, rot=(-30, 0, 0))


def spin_wheel(loc=(0, 0, 0), rot=(0, 0, 0), s=1.0):
    P = _xf(loc, rot, s)
    cols = ["#ff3b4a", "#ffc534", "#3fd36a", "#2f8cff", "#ff4fa8", "#ff8a26", "#45dcff", "#a25cff"]
    n = 8
    for i in range(n):
        a0, a1 = TAU * i / n, TAU * (i + 1) / n
        pts = [(0, 0)] + [(math.cos(a0 + (a1 - a0) * k / 10) * 1.2, math.sin(a0 + (a1 - a0) * k / 10) * 1.2) for k in range(11)]
        bm = bm_prism(pts, 0.26, axis="Y")
        obj("slice", bm, candy(cols[i], rough=0.22), parent=P, bevel=0.0, outline=False)
    g = gold()
    t = torus(1.25, 0.12, g)
    t.matrix_world = P @ _xf((0, 0, 0), (90, 0, 0)) @ t.matrix_world
    for k in range(16):
        a = TAU * k / 16
        sp = sphere(0.07, glow("#fff6c8", 2.5), outline=False)
        sp.matrix_world = P @ _xf((math.cos(a) * 1.25, -0.12, math.sin(a) * 1.25))
    obj("hub", bm_cyl(0.28, 0.4, 32, axis="Y"), g, parent=P, smooth=40, bevel=0.05)
    obj("hubstar", bm_prism(star_pts(0.2, 0.09), 0.44, axis="Y"), candy("#ffffff", emit=0.4), parent=P, bevel=0.0, outline=False)
    bm = bm_prism([(-0.28, 1.62), (0.28, 1.62), (0, 1.05)], 0.34, axis="Y")
    for v in bm.verts:
        v.co.z = -v.co.z
    obj("pointer", bm, candy("#ffffff", rough=0.2), loc=(0, -0.1, 0), parent=P, bevel=0.04)
    obj("stand", bm_box(0.5, 0.5, 1.0), gold_dark(), loc=(0, 0.3, -1.45), parent=P, bevel=0.06)
    obj("base", bm_box(1.5, 0.9, 0.25), gold_dark(), loc=(0, 0.3, -1.95), parent=P, bevel=0.06)


def i_spin1():
    spin_wheel(rot=(0, 0, 0))


def i_spins3():
    spin_wheel(rot=(0, 0, 0))
    badge("x5", (1.15, -0.6, -1.2), s=0.75, col="#a25cff")


def i_gems100():
    gem(BLUE_GEM, loc=(0, 0, 0.15), rot=(8, 0, 14), s=1.05)


def i_gems300():
    gem(BLUE_GEM, loc=(0, 0.3, 0.45), rot=(8, 0, 14), s=0.9)
    gem(PINK_GEM, loc=(-0.95, -0.2, -0.35), rot=(8, 0, -20), s=0.62)
    gem(GREEN_GEM, loc=(0.95, -0.25, -0.4), rot=(8, 0, 25), s=0.6)


def gem_pile(n, r, seed=3, base=0.0, sets=(BLUE_GEM, PINK_GEM, GREEN_GEM, PURPLE_GEM)):
    random.seed(seed)
    for k in range(n):
        a = random.uniform(0, TAU)
        d = r * math.sqrt(random.random())
        s = random.uniform(0.35, 0.55)
        z = base + (r - d) * 0.55 + s * 0.6
        gem(sets[k % len(sets)], loc=(math.cos(a) * d, math.sin(a) * d * 0.7, z), rot=(random.uniform(-30, 30), random.uniform(-30, 30), random.uniform(0, 360)), s=s)


def i_gems750():
    # a heap of gems on a little golden dish
    obj("dish", bm_cyl(1.5, 0.22, 64, r2=1.3), gold(), loc=(0, 0, 0.0), smooth=40, bevel=0.05)
    gem_pile(9, 1.1, seed=7, base=0.1)
    gem(BLUE_GEM, loc=(0, -0.1, 1.25), rot=(8, 0, 14), s=0.75)


def pouch(loc=(0, 0, 0), rot=(0, 0, 0), s=1.0, col="#8a3df0"):
    P = _xf(loc, rot, s)
    c = candy(col, rough=0.5, coat=0.3)
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=48, v_segments=24, radius=1.0)
    for v in bm.verts:
        z = v.co.z
        v.co.x *= 1.0 + 0.15 * max(0.0, -z)
        if z > 0.55:
            k = (z - 0.55) / 0.45
            v.co.x *= 1 - 0.45 * k
            v.co.y *= 1 - 0.45 * k
    obj("pouch", bm, c, loc=(0, 0, 0.9), parent=P, smooth=80)
    t = torus(0.5, 0.09, gold())
    t.matrix_world = P @ _xf((0, 0, 1.68)) @ t.matrix_world
    obj("emblem", bm_prism(circle(0.36, 48), 0.12, axis="Y"), gold(), loc=(0, -1.02, 0.85), parent=P, smooth=40, bevel=0.03)
    g = gem(PINK_GEM, rot=(90, 0, 0), s=0.24)
    g.matrix_world = P @ _xf((0, -1.12, 0.85)) @ g.matrix_world


def i_gems1700():
    pouch(loc=(0, 0.2, 0), rot=(0, 0, 10))
    # one big diamond standing up out of the opening, two smaller ones behind it on the sides (no gem touches another)
    gem(BLUE_GEM, loc=(0, 0.2, 2.12), rot=(10, 0, 14), s=0.62)
    gem(PINK_GEM, loc=(-0.62, 0.82, 1.86), rot=(10, -12, 20), s=0.36)
    gem(GREEN_GEM, loc=(0.64, 0.82, 1.84), rot=(10, 12, -20), s=0.34)
    gem(BLUE_GEM, loc=(1.15, -0.8, 0.45), rot=(8, 0, -20), s=0.5)
    gem(PURPLE_GEM, loc=(-1.15, -0.75, 0.4), rot=(8, 0, 20), s=0.45)


def chest(loc=(0, 0, 0), rot=(0, 0, 0), s=1.0, fill=None):
    P = _xf(loc, rot, s)
    wood = pbr("chest_wood", "#b8733a", rough=0.5, coat=0.4, tex="grain", dark="#9a5a2a", light="#c98546", emit=0.15)
    g = gold()
    obj("base", bm_box(2.4, 1.5, 1.2), wood, loc=(0, 0, 0.6), parent=P, bevel=0.08)
    for x in (-0.9, 0.9):
        obj("band", bm_box(0.22, 1.56, 1.24), g, loc=(x, 0, 0.6), parent=P, bevel=0.03)
    obj("rim", bm_box(2.46, 1.56, 0.18), g, loc=(0, 0, 1.18), parent=P, bevel=0.03)
    obj("lock", bm_box(0.38, 0.1, 0.46), g, loc=(0, -0.78, 0.95), parent=P, bevel=0.04)
    # open lid tilted back
    L = P @ _xf((0, 0.75, 1.25), (-100, 0, 0))
    bm = bm_cyl(0.75, 2.4, 48, axis="X")
    for v in bm.verts:
        if v.co.z < 0:
            v.co.z = 0
    obj("lid", bm, wood, loc=(0, -0.75, 0), parent=L, smooth=30, bevel=0.04)
    for x in (-0.9, 0.9):
        bm = bm_cyl(0.78, 0.24, 48, axis="X")
        for v in bm.verts:
            if v.co.z < 0:
                v.co.z = 0
        obj("lidband", bm, g, loc=(x, -0.75, 0), parent=L, smooth=30, bevel=0.02)
    if fill:
        fill(P)


def i_gems4500():
    def fill(P):
        random.seed(11)
        for k in range(10):
            x = random.uniform(-0.9, 0.9)
            y = random.uniform(-0.45, 0.35)
            sets = (BLUE_GEM, PINK_GEM, GREEN_GEM, PURPLE_GEM, RED_GEM)
            g = gem(sets[k % 5], rot=(random.uniform(-25, 25), random.uniform(-25, 25), random.uniform(0, 360)), s=random.uniform(0.32, 0.45))
            g.matrix_world = P @ _xf((x, y, 1.3 + random.uniform(0, 0.35))) @ g.matrix_world
    chest(rot=(0, 0, 14), fill=fill)


def i_gems12000():
    def fill(P):
        random.seed(5)
        sets = (BLUE_GEM, PINK_GEM, GREEN_GEM, PURPLE_GEM, RED_GEM)
        for k in range(16):
            x = random.uniform(-1.0, 1.0)
            y = random.uniform(-0.5, 0.4)
            g = gem(sets[k % 5], rot=(random.uniform(-30, 30), random.uniform(-30, 30), random.uniform(0, 360)), s=random.uniform(0.32, 0.5))
            g.matrix_world = P @ _xf((x, y, 1.35 + random.uniform(0, 0.6) + (0.4 - abs(x) * 0.35))) @ g.matrix_world
        big = gem(BLUE_GEM, rot=(10, 0, 10), s=0.75)
        big.matrix_world = P @ _xf((0, -0.1, 2.25)) @ big.matrix_world
    chest(rot=(0, 0, 14), fill=fill, s=1.0)
    # spilled in front
    for k, (x, cols) in enumerate(((-1.35, PINK_GEM), (1.3, GREEN_GEM), (0.6, PURPLE_GEM))):
        gem(cols, loc=(x, -1.15, 0.35), rot=(10, 0, 20 * k), s=0.4)
    coin(loc=(-0.5, -1.25, 0.32), rot=(75, 0, 20), r=0.4)


ICONS = {
    # game passes
    "skipanim": i_skipanim, "stormhammer": i_stormhammer, "teleporter": i_teleporter, "vip": i_vip, "bigcrew": i_bigcrew,
    "cash2x": i_cash2x, "strength2x": i_strength2x, "autobuild": i_autobuild, "autotrain": i_autotrain, "gems2x": i_gems2x,
    "fasttools": i_fasttools, "monster": i_monster, "goldcar": i_goldcar,
    # developer products
    "starter": i_starter, "rushcrew": i_rushcrew, "cashpack": i_cashpack, "cashstack": i_cashstack, "cashvault": i_cashvault,
    "cashbank": i_cashbank, "cashboost": i_cashboost, "spin1": i_spin1, "spins3": i_spins3, "gems100": i_gems100, "gems300": i_gems300,
    "gems750": i_gems750, "gems1700": i_gems1700, "gems4500": i_gems4500, "gems12000": i_gems12000,
}
VIEW = {"cashpack": (0, -1, 0.3), "cash2x": (-0.2, -1, 0.75), "cashstack": (-0.2, -1, 0.75), "cashboost": (-0.2, -1, 0.6), "stormhammer": (-0.18, -1, 0.22), "monster": (-0.3, -1, 0.3), "rushcrew": (-0.1, -1, 0.42), "bigcrew": (0, -1, 0.45), "fasttools": (-0.1, -1, 0.2), "goldcar": (-0.45, -1, 0.5), "teleporter": (0, -1, 0.35),
        "vip": (0, -1, 0.42), "gems750": (0, -1, 0.5), "spin1": (0, -1, 0.12), "spins3": (0, -1, 0.12), "skipanim": (-0.1, -1, 0.15)}
# card colours: (centre glow, edge)
CARD = {
    "skipanim": ("#6fc3ff", "#1b2f86"), "stormhammer": ("#8fd8ff", "#1a1f6e"), "teleporter": ("#7ff2ff", "#11406e"), "vip": ("#ffe27a", "#8a3a10"),
    "bigcrew": ("#ffd36b", "#a2470f"), "cash2x": ("#9cf29a", "#13643a"), "strength2x": ("#ffb08a", "#8a1f22"), "autobuild": ("#9fd3ff", "#1d3f8f"),
    "autotrain": ("#b6f59a", "#1d6a35"), "gems2x": ("#9fe8ff", "#1c3d9a"), "fasttools": ("#ffd98a", "#9a3a12"), "monster": ("#ff9aa2", "#7a1630"),
    "goldcar": ("#fff0a0", "#7a4a0c"), "starter": ("#ffb3e1", "#7a1f6a"), "rushcrew": ("#ffe08a", "#9a4a0f"), "cashpack": ("#a8f0a0", "#14603a"),
    "cashstack": ("#a8f0a0", "#14603a"), "cashvault": ("#c0f5b0", "#103f3a"), "cashbank": ("#fff1a6", "#6a3c0c"), "cashboost": ("#b8f5a8", "#145a40"),
    "spin1": ("#ffb0f0", "#5a1a8a"), "spins3": ("#e0b0ff", "#3a1a8a"), "gems100": ("#a8ecff", "#14408a"), "gems300": ("#b8e8ff", "#1c3a96"),
    "gems750": ("#b8e0ff", "#22348a"), "gems1700": ("#d8c0ff", "#3a1f8a"), "gems4500": ("#ffd8a0", "#5a2a7a"), "gems12000": ("#fff0b0", "#6a1f7a"),
}
SPARK = {"vip": [(0.84, 0.16, 0.07), (0.16, 0.3, 0.05)], "goldcar": [(0.84, 0.2, 0.07)], "gems100": [(0.82, 0.18, 0.08), (0.18, 0.7, 0.05)],
         "gems300": [(0.84, 0.16, 0.07)], "gems750": [(0.84, 0.16, 0.07), (0.16, 0.28, 0.05)], "gems1700": [(0.84, 0.16, 0.07)],
         "gems4500": [(0.86, 0.14, 0.07), (0.14, 0.3, 0.05)], "gems12000": [(0.86, 0.12, 0.08), (0.12, 0.26, 0.06), (0.6, 0.06, 0.04)],
         "cashbank": [(0.86, 0.14, 0.07)], "cashvault": [(0.84, 0.16, 0.06)], "starter": [(0.84, 0.16, 0.07)], "stormhammer": [(0.84, 0.16, 0.07)],
         "spin1": [(0.86, 0.14, 0.06)], "spins3": [(0.86, 0.14, 0.06)], "cash2x": [(0.16, 0.2, 0.06)], "gems2x": [(0.16, 0.2, 0.07)]}


# ------------------------------------------------------------------------------------------- 2D: the Creator Hub card
def _hex(h):
    h = h.lstrip("#")
    return np.array([int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)], np.float32)


def card(icon_canvas, key, size=512):
    """opaque square: radial glow, soft rays, a few sparkles, the icon (sticker look) in the middle 82 %"""
    c0, c1 = (_hex(c) for c in CARD.get(key, ("#b8c8ff", "#1c2a6a")))
    yy, xx = np.mgrid[0:size, 0:size].astype(np.float32)
    cx = cy = (size - 1) / 2
    d = np.sqrt((xx - cx) ** 2 + (yy - cy) ** 2) / (size * 0.62)
    t = np.clip(d, 0, 1) ** 1.15
    rgb = c0[None, None, :] * (1 - t[..., None]) + c1[None, None, :] * t[..., None]
    ang = np.arctan2(yy - cy, xx - cx)
    rays = (np.sin(ang * 12) > 0.35).astype(np.float32) * np.clip(1 - d, 0, 1) * 0.12
    rgb = np.clip(rgb + rays[..., None], 0, 1)
    out = np.concatenate([rgb, np.ones((size, size, 1), np.float32)], -1)
    # sparkles around
    for (sx, sy, r) in ((0.16, 0.18, 0.035), (0.86, 0.22, 0.03), (0.12, 0.8, 0.025), (0.88, 0.84, 0.035)):
        out = postnp.sparkle(out, sx * size, sy * size, r * size * 1.4, max(2.0, size * 0.006))
    n = int(size * 0.82)
    ic = postnp.resize(icon_canvas, n)
    o = (size - n) // 2
    out[o:o + n, o:o + n] = postnp.over(out[o:o + n, o:o + n], ic)
    out[..., 3] = 1
    return out


# ------------------------------------------------------------------------------------------- run
def render(names=None, size=768, samples=80):
    names = names or list(ICONS)
    for sub in ("raw", "game", "card"):
        os.makedirs(os.path.join(OUT, sub), exist_ok=True)
    done = []
    for n in names:
        I3.reset()
        T._M.clear()
        I.OUTLINE = 0.034
        ICONS[n]()
        I.add_outlines()
        scn = I3.iscene()
        scn.render.resolution_x = scn.render.resolution_y = size
        scn.cycles.samples = samples
        raw = os.path.join(OUT, "raw", n + ".png")
        I.frame_and_render(raw, view=VIEW.get(n, (-0.2, -1, 0.32)), margin=1.08)
        key = "robux_" + n
        postnp.SPARKLE[key] = SPARK.get(n, [])
        canvas = postnp.canvas_of(postnp.load(raw), key)
        postnp.save(postnp.resize(canvas, 256), os.path.join(OUT, "game", n + ".png"))
        postnp.save(card(canvas, n), os.path.join(OUT, "card", n + ".png"))
        done.append(n)
    I3.clear()
    return done
