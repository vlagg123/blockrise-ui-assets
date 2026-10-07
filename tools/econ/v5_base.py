"""Economy v5, step 1: where crates and hammers come from today (Economy v4), per hour of play, per player type.
Sources: tutorial, free_play (the free Supply every 6 contracts + the Builder's drop), cash (Supply crates bought),
gems (Golden for Gems), robux (Golden for Robux), mission (v5). Usage: python3 v5_base.py"""
import statistics as st
import sim, final_v2

RAR = ["Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "Secret", "Divine"]


def per_hour(E, name, hours=10, seeds=range(1, 6), **kw):
    acc = {}
    gems = []
    for seed in seeds:
        s = sim.simulate(E, sim.PLAYERS[name], hours=hours, seed=seed, **kw)
        h = s.t / 3600
        for k, v in getattr(s, "crate_src", {}).items():
            acc.setdefault(("crate",) + k, []).append(v / h)
        for (src, r), v in getattr(s, "got_src", {}).items():
            acc.setdefault(("got", src, r), []).append(v / h)
        gems.append(getattr(s, "gems_total", 0.0) / h)
    n = len(list(seeds))
    out = {k: sum(v) / n for k, v in acc.items()}
    out["gems_h"] = st.mean(gems)
    return out


def show(E, label, players=("active", "casual", "payer", "whale"), **kw):
    print("==", label)
    for name in players:
        o = per_hour(E, name, **kw)
        crates = sorted((k[1], k[2], round(v, 2)) for k, v in o.items() if k[0] == "crate")
        free_hi = sum(v for k, v in o.items() if k[0] == "got" and k[1] in ("free_play", "mission") and k[2] >= 4)
        all_hi = sum(v for k, v in o.items() if k[0] == "got" and k[2] >= 4)
        print(f"{name:7s} gems/h {o['gems_h']:.0f} | crates/h {crates}")
        print(f"        Legendary+ /h: free {free_hi:.3f} of {all_hi:.3f}")
    return


if __name__ == "__main__":
    E = final_v2.load()
    show(E, "Economy v4 (today)")
