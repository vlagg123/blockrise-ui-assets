# hammer_export.py - every hammer of the spec as meshes for Roblox (BlockRise Empire)
# One object per hammer per material ("<key>__<mat>", the Galaxy core on its own: "<key>__<mat>__Galaxy"), full-length
# handles (the icons shorten them), bevels applied, triangulated. Hammer i sits at OFF[i] (Blender coords, spec scale 1:
# 1 m = 1 spec unit). Four markers tell Roblox how the file came in: MARK_O (0,0,0), MARK_X (10,0,0), MARK_Y (0,10,0),
# MARK_Z (0,0,10).
import math, os, json
import bpy, bmesh
from mathutils import Vector, Matrix
import bl_build as B

OUT = os.path.expanduser("~/.local/share/blockrise_icons/hammer_meshes")
KEEP_APART = {"Galaxy"}
MAXTRI = 6000


def offset(i):
    return Vector(((i % 8) * 8.0 - 28.0, (i // 8) * 8.0 + 20.0, 0.0))


def build_all(keys=None):
    os.makedirs(OUT, exist_ok=True)
    spec = B.load_spec()
    pal = spec["palette"]
    import robux as R
    R.I3.reset()
    scn = R.I3.iscene()  # (the scene the hammers are built in: modifiers are evaluated there)
    bpy.context.window.scene = scn
    info = {"scale": spec.get("scale", 1), "hammers": {}}
    for i, h in enumerate(spec["hammers"]):
        if keys and h["key"] not in keys:
            continue
        B._M.clear()
        objs = B.build(h, pal, S=1.0, pose=(0.0, 0.0, 0.0), short=None)
        bpy.context.view_layer.update()
        dg = bpy.context.evaluated_depsgraph_get()
        groups = {}
        for ob in objs:
            me = bpy.data.meshes.new_from_object(ob.evaluated_get(dg), depsgraph=dg)
            mat = me.materials[0] if len(me.materials) else None
            mk = (mat.name[3:] if mat and mat.name.startswith("hm_") else (mat.name if mat else "none")).split(".")[0]
            piece = ob.name[3:].split(".")[0] if ob.name.startswith("hm_") else ob.name
            gk = mk + ("__" + piece if piece in KEEP_APART else "")
            groups.setdefault(gk, {"mat": mat, "parts": []})["parts"].append((me, ob.matrix_world.copy()))
        for ob in objs:
            bpy.data.objects.remove(ob, do_unlink=True)
        off = offset(i)
        tris_total = 0
        names = []
        for gk, g in groups.items():
            bm = bmesh.new()
            for me, mw in g["parts"]:
                tmp = bmesh.new()
                tmp.from_mesh(me)
                bmesh.ops.transform(tmp, matrix=Matrix.Translation(off) @ mw, verts=tmp.verts)
                tmp.to_mesh(me)
                tmp.free()
                bm.from_mesh(me)
                bpy.data.meshes.remove(me)
            bmesh.ops.triangulate(bm, faces=bm.faces[:])
            name = h["key"] + "__" + gk
            me2 = bpy.data.meshes.new(name)
            bm.to_mesh(me2)
            bm.free()
            if g["mat"]:
                me2.materials.append(g["mat"])
            ob2 = bpy.data.objects.new(name, me2)
            scn.collection.objects.link(ob2)
            # Roblox meshes stay light: anything over MAXTRI triangles is decimated (balls and rings have plenty)
            if len(me2.polygons) > MAXTRI:
                md = ob2.modifiers.new("dec", "DECIMATE")
                md.ratio = MAXTRI / len(me2.polygons)
                md.use_collapse_triangulate = True
                bpy.context.view_layer.update()
                dg2 = bpy.context.evaluated_depsgraph_get()
                me3 = bpy.data.meshes.new_from_object(ob2.evaluated_get(dg2), depsgraph=dg2)
                ob2.modifiers.remove(md)
                ob2.data = me3
                bpy.data.meshes.remove(me2)
                me2 = me3
                me2.name = name
            tris_total += len(me2.polygons)
            names.append((name, len(me2.polygons)))
        info["hammers"][h["key"]] = {"i": i, "tier": h["tier"], "off": list(off), "parts": names, "tris": tris_total}
    for nm, p in (("MARK_O", (0, 0, 0)), ("MARK_X", (10, 0, 0)), ("MARK_Y", (0, 10, 0)), ("MARK_Z", (0, 0, 10))):
        bm = bmesh.new()
        bmesh.ops.create_cube(bm, size=0.2)
        me = bpy.data.meshes.new(nm)
        bm.to_mesh(me)
        bm.free()
        ob = bpy.data.objects.new(nm, me)
        ob.location = p
        scn.collection.objects.link(ob)
    json.dump(info, open(os.path.join(OUT, "hammers.json"), "w"), indent=1)
    return scn, info


def export(scn, name="hammers.fbx"):
    win = bpy.context.window
    prev = win.scene
    win.scene = scn
    for ob in scn.objects:
        ob.select_set(ob.type == "MESH" and ("__" in ob.name or ob.name.startswith("MARK_")))
    path = os.path.join(OUT, name)
    bpy.ops.export_scene.fbx(filepath=path, use_selection=True, object_types={"MESH"}, use_mesh_modifiers=True,
                             mesh_smooth_type="FACE", apply_unit_scale=True, apply_scale_options="FBX_SCALE_ALL",
                             axis_forward="-Z", axis_up="Y", path_mode="AUTO", embed_textures=False, add_leaf_bones=False,
                             bake_anim=False)
    win.scene = prev
    return path
