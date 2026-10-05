-- BlockRise Empire - trading UI: player list, trade requests and the trade window
local RS = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Company = require(RS.Shared:WaitForChild("Company"))
local K = require(RS.Shared:WaitForChild("MenuKit"))

local M = {}
local c
local UI, T, new, Config
local GREEN1, GREEN2 = Color3.fromRGB(120, 226, 140), Color3.fromRGB(36, 160, 78)
local ROW = Color3.fromRGB(236, 238, 252)

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
	K.banner(c.content, 1, { name = "SAFE TRADING", line = "Both press READY, then a 5 second countdown. Any change cancels it. Cash fee 5%.", icon = "trade",
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
	if data.log and #data.log > 0 then
		K.section(c.content, 50, "YOUR LAST TRADES", Color3.fromRGB(170, 245, 180))
		local n = 0
		for i = #data.log, math.max(1, #data.log - 4), -1 do
			local e = data.log[i]
			n += 1
			K.row(c.content, 50 + n, { name = "Got: " .. e.got, line = "Gave: " .. e.gave, icon = "trade", color = GREEN2, height = 84 })
		end
	end
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
---------------------------------------------------------------------------
local win -- { gui, ... }
local lastView

local function closeWindow()
	if win then win.gui:Destroy() win = nil end
	lastView = nil
end

local function itemList()
	local list = {}
	for _, m in ipairs(Company.Materials) do table.insert(list, { kind = "mat", id = m.id, name = m.name, icon = m.icon, color = m.color, attr = "Mat_" .. m.id }) end
	for _, b in ipairs(Company.Blueprints) do table.insert(list, { kind = "bp", id = b.id, name = b.name, icon = b.icon, color = b.color, attr = "BP_" .. b.id }) end
	return list
end

local function offerLines(o)
	local lines = {}
	for _, m in ipairs(Company.Materials) do if (o.mats[m.id] or 0) > 0 then table.insert(lines, { m.icon, m.name, o.mats[m.id] }) end end
	for _, b in ipairs(Company.Blueprints) do if (o.bps[b.id] or 0) > 0 then table.insert(lines, { b.icon, b.name, o.bps[b.id] }) end end
	if (o.cash or 0) > 0 then table.insert(lines, { "💵", "Cash", Config.FormatMoney(o.cash) }) end
	return lines
end

local function lineRow(parent, order, h)
	local f = new("Frame", { Size = UDim2.new(1, 0, 0, h or 50), BackgroundTransparency = 1, LayoutOrder = order, Parent = parent })
	UI.slice("tile", { Name = "Bg", ImageColor3 = ROW, SliceScale = 0.36, ZIndex = 1, Parent = f })
	return f
end

local function render(v)
	lastView = v
	if not win then return end
	local me = tostring(c.player.UserId)
	local themId = (tostring(v.a) == me) and tostring(v.b) or tostring(v.a)
	local myOffer = v.offers[me] or { mats = {}, bps = {}, cash = 0 }
	local theirOffer = v.offers[themId] or { mats = {}, bps = {}, cash = 0 }
	win.title.Text = "Trade with " .. ((tostring(v.a) == me) and v.bName or v.aName)
	-- my side: steppers
	for _, row in ipairs(win.rows) do
		local have = c.player:GetAttribute(row.it.attr) or 0
		local offered = (row.it.kind == "mat" and myOffer.mats[row.it.id] or myOffer.bps[row.it.id]) or 0
		row.count.Text = tostring(offered)
		row.have.Text = "have " .. Config.FormatNum(have)
		row.frame.Visible = have > 0 or offered > 0
	end
	if not win.cashBox:IsFocused() then win.cashBox.Text = (myOffer.cash or 0) > 0 and tostring(myOffer.cash) or "" end
	-- their side
	for _, ch in ipairs(win.theirList:GetChildren()) do if ch:IsA("Frame") then ch:Destroy() end end
	local lines = offerLines(theirOffer)
	if #lines == 0 then
		local f = new("Frame", { Size = UDim2.new(1, 0, 0, 44), BackgroundTransparency = 1, Parent = win.theirList })
		K.text({ Size = UDim2.fromScale(1, 1), Text = "Nothing yet...", TextSize = 18, TextColor3 = K.SUB, TextXAlignment = Enum.TextXAlignment.Center, Parent = f })
	end
	for i, l in ipairs(lines) do
		local f = lineRow(win.theirList, i, 50)
		K.text({ Position = UDim2.fromOffset(12, 0), Size = UDim2.fromOffset(32, 50), Text = l[1], TextSize = 24, Parent = f })
		K.text({ Position = UDim2.fromOffset(50, 0), Size = UDim2.new(1, -150, 1, 0), Text = l[2], TextSize = 18, Max = 18, Parent = f })
		K.text({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -14, 0, 0), Size = UDim2.fromOffset(90, 50), Text = tostring(l[3]), Font = T.chunky, TextSize = 20,
			TextXAlignment = Enum.TextXAlignment.Right, Parent = f })
	end
	-- ready states
	local meReady, themReady = v.ready[me], v.ready[themId]
	UI.recolor(win.myReady, meReady and K.GREEN or K.LOCK)
	win.myReady.Label.Text = meReady and "✔ READY" or "NOT READY"
	UI.recolor(win.theirReady, themReady and K.GREEN or K.LOCK)
	win.theirReady.Label.Text = themReady and "✔ READY" or "NOT READY"
	local lbl = win.readyBtn:FindFirstChild("Label")
	if lbl then lbl.Text = meReady and "UNREADY" or "READY" end
	UI.recolor(win.readyBtn, meReady and Color3.fromRGB(255, 170, 40) or K.GREEN)
	win.countdownEnds = v.countdown and (os.clock() + v.countdown) or nil
end

local function openWindow(v)
	closeWindow()
	local pg = c.player:WaitForChild("PlayerGui")
	local gui = new("ScreenGui", { Name = "TradeWindow", ResetOnSpawn = false, DisplayOrder = 40, IgnoreGuiInset = true, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, Parent = pg })
	local dim = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.5, Active = true, Parent = gui })
	local panel, x, title = K.window(dim, UDim2.fromOffset(840, 540), "Trade", GREEN1, GREEN2, "trade")
	local fit = math.clamp(math.min(c.camera.ViewportSize.X / 900, (c.camera.ViewportSize.Y - 60) / 620), 0.5, 1.15)
	new("UIScale", { Scale = fit, Parent = panel })
	x.Activated:Connect(function() c.click(); invoke("cancel") end)

	local function column(xpos, text)
		local col = new("Frame", { Position = UDim2.new(xpos, xpos == 0 and 18 or 6, 0, 62), Size = UDim2.new(0.5, -24, 1, -170), BackgroundTransparency = 1, ZIndex = 5, Parent = panel })
		UI.slice("tile", { Name = "Bg", ImageColor3 = K.TILE, ZIndex = 1, Parent = col })
		K.text({ Position = UDim2.fromOffset(16, 8), Size = UDim2.new(1, -170, 0, 36), Text = text, Font = T.chunky, TextSize = 24, Max = 24, TextColor3 = K.DARK, Parent = col })
		local ready = UI.button("NOT READY", K.LOCK, nil, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 8), Size = UDim2.fromOffset(140, 38), TextSize = 16, ZIndex = 4, Parent = col })
		ready.Active = false
		local list = new("ScrollingFrame", { Position = UDim2.fromOffset(12, 54), Size = UDim2.new(1, -24, 1, -66), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 4,
			ScrollBarImageColor3 = Color3.fromRGB(150, 150, 200), CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollingDirection = Enum.ScrollingDirection.Y, ZIndex = 3, Parent = col })
		UI.list(Enum.FillDirection.Vertical, 6).Parent = list
		return list, ready
	end
	local myList, myReady = column(0, "YOU GIVE")
	local theirList, theirReady = column(0.5, "YOU GET")

	local rows = {}
	for i, it in ipairs(itemList()) do
		local f = lineRow(myList, i, 52)
		K.text({ Position = UDim2.fromOffset(10, 0), Size = UDim2.fromOffset(32, 52), Text = it.icon, TextSize = 24, Parent = f })
		K.text({ Position = UDim2.fromOffset(46, 5), Size = UDim2.new(1, -206, 0, 24), Text = it.name, TextSize = 17, Max = 17, Parent = f })
		local have = K.text({ Position = UDim2.fromOffset(46, 27), Size = UDim2.new(1, -206, 0, 18), Text = "", TextSize = 13, TextColor3 = K.SUB, Parent = f })
		local minus = UI.button("-", K.LOCK, nil, { Position = UDim2.new(1, -156, 0, 7), Size = UDim2.fromOffset(38, 38), TextSize = 22, ZIndex = 4, Parent = f })
		local count = K.text({ Position = UDim2.new(1, -116, 0, 0), Size = UDim2.fromOffset(36, 52), Text = "0", Font = T.chunky, TextSize = 20, TextXAlignment = Enum.TextXAlignment.Center, Parent = f })
		local plus = UI.button("+", K.GREEN, nil, { Position = UDim2.new(1, -80, 0, 7), Size = UDim2.fromOffset(34, 38), TextSize = 22, ZIndex = 4, Parent = f })
		local plus10 = UI.button("+10", K.GREEN, nil, { Position = UDim2.new(1, -44, 0, 7), Size = UDim2.fromOffset(38, 38), TextSize = 14, ZIndex = 4, Parent = f })
		local function change(delta)
			c.click()
			local cur = tonumber(count.Text) or 0
			local ok, msg = invoke("set", it.kind, it.id, math.max(0, cur + delta))
			if not ok then c.toast("⚠️ " .. tostring(msg), T.red) end
		end
		minus.Activated:Connect(function() change(-1) end)
		plus.Activated:Connect(function() change(1) end)
		plus10.Activated:Connect(function() change(10) end)
		table.insert(rows, { it = it, frame = f, count = count, have = have })
	end
	local cashRow = lineRow(myList, 100, 54)
	K.text({ Position = UDim2.fromOffset(12, 0), Size = UDim2.fromOffset(100, 54), Text = "💵 Cash", TextSize = 18, Parent = cashRow })
	local field = UI.slice("tile", { ImageColor3 = Color3.fromRGB(74, 78, 166), Position = UDim2.fromOffset(110, 8), Size = UDim2.new(1, -122, 0, 38), SliceScale = 0.36, ZIndex = 2, Parent = cashRow })
	local cashBox = new("TextBox", { Position = UDim2.fromOffset(12, 0), Size = UDim2.new(1, -24, 1, 0), BackgroundTransparency = 1, Text = "", PlaceholderText = "0 (5% fee)",
		Font = T.body, TextSize = 18, TextColor3 = Color3.new(1, 1, 1), PlaceholderColor3 = Color3.fromRGB(200, 205, 240), TextXAlignment = Enum.TextXAlignment.Left,
		ClearTextOnFocus = false, ZIndex = 3, Parent = field })
	cashBox.FocusLost:Connect(function()
		local n = tonumber((cashBox.Text:gsub("[^%d]", ""))) or 0
		local ok, msg = invoke("set", "cash", "cash", n)
		if not ok then c.toast("⚠️ " .. tostring(msg), T.red) end
	end)

	-- bottom bar: status + READY
	local bar = new("Frame", { AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 18, 1, -16), Size = UDim2.new(1, -36, 0, 80), BackgroundTransparency = 1, ZIndex = 5, Parent = panel })
	UI.slice("tile", { Name = "Bg", ImageColor3 = K.TILE, ZIndex = 1, Parent = bar })
	local status = K.text({ Position = UDim2.fromOffset(18, 10), Size = UDim2.new(1, -270, 0, 30), Text = "", TextSize = 22, Max = 22, Parent = bar })
	K.text({ Position = UDim2.fromOffset(18, 42), Size = UDim2.new(1, -270, 0, 24), Text = "Check what you get before READY. Any change cancels READY.", TextSize = 15, Max = 15,
		TextColor3 = K.SUB, Parent = bar })
	local readyBtn = UI.button("READY", K.GREEN, nil, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -14, 0.5, 0), Size = UDim2.fromOffset(230, 58), TextSize = 26,
		ZIndex = 4, Shine = true, Parent = bar })
	readyBtn.Activated:Connect(function()
		c.click()
		local me = tostring(c.player.UserId)
		local on = not (lastView and lastView.ready[me])
		local ok, msg = invoke("ready", on)
		if not ok then c.toast("⚠️ " .. tostring(msg), T.red) end
	end)
	win = { gui = gui, title = title, rows = rows, cashBox = cashBox, theirList = theirList, myReady = myReady, theirReady = theirReady, readyBtn = readyBtn, status = status }
	-- status line / countdown
	local conn
	conn = RunService.RenderStepped:Connect(function()
		if not win or win.gui ~= gui then conn:Disconnect() return end
		if win.countdownEnds then
			local left = math.max(0, math.ceil(win.countdownEnds - os.clock()))
			status.Text = "Trading in " .. left .. "..."
			status.TextColor3 = Color3.fromRGB(225, 110, 10)
		else
			status.Text = "Both players press READY"
			status.TextColor3 = K.DARK
		end
	end)
	render(v)
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
