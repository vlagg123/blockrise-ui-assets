"""Check 4: real play is a session a day. Players who play 20 / 45 / 90 min a day: on which day (and after how many minutes of
play) each Rebirth comes, and how much of the money came from the night (offline rent)."""
import sim, recal
E = recal.load_v2()
E["reb_headstart"] = 0.01
import sys
E["offline_counts"] = (sys.argv[1] != "no") if len(sys.argv) > 1 else True
print("offline counts toward the Rebirth:", E["offline_counts"])
for label, base, sess in (("casual 20 min/day", "casual", 20), ("casual 45 min/day", "casual", 45), ("active 45 min/day", "active", 45),
                          ("active 90 min/day", "active", 90), ("active 90 min/day + Night Shift", "active", 90)):
    P = dict(sim.PLAYERS[base]); P["session_min"] = sess
    if "Night" in label: P["passes"] = set(P["passes"]) | {"nightshift"}
    s = sim.simulate(E, P, hours=sess * 30 / 60, record=True)
    mins = sim.report(s)["rebirth_minutes"][:5]
    days = s.reb_day[:5]
    total = getattr(s, "total_earned", 1.0)
    print(f"{label:34s} Rebirths on day {days} (play {[round(m) for m in mins]} min); offline = {s.offline_earned / max(1, total) * 100:.0f}% of all money")
