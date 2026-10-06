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


def text(s, size, depth, mat, loc=(0, 0, 0), rot=(90, 0, 0), bevel=0.02, outline=True, center=False):
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
    if center and me.vertices:
        xs = [v.co.x for v in me.vertices]
        ys = [v.co.y for v in me.vertices]
        cx, cy = (min(xs) + max(xs)) / 2, (min(ys) + max(ys)) / 2
        for v in me.vertices:
            v.co.x -= cx
            v.co.y -= cy
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


def gem_at(cols, P, loc, s, rz=0.0, tilt=12.0):
    """an upright brilliant at loc (in the frame P), turned rz degrees, tipped tilt degrees towards the camera"""
    g = gem(cols, rot=(tilt, 0, rz), s=s)
    g.matrix_world = P @ _xf(loc) @ g.matrix_world
    return g


def touching(objs):
    """pairs of meshes that cut into each other (world space). Gems must sit side by side, never inside each other."""
    from mathutils.bvhtree import BVHTree
    bpy.context.view_layer.update()
    trees = []
    for o in objs:
        mw = o.matrix_world
        trees.append((o, BVHTree.FromPolygons([mw @ v.co for v in o.data.vertices], [p.vertices for p in o.data.polygons])))
    bad = []
    for i in range(len(trees)):
        for j in range(i + 1, len(trees)):
            if trees[i][1].overlap(trees[j][1]):
                bad.append((i, j))
    TOUCH_LOG.append(bad)
    if bad:
        print("GEMS TOUCHING:", bad, flush=True)
    return bad


TOUCH_LOG = []
GROUPS = []


def track(fn, *a, **k):
    """build one part (a coin, a stack of notes, a badge...) and remember its meshes for the clash check"""
    before = set(bpy.data.objects)
    r = fn(*a, **k)
    GROUPS.append([o for o in bpy.data.objects if o not in before and o.type == "MESH"])
    return r


def clashes():
    """pairs of tracked parts that cut into each other (world space, modifiers applied)"""
    from mathutils.bvhtree import BVHTree
    bpy.context.view_layer.update()
    dg = bpy.context.evaluated_depsgraph_get()
    trees = []
    for g in GROUPS:
        vs, fs = [], []
        for o in g:
            ev = o.evaluated_get(dg)
            me = ev.to_mesh()
            off = len(vs)
            vs += [o.matrix_world @ v.co for v in me.vertices]
            fs += [[off + i for i in p.vertices] for p in me.polygons]
            ev.to_mesh_clear()
        trees.append(BVHTree.FromPolygons(vs, fs) if fs else None)
    bad = [(i, j) for i in range(len(trees)) for j in range(i + 1, len(trees))
           if trees[i] and trees[j] and trees[i].overlap(trees[j])]
    GROUPS.clear()
    return bad


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


def bills(loc=(0, 0, 0), rot=(0, 0, 0), n=7, s=1.0, band="#f7d35a"):
    """a neat brick of green bank notes: a golden paper band round the middle, a printed $ medallion each side of it"""
    P = _xf(loc, rot, s)
    g1 = candy("#4fbf66", rough=0.5, coat=0.3)
    g2 = candy("#79d988", rough=0.5, coat=0.3)
    th = 0.065
    for i in range(n):
        dx = 0.022 * math.sin(i * 1.7)   # a tiny regular shift: the edges read as separate notes
        obj("bill", bm_box(1.9, 0.95, th), g1 if i % 2 else g2, loc=(dx, 0, th / 2 + i * th), parent=P, bevel=0.012,
            outline=i == n - 1)
    top = th * n
    obj("bill_border", bm_box(1.66, 0.74, 0.02), candy("#3fa856", rough=0.5, coat=0.3), loc=(0, 0, top + 0.008), parent=P, bevel=0.005,
        outline=False)
    obj("bill_face", bm_box(1.54, 0.62, 0.025), candy("#8fe39a", rough=0.5, coat=0.3), loc=(0, 0, top + 0.014), parent=P, bevel=0.005,
        outline=False)
    obj("band", bm_box(0.38, 0.99, top + 0.05), candy(band, rough=0.35, coat=0.5), loc=(0, 0, top / 2 + 0.01), parent=P, bevel=0.012)
    for x in (-0.56, 0.56):
        obj("seal", bm_cyl(0.23, 0.03, 40), candy("#2f9a4a", rough=0.4), loc=(x, 0, top + 0.03), parent=P, smooth=40, outline=False)
        t = text("$", 0.34, 0.012, candy("#e9fbe9", rough=0.4), rot=(0, 0, 0), bevel=0.006, outline=False, center=True)
        t.matrix_world = P @ Matrix.Translation((x, 0, top + 0.05)) @ t.matrix_world


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
    t = text("$", 1.25, 0.1, candy(sign, rough=0.3), rot=(90, 0, 0), center=True)
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
    size = 0.74 if len(label) <= 2 else 0.56
    t = text(label, size, 0.07, candy(txt, rough=0.3, emit=0.4), bevel=0.012, outline=False, center=True)
    t.matrix_world = P @ _xf((0, -0.25, 0), (90, 0, 0))
    sh = text(label, size, 0.07, candy("#1b1530", rough=0.6, coat=0.0, emit=0.0), bevel=0.012, outline=False, center=True)
    sh.matrix_world = P @ _xf((0.03, -0.19, -0.045), (90, 0, 0))


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
    """a big glossy play button with a skip-forward symbol, centred"""
    cyl(1.25, 0.4, candy("#2f8cff"), rot=(90, 0, 0), bevel=0.12, segs=72)
    cyl(1.05, 0.44, candy("#58b0ff", rough=0.18, emit=0.3), loc=(0, -0.03, 0), rot=(90, 0, 0), bevel=0.06, segs=72, outline=False)
    w = candy("#ffffff", rough=0.25, emit=0.5)
    dx = -0.06  # the whole symbol (two triangles + bar) spans -0.68 .. 0.68
    poly([(-0.62 + dx, 0.48), (0.02 + dx, 0.0), (-0.62 + dx, -0.48)], 0.3, w, loc=(0.0, -0.3, 0))
    poly([(-0.06 + dx, 0.48), (0.58 + dx, 0.0), (-0.06 + dx, -0.48)], 0.3, w, loc=(0.0, -0.3, 0))
    box((0.16, 0.3, 0.96), w, loc=(0.66 + dx, -0.3, 0), bevel=0.04)


def i_stormhammer():
    """the Thunderclap Hammer (from its spec, hammers/bl_build.py), centred, with a bolt in each free corner"""
    import bl_build as B
    spec = B.load_spec()
    h = [x for x in spec["hammers"] if x["key"] == "thunder"][0]
    B._M.clear()
    before = set(bpy.data.objects)
    B.build(h, spec["palette"])
    parts = [o for o in bpy.data.objects if o not in before]
    bpy.context.view_layer.update()
    pts = [o.matrix_world @ Vector(c) for o in parts if o.type == "MESH" for c in o.bound_box]
    cx = (min(p.x for p in pts) + max(p.x for p in pts)) / 2
    cz = (min(p.z for p in pts) + max(p.z for p in pts)) / 2
    move = Matrix.Translation((-cx, 0, -cz))
    for o in parts:
        if o.parent is None:
            o.matrix_world = move @ o.matrix_world
    # the head is top left and the handle runs to the bottom right: top right and bottom left are free
    poly(BOLT, 0.25, glow("#ffe14a", 3.5), loc=(1.35, 0.4, 1.1), rot=(0, 18, 0)).scale = (0.55, 0.55, 0.55)
    poly(BOLT, 0.25, glow("#7fd4ff", 3.5), loc=(-1.05, 0.4, -0.9), rot=(0, -20, 0)).scale = (0.5, 0.5, 0.5)


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


def crown_ring(r_out, r_in, h0, amp, n_pts=5, power=2.2, segs=240):
    """the crown band: a ring whose top edge rises into n soft rounded points (one straight at the front)"""
    bm = bmesh.new()
    ob_, ot_, it_, ib_ = [], [], [], []
    for k in range(segs):
        a = TAU * k / segs - math.pi / 2
        h = h0 + amp * (0.5 + 0.5 * math.cos(n_pts * (a + math.pi / 2))) ** power
        c, sn = math.cos(a), math.sin(a)
        ob_.append(bm.verts.new((c * r_out, sn * r_out, 0)))
        ot_.append(bm.verts.new((c * r_out, sn * r_out, h)))
        it_.append(bm.verts.new((c * r_in, sn * r_in, h)))
        ib_.append(bm.verts.new((c * r_in, sn * r_in, 0)))
    for k in range(segs):
        k2 = (k + 1) % segs
        bm.faces.new((ob_[k], ob_[k2], ot_[k2], ot_[k]))
        bm.faces.new((ot_[k], ot_[k2], it_[k2], it_[k]))
        bm.faces.new((it_[k], it_[k2], ib_[k2], ib_[k]))
        bm.faces.new((ib_[k], ib_[k2], ob_[k2], ob_[k]))
    return bm


def i_vip():
    """a rounded gold crown: five soft points with pearls, a velvet cap, three jewels set in the band"""
    g = gold()
    H0, AMP = 0.62, 0.7
    obj("crown", crown_ring(1.15, 1.0, H0, AMP), g, loc=(0, 0, 0.12), smooth=40, bevel=0.035, segs=3)
    obj("rim_low", bm_prism(circle(1.21, 96), 0.16, holes=circle(1.0, 96)), gold_dark(), loc=(0, 0, 0.1), smooth=40, bevel=0.04)
    vel = pbr("crown_velvet", "#b3163a", rough=0.7, coat=0.1, tex="leaf", scale=26.0, bump=0.1, dark="#a3122e", light="#c41d44", emit=0.12)
    sphere(1.0, vel, loc=(0, 0, 0.62), scale=(0.98, 0.98, 0.6), outline=False)
    sphere(0.16, g, loc=(0, 0, 1.3))
    pearl = candy("#fff6e0", rough=0.12, emit=0.35)
    for k in range(5):
        a = TAU * k / 5 - math.pi / 2
        sphere(0.15, pearl, loc=(math.cos(a) * 1.075, math.sin(a) * 1.075, 0.12 + H0 + AMP + 0.08))
    for k, cols in enumerate((RED_GEM, BLUE_GEM, RED_GEM)):
        a = -math.pi / 2 + (k - 1) * 0.62
        rot = (90, 0, math.degrees(a) + 90)
        gem(cols, loc=(math.cos(a) * 1.2, math.sin(a) * 1.2, 0.44), rot=rot, s=0.22)
        t = torus(0.25, 0.045, g, outline=False)
        t.matrix_world = _xf((math.cos(a) * 1.17, math.sin(a) * 1.17, 0.44), rot)


def i_bigcrew():
    track(hardhat, (-1.05, 1.25, 1.1), rot=(-25, 0, 0), col="#ff8a26", s=0.72)
    track(hardhat, (1.05, 1.25, 1.1), rot=(-25, 0, 0), col="#3d8cff", s=0.72)
    track(hardhat, (0, -0.4, 0.0), rot=(-22, 0, 0), col="#ffc534", s=1.0)
    track(badge, "+3", (1.35, -1.4, 1.2), s=0.8, col="#3fd36a", rot=(-24, 0, 0))


def i_cash2x():
    # one brick of notes on top of another, a coin beside them
    track(bills, (0.0, 0.25, 0), rot=(0, 0, 8), n=8)
    track(bills, (0.12, 0.08, 0.62), rot=(0, 0, -10), n=5, s=0.95)
    track(coin, loc=(-1.45, -0.85, 0.42), rot=(72, 0, 25), r=0.55)
    track(badge, "2x", (1.2, -1.1, 1.15), s=0.8, rot=(-36, 0, 0))


def dumbbell(loc, rot=(0, 0, 0), plate="#ff3b4a", s=1.0):
    P = _xf(loc, rot, s)
    obj("bar", bm_cyl(0.13, 2.5, 32, axis="X"), chrome(), parent=P, smooth=40, bevel=0.02)
    for sx in (-1, 1):
        obj("plate", bm_cyl(0.68, 0.32, 48, axis="X"), candy(plate), loc=(sx * 0.82, 0, 0), parent=P, smooth=40, bevel=0.07)
        obj("plate2", bm_cyl(0.52, 0.22, 48, axis="X"), candy(plate), loc=(sx * 1.08, 0, 0), parent=P, smooth=40, bevel=0.06)
        obj("collar", bm_cyl(0.2, 0.12, 32, axis="X"), chrome(), loc=(sx * 1.24, 0, 0), parent=P, smooth=40, bevel=0.02)


def i_strength2x():
    track(dumbbell, (0, 0, 0.3), rot=(0, -25, -15), plate="#ff6a2b")
    # the badge in the free bottom right corner, clear of the plates
    track(badge, "2x", (1.3, -0.9, -0.85), s=0.78, rot=(-16, 0, 0))


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
    hm.matrix_world = P @ _xf((1.15, -0.55, 1.15), (0, 25, 0))
    for x in (-0.38, 0.38):
        obj("leg", bm_box(0.36, 0.4, 0.35), trim, loc=(x, 0, 0.0), parent=P, bevel=0.08)


def i_autobuild():
    track(robot, rot=(0, 0, -12))
    track(badge, "AUTO", (-1.2, -0.95, 0.45), s=0.62, col="#3fd36a", rot=(-16, 0, 0))


def i_autotrain():
    # the dumbbell sits exactly in the middle of the circle of arrows (same centre point)
    dumbbell((0, -0.2, 0.1), rot=(0, -20, -10), plate="#ff8a26", s=0.85)
    arrow_loop((0, -0.2, 0.1), R=1.55, col="#3fd36a")


def i_gems2x():
    track(gem, BLUE_GEM, loc=(-0.35, 0.3, 0.2), rot=(10, 0, 12), s=1.0)
    track(gem, PINK_GEM, loc=(0.95, -0.75, -0.35), rot=(10, 0, -18), s=0.62)
    track(badge, "2x", (1.15, -1.0, 1.0), s=0.72, rot=(-16, 0, 0))


def i_fasttools():
    hm = I.hammer(s=1.7)
    repaint(hm)
    for ob in hm.children_recursive:
        if ob.type == "MESH" and ob.data.materials and "9aa3b8" in ob.data.materials[0].name:
            ob.data.materials[0] = gold()
    hm.matrix_world = _xf((0.55, 0, 0), (0, -40, 0))
    # the speed lines trail behind the head with a clear gap (measured from the hammer itself)
    bpy.context.view_layer.update()
    corners = [o.matrix_world @ Vector(c) for o in hm.children_recursive if o.type == "MESH" for c in o.bound_box]
    left = min(p.x for p in corners)
    head = [p for p in corners if p.x < left + 0.6]
    zmid = (min(p.z for p in head) + max(p.z for p in head)) / 2
    for dz, l, c, gap in ((0.42, 1.1, "#ffc534", 0.3), (0.0, 1.5, "#ff8a26", 0.22), (-0.42, 0.95, "#ffc534", 0.34)):
        box((l, 0.12, 0.16), candy(c, emit=0.5), loc=(left - gap - l / 2, 0.35, zmid + dz), bevel=0.06)
    poly(BOLT, 0.25, glow("#ffe14a", 2.5), loc=(1.6, -0.5, -0.9), rot=(0, 15, 0)).scale = (0.7, 0.7, 0.7)


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
    track(gift, rot=(0, 0, 18))
    track(gem, BLUE_GEM, loc=(1.6, -1.0, 0.5), rot=(10, 0, -15), s=0.48)
    track(coin, loc=(-1.35, -1.05, 0.45), rot=(75, 0, 20), r=0.5)
    track(bills, (0.25, -1.38, 0.0), rot=(0, 0, 18), n=3, s=0.55)


def i_rushcrew():
    hh = track(hardhat, (0, 0.2, 0), rot=(-8, 0, 28), col="#ffa91a", s=1.2)
    # a round blue badge with a lightning bolt (2x speed): bottom right, in front of the whole hat so the brim never
    # goes through it (placed from the hat's measured size)
    bpy.context.view_layer.update()
    pts = [o.matrix_world @ Vector(c) for o in GROUPS[-1] for c in o.bound_box]
    xmax, ymin = max(p.x for p in pts), min(p.y for p in pts)
    P = _xf((xmax - 0.2, ymin - 0.35, 0.4), (-23, 0, 0), 0.8)
    def badge_():
        obj("bb", bm_prism(circle(0.82, 64), 0.28, axis="Y"), candy("#2f8cff", rough=0.25), parent=P, bevel=0.06)
        b = poly(BOLT, 0.3, candy("#ffe14a", rough=0.25, emit=0.6), rot=(0, 0, 0), bevel=0.03)
        b.matrix_world = P @ _xf((0, -0.2, 0)) @ Matrix.Diagonal((0.62, 1, 0.62, 1))
    track(badge_)
    for k, (z, l) in enumerate(((1.1, 1.2), (0.65, 1.7), (0.2, 1.0))):
        box((l, 0.1, 0.13), candy("#ff8a26", emit=0.5), loc=(-1.6 - l * 0.2, 0.5, z), bevel=0.05)


def i_cashpack():
    money_bag()
    # the coins lean in front of the bag (clear of the cloth)
    coin(loc=(0.98, -1.28, 0.36), rot=(75, 0, -25), r=0.5)
    coin(loc=(-1.02, -1.12, 0.3), rot=(72, 0, 30), r=0.42)


def i_cashstack():
    # two bricks side by side, one across them on top, one in front
    track(bills, (-1.0, 0.25, 0), n=8)
    track(bills, (1.0, 0.25, 0), n=8)
    track(bills, (0.0, 0.25, 0.62), rot=(0, 0, 6), n=6)
    track(bills, (0.05, -0.95, 0), rot=(0, 0, -4), n=4)


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
    track(vault, rot=(0, 0, 14))
    track(coin, loc=(-1.55, -1.35, 0.45), rot=(75, 0, 25), r=0.45)
    track(coin, loc=(1.75, -1.05, 0.45), rot=(75, 0, -25), r=0.45)
    track(bills, (0.05, -1.55, 0.0), rot=(0, 0, 14), n=4, s=0.6)


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
    t = text("$", 0.55, 0.06, candy("#2e9e4a", rough=0.3), loc=(0, -0.55, 2.55), center=True)
    GROUPS.append([o for o in I3.iscene().objects if o.type == "MESH"])  # the whole bank is one part
    # the cash sits in front of the steps, not under them
    track(bills, (-1.12, -1.25, 0.0), rot=(0, 0, 8), n=5, s=0.6)
    track(bills, (1.12, -1.25, 0.0), rot=(0, 0, -8), n=7, s=0.6)
    track(coin, loc=(0, -1.35, 0.35), rot=(75, 0, 0), r=0.42)


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
    badge("2x", (-1.15, -1.1, -0.35), s=0.68, rot=(-30, 0, 0))


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
    badge("5x", (1.15, -0.75, -1.2), s=0.78, col="#ff3fa8")


def i_gems100():
    gem(BLUE_GEM, loc=(0, 0, 0.15), rot=(8, 0, 14), s=1.05)


def i_gems300():
    gem(BLUE_GEM, loc=(0, 0.3, 0.45), rot=(8, 0, 14), s=0.9)
    gem(PINK_GEM, loc=(-0.95, -0.2, -0.35), rot=(8, 0, -20), s=0.62)
    gem(GREEN_GEM, loc=(0.95, -0.25, -0.4), rot=(8, 0, 25), s=0.6)


def settle(dynamic, passive, frames=160):
    """drop the dynamic objects onto the passive ones (Bullet rigid bodies) and keep them where they come to rest"""
    scn = bpy.context.scene
    def ov(ob=None):
        if ob is None:
            return bpy.context.temp_override(scene=scn)
        return bpy.context.temp_override(scene=scn, object=ob, active_object=ob, selected_objects=[ob], selected_editable_objects=[ob])
    if scn.rigidbody_world is None:
        with ov():
            bpy.ops.rigidbody.world_add()
    rw = scn.rigidbody_world
    rw.enabled = True
    rw.substeps_per_frame = 20
    rw.solver_iterations = 30
    rw.point_cache.frame_start = 1
    rw.point_cache.frame_end = frames
    for ob, kind in [(o, "ACTIVE") for o in dynamic] + [(o, "PASSIVE") for o in passive]:
        with ov(ob):
            bpy.ops.rigidbody.object_add(type=kind)
        rb = ob.rigid_body
        rb.collision_shape = "CONVEX_HULL" if kind == "ACTIVE" else "MESH"
        if kind == "PASSIVE":
            rb.mesh_source = "FINAL"
        rb.friction = 1.0
        rb.restitution = 0.0
        rb.linear_damping = 0.5
        rb.angular_damping = 0.9
        rb.use_margin = True
        rb.collision_margin = 0.004
    for f in range(1, frames + 1):
        scn.frame_set(f)
    dg = bpy.context.evaluated_depsgraph_get()
    final = [o.evaluated_get(dg).matrix_world.copy() for o in dynamic]
    for ob in dynamic + passive:
        with ov(ob):
            bpy.ops.rigidbody.object_remove()
    with ov():
        bpy.ops.rigidbody.world_remove()
    scn.frame_set(1)
    for o, m in zip(dynamic, final):
        o.matrix_world = m


def drop_gems(P, n, seed, area, z0, sizes=(0.3, 0.4), sets=(BLUE_GEM, PINK_GEM, GREEN_GEM, PURPLE_GEM, RED_GEM), per=2, gap=0.92):
    """n gems at random turns, dropped in layers of `per` over area (x0, x1, y0, y1) in the frame P.
    Gems of one layer are ~0.9 apart and layers 0.92 apart, so none starts inside another."""
    rnd = random.Random(seed)
    gs = []
    x0, x1, y0, y1 = area
    for k in range(n):
        layer, i = divmod(k, per)
        fx = (i + 0.5) / per if per > 1 else 0.5
        if layer % 2:
            fx = 1 - fx
        x = x0 + (x1 - x0) * fx + rnd.uniform(-0.08, 0.08)
        y = rnd.uniform(y0, y1)
        s_ = rnd.uniform(*sizes)
        g = gem(sets[k % len(sets)], rot=(rnd.uniform(0, 360), rnd.uniform(0, 360), rnd.uniform(0, 360)), s=s_)
        g.matrix_world = P @ _xf((x, y, z0 + layer * gap)) @ g.matrix_world
        gs.append(g)
    return gs


def keep_inside(gs, P, test):
    """delete the gems that came to rest outside the place they belong (test gets the position in frame P)"""
    inv = P.inverted()
    kept = []
    for g in gs:
        p = inv @ g.matrix_world.translation
        if test(p):
            kept.append(g)
        else:
            bpy.data.objects.remove(g, do_unlink=True)
    return kept


def ground(z=0.0, size=20.0):
    """an invisible floor for the physics (removed again afterwards)"""
    return obj("ground", bm_box(size, size, 0.2), candy("#000000"), loc=(0, 0, z - 0.1), outline=False)


def cushion(loc=(0, 0, 0), size=(3.0, 2.2, 0.55), col="#c8203c"):
    """a puffy red velvet jewellery cushion with a gold cord round its middle"""
    vel = pbr("velvet" + col, col, rough=0.75, coat=0.05, tex="leaf", scale=30.0, bump=0.12, dark="#b51c36", light="#d42a46", emit=0.12)
    o = obj("cushion", bm_box(*size), vel, loc=loc, smooth=85, bevel=0.24, segs=3)
    m = o.modifiers.new("soft", "SUBSURF")
    m.levels = m.render_levels = 2
    cush = o
    # the cord: a rounded rectangle tube just outside the cushion's widest line
    w, d, r = size[0] / 2 - 0.08, size[1] / 2 - 0.08, 0.3
    path = []
    for (cx, cy, a0) in ((w - r, d - r, 0), (-w + r, d - r, 90), (-w + r, -d + r, 180), (w - r, -d + r, 270)):
        for k in range(9):
            aa = math.radians(a0 + 90 * k / 8)
            path.append((loc[0] + cx + math.cos(aa) * r, loc[1] + cy + math.sin(aa) * r, loc[2]))
    bm = bmesh.new()
    rings = []
    n = len(path)
    for i in range(n):
        p = Vector(path[i])
        t = (Vector(path[(i + 1) % n]) - Vector(path[i - 1])).normalized()
        nn = t.cross(Vector((0, 0, 1))).normalized()
        rings.append([bm.verts.new(p + (nn * math.cos(TAU * j / 10) + Vector((0, 0, 1)) * math.sin(TAU * j / 10)) * 0.05) for j in range(10)])
    for i in range(n):
        a_, b_ = rings[i], rings[(i + 1) % n]
        for j in range(10):
            bm.faces.new((a_[j], a_[(j + 1) % 10], b_[(j + 1) % 10], b_[j]))
    obj("cord", bm, gold(), smooth=80, outline=False)
    return cush


def i_gems750():
    # a heap of gems dropped onto a red velvet cushion
    c = cushion(loc=(0, 0.2, 0.0))
    floor_ = ground(-0.32)
    P = Matrix.Identity(4)
    gs = drop_gems(P, 12, 7, (-0.9, 0.9, 0.0, 0.4), 0.8, sizes=(0.32, 0.42))
    settle(gs, [c, floor_])
    bpy.data.objects.remove(floor_, do_unlink=True)
    gs = keep_inside(gs, P, lambda p: abs(p.x) < 1.45 and -0.85 < p.y < 1.25 and p.z > 0.15)
    touching(gs)


def velvet_mound(P, z=1.2, sx=1.12, sy=0.66, h=0.28):
    vel = pbr("chest_velvet", "#7a1f9a", rough=0.75, coat=0.05, tex="leaf", scale=30.0, bump=0.12, dark="#6a1888", light="#8a2aa8", emit=0.12)
    o = sphere(1.0, vel, outline=False)
    o.matrix_world = P @ _xf((0, 0, z), (0, 0, 0), (sx, sy, h))
    return o


def chest_gems(P, hero=None):
    """a chest full to the brim: 3 gems along the front, 2 behind them and higher, an optional big one on top"""
    gs = [gem_at(PINK_GEM, P, (-0.78, -0.33, 1.4), 0.38, 16), gem_at(BLUE_GEM, P, (0, -0.33, 1.42), 0.38, -10),
          gem_at(GREEN_GEM, P, (0.78, -0.33, 1.4), 0.38, 20),
          gem_at(PURPLE_GEM, P, (-0.46, 0.36, 1.78), 0.42, -12), gem_at(RED_GEM, P, (0.46, 0.36, 1.78), 0.42, 14)]
    if hero:
        gs.append(gem_at(BLUE_GEM, P, (0, 0.3, 2.5), hero, 10))
    return gs


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


def chest_heap(n, seed, spill=0):
    """an open chest heaped with gems that were dropped in and came to rest (plus some spilled on the floor in front)"""
    P = _xf((0, 0, 0), (0, 0, 14))
    before = set(bpy.data.objects)
    chest(rot=(0, 0, 14))
    walls = [o for o in bpy.data.objects if o not in before and o.type == "MESH"]
    bed = velvet_mound(P)
    gs = drop_gems(P, n, seed, (-0.9, 0.9, -0.25, 0.25), 1.75)
    floor_ = ground(0.0)
    # invisible guard rails a little above the rim keep the heap in the chest (removed after the drop)
    rails = []
    for size, loc in (((0.1, 1.5, 0.5), (1.2, 0, 1.5)), ((0.1, 1.5, 0.5), (-1.2, 0, 1.5)), ((2.5, 0.1, 0.5), (0, -0.76, 1.5)),
                      ((2.5, 0.1, 0.5), (0, 0.76, 1.5))):
        r = obj("rail", bm_box(*size), candy("#000000"), loc=loc, outline=False)
        r.matrix_world = P @ r.matrix_world
        rails.append(r)
    if spill:
        gs += drop_gems(P, spill, seed + 1, (-1.6, 1.6, -1.5, -1.25), 0.7, sizes=(0.34, 0.42), per=3)
    settle(gs, walls + rails + [bed, floor_])
    for o in rails + [floor_]:
        bpy.data.objects.remove(o, do_unlink=True)
    in_chest = lambda p: abs(p.x) < 1.15 and abs(p.y) < 0.72 and p.z > 1.15
    on_floor = lambda p: abs(p.x) < 1.9 and -1.95 < p.y < -0.8 and p.z < 0.7
    gs = keep_inside(gs, P, (lambda p: in_chest(p) or on_floor(p)) if spill else in_chest)
    touching(gs)
    return gs


def i_gems4500():
    chest_heap(14, 21)


def i_gems12000():
    # the biggest pack: a fuller heap and gems spilled on the floor in front
    chest_heap(20, 33, spill=6)


# ------------------------------------------------------------------------------------------- hammer crates
# loot chests: a chunky rounded chest with metal straps, the lid thrown open, a real hammer (from the hammer spec)
# bursting out of a glowing opening; the light rays and the bloom are painted in 2D afterwards (crate_post), so they
# glow softly behind the chest without a sticker outline. One look per crate.
CRATE_LOOK = {
    "supply": dict(body=("#c98546", "grain", "#a8672f", "#dc9a58"), lid="#b0703a", trim=("#6b7388", 0.9), inner="#4a2c18",
                   glow="#ffc93a", ray="#ffb21f", gem=None, hammer="steel", pose=(0.0, -16.0, 18.0)),
    "builder": dict(body=("#3f8cff", None, None, None), lid="#2a62d8", trim=("#ffc534", 1.0), inner="#163a8a",
                    glow="#8fd8ff", ray="#3fb8ff", gem=None, hammer="gold", pose=(0.0, -16.0, 18.0)),
    "golden": dict(body=("#ffc534", "hammered", "#f2ae22", "#ffd86a"), lid="#e39a1a", trim=("#fff1c0", 1.0), inner="#8a4a10",
                   glow="#ffe680", ray="#ffcf2e", gem=None, hammer="diamond", pose=(0.0, -16.0, 18.0)),
    "exclusive": dict(body=("#ff4fc8", None, None, None), lid="#d42c9e", trim=("#8a4df8", 0.6), inner="#4a1070",
                      glow="#ff9cf0", ray="#d65cff", gem="pink", hammer="plasma", pose=(0.0, -16.0, 18.0)),
}
CRATE_O = []      # world points of the glowing openings (for the 2D rays)
_SPEC = None


def _chest_mats(kind):
    L = CRATE_LOOK[kind]
    col, tex, dark, light = L["body"]
    if tex == "grain":
        body = pbr("lc_body_" + kind, col, rough=0.5, coat=0.4, tex="grain", dark=dark, light=light, emit=0.15)
    elif tex == "hammered":
        body = pbr("lc_body_" + kind, col, metal=1.0, rough=0.14, coat=0.45, tex="hammered", scale=3.0, bump=0.04, dark=dark, light=light, emit=0.32)
    else:
        body = candy(col, rough=0.25)
    lid = (pbr("lc_lid_" + kind, L["lid"], metal=1.0, rough=0.22, coat=0.3, emit=0.25) if kind == "golden"
           else (pbr("lc_lid_" + kind, L["lid"], rough=0.55, coat=0.3, tex="grain", dark="#8a5224", light="#b8773a", emit=0.08) if kind == "supply"
                 else candy(L["lid"], emit=0.08)))
    tc, tm = L["trim"]
    trim = pbr("lc_trim_" + kind, tc, metal=tm, rough=0.22 if tm > 0.8 else 0.3, coat=0.5, emit=0.22)
    inner = candy(L["inner"], rough=0.6, coat=0.1, emit=0.05)
    return body, lid, trim, inner, L


def burst_hammer(P, key, H, pose, height=3.0):
    """the hammer `key` (hammers/spec.json) standing up out of the chest: handle in the light, head high above the lid"""
    global _SPEC
    import bl_build as B
    if _SPEC is None:
        _SPEC = B.load_spec()
    h = [x for x in _SPEC["hammers"] if x["key"] == key][0]
    B._M.clear()
    before = set(bpy.data.objects)
    B.build(h, _SPEC["palette"], pose=pose)
    parts = [o for o in bpy.data.objects if o not in before]
    bpy.context.view_layer.update()
    pts = [o.matrix_world @ Vector(c) for o in parts if o.type == "MESH" for c in o.bound_box]
    lo = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
    hi = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
    k = height / max(hi.z - lo.z, 1e-6)
    # bottom of the handle sinks 0.45 into the light, centred over the opening
    move = P @ Matrix.Translation((0.05, -0.05, H - 0.45)) @ Matrix.Scale(k, 4) @ Matrix.Translation((-(lo.x + hi.x) / 2, -(lo.y + hi.y) / 2, -lo.z))
    for o in parts:
        if o.parent is None:
            o.matrix_world = move @ o.matrix_world
    return parts


def loot_chest(loc=(0, 0, 0), rot=(0, 0, 0), s=1.0, kind="supply", open_=True, mark=True):
    P = _xf(loc, rot, s)
    body, lidm, trim, inner, L = _chest_mats(kind)
    W, D, H = 2.6, 1.7, 1.35
    t = 0.26
    obj("chest", bm_box(W, D, H), body, loc=(0, 0, H / 2), parent=P, bevel=0.12)
    # the dark inside (seen through the opening), the glow sits on top of it
    obj("inside", bm_box(W - 0.3, D - 0.3, 0.3), inner, loc=(0, 0, H - 0.2), parent=P, bevel=0.03, outline=False)
    # straps and rims
    for x in (-0.86, 0.86):
        obj("strap", bm_box(t, D + 0.06, H + 0.04), trim, loc=(x, 0, H / 2), parent=P, bevel=0.05)
    for z in (0.12, H - 0.12):
        obj("rim", bm_box(W + 0.06, D + 0.06, 0.22), trim, loc=(0, 0, z), parent=P, bevel=0.05)
    # the lock plate on the front: a keyhole, or a gem on the exclusive crate
    obj("plate", bm_box(0.56, 0.1, 0.5), trim, loc=(0, -D / 2 - 0.04, H * 0.5), parent=P, bevel=0.05)
    if L["gem"]:
        g = gem(PINK_GEM, s=0.3)
        g.matrix_world = P @ _xf((0, -D / 2 - 0.12, H * 0.5), (90, 0, 0))
    else:
        obj("keyhole", bm_cyl(0.07, 0.12, 20, axis="Y"), inner, loc=(0, -D / 2 - 0.1, H * 0.5 + 0.06), parent=P, smooth=40, outline=False)
        obj("keyslot", bm_box(0.07, 0.12, 0.16), inner, loc=(0, -D / 2 - 0.1, H * 0.5 - 0.06), parent=P, bevel=0.0, outline=False)
    # the lid: a half cylinder on a hinge at the back top edge, thrown open (or shut)
    ang = -112 if open_ else -3
    Lf = P @ _xf((0, D / 2, H), (ang, 0, 0))
    bm = bm_cyl(D / 2, W, 48, axis="X")
    for v in bm.verts:
        if v.co.z < 0:
            v.co.z = 0
    obj("lid", bm, lidm, loc=(0, -D / 2, 0), parent=Lf, smooth=30, bevel=0.04)
    for x in (-0.86, 0.86):
        bm = bm_cyl(D / 2 + 0.03, t, 48, axis="X")
        for v in bm.verts:
            if v.co.z < 0:
                v.co.z = 0
        obj("lidband", bm, trim, loc=(x, -D / 2, 0), parent=Lf, smooth=30, bevel=0.02)
    obj("lidrim", bm_box(W + 0.06, 0.22, 0.16), trim, loc=(0, -D + 0.05, 0.02), parent=Lf, bevel=0.04)
    if open_:
        # the opening glows in the crate's colour (bright, not blown out); the rays come in 2D (crate_post)
        obj("light", bm_box(W - 0.34, D - 0.34, 0.26), glow(L["glow"], 4.0), loc=(0, 0, H - 0.02), parent=P, bevel=0.06, outline=False)
        CRATE_O.append(P @ Vector((0, 0, H + 0.15)))
        if mark and L.get("hammer"):
            burst_hammer(P, L["hammer"], H, L["pose"])
        # a few sparkles in the air
        for (x, z, r) in ((-1.75, 2.5, 0.2), (1.85, 2.2, 0.17), (-1.25, 3.7, 0.13), (1.5, 3.6, 0.15)):
            st = poly(star_pts(r, r * 0.34, 4, 90), 0.05, glow("#ffffff", 4.5), bevel=0.0, outline=False)
            st.matrix_world = P @ _xf((x, -0.3, z), (0, 0, 0))
    return P


def i_crate_supply():
    track(loot_chest, rot=(0, 0, 22), kind="supply")


def i_crate_builder():
    track(loot_chest, rot=(0, 0, 22), kind="builder")


def i_crate_golden():
    track(loot_chest, rot=(0, 0, 22), kind="golden")
    track(coin, loc=(-0.78, -0.25, 1.42), rot=(62, 0, 24), r=0.38)
    track(coin, loc=(0.82, -0.15, 1.38), rot=(70, 0, -30), r=0.34)
    track(coin, loc=(2.0, -1.15, 0.42), rot=(75, 0, -25), r=0.42)
    track(coin, loc=(-2.05, -0.95, 0.42), rot=(75, 0, 25), r=0.42)


def i_crate_exclusive():
    track(loot_chest, rot=(0, 0, 22), kind="exclusive")
    track(gem, PURPLE_GEM, loc=(-0.8, -0.2, 1.5), rot=(12, 0, 25), s=0.34)
    track(gem, PINK_GEM, loc=(0.85, -0.15, 1.46), rot=(12, 0, -20), s=0.32)
    track(gem, BLUE_GEM, loc=(2.0, -1.15, 0.45), rot=(8, 0, -20), s=0.42)
    track(gem, PINK_GEM, loc=(-2.05, -0.95, 0.42), rot=(8, 0, 20), s=0.38)


def _three(kind):
    # three chests: two shut at the back, the front one open with the light and its hammer
    track(loot_chest, loc=(-1.6, 1.3, 0), rot=(0, 0, 12), s=0.74, kind=kind, open_=False)
    track(loot_chest, loc=(1.7, 1.3, 0), rot=(0, 0, 32), s=0.74, kind=kind, open_=False)
    track(loot_chest, loc=(0.0, -0.9, 0), rot=(0, 0, 22), s=0.8, kind=kind)


def i_crate_golden3():
    _three("golden")


def i_crate_exclusive3():
    _three("exclusive")


ICONS = {
    # game passes
    "skipanim": i_skipanim, "stormhammer": i_stormhammer, "teleporter": i_teleporter, "vip": i_vip, "bigcrew": i_bigcrew,
    "cash2x": i_cash2x, "strength2x": i_strength2x, "autobuild": i_autobuild, "autotrain": i_autotrain, "gems2x": i_gems2x,
    "fasttools": i_fasttools, "monster": i_monster, "goldcar": i_goldcar,
    # developer products
    "starter": i_starter, "rushcrew": i_rushcrew, "cashpack": i_cashpack, "cashstack": i_cashstack, "cashvault": i_cashvault,
    "cashbank": i_cashbank, "cashboost": i_cashboost, "spin1": i_spin1, "spins3": i_spins3, "gems100": i_gems100, "gems300": i_gems300,
    "gems750": i_gems750, "gems1700": i_gems1700, "gems4500": i_gems4500, "gems12000": i_gems12000,
    # hammer crates (in-game art + the Robux crate products)
    "crate_supply": i_crate_supply, "crate_builder": i_crate_builder, "crate_golden": i_crate_golden, "crate_exclusive": i_crate_exclusive,
    "crate_golden3": i_crate_golden3, "crate_exclusive3": i_crate_exclusive3,
}
VIEW = {"cashpack": (0, -1, 0.3), "cash2x": (-0.2, -1, 0.75), "cashstack": (-0.2, -1, 0.75), "cashboost": (-0.2, -1, 0.6), "stormhammer": (-0.18, -1, 0.22), "monster": (-0.3, -1, 0.3), "rushcrew": (-0.1, -1, 0.42), "bigcrew": (0, -1, 0.45), "fasttools": (-0.1, -1, 0.2), "goldcar": (-0.45, -1, 0.5), "teleporter": (0, -1, 0.35),
        "vip": (0, -1, 0.42), "crate_supply": (-0.3, -1, 0.4), "crate_builder": (-0.3, -1, 0.4), "crate_golden": (-0.3, -1, 0.4),
        "crate_exclusive": (-0.3, -1, 0.4), "crate_golden3": (-0.22, -1, 0.38), "crate_exclusive3": (-0.22, -1, 0.38), "gems750": (0, -1, 0.5), "spin1": (0, -1, 0.12), "spins3": (0, -1, 0.12), "skipanim": (0, -1, 0.15)}
# card colours: (centre glow, edge)
CARD = {
    "skipanim": ("#6fc3ff", "#1b2f86"), "stormhammer": ("#8fd8ff", "#1a1f6e"), "teleporter": ("#7ff2ff", "#11406e"), "vip": ("#ffe27a", "#8a3a10"),
    "bigcrew": ("#ffd36b", "#a2470f"), "cash2x": ("#9cf29a", "#13643a"), "strength2x": ("#ffb08a", "#8a1f22"), "autobuild": ("#9fd3ff", "#1d3f8f"),
    "autotrain": ("#b6f59a", "#1d6a35"), "gems2x": ("#9fe8ff", "#1c3d9a"), "fasttools": ("#ffd98a", "#9a3a12"), "monster": ("#ff9aa2", "#7a1630"),
    "goldcar": ("#fff0a0", "#7a4a0c"), "starter": ("#ffb3e1", "#7a1f6a"), "rushcrew": ("#ffe08a", "#9a4a0f"), "cashpack": ("#a8f0a0", "#14603a"),
    "cashstack": ("#a8f0a0", "#14603a"), "cashvault": ("#c0f5b0", "#103f3a"), "cashbank": ("#fff1a6", "#6a3c0c"), "cashboost": ("#b8f5a8", "#145a40"),
    "spin1": ("#ffb0f0", "#5a1a8a"), "spins3": ("#8fe6ff", "#103d8c"), "gems100": ("#a8ecff", "#14408a"), "gems300": ("#b8e8ff", "#1c3a96"),
    "gems750": ("#b8e0ff", "#22348a"), "gems1700": ("#d8c0ff", "#3a1f8a"), "gems4500": ("#ffd8a0", "#5a2a7a"), "gems12000": ("#fff0b0", "#6a1f7a"),
    "crate_supply": ("#ffd98a", "#8a4a12"), "crate_builder": ("#a8d8ff", "#163a8a"), "crate_golden": ("#fff1a6", "#7a4a0c"), "crate_exclusive": ("#ffb8ee", "#5a1a7a"),
    "crate_golden3": ("#fff1a6", "#7a4a0c"), "crate_exclusive3": ("#ffb8ee", "#5a1a7a"),
}
SPARK = {"vip": [(0.84, 0.16, 0.07), (0.16, 0.3, 0.05)], "goldcar": [(0.84, 0.2, 0.07)], "gems100": [(0.82, 0.18, 0.08), (0.18, 0.7, 0.05)],
         "gems300": [(0.84, 0.16, 0.07)], "gems750": [(0.84, 0.16, 0.07), (0.16, 0.28, 0.05)], "gems1700": [(0.84, 0.16, 0.07)],
         "gems4500": [(0.86, 0.14, 0.07), (0.14, 0.3, 0.05)], "gems12000": [(0.86, 0.12, 0.08), (0.12, 0.26, 0.06), (0.6, 0.06, 0.04)],
         "cashbank": [(0.86, 0.14, 0.07)], "cashvault": [(0.84, 0.16, 0.06)], "starter": [(0.84, 0.16, 0.07)], "stormhammer": [(0.84, 0.16, 0.07)],
         "crate_golden": [(0.84, 0.16, 0.07)], "crate_exclusive": [(0.84, 0.16, 0.07), (0.16, 0.3, 0.05)], "crate_golden3": [(0.86, 0.14, 0.07)],
         "crate_exclusive3": [(0.86, 0.14, 0.07), (0.14, 0.3, 0.05)],
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


# ------------------------------------------------------------------------------------------- 2D: crate light
def crate_post(canvas, o_px, ray_hex, glow_hex):
    """soft coloured light rays fanning up behind the chest (no outline, they fade out) and a small bloom over the
    opening. o_px = the opening in canvas pixels (x, y from the top)."""
    S = canvas.shape[0]
    ox, oy = o_px
    yy, xx = np.mgrid[0:S, 0:S].astype(np.float32)
    dx, dy = xx - ox, yy - oy
    d = np.sqrt(dx * dx + dy * dy) / S
    ang = np.degrees(np.arctan2(dx, -dy))          # 0 = straight up
    n, spread, length = 9, 156.0, 0.56
    m = np.zeros((S, S), np.float32)
    for i in range(n):
        a = -spread / 2 + (i + 0.5) * spread / n
        w = (spread / n) * (0.36 if i % 2 == 0 else 0.24)
        L = length * (1.0 if i % 2 == 0 else 0.8)
        band = np.clip(1 - np.abs(ang - a) / w, 0, 1) ** 0.7
        fall = np.clip(1 - d / L, 0, 1) ** 1.4
        m = np.maximum(m, band * fall)
    halo = np.exp(-(d / 0.2) ** 2)
    alpha = np.clip(m * 0.62 + halo * 0.55, 0, 1)
    c = _hex(ray_hex)
    tint = np.clip(d / length, 0, 1)[..., None] ** 0.6
    rgb = (1 - tint) * (0.55 * c + 0.45) + tint * c        # pale near the chest, full colour further out
    rays = np.concatenate([rgb, alpha[..., None]], -1)
    out = postnp.over(rays, canvas)                        # the chest sticker sits on the light
    g = _hex(glow_hex)
    bloom = np.exp(-(d / 0.075) ** 2) * 0.38
    out = postnp.over(out, np.concatenate([np.broadcast_to(0.5 * g + 0.5, (S, S, 3)), bloom[..., None]], -1).astype(np.float32))
    return out


def _px_of(world, S):
    from bpy_extras.object_utils import world_to_camera_view
    scn = bpy.context.scene
    u = world_to_camera_view(scn, scn.camera, world)
    return (u.x * S, (1 - u.y) * S)


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
        GROUPS.clear()
        CRATE_O.clear()
        ICONS[n]()
        TOUCH_LOG.append(("clash", clashes()))
        I.add_outlines()
        scn = I3.iscene()
        scn.render.resolution_x = scn.render.resolution_y = size
        scn.cycles.samples = samples
        raw = os.path.join(OUT, "raw", n + ".png")
        I.frame_and_render(raw, view=VIEW.get(n, (-0.2, -1, 0.32)), margin=1.08)
        key = "robux_" + n
        postnp.SPARKLE[key] = SPARK.get(n, [])
        rawpx = postnp.load(raw)
        canvas = postnp.canvas_of(rawpx, key)
        if n.startswith("crate_") and CRATE_O:
            L = CRATE_LOOK[n.replace("crate_", "").rstrip("3")]
            canvas = crate_post(canvas, _px_of(CRATE_O[-1], rawpx.shape[0]), L["ray"], L["glow"])
        postnp.save(postnp.resize(canvas, 256), os.path.join(OUT, "game", n + ".png"))
        postnp.save(card(canvas, n), os.path.join(OUT, "card", n + ".png"))
        done.append(n)
    I3.clear()
    return done
