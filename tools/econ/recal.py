"""FIDELITY_V2 recalibration: the final economy (final_econ.json) with the systems the first model left out, the Star Shop
on the proposed Star rule, and the Rebirth costs recalibrated to the same pacing targets -> final_econ_v2.json"""
import json, sys, statistics as st
import sim, proposal as P, report_final as RF, fidelity, tables

def build(stars_new=True):
    E, p = RF.load()
    fidelity.apply(E, stars_new=stars_new)
    P.calibrate_rebirths(E, upto=6)
    L = E["reb_costs"]
    L[6] = P.nice(L[5] * max(4.0, L[5] / L[4]) * 1.5)
    return E

def pacing(E, players=("active", "casual", "payer", "whale"), seeds=(1, 2, 3), hours=14):
    out = {}
    for name in players:
        rows = []
        for seed in seeds:
            s = sim.simulate(E, sim.PLAYERS[name], hours=hours, seed=seed, record=True)
            rows.append(sim.report(s)["rebirth_minutes"][:6])
        n = min(len(r) for r in rows)
        out[name] = [round(st.mean(r[k] for r in rows), 1) for k in range(n)]
    return out

if __name__ == "__main__":
    E = build()
    json.dump(dict(stations=E["stations"], reb_costs=E["reb_costs"], contracts=E["contracts"], fidelity=True, stars_new=True),
              open("final_econ_v2.json", "w"), indent=1, default=str)
    print("costs", [tables.short(x) for x in E["reb_costs"]])
    for k, v in pacing(E).items(): print(k, v)
    s = sim.simulate(E, sim.PLAYERS["active"], hours=14, record=True)
    print("active stars left", s.stars, s.perks)


def load_v2():
    """the recalibrated economy without re-running the calibration"""
    E, p = RF.load()
    fidelity.apply(E, stars_new=True)
    d = json.load(open("final_econ_v2.json"))
    E["reb_costs"] = d["reb_costs"]
    return E
