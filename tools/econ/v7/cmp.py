import proposal as PR, sim7, sys
from sim7 import *
E = PR.base_proposal(); E["road"] = PR.road_v7(E); PR.tune(E, verbose="-v" in sys.argv)
CASUAL = dict(PLAYER, cps=3.5, active=0.7, combo=1.6, job_overhead=18, train_overhead=15, crate_share=0.15, spend_share=0.35)
def summ(E, P, label):
    rs = [simulate(E, P, seed=s, until_R=5, max_hours=60) for s in range(1, 6)]
    out = []
    for R in range(1, 6):
        ts = [r.rebirth_at.get(R) for r in rs if r.rebirth_at.get(R)]
        out.append(f"R{R} {sum(ts)/len(ts)/60:6.1f}m" if ts else f"R{R}   n/a")
    r = rs[0]
    print(f"{label:18}", "  ".join(out), f"| build {r.t_build/60:4.0f}m train {r.t_train/60:4.0f}m | builds {sum(r.builds_by_zone.values())}")
    return rs
summ(live_econ(), PLAYER, "today active")
rs = summ(E, PLAYER, "v7 active")
summ(live_econ(), CASUAL, "today casual")
summ(E, CASUAL, "v7 casual")
if "-e" in sys.argv:
    for t, w in rs[0].events: print(f"   {t/60:6.1f}  {w}")
import json
json.dump([{k: (list(v) if isinstance(v, set) else v) for k, v in c.items()} for c in E["contracts"]], open("v7_contracts.json", "w"), indent=1)
json.dump(E["road"], open("v7_road.json", "w"), indent=1)
