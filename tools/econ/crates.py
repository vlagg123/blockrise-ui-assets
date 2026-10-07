"""Crate odds as a market: how long until a player's first Legendary / Mythic / Secret / Divine, and how many of each
exist after a day / a month (per 1,000 daily players). Odds in % for Common..Divine; luck multiplies Legendary+."""
import math

RAR = ["Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "Secret", "Divine"]

CURRENT = {
    "Town Supply": [62, 28, 9, 1, 0, 0, 0, 0],
    "Suburbs Supply": [30, 38, 22, 8, 2, 0, 0, 0],
    "Downtown Supply": [0, 30, 40, 24, 6, 0, 0, 0],
    "Builder's": [0, 45, 35, 15, 4.5, 0.5, 0, 0],
    "Golden": [0, 0, 40, 35, 18, 6, 0.9, 0.1],
}
PROPOSAL = {
    "Town Supply": [75, 20, 4, 1, 0, 0, 0, 0],
    "Suburbs Supply": [52, 33, 12, 2.6, 0.4, 0, 0, 0],
    "Downtown Supply": [0, 55, 33, 10.8, 1.15, 0.05, 0, 0],
    "Builder's": [0, 52, 36, 10, 1.85, 0.15, 0, 0],
    "Golden": [0, 0, 55.996, 33, 9.4, 1.3, 0.3, 0.004],
}


def adjust(odds, luck, from_r=4):
    w = [v * (luck if i >= from_r else 1) for i, v in enumerate(odds)]
    t = sum(w)
    return [x / t for x in w]


def one_in(p):
    if p <= 0: return "-"
    x = 1 / p
    if x < 1.05: return "1 in 1"
    if x < 10: return f"1 in {x:.1f}"
    return f"1 in {round(x):,}"


# crates opened per hour by a player of each kind in each phase (from the simulator: contracts per hour, the Supply Crate
# every 6 contracts, Builder's 3%, cash crates ~10% of income at 1.5 min of income each, Gems ~200/h for Golden)
PLAYERS = {
    "casual free": dict(hours_day=0.75, town=(5, 0.6, 0.1), suburbs=(6, 0.7, 0.12), downtown=(7, 0.8, 0.15), luck=1.0),
    "active free": dict(hours_day=2.0, town=(9, 1.0, 0.15), suburbs=(10, 1.1, 0.2), downtown=(11, 1.1, 0.27), luck=1.25),
    "payer": dict(hours_day=2.0, town=(10, 1.0, 0.6), suburbs=(12, 1.1, 0.8), downtown=(13, 1.2, 1.0), luck=2.5),
    "whale": dict(hours_day=3.0, town=(14, 2.0, 3.0), suburbs=(16, 2.2, 4.0), downtown=(18, 2.4, 5.0), luck=6.0),
}


def rates(table, phase, P):
    supply, builder, golden = P[phase]
    name = {"town": "Town Supply", "suburbs": "Suburbs Supply", "downtown": "Downtown Supply"}[phase]
    r = [0.0] * 8
    for crate, n in ((name, supply), ("Builder's", builder), ("Golden", golden)):
        o = adjust(table[crate], P["luck"])
        for i in range(8): r[i] += n * o[i]
    return r


def time_to_first(table, P, tradeup=True, tradeup_top=5):
    """hours of play until the first of each rarity (phases: town 0.3h, suburbs 0.6h, downtown after)"""
    phases = [("town", 0.3), ("suburbs", 0.6), ("downtown", 1e9)]
    first = [None] * 8
    have = [0.0] * 8
    t, dt = 0.0, 0.05
    left = phases[0][1]; pi = 0
    while t < 3000 and any(f is None for f in first):
        ph = phases[pi][0]
        r = rates(table, ph, P)
        for i in range(8):
            have[i] += r[i] * dt
        if tradeup:
            for i in range(0, tradeup_top):
                while have[i] >= 10:
                    have[i] -= 10; have[i + 1] += 1
        for i in range(8):
            if first[i] is None and have[i] >= 1: first[i] = t
        t += dt
        left -= dt
        if left <= 0 and pi < 2:
            pi += 1; left = phases[pi][1]
    return first


def exists(table, days=30, dau=1000):
    """how many of each rarity exist after `days` (per 1,000 daily players: 70% casual, 25% active, 4% payers, 1% whales),
    everyone in Downtown (the long phase)"""
    mix = {"casual free": 0.70, "active free": 0.25, "payer": 0.04, "whale": 0.01}
    tot = [0.0] * 8
    for name, share in mix.items():
        P = PLAYERS[name]
        r = rates(table, "downtown", P)
        for i in range(8): tot[i] += r[i] * P["hours_day"] * dau * share * days
    return tot


if __name__ == "__main__":
    for label, table in (("CURRENT", CURRENT), ("PROPOSAL", PROPOSAL)):
        print("=" * 30, label)
        for crate, odds in table.items():
            p = adjust(odds, 1.0)
            print(f"  {crate:16s}", "  ".join(f"{RAR[i][:4]} {one_in(p[i])}" for i in range(8) if p[i] > 0))
        for name, P in PLAYERS.items():
            f = time_to_first(table, P, tradeup=True, tradeup_top=(7 if label == "CURRENT" else 5))
            print(f"  {name:12s} hours to first:", "  ".join(f"{RAR[i][:4]} {('%.1f' % f[i]) if f[i] is not None else '>3000'}" for i in range(3, 8)))
        e1 = exists(table, 1); e30 = exists(table, 30)
        print("  exist per 1,000 DAU after 1 day:", "  ".join(f"{RAR[i][:4]} {e1[i]:.1f}" for i in range(4, 8)))
        print("  exist per 1,000 DAU after 30 days:", "  ".join(f"{RAR[i][:4]} {e30[i]:.0f}" for i in range(4, 8)))
