-- one-off patch (run in Edit): hammers become items (HammerService). Main: the tool in your hand comes from the
-- equipped hammer item, build power and swing speed from its rarity and level, the crew uses the hammer's power
-- (not the Strength bonus), tool tiers migrate to items on join, crates from the Store / free drops, admin + debug hooks.
local function replaceOnce(src, old, new)
	local a, b = src:find(old, 1, true)
	assert(a, "not found: " .. old:sub(1, 90))
	assert(not src:find(old, b + 1, true), "found twice: " .. old:sub(1, 90))
	return src:sub(1, a - 1) .. new .. src:sub(b + 1)
end
local Main = game.ServerScriptService.Game.Main
local s = Main.Source
if s:find("HAMMER_ITEMS", 1, true) then return "already patched" end

-- requires
s = replaceOnce(s, [[local VehicleService = require(script.Parent.VehicleService)
local CompanyData = require(ReplicatedStorage.Shared.Company)
]], [[local VehicleService = require(script.Parent.VehicleService)
local HammerService = require(script.Parent.HammerService) -- HAMMER_ITEMS
local Hammers = require(ReplicatedStorage.Shared.Hammers)
local CompanyData = require(ReplicatedStorage.Shared.Company)
]])

-- new profiles start migrated (Sanitize adds the Rusty Hammer)
s = replaceOnce(s, [[Rebirths = 0, Stars = 0, StarPerks = {}, RunStart = 0, Vehicles = {}, Playtime = { day = 0, secs = 0, claimed = {} }, Spin = { last = 0, extra = 0 }, Codes = {}, RoadV = 2 }]],
	[[Rebirths = 0, Stars = 0, StarPerks = {}, RunStart = 0, Vehicles = {}, Playtime = { day = 0, secs = 0, claimed = {} }, Spin = { last = 0, extra = 0 }, Codes = {}, RoadV = 2,
		Hammers = {}, Crates = {}, HammerV = 1 }]])

-- the crew works with the hammer's power (rarity + level), not with the Strength bonus (that one is yours alone)
s = replaceOnce(s, [[		local t = Config.Tools[d.ToolTier or 1] or Config.Tools[1]
		local m = t.power * Economy.Mult(st, "power")
		if st.rushCrewUntil and os.clock() < st.rushCrewUntil then m *= 2 end
		return m]], [[		local m = HammerService.Power(st) * Economy.Mult(st, "power") / Config.StrengthMult(d.Strength)
		if st.rushCrewUntil and os.clock() < st.rushCrewUntil then m *= 2 end
		return m]])

-- the tool in your hand: the equipped hammer item
s = replaceOnce(s, [[-- the hammer of your tier, built from hammers/spec.json (ServerStorage.Hammers); same Tool attributes as before
local function makeTool(tier)
	local cfg = Config.Tools[tier] or Config.Tools[1]
	local lib = game:GetService("ServerStorage"):FindFirstChild("Hammers")
	local src = lib and lib:FindFirstChild("Hammer_" .. tier)
	if not src then return makeToolOld(tier) end
	local tool = src:Clone()
	tool.Name = cfg.name
	tool.ToolTip = "Click / tap on a site to build"
	tool.CanBeDropped = false
	tool:SetAttribute("BuilderTool", true)
	tool:SetAttribute("Tier", tier)
	if cfg.icon and cfg.icon ~= "" then tool.TextureId = cfg.icon end
	return tool
end]], [[-- the hammer in your hand = the equipped hammer item (ServerStorage.Hammers.Hammer_<model>); Key / Rarity / Level
-- attributes drive the effects (HammerFX) and the HUD
local function makeTool(st)
	local it = HammerService.Equipped(st.data)
	local h = Hammers.ById[it.k] or Hammers.ById.rusty
	local lib = game:GetService("ServerStorage"):FindFirstChild("Hammers")
	local src = lib and h.model and lib:FindFirstChild("Hammer_" .. h.model)
	local tool = src and src:Clone() or makeToolOld(math.clamp(h.r, 1, #Config.Tools))
	tool.Name = h.name
	tool.ToolTip = "Click / tap on a site to build"
	tool.CanBeDropped = false
	tool:SetAttribute("BuilderTool", true)
	tool:SetAttribute("Tier", h.r)
	tool:SetAttribute("Key", h.key)
	tool:SetAttribute("Rarity", h.r)
	tool:SetAttribute("Level", it.lv or 1)
	tool:SetAttribute("HammerId", it.id)
	if h.key == "thunder" then tool:SetAttribute("Storm", true) end
	return tool
end]])
s = replaceOnce(s, [[	local best = st.data.ToolTier
	local pick = st.data.EquipTool
	if type(pick) ~= "number" or pick < 1 or pick > best then pick = nil end
	local tool = makeTool(pick or best)
	tool:SetAttribute("Tier", best) -- the look you picked; the power is always your best hammer's
	-- Thunderclap Hammer owners swing it instead, unless they picked another hammer (its power bonus is a multiplier)
	local storm = st.passes and st.passes[Config.StormHammer.pass] and pick == nil
	local lib = game:GetService("ServerStorage"):FindFirstChild("Hammers")
	local sh = storm and lib and lib:FindFirstChild("Hammer_" .. Config.StormHammer.key)
	if sh then
		tool:Destroy()
		tool = sh:Clone()
		tool.Name = Config.StormHammer.name
		tool.ToolTip = "Click / tap on a site to build"
		tool.CanBeDropped = false
		tool:SetAttribute("BuilderTool", true)
		tool:SetAttribute("Tier", st.data.ToolTier)
		tool:SetAttribute("Storm", true)
		if Config.StormHammer.icon then tool.TextureId = Config.StormHammer.icon end
	end
	local char = plr.Character]], [[	local tool = makeTool(st)
	local char = plr.Character]])

-- hammers come from crates now
s = replaceOnce(s, [[BuyToolRF.OnServerInvoke = function(plr, tier)
	local st = S[plr]
	if not st then return false, "Loading..." end]], [[BuyToolRF.OnServerInvoke = function(plr, tier)
	local st = S[plr]
	if not st then return false, "Loading..." end
	if true then return false, "Hammers come from crates now: Shop → HAMMERS" end]])
s = replaceOnce(s, [[EquipToolRF.OnServerInvoke = function(plr, which)
	local st = S[plr]
	if not st then return false, "Loading..." end]], [[EquipToolRF.OnServerInvoke = function(plr, which)
	local st = S[plr]
	if not st then return false, "Loading..." end
	if true then return false, "Pick your hammer in Shop → HAMMERS" end]])

-- the rebirth keeps your hammers (they are your collection)
s = replaceOnce(s, [[	d.Money = Config.StartMoney + (headStart or 0)
	d.ToolTier = 1
	d.GearTier = 1]], [[	d.Money = Config.StartMoney + (headStart or 0)
	d.GearTier = 1]])

-- build power + swing speed from the hammer
s = replaceOnce(s, [[	local cd = (Config.Tools[st.data.ToolTier] or Config.Tools[1]).cooldown
	if st.passes and st.passes.fasttools then cd *= Config.FastToolsPass end]], [[	local cd = HammerService.Cooldown(st)
	if st.passes and st.passes.fasttools then cd *= Config.FastToolsPass end]])
s = replaceOnce(s, [[	local amount = tcfg.power * Economy.Mult(st, "power") * st.combo]], [[	local amount = HammerService.Power(st) * Economy.Mult(st, "power") * st.combo]])

-- the service (after giveTool / bestUnlockedReward / contractUnlocked exist)
s = replaceOnce(s, [[GetContractsRF.OnServerInvoke = function(plr)]], [[HammerService.Init({
	S = S, sync = sync, addMoney = addMoney, addGems = addGems, feedback = feedback, saveSoon = saveSoon, saveData = saveData, remote = remote,
	giveTool = function(p) giveTool(p) end, bestUnlockedReward = bestUnlockedReward,
	zoneOf = function(d)
		local zone, best = "town", -1
		for _, c in ipairs(Config.Contracts) do
			if contractUnlocked(d, c) and c.reward > best then best = c.reward; zone = c.zone or "town" end
		end
		return zone
	end,
	luck = function(st) return (st.passes and st.passes.luck) and 2 or 1 end,
	missionProgress = function(p, k, n) if missionProgress then missionProgress(p, k, n) end end,
	isTrading = function(p) return TradeService.IsTrading(p) end,
})

GetContractsRF.OnServerInvoke = function(plr)]])

-- a finished contract can drop a crate
s = replaceOnce(s, [[		CompanyService.RollBlueprint(owner, st, c)
		local okF, errF = pcall(CompanyService.ContractFinds, owner, st, job, job:Center())]], [[		CompanyService.RollBlueprint(owner, st, c)
		pcall(HammerService.OnContract, owner, st)
		local okF, errF = pcall(CompanyService.ContractFinds, owner, st, job, job:Center())]])

-- on join: items, migration; the pass hammer follows the pass
s = replaceOnce(s, [[	VehicleService.Sanitize(st.data)
	-- economy v2 (2026-10-05)]], [[	VehicleService.Sanitize(st.data)
	HammerService.Sanitize(st.data)
	HammerService.Migrate(plr, st)
	-- economy v2 (2026-10-05)]])
s = replaceOnce(s, [[	plr:SetAttribute("SkipAnim", st.passes.skipanim == true and st.data.SkipAnimOff ~= true)
	sync(plr)
	vipTag(plr)]], [[	plr:SetAttribute("SkipAnim", st.passes.skipanim == true and st.data.SkipAnimOff ~= true)
	HammerService.SyncPass(plr, st)
	HammerService.Publish(plr)
	sync(plr)
	vipTag(plr)]])
-- sync publishes the hammer attributes too (cheap)
s = replaceOnce(s, [[	plr:SetAttribute("ToolTier", d.ToolTier)
]], [[	plr:SetAttribute("ToolTier", d.ToolTier)
	if d.Hammers then HammerService.Publish(plr) end
]])

-- Robux crates: granted once, kept in the permanent ledger like Gems
s = replaceOnce(s, [[	local dl = { gems = 0, spins = 0, boosts = {}, starter = false }
	if product.key == "starter" then
		dl.starter = true
		dl.gems = 500
		dl.boosts.cash = 1800]], [[	local dl = { gems = 0, spins = 0, boosts = {}, starter = false, crates = {} }
	if product.crate then dl.crates[product.crate] = product.count or 1 end
	if product.key == "starter" then
		dl.starter = true
		dl.gems = 500
		dl.boosts.cash = 1800
		dl.crates.builder = 1]])
s = replaceOnce(s, [[	p.starter = p.starter == true
	return p]], [[	p.starter = p.starter == true
	p.crates = type(p.crates) == "table" and p.crates or {}
	return p]])
s = replaceOnce(s, [[			if dl.starter then old.starter = true end
			if product.key == "rushcrew" then]], [[			if dl.starter then old.starter = true end
			old.crates = type(old.crates) == "table" and old.crates or {}
			for k, n in pairs(dl.crates) do old.crates[k] = (tonumber(old.crates[k]) or 0) + n end
			if product.key == "rushcrew" then]])
s = replaceOnce(s, [[	if led.starter and not p.starter then
		d.StarterBought = true
		p.starter = true
	end]], [[	if led.starter and not p.starter then
		d.StarterBought = true
		p.starter = true
	end
	for k, n in pairs(type(led.crates) == "table" and led.crates or {}) do
		local diff = math.floor(tonumber(n) or 0) - math.floor(tonumber(p.crates[k]) or 0)
		if diff > 0 and Hammers.CrateById[k] then
			HammerService.AddCrate(plr, st, k, diff, "silent")
			p.crates[k] = (tonumber(p.crates[k]) or 0) + diff
			table.insert(back, diff .. "x " .. Hammers.CrateById[k].name)
		end
	end]])
s = replaceOnce(s, [[	elseif product.key == "starter" then
		st.data.StarterBought = true
		addGems(plr, dl.gems, product.name)]], [[	elseif product.crate then
		HammerService.AddCrate(plr, st, product.crate, product.count or 1, "robux")
	elseif product.key == "starter" then
		st.data.StarterBought = true
		HammerService.AddCrate(plr, st, "builder", 1, "robux")
		addGems(plr, dl.gems, product.name)]])
s = replaceOnce(s, [[	if dl.starter then paid.starter = true end
	table.insert(st.data.Receipts, info.PurchaseId)]], [[	if dl.starter then paid.starter = true end
	for k, n in pairs(dl.crates) do paid.crates[k] = (tonumber(paid.crates[k]) or 0) + n end
	table.insert(st.data.Receipts, info.PurchaseId)]])

-- debug + admin: "tool" gives a hammer by its tool tier key
s = replaceOnce(s, [[		elseif cmd == "tool" then S[plr].data.ToolTier = v; giveTool(plr); sync(plr)]],
	[[		elseif cmd == "tool" then
			local cfg = Config.Tools[v]
			local it = cfg and HammerService.Give(plr, S[plr], cfg.key, "debug")
			if it then S[plr].data.EquipHammer = it.id end
			giveTool(plr); sync(plr)
		elseif cmd == "hammer" then
			local it = HammerService.Give(plr, S[plr], v, "debug")
			if it then S[plr].data.EquipHammer = it.id end
			giveTool(plr); sync(plr)
			return it and it.id
		elseif cmd == "crate" then HammerService.AddCrate(plr, S[plr], v[1], v[2] or 1, "debug")
		elseif cmd == "migrate" then S[plr].data.HammerV = nil; S[plr].data.ToolTier = v; local r = HammerService.Migrate(plr, S[plr]); giveTool(plr); sync(plr); return r
		elseif cmd == "hammers" then
			local t = {}
			for _, it in ipairs(S[plr].data.Hammers) do table.insert(t, it.k .. ":" .. it.lv .. (it.bound and "(b)" or "")) end
			return { list = t, equip = S[plr].data.EquipHammer, power = HammerService.Power(S[plr]), cd = HammerService.Cooldown(S[plr]), crates = S[plr].data.Crates, tier = S[plr].data.ToolTier }
		elseif cmd == "hammerAction" then
			return ReplicatedStorage.Remotes.HammerAction.OnServerInvoke(plr, v[1], v[2], v[3])]])
s = replaceOnce(s, [[		local n = int(v, 1, #Config.Tools)
		if not n then return false, "bad tier" end
		st.data.ToolTier = n
		if type(st.data.EquipTool) == "number" and st.data.EquipTool > n then st.data.EquipTool = nil end
		giveTool(plr)
		sync(plr)
		return true, "Hammer → " .. Config.Tools[n].name]], [[		local n = int(v, 1, #Config.Tools)
		if not n then return false, "bad tier" end
		local it = HammerService.Give(plr, st, Config.Tools[n].key, "admin")
		if not it then return false, "hammer bag full" end
		st.data.EquipHammer = it.id
		giveTool(plr)
		sync(plr)
		return true, "Hammer → " .. Config.Tools[n].name]])

assert(loadstring(s), "Main compile")
Main.Source = s
return "Main: hammer items wired"
