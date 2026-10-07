"""The numbers of the corrected recipe (final_econ_v2.json): road use, daily players, the jump after a Rebirth, late game."""
import json
from collections import Counter, defaultdict
import sim, final_v2, tables
from check3_jump import series, rate_at
sh = tables.short
L = json.load(open("final_econ_v2.json"))["reb_costs"]
def E_():
    E = final_v2.load(); E["reb_costs"] = L
    E["rebirth_cost"] = lambda n, L=L: L[n] if n < len(L) else L[-1] * 3 ** (n - len(L) + 1)
    return E
E = E_()
s = sim.simulate(E, sim.PLAYERS["active"], hours=24, record=True, max_rebirths=10)
cnt = defaultdict(Counter)
for (tt, cid, dur, R, share, hits) in s.contract_log: cnt[R][cid] += 1
print("ROAD (active):")
for R in range(5): print("  run", R + 1, dict(cnt[R].most_common()))
reb = [0.0] + s.events["rebirth"]
backs = []
for n in range(1, 6):
    if n + 1 >= len(reb): break
    prev, cur = series(s, n - 1), series(s, n)
    before = rate_at(prev, len(prev) - 1)
    back = next(((cur[i][0] - reb[n]) / 60 for i in range(len(cur)) if rate_at(cur, i) >= before), None)
    backs.append(round(back) if back else None)
print("BACK TO THE OLD INCOME after each Rebirth (min):", backs)
print("LATE GAME (active, 24 h):", [round(x) for x in sim.report(s)["rebirth_minutes"]], "perks", s.perks)
rows = sim.runs_table(s)
for row in rows[:6]: print("   ", row)
print("DAILY PLAYERS (offline 50%, 8 h, counts toward the Rebirth):")
for label, base, sess, ns in (("casual 20 min/day", "casual", 20, False), ("casual 45 min/day", "casual", 45, False),
                              ("active 45 min/day", "active", 45, False), ("active 90 min/day", "active", 90, False),
                              ("casual 45 min/day + Night Shift", "casual", 45, True)):
    P = dict(sim.PLAYERS[base]); P["session_min"] = sess
    if ns: P["passes"] = set(P["passes"]) | {"nightshift"}
    t = sim.simulate(E_(), P, hours=sess * 30 / 60, record=True)
    mins = sim.report(t)["rebirth_minutes"][:5]
    print(f"  {label:32s} day {t.reb_day[:5]}  play {[round(m) for m in mins]} min  offline {t.offline_earned / max(1, t.offline_earned + t.total_earned) * 100:.0f}% of the money")
