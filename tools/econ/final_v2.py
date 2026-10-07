"""The recipe after the 10 checks: fidelity v2 (Star Shop on the new Star rule, blueprints, one-time rewards, extras),
a built-in head start (1% of the Rebirth paid), trade-ups up to Legendary, Rebirth 1 at ~15 min, R8+ x3 per Rebirth.
Recalibrates the Rebirth costs and writes final_econ_v2.json. Usage: python3 final_v2.py"""
import json, statistics as st
import sim, proposal as P, report_final as RF, fidelity, tables

P.TARGET_CLOCK[1] = 15

def build():
    E, p = RF.load()
    fidelity.apply(E, stars_new=True)
    E["reb_headstart"] = 0.01
    E["tradeup_top"] = 5          # (sim indexing) trade-ups stop at Legendary
    P.calibrate_rebirths(E, upto=6)
    L = E["reb_costs"]
    L[6] = P.nice(L[5] * max(4.0, L[5] / L[4]) * 1.5)
    E["rebirth_cost"] = lambda n, L=L: L[n] if n < len(L) else L[-1] * 3 ** (n - len(L) + 1)
    return E

def load():
    E, p = RF.load()
    fidelity.apply(E, stars_new=True)
    E["reb_headstart"] = 0.01
    E["tradeup_top"] = 5
    L = json.load(open("final_econ_v2.json"))["reb_costs"]
    E["reb_costs"] = L
    E["rebirth_cost"] = lambda n, L=L: L[n] if n < len(L) else L[-1] * 3 ** (n - len(L) + 1)
    return E

if __name__ == "__main__":
    E = build()
    json.dump(dict(reb_costs=E["reb_costs"], stations=E["stations"], contracts=E["contracts"], reb_headstart=0.01, tradeup_top="Legendary",
                   stars="3 + 2 x Rebirth + 1 per doubling of the cost", fidelity="v2"), open("final_econ_v2.json", "w"), indent=1, default=str)
    print("costs", [tables.short(E["rebirth_cost"](n)) for n in range(9)])
    for name in ("active", "casual", "payer", "whale"):
        rows = []
        for seed in range(1, 6):
            s = sim.simulate(E, sim.PLAYERS[name], hours=14, seed=seed, record=True)
            rows.append(sim.report(s)["rebirth_minutes"][:5])
        n = min(len(r) for r in rows)
        print(name, [round(st.mean(r[k] for r in rows), 1) for k in range(n)], "R1", min(r[0] for r in rows), max(r[0] for r in rows),
              "R5", min(r[n - 1] for r in rows), max(r[n - 1] for r in rows))
