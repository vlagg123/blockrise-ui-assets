"""BlockRise Empire - every Robux item's thumbnail (game passes + developer products) in the premium look of thumbs.py,
numbered in the order of the Creator Hub list (roblox/robux_list_2026-10-07.md), 2026-10-07.

Run in Blender after blender/setup.py (and this file in src):
    import allthumbs; allthumbs.render(out=r"C:/Users/Vlad/BlockRise_thumbnails/Robux_2026-10-07")
    allthumbs.render(["luckboost"], out=...)      # some
Files: <out>/<NN>_<key>.png, 512 x 512. The game passes already rendered by thumbs.py are copied, not rendered again
(pass reuse=False to render them too).

New pictures made here: the packs (5 Builder's, 3 / 10 Golden, 3 Exclusive, 3 Legends) with an x5 / x3 / x10 badge,
the Exclusive Hammer of the Day, 2x Luck (30 min); the cars as products use the pass pictures' models.
"""
import os, shutil
import robux as R
import zonecrates  # (the in-game Builder's, Golden and Exclusive crates)
import setcrates   # (Legends, Pirate Cove, Jungle Temple)
import thumbs as TH
from robux import track, badge, loot_chest, stopwatch

# the Creator Hub list, in order: (number, key, kind)
ORDER = [
    # game passes
    "vip", "bigcrew", "cash2x", "strength2x", "autobuild", "autotrain", "gems2x", "fasttools", "teleporter", "skipanim",
    "quickopen", "autoopen", "luck", "ultraluck", "offline", "hunter",
    # developer products
    "starter", "rushcrew", "cashstack", "cashpack", "cashvault", "cashbank", "cashboost", "luckboost", "spin1", "spins3",
    "gems100", "gems300", "gems750", "gems1700", "gems4500", "gems12000",
    "crate_builder", "crate_builder5", "crate_golden", "crate_golden3", "crate_golden10", "crate_exclusive", "crate_exclusive3",
    "crate_legends", "crate_legends3", "crate_pirate", "crate_temple", "hammer_exclusive", "car_monster", "car_goldcar",
]
NUM = {k: i + 1 for i, k in enumerate(ORDER)}


# ------------------------------------------------------------------------------------------- the new pictures
def _pack(kind, n, label, col):
    """a pile of crates: the open one in front (its light and hammer), the others shut behind it, a count badge"""
    back = {3: [(-1.6, 1.3, 0, 12), (1.7, 1.3, 0, 32)],
            5: [(-2.1, 1.9, 0, 10), (0.1, 2.3, 0, 22), (2.2, 1.7, 0, 34), (-1.95, 0.25, 0, 14), (2.05, 0.15, 0, 30)]}[n]
    for (x, y, z, r) in back:
        track(loot_chest, loc=(x, y, z), rot=(0, 0, r), s=0.66 if n == 5 else 0.74, kind=kind, open_=False)
    track(loot_chest, loc=(0.0, -1.0, 0), rot=(0, 0, 22), s=0.8, kind=kind)
    # (a big count badge: x3 / x5 / x10 must read at a glance, even small in the store)
    track(badge, label, (1.85, -2.4, -0.05), s=1.0, col=col, rot=(-12, 0, 0))


def i_crate_builder5():
    _pack("builder", 5, "x5", "#2f7cf6")


def i_crate_golden3():
    _pack("golden", 3, "x3", "#ff9a1c")


def i_crate_golden10():
    _pack("golden", 5, "x10", "#ff5a1c")


def i_crate_exclusive3():
    _pack("exclusive", 3, "x3", "#d42c9e")


def i_crate_legends3():
    _pack("legends", 3, "x3", "#1f3fc4")


def i_hammer_exclusive():
    """the Exclusive of the Day: two Exclusive hammers crossed, an EXCLUSIVE plate, a star"""
    R._hammer_day(("crown", "prism"), "EXCLUSIVE", "#14b6aa")


def i_luckboost():
    """2x Luck (30 min): a four-leaf clover, a stopwatch, a 2x badge"""
    TH.clover(loc=(-0.55, 0.5, -0.1), s=1.05)
    track(stopwatch, (0.75, -0.55, 0.85), rot=(0, 0, -10), s=0.8)
    track(badge, "2x", (-1.2, -1.1, -0.45), s=0.68, col="#ff9a1c", rot=(-30, 0, 0))


NEW = {"crate_builder5": i_crate_builder5, "crate_golden3": i_crate_golden3, "crate_golden10": i_crate_golden10,
       "crate_exclusive3": i_crate_exclusive3, "crate_legends3": i_crate_legends3, "hammer_exclusive": i_hammer_exclusive,
       "luckboost": i_luckboost, "car_monster": R.ICONS["monster"], "car_goldcar": R.ICONS["goldcar"]}
# (the single crates: the in-game models, registered by zonecrates / setcrates)
for k in ("crate_builder", "crate_golden", "crate_exclusive", "crate_legends", "crate_pirate", "crate_temple"):
    TH.ICONS[k] = R.ICONS[k]
TH.ICONS.update(NEW)

# backdrops: (spotlight, deep edge)
GREEN, GOLD, BLUE, PINK = ("#2fd06a", "#032a12"), ("#ffc534", "#3a2200"), ("#3fb8ff", "#05164a"), ("#ff4fc8", "#2a0630")
TH.LOOK.update({
    "starter": ("#ff5fc0", "#3a0630"), "rushcrew": ("#ffb12e", "#3a1400"), "cashstack": GREEN, "cashpack": GREEN, "cashvault": ("#2fd0a0", "#032a22"),
    "cashbank": ("#ffd23a", "#3a2600"), "cashboost": GREEN, "luckboost": ("#3fe07a", "#03300f"), "spin1": ("#ff5fe0", "#2a0640"),
    "spins3": ("#4fb2ff", "#06123a"), "gems100": BLUE, "gems300": BLUE, "gems750": ("#3f8cff", "#06123a"), "gems1700": ("#a25cff", "#16063a"),
    "gems4500": ("#ff7ad8", "#2a0640"), "gems12000": ("#ffd23a", "#2a0640"),
    "crate_builder5": ("#3f8cff", "#06143a"), "crate_golden3": GOLD, "crate_golden10": ("#ffb02e", "#3a1600"), "crate_exclusive3": PINK,
    "crate_legends3": ("#3f8cff", "#06123a"), "hammer_exclusive": ("#18d6c8", "#032a2a"),
    "car_monster": ("#ff4a5a", "#3a0610"), "car_goldcar": ("#ffd23a", "#3a2600"),
})
for k in ("crate_builder5", "crate_golden3", "crate_golden10", "crate_exclusive3", "crate_legends3"):
    TH.VIEW[k] = (-0.22, -1, 0.38)
TH.VIEW["hammer_exclusive"] = (0, -1, 0.12)
TH.VIEW["luckboost"] = (-0.2, -1, 0.6)
TH.VIEW["car_monster"] = R.VIEW.get("monster", (-0.3, -1, 0.3))
TH.VIEW["car_goldcar"] = R.VIEW.get("goldcar", (-0.45, -1, 0.5))
for k in ORDER:
    if k not in TH.VIEW and k in R.VIEW:
        TH.VIEW[k] = R.VIEW[k]
TH.FILL.update({"hammer_exclusive": 0.82, "car_goldcar": 0.84, "car_monster": 0.82})


def render(names=None, out=None, reuse=True, size=1024, samples=128):
    """render (or copy) each item into out/<NN>_<key>.png"""
    names = names or ORDER
    out = out or os.path.join(TH.OUT, "all")
    os.makedirs(out, exist_ok=True)
    done = []
    for k in names:
        dest = os.path.join(out, "%02d_%s.png" % (NUM[k], k))
        old = os.path.join(TH.OUT, k + ".png")
        if reuse and k in TH.PASSES and os.path.exists(old):
            shutil.copyfile(old, dest)
        else:
            TH.render([k], size=size, samples=samples)
            shutil.copyfile(old, dest)
        done.append(os.path.basename(dest))
    return done
