-- one-off patch (run in Edit, after patch_no_paid_random.lua): X-RAY crates, like CS2's X-Ray Scanner, where Roblox
-- doesn't allow paid random items (PolicyService ArePaidRandomItemsRestricted -> player attribute PaidRandomRestricted)
--  * every crate you can buy shows the hammer inside BEFORE you pay; you pay its normal price (cash / Gems) and get
--    exactly that hammer; the next one shows only once you took this one (no free re-rolls: rejoining, leaving it
--    for later... it stays the same, it is saved with your data)
--  * same odds, luck, pity and price as everywhere: these hammers trade like any other, the market isn't touched
--  * Roblox's policy allows it: "outcomes in a pre-determined order disclosed to the user before purchase"
--  * the free crates are the same for everyone again (a Supply Crate every 6 contracts, Builder's 3%): the extra free
--    crates of the first version are gone; the crates you get free open as usual (free random items are allowed)
--  * the tutorial's Supply Crate: X-ray too (you see your first hammer, you pay the $150 like everyone)
-- Robux crates stay hidden there (the Store), Lucky Spins for Gems / Robux stay closed (the free spin works).
local function replaceOnce(src, old, new)
	local a, b = src:find(old, 1, true)
	assert(a, "not found: " .. old:sub(1, 80))
	assert(not src:find(old, b + 1, true), "found twice: " .. old:sub(1, 80))
	return src:sub(1, a - 1) .. new .. src:sub(b + 1)
end
local HS = game.ServerScriptService.Game.HammerService
local s = HS.Source
if s:find("XRAY:", 1, true) then return "HammerService: already" end
assert(s:find("PAID_RANDOM_POLICY", 1, true), "run patch_no_paid_random.lua first")

-- 1. the free crates: the same for everyone again
s = replaceOnce(s, [=[-- contracts per free Supply Crate
function M.CrateEvery(plr) return noPaidRandom(plr) and 3 or 6 end

-- free crates: every 6th finished contract drops a Supply Crate, and 3% of contracts a Builder's Crate
-- (no paid crates in your country: every 3rd, 6%, and 0.5% a Golden Crate)
function M.OnContract(plr, st)
	local d = st.data
	local free = noPaidRandom(plr)
	local luck = ctx.luck and ctx.luck(st) or 1
	d.CrateProgress = (d.CrateProgress or 0) + 1
	if d.CrateProgress >= M.CrateEvery(plr) then
		d.CrateProgress = 0
		M.AddCrate(plr, st, Hammers.SupplyFor(ctx.zoneOf(d)), 1, "drop")
	elseif rng:NextNumber() < (free and 0.06 or 0.03) * luck then
		M.AddCrate(plr, st, "builder", 1, "drop")
	elseif free and rng:NextNumber() < 0.005 * luck then
		M.AddCrate(plr, st, "golden", 1, "drop")
	end]=], [=[-- contracts per free Supply Crate (the same for everyone)
function M.CrateEvery(plr) return 6 end

-- free crates: every 6th finished contract drops a Supply Crate, and 3% of contracts a Builder's Crate
function M.OnContract(plr, st)
	local d = st.data
	d.CrateProgress = (d.CrateProgress or 0) + 1
	if d.CrateProgress >= 6 then
		d.CrateProgress = 0
		M.AddCrate(plr, st, Hammers.SupplyFor(ctx.zoneOf(d)), 1, "drop")
	elseif rng:NextNumber() < 0.03 * (ctx.luck and ctx.luck(st) or 1) then
		M.AddCrate(plr, st, "builder", 1, "drop")
	end]=])

-- 2. opening with the hammer already known (the X-ray's): everything else as a normal opening (pity, first crate,
--    the bag, the hand, missions)
s = replaceOnce(s, "local function openOne(plr, st, crateId)", "local function openOne(plr, st, crateId, forced)")
s = replaceOnce(s, "local key, r = Hammers.Roll(crateId, zone, rng, luck, pityMin)", [=[local key, r
	if forced then key, r = forced.k, forced.r else key, r = Hammers.Roll(crateId, zone, rng, luck, pityMin) end]=])
s = replaceOnce(s, "task.delay(quick and 0.2 or 4.5, function()", "task.delay(quick and 0.2 or (forced and 0.8) or 4.5, function()")

-- 3. the X-ray itself
s = replaceOnce(s, [=[-- Actions (client -> server) -------------------------------------------------------------------------
local actions = {}]=], [=[-- XRAY: where paid random items aren't allowed, every crate you can buy shows the hammer inside before you pay (like
-- CS2's X-Ray Scanner): you pay its normal price and get exactly that hammer; the next one shows only once you took it
-- (no free re-rolls: it is saved with your data). Same odds, luck, pity and price as everywhere.
local function xrayable(c) return c ~= nil and (c.cash or c.gems) and true or false end
function M.XRay(plr, st, crateId)
	local d = st.data
	local c = Hammers.CrateById[crateId]
	if not xrayable(c) then return nil end
	if type(d.XRay) ~= "table" then d.XRay = {} end
	local x = d.XRay[crateId]
	if type(x) == "table" and Hammers.ById[x.k] then return x end
	local zone = c.zone or ctx.zoneOf(d)
	local luck = ctx.luck and ctx.luck(st) or 1
	-- (the same rules as an opening: the pity, the first crate Uncommon or better)
	local pityMin
	if c.pity and ((d.HammerPity and d.HammerPity[crateId] or 0) + 1) >= c.pity.every then pityMin = c.pity.min end
	if not d.FirstCrateDone then pityMin = math.max(pityMin or 0, 2) end
	local key, r = Hammers.Roll(crateId, zone, rng, luck, pityMin)
	if not key then return nil end
	x = { k = key, r = r }
	d.XRay[crateId] = x
	return x
end
-- the X-ray of every crate the Shop sells you (your zone's Supply Crate, the Gem crates)
local function xrayAll(plr, st)
	local out = {}
	local zid = Hammers.SupplyFor(ctx.zoneOf(st.data))
	for _, c in ipairs(Hammers.Crates) do
		if xrayable(c) and (c.family ~= "supply" or c.id == zid) then
			local x = M.XRay(plr, st, c.id)
			if x then out[c.id] = { key = x.k, r = x.r } end
		end
	end
	return out
end

-- Actions (client -> server) -------------------------------------------------------------------------
local actions = {}]=])

s = replaceOnce(s, "every = M.CrateEvery(plr), noPaid = noPaidRandom(plr) }",
	"every = M.CrateEvery(plr), noPaid = noPaidRandom(plr), xray = noPaidRandom(plr) and xrayAll(plr, st) or nil }")

-- 4. buying where it's X-ray: one at a time, the hammer you saw (the client says which: if the X-ray changed in
--    between, nothing is bought and the new one shows), the normal price, opened at once
s = replaceOnce(s, "function actions.buy(plr, st, crateId, n)\n\tlocal d = st.data", [=[function actions.buy(plr, st, crateId, n)
	local d = st.data
	-- (X-ray: { n = 1, expect = the hammer key you were shown })
	local expect
	if type(n) == "table" then expect = n.expect; n = n.n end]=])
s = replaceOnce(s, [=[	if noPaidRandom(plr) then
		-- the tutorial's Supply Crate (the check above let only that one through): a gift
		if Config.InTutorial and Config.InTutorial(d) then
			d.Crates[crateId] = (d.Crates[crateId] or 0) + 1
			M.Publish(plr)
			ctx.saveSoon(plr)
			return true, { crates = d.Crates[crateId], free = true }
		end
		return false, "Crates can't be bought in your country: you get them free while you build"
	end]=], [=[	local xr
	if noPaidRandom(plr) then
		-- XRAY: you buy the hammer you were shown, one at a time
		if n ~= 1 then return false, "One at a time: you get the hammer you see" end
		xr = M.XRay(plr, st, crateId)
		if not xr then return false, "This crate can't be bought here" end
		if type(expect) ~= "string" or expect ~= xr.k then return false, "xray" end
		if #d.Hammers >= Hammers.InventoryCap then return false, "Hammer bag full (" .. Hammers.InventoryCap .. "): trade up or trade some away first" end
	end]=])
s = replaceOnce(s, [=[	d.Crates[crateId] = (d.Crates[crateId] or 0) + n
	M.Publish(plr)
	ctx.saveSoon(plr)
	return true, { crates = d.Crates[crateId] }]=], [=[	d.Crates[crateId] = (d.Crates[crateId] or 0) + n
	if xr then
		-- XRAY: opened at once, with the hammer you saw; then the next one shows
		local ok, res = openOne(plr, st, crateId, xr)
		if not ok then
			-- (it can't really happen: the bag and the crate were checked) the crate goes back to cash / Gems
			d.Crates[crateId] = math.max(0, (d.Crates[crateId] or 0) - 1)
			if c.cash then ctx.addMoney(plr, Hammers.SupplyPrice((ctx.zoneReward or ctx.bestUnlockedReward)(d)), c.name .. " refund", true)
			elseif c.gems then ctx.addGems(plr, c.gems, c.name .. " refund") end
			M.Publish(plr)
			return false, res
		end
		d.XRay[crateId] = nil
		local nx = M.XRay(plr, st, crateId)
		res.xray = true
		res.next = nx and { key = nx.k, r = nx.r } or nil
		if ctx.sync then ctx.sync(plr) else M.Publish(plr) end
		ctx.feedback(plr, "Hammer", { kind = "got", key = res.key, r = res.r, crate = crateId, new = res.new })
		ctx.saveSoon(plr)
		return true, res
	end
	M.Publish(plr)
	ctx.saveSoon(plr)
	return true, { crates = d.Crates[crateId] }]=])

local f, err = loadstring(s)
assert(f, "HammerService compile: " .. tostring(err))
HS.Source = s
return "HammerService: X-ray crates where paid random items aren't allowed; free crates the same for everyone"
