-- BlockRise Empire - main HUD (kept light on purpose)
--   top: Roblox's own top bar row, edge to edge: a big construction progress bar, the Empire Road goal, the City Tower
--   left: money, gems, Strength + eight menu buttons   right: Store, Gift, More   bottom-left: level + XP
-- The middle of the screen stays free for playing.
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Icons = require(RS.Shared:WaitForChild("Icons"))
local Company = require(RS.Shared:WaitForChild("Company"))

local M = {}
local c, UI, T, new, Config, player, gui

local INK = Color3.fromRGB(20, 17, 32)
local WHITE = Color3.new(1, 1, 1)
local BIG = Enum.Font.LuckiestGuy
local ROUND = Enum.Font.FredokaOne
local PANEL1, PANEL2 = Color3.fromRGB(62, 56, 100), Color3.fromRGB(33, 29, 56)

---------------------------------------------------------------------------
-- building blocks
---------------------------------------------------------------------------
local function corner(o, r) return new("UICorner", { CornerRadius = UDim.new(0, r), Parent = o }) end
local function stroke(o, th, col, tr)
	return new("UIStroke", { Thickness = th or 3, Color = col or INK, Transparency = tr or 0,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border, LineJoinMode = Enum.LineJoinMode.Round, Parent = o })
end
local function tstroke(l, th)
	return new("UIStroke", { Thickness = th or 2.5, Color = INK, LineJoinMode = Enum.LineJoinMode.Round,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual, Parent = l })
end
local function grad(o, c1, c2, rot) return new("UIGradient", { Color = ColorSequence.new(c1, c2), Rotation = rot or 90, Parent = o }) end

local function text(props)
	local l = new("TextLabel", { BackgroundTransparency = 1, Font = BIG, TextColor3 = WHITE, TextSize = 20,
		TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Center, RichText = true })
	for k, v in pairs(props) do if k ~= "Parent" then l[k] = v end end
	l.Parent = props.Parent
	return l
end

-- dark glass card with a thick ink border and a thin light rim inside
local function panel(props, r)
	r = r or 16
	local f = new("Frame", { BackgroundColor3 = WHITE, BorderSizePixel = 0 })
	for k, v in pairs(props) do if k ~= "Parent" then f[k] = v end end
	corner(f, r)
	grad(f, PANEL1, PANEL2)
	stroke(f, 3)
	local rim = new("Frame", { Name = "Rim", Position = UDim2.fromOffset(3, 3), Size = UDim2.new(1, -6, 1, -6), BackgroundTransparency = 1, Parent = f })
	corner(rim, math.max(2, r - 3))
	stroke(rim, 1.5, WHITE, 0.84)
	f.Parent = props.Parent
	return f
end

local function progress(parent, props, c1, c2)
	local bg = new("Frame", { BackgroundColor3 = Color3.fromRGB(14, 12, 26), BorderSizePixel = 0 })
	for k, v in pairs(props) do bg[k] = v end
	corner(bg, 99)
	stroke(bg, 2)
	local fill = new("Frame", { Name = "Fill", Size = UDim2.fromScale(0, 1), BackgroundColor3 = WHITE, BorderSizePixel = 0, Parent = bg })
	corner(fill, 99)
	grad(fill, c1, c2)
	local shine = new("Frame", { Position = UDim2.new(0, 4, 0, 2), Size = UDim2.new(1, -8, 0.38, 0), BackgroundColor3 = WHITE,
		BackgroundTransparency = 0.62, BorderSizePixel = 0, Parent = fill })
	corner(shine, 99)
	bg.Parent = parent
	return bg, fill
end

local function setFill(fill, f)
	f = math.clamp(f or 0, 0, 1)
	fill.Visible = f > 0.001
	fill.Size = UDim2.fromScale(math.max(f, 0.04), 1)
end

-- the chunky "simulator" button: gradient face sitting on a darker base, gloss, icon, label, badge
local pulsing = {}
local function bigButton(parent, key, label, c1, c2, w, h, onClick)
	local faceH = h - 12
	local b = new("TextButton", { Name = label, BackgroundTransparency = 1, Text = "", AutoButtonColor = false,
		Size = UDim2.fromOffset(w, h), Parent = parent })
	local sc = new("UIScale", { Parent = b })
	local base = new("Frame", { Name = "Base", Position = UDim2.fromOffset(0, 6), Size = UDim2.new(1, 0, 0, faceH),
		BackgroundColor3 = c2:Lerp(INK, 0.4), BorderSizePixel = 0, Parent = b })
	corner(base, 20)
	stroke(base, 3)
	local face = new("Frame", { Name = "Face", Size = UDim2.new(1, 0, 0, faceH), BackgroundColor3 = WHITE, BorderSizePixel = 0, Parent = b })
	corner(face, 20)
	local faceGrad = grad(face, c1, c2)
	stroke(face, 3)
	local gloss = new("Frame", { Position = UDim2.fromOffset(6, 5), Size = UDim2.new(1, -12, 0.42, 0), BackgroundColor3 = WHITE,
		BackgroundTransparency = 0.55, BorderSizePixel = 0, Parent = face })
	corner(gloss, 14)
	new("UIGradient", { Transparency = NumberSequence.new(0.2, 1), Rotation = 90, Parent = gloss })
	local ic = Icons.make(key, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.45), Size = UDim2.fromScale(0.84, 0.84), Parent = face })
	local lbl = text({ Name = "Label", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, 0), Size = UDim2.new(1, 4, 0, 24),
		Text = label, TextScaled = true, TextXAlignment = Enum.TextXAlignment.Center, Parent = b })
	tstroke(lbl, 3)
	new("UITextSizeConstraint", { MaxTextSize = 21, MinTextSize = 9, Parent = lbl })
	-- the red circle breathes; the number on it stays still (a scaled number drifts off the centre by a pixel or two)
	local badge = new("Frame", { Name = "Badge", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(1, -7, 0, 7), Size = UDim2.fromOffset(28, 28),
		BackgroundTransparency = 1, Visible = false, ZIndex = 5, Parent = b })
	local dot = new("Frame", { Name = "Dot", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(255, 52, 84), BorderSizePixel = 0, ZIndex = 5, Parent = badge })
	corner(dot, 14)
	stroke(dot, 2.5)
	local bsc = new("UIScale", { Parent = dot })
	-- FredokaOne: its glyphs sit in the middle of the line (Luckiest Guy leans and rides high, so "!" looked off-centre)
	local bl = text({ Size = UDim2.fromScale(1, 1), Text = "1", Font = ROUND, TextSize = 18, TextXAlignment = Enum.TextXAlignment.Center,
		TextYAlignment = Enum.TextYAlignment.Center, ZIndex = 6, Parent = badge })
	tstroke(bl, 1.5)
	local down = false
	local hasBadge = false
	b.MouseEnter:Connect(function() b.ZIndex = 3; UI.tween(sc, 0.12, { Scale = 1.06 }) end)
	b.MouseLeave:Connect(function()
		b.ZIndex = hasBadge and 2 or 1
		UI.tween(sc, 0.12, { Scale = 1 })
		down = false
		UI.tween(face, 0.1, { Position = UDim2.new() })
	end)
	b.MouseButton1Down:Connect(function()
		down = true
		UI.tween(face, 0.05, { Position = UDim2.fromOffset(0, 5) })
	end)
	b.MouseButton1Up:Connect(function()
		down = false
		UI.tween(face, 0.18, { Position = UDim2.new() }, Enum.EasingStyle.Back)
	end)
	b.Activated:Connect(function()
		c.click()
		face.Position = UDim2.new()
		if onClick then onClick() end
	end)
	local api = { button = b, face = face, icon = ic, label = lbl }
	-- tutorial lock: the button turns grey with a small padlock on its corner; unlocking plays an animation
	-- (the padlock shakes, its shackle pops open, it flies off and the colours fill back in with a sparkle burst)
	local GREY1, GREY2 = Color3.fromRGB(178, 182, 200), Color3.fromRGB(104, 108, 136)
	local pics = {}
	for _, d in ipairs(ic:GetDescendants()) do if d:IsA("ImageLabel") then table.insert(pics, d) end end
	if ic:IsA("ImageLabel") then table.insert(pics, ic) end
	local function paint(t) -- 0 = grey (locked) .. 1 = the button's own colours
		faceGrad.Color = ColorSequence.new(GREY1:Lerp(c1, t), GREY2:Lerp(c2, t))
		base.BackgroundColor3 = GREY2:Lerp(INK, 0.4):Lerp(c2:Lerp(INK, 0.4), t)
		for _, im in ipairs(pics) do
			im.ImageColor3 = Color3.fromRGB(150, 152, 168):Lerp(WHITE, t)
			im.ImageTransparency = 0.25 * (1 - t)
		end
		lbl.TextColor3 = Color3.fromRGB(205, 207, 220):Lerp(WHITE, t)
	end
	local lock
	local function padlock()
		local g = new("CanvasGroup", { Name = "Lock", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(1, -8, 0, 8), Size = UDim2.fromOffset(40, 44),
			BackgroundTransparency = 1, ZIndex = 7, Parent = b })
		-- shackle: an ink ring with a steel ring inside; its lower half hides behind the body
		local sh = new("Frame", { Name = "Shackle", Position = UDim2.fromOffset(9, 3), Size = UDim2.fromOffset(22, 26), BackgroundTransparency = 1, ZIndex = 7, Parent = g })
		local ink = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 7, Parent = sh })
		corner(ink, 11)
		new("UIStroke", { Thickness = 8, Color = INK, Parent = ink })
		local steel = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 8, Parent = sh })
		corner(steel, 11)
		new("UIStroke", { Thickness = 4, Color = Color3.fromRGB(214, 218, 232), Parent = steel })
		-- body: gold with a keyhole and a little gloss
		local body = new("Frame", { Name = "Body", Position = UDim2.fromOffset(4, 18), Size = UDim2.fromOffset(32, 23), BackgroundColor3 = WHITE, BorderSizePixel = 0, ZIndex = 9, Parent = g })
		corner(body, 7)
		grad(body, Color3.fromRGB(255, 222, 96), Color3.fromRGB(232, 146, 26))
		stroke(body, 2.5)
		local gl = new("Frame", { Position = UDim2.fromOffset(4, 3), Size = UDim2.new(1, -8, 0, 6), BackgroundColor3 = WHITE, BackgroundTransparency = 0.45, BorderSizePixel = 0, ZIndex = 10, Parent = body })
		corner(gl, 3)
		local hole = new("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 7), Size = UDim2.fromOffset(7, 7), BackgroundColor3 = Color3.fromRGB(70, 42, 18), BorderSizePixel = 0, ZIndex = 10, Parent = body })
		corner(hole, 4)
		new("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 11), Size = UDim2.fromOffset(3, 7), BackgroundColor3 = Color3.fromRGB(70, 42, 18), BorderSizePixel = 0, ZIndex = 10, Parent = body })
		return { group = g, shackle = sh }
	end
	-- little stars that fly out of the button when it unlocks
	local function burst()
		for i = 1, 10 do
			local a = (i / 10) * math.pi * 2 + math.random() * 0.4
			local st = new("TextLabel", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.45), Size = UDim2.fromOffset(22, 22), BackgroundTransparency = 1,
				Text = "✦", Font = BIG, TextSize = 18 + math.random(0, 8), TextColor3 = (i % 2 == 0) and Color3.fromRGB(255, 236, 120) or WHITE, ZIndex = 9, Parent = b })
			tstroke(st, 1.5)
			local d = 46 + math.random(0, 18)
			UI.tween(st, 0.55, { Position = UDim2.new(0.5, math.cos(a) * d, 0.45, math.sin(a) * d), TextTransparency = 1, Rotation = math.random(-90, 90) })
			task.delay(0.6, function() st:Destroy() end)
		end
	end
	-- a light band sweeps across the face
	local function sweep()
		local holder = new("CanvasGroup", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 6, Parent = face })
		corner(holder, 20)
		local band = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = WHITE, BackgroundTransparency = 0.2, BorderSizePixel = 0, Parent = holder })
		local g = new("UIGradient", { Rotation = 20, Offset = Vector2.new(-1, 0), Parent = band,
			Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.4, 1), NumberSequenceKeypoint.new(0.5, 0.05),
				NumberSequenceKeypoint.new(0.6, 1), NumberSequenceKeypoint.new(1, 1) }) })
		UI.tween(g, 0.6, { Offset = Vector2.new(1, 0) })
		task.delay(0.65, function() holder:Destroy() end)
	end
	function api.setLocked(on, animate)
		if on then
			if lock then return end
			paint(0)
			lock = padlock()
			return
		end
		if not lock then return end
		local L = lock
		lock = nil
		if not animate then
			L.group:Destroy()
			paint(1)
			return
		end
		task.spawn(function()
			-- shake
			for i = 1, 6 do
				L.group.Rotation = ((i % 2 == 0) and -16 or 16) * (1 - i / 7)
				task.wait(0.05)
			end
			L.group.Rotation = 0
			-- the shackle pops open
			UI.tween(L.shackle, 0.2, { Position = L.shackle.Position + UDim2.fromOffset(4, -9), Rotation = 18 }, Enum.EasingStyle.Back)
			if c.sound2D and c.S then c.sound2D(c.S.Click, 0.7, 1.5) end
			task.wait(0.28)
			-- the padlock flies off, the button fills with its colours
			UI.tween(L.group, 0.45, { Position = L.group.Position + UDim2.fromOffset(14, -30), GroupTransparency = 1, Rotation = 30 })
			local v = new("NumberValue", { Value = 0 })
			v.Changed:Connect(paint)
			UI.tween(v, 0.55, { Value = 1 })
			sc.Scale = 1.3
			UI.tween(sc, 0.55, { Scale = 1 }, Enum.EasingStyle.Back)
			burst()
			sweep()
			if c.sound2D and c.S then c.sound2D(c.S.Chime, 0.6, 1.25) end
			task.wait(0.6)
			v:Destroy()
			L.group:Destroy()
			paint(1)
		end)
	end
	function api.isLocked() return lock ~= nil end
	function api.nudge()
		if not lock then return end
		local g = lock.group
		task.spawn(function()
			for i = 1, 5 do
				g.Rotation = ((i % 2 == 0) and -14 or 14) * (1 - i / 6)
				task.wait(0.04)
			end
			g.Rotation = 0
		end)
	end
	-- always a number (true = 1), never a "!"; over 9 it says +9
	function api.setBadge(v)
		local n = v == true and 1 or (tonumber(v) or 0)
		local on = n > 0
		badge.Visible = on
		hasBadge = on
		if b.ZIndex < 3 then b.ZIndex = on and 2 or 1 end
		pulsing[bsc] = on or nil
		if on then UI.badgeText(bl, n) end
	end
	function api.setLabel(t) lbl.Text = t end
	-- a small dark pill on the top-right corner (a timer: when the next free spin comes...)
	local cornerPill, cornerLbl
	function api.setCorner(t)
		if not t or t == "" then
			if cornerPill then cornerPill.Visible = false end
			return
		end
		if not cornerPill then
			cornerPill = new("Frame", { Name = "Corner", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 2, 0, -8), Size = UDim2.fromOffset(0, 22),
				AutomaticSize = Enum.AutomaticSize.X, BackgroundColor3 = WHITE, BorderSizePixel = 0, ZIndex = 6, Parent = b })
			corner(cornerPill, 11)
			grad(cornerPill, PANEL1, PANEL2)
			stroke(cornerPill, 2)
			new("UIPadding", { PaddingLeft = UDim.new(0, 7), PaddingRight = UDim.new(0, 7), Parent = cornerPill })
			cornerLbl = text({ Size = UDim2.fromOffset(0, 22), AutomaticSize = Enum.AutomaticSize.X, Font = ROUND, TextSize = 13, Text = "", ZIndex = 7, Parent = cornerPill })
			tstroke(cornerLbl, 1.5)
		end
		cornerPill.Visible = true
		cornerLbl.Text = t
	end
	return api
end

local function pill(parent, key, width, color)
	local f = panel({ Size = UDim2.fromOffset(width, 40), Parent = parent }, 20)
	-- the icon sits inside the pill (a little bigger than the pill's height, never past its left edge)
	local ic = Icons.make(key, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(25, 19), Size = UDim2.fromOffset(46, 46), ZIndex = 3, Parent = f })
	local val = text({ Name = "Value", Position = UDim2.fromOffset(52, 0), Size = UDim2.new(1, -100, 1, 0), Text = "0", TextSize = 23,
		TextColor3 = color, TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 3, Parent = f })
	tstroke(val, 2.5)
	local sc = new("UIScale", { Parent = val })
	return f, val, sc, ic
end

local function plusButton(parent, onClick)
	local b = new("TextButton", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0), Size = UDim2.fromOffset(30, 30),
		BackgroundColor3 = WHITE, Text = "", AutoButtonColor = false, ZIndex = 4, Parent = parent })
	corner(b, 11)
	grad(b, Color3.fromRGB(110, 236, 120), Color3.fromRGB(36, 168, 78))
	stroke(b, 2.5)
	local l = text({ Size = UDim2.fromScale(1, 1), Position = UDim2.fromOffset(0, 1), Text = "+", TextSize = 23, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 5, Parent = b })
	tstroke(l, 2)
	local sc = new("UIScale", { Parent = b })
	b.MouseButton1Down:Connect(function() UI.tween(sc, 0.06, { Scale = 0.9 }) end)
	b.MouseButton1Up:Connect(function() UI.tween(sc, 0.15, { Scale = 1 }, Enum.EasingStyle.Back) end)
	b.MouseLeave:Connect(function() UI.tween(sc, 0.1, { Scale = 1 }) end)
	b.Activated:Connect(function() c.click(); onClick() end)
	return b
end

local function bounce(sc, s)
	sc.Scale = s or 1.18
	UI.tween(sc, 0.32, { Scale = 1 }, Enum.EasingStyle.Back)
end

local function fmtTime(s)
	s = math.max(0, math.floor(s))
	if s >= 3600 then return string.format("%dh %02dm", s // 3600, (s % 3600) // 60) end
	return string.format("%d:%02d", s // 60, s % 60)
end
local function short(n) return n >= 1e4 and Config.Short(n) or Config.FormatNum(math.floor(n)) end

---------------------------------------------------------------------------
-- init
---------------------------------------------------------------------------
function M.Init(ctx)
	c = ctx
	UI, T, new, Config, player, gui = c.UI, c.T, c.new, c.Config, c.player, c.gui
	local camera = c.camera
	local GuiService = game:GetService("GuiService")

	local root = new("Frame", { Name = "HUD2", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 2, Parent = gui })
	-- the top strip lives in Roblox's top bar row, so it gets its own layer that ignores the top bar inset
	-- (one layer below the HUD, so an open window's dark backdrop covers it too)
	gui.DisplayOrder = math.max(gui.DisplayOrder, 1)
	local topGui = new("ScreenGui", { Name = "TopStrip", IgnoreGuiInset = true, ResetOnSpawn = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = gui.DisplayOrder - 1, Parent = gui.Parent })

	-- tutorial: JOBS, SHOP and the contract bar stay locked until the first Empire Road steps are done
	-- (walk to the Job Board, build the first building, Equipment Store, Hiring Office, your property)
	local menu
	local function tutorialDone()
		local rs = player:GetAttribute("RoadStep")
		return rs ~= nil and rs > (Config.TutorialSteps or 6)
	end
	local function lockedToast(which)
		c.toast("🔒 Complete the tutorial first — follow the arrow!", T.muted, 2.5)
		if which and menu and menu[which] then menu[which].nudge() end
	end

	-- actions ----------------------------------------------------------------
	local A = {}
	local function toggle(name, fn) if fn then _G.__CE_Toggle(name, fn) end end
	function A.jobs()
		if not tutorialDone() then lockedToast("jobs") return end
		-- after your first contract the Job Board opens from anywhere
		if (player:GetAttribute("Completed") or 0) >= 1 and _G.__CE_ShowContracts then
			toggle("Contracts", _G.__CE_ShowContracts)
		else
			c.setWaypoint("board")
		end
	end
	function A.shop()
		if not tutorialDone() then lockedToast("shop") return end
		toggle("Shop", c.showShop)
	end
	function A.upgrades() toggle("Upgrades", c.showUpgrades) end
	function A.inventory() toggle("Inventory", c.showInventory) end
	function A.cars() toggle("Garage", _G.__CE_ShowGarage) end
	function A.company() toggle("Company", _G.__CE_ShowCompany) end
	function A.rebirth() toggle("Rebirth", c.showRebirth) end
	function A.locations() toggle("Locations", c.showLocations) end
	function A.store(tab) if tab then _G.__CE_ShowStore(tab) else toggle("Store", _G.__CE_ShowStore) end end
	function A.daily() toggle("Missions", _G.__CE_ShowMissions) end
	function A.spin() toggle("Spin", _G.__CE_ShowSpin) end
	function A.gift()
		local i, _, left = c.playtime.Next()
		if i and left <= 0 then c.playtime.Claim(i) else toggle("Gifts", c.playtime.Show) end
	end
	function A.go(place) if c.go then c.go(place) end end
	c.actions = A

	-- where an Empire Road goal is done: open the right window, or take you there
	local function goPlace(place)
		if not place then return end
		-- after your first building the Job Board opens from anywhere: no walking back to it
		if place == "board" and (player:GetAttribute("Completed") or 0) >= 1 and tutorialDone() then A.jobs() return end
		local tutorial = (player:GetAttribute("RoadStep") or 1) <= Config.RoadTutorialSteps
		if place == "site" then
			if (player:GetAttribute("ContractJob") or "") == "" then A.jobs() else A.go("site") end
		elseif tutorial then
			c.setWaypoint(place)
		elseif place == "shop" then A.shop()
		elseif place == "hire" then c.showHire()
		elseif place == "company" then A.company()
		elseif place == "rebirth" then A.rebirth()
		elseif place == "upgrades" then A.upgrades()
		elseif place == "board" then A.jobs()
		elseif place == "garage" then toggle("Garage", _G.__CE_ShowGarage)
		else A.go(place) end
	end

	---------------------------------------------------------------------------
	-- TOP ROW: in Roblox's own top bar, from the Roblox buttons to the right edge
	--   [ big construction progress bar ......................... ] [ Empire Road goal ] [ City Tower ]
	---------------------------------------------------------------------------
	local row = new("Frame", { Name = "Row", BackgroundTransparency = 1, Size = UDim2.fromOffset(800, 44), Parent = topGui })
	local function chip(name)
		local f = panel({ Name = name, Size = UDim2.fromOffset(100, 44), Parent = row }, 14)
		local b = new("TextButton", { Name = "Hit", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "", AutoButtonColor = false, ZIndex = 6, Parent = f })
		-- the top chips never move or change size (hover / hold / tap only light them up a little),
		-- so nothing slides away from the mouse, like the abandon X on the corner
		local hl = new("Frame", { Name = "Hover", Size = UDim2.fromScale(1, 1), BackgroundColor3 = WHITE, BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 3, Parent = f })
		corner(hl, 14)
		local over = false
		b.MouseEnter:Connect(function() over = true; UI.tween(hl, 0.12, { BackgroundTransparency = 0.9 }) end)
		b.MouseLeave:Connect(function() over = false; UI.tween(hl, 0.12, { BackgroundTransparency = 1 }) end)
		b.MouseButton1Down:Connect(function() UI.tween(hl, 0.05, { BackgroundTransparency = 0.82 }) end)
		b.MouseButton1Up:Connect(function() UI.tween(hl, 0.15, { BackgroundTransparency = over and 0.9 or 1 }) end)
		return f, b
	end

	-- 1) construction: the whole chip is a progress bar that fills up as the building goes up
	local build, buildHit = chip("Build")
	local bFill = new("Frame", { Name = "Fill", Position = UDim2.fromOffset(3, 3), Size = UDim2.new(0, 0, 1, -6), BackgroundColor3 = WHITE, BorderSizePixel = 0, ZIndex = 2, Parent = build })
	corner(bFill, 11)
	grad(bFill, Color3.fromRGB(255, 214, 72), Color3.fromRGB(246, 128, 24))
	local bShine = new("Frame", { Position = UDim2.fromOffset(4, 2), Size = UDim2.new(1, -8, 0.4, 0), BackgroundColor3 = WHITE, BackgroundTransparency = 0.55, BorderSizePixel = 0, ZIndex = 2, Parent = bFill })
	corner(bShine, 8)
	new("UIGradient", { Transparency = NumberSequence.new(0.2, 1), Rotation = 90, Parent = bShine })
	local bIcon = Icons.make("contract", { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, -2, 0.5, 0), Size = UDim2.fromOffset(52, 52), ZIndex = 4, Parent = build })
	local bText = text({ Position = UDim2.fromOffset(52, 0), Size = UDim2.new(1, -150, 1, 0), TextSize = 19, TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 4, Text = "", Parent = build })
	tstroke(bText, 2.5)
	local bPct = text({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 0), Size = UDim2.fromOffset(90, 44), TextSize = 22, TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 4, Text = "", Parent = build })
	tstroke(bPct, 2.5)
	local bBonus = text({ AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -78, 0.5, 0), Size = UDim2.fromOffset(110, 20), Font = ROUND, TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 4, Text = "", Parent = build })
	tstroke(bBonus, 2)
	-- abandon: a small X hanging off the chip's corner, two taps
	local cX = new("TextButton", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(1, -2, 0, 4), Size = UDim2.fromOffset(20, 20), BackgroundColor3 = WHITE,
		Text = "", AutoButtonColor = false, Visible = false, ZIndex = 8, Parent = build })
	corner(cX, 10)
	grad(cX, Color3.fromRGB(255, 110, 110), Color3.fromRGB(205, 45, 60))
	stroke(cX, 2)
	local cXl = text({ Size = UDim2.fromScale(1, 1), Text = "X", TextSize = 11, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 9, Parent = cX })
	tstroke(cXl, 1.5)
	local cXstroke = cX:FindFirstChildOfClass("UIStroke") -- glows after the first tap: tap the same X again
	local confirmUntil = 0
	cX.Activated:Connect(function()
		c.click()
		if os.clock() < confirmUntil then
			confirmUntil = 0
			pcall(function() c.R.Abandon:InvokeServer() end)
		else
			confirmUntil = os.clock() + 2.5
			c.toast("Tap the red X again to abandon this contract", T.muted, 2.5)
		end
	end)
	buildHit.Activated:Connect(function()
		c.click()
		if not tutorialDone() then lockedToast() return end
		if c.legacyJob.panel.Visible then A.go("site") else A.jobs() end
	end)

	-- 2) Empire Road goal
	local quest, questHit = chip("Quest")
	local qIcon = Icons.make("quest", { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, -2, 0.5, 0), Size = UDim2.fromOffset(48, 48), ZIndex = 4, Parent = quest })
	local qTitle = text({ Position = UDim2.fromOffset(46, 3), Size = UDim2.new(1, -54, 0, 20), TextSize = 15, TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 4, Text = "", Parent = quest })
	tstroke(qTitle, 2)
	local qBar, qFill = progress(quest, { Position = UDim2.new(0, 46, 1, -18), Size = UDim2.new(1, -54, 0, 12), ZIndex = 3 }, Color3.fromRGB(130, 240, 120), Color3.fromRGB(40, 175, 80))
	local qVal = text({ Size = UDim2.fromScale(1, 1), Font = ROUND, TextSize = 10, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 4, Text = "", Parent = qBar })
	tstroke(qVal, 1.5)
	local qPlace
	questHit.Activated:Connect(function() c.click(); goPlace(qPlace) end)
	local function refreshQuest()
		local i = player:GetAttribute("RoadStep") or 1
		local step = Config.Road[i]
		if not step then
			qTitle.Text = "Empire Road complete!"
			qVal.Text = ""
			setFill(qFill, 1)
			qPlace = nil
			return
		end
		qTitle.Text = step.title
		local v = player:GetAttribute("RoadValue") or 0
		setFill(qFill, v / math.max(step.target, 1))
		qVal.Text = (step.target > 1 and (short(v) .. " / " .. short(step.target) .. "   ") or "") .. "+" .. Config.FormatMoney(step.cash)
		qPlace = step.place
	end
	player:GetAttributeChangedSignal("RoadStep"):Connect(refreshQuest)
	player:GetAttributeChangedSignal("RoadValue"):Connect(refreshQuest)
	refreshQuest()

	-- 3) City Tower (only while one is being built)
	local mega, megaHit = chip("Mega")
	Icons.make("mega", { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, -2, 0.5, 0), Size = UDim2.fromOffset(48, 48), ZIndex = 4, Parent = mega })
	local mTitle = text({ Position = UDim2.fromOffset(44, 3), Size = UDim2.new(1, -50, 0, 20), TextSize = 15, ZIndex = 4, Text = "City Tower", Parent = mega })
	tstroke(mTitle, 2)
	local mBar, mFill = progress(mega, { Position = UDim2.new(0, 44, 1, -18), Size = UDim2.new(1, -52, 0, 12), ZIndex = 3 }, Color3.fromRGB(215, 170, 255), Color3.fromRGB(130, 80, 235))
	local mPct = text({ Size = UDim2.fromScale(1, 1), Font = ROUND, TextSize = 10, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 4, Text = "", Parent = mBar })
	tstroke(mPct, 1.5)
	megaHit.Activated:Connect(function() c.click(); A.go("mega") end)

	---------------------------------------------------------------------------
	-- LEFT: money, gems, Strength + the six menu buttons
	---------------------------------------------------------------------------
	local left = new("Frame", { Name = "Left", BackgroundTransparency = 1, Position = UDim2.fromOffset(12, 10), Size = UDim2.fromOffset(240, 560), Parent = root })
	local leftScale = new("UIScale", { Parent = left })
	local cashPill, cashVal, cashSc = pill(left, "cash", 236, Color3.fromRGB(150, 255, 140))
	plusButton(cashPill, function() A.store("cash") end)
	local gemPill, gemVal, gemSc, gemIc = pill(left, "gem", 236, Color3.fromRGB(130, 225, 255))
	gemPill.Position = UDim2.fromOffset(0, 46)
	gemIc.Position = UDim2.fromOffset(25, 22) -- the diamond is drawn high in its picture: centred in the pill
	plusButton(gemPill, function() A.store("gems") end)
	local strPill, strVal, strSc = pill(left, "strength", 236, Color3.fromRGB(255, 180, 110))
	strPill.Position = UDim2.fromOffset(0, 92)
	strVal.Size = UDim2.new(1, -58, 1, 0)
	local powLbl = text({ AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), Size = UDim2.fromOffset(100, 18), Font = ROUND, TextSize = 12,
		TextColor3 = Color3.fromRGB(170, 215, 255), TextXAlignment = Enum.TextXAlignment.Right, Text = "", ZIndex = 3, Parent = strPill })
	tstroke(powLbl, 1.5)

	local shownMoney = player:GetAttribute("Money") or 0
	player:GetAttributeChangedSignal("Money"):Connect(function() bounce(cashSc, 1.15) end)
	local function refreshGems()
		gemVal.Text = Config.FormatNum(player:GetAttribute("Gems") or 0)
		bounce(gemSc, 1.18)
	end
	player:GetAttributeChangedSignal("Gems"):Connect(refreshGems)
	refreshGems()
	local lastStr = 0
	local function refreshStrength()
		strVal.Text = short(player:GetAttribute("Strength") or 0)
		powLbl.Text = c.fmtMult(c.buildPower()) .. " power/hit"
		if os.clock() - lastStr > 0.15 then lastStr = os.clock(); bounce(strSc, 1.1) end
	end
	for _, a in ipairs({ "Strength", "PowerMult", "ToolTier" }) do player:GetAttributeChangedSignal(a):Connect(refreshStrength) end
	refreshStrength()

	local grid = new("Frame", { Name = "Menu", BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 146), Size = UDim2.fromOffset(176, 400), Parent = left })
	local MENU_SCALE = 0.9 -- the big menu buttons (left and right) are 10% smaller than the original design
	local gridScale = new("UIScale", { Scale = MENU_SCALE, Parent = grid })
	local gridLayout = new("UIGridLayout", { CellSize = UDim2.fromOffset(80, 88), CellPadding = UDim2.fromOffset(14, 8), SortOrder = Enum.SortOrder.LayoutOrder,
		FillDirectionMaxCells = 2, Parent = grid })
	menu = {}
	local defs = {
		{ "jobs", "JOBS", Color3.fromRGB(255, 205, 70), Color3.fromRGB(240, 130, 20), A.jobs },
		{ "shop", "SHOP", Color3.fromRGB(110, 200, 255), Color3.fromRGB(40, 110, 230), A.shop },
		{ "upgrades", "UPGRADES", Color3.fromRGB(130, 240, 120), Color3.fromRGB(30, 160, 70), A.upgrades },
		{ "rebirth", "REBIRTH", Color3.fromRGB(205, 150, 255), Color3.fromRGB(125, 65, 230), A.rebirth },
		{ "company", "COMPANY", Color3.fromRGB(120, 220, 255), Color3.fromRGB(30, 140, 210), A.company },
		{ "inventory", "INVENTORY", Color3.fromRGB(255, 214, 90), Color3.fromRGB(226, 130, 30), A.inventory, icon = "backpack" },
		{ "locations", "PLACES", Color3.fromRGB(255, 140, 150), Color3.fromRGB(225, 55, 85), A.locations },
		{ "cars", "CARS", Color3.fromRGB(255, 140, 120), Color3.fromRGB(215, 55, 55), A.cars },
	}
	for i, d in ipairs(defs) do
		local api = bigButton(grid, d.icon or d[1], d[2], d[3], d[4], 80, 88, d[5])
		api.button.LayoutOrder = i
		menu[d[1]] = api
	end

	---------------------------------------------------------------------------
	-- RIGHT: Store, Gift (playtime timer), Cars, More (daily, spin, codes, invite, trade, trophies, music)
	---------------------------------------------------------------------------
	local right = new("Frame", { Name = "Right", BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 10), Size = UDim2.fromOffset(84, 400), Parent = root })
	local rightScale = new("UIScale", { Parent = right })
	new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, HorizontalAlignment = Enum.HorizontalAlignment.Right, Parent = right })

	local popups = {}
	local function popup(name, defs2, anchorBtn, cols)
		cols = cols or 3
		local rows = math.ceil(#defs2 / cols)
		local pop = panel({ Name = name, AnchorPoint = Vector2.new(1, 0), Size = UDim2.fromOffset(cols * 86 - 14 + 28, rows * 90 - 10 + 28), Visible = false, ZIndex = 8, Parent = root }, 18)
		local g = new("Frame", { Position = UDim2.fromOffset(14, 14), Size = UDim2.new(1, -28, 1, -28), BackgroundTransparency = 1, Parent = pop })
		new("UIGridLayout", { CellSize = UDim2.fromOffset(72, 80), CellPadding = UDim2.fromOffset(14, 10), SortOrder = Enum.SortOrder.LayoutOrder, Parent = g })
		local sc = new("UIScale", { Parent = pop })
		local items = {}
		for i, d in ipairs(defs2) do
			local api = bigButton(g, d[1], d[2], d[3], d[4], 72, 80, function()
				if not d.keepOpen then pop.Visible = false end
				d[5]()
			end)
			api.button.LayoutOrder = i
			items[d[1]] = api
		end
		local p = { frame = pop, scale = sc, items = items, anchor = anchorBtn }
		table.insert(popups, p)
		return p
	end
	local function openPopup(p)
		local was = p.frame.Visible
		for _, q in ipairs(popups) do q.frame.Visible = false end
		p.frame.Visible = not was
		if p.frame.Visible then
			p.scale.Scale = rightScale.Scale * 0.85
			UI.tween(p.scale, 0.2, { Scale = rightScale.Scale }, Enum.EasingStyle.Back)
		end
	end

	local storeB = bigButton(right, "store", "STORE", Color3.fromRGB(255, 225, 90), Color3.fromRGB(245, 150, 20), 84, 94, function() A.store() end)
	storeB.button.LayoutOrder = 1
	local giftB = bigButton(right, "gift", "GIFT", Color3.fromRGB(255, 160, 220), Color3.fromRGB(215, 60, 160), 84, 94, A.gift)
	giftB.button.LayoutOrder = 2
	local more
	local moreB = bigButton(right, "more", "MORE", Color3.fromRGB(170, 185, 225), Color3.fromRGB(85, 95, 150), 84, 94, function() openPopup(more) end)
	moreB.button.LayoutOrder = 3

	more = popup("MorePopup", {
		{ "daily", "DAILY", Color3.fromRGB(255, 150, 175), Color3.fromRGB(225, 60, 105), A.daily },
		{ "spin", "SPIN", Color3.fromRGB(190, 150, 255), Color3.fromRGB(110, 60, 220), A.spin },
		{ "codes", "CODES", Color3.fromRGB(185, 155, 255), Color3.fromRGB(105, 70, 225), function() toggle("Codes", _G.__CE_ShowCodes) end },
		{ "invite", "INVITE", Color3.fromRGB(255, 160, 200), Color3.fromRGB(225, 70, 140), function() if _G.__CE_Invite then _G.__CE_Invite() end end },
		{ "trade", "TRADE", Color3.fromRGB(130, 240, 140), Color3.fromRGB(30, 160, 80), function() toggle("Trade", _G.__CE_ShowTrade) end },
		{ "portfolio", "TROPHIES", Color3.fromRGB(255, 220, 110), Color3.fromRGB(230, 145, 25), function() toggle("Portfolio", _G.__CE_ShowPortfolio) end },
		{ "music", "MUSIC", Color3.fromRGB(150, 205, 255), Color3.fromRGB(70, 110, 230), function() if _G.__CE_ToggleMusic then _G.__CE_ToggleMusic() end end, keepOpen = true },
	}, moreB, 4)
	local musicB = more.items.music
	local function refreshMusic() musicB.setLabel(gui:GetAttribute("MusicOn") == false and "MUSIC OFF" or "MUSIC") end
	gui:GetAttributeChangedSignal("MusicOn"):Connect(refreshMusic)
	refreshMusic()

	---------------------------------------------------------------------------
	-- BOTTOM-LEFT: level + XP
	---------------------------------------------------------------------------
	local lvlBox = new("Frame", { Name = "Level", AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 18, 1, -14), Size = UDim2.fromOffset(340, 40), BackgroundTransparency = 1, Parent = root })
	local lvlScale = new("UIScale", { Parent = lvlBox })
	local xpBar, xpFill = progress(lvlBox, { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 30, 0.5, 2), Size = UDim2.new(1, -96, 0, 20) }, Color3.fromRGB(120, 210, 255), Color3.fromRGB(50, 120, 240))
	local xpLbl = text({ Size = UDim2.fromScale(1, 1), Font = ROUND, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 3, Text = "", Parent = xpBar })
	tstroke(xpLbl, 1.5)
	Icons.make("level", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0, 28, 0.5, 0), Size = UDim2.fromOffset(58, 58), ZIndex = 3, Parent = lvlBox })
	local lvlNum = text({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0, 28, 0.5, 3), Size = UDim2.fromOffset(44, 24), Text = "1", TextSize = 19,
		TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 4, Parent = lvlBox })
	tstroke(lvlNum, 2.5)
	local lvlSc = new("UIScale", { Parent = lvlNum })
	Icons.make("star", { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(1, -62, 0.5, 1), Size = UDim2.fromOffset(26, 26), ZIndex = 3, Parent = lvlBox })
	local repLbl = text({ AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(1, -36, 0.5, 2), Size = UDim2.fromOffset(40, 20), Font = ROUND, TextSize = 14,
		TextColor3 = Color3.fromRGB(255, 214, 80), Text = "0", Parent = lvlBox })
	tstroke(repLbl, 2)
	local lastLevel
	local function refreshLevel()
		local lvl = player:GetAttribute("Level") or 1
		local xp, nxt = player:GetAttribute("XP") or 0, player:GetAttribute("XPNext") or 80
		lvlNum.Text = tostring(lvl)
		repLbl.Text = short(player:GetAttribute("Rep") or 0)
		setFill(xpFill, xp / math.max(nxt, 1))
		xpLbl.Text = "Level " .. lvl .. "  ·  " .. short(xp) .. " / " .. short(nxt) .. " XP"
		if lastLevel and lvl > lastLevel then bounce(lvlSc, 1.5) end
		lastLevel = lvl
	end
	for _, a in ipairs({ "Level", "XP", "XPNext", "Rep" }) do player:GetAttributeChangedSignal(a):Connect(refreshLevel) end
	refreshLevel()

	---------------------------------------------------------------------------
	-- BOTTOM-LEFT, above the level: everything working for you right now
	-- (bad-weather bonus, boosts and Rush Crew with their timers, VIP and every pass you own, friends, Premium)
	---------------------------------------------------------------------------
	local fx = new("Frame", { Name = "Effects", AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 18, 1, -64), Size = UDim2.fromOffset(460, 160),
		BackgroundTransparency = 1, Parent = root })
	local fxScale = new("UIScale", { Parent = fx })
	-- small lines of text, one per effect, stacked upwards from the level bar
	new("UIListLayout", { FillDirection = Enum.FillDirection.Vertical, Padding = UDim.new(0, 1), VerticalAlignment = Enum.VerticalAlignment.Bottom,
		SortOrder = Enum.SortOrder.LayoutOrder, Parent = fx })
	local PASS_ICON = { vip = "vip", bigcrew = "hire", cash2x = "up_cash", strength2x = "up_strength", autobuild = "🤖", autotrain = "gym", gems2x = "gem",
		fasttools = "up_power", teleporter = "locations" }
	local PASS_COL = { vip = Color3.fromRGB(255, 190, 40), bigcrew = Color3.fromRGB(90, 200, 120), cash2x = Color3.fromRGB(80, 210, 110),
		strength2x = Color3.fromRGB(255, 120, 80), autobuild = Color3.fromRGB(90, 170, 255), autotrain = Color3.fromRGB(255, 150, 90),
		gems2x = Color3.fromRGB(70, 190, 255), fasttools = Color3.fromRGB(255, 200, 60), teleporter = Color3.fromRGB(235, 70, 130) }
	local BOOST_ICON = { cash = "up_cash", strength = "up_strength", power = "up_power", crew = "up_crew" }
	local BOOST_COL = { cash = Color3.fromRGB(80, 210, 110), strength = Color3.fromRGB(255, 120, 80), power = Color3.fromRGB(255, 196, 46), crew = Color3.fromRGB(90, 170, 255) }
	-- passes that are cars (they live in CARS, not here)
	local carPass = {}
	for _, v in ipairs(Config.Vehicles or {}) do if v.pass then carPass[v.pass] = true end end
	local function pct(x) return math.floor((x or 0) * 100 + 0.5) .. "%" end
	local fxChips = {}
	local function fxChip(key, icon, color, order)
		local ch = fxChips[key]
		if ch then return ch end
		local f = new("Frame", { Name = key, Size = UDim2.fromOffset(0, 20), AutomaticSize = Enum.AutomaticSize.X, BackgroundTransparency = 1, LayoutOrder = order, Parent = fx })
		new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 4),
			SortOrder = Enum.SortOrder.LayoutOrder, Parent = f })
		if Icons.has(icon) then
			Icons.make(icon, { Size = UDim2.fromOffset(20, 20), LayoutOrder = 1, ZIndex = 3, Parent = f })
		else
			new("TextLabel", { Size = UDim2.fromOffset(18, 20), BackgroundTransparency = 1, Text = icon, TextSize = 14, Font = Enum.Font.SourceSans, LayoutOrder = 1, ZIndex = 3, Parent = f })
		end
		local l = text({ Size = UDim2.fromOffset(0, 20), AutomaticSize = Enum.AutomaticSize.X, Font = ROUND, TextSize = 14, LayoutOrder = 2, Text = "",
			TextColor3 = color:Lerp(WHITE, 0.45), Parent = f })
		tstroke(l, 1.5)
		local sc = new("UIScale", { Scale = 0.3, Parent = f })
		UI.tween(sc, 0.3, { Scale = 1 }, Enum.EasingStyle.Back)
		ch = { frame = f, label = l }
		fxChips[key] = ch
		return ch
	end
	local function updateEffects()
		local now = workspace:GetServerTimeNow()
		local want = {}
		local function add(key, icon, color, order, label) want[key] = { icon, color, order, label } end
		-- timed: bad weather, boosts, Rush Crew
		if RS:GetAttribute("Weather") == "rain" then
			local left = (RS:GetAttribute("WeatherEnds") or 0) - now
			add("rain", "🌧️", Color3.fromRGB(110, 170, 255), 1, "RAIN +" .. pct(Config.Weather and Config.Weather.rainBonus) .. " CASH" .. (left > 0 and ("  " .. fmtTime(left)) or ""))
		end
		local bi = 0
		for key, b in pairs(Config.Boosts or {}) do
			bi += 1
			local left = player:GetAttribute("Boost_" .. key) or 0
			if left > 0 then add("boost_" .. key, BOOST_ICON[key] or b.icon, BOOST_COL[key] or T.accent, 10 + bi, string.upper(b.name or key) .. "  " .. fmtTime(left)) end
		end
		local rush = (player:GetAttribute("RushCrewEnds") or 0) - now
		if rush > 0 then add("rush", "up_crew", Color3.fromRGB(255, 150, 40), 20, "RUSH CREW 2X  " .. fmtTime(rush)) end
		-- forever: VIP and every pass you own
		for i, p in ipairs(Config.Store.passes or {}) do
			if player:GetAttribute("Pass_" .. p.key) == true and not carPass[p.key] then
				local label = (p.key == "vip" and ("VIP +" .. pct(Config.VipBonus) .. " CASH"))
					or (p.key == "bigcrew" and ("BIG CREW +" .. tostring(Config.BigCrewSlots or 3)))
					or string.upper(p.name or p.key)
				add("pass_" .. p.key, PASS_ICON[p.key] or p.icon or "star", PASS_COL[p.key] or T.purple, 30 + i, label)
			end
		end
		local fb = player:GetAttribute("FriendBonus") or 0
		if fb > 0 then add("friends", "invite", Color3.fromRGB(120, 220, 140), 60, "FRIENDS +" .. pct(fb) .. " CASH") end
		if player.MembershipType == Enum.MembershipType.Premium then
			add("premium", "⭐", Color3.fromRGB(255, 205, 70), 61, "PREMIUM +" .. pct(Config.PremiumBonus) .. " CASH")
		end
		for key, ch in pairs(fxChips) do
			if not want[key] then
				fxChips[key] = nil
				local f = ch.frame
				local sc = f:FindFirstChildOfClass("UIScale")
				if sc then UI.tween(sc, 0.18, { Scale = 0 }) end
				task.delay(0.2, function() f:Destroy() end)
			end
		end
		for key, w in pairs(want) do
			local ch = fxChip(key, w[1], w[2], w[3])
			ch.label.Text = w[4]
		end
	end
	task.spawn(function()
		while root.Parent do
			pcall(updateEffects)
			task.wait(0.5)
		end
	end)

	---------------------------------------------------------------------------
	-- layout (computer / phone, tall / short screens)
	---------------------------------------------------------------------------
	local megaOn = false
	local function layoutStrip()
		local inset = GuiService.TopbarInset
		local x0, w, h = inset.Min.X, inset.Width, inset.Height
		if w < 200 or h < 24 then
			x0, w, h = 160, camera.ViewportSize.X - 160, 44
		end
		local ch = math.clamp(h - 12, 32, 44)
		local gap = 16 -- clear room between the chips
		-- a clear gap after the Roblox buttons, and a little room on the right
		local left = math.clamp(math.floor(camera.ViewportSize.X * 0.025), 18, 40)
		-- level with Roblox's own buttons: in today's top bar (58 high) they are 44 tall and sit 2 above its bottom edge
		local by, bh = (h >= 50) and (h - 46) or math.floor((h - 32) / 2), (h >= 50) and 44 or 32
		row.Position = UDim2.fromOffset(x0 + left, inset.Min.Y + math.floor(by + (bh - ch) / 2))
		local total = w - left - 12
		row.Size = UDim2.fromOffset(total, ch)
		local mw = megaOn and math.clamp(math.floor(total * 0.16), 130, 190) or 0
		local qw = math.clamp(math.floor(total * 0.3), 170, 340)
		local bw = total - qw - (megaOn and (mw + gap) or 0) - gap
		build.Position = UDim2.fromOffset(0, 0)
		build.Size = UDim2.fromOffset(bw, ch)
		quest.Position = UDim2.fromOffset(bw + gap, 0)
		quest.Size = UDim2.fromOffset(qw, ch)
		mega.Visible = megaOn
		mega.Position = UDim2.fromOffset(bw + gap + qw + gap, 0)
		mega.Size = UDim2.fromOffset(mw, ch)
		local ic = ch + 6
		bIcon.Size = UDim2.fromOffset(ic + 4, ic + 4)
		qIcon.Size = UDim2.fromOffset(ic, ic)
		bText.Position = UDim2.fromOffset(ic + 2, 0)
		bText.TextSize = ch >= 40 and 19 or 16
		bPct.TextSize = ch >= 40 and 22 or 18
		bPct.Size = UDim2.fromOffset(90, ch)
		gui:SetAttribute("TopBand", 10)
	end

	local function layout()
		local compact = gui:GetAttribute("Compact") == true
		local s = math.max(c.uiScale.Scale, 0.01)
		local H = camera.ViewportSize.Y / s
		layoutStrip()
		-- left: smaller on phones; the menu goes 3-wide when the screen is short
		local ls = compact and (H < 620 and 0.72 or 0.8) or 1
		leftScale.Scale = ls
		local avail = (H - 10 - (compact and 150 or 60)) / ls
		-- 8 buttons: 4 rows of 2, or 3 wide (3 rows) when the screen is short
		local cols = (146 + 4 * 96 * MENU_SCALE > avail) and 3 or 2
		gridLayout.FillDirectionMaxCells = cols
		grid.Size = UDim2.fromOffset(cols * 94, 400)
		local rs = (compact and 0.8 or 1) * MENU_SCALE
		rightScale.Scale = rs
		lvlScale.Scale = compact and 0.85 or 1
		fxScale.Scale = compact and 0.85 or 1
		-- the effects never reach the hotbar in the middle of the bottom edge
		fx.Size = UDim2.fromOffset(math.clamp(math.floor(camera.ViewportSize.X / s * 0.36 / fxScale.Scale), 220, 460), 160)
		-- popups open to the left of their button
		for i, p in ipairs(popups) do
			p.frame.Position = UDim2.new(1, -12 - 92 * rs, 0, 10 + 200 * rs) -- level with MORE
		end
	end
	gui:GetAttributeChangedSignal("Compact"):Connect(function() task.defer(layout) end)
	camera:GetPropertyChangedSignal("ViewportSize"):Connect(function() task.defer(layout) end)
	GuiService:GetPropertyChangedSignal("TopbarInset"):Connect(layoutStrip)
	layout()
	task.delay(1, layout)

	---------------------------------------------------------------------------
	-- live updates
	---------------------------------------------------------------------------
	local lj = c.legacyJob
	local KIND_ICON = { mega = "mega", home = "home", help = "crew", contract = "contract" }
	local lastKind
	RunService.RenderStepped:Connect(function(dt)
		local show = gui:GetAttribute("Cinematic") ~= true
		root.Visible = show
		topGui.Enabled = show
		-- money counter
		local target = player:GetAttribute("Money") or 0
		if math.abs(target - shownMoney) < 0.5 then shownMoney = target else shownMoney += (target - shownMoney) * math.min(1, dt * 8) end
		cashVal.Text = Config.FormatMoney(shownMoney)
		-- construction bar
		if lj.panel.Visible then
			local tag = lj.tag.Text
			local kind = tag:find("MEGA") and "mega" or (tag:find("HELPING") and "help") or (tag:find("HOME") and "home") or "contract"
			if kind ~= lastKind then
				lastKind = kind
				Icons.set(bIcon, KIND_ICON[kind])
			end
			local stage = lj.stage.Text -- "2/5  Walls"
			local n, name = stage:match("^(%d+/%d+)%s+(.+)$")
			local title = lj.title.Text ~= "" and lj.title.Text or "Construction"
			bText.Text = string.upper(title) .. (name and ("  <font color='#fff1c4' size='15' face='FredokaOne'>" .. name .. " " .. n .. "</font>") or "")
			bText.TextColor3 = WHITE
			local f = math.clamp(lj.fill.Size.X.Scale, 0, 1)
			bFill.Visible = f > 0.002
			bFill.Size = bFill.Size:Lerp(UDim2.new(math.max(f, 0.03), -6 * math.max(f, 0.03), 1, -6), math.min(1, dt * 10))
			bPct.Text = lj.pct.Text
			local t = lj.timer.Text
			local bonus = t:match("Speed bonus: ([%d:]+)")
			local rush = t:match("RUSH ORDER: (%d+)s")
			if rush then
				bBonus.Text = "RUSH " .. rush .. "s"
				bBonus.TextColor3 = Color3.fromRGB(255, 170, 90)
			elseif bonus then
				bBonus.Text = "BONUS " .. bonus
				bBonus.TextColor3 = Color3.fromRGB(150, 255, 150)
			else
				bBonus.Text = ""
			end
			cX.Visible = lj.abandon.Visible and tutorialDone()
			-- armed (first tap done): the same X in the same place, its border flashing yellow until tapped again
			if cXstroke then
				local armed = os.clock() < confirmUntil
				cXstroke.Color = armed and INK:Lerp(Color3.fromRGB(255, 230, 60), 0.5 + 0.5 * math.sin(os.clock() * 12)) or INK
			end
		else
			if lastKind ~= "none" then lastKind = "none"; Icons.set(bIcon, "jobs") end
			bFill.Visible = false
			local hint = tutorialDone() and "tap here to find a job"
				or ((player:GetAttribute("Completed") or 0) == 0 and "follow the arrow to the Job Board" or "🔒 finish the tutorial first")
			bText.Text = "NO CONTRACT  <font color='#ffd45a' size='15' face='FredokaOne'>" .. hint .. "</font>"
			bText.TextColor3 = Color3.fromRGB(255, 255, 255)
			bPct.Text = ""
			bBonus.Text = ""
			cX.Visible = false
		end
		-- City Tower chip only while a tower is being built
		local active = RS:GetAttribute("MegaStatus") == "active"
		if active ~= megaOn then megaOn = active; layoutStrip() end
		if active then
			local st = c.Jobs:FindFirstChild(RS:GetAttribute("MegaJob") or "")
			local tot = st and st:GetAttribute("Total") or 0
			setFill(mFill, tot)
			mPct.Text = math.floor(tot * 100) .. "%"
		end

		-- badge pulse
		local p = 1 + math.sin(os.clock() * 6) * 0.08
		for sc in pairs(pulsing) do sc.Scale = p end
		-- popups never stay open behind a window
		if c.modalOpen() then for _, q in ipairs(popups) do q.frame.Visible = false end end
	end)

	-- gift timer on the GIFT button; MORE shows a badge when daily missions or a spin are waiting
	RunService.Heartbeat:Connect(function()
		local i, _, gleft = c.playtime.Next()
		if not i then
			giftB.setLabel("GIFTS")
			giftB.setBadge(false)
		elseif gleft <= 0 then
			giftB.setLabel("OPEN!")
			giftB.setBadge(true)
		else
			giftB.setLabel(fmtTime(gleft))
			giftB.setBadge(false)
		end
		local ready, sleft = c.spinReady()
		-- the button always says SPIN; the time to the next free spin sits small on its corner
		more.items.spin.setLabel(ready and "SPIN!" or "SPIN")
		more.items.spin.setCorner((not ready and sleft and sleft > 0) and fmtTime(sleft) or nil)
		-- how many spins are waiting: the free one + the extra ones
		local spins = (ready and ((player:GetAttribute("SpinNext") or math.huge) <= os.time()) and 1 or 0) + (player:GetAttribute("SpinExtra") or 0)
		if ready and spins == 0 then spins = 1 end
		more.items.spin.setBadge(spins)
		local missions = player:GetAttribute("MissionsReady") or 0
		more.items.daily.setBadge(missions)
		moreB.setBadge(missions + spins)
	end)

	-- the buildings you can take now and never built (the server sends the built ones in BuiltIds)
	local seenNew
	local function newBuildings()
		local list = {}
		local ids = player:GetAttribute("BuiltIds")
		if ids == nil then return list end
		local built = {}
		for id in string.gmatch(ids, "[^,]+") do built[id] = true end
		local lvl, rep, str, reb = player:GetAttribute("Level") or 1, player:GetAttribute("Rep") or 0, player:GetAttribute("Strength") or 0, player:GetAttribute("Rebirths") or 0
		for _, ct in ipairs(Config.Contracts) do
			if not built[ct.id] and rep >= ct.reqRep and lvl >= ct.reqLevel and str >= (ct.reqStrength or 0) and reb >= (ct.reqRebirth or 0) then
				table.insert(list, ct)
			end
		end
		return list
	end
	c.newBuildings = newBuildings

	-- the lock on JOBS and SHOP: animated when it opens during this session, silent for players past the tutorial
	local wasLocked, sawLocked = nil, false
	local function applyLock()
		local locked = not tutorialDone()
		-- only a player we actually saw doing the tutorial gets the unlock show
		if locked and player:GetAttribute("RoadStep") ~= nil and player:GetAttribute("Loaded") == true then sawLocked = true end
		if locked == wasLocked then return end
		local animate = (not locked) and sawLocked
		wasLocked = locked
		menu.jobs.setLocked(locked, animate)
		if animate then
			task.delay(0.35, function() menu.shop.setLocked(locked, true) end)
		else
			menu.shop.setLocked(locked, false)
		end
	end
	applyLock()
	player:GetAttributeChangedSignal("RoadStep"):Connect(applyLock)
	player:GetAttributeChangedSignal("Loaded"):Connect(applyLock)

	-- "something to do here" badges on the menu buttons (checked twice a second)
	task.spawn(function()
		while root.Parent do
			local money = player:GetAttribute("Money") or 0
			-- shop: the next tool or training gear is affordable
			local tier, gt = player:GetAttribute("ToolTier") or 1, player:GetAttribute("GearTier") or 1
			local nt, ng = Config.Tools[tier + 1], Config.TrainingGear[gt + 1]
			local open = tutorialDone()
			-- shop: something to buy on any tab (the Shop shows a red dot on that tab)
			-- how many things you can buy there right now
			local av = c.shopAvailable and c.shopAvailable()
			local count = av and av.count or (((nt and money >= nt.price) and 1 or 0) + ((ng and money >= ng.price) and 1 or 0))
			menu.shop.setBadge(open and count or 0)
			-- jobs: buildings you can take now but never built yet (NEW on the Job Board)
			local fresh = newBuildings()
			menu.jobs.setBadge(open and #fresh or 0)
			if player:GetAttribute("Loaded") and player:GetAttribute("BuiltIds") ~= nil then
				if not seenNew then
					seenNew = {}
					for _, ct in ipairs(fresh) do seenNew[ct.id] = true end
				else
					-- one message, however many unlock at once
					local got = {}
					for _, ct in ipairs(fresh) do
						if not seenNew[ct.id] then
							seenNew[ct.id] = true
							table.insert(got, ct.name)
						end
					end
					if open and #got > 0 then
						c.toast(#got == 1 and ("🆕 New building unlocked: " .. got[1] .. "! Open JOBS")
							or ("🆕 " .. #got .. " new buildings unlocked! Open JOBS"), Color3.fromRGB(255, 205, 70), 4)
						if c.sound2D and c.S then c.sound2D(c.S.Chime, 0.5, 1.3) end
					end
				end
			end
			-- upgrades: how many can be bought right now
			local n = 0
			for _, dp in ipairs(Company.Departments) do
				local lv = player:GetAttribute("Up_" .. dp.id) or 0
				if lv < Company.DeptMax then
					local cash, mats = Company.DeptCost(dp, lv)
					local ok = money >= cash
					for id, q in pairs(mats or {}) do
						if (player:GetAttribute("Mat_" .. id) or 0) < q then ok = false end
					end
					if ok then n += 1 end
				end
			end
			menu.upgrades.setBadge(n)
			-- rebirth: ready
			local run, cost = player:GetAttribute("RunEarned") or 0, player:GetAttribute("FranchiseCost") or math.huge
			menu.rebirth.setBadge(run >= cost)
			task.wait(0.5)
		end
	end)
end

return M
