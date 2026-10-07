"""EXCLUSIVE_V2 (made in the PC session): Exclusive became the top rarity (x256 power, above Divine x128), 100% in the
Exclusive Crate (999 R$) and sold directly (Exclusive of the Day, 1499 R$). What a player who buys one at the start
does to the pacing, and what each rarity costs in Robux (expected, through the Golden Crate at 249 R$).
Usage: python3 v5_exclusive.py"""
import json, statistics as st
import sim, v5

if __name__ == "__main__":
    d = json.load(open("final_econ_v5.json"))
    E = v5.build(d["reb_costs"])
    E["level_base"] = list(E["level_base"]) + [40e6]   # (Exclusive: level base 40M, EXCLUSIVE_V2)
    gold = E["crates"]["golden"]["odds"]
    names = ["Rare", "Epic", "Legendary", "Mythic", "Secret", "Divine"]
    print("== power and price of each rarity (Golden Crate 249 R$, no luck)")
    for i, nm in zip(range(2, 8), names):
        p = gold[i] / 100
        print("  %-9s x%-4d  1 in %-8s ~%s R$" % (nm, 2 ** i, "%.0f" % (1 / p), "{:,.0f}".format(249 / p)))
    print("  %-9s x%-4d  Exclusive Crate 999 R$ (100%%) / Exclusive of the Day 1499 R$" % ("Exclusive", 256))
    print("== pacing (v5), minutes to R1..R5: no purchase vs an Exclusive (x256) from the start")
    for name in ("casual", "payer"):
        for lab, kw in (("as today", {}), ("+ Exclusive", {"start_best": (8, 1)}), ("+ Legendary", {"start_best": (4, 1)})):
            print("  %-6s %-12s %s" % (name, lab, [v5.hm(x) for x in v5.pacing(E, name, seeds=range(1, 4), upto=5, **kw)]), flush=True)
