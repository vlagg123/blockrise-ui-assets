-- BlockRise Empire 2.0 - shared numbers (server + client). The economy comes from tools/econ/v2/sim.py in the repo:
-- Rebirth 1 in about 20 minutes, Rebirth 2 in about 3 hours, Rebirth 3 in about 15 hours of play.
local C = {}

C.Version = 2
C.MaxLevel = 10

-- the buildings of a lot, level 1..10: name, income per second (x1), cash to reach it, base build seconds.
-- STYLE_V1 (2026-10-18, the owner: new buildings in the live game's style, built piece by piece): every level has
-- two styles, each one a blueprint of ServerScriptService.Game2.Blueprints2; `name` is style 1's name.
C.Levels = {
	{ name = "Coffee Kiosk", income = 1, cost = 8, time = 5, styles = { { "Coffee Kiosk", "CoffeeKiosk" }, { "Flower Shop", "FlowerShop" } } },
	{ name = "Brick Cottage", income = 3, cost = 60, time = 10, styles = { { "Brick Cottage", "BrickCottage" }, { "Timber Cabin", "TimberCabin" } } },
	{ name = "Family Home", income = 8, cost = 750, time = 20, styles = { { "Family Home", "FamilyHome" }, { "Pizza Place", "PizzaPlace" } } },
	{ name = "Corner Market", income = 20, cost = 7200, time = 40, styles = { { "Corner Market", "CornerMarket" }, { "Police Station", "PoliceStation" } } },
	{ name = "Boutique Hotel", income = 50, cost = 39000, time = 60, styles = { { "Boutique Hotel", "BoutiqueHotel" }, { "Arcade", "Arcade" } } },
	{ name = "Apartment Block", income = 125, cost = 220000, time = 90, styles = { { "Apartment Block", "ApartmentBlock" }, { "Department Store", "DepartmentStore" } } },
	{ name = "Deco Hotel", income = 310, cost = 925000, time = 120, styles = { { "Deco Hotel", "DecoHotel" }, { "Tech HQ", "TechHQ" } } },
	{ name = "Residence Tower", income = 780, cost = 8500000, time = 180, styles = { { "Residence Tower", "ResidenceTower" }, { "Media Tower", "MediaTower" } } },
	{ name = "Crown Plaza", income = 1950, cost = 37500000, time = 240, styles = { { "Crown Plaza", "CrownPlaza" }, { "Twin Towers", "TwinTowers2" } } },
	{ name = "Sky Needle", income = 4900, cost = 142000000, time = 300, styles = { { "Sky Needle", "SkyNeedle" }, { "Twist Tower", "DiamondTower" } } },
}
-- the name and the blueprint of a level in a style (1 or 2)
function C.StyleOf(level, style)
	local L = C.Levels[level]
	if not L then return nil end
	local s = L.styles[style] or L.styles[1]
	return s[1], s[2]
end
-- the highest level you can build, by Rebirths (0, 1, 2+)
C.CapByRebirth = { [0] = 4, [1] = 7, [2] = 10 }
function C.Cap(rebirths) return C.CapByRebirth[math.min(tonumber(rebirths) or 0, 2)] end

-- land: each row has 2 blocks of 4 lots; row r opens at Rebirth r - 1; block "1_1" is free
C.BlockPrice = { ["1_1"] = 0, ["1_2"] = 300, ["2_1"] = 60000, ["2_2"] = 250000, ["3_1"] = 12000000, ["3_2"] = 40000000 }
C.RowNames = { "Town", "Suburbs", "Downtown" }
function C.RowOpen(row, rebirths) return (tonumber(rebirths) or 0) >= row - 1 end
C.BlockBonus = 0.25 -- a block whose 4 lots have the same level: +25% (its park appears)

-- Rebirth: the cash it costs (all open lots at the cap first); income x1.5 per Rebirth
C.RebirthCost = { 50000, 12000000, 1500000000 }
C.RebirthMult = 1.5
function C.RebirthMultiplier(rebirths) return C.RebirthMult ^ (tonumber(rebirths) or 0) end

-- the crew: you + 2 workers to start; hires for cash (+1 each); the build speed = crew power / 3
C.StartWorkers = 2
C.HirePrice = { 250, 2500, 25000, 250000 }
C.MaxWorkersShown = 6 -- NPCs in the city (more crew still counts, they just aren't all walking around)
C.BasePower = 3
C.QueueSize = 3
C.MinBuildSeconds = 3
C.TapPower = 0.6 -- one tap on a site = 0.6 x your hammer's power, in work units

-- offline: half your income, up to 8 hours (Night Shift: all of it, 12 hours)
C.OfflineShare = 0.5
C.OfflineHours = 8

function C.Fmt(n)
	n = tonumber(n) or 0
	local neg = n < 0
	n = math.abs(n)
	local s
	if n < 1000 then s = tostring(math.floor(n))
	else
		local units = { "K", "M", "B", "T", "Qa", "Qi" }
		local i = 0
		while n >= 1000 and i < #units do n /= 1000 i += 1 end
		if n >= 100 then s = tostring(math.floor(n))
		else
			s = n >= 10 and string.format("%.1f", math.floor(n * 10) / 10) or string.format("%.2f", math.floor(n * 100) / 100)
			s = (s:gsub("0+$", ""):gsub("%.$", ""))
		end
		s ..= units[i]
	end
	return (neg and "-" or "") .. s
end
function C.Money(n) return "$" .. C.Fmt(n) end

return C
