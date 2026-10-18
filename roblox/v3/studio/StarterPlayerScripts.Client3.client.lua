-- BlockRise 3.0 (tycoon prototype, PROTO3_V1, 2026-10-18) - the client: the show.
--  * the buttons: a glowing disc on the ground and a chunky card over it (what, how much, what it gives); green when
--    you can pay it, red when you cannot; they pop up out of the ground, and shrink away when bought
--  * the construction: every floor drops onto the one below with a bounce and a puff of dust; the street is poured
--    stretch by stretch; lamps, trees and benches fall into place; when a building is done it bounces, confetti, a
--    fanfare, and its "+$X/s" floats up
--  * the money: coins fly from your buildings into the vault; the vault's screen counts up; step on the gold pad and
--    the cash bursts into your counter
--  * the HUD: just your cash and what it grows by, in the top-left corner
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Debris = game:GetService("Debris")
local SoundService = game:GetService("SoundService")

local T = require(ReplicatedStorage:WaitForChild("Shared3"):WaitForChild("Tycoon"))
local Remotes = ReplicatedStorage:WaitForChild("Remotes3")
local EventRE = Remotes:WaitForChild("Event")
local TapRE = Remotes:WaitForChild("Tap")
local HitsRE = Remotes:WaitForChild("Hits")

local plr = Players.LocalPlayer
local C3 = Color3.fromRGB
local at = CFrame.new
local WHITE = Color3.new(1, 1, 1)
local INK = C3(26, 22, 48)
local NSK = NumberSequenceKeypoint.new
local BIG = Enum.Font.LuckiestGuy
local FONT = Enum.Font.FredokaOne

local function new(class, props)
	local o = Instance.new(class)
	for k, v in pairs(props or {}) do if k ~= "Parent" then o[k] = v end end
	if props and props.Parent then o.Parent = props.Parent end
	return o
end
local function tween(o, t, props, style, dir)
	local tw = TweenService:Create(o, TweenInfo.new(t, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props)
	tw:Play()
	return tw
end
local function corner(o, r) return new("UICorner", { CornerRadius = typeof(r) == "UDim" and r or UDim.new(0, r), Parent = o }) end
local function stroke(o, th, col, mode)
	return new("UIStroke", { Thickness = th, Color = col or INK, LineJoinMode = Enum.LineJoinMode.Round, ApplyStrokeMode = mode or Enum.ApplyStrokeMode.Border, Parent = o })
end
local function grad(o, a, b, rot) return new("UIGradient", { Color = ColorSequence.new(a, b), Rotation = rot or 90, Parent = o }) end
local function text(props)
	local t = new("TextLabel", { BackgroundTransparency = 1, Font = props.Font or BIG, Text = props.Text or "", TextColor3 = props.Color or WHITE, TextScaled = true,
		Size = props.Size, Position = props.Position or UDim2.new(), AnchorPoint = props.AnchorPoint or Vector2.zero, TextXAlignment = props.XAlign or Enum.TextXAlignment.Center,
		ZIndex = props.ZIndex or 2, Rotation = props.Rotation or 0, Parent = props.Parent })
	stroke(t, props.Stroke or 3, props.StrokeColor or INK, Enum.ApplyStrokeMode.Contextual)
	if props.Max then new("UITextSizeConstraint", { MaxTextSize = props.Max, MinTextSize = 6, Parent = t }) end
	return t
end

-- sounds ---------------------------------------------------------------------------------------------------------
local sounds = {}
local function sfx(key, vol, pitch)
	local s = sounds[key]
	if not s then
		s = new("Sound", { SoundId = T.Sounds[key], Parent = SoundService })
		sounds[key] = s
	end
	s.Volume = vol or 0.5
	s.PlaybackSpeed = pitch or 1
	s.TimePosition = 0
	s:Play()
	return s
end
local function sfx3D(key, pos, vol, pitch)
	local cam = workspace.CurrentCamera
	if not cam or (cam.CFrame.Position - pos).Magnitude > 160 then return end
	local a = new("Attachment", { WorldPosition = pos, Parent = workspace.Terrain })
	local s = new("Sound", { SoundId = T.Sounds[key], Volume = vol or 0.4, PlaybackSpeed = pitch or 1, RollOffMinDistance = 16, RollOffMaxDistance = 160, Parent = a })
	s:Play()
	Debris:AddItem(a, 3)
end
task.spawn(function()
	local list = {}
	for _, id in pairs(T.Sounds) do table.insert(list, new("Sound", { SoundId = id })) end
	pcall(function() game:GetService("ContentProvider"):PreloadAsync(list) end)
end)

-- particles ------------------------------------------------------------------------------------------------------
local function burst(pos, kind, n, color)
	local p = new("Part", { Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false, Transparency = 1, Size = Vector3.one, CFrame = at(pos), Parent = workspace })
	local e = new("ParticleEmitter", { Enabled = false, Rotation = NumberRange.new(0, 360) })
	if kind == "dust" then
		e.Texture = "rbxasset://textures/particles/smoke_main.dds"
		e.Color = ColorSequence.new(color or C3(236, 220, 196))
		e.Size = NumberSequence.new({ NSK(0, 1.5), NSK(1, 5) })
		e.Transparency = NumberSequence.new({ NSK(0, 0.35), NSK(1, 1) })
		e.Lifetime = NumberRange.new(0.6, 1.1)
		e.Speed = NumberRange.new(8, 14)
		e.SpreadAngle = Vector2.new(90, 10)
		e.Acceleration = Vector3.new(0, 3, 0)
		e.Drag = 5
	elseif kind == "sparks" then
		e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		e.Color = ColorSequence.new(color or C3(255, 210, 90))
		e.LightEmission = 1
		e.Size = NumberSequence.new({ NSK(0, 0.7), NSK(1, 0) })
		e.Lifetime = NumberRange.new(0.25, 0.5)
		e.Speed = NumberRange.new(14, 24)
		e.SpreadAngle = Vector2.new(70, 70)
		e.Acceleration = Vector3.new(0, -50, 0)
	elseif kind == "confetti" then
		e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		e.Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, C3(255, 80, 80)), ColorSequenceKeypoint.new(0.25, C3(255, 210, 40)), ColorSequenceKeypoint.new(0.5, C3(80, 220, 120)),
			ColorSequenceKeypoint.new(0.75, C3(80, 160, 255)), ColorSequenceKeypoint.new(1, C3(200, 100, 255)) })
		e.LightEmission = 0.4
		e.Size = NumberSequence.new({ NSK(0, 1.6), NSK(1, 0.7) })
		e.Lifetime = NumberRange.new(2, 3.4)
		e.Speed = NumberRange.new(40, 70)
		e.SpreadAngle = Vector2.new(40, 40)
		e.EmissionDirection = Enum.NormalId.Top
		e.Acceleration = Vector3.new(0, -32, 0)
		e.Drag = 1.2
		e.RotSpeed = NumberRange.new(-200, 200)
	elseif kind == "coins" then
		e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		e.Color = ColorSequence.new(C3(255, 220, 60))
		e.LightEmission = 0.8
		e.Size = NumberSequence.new({ NSK(0, 1.2), NSK(1, 0) })
		e.Lifetime = NumberRange.new(0.6, 1)
		e.Speed = NumberRange.new(16, 26)
		e.SpreadAngle = Vector2.new(50, 50)
		e.EmissionDirection = Enum.NormalId.Top
		e.Acceleration = Vector3.new(0, -40, 0)
	end
	e.Parent = p
	e:Emit(n or 10)
	Debris:AddItem(p, 4)
end

-- my plot -----------------------------------------------------------------------------------------------------------
local world = workspace:WaitForChild("World3")
local plotsF = world:WaitForChild("Plots")
local function myPlot()
	local i = plr:GetAttribute("Plot")
	return i and plotsF:FindFirstChild("P" .. i)
end
local function money() return plr:GetAttribute("Money") or 0 end

-- the HUD: a chunky cash badge in the top-left corner --------------------------------------------------------------
local gui = new("ScreenGui", { Name = "HUD3", ResetOnSpawn = false, IgnoreGuiInset = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, Parent = plr:WaitForChild("PlayerGui") })
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

local cashCard = new("Frame", { Name = "Cash", BackgroundColor3 = WHITE, Size = UDim2.fromOffset(270, 74), Position = UDim2.fromOffset(18, 12), Parent = root })
corner(cashCard, 26)
stroke(cashCard, 5)
grad(cashCard, C3(120, 236, 96), C3(34, 170, 70))
local cashGloss = new("Frame", { BackgroundColor3 = WHITE, BackgroundTransparency = 0.72, Size = UDim2.new(1, -16, 0, 22), Position = UDim2.fromOffset(8, 5), ZIndex = 2, Parent = cashCard })
corner(cashGloss, 12)
-- a fat coin
local coin = new("Frame", { BackgroundColor3 = WHITE, Size = UDim2.fromOffset(72, 72), Position = UDim2.fromOffset(-20, 1), ZIndex = 4, Parent = cashCard })
corner(coin, UDim.new(1, 0))
stroke(coin, 5)
grad(coin, C3(255, 236, 110), C3(255, 170, 30))
text({ Text = "$", Size = UDim2.fromScale(0.7, 0.7), Position = UDim2.fromScale(0.15, 0.17), ZIndex = 5, Stroke = 4, Parent = coin })
local cashText = text({ Text = "$0", Size = UDim2.new(1, -72, 0, 46), Position = UDim2.fromOffset(60, 6), XAlign = Enum.TextXAlignment.Left, ZIndex = 3, Stroke = 4, Max = 40, Parent = cashCard })
local incomeText = text({ Text = "+$0/s", Font = FONT, Size = UDim2.new(1, -78, 0, 20), Position = UDim2.fromOffset(62, 50), XAlign = Enum.TextXAlignment.Left, ZIndex = 3, Stroke = 2.5, Max = 19, Color = C3(235, 255, 200), Parent = cashCard })
new("UIScale", { Parent = cashCard })

local shown = 0
RunService.RenderStepped:Connect(function(dt)
	local target = money()
	if math.abs(target - shown) < 1 then shown = target else shown += (target - shown) * math.min(1, dt * 9) end
	cashText.Text = T.Money(shown)
end)
local function bump(o, s)
	local sc = o:FindFirstChildOfClass("UIScale") or new("UIScale", { Parent = o })
	sc.Scale = s or 1.12
	tween(sc, 0.3, { Scale = 1 }, Enum.EasingStyle.Back)
end

-- a toast in the top middle (short, then gone)
local toastHolder = new("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 14), Size = UDim2.fromOffset(560, 60), Parent = root })
local function toast(msg, col)
	for _, c in ipairs(toastHolder:GetChildren()) do c:Destroy() end
	local f = new("Frame", { BackgroundColor3 = WHITE, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0), Size = UDim2.fromOffset(40 + #msg * 15, 52), Parent = toastHolder })
	corner(f, 24)
	stroke(f, 4)
	local c = col or C3(255, 214, 60)
	grad(f, c:Lerp(WHITE, 0.25), c)
	text({ Text = msg, Size = UDim2.new(1, -24, 1, -14), Position = UDim2.fromOffset(12, 7), Stroke = 3, Max = 30, Parent = f })
	bump(f, 0.6)
	task.delay(2.2, function() if f.Parent then tween(f, 0.25, { Position = UDim2.new(0.5, 0, 0, -80) }) Debris:AddItem(f, 0.3) end end)
end

-- the hint at the bottom (what to do now)
local hint = text({ Text = "", Font = BIG, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -22), Size = UDim2.fromOffset(700, 34), Stroke = 4, Max = 30, Parent = root })

-- world cards: a BillboardGui sized in studs whose design (w x h pixels) is scaled to it, capped close up
local function worldCard(adornee, studs, w, h, offsetY)
	local bb = new("BillboardGui", { Adornee = adornee, Size = UDim2.new(studs, 60, studs * h / w, 60 * h / w), StudsOffsetWorldSpace = Vector3.new(0, offsetY or 0, 0),
		LightInfluence = 0, MaxDistance = 140, ResetOnSpawn = false, Parent = plr.PlayerGui })
	local r = new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(w, h), AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.fromScale(0.5, 1), Parent = bb })
	local sc = new("UIScale", { Parent = r })
	bb:GetPropertyChangedSignal("AbsoluteSize"):Connect(function() sc.Scale = math.min(1.1, bb.AbsoluteSize.X / w) end)
	return bb, r, sc
end

-- the buttons -------------------------------------------------------------------------------------------------------
local cards = {} -- button model -> { bb, frame, ... }
local function priceText(p) return p == 0 and "FREE" or T.Money(p) end
local function makeCard(btn)
	local disc = btn:WaitForChild("Disc", 3)
	if not disc then return end
	local mine = btn:GetAttribute("Plot") == plr:GetAttribute("Plot")
	local bb, r = worldCard(disc, 9, 300, 160, 1.2)
	bb.MaxDistance = mine and 150 or 70
	local card = new("Frame", { BackgroundColor3 = WHITE, Size = UDim2.fromOffset(300, 112), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 0), ZIndex = 1, Parent = r })
	corner(card, 28)
	stroke(card, 5)
	local g = grad(card, C3(120, 236, 96), C3(34, 170, 70))
	local gloss = new("Frame", { BackgroundColor3 = WHITE, BackgroundTransparency = 0.75, Size = UDim2.new(1, -18, 0, 30), Position = UDim2.fromOffset(9, 6), ZIndex = 2, Parent = card })
	corner(gloss, 14)
	-- the tail pointing down at the disc
	local tail = new("Frame", { BackgroundColor3 = WHITE, Rotation = 45, AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(24, 24), Position = UDim2.new(0.5, 0, 0, 144), ZIndex = 0, Parent = r })
	stroke(tail, 5)
	local tg = grad(tail, C3(34, 170, 70), C3(34, 170, 70))
	local label = text({ Text = string.upper(btn:GetAttribute("Label") or ""), Size = UDim2.new(1, -24, 0, 40), Position = UDim2.fromOffset(12, 8), ZIndex = 3, Stroke = 4, Max = 34, Parent = card })
	local price = text({ Text = priceText(btn:GetAttribute("Price") or 0), Size = UDim2.new(1, -24, 0, 40), Position = UDim2.fromOffset(12, 46), ZIndex = 3, Stroke = 4, Max = 38, Color = C3(255, 240, 120), Parent = card })
	local inc = btn:GetAttribute("Income") or 0
	local bon = btn:GetAttribute("Bonus") or 0
	local sub = inc > 0 and ("+" .. T.Money(inc) .. "/s") or (bon > 0 and ("+" .. math.floor(bon * 100 + 0.5) .. "% income") or (btn:GetAttribute("Kind") == "worker" and "builds faster" or ""))
	local subChip
	if sub ~= "" then
		subChip = new("Frame", { BackgroundColor3 = C3(36, 30, 70), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0, 112), Size = UDim2.fromOffset(40 + #sub * 12, 34), ZIndex = 4, Parent = card })
		corner(subChip, 16)
		stroke(subChip, 3, WHITE)
		text({ Text = sub, Font = FONT, Size = UDim2.new(1, -12, 1, -6), Position = UDim2.fromOffset(6, 3), ZIndex = 5, Stroke = 2, Max = 22, Parent = subChip })
	end
	local c = { bb = bb, r = r, card = card, g = g, tg = tg, price = btn:GetAttribute("Price") or 0, mine = mine, disc = disc, btn = btn, state = nil }
	cards[btn] = c
	-- it pops up: the disc grows, the card bounces in
	local s0 = disc.Size
	disc.Size = Vector3.new(s0.X, 0.1, 0.1)
	tween(disc, 0.45, { Size = s0 }, Enum.EasingStyle.Back)
	local sc = new("UIScale", { Scale = 0.2, Parent = card })
	tween(sc, 0.45, { Scale = 1 }, Enum.EasingStyle.Back)
	if mine then
		sfx3D("Chime", disc.Position, 0.35, 1.3)
		burst(disc.Position + Vector3.new(0, 1, 0), "sparks", 12, C3(140, 255, 160))
	end
	-- bought: the card shoots up and shrinks, the disc flashes
	btn:GetAttributeChangedSignal("Bought"):Connect(function()
		if not btn:GetAttribute("Bought") then return end
		tween(sc, 0.35, { Scale = 0 }, Enum.EasingStyle.Back, Enum.EasingDirection.In)
		bb.StudsOffsetWorldSpace += Vector3.new(0, 2, 0)
		disc.Color = WHITE
		tween(disc, 0.4, { Size = Vector3.new(s0.X, s0.Y * 1.6, s0.Z * 1.6), Transparency = 1 })
		burst(disc.Position + Vector3.new(0, 1, 0), "coins", 18)
		if mine then sfx("Coins", 0.5, 1.1) sfx("Hammer", 0.5, 1.2) end
	end)
	btn.Destroying:Connect(function() bb:Destroy() cards[btn] = nil end)
end
local function watchButtons(plot)
	local f = plot:WaitForChild("Buttons")
	f.ChildAdded:Connect(function(b) task.defer(makeCard, b) end)
	for _, b in ipairs(f:GetChildren()) do task.spawn(makeCard, b) end
end
for _, p in ipairs(plotsF:GetChildren()) do task.spawn(watchButtons, p) end

-- green when you can pay, red when you cannot (yours); grey (someone else's)
local GREEN, RED, GREY = { C3(120, 236, 96), C3(34, 170, 70) }, { C3(255, 120, 120), C3(214, 50, 60) }, { C3(200, 206, 220), C3(130, 138, 160) }
task.spawn(function()
	while true do
		local m = money()
		for btn, c in pairs(cards) do
			local col = not c.mine and GREY or (m >= c.price and GREEN or RED)
			if c.state ~= col then
				c.state = col
				c.g.Color = ColorSequence.new(col[1], col[2])
				c.tg.Color = ColorSequence.new(col[2], col[2])
				if c.disc.Parent and not btn:GetAttribute("Bought") then
					c.disc.Color = col == GREEN and C3(70, 225, 110) or (col == RED and C3(255, 90, 90) or C3(170, 176, 196))
				end
			end
		end
		task.wait(0.2)
	end
end)
-- a soft pulse on the buttons you can buy
RunService.Heartbeat:Connect(function()
	local t = os.clock()
	for _, c in pairs(cards) do
		if c.state == GREEN and c.disc.Parent and not c.btn:GetAttribute("Bought") then
			c.disc.Transparency = 0.05 + (math.sin(t * 5) + 1) * 0.12
		end
	end
end)

-- the construction show ---------------------------------------------------------------------------------------------
local function near(pos, d)
	local cam = workspace.CurrentCamera
	return cam and (cam.CFrame.Position - pos).Magnitude < (d or 400)
end
-- a model falls into place from above with a bounce (and fades in)
local function dropIn(m, height, dur, dust)
	if not m.Parent then return end
	local pivot = m:GetPivot()
	if not near(pivot.Position) then return end
	local parts, trans = {}, {}
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("BasePart") then table.insert(parts, d) trans[d] = d.Transparency d.Transparency = 1 end
	end
	m:PivotTo(pivot + Vector3.new(0, height, 0))
	local v = new("NumberValue", { Value = 1 })
	v.Changed:Connect(function(x) if m.Parent then m:PivotTo(pivot + Vector3.new(0, height * x, 0)) end end)
	tween(v, dur, { Value = 0 }, Enum.EasingStyle.Bounce)
	for _, p in ipairs(parts) do tween(p, dur * 0.4, { Transparency = trans[p] }) end
	task.delay(dur * 0.45, function()
		if dust then
			local cf, size = m:GetBoundingBox()
			burst(cf.Position - Vector3.new(0, size.Y / 2, 0), "dust", 8)
		end
	end)
	Debris:AddItem(v, dur + 0.2)
end
-- a road chunk is poured: each part grows along the street from its front edge
local function pour(c)
	local parts = {}
	for _, d in ipairs(c:GetDescendants()) do if d:IsA("BasePart") then table.insert(parts, d) end end
	if #parts == 0 or not near(parts[1].Position) then return end
	for _, p in ipairs(parts) do
		local cf, s = p.CFrame, p.Size
		p.Size = Vector3.new(s.X, s.Y, 0.05)
		p.CFrame = cf * at(0, 0, -s.Z / 2)
		tween(p, 0.45, { Size = s, CFrame = cf }, Enum.EasingStyle.Sine)
	end
	local first = parts[1]
	burst((first.CFrame * at(0, 1, 0)).Position, "dust", 10, C3(110, 110, 120))
	sfx3D("Pour", first.Position, 0.35, 1.1 + math.random() * 0.2)
end
local function floorSound(f)
	local mat
	for _, d in ipairs(f:GetDescendants()) do if d:IsA("BasePart") then mat = d.Material break end end
	local key = (mat == Enum.Material.Glass and "Metal") or (mat == Enum.Material.WoodPlanks and "Wood") or "Brick"
	local cf = f:GetBoundingBox()
	sfx3D(key, cf.Position, key == "Metal" and 0.18 or 0.35, 0.9 + math.random() * 0.2)
end
-- the "+$X/s" that rises from a finished building
local function riseText(pos, msg, col)
	local a = new("Part", { Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false, Transparency = 1, Size = Vector3.one, CFrame = at(pos), Parent = workspace })
	local bb = new("BillboardGui", { Adornee = a, Size = UDim2.fromOffset(320, 80), AlwaysOnTop = true, LightInfluence = 0, Parent = plr.PlayerGui })
	local t = text({ Text = msg, Size = UDim2.fromScale(1, 1), Stroke = 5, Max = 56, Color = col or C3(140, 255, 120), Parent = bb })
	local sc = new("UIScale", { Scale = 0.3, Parent = t })
	tween(sc, 0.4, { Scale = 1 }, Enum.EasingStyle.Back)
	tween(a, 2, { CFrame = at(pos + Vector3.new(0, 14, 0)) }, Enum.EasingStyle.Sine)
	task.delay(1.4, function() tween(t, 0.5, { TextTransparency = 1 }) end)
	Debris:AddItem(a, 2.1)
	Debris:AddItem(bb, 2.1)
end
-- the finished building bounces (a quick squash and stretch)
local function bounce(m)
	local ok = pcall(function() return m:GetScale() end)
	if not ok then return end
	local v = new("NumberValue", { Value = 1 })
	v.Changed:Connect(function(x) if m.Parent then pcall(function() m:ScaleTo(x) end) end end)
	local up = tween(v, 0.16, { Value = 1.08 }, Enum.EasingStyle.Quad)
	up.Completed:Connect(function() tween(v, 0.5, { Value = 1 }, Enum.EasingStyle.Elastic) end)
	Debris:AddItem(v, 1)
end

local function watchBuilt(plot)
	local built = plot:WaitForChild("Built")
	local function onThing(m)
		if not m:IsA("Model") then return end
		-- a new builder arrives in a puff
		if m.Name:match("^Builder") then
			task.delay(0.2, function()
				local hrp = m:FindFirstChild("HumanoidRootPart")
				if hrp and near(hrp.Position, 200) then burst(hrp.Position, "dust", 14) burst(hrp.Position + Vector3.new(0, 2, 0), "sparks", 12) end
			end)
			return
		end
		m.ChildAdded:Connect(function(c)
			if not c:IsA("Model") then return end
			if c:GetAttribute("Floor") then
				task.defer(function()
					dropIn(c, 7, 0.5, true)
					task.delay(0.22, floorSound, c)
				end)
			elseif c:GetAttribute("Grow") then
				task.defer(pour, c)
			elseif c:GetAttribute("Drop") then
				task.defer(function()
					dropIn(c, 12, 0.7, true)
					local cf = c:GetBoundingBox()
					sfx3D("Wood", cf.Position, 0.3, 1)
				end)
			end
		end)
		m:GetAttributeChangedSignal("State"):Connect(function()
			if m:GetAttribute("State") ~= "done" or not near(m:GetPivot().Position) then return end
			if m:GetAttribute("Kind") == "building" then
				bounce(m)
				local cf, size = m:GetBoundingBox()
				burst(cf.Position + Vector3.new(0, size.Y / 2 + 2, 0), "confetti", 70)
				burst(cf.Position - Vector3.new(0, size.Y / 2, 0), "dust", 14)
			end
		end)
	end
	built.ChildAdded:Connect(onThing)
	for _, m in ipairs(built:GetChildren()) do onThing(m) end
end
for _, p in ipairs(plotsF:GetChildren()) do task.spawn(watchBuilt, p) end

-- builders' hammer hits: sparks and a knock now and then
local lastKnock = 0
HitsRE.OnClientEvent:Connect(function(list)
	for _, h in ipairs(list) do
		if near(h[1], 250) then burst(h[1], "sparks", h[3] and 12 or 6) end
		if os.clock() - lastKnock > 0.2 and near(h[1], 90) then
			lastKnock = os.clock()
			sfx3D("Hammer", h[1], h[3] and 0.5 or 0.25, 0.95 + math.random() * 0.2)
		end
	end
end)

-- the vaults: their screens count up ---------------------------------------------------------------------------------
local vaultShown = {}
RunService.Heartbeat:Connect(function(dt)
	for _, p in ipairs(plotsF:GetChildren()) do
		local v = p:FindFirstChild("Vault")
		local screen = v and v:FindFirstChild("Screen")
		local lbl = screen and screen:FindFirstChild("Label") and screen.Label:FindFirstChild("Cash")
		if lbl then
			local target = p:GetAttribute("Vault") or 0
			local s = vaultShown[p] or 0
			if target < s then s = target else s += (target - s) * math.min(1, dt * 6) end
			vaultShown[p] = s
			lbl.Text = T.Money(s)
		end
	end
end)

-- coins: from your buildings into your vault ---------------------------------------------------------------------------
local coinTemplate = new("Part", { Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.35, 2, 2), Color = C3(255, 205, 50), Material = Enum.Material.Neon, Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false })
local function flyCoin(from, to)
	local c = coinTemplate:Clone()
	c.CFrame = at(from)
	c.Parent = workspace
	local mid = (from + to) / 2 + Vector3.new(0, 18 + math.random() * 8, 0)
	local v = new("NumberValue", { Value = 0 })
	v.Changed:Connect(function(t)
		local a = from:Lerp(mid, t):Lerp(mid:Lerp(to, t), t)
		c.CFrame = at(a) * CFrame.Angles(0, t * 12, math.pi / 2)
	end)
	local tw = tween(v, 1.1, { Value = 1 }, Enum.EasingStyle.Sine, Enum.EasingDirection.In)
	tw.Completed:Connect(function() c:Destroy() v:Destroy() end)
end
task.spawn(function()
	while true do
		task.wait(2.4)
		local p = myPlot()
		local vault = p and p:FindFirstChild("Vault")
		if vault and vault.PrimaryPart and near(vault.PrimaryPart.Position, 300) then
			local to = vault.PrimaryPart.Position + Vector3.new(0, 4, 0)
			local n = 0
			for _, m in ipairs(p.Built:GetChildren()) do
				if m:GetAttribute("Kind") == "building" and m:GetAttribute("State") == "done" and n < 8 then
					n += 1
					local o = m:GetAttribute("Origin")
					local h = m:GetAttribute("Height") or 10
					if typeof(o) == "CFrame" then
						task.delay(n * 0.12, flyCoin, o.Position + Vector3.new(0, h * 0.6, 0), to)
					end
				end
			end
		end
	end
end)

-- events from the server --------------------------------------------------------------------------------------------
EventRE.OnClientEvent:Connect(function(kind, d)
	if kind == "Collect" then
		sfx("Coins", 0.6, 1)
		bump(cashCard, 1.15)
		local p = myPlot()
		local pad = p and p:FindFirstChild("VaultPad")
		if pad then burst(pad.Position + Vector3.new(0, 1, 0), "coins", 30) riseText(pad.Position + Vector3.new(0, 6, 0), "+" .. T.Money(d.amount), C3(255, 230, 90)) end
	elseif kind == "Built" then
		local p = myPlot()
		local m = p and p.Built:FindFirstChild(d.id)
		if d.kind == "building" then
			sfx("Fanfare", 0.32, 1.1)
			task.delay(2.4, function() local s = sounds.Fanfare if s and s.IsPlaying then tween(s, 0.6, { Volume = 0 }) end end)
			if m then
				local cf, size = m:GetBoundingBox()
				riseText(cf.Position + Vector3.new(0, size.Y / 2 + 4, 0), "+" .. T.Money(d.income) .. "/s")
			end
			toast(string.upper(d.label) .. " BUILT!", C3(120, 236, 96))
		elseif d.kind == "worker" then
			sfx("Chime", 0.5, 1)
			toast("A NEW BUILDER JOINED!", C3(255, 200, 70))
		else
			sfx("Chime", 0.4, 1.15)
		end
	elseif kind == "Bought" then
		bump(cashCard, 0.94)
	elseif kind == "Need" then
		toast("NEED " .. T.Money(d.price - d.have) .. " MORE", C3(255, 110, 110))
		sfx("Click", 0.4, 0.8)
	end
end)

-- the income line under the cash
task.spawn(function()
	while true do
		local p = myPlot()
		incomeText.Text = "+" .. T.Money(p and p:GetAttribute("Income") or 0) .. "/s"
		task.wait(0.5)
	end
end)

-- the hint: what to do now
task.spawn(function()
	while true do
		local p = myPlot()
		local msg = ""
		if p then
			local vault = p:GetAttribute("Vault") or 0
			local any, can = false, false
			for btn, c in pairs(cards) do
				if c.mine and btn.Parent and not btn:GetAttribute("Bought") then
					any = true
					if money() >= c.price then can = true end
				end
			end
			if vault >= 10 and not can then msg = "COLLECT YOUR CASH AT THE VAULT!"
			elseif can then msg = "STEP ON A GREEN BUTTON TO BUILD!"
			elseif any then msg = "YOUR CITY IS MAKING MONEY..." end
		end
		if hint.Text ~= msg then hint.Text = msg end
		task.wait(0.4)
	end
end)

-- your hammer: held up like a tool; a click near one of your sites is a blow that speeds it up ----------------------
local holdTrack, slashTrack
local function setupHold(char)
	local hum = char:WaitForChild("Humanoid", 10)
	if not hum then return end
	local animator = hum:WaitForChild("Animator", 10)
	if not animator then return end
	local a = new("Animation", { AnimationId = "rbxassetid://507768375" })
	holdTrack = animator:LoadAnimation(a)
	holdTrack.Priority = Enum.AnimationPriority.Action
	holdTrack.Looped = true
	holdTrack:Play()
	local s = new("Animation", { AnimationId = "rbxassetid://522635514" })
	slashTrack = animator:LoadAnimation(s)
	slashTrack.Priority = Enum.AnimationPriority.Action2
end
plr.CharacterAdded:Connect(function(c) task.defer(setupHold, c) end)
if plr.Character then task.spawn(setupHold, plr.Character) end
UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then return end
	local p = myPlot()
	local char = plr.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not p or not hrp then return end
	-- only near a site being built
	local close = false
	for _, m in ipairs(p.Built:GetChildren()) do
		if m:GetAttribute("State") == "building" then
			local ok, cf = pcall(function() return m:GetBoundingBox() end)
			if ok and (cf.Position - hrp.Position).Magnitude < 60 then close = true break end
		end
	end
	if not close then return end
	TapRE:FireServer()
	if slashTrack and not slashTrack.IsPlaying then
		local wd = char:FindFirstChild("GripWeld", true)
		local base = wd and wd:GetAttribute("Base")
		if base then
			wd.C0 = base
			task.delay(0.5, function() if wd.Parent then wd.C0 = base * CFrame.Angles(math.rad(35), 0, 0) end end)
		end
		slashTrack:Play(0.05, 1, 1.6)
	end
end)

print("[Client3] BlockRise 3.0 prototype client ready")
