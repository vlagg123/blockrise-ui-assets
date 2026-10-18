"""BlockRise 2.0 economy simulator: a greedy player builds a city of 24 lots (3 rows x 2 blocks x 4 lots).
Prints when each Rebirth happens, the longest wait without anything to buy, and the income over time."""
import math, sys, json

P = {
    # income per second of a building at each level (L1..L10), at x1
    "I": [1, 3, 8, 20, 50, 125, 310, 780, 1950, 4900],
    # cash to reach level L (build on an empty lot = L1)
    "C": [8, 50, 220, 900, 4000, 16000, 65000, 260000, 1050000, 4200000],
    # base build seconds per level (crew of 3, Rusty hammers)
    "BT": [5, 10, 20, 40, 60, 90, 120, 180, 240, 300],
    # land: price of each block (row, block); (1,1) is free
    "BLOCK": {(1, 1): 0, (1, 2): 400, (2, 1): 60000, (2, 2): 250000, (3, 1): 6000000, (3, 2): 20000000},
    "CAP": {0: 4, 1: 7, 2: 10},
    "REBIRTH": {1: 30000, 2: 8000000, 3: 400000000},
    "REB_MULT": 1.5,
    "BLOCK_BONUS": 0.25,
    # crew hires (cash): +1 worker each
    "HIRE": [150, 1500, 12000, 90000],
    # machines: +15% build speed per level, 3 machines x 3 levels
    "MACH": [[300, 3000, 30000], [2500, 25000, 250000], [20000, 200000, 2000000]],
    "TAP": 1.25,      # an active player taps: +25% speed
    "MIN_BUILD": 3,
}

def run(P, horizon=60 * 60 * 12, verbose=False):
    I, C, BT = P["I"], P["C"], P["BT"]
    lots = {}  # (row, block, slot) -> level
    owned = {(1, 1)}
    for s in range(4): lots[(1, 1, s)] = 0
    money = 0.0
    reb = 0
    workers = 2
    hires = 0
    mach = [0, 0, 0]
    queue = []  # [lot, to_level, remaining_work]
    t = 0
    events = []
    last_action = 0
    max_gap = (0, 0)
    gaps = []
    def cap(): return P["CAP"][min(reb, 2)]
    def mult(): return P["REB_MULT"] ** reb
    def income():
        tot = 0
        blocks = {}
        for (r, b, s), lv in lots.items():
            if lv > 0: tot += I[lv - 1]
            blocks.setdefault((r, b), []).append(lv)
        bonus = 0
        for k, lvs in blocks.items():
            if len(lvs) == 4 and min(lvs) >= 1 and min(lvs) == max(lvs):
                bonus += sum(I[l - 1] for l in lvs) * P["BLOCK_BONUS"]
        return (tot + bonus) * mult()
    def speed():
        crew = 1 + workers
        m = 1 + 0.15 * sum(mach)
        return crew / 3 * m * P["TAP"]
    first = {}
    # the free first building (tutorial)
    queue.append([(1, 1, 0), 1, BT[0]])
    lots_q = {(1, 1, 0)}
    while t < horizon:
        t += 1
        inc = income()
        money += inc
        # build
        if queue:
            q = queue[0]
            q[2] -= speed()
            if q[2] <= 0:
                lots[q[0]] = q[1]
                lots_q.discard(q[0])
                queue.pop(0)
                if queue: queue[0][2] = max(queue[0][2], 0)
        # decide
        acted = True
        while acted:
            acted = False
            # rebirth
            open_lots = [k for k in lots if k[0] <= reb + 1 or True]
            allcap = all(lv >= cap() for k, lv in lots.items()) and len(lots) == 8 * min(reb + 1, 3) and not queue
            if allcap and reb + 1 in P["REBIRTH"] and money >= P["REBIRTH"][reb + 1]:
                money -= P["REBIRTH"][reb + 1]
                money = 0
                reb += 1
                events.append((t, "REBIRTH %d" % reb, inc))
                if verbose: print("t=%6.1f min  REBIRTH %d  income %.0f/s" % (t / 60, reb, inc))
                last_action = t
                acted = True
                continue
            if len(queue) >= 3: break
            cands = []
            for k, lv in lots.items():
                if k in lots_q or lv >= cap(): continue
                c = C[lv]
                dI = (I[lv] - (I[lv - 1] if lv > 0 else 0)) * mult()
                cands.append((c / dI, c, "lot", k, lv + 1))
            # blocks
            for (r, b), bc in P["BLOCK"].items():
                if (r, b) in owned or r > reb + 1: continue
                if b == 2 and (r, 1) not in owned: continue
                if r > 1 and (r, 1) not in owned and b == 1:
                    pass
                c = bc + 4 * C[0]
                dI = 4 * I[0] * mult()
                cands.append((c / dI * 0.5, bc, "block", (r, b), None))
            # hires and machines: valued as a share of income (build speed helps when the queue is long)
            if hires < len(P["HIRE"]):
                c = P["HIRE"][hires]
                cands.append((c / max(1, inc * 0.12) , c, "hire", None, None))
            for i in range(3):
                if mach[i] < len(P["MACH"][i]):
                    c = P["MACH"][i][mach[i]]
                    cands.append((c / max(1, inc * 0.1), c, "mach", i, None))
            if not cands: break
            cands.sort()
            score, c, kind, k, to = cands[0]
            if money < c: break
            money -= c
            last_action_prev = last_action
            gap = t - last_action
            gaps.append((t, gap))
            if gap > max_gap[1] and t < 3600: max_gap = (t, gap)
            last_action = t
            if kind == "lot":
                lots_q.add(k)
                queue.append([k, to, BT[to - 1]])
                key = "L%d" % to
                if key not in first:
                    first[key] = t
            elif kind == "block":
                owned.add(k)
                for s in range(4): lots[(k[0], k[1], s)] = 0
                events.append((t, "BLOCK %s" % (k,), inc))
            elif kind == "hire":
                hires += 1; workers += 1
            elif kind == "mach":
                mach[k] += 1
            acted = True
        if reb >= 3: break
    return events, first, max_gap, gaps, (money, reb, income(), t)

if __name__ == "__main__":
    ev, first, mg, gaps, end = run(P, verbose=True)
    for e in ev: print("%7.1f min  %-16s income %.0f/s" % (e[0] / 60, e[1], e[2]))
    print("first level reached:", {k: round(v / 60, 1) for k, v in first.items()})
    print("longest wait in the first hour: %.0f s at minute %.1f" % (mg[1], mg[0] / 60))
    # waits over 60 s in the first hour
    big = [(round(t / 60, 1), g) for t, g in gaps if g > 60 and t < 3600]
    print("waits > 60 s in the first hour:", big[:20])
    print("end:", end)
