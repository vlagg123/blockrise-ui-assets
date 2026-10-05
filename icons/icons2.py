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

def icon_crew():
    I.hardhat(rot=(16, 0, 22))

def icon_hire():
    icon_crew()

def icon_up_crew():
    icon_crew()

for name, fn in list(globals().items()):
    if name.startswith("icon_") and callable(fn):
        I.ICONS[name[5:]] = fn
I.icon_star = icon_star

def frame_and_render(path, view=(0, -1, 0.42), margin=1.12):
    scn = bpy.context.scene
    scn.render.resolution_x = scn.render.resolution_y = RES
    I.frame_and_render(path, view=view, margin=margin)

if __name__ == "__main__":
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
    out = args[0]
    names = args[1:] or sorted(I.ICONS)
    os.makedirs(out, exist_ok=True)
    for n in names:
        reset()
        I.ICONS[n]()
        puff()
        I.add_outlines()
        frame_and_render(os.path.join(out, n + ".png"))
        print("rendered", n, flush=True)
