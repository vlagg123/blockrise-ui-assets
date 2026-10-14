# divinecrate.py - the Divine Crate of CRATES_V7 (2026-10-14): the Store's power crate (Robux only, Mythic or better every
# time). The same loot chest as the other crates (robux.loot_chest): pearl white with gold straps, a soft lavender light
# and the Celestial Hammer (a Divine hammer) standing out of it, two white-violet gems at its feet. No sparkles in the air.
#   crate_divine    the game picture (256 px, transparent) and the product card (512 px)
#   crate_divine3   three chests (the 3-pack's product card)
# The Creator Hub thumbnails (icons/cards/crate_divine*.png, 512 px) are in the premium round look of thumbs.py (deep
# violet backdrop, spotlight, gold ring), like every other product: see divinethumbs_render.py.
# Run in Blender after blender/setup.py:  import divinecrate; divinecrate.render()
import robux as R

R.AIR_STARS = False  # (the game wants no sparkles)

R.CRATE_LOOK["divine"] = dict(body=("#e4d6ff", None, None, None), lid="#c9b0fc", trim=("#ffcf3a", 1.0), inner="#3b1c6e",
                              glow="#fff0ff", ray="#c48cff", gem=None, hammer="celestial", pose=(0.0, -15.0, -45.0))
WHITE_GEM = ("#ffffff", "#f4ecff", "#dccbff", "#bfa2ff", "#9a78f0", "#c7b0ff")
R.CARD["crate_divine"] = ("#f6e2ff", "#3a1670")
R.CARD["crate_divine3"] = ("#f6e2ff", "#3a1670")
for k in ("crate_divine", "crate_divine3"):
    R.VIEW[k] = (-0.3, -1, 0.4) if k == "crate_divine" else (-0.22, -1, 0.38)
    R.SPARK[k] = []


def i_crate_divine():
    R.track(R.loot_chest, rot=(0, 0, 22), kind="divine")
    R.track(R.gem, WHITE_GEM, loc=(-0.8, -0.2, 1.5), rot=(12, 0, 25), s=0.32)
    R.track(R.gem, R.PURPLE_GEM, loc=(2.0, -1.15, 0.45), rot=(8, 0, -20), s=0.4)
    R.track(R.gem, WHITE_GEM, loc=(-2.05, -0.95, 0.42), rot=(8, 0, 20), s=0.36)


def i_crate_divine3():
    R._three("divine")


R.ICONS["crate_divine"] = i_crate_divine
R.ICONS["crate_divine3"] = i_crate_divine3


def render(spec=None, names=("crate_divine", "crate_divine3")):
    if spec:
        R._SPEC = spec
    return R.render(list(names))
