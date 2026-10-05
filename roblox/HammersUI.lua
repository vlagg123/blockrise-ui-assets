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

-- HAMMERS tab ----------------------------------------------------------------------------------------------------
function M.Hammers(tok)
	local loading = K.loading(c.content)
	local data = fetch()
	if not c.live(tok) then return end
	loading:Destroy()
	if not data then K.empty(c.content, 1, "Couldn't load your hammers. Open the Shop again.", "shop") return end
	local byId = {}
	for _, it in ipairs(data.hammers) do byId[it.id] = it end
	local eq = byId[data.equip]
	stormBanner(0)
	-- in your hand
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
		K.banner(c.content, 1, o)
	end
	-- crates
	local zone = data.zone or "town"
	K.section(c.content, 2, "CRATES", Color3.fromRGB(255, 220, 110), "every crate holds one hammer  ·  a Supply Crate drops every 6 contracts")
	local grid = K.grid(c.content, 3, cols(), 300)
	for i, cr in ipairs(Hammers.Crates) do
		local have = data.crates[cr.id] or 0
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
		if cr.cash then
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
		if prod and not cr.gems then
			if robuxOk then
				table.insert(buttons, { K.robux(prod.price), K.GREEN, function() c.click(); MarketplaceService:PromptProductPurchase(c.player, prod.id) end, shine = have == 0 })
			elseif #buttons == 0 then
				o.status = { studio and ("SOON · " .. K.robux(prod.price)) or "COMING SOON", K.LOCK }
			end
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
	-- the hammers you own
	table.sort(data.hammers, function(a, b)
		local ha, hb = Hammers.ById[a.k], Hammers.ById[b.k]
		if a.id == data.equip then return true elseif b.id == data.equip then return false end
		if ha.r ~= hb.r then return ha.r > hb.r end
		if a.lv ~= b.lv then return a.lv > b.lv end
		return ha.order < hb.order
	end)
	K.section(c.content, 4, "MY HAMMERS", Color3.fromRGB(150, 215, 255), #data.hammers .. " / " .. Hammers.InventoryCap .. "  ·  10 of a rarity make 1 of the next (INDEX tab)")
	local g2 = K.grid(c.content, 5, cols(), 268)
	for i, it in ipairs(data.hammers) do
		local h = Hammers.ById[it.k]
		local r = rar(h)
		local cost = Hammers.LevelCost(it.k, it.lv)
		local o = { order = i, name = h.name, icon = art(h), color = r.color, badge = { string.upper(r.name), r.color }, tag = { "LV " .. it.lv, K.DARK },
			stats = { { Hammers.PowerLabel(it.k, it.lv) .. " POWER", GOLD } } }
		if it.id == "rusty" then table.insert(o.stats, { "FOREVER", K.SUB }) elseif it.pass then table.insert(o.stats, { "PASS", EQUIP_BLUE }) elseif h.exclusive then table.insert(o.stats, { "EXCLUSIVE", T.red }) end
		local buttons = {}
		if it.id == data.equip then
			o.spin = true
			table.insert(buttons, { "IN HAND", K.GREEN, function() end })
		else
			table.insert(buttons, { "EQUIP", EQUIP_BLUE, function() equip(it, h) end })
		end
		if cost then
			local can = money() >= cost
			table.insert(buttons, { "⬆ " .. fmt(cost), can and GOLD or K.LOCK, function() levelUp(it, h) end, shine = can and it.id == data.equip })
		else
			table.insert(buttons, { "MAX", GOLD, function() end })
		end
		o.buttons = buttons
		K.tile(g2, o)
	end
	K.note(c.content, 6, "Trade hammers with other builders (TRADE). The Rusty Hammer and pass hammers always stay yours.")
end

-- INDEX tab: trade-up + the collection book --------------------------------------------------------------------
function M.Index(tok)
	local loading = K.loading(c.content)
	local data = fetch()
	if not c.live(tok) then return end
	loading:Destroy()
	if not data then K.empty(c.content, 1, "Couldn't load your hammers. Open the Shop again.", "shop") return end
	local eligible = {}
	for _, it in ipairs(data.hammers) do
		local h = Hammers.ById[it.k]
		if not it.bound and not it.pass and not h.exclusive and not h.event and it.id ~= "rusty" then eligible[h.r] = (eligible[h.r] or 0) + 1 end
	end
	local owned, total = 0, #Hammers.List
	for _, h in ipairs(Hammers.List) do if data.index[h.key] then owned += 1 end end
	K.banner(c.content, 1, { name = "HAMMER INDEX", line = "Found " .. owned .. " of " .. total .. " hammers. Open crates, trade up, trade with friends.", icon = "star", color = GOLD,
		tint = Color3.fromRGB(255, 240, 200), bar = { owned / total, GOLD, owned .. " / " .. total }, height = 124 })
	K.section(c.content, 2, "TRADE-UP", Color3.fromRGB(200, 170, 255), Hammers.TradeUpCount .. " of one rarity → 1 random hammer of the next (levels are not kept)")
	local regular = { exclusiveOnly = false }
	for r = 1, #Hammers.Rarities - 1 do
		local rr, nr = Hammers.Rarities[r], Hammers.Rarities[r + 1]
		local n = eligible[r] or 0
		local can = n >= Hammers.TradeUpCount
		local up = Hammers.PoolAt(regular, r + 1)
		local o = { order = 2 + r, name = rr.name .. "  →  " .. nr.name, line = n .. " / " .. Hammers.TradeUpCount .. " " .. rr.name .. " hammers ready",
			icon = up[1] and art(up[1]) or "shop", color = nr.color, height = 96, buttonW = 170, spin = can }
		if #up > 0 then o.chips = { { Hammers.PowerLabel(up[1].key, 1) .. " POWER", GOLD } } end
		if #up == 0 then
			o.status = { "COMING SOON", K.LOCK }
			o.dim = true
		elseif can then
			o.button = { "TRADE UP", K.GREEN, function()
				c.click()
				local ok, res = call("tradeup", r)
				if ok then
					local h = Hammers.ById[res.key]
					if h then revealHammer(h, { head = "TRADE-UP!", isNew = res.new, button = "NICE!", onClose = function() M.Redraw() end }) else M.Redraw() end
				else
					c.toast("⚠️ " .. tostring(res), T.red)
				end
			end, shine = true }
		else
			o.status = { n .. " / " .. Hammers.TradeUpCount, K.LOCK }
			o.dim = n == 0
		end
		K.row(c.content, 2 + r, o)
	end
	-- the book, best rarity first
	local order = 20
	for r = #Hammers.Rarities, 1, -1 do
		local rr = Hammers.Rarities[r]
		local list = {}
		for _, h in ipairs(Hammers.List) do if h.r == r then table.insert(list, h) end end
		local have = 0
		for _, h in ipairs(list) do if data.index[h.key] then have += 1 end end
		K.section(c.content, order, string.upper(rr.name), rr.text and Color3.fromRGB(200, 200, 235) or rr.color, have .. " / " .. #list .. "  ·  " .. Hammers.PowerLabel(list[1].key, 1) .. " power")
		local grid = K.grid(c.content, order + 1, cols(), 214)
		for i, h in ipairs(list) do
			local got = data.index[h.key] == true
			local o = { order = i, name = h.name, icon = h.soon and "shop" or art(h), color = rr.color, dim = not got, artH = 110, iconScale = h.soon and 0.7 or 1.06 }
			if got then
				o.badge = { "✓", K.GREEN }
				o.status = { h.exclusive and "EXCLUSIVE" or string.upper(rr.name), rr.color }
			else
				o.status = { h.soon and "COMING SOON" or (h.event and "EVENT ONLY" or (h.exclusive and "EXCLUSIVE CRATE" or (h.pass and "GAME PASS" or "NOT FOUND YET"))), K.LOCK }
			end
			if h.exclusive and not got then o.tag = { "EXCLUSIVE", T.red } end
			K.tile(grid, o)
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
	if c.redrawShop then c.redrawShop() end
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
			c.toast("📦 " .. (n > 1 and (n .. "x ") or "") .. (cr and cr.name or "Crate") .. (d.reason == "drop" and " found! Open it: Shop → HAMMERS" or " added: Shop → HAMMERS"), cr and cr.color or T.green, 4)
			c.sound2D(c.S.Chime, 0.4, 1.1)
		end
	end)
end

return M
