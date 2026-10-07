import sim, recal, sys
from check3_jump import series, rate_at
for hs in (0.0, 0.01, 0.03):
    E = recal.load_v2(); E["reb_headstart"] = hs
    s = sim.simulate(E, sim.PLAYERS["active"], hours=10, record=True)
    reb = [0.0] + s.events["rebirth"]
    backs = []
    for n in range(1, 5):
        if n + 1 >= len(reb): break
        prev, cur = series(s, n - 1), series(s, n)
        before = rate_at(prev, len(prev) - 1)
        back = next(((cur[i][0] - reb[n]) / 60 for i in range(len(cur)) if rate_at(cur, i) >= before), None)
        backs.append(round(back) if back else None)
    print(f"head start {hs:.0%}: back to the old income after {backs} min; Rebirths at", sim.report(s)["rebirth_minutes"][:5])
