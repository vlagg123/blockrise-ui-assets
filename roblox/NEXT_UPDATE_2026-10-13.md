# Next update (owner, 2026-10-13): agreed, to build when Studio is open

The owner's rule for every change: perfect, tested, centred, nothing touching, a clear UI (see the handoff, section 2).

## 1. ZONE_CHAIN: new buildings instead of farming the top building for the Rebirth's Level
- **The problem:** today Rebirth 1 needs the Corner Shop built once and Level 12. After the Corner Shop that means about
  29 more Corner Shops. Suburbs means ~27 Distribution Centers for Level 35; Downtown ~23 Grand Hotels for Level 55.
- **What changes:** 5 new buildings per zone, each built once, in order. After the last one you have exactly the
  Level the Rebirth needs, and the last one is the zone's new top building (the Rebirth needs it built once).
- **What stays as it is (owner):**
  - power and Strength (from building, plus the Training Yard for the Strength gates);
  - the Level numbers (12 / 35 / 55);
  - everything else.
- **XP grows exponentially along the chain** (×1.56–1.66 a building). XP per second of a first build rises at every
  step, so building in order is always the best for XP.
- **No shortcut:** farming small buildings can bring the Level, but the Rebirth still needs the top building, which
  needs its Strength.
- **Cash rewards also grow** along the chain (tuned with the existing ~×2.8 a building).
- **Numbers:** first pass from `tools/econ/zone_chain.py`, re-run after any change. Strength gates, work and pay are
  tuned in Studio with the live formulas so that the time to R1 / R2 / R3 stays about what it is today.

| Zone | New buildings (XP each, in order) | Sum with the old ones once |
|---|---|---|
| Town (→ Level 12, R1) | Bakery 1,000 · Car Wash 1,700 · Clinic 2,900 · Fire Station 4,800 · **Town Hall** 7,871 | 19,416 (exactly Level 12) |
| Suburbs (12 → 35, R2) | Shopping Plaza 15,000 · Sports Arena 24,000 · Hospital 39,000 · Water Park 64,000 · **Suburb Mall** 103,406 | 267,406 |
| Downtown R2 (35 → 55, R3) | Bank Tower 37,000 · Concert Hall 59,000 · Museum 91,000 · Twin Towers 140,000 · **City Stadium** 226,531 | 592,531 |

- **Downtown after R3:** Skyscraper (R3), HQ (R4) and Spire (R5) stay as they are until the Desert update (V6)
  replaces those later Rebirths.
- **Each new building is its own blueprint:** a different shape, colours and roof, built in stages like the others.
  Every one is checked visually and for the StandPoint (TELEPORT_FIX) on every site of its zone.
- **Tests:**
  - simulator plus a Studio run: the time to R1 stays at about today's (30–40 min active);
  - the Rebirth button appears right after the last building;
  - Job Board order and locks;
  - the green NEXT button / Empire Road point to the next building;
  - migration of old saves (no reset): buildings built stay built, and a player who is already Level 12 + Corner
    Shop keeps the Rebirth (do not take away something that was already open).

## 2. Crate prices (V6 section 5, owner's structure)
- **Cash:** the crate of each zone (Rebirth) at a fixed price: Town $150, Suburbs $88K, Downtown $16M.
- **Gems only:** Builder's, Golden, Pirate Cove, Jungle Temple and Legends. They are no longer sold directly for
  Robux; Robux buys Gems.
- **Robux only:** the Exclusive Crate (999 / 3 for 2,699).
- **Check:** the X-Ray rule (PolicyService) and the ODDS window still work for every crate.

## 3. Construction animations: more "wow", above all the skyscrapers
- **Owner:** today a skyscraper is white wall pieces with some glass on top at the end. It needs more.
- **Plan for the tall buildings** (Office, Hotel, Skyscraper, HQ, Spire and the new Downtown ones):
  - steel frame floor by floor (columns, beams), with the tower crane lifting pieces;
  - glass curtain-wall panels sliding in per floor;
  - floor slabs and lights switching on floor by floor;
  - a top finale (beacon, antenna, fireworks / sparks), a camera tilt up on completion, a sound.
- **Smaller buildings:** a few better stage effects (dust, scaffolding).
- **Performance:** checked on phones (part count, tweens client-side).

## Also agreed today
- **Phone HUD cleanup** (owner: too much on screen):
  - in the tutorial only the usable buttons show;
  - after it, a compact left column + a MENU button;
  - STORE / GIFT / SPIN on the right;
  - effects as one row of icons;
  - one message at a time, smaller and higher;
  - no overlaps;
  - the PC layout unchanged.
- **A polite "Add to Favorites" prompt after the tutorial** (AvatarEditorService:PromptSetFavorite).
- **Publish when the game is empty** (0 players), and note the time.
