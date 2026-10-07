"""Economy v5, the Gem economy on its own: where Gems come from per hour of play (contracts, hits, the daily rewards),
how long each Gem item takes a free player, and whether Gem prices and Robux prices agree (no item is much cheaper one
way than the other). Usage: python3 v5_gems.py"""
import json, statistics as st
import sim, v5

# Robux -> Gems packs (Config.Store, live ids): R$ per Gem
PACKS = {"gems100": (49, 100), "gems300": (129, 300), "gems750": (299, 750), "gems1700": (599, 1700), "gems4500": (1399, 4500), "gems12000": (3299, 12000)}
# Gem items and, where one exists, their direct Robux price
ITEMS = [("Builder's Crate", 200, 79), ("Golden Crate", 750, 249), ("Pirate Cove / Jungle Temple Crate", 600, 149),
         ("Hammer of the Day: Epic", 3000, None), ("Hammer of the Day: Legendary", 12000, None), ("Hammer of the Day: Mythic", 60000, None),
         ("Builder's Helmet IV (+ cash)", 2500, None), ("Builder's Helmet V (+ cash)", 10000, None), ("Cash Safe (60 min of income)", 200, None)]

if __name__ == "__main__":
    d = json.load(open("final_econ_v5.json"))
    E = v5.build(d["reb_costs"])
    print("== Gems per hour of play (v5, 20 h, 3 seeds)")
    rate = {}
    for name in ("casual", "active", "payer"):
        c_g, h_g, hours = [], [], []
        for seed in (1, 2, 3):
            s = sim.simulate(E, v5.player(name), hours=20, seed=seed, max_rebirths=8)
            byid = {c["id"]: c for c in E["contracts"]}
            cg = sum(E["gems_contract"](sim.ORDER.index(cid) + 1, dur <= byid[cid]["target"]) for (t, cid, dur, R, sh, hits) in s.contract_log)
            hg = sum(hits * E["gem_hit"] for (t, cid, dur, R, sh, hits) in s.contract_log)
            h = s.t / 3600
            c_g.append(cg / h); h_g.append(hg / h); hours.append(h)
        daily = E["gems_day"] / v5.DAY_H[name]
        tot = st.mean(c_g) + st.mean(h_g) + daily
        rate[name] = tot
        print("  %-6s contracts %3.0f + hits %3.0f + daily rewards %3.0f (%d a day over %.2g h) = %3.0f Gems/h" % (
            name, st.mean(c_g), st.mean(h_g), daily, E["gems_day"], v5.DAY_H[name], tot))
    print("== hours of play for each Gem item (free player)")
    for nm, g, rbx in ITEMS:
        print("  %-36s %6d Gems: casual %5.1f h, active %5.1f h" % (nm, g, g / rate["casual"], g / rate["active"]))
    print("== Gems vs Robux (R$ per Gem by pack)")
    for k, (r, g) in PACKS.items():
        print("  %-9s %4d R$ / %5d Gems = %.3f R$ per Gem" % (k, r, g, r / g))
    mid = PACKS["gems1700"][0] / PACKS["gems1700"][1]
    for nm, g, rbx in ITEMS:
        if rbx:
            print("  %-36s %d Gems = %.0f R$ through the 1,700 pack; direct %d R$ (direct / via Gems = %.2f)" % (nm, g, g * mid, rbx, rbx / (g * mid)))
