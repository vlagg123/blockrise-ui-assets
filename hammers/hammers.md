# BlockRise Empire — Hammer collection (40 hammers)

Brief for the AI that builds the models and icons in Blender. The game already has 16 hammers with models
(marked **has model**). The 24 marked **TO MAKE** need: an in-game Tool model (same build pipeline as the existing
ones: `hammers/bl_build.py` spec → `ServerStorage.Hammers.Hammer_<key>`, Key attribute = key) and a 256 px icon in the
Shop style (sticker look, dark outline, transparent background — same pipeline as `icons/robux.py`).

Style rules (keep the game's look): chunky cartoon proportions, head about 1.6x the handle width, bevelled edges,
candy/PBR materials, no photo textures. Every hammer must read at 64 px: one strong silhouette + one signature colour.
In-game effects (trails, glints, orbs, aura) are done by the game per rarity; the model only needs the shape and materials,
plus optional emissive parts (the game lights them).

## Rarity → power and effects

| Rarity | Power | Swing CD | Effect tier (done by the game) |
|---|---|---|---|
| Common | x1.00 | 0.42 s | none |
| Uncommon | x1.35 | 0.38 s | thin swing trail |
| Rare | x1.82 | 0.34 s | head glow + coloured trail, sparkles |
| Epic | x2.46 | 0.30 s | particles on impact, own hit sound |
| Legendary | x3.32 | 0.27 s | aura on the player + impact flash |
| Mythic | x4.48 | 0.25 s | orbiting lights, ring of light at the feet |
| Secret | x6.05 | 0.23 s | screen-wide impact effect, unique sound, coloured name tag |
| Divine | x8.17 | 0.21 s | all of the above + a beam from the sky |

Levels 1–10: +8% power per level (bought with cash).

## The hammers

### Common
| key | Name | Status | Description / visual notes |
|---|---|---|---|
| rusty | Rusty Hammer | has model | The default hammer. Old, bent, tape on the handle. Never tradeable. |
| iron | Iron Hammer | has model | Solid iron, honest wood. |
| steel | Steel Hammer | has model | Polished steel, comfy grip. |
| mallet | Carpenter's Mallet | TO MAKE | Fat cylindrical wooden head (light oak), leather-wrapped handle, brass band. Warm browns. |
| brick | Brick Hammer | TO MAKE | A single red clay brick as the head (with the 3 holes), rough mortar edges, plain wooden handle. |
| claw | Claw Hammer | TO MAKE | Classic hardware-store claw hammer: silver steel head with the curved claw, yellow-and-black fibreglass handle. |

### Uncommon
| key | Name | Status | Description / visual notes |
|---|---|---|---|
| gold | Golden Hammer | has model | Solid gold. Every hit shines. |
| titanium | Titanium Sledge | has model | Light as air, hard as rock. |
| copper | Copper Pipe Hammer | TO MAKE | Head is a bent copper pipe elbow (mirror copper), pipe-clamp handle, a little green patina at the joints. |
| neon | Neon Hammer | TO MAKE | Matte black rubber head and handle with 3 glowing neon stripes (magenta, cyan, lime). Emissive stripes. |
| toolbox | Toolbox Hammer | TO MAKE | A small red metal toolbox (latch, handle on top) as the head, screwdrivers sticking out of the side, steel handle. |
| bronze | Bronze Mallet | TO MAKE | Ancient bronze round-ended mallet, engraved rings, green patina in the grooves, dark wood handle with cord wrap. |

### Rare
| key | Name | Status | Description / visual notes |
|---|---|---|---|
| emerald | Emerald Hammer | has model | A flawless emerald set in gold. |
| ruby | Ruby Hammer | has model | Two blazing rubies. |
| obsidian | Obsidian Hammer | TO MAKE | Black volcanic glass head with sharp facets, a deep red emissive glow in cracks, charcoal handle with red cord. |
| jade | Jade Hammer | TO MAKE | Carved green jade head (slightly translucent), gold dragon engraving on the sides, gold caps, dark lacquered handle. |
| candy | Candy Hammer | TO MAKE | Giant pink-and-white swirl lollipop as the head, red-and-white candy-cane handle, glossy, a few sprinkles. |

### Epic
| key | Name | Status | Description / visual notes |
|---|---|---|---|
| sapphire | Sapphire War Hammer | has model | A sapphire war hammer with a spike. |
| amethyst | Amethyst Crystal Hammer | has model | Crystals that grew on their own. |
| dragon | Dragon Fang Hammer | TO MAKE | Head = a huge curved white fang bound to a scaled red-and-black grip with leather straps; small smoke wisps at the tip (emissive orange). |
| clockwork | Clockwork Hammer | TO MAKE | Glass-domed brass head with visible gears inside (3–5 gears, one big), copper rivets, walnut handle. Gears may spin (the game can animate a part named `Gear`). |
| robo | Robo Hammer | TO MAKE | White-and-blue robot head (two blue LED eyes, antenna) as the hammer head, chrome handle with blue rubber grip. Eyes emissive. |

### Legendary
| key | Name | Status | Description / visual notes |
|---|---|---|---|
| lava | Lava Hammer | has model | Forged in a volcano. Still hot. |
| frost | Frost Hammer | has model | Cold enough to freeze the air. |
| phoenix | Phoenix Hammer | TO MAKE | Golden head shaped like a phoenix with spread wings as the two faces, red-orange flame feathers (emissive), white-gold handle. |
| tsunami | Tsunami Hammer | TO MAKE | Head = a frozen curling wave of deep blue translucent water with white foam on the crest, driftwood-look handle. |
| cyber | Cyber Hammer | TO MAKE | Matte black angular head with cyan circuit lines (emissive) and a hex pattern, black handle with cyan ring lights. |

### Mythic
| key | Name | Status | Description / visual notes |
|---|---|---|---|
| diamond | Diamond Hammer | has model | The hardest hammer there is. |
| plasma | Plasma Hammer | has model | Pure energy in a magnetic field. |
| thunder | Thunderclap Hammer | has model | Pass owners only (bound, not tradeable). |
| void | Void Hammer | TO MAKE | A pure black head (no reflections) with a thin violet rim light and purple sparks, dark purple handle. The head should look like a hole in the world. |

### Secret
| key | Name | Status | Description / visual notes |
|---|---|---|---|
| solar | Solar Hammer | has model | A tiny sun on a stick. |
| blackhole | Black Hole Hammer | TO MAKE | Black sphere head with a bright orange-white accretion ring tilted around it (emissive), dark iron handle. |
| demon | Demon King Hammer | TO MAKE | Dark crimson head with two black horns, a small golden crown on top, chains wrapped around the handle, lava-crack emissive lines. |

### Divine
| key | Name | Status | Description / visual notes |
|---|---|---|---|
| galaxy | Galaxy Hammer | has model | A whole galaxy trapped in crystal. |
| celestial | Celestial Creator | TO MAKE | White marble head with gold inlays and a floating golden halo ring above it, soft white-gold glow, ivory handle with gold wrap. The most "holy" looking item in the game. |

### Exclusive (Exclusive Crate — Robux — and events only)
| key | Name | Rarity | Status | Description / visual notes |
|---|---|---|---|---|
| crown | Royal Crown Hammer | Legendary | TO MAKE | A jewelled gold crown (red velvet inside, 3 gems) as the head, red velvet grip with gold cord. |
| ghost | Ghost Hammer | Mythic | TO MAKE | Translucent pale-cyan ghost (cartoon ghost face on the head) with wisps trailing off the back, semi-transparent handle. |
| prism | Rainbow Prism Hammer | Secret | TO MAKE | A clear triangular glass prism as the head with a rainbow refraction band inside, chrome handle. |
| founder | Founder's Hammer | Secret | TO MAKE | Launch-event only. Dark navy head with the BlockRise logo in gold on both faces, gold "FOUNDER" band on the handle, small gold stars. |

## Deliverables per hammer
1. Blender build in `hammers/bl_build.py` style (one spec entry: key, parts, materials, palette) so the in-game Tool is generated the same way as the existing 16.
2. Icon render `icons/.../<key>.png` at 256 px, transparent, sticker outline, same camera angle as `shop_1..15`.
3. Keep the handle length and grip point identical to the existing hammers (the swing animation and the hand grip are shared).
