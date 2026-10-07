"""Economy v5: are the crate missions worth what the crate costs in Gems? Per zone, for active and casual players:
contracts per hour, Gems per contract from playing (contract Gems + 1 per 350 hits, without the daily rewards), the play
it takes to farm a Builder's (200) / Golden (750) and how long the Builder's / Golden Orders take.
Usage: python3 v5_value.py"""
import json, statistics as st
import sim, v5

if __name__ == "__main__":
    d = json.load(open("final_econ_v5.json"))
    E = v5.build(d["reb_costs"])
    M = E["missions"]
    for name in ("active", "casual"):
        z = {}
        for seed in (1, 2, 3):
            s = sim.simulate(E, v5.player(name), hours=24, seed=seed, max_rebirths=8)
            byid = {c["id"]: c for c in E["contracts"]}
            prev = 0.0
            for (t, cid, dur, R, share, hits) in s.contract_log:
                c = byid[cid]
                zone = sim.zone_supply_for(R) if hasattr(sim, "zone_supply_for") else ("town" if R == 0 else "suburbs" if R == 1 else "downtown")
                order = sim.ORDER.index(cid) + 1
                g = E["gems_contract"](order, dur <= c["target"]) + hits * E["gem_hit"]
                a = z.setdefault(zone, [0, 0.0, 0.0])
                a[0] += 1; a[1] += g; a[2] += t - prev
                prev = t
        print(name)
        for zone in ("town", "suburbs", "downtown"):
            if zone not in z: continue
            n, g, secs = z[zone]
            cph = n / (secs / 3600)
            gpc = g / n
            print("  %-8s %5.0f contracts/h  %.1f Gems/contract  %3.0f Gems/h of play | 200 Gems = %.0f contracts (%.1f h)  750 Gems = %.0f contracts (%.1f h) | Builder's Order %d (%.1f h)  Golden Order %d (%.1f h)" % (
                zone, cph, gpc, gpc * cph, 200 / gpc, 200 / gpc / cph, 750 / gpc, 750 / gpc / cph,
                M["builder_n"][zone], M["builder_n"][zone] / cph, M["golden_n"][zone], M["golden_n"][zone] / cph))
