"""Economy v5, the hammer market: hammers that come into the game per day per 1,000 daily players, by rarity and by
source, today (v4) and with v5 (no free drops; Road + mission crates). Rates per hour of play come from the simulator
(first `hours` of play of each player type), the mix of players is the one of check 7 (market.py):
casual 70% x 0.75 h/day, active 25% x 2 h, payer 4% x 2 h, whale 1% x 3 h. Payers / whales also buy Golden Crates with
Robux (0.5 / 4 an hour, the same in v4 and v5).
Usage: python3 v5_market.py"""
import json, statistics as st
import sim, v5

RAR = ["Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "Secret", "Divine"]
MIX = {"casual": 0.70, "active": 0.25, "payer": 0.04, "whale": 0.01}
ROBUX_GOLDEN_H = {"payer": 0.5, "whale": 4.0}
FREE = ("free_play", "road", "mission", "tutorial")


def rates(E, name, hours, seeds=range(1, 6)):
    """per hour of play: hammers by (source, rarity), crates by (source, crate), Gems"""
    got, crates, gems = {}, {}, []
    for seed in seeds:
        p = v5.player(name, robux_golden_h=ROBUX_GOLDEN_H.get(name, 0))
        s = sim.simulate(E, p, hours=hours, seed=seed, max_rebirths=12)
        h = s.t / 3600
        for k, v in getattr(s, "got_src", {}).items():
            got[k] = got.get(k, 0) + v / h / len(seeds)
        for k, v in getattr(s, "crate_src", {}).items():
            crates[k] = crates.get(k, 0) + v / h / len(seeds)
        gems.append(getattr(s, "gems_total", 0.0) / h)
    return got, crates, st.mean(gems)


def per_day(E, hours):
    """per day per 1,000 daily players: hammers by rarity (all / free sources), crates by kind"""
    allr, freer = [0.0] * 8, [0.0] * 8
    crates = {}
    detail = {}
    for name, share in MIX.items():
        got, cr, g = rates(E, name, hours)
        n = 1000 * share * v5.DAY_H[name]
        for (src, r), v in got.items():
            allr[r] += v * n
            if src in FREE:
                freer[r] += v * n
        for k, v in cr.items():
            crates[k] = crates.get(k, 0) + v * n
        detail[name] = (got, cr, g)
    return allr, freer, crates, detail


def fmt(v):
    return "%.0f" % v if v >= 10 else ("%.1f" % v if v >= 1 else "%.2f" % v)


if __name__ == "__main__":
    d = json.load(open("final_econ_v5.json"))
    versions = {"v4": v5.v4_with_days(), "v5": v5.build(d["reb_costs"])}
    out = {}
    for hours in (6, 20):
        print("== first %d h of play of each player" % hours)
        for lab, E in versions.items():
            allr, freer, crates, detail = per_day(E, hours)
            out[(lab, hours)] = (allr, freer, crates)
            print(lab, "hammers/day per 1,000 players:", {RAR[i]: fmt(allr[i]) for i in range(8)})
            print("   of which free:", {RAR[i]: fmt(freer[i]) for i in range(8)})
            print("   crates/day:", {"%s/%s" % k: fmt(v) for k, v in sorted(crates.items())})
            for name, (got, cr, g) in detail.items():
                hi = sum(v for (src, r), v in got.items() if r >= 4)
                hif = sum(v for (src, r), v in got.items() if r >= 4 and src in FREE)
                print("   %-6s gems/h %.0f  Legendary+/h %.3f (free %.3f)  hours per Legendary+ %.1f" % (name, g, hi, hif, 1 / max(1e-9, hi)))
    json.dump({"%s_%d" % k: v for k, v in out.items()}, open("v5_market.json", "w"), default=str, indent=1)
