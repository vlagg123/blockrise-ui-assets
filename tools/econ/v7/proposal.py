"""Economy v7 proposal (2026-10-14): ZONE_CHAIN + fixed zone crates + a real Training Yard + a Road scaled to the zone.

Builds on sim7.live_econ() (today's live numbers) and tunes the 15 new buildings on the simulator:
  * XP: the 5 new buildings of a zone + the 5 old ones once = exactly the XP from the zone's Rebirth Level to the next
    (Level 12 / 35 / 55 stay). Built in order: a building opens only once the one before it in its zone is built.
  * Strength gate of a new building: what the player has right after the previous first build + TRAIN_S seconds of
    training at that moment's rate (the Training Yard is where you get it; building old ones is ~3x slower for it).
  * Work of a new building: its first build, at its gate, with that moment's crew / hammer / machines, takes BUILD_S.
  * Pay grows by PAY_STEP a building; targetTime (speed bonus) = BUILD_S.
Run: python3 proposal.py
"""
import copy, math, json, os
import sim7
from sim7 import *

ROAD_BUILDS = {0: 1, 1: 1, 2: 1}   # a Road step pays this many builds of its building (the gear is bought again after a Rebirth)
TRAINING_STATIONS = [(0, 2), (4000, 4), (150000, 8), (5000000, 16)]     # today 1 / 1.5 / 2.5 / 4

NEW = {
    # zone: after which building, the 5 new (id, name, blueprint kind, crew), pay step, first-build seconds, training seconds
    "town": dict(after="shop", reb=0, pay_step=1.32, names=[
        ("bakery", "Corner Bakery", 3), ("carwash", "Car Wash", 4), ("clinic", "Town Clinic", 4),
        ("firestation", "Fire Station", 5), ("townhall", "Town Hall", 6)],
        build_s=[60, 70, 80, 90, 100], train_s=[45, 50, 60, 70, 80]),
    "suburbs": dict(after="distcenter", reb=1, pay_step=1.45, names=[
        ("plaza", "Shopping Plaza", 6), ("arena", "Sports Arena", 7), ("hospital", "Hospital", 7),
        ("waterpark", "Water Park", 8), ("mall", "Suburb Mall", 8)],
        build_s=[30, 35, 40, 45, 50], train_s=[10, 10, 15, 15, 20]),
    "downtown": dict(after="hotel", reb=2, pay_step=1.35, names=[
        ("banktower", "Bank Tower", 8), ("concert", "Concert Hall", 9), ("museum", "City Museum", 9),
        ("twintowers", "Twin Towers", 10), ("stadium", "City Stadium", 10)],
        build_s=[45, 50, 55, 60, 65], train_s=[20, 20, 25, 25, 30]),
}
LEVEL_GAP = {0: (1, 12), 1: (12, 35), 2: (35, 55)}
# the verbs (stage mix) the new blueprints will have, like their old neighbours
VERB_LIKE = {"town": "shop", "suburbs": "distcenter", "downtown": "hotel"}


def sig(x, d=2):
    if x <= 0: return 0
    e = 10 ** (math.floor(math.log10(x)) - d + 1)
    return round(x / e) * e


def xp_ladder(old_xps, need):
    rest = need - sum(old_xps)
    last = old_xps[-1]
    lo, hi = 1.01, 6.0
    for _ in range(200):
        r = (lo + hi) / 2
        if sum(last * r ** k for k in range(1, 6)) < rest: lo = r
        else: hi = r
    xs = [sig(last * r ** k) for k in range(1, 6)]
    xs[-1] += rest - sum(xs)
    return xs, r


def base_proposal():
    E = live_econ()
    E["name"] = "PROPOSAL v7"
    E["stations"] = list(TRAINING_STATIONS)
    E["order_gate"] = True
    E["crate_price"] = "fixed"
    E["crate_fixed"] = {"town": 150, "suburbs": 88000, "downtown": 16_000_000}
    # insert the new contracts (placeholders: gates and work are tuned below)
    cs = E["contracts"]
    for zone, spec in NEW.items():
        old = [c for c in cs if c["reb"] == spec["reb"] and c["zone"] == zone]
        lo, hi = LEVEL_GAP[spec["reb"]]
        need = total_xp(hi) - total_xp(lo)
        xs, r = xp_ladder([c["xp"] for c in old], need)
        spec["xp"] = xs
        idx = next(i for i, c in enumerate(cs) if c["id"] == spec["after"])
        prev = cs[idx]
        like = next(c for c in cs if c["id"] == VERB_LIKE[zone])
        pay = prev["reward"]
        new = []
        for k, (cid, name, crew) in enumerate(spec["names"]):
            pay = sig(pay * spec["pay_step"])
            new.append(dict(id=cid, name=name, zone=zone, reward=pay, xp=xs[k], reqS=None, crew=crew, reb=spec["reb"],
                            work=None, verbs=dict(like["verbs"]), target=spec["build_s"][k], order=0, new=True))
        cs[idx + 1:idx + 1] = new
    for i, c in enumerate(cs): c["order"] = i + 1
    # the Empire Road: a "Build X" step pays one build of X (with the Rebirth bonus of its zone), the other steps of a
    # chapter half of the next building's pay; crates as today
    return E


def road_v7(E):
    """the Empire Road v7 (hand-written): the tutorial as it is; then a chapter a zone along the chain. Cash: Town about one
    build of the step's building; Suburbs and Downtown keep today's amounts for today's steps (they help to buy the gear and
    the crew again after a Rebirth) and ~2 builds for the new buildings. Crates on 5 steps as today. After Rebirth 3:
    today's steps."""
    live = E["road"]
    R = [dict(s) for s in live[:7]]
    M = 1e6
    def add(title, stat, target, cash, gems, crate=None, place="board"):
        R.append(dict(title=title, stat=stat, target=target, cash=int(cash), gems=gems, crate=crate, place=place))
    # Chapter 1: Town
    add("Build the Garden Shed", "Built_shed", 1, 200, 5)
    add("Hire 2 workers", "Workers", 2, 300, 10, "builder", "hire")
    add("Build the Brick Garage", "Built_garage", 1, 500, 10, "supply")
    add("Your first upgrade", "DeptLevels", 1, 400, 5, None, "upgrades")
    add("Build the Family House", "Built_house", 1, 1000, 10)
    add("Lifting Belt", "GearTier", 3, 500, 10, None, "gearshop")
    add("Build the Corner Shop", "Built_shop", 1, 2500, 15, "supply")
    add("Build the Corner Bakery", "Built_bakery", 1, 3000, 10)
    add("Open 10 Town crates", "CratesOpened", 10, 2000, 10, None, "shop")
    add("Build the Car Wash", "Built_carwash", 1, 4000, 15)
    add("A crew of 4", "Workers", 4, 3000, 10, None, "hire")
    add("Build the Town Clinic", "Built_clinic", 1, 5000, 15)
    add("Build the Fire Station", "Built_firestation", 1, 7000, 15)
    add("Build the Town Hall", "Built_townhall", 1, 10000, 20, "builder")
    add("Level 12 → Rebirth 1", "Rebirths", 1, 5000, 25, "builder", "rebirth")
    # Chapter 2: Suburbs
    add("Build the Villa", "Built_villa", 1, 0.3 * M, 10)
    add("Concrete Mixer", "Owns_mixer", 1, 0.3 * M, 10, None, "machines")
    add("A crew of 6", "Workers", 6, 0.5 * M, 10, None, "hire")
    add("An upgrade at level 5", "DeptMax", 5, 0.5 * M, 10, None, "upgrades")
    add("Build the Warehouse", "Built_warehouse", 1, 1 * M, 15)
    add("A Builder's Order", "BuilderOrders", 1, 1.5 * M, 15, None, "missions")
    add("Your first trade-up", "TradeUps", 1, 1.5 * M, 15, None, "tradeup")
    add("Build the Apartments", "Built_apartments", 1, 3 * M, 15)
    add("Build the Luxury Villa", "Built_luxvilla", 1, 7 * M, 20)
    add("Build the Distribution Center", "Built_distcenter", 1, 8 * M, 20)
    add("Build the Shopping Plaza", "Built_plaza", 1, 4 * M, 15)
    add("Your first property", "PropertyCount", 1, 4 * M, 15, None, "company")
    add("Build the Sports Arena", "Built_arena", 1, 5 * M, 15)
    add("Build the Hospital", "Built_hospital", 1, 7 * M, 20)
    add("Build the Water Park", "Built_waterpark", 1, 10 * M, 20)
    add("Build the Suburb Mall", "Built_mall", 1, 15 * M, 25, "builder")
    add("Level 35 → Rebirth 2", "Rebirths", 2, 9 * M, 25, "golden", "rebirth")
    # Chapter 3: Downtown
    add("Build the Office Tower", "Built_office", 1, 40 * M, 15, None, "downtown")
    add("Builder's Helmet I", "Helmet", 1, 40 * M, 15, None, "upgrades")
    add("Buy the Crane", "Owns_crane", 1, 40 * M, 15, None, "machines")
    add("Build the Grand Hotel", "Built_hotel", 1, 100 * M, 20, None, "downtown")
    add("Build the Bank Tower", "Built_banktower", 1, 100 * M, 20, None, "downtown")
    add("A Star Shop perk", "StarPerks", 1, 100 * M, 15, None, "rebirth")
    add("Build the Concert Hall", "Built_concert", 1, 120 * M, 20, None, "downtown")
    add("Build the City Museum", "Built_museum", 1, 160 * M, 20, None, "downtown")
    add("Build the Twin Towers", "Built_twintowers", 1, 220 * M, 20, None, "downtown")
    add("Build the City Stadium", "Built_stadium", 1, 300 * M, 25, "golden", "downtown")
    add("A Golden Order", "GoldenOrders", 1, 300 * M, 20, None, "missions")
    add("Level 55 → Rebirth 3", "Rebirths", 3, 700 * M, 25, None, "rebirth")
    k = next(i for i, s in enumerate(live) if s["stat"] == "Built_skyscraper")
    R += [dict(s) for s in live[k:]]
    return R

def tune(E, P=PLAYER, seed=1, verbose=True):
    """set reqS and work of every new building, in order, on the simulator"""
    for c in E["contracts"]:
        if c.get("new") and c["reqS"] is None:
            c["reqS"], c["work"] = 1e30, 1e30          # closed until tuned
    for zone, spec in NEW.items():
        for k, (cid, _, _) in enumerate(spec["names"]):
            c = next(x for x in E["contracts"] if x["id"] == cid)
            prev = E["contracts"][E["contracts"].index(c) - 1]
            # play until the previous building is built for the first time, look at the player then
            st = simulate_until(E, P, seed, prev["id"])
            rate = reps_per_s(st, P) * station(E, st)[1] * str_mult(E, st)
            c["reqS"] = sig(max(st.S * 1.05, st.S + spec["train_s"][k] * rate), 2)
            # the work: the first build at the gate takes build_s (the player's power at the gate)
            S0 = st.S
            st.S = c["reqS"]
            c["work"] = 1.0
            t1, _, _ = build_time(E, st, c, P)          # seconds for 1 unit of work
            c["work"] = sig(spec["build_s"][k] / t1, 3)
            st.S = S0
            if verbose:
                print(f"  {cid:12} xp {c['xp']:>9,}  pay ${c['reward']:>12,}  crew {c['crew']:>2}  gate S {c['reqS']:>14,.0f}  work {c['work']:>14,.0f}"
                      f"   (at prev: S {S0:,.0f}, train {rate:,.0f}/s, t={st.t/60:.1f} min)")
    # refine: the real first builds (the player hires / opens crates between the previous build and this one)
    for _ in range(3):
        runs = [simulate(E, P, seed=sd, until_R=3) for sd in (1, 2, 3)]
        for zone, spec in NEW.items():
            for k, (cid, _, _) in enumerate(spec["names"]):
                c = next(x for x in E["contracts"] if x["id"] == cid)
                got = [r.first_t[cid] for r in runs if cid in r.first_t]
                if got:
                    c["work"] = sig(c["work"] * spec["build_s"][k] / (sum(got) / len(got)), 3)
    # Rebirth 3-5 (Skyscraper, HQ, Spire): their Strength gates keep the time to R4 / R5 as today (the City Stadium's
    # XP would make them shorter otherwise)
    for cid, g in (("skyscraper", 1.0e9), ("hq", 2.5e9), ("spire", 8e9)):
        next(x for x in E["contracts"] if x["id"] == cid)["reqS"] = g
    if verbose:
        for c in E["contracts"]:
            if c.get("new"):
                print(f"  {c['id']:12} final work {c['work']:>14,.0f}  gate {c['reqS']:>14,.0f}")
    return E


def simulate_until(E, P, seed, first_id):
    """the simulator, stopped right after the first build of `first_id`"""
    import sim7 as S7
    orig = S7.do_build
    hit = {}
    class Stop(Exception): pass
    def wrapped(E_, st, c, P_, rng):
        r = orig(E_, st, c, P_, rng)
        if c["id"] == first_id and st.built.get(c["id"]) == 1:
            hit["st"] = st
            raise Stop()
        return r
    S7.do_build = wrapped
    try:
        S7.simulate(E, P, seed=seed, until_R=3)
    except Stop:
        pass
    finally:
        S7.do_build = orig
    return hit.get("st")


if __name__ == "__main__":
    E = base_proposal()
    E['road'] = road_v7(E)
    tune(E)
    report(live_econ())
    report(E)
