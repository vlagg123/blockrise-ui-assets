# BlockRise Empire — hand-off to the Windows PC (2026-10-07, 13:50 Bucharest)

The previous session ran on the owner's Mac (Roblox Studio + Blender through local MCP). The owner moved to the Windows
PC and the old chat could not be linked to it, so a new task continues here. **Read this file first, then
`roblox/ECON_V4_STUDIO.md`.** Talk to the owner in Romanian.

## Standing rules (from the owner, still in force)
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

## Step 0 — check the move worked
1. **Studio:** open **BlockRise Empire** on the PC. The owner pressed Save on the Mac before moving. Check that the
   saved version is the newest:
   - `ReplicatedStorage.Shared.Config` source contains `ECONOMY_V4` and `CAR_PRODUCTS`;
   - `ServerStorage` has `Backup_pre_econ4` and `Backup_pre_carproducts`;
   - `ServerStorage.Hammers` has 40 tools (`Hammer_1`..`Hammer_15`, `Hammer_<key>`).

   If any of these is missing, STOP and tell the owner: the Save didn't reach Roblox.
2. **Blender** (5.2 on the Mac; check the version on the PC). The whole icon / hammer pipeline is in this repo. Install it
   with:
   ```python
   import urllib.request
   exec(urllib.request.urlopen("https://raw.githubusercontent.com/vlagg123/blockrise-ui-assets/main/blender/setup.py").read())
   ```
   It downloads into `~/.local/share/blockrise_icons`:
   - the scripts (`src/`): icons, icons2, icons3, items, postnp, robux, gear, zonecrates, bl_build, hammer_export;
   - the studio HDRI and the Poly Haven textures.

   It also appends the scenes "BlockRise Icons" and "BR Library" and puts `src` on `sys.path`. To check, render one
   existing hammer with `import bl_build as B; B.render(tiers=[37])` (the crown), then compare it with the Store picture
   (rbxassetid 126956308355764).

## Step 1 — five things the owner asked for (do these first)

Order of the work: Step 0, then **3.0 (the data export, right away)**, Step 1 (fixes), Step 2 (new hammers and crates), and Step 3 (Economy v5) only when the owner confirms `tools/econ/recipe_v5.md`.
1. **Tutorial ring at GO (PLACES → My Property)** sits lower and wider than the button.
   - Cause: `LocationsUI` takes the window's scale from `go.AbsoluteSize.Y / 50`, but the tile buttons are 47 px tall
     now.
   - Fix: `roblox/patch_tutring.lua`, ready to run in Edit. It measures the scale on a 100 px reference frame.
   - Test: with the tutorial at its last step, open Places and check the ring's Absolute rect against GO's.
2. **Every hammer hits twice, very fast, on one click** (should be one swing).
   - Look at the Client script (`StarterPlayer.StarterPlayerScripts.Client`): `SW.swing`, `doHit`, the `SW.queued`
     re-swing, and every place that calls `doHit` (Tool.Activated, input handlers, Auto Build / Auto Train). Also look
     at `Client.HammerSwing`, which `_G.__CE_Swing` plays.
   - Hypothesis: one click reaches `doHit` twice. The second call lands inside the cooldown, is queued, and swings
     again right after the first. Other suspects: the Economy v4 Auto Train ×2 change in Main, and HitFX echoing back
     to yourself.
   - Fix it so one click = one swing (a held click / spam still keeps the rhythm). Test several styles: chop (rusty),
     smash (titanium), double (gold — its own two taps are by design), twirl, sweep, rise.
3. **Crate odds tooltip** (`HammersUI`, the small `OddsTip` box over a crate card's rarity bar).
   - Problem: each line shows `oneIn(v) .. "  ·  " .. shortPct(v)`, and the next card covers its right part.
   - The owner wants only "1 in X": drop the `"  ·  " .. shortPct(...)` part.
   - Make the tip narrower: Size 268 → ~236, text box 150 → ~110.
   - Keep it above the neighbouring card: raise the card's ZIndex while the tip is open, or parent the tip higher.
   - The % stays in the crate's big window (Roblox's paid-random-items rule: the odds are shown before buying).

4. **"Two crew members appeared that I don't remember buying"** — reported after the tutorial, the playtime gifts and
   the daily missions.
   - Probable cause (from the repo's `patch_tutorial_v4.lua`): the tutorial itself buys both, and tops up exactly the
     money for them.
     - Step 5 "Your first machine" buys the Mini Excavator, which builds on its own.
     - Step 6 "Hire a worker" buys one Laborer. In the tutorial `Hire` refuses a second worker.
   - Confirm it in the CURRENT Studio code. Look for every code path that adds to `d.Workers` (Main `Hire`, the
     tutorial, `PlaytimeGifts`, `DailyMissions`, Road rewards, the Starter Pack, Rush Crew, Big Crew, the Economy v4
     migration). Also confirm that no gift or mission gives a worker.
   - Tell the owner which two they are. If it is TWO workers (people) rather than a worker and the excavator, it's a bug:
     find it and fix it.
5. **Holding Shift to run kills the mouse wheel**: no camera zoom in or out, no scrolling in the menus while sprinting.
   - Find the sprint code (`script_grep` for `LeftShift` / `Sprint`, look at ContextActionService binds, and at what
     changes the camera zoom limits or the MouseBehavior while running).
   - Likely causes:
     - a bind that sinks input;
     - the zoom limits locked while sprinting;
     - Roblox turning Shift+wheel into a sideways scroll. If so, sprint on a key the wheel doesn't care about, or read
       the wheel ourselves while Shift is down: `InputChanged` → `MouseWheel` → camera zoom / `CanvasPosition` of the
       ScrollingFrame under the mouse.
   - Fix it so the wheel works the same whether you run or not.

## Step 2 — the owner's request of 13:35 (verbatim)
> "Sa mai faci niste ciocane exlcusive si niste crate-uri ceva cu colectii si inca un crate exclusive. Sa le faci in
> blender si sa le adaugi in joc si in meniu cu coming soon si dupa ce termini tot, dupa ce testezi ca se vad in joc si
> ca tot jocul merge corect, sa imi dai lista completa cu pass uri si iteme gen alea care costa robuxi ca sa le modific
> pe toate. Poate generezi niste imagini noi mai frumoase pentru thumbnail-urile pass-urilor de pe pagina roblox ca
> acuma sunt cam laim cu stelutele alea si sunt putin cam neclare sau nuj pareau washed putin. Poate le faci sa arate
> mai premium si odata cu lista completa cu nume descriere si robuxi imi dai si fisierul cu imaginile noi generate"

Plan:
1. **New exclusive hammers** for a second exclusive crate, plus themed **collection crates**, each with its own set of
   hammers.
   - Design each hammer in `hammers/hammers.md` (style rules at the top: chunky cartoon, readable at 64 px, one strong
     silhouette + one signature colour).
   - Add it to `hammers/spec.py` (`build_new`, `new(key, name, desc)`; new materials go in `PALETTE`).
   - Run `python3 hammers/spec.py` to regenerate `spec.json`, then push. Studio and Blender both read the raw GitHub
     URL.
2. **Roblox models:** run `roblox/hammer_build.lua` in Edit with
   `_G.__HB = { tiers = {41, 42, ...}, url = "<raw spec.json>", reload = true }`. It turns HttpEnabled on only for the
   download and then restores it; check that it's false afterwards. The output is `ServerStorage.Hammers.Hammer_<key>`.
3. **Icons:** in Blender run `bl_build.render(tiers=[...])`, which writes `~/.local/share/blockrise_icons/hammers/NN_key.png`
   (256 px, no sparkles).
   - Crate pictures come from `src/zonecrates.py`, the same look as the six crates in `upl_crates`.
   - Upload: from Blender, serve the files on `http://localhost:8765/` (a `ThreadingHTTPServer` in
     `bpy.app.driver_namespace["br_srv"]`, see the earlier sessions), then use Studio `upload_image` on those URLs.
   - New pictures go in `Hammers` (the `HAMMER_IMG` table at the end).
4. **In the game as COMING SOON:**
   - hammers: `Hammers.List` entries with `exclusive = true, soon = true`;
   - crates: `Hammers.Crates` entries with `soon = true`;
   - check that the Shop / Store / Index menus draw them as COMING SOON and can't buy or open them.
   - Then test that the whole game works (Play, console clean, open the main windows from the server).
5. **The complete list** of every game pass and developer product: name, description, Robux price, including the new
   ones and those with id 0 that the owner still has to create (see `roblox/store_ids.md`, `roblox/ECON_V4_STUDIO.md`
   "Left for the owner", and `Config.Store`).
6. **New premium pass thumbnails** for the Roblox game page: rendered in Blender, sharp, rich colours, no stars or
   sparkles, not washed out. 512×512 for passes. Deliver them as a zip (SendUserFile) together with the list.

## Step 3 — Economy v5 (designed and simulated by the Mac chat; you implement it when the owner says so)

The design, every number and the reasoning are in **`tools/econ/recipe_v5.md`** (Romanian). This step is the exact work
list. Order:
1. 3.0, if not done yet.
2. Implement 3.1 – 3.7 when the owner confirms.
3. Run EVERY check in 3.8 and report each one to the owner (in Romanian) with its result.

Do not change any number on your own. If something in the live code makes a rule impossible, stop and tell the owner.
**Backups first:** `ServerStorage.Backup_pre_econ5` with every script you touch. Mark every edit `ECONOMY_V5`, and write
the change log in `roblox/ECON_V5_STUDIO.md` (the same style as `ECON_V4_STUDIO.md`).

### 3.0 Export the live game's data (if not done yet): `tools/econ/game_dump_v4.md`, pushed
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

### 3.1 Rebirth on cash in hand
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

### 3.2 Free crates ONLY from missions
- **Remove:**
  - the free Supply Crate every 6 contracts;
  - the Builder's Crate drop on contracts (~3%, ×2 with Lucky Builder);
  - the crates on the Rebirth bar (now the prizes in 3.1);
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

### 3.3 Suburbs ×2 work
Multiply the work of the 5 Suburbs contracts (Villa, Warehouse, Apartments, Luxury Villa, Distribution Center) by 2.
Their rewards stay the same.

### 3.4 Road and achievement cash
Scale every Road step's cash so that each run's total stays ~8% of its Rebirth:

| Zone | v4 cash × |
|---|---|
| Town | 6 |
| Suburbs | 2.4 |
| Downtown run 3 | 1.25 |
| later | 1 |

Achievements worth ≤ 10K (divided by 6 in v4) go back to their old values.

### 3.5 The new Empire Road
- Build it as written in `recipe_v5.md` §8: the tutorial unchanged, Chapter 1 Town, Chapter 2 Suburbs, Chapter 3
  Downtown, then the per-Rebirth steps.
- Map every step to an existing stat, or add the stat.
- Cash per step: the chapter's total split over its steps. Gems 5–25 per step.
- **Migration:** players are placed at the first step they haven't done yet. Steps already done are ticked WITHOUT any
  reward (no crate twice).

### 3.6 The new hammers and crates (SETS_V1)
- **Pirate Cove odds:** Kraken King 0.1% → **0.004%**; Treasure Chest 5.9% → 5.996%.
- **Luck in the set crates** follows the same rules as the other crates: from Legendary up, and on Secret / Divine at most
  ×3, then × Secret Hunter.
- **Prices:** `crate_pirate` and `crate_temple` 149 → **199 R$** (still 600 Gems).
  - Pirate Cove description: "One of the 4 pirate hammers, Rare to Divine (Kraken King 1 in 25,000)."
- **Collection bonus:**
  - owning the 3 lower hammers of a set gives +0.05 luck (like an Index rarity);
  - owning all 4 gives a title: "Pirate King" / "Temple Guardian" / "Legend";
  - show it in the Index.
- They stay "coming soon" until the owner opens them.

### 3.6b EXCLUSIVE_V2 — apply the option the owner picks (recipe_v5.md §5.3)
EXCLUSIVE_V2 made Exclusive the top power (×256), sold guaranteed: the Exclusive Crate at 999 R$ and the Exclusive of the
Day at 1499 R$. The strongest hammer of the game would be ~6,000× cheaper than a Divine (~6.2M R$ through Golden Crates),
which kills the Divine / Secret market. A payer with one reaches Rebirth 5 in 2 h 07 instead of 5 h 44.
- **Option A (recommended):**
  - Exclusive stays the rarest *collectible*: badge, the top Index section, its own effects, Robux only.
  - Its power is its ladder power: Royal Crown / Ghost / Rainbow Prism = Mythic (×32); Thunderclap = Secret (×64).
  - `Hammers.Power` uses the ladder rarity for `ExclusiveR` hammers. The cooldown and the level costs follow too.
  - Divine stays the strongest.
  - Prices stay: Exclusive Crate 999 / 3 for 2699, Exclusive of the Day 1499.
  - Texts: replace "x256" with "Mythic power" / "Secret power".
- **Option B:**
  - Exclusive stays ×256 but is never sold guaranteed.
  - The Exclusive Crate odds become 75 Legendary / 22 Mythic / 2.9 Secret / 0.1 Exclusive, at 399 / 3 for 999.
  - Remove the Exclusive of the Day (`hammer_exclusive`).
  - Golden 1 in 100,000, Legends 1 in 5,000 and the Lucky Spin 1 in 10,000 stay.
- **Verify:**
  - Power in the Inventory card equals the chosen rule.
  - Option A: a new Royal Crown builds exactly like a Mythic of the same level.
  - Option B: 10,000 server rolls of the Exclusive Crate give ~10 Exclusives.

### 3.7 Nothing else changes
- The passes, the other products and their prices stay the same.
- The Gem prices stay the same.
- The Hammers of the Day stay on Gems only.

### 3.8 VERIFY after implementing (all of them; tell the owner each result)
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
10. **Set crates** (temporarily un-soon them in Play only): 20,000 Pirate Cove rolls on the server with no luck →
    Kraken King 0–3 times (expected 0.8). With luck ×3 the Divine stays ≤ ×3. Do not leave them open.
11. **Gem loops:** the Lucky Spin's average Gem prize < its Gem price; nothing turns cash into Gems; Gems can't be
    traded.
12. **No-paid-random-items policy** switched on: missions give their crates, nothing is sold that shouldn't be.
13. **The whole game still works:**
    - the tutorial from a fresh profile to Rebirth 1;
    - every window opens with a clean console;
    - after stopping: Workspace = Map / Terrain / Camera, and HttpEnabled = false.
14. Write the results in `ECON_V5_STUDIO.md`, push, and tell the owner he can publish.

### 3.9 Simulator data behind the numbers
`tools/econ/`:
- `check11_cash.py`: cash vs earned;
- `v5.py`: costs, missions, Road crates;
- `v5_checks.py`: pacing, loop per run, naive players, days;
- `v5_value.py`: missions vs Gems;
- `v5_market.py`: the hammer market;
- `v5_gems.py`: the Gem economy.

Results are in `recipe_v5.md`.

## Where things are
| What | Where |
|---|---|
| Economy v4 change log, tests, owner's to-do | `roblox/ECON_V4_STUDIO.md` |
| Economy recipe | `tools/econ/recipe.md` |
| Store ids | `roblox/store_ids.md` |
| Build-effects plan (later) | `roblox/NEXT_build_fx.md` |
| Hammer brief / spec / Blender builder / Roblox builder | `hammers/hammers.md`, `hammers/spec.py`, `hammers/bl_build.py`, `roblox/hammer_build.lua` |
| Blender pipeline installer | `blender/setup.py` (assets in `blender/assets/`) |
