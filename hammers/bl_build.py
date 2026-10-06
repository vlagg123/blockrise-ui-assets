"""BlockRise Empire - hammer icons, rendered in the live Blender (scene "BlockRise Icons", same studio lights, Poly Haven
HDRI and 2D finish as the rest of the icon set). Geometry comes from hammers/spec.json (the same spec the in-game
Roblox hammers are built from): every piece is a box / cylinder / ball / ring, cut by planes and closed as a convex hull.
Materials are real PBR: transmissive gems with high IOR, brushed metals, procedural rust / wood / rock, emissive neon,
and a galaxy image inside the last hammer."""
import bpy, bmesh, json, math, os, urllib.request
import numpy as np
from mathutils import Vector, Matrix
import icons as I
import icons3 as I3
import postnp

SRC = "https://raw.githubusercontent.com/vlagg123/blockrise-ui-assets/main/hammers/spec.json"
OUT = os.path.join(I3.OUT, "hammers")
GALAXY = os.path.join(I3.OUT, "galaxy.png")

# spec space (Y up, -Z = striking face, X sideways) -> Blender (Z up, the head across the picture, X sideways = depth)
Q = Matrix(((0, 0, 1), (1, 0, 0), (0, 1, 0)))


def load_spec(url=SRC):
    return json.loads(urllib.request.urlopen(url, timeout=30).read().decode("utf-8"))


# ------------------------------------------------------------------------------------------- materials
_M = {}


def _noise_ramp(nt, scale, detail, c1, c2, pos=(0.35, 0.65), kind="noise"):
    tc = nt.nodes.new("ShaderNodeTexCoord")
    if kind == "wave":
        n = nt.nodes.new("ShaderNodeTexWave")
        n.inputs["Scale"].default_value = scale
        n.inputs["Distortion"].default_value = 6
        n.inputs["Detail"].default_value = detail
        n.bands_direction = "Z"
    else:
        n = nt.nodes.new("ShaderNodeTexNoise")
        n.inputs["Scale"].default_value = scale
        n.inputs["Detail"].default_value = detail
        n.inputs["Roughness"].default_value = 0.62
    nt.links.new(tc.outputs["Object"], n.inputs["Vector"])
    r = nt.nodes.new("ShaderNodeValToRGB")
    r.color_ramp.elements[0].position, r.color_ramp.elements[1].position = pos
    r.color_ramp.elements[0].color = (*c1, 1)
    r.color_ramp.elements[1].color = (*c2, 1)
    nt.links.new(n.outputs["Fac"] if "Fac" in n.outputs else n.outputs[0], r.inputs["Fac"])
    return r, n


def material(key, pal):
    if key in _M:
        return _M[key]
    b = pal[key]["bl"]
    m = bpy.data.materials.new("hm_" + key)
    m.use_nodes = True
    nt = m.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    p = nt.nodes.new("ShaderNodeBsdfPrincipled")
    col = tuple(b["color"])
    metal = b.get("metal", 0)
    p.inputs["Base Color"].default_value = (*col, 1)
    p.inputs["Metallic"].default_value = metal
    p.inputs["Roughness"].default_value = b.get("rough", 0.4)
    p.inputs["Coat Weight"].default_value = 0.25 if metal >= 0.5 else 0.45
    p.inputs["Coat Roughness"].default_value = 0.05
    tr = b.get("trans", 0)
    if tr:
        p.inputs["Transmission Weight"].default_value = tr
        p.inputs["IOR"].default_value = b.get("ior", 1.5)
        p.inputs["Coat Weight"].default_value = 0.6
    em = b.get("emit", 0)
    p.inputs["Emission Color"].default_value = (*col, 1)
    # a little self light keeps cartoon shadows coloured, neon parts glow for real
    p.inputs["Emission Strength"].default_value = em if em else (0.06 if metal >= 0.5 else 0.12)
    if b.get("flat"):
        # a hole in the world (Void, Black Hole): no gloss, no light of its own, pure black
        p.inputs["Coat Weight"].default_value = 0.0
        p.inputs["Emission Strength"].default_value = 0.0
        p.inputs["Specular IOR Level"].default_value = 0.0
    if b.get("alpha"):
        p.inputs["Alpha"].default_value = b["alpha"]
    tex = b.get("tex")
    c = np.array(col)
    if tex == "rust":
        # ugly on purpose: dark crusty brown, bright orange rust, and a few patches of bare grey metal
        r, _ = _noise_ramp(nt, 7, 10, (0.07, 0.03, 0.012), (0.55, 0.2, 0.05), (0.25, 0.5))
        el = r.color_ramp.elements
        e1 = el.new(0.66); e1.color = (0.78, 0.36, 0.08, 1)
        e2 = el.new(0.82); e2.color = (0.22, 0.21, 0.2, 1)
        nt.links.new(r.outputs["Color"], p.inputs["Base Color"])
        nt.links.new(r.outputs["Color"], p.inputs["Emission Color"])
        r2, _ = _noise_ramp(nt, 24, 4, (0.75, 0.75, 0.75), (1, 1, 1), (0.4, 0.6))
        nt.links.new(r2.outputs["Color"], p.inputs["Roughness"])
    elif tex == "wood":
        r, _ = _noise_ramp(nt, 3.0, 3, tuple(c * 0.7), tuple(np.minimum(c * 1.35, 1)), (0.2, 0.85), kind="wave")
        nt.links.new(r.outputs["Color"], p.inputs["Base Color"])
    elif tex == "rock":
        r, _ = _noise_ramp(nt, 6, 10, tuple(c * 0.5), tuple(np.minimum(c * 2.2, 1)), (0.35, 0.7))
        nt.links.new(r.outputs["Color"], p.inputs["Base Color"])
    elif tex == "plate":
        r, _ = _noise_ramp(nt, 40, 2, tuple(c * 0.8), tuple(np.minimum(c * 1.2, 1)), (0.45, 0.55))
        nt.links.new(r.outputs["Color"], p.inputs["Base Color"])
    elif tex == "galaxy" and os.path.exists(GALAXY):
        tc = nt.nodes.new("ShaderNodeTexCoord")
        mp = nt.nodes.new("ShaderNodeMapping")
        mp.inputs["Scale"].default_value = (1.6, 1.6, 1.6)
        im = nt.nodes.new("ShaderNodeTexImage")
        im.image = bpy.data.images.load(GALAXY, check_existing=True)
        im.projection = "BOX"
        im.projection_blend = 0.3
        nt.links.new(tc.outputs["Object"], mp.inputs["Vector"])
        nt.links.new(mp.outputs["Vector"], im.inputs["Vector"])
        nt.links.new(im.outputs["Color"], p.inputs["Base Color"])
        nt.links.new(im.outputs["Color"], p.inputs["Emission Color"])
        p.inputs["Emission Strength"].default_value = 1.6
    nt.links.new(p.outputs[0], out.inputs[0])
    if b.get("alpha") or tr:
        try:
            m.surface_render_method = "BLENDED" if b.get("alpha") else "DITHERED"
        except Exception:
            pass
    m["trans"] = bool(tr or b.get("alpha"))
    _M[key] = m
    return m


# ------------------------------------------------------------------------------------------- geometry
def _base(bm, shape, size, S):
    if shape == "box":
        bmesh.ops.create_cube(bm, size=1.0)
        for v in bm.verts:
            v.co = Vector((v.co.x * size[0] * S, v.co.y * size[1] * S, v.co.z * size[2] * S))
    elif shape == "cyl":
        L, r = size[0] * S, size[1] * S
        bmesh.ops.create_cone(bm, cap_ends=True, segments=48, radius1=r, radius2=r, depth=L)
        for v in bm.verts:  # cone axis Z -> the spec's local Y
            v.co = Vector((v.co.x, v.co.z, -v.co.y))
    elif shape == "ball":
        bmesh.ops.create_uvsphere(bm, u_segments=40, v_segments=20, radius=size[0] * S / 2)
    elif shape == "ring":
        t, ro, ri = size[0] * S, size[1] * S, size[2] * S
        n = 48
        rings = []
        for (r, y) in ((ro, -t / 2), (ro, t / 2), (ri, t / 2), (ri, -t / 2)):
            rings.append([bm.verts.new((math.cos(2 * math.pi * k / n) * r, y, math.sin(2 * math.pi * k / n) * r)) for k in range(n)])
        for a in range(4):
            r0, r1 = rings[a], rings[(a + 1) % 4]
            for k in range(n):
                bm.faces.new((r0[k], r0[(k + 1) % n], r1[(k + 1) % n], r1[k]))
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)


def piece_mesh(piece, S):
    bm = bmesh.new()
    _base(bm, piece["shape"], piece["size"], S)
    planes = piece["planes"]
    if planes:
        for pl in planes:
            n = Vector(pl[:3])
            co = n * (pl[3] * S)
            geom = bm.verts[:] + bm.edges[:] + bm.faces[:]
            bmesh.ops.bisect_plane(bm, geom=geom, dist=1e-6, plane_co=co, plane_no=n, clear_outer=True)
        # every cut piece is convex: rebuild it as the hull of what is left (closes the cut faces)
        bmesh.ops.remove_doubles(bm, verts=bm.verts[:], dist=1e-4)
        pts = [v.co.copy() for v in bm.verts]
        bm.free()
        bm = bmesh.new()
        for p in pts:
            bm.verts.new(p)
        ret = bmesh.ops.convex_hull(bm, input=bm.verts[:])
        kill = list({g for g in ret["geom_interior"] + ret["geom_unused"] if isinstance(g, bmesh.types.BMVert)})
        if kill:
            bmesh.ops.delete(bm, geom=kill, context="VERTS")
        bmesh.ops.dissolve_limit(bm, angle_limit=math.radians(0.5), verts=bm.verts[:], edges=bm.edges[:])
    # smooth where the spec says so (cylinders, balls), sharp facets everywhere else
    smooth = piece.get("smooth", 0) > 0 or piece["shape"] == "ball"
    lim = math.radians(piece.get("smooth", 40) or 40)
    for f in bm.faces:
        f.smooth = smooth
    if smooth:
        for e in bm.edges:
            if len(e.link_faces) == 2 and e.calc_face_angle(0) > lim:
                e.smooth = False
    me = bpy.data.meshes.new("hm_" + piece["name"])
    bm.to_mesh(me)
    bm.free()
    return me


def _shorten(h, k):
    """icons: a shorter handle (k of its length) so the head reads big in a small square; the head is untouched"""
    hy = h["head"]["center"][1] if h.get("head") else 2.0
    out = []
    for piece in h["pieces"]:
        p = dict(piece)
        y = p["pos"][1]
        if y < hy - 0.3:
            p["pos"] = [p["pos"][0], hy - (hy - y) * k, p["pos"][2]]
            # the long parts along the handle (shaft, grip) get shorter too; rings and caps keep their size
            if p["shape"] == "cyl" and p["size"][0] > 0.25 and abs(p["R"][1][1]) > 0.99:
                p["size"] = [p["size"][0] * k, p["size"][1]]
        out.append(p)
    return out


def build(h, pal, S=1.0, pose=(0.0, -42.0, 14.0), short=0.62):
    """the hammer as Blender objects; pose = degrees about Blender X, Y (view axis), Z"""
    scn = I3.iscene()
    objs = []
    pieces = _shorten(h, short) if short and short < 1 else h["pieces"]
    for piece in pieces:
        me = piece_mesh(piece, S)
        ob = bpy.data.objects.new("hm_" + piece["name"], me)
        R = Matrix([row for row in piece["R"]])
        pos = Vector(piece["pos"]) * S
        local = Matrix.Translation(pos) @ R.to_4x4()
        ob.matrix_world = Q.to_4x4() @ local
        m = material(piece["mat"], pal)
        me.materials.append(m)
        if not m.get("trans") and piece["shape"] in ("box", "cyl"):
            bv = ob.modifiers.new("bevel", "BEVEL")
            bv.width = 0.012 * S
            bv.segments = 2
            bv.limit_method = "ANGLE"
            bv.angle_limit = math.radians(35)
        if m.get("trans"):
            ob["no_outline"] = True  # an inverted hull behind glass shows through it
        scn.collection.objects.link(ob)
        objs.append(ob)
    # pose the whole hammer for the icon (diagonal, a little turned to show depth)
    rot = (Matrix.Rotation(math.radians(pose[2]), 4, "Z") @ Matrix.Rotation(math.radians(pose[1]), 4, "Y")
           @ Matrix.Rotation(math.radians(pose[0]), 4, "X"))
    for ob in objs:
        ob.matrix_world = rot @ ob.matrix_world
    return objs


# sparkles drawn on the finished icon (fractions of the canvas) for the shiny tiers
SPARKLE = {
    "gold": [(0.8, 0.2, 0.06)], "emerald": [(0.82, 0.2, 0.07), (0.2, 0.36, 0.045)], "ruby": [(0.82, 0.2, 0.07)],
    "sapphire": [(0.84, 0.18, 0.07)], "amethyst": [(0.8, 0.16, 0.07), (0.2, 0.3, 0.05)], "diamond": [(0.84, 0.16, 0.08), (0.18, 0.32, 0.055)],
    "frost": [(0.8, 0.18, 0.06)], "plasma": [(0.84, 0.2, 0.06)], "solar": [(0.84, 0.18, 0.07)], "thunder": [(0.82, 0.16, 0.07)],
    "galaxy": [(0.84, 0.16, 0.08), (0.18, 0.3, 0.06), (0.62, 0.08, 0.04)],
}


def render(tiers=None, size=768, out_size=256, spec=None):
    spec = spec or load_spec()
    pal = spec["palette"]
    os.makedirs(OUT, exist_ok=True)
    done = []
    for h in spec["hammers"]:
        if tiers and h["tier"] not in tiers:
            continue
        I3.reset()
        _M.clear()
        build(h, pal)
        I.add_outlines()
        scn = I3.iscene()
        scn.render.resolution_x = scn.render.resolution_y = size
        scn.cycles.samples = 96
        raw = os.path.join(OUT, "raw_%s.png" % h["key"])
        I.frame_and_render(raw, view=(-0.18, -1, 0.22), margin=1.12)
        name = "hammer_" + h["key"]
        postnp.SPARKLE[name] = SPARKLE.get(h["key"], [])
        cell = postnp.finish(postnp.load(raw), name, out_size)
        postnp.save(cell, os.path.join(OUT, "%02d_%s.png" % (h["tier"], h["key"])))
        done.append(h["key"])
    I3.clear()
    return done
