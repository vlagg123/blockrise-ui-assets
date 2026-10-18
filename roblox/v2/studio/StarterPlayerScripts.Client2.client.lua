-- BlockRise Empire 2.0 - client: the HUD (money, gems, Rebirth bar, HAMMERS / SHOP / MENU, NEXT), the building card
-- (tap a lot), taps on the building site, the construction overlay and the effects (sparks, coins, pops).
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
local new = UI.new
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

-- Screen ------------------------------------------------------------------------------------------------
local gui = new("ScreenGui", { Name = "HUD2", ResetOnSpawn = false, IgnoreGuiInset = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, Parent = plr:WaitForChild("PlayerGui") })
pcall(function() gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets end)
-- the billboards in the world: straight in PlayerGui (inside a ScreenGui or a Folder they are never drawn), kept on respawn
local worldGui = plr.PlayerGui
local root = new("Frame", { Name = "Root", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = gui })
local scale = new("UIScale", { Parent = root })
local function rescale()
	local v = workspace.CurrentCamera.ViewportSize
	local s = math.clamp(math.min(v.X / 1150, v.Y / 640), 0.62, 1.2)
	scale.Scale = s
	root.Size = UDim2.fromScale(1 / s, 1 / s)
end
workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(rescale)
rescale()

-- Top: money, gems, Rebirth -------------------------------------------------------------------------------
local top = new("Frame", { Name = "Top", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 8), Size = UDim2.fromOffset(520, 120), Parent = root })
local moneyPill = UI.pill({ Name = "Money", Color = "green", Size = UDim2.fromOffset(290, 62), Position = UDim2.new(0.5, -40, 0, 0), AnchorPoint = Vector2.new(0.5, 0), Parent = top })
UI.icon("cash", { Size = UDim2.fromOffset(66, 66), Position = UDim2.new(0, -16, 0.5, -33), ZIndex = 4, Parent = moneyPill })
local moneyText = UI.text({ Text = "$0", Size = UDim2.new(1, -70, 0.66, 0), Position = UDim2.new(0, 56, 0.04, 0), XAlign = Enum.TextXAlignment.Left, ZIndex = 4, StrokeTh = 3, Parent = moneyPill })
local incomeText = UI.text({ Text = "+$0/s", Size = UDim2.new(1, -70, 0.32, 0), Position = UDim2.new(0, 58, 0.64, 0), XAlign = Enum.TextXAlignment.Left, Color = Color3.fromRGB(255, 255, 190), ZIndex = 4, StrokeTh = 2, Parent = moneyPill })
local gemPill = UI.pill({ Name = "Gems", Color = "purple", Size = UDim2.fromOffset(150, 48), Position = UDim2.new(0.5, 168, 0, 7), Parent = top })
UI.icon("gem", { Size = UDim2.fromOffset(50, 50), Position = UDim2.new(0, -12, 0.5, -25), ZIndex = 4, Parent = gemPill })
local gemText = UI.text({ Text = "0", Size = UDim2.new(1, -52, 0.74, 0), Position = UDim2.new(0, 42, 0.13, 0), XAlign = Enum.TextXAlignment.Left, ZIndex = 4, Parent = gemPill })
local money = UI.counter(moneyText, function(v) return C.Money(v) end)
local gems = UI.counter(gemText, function(v) return C.Fmt(v) end)

-- the Rebirth bar (a button when it is ready)
local rebBar = new("Frame", { Name = "Rebirth", BackgroundColor3 = Color3.fromRGB(255, 255, 255), Size = UDim2.fromOffset(270, 20), Position = UDim2.new(0.5, -40, 0, 72), AnchorPoint = Vector2.new(0.5, 0), Parent = top })
UI.corner(rebBar, UDim.new(1, 0))
UI.stroke(rebBar, 3)
local rebFill = new("Frame", { BackgroundColor3 = Color3.new(1, 1, 1), Size = UDim2.fromScale(0, 1), Parent = rebBar })
UI.corner(rebFill, UDim.new(1, 0))
UI.gradient(rebFill, UI.Colors.gold[1], UI.Colors.gold[2])
local rebText = UI.text({ Text = "REBIRTH 0%", Size = UDim2.new(1, 0, 1.2, 0), Position = UDim2.fromScale(0, -0.1), ZIndex = 3, StrokeTh = 2, Parent = rebBar })
local rebBtn, rebHolder = UI.button({ Name = "RebirthBtn", Color = "gold", Text = "REBIRTH!", Size = UDim2.fromOffset(200, 50), Position = UDim2.new(0.5, -40, 0, 70), AnchorPoint = Vector2.new(0.5, 0), Parent = top })
rebHolder.Visible = false

-- toasts: one at a time, under the top
local toastHolder = new("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 132), Size = UDim2.fromOffset(520, 46), Parent = root })
local toastQueue, toasting = {}, false
local function nextToast()
	if toasting or #toastQueue == 0 then return end
	toasting = true
	local t = table.remove(toastQueue, 1)
	local f = UI.pill({ Color = t.color or "white", Size = UDim2.fromOffset(0, 44), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0), Parent = toastHolder })
	f.AutomaticSize = Enum.AutomaticSize.X
	UI.pad(f, 22, 0, 22, 0)
	local l = UI.text({ Text = t.text, Scaled = false, TextSize = 24, Size = UDim2.fromScale(0, 1), Color = t.ink and UI.Ink or Color3.new(1, 1, 1), Stroke = not t.ink, ZIndex = 4, Parent = f })
	l.AutomaticSize = Enum.AutomaticSize.X
	UI.pop(f, 0.6)
	task.delay(t.time or 2.4, function()
		local sc = f:FindFirstChildOfClass("UIScale")
		if sc then TweenService:Create(sc, TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.In), { Scale = 0 }):Play() end
		task.wait(0.2)
		f:Destroy()
		toasting = false
		nextToast()
	end)
end
local function toast(text, color, time)
	table.insert(toastQueue, { text = text, color = color, time = time, ink = (color == nil or color == "white") })
	if #toastQueue > 3 then table.remove(toastQueue, 1) end
	nextToast()
end

-- Left: HAMMERS, SHOP, MENU -----------------------------------------------------------------------------------
local left = new("Frame", { Name = "Left", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 14, 0.5, -10), Size = UDim2.fromOffset(92, 300), Parent = root })
new("UIListLayout", { Padding = UDim.new(0, 14), SortOrder = Enum.SortOrder.LayoutOrder, Parent = left })
local windows = {}
local function sideButton(name, icon, color, order)
	local ic = UI.icon(icon, { Size = UDim2.fromScale(0.78, 0.78), Position = UDim2.fromScale(0.11, 0.02) })
	local btn, holder = UI.button({ Name = name, Color = color, Size = UDim2.fromOffset(82, 74), Icon = ic, Order = order, Radius = 18, Parent = left,
		OnClick = function() if windows.open then windows.open(name) end end })
	UI.text({ Text = name, Size = UDim2.new(1, 8, 0, 22), Position = UDim2.new(0, -4, 1, -16), ZIndex = btn.ZIndex + 3, Max = 20, Parent = btn })
	return btn, holder
end
sideButton("HAMMERS", "shop", "blue", 1)
sideButton("SHOP", "store", "gold", 2)
local menuBtn = sideButton("MENU", "more", "purple", 3)
-- HOME: only when you are far from your city
local homeBtn, homeHolder = UI.button({ Name = "HOME", Color = "green", Text = "HOME", Size = UDim2.fromOffset(82, 44), Order = 4, Parent = left, Max = 22,
	OnClick = function() CityRF:InvokeServer("home") end })
homeHolder.Visible = false

-- Bottom: NEXT ----------------------------------------------------------------------------------------------
local nextHolder = new("Frame", { Name = "Next", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -14), Size = UDim2.fromOffset(460, 66), Parent = root })
local nextPill = UI.pill({ Color = "white", Size = UDim2.fromScale(1, 1), Parent = nextHolder })
local nextTag = UI.pill({ Color = "green", Size = UDim2.fromOffset(92, 50), Position = UDim2.new(0, 8, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), Parent = nextPill })
UI.text({ Text = "NEXT", Size = UDim2.new(1, -12, 0.7, 0), Position = UDim2.new(0, 6, 0.15, 0), ZIndex = 4, Parent = nextTag })
local nextText = UI.text({ Text = "", Size = UDim2.new(1, -200, 0.62, 0), Position = UDim2.new(0, 112, 0.19, 0), XAlign = Enum.TextXAlignment.Left, Color = UI.Ink, Stroke = false, ZIndex = 4, Max = 26, Parent = nextPill })
local nextProg = UI.text({ Text = "", Size = UDim2.new(0, 80, 0.6, 0), Position = UDim2.new(1, -90, 0.2, 0), Color = Color3.fromRGB(46, 186, 80), Stroke = false, ZIndex = 4, Max = 26, Parent = nextPill })

-- the goals, the first one not done yet
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
	local openLots = 8 * math.min(3, reb + 1)
	if ownedLots < openLots then return "Buy new land (the sale sign)", (ownedLots // 4) .. "/" .. (openLots // 4) end
	if built < ownedLots then return "Build on every lot", built .. "/" .. ownedLots end
	if maxed < ownedLots then return "Upgrade every lot to " .. C.Levels[cap].name, maxed .. "/" .. ownedLots end
	if reb < #C.RebirthCost then return "REBIRTH for x" .. C.RebirthMult .. " income!", math.floor(math.min(1, attr("Money", 0) / math.max(1, attr("RebirthCost", 1))) * 100) .. "%" end
	return "Your city is complete!", ""
end

-- Building card -------------------------------------------------------------------------------------------------
local card = new("Frame", { Name = "Card", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -96), Size = UDim2.fromOffset(500, 220), Visible = false, Parent = root })
local cardBg = new("Frame", { BackgroundColor3 = Color3.new(1, 1, 1), Size = UDim2.fromScale(1, 1), Parent = card })
UI.corner(cardBg, 22)
UI.stroke(cardBg, 4)
UI.gradient(cardBg, Color3.fromRGB(255, 255, 255), Color3.fromRGB(226, 236, 255))
local cardHead = new("Frame", { BackgroundColor3 = Color3.new(1, 1, 1), Size = UDim2.new(1, 0, 0, 50), Parent = cardBg })
UI.corner(cardHead, 22)
UI.gradient(cardHead, UI.Colors.blue[1], UI.Colors.blue[2])
new("Frame", { BackgroundColor3 = UI.Colors.blue[2], Size = UDim2.new(1, 0, 0, 16), Position = UDim2.new(0, 0, 1, -16), Parent = cardHead })
local cardTitle = UI.text({ Text = "", Size = UDim2.new(1, -110, 0.7, 0), Position = UDim2.new(0, 18, 0.15, 0), XAlign = Enum.TextXAlignment.Left, ZIndex = 3, Max = 30, Parent = cardHead })
local closeBtn = UI.button({ Name = "Close", Color = "red", Text = "X", Size = UDim2.fromOffset(44, 40), Position = UDim2.new(1, -54, 0, 4), Radius = 12, Parent = cardBg,
	OnClick = function() card.Visible = false end })
local view = new("ViewportFrame", { BackgroundColor3 = Color3.fromRGB(190, 230, 255), Size = UDim2.fromOffset(150, 150), Position = UDim2.new(0, 16, 0, 60), Ambient = Color3.fromRGB(200, 200, 210), LightColor = Color3.fromRGB(255, 250, 240), LightDirection = Vector3.new(-1, -1.5, -0.6), Parent = cardBg })
UI.corner(view, 16)
UI.stroke(view, 3)
local vcam = new("Camera", { Parent = view })
view.CurrentCamera = vcam
local cardLine1 = UI.text({ Text = "", Size = UDim2.new(1, -200, 0, 34), Position = UDim2.new(0, 182, 0, 62), XAlign = Enum.TextXAlignment.Left, Color = UI.Ink, Stroke = false, ZIndex = 3, Max = 28, Parent = cardBg })
local cardLine2 = UI.text({ Text = "", Size = UDim2.new(1, -200, 0, 28), Position = UDim2.new(0, 182, 0, 98), XAlign = Enum.TextXAlignment.Left, Color = Color3.fromRGB(46, 170, 80), Stroke = false, ZIndex = 3, Max = 24, Parent = cardBg })
local cardBtn, cardBtnHolder, cardBtnLabel = UI.button({ Name = "Do", Color = "green", Text = "BUILD", Size = UDim2.new(1, -200, 0, 58), Position = UDim2.new(0, 182, 0, 142), Parent = cardBg })
local styleBtn, styleHolder = UI.button({ Name = "Style", Color = "purple", Text = "STYLE", Size = UDim2.fromOffset(84, 36), Position = UDim2.new(1, -150, 0, 6), Radius = 12, Max = 18, Parent = cardBg })
local cardLot, cardAction, previewKey = nil, nil, nil

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
	local dist = r / math.sin(math.rad(17)) * 0.92
	local centre = Vector3.new(0, size.Y / 2, 0)
	vcam.CFrame = CFrame.lookAt(centre + Vector3.new(0.55, 0.32, -0.77).Unit * dist, centre)
end
RunService.RenderStepped:Connect(function(dt)
	if card.Visible then
		for _, c in ipairs(view:GetChildren()) do if c:IsA("Model") then c:PivotTo(c:GetPivot() * CFrame.Angles(0, dt * 0.6, 0)) end end
	end
end)

local function refreshCard()
	if not card.Visible or not cardLot then return end
	local L = lots()
	local l = L[cardLot]
	if not l then return end
	local cap = attr("Cap", 4)
	local moneyNow = attr("Money", 0)
	local busy = attr("Queue", 0) >= C.QueueSize
	styleHolder.Visible = l.owned and l.lv > 0
	if not l.owned then
		cardTitle.Text = "LAND FOR SALE"
		cardLine1.Text = "Walk to the sign to buy it"
		cardLine2.Text = ""
		cardBtnLabel.Text = "OK"
		UI.recolor(cardBtn, "blue")
		cardAction = function() card.Visible = false end
		setPreview(1, 1)
		return
	end
	local cur = l.lv > 0 and C.Levels[l.lv] or nil
	cardTitle.Text = cur and ("LV " .. l.lv .. " " .. (C.StyleOf(l.lv, l.st)):upper()) or "EMPTY LOT"
	local nextLv = l.planned + 1
	if l.planned >= cap then
		setPreview(math.max(1, l.lv), l.st)
		cardLine1.Text = cur and ("Makes " .. C.Money(cur.income * C.RebirthMultiplier(attr("Rebirths", 0))) .. "/s") or ""
		cardLine2.Text = l.planned >= C.MaxLevel and "Max level!" or "Rebirth to build higher"
		cardBtnLabel.Text = l.planned >= C.MaxLevel and "MAX" or "REBIRTH TO GO HIGHER"
		UI.recolor(cardBtn, "grey")
		cardAction = nil
		return
	end
	local nx = C.Levels[nextLv]
	setPreview(nextLv, l.st)
	local gain = (nx.income - (cur and cur.income or 0)) * C.RebirthMultiplier(attr("Rebirths", 0))
	cardLine1.Text = (l.planned > l.lv and "Then: " or "Next: ") .. (C.StyleOf(nextLv, l.st))
	cardLine2.Text = "+" .. C.Money(gain) .. "/s  -  " .. nx.time .. "s build"
	local price = nx.cost
	if nextLv == 1 and cardLot == 1 and attr("FreeFirst", false) ~= true and #L > 0 and L[1].lv == 0 then price = 0 end
	if busy then
		cardBtnLabel.Text = "CREW BUSY " .. attr("Queue", 0) .. "/" .. C.QueueSize
		UI.recolor(cardBtn, "grey")
		cardAction = nil
	else
		cardBtnLabel.Text = (l.planned == 0 and "BUILD " or "UPGRADE ") .. (price == 0 and "FREE" or C.Money(price))
		UI.recolor(cardBtn, moneyNow >= price and "green" or "grey")
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
		if sparks then sparks(hitPos, Hammers.ById[attr("HammerKey", "rusty")] and Hammers.ById[attr("HammerKey", "rusty")].r or 1, 10) end
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
HitsRE.OnClientEvent:Connect(function(list)
	local cam = workspace.CurrentCamera.CFrame.Position
	for _, h in ipairs(list) do
		if (h[1] - cam).Magnitude < 260 then sparks(h[1], h[2], 5) end
	end
end)

-- a floating text in the world ("+$3/s", "+ $120")
local function floatText(pos, text, color)
	local p = new("Part", { Anchored = true, CanCollide = false, CanQuery = false, Transparency = 1, Size = Vector3.one, CFrame = CFrame.new(pos), Parent = fxFolder })
	local bb = new("BillboardGui", { Size = UDim2.fromOffset(260, 70), AlwaysOnTop = true, MaxDistance = 400, Parent = p })
	local t = UI.text({ Text = text, Color = color or Color3.fromRGB(120, 255, 120), StrokeTh = 3, Parent = bb })
	TweenService:Create(p, TweenInfo.new(1.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { CFrame = CFrame.new(pos + Vector3.new(0, 14, 0)) }):Play()
	TweenService:Create(t, TweenInfo.new(1.6, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { TextTransparency = 1 }):Play()
	Debris:AddItem(p, 1.7)
end

-- the lot model of my city
local function lotModel(i)
	local d = workspace.World.Districts:FindFirstChild("D" .. myDistrict())
	local c = d and d:FindFirstChild("City")
	return c and c.Lots:FindFirstChild("L" .. i)
end

-- the construction overlay: a progress bar over the site, dust at its foot, a glowing arrow on the tutorial lot
local overlay = new("BillboardGui", { Name = "Site", Size = UDim2.fromOffset(240, 92), AlwaysOnTop = true, MaxDistance = 600, StudsOffsetWorldSpace = Vector3.new(0, 26, 0), Enabled = false, Parent = worldGui })
local ovBar = new("Frame", { BackgroundColor3 = Color3.new(1, 1, 1), Size = UDim2.new(1, 0, 0, 28), Position = UDim2.new(0, 0, 0, 34), Parent = overlay })
UI.corner(ovBar, UDim.new(1, 0))
UI.stroke(ovBar, 3)
local ovFill = new("Frame", { BackgroundColor3 = Color3.new(1, 1, 1), Size = UDim2.fromScale(0, 1), Parent = ovBar })
UI.corner(ovFill, UDim.new(1, 0))
UI.gradient(ovFill, UI.Colors.green[1], UI.Colors.green[2])
local ovText = UI.text({ Text = "", Size = UDim2.new(1, 0, 0, 32), Parent = overlay })
local ovTime = UI.text({ Text = "", Size = UDim2.new(1, 0, 1, 0), ZIndex = 3, StrokeTh = 2, Parent = ovBar })
local ovTap = UI.text({ Text = "TAP TO BUILD FASTER!", Size = UDim2.new(1, 0, 0, 24), Position = UDim2.new(0, 0, 0, 66), Color = Color3.fromRGB(255, 230, 90), Parent = overlay })

local arrow = new("BillboardGui", { Name = "Arrow", Size = UDim2.fromOffset(110, 130), AlwaysOnTop = true, StudsOffsetWorldSpace = Vector3.new(0, 14, 0), Enabled = false, Parent = worldGui })
local arrowImg = UI.text({ Text = "V", Color = Color3.fromRGB(255, 220, 60), StrokeTh = 5, Parent = arrow })
local arrowTag = UI.text({ Text = "TAP!", Size = UDim2.new(1, 0, 0.35, 0), Position = UDim2.fromScale(0, -0.3), StrokeTh = 3, Parent = arrow })

local dust = new("Attachment", { Parent = workspace.Terrain })
local dustPE = new("ParticleEmitter", { Texture = "rbxasset://textures/particles/smoke_main.dds", Color = ColorSequence.new(Color3.fromRGB(235, 215, 185)),
	Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 3), NumberSequenceKeypoint.new(1, 9) }), Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 1) }),
	Lifetime = NumberRange.new(1, 1.6), Speed = NumberRange.new(4, 9), SpreadAngle = Vector2.new(80, 80), Rate = 0, Parent = dust })

-- Windows (HAMMERS / SHOP / MENU): the shared frame; the contents come in their own modules -------------------------
local win = new("Frame", { Name = "Window", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.52), Size = UDim2.fromOffset(760, 470), Visible = false, Parent = root })
local winBg = new("Frame", { BackgroundColor3 = Color3.new(1, 1, 1), Size = UDim2.fromScale(1, 1), Parent = win })
UI.corner(winBg, 26)
UI.stroke(winBg, 4)
UI.gradient(winBg, Color3.fromRGB(255, 255, 255), Color3.fromRGB(222, 234, 255))
local winHead = new("Frame", { BackgroundColor3 = Color3.new(1, 1, 1), Size = UDim2.new(1, 0, 0, 64), Parent = winBg })
UI.corner(winHead, 26)
local winHeadGrad = UI.gradient(winHead, UI.Colors.blue[1], UI.Colors.blue[2])
local winHeadFill = new("Frame", { BackgroundColor3 = UI.Colors.blue[2], Size = UDim2.new(1, 0, 0, 20), Position = UDim2.new(0, 0, 1, -20), Parent = winHead })
local winTitle = UI.text({ Text = "", Size = UDim2.new(1, -140, 0.72, 0), Position = UDim2.new(0, 24, 0.14, 0), XAlign = Enum.TextXAlignment.Left, ZIndex = 3, StrokeTh = 3, Parent = winHead })
UI.button({ Name = "Close", Color = "red", Text = "X", Size = UDim2.fromOffset(52, 48), Position = UDim2.new(1, -66, 0, 8), Radius = 14, Parent = winBg, OnClick = function() win.Visible = false end })
local winBody = new("Frame", { Name = "Body", BackgroundTransparency = 1, Position = UDim2.new(0, 18, 0, 78), Size = UDim2.new(1, -36, 1, -94), Parent = winBg })
local winColors = { HAMMERS = "blue", SHOP = "gold", MENU = "purple" }
local contents = {}
windows.open = function(name)
	if win.Visible and win:GetAttribute("Name") == name then win.Visible = false return end
	card.Visible = false
	win:SetAttribute("Name", name)
	winTitle.Text = name
	local col = UI.Colors[winColors[name] or "blue"]
	winHeadGrad.Color = ColorSequence.new(col[1], col[2])
	winHeadFill.BackgroundColor3 = col[2]
	for _, c in ipairs(winBody:GetChildren()) do c:Destroy() end
	if contents[name] then contents[name](winBody, { UI = UI, toast = toast, attr = attr }) end
	win.Visible = true
	UI.pop(win, 0.85)
end
-- the window contents live in modules next to this script (HammersWin, ShopWin, MenuWin); missing ones say so
for _, n in ipairs({ "HAMMERS", "SHOP", "MENU" }) do
	local mod = script:FindFirstChild(n:sub(1, 1) .. n:sub(2):lower() .. "Win")
	if mod then
		local ok, fn = pcall(require, mod)
		if ok then contents[n] = fn end
	end
	if not contents[n] then
		contents[n] = function(body) UI.text({ Text = "Coming soon", Color = UI.Ink, Stroke = false, Size = UDim2.new(1, 0, 0, 40), Position = UDim2.fromScale(0, 0.4), Max = 32, Parent = body }) end
	end
end

-- The loop: counters, Rebirth, NEXT, the overlay, the arrow, HOME ----------------------------------------------------
local lastMoney = attr("Money", 0)
local function refreshTop()
	money.set(attr("Money", 0))
	gems.set(attr("Gems", 0))
	incomeText.Text = "+" .. C.Money(attr("Income", 0)) .. "/s"
	local ready = attr("RebirthReady", false)
	rebHolder.Visible = ready
	rebBar.Visible = not ready
	local p = math.clamp(attr("RebirthProgress", 0), 0, 1)
	rebFill.Size = UDim2.fromScale(math.max(0.04, p), 1)
	rebText.Text = (attr("Rebirths", 0) >= #C.RebirthCost) and "MAX REBIRTH" or ("REBIRTH " .. math.floor(p * 100) .. "%")
end
for _, n in ipairs({ "Money", "Gems", "Income", "RebirthReady", "RebirthProgress", "Rebirths" }) do plr:GetAttributeChangedSignal(n):Connect(refreshTop) end
refreshTop()
plr:GetAttributeChangedSignal("Lots"):Connect(refreshCard)
plr:GetAttributeChangedSignal("Queue"):Connect(refreshCard)
plr:GetAttributeChangedSignal("Money"):Connect(function() if card.Visible then refreshCard() end end)

rebBtn.Activated:Connect(function()
	UI.click()
	local ok, err = CityRF:InvokeServer("rebirth")
	if not ok then toast(tostring(err), "red") end
end)

RunService.Heartbeat:Connect(function()
	-- NEXT
	local g, prog, arrowLot = goal()
	nextText.Text = g
	nextProg.Text = prog or ""
	-- the site overlay
	local bl = attr("BuildLot", 0)
	local m = bl > 0 and lotModel(bl)
	if m and m:FindFirstChild("Pad") then
		overlay.Adornee = m.Pad
		overlay.StudsOffsetWorldSpace = m.Pad.CFrame.LookVector * 21 + Vector3.new(0, 15, 0)
		overlay.Enabled = true
		local p = attr("BuildProgress", 0)
		ovFill.Size = UDim2.fromScale(math.clamp(p, 0.02, 1), 1)
		ovText.Text = attr("BuildStage", "") ~= "" and attr("BuildStage", "") or (C.Levels[attr("BuildTo", 1)] or C.Levels[1]).name
		ovTime.Text = math.ceil(attr("BuildLeft", 0)) .. "s"
		ovTap.Visible = p > 0
		if math.random() < 0.08 then dust.WorldPosition = m.Pad.Position dustPE:Emit(2) end
	else
		overlay.Enabled = false
	end
	-- the tutorial arrow over lot 1
	local am = arrowLot and lotModel(arrowLot)
	if am and am:FindFirstChild("Pad") and bl == 0 then
		arrow.Adornee = am.Pad
		arrow.Enabled = not card.Visible
		arrow.StudsOffsetWorldSpace = Vector3.new(0, 10 + math.abs(math.sin(os.clock() * 4)) * 4, 0)
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
	if v > lastMoney + 0.5 then UI.pop(moneyPill, 1.05) end
	lastMoney = v
end)

-- Lot bubbles: over each lot of yours, BUILD (empty) or UPGRADE (you can pay the next level); tap one = its card ------
local bubbles = {}
local function bubble(i)
	if bubbles[i] then return bubbles[i] end
	local bb = new("BillboardGui", { Name = "Lot" .. i, Size = UDim2.fromOffset(132, 54), AlwaysOnTop = true, MaxDistance = 260, Active = true, Enabled = false, Parent = worldGui })
	local btn, holder, label = UI.button({ Name = "B", Color = "green", Text = "BUILD", Size = UDim2.new(1, -8, 1, -10), Position = UDim2.fromOffset(4, 2), Radius = 16, Max = 26, Parent = bb,
		OnClick = function() openCard(i) end })
	bubbles[i] = { bb = bb, btn = btn, label = label, kind = nil }
	return bubbles[i]
end
local function refreshBubbles()
	local L = lots()
	local cap = attr("Cap", 4)
	local moneyNow = attr("Money", 0)
	local busy = attr("Queue", 0) >= C.QueueSize
	for i, l in ipairs(L) do
		local kind
		if l.owned and not busy and l.planned == l.lv and l.planned < cap then
			local nx = C.Levels[l.planned + 1]
			local free = l.planned == 0 and i == 1 and attr("FreeFirst", false) ~= true
			if l.planned == 0 then kind = (free or moneyNow >= nx.cost) and "build" or nil
			elseif moneyNow >= nx.cost then kind = "up" end
		end
		local m = kind and lotModel(i)
		if m and m:FindFirstChild("Pad") then
			local b = bubble(i)
			if b.kind ~= kind then
				b.kind = kind
				b.label.Text = kind == "build" and "BUILD" or "UPGRADE"
				UI.recolor(b.btn, kind == "build" and "green" or "gold")
				UI.pop(b.bb:FindFirstChild("B"), 0.5)
			end
			-- (in front of the building, toward its street, at eye height: tall towers never hide it above the screen)
			b.bb.Adornee = m.Pad
			b.bb.StudsOffsetWorldSpace = m.Pad.CFrame.LookVector * 21 + Vector3.new(0, 9, 0)
			b.bb.Enabled = true
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
game:GetService("ProximityPromptService").PromptTriggered:Connect(function(prompt)
	local w = prompt:GetAttribute("Window")
	if w and windows.open then
		if not (win.Visible and win:GetAttribute("Name") == w) then windows.open(w) end
	end
end)

-- music (the v1 track), quiet
local music = new("Sound", { Name = "Music2", SoundId = "rbxassetid://84797666595507", Looped = true, Volume = 0.16, Parent = game:GetService("SoundService") })
music:Play()

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
		UI.coin()
		toast(p.name .. " built!", "green")
	elseif kind == "Land" then
		toast("New land! The streets build themselves", "gold", 3)
	elseif kind == "Rebirth" then
		toast("REBIRTH " .. p.n .. "! Income x" .. C.Fmt(p.mult), "gold", 4)
	elseif kind == "Offline" then
		toast("While you were away: +" .. C.Money(p.amount), "green", 4)
	elseif kind == "Error" then
		toast(tostring(p.text), "red")
	elseif kind == "Gems" and (p.amount or 0) > 0 then
		toast("+" .. C.Fmt(p.amount) .. " Gems", "purple")
	elseif kind == "Purchased" then
		UI.coin()
		toast(tostring(p.name) .. " - thank you!", "gold", 3.5)
	elseif kind == "PaidRestored" then
		toast("Restored: " .. tostring(p.list), "gold", 4)
	end
end)
