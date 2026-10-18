import sim, copy
def make(pb, I, blocks, reb):
    P = copy.deepcopy(sim.P)
    C = []
    for L in range(10):
        dI = I[L] - (I[L-1] if L else 0)
        C.append(int(dI * pb[L]))
    P["I"], P["C"], P["BLOCK"], P["REBIRTH"] = I, C, blocks, reb
    P["HIRE"], P["MACH"] = [], [[], [], []]
    return P
I = [1, 3, 8, 20, 50, 125, 310, 780, 1950, 4900]
blocks = {(1, 1): 0, (1, 2): 300, (2, 1): 60000, (2, 2): 250000, (3, 1): 12000000, (3, 2): 40000000}
for pb4 in (420, 600, 800):
  for r1 in (40000, 60000):
    pb = [8, 30, 150, pb4, 1300, 2900, 5000, 18000, 32000, 48000]
    P = make(pb, I, blocks, {1: r1, 2: 12000000, 3: 1500000000})
    ev, first, mg, gaps, end = sim.run(P, horizon=60*60*30)
    r = {e[1]: round(e[0]/60, 1) for e in ev if e[1].startswith("REB")}
    w = [(round(t / 60, 1), g) for t, g in gaps if g > 60 and t < r.get("REBIRTH 1", 99)*60]
    print("pb4", pb4, "R1cost", r1, "C4", P["C"][3], "->", r, "L4 first", round(first["L4"]/60,1), "waits>60s before R1:", w)
