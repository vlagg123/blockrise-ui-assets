-- BlockRise Empire - hammers as items on the server: inventory, the Rusty default, equip, levels, crates, pity,
-- trade-up, the Thunderclap pass hammer, and the migration of the old tool tiers.
-- Every change goes through here (the client only asks); items have unique ids so trades can be logged and undone.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local HttpService = game:GetService("HttpService")
local Hammers = require(ReplicatedStorage.Shared.Hammers)
local Config = require(ReplicatedStorage.Shared.Config)

local M = {}
local ctx -- { S, sync, addMoney, addGems, feedback, saveSoon, saveData, remote, giveTool, bestUnlockedReward, zoneOf, luck, missionProgress }
local rng = Random.new()

local function int(v) return math.max(0, math.floor(tonumber(v) or 0)) end
local function newId() return HttpService:GenerateGUID(false):sub(1, 12) end

-- Data ---------------------------------------------------------------------------------------
function M.Sanitize(d)
	d.Hammers = type(d.Hammers) == "table" and d.Hammers or {}
	local clean = {}
	local seen = {}
	for _, it in ipairs(d.Hammers) do
		if type(it) == "table" and type(it.id) == "string" and Hammers.ById[it.k] and not seen[it.id] then
			seen[it.id] = true
			it.lv = math.clamp(int(it.lv) == 0 and 1 or int(it.lv), 1, Hammers.MaxLevel)
			table.insert(clean, it)
		end
	end
	d.Hammers = clean
	-- the Rusty Hammer is always there (never traded, never lost)
	local hasRusty = false
	for _, it in ipairs(d.Hammers) do if it.id == "rusty" then hasRusty = true; it.k = "rusty"; it.bound = true end end
	if not hasRusty then table.insert(d.Hammers, 1, { id = "rusty", k = "rusty", lv = 1, bound = true, s = "start", t = os.time() }) end
	d.Crates = type(d.Crates) == "table" and d.Crates or {}
	for _, c in ipairs(Hammers.Crates) do d.Crates[c.id] = int(d.Crates[c.id]) end
	d.HammerPity = type(d.HammerPity) == "table" and d.HammerPity or {}
	d.Index = type(d.Index) == "table" and d.Index or {}
	for _, it in ipairs(d.Hammers) do d.Index[it.k] = true end
	d.CrateProgress = int(d.CrateProgress)
	if type(d.EquipHammer) ~= "string" then d.EquipHammer = nil end
end

local function find(d, id)
	for i, it in ipairs(d.Hammers or {}) do if it.id == id then return it, i end end
end

local function better(a, b) -- a better than b?
	local ha, hb = Hammers.ById[a.k], Hammers.ById[b.k]
	if ha.r ~= hb.r then return ha.r > hb.r end
	return (a.lv or 1) > (b.lv or 1)
end

local RUSTY = { id = "rusty", k = "rusty", lv = 1, bound = true }
function M.Best(d)
	local best
	for _, it in ipairs(d.Hammers or {}) do if not best or better(it, best) then best = it end end
	return best or RUSTY
end

-- the hammer in your hand: the one you picked, else your best (never nil)
function M.Equipped(d)
	local it = d.EquipHammer and find(d, d.EquipHammer)
	if it then return it end
	return M.Best(d)
end

function M.BestRarity(d) return Hammers.ById[M.Best(d).k].r end

function M.Power(st)
	local it = M.Equipped(st.data)
	return Hammers.Power(it.k, it.lv)
end
function M.Cooldown(st) return Hammers.Cooldown(M.Equipped(st.data).k) end

-- what the client sees (attributes) + the legacy ToolTier (= best rarity index, kept for old checks and the Road)
function M.Publish(plr)
	local st = ctx.S[plr]
	if not st then return end
	local d = st.data
	local eq = M.Equipped(d)
	d.ToolTier = M.BestRarity(d)
	plr:SetAttribute("ToolTier", d.ToolTier)
	plr:SetAttribute("EquipKey", eq.k)
	plr:SetAttribute("EquipId", eq.id)
	plr:SetAttribute("EquipLevel", eq.lv or 1)
	plr:SetAttribute("EquipRarity", Hammers.ById[eq.k].r)
	plr:SetAttribute("HammerPower", Hammers.Power(eq.k, eq.lv))
	plr:SetAttribute("HammerCount", #d.Hammers)
	local total = 0
	for _, c in ipairs(Hammers.Crates) do
		plr:SetAttribute("Crate_" .. c.id, d.Crates[c.id] or 0)
		total += d.Crates[c.id] or 0
	end
	plr:SetAttribute("CrateTotal", total)
	plr:SetAttribute("SupplyPrice", Hammers.SupplyPrice(ctx.bestUnlockedReward(d)))
	plr:SetAttribute("CrateZone", ctx.zoneOf(d))
	local owned = 0
	for k in pairs(d.Index) do if Hammers.ById[k] then owned += 1 end end
	plr:SetAttribute("IndexCount", owned)
end

-- Items -----------------------------------------------------------------------------------------
-- add one hammer (returns the item), nil when the inventory is full
function M.Give(plr, st, key, src, extra)
	local d = st.data
	if not Hammers.ById[key] then return nil end
	if #d.Hammers >= Hammers.InventoryCap and not (extra and extra.force) then return nil, "Hammer bag full (" .. Hammers.InventoryCap .. "): trade up or trade some away" end
	local it = { id = newId(), k = key, lv = 1, s = src or "?", t = os.time() }
	if extra then for k2, v in pairs(extra) do if k2 ~= "force" then it[k2] = v end end end
	table.insert(d.Hammers, it)
	d.Index[key] = true
	return it
end

-- the Thunderclap pass: its hammer is a bound item while you own the pass (never tradeable, never duplicable)
function M.SyncPass(plr, st)
	local d = st.data
	local has = st.passes and st.passes.stormhammer == true
	local mine
	for _, it in ipairs(d.Hammers) do if it.k == "thunder" and it.pass then mine = it end end
	if has and not mine then
		local it = M.Give(plr, st, "thunder", "pass", { bound = true, pass = true, force = true })
		if it and not d.EquipHammer then d.EquipHammer = it.id end
	elseif not has and mine then
		for i, it in ipairs(d.Hammers) do if it == mine then table.remove(d.Hammers, i) break end end
		if d.EquipHammer == mine.id then d.EquipHammer = nil end
	end
end

-- old profiles: every tool tier they had becomes a hammer item (level 1), the best one is in hand, + a welcome crate
function M.Migrate(plr, st)
	local d = st.data
	if d.HammerV then return false end
	local tier = math.clamp(int(d.ToolTier), 1, #Config.Tools)
	for t = 2, tier do
		local cfg = Config.Tools[t]
		if cfg and Hammers.ById[cfg.key] then M.Give(plr, st, cfg.key, "migrate", { force = true }) end
	end
	d.EquipHammer = nil
	d.Crates.builder = (d.Crates.builder or 0) + 1
	d.HammerV = 1
	return true
end

-- Crates ------------------------------------------------------------------------------------------
function M.AddCrate(plr, st, crateId, n, reason)
	local c = Hammers.CrateById[crateId]
	if not c then return false end
	local d = st.data
	d.Crates[crateId] = (d.Crates[crateId] or 0) + int(n)
	M.Publish(plr)
	if reason ~= "silent" then ctx.feedback(plr, "Hammer", { kind = "crate", crate = crateId, n = int(n), reason = reason }) end
	return true
end

-- free crates: every 6th finished contract drops a Supply Crate, and 3% of contracts a Builder's Crate
function M.OnContract(plr, st)
	local d = st.data
	d.CrateProgress = (d.CrateProgress or 0) + 1
	if d.CrateProgress >= 6 then
		d.CrateProgress = 0
		M.AddCrate(plr, st, "supply", 1, "drop")
	elseif rng:NextNumber() < 0.03 * (ctx.luck and ctx.luck(st) or 1) then
		M.AddCrate(plr, st, "builder", 1, "drop")
	end
	plr:SetAttribute("CrateProgress", d.CrateProgress)
end

local function openOne(plr, st, crateId)
	local d = st.data
	local c = Hammers.CrateById[crateId]
	if not c then return false, "Unknown crate" end
	if (d.Crates[crateId] or 0) < 1 then return false, "You don't have that crate" end
	if #d.Hammers >= Hammers.InventoryCap then return false, "Hammer bag full (" .. Hammers.InventoryCap .. "): trade up or trade some away first" end
	local zone = ctx.zoneOf(d)
	local luck = ctx.luck and ctx.luck(st) or 1
	-- pity: after `every` opens without a rarity >= min, the next one is at least min
	local pityMin
	if c.pity then
		local n = (d.HammerPity[crateId] or 0) + 1
		if n >= c.pity.every then pityMin = c.pity.min end
		d.HammerPity[crateId] = n
	end
	local key, r = Hammers.Roll(crateId, zone, rng, luck, pityMin)
	if not key then return false, "Nothing in this crate yet (coming soon)" end
	if c.pity and r >= c.pity.min then d.HammerPity[crateId] = 0 end
	d.Crates[crateId] -= 1
	local isNew = not d.Index[key]
	local it = M.Give(plr, st, key, "crate:" .. crateId)
	if not it then return false, "Hammer bag full" end
	-- a better hammer than the one in hand goes straight into it (you never miss the upgrade)
	local eq = M.Equipped(d)
	if better(it, eq) and not d.EquipHammer then ctx.giveTool(plr) end
	if ctx.missionProgress then ctx.missionProgress(plr, "crates", 1) end
	return true, { id = it.id, key = key, r = r, lv = 1, crate = crateId, new = isNew, pity = pityMin ~= nil, pityLeft = c.pity and (c.pity.every - (d.HammerPity[crateId] or 0)) or nil }
end

-- Actions (client -> server) -------------------------------------------------------------------------
local actions = {}

function actions.get(plr, st)
	local d = st.data
	local list = {}
	for _, it in ipairs(d.Hammers) do
		table.insert(list, { id = it.id, k = it.k, lv = it.lv or 1, bound = it.bound == true, pass = it.pass == true, s = it.s })
	end
	local pity = {}
	for _, c in ipairs(Hammers.Crates) do if c.pity then pity[c.id] = c.pity.every - (d.HammerPity[c.id] or 0) end end
	local eq = M.Equipped(d)
	return true, { hammers = list, equip = eq.id, crates = d.Crates, pity = pity, index = d.Index, zone = ctx.zoneOf(d),
		supplyPrice = Hammers.SupplyPrice(ctx.bestUnlockedReward(d)), luck = ctx.luck and ctx.luck(st) or 1, progress = d.CrateProgress or 0 }
end

function actions.equip(plr, st, id)
	local d = st.data
	local it = type(id) == "string" and find(d, id)
	if not it then return false, "You don't have that hammer" end
	-- your best hammer is the default (no pick to remember); picking it clears the pick
	d.EquipHammer = (it == M.Best(d)) and nil or it.id
	ctx.giveTool(plr)
	M.Publish(plr)
	return true, { key = it.k, name = Hammers.ById[it.k].name }
end

function actions.levelup(plr, st, id)
	local d = st.data
	local it = type(id) == "string" and find(d, id)
	if not it then return false, "You don't have that hammer" end
	local cost = Hammers.LevelCost(it.k, it.lv)
	if not cost then return false, "Max level" end
	if d.Money < cost then return false, "Not enough cash" end
	it.lv += 1
	ctx.addMoney(plr, -cost, Hammers.ById[it.k].name .. " Lv " .. it.lv, true)
	ctx.feedback(plr, "Purchased", { name = Hammers.ById[it.k].name .. " Lv " .. it.lv, kind = "hammer",
		effect = string.format("Build power %s → %s", Hammers.PowerLabel(it.k, it.lv - 1), Hammers.PowerLabel(it.k, it.lv)) })
	if M.Equipped(d) == it then ctx.giveTool(plr) end
	M.Publish(plr)
	ctx.saveSoon(plr)
	return true, { lv = it.lv }
end

-- buy crates: the Supply Crate with cash (zone price), the others with Gems. Robux ones come through the Store.
function actions.buy(plr, st, crateId, n)
	local d = st.data
	local c = Hammers.CrateById[crateId]
	if not c then return false, "Unknown crate" end
	n = math.clamp(math.floor(tonumber(n) or 1), 1, 10)
	if c.cash then
		local price = Hammers.SupplyPrice(ctx.bestUnlockedReward(d)) * n
		if d.Money < price then return false, "Not enough cash" end
		ctx.addMoney(plr, -price, n .. "x " .. c.name, true)
	elseif c.gems then
		local price = c.gems * n
		if (d.Gems or 0) < price then return false, "Not enough Gems" end
		ctx.addGems(plr, -price, n .. "x " .. c.name)
	else
		return false, "This crate is only in the Store"
	end
	d.Crates[crateId] = (d.Crates[crateId] or 0) + n
	M.Publish(plr)
	ctx.saveSoon(plr)
	return true, { crates = d.Crates[crateId] }
end

function actions.open(plr, st, crateId)
	local ok, res = openOne(plr, st, crateId)
	if not ok then return false, res end
	M.Publish(plr)
	ctx.feedback(plr, "Hammer", { kind = "got", key = res.key, r = res.r, crate = crateId, new = res.new })
	ctx.saveSoon(plr)
	return true, res
end

-- 10 hammers of one rarity -> 1 of the next. Rusty, bound (pass) and exclusive hammers never go in; the one in your
-- hand is kept out when there are enough others.
function actions.tradeup(plr, st, rarity)
	local d = st.data
	local r = math.floor(tonumber(rarity) or 0)
	if r < 1 or r >= #Hammers.Rarities then return false, "Pick a rarity below Divine" end
	local eq = M.Equipped(d)
	local pool = {}
	for _, it in ipairs(d.Hammers) do
		local h = Hammers.ById[it.k]
		if h.r == r and not it.bound and not it.pass and not h.exclusive and not h.event and it.id ~= "rusty" then table.insert(pool, it) end
	end
	table.sort(pool, function(a, b)
		if (a == eq) ~= (b == eq) then return b == eq end -- the equipped one last
		return (a.lv or 1) < (b.lv or 1)
	end)
	if #pool < Hammers.TradeUpCount then return false, "You need " .. Hammers.TradeUpCount .. " " .. Hammers.Rarities[r].name .. " hammers (" .. #pool .. "/" .. Hammers.TradeUpCount .. ")" end
	local taken = {}
	for i = 1, Hammers.TradeUpCount do taken[pool[i]] = true end
	local kept = {}
	for _, it in ipairs(d.Hammers) do if not taken[it] then table.insert(kept, it) end end
	d.Hammers = kept
	if d.EquipHammer and not find(d, d.EquipHammer) then d.EquipHammer = nil end
	local fake = { exclusiveOnly = false }
	local poolUp = Hammers.PoolAt(fake, r + 1)
	if #poolUp == 0 then
		-- nothing exists at that rarity yet: give the 10 back
		for it in pairs(taken) do table.insert(d.Hammers, it) end
		return false, "No " .. Hammers.Rarities[r + 1].name .. " hammers exist yet (coming soon)"
	end
	local pick = poolUp[rng:NextInteger(1, #poolUp)]
	local isNew = not d.Index[pick.key]
	local it = M.Give(plr, st, pick.key, "tradeup", { force = true })
	ctx.giveTool(plr)
	M.Publish(plr)
	ctx.feedback(plr, "Hammer", { kind = "tradeup", key = pick.key, r = r + 1, new = isNew })
	if ctx.missionProgress then ctx.missionProgress(plr, "tradeups", 1) end
	ctx.saveSoon(plr)
	return true, { id = it.id, key = pick.key, r = r + 1, new = isNew }
end

function actions.odds(plr, st, crateId)
	local d = st.data
	return true, Hammers.Odds(crateId, ctx.zoneOf(d), ctx.luck and ctx.luck(st) or 1)
end

-- Trading hooks (TradeService) ------------------------------------------------------------------------
function M.CanTrade(d, id)
	local it = find(d, id)
	if not it then return false, "not yours" end
	if it.id == "rusty" or it.bound or it.pass then return false, "That hammer can't be traded" end
	return true, it
end
-- move an item between two players (the caller has checked both sides); unequips it if it was in hand
function M.Transfer(fromPlr, fromSt, toPlr, toSt, id)
	local it, i = find(fromSt.data, id)
	if not it then return false end
	if #toSt.data.Hammers >= Hammers.InventoryCap then return false end
	table.remove(fromSt.data.Hammers, i)
	if fromSt.data.EquipHammer == id then fromSt.data.EquipHammer = nil end
	table.insert(toSt.data.Hammers, it)
	toSt.data.Index[it.k] = true
	it.s = "trade"
	return true
end
function M.AfterTrade(plr)
	local st = ctx.S[plr]
	if not st then return end
	ctx.giveTool(plr)
	M.Publish(plr)
end

-- Init ---------------------------------------------------------------------------------------------
function M.Init(c)
	ctx = c
	local rf = c.remote("RemoteFunction", "HammerAction")
	M.Handler = function(plr, action, a, b)
		local st = ctx.S[plr]
		if not st or not st.data or not st.data.Hammers then return false, "Loading..." end
		local fn = type(action) == "string" and actions[action]
		if not fn then return false, "Unknown action" end
		if action ~= "get" and action ~= "odds" then
			if os.clock() - (st.lastHammerAction or 0) < 0.15 then return false, "Slow down!" end
			st.lastHammerAction = os.clock()
		end
		if ctx.isTrading and ctx.isTrading(plr) and action ~= "get" and action ~= "odds" then return false, "Finish your trade first" end
		local ok, r1, r2 = pcall(fn, plr, st, a, b)
		if not ok then warn("HammerAction error:", action, r1) return false, "Something went wrong" end
		return r1, r2
	end
	rf.OnServerInvoke = M.Handler
end

return M
