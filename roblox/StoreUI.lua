-- BlockRise Empire - Store window (Robux and Gems), five tabs:
--   GEM SHOP (spend Gems) · PASSES (buy once, keep forever: the Starter Pack on top, then the passes by what they do, each
--   with its picture, what it does and its price) · GEMS (gem packs) · CASH & BOOSTS (instant cash, timed boosts, spins) ·
--   CRATES (hammer crates for Robux)
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
	{ id = "passes", label = "PASSES", icon = "vip", c1 = Color3.fromRGB(205, 150, 255), c2 = Color3.fromRGB(125, 65, 230) },
	{ id = "gems", label = "GEMS", icon = "gem", c1 = GEM1, c2 = GEM2 },
	{ id = "cash", label = "CASH & BOOSTS", icon = "cash", c1 = Color3.fromRGB(130, 240, 120), c2 = Color3.fromRGB(30, 160, 70) },
	{ id = "crates", label = "CRATES", icon = "gift", c1 = Color3.fromRGB(255, 220, 110), c2 = Color3.fromRGB(230, 120, 30) },
}
-- the passes, by what they do (a pass in none of these goes under MORE)
local PASS_GROUPS = {
	{ title = "EARN MORE", color = Color3.fromRGB(150, 245, 140), note = "more cash and Gems from everything you do", keys = { "cash2x", "vip", "gems2x", "offline" } },
	{ title = "BUILD FASTER", color = Color3.fromRGB(140, 210, 255), note = "less clicking, more building", keys = { "autobuild", "fasttools", "bigcrew", "skipanim" } },
	{ title = "GET STRONGER", color = Color3.fromRGB(255, 170, 130), note = "Strength opens bigger contracts", keys = { "strength2x", "autotrain" } },
	{ title = "HAMMERS & CRATES", color = Color3.fromRGB(255, 220, 110), note = "better hammers, opened faster", keys = { "luck", "quickopen", "autoopen", "stormhammer" } },
	{ title = "RIDES & TRAVEL", color = Color3.fromRGB(255, 160, 200), note = "get around the city", keys = { "teleporter", "goldcar", "monster" } },
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
-- no paid random items in your country (Roblox: PolicyService ArePaidRandomItemsRestricted; the server's word first)
local function noPaidRandom() return c.player:GetAttribute("PaidRandomRestricted") == true or c.paidRandomRestricted == true end
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
	-- what is inside, as chips under the line
	local b = K.banner(c.content, order, { name = "STARTER PACK", line = "One time only - the best deal in the game:", height = 128,
		chips = { { "500 💎", GEM2 }, { Config.FormatMoney(bestReward() * 20), Color3.fromRGB(40, 160, 80) }, { "BUILDER'S CRATE", Color3.fromRGB(230, 120, 30) },
			{ "2x CASH 30 MIN", Color3.fromRGB(120, 90, 230) } },
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

local function boostTiles(tok, order)
	local list = {}
	for _, p in ipairs(Config.Store.products) do
		-- (Lucky Spins are paid random items: not sold where Roblox doesn't allow them)
		if (p.boost or p.key == "rushcrew" or (p.key == "spins3" and not noPaidRandom())) and visible(p) then table.insert(list, p) end
	end
	itemTiles(tok, list, order, { make = function(p)
		local left = p.key == "rushcrew" and ((c.player:GetAttribute("RushCrewEnds") or 0) - workspace:GetServerTimeNow())
			or (p.boost and (c.player:GetAttribute("Boost_" .. tostring(p.boost)) or 0) or 0)
		local mins = (p.name or ""):match("(%d+) min")
		local icon, sc = iconOf(p.key, "up_power")
		return { name = (p.name or ""):gsub("%s*%(.-%)", ""), icon = icon, iconScale = sc, color = Color3.fromRGB(255, 170, 50),
			stats = { mins and { mins .. " MIN", T.blue } or { "x" .. tostring(p.spins or 3), T.blue } },
			badge = left > 0 and { "ON " .. c.fmtTime(left), K.GREEN } or nil, spin = left > 0 }
	end })
end

local function cash(tok)
	K.section(c.content, 3, "INSTANT CASH", Color3.fromRGB(150, 245, 140), "worth minutes of YOUR income: the further you get, the more they give")
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
			-- (BEST VALUE next to the amount: in the picture's corner it covered the "OF INCOME" badge)
			if p.key == "cashvault" then table.insert(o.stats, { "BEST VALUE", T.red }); o.spin = true end
		end
		return o
	end })
	K.section(c.content, 5, "BOOSTS & SPINS", Color3.fromRGB(255, 220, 110), "for a while, on top of your passes")
	boostTiles(tok, 6)
end

-- hammer crates for Robux (the Gem and cash crates are in Shop → HAMMERS)
local function crates(tok)
	local Hammers = require(RS.Shared:WaitForChild("Hammers"))
	K.section(c.content, 2, "HAMMER CRATES", Color3.fromRGB(255, 220, 110), "odds shown on each · open them in Inventory → HAMMERS")
	if noPaidRandom() then
		K.empty(c.content, 3, "In your country crates show the hammer inside before you buy them (X-Ray): they're in Shop → HAMMERS, for cash or Gems.", "gift")
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

-- one pass as a wide card: picture, name, what it does, and its price (or OWNED / ON-OFF when it is yours)
local function passCard(grid, p, order, tok)
	local owned = c.player:GetAttribute("Pass_" .. p.key) == true
	local f = c.new("Frame", { Name = "Pass_" .. p.key, BackgroundTransparency = 1, LayoutOrder = order, ZIndex = 2, Parent = grid })
	c.UI.slice("tile", { Name = "Bg", ImageColor3 = owned and Color3.fromRGB(226, 246, 230) or K.TILE, ZIndex = 1, Parent = f })
	local icon, sc = iconOf(p.key, p.icon)
	local box = K.artBox(f, icon, PASS_COL[p.key] or T.purple, { Position = UDim2.fromOffset(8, 8), Size = UDim2.fromOffset(104, 104), Spin = not owned, IconScale = sc })
	box.ZIndex = 2
	K.text({ Position = UDim2.fromOffset(124, 10), Size = UDim2.new(1, -136, 0, 26), Text = p.name, Font = T.chunky, TextSize = 21, Max = 21, ZIndex = 3, Parent = f })
	local desc = (p.desc or ""):gsub("%s*Turn it on.*$", "")
	K.text({ Position = UDim2.fromOffset(124, 38), Size = UDim2.new(1, -136, 0, 38), Text = desc, TextSize = 14, Max = 14, TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top, TextColor3 = K.SUB, ZIndex = 3, Parent = f })
	-- the bottom right: the price, or what you have
	local bw = 150
	local pos = { AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -10, 1, -10), Size = UDim2.fromOffset(bw, 40) }
	local toggle = owned and (p.key == "skipanim" and "SkipAnim" or (p.key == "quickopen" and "QuickOpen" or nil))
	if toggle then
		-- yours: switch it off / on
		local on = c.player:GetAttribute(toggle) == true
		K.button(f, on and "ON" or "OFF", on and K.GREEN or K.LOCK, { AnchorPoint = pos.AnchorPoint, Position = pos.Position, Size = pos.Size, TextSize = 19, ZIndex = 5 }, function()
			c.click()
			local r = RS:FindFirstChild("Remotes") and RS.Remotes:FindFirstChild("SetAuto")
			if r then r:FireServer(p.key, not on) end
		end)
		K.chip(f, "OWNED", K.GREEN, { AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 124, 1, -16), ZIndex = 5 })
	elseif owned then
		K.status(f, "✔ OWNED", K.GREEN, { AnchorPoint = pos.AnchorPoint, Position = pos.Position, Size = pos.Size })
	else
		local btn, status = robuxButton(p, true, tok)
		if btn then
			local b = K.button(f, btn[1], btn[2], { AnchorPoint = pos.AnchorPoint, Position = pos.Position, Size = pos.Size, TextSize = 20, ZIndex = 5, Shine = true }, btn[3])
			if btn.fill then task.spawn(function() btn.fill(b) end) end
		else
			K.status(f, status[1], status[2], { AnchorPoint = pos.AnchorPoint, Position = pos.Position, Size = pos.Size })
		end
		K.chip(f, "FOREVER", Color3.fromRGB(125, 65, 230), { AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 124, 1, -16), ZIndex = 5 })
	end
	return f
end

local function passes(tok)
	-- the Starter Pack first (one time only), then every pass by what it does
	starterBanner(tok, 1)
	local all, seen = {}, {}
	for _, p in ipairs(Config.Store.passes) do
		-- the Thunderclap pass isn't sold any more (the hammer is in the Exclusive Crate): only its owners still see it
		local gone = Config.StormHammer and p.key == Config.StormHammer.pass and c.player:GetAttribute("Pass_" .. p.key) ~= true
		if visible(p) and not gone then all[p.key] = p end
	end
	local nOwned, nAll = 0, 0
	for _, p in pairs(all) do
		nAll += 1
		if c.player:GetAttribute("Pass_" .. p.key) == true then nOwned += 1 end
	end
	local groups = table.clone(PASS_GROUPS)
	local rest = {}
	for key in pairs(all) do
		local inOne = false
		for _, g in ipairs(PASS_GROUPS) do if table.find(g.keys, key) then inOne = true end end
		if not inOne then table.insert(rest, key) end
	end
	table.sort(rest)
	if #rest > 0 then table.insert(groups, { title = "MORE", color = Color3.fromRGB(220, 185, 255), note = "", keys = rest }) end
	local order = 2
	local twoCols = (_G.__CE_ListWidth and _G.__CE_ListWidth() or 780) >= 700
	for gi, g in ipairs(groups) do
		local list = {}
		for _, key in ipairs(g.keys) do if all[key] and not seen[key] then seen[key] = true; table.insert(list, all[key]) end end
		if #list > 0 then
			-- the ones you can buy first (cheapest first), then the ones coming soon, yours last
			local function rank(p)
				if c.player:GetAttribute("Pass_" .. p.key) == true then return 3 end
				return (p.id or 0) > 0 and 1 or 2
			end
			table.sort(list, function(a, b)
				local ra, rb = rank(a), rank(b)
				if ra ~= rb then return ra < rb end
				return (a.price or 0) < (b.price or 0)
			end)
			K.section(c.content, order, g.title, g.color, gi == 1 and (g.note .. "  ·  you own " .. nOwned .. " of " .. nAll) or g.note)
			local grid = K.grid(c.content, order + 1, twoCols and 2 or 1, 122, 10)
			-- (a lone pass sits on the left, under its title, not in the middle)
			local gl = grid:FindFirstChildOfClass("UIGridLayout")
			if gl then gl.HorizontalAlignment = Enum.HorizontalAlignment.Left end
			for i, p in ipairs(list) do passCard(grid, p, i, tok) end
			order += 2
		end
	end
	K.note(c.content, order, "Passes are yours forever: they stay through Rebirths and work in every server.")
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
	if type(t) == "string" then tab = (t == "packs" and "gems") or (t == "boosts" and "cash") or t end
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
	-- (the Teleporter offer: on the first tab only, it is in PASSES with the others)
	if tab == "gemshop" then teleporterBanner(tok, 1) end
	if tab == "gems" then gems(tok) elseif tab == "cash" then cash(tok) elseif tab == "crates" then crates(tok)
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
