"""BlockRise Empire - the Thunderclap storm cloud sprite (live Blender, scene "BlockRise Icons").

A cartoon storm cloud seen from the side: soft round puffs on top, a flat darker underside, lit from above.
Rendered on a transparent background; in game it is a camera-facing billboard (a few of them at different depths
make the cloud), tinted darker normally and white for a blink of lightning.

    import cloud; cloud.render()
"""
import bpy, math, os, random
from mathutils import Vector
import icons as I
import icons3 as I3

OUT = os.path.join(I3.OUT, "cloud")


def _mat():
    m = bpy.data.materials.new("cloud_mat")
    m.use_nodes = True
    nt = m.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    p = nt.nodes.new("ShaderNodeBsdfPrincipled")
    p.inputs["Roughness"].default_value = 0.85
    p.inputs["Coat Weight"].default_value = 0.0
    # colour by height: light grey-blue tops, slate underside
    geo = nt.nodes.new("ShaderNodeNewGeometry")
    sep = nt.nodes.new("ShaderNodeSeparateXYZ")
    nt.links.new(geo.outputs["Position"], sep.inputs[0])
    mr = nt.nodes.new("ShaderNodeMapRange")
    mr.inputs["From Min"].default_value = -0.6
    mr.inputs["From Max"].default_value = 1.4
    nt.links.new(sep.outputs["Z"], mr.inputs["Value"])
    r = nt.nodes.new("ShaderNodeValToRGB")
    el = r.color_ramp.elements
    el[0].position, el[0].color = 0.0, (*I.rgb("#4b5675"), 1)
    el[1].position, el[1].color = 1.0, (*I.rgb("#e4eaf7"), 1)
    e = el.new(0.45)
    e.color = (*I.rgb("#8d99b8"), 1)
    nt.links.new(mr.outputs[0], r.inputs["Fac"])
    nt.links.new(r.outputs["Color"], p.inputs["Base Color"])
    nt.links.new(r.outputs["Color"], p.inputs["Emission Color"])
    p.inputs["Emission Strength"].default_value = 0.35
    # soft light through the edges (subsurface-ish look without the cost)
    lw = nt.nodes.new("ShaderNodeLayerWeight")
    lw.inputs["Blend"].default_value = 0.35
    mix = nt.nodes.new("ShaderNodeMixShader")
    tr = nt.nodes.new("ShaderNodeEmission")
    tr.inputs["Color"].default_value = (*I.rgb("#cfd8f0"), 1)
    tr.inputs["Strength"].default_value = 0.55
    nt.links.new(lw.outputs["Fresnel"], mix.inputs["Fac"])
    nt.links.new(p.outputs[0], mix.inputs[1])
    nt.links.new(tr.outputs[0], mix.inputs[2])
    nt.links.new(mix.outputs[0], out.inputs[0])
    return m


def build(seed=3, width=5.2):
    """metaball puffs: a row of big round tops, smaller puffs at the ends, a flat bottom"""
    random.seed(seed)
    scn = I3.iscene()
    mb = bpy.data.metaballs.new("cloud_mb")
    mb.resolution = 0.06
    mb.render_resolution = 0.035
    mb.threshold = 0.6
    ob = bpy.data.objects.new("cloud_mb", mb)
    scn.collection.objects.link(ob)
    n = 7
    for i in range(n):
        t = i / (n - 1)
        x = (t - 0.5) * width
        # tallest in the middle, falling off to the ends
        h = math.sin(math.pi * (0.12 + 0.76 * t))
        r = 0.75 + 0.75 * h + random.uniform(-0.12, 0.12)
        el = mb.elements.new()
        el.co = (x + random.uniform(-0.15, 0.15), random.uniform(-0.25, 0.25), 0.15 + 0.55 * h + random.uniform(-0.1, 0.1))
        el.radius = r
    # a second row a little behind and up, for depth
    for i in range(4):
        t = (i + 0.5) / 4
        el = mb.elements.new()
        el.co = ((t - 0.5) * width * 0.75, 0.6, 0.55 + 0.6 * math.sin(math.pi * t))
        el.radius = 0.95 + random.uniform(-0.1, 0.15)
    # the flat underside: a wide squashed ellipsoid
    el = mb.elements.new()
    el.type = "ELLIPSOID"
    el.co = (0, 0, -0.05)
    el.size_x, el.size_y, el.size_z = width * 0.5, 0.75, 0.32
    el.radius = 1.0
    bpy.context.view_layer.update()
    dg = bpy.context.evaluated_depsgraph_get()
    me = bpy.data.meshes.new_from_object(ob.evaluated_get(dg), depsgraph=dg)
    bpy.data.objects.remove(ob, do_unlink=True)
    bpy.data.metaballs.remove(mb)
    cl = bpy.data.objects.new("cloud", me)
    scn.collection.objects.link(cl)
    for p in me.polygons:
        p.use_smooth = True
    me.materials.append(_mat())
    # flatten the very bottom a little more
    for v in me.vertices:
        if v.co.z < -0.25:
            v.co.z = -0.25 + (v.co.z + 0.25) * 0.25
    cl["no_outline"] = True
    return cl


def render(size=512):
    os.makedirs(OUT, exist_ok=True)
    I3.reset()
    scn = I3.iscene()
    build()
    scn.render.resolution_x = size
    scn.render.resolution_y = size
    scn.cycles.samples = 64
    path = os.path.join(OUT, "storm_cloud.png")
    I.frame_and_render(path, view=(0, -1, 0.12), margin=1.04)
    I3.clear()
    return path
