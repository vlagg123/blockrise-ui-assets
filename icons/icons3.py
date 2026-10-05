"""BlockRise Empire icons - live-Blender runner (premium pass 2).

Runs inside an open Blender session (through the Blender MCP add-on), without touching the user's own
scenes or data:
  * everything is built in the scene "BlockRise Icons"; between icons only data created here is removed
  * lighting = Poly Haven HDRI (wooden_studio_19, CC0) for soft studio reflections + the warm key / cool fill / rim suns
  * a few icons use CC0 Poly Pizza models (Quaternius, Kenney) kept in the scene "BR Library",
    re-shaded with the same glossy "candy" materials as the rest of the set
  * the 2D finish (outline, shadow, sparkles) and the atlas are made with numpy (postnp.py)
"""
import bpy, bmesh, os, math, json, colorsys, tempfile
from mathutils import Vector, Matrix
import icons as I
import icons2 as P
import postnp

ICON_SCENE, LIB_SCENE = "BlockRise Icons", "BR Library"
RES = 372                      # 3 x 124 (atlas cell 128 with a 2 px gutter)
OUT = os.path.join(tempfile.gettempdir(), "blockrise_icons")
HDRI_STRENGTH = 0.75


def iscene():
    return bpy.data.scenes[ICON_SCENE]


# ----------------------------------------------------------------------------------------- scene
def clear():
    scn = iscene()
    for o in list(scn.objects):
        bpy.data.objects.remove(o, do_unlink=True)
    before = json.loads(scn.get("br_before", "{}"))
    for attr in ("meshes", "materials", "curves", "lights", "cameras"):
        coll = getattr(bpy.data, attr)
        keep = set(before.get(attr, []))
        for d in list(coll):
            if d.users == 0 and d.name not in keep and not d.get("br_lib"):
                coll.remove(d)


def sun(direction, energy, color, angle):
    d = bpy.data.lights.new("br_sun", "SUN")
    d.energy = energy
    d.color = I.rgb(color)
    d.angle = math.radians(angle)
    o = bpy.data.objects.new("br_sun", d)
    iscene().collection.objects.link(o)
    o.rotation_euler = Vector(direction).to_track_quat("-Z", "Y").to_euler()
    return o


def reset():
    scn = iscene()
    bpy.context.window.scene = scn
    clear()
    P._mats = {}
    I._mats, I._outline_mat = {}, None
    scn.render.engine = "CYCLES"
    scn.cycles.device = "CPU"
    scn.cycles.samples = 64
    scn.cycles.use_denoising = True
    scn.cycles.max_bounces = 6
    scn.cycles.transparent_max_bounces = 32
    scn.render.resolution_x = scn.render.resolution_y = RES
    scn.render.resolution_percentage = 100
    scn.render.film_transparent = True
    scn.render.image_settings.file_format = "PNG"
    scn.render.image_settings.color_mode = "RGBA"
    scn.view_settings.view_transform = "Standard"
    scn.view_settings.look = "None"
    scn.view_settings.exposure = 0.0
    if scn.world and scn.world.use_nodes:
        for n in scn.world.node_tree.nodes:
            if n.type == "BACKGROUND":
                n.inputs["Strength"].default_value = HDRI_STRENGTH
    sun((0.45, 0.6, -0.66), 2.9, "#fff2dc", 22)     # key: warm, top-left-front
    sun((-0.7, 0.35, -0.25), 0.7, "#cfdcff", 30)    # fill: cool, from the right
    sun((-0.25, -0.9, -0.35), 2.6, "#ffffff", 6)    # rim: edge glint


# ----------------------------------------------------------------------------------------- library
def _srgb_hex(lin, sat=1.25, val=1.12):
    def to_s(c):
        c = max(0.0, min(1.0, c))
        return 12.92 * c if c <= 0.0031308 else 1.055 * c ** (1 / 2.4) - 0.055
    r, g, b = (to_s(c) for c in lin[:3])
    h, s, v = colorsys.rgb_to_hsv(r, g, b)
    r, g, b = colorsys.hsv_to_rgb(h, min(1, s * sat), min(1, v * val))
    return "#%02x%02x%02x" % (int(r * 255), int(g * 255), int(b * 255))


def _base_color(m):
    if m and m.use_nodes:
        for n in m.node_tree.nodes:
            if n.type == "BSDF_PRINCIPLED":
                return n.inputs["Base Color"].default_value
    return (0.6, 0.6, 0.6, 1)


def build_library(spec):
    """spec: key -> {"roots": [object names], "colors": {material name: hex}, "gloss": {material name: g}}.
    Moves each model under an empty 'LIB_<key>' in the library scene, centred with its bottom at z=0,
    smooth-by-angle shaded, with candy materials."""
    lib = bpy.data.scenes.get(LIB_SCENE) or bpy.data.scenes.new(LIB_SCENE)
    done_meshes = set()
    for key, sp in spec.items():
        if bpy.data.objects.get("LIB_" + key):
            continue
        roots = [bpy.data.objects[n] for n in sp["roots"]]
        objs = []
        for r in roots:
            objs.append(r)
            objs.extend(r.children_recursive)
        bpy.context.view_layer.update()
        pts = [o.matrix_world @ Vector(c) for o in objs if o.type == "MESH" for c in o.bound_box]
        lo = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
        hi = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
        off = Vector(((lo.x + hi.x) / 2, (lo.y + hi.y) / 2, lo.z))
        holder = bpy.data.objects.new("LIB_" + key, None)
        holder["br_lib"] = True
        lib.collection.objects.link(holder)
        for r in roots:
            mw = r.matrix_world.copy()
            r.parent = holder
            r.matrix_parent_inverse = Matrix.Identity(4)
            r.matrix_world = Matrix.Translation(-off) @ mw
        for o in [holder] + objs:
            for c in list(o.users_collection):
                if c != lib.collection:
                    c.objects.unlink(o)
            if lib.collection not in o.users_collection:
                lib.collection.objects.link(o)
        colors, gloss = sp.get("colors", {}), sp.get("gloss", {})
        for o in objs:
            if o.type != "MESH":
                continue
            me = o.data
            if me.name not in done_meshes:
                done_meshes.add(me.name)
                bm = bmesh.new()
                bm.from_mesh(me)
                for e in bm.edges:
                    e.smooth = not (len(e.link_faces) == 2 and e.calc_face_angle(0) > math.radians(38))
                for f in bm.faces:
                    f.smooth = True
                bm.to_mesh(me)
                bm.free()
            for slot in o.material_slots:
                m = slot.material
                if m is None or m.get("br_lib"):
                    continue
                name = m.name
                hexcol = colors.get(name.split(".")[0]) or colors.get(name) or _srgb_hex(_base_color(m))
                nm = P.mat(hexcol, gloss=gloss.get(name.split(".")[0], 0.4)).copy()
                nm.name = "lib_%s_%s" % (key, name)
                nm["br_lib"] = True
                nm["src"] = name.split(".")[0]
                slot.material = nm
    return lib


def lib(key, loc=(0, 0, 0), rot=(0, 0, 0), scale=1.0, paint=None):
    """Put a copy of a library model in the icon scene. paint: {source material name: hex} for this copy only."""
    holder = bpy.data.objects["LIB_" + key]
    scn = iscene()
    root = bpy.data.objects.new("use_" + key, None)
    scn.collection.objects.link(root)

    def cp(o, parent):
        c = o.copy()
        scn.collection.objects.link(c)
        c.parent = parent
        c.matrix_parent_inverse = o.matrix_parent_inverse.copy()
        if paint and c.type == "MESH":
            for slot in c.material_slots:
                src = slot.material and slot.material.get("src")
                if src in paint:
                    slot.link = "OBJECT"
                    slot.material = P.mat(paint[src], gloss=0.45)
        for ch in o.children:
            cp(ch, c)

    for ch in holder.children:
        cp(ch, root)
    root.location = loc
    root.rotation_euler = [math.radians(a) for a in rot]
    root.scale = (scale, scale, scale)
    return root


# ----------------------------------------------------------------------------------------- icons using library models
def icon_store():
    # Quaternius "Chest with Gold", open, from the front corner
    lib("chest", rot=(0, 0, 200))


def icon_home():
    lib("house", rot=(0, 0, 205))


def icon_suburbs():
    lib("house", loc=(-0.35, 0.2, 0), rot=(0, 0, 205), paint={"Main": "#4f8dff"})
    I.tree(loc=(1.05, -0.2, 0), s=1.05)


def icon_company():
    lib("bigbuilding", loc=(-0.45, 0.25, 0), rot=(0, 0, 25))
    lib("kenneyA", loc=(0.75, -0.35, 0), rot=(0, 0, 25), scale=0.62, paint={"_defaultMat": "#ffb347"})


def icon_downtown():
    lib("skyscraper", loc=(0, 0.2, 0), rot=(0, 0, 20), scale=1.25)
    lib("kenneyG", loc=(-0.85, -0.15, 0), rot=(0, 0, 20), scale=0.78, paint={"_defaultMat": "#7fb2ff"})
    lib("kenneyA", loc=(0.9, -0.3, 0), rot=(0, 0, 20), scale=0.7, paint={"_defaultMat": "#ff9f6e"})


def icon_vip():
    lib("crown", rot=(12, 0, 0))


LIB_ICONS = {"store": icon_store, "home": icon_home, "suburbs": icon_suburbs, "company": icon_company,
             "downtown": icon_downtown, "vip": icon_vip}
ICONS = dict(I.ICONS)
ICONS.update(LIB_ICONS)
VIEWS = dict(P.VIEWS)
VIEWS.update({"home": (0, -1, 0.5), "suburbs": (0, -1, 0.5), "company": (0, -1, 0.35), "downtown": (0, -1, 0.3),
              "store": (0, -1, 0.55), "vip": (0, -1, 0.35)})


# ----------------------------------------------------------------------------------------- run
def render(names):
    os.makedirs(os.path.join(OUT, "raw"), exist_ok=True)
    done = []
    for n in names:
        reset()
        ICONS[n]()
        if n not in LIB_ICONS:
            P.turn(n)
        P.puff()
        I.add_outlines()
        scn = iscene()
        scn.render.resolution_x = scn.render.resolution_y = RES
        I.frame_and_render(os.path.join(OUT, "raw", n + ".png"), view=VIEWS.get(n, (0, -1, 0.42)))
        done.append(n)
    clear()
    return done


def finish(names=None):
    raw = os.path.join(OUT, "raw")
    names = names or sorted(f[:-4] for f in os.listdir(raw) if f.endswith(".png"))
    os.makedirs(os.path.join(OUT, "cells"), exist_ok=True)
    cells = {}
    for n in names:
        cells[n] = postnp.finish(postnp.load(os.path.join(raw, n + ".png")), n)
        postnp.save(cells[n], os.path.join(OUT, "cells", n + ".png"))
    at, pos = postnp.atlas(cells, names)
    postnp.save(at, os.path.join(OUT, "icons_atlas.png"))
    rows = (len(names) + 7) // 8
    postnp.save(postnp.preview(at, rows), os.path.join(OUT, "preview.png"))
    return pos
