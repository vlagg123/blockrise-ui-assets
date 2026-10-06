-- one-off patch (run in Edit): every building drops its own materials, in step with what you need at that point of
-- the road (Job Board shows them: "DROPS: Steel Beams 90% · Copper Wire 10%")
--   Town (no Rebirth): Steel Beams, then Copper Wire          -> founding the company, upgrades 4-9, sheds..shops
--   Suburbs (Rebirth 1): Copper -> Marble -> Gold, Diamond at the end -> upgrades 10-19, villas..distribution centers
--   Downtown (Rebirth 2+): Gold and Diamond Glass, more Diamond the later the building -> upgrades 20-30, towers
local CompanyM = game:GetService("ReplicatedStorage").Shared.Company
local s = CompanyM.Source
if s:find("DROPS_V2", 1, true) then return "already patched" end
local old = [==[function Company.DropTable(tier)
	tier = tier or 1
	if tier <= 3 then return { steel = 100 } end
	if tier <= 5 then return { steel = 75, copper = 25 } end
	if tier <= 7 then return { steel = 45, copper = 40, marble = 15 } end
	if tier <= 8 then return { copper = 50, marble = 40, gold = 10 } end
	if tier <= 10 then return { copper = 30, marble = 45, gold = 22, diamond = 3 } end
	return { marble = 35, gold = 45, diamond = 20 } -- Downtown
end]==]
local new = [==[-- DROPS_V2: what each building drops (by its place on the road, Config.Contracts order), in % of the finds
Company.Drops = {
	{ steel = 100 },                              -- 1  Repair Fence
	{ steel = 100 },                              -- 2  Garden Shed
	{ steel = 90, copper = 10 },                  -- 3  Brick Garage
	{ steel = 65, copper = 35 },                  -- 4  Small Family House
	{ steel = 40, copper = 60 },                  -- 5  Corner Shop
	{ copper = 65, marble = 35 },                 -- 6  Two-Story Villa        (Suburbs, Rebirth 1)
	{ copper = 45, marble = 55 },                 -- 7  Logistics Warehouse
	{ copper = 20, marble = 60, gold = 20 },      -- 8  Apartment Block
	{ marble = 55, gold = 45 },                   -- 9  Luxury Villa
	{ marble = 25, gold = 50, diamond = 25 },     -- 10 Distribution Center
	{ marble = 20, gold = 60, diamond = 20 },     -- 11 Glass Office Tower     (Downtown, Rebirth 2)
	{ gold = 65, diamond = 35 },                  -- 12 Grand Hotel
	{ gold = 55, diamond = 45 },                  -- 13 Skyscraper
	{ gold = 45, diamond = 55 },                  -- 14 Corporate HQ
	{ gold = 30, diamond = 70 },                  -- 15 Landmark Spire
}
function Company.DropTable(tier)
	tier = math.clamp(math.floor(tonumber(tier) or 1), 1, #Company.Drops)
	return Company.Drops[tier]
end]==]
local a, b = s:find(old, 1, true)
assert(a and not s:find(old, b + 1, true), "DropTable not found once")
s = s:sub(1, a - 1) .. new .. s:sub(b + 1)
assert(loadstring(s), "compile Company")
CompanyM.Source = s
return "drops v2"
