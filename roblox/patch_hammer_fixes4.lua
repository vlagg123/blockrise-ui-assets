-- one-off patch (run in Edit): the Supply Crate's price follows the same contracts as its odds (the ones you can take now,
-- crew and hammer included), and "Requires an Uncommon hammer" reads right
local function replaceOnce(src, old, new)
	local a, b = src:find(old, 1, true)
	assert(a, "not found: " .. old:sub(1, 80))
	assert(not src:find(old, b + 1, true), "found twice: " .. old:sub(1, 80))
	return src:sub(1, a - 1) .. new .. src:sub(b + 1)
end
local G = game.ServerScriptService.Game
local HS, Main = G.HammerService, G.Main
local m = Main.Source
if m:find("zoneReward = function", 1, true) then return "already patched" end
m = replaceOnce(m, [[	luck = function(st) return (st.passes and st.passes.luck) and 2 or 1 end,]], [[	-- the best reward of a contract you can take right now (the Supply Crate's price follows it, like its odds)
	zoneReward = function(d)
		local best = 60
		for _, c in ipairs(Config.Contracts) do
			if contractUnlocked(d, c) and c.reward > best then best = c.reward end
		end
		return best
	end,
	luck = function(st) return (st.passes and st.passes.luck) and 2 or 1 end,]])
m = replaceOnce(m, [[then return "Requires a " .. Hammers.Rarities[c.reqHammer].name .. " hammer or better]],
	[[then return "Requires " .. (Hammers.Rarities[c.reqHammer].name:match("^[AEIOU]") and "an " or "a ") .. Hammers.Rarities[c.reqHammer].name .. " hammer or better]])
assert(loadstring(m), "compile Main")

local h = HS.Source
local n
h, n = h:gsub("Hammers%.SupplyPrice%(ctx%.bestUnlockedReward%(d%)%)", "Hammers.SupplyPrice((ctx.zoneReward or ctx.bestUnlockedReward)(d))")
assert(n == 3, "SupplyPrice calls: " .. n)
assert(loadstring(h), "compile HammerService")
Main.Source = m
HS.Source = h
return "fixes4: supply price x" .. n
