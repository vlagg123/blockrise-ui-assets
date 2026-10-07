"""BlockRise Empire - installs the Blender icon / hammer pipeline on any computer (Mac or Windows), from this repo.

Run inside Blender (through the Blender MCP add-on):
    import urllib.request
    exec(urllib.request.urlopen("https://raw.githubusercontent.com/vlagg123/blockrise-ui-assets/main/blender/setup.py").read())

What it does (nothing of the user's own scenes is touched):
  * downloads the scripts into ~/.local/share/blockrise_icons/src (icons*, items, postnp, robux, gear, zonecrates,
    bl_build, hammer_export) and the assets (studio HDRI, Poly Haven textures) next to them
  * appends the scenes "BlockRise Icons" (studio world + lights setup) and "BR Library" (CC0 library models) from
    blender/assets/blockrise_session.blend if this Blender file doesn't have them yet, and points the world's HDRI at
    the local copy
  * puts src on sys.path and sets icons3.OUT to the pipeline folder
Run it again any time: it refreshes the scripts (assets are kept if already there).
"""
import bpy, os, sys, importlib, urllib.request

RAW = "https://raw.githubusercontent.com/vlagg123/blockrise-ui-assets/main/"
ROOT = os.path.expanduser("~/.local/share/blockrise_icons")
SRC = os.path.join(ROOT, "src")
SCRIPTS = {
    "icons/icons.py": "icons.py", "icons/icons2.py": "icons2.py", "icons/icons3.py": "icons3.py", "icons/items.py": "items.py",
    "icons/postnp.py": "postnp.py", "icons/robux.py": "robux.py", "icons/gear.py": "gear.py", "icons/zonecrates.py": "zonecrates.py",
    "hammers/bl_build.py": "bl_build.py", "hammers/hammer_export.py": "hammer_export.py",
}
TEX = ["leather_red_02_Displacement_1k.png", "leather_red_02_Rough_1k.png", "leather_red_02_coll1_1k.png", "leather_red_02_nor_gl_1k.png",
       "rosewood_veneer_02_Diffuse_1k.png", "rosewood_veneer_02_Displacement_1k.png", "rosewood_veneer_02_Rough_1k.png",
       "rosewood_veneer_02_nor_gl_1k.png", "rusty_metal_04_Diffuse_1k.png", "rusty_metal_04_Displacement_1k.png",
       "rusty_metal_04_Metal_1k.png", "rusty_metal_04_Rough_1k.png", "rusty_metal_04_nor_gl_1k.png"]
HDR = "wooden_studio_19_1k.hdr"
BLEND = "blockrise_session.blend"


def _get(path, dest, force=True):
    if not force and os.path.exists(dest) and os.path.getsize(dest) > 0:
        return False
    data = urllib.request.urlopen(RAW + path, timeout=60).read()
    os.makedirs(os.path.dirname(dest), exist_ok=True)
    with open(dest, "wb") as f:
        f.write(data)
    return True


def install():
    report = []
    for path, name in SCRIPTS.items():
        _get(path, os.path.join(SRC, name))
    report.append("scripts %d" % len(SCRIPTS))
    n = 0
    for t in TEX:
        n += _get("blender/assets/tex/" + t, os.path.join(ROOT, "tex", t), force=False)
    n += _get("blender/assets/" + HDR, os.path.join(ROOT, HDR), force=False)
    blend = os.path.join(ROOT, BLEND)
    _get("blender/assets/" + BLEND, blend, force=False)
    report.append("assets new %d" % n)
    # the two pipeline scenes
    want = [s for s in ("BlockRise Icons", "BR Library") if s not in bpy.data.scenes]
    if want:
        with bpy.data.libraries.load(blend, link=False) as (src, dst):
            dst.scenes = [s for s in src.scenes if s in want]
        report.append("scenes appended: " + ", ".join(want))
    # the studio HDRI points at this computer's copy
    hdr = os.path.join(ROOT, HDR)
    for img in bpy.data.images:
        if img.filepath and os.path.basename(bpy.path.abspath(img.filepath)) == HDR:
            img.filepath = hdr
            img.reload()
    for s in bpy.data.scenes:
        if s.name == "BlockRise Icons" and s.world and s.world.use_nodes:
            for nd in s.world.node_tree.nodes:
                if nd.type == "TEX_ENVIRONMENT" and nd.image is None:
                    nd.image = bpy.data.images.load(hdr, check_existing=True)
    # imports
    if SRC not in sys.path:
        sys.path.insert(0, SRC)
    import icons3
    importlib.reload(icons3)
    icons3.OUT = ROOT
    for m in ("icons", "icons2", "postnp", "items", "robux", "gear", "zonecrates", "bl_build", "hammer_export"):
        if m in sys.modules:
            importlib.reload(sys.modules[m])
    report.append("OUT " + icons3.OUT)
    return report


print("BlockRise pipeline:", " · ".join(install()))
