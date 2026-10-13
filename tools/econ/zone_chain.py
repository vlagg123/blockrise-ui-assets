"""ZONE_CHAIN (owner, 2026-10-13): instead of building a zone's top building ~20-30 times for the Rebirth's Level,
5 new buildings per zone, each built once; after the last one you have exactly the Level the Rebirth needs.
XP grows exponentially along the chain, so building in order is always the best XP per second (no shortcut by
farming small buildings). Power / Strength stay as they are (Training Yard). First pass; the times are tuned in
Studio with the live formulas."""
import math

def xp_total(L):  # XP to reach Level L (Config.XPForLevel: 120 * l^1.45 per level)
    return sum(120 * l ** 1.45 for l in range(1, L))

def sig(x, d=2):
    e = 10 ** (math.floor(math.log10(x)) - d + 1)
    return round(x / e) * e

ZONES = [
    # zone, Level from -> to, existing buildings (name, xp, targetTime s), new names, extra XP already earned (tutorial)
    ("Town", 1, 12, [("Repair Fence", 25, 33), ("Garden Shed", 55, 48), ("Brick Garage", 120, 63), ("Small Family House", 300, 78), ("Corner Shop", 620, 93)],
     ["Bakery", "Car Wash", "Clinic", "Fire Station", "Town Hall"], 25),
    ("Suburbs", 12, 35, [("Two-Story Villa", 1300, 108), ("Logistics Warehouse", 2100, 120), ("Apartment Block", 3600, 132), ("Luxury Villa", 6000, 144), ("Distribution Center", 9000, 158)],
     ["Shopping Plaza", "Sports Arena", "Hospital", "Water Park", "Suburb Mall"], 0),
    ("Downtown (R2)", 35, 55, [("Glass Office Tower", 15000, 173), ("Grand Hotel", 24000, 188)],
     ["Bank Tower", "Concert Hall", "Museum", "Twin Towers", "City Stadium"], 0),
]

for zone, l0, l1, have, names, extra in ZONES:
    need = xp_total(l1) - xp_total(l0)
    base = sum(x for _, x, _ in have) + extra
    rest = need - base
    last_xp, last_t = have[-1][1], have[-1][2]
    # geometric ladder: x1 = last * r, ..., x5 = last * r^5, sum = rest  -> solve r
    lo, hi = 1.01, 5.0
    for _ in range(100):
        r = (lo + hi) / 2
        s = sum(last_xp * r ** k for k in range(1, 6))
        if s < rest: lo = r
        else: hi = r
    xs = [last_xp * r ** k for k in range(1, 6)]
    xs = [sig(x) for x in xs]
    xs[-1] += rest - sum(xs)            # the last one makes the sum exact
    ts = [last_t + 12 * k for k in range(1, 6)]   # first-build target times keep growing 12 s a building
    print(f"== {zone}: Level {l0} -> {l1} needs {need:,.0f} XP; the old buildings once give {base:,.0f}; the 5 new give {rest:,.0f} (step x{r:.2f})")
    print(f"   before: the top building ({have[-1][0]}, {last_xp} XP) ~{rest / last_xp:.0f} more times")
    rows = [(n, x, t, False) for n, x, t in have] + [(n, x, t, True) for n, x, t in zip(names, xs, ts)]
    prev = 0
    for n, x, t, new in rows:
        rate = x / t
        ok = "ok" if rate > prev else "!! not increasing"
        prev = rate
        print(f"   {'NEW ' if new else '    '}{n:22} XP {x:>8,.0f}   first build ~{t:>3} s   XP/s {rate:7.1f}  {ok}")
    total = base + sum(xs)
    print(f"   sum once each = {total:,.0f} (needed {need:,.0f})")
