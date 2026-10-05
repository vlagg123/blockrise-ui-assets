-- one-off patch (run in Edit): hammers can be traded (TradeService + HammerService)
--  * an offer can hold up to 6 hammers (by item id); the Rusty Hammer and pass hammers never can
--  * adding or removing a hammer locks READY for 3 seconds for both players (no last-second swaps)
--  * the swap checks both bags have room, takes every hammer out first and then puts them in (never half a trade)
--  * the trade log names the hammers; both players get their tool and attributes refreshed
local function replaceOnce(src, old, new)
	local a, b = src:find(old, 1, true)
	assert(a, "not found: " .. old:sub(1, 80))
	assert(not src:find(old, b + 1, true), "found twice: " .. old:sub(1, 80))
	return src:sub(1, a - 1) .. new .. src:sub(b + 1)
end
local G = game.ServerScriptService.Game
local TS, HS = G.TradeService, G.HammerService
local t, h = TS.Source, HS.Source
if t:find("hams", 1, true) then return "already patched" end
local bk = game.ServerStorage:FindFirstChild("Backup_pre_hammers")
if bk and not bk:FindFirstChild("HammerService") then HS:Clone().Parent = bk end

-- HammerService: take out / put in (used by the trade swap)
h = replaceOnce(h, [[function M.AfterTrade(plr)]], [[-- the trade swap: take an item out of a bag (returns it), put it in another one
function M.Take(st, id)
	local it, i = find(st.data, id)
	if not it then return nil end
	table.remove(st.data.Hammers, i)
	if st.data.EquipHammer == id then st.data.EquipHammer = nil end
	return it
end
function M.Put(st, it)
	table.insert(st.data.Hammers, it)
	st.data.Index[it.k] = true
	it.s = "trade"
	it.t = os.time()
end
function M.Item(d, id) return (find(d, id)) end
function M.AfterTrade(plr)]])

-- TradeService
t = replaceOnce(t, [[local Config = require(ReplicatedStorage.Shared.Config)
]], [[local Config = require(ReplicatedStorage.Shared.Config)
local Hammers = require(ReplicatedStorage.Shared.Hammers)
local HammerService = require(script.Parent:WaitForChild("HammerService"))
]])
t = replaceOnce(t, [[M.Countdown = 5
]], [[M.Countdown = 5
M.MaxHammers = 6
M.HammerLock = 3 -- seconds READY is locked after a hammer is added or removed
]])
t = replaceOnce(t, [[local function emptyOffer() return { mats = {}, bps = {}, cash = 0 } end]], [[local function emptyOffer() return { mats = {}, bps = {}, cash = 0, hams = {} } end]])
t = replaceOnce(t, [[	if (d.Money or 0) < offer.cash then return false end
	return true]], [[	if (d.Money or 0) < offer.cash then return false end
	for _, hm in ipairs(offer.hams or {}) do
		local ok, it = HammerService.CanTrade(d, hm.id)
		if not ok or it.k ~= hm.k then return false end
	end
	return true]])
t = replaceOnce(t, [[	return next(o.mats) == nil and next(o.bps) == nil and (o.cash or 0) <= 0]], [[	return next(o.mats) == nil and next(o.bps) == nil and (o.cash or 0) <= 0 and #(o.hams or {}) == 0]])
t = replaceOnce(t, [[	if (o.cash or 0) > 0 then table.insert(parts, Config.FormatMoney(o.cash)) end
	return #parts > 0]], [[	for _, hm in ipairs(o.hams or {}) do
		local hd = Hammers.ById[hm.k]
		if hd then table.insert(parts, hd.name .. " Lv" .. (hm.lv or 1)) end
	end
	if (o.cash or 0) > 0 then table.insert(parts, Config.FormatMoney(o.cash)) end
	return #parts > 0]])
t = replaceOnce(t, [[	if not offerValid(sa, oa) or not offerValid(sb, ob) then close(s, "Items changed - trade cancelled") return end]],
	[[	if not offerValid(sa, oa) or not offerValid(sb, ob) then close(s, "Items changed - trade cancelled") return end
	-- both hammer bags must have room after the swap
	local na, nb = #(oa.hams or {}), #(ob.hams or {})
	if #sa.data.Hammers - na + nb > Hammers.InventoryCap then close(s, s.a.DisplayName .. "'s hammer bag is full - trade cancelled") return end
	if #sb.data.Hammers - nb + na > Hammers.InventoryCap then close(s, s.b.DisplayName .. "'s hammer bag is full - trade cancelled") return end]])
t = replaceOnce(t, [[	move(sa, sb, oa)
	move(sb, sa, ob)]], [[	move(sa, sb, oa)
	move(sb, sa, ob)
	-- hammers: every one out first, then in (an item can never be in two bags, or in none)
	local toB, toA = {}, {}
	for _, hm in ipairs(oa.hams or {}) do local it = HammerService.Take(sa, hm.id); if it then table.insert(toB, it) end end
	for _, hm in ipairs(ob.hams or {}) do local it = HammerService.Take(sb, hm.id); if it then table.insert(toA, it) end end
	for _, it in ipairs(toB) do HammerService.Put(sb, it) end
	for _, it in ipairs(toA) do HammerService.Put(sa, it) end]])
t = replaceOnce(t, [[	ctx.afterTrade(s.a)
	ctx.afterTrade(s.b)]], [[	ctx.afterTrade(s.a)
	ctx.afterTrade(s.b)
	pcall(HammerService.AfterTrade, s.a)
	pcall(HammerService.AfterTrade, s.b)]])
t = replaceOnce(t, [[	elseif kind == "cash" then
		o.cash = math.min(qty, math.floor(d.Money or 0))]], [[	elseif kind == "cash" then
		o.cash = math.min(qty, math.floor(d.Money or 0))
	elseif kind == "ham" then
		-- id = the hammer item, qty 1 = put it in, 0 = take it out
		if type(id) ~= "string" then return false, "Unknown hammer" end
		o.hams = o.hams or {}
		local at
		for i, hm in ipairs(o.hams) do if hm.id == id then at = i end end
		if qty > 0 then
			if at then return true end
			local ok, it = HammerService.CanTrade(d, id)
			if not ok then return false, it end
			if #o.hams >= M.MaxHammers then return false, "Up to " .. M.MaxHammers .. " hammers per trade" end
			table.insert(o.hams, { id = it.id, k = it.k, lv = it.lv or 1 })
		else
			if not at then return true end
			table.remove(o.hams, at)
		end
		s.lockUntil = os.clock() + M.HammerLock]])
t = replaceOnce(t, [[	if on and offerEmpty(s.offers[s.a]) and offerEmpty(s.offers[s.b]) then return false, "Add something to the trade first" end]],
	[[	if on and offerEmpty(s.offers[s.a]) and offerEmpty(s.offers[s.b]) then return false, "Add something to the trade first" end
	if on and s.lockUntil and os.clock() < s.lockUntil then return false, "A hammer just changed: look at the offer first (" .. math.ceil(s.lockUntil - os.clock()) .. "s)" end]])
t = replaceOnce(t, [[		version = s.version, fee = M.CashFee,]], [[		version = s.version, fee = M.CashFee, lock = s.lockUntil and math.max(0, s.lockUntil - os.clock()) or 0,]])

assert(loadstring(h), "compile HammerService")
assert(loadstring(t), "compile TradeService")
HS.Source = h
TS.Source = t
return "trade hammers patched"
