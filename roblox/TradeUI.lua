-- BlockRise Empire - trading UI: player list, trade requests and the trade window (two offers on top, your things in tabs
-- below, READY at the bottom)
local RS = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Company = require(RS.Shared:WaitForChild("Company"))
local K = require(RS.Shared:WaitForChild("MenuKit"))
local Hammers = require(RS.Shared:WaitForChild("Hammers"))

local M = {}
local c
local UI, T, new, Config
local GREEN1, GREEN2 = Color3.fromRGB(120, 226, 140), Color3.fromRGB(36, 160, 78)

local function invoke(...)
	local args = table.pack(...)
	local ok, res, msg = pcall(function() return c.R.TradeAction:InvokeServer(table.unpack(args, 1, args.n)) end)
	if not ok then return false, "Connection problem" end
	return res, msg
end

-- a player's head shot inside an art box
local function headshot(userId)
	return function(art)
		local img = new("ImageLabel", { Position = UDim2.fromOffset(4, 4), Size = UDim2.new(1, -8, 1, -8), BackgroundTransparency = 1, ZIndex = 6, Parent = art })
		task.spawn(function()
			local ok, url = pcall(function() return Players:GetUserThumbnailAsync(tonumber(userId) or 0, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size150x150) end)
			if ok and img.Parent then img.Image = url end
		end)
		return img
	end
end

---------------------------------------------------------------------------
-- Player list
---------------------------------------------------------------------------
function M.ShowPlayers()
	local tok = c.openModal("Trade", "Trade", "", GREEN1, GREEN2)
	local loading = K.loading(c.content)
	local ok, data = invoke("players")
	if not c.live(tok) then return end
	loading:Destroy()
	if not ok or type(data) ~= "table" then c.toast("⚠️ Couldn't load the player list", T.red) return end
	if c.player:GetAttribute("TradingAllowed") == false then
		-- Roblox policy for this player's region: no trading of items that can come from paid random items
		K.banner(c.content, 1, { name = "NOT AVAILABLE", line = "Trading is off in your region. You can still sell materials in Upgrades.", icon = "trade",
			color = K.LOCK, tint = Color3.fromRGB(215, 220, 240), height = 104 })
		return
	end
	K.banner(c.content, 1, { name = "SAFE TRADING", line = "Swap hammers, materials, blueprints and cash. Both press READY, then a 5 second countdown. Any change cancels it.", icon = "trade",
		color = GREEN2, tint = Color3.fromRGB(190, 240, 200), height = 110 })
	if data.myLevel < data.minLevel then
		K.row(c.content, 2, { name = "Reach Level " .. data.minLevel .. " to trade", line = "You are Level " .. data.myLevel, icon = "level", color = Color3.fromRGB(255, 196, 60),
			height = 92, buttonW = 150, status = { "🔒 LEVEL " .. data.minLevel, K.LOCK } })
	end
	K.section(c.content, 3, "PLAYERS", Color3.fromRGB(170, 245, 180), #data.players .. " on this server")
	if #data.players == 0 then
		K.row(c.content, 4, { name = "Nobody else is here yet", line = "Invite a friend and trade together!", icon = "invite", color = Color3.fromRGB(255, 130, 180),
			height = 92, buttonW = 150, button = { "INVITE", K.GREEN, function() c.click(); if _G.__CE_Invite then _G.__CE_Invite() end end } })
	end
	for i, p in ipairs(data.players) do
		local o = { name = p.name, line = "Level " .. p.level .. (p.company ~= "" and ("  ·  " .. p.company) or ""), icon = "trade", color = Color3.fromRGB(120, 200, 255),
			height = 96, buttonW = 150 }
		if p.busy then
			o.status = { "TRADING...", K.LOCK }
		elseif p.level < data.minLevel then
			o.status = { "🔒 LEVEL " .. data.minLevel, K.LOCK }
		else
			o.button = { "TRADE", K.GREEN, function()
				c.click()
				local ok2, msg = invoke("request", p.id)
				if ok2 then c.toast("🤝 Trade request sent to " .. p.name, T.green, 3) else c.toast("⚠️ " .. tostring(msg), T.red) end
			end }
		end
		local row = K.row(c.content, 4 + i, o)
		-- the art shows the player's head shot
		local art = row:FindFirstChild("Art")
		if art then
			for _, d in ipairs(art:GetChildren()) do if d.Name == "Icon" then d:Destroy() end end
			headshot(p.id)(art)
		end
	end
	-- (the "YOUR LAST TRADES" history is hidden for now; the server still keeps data.log)
end

---------------------------------------------------------------------------
-- Incoming request popup
---------------------------------------------------------------------------
local requestGui
local function showRequest(d)
	if requestGui then requestGui:Destroy() end
	local pg = c.player:WaitForChild("PlayerGui")
	requestGui = new("ScreenGui", { Name = "TradeRequest", ResetOnSpawn = false, DisplayOrder = 45, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, Parent = pg })
	local f = new("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 120), Size = UDim2.fromOffset(470, 150), BackgroundTransparency = 1, Parent = requestGui })
	new("UIScale", { Scale = math.clamp(c.uiScale and c.uiScale.Scale or 1, 0.6, 1.1), Parent = f })
	local pop = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = f })
	local sc = new("UIScale", { Scale = 0.7, Parent = pop })
	UI.tween(sc, 0.3, { Scale = 1 }, Enum.EasingStyle.Back)
	UI.slice("shadow", { Position = UDim2.fromOffset(-10, -2), Size = UDim2.new(1, 22, 1, 24), ImageTransparency = 0.1, ZIndex = 1, Parent = pop })
	UI.slice("tile", { Name = "Bg", ImageColor3 = K.TILE, ZIndex = 2, Parent = pop })
	local art = K.artBox(pop, nil, GREEN2, { Position = UDim2.fromOffset(12, 12), Size = UDim2.fromOffset(78, 78), ZIndex = 3, Custom = headshot(d.from) })
	art.ZIndex = 3
	K.text({ Position = UDim2.fromOffset(104, 16), Size = UDim2.new(1, -118, 0, 32), Text = d.name .. " wants to trade!", TextSize = 25, Max = 25, ZIndex = 4, Parent = pop })
	local timeLbl = K.text({ Position = UDim2.fromOffset(104, 52), Size = UDim2.new(1, -118, 0, 22), Text = "", TextSize = 17, TextColor3 = K.SUB, ZIndex = 4, Parent = pop })
	local gui = requestGui
	local function answer(yes)
		if gui.Parent == nil then return end
		gui:Destroy()
		if requestGui == gui then requestGui = nil end
		local ok, msg = invoke("respond", d.from, yes)
		if not ok and yes then c.toast("⚠️ " .. tostring(msg), T.red) end
	end
	local yes = UI.button("ACCEPT", K.GREEN, nil, { AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 104, 1, -12), Size = UDim2.new(0.5, -62, 0, 46), TextSize = 21, ZIndex = 5, Shine = true, Parent = pop })
	local no = UI.button("DECLINE", T.red, nil, { AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -12, 1, -12), Size = UDim2.new(0.5, -62, 0, 46), TextSize = 21, ZIndex = 5, Parent = pop })
	yes.Activated:Connect(function() c.click(); answer(true) end)
	no.Activated:Connect(function() c.click(); answer(false) end)
	c.sound2D(c.S.Chime, 0.5, 1.2)
	task.spawn(function()
		for left = 15, 1, -1 do
			if gui.Parent == nil then return end
			timeLbl.Text = "Expires in " .. left .. "s"
			task.wait(1)
		end
		if gui.Parent then answer(false) end
	end)
end

---------------------------------------------------------------------------
-- Trade window
--   top: the two offers side by side (YOU GIVE · YOU GET), each thing a card; tap one of yours to take it out
--   middle: your things in tabs (HAMMERS · MATERIALS · BLUEPRINTS · CASH), only what you have
--   bottom: what is happening + READY
-- A tap shows its result at once; the server gets the taps one at a time, in order, never too fast (no "Slow down!"),
-- and its answer is what counts in the end. When your partner changes their offer, the new cards flash and your READY
-- waits a moment (the server says how long), so nothing slips by you.
---------------------------------------------------------------------------
local win -- the open trade window: { gui, ... }
local lastView
local W, H = 900, 620
local ORANGE = Color3.fromRGB(255, 170, 40)
local CARD = Color3.fromRGB(236, 238, 252)
local FLASH = Color3.fromRGB(255, 200, 40)
local HAMMER_PIC = "rbxassetid://71762305316190"

-- the taps waiting for the server: [kind:id] = qty (the new total), in order; inflight = sent, no answer yet
local q = { want = {}, order = {}, busy = false, last = 0, inflight = {} }
local function qKey(kind, id) return kind .. ":" .. tostring(id) end

local function closeWindow()
	if win then win.gui:Destroy() win = nil end
	lastView = nil
	q.want, q.order, q.inflight = {}, {}, {}
end

local function me() return tostring(c.player.UserId) end
local function myOffer(v) return (v and v.offers[me()]) or { mats = {}, bps = {}, cash = 0, hams = {} } end
local function themId(v) return (tostring(v.a) == me()) and tostring(v.b) or tostring(v.a) end
local function themName(v) return (tostring(v.a) == me()) and v.bName or v.aName end

-- what my offer shows for one thing: my last tap if the server hasn't answered it yet, else the server's
local function shown(kind, id)
	local k = qKey(kind, id)
	if q.want[k] then return q.want[k].qty end
	if q.inflight[k] then return q.inflight[k] end
	local o = myOffer(lastView)
	if kind == "mat" then return o.mats[id] or 0 end
	if kind == "bp" then return o.bps[id] or 0 end
	if kind == "cash" then return o.cash or 0 end
	if kind == "ham" then
		for _, hm in ipairs(o.hams or {}) do if hm.id == id then return 1 end end
		return 0
	end
	return 0
end

local function have(kind, id)
	if kind == "mat" then return c.player:GetAttribute("Mat_" .. id) or 0 end
	if kind == "bp" then return c.player:GetAttribute("BP_" .. id) or 0 end
	if kind == "cash" then return math.floor(c.player:GetAttribute("Money") or 0) end
	return 0
end

local redraw -- (below)

local function pump()
	if q.busy then return end
	q.busy = true
	task.spawn(function()
		while #q.order > 0 and win do
			local k = table.remove(q.order, 1)
			local w = q.want[k]
			q.want[k] = nil
			if w then
				local gap = 0.11 - (os.clock() - q.last)
				if gap > 0 then task.wait(gap) end
				q.inflight[k] = w.qty
				q.last = os.clock()
				local ok, msg = invoke("set", w.kind, w.id, w.qty)
				q.inflight[k] = nil
				if not ok then
					if msg == "Slow down!" then
						-- (never shown: just sent again a moment later)
						if not q.want[k] then q.want[k] = w; table.insert(q.order, 1, k) end
						task.wait(0.15)
					elseif win then
						c.toast("⚠️ " .. tostring(msg), T.red)
					end
				end
				if win and #q.order == 0 then redraw() end
			end
		end
		q.busy = false
	end)
end

-- a tap: the new total of one thing in my offer
local function setQty(kind, id, qty)
	if not win then return end
	local k = qKey(kind, id)
	if not q.want[k] then table.insert(q.order, k) end
	q.want[k] = { kind = kind, id = id, qty = math.max(0, math.floor(qty)) }
	redraw()
	pump()
end

-- the cards of an offer: { key, pic, title, amount, color (art background), rarity, kind, id }
local function offerCards(o, hamLookup)
	local list = {}
	for _, hm in ipairs(o.hams or {}) do
		local h = Hammers.ById[hm.k]
		if h then
			local r = Hammers.Rarities[h.dr or h.r]
			table.insert(list, { key = "ham:" .. hm.id, pic = M.hammerArt(h), title = h.name, amount = "LV " .. (hm.lv or 1), color = r.color, rid = r.id, kind = "ham", id = hm.id,
				line = r.name .. " · " .. Hammers.PowerLabel(h.key, hm.lv or 1) })
		end
	end
	for _, m in ipairs(Company.Materials) do
		local n = o.mats[m.id] or 0
		if n > 0 then table.insert(list, { key = "mat:" .. m.id, pic = m.image or m.icon, title = m.name, amount = "x" .. Config.FormatNum(n), color = m.color, kind = "mat", id = m.id, n = n }) end
	end
	for _, b in ipairs(Company.Blueprints) do
		local n = o.bps[b.id] or 0
		if n > 0 then table.insert(list, { key = "bp:" .. b.id, pic = b.image or b.icon, title = b.name, amount = "x" .. Config.FormatNum(n), color = b.color, kind = "bp", id = b.id, n = n }) end
	end
	if (o.cash or 0) > 0 then
		table.insert(list, { key = "cash", pic = "cash", title = "Cash", amount = Config.FormatMoney(o.cash), color = Color3.fromRGB(90, 200, 110), kind = "cash", id = "cash", n = o.cash })
	end
	return list
end

-- my offer as the server has it, with my taps that are still on their way
local function myShownOffer()
	local o = K.copy(myOffer(lastView))
	o.mats, o.bps, o.hams = o.mats or {}, o.bps or {}, o.hams or {}
	local function apply(w)
		if w.kind == "mat" then o.mats[w.id] = w.qty > 0 and w.qty or nil
		elseif w.kind == "bp" then o.bps[w.id] = w.qty > 0 and w.qty or nil
		elseif w.kind == "cash" then o.cash = w.qty
		elseif w.kind == "ham" then
			local at
			for i, hm in ipairs(o.hams) do if hm.id == w.id then at = i end end
			if w.qty > 0 and not at then
				local it = win and win.hamById[w.id]
				if it then table.insert(o.hams, { id = it.id, k = it.k, lv = it.lv or 1 }) end
			elseif w.qty == 0 and at then
				table.remove(o.hams, at)
			end
		end
	end
	for k, qty in pairs(q.inflight) do
		local kind, id = k:match("^(%a+):(.+)$")
		if kind then apply({ kind = kind, id = id, qty = qty }) end
	end
	for _, w in pairs(q.want) do apply(w) end
	return o
end

local function drawOffer(list, cards, mine, flashKeys)
	for _, ch in ipairs(list:GetChildren()) do if ch:IsA("GuiObject") then ch:Destroy() end end
	-- (the "nothing yet" line sits over the whole list, not in one grid cell)
	local emptyNote = list.Parent:FindFirstChild("EmptyNote")
	if not emptyNote then
		emptyNote = K.text({ Name = "EmptyNote", Position = list.Position, Size = list.Size, TextSize = 17, Max = 17, TextWrapped = true, TextColor3 = K.SUB,
			TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 4, Parent = list.Parent,
			Text = mine and "Nothing yet - add what you give from YOUR STUFF below" or "Nothing yet..." })
	end
	emptyNote.Visible = #cards == 0
	if #cards == 0 then return end
	for i, cd in ipairs(cards) do
		local f = new("TextButton", { Name = "Card", Text = "", AutoButtonColor = false, BackgroundTransparency = 1, LayoutOrder = i, ZIndex = 4, Parent = list })
		local bg = UI.slice("tile", { Name = "Bg", ImageColor3 = CARD, SliceScale = 0.3, ZIndex = 4, Parent = f })
		local box = K.artBox(f, cd.pic, cd.color, { Position = UDim2.fromOffset(5, 5), Size = UDim2.new(1, -10, 0, 66), IconScale = 0.95 })
		box.ZIndex = 5
		if cd.rid and K.rarityFX then pcall(K.rarityFX, box, cd.rid) end
		K.text({ Position = UDim2.fromOffset(4, 72), Size = UDim2.new(1, -8, 0, 16), Text = cd.title, TextSize = 12, Max = 12, Font = T.chunky, TextXAlignment = Enum.TextXAlignment.Center,
			TextColor3 = K.DARK, ZIndex = 6, Parent = f })
		K.chip(f, cd.amount, cd.kind == "ham" and Color3.fromRGB(60, 56, 110) or (cd.kind == "cash" and Color3.fromRGB(40, 160, 80) or K.DARK),
			{ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 88), ZIndex = 7 })
		if mine then
			-- tap to take it out
			local x = new("Frame", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -2, 0, 2), Size = UDim2.fromOffset(22, 22), BackgroundColor3 = T.red, BorderSizePixel = 0, ZIndex = 9, Parent = f })
			new("UICorner", { CornerRadius = UDim.new(1, 0), Parent = x })
			new("UIStroke", { Thickness = 2, Color = T.ink, Parent = x })
			K.text({ Size = UDim2.fromScale(1, 1), Position = UDim2.fromOffset(0, 1), Text = "×", Font = T.chunky, TextSize = 16, Max = 16, TextColor3 = Color3.new(1, 1, 1),
				TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 10, Parent = x })
			f.Activated:Connect(function()
				c.click()
				setQty(cd.kind, cd.id, 0)
			end)
		end
		if flashKeys and flashKeys[cd.key] then
			-- new or changed on their side: a yellow ring pulses for a moment
			local st = new("UIStroke", { Thickness = 4, Color = FLASH, Transparency = 0, Parent = bg })
			task.spawn(function()
				for _ = 1, 3 do
					if not st.Parent then return end
					UI.tween(st, 0.3, { Transparency = 0.8 }); task.wait(0.3)
					if not st.Parent then return end
					UI.tween(st, 0.3, { Transparency = 0 }); task.wait(0.3)
				end
				if st.Parent then UI.tween(st, 0.5, { Transparency = 1 }) end
			end)
		end
	end
end

-- the YOUR STUFF tabs ------------------------------------------------------------------------------------------------
local TABS = {
	{ id = "hams", label = "HAMMERS", icon = HAMMER_PIC, c1 = Color3.fromRGB(255, 200, 80), c2 = Color3.fromRGB(230, 130, 20) },
	{ id = "mats", label = "MATERIALS", icon = "rbxassetid://122360343832470", c1 = Color3.fromRGB(150, 220, 255), c2 = Color3.fromRGB(60, 140, 230) },
	{ id = "bps", label = "BLUEPRINTS", icon = "rbxassetid://77419840394146", c1 = Color3.fromRGB(150, 180, 255), c2 = Color3.fromRGB(70, 90, 230) },
	{ id = "cash", label = "CASH", icon = "cash", c1 = Color3.fromRGB(130, 230, 140), c2 = Color3.fromRGB(40, 160, 80) },
}

local function stepRow(parent, order, it)
	local f = new("Frame", { Name = "Row_" .. it.id, Size = UDim2.new(1, -6, 0, 56), BackgroundTransparency = 1, LayoutOrder = order, Parent = parent })
	UI.slice("tile", { Name = "Bg", ImageColor3 = CARD, SliceScale = 0.36, ZIndex = 4, Parent = f })
	local pic = new("Frame", { Position = UDim2.fromOffset(8, 5), Size = UDim2.fromOffset(46, 46), BackgroundTransparency = 1, ZIndex = 5, Parent = f })
	K.art(pic, it.icon, UDim2.fromScale(1.05, 1.05), 6)
	K.text({ Position = UDim2.fromOffset(62, 6), Size = UDim2.new(1, -420, 0, 24), Text = it.name, TextSize = 18, Max = 18, Font = T.chunky, ZIndex = 5, Parent = f })
	local haveL = K.text({ Position = UDim2.fromOffset(62, 30), Size = UDim2.new(1, -420, 0, 18), Text = "", TextSize = 14, Max = 14, TextColor3 = K.SUB, ZIndex = 5, Parent = f })
	-- right side: - [n] + +10 ALL
	local x0 = -344
	local function btn(label, color, x, w, fn)
		local b = UI.button(label, color, nil, { Position = UDim2.new(1, x, 0, 8), Size = UDim2.fromOffset(w, 40), TextSize = label:len() > 2 and 15 or 22, ZIndex = 6, Parent = f })
		b.Activated:Connect(function() c.click(); fn() end)
		return b
	end
	btn("-", K.LOCK, x0, 40, function() setQty(it.kind, it.id, shown(it.kind, it.id) - 1) end)
	local count = K.text({ Position = UDim2.new(1, x0 + 44, 0, 0), Size = UDim2.fromOffset(74, 56), Text = "0", Font = T.chunky, TextSize = 22, Max = 22,
		TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 6, Parent = f })
	btn("+", K.GREEN, x0 + 122, 40, function() setQty(it.kind, it.id, math.min(have(it.kind, it.id), shown(it.kind, it.id) + 1)) end)
	btn("+10", K.GREEN, x0 + 168, 54, function() setQty(it.kind, it.id, math.min(have(it.kind, it.id), shown(it.kind, it.id) + 10)) end)
	btn("ALL", Color3.fromRGB(255, 176, 40), x0 + 228, 60, function() setQty(it.kind, it.id, have(it.kind, it.id)) end)
	btn("0", K.LOCK, x0 + 294, 44, function() setQty(it.kind, it.id, 0) end)
	return { frame = f, count = count, have = haveL, it = it }
end

local function drawStuff()
	if not win then return end
	local list = win.stuff
	for _, ch in ipairs(list:GetChildren()) do if ch:IsA("GuiObject") then ch:Destroy() end end
	win.rows, win.hamCards, win.cashUI = {}, {}, nil
	local grid = list:FindFirstChildOfClass("UIGridLayout")
	local lay = list:FindFirstChildOfClass("UIListLayout")
	local tab = win.tab
	if grid then grid.Parent = nil end
	if lay then lay.Parent = nil end
	local function empty(msg)
		local f = new("Frame", { Size = UDim2.new(1, 0, 0, 120), BackgroundTransparency = 1, Parent = list })
		K.text({ Size = UDim2.fromScale(1, 1), Text = msg, TextSize = 17, Max = 17, TextWrapped = true, TextColor3 = K.NOTE, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 4, Parent = f })
	end
	if tab == "hams" then
		win.grid.Parent = list
		if #win.hams == 0 then
			win.grid.Parent = nil
			win.list.Parent = list
			empty(win.hamsLoaded and "No hammers to trade yet (your starter Rusty Hammer always stays with you)" or "Loading your hammers...")
			return
		end
		for i, e in ipairs(win.hams) do
			local r = Hammers.Rarities[e.h.dr or e.h.r]
			local f = new("TextButton", { Name = "Ham", Text = "", AutoButtonColor = false, BackgroundTransparency = 1, LayoutOrder = i, ZIndex = 4, Parent = list })
			local bg = UI.slice("tile", { Name = "Bg", ImageColor3 = CARD, SliceScale = 0.3, ZIndex = 4, Parent = f })
			local box = K.artBox(f, M.hammerArt(e.h), r.color, { Position = UDim2.fromOffset(5, 5), Size = UDim2.new(1, -10, 0, 78), IconScale = 0.95 })
			box.ZIndex = 5
			if K.rarityFX then pcall(K.rarityFX, box, r.id) end
			local nm = K.text({ Position = UDim2.fromOffset(4, 84), Size = UDim2.new(1, -8, 0, 16), Text = e.h.name, TextSize = 13, Max = 13, Font = T.chunky,
				TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 6, Parent = f })
			K.rarityText(nm, r.id)
			K.text({ Position = UDim2.fromOffset(4, 100), Size = UDim2.new(1, -8, 0, 14), Text = "LV " .. (e.it.lv or 1) .. " · " .. Hammers.PowerLabel(e.h.key, e.it.lv or 1),
				TextSize = 12, Max = 12, Font = T.chunky, TextXAlignment = Enum.TextXAlignment.Center, TextColor3 = K.SUB, ZIndex = 6, Parent = f })
			local b = UI.button("ADD", K.GREEN, nil, { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -5), Size = UDim2.new(1, -12, 0, 30), TextSize = 15, ZIndex = 7, Parent = f })
			if e.it.id == win.equipId then
				K.chip(f, "IN HAND", Color3.fromRGB(40, 170, 80), { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 8), ZIndex = 8 })
			end
			local function toggle()
				c.click()
				local on = shown("ham", e.it.id) > 0
				if not on and #myShownOffer().hams >= (lastView and lastView.maxHammers or 6) then
					c.toast("⚠️ Up to " .. (lastView and lastView.maxHammers or 6) .. " hammers per trade", T.red)
					return
				end
				setQty("ham", e.it.id, on and 0 or 1)
			end
			f.Activated:Connect(toggle)
			b.Activated:Connect(toggle)
			win.hamCards[e.it.id] = { bg = bg, btn = b }
		end
	elseif tab == "mats" or tab == "bps" then
		win.list.Parent = list
		local src = tab == "mats" and Company.Materials or Company.Blueprints
		local n = 0
		for _, m in ipairs(src) do
			local kind = tab == "mats" and "mat" or "bp"
			if have(kind, m.id) > 0 or shown(kind, m.id) > 0 then
				n += 1
				win.rows[qKey(kind, m.id)] = stepRow(list, n, { kind = kind, id = m.id, name = m.name, icon = m.image or m.icon })
			end
		end
		if n == 0 then empty(tab == "mats" and "No materials yet - they drop while you build" or "No blueprints yet - they come from the Lucky Spin and contracts") end
	elseif tab == "cash" then
		win.list.Parent = list
		local f = new("Frame", { Size = UDim2.new(1, -6, 0, 120), BackgroundTransparency = 1, LayoutOrder = 1, Parent = list })
		UI.slice("tile", { Name = "Bg", ImageColor3 = CARD, SliceScale = 0.36, ZIndex = 4, Parent = f })
		local pic = new("Frame", { Position = UDim2.fromOffset(10, 10), Size = UDim2.fromOffset(52, 52), BackgroundTransparency = 1, ZIndex = 5, Parent = f })
		K.art(pic, "cash", UDim2.fromScale(1.05, 1.05), 6)
		local haveL = K.text({ Position = UDim2.fromOffset(72, 10), Size = UDim2.new(0.45, -72, 0, 24), Text = "", TextSize = 18, Max = 18, Font = T.chunky, ZIndex = 5, Parent = f })
		local feeL = K.text({ Position = UDim2.fromOffset(72, 36), Size = UDim2.new(0.45, -72, 0, 22), Text = "", TextSize = 14, Max = 14, TextColor3 = K.SUB, ZIndex = 5, Parent = f })
		local field = UI.slice("tile", { ImageColor3 = Color3.fromRGB(74, 78, 166), Position = UDim2.new(0.45, 0, 0, 12), Size = UDim2.new(0.55, -12, 0, 44), SliceScale = 0.36, ZIndex = 5, Parent = f })
		local box = new("TextBox", { Position = UDim2.fromOffset(12, 0), Size = UDim2.new(1, -24, 1, 0), BackgroundTransparency = 1, Text = "", PlaceholderText = "Type an amount...",
			Font = T.body, TextSize = 20, TextColor3 = Color3.new(1, 1, 1), PlaceholderColor3 = Color3.fromRGB(200, 205, 240), TextXAlignment = Enum.TextXAlignment.Left,
			ClearTextOnFocus = false, ZIndex = 6, Parent = field })
		box.FocusLost:Connect(function()
			local n = tonumber((box.Text:gsub("[^%d]", ""))) or 0
			setQty("cash", "cash", math.min(n, have("cash", "cash")))
		end)
		local quick = new("Frame", { Position = UDim2.fromOffset(10, 68), Size = UDim2.new(1, -20, 0, 42), BackgroundTransparency = 1, ZIndex = 5, Parent = f })
		new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder, Parent = quick })
		for i, p in ipairs({ { "10%", 0.1 }, { "25%", 0.25 }, { "50%", 0.5 }, { "ALL", 1 }, { "CLEAR", 0 } }) do
			local b = UI.button(p[1], p[2] == 0 and K.LOCK or (p[2] == 1 and Color3.fromRGB(255, 176, 40) or K.GREEN), nil,
				{ Size = UDim2.new(0.2, -7, 1, 0), TextSize = 17, LayoutOrder = i, ZIndex = 6, Parent = quick })
			b.Activated:Connect(function()
				c.click()
				setQty("cash", "cash", math.floor(have("cash", "cash") * p[2]))
			end)
		end
		win.cashUI = { box = box, have = haveL, fee = feeL }
	end
end

-- the numbers on the YOUR STUFF side (no rebuild: a tap only changes labels and colours)
local function refreshStuff()
	if not win then return end
	for _, row in pairs(win.rows or {}) do
		local n, hv = shown(row.it.kind, row.it.id), have(row.it.kind, row.it.id)
		row.count.Text = Config.FormatNum(n)
		row.count.TextColor3 = n > 0 and Color3.fromRGB(30, 140, 60) or K.DARK
		row.have.Text = "you have " .. Config.FormatNum(hv)
	end
	for id, hc in pairs(win.hamCards or {}) do
		local on = shown("ham", id) > 0
		hc.btn.Label.Text = on and "✔ IN TRADE" or "ADD"
		UI.recolor(hc.btn, on and ORANGE or K.GREEN)
		hc.bg.ImageColor3 = on and Color3.fromRGB(255, 236, 170) or CARD
	end
	local cu = win.cashUI
	if cu then
		local n = shown("cash", "cash")
		cu.have.Text = "You have " .. Config.FormatMoney(have("cash", "cash"))
		cu.fee.Text = n > 0 and ("They get " .. Config.FormatMoney(math.floor(n * (1 - ((lastView and lastView.fee) or 0.05)))) .. " (5% trade fee)") or "Cash pays a 5% trade fee"
		if not cu.box:IsFocused() then cu.box.Text = n > 0 and Config.FormatNum(n) or "" end
	end
	-- the tab badges: how many kinds of each you put in
	local o = myShownOffer()
	local counts = { hams = #o.hams, mats = 0, bps = 0, cash = (o.cash or 0) > 0 and 1 or 0 }
	for _ in pairs(o.mats) do counts.mats += 1 end
	for _, _ in pairs(o.bps) do counts.bps += 1 end
	if win.tabSig ~= (counts.hams .. "/" .. counts.mats .. "/" .. counts.bps .. "/" .. counts.cash .. "/" .. win.tab) then
		win.tabSig = counts.hams .. "/" .. counts.mats .. "/" .. counts.bps .. "/" .. counts.cash .. "/" .. win.tab
		local list = {}
		for _, t in ipairs(TABS) do
			local e = table.clone(t)
			e.badge = counts[t.id] > 0 and counts[t.id] or nil
			table.insert(list, e)
		end
		for _, ch in ipairs(win.tabBar:GetChildren()) do ch:Destroy() end
		local row = UI.tabs(win.tabBar, list, win.tab, function(id)
			c.click()
			win.tab = id
			win.tabPicked = true
			win.tabSig = nil
			drawStuff()
			redraw()
		end)
		-- (a picture still in Roblox's review shows its older version meanwhile)
		for _, d in ipairs(row:GetDescendants()) do
			if d:IsA("ImageLabel") and d.Name == "Icon" and K.guardImage then K.guardImage(d) end
		end
	end
end

function redraw()
	if not win or not lastView then return end
	local v = lastView
	local mine = myShownOffer()
	local theirs = v.offers[themId(v)] or { mats = {}, bps = {}, cash = 0, hams = {} }
	-- their side: what is new / different since last time flashes
	local tc = offerCards(theirs)
	local sig, flash = {}, {}
	for _, cd in ipairs(tc) do
		sig[cd.key] = cd.amount
		if win.theirSig and win.theirSig[cd.key] ~= cd.amount then flash[cd.key] = true end
	end
	local theirChanged = false
	if win.theirSig then
		for k, a in pairs(win.theirSig) do if sig[k] ~= a then theirChanged = true end end
		for k, a in pairs(sig) do if win.theirSig[k] ~= a then theirChanged = true end end
	end
	local tKey = table.concat((function() local t = {} for k, a in pairs(sig) do table.insert(t, k .. "=" .. a) end table.sort(t) return t end)(), ",")
	if tKey ~= win.theirKey then
		win.theirKey = tKey
		drawOffer(win.theirList, tc, false, theirChanged and flash or nil)
		if theirChanged and c.S.Chime then c.sound2D(c.S.Chime, 0.3, 1.6) end
	end
	win.theirSig = sig
	-- my side
	local mc = offerCards(mine)
	local mKey = {}
	for _, cd in ipairs(mc) do table.insert(mKey, cd.key .. "=" .. cd.amount) end
	mKey = table.concat(mKey, ",")
	if mKey ~= win.myKey then
		win.myKey = mKey
		drawOffer(win.myList, mc, true)
	end
	refreshStuff()
	-- READY states
	local meReady, themReady = v.ready[me()], v.ready[themId(v)]
	UI.recolor(win.myReady, meReady and K.GREEN or K.LOCK)
	win.myReady.Label.Text = meReady and "✔ READY" or "NOT READY"
	UI.recolor(win.theirReady, themReady and K.GREEN or K.LOCK)
	win.theirReady.Label.Text = themReady and "✔ READY" or "NOT READY"
	win.countdownEnds = v.countdown and (os.clock() + v.countdown) or nil
	local lk = v.locks and v.locks[me()] or 0
	win.lockEnds = lk > 0 and (os.clock() + lk) or nil
	win.meReady, win.themReady = meReady, themReady
end

local function openWindow(v)
	closeWindow()
	lastView = v
	local pg = c.player:WaitForChild("PlayerGui")
	local gui = new("ScreenGui", { Name = "TradeWindow", ResetOnSpawn = false, DisplayOrder = 40, IgnoreGuiInset = true, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, Parent = pg })
	local dim = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.5, Active = true, Parent = gui })
	local panel, x, title = K.window(dim, UDim2.fromOffset(W, H), "Trade", GREEN1, GREEN2, "trade")
	local fit = math.clamp(math.min(c.camera.ViewportSize.X / (W + 40), (c.camera.ViewportSize.Y - 60) / (H + 60)), 0.5, 1.15)
	new("UIScale", { Scale = fit, Parent = panel })
	x.Activated:Connect(function() c.click(); invoke("cancel") end)
	title.Text = "Trade with " .. themName(v)

	-- the two offers
	local function column(xpos, label)
		local col = new("Frame", { Position = UDim2.new(xpos, xpos == 0 and 18 or 6, 0, 62), Size = UDim2.new(0.5, -24, 0, 208), BackgroundTransparency = 1, ZIndex = 5, Parent = panel })
		UI.slice("tile", { Name = "Bg", ImageColor3 = K.TILE, ZIndex = 1, Parent = col })
		K.text({ Position = UDim2.fromOffset(14, 6), Size = UDim2.new(1, -170, 0, 34), Text = label, Font = T.chunky, TextSize = 22, Max = 22, TextColor3 = K.DARK, ZIndex = 3, Parent = col })
		local ready = UI.button("NOT READY", K.LOCK, nil, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -10, 0, 6), Size = UDim2.fromOffset(136, 34), TextSize = 15, ZIndex = 4, Parent = col })
		ready.Active = false
		ready.Interactable = false
		local list = new("ScrollingFrame", { Position = UDim2.fromOffset(8, 46), Size = UDim2.new(1, -16, 1, -52), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 5,
			ScrollBarImageColor3 = Color3.fromRGB(150, 150, 200), CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollingDirection = Enum.ScrollingDirection.Y,
			ZIndex = 3, Parent = col })
		new("UIGridLayout", { CellSize = UDim2.fromOffset(92, 116), CellPadding = UDim2.fromOffset(6, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = list })
		new("UIPadding", { PaddingTop = UDim.new(0, 4), PaddingLeft = UDim.new(0, 2), Parent = list })
		return list, ready
	end
	local myList, myReady = column(0, "YOU GIVE")
	local theirList, theirReady = column(0.5, "YOU GET")

	-- YOUR STUFF: tabs + what you have
	local stuffBox = new("Frame", { Position = UDim2.fromOffset(18, 280), Size = UDim2.new(1, -36, 0, 236), BackgroundTransparency = 1, ZIndex = 5, Parent = panel })
	UI.slice("tile", { Name = "Bg", ImageColor3 = Color3.fromRGB(60, 56, 150), ZIndex = 1, Parent = stuffBox })
	local tabBar = new("Frame", { Name = "TabBar", Position = UDim2.fromOffset(10, 4), Size = UDim2.new(1, -20, 0, 54), BackgroundTransparency = 1, ZIndex = 6, Parent = stuffBox })
	local stuff = new("ScrollingFrame", { Position = UDim2.fromOffset(10, 62), Size = UDim2.new(1, -20, 1, -68), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 5,
		ScrollBarImageColor3 = Color3.fromRGB(200, 200, 240), CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollingDirection = Enum.ScrollingDirection.Y,
		ZIndex = 3, Parent = stuffBox })
	local grid = new("UIGridLayout", { CellSize = UDim2.fromOffset(128, 150), CellPadding = UDim2.fromOffset(8, 8), SortOrder = Enum.SortOrder.LayoutOrder })
	local lst = new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder })
	new("UIPadding", { PaddingTop = UDim.new(0, 2), PaddingLeft = UDim.new(0, 2), Parent = stuff })

	-- bottom bar: what is happening + READY
	local bar = new("Frame", { AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 18, 1, -16), Size = UDim2.new(1, -36, 0, 80), BackgroundTransparency = 1, ZIndex = 5, Parent = panel })
	UI.slice("tile", { Name = "Bg", ImageColor3 = K.TILE, ZIndex = 1, Parent = bar })
	local status = K.text({ Position = UDim2.fromOffset(18, 10), Size = UDim2.new(1, -280, 0, 30), Text = "", TextSize = 21, Max = 21, Font = T.chunky, ZIndex = 3, Parent = bar })
	local sub = K.text({ Position = UDim2.fromOffset(18, 42), Size = UDim2.new(1, -280, 0, 24), Text = "Any change cancels READY. Check what you get before you press it.", TextSize = 15, Max = 15,
		TextColor3 = K.SUB, ZIndex = 3, Parent = bar })
	local readyBtn = UI.button("READY", K.GREEN, nil, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -14, 0.5, 0), Size = UDim2.fromOffset(240, 58), TextSize = 26,
		ZIndex = 4, Shine = true, Parent = bar })
	readyBtn.Activated:Connect(function()
		c.click()
		if not win or not lastView then return end
		if win.lockEnds and os.clock() < win.lockEnds then
			c.toast("👀 " .. themName(lastView) .. " just changed the offer - look at it first", T.accent, 2)
			return
		end
		local on = not win.meReady
		task.spawn(function()
			-- (my taps reach the server first: READY is for the offer as I see it)
			local t0 = os.clock()
			while (q.busy or #q.order > 0) and os.clock() - t0 < 3 do task.wait(0.05) end
			local ok, msg = invoke("ready", on)
			if not ok and win then c.toast("⚠️ " .. tostring(msg), T.red, 2.5) end
		end)
	end)

	-- my hammers (every one but the starter Rusty: it stays with you)
	local hams, hamById = {}, {}
	win = { gui = gui, title = title, myList = myList, theirList = theirList, myReady = myReady, theirReady = theirReady, readyBtn = readyBtn, status = status, sub = sub,
		stuff = stuff, grid = grid, list = lst, tabBar = tabBar, tab = "mats", hams = hams, hamById = hamById, rows = {}, hamCards = {} }
	task.spawn(function()
		local hf = c.Remotes:FindFirstChild("HammerAction")
		-- (not "hf and hf:InvokeServer()": an and-expression keeps only the first of the two answers)
		local okH, okRes, data = pcall(function()
			if not hf then return false end
			return hf:InvokeServer("get")
		end)
		if not win or win.gui ~= gui then return end
		if okH and okRes and type(data) == "table" then
			for _, it in ipairs(data.hammers or {}) do
				local h = Hammers.ById[it.k]
				if h and it.id ~= "rusty" then table.insert(hams, { it = it, h = h }); hamById[it.id] = it end
			end
			win.equipId = data.equip
			table.sort(hams, function(a, b) if a.h.r ~= b.h.r then return a.h.r > b.h.r end return (a.it.lv or 1) > (b.it.lv or 1) end)
		end
		win.hamsLoaded = true
		-- (the first tab: hammers when you have some to trade)
		if #hams > 0 and not win.tabPicked then win.tab = "hams" end
		win.tabSig = nil
		drawStuff()
		redraw()
	end)
	-- live "you have" numbers
	local conns = {}
	table.insert(conns, c.player.AttributeChanged:Connect(function(a)
		if win and win.gui == gui and (a == "Money" or a:sub(1, 4) == "Mat_" or a:sub(1, 3) == "BP_") then refreshStuff() end
	end))
	-- status line / countdown
	table.insert(conns, RunService.RenderStepped:Connect(function()
		if not win or win.gui ~= gui then return end
		local v = lastView
		if not v then return end
		local name = themName(v)
		local lockLeft = win.lockEnds and (win.lockEnds - os.clock()) or 0
		local lbl = readyBtn:FindFirstChild("Label")
		if win.countdownEnds then
			local left = math.max(0, math.ceil(win.countdownEnds - os.clock()))
			status.Text = "🤝 Trading in " .. left .. "..."
			status.TextColor3 = Color3.fromRGB(225, 110, 10)
		elseif lockLeft > 0 then
			status.Text = "👀 " .. name .. " changed the offer - check it (" .. math.ceil(lockLeft) .. ")"
			status.TextColor3 = Color3.fromRGB(70, 120, 230)
		elseif win.meReady and not win.themReady then
			status.Text = "Waiting for " .. name .. "..."
			status.TextColor3 = K.DARK
		elseif win.themReady and not win.meReady then
			status.Text = name .. " is READY - check and press READY"
			status.TextColor3 = Color3.fromRGB(30, 140, 60)
		else
			status.Text = "Add what you give, then both press READY"
			status.TextColor3 = K.DARK
		end
		if lbl then
			local want = win.meReady and "UNREADY" or (lockLeft > 0 and ("WAIT " .. math.ceil(lockLeft)) or "READY")
			if lbl.Text ~= want then
				lbl.Text = want
				UI.recolor(readyBtn, win.meReady and ORANGE or (lockLeft > 0 and K.LOCK or K.GREEN))
			end
		end
	end))
	gui.Destroying:Connect(function() for _, cn in ipairs(conns) do cn:Disconnect() end end)
	drawStuff()
	redraw()
end

local function render(v)
	lastView = v
	redraw()
end

-- the picture of a hammer (HammersUI knows the renders)
function M.hammerArt(h)
	local HU = script.Parent:FindFirstChild("HammersUI")
	local ok, mod = pcall(require, HU)
	if ok and mod and mod.art then return mod.art(h) end
	return "shop"
end

function M.Init(ctx)
	c = ctx
	UI, T, new, Config = c.UI, c.T, c.new, c.Config
	local ev = c.Remotes:WaitForChild("TradeEvent")
	ev.OnClientEvent:Connect(function(kind, d)
		if kind == "request" then
			showRequest(d)
		elseif kind == "declined" then
			c.toast("❌ " .. d.name .. " declined your trade", T.muted, 3)
		elseif kind == "open" then
			c.closeModal()
			openWindow(d)
			c.sound2D(c.S.Chime, 0.5, 1)
		elseif kind == "update" then
			if win then render(d) else openWindow(d) end
		elseif kind == "note" then
			if d and d.text then c.toast("🤝 " .. d.text, T.accent, 3.5) end
		elseif kind == "closed" then
			closeWindow()
			if d and d.reason then c.toast("🤝 " .. d.reason, T.muted, 3.5) end
		elseif kind == "done" then
			closeWindow()
			c.banner("🤝 TRADE COMPLETE!", "You got: " .. d.got, T.green)
			c.sound2D(c.S.Coins, 0.6, 1)
		end
	end)
end

return M
