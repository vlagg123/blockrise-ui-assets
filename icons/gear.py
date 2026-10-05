"""BlockRise Empire - icons for the Shop's TRAINING gear (12 tiers), the heavy MACHINES (3) and the Training Yard
stations. Same pipeline and helpers as robux.py (PBR candy materials, outline, sticker finish), 256 px transparent.

    import gear; gear.render()
"""
import bpy, bmesh, math, os, random
from mathutils import Vector, Matrix
import icons as I
import icons3 as I3
import postnp
import items as T
import robux as R
from items import pbr, obj, bm_box, bm_cyl, bm_prism, bm_hull, bm_tube, circle, _xf
from robux import candy, gold, gold_dark, chrome, rubber, glow, box, cyl, sphere, torus, poly, dumbbell, wheel_

OUT = os.path.join(I3.OUT, "gear")
TAU = math.tau
SKIN = "#ffc896"


def iron():
    return pbr("iron", "#4a5165", metal=0.85, rough=0.3, coat=0.5, emit=0.18)


def concrete():
    return pbr("concrete", "#b4b8c0", rough=0.85, coat=0.05, tex="hammered", scale=9.0, bump=0.35, dark="#9a9ea8", light="#c6c9d0", emit=0.15)


def rounded(size, mat, loc=(0, 0, 0), rot=(0, 0, 0), r=0.12, parent=None, outline=True):
    return obj("rbox", bm_box(*size), mat, loc=loc, rot=rot, bevel=r, segs=4, parent=parent, outline=outline)


# ------------------------------------------------------------------------------------------- training gear
def meta(elements, mat, name="meta", P=None, resolution=0.035, threshold=0.6, outline=False):
    """organic shapes from metaballs (hands, gloves): elements = [(type, co, radius, size(x,y,z), rot(deg xyz), stiffness)]"""
    from mathutils import Euler
    scn = I3.iscene()
    mb = bpy.data.metaballs.new("mb_" + name)
    mb.resolution = resolution
    mb.render_resolution = resolution
    mb.threshold = threshold
    ob = bpy.data.objects.new("mb_" + name, mb)
    scn.collection.objects.link(ob)
    for typ, co, r, size, rot, stiff in elements:
        el = mb.elements.new()
        el.type = typ
        el.co = co
        el.radius = r
        el.stiffness = stiff
        if size:
            el.size_x, el.size_y, el.size_z = size
        if rot:
            el.rotation = Euler([math.radians(v) for v in rot]).to_quaternion()
    bpy.context.view_layer.update()
    dg = bpy.context.evaluated_depsgraph_get()
    me = bpy.data.meshes.new_from_object(ob.evaluated_get(dg), depsgraph=dg)
    bpy.data.objects.remove(ob, do_unlink=True)
    bpy.data.metaballs.remove(mb)
    for poly_ in me.polygons:
        poly_.use_smooth = True
    me.materials.append(mat)
    o = bpy.data.objects.new(name, me)
    scn.collection.objects.link(o)
    if P is not None:
        o.matrix_world = P
    if not outline:
        o["no_outline"] = True
    return o


def _catmull(ctrl, rad, sub):
    """Catmull-Rom curve through the control points, with a radius per point"""
    P = [Vector(p) for p in ctrl]
    n = len(P)
    pts, rs = [], []
    for i in range(n - 1):
        p1, p2 = P[i], P[i + 1]
        p0 = P[i - 1] if i > 0 else p1 + (p1 - p2)
        p3 = P[i + 2] if i + 2 < n else p2 + (p2 - p1)
        for s in range(sub):
            t = s / sub
            pt = 0.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t * t + (-p0 + 3 * p1 - 3 * p2 + p3) * t * t * t)
            pts.append(pt)
            rs.append(rad[i] + (rad[i + 1] - rad[i]) * t)
    pts.append(P[-1])
    rs.append(rad[-1])
    return pts, rs


def rtube(name, ctrl, rad, mat, parent=None, ring=32, sub=8, cap=10, outline=True):
    """a smooth round tube through the control points with round ends (fingers, thumbs)"""
    pts, rs = _catmull(ctrl, rad, sub)
    t0 = (pts[1] - pts[0]).normalized()
    t1 = (pts[-1] - pts[-2]).normalized()
    head, headr, tail, tailr = [], [], [], []
    for k in range(cap, 0, -1):
        th = (math.pi / 2) * k / (cap + 0.35)
        head.append(pts[0] - t0 * rs[0] * math.sin(th))
        headr.append(rs[0] * math.cos(th))
    for k in range(1, cap + 1):
        th = (math.pi / 2) * k / (cap + 0.35)
        tail.append(pts[-1] + t1 * rs[-1] * math.sin(th))
        tailr.append(rs[-1] * math.cos(th))
    path, radii = head + pts + tail, headr + rs + tailr
    n = len(path)
    bm = bm_tube(path, lambda f: radii[min(n - 1, round(f * (n - 1)))], ring=ring, caps=True)
    o = obj(name, bm, mat, smooth=85, outline=outline)
    if parent is not None:
        o.matrix_world = parent @ o.matrix_world
    return o


def pillow(name, size, mat, loc=(0, 0, 0), parent=None, bevel=0.16, taper=None, levels=2, outline=True):
    """a soft rounded block (bevelled box + subdivision): palms, the back of the hand"""
    bm = bm_box(*size)
    if taper:
        for v in bm.verts:
            if v.co.z < 0:
                v.co.x *= taper
    o = obj(name, bm, mat, loc=loc, parent=parent, smooth=85, bevel=bevel, segs=3, outline=outline)
    s = o.modifiers.new("soft", "SUBSURF")
    s.levels = s.render_levels = levels
    return o


def ribbed(name, r, h, mat, r2=None, sy=1.0, ribs=28, amp=0.016, loc=(0, 0, 0), parent=None, bevel=0.05, outline=True):
    """a knitted cuff / sweatband: a (flattened) cylinder with soft vertical ribs"""
    bm = bm_cyl(r, h, 112, r2=r2)
    for v in bm.verts:
        a = math.atan2(v.co.y, v.co.x)
        k = 1 + amp * math.cos(ribs * a) / max(r, 0.01)
        v.co.x *= k
        v.co.y *= k * sy
    return obj(name, bm, mat, loc=loc, parent=parent, smooth=40, bevel=bevel, segs=4, outline=outline)


def g_hands():
    """Bare Hands: a clean cartoon fist (the raised-fist emoji): four soft square fingers side by side with the knuckles
    on top, the thumb wrapped across them, a red terry sweatband on the wrist"""
    sk = pbr("skin3", "#f7b98b", rough=0.42, coat=0.15, emit=0.07)
    P = _xf((0, 0, 0), (0, 0, -14))
    pillow("hand", (1.18, 0.78, 0.92), sk, loc=(0, 0.3, 0.52), parent=P, bevel=0.25)
    # fingers index -> pinky: x, width, top
    for x, w, top in ((-0.44, 0.3, 1.14), (-0.147, 0.3, 1.18), (0.147, 0.3, 1.14), (0.43, 0.27, 1.06)):
        h = top - 0.56
        pillow("finger", (w, 0.74, h), sk, loc=(x, 0.06, 0.56 + h / 2), parent=P, bevel=0.1)
    rtube("thumb", [(-0.5, 0.25, 0.32), (-0.64, -0.08, 0.44), (-0.46, -0.4, 0.5), (-0.12, -0.5, 0.5), (0.16, -0.48, 0.47)],
          [0.22, 0.21, 0.195, 0.18, 0.165], sk, parent=P)
    nail = sphere(0.1, pbr("nail3", "#ffcab4", rough=0.25, coat=0.5, emit=0.05), outline=False)
    nail.matrix_world = P @ _xf((0.12, -0.6, 0.53), (-40, 0, -4), (0.9, 0.38, 0.7))
    obj("wrist", bm_cyl(0.42, 0.6, 64), sk, loc=(0, 0.3, 0.0), scale=(1, 0.85, 1), parent=P, smooth=40, outline=False)
    band = pbr("band_red", "#ff4a3d", rough=0.7, coat=0.05, emit=0.1, tex="leaf", scale=18, bump=0.3, dark="#ef3b30", light="#ff5d50")
    ribbed("band", 0.52, 0.42, band, sy=0.86, loc=(0, 0.3, -0.12), parent=P, ribs=30, amp=0.012, bevel=0.1)
    ribbed("stripe", 0.535, 0.09, candy("#ffffff", rough=0.5), sy=0.86, loc=(0, 0.3, -0.12), parent=P, ribs=30, amp=0.012, bevel=0.02,
           outline=False)


def g_gloves():
    """Work Gloves: a yellow leather work glove, palm to the front, with a stitched palm patch and a blue knitted cuff"""
    lea = pbr("leather_y2", "#f6b53c", rough=0.5, coat=0.25, emit=0.1, tex="hammered", scale=5.0, bump=0.04, dark="#f0ab33", light="#f9bf4c")
    P = _xf((0, 0, 0), (0, -6, -10))
    pillow("palm", (1.12, 0.46, 1.0), lea, loc=(0, 0, 0.55), parent=P, bevel=0.16, taper=0.88)
    # fingers, pinky to index (the thumb is on the right): x, lean (deg), length, radius
    for x, ang, L, r in ((-0.4, -9, 0.62, 0.155), (-0.135, -3, 0.82, 0.172), (0.135, 3, 0.9, 0.176), (0.4, 9, 0.8, 0.172)):
        a = math.radians(ang)
        d = Vector((math.sin(a), 0, math.cos(a)))
        b = Vector((x, 0, 0.88))
        rtube("finger", [b, b + d * L * 0.5 + Vector((0, -0.03, 0)), b + d * L + Vector((0, -0.08, 0))], [r * 1.05, r, r * 0.97], lea, parent=P)
    rtube("thumb", [(0.34, 0.02, 0.32), (0.62, -0.04, 0.5), (0.82, -0.1, 0.74), (0.92, -0.14, 0.93)], [0.21, 0.2, 0.185, 0.172], lea, parent=P)
    # the darker leather palm patch with white stitching around it
    patch = pbr("leather_d2", "#d4822a", rough=0.55, coat=0.2, emit=0.08, tex="hammered", scale=6.0, bump=0.06, dark="#cc7a28", light="#da8b33")
    w, z0, z1, cr = 0.36, 0.3, 0.8, 0.12
    pts = []
    for (cx, cz, a0) in ((w - cr, z1 - cr, 0), (-w + cr, z1 - cr, 90), (-w + cr, z0 + cr, 180), (w - cr, z0 + cr, 270)):
        for k in range(7):
            aa = math.radians(a0 + 90 * k / 6)
            pts.append((cx + math.cos(aa) * cr, cz + math.sin(aa) * cr))
    bm = bm_prism(pts, 0.08, axis="Y")
    for v in bm.verts:
        v.co.z = -v.co.z
    o = obj("patch", bm, patch, loc=(0, -0.19, 0), bevel=0.025, segs=3)
    o.matrix_world = P @ o.matrix_world
    st = candy("#fff2cf", rough=0.5)
    inset = 0.055
    ring = []
    for (cx, cz, a0) in ((w - cr, z1 - cr, 0), (-w + cr, z1 - cr, 90), (-w + cr, z0 + cr, 180), (w - cr, z0 + cr, 270)):
        for k in range(24):
            aa = math.radians(a0 + 90 * k / 24)
            ring.append(Vector((cx + math.cos(aa) * (cr - inset), 0, cz + math.sin(aa) * (cr - inset))))
    per = [0.0]
    for i in range(1, len(ring) + 1):
        per.append(per[-1] + (ring[i % len(ring)] - ring[i - 1]).length)
    total, dash, step = per[-1], 0.055, 0.1
    s = 0.0
    while s < total - step * 0.5:
        i = max(j for j in range(len(ring)) if per[j] <= s)
        p0, p1 = ring[i], ring[(i + 1) % len(ring)]
        f = (s - per[i]) / max(per[i + 1] - per[i], 1e-6)
        p = p0.lerp(p1, f)
        dirv = (p1 - p0).normalized()
        ang = math.degrees(math.atan2(dirv.z, dirv.x))
        d = obj("stitch", bm_box(dash, 0.02, 0.02), st, loc=(p.x, -0.235, p.z), rot=(0, -ang, 0), bevel=0.008, segs=2, outline=False)
        d.matrix_world = P @ d.matrix_world
        s += step
    knit = pbr("knit_b", "#2f7cf6", rough=0.7, coat=0.05, emit=0.12, tex="leaf", scale=22.0, bump=0.25, dark="#2a70e6", light="#3a88ff")
    ribbed("cuff", 0.6, 0.56, knit, r2=0.56, sy=0.56, loc=(0, 0, -0.14), parent=P, ribs=28, amp=0.016, bevel=0.07)
    ribbed("cuffline", 0.578, 0.09, candy("#ffffff", rough=0.5), r2=0.574, sy=0.56, loc=(0, 0, 0.0), parent=P, ribs=28, amp=0.016, bevel=0.02,
           outline=False)


def g_belt():
    """Lifting Belt: a thick leather belt in a loop, wide at the back, big gold buckle"""
    lea = pbr("leather", "#8c4a22", rough=0.5, coat=0.4, tex="leaf", scale=7, bump=0.15, dark="#7c3f1c", light="#a05a2c", emit=0.15)
    n = 72
    out, inn = [], []
    for k in range(n):
        a = TAU * k / n
        out.append((math.cos(a) * 1.35, math.sin(a) * 0.95))
        inn.append((math.cos(a) * 1.15, math.sin(a) * 0.76))
    bm = bm_prism(out, 0.62, holes=inn)
    # the back is wider (a lifting belt): pull the top/bottom out where y > 0
    for v in bm.verts:
        if v.co.y > 0:
            k = min(1.0, v.co.y / 0.95) ** 1.5
            v.co.z *= 1 + 0.55 * k
    obj("belt", bm, lea, loc=(0, 0, 0.7), rot=(18, 0, 0), smooth=50, bevel=0.03)
    # stitching (a light line along the edges at the front)
    P = _xf((0, 0, 0.7), (18, 0, 0))
    g = gold()
    # buckle at the front: a rounded rectangle frame
    def rr(w, h, rr_, n4=8):
        pts = []
        for cx, cy, a0 in ((w / 2 - rr_, h / 2 - rr_, 0), (-w / 2 + rr_, h / 2 - rr_, 90), (-w / 2 + rr_, -h / 2 + rr_, 180), (w / 2 - rr_, -h / 2 + rr_, 270)):
            for k in range(n4):
                a = math.radians(a0 + 90 * k / (n4 - 1))
                pts.append((cx + math.cos(a) * rr_, cy + math.sin(a) * rr_))
        return pts
    bm = bm_prism(rr(0.95, 0.85, 0.2), 0.16, axis="Y", holes=rr(0.62, 0.52, 0.08))
    obj("buckle", bm, g, loc=(0, -1.0, 0), parent=P, bevel=0.03)
    obj("prong", bm_box(0.09, 0.1, 0.62), chrome(), loc=(0, -1.06, 0.0), rot=(0, 90, 0), parent=P, bevel=0.03)
    for x in (-0.55, 0.55):
        obj("loop", bm_box(0.1, 0.16, 0.7), lea, loc=(x, -0.98, 0), parent=P, bevel=0.03)


def g_dumbbells():
    dumbbell((0.0, 0.5, 0.75), rot=(0, -18, -25), plate="#2f8cff", s=0.8)
    dumbbell((0.1, -0.4, 0.0), rot=(0, 10, -15), plate="#2f8cff", s=0.85)


def g_kettlebell():
    body = candy("#ff6a2b", rough=0.3)
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=48, v_segments=24, radius=1.0)
    for v in bm.verts:
        if v.co.z < -0.82:
            v.co.z = -0.82
    obj("bell", bm, body, loc=(0, 0, 0.9), smooth=80)
    obj("foot", bm_cyl(0.58, 0.1, 48), candy("#2b2d38"), loc=(0, 0, 0.05), smooth=40, bevel=0.03)
    t = torus(0.62, 0.17, candy("#2b2d38", rough=0.35), a0=-0.25, a1=math.pi + 0.25, seg=40)
    t.matrix_world = _xf((0, 0, 1.55), (90, 0, 0)) @ t.matrix_world
    for x in (-0.6, 0.6):
        cyl(0.17, 0.4, candy("#2b2d38", rough=0.35), loc=(x, 0, 1.55), bevel=0.0)
    # a white weight label


def barbell(loc, rot, plates=(("#e0302f", 1.0, 0.26), ("#2f8cff", 0.8, 0.22), ("#ffc534", 0.6, 0.18)), L=3.8, bar=None, s=1.0):
    P = _xf(loc, rot, s)
    if bar is None:
        obj("bar", bm_cyl(0.09, L, 32, axis="X"), chrome(), parent=P, smooth=40, bevel=0.01)
    else:
        bar(P)
    for sx in (-1, 1):
        x = sx * (L / 2 - 0.55)
        for col, r, w in plates:
            obj("plate", bm_cyl(r, w, 56, axis="X"), candy(col, rough=0.28), loc=(x, 0, 0), parent=P, smooth=40, bevel=0.05)
            obj("pin", bm_cyl(0.16, w + 0.04, 24, axis="X"), chrome(), loc=(x, 0, 0), parent=P, smooth=40, outline=False)
            x += sx * (w + 0.02)
        obj("collar", bm_cyl(0.15, 0.14, 24, axis="X"), chrome(), loc=(x + sx * 0.05, 0, 0), parent=P, smooth=40, bevel=0.02)


def g_barbell():
    barbell((0, 0, 0.6), (0, 0, -20))


def g_ibeam():
    steel = pbr("ibeam_y", "#ffb81c", metal=0.3, rough=0.32, coat=0.6, emit=0.22)

    def bar(P):
        T.i_beam(steel, (0, 0, 0), L=4.0, w=0.62, h=0.72, tf=0.12, tw=0.12)
        ob = [o for o in I3.iscene().objects if o.name.startswith("it_beam")][-1]
        ob.matrix_world = P @ _xf((0, 0, 0), (0, 0, 90))
    barbell((0, 0, 0.6), (0, 0, -20), plates=(("#2b2d38", 1.1, 0.3),), L=4.0, bar=bar)


def g_block():
    """Concrete Block: a heavy grey block with two chain handles"""
    c = concrete()
    rounded((1.9, 1.5, 1.25), c, loc=(0, 0, 0.62), rot=(0, 0, 18), r=0.08)
    P = _xf((0, 0, 1.25), (0, 0, 18))
    for x in (-0.55, 0.55):
        for k in range(3):
            t = torus(0.17, 0.05, chrome(), seg=24, ring=10)
            t.matrix_world = P @ _xf((x, 0, 0.12 + k * 0.24), (90 if k % 2 == 0 else 0, 0, 90 if k % 2 else 0)) @ Matrix.Diagonal((1, 1.5, 1, 1))
    t = torus(0.55, 0.06, chrome(), a0=0.0, a1=math.pi, seg=30)
    t.matrix_world = P @ _xf((0, 0, 0.72), (90, 0, 0)) @ Matrix.Diagonal((1, 0.5, 1, 1))


def g_anvil():
    pts = [(-0.7, 1.0), (1.1, 1.0), (1.1, 0.72), (0.78, 0.56), (0.72, 0.24), (1.18, 0.0), (-0.78, 0.0), (-0.34, 0.24), (-0.4, 0.56), (-0.75, 0.62), (-1.65, 0.9)]
    m = iron()
    a = poly(pts, 0.95, m, loc=(0, 0, 0), rot=(0, 0, -25), bevel=0.05)
    # shiny worn top
    box((1.72, 0.9, 0.04), pbr("anviltop", "#c9d3e6", metal=1.0, rough=0.15, coat=0.6, emit=0.25), loc=(0.2, 0, 1.0), rot=(0, 0, -25), bevel=0.01, outline=False)


def g_wreck():
    ball = pbr("wreckball", "#2f3340", metal=0.7, rough=0.3, coat=0.6, emit=0.15)
    sphere(1.1, ball, loc=(0, 0, 0.9))
    cyl(0.32, 0.3, iron(), loc=(0, 0, 2.05), bevel=0.04)
    for k in range(4):
        t = torus(0.2, 0.06, chrome(), seg=24, ring=10)
        t.matrix_world = _xf((0, 0, 2.35 + k * 0.32), (0 if k % 2 == 0 else 0, 90 if k % 2 == 0 else 0, 0 if k % 2 == 0 else 90)) @ Matrix.Diagonal((1, 1, 1.5, 1))
    # hazard stripes on a band around it
    obj("band", bm_cyl(1.12, 0.32, 64), candy("#ffc534", rough=0.35), loc=(0, 0, 0.9), smooth=40, bevel=0.0)
    for k in range(10):
        a = TAU * k / 10
        box((0.22, 0.05, 0.34), candy("#2b2d38"), loc=(math.cos(a) * 1.13, math.sin(a) * 1.13, 0.9), rot=(0, 0, math.degrees(a) + 90 + 0), bevel=0.0, outline=False)


def g_girder():
    """Steel Girder: a red bridge truss with bolts"""
    red = pbr("girder", "#e0452b", metal=0.35, rough=0.35, coat=0.6, emit=0.2)
    P = _xf((0, 0, 0.7), (0, 0, -22))
    L, H = 3.6, 1.1
    for z in (-H / 2, H / 2):
        obj("chord", bm_box(L, 0.42, 0.22), red, loc=(0, 0, z), parent=P, bevel=0.03)
    n = 5
    for k in range(n + 1):
        x = -L / 2 + 0.15 + k * (L - 0.3) / n
        obj("post", bm_box(0.16, 0.3, H), red, loc=(x, 0, 0), parent=P, bevel=0.02)
        if k < n:
            x2 = -L / 2 + 0.15 + (k + 0.5) * (L - 0.3) / n
            d = math.degrees(math.atan2(H, (L - 0.3) / n)) * (1 if k % 2 else -1)
            obj("diag", bm_box(math.hypot(H, (L - 0.3) / n), 0.24, 0.12), red, loc=(x2, 0, 0), rot=(0, d, 0), parent=P, bevel=0.02)
        for z in (-H / 2, H / 2):
            b = sphere(0.07, chrome(), outline=False)
            b.matrix_world = P @ _xf((x, -0.23, z))


def g_hook():
    """Tower Crane Hook: a yellow pulley block on two cables and a forged J hook with its safety latch"""
    y = candy("#ffc534", rough=0.3)
    dk = candy("#2b2d38", rough=0.45)
    rounded((1.2, 0.62, 0.9), y, loc=(0, 0, 1.75), r=0.18)
    for x in (-0.3, 0.3):
        cyl(0.3, 0.7, chrome(), loc=(x, 0, 1.92), rot=(90, 0, 0), bevel=0.04)
        cyl(0.035, 1.3, dk, loc=(x, 0, 2.85), bevel=0.0, outline=False)
    obj("cheek", bm_box(1.24, 0.66, 0.14), dk, loc=(0, 0, 1.36), bevel=0.04)
    for k in range(4):
        obj("haz", bm_box(0.14, 0.03, 0.5), dk, loc=(-0.42 + k * 0.28, -0.32, 1.78), rot=(0, 32, 0), bevel=0.0, outline=False)
    hk = pbr("hook", "#cfd8e8", metal=1.0, rough=0.16, coat=0.6, emit=0.22)
    cyl(0.16, 0.22, hk, loc=(0, 0, 1.2), bevel=0.03)
    t = torus(0.17, 0.07, hk, seg=32, ring=12)
    t.matrix_world = _xf((0, 0, 1.0), (90, 0, 0)) @ t.matrix_world
    # the J: shank down, round the bottom, up to a blunt tip (thick to thin)
    R0, cx, cz = 0.46, 0.46, 0.15
    path = [(0, 0, 0.84), (0, 0, 0.55), (0, 0, cz)]
    n = 36
    for k in range(1, n + 1):
        a = math.pi + (math.pi + 0.55) * k / n
        path.append((cx + math.cos(a) * R0, 0, cz + math.sin(a) * R0))
    bm = bm_tube(path, lambda t: 0.19 - 0.09 * t, ring=20)
    obj("hook", bm, hk, smooth=70)
    tip = Vector(path[-1])
    sphere(0.1, hk, loc=tuple(tip))
    # safety latch: a red spring bar from the shank to the tip
    a0 = Vector((0.0, 0, 0.62))
    d = tip - a0
    lat = obj("latch", bm_box(d.length, 0.1, 0.05), candy("#e0302f", rough=0.3), bevel=0.02)
    lat.matrix_world = Matrix.Translation((a0 + tip) / 2) @ Matrix.Rotation(-math.atan2(d.z, d.x), 4, "Y")


# ------------------------------------------------------------------------------------------- machines
YEL = "#ffb81c"


def m_excavator():
    y = candy(YEL, rough=0.3)
    dk = candy("#2b2d38", rough=0.45)
    P = _xf((0, 0, 0), (0, 0, -28))
    for yy in (-0.62, 0.62):
        obj("track", bm_box(2.3, 0.42, 0.5), rubber(), loc=(0, yy, 0.25), parent=P, bevel=0.22, segs=6)
        for k in range(4):
            obj("roller", bm_cyl(0.13, 0.46, 24, axis="Y"), chrome(), loc=(-0.75 + k * 0.5, yy, 0.25), parent=P, smooth=40, outline=False)
    obj("turret", bm_cyl(0.6, 0.18, 48), dk, loc=(0, 0, 0.58), parent=P, smooth=40)
    obj("body", bm_box(1.8, 1.3, 0.55), y, loc=(-0.2, 0, 0.95), parent=P, bevel=0.12)
    obj("cab", bm_box(0.85, 0.75, 0.85), y, loc=(0.25, 0.3, 1.6), parent=P, bevel=0.1)
    obj("glass", bm_box(0.88, 0.6, 0.5), candy("#bfe6ff", rough=0.08, emit=0.3), loc=(0.27, 0.3, 1.68), parent=P, bevel=0.05)
    obj("weight", bm_box(0.4, 1.2, 0.5), dk, loc=(-1.05, 0, 1.0), parent=P, bevel=0.1)
    # boom and stick
    A = P @ _xf((0.55, -0.3, 1.1), (0, -40, 0))
    obj("boom", bm_box(1.7, 0.28, 0.3), y, loc=(0.85, 0, 0), parent=A, bevel=0.08)
    B = A @ _xf((1.65, 0, 0), (0, 95, 0))
    obj("stick", bm_box(1.25, 0.24, 0.26), y, loc=(0.6, 0, 0), parent=B, bevel=0.07)
    obj("piston", bm_cyl(0.06, 1.1, 16, axis="X"), chrome(), loc=(0.6, 0, 0.22), parent=A, smooth=40, outline=False)
    C = B @ _xf((1.2, 0, 0), (0, 30, 0))
    pts = [(0, 0.25, 0), (0, -0.25, 0), (0.55, 0.3, -0.1), (0.55, -0.3, -0.1), (0.15, 0.3, -0.55), (0.15, -0.3, -0.55), (0.62, 0.3, -0.5), (0.62, -0.3, -0.5)]
    obj("bucket", bm_hull(pts), dk, parent=C, bevel=0.04)
    for k in range(4):
        obj("tooth", bm_box(0.1, 0.08, 0.16), chrome(), loc=(0.68, -0.21 + k * 0.14, -0.55), parent=C, bevel=0.02, outline=False)


def m_mixer():
    w = candy("#f2f4f8", rough=0.3)
    red = candy("#e0302f", rough=0.3)
    P = _xf((0, 0, 0), (0, 0, -28))
    obj("chassis", bm_box(3.2, 1.0, 0.3), candy("#2b2d38", rough=0.45), loc=(0, 0, 0.55), parent=P, bevel=0.05)
    obj("cab", bm_box(0.95, 1.1, 1.0), red, loc=(1.15, 0, 1.15), parent=P, bevel=0.15)
    obj("glass", bm_box(0.5, 1.12, 0.45), candy("#bfe6ff", rough=0.08, emit=0.3), loc=(1.3, 0, 1.38), parent=P, bevel=0.05)
    obj("bumper", bm_box(0.15, 1.05, 0.22), chrome(), loc=(1.65, 0, 0.6), parent=P, bevel=0.05)
    D = P @ _xf((-0.45, 0, 1.25), (0, -16, 0))
    obj("drum", bm_cyl(0.78, 1.5, 48, r2=0.42, axis="X"), w, loc=(-0.1, 0, 0), parent=D, smooth=40, bevel=0.06)
    obj("drum_back", bm_cyl(0.78, 0.5, 48, r2=0.55, axis="X"), w, loc=(0.85, 0, 0), parent=D, smooth=40, bevel=0.06)
    for k in range(4):
        x = -0.6 + k * 0.38
        r = 0.78 - (x + 0.85) * 0.0
        rr = 0.78 - (x + 0.85) / 1.5 * 0.36 + 0.03
        t = torus(rr, 0.06, red, seg=48, ring=10)
        t.matrix_world = D @ _xf((x, 0, 0), (0, 90, 0)) @ _xf((0, 0, 0), (14, 0, 0))
    obj("chute", bm_box(0.6, 0.25, 0.1), candy("#9aa3b8", rough=0.3), loc=(-1.0, 0, -0.35), rot=(0, 30, 0), parent=D, bevel=0.03)
    for x in (-1.1, -0.3, 1.15):
        for yy in (-0.55, 0.55):
            wheel_((x, yy, 0.38), r=0.38, w=0.3, parent=P, rim=chrome())


def m_crane():
    y = candy(YEL, rough=0.3)
    dk = candy("#2b2d38", rough=0.45)
    P = _xf((0, 0, 0), (0, 0, -28))
    obj("base", bm_box(2.9, 1.15, 0.5), y, loc=(0, 0, 0.75), parent=P, bevel=0.1)
    obj("cab", bm_box(0.7, 1.0, 0.75), y, loc=(1.15, 0.0, 1.3), parent=P, bevel=0.12)
    obj("glass", bm_box(0.4, 1.02, 0.36), candy("#bfe6ff", rough=0.08, emit=0.3), loc=(1.3, 0, 1.38), parent=P, bevel=0.04)
    obj("turret", bm_box(1.1, 0.9, 0.5), dk, loc=(-0.45, 0, 1.25), parent=P, bevel=0.08)
    for x in (-1.05, -0.35, 0.95):
        for yy in (-0.58, 0.58):
            wheel_((x, yy, 0.38), r=0.38, w=0.3, parent=P, rim=chrome())
    for x in (-1.35, 1.35):
        obj("leg", bm_box(0.18, 1.6, 0.12), dk, loc=(x, 0, 0.55), parent=P, bevel=0.03)
    Bm = P @ _xf((-0.6, 0, 1.45), (0, -38, 0))
    obj("boom1", bm_box(2.0, 0.42, 0.42), y, loc=(1.0, 0, 0), parent=Bm, bevel=0.06)
    obj("boom2", bm_box(1.4, 0.32, 0.32), candy("#ffd04a", rough=0.3), loc=(2.6, 0, 0), parent=Bm, bevel=0.05)
    for k in range(0, 6, 2):
        obj("stripe", bm_box(0.12, 0.44, 0.44), dk, loc=(0.3 + k * 0.28, 0, 0), parent=Bm, bevel=0.0, outline=False)
    tip = Bm @ Vector((3.25, 0, 0))
    cyl(0.025, (tip.z - 0.9), dk, loc=(tip.x, tip.y, (tip.z + 0.9) / 2), bevel=0.0)
    hk = pbr("hook", "#c9d3e6", metal=1.0, rough=0.18, coat=0.5, emit=0.22)
    box((0.3, 0.25, 0.3), y, loc=(tip.x, tip.y, 0.95), bevel=0.06)
    t = torus(0.2, 0.07, hk, a0=-math.pi * 0.4, a1=math.pi * 1.2, seg=32)
    t.matrix_world = _xf((tip.x, tip.y, 0.62), (90, 0, -28)) @ t.matrix_world


# ------------------------------------------------------------------------------------------- training yard stations
def s_tires():
    """Tire Flip: a giant tractor tire standing on its edge, leaning"""
    P = _xf((0, 0, 1.05), (0, 22, -24))
    t = torus(0.82, 0.42, rubber(), seg=64, ring=20)
    t.matrix_world = P @ _xf((0, 0, 0), (90, 0, 0)) @ t.matrix_world
    for k in range(22):
        a = TAU * k / 22
        obj("lug", bm_box(0.28, 0.75, 0.12), rubber(), loc=(math.cos(a) * 1.25, 0, math.sin(a) * 1.25), rot=(0, -math.degrees(a) + 90, 0), parent=P,
            bevel=0.03, outline=False)
    obj("rim", bm_cyl(0.55, 0.5, 48, axis="Y"), candy("#ffc534", rough=0.3), parent=P, smooth=40, bevel=0.05)
    obj("hub", bm_cyl(0.2, 0.56, 24, axis="Y"), chrome(), parent=P, smooth=40, bevel=0.03)


def s_hoist():
    """Engine Hoist: a yellow A-frame, a chain and a hook lifting an engine block"""
    y = candy("#ffc534", rough=0.3)
    P = _xf((0, 0, 0), (0, 0, -20))
    for x in (-1.0, 1.0):
        obj("leg", bm_box(0.2, 0.2, 2.6), y, loc=(x * 0.75, 0, 1.2), rot=(0, x * -16, 0), parent=P, bevel=0.04)
    obj("top", bm_box(2.0, 0.26, 0.26), y, loc=(0, 0, 2.48), parent=P, bevel=0.05)
    obj("foot", bm_box(2.6, 0.5, 0.16), candy("#2b2d38"), loc=(0, 0, 0.08), parent=P, bevel=0.04)
    for k in range(5):
        t = torus(0.1, 0.035, chrome(), seg=20, ring=8)
        t.matrix_world = P @ _xf((0, 0, 2.25 - k * 0.17), (0, 90 if k % 2 else 0, 0)) @ Matrix.Diagonal((1, 1, 1.5, 1))
    eng = pbr("engine", "#6f7a90", metal=0.8, rough=0.3, coat=0.5, emit=0.2)
    obj("block", bm_box(1.0, 0.7, 0.62), eng, loc=(0, 0, 1.1), parent=P, bevel=0.06)
    for k in range(3):
        obj("cylhead", bm_cyl(0.13, 0.22, 20), candy("#e0302f", rough=0.3), loc=(-0.32 + k * 0.32, 0, 1.5), parent=P, smooth=40, bevel=0.02)


ICONS = {
    "gear1": g_hands, "gear2": g_gloves, "gear3": g_belt, "gear4": g_dumbbells, "gear5": g_kettlebell, "gear6": g_barbell,
    "gear7": g_ibeam, "gear8": g_block, "gear9": g_anvil, "gear10": g_wreck, "gear11": g_girder, "gear12": g_hook,
    "excavator": m_excavator, "mixer": m_mixer, "crane": m_crane, "st_tires": s_tires, "st_hoist": s_hoist,
}
VIEW = {"gear3": (-0.1, -1, 0.75), "gear4": (-0.2, -1, 0.45), "gear8": (-0.2, -1, 0.45), "gear11": (-0.2, -1, 0.3), "gear12": (-0.1, -1, 0.12), "gear1": (-0.3, -1, 0.35), "gear2": (-0.22, -1, 0.18),
        "excavator": (-0.3, -1, 0.35), "mixer": (-0.3, -1, 0.3), "crane": (-0.3, -1, 0.3), "st_tires": (-0.2, -1, 0.25), "st_hoist": (-0.2, -1, 0.25)}
SPARK = {"gear9": [(0.82, 0.2, 0.07), (0.66, 0.1, 0.045)], "gear5": [(0.82, 0.2, 0.06)], "gear12": [(0.84, 0.18, 0.06)], "gear10": [(0.84, 0.16, 0.06)]}


def render(names=None, size=768, samples=80):
    names = names or list(ICONS)
    os.makedirs(os.path.join(OUT, "raw"), exist_ok=True)
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
        key = "gear_" + n
        postnp.SPARKLE[key] = SPARK.get(n, [])
        postnp.save(postnp.finish(postnp.load(raw), key, 256), os.path.join(OUT, n + ".png"))
        done.append(n)
    I3.clear()
    return done
