"""Every number of the recipe, from final_econ.json (made by road.py): python3 report_final.py"""
import json, copy
from collections import Counter, defaultdict
import sim, final, proposal as P, tables, crates

sh = tables.short


def load():
    d = json.load(open("final_econ.json"))
    p = dict(P.DEFAULT); p.update(final.BEST)
    E = P.build(p)
    E["contracts"] = d["contracts"]
    E["reb_costs"] = d["reb_costs"]
    E["stations"] = [tuple(x) for x in d["stations"]]
    return E, p


if __name__ == "__main__":
    E, p = load()
    print("## Rebirths")
    for n in range(7):
        print(f"R{n + 1}: earn {sh(E['rebirth_cost'](n))} | after: cash x{E['rebirth_cash'](n + 1):.1f} strength x{E['rebirth_strength'](n + 1):.2f}")
    s = sim.simulate(E, sim.PLAYERS["active"], hours=12, record=True)
    first = {}
    for (tt, cid, dur, R, share, hits) in s.contract_log:
        if (R, cid) not in first: first[(R, cid)] = dur
    print("## Contracts")
    for c in E["contracts"]:
        w = sum(sim.VERBS[c["id"]].values()) * c["workMult"]
        fb = first.get((P.NEW_IN[c["id"]], c["id"]))
        print(f"{c['id']:11s} {c['zone']:9s} R{c['reqReb']} reward {sh(c['reward']):>6s} work {sh(w):>6s} str {sh(c['reqStr']):>6s} crew {c['reqCrew']} first build {fb and round(fb)} s")
    print("## Pacing")
    for name in ("active", "casual", "payer", "whale"):
        s = sim.simulate(E, sim.PLAYERS[name], hours=14, record=True)
        r = sim.report(s)
        print(name, r["rebirth_minutes"][:6], "gems/h", r["gems_h"], "crates", r["crates"], "got", r["got"], "train min", round(s.train_time / 60))
        for row in sim.runs_table(s)[:6]:
            print("     ", row)
    print("## Props")
    for k, (cost, rent) in E["props"].items():
        print(f"  {k:11s} first unit {sh(cost):>6s}  rent/min {sh(rent):>6s}")
    print("## robustness: crate seeds")
    for seed in range(1, 6):
        s = sim.simulate(E, sim.PLAYERS["active"], hours=12, seed=seed, record=True)
        print("  seed", seed, sim.report(s)["rebirth_minutes"][:5])
    print("## habits")
    for act, cps in ((0.9, 6.0), (0.75, 5.0), (0.6, 4.0), (0.3, 3.0)):
        pl = dict(sim.PLAYERS["active"]); pl["active"] = act; pl["cps"] = cps
        s = sim.simulate(E, pl, hours=14, record=True)
        print(f"  clicking {int(act*100)}% at {cps} cps:", sim.report(s)["rebirth_minutes"][:5])
    pl = dict(sim.PLAYERS["active"]); pl["passes"] = {"autobuild"}; pl["active"] = 0.0; pl["cps"] = 1.0
    s = sim.simulate(E, pl, hours=14, record=True)
    print("  AFK with Auto Builder:", sim.report(s)["rebirth_minutes"][:5])
