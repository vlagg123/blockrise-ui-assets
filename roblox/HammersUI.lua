-- BlockRise Empire - the hammer collection in the Shop (a Client child module, run by ShopUI):
--   HAMMERS tab: the hammer in your hand (level up), your crates (buy / open, odds and pity), every hammer you own (equip, level up)
--   INDEX tab:   trade-up (10 of a rarity -> 1 of the next) and the collection book (all 40, the ones you don't have dimmed)
-- Opening a crate: the crate shakes, then HammerFX's reveal card shows the hammer (OPEN ANOTHER while you have more).
local RS = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")
local PolicyService = game:GetService("PolicyService")
local RunService = game:GetService("RunService")
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
local studio = RunService:IsStudio()

local function money() return c.player:GetAttribute("Money") or 0 end
local function gems() return c.player:GetAttribute("Gems") or 0 end
local function fmt(n) return Config.FormatMoney(n) end
local function cols() return (_G.__CE_ListWidth and _G.__CE_ListWidth() or 780) >= 700 and 4 or 3 end
local function rar(h) return Hammers.Rarities[h.r] end
-- the picture of a hammer: the Thunderclap's pass art, its own render, or the Shop atlas icon
local function art(h)
	if Config.StormHammer and h.key == Config.StormHammer.key and Config.StormHammer.icon then return Config.StormHammer.icon end
	if h.image and Config.ProductImages and Config.ProductImages[h.image] then return Config.ProductImages[h.image] end
	for _, t in ipairs(Config.Tools) do if t.key == h.key and t.icon then return t.icon end end
	return "shop"
end
M.art = art
local function crateArt(cr) return cr.image or "gift" end
local function product(key)
	for _, p in ipairs(Config.Store.products) do if p.key == key then return p end end
end
local function pct(v) return v >= 10 and string.format("%d%%", math.floor(v + 0.5)) or (v >= 1 and string.format("%.1f%%", v) or string.format("%.2f%%", v)) end

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

-- Crate opening ------------------------------------------------------------------------------------------------
local shaker
local function stopShake()
	if shaker then shaker:Destroy(); shaker = nil end
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
		big = h.r >= 5, tier = h.r, effect = Hammers.PowerLabel(h.key, 1) .. " build power  ·  " .. h.desc, button = o.button or "KEEP",
		again = o.again, onClose = o.onClose, tag = o.pity and "PITY: GUARANTEED" or nil })
end

local openCrate
local function shakeThenReveal(cr, res)
	stopShake()
	local h = Hammers.ById[res.key]
	if not h then M.Redraw() return end
	local gui = new("ScreenGui", { Name = "CrateShake", IgnoreGuiInset = true, DisplayOrder = 110, ResetOnSpawn = false, Parent = c.player:WaitForChild("PlayerGui") })
	shaker = gui
	new("UIScale", { Scale = c.uiScale and c.uiScale.Scale or 1, Parent = gui })
	local back = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(8, 8, 22), BackgroundTransparency = 1, ZIndex = 1, Parent = gui })
	UI.tween(back, 0.2, { BackgroundTransparency = 0.4 })
	local holder = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.47), Size = UDim2.fromOffset(260, 260), BackgroundTransparency = 1, ZIndex = 2, Parent = gui })
	local glow = UI.slice("glow", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(60, 60), ImageColor3 = cr.color, ImageTransparency = 0.5, ZIndex = 2, Parent = holder })
	local pic = crateArt(cr)
	local crate
	if type(pic) == "string" and pic:find("^rbxassetid://") then
		crate = new("ImageLabel", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Image = pic, ScaleType = Enum.ScaleType.Fit, ZIndex = 4, Parent = holder })
	else
		crate = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 4, Parent = holder })
		Icons.make(pic, { Size = UDim2.fromScale(1, 1), ZIndex = 4, Parent = crate })
	end
	local sc = new("UIScale", { Scale = 0.3, Parent = crate })
	UI.tween(sc, 0.3, { Scale = 1 }, Enum.EasingStyle.Back)
	UI.tween(glow, 1.0, { Size = UDim2.fromOffset(520, 520), ImageTransparency = 0.15 })
	local lbl = UI.label({ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 1, 10), Size = UDim2.fromOffset(400, 34), Text = string.upper(cr.name), Font = T.chunky, TextSize = 28,
		TextXAlignment = Enum.TextXAlignment.Center, TextColor3 = Color3.new(1, 1, 1), ZIndex = 5, Parent = holder })
	UI.textStroke(0.1, 3).Parent = lbl
	c.sound2D(c.S.Click, 0.5, 0.8)
	task.spawn(function()
		local t0 = os.clock()
		local DUR = 1.05
		while gui.Parent and os.clock() - t0 < DUR do
			local k = (os.clock() - t0) / DUR
			crate.Rotation = math.sin(os.clock() * (30 + 40 * k)) * (5 + 16 * k)
			holder.Position = UDim2.new(0.5, math.sin(os.clock() * 53) * 6 * k, 0.47, math.cos(os.clock() * 47) * 5 * k)
			task.wait()
		end
		if not gui.Parent then return end
		for i = 1, 16 do
			local p = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.47), Size = UDim2.fromOffset(18, 18), Rotation = 45,
				BackgroundColor3 = i % 2 == 0 and Color3.new(1, 1, 1) or cr.color, BorderSizePixel = 0, ZIndex = 6, Parent = gui })
			UI.corner(4).Parent = p
			local a = i / 16 * math.pi * 2 + math.random() * 0.3
			UI.tween(p, 0.5, { Position = UDim2.new(0.5, math.cos(a) * 260, 0.47, math.sin(a) * 260), Size = UDim2.fromOffset(4, 4), BackgroundTransparency = 1 })
		end
		crate.Visible = false
		lbl.Visible = false
		task.wait(0.12)
		stopShake()
		local left = c.player:GetAttribute("Crate_" .. cr.id) or 0
		revealHammer(h, { isNew = res.new, pity = res.pity, button = "KEEP",
			again = left > 0 and { label = "OPEN ANOTHER (" .. left .. ")", fn = function() openCrate(cr.id) end } or nil,
			onClose = function() M.Redraw() end })
	end)
end

function openCrate(crateId)
	if busy then return end
	busy = true
	local ok, res = call("open", crateId)
	busy = false
	if not ok then c.toast("⚠️ " .. tostring(res), T.red) return end
	shakeThenReveal(Hammers.CrateById[crateId], res)
end

local function buyCrate(crateId, n, thenOpen)
	if busy then return end
	busy = true
	local ok, res = call("buy", crateId, n)
	busy = false
	if not ok then c.toast("⚠️ " .. tostring(res), T.red) return end
	c.sound2D(c.S.Coins, 0.4, 1)
	if thenOpen then openCrate(crateId) else M.Redraw() end
end

local function levelUp(it, h)
	local cost = Hammers.LevelCost(it.k, it.lv)
	if not cost then return end
	if money() < cost then c.click(); c.toast("💸 Not enough cash yet", T.red, 2) return end
	c.click()
	local ok, res = call("levelup", it.id)
	if ok then
		M.Redraw() -- (the server's banner says what changed)
	else
		c.toast("⚠️ " .. tostring(res), T.red)
	end
end

local function equip(it, h)
	c.click()
	local ok, res = call("equip", it.id)
	if ok then c.toast("🔨 " .. h.name .. " is in your hand", T.green, 2); M.Redraw() else c.toast("⚠️ " .. tostring(res), T.red) end
end

-- the Thunderclap pass: a Mythic storm hammer + x3 power, offered in the Shop too (until you own it)
local function stormBanner(order)
	local sh = Config.StormHammer
	if not sh then return end
	local pass
	for _, p in ipairs(Config.Store.passes) do if p.key == sh.pass then pass = p end end
	if not pass or c.player:GetAttribute("Pass_" .. sh.pass) == true then return end
	if (pass.id or 0) <= 0 and not studio then return end
	local o = { name = string.upper(sh.name), line = "A Mythic storm hammer, yours forever, plus x" .. sh.mult .. " build power for you and your crew.",
		icon = sh.icon or "up_power", color = sh.color, tint = Color3.fromRGB(150, 200, 255), buttonW = 180,
		chips = { { "MYTHIC", Hammers.RarityById.mythic.color }, { "x" .. sh.mult .. " POWER", GOLD }, { "FOREVER", K.GREEN } } }
	if (pass.id or 0) > 0 then
		o.button = { K.robux(pass.price), K.GREEN, function() c.click(); MarketplaceService:PromptGamePassPurchase(c.player, pass.id) end }
	else
		o.status = { "SOON · " .. K.robux(pass.price), K.LOCK }
	end
	K.banner(c.content, order, o)
end

-- the hammer in your hand, with LEVEL UP
local function handBanner(data, order)
	local eq
	for _, it in ipairs(data.hammers) do if it.id == data.equip then eq = it end end
	if eq then
		local h = Hammers.ById[eq.k]
		local r = rar(h)
		local cost = Hammers.LevelCost(eq.k, eq.lv)
		local o = { name = string.upper(h.name), line = h.desc, icon = art(h), color = r.color, tint = r.color:Lerp(Color3.new(1, 1, 1), 0.7), buttonW = 200,
			chips = { { "IN YOUR HAND", K.GREEN }, { string.upper(r.name), r.color }, { "LV " .. eq.lv .. "/" .. Hammers.MaxLevel, K.DARK }, { Hammers.PowerLabel(eq.k, eq.lv) .. " POWER", GOLD } } }
		if cost then
			local can = money() >= cost
			o.button = { "LEVEL UP " .. fmt(cost), can and GOLD or K.LOCK, function() levelUp(eq, h) end, shine = can }
		else
			o.status = { "MAX LEVEL", GOLD }
		end
		K.banner(c.content, order, o)
	end
end

-- the crates as tiles: shop = every crate with its price and odds; mine = only the ones you have, to OPEN
local function crateTiles(data, order, shop)
	local zone = data.zone or "town"
	local grid = K.grid(c.content, order, cols(), 300)
	for i, cr in ipairs(Hammers.Crates) do
		local have = data.crates[cr.id] or 0
		if not shop and have == 0 then continue end
		local prod = cr.product and product(cr.product)
		local robuxOk = prod and (prod.id or 0) > 0 and not c.paidRandomRestricted
		local o = { order = i, name = cr.name, icon = crateArt(cr), iconScale = cr.image and 1.06 or 0.9, color = cr.color, stats = {}, spin = have > 0 }
		if have > 0 then o.badge = { "x" .. have, T.red } end
		if cr.pity then o.tag = { "PITY " .. tostring(data.pity[cr.id] or cr.pity.every), GOLD } end
		if cr.cash then table.insert(o.stats, { string.upper(zone), K.SUB }) end
		if cr.exclusiveOnly then table.insert(o.stats, { "EXCLUSIVES", T.red }) end
		if (data.luck or 1) > 1 and not cr.exclusiveOnly then table.insert(o.stats, { "🍀 2x LUCK", K.GREEN }) end
		local buttons = {}
		if have > 0 then table.insert(buttons, { "OPEN", K.GREEN, function() c.click(); openCrate(cr.id) end, shine = true }) end
		if not shop then
			-- (the inventory only opens them)
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
				if not can then c.click(); c.toast("💎 Not enough Gems: Store → GEMS", T.red, 2.5) return end
				c.click(); buyCrate(cr.id, 1, have == 0)
			end, shine = can and have == 0 })
		end
		if shop and prod and not cr.gems then
			if robuxOk then
				table.insert(buttons, { K.robux(prod.price), K.GREEN, function() c.click(); MarketplaceService:PromptProductPurchase(c.player, prod.id) end, shine = have == 0 })
			elseif #buttons == 0 then
				o.status = { studio and ("SOON · " .. K.robux(prod.price)) or "COMING SOON", K.LOCK }
			end
		end
		if next(Hammers.Odds(cr.id, zone, 1)) == nil and have == 0 then
			-- its hammers are still being made
			buttons = {}
			o.status = { "COMING SOON", K.LOCK }
		end
		if #buttons > 0 then o.buttons = buttons end
		local t = K.tile(grid, o)
		-- the odds (Roblox: paid random items must show them)
		local odds = Hammers.Odds(cr.id, zone, data.luck or 1)
		local parts = {}
		for r = 1, #Hammers.Rarities do
			if odds[r] and odds[r] > 0 then
				local rr = Hammers.Rarities[r]
				local col = rr.text and Color3.fromRGB(90, 80, 130) or rr.color:Lerp(Color3.new(0, 0, 0), 0.15)
				table.insert(parts, string.format('<font color="#%s">%s %s</font>', col:ToHex(), rr.name, pct(odds[r])))
			end
		end
		K.text({ Position = UDim2.fromOffset(12, 196), Size = UDim2.new(1, -24, 0, 38), Text = #parts > 0 and table.concat(parts, " · ") or "Nothing to drop yet", TextSize = 14,
			TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top, TextColor3 = K.SUB, ZIndex = 3, Parent = t })
	end
	return grid
end

-- Shop → CRATES: the hammer in your hand, every crate (buy / open) --------------------------------------------------
function M.Crates(tok)
	local loading = K.loading(c.content)
	local data = fetch()
	if not c.live(tok) then return end
	loading:Destroy()
	if not data then K.empty(c.content, 1, "Couldn't load the crates. Open the Shop again.", "gift") return end
	stormBanner(0)
	handBanner(data, 1)
	K.section(c.content, 2, "HAMMER CRATES", Color3.fromRGB(255, 220, 110), "every crate holds one hammer  ·  a Supply Crate drops every 6 contracts")
	crateTiles(data, 3, true)
	K.row(c.content, 4, { name = "Your hammers are in your INVENTORY", line = #data.hammers .. " hammers  ·  equip, level up, trade up and the Index", icon = "backpack",
		color = Color3.fromRGB(255, 176, 40), height = 92, buttonW = 190, button = { "INVENTORY", Color3.fromRGB(255, 176, 40), function()
			c.click()
			if _G.__CE_ShowInventory then _G.__CE_ShowInventory("hammers") end
		end } })
end

-- Inventory: small item tiles (6 a row), so a big collection fits on a page ---------------------------------------
local function invCols() return (_G.__CE_ListWidth and _G.__CE_ListWidth() or 780) >= 700 and 6 or 4 end
local function clearBody()
	for _, ch in ipairs(c.content:GetChildren()) do
		if not ch:IsA("UIListLayout") and ch.Name ~= "Tabs" then ch:Destroy() end
	end
end
-- a grid of small tiles that always keeps its column count (a short row stays small, on the left)
local function smallGrid(order)
	local n = invCols()
	local f = new("Frame", { Name = "Grid", Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, LayoutOrder = order, ZIndex = 2, Parent = c.content })
	new("UIGridLayout", { CellSize = UDim2.new(1 / n, -math.ceil(8 * (n - 1) / n), 0, 158), CellPadding = UDim2.fromOffset(8, 8), SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = Enum.HorizontalAlignment.Left, Parent = f })
	return f
end
local function small(chip, s) new("UIScale", { Scale = s or 0.78, Parent = chip }) return chip end

-- one hammer as a small tile: art, rarity, level, name, power. The whole tile is a button.
local function miniTile(grid, o)
	local t = new("TextButton", { Name = "Item", Text = "", AutoButtonColor = false, BackgroundTransparency = 1, LayoutOrder = o.order or 0, ZIndex = 2, Parent = grid })
	local bg = UI.slice("tile", { Name = "Bg", ImageColor3 = o.selected and Color3.fromRGB(255, 236, 160) or (o.dim and K.DIM or K.TILE), ZIndex = 1, Parent = t })
	local artH = o.artH or 84
	K.artBox(t, o.icon, o.color, { Position = UDim2.fromOffset(6, 6), Size = UDim2.new(1, -12, 0, artH), Spin = o.spin, Dim = o.dim, IconScale = 1.04 })
	if o.badge then small(K.chip(t, o.badge[1], o.badge[2], { Position = UDim2.fromOffset(9, 9), ZIndex = 8 }), 0.66) end
	if o.tag then small(K.chip(t, o.tag[1], o.tag[2], { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -9, 0, 9), ZIndex = 8 }), 0.66) end
	K.text({ Position = UDim2.fromOffset(8, artH + 9), Size = UDim2.new(1, -16, 0, 18), Text = o.name, TextSize = 15, Max = 15, TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = o.dim and K.SUB or K.DARK, ZIndex = 3, Parent = t })
	if o.line then
		K.text({ Position = UDim2.fromOffset(8, artH + 28), Size = UDim2.new(1, -16, 0, 16), Text = o.line, TextSize = 13, Max = 13, Font = T.chunky,
			TextXAlignment = Enum.TextXAlignment.Center, TextColor3 = o.lineColor or K.SUB, ZIndex = 3, Parent = t })
	end
	if o.ring then
		-- the hammer in your hand / picked for a trade-up
		new("UIStroke", { Thickness = 3, Color = o.ring, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = new("Frame", { Name = "Ring",
			Position = UDim2.fromOffset(2, 2), Size = UDim2.new(1, -4, 1, -4), BackgroundTransparency = 1, ZIndex = 9, Parent = t }, { UI.corner(16) }) })
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

local function sortHammers(list, equipId)
	table.sort(list, function(a, b)
		local ha, hb = Hammers.ById[a.k], Hammers.ById[b.k]
		if equipId then
			if a.id == equipId then return true elseif b.id == equipId then return false end
		end
		if ha.r ~= hb.r then return ha.r > hb.r end
		if a.lv ~= b.lv then return a.lv > b.lv end
		return ha.order < hb.order
	end)
end

-- Inventory → HAMMERS ----------------------------------------------------------------------------------------------
local selected -- the hammer shown on top (its EQUIP / LEVEL UP); nil = the one in your hand
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
			o.button = { "⬆ LV " .. (cur.lv + 1) .. "  " .. fmt(cost), can and GOLD or K.LOCK, function() levelUp(cur, h) end, shine = can, size = 19 }
		else
			o.status = { "MAX LEVEL", GOLD }
		end
		if not inHand then o.extra = { label = "EQUIP", color = EQUIP_BLUE, w = 110, onClick = function() equip(cur, h) end } end
		K.row(c.content, 1, o)
	end
	-- crates waiting to be opened
	local total = 0
	for _, n in pairs(data.crates) do total += n end
	if total > 0 then
		K.section(c.content, 2, "CRATES TO OPEN", Color3.fromRGB(255, 220, 110), total .. " waiting  ·  tap one to open it")
		local cg = smallGrid(3)
		for i, cr in ipairs(Hammers.Crates) do
			local have = data.crates[cr.id] or 0
			if have > 0 then
				miniTile(cg, { order = i, name = cr.name, icon = crateArt(cr), color = cr.color, badge = { "x" .. have, T.red }, spin = true,
					tag = cr.pity and { "PITY " .. tostring(data.pity[cr.id] or cr.pity.every), GOLD } or nil,
					line = "TAP TO OPEN", lineColor = Color3.fromRGB(35, 154, 69), onClick = function() c.click(); openCrate(cr.id) end })
			end
		end
	end
	sortHammers(data.hammers, data.equip)
	K.section(c.content, 4, "MY HAMMERS", Color3.fromRGB(150, 215, 255), #data.hammers .. " / " .. Hammers.InventoryCap .. "  ·  tap one to see it")
	local grid = smallGrid(5)
	for i, it in ipairs(data.hammers) do
		local h = Hammers.ById[it.k]
		local r = rar(h)
		local isCur = cur and it.id == cur.id
		miniTile(grid, { order = i, name = h.name, icon = art(h), color = r.color, badge = { string.upper(r.name), r.color }, tag = { "LV " .. it.lv, K.DARK },
			line = it.id == data.equip and "✋ IN HAND" or (Hammers.PowerLabel(it.k, it.lv) .. " power"), lineColor = it.id == data.equip and Color3.fromRGB(35, 154, 69) or nil,
			ring = isCur and GOLD or nil, spin = it.id == data.equip,
			onClick = function()
				c.click()
				selected = it.id
				local y = c.content.CanvasPosition
				drawHammers(tok, data)
				c.content.CanvasPosition = Vector2.new(0, 0) -- the selected hammer is on top
			end })
	end
	K.note(c.content, 6, "Trade hammers with other builders (TRADE). The Rusty Hammer and pass hammers always stay yours.")
end

function M.Hammers(tok)
	local loading = K.loading(c.content)
	local data = fetch()
	if not c.live(tok) then return end
	loading:Destroy()
	if not data then K.empty(c.content, 1, "Couldn't load your hammers. Open the Inventory again.", "shop") return end
	drawHammers(tok, data)
end

-- Inventory → TRADE-UP: a contract like CS:GO. Put 10 hammers of one rarity in the slots, get 1 random of the next.
local picked = {} -- item ids in the contract, in order
local function canTrade(it, h) return not it.bound and not it.pass and not h.exclusive and not h.event and it.id ~= "rusty" end
local function drawTradeUp(tok, data)
	if not c.live(tok) then return end
	clearBody()
	local byId = {}
	for _, it in ipairs(data.hammers) do byId[it.id] = it end
	-- drop picks that are gone
	local keep = {}
	for _, id in ipairs(picked) do if byId[id] then table.insert(keep, id) end end
	picked = keep
	local rarity = picked[1] and Hammers.ById[byId[picked[1]].k].r or nil
	local N = Hammers.TradeUpCount
	local regular = { exclusiveOnly = false }
	-- the contract
	local panel = new("Frame", { Name = "Contract", Size = UDim2.new(1, 0, 0, 228), BackgroundTransparency = 1, LayoutOrder = 1, ZIndex = 2, Parent = c.content })
	UI.slice("tile", { Name = "Bg", ImageColor3 = Color3.fromRGB(240, 236, 255), ZIndex = 1, Parent = panel })
	local from, to = rarity and Hammers.Rarities[rarity], rarity and Hammers.Rarities[rarity + 1]
	local title = rarity and (string.upper(from.name) .. "  →  " .. (to and string.upper(to.name) or "—")) or "TRADE-UP CONTRACT"
	local tl = K.text({ Position = UDim2.fromOffset(18, 10), Size = UDim2.new(1, -250, 0, 34), Text = title, Font = T.chunky, TextSize = 28, Max = 28,
		TextColor3 = Color3.new(1, 1, 1), Stroke = 3, ZIndex = 3, Parent = panel })
	if from then new("UIGradient", { Color = ColorSequence.new(from.color:Lerp(Color3.new(1, 1, 1), 0.3), to and to.color or from.color), Parent = tl }) end
	K.text({ Position = UDim2.fromOffset(18, 44), Size = UDim2.new(1, -250, 0, 22), TextSize = 16, Max = 16, TextColor3 = K.SUB, ZIndex = 3, Parent = panel,
		Text = rarity and ("Put in " .. N .. " " .. from.name .. " hammers: you get 1 random " .. (to and to.name or "?") .. " hammer. Levels are not kept.")
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
	local bar, fill = UI.bar({ Position = UDim2.fromOffset(18, 172), Size = UDim2.new(1, -440, 0, 24), ZIndex = 3 }, K.GREEN)
	bar.Parent = panel
	fill.Size = UDim2.fromScale(math.clamp(#picked / N, 0.04, 1), 1)
	K.text({ Position = UDim2.fromOffset(0, 1), Size = UDim2.fromScale(1, 1), Text = #picked .. " / " .. N, Font = T.chunky, TextSize = 15, TextColor3 = Color3.new(1, 1, 1), Stroke = 2,
		TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 6, Parent = bar })
	local ready = #picked == N and to ~= nil and #Hammers.PoolAt(regular, rarity + 1) > 0
	K.button(panel, "AUTO-FILL", EQUIP_BLUE, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -224, 0, 160), Size = UDim2.fromOffset(190, 52), TextSize = 19 }, function()
		c.click()
		-- the rarity you picked (or the one you have most of), lowest levels first, never the hammer in your hand when there are enough others
		local want = rarity
		if not want then
			local count = {}
			for _, it in ipairs(data.hammers) do
				local h = Hammers.ById[it.k]
				if canTrade(it, h) and h.r < #Hammers.Rarities then count[h.r] = (count[h.r] or 0) + 1 end
			end
			local best = 0
			for r, n in pairs(count) do if n >= N and (not want or r < want) then want = r end; best = math.max(best, n) end
			if not want then for r, n in pairs(count) do if n == best then want = r end end end
		end
		if not want then c.toast("No hammers to trade up yet", T.muted, 2.5) return end
		local pool = {}
		for _, it in ipairs(data.hammers) do
			local h = Hammers.ById[it.k]
			if h.r == want and canTrade(it, h) and not table.find(picked, it.id) then table.insert(pool, it) end
		end
		table.sort(pool, function(a, b)
			if (a.id == data.equip) ~= (b.id == data.equip) then return b.id == data.equip end
			return (a.lv or 1) < (b.lv or 1)
		end)
		for _, it in ipairs(pool) do if #picked < N then table.insert(picked, it.id) end end
		drawTradeUp(tok, data)
	end)
	K.button(panel, ready and "TRADE UP!" or ("TRADE UP " .. #picked .. "/" .. N), ready and K.GREEN or K.LOCK,
		{ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -16, 0, 160), Size = UDim2.fromOffset(200, 52), TextSize = 21, Shine = ready }, function()
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
		local ok = canTrade(it, h) and h.r < #Hammers.Rarities and (not rarity or h.r == rarity)
		n += 1
		miniTile(grid, { order = n, name = h.name, icon = art(h), color = r.color, badge = { string.upper(r.name), r.color }, tag = { "LV " .. it.lv, K.DARK },
			line = inside and "IN CONTRACT" or (it.id == data.equip and "✋ IN HAND" or nil), lineColor = inside and Color3.fromRGB(35, 154, 69) or nil,
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
	local loading = K.loading(c.content)
	local data = fetch()
	if not c.live(tok) then return end
	loading:Destroy()
	if not data then K.empty(c.content, 1, "Couldn't load your hammers. Open the Inventory again.", "shop") return end
	drawTradeUp(tok, data)
end

-- Inventory → INDEX: the collection book ----------------------------------------------------------------------------
function M.Index(tok)
	local loading = K.loading(c.content)
	local data = fetch()
	if not c.live(tok) then return end
	loading:Destroy()
	if not data then K.empty(c.content, 1, "Couldn't load your hammers. Open the Inventory again.", "shop") return end
	local owned, total = 0, #Hammers.List
	for _, h in ipairs(Hammers.List) do if data.index[h.key] then owned += 1 end end
	K.banner(c.content, 1, { name = "HAMMER INDEX", line = "Found " .. owned .. " of " .. total .. " hammers. Open crates, trade up, trade with friends.", icon = "star", color = GOLD,
		tint = Color3.fromRGB(255, 240, 200), bar = { owned / total, GOLD, owned .. " / " .. total }, height = 124 })
	local order = 2
	for r = #Hammers.Rarities, 1, -1 do
		local rr = Hammers.Rarities[r]
		local list = {}
		for _, h in ipairs(Hammers.List) do if h.r == r then table.insert(list, h) end end
		local have = 0
		for _, h in ipairs(list) do if data.index[h.key] then have += 1 end end
		K.section(c.content, order, string.upper(rr.name), rr.text and Color3.fromRGB(200, 200, 235) or rr.color, have .. " / " .. #list .. "  ·  " .. Hammers.PowerLabel(list[1].key, 1) .. " power")
		local grid = smallGrid(order + 1)
		for i, h in ipairs(list) do
			local got = data.index[h.key] == true
			miniTile(grid, { order = i, name = h.name, icon = h.soon and "shop" or art(h), color = rr.color, dim = not got,
				badge = got and { "✓", K.GREEN } or (h.exclusive and { "EXCLUSIVE", T.red } or nil),
				line = got and "FOUND" or (h.soon and "COMING SOON" or (h.event and "EVENT ONLY" or (h.exclusive and "EXCLUSIVE CRATE" or (h.pass and "GAME PASS" or "NOT FOUND")))),
				lineColor = got and Color3.fromRGB(35, 154, 69) or nil,
				onClick = function() c.click(); c.toast(h.name .. ": " .. h.desc, rr.color, 4) end })
		end
		order += 2
	end
end

-- the Shop's red dot: a crate to open, or a level-up you can afford on the hammer in your hand
function M.Available()
	local p = c.player
	if (p:GetAttribute("CrateTotal") or 0) > 0 then return true end
	local key, lv = p:GetAttribute("EquipKey"), p:GetAttribute("EquipLevel") or 1
	local cost = key and Hammers.LevelCost(key, lv)
	return cost ~= nil and money() >= cost
end

function M.Redraw()
	if c.modalOpen() and c.modalTitle.Text == "Inventory" then
		if c.redrawInventory then c.redrawInventory() end
	elseif c.redrawShop then
		c.redrawShop()
	end
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
	c.R.Feedback.OnClientEvent:Connect(function(kind, d)
		if kind ~= "Hammer" or type(d) ~= "table" then return end
		if d.kind == "crate" and d.reason ~= "silent" then
			local cr = Hammers.CrateById[d.crate]
			local n = tonumber(d.n) or 1
			c.toast("📦 " .. (n > 1 and (n .. "x ") or "") .. (cr and cr.name or "Crate") .. (d.reason == "drop" and " found! Open it: Inventory → HAMMERS" or " added: Inventory → HAMMERS"), cr and cr.color or T.green, 4)
			c.sound2D(c.S.Chime, 0.4, 1.1)
		end
	end)
end

return M
