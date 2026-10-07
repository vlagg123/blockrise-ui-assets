"""The chosen scenario: calibrate (incl. the Spire), then robustness: other crate seeds, other click habits."""
import json, sim, proposal as P, tables
sim.PLAYERS["whale"]["passes"] = {"cash2x", "strength2x", "vip", "autobuild", "fasttools", "luck", "bigcrew"}
BEST = {"worker_rate": 4.0, "machine_rate": 1.5, "reb_cash": 1.5, "reb_strength": 0.75, "prop_unit_share": 0.03,
        "prop_payback_min": 30.0, "prop_growth": 1.45, "rarity_step": 2.0, "dept_growth": 1.55, "worker_growth": 1.3, "dept_per": 0.15}


def build():
    p = dict(P.DEFAULT); p.update(BEST)
    E = P.build(p)
    E = P.calibrate_seq(E, p, upto=6)
    tables.monotonic(E)
    return E, p


if __name__ == "__main__":
    E, p = build()
    json.dump(dict(params=BEST, reb_costs=E["reb_costs"], contracts=E["contracts"], props={k: list(v) for k, v in E["props"].items()}),
              open("final_econ.json", "w"), indent=1, default=str)
    print("costs", [f"{x:.3g}" for x in E["reb_costs"]])
    for c in E["contracts"]:
        work = sum(sim.VERBS[c["id"]].values()) * c["workMult"]
        print(f"  {c['id']:11s} R{c['reqReb']} reward {c['reward']:.3g} work {work:.4g} str {c['reqStr']:.3g} crew {c['reqCrew']}")
    print("ROBUSTNESS (crate seeds 1..5, active player): minutes to R1..R5")
    for seed in range(1, 6):
        s = sim.simulate(E, sim.PLAYERS["active"], hours=12, seed=seed, record=True)
        print("  seed", seed, sim.report(s)["rebirth_minutes"][:6], "best hammer", sim.RARITY[s.best[0]])
    print("HABITS (active share of build time clicking / clicks per second)")
    for act, cps in ((0.9, 6.0), (0.75, 5.0), (0.6, 4.0), (0.3, 3.0), (0.0, 1.0)):
        pl = dict(sim.PLAYERS["active"]); pl["active"] = act; pl["cps"] = cps
        s = sim.simulate(E, pl, hours=14, record=True)
        print(f"  clicking {int(act*100)}% at {cps} cps:", sim.report(s)["rebirth_minutes"][:6])
