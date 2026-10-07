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

## Step 3 — Economy v5
Everything to do is in **`ECONOMY_V5_PC.md`**: the work list, the exact numbers and the checks. The reasoning and the
simulator results are in `tools/econ/recipe_v5.md`.

## Where things are
| What | Where |
|---|---|
| Economy v4 change log, tests, owner's to-do | `roblox/ECON_V4_STUDIO.md` |
| Economy recipe | `tools/econ/recipe.md` |
| Store ids | `roblox/store_ids.md` |
| Build-effects plan (later) | `roblox/NEXT_build_fx.md` |
| Hammer brief / spec / Blender builder / Roblox builder | `hammers/hammers.md`, `hammers/spec.py`, `hammers/bl_build.py`, `roblox/hammer_build.lua` |
| Blender pipeline installer | `blender/setup.py` (assets in `blender/assets/`) |
