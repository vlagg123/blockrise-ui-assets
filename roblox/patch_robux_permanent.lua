-- one-off patch (run in Edit): everything bought with Robux stays forever (rebirths, updates, even a progress reset).
--  * Game passes: asked from Roblox on every join (with retries); the passes we have seen you own are remembered
--    in your save, so a Roblox hiccup never takes a pass away for a session (and it is asked again a minute later).
--  * Developer products: besides your save, every purchase is written to a separate permanent DataStore
--    ("BlockRise_RobuxLedger") that is never reset. On join, paid Gems / spins / boost time / the Starter Pack flag /
--    Rush Crew time that your profile is missing are given back, and the purchase ids are merged so Roblox can never
--    grant the same purchase twice. Cash packs are run money (Rebirth resets money by design) and are not given back.
--  * Server shutdown (update restarts) waits until every save has finished instead of a fixed 5 seconds.
local Main = game.ServerScriptService.Game.Main
local s = Main.Source
if s:find("BlockRise_RobuxLedger", 1, true) then return "already patched" end

local function replaceOnce(src, old, new)
	local a, b = src:find(old, 1, true)
	assert(a, "not found: " .. old:sub(1, 80))
	assert(not src:find(old, b + 1, true), "found twice: " .. old:sub(1, 80))
	return src:sub(1, a - 1) .. new .. src:sub(b + 1)
end
-- replaces everything from the start of `first` to the end of `last`
local function replaceBetween(src, first, last, new)
	local a = src:find(first, 1, true)
	assert(a, "not found: " .. first:sub(1, 80))
	assert(not src:find(first, a + 1, true), "found twice: " .. first:sub(1, 80))
	local _, b = src:find(last, a, true)
	assert(b, "end not found: " .. last:sub(1, 80))
	return src:sub(1, a - 1) .. new .. src:sub(b + 1)
end

-- 1) forward declaration
s = replaceOnce(s, "local checkPasses, vipTag, syncRushCrew -- defined in the store section",
	"local checkPasses, vipTag, syncRushCrew, restorePaid -- defined in the store section")

-- 2) on join: give back anything paid that the profile is missing (before anything reads the data)
s = replaceOnce(s, [[	CompanyService.Sanitize(st.data)
	RebirthService.Sanitize(st.data)
	st.premium = plr.MembershipType == Enum.MembershipType.Premium]], [[	-- Robux purchases also live in a permanent ledger: anything this profile is missing comes back here
	restorePaid(plr, st)
	CompanyService.Sanitize(st.data)
	RebirthService.Sanitize(st.data)
	st.premium = plr.MembershipType == Enum.MembershipType.Premium]])

-- 3) game passes: retries + remembered ownership as a fallback
s = replaceBetween(s, "checkPasses = function(plr)", [[	applyPasses(plr)
end
]], [[checkPasses = function(plr)
	local st = S[plr]
	if not st then return end
	st.passes = st.passes or {}
	local d = st.data
	d.OwnedPasses = type(d.OwnedPasses) == "table" and d.OwnedPasses or {}
	local failed = false
	for _, p in ipairs(Config.Store.passes) do
		if p.id and p.id > 0 then
			local ok, owns = withRetry(function() return MarketplaceService:UserOwnsGamePassAsync(plr.UserId, p.id) end, 3)
			if S[plr] ~= st then return end
			if ok and owns then
				st.passes[p.key] = true
				d.OwnedPasses[p.key] = true
			elseif ok then
				-- Roblox says no (e.g. a refunded pass); a pass bought in this session stays (the answer can lag)
				if not st.passes[p.key] then d.OwnedPasses[p.key] = nil end
			else
				-- Roblox couldn't answer: keep a pass we have seen them own, and ask again in a minute
				if d.OwnedPasses[p.key] then st.passes[p.key] = true end
				failed = true
			end
		end
	end
	applyPasses(plr)
	if failed and not st.passRecheck then
		st.passRecheck = true
		task.delay(60, function()
			if S[plr] == st then
				st.passRecheck = false
				checkPasses(plr)
			end
		end)
	end
end
]])

s = replaceOnce(s, [[		if p.id == passId then
			st.passes[p.key] = true
			applyPasses(plr)]], [[		if p.id == passId then
			st.passes[p.key] = true
			st.data.OwnedPasses = type(st.data.OwnedPasses) == "table" and st.data.OwnedPasses or {}
			st.data.OwnedPasses[p.key] = true
			applyPasses(plr)]])

-- 4) developer products: the permanent ledger + restore + a receipt flow that records into both
s = replaceBetween(s, "local function processReceipt(info)", "MarketplaceService.ProcessReceipt = processReceipt", [==[-- Permanent Robux ledger -----------------------------------------------------------------
-- Every developer product bought is also written to its own DataStore that is NEVER reset (a progress reset only
-- moves the progress store). It keeps the purchase ids and the totals of what lasts: Gems, extra spins, boost time,
-- the Starter Pack flag and the Rush Crew end time. The profile counts what it already got from it (data.Paid), so
-- on join anything missing is given back exactly once. NEVER rename LEDGER_NAME.
local LEDGER_NAME = "BlockRise_RobuxLedger"
local ledgerStore
if RunService:IsStudio() then
	-- Studio: an in-memory stand-in, so the real code paths can be tested without touching live data
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
		_mem = mem,
	}
else
	pcall(function() ledgerStore = DataStoreService:GetDataStore(LEDGER_NAME) end)
end

-- what one purchase of a product adds to the lasting totals
local function paidDelta(product)
	local dl = { gems = 0, spins = 0, boosts = {}, starter = false }
	if product.key == "starter" then
		dl.starter = true
		dl.gems = 500
		dl.boosts.cash = 1800
	elseif product.gems then dl.gems = product.gems
	elseif product.spins then dl.spins = product.spins
	elseif product.boost then dl.boosts[product.boost] = product.secs or 1800
	end
	return dl
end

-- the profile's own count of the lasting things it already got for Robux
local function paidOf(d)
	if type(d.Paid) ~= "table" then d.Paid = {} end
	local p = d.Paid
	p.gems = math.max(0, math.floor(tonumber(p.gems) or 0))
	p.spins = math.max(0, math.floor(tonumber(p.spins) or 0))
	p.boosts = type(p.boosts) == "table" and p.boosts or {}
	p.starter = p.starter == true
	return p
end

-- records one purchase in the ledger (safe to call again for the same purchase id)
local function ledgerAdd(userId, purchaseId, product)
	if not ledgerStore then return true end -- no ledger at all: never block a purchase on it
	local dl = paidDelta(product)
	local ok = withRetry(function()
		ledgerStore:UpdateAsync("u_" .. userId, function(old)
			old = type(old) == "table" and old or {}
			old.ids = type(old.ids) == "table" and old.ids or {}
			if table.find(old.ids, purchaseId) then return nil end -- already recorded
			table.insert(old.ids, purchaseId)
			while #old.ids > 300 do table.remove(old.ids, 1) end
			old.gems = (tonumber(old.gems) or 0) + dl.gems
			old.spins = (tonumber(old.spins) or 0) + dl.spins
			old.boosts = type(old.boosts) == "table" and old.boosts or {}
			for k, secs in pairs(dl.boosts) do old.boosts[k] = (tonumber(old.boosts[k]) or 0) + secs end
			if dl.starter then old.starter = true end
			if product.key == "rushcrew" then
				old.rushUntil = math.max(tonumber(old.rushUntil) or 0, os.time()) + Config.RushCrewTime
			end
			old.products = type(old.products) == "table" and old.products or {}
			old.products[product.key] = (tonumber(old.products[product.key]) or 0) + 1
			return old
		end)
	end, 3)
	return ok
end

-- on join: merge the purchase ids and give back whatever paid thing this profile is missing
restorePaid = function(plr, st)
	local d = st.data
	local p = paidOf(d)
	d.Receipts = type(d.Receipts) == "table" and d.Receipts or {}
	if not ledgerStore then return end
	local ok, led = withRetry(function() return ledgerStore:GetAsync("u_" .. plr.UserId) end, 3)
	if not ok or type(led) ~= "table" then return end
	-- Roblox may send a purchase again: if its id is known here it is never granted twice
	for _, id in ipairs(type(led.ids) == "table" and led.ids or {}) do
		if not table.find(d.Receipts, id) then table.insert(d.Receipts, id) end
	end
	while #d.Receipts > 300 do table.remove(d.Receipts, 1) end
	local back = {}
	local g = math.floor(tonumber(led.gems) or 0) - p.gems
	if g > 0 then
		d.Gems = (tonumber(d.Gems) or 0) + g
		p.gems += g
		table.insert(back, Config.FormatNum(g) .. " Gems")
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
	local rush = tonumber(led.rushUntil) or 0
	if rush > (tonumber(d.RushCrewUntil) or 0) then d.RushCrewUntil = rush end
	if #back > 0 then
		task.delay(8, function()
			if S[plr] == st then
				feedback(plr, "PaidRestored", { list = table.concat(back, ", ") })
				saveSoon(plr)
			end
		end)
	end
end

local function processReceipt(info)
	local plr = Players:GetPlayerByUserId(info.PlayerId)
	local st = plr and S[plr]
	local studio = RunService:IsStudio()
	if not st or (not st.loaded and not studio) then return Enum.ProductPurchaseDecision.NotProcessedYet end
	local product
	for _, p in ipairs(Config.Store.products) do if p.id == info.ProductId then product = p end end
	if not product then return Enum.ProductPurchaseDecision.NotProcessedYet end
	-- every purchase is granted exactly once (Roblox may call this again for the same purchase)
	st.data.Receipts = st.data.Receipts or {}
	if table.find(st.data.Receipts, info.PurchaseId) then
		-- already given: make sure the permanent ledger has it too, then confirm
		if not ledgerAdd(plr.UserId, info.PurchaseId, product) then return Enum.ProductPurchaseDecision.NotProcessedYet end
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	local dl = paidDelta(product)
	local paid = paidOf(st.data)
	if product.key == "rushcrew" then
		-- buying again while active stacks the time
		st.data.RushCrewUntil = math.max(os.time(), st.data.RushCrewUntil or 0) + Config.RushCrewTime
		syncRushCrew(plr)
	elseif product.key == "starter" then
		st.data.StarterBought = true
		addGems(plr, dl.gems, product.name)
		addMoney(plr, bestUnlockedReward(st.data) * 20, product.name, true)
		addBoost(plr, "cash", dl.boosts.cash)
	elseif product.cash then
		-- cash packs grow with your progress: a multiple of your best contract
		addMoney(plr, bestUnlockedReward(st.data) * product.cash, product.name, true)
	elseif product.gems then
		addGems(plr, dl.gems, product.name)
	elseif product.boost then
		addBoost(plr, product.boost, dl.boosts[product.boost])
	elseif product.spins then
		if type(st.data.Spin) ~= "table" then st.data.Spin = { last = 0, extra = 0 } end
		st.data.Spin.extra = (tonumber(st.data.Spin.extra) or 0) + dl.spins
		plr:SetAttribute("SpinExtra", st.data.Spin.extra)
	end
	-- count what this profile got, so a restore from the ledger never gives it twice
	paid.gems += dl.gems
	paid.spins += dl.spins
	for k, secs in pairs(dl.boosts) do paid.boosts[k] = (tonumber(paid.boosts[k]) or 0) + secs end
	if dl.starter then paid.starter = true end
	table.insert(st.data.Receipts, info.PurchaseId)
	while #st.data.Receipts > 300 do table.remove(st.data.Receipts, 1) end
	feedback(plr, "Purchased", { name = product.name, kind = "product" })
	-- only confirm to Roblox once the purchase is safely saved (profile + permanent ledger); otherwise Roblox retries
	if not studio and not saveData(plr, false, true) then return Enum.ProductPurchaseDecision.NotProcessedYet end
	if not ledgerAdd(plr.UserId, info.PurchaseId, product) then return Enum.ProductPurchaseDecision.NotProcessedYet end
	return Enum.ProductPurchaseDecision.PurchaseGranted
end
MarketplaceService.ProcessReceipt = processReceipt]==])

-- 5) server shutdown: wait for every save to finish (up to 25 s) instead of a fixed 5 s
s = replaceOnce(s, [[	for _, p in ipairs(Players:GetPlayers()) do task.spawn(saveData, p, true) end
	task.wait(5)
end)]], [[	local pending = 0
	for _, p in ipairs(Players:GetPlayers()) do
		pending += 1
		task.spawn(function()
			pcall(saveData, p, true)
			pending -= 1
		end)
	end
	local waited = 0
	while pending > 0 and waited < 25 do task.wait(0.25); waited += 0.25 end
end)]])

-- 6) Studio test hooks for the ledger
s = replaceOnce(s, [[		elseif cmd == "rejoinSim" then]], [[		elseif cmd == "receiptKey" then
			-- run a real receipt for a product that has no Roblox id yet (Studio tests only)
			local prod
			for _, p in ipairs(Config.Store.products) do if p.key == v.key then prod = p end end
			if not prod then return "no product" end
			local oldId = prod.id
			if (prod.id or 0) == 0 then prod.id = -7 end
			local r = processReceipt({ PlayerId = plr.UserId, ProductId = prod.id, PurchaseId = v.purchase, CurrencySpent = 0, CurrencyType = Enum.CurrencyType.Robux, PlaceIdWherePurchased = game.PlaceId })
			prod.id = oldId
			return r
		elseif cmd == "ledger" then return ledgerStore and ledgerStore._mem and ledgerStore._mem["u_" .. plr.UserId]
		elseif cmd == "paid" then return S[plr].data.Paid
		elseif cmd == "wipeSim" then
			-- what a brand-new profile (progress reset) gets back from the permanent ledger
			local st = S[plr]
			local fresh = defaultData()
			for k in pairs(st.data) do st.data[k] = nil end
			for k, v in pairs(fresh) do st.data[k] = v end
			restorePaid(plr, st)
			CompanyService.Sanitize(st.data)
			RebirthService.Sanitize(st.data)
			VehicleService.Sanitize(st.data)
			sync(plr)
			RebirthService.Publish(plr)
			syncRushCrew(plr)
			plr:SetAttribute("SpinExtra", st.data.Spin.extra)
			return { gems = st.data.Gems, spins = st.data.Spin.extra, boosts = st.data.Boosts, starter = st.data.StarterBought,
				rush = (st.data.RushCrewUntil or 0) - os.time(), receipts = #st.data.Receipts, paid = st.data.Paid }
		elseif cmd == "passCheck" then checkPasses(plr) return S[plr].data.OwnedPasses
		elseif cmd == "rejoinSim" then]])

local ok, err = loadstring(s)
assert(ok, "compile failed: " .. tostring(err))

-- client: a banner when paid items come back, and "is yours" (not "equipped") for Robux purchases
local Client = game.StarterPlayer.StarterPlayerScripts.Client
local cs = Client.Source
if not cs:find('"PaidRestored"', 1, true) then
	cs = replaceOnce(cs, [[" upgraded!" or " equipped!"))]], [[" upgraded!" or ((d.kind == "product" or d.kind == "pass") and " is yours — thank you!" or " equipped!")))]])
	cs = replaceOnce(cs, [[	elseif kind == "MachineDeployed" then]], [[	elseif kind == "PaidRestored" then
		banner("💎 PURCHASES RESTORED", "Everything you bought with Robux is back: " .. tostring(d.list or ""), T.green)
		sound2D(S.Chime, 0.6, 1.1)
	elseif kind == "MachineDeployed" then]])
	local ok2, err2 = loadstring(cs)
	assert(ok2, "client compile failed: " .. tostring(err2))
end

Main.Source = s
Client.Source = cs
return "patched, " .. #s .. " chars"
