"""Render a Roblox part dump (JSON from dump.lua) with Blender (bpy, Cycles CPU) so the scene can be looked at
without a Studio screenshot.  usage: python3 render.py dump.json out.png --cam x,y,z --look x,y,z [--w 960 --h 540]
Coordinates in the dump are Roblox (Y up); converted here to Blender (Z up): (x, y, z) -> (x, -z, y)."""
import bpy, json, math, sys, argparse
from mathutils import Matrix, Vector

ap = argparse.ArgumentParser()
ap.add_argument("dump"); ap.add_argument("out")
ap.add_argument("--cam", default="0,120,-260"); ap.add_argument("--look", default="0,10,0")
ap.add_argument("--w", type=int, default=960); ap.add_argument("--h", type=int, default=540)
ap.add_argument("--samples", type=int, default=24); ap.add_argument("--lens", type=float, default=32)
ap.add_argument("--night", action="store_true"); ap.add_argument("--ground", default="0.36,0.62,0.27")
args = ap.parse_args(sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:])

T = Matrix(((1, 0, 0), (0, 0, -1), (0, 1, 0)))
def v(x, y, z): return Vector((x, -z, y))

bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
scene.render.engine = "CYCLES"
scene.cycles.device = "CPU"
scene.cycles.samples = args.samples
scene.cycles.use_denoising = True
scene.render.resolution_x, scene.render.resolution_y = args.w, args.h
scene.view_settings.view_transform = "AgX" if "AgX" in [i.identifier for i in scene.view_settings.bl_rna.properties["view_transform"].enum_items] else "Filmic"

world = bpy.data.worlds.new("W"); scene.world = world
world.use_nodes = True
bg = world.node_tree.nodes["Background"]
bg.inputs[0].default_value = (0.02, 0.03, 0.06, 1) if args.night else (0.55, 0.72, 0.95, 1)
bg.inputs[1].default_value = 0.15 if args.night else 1.0

mats = {}
def mat(r, g, b, kind, transp):
    key = (round(r, 3), round(g, 3), round(b, 3), kind, round(transp, 2))
    if key in mats: return mats[key]
    m = bpy.data.materials.new("m%d" % len(mats)); m.use_nodes = True
    bsdf = m.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = (r, g, b, 1)
    rough = {"Metal": 0.3, "Glass": 0.05, "Marble": 0.25, "Neon": 0.5, "Foil": 0.15, "SmoothPlastic": 0.45}.get(kind, 0.8)
    bsdf.inputs["Roughness"].default_value = rough
    if kind in ("Metal", "Foil", "DiamondPlate"): bsdf.inputs["Metallic"].default_value = 0.85
    if kind == "Neon":
        bsdf.inputs["Emission Color"].default_value = (r, g, b, 1); bsdf.inputs["Emission Strength"].default_value = 4.0
    if kind == "Glass" or transp > 0.01:
        bsdf.inputs["Alpha"].default_value = max(0.05, 1 - transp)
        m.blend_method = "BLEND" if hasattr(m, "blend_method") else None
    mats[key] = m
    return m

def srgb_to_lin(c): return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4

# primitive meshes (unit size), reused
def unit_cube():
    me = bpy.data.meshes.new("cube")
    vs = [(x, y, z) for x in (-.5, .5) for y in (-.5, .5) for z in (-.5, .5)]
    fs = [(0, 1, 3, 2), (4, 6, 7, 5), (0, 4, 5, 1), (2, 3, 7, 6), (0, 2, 6, 4), (1, 5, 7, 3)]
    me.from_pydata(vs, [], fs); me.update(); return me
def unit_wedge():
    # Roblox wedge in its own frame (x right, y up, z back): bottom full, vertical face at +z, slope from front-bottom to back-top
    me = bpy.data.meshes.new("wedge")
    rb = [(-.5, -.5, -.5), (.5, -.5, -.5), (-.5, -.5, .5), (.5, -.5, .5), (-.5, .5, .5), (.5, .5, .5)]
    vs = [tuple(T @ Vector(p)) for p in rb]
    fs = [(0, 1, 3, 2), (2, 3, 5, 4), (0, 4, 5, 1), (0, 2, 4), (1, 5, 3)]
    me.from_pydata(vs, [], fs); me.update(); return me
def unit_cyl():
    bpy.ops.mesh.primitive_cylinder_add(vertices=24, radius=0.5, depth=1)
    o = bpy.context.active_object; me = o.data; bpy.data.objects.remove(o); return me
def unit_ball():
    bpy.ops.mesh.primitive_uv_sphere_add(segments=20, ring_count=12, radius=0.5)
    o = bpy.context.active_object; me = o.data; bpy.data.objects.remove(o); return me
CUBE, WEDGE, CYL, BALL = unit_cube(), unit_wedge(), unit_cyl(), unit_ball()
for me in (CUBE, WEDGE, CYL, BALL): me.materials.append(None)
for me in (CUBE, WEDGE, CYL, BALL): me.polygons.foreach_set("use_smooth", [me is CYL or me is BALL] * len(me.polygons))

data = json.load(open(args.dump))
for p in data["parts"]:
    shape, sx, sy, sz, px, py, pz = p[0], *p[1:7]
    r = p[7:16]
    R = Matrix(((r[0], r[1], r[2]), (r[3], r[4], r[5]), (r[6], r[7], r[8])))
    col = [srgb_to_lin(c) for c in p[16:19]]
    kind, transp = p[19], p[20]
    if transp >= 0.98: continue
    Rb = T @ R @ T.inverted()
    if shape == "Cylinder":
        me = CYL; d = min(sy, sz)
        A = Matrix(((0, 0, 1), (0, 1, 0), (-1, 0, 0)))  # blender cylinder axis Z -> X (roblox cylinders run along X)
        M3 = Rb @ A @ Matrix.Diagonal((d, d, sx))
    elif shape == "Ball":
        me = BALL; d = min(sx, sy, sz); M3 = Rb @ Matrix.Diagonal((d, d, d))
    elif shape == "Wedge":
        me = WEDGE; M3 = Rb @ T @ Matrix.Diagonal((sx, sy, sz)) @ T.inverted()
    else:
        me = CUBE; M3 = Rb @ T @ Matrix.Diagonal((sx, sy, sz)) @ T.inverted()
    ob = bpy.data.objects.new("p", me)
    ob.matrix_world = Matrix.Translation(v(px, py, pz)) @ M3.to_4x4()
    scene.collection.objects.link(ob)
    ob.material_slots[0].link = "OBJECT"
    ob.material_slots[0].material = mat(*col, kind, transp)

# ground
g = [float(c) for c in args.ground.split(",")]
lk = [float(x) for x in args.look.split(",")]
bpy.ops.mesh.primitive_plane_add(size=6000, location=(lk[0], -lk[2], -0.02))
gp = bpy.context.active_object; gp.active_material = mat(*g, "Grass", 0)

# sun
sun = bpy.data.objects.new("sun", bpy.data.lights.new("sun", "SUN"))
sun.data.energy = 0.3 if args.night else 3.2; sun.rotation_euler = (math.radians(38), math.radians(12), math.radians(35))
scene.collection.objects.link(sun)

cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam")); cam.data.lens = args.lens; cam.data.clip_end = 6000
c = [float(x) for x in args.cam.split(",")]; l = [float(x) for x in args.look.split(",")]
cam.location = v(*c)
d = v(*l) - v(*c)
cam.rotation_euler = d.to_track_quat("-Z", "Y").to_euler()
scene.collection.objects.link(cam); scene.camera = cam
scene.render.filepath = args.out
bpy.ops.render.render(write_still=True)
print("rendered", args.out, len(data["parts"]), "parts")
