"""The road check: every contract must actually be used in the run where it is new (a player who picks the best-paying
contract builds it), otherwise it is dead content.
- Training stations are halved (x1 / x1.5 / x2.5 / x4): training is a side option, never a way to skip the road.
- In Suburbs, Warehouse and Luxury Villa paid less per unit of work than the contract before them, so nobody built
  them: the Suburbs road becomes a ladder of pay per work (villa 1.9 -> warehouse 3 -> apartments 5.2 -> luxvilla 6.5
  -> distcenter 8.5).
Then the Rebirth costs are recalibrated to the pacing targets. Usage: python3 road.py -> final_econ.json"""
import json
from collections import Counter, defaultdict
import sim, final, proposal as P, tables

STATIONS = [(0, 1.0), (4000.0, 1.5), (150000.0, 2.5), (5000000.0, 4.0)]
LADDER = {"warehouse": 3.0, "luxvilla": 6.5, "distcenter": 8.5}


def uses(E, player="active", hours=12, seed=1):
    s = sim.simulate(E, sim.PLAYERS[player], hours=hours, seed=seed, record=True)
    cnt = defaultdict(Counter)
    for (tt, cid, dur, R, share, hits) in s.contract_log:
        cnt[R][cid] += 1
    return s, cnt


def road_fix(E):
    E["stations"] = list(STATIONS)
    for c in E["contracts"]:
        if c["id"] in LADDER:
            base = sum(sim.VERBS[c["id"]].values())
            c["workMult"] = c["reward"] / LADDER[c["id"]] / base
    P.calibrate_rebirths(E, upto=6)
    L = E["reb_costs"]
    L[6] = P.nice(L[5] * max(4.0, L[5] / L[4]) * 1.5)
    return E


if __name__ == "__main__":
    E, p = final.build()
    road_fix(E)
    tables.monotonic(E)
    json.dump(dict(params=final.BEST, stations=E["stations"], reb_costs=E["reb_costs"], contracts=E["contracts"],
                   props={k: list(v) for k, v in E["props"].items()}), open("final_econ.json", "w"), indent=1, default=str)
    print("costs", [tables.short(x) for x in E["reb_costs"]])
    for name in ("active", "casual"):
        s, cnt = uses(E, name)
        print(name, sim.report(s)["rebirth_minutes"][:6], "train min", round(s.train_time / 60))
        for R in range(3):
            print("    run", R, dict(cnt[R].most_common()))
