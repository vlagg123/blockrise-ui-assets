# BlockRise Empire 2.0 — architecture (DEV place 97174353381365, universe 10771623817)

Live stays untouched (place 93206782559935). Everything below is built only in BlockRise DEV; every Studio edit
asserts `game.PlaceId == 97174353381365` first. Never publish; the owner publishes DEV over live at launch.

## World (Workspace.World, built once in Edit by roblox/v2/build_world.lua)
- Hub at the origin, ground top at Y = 0. Angles: θ from +Z toward +X, dir = (sin θ, 0, cos θ).
- Plaza: paved disk r = 140, fountain with the golden hammer at the centre, spawn terrace at θ = 180°, r ≈ 100,
  facing the fountain and the City Tower (θ = 0°).
- Hub buildings at r ≈ 195, θ = 0 (City Tower), 60 (Hammer Shop + Store), 120 (Car Dealer), 240 (Gym),
  300 (Heliport); Trade kiosks and the leaderboard screens inside the plaza.
- Ring road centre r = 253, width 26. Six avenues at θ = 30 + 60k from the plaza edge to the districts.
- District k (k = 0..5) on axis θ = 30 + 60k, entrance at r = 330. Local frame: +Z outward, +X to the right.
  Across X: street 28 | block 112 | avenue 28 | block 112 | street 28 (X −154..154).
  Depth Z: arch 0..20, street 20..48, row 1 48..160, street 160..188, row 2 188..300, street 300..328,
  row 3 328..440, street 440..468, landmark 468..588.
- Lot 56 × 56 (building footprint ≤ 48 × 48). Lot index = (row−1)·8 + (block−1)·4 + slot; block 1 = left (−X),
  2 = right; slot 1 front-outer, 2 front-inner, 3 back-outer, 4 back-inner. Front lots face −Z, back lots +Z.

## Server (ServerScriptService.Game2)
- Main2 (Script): players, load/save (session lock, spaced writes — ported from v1), passes, receipts + the
  permanent Robux ledger (ported, BlockRise_RobuxLedger never renamed), update restarts, admin.
- Data2: defaultData v3 + migration of v1 saves (keeps hammers, crates, gems, passes, cars, spins, boosts, receipts;
  the old run becomes a welcome pack). DataStore stays BlockRise_v6 (no reset).
- City: district assignment, lots, blocks, build queue (3 orders, the crew builds one at a time), income per second,
  offline earnings, block bonus, land purchase, Rebirth.
- Kit: builds the 10 levels × 2 styles of buildings from parts (templates in ServerStorage.Kit2); construction
  reveals the template floor by floor.
- Crew: worker NPCs with real hammers in hand (the player's best hammers, EQUIP BEST), walk to the site and swing.
- Reused v1 modules: Hammers (shared data), HammerService (inventory, crates, trade hooks), TradeService,
  VehicleService.

## Client (StarterPlayerScripts.Client2)
- UIKit2 (new design system), HUD2, windows (HAMMERS, SHOP, MENU), building card, contextual tutorial, FX.

## Economy (tools/econ/v2/sim.py; numbers in Config2)
- Income per building, L1..L10: 1, 3, 8, 20, 50, 125, 310, 780, 1950, 4900 $/s (× 1.5^Rebirths × bonuses).
- Cost to reach L: 8, 60, 750, 7.2K, 39K, 220K, 925K, 8.5M, 37.5M, 142M.
- Base build time: 5, 10, 20, 40, 60, 90, 120, 180, 240, 300 s (crew of 3 with basic hammers).
- Land: row 1 block 2 $300; row 2 $60K / $250K; row 3 $12M / $40M. Caps: Lv 4 / 7 / 10 (Rebirth 0 / 1 / 2+).
- Rebirth: $50K, $12M, $1.5B, then Landmarks. Block bonus +25% when its 4 lots are the same level.
- Sim (greedy player, no crew upgrades): Rebirth 1 ≈ 18 min, Rebirth 2 ≈ 2.6 h, Rebirth 3 ≈ 15 h.
