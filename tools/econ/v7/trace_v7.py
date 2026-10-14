import proposal as PR, sim7
from sim7 import *
E = PR.base_proposal(); E["road"] = PR.road_v7(E); PR.tune(E, verbose=False)
orig = sim7.do_build
def b(E_, st, c, P, rng):
    before = (int(st.money), len(st.workers), st.gear)
    r = orig(E_, st, c, P, rng)
    if st.built[c["id"]] == 1:
        print(f"{st.t/60:6.1f}m first {c['id']:11} R{st.R} L{st.L:3} S {st.S:>15,.0f}  $ {before[0]:>14,}  crew {before[1]:2}  gear {before[2]+1:2}  dept {sum(st.dept.values()):3}  gems {int(st.gems):5}  hammer r{hammer_now(st)[0]}  crates {sum(st.crates_opened.values())}")
    return r
sim7.do_build = b
st = simulate(E, PLAYER, seed=2, until_R=3)
print("gems/h", st.gems / (st.t / 3600))
