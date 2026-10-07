# zonecrates.py - the Supply Crate of every zone, each its own object (BlockRise Empire)
#   town      a wooden shipping crate: planks, corner posts, a Z brace, rope handles, the lid pried off behind
#   suburbs   a green cantilever toolbox: two white trays swung up on chrome arms, a little house on the front
#   downtown  a navy armoured cargo pod: rounded shell, cyan light strips, a skyline badge, the lid up on pistons
import math, random
import bpy, bmesh
from mathutils import Vector, Matrix
import robux as R
from robux import obj, bm_box, bm_cyl, bm_tube, bm_hull, bm_prism, pbr, candy, glow, chrome, track, _xf, torus, burst_hammer

R.CRATE_LOOK["town"] = {"glow": "#ffc93a", "ray": "#ff9f1c"}
R.CRATE_LOOK["suburbs"] = {"glow": "#d6ff8f", "ray": "#3fcf5c"}
R.CRATE_LOOK["downtown"] = {"glow": "#9ff6ff", "ray": "#2f8dff"}
POSE = (0.0, -15.0, -45.0)


def _bar(p0, p1, r, mat, name="bar", outline=True):
    """a round bar between two world points"""
    return obj(name, bm_tube([p0, p1], r, ring=14), mat, smooth=60, outline=outline)


def _front_poly(pts, depth):
    """a 2D outline (x right, z up) as a slab facing -Y"""
    bm = bm_prism(pts, depth, axis="Y")
    for v in bm.verts:
        v.co.z = -v.co.z
    return bm


def town_crate(loc=(0, 0, 0), rot=(0, 0, 0), s=1.0, hammer="steel"):
    P = _xf(loc, rot, s)
    W, D, H = 2.5, 1.9, 1.7
    plank = pbr("zc_plank", "#d08b4b", rough=0.55, coat=0.35, tex="grain", dark="#a8672f", light="#e3a466", emit=0.14)
    post = pbr("zc_post", "#e6ae6e", rough=0.5, coat=0.35, tex="grain", dark="#c0843f", light="#f2c084", emit=0.16)
    brace = pbr("zc_brace", "#a9622c", rough=0.55, coat=0.3, tex="grain", dark="#874c1f", light="#bf7a3e", emit=0.1)
    dark = candy("#3a2414", rough=0.7, coat=0.0, emit=0.03)
    iron = pbr("zc_iron", "#3d424e", metal=0.8, rough=0.35, coat=0.3, emit=0.08)
    rope = candy("#ecd49a", rough=0.75, coat=0.1, emit=0.12)
    straw = candy("#f6d55c", rough=0.6, coat=0.2, emit=0.2)
    obj("core", bm_box(W - 0.16, D - 0.16, H - 0.1), dark, loc=(0, 0, (H - 0.1) / 2), parent=P, outline=False)
    # the planks: three a side with a gap between them
    n, gap, th = 3, 0.07, 0.12
    ph = (H - gap * (n - 1)) / n
    for i in range(n):
        z = ph / 2 + i * (ph + gap)
        for y in (-D / 2, D / 2):
            obj("plank", bm_box(W - 0.3, th, ph), plank, loc=(0, y, z), parent=P, bevel=0.035)
        for x in (-W / 2, W / 2):
            obj("plank", bm_box(th, D - 0.3, ph), plank, loc=(x, 0, z), parent=P, bevel=0.035)
    for x in (-W / 2, W / 2):
        for y in (-D / 2, D / 2):
            obj("post", bm_box(0.27, 0.27, H + 0.05), post, loc=(x, y, (H + 0.05) / 2), parent=P, bevel=0.05)
    # the Z brace on the front and the right side
    for z in (0.15, H - 0.15):
        obj("batten", bm_box(W - 0.3, 0.1, 0.22), brace, loc=(0, -D / 2 - 0.1, z), parent=P, bevel=0.03)
        obj("batten", bm_box(0.1, D - 0.3, 0.22), brace, loc=(-W / 2 - 0.1, 0, z), parent=P, bevel=0.03)
    dl, da = math.hypot(W - 0.55, H - 0.45), math.degrees(math.atan2(H - 0.45, W - 0.55))
    obj("diag", bm_box(dl, 0.1, 0.22), brace, loc=(0, -D / 2 - 0.11, H / 2), rot=(0, -da, 0), parent=P, bevel=0.03)
    dl2, da2 = math.hypot(D - 0.55, H - 0.45), math.degrees(math.atan2(H - 0.45, D - 0.55))
    obj("diag", bm_box(0.1, dl2, 0.22), brace, loc=(-W / 2 - 0.11, 0, H / 2), rot=(da2, 0, 0), parent=P, bevel=0.03)
    for x in (-W / 2 + 0.36, W / 2 - 0.36):
        for z in (0.15, H - 0.15):
            obj("nail", bm_cyl(0.05, 0.05, 12, axis="Y"), iron, loc=(x, -D / 2 - 0.17, z), parent=P, smooth=40, outline=False)
    # rope handles on the sides
    for sx in (-1, 1):
        x0, x1 = sx * (W / 2 + 0.03), sx * (W / 2 + 0.24)
        pts = [P @ Vector(p) for p in ((x0, -0.42, H * 0.7), (x1, -0.38, H * 0.56), (x1, 0.0, H * 0.48), (x1, 0.38, H * 0.56), (x0, 0.42, H * 0.7))]
        obj("rope", bm_tube(pts, 0.065, ring=12), rope, smooth=60)
    # the lid: three planks on two battens, pried off and leaning on the back
    Lf = P @ _xf((0.12, D / 2 + 0.06, H + 0.02), (-108, 0, 5))
    lw = (D + 0.1) / 3
    for i in range(3):
        obj("lidplank", bm_box(W + 0.08, lw - 0.06, 0.12), plank, loc=(0, -lw / 2 - i * lw, 0.06), parent=Lf, bevel=0.035)
    for x in (-W / 2 + 0.35, W / 2 - 0.35):
        obj("lidbatten", bm_box(0.22, D, 0.1), brace, loc=(x, -(D + 0.1) / 2, -0.05), parent=Lf, bevel=0.03)
    # packing straw sticking out of the top, and the light inside
    rng = random.Random(7)
    for k in range(14):
        a = k / 14 * math.tau + rng.uniform(-0.2, 0.2)
        rx, ry = math.cos(a) * (W / 2 - 0.35), math.sin(a) * (D / 2 - 0.35)
        out = Vector((math.cos(a) * 0.5, math.sin(a) * 0.5, 0))
        p0 = Vector((rx * 0.8, ry * 0.8, H - 0.05))
        pts = [P @ (p0 + out * t + Vector((0, 0, 0.35 * math.sin(t * 2.2) + rng.uniform(0, 0.08)))) for t in (0, 0.35, 0.7, 1.0)]
        obj("straw", bm_tube(pts, 0.028, ring=6), straw, smooth=60, outline=False)
    obj("light", bm_box(W - 0.42, D - 0.42, 0.26), glow(R.CRATE_LOOK["town"]["glow"], 2.6), loc=(0, 0, H - 0.04), parent=P, bevel=0.06, outline=False)
    R.CRATE_O.append(P @ Vector((0, 0, H + 0.15)))
    burst_hammer(P, hammer, H, POSE)
    return P


def suburbs_box(loc=(0, 0, 0), rot=(0, 0, 0), s=1.0, hammer="emerald"):
    P = _xf(loc, rot, s)
    W, D, H = 2.7, 1.6, 1.1
    green = pbr("zc_green", "#3ec25b", metal=0.35, rough=0.3, coat=0.7, emit=0.18)
    green2 = pbr("zc_green2", "#2a9a45", metal=0.35, rough=0.32, coat=0.6, emit=0.14)
    white = candy("#f5f7ef", rough=0.3, emit=0.22)
    inner = candy("#163a20", rough=0.6, coat=0.1, emit=0.04)
    red = candy("#ff5b4a", rough=0.3, emit=0.18)
    yellow = candy("#ffcf3a", rough=0.3, emit=0.2)
    ch = chrome()
    b, t = (W / 2 - 0.12, D / 2 - 0.07), (W / 2, D / 2)
    pts = [Vector((sx * b[0], sy * b[1], 0)) for sx in (-1, 1) for sy in (-1, 1)] + [Vector((sx * t[0], sy * t[1], H)) for sx in (-1, 1) for sy in (-1, 1)]
    obj("tb_body", bm_hull([P @ p for p in pts]), green, bevel=0.08)
    # the white rim round the opening (a frame: the light inside shows)
    for y in (-(D + 0.1) / 2 + 0.08, (D + 0.1) / 2 - 0.08):
        obj("tb_rim", bm_box(W + 0.1, 0.16, 0.16), white, loc=(0, y, H - 0.04), parent=P, bevel=0.05)
    for x in (-(W + 0.1) / 2 + 0.08, (W + 0.1) / 2 - 0.08):
        obj("tb_rim", bm_box(0.16, D + 0.1, 0.16), white, loc=(x, 0, H - 0.04), parent=P, bevel=0.05)
    for z in (0.28, 0.5):
        k = z / H
        obj("tb_rib", bm_box(W - 0.5, 0.06, 0.09), green2, loc=(0, -(b[1] + (t[1] - b[1]) * k) - 0.02, z), parent=P, bevel=0.02)
    # the little house on the front (white walls, red roof, a yellow window)
    hx, hz = 0, 0.2
    obj("house", _front_poly([(-0.26, 0), (0.26, 0), (0.26, 0.3), (-0.26, 0.3)], 0.08), white, loc=(hx, -t[1] - 0.06, hz), parent=P, bevel=0.02)
    obj("roof", _front_poly([(-0.36, 0.28), (0.36, 0.28), (0, 0.6)], 0.1), red, loc=(hx, -t[1] - 0.08, hz), parent=P, bevel=0.02)
    obj("window", bm_box(0.13, 0.04, 0.13), yellow, loc=(hx + 0.1, -t[1] - 0.11, hz + 0.16), parent=P, bevel=0.01)
    obj("door", bm_box(0.12, 0.04, 0.18), green2, loc=(hx - 0.09, -t[1] - 0.11, hz + 0.09), parent=P, bevel=0.01)
    for x in (-0.82, 0.82):
        obj("latch", bm_box(0.3, 0.1, 0.34), ch, loc=(x, -t[1] - 0.05, H - 0.3), parent=P, bevel=0.04)
        obj("latchbtn", bm_cyl(0.07, 0.08, 16, axis="Y"), red, loc=(x, -t[1] - 0.12, H - 0.3), parent=P, smooth=40)
    for x in (-W / 2 + 0.2, W / 2 - 0.2):
        for y in (-b[1] + 0.15, b[1] - 0.15):
            obj("foot", bm_cyl(0.12, 0.1, 16), R.rubber(), loc=(x, y, -0.03), parent=P, smooth=40, outline=False)
    obj("inside", bm_box(W - 0.32, D - 0.32, 0.3), inner, loc=(0, 0, H - 0.2), parent=P, bevel=0.03, outline=False)
    # the two trays, swung up and out on chrome arms
    Wt, Dt, Ht, wall = 1.28, 1.3, 0.4, 0.08
    for sx in (-1, 1):
        cx, cz = sx * 1.32, H + 0.42
        T = P @ _xf((cx, 0, cz), (0, sx * 6, 0))
        obj("tray", bm_box(Wt, Dt, wall), white, loc=(0, 0, wall / 2), parent=T, bevel=0.03)
        for y in (-Dt / 2 + wall / 2, Dt / 2 - wall / 2):
            obj("traywall", bm_box(Wt, wall, Ht), white, loc=(0, y, Ht / 2), parent=T, bevel=0.03)
        for x in (-Wt / 2 + wall / 2, Wt / 2 - wall / 2):
            obj("traywall", bm_box(wall, Dt - 0.02, Ht), white, loc=(x, 0, Ht / 2), parent=T, bevel=0.03)
        obj("traydiv", bm_box(wall * 0.7, Dt - 0.1, Ht * 0.75), green2, loc=(0, 0, Ht * 0.375), parent=T, bevel=0.02)
        obj("trayfloor", bm_box(Wt - 0.16, Dt - 0.16, 0.04), inner, loc=(0, 0, wall + 0.01), parent=T, outline=False)
        # a few things in the tray: bolts, a nut, a screwdriver handle
        for (x, y, c) in ((-0.3, -0.25, ch), (-0.25, 0.2, ch), (0.28, -0.2, yellow), (0.3, 0.22, red)):
            obj("bit", bm_cyl(0.1, 0.16, 6 if c is ch else 16), c, loc=(x, y, wall + 0.1), parent=T, smooth=0 if c is ch else 40)
        # the arms: from the body's top edge up to the tray
        for y in (-Dt / 2 - 0.06, Dt / 2 + 0.06):
            p0 = P @ Vector((sx * 0.45, y, H - 0.15))
            p1 = T @ Vector((-sx * 0.25, y, 0.05))
            _bar(p0, p1, 0.045, ch, "arm")
            p2 = P @ Vector((sx * 0.95, y, H - 0.15))
            p3 = T @ Vector((sx * 0.3, y, 0.05))
            _bar(p2, p3, 0.045, ch, "arm")
    obj("light", bm_box(W - 0.5, D - 0.42, 0.26), glow(R.CRATE_LOOK["suburbs"]["glow"], 2.4), loc=(0, 0, H - 0.03), parent=P, bevel=0.06, outline=False)
    R.CRATE_O.append(P @ Vector((0, 0, H + 0.15)))
    burst_hammer(P, hammer, H, POSE)
    return P


def downtown_pod(loc=(0, 0, 0), rot=(0, 0, 0), s=1.0, hammer="sapphire"):
    P = _xf(loc, rot, s)
    W, D, H = 2.7, 1.8, 1.1
    navy = pbr("zc_navy", "#2c3c72", metal=0.75, rough=0.28, coat=0.6, tex="brushed", axis="X", dark="#223064", light="#3d548f", emit=0.16)
    steel = pbr("zc_steel", "#a3aecb", metal=0.9, rough=0.22, coat=0.5, emit=0.18)
    cyan = glow("#46eaff", 3.0)
    inner = candy("#0c1430", rough=0.6, coat=0.1, emit=0.04)
    ch = chrome()
    obj("pod", bm_box(W, D, H), navy, loc=(0, 0, H / 2), parent=P, bevel=0.3, segs=5)
    obj("band", bm_box(W + 0.04, D + 0.04, 0.16), steel, loc=(0, 0, H - 0.1), parent=P, bevel=0.07)
    # light strips: one along the front, two up the front, one along the right side
    obj("strip", bm_box(W - 0.9, 0.05, 0.09), cyan, loc=(0, -D / 2 - 0.005, 0.26), parent=P, outline=False)
    for x in (-W / 2 + 0.45, W / 2 - 0.45):
        obj("strip", bm_box(0.09, 0.05, H - 0.55), cyan, loc=(x, -D / 2 - 0.005, H / 2 - 0.05), parent=P, outline=False)
    obj("strip", bm_box(0.05, D - 0.9, 0.09), cyan, loc=(W / 2 + 0.005, 0, 0.26), parent=P, outline=False)
    # the badge on the front: a steel hexagon, a ring of light and a little skyline
    hexp = [(math.cos(math.radians(30 + 60 * i)) * 0.42, math.sin(math.radians(30 + 60 * i)) * 0.42) for i in range(6)]
    obj("badge", _front_poly(hexp, 0.1), steel, loc=(0, -D / 2 - 0.04, H * 0.5), parent=P, bevel=0.03)
    hexi = [(x * 0.72, z * 0.72) for x, z in hexp]
    obj("badgein", _front_poly(hexi, 0.06), inner, loc=(0, -D / 2 - 0.09, H * 0.5), parent=P, bevel=0.01, outline=False)
    ring = torus(0.29, 0.035, cyan, outline=False)
    ring.matrix_world = P @ _xf((0, -D / 2 - 0.12, H * 0.5), (90, 0, 0)) @ ring.matrix_world
    for (x, h) in ((-0.12, 0.2), (-0.04, 0.34), (0.05, 0.26), (0.13, 0.16)):
        obj("tower", bm_box(0.07, 0.04, h), cyan, loc=(x, -D / 2 - 0.13, H * 0.5 - 0.17 + h / 2), parent=P, outline=False)
    for x in (-W / 2 + 0.35, W / 2 - 0.35):
        for y in (-D / 2 + 0.35, D / 2 - 0.35):
            obj("foot", bm_box(0.36, 0.36, 0.12), steel, loc=(x, y, -0.02), parent=P, bevel=0.04)
    obj("inside", bm_box(W - 0.4, D - 0.4, 0.3), inner, loc=(0, 0, H - 0.2), parent=P, bevel=0.03, outline=False)
    # the top: two halves slid apart sideways on chrome rails, a line of light along their inner edges
    Hl = 0.42
    for sx in (-1, 1):
        T = P @ _xf((sx * (W / 4 + 0.62), 0, H + 0.24), (0, sx * 14, 0))
        obj("half", bm_box(W / 2, D, Hl), navy, loc=(0, 0, Hl / 2), parent=T, bevel=0.2, segs=4)
        obj("halfband", bm_box(W / 2 + 0.04, D + 0.04, 0.1), steel, loc=(0, 0, 0.05), parent=T, bevel=0.04)
        obj("halfedge", bm_box(0.06, D - 0.5, 0.08), cyan, loc=(-sx * (W / 4 - 0.02), 0, Hl * 0.55), parent=T, outline=False)
        for y in (-D / 2 + 0.3, D / 2 - 0.3):
            p0 = P @ Vector((sx * 0.55, y, H - 0.05))
            p1 = T @ Vector((sx * 0.25, y, 0.02))
            _bar(p0, p1, 0.06, ch, "rail")
    obj("light", bm_box(W - 0.55, D - 0.55, 0.26), glow(R.CRATE_LOOK["downtown"]["glow"], 2.6), loc=(0, 0, H - 0.03), parent=P, bevel=0.06, outline=False)
    R.CRATE_O.append(P @ Vector((0, 0, H + 0.15)))
    burst_hammer(P, hammer, H, POSE)
    return P


def i_crate_town():
    track(town_crate, rot=(0, 0, 22))


def i_crate_suburbs():
    track(suburbs_box, rot=(0, 0, 18))


def i_crate_downtown():
    track(downtown_pod, rot=(0, 0, 22))


R.ICONS["crate_town"] = i_crate_town
R.ICONS["crate_suburbs"] = i_crate_suburbs
R.ICONS["crate_downtown"] = i_crate_downtown


# ---------------------------------------------------------------------------------------------------------------
# the paid crates, each its own object too, cooler the rarer they are
#   builder    a blue steel job-site box: ribs, a hazard band, a blueprint under the lid on a gas strut, a hard hat
#   golden     a royal treasure chest: gold, red velvet, gems, a crown clasp, coins spilling out
#   exclusive  an arcane crystal reliquary: a hexagonal altar, crystal petals opened like a flower, orbiting rings
# ---------------------------------------------------------------------------------------------------------------
def builder_box(loc=(0, 0, 0), rot=(0, 0, 0), s=1.0, hammer="gold"):
    P = _xf(loc, rot, s)
    W, D, H = 2.8, 1.6, 1.2
    blue = pbr("zc_jobblue", "#2f7cf6", metal=0.55, rough=0.28, coat=0.7, emit=0.2)
    blue2 = pbr("zc_jobblue2", "#1f5fd0", metal=0.55, rough=0.3, coat=0.6, emit=0.16)
    yel = candy("#ffc534", rough=0.3, emit=0.22)
    blk = candy("#22232c", rough=0.4, coat=0.4, emit=0.04)
    inner = candy("#0f2a66", rough=0.6, coat=0.1, emit=0.04)
    ch = chrome()
    obj("job", bm_box(W, D, H), blue, loc=(0, 0, H / 2), parent=P, bevel=0.07)
    # ribs on the front and the side
    for x in (-1.0, -0.5, 0.5, 1.0):
        obj("rib", bm_box(0.12, 0.08, H - 0.3), blue2, loc=(x, -D / 2 - 0.03, H / 2 + 0.05), parent=P, bevel=0.03)
    for y in (-0.4, 0.4):
        obj("rib", bm_box(0.08, 0.12, H - 0.3), blue2, loc=(-W / 2 - 0.03, y, H / 2 + 0.05), parent=P, bevel=0.03)
    # the hazard band: yellow with black slashes
    bw, bh, bz = W - 0.3, 0.3, 0.3
    obj("hazard", bm_box(bw, 0.06, bh), yel, loc=(0, -D / 2 - 0.08, bz), parent=P, bevel=0.02)
    x = -bw / 2 + 0.08
    while x + 0.3 < bw / 2:
        obj("slash", _front_poly([(x, -bh / 2 + 0.02), (x + 0.13, -bh / 2 + 0.02), (x + 0.3, bh / 2 - 0.02), (x + 0.17, bh / 2 - 0.02)], 0.03), blk,
            loc=(0, -D / 2 - 0.115, bz), parent=P, bevel=0.0, outline=False)
        x += 0.34
    # chrome corner guards, skids, the rim
    for sx in (-1, 1):
        for sy in (-1, 1):
            obj("guard", bm_box(0.24, 0.24, H + 0.06), ch, loc=(sx * (W / 2 - 0.06), sy * (D / 2 - 0.06), H / 2), parent=P, bevel=0.05)
    for y in (-D / 2 + 0.3, D / 2 - 0.3):
        obj("skid", bm_box(W + 0.1, 0.22, 0.14), blk, loc=(0, y, -0.05), parent=P, bevel=0.04)
    obj("inside", bm_box(W - 0.3, D - 0.3, 0.3), inner, loc=(0, 0, H - 0.2), parent=P, bevel=0.03, outline=False)
    # yellow lifting handles on the ends
    for sx in (-1, 1):
        x0, x1 = sx * (W / 2 + 0.02), sx * (W / 2 + 0.26)
        pts = [P @ Vector(p) for p in ((x0, -0.38, H * 0.72), (x1, -0.38, H * 0.72), (x1, 0.38, H * 0.72), (x0, 0.38, H * 0.72))]
        obj("handle", bm_tube(pts, 0.07, ring=12), yel, smooth=60)
    # the lid, up at the back on a gas strut, a blueprint taped under it
    Lf = P @ _xf((0, D / 2, H), (-102, 0, 0))
    obj("lid", bm_box(W + 0.08, D + 0.08, 0.2), blue, loc=(0, -D / 2, 0.1), parent=Lf, bevel=0.06)
    obj("lidrim", bm_box(W + 0.12, 0.16, 0.24), ch, loc=(0, -D - 0.02, 0.1), parent=Lf, bevel=0.04)
    bp = candy("#2d6fd6", rough=0.6, coat=0.1, emit=0.25)
    wl = candy("#eaf4ff", rough=0.5, coat=0.1, emit=0.4)
    obj("blueprint", bm_box(W - 0.6, D - 0.45, 0.03), bp, loc=(0, -D / 2, -0.02), parent=Lf, outline=False)
    for k in range(4):
        obj("bpline", bm_box(W - 0.75, 0.025, 0.02), wl, loc=(0, -D / 2 - (D - 0.65) / 2 + k * (D - 0.65) / 3, -0.04), parent=Lf, outline=False)
    for k in range(5):
        obj("bpline", bm_box(0.025, D - 0.6, 0.02), wl, loc=(-(W - 0.75) / 2 + k * (W - 0.75) / 4, -D / 2, -0.04), parent=Lf, outline=False)
    hp = [(-0.35, -0.2), (0.35, -0.2), (0.35, 0.12), (0, 0.38), (-0.35, 0.12)]
    for i in range(5):
        a2, b2 = hp[i], hp[(i + 1) % 5]
        p0 = Lf @ Vector((a2[0], -D / 2 + a2[1], -0.06))
        p1 = Lf @ Vector((b2[0], -D / 2 + b2[1], -0.06))
        obj("bphouse", bm_tube([p0, p1], 0.03, ring=6), wl, smooth=60, outline=False)
    p0 = P @ Vector((W / 2 - 0.2, D / 2 - 0.55, H - 0.1))
    p1 = Lf @ Vector((W / 2 - 0.2, -0.75, -0.04))
    mid = p0.lerp(p1, 0.5)
    _bar(p0, mid, 0.075, blk, "strut")
    _bar(mid, p1, 0.04, ch, "strutrod")
    obj("light", bm_box(W - 0.45, D - 0.42, 0.26), glow(R.CRATE_LOOK["builder"]["glow"], 2.6), loc=(0, 0, H - 0.03), parent=P, bevel=0.06, outline=False)
    R.CRATE_O.append(P @ Vector((0, 0, H + 0.15)))
    burst_hammer(P, hammer, H, POSE)
    return P


def i_crate_builder_v2():
    P = track(builder_box, rot=(0, 0, 22))
    track(R.hardhat, (P @ Vector((-1.95, -1.6, 0.0))).to_tuple(), rot=(0, 0, 40), col="#ffc534", s=0.52)


def treasure_chest(loc=(0, 0, 0), rot=(0, 0, 0), s=1.0, hammer="diamond"):
    P = _xf(loc, rot, s)
    W, D, H = 2.7, 1.75, 1.3
    g, gd = R.gold(), R.gold_dark()
    velvet = pbr("zc_velvet", "#b3123a", rough=0.85, coat=0.0, emit=0.12)
    inner = candy("#5a0a1c", rough=0.7, coat=0.1, emit=0.05)
    obj("chest", bm_box(W, D, H), g, loc=(0, 0, H / 2), parent=P, bevel=0.1)
    # red velvet panels framed in dark gold on the front and the side
    for x in (-0.72, 0.72):
        obj("frame", bm_box(0.98, 0.07, 0.86), gd, loc=(x, -D / 2 - 0.02, H / 2), parent=P, bevel=0.03)
        obj("panel", bm_box(0.8, 0.08, 0.68), velvet, loc=(x, -D / 2 - 0.05, H / 2), parent=P, bevel=0.05)
        gm = R.gem(R.RED_GEM if x < 0 else R.BLUE_GEM, s=0.16)
        gm.matrix_world = P @ _xf((x, -D / 2 - 0.14, H / 2), (90, 0, 0))
    obj("frame", bm_box(0.07, D - 0.3, 0.86), gd, loc=(-W / 2 - 0.02, 0, H / 2), parent=P, bevel=0.03)
    obj("panel", bm_box(0.08, D - 0.48, 0.68), velvet, loc=(-W / 2 - 0.05, 0, H / 2), parent=P, bevel=0.05)
    # the crown clasp in the middle, a ruby in it
    crown = [(x * 1.45, z * 1.45) for x, z in ((-0.3, 0), (0.3, 0), (0.3, 0.34), (0.18, 0.2), (0.0, 0.42), (-0.18, 0.2), (-0.3, 0.34))]
    obj("crown", _front_poly(crown, 0.12), g, loc=(0, -D / 2 - 0.08, H * 0.3), parent=P, bevel=0.03)
    gm = R.gem(R.RED_GEM, s=0.15)
    gm.matrix_world = P @ _xf((0, -D / 2 - 0.17, H * 0.3 + 0.2), (90, 0, 0))
    # corner caps with balls, rims
    for sx in (-1, 1):
        for sy in (-1, 1):
            obj("cap", bm_box(0.3, 0.3, H + 0.06), gd, loc=(sx * (W / 2 - 0.08), sy * (D / 2 - 0.08), H / 2), parent=P, bevel=0.06)
            obj("ball", bm_cyl(0.13, 0.26, 24), g, loc=(sx * (W / 2 - 0.08), sy * (D / 2 - 0.08), -0.02), parent=P, smooth=40, bevel=0.06)
    for z in (0.1, H - 0.1):
        obj("rim", bm_box(W + 0.06, D + 0.06, 0.18), gd, loc=(0, 0, z), parent=P, bevel=0.05)
    obj("inside", bm_box(W - 0.3, D - 0.3, 0.3), inner, loc=(0, 0, H - 0.2), parent=P, bevel=0.03, outline=False)
    # the domed lid, open, velvet inside, gems along its band
    Lf = P @ _xf((0, D / 2, H), (-112, 0, 0))
    bm = bm_cyl(D / 2, W, 48, axis="X")
    for v in bm.verts:
        if v.co.z < 0:
            v.co.z = 0
    obj("lid", bm, g, loc=(0, -D / 2, 0), parent=Lf, smooth=30, bevel=0.04)
    obj("lidvelvet", bm_box(W - 0.2, D - 0.2, 0.05), velvet, loc=(0, -D / 2, -0.01), parent=Lf, outline=False)
    for x in (-0.86, 0.86):
        bm = bm_cyl(D / 2 + 0.04, 0.26, 48, axis="X")
        for v in bm.verts:
            if v.co.z < 0:
                v.co.z = 0
        obj("lidband", bm, gd, loc=(x, -D / 2, 0), parent=Lf, smooth=30, bevel=0.02)
    obj("lidrim", bm_box(W + 0.06, 0.22, 0.16), gd, loc=(0, -D + 0.05, 0.02), parent=Lf, bevel=0.04)
    for k, cols in enumerate((R.GREEN_GEM, R.RED_GEM, R.BLUE_GEM)):
        gm = R.gem(cols, s=0.15)
        gm.matrix_world = Lf @ _xf((-0.86 + k * 0.86, -D / 2, D / 2 + 0.06), (0, 0, 0))
    obj("light", bm_box(W - 0.4, D - 0.4, 0.26), glow(R.CRATE_LOOK["golden"]["glow"], 2.7), loc=(0, 0, H - 0.03), parent=P, bevel=0.06, outline=False)
    R.CRATE_O.append(P @ Vector((0, 0, H + 0.15)))
    burst_hammer(P, hammer, H, POSE)
    return P


def i_crate_golden_v2():
    P = track(treasure_chest, rot=(0, 0, 22))
    for (loc, rt, r) in (((-0.8, -0.35, 1.4), (62, 0, 24), 0.34), ((0.85, -0.25, 1.36), (70, 0, -30), 0.3),
                         ((1.95, -1.25, 0.4), (75, 0, -25), 0.4), ((-2.0, -1.05, 0.4), (75, 0, 25), 0.4), ((1.35, -1.55, 0.3), (82, 0, 10), 0.32)):
        track(R.coin, loc=(P @ Vector(loc)).to_tuple(), rot=(rt[0], rt[1], rt[2] + 22), r=r)
    gm = track(R.gem, R.GREEN_GEM, loc=(P @ Vector((-1.5, -1.6, 0.32))).to_tuple(), rot=(8, 0, 20), s=0.3)


def reliquary(loc=(0, 0, 0), rot=(0, 0, 0), s=1.0, hammer="prism"):
    P = _xf(loc, rot, s)
    dark = pbr("zc_arcane", "#3a1670", metal=0.6, rough=0.25, coat=0.8, emit=0.18)
    trim = pbr("zc_arcane_trim", "#ff4fc8", metal=0.4, rough=0.22, coat=0.8, emit=0.3)
    g = R.gold()
    pink = glow("#ff7be6", 3.4)
    violet = glow("#b07bff", 3.0)
    crysA = pbr("zc_crys_a", "#ff74d9", rough=0.06, coat=1.0, emit=0.55)
    crysB = pbr("zc_crys_b", "#9d6bff", rough=0.06, coat=1.0, emit=0.55)
    # the altar: two hexagonal tiers, gold edges, a hexagon of light round the top
    obj("altar", bm_cyl(1.55, 0.55, 6), dark, loc=(0, 0, 0.275), rot=(0, 0, 30), parent=P, bevel=0.06)
    obj("altarrim", bm_cyl(1.6, 0.12, 6), g, loc=(0, 0, 0.58), rot=(0, 0, 30), parent=P, bevel=0.04)
    obj("altar2", bm_cyl(1.3, 0.38, 6), dark, loc=(0, 0, 0.82), rot=(0, 0, 30), parent=P, bevel=0.05)
    obj("altar2rim", bm_cyl(1.34, 0.1, 6), trim, loc=(0, 0, 1.02), rot=(0, 0, 30), parent=P, bevel=0.03)
    hexring = torus(1.42, 0.045, pink, seg=6, ring=8, outline=False)
    hexring.matrix_world = P @ _xf((0, 0, 0.3), (0, 0, 30)) @ hexring.matrix_world
    # runes: little glowing bars on the front faces of the altar
    for k in range(6):
        a = math.radians(30 + 60 * k)
        if math.sin(a) > 0.2:
            continue
        c = Vector((math.cos(a) * 1.36, math.sin(a) * 1.36, 0.3))
        for j, (dz, h) in enumerate(((-0.08, 0.16), (0.02, 0.3), (-0.05, 0.2))):
            off = Vector((-math.sin(a), math.cos(a), 0)) * (j - 1) * 0.16
            obj("rune", bm_box(0.06, 0.04, h), violet if j == 1 else pink, loc=(c + off + Vector((0, 0, dz))).to_tuple(), rot=(0, 0, math.degrees(a) + 90), parent=P, outline=False)
    H = 1.07
    obj("well", bm_cyl(0.95, 0.12, 48), glow("#ffd8f6", 2.8), loc=(0, 0, H), parent=P, smooth=40, outline=False)
    # crystal petals opened round the light
    for k in range(6):
        a = 60 * k + 15
        ar = math.radians(a)
        pts = []
        for i in range(6):
            t = math.radians(60 * i)
            pts.append((math.cos(t) * 0.2, math.sin(t) * 0.2, 0))
            pts.append((math.cos(t) * 0.24, math.sin(t) * 0.24, 0.85))
        pts.append((0, 0, 1.25))
        bm = bm_hull([Vector(p) for p in pts])
        tilt = 34 + (k % 2) * 8
        obj("petal", bm, crysA if k % 2 == 0 else crysB, loc=(math.cos(ar) * 1.0, math.sin(ar) * 1.0, H - 0.05), rot=(tilt, 0, a + 90), parent=P, bevel=0.0)
    # two rings of light orbiting the hammer
    r1 = torus(1.75, 0.05, pink, outline=False)
    r1.matrix_world = P @ _xf((0, 0, 2.6), (68, 0, 25)) @ r1.matrix_world
    r2 = torus(1.95, 0.04, violet, outline=False)
    r2.matrix_world = P @ _xf((0, 0, 2.3), (72, 0, -40)) @ r2.matrix_world
    R.CRATE_O.append(P @ Vector((0, 0, H + 0.15)))
    burst_hammer(P, hammer, H + 0.25, POSE)
    return P


def i_crate_exclusive_v2():
    P = track(reliquary, rot=(0, 0, 22))
    for cols, loc, sc in ((R.PINK_GEM, (-1.85, -0.9, 2.2), 0.3), (R.PURPLE_GEM, (1.9, -0.7, 2.7), 0.26), (R.BLUE_GEM, (1.75, -1.35, 0.45), 0.34), (R.PINK_GEM, (-1.7, -1.35, 0.4), 0.3)):
        track(R.gem, cols, loc=(P @ Vector(loc)).to_tuple(), rot=(10, 0, 20), s=sc)


R.ICONS["crate_builder"] = i_crate_builder_v2
R.ICONS["crate_golden"] = i_crate_golden_v2
R.ICONS["crate_exclusive"] = i_crate_exclusive_v2
