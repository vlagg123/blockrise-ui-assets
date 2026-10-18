import sim, copy
P = copy.deepcopy(sim.P)
I = [1, 3, 8, 20, 50, 125, 310, 780, 1950, 4900]
pb = [8, 20, 55, 150, 600, 1300, 2300, 5000, 8500, 12000]
C = []
for L in range(10):
    dI = I[L] - (I[L-1] if L else 0)
    C.append(dI * pb[L])
P["I"], P["C"] = I, C
P["BLOCK"] = {(1, 1): 0, (1, 2): 300, (2, 1): 30000, (2, 2): 100000, (3, 1): 3000000, (3, 2): 10000000}
P["REBIRTH"] = {1: 50000, 2: 5500000, 3: 300000000}
print("C =", C)
ev, first, mg, gaps, end = sim.run(P, horizon=60*60*60)
for e in ev: print("%7.1f min  %-16s income %.0f/s" % (e[0] / 60, e[1], e[2]))
print("first level reached (min):", {k: round(v / 60, 1) for k, v in first.items()})
print("longest wait in the first hour: %.0f s at minute %.1f" % (mg[1], mg[0] / 60))
print("waits > 60 s in the first hour:", [(round(t / 60, 1), g) for t, g in gaps if g > 60 and t < 3600][:30])
print("end:", end)
