-- BlockRise Empire - main HUD
-- One full-width bar on top (Empire Road goal · active contract · Mega Project), your level and money on
-- the left with six big menu buttons, rewards on the right. The middle of the screen stays free for playing.
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
	local f = panel({ Size = UDim2.fromOffset(width, 46), Parent = parent }, 23)
	local ic = Icons.make(key, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(18, 22), Size = UDim2.fromOffset(58, 58), ZIndex = 3, Parent = f })
	local val = text({ Name = "Value", Position = UDim2.fromOffset(52, 0), Size = UDim2.new(1, -100, 1, 0), Text = "0", TextSize = 26,
		TextColor3 = color, TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 3, Parent = f })
	tstroke(val, 2.5)
	local sc = new("UIScale", { Parent = val })
	return f, val, sc, ic
end

local function plusButton(parent, onClick)
	local b = new("TextButton", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -6, 0.5, 0), Size = UDim2.fromOffset(34, 34),
		BackgroundColor3 = WHITE, Text = "", AutoButtonColor = false, ZIndex = 4, Parent = parent })
	corner(b, 11)
	grad(b, Color3.fromRGB(110, 236, 120), Color3.fromRGB(36, 168, 78))
	stroke(b, 2.5)
	local l = text({ Size = UDim2.fromScale(1, 1), Position = UDim2.fromOffset(0, 1), Text = "+", TextSize = 26, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 5, Parent = b })
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

	local root = new("Frame", { Name = "HUD2", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 2, Parent = gui })

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
	-- TOP BAR
	---------------------------------------------------------------------------
	local bar = panel({ Name = "TopBar", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 8), Size = UDim2.new(1, -24, 0, 70), Parent = root }, 18)
	local function segment(name)
		local s = new("TextButton", { Name = name, BackgroundTransparency = 1, Text = "", AutoButtonColor = false, Size = UDim2.new(0.33, 0, 1, 0), Parent = bar })
		local hl = new("Frame", { Position = UDim2.fromOffset(4, 4), Size = UDim2.new(1, -8, 1, -8), BackgroundColor3 = WHITE, BackgroundTransparency = 1, BorderSizePixel = 0, Parent = s })
		corner(hl, 14)
		s.MouseEnter:Connect(function() UI.tween(hl, 0.12, { BackgroundTransparency = 0.93 }) end)
		s.MouseLeave:Connect(function() UI.tween(hl, 0.12, { BackgroundTransparency = 1 }) end)
		return s
	end
	local function divider()
		local d = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.new(0, 3, 1, -22), BackgroundColor3 = INK, BackgroundTransparency = 0.25, BorderSizePixel = 0, Parent = bar })
		corner(d, 2)
		return d
	end

	-- Empire Road goal
	local segQ = segment("Quest")
	local qIcon = Icons.make("quest", { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 6, 0.5, 0), Size = UDim2.fromOffset(60, 60), Parent = segQ })
	local qTag = text({ Position = UDim2.fromOffset(70, 7), Size = UDim2.new(1, -78, 0, 16), Font = ROUND, TextSize = 14, TextColor3 = Color3.fromRGB(255, 205, 70), Text = "", Parent = segQ })
	tstroke(qTag, 2)
	local qReward = text({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -10, 0, 7), Size = UDim2.fromOffset(150, 16), Font = ROUND, TextSize = 14,
		TextColor3 = Color3.fromRGB(130, 240, 140), TextXAlignment = Enum.TextXAlignment.Right, Text = "", Parent = segQ })
	tstroke(qReward, 2)
	local qTitle = text({ Position = UDim2.fromOffset(70, 22), Size = UDim2.new(1, -80, 0, 24), TextSize = 21, TextTruncate = Enum.TextTruncate.AtEnd, Text = "", Parent = segQ })
	tstroke(qTitle, 2.5)
	local qBar, qFill = progress(segQ, { Position = UDim2.fromOffset(70, 49), Size = UDim2.new(1, -170, 0, 13) }, Color3.fromRGB(130, 240, 120), Color3.fromRGB(40, 175, 80))
	local qVal = text({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -10, 0, 46), Size = UDim2.fromOffset(92, 18), Font = ROUND, TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Right, Text = "", Parent = segQ })
	tstroke(qVal, 2)
	local qPlace
	segQ.Activated:Connect(function() c.click(); goPlace(qPlace) end)
	local function refreshQuest()
		local i = player:GetAttribute("RoadStep") or 1
		local step = Config.Road[i]
		if not step then
			qTag.Text = "EMPIRE ROAD · COMPLETE"
			qTitle.Text = "You finished the road!"
			qReward.Text = ""
			qVal.Text = ""
			setFill(qFill, 1)
			qPlace = nil
			return
		end
		local tutorial = i <= Config.RoadTutorialSteps
		qTag.Text = tutorial and ("TUTORIAL · " .. i .. "/" .. Config.RoadTutorialSteps) or ("EMPIRE ROAD · " .. i .. "/" .. #Config.Road)
		qTitle.Text = step.title
		qReward.Text = "+" .. Config.FormatMoney(step.cash) .. "  +" .. step.gems .. " gems"
		local v = player:GetAttribute("RoadValue") or 0
		setFill(qFill, v / math.max(step.target, 1))
		qVal.Text = step.target > 1 and (short(v) .. " / " .. short(step.target)) or (v >= step.target and "DONE!" or "0 / 1")
		qPlace = step.place
	end
	player:GetAttributeChangedSignal("RoadStep"):Connect(refreshQuest)
	player:GetAttributeChangedSignal("RoadValue"):Connect(refreshQuest)
	refreshQuest()
	local div1 = divider()

	-- Active contract (mirrors the job tracker: contract, home build, helping, mega)
	local segC = segment("Contract")
	local cIcon = Icons.make("contract", { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 6, 0.5, 0), Size = UDim2.fromOffset(60, 60), Parent = segC })
	local cTag = text({ Position = UDim2.fromOffset(70, 7), Size = UDim2.new(1, -200, 0, 16), Font = ROUND, TextSize = 14, TextColor3 = Color3.fromRGB(255, 170, 70), Text = "", Parent = segC })
	tstroke(cTag, 2)
	local cTimer = text({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -46, 0, 7), Size = UDim2.fromOffset(150, 16), Font = ROUND, TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Right, Text = "", Parent = segC })
	tstroke(cTimer, 2)
	local cTitle = text({ Position = UDim2.fromOffset(70, 22), Size = UDim2.new(1, -120, 0, 24), TextSize = 21, TextTruncate = Enum.TextTruncate.AtEnd, Text = "", Parent = segC })
	tstroke(cTitle, 2.5)
	local cBar, cFill = progress(segC, { Position = UDim2.fromOffset(70, 47), Size = UDim2.new(1, -82, 0, 17) }, Color3.fromRGB(255, 220, 80), Color3.fromRGB(255, 140, 30))
	local cPct = text({ Size = UDim2.fromScale(1, 1), TextSize = 14, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 3, Text = "", Parent = cBar })
	tstroke(cPct, 2)
	local cFind = new("TextButton", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), Size = UDim2.fromOffset(130, 44), BackgroundColor3 = WHITE,
		Text = "", AutoButtonColor = false, Visible = false, Parent = segC })
	corner(cFind, 14)
	grad(cFind, Color3.fromRGB(255, 214, 70), Color3.fromRGB(245, 140, 20))
	stroke(cFind, 3)
	tstroke(text({ Size = UDim2.fromScale(1, 1), Text = "FIND A JOB", TextSize = 19, TextXAlignment = Enum.TextXAlignment.Center, Parent = cFind }), 2.5)
	cFind.Activated:Connect(function() c.click(); A.jobs() end)
	-- abandon: two taps
	local cX = new("TextButton", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -10, 0, 5), Size = UDim2.fromOffset(30, 26), BackgroundColor3 = WHITE,
		Text = "", AutoButtonColor = false, Visible = false, ZIndex = 4, Parent = segC })
	corner(cX, 9)
	grad(cX, Color3.fromRGB(255, 110, 110), Color3.fromRGB(205, 45, 60))
	stroke(cX, 2.5)
	local cXl = text({ Size = UDim2.fromScale(1, 1), Text = "X", TextSize = 16, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 5, Parent = cX })
	tstroke(cXl, 2)
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
	segC.Activated:Connect(function()
		c.click()
		if c.legacyJob.panel.Visible then A.go("site") else A.jobs() end
	end)
	local div2 = divider()

	-- Mega Project
	local segM = segment("Mega")
	local mIcon = Icons.make("mega", { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 6, 0.5, 0), Size = UDim2.fromOffset(56, 56), Parent = segM })
	local mTag = text({ Position = UDim2.fromOffset(66, 7), Size = UDim2.new(1, -74, 0, 16), Font = ROUND, TextSize = 14, TextColor3 = Color3.fromRGB(200, 150, 255), Text = "MEGA PROJECT", Parent = segM })
	tstroke(mTag, 2)
	local mLine = text({ Position = UDim2.fromOffset(66, 22), Size = UDim2.new(1, -130, 0, 24), TextSize = 19, TextTruncate = Enum.TextTruncate.AtEnd, Text = "", Parent = segM })
	tstroke(mLine, 2.5)
	local mBar, mFill = progress(segM, { Position = UDim2.fromOffset(66, 49), Size = UDim2.new(1, -130, 0, 12) }, Color3.fromRGB(215, 170, 255), Color3.fromRGB(130, 80, 235))
	local mGo = new("TextButton", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), Size = UDim2.fromOffset(54, 40), BackgroundColor3 = WHITE,
		Text = "", AutoButtonColor = false, Parent = segM })
	corner(mGo, 12)
	grad(mGo, Color3.fromRGB(120, 236, 130), Color3.fromRGB(36, 168, 78))
	stroke(mGo, 3)
	tstroke(text({ Size = UDim2.fromScale(1, 1), Text = "GO", TextSize = 20, TextXAlignment = Enum.TextXAlignment.Center, Parent = mGo }), 2.5)
	mGo.Activated:Connect(function() c.click(); A.go("mega") end)
	segM.Activated:Connect(function() c.click(); A.go("mega") end)

	---------------------------------------------------------------------------
	-- LEFT: level, money, gems, Strength, bonuses, menu buttons
	---------------------------------------------------------------------------
	local left = new("Frame", { Name = "Left", BackgroundTransparency = 1, Position = UDim2.fromOffset(12, 88), Size = UDim2.fromOffset(270, 600), Parent = root })
	local leftScale = new("UIScale", { Parent = left })

	local lvlCard = panel({ Size = UDim2.fromOffset(262, 68), Parent = left }, 20)
	local star = Icons.make("level", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(30, 32), Size = UDim2.fromOffset(78, 78), ZIndex = 3, Parent = lvlCard })
	local lvlNum = text({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(30, 36), Size = UDim2.fromOffset(60, 30), Text = "1", TextSize = 24,
		TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 4, Parent = lvlCard })
	tstroke(lvlNum, 3)
	local lvlSc = new("UIScale", { Parent = lvlNum })
	local lvlWord = text({ Position = UDim2.fromOffset(70, 8), Size = UDim2.fromOffset(90, 20), Text = "LEVEL 1", TextSize = 18, Parent = lvlCard })
	tstroke(lvlWord, 2)
	local repIcon = Icons.make("star", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -66, 0, 18), Size = UDim2.fromOffset(24, 24), ZIndex = 3, Parent = lvlCard })
	local repLbl = text({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -10, 0, 8), Size = UDim2.fromOffset(56, 20), Font = ROUND, TextSize = 16,
		TextColor3 = Color3.fromRGB(255, 214, 80), TextXAlignment = Enum.TextXAlignment.Left, Text = "0", Parent = lvlCard })
	tstroke(repLbl, 2)
	local xpBar, xpFill = progress(lvlCard, { Position = UDim2.fromOffset(68, 34), Size = UDim2.new(1, -80, 0, 22) }, Color3.fromRGB(120, 210, 255), Color3.fromRGB(50, 120, 240))
	local xpLbl = text({ Size = UDim2.fromScale(1, 1), Font = ROUND, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 3, Text = "", Parent = xpBar })
	tstroke(xpLbl, 2)
	local lastLevel
	local function refreshLevel()
		local lvl = player:GetAttribute("Level") or 1
		local xp, nxt = player:GetAttribute("XP") or 0, player:GetAttribute("XPNext") or 80
		lvlNum.Text = tostring(lvl)
		lvlWord.Text = "LEVEL " .. lvl
		repLbl.Text = short(player:GetAttribute("Rep") or 0)
		setFill(xpFill, xp / math.max(nxt, 1))
		xpLbl.Text = short(xp) .. " / " .. short(nxt) .. " XP"
		if lastLevel and lvl > lastLevel then bounce(lvlSc, 1.5) end
		lastLevel = lvl
	end
	for _, a in ipairs({ "Level", "XP", "XPNext", "Rep" }) do player:GetAttributeChangedSignal(a):Connect(refreshLevel) end
	refreshLevel()

	local cashPill, cashVal, cashSc = pill(left, "cash", 262, Color3.fromRGB(150, 255, 140))
	cashPill.Position = UDim2.fromOffset(0, 78)
	plusButton(cashPill, function() A.store("cash") end)
	local gemPill, gemVal, gemSc = pill(left, "gem", 262, Color3.fromRGB(130, 225, 255))
	gemPill.Position = UDim2.fromOffset(0, 130)
	plusButton(gemPill, function() A.store("gems") end)
	local strPill, strVal, strSc = pill(left, "strength", 262, Color3.fromRGB(255, 180, 110))
	strPill.Position = UDim2.fromOffset(0, 182)
	strVal.Size = UDim2.new(1, -60, 1, 0)
	local powLbl = text({ AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0), Size = UDim2.fromOffset(110, 20), Font = ROUND, TextSize = 13,
		TextColor3 = Color3.fromRGB(170, 215, 255), TextXAlignment = Enum.TextXAlignment.Right, Text = "", ZIndex = 3, Parent = strPill })
	tstroke(powLbl, 2)
	local bonusLbl = text({ Position = UDim2.fromOffset(4, 232), Size = UDim2.fromOffset(262, 34), Font = ROUND, TextSize = 13, TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top, TextColor3 = Color3.fromRGB(140, 245, 150), Text = "", Parent = left })
	tstroke(bonusLbl, 2)

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

	-- menu grid
	local grid = new("Frame", { Name = "Menu", BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 268), Size = UDim2.fromOffset(262, 340), Parent = left })
	local gridLayout = new("UIGridLayout", { CellSize = UDim2.fromOffset(96, 104), CellPadding = UDim2.fromOffset(12, 8), SortOrder = Enum.SortOrder.LayoutOrder,
		FillDirectionMaxCells = 2, Parent = grid })
	local menu = {}
	local defs = {
		{ "jobs", "JOBS", Color3.fromRGB(255, 205, 70), Color3.fromRGB(240, 130, 20), A.jobs },
		{ "shop", "SHOP", Color3.fromRGB(110, 200, 255), Color3.fromRGB(40, 110, 230), A.shop },
		{ "upgrades", "UPGRADES", Color3.fromRGB(130, 240, 120), Color3.fromRGB(30, 160, 70), A.upgrades },
		{ "company", "COMPANY", Color3.fromRGB(120, 220, 255), Color3.fromRGB(30, 140, 210), A.company },
		{ "rebirth", "REBIRTH", Color3.fromRGB(205, 150, 255), Color3.fromRGB(125, 65, 230), A.rebirth },
		{ "locations", "PLACES", Color3.fromRGB(255, 140, 150), Color3.fromRGB(225, 55, 85), A.locations },
	}
	for i, d in ipairs(defs) do
		local api = bigButton(grid, d[1], d[2], d[3], d[4], 96, 104, d[5])
		api.button.LayoutOrder = i
		menu[d[1]] = api
	end

	---------------------------------------------------------------------------
	-- RIGHT: Store, Daily, Spin, Gift, More
	---------------------------------------------------------------------------
	local right = new("Frame", { Name = "Right", BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 88), Size = UDim2.fromOffset(84, 520), Parent = root })
	local rightScale = new("UIScale", { Parent = right })
	local rightLayout = new("UIGridLayout", { CellSize = UDim2.fromOffset(84, 94), CellPadding = UDim2.fromOffset(8, 6), SortOrder = Enum.SortOrder.LayoutOrder,
		FillDirectionMaxCells = 1, HorizontalAlignment = Enum.HorizontalAlignment.Right, Parent = right })
	local storeB = bigButton(right, "store", "STORE", Color3.fromRGB(255, 225, 90), Color3.fromRGB(245, 150, 20), 84, 94, function() A.store() end)
	local dailyB = bigButton(right, "daily", "DAILY", Color3.fromRGB(255, 150, 175), Color3.fromRGB(225, 60, 105), 84, 94, A.daily)
	local spinB = bigButton(right, "spin", "SPIN", Color3.fromRGB(190, 150, 255), Color3.fromRGB(110, 60, 220), 84, 94, A.spin)
	local giftB = bigButton(right, "gift", "GIFT", Color3.fromRGB(255, 160, 220), Color3.fromRGB(215, 60, 160), 84, 94, function()
		local i, _, left = c.playtime.Next()
		if i and left <= 0 then c.playtime.Claim(i) else toggle("Gifts", c.playtime.Show) end
	end)
	local moreB
	for i, b in ipairs({ storeB, dailyB, spinB, giftB }) do b.button.LayoutOrder = i end

	-- More popup
	local pop = panel({ Name = "MorePopup", AnchorPoint = Vector2.new(1, 0), Size = UDim2.fromOffset(3 * 78 + 26, 2 * 86 + 26), Visible = false, ZIndex = 8, Parent = root }, 20)
	local popGrid = new("Frame", { Position = UDim2.fromOffset(13, 13), Size = UDim2.new(1, -26, 1, -26), BackgroundTransparency = 1, Parent = pop })
	new("UIGridLayout", { CellSize = UDim2.fromOffset(72, 80), CellPadding = UDim2.fromOffset(6, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = popGrid })
	local popScale = new("UIScale", { Parent = pop })
	local function closePop() pop.Visible = false end
	local musicB
	local popDefs = {
		{ "trade", "TRADE", Color3.fromRGB(130, 240, 140), Color3.fromRGB(30, 160, 80), function() toggle("Trade", _G.__CE_ShowTrade) end },
		{ "cars", "CARS", Color3.fromRGB(255, 140, 120), Color3.fromRGB(215, 55, 55), function() toggle("Garage", _G.__CE_ShowGarage) end },
		{ "codes", "CODES", Color3.fromRGB(185, 155, 255), Color3.fromRGB(105, 70, 225), function() toggle("Codes", _G.__CE_ShowCodes) end },
		{ "invite", "INVITE", Color3.fromRGB(255, 160, 200), Color3.fromRGB(225, 70, 140), function() if _G.__CE_Invite then _G.__CE_Invite() end end },
		{ "portfolio", "TROPHIES", Color3.fromRGB(255, 220, 110), Color3.fromRGB(230, 145, 25), function() toggle("Portfolio", _G.__CE_ShowPortfolio) end },
		{ "music", "MUSIC", Color3.fromRGB(150, 205, 255), Color3.fromRGB(70, 110, 230), function() if _G.__CE_ToggleMusic then _G.__CE_ToggleMusic() end end },
	}
	for i, d in ipairs(popDefs) do
		local api = bigButton(popGrid, d[1], d[2], d[3], d[4], 72, 80, function() if d[1] ~= "music" then closePop() end; d[5]() end)
		api.button.LayoutOrder = i
		if d[1] == "music" then musicB = api end
	end
	local function refreshMusic()
		if musicB then musicB.setLabel(gui:GetAttribute("MusicOn") == false and "MUSIC OFF" or "MUSIC") end
	end
	gui:GetAttributeChangedSignal("MusicOn"):Connect(refreshMusic)
	refreshMusic()
	moreB = bigButton(right, "more", "MORE", Color3.fromRGB(170, 185, 225), Color3.fromRGB(85, 95, 150), 84, 94, function()
		pop.Visible = not pop.Visible
		if pop.Visible then
			popScale.Scale = 0.85
			UI.tween(popScale, 0.2, { Scale = 1 }, Enum.EasingStyle.Back)
		end
	end)
	moreB.button.LayoutOrder = 5

	---------------------------------------------------------------------------
	-- layout (computer / phone, tall / short screens)
	---------------------------------------------------------------------------
	local segQW, segCW = 0.32, 0.43
	local function layout()
		local compact = gui:GetAttribute("Compact") == true
		local s = math.max(c.uiScale.Scale, 0.01)
		local W, H = camera.ViewportSize.X / s, camera.ViewportSize.Y / s
		local barH = compact and 60 or 70
		bar.Size = UDim2.new(1, -24, 0, barH)
		local top = 8 + barH + 10
		gui:SetAttribute("TopBand", top)
		-- top bar segments
		local megaOn = RS:GetAttribute("MegaStatus") ~= nil and (not compact or RS:GetAttribute("MegaStatus") == "active")
		local qw, cw = 0.32, 0.43
		if not megaOn then qw, cw = 0.42, 0.58 elseif compact then qw, cw = 0.34, 0.42 end
		if W < 900 and megaOn then qw, cw = 0.33, 0.40 end
		segQW, segCW = qw, cw
		segQ.Size = UDim2.new(qw, 0, 1, 0)
		segC.Position = UDim2.new(qw, 0, 0, 0)
		segC.Size = UDim2.new(cw, 0, 1, 0)
		segM.Position = UDim2.new(qw + cw, 0, 0, 0)
		segM.Size = UDim2.new(1 - qw - cw, 0, 1, 0)
		segM.Visible = megaOn
		div1.Position = UDim2.new(qw, 0, 0.5, 0)
		div2.Position = UDim2.new(qw + cw, 0, 0.5, 0)
		div2.Visible = megaOn
		local ic = compact and 50 or 60
		for _, o in ipairs({ qIcon, cIcon }) do o.Size = UDim2.fromOffset(ic, ic) end
		mIcon.Size = UDim2.fromOffset(ic - 4, ic - 4)
		-- left column: smaller on phones; the menu grid goes 3-wide when the screen is short
		local ls = compact and (H < 620 and 0.72 or 0.8) or 1
		leftScale.Scale = ls
		left.Position = UDim2.fromOffset(12, top)
		local avail = (H - top - (compact and 150 or 20)) / ls
		local cols = (268 + 3 * 112 > avail) and 3 or 2
		gridLayout.FillDirectionMaxCells = cols
		grid.Size = UDim2.fromOffset(cols * 108, 340)
		-- right column: one column, or two on short screens
		local rs = compact and 0.8 or 1
		rightScale.Scale = rs
		right.Position = UDim2.new(1, -12, 0, top)
		local rAvail = (H - top - (compact and 150 or 90)) / rs
		local rCols = (5 * 100 > rAvail) and 2 or 1
		rightLayout.FillDirectionMaxCells = rCols
		right.Size = UDim2.fromOffset(rCols * 92 - 8, 520)
		-- More popup opens to the left of the right column, level with the More button
		pop.Position = UDim2.new(1, -12 - (rCols * 92) * rs - 8, 0, top + (rCols == 1 and 4 * 100 or 2 * 100) * rs)
		popScale.Scale = rs
	end
	gui:GetAttributeChangedSignal("Compact"):Connect(function() task.defer(layout) end)
	camera:GetPropertyChangedSignal("ViewportSize"):Connect(function() task.defer(layout) end)
	RS:GetAttributeChangedSignal("MegaStatus"):Connect(layout)
	layout()
	task.delay(1, layout)

	---------------------------------------------------------------------------
	-- live updates
	---------------------------------------------------------------------------
	local lj = c.legacyJob
	local KIND_ICON = { mega = "mega", home = "home", help = "crew", contract = "contract" }
	local lastKind
	RunService.RenderStepped:Connect(function(dt)
		root.Visible = gui:GetAttribute("Cinematic") ~= true
		-- money counter
		local target = player:GetAttribute("Money") or 0
		if math.abs(target - shownMoney) < 0.5 then shownMoney = target else shownMoney += (target - shownMoney) * math.min(1, dt * 8) end
		cashVal.Text = Config.FormatMoney(shownMoney)
		-- bonuses (computed by the main script)
		local b = c.boostLbl.Text
		bonusLbl.Text = (b:gsub("^Bonus: ", ""))
		-- contract segment
		if lj.panel.Visible then
			local tag = lj.tag.Text
			local kind = tag:find("MEGA") and "mega" or (tag:find("HELPING") and "help") or (tag:find("HOME") and "home") or "contract"
			if kind ~= lastKind then
				lastKind = kind
				Icons.set(cIcon, KIND_ICON[kind])
			end
			cTag.Text = kind == "mega" and "MEGA PROJECT" or (kind == "home" and "HOME BUILD")
				or (kind == "help" and (tag:gsub("^[^%w]+", ""):gsub("·.*$", ""))) or "ACTIVE CONTRACT"
			local stage = lj.stage.Text -- "2/5  Walls"
			local n, name = stage:match("^(%d+/%d+)%s+(.+)$")
			cTitle.Text = (lj.title.Text ~= "" and lj.title.Text or "Construction") .. (name and ("  <font color='#ffd27a' size='17'>" .. name .. " " .. n .. "</font>") or "")
			setFill(cFill, lj.fill.Size.X.Scale)
			cPct.Text = lj.pct.Text
			local t = lj.timer.Text
			local bonus = t:match("Speed bonus: ([%d:]+)")
			local rush = t:match("RUSH ORDER: (%d+)s")
			if rush then
				cTimer.Text = "RUSH  " .. rush .. "s!"
				cTimer.TextColor3 = Color3.fromRGB(255, 150, 70)
			elseif bonus then
				cTimer.Text = "SPEED BONUS " .. bonus
				cTimer.TextColor3 = Color3.fromRGB(130, 240, 140)
			else
				cTimer.Text = t:match("⏱ ([%d:]+)") or ""
				cTimer.TextColor3 = Color3.fromRGB(190, 195, 215)
			end
			cBar.Visible = true
			cFind.Visible = false
			cX.Visible = lj.abandon.Visible
			cTimer.Position = UDim2.new(1, cX.Visible and -46 or -10, 0, 7)
			cXl.Text = os.clock() < confirmUntil and "?" or "X"
		else
			if lastKind ~= "none" then lastKind = "none"; Icons.set(cIcon, "contract") end
			cTag.Text = "NO CONTRACT"
			cTitle.Text = "Take a job and start building!"
			cTimer.Text = ""
			cBar.Visible = false
			cX.Visible = false
			cFind.Visible = true
		end
		-- mega segment
		local status = RS:GetAttribute("MegaStatus")
		if status and segM.Visible then
			local mleft = math.max(0, (RS:GetAttribute("MegaNext") or 0) - workspace:GetServerTimeNow())
			if status == "active" then
				local st = c.Jobs:FindFirstChild(RS:GetAttribute("MegaJob") or "")
				local tot = st and st:GetAttribute("Total") or 0
				mTag.Text = "CITY TOWER · BUILD TOGETHER"
				mLine.Text = math.floor(tot * 100) .. "%  <font color='#d9c2ff' size='15'>" .. (st and (st:GetAttribute("StageName") or "") or "") .. "</font>"
				setFill(mFill, tot)
				mBar.Visible = true
				mGo.Visible = true
			else
				mTag.Text = status == "done" and "CITY TOWER · COMPLETE" or "MEGA PROJECT"
				mLine.Text = "Next tower in " .. fmtTime(mleft)
				mBar.Visible = false
				mGo.Visible = false
			end
		end
		-- badge pulse
		local p = 1 + math.sin(os.clock() * 6) * 0.08
		for sc in pairs(pulsing) do sc.Scale = p end
		-- the popup never stays open behind a window
		if pop.Visible and c.modalOpen() then pop.Visible = false end
	end)

	-- right column labels and badges (spin / gift timers)
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
		spinB.setLabel(ready and "SPIN!" or (sleft and sleft > 0 and fmtTime(sleft) or "SPIN"))
		spinB.setBadge(ready)
		dailyB.setBadge(player:GetAttribute("MissionsReady") or 0)
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
