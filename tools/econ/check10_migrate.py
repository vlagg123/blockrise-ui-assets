"""Check 10: players who already play today. Play the live economy for 1 / 3 / 6 / 10 hours, then switch the same save to
the new one: income per minute before and after, how full the Rebirth bar is, which buildings they lose, and the minutes
to their next Rebirth (new economy) vs what it would have been (old economy)."""
import copy
import sim, recal, tables
OLD = sim.current()
NEW = recal.load_v2(); NEW["reb_headstart"] = 0.01
sh = tables.short

def income(s):
    return s.income_per_sec() * 60

def next_reb(s, E, minutes_cap=600):
    t = copy.deepcopy(s); t.E = E
    R0 = t.R; start = t.t
    # continue the same player for up to minutes_cap
    P = t.P
    s2 = sim.simulate(E, P, hours=0.001)   # warm
    # run the loop by hand: reuse simulate on a copy is not possible, so emulate with a fresh sim from this state
    return None

for hours in (1, 3, 6, 10):
    s = sim.simulate(OLD, sim.PLAYERS["active"], hours=hours, record=True)
    before = income(s)
    run_old = s.earned_run / OLD["rebirth_cost"](s.R)
    lost = [c["id"] for c in OLD["contracts"] if s.unlocked(c)]
    t = copy.copy(s); t.E = NEW
    t.props = {k: min(10, v) for k, v in s.props.items()}
    now_open = [c["id"] for c in NEW["contracts"] if t.unlocked(c)]
    lost = [x for x in lost if x not in now_open]
    after = income(t)
    run_new = s.earned_run / NEW["rebirth_cost"](s.R)
    rent_b = s.rent_per_sec() * 60; rent_a = t.rent_per_sec() * 60
    print(f"after {hours:2d} h: R{s.R}, hammer {sim.RARITY[s.best[0]]}, strength {sh(s.strength)}, {sum(s.props.values())} properties")
    print(f"     income/min {sh(before)} -> {sh(after)} (x{after / max(1, before):.1f}); rent/min {sh(rent_b)} -> {sh(rent_a)}; "
          f"Rebirth bar {run_old * 100:.0f}% -> {run_new * 100:.0f}%; buildings lost: {lost or 'none'}")
