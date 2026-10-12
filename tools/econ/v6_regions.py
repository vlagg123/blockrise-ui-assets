"""Economy V6 (regions) - the derived numbers of roblox/ECONOMY_V6_REGIONS.md.

Run: python3 tools/econ/v6_regions.py
Everything here is arithmetic from the design rules (no game simulation): reward / XP ladders, Zone Crate prices,
crate odds checks, hammer power by region, pacing targets in days. The tuning of work and Strength gates is done in
Studio afterwards (see the doc, section 9).
"""
import math

def sig2(x):
    """round to 2 significant digits (prices and rewards read well)"""
    if x <= 0:
        return 0
    e = 10 ** (math.floor(math.log10(x)) - 1)
    return round(x / e) * e

SUF = ["", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp"]
def short(x):
    if x < 1000:
        return f"{x:g}"
    i = min(len(SUF) - 1, int(math.log10(x) // 3))
    v = x / 10 ** (3 * i)
    s = f"{v:.1f}".rstrip("0").rstrip(".") if v < 100 else f"{v:.0f}"
    return s + SUF[i]

# --- zones: (region, zone, rebirth that opens it, 5 buildings) -------------------------------------------------------
ZONES = [
    ("City", "Town", 0, ["Repair Fence", "Garden Shed", "Brick Garage", "Small Family House", "Corner Shop"]),
    ("City", "Suburbs", 1, ["Two-Story Villa", "Logistics Warehouse", "Apartment Block", "Luxury Villa", "Distribution Center"]),
    ("City", "Downtown", 2, ["Glass Office Tower", "Grand Hotel", "Skyscraper", "Corporate HQ", "Landmark Spire"]),
    ("Desert", "Dunes Outpost", 3, ["Desert Well", "Adobe House", "Gas Station", "Oil Derrick", "Desert Motel"]),
    ("Desert", "Oasis", 4, ["Oasis Bazaar", "Palm Resort", "Solar Farm", "Desert Mall", "Great Pyramid"]),
    ("Desert", "Oil Fields", 5, ["Oil Pipeline", "Oil Refinery", "Tanker Port", "Golden Tower", "Oil Palace"]),
    ("Moon", "Moon Base", 6, ["Landing Pad", "Moon Habitat", "Solar Array", "Rover Garage", "Moon Dome"]),
    ("Moon", "Crater City", 7, ["Crater Mine", "Oxygen Plant", "Lunar Lab", "Moon Hotel", "Colony Tower"]),
    ("Moon", "Spaceport", 8, ["Launch Tower", "Rocket Hangar", "Mission Control", "Space Elevator", "Mega Rocket"]),
]
# today's City rewards / XP (Config.Contracts, live): kept as they are
CITY_REWARD = [60, 190, 520, 1600, 4200, 14000, 32000, 85000, 210000, 520000, 1.6e6, 4.5e6, 14e6, 45e6, 150e6]
CITY_XP = [25, 55, 120, 300, 620, 1300, 2100, 3600, 6000, 9000, 15000, 24000, 38000, 60000, 100000]
REWARD_STEP = 2.8   # the City's average step between buildings (60 -> 150M over 14 steps = x2.85)
XP_STEP = 1.6

rewards, xps = list(CITY_REWARD), list(CITY_XP)
while len(rewards) < 45:
    rewards.append(sig2(rewards[-1] * REWARD_STEP))
    xps.append(sig2(xps[-1] * XP_STEP))

city_step = (CITY_REWARD[-1] / CITY_REWARD[0]) ** (1 / 14)

def bonus(rebirths):
    """the Rebirth cash bonus today: +150% a Rebirth, added"""
    return 1 + 1.5 * rebirths

REGION_FACTOR = {"City": 1, "Desert": 16, "Moon": 256}   # x16 a region = 4 rarity steps
RARITIES = ["Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "Secret", "Divine"]

# zone crate odds by the zone's place in its region (1st / 2nd / 3rd), in %
ODDS = {
    1: [62, 28, 8.89, 1, 0.1, 0.01, 0, 0],
    2: [30, 38, 22, 8, 1.8, 0.19, 0.01, 0],
    3: [0, 30, 40, 24, 5.4, 0.555, 0.04, 0.005],
}
COLOSSAL = {"zone": 1 / 100000, "golden": 1 / 25000, "exclusive": 1 / 2500}
LEVELS = {1: 12, 2: 35, 3: 55, 4: 75, 5: 100, 6: 125, 7: 145, 8: 165}

# pacing targets: hours of play (active free player) to ENTER each zone, and to build the last zone's top building
ENTER_H = [0, 0.5, 2, 6, 10, 15, 21, 28, 36]
END_H = 46

def main():
    print("== reward step in the City today: x%.2f a building" % city_step)
    print()
    print("== zones, buildings, rewards (base, before the Rebirth bonus), Zone Crate price")
    rows = []
    for zi, (region, zone, rb, names) in enumerate(ZONES):
        b = bonus(rb)
        first = rewards[zi * 5]
        price = 150 if zi == 0 else sig2(2.5 * first * b)
        top = rewards[zi * 5 + 4]
        rows.append((region, zone, rb, b, first, top, price))
        print(f"{region:6} {zone:13} R{rb}  cash x{b:<4g} level {LEVELS.get(rb, '-')!s:>4}  crate ${short(price):>6}")
        for k in range(5):
            i = zi * 5 + k
            print(f"      {k+1}. {names[k]:22} reward ${short(rewards[i]):>6}  (x bonus = ${short(rewards[i]*b):>6})  XP {short(xps[i]):>5}")
        # the crate against income: a build of the first / the top building pays reward * bonus
        print(f"      crate = {price/(first*b):.1f} first builds at entry, {price/(top*b)*100:.1f}% of one top build at the end")
    print()
    print("== zone crate odds (sum must be 100) and how many crates for a first ...")
    for k, o in ODDS.items():
        s = sum(o)
        assert abs(s - 100) < 1e-9, (k, s)
        p_epic = sum(o[3:]) / 100
        p_leg = sum(o[4:]) / 100
        print(f"  zone {k} of a region: {o}  sum {s:g}  -> Epic+ 1 in {1/p_epic:.0f}, Legendary+ 1 in {1/p_leg:.0f}")
    print()
    print("== hammer power (rarity x2 a step, region x16)")
    for region, f in REGION_FACTOR.items():
        print(f"  {region:6}: " + "  ".join(f"{r[:3]} {short(f * 2 ** i)}" for i, r in enumerate(RARITIES)))
    print("  check: a Desert Common = a City Legendary:", REGION_FACTOR["Desert"] * 1 == 2 ** 4)
    print()
    print("== Colossal: expected number per day at 1,000 daily players opening 200 zone crates + 1 Golden each")
    per_day = 1000 * (200 * COLOSSAL["zone"] + 1 * COLOSSAL["golden"])
    print(f"  {per_day:.2f} a day in the whole game (luck x3 at most -> up to {3*per_day:.1f})")
    print()
    print("== pacing targets: the day each zone opens")
    profiles = {"casual 45 min/day": 0.75, "active 2 h/day": 2, "heavy 5 h/day": 5}
    names = [z[1] for z in ZONES] + ["END (Mega Rocket)"]
    hours = ENTER_H + [END_H]
    head = f"  {'zone':18}{'play h':>8}" + "".join(f"{p:>20}" for p in profiles)
    print(head)
    for n, h in zip(names, hours):
        print(f"  {n:18}{h:>8g}" + "".join(f"{('day ' + str(math.floor(h / d) + 1)):>20}" for d in profiles.values()))
    lens = [b - a for a, b in zip(hours, hours[1:])]
    print("  zone lengths (h):", lens)

if __name__ == "__main__":
    main()
