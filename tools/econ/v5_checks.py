"""Economy v5 checks: the loop in every run (saving phase, builds, crew, rent, purchases), naive players under the cash
rule, and days (one session a day + the night offline). Usage: python3 v5_checks.py"""
import json, statistics as st
import sim, v5, final_v2


def loop(E, name, seeds=(1, 2, 3), upto=6):
    rows = {}
    for seed in seeds:
        s = sim.simulate(E, v5.player(name), hours=40, seed=seed, max_rebirths=upto)
        reb = [0.0] + s.events["rebirth"]
        for n, row in enumerate(sim.runs_table(s)[:upto]):
            if n + 1 >= len(reb): break
            t0, t1 = reb[n], reb[n + 1]
            buys = [t for (t, k, kk, c) in s.purchases if t0 <= t < t1]
            last = max(buys) if buys else t0
            row["saving_min"] = round((t1 - last) / 60, 1)
            row["saving_pct"] = round((t1 - last) / max(1, t1 - t0) * 100)
            rows.setdefault(n, []).append(row)
    out = []
    for n in sorted(rows):
        rs = rows[n]
        out.append({k: round(st.mean(r[k] for r in rs), 2) for k in ("minutes", "contracts", "avg_build", "player_share", "rent_share", "buys_min", "saving_min", "saving_pct")})
    return out


def naive(E, pol, seeds=(1, 2, 3), upto=3):
    t = []
    for seed in seeds:
        s = sim.simulate(E, v5.player("casual", policy=pol), hours=30, seed=seed, max_rebirths=upto)
        t.append([x / 60 for x in s.events["rebirth"][:upto]] + [None] * upto)
    return [round(st.mean(r[k] for r in t), 0) if all(r[k] is not None for r in t) else None for k in range(upto)]


def days(E, name, session_min, upto=5, seeds=(1, 2)):
    out = []
    for seed in seeds:
        s = sim.simulate(E, v5.player(name, session_min=session_min, day_h=session_min / 60), hours=session_min / 60 * 60, seed=seed, max_rebirths=upto)
        out.append(getattr(s, "reb_day", [])[:upto])
    n = min(len(o) for o in out)
    return [round(st.mean(o[k] for o in out), 1) for k in range(n)]


if __name__ == "__main__":
    d = json.load(open("final_econ_v5.json"))
    E5 = v5.build(d["reb_costs"])
    E4 = v5.v4_with_days()
    print("== pacing v5 (5 seeds)")
    for name in ("active", "casual", "payer", "whale"):
        print(" ", name, [v5.hm(x) for x in v5.pacing(E5, name)], flush=True)
    print("== the loop in each run (active, v5 then v4)")
    for lab, E in (("v5", E5), ("v4", E4)):
        for n, r in enumerate(loop(E, "active")):
            print("  %s run %d: %s" % (lab, n + 1, r), flush=True)
    print("== naive players (casual), minutes to R1..R3")
    for pol in ("random", "cheapest"):
        print("  %-8s v4 %s  v5 %s" % (pol, naive(E4, pol), naive(E5, pol)), flush=True)
    print("== days (one session a day, offline at night): day of R1..R5")
    for name, m in (("casual", 20), ("casual", 45), ("active", 45), ("active", 90)):
        print("  %s %d min/day: v4 %s  v5 %s" % (name, m, days(E4, name, m), days(E5, name, m)), flush=True)
