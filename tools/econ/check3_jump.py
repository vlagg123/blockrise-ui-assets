"""Check 3: does a Rebirth feel like a power jump? Income per minute at the end of a run vs after the Rebirth: minutes until
you earn as much per minute as before; how fast the first buildings go; minute 3-6 of a run vs the same minutes of the run before."""
import sim, recal
E = recal.load_v2()

def series(s, n):
    return [(t, e) for (t, R, e, g, st) in s.run_log if R == n]

def rate_at(pts, i, k=4):
    a = pts[max(0, i - k)]; b = pts[i]
    return (b[1] - a[1]) / max(1.0, b[0] - a[0]) * 60

if __name__ == "__main__":
  for name in ("active", "casual"):
      s = sim.simulate(E, sim.PLAYERS[name], hours=10, record=True)
      reb = [0.0] + s.events["rebirth"]
      print(name)
      for n in range(1, 5):
          if n + 1 >= len(reb): break
          prev, cur = series(s, n - 1), series(s, n)
          before = rate_at(prev, len(prev) - 1)
          back = next(((cur[i][0] - reb[n]) / 60 for i in range(len(cur)) if rate_at(cur, i) >= before), None)
          def window(pts, t0):
              w = [(t, e) for (t, e) in pts if t0 + 180 <= t <= t0 + 360]
              return (w[-1][1] - w[0][1]) / max(1, w[-1][0] - w[0][0]) * 60 if len(w) >= 2 else 0
          early = window(cur, reb[n]) / max(1, window(prev, reb[n - 1]))
          first = [(cid, round(dur)) for (tt, cid, dur, R, sh, h) in s.contract_log if R == n][:5]
          print(f"  Rebirth {n}: end of run {before:,.0f}/min; back to it after {round(back) if back else '-'} of {round((reb[n+1] - reb[n]) / 60)} min; "
                f"min 3-6: x{early:.1f} vs the run before; first builds {first}")
