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

## Step 1 — six things the owner asked for (do these first)

Order of the work: Step 0, then **3.0 (the data export, right away)**, Step 1 (fixes), Step 2 (new hammers and crates), and Step 3.2 (Economy v5) only when the owner confirms `tools/econ/recipe_v5.md`.
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

6. **The LUCKY HOUR banner and the bottom-left list** (the owner, 15:03):
   - The clover must not be an emoji. Use the game's rendered clover (Icons `up_luck`, dark outline) on a white round
     badge, so it shows on the green.
   - The banner stays until the player taps it, or 30 s, then disappears.
   - While it lasts, the Lucky Hour sits in the bottom-left list with its time left. The 2x Luck potion has the clover
     there too.
   - Every timed line in that list counts down live, every second, and disappears when it ends.
   - Patch ready: `roblox/patch_luck_hud.lua` (run in Edit; it finds the HUD module holding `LuckPill`). If a string
     doesn't match the current HUD, apply the same change by hand.
   - Test in Play:
     - Lucky Hour: set `ReplicatedStorage:SetAttribute("LuckyHourEnds", workspace:GetServerTimeNow() + 120)` from the
       server.
     - Potion: give the luck boost with CE_Debug.
     - Check that the banner shows, then hides after 30 s or a tap.
     - Check that the list line counts down second by second and disappears at 0.

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

## Step 3 — Economy v5 (the owner's decisions of 14:06 – 14:29)

**Who does what:**
- **The Mac chat:** designs Economy v5 and proves it with the simulator (`tools/econ/`). It writes everything, number by
  number, into `tools/econ/recipe_v5.md` (Romanian, in the style of `recipe.md`).
- **You (PC chat):**
  1. right away, the data export in 3.0;
  2. after Steps 1 and 2, when the owner says "start Economy v5", implement `recipe_v5.md` exactly as written (3.2).
     Do not invent other numbers. The game is live: nothing changes without the owner's explicit confirmation.

### 3.0 Right away (after Step 0, ~10 min): export the live game's data for the simulator
Write `tools/econ/game_dump_v4.md` with exact values, and next to each the script and line where it lives. Push it.
1. `Config.Road`: every step in order. Give its title, stat, target, cash, gems, any other reward, its place and which
   steps are the tutorial (`Config.TutorialSteps`).
2. `Config.DailyMissions`: how many a day, how they are picked, every target and reward (cash / XP / gems / other).
   Also streak rewards, `PlaytimeGifts`, Achievements (target + reward), Index rewards and codes.
3. **Every place a crate is given without paying.** Search Main, HammerService, RebirthService, CompanyService and
   SpinUI / Spin for `addCrate`, `Crates[`, `open_crate`, `crate =`, `RunChests`, `free`, and for the tutorial.
   - For each: which crate, how often (every N contracts, % per contract, per bar step…), and for whom.
   - Include the special rules for countries where paid random items are not allowed.
4. Gems: every source (per hit, per contract, missions, streak, gifts, achievements, Index…) and every Gem Shop item
   with its price.
5. The Rebirth: what it resets and what it keeps (money, gear, Strength, workers, machines, departments, properties,
   helmet, hammers, Stars, materials, blueprints…). Also the current costs and the bar's prize steps.

### 3.1 The owner's decisions (fixed; `recipe_v5.md` gives the numbers)
1. **The Rebirth needs CASH IN HAND, not the money earned this run.**
   - You can rebirth when your cash ≥ the cost (and the zone's last building is built, as today). The cash is spent:
     you start the new run with the head start, as today.
   - The Rebirth bar shows cash in hand / cost.
   - The prize steps (1/5/10/25/50/75%) are paid on the HIGHEST % reached this run. The bar can go down when you buy;
     a prize is never paid twice.
   - The "≈ X min" estimate comes from the current income.
   - Text on the bar: "Rebirth needs $X in cash. Upgrades that pay back still win — then save up!"
2. **The Rebirth gets harder.** The owner finds Economy v4 too easy (Rebirth 1 after ~17 min; most Roblox simulators:
   30–60 min). The new costs and the first run's retuned content are in `recipe_v5.md`.
3. **No more free crates while just playing. Free crates come ONLY as rewards of specific missions.**
   - Remove:
     - the free Supply Crate every N contracts;
     - the Builder's Crate that drops on contracts (~3%, ×2 with Lucky Builder);
     - the crates on the Rebirth bar's prize steps (they become Gems / cash; numbers in the recipe);
     - any other free crate the export in 3.0 finds.
   - The tutorial's first Supply Crate stays (it is bought, with the tutorial's money).
   - **The Gem crates** (Builder's 200 Gems, Golden 750 Gems) are given ONLY by specific missions. Each such mission
     takes about as much play as farming the crate's Gems would. There are daily / weekly limits, so free players can't
     flood the hammer market.
   - The exact missions, targets, rewards and limits are in `recipe_v5.md`. The paid crates (Gems / Robux / Lucky Spin)
     don't change.
   - **Countries where paid random items are not allowed:** today every crate is free there. They get the same
     missions (a free path), plus what the recipe says. Check it with the policy switch, as before.
4. **The Empire Road and the core loop are rethought** so they make sense from the tutorial to the late game:
   contracts → money → upgrades / crew / machines / properties → save cash → Rebirth, with missions, crates, hammers and
   trading around it. The new Road (every step, target and reward) is in `recipe_v5.md`.

### 3.2 When the owner confirms `recipe_v5.md`: how to implement
- Backups first: `ServerStorage.Backup_pre_econ5` with every script you change.
- Implement exactly the recipe. Mark every edit `ECONOMY_V5`. Keep `ECON_V4_STUDIO.md`'s style of change log as
  `roblox/ECON_V5_STUDIO.md`.
- **Migration of current saves:** follow the recipe's migration section. Players in the middle of a run must not lose
  progress, and Road indexes must map to the new Road.
- **UI:**
  - the Rebirth window (cash bar, texts, prize steps on the highest %);
  - the missions windows (daily / weekly, with the crate rewards);
  - crate cards: "how you get it" says "Missions" for the free path;
  - the Road panel.
- **Test in Play** (CE_Debug):
  - Rebirth refused under the cost, accepted at it, cash spent;
  - bar prizes paid once, on the highest %;
  - no crate from contracts in 30+ contracts;
  - every mission crate given once per its period;
  - the Road from step 1 to the first Rebirth;
  - migration of a v4 save;
  - the restricted-country path.
- Then the usual: stop Play, Workspace = Map / Terrain / Camera, HttpEnabled = false, and tell the owner he can publish.

### 3.3 Data so far (check 11, `tools/econ/check11_cash.py`)
Economy v4 costs (25K, 250M, 20B, 150B, 800B). "saver" = a player who stops buying what won't pay back before his
Rebirth. Minutes of play to each Rebirth, mean of 5 seeds:

| Player | Rule | R1 | R2 | R3 | R4 | R5 |
|---|---|---|---|---|---|---|
| active | earned this run (v4) | 17 min | 49 min | 2 h 17 | 4 h 42 | 8 h 49 |
| active | cash, keeps buying | 34 min | 1 h 11 | 2 h 53 | 5 h 30 | 10 h 11 |
| active | cash, saver | 21 min | 59 min | 2 h 44 | 5 h 29 | 10 h 18 |
| casual | earned | 22 min | 60 min | 2 h 52 | 5 h 52 | 11 h 06 |
| casual | cash, saver | 27 min | 1 h 11 | 3 h 04 | 5 h 56 | 11 h 04 |
| payer | earned | 8 min | 25 min | 1 h 05 | 2 h 03 | 3 h 57 |
| payer | cash, saver | 10 min | 30 min | 1 h 19 | 2 h 28 | 5 h 18 |
| whale | earned | 6 min | 17 min | 40 min | 1 h 11 | 2 h 17 |
| whale | cash, saver | 7 min | 19 min | 49 min | 1 h 27 | 2 h 50 |

- Players keep buying upgrades every run, as the owner said. Runs get ~15–35% longer; the saving happens at the end.
- Multiplying every cost barely moves Rebirth 1 but stretches the late game (×2: active R1 26 min, R5 16 h 45).
  Rebirth 1 is bound by the Town's contracts and the Corner Shop gate.
- **My Toll Farm**: the Rebirth needs cash and wipes ONLY the cash; cars and upgrades stay. The first one costs 15,000
  cash and gives ×2, then ×3, ×5 … up to ×50 at Rebirth 10. Sources: earnaldo.com/blog/my-toll-farm-beginner-guide,
  allthings.how.

## Where things are
| What | Where |
|---|---|
| Economy v4 change log, tests, owner's to-do | `roblox/ECON_V4_STUDIO.md` |
| Economy recipe | `tools/econ/recipe.md` |
| Store ids | `roblox/store_ids.md` |
| Build-effects plan (later) | `roblox/NEXT_build_fx.md` |
| Hammer brief / spec / Blender builder / Roblox builder | `hammers/hammers.md`, `hammers/spec.py`, `hammers/bl_build.py`, `roblox/hammer_build.lua` |
| Blender pipeline installer | `blender/setup.py` (assets in `blender/assets/`) |
