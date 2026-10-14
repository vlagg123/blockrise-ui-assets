# BlockRise economy check (2026-10-14): prices from the live Config/Hammers (Studio dump)
gem_packs = [(100,49),(300,129),(750,299),(1700,599),(4500,1399),(12000,3299)]
best = min(r/g for g,r in gem_packs)   # R$ per gem, 12000 pack
worst = max(r/g for g,r in gem_packs)  # 100 pack
mid = 599/1700
print(f"R$ per gem: best {best:.3f} (12k pack), 1.7k pack {mid:.3f}, smallest {worst:.3f}")
# odds at luck 1 / 4 / 8+hunter (from Hammers.Odds), rarity 4..9 = Epic, Leg, Myt, Sec, Div, Exc
crates = {
 'builder': dict(gems=200, rbx=79, rbx_pack=349/5, L1={4:12,5:1.85,6:0.5,7:0.1,8:0.05,9:0.002},
                 L4={4:11.16,5:6.88,6:1.86,7:0.372,8:0.186,9:0.002}, L8h={4:10.11,5:12.47,6:3.37,7:1.35,8:0.674,9:0.002}),
 'golden':  dict(gems=750, rbx=249, rbx_pack=2199/10, L1={4:33,5:9.4,6:1.3,7:0.6,8:0.3,9:0.01},
                 L4={4:24.48,5:27.89,6:3.86,7:1.78,8:0.89,9:0.01}, L8h={4:17.5,5:39.9,6:5.52,7:5.1,8:2.55,9:0.01}),
 'pirate':  dict(gems=600, rbx=199, rbx_pack=199, L1={4:24,5:5.795,8:0.2,9:0.005},
                 L4={4:20.34,5:19.65,8:0.678,9:0.005}, L8h={4:16.7,5:32.3,8:2.23,9:0.005}),
 'temple':  dict(gems=600, rbx=199, rbx_pack=199, L1={4:24,5:4.995,6:1,9:0.005},
                 L4={4:20.34,5:16.93,6:3.39,9:0.005}, L8h={4:16.9,5:28.1,6:5.64,9:0.005}),
 'legends': dict(gems=3000, rbx=999, rbx_pack=2699/3, L1={5:54.96,6:33,7:12,9:0.04},
                 L4={5:23.38,6:56.16,7:20.42,9:0.04}, L8h={5:10.75,6:51.65,7:37.56,9:0.04}),
 'exclusive': dict(gems=None, rbx=999, rbx_pack=2699/3, L1={6:77,7:14,8:6,9:3},
                 L4={6:47.57,7:34.6,8:14.83,9:3}, L8h={6:18.81,7:54.73,8:23.46,9:3}),
 'divine':  dict(gems=None, rbx=1499, rbx_pack=3999/3, L1={7:65,8:28.33,9:6.67},
                 L4={7:34.02,8:59.31,9:6.67}, L8h={7:11.7,8:81.63,9:6.67}),
}
names = {5:'Legendary+',6:'Mythic+',7:'Secret+',8:'Divine+',9:'Exclusive'}
def cheapest_rbx(c):
    opts = [c['rbx_pack'], c['rbx']]
    if c['gems']: opts.append(c['gems']*best)
    return min(opts)
print("\nR$ per hammer of rarity X or better (cheapest way to buy the crate; gems at the 12k-pack rate):")
for lk in ('L1','L4','L8h'):
    print(f"  luck {lk}:")
    for r in (6,7,8,9):
        row = []
        for k,c in crates.items():
            p = sum(v for rr,v in c[lk].items() if rr>=r)/100
            if p>0: row.append(f"{k} {cheapest_rbx(c)/p:,.0f}")
        print(f"    {names[r]:10s}: " + " | ".join(row))
print("\nGem route vs direct Robux (crate bought with gems from the 12k pack / from the 1.7k pack, vs cheapest Robux price):")
for k,c in crates.items():
    if c['gems']:
        print(f"  {k:8s} gems {c['gems']}: {c['gems']*best:6.0f} R$ (12k) / {c['gems']*mid:6.0f} R$ (1.7k)  vs Robux {c['rbx']} (pack {c['rbx_pack']:.0f})")
print("\nNo-arbitrage gem price (>= cheapest Robux per crate / best gem rate):")
for k,c in crates.items():
    if c['gems']:
        print(f"  {k:8s}: >= {c['rbx_pack']/best:,.0f} gems (now {c['gems']})")
# boosts / cash / spins
print("\nOther things sold for both:")
print(f"  2x Cash 30 min: Robux 79 | gems 2x60=120 -> {120*best:.0f}-{120*worst:.0f} R$  -> fair gem price >= {79/best/2:.0f} per 15 min")
for nm,mins,r in (('Cash Stack',20,49),("Contractor's Bonus",40,99),('Cash Vault',90,199),('Cash Empire',300,699)):
    print(f"  {nm:18s} {mins:3d} min / {r} R$ = {r/mins:.2f} R$ per minute")
for nm,mins,g in (('Cash Bag',10,40),('Cash Safe',60,200)):
    print(f"  {nm:18s} {mins:3d} min / {g} gems = {g*best/mins:.2f}-{g*worst/mins:.2f} R$ per minute -> fair >= {2.21*mins/best:.0f} gems")
print(f"  Spin: Robux 79/5 = 15.8 R$ | gems 40 = {40*best:.1f}-{40*worst:.1f} R$ -> fair >= {15.8/best:.0f} gems")
# hammer of the day in gems vs crates (gems)
print("\nHammer of the Day (gems) vs the gem crates:")
leg_plus_legends = 3000/1.0
myt_plus_legends = 3000/((33+12)/100)
epic_plus_builder = 200/((12+1.85+.5+.1+.05)/100)
epic_plus_golden = 750/((33+9.4+1.3+.6+.3)/100)
print(f"  Epic+ from a Builder's Crate: {epic_plus_builder:,.0f} gems, from a Golden: {epic_plus_golden:,.0f} gems  | Epic of the Day 3,000")
print(f"  Legendary+ from a Legends Crate: {leg_plus_legends:,.0f} gems | Legendary of the Day 12,000")
print(f"  Mythic+ from Legends Crates: {myt_plus_legends:,.0f} gems | Mythic of the Day 60,000 ({60000*best:,.0f} R$ at the best rate; an Exclusive Crate, Mythic+ always, is 999 R$)")
print(f"\nExclusive Hammer of the Day 1,499 R$ vs an Exclusive from crates: Exclusive Crate {999/0.03:,.0f} R$, Divine Crate {1499/0.0667:,.0f} R$ (3-packs: {900/0.03:,.0f} / {1333/0.0667:,.0f})")
# starter pack value
sp = 600*best + 249 + 79 + 79
print(f"\nStarter Pack 99 R$: 600 gems ({600*best:.0f}-{600*worst:.0f} R$) + Golden (249) + Builder's (79) + 30 min 2x Cash (79) = {sp:.0f}+ R$ of value")
# luck passes cost
print(f"\nMax luck x8: Lucky Builder 299 + Ultra Lucky 899 (=x4) + 2x Luck boost 99/30 min + Lucky Rush (free, 5 min every 40) + Helmet V (+2) ...; Secret Hunter 1499")
