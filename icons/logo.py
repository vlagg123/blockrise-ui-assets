"""BlockRise Empire - title logo, rendered in the live Blender (scene "BlockRise Icons", same lights and candy
materials as the icons): chunky 3D gold letters, a red EMPIRE banner, a tower crane carrying a steel beam,
a hard hat on the B, coins and a gem. The 2D finish (thick ink outline + soft shadow) is done with numpy."""
import bpy, math, os
from mathutils import Vector
import icons as I
import icons2 as P
import icons3 as I3
import postnp

FONT = "LuckiestGuy"
OUT = I3.OUT


def grad_mat(name, stops, gloss=0.6):
    """candy material with a vertical colour ramp (object 'Generated' Z: 0 bottom .. 1 top)"""
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    p = nt.nodes.new("ShaderNodeBsdfPrincipled")
    tc = nt.nodes.new("ShaderNodeTexCoord")
    sep = nt.nodes.new("ShaderNodeSeparateXYZ")
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    els = ramp.color_ramp.elements
    for i, (pos, hexcol) in enumerate(stops):
        e = els[i] if i < 2 else els.new(pos)
        e.position = pos
        e.color = (*I.rgb(hexcol), 1)
    nt.links.new(tc.outputs["Generated"], sep.inputs[0])
    nt.links.new(sep.outputs["Z"], ramp.inputs["Fac"])
    nt.links.new(ramp.outputs["Color"], p.inputs["Base Color"])
    nt.links.new(ramp.outputs["Color"], p.inputs["Emission Color"])
    p.inputs["Emission Strength"].default_value = 0.18
    p.inputs["Roughness"].default_value = 0.42 - 0.35 * gloss
    p.inputs["Coat Weight"].default_value = 0.6
    p.inputs["Coat Roughness"].default_value = 0.06
    p.inputs["Metallic"].default_value = 0.15
    nt.links.new(p.outputs[0], out.inputs[0])
    return m


def text3d(body, size, depth, loc, mat, bevel=0.035, spacing=1.0, rot=(90, 0, 0)):
    bpy.ops.object.text_add(location=loc, rotation=[math.radians(a) for a in rot])
    ob = bpy.context.object
    cu = ob.data
    cu.body = body
    cu.font = bpy.data.fonts[FONT]
    cu.size = size
    cu.extrude = depth
    cu.bevel_depth = bevel
    cu.bevel_resolution = 4
    cu.space_character = spacing
    cu.align_x = "CENTER"
    cu.align_y = "CENTER"
    bpy.ops.object.convert(target="MESH")
    ob = bpy.context.object
    ob.data.materials.clear()
    ob.data.materials.append(mat)
    for p in ob.data.polygons:
        p.use_smooth = True
    wn = ob.modifiers.new("wn", "WEIGHTED_NORMAL")
    wn.keep_sharp = True
    ob["keep_flat"] = True
    return ob


def crane(x, y, base_z, top_z, jib_left, jib_right, hook_x, hook_z):
    Y, DK = "#ffc21a", "#3c4256"
    I.box((0.34, 0.34, top_z - base_z), loc=(x, y, (top_z + base_z) / 2), color=Y, bevel=0.04)
    # lattice: dark diagonals on the front of the mast
    n = int((top_z - base_z) / 0.42)
    for k in range(n):
        z = base_z + 0.21 + k * 0.42
        I.box((0.05, 0.05, 0.5), loc=(x, y - 0.18, z), rot=(0, 40 if k % 2 == 0 else -40, 0), color=DK, bevel=0.0)
    # jib + counter-jib, cab, cable, hook
    I.box((jib_right - jib_left, 0.26, 0.26), loc=((jib_left + jib_right) / 2, y, top_z + 0.13), color=Y, bevel=0.04)
    I.box((0.6, 0.4, 0.42), loc=(x + 0.2, y - 0.1, top_z - 0.1), color="#4f8dff", bevel=0.06)
    I.box((0.55, 0.36, 0.36), loc=(jib_right - 0.35, y, top_z - 0.12), color="#8a93a8", bevel=0.05)
    I.cyl(0.025, top_z - hook_z, loc=(hook_x, y, (top_z + hook_z) / 2), color=DK, bevel=0.0, verts=12)
    I.box((0.16, 0.16, 0.12), loc=(hook_x, y, hook_z), color=DK, bevel=0.03)


def ibeam(loc, length, rot=(0, 0, 0)):
    G = "#9aa6bd"
    parts = [I.box((length, 0.34, 0.07), loc=(0, 0, 0.17), color=G, bevel=0.02, metal=True),
             I.box((length, 0.34, 0.07), loc=(0, 0, -0.17), color=G, bevel=0.02, metal=True),
             I.box((length, 0.08, 0.34), loc=(0, 0, 0), color="#7f8aa3", bevel=0.01, metal=True)]
    return I.group(parts, loc=loc, rot=rot)


def build():
    I3.reset()
    I.OUTLINE = 0.05
    gold = grad_mat("logo_gold", [(0.0, "#ff7a14"), (0.45, "#ffc22e"), (1.0, "#fff3a6")])
    # crane behind the right end of the word, carrying a beam above the letters
    crane(x=3.55, y=0.9, base_z=-1.45, top_z=2.75, jib_left=-0.2, jib_right=4.6, hook_x=1.15, hook_z=2.25)
    ibeam((1.15, 0.9, 2.02), 1.9, rot=(0, -4, 0))
    # the word
    text3d("BLOCKRISE", 1.55, 0.3, (0, 0, 1.0), gold, bevel=0.04, spacing=1.02)
    # EMPIRE banner: red bar with folded tails behind
    RED, RED2 = "#ff4a3d", "#c42f2a"
    I.box((4.1, 0.34, 1.02), loc=(0, 0.05, -0.38), color=RED, bevel=0.12, gloss=0.5)
    for sx in (-1, 1):
        tail = [(0, 0.42), (0.95, 0.42), (0.62, 0.0), (0.95, -0.42), (0, -0.42)]
        I.poly([(sx * (2.0 + x), z) for x, z in tail], 0.26, loc=(0, 0.3, -0.58), color=RED2, bevel=0.06)
        I.poly([(sx * 2.0, 0.42), (sx * 2.25, 0.42), (sx * 2.25, -0.16), (sx * 2.0, 0.08)], 0.2, loc=(0, 0.22, -0.58), color="#8f1f1d", bevel=0.02)
    white = P.mat("#ffffff", gloss=0.5)
    text3d("EMPIRE", 0.92, 0.14, (0, -0.2, -0.36), white, bevel=0.025, spacing=1.06)
    # hard hat on the B, coins and a gem around
    hh = I.hardhat(rot=(12, 0, -18))
    hh.location = (-3.25, -0.1, 1.95)
    hh.scale = (0.48, 0.48, 0.48)
    I.coin(loc=(-4.15, -0.4, 0.15), rot=(78, 0, 25), r=0.42)
    I.coin(loc=(-3.6, -0.5, -0.75), rot=(82, 0, -15), r=0.32)
    P.brilliant(loc=(4.2, -0.5, -0.55), rot=(8, 0, -14), s=0.46)
    I.coin(loc=(3.0, -0.6, -1.05), rot=(80, 0, 18), r=0.3)
    P.puff()
    I.add_outlines()


def render(path=None, res=(2048, 1024)):
    path = path or os.path.join(OUT, "logo_raw.png")
    build()
    scn = I3.iscene()
    scn.render.resolution_x, scn.render.resolution_y = res
    scn.cycles.samples = 80
    I.frame_and_render(path, view=(0, -1, 0.16), margin=1.1)
    I3.clear()
    return path


def finish(raw_path=None, out_path=None):
    """halve, then a thick ink outline + soft drop shadow; 1024 x 512 for Roblox"""
    raw = postnp.load(raw_path or os.path.join(OUT, "logo_raw.png"))
    H, W = raw.shape[:2]
    pm = postnp._pm(raw).reshape(H // 2, 2, W // 2, 2, 4).mean((1, 3))
    img = postnp._unpm(pm)
    a = img[..., 3]
    outline = postnp.dilate(a, 9)
    sh = postnp.blur(postnp.shift_down(outline, 12), 7) * 0.6
    c = postnp.solid(postnp.INK, sh)
    c = postnp.over(c, postnp.solid(postnp.INK, outline))
    c = postnp.over(c, img)
    out_path = out_path or os.path.join(OUT, "logo.png")
    postnp.save(c, out_path)
    return out_path
