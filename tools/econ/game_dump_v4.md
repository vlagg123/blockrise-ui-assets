# BlockRise Empire — live game data before Economy v5 (exported from Studio, 2026-10-07)

Read-only export of the game as it is live (Economy v4, `EconV` 3, `RoadV` 3), taken from Studio before any v5 edit.
Sources: `ReplicatedStorage.Shared.Config` / `Company` / `Hammers`, `ServerScriptService.Game.Main` /
`HammerService` / `RebirthService` / `TradeService`.

## 1. Empire Road (`Config.Road`, 47 steps; `Config.TutorialSteps` = 7, `RoadTutorialSteps` = 7)
The Road pays `cash` and `gems` when `stat >= target`; no step gives a crate. Steps 1–7 are the tutorial (`buy` = the
tutorial tops your cash up to the price of that buy once).

| # | Title | Stat | Target | Cash | Gems | Place / other |
|---|---|---|---|---|---|---|
| 1 | Your first hammer | FirstCrate | 1 | 10 | 5 | shop, buy=crate |
| 2 | Build your first fence | Completed | 1 | 17 | 5 | board |
| 3 | Training gloves | GearTier | 2 | 17 | 5 | gearshop, buy=gear |
| 4 | Get stronger | TrainReps | 10 | 17 | 5 | tires |
| 5 | Your first machine | MachinesOwned | 1 | 25 | 5 | machines, buy=machine |
| 6 | Hire a worker | Workers | 1 | 25 | 5 | hire, buy=worker |
| 7 | Visit your property | VisitedHome | 1 | 50 | 10 | home |
| 8 | Three contracts | Completed | 3 | 50 | 10 | board |
| 9 | Lifting Belt | GearTier | 3 | 50 | 10 | gearshop |
| 10 | Upgrade your house | HouseLevel | 2 | 67 | 10 | home |
| 11 | Reach Level 4 | Level | 4 | 100 | 15 | board |
| 12 | Build a family house | Built_house | 1 | 250 | 15 | board |
| 13 | Get some wheels | VehiclesOwned | 1 | 170 | 10 | garage |
| 14 | Found your company | CompanyFounded | 1 | 330 | 20 | company |
| 15 | Your first property | PropertyCount | 1 | 250 | 15 | company |
| 16 | 5,000 Strength | Strength | 5,000 | 250 | 15 | gym |
| 17 | First upgrade | DeptLevels | 1 | 330 | 15 | upgrades |
| 18 | First Rebirth | Rebirths | 1 | 18,000 | 25 | rebirth |
| 19 | Your first extension | ExtCount | 1 | 18,000 | 20 | home |
| 20 | Mega Project | MegaBuilt | 1 | 24,000 | 20 | mega |
| 21 | A real crew | Workers | 5 | 36,000 | 20 | hire |
| 22 | Premium contract | BlueprintsUsed | 1 | 48,000 | 25 | board |
| 23 | Real estate mogul | PropertyCount | 10 | 60,000 | 25 | company |
| 24 | Two-Story Villa | Built_villa | 1 | 72,000 | 25 | board |
| 25 | Concrete Mixer | MachinesOwned | 2 | 72,000 | 25 | machines |
| 26 | 30,000 Strength | Strength | 30,000 | 120,000 | 25 | gym |
| 27 | Reach Level 10 | Level | 10 | 150,000 | 30 | — |
| 28 | Logistics Warehouse | Built_warehouse | 1 | 240,000 | 30 | board |
| 29 | Six figures | Earned | 100,000 | 300,000 | 30 | — |
| 30 | Power player | DeptLevels | 25 | 360,000 | 30 | upgrades |
| 31 | Property empire | PropertyCount | 50 | 720,000 | 40 | company |
| 32 | Apartment Block | Built_apartments | 1 | 600,000 | 40 | board |
| 33 | 300,000 Strength | Strength | 300,000 | 900,000 | 40 | gym |
| 34 | Luxury Villa | Built_luxvilla | 1 | 1,800,000 | 50 | board |
| 35 | Second Rebirth | Rebirths | 2 | 300,000 | 60 | rebirth |
| 36 | Millionaire | Earned | 1,000,000 | 800,000 | 50 | — |
| 37 | Distribution Center | Built_distcenter | 1 | 1,600,000 | 60 | board |
| 38 | Third Rebirth | Rebirths | 3 | 75,000 | 100 | rebirth |
| 39 | 5,000,000 Strength | Strength | 5,000,000 | 750,000 | 75 | gym |
| 40 | Downtown builder | Built_office | 1 | 1,100,000 | 60 | downtown |
| 41 | Grand Hotel | Built_hotel | 1 | 3,000,000 | 60 | downtown |
| 42 | Fourth Rebirth | Rebirths | 4 | 200,000 | 100 | rebirth |
| 43 | Skyscraper | Built_skyscraper | 1 | 4,800,000 | 80 | downtown |
| 44 | Collector | Hammers | 12 | 400,000 | 120 | shop |
| 45 | Corporate HQ | Built_hq | 1 | 16,000,000 | 100 | downtown |
| 46 | Legendary hands | ToolTier | 5 | 1,600,000 | 150 | shop |
| 47 | Landmark Spire | Built_spire | 1 | 48,000,000 | 250 | downtown |

Notes: the Road position is `d.Road` (an index). Stats come from `roadValue` / `statValue` in Main (Workers, Hammers =
Index count, MachinesOwned, VehiclesOwned, ExtCount, PropertyCount = all units, DeptLevels = sum of levels,
Built_<id> = Portfolio count, FirstCrate, VisitedHome, TrainReps, BlueprintsUsed, CompanyFounded, the rest = `d[stat]`).

## 2. Daily missions and other rewards
### Daily missions (`Config.DailyMissions`)
3 a day (UTC day), picked at random from the 7 below with the seed `day * 7919 + UserId % 100000`. Each claim pays
`max(MissionReward(m, Level), bestUnlockedReward × share)` cash, `xp × (1 + 0.3·(Level−1))` XP and **5 Gems**
(`Config.Gems.mission`). The "earn" target scales: `max(target × (1 + 0.6·(Level−1)), 1.5 × best contract reward)`,
rounded to 50.

| id | Text | Target | Cash base | share | XP |
|---|---|---|---|---|---|
| hits | Make %d build hits | 150 | 150 | 0.30 | 40 |
| contracts | Complete %d contracts | 2 | 260 | 0.60 | 70 |
| stages | Finish %d construction stages | 8 | 200 | 0.40 | 50 |
| earn | Earn %s from jobs | 800 (scaled) | 220 | 0.45 | 60 |
| helper | Help another crew finish %d stage | 1 | 320 | 0.50 | 90 |
| combo | Reach the max x2.0 combo | 1 | 160 | 0.30 | 40 |
| train | Do %d training reps | 120 | 200 | 0.40 | 50 |

No crate from missions today. No "all 3 done" bonus.

### Daily login streak
On the first join of a UTC day: streak +1 (or back to 1), cash = `max((100 + 25·Level) × min(streak, 7),
bestUnlockedReward × 0.15 × min(streak, 7))`, Gems = `3 × min(streak, 7)`.

### Playtime gifts (`Config.PlaytimeGifts`, minutes played that UTC day; cash = × best contract reward)
| min | cash × | Gems | other |
|---|---|---|---|
| 5 | 0.5 | 3 | |
| 10 | 1 | 5 | |
| 20 | 1.5 | — | 2x Power 5 min |
| 30 | 2 | 10 | |
| 45 | 3 | — | 2x Cash 10 min |
| 60 | 5 | 25 | Silver Blueprint |

### Achievements (`Config.Achievements`, once each; + 10 Gems each)
| id | Name | Stat ≥ target | Cash |
|---|---|---|---|
| first | First Job | Completed 1 | 50 |
| c10 | Reliable Contractor | Completed 10 | 170 |
| c50 | Construction Legend | Completed 50 | 1,670 |
| types | Jack of All Trades | Types 15 | 1,330 |
| lv5 | Rising Builder | Level 5 | 80 |
| lv10 | Master Builder | Level 10 | 500 |
| lv15 | Construction Tycoon | Level 15 | 1,500 |
| earn10k | Ten Grand | Earned 10,000 | 170 |
| earn100k | Six Figures | Earned 100,000 | 1,330 |
| earn1m | Millionaire | Earned 1,000,000 | 50,000 |
| crew5 | Crew Chief | Workers 5 | 250 |
| fleet | Heavy Metal | MachinesOwned 3 | 500 |
| dream | Dream Home | HouseLevel 3 | 670 |
| estate | Estate Owner | ExtCount 3 | 830 |
| mega | City Builder | MegaBuilt 1 | 330 |
| streak7 | Dedicated | Streak 7 | 500 |
| trade1 | Deal Maker | Trades 1 | 330 |
| str10k | Strong Hands | Strength 10,000 | 1,330 |
| str1m | Titan | Strength 1,000,000 | 400,000 |

(v4 divided the achievements worth ≤ 10K by 6, rounded to 10, at least 50. The values before that, in the table's
order: 100 · 1,000 · 10,000 · 8,000 · 500 · 3,000 · 9,000 · 1,000 · 8,000 · 50,000 · 1,500 · 3,000 · 4,000 · 5,000 ·
2,000 · 3,000 · 2,000 · 8,000 · 400,000.)

(The Road cash above is after the v4 scaling: Town ÷6, Suburbs ×6, Downtown ×2 / ×1.5 / ×0.8.)

### Index rewards
Every Ladder rarity whose crate hammers you all own (not exclusive / event / pass / set / soon, not the Rusty): once
`100 × rarity index` Gems, and +5% luck forever (`Hammers.IndexDone`).

### Codes (`Config.Codes`, once per player)
| Code | Gems | Cash | Boost |
|---|---|---|---|
| BLOCKRISE | 25 | — | 2x Cash 15 min |
| BUILDER | 25 | — | 2x Strength 15 min |
| RELEASE | 50 | best contract × 3 | — |

## 3. Every crate given without paying
| Where | Crate | How often | Who | Code |
|---|---|---|---|---|
| Finished contract (`HammerService.OnContract`) | Supply Crate of your zone | every 6th contract (`CrateProgress`) | everyone | HammerService 186–197 |
| Finished contract | Builder's Crate | 3% of the other contracts, × luck up to ×2 | everyone | HammerService 193 |
| Rebirth bar (`Company.RunChests`, `RebirthService.checkChests`) | Supply (1%), Supply (10%), Builder's (50%) | once per run | everyone (not in the tutorial) | RebirthService 126–145 |
| Lucky Spin prize "EXCLUSIVE CRATE" | Exclusive Crate | weight 0.01 of 100 (1 in 10,000 spins; free spin every 4 h) | everyone | Main 2806 |
| v4 migration gift (`EconV` < 3) | Golden Crate | once, for a save from before v4 | old saves | Main 1819–1820 |
| Hammer migration (`HammerService.Migrate`, `HammerV` nil) | Builder's Crate | once, for a save from before the hammers | very old saves | HammerService 161 |
| Tutorial step 1 | Supply Crate | once | bought with the tutorial's top-up cash | Main 589–607 |

Paid ones (not free): Starter Pack (Builder's + Golden), Robux crate products, the purchase ledger restore.

**No-paid-random-items countries** (`PaidRandomRestricted`): the same free crates as everyone (`CrateEvery` = 6 for
all). Bought crates use X-Ray (you see the hammer before you pay: `HammerService.XRay`). Paid spins are blocked
(the free spin works).

## 4. Gems
### Sources
| Source | Amount |
|---|---|
| Finished contract | `1 + floor(order / 4)` (+1 if fast), ×2 with 2x Gems |
| Build hit | 1 in 350 hits (`hitChance` 0.00286); training rep 1 in 700 |
| Daily mission claim | 5 each |
| Daily login | 3 × min(streak, 7) |
| Empire Road | 5–250 per step |
| Achievements | 10 each |
| Index rarity complete | 100 × rarity index, once |
| Playtime gifts | 3 / 5 / 10 / 25 a day |
| Mega Project | 3 (+5 for the top builder) |
| Rebirth bar | 10 (5%), 20 (25%), 30 (75%) per run |
| Lucky Spin | 30 / 60 / 150 / 500 / 1,500 prizes |
| Codes | 25 / 25 / 50 |
| Robux | Gem packs, Starter Pack (600) |

### Gem Shop (`Config.GemShop`)
| Item | Gems |
|---|---|
| 2x Cash 15 min | 60 |
| 2x Strength 15 min | 50 |
| 2x Build Power 15 min | 50 |
| 2x Crew Speed 15 min | 40 |
| Cash Bag (10 min of income) | 40 |
| Cash Safe (60 min of income) | 200 |
| Instant Finish | `max(3, ceil((5 + 10·order) × work left))` |
| +1 Crew Slot (max 3) | 300, rising (`CrewSlotGems`) |

Other Gem sinks: Builder's Crate 200, Golden Crate 750, Pirate Cove / Jungle Temple 600 (coming soon), Legends 2,500
(coming soon), Hammers of the Day 3,000 / 12,000 / 60,000, Builder's Helmet IV 2,500 / V 10,000.

### Lucky Spin (`Config.Spin`)
Free every 4 h (`cooldown` 14,400 s); extra spins from Robux; otherwise **40 Gems** a spin (blocked in no-paid-random
countries). Prizes (weight of 100): Cash Bag ×2 best reward 20.09 · 30 Gems 12 · 2x Cash 10 min 10 · 2x Strength 10 min
9 · Cash Stack ×5 10 · 60 Gems 8 · 2x Power 15 min 6 · Rush Crew 15 min 5 · 10 Steel Beams 5 · 3 Free Spins 4 · Gold
Blueprint 3 · 150 Gems 3 · Cash Vault ×12 2 · 2x Cash 1 h 1.2 · Diamond Blueprint 0.8 · 500 Gems 0.5 · MEGA JACKPOT ×40
0.3 · 1,500 Gems 0.1 · Exclusive Crate 0.01.
Average Gem prize of a spin: (30·12 + 60·8 + 150·3 + 500·0.5 + 1500·0.1) / 100 = **16.9 Gems** (< 40).

Trades move cash (−5% fee), hammers, materials and blueprints; never Gems or crates.

## 5. Rebirth
- **Condition** (`RebirthService.franchise`): `RunEarned = Earned − RunStart ≥ FranchiseCost(Rebirths)` and the
  zone's top building (the last contract with `reqRebirth == Rebirths`) built once. Not while trading.
- **Costs** (`Company.FranchiseCost`): 25K, 250M, 20B, 150B, 800B, 5T, 40T, then ×3. (`FranchiseOld` = the costs before
  v4: 150K, 40M, 10B, 100B, 1T, then ×10.)
- **Stars:** `3 + 2·(n+1) + floor(log2(RunEarned / cost))`.
- **Resets** (`resetRun`): Money → StartMoney (25) + 1% of the cost paid + Head Start perk; Gear → Bare Hands;
  Strength → 0; workers (keeps 1 per Loyal Crew perk level); machines and their levels; properties; upgrades
  (departments); the current contract.
- **Keeps:** Level, XP, Rep, Gems, hammers, crates, house and extensions, vehicles, helmet, company, materials,
  blueprints, Portfolio (built counts), Road position, achievements, Stars and perks, passes.
- **Bonuses per Rebirth:** cash and rent +150%, Strength +75%, +crew slots (`RebirthCrewSlots`).
- **The bar** (`RunChests`, paid once per run when `RunEarned / cost` passes the step): 1% Supply Crate · 5% 10 Gems ·
  10% Supply Crate · 25% 20 Gems · 50% Builder's Crate · 75% 30 Gems. `d.RunChest` = how many were paid.
- **v4 migration** (`EconV` < 3): the bar % kept (`RunStart` moved), buildings built before stay open until the next
  Rebirth (`GrandOpen`), extra properties over 10 refunded, a free Golden Crate.
