# BlockRise Empire: handoff for the next AI (2026-10-12)

You are taking over a LIVE Roblox game, built and maintained entirely through Roblox Studio (MCP tools). The owner is
**vlagg124** (Roblox user 4285033131). He speaks **Romanian**: always answer him in Romanian, short and clear. Read this
whole file before touching anything. Older notes: `roblox/HANDOFF_2026-10-11.md` (bug list + everything shipped
2026-10-11) and `roblox/AUDIT_2026-10-11.md` (first ad-campaign audit).

- Game: BlockRise Empire. PlaceId 93206782559935, UniverseId 10769362402.
- Repo: `vlagg123/blockrise-ui-assets` (notes in `roblox/`).
- DataStore: `BlockRise_v6`.

---

## 1. Rules you must follow (the owner's, non-negotiable)

1. **The game is LIVE. Never publish.** The owner presses Publish himself, then "Restart servers".
2. **Never reset player progress** (no DataStore bump, no wipe) unless the owner says so clearly and explicitly.
3. **Edit scripts only with Play stopped**, through `ScriptEditorService:UpdateSourceAsync`, using an exact, unique
   string replace and a `loadstring` compile check before saving. Never rewrite a whole script from memory.
4. **After every change**, all of these:
   - run Play and test the change;
   - read the console (only the Studio DataStore 403 warnings are normal);
   - stop Play;
   - check that Workspace contains only Map / Terrain / Camera;
   - check that `HttpService.HttpEnabled` is false;
   - check that ServerScriptService.Game.Main has no `DayOffset` attribute;
   - check that no test objects are left (name them `CE_*` and delete them).

   Only then tell the owner he can publish.
5. **Do not use the `screen_capture` tool** (the owner asked). Verify UI by measuring it: AbsolutePosition /
   AbsoluteSize, `TextFits`, `TextBounds`, overlap math. Ask the owner for a screenshot when you need his eyes.
6. Phone/tablet-only changes must not change the PC layout (test both).
7. Admins: 4285033131 (owner) and 2808108421 (his friend).
8. Commits end with the attribution lines the session gives you.

## 2. The owner's quality bar for UI / HUD (read twice)

The owner's words (2026-10-12): *"orice update pe partea de joc si mai ales UI trebuie sa fie perfect, testat sa arate
bine si sa fie centrat corespunzator si sa nu fie lipite chestiile, sa aiba un UI clar si perfect HUD-ul."*
(Every game update, and especially UI, must be perfect: tested, good-looking, properly centred, nothing stuck together,
a clear UI and a perfect HUD.)

The owner rejects anything that looks "aiurea" (off). For EVERY UI or game change:
- **Perfect on PC and on phone.** Test in the Studio device emulator (iPhone landscape, 750x361 viewport) and on PC.
  He tests in the emulator himself and reports anything that looks wrong.
- **Nothing overlapping, nothing touching.** Leave a clear gap between neighbours (hint line vs button, button vs hotbar,
  chips vs Roblox's top-bar buttons). Measure the gaps; the buttons pulse (scale 1.06), so leave room for that too.
- **Text fits and is centred.** `TextFits = true` for every label; one line where it should be one line; no word cut
  in half ("INVENTOR / Y" happened). Text must be **vertically centred on the button face**. The font Luckiest Guy
  (`T.chunky`) draws its capitals about 0.14 em above the middle of its line, so a "centred" line looks too high: move
  the line down by `round(TextSize * 0.14)` (UIKit's CHUNKY_DOWN does this on touch; the green NEXT button does it
  everywhere).
- **No tofu glyphs.** "✕" in GothamBold / Luckiest Guy shows as an empty box. Use plain "X" or an icon.
- **Phone layout respects Roblox's controls.** The bottom-left belongs to the thumbstick, the bottom-right to
  jump / HIT / sprint, the top-left to Roblox's menu / chat / voice buttons (`GuiService.TopbarInset`, about 208 px in
  the emulator). Windows open as high as possible on touch.
- **In Studio, `UI.touch()` follows `UserInputService.TouchEnabled`.** The emulator on a Mac keeps the keyboard, so
  without this rule the owner saw the PC layout. The live rule is unchanged (touch and no keyboard).
- When the owner points at something, fix exactly that, test it, then report in 2–4 short lines in Romanian.

## 3. What is live right now (published 2026-10-11 evening)

- **Phone HUD (PHONE_V3 / V3b):**
  - Hotbar: our own 44 px hotbar (Roblox's 60 px one is hidden on touch).
  - Top: the level bar (+5%) sits on the pills row next to the right column, with the boost lines under it.
  - Right column: CARS / PLACES.
  - Touch buttons: HIT button with the equipped hammer; the jump button sits above sprint.
  - Windows open from the very top; the top strip respects TopbarInset.
  - Drive controls stay inside the screen.
- **Title screen:** no PLAY button. At LOADING 100% everyone goes straight in. Pictures wait at most 4 s.
- **FIRST_MINUTE (new players):**
  - The Repair Fence starts by itself and the player is teleported to the site (`autoFirstJob` in Main). The first job needs half the work.
  - A free Supply Crate opens by itself after the first job's card.
  - **Tutorial, 7 steps:** fence, hire a worker, gloves, 10 tire reps, Mini Excavator, second job, visit property.
  - **End of the tutorial:** a Builder's Crate and 10 min of 2x Cash.
  - **Green NEXT button:** bottom centre; the next goal in one tap (a window, or a free trip). Shown in the tutorial and under Level 10 (`Config.RookieLevel`).
  - **Strength lock:** a building goal locked by Strength sends the player to train and shows the count.
  - **Garden Shed** needs 80 Strength (was 200: everybody stopped there).
- **Events every 20 min (EVENTS_20):**
  - Lucky Rush (x2 luck) and Cash Rush (x2 contract cash) take turns, 5 min each.
  - The HUD always shows the running event or the countdown to the next one; a toast comes 1 min before, and a banner when Cash Rush starts.
- **Crate reveal KEEP button (anti-autoclicker):**
  - It stays in its own place under the hammer and only moves if it would cover the OPEN button that was pressed: beside it, else under it, never over the hammer picture.
  - Tutorial crates don't move it.
- **Skip Build Animation pass:** offered during the build cinematic. The owner reports another sale today, so this
  moment converts. Keep it.

## 4. Open work, in priority order

### P0: must be done before any more ad money
1. **Teleport puts players ON the foundation, and the walls push them under the map** (owner, 2026-10-12, live).
   - Cause: LocationsUI.Go("site") stands 6 studs from the job's `WorkPoint`, toward the map centre; `autoFirstJob`
     does the same at 9 studs. That point is often inside the building's footprint. New walls spawn over the player,
     physics pushes them down, they fall into the void and respawn at the plaza.
   - Fix plan:
     - **Server (`acceptContract` in Main):** compute a stand point in FRONT of the plot, outside the footprint. Use
       `job:Center()`, `job.origin.LookVector`, and distance `max(job.size.X, job.size.Z)/2 + 7`, clamped to the site
       radius − 4. Ground it with a downward raycast that excludes characters and `Workspace.Constructions`. Publish
       it as `job.state:SetAttribute("StandPoint", …)`.
     - **Use StandPoint in three places:** `autoFirstJob`, `LocationsUI.Go("site")`, and the rookie auto-trip after
       "Accepted" (Client). The player faces the centre.
     - **Fall guard (Client):** if the player drops below the map, put them back on their site's StandPoint, or on
       the ground above them, or at Spawn. First measure the map's lowest walkable Y (do not guess it).
     - **Test:** all 4 Town sites (Site1–4 at x ±300, z ±70) and the Suburbs sites, with small (fence), medium (shed,
       garage) and big (house, villa) buildings; stand there through the wall stages.
2. **Funnel is mixed.** The new steps reused the old onboarding-funnel numbers, so Creator Hub shows old and new names
   together.
   - Move the new path to a separate custom funnel, e.g. `AnalyticsService:LogFunnelStepEvent(player, "Tutorial v8",
     nil, step, name)`, with the same steps: 1 Joined, 2 First hit, 3–9 tutorial steps 1–7, 10 Garden Shed, 11 Hire 2
     workers, 12 Brick Garage.
   - Code: `funnel()` in Main (with the `v8` flag) and `roadCheck` in Main.

### P1: before the €100 push
3. **Click → play loss on ads** (63 clicks → 9 attributed plays; Analytics shows ~15 new users in the same days, so
   attribution under-counts). Check, then fix:
   - **The experience page:**
     - The owner was given a new description: game idea in line 1, then free crates and events.
     - The first thumbnail should be the best ad creative, "LVL 1 → LVL 100" (CTR 1.8%).
   - **Age reach:**
     - The game's reach is "16+ and trusted friends" until it has 250 Highly Engaged Players in 60 days (it had 5). The Kids & Select fee of 1,000 R$ was paid 2026-10-09; the refund is around 2027-01-07 if it never qualifies.
     - The campaign targets "All players": 13–15 year olds can click but may not be able to join.
     - Check the Ads Manager targeting options and match them.
   - **Cold start:**
     - With 0 players online, every click starts a new server, and players see "Retrying" at join.
     - Check whether StreamingEnabled is on; consider it for faster joins on phones (test well).
4. **Town site capacity.** Only 4 Town sites per server, and MaxPlayers is 60.
   - Today's traffic is tiny, but a €100 push can fill a server with new players at once, and then "All town sites are busy".
   - Decide before spending: more Town sites, instanced first-job sites, or a smaller server size.
5. **Phone HUD final visual pass on a real phone.** The owner left this for last; do it with his screenshots.

### P2
6. "Retrying" at join: Roblox server cold start, partly mitigated by trimming the place. Keep an eye on it.
7. The owner once got "stuck in the sky" after pressing PLAY. It never reproduced; PLAY was removed afterwards. If it
   comes back: camera Scriptable left over, or CameraSubject not the humanoid. Add a camera guard.
8. Mid-tutorial old saves got the new tutorial (stat-based steps catch up; some get a free crate). Fine, just know it.

## 5. Data: where it is and what it said

Read the data yourself and connect the dots: ads → game page → join → funnel step → session length → D1.

- **Creator Hub** (the owner logs in himself in the Claude desktop app's built-in browser; never handle his password):
  - Analytics API:
    - Request: `POST https://apis.roblox.com/analytics-query-gateway/v1/metrics/resource/RESOURCE_TYPE_UNIVERSE/id/10769362402`, body
      `{resourceType, resourceId, query:{metric, granularity, breakdown, filter, startTime, endTime}}`; poll until done.
    - Metrics used: DailyActiveUsers, Visits, AverageSessionLengthMinutes, TotalSessionsEndedInBucket,
      FunnelStepTotalCount, FunnelUserStepCompletionRate, ForwardD1Retention, ErrorCount.
    - Breakdowns: Platform, Country, IsNewUser, FunnelStep, FunnelName.
  - Saves (read only): `GET https://apis.roblox.com/user/cloud/v2/universes/10769362402/data-stores/BlockRise_v6/scopes/global/entries/u_<userId>`.
  - Ads Manager: `https://create.roblox.com/advertise/manage?campaignId=de8dd44a-0542-475b-8be5-090c761eaa1e`.
- **Snapshot from the owner's phone, 2026-10-12 13:25 (data updated 11:00):**
  - **Campaign "BRE Engagement v1":** Engagement objective, All players, now 3 credits/day, status Learning. So far:
    5.65 credits spent, 4,039 impressions, CTR 1.6%, 63 clicks, 9 plays, CPP 0.628 credits, 2.1 h of playtime
    (~14 min per player).
  - **New users per day:** Oct 10: 11 (ads), Oct 11: 3.
  - **New user first session:** 54% still playing after 5 min (previous period 40%). Mostly pre-update players.
  - **D1:** the Oct 10 cohort came back 1 of 11 (9%). This is the number to move.
  - **Funnel after the update** (steps 8–10 are the only clean ones): 3 reached "Second job", 1 finished the tutorial
    and built the Garden Shed. Too few players to judge.
  - **Avg session ~1 min on Oct 9 and 11:** probably the owner's own quick test joins; filter by IsNewUser.
- **Earlier audit (AUDIT_2026-10-11):**
  - Half of the new players never started (old errand-style first step).
  - Phone/tablet players never passed level 3.
  - The ones who stay play a long time (the mid/late loop works).

## 6. Getting ready for the €100 promotion

- **Spend the €100 only when these gates pass** on ~20 new players from the small 3 credits/day campaign:
  1. **P0 items fixed and published:** the teleport fix and the clean funnel.
  2. **5-minute retention ≥ 60%** of new players (first-session curve).
  3. **Tutorial completion ≥ 50%** of joiners (clean funnel, step 9).
  4. **D1 ≥ 20%.**
  5. **No new errors** in the Error Report; no "sites busy" for new players (P1 #4).
  6. **Game page ready:** the new description and the best thumbnail first.
- **How to spend it:**
  - Check the current Ad Credit price first.
  - Ramp, don't dump: a few days at a higher daily budget. Keep the creative that wins on CTR **and** on D1 (not just
    clicks), and drop "Rare Hammers" (CTR 0.3%).
  - Watch CPP, D1 per day and the funnel daily. Stop or pause if D1 falls under ~10% or a new bug shows up.
- **Why retention first:** CCU comes from Roblox's recommendations, which reward playtime and returns. 5 CCU with
  15-minute sessions needs ~480 sessions a day, about 300 credits a day at today's CPP. Paid traffic alone can't buy
  that; it only proves the game keeps people.
- **Free volume:** 15–30 s TikTok / YouTube Shorts clips (a rare hammer pull, a building going up fast).

## 7. Technical notes (how this project is worked on)

- **Roblox Studio MCP:** studio ids change when Studio reopens, so call `list_roblox_studios`.
  - `execute_luau` contexts: Edit (only with Play stopped), Server, Client.
  - The MCP Client VM is not the game VM. To run code in the game client, insert a LocalScript into the player's
    PlayerGui from the Server context, and read results through a player attribute. Attributes a client sets are
    visible to the MCP Client context but do not replicate to the server.
- **Studio has no DataStore API access:** every Play is a brand-new player, which is ideal for testing the first minute.
- **Studio-only debug hook:** a BindableFunction named `CE_Debug` (created by Main at runtime), called as
  `bf:Invoke(cmd, plr, v)`. Commands include `give`, `level`, `set` ({key, value}), `boost` ({key, secs}), `vehicle`,
  `crate` ({id, n}), `finish` (completes the current contract), `pass`, `events`.
- **Remotes:** `ReplicatedStorage.Remotes` (Work, AcceptContract, AbandonContract, HireWorker, BuyGear, BuyMachine,
  HammerAction, VehicleAction…).
- **Phone layout test:** `UI.emulate(Vector2.new(750, 361), true)` in an injected LocalScript, or the owner's emulator.
- **Locals limit:** the Client main chunk is at Luau's 200-locals limit. Put new code in `do … end` blocks or in the
  `SW` table.
- **Code markers to search for:** `FIRST_MINUTE`, `EVENTS_20`, `PHONE_V3`, `PHONE_V3b`, `MENUS_HIGH`, `REJOIN_RACE`,
  `TUTORIAL_V4`, `ECONOMY_V5`.
- **Where things live:**
  - **Main (ServerScriptService.Game.Main):** `acceptContract`, `autoFirstJob`, `roadCheck`, `funnel`, Cash Rush /
    Lucky Hour loops.
  - **Config:** Road tutorial in the TUTORIAL_V4 block, event schedule and RookieLevel at the end.
  - **StarterPlayerScripts.Client:**
    - title screen: `showWelcome`;
    - green NEXT button and events toasts: end of file;
    - rookie trip: Feedback "Accepted";
    - PROJECT COMPLETE card: `_G.__CE_ShowComplete`.
  - **Client.HUD:** layout / layoutStrip, `goPlace` (`_G.__CE_GoPlace`), effects list, top strip.
  - **Client.LocationsUI.Go:** free trips.
  - **Client.HammersUI:** tutorial crate auto-open.
  - **StarterPlayerScripts.HammerFX:** reveal card, KEEP placement.
  - **ReplicatedStorage.Shared.UIKit:** `UI.touch`, `UI.emulate`, `UI.button`, `UI.touchActions`.

## 8. Game page text given to the owner (2026-10-12)

He pastes it himself. If the page still shows the old text, remind him.

```
🏗️ Take building jobs, smash with your hammer, earn cash and grow from a rusty hammer to a huge CONSTRUCTION EMPIRE!

🎁 FREE crate after your first job – in under 1 minute!
⏰ EVENTS every 20 minutes: CASH RUSH (x2 cash) or LUCKY RUSH (x2 luck)!
🔨 Pull hammers from Common to Mythic and DIVINE!
👷 Hire workers and machines – they build for you!
🏙️ Unlock bigger jobs: shops, villas, skyscrapers!
🎰 FREE Lucky Spin + gifts just for playing!

👍 Like + ⭐ Favorite for new updates!
```

Optional title tag: `BlockRise Empire [🔨 EVENTS]`. First thumbnail: the "LVL 1 → LVL 100" image.

## 9. Your first session, step by step

1. Ask the owner to open Roblox Studio (the place) and the Claude desktop app on his MacBook, and to open the
   conversation there so the Studio tools connect.
2. Read the Creator Hub data (section 5) for the days since 2026-10-11 and write him a short Romanian summary:
   - ads: clicks → plays;
   - new users per day;
   - 5-minute retention;
   - funnel per step;
   - D1;
   - errors;
   - sales, including the Skip Build Animation pass.
3. Fix P0 #1 (teleport + fall guard), test it on every site as described, run the final checks, and tell him he can publish.
4. Then P0 #2 (clean funnel), then the P1 list. One change at a time, each one tested and shown to him.

## 10. The next big update: REGIONS (owner's direction, 2026-10-12 evening)

**The problem (owner):** a player who likes the game reaches the last building in about 3 days and then has nothing
left. Everything is the same action (hit → cash → bigger building).

**Owner's decisions:**
- **YES: regions, Pet Simulator 99 style.** Every zone is one Rebirth, and every 3 zones open a new region with its
  own world and jobs. No more "100 rebirths" of the same map.
- **YES: a portal hub at the central fountain** that takes you to other worlds: Speed Build (build a tower against the
  clock, tiers by power, medals → chests, a tiny chance at an exclusive hammer) and a Parkour/obby world (checkpoints,
  wide platforms for phone, chest at the end, server-checked checkpoints against exploiters). Rewards have a cooldown,
  plus one big daily reward. Unlocked after the tutorial.
- **NO: "Your City"** (placing your finished buildings on your own plot). Don't build it.
- **Not decided:** construction stages that aren't clicking (demolition with physics, material deliveries by car, a
  crane timing minigame for the top floors). Proposed; ask him before building.

### Region ladder (owner's order; names are proposals)
| Region | Zones (one Rebirth each) | Jobs / feel |
|---|---|---|
| 1 City (exists) | Town (R0), Suburbs (R1), Downtown (R2) | today's buildings |
| 2 Desert / Oil | e.g. Dunes (R3), Oasis (R4), Oil Fields (R5) | oil derricks, pipelines, refinery, desert hotel |
| 3 Atlantis (underwater) | e.g. Reef (R6), Sunken City (R7), Palace (R8) | domes, glass tunnels, coral towers, sub dock |
| 4 Moon | e.g. Moon Base (R9), Craters (R10), Spaceport (R11) | low gravity, habitats, rocket pad |
| later | Snow (bridges), Volcano, Space Station… | one region per update |

- Rebirth = move to the next zone (the existing RebirthService cost rules can stay). It stops at the last zone that is
  released: show "NEW REGION SOON" with a countdown. A release every 2–3 weeks gives players a reason to come back, and
  Roblox treats regular updates well.
- Today: Suburbs opens at Rebirth 1 and Downtown at Rebirth 2 (`Config.Zones.*.rebirth`). That already matches the
  owner's plan for region 1.
- Travel between unlocked regions: portals in the fountain hub (locked ones show "Rebirth 3").

### The economy, PS99 style. Much of it already exists; check before rebuilding
- **Already in the game:**
  - Zone Supply Crates for cash: one per zone, opening with that zone's odds (`Hammers.SupplyFor(zone)`).
  - Gem crates: Builder's Crate (150 Gems) and Golden Crate (600 Gems, up to Divine). Both are also sold for Robux.
  - Gem Shop and Gem packs for Robux.
  - Passes: luck, quick-open, auto-open, Skip Build Animation, etc.
  - Trading (TradeService).
  - X-Ray crates where paid random items are restricted (PolicyService).
  - **Exclusive Crate (Robux):** built but closed (`soon = true`). Its hammers (Royal Crown, Ghost, Rainbow Prism) have
    no models yet; only the Thunderclap has one.
- **What the owner wants, and what's missing:**
  1. **Each zone's crate costs a lot of cash, but its best hammers match the power that zone's jobs need** (like each
     PS99 egg). With only 8 rarities, power can't keep growing through rarity alone. Give every region its own hammer
     family with a region power multiplier: the region-2 Common beats the region-1 Legendary, and so on. Tune so the
     usual pull from a zone's crate is enough for that zone, and a lucky pull (or a Gem crate) puts you ahead.
  2. **Rare things only for Gems.** Gems must be farmable in every region, so a free player can earn them by playing:
     gem nodes or jobs, quests, events, Rebirth prizes. They can also be bought with Robux, which already works.
  3. **Robux-only crates with better (still small) odds for exclusives.** First open the Exclusive Crate: make the 3
     models. Then add one exclusive crate per region. Always show the odds before purchase.
  4. **A chase item like PS99's Huges: COLOSSAL hammers** (owner: not "Titan").
     - **Odds:** about 1 in 50,000 from any crate.
     - **Look:** a giant version of a hammer (e.g. "Colossal Galaxy Hammer"), clearly bigger in the hand, with its own
       aura.
     - **Pull moment:** announced to the whole server.
     - Use our own names and art, not PS99's.
  5. **Optional, PS99 style:** a fuse machine (5 duplicates → Golden version, Golden → Rainbow) as a sink for
     duplicates. A separate currency per region (Cash → Oil → Pearls → Moon Rock) keeps old cash from breaking new
     prices; the 2x Cash pass applies to all of them.
- **Existing saves: NEVER reset progress.** Before designing the migration:
  - Read (read-only) how many Rebirths today's players have, using Data Stores Manager.
  - Agree with the owner how players with Rebirth ≥ 3 enter the Desert: for example, they start in Desert zone 1 and
    their old Rebirth multipliers become a one-time bonus.
- **Build order:**
  1. The P0 fixes above.
  2. Open the Exclusive Crate.
  3. The portal hub with Speed Build and Parkour.
  4. Region 2, the Desert: map, jobs, hammer family, crates, the rebirth into it, the migration.
  5. Then one region per update.

  Every map and UI must pass section 2 on PC and phone, and phone performance must be checked with the new maps
  (StreamingEnabled).
