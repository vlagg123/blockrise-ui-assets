# BlockRise Empire — Economy v5: implement it (PC session)

**The owner confirmed Economy v5 and wants you to implement it now.** This file is the complete work list.
- `tools/econ/recipe_v5.md` (Romanian) has the reasoning and the simulator results behind every number.
- `HANDOFF_PC.md` has the background (Steps 0–2 are done).
- Talk to the owner in Romanian.

**How to work:**
1. Read this whole file first.
2. Do the sections in order.
3. **Do not change any number on your own.** If the live code makes a rule impossible, or something is unclear, stop and
   ask the owner.
4. Backups first: `ServerStorage.Backup_pre_econ5` with every script you touch.
5. Mark every edit `ECONOMY_V5`.
6. Keep a change log in `roblox/ECON_V5_STUDIO.md` (the same style as `roblox/ECON_V4_STUDIO.md`).
7. When everything is implemented, run **every check in section 8 (VERIFY)**. Report each one to the owner with its
   result (OK / what was wrong / what you fixed).
8. Only then: stop Play, Workspace = Map / Terrain / Camera, HttpEnabled = false, push to GitHub, and tell the owner he
   can Publish (+ Restart servers).

## Standing rules (from the owner)
- The game is LIVE. Nothing that touches the live game without the owner's approval. **Never publish**: the owner does
  Publish + "Restart servers" in Creator Hub himself.
- After every change in Studio:
  1. test in Play (`start_stop_play`, read the console);
  2. stop Play;
  3. check that Workspace holds only Map / Terrain / Camera and that `HttpService.HttpEnabled` is false;
  4. tell the owner (in Romanian) that he can publish.
- All Studio work goes through the Roblox Studio MCP (`list_roblox_studios` gives the id; it changed with the move).
- Admin panel stays secure: admins 4285033131 (owner) and 2808108421.
- Commits end with the `Co-Authored-By` / `Claude-Session` lines the session gives.
- Don't use `screen_capture` (the owner rejected it). Avoid permission prompts while he is away.
- Mouse input in Studio timed out on the Mac and VirtualInputManager is not allowed. Open windows from the server
  instead: `game.ReplicatedStorage.Remotes.OpenUI:FireClient(player, "Store"|"Shop"|"Rebirth"|...)`, then read the
  client's TextLabels.
- Studio has no DataStore access, so nothing is saved in Play. The `CE_Debug` commands give / set things in Play.


## 0. Export the live game's data (if not done yet): `tools/econ/game_dump_v4.md`, pushed
1. `Config.Road`: every step with its title, stat, target, cash, gems, other rewards and place, plus
   `Config.TutorialSteps`.
2. Daily missions:
   - `Config.DailyMissions`: how many a day, how they are picked, every target and reward;
   - streak rewards;
   - `PlaytimeGifts`;
   - Achievements;
   - Index rewards;
   - codes.
3. Every place a crate is given without paying: which crate, how often, for whom. Include the
   no-paid-random-items countries.
4. Gems:
   - every source;
   - every Gem Shop item with its price;
   - the Lucky Spin prizes and the spin's price.
5. What a Rebirth resets and keeps, the current costs, and the bar's prize steps.

## 1. Rebirth on cash in hand
- **Costs** (`Company` FRANCHISE / `FranchiseCost`): 150K, 600M, 25B, 150B, 1T, 4T, 10T, then ×3 per Rebirth (30T, 90T…).
  - Update the Rebirth step texts in Config.
  - `FranchiseCostOld` stays for history.
- **Condition (server, RebirthService `franchise`).** All three must hold:
  1. `Money ≥ cost`;
  2. `RunEarned ≥ cost`;
  3. the zone's last building is built (as today).
  - **`RunEarned` counts:**
    - contract pay;
    - rent, online and offline;
    - Road and achievement cash;
    - mission cash;
    - Robux cash packs;
    - Gem Shop Cash Bag / Cash Safe;
    - the head start.
  - **It does NOT count:**
    - cash received in a trade (`TradeService`: `toSt.data.Money +=` must not touch `RunEarned`);
    - money from selling materials (they still give cash).
  - Check every `addMoney` call site and decide which side it is on. List them in the change log.
- **On Rebirth:**
  - spend the cost: the new run starts as today, with start money + 1% of the cost paid + the Head Start perk;
  - Stars = 3 + 2·n + 1 per doubling, where the doubling is counted on `min(Money, RunEarned) / cost`;
  - reset `RunBest` and `RebCredit`.
- **The bar.**
  - progress = `min(Money + RebCredit, RunEarned + RebCredit) / cost`, clamped to 0..1;
  - store `RunBest` = the highest progress reached this run.
  - The prize steps are paid when `RunBest` passes them, once per run. The new prizes have no crates:

    | Step | Prize |
    |---|---|
    | 1% | 3 min of IncomePerMin in cash |
    | 5% | 10 Gems |
    | 10% | 15 Gems |
    | 25% | 20 Gems |
    | 50% | 40 Gems |
    | 75% | 30 Gems |

  - Text: "Rebirth needs $X in cash — you have $Y". The ETA "≈ N min" comes from the current income per minute.
  - The HUD REBIRTH dot uses the same condition.
- **Saving warning (client, every buy button).**
  - When: once the zone's last building is built, a purchase costing ≥ 5% of the current Rebirth cost.
  - It asks: "Saving for Rebirth: this sets it back by ≈ N min. Buy anyway?" N = price / income per minute. Add a
    "don't ask again this run" checkbox.
  - AUTO BUY BEST pauses in this state ("PAUSED — saving for Rebirth", tap to resume).
- **Migration (EconV < 4 → 4).** Players in the middle of a run get `RebCredit = min(0.95, old bar %) × v5 cost` of their
  next Rebirth.
  - The credit counts in both sums, and is shown on the bar as "saved before the update".
  - It is consumed by the Rebirth and can't be spent on anything else.
  - Built-ever buildings stay open (as in v4).

## 2. Free crates ONLY from missions
- **Remove:**
  - the free Supply Crate every 6 contracts;
  - the Builder's Crate drop on contracts (~3%, ×2 with Lucky Builder);
  - the crates on the Rebirth bar (now the prizes in section 1);
  - every other free crate the export finds.
- **Keep** the tutorial's first Supply Crate (bought with the tutorial's money).
- **Daily Crate:** all 3 daily missions claimed → 1 Supply Crate of the player's zone, once a day.
- **Builder's Order:** a 4th card in Daily Missions with a progress bar. Build N contracts today → 1 Builder's Crate,
  once a day.
  - N = 100 (Town) / 75 (Suburbs) / 55 (Downtown).
  - The zone is the one of the best contract unlocked; N is fixed when the day starts.
- **Golden Order:** a weekly card that resets Monday 00:00 UTC. Build N contracts this week AND claim the daily set on 6
  of the 7 days → 1 Golden Crate, once a week.
  - N = 480 / 365 / 260, taken from the zone at the start of the week.
- **Road crates, once per account:**

  | Road step | Crate |
  |---|---|
  | Hire 2 workers | Builder's |
  | Build the Garage | Supply |
  | Build the Corner Shop | Supply |
  | Rebirth 1 | Builder's |
  | Rebirth 2 | Golden |

- **Crate cards, "How you get it":**
  - Supply: "Cash · the Daily Crate";
  - Builder's: "200 Gems · Builder's Order (daily)";
  - Golden: "750 Gems · Golden Order (weekly)".
- **No-paid-random-items countries:** the same missions. Bought crates work there as today (X-ray).

## 3. Suburbs ×2 work
Multiply the work of the 5 Suburbs contracts (Villa, Warehouse, Apartments, Luxury Villa, Distribution Center) by 2.
Their rewards stay the same.

## 4. Road and achievement cash
Scale every Road step's cash so that each run's total stays ~8% of its Rebirth:

| Zone | v4 cash × |
|---|---|
| Town | 6 |
| Suburbs | 2.4 |
| Downtown run 3 | 1.25 |
| later | 1 |

Achievements worth ≤ 10K (divided by 6 in v4) go back to their old values.

## 5. The new Empire Road
- Build it as written in section 5b below: the tutorial unchanged, Chapter 1 Town, Chapter 2 Suburbs, Chapter 3
  Downtown, then the per-Rebirth steps.
- Map every step to an existing stat, or add the stat.
- Cash per step: the chapter's total split over its steps. Gems 5–25 per step.
- **Migration:** players are placed at the first step they haven't done yet. Steps already done are ticked WITHOUT any
  reward (no crate twice).

## 5b. The new Empire Road, step by step (recipe_v5.md §8)
**Rules:**
- Each chapter ends with "Save $X → Rebirth".
- **Cash:** each chapter's steps share ~8% of that run's Rebirth, more for the bigger steps.
- **Gems:** 5–25 per step.
- **Stats:** map each step to an existing stat (`Workers`, `MachinesOwned`, `GearTier`, `Completed`, contract built,
  property count, department level, Index, trade-ups, Star Shop, helmet, Rebirths…) or add the stat.
- **Crates:** only the 5 steps marked [crate].

**Tutorial:** the 7 steps of today, unchanged.

**Chapter 1, Town (~12K cash in total):**
1. Build the Shed.
2. Hire 2 workers [crate: Builder's].
3. Build the Garage [crate: Supply].
4. Buy your first upgrade (any department level 1).
5. Build the House.
6. Buy your first property.
7. Finish today's 3 daily missions.
8. Build the Corner Shop [crate: Supply].
9. Buy the Lifting Belt (gear 3).
10. Save $150K → Rebirth 1 [crate: Builder's].

**Chapter 2, Suburbs (~48M):**
1. Build the Villa.
2. Buy the Concrete Mixer.
3. A crew of 4.
4. Any department at level 5.
5. Build the Warehouse.
6. Finish a Builder's Order.
7. Your first trade-up (10 → 1).
8. Build the Apartments.
9. Own 3 kinds of property.
10. Build the Luxury Villa.
11. Complete one rarity in the Index.
12. Build the Distribution Center.
13. Save $600M → Rebirth 2 [crate: Golden].

**Chapter 3, Downtown (~2B):**
1. Build the Office.
2. Builder's Helmet I.
3. Buy the Crane.
4. Build the Hotel.
5. Buy your first Star Shop perk.
6. Finish a Golden Order.
7. Save $25B → Rebirth 3.

**After that, every Rebirth:**
1. Build the new building (Skyscraper at R3, HQ at R4, Spire at R5).
2. The next Builder's Helmet tier.
3. Save $<cost> → Rebirth N. Cash = 8% of that Rebirth.

**Migration:** each player starts at the first step he hasn't done yet. Steps already done are ticked WITHOUT any reward,
no crate either.

## 6. The new hammers and crates (SETS_V1)
- **Pirate Cove odds:** Kraken King 0.1% → **0.004%**; Treasure Chest 5.9% → 5.996%.
- **Luck in the set crates** follows the same rules as the other crates: from Legendary up, and on Secret / Divine at most
  ×3, then × Secret Hunter.
- **Prices:**
  - `crate_pirate` and `crate_temple`: 149 → **199 R$** (still 600 Gems).
  - **Legends Crate on Gems: 2,500 → 12,000 Gems**; on Robux it stays 299 / 3 for 799. At 2,500 Gems a Mythic would cost
    ~11K Gems (from Golden ~58K) and the Mythics coming in would double.
  - Pirate Cove description: "One of the 4 pirate hammers, Rare to Divine (Kraken King 1 in 25,000)."
- **Collection bonus:**
  - owning the 3 lower hammers of a set gives +0.05 luck (like an Index rarity);
  - owning all 4 gives a title: "Pirate King" / "Temple Guardian" / "Legend";
  - show it in the Index.
- They stay "coming soon" until the owner opens them.

## 6b. EXCLUSIVE_V2 → Option A (decided; recipe_v5.md §5.3)
**Why.** EXCLUSIVE_V2 (your earlier change) made Exclusive the top power (×256) and sold it guaranteed: the Exclusive
Crate at 999 R$ and the Exclusive of the Day at 1499 R$.
- The strongest hammer was ~6,000× cheaper than a Divine (~6.2M R$ through Golden Crates). That kills the Divine / Secret
  market.
- A payer with one reaches Rebirth 5 in 2 h 07 instead of 5 h 44.

**Do:**
- Exclusive stays the rarest *collectible*: badge, the top Index section, its own effects and trail, Robux only.
- **Its power is ladder power.** Royal Crown, Ghost and Rainbow Prism get Mythic power (×32), cooldown and level costs.
  Thunderclap ("1 in ???") gets Secret (×64).
- `Hammers.Power`, the cooldown and the level costs use that ladder rarity for every `ExclusiveR` hammer.
- Divine stays the strongest hammer of the game.
- Prices stay: Exclusive Crate 999 / 3 for 2699, Exclusive of the Day 1499. The other sources (Golden 1 in 100,000,
  Legends 1 in 5,000, the Lucky Spin 1 in 10,000) stay.
- Every text that says "x256" now says "Mythic power" (Thunderclap: "Secret power"): Store, Shop, crate cards, Index,
  product descriptions in Config.Store.
- **Owners of an Exclusive** keep it; it now builds with Mythic / Secret power.

**Verify:**
- In Play, equip a Royal Crown and a Mythic of the same level: the same build power, the same cooldown.
- The Thunderclap equals a Secret.
- The Inventory card shows that power.
- (Option B is only if the owner says so: Exclusive ×256 never sold guaranteed. Exclusive Crate odds 75 Legendary /
  22 Mythic / 2.9 Secret / 0.1 Exclusive at 399 / 3 for 999, and no Exclusive of the Day.)

## 7. Nothing else changes
- The passes, the other products and their prices stay the same.
- The Gem prices stay the same.
- The Hammers of the Day stay on Gems only.

## 8. VERIFY after implementing (all of them; tell the owner each result)
Use Studio Play with CE_Debug: give cash / Gems / contracts, set the Rebirth, jump time. For the weekly checks, fake the
week with a debug offset.
1. **Rebirth refused** with Money = cost − 1, and with Money = cost but RunEarned < cost (cash received through the
   Studio test trade partner). **Accepted** at both ≥ cost. Money after = start + 1% of the cost (+ Head Start). Next cost
   = the table's.
2. **Trades and materials don't move the bar:** receiving 1B cash in a trade and selling 100 Diamonds leaves the bar %
   unchanged.
3. **Bar prizes:**
   - go to 52% → the 1/5/10/25/50% prizes are paid;
   - spend to 20%, climb back to 52% → nothing paid twice;
   - reach 75% → 30 Gems.
4. **No crate from playing:** 50 contracts in a row → the crate inventory unchanged (only mission crates).
5. **Daily Crate** once a day; **Builder's Order** at exactly N contracts (Town 100) and not again that day;
   **Golden Order** needs both the contracts and 6 daily sets, once per week, and resets Monday.
6. **Road crates** given once. Replaying the condition (hire again, a new Garage after a Rebirth) gives nothing.
7. **Saving warning** appears only after the zone's top building, and only for buys ≥ 5% of the cost. AUTO BUY BEST pauses.
8. **Suburbs:** the first Villa build takes ~2× the v4 time for the same player.
9. **Migration** on a copy of a v4 save at 80% of R2: after loading, the bar shows 80% (credit = 0.8 × 600M). Rebirth
   works when cash + credit ≥ cost. Road position mapped, no rewards given twice.
10. **Set crates** (temporarily un-soon them in Play only):
    - 20,000 Pirate Cove rolls on the server with no luck → Kraken King 0–3 times (expected 0.8);
    - with luck ×3 the Divine stays ≤ ×3;
    - the Legends Crate shows 12,000 Gems and 299 R$.

    Do not leave them open.
11. **Gem loops:** the Lucky Spin's average Gem prize < its Gem price; nothing turns cash into Gems; Gems can't be
    traded.
12. **No-paid-random-items policy** switched on: missions give their crates, nothing is sold that shouldn't be.
13. **The whole game still works:**
    - the tutorial from a fresh profile to Rebirth 1;
    - every window opens with a clean console;
    - after stopping: Workspace = Map / Terrain / Camera, and HttpEnabled = false.
14. **Exclusive (section 6b):**
    - a Royal Crown builds exactly like a Mythic of the same level, and a Thunderclap like a Secret;
    - no text in the game says "x256".
15. **Every new number shows right in the game:**
    - the Rebirth window shows the costs (150K / 600M / 25B…) and "Rebirth needs $X in cash";
    - the crate cards show "how you get it";
    - the Daily Missions show the Builder's Order and Golden Order cards.
16. Write the results in `roblox/ECON_V5_STUDIO.md`, push, and tell the owner he can publish.

## 9. Simulator data behind the numbers
`tools/econ/`:
- `check11_cash.py`: cash vs earned;
- `v5.py`: costs, missions, Road crates;
- `v5_checks.py`: pacing, loop per run, naive players, days;
- `v5_value.py`: missions vs Gems;
- `v5_market.py`: the hammer market;
- `v5_gems.py`: the Gem economy.

Results are in `recipe_v5.md`.
