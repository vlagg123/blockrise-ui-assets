# Next: build effects ladder (HammerFX SITE table) — stopped 2026-10-07

Done and live in Studio (dbd1f7d): hit bursts in their own colours for the 15 newer hammers, the `firework` and
`glitter` emitters, and `glide(part, life, fn(u)->CFrame, land, fade)` plus `kids` on `throw` (a gear's teeth).
Hammers rebuilt from spec 37fde9d (z-fight fix, checked on the Founder in Play).

What the user asked for: effects around the building while you build, from Epic upwards. Epic should be subtle, and
each rarity after it should be clearly more impressive, up to Divine.
Today only amethyst, lava, frost, diamond, plasma, solar, galaxy and thunder have SITE effects. Lava and frost are
Legendary now but still have Epic-strength effects.

Ladder (`SITE[key] = { fn(pos, mine, e), cooldown }`; the cooldown is doubled for other players; screen flash and
shake are for your own hits only):

## EPIC: cooldown 1.4, no light, no screen effects
- sapphire: one blue crystal
- amethyst: as it is
- dragon: a puff of smoke and a small flame
- clockwork: a brass gear (a cylinder, a hub and 4 cross bars as `kids`) thrown out, tumbling
- robo: a cyan ring on the ground and 3 pixel cubes that pop up

## LEGENDARY: cooldown 1.0, plus `lightFlash` (yours)
- lava: a column and 2 lava blobs arcing out, each landing in fire and smoke
- frost: a cluster of 3 ice spikes, mist and a pale ring
- phoenix: 6 embers spiralling up 12 studs, a burst at the top and a fire ring
- tsunami: a splash column, a water ring and 6 droplets
- cyber: 3 circuit traces in L shapes growing over the ground, each ending in a node that blinks
- crown: a fountain of 5 gold coins

## MYTHIC: cooldown 0.85, plus a big moment every 5 s (no screen flash)
- diamond: the shard shower; big: 8 crystals in a circle and a ring
- plasma: the chain; big: an EMP (ring 34 and 6 zaps in a star)
- void: a small purple implosion with particles pulled in; big: a large rift over the house
- ghost: 2 wisps rising; big: 10 wisps spiralling up around the house

## SECRET: cooldown 0.7, plus a big moment every 4 s with screen flash and shake 0.25–0.3
- solar: as it is, cooldown 0.75
- thunder: as it is
- blackhole: a black sphere with an accretion disc (two discs of different thickness, so they don't z-fight) and
  debris spiralling in; big: a size-4.5 hole over the house, a dark flash, ring 36
- demon: a glowing crack with a fire pillar; big: 6 pillars in a circle, a red flash
- prism: a white beam splitting into 7 rainbow bars; big: a rainbow arc over the house (7 bands × 9 segments,
  facing the camera)
- founder: a gold firework rocket bursting; big: a volley of 5 coloured fireworks

## DIVINE: cooldown 0.6, plus a huge moment every 3.5 s (flash and shake 0.3)
- galaxy: a meteor on every hit; big: 8 meteors and a 16-star spiral pulled into the house
- celestial: a pillar of heavenly light, a gold ring and glitter; big: a gold halo of 16 lights coming down over
  the house, 6 beams, a white-gold flash

## After that
- Test every one in Play: give the tool in the Server DM, fire `Feedback` "Hit", camera through `BindToRenderStep`.
- Then the user publishes.
