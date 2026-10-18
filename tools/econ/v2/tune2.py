import sim, copy, sys
def make(pb, I, blocks, reb):
    P = copy.deepcopy(sim.P)
    C = []
    for L in range(10):
        dI = I[L] - (I[L-1] if L else 0)
        C.append(int(dI * pb[L]))
    P["I"], P["C"], P["BLOCK"], P["REBIRTH"] = I, C, blocks, reb
    return P
I = [1, 3, 8, 20, 50, 125, 310, 780, 1950, 4900]
pb = [8, 25, 120, 420, 1300, 2900, 5000, 18000, 32000, 48000]
blocks = {(1, 1): 0, (1, 2): 300, (2, 1): 60000, (2, 2): 250000, (3, 1): 12000000, (3, 2): 40000000}
reb = {1: 40000, 2: 12000000, 3: 1500000000}
P = make(pb, I, blocks, reb)
print("C =", P["C"])
ev, first, mg, gaps, end = sim.run(P, horizon=60*60*100)
for e in ev: print("%7.1f min (%5.1f h) %-16s income %.0f/s" % (e[0] / 60, e[0]/3600, e[1], e[2]))
print("first level reached (min):", {k: round(v / 60, 1) for k, v in first.items()})
print("waits > 60 s in the first 40 min:", [(round(t / 60, 1), g) for t, g in gaps if g > 60 and t < 2400][:30])
