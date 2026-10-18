-- BlockRise 2.0 - Robux: game passes bought in game, developer products (ProcessReceipt) and the permanent Robux
-- ledger, ported from v1 Main (same ledger store, same rules): every purchase is granted exactly once, confirmed to
-- Roblox only once it is saved (profile + ledger), and whatever paid thing a profile is missing comes back on join.
-- 2.0 changes: cash packs pay minutes of your CITY income; the Starter Pack's cash = a Cash Vault (90 min).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")
local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")
local Config = require(ReplicatedStorage.Shared.Config)
local Hammers = require(ReplicatedStorage.Shared.Hammers)

local M = {}
local ctx

local function withRetry(fn, tries)
	local lastErr
	for i = 1, tries or 3 do
		local ok, res = pcall(fn)
		if ok then return true, res end
		lastErr = res
		if i < (tries or 3) then task.wait(i * 1.5) end
	end
	return false, lastErr
end

-- Passes -------------------------------------------------------------------------------------------------
local function grantPass(plr, passId)
	local st = ctx.S[plr]
	if not st then return false end
	for _, p in ipairs(Config.Store.passes) do
		if p.id == passId then
			st.passes = st.passes or {}
			st.passes[p.key] = true
			st.data.OwnedPasses = type(st.data.OwnedPasses) == "table" and st.data.OwnedPasses or {}
			st.data.OwnedPasses[p.key] = true
			plr:SetAttribute("Pass_" .. p.key, true)
			if ctx.crewChanged then ctx.crewChanged(plr, st) else ctx.sync(plr) end
			ctx.feedback(plr, "Purchased", { name = p.name, kind = "pass" })
			ctx.saveSoon(plr)
			return true
		end
	end
	return false
end

-- The permanent Robux ledger (NEVER rename LEDGER_NAME) ----------------------------------------------------
local LEDGER_NAME = "BlockRise_RobuxLedger"
local ledgerStore
if RunService:IsStudio() then
	-- Studio: an in-memory stand-in (the real code paths, no live data touched)
	local HS = game:GetService("HttpService")
	local mem = {}
	local function copy(v) return v ~= nil and HS:JSONDecode(HS:JSONEncode(v)) or nil end
	ledgerStore = {
		GetAsync = function(_, key) return copy(mem[key]) end,
		UpdateAsync = function(_, key, fn)
			local new = fn(copy(mem[key]))
			if new ~= nil then mem[key] = copy(new) end
			return copy(mem[key])
		end,
	}
else
	pcall(function() ledgerStore = DataStoreService:GetDataStore(LEDGER_NAME) end)
end

-- what one purchase of a product adds to the lasting totals
local function paidDelta(product)
	local dl = { gems = 0, spins = 0, boosts = {}, starter = false, crates = {} }
	if product.crate then dl.crates[product.crate] = product.count or 1 end
	if product.key == "starter" then
		dl.starter = true
		dl.gems = 600
		dl.boosts.cash = 1800
		dl.crates.builder = 1
		dl.crates.golden = 1
	elseif product.gems then dl.gems = product.gems
	elseif product.spins then dl.spins = product.spins
	elseif product.boost then dl.boosts[product.boost] = product.secs or 1800
	end
	return dl
end

local function paidOf(d)
	if type(d.Paid) ~= "table" then d.Paid = {} end
	local p = d.Paid
	p.gems = math.max(0, math.floor(tonumber(p.gems) or 0))
	p.spins = math.max(0, math.floor(tonumber(p.spins) or 0))
	p.boosts = type(p.boosts) == "table" and p.boosts or {}
	p.starter = p.starter == true
	p.crates = type(p.crates) == "table" and p.crates or {}
	return p
end

local function ledgerAdd(userId, purchaseId, product)
	if not ledgerStore then return true end -- no ledger at all: never block a purchase on it
	local dl = paidDelta(product)
	local ok = withRetry(function()
		ledgerStore:UpdateAsync("u_" .. userId, function(old)
			old = type(old) == "table" and old or {}
			old.ids = type(old.ids) == "table" and old.ids or {}
			if table.find(old.ids, purchaseId) then return nil end
			table.insert(old.ids, purchaseId)
			while #old.ids > 300 do table.remove(old.ids, 1) end
			old.gems = (tonumber(old.gems) or 0) + dl.gems
			old.spins = (tonumber(old.spins) or 0) + dl.spins
			old.boosts = type(old.boosts) == "table" and old.boosts or {}
			for k, secs in pairs(dl.boosts) do old.boosts[k] = (tonumber(old.boosts[k]) or 0) + secs end
			if dl.starter then old.starter = true end
			old.crates = type(old.crates) == "table" and old.crates or {}
			for k, n in pairs(dl.crates) do old.crates[k] = (tonumber(old.crates[k]) or 0) + n end
			if product.key == "rushcrew" then old.rushUntil = math.max(tonumber(old.rushUntil) or 0, os.time()) + Config.RushCrewTime end
			old.products = type(old.products) == "table" and old.products or {}
			old.products[product.key] = (tonumber(old.products[product.key]) or 0) + 1
			return old
		end)
	end, 3)
	return ok
end

-- on join: merge the purchase ids and give back whatever paid thing this profile is missing
function M.RestorePaid(plr, st)
	local d = st.data
	local p = paidOf(d)
	d.Receipts = type(d.Receipts) == "table" and d.Receipts or {}
	if not ledgerStore then return end
	local ok, led = withRetry(function() return ledgerStore:GetAsync("u_" .. plr.UserId) end, 3)
	if not ok or type(led) ~= "table" then return end
	for _, id in ipairs(type(led.ids) == "table" and led.ids or {}) do
		if not table.find(d.Receipts, id) then table.insert(d.Receipts, id) end
	end
	while #d.Receipts > 300 do table.remove(d.Receipts, 1) end
	local back = {}
	local g = math.floor(tonumber(led.gems) or 0) - p.gems
	if g > 0 then
		d.Gems = (tonumber(d.Gems) or 0) + g
		p.gems += g
		table.insert(back, g .. " Gems")
	end
	local sp = math.floor(tonumber(led.spins) or 0) - p.spins
	if sp > 0 then
		if type(d.Spin) ~= "table" then d.Spin = { last = 0, extra = 0 } end
		d.Spin.extra = (tonumber(d.Spin.extra) or 0) + sp
		p.spins += sp
		table.insert(back, sp .. (sp == 1 and " spin" or " spins"))
	end
	for k, secs in pairs(type(led.boosts) == "table" and led.boosts or {}) do
		local diff = (tonumber(secs) or 0) - (tonumber(p.boosts[k]) or 0)
		if diff > 0 and Config.Boosts[k] then
			d.Boosts = type(d.Boosts) == "table" and d.Boosts or {}
			d.Boosts[k] = (tonumber(d.Boosts[k]) or 0) + diff
			p.boosts[k] = (tonumber(p.boosts[k]) or 0) + diff
			table.insert(back, math.floor(diff / 60) .. " min " .. (Config.Boosts[k].name or k))
		end
	end
	if led.starter and not p.starter then
		d.StarterBought = true
		p.starter = true
	end
	for k, n in pairs(type(led.crates) == "table" and led.crates or {}) do
		local diff = math.floor(tonumber(n) or 0) - math.floor(tonumber(p.crates[k]) or 0)
		if diff > 0 and Hammers.CrateById[k] then
			ctx.HammerService.AddCrate(plr, st, k, diff, "silent")
			p.crates[k] = (tonumber(p.crates[k]) or 0) + diff
			table.insert(back, diff .. "x " .. Hammers.CrateById[k].name)
		end
	end
	for k, n in pairs(type(led.products) == "table" and led.products or {}) do
		if (tonumber(n) or 0) > 0 then
			for _, pr in ipairs(Config.Store.products) do
				if pr.key == k and pr.vehicle then
					d.Vehicles = type(d.Vehicles) == "table" and d.Vehicles or {}
					if not d.Vehicles[pr.vehicle] then d.Vehicles[pr.vehicle] = true end
				end
			end
		end
	end
	local rush = tonumber(led.rushUntil) or 0
	if rush > (tonumber(d.RushCrewUntil) or 0) then d.RushCrewUntil = rush end
	if #back > 0 then
		task.delay(8, function()
			if ctx.S[plr] == st then
				ctx.sync(plr)
				ctx.feedback(plr, "PaidRestored", { list = table.concat(back, ", ") })
				ctx.saveSoon(plr)
			end
		end)
	end
end

local function addBoost(plr, st, kind, secs)
	st.data.Boosts = type(st.data.Boosts) == "table" and st.data.Boosts or {}
	st.data.Boosts[kind] = (tonumber(st.data.Boosts[kind]) or 0) + (secs or 0)
	plr:SetAttribute("Boost_" .. kind, st.data.Boosts[kind])
end

local function processReceipt(info)
	local plr = Players:GetPlayerByUserId(info.PlayerId)
	local st = plr and ctx.S[plr]
	local studio = RunService:IsStudio()
	if not st or (not st.loaded and not studio) then return Enum.ProductPurchaseDecision.NotProcessedYet end
	local product
	for _, p in ipairs(Config.Store.products) do if p.id == info.ProductId then product = p end end
	if not product then return Enum.ProductPurchaseDecision.NotProcessedYet end
	st.data.Receipts = type(st.data.Receipts) == "table" and st.data.Receipts or {}
	if table.find(st.data.Receipts, info.PurchaseId) then
		if not ledgerAdd(plr.UserId, info.PurchaseId, product) then return Enum.ProductPurchaseDecision.NotProcessedYet end
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	local dl = paidDelta(product)
	local paid = paidOf(st.data)
	local perMin = (ctx.incomeOf and ctx.incomeOf(st) or 0) * 60
	if product.offline2x then
		-- the cash your city made while you were away, once more
		local got = math.max(0, math.floor(tonumber(st.data.OfflineLast) or 0))
		if got > 0 and not st.data.OfflineLastDoubled then ctx.addMoney(plr, got, product.name) st.data.OfflineLastDoubled = true end
	elseif product.key == "rushcrew" then
		st.data.RushCrewUntil = math.max(os.time(), st.data.RushCrewUntil or 0) + Config.RushCrewTime
		plr:SetAttribute("RushCrewEnds", workspace:GetServerTimeNow() + (st.data.RushCrewUntil - os.time()))
		if ctx.crewChanged then ctx.crewChanged(plr, st) end
	elseif product.vehicle then
		st.data.Vehicles = type(st.data.Vehicles) == "table" and st.data.Vehicles or {}
		st.data.Vehicles[product.vehicle] = true
	elseif product.hammerTier then
		ctx.HammerService.GrantShopHammer(plr, st, product.hammerTier)
	elseif product.crate then
		ctx.HammerService.AddCrate(plr, st, product.crate, product.count or 1, "robux")
	elseif product.key == "starter" then
		st.data.StarterBought = true
		plr:SetAttribute("Bought_starter", true)
		ctx.HammerService.AddCrate(plr, st, "builder", 1, "robux")
		ctx.HammerService.AddCrate(plr, st, "golden", 1, "robux")
		ctx.addGems(plr, dl.gems, product.name)
		ctx.addMoney(plr, math.max(500, math.floor(perMin * 90)), product.name)
		addBoost(plr, st, "cash", dl.boosts.cash)
	elseif product.minutes or product.cash then
		-- 2.0: minutes of your city's income right now (at least a little, for a brand new city)
		ctx.addMoney(plr, math.max(100 * (product.minutes or 20), math.floor(perMin * (product.minutes or 20))), product.name)
	elseif product.gems then
		ctx.addGems(plr, dl.gems, product.name)
	elseif product.boost then
		addBoost(plr, st, product.boost, dl.boosts[product.boost])
	elseif product.spins then
		if type(st.data.Spin) ~= "table" then st.data.Spin = { last = 0, extra = 0 } end
		st.data.Spin.extra = (tonumber(st.data.Spin.extra) or 0) + dl.spins
	end
	paid.gems += dl.gems
	paid.spins += dl.spins
	for k, secs in pairs(dl.boosts) do paid.boosts[k] = (tonumber(paid.boosts[k]) or 0) + secs end
	if dl.starter then paid.starter = true end
	for k, n in pairs(dl.crates) do paid.crates[k] = (tonumber(paid.crates[k]) or 0) + n end
	table.insert(st.data.Receipts, info.PurchaseId)
	while #st.data.Receipts > 300 do table.remove(st.data.Receipts, 1) end
	ctx.sync(plr)
	ctx.feedback(plr, "Purchased", { name = product.name, kind = "product" })
	-- only confirmed to Roblox once it is safely saved (profile + ledger); otherwise Roblox tries again later
	if not studio and not ctx.saveData(plr, false, true) then return Enum.ProductPurchaseDecision.NotProcessedYet end
	if not ledgerAdd(plr.UserId, info.PurchaseId, product) then return Enum.ProductPurchaseDecision.NotProcessedYet end
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

function M.Init(c)
	ctx = c
	MarketplaceService.ProcessReceipt = processReceipt
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(plr, passId, purchased)
		if purchased then grantPass(plr, passId) end
	end)
end

-- (on join, after the profile loaded) the passes kept in the profile, the Starter Pack flag
function M.OnJoin(plr, st)
	local d = st.data
	plr:SetAttribute("Bought_starter", d.StarterBought == true)
	task.spawn(M.RestorePaid, plr, st)
end

return M
