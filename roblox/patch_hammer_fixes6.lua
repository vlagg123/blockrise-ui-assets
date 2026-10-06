-- one-off patch (run in Edit): a player's very first crate is Uncommon or better (the welcome crate always feels like an upgrade)
local HS = game.ServerScriptService.Game.HammerService
local h = HS.Source
if h:find("FirstCrateDone", 1, true) then return "already patched" end
local old = [[	local key, r = Hammers.Roll(crateId, zone, rng, luck, pityMin)]]
local a, b = h:find(old, 1, true)
assert(a and not h:find(old, b + 1, true), "roll line")
h = h:sub(1, a - 1) .. [[	-- the first crate you ever open: Uncommon or better
	if not d.FirstCrateDone then pityMin = math.max(pityMin or 0, 2) end
	local key, r = Hammers.Roll(crateId, zone, rng, luck, pityMin)
	if key then d.FirstCrateDone = true end]] .. h:sub(b + 1)
assert(loadstring(h), "compile")
HS.Source = h
return "fixes6: first crate Uncommon+"
