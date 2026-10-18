-- BlockRise Empire 2.0 - client: the HUD (money, gems, Rebirth bar, HAMMERS / SHOP / MENU, NEXT), the building card
-- (tap a lot), taps on the building site, the construction overlay, the world tags (income, BUILD / UPGRADE, the
-- for-sale boards, the prompts) and the effects (sparks, coins, pops).
-- PREMIUM_UI (2026-10-18): everything redrawn with the UI kit v2 (UI.lua): dark HUD capsules with + buttons, glossy
-- 3D buttons, panels with a header ribbon over a dimmed screen, segmented tabs, chips, progress bars with a shimmer.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Debris = game:GetService("Debris")

local plr = Players.LocalPlayer
local C = require(ReplicatedStorage.Shared.Config2)
local Hammers = require(ReplicatedStorage.Shared.Hammers)
local UI = require(script:WaitForChild("UI"))
local BuildFX = require(script:WaitForChild("BuildFX"))
task.spawn(BuildFX.start)
-- cars driving the permanent streets (Traffic.lua)
task.spawn(function()
	local mod = script:WaitForChild("Traffic", 10)
	local ok, T = pcall(require, mod)
	if ok and T then T.start() else warn("[HUD2] traffic: " .. tostring(T)) end
end)
local new = UI.new
local C3 = Color3.fromRGB
local WHITE = Color3.new(1, 1, 1)
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local CityRF = Remotes:WaitForChild("City")
local TapRE = Remotes:WaitForChild("CityTap")
local FeedbackRE = Remotes:WaitForChild("Feedback")
local HitsRE = Remotes:WaitForChild("CrewHits")

local function attr(n, d) local v = plr:GetAttribute(n) if v == nil then return d end return v end

-- the lots, from the server's "Lots" attribute: owned:lv:style:planned
local function lots()
	local out = {}
	local s = attr("Lots", "")
	local i = 0
	for part in s:gmatch("[^,]+") do
		i += 1
		local o, lv, st, pl = part:match("(%d):(%d+):(%d):(%d+)")
		out[i] = { owned = o == "1", lv = tonumber(lv) or 0, st = tonumber(st) or 1, planned = tonumber(pl) or 0 }
	end
	return out
end

-- a text that never wraps: the biggest size up to `max` that fits `width`
local function fit(label, text, max, width, min)
	local s = max
	while s > (min or 12) and UI.textWidth(text, s) > width do s -= 1 end
	label.TextSize = s
	label.Text = text
end

-- a speech-bubble tail (a diamond under a bubble)
local function tail(parent, color, props)
	local col = UI.Colors[color]
	local d = new("Frame", { Name = "Tail", BackgroundColor3 = WHITE, Rotation = 45, AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(props.S or 20, props.S or 20),
		Position = props.Position, ZIndex = props.ZIndex or 1, Parent = parent })
	UI.corner(d, 4)
	UI.stroke(d, 3)
	local g = UI.gradient(d, col[2], UI.darker(col[2], 0.35), 45)
	return d, g
end

-- Screen ------------------------------------------------------------------------------------------------
local gui = new("ScreenGui", { Name = "HUD2", ResetOnSpawn = false, IgnoreGuiInset = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, Parent = plr:WaitForChild("PlayerGui") })
pcall(function() gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets end)
-- the billboards in the world: straight in PlayerGui (inside a ScreenGui or a Folder they are never drawn), kept on respawn
local worldGui = plr.PlayerGui
local root = new("Frame", { Name = "Root", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = gui })
local scale = new("UIScale", { Parent = root })
local logicalH, logicalW = 640, 1150
local onResize = {}
local function rescale()
	local v = workspace.CurrentCamera.ViewportSize
	local s = math.clamp(math.min(v.X / 1150, v.Y / 640), 0.62, 1.2)
	scale.Scale = s
	root.Size = UDim2.fromScale(1 / s, 1 / s)
	local abs = gui.AbsoluteSize
	logicalH = (abs.Y > 0 and abs.Y or v.Y) / s
	logicalW = (abs.X > 0 and abs.X or v.X) / s
	for _, f in ipairs(onResize) do pcall(f) end
end
workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(rescale)
gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(rescale)

local windows = {}

-- Top-left: money, gems, Rebirth (PREMIUM_UI v2, 2026-10-18: a compact column in the corner; the middle of the screen
-- belongs to the game) ----------------------------------------------------------------------------------------
local top = new("Frame", { Name = "Top", BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 0), Size = UDim2.fromOffset(300, 184), ZIndex = 8, Parent = root })
local moneyPill = UI.pill({ Name = "Money", Style = "dark", Size = UDim2.fromOffset(250, 54), Position = UDim2.fromOffset(36, 10), Parent = top })
local cashIcon = UI.icon("cash", { Size = UDim2.fromOffset(74, 74), Position = UDim2.new(0, -34, 0.5, -39), ZIndex = 6, Parent = moneyPill })
cashIcon.Rotation = -8
local moneyText = UI.text({ Text = "$0", Size = UDim2.new(1, -96, 0, 40), Position = UDim2.fromOffset(44, 6), XAlign = Enum.TextXAlignment.Left, ZIndex = 5, StrokeTh = 3,
	Max = 36, Gradient = { WHITE, C3(214, 255, 196) }, Parent = moneyPill })
UI.plus({ Name = "AddCash", Color = "green", Size = 40, Position = UDim2.new(1, -46, 0.5, -22), ZIndex = 5, Parent = moneyPill,
	OnClick = function() if windows.open then windows.open("SHOP", { tab = "packs" }) end end })
local incomeChip = UI.chip({ Name = "Income", Color = "green", Icon = "up_cash", Height = 26, TextSize = 17, Text = "+$0/s", Position = UDim2.fromOffset(50, 42), ZIndex = 7, Parent = moneyPill })

local gemPill = UI.pill({ Name = "Gems", Style = "dark", Size = UDim2.fromOffset(200, 46), Position = UDim2.fromOffset(36, 86), Parent = top })
UI.icon("gem", { Size = UDim2.fromOffset(58, 58), Position = UDim2.new(0, -30, 0.5, -30), ZIndex = 6, Parent = gemPill })
local gemText = UI.text({ Text = "0", Size = UDim2.new(1, -86, 0, 32), Position = UDim2.fromOffset(40, 7), XAlign = Enum.TextXAlignment.Left, ZIndex = 5, StrokeTh = 3,
	Max = 28, Gradient = { WHITE, C3(236, 214, 255) }, Parent = gemPill })
UI.plus({ Name = "AddGems", Color = "purple", Size = 34, Position = UDim2.new(1, -40, 0.5, -19), ZIndex = 5, Parent = gemPill,
	OnClick = function() if windows.open then windows.open("SHOP", { tab = "packs" }) end end })
local money = UI.counter(moneyText, function(v) return C.Money(v) end)
local gems = UI.counter(gemText, function(v) return C.Fmt(v) end)

-- the Rebirth bar (a button when it is ready)
local rebBar = new("Frame", { Name = "Rebirth", BackgroundTransparency = 1, Size = UDim2.fromOffset(240, 30), Position = UDim2.fromOffset(18, 144), Parent = top })
local rebProg = UI.progress({ Color = "gold", Size = UDim2.new(1, -26, 0, 26), Position = UDim2.fromOffset(26, 2), Text = "REBIRTH 0%", Max = 17, Parent = rebBar })
UI.icon("rebirth_star", { Size = UDim2.fromOffset(46, 46), Position = UDim2.fromOffset(0, -8), ZIndex = 6, Parent = rebBar })
local rebBtn, rebHolder = UI.button({ Name = "RebirthBtn", Color = "gold", Text = "REBIRTH!", IconKey = "rebirth", Size = UDim2.fromOffset(220, 46), Position = UDim2.fromOffset(36, 140),
	Shimmer = true, Max = 26, Parent = top })
rebHolder.Visible = false

-- toasts: one at a time, under the top; they drop in, wait, then pop away
local toastHolder = new("Frame", { Name = "Toasts", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 14), Size = UDim2.fromOffset(600, 50), ZIndex = 9, Parent = root })
local toastQueue, toasting = {}, false
local TOAST_ICON = { green = "upgrades", gold = "star", purple = "gem", blue = "shop", red = nil, white = nil }
local function nextToast()
	if toasting or #toastQueue == 0 then return end
	toasting = true
	local t = table.remove(toastQueue, 1)
	local icon = t.icon or TOAST_ICON[t.color or "white"]
	local ts = 24
	local left = icon and 52 or 22
	local w = left + UI.textWidth(t.text, ts) + 26
	local f = UI.pill({ Color = t.color or "white", Size = UDim2.fromOffset(w, 46), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, -20), Parent = toastHolder })
	if icon then UI.icon(icon, { Size = UDim2.fromOffset(56, 56), Position = UDim2.new(0, -10, 0.5, -29), ZIndex = 6, Parent = f }) end
	UI.text({ Text = t.text, Scaled = false, TextSize = ts, Size = UDim2.new(1, -left - 18, 1, 0), Position = UDim2.fromOffset(left, 0), XAlign = Enum.TextXAlignment.Left,
		Color = t.ink and UI.Ink or WHITE, Stroke = not t.ink, StrokeTh = 2.4, ZIndex = 5, Parent = f })
	UI.pop(f, 0.6)
	TweenService:Create(f, TweenInfo.new(0.3, Enum.EasingStyle.Back), { Position = UDim2.new(0.5, 0, 0, 0) }):Play()
	task.delay(t.time or 2.4, function()
		local sc = f:FindFirstChildOfClass("UIScale")
		if sc then TweenService:Create(sc, TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.In), { Scale = 0 }):Play() end
		task.wait(0.2)
		f:Destroy()
		toasting = false
		nextToast()
	end)
end
local function toast(text, color, time, icon)
	table.insert(toastQueue, { text = text, color = color, time = time, icon = icon, ink = (color == nil or color == "white") })
	if #toastQueue > 3 then table.remove(toastQueue, 1) end
	nextToast()
end

-- Left: HAMMERS, SHOP, MENU -----------------------------------------------------------------------------------
local left = new("Frame", { Name = "Left", BackgroundTransparency = 1, Position = UDim2.fromOffset(18, 200), Size = UDim2.fromOffset(96, 340), ZIndex = 8, Parent = root })
new("UIListLayout", { Padding = UDim.new(0, 16), SortOrder = Enum.SortOrder.LayoutOrder, Parent = left })
local function sideButton(name, icon, color, order, parent)
	local btn, holder = UI.button({ Name = name, Color = color, Size = UDim2.fromOffset(88, 80), Order = order, Radius = 22, Parent = parent or left,
		OnClick = function() if windows.open then windows.open(name) end end })
	local ic = UI.icon(icon, { Size = UDim2.fromOffset(66, 66), Position = UDim2.new(0.5, -33, 0, -2), ZIndex = btn.ZIndex + 3, Parent = btn })
	ic.Rotation = -6
	UI.text({ Text = name, Size = UDim2.new(1, 12, 0, 26), Position = UDim2.new(0, -6, 1, -22), ZIndex = btn.ZIndex + 5, Max = 21, StrokeTh = 2.8, Shadow = 2, Parent = btn })
	return btn, holder
end
sideButton("HAMMERS", "rbxassetid://71920003497651", "blue", 1)
sideButton("SHOP", "store", "gold", 2)
sideButton("MENU", "more", "purple", 3)
-- Right: FREE GIFTS (a badge with how many are waiting; else the time to the next one). Under the dimmed screen
-- while a window is open
local right = new("Frame", { Name = "Right", BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -18, 0, 200), Size = UDim2.fromOffset(96, 130), ZIndex = 4, Parent = root })
local giftBtn = sideButton("GIFTS", "gift", "pink", 1, right)
local giftBadge, giftBadgeText = UI.badge(giftBtn, "1")
giftBadge.Visible = false
local giftTimer = UI.chip({ Color = "dark", Icon = "timer", Height = 26, TextSize = 16, Text = "0:00", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 8, 0, 96), ZIndex = 6, Parent = right })
giftTimer.frame.Visible = false
local function refreshGifts()
	local n = attr("GiftsReady", 0)
	giftBadge.Visible = n > 0
	giftBadgeText.Text = tostring(n)
	local nx = attr("GiftNext", -1)
	giftTimer.frame.Visible = n == 0 and nx >= 0
	if nx >= 0 then giftTimer.set(string.format("%d:%02d", nx // 60, nx % 60)) end
end
plr:GetAttributeChangedSignal("GiftsReady"):Connect(function()
	local before = giftBadge.Visible
	refreshGifts()
	if giftBadge.Visible and not before then UI.pop(giftBadge, 1.5) end
end)
plr:GetAttributeChangedSignal("GiftNext"):Connect(refreshGifts)
refreshGifts()
-- HOME: only when you are far from your city
local _homeBtn, homeHolder = UI.button({ Name = "HOME", Color = "green", Text = "HOME", IconKey = "home", Size = UDim2.fromOffset(88, 46), Order = 4, Parent = left, Max = 20,
	OnClick = function() CityRF:InvokeServer("home") end })
homeHolder.Visible = false

-- Bottom: NEXT ----------------------------------------------------------------------------------------------
local NEXT_W = 540
local nextHolder = new("Frame", { Name = "Next", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -16), Size = UDim2.fromOffset(NEXT_W, 68), Parent = root })
local nextShadow = new("Frame", { BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.75, Size = UDim2.fromScale(1, 1), Position = UDim2.fromOffset(0, 6), Parent = nextHolder })
UI.corner(nextShadow, UDim.new(1, 0))
local nextPill = UI.pill({ Color = "white", Size = UDim2.fromScale(1, 1), StrokeTh = 3.5, ZIndex = 2, Parent = nextHolder })
local nextTag = UI.pill({ Color = "green", Size = UDim2.fromOffset(112, 52), Position = UDim2.new(0, 8, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), ZIndex = 4, Parent = nextPill })
UI.icon("quest", { Size = UDim2.fromOffset(50, 50), Position = UDim2.new(0, -8, 0.5, -26), ZIndex = 7, Parent = nextTag })
UI.text({ Text = "NEXT", Size = UDim2.new(1, -46, 0.6, 0), Position = UDim2.new(0, 38, 0.2, 0), ZIndex = 7, StrokeTh = 2.6, Max = 26, Parent = nextTag })
local NEXT_TX = 134
local NEXT_TW = NEXT_W - NEXT_TX - 22
local nextText = UI.text({ Text = "", Scaled = false, TextSize = 24, Size = UDim2.fromOffset(NEXT_TW, 30), Position = UDim2.fromOffset(NEXT_TX, 6), XAlign = Enum.TextXAlignment.Left,
	Color = UI.Ink, Stroke = false, ZIndex = 5, Parent = nextPill })
local nextBar = UI.progress({ Color = "green", Size = UDim2.fromOffset(NEXT_TW, 20), Position = UDim2.fromOffset(NEXT_TX, 39), Max = 15, TextStroke = 2, StrokeTh = 2.5, ZIndex = 5, Parent = nextPill })

-- the goals, the first one not done yet: text, progress text, the lot to point at
local function goal()
	local L = lots()
	local built, n4, ownedLots, maxed = 0, 0, 0, 0
	local cap = attr("Cap", 4)
	for i, l in ipairs(L) do
		if l.owned then ownedLots += 1 end
		if l.lv >= 1 then built += 1 end
		if l.lv >= 2 then n4 += 1 end
		if l.owned and l.lv >= cap then maxed += 1 end
	end
	local reb = attr("Rebirths", 0)
	if built < 1 then return "Tap the glowing lot to build!", "", 1 end
	if built < 2 then return "Build a second building", built .. "/2", 2 end
	if n4 < 1 then return "Upgrade a building", "0/1" end
	if built < 4 then return "Build 4 buildings", built .. "/4" end
	if attr("Hires", 0) < 1 and attr("Money", 0) >= C.HirePrice[1] then return "Hire a worker: HAMMERS > CREW", "0/1" end
	local openLots = 8 * math.min(3, reb + 1)
	if ownedLots < openLots then return "Buy new land (the sale sign)", (ownedLots // 4) .. "/" .. (openLots // 4) end
	if built < ownedLots then return "Build on every lot", built .. "/" .. ownedLots end
	if maxed < ownedLots then return "Upgrade every lot to " .. C.Levels[cap].name, maxed .. "/" .. ownedLots end
	if reb < #C.RebirthCost then return "REBIRTH for x" .. C.RebirthMult .. " income!", math.floor(math.min(1, attr("Money", 0) / math.max(1, attr("RebirthCost", 1))) * 100) .. "%" end
	return "Your city is complete!", ""
end
-- "3/8" -> 0.375, "71%" -> 0.71
local function progOf(s)
	if not s or s == "" then return nil end
	local a, b = s:match("^(%d+)/(%d+)$")
	if a then return tonumber(a) / math.max(1, tonumber(b)) end
	local p = s:match("^(%d+)%%$")
	if p then return tonumber(p) / 100 end
	return nil
end

-- Building card -------------------------------------------------------------------------------------------------
local CARD_W, CARD_H = 560, 248
local cardBg, card, cardHead = UI.panel({ Name = "Card", Size = UDim2.fromOffset(CARD_W, CARD_H), AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -100),
	Title = "", Color = "blue", HeadHeight = 52, Radius = 22, TitleMax = 30, Visible = false, ZIndex = 3, Parent = root })
local cardTitle = cardHead.title
cardTitle.Size = UDim2.new(1, -190, 0, 32) -- (room for STYLE and the close button)
UI.close({ Size = 46, Position = UDim2.new(1, -30, 0, -16), ZIndex = 10, Parent = cardBg, OnClick = function() card.Visible = false end })
-- the picture: a sky well with the model turning on it
local well = UI.well({ Size = UDim2.fromOffset(168, 168), Position = UDim2.fromOffset(16, 64), Color = WHITE, Transparency = 0, Radius = 18, Parent = cardBg })
UI.gradient(well, C3(160, 220, 255), C3(226, 244, 255))
local pedestal = new("Frame", { BackgroundColor3 = WHITE, BackgroundTransparency = 0.35, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 1, -30), Size = UDim2.fromOffset(130, 34), ZIndex = 4, Parent = well })
UI.corner(pedestal, UDim.new(1, 0))
local view = new("ViewportFrame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Ambient = C3(200, 200, 210), LightColor = C3(255, 250, 240), LightDirection = Vector3.new(-1, -1.5, -0.6), ZIndex = 5, Parent = well })
local vcam = new("Camera", { Parent = view })
view.CurrentCamera = vcam
local COL_X = 200
local COL_W = CARD_W - COL_X - 22
local cardLine1 = UI.text({ Text = "", Scaled = false, TextSize = 26, Size = UDim2.fromOffset(COL_W, 30), Position = UDim2.fromOffset(COL_X, 64), XAlign = Enum.TextXAlignment.Left, Color = UI.Ink, Stroke = false, ZIndex = 5, Parent = cardBg })
local chipRow = new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(COL_W, 30), Position = UDim2.fromOffset(COL_X + 10, 102), ZIndex = 5, Parent = cardBg })
new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 22), SortOrder = Enum.SortOrder.LayoutOrder, VerticalAlignment = Enum.VerticalAlignment.Center, Parent = chipRow })
local incChip = UI.chip({ Color = "green", Icon = "cash", Height = 30, TextSize = 19, Order = 1, ZIndex = 5, Parent = chipRow })
local timeChip = UI.chip({ Color = "blue", Icon = "timer", Height = 30, TextSize = 19, Order = 2, ZIndex = 5, Parent = chipRow })
local cardLine2 = UI.text({ Text = "", Scaled = false, TextSize = 19, Size = UDim2.fromOffset(COL_W, 22), Position = UDim2.fromOffset(COL_X, 138), XAlign = Enum.TextXAlignment.Left, Color = UI.Muted, Stroke = false, ZIndex = 5, Parent = cardBg })
local cardBtn, cardBtnHolder, cardBtnLabel = UI.button({ Name = "Do", Color = "green", Text = "BUILD", Sub = " ", Size = UDim2.fromOffset(COL_W, 64), Position = UDim2.fromOffset(COL_X, 164), Shimmer = true, Max = 30, SubMax = 20, ZIndex = 5, Parent = cardBg })
local cardSub = cardBtn:FindFirstChild("Sub")
local styleBtn, styleHolder = UI.button({ Name = "Style", Color = "purple", Text = "STYLE", Size = UDim2.fromOffset(92, 36), Position = UDim2.new(1, -150, 0, 8), Radius = 13, Max = 18, Depth = 4, ZIndex = 8, Parent = cardBg })
local cardLot, cardAction, previewKey = nil, nil, nil

-- the main button: a label, an optional second line (the price), a colour
local function cta(text, sub, color)
	cardBtnLabel.Text = text
	cardSub.Visible = sub ~= nil and sub ~= ""
	cardSub.Text = sub or ""
	if cardSub.Visible then
		cardBtnLabel.Size = UDim2.new(1, -16, 0.5, 0)
		cardBtnLabel.Position = UDim2.new(0, 8, 0.08, 0)
	else
		cardBtnLabel.Size = UDim2.new(1, -16, 0.62, 0)
		cardBtnLabel.Position = UDim2.new(0, 8, 0.19, 0)
	end
	UI.recolor(cardBtn, color)
end

-- the card's picture: the live game's blueprint of that level and style, drawn here
local function setPreview(lv, st)
	local key = lv .. "_" .. st
	if previewKey == key then return end
	previewKey = key
	for _, c in ipairs(view:GetChildren()) do if c:IsA("Model") then c:Destroy() end end
	local _, bp = C.StyleOf(lv, st)
	local m = bp and BuildFX.preview(bp, view)
	if not m then return end
	local _, size = m:GetBoundingBox()
	-- frame the whole model: its bounding sphere fills the view, seen from the front-right, a bit from above
	local r = size.Magnitude / 2
	vcam.FieldOfView = 34
	local dist = r / math.sin(math.rad(17)) * 1.12
	local centre = Vector3.new(0, size.Y / 2, 0)
	vcam.CFrame = CFrame.lookAt(centre + Vector3.new(0.55, 0.32, -0.77).Unit * dist, centre)
end
RunService.RenderStepped:Connect(function(dt)
	if card.Visible then
		for _, c in ipairs(view:GetChildren()) do if c:IsA("Model") then c:PivotTo(c:GetPivot() * CFrame.Angles(0, dt * 0.6, 0)) end end
	end
end)

local function chips(income, time)
	incChip.frame.Visible = income ~= nil
	if income then incChip.set(income) end
	timeChip.frame.Visible = time ~= nil
	if time then timeChip.set(time) end
end

local function refreshCard()
	if not card.Visible or not cardLot then return end
	local L = lots()
	local l = L[cardLot]
	if not l then return end
	local cap = attr("Cap", 4)
	local moneyNow = attr("Money", 0)
	local busy = attr("Queue", 0) >= C.QueueSize
	local mult = C.RebirthMultiplier(attr("Rebirths", 0))
	styleHolder.Visible = l.owned and l.lv > 0
	if not l.owned then
		cardHead.color("blue")
		cardTitle.Text = "LAND FOR SALE"
		fit(cardLine1, "Buy this land at its sale sign", 26, COL_W)
		chips(nil, nil)
		cardLine2.Text = "Walk to the board and hold the button"
		cta("OK", nil, "blue")
		cardAction = function() card.Visible = false end
		setPreview(1, 1)
		return
	end
	local cur = l.lv > 0 and C.Levels[l.lv] or nil
	cardTitle.Text = cur and ("LV " .. l.lv .. "  " .. (C.StyleOf(l.lv, l.st)):upper()) or "EMPTY LOT"
	local nextLv = l.planned + 1
	if l.planned >= cap then
		cardHead.color("gold")
		setPreview(math.max(1, l.lv), l.st)
		fit(cardLine1, cur and "This building makes" or "", 26, COL_W)
		chips(cur and (C.Money(cur.income * mult) .. "/s") or nil, nil)
		cardLine2.Text = l.planned >= C.MaxLevel and "It is at the top level!" or "Rebirth to build even higher"
		cta(l.planned >= C.MaxLevel and "MAX LEVEL" or "REBIRTH TO GO HIGHER", nil, "grey")
		cardAction = nil
		return
	end
	cardHead.color(l.planned == 0 and "green" or "blue")
	local nx = C.Levels[nextLv]
	setPreview(nextLv, l.st)
	local gain = (nx.income - (cur and cur.income or 0)) * mult
	fit(cardLine1, (l.planned > l.lv and "Then: " or "Next: ") .. (C.StyleOf(nextLv, l.st)), 26, COL_W)
	chips("+" .. C.Money(gain) .. "/s", nx.time .. "s")
	cardLine2.Text = ""
	local price = nx.cost
	if nextLv == 1 and cardLot == 1 and attr("FreeFirst", false) ~= true and #L > 0 and L[1].lv == 0 then price = 0 end
	if busy then
		cta("CREW BUSY", "Queue " .. attr("Queue", 0) .. "/" .. C.QueueSize, "grey")
		cardAction = nil
	else
		local can = moneyNow >= price
		cta(l.planned == 0 and "BUILD" or "UPGRADE", price == 0 and "FREE" or C.Money(price), can and "green" or "grey")
		if not can then cardLine2.Text = "You need " .. C.Money(price - moneyNow) .. " more" end
		cardAction = function()
			local ok, res = CityRF:InvokeServer("order", cardLot)
			if ok then
				UI.coin()
				card.Visible = false
			else
				toast(tostring(res), "red")
			end
		end
	end
end
cardBtn.Activated:Connect(function() UI.click() if cardAction then cardAction() end end)
styleBtn.Activated:Connect(function()
	UI.click()
	local l = lots()[cardLot]
	if l then CityRF:InvokeServer("style", cardLot, l.st == 1 and 2 or 1) task.wait(0.2) previewKey = nil refreshCard() end
end)
local function openCard(i)
	if windows.close then windows.close() end
	cardLot = i
	card.Visible = true
	previewKey = nil
	refreshCard()
	UI.pop(card, 0.85)
end

-- Taps in the world: a lot of yours opens its card; the site being built gets your hammer ------------------------
local myDistrict = function() return attr("District", 0) end
local function lotUnder(pos)
	local cam = workspace.CurrentCamera
	local ray = cam:ScreenPointToRay(pos.X, pos.Y) -- (input positions are below the top bar inset)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { plr.Character }
	local hit = workspace:Raycast(ray.Origin, ray.Direction * 1500, params)
	if not hit then return nil end
	local x = hit.Instance
	while x and x ~= workspace do
		if x:GetAttribute("Lot") then
			local lotM = x
			while lotM and not lotM:GetAttribute("District") do lotM = lotM.Parent end
			if lotM and lotM:GetAttribute("District") == myDistrict() then return x:GetAttribute("Lot"), hit.Position end
			return nil
		end
		x = x.Parent
	end
end

-- your hammer: held upright like a tool (Roblox's tool pose over walking and idling), a swing on every tap on your
-- building site (the animations play on your own character, so everyone sees them)
local holdTrack, slashTrack
local function setupHold(char)
	local hum = char:WaitForChild("Humanoid", 10)
	local animator = hum and (hum:FindFirstChildOfClass("Animator") or hum:WaitForChild("Animator", 5))
	if not animator then return end
	local a = Instance.new("Animation")
	a.AnimationId = "rbxassetid://507768375"
	local b = Instance.new("Animation")
	b.AnimationId = "rbxassetid://522635514"
	local ok1, h = pcall(function() return animator:LoadAnimation(a) end)
	local ok2, sl = pcall(function() return animator:LoadAnimation(b) end)
	if not (ok1 and ok2) then return end
	h.Looped = true
	h.Priority = Enum.AnimationPriority.Action
	sl.Looped = false
	sl.Priority = Enum.AnimationPriority.Action2
	holdTrack, slashTrack = h, sl
	local function update()
		if char:FindFirstChild("HeldHammer") then
			if not h.IsPlaying then h:Play(0.2) end
		elseif h.IsPlaying then
			h:Stop(0.2)
		end
	end
	char.ChildAdded:Connect(update)
	char.ChildRemoved:Connect(update)
	update()
end
plr.CharacterAdded:Connect(setupHold)
if plr.Character then task.spawn(setupHold, plr.Character) end

local sparks -- defined below
local lastTap = 0
UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then return end
	local pos = input.Position
	local i, hitPos = lotUnder(Vector2.new(pos.X, pos.Y))
	if not i then return end
	if attr("BuildLot", 0) == i and attr("BuildProgress", 0) > 0 and attr("BuildProgress", 0) < 1 then
		if os.clock() - lastTap < 0.12 then return end
		lastTap = os.clock()
		TapRE:FireServer(i)
		if slashTrack and not slashTrack.IsPlaying then
			-- the hammer straightens for the swing, then rests on the shoulder again
			local wd = plr.Character and plr.Character:FindFirstChild("GripWeld", true)
			local base = wd and wd:GetAttribute("Base")
			if base then
				wd.C0 = base
				task.delay(0.5, function() if wd.Parent then wd.C0 = base * CFrame.Angles(math.rad(35), 0, 0) end end)
			end
			slashTrack:Play(0.05, 1, 1.5)
		end
		if sparks then sparks(hitPos, Hammers.ById[attr("HammerKey", "rusty")] and Hammers.ById[attr("HammerKey", "rusty")].r or 1, 10) end
		BuildFX.play("Hammer", 0.42, 0.92 + math.random() * 0.22)
		return
	end
	openCard(i)
end)

-- Effects ------------------------------------------------------------------------------------------------------
local fxFolder = new("Folder", { Name = "FX2", Parent = workspace })
local sparkAtt = new("Attachment", { Parent = workspace.Terrain })
local emitters = {}
local function emitter(r)
	if emitters[r] then return emitters[r] end
	local rar = Hammers.Rarities[r] or Hammers.Rarities[1]
	local pe = new("ParticleEmitter", {
		Texture = "rbxasset://textures/particles/sparkles_main.dds", Color = ColorSequence.new(rar.color:Lerp(Color3.new(1, 1, 1), 0.3), rar.color),
		LightEmission = 0.8, Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.9), NumberSequenceKeypoint.new(1, 0) }),
		Lifetime = NumberRange.new(0.35, 0.6), Speed = NumberRange.new(10, 18), SpreadAngle = Vector2.new(70, 70), Acceleration = Vector3.new(0, -30, 0),
		Rate = 0, Enabled = true, Parent = sparkAtt,
	})
	emitters[r] = pe
	return pe
end
sparks = function(pos, r, n)
	sparkAtt.WorldPosition = pos
	emitter(r):Emit(n or 6)
end
local lastKnock = 0
HitsRE.OnClientEvent:Connect(function(list)
	local cam = workspace.CurrentCamera.CFrame.Position
	for _, h in ipairs(list) do
		if (h[1] - cam).Magnitude < 260 then sparks(h[1], h[2], 5) end
		if os.clock() - lastKnock > 0.22 and (h[1] - cam).Magnitude < 90 then
			lastKnock = os.clock()
			BuildFX.play3D("Hammer", h[1], 0.22, 0.95 + math.random() * 0.2, 90)
		end
	end
end)

-- a floating tag in the world ("+$3/s"): a glossy pill that rises and fades
local function floatText(pos, text, color)
	local p = new("Part", { Anchored = true, CanCollide = false, CanQuery = false, Transparency = 1, Size = Vector3.one, CFrame = CFrame.new(pos), Parent = fxFolder })
	local bb = new("BillboardGui", { Size = UDim2.fromOffset(300, 70), AlwaysOnTop = true, MaxDistance = 400, LightInfluence = 0, Parent = p })
	local w = UI.textWidth(text, 32) + 62
	local pill = UI.pill({ Color = color or "green", Size = UDim2.fromOffset(w, 52), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Parent = bb })
	UI.icon("cash", { Size = UDim2.fromOffset(56, 56), Position = UDim2.new(0, -8, 0.5, -29), ZIndex = 6, Parent = pill })
	UI.text({ Text = text, Scaled = false, TextSize = 32, Size = UDim2.new(1, -52, 1, 0), Position = UDim2.fromOffset(44, 0), ZIndex = 5, StrokeTh = 3, XAlign = Enum.TextXAlignment.Left, Parent = pill })
	UI.pop(pill, 0.3)
	TweenService:Create(p, TweenInfo.new(1.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { CFrame = CFrame.new(pos + Vector3.new(0, 14, 0)) }):Play()
	task.delay(1.2, function()
		local sc = pill:FindFirstChildOfClass("UIScale")
		if sc then TweenService:Create(sc, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.In), { Scale = 0 }):Play() end
	end)
	Debris:AddItem(p, 1.9)
end

-- the lot model of my city
local function lotModel(i)
	local d = workspace.World.Districts:FindFirstChild("D" .. myDistrict())
	local c = d and d:FindFirstChild("City")
	return c and c.Lots:FindFirstChild("L" .. i)
end

-- the construction overlay: a dark panel with the stage, a progress bar and the time; a gold hint to tap
local overlay = new("BillboardGui", { Name = "Site", Size = UDim2.fromOffset(310, 146), AlwaysOnTop = true, MaxDistance = 600, LightInfluence = 0, StudsOffsetWorldSpace = Vector3.new(0, 26, 0), Enabled = false, Parent = worldGui })
local ovPanel = UI.pill({ Style = "dark", Size = UDim2.fromOffset(272, 82), Position = UDim2.new(0.5, 8, 0, 16), AnchorPoint = Vector2.new(0.5, 0), Radius = 22, Transparency = 0.1, Parent = overlay })
UI.icon("mega", { Size = UDim2.fromOffset(56, 56), Position = UDim2.fromOffset(-20, -14), ZIndex = 8, Parent = ovPanel })
local ovText = UI.text({ Text = "", Scaled = false, TextSize = 22, Size = UDim2.new(1, -60, 0, 28), Position = UDim2.fromOffset(42, 7), XAlign = Enum.TextXAlignment.Left, ZIndex = 5, StrokeTh = 2.4, Parent = ovPanel })
local ovProg = UI.progress({ Color = "green", Track = C3(64, 78, 140), Size = UDim2.new(1, -28, 0, 30), Position = UDim2.fromOffset(14, 41), Max = 20, ZIndex = 5, Parent = ovPanel })
local ovTap = UI.chip({ Color = "gold", Icon = "up_power", Height = 32, TextSize = 19, Text = "TAP TO BUILD FASTER!", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 12, 0, 106), Parent = overlay })
local ovTapScale = new("UIScale", { Parent = ovTap.frame })

-- the tutorial marker over lot 1: a gold "TAP HERE!" bubble with a tail, bobbing
local arrow = new("BillboardGui", { Name = "Arrow", Size = UDim2.fromOffset(200, 96), AlwaysOnTop = true, LightInfluence = 0, StudsOffsetWorldSpace = Vector3.new(0, 14, 0), Enabled = false, Parent = worldGui })
tail(arrow, "gold", { Position = UDim2.new(0.5, 0, 0, 62), S = 24 })
local arrowPill = UI.pill({ Color = "gold", Size = UDim2.fromOffset(176, 60), Position = UDim2.new(0.5, 0, 0, 6), AnchorPoint = Vector2.new(0.5, 0), StrokeTh = 3.5, ZIndex = 3, Parent = arrow })
UI.icon("site", { Size = UDim2.fromOffset(64, 64), Position = UDim2.new(0, -12, 0.5, -34), ZIndex = 6, Parent = arrowPill })
UI.text({ Text = "TAP HERE!", Size = UDim2.new(1, -62, 0.62, 0), Position = UDim2.new(0, 50, 0.19, 0), ZIndex = 6, StrokeTh = 3, Max = 30, Parent = arrowPill })

local dust = new("Attachment", { Parent = workspace.Terrain })
local dustPE = new("ParticleEmitter", { Texture = "rbxasset://textures/particles/smoke_main.dds", Color = ColorSequence.new(Color3.fromRGB(235, 215, 185)),
	Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 3), NumberSequenceKeypoint.new(1, 9) }), Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 1) }),
	Lifetime = NumberRange.new(1, 1.6), Speed = NumberRange.new(4, 9), SpreadAngle = Vector2.new(80, 80), Rate = 0, Parent = dust })

-- A reward flying home: a handful of icons burst out of `from` (a GuiObject) and fly into the money (cash), the gems
-- (gems) or the HAMMERS button (crates), which bumps as they land
local function fly(icon, from, kind, n)
	local target = kind == "gems" and gemPill or (kind == "cash" and moneyPill or left:FindFirstChild("HAMMERS"))
	if not (from and from.Parent and target) then UI.coin() return end
	local sc = scale.Scale
	local function logical(v) return (v - root.AbsolutePosition) / sc end
	local a = logical(from.AbsolutePosition + from.AbsoluteSize / 2)
	local b = logical(target.AbsolutePosition + Vector2.new(math.min(26 * sc, target.AbsoluteSize.X / 2), target.AbsoluteSize.Y / 2))
	n = n or 8
	for i = 1, n do
		local ic = UI.icon(icon, { Size = UDim2.fromOffset(56, 56), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(a.X, a.Y), ZIndex = 40, Parent = root })
		local s = new("UIScale", { Scale = 0.2, Parent = ic })
		local ang = (i / n) * math.pi * 2 + math.random() * 0.6
		local mid = a + Vector2.new(math.cos(ang), math.sin(ang)) * (46 + math.random() * 40)
		TweenService:Create(s, TweenInfo.new(0.28, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
		TweenService:Create(ic, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Position = UDim2.fromOffset(mid.X, mid.Y), Rotation = math.random(-25, 25) }):Play()
		task.delay(0.34 + i * 0.045, function()
			local tw = TweenService:Create(ic, TweenInfo.new(0.42, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Position = UDim2.fromOffset(b.X, b.Y), Rotation = 0 })
			TweenService:Create(s, TweenInfo.new(0.42, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Scale = 0.5 }):Play()
			tw.Completed:Connect(function()
				ic:Destroy()
				UI.pop(target, 1.08)
				if i % 2 == 1 then UI.coin() end
			end)
			tw:Play()
		end)
	end
end

-- Windows (HAMMERS / SHOP / MENU): a dimmed screen, one panel with a header ribbon; the contents come in their own modules
local scrim = new("TextButton", { Name = "Scrim", Text = "", AutoButtonColor = false, BackgroundColor3 = C3(8, 12, 36), BackgroundTransparency = 0.45, Size = UDim2.new(1, 0, 1, 120), Position = UDim2.fromOffset(0, -120), ZIndex = 5, Visible = false, Parent = root })
local WIN_W = 800
local winBg, win, winHead = UI.panel({ Name = "Window", Size = UDim2.fromOffset(WIN_W, 470), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 24),
	Title = "", Icon = "shop", Color = "blue", HeadHeight = 64, Radius = 26, Pattern = true, PatternW = WIN_W, PatternH = 520, Visible = false, ZIndex = 6, Parent = root })
local winTitle = winHead.title
local function closeWindow()
	if not win.Visible then return end
	win.Visible = false
	scrim.Visible = false
	nextHolder.Visible = true
end
windows.close = closeWindow
UI.close({ Size = 52, Position = UDim2.new(1, -34, 0, -18), ZIndex = 12, Parent = winBg, OnClick = closeWindow })
scrim.Activated:Connect(closeWindow)
local winBody = new("Frame", { Name = "Body", BackgroundTransparency = 1, Position = UDim2.fromOffset(22, 80), Size = UDim2.new(1, -44, 1, -98), ZIndex = 5, Parent = winBg })
-- the window: as tall as the screen allows, centred, but never over the money column on the left
local function fitWindow()
	local h = math.clamp(logicalH - 44, 330, 540)
	win.Size = UDim2.fromOffset(WIN_W, h)
	-- (on a narrow phone it may cover the money column's right end rather than run off the screen)
	win.Position = UDim2.fromOffset(math.max(logicalW / 2, math.min(304 + WIN_W / 2, logicalW - WIN_W / 2 - 12)), 24)
end
table.insert(onResize, fitWindow)
local winColors = { HAMMERS = "blue", SHOP = "gold", MENU = "purple", GIFTS = "pink" }
local winIcons = { HAMMERS = "rbxassetid://71920003497651", SHOP = "store", MENU = "more", GIFTS = "gift" }
local contents = {}
windows.open = function(name, opts)
	if win.Visible and win:GetAttribute("Name") == name and not opts then closeWindow() return end
	card.Visible = false
	win:SetAttribute("Name", name)
	winTitle.Text = name
	winHead.color(winColors[name] or "blue")
	if winHead.icon then
		winHead.icon:Destroy()
		local ic = UI.icon(winIcons[name] or "shop", { Size = UDim2.fromOffset(80, 80), Position = UDim2.new(0, 6, 0.5, -44), ZIndex = 8, Parent = winHead.frame })
		ic.Rotation = -8
		winHead.icon = ic
	end
	for _, c in ipairs(winBody:GetChildren()) do c:Destroy() end
	if contents[name] then
		local ok, err = pcall(contents[name], winBody, { UI = UI, toast = toast, attr = attr, tab = opts and opts.tab, close = closeWindow, open = function(n, o) task.defer(windows.open, n, o) end, h = win.Size.Y.Offset - 98, fly = fly })
		if not ok then warn("[HUD2] window " .. name .. ": " .. tostring(err)) end
	end
	win.Visible = true
	scrim.Visible = true
	nextHolder.Visible = false
	UI.pop(win, 0.88)
end
-- the window contents live in modules next to this script (HammersWin, ShopWin, MenuWin); missing ones say so
for _, n in ipairs({ "HAMMERS", "SHOP", "MENU", "GIFTS" }) do
	local mod = script:FindFirstChild(n:sub(1, 1) .. n:sub(2):lower() .. "Win")
	if mod then
		local ok, fn = pcall(require, mod)
		if ok then contents[n] = fn else warn("[HUD2] " .. tostring(fn)) end
	end
	if not contents[n] then
		contents[n] = function(body) UI.text({ Text = "Coming soon", Color = UI.Ink, Stroke = false, Size = UDim2.new(1, 0, 0, 40), Position = UDim2.fromScale(0, 0.4), Max = 32, Parent = body }) end
	end
end
rescale()

-- The loop: counters, Rebirth, NEXT, the overlay, the arrow, HOME ----------------------------------------------------
local lastMoney = attr("Money", 0)
local function refreshTop()
	money.set(attr("Money", 0))
	gems.set(attr("Gems", 0))
	incomeChip.set("+" .. C.Money(attr("Income", 0)) .. "/s")
	local ready = attr("RebirthReady", false)
	rebHolder.Visible = ready
	rebBar.Visible = not ready
	local p = math.clamp(attr("RebirthProgress", 0), 0, 1)
	rebProg.set(math.max(0.05, p), (attr("Rebirths", 0) >= #C.RebirthCost) and "MAX REBIRTH" or ("REBIRTH " .. math.floor(p * 100) .. "%"))
end
for _, n in ipairs({ "Money", "Gems", "Income", "RebirthReady", "RebirthProgress", "Rebirths" }) do plr:GetAttributeChangedSignal(n):Connect(refreshTop) end
refreshTop()
plr:GetAttributeChangedSignal("Lots"):Connect(refreshCard)
plr:GetAttributeChangedSignal("Queue"):Connect(refreshCard)
plr:GetAttributeChangedSignal("Money"):Connect(function() if card.Visible then refreshCard() end end)

-- a multiplier as people read it: 2, 1.5, 2.25
local function multText(m)
	if math.abs(m - math.floor(m)) < 1e-6 then return tostring(math.floor(m)) end
	return (string.format("%.2f", m):gsub("%.?0+$", ""))
end

-- Rebirth: the dialog says what you get and what it takes. Ready: what goes (all your cash) and a REBIRTH! button.
-- Not ready yet (a tap on the Rebirth bar): how far you are and what is missing
local function confirmRebirth()
	local reb = attr("Rebirths", 0)
	if reb >= #C.RebirthCost then toast("Max Rebirth for now!", "gold", 2.5, "rebirth_star") return end
	if root:FindFirstChild("RebirthAsk") then return end
	local ready = attr("RebirthReady", false)
	local cap, capNow = C.Cap(reb + 1), C.Cap(reb)
	local cost = attr("RebirthCost", 0)
	if cost <= 0 then cost = C.RebirthCost[reb + 1] end
	local money = attr("Money", 0)
	local rows = {
		{ "up_cash", "Income x" .. multText(C.RebirthMultiplier(reb + 1)) .. " for good" },
		{ "locations", C.RowNames[reb + 2] and ("New land: " .. C.RowNames[reb + 2]) or "Bigger towers on all your land" },
		{ "mega", "Build up to level " .. cap .. ": " .. C.Levels[cap].name },
	}
	if ready then
		table.insert(rows, { "cash", "Your cash (" .. C.Money(money) .. ") goes back to $0. Your buildings stay!", red = true })
	else
		table.insert(rows, { "site", "Every lot to level " .. capNow .. " (" .. C.Levels[capNow].name .. ")", prog = math.clamp(attr("RebirthProgress", 0), 0, 1) })
		table.insert(rows, { "cash", "Have " .. C.Money(cost) .. " cash", prog = math.clamp(money / cost, 0, 1) })
	end
	local H = 84 + #rows * 58 + 96
	local holder = new("Frame", { Name = "RebirthAsk", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 20, Parent = root })
	local dim = new("TextButton", { Text = "", AutoButtonColor = false, BackgroundColor3 = C3(8, 12, 36), BackgroundTransparency = 0.4, Size = UDim2.new(1, 0, 1, 120), Position = UDim2.fromOffset(0, -120), ZIndex = 1, Parent = holder })
	local body, panel = UI.panel({ Size = UDim2.fromOffset(580, H), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, -24), Title = "REBIRTH " .. (reb + 1), Icon = "rebirth",
		Color = "gold", HeadHeight = 64, Radius = 26, Pattern = true, PatternW = 580, PatternH = H + 20, ZIndex = 2, Parent = holder })
	if not ready then
		UI.chip({ Color = "dark", Icon = "timer", Height = 32, TextSize = 17, Text = "NOT YET", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -70, 0, 32), ZIndex = 9, Parent = body })
	end
	for i, r in ipairs(rows) do
		local row = new("Frame", { BackgroundColor3 = WHITE, Size = UDim2.new(1, -60, 0, 50), Position = UDim2.fromOffset(30, 80 + (i - 1) * 58), ZIndex = 5, Parent = body })
		UI.corner(row, 16)
		UI.stroke(row, 2.5, r.red and UI.Colors.red[2] or UI.Ink, r.red and 0 or 0.35)
		UI.gradient(row, WHITE, r.red and C3(255, 226, 226) or (r.prog and C3(255, 244, 214) or C3(232, 240, 255)))
		UI.icon(r[1], { Size = UDim2.fromOffset(46, 46), Position = UDim2.new(0, 8, 0.5, -23), ZIndex = 7, Parent = row })
		local textW = r.prog and -200 or -74
		UI.text({ Text = r[2], Size = UDim2.new(1, textW, 0.6, 0), Position = UDim2.new(0, 62, 0.2, 0), XAlign = Enum.TextXAlignment.Left, Color = r.red and UI.Colors.red[2] or UI.Ink, Stroke = false, Max = 19, ZIndex = 7, Parent = row })
		if r.prog then
			local done = r.prog >= 1
			local pb = UI.progress({ Color = done and "green" or "gold", Size = UDim2.fromOffset(122, 26), AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0), Text = done and "DONE!" or (math.floor(r.prog * 100) .. "%"), Max = 16, ZIndex = 7, Parent = row })
			pb.set(math.max(0.08, r.prog), done and "DONE!" or (math.floor(r.prog * 100) .. "%"), true)
		end
	end
	local function close()
		local sc = panel:FindFirstChildOfClass("UIScale")
		if sc then TweenService:Create(sc, TweenInfo.new(0.16, Enum.EasingStyle.Back, Enum.EasingDirection.In), { Scale = 0 }):Play() end
		task.delay(0.18, function() holder:Destroy() end)
	end
	if ready then
		UI.button({ Name = "No", Color = "grey", Text = "NOT YET", Size = UDim2.fromOffset(200, 60), AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 30, 1, -22), Max = 26, ZIndex = 6, Parent = body, OnClick = close })
		UI.button({ Name = "Yes", Color = "gold", Text = "REBIRTH!", IconKey = "rebirth", Size = UDim2.fromOffset(270, 60), AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -30, 1, -22), Shimmer = true, Max = 28, ZIndex = 6, Parent = body,
			OnClick = function()
				local ok, err = CityRF:InvokeServer("rebirth")
				close()
				if not ok then toast(tostring(err), "red") end
			end })
	else
		UI.button({ Name = "Ok", Color = "green", Text = "KEEP BUILDING!", IconKey = "site", Size = UDim2.fromOffset(330, 60), AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -22), Max = 26, ZIndex = 6, Parent = body, OnClick = close })
	end
	dim.Activated:Connect(close)
	UI.pop(panel, 0.7)
end
-- the Rebirth bar (not ready yet) opens the same dialog: what it takes
local rebTap = new("TextButton", { Name = "Tap", Text = "", AutoButtonColor = false, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, 12), Position = UDim2.fromOffset(0, -6), ZIndex = 12, Parent = rebBar })
rebTap.Activated:Connect(function()
	UI.click()
	confirmRebirth()
end)
rebBtn.Activated:Connect(function()
	UI.click()
	confirmRebirth()
end)

local lastGoal, lastProg = nil, nil
RunService.Heartbeat:Connect(function()
	-- NEXT
	local g, prog, arrowLot = goal()
	if g ~= lastGoal or prog ~= lastProg then
		lastGoal, lastProg = g, prog
		local p = progOf(prog)
		fit(nextText, g, 24, NEXT_TW, 14)
		nextBar.frame.Visible = p ~= nil
		nextText.Position = UDim2.fromOffset(NEXT_TX, p and 6 or 19)
		if p then nextBar.set(math.max(0.06, p), prog) end
	end
	-- the site overlay
	local bl = attr("BuildLot", 0)
	local m = bl > 0 and lotModel(bl)
	if m and m:FindFirstChild("Pad") then
		overlay.Adornee = m.Pad
		overlay.StudsOffsetWorldSpace = m.Pad.CFrame.LookVector * 21 + Vector3.new(0, 15, 0)
		overlay.Enabled = true
		local p = attr("BuildProgress", 0)
		local stage = attr("BuildStage", "") ~= "" and attr("BuildStage", "") or (C.Levels[attr("BuildTo", 1)] or C.Levels[1]).name
		if ovText.Text ~= stage then fit(ovText, stage, 22, 216, 12) end
		ovProg.set(math.clamp(p, 0.04, 1), math.ceil(attr("BuildLeft", 0)) .. "s")
		ovTap.frame.Visible = p > 0
		ovTapScale.Scale = 1 + math.abs(math.sin(os.clock() * 3)) * 0.07
		if math.random() < 0.08 then dust.WorldPosition = m.Pad.Position dustPE:Emit(2) end
	else
		overlay.Enabled = false
	end
	-- the tutorial marker over lot 1
	local am = arrowLot and lotModel(arrowLot)
	if am and am:FindFirstChild("Pad") and bl == 0 then
		arrow.Adornee = am.Pad
		arrow.Enabled = not card.Visible
		arrow.StudsOffsetWorldSpace = Vector3.new(0, 12 + math.abs(math.sin(os.clock() * 3.2)) * 3, 0)
	else
		arrow.Enabled = false
	end
	-- HOME when far from your city
	local char = plr.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	local d = workspace.World.Districts:FindFirstChild("D" .. myDistrict())
	local gate = d and d:FindFirstChild("Gate")
	if hrp and gate then
		local far = (hrp.Position - gate:GetPivot().Position).Magnitude > 260
		homeHolder.Visible = far
	end
end)

-- money pops: the counter grows; a coin sound now and then
plr:GetAttributeChangedSignal("Money"):Connect(function()
	local v = attr("Money", 0)
	if v > lastMoney + 0.5 then UI.pop(moneyPill, 1.04) end
	lastMoney = v
end)

-- Lot bubbles: over each lot of yours, BUILD (empty) or UPGRADE (you can pay the next level) with the price, a tail
-- pointing at the lot; tap one = its card ------------------------------------------------------------------------
local bubbles = {}
local function bubble(i)
	if bubbles[i] then return bubbles[i] end
	local bb = new("BillboardGui", { Name = "Lot" .. i, Size = UDim2.fromOffset(170, 84), AlwaysOnTop = true, MaxDistance = 220, Active = true, LightInfluence = 0, Enabled = false, Parent = worldGui })
	local _, tailGrad = tail(bb, "green", { Position = UDim2.new(0.5, 0, 0, 60), S = 20 })
	local btn, holder, label = UI.button({ Name = "B", Color = "green", Text = "BUILD", Sub = "FREE", IconKey = "mega", Size = UDim2.fromOffset(156, 58), AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 2), Radius = 18, Max = 24, SubMax = 18, ZIndex = 2, Parent = bb, OnClick = function() openCard(i) end })
	bubbles[i] = { bb = bb, btn = btn, holder = holder, label = label, sub = btn:FindFirstChild("Sub"), icon = btn:FindFirstChild("Icon"), tail = tailGrad, kind = nil, phase = math.random() * 6 }
	return bubbles[i]
end
local function refreshBubbles()
	local L = lots()
	local cap = attr("Cap", 4)
	local moneyNow = attr("Money", 0)
	local busy = attr("Queue", 0) >= C.QueueSize
	for i, l in ipairs(L) do
		local kind, price
		if l.owned and not busy and l.planned == l.lv and l.planned < cap then
			local nx = C.Levels[l.planned + 1]
			local free = l.planned == 0 and i == 1 and attr("FreeFirst", false) ~= true
			price = free and 0 or nx.cost
			if l.planned == 0 then kind = (free or moneyNow >= nx.cost) and "build" or nil
			elseif moneyNow >= nx.cost then kind = "up" end
		end
		local m = kind and lotModel(i)
		if m and m:FindFirstChild("Pad") then
			local b = bubble(i)
			if b.kind ~= kind then
				b.kind = kind
				local col = kind == "build" and "green" or "gold"
				b.label.Text = kind == "build" and "BUILD" or "UPGRADE"
				UI.recolor(b.btn, col)
				b.tail.Color = ColorSequence.new(UI.Colors[col][2], UI.darker(UI.Colors[col][2], 0.35))
				if b.icon then UI.setIcon(b.icon, kind == "build" and "mega" or "upgrades") end
				UI.pop(b.holder, 0.5)
			end
			b.sub.Text = price == 0 and "FREE" or C.Money(price)
			-- (in front of the building, toward its street, at eye height: tall towers never hide it above the screen)
			b.bb.Adornee = m.Pad
			b.base = m.Pad.CFrame.LookVector * 22 + Vector3.new(0, 5.5, 0)
			b.bb.Enabled = not (card.Visible or win.Visible) -- (no clutter over an open card or window)
		elseif bubbles[i] then
			bubbles[i].bb.Enabled = false
			bubbles[i].kind = nil
		end
	end
end
task.spawn(function()
	while true do
		pcall(refreshBubbles)
		task.wait(0.5)
	end
end)
RunService.RenderStepped:Connect(function()
	local t = os.clock()
	for _, b in pairs(bubbles) do
		if b.bb.Enabled and b.base then b.bb.StudsOffsetWorldSpace = b.base + Vector3.new(0, math.sin(t * 2.4 + b.phase) * 0.6, 0) end
	end
end)

-- Income tags (RATE_TAGS): over every finished building of every city, the money it makes each second ---------------
-- (green; gold with "+25%" when its block has the bonus). Mine pulse with every income tick; the others show up closer.
local rateTags = {}
local RATE_TS = 21
local function rateTag(m)
	local t = rateTags[m]
	if t then return t end
	local bb = new("BillboardGui", { Name = "Rate", Size = UDim2.fromOffset(220, 58), AlwaysOnTop = true, MaxDistance = 220, LightInfluence = 0, Enabled = false, Parent = worldGui })
	local pill = UI.pill({ Color = "green", Size = UDim2.fromOffset(120, 38), Position = UDim2.new(0.5, 0, 1, -6), AnchorPoint = Vector2.new(0.5, 1), Parent = bb })
	UI.icon("cash", { Size = UDim2.fromOffset(44, 44), Position = UDim2.new(0, -8, 0.5, -23), ZIndex = 6, Parent = pill })
	local txt = UI.text({ Text = "", Scaled = false, TextSize = RATE_TS, Size = UDim2.new(1, -44, 1, 0), Position = UDim2.fromOffset(38, 0), XAlign = Enum.TextXAlignment.Left, ZIndex = 5, StrokeTh = 2.4, Parent = pill })
	local badge = UI.pill({ Color = "red", Size = UDim2.fromOffset(52, 22), Position = UDim2.new(1, -24, 0, -14), ZIndex = 8, StrokeTh = 2.2, Parent = pill })
	badge.Visible = false
	UI.text({ Text = "+25%", Size = UDim2.new(1, -8, 1, -4), Position = UDim2.fromOffset(4, 2), ZIndex = 10, StrokeTh = 1.6, Max = 16, Parent = badge })
	t = { bb = bb, pill = pill, txt = txt, badge = badge, grad = pill:FindFirstChildOfClass("UIGradient"), sc = new("UIScale", { Parent = pill }) }
	rateTags[m] = t
	m.Destroying:Connect(function() bb:Destroy() rateTags[m] = nil end)
	return t
end
local function refreshRates(pulse)
	local districts = workspace:FindFirstChild("World") and workspace.World:FindFirstChild("Districts")
	if not districts then return end
	local mine = myDistrict()
	for _, d in ipairs(districts:GetChildren()) do
		local lotsF = d:FindFirstChild("City") and d.City:FindFirstChild("Lots")
		for _, m in ipairs(lotsF and lotsF:GetChildren() or {}) do
			local rate = m:GetAttribute("Rate") or 0
			local b = m:FindFirstChild("Building")
			local pad = m:FindFirstChild("Pad")
			if rate > 0 and b and pad then
				local t = rateTag(m)
				local own = m:GetAttribute("District") == mine
				local bonus = m:GetAttribute("Bonus") == true
				local text = "+" .. C.Money(rate) .. "/s"
				if t.txt.Text ~= text then
					t.txt.Text = text
					t.pill.Size = UDim2.fromOffset(38 + UI.textWidth(text, RATE_TS) + 14, 38)
				end
				if t.bonus ~= bonus then
					t.bonus = bonus
					local col = UI.Colors[bonus and "gold" or "green"]
					t.grad.Color = ColorSequence.new(col[1], col[2])
					t.badge.Visible = bonus
				end
				-- just over the roof (the blueprint's height), centred on the lot
				t.bb.Adornee = pad
				t.bb.StudsOffsetWorldSpace = Vector3.new(0, (b:GetAttribute("Height") or 20) + 4, 0)
				t.bb.MaxDistance = own and 360 or 200
				if not t.bb.Enabled then t.bb.Enabled = true UI.pop(t.pill, 0.6) end
				if pulse and own then
					t.sc.Scale = 1.12
					TweenService:Create(t.sc, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
				end
			elseif rateTags[m] then
				rateTags[m].bb.Enabled = false
			end
		end
	end
end
task.spawn(function()
	local n = 0
	while true do
		n += 1
		pcall(refreshRates, n % 2 == 0)
		task.wait(0.5)
	end
end)

-- For-sale boards (PREMIUM_UI): the server puts the plain board and its numbers (Price, Locked, Need); the face is
-- drawn here with the kit: a ribbon, the price, how to buy ---------------------------------------------------------
local function dressBoard(board)
	if not board:IsA("BasePart") or board.Name ~= "Board" or board:GetAttribute("Block") == nil then return end
	local old = board:FindFirstChild("SaleUI")
	if old then old:Destroy() end
	local locked = board:GetAttribute("Locked") == true
	local price = board:GetAttribute("Price") or 0
	local ppsS = 40
	local H = board.Size.Y * ppsS
	local sg = new("SurfaceGui", { Name = "SaleUI", Face = Enum.NormalId.Front, SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud, PixelsPerStud = ppsS, LightInfluence = 0, Parent = board })
	local body = new("Frame", { BackgroundColor3 = WHITE, Size = UDim2.new(1, -24, 1, -24), Position = UDim2.fromOffset(12, 12), Parent = sg })
	UI.corner(body, 40)
	UI.stroke(body, 10)
	UI.gradient(body, locked and C3(236, 240, 252) or C3(255, 255, 250), locked and C3(188, 198, 226) or C3(255, 236, 170))
	local rib = new("Frame", { BackgroundColor3 = WHITE, Size = UDim2.new(1, 0, 0, H * 0.3), ZIndex = 2, Parent = body })
	UI.corner(rib, 40)
	local rc = UI.Colors[locked and "navy" or "red"]
	UI.gradient(rib, rc[1], rc[2])
	local ribFill = new("Frame", { BackgroundColor3 = rc[2], Size = UDim2.new(1, 0, 0, 40), Position = UDim2.new(0, 0, 1, -40), ZIndex = 2, Parent = rib })
	UI.gradient(ribFill, rc[1]:Lerp(rc[2], 0.6), rc[2])
	new("Frame", { BackgroundColor3 = UI.Ink, Size = UDim2.new(1, 0, 0, 10), Position = UDim2.new(0, 0, 1, -5), ZIndex = 3, Parent = rib })
	UI.gloss(rib, 30, { ZIndex = 3, Size = UDim2.new(1, -40, 0.4, 0), Position = UDim2.fromOffset(20, 8) })
	UI.text({ Text = locked and "LOCKED LAND" or "LAND FOR SALE", Size = UDim2.new(1, -60, 0.72, 0), Position = UDim2.new(0, 30, 0.12, 0), ZIndex = 4, StrokeTh = 8, Parent = rib })
	local chip = UI.pill({ Color = locked and "purple" or "green", Size = UDim2.new(0.74, 0, 0, H * 0.36), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 30, 0, H * 0.34), StrokeTh = 8, ZIndex = 3, Parent = body })
	UI.icon(locked and "rebirth_star" or "cash", { Size = UDim2.fromOffset(H * 0.5, H * 0.5), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0, 0, 0.5, 0), ZIndex = 6, Parent = chip })
	UI.text({ Text = locked and ("REBIRTH " .. tostring(board:GetAttribute("Need") or 1)) or C.Money(price), Size = UDim2.new(1, -H * 0.36, 0.78, 0), Position = UDim2.new(0, H * 0.28, 0.11, 0),
		ZIndex = 5, StrokeTh = 8, Parent = chip })
	UI.text({ Text = locked and "Rebirth to unlock this land" or "Walk up to the sign to buy it", Size = UDim2.new(1, -60, 0, H * 0.16), Position = UDim2.new(0, 30, 1, -H * 0.2), Color = UI.Ink,
		Stroke = false, ZIndex = 3, Parent = body })
end
local function watchBoards()
	local world = workspace:WaitForChild("World")
	for _, d in ipairs(world:GetDescendants()) do if d.Name == "Board" then pcall(dressBoard, d) end end
	world.DescendantAdded:Connect(function(d)
		if d.Name == "Board" and d:IsA("BasePart") then
			task.delay(0.2, function() if d.Parent then pcall(dressBoard, d) end end)
		end
	end)
end
task.spawn(watchBoards)

-- Prompts (PREMIUM_UI): every ProximityPrompt drawn in the kit's style: a key cap, a dark capsule with what it does,
-- a gold bar while you hold; on touch the whole thing is the button ------------------------------------------------
local PPS = game:GetService("ProximityPromptService")
local function customize(p) if p:IsA("ProximityPrompt") then p.Style = Enum.ProximityPromptStyle.Custom end end
for _, d in ipairs(workspace:GetDescendants()) do customize(d) end
workspace.DescendantAdded:Connect(customize)
PPS.PromptShown:Connect(function(prompt, inputType)
	if prompt.Style ~= Enum.ProximityPromptStyle.Custom then return end
	local adornee = prompt.Parent
	if not (adornee and (adornee:IsA("BasePart") or adornee:IsA("Attachment") or adornee:IsA("Model"))) then return end
	local touch = inputType == Enum.ProximityPromptInputType.Touch
	local action, object = prompt.ActionText, prompt.ObjectText
	local aw = math.max(UI.textWidth(action, 26), UI.textWidth(object, 17)) + 40
	local w = 84 + aw
	local bb = new("BillboardGui", { Name = "Prompt", Size = UDim2.fromOffset(w + 20, 104), AlwaysOnTop = true, Active = true, LightInfluence = 0, Adornee = adornee,
		ExtentsOffsetWorldSpace = Vector3.new(0, 1, 0), Parent = worldGui })
	local holder = new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(w, 76), Position = UDim2.fromOffset(10, 8), Parent = bb })
	local sc = new("UIScale", { Scale = 0, Parent = holder })
	TweenService:Create(sc, TweenInfo.new(0.22, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	local cap = UI.pill({ Color = "white", Size = UDim2.fromOffset(70, 70), Position = UDim2.fromOffset(0, 3), Radius = 18, StrokeTh = 3.5, ZIndex = 4, Parent = holder })
	local capLip = new("Frame", { BackgroundColor3 = C3(150, 160, 196), Size = UDim2.fromOffset(70, 70), Position = UDim2.fromOffset(0, 8), ZIndex = 3, Parent = holder })
	UI.corner(capLip, 18)
	UI.stroke(capLip, 3.5)
	local key = touch and "TAP" or (inputType == Enum.ProximityPromptInputType.Gamepad and prompt.GamepadKeyCode.Name:gsub("Button", "") or prompt.KeyboardKeyCode.Name)
	UI.text({ Text = key, Size = UDim2.new(1, -14, 0.6, 0), Position = UDim2.new(0, 7, 0.2, 0), Color = UI.Ink, Stroke = false, ZIndex = 6, Max = 40, Parent = cap })
	local panel = UI.pill({ Style = "dark", Size = UDim2.fromOffset(aw, 62), Position = UDim2.fromOffset(80, 7), Radius = 20, Transparency = 0.1, ZIndex = 2, Parent = holder })
	UI.text({ Text = object, Scaled = false, TextSize = 17, Size = UDim2.new(1, -24, 0, 20), Position = UDim2.fromOffset(16, 6), XAlign = Enum.TextXAlignment.Left, Color = C3(190, 204, 240), StrokeTh = 1.6, ZIndex = 4, Parent = panel })
	UI.text({ Text = action, Scaled = false, TextSize = 26, Size = UDim2.new(1, -24, 0, 30), Position = UDim2.fromOffset(16, object ~= "" and 25 or 16), XAlign = Enum.TextXAlignment.Left, ZIndex = 4, StrokeTh = 2.4, Parent = panel })
	local bar = UI.progress({ Color = "gold", Size = UDim2.new(1, -10, 0, 14), Position = UDim2.new(0, 5, 1, 12), StrokeTh = 2.5, ZIndex = 3, Parent = holder })
	bar.frame.Visible = false
	local holdTween
	local conns = {}
	table.insert(conns, prompt.PromptButtonHoldBegan:Connect(function()
		if prompt.HoldDuration <= 0 then return end
		bar.frame.Visible = true
		bar.set(0, "", true)
		holdTween = TweenService:Create(bar.fill, TweenInfo.new(prompt.HoldDuration, Enum.EasingStyle.Linear), { Size = UDim2.fromScale(1, 1) })
		bar.fill.Visible = true
		holdTween:Play()
		cap.Position = UDim2.fromOffset(0, 7)
	end))
	table.insert(conns, prompt.PromptButtonHoldEnded:Connect(function()
		if holdTween then holdTween:Cancel() end
		bar.frame.Visible = false
		cap.Position = UDim2.fromOffset(0, 3)
	end))
	table.insert(conns, prompt.Triggered:Connect(function()
		UI.click()
		UI.pop(holder, 1.12)
	end))
	if touch or inputType == Enum.ProximityPromptInputType.Keyboard then
		local hit = new("TextButton", { Text = "", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 20, Parent = holder })
		hit.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
				if input.UserInputState ~= Enum.UserInputState.Change then prompt:InputHoldBegin() end
			end
		end)
		hit.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then prompt:InputHoldEnd() end
		end)
	end
	prompt.PromptHidden:Wait()
	for _, c in ipairs(conns) do c:Disconnect() end
	TweenService:Create(sc, TweenInfo.new(0.12), { Scale = 0 }):Play()
	Debris:AddItem(bb, 0.15)
end)

-- The fountain: the golden hammer rises slowly and slams the anvil; the jets burst, a clang ------------------------
task.spawn(function()
	local CollectionService = game:GetService("CollectionService")
	local hm
	repeat
		hm = CollectionService:GetTagged("FountainHammer")[1]
		if not hm then task.wait(1) end
	until hm
	local base = hm:GetPivot()
	local angle = new("NumberValue", { Value = 0 })
	angle.Changed:Connect(function(v) hm:PivotTo(base * CFrame.Angles(0, 0, math.rad(v))) end)
	local clang = new("Sound", { SoundId = "rbxassetid://9125672726", Volume = 0.9, RollOffMinDistance = 30, RollOffMaxDistance = 320, Parent = hm.PrimaryPart })
	local jets = CollectionService:GetTagged("FountainJet")
	while true do
		task.wait(3.2)
		TweenService:Create(angle, TweenInfo.new(1.3, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), { Value = 52 }):Play()
		task.wait(1.7)
		local slam = TweenService:Create(angle, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Value = 0 })
		slam:Play()
		slam.Completed:Wait()
		clang.PlaybackSpeed = 0.75 + math.random() * 0.1
		clang:Play()
		for _, j in ipairs(jets) do
			local pe = j:FindFirstChildOfClass("ParticleEmitter")
			if pe then pe:Emit(14) end
		end
		local head = base * CFrame.new(25, -8, 0)
		sparks(head.Position, 5, 26)
	end
end)

-- the Hammer Shop's prompt (and any prompt with a Window attribute) opens its window
PPS.PromptTriggered:Connect(function(prompt)
	local w = prompt:GetAttribute("Window")
	if w and windows.open then
		if not (win.Visible and win:GetAttribute("Name") == w) then windows.open(w) end
	end
end)

-- music (the v1 track), quiet
local music = new("Sound", { Name = "Music2", SoundId = "rbxassetid://84797666595507", Looped = true, Volume = 0.16, Parent = game:GetService("SoundService") })
music:Play()

-- Welcome (a new builder: no building yet, the free first build still there) ---------------------------------------------
local function welcome()
	local holder = new("Frame", { Name = "Welcome", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 20, Parent = root })
	local dim = new("TextButton", { Text = "", AutoButtonColor = false, BackgroundColor3 = C3(8, 12, 36), BackgroundTransparency = 0.4, Size = UDim2.new(1, 0, 1, 120), Position = UDim2.fromOffset(0, -120), ZIndex = 1, Parent = holder })
	local body, panel = UI.panel({ Size = UDim2.fromOffset(560, 400), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Title = "WELCOME, BUILDER!", Icon = "mega",
		Color = "gold", HeadHeight = 64, Radius = 26, Pattern = true, PatternW = 560, PatternH = 420, ZIndex = 2, Parent = holder })
	UI.text({ Text = "Grow a city from one empty lot to a skyline of towers.", Size = UDim2.new(1, -60, 0, 26), Position = UDim2.fromOffset(30, 80), Color = UI.Ink, Stroke = false, Max = 21, ZIndex = 6, Parent = body })
	local steps = {
		{ "site", "Tap your glowing lot to build: the first one is free", "green" },
		{ "upgrades", "Upgrade your buildings: every level makes more cash", "blue" },
		{ "rebirth", "Rebirth to unlock new land and much taller towers", "purple" },
	}
	for i, st in ipairs(steps) do
		local y = 118 + (i - 1) * 62
		local row = new("Frame", { BackgroundColor3 = WHITE, Size = UDim2.new(1, -60, 0, 52), Position = UDim2.fromOffset(30, y), ZIndex = 5, Parent = body })
		UI.corner(row, 16)
		UI.stroke(row, 2.5, UI.Ink, 0.35)
		UI.gradient(row, WHITE, C3(232, 240, 255))
		local num = UI.pill({ Color = st[3], Size = UDim2.fromOffset(38, 38), Position = UDim2.new(0, 8, 0.5, -19), ZIndex = 7, Parent = row })
		UI.text({ Text = tostring(i), Size = UDim2.new(1, -10, 1, -10), Position = UDim2.fromOffset(5, 5), ZIndex = 9, Max = 24, StrokeTh = 2, Parent = num })
		UI.icon(st[1], { Size = UDim2.fromOffset(48, 48), Position = UDim2.new(0, 50, 0.5, -24), ZIndex = 7, Parent = row })
		UI.text({ Text = st[2], Size = UDim2.new(1, -120, 0.62, 0), Position = UDim2.new(0, 106, 0.19, 0), XAlign = Enum.TextXAlignment.Left, Color = UI.Ink, Stroke = false, Max = 19, ZIndex = 7, Parent = row })
	end
	local function close()
		local sc = panel:FindFirstChildOfClass("UIScale")
		if sc then TweenService:Create(sc, TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.In), { Scale = 0 }):Play() end
		TweenService:Create(dim, TweenInfo.new(0.2), { BackgroundTransparency = 1 }):Play()
		task.delay(0.22, function() holder:Destroy() end)
	end
	UI.button({ Name = "Go", Color = "green", Text = "LET'S BUILD!", Size = UDim2.fromOffset(300, 64), AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -22),
		Shimmer = true, Max = 32, ZIndex = 6, Parent = body, OnClick = close })
	dim.Activated:Connect(close)
	UI.pop(panel, 0.7)
end
task.spawn(function()
	-- wait for the save, then: no building at all and the free first build unused = a new builder
	local t0 = os.clock()
	while attr("Lots", "") == "" and os.clock() - t0 < 20 do task.wait(0.5) end
	task.wait(1.5)
	local any = false
	for _, l in ipairs(lots()) do if l.lv > 0 or l.planned > 0 then any = true end end
	if not any and attr("FreeFirst", false) ~= true then welcome() end
end)

-- Feedback from the server ------------------------------------------------------------------------------------------
FeedbackRE.OnClientEvent:Connect(function(kind, p)
	if kind == "Built" then
		local m = lotModel(p.lot)
		if m and m:FindFirstChild("Pad") then
			floatText(m.Pad.Position + Vector3.new(0, 20, 0), "+" .. C.Money(p.income) .. "/s")
			dust.WorldPosition = m.Pad.Position
			dustPE:Emit(18)
			local b = m:FindFirstChild("Building")
			local h = b and b:GetAttribute("Height") or 12
			BuildFX.emit(m.Pad.Position + Vector3.new(0, h + 4, 0), "confetti", nil, 60)
			sparks(m.Pad.Position + Vector3.new(0, 8, 0), 5, 30)
		end
		BuildFX.play("Fanfare", 0.35, 1.05, 2.6)
		BuildFX.play("Coins", 0.45)
		toast(p.name .. " built!", "green", nil, "mega")
	elseif kind == "Land" then
		BuildFX.play("Chime", 0.5)
		toast("New land! The streets build themselves", "gold", 3, "locations")
	elseif kind == "Rebirth" then
		BuildFX.play("Fanfare", 0.5, 0.9)
		toast("REBIRTH " .. p.n .. "! Income x" .. multText(p.mult), "gold", 4, "rebirth")
	elseif kind == "Offline" then
		toast("While you were away: +" .. C.Money(p.amount), "green", 4, "cash")
	elseif kind == "Error" then
		toast(tostring(p.text), "red")
	elseif kind == "Gems" and (p.amount or 0) > 0 then
		toast("+" .. C.Fmt(p.amount) .. " Gems", "purple", nil, "gem")
	elseif kind == "Purchased" then
		UI.coin()
		toast(tostring(p.name) .. " - thank you!", "gold", 3.5, "gift")
	elseif kind == "PaidRestored" then
		toast("Restored: " .. tostring(p.list), "gold", 4, "gift")
	end
end)
