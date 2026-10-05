"""BlockRise Empire - premium icon pass.

Re-uses the scene builders from icons.py, but swaps in:
  * soft, glossy "candy" materials (Principled + clear coat) instead of hard toon steps
  * warm key light, cool fill, back rim light, warm ambient -> cozy, rounded volume
  * puffier geometry (bigger, smoother bevels with weighted normals)
  * redesigned weak icons (faceted star, stopwatch, treasure chest, mega tower + crane, tile menu)
The 2D finish (thick outer outline, drop shadow, sparkles) is done in post.py.

Usage: python3 icons2.py OUTDIR [name ...]
"""
import bpy, bmesh, math, sys, os
from mathutils import Vector
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import icons as I

RES = 384
I.OUTLINE = 0.034
I.INK = "#1d1830"

# --------------------------------------------------------------------------------- materials
_mats = {}
def mat(hexcol, gloss=0.35, emit=0.62, metal=False):
    key = (hexcol, round(gloss, 2), metal)
    if key in _mats:
        return _mats[key]
    m = bpy.data.materials.new("p" + hexcol)
    m.use_nodes = True
    nt = m.node_tree
    nt.nodes.clear()
    col = (*I.rgb(hexcol), 1)
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    p = nt.nodes.new("ShaderNodeBsdfPrincipled")
    p.inputs["Base Color"].default_value = col
    p.inputs["Roughness"].default_value = 0.42 - 0.35 * gloss - (0.08 if metal else 0)
    p.inputs["Specular IOR Level"].default_value = 0.55
    p.inputs["Coat Weight"].default_value = 0.55 if (metal or gloss >= 0.45) else 0.3
    p.inputs["Coat Roughness"].default_value = 0.08
    # a little self light so shadows stay coloured (cartoon shadows are never black)
    p.inputs["Emission Color"].default_value = col
    p.inputs["Emission Strength"].default_value = 0.16
    nt.links.new(p.outputs[0], out.inputs[0])
    _mats[key] = m
    return m

def reset():
    global _mats
    bpy.ops.wm.read_factory_settings(use_empty=True)
    _mats = {}
    I._mats, I._outline_mat = {}, None
    scn = bpy.context.scene
    scn.render.engine = "CYCLES"
    scn.cycles.device = "CPU"
    scn.cycles.samples = 40
    scn.cycles.use_denoising = True
    scn.cycles.max_bounces = 5
    scn.cycles.transparent_max_bounces = 32
    scn.render.resolution_x = scn.render.resolution_y = RES
    scn.render.film_transparent = True
    scn.view_settings.view_transform = "Standard"
    scn.view_settings.look = "None"
    scn.view_settings.exposure = 0.0
    w = bpy.data.worlds.new("w")
    scn.world = w
    w.use_nodes = True
    bg = w.node_tree.nodes["Background"]
    bg.inputs[0].default_value = (*I.rgb("#fff0e6"), 1)   # warm ambient
    bg.inputs[1].default_value = 0.55

    def sun(direction, energy, color, angle):
        bpy.ops.object.light_add(type="SUN")
        s = bpy.context.object
        s.rotation_euler = Vector(direction).to_track_quat("-Z", "Y").to_euler()
        s.data.energy = energy
        s.data.color = I.rgb(color)
        s.data.angle = math.radians(angle)
        return s
    # direction = where the light travels
    sun((0.45, 0.6, -0.66), 3.4, "#fff2dc", 22)      # key: warm, top-left-front, soft shadows
    sun((-0.7, 0.35, -0.25), 0.9, "#cfdcff", 30)     # fill: cool, from the right
    rim = sun((-0.25, -0.9, -0.35), 3.2, "#ffffff", 6)  # rim: from behind, top-right edge glint

I.mat = mat
I.reset = reset

def puff():
    """Rounder, softer shapes: bigger bevels, more segments, smooth shading with weighted normals."""
    for ob in bpy.context.scene.objects:
        if ob.type != "MESH" or ob.get("keep_flat"):
            continue
        bev = [m for m in ob.modifiers if m.type == "BEVEL"]
        for b in bev:
            b.width = b.width * 1.55
            b.segments = 5
            b.use_clamp_overlap = True
            b.harden_normals = False
        if bev:
            for p in ob.data.polygons:
                p.use_smooth = True
            if not any(m.type == "WEIGHTED_NORMAL" for m in ob.modifiers):
                wn = ob.modifiers.new("wn", "WEIGHTED_NORMAL")
                wn.keep_sharp = True

# --------------------------------------------------------------------------------- new / redesigned icons
GOLD, GOLD2 = I.GOLD, I.GOLD2

def star3d(r1=1.0, r2=0.48, depth=0.42, loc=(0, 0, 0), rot=(0, 0, 0), color=GOLD, n=5):
    """Classic faceted game star: ridges run from a raised centre to every point."""
    bm = bmesh.new()
    pts = I.star_points(r1, r2, n)
    ring = [bm.verts.new((x, 0, z)) for x, z in pts]
    front = bm.verts.new((0, -depth, 0))
    back = bm.verts.new((0, depth * 0.6, 0))
    m = len(ring)
    for i in range(m):
        j = (i + 1) % m
        bm.faces.new((front, ring[i], ring[j]))
        bm.faces.new((back, ring[j], ring[i]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    ob = I._obj_from_bm(bm, "star", color, gloss=0.55)
    ob.location = loc
    ob.rotation_euler = [math.radians(a) for a in rot]
    b = ob.modifiers.new("bevel", "BEVEL")   # tiny bevel only: keeps the facets crisp
    b.width = 0.02
    b.segments = 2
    b.limit_method = "ANGLE"
    ob["keep_flat"] = True
    return ob

def icon_star():
    star3d(rot=(0, 0, 0), color=GOLD)

def icon_level():
    star3d(color=GOLD)

def icon_rebirth_star():
    star3d(color=I.PURPLE)

def icon_more():
    cols = (I.BLUE, I.GREEN, I.ORANGE, I.PINK)
    for i, c in enumerate(cols):
        x = -0.55 if i % 2 == 0 else 0.55
        z = 0.55 if i < 2 else -0.55
        I.box((0.9, 0.36, 0.9), loc=(x, 0, z), color=c, bevel=0.16, gloss=0.5)

def icon_timer():
    # stopwatch
    I.cyl(1.0, 0.42, rot=(90, 0, 0), color=I.ORANGE, bevel=0.08, gloss=0.5)
    I.cyl(0.8, 0.46, loc=(0, -0.02, 0), rot=(90, 0, 0), color=I.PAPER, bevel=0.03)
    I.box((0.34, 0.3, 0.3), loc=(0, 0, 1.08), color=I.ORANGE, bevel=0.06)
    I.cyl(0.26, 0.22, loc=(0, 0, 1.3), rot=(90, 0, 0), color=I.RED, bevel=0.05)
    I.box((0.22, 0.24, 0.22), loc=(0.78, 0, 0.78), rot=(0, -45, 0), color=I.RED, bevel=0.05)
    for k in range(12):
        a = math.radians(90 - k * 30)
        big = k % 3 == 0
        I.box((0.07, 0.04, 0.16 if big else 0.08), loc=(math.cos(a) * 0.64, -0.25, math.sin(a) * 0.64), rot=(0, 90 - math.degrees(a), 0), color=I.DARK, bevel=0.0)
    I.box((0.09, 0.05, 0.56), loc=(0.17, -0.27, 0.22), rot=(0, 38, 0), color=I.RED, bevel=0.02)
    I.cyl(0.1, 0.1, loc=(0, -0.27, 0), rot=(90, 0, 0), color=I.DARK, bevel=0.02)

def icon_mega():
    # a big tower under construction with a tower crane
    I.building(loc=(-0.25, 0, 0), h=3.0, w=1.35, color=I.CYAN)
    I.box((1.45, 0.95, 0.5), loc=(-0.25, 0, 3.15), color=I.ORANGE, bevel=0.03)   # unfinished top floor
    Y = "#ffc21a"
    I.box((0.32, 0.32, 4.4), loc=(1.15, 0.25, 2.2), color=Y, bevel=0.05)
    I.box((3.4, 0.28, 0.28), loc=(0.15, 0.25, 4.35), color=Y, bevel=0.05)
    I.box((0.5, 0.36, 0.36), loc=(1.75, 0.25, 4.2), color=I.DARK, bevel=0.05)        # counterweight
    I.box((0.4, 0.36, 0.34), loc=(1.15, 0.0, 3.95), color="#bfe6ff", bevel=0.05)      # cab
    I.cyl(0.025, 1.0, loc=(-1.1, 0.25, 3.8), color=I.DARK, bevel=0.0)
    I.box((0.4, 0.3, 0.25), loc=(-1.1, 0.25, 3.25), color=I.RED, bevel=0.05)          # load

def icon_store():
    # treasure chest overflowing with coins and gems
    WOODC, WOODIN = "#c9783a", "#7a3f1a"
    I.box((2.0, 1.2, 1.0), loc=(0, 0, -0.35), color=WOODC, bevel=0.08)
    for sx in (-0.62, 0.62):
        I.box((0.22, 1.26, 1.04), loc=(sx, 0, -0.35), color=GOLD, bevel=0.04, metal=True)
    I.box((2.06, 1.26, 0.16), loc=(0, 0, 0.1), color=GOLD, bevel=0.04, metal=True)
    I.box((0.36, 0.1, 0.44), loc=(0, -0.64, -0.1), color=GOLD, bevel=0.05, metal=True)
    I.box((0.1, 0.06, 0.16), loc=(0, -0.7, -0.14), color=I.DARK, bevel=0.0)
    # open lid: we see its dark inside, framed in gold
    I.box((2.0, 0.22, 1.0), loc=(0, 0.62, 0.72), rot=(-12, 0, 0), color=WOODIN, bevel=0.06)
    I.box((2.08, 0.18, 0.16), loc=(0, 0.6, 1.2), rot=(-12, 0, 0), color=GOLD, bevel=0.04, metal=True)
    for sx in (-0.62, 0.62):
        I.box((0.22, 0.26, 1.04), loc=(sx, 0.6, 0.72), rot=(-12, 0, 0), color=GOLD, bevel=0.04, metal=True)
    # treasure pile
    I.sphere(0.98, loc=(0, -0.05, 0.14), scale=(1.0, 0.6, 0.45), color=GOLD, gloss=0.55)
    I.coin(loc=(-0.55, -0.42, 0.40), rot=(84, 0, 14), r=0.36)
    I.coin(loc=(0.6, -0.4, 0.36), rot=(86, 0, -12), r=0.32)
    I.gem(loc=(0.02, -0.3, 0.62), s=0.42, color=I.CYAN, rot=(-14, 0, 24))
    I.gem(loc=(-0.6, -0.05, 0.66), s=0.26, color=I.PINK, rot=(-10, 0, -20))

def icon_rebirth():
    P = I.PURPLE
    R, r = 0.9, 0.21
    I.arc_tube(R, r, 25, 150, color=P)
    I.arc_tube(R, r, 205, 330, color=P)
    for a_end in (150, 330):
        a = math.radians(a_end)
        c = (math.cos(a) * R, math.sin(a) * R)
        n = (math.cos(a), math.sin(a))
        t = (-math.sin(a), math.cos(a))
        tip = (c[0] + t[0] * 0.55, c[1] + t[1] * 0.55)
        p1 = (c[0] + n[0] * 0.46, c[1] + n[1] * 0.46)
        p2 = (c[0] - n[0] * 0.46, c[1] - n[1] * 0.46)
        I.poly([p1, tip, p2], 0.42, color=P, bevel=0.07)
    star3d(0.46, 0.22, 0.22, color=GOLD)

def icon_gift():
    # seen from a corner, a bit from above: two sides + the ribbon cross on the lid
    PK, PK2 = I.PINK, "#ff86cf"
    objs = [I.box((1.6, 1.6, 1.2), loc=(0, 0, -0.3), color=PK, bevel=0.06),
            I.box((1.78, 1.78, 0.4), loc=(0, 0, 0.42), color=PK2, bevel=0.07),
            I.box((0.32, 1.66, 1.24), loc=(0, 0, -0.3), color=GOLD, bevel=0.03, gloss=0.5),
            I.box((1.66, 0.32, 1.24), loc=(0, 0, -0.3), color=GOLD, bevel=0.03, gloss=0.5),
            I.box((0.34, 1.84, 0.44), loc=(0, 0, 0.42), color=GOLD, bevel=0.03, gloss=0.5),
            I.box((1.84, 0.34, 0.44), loc=(0, 0, 0.42), color=GOLD, bevel=0.03, gloss=0.5)]
    I.group(objs, rot=(0, 0, 40))
    # the bow stays turned to the camera
    I.torus(0.38, 0.14, loc=(-0.36, 0, 0.9), rot=(90, 0, 28), color=GOLD, gloss=0.5)
    I.torus(0.38, 0.14, loc=(0.36, 0, 0.9), rot=(90, 0, -28), color=GOLD, gloss=0.5)
    I.sphere(0.22, loc=(0, -0.06, 0.74), color="#ffc21a", gloss=0.5)

def _deg_euler_to(d):
    """Euler angles (degrees) that turn +Z onto direction d."""
    q = Vector((0, 0, 1)).rotation_difference(Vector(d).normalized())
    e = q.to_euler()
    return (math.degrees(e.x), math.degrees(e.y), math.degrees(e.z))

def icon_quest():
    # archery target with an arrow right in the bullseye, seen a little from the side
    WOODC = "#b8743c"
    objs = []
    for i, (r, col) in enumerate(((1.0, I.RED), (0.77, I.WHITE), (0.54, I.RED), (0.3, GOLD))):
        objs.append(I.cyl(r, 0.24 + i * 0.05, rot=(90, 0, 0), color=col, bevel=0.03, gloss=0.45))
    objs.append(I.torus(1.0, 0.09, rot=(90, 0, 0), color=WOODC))
    # wooden stand behind the board
    objs.append(I.box((0.16, 0.16, 1.5), loc=(-0.45, 0.35, -0.75), rot=(0, 12, 0), color=WOODC, bevel=0.04))
    objs.append(I.box((0.16, 0.16, 1.5), loc=(0.45, 0.35, -0.75), rot=(0, -12, 0), color=WOODC, bevel=0.04))
    # the arrow, built along +Z then aimed out of the bullseye
    arrow = [I.cyl(0.065, 1.7, loc=(0, 0, 0.85), color="#f2e4c8", bevel=0.0),
             I.cyl(0.09, 0.14, loc=(0, 0, 1.74), color=I.DARK, bevel=0.02)]
    for k in range(3):
        phi = math.radians(90 + 120 * k)
        arrow.append(I.box((0.3, 0.035, 0.5), loc=(math.cos(phi) * 0.17, math.sin(phi) * 0.17, 1.42), rot=(0, 0, math.degrees(phi)), color=I.RED if k else I.ORANGE, bevel=0.015))
    objs.append(I.group(arrow, loc=(0, 0.05, 0), rot=_deg_euler_to((0.42, -0.72, 0.5))))
    I.group(objs, rot=(0, 0, 32))

def gear_wheel(r, teeth, depth, color, loc=(0, 0, 0)):
    objs = [I.cyl(r, depth, rot=(90, 0, 0), color=color, bevel=0.07, gloss=0.45)]
    tw = 2 * math.pi * r / teeth * 0.5
    for i in range(teeth):
        a = 360 * i / teeth
        ar = math.radians(a)
        objs.append(I.box((r * 0.36, depth * 0.96, tw), loc=(math.cos(ar) * (r + r * 0.1), 0, math.sin(ar) * (r + r * 0.1)), rot=(0, -a, 0), color=color, bevel=0.06, gloss=0.45))
    objs.append(I.cyl(r * 0.5, depth + 0.06, rot=(90, 0, 0), color="#ffffff", bevel=0.04, gloss=0.5))
    objs.append(I.cyl(r * 0.26, depth + 0.12, rot=(90, 0, 0), color=I.DARK, bevel=0.03))
    return I.group(objs, loc=loc)

def icon_settings():
    big = gear_wheel(0.82, 9, 0.42, "#8ea4c8", loc=(-0.3, 0, 0.28))
    small = gear_wheel(0.46, 7, 0.36, I.ORANGE, loc=(0.78, -0.12, -0.62))
    small.rotation_euler.y = math.radians(14)
    I.group([big, small], rot=(0, 0, -26))

def icon_locations():
    # a little island with a big map pin on it
    I.cyl(1.2, 0.3, loc=(0, 0, -0.15), color=I.GREEN, bevel=0.1, gloss=0.3)
    I.cyl(0.75, 0.55, loc=(0, 0, -0.55), r2=1.18, color="#a8683a", bevel=0.06)
    I.cyl(0.32, 0.03, loc=(0.05, -0.15, 0.01), color="#2f9a45", bevel=0.0)
    for x, y in ((-0.5, -0.55), (-0.15, -0.75), (0.25, -0.9)):
        I.cyl(0.11, 0.04, loc=(x, y, 0.02), color="#f1d9a8", bevel=0.01)
    t = I.tree(loc=(-0.72, 0.35, 0), s=0.85)
    t2 = I.tree(loc=(0.75, 0.45, 0), s=0.6)
    pin = [I.sphere(0.7, loc=(0, 0, 0.6), color=I.RED, gloss=0.5),
           I.cyl(0.62, 1.0, loc=(0, 0, -0.1), rot=(180, 0, 0), color=I.RED, r2=0.0, bevel=0.0, verts=40),
           I.sphere(0.3, loc=(0, -0.6, 0.66), scale=(1, 0.7, 1), color=I.WHITE, gloss=0.5)]
    I.group(pin, loc=(0.05, -0.2, 0.5), scale=0.82)

def icon_portfolio():
    # gold trophy: your buildings & achievements
    PURP = "#6a4bd6"
    I.box((1.4, 1.0, 0.38), loc=(0, 0, -0.62), color=PURP, bevel=0.08)
    I.box((1.05, 0.78, 0.2), loc=(0, 0, -0.34), color=PURP, bevel=0.06)
    I.box((0.62, 0.06, 0.2), loc=(0, -0.51, -0.62), color=GOLD, bevel=0.03, metal=True)
    I.cyl(0.13, 0.5, loc=(0, 0, 0.0), color=GOLD, bevel=0.03, metal=True)
    I.sphere(0.2, loc=(0, 0, 0.08), color=GOLD, gloss=0.55)
    I.cyl(0.32, 0.12, loc=(0, 0, -0.2), color=GOLD, bevel=0.04, metal=True)
    I.cyl(0.42, 1.05, loc=(0, 0, 0.72), r2=0.9, color=GOLD, bevel=0.1, metal=True)
    I.torus(0.9, 0.08, loc=(0, 0, 1.24), color=GOLD, gloss=0.55)
    I.cyl(0.84, 0.04, loc=(0, 0, 1.22), color="#d8901a", bevel=0.0)
    I.arc_tube(0.34, 0.09, 80, 280, loc=(-0.8, 0, 0.82), color=GOLD)
    I.arc_tube(0.34, 0.09, -100, 100, loc=(0.8, 0, 0.82), color=GOLD)
    star3d(0.3, 0.14, 0.12, loc=(0, -0.66, 0.78), rot=(-8, 0, 0), color="#fff6c8")

def icon_up_luck():
    # four-leaf clover: four puffy hearts meeting in the middle, with a curly stem
    G1 = "#43d05c"
    sc = 0.026
    for i in range(4):
        ang = math.radians(45 + 90 * i)
        u = (math.cos(ang), math.sin(ang))      # leaf axis (from the centre outwards)
        v = (math.sin(ang), -math.cos(ang))     # across the leaf
        pts = []
        for k in range(48):
            t = 2 * math.pi * k / 48
            x = 16 * math.sin(t) ** 3 * sc
            z = (13 * math.cos(t) - 5 * math.cos(2 * t) - 2 * math.cos(3 * t) - math.cos(4 * t)) * sc
            z = z + 17 * sc + 0.06            # heart tip just off the centre
            pts.append((x * v[0] + z * u[0], x * v[1] + z * u[1]))
        I.poly(pts, 0.26, color=G1, bevel=0.09, gloss=0.45)
    I.sphere(0.16, loc=(0, -0.1, 0), scale=(1, 0.6, 1), color="#2fae48", gloss=0.4)
    I.arc_tube(0.9, 0.085, 185, 255, loc=(0.9, 0.06, -0.1), color="#2fa346")

TURN = {"store": (0, 34), "cash": (0, 22), "board": (0, 24), "site": (0, 26), "garage": (0, 28), "gym": (0, 20), "trade": (0, 30), "upgrades": (0, 32), "up_luck": (-10, 26), "rebirth": (0, 26),
        "up_power": (0, 22), "up_strength": (0, 22), "codes": (0, 26), "invite": (0, 26)}

def turn(n):
    """Turn the finished model so we see it from the side (3/4 view) instead of flat on."""
    if n not in TURN:
        return
    rx, rz = TURN[n]
    tops = [o for o in bpy.context.scene.objects if o.parent is None and o.type in ("MESH", "EMPTY")]
    e = bpy.data.objects.new("turn", None)
    bpy.context.collection.objects.link(e)
    for o in tops:
        o.parent = e
    e.rotation_euler = (math.radians(rx), 0, math.radians(rz))
    bpy.context.view_layer.update()

def up_arrow(loc, s=1.0):
    pts = [(-0.3, -0.5), (0.3, -0.5), (0.3, 0.05), (0.6, 0.05), (0, 0.65), (-0.6, 0.05), (-0.3, 0.05)]
    return I.poly([(x * s, z * s) for x, z in pts], 0.3 * s, loc=loc, color=I.GREEN, bevel=0.05, gloss=0.5)

def icon_cars():
    # chunky cartoon sports car, front three-quarter view
    RED, GLASS = "#ff4a4a", "#9fe0ff"
    objs = [I.box((2.5, 1.24, 0.52), loc=(0, 0, 0.55), color=RED, bevel=0.2, gloss=0.55)]
    cab = [(-0.85, 0.74), (0.55, 0.74), (0.18, 1.22), (-0.62, 1.22)]
    objs.append(I.poly(cab, 1.0, color=RED, bevel=0.1, gloss=0.55))
    objs.append(I.poly([(x * 0.94, 0.74 + (z - 0.74) * 0.86) for x, z in cab], 1.06, color=GLASS, bevel=0.05, gloss=0.7))
    objs.append(I.box((0.72, 1.02, 0.09), loc=(-0.24, 0, 1.2), color=RED, bevel=0.04, gloss=0.55))
    objs.append(I.box((2.2, 0.26, 0.04), loc=(0.05, 0, 0.82), color="#ffffff", bevel=0.01))
    for sy in (-0.38, 0.38):
        objs.append(I.sphere(0.14, loc=(1.24, sy, 0.62), scale=(0.5, 1, 0.8), color="#fff6a8", gloss=0.6))
    objs.append(I.box((0.06, 0.62, 0.16), loc=(1.26, 0, 0.42), color=I.DARK, bevel=0.03))
    objs.append(I.box((0.34, 1.22, 0.09), loc=(-1.2, 0, 1.02), color=I.DARK, bevel=0.04))
    for sy in (-0.4, 0.4):
        objs.append(I.box((0.08, 0.08, 0.2), loc=(-1.18, sy, 0.86), color=I.DARK, bevel=0.0))
    for sx in (-0.78, 0.8):
        for sy in (-0.62, 0.62):
            objs.append(I.cyl(0.38, 0.32, loc=(sx, sy, 0.34), rot=(90, 0, 0), color="#2c2f3d", bevel=0.08))
            objs.append(I.cyl(0.22, 0.34, loc=(sx, sy, 0.34), rot=(90, 0, 0), color="#ffd23a", bevel=0.04, gloss=0.55))
            objs.append(I.cyl(0.08, 0.36, loc=(sx, sy, 0.34), rot=(90, 0, 0), color=I.DARK, bevel=0.02))
    I.group(objs, rot=(0, 0, -32))

def icon_garage():
    # BlockRise Motors: a garage with the door half up and a car peeking out
    WALL, ROOF = "#8fa4cf", I.RED
    I.box((2.2, 1.5, 1.5), loc=(0, 0.2, 0.75), color=WALL, bevel=0.08)
    I.poly([(-1.3, 1.45), (1.3, 1.45), (0, 2.15)], 1.7, loc=(0, 0.2, 0), color=ROOF, bevel=0.08)
    I.box((1.6, 0.1, 1.25), loc=(0, -0.56, 0.62), color="#2b2f45", bevel=0.02)
    for k in range(4):
        I.box((1.62, 0.12, 0.13), loc=(0, -0.6, 1.16 - k * 0.15), color="#eef1f8", bevel=0.03)
    # car front
    I.box((1.3, 0.7, 0.42), loc=(0, -0.55, 0.36), color="#ff4a4a", bevel=0.16, gloss=0.55)
    for sx in (-0.4, 0.4):
        I.sphere(0.12, loc=(sx, -0.9, 0.42), scale=(1, 0.5, 0.8), color="#fff6a8", gloss=0.6)
        I.cyl(0.2, 0.2, loc=(sx * 1.45, -0.62, 0.14), rot=(0, 90, 0), color="#2c2f3d", bevel=0.05)

def icon_board():
    # the Job Board: a wooden notice board with pinned job papers
    WOODC, CORK = "#a86434", "#e0aa6a"
    I.box((0.18, 0.18, 2.4), loc=(-1.0, 0.1, 0.2), color=WOODC, bevel=0.05)
    I.box((0.18, 0.18, 2.4), loc=(1.0, 0.1, 0.2), color=WOODC, bevel=0.05)
    I.box((2.3, 0.2, 1.45), loc=(0, 0, 0.72), color=WOODC, bevel=0.06)
    I.box((2.0, 0.22, 1.18), loc=(0, -0.02, 0.72), color=CORK, bevel=0.03)
    I.poly([(-1.35, 1.45), (1.35, 1.45), (0, 1.95)], 0.5, loc=(0, 0.05, 0), color=I.RED, bevel=0.06)
    papers = [((-0.55, 0.92), 4, I.PAPER), ((0.05, 0.98), -5, "#fff2a8"), ((0.62, 0.84), 6, "#cfe8ff"), ((-0.3, 0.42), -3, "#ffd6e8"), ((0.4, 0.4), 4, I.PAPER)]
    for (x, z), r, col in papers:
        I.box((0.5, 0.05, 0.42), loc=(x, -0.15, z), rot=(0, r, 0), color=col, bevel=0.02)
        I.box((0.32, 0.04, 0.04), loc=(x, -0.18, z - 0.04), rot=(0, r, 0), color="#9aa3b8", bevel=0.0)
        I.sphere(0.06, loc=(x, -0.2, z + 0.15), color=I.RED, gloss=0.6)

def icon_site():
    # a brick wall going up, with a traffic cone
    BR, BR2 = "#e8794a", "#d4643a"
    for row in range(3):
        n = 4 if row < 2 else 2
        off = 0.0 if row % 2 == 0 else 0.3
        for k in range(n):
            I.box((0.56, 0.5, 0.3), loc=(-0.9 + off + k * 0.6, 0.15, 0.15 + row * 0.33), color=BR if (k + row) % 2 == 0 else BR2, bevel=0.04)
    I.box((2.4, 0.9, 0.12), loc=(0, 0.1, -0.06), color="#b9a58a", bevel=0.04)
    c = I.cone_icon(loc=(0.75, -0.45, 0.0), s=0.55)

def icon_gym():
    # kettlebell
    KB = "#ff6a3d"
    I.sphere(0.85, loc=(0, 0, 0), scale=(1, 1, 0.9), color=KB, gloss=0.5)
    I.cyl(0.55, 0.18, loc=(0, 0, -0.76), color=KB, bevel=0.06)
    I.arc_tube(0.58, 0.18, -8, 188, loc=(0, 0, 0.62), color="#3c4256")
    I.cyl(0.42, 0.06, loc=(0, -0.83, 0.05), rot=(90, 0, 0), color="#ffd23a", bevel=0.02, gloss=0.5)
    I.text("10", 0.42, 0.03, loc=(0, -0.87, 0.04), rot=(90, 0, 0), color="#8a3b12")

def plus_badge(loc, s=1.0):
    I.box((0.62 * s, 0.26 * s, 0.22 * s), loc=loc, color=I.GREEN, bevel=0.05)
    I.box((0.22 * s, 0.26 * s, 0.62 * s), loc=loc, color=I.GREEN, bevel=0.05)

def icon_hire():
    I.hardhat(loc=(-0.2, 0.2, 0.15), rot=(16, 0, 22))
    plus_badge((0.95, -1.3, -0.45), 1.6)

def icon_up_crew():
    I.hardhat(loc=(-0.2, 0.2, 0.15), rot=(16, 0, 22))
    up_arrow((1.0, -1.3, -0.5), 1.25)

def coin_stack(n, loc=(0, 0, 0), r=0.9):
    for i in range(n):
        I.cyl(r, 0.24, loc=(loc[0] + (0.03 if i % 2 else -0.03), loc[1], loc[2] + i * 0.25), color=GOLD if i % 2 == 0 else "#ffd94a", gloss=0.5, bevel=0.06, metal=True)
    I.cyl(r * 0.78, 0.26, loc=(loc[0], loc[1], loc[2] + (n - 1) * 0.25 + 0.01), color="#ffe27a", gloss=0.55, bevel=0.03, metal=True)

def icon_coins():
    coin_stack(4, loc=(-0.25, 0.25, -0.35))
    I.coin(loc=(0.8, -0.75, 0.0), rot=(78, 0, -22), r=0.68)

def icon_up_cash():
    coin_stack(4, loc=(-0.25, 0.25, -0.35))
    up_arrow((1.0, -0.8, -0.35))

def icon_cash():
    # a fat bundle of banknotes with a paper band, and a coin in front
    G1, G2 = "#5bcf6a", "#9ff0a2"
    for i in range(5):
        I.box((2.0, 1.1, 0.12), loc=(0.02 * (i % 2), 0.02 * ((i + 1) % 2), -0.3 + i * 0.13), color=G1 if i % 2 == 0 else "#4fbf5e", bevel=0.03)
    I.box((1.5, 0.75, 0.02), loc=(0, 0, 0.29), color=G2, bevel=0.0)
    t = I.text("$", 0.55, 0.03, loc=(0, 0, 0.31), rot=(0, 0, 0), color="#2f9a45")
    I.box((0.42, 1.16, 0.7), loc=(-0.45, 0, -0.03), color="#ffd23a", bevel=0.03, gloss=0.45)
    I.coin(loc=(0.75, -0.75, -0.1), rot=(78, 0, -20), r=0.55)

def icon_gem():
    brilliant()

def brilliant(loc=(0, 0, 0), rot=(6, 0, 11), s=1.0):
    """Brilliant-cut gem: table, crown facets, girdle and pavilion, each with its own tint."""
    bm = bmesh.new()
    TOP, GT, GB, CUL = 0.5, 0.14, 0.04, -1.05
    table = [bm.verts.new((math.cos(2 * math.pi * i / 8 + math.pi / 8) * 0.56 * s, math.sin(2 * math.pi * i / 8 + math.pi / 8) * 0.56 * s, TOP * s)) for i in range(8)]
    gt = [bm.verts.new((math.cos(2 * math.pi * k / 16 + math.pi / 8) * 1.0 * s, math.sin(2 * math.pi * k / 16 + math.pi / 8) * 1.0 * s, GT * s)) for k in range(16)]
    gb = [bm.verts.new((v.co.x, v.co.y, GB * s)) for v in gt]
    mid = [bm.verts.new((math.cos(2 * math.pi * k / 8 + math.pi / 8 + math.pi / 8) * 0.52 * s, math.sin(2 * math.pi * k / 8 + math.pi / 8 + math.pi / 8) * 0.52 * s, -0.5 * s)) for k in range(8)]
    culet = bm.verts.new((0, 0, CUL * s))
    faces = []
    f = bm.faces.new(table); faces.append((f, 0))
    for i in range(8):
        t0, t1 = table[i], table[(i + 1) % 8]
        g0, g1, g2 = gt[2 * i], gt[2 * i + 1], gt[(2 * i + 2) % 16]
        faces.append((bm.faces.new((t0, g0, g1)), 1))
        faces.append((bm.faces.new((t0, g1, t1)), 2))
        faces.append((bm.faces.new((t1, g1, g2)), 1))
    for k in range(16):
        faces.append((bm.faces.new((gt[k], gb[k], gb[(k + 1) % 16], gt[(k + 1) % 16])), 3))
    for i in range(8):
        a, b, c3 = gb[2 * i], gb[2 * i + 1], gb[(2 * i + 2) % 16]
        m = mid[i]
        faces.append((bm.faces.new((a, m, b)), 4))
        faces.append((bm.faces.new((b, m, c3)), 5))
        faces.append((bm.faces.new((a, culet, m)), 5 if i % 2 else 4))
        faces.append((bm.faces.new((m, culet, c3)), 4 if i % 2 else 5))
    for fc, mi in faces:
        fc.material_index = mi
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    me = bpy.data.meshes.new("gem")
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new("gem", me)
    bpy.context.collection.objects.link(ob)
    for col in ("#a8f2ff", "#47d3ff", "#22b2ff", "#1595f0", "#1667ff", "#2a8cff"):
        m = mat(col, gloss=0.75)
        m.node_tree.nodes["Principled BSDF"].inputs["Emission Strength"].default_value = 0.42 if col not in ("#1667ff", "#2a8cff") else 0.7
        ob.data.materials.append(m)
    ob.location = loc
    ob.rotation_euler = [math.radians(a) for a in rot]
    ob["keep_flat"] = True
    return ob

def icon_invite():
    # envelope with a wax heart seal
    I.box((1.9, 0.24, 1.3), color=I.WHITE, bevel=0.08)
    I.poly([(-0.92, 0.62), (0.92, 0.62), (0, -0.12)], 0.12, loc=(0, -0.15, 0), color="#dfe3ef", bevel=0.04)
    I.poly([(-0.92, -0.62), (-0.1, 0.02), (-0.92, 0.5)], 0.06, loc=(0, -0.13, 0), color="#eef0f7", bevel=0.02)
    I.poly([(0.92, -0.62), (0.1, 0.02), (0.92, 0.5)], 0.06, loc=(0, -0.13, 0), color="#eef0f7", bevel=0.02)
    heart = []
    for k in range(40):
        t = 2 * math.pi * k / 40
        heart.append((16 * math.sin(t) ** 3 * 0.017, (13 * math.cos(t) - 5 * math.cos(2 * t) - 2 * math.cos(3 * t) - math.cos(4 * t)) * 0.017))
    I.poly(heart, 0.16, loc=(0, -0.26, -0.06), color=I.RED, bevel=0.05, gloss=0.55)

def icon_crew():
    I.hardhat(rot=(16, 0, 22))


for name, fn in list(globals().items()):
    if name.startswith("icon_") and callable(fn):
        I.ICONS[name[5:]] = fn
I.icon_star = icon_star

def frame_and_render(path, view=(0, -1, 0.42), margin=1.12):
    scn = bpy.context.scene
    scn.render.resolution_x = scn.render.resolution_y = RES
    I.frame_and_render(path, view=view, margin=margin)

VIEWS = {"gift": (0, -1, 0.8), "cash": (0, -1, 0.85), "gem": (0, -1, 0.42), "coins": (0, -1, 0.45), "up_cash": (0, -1, 0.45), "board": (0, -1, 0.3), "settings": (0, -1, 0.55), "locations": (0, -1, 0.42), "quest": (0, -1, 0.3), "portfolio": (0, -1, 0.38)}

if __name__ == "__main__":
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
    out = args[0]
    names = args[1:] or sorted(I.ICONS)
    os.makedirs(out, exist_ok=True)
    for n in names:
        reset()
        I.ICONS[n]()
        turn(n)
        puff()
        I.add_outlines()
        frame_and_render(os.path.join(out, n + ".png"), view=VIEWS.get(n, (0, -1, 0.42)))
        print("rendered", n, flush=True)
