"""Check 11 (2026-10-07, the owner's question): should the Rebirth bar count the CASH IN HAND instead of the money
earned this run? Same game (economy v4 = final_econ_v2.json), three ways to rebirth:
  earned  today: the money earned this run reaches the cost (spending never slows you)
  cash    the owner's idea: you need the cost in cash; the player keeps buying the way he does today
  saver   the owner's idea with a smart player: he stops buying what won't pay back before the Rebirth he saves for
and, for the cash rule, the costs it would need to keep today's pace.
Usage: python3 check11_cash.py"""
import copy, statistics as st
import sim, final_v2, tables

PLAYERS = ("active", "casual", "payer", "whale")
SEEDS = range(1, 6)


def mode(E, m, cost_x=1.0):
    E = copy.copy(E)
    E["reb_cash"] = m in ("cash", "saver")
    E["reb_cash_saver"] = m == "saver"
    if cost_x != 1.0:
        L = [c * cost_x for c in E["reb_costs"]]
        E["reb_costs"] = L
        E["rebirth_cost"] = lambda n, L=L: L[n] if n < len(L) else L[-1] * 3 ** (n - len(L) + 1)
    return E


def run(E, name, hours=30, upto=5):
    rows = []
    for seed in SEEDS:
        s = sim.simulate(E, sim.PLAYERS[name], hours=hours, seed=seed, max_rebirths=upto)
        r = s.events["rebirth"]
        rows.append([x / 60 for x in r[:upto]] + [None] * (upto - len(r[:upto])))
    out = []
    for k in range(upto):
        v = [r[k] for r in rows if r[k] is not None]
        out.append(round(st.mean(v), 1) if len(v) == len(rows) else None)
    return out


def hm(m):
    if m is None:
        return "—"
    return "%d min" % round(m) if m < 60 else "%d h %02d" % (m // 60, round(m % 60))


if __name__ == "__main__":
    E0 = final_v2.load()
    print("costs", [tables.short(E0["rebirth_cost"](n)) for n in range(5)])
    res = {}
    for name in PLAYERS:
        for m in ("earned", "cash", "saver"):
            res[(name, m)] = run(mode(E0, m), name)
            print(name, m, [hm(x) for x in res[(name, m)]], flush=True)
