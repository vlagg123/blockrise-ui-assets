"""Check 8: what each pass is worth. A daily player (60 min a day, offline at night) with one pass added: how much sooner the
5th Rebirth comes (in days and play minutes) -> Robux per % of speed, to price the passes consistently."""
import sim, recal
E = recal.load_v2(); E["reb_headstart"] = 0.01
base = dict(sim.PLAYERS["active"]); base["session_min"] = 60
PRICES = {"none": 0, "cash2x": 499, "vip": 199, "strength2x": 349, "bigcrew": 149, "fasttools": 199, "autobuild": 399, "nightshift": 199}
def run(passes, seeds=(1, 2)):
    out = []
    for sd in seeds:
        P = dict(base); P["passes"] = set(passes)
        s = sim.simulate(E, P, hours=20, seed=sd, record=True)
        out.append(sim.report(s)["rebirth_minutes"][:5])
    n = min(len(r) for r in out)
    return [sum(r[k] for r in out) / len(out) for k in range(n)]
ref = run([])
print("no pass:", [round(x) for x in ref], "play minutes to R1..R5")
for k, price in PRICES.items():
    if k == "none": continue
    r = run([k])
    n = min(len(r), len(ref))
    speed = ref[n - 1] / r[n - 1] - 1
    print(f"{k:11s} {price:4d} R$: R{n} after {r[n-1]:.0f} min instead of {ref[n-1]:.0f} -> {speed * 100:+.0f}% speed, {price / max(0.1, speed * 100):.0f} R$ per 1%")
