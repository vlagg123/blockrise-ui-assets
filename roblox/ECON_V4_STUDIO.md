# Economy v4 (2026-10-07) — implemented in Studio, waiting for Publish

The recipe is `tools/econ/recipe.md` (v2, confirmed by the owner on 2026-10-07). It was implemented directly in Studio with
the Studio MCP (targeted edits, every change marked `ECONOMY_V4`). The scripts below are newer in Studio than their copies
in this folder.

**Copies from before the change:** `ServerStorage.Backup_pre_econ4` holds Config, Company, Hammers, Main, HammerService,
CompanyService, RebirthService, RebirthUI, UpgradesUI, CompanyUI, HUD, StoreUI, HammersUI and ShopUI.

## What changed, by script

### ReplicatedStorage.Shared.Config
The `ECONOMY_V4` block at the end of the file holds:
- **Contracts:** workMult, Strength gate, crew and Rebirth per contract. reqHammer, reqRep and reqLevel are reset (1 / 0 / 1).
- **Workers:** rates ×4. `Config.WorkerPrice(t, hired)`: each hire costs ×1.3 more than the one before.
- **Machines:** rates ×1.5.
- **Training stations:** ×1 / ×1.5 / ×2.5 / ×4, at 0 / 4K / 150K / 5M Strength.
- **Gems per contract:** `ContractGems` = 1 + order/4, +1 if built fast.
- **Boosts:** a new `luck` boost (the 2x Luck potion). `Config.LuckyHour` sets the Lucky Hour: 15 minutes every 3 hours.
- **Empire Road and achievements:**
  - Road cash is scaled by the run it belongs to (Town ÷6, Suburbs ×6, Downtown ×2 / ×1.5 / ×0.8).
  - The texts of the Rebirth steps show the new costs.
  - Achievements worth 10K or less are ÷6.
- **Store:**
  - Lucky Builder and Night Shift: new texts.
  - New passes, id 0: Ultra Lucky (899), Secret Hunter (1,499).
  - Prices: Golden 249, 3 Golden 699, Builder's 79.
  - New products, id 0: 10 Golden (2,199), 5 Builder's (349), 10 Exclusive (2,999), 2x Luck 30 min (99).
  - New Starter Pack text.
  - The Hammer-of-the-Day Robux products must never be created.
- **Thunderclap pass:**
  - The pass's ×3 is retired (`StormHammer.mult = 1`); its hammer is a ×64 Secret now.
  - New pass text.
- **Lucky Spin:** the top prize is an Exclusive Crate, no longer the Thunderclap.

### ReplicatedStorage.Shared.Company
- **Materials:** Steel sells for 10, Copper for 60.
- **Properties:**
  - new costs and rents;
  - ×1.45 a unit, at most 10 (`PropMax`);
  - ×1.5 rent at 10.
- **Upgrades:** +15% a level.
- **Offline:** 50% for 8 h; with Night Shift, 100% for 12 h.
- **Rebirth:**
  - Rebirth bonus: cash +150%, Strength +75%.
  - Costs: 25K, 250M, 20B, 150B, 800B, 5T, 40T, then ×3 (`FranchiseCostOld` keeps the old ones for the migration).
  - `StarsFor(run, rebirths)` = 3 + 2·n + 1 per doubling of the cost.
  - `RunHeadStart` = 1%.
  - `RunChests`: the prizes of the Rebirth bar's cash steps.
- **Builder's Helmet:** `Helmets` I–V and `HelmetLuck`.

### ReplicatedStorage.Shared.Hammers
- `RarityStep` = 2.
- New odds for every crate. Builder's costs 200 Gems, Golden 750.
- **Exclusive Crate:**
  - open: 75 / 22 / 3;
  - inside the Secret 3%: Prism 2.9, Thunderclap 0.1.
- `SupplyPrice(incomePerMin)` = 1.5 minutes of income.
- Trade-ups: `TradeUpTop` = 4 (stop at Legendary).
- **Luck in `Odds`:**
  - it counts from Legendary up;
  - on Secret and Divine, at most ×3, then × Secret Hunter;
  - `luck` may be `{ luck, hunter }`.
- Hammers of the Day cost 3,000 / 12,000 / 60,000 Gems.
- `IndexDone(d)`: the rarities you have collected in full.
- `Power(key, lv, pass)`.

### ServerScriptService.Game.Main
- **Luck** (in `HammerService.Init`) adds up:
  - Lucky Builder +1;
  - Ultra Lucky +2;
  - the Helmet;
  - the potion +1;
  - Lucky Hour +1;
  - +5% for every rarity collected in the Index.

  The Secret Hunter is ×2.
- `zoneReward` gives your IncomePerMin, which sets the Supply price.
- **Hiring and firing** use `Config.WorkerPrice`.
- **Auto Train:** ×2 on every rep.
- **Starter Pack:** adds a Golden Crate and 100 Gems.
- **The Lucky Hour loop** also pays the Index rewards (Gems once per completed rarity).
- **`RebirthService.Init` gets new ctx functions:** addGems, addCrate and supplyOf.
- **Migration of saves from before the update** (EconV < 3; new saves start at EconV 3):
  - the Rebirth bar keeps its %;
  - buildings already built stay open until the next Rebirth (`GrandOpen` / `GrandR`, checked in `contractUnlocked`);
  - properties over 10 are refunded at their old prices;
  - 1 Golden Crate as a gift, and a notice 9 s after joining.
- **Lucky Spin:** a new `crate` prize kind.

### ServerScriptService.Game.HammerService
- Luck passed as `{ luck, hunter }`.
- Builder's Crate drop: at most ×2 from luck.
- Trade-ups capped at Legendary.
- `better()` compares build power.
- `Power` honours the `pass` flag.

### ServerScriptService.Game.CompanyService
- `Helmet` in Sanitize, Publish and `get`.
- `actions.helmet` to buy the next tier.
- `HelmetModel` (a hard hat on your head, by tier), redrawn on every character.
- At most 10 of each property.
- Offline rent: 50% for 8 h, or with Night Shift 100% for 12 h.

### ServerScriptService.Game.RebirthService
- Rent gets the Rebirth cash bonus.
- `get` returns `steps` (the zone's buildings), `chests` and `headStartPerk`.
- `franchise` uses the new Stars rule and starts the new run with 1% of the Rebirth just paid.
- A loop gives the cash-step prizes (1 / 5 / 10 / 25 / 50 / 75%).

### Client scripts
| Script | Changes |
|---|---|
| RebirthUI | the stepped bar; a row with the zone's buildings; a row with the cash steps and the "about X min left" estimate; texts for the zones that open |
| UpgradesUI | BEST BUY; the Builder's Helmet row |
| CompanyUI | at most 10 properties; MAX button; new texts; the RebirthStep toast |
| HammersUI | odds as "1 in X" with the %; Thunderclap "1 in ???" and the line with exact odds; trade-ups only up to Legendary; power for pass hammers |
| StoreUI | Ultra Lucky and Secret Hunter in HAMMERS & CRATES; Robux crates show "1 in X (Y%)"; Lucky Builder text |
| ShopUI | the crew's price ×1.3 a hire |
| HUD | the LUCKY HOUR / 2x LUCK pill |

## Tested in Studio Play (the DataStore is off in Studio: nothing was saved)

| What | Result |
|---|---|
| House contract | 4,101 work, the same as the simulator |
| Supply Crate price | 1.5 × IncomePerMin |
| 2x Luck potion | Legendary from Golden 9.4% → 16.9% |
| Trade-up past Epic | refused |
| Rebirth | Stars 7 (3+2+2 doublings); next run starts with $275 = 25 + 1% of 25K; next cost 250M |
| Rebirth bar prizes at 28% | 2 Supply Crates, 30 Gems |
| Helmet I | bought; model on the head; luck +10%; tier II wants Rebirth 2 |
| Properties | 10 at most; rent ×1.5 × the Rebirth bonus |
| Index | all Commons → +100 Gems, +5% luck |
| Exclusive Crate | opens (75/22/3) |
| Rebirth 3 + 160M Strength | everything up to the Skyscraper opens; HQ and Spire locked |
| Windows (opened from the server) | Rebirth, Upgrades, Company, Store / Gem Shop and Shop draw with no errors |
| Migration (harness) | the bar keeps its %, refunds, GrandOpen and the gift all work |

After the tests: Play stopped, Workspace = Map / Terrain / Camera, HttpEnabled = false.

## Left for the owner
- Publish + Restart servers.
- Create on Roblox and send the ids (they are hidden in the live game until then):
  - passes: Lucky Builder (299), Ultra Lucky (899), Secret Hunter (1,499), Night Shift (199), Quick Open (99), Auto Opener (199);
  - products: Golden 249 / 3 for 699 / 10 for 2,199; Builder's 79 / 5 for 349; Exclusive 399 / 3 for 999 / 10 for 2,999; 2x Luck 99.
- Set the Thunderclap Hammer pass off sale on Roblox.
- Do NOT create the Hammer-of-the-Day Robux products (99 / 249 / 549).
