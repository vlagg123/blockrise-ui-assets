-- BlockRise Empire - hammers as items (a Client child module, used by ShopUI and UpgradesUI/Inventory):
--   Shop → CRATES:        every crate with its price, odds and a "what's inside" popup; buy and open
--   Inventory → HAMMERS:  every hammer you own as a small item tile (6 a row), rarity filters, the one you tap on top (EQUIP / LEVEL UP)
--   Inventory → CRATES:   the crates you have, one OPEN each
--   Inventory → TRADE-UP: a contract like CS:GO: 10 hammers of one rarity in the slots -> 1 random hammer of the next
--   Inventory → INDEX:    the collection book (all 40), tap one to see where it comes from
-- Opening a crate: the strip of hammers spins like a case opening and lands on yours, then HammerFX's reveal card.
local RS = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")
local PolicyService = game:GetService("PolicyService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local TextService = game:GetService("TextService")
local Icons = require(RS.Shared:WaitForChild("Icons"))
local K = require(RS.Shared:WaitForChild("MenuKit"))
local Hammers = require(RS.Shared:WaitForChild("Hammers"))

local M = {}
local c, UI, T, Config, new
local HammerAction
local cache -- the last "get" answer
local busy = false
local GOLD = Color3.fromRGB(255, 190, 40)
local GEM = Color3.fromRGB(60, 180, 255)
local EQUIP_BLUE = Color3.fromRGB(70, 160, 255)
local GREEN_TXT = Color3.fromRGB(35, 154, 69)
local studio = RunService:IsStudio()
local rng = Random.new()

local function money() return c.player:GetAttribute("Money") or 0 end
-- the tutorial: the Hammers Shop sells its one Supply Crate (no gems / Robux crates, no passes, no Inventory yet)
local function inTut() return (c.player:GetAttribute("RoadStep") or 1) <= (Config.TutorialSteps or 7) end
local function gems() return c.player:GetAttribute("Gems") or 0 end
local function fmt(n) return Config.FormatMoney(n) end
local function wide() return (_G.__CE_ListWidth and _G.__CE_ListWidth() or 780) >= 700 end
local function cols() return wide() and 4 or 3 end
local function invCols() return wide() and 6 or 4 end
local function rar(h) return Hammers.Rarities[h.dr or h.r] end -- the rarity a hammer is SHOWN as (Exclusive for the pass hammer)
local function rarText(r) return r.text and Color3.fromRGB(90, 80, 130) or r.color:Lerp(Color3.new(0, 0, 0), 0.15) end
-- the picture of a hammer: the Thunderclap's pass art, its own render, or the Shop atlas icon
local function art(h)
	if Config.StormHammer and h.key == Config.StormHammer.key and Config.StormHammer.icon then return Config.StormHammer.icon end
	if h.image and Config.ProductImages and Config.ProductImages[h.image] then return Config.ProductImages[h.image] end
	if h.img then return h.img end -- (its own render: every hammer made after the first 15)
	for _, t in ipairs(Config.Tools) do if t.key == h.key and t.icon then return t.icon end end
	return "shop"
end
M.art = art
local function crateArt(cr) return cr.image or "gift" end
local function product(key)
	for _, p in ipairs(Config.Store.products) do if p.key == key then return p end end
end
local function pct(v) return v >= 10 and string.format("%d%%", math.floor(v + 0.5)) or (v >= 1 and string.format("%.1f%%", v) or string.format("%.2f%%", v)) end
local function canTrade(it, h) return not it.bound and not it.pass and not h.exclusive and not h.event and it.id ~= "rusty" end
-- a hammer that arrived in the last half hour (from a crate, a trade-up or a trade) is NEW until you look at it
local seen = {}
local function isNew(it)
	if seen[it.id] or not it.t or it.s == "start" or it.s == "migrate" or it.s == "pass" then return false end
	return os.time() - it.t < 1800
end

local function call(action, a, b)
	if not HammerAction then return false, "Loading..." end
	local ok, res, msg = pcall(function() return HammerAction:InvokeServer(action, a, b) end)
	if not ok then return false, "No answer from the server" end
	return res, msg
end

local function fetch()
	local ok, data = call("get")
	if ok and type(data) == "table" then cache = data end
	return cache
end
-- a redraw right after M.Redraw fetched the new state draws in one go: no spinner, no empty window blinking in between
local freshUntil = 0
local function dataNow()
	if cache and os.clock() < freshUntil then return cache end
	local loading = K.loading(c.content)
	local data = fetch()
	if loading.Parent then loading:Destroy() end
	return data
end

local function sortHammers(list, equipId)
	table.sort(list, function(a, b)
		local ha, hb = Hammers.ById[a.k], Hammers.ById[b.k]
		if equipId then
			if a.id == equipId then return true elseif b.id == equipId then return false end
		end
		if (ha.dr or ha.r) ~= (hb.dr or hb.r) then return (ha.dr or ha.r) > (hb.dr or hb.r) end
		if a.lv ~= b.lv then return a.lv > b.lv end
		if ha.order ~= hb.order then return ha.order < hb.order end
		return tostring(a.id) < tostring(b.id) -- same hammer, same level: always the same order (table.sort is not stable)
	end)
end

---------------------------------------------------------------------------------------------------------------------
-- Popups: a small window over everything (what's inside a crate / one hammer)
---------------------------------------------------------------------------------------------------------------------
local popup
local function closePopup()
	if popup then popup:Destroy(); popup = nil end
end
local function openPopup(size, title, c1, c2, icon)
	closePopup()
	local gui = new("ScreenGui", { Name = "HammerPopup", IgnoreGuiInset = true, DisplayOrder = 100, ResetOnSpawn = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, Parent = c.player:WaitForChild("PlayerGui") })
	popup = gui
	local dim = new("TextButton", { Text = "", AutoButtonColor = false, Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.5, Parent = gui })
	dim.Activated:Connect(closePopup)
	local w, x = K.window(dim, size, title, c1, c2, icon)
	local fit = math.clamp(math.min(c.camera.ViewportSize.X / (size.X.Offset + 80), (c.camera.ViewportSize.Y - 40) / (size.Y.Offset + 80)), 0.5, 1.1)
	local sc = new("UIScale", { Scale = fit * 0.8, Parent = w })
	UI.tween(sc, 0.25, { Scale = fit }, Enum.EasingStyle.Back)
	x.Activated:Connect(function() c.click(); closePopup() end)
	local body = new("Frame", { Name = "Content", Position = UDim2.fromOffset(18, 56), Size = UDim2.new(1, -36, 1, -74), BackgroundTransparency = 1, ZIndex = 5, Parent = w })
	return body, w
end

-- where a hammer comes from (the Index)
local function sources(h)
	local out = {}
	if h.key == Hammers.DefaultKey then return { "Everyone's first hammer. Yours forever." } end
	if h.pass then return { "The Thunderclap Hammer game pass (Store → PASSES)" } end
	if h.event then return { "The launch event only" } end
	if h.soon then return { "Coming soon: it isn't in any crate yet" } end
	for _, cr in ipairs(Hammers.Crates) do
		-- the crate must be able to drop this rarity (its odds), and the hammer must be in its pool
		local fits = (cr.exclusiveOnly and h.exclusive) or (not cr.exclusiveOnly and not h.exclusive)
		local zones = {}
		if cr.pools then
			for _, z in ipairs({ "town", "suburbs", "downtown" }) do if (cr.pools[z] or {})[h.r] and cr.pools[z][h.r] > 0 then table.insert(zones, z:sub(1, 1):upper() .. z:sub(2)) end end
			fits = fits and #zones > 0
		else
			fits = fits and (cr.odds[h.r] or 0) > 0
		end
		if fits then table.insert(out, cr.name .. (#zones > 0 and (" (" .. table.concat(zones, ", ") .. ")") or "")) end
	end
	if not h.exclusive and h.r > 1 then table.insert(out, "Trade-up: " .. Hammers.TradeUpCount .. " " .. Hammers.Rarities[h.r - 1].name .. " hammers") end
	if not h.exclusive or h.r >= 5 then table.insert(out, "Trades with other builders") end
	return out
end

local equipItem, levelUpItem
-- one hammer: the big picture, what it is, where it comes from (and EQUIP when it's one of yours)
local function hammerPopup(h, it, data)
	local r = rar(h)
	local body, pw = openPopup(UDim2.fromOffset(620, 400), h.name, r.color:Lerp(Color3.new(1, 1, 1), 0.2), r.color, nil)
	local box = K.artBox(body, art(h), r.color, { Position = UDim2.fromOffset(0, 8), Size = UDim2.fromOffset(220, 220), Spin = true, IconScale = 1.06 })
	box.ZIndex = 5
	K.rarityFX(box, r.id)
	local ttl = pw and pw:FindFirstChild("Header") and pw.Header:FindFirstChild("Title")
	if ttl and K.RARITY_LOOK[r.id] then
		K.rarityText(ttl, r.id)
		local rib = pw.Header:FindFirstChild("Ribbon")
		if rib then K.rarityChip(rib, r.id) end
	end
	local x = 240
	local chips = new("Frame", { Position = UDim2.fromOffset(x, 10), Size = UDim2.new(1, -x, 0, 28), BackgroundTransparency = 1, ZIndex = 6, Parent = body })
	new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = chips })
	K.rarityChip(K.chip(chips, string.upper(r.name), r.color, { LayoutOrder = 1 }), r.id)
	K.chip(chips, Hammers.PowerLabel(h.key, it and it.lv or 1) .. " POWER", GOLD, { LayoutOrder = 2 })
	if it then K.chip(chips, "LV " .. it.lv .. "/" .. Hammers.MaxLevel, Color3.fromRGB(60, 56, 110), { LayoutOrder = 3 }) end
	if h.exclusive and r.id ~= "exclusive" then K.chip(chips, "EXCLUSIVE", T.red, { LayoutOrder = 4 }) end
	K.text({ Position = UDim2.fromOffset(x, 46), Size = UDim2.new(1, -x, 0, 60), Text = h.desc, TextSize = 18, TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top,
		TextColor3 = Color3.new(1, 1, 1), Stroke = 2, ZIndex = 6, Parent = body })
	K.text({ Position = UDim2.fromOffset(x, 112), Size = UDim2.new(1, -x, 0, 24), Text = "WHERE TO FIND IT", Font = T.chunky, TextSize = 18, TextColor3 = Color3.fromRGB(255, 230, 150), Stroke = 2, ZIndex = 6, Parent = body })
	local y = 138
	for _, line in ipairs(sources(h)) do
		K.text({ Position = UDim2.fromOffset(x, y), Size = UDim2.new(1, -x, 0, 22), Text = "•  " .. line, TextSize = 16, Max = 16, TextColor3 = K.NOTE, ZIndex = 6, Parent = body })
		y += 22
	end
	-- levels: +8% a level, the cost of the next
	K.text({ Position = UDim2.fromOffset(x, y + 6), Size = UDim2.new(1, -x, 0, 22), TextSize = 15, Max = 15, TextColor3 = K.NOTE, ZIndex = 6, Parent = body,
		Text = "Levels 1–" .. Hammers.MaxLevel .. ": +" .. math.floor(Hammers.LevelStep * 100) .. "% power each (Lv 2 costs " .. fmt(Hammers.LevelCost(h.key, 1)) .. ")" })
	if it and data then
		local inHand = it.id == data.equip
		local holder = new("Frame", { AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 0, 1, 0), Size = UDim2.new(1, 0, 0, 56), BackgroundTransparency = 1, ZIndex = 6, Parent = body })
		new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 10), HorizontalAlignment = Enum.HorizontalAlignment.Right, SortOrder = Enum.SortOrder.LayoutOrder, Parent = holder })
		local cost = Hammers.LevelCost(it.k, it.lv)
		if cost then
			local can = money() >= cost
			K.button(holder, "⬆ LV " .. (it.lv + 1) .. "  " .. fmt(cost), can and GOLD or K.LOCK, { Size = UDim2.fromOffset(220, 54), TextSize = 20, LayoutOrder = 1, Shine = can }, function()
				closePopup(); levelUpItem(it, h)
			end)
		end
		if inHand then
			K.status(holder, "IN YOUR HAND", K.GREEN, { Size = UDim2.fromOffset(180, 48), LayoutOrder = 2 })
		else
			K.button(holder, "EQUIP", EQUIP_BLUE, { Size = UDim2.fromOffset(160, 54), TextSize = 22, LayoutOrder = 2, Shine = true }, function() closePopup(); equipItem(it, h) end)
		end
	end
end

-- what's inside a crate: every rarity it can drop, the odds and the hammers at that rarity
local function cratePopup(cr, data)
	local zone = data and data.zone or "town"
	local luck = data and data.luck or 1
	local body = openPopup(UDim2.fromOffset(700, 520), cr.name, cr.color:Lerp(Color3.new(1, 1, 1), 0.25), cr.color, nil)
	K.text({ Position = UDim2.fromOffset(0, 4), Size = UDim2.new(1, 0, 0, 44), Text = cr.desc, TextSize = 16, TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top, TextColor3 = Color3.new(1, 1, 1), Stroke = 2, ZIndex = 6, Parent = body })
	local list = new("ScrollingFrame", { Position = UDim2.fromOffset(0, 52), Size = UDim2.new(1, 0, 1, -82), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 6,
		ScrollBarImageColor3 = Color3.fromRGB(200, 200, 240), CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollingDirection = Enum.ScrollingDirection.Y, ZIndex = 6, Parent = body })
	new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder, Parent = list })
	local odds = Hammers.Odds(cr.id, zone, luck)
	local n = 0
	for r = #Hammers.Rarities, 1, -1 do
		local v = odds[r]
		if v and v > 0 then
			n += 1
			local rr = Hammers.Rarities[r]
			local row = new("Frame", { Size = UDim2.new(1, -8, 0, 92), BackgroundTransparency = 1, LayoutOrder = n, ZIndex = 6, Parent = list })
			UI.slice("tile", { ImageColor3 = K.TILE, ZIndex = 1, Parent = row })
			K.rarityChip(K.chip(row, string.upper(rr.name), rr.color, { Position = UDim2.fromOffset(12, 18), ZIndex = 8 }), rr.id)
			K.text({ Position = UDim2.fromOffset(12, 50), Size = UDim2.fromOffset(130, 26), Text = pct(v), Font = T.chunky, TextSize = 24, TextColor3 = rarText(rr), ZIndex = 8, Parent = row })
			local pics = new("Frame", { Position = UDim2.fromOffset(150, 6), Size = UDim2.new(1, -160, 0, 82), BackgroundTransparency = 1, ZIndex = 7, Parent = row })
			new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder, Parent = pics })
			for i, h in ipairs(Hammers.PoolAt(cr, r)) do
				local b = new("TextButton", { Text = "", AutoButtonColor = false, Size = UDim2.fromOffset(96, 82), BackgroundTransparency = 1, LayoutOrder = i, ZIndex = 7, Parent = pics })
				K.rarityFX(K.artBox(b, art(h), rr.color, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 0), Size = UDim2.fromOffset(58, 58), IconScale = 1.06 }), rr.id, { small = true })
				K.rarityText(K.text({ Position = UDim2.fromOffset(0, 60), Size = UDim2.new(1, 0, 0, 20), Text = h.name, TextSize = 12, Max = 12, TextXAlignment = Enum.TextXAlignment.Center, TextColor3 = K.DARK, ZIndex = 8, Parent = b }), rr.id, rarText(rr))
				b.Activated:Connect(function() c.click(); hammerPopup(h) end)
			end
		end
	end
	if n == 0 then K.text({ Position = UDim2.fromOffset(0, 60), Size = UDim2.new(1, 0, 0, 30), Text = "Its hammers are still being made: coming soon!", TextSize = 18, TextColor3 = K.NOTE, ZIndex = 6, Parent = body }) end
	local foot = {}
	if cr.pools then table.insert(foot, "Better odds once you take Suburbs, then Downtown contracts (now: " .. zone:sub(1, 1):upper() .. zone:sub(2) .. ")") end
	if cr.pity then table.insert(foot, "Pity: " .. Hammers.Rarities[cr.pity.min].name .. " or better guaranteed every " .. cr.pity.every .. " opens") end
	if luck > 1 then table.insert(foot, "🍀 Lucky Builder: Rare+ twice as often (already counted)") end
	K.text({ AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 0, 1, 0), Size = UDim2.new(1, 0, 0, 26), Text = table.concat(foot, "  ·  "), TextSize = 14, Max = 14, TextColor3 = K.NOTE, ZIndex = 6, Parent = body })
end

---------------------------------------------------------------------------------------------------------------------
-- Crate opening: the case-opening strip, then HammerFX's reveal card
---------------------------------------------------------------------------------------------------------------------
local opening -- the ScreenGui while a crate opens
local function stopOpening()
	if opening then opening:Destroy(); opening = nil end
end

-- the reveal card lives in HammerFX (its own ScreenGui, above everything); a toast if it isn't there
local function revealHammer(h, o)
	local r = rar(h)
	local show = _G.__CE_RevealHammer
	if not show then
		c.toast("🔨 " .. h.name .. " (" .. r.name .. ")", r.color, 4)
		if o.onClose then o.onClose() end
		return
	end
	show({ head = o.head or "NEW HAMMER!", name = h.name, icon = art(h), color = r.color, rarity = { string.upper(r.name) .. (o.isNew and "  ·  NEW!" or ""), r.color },
		big = h.r >= 5, tier = h.r, rid = r.id, effect = Hammers.PowerLabel(h.key, 1) .. " build power  ·  " .. h.desc, button = o.button or "KEEP",
		again = o.again, onClose = o.onClose, tag = o.pity and "PITY: GUARANTEED" or nil })
end

-- a random hammer the crate could drop (for the strip), weighted like the real odds
local function rollFake(cr, zone, luck)
	local odds = Hammers.Odds(cr.id, zone, luck)
	local total = 0
	for _, v in pairs(odds) do total += v end
	local x = rng:NextNumber() * total
	for r = 1, #Hammers.Rarities do
		local v = odds[r]
		if v then
			x -= v
			if x <= 0 then
				local pool = Hammers.PoolAt(cr, r)
				return pool[rng:NextInteger(1, #pool)]
			end
		end
	end
	return Hammers.ById.iron
end

local openCrate
local autoOpen, cratePassPopup
-- the card after a crate: KEEP, or OPEN ANOTHER while you have more of that crate
local function revealOpened(cr, h, res)
	local left = c.player:GetAttribute("Crate_" .. cr.id) or 0
	-- in the tutorial the new hammer is already in your hand (the server equips it)
	local tut = inTut() and c.player:GetAttribute("EquipId") == res.id
	revealHammer(h, { isNew = res.new, pity = res.pity, button = tut and "BUILD WITH IT!" or "KEEP",
		again = left > 0 and { label = "OPEN ANOTHER (" .. left .. ")", fn = function() openCrate(cr.id) end } or nil,
		onClose = function()
			M.Redraw()
			if tut then c.toast("🔨 " .. h.name .. " is in your hand now!", rar(h).color, 3.5) end
		end })
end

-- the crate passes (Config.Store.passes): Quick Open (the hammer at once) and Auto Opener (opens them all by itself)
local function passOf(key)
	for _, p in ipairs(Config.Store.passes) do if p.key == key then return p end end
end
local function buyPass(p)
	c.click()
	if (p.id or 0) > 0 then MarketplaceService:PromptGamePassPurchase(c.player, p.id)
	else c.toast(p.name .. ": coming soon (" .. K.robux(p.price) .. ")", T.accent, 2.5) end
end

local function spinThenReveal(cr, res)
	stopOpening()
	local h = Hammers.ById[res.key]
	if not h then M.Redraw() return end
	local data = cache or {}
	local gui = new("ScreenGui", { Name = "CrateShake", IgnoreGuiInset = true, DisplayOrder = 110, ResetOnSpawn = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, Parent = c.player:WaitForChild("PlayerGui") })
	opening = gui
	local scale = c.uiScale and c.uiScale.Scale or 1
	new("UIScale", { Scale = scale, Parent = gui })
	local back = new("TextButton", { Text = "", AutoButtonColor = false, Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(8, 8, 22), BackgroundTransparency = 1, ZIndex = 1, Parent = gui })
	UI.tween(back, 0.2, { BackgroundTransparency = 0.35 })
	-- the crate on top, the strip in the middle
	local vp = c.camera.ViewportSize / scale
	local W = math.floor(math.min(960, vp.X * 0.92))
	local TILE, GAP = 124, 8
	local STRIDE = TILE + GAP
	local holder = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(W, 150), BackgroundTransparency = 1, ZIndex = 2, Parent = gui })
	UI.slice("inset", { ImageColor3 = Color3.fromRGB(28, 26, 60), ZIndex = 2, Parent = holder })
	local clip = new("Frame", { Position = UDim2.fromOffset(6, 6), Size = UDim2.new(1, -12, 1, -12), BackgroundTransparency = 1, ClipsDescendants = true, ZIndex = 3, Parent = holder })
	local crateBox = new("Frame", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 0.5, -95), Size = UDim2.fromOffset(150, 150), BackgroundTransparency = 1, ZIndex = 4, Parent = gui })
	local pic = crateArt(cr)
	local crateImg
	if type(pic) == "string" and pic:find("^rbxassetid://") then
		crateImg = new("ImageLabel", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Image = pic, ScaleType = Enum.ScaleType.Fit, ZIndex = 4, Parent = crateBox })
	else
		crateImg = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 4, Parent = crateBox })
		Icons.make(pic, { Size = UDim2.fromScale(1, 1), ZIndex = 4, Parent = crateImg })
	end
	local title = UI.label({ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0.5, 86), Size = UDim2.fromOffset(600, 34), Text = string.upper(cr.name) .. "  ·  OPENING", Font = T.chunky, TextSize = 26,
		TextXAlignment = Enum.TextXAlignment.Center, TextColor3 = Color3.new(1, 1, 1), ZIndex = 5, Parent = gui })
	UI.textStroke(0.1, 3).Parent = title
	local hint = UI.label({ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0.5, 122), Size = UDim2.fromOffset(600, 22), Text = "tap to skip", Font = T.body, TextSize = 16,
		TextXAlignment = Enum.TextXAlignment.Center, TextColor3 = Color3.fromRGB(200, 204, 240), ZIndex = 5, Parent = gui })
	-- the strip: 40 hammers, yours at slot 34
	local N, WIN = 40, 34
	local strip = new("Frame", { Size = UDim2.fromOffset(N * STRIDE, TILE), Position = UDim2.fromOffset(0, 7), BackgroundTransparency = 1, ZIndex = 3, Parent = clip })
	local tiles = {}
	for i = 1, N do
		local hh = i == WIN and h or rollFake(cr, data.zone or "town", data.luck or 1)
		local rr = rar(hh)
		local tl = new("Frame", { Position = UDim2.fromOffset((i - 1) * STRIDE, 0), Size = UDim2.fromOffset(TILE, TILE), BackgroundTransparency = 1, ZIndex = 3, Parent = strip })
		K.rarityFX(K.artBox(tl, art(hh), rr.color, { Size = UDim2.fromScale(1, 1), IconScale = 1.02 }), rr.id)
		local band = new("Frame", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -6), Size = UDim2.new(1, -16, 0, 8), BackgroundColor3 = rr.color, BorderSizePixel = 0, ZIndex = 8, Parent = tl })
		UI.corner(4).Parent = band
		tiles[i] = tl
	end
	-- the marker in the middle
	local innerW = W - 12
	local mark = new("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 0), Size = UDim2.fromOffset(5, 150), BackgroundColor3 = GOLD, BorderSizePixel = 0, ZIndex = 9, Parent = holder })
	new("UIStroke", { Thickness = 1.5, Color = T.ink, Parent = mark })
	for _, side in ipairs({ 0, 1 }) do
		local d = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, side, 0), Size = UDim2.fromOffset(18, 18), Rotation = 45, BackgroundColor3 = GOLD, BorderSizePixel = 0, ZIndex = 10, Parent = holder })
		UI.corner(4).Parent = d
		new("UIStroke", { Thickness = 2, Color = T.ink, Parent = d })
	end
	-- from the start to your hammer under the marker (a little off centre, like a real spin)
	local centre = innerW / 2
	local x0 = centre - (TILE / 2) - STRIDE * 1
	local jitter = rng:NextInteger(-TILE * 0.38, TILE * 0.38)
	local xEnd = centre - ((WIN - 1) * STRIDE + TILE / 2) + jitter
	strip.Position = UDim2.fromOffset(x0, 7)
	local DUR = 3.6
	local tw = TweenService:Create(strip, TweenInfo.new(DUR, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), { Position = UDim2.fromOffset(xEnd, 7) })
	local finished = false
	local lastIdx = 0
	local conn
	local function finish()
		if finished then return end
		finished = true
		if conn then conn:Disconnect() end
		tw:Cancel()
		strip.Position = UDim2.fromOffset(xEnd, 7)
		-- the winner lights up
		local win = tiles[WIN]
		local ws = new("UIScale", { Parent = win })
		UI.tween(ws, 0.25, { Scale = 1.12 }, Enum.EasingStyle.Back)
		local glow = UI.slice("glow", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(10, 10), ImageColor3 = rar(h).color, ImageTransparency = 0.2, ZIndex = 2, Parent = win })
		UI.tween(glow, 0.4, { Size = UDim2.fromOffset(300, 300), ImageTransparency = 0.6 })
		c.sound2D(c.S.Chime, 0.6, h.r >= 5 and 0.85 or 1.15)
		title.Text = string.upper(h.name) .. "!"
		hint.Visible = false
		task.delay(0.75, function()
			if opening ~= gui then return end
			stopOpening()
			revealOpened(cr, h, res)
		end)
	end
	-- the crate shakes while the strip spins; the ticks follow the hammers passing the marker
	local t0 = os.clock()
	conn = RunService.RenderStepped:Connect(function()
		if opening ~= gui then conn:Disconnect() return end
		local t = os.clock() - t0
		crateImg.Rotation = math.sin(t * 28) * 6 * math.clamp(1 - t / DUR, 0, 1)
		local x = strip.Position.X.Offset
		local idx = math.floor((centre - x) / STRIDE) + 1
		if idx ~= lastIdx and idx >= 1 and idx <= N then
			lastIdx = idx
			c.sound2D(c.S.Click, 0.22, 1.35 + math.min(0.5, (idx / N) * 0.5))
			mark.Size = UDim2.fromOffset(9, 150)
			UI.tween(mark, 0.12, { Size = UDim2.fromOffset(5, 150) })
		end
	end)
	tw.Completed:Connect(function(state) if state == Enum.PlaybackState.Completed then finish() end end)
	tw:Play()
	-- the strip plays to the end (no tap to skip): the hammer at once is the Quick Open pass, offered right here
	hint.Text = ""
	local qp = passOf("quickopen")
	if qp and not c.player:GetAttribute("Pass_quickopen") and ((qp.id or 0) > 0 or studio) and not inTut() then
		local offer = UI.button("QUICK OPEN  " .. K.robux(qp.price), Color3.fromRGB(255, 200, 60), Color3.fromRGB(240, 130, 20),
			{ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0.5, 116), Size = UDim2.fromOffset(300, 54), TextSize = 22, Font = T.chunky, Shine = true, ZIndex = 6, Parent = gui })
		local note = UI.label({ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0.5, 174), Size = UDim2.fromOffset(600, 22),
			Text = "Game pass: press OPEN and get your hammer at once, every crate, forever", Font = T.body, TextSize = 16, TextXAlignment = Enum.TextXAlignment.Center,
			TextColor3 = Color3.fromRGB(230, 232, 255), ZIndex = 6, Parent = gui })
		UI.textStroke(0.2, 2).Parent = note
		offer.Activated:Connect(function() buyPass(qp) end)
	end
	c.sound2D(c.S.Click, 0.5, 0.8)
end

function openCrate(crateId)
	if busy then return end
	busy = true
	local ok, res = call("open", crateId)
	busy = false
	if not ok then c.toast("⚠️ " .. tostring(res), T.red) return end
	local cr = Hammers.CrateById[crateId]
	local h = Hammers.ById[res.key]
	if c.player:GetAttribute("QuickOpen") == true and h then
		c.sound2D(c.S.Chime, 0.6, h.r >= 5 and 0.85 or 1.15)
		revealOpened(cr, h, res)
	else
		spinThenReveal(cr, res)
	end
end

local function buyCrate(crateId, n, thenOpen)
	if busy then return end
	busy = true
	local t0 = os.clock()
	local ok, res = call("buy", crateId, n)
	-- BUY & OPEN: the server takes one hammer action every 0.15 s, so the open waits that long after the buy
	-- (on a fast connection it came back "Slow down!" and the crate stayed shut)
	if ok and thenOpen then
		local w = 0.2 - (os.clock() - t0)
		if w > 0 then task.wait(w) end
	end
	busy = false
	if not ok then c.toast("⚠️ " .. tostring(res), T.red) return end
	c.sound2D(c.S.Coins, 0.4, 1)
	if thenOpen then openCrate(crateId) else M.Redraw() end
end

-- the crate passes, side by side: what each does and its price
function cratePassPopup()
	local body = openPopup(UDim2.fromOffset(640, 380), "Crate passes", Color3.fromRGB(255, 214, 90), Color3.fromRGB(226, 130, 30), nil)
	local defs = {
		{ passOf("quickopen"), "Press OPEN and your hammer is there at once: no spinning strip, on every crate. Forever." },
		{ passOf("autoopen"), "An AUTO button on your crates: it opens all of them by itself, one after another, fast. Forever." },
	}
	for i, d in ipairs(defs) do
		local p = d[1]
		if p then
			local f = new("Frame", { Position = UDim2.new((i - 1) * 0.5, i == 1 and 0 or 6, 0, 0), Size = UDim2.new(0.5, -6, 1, 0), BackgroundTransparency = 1, ZIndex = 5, Parent = body })
			UI.slice("tile", { ImageColor3 = K.TILE, ZIndex = 5, Parent = f })
			local img = Config.ProductImages and Config.ProductImages[p.key]
			K.artBox(f, img or "gift", Color3.fromRGB(255, 186, 60), { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 10), Size = UDim2.fromOffset(120, 120), Spin = true, IconScale = 1.04 }).ZIndex = 6
			K.text({ Position = UDim2.fromOffset(10, 136), Size = UDim2.new(1, -20, 0, 30), Text = p.name, Font = T.chunky, TextSize = 24, Max = 24, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 7, Parent = f })
			K.text({ Position = UDim2.fromOffset(12, 168), Size = UDim2.new(1, -24, 0, 66), Text = d[2], TextSize = 15, Max = 15, TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top,
				TextXAlignment = Enum.TextXAlignment.Center, TextColor3 = K.SUB, ZIndex = 7, Parent = f })
			if c.player:GetAttribute("Pass_" .. p.key) == true then
				K.status(f, "OWNED", K.GREEN, { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -12), Size = UDim2.fromOffset(170, 46), ZIndex = 7 })
			else
				K.button(f, (p.id or 0) > 0 and K.robux(p.price) or ("SOON · " .. K.robux(p.price)), (p.id or 0) > 0 and K.GREEN or K.LOCK,
					{ AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -12), Size = UDim2.fromOffset(190, 52), TextSize = 22, Shine = (p.id or 0) > 0, ZIndex = 7 }, function()
					closePopup(); buyPass(p)
				end)
			end
		end
	end
end

-- the Auto Opener: every crate of a kind, one after another, the hammers dropping into a grid; STOP any time
local autoGui
function autoOpen(crateId)
	local cr = Hammers.CrateById[crateId]
	if not cr or autoGui or busy then return end
	local total = c.player:GetAttribute("Crate_" .. crateId) or 0
	if total <= 0 then c.toast("No " .. cr.name .. " to open", T.muted, 2) return end
	closePopup()
	local gui = new("ScreenGui", { Name = "AutoOpen", IgnoreGuiInset = true, DisplayOrder = 110, ResetOnSpawn = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = c.player:WaitForChild("PlayerGui") })
	autoGui = gui
	local dim = new("TextButton", { Text = "", AutoButtonColor = false, Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(8, 8, 22), BackgroundTransparency = 0.35, Parent = gui })
	local w = K.window(dim, UDim2.fromOffset(760, 500), "Auto Opener", cr.color:Lerp(Color3.new(1, 1, 1), 0.25), cr.color, nil, true)
	local fit = math.clamp(math.min(c.camera.ViewportSize.X / 840, (c.camera.ViewportSize.Y - 40) / 580), 0.5, 1.1)
	local sc = new("UIScale", { Scale = fit * 0.85, Parent = w })
	UI.tween(sc, 0.25, { Scale = fit }, Enum.EasingStyle.Back)
	local body = new("Frame", { Position = UDim2.fromOffset(20, 58), Size = UDim2.new(1, -40, 1, -76), BackgroundTransparency = 1, ZIndex = 5, Parent = w })
	-- the crate, the count, the bar, the best hammer so far
	local crateBox = new("Frame", { Size = UDim2.fromOffset(96, 96), BackgroundTransparency = 1, ZIndex = 6, Parent = body })
	local crateImg = K.art(crateBox, crateArt(cr), UDim2.fromScale(1, 1), 6)
	local head = K.text({ Position = UDim2.fromOffset(110, 0), Size = UDim2.new(1, -330, 0, 34), Text = string.upper(cr.name), Font = T.chunky, TextSize = 28, Max = 28,
		TextColor3 = Color3.new(1, 1, 1), Stroke = 3, ZIndex = 6, Parent = body })
	local bar, fill = UI.bar({ Position = UDim2.fromOffset(110, 42), Size = UDim2.new(1, -330, 0, 26), ZIndex = 6 }, K.GREEN)
	bar.Parent = body
	fill.Size = UDim2.fromScale(0.03, 1)
	local count = K.text({ Position = UDim2.fromOffset(0, 1), Size = UDim2.fromScale(1, 1), Text = "0 / " .. total, Font = T.chunky, TextSize = 16, TextColor3 = Color3.new(1, 1, 1), Stroke = 2,
		TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 8, Parent = bar })
	local bestT = K.text({ Position = UDim2.fromOffset(110, 74), Size = UDim2.new(1, -330, 0, 22), Text = "Best so far: —", TextSize = 17, Max = 17, TextColor3 = K.NOTE, ZIndex = 6, Parent = body })
	local bestBox = new("Frame", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -110, 0, 0), Size = UDim2.fromOffset(96, 96), BackgroundTransparency = 1, ZIndex = 6, Parent = body })
	-- the hammers that came out, newest last
	local list = new("ScrollingFrame", { Position = UDim2.fromOffset(0, 108), Size = UDim2.new(1, 0, 1, -170), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 6,
		ScrollBarImageColor3 = Color3.fromRGB(200, 200, 240), CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollingDirection = Enum.ScrollingDirection.Y, ZIndex = 6, Parent = body })
	new("UIGridLayout", { CellSize = UDim2.fromOffset(78, 78), CellPadding = UDim2.fromOffset(8, 8), SortOrder = Enum.SortOrder.LayoutOrder, Parent = list })
	local stopping, done = false, false
	local stopBtn
	local function close()
		if autoGui == gui then autoGui = nil end
		gui:Destroy()
		M.Redraw()
	end
	stopBtn = K.button(body, "STOP", T.red, { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, 0), Size = UDim2.fromOffset(220, 54), TextSize = 24, ZIndex = 7 }, function()
		c.click()
		if done then close() else stopping = true end
	end)
	task.spawn(function()
		local got, best, fails = 0, nil, 0
		local t0 = os.clock()
		while not stopping and gui.Parent do
			if (c.player:GetAttribute("Crate_" .. crateId) or 0) <= 0 then break end
			local ok, res = call("open", crateId)
			if not gui.Parent then break end
			if ok and type(res) == "table" and Hammers.ById[res.key] then
				fails = 0
				got += 1
				local h = Hammers.ById[res.key]
				local r = rar(h)
				local cell = new("Frame", { BackgroundTransparency = 1, LayoutOrder = got, ZIndex = 6, Parent = list })
				local box = K.artBox(cell, art(h), r.color, { Size = UDim2.fromScale(1, 1), IconScale = 1.04 })
				K.rarityFX(box, r.id, { small = true })
				if res.new then new("UIScale", { Scale = 0.6, Parent = K.chip(cell, "NEW", Color3.fromRGB(255, 52, 84), { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, -4), ZIndex = 9 }) }) end
				local cs = new("UIScale", { Scale = 0.4, Parent = cell })
				UI.tween(cs, 0.2, { Scale = 1 }, Enum.EasingStyle.Back)
				list.CanvasPosition = Vector2.new(0, math.max(0, list.AbsoluteCanvasSize.Y))
				c.sound2D(c.S.Click, 0.3, 1.2 + math.min(0.4, got / 80))
				if not best or h.r > best.r or (h.r == best.r and (h.dr or h.r) > (best.dr or best.r)) then
					best = h
					bestT.Text = "Best so far: " .. h.name .. " (" .. r.name .. ")"
					for _, ch in ipairs(bestBox:GetChildren()) do ch:Destroy() end
					K.rarityFX(K.artBox(bestBox, art(h), r.color, { Size = UDim2.fromScale(1, 1), Spin = true, IconScale = 1.04 }), r.id)
				end
				if h.r >= 5 then c.sound2D(c.S.Chime, 0.6, 0.9) end
				count.Text = got .. " / " .. total
				fill.Size = UDim2.fromScale(math.clamp(got / total, 0.03, 1), 1)
				crateImg.Rotation = (got % 2 == 0) and 6 or -6
			else
				fails += 1
				if fails >= 4 then c.toast("⚠️ " .. tostring(res), T.red, 3); break end
			end
			task.wait(0.2) -- (the server takes one action every 0.15 s)
		end
		if not gui.Parent then return end
		done = true
		crateImg.Rotation = 0
		head.Text = got .. " HAMMERS OPENED!"
		local lb = stopBtn:FindFirstChild("Label")
		if lb then lb.Text = "DONE" end
		local bg = stopBtn:FindFirstChild("Bg")
		if bg then bg.ImageColor3 = K.GREEN end
		c.sound2D(c.S.Chime, 0.6, 1)
	end)
end

function levelUpItem(it, h)
	local cost = Hammers.LevelCost(it.k, it.lv)
	if not cost then return end
	if money() < cost then c.click(); c.toast("💸 Not enough cash yet", T.red, 2) return end
	c.click()
	local ok, res = call("levelup", it.id)
	if ok then M.Redraw() else c.toast("⚠️ " .. tostring(res), T.red) end
end

function equipItem(it, h)
	c.click()
	local ok, res = call("equip", it.id)
	if ok then c.toast("🔨 " .. h.name .. " is in your hand", T.green, 2); M.Redraw() else c.toast("⚠️ " .. tostring(res), T.red) end
end

---------------------------------------------------------------------------------------------------------------------
-- Shared pieces
---------------------------------------------------------------------------------------------------------------------
-- the Thunderclap pass: an Exclusive storm hammer + x3 power, offered in the Shop too (until you own it)
local function stormBanner(order)
	local sh = Config.StormHammer
	if not sh then return end
	local pass
	for _, p in ipairs(Config.Store.passes) do if p.key == sh.pass then pass = p end end
	if not pass or c.player:GetAttribute("Pass_" .. sh.pass) == true then return end
	if (pass.id or 0) <= 0 and not studio then return end
	local o = { name = string.upper(sh.name), line = "An Exclusive storm hammer, yours forever, plus x" .. sh.mult .. " build power for you and your crew.",
		icon = sh.icon or "up_power", color = sh.color, tint = Color3.fromRGB(150, 200, 255), buttonW = 180,
		chips = { { "EXCLUSIVE", Hammers.RarityById.exclusive.color }, { "x" .. sh.mult .. " POWER", GOLD }, { "FOREVER", K.GREEN } } }
	if (pass.id or 0) > 0 then
		o.button = { K.robux(pass.price), K.GREEN, function() c.click(); MarketplaceService:PromptGamePassPurchase(c.player, pass.id) end }
	else
		o.status = { "SOON · " .. K.robux(pass.price), K.LOCK }
	end
	K.banner(c.content, order, o)
end

-- the odds of a crate on one line (Roblox: paid random items show them): 40% · 6% · 0.9% · 0.1%
local function shortPct(v)
	local t = v >= 10 and string.format("%d", math.floor(v + 0.5)) or (v >= 1 and string.format("%.1f", v) or string.format("%.2f", v))
	t = t:find("%.") and t:gsub("0+$", ""):gsub("%.$", "") or t
	return t .. "%"
end
local function oddsLine(cr, zone, luck)
	local odds = Hammers.Odds(cr.id, zone, luck)
	local parts = {}
	for r = 1, Hammers.LadderTop do
		if odds[r] and odds[r] > 0 then
			local rr = Hammers.Rarities[r]
			table.insert(parts, string.format('<font color="#%s">%s %s</font>', rarText(rr):ToHex(), rr.name, shortPct(odds[r])))
		end
	end
	return #parts > 0 and table.concat(parts, " · ") or "Nothing to drop yet"
end

-- the crates as tiles: shop = every crate with its price; mine = only the ones you have, one OPEN each
local function crateTiles(data, order, shop)
	local zone = data.zone or "town"
	local tut = shop and inTut()
	local grid = K.grid(c.content, order, cols(), 304)
	for i, cr in ipairs(Hammers.Crates) do
		local have = data.crates[cr.id] or 0
		if not shop and have == 0 then continue end
		local prod = cr.product and product(cr.product)
		local robuxOk = prod and (prod.id or 0) > 0 and not c.paidRandomRestricted
		local exists = next(Hammers.Odds(cr.id, zone, 1)) ~= nil
		local o = { order = i, name = cr.name, icon = crateArt(cr), iconScale = cr.image and 1.06 or 0.9, color = cr.color, stats = {}, spin = have > 0,
			corner = { label = "?", color = EQUIP_BLUE, w = 26, plain = true, onClick = function() c.click(); cratePopup(cr, data) end } }
		if have > 0 then o.badge = { "x" .. have, T.red } end
		if cr.pity then table.insert(o.stats, { "PITY " .. tostring(data.pity[cr.id] or cr.pity.every), GOLD }) end
		if cr.cash then table.insert(o.stats, { string.upper(zone), K.SUB }) end
		if cr.exclusiveOnly then table.insert(o.stats, { "EXCLUSIVES", T.red }) end
		if (data.luck or 1) > 1 and not cr.exclusiveOnly then table.insert(o.stats, { "🍀 2x", K.GREEN }) end
		local buttons = {}
		if have > 0 then table.insert(buttons, { "OPEN", K.GREEN, function() c.click(); openCrate(cr.id) end, shine = true }) end
		if not shop then
			-- the inventory opens them: one at a time, or all of them by themselves (the Auto Opener pass)
			if have >= 2 then
				local owns = c.player:GetAttribute("Pass_autoopen") == true
				table.insert(buttons, { "AUTO", owns and Color3.fromRGB(255, 176, 40) or K.LOCK, function()
					c.click()
					if owns then autoOpen(cr.id) else cratePassPopup() end
				end, shine = owns })
			end
		elseif tut then
			-- the tutorial: one Supply Crate, bought and opened at once; the rest waits
			if cr.cash and have == 0 and (c.player:GetAttribute("RoadStep") or 1) == 1 then
				local price = data.supplyPrice or Hammers.SupplyPrice(60)
				local can = money() >= price
				table.insert(buttons, { fmt(price), can and GOLD or K.LOCK, function()
					if not can then c.click(); c.toast("💸 Not enough cash yet", T.red, 2) return end
					c.click(); buyCrate(cr.id, 1, true)
				end, icon = "cash", shine = can })
			elseif have == 0 then
				o.dim = true
				o.status = { "AFTER TUTORIAL", K.LOCK }
			end
		elseif cr.cash then
			local price = data.supplyPrice or Hammers.SupplyPrice(60)
			local can = money() >= price
			table.insert(buttons, { fmt(price), can and GOLD or K.LOCK, function()
				if not can then c.click(); c.toast("💸 Not enough cash yet", T.red, 2) return end
				c.click(); buyCrate(cr.id, 1, have == 0)
			end, icon = have == 0 and "cash" or nil, shine = can and have == 0 })
		elseif cr.gems then
			local can = gems() >= cr.gems
			table.insert(buttons, { "💎 " .. cr.gems, can and GEM or K.LOCK, function()
				if not can then c.click(); M.GemStore("Not enough Gems") return end
				c.click(); buyCrate(cr.id, 1, have == 0)
			end, shine = can and have == 0 })
		end
		-- Robux next to the Gem price (at most two buttons: with crates in the bag, OPEN + the price)
		if shop and prod and not tut and (have == 0 or not cr.gems) then
			if robuxOk then
				table.insert(buttons, { K.robux(prod.price), K.GREEN, function() c.click(); MarketplaceService:PromptProductPurchase(c.player, prod.id) end, shine = have == 0 })
			elseif #buttons == 0 then
				o.status = { studio and ("SOON · " .. K.robux(prod.price)) or "COMING SOON", K.LOCK }
			end
		end
		if not exists and have == 0 then
			buttons = {}
			o.status = { "COMING SOON", K.LOCK }
		end
		if #buttons > 0 then o.buttons = buttons end
		local t = K.tile(grid, o)
		-- (shrinks to fit two lines: it never runs into the buttons)
		K.text({ Position = UDim2.fromOffset(12, 198), Size = UDim2.new(1, -24, 0, 34), Text = oddsLine(cr, zone, data.luck or 1), TextSize = 14, Max = 14,
			TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top, TextColor3 = K.SUB, ZIndex = 3, Parent = t })
	end
	return grid
end

---------------------------------------------------------------------------------------------------------------------
-- Shop → HAMMERS: the Hammers of the Day (the one you want, no luck: lots of Gems or Robux), the crates, the Thunderclap
---------------------------------------------------------------------------------------------------------------------
-- not enough Gems: straight to the Gem packs (one tap from wanting to having)
function M.GemStore(why)
	c.toast("💎 " .. why .. ": Gem packs are in the Store", GEM, 2.5)
	if _G.__CE_ShowStore then task.delay(0.15, function() _G.__CE_ShowStore("gems") end) end
end

local function fmtLeft(s)
	s = math.max(0, math.floor(s))
	return string.format("%02d:%02d:%02d", s // 3600, (s % 3600) // 60, s % 60)
end

-- the reveal after a Hammer of the Day is bought
local function revealBought(key, new)
	local h = Hammers.ById[key]
	if not h then return end
	c.sound2D(c.S.Chime, 0.6, (h.dr or h.r) >= 5 and 0.85 or 1.1)
	revealHammer(h, { head = "IT'S YOURS!", isNew = new, button = "AWESOME!", onClose = function() if M.Showing() then M.Redraw() end end })
end

local armedGems = {} -- [hammer key] = until when the Gem button waits for its second tap
-- a rounded outline that follows a tile's corners (a stroke on the 9-slice background drew a square box around it)
local function glowFrame(t)
	local f = new("Frame", { Name = "Glow", Position = UDim2.fromOffset(1, 1), Size = UDim2.new(1, -2, 1, -2), BackgroundTransparency = 1, ZIndex = 1, Parent = t })
	new("UICorner", { CornerRadius = UDim.new(0, 20), Parent = f })
	return f
end
local function dailyHammers(order, data)
	local offers = Hammers.Featured(Hammers.ShopDay())
	if #offers == 0 then return end
	-- the header: a wide gradient card, the title, one line, the time to the next set
	local head = new("Frame", { Name = "DailyHead", Size = UDim2.new(1, 0, 0, 78), BackgroundTransparency = 1, LayoutOrder = order, ZIndex = 2, Parent = c.content })
	local bg = UI.slice("tile", { Name = "Bg", ImageColor3 = Color3.new(1, 1, 1), ZIndex = 1, Parent = head })
	new("UIGradient", { Rotation = 0, Parent = bg, Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, Color3.fromRGB(108, 62, 236)),
		ColorSequenceKeypoint.new(0.55, Color3.fromRGB(214, 62, 176)), ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 148, 52)) }) })
	local icon = new("Frame", { Position = UDim2.fromOffset(10, 6), Size = UDim2.fromOffset(66, 66), BackgroundTransparency = 1, ZIndex = 3, Parent = head })
	K.art(icon, art(Hammers.ById[(offers[3] or offers[1]).key]), UDim2.fromScale(1, 1), 4)
	local title = K.text({ Position = UDim2.fromOffset(84, 9), Size = UDim2.new(1, -330, 0, 34), Text = "HAMMERS OF THE DAY", Font = T.chunky, TextSize = 30, Max = 30,
		TextColor3 = Color3.new(1, 1, 1), Stroke = 3, ZIndex = 4, Parent = head })
	new("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(255, 232, 140)), Parent = title })
	K.text({ Position = UDim2.fromOffset(85, 44), Size = UDim2.new(1, -330, 0, 22), Text = "No luck needed: pick the hammer you want. New ones every day.", TextSize = 17, Max = 17,
		TextColor3 = Color3.fromRGB(255, 240, 255), Stroke = 1.6, ZIndex = 4, Parent = head })
	local pill = UI.slice("pill", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -14, 0.5, 0), Size = UDim2.fromOffset(222, 46), SliceScale = 0.42,
		ImageColor3 = Color3.fromRGB(32, 24, 62), ZIndex = 3, Parent = head })
	local timer = K.text({ Size = UDim2.fromScale(1, 1), Text = "", Font = T.chunky, TextSize = 21, TextColor3 = Color3.fromRGB(255, 226, 120), Stroke = 2,
		TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 4, Parent = pill })
	local nextAt = (Hammers.ShopDay() + 1) * 86400
	task.spawn(function()
		while timer.Parent do
			local left = nextAt - os.time()
			timer.Text = "NEW IN " .. fmtLeft(left)
			if left <= 0 then
				task.wait(1.5)
				if timer.Parent and M.Showing() then M.Redraw() end
				return
			end
			task.wait(1)
		end
	end)
	-- one row of four cards: the three Hammers of the Day (Epic, Legendary, Mythic) and, last on the right, the
	-- Thunderclap: a hammer only Robux buys (never in a crate)
	local list = {}
	for _, o in pairs(offers) do table.insert(list, o) end
	table.sort(list, function(x, y) return x.r < y.r end)
	local CELL, GAP, ART, BH = 350, 12, 156, 44
	local grid = new("Frame", { Name = "DailyHammers", Size = UDim2.new(1, 0, 0, CELL), BackgroundTransparency = 1, LayoutOrder = order + 1, ZIndex = 2, Parent = c.content })
	new("UIGridLayout", { CellSize = UDim2.new(0.25, -math.ceil(GAP * 3 / 4), 0, CELL), CellPadding = UDim2.fromOffset(GAP, GAP), SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = grid })
	-- the buttons one above the other (a card is narrow: Gems and Robux side by side didn't fit)
	local function stack(t, defs)
		local holder = new("Frame", { Name = "Buttons", AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 10, 1, -10), Size = UDim2.new(1, -20, 0, #defs * BH + (#defs - 1) * 6),
			BackgroundTransparency = 1, ZIndex = 7, Parent = t })
		new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = holder })
		for i, bd in ipairs(defs) do
			K.button(holder, bd[1], bd[2], { Size = UDim2.new(1, 0, 0, BH), TextSize = 21, Shine = bd.shine, LayoutOrder = i }, bd[3])
		end
	end
	-- the card's tag (GREAT DEAL, POPULAR...) sits at the bottom of the picture, in the middle (clear of the name)
	local function tagChip(t, label, color)
		K.chip(t, label, color, { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 0, 8 + ART - 5), ZIndex = 8 })
	end
	for i, o in ipairs(list) do
		local h = Hammers.ById[o.key]
		local r = rar(h)
		local owned = data.index and data.index[o.key]
		local prod = product(o.product)
		local robuxOk = prod and ((prod.id or 0) > 0 or studio)
		local gemLabel = "💎 " .. Config.FormatNum(o.gems)
		local can = gems() >= o.gems
		local buttons = {
			{ gemLabel, can and GEM or K.LOCK, function(b)
				c.click()
				if not can and gems() < o.gems then M.GemStore("You need " .. Config.FormatNum(o.gems) .. " Gems") return end
				-- a big Gem buy takes two taps (never by accident)
				local l = b:FindFirstChild("Label", true)
				if not armedGems[o.key] or os.clock() > armedGems[o.key] then
					armedGems[o.key] = os.clock() + 3
					if l then l.Text = "SURE?" end
					task.delay(3, function() if l and l.Parent and l.Text == "SURE?" then l.Text = gemLabel end end)
					return
				end
				armedGems[o.key] = nil
				if busy then return end
				busy = true
				local ok, res = call("shopbuy", o.key)
				busy = false
				if not ok then c.toast("⚠️ " .. tostring(res), T.red) if l and l.Parent then l.Text = gemLabel end return end
				revealBought(o.key, type(res) == "table" and res.new)
			end, shine = can },
		}
		if robuxOk then
			table.insert(buttons, { K.robux(prod.price), K.GREEN, function()
				c.click()
				call("shopintent", o.key)
				if (prod.id or 0) > 0 then MarketplaceService:PromptProductPurchase(c.player, prod.id)
				else c.toast(h.name .. ": Robux coming soon (" .. K.robux(prod.price) .. ")", T.accent, 2.5) end
			end, shine = true })
		end
		local t = K.tile(grid, { order = i, name = h.name, icon = art(h), iconScale = 1.04, color = r.color, artH = ART, spin = true,
			badge = { string.upper(r.name), r.color },
			stats = { { Hammers.PowerLabel(h.key, 1) .. " POWER", GOLD }, owned and { "OWNED", K.LOCK } or { "NEW!", K.GREEN } } })
		tagChip(t, o.tag, o.r == 5 and T.red or K.DARK)
		stack(t, buttons)
		K.rarityFX(t:FindFirstChild("Art"), r.id)
		local tl = t:FindFirstChild("Title")
		if tl then K.rarityText(tl, r.id, rarText(r)) end
		local chip = t:FindFirstChild("Chip")
		if chip then K.rarityChip(chip, r.id) end
		-- the Legendary is the one most players want: a soft gold glow around it
		if o.r == 5 then
			local glow = new("UIStroke", { Thickness = 4, Color = Color3.fromRGB(255, 200, 60), Transparency = 0.2, Parent = glowFrame(t) })
			task.spawn(function()
				local t0 = os.clock()
				while glow.Parent do
					glow.Transparency = 0.15 + 0.45 * (0.5 + 0.5 * math.sin((os.clock() - t0) * 3))
					task.wait(0.05)
				end
			end)
		end
	end
	-- the last card on the right: the Thunderclap Hammer, Robux only (the game pass), electric
	local sh = Config.StormHammer
	local pass
	if sh then for _, pp in ipairs(Config.Store.passes) do if pp.key == sh.pass then pass = pp end end end
	if sh and pass then
		local ex = Hammers.RarityById.exclusive
		local owns = c.player:GetAttribute("Pass_" .. sh.pass) == true
		local o = { order = 10, name = sh.name, icon = sh.icon or art(Hammers.ById[sh.key or "thunder"]), iconScale = 1.04, color = ex.color, spin = true,
			artH = ART, badge = { "EXCLUSIVE", ex.color }, stats = { { "x" .. sh.mult .. " POWER", GOLD }, { "FOREVER", K.GREEN } } }
		if owns then
			o.status = { "OWNED", K.GREEN }
		end
		local t = K.tile(grid, o)
		tagChip(t, "ROBUX ONLY", T.red)
		if not owns and ((pass.id or 0) > 0 or studio) then
			stack(t, { { K.robux(pass.price), K.GREEN, function()
				c.click()
				if (pass.id or 0) > 0 then MarketplaceService:PromptGamePassPurchase(c.player, pass.id)
				else c.toast(sh.name .. ": coming soon (" .. K.robux(pass.price) .. ")", T.accent, 2.5) end
			end, shine = true } })
		end
		K.rarityFX(t:FindFirstChild("Art"), "exclusive")
		local tl = t:FindFirstChild("Title")
		if tl then K.rarityText(tl, "exclusive", ex.color) end
		local chip = t:FindFirstChild("Chip")
		if chip then K.rarityChip(chip, "exclusive") end
		-- (in the place of a second button: what makes it special)
		K.text({ Position = UDim2.new(0, 13, 1, -10 - BH - 6 - BH), Size = UDim2.new(1, -26, 0, BH), Text = "Never in a crate · x" .. sh.mult .. " build power for you and your crew",
			TextSize = 15, Max = 15, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Center, TextColor3 = K.SUB, ZIndex = 3, Parent = t })
		-- an electric glow around the card
		local glow = new("UIStroke", { Thickness = 4, Color = ex.color, Transparency = 0.2, Parent = glowFrame(t) })
		task.spawn(function()
			local t0 = os.clock()
			while glow.Parent do
				glow.Transparency = 0.1 + 0.5 * (0.5 + 0.5 * math.sin((os.clock() - t0) * 4))
				task.wait(0.05)
			end
		end)
	end
end

function M.Crates(tok)
	local data = dataNow()
	if not c.live(tok) then return end
	if not data then K.empty(c.content, 1, "Couldn't load the crates. Open the Shop again.", "gift") return end
	local tut = inTut()
	if not tut then dailyHammers(1, data) end
	K.section(c.content, 3, "HAMMER CRATES", Color3.fromRGB(255, 220, 110), "a hammer in every crate  ·  ? = what's inside  ·  a free one every 6 contracts")
	crateTiles(data, 4, true)
	if tut then return end -- (the Inventory and the passes open after the tutorial)
	K.row(c.content, 6, { name = "Your hammers live in your INVENTORY", line = #data.hammers .. " hammers  ·  equip, level up, trade up, the Index", icon = "backpack",
		color = Color3.fromRGB(255, 176, 40), height = 92, buttonW = 190, button = { "INVENTORY", Color3.fromRGB(255, 176, 40), function()
			c.click()
			if _G.__CE_ShowInventory then _G.__CE_ShowInventory("hammers") end
		end } })
end

---------------------------------------------------------------------------------------------------------------------
-- Inventory: small item tiles (6 a row), so a big collection fits on a page
---------------------------------------------------------------------------------------------------------------------
local function clearBody()
	for _, ch in ipairs(c.content:GetChildren()) do
		if not ch:IsA("UIListLayout") and ch.Name ~= "Tabs" then ch:Destroy() end
	end
end
-- a grid of small tiles that always keeps its column count (a short row stays small, on the left)
local function smallGrid(order, parent)
	local n = invCols()
	local f = new("Frame", { Name = "Grid", Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, LayoutOrder = order, ZIndex = 2, Parent = parent or c.content })
	new("UIGridLayout", { CellSize = UDim2.new(1 / n, -math.ceil(8 * (n - 1) / n), 0, 158), CellPadding = UDim2.fromOffset(8, 8), SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = Enum.HorizontalAlignment.Left, Parent = f })
	return f
end
local function small(chip, s) new("UIScale", { Scale = s or 0.78, Parent = chip }) return chip end

-- one hammer as a small tile: art, rarity, level, name, a line. The whole tile is a button.
local function miniTile(grid, o)
	local t = new("TextButton", { Name = "Item", Text = "", AutoButtonColor = false, BackgroundTransparency = 1, LayoutOrder = o.order or 0, ZIndex = 2, Parent = grid })
	local bg = UI.slice("tile", { Name = "Bg", ImageColor3 = o.selected and Color3.fromRGB(255, 236, 160) or (o.dim and K.DIM or K.TILE), ZIndex = 1, Parent = t })
	local artH = o.artH or 84
	local box = K.artBox(t, o.icon, o.color, { Position = UDim2.fromOffset(6, 6), Size = UDim2.new(1, -12, 0, artH), Spin = o.spin, Dim = o.dim, IconScale = 1.04 })
	if o.rid then K.rarityFX(box, o.rid, { dim = o.dim, small = true }) end
	if o.badge then
		local b = small(K.chip(t, o.badge[1], o.badge[2], { Position = UDim2.fromOffset(9, 9), ZIndex = 8 }), 0.66)
		if o.rid and o.badgeRarity then K.rarityChip(b, o.rid) end
	end
	if o.tag then small(K.chip(t, o.tag[1], o.tag[2], { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -9, 0, 9), ZIndex = 8 }), 0.66) end
	local nm = K.text({ Position = UDim2.fromOffset(8, artH + 8), Size = UDim2.new(1, -16, 0, 32), Text = o.name, TextSize = 15, Max = 15, TextXAlignment = Enum.TextXAlignment.Center,
		TextYAlignment = Enum.TextYAlignment.Center, TextWrapped = true, TextColor3 = o.dim and K.SUB or K.DARK, ZIndex = 3, Parent = t })
	if o.rid and not o.dim then K.rarityText(nm, o.rid, o.nameColor) end
	if o.line then
		K.text({ Position = UDim2.fromOffset(8, artH + 42), Size = UDim2.new(1, -16, 0, 16), Text = o.line, TextSize = 13, Max = 13, Font = T.chunky,
			TextXAlignment = Enum.TextXAlignment.Center, TextColor3 = o.lineColor or K.SUB, ZIndex = 3, Parent = t })
	end
	if o.ring then
		new("UIStroke", { Thickness = 3, Color = o.ring, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = new("Frame", { Name = "Ring",
			Position = UDim2.fromOffset(2, 2), Size = UDim2.new(1, -4, 1, -4), BackgroundTransparency = 1, ZIndex = 9, Parent = t }, { UI.corner(16) }) })
	end
	if o.new then
		-- a pulsing NEW pill on the picture's corner
		local pill = new("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, -7), Size = UDim2.fromOffset(44, 20), BackgroundColor3 = Color3.fromRGB(255, 52, 84), BorderSizePixel = 0, ZIndex = 10, Parent = t })
		UI.corner(8).Parent = pill
		new("UIStroke", { Thickness = 2, Color = T.ink, Parent = pill })
		new("TextLabel", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "NEW", Font = T.chunky, TextSize = 13, TextColor3 = Color3.new(1, 1, 1), ZIndex = 11, Parent = pill })
		local ps = new("UIScale", { Parent = pill })
		TweenService:Create(ps, TweenInfo.new(0.55, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Scale = 1.15 }):Play()
	end
	if o.onClick then
		t.Activated:Connect(function() o.onClick(t) end)
		local sc = new("UIScale", { Parent = t })
		t.MouseButton1Down:Connect(function() UI.tween(sc, 0.08, { Scale = 0.95 }) end)
		t.MouseButton1Up:Connect(function() UI.tween(sc, 0.12, { Scale = 1 }, Enum.EasingStyle.Back) end)
		t.MouseLeave:Connect(function() UI.tween(sc, 0.12, { Scale = 1 }) end)
	end
	return t, bg
end

-- a row of small filter buttons (ALL + every rarity you own)
local function filterRow(order, counts, current, onPick)
	local row = new("Frame", { Name = "Filters", Size = UDim2.new(1, 0, 0, 36), BackgroundTransparency = 1, LayoutOrder = order, ZIndex = 3, Parent = c.content })
	new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = row })
	local total = 0
	for _, n in pairs(counts) do total += n end
	local function btn(label, color, on, i, id)
		local w = TextService:GetTextSize(label, 15, T.body, Vector2.new(1000, 40)).X + 30
		local b = UI.button(label, on and color or UI.TAB_OFF, nil, { Size = UDim2.fromOffset(w, 34), TextSize = 15, LayoutOrder = i, ZIndex = 3, Parent = row })
		if not on then
			local sh = b.Bg:FindFirstChild("Shine")
			if sh then sh.ImageTransparency = 0.55 end
		elseif type(id) == "number" and Hammers.Rarities[id] and K.RARITY_LOOK[Hammers.Rarities[id].id] and b.Bg:IsA("ImageLabel") then
			K.rarityChip(b.Bg, Hammers.Rarities[id].id)
		end
		b.Activated:Connect(function() c.click(); onPick(id) end)
	end
	btn("ALL " .. total, Color3.fromRGB(110, 200, 255), current == nil, 0, nil)
	for r = #Hammers.Rarities, 1, -1 do
		if (counts[r] or 0) > 0 then
			local rr = Hammers.Rarities[r]
			btn(rr.name:upper() .. " " .. counts[r], rr.text and Color3.fromRGB(90, 90, 140) or rr.color, current == r, 10 - r, r)
		end
	end
	-- the row never spills: it shrinks a little when there are many rarities
	K.fitRow(row, row:FindFirstChildOfClass("UIListLayout"), 0.6, 0, c.content)
	return row
end

-- the smart toolbar of the inventories (like the big games): search by name + menus (SORT, RARITY, SHOW...)
-- o = { order, search, onSearch(text), placeholder, menus = { { label, value, w, options = { { key, text, color } }, onPick(key) } } }
local function toolbar(o)
	local bar = new("Frame", { Name = "Toolbar", Size = UDim2.new(1, 0, 0, 42), BackgroundTransparency = 1, LayoutOrder = o.order, ZIndex = 10, Parent = c.content })
	new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder,
		VerticalAlignment = Enum.VerticalAlignment.Center, Parent = bar })
	new("UIPadding", { PaddingLeft = UDim.new(0, 4), Parent = bar })
	-- search
	local box = UI.slice("pill", { Name = "Search", Size = UDim2.fromOffset(o.searchW or 230, 38), SliceScale = 0.42, ImageColor3 = Color3.new(1, 1, 1), LayoutOrder = 1, ZIndex = 10, Parent = bar })
	new("UIStroke", { Thickness = 2.5, Color = T.ink, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 10, Parent = box }, { UI.corner(19) }) })
	local tb = new("TextBox", { Position = UDim2.fromOffset(16, 0), Size = UDim2.new(1, -32, 1, 0), BackgroundTransparency = 1, Text = o.search or "", PlaceholderText = o.placeholder or "Search...",
		Font = T.body, TextSize = 17, TextColor3 = K.DARK, PlaceholderColor3 = Color3.fromRGB(150, 146, 186), TextXAlignment = Enum.TextXAlignment.Left, ClearTextOnFocus = false, ZIndex = 11, Parent = box })
	local pending = 0
	tb:GetPropertyChangedSignal("Text"):Connect(function()
		pending += 1
		local mine = pending
		task.delay(0.15, function() if mine == pending and tb.Parent then o.onSearch(tb.Text) end end) -- typing fast makes one refresh
	end)
	-- the menus: a button that opens a list under it
	local openMenu
	local function closeMenu() if openMenu then openMenu.frame:Destroy(); openMenu = nil end end
	for i, m in ipairs(o.menus) do
		local function textOf(key) for _, op in ipairs(m.options) do if op.key == key then return op.text end end return "ALL" end
		local b = UI.button(m.label .. ": " .. textOf(m.value), m.color or Color3.fromRGB(110, 120, 210), nil, { Size = UDim2.fromOffset(m.w or 210, 38), TextSize = 15, LayoutOrder = 1 + i, ZIndex = 10, Parent = bar })
		b.Activated:Connect(function()
			c.click()
			local was = openMenu and openMenu.owner
			closeMenu()
			if was == b then return end
			local list = new("Frame", { Name = "Menu", Position = UDim2.new(0, 0, 1, 6), Size = UDim2.fromOffset(math.max(m.w or 210, 210), #m.options * 38 + 12), BackgroundTransparency = 1, ZIndex = 30, Parent = b })
			UI.slice("tile", { ImageColor3 = Color3.fromRGB(44, 40, 104), ZIndex = 30, Parent = list })
			for j, op in ipairs(m.options) do
				local on = op.key == m.value
				local ob = new("TextButton", { Position = UDim2.fromOffset(6, 6 + (j - 1) * 38), Size = UDim2.new(1, -12, 0, 34), BackgroundColor3 = on and Color3.fromRGB(110, 96, 220) or Color3.fromRGB(66, 60, 140),
					AutoButtonColor = true, Text = op.text, Font = T.chunky, TextSize = 16, TextColor3 = op.color or Color3.new(1, 1, 1), ZIndex = 31, Parent = list })
				UI.corner(9).Parent = ob
				new("UIStroke", { Thickness = 1.6, Color = T.ink, ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual, Parent = ob })
				ob.Activated:Connect(function()
					c.click()
					closeMenu()
					m.value = op.key
					local lb = b:FindFirstChild("Label")
					if lb then lb.Text = m.label .. ": " .. op.text end
					m.onPick(op.key)
				end)
			end
			openMenu = { frame = list, owner = b }
		end)
	end
	-- the bar never spills: it shrinks a little on a narrow window
	K.fitRow(bar, bar:FindFirstChildOfClass("UIListLayout"), 0.6, 8, c.content)
	return bar
end

-- how the hammers can be ordered (every one ends on the id: the same hammers always land in the same places)
local function powerOf(it) return Hammers.Power(it.k, it.lv) end
local function dr(h) return h.dr or h.r end
local SORTS = {
	{ key = "power_desc", text = "BEST POWER", fn = function(a, b, ha, hb) if powerOf(a) ~= powerOf(b) then return powerOf(a) > powerOf(b) end if dr(ha) ~= dr(hb) then return dr(ha) > dr(hb) end end },
	{ key = "power_asc", text = "LOWEST POWER", fn = function(a, b, ha, hb) if powerOf(a) ~= powerOf(b) then return powerOf(a) < powerOf(b) end if dr(ha) ~= dr(hb) then return dr(ha) < dr(hb) end end },
	{ key = "rarity_desc", text = "RAREST FIRST", fn = function(a, b, ha, hb) if dr(ha) ~= dr(hb) then return dr(ha) > dr(hb) end if powerOf(a) ~= powerOf(b) then return powerOf(a) > powerOf(b) end end },
	{ key = "rarity_asc", text = "COMMON FIRST", fn = function(a, b, ha, hb) if dr(ha) ~= dr(hb) then return dr(ha) < dr(hb) end if powerOf(a) ~= powerOf(b) then return powerOf(a) < powerOf(b) end end },
	{ key = "level_desc", text = "HIGHEST LEVEL", fn = function(a, b, ha, hb) if (a.lv or 1) ~= (b.lv or 1) then return (a.lv or 1) > (b.lv or 1) end if powerOf(a) ~= powerOf(b) then return powerOf(a) > powerOf(b) end end },
	{ key = "newest", text = "NEWEST", fn = function(a, b) if (a.t or 0) ~= (b.t or 0) then return (a.t or 0) > (b.t or 0) end end },
}
local function sortBy(list, key)
	local f
	for _, so in ipairs(SORTS) do if so.key == key then f = so.fn end end
	f = f or SORTS[1].fn
	table.sort(list, function(a, b)
		local ha, hb = Hammers.ById[a.k], Hammers.ById[b.k]
		local r = f(a, b, ha, hb)
		if r ~= nil then return r end
		if ha.order ~= hb.order then return ha.order < hb.order end
		return tostring(a.id) < tostring(b.id)
	end)
end
-- the RARITY menu: ALL + every rarity (with how many there are)
local function rarityOptions(counts)
	local ops = { { key = 0, text = "ALL" } }
	for r = #Hammers.Rarities, 1, -1 do
		if (counts[r] or 0) > 0 then
			local rr = Hammers.Rarities[r]
			table.insert(ops, { key = r, text = string.upper(rr.name) .. "  " .. counts[r], color = rr.id == "secret" and Color3.fromRGB(205, 205, 240) or rr.color:Lerp(Color3.new(1, 1, 1), 0.3) })
		end
	end
	return ops
end
local function matches(h, text)
	if not text or text == "" then return true end
	return string.find(string.lower(h.name), string.lower(text), 1, true) ~= nil
end

-- Inventory → HAMMERS -----------------------------------------------------------------------------------------------
local selected -- the hammer shown on top (its EQUIP / LEVEL UP); nil = the one in your hand
local filter -- rarity index, nil = all
local hSort, hSearch = "power_desc", "" -- the HAMMERS toolbar: sort key, search text
local function drawHammers(tok, data)
	if not c.live(tok) then return end
	clearBody()
	local byId = {}
	for _, it in ipairs(data.hammers) do byId[it.id] = it end
	if selected and not byId[selected] then selected = nil end
	local cur = byId[selected or data.equip] or byId[data.equip]
	-- the selected hammer, big: what it is, EQUIP, LEVEL UP
	if cur then
		local h = Hammers.ById[cur.k]
		local r = rar(h)
		local inHand = cur.id == data.equip
		local cost = Hammers.LevelCost(cur.k, cur.lv)
		local o = { name = h.name, line = h.desc, icon = art(h), color = r.color, height = 112, buttonW = 190, spin = inHand,
			chips = { { string.upper(r.name), r.color }, { "LV " .. cur.lv .. "/" .. Hammers.MaxLevel, K.DARK }, { Hammers.PowerLabel(cur.k, cur.lv) .. " POWER", GOLD } } }
		if inHand then table.insert(o.chips, 1, { "IN YOUR HAND", K.GREEN }) end
		if cost then
			local can = money() >= cost
			o.button = { "⬆ LV " .. (cur.lv + 1) .. "  " .. fmt(cost), can and GOLD or K.LOCK, function() levelUpItem(cur, h) end, shine = can, size = 19 }
		else
			o.status = { "MAX LEVEL", GOLD }
		end
		if not inHand then o.extra = { label = "EQUIP", color = EQUIP_BLUE, w = 110, onClick = function() equipItem(cur, h) end } end
		local row = K.row(c.content, 1, o)
		-- the rare ones wear their look on top too
		if K.RARITY_LOOK[r.id] then
			K.rarityFX(row:FindFirstChild("Art"), r.id)
			K.rarityText(row:FindFirstChild("Title"), r.id)
			local cf = row:FindFirstChild("Chips")
			for _, ch in ipairs(cf and cf:GetChildren() or {}) do
				local lb = ch:FindFirstChildOfClass("TextLabel")
				if lb and lb.Text == string.upper(r.name) then K.rarityChip(ch, r.id) end
			end
		end
		-- the picture opens the hammer's card
		local hit = new("TextButton", { Text = "", AutoButtonColor = false, Position = UDim2.fromOffset(9, 9), Size = UDim2.fromOffset(94, 94), BackgroundTransparency = 1, ZIndex = 9, Parent = row })
		hit.Activated:Connect(function() c.click(); hammerPopup(h, cur, data) end)
	end
	local total = 0
	for _, n in pairs(data.crates) do total += n end
	if total > 0 then
		K.row(c.content, 2, { name = total .. (total == 1 and " crate" or " crates") .. " waiting to be opened", line = "Every crate holds a new hammer", icon = "gift", color = GOLD, height = 84, buttonW = 170,
			button = { "OPEN", K.GREEN, function() c.click(); if c.showInventory then c.showInventory("crates") end end, shine = true, size = 22 } })
	end
	-- the toolbar (search, SORT, RARITY) and the grid; the toolbar only refills the grid (the search box keeps its focus)
	local counts = {}
	for _, it in ipairs(data.hammers) do local r = dr(Hammers.ById[it.k]); counts[r] = (counts[r] or 0) + 1 end
	if filter and not counts[filter] then filter = nil end
	K.section(c.content, 3, "MY HAMMERS", Color3.fromRGB(150, 215, 255), #data.hammers .. " / " .. Hammers.InventoryCap .. "  ·  tap one to see it")
	local grid
	local function fill()
		for _, ch in ipairs(grid:GetChildren()) do if not ch:IsA("UIGridLayout") then ch:Destroy() end end
		local list = {}
		for _, it in ipairs(data.hammers) do
			local h = Hammers.ById[it.k]
			if (not filter or dr(h) == filter) and matches(h, hSearch) then table.insert(list, it) end
		end
		sortBy(list, hSort)
		for n, it in ipairs(list) do
			local h = Hammers.ById[it.k]
			local r = rar(h)
			local isCur = cur and it.id == cur.id
			miniTile(grid, { order = n, name = h.name, icon = art(h), color = r.color, badge = { string.upper(r.name), r.color }, tag = { "LV " .. it.lv, K.DARK }, rid = r.id, badgeRarity = true, nameColor = rarText(r),
				line = it.id == data.equip and "✋ IN HAND" or (Hammers.PowerLabel(it.k, it.lv) .. " power"), lineColor = it.id == data.equip and GREEN_TXT or nil,
				ring = it.id == data.equip and K.GREEN or (isCur and GOLD or nil), spin = it.id == data.equip, new = isNew(it),
				onClick = function()
					c.click()
					seen[it.id] = true
					if selected == it.id then hammerPopup(h, it, data) return end -- a second tap opens its card
					selected = it.id
					drawHammers(tok, data)
					c.content.CanvasPosition = Vector2.new(0, 0) -- the selected hammer is on top
				end })
		end
		if #list == 0 then
			K.text({ Text = "Nothing matches", TextSize = 16, Max = 16, TextXAlignment = Enum.TextXAlignment.Center, TextColor3 = K.NOTE, ZIndex = 3, Parent = grid })
		end
	end
	toolbar({ order = 4, search = hSearch, placeholder = "Search hammers...", onSearch = function(t) hSearch = t; fill() end, menus = {
		{ label = "SORT", value = hSort, w = 230, options = SORTS, onPick = function(k) hSort = k; fill() end },
		{ label = "RARITY", value = filter or 0, w = 210, options = rarityOptions(counts), onPick = function(k) filter = k ~= 0 and k or nil; fill() end },
	} })
	grid = smallGrid(5)
	fill()
	K.note(c.content, 6, "Tap a hammer to see it, tap it again for its card. Trade with other builders (TRADE); Rusty and pass hammers always stay yours.")
end

function M.Hammers(tok)
	local data = dataNow()
	if not c.live(tok) then return end
	if not data then K.empty(c.content, 1, "Couldn't load your hammers. Open the Inventory again.", "shop") return end
	drawHammers(tok, data)
end

-- Inventory → CRATES: the crates you have, one OPEN each ----------------------------------------------------------
function M.MyCrates(tok)
	local data = dataNow()
	if not c.live(tok) then return end
	if not data then K.empty(c.content, 1, "Couldn't load your crates. Open the Inventory again.", "gift") return end
	local total = 0
	for _, n in pairs(data.crates) do total += n end
	local left = 6 - (tonumber(data.progress) or 0)
	if total > 0 then
		K.section(c.content, 1, "YOUR CRATES", Color3.fromRGB(255, 220, 110), total .. " to open  ·  ? = what's inside  ·  next free Supply Crate in " .. left .. (left == 1 and " contract" or " contracts"))
		crateTiles(data, 2, false)
	else
		K.banner(c.content, 1, { name = "NO CRATES RIGHT NOW", line = "Your next free Supply Crate comes in " .. left .. (left == 1 and " contract" or " contracts") .. ". More in the Shop (CRATES): cash, Gems or Robux.", icon = "gift", color = K.LOCK,
			tint = Color3.fromRGB(220, 222, 240), height = 118, bar = { (6 - left) / 6, GOLD, (6 - left) .. " / 6 contracts" } })
	end
	-- (the Shop opens once the tutorial is done: no shortcut around its lock)
	if (c.player:GetAttribute("RoadStep") or 1) > (Config.TutorialSteps or 6) then
		K.row(c.content, 3, { name = "Need more crates?", line = "Supply Crates for cash, Builder's and Golden Crates for Gems or Robux", icon = "shop", color = Color3.fromRGB(110, 200, 255), height = 92, buttonW = 190,
			button = { "SHOP", K.GREEN, function() c.click(); if _G.__CE_ShopUI then _G.__CE_ShopUI.Show("hammers") end end, size = 22 } })
	end
	K.note(c.content, 4, "The hammers you find go to the HAMMERS tab. 10 hammers of one rarity make 1 of the next in TRADE-UP.")
end

-- Inventory → TRADE-UP: a contract like CS:GO. Put 10 hammers of one rarity in the slots, get 1 random of the next ----
local picked = {} -- item ids in the contract, in order
local function drawTradeUp(tok, data)
	if not c.live(tok) then return end
	clearBody()
	local byId = {}
	for _, it in ipairs(data.hammers) do byId[it.id] = it end
	local keep = {}
	for _, id in ipairs(picked) do if byId[id] then table.insert(keep, id) end end
	picked = keep
	local rarity = picked[1] and Hammers.ById[byId[picked[1]].k].r or nil
	local N = Hammers.TradeUpCount
	local regular = { exclusiveOnly = false }
	-- the contract
	local panel = new("Frame", { Name = "Contract", Size = UDim2.new(1, 0, 0, 232), BackgroundTransparency = 1, LayoutOrder = 1, ZIndex = 2, Parent = c.content })
	UI.slice("tile", { Name = "Bg", ImageColor3 = Color3.fromRGB(240, 236, 255), ZIndex = 1, Parent = panel })
	local from, to = rarity and Hammers.Rarities[rarity], rarity and Hammers.Rarities[rarity + 1]
	local title = rarity and (string.upper(from.name) .. "  →  " .. (to and string.upper(to.name) or "—")) or "TRADE-UP CONTRACT"
	local tl = K.text({ Position = UDim2.fromOffset(18, 10), Size = UDim2.new(1, -250, 0, 34), Text = title, Font = T.chunky, TextSize = 28, Max = 28,
		TextColor3 = Color3.new(1, 1, 1), Stroke = 3, ZIndex = 3, Parent = panel })
	if from then new("UIGradient", { Color = ColorSequence.new(from.color:Lerp(Color3.new(1, 1, 1), 0.3), to and to.color or from.color), Parent = tl }) end
	K.text({ Position = UDim2.fromOffset(18, 44), Size = UDim2.new(1, -250, 0, 22), TextSize = 16, Max = 16, TextColor3 = K.SUB, ZIndex = 3, Parent = panel,
		Text = rarity and ("Put in " .. N .. " " .. from.name .. " hammers: you get 1 random " .. (to and to.name or "?") .. " hammer (" .. (to and Hammers.PowerLabel(Hammers.PoolAt(regular, rarity + 1)[1] and Hammers.PoolAt(regular, rarity + 1)[1].key or "rusty", 1) or "?") .. " power). Levels are not kept.")
			or ("Tap " .. N .. " hammers of the same rarity below. You get 1 random hammer of the next rarity.") })
	-- the 10 slots
	local slots = new("Frame", { Position = UDim2.fromOffset(14, 76), Size = UDim2.new(1, -28, 0, 82), BackgroundTransparency = 1, ZIndex = 3, Parent = panel })
	new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6), HorizontalAlignment = Enum.HorizontalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder, Parent = slots })
	for i = 1, N do
		local id = picked[i]
		local it = id and byId[id]
		local s = new("TextButton", { Text = "", AutoButtonColor = false, Size = UDim2.new(1 / N, -6, 1, 0), BackgroundTransparency = 1, LayoutOrder = i, ZIndex = 3, Parent = slots })
		new("UIAspectRatioConstraint", { AspectRatio = 1, Parent = s })
		if it then
			local h = Hammers.ById[it.k]
			K.artBox(s, art(h), rar(h).color, { Size = UDim2.fromScale(1, 1), IconScale = 1.04 })
			local sc = new("UIScale", { Scale = 0.6, Parent = s })
			UI.tween(sc, 0.2, { Scale = 1 }, Enum.EasingStyle.Back)
			s.Activated:Connect(function()
				c.click()
				table.remove(picked, i)
				drawTradeUp(tok, data)
			end)
		else
			UI.slice("inset", { ImageColor3 = Color3.fromRGB(200, 196, 230), ZIndex = 3, Parent = s })
			K.text({ Size = UDim2.fromScale(1, 1), Text = tostring(i), Font = T.chunky, TextSize = 22, TextColor3 = Color3.fromRGB(150, 146, 190), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 4, Parent = s })
		end
	end
	-- progress + buttons
	local bar, fill = UI.bar({ Position = UDim2.fromOffset(18, 174), Size = UDim2.new(1, -440, 0, 24), ZIndex = 3 }, K.GREEN)
	bar.Parent = panel
	fill.Size = UDim2.fromScale(math.clamp(#picked / N, 0.04, 1), 1)
	K.text({ Position = UDim2.fromOffset(0, 1), Size = UDim2.fromScale(1, 1), Text = #picked .. " / " .. N, Font = T.chunky, TextSize = 15, TextColor3 = Color3.new(1, 1, 1), Stroke = 2,
		TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 6, Parent = bar })
	local ready = #picked == N and to ~= nil and #Hammers.PoolAt(regular, rarity + 1) > 0
	K.button(panel, #picked > 0 and "CLEAR" or "AUTO-FILL", #picked > 0 and K.LOCK or EQUIP_BLUE, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -224, 0, 162), Size = UDim2.fromOffset(190, 52), TextSize = 19 }, function()
		c.click()
		if #picked > 0 then picked = {}; drawTradeUp(tok, data) return end
		-- the rarity you have most of (that can go up), lowest levels first, the hammer in your hand last
		local count = {}
		for _, it in ipairs(data.hammers) do
			local h = Hammers.ById[it.k]
			if canTrade(it, h) and h.r < Hammers.LadderTop and #Hammers.PoolAt(regular, h.r + 1) > 0 then count[h.r] = (count[h.r] or 0) + 1 end
		end
		local want, best = nil, 0
		for r, n in pairs(count) do if n >= N and (not want or r < want) then want = r end; best = math.max(best, n) end
		if not want then for r, n in pairs(count) do if n == best then want = r end end end
		if not want then c.toast("No hammers to trade up yet", T.muted, 2.5) return end
		local pool = {}
		for _, it in ipairs(data.hammers) do
			local h = Hammers.ById[it.k]
			if h.r == want and canTrade(it, h) then table.insert(pool, it) end
		end
		table.sort(pool, function(a, b)
			if (a.id == data.equip) ~= (b.id == data.equip) then return b.id == data.equip end
			return (a.lv or 1) < (b.lv or 1)
		end)
		for _, it in ipairs(pool) do if #picked < N then table.insert(picked, it.id) end end
		drawTradeUp(tok, data)
	end)
	K.button(panel, ready and "TRADE UP!" or ("TRADE UP " .. #picked .. "/" .. N), ready and K.GREEN or K.LOCK,
		{ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -16, 0, 162), Size = UDim2.fromOffset(200, 52), TextSize = 21, Shine = ready }, function()
		c.click()
		if not ready then
			c.toast(#picked < N and ("Put " .. (N - #picked) .. " more in the contract") or "Nothing of the next rarity exists yet", T.muted, 2.5)
			return
		end
		local ok, res = call("tradeup", rarity, picked)
		if ok then
			picked = {}
			local h = Hammers.ById[res.key]
			if h then revealHammer(h, { head = "TRADE-UP!", isNew = res.new, button = "NICE!", onClose = function() M.Redraw() end }) else M.Redraw() end
		else
			c.toast("⚠️ " .. tostring(res), T.red)
		end
	end)
	-- what you can put in (others dimmed)
	sortHammers(data.hammers)
	K.section(c.content, 2, "YOUR HAMMERS", Color3.fromRGB(200, 170, 255), "tap to put in · tap a slot to take out · Rusty, pass and exclusive hammers stay out")
	local grid = smallGrid(3)
	local n = 0
	for _, it in ipairs(data.hammers) do
		local h = Hammers.ById[it.k]
		local r = rar(h)
		local inside = table.find(picked, it.id) ~= nil
		local ok = canTrade(it, h) and h.r < Hammers.LadderTop and (not rarity or h.r == rarity)
		n += 1
		miniTile(grid, { order = n, name = h.name, icon = art(h), color = r.color, badge = { string.upper(r.name), r.color }, tag = { "LV " .. it.lv, K.DARK }, rid = r.id, badgeRarity = true, nameColor = rarText(r),
			line = inside and "IN CONTRACT" or (it.id == data.equip and "✋ IN HAND" or nil), lineColor = inside and GREEN_TXT or nil,
			dim = not ok and not inside, selected = inside, ring = inside and K.GREEN or nil,
			onClick = function()
				c.click()
				if inside then
					table.remove(picked, table.find(picked, it.id))
				elseif not ok then
					c.toast(not canTrade(it, h) and "This hammer can't be traded up" or ("Only " .. Hammers.Rarities[rarity].name .. " hammers in this contract"), T.muted, 2)
					return
				elseif #picked >= N then
					c.toast("The contract is full", T.muted, 2)
					return
				else
					table.insert(picked, it.id)
				end
				local y = c.content.CanvasPosition
				drawTradeUp(tok, data)
				c.content.CanvasPosition = y
			end })
	end
end

function M.TradeUp(tok)
	local data = dataNow()
	if not c.live(tok) then return end
	if not data then K.empty(c.content, 1, "Couldn't load your hammers. Open the Inventory again.", "shop") return end
	drawTradeUp(tok, data)
end

-- Inventory → INDEX: the collection book ----------------------------------------------------------------------------
local idxFilter, idxFound -- rarity index (nil = all); "found" / "missing" (nil = both)
local idxSort, idxSearch = "rarity_desc", "" -- the INDEX toolbar
local function drawIndex(tok, data)
	if not c.live(tok) then return end
	clearBody()
	local owned, total = 0, #Hammers.List
	for _, h in ipairs(Hammers.List) do if data.index[h.key] then owned += 1 end end
	K.banner(c.content, 1, { name = "HAMMER INDEX", line = "Found " .. owned .. " of " .. total .. ". Tap a hammer to see where it comes from.", icon = "star", color = GOLD,
		tint = Color3.fromRGB(255, 240, 200), bar = { owned / total, GOLD, owned .. " / " .. total }, height = 124 })
	local counts = {}
	for _, h in ipairs(Hammers.List) do counts[h.dr] = (counts[h.dr] or 0) + 1 end
	-- the book: one section per rarity (rarest or most common first), refilled by the toolbar
	local book = new("Frame", { Name = "Book", Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, LayoutOrder = 3, ZIndex = 2, Parent = c.content })
	new("UIListLayout", { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder, Parent = book })
	local function fill()
		for _, ch in ipairs(book:GetChildren()) do if not ch:IsA("UIListLayout") then ch:Destroy() end end
		local order, shown = 1, 0
		local from, to, step = #Hammers.Rarities, 1, -1
		if idxSort == "rarity_asc" then from, to, step = 1, #Hammers.Rarities, 1 end
		for r = from, to, step do
			if not idxFilter or idxFilter == r then
				local rr = Hammers.Rarities[r]
				local all, list = {}, {}
				for _, h in ipairs(Hammers.List) do
					if h.dr == r then
						table.insert(all, h)
						local got = data.index[h.key] == true
						if (not idxFound or (idxFound == "found") == got) and matches(h, idxSearch) then table.insert(list, h) end
					end
				end
				if #list > 0 then
					local have = 0
					for _, h in ipairs(all) do if data.index[h.key] then have += 1 end end
					local sec = K.section(book, order, string.upper(rr.name), rr.text and Color3.fromRGB(200, 200, 235) or rr.color,
						have .. " / " .. #all .. "  ·  " .. Hammers.PowerLabel(all[1].key, 1) .. " power")
					-- breathing room: off the window's left edge, and a gap above and below
					sec.Size = UDim2.new(1, 0, 0, 48)
					local pad = sec:FindFirstChildOfClass("UIPadding") or new("UIPadding", { Parent = sec })
					pad.PaddingLeft, pad.PaddingTop, pad.PaddingBottom = UDim.new(0, 10), UDim.new(0, 8), UDim.new(0, 4)
					local tl = sec:FindFirstChildOfClass("TextLabel")
					if tl and K.RARITY_LOOK[rr.id] then K.rarityText(tl, rr.id) end
					local grid = smallGrid(order + 1, book)
					for i, h in ipairs(list) do
						local got = data.index[h.key] == true
						shown += 1
						miniTile(grid, { order = i, name = h.name, icon = h.soon and "shop" or art(h), color = rr.color, dim = not got, rid = rr.id, nameColor = rarText(rr),
							badge = got and { "✓", K.GREEN } or ((h.exclusive and rr.id ~= "exclusive") and { "EXCLUSIVE", T.red } or nil),
							line = got and "FOUND" or (h.soon and "COMING SOON" or (h.event and "EVENT ONLY" or (h.pass and "GAME PASS" or (h.exclusive and "EXCLUSIVE CRATE" or "NOT FOUND")))),
							lineColor = got and GREEN_TXT or nil,
							onClick = function() c.click(); hammerPopup(h) end })
					end
					order += 2
				end
			end
		end
		if shown == 0 then
			K.text({ Size = UDim2.new(1, 0, 0, 40), Text = idxFound == "found" and "Nothing found here yet: open some crates!" or "Nothing matches", TextSize = 18, Max = 18,
				TextXAlignment = Enum.TextXAlignment.Center, TextColor3 = K.NOTE, LayoutOrder = 1, ZIndex = 3, Parent = book })
		end
	end
	toolbar({ order = 2, search = idxSearch, placeholder = "Search the Index...", searchW = 180, onSearch = function(t) idxSearch = t; fill() end, menus = {
		{ label = "SORT", value = idxSort, w = 200, options = { { key = "rarity_desc", text = "RAREST FIRST" }, { key = "rarity_asc", text = "COMMON FIRST" } },
			onPick = function(k) idxSort = k; fill() end },
		{ label = "RARITY", value = idxFilter or 0, w = 180, options = rarityOptions(counts), onPick = function(k) idxFilter = k ~= 0 and k or nil; fill() end },
		{ label = "SHOW", value = idxFound or "all", w = 160, options = { { key = "all", text = "ALL" }, { key = "found", text = "FOUND " .. owned, color = K.GREEN },
			{ key = "missing", text = "MISSING " .. (total - owned), color = Color3.fromRGB(255, 150, 120) } }, onPick = function(k) idxFound = k ~= "all" and k or nil; fill() end },
	} })
	fill()
end

function M.Index(tok)
	local data = dataNow()
	if not c.live(tok) then return end
	if not data then K.empty(c.content, 1, "Couldn't load your hammers. Open the Inventory again.", "shop") return end
	drawIndex(tok, data)
end

---------------------------------------------------------------------------------------------------------------------
-- wiring
---------------------------------------------------------------------------------------------------------------------
-- the Inventory's red dots: a crate to open, a level-up you can afford on the hammer in your hand
function M.Available()
	local p = c.player
	local out = { crates = p:GetAttribute("CrateTotal") or 0, hammers = false }
	local key, lv = p:GetAttribute("EquipKey"), p:GetAttribute("EquipLevel") or 1
	local cost = key and Hammers.LevelCost(key, lv)
	out.hammers = cost ~= nil and money() >= cost
	return out
end

local redrawing = false
function M.Redraw()
	closePopup()
	if redrawing then return end
	redrawing = true
	task.spawn(function()
		-- the new state first (the window stays as it is meanwhile), then one redraw with it
		fetch()
		freshUntil = os.clock() + 1
		redrawing = false
		if c.modalOpen() and c.modalTitle.Text == "Inventory" then
			if c.redrawInventory then c.redrawInventory() end
		elseif c.redrawShop then
			c.redrawShop()
		end
	end)
end
-- is a hammer view on screen? (the Shop's CRATES tab or the Inventory's hammer tabs): it follows your hammers live
function M.Showing()
	if not c.modalOpen() then return false end
	if c.modalTitle.Text == "Inventory" then return c.inventoryHammerTab and c.inventoryHammerTab() or false end
	return c.modalTitle.Text == "Shop" and c.shopHammerTab and c.shopHammerTab() or false
end

function M.Init(ctx)
	c = ctx
	UI, T, Config, new = c.UI, c.T, c.Config, c.new
	task.spawn(function() HammerAction = c.Remotes:WaitForChild("HammerAction", 60) end)
	-- Roblox policy: where paid random items are restricted, the Robux crates are not sold
	c.paidRandomRestricted = false
	task.spawn(function()
		local ok, info = pcall(function() return PolicyService:GetPolicyInfoForPlayerAsync(c.player) end)
		if ok and type(info) == "table" then c.paidRandomRestricted = info.ArePaidRandomItemsRestricted == true end
	end)
	-- a crate pass bought (or switched): the crate views follow at once
	for _, at in ipairs({ "Pass_quickopen", "Pass_autoopen" }) do
		c.player:GetAttributeChangedSignal(at):Connect(function() if M.Showing() then M.Redraw() end end)
	end
	c.R.Feedback.OnClientEvent:Connect(function(kind, d)
		if kind ~= "Hammer" or type(d) ~= "table" then return end
		if d.kind == "shop" and d.via == "robux" then
			-- a Hammer of the Day bought with Robux arrived
			revealBought(d.key, d.new)
			return
		end
		if d.kind == "crate" and d.reason ~= "silent" then
			local cr = Hammers.CrateById[d.crate]
			local n = tonumber(d.n) or 1
			c.toast("📦 " .. (n > 1 and (n .. "x ") or "") .. (cr and cr.name or "Crate") .. (d.reason == "drop" and " found! Open it: INVENTORY → CRATES" or " added: INVENTORY → CRATES"), cr and cr.color or T.green, 4)
			c.sound2D(c.S.Chime, 0.4, 1.1)
		end
	end)
end

return M
