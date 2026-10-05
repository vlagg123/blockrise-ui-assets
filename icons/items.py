"""BlockRise Empire - Company materials + blueprints icons (live Blender, scene "BlockRise Icons").

Same pipeline as the hammer icons (hammers/bl_build.py): real PBR materials under the studio HDRI and the three
suns of icons3.reset(), inverted-hull outline, then the 2D sticker finish (postnp: thick outline, drop shadow,
sparkles). Everything is built from bmesh primitives, so nothing depends on the user's own scenes.

    import items; items.render()            # all of them
    items.render(["steel", "bp_gold"])      # some of them
"""
import bpy, bmesh, math, os
from mathutils import Vector, Matrix
import icons as I
import icons3 as I3
import postnp

OUT = os.path.join(I3.OUT, "items")
TAU = math.tau

# ------------------------------------------------------------------------------------------- materials
_M = {}


def _node(nt, kind, **inputs):
    n = nt.nodes.new(kind)
    for k, v in inputs.items():
        n.inputs[k].default_value = v
    return n


def _ramp(nt, stops):
    r = nt.nodes.new("ShaderNodeValToRGB")
    el = r.color_ramp.elements
    el[0].position, el[0].color = stops[0][0], (*I.rgb(stops[0][1]), 1)
    el[1].position, el[1].color = stops[-1][0], (*I.rgb(stops[-1][1]), 1)
    for pos, col in stops[1:-1]:
        e = el.new(pos)
        e.color = (*I.rgb(col), 1)
    return r


def pbr(name, col, metal=0.0, rough=0.35, coat=0.3, trans=0.0, ior=1.5, emit=0.1, tex=None, aniso=0.0, **kw):
    """Principled material. tex: brushed | marble | wood | leaf | grid | hammered"""
    if name in _M:
        return _M[name]
    m = bpy.data.materials.new("it_" + name)
    m.use_nodes = True
    nt = m.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    p = nt.nodes.new("ShaderNodeBsdfPrincipled")
    c = (*I.rgb(col), 1)
    p.inputs["Base Color"].default_value = c
    p.inputs["Metallic"].default_value = metal
    p.inputs["Roughness"].default_value = rough
    p.inputs["Coat Weight"].default_value = coat
    p.inputs["Coat Roughness"].default_value = 0.04
    if trans:
        p.inputs["Transmission Weight"].default_value = trans
        p.inputs["IOR"].default_value = ior
    if aniso:
        p.inputs["Anisotropic"].default_value = aniso
    # a little self light keeps the shadows coloured (cartoon shadows are never black)
    p.inputs["Emission Color"].default_value = c
    p.inputs["Emission Strength"].default_value = emit
    tc = nt.nodes.new("ShaderNodeTexCoord")
    if tex == "brushed":
        # fine streaks along the local axis kw["axis"] (default X): stretch the noise along it
        mp = nt.nodes.new("ShaderNodeMapping")
        sc = [70.0, 70.0, 70.0]
        sc["XYZ".index(kw.get("axis", "X"))] = 1.2
        mp.inputs["Scale"].default_value = sc
        nt.links.new(tc.outputs["Object"], mp.inputs["Vector"])
        n = _node(nt, "ShaderNodeTexNoise", Scale=1.0, Detail=6.0)
        nt.links.new(mp.outputs[0], n.inputs["Vector"])
        r = _ramp(nt, [(0.3, kw.get("dark", col)), (0.7, kw.get("light", col))])
        nt.links.new(n.outputs["Fac"], r.inputs["Fac"])
        nt.links.new(r.outputs["Color"], p.inputs["Base Color"])
        rr = nt.nodes.new("ShaderNodeMapRange")
        rr.inputs["To Min"].default_value = rough * 0.6
        rr.inputs["To Max"].default_value = rough * 1.5
        nt.links.new(n.outputs["Fac"], rr.inputs["Value"])
        nt.links.new(rr.outputs[0], p.inputs["Roughness"])
    elif tex == "marble":
        # polished white stone: soft grey clouds, long flowing grey veins (distorted bands) and a few thin gold ones
        mp = nt.nodes.new("ShaderNodeMapping")
        mp.inputs["Scale"].default_value = (kw.get("scale", 1.0),) * 3
        nt.links.new(tc.outputs["Object"], mp.inputs["Vector"])
        cloud = _node(nt, "ShaderNodeTexNoise", Scale=1.1, Detail=3.0, Roughness=0.5)
        nt.links.new(mp.outputs[0], cloud.inputs["Vector"])
        base = _ramp(nt, [(0.3, "#ffffff"), (0.75, "#dcdfe6")])
        nt.links.new(cloud.outputs["Fac"], base.inputs["Fac"])

        def veins(scale, dist, w, seed_off):
            wv = nt.nodes.new("ShaderNodeTexWave")
            wv.wave_type = "BANDS"
            wv.bands_direction = "DIAGONAL"
            wv.inputs["Scale"].default_value = scale
            wv.inputs["Distortion"].default_value = dist
            wv.inputs["Detail"].default_value = 4.0
            wv.inputs["Detail Scale"].default_value = 1.4
            wv.inputs["Phase Offset"].default_value = seed_off
            nt.links.new(mp.outputs[0], wv.inputs["Vector"])
            r = nt.nodes.new("ShaderNodeValToRGB")
            e = r.color_ramp.elements
            e[0].position, e[0].color = 0.5 - w, (0, 0, 0, 1)
            e[1].position, e[1].color = 0.5 + w, (0, 0, 0, 1)
            m = e.new(0.5)
            m.color = (1, 1, 1, 1)
            nt.links.new(wv.outputs["Fac"], r.inputs["Fac"])
            return r

        def mixc(fac_node, a_out, col_b):
            mx = nt.nodes.new("ShaderNodeMix")
            mx.data_type = "RGBA"
            nt.links.new(fac_node.outputs["Color"], mx.inputs["Factor"])
            nt.links.new(a_out, mx.inputs["A"])
            mx.inputs["B"].default_value = (*I.rgb(col_b), 1)
            return mx.outputs["Result"]
        grey = mixc(veins(0.9, 10.0, 0.03, 0.0), base.outputs["Color"], "#8e97ab")
        gold = mixc(veins(0.6, 14.0, 0.012, 2.0), grey, "#e0a93c")
        nt.links.new(gold, p.inputs["Base Color"])
        nt.links.new(gold, p.inputs["Emission Color"])
    elif tex == "grain":
        # plywood face: soft straight grain bands (no rings: rings read as a target at icon size)
        w = nt.nodes.new("ShaderNodeTexWave")
        w.wave_type = "BANDS"
        w.bands_direction = "Z"
        w.inputs["Scale"].default_value = 1.3
        w.inputs["Distortion"].default_value = 3.0
        w.inputs["Detail"].default_value = 2.0
        w.inputs["Detail Scale"].default_value = 1.2
        nt.links.new(tc.outputs["Object"], w.inputs["Vector"])
        r = _ramp(nt, [(0.25, kw.get("dark", col)), (0.8, kw.get("light", col))])
        nt.links.new(w.outputs["Fac"], r.inputs["Fac"])
        nt.links.new(r.outputs["Color"], p.inputs["Base Color"])
        nt.links.new(r.outputs["Color"], p.inputs["Emission Color"])
    elif tex == "wood":
        mp = nt.nodes.new("ShaderNodeMapping")
        mp.inputs["Scale"].default_value = (1.0, 1.0, 1.0)
        nt.links.new(tc.outputs["Object"], mp.inputs["Vector"])
        w = nt.nodes.new("ShaderNodeTexWave")
        w.wave_type = "RINGS"
        w.rings_direction = kw.get("rings", "X")
        w.inputs["Scale"].default_value = 3.2
        w.inputs["Distortion"].default_value = 4.0
        w.inputs["Detail"].default_value = 3.0
        nt.links.new(mp.outputs[0], w.inputs["Vector"])
        r = _ramp(nt, [(0.2, kw.get("dark", "#8a5530")), (0.9, kw.get("light", col))])
        nt.links.new(w.outputs["Fac"], r.inputs["Fac"])
        nt.links.new(r.outputs["Color"], p.inputs["Base Color"])
        nt.links.new(r.outputs["Color"], p.inputs["Emission Color"])
    elif tex in ("leaf", "hammered"):
        # crinkled foil / hammered metal: a bump map and a little colour play
        n = _node(nt, "ShaderNodeTexNoise", Scale=kw.get("scale", 7.0), Detail=4.0, Roughness=0.55)
        nt.links.new(tc.outputs["Object"], n.inputs["Vector"])
        if tex == "leaf":
            v = nt.nodes.new("ShaderNodeTexVoronoi")
            v.inputs["Scale"].default_value = 9.0
            nt.links.new(tc.outputs["Object"], v.inputs["Vector"])
            src = v.outputs["Distance"]
        else:
            src = n.outputs["Fac"]
        b = _node(nt, "ShaderNodeBump", Strength=kw.get("bump", 0.35), Distance=0.05)
        nt.links.new(src, b.inputs["Height"])
        nt.links.new(b.outputs["Normal"], p.inputs["Normal"])
        r = _ramp(nt, [(0.3, kw.get("dark", col)), (0.7, kw.get("light", col))])
        nt.links.new(n.outputs["Fac"], r.inputs["Fac"])
        nt.links.new(r.outputs["Color"], p.inputs["Base Color"])
    elif tex == "grid":
        # blueprint paper: blue, with a fine light grid (object space, kw["k"] cells per unit)
        k = kw.get("k", 5.0)
        sep = nt.nodes.new("ShaderNodeSeparateXYZ")
        nt.links.new(tc.outputs[kw.get("coords", "Object")], sep.inputs[0])
        lines = []
        for ax in kw.get("axes", ("X", "Y")):
            mu = _node(nt, "ShaderNodeMath")
            mu.operation = "MULTIPLY"
            mu.inputs[1].default_value = k
            nt.links.new(sep.outputs[ax], mu.inputs[0])
            fr = nt.nodes.new("ShaderNodeMath")
            fr.operation = "FRACT"
            nt.links.new(mu.outputs[0], fr.inputs[0])
            lt = nt.nodes.new("ShaderNodeMath")
            lt.operation = "LESS_THAN"
            lt.inputs[1].default_value = kw.get("w", 0.07)
            nt.links.new(fr.outputs[0], lt.inputs[0])
            lines.append(lt)
        mx = nt.nodes.new("ShaderNodeMath")
        mx.operation = "MAXIMUM"
        nt.links.new(lines[0].outputs[0], mx.inputs[0])
        nt.links.new(lines[-1].outputs[0], mx.inputs[1])
        mix = nt.nodes.new("ShaderNodeMix")
        mix.data_type = "RGBA"
        nt.links.new(mx.outputs[0], mix.inputs["Factor"])
        mix.inputs["A"].default_value = c
        mix.inputs["B"].default_value = (*I.rgb(kw.get("line", "#7fb6ff")), 1)
        nt.links.new(mix.outputs["Result"], p.inputs["Base Color"])
        nt.links.new(mix.outputs["Result"], p.inputs["Emission Color"])
    nt.links.new(p.outputs[0], out.inputs[0])
    if trans:
        try:
            m.surface_render_method = "DITHERED"
        except Exception:
            pass
    m["trans"] = bool(trans)
    _M[name] = m
    return m


# ------------------------------------------------------------------------------------------- geometry
def _xf(loc=(0, 0, 0), rot=(0, 0, 0), scale=1.0):
    r = (Matrix.Rotation(math.radians(rot[2]), 4, "Z") @ Matrix.Rotation(math.radians(rot[1]), 4, "Y")
         @ Matrix.Rotation(math.radians(rot[0]), 4, "X"))
    s = scale if isinstance(scale, (tuple, list)) else (scale, scale, scale)
    return Matrix.Translation(Vector(loc)) @ r @ Matrix.Diagonal((*s, 1))


def obj(name, bm, mats, loc=(0, 0, 0), rot=(0, 0, 0), scale=1.0, smooth=0, bevel=0.0, segs=3, outline=True, parent=None):
    """bmesh -> object in the icon scene. smooth = angle (deg) under which edges are smooth, 0 = flat."""
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    if smooth:
        lim = math.radians(smooth)
        for f in bm.faces:
            f.smooth = True
        for e in bm.edges:
            if len(e.link_faces) == 2 and e.calc_face_angle(0) > lim:
                e.smooth = False
    me = bpy.data.meshes.new("it_" + name)
    bm.to_mesh(me)
    bm.free()
    for m in (mats if isinstance(mats, (list, tuple)) else [mats]):
        me.materials.append(m)
    ob = bpy.data.objects.new("it_" + name, me)
    I3.iscene().collection.objects.link(ob)
    ob.matrix_world = _xf(loc, rot, scale)
    if parent:
        ob.matrix_world = parent @ ob.matrix_world
    if bevel:
        b = ob.modifiers.new("bevel", "BEVEL")
        b.width = bevel
        b.segments = segs
        b.limit_method = "ANGLE"
        b.angle_limit = math.radians(35)
        b.harden_normals = False
    if not outline or any(m.get("trans") for m in me.materials):
        ob["no_outline"] = True
    return ob


def bm_box(sx, sy, sz):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    for v in bm.verts:
        v.co = Vector((v.co.x * sx, v.co.y * sy, v.co.z * sz))
    return bm


def bm_cyl(r, depth, segs=48, r2=None, axis="Z"):
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=segs, radius1=r, radius2=r if r2 is None else r2, depth=depth)
    _axis(bm, axis)
    return bm


def _axis(bm, axis):
    if axis == "X":
        for v in bm.verts:
            v.co = Vector((v.co.z, v.co.y, -v.co.x))
    elif axis == "Y":
        for v in bm.verts:
            v.co = Vector((v.co.x, v.co.z, -v.co.y))


def bm_prism(pts, depth, axis="Z", holes=None):
    """2D outline (x, y) extruded along axis. holes: an inner ring with as many points (makes a ring prism)."""
    bm = bmesh.new()
    if holes:
        n = len(pts)
        lay = []
        for z in (-depth / 2, depth / 2):
            lay.append(([bm.verts.new((x, y, z)) for x, y in pts], [bm.verts.new((x, y, z)) for x, y in holes]))
        (o0, i0), (o1, i1) = lay
        for k in range(n):
            k2 = (k + 1) % n
            bm.faces.new((o0[k], o0[k2], o1[k2], o1[k]))
            bm.faces.new((i0[k2], i0[k], i1[k], i1[k2]))
            bm.faces.new((o0[k2], o0[k], i0[k], i0[k2]))
            bm.faces.new((o1[k], o1[k2], i1[k2], i1[k]))
    else:
        vs = [bm.verts.new((x, y, -depth / 2)) for x, y in pts]
        f = bm.faces.new(vs)
        ext = bmesh.ops.extrude_face_region(bm, geom=[f])
        nv = [e for e in ext["geom"] if isinstance(e, bmesh.types.BMVert)]
        bmesh.ops.translate(bm, verts=nv, vec=(0, 0, depth))
    _axis(bm, axis)
    return bm


def bm_hull(points):
    bm = bmesh.new()
    for p in points:
        bm.verts.new(p)
    ret = bmesh.ops.convex_hull(bm, input=bm.verts[:])
    kill = list({g for g in ret["geom_interior"] + ret["geom_unused"] if isinstance(g, bmesh.types.BMVert)})
    if kill:
        bmesh.ops.delete(bm, geom=kill, context="VERTS")
    bmesh.ops.dissolve_limit(bm, angle_limit=math.radians(1), verts=bm.verts[:], edges=bm.edges[:])
    return bm


def bm_tube(path, r, ring=12, caps=True, bm=None):
    """A round tube along a list of points (parallel-transport frames, so long helices don't twist)."""
    bm = bm or bmesh.new()
    path = [Vector(p) for p in path]
    n = len(path)
    tan = [(path[min(i + 1, n - 1)] - path[max(i - 1, 0)]).normalized() for i in range(n)]
    up = Vector((0, 0, 1)) if abs(tan[0].z) < 0.9 else Vector((1, 0, 0))
    nrm = tan[0].cross(up).normalized()
    rings = []
    for i in range(n):
        t = tan[i]
        if i:
            ax = tan[i - 1].cross(t)
            if ax.length > 1e-9:
                nrm = Matrix.Rotation(tan[i - 1].angle(t), 3, ax.normalized()) @ nrm
        b = t.cross(nrm).normalized()
        nn = b.cross(t).normalized()
        rr = r(i / (n - 1)) if callable(r) else r
        rings.append([bm.verts.new(path[i] + (nn * math.cos(TAU * j / ring) + b * math.sin(TAU * j / ring)) * rr) for j in range(ring)])
    for i in range(n - 1):
        for j in range(ring):
            bm.faces.new((rings[i][j], rings[i][(j + 1) % ring], rings[i + 1][(j + 1) % ring], rings[i + 1][j]))
    if caps:
        bm.faces.new(list(reversed(rings[0])))
        bm.faces.new(rings[-1])
    return bm


def hexagon(R, n_side=4, rot=0.0):
    """points along a regular hexagon (corner radius R), n_side points per side, so it can be bridged to a circle"""
    pts = []
    for k in range(6 * n_side):
        a = TAU * k / (6 * n_side) + rot
        sector = (a - rot) % (TAU / 6) - TAU / 12
        rr = R * math.cos(TAU / 12) / math.cos(sector)
        pts.append((math.cos(a) * rr, math.sin(a) * rr))
    return pts


def circle(r, n, rot=0.0):
    return [(math.cos(TAU * k / n + rot) * r, math.sin(TAU * k / n + rot) * r) for k in range(n)]


# ------------------------------------------------------------------------------------------- pieces
def bolt(m_bolt, loc, rot, s=1.0):
    """hex bolt with washer and a real thread, standing on its head (local +Z = shank)"""
    P = _xf(loc, rot, s)
    obj("bolt_head", bm_prism(hexagon(0.36, 1), 0.24), m_bolt, loc=(0, 0, 0.12), parent=P, bevel=0.03)
    obj("bolt_cap", bm_cyl(0.3, 0.06, 48), m_bolt, loc=(0, 0, 0.27), parent=P, smooth=40)
    obj("bolt_washer", bm_prism(circle(0.44, 48), 0.05, holes=circle(0.17, 48)), m_bolt, loc=(0, 0, 0.27), parent=P, smooth=40)
    obj("bolt_shank", bm_cyl(0.135, 1.0, 32), m_bolt, loc=(0, 0, 0.74), parent=P, smooth=40)
    # thread: a helix wound on the shank
    turns, z0, z1 = 9, 0.62, 1.2
    path = [(math.cos(TAU * turns * t) * 0.15, math.sin(TAU * turns * t) * 0.15, z0 + (z1 - z0) * t) for t in (i / (turns * 24) for i in range(turns * 24 + 1))]
    obj("bolt_thread", bm_tube(path, 0.03, ring=8), m_bolt, parent=P, smooth=70, outline=False)
    return P


def nut(m, loc, rot, s=1.0):
    obj("nut", bm_prism(hexagon(0.34, 4), 0.26, holes=circle(0.15, 24)), m, loc=loc, rot=rot, scale=s, bevel=0.03)


def i_beam(m, loc, rot=(0, 0, 0), L=2.4, w=0.84, h=0.9, tf=0.15, tw=0.15, rivets=None):
    """structural I-beam, length along local Y (its I-shaped end looks at the camera)"""
    pts = [(-w / 2, -h / 2), (w / 2, -h / 2), (w / 2, -h / 2 + tf), (tw / 2, -h / 2 + tf), (tw / 2, h / 2 - tf), (w / 2, h / 2 - tf),
           (w / 2, h / 2), (-w / 2, h / 2), (-w / 2, h / 2 - tf), (-tw / 2, h / 2 - tf), (-tw / 2, -h / 2 + tf), (-w / 2, -h / 2 + tf)]
    bm = bm_prism(pts, L, axis="Y")
    # prism along Y: (x, y, z) <- (x, z_extrude, -y): the outline (x, y) becomes (x, -z); mirror back to keep it upright
    for v in bm.verts:
        v.co.z = -v.co.z
    ob = obj("beam", bm, m, loc=loc, rot=rot, bevel=0.025)
    if rivets:
        P = _xf(loc, rot)
        for y in rivets:
            for x in (-w * 0.3, w * 0.3):
                bm2 = bmesh.new()
                bmesh.ops.create_uvsphere(bm2, u_segments=16, v_segments=8, radius=0.055)
                obj("rivet", bm2, m, loc=(x, y, h / 2 + 0.01), parent=P, smooth=80, outline=False)
    return ob


# ------------------------------------------------------------------------------------------- icons
def icon_steel():
    """Steel Beams: a pyramid of three I-beams (ends to the camera) and a big bolt with its nut"""
    steel = pbr("steel", "#5f78aa", metal=0.8, rough=0.32, coat=0.45, tex="brushed", axis="Y", dark="#4a6194", light="#94acd8",
                aniso=0.4, emit=0.2)
    chrome = pbr("chrome", "#eef2f8", metal=1.0, rough=0.12, coat=0.6, tex="brushed", axis="Z", dark="#cfd7e3", light="#ffffff", emit=0.2)
    W, H = 0.84, 0.9
    for x in (-0.47, 0.47):
        i_beam(steel, (x, 0, H / 2), L=1.8, rivets=(-0.45, 0.2))
    i_beam(steel, (0, 0.12, H * 1.5), L=1.8, rivets=(-0.3, 0.35))
    bolt(chrome, (0.98, -1.0, 0.42), (70, 0, 150), s=1.05)
    nut(chrome, (-0.98, -1.05, 0.13), (90, 0, 25), s=0.95)


def icon_copper():
    """Copper Wire: a wooden cable reel wound with shiny copper wire, the free end curling out"""
    cu = pbr("copper", "#ff8b4e", metal=1.0, rough=0.2, coat=0.45, emit=0.14)
    cu_core = pbr("copper_core", "#c45a2a", metal=1.0, rough=0.35, emit=0.1)
    wood = pbr("reel_wood", "#e0a868", rough=0.45, coat=0.3, tex="grain", dark="#cf9454", light="#eab778", emit=0.18)
    dark = pbr("reel_hub", "#5a3a22", rough=0.5, emit=0.06)
    R0, L, Rf, wr = 0.62, 1.16, 1.05, 0.062
    for x in (-L / 2 - 0.08, L / 2 + 0.08):
        obj("flange", bm_prism(circle(Rf, 64), 0.16, holes=circle(0.2, 64), axis="X"), wood, loc=(x, 0, 0), smooth=40, bevel=0.035)
        obj("hub", bm_cyl(0.2, 0.17, 32, axis="X"), dark, loc=(x, 0, 0), smooth=40)
    # under the coil a copper core, so no gap shows between the turns
    obj("core", bm_cyl(R0 + 0.02, L, 64, axis="X"), cu_core, smooth=40, outline=False)
    # two visible layers of tightly wound wire
    for R, ph in ((R0 + wr * 1.2, 0.0), (R0 + wr * 2.9, 0.5)):
        turns = int(L / (2 * wr)) - 0.5
        n = int(turns * 40)
        path = []
        for i in range(n + 1):
            t = i / n
            a = TAU * (turns * t + ph)
            path.append((-L / 2 + wr + (L - 2 * wr) * t, math.cos(a) * R, math.sin(a) * R))
        obj("coil", bm_tube(path, wr, ring=10), cu, smooth=70, outline=False)
    # the free end: leaves the top of the coil, loops up and out to the front-right, stripped bright tip
    R = R0 + wr * 2.9
    p0 = Vector((L / 2 - 0.2, 0, R))
    pts = []
    for i in range(40):
        t = i / 39
        a = math.pi * 1.25 * t
        pts.append(p0 + Vector((0.55 * t + 0.25 * math.sin(a), -0.5 * math.sin(a) - 0.4 * t, 0.45 * math.sin(a * 0.8) + 0.1 * t)))
    obj("wire_end", bm_tube(pts, wr * 1.05, ring=12), cu, smooth=70)
    tip = pts[-1] + (pts[-1] - pts[-2]).normalized() * 0.12
    obj("wire_tip", bm_tube([pts[-1], tip], wr * 0.7, ring=12), pbr("bright_cu", "#ffc49a", metal=1.0, rough=0.1, emit=0.25), smooth=70)


def fluted(r, h, n=20, depth=0.06):
    pts = []
    for k in range(n * 6):
        a = TAU * k / (n * 6)
        f = abs(math.sin(a * n / 2))
        pts.append((math.cos(a) * (r - depth * (1 - f) ** 3), math.sin(a) * (r - depth * (1 - f) ** 3)))
    return bm_prism(pts, h)


def icon_marble():
    """Marble: a fluted column on its plinth, and two polished slabs stacked in front of it"""
    mb = pbr("marble", "#f7f4ef", rough=0.06, coat=0.9, tex="marble", scale=1.0, emit=0.18)
    mb2 = pbr("marble2", "#f4f1ec", rough=0.06, coat=0.9, tex="marble", scale=1.4, emit=0.18)
    cx, cy = 0.45, 0.5
    obj("plinth", bm_box(1.25, 1.25, 0.26), mb2, loc=(cx, cy, 0.13), bevel=0.04)
    obj("torus", bm_cyl(0.56, 0.16, 64), mb2, loc=(cx, cy, 0.34), smooth=40, bevel=0.06)
    obj("shaft", fluted(0.47, 1.5, n=16, depth=0.07), mb2, loc=(cx, cy, 0.42 + 0.75), smooth=50)
    obj("echinus", bm_cyl(0.48, 0.18, 64, r2=0.64), mb2, loc=(cx, cy, 2.01), smooth=40, bevel=0.03)
    obj("abacus", bm_box(1.38, 1.38, 0.22), mb2, loc=(cx, cy, 2.21), bevel=0.04)
    obj("slab1", bm_box(1.6, 1.05, 0.4), mb, loc=(-0.55, -0.75, 0.2), rot=(0, 0, 14), bevel=0.06)
    obj("slab2", bm_box(1.3, 0.85, 0.36), mb2, loc=(-0.5, -0.78, 0.58), rot=(0, 0, -8), bevel=0.06)


def ingot(m, m_top, loc, rot=(0, 0, 0)):
    a, b, h = (0.72, 0.36), (0.54, 0.24), 0.36
    pts = [(sx * a[0], sy * a[1], 0) for sx in (-1, 1) for sy in (-1, 1)] + [(sx * b[0], sy * b[1], h) for sx in (-1, 1) for sy in (-1, 1)]
    P = _xf(loc, rot)
    obj("ingot", bm_hull(pts), m, parent=P, bevel=0.035)
    obj("stamp", bm_box(0.6, 0.24, 0.02), m_top, loc=(0, 0, h + 0.003), parent=P, bevel=0.008, outline=False)


def leaf_sheet(m, loc, rot, s=1.0, wave=0.1, seed=0, parent=None):
    bm = bmesh.new()
    n = 12
    vs = {}
    for i in range(n + 1):
        for j in range(n + 1):
            x, y = (i / n - 0.5) * s, (j / n - 0.5) * s
            z = wave * (math.sin(x * 3.1 + seed) * math.cos(y * 2.7 - seed) + 0.6 * (x * x - y * y))
            vs[i, j] = bm.verts.new((x, y, z))
    for i in range(n):
        for j in range(n):
            bm.faces.new((vs[i, j], vs[i + 1, j], vs[i + 1, j + 1], vs[i, j + 1]))
    ret = bmesh.ops.extrude_face_region(bm, geom=bm.faces[:])
    nv = [e for e in ret["geom"] if isinstance(e, bmesh.types.BMVert)]
    bmesh.ops.translate(bm, verts=nv, vec=(0, 0, 0.025))
    obj("leaf", bm, m, loc=loc, rot=rot, smooth=60, parent=parent)


def icon_gold():
    """Gold Leaf: a pyramid of shiny gold bars on a few crinkled sheets of gold leaf"""
    g = pbr("gold", "#ffc534", metal=1.0, rough=0.13, coat=0.45, tex="hammered", scale=3.0, bump=0.05, dark="#f2ae22", light="#ffd86a", emit=0.3)
    gt = pbr("gold_stamp", "#e09a1c", metal=1.0, rough=0.3, emit=0.1)
    leaf = pbr("gold_leaf", "#ffd24f", metal=1.0, rough=0.2, coat=0.2, tex="leaf", bump=0.25, dark="#f0b028", light="#ffe48a", emit=0.32)
    # a fan of gold leaf sheets standing up behind (like a book of leaf, opened)
    for k, a in enumerate((-34, -12, 10, 32)):
        P = _xf((0, 0.45, 0.15), (0, a, 0)) @ _xf((0, 0, 0.85), (90 + 4 * (k % 2), 0, 0))
        leaf_sheet(leaf, (0, 0.03 * k, 0), (0, 0, 0), s=1.45, wave=0.06 + 0.02 * (k % 2), seed=0.7 * k, parent=P)
    for x in (-0.6, 0.6):
        ingot(g, gt, (x, -0.35, 0.0))
    ingot(g, gt, (0, -0.35, 0.36))


def icon_diamond():
    """Diamond Glass: a framed pane of shining crystal glass with a big brilliant-cut diamond in front"""
    import icons2 as P
    frame = pbr("dg_frame", "#c9d6ea", metal=1.0, rough=0.14, coat=0.6, emit=0.28)
    W, H, T = 1.7, 2.1, 0.14
    # glass pane: faceted tiles in shades of ice blue (opaque candy glass reads at any size), with a bright edge
    tiles = [("#bdf4ff", 0.55), ("#7fe3ff", 0.4), ("#4fcbff", 0.45), ("#a6eeff", 0.5)]
    P0 = _xf((0, 0.3, H / 2 + 0.05), (8, 0, -16))
    for k, (col, em) in enumerate(tiles):
        ix, iz = k % 2, k // 2
        m = pbr("dg_glass%d" % k, col, rough=0.04, coat=1.0, emit=em)
        obj("pane", bm_box(W / 2 - 0.06, T, H / 2 - 0.06), m, loc=((ix - 0.5) * W / 2, 0, (iz - 0.5) * H / 2), parent=P0, bevel=0.05)
    # frame bars around and across
    for (sx, sz, x, z) in ((W + 0.16, 0.12, 0, H / 2 + 0.03), (W + 0.16, 0.12, 0, -H / 2 - 0.03), (0.12, H, W / 2 + 0.03, 0),
                           (0.12, H, -W / 2 - 0.03, 0), (W, 0.07, 0, 0), (0.07, H, 0, 0)):
        obj("frame", bm_box(sx, T + 0.06, sz), frame, loc=(x, 0, z), parent=P0, bevel=0.02)
    # glints on the glass (thin white strokes)
    for (x, z, a, l) in ((-0.55, 0.62, 40, 0.42), (-0.4, 0.52, 40, 0.2), (0.32, -0.3, 40, 0.3)):
        obj("glint", bm_box(l, 0.02, 0.05), pbr("glint", "#ffffff", emit=2.0), loc=(x, -T / 2 - 0.012, z), rot=(0, -a, 0), parent=P0, outline=False)
    g = P.brilliant(loc=(0.55, -0.85, 0.7), rot=(18, 0, 14), s=0.78)
    if g.name not in I3.iscene().objects:
        I3.iscene().collection.objects.link(g)


# blueprints: blue sheet with a light grid and a white house drawing, rolled at the top, and a tier seal
BP = {"bronze": ("#d98a4e", "#9c5426", "#ffc08a"), "silver": ("#dfe6f0", "#8d9ab0", "#ffffff"),
      "gold": ("#ffcb3a", "#d18a12", "#fff0a0"), "diamond": ("#7fe8ff", "#1f9ee6", "#e8fdff")}


def icon_blueprint(tier):
    paper = pbr("bp_paper", "#1f63c9", rough=0.55, coat=0.1, tex="grid", k=4.0, w=0.06, axes=("X", "Z"), line="#5d9bf0", emit=0.22)
    ink = pbr("bp_ink", "#f2f8ff", rough=0.4, emit=0.7)
    W, H = 2.0, 1.7
    P0 = _xf((0, 0, 0), (-12, 0, 0))
    # the sheet: a thin, slightly curved panel facing the camera (-Y)
    bm = bmesh.new()
    nx, nz = 16, 12
    vs = {}
    for i in range(nx + 1):
        for j in range(nz + 1):
            x, z = (i / nx - 0.5) * W, (j / nz) * H - H / 2
            vs[i, j] = bm.verts.new((x, 0.06 * math.cos(x * 1.2) - 0.02, z))
    for i in range(nx):
        for j in range(nz):
            bm.faces.new((vs[i, j], vs[i, j + 1], vs[i + 1, j + 1], vs[i + 1, j]))
    ret = bmesh.ops.extrude_face_region(bm, geom=bm.faces[:])
    nv = [e for e in ret["geom"] if isinstance(e, bmesh.types.BMVert)]
    bmesh.ops.translate(bm, verts=nv, vec=(0, 0.03, 0))
    obj("sheet", bm, paper, parent=P0, smooth=60)
    # rolls at the top and the bottom edge
    for z, r in ((H / 2 + 0.16, 0.2), (-H / 2 - 0.12, 0.15)):
        obj("roll", bm_cyl(r, W + 0.02, 48, axis="X"), paper, loc=(0, 0.04, z), parent=P0, smooth=40)
    # the drawing: a house front in thick white lines (walls, roof, door, two windows) and a dimension line
    def line(x0, z0, x1, z1, w=0.055):
        dx, dz = x1 - x0, z1 - z0
        L = math.hypot(dx, dz)
        a = math.degrees(math.atan2(dz, dx))
        obj("ink", bm_box(L + w, 0.03, w), ink, loc=((x0 + x1) / 2, -0.06, (z0 + z1) / 2), rot=(0, -a, 0), parent=P0, outline=False)
    hx, hz, hw, hh = -0.18, -0.62, 1.05, 0.62
    for a, b in (((hx - hw / 2, hz), (hx + hw / 2, hz)), ((hx - hw / 2, hz), (hx - hw / 2, hz + hh)), ((hx + hw / 2, hz), (hx + hw / 2, hz + hh)),
                 ((hx - hw / 2 - 0.12, hz + hh), (hx, hz + hh + 0.5)), ((hx, hz + hh + 0.5), (hx + hw / 2 + 0.12, hz + hh)),
                 ((hx - hw / 2 - 0.12, hz + hh), (hx + hw / 2 + 0.12, hz + hh))):
        line(*a, *b)
    for a, b in (((hx - 0.08, hz), (hx - 0.08, hz + 0.36)), ((hx + 0.14, hz), (hx + 0.14, hz + 0.36)), ((hx - 0.08, hz + 0.36), (hx + 0.14, hz + 0.36))):
        line(*a, *b, w=0.04)
    for wx in (hx - 0.32, hx + 0.34):
        for a, b in (((wx - 0.1, hz + 0.22), (wx + 0.1, hz + 0.22)), ((wx - 0.1, hz + 0.42), (wx + 0.1, hz + 0.42)),
                     ((wx - 0.1, hz + 0.22), (wx - 0.1, hz + 0.42)), ((wx + 0.1, hz + 0.22), (wx + 0.1, hz + 0.42))):
            line(*a, *b, w=0.035)
    line(hx - hw / 2, hz - 0.14, hx + hw / 2, hz - 0.14, w=0.025)
    line(hx - hw / 2, hz - 0.2, hx - hw / 2, hz - 0.08, w=0.025)
    line(hx + hw / 2, hz - 0.2, hx + hw / 2, hz - 0.08, w=0.025)
    line(-0.85, 0.58, -0.25, 0.58, w=0.03)
    line(-0.85, 0.46, -0.45, 0.46, w=0.03)
    # the tier seal: a medal with a star, ribbon tails behind it
    c, cd, cl = BP[tier]
    if tier == "diamond":
        sm = pbr("seal_" + tier, c, rough=0.05, coat=1.0, emit=0.45)
        sm2 = pbr("seal2_" + tier, cd, rough=0.1, coat=0.8, emit=0.5)
    else:
        sm = pbr("seal_" + tier, c, metal=1.0, rough=0.14, coat=0.5, tex="hammered", scale=4.0, bump=0.04, dark=c, light=cl, emit=0.38)
        sm2 = pbr("seal2_" + tier, cd, metal=1.0, rough=0.2, coat=0.4, emit=0.3)
    rib = pbr("rib_" + tier, {"bronze": "#c0392b", "silver": "#3a6fe0", "gold": "#e0302f", "diamond": "#8a4dff"}[tier], rough=0.35, coat=0.3, emit=0.2)
    sx, sz = 0.62, -0.42
    for side in (-1, 1):
        pts = [(-0.13, 0), (0.13, 0), (0.13, 0.62), (0, 0.5), (-0.13, 0.62)]  # (axis Y turns +y into -z: they hang down)
        obj("ribbon", bm_prism(pts, 0.04, axis="Y"), rib, loc=(sx + side * 0.17, -0.1, sz - 0.05), rot=(0, side * -18, 0), parent=P0, bevel=0.01)
    bm = bm_prism(circle(0.46, 72), 0.1, axis="Y")
    obj("seal", bm, sm, loc=(sx, -0.16, sz), parent=P0, smooth=40, bevel=0.03)
    obj("seal_rim", bm_prism(circle(0.46, 72), 0.04, holes=circle(0.37, 72), axis="Y"), sm2, loc=(sx, -0.22, sz), parent=P0, smooth=40)
    star = [(math.cos(math.radians(90 + 36 * k)) * (0.27 if k % 2 == 0 else 0.12), math.sin(math.radians(90 + 36 * k)) * (0.27 if k % 2 == 0 else 0.12)) for k in range(10)]
    bm = bm_prism(star, 0.06, axis="Y")
    for v in bm.verts:
        v.co.z = -v.co.z
    obj("seal_star", bm, sm2 if tier != "diamond" else pbr("seal_star_d", "#ffffff", rough=0.05, emit=0.9), loc=(sx, -0.23, sz), parent=P0, bevel=0.012)


ICONS = {"steel": icon_steel, "copper": icon_copper, "marble": icon_marble, "gold": icon_gold, "diamond": icon_diamond}
for _t in BP:
    ICONS["bp_" + _t] = (lambda t: (lambda: icon_blueprint(t)))(_t)

VIEW = {"steel": (-0.34, -1, 0.5), "copper": (-0.3, -1, 0.34), "marble": (-0.3, -1, 0.36), "gold": (-0.2, -1, 0.42),
        "diamond": (-0.25, -1, 0.3)}
SPARKLE = {"steel": [(0.86, 0.14, 0.05)], "copper": [(0.14, 0.2, 0.06)], "marble": [(0.86, 0.12, 0.055)],
           "gold": [(0.84, 0.2, 0.08), (0.16, 0.32, 0.055)], "diamond": [(0.85, 0.15, 0.08), (0.2, 0.2, 0.05)],
           "bp_bronze": [], "bp_silver": [(0.88, 0.56, 0.05)], "bp_gold": [(0.88, 0.56, 0.06)], "bp_diamond": [(0.88, 0.54, 0.07), (0.86, 0.14, 0.045)]}


def render(names=None, size=768, out_size=256, samples=96):
    names = names or list(ICONS)
    os.makedirs(OUT, exist_ok=True)
    done = []
    for n in names:
        I3.reset()
        _M.clear()
        I.OUTLINE = 0.034
        ICONS[n]()
        I.add_outlines()
        scn = I3.iscene()
        scn.render.resolution_x = scn.render.resolution_y = size
        scn.cycles.samples = samples
        raw = os.path.join(OUT, "raw_%s.png" % n)
        I.frame_and_render(raw, view=VIEW.get(n, (-0.12, -1, 0.3)), margin=1.1)
        key = "item_" + n
        postnp.SPARKLE[key] = SPARKLE.get(n, [])
        cell = postnp.finish(postnp.load(raw), key, out_size)
        postnp.save(cell, os.path.join(OUT, n + ".png"))
        done.append(n)
    I3.clear()
    return done


def build_only(name):
    """for looking at a model in the viewport before rendering"""
    I3.reset()
    _M.clear()
    ICONS[name]()
