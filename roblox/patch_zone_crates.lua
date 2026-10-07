-- one-off patch (run in Edit): every zone has its own Supply Crate (Town, Suburbs, Downtown). They are separate items:
-- they don't stack together, the Shop sells (and counts) only the crate of the zone you build in, and the ones from
-- older zones stay in your Inventory and open with their own zone's odds (before, a Supply Crate opened with the odds
-- of the zone you were in when you opened it)
--  * Hammers: the one "supply" crate with odds by zone becomes three crates (id "supply" stays the Town one, so the
--    tutorial and old saves keep working); Hammers.SupplyFor(zone) = the id of a zone's crate
--  * HammerService: the free crate every 6 contracts is the zone's one; buying: only the zone's one; opening: the
--    crate's own zone; your Supply Crates from before become the crates of the zone you are in (once: they always
--    opened with that zone's odds, so nothing changes for them)
local function replaceOnce(src, old, new)
	local a, b = src:find(old, 1, true)
	assert(a, "not found: " .. old:sub(1, 80))
	assert(not src:find(old, b + 1, true), "found twice: " .. old:sub(1, 80))
	return src:sub(1, a - 1) .. new .. src:sub(b + 1)
end
local report = {}

local HM = game.ReplicatedStorage.Shared.Hammers
local h = HM.Source
if not h:find("SupplyFor", 1, true) then
	h = replaceOnce(h, [=[-- odds = chance in % per rarity index 1..8 (they add up to 100). Pools by zone for the cash crate.
Hammers.Crates = {
	{ id = "supply", image = "rbxassetid://81484084637371", name = "Supply Crate", icon = "crate_supply", color = C3(255, 186, 60), cash = true,
		desc = "The builders' crate: Common to Epic in Town, Legendary from the Suburbs. It also drops while you build.",
		pools = {
			town = { 62, 28, 9, 1, 0, 0, 0, 0 },
			suburbs = { 30, 38, 22, 8, 2, 0, 0, 0 },
			downtown = { 0, 30, 40, 24, 6, 0, 0, 0 },
		} },]=], [=[-- odds = chance in % per rarity index 1..8 (they add up to 100).
-- ZONE_CRATES: every zone has its own Supply Crate (family "supply"): they don't stack together, the Shop sells the one of
-- the zone you build in, and each opens with its own zone's odds wherever you are
Hammers.Crates = {
	{ id = "supply", zone = "town", family = "supply", image = "rbxassetid://81484084637371", name = "Town Supply Crate", icon = "crate_supply", color = C3(255, 186, 60), cash = true,
		desc = "The Town's builders' crate: Common to Epic. It also drops while you build in the Town.",
		odds = { 62, 28, 9, 1, 0, 0, 0, 0 } },
	{ id = "supply_suburbs", zone = "suburbs", family = "supply", image = "rbxassetid://81484084637371", name = "Suburbs Supply Crate", icon = "crate_supply", color = C3(110, 200, 90), cash = true,
		desc = "The Suburbs' builders' crate: Common to Legendary. It also drops while you build in the Suburbs.",
		odds = { 30, 38, 22, 8, 2, 0, 0, 0 } },
	{ id = "supply_downtown", zone = "downtown", family = "supply", image = "rbxassetid://81484084637371", name = "Downtown Supply Crate", icon = "crate_supply", color = C3(80, 150, 255), cash = true,
		desc = "Downtown's builders' crate: Uncommon to Legendary. It also drops while you build Downtown.",
		odds = { 0, 30, 40, 24, 6, 0, 0, 0 } },]=])
	h = replaceOnce(h, [=[for _, c in ipairs(Hammers.Crates) do Hammers.CrateById[c.id] = c end
]=], [=[for _, c in ipairs(Hammers.Crates) do Hammers.CrateById[c.id] = c end
-- the Supply Crate of a zone (the Town's when the zone has none)
function Hammers.SupplyFor(zone)
	for _, c in ipairs(Hammers.Crates) do if c.family == "supply" and c.zone == zone then return c.id end end
	return "supply"
end
Hammers.ZoneLabel = { town = "TOWN", suburbs = "SUBURBS", downtown = "DOWNTOWN" }
]=])
	local f = assert(loadstring(h), "Hammers compile")
	local t = f()
	assert(t.CrateById.supply_suburbs and t.SupplyFor("downtown") == "supply_downtown" and t.SupplyFor("town") == "supply", "Hammers check")
	assert(next(t.Odds("supply_suburbs", "town", 1)) ~= nil, "Hammers odds")
	HM.Source = h
	table.insert(report, "Hammers: 3 Supply Crates")
else
	table.insert(report, "Hammers: already")
end

local HS = game.ServerScriptService.Game.HammerService
local s = HS.Source
if not s:find("ZONE_CRATES", 1, true) then
	-- Publish: the crates from before move to your zone's crate (once); the client knows which one the Shop sells
	s = replaceOnce(s, [=[	ready(d)
	local eq = M.Equipped(d)
	d.ToolTier = M.BestRarity(d)]=], [=[	ready(d)
	-- ZONE_CRATES: the Supply Crates from before every zone had its own become the crates of the zone you are in (once:
	-- they always opened with that zone's odds, so nothing changes for them)
	if not d.CrateZoneV then
		d.CrateZoneV = 1
		local okZ, zid = pcall(function() return Hammers.SupplyFor(ctx.zoneOf(d)) end)
		if okZ and zid and zid ~= "supply" and (d.Crates.supply or 0) > 0 then
			d.Crates[zid] = (d.Crates[zid] or 0) + d.Crates.supply
			d.Crates.supply = 0
		end
	end
	local eq = M.Equipped(d)
	d.ToolTier = M.BestRarity(d)]=])
	s = replaceOnce(s, [=[	plr:SetAttribute("CrateZone", ctx.zoneOf(d))]=], [=[	plr:SetAttribute("CrateZone", ctx.zoneOf(d))
	plr:SetAttribute("SupplyCrate", Hammers.SupplyFor(ctx.zoneOf(d)))]=])
	-- the free crate every 6 contracts: the one of your zone
	s = replaceOnce(s, [=[		M.AddCrate(plr, st, "supply", 1, "drop")]=], [=[		M.AddCrate(plr, st, Hammers.SupplyFor(ctx.zoneOf(d)), 1, "drop")]=])
	-- opening: the crate's own zone
	s = replaceOnce(s, [=[	local zone = ctx.zoneOf(d)
	local luck = ctx.luck and ctx.luck(st) or 1
	-- pity]=], [=[	local zone = c.zone or ctx.zoneOf(d)
	local luck = ctx.luck and ctx.luck(st) or 1
	-- pity]=])
	-- buying: only the Supply Crate of the zone you build in
	s = replaceOnce(s, [=[		if crateId ~= "supply" or n ~= 1 or (tonumber(d.Road) or 1) ~= 1 or (d.Crates.supply or 0) > 0 then return false, "🔒 More crates after the tutorial" end
	end]=], [=[		if crateId ~= "supply" or n ~= 1 or (tonumber(d.Road) or 1) ~= 1 or (d.Crates.supply or 0) > 0 then return false, "🔒 More crates after the tutorial" end
	end
	if c.family == "supply" and c.id ~= Hammers.SupplyFor(ctx.zoneOf(d)) then return false, "The Shop sells the Supply Crate of the zone you build in" end]=])
	s = replaceOnce(s, [=[index = d.Index, zone = ctx.zoneOf(d),]=], [=[index = d.Index, zone = ctx.zoneOf(d), supplyId = Hammers.SupplyFor(ctx.zoneOf(d)),]=])
	assert(loadstring(s), "HammerService compile")
	HS.Source = s
	table.insert(report, "HammerService: zone crates")
else
	table.insert(report, "HammerService: already")
end
return table.concat(report, " · ")
