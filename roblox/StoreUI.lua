-- BlockRise Empire - Store window (Robux and Gems): gem packs, cash packs, boosts, passes and the Gem Shop, as item tiles.
-- The Teleporter offer sits on top of every tab until you own it.
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local MarketplaceService = game:GetService("MarketplaceService")
local K = require(RS.Shared:WaitForChild("MenuKit"))

local M = {}
local c, UI, T, Config
local tab = "gems"

local GEM1, GEM2 = Color3.fromRGB(120, 230, 255), Color3.fromRGB(30, 140, 220)
local TABS = {
	{ id = "gems", label = "GEMS", icon = "gem", c1 = GEM1, c2 = GEM2 },
	{ id = "cash", label = "CASH", icon = "cash", c1 = Color3.fromRGB(130, 240, 120), c2 = Color3.fromRGB(30, 160, 70) },
	{ id = "boosts", label = "BOOSTS", icon = "up_power", c1 = Color3.fromRGB(255, 205, 70), c2 = Color3.fromRGB(240, 130, 20) },
	{ id = "passes", label = "PASSES", icon = "vip", c1 = Color3.fromRGB(205, 150, 255), c2 = Color3.fromRGB(125, 65, 230) },
	{ id = "gemshop", label = "GEM SHOP", icon = "store", c1 = Color3.fromRGB(255, 150, 200), c2 = Color3.fromRGB(215, 60, 140) },
}
local THEME = {}
for _, t in ipairs(TABS) do THEME[t.id] = t end
local GEM_COLS = { Color3.fromRGB(90, 200, 255), Color3.fromRGB(60, 160, 255), Color3.fromRGB(120, 120, 255), Color3.fromRGB(165, 90, 255),
	Color3.fromRGB(255, 150, 40), Color3.fromRGB(255, 70, 120) }
local CASH_COLS = { Color3.fromRGB(120, 210, 90), Color3.fromRGB(60, 190, 120), Color3.fromRGB(255, 190, 40), Color3.fromRGB(255, 140, 30) }

local ICON = {
	-- passes
	vip = "vip", bigcrew = "hire", cash2x = "up_cash", strength2x = "up_strength", autobuild = "🤖", autotrain = "gym", gems2x = "gem",
	fasttools = "up_power", monster = "cars", goldcar = "cars", teleporter = "locations", stormhammer = "up_power", skipanim = "⏭️",
	-- products
	starter = "gift", rushcrew = "up_crew", cashpack = "cash", cashstack = "cash", cashvault = "coins", cashbank = "store", cashboost = "up_cash",
	spins3 = "spin",
	-- gem shop
	b_cash = "up_cash", b_strength = "up_strength", b_power = "up_power", b_crew = "up_crew", cashbag = "cash", cashsafe = "coins", finish = "timer", crewslot = "hire",
}
local PASS_COL = {
	vip = Color3.fromRGB(255, 190, 40), bigcrew = Color3.fromRGB(90, 200, 120), cash2x = Color3.fromRGB(80, 210, 110), strength2x = Color3.fromRGB(255, 120, 80),
	autobuild = Color3.fromRGB(90, 170, 255), autotrain = Color3.fromRGB(255, 150, 90), gems2x = Color3.fromRGB(70, 190, 255), fasttools = Color3.fromRGB(255, 200, 60),
	monster = Color3.fromRGB(255, 110, 110), goldcar = Color3.fromRGB(255, 196, 46), teleporter = Color3.fromRGB(235, 70, 130),
	stormhammer = Color3.fromRGB(80, 170, 255), skipanim = Color3.fromRGB(90, 200, 255),
}

-- Robux prices load in the background so the Store opens instantly
local priceCache = {}
local function robuxPrice(id, infoType)
	if not id or id <= 0 then return nil end
	if priceCache[id] ~= nil then return priceCache[id] end
	local ok, info = pcall(function() return MarketplaceService:GetProductInfo(id, infoType) end)
	priceCache[id] = ok and info and info.PriceInRobux or false
	return priceCache[id]
end

-- best contract reward you can take right now (cash packs grow with it, like on the server)
local function bestReward()
	local p = c.player
	local rep, lvl, str = p:GetAttribute("Rep") or 0, p:GetAttribute("Level") or 1, p:GetAttribute("Strength") or 0
	local b = 60
	for _, cc in ipairs(Config.Contracts) do
		if rep >= cc.reqRep and lvl >= cc.reqLevel and str >= (cc.reqStrength or 0) and (p:GetAttribute("Rebirths") or 0) >= (cc.reqRebirth or 0) then b = math.max(b, cc.reward) end
	end
	return b
end

local studio = RunService:IsStudio()
local function visible(it) return (it.id or 0) > 0 or studio end
local function cols() return (_G.__CE_ListWidth and _G.__CE_ListWidth() or 780) >= 700 and 4 or 3 end
local function find(list, key) for _, p in ipairs(list) do if p.key == key then return p end end end

-- the Robux button for a product or a pass (or "soon" while it has no id)
local function robuxButton(it, isPass, tok)
	if (it.id or 0) <= 0 then
		return nil, { studio and ("SOON · R$" .. tostring(it.price or "?")) or "SOON", K.LOCK }
	end
	local infoType = isPass and Enum.InfoType.GamePass or Enum.InfoType.Product
	local price = priceCache[it.id]
	return { price and ("R$ " .. price) or "R$ ...", K.GREEN, function(b)
		c.click()
		if isPass then MarketplaceService:PromptGamePassPurchase(c.player, it.id) else MarketplaceService:PromptProductPurchase(c.player, it.id) end
	end, shine = true, fill = price == nil and function(b)
		local pr = robuxPrice(it.id, infoType)
		local l = b and b:FindFirstChild("Label")
		if c.live(tok) and l then l.Text = pr and ("R$ " .. pr) or "BUY" end
	end }
end

-- when a price wasn't cached yet, fill it in once it arrives
local function fillPrices(grid, pending)
	for tile, fn in pairs(pending) do
		task.spawn(function()
			local b
			for _, d in ipairs(tile:GetChildren()) do if d:IsA("TextButton") and d.Name ~= "Corner" then b = d end end
			fn(b)
		end)
	end
end

local function itemTiles(tok, list, order, opts)
	local grid = K.grid(c.content, order, cols(), opts.h or 268)
	local pending = {}
	for i, it in ipairs(list) do
		local o = opts.make(it, i)
		if o then
			o.order = i
			local btn, status = robuxButton(it, opts.pass, tok)
			if o.status == nil and o.button == nil then
				if btn then o.button = btn else o.status = status end
			end
			local t = K.tile(grid, o)
			if o.button and o.button.fill then pending[t] = o.button.fill end
		end
	end
	fillPrices(grid, pending)
	return grid
end

local function teleporterBanner(tok, order)
	local tp = find(Config.Store.passes, "teleporter")
	if not tp or not visible(tp) or c.player:GetAttribute("Pass_teleporter") then return end
	local btn, status = robuxButton(tp, true, tok)
	local b = K.banner(c.content, order, { name = "TELEPORTER", line = "Tap GO in Places and travel anywhere in one tap. Forever.", icon = "locations",
		color = PASS_COL.teleporter, tint = Color3.fromRGB(255, 214, 120), button = btn, status = status, buttonW = 180 })
	if btn and btn.fill then task.spawn(function() btn.fill(b:FindFirstChildOfClass("TextButton")) end) end
end

local function starterBanner(tok, order)
	local st = find(Config.Store.products, "starter")
	if not st or not visible(st) or c.player:GetAttribute("StarterBought") then return end
	local btn, status = robuxButton(st, false, tok)
	local b = K.banner(c.content, order, { name = "STARTER PACK", line = "500 Gems + " .. Config.FormatMoney(bestReward() * 20) .. " + 30 min of 2x Cash. One time only!",
		icon = "gift", color = Color3.fromRGB(255, 110, 140), tint = Color3.fromRGB(255, 190, 210), button = btn, status = status, buttonW = 180 })
	if btn and btn.fill then task.spawn(function() btn.fill(b:FindFirstChildOfClass("TextButton")) end) end
end

local function gems(tok)
	starterBanner(tok, 2)
	K.section(c.content, 3, "GEM PACKS", GEM1, "boosts, helpers and more")
	local packs = {}
	for _, p in ipairs(Config.Store.products) do if p.gems and visible(p) then table.insert(packs, p) end end
	itemTiles(tok, packs, 4, { make = function(p, i)
		local bonus = (p.desc or ""):match("%+(%d+)%%")
		return { name = p.name, icon = "gem", color = GEM_COLS[math.min(i, #GEM_COLS)], badge = p.tag and { p.tag, p.tag == "POPULAR" and T.red or Color3.fromRGB(255, 150, 20) },
			stats = bonus and { { "+" .. bonus .. "% BONUS", K.GREEN } } or { { "GEMS", GEM2 } }, spin = p.tag ~= nil, iconScale = 0.8 + 0.2 * (i / #packs) }
	end })
end

local function cash(tok)
	starterBanner(tok, 2)
	K.section(c.content, 3, "CASH PACKS", Color3.fromRGB(150, 245, 140), "they grow with your progress")
	local packs = {}
	for _, p in ipairs(Config.Store.products) do if p.cash and visible(p) then table.insert(packs, p) end end
	table.sort(packs, function(a, b) return a.cash < b.cash end)
	local best = bestReward()
	itemTiles(tok, packs, 4, { make = function(p, i)
		return { name = p.name, icon = ICON[p.key] or "cash", color = CASH_COLS[math.min(i, #CASH_COLS)], stats = { { "+" .. Config.FormatMoney(best * p.cash), K.GREEN } } }
	end })
end

local function boosts(tok)
	K.section(c.content, 2, "BOOSTS", Color3.fromRGB(255, 220, 110), "they stack with passes")
	local list = {}
	for _, p in ipairs(Config.Store.products) do
		if (p.boost or p.key == "rushcrew" or p.key == "spins3") and visible(p) then table.insert(list, p) end
	end
	itemTiles(tok, list, 3, { make = function(p)
		local left = p.key == "rushcrew" and ((c.player:GetAttribute("RushCrewEnds") or 0) - workspace:GetServerTimeNow())
			or (p.boost and (c.player:GetAttribute("Boost_" .. tostring(p.boost)) or 0) or 0)
		local mins = (p.name or ""):match("(%d+) min")
		return { name = (p.name or ""):gsub("%s*%(.-%)", ""), icon = ICON[p.key] or "up_power", color = Color3.fromRGB(255, 170, 50),
			stats = { mins and { mins .. " MIN", T.blue } or { "x3", T.blue } },
			badge = left > 0 and { "ON " .. c.fmtTime(left), K.GREEN } or nil, spin = left > 0 }
	end })
end

local function passes(tok)
	K.section(c.content, 2, "GAME PASSES", Color3.fromRGB(220, 185, 255), "buy once, keep forever")
	local list = {}
	for _, p in ipairs(Config.Store.passes) do if visible(p) then table.insert(list, p) end end
	itemTiles(tok, list, 3, { pass = true, make = function(p)
		local owned = c.player:GetAttribute("Pass_" .. p.key) == true
		local o = { name = p.name, icon = ICON[p.key] or p.icon, color = PASS_COL[p.key] or T.purple, status = owned and { "OWNED", K.GREEN } or nil, spin = p.key == "vip" }
		if owned and p.key == "skipanim" then
			-- yours: switch the building fly-around off / on
			local on = c.player:GetAttribute("SkipAnim") == true
			o.status = nil
			o.stats = { { on and "NO ANIMATION" or "ANIMATION ON", on and K.GREEN or T.blue } }
			o.button = { on and "SKIP: ON" or "SKIP: OFF", on and K.GREEN or K.LOCK, function()
				c.click()
				local r = RS:FindFirstChild("Remotes") and RS.Remotes:FindFirstChild("SetAuto")
				if r then r:FireServer("skipanim", not on) end
			end }
		end
		return o
	end })
end

local function gemshop(tok)
	local have = c.player:GetAttribute("Gems") or 0
	K.section(c.content, 2, "GEM SHOP", Color3.fromRGB(255, 180, 220), "spend your Gems here")
	local grid = K.grid(c.content, 3, cols(), 268)
	for i, it in ipairs(Config.GemShop) do
		local cost, disabled, stat = it.gems, nil, nil
		if it.kind == "cash" then
			stat = { "+" .. Config.FormatMoney(bestReward() * it.mult), K.GREEN }
		elseif it.kind == "crewslot" then
			local owned = c.player:GetAttribute("GemCrewSlots") or 0
			if owned >= Config.MaxGemCrewSlots then disabled = "MAX" else cost = Config.CrewSlotGems(owned) end
			stat = { owned .. " / " .. Config.MaxGemCrewSlots, T.blue }
		elseif it.kind == "finish" then
			local job = c.Jobs:FindFirstChild(c.player:GetAttribute("ContractJob") or "")
			if not job or job:GetAttribute("Done") then
				disabled = "NO JOB"
			else
				local title, ord = job:GetAttribute("Title"), 1
				for _, cc in ipairs(Config.Contracts) do if cc.name == title then ord = cc.order end end
				cost = Config.FinishGems(1 - (job:GetAttribute("Total") or 0), ord)
			end
			stat = { "NOW!", T.purple }
		elseif it.kind == "boost" then
			stat = { "15 MIN", T.blue }
		end
		local left = it.kind == "boost" and (c.player:GetAttribute("Boost_" .. it.boost) or 0) or 0
		local o = { order = i, name = it.name, icon = ICON[it.id] or it.icon, color = Color3.fromRGB(70, 175, 255), stats = stat and { stat } or nil,
			badge = left > 0 and { "ON " .. c.fmtTime(left), K.GREEN } or nil }
		if disabled then
			o.status = { disabled, K.LOCK }
		else
			local can = have >= cost
			o.button = { Config.FormatNum(cost), can and Color3.fromRGB(60, 180, 255) or K.LOCK, function()
				c.click()
				if not can then
					c.toast("💎 Not enough Gems. Get more in the GEMS tab", T.red, 2.5)
					M.Show("gems")
					return
				end
				local ok, res, msg = pcall(function() return c.R.GemShop:InvokeServer(it.id) end)
				if ok and res then
					if c.live(tok) then M.Show("gemshop", true) end
				else
					c.toast("⚠️ " .. tostring(msg or "Can't buy that"), T.red)
				end
			end, icon = "gem", shine = can }
		end
		K.tile(grid, o)
	end
end

function M.Show(t, keepScroll)
	-- opening the window (not a redraw while it is open) always starts on the first tab
	if t == nil and not (c.modalOpen() and c.modalTitle.Text == "Store") then tab = "gems" end
	if type(t) == "string" then tab = (t == "packs" and "gems") or t end
	if not THEME[tab] then tab = "gems" end
	local scroll = keepScroll and c.modalOpen() and c.content.CanvasPosition or nil
	local th = THEME[tab]
	local tok = c.openModal("Store", "Store", "", th.c1, th.c2)
	if scroll then task.defer(function() c.content.CanvasPosition = scroll end) end
	c.modalSub.Text = "💎 " .. Config.FormatNum(c.player:GetAttribute("Gems") or 0)
	UI.tabs(c.content, TABS, tab, function(id)
		c.click()
		c.content.CanvasPosition = Vector2.zero -- a new tab starts at the top
		M.Show(id)
	end)
	if tab ~= "passes" then teleporterBanner(tok, 1) end
	if tab == "gems" then gems(tok) elseif tab == "cash" then cash(tok) elseif tab == "boosts" then boosts(tok)
	elseif tab == "passes" then passes(tok) else gemshop(tok) end
end

function M.Init(ctx)
	c = ctx
	if c.Config.StormHammer and c.Config.StormHammer.icon then ICON.stormhammer = c.Config.StormHammer.icon end
	UI, T, Config = c.UI, c.T, c.Config
	task.spawn(function()
		for _, p in ipairs(Config.Store.passes) do robuxPrice(p.id, Enum.InfoType.GamePass) end
		for _, p in ipairs(Config.Store.products) do robuxPrice(p.id, Enum.InfoType.Product) end
	end)
	c.player:GetAttributeChangedSignal("Gems"):Connect(function()
		if c.modalOpen() and c.modalTitle.Text == "Store" then c.modalSub.Text = "💎 " .. Config.FormatNum(c.player:GetAttribute("Gems") or 0) end
	end)
	-- a pass bought while the Store is open shows OWNED right away
	c.player.AttributeChanged:Connect(function(a)
		if (a:sub(1, 5) == "Pass_" or a == "SkipAnim") and c.modalOpen() and c.modalTitle.Text == "Store" then M.Show(nil, true) end
	end)
end

return M
