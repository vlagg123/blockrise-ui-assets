-- BlockRise Empire - Store window (Robux and Gems): gem packs, cash packs, boosts, passes and the Gem Shop, as item tiles.
-- The Teleporter offer sits on top of every tab until you own it.
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local MarketplaceService = game:GetService("MarketplaceService")
local K = require(RS.Shared:WaitForChild("MenuKit"))

local M = {}
local c, UI, T, Config
local tab = "gemshop"

local GEM1, GEM2 = Color3.fromRGB(120, 230, 255), Color3.fromRGB(30, 140, 220)
-- (the Gem Shop first: the Store always opens on it; the CRATES tab shows a crate, set in M.Init)
local TABS = {
	{ id = "gemshop", label = "GEM SHOP", icon = "store", c1 = Color3.fromRGB(255, 150, 200), c2 = Color3.fromRGB(215, 60, 140) },
	{ id = "gems", label = "GEMS", icon = "gem", c1 = GEM1, c2 = GEM2 },
	{ id = "cash", label = "CASH", icon = "cash", c1 = Color3.fromRGB(130, 240, 120), c2 = Color3.fromRGB(30, 160, 70) },
	{ id = "crates", label = "CRATES", icon = "gift", c1 = Color3.fromRGB(255, 220, 110), c2 = Color3.fromRGB(230, 120, 30) },
	{ id = "boosts", label = "BOOSTS", icon = "up_power", c1 = Color3.fromRGB(255, 205, 70), c2 = Color3.fromRGB(240, 130, 20) },
	{ id = "passes", label = "PASSES", icon = "vip", c1 = Color3.fromRGB(205, 150, 255), c2 = Color3.fromRGB(125, 65, 230) },
}
local THEME = {}
for _, t in ipairs(TABS) do THEME[t.id] = t end
local GEM_COLS = { Color3.fromRGB(90, 200, 255), Color3.fromRGB(60, 160, 255), Color3.fromRGB(120, 120, 255), Color3.fromRGB(165, 90, 255),
	Color3.fromRGB(255, 150, 40), Color3.fromRGB(255, 70, 120) }
local CASH_COLS = { Color3.fromRGB(120, 210, 90), Color3.fromRGB(60, 190, 120), Color3.fromRGB(255, 190, 40), Color3.fromRGB(255, 140, 30) }

local ICON = {
	-- passes
	vip = "vip", bigcrew = "hire", cash2x = "up_cash", strength2x = "up_strength", autobuild = "🤖", autotrain = "gym", gems2x = "gem",
	fasttools = "up_power", monster = "cars", goldcar = "cars", teleporter = "locations", stormhammer = "up_power", skipanim = "⏭️", luck = "up_luck", offline = "up_rent",
	quickopen = "gift", autoopen = "gift",
	-- products
	starter = "gift", rushcrew = "up_crew", cashpack = "cash", cashstack = "cash", cashvault = "coins", cashbank = "store", cashboost = "up_cash",
	spins3 = "spin",
	-- gem shop
	b_cash = "up_cash", b_strength = "up_strength", b_power = "up_power", b_crew = "up_crew", cashbag = "cash", cashsafe = "coins", finish = "timer", crewslot = "hire",
}
-- the Blender pictures of everything sold for Robux (Config.ProductImages), the old atlas icons as fallback
local function iconOf(key, fallback)
	local img = Config.ProductImages and Config.ProductImages[key]
	return img or ICON[key] or fallback, img and 1.06 or nil
end
local PASS_COL = {
	vip = Color3.fromRGB(255, 190, 40), bigcrew = Color3.fromRGB(90, 200, 120), cash2x = Color3.fromRGB(80, 210, 110), strength2x = Color3.fromRGB(255, 120, 80),
	autobuild = Color3.fromRGB(90, 170, 255), autotrain = Color3.fromRGB(255, 150, 90), gems2x = Color3.fromRGB(70, 190, 255), fasttools = Color3.fromRGB(255, 200, 60),
	monster = Color3.fromRGB(255, 110, 110), goldcar = Color3.fromRGB(255, 196, 46), teleporter = Color3.fromRGB(235, 70, 130),
	stormhammer = Color3.fromRGB(80, 170, 255), skipanim = Color3.fromRGB(90, 200, 255), luck = Color3.fromRGB(80, 200, 100), offline = Color3.fromRGB(110, 110, 230),
	quickopen = Color3.fromRGB(255, 186, 50), autoopen = Color3.fromRGB(255, 150, 60),
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
local function perMin() return c.player:GetAttribute("IncomePerMin") or 0 end
-- what a cash pack gives right now: minutes of your income (or, the old way, contract rewards)
local function packCash(p)
	if p.minutes then return math.floor(perMin() * p.minutes) end
	return 0
end
local function minLabel(m) return m >= 60 and ((m % 60 == 0) and (m // 60 .. "H") or (string.format("%.1fH", m / 60))) .. " OF INCOME" or (m .. " MIN OF INCOME") end
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
		return nil, { studio and ("SOON · \u{E002} " .. tostring(it.price or "?")) or "SOON", K.LOCK }
	end
	local infoType = isPass and Enum.InfoType.GamePass or Enum.InfoType.Product
	local price = priceCache[it.id]
	return { price and ("\u{E002} " .. price) or "\u{E002} ...", K.GREEN, function(b)
		c.click()
		if isPass then MarketplaceService:PromptGamePassPurchase(c.player, it.id) else MarketplaceService:PromptProductPurchase(c.player, it.id) end
	end, shine = true, fill = price == nil and function(b)
		local pr = robuxPrice(it.id, infoType)
		local l = b and b:FindFirstChild("Label")
		if c.live(tok) and l then l.Text = pr and ("\u{E002} " .. pr) or "BUY" end
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
	local b = K.banner(c.content, order, { name = "TELEPORTER", line = "Tap GO in Places and travel anywhere in one tap. Forever.", icon = (iconOf("teleporter", "locations")),
		color = PASS_COL.teleporter, tint = Color3.fromRGB(255, 214, 120), button = btn, status = status, buttonW = 180 })
	if btn and btn.fill then task.spawn(function() btn.fill(b:FindFirstChildOfClass("TextButton")) end) end
end

local function starterBanner(tok, order)
	local st = find(Config.Store.products, "starter")
	if not st or not visible(st) or c.player:GetAttribute("StarterBought") then return end
	local btn, status = robuxButton(st, false, tok)
	local b = K.banner(c.content, order, { name = "STARTER PACK", line = "500 Gems + " .. Config.FormatMoney(bestReward() * 20) .. " + a Builder's Crate + 30 min of 2x Cash. One time only!",
		icon = (iconOf("starter", "gift")), color = Color3.fromRGB(255, 110, 140), tint = Color3.fromRGB(255, 190, 210), button = btn, status = status, buttonW = 180 })
	if btn and btn.fill then task.spawn(function() btn.fill(b:FindFirstChildOfClass("TextButton")) end) end
end

local function gems(tok)
	starterBanner(tok, 2)
	K.section(c.content, 3, "GEM PACKS", GEM1, "boosts, helpers and more")
	local packs = {}
	for _, p in ipairs(Config.Store.products) do if p.gems and visible(p) then table.insert(packs, p) end end
	-- (no chips on these cards: the price sits right under the name)
	itemTiles(tok, packs, 4, { h = 232, make = function(p, i)
		local bonus = (p.desc or ""):match("%+(%d+)%%")
		local icon, sc = iconOf(p.key, "gem")
		return { name = p.name, icon = icon, color = GEM_COLS[math.min(i, #GEM_COLS)], badge = p.tag and { p.tag, p.tag == "POPULAR" and T.red or Color3.fromRGB(255, 150, 20) },
			bubble = bonus and { "+" .. bonus .. "%", "BONUS", K.GREEN } or nil, spin = p.tag ~= nil, iconScale = sc or (0.8 + 0.2 * (i / #packs)) }
	end })
end

local function cash(tok)
	starterBanner(tok, 2)
	K.section(c.content, 3, "CASH PACKS", Color3.fromRGB(150, 245, 140), "they grow with your progress")
	local packs = {}
	local best = bestReward()
	local function value(p) return p.minutes and packCash(p) or best * (p.cash or 0) end
	for _, p in ipairs(Config.Store.products) do if (p.cash or p.minutes) and visible(p) then table.insert(packs, p) end end
	table.sort(packs, function(a, b) return (a.price or 0) < (b.price or 0) end)
	itemTiles(tok, packs, 4, { make = function(p, i)
		local icon, sc = iconOf(p.key, "cash")
		local o = { name = p.name, icon = icon, iconScale = sc, color = CASH_COLS[math.min(i, #CASH_COLS)], stats = { { "+" .. Config.FormatMoney(value(p)), K.GREEN } } }
		if p.minutes then
			o.badge = { minLabel(p.minutes), T.blue }
			if p.key == "cashvault" then o.tag = { "BEST VALUE", T.red }; o.spin = true end
		end
		return o
	end })
	K.note(c.content, 5, "Cash packs are worth minutes of YOUR income: the further you get, the more they give.")
end

-- hammer crates for Robux (the Gem and cash crates are in Shop → HAMMERS)
local function crates(tok)
	local Hammers = require(RS.Shared:WaitForChild("Hammers"))
	K.section(c.content, 2, "HAMMER CRATES", Color3.fromRGB(255, 220, 110), "odds shown on each · open them in Inventory → HAMMERS")
	if c.paidRandomRestricted then
		K.empty(c.content, 3, "Crates for Robux are not available in your region. Get them with Gems or cash in Shop → HAMMERS.", "gift")
		return
	end
	local list = {}
	for _, p in ipairs(Config.Store.products) do
		-- (a crate whose hammers are still being made isn't sold)
		if p.crate and visible(p) and next(Hammers.Odds(p.crate, "town", 1)) ~= nil then table.insert(list, p) end
	end
	itemTiles(tok, list, 3, { h = 300, make = function(p)
		local cr = Hammers.CrateById[p.crate]
		local odds = Hammers.Odds(p.crate, c.player:GetAttribute("CrateZone") or "town", 1)
		local parts = {}
		for r = #Hammers.Rarities, 1, -1 do
			if odds[r] and odds[r] > 0 and #parts < 3 then
				table.insert(parts, { Hammers.Rarities[r].name:upper() .. " " .. (odds[r] >= 1 and string.format("%.0f%%", odds[r]) or string.format("%.1f%%", odds[r])),
					Hammers.Rarities[r].text and Color3.fromRGB(70, 70, 110) or Hammers.Rarities[r].color })
			end
		end
		local o = { name = p.name, icon = (Config.ProductImages and Config.ProductImages[p.key]) or (cr and cr.image) or "gift", color = cr and cr.color or T.accent, stats = { parts[1], parts[2] },
			badge = (p.count or 1) > 1 and { "x" .. p.count, T.red } or nil, tag = cr and cr.pity and { "PITY " .. cr.pity.every, Color3.fromRGB(255, 176, 40) } or nil, spin = (p.count or 1) > 1 }
		return o
	end })
	local luck = find(Config.Store.passes, "luck")
	if luck and visible(luck) and not c.player:GetAttribute("Pass_luck") then
		local btn, status = robuxButton(luck, true, tok)
		local b = K.banner(c.content, 4, { name = "LUCKY BUILDER", line = "2x luck in every crate: Rare and better hammers drop twice as often. Forever.", icon = (iconOf("luck", "up_luck")),
			color = Color3.fromRGB(80, 200, 100), tint = Color3.fromRGB(190, 255, 190), button = btn, status = status, buttonW = 180 })
		if btn and btn.fill then task.spawn(function() btn.fill(b:FindFirstChildOfClass("TextButton")) end) end
	end
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
		local icon, sc = iconOf(p.key, "up_power")
		return { name = (p.name or ""):gsub("%s*%(.-%)", ""), icon = icon, iconScale = sc, color = Color3.fromRGB(255, 170, 50),
			stats = { mins and { mins .. " MIN", T.blue } or { "x" .. tostring(p.spins or 3), T.blue } },
			badge = left > 0 and { "ON " .. c.fmtTime(left), K.GREEN } or nil, spin = left > 0 }
	end })
end

local function passes(tok)
	K.section(c.content, 2, "GAME PASSES", Color3.fromRGB(220, 185, 255), "buy once, keep forever")
	local list = {}
	for _, p in ipairs(Config.Store.passes) do
		-- the Thunderclap pass isn't sold any more (the hammer is in the Exclusive Crate): only its owners still see it
		local gone = Config.StormHammer and p.key == Config.StormHammer.pass and c.player:GetAttribute("Pass_" .. p.key) ~= true
		if visible(p) and not gone then table.insert(list, p) end
	end
	itemTiles(tok, list, 3, { pass = true, make = function(p)
		local owned = c.player:GetAttribute("Pass_" .. p.key) == true
		local icon, sc = iconOf(p.key, p.icon)
		local o = { name = p.name, icon = icon, iconScale = sc, color = PASS_COL[p.key] or T.purple, status = owned and { "OWNED", K.GREEN } or nil, spin = p.key == "vip" }
		if owned and p.key == "skipanim" then
			-- yours: switch the building fly-around off / on
			local on = c.player:GetAttribute("SkipAnim") == true
			o.status = nil
			o.stats = { { on and "NO ANIMATION" or "ANIMATION ON", on and K.GREEN or T.blue } }
			o.button = { on and "ON" or "OFF", on and K.GREEN or K.LOCK, function()
				c.click()
				local r = RS:FindFirstChild("Remotes") and RS.Remotes:FindFirstChild("SetAuto")
				if r then r:FireServer("skipanim", not on) end
			end }
		elseif owned and p.key == "quickopen" then
			-- yours: the crate strip off / on
			local on = c.player:GetAttribute("QuickOpen") == true
			o.status = nil
			o.stats = { { on and "HAMMER AT ONCE" or "STRIP ON", on and K.GREEN or T.blue } }
			o.button = { on and "ON" or "OFF", on and K.GREEN or K.LOCK, function()
				c.click()
				local r = RS:FindFirstChild("Remotes") and RS.Remotes:FindFirstChild("SetAuto")
				if r then r:FireServer("quickopen", not on) end
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
			stat = { "+" .. Config.FormatMoney(it.minutes and math.floor(perMin() * it.minutes) or bestReward() * (it.mult or 1)), K.GREEN }
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
	-- opening the window (not a redraw while it is open) always starts on the first tab: the Gem Shop
	if t == nil and not (c.modalOpen() and c.modalTitle.Text == "Store") then tab = "gemshop" end
	if type(t) == "string" then tab = (t == "packs" and "gems") or t end
	if not THEME[tab] then tab = "gemshop" end
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
	if tab == "gems" then gems(tok) elseif tab == "cash" then cash(tok) elseif tab == "crates" then crates(tok) elseif tab == "boosts" then boosts(tok)
	elseif tab == "passes" then passes(tok) else gemshop(tok) end
end

function M.Init(ctx)
	c = ctx
	if c.Config.StormHammer and c.Config.StormHammer.icon then ICON.stormhammer = c.Config.StormHammer.icon end
	UI, T, Config = c.UI, c.T, c.Config
	-- the CRATES tab: the Golden Crate without sparkles (icons/plain/crate_golden.png)
	THEME.crates.icon = "rbxassetid://109896821556277"
	task.spawn(function()
		for _, p in ipairs(Config.Store.passes) do robuxPrice(p.id, Enum.InfoType.GamePass) end
		for _, p in ipairs(Config.Store.products) do robuxPrice(p.id, Enum.InfoType.Product) end
	end)
	c.player:GetAttributeChangedSignal("Gems"):Connect(function()
		if c.modalOpen() and c.modalTitle.Text == "Store" then c.modalSub.Text = "💎 " .. Config.FormatNum(c.player:GetAttribute("Gems") or 0) end
	end)
	-- a pass bought while the Store is open shows OWNED right away
	c.player.AttributeChanged:Connect(function(a)
		if (a:sub(1, 5) == "Pass_" or a == "SkipAnim" or a == "QuickOpen") and c.modalOpen() and c.modalTitle.Text == "Store" then M.Show(nil, true) end
	end)
end

return M
