-- BlockRise 3.0 (tycoon prototype, PROTO3_V1, 2026-10-18) - the numbers and the layout of a plot.
-- A plot is 200 x 340 studs; its local frame: X to the right, Z away from the avenue (the back), the origin at the
-- middle of its front edge. Its Main Street runs down the middle (x = 0) and is poured one stretch at a time; the
-- lots line it on both sides. Every unlock is a button on the ground next to what it builds; buying one shows the
-- next ones (`after`). Money from the buildings piles up in the vault at the gate: walk over the gold pad to take it.
local T = {}

T.StartMoney = 0
T.PlotW, T.PlotD = 200, 340
T.Road = { half = 8, walk = 5 } -- the road's half width, the sidewalks' width

-- the stretches of Main Street (z from .. to)
T.Segs = { { 0, 116 }, { 116, 214 }, { 214, 340 } }

-- the lots: centre (x, z) and which way the building faces (toward the street)
T.Lots = {
	L1 = { x = -48, z = 44 }, R1 = { x = 48, z = 44 },
	L2 = { x = -48, z = 92 }, R2 = { x = 48, z = 92 },
	L3 = { x = -48, z = 140 }, R3 = { x = 48, z = 140 },
	L4 = { x = -48, z = 188 }, R4 = { x = 48, z = 188 },
	L5 = { x = -52, z = 246 }, R5 = { x = 52, z = 246 },
	L6 = { x = -52, z = 300 }, R6 = { x = 52, z = 300 },
}

-- the vault (the safe at the gate) and its pad
T.Vault = { x = 26, z = 10 }
T.VaultPad = { x = 18, z = 10 }

-- the buildings: income per second once built, how long the crew takes (seconds)
T.Buildings = {
	lemonade = { name = "Lemonade Stand", income = 1.5, time = 3 },
	coffee = { name = "Coffee Shop", income = 3, time = 4 },
	diner = { name = "Burger Diner", income = 6, time = 5 },
	townhouse = { name = "Townhouse", income = 10, time = 6 },
	apartment = { name = "Apartments", income = 18, time = 8 },
	bakery = { name = "Bakery", income = 28, time = 7 },
	office = { name = "Office Block", income = 45, time = 10 },
	bank = { name = "City Bank", income = 70, time = 9 },
	hotel = { name = "Grand Hotel", income = 110, time = 12 },
	cinema = { name = "Cinema", income = 170, time = 10 },
	tower = { name = "Sky Tower", income = 260, time = 16 },
	sky = { name = "Crown Skyscraper", income = 400, time = 20 },
}

-- the unlocks, in the order they open. kind: building (lot), road (seg), lamps (seg), park, fountain, worker.
-- at = where its button stands (x, z); bonus = income multiplier added (decorations)
T.Unlocks = {
	{ id = "stand", kind = "building", key = "lemonade", lot = "L1", price = 0, at = { -19, 44 } },
	{ id = "road1", kind = "road", seg = 1, label = "Main Street", price = 15, after = { "stand" }, at = { 0, 8 } },
	{ id = "coffee", kind = "building", key = "coffee", lot = "R1", price = 35, after = { "road1" }, at = { 19, 44 } },
	{ id = "lamps1", kind = "lamps", seg = 1, label = "Street Lamps", price = 60, bonus = 0.1, after = { "road1" }, at = { -19, 16 } },
	{ id = "diner", kind = "building", key = "diner", lot = "L2", price = 90, after = { "coffee" }, at = { -19, 92 } },
	{ id = "worker2", kind = "worker", label = "Hire a Builder", price = 120, after = { "coffee" }, at = { 40, 10 } },
	{ id = "town", kind = "building", key = "townhouse", lot = "R2", price = 160, after = { "diner" }, at = { 19, 92 } },
	{ id = "road2", kind = "road", seg = 2, label = "Main Street II", price = 300, after = { "town" }, at = { 0, 122 } },
	{ id = "park", kind = "park", label = "Pocket Park", price = 450, bonus = 0.1, after = { "road2" }, at = { -76, 112 } },
	{ id = "apart", kind = "building", key = "apartment", lot = "L3", price = 600, after = { "road2" }, at = { -19, 140 } },
	{ id = "bakery", kind = "building", key = "bakery", lot = "R3", price = 950, after = { "apart" }, at = { 19, 140 } },
	{ id = "worker3", kind = "worker", label = "Hire a Builder", price = 1200, after = { "bakery" }, at = { 50, 10 } },
	{ id = "office", kind = "building", key = "office", lot = "L4", price = 1600, after = { "bakery" }, at = { -19, 188 } },
	{ id = "fountain", kind = "fountain", label = "Fountain", price = 2000, bonus = 0.15, after = { "office" }, at = { 76, 112 } },
	{ id = "bank", kind = "building", key = "bank", lot = "R4", price = 2600, after = { "office" }, at = { 19, 188 } },
	{ id = "road3", kind = "road", seg = 3, label = "Main Street III", price = 4000, after = { "bank" }, at = { 0, 220 } },
	{ id = "lamps3", kind = "lamps", seg = 2, label = "Street Lamps", price = 3000, bonus = 0.1, after = { "road3" }, at = { -19, 214 } },
	{ id = "hotel", kind = "building", key = "hotel", lot = "L5", price = 6500, after = { "road3" }, at = { -19, 246 } },
	{ id = "cinema", kind = "building", key = "cinema", lot = "R5", price = 10000, after = { "hotel" }, at = { 19, 246 } },
	{ id = "tower", kind = "building", key = "tower", lot = "L6", price = 16000, after = { "cinema" }, at = { -19, 300 } },
	{ id = "sky", kind = "building", key = "sky", lot = "R6", price = 25000, after = { "tower" }, at = { 19, 300 } },
}
T.ById = {}
for i, u in ipairs(T.Unlocks) do
	u.order = i
	u.after = u.after or {}
	T.ById[u.id] = u
	if u.kind == "building" then
		local b = T.Buildings[u.key]
		u.label = u.label or b.name
		u.income = b.income
		u.time = b.time
	else
		u.time = u.kind == "road" and 3.5 or 2.5
	end
end

-- builders: how many at the start; each one more builds faster
T.StartWorkers = 1
T.WorkerSpeed = 0.35 -- +35% speed per extra builder

-- sounds (the live game's set)
T.Sounds = {
	Hammer = "rbxassetid://9120954412", Brick = "rbxassetid://9118609285", Wood = "rbxassetid://9120871244",
	Pour = "rbxassetid://9117934842", Metal = "rbxassetid://9125672726", Dig = "rbxassetid://9114083746",
	Coins = "rbxassetid://9113849583", Fanfare = "rbxassetid://1843946260", Chime = "rbxassetid://4612374036",
	Click = "rbxassetid://15051647685",
}

function T.Fmt(n)
	n = math.floor(n + 0.5)
	if n >= 1e12 then return string.format("%.2fT", n / 1e12) end
	if n >= 1e9 then return string.format("%.2fB", n / 1e9) end
	if n >= 1e6 then return string.format("%.2fM", n / 1e6) end
	if n >= 1e4 then return string.format("%.1fK", n / 1e3) end
	local s = tostring(n)
	local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (out:gsub("^,", ""))
end
function T.Money(n) return "$" .. T.Fmt(n) end

return T
