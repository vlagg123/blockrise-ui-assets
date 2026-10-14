"""BlockRise Empire - crates V8 + hammer bonuses on the V7 simulator (2026-10-14).

The owner asked: with the new crate odds (CRATES_V8c), the Exclusive at x256 and every hammer's own bonuses
(HAMMER_PERKS), do players get too strong too fast? This plays the V7 economy (proposal.py, the live one) with:
  * the crates' odds as they are in the game now (9 rarities, Exclusive included);
  * the hammer in hand chosen by build power x its power bonus; its cash / power / strength / crew bonuses applied
    (Main's Economy "Hammer" contributor);
  * a free player spending its Gems on Golden Crates (750) as it earns them (the old sim kept them);
  * payers who open Robux crates right after the tutorial.
It compares the minutes to every Rebirth with the V7 baseline (old odds, no bonuses).

    python3 sim8.py
"""
import copy, random, sys
import sim7
import proposal as PR
from sim7 import PLAYER, hammer_power

CASUAL = dict(PLAYER, cps=3.5, active=0.7, combo=1.6, job_overhead=18, train_overhead=15, crate_share=0.15, spend_share=0.35)

OLD_ODDS = dict(sim7.CRATE_ODDS)
OLD_ODDS["legends"] = [0, 0, 0, 0, 70, 24, 6, 0]
NEW_ODDS = {
    "supply": [75, 20, 4, 1, 0, 0, 0, 0, 0],
    "supply_suburbs": [52, 33, 12, 2.6, 0.4, 0, 0, 0, 0.0005],
    "supply_downtown": [0, 55, 33, 10.798, 1.1, 0.08, 0.015, 0.006, 0.001],
    "builder": [0, 50, 35.498, 12, 1.85, 0.5, 0.1, 0.05, 0.002],
    "golden": [0, 0, 55.39, 33, 9.4, 1.3, 0.6, 0.3, 0.01],
    "legends": [0, 0, 0, 0, 54.96, 33, 12, 0, 0.04],
    "exclusive": [0, 0, 0, 0, 0, 77, 14, 6, 3],
    "divine": [0, 0, 0, 0, 0, 0, 65, 28.33, 6.67],
}
# the normal hammers by rarity (no sets) and their bonuses (Hammers.Perks); the Exclusives with their crate weights
POOL = {
    1: ["iron"], 2: ["gold"],
    3: ["emerald", "ruby", "obsidian", "jade", "candy"],
    4: ["sapphire", "amethyst", "dragon", "clockwork", "robo"],
    5: ["lava", "frost", "phoenix", "tsunami", "cyber"],
    6: ["diamond", "plasma", "void"],
    7: ["solar", "blackhole", "demon"],
    8: ["galaxy", "celestial"],
    9: ["crown", "ghost", "prism", "thunder"],  # (EQUAL_ODDS 2026-10-14: the same chance each)
}
PERKS = {
    "emerald": {"luck": .05}, "ruby": {"power": .05}, "obsidian": {"strength": .05}, "jade": {"crew": .05}, "candy": {"cash": .05},
    "sapphire": {"power": .10}, "amethyst": {"luck": .10}, "dragon": {"strength": .10}, "clockwork": {"crew": .10}, "robo": {"cash": .10},
    "lava": {"power": .25}, "frost": {"luck": .25}, "phoenix": {"strength": .20}, "tsunami": {"cash": .25}, "cyber": {"crew": .30},
    "diamond": {"cash": .50, "luck": .15}, "plasma": {"power": .50, "crew": .15}, "void": {"luck": .50, "power": .15},
    "solar": {"power": .75, "strength": .30}, "blackhole": {"luck": .75, "cash": .30}, "demon": {"strength": .60, "power": .30},
    "galaxy": {"luck": 1.0, "power": .40, "cash": .25}, "celestial": {"cash": 1.0, "strength": .40, "crew": .25},
    "thunder": {"power": 1.5, "crew": .5, "strength": .5, "cash": .3}, "prism": {"luck": 1.5, "cash": .5, "power": .5, "strength": .3},
    "crown": {"cash": 1.5, "power": .5, "luck": .5, "crew": .3}, "ghost": {"crew": 1.5, "cash": .5, "strength": .5, "luck": .3},
}

MODE = {"perks": False, "gem_crates": False}


class HL(list):
    """a hammer [rarity, level] (unpacks to two, like sim7's) that also knows which hammer it is"""
    key = ""


def make(r, key):
    h = HL([r, 1])
    h.key = key
    return h


def perk(h, kind):
    return PERKS.get(getattr(h, "key", ""), {}).get(kind, 0) if MODE["perks"] else 0


def score(h):
    # (the player holds the hammer that builds the most: power x its own power bonus)
    return hammer_power(h[0], h[1]) * (1 + perk(h, "power"))


def hammer_now(st):
    return max(st.hammers, key=score)


def open_crate(st, crate, rng):
    odds = sim7.CRATE_ODDS[crate]
    x = rng.random() * sum(odds)
    for i, o in enumerate(odds):
        x -= o
        if x <= 0:
            r = i + 1
            st.hammers.append(make(r, rng.choice(POOL[r])))
            if r >= 8: st.events.append((st.t, f"{'DIVINE' if r == 8 else 'EXCLUSIVE'} from {crate}"))
            break
    st.crates_opened[crate] = st.crates_opened.get(crate, 0) + 1
    st.hammers.sort(key=lambda h: -score(h))
    del st.hammers[6:]


_cash, _str, _power, _crew = sim7.cash_mult, sim7.str_mult, sim7.power_mult, sim7.crew_mult


def cash_mult(E, st): return _cash(E, st) * (1 + perk(hammer_now(st), "cash"))
def str_mult(E, st): return _str(E, st) * (1 + perk(hammer_now(st), "strength"))
def power_mult(E, st): return _power(E, st) * (1 + perk(hammer_now(st), "power"))


def crew_mult(E, st):
    r, lv = hammer_now(st)[0], hammer_now(st)[1]
    return hammer_power(r, lv) * power_mult(E, st) * (1 + 0.15 * st.dept["crew"]) * (1 + perk(hammer_now(st), "crew"))


_shop = sim7.shop


def shop(E, st, P, rng, next_c):
    _shop(E, st, P, rng, next_c)
    # a free player opens a Golden Crate whenever it has the Gems (750)
    if MODE["gem_crates"]:
        while st.gems >= 750:
            st.gems -= 750
            open_crate(st, "golden", rng)
            st.t += 1.5


for name, fn in dict(hammer_now=hammer_now, open_crate=open_crate, cash_mult=cash_mult, str_mult=str_mult,
                     power_mult=power_mult, crew_mult=crew_mult, shop=shop).items():
    setattr(sim7, name, fn)

_sim = sim7.simulate


def simulate_with(E, P, seed, until_R, robux=None):
    """robux: crates opened right after the tutorial, e.g. {"divine": 3}"""
    if robux:
        orig_road = sim7.road
        done = {"x": False}

        def road(E2, st, rng):
            orig_road(E2, st, rng)
            if not done["x"] and st.completed >= 2:
                done["x"] = True
                for crate, n in robux.items():
                    for _ in range(n):
                        if crate in PERKS:
                            st.hammers.append(make(9, crate))   # (a hammer bought outright: the Exclusive of the Day)
                        else:
                            open_crate(st, crate, rng)
        sim7.road = road
        try:
            return _sim(E, P, seed=seed, until_R=until_R, max_hours=60)
        finally:
            sim7.road = orig_road
    return _sim(E, P, seed=seed, until_R=until_R, max_hours=60)


def run(E, P, label, robux=None, seeds=range(1, 9), until_R=5):
    rs = [simulate_with(E, P, s, until_R, robux) for s in seeds]
    cols = []
    for R in range(1, until_R + 1):
        ts = [r.rebirth_at.get(R) for r in rs if r.rebirth_at.get(R)]
        cols.append(f"R{R} {sum(ts) / len(ts) / 60:6.1f}m" if len(ts) == len(rs) else f"R{R} {'n/a':>7}")
    best = [hammer_now(r) for r in rs]
    top = sum(1 for b in best if b[0] >= 8)
    rar = sorted(b[0] for b in best)
    print(f"{label:34}", "  ".join(cols), f"| best hammer rarity (median) {rar[len(rar) // 2]}, Divine+ in {top}/{len(rs)} runs")
    return rs


if __name__ == "__main__":
    E = PR.base_proposal()
    E["road"] = PR.road_v7(E)
    PR.tune(E, verbose=False)
    print("minutes of play to each Rebirth (8 seeds)\n")
    for P, who in ((PLAYER, "active"), (CASUAL, "casual")):
        # V7 as it was this morning: old odds, no bonuses, Gems kept
        sim7.CRATE_ODDS.clear(); sim7.CRATE_ODDS.update(OLD_ODDS)
        MODE.update(perks=False, gem_crates=False)
        run(E, P, f"V7 (this morning), {who}")
        # V8: the odds now in the game + every hammer's bonuses, Gems into Golden Crates
        sim7.CRATE_ODDS.clear(); sim7.CRATE_ODDS.update(NEW_ODDS)
        MODE.update(perks=True, gem_crates=True)
        run(E, P, f"V8 free player, {who}")
        if P is PLAYER:
            run(E, P, "V8 + 1 Exclusive Crate (999)", robux={"exclusive": 1})
            run(E, P, "V8 + 3 Divine Crates (3,999)", robux={"divine": 3})
            run(E, P, "V8 + 10 Divine Crates (~13,000)", robux={"divine": 10})
            run(E, P, "V8 + Royal Crown (Hammer of Day)", robux={"crown": 1})
            run(E, P, "V8 + Thunderclap (Hammer of Day)", robux={"thunder": 1})
