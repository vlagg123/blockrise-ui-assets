"""BlockRise Empire - economy simulator v7 (2026-10-14).

Written from the LIVE code dumped from Studio on 2026-10-14 (live_2026-10-14.json + the formulas below, each one
quoted from Main / Config / Hammers / HammerService / Crew / Machines / RebirthService / Company / CompanyService).
It plays an "active free player" through the loop second by second (build / train / buy / rebirth) and reports the
clock: minutes to every first build, to each Rebirth, how the time splits between building and training, cash, crates.

    python3 sim7.py            # today's game vs the proposal (proposal.py)

The player model (clicks, idle share, overheads) is calibrated on what was measured in Studio and on the live funnel.
Everything that is random (crates, HOT) is seeded; runs are averaged over seeds.
"""
import json, math, os, random, copy

HERE = os.path.dirname(os.path.abspath(__file__))
LIVE = json.load(open(os.path.join(HERE, "live_2026-10-14.json")))

# ---------------------------------------------------------------------------------------------------------------------
# live formulas
# ---------------------------------------------------------------------------------------------------------------------
def strength_mult(s):                       # Config.StrengthMult (LOOP_V7)
    return 1 + (max(0.0, s) / 40) ** 0.55

def xp_for_level(L):                        # Config.XPForLevel
    return math.floor(120 * L ** 1.45)

def total_xp(L):                            # Company.TotalXP
    return sum(math.floor(120 * l ** 1.45) for l in range(1, L))

RARITY_CD = [0.42, 0.38, 0.34, 0.30, 0.27, 0.25, 0.23, 0.21, 0.19]
LEVEL_BASE = [120, 500, 2500, 12000, 60000, 300000, 1500000, 8000000, 40000000]

def hammer_power(r, lv):                    # Hammers.Power: 2^(r-1) * (1 + 0.08 (lv-1))
    return 2 ** (r - 1) * (1 + 0.08 * (lv - 1))

def hammer_level_cost(r, lv):               # Hammers.LevelCost
    return None if lv >= 10 else math.floor(LEVEL_BASE[r - 1] * 1.6 ** (lv - 1))

def max_workers(L, rebirths, hr_lv=0):      # Config.MaxWorkers + Rebirth slots + HR dept
    return min(2 + L // 2, 10) + rebirths * 1 + hr_lv // 10

def rebirth_level(n):                       # Company.RebirthLevel
    L = [12, 35, 55, 75, 100, 125]
    return L[n] if n < len(L) else L[-1] + 20 * (n - len(L) + 1)

def dept_cost(base, lv):                    # Company.DeptCost (cash; materials are left out)
    return math.floor(base * 1.55 ** lv)

def dept_cap(rebirths):                     # Config.DeptCap
    return min(50, 10 * (1 + min(2, rebirths)))

DEPTS = {"power": 2500, "strength": 2000, "cash": 2000, "crew": 3000}

def machine_mult(lv): return 1 + 0.5 * (lv - 1)
def machine_up_cost(price, lv):
    raw = price * 2.2 ** lv
    mag = 10 ** max(0, math.floor(math.log10(raw)) - 2)
    return math.floor(raw / mag + 0.5) * mag

# zone crates (Hammers.Crates odds per rarity 1..8, %) and the free ones
CRATE_ODDS = {
    "supply": [75, 20, 4, 1, 0, 0, 0, 0],
    "supply_suburbs": [52, 33, 12, 2.6, 0.4, 0, 0, 0],
    "supply_downtown": [0, 55, 33, 10.8, 1.15, 0.05, 0, 0],
    "builder": [0, 52, 35.65, 10, 1.85, 0.5, 0, 0],
    "golden": [0, 0, 55.68, 33, 9.4, 1.3, 0.6, 0.02],
}
ZONE_CRATE = {"town": "supply", "suburbs": "supply_suburbs", "downtown": "supply_downtown"}
ZONE_OF_REBIRTH = ["town", "suburbs", "downtown"]

# the stage verbs of every blueprint (Blueprints, live): share of the base work per verb
BP_VERBS = {
    "fence": {"clear": 10, "hammer": 38},
    "shed": {"wood": 60, "glass": 6, "hammer": 8, "dig": 14, "pour": 16, "clear": 10},
    "garage": {"clear": 20, "brick": 95, "hammer": 25, "wood": 45, "glass": 15, "dig": 35, "pour": 35, "metal": 20},
    "house": {"clear": 40, "brick": 230, "hammer": 100, "wood": 140, "glass": 60, "dig": 80, "pour": 80, "metal": 50},
    "shop": {"clear": 60, "brick": 330, "hammer": 150, "glass": 120, "dig": 120, "pour": 250, "metal": 70},
    "villa": {"clear": 80, "brick": 700, "hammer": 300, "wood": 400, "glass": 300, "dig": 160, "pour": 160, "metal": 100},
    "warehouse": {"clear": 120, "glass": 120, "hammer": 300, "dig": 240, "pour": 590, "metal": 1050},
    "apartments": {"clear": 150, "brick": 1400, "hammer": 400, "glass": 800, "dig": 300, "pour": 600, "metal": 180},
    "luxvilla": {"clear": 90, "brick": 750, "hammer": 330, "wood": 420, "glass": 320, "dig": 170, "pour": 170, "metal": 110},
    "distcenter": {"clear": 130, "glass": 140, "hammer": 330, "dig": 260, "pour": 640, "metal": 1120},
    "office": {"clear": 200, "glass": 2400, "hammer": 600, "dig": 400, "pour": 800, "metal": 300},
    "hotel": {"clear": 250, "brick": 2400, "hammer": 700, "glass": 1200, "dig": 500, "pour": 900, "metal": 350},
    "skyscraper": {"clear": 300, "glass": 4200, "hammer": 1250, "dig": 600, "pour": 1200, "metal": 450},
    "hq": {"clear": 350, "glass": 4800, "hammer": 1250, "dig": 700, "pour": 1400, "metal": 500},
    "spire": {"clear": 400, "glass": 5400, "hammer": 1200, "dig": 800, "pour": 1600, "metal": 600},
}

# ---------------------------------------------------------------------------------------------------------------------
# the economy (data): today's, from the live dump; proposals change a copy
# ---------------------------------------------------------------------------------------------------------------------
def live_econ():
    E = {"name": "TODAY (live 2026-10-14)"}
    E["contracts"] = []
    for c in LIVE["contracts"]:
        verbs = BP_VERBS[c["id"]]
        base = sum(verbs.values())
        E["contracts"].append(dict(id=c["id"], name=c["name"], zone=c["zone"], reward=c["reward"], xp=c["xp"],
                                   reqS=c["reqStrength"], crew=c["reqCrew"], reb=c["reqRebirth"],
                                   work=base * c["workMult"], verbs={k: v / base for k, v in verbs.items()},
                                   target=c["targetTime"], order=c["order"]))
    E["gear"] = [(g["price"], g["mult"]) for g in LIVE["gear"]]
    E["stations"] = [(s["req"], s["mult"]) for s in LIVE["stations"]]
    E["workers"] = {w["id"]: dict(price=w["price"], rate=w["rate"], lvl=w["reqLevel"], boost=w.get("boost") or 0) for w in LIVE["workers"]}
    E["machines"] = {m["id"]: dict(price=m["price"], rate=m["rate"], lvl=m["reqLevel"], verbs=set(m["verbs"])) for m in LIVE["machines"]}
    E["crate_price"] = "income"          # today: max(150, IncomePerMin * 1.5)
    E["crate_fixed"] = {}
    E["road"] = LIVE["road"]
    E["new_player_money"] = LIVE["newPlayerMoney"]
    E["rebirth_cash_per"] = 1.5
    E["rebirth_str_per"] = 0.75
    E["first_job_half"] = True
    return E

# ---------------------------------------------------------------------------------------------------------------------
# the player
# ---------------------------------------------------------------------------------------------------------------------
PLAYER = dict(
    cps=5.0,            # clicks a second it tries while building / training (PC ~6, phone ~4)
    active=0.85,        # share of a build's time spent hitting (walks, camera, looking at the screen)
    combo=1.85,         # average combo while hitting continuously (Config.Combo: +0.08 a hit up to x2)
    job_overhead=10.0,  # s per contract: accept, the trip, the PROJECT COMPLETE card
    train_overhead=8.0, # s per training session: the trip to the yard
    buy_overhead=2.0,   # s per purchase
    crate_share=0.25,   # share of the cash it puts into zone crates when it shops
    spend_share=0.5,    # a single buy may use this share of the cash (gear / crew / machines)
)

class State:
    pass

def zone_of(st):
    return ZONE_OF_REBIRTH[min(st.R, 2)]

def unlocked(E, st, c):
    if not (st.S >= c["reqS"] and st.R >= c["reb"] and len(st.workers) >= c["crew"]):
        return False
    if E.get("order_gate"):
        # ZONE_CHAIN: a building opens once the one before it (same Rebirth group) has been built
        group = [x for x in E["contracts"] if x["reb"] == c["reb"]]
        i = group.index(c)
        if i > 0 and st.built.get(group[i - 1]["id"], 0) == 0:
            return False
    return True

def power_mult(E, st):
    return strength_mult(st.S) * (1 + 0.15 * st.dept["power"])

def hammer_now(st):
    return max(st.hammers, key=lambda h: hammer_power(h[0], h[1]))

def cash_mult(E, st):
    return (1 + E["rebirth_cash_per"] * st.R) * (1 + 0.15 * st.dept["cash"])

def str_mult(E, st):
    return E["gear"][st.gear][1] * (1 + E["rebirth_str_per"] * st.R) * (1 + 0.15 * st.dept["strength"])

def crew_mult(E, st):
    r, lv = hammer_now(st)
    return hammer_power(r, lv) * power_mult(E, st) * (1 + 0.15 * st.dept["crew"])

def hits_per_s(st, P):
    r, _ = hammer_now(st)
    return min(P["cps"], 1 / (0.8 * RARITY_CD[r - 1]))

def reps_per_s(st, P):
    r, _ = hammer_now(st)
    return min(P["cps"], 1 / (0.8 * min(0.3, RARITY_CD[r - 1])))

def station(E, st):
    best = E["stations"][0]
    for s in E["stations"]:
        if st.S >= s[0]: best = s
    return best

def crate_price(E, st, zone):
    if E["crate_price"] == "fixed":
        return E["crate_fixed"][zone]
    best = None
    for c in E["contracts"]:
        if unlocked(E, st, c) and (best is None or c["reward"] > best["reward"]): best = c
    best = best or E["contracts"][0]
    ipm = best["reward"] * cash_mult(E, st) * 1.1 / ((best["target"] + 20) / 60)
    return max(150, math.floor(ipm * 1.5))

def open_crate(st, crate, rng):
    odds = CRATE_ODDS[crate]
    x = rng.random() * sum(odds)
    for i, o in enumerate(odds):
        x -= o
        if x <= 0:
            st.hammers.append([i + 1, 1]); break
    st.crates_opened[crate] = st.crates_opened.get(crate, 0) + 1
    # keep the bag small: only the best few matter for power
    st.hammers.sort(key=lambda h: -hammer_power(h[0], h[1]))
    del st.hammers[6:]

def add_xp(st, xp):
    st.xp += xp
    while st.xp >= xp_for_level(st.L):
        st.xp -= xp_for_level(st.L)
        st.L += 1

def log(st, what):
    st.events.append((st.t, what))

# ---------------------------------------------------------------------------------------------------------------------
def build_time(E, st, c, P, first_ever=False):
    """seconds to build contract c once, the hits made, and whether it beat its target time"""
    work = c["work"] * (0.5 if first_ever and E["first_job_half"] else 1)
    r, lv = hammer_now(st)
    hit = hammer_power(r, lv) * power_mult(E, st) * P["combo"]
    you = hits_per_s(st, P) * P["active"] * hit
    cm = crew_mult(E, st)
    boost = min(0.4, sum(E["workers"][w]["boost"] for w in st.workers))
    crew = sum(E["workers"][w]["rate"] for w in st.workers) * (1 + boost) * cm
    t = 0.0
    for verb, share in c["verbs"].items():
        mach = sum(E["machines"][m]["rate"] * machine_mult(lv_) for m, lv_ in st.machines.items() if verb in E["machines"][m]["verbs"]) * cm
        t += work * share / (you + crew + mach)
    hits = hits_per_s(st, P) * P["active"] * t
    return t, hits, t <= c["target"]

def do_build(E, st, c, P, rng):
    first_ever = st.completed == 0
    t, hits, fast = build_time(E, st, c, P, first_ever)
    st.t += t + P["job_overhead"]
    st.t_build += t + P["job_overhead"]
    st.S += hits * str_mult(E, st)
    st.gems += hits / 350
    variety = 1 + 0.2 * st.variety
    hot = 2 if rng.random() < st.hot_chance(c) else 1
    pay = c["reward"] * cash_mult(E, st) * variety * hot
    if fast: pay *= 1.25
    st.money += pay
    st.earned += pay
    st.gems += 1 + c["order"] // 4 + (1 if fast else 0)
    # VARIETY: +1 for a different building (max 5), the same one twice -> 0
    st.variety = 0 if st.last == c["id"] else min(5, st.variety + 1)
    st.last = c["id"]
    add_xp(st, c["xp"])
    st.completed += 1
    st.built[c["id"]] = st.built.get(c["id"], 0) + 1
    st.builds_by_zone[c["zone"]] = st.builds_by_zone.get(c["zone"], 0) + 1
    if st.built[c["id"]] == 1:
        st.first_t[c["id"]] = t
        log(st, f"first {c['id']} ({t:.0f}s, S {st.S:,.0f}, L{st.L})")
    road(E, st, rng)
    return t

def do_train(E, st, P, seconds):
    st.t += seconds + P["train_overhead"]
    st.t_train += seconds + P["train_overhead"]
    reps = reps_per_s(st, P) * seconds
    st.S += reps * station(E, st)[1] * str_mult(E, st)
    st.gems += reps / 700
    st.reps += reps

def road(E, st, rng):
    """the Empire Road: cash / Gems / crates when a step is reached (in order, the live list)"""
    R = E["road"]
    while st.road < len(R):
        s = R[st.road]
        stat, target = s["stat"], s["target"]
        v = None
        if stat.startswith("Built_"): v = st.built.get(stat[6:], 0)
        elif stat == "Completed": v = st.completed
        elif stat == "Workers": v = len(st.workers)
        elif stat == "GearTier": v = st.gear + 1
        elif stat == "Rebirths": v = st.R
        elif stat == "MachinesOwned": v = len(st.machines)
        elif stat.startswith("Owns_"): v = 1 if stat[5:] in st.machines else 0
        elif stat == "DeptLevels": v = sum(st.dept.values())
        elif stat == "DeptMax": v = max(st.dept.values())
        elif stat == "CratesOpened": v = sum(st.crates_opened.values())
        else: v = target   # (missions, trade-ups, properties, Index...: an active player gets them along the way)
        if v < target: break
        st.money += s["cash"]; st.earned += s["cash"]; st.gems += s["gems"]
        if s.get("crate"):
            cr = s["crate"]
            open_crate(st, ZONE_CRATE[zone_of(st)] if cr == "supply" else cr, rng)
        st.road += 1

# ---------------------------------------------------------------------------------------------------------------------
def shop(E, st, P, rng, next_c):
    """what the player buys between jobs (greedy, the way an active player plays)"""
    bought = True
    n = 0
    crates_done = False
    while bought and n < 60:
        bought = False
        n += 1
        cap = st.money * P["spend_share"]
        # 1) the crew the next building needs
        if next_c and len(st.workers) < next_c["crew"] and len(st.workers) < max_workers(st.L, st.R, st.dept["crew"]):
            w = "builder" if st.L >= 3 else "laborer"
            price = E["workers"][w]["price"] * 1.3 ** len(st.workers)
            if st.money >= price:
                st.money -= price; st.workers.append(w); st.t += P["buy_overhead"]; bought = True; continue
        # 2) the next training gear
        if st.gear + 1 < len(E["gear"]) and E["gear"][st.gear + 1][0] <= cap:
            st.money -= E["gear"][st.gear + 1][0]; st.gear += 1; st.t += P["buy_overhead"]; bought = True; continue
        # 3) workers up to the max
        if len(st.workers) < max_workers(st.L, st.R, st.dept["crew"]):
            if st.L >= 5 and "foreman" not in st.workers:
                w = "foreman"
            else:
                w = "builder" if st.L >= 3 else "laborer"
            price = E["workers"][w]["price"] * 1.3 ** len(st.workers)
            if price <= cap * 0.7:
                st.money -= price; st.workers.append(w); st.t += P["buy_overhead"]; bought = True; continue
        # 4) machines (and their upgrades)
        for m, cfg in E["machines"].items():
            if m not in st.machines and st.L >= cfg["lvl"] and cfg["price"] <= cap * 0.8:
                st.money -= cfg["price"]; st.machines[m] = 1; st.t += P["buy_overhead"]; bought = True; break
        if bought: continue
        # 5) upgrades (the cheapest useful one)
        best = None
        for d, base in DEPTS.items():
            if st.dept[d] < dept_cap(st.R):
                c = dept_cost(base, st.dept[d])
                if best is None or c < best[1]: best = (d, c)
        if best and best[1] <= cap * 0.5:
            st.money -= best[1]; st.dept[best[0]] += 1; st.t += P["buy_overhead"]; bought = True; continue
        # 6) zone crates (one batch of up to 10 a shopping trip)
        zone = zone_of(st)
        price = crate_price(E, st, zone)
        budget = st.money * P["crate_share"]
        if price <= budget and not crates_done:
            crates_done = True
            k = int(min(10, budget // price))
            for _ in range(k):
                st.money -= price; open_crate(st, ZONE_CRATE[zone], rng)
            st.crate_cash += k * price
            st.t += 1.5 * k
            bought = True; continue
        # 7) the hammer in hand, a level up
        h = hammer_now(st)
        lc = hammer_level_cost(h[0], h[1])
        if lc and lc <= cap * 0.3:
            st.money -= lc; h[1] += 1; st.t += P["buy_overhead"]; bought = True; continue

def best_farm(E, st, P):
    """the contract with the best pay a second right now (variety counted: a different one than the last)"""
    best, bv = None, -1
    for c in E["contracts"]:
        if not unlocked(E, st, c) or c["zone"] != zone_of(st) and c["reb"] < st.R - 0: pass
        if not unlocked(E, st, c): continue
        t, _, fast = build_time(E, st, c, P)
        streak = 0 if st.last == c["id"] else min(5, st.variety + 1)
        v = c["reward"] * (1 + 0.2 * streak) * (1.25 if fast else 1) / (t + P["job_overhead"])
        if v > bv: best, bv = c, v
    return best

def best_xp(E, st, P):
    best, bv = None, -1
    for c in E["contracts"]:
        if not unlocked(E, st, c): continue
        t, _, _ = build_time(E, st, c, P)
        v = c["xp"] / (t + P["job_overhead"])
        if v > bv: best, bv = c, v
    return best

def simulate(E, P=PLAYER, seed=1, until_R=3, max_hours=12, verbose=False):
    rng = random.Random(seed)
    st = State()
    st.t = 0.0; st.t_build = 0.0; st.t_train = 0.0
    st.S = 0.0; st.money = float(E["new_player_money"]); st.earned = 0.0; st.gems = 0.0
    st.L = 1; st.xp = 0; st.R = 0; st.gear = 0
    st.workers = []; st.machines = {}; st.dept = {d: 0 for d in DEPTS}
    st.hammers = [[1, 1]]
    st.completed = 0; st.built = {}; st.builds_by_zone = {}; st.variety = 0; st.last = None
    st.road = 0; st.reps = 0; st.crates_opened = {}; st.crate_cash = 0.0
    st.events = []; st.rebirth_at = {}; st.first_t = {}
    def hot_chance(c):
        zone_list = [x for x in E["contracts"] if x["zone"] == c["zone"]]
        return 1 / max(1, len(zone_list))
    st.hot_chance = hot_chance
    # the tutorial (measured in Studio: ~2.5 minutes; it buys a worker, the gloves, the excavator; 10 tire reps)
    zone_seq = E["contracts"]
    fence = E["contracts"][0]
    do_build(E, st, fence, P, rng)                 # step 1: the first fence (half the work), the Supply Crate
    st.money -= E["workers"]["laborer"]["price"]; st.workers.append("laborer")
    st.money -= E["gear"][1][0]; st.gear = 1
    do_train(E, st, P, 10 / reps_per_s(st, P))    # 10 reps at the Tire Flip
    st.money -= E["machines"]["excavator"]["price"]; st.machines["excavator"] = 1
    road(E, st, rng)
    c2 = E["contracts"][1] if unlocked(E, st, E["contracts"][1]) else fence
    do_build(E, st, c2, P, rng)                    # step 6: the second job
    st.t += 15                                      # step 7: the trip to the Training Yard
    road(E, st, rng)
    log(st, f"tutorial done (S {st.S:.0f}, L{st.L}, ${st.money:,.0f})")
    st.t_tutorial = st.t

    while st.R < until_R and st.t < max_hours * 3600:
        zone_cs = [c for c in E["contracts"] if c["reb"] == st.R]
        top = zone_cs[-1]
        # the next building of this zone not built yet (in order)
        nxt = next((c for c in zone_cs if st.built.get(c["id"], 0) == 0), None)
        shop(E, st, P, rng, nxt)
        if nxt is None and st.L >= rebirth_level(st.R):
            # REBIRTH
            st.rebirth_at[st.R + 1] = st.t
            log(st, f"REBIRTH {st.R + 1} (L{st.L}, S {st.S:,.0f})")
            st.R += 1
            st.money = 25 + 0.01 * [150e3, 600e6, 25e9, 150e9][min(st.R - 1, 3)]
            st.gear = 0; st.workers = []; st.machines = {}; st.dept = {d: 0 for d in DEPTS}
            st.variety = 0; st.last = None
            road(E, st, rng)
            continue
        if nxt is not None and unlocked(E, st, nxt):
            do_build(E, st, nxt, P, rng)
            continue
        if nxt is None:
            # every building done: the Level for the Rebirth (build what gives XP the fastest)
            c = best_xp(E, st, P)
            do_build(E, st, c, P, rng)
            continue
        # blocked: Strength or crew
        if len(st.workers) < nxt["crew"]:
            c = best_farm(E, st, P)
            do_build(E, st, c, P, rng)
            continue
        # Strength: train at the yard, or build (it gives Strength too, and cash / XP). An active player trains when
        # training gets it there clearly faster, but builds when the next gear (x2 training) is close to affordable.
        train_rate = reps_per_s(st, P) * station(E, st)[1] * str_mult(E, st)
        c = best_farm(E, st, P)
        t_b, hits, _ = build_time(E, st, c, P)
        build_rate = hits * str_mult(E, st) / (t_b + P["job_overhead"])
        nextgear = E["gear"][st.gear + 1][0] if st.gear + 1 < len(E["gear"]) else None
        need = nxt["reqS"] - st.S
        if nextgear and st.money < nextgear and nextgear < 3 * c["reward"] * cash_mult(E, st):
            do_build(E, st, c, P, rng)                       # the next gear first: it doubles training
        elif train_rate > 1.3 * build_rate:
            secs = min(90.0, need / train_rate + 0.5)
            do_train(E, st, P, secs)
        else:
            do_build(E, st, c, P, rng)
    st.gems = int(st.gems)
    return st

def report(E, seeds=range(1, 7), until_R=3, P=PLAYER, show_events=True):
    runs = [simulate(E, P, seed=s, until_R=until_R) for s in seeds]
    print(f"\n=== {E['name']}  ({len(runs)} runs, active free player)")
    for R in range(1, until_R + 1):
        ts = [r.rebirth_at.get(R) for r in runs if r.rebirth_at.get(R)]
        if ts:
            print(f"  Rebirth {R}: {sum(ts) / len(ts) / 60:6.1f} min  (min {min(ts)/60:.1f}, max {max(ts)/60:.1f})")
    r = runs[0]
    print(f"  tutorial {r.t_tutorial/60:.1f} min; build {r.t_build/60:.0f} min, train {r.t_train/60:.0f} min of {r.t/60:.0f}")
    print(f"  builds by zone {r.builds_by_zone}; crates {r.crates_opened}; best hammer r{hammer_now(r)[0]} lv{hammer_now(r)[1]}; gems {r.gems}")
    if show_events:
        for t, w in r.events:
            print(f"    {t/60:6.1f} min  {w}")
    return runs

if __name__ == "__main__":
    report(live_econ())
