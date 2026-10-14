import sys, os, json, time, shutil
SP = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(SP, "src"))
import bpy
REPO = "/home/claude/blockrise-ui-assets"
bpy.ops.wm.open_mainfile(filepath=os.path.join(REPO, "blender/assets/blockrise_session.blend"))
hdr = os.path.join(REPO, "blender/assets/wooden_studio_19_1k.hdr")
for img in bpy.data.images:
    if img.filepath and os.path.basename(bpy.path.abspath(img.filepath)) == os.path.basename(hdr):
        img.filepath = hdr
        img.reload()
for s in bpy.data.scenes:
    if s.name == "BlockRise Icons" and s.world and s.world.use_nodes:
        for nd in s.world.node_tree.nodes:
            if nd.type == "TEX_ENVIRONMENT" and nd.image is None:
                nd.image = bpy.data.images.load(hdr, check_existing=True)
icon = bpy.data.scenes["BlockRise Icons"]
for w in bpy.context.window_manager.windows:
    w.scene = icon
import icons3
icons3.OUT = os.path.join(SP, "out")
import robux as R
R._SPEC = json.load(open(os.path.join(REPO, "hammers/spec.json")))
import allthumbs as A
import thumbs as TH
import divinecrate as DC

# the Divine Crate in the premium product look (the same deep round backdrop + gold ring as every other product)
TH.ICONS["crate_divine"] = DC.i_crate_divine
TH.ICONS["crate_divine3"] = lambda: A._pack("divine", 3, "x3", "#7a3fe0")
VIOLET = ("#8f5cff", "#120634")
TH.LOOK["crate_divine"] = VIOLET
TH.LOOK["crate_divine3"] = VIOLET
TH.VIEW["crate_divine"] = R.VIEW.get("crate_divine", (-0.3, -1, 0.4))
TH.VIEW["crate_divine3"] = (-0.22, -1, 0.38)

names = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else ["crate_divine", "crate_divine3"]
t0 = time.time()
print("rendered:", TH.render(names, size=1024, samples=128), "in %.0f s" % (time.time() - t0))
print("out dir:", TH.OUT)
