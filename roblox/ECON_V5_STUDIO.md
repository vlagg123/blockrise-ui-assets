# Economy v5 (2026-10-07) — implemented in Studio, waiting for Publish

The work list is `ECONOMY_V5_PC.md`; the reasoning and the simulator numbers are `tools/econ/recipe_v5.md` (confirmed by
the owner). Implemented in Studio with the Studio MCP, every change marked `ECONOMY_V5`. Exclusive: **option A**.
The export of the live game before the change is `tools/econ/game_dump_v4.md` (section 0).

**Copies from before the change:** `ServerStorage.Backup_pre_econ5` holds Config, Company, Hammers, Main, HammerService,
RebirthService, CompanyService, TradeService, VehicleService, Client, HUD, RebirthUI, UpgradesUI, HammersUI, MoreUI,
ShopUI, CompanyUI, StoreUI, VehicleUI, HammerSwing, JobsUI, PlaytimeUI and HammerFX.

## 1. Rebirth on cash in hand
- `Company.FranchiseCost`: 150K, 600M, 25B, 150B, 1T, 4T, 10T, then ×3. `FranchiseCostOld` (pre-v4) stays;
  `FranchiseCostV4` keeps the v4 costs for the migration. The Rebirth steps of the new Road say "Save $X → Rebirth N".
- `RebirthService.franchise`: cash + credit ≥ cost AND earned-this-run + credit ≥ cost AND the zone's top building
  (as before). Messages: "Rebirth needs $X in cash — you have $Y" / "Earn $X more yourself this run (cash from trades
  and material sales doesn't count)".
- `RunEarned = Earned − RunStart − RunExcl`. `addMoney(plr, amount, reason, noMission, notEarned)`: `notEarned` adds
  to `RunExcl` (still in `Earned`, the lifetime stat).
- On Rebirth: the counters are set first (`RunStart = Earned − head start`, so the head start counts; `RunExcl`,
  `RebCredit`, `RunBest`, `RunChest` = 0), then the run resets as before (start money + 1% of the cost + Head Start
  perk). Stars = `StarsFor(min(Money, RunEarned))`.
- The bar: `RebirthService.Progress` = min(cash + credit, earned + credit) / cost. `RunBest` keeps the best % of the
  run; the prizes go by `RunBest` (once a run): 1% = 3 min of IncomePerMin in cash, 5% 10 Gems, 10% 15, 25% 20, 50% 40,
  75% 30. No crates.
- Rebirth window: the bar in cash, "Rebirth needs $X in cash — you have $Y", "≈ N min at your income now", the credit
  "saved before the update", the cost list (150K · 600M · 25B · 150B · 1T · 4T · 10T, then ×3). HUD REBIRTH dot: the
  same condition as the server.
- **Saving warning** (`RebirthUI`: `c.saveGuard(price, buy)`, `c.savingForRebirth()`): once the zone's top building is
  built, a cash buy ≥ 5% of the Rebirth (`Company.SaveWarnShare`) asks "Saving for Rebirth: this sets it back by ≈ N
  min. Buy anyway?" (KEEP SAVING / BUY ANYWAY, "Don't ask again this run"). Wired into: the Shop (crew, machines,
  gear), Upgrades (upgrades, helmet), Company (properties, MAX), house and extensions (MoreUI), cars (VehicleUI), hammer
  level-ups (HammersUI). Supply Crates (1.5 min of income) can never reach 5%. AUTO BUY BEST shows
  "PAUSED — saving for Rebirth" and a RESUME button (for this run).
- **Migration** (`EconV` 3 → 4, `V5.econ`): `RebCredit = min(0.95, v4 bar %) × v5 cost`, the run's earnings start
  from 0 on top of it, `RunBest` = that %, prizes below it count as paid, buildings built before stay open until the
  next Rebirth (as in v4). A notice says the bar kept its %. New saves start at `EconV` 4.

### Every addMoney call site
| Counts toward the Rebirth (earned) | Does not count |
|---|---|
| contract stages and completion, speed bonus, rush orders, helper pay, client tips, Mega Project | material sales (`CompanyService sell`) |
| rent online and offline (`giveRent`) | a worker let go (50% refund) |
| Empire Road, achievements, daily missions, daily login, playtime gifts, codes, Lucky Spin cash | a Supply Crate refund (X-ray error) |
| Robux cash packs, Starter Pack cash, Gem Shop Cash Bag / Cash Safe | cash from trades (never in `Earned`: `TradeService` adds to `Money` only) |
| the Rebirth bar's 1% prize, the head start | the v4 extra-property refund (never in `Earned`) |

## 2. Free crates only from missions
- Removed: the Supply Crate every 6 contracts and the 3% Builder's Crate (`HammerService.OnContract`), the bar's crates,
  the v4 update's Golden Crate gift, the hammer migration's welcome Builder's Crate. Kept: the tutorial's Supply Crate
  (bought with the tutorial's cash) and the Lucky Spin's Exclusive Crate (1 in 10,000, section 6b).
- `Main V5`: **Daily Crate** (all 3 daily missions claimed → your zone's Supply Crate, once a day), **Builder's Order**
  (contracts today: 100 / 75 / 55 by zone → a Builder's Crate, once a day), **Golden Order** (contracts this week:
  480 / 365 / 260 AND the daily set on 6 of 7 days → a Golden Crate, once a week, Monday 00:00 UTC). N by the zone of
  your best unlocked contract, fixed when the day / week starts (`Config.MissionCrates`). Given at once when done.
- Daily Missions window: the 3 missions, then DAILY CRATE, BUILDER'S ORDER (bar), GOLDEN ORDER (bar, days x/6,
  time to Monday).
- Crate cards: "Cash · the Daily Crate", "200 Gems · Builder's Order (daily)", "750 Gems · Golden Order (weekly)";
  the Shop and Inventory texts say free crates come from the Daily Missions.
- Same for the no-paid-random-items countries (X-ray for bought crates as before).
- Test hook: the `DayOffset` attribute on `Main` shifts the day (0 / absent in the live game).

## 3. Suburbs ×2 work
Villa, Warehouse, Apartments, Luxury Villa, Distribution Center: `workMult` ×2 (rewards unchanged).

## 4. Road and achievement cash
Achievements ≤ 10K back to their pre-v4 values. The Road cash is set by the new Road (section 5): each chapter ≈ 8% of
its Rebirth (Town 12K, Suburbs 48M, Downtown 2B, then 8% of each cost), which is the section 4 target.

## 5. The new Empire Road (`Config.Road`, 51 steps, `Config.RoadV` 4)
Tutorial (7 steps, unchanged) · Chapter 1 Town (10 steps, 12K) · Chapter 2 Suburbs (13 steps, 48M) · Chapter 3
Downtown (7 steps, 2B) · then per Rebirth: the new building (Skyscraper / HQ / Spire), the next Builder's Helmet,
"Save $X → Rebirth N" (8% of that Rebirth), up to Rebirth 10. Gems 5–25 a step. Crates on 5 steps: Hire 2 workers
(Builder's), Brick Garage (Supply), Corner Shop (Supply), Rebirth 1 (Builder's), Rebirth 2 (Golden).
New stats (Main `roadValue`): DailySets, BuilderOrders, GoldenOrders, TradeUps (counted from trade-ups), DeptMax,
PropertyKinds, IndexRarities, StarPerks, Helmet, Owns_<machine>. New arrow places: missions, index, tradeup.
**Migration** (`RoadV` < 4, `V5.roadMigrate`, run before anything checks the Road): in the tutorial you stay where you
were; otherwise you continue at the first step not done, and every later step already done is ticked in `RoadDone`
and passes WITHOUT a reward (no crate twice).

## 6. The new crates (still COMING SOON)
Pirate Cove: Kraken King 0.004% (1 in 25,000), Treasure Chest 5.996%; luck as in every crate (from Legendary, Secret /
Divine at most ×3, then × Secret Hunter). `crate_pirate` / `crate_temple` 199 R$ (600 Gems), Legends Crate 12,000 Gems
(299 / 3 for 799 R$). Pirate Cove text: "One of the 4 pirate hammers, Rare to Divine (Kraken King 1 in 25,000)."
Collections (`Hammers.Sets`, `SetsDone`): the 3 lower hammers of a set = +5% luck; all 4 = the title Pirate King /
Temple Guardian / Legend; shown in the Index (COLLECTIONS).

## 6b. Exclusive: option A
`h.pr` = the rarity its power, cooldown and level costs come from: Royal Crown, Ghost, Rainbow Prism = Mythic (×32),
Thunderclap = Secret (×64). `Hammers.Power / Cooldown / LevelCost` use it; the clients' swing cooldown uses
`Hammers.Cooldown(EquipKey)`. Divine stays the strongest. Prices and sources unchanged (Exclusive Crate 999 / 2699,
Exclusive of the Day 1499, Golden 1 in 100,000, Legends 1 in 5,000, Lucky Spin 1 in 10,000). No text says "x256".

## Checks (section 8), Studio Play, 2026-10-07
| # | Check | Result |
|---|---|---|
| 1 | Rebirth refused at cash = cost − 1 ("needs $600M in cash — you have $599M") and at cash = cost with 500M earned (600M came from a trade) ("Earn $100M more yourself"); accepted at both ≥ cost; cash after = 25 + 6M (1%); next cost 25B; 7 Stars | OK |
| 2 | +1B cash through the trade path and 100 Diamonds sold (+8M): bar stays 0.024% (earned 6M) | OK |
| 3 | to 52%: +85 Gems (10+15+20+40) and the 1% cash; down to 20% and back to 52%: nothing; to 76%: +30 Gems | OK |
| 4 | 50 real contracts in a row: no crate | OK |
| 5 | Daily Crate once (2nd claim: nothing); Builder's Order at exactly 100 (99: none) and not again (110); Golden Order only with 480 contracts AND the 6th daily set (Mon–Sat), nothing more on Sunday, reset the next Monday (0/480, 0 days) | OK |
| 6 | Road crates once: Hire 2 workers → 1 Builder's, again → none; Garage → 1 Supply, again → none | OK |
| 7 | Saving warning only after the Town's top building and only for ≥ 5% (an $11,544 upgrade asks "≈ 41 min"; $2,500 doesn't; KEEP SAVING buys nothing); before the top building no question; AUTO BUY BEST "PAUSED — saving for Rebirth", RESUME works | OK |
| 8 | Suburbs work ×2 (Villa 3.405 → 6.81 … Distribution Center 23.35 → 46.7), rewards the same: the same player builds the Villa in 2× the time | OK |
| 9 | v4 save at 80% of R2: credit 480M, bar 80%, prizes counted as paid; refused at cash+credit 600M / earned+credit 550M, accepted at 170M cash / 120M earned (credit used, 0 after). Road from an old save: placed at the first step not done, 8 later steps ticked; no Gems / cash / crates given by the move; the next step pays and the ticked one after it passes without a reward | OK |
| 10 | (opened in Play only, closed again) 3 × 20,000 Pirate Cove rolls without luck: Kraken 1, 0, 1; luck ×3 → Divine ×3 before sharing (luck 10 still ×3); cards show Legends 12,000 Gems / 299 R$, Pirate and Temple 600 / 199 | OK |
| 11 | Lucky Spin: 16.9 Gems per spin on average for 40 Gems; no cash → Gems path (every addGems source listed); Gems not in trades | OK |
| 12 | No-paid-random-items on: Daily Crate and Builder's Order give their crates; X-ray only, one at a time; the Exclusive Crate can't be bought; Robux buttons only on the Exclusive of the Day (a direct buy, not random) | OK |
| 13 | Fresh profile: the tutorial (crate, fence, gloves, reps, excavator, laborer, home) and Chapter 1 to Rebirth 1 with the real remotes; every window opened (16) with a clean console; Workspace = Map / Terrain / Camera, HttpEnabled false | OK |
| 14 | Royal Crown = Diamond (×32, 0.25 s, level costs, ×42.24 at Lv 5), Thunderclap = Solar (×64, 0.23 s); the Inventory card says x32 / x64; no "x256" in any script | OK |
| 15 | Rebirth window: costs list and "Rebirth needs $X in cash"; crate cards "how you get it"; Daily Missions: Daily Crate, Builder's Order, Golden Order cards | OK |
| 16 | This file, pushed | OK |

Fixed during the checks: the Road's Rebirth-step cash was paid before the new run's counters were set (it didn't count
in the new run): the counters are set first now; the crate cards with crates in the bag now show "how you get it" too.

Note for the owner: the Suburbs contracts keep their target times, so their speed bonus is harder to get with twice the
work (the recipe didn't change the times).
