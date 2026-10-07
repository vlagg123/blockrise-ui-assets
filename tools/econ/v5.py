"""Economy v5 (the owner's decisions, 2026-10-07 14:06-14:29), on top of Economy v4 (final_econ_v2.json):
  * the Rebirth needs CASH IN HAND (players save; the simulator's "saver" stops buying what won't pay back in time)
  * the Rebirth is harder (Rebirth 1 ~30 min for an active free player, every run longer than in v4)
  * no free crates while just playing: the free Supply every 6 contracts and the Builder's drop are gone; crates come
    only from missions: the daily set (a Supply Crate of your zone), a daily Builder's Order (a Builder's Crate) and a
    weekly Golden Order (a Golden Crate), each taking about the play the crate's Gems would take to farm
Usage: python3 v5.py [calibrate]"""
import copy, json, math, sys, statistics as st
import sim, final_v2, proposal as P, tables

# hours of play in a day, by player type (the daily / weekly missions follow the days)
DAY_H = {"active": 2.0, "casual": 0.75, "payer": 2.0, "whale": 3.0}

# pacing target, minutes of play from the first join (v4 was 17 / 52 / 135 / 270 / 520 / 900 / 1500)
TARGET = {1: 30, 2: 90, 3: 220, 4: 430, 5: 780, 6: 1250, 7: 1950}

MISSIONS = dict(
    daily_contracts=8,                                           # the 3 daily missions ~ this many contracts of play
    builder_n={"town": 70, "suburbs": 45, "downtown": 30},       # Builder's Order: N contracts in a day -> Builder's (1/day)
    golden_n={"town": 260, "suburbs": 170, "downtown": 110},     # Golden Order: N contracts in a week ...
    golden_days=4,                                               # ... and the daily set on 4 days -> Golden (1/week)
)


def player(name, **kw):
    p = dict(sim.PLAYERS[name])
    p["day_h"] = DAY_H[name]
    p.update(kw)
    return p


# Empire Road steps that give a crate (once per account): they replace the free drops of the first runs, so a new
# builder still gets better hammers while learning the loop (hammer rarity is x2 build power per step)
ROAD_CRATES = [("built", "garage", "supply"), ("workers", 2, "builder"), ("built", "shop", "supply"),
               ("reb", 1, "builder"), ("reb", 2, "golden")]


def road_crates(s):
    done = getattr(s, "road_done", set())
    s.road_done = done
    for kind, key, crate in s.E.get("road_crates", []):
        if (kind, key) in done:
            continue
        if (kind == "built" and s.built.get(key)) or (kind == "reb" and s.R >= key) or (kind == "workers" and len(s.workers) >= key):
            done.add((kind, key))
            sim.open_crate(s, sim.zone_supply(s) if crate == "supply" else crate, "road")


def mission_crates(s, dt, c):
    E = s.E
    M = E["missions"]
    road_crates(s)
    dh = s.P.get("day_h", 2.0)
    s.mplay = getattr(s, "mplay", 0.0) + dt / 3600
    day = int(s.mplay // dh)
    if day != getattr(s, "mday", -1):
        if getattr(s, "mday", -1) >= 0 and getattr(s, "daily_done", False):
            s.days_done = getattr(s, "days_done", 0) + 1
        s.mday = day
        s.c_today, s.daily_done, s.builder_done = 0, False, False
        if day // 7 != getattr(s, "mweek", -1):
            s.mweek = day // 7
            s.c_week, s.days_done, s.golden_done = 0, 0, False
    s.c_today += 1
    s.c_week += 1
    zone = sim.zone_supply(s).split("_")[1]
    if not s.daily_done and s.c_today >= M["daily_contracts"]:
        s.daily_done = True
        sim.open_crate(s, sim.zone_supply(s), "mission")
    if M.get("builder_n") and not s.builder_done and s.c_today >= M["builder_n"][zone]:
        s.builder_done = True
        sim.open_crate(s, "builder", "mission")
    if M.get("golden_n") and not s.golden_done and s.c_week >= M["golden_n"][zone] \
            and s.days_done + (1 if s.daily_done else 0) >= M["golden_days"]:
        s.golden_done = True
        sim.open_crate(s, "golden", "mission")


def costs_fn(L):
    return lambda n, L=L: L[n] if n < len(L) else L[-1] * 3 ** (n - len(L) + 1)


def build(costs=None, missions=MISSIONS, saver=True):
    E = final_v2.load()
    E["name"] = "V5"
    E["reb_cash"] = True
    E["reb_cash_saver"] = saver
    E["free_crate_every"] = None
    E["builder_drop"] = 0.0
    E["missions"] = copy.deepcopy(missions)
    E["road_crates"] = list(ROAD_CRATES)
    E["mission_crates"] = mission_crates
    if costs:
        E["reb_costs"] = list(costs)
        E["rebirth_cost"] = costs_fn(E["reb_costs"])
    return E


def v4_with_days():
    E = final_v2.load()
    E["name"] = "V4"
    return E


def calibrate(E, upto=7, name="active", seeds=(1,), target=TARGET):
    """each Rebirth's cost so that the reference player's run lasts what the target says (bisection on the cost, one
    Rebirth at a time; the earlier ones are already fixed)"""
    L = E["reb_costs"]
    for n in range(upto):
        want = (target[n + 1] - (target[n] if n > 0 else 0))
        lo, hi = math.log(L[n] / 30), math.log(L[n] * 30)
        for _ in range(8):
            mid = (lo + hi) / 2
            L[n] = math.exp(mid)
            E["rebirth_cost"] = costs_fn(L)
            durs = []
            for seed in seeds:
                s = sim.simulate(E, player(name), hours=target[n + 1] / 60 * 2.2 + 1, seed=seed, max_rebirths=n + 1)
                r = s.events["rebirth"]
                if len(r) <= n:
                    durs.append(1e9)
                else:
                    durs.append((r[n] - (r[n - 1] if n > 0 else 0)) / 60)
            d = st.mean(durs)
            if d > want:
                hi = mid
            else:
                lo = mid
        L[n] = P.nice(math.exp((lo + hi) / 2))
        E["rebirth_cost"] = costs_fn(L)
        print("R%d cost %s (run %.0f min wanted %d)" % (n + 1, tables.short(L[n]), d, want), flush=True)
    return E


def pacing(E, name, hours=40, upto=7, seeds=range(1, 6), **kw):
    rows = []
    for seed in seeds:
        s = sim.simulate(E, player(name, **kw), hours=hours, seed=seed, max_rebirths=upto)
        r = [x / 60 for x in s.events["rebirth"][:upto]]
        rows.append(r + [None] * (upto - len(r)))
    out = []
    for k in range(upto):
        v = [r[k] for r in rows if r[k] is not None]
        out.append(round(st.mean(v), 1) if len(v) == len(rows) else None)
    return out


def hm(m):
    if m is None:
        return "—"
    return "%d min" % round(m) if m < 60 else "%d h %02d" % (m // 60, round(m % 60))


if __name__ == "__main__":
    if "calibrate" in sys.argv:
        E = build()
        calibrate(E)
        json.dump(dict(reb_costs=E["reb_costs"], target=TARGET, missions=MISSIONS), open("final_econ_v5.json", "w"), indent=1)
    else:
        d = json.load(open("final_econ_v5.json"))
        E = build(d["reb_costs"])
    print("costs", [tables.short(E["rebirth_cost"](n)) for n in range(8)])
    for name in ("active", "casual", "payer", "whale"):
        print(name, [hm(x) for x in pacing(E, name)], flush=True)
