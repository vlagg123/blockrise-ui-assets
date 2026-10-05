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
    mr.inputs["From Min"].default_value = -0.4
    mr.inputs["From Max"].default_value = 2.3
    nt.links.new(sep.outputs["Z"], mr.inputs["Value"])
    r = nt.nodes.new("ShaderNodeValToRGB")
    el = r.color_ramp.elements
    el[0].position, el[0].color = 0.0, (*I.rgb("#3c4562"), 1)
    el[1].position, el[1].color = 1.0, (*I.rgb("#c9d3ea"), 1)
    e = el.new(0.4)
    e.color = (*I.rgb("#76829f"), 1)
    nt.links.new(mr.outputs[0], r.inputs["Fac"])
    nt.links.new(r.outputs["Color"], p.inputs["Base Color"])
    nt.links.new(r.outputs["Color"], p.inputs["Emission Color"])
    p.inputs["Emission Strength"].default_value = 0.12
    # soft light through the edges (subsurface-ish look without the cost)
    lw = nt.nodes.new("ShaderNodeLayerWeight")
    lw.inputs["Blend"].default_value = 0.35
    mix = nt.nodes.new("ShaderNodeMixShader")
    tr = nt.nodes.new("ShaderNodeEmission")
    tr.inputs["Color"].default_value = (*I.rgb("#cfd8f0"), 1)
    tr.inputs["Strength"].default_value = 0.3
    nt.links.new(lw.outputs["Fresnel"], mix.inputs["Fac"])
    nt.links.new(p.outputs[0], mix.inputs[1])
    nt.links.new(tr.outputs[0], mix.inputs[2])
    nt.links.new(mix.outputs[0], out.inputs[0])
    return m


def build(seed=3, width=5.2):
    """metaball puffs: a cauliflower top (rows of round puffs getting fewer and higher), a flat bottom"""
    random.seed(seed)
    scn = I3.iscene()
    mb = bpy.data.metaballs.new("cloud_mb")
    mb.resolution = 0.05
    mb.render_resolution = 0.03
    mb.threshold = 0.6
    ob = bpy.data.objects.new("cloud_mb", mb)
    scn.collection.objects.link(ob)
    rows = ((8, 0.15, 0.62, 1.0), (6, 0.75, 0.78, 0.8), (4, 1.3, 0.8, 0.58), (2, 1.8, 0.7, 0.3))
    for n, z, r, span in rows:
        for i in range(n):
            t = (i + 0.5) / n
            el = mb.elements.new()
            el.co = ((t - 0.5) * width * span + random.uniform(-0.12, 0.12), random.uniform(-0.3, 0.3),
                     z + random.uniform(-0.12, 0.12) - (0.25 * abs(t - 0.5) if z > 0.5 else 0))
            el.radius = r * random.uniform(0.88, 1.15)
            el.stiffness = 2.6
    # the flat underside: a wide squashed ellipsoid
    el = mb.elements.new()
    el.type = "ELLIPSOID"
    el.co = (0, 0, -0.05)
    el.size_x, el.size_y, el.size_z = width * 0.46, 0.6, 0.22
    el.radius = 0.9
    el.stiffness = 2.6
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
    scn.view_settings.exposure = -0.5
    path = os.path.join(OUT, "storm_cloud.png")
    I.frame_and_render(path, view=(0, -1, 0.12), margin=1.04)
    scn.view_settings.exposure = 0.0
    I3.clear()
    return path
