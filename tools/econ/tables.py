"""Print the recipe's tables for a chosen scenario: python3 tables.py '<json params>'"""
import json, math, sys
import sim, proposal as P, crates

sim.PLAYERS["whale"]["passes"] = {"cash2x", "strength2x", "vip", "autobuild", "fasttools", "luck", "bigcrew"}

SUF = ["", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc"]


def short(n):
    n = float(n)
    if n < 1000: return f"{n:,.0f}"
    i = min(len(SUF) - 1, int(math.log10(n) // 3))
    v = n / 10 ** (3 * i)
    s = f"{v:.0f}" if v >= 100 else (f"{v:.1f}" if v >= 10 else f"{v:.2f}")
    s = s.rstrip("0").rstrip(".") if "." in s else s
    return s + SUF[i]


def monotonic(E):
    """Strength gates never go down along the road (within a zone order)"""
    last = 0
    for c in E["contracts"]:
        if c["reqStr"] and c["reqStr"] < last and P.OPEN_AT[c["id"]] > 0:
            c["reqStr"] = P.nice(last * 1.5)
        if c["reqStr"]: last = max(last, c["reqStr"])
    return E


def main(params):
    p = dict(P.DEFAULT); p.update(params)
    E = P.build(p)
    E = P.calibrate_seq(E, p)
    monotonic(E)
    print("## Rebirths")
    for n in range(7):
        print(f"R{n + 1}: earn {short(E['rebirth_cost'](n))} in the run | after it: cash x{E['rebirth_cash'](n + 1):.1f}, strength x{E['rebirth_strength'](n + 1):.1f}")
    print("## Contracts")
    for c in E["contracts"]:
        work = sum(VERB for VERB in sim.VERBS[c["id"]].values()) * c["workMult"]
        print(f"{c['id']:11s} zone {c['zone']:9s} R{c['reqReb']}  reward {short(c['reward']):>6s}  work {short(work):>6s}  strength {short(c['reqStr']):>6s}  crew {c['reqCrew']}  build target {P.TARGET_BUILD[c['id']]} s")
    print("## Pacing per player (minutes to each Rebirth)")
    res = {}
    for name in ("active", "casual", "payer", "whale"):
        s = sim.simulate(E, sim.PLAYERS[name], hours=14, record=True)
        r = sim.report(s)
        res[name] = (s, r)
        print(f"{name:7s}", r["rebirth_minutes"][:6], "| train min", round(s.train_time / 60), "| crates", r["crates"], "| got", r["got"])
        for row in sim.runs_table(s)[:6]:
            print("     ", row)
    return E, res


if __name__ == "__main__":
    params = json.loads(sys.argv[1]) if len(sys.argv) > 1 else {}
    main(params)
