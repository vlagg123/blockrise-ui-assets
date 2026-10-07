"""Sweep the proposal's structural knobs: every scenario is calibrated (work, strength gates, Rebirth costs) for the
reference active player, then played by four players; the score says how close it feels to the top simulators'
recipe (see recipe.md). Usage: python3 sweep.py N [seed]  -> sweep_results.json"""
import json, math, random, sys, time
from multiprocessing import Pool
import sim, proposal as P

sim.PLAYERS["whale"]["passes"] = {"cash2x", "strength2x", "vip", "autobuild", "fasttools", "luck", "bigcrew"}

SPACE = dict(
    worker_rate=[2.5, 3.0, 4.0, 5.0],
    machine_rate=[1.5, 2.0, 2.5],
    reb_cash=[1.0, 1.5, 2.0],
    reb_strength=[0.75, 1.0, 1.25],
    prop_unit_share=[0.03, 0.05, 0.08],
    prop_payback_min=[20.0, 30.0, 40.0],
    prop_growth=[1.3, 1.45],
    rarity_step=[1.8, 2.0],
    dept_growth=[1.55, 1.7],
    worker_growth=[1.15, 1.2, 1.3],
    dept_per=[0.10, 0.15],
)


def metrics(E):
    out = {}
    for name in ("active", "casual", "payer", "whale"):
        s = sim.simulate(E, sim.PLAYERS[name], hours=12, record=True)
        r = sim.report(s)
        rows = sim.runs_table(s)
        out[name] = dict(reb=r["rebirth_minutes"], rows=rows, got=r["got"], crates=r["crates"], train=round(s.train_time / 60, 1),
                         cps=r["cps"])
    return out


def score(m):
    a = m["active"]
    pen = 0.0
    T = P.TARGET_ACTIVE
    for n, target in T.items():
        if len(a["reb"]) >= n:
            pen += abs(math.log(a["reb"][n - 1] / target)) * (2.0 if n <= 2 else 1.0)
        else:
            pen += 3.0

    def ratio(name, k):
        o = m[name]["reb"]
        if len(o) > k and len(a["reb"]) > k:
            return o[k] / a["reb"][k]
        return None
    # a casual player ~1.6x slower, a payer ~1.6x faster, a whale at most ~4x faster
    for k in range(3):
        rc = ratio("casual", k)
        if rc: pen += max(0.0, abs(math.log(rc / 1.35)) - 0.15) * 0.4
        rp = ratio("payer", k)
        if rp: pen += abs(math.log(rp / (1 / 1.6))) * 0.4
        rw = ratio("whale", k)
        if rw: pen += max(0.0, math.log(0.25 / rw)) * 0.6
    rows = a["rows"]
    for row in rows[:5]:
        # the player shouldn't have to do most of the work alone (a tiring clicker), early ~60%, later ~40%
        lim = 0.70 if row["run"] == 0 else 0.45
        pen += max(0.0, row["player_share"] - lim) * 1.5
        pen += max(0.0, row["clicks_min"] - 110) / 100
        if not 25 <= row["avg_build"] <= 120: pen += 0.3
        if row["run"] >= 1:
            pen += max(0.0, abs(row["rent_share"] - 0.2) - 0.05) * 1.5
        if row["buys_min"] < 0.6: pen += 0.2
    return round(pen, 3)


def one(args):
    i, params = args
    p = dict(P.DEFAULT)
    p.update(params)
    t0 = time.time()
    try:
        E = P.build(p)
        E = P.calibrate_seq(E, p)
        m = metrics(E)
        sc = score(m)
        return dict(i=i, params=params, score=sc, reb_costs=E["reb_costs"],
                    work={c["id"]: round(c["workMult"], 3) for c in E["contracts"]},
                    reqStr={c["id"]: c["reqStr"] for c in E["contracts"]}, metrics=m, secs=round(time.time() - t0, 1))
    except Exception as e:
        return dict(i=i, params=params, score=99.0, error=repr(e))


if __name__ == "__main__":
    n = int(sys.argv[1]) if len(sys.argv) > 1 else 20
    seed = int(sys.argv[2]) if len(sys.argv) > 2 else 7
    out = sys.argv[3] if len(sys.argv) > 3 else "sweep_results.json"
    rng = random.Random(seed)
    jobs = []
    for i in range(n):
        jobs.append((i, {k: rng.choice(v) for k, v in SPACE.items()}))
    t0 = time.time()
    with Pool(2) as pool:
        res = pool.map(one, jobs)
    res.sort(key=lambda r: r["score"])
    json.dump(res, open(out, "w"), indent=1, default=str)
    print("done", n, "scenarios in", round(time.time() - t0), "s")
    for r in res[:8]:
        a = r.get("metrics", {}).get("active", {})
        print(r["score"], r["params"], a.get("reb"))
