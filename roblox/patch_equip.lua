-- one-off patch (run in Edit): equip any hammer you own (the look you hold; your build power stays your best hammer's)
--  * data.EquipTool = the tier you picked (nil = your best hammer, or the Thunderclap if you own it)
--  * EquipTool remote (tier number or "thunder"); the player's "EquipTool" attribute tells the Shop which one you hold
--  * buying a new hammer equips it; the tool keeps Tier = your best tier, so nothing about power / cooldown changes
local function replaceOnce(src, old, new)
	local a, b = src:find(old, 1, true)
	assert(a, "not found: " .. old:sub(1, 80))
	assert(not src:find(old, b + 1, true), "found twice: " .. old:sub(1, 80))
	return src:sub(1, a - 1) .. new .. src:sub(b + 1)
end
local Main = game.ServerScriptService.Game.Main
local s = Main.Source
if s:find("EquipToolRF", 1, true) then return "already patched" end

s = replaceOnce(s, [[local BuyToolRF = remote("RemoteFunction", "BuyTool")
]], [[local BuyToolRF = remote("RemoteFunction", "BuyTool")
local EquipToolRF = remote("RemoteFunction", "EquipTool")
]])

-- saved choice: a whole tier you own, or nothing (= the best)
s = replaceOnce(s, [[	d.ToolTier = math.clamp(tonumber(d.ToolTier) or 1, 1, #Config.Tools)
]], [[	d.ToolTier = math.clamp(tonumber(d.ToolTier) or 1, 1, #Config.Tools)
	d.EquipTool = tonumber(d.EquipTool) and math.clamp(math.floor(tonumber(d.EquipTool)), 1, #Config.Tools) or nil
]])

s = replaceOnce(s, [[	plr:SetAttribute("ToolTier", d.ToolTier)
]], [[	plr:SetAttribute("ToolTier", d.ToolTier)
	plr:SetAttribute("EquipTool", (d.EquipTool and d.EquipTool <= d.ToolTier) and tostring(d.EquipTool) or "")
]])

-- the hammer in your hand is the one you picked
s = replaceOnce(s, [[	local tool = makeTool(st.data.ToolTier)
	-- Thunderclap Hammer owners swing it instead (same tool attributes; its power bonus is a multiplier)
	local storm = st.passes and st.passes[Config.StormHammer.pass]
]], [[	local best = st.data.ToolTier
	local pick = st.data.EquipTool
	if type(pick) ~= "number" or pick < 1 or pick > best then pick = nil end
	local tool = makeTool(pick or best)
	tool:SetAttribute("Tier", best) -- the look you picked; the power is always your best hammer's
	-- Thunderclap Hammer owners swing it instead, unless they picked another hammer (its power bonus is a multiplier)
	local storm = st.passes and st.passes[Config.StormHammer.pass] and pick == nil
]])

-- a new hammer goes straight into your hand
s = replaceOnce(s, [[	st.data.ToolTier = tier
	addMoney(plr, -cfg.price, "Bought " .. cfg.name)]], [[	st.data.ToolTier = tier
	-- (a Thunderclap owner holds the new one too: the Thunderclap is one EQUIP away in the Shop, its x3 stays on)
	st.data.EquipTool = (st.passes and st.passes[Config.StormHammer.pass]) and tier or nil
	plr:SetAttribute("EquipTool", st.data.EquipTool and tostring(st.data.EquipTool) or "")
	addMoney(plr, -cfg.price, "Bought " .. cfg.name)]])

s = replaceOnce(s, [[BuyGearRF.OnServerInvoke = function(plr, tier)]], [[-- pick which of your hammers you hold
EquipToolRF.OnServerInvoke = function(plr, which)
	local st = S[plr]
	if not st then return false, "Loading..." end
	if st.lastEquip and os.clock() - st.lastEquip < 0.4 then return false, "One moment..." end
	local storm = (st.passes and st.passes[Config.StormHammer.pass]) == true
	if which == "thunder" then
		if not storm then return false, "Get the " .. Config.StormHammer.name .. " first" end
		st.data.EquipTool = nil
	else
		local t = tonumber(which)
		if not t or t ~= math.floor(t) or t < 1 or t > st.data.ToolTier then return false, "You don't own that hammer yet" end
		-- your best hammer is the default (unless the Thunderclap is): no need to remember it
		if t == st.data.ToolTier and not storm then st.data.EquipTool = nil else st.data.EquipTool = t end
	end
	st.lastEquip = os.clock()
	plr:SetAttribute("EquipTool", st.data.EquipTool and tostring(st.data.EquipTool) or "")
	giveTool(plr)
	return true
end

BuyGearRF.OnServerInvoke = function(plr, tier)]])

-- the Thunderclap you just bought goes straight into your hand
s = replaceOnce(s, [[			st.data.OwnedPasses[p.key] = true
			applyPasses(plr)
			feedback(plr, "Purchased", { name = p.name, kind = "pass" })]], [[			st.data.OwnedPasses[p.key] = true
			if p.key == Config.StormHammer.pass then
				st.data.EquipTool = nil
				plr:SetAttribute("EquipTool", "")
				st.stormGiven = false -- applyPasses hands it over now
			end
			applyPasses(plr)
			feedback(plr, "Purchased", { name = p.name, kind = "pass" })]])

assert(loadstring(s), "Main compile")
Main.Source = s
return "equip patched"
