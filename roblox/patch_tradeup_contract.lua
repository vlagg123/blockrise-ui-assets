-- one-off patch (run in Edit): the trade-up is a contract you fill yourself (like CS:GO): the client sends the 10 item ids.
-- All 10 must be yours, different, tradeable (not Rusty, pass, exclusive or event) and of the same rarity below Divine.
-- Without ids it still picks for you (lowest levels first, the hammer in your hand last).
local function replaceOnce(src, old, new)
	local a, b = src:find(old, 1, true)
	assert(a, "not found: " .. old:sub(1, 80))
	assert(not src:find(old, b + 1, true), "found twice: " .. old:sub(1, 80))
	return src:sub(1, a - 1) .. new .. src:sub(b + 1)
end
local HS = game.ServerScriptService.Game.HammerService
local h = HS.Source
if h:find("the contract the player filled", 1, true) then return "already patched" end
h = replaceOnce(h, [[function actions.tradeup(plr, st, rarity)
	local d = st.data
	local r = math.floor(tonumber(rarity) or 0)
	if r < 1 or r >= #Hammers.Rarities then return false, "Pick a rarity below Divine" end
	local eq = M.Equipped(d)
	local pool = {}]], [[function actions.tradeup(plr, st, rarity, ids)
	local d = st.data
	local r = math.floor(tonumber(rarity) or 0)
	if r < 1 or r >= #Hammers.Rarities then return false, "Pick a rarity below Divine" end
	local eq = M.Equipped(d)
	local pool = {}
	if type(ids) == "table" then
		-- the contract the player filled: exactly these items
		if #ids ~= Hammers.TradeUpCount then return false, "Put exactly " .. Hammers.TradeUpCount .. " hammers in the contract" end
		local seen = {}
		for _, id in ipairs(ids) do
			if type(id) ~= "string" or seen[id] then return false, "Each hammer only once" end
			seen[id] = true
			local it = find(d, id)
			if not it then return false, "One of those hammers isn't yours any more" end
			local hd = Hammers.ById[it.k]
			if hd.r ~= r then return false, "All " .. Hammers.TradeUpCount .. " must be " .. Hammers.Rarities[r].name end
			if it.bound or it.pass or hd.exclusive or hd.event or it.id == "rusty" then return false, hd.name .. " can't be traded up" end
			table.insert(pool, it)
		end
	end
	if type(ids) ~= "table" then]])
h = replaceOnce(h, [[		if h.r == r and not it.bound and not it.pass and not h.exclusive and not h.event and it.id ~= "rusty" then table.insert(pool, it) end
	end]], [[		if h.r == r and not it.bound and not it.pass and not h.exclusive and not h.event and it.id ~= "rusty" then table.insert(pool, it) end
	end
	end]])
assert(loadstring(h), "compile HammerService")
HS.Source = h
return "trade-up contract patched"
