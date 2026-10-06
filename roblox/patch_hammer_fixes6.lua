-- one-off patch (run in Edit): a player's very first crate is Uncommon or better (the welcome crate always feels like an upgrade)
-- (the reveal's "PITY: GUARANTEED" tag stays for the real pity only)
local HS = game.ServerScriptService.Game.HammerService
local h = HS.Source
if h:find("FirstCrateDone", 1, true) then return "already patched" end
local function replaceOnce(src, old, new)
	local a, b = src:find(old, 1, true)
	assert(a, "not found: " .. old:sub(1, 80))
	assert(not src:find(old, b + 1, true), "found twice: " .. old:sub(1, 80))
	return src:sub(1, a - 1) .. new .. src:sub(b + 1)
end
h = replaceOnce(h, [[	local key, r = Hammers.Roll(crateId, zone, rng, luck, pityMin)]], [[	local realPity = pityMin
	-- the first crate you ever open: Uncommon or better
	if not d.FirstCrateDone then pityMin = math.max(pityMin or 0, 2) end
	local key, r = Hammers.Roll(crateId, zone, rng, luck, pityMin)
	if key then d.FirstCrateDone = true end]])
h = replaceOnce(h, [[pity = pityMin ~= nil,]], [[pity = realPity ~= nil,]])
assert(loadstring(h), "compile")
HS.Source = h
return "fixes6: first crate Uncommon+"
