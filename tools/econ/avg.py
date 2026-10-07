"""Minutes to each Rebirth, averaged over 5 crate seeds, per player: python3 avg.py"""
import statistics as st
import sim, report_final as RF
E, p = RF.load()
for name in ("active", "casual", "payer", "whale"):
    rows = []
    for seed in range(1, 6):
        s = sim.simulate(E, sim.PLAYERS[name], hours=14, seed=seed, record=True)
        rows.append(sim.report(s)["rebirth_minutes"][:5])
    n = min(len(r) for r in rows)
    print(name, [round(st.mean(r[k] for r in rows), 1) for k in range(n)], "min-max R1", min(r[0] for r in rows), max(r[0] for r in rows),
          "R5", min(r[n - 1] for r in rows), max(r[n - 1] for r in rows))
