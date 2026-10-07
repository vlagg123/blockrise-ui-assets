"""Check 2b: a Rebirth bar made of checkpoints - each new building of the zone (first build) is one step, the cash is the
last step - and an ETA (cost left / income of the last 2 minutes) shown only once the zone's last building is built."""
import sim, recal, proposal as P
E = recal.load_v2()
for name in ("active", "casual"):
    s = sim.simulate(E, sim.PLAYERS[name], hours=10, record=True)
    reb = [0.0] + s.events["rebirth"]
    print(name)
    for n in range(5):
        if n + 1 >= len(reb): break
        t0, t1 = reb[n], reb[n + 1]
        cost = E["rebirth_cost"](n)
        new = [c["id"] for c in E["contracts"] if P.NEW_IN[c["id"]] == n]
        firsts = {}
        for (tt, cid, dur, R, share, hits) in s.contract_log:
            if R == n and cid in new and cid not in firsts: firsts[cid] = tt
        pts = [(t, e) for (t, R, e, g, st) in s.run_log if R == n]
        steps = len(new) + 1
        def bar(tt):
            built = sum(1 for c in new if firsts.get(c, 1e18) <= tt)
            e = next((e for (t, e) in pts if t >= tt), pts[-1][1])
            cash = min(1.0, e / cost) if built == len(new) else 0.0
            return (built + cash) / steps
        row = [f"{int(f*100)}%->{bar(t0 + f * (t1 - t0)) * 100:.0f}%" for f in (0.25, 0.5, 0.75)]
        tg = max(firsts.values()) if len(firsts) == len(new) else None
        info = ""
        if tg:
            eg = next((e for (t, e) in pts if t >= tg), 0)
            ets = []
            for f in (0.0, 0.5):
                tt = tg + f * (t1 - tg)
                win = [(t, e) for (t, e) in pts if tt - 120 <= t <= tt]
                if len(win) >= 2 and win[-1][0] > win[0][0]:
                    rate = (win[-1][1] - win[0][1]) / (win[-1][0] - win[0][0])
                    ets.append(f"ETA {(cost - win[-1][1]) / max(1e-9, rate) / 60:.0f} vs real {(t1 - win[-1][0]) / 60:.0f} min")
            info = f"last building at {(tg - t0) / 60:.0f} min (cash {eg / cost * 100:.0f}%), then {(t1 - tg) / 60:.0f} min of cash; " + "; ".join(ets)
        print(f"  run {n + 1} ({(t1 - t0) / 60:.0f} min, {steps} steps): " + " ".join(row) + " | " + info)
