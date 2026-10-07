"""The proposed economy, as knobs: build an economy from parameters, calibrate each contract's work to a target build
time, and score a run against the pacing targets (from the top Roblox simulators; see recipe.md)."""
import math, copy
import sim
from sim import ORDER, VERBS

# the pacing a free player who plays actively should feel (minutes from the first join)
TARGET_ACTIVE = {1: 17, 2: 52, 3: 135, 4: 270, 5: 520}
TARGET_CLOCK = {1: 17, 2: 52, 3: 135, 4: 270, 5: 520, 6: 900, 7: 1500}
TOL = {1: (14, 21), 2: (42, 62), 3: (110, 160), 4: (225, 320), 5: (430, 620)}

# target build time of each contract the first time it is reached (seconds, without the 20 s walk / finish)
TARGET_BUILD = {"fence": 25, "shed": 35, "garage": 45, "house": 55, "shop": 65,
                "villa": 55, "warehouse": 65, "apartments": 75, "luxvilla": 85, "distcenter": 95,
                "office": 75, "hotel": 85, "skyscraper": 100, "hq": 115, "spire": 130}

DEFAULT = dict(
    r1_cost=40e3,           # money earned in the run for Rebirth 1
    r_growth=60.0,          # Rebirth n+1 costs x this more (first step)
    r_growth_late=12.0,     # ... and after Rebirth 3
    reb_cash=1.0,           # +100% cash per Rebirth (additive)
    reb_strength=1.0,       # +100% Strength gains per Rebirth
    reb_power=0.0,          # +x build power per Rebirth (multiplicative 1 + x*R)
    reward_scale=1.0,       # all contract rewards x this
    zone_jump=1.0,          # rewards of zone 2/3 x this (zone 3 x this^2)
    worker_rate=1.0,        # worker rates x this
    machine_rate=1.0,       # machine rates x this
    worker_growth=1.25,     # each worker you hire costs x this more
    dept_per=0.10,
    dept_growth=1.55,
    prop_payback_min=15.0,  # first unit of a property pays back in this many minutes (online)
    prop_growth=1.35,
    offline_share=0.5,
    offline_cap_h=8.0,
    rarity_step=1.8,
    tradeup_top=6,          # trade-ups go up to Mythic (index 6 in 1..8); Secret / Divine only from crates
    luck_from_r=5,          # luck multiplies Legendary and rarer
    supply_price_min=1.5,   # a Supply Crate costs this many minutes of your zone's income (min)
    calib_rounds=4,
)

# crate odds (in %, Common..Divine): the proposal (zone crates for cash; only the Golden Crate can give Secret / Divine)
CRATES = {
    "supply_town": dict(cash=True, zone="town", odds=[75, 20, 4, 1, 0, 0, 0, 0]),
    "supply_suburbs": dict(cash=True, zone="suburbs", odds=[52, 33, 12, 2.6, 0.4, 0, 0, 0]),
    "supply_downtown": dict(cash=True, zone="downtown", odds=[0, 55, 33, 10.8, 1.15, 0.05, 0, 0]),
    "builder": dict(gems=200, odds=[0, 52, 36, 10, 1.85, 0.15, 0, 0]),
    "golden": dict(gems=750, odds=[0, 0, 55.996, 33, 9.4, 1.3, 0.3, 0.004]),
}

def build(p):
    E = sim.current()
    E["name"] = "PROPOSAL"
    E["crates"] = copy.deepcopy(CRATES)
    E["rarity_step"] = p["rarity_step"]
    E["tradeup_top"] = p["tradeup_top"]
    E["luck_from_r"] = p["luck_from_r"]
    zone_mult = {"town": 1.0, "suburbs": p["zone_jump"], "downtown": p["zone_jump"] ** 2}
    for c in E["contracts"]:
        c["reward"] = c["reward"] * p["reward_scale"] * zone_mult[c["zone"]]
    # Downtown opens one contract per Rebirth after the second (office/hotel R2, skyscraper R3, hq R4, spire R5)
    rb = {"office": 2, "hotel": 2, "skyscraper": 3, "hq": 4, "spire": 5}
    for c in E["contracts"]:
        if c["id"] in rb: c["reqReb"] = rb[c["id"]]
    E["reb_costs"] = list(p.get("reb_costs", [40e3, 2e6, 1e8, 3e9, 6e10, 1e12, 2e13]))

    def cost(n):
        L = E["reb_costs"]
        return L[n] if n < len(L) else L[-1] * 20 ** (n - len(L) + 1)
    E["rebirth_cost"] = cost
    E["rebirth_cash"] = lambda R: 1 + p["reb_cash"] * R
    E["rebirth_strength"] = lambda R: 1 + p["reb_strength"] * R
    E["rebirth_power"] = lambda R: 1 + p["reb_power"] * R
    for w in E["workers"].values(): w["rate"] *= p["worker_rate"]
    for m in E["machines"].values(): m["rate"] *= p["machine_rate"]
    E["worker_price_growth"] = p["worker_growth"]
    E["depts"] = {k: (p["dept_per"], v[1]) for k, v in E["depts"].items()}
    E["dept_growth"] = p["dept_growth"]
    # properties: one unit rents for prop_unit_share of what building that contract earns per minute (base pay), and
    # costs prop_payback_min minutes of its rent (so they track the zones, never outgrow building)
    byid = {c["id"]: c for c in E["contracts"]}
    for pid in list(E["props"].keys()):
        c = byid[pid]
        rent = p.get("prop_unit_share", 0.05) * c["reward"] / ((TARGET_BUILD[pid] + 20) / 60.0)
        E["props"][pid] = (rent * p["prop_payback_min"], rent)
    E["prop_rent_rebirth"] = p.get("prop_rent_rebirth", True)
    E["prop_growth"] = p["prop_growth"]
    E["prop_milestones"] = p.get("prop_milestones", [(10, 1.5)])
    E["prop_max"] = p.get("prop_max", 10)
    E["offline_share"] = p["offline_share"]
    E["offline_cap_h"] = p["offline_cap_h"]
    E["supply_price_min"] = p["supply_price_min"]
    # the Training Yard: a speed-up over building (x2 .. x8 the Strength of a build hit), never the only way
    E["stations"] = p.get("stations", [(0, 2), (4e3, 3), (1.5e5, 5), (5e6, 8)])
    E["price_scale"] = p.get("price_scale", 1.0)
    # contract Gems: 1 + order/4 (+1 fast) instead of order/2 (Gems stay premium)
    E["gems_contract"] = lambda order, fast: 1 + order // 4 + (1 if fast else 0)
    return E


def calibrate(E, p, players=("active",), rounds=None):
    """set each contract's workMult so that a reference active player builds it in TARGET_BUILD the first time it is
    the best job; strength requirements follow what that player has at the time (soft gates)"""
    rounds = rounds or p["calib_rounds"]
    for _ in range(rounds):
        s = sim.simulate(E, sim.PLAYERS["active"], hours=14, record=True)
        firsts = {}
        for (t, cid, dur, R, share, hits) in s.contract_log:
            if cid not in firsts: firsts[cid] = dur
        for c in E["contracts"]:
            if c["id"] in firsts:
                ratio = TARGET_BUILD[c["id"]] / max(1.0, firsts[c["id"]])
                c["workMult"] *= max(0.33, min(3.0, ratio)) ** 0.85
    return E


def score(runs):
    """lower is better: how far the rebirth clock is from the targets (log distance), plus feel penalties"""
    a = runs["active"]
    pen = 0.0
    reb = a["rebirth_minutes"]
    for n, target in TARGET_ACTIVE.items():
        if len(reb) >= n:
            pen += abs(math.log(reb[n - 1] / target)) * (2.0 if n <= 2 else 1.0)
        else:
            pen += 3.0
    c = runs.get("casual")
    if c and c["rebirth_minutes"]:
        ratio = c["rebirth_minutes"][0] / max(1e-9, reb[0] if reb else 1e9)
        pen += abs(math.log(ratio / 1.7)) * 0.5
    py = runs.get("payer")
    if py and py["rebirth_minutes"] and reb:
        ratio = reb[0] / py["rebirth_minutes"][0]
        pen += abs(math.log(ratio / 1.7)) * 0.5
    pen += max(0.0, a["cps"] - 1.6) * 1.0          # a tiring clicker
    sp = a["split"][0]
    pen += max(0.0, sp - 0.55) * 2.0               # the player does too much of the work alone
    rs = a["rent_share"]
    pen += abs(rs - 0.2) * 1.5
    return pen


def nice(x):
    """round to a nice number (1, 1.5, 2, 2.5, 3, 4, 5, 6, 7.5 x 10^n)"""
    if x <= 0: return 0
    e = math.floor(math.log10(x))
    m = x / 10 ** e
    for n in (1, 1.5, 2, 2.5, 3, 4, 5, 6, 7.5, 10):
        if m <= n * 1.12:
            return n * 10 ** e
    return 10 ** (e + 1)


def calibrate_rebirths(E, upto=7, player="active"):
    """each Rebirth's cost = what the reference player has earned in that run when the run has lasted as long as the
    pacing targets say (TARGET_CLOCK); runs one Rebirth at a time"""
    T = TARGET_CLOCK
    for n in range(upto):
        s = sim.simulate(E, sim.PLAYERS[player], hours=T.get(n + 1, 2500) / 60 * 1.6 + 1, record=True, hold_at=n)
        reb = s.events["rebirth"]
        if len(reb) < n:
            break
        t0 = reb[n - 1] if n > 0 else 0.0
        want = (T[n + 1] - (T[n] if n > 0 else 0)) * 60
        # this run's earnings over time (the gate building must be built too)
        best = None
        for (t, R, earned, gate, strength) in s.run_log:
            if R == n and t - t0 >= want:
                best = earned if gate else None
                if best is not None: break
        if best is None:
            pts = [(t, e) for (t, R, e, g, st) in s.run_log if R == n and g]
            if not pts: break
            best = pts[-1][1]
        E["reb_costs"][n] = nice(best)
    return E


# the run in which each contract is new, and when in that run it should open (minutes from the run's start)
NEW_IN = {"fence": 0, "shed": 0, "garage": 0, "house": 0, "shop": 0,
          "villa": 1, "warehouse": 1, "apartments": 1, "luxvilla": 1, "distcenter": 1,
          "office": 2, "hotel": 2, "skyscraper": 3, "hq": 4, "spire": 5}
OPEN_AT = {"fence": 0, "shed": 1.2, "garage": 3.5, "house": 7, "shop": 11,
           "villa": 0, "warehouse": 5, "apartments": 11, "luxvilla": 18, "distcenter": 26,
           "office": 0, "hotel": 30, "skyscraper": 45, "hq": 70, "spire": 110}


def simplify_gates(E):
    """the proposal's gates: Rebirth (the zone) and Strength (+ the crew size); no hammer-rarity, level or rep gates"""
    for c in E["contracts"]:
        c["reqHam"] = 1
        c["reqRep"] = 0
        c["reqLevel"] = 1
        c["reqCrew"] = min(c["reqCrew"], {"town": 3, "suburbs": 6, "downtown": 8}[c["zone"]])
    return E


def calibrate_all(E, p, rounds=5, verbose=False):
    """work (build time), strength gates (when each contract opens in its run) and Rebirth costs (the clock), together"""
    simplify_gates(E)
    ref = dict(sim.PLAYERS["active"]); ref["train"] = False   # the gates follow the Strength you get from BUILDING
    for rnd in range(rounds):
        s = sim.simulate(E, ref, hours=30, record=True)
        reb = [0.0] + s.events["rebirth"]
        rf = s.events.get("run_first", {})
        # strength over time per run
        strength_at = {}
        for (tt, R, earned, gate, st) in s.run_log:
            strength_at.setdefault(R, []).append((tt, st))
        for c in E["contracts"]:
            n = NEW_IN[c["id"]]
            key = (n, c["id"])
            # build time
            if key in rf:
                dur = rf[key][1]
                ratio = TARGET_BUILD[c["id"]] / max(1.0, dur)
                c["workMult"] *= max(0.4, min(2.5, ratio)) ** 0.8
            # the strength gate: what the player has OPEN_AT minutes into that run
            if n < len(reb) and n in strength_at and OPEN_AT[c["id"]] > 0:
                t_open = reb[n] + OPEN_AT[c["id"]] * 60
                pts = strength_at[n]
                st = None
                for (tt, sv) in pts:
                    if tt >= t_open:
                        st = sv
                        break
                if st is None and pts: st = pts[-1][1] * 1.3
                if st is not None:
                    c["reqStr"] = nice(max(1, st))
            elif OPEN_AT[c["id"]] == 0:
                c["reqStr"] = 0
        # Rebirth costs: what was earned in each run at its target length
        T = TARGET_CLOCK
        for n in range(min(len(reb), 5)):
            t0 = reb[n]
            want = (T[n + 1] - (T[n] if n > 0 else 0)) * 60
            best = None
            for (tt, R, earned, gate, st) in s.run_log:
                if R == n and tt - t0 >= want and gate:
                    best = earned
                    break
            if best is None:
                pts = [e for (tt, R, e, g, st) in s.run_log if R == n and g]
                if pts: best = pts[-1] * 1.0
            if best: E["reb_costs"][n] = nice(best)
        # past Rebirth 5: the same growth as the last step, x1.5 (a long tail until new zones come)
        L = E["reb_costs"]
        g = max(4.0, L[4] / max(1.0, L[3])) * 1.5
        for k in range(5, len(L)): L[k] = nice(L[k - 1] * g)
        if verbose:
            r = sim.report(s)
            print("round", rnd, r["rebirth_minutes"], [f"{x:.2g}" for x in E["reb_costs"]])
    return E


def first_build_times(s, n):
    out = {}
    for (tt, cid, dur, R, share, hits) in s.contract_log:
        if R == n and cid not in out: out[cid] = (tt, dur)
    return out


def calibrate_seq(E, p, upto=5, verbose=False):
    """one run at a time: the new contracts' work (build time), their Strength gates (from the Strength you get by
    building), then that Rebirth's cost (what the run has earned at its target length)"""
    simplify_gates(E)
    ref = dict(sim.PLAYERS["active"])
    T = TARGET_CLOCK
    big = 1e30
    for c in E["contracts"]:
        if OPEN_AT[c["id"]] > 0: c["reqStr"] = big       # closed until calibrated
    for n in range(upto):
        new = [c for c in E["contracts"] if NEW_IN[c["id"]] == n]
        length = (T[n + 1] - (T[n] if n > 0 else 0)) * 60
        # 1. open the new contracts in order, each at its OPEN_AT, with its work tuned to the target build time
        for c in sorted(new, key=lambda c: OPEN_AT[c["id"]]):
            for it in range(4):
                saved = E["reb_costs"][n]
                E["reb_costs"][n] = big
                s = sim.simulate(E, ref, hours=(T.get(n, 0) * 60 + length * 1.5) / 3600 + 0.2, record=True, hold_at=n)
                E["reb_costs"][n] = saved
                reb = [0.0] + s.events["rebirth"]
                if len(reb) <= n: break
                t0 = reb[n]
                # the Strength gate: what the player has OPEN_AT into the run (building only)
                if OPEN_AT[c["id"]] > 0 and it == 0:
                    pts = [(tt, st) for (tt, R, e, g, st) in s.run_log if R == n]
                    want = t0 + OPEN_AT[c["id"]] * 60
                    st = next((sv for (tt, sv) in pts if tt >= want), pts[-1][1] if pts else 0)
                    c["reqStr"] = nice(max(1, st))
                    continue
                fb = first_build_times(s, n)
                if c["id"] not in fb: break
                dur = fb[c["id"]][1]
                ratio = TARGET_BUILD[c["id"]] / max(0.5, dur)
                if abs(math.log(ratio)) < 0.08: break
                c["workMult"] *= max(0.3, min(3.0, ratio))
        # 2. the Rebirth cost: earned in this run when it has lasted its target length (and the gate is built)
        E["reb_costs"][n] = big
        s = sim.simulate(E, ref, hours=(T.get(n, 0) * 60 + length * 1.6) / 3600 + 0.2, record=True, hold_at=n)
        reb = [0.0] + s.events["rebirth"]
        if len(reb) <= n:
            E["reb_costs"][n] = 1e12
            continue
        t0 = reb[n]
        best = None
        for (tt, R, earned, gate, st) in s.run_log:
            if R == n and tt - t0 >= length and gate:
                best = earned
                break
        if best is None:
            pts = [e for (tt, R, e, g, st) in s.run_log if R == n and g]
            best = pts[-1] if pts else 1e12
        E["reb_costs"][n] = nice(best)
        if verbose:
            print("run", n, "cost", f"{E['reb_costs'][n]:.3g}", [(c["id"], round(c["workMult"], 2), f"{c['reqStr']:.2g}") for c in new])
    L = E["reb_costs"]
    g = max(4.0, L[upto - 1] / max(1.0, L[upto - 2])) * 1.5
    for k in range(upto, len(L)): L[k] = nice(L[k - 1] * g)
    return E
