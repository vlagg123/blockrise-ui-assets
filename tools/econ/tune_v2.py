"""Hand-tune the first Rebirth costs on 5 crate seeds (the calibration uses one): python3 tune_v2.py 25000 300e6"""
import sys, json, statistics as st
import sim, final_v2, tables
E = final_v2.load()
L = list(E["reb_costs"])
for i, v in enumerate(sys.argv[1:]):
    L[i] = float(v)
E["reb_costs"] = L
E["rebirth_cost"] = lambda n, L=L: L[n] if n < len(L) else L[-1] * 3 ** (n - len(L) + 1)
print("costs", [tables.short(E["rebirth_cost"](n)) for n in range(9)])
for name in (sys.argv[0] and ("active", "casual", "payer", "whale")):
    rows = []
    for seed in range(1, 6):
        s = sim.simulate(E, sim.PLAYERS[name], hours=14, seed=seed, record=True)
        rows.append(sim.report(s)["rebirth_minutes"][:5])
    n = min(len(r) for r in rows)
    print(name, [round(st.mean(r[k] for r in rows), 1) for k in range(n)], "R1", min(r[0] for r in rows), max(r[0] for r in rows),
          "R5", min(r[n - 1] for r in rows), max(r[n - 1] for r in rows))
if "--save" in sys.argv[-1:] or True:
    d = json.load(open("final_econ_v2.json")); d["reb_costs_tuned"] = L
    json.dump(d, open("final_econ_v2_tuned_try.json", "w"), indent=1, default=str)
