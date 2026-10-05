"""BlockRise Empire - cartoon icon set, rendered with Blender (Cycles, toon shading, inverted-hull outline).

Usage: python3 icons.py OUTDIR [name ...]
Every icon is a small scene built from primitives, framed by an orthographic camera and rendered
to a transparent PNG (RES x RES). The style follows simulator games: chunky shapes, saturated colours,
thick dark outline, two-tone shading with a soft highlight.
"""
import bpy, bmesh, math, sys, os
from mathutils import Vector, Matrix, Euler

RES = 256
OUTLINE = 0.055        # outline thickness (scene units, objects are normalised to ~2 units)
INK = "#1d1830"

# --------------------------------------------------------------------------------- colours
def lin(c):
    c = c / 255.0
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4

def rgb(h):
    h = h.lstrip("#")
    return tuple(lin(int(h[i:i + 2], 16)) for i in (0, 2, 4))

_mats = {}
def mat(hexcol, gloss=0.35, emit=0.62, metal=False):
    key = (hexcol, gloss, emit, metal)
    if key in _mats:
        return _mats[key]
    m = bpy.data.materials.new("m" + hexcol)
    m.use_nodes = True
    nt = m.node_tree
    nt.nodes.clear()
    col = (*rgb(hexcol), 1)
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    toon = nt.nodes.new("ShaderNodeBsdfToon")
    toon.component = "DIFFUSE"
    toon.inputs["Color"].default_value = col
    toon.inputs["Size"].default_value = 0.78
    toon.inputs["Smooth"].default_value = 0.10
    em = nt.nodes.new("ShaderNodeEmission")
    em.inputs["Color"].default_value = col
    em.inputs["Strength"].default_value = emit
    add = nt.nodes.new("ShaderNodeAddShader")
    nt.links.new(toon.outputs[0], add.inputs[0])
    nt.links.new(em.outputs[0], add.inputs[1])
    gl = nt.nodes.new("ShaderNodeBsdfToon")
    gl.component = "GLOSSY"
    gl.inputs["Color"].default_value = (1, 1, 1, 1)
    gl.inputs["Size"].default_value = 0.10 if not metal else 0.22
    gl.inputs["Smooth"].default_value = 0.06
    mix = nt.nodes.new("ShaderNodeMixShader")
    mix.inputs["Fac"].default_value = gloss
    nt.links.new(add.outputs[0], mix.inputs[1])
    nt.links.new(gl.outputs[0], mix.inputs[2])
    nt.links.new(mix.outputs[0], out.inputs[0])
    _mats[key] = m
    return m

_outline_mat = None
def outline_mat():
    global _outline_mat
    if _outline_mat:
        return _outline_mat
    m = bpy.data.materials.new("outline")
    m.use_nodes = True
    nt = m.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    geo = nt.nodes.new("ShaderNodeNewGeometry")
    em = nt.nodes.new("ShaderNodeEmission")
    em.inputs["Color"].default_value = (*rgb(INK), 1)
    em.inputs["Strength"].default_value = 1.0
    tr = nt.nodes.new("ShaderNodeBsdfTransparent")
    mix = nt.nodes.new("ShaderNodeMixShader")
    nt.links.new(geo.outputs["Backfacing"], mix.inputs["Fac"])
    nt.links.new(em.outputs[0], mix.inputs[1])
    nt.links.new(tr.outputs[0], mix.inputs[2])
    nt.links.new(mix.outputs[0], out.inputs[0])
    _outline_mat = m
    return m

# --------------------------------------------------------------------------------- scene
def reset():
    global _mats, _outline_mat
    bpy.ops.wm.read_factory_settings(use_empty=True)
    _mats, _outline_mat = {}, None
    scn = bpy.context.scene
    scn.render.engine = "CYCLES"
    scn.cycles.device = "CPU"
    scn.cycles.samples = 28
    scn.cycles.use_denoising = True
    scn.cycles.max_bounces = 4
    scn.cycles.transparent_max_bounces = 32
    scn.render.resolution_x = scn.render.resolution_y = RES
    scn.render.film_transparent = True
    scn.view_settings.view_transform = "Standard"
    scn.view_settings.look = "None"
    w = bpy.data.worlds.new("w")
    scn.world = w
    w.use_nodes = True
    w.node_tree.nodes["Background"].inputs[1].default_value = 0.0
    # key light from the top left, a little in front
    bpy.ops.object.light_add(type="SUN")
    sun = bpy.context.object
    # light travels from the top-left-front (camera side) towards the back
    sun.rotation_euler = Vector((0.45, 0.6, -0.66)).to_track_quat("-Z", "Y").to_euler()
    sun.data.energy = 4.0
    bpy.context.object.data.angle = math.radians(8)

def _obj_from_bm(bm, name, color, gloss=0.35, metal=False, smooth=False):
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new(name, me)
    bpy.context.collection.objects.link(ob)
    ob.data.materials.append(mat(color, gloss, metal=metal))
    if smooth:
        for p in ob.data.polygons:
            p.use_smooth = True
    return ob

def _active(ob, color, gloss=0.35, metal=False, smooth=True, bevel=0.0, segs=3):
    ob.data.materials.clear()
    ob.data.materials.append(mat(color, gloss, metal=metal))
    if smooth:
        for p in ob.data.polygons:
            p.use_smooth = True
    if bevel > 0:
        b = ob.modifiers.new("bevel", "BEVEL")
        b.width = bevel
        b.segments = segs
        b.limit_method = "ANGLE"
    return ob

def box(size, loc=(0, 0, 0), rot=(0, 0, 0), color="#ffffff", bevel=0.06, gloss=0.35, metal=False):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc, rotation=[math.radians(a) for a in rot])
    ob = bpy.context.object
    ob.scale = size
    bpy.ops.object.transform_apply(scale=True)
    return _active(ob, color, gloss, metal, smooth=False, bevel=bevel, segs=3)

def cyl(r, depth, loc=(0, 0, 0), rot=(0, 0, 0), color="#ffffff", verts=48, bevel=0.04, gloss=0.35, metal=False, r2=None):
    if r2 is None:
        bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=r, depth=depth, location=loc, rotation=[math.radians(a) for a in rot])
    else:
        bpy.ops.mesh.primitive_cone_add(vertices=verts, radius1=r, radius2=r2, depth=depth, location=loc, rotation=[math.radians(a) for a in rot])
    ob = bpy.context.object
    _active(ob, color, gloss, metal, smooth=True, bevel=bevel, segs=3)
    if bevel > 0:
        ob.modifiers.new("ws", "WEIGHTED_NORMAL")
    return ob

def sphere(r, loc=(0, 0, 0), scale=(1, 1, 1), color="#ffffff", gloss=0.35, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=40, ring_count=20, radius=r, location=loc, rotation=[math.radians(a) for a in rot])
    ob = bpy.context.object
    ob.scale = scale
    bpy.ops.object.transform_apply(scale=True)
    return _active(ob, color, gloss, smooth=True)

def torus(R, r, loc=(0, 0, 0), rot=(0, 0, 0), color="#ffffff", gloss=0.35, metal=False):
    bpy.ops.mesh.primitive_torus_add(major_radius=R, minor_radius=r, major_segments=48, minor_segments=16, location=loc, rotation=[math.radians(a) for a in rot])
    ob = bpy.context.object
    return _active(ob, color, gloss, metal, smooth=True)

def poly(points, depth, loc=(0, 0, 0), rot=(0, 0, 0), color="#ffffff", bevel=0.05, gloss=0.35, metal=False):
    """Extruded 2D polygon (points in the XZ plane, facing the camera)."""
    bm = bmesh.new()
    vs = [bm.verts.new((x, 0, z)) for x, z in points]
    f = bm.faces.new(vs)
    bmesh.ops.recalc_face_normals(bm, faces=[f])
    ext = bmesh.ops.extrude_face_region(bm, geom=[f])
    nv = [e for e in ext["geom"] if isinstance(e, bmesh.types.BMVert)]
    bmesh.ops.translate(bm, verts=nv, vec=(0, depth, 0))
    bmesh.ops.translate(bm, verts=bm.verts, vec=(0, -depth / 2, 0))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    ob = _obj_from_bm(bm, "poly", color, gloss, metal)
    ob.location = loc
    ob.rotation_euler = [math.radians(a) for a in rot]
    if bevel > 0:
        b = ob.modifiers.new("bevel", "BEVEL")
        b.width = bevel
        b.segments = 3
        b.limit_method = "ANGLE"
    return ob

def text(s, size, depth, loc=(0, 0, 0), rot=(90, 0, 0), color="#ffffff", bevel=0.02):
    bpy.ops.object.text_add(location=loc, rotation=[math.radians(a) for a in rot])
    ob = bpy.context.object
    ob.data.body = s
    ob.data.size = size
    ob.data.extrude = depth
    ob.data.bevel_depth = bevel
    ob.data.align_x = "CENTER"
    ob.data.align_y = "CENTER"
    bpy.ops.object.convert(target="MESH")
    ob = bpy.context.object
    return _active(ob, color, smooth=False)

def star_points(r1, r2, n=5, rot=90):
    pts = []
    for i in range(n * 2):
        a = math.radians(rot) + i * math.pi / n
        r = r1 if i % 2 == 0 else r2
        pts.append((math.cos(a) * r, math.sin(a) * r))
    return pts

def arc_tube(R, r, a0, a1, loc=(0, 0, 0), rot=(0, 0, 0), color="#ffffff", segs=40):
    """A bent tube (part of a torus) from angle a0 to a1 (degrees), in the XZ plane."""
    bm = bmesh.new()
    rings = []
    ring_n = 14
    for i in range(segs + 1):
        a = math.radians(a0 + (a1 - a0) * i / segs)
        c = Vector((math.cos(a) * R, 0, math.sin(a) * R))
        t = Vector((-math.sin(a), 0, math.cos(a)))
        n1 = Vector((math.cos(a), 0, math.sin(a)))
        n2 = Vector((0, 1, 0))
        ring = []
        for j in range(ring_n):
            b = 2 * math.pi * j / ring_n
            ring.append(bm.verts.new(c + (n1 * math.cos(b) + n2 * math.sin(b)) * r))
        rings.append(ring)
    for i in range(segs):
        for j in range(ring_n):
            bm.faces.new((rings[i][j], rings[i][(j + 1) % ring_n], rings[i + 1][(j + 1) % ring_n], rings[i + 1][j]))
    bm.faces.new(list(reversed(rings[0])))
    bm.faces.new(rings[-1])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    ob = _obj_from_bm(bm, "arc", color, smooth=True)
    ob.location = loc
    ob.rotation_euler = [math.radians(a) for a in rot]
    return ob

def group(objs, loc=(0, 0, 0), rot=(0, 0, 0), scale=1.0):
    e = bpy.data.objects.new("grp", None)
    bpy.context.collection.objects.link(e)
    for o in objs:
        o.parent = e
    e.location = loc
    e.rotation_euler = [math.radians(a) for a in rot]
    e.scale = (scale, scale, scale)
    return e

# --------------------------------------------------------------------------------- framing + render
def add_outlines():
    """Inverted hull: a copy of every mesh (modifiers applied, world space), pushed out along the
    normals and turned inside out. Only its far side is seen, as a dark rim around the silhouette."""
    om = outline_mat()
    bpy.context.view_layer.update()
    dg = bpy.context.evaluated_depsgraph_get()
    for ob in list(bpy.context.scene.objects):
        if ob.type != "MESH" or ob.get("no_outline"):
            continue
        ev = ob.evaluated_get(dg)
        me = bpy.data.meshes.new_from_object(ev, depsgraph=dg)
        me.transform(ob.matrix_world)
        bm = bmesh.new()
        bm.from_mesh(me)
        bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-4)
        bm.normal_update()
        for v in bm.verts:
            v.co += v.normal * OUTLINE
        bmesh.ops.reverse_faces(bm, faces=bm.faces)
        bm.to_mesh(me)
        bm.free()
        me.materials.clear()
        me.materials.append(om)
        d = bpy.data.objects.new(ob.name + "_hull", me)
        d["no_outline"] = True
        # the hull is only for the camera: it must not shadow or reflect on the object
        d.visible_shadow = False
        d.visible_diffuse = False
        d.visible_glossy = False
        d.visible_transmission = False
        d.visible_volume_scatter = False
        bpy.context.collection.objects.link(d)

def frame_and_render(path, view=(0, -1, 0.42), margin=1.16):
    bpy.context.view_layer.update()
    # bounding box of everything, seen from the camera direction
    pts = []
    for ob in bpy.context.scene.objects:
        if ob.type == "MESH":
            for c in ob.bound_box:
                pts.append(ob.matrix_world @ Vector(c))
    lo = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
    hi = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
    center = (lo + hi) / 2
    d = Vector(view).normalized()   # direction from the subject towards the camera
    cam_loc = center + d * 20
    bpy.ops.object.camera_add(location=cam_loc)
    cam = bpy.context.object
    cam.data.type = "ORTHO"
    look = (center - cam_loc).normalized()
    cam.rotation_euler = look.to_track_quat("-Z", "Y").to_euler()
    bpy.context.scene.camera = cam
    bpy.context.view_layer.update()
    # projected extent on the camera plane
    inv = cam.matrix_world.inverted()
    xs, ys = [], []
    for p in pts:
        q = inv @ p
        xs.append(q.x)
        ys.append(q.y)
    w, h = max(xs) - min(xs), max(ys) - min(ys)
    cx, cy = (max(xs) + min(xs)) / 2, (max(ys) + min(ys)) / 2
    cam.location = cam.matrix_world @ Vector((cx, cy, 0))
    cam.data.ortho_scale = max(w, h) * margin + OUTLINE * 4
    bpy.context.scene.render.filepath = path
    bpy.ops.render.render(write_still=True)

# --------------------------------------------------------------------------------- palette
GOLD, GOLD2 = "#ffcf3a", "#f39a12"
ORANGE, RED, PINK = "#ff8a26", "#ff4f4a", "#ff5fb4"
CYAN, BLUE, NAVY = "#45dcff", "#3d8cff", "#2a4fbf"
PURPLE, GREEN, LIME = "#a25cff", "#43d45a", "#9df25a"
WHITE, PAPER, GRAY, DARK = "#f7f7fb", "#fffaf0", "#9aa3b8", "#454c5e"
BROWN, WOOD, STEEL = "#9a5b2c", "#d08a47", "#c9d1de"

# --------------------------------------------------------------------------------- icons
def coin(loc=(0, 0, 0), rot=(72, 0, 18), r=1.0, sign=True):
    objs = [cyl(r, 0.26, color=GOLD, gloss=0.45, bevel=0.07, metal=True)]
    objs.append(cyl(r * 0.78, 0.30, color="#ffe07a", gloss=0.5, bevel=0.03, metal=True))
    if sign:
        t = text("$", r * 1.2, 0.05, loc=(0, 0, 0.17), rot=(0, 0, 0), color=GOLD2)
        objs.append(t)
    return group(objs, loc=loc, rot=rot)

def icon_cash():
    coin(loc=(0.55, 0.2, -0.15), rot=(78, 0, -25), r=0.85)
    coin(loc=(-0.35, -0.2, 0.25), rot=(70, 0, 20), r=1.0)

def icon_coins():  # coin stack
    for i in range(4):
        cyl(0.9, 0.26, loc=(0, 0, i * 0.27), color=GOLD if i % 2 == 0 else "#ffdc5a", gloss=0.45, bevel=0.06, metal=True)
    coin(loc=(1.1, -0.3, 0.45), rot=(75, 0, -20), r=0.7)

def gem(loc=(0, 0, 0), rot=(0, 0, 0), s=1.0, color=CYAN):
    bm = bmesh.new()
    n = 8
    top = [bm.verts.new((math.cos(2 * math.pi * i / n) * 0.55 * s, math.sin(2 * math.pi * i / n) * 0.55 * s, 0.42 * s)) for i in range(n)]
    mid = [bm.verts.new((math.cos(2 * math.pi * (i + 0.5) / n) * 1.0 * s, math.sin(2 * math.pi * (i + 0.5) / n) * 1.0 * s, 0.12 * s)) for i in range(n)]
    tip = bm.verts.new((0, 0, -1.0 * s))
    bm.faces.new(top)
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new((top[i], mid[i], top[j]))
        bm.faces.new((top[j], mid[i], mid[j]))
        bm.faces.new((mid[i], tip, mid[j]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    ob = _obj_from_bm(bm, "gem", color, gloss=0.6)
    ob.location = loc
    ob.rotation_euler = [math.radians(a) for a in rot]
    return ob

def icon_gem():
    gem(rot=(-12, 0, 22))

def dumbbell(loc=(0, 0, 0), rot=(0, 0, 0), color=RED):
    objs = [cyl(0.16, 2.2, rot=(0, 90, 0), color=STEEL, gloss=0.5, metal=True, bevel=0.02)]
    for sx in (-1, 1):
        objs.append(cyl(0.62, 0.34, loc=(sx * 0.78, 0, 0), rot=(0, 90, 0), color=color, bevel=0.07))
        objs.append(cyl(0.48, 0.24, loc=(sx * 1.02, 0, 0), rot=(0, 90, 0), color=color, bevel=0.06))
    return group(objs, loc=loc, rot=rot)

def icon_strength():
    dumbbell(rot=(0, -28, -18), color=ORANGE)

def icon_star(color=GOLD):
    poly(star_points(1.0, 0.46), 0.42, rot=(0, 0, 0), color=color, bevel=0.09, gloss=0.5)

def icon_level():
    icon_star()

def icon_jobs():
    box((1.5, 0.16, 1.9), color=BROWN, bevel=0.08)
    box((1.22, 0.06, 1.55), loc=(0, -0.1, -0.08), color=PAPER, bevel=0.02)
    box((0.72, 0.2, 0.32), loc=(0, -0.12, 0.92), color=STEEL, bevel=0.06, metal=True)
    for i, w in enumerate((0.9, 0.75, 0.9, 0.6)):
        box((w, 0.05, 0.1), loc=(-0.05 - (0.9 - w) / 2, -0.15, 0.42 - i * 0.3), color="#7b8bb0", bevel=0.02)
    poly([(-0.18, 0), (-0.05, -0.15), (0.22, 0.18), (0.12, 0.26), (-0.05, 0.05), (-0.11, 0.1)], 0.08, loc=(0.45, -0.18, -0.55), color=GREEN, bevel=0.01)

def hammer(loc=(0, 0, 0), rot=(0, 0, 0), s=1.0):
    objs = [cyl(0.13 * s, 1.9 * s, loc=(0, 0, -0.25 * s), color=WOOD, bevel=0.03),
            box((1.05 * s, 0.36 * s, 0.4 * s), loc=(0, 0, 0.78 * s), color=GRAY, bevel=0.06, metal=True, gloss=0.5),
            box((0.2 * s, 0.38 * s, 0.42 * s), loc=(0.5 * s, 0, 0.78 * s), color=DARK, bevel=0.05)]
    return group(objs, loc=loc, rot=rot)

def icon_shop():
    # wrench behind, hammer in front, crossed
    group([box((0.24, 0.16, 1.7), color=STEEL, bevel=0.05, metal=True),
           cyl(0.4, 0.2, loc=(0, 0, 0.9), rot=(90, 0, 0), color=STEEL, bevel=0.04, metal=True),
           box((0.26, 0.24, 0.38), loc=(0, 0, 1.12), color="#5a6275", bevel=0.02)], loc=(0, 0.35, 0.05), rot=(0, 38, 0))
    hammer(loc=(0, -0.1, 0), rot=(0, -38, 0))

def icon_upgrades():
    poly([(-0.45, -1.0), (0.45, -1.0), (0.45, 0.05), (0.95, 0.05), (0, 1.05), (-0.95, 0.05), (-0.45, 0.05)], 0.5, color=GREEN, bevel=0.1, gloss=0.5)

def icon_rebirth():
    arc_tube(0.9, 0.2, 20, 160, color=PURPLE)
    arc_tube(0.9, 0.2, 200, 340, color=PURPLE)
    cyl(0.36, 0.5, loc=(-0.96, 0, 0.18), rot=(0, 0, 0), color=PURPLE, r2=0.0, verts=24, bevel=0.03)
    cyl(0.36, 0.5, loc=(0.96, 0, -0.18), rot=(180, 0, 0), color=PURPLE, r2=0.0, verts=24, bevel=0.03)
    icon_star_small = poly(star_points(0.42, 0.2), 0.2, loc=(0, 0, 0), color=GOLD, bevel=0.04, gloss=0.5)

def building(loc=(0, 0, 0), h=2.0, w=1.0, d=0.8, color=BLUE, windows=True, rot=(0, 0, 0)):
    objs = [box((w, d, h), loc=(0, 0, h / 2), color=color, bevel=0.05)]
    if windows:
        rows = max(2, int(h / 0.38))
        for r in range(rows):
            for cx in (-0.22, 0.22):
                objs.append(box((0.24 * w, 0.06, 0.2), loc=(cx * w * 1.6 / 1.6, -d / 2 - 0.01, 0.32 + r * (h - 0.5) / max(1, rows - 1) * 0.9), color="#bfe6ff", bevel=0.01))
    objs.append(box((w + 0.12, d + 0.12, 0.14), loc=(0, 0, h + 0.05), color=DARK, bevel=0.03))
    return group(objs, loc=loc, rot=rot)

def icon_company():
    building(loc=(-0.45, 0, 0), h=2.3, w=0.95, color=BLUE)
    building(loc=(0.55, -0.2, 0), h=1.5, w=0.9, color="#5aa6ff")

def icon_mega():
    building(loc=(0, 0, 0), h=3.2, w=1.0, color=CYAN)
    cyl(0.05, 0.6, loc=(0, 0, 3.55), color=DARK, bevel=0)
    sphere(0.12, loc=(0, 0, 3.9), color=RED)

def icon_downtown():
    building(loc=(-0.6, 0, 0), h=2.6, w=0.8, color=NAVY)
    building(loc=(0.15, -0.15, 0), h=3.3, w=0.8, color=CYAN)
    building(loc=(0.85, -0.3, 0), h=1.9, w=0.7, color=BLUE)

def pin(loc=(0, 0, 0), color=RED):
    objs = [sphere(0.7, loc=(0, 0, 0.6), color=color),
            cyl(0.62, 1.0, loc=(0, 0, -0.1), rot=(180, 0, 0), color=color, r2=0.0, bevel=0.0, verts=40),
            sphere(0.28, loc=(0, -0.55, 0.68), scale=(1, 0.4, 1), color=WHITE)]
    return group(objs, loc=loc)

def icon_locations():
    # folded map + pin
    for i, c in enumerate(("#9fe07a", "#7fcf5e", "#9fe07a")):
        box((0.62, 0.08, 1.5), loc=(-0.62 + i * 0.6, 0.15 + (i % 2) * 0.12, -0.2), rot=(0, 0, (-12 if i % 2 else 12)), color=c, bevel=0.02)
    box((0.5, 0.04, 0.12), loc=(-0.5, -0.02, 0.1), color="#4f8bff", bevel=0.01)
    pin(loc=(0.25, -0.35, 0.35), color=RED)

def icon_store():
    # shopping bag full of treasure
    arc_tube(0.42, 0.08, 10, 170, loc=(0, 0.25, 0.55), color=DARK)
    box((1.6, 1.0, 1.35), loc=(0, 0, -0.2), color=PINK, bevel=0.08)
    box((1.64, 1.04, 0.2), loc=(0, 0, 0.42), color="#ff86c8", bevel=0.05)
    coin(loc=(-0.35, -0.05, 0.62), rot=(75, 0, 18), r=0.45)
    gem(loc=(0.38, -0.1, 0.62), s=0.4, color=CYAN, rot=(-12, 0, 20))
    poly(star_points(0.32, 0.14), 0.12, loc=(0, -0.53, -0.25), color=GOLD, bevel=0.03, gloss=0.5)

def icon_daily():
    box((1.7, 0.3, 1.6), loc=(0, 0, -0.1), color=WHITE, bevel=0.08)
    box((1.7, 0.34, 0.45), loc=(0, 0, 0.62), color=RED, bevel=0.08)
    for sx in (-0.45, 0.45):
        cyl(0.09, 0.42, loc=(sx, -0.05, 0.92), color=DARK, bevel=0.02)
    poly([(-0.6, 0.0), (-0.36, 0.24), (-0.12, 0.0), (0.4, 0.52), (0.64, 0.28), (-0.12, -0.48)], 0.16, loc=(0.02, -0.2, -0.15), rot=(0, 0, 0), color=GREEN, bevel=0.04)

def icon_spin():
    cols = [RED, GOLD, GREEN, BLUE, PINK, ORANGE, CYAN, PURPLE]
    n = 8
    for i in range(n):
        a0 = 2 * math.pi * i / n
        a1 = 2 * math.pi * (i + 1) / n
        pts = [(0, 0)]
        for k in range(7):
            a = a0 + (a1 - a0) * k / 6
            pts.append((math.cos(a) * 1.0, math.sin(a) * 1.0))
        poly(pts, 0.22, color=cols[i], bevel=0.0)
    torus(1.02, 0.08, rot=(90, 0, 0), color=GOLD, gloss=0.5)
    cyl(0.2, 0.34, rot=(90, 0, 0), color=WHITE, bevel=0.03)
    poly([(-0.25, 1.35), (0.25, 1.35), (0, 0.85)], 0.3, loc=(0, -0.08, 0), color=WHITE, bevel=0.03)

def icon_gift():
    box((1.6, 1.6, 1.2), loc=(0, 0, -0.3), color=PINK, bevel=0.06)
    box((1.75, 1.75, 0.38), loc=(0, 0, 0.42), color="#ff7cc6", bevel=0.06)
    box((0.3, 1.78, 1.62), loc=(0, 0, -0.05), color=GOLD, bevel=0.02)
    box((1.78, 0.3, 1.62), loc=(0, 0, -0.05), color=GOLD, bevel=0.02)
    torus(0.32, 0.12, loc=(-0.3, 0, 0.82), rot=(90, 0, 30), color=GOLD)
    torus(0.32, 0.12, loc=(0.3, 0, 0.82), rot=(90, 0, -30), color=GOLD)

def gear(loc=(0, 0, 0), color=GRAY):
    objs = [cyl(0.8, 0.4, rot=(90, 0, 0), color=color, bevel=0.04, metal=True)]
    for i in range(8):
        a = 360 * i / 8
        objs.append(box((0.38, 0.4, 0.38), loc=(math.cos(math.radians(a)) * 0.9, 0, math.sin(math.radians(a)) * 0.9), rot=(0, -a, 0), color=color, bevel=0.03, metal=True))
    objs.append(cyl(0.3, 0.46, rot=(90, 0, 0), color=DARK, bevel=0.02))
    return group(objs, loc=loc)

def icon_more():
    for i in range(3):
        box((1.9, 0.3, 0.38), loc=(0, 0, 0.62 - i * 0.62), color=WHITE, bevel=0.15)

def icon_settings():
    gear()

def icon_trade():
    poly([(-1.0, 0.25), (0.35, 0.25), (0.35, 0.55), (1.0, 0.05), (0.35, -0.45), (0.35, -0.15), (-1.0, -0.15)], 0.4, loc=(0, 0, 0.45), color=GREEN, bevel=0.07)
    poly([(1.0, 0.25), (-0.35, 0.25), (-0.35, 0.55), (-1.0, 0.05), (-0.35, -0.45), (-0.35, -0.15), (1.0, -0.15)], 0.4, loc=(0, 0.1, -0.45), color=BLUE, bevel=0.07)

def car(loc=(0, 0, 0), rot=(0, 0, 0), color=RED):
    objs = [box((2.2, 1.1, 0.55), loc=(0, 0, 0.45), color=color, bevel=0.14),
            box((1.2, 1.0, 0.55), loc=(-0.1, 0, 0.95), color=color, bevel=0.14),
            box((1.0, 1.04, 0.36), loc=(-0.1, 0, 0.98), color="#bfe6ff", bevel=0.08)]
    for sx in (-0.68, 0.7):
        for sy in (-0.55, 0.55):
            objs.append(cyl(0.3, 0.24, loc=(sx, sy, 0.2), rot=(90, 0, 0), color=DARK, bevel=0.05))
            objs.append(cyl(0.14, 0.26, loc=(sx, sy, 0.2), rot=(90, 0, 0), color=STEEL, bevel=0.02))
    return group(objs, loc=loc, rot=rot)

def icon_cars():
    car(rot=(0, 0, -28), color=RED)

def icon_codes():
    poly([(-1.1, -0.6), (1.1, -0.6), (1.1, -0.2), (0.9, 0), (1.1, 0.2), (1.1, 0.6), (-1.1, 0.6), (-1.1, 0.2), (-0.9, 0), (-1.1, -0.2)], 0.24, rot=(0, -12, 0), color=PURPLE, bevel=0.05)
    poly(star_points(0.36, 0.16), 0.3, loc=(0, -0.05, 0), rot=(0, -12, 0), color=GOLD, bevel=0.03, gloss=0.5)

def icon_invite():
    box((1.9, 0.2, 1.3), color=WHITE, bevel=0.06)
    poly([(-0.95, 0.65), (0.95, 0.65), (0, -0.1)], 0.08, loc=(0, -0.13, 0), color="#e9e9f2", bevel=0.02)
    sphere(0.28, loc=(0, -0.2, 0.0), scale=(1, 0.5, 1), color=RED)

def icon_portfolio():
    box((1.4, 0.4, 1.8), color=BLUE, bevel=0.06)
    box((1.25, 0.34, 1.7), loc=(0.1, -0.04, 0), color=PAPER, bevel=0.02)
    box((1.4, 0.12, 1.8), loc=(0, -0.22, 0), color=BLUE, bevel=0.05)
    poly(star_points(0.34, 0.15), 0.08, loc=(0, -0.3, 0.1), color=GOLD, bevel=0.02)

def icon_music():
    sphere(0.42, loc=(-0.35, 0, -0.7), scale=(1.25, 0.6, 0.9), color=PURPLE)
    box((0.14, 0.14, 1.65), loc=(0.08, 0, 0.1), color=PURPLE, bevel=0.03)
    poly([(0.08, 0.95), (0.75, 0.55), (0.75, 0.25), (0.08, 0.6)], 0.14, color=PURPLE, bevel=0.03)

def icon_quest():
    for i, (r, c) in enumerate(((1.0, RED), (0.74, WHITE), (0.48, RED), (0.22, WHITE))):
        cyl(r, 0.22 + i * 0.06, rot=(90, 0, 0), color=c, bevel=0.03)
    g = group([cyl(0.06, 1.4, rot=(0, 90, 0), color=BROWN, bevel=0.0), cyl(0.15, 0.3, loc=(0.7, 0, 0), rot=(0, -90, 0), color=STEEL, r2=0.0, bevel=0.0)], loc=(-0.45, -0.4, 0.45), rot=(0, -35, -30))

def cone_icon(loc=(0, 0, 0), s=1.0):
    objs = [box((1.5 * s, 1.5 * s, 0.2 * s), loc=(0, 0, 0.1 * s), color=ORANGE, bevel=0.06),
            cyl(0.62 * s, 1.8 * s, loc=(0, 0, 1.08 * s), color=ORANGE, r2=0.12 * s, bevel=0.03),
            cyl(0.5 * s, 0.3 * s, loc=(0, 0, 0.75 * s), color=WHITE, r2=0.42 * s, bevel=0.0),
            cyl(0.32 * s, 0.26 * s, loc=(0, 0, 1.45 * s), color=WHITE, r2=0.25 * s, bevel=0.0)]
    return group(objs, loc=loc)

def icon_contract():
    cone_icon()

def icon_site():
    cone_icon()

def icon_timer():
    poly([(0.15, 1.0), (-0.55, -0.05), (-0.05, -0.05), (-0.25, -1.0), (0.6, 0.15), (0.08, 0.15), (0.4, 1.0)], 0.38, color=GOLD, bevel=0.06, gloss=0.5)

def house(loc=(0, 0, 0), rot=(0, 0, 0), wall=PAPER, roof=RED):
    objs = [box((1.6, 1.4, 1.1), loc=(0, 0, 0.55), color=wall, bevel=0.05)]
    roofob = poly([(-1.0, 1.1), (1.0, 1.1), (0, 2.0)], 1.6, loc=(0, 0, 0), color=roof, bevel=0.06)
    objs.append(roofob)
    objs.append(box((0.38, 0.06, 0.62), loc=(0, -0.72, 0.31), color=BROWN, bevel=0.03))
    objs.append(box((0.32, 0.06, 0.3), loc=(-0.52, -0.72, 0.62), color="#bfe6ff", bevel=0.02))
    objs.append(box((0.32, 0.06, 0.3), loc=(0.52, -0.72, 0.62), color="#bfe6ff", bevel=0.02))
    objs.append(box((0.24, 0.24, 0.5), loc=(0.5, 0.2, 1.75), color=DARK, bevel=0.03))
    return group(objs, loc=loc, rot=rot)

def icon_home():
    house(rot=(0, 0, -20))

def tree(loc=(0, 0, 0), s=1.0):
    return group([cyl(0.12 * s, 0.7 * s, loc=(0, 0, 0.35 * s), color=BROWN, bevel=0.0), sphere(0.55 * s, loc=(0, 0, 1.0 * s), color=GREEN)], loc=loc)

def icon_suburbs():
    house(loc=(-0.25, 0, 0), rot=(0, 0, -20), roof=BLUE)
    tree(loc=(1.05, 0.3, 0), s=1.1)

def hardhat(loc=(0, 0, 0), rot=(0, 0, 0), color=GOLD):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=40, ring_count=20, radius=1.0, location=(0, 0, 0))
    dome = bpy.context.object
    bm = bmesh.new()
    bm.from_mesh(dome.data)
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if v.co.z < -0.02], context="VERTS")
    bm.to_mesh(dome.data)
    bm.free()
    sol = dome.modifiers.new("s", "SOLIDIFY")
    sol.thickness = 0.12
    _active(dome, color, gloss=0.5)
    brim = cyl(1.3, 0.12, loc=(0, -0.28, 0.02), color=color, bevel=0.05, gloss=0.5)
    brim.scale = (1.0, 1.15, 1)
    ridge = arc_tube(1.05, 0.13, 25, 155, rot=(0, 0, 90), color=color)
    band = cyl(1.03, 0.16, loc=(0, 0, 0.1), color="#e8a514", bevel=0.03)
    return group([dome, brim, ridge, band], loc=loc, rot=rot)

def icon_crew():
    hardhat(rot=(-8, 0, 28))

def icon_hire():
    icon_crew()

def icon_gym():
    dumbbell(rot=(0, -28, -18), color=RED)

def icon_board():
    icon_jobs()

def icon_garage():
    icon_cars()

def icon_up_power():
    hammer(rot=(0, -32, 0))
    poly([(-0.3, -0.5), (0.3, -0.5), (0.3, 0.05), (0.6, 0.05), (0, 0.65), (-0.6, 0.05), (-0.3, 0.05)], 0.3, loc=(0.75, -0.4, -0.5), color=GREEN, bevel=0.05)

def icon_up_strength():
    dumbbell(rot=(0, -28, -18), color=ORANGE)
    poly([(-0.3, -0.5), (0.3, -0.5), (0.3, 0.05), (0.6, 0.05), (0, 0.65), (-0.6, 0.05), (-0.3, 0.05)], 0.3, loc=(0.8, -0.6, -0.55), color=GREEN, bevel=0.05)

def icon_up_cash():
    icon_coins()

def icon_up_crew():
    icon_crew()

def icon_up_rent():
    house(loc=(-0.3, 0, 0), rot=(0, 0, -20), roof=PURPLE)
    coin(loc=(0.95, -0.6, 0.4), rot=(75, 0, -20), r=0.55)

def icon_up_luck():
    for i in range(4):
        a = math.radians(45 + 90 * i)
        sphere(0.48, loc=(math.cos(a) * 0.5, 0, math.sin(a) * 0.5), scale=(1, 0.35, 1), color=GREEN)
    cyl(0.07, 0.9, loc=(0.25, 0.05, -0.75), rot=(0, 25, 0), color="#2e9e43", bevel=0.0)

def icon_rebirth_star():
    icon_star(color=PURPLE)

def icon_robux_like():
    pass

ICONS = {name[5:]: fn for name, fn in globals().items() if name.startswith("icon_") and callable(fn) and name != "icon_robux_like"}

if __name__ == "__main__":
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
    out = args[0]
    names = args[1:] or sorted(ICONS)
    os.makedirs(out, exist_ok=True)
    for n in names:
        reset()
        ICONS[n]()
        add_outlines()
        frame_and_render(os.path.join(out, n + ".png"))
        print("rendered", n, flush=True)
