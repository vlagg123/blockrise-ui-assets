-- BlockRise Empire - Job Board window: contracts as light rows (building art, client, rewards, ACCEPT)
local RS = game:GetService("ReplicatedStorage")
local K = require(RS.Shared:WaitForChild("MenuKit"))

local Hammers = require(RS.Shared:WaitForChild("Hammers"))
local Company = require(RS.Shared:WaitForChild("Company"))

local M = {}
local c, UI, T, Config
local blueprint -- blueprint picked for the next contract (nil = none)

local J1, J2 = Color3.fromRGB(255, 205, 80), Color3.fromRGB(240, 130, 20)
-- building art per contract (by order) until each building has its own icon
local ART = { "site", "home", "garage", "home", "home", "suburbs", "company", "company", "suburbs", "contract", "downtown", "company", "downtown", "company", "mega" }

local function contractOrder(id)
	for _, cc in ipairs(Config.Contracts) do if cc.id == id then return cc.order or 1 end end
	return 1
end

-- the materials a building drops while you build it (and when it's finished): picture, name and chance, most first
local function dropsOf(ord, narrow)
	local out = {}
	if not Company.DropTable then return out end
	for id, pct in pairs(Company.DropTable(ord)) do
		local m = Company.MaterialById[id]
		if m and pct > 0 then
			local name = narrow and m.name:match("^(%S+)") or m.name
			table.insert(out, { name .. " " .. pct .. "%", m.color:Lerp(Color3.new(0, 0, 0), 0.25), pic = m.image or m.icon, pct = pct, order = m.order })
		end
	end
	table.sort(out, function(a, b) if a.pct ~= b.pct then return a.pct > b.pct end return a.order < b.order end)
	return out
end

local function blueprintPicker(order)
	local owned = {}
	for _, bp in ipairs(Company.Blueprints) do
		local n = c.player:GetAttribute("BP_" .. bp.id) or 0
		if n > 0 then table.insert(owned, { bp = bp, n = n }) end
	end
	if blueprint and (c.player:GetAttribute("BP_" .. blueprint) or 0) < 1 then blueprint = nil end
	if #owned == 0 then return 1 end
	local mult = 1
	K.section(c.content, order, "BLUEPRINT", Color3.fromRGB(150, 210, 255), "pick one for a premium job")
	local row = UI.new("Frame", { Name = "Blueprints", Size = UDim2.new(1, 0, 0, 56), BackgroundTransparency = 1, LayoutOrder = order + 1, ZIndex = 2, Parent = c.content })
	UI.new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder, Parent = row })
	-- (the buttons' ink outline sits outside them: a little room so the list's edge never cuts it)
	UI.new("UIPadding", { PaddingLeft = UDim.new(0, 4), PaddingTop = UDim.new(0, 3), Parent = row })
	local function pick(id, label, col, i)
		local on = blueprint == id
		local b = UI.button(label, on and col or UI.TAB_OFF, nil, { Size = UDim2.fromOffset(id and 170 or 100, 48), TextSize = 18, LayoutOrder = i, ZIndex = 3, Parent = row })
		b.Activated:Connect(function() c.click(); blueprint = id; M.Show() end)
	end
	pick(nil, "NONE", Color3.fromRGB(150, 156, 196), 0)
	for i, e in ipairs(owned) do
		pick(e.bp.id, e.bp.name:gsub(" Blueprint", "") .. " x" .. e.n, e.bp.color, i)
		if e.bp.id == blueprint then mult = e.bp.pay end
	end
	return mult
end

function M.Show()
	local tok = c.openModal("Contracts", "Job Board", "", J1, J2)
	local loading = K.loading(c.content)
	local ok, data = pcall(function() return c.R.GetContracts:InvokeServer() end)
	if not c.live(tok) then return end
	loading:Destroy()
	if not ok or not data or not data.contracts or #data.contracts == 0 then
		K.empty(c.content, 1, "The job list didn't load. Open it again.", "jobs")
		return
	end
	c.modalSub.Text = data.freeSites .. " free site" .. (data.freeSites == 1 and "" or "s")
	local mult = blueprintPicker(1)
	K.section(c.content, 3, "CONTRACTS", Color3.fromRGB(255, 220, 110), "finish fast for a bonus")
	local p = c.player
	local lvl, rep, str, reb = p:GetAttribute("Level") or 1, p:GetAttribute("Rep") or 0, p:GetAttribute("Strength") or 0, p:GetAttribute("Rebirths") or 0
	local crew, best = p:GetAttribute("WorkerCount") or 0, p:GetAttribute("ToolTier") or 1
	-- a locked building says exactly what it needs: a green tick for what you have, a red cross for what's missing
	local function needs(ct)
		local parts = {}
		local function add(ok, label, have)
			table.insert(parts, string.format('<font color="%s">%s %s%s</font>', ok and "#239a45" or "#e0344f", ok and "✓" or "×", label,
				(not ok and have) and (" (you: " .. have .. ")") or ""))
		end
		if (ct.reqRebirth or 0) > 0 then add(reb >= ct.reqRebirth, "Rebirth " .. ct.reqRebirth, tostring(reb)) end
		if (ct.reqLevel or 1) > 1 then add(lvl >= ct.reqLevel, "Level " .. ct.reqLevel, tostring(lvl)) end
		if (ct.reqRep or 0) > 0 then add(rep >= ct.reqRep, Config.FormatNum(ct.reqRep) .. " Rep ⭐", Config.FormatNum(rep)) end
		if (ct.reqStrength or 0) > 0 then add(str >= ct.reqStrength, Config.Short(ct.reqStrength) .. " Strength 💪", Config.Short(math.floor(str))) end
		if (ct.reqCrew or 0) > 0 then add(crew >= ct.reqCrew, "Crew of " .. ct.reqCrew .. " 👷", tostring(crew)) end
		if (ct.reqHammer or 1) > 1 then
			local r = Hammers.Rarities[ct.reqHammer]
			add(best >= ct.reqHammer, r.name .. "+ hammer 🔨", Hammers.Rarities[math.clamp(best, 1, #Hammers.Rarities)].name)
		end
		return "<b>To unlock:</b>  " .. table.concat(parts, "   ")
	end
	for i, ct in ipairs(data.contracts) do
		local ord = contractOrder(ct.id)
		local rk = K.rarityOf(ord, #Config.Contracts)
		local chips = {
			{ Config.FormatMoney(ct.reward * mult), K.GREEN },
			{ "+" .. ct.xp .. " XP", T.blue },
			{ "+" .. ct.rep .. " REP", Color3.fromRGB(240, 140, 20) },
			{ "⚡ " .. c.fmtTime(ct.targetTime), T.purple },
		}
		-- (a locked building lists its Strength need in the "To unlock" line instead)
		if ct.unlocked and (ct.reqStrength or 0) > 0 then table.insert(chips, { "💪 " .. Config.Short(ct.reqStrength), Color3.fromRGB(255, 120, 80) }) end
		if ct.unlocked and (ct.reqHammer or 1) > 1 then
			local r = Hammers.Rarities[ct.reqHammer]
			table.insert(chips, { "🔨 " .. string.upper(r.name) .. "+", r.text and Color3.fromRGB(70, 70, 110) or r.color })
		end
		local narrow = (_G.__CE_ListWidth and _G.__CE_ListWidth() or 780) < 700
		if narrow then
			-- narrow window (phones): only the reward, the stars and the strength you need
			table.remove(chips, 4)
			table.remove(chips, 2)
		end
		local o = { name = ct.name, line = ct.unlocked and (ct.client .. " · " .. ct.stages .. " stages" .. (ct.done > 0 and ("  ·  done x" .. ct.done) or "")) or needs(ct),
			icon = K.BUILDING[ct.id] or ART[ord] or "site", color = K.RAR[rk], chips = chips, drops = dropsOf(ord, narrow), height = 150, buttonW = 168,
			new = ct.unlocked and (ct.done or 0) == 0 }
		if ct.unlocked and data.active == ct.id then
			o.status = { "ACTIVE", Color3.fromRGB(255, 176, 40) }
			o.spin = true
		elseif ct.unlocked then
			o.button = { "ACCEPT", K.GREEN, function()
				c.click()
				local ok2, res, msg = pcall(function() return c.R.Accept:InvokeServer(ct.id, blueprint) end)
				if ok2 and res then blueprint = nil; c.closeModal() else c.toast("⚠️ " .. tostring(msg or "Can't accept right now"), T.red) end
			end, shine = true, size = 24 }
		elseif reb < (ct.reqRebirth or 0) then
			o.dim = true
			o.status = { "🔒 REBIRTH " .. ct.reqRebirth, K.LOCK }
		elseif lvl >= ct.reqLevel and rep >= ct.reqRep and best < (ct.reqHammer or 1) then
			-- a better hammer is missing: straight to the crates
			o.button = { "🔨 HAMMERS", Color3.fromRGB(70, 160, 255), function() c.click(); if _G.__CE_ShopUI then _G.__CE_ShopUI.Show("hammers") end end }
		elseif lvl >= ct.reqLevel and rep >= ct.reqRep and crew < (ct.reqCrew or 0) then
			-- the crew is too small: hire
			o.button = { "👷 HIRE", K.GREEN, function() c.click(); if _G.__CE_ShopUI then _G.__CE_ShopUI.Show("crew") end end }
		elseif lvl >= ct.reqLevel and rep >= ct.reqRep and str < (ct.reqStrength or 0) then
			-- only Strength is missing: send them to the Training Yard
			o.button = { "💪 TRAIN", Color3.fromRGB(255, 140, 80), function() c.click(); c.closeModal(); c.setWaypoint("gym") end }
		else
			o.dim = true
			o.status = { lvl < ct.reqLevel and ("🔒 LEVEL " .. ct.reqLevel) or ("🔒 " .. ct.reqRep .. " ⭐"), K.LOCK }
		end
		K.row(c.content, 3 + i, o)
	end
end

function M.Init(ctx)
	c = ctx
	UI, T, Config = c.UI, c.T, c.Config
end

return M
