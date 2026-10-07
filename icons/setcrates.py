# setcrates.py - the three crates of SETS_V1 (2026-10-07), the same loot chest as the others (robux.loot_chest), each
# with its own colours and its star hammer standing out of the light:
#   legends   the second Exclusive Crate: royal blue, gold straps, the Chrono Hammer
#   pirate    Pirate Cove: dark ship's wood with iron straps, sea-blue light, the Kraken King
#   temple    Jungle Temple: sandstone with gold, green light, the Sun Temple Hammer
# Run in Blender after blender/setup.py:  import setcrates; setcrates.render()  (spec = the hammers' spec.json to use)
import robux as R

R.CRATE_LOOK["legends"] = dict(body=("#2f5bff", None, None, None), lid="#1f3fc4", trim=("#ffc534", 1.0), inner="#0b1650",
                               glow="#9fe8ff", ray="#4fb2ff", gem=None, hammer="chrono", pose=(0.0, -15.0, -45.0))
R.CRATE_LOOK["pirate"] = dict(body=("#8a5530", "grain", "#6a3e20", "#a66a3c"), lid="#74431f", trim=("#4a505e", 0.9), inner="#22130a",
                              glow="#8ff0ff", ray="#2f9dff", gem=None, hammer="kraken", pose=(0.0, -15.0, -45.0))
R.CRATE_LOOK["temple"] = dict(body=("#d9b06e", None, None, None), lid="#b88a46", trim=("#ffc534", 1.0), inner="#2e2208",
                              glow="#c8ff8f", ray="#3fcf5c", gem=None, hammer="suntemple", pose=(0.0, -15.0, -45.0))
R.CARD["crate_legends"] = ("#a8d8ff", "#14287a")
R.CARD["crate_pirate"] = ("#9fe0ff", "#0f3a5a")
R.CARD["crate_temple"] = ("#d8ffb0", "#1f5a1a")
for k in ("crate_legends", "crate_pirate", "crate_temple"):
    R.VIEW[k] = (-0.3, -1, 0.4)
    R.SPARK[k] = []


def i_crate_legends():
    R.track(R.loot_chest, rot=(0, 0, 22), kind="legends")
    R.track(R.gem, R.BLUE_GEM, loc=(-0.8, -0.2, 1.5), rot=(12, 0, 25), s=0.32)
    R.track(R.gem, R.BLUE_GEM, loc=(2.0, -1.15, 0.45), rot=(8, 0, -20), s=0.4)


def i_crate_pirate():
    R.track(R.loot_chest, rot=(0, 0, 22), kind="pirate")
    R.track(R.coin, loc=(-0.78, -0.25, 1.42), rot=(62, 0, 24), r=0.36)
    R.track(R.coin, loc=(2.0, -1.15, 0.42), rot=(75, 0, -25), r=0.42)
    R.track(R.coin, loc=(-2.05, -0.95, 0.42), rot=(75, 0, 25), r=0.4)


def i_crate_temple():
    R.track(R.loot_chest, rot=(0, 0, 22), kind="temple")
    R.track(R.gem, R.GREEN_GEM, loc=(-0.8, -0.2, 1.5), rot=(12, 0, 25), s=0.32)
    R.track(R.gem, R.GREEN_GEM, loc=(2.0, -1.15, 0.45), rot=(8, 0, -20), s=0.4)


R.ICONS["crate_legends"] = i_crate_legends
R.ICONS["crate_pirate"] = i_crate_pirate
R.ICONS["crate_temple"] = i_crate_temple


def render(spec=None, names=("crate_legends", "crate_pirate", "crate_temple")):
    if spec:
        R._SPEC = spec
    return R.render(list(names))
