"""Check 2: the Rebirth bar inside each run. At 25/50/75% of the run's time, how full is the bar (earned / cost)?
And the ETA the game could show (cost left / income per minute right now): how far off is it from the real time left?"""
import sim, recal
E = recal.load_v2()
for name in ("active", "casual"):
    s = sim.simulate(E, sim.PLAYERS[name], hours=10, record=True)
    reb = [0.0] + s.events["rebirth"]
    print(name)
    for n in range(5):
        if n + 1 >= len(reb): break
        t0, t1 = reb[n], reb[n + 1]
        cost = E["rebirth_cost"](n)
        pts = [(t, e) for (t, R, e, g, st) in s.run_log if R == n]
        row = []
        for f in (0.25, 0.5, 0.75):
            tt = t0 + f * (t1 - t0)
            e = next((e for (t, e) in pts if t >= tt), pts[-1][1])
            row.append(f"{int(f*100)}% time -> bar {min(100, e / cost * 100):.0f}%")
        # ETA honesty: at 25% / 50% of the run, ETA = cost left / earning rate of the last 2 minutes
        eta = []
        for f in (0.25, 0.5):
            tt = t0 + f * (t1 - t0)
            win = [(t, e) for (t, e) in pts if tt - 120 <= t <= tt]
            if len(win) >= 2 and win[-1][0] > win[0][0]:
                rate = (win[-1][1] - win[0][1]) / (win[-1][0] - win[0][0])
                left = cost - win[-1][1]
                est = left / max(1e-9, rate) / 60
                real = (t1 - win[-1][0]) / 60
                eta.append(f"at {int(f*100)}%: ETA {est:.0f} min, real {real:.0f} min")
        print(f"  run {n + 1} ({(t1 - t0) / 60:.0f} min):", " | ".join(row), " || ", " ; ".join(eta))
