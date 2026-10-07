"""Check 7: the hammer market over 30 / 90 days per 1,000 daily players, with what the first estimate left out:
- luck as players will really have it (helmet tier, passes, potions, Lucky Hours; additive), Secret Hunter x3 on Secret+Divine
- trade-ups 10 -> 1 up to Mythic (everyone trades up their spares, keeping one of each)
Each player type opens crates per hour (Supply / Builder's / Golden) as in crates.py."""
import random, sys
from crates import PROPOSAL, RAR

# luck = 1 + sum of the bonuses (additive), on Legendary and rarer; hunter = Secret Hunter (x on Secret and Divine)
TYPES = {
    #               share  h/day  supply b'ers golden luck   hunter
    "casual free": (0.70, 0.75, 6.0, 0.7, 0.12, 1.25, 1.0),   # helmet I-II, a Lucky Hour now and then
    "active free": (0.25, 2.0, 10.0, 1.1, 0.25, 1.45, 1.0),   # helmet II-III
    "payer":       (0.04, 2.0, 12.0, 1.1, 0.8, 2.9, 1.0),     # Lucky Builder, helmet III, potions 30% of the time
    "whale":       (0.01, 3.0, 16.0, 2.2, 4.5, 6.6, 3.0),     # Lucky + Ultra Lucky, helmet IV-V, potions, Secret Hunter
}

def odds(table, luck, hunter):
    w = [v * (luck if i >= 4 else 1) * (hunter if i >= 6 else 1) for i, v in enumerate(table)]
    t = sum(w)
    return [x / t for x in w]

def month(days=30, dau=1000, tradeup_top=5, table=PROPOSAL, luck_on=True, phase="Downtown Supply"):
    made = [0.0] * 8          # created by crates
    tu = [0.0] * 8            # created by trade-ups
    for name, (share, h, sup, bld, gold, luck, hunter) in TYPES.items():
        L = luck if luck_on else 1.0; H = hunter if luck_on else 1.0
        n = dau * share
        per_day = [0.0] * 8
        for crate, k in ((phase, sup), ("Builder's", bld), ("Golden", gold)):
            o = odds(table[crate], L, H)
            for i in range(8): per_day[i] += o[i] * k * h
        # each player of this type over `days`: crates, then trade-ups of the spares (keep one of each)
        have = [x * days for x in per_day]
        for i in range(8): made[i] += have[i] * n
        inv = list(have)
        for i in range(0, tradeup_top):
            spare = max(0.0, inv[i] - 1)
            k = int(spare // 10)
            inv[i] -= 10 * k; inv[i + 1] += k
            tu[i + 1] += k * n
    return made, tu

if __name__ == "__main__":
    for luck_on in (False, True):
        for days in (30, 90):
            made, tu = month(days, luck_on=luck_on)
            print(f"{'real luck' if luck_on else 'no luck  '} {days:2d} days:", "  ".join(
                f"{RAR[i][:4]} {made[i]:,.0f}+{tu[i]:,.0f}tu" for i in range(4, 8)))
    # who makes the Divines / Secrets
    for name in TYPES:
        sh = dict(TYPES)
        only = {name: TYPES[name]}
        import market as M
        M.TYPES = only
        made, tu = M.month(30)
        print(f"   {name:12s} makes per month: Secret {made[6]:.1f}  Divine {made[7]:.2f}")
        M.TYPES = sh
