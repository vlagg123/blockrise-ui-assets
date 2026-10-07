"""Check 5: kids who don't play optimally. Phone tapping (slower), random or cheapest-first buying, never opening Upgrades,
never buying properties, never hiring past the tutorial, never training. Does anyone get stuck?"""
import sim, recal
E = recal.load_v2(); E["reb_headstart"] = 0.01
base = sim.PLAYERS["casual"]
V = {
    "casual (reference)": {},
    "phone: 3 taps/s, 50% of the time": dict(cps=3.0, active=0.5),
    "buys at random": dict(policy="random"),
    "buys the cheapest first": dict(policy="cheapest"),
    "never opens Upgrades": dict(skip=("dept",)),
    "never buys properties": dict(skip=("prop", "company")),
    "no crew past the tutorial": dict(skip=("worker",)),
    "never trains": dict(train=False),
    "phone + random + no Upgrades": dict(cps=3.0, active=0.5, policy="random", skip=("dept",)),
}
for label, ch in V.items():
    P = dict(base); P.update(ch)
    s = sim.simulate(E, P, hours=16, record=True)
    print(f"{label:34s}", sim.report(s)["rebirth_minutes"][:5])
