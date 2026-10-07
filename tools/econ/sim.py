"""BlockRise Empire - economy simulator.

Simulates a player through contracts, upgrades, crates and rebirths with the game's real formulas (read from Studio:
Config, Company, Hammers, Main, Crew, Machines, CompanyService, RebirthService), so a set of numbers can be judged by what
it does to a player's clock: minutes to Rebirth 1..N, contract length, clicks, how often something is bought, hammers.

    econ = current()            # the numbers in the game today
    run = simulate(econ, PLAYERS["active"], hours=12)
    report(run)

Everything is deterministic except crate rolls (seeded).
"""
import math, random, copy

# ------------------------------------------------------------------------------------------------------------------
# the game's content (stage work per verb = blueprint base work; the contract's workMult multiplies it)
# ------------------------------------------------------------------------------------------------------------------
VERBS = {
    "fence": {"clear": 10, "hammer": 38},
    "shed": {"clear": 10, "dig": 14, "glass": 6, "hammer": 8, "pour": 16, "wood": 60},
    "garage": {"brick": 95, "clear": 20, "dig": 35, "glass": 15, "hammer": 25, "metal": 20, "pour": 35, "wood": 45},
    "house": {"brick": 230, "clear": 40, "dig": 80, "glass": 60, "hammer": 100, "metal": 50, "pour": 80, "wood": 140},
    "shop": {"brick": 330, "clear": 60, "dig": 120, "glass": 120, "hammer": 150, "metal": 70, "pour": 250},
    "villa": {"brick": 700, "clear": 80, "dig": 160, "glass": 300, "hammer": 300, "metal": 100, "pour": 160, "wood": 400},
    "warehouse": {"clear": 120, "dig": 240, "glass": 120, "hammer": 300, "metal": 1050, "pour": 590},
    "apartments": {"brick": 1400, "clear": 150, "dig": 300, "glass": 800, "hammer": 400, "metal": 180, "pour": 600},
    "luxvilla": {"brick": 750, "clear": 90, "dig": 170, "glass": 320, "hammer": 330, "metal": 110, "pour": 170, "wood": 420},
    "distcenter": {"clear": 130, "dig": 260, "glass": 140, "hammer": 330, "metal": 1120, "pour": 640},
    "office": {"clear": 200, "dig": 400, "glass": 2400, "hammer": 600, "metal": 300, "pour": 800},
    "hotel": {"brick": 2400, "clear": 250, "dig": 500, "glass": 1200, "hammer": 700, "metal": 350, "pour": 900},
    "skyscraper": {"clear": 300, "dig": 600, "glass": 4200, "hammer": 1250, "metal": 450, "pour": 1200},
    "hq": {"clear": 350, "dig": 700, "glass": 4800, "hammer": 1250, "metal": 500, "pour": 1400},
    "spire": {"clear": 400, "dig": 800, "glass": 5400, "hammer": 1200, "metal": 600, "pour": 1600},
}
ORDER = list(VERBS.keys())
ZONE_OF = {k: ("town" if i < 5 else "suburbs" if i < 10 else "downtown") for i, k in enumerate(ORDER)}

MACHINE_VERBS = {"excavator": {"dig", "clear"}, "mixer": {"pour"}, "crane": {"metal", "glass"}}

RARITY = ["common", "uncommon", "rare", "epic", "legendary", "mythic", "secret", "divine"]
COOLDOWN = [0.42, 0.38, 0.34, 0.30, 0.27, 0.25, 0.23, 0.21]
MATS = ["steel", "copper", "marble", "gold", "diamond"]
# FIDELITY_V2 (read from Studio, Company.StarPerks): max levels; level n -> n+1 costs n+1 Stars
PERK_MAX = {"tycoon": 10, "genes": 10, "lawyer": 10, "lucky": 10, "headstart": 10, "crew": 5}
PERK_ORDER = ["tycoon", "tycoon", "crew", "headstart", "tycoon", "genes", "crew", "headstart", "genes", "lawyer"]
# material sell prices and what each building drops (Company.Materials / Company.Drops), finds per hit 1/30, 3 per contract
MAT_SELL = {"steel": 40, "copper": 250, "marble": 1500, "gold": 10000, "diamond": 80000}
DROPS = [{"steel": 100}, {"steel": 100}, {"steel": 90, "copper": 10}, {"steel": 65, "copper": 35}, {"steel": 40, "copper": 60},
         {"copper": 65, "marble": 35}, {"copper": 45, "marble": 55}, {"copper": 20, "marble": 60, "gold": 20},
         {"marble": 55, "gold": 45}, {"marble": 25, "gold": 50, "diamond": 25}, {"marble": 20, "gold": 60, "diamond": 20},
         {"gold": 65, "diamond": 35}, {"gold": 55, "diamond": 45}, {"gold": 45, "diamond": 55}, {"gold": 30, "diamond": 70}]


def current():
    """The economy as it is in the game today (Studio, 2026-10-07)."""
    E = {}
    E["name"] = "CURRENT"
    E["start_money"] = 25
    E["new_player_money"] = 150 + 250 + 2500 + 200
    # id: reward, xp, rep, reqRep, reqLevel, reqStr, reqCrew, reqHam, reqReb, workMult, target
    C = {
        "fence": (60, 25, 1, 0, 1, 0, 0, 1, 0, 4.35, 33),
        "shed": (190, 55, 2, 1, 1, 0, 0, 1, 0, 3.30, 48),
        "garage": (520, 120, 3, 6, 2, 60, 1, 1, 0, 2.98, 63),
        "house": (1600, 300, 5, 24, 3, 400, 2, 2, 0, 3.33, 78),
        "shop": (4200, 620, 8, 60, 5, 2500, 3, 2, 0, 5.04, 93),
        "villa": (14000, 1300, 12, 130, 7, 15000, 4, 3, 1, 9.77, 108),
        "warehouse": (32000, 2100, 18, 235, 9, 60000, 5, 3, 1, 13.04, 120),
        "apartments": (85000, 3600, 26, 405, 11, 200000, 6, 3, 1, 9.64, 132),
        "luxvilla": (210000, 6000, 36, 715, 13, 600000, 7, 3, 1, 18.52, 144),
        "distcenter": (520000, 9000, 50, 1130, 15, 1500000, 8, 4, 1, 28.67, 158),
        "office": (1600000, 15000, 70, 1200, 16, 4900000, 8, 4, 2, 23.05, 173),
        "hotel": (4500000, 24000, 95, 1500, 18, 6800000, 9, 4, 2, 18.09, 188),
        "skyscraper": (14000000, 38000, 125, 1900, 20, 8900000, 10, 4, 2, 16.81, 203),
        "hq": (45000000, 60000, 160, 2400, 22, 12000000, 10, 4, 3, 16.31, 218),
        "spire": (150000000, 100000, 200, 3000, 25, 35000000, 12, 4, 4, 19.24, 240),
    }
    E["contracts"] = []
    for k in ORDER:
        r, xp, rep, rr, rl, rs, rc, rh, rb, wm, tt = C[k]
        E["contracts"].append(dict(id=k, zone=ZONE_OF[k], reward=r, xp=xp, rep=rep, reqRep=rr, reqLevel=rl, reqStr=rs, reqCrew=rc,
                                   reqHam=rh, reqReb=rb, workMult=wm, target=tt))
    E["xp_for_level"] = lambda L: math.floor(120 * L ** 1.45)
    # hammers
    E["rarity_step"] = 1.35
    E["level_step"] = 0.08
    E["max_level"] = 10
    E["level_base"] = [120, 500, 2500, 12000, 60000, 300000, 1500000, 8000000]
    E["level_growth"] = 1.6
    E["tradeup"] = 10
    E["tradeup_top"] = 8          # trade-ups go up to this rarity index (8 = Divine)
    # crates: odds per rarity index 1..8 in %
    E["crates"] = {
        "supply_town": dict(cash=True, zone="town", odds=[62, 28, 9, 1, 0, 0, 0, 0]),
        "supply_suburbs": dict(cash=True, zone="suburbs", odds=[30, 38, 22, 8, 2, 0, 0, 0]),
        "supply_downtown": dict(cash=True, zone="downtown", odds=[0, 30, 40, 24, 6, 0, 0, 0]),
        "builder": dict(gems=150, odds=[0, 45, 35, 15, 4.5, 0.5, 0, 0]),
        "golden": dict(gems=600, odds=[0, 0, 40, 35, 18, 6, 0.9, 0.1]),
    }
    E["supply_price"] = lambda best_reward: max(150, math.floor(best_reward * 0.15))
    E["free_crate_every"] = 6
    E["builder_drop"] = 0.03
    E["luck_from_r"] = 3          # luck multiplies the weights of rarities >= this
    # strength
    E["strength_mult"] = lambda s: 1 + 0.35 * math.log2(1 + max(0, s) / 100)
    E["gear"] = [(0, 1), (250, 2), (720, 4), (2100, 8), (6100, 16), (17700, 32), (51300, 64), (149000, 128), (431000, 256),
                 (1250000, 512), (3630000, 1024), (10500000, 2048)]
    E["stations"] = [(0, 3), (3000, 8), (60000, 20), (1000000, 50)]
    E["train_cd"] = 0.3
    # crew & machines
    E["workers"] = {"laborer": dict(price=200, rate=0.35, eff=0.75, lvl=1), "builder": dict(price=800, rate=0.85, eff=0.85, lvl=3),
                    "foreman": dict(price=6000, rate=0.6, eff=1.0, boost=0.20, lvl=5)}
    E["worker_price_growth"] = 1.0   # price x this per worker already hired
    E["max_workers"] = lambda L: min(2 + L // 2, 10)
    E["machines"] = {"excavator": dict(price=2500, rate=3, lvl=1), "mixer": dict(price=6500, rate=4, lvl=5),
                     "crane": dict(price=120000, rate=3, lvl=12)}
    E["machine_mult"] = lambda lv: 1 + 0.5 * (lv - 1)
    E["machine_up_cost"] = lambda price, lv: price * 2.2 ** lv
    E["machine_max"] = 10
    # upgrades (departments)
    E["depts"] = {"power": (0.10, 2500), "strength": (0.12, 2000), "cash": (0.10, 2000), "crew": (0.10, 3000), "rent": (0.10, 4000)}
    E["dept_growth"] = 1.55
    E["dept_cap"] = lambda R: min(50, 10 * (1 + min(2, R)))
    # properties: id -> (cost, rent/min); unlocked by building that contract once
    E["props"] = {"shed": (1200, 40), "garage": (5000, 150), "house": (20000, 520), "shop": (80000, 1800), "villa": (320000, 6300),
                  "warehouse": (1300000, 22000), "apartments": (5200000, 77000), "luxvilla": (21000000, 270000),
                  "distcenter": (85000000, 950000), "office": (340000000, 3300000), "hotel": (1400000000, 12000000),
                  "skyscraper": (5500000000, 42000000), "hq": (22000000000, 150000000), "spire": (90000000000, 540000000)}
    E["prop_growth"] = 1.15
    E["prop_milestones"] = [(10, 2), (25, 2), (50, 2), (100, 3)]
    E["company_level"] = 5
    E["company_cost"] = 5000
    E["offline_share"] = 1.0
    E["offline_cap_h"] = 1e9
    # rebirth
    E["rebirth_cost"] = lambda n: [150e3, 40e6, 10e9, 100e9, 1e12][n] if n < 5 else 1e12 * 10 ** (n - 4)
    E["rebirth_cash"] = lambda R: 1 + 0.5 * R
    E["rebirth_strength"] = lambda R: 1 + 0.5 * R
    E["rebirth_power"] = lambda R: 1.0
    E["rebirth_gate_last_contract"] = True
    E["zone_reb"] = {"town": 0, "suburbs": 1, "downtown": 2}
    # pay
    E["stage_overhead"] = 20.0       # walking, accepting, the finished-building moment
    E["speed_bonus"] = 0.25
    E["combo_avg"] = 1.8
    # gems
    E["gem_hit"] = 1 / 350
    E["gems_contract"] = lambda order, fast: max(1, order // 2) + (1 if fast else 0)
    E["gems_day"] = 15 + 21 + 43      # 3 missions + streak + playtime gifts (a daily session)
    E["mat_drop"] = 1 / 30
    E["contract_finds"] = 3
    # extensions & house (one-off)
    E["extensions"] = {"office": 2500, "workshop": 4000, "garage": 1200}
    return E


# ------------------------------------------------------------------------------------------------------------------
# the players
# ------------------------------------------------------------------------------------------------------------------
PLAYERS = {
    # cps: clicks per second while clicking; active: share of a build spent clicking; crate_share: share of income put
    # into cash crates; train: trains when a gate is in the way
    "active": dict(cps=5.0, active=0.75, crate_share=0.08, train=True, passes=set(), boosts=0.0),
    "casual": dict(cps=4.0, active=0.45, crate_share=0.05, train=True, passes=set(), boosts=0.0),
    "payer": dict(cps=5.0, active=0.70, crate_share=0.10, train=True, passes={"cash2x", "strength2x", "vip"}, boosts=0.15),
    "whale": dict(cps=5.0, active=0.70, crate_share=0.15, train=True,
                  passes={"cash2x", "strength2x", "vip", "autobuild", "fasttools", "thunder", "luck", "bigcrew"}, boosts=0.5),
}


class State:
    def __init__(self, E, P, seed=1):
        self.E, self.P = E, P
        self.rng = random.Random(seed)
        self.t = 0.0
        self.money = E["new_player_money"]
        self.earned_run = 0.0
        self.gems = 0
        self.strength = 0.0
        self.level, self.xp, self.rep = 1, 0, 0
        self.R = 0
        self.gear = 0
        self.workers = []
        self.machines = {}
        self.dept = {k: 0 for k in E["depts"]}
        self.props = {}
        self.company = False
        self.exts = set()
        self.mats = {m: 0.0 for m in MATS}
        self.built = {}
        self.best = (0, 1)           # the hammer in hand: (rarity index 0..7, level)
        self.inv = [0] * 8           # spare hammers per rarity (level 1)
        self.crates = {}
        self.crate_progress = 0
        self.log = []
        self.events = {"rebirth": [], "first": {}}
        self.clicks = 0
        self.purchases = []
        self.contracts_done = 0
        self.work_split = [0.0, 0.0, 0.0]   # player, crew, machines
        self.rent_earned = 0.0
        self.train_time = 0.0
        # FIDELITY_V2: Rebirth Stars and the Star Shop perks (RebirthService), what the game gives on top of contracts
        self.stars = 0
        self.perks = {k: 0 for k in PERK_MAX}
        self.onetime_given = 0
        self.mat_value = 0.0

    # --- multipliers ---------------------------------------------------------------------------------------------
    def best_hammer(self):
        return self.best

    def hammer_power(self):
        r, lv = self.best_hammer()
        E = self.E
        return E["rarity_step"] ** r * (1 + E["level_step"] * (lv - 1))

    def dept_mult(self, k):
        per = self.E["depts"][k][0]
        return 1 + per * self.dept[k]

    def power_mult(self):
        m = self.E["strength_mult"](self.strength) * self.dept_mult("power") * self.E["rebirth_power"](self.R)
        if "workshop" in self.exts: m *= 1.15
        if "thunder" in self.P["passes"]: m *= 3
        m *= 1 + self.P["boosts"]  # share of time under a 2x boost
        return m

    def crew_mult(self):
        m = self.hammer_power() * self.power_mult() / self.E["strength_mult"](self.strength) * self.dept_mult("crew")
        return m

    def pay_mult(self):
        m = 1.0
        if "office" in self.exts: m += 0.10
        if "vip" in self.P["passes"]: m += 0.20
        m += 0.05  # rain a quarter of the time
        m *= self.dept_mult("cash") * self.E["rebirth_cash"](self.R)
        if "cash2x" in self.P["passes"]: m *= 2
        m *= 1 + self.P["boosts"]
        m *= 1 + 0.10 * self.perks["tycoon"]                       # Star Shop: Tycoon
        m *= self.E.get("pay_extra", 1.0)                           # tips, rush orders, gifts, missions
        m *= 1 + self.P.get("friends", 0) * 0.10                    # friends on the server (+10% each, max 4)
        return m

    def bp_factor(self, c):
        # Blueprints: found on (6% + 1.2% x order) of contracts, used on the best one: E[pay - work] = +0.46 of a reward
        g = self.E.get("bp_gain", 0.0)
        if not g: return 1.0
        order = ORDER.index(c["id"]) + 1
        return 1 + g * (0.06 + 0.012 * order) * (1 + 0.10 * self.perks["lucky"])

    def strength_per_hit(self):
        E = self.E
        m = E["gear"][self.gear][1] * self.dept_mult("strength") * E["rebirth_strength"](self.R)
        if "strength2x" in self.P["passes"]: m *= 2
        m *= 1 + 0.20 * self.perks["genes"]                         # Star Shop: Strong Genes
        m *= 1 + self.P["boosts"]
        return m

    def cooldown(self):
        r, _ = self.best_hammer()
        cd = COOLDOWN[r]
        if "fasttools" in self.P["passes"]: cd *= 0.8
        return cd

    def hit_rate(self):
        if "autobuild" in self.P["passes"]:
            return 1 / (self.cooldown() * 1.25 * 0.8)
        return max(1e-6, min(self.P["cps"], 1 / (0.8 * self.cooldown())) * self.P["active"])

    def max_workers(self):
        E = self.E
        n = E["max_workers"](self.level) + self.R + self.dept["crew"] // 10
        if "garage" in self.exts: n += 2
        if "bigcrew" in self.P["passes"]: n += 3
        return n

    # --- a contract with the current state --------------------------------------------------------------------------
    def unlocked(self, c):
        return (self.rep >= c["reqRep"] and self.level >= c["reqLevel"] and self.strength >= c["reqStr"] and self.R >= c["reqReb"]
                and len(self.workers) >= c["reqCrew"] and self.best_hammer()[0] + 1 >= c["reqHam"])

    def contract_time(self, c):
        """seconds to build it, and the work done by player / crew / machines, and the player's hits"""
        E = self.E
        power = self.hammer_power() * self.power_mult()
        pdps = power * E["combo_avg"] * self.hit_rate()
        cm = self.crew_mult()
        boost = min(0.40, 0.20 * self.workers.count("foreman"))
        cdps = 0.0
        for w in self.workers:
            wt = E["workers"][w]
            cdps += wt["rate"] * wt["eff"]
        cdps *= (1 + boost) * cm
        t = 0.0
        split = [0.0, 0.0, 0.0]
        for verb, w in VERBS[c["id"]].items():
            work = w * c["workMult"]
            mdps = 0.0
            for mk, lv in self.machines.items():
                if verb in MACHINE_VERBS[mk]:
                    mdps += E["machines"][mk]["rate"] * E["machine_mult"](lv) * cm
            total = pdps + cdps + mdps
            dt = work / total
            t += dt
            split[0] += pdps * dt; split[1] += cdps * dt; split[2] += mdps * dt
        hits = self.hit_rate() * t
        return t, split, hits

    def contract_income(self, c):
        t, _, _ = self.contract_time(c)
        fast = t <= c["target"]
        pay = c["reward"] * self.pay_mult() * (1 + (self.E["speed_bonus"] if fast else 0)) * self.bp_factor(c)
        return pay / (t + self.E["stage_overhead"]), t, pay

    def best_contract(self):
        best, bi = None, -1
        for c in self.E["contracts"]:
            if self.unlocked(c):
                inc, _, _ = self.contract_income(c)
                if inc > bi: best, bi = c, inc
        return best, bi

    def rent_per_sec(self):
        E = self.E
        total = 0.0
        for pid, n in self.props.items():
            cost, rent = E["props"][pid]
            m = 1
            for need, x in E["prop_milestones"]:
                if n >= need: m *= x
            total += rent * n * m
        m = self.E["rebirth_cash"](self.R) if self.E.get("prop_rent_rebirth") else 1.0
        m *= 1 + 0.25 * self.perks["lawyer"]                        # Star Shop: Property Lawyer
        return total * self.dept_mult("rent") * m / 60.0

    def income_per_sec(self):
        _, bi = self.best_contract()
        return max(0.0, bi) + self.rent_per_sec()


# ------------------------------------------------------------------------------------------------------------------
# what a player can buy (greedy on payback time)
# ------------------------------------------------------------------------------------------------------------------
def candidates(s):
    E = s.E
    out = []
    ps = E.get("price_scale", 1.0) ** s.R
    # upgrades
    cap = E["dept_cap"](s.R)
    for k, (per, base) in E["depts"].items():
        lv = s.dept[k]
        if lv < cap:
            out.append(("dept", k, base * E["dept_growth"] ** lv * ps))
    # workers
    if len(s.workers) < s.max_workers():
        for w, wt in E["workers"].items():
            if s.level >= wt["lvl"]:
                if w == "foreman" and s.workers.count("foreman") >= 2: continue
                price = wt["price"] * E["worker_price_growth"] ** len(s.workers) * ps
                out.append(("worker", w, price))
    # machines
    for mk, mt in E["machines"].items():
        if s.level >= mt["lvl"]:
            if mk not in s.machines:
                out.append(("machine", mk, mt["price"] * ps))
            elif s.machines[mk] < E["machine_max"]:
                out.append(("mup", mk, E["machine_up_cost"](mt["price"], s.machines[mk]) * ps))
    # gear
    if s.gear + 1 < len(E["gear"]):
        out.append(("gear", s.gear + 1, E["gear"][s.gear + 1][0] * ps))
    # hammer level
    r, lv = s.best_hammer()
    if lv < E["max_level"]:
        out.append(("hlevel", None, E["level_base"][r] * E["level_growth"] ** (lv - 1)))
    # extensions
    for x, price in E["extensions"].items():
        if x not in s.exts: out.append(("ext", x, price))
    # company + properties
    if not s.company and s.level >= E["company_level"]:
        out.append(("company", None, E["company_cost"]))
    if s.company:
        for pid, (cost, rent) in E["props"].items():
            if s.built.get(pid):
                n = s.props.get(pid, 0)
                if n < E.get("prop_max", 1000):
                    out.append(("prop", pid, cost * E["prop_growth"] ** n))
    return out


def apply(s, kind, key):
    E = s.E
    if kind == "dept": s.dept[key] += 1
    elif kind == "worker": s.workers.append(key)
    elif kind == "machine": s.machines[key] = 1
    elif kind == "mup": s.machines[key] += 1
    elif kind == "gear": s.gear = key
    elif kind == "hlevel":
        s.best = (s.best[0], s.best[1] + 1)
    elif kind == "ext": s.exts.add(key)
    elif kind == "company": s.company = True
    elif kind == "prop": s.props[key] = s.props.get(key, 0) + 1


def value_of(s, kind, key):
    """income gain per second of a purchase (with what it unlocks next counted a little)"""
    before = s.income_per_sec()
    t = copy.copy(s)
    t.dept = dict(s.dept); t.workers = list(s.workers); t.machines = dict(s.machines); t.exts = set(s.exts)
    t.props = dict(s.props)
    apply(t, kind, key)
    after = t.income_per_sec()
    gain = after - before
    # strength things: worth what they cut from the time to the next strength gate
    if kind in ("gear",) or (kind == "dept" and key == "strength"):
        gain = max(gain, 0.15 * before * (t.strength_per_hit() / s.strength_per_hit() - 1))
    if kind == "worker":
        gain = max(gain, 0.02 * before)
    if kind == "company":
        # worth the best property it opens (first unit)
        best = 0.0
        for pid, (cost, rent) in s.E["props"].items():
            if s.built.get(pid): best = max(best, rent / 60.0)
        gain = best * 0.8
    return gain


def buy_round(s, horizon):
    """buy the best-payback thing again and again while it pays back within `horizon` seconds"""
    bought = 0
    while bought < 200:
        best, bk = None, None
        pol = s.P.get("policy")
        skip = s.P.get("skip", ())
        if pol in ("random", "cheapest"):
            # a kid who doesn't compare paybacks: buys whatever is affordable (random) or the cheapest thing first
            opts = [(k, kk, c) for (k, kk, c) in candidates(s) if c <= s.money and k not in skip and value_of(s, k, kk) > 0]
            if not opts: break
            if pol == "random" and s.rng.random() < 0.5: break      # and doesn't spend everything at once
            k, kk, c = s.rng.choice(opts) if pol == "random" else min(opts, key=lambda o: o[2])
            s.money -= c; apply(s, k, kk); s.purchases.append((s.t, k, kk, c)); bought += 1
            continue
        for kind, key, cost in candidates(s):
            if cost > s.money: continue
            if kind in skip: continue
            gain = value_of(s, kind, key)
            if gain <= 0: continue
            pb = cost / gain
            lim = horizon * (s.E.get("prop_horizon_x", 2.25) if kind in ("prop", "company") else 1.0)
            if pb < lim and (best is None or pb / lim < best):
                best, bk = pb / lim, (kind, key, cost)
        if not bk: break
        kind, key, cost = bk
        s.money -= cost
        apply(s, kind, key)
        s.purchases.append((s.t, kind, key, cost))
        bought += 1
    return bought


# ------------------------------------------------------------------------------------------------------------------
# crates
# ------------------------------------------------------------------------------------------------------------------
def luck_of(s):
    L = 1.0
    if "luck" in s.P["passes"]: L *= 2
    L *= s.E.get("helmet_luck", lambda st: 1.0)(s)
    return L


def roll(s, crate):
    E = s.E
    odds = list(E["crates"][crate]["odds"])
    L = luck_of(s)
    w = [v * (L if (i + 1) >= E["luck_from_r"] else 1) for i, v in enumerate(odds)]
    x = s.rng.random() * sum(w)
    for i, v in enumerate(w):
        x -= v
        if x <= 0:
            return i
    return max(i for i, v in enumerate(w) if v > 0)


def hpow(E, h):
    return E["rarity_step"] ** h[0] * (1 + E["level_step"] * (h[1] - 1))


def got_hammer(s, r):
    E = s.E
    s.events["first"].setdefault(RARITY[r], s.t)
    s.got[r] = s.got.get(r, 0) + 1 if hasattr(s, "got") else 1
    if hpow(E, (r, 1)) > hpow(E, s.best):
        s.inv[s.best[0]] += 1
        s.best = (r, 1)
    else:
        s.inv[r] += 1


def open_crate(s, crate):
    if not hasattr(s, "got"): s.got = {}
    r = roll(s, crate)
    s.crates_opened = getattr(s, "crates_opened", 0) + 1
    got_hammer(s, r)
    # trade-ups: 10 spares of a rarity -> 1 of the next
    E = s.E
    for rr in range(0, min(7, E["tradeup_top"] - 1)):
        while s.inv[rr] >= E["tradeup"]:
            s.inv[rr] -= E["tradeup"]
            s.tradeups = getattr(s, "tradeups", 0) + 1
            got_hammer(s, rr + 1)


def zone_supply(s):
    best = None
    for c in s.E["contracts"]:
        if s.R >= s.E["zone_reb"][c["zone"]]:
            best = c["zone"]
    return "supply_" + (best or "town")


# ------------------------------------------------------------------------------------------------------------------
# the run
# ------------------------------------------------------------------------------------------------------------------
def do_rebirth(s):
    E = s.E
    s.reb_day = getattr(s, "reb_day", []) + [getattr(s, "day", 1)]
    if E.get("stars"):
        if E.get("stars_new"):
            # PROPOSAL: 3 + 2 x (the Rebirth's number) Stars, +1 for every doubling of the cost you earned before pressing it
            cost = E["rebirth_cost"](s.R)
            s.stars += 3 + 2 * (s.R + 1) + max(0, int(math.log2(max(1.0, s.earned_run / cost))))
        else:
            s.stars += max(1, int(math.sqrt(max(0.0, s.earned_run) / 2.5e6)))
        buy_perks(s)
    keep = []
    if E.get("stars") and s.perks["crew"]:
        order = sorted(s.workers, key=lambda w: -E["workers"][w]["rate"])
        keep = order[:s.perks["crew"]]
    s.R += 1
    s.events["rebirth"].append(s.t)
    s.money = E["start_money"] + (2500 * 3 ** s.perks["headstart"] if s.perks["headstart"] > 0 else 0)
    # PROPOSAL option: every Rebirth starts with a share of the Rebirth you just paid (a built-in head start)
    s.money += E.get("reb_headstart", 0.0) * E["rebirth_cost"](s.R - 1)
    s.earned_run = 0.0
    s.onetime_given = 0
    s.gear = 0
    s.strength = 0.0
    s.workers = keep
    s.machines = {}
    s.dept = {k: 0 for k in E["depts"]}
    s.props = {}


def buy_perks(s):
    """Star Shop: a sensible order first (cash, loyal crew, head start, strength), then the cheapest level"""
    i = 0
    while True:
        bought = False
        for k in PERK_ORDER + sorted(PERK_MAX, key=lambda k: s.perks[k]):
            lv = s.perks[k]
            if lv < PERK_MAX[k] and s.stars >= lv + 1:
                s.stars -= lv + 1
                s.perks[k] += 1
                bought = True
                break
        if not bought: break


def gate_contract(s):
    """the zone's last contract that must be built before this Rebirth"""
    g = None
    for c in s.E["contracts"]:
        if c["reqReb"] == s.R: g = c
    return g


def simulate(E, P, hours=12.0, seed=1, max_rebirths=8, verbose=False, record=False, hold_at=None):
    s = State(E, P, seed)
    s.contract_log = []
    s.got = {}
    open_crate(s, "supply_town")
    s.money -= 150
    s.gear = 1; s.money -= E["gear"][1][0]
    s.machines["excavator"] = 1; s.money -= E["machines"]["excavator"]["price"]
    s.workers.append("laborer"); s.money -= E["workers"]["laborer"]["price"]
    s.money = max(s.money, 0)
    end = hours * 3600
    gems_per_sec_daily = E["gems_day"] / 3600.0   # the daily rewards, spread over an hour a day
    sess = P.get("session_min")
    next_end = sess * 60 if sess else None
    s.day = 1
    s.offline_earned = 0.0
    s.reb_day = []
    while s.t < end and s.R < max_rebirths:
        # DAILY SESSIONS: play `session_min` a day, the rest of the day offline (rent at offline_share, up to the cap)
        if sess and s.t >= next_end:
            gap = 24 * 3600 - sess * 60
            share = 1.0 if "nightshift" in P["passes"] else E.get("offline_share", 1.0)
            cap = (12 if "nightshift" in P["passes"] else E.get("offline_cap_h", 1e9)) * 3600
            off = s.rent_per_sec() * share * min(gap, cap)
            s.money += off
            if E.get("offline_counts", True): s.earned_run += off
            s.offline_earned += off
            s.day += 1
            next_end += sess * 60
        c, inc = s.best_contract()
        if c is None:
            break
        # a strength gate in the way of a much better contract: train for it
        nxt = None
        for cc in E["contracts"]:
            if not s.unlocked(cc) and s.R >= cc["reqReb"] and s.rep >= cc["reqRep"] and s.level >= cc["reqLevel"] \
                    and len(s.workers) >= cc["reqCrew"] and s.best_hammer()[0] + 1 >= cc["reqHam"] and s.strength < cc["reqStr"]:
                nxt = cc
                break
        if nxt and P["train"]:
            st = 0
            for req, mult in E["stations"]:
                if s.strength >= req: st = mult
            rep_rate = (1 / E["train_cd"]) * max(0.02, P["active"])
            need = nxt["reqStr"] - s.strength
            ttrain = need / (st * s.strength_per_hit() * rep_rate)
            # what building gives meanwhile
            t_c, _, hits = s.contract_time(c)
            build_str_rate = hits * s.strength_per_hit() / (t_c + E["stage_overhead"])
            tbuild = need / max(1e-9, build_str_rate)
            if ttrain < 0.33 * tbuild and ttrain < E.get("train_max_s", 240):
                step = min(ttrain, 120.0)
                s.strength += st * s.strength_per_hit() * rep_rate * step
                s.t += step
                s.train_time += step
                s.clicks += rep_rate * step
                continue
        # build the contract
        t, split, hits = s.contract_time(c)
        fast = t <= c["target"]
        pay = c["reward"] * s.pay_mult() * (1 + (E["speed_bonus"] if fast else 0)) * s.bp_factor(c)
        dt = t + E["stage_overhead"]
        rent = s.rent_per_sec() * dt
        s.t += dt
        s.money += pay + rent
        s.earned_run += pay + rent
        s.total_earned = getattr(s, "total_earned", 0.0) + pay + rent
        s.rent_earned += rent
        s.run_rent = getattr(s, "run_rent", {}); s.run_rent[s.R] = s.run_rent.get(s.R, 0.0) + rent
        s.run_pay = getattr(s, "run_pay", {}); s.run_pay[s.R] = s.run_pay.get(s.R, 0.0) + pay
        s.strength += hits * s.strength_per_hit()
        s.clicks += hits
        s.work_split = [a + b for a, b in zip(s.work_split, split)]
        s.contracts_done += 1
        # FIDELITY_V2: one-time rewards (Empire Road + achievements) worth onetime_frac of each of the first 5 Rebirths,
        # given in 10 parts as the run goes; materials found (3 finds per contract or 1 per 30 player hits)
        fr = E.get("onetime_frac", 0.0)
        if fr and s.R < 5:
            cost = E["rebirth_cost"](s.R)
            while s.onetime_given < 10 and s.earned_run >= cost * (s.onetime_given + 1) / 10 * 0.9:
                s.onetime_given += 1
                s.money += fr * cost / 10
                s.earned_run += fr * cost / 10
        order = ORDER.index(c["id"]) + 1
        finds = max(3.0, hits / 30.0) * (1 + 0.10 * s.perks["lucky"])
        amt = 1 + order // 4
        dt_ = DROPS[order - 1]
        for m, w in dt_.items():
            s.mats[m] += finds * amt * w / 100.0
            s.mat_value += finds * amt * w / 100.0 * MAT_SELL[m]
        if E.get("sell_mats"):
            v = sum(finds * amt * w / 100.0 * MAT_SELL[m] for m, w in dt_.items()) * E["sell_mats"]
            s.money += v
            s.earned_run += v
        s.contract_log.append((s.t, c["id"], t, s.R, split[0] / max(1e-9, sum(split)), hits))
        s.built[c["id"]] = s.built.get(c["id"], 0) + 1
        s.events["first"].setdefault("built_" + c["id"], s.t)
        s.events.setdefault("run_first", {}).setdefault((s.R, c["id"]), (s.t, t))
        s.xp += c["xp"]
        while s.xp >= E["xp_for_level"](s.level):
            s.xp -= E["xp_for_level"](s.level)
            s.level += 1
        s.rep += c["rep"]
        g_now = E["gems_contract"](ORDER.index(c["id"]) + 1, fast) + hits * E["gem_hit"] + gems_per_sec_daily * dt
        if "gems2x" in P["passes"]: g_now *= 2
        s.gems += g_now
        s.gems_total = getattr(s, "gems_total", 0.0) + g_now
        # free crates
        s.crate_progress += 1
        if s.crate_progress >= E["free_crate_every"]:
            s.crate_progress = 0
            open_crate(s, zone_supply(s))
        elif s.rng.random() < E["builder_drop"] * (2 if "luck" in P["passes"] else 1):
            open_crate(s, "builder")
        # buying: cash crates with a share of the pay, gem crates when affordable, then the best paybacks
        sp = zone_supply(s)
        bestc = max((cc for cc in E["contracts"] if s.unlocked(cc)), key=lambda cc: cc["reward"])
        if "supply_price_min" in E:
            # minutes of what you earn now (the IncomePerMin the game already shows)
            price = max(150.0, (pay / dt) * 60 * E["supply_price_min"])
        else:
            price = E["supply_price"](bestc["reward"])
        budget = pay * P["crate_share"]
        s.crate_budget = min(getattr(s, "crate_budget", 0.0) + budget, price * 10)
        s.money -= budget
        n = 0
        open_t = 0.6 if ("quickopen" in P["passes"] or "autoopen" in P["passes"]) else 4.5
        while s.crate_budget >= price and n < E.get("crates_per_cycle", 4):
            s.crate_budget -= price
            open_crate(s, sp)
            s.t += open_t
            n += 1
        need_ham = any(s.R >= cc["reqReb"] and s.best_hammer()[0] + 1 < cc["reqHam"] for cc in E["contracts"]
                       if cc["reqReb"] <= s.R)
        if need_ham and s.money > price * 3:
            s.money -= price
            open_crate(s, sp)
        # the game's IncomePerMin (Config.IncomePerMin): best unlocked contract, its target time + 20 s
        ipm = bestc["reward"] * s.pay_mult() * 1.1 / ((bestc["target"] + 20) / 60.0)
        s.ipm = ipm
        if P.get("gem_policy") == "cashsafe":
            # Gem Shop Cash Safe: 200 Gems -> 60 minutes of IncomePerMin (counts toward the Rebirth)
            while s.gems >= 200:
                s.gems -= 200
                v = 60 * ipm * E.get("cash_pack_mult", 1.0)
                s.money += v; s.earned_run += v
                s.cash_from_packs = getattr(s, "cash_from_packs", 0.0) + v
        elif s.gems >= E["crates"]["golden"]["gems"]:
            s.gems -= E["crates"]["golden"]["gems"]
            open_crate(s, "golden")
        # Robux cash packs (Contractor's Bonus 99 R$ = 40 min of IncomePerMin), packs_h per hour of play
        s.robux_pack = getattr(s, "robux_pack", 0.0) + P.get("packs_h", 0) * dt / 3600
        while s.robux_pack >= 1:
            s.robux_pack -= 1
            v = 40 * ipm * E.get("cash_pack_mult", 1.0)
            s.money += v
            if E.get("packs_count", True): s.earned_run += v
            s.cash_from_packs = getattr(s, "cash_from_packs", 0.0) + v
        # Robux Golden Crates (payers / whales), spread over the play time
        s.robux_golden = getattr(s, "robux_golden", 0.0) + P.get("robux_golden_h", 0) * dt / 3600
        while s.robux_golden >= 1:
            s.robux_golden -= 1
            open_crate(s, "golden")
            s.robux_spent = getattr(s, "robux_spent", 0) + 149
        buy_round(s, horizon=E.get("horizon", 1200))
        # rebirth
        g = gate_contract(s)
        if record:
            s.run_log = getattr(s, "run_log", [])
            s.run_log.append((s.t, s.R, s.earned_run, bool(g is None or s.built.get(g["id"])), s.strength))
        if hold_at is not None and s.R >= hold_at:
            continue
        if s.earned_run >= E["rebirth_cost"](s.R) and (not E["rebirth_gate_last_contract"] or g is None or s.built.get(g["id"])):
            do_rebirth(s)
    return s


def runs_table(s):
    """per run: minutes, contracts, average build time, clicks per minute, the player's share of the work, rent share,
    purchases per minute, crates"""
    reb = [0.0] + s.events["rebirth"]
    out = []
    for n in range(len(reb)):
        t0 = reb[n]; t1 = reb[n + 1] if n + 1 < len(reb) else s.t
        log = [x for x in s.contract_log if t0 <= x[0] < t1]
        mins = (t1 - t0) / 60
        if not log or mins <= 0: continue
        builds = [x[2] for x in log]
        clicks = sum(x[5] for x in log)
        share = sum(x[4] * x[2] for x in log) / max(1e-9, sum(builds))
        buys = sum(1 for (t, k, key, c) in s.purchases if t0 <= t < t1)
        rent = getattr(s, "run_rent", {}).get(n, 0.0); pay = getattr(s, "run_pay", {}).get(n, 0.0)
        afk = 1 / max(0.05, 1 - share)
        out.append(dict(run=n, minutes=round(mins, 1), contracts=len(log), avg_build=round(sum(builds) / len(builds), 1), afk_x=round(afk, 2),
                        clicks_min=round(clicks / mins, 1), player_share=round(share, 2), rent_share=round(rent / max(1, rent + pay), 2),
                        buys_min=round(buys / mins, 2)))
    return out


def report(s, label=""):
    reb = s.events["rebirth"]
    mins = [round(x / 60, 1) for x in reb]
    ws = sum(s.work_split) or 1
    return dict(label=label, rebirth_minutes=mins, contracts=s.contracts_done, clicks=int(s.clicks), cps=round(s.clicks / max(1, s.t), 2), level=s.level, R=s.R,
                split=[round(x / ws, 2) for x in s.work_split], purchases=len(s.purchases), hours=round(s.t / 3600, 2),
                rent_share=round(s.rent_earned / max(1, s.total_earned), 3), crates=getattr(s, "crates_opened", 0),
                tradeups=getattr(s, "tradeups", 0), got={RARITY[k]: v for k, v in sorted(getattr(s, "got", {}).items())},
                gems_h=round(getattr(s, "gems_total", 0.0) / max(1e-9, s.t / 3600)),
                firsts={k: round(v / 60, 1) for k, v in s.events["first"].items() if not k.startswith("built_")},
                built={k: round(v / 60, 1) for k, v in s.events["first"].items() if k.startswith("built_")})


if __name__ == "__main__":
    E = current()
    for name in ("active", "casual", "payer", "whale"):
        s = simulate(E, PLAYERS[name], hours=20)
        print(name, report(s))
