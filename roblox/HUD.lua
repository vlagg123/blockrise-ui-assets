-- BlockRise Empire - main HUD (kept light on purpose)
--   top: Roblox's own top bar row, edge to edge: a big construction progress bar, the Empire Road goal, the City Tower
--   left: money, gems, Strength + six menu buttons   right: Store, Gift, More   bottom: level + XP
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
	grad(face, c1, c2)
	stroke(face, 3)
	local gloss = new("Frame", { Position = UDim2.fromOffset(6, 5), Size = UDim2.new(1, -12, 0.42, 0), BackgroundColor3 = WHITE,
		BackgroundTransparency = 0.55, BorderSizePixel = 0, Parent = face })
	corner(gloss, 14)
	new("UIGradient", { Transparency = NumberSequence.new(0.2, 1), Rotation = 90, Parent = gloss })
	local ic = Icons.make(key, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.45), Size = UDim2.fromScale(0.84, 0.84), Parent = face })
	local lbl = text({ Name = "Label", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, 0), Size = UDim2.new(1, 12, 0, 24),
		Text = label, TextScaled = true, TextXAlignment = Enum.TextXAlignment.Center, Parent = b })
	tstroke(lbl, 3)
	new("UITextSizeConstraint", { MaxTextSize = 21, MinTextSize = 9, Parent = lbl })
	local badge = new("Frame", { Name = "Badge", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(1, -7, 0, 7), Size = UDim2.fromOffset(28, 28),
		BackgroundColor3 = Color3.fromRGB(255, 52, 84), BorderSizePixel = 0, Visible = false, ZIndex = 5, Parent = b })
	corner(badge, 14)
	stroke(badge, 2.5)
	local bsc = new("UIScale", { Parent = badge })
	local bl = text({ Size = UDim2.fromScale(1, 1), Text = "!", TextSize = 17, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 6, Parent = badge })
	tstroke(bl, 1.5)
	local down = false
	b.MouseEnter:Connect(function() UI.tween(sc, 0.12, { Scale = 1.06 }) end)
	b.MouseLeave:Connect(function()
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
	function api.setBadge(v)
		local on = v ~= nil and v ~= false and v ~= 0
		badge.Visible = on
		pulsing[bsc] = on or nil
		if type(v) == "number" then bl.Text = v > 9 and "9+" or tostring(v) else bl.Text = "!" end
	end
	function api.setLabel(t) lbl.Text = t end
	return api
end

local function pill(parent, key, width, color)
	local f = panel({ Size = UDim2.fromOffset(width, 40), Parent = parent }, 20)
	local ic = Icons.make(key, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(16, 19), Size = UDim2.fromOffset(50, 50), ZIndex = 3, Parent = f })
	local val = text({ Name = "Value", Position = UDim2.fromOffset(46, 0), Size = UDim2.new(1, -88, 1, 0), Text = "0", TextSize = 23,
		TextColor3 = color, TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 3, Parent = f })
	tstroke(val, 2.5)
	local sc = new("UIScale", { Parent = val })
	return f, val, sc, ic
end

local function plusButton(parent, onClick)
	local b = new("TextButton", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -5, 0.5, 0), Size = UDim2.fromOffset(30, 30),
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

	-- actions ----------------------------------------------------------------
	local A = {}
	local function toggle(name, fn) if fn then _G.__CE_Toggle(name, fn) end end
	function A.jobs()
		-- after your first contract the Job Board opens from anywhere
		if (player:GetAttribute("Completed") or 0) >= 1 and _G.__CE_ShowContracts then
			toggle("Contracts", _G.__CE_ShowContracts)
		else
			c.setWaypoint("board")
		end
	end
	function A.shop() toggle("Shop", c.showShop) end
	function A.upgrades() toggle("Upgrades", c.showUpgrades) end
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
		local sc = new("UIScale", { Parent = f })
		b.MouseEnter:Connect(function() UI.tween(sc, 0.12, { Scale = 1.03 }) end)
		b.MouseLeave:Connect(function() UI.tween(sc, 0.12, { Scale = 1 }) end)
		b.MouseButton1Down:Connect(function() UI.tween(sc, 0.05, { Scale = 0.97 }) end)
		b.MouseButton1Up:Connect(function() UI.tween(sc, 0.15, { Scale = 1 }, Enum.EasingStyle.Back) end)
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
	local confirmUntil = 0
	cX.Activated:Connect(function()
		c.click()
		if os.clock() < confirmUntil then
			confirmUntil = 0
			pcall(function() c.R.Abandon:InvokeServer() end)
		else
			confirmUntil = os.clock() + 2.5
			c.toast("Tap X again to abandon this contract", T.muted, 2.5)
		end
	end)
	buildHit.Activated:Connect(function()
		c.click()
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
	local gemPill, gemVal, gemSc = pill(left, "gem", 236, Color3.fromRGB(130, 225, 255))
	gemPill.Position = UDim2.fromOffset(0, 46)
	plusButton(gemPill, function() A.store("gems") end)
	local strPill, strVal, strSc = pill(left, "strength", 236, Color3.fromRGB(255, 180, 110))
	strPill.Position = UDim2.fromOffset(0, 92)
	strVal.Size = UDim2.new(1, -52, 1, 0)
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

	local grid = new("Frame", { Name = "Menu", BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 146), Size = UDim2.fromOffset(176, 300), Parent = left })
	local gridLayout = new("UIGridLayout", { CellSize = UDim2.fromOffset(80, 88), CellPadding = UDim2.fromOffset(10, 6), SortOrder = Enum.SortOrder.LayoutOrder,
		FillDirectionMaxCells = 2, Parent = grid })
	local menu = {}
	local defs = {
		{ "jobs", "JOBS", Color3.fromRGB(255, 205, 70), Color3.fromRGB(240, 130, 20), A.jobs },
		{ "shop", "SHOP", Color3.fromRGB(110, 200, 255), Color3.fromRGB(40, 110, 230), A.shop },
		{ "upgrades", "UPGRADES", Color3.fromRGB(130, 240, 120), Color3.fromRGB(30, 160, 70), A.upgrades },
		{ "rebirth", "REBIRTH", Color3.fromRGB(205, 150, 255), Color3.fromRGB(125, 65, 230), A.rebirth },
		{ "company", "COMPANY", Color3.fromRGB(120, 220, 255), Color3.fromRGB(30, 140, 210), A.company },
		{ "locations", "PLACES", Color3.fromRGB(255, 140, 150), Color3.fromRGB(225, 55, 85), A.locations },
	}
	for i, d in ipairs(defs) do
		local api = bigButton(grid, d[1], d[2], d[3], d[4], 80, 88, d[5])
		api.button.LayoutOrder = i
		menu[d[1]] = api
	end

	---------------------------------------------------------------------------
	-- RIGHT: Store, Gift (playtime timer), More (daily, spin, codes, invite, trade, cars, trophies, music)
	---------------------------------------------------------------------------
	local right = new("Frame", { Name = "Right", BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 10), Size = UDim2.fromOffset(84, 300), Parent = root })
	local rightScale = new("UIScale", { Parent = right })
	new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, HorizontalAlignment = Enum.HorizontalAlignment.Right, Parent = right })

	local popups = {}
	local function popup(name, defs2, anchorBtn, cols)
		cols = cols or 3
		local rows = math.ceil(#defs2 / cols)
		local pop = panel({ Name = name, AnchorPoint = Vector2.new(1, 0), Size = UDim2.fromOffset(cols * 78 + 20, rows * 86 + 20), Visible = false, ZIndex = 8, Parent = root }, 18)
		local g = new("Frame", { Position = UDim2.fromOffset(10, 10), Size = UDim2.new(1, -20, 1, -20), BackgroundTransparency = 1, Parent = pop })
		new("UIGridLayout", { CellSize = UDim2.fromOffset(72, 80), CellPadding = UDim2.fromOffset(6, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = g })
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
		{ "cars", "CARS", Color3.fromRGB(255, 140, 120), Color3.fromRGB(215, 55, 55), function() toggle("Garage", _G.__CE_ShowGarage) end },
		{ "portfolio", "TROPHIES", Color3.fromRGB(255, 220, 110), Color3.fromRGB(230, 145, 25), function() toggle("Portfolio", _G.__CE_ShowPortfolio) end },
		{ "music", "MUSIC", Color3.fromRGB(150, 205, 255), Color3.fromRGB(70, 110, 230), function() if _G.__CE_ToggleMusic then _G.__CE_ToggleMusic() end end, keepOpen = true },
	}, moreB, 4)
	local musicB = more.items.music
	local function refreshMusic() musicB.setLabel(gui:GetAttribute("MusicOn") == false and "MUSIC OFF" or "MUSIC") end
	gui:GetAttributeChangedSignal("MusicOn"):Connect(refreshMusic)
	refreshMusic()

	---------------------------------------------------------------------------
	-- BOTTOM: level + XP
	---------------------------------------------------------------------------
	local lvlBox = new("Frame", { Name = "Level", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -8), Size = UDim2.fromOffset(340, 40), BackgroundTransparency = 1, Parent = root })
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
		local gap = 8
		-- a clear gap after the Roblox buttons, and a little room on the right
		local left = math.clamp(math.floor(camera.ViewportSize.X * 0.025), 18, 40)
		row.Position = UDim2.fromOffset(x0 + left, math.floor((h - ch) / 2))
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
		local cols = (146 + 3 * 94 > avail) and 3 or 2
		gridLayout.FillDirectionMaxCells = cols
		grid.Size = UDim2.fromOffset(cols * 90, 300)
		local rs = compact and 0.8 or 1
		rightScale.Scale = rs
		lvlScale.Scale = compact and 0.85 or 1
		-- popups open to the left of their button
		for i, p in ipairs(popups) do
			p.frame.Position = UDim2.new(1, -12 - 92 * rs, 0, 10 + 100 * rs)
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
			cX.Visible = lj.abandon.Visible
			cXl.Text = os.clock() < confirmUntil and "?" or "X"
		else
			if lastKind ~= "none" then lastKind = "none"; Icons.set(bIcon, "jobs") end
			bFill.Visible = false
			bText.Text = "NO CONTRACT  <font color='#ffd45a' size='15' face='FredokaOne'>tap here to find a job</font>"
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
		more.items.spin.setLabel(ready and "SPIN!" or (sleft and sleft > 0 and fmtTime(sleft) or "SPIN"))
		more.items.spin.setBadge(ready)
		local missions = player:GetAttribute("MissionsReady") or 0
		more.items.daily.setBadge(missions)
		moreB.setBadge(missions + (ready and 1 or 0))
	end)

	-- "something to do here" badges on the menu buttons (checked twice a second)
	task.spawn(function()
		while root.Parent do
			local money = player:GetAttribute("Money") or 0
			-- shop: the next tool or training gear is affordable
			local tier, gt = player:GetAttribute("ToolTier") or 1, player:GetAttribute("GearTier") or 1
			local nt, ng = Config.Tools[tier + 1], Config.TrainingGear[gt + 1]
			menu.shop.setBadge((nt and money >= nt.price) or (ng and money >= ng.price) or false)
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
