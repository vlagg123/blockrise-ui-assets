-- BlockRise Empire - the hammers: collectible items with a rarity, a level and a look.
-- Shared by server and client (pure data + pure functions; no services here).
--   Hammers.Rarities        the 8 rarities of the ladder, in order (power, swing cooldown, colour, effect tier), and
--                           a 9th shown on its own: EXCLUSIVE (the pass hammer; its power stays the one of its ladder rarity)
--   Hammers.List / ById     the 40 hammers (16 have a model in the game today; the rest are "coming soon")
--   Hammers.Crates / CrateById  the crates and their odds (shown in the game: Roblox requires it for paid random items)
--   Hammers.Power(key, lv)  build power of one hammer; Hammers.LevelCost(key, lv) cash to go lv -> lv+1
--   Hammers.Roll(crateId, zone, rng, luck)  -> hammer key (only hammers that exist in the game can drop)
local Hammers = {}

local C3 = Color3.fromRGB
Hammers.MaxLevel = 10
Hammers.LevelStep = 0.08          -- +8% power per level
Hammers.RarityStep = 1.35         -- every rarity x1.35 power
Hammers.TradeUpCount = 10         -- 10 of a rarity -> 1 of the next
Hammers.InventoryCap = 300
Hammers.LadderTop = 8              -- trade-ups and crates stop at Divine (Exclusive is a category, not a step)
Hammers.DefaultKey = "rusty"      -- everyone's first hammer; never tradeable, never lost

Hammers.Rarities = {
	{ id = "common", name = "Common", cooldown = 0.42, color = C3(150, 156, 178), fx = 0, levelBase = 120 },
	{ id = "uncommon", name = "Uncommon", cooldown = 0.38, color = C3(80, 200, 100), fx = 1, levelBase = 500 },
	{ id = "rare", name = "Rare", cooldown = 0.34, color = C3(60, 150, 255), fx = 2, levelBase = 2500 },
	{ id = "epic", name = "Epic", cooldown = 0.30, color = C3(165, 90, 255), fx = 3, levelBase = 12000 },
	{ id = "legendary", name = "Legendary", cooldown = 0.27, color = C3(255, 170, 30), fx = 4, levelBase = 60000 },
	{ id = "mythic", name = "Mythic", cooldown = 0.25, color = C3(255, 70, 120), fx = 5, levelBase = 300000 },
	{ id = "secret", name = "Secret", cooldown = 0.23, color = C3(40, 40, 60), fx = 6, levelBase = 1500000, text = C3(230, 230, 255) },
	{ id = "divine", name = "Divine", cooldown = 0.21, color = C3(250, 214, 255), fx = 7, levelBase = 8000000, text = C3(120, 60, 160) },
	-- shown, never rolled: pass hammers (h.show = "exclusive"); power, cooldown and level costs come from h.rarity
	{ id = "exclusive", name = "Exclusive", cooldown = 0.25, color = C3(24, 214, 200), fx = 5, levelBase = 300000, display = true },
}
Hammers.RarityById = {}
for i, r in ipairs(Hammers.Rarities) do r.index = i; Hammers.RarityById[r.id] = r end

-- model = the Tool in ServerStorage.Hammers (Hammer_<model>); icon = the Shop atlas icon; soon = no model yet
-- exclusive = only from the Exclusive Crate (Robux) / a pass; event = only from an event crate
Hammers.List = {
	-- COMMON
	{ key = "rusty", name = "Rusty Hammer", rarity = "common", model = "1", icon = "shop_1", desc = "Old, bent and held together with tape. It works. Mostly. Yours forever." },
	{ key = "iron", name = "Iron Hammer", rarity = "common", model = "2", icon = "shop_2", desc = "Solid iron, honest wood." },
	{ key = "steel", name = "Steel Hammer", rarity = "common", model = "3", icon = "shop_3", desc = "Polished steel, comfy grip." },
	{ key = "mallet", name = "Carpenter's Mallet", rarity = "common", soon = true, desc = "A fat wooden mallet with a leather-wrapped handle. Thud." },
	{ key = "brick", name = "Brick Hammer", rarity = "common", soon = true, desc = "A red brick on a stick. Don't ask how it holds together." },
	{ key = "claw", name = "Claw Hammer", rarity = "common", soon = true, desc = "The classic claw hammer, fresh from the hardware store." },
	-- UNCOMMON
	{ key = "gold", name = "Golden Hammer", rarity = "uncommon", model = "4", icon = "shop_4", desc = "Solid gold. Every hit shines." },
	{ key = "titanium", name = "Titanium Sledge", rarity = "uncommon", model = "5", icon = "shop_5", desc = "Light as air, hard as rock." },
	{ key = "copper", name = "Copper Pipe Hammer", rarity = "uncommon", soon = true, desc = "A plumber's revenge: a bent copper pipe, polished to a mirror." },
	{ key = "neon", name = "Neon Hammer", rarity = "uncommon", soon = true, desc = "Black rubber with glowing neon stripes. Looks fast standing still." },
	{ key = "toolbox", name = "Toolbox Hammer", rarity = "uncommon", soon = true, desc = "A whole red toolbox welded onto a handle. Everything you need, in one swing." },
	{ key = "bronze", name = "Bronze Mallet", rarity = "uncommon", soon = true, desc = "Ancient bronze with green patina. It has seen things." },
	-- RARE
	{ key = "emerald", name = "Emerald Hammer", rarity = "rare", model = "6", icon = "shop_6", desc = "A flawless emerald set in gold." },
	{ key = "ruby", name = "Ruby Hammer", rarity = "rare", model = "7", icon = "shop_7", desc = "Two blazing rubies." },
	{ key = "obsidian", name = "Obsidian Hammer", rarity = "rare", soon = true, desc = "Black volcanic glass with a red glow deep inside." },
	{ key = "jade", name = "Jade Hammer", rarity = "rare", soon = true, desc = "Carved green jade with golden dragon engravings." },
	{ key = "candy", name = "Candy Hammer", rarity = "rare", soon = true, desc = "A giant swirl lollipop head on a candy-cane handle. Sticky." },
	-- EPIC
	{ key = "sapphire", name = "Sapphire War Hammer", rarity = "epic", model = "8", icon = "shop_8", desc = "A sapphire war hammer with a spike." },
	{ key = "amethyst", name = "Amethyst Crystal Hammer", rarity = "epic", model = "9", icon = "shop_9", desc = "Crystals that grew on their own." },
	{ key = "dragon", name = "Dragon Fang Hammer", rarity = "epic", soon = true, desc = "A dragon's fang bound in scales. It still breathes a little smoke." },
	{ key = "clockwork", name = "Clockwork Hammer", rarity = "epic", soon = true, desc = "Brass gears spin inside the glass head with every swing." },
	{ key = "robo", name = "Robo Hammer", rarity = "epic", soon = true, desc = "A white-and-blue robot head that beeps when it hits." },
	-- LEGENDARY
	{ key = "lava", name = "Lava Hammer", rarity = "legendary", model = "10", icon = "shop_10", desc = "Forged in a volcano. Still hot." },
	{ key = "frost", name = "Frost Hammer", rarity = "legendary", model = "11", icon = "shop_11", desc = "Cold enough to freeze the air." },
	{ key = "phoenix", name = "Phoenix Hammer", rarity = "legendary", soon = true, desc = "Golden feathers and living flame. It rises with every swing." },
	{ key = "tsunami", name = "Tsunami Hammer", rarity = "legendary", soon = true, desc = "A frozen wave of deep blue water, white foam on the crest." },
	{ key = "cyber", name = "Cyber Hammer", rarity = "legendary", soon = true, desc = "Matte black with cyan circuit lines that pulse to the beat." },
	-- MYTHIC
	{ key = "diamond", name = "Diamond Hammer", rarity = "mythic", model = "12", icon = "shop_12", desc = "The hardest hammer there is." },
	{ key = "plasma", name = "Plasma Hammer", rarity = "mythic", model = "13", icon = "shop_13", desc = "Pure energy in a magnetic field." },
	{ key = "thunder", name = "Thunderclap Hammer", rarity = "mythic", show = "exclusive", model = "thunder", exclusive = true, pass = "stormhammer", image = "stormhammer",
		desc = "A storm in a hammer. Every hit cracks like thunder. Thunderclap Hammer pass owners only." },
	{ key = "void", name = "Void Hammer", rarity = "mythic", soon = true, desc = "A hole in the world shaped like a hammer. Light bends around it." },
	-- SECRET
	{ key = "solar", name = "Solar Hammer", rarity = "secret", model = "14", icon = "shop_14", desc = "A tiny sun on a stick." },
	{ key = "blackhole", name = "Black Hole Hammer", rarity = "secret", soon = true, desc = "An event horizon on a handle. Whatever it hits is gone." },
	{ key = "demon", name = "Demon King Hammer", rarity = "secret", soon = true, desc = "Horns, chains and a crown of fire. Forged in the deep." },
	-- DIVINE
	{ key = "galaxy", name = "Galaxy Hammer", rarity = "divine", model = "15", icon = "shop_15", desc = "A whole galaxy trapped in crystal." },
	{ key = "celestial", name = "Celestial Creator", rarity = "divine", soon = true, desc = "White marble, gold and a halo of light. The hammer that built the sky." },
	-- EXCLUSIVE (Exclusive Crate - Robux - and events only)
	{ key = "crown", name = "Royal Crown Hammer", rarity = "legendary", exclusive = true, soon = true, desc = "A jewelled crown for a head, red velvet grip. Exclusive." },
	{ key = "ghost", name = "Ghost Hammer", rarity = "mythic", exclusive = true, soon = true, desc = "Translucent and glowing, with wisps trailing behind. Exclusive." },
	{ key = "prism", name = "Rainbow Prism Hammer", rarity = "secret", exclusive = true, soon = true, desc = "A crystal prism that splits every hit into a rainbow. Exclusive." },
	{ key = "founder", name = "Founder's Hammer", rarity = "secret", exclusive = true, event = true, soon = true, desc = "Only given during the launch event. Never again." },
}
Hammers.ById = {}
for i, h in ipairs(Hammers.List) do
	h.order = i
	h.r = Hammers.RarityById[h.rarity].index           -- the ladder rarity: power, cooldown, trade-ups
	h.dr = Hammers.RarityById[h.show or h.rarity].index -- the rarity it is shown as (Index section, colours, filters)
	Hammers.ById[h.key] = h
end

-- crates: price in cash (scaled per zone, see Hammers.SupplyPrice), gems, or a Robux developer product (Store key)
-- odds = chance in % per rarity index 1..8 (they add up to 100). Pools by zone for the cash crate.
Hammers.Crates = {
	{ id = "supply", image = "rbxassetid://75330431497360", name = "Supply Crate", icon = "crate_supply", color = C3(255, 186, 60), cash = true,
		desc = "The builders' crate: Common to Epic in Town, Legendary from the Suburbs. It also drops while you build.",
		pools = {
			town = { 62, 28, 9, 1, 0, 0, 0, 0 },
			suburbs = { 30, 38, 22, 8, 2, 0, 0, 0 },
			downtown = { 0, 30, 40, 24, 6, 0, 0, 0 },
		} },
	{ id = "builder", image = "rbxassetid://104449117497713", name = "Builder's Crate", icon = "crate_builder", color = C3(70, 160, 255), gems = 150, product = "crate_builder",
		desc = "Uncommon or better, with a real shot at Legendary. 1 in 200 is Mythic.",
		odds = { 0, 45, 35, 15, 4.5, 0.5, 0, 0 } },
	{ id = "golden", image = "rbxassetid://108198116543312", name = "Golden Crate", icon = "crate_golden", color = C3(255, 206, 40), gems = 600, product = "crate_golden",
		desc = "Rare or better. Mythic, Secret and even Divine hammers live here. Pity: Legendary+ guaranteed every 20.",
		odds = { 0, 0, 40, 35, 18, 6, 0.9, 0.1 }, pity = { every = 20, min = 5 } },
	{ id = "exclusive", image = "rbxassetid://117610832518353", name = "Exclusive Crate", icon = "crate_exclusive", color = C3(255, 90, 200), product = "crate_exclusive", exclusiveOnly = true,
		desc = "Hammers nobody else can get: Legendary, Mythic and Secret exclusives. Pity: Secret guaranteed every 25.",
		odds = { 0, 0, 0, 0, 60, 32, 8, 0 }, pity = { every = 25, min = 7 } },
}
Hammers.CrateById = {}
for _, c in ipairs(Hammers.Crates) do Hammers.CrateById[c.id] = c end

-- the cash price of a Supply Crate: a share of the best contract you can take (never under 150)
function Hammers.SupplyPrice(bestReward) return math.max(150, math.floor((bestReward or 60) * 0.15)) end

function Hammers.Power(key, level)
	local h = Hammers.ById[key] or Hammers.ById.rusty
	level = math.clamp(math.floor(tonumber(level) or 1), 1, Hammers.MaxLevel)
	return Hammers.RarityStep ^ (h.r - 1) * (1 + Hammers.LevelStep * (level - 1))
end
function Hammers.Cooldown(key)
	local h = Hammers.ById[key] or Hammers.ById.rusty
	return Hammers.Rarities[h.r].cooldown
end
-- cash to raise a hammer from `level` to level + 1 (nil at the cap)
function Hammers.LevelCost(key, level)
	local h = Hammers.ById[key] or Hammers.ById.rusty
	level = math.floor(tonumber(level) or 1)
	if level >= Hammers.MaxLevel then return nil end
	return math.floor(Hammers.Rarities[h.r].levelBase * 1.6 ^ (level - 1))
end

-- the hammers a crate can drop at a rarity (only ones with a model; exclusives only from the exclusive crate)
function Hammers.PoolAt(crate, r)
	local out = {}
	for _, h in ipairs(Hammers.List) do
		if h.r == r and not h.soon and not h.event and not h.pass and h.key ~= Hammers.DefaultKey then
			if (crate.exclusiveOnly and h.exclusive) or (not crate.exclusiveOnly and not h.exclusive) then table.insert(out, h) end
		end
	end
	return out
end

-- odds of a crate as shown (per rarity, only rarities with something to drop), luck shifts weight to the rarer half
function Hammers.Odds(crateId, zone, luck)
	local c = Hammers.CrateById[crateId]
	if not c then return {} end
	local base = c.odds or (c.pools and (c.pools[zone] or c.pools.town)) or {}
	luck = luck or 1
	local w, total = {}, 0
	for r = 1, Hammers.LadderTop do
		local v = base[r] or 0
		if v > 0 and #Hammers.PoolAt(c, r) > 0 then
			if luck > 1 and r >= 3 then v *= luck end
			w[r] = v; total += v
		end
	end
	local out = {}
	for r, v in pairs(w) do out[r] = v / total * 100 end
	return out
end

-- roll one hammer. rng: a Random; pityHit: force at least rarity `min`
function Hammers.Roll(crateId, zone, rng, luck, pityMin)
	local c = Hammers.CrateById[crateId]
	local odds = Hammers.Odds(crateId, zone, luck)
	local total, best = 0, nil
	for r, v in pairs(odds) do
		if not pityMin or r >= pityMin then total += v; best = math.max(best or r, r) end
	end
	if total <= 0 then
		-- nothing at or above the pity floor exists: the best rarity the crate has
		for r in pairs(odds) do best = math.max(best or r, r) end
		if not best then return nil end
		local pool = Hammers.PoolAt(c, best)
		return pool[rng:NextInteger(1, #pool)].key, best
	end
	local x = rng:NextNumber() * total
	local pick
	for r = 1, Hammers.LadderTop do
		local v = odds[r]
		if v and (not pityMin or r >= pityMin) then
			x -= v
			if x <= 0 then pick = r break end
		end
	end
	pick = pick or best
	local pool = Hammers.PoolAt(c, pick)
	return pool[rng:NextInteger(1, #pool)].key, pick
end

-- Hammer Shop: three hammers of the day (Epic, Legendary, Mythic), the same for everyone, a new set every day at
-- 00:00 UTC. Bought with lots of Gems or with Robux (a developer product per tier, pointing at it by index). Only hammers
-- that exist in the game and drop from the normal crates are sold (never Exclusive, event, pass, Secret or Divine ones:
-- those stay rare). The shop shows them in one row with the Thunderclap (Robux only) last on the right.
Hammers.ShopTiers = {
	{ r = 4, gems = 1500, product = "hammer_epic", tag = "GREAT DEAL" },
	{ r = 5, gems = 6000, product = "hammer_legendary", tag = "POPULAR" },
	{ r = 6, gems = 20000, product = "hammer_mythic", tag = "ULTRA RARE" },
}
function Hammers.ShopDay(t) return math.floor((t or os.time()) / 86400) end
function Hammers.Featured(day)
	local out = {}
	for i, tier in ipairs(Hammers.ShopTiers) do
		local pool = {}
		for _, h in ipairs(Hammers.List) do
			if h.r == tier.r and not h.soon and not h.event and not h.pass and not h.exclusive and not h.show and h.key ~= Hammers.DefaultKey then
				table.insert(pool, h)
			end
		end
		table.sort(pool, function(a, b) return a.key < b.key end)
		if #pool > 0 then
			local rng = Random.new(day * 7919 + i * 104729)
			-- never the same hammer two days in a row (when there is a choice)
			local prev = Random.new((day - 1) * 7919 + i * 104729):NextInteger(1, #pool)
			local k = rng:NextInteger(1, #pool)
			if k == prev and #pool > 1 then k = k % #pool + 1 end
			out[i] = { key = pool[k].key, tier = i, r = tier.r, gems = tier.gems, product = tier.product, tag = tier.tag }
		end
	end
	return out
end
-- the offer for a hammer key today (or in the last minute of yesterday's set), nil if it isn't sold
function Hammers.ShopOffer(key, t)
	t = t or os.time()
	for _, day in ipairs({ Hammers.ShopDay(t), Hammers.ShopDay(t - 120) }) do
		for _, o in pairs(Hammers.Featured(day)) do if o.key == key then return o end end
	end
end

-- a short label for the power ("x1.35")
function Hammers.PowerLabel(key, level)
	local p = Hammers.Power(key, level)
	return "x" .. (p < 10 and string.format("%.2f", p):gsub("%.?0+$", "") or tostring(math.floor(p + 0.5)))
end

return Hammers
