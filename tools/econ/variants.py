import sys, json, sim, proposal as P, final, sweep
ps = float(sys.argv[1])
p = dict(P.DEFAULT); p.update(final.BEST); p["price_scale"] = ps
E = P.build(p); E = P.calibrate_seq(E, p, upto=6)
m = sweep.metrics(E)
print("price_scale", ps, "score", sweep.score(m), "costs", [f"{x:.2g}" for x in E["reb_costs"]])
for n in ("active", "casual", "payer", "whale"):
    print(" ", n, m[n]["reb"], "got", m[n]["got"])
for row in m["active"]["rows"][:6]:
    print("    ", row)
