-- BlockRise Empire - hammer effects (client, StarterPlayerScripts.HammerFX)
--  * the hammers in the world come alive: the Galaxy core drifts through space, the Thunderclap crackles
--  * hits with the better hammers burst in the hammer's colours (yours, and other players' near you)
--  * every new hammer gets its own reveal card (and the Thunderclap add-on too)
-- Kept apart from Client on purpose: Client is at Luau's 200 locals limit.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local Debris = game:GetService("Debris")
local SoundService = game:GetService("SoundService")

if RS:GetAttribute("IsBounce") then return end -- the short stop between two versions: nothing to show

local Config = require(RS:WaitForChild("Shared"):WaitForChild("Config"))
local UI = require(RS.Shared:WaitForChild("UIKit"))
local K = require(RS.Shared:WaitForChild("MenuKit"))
local T = UI.Theme
local new = UI.new
local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local Remotes = RS:WaitForChild("Remotes")
local Feedback = Remotes:WaitForChild("Feedback")
local HitFX = Remotes:WaitForChild("HitFX")
local S = Config.Sounds or {}

local SPARK = "rbxasset://textures/particles/sparkles_main.dds"
local FIRE = "rbxasset://textures/particles/fire_main.dds"
local NSK = NumberSequenceKeypoint.new

local function sound(id, vol, pitch)
	if not id then return end
	local s = new("Sound", { SoundId = id, Volume = vol or 0.5, PlaybackSpeed = pitch or 1, Parent = SoundService })
	s:Play()
	Debris:AddItem(s, 6)
end

local function toolCfg(tool)
	local key = tool:GetAttribute("Key")
	if Config.StormHammer and key == Config.StormHammer.key then return Config.StormHammer, 16 end
	for i, t in ipairs(Config.Tools) do
		if t.key == key then return t, i end
	end
end

---------------------------------------------------------------------------
-- 1. hammers in the world: galaxy drift, thunder crackle
---------------------------------------------------------------------------
local live = {} -- tool -> { spaces, light, base, neon, emitters, galaxy, thunder, nextFlash }

local track
function track(tool)
	if live[tool] then return end
	local key = tool:GetAttribute("Key")
	local thunder = Config.StormHammer and key == Config.StormHammer.key
	local e = { spaces = {}, neon = {}, emitters = {}, galaxy = key == "galaxy", thunder = thunder, nextFlash = os.clock() + 1 }
	for _, d in ipairs(tool:GetDescendants()) do
		if d:IsA("Texture") and d.Name == "Space" then
			table.insert(e.spaces, { tx = d, su = d.StudsPerTileU, sv = d.StudsPerTileV, k = (#e.spaces % 3) - 1 })
		elseif d:IsA("PointLight") then
			e.light, e.base = d, d.Brightness
		elseif d:IsA("ParticleEmitter") then
			table.insert(e.emitters, d)
		elseif d:IsA("BasePart") and d.Material == Enum.Material.Neon then
			table.insert(e.neon, { part = d, color = d.Color })
		end
	end
	if #e.spaces == 0 and not e.light then
		-- another player's hammer can arrive a moment before its parts: look again once
		if (e.galaxy or e.thunder) and not tool:GetAttribute("FxRetry") then
			tool:SetAttribute("FxRetry", true)
			task.delay(1, function() if tool:IsDescendantOf(workspace) then track(tool) end end)
		end
		return
	end
	live[tool] = e
end

local function scan(d)
	if d:IsA("Tool") and d:GetAttribute("Key") then track(d) end
end
workspace.DescendantAdded:Connect(scan)
for _, d in ipairs(workspace:GetDescendants()) do scan(d) end

local function flash(e)
	-- a crack of lightning inside the hammer: the light jumps, the cores go white, sparks fly
	if e.light then
		e.light.Brightness = e.base * 3.2
		task.delay(0.05, function() if e.light then e.light.Brightness = e.base * 0.5 end end)
		task.delay(0.1, function() if e.light then e.light.Brightness = e.base * 2.4 end end)
	end
	for _, n in ipairs(e.neon) do
		n.part.Color = n.color:Lerp(Color3.new(1, 1, 1), 0.7)
		task.delay(0.14, function() if n.part.Parent then n.part.Color = n.color end end)
	end
	for _, pe in ipairs(e.emitters) do pe:Emit(3) end
end

RunService.Heartbeat:Connect(function()
	local now = os.clock()
	local cam = camera.CFrame.Position
	for tool, e in pairs(live) do
		if not tool.Parent or not tool:IsDescendantOf(workspace) then
			live[tool] = nil
		else
			local h = tool:FindFirstChild("Handle")
			local near = h and (h.Position - cam).Magnitude < 150
			if near then
				-- the galaxy: every face drifts its own way, slowly, like the sky turning
				for _, s in ipairs(e.spaces) do
					s.tx.OffsetStudsU = (now * 0.22 * (s.k == 0 and 1 or s.k)) % s.su
					s.tx.OffsetStudsV = (now * 0.13) % s.sv
				end
				if e.galaxy and e.light then
					local hue = 0.72 + math.sin(now * 0.8) * 0.08
					e.light.Color = Color3.fromHSV(hue % 1, 0.6, 1)
					e.light.Brightness = e.base * (0.85 + 0.25 * math.sin(now * 2.3))
				end
				if e.thunder and e.light then
					if now >= e.nextFlash then
						e.nextFlash = now + 0.7 + math.random() * 1.8
						flash(e)
					elseif e.light.Brightness < e.base * 2 then
						-- restless glow between the cracks
						e.light.Brightness = e.base * (0.75 + 0.35 * math.noise(now * 6, 0.5))
					end
				end
			end
		end
	end
end)

---------------------------------------------------------------------------
-- 2. hit bursts with the better hammers
---------------------------------------------------------------------------
local fxRoot = new("Attachment", { Name = "HammerFX", Parent = workspace.Terrain })
local function emitter(name, tex, props)
	local pe = new("ParticleEmitter", { Name = name, Texture = tex, Enabled = false, LightEmission = 1, LightInfluence = 0, Rate = 0,
		SpreadAngle = Vector2.new(180, 180), Parent = fxRoot })
	for k, v in pairs(props) do pe[k] = v end
	return pe
end
local PE = {
	glint = emitter("Glint", SPARK, { Lifetime = NumberRange.new(0.35, 0.6), Speed = NumberRange.new(4, 9), Drag = 4,
		Size = NumberSequence.new({ NSK(0, 0), NSK(0.3, 0.9), NSK(1, 0) }), Transparency = NumberSequence.new(0, 1), Rotation = NumberRange.new(0, 360) }),
	sparks = emitter("Sparks", SPARK, { Lifetime = NumberRange.new(0.18, 0.35), Speed = NumberRange.new(10, 18), Drag = 7,
		Size = NumberSequence.new({ NSK(0, 0.45), NSK(1, 0) }), Transparency = NumberSequence.new(0, 1) }),
	fire = emitter("Fire", FIRE, { Lifetime = NumberRange.new(0.3, 0.55), Speed = NumberRange.new(3, 7), Drag = 3, Acceleration = Vector3.new(0, 6, 0),
		Size = NumberSequence.new({ NSK(0, 0.8), NSK(1, 0) }), Transparency = NumberSequence.new(0.1, 1), Rotation = NumberRange.new(0, 360) }),
	bloom = emitter("Bloom", SPARK, { Lifetime = NumberRange.new(0.22, 0.22), Speed = NumberRange.new(0, 0),
		Size = NumberSequence.new({ NSK(0, 1), NSK(1, 7) }), Transparency = NumberSequence.new({ NSK(0, 0.25), NSK(1, 1) }) }),
}

-- what each hammer adds to a hit: { burst kind, colours, count, bloom? }
local function seq(a, b) return ColorSequence.new(a, b or a) end
local BURST = {
	gold = { "glint", seq(Color3.fromRGB(255, 225, 120), Color3.fromRGB(255, 180, 40)), 5 },
	titanium = { "sparks", seq(Color3.fromRGB(255, 200, 120), Color3.fromRGB(255, 120, 40)), 7 },
	emerald = { "glint", seq(Color3.fromRGB(120, 255, 170), Color3.fromRGB(20, 200, 110)), 7 },
	ruby = { "glint", seq(Color3.fromRGB(255, 120, 150), Color3.fromRGB(230, 30, 70)), 8 },
	sapphire = { "glint", seq(Color3.fromRGB(130, 180, 255), Color3.fromRGB(40, 100, 255)), 9 },
	amethyst = { "glint", seq(Color3.fromRGB(220, 170, 255), Color3.fromRGB(150, 70, 255)), 10 },
	lava = { "fire", seq(Color3.fromRGB(255, 200, 80), Color3.fromRGB(255, 70, 10)), 10, Color3.fromRGB(255, 120, 30) },
	frost = { "glint", seq(Color3.fromRGB(230, 250, 255), Color3.fromRGB(120, 215, 255)), 12, Color3.fromRGB(160, 230, 255) },
	diamond = { "glint", ColorSequence.new({ ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)), ColorSequenceKeypoint.new(0.5, Color3.fromRGB(170, 235, 255)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 200, 250)) }), 14, Color3.fromRGB(210, 245, 255) },
	plasma = { "sparks", seq(Color3.fromRGB(180, 250, 255), Color3.fromRGB(40, 200, 255)), 16, Color3.fromRGB(80, 220, 255) },
	solar = { "fire", seq(Color3.fromRGB(255, 240, 150), Color3.fromRGB(255, 140, 20)), 14, Color3.fromRGB(255, 190, 60) },
	galaxy = { "glint", ColorSequence.new({ ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 150, 240)), ColorSequenceKeypoint.new(0.5, Color3.fromRGB(160, 110, 255)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(90, 180, 255)) }), 18, Color3.fromRGB(170, 120, 255) },
	thunder = { "sparks", seq(Color3.fromRGB(230, 245, 255), Color3.fromRGB(90, 170, 255)), 18, Color3.fromRGB(140, 200, 255) },
}

local function lightFlash(pos, color, brightness, range)
	local a = new("Attachment", { WorldPosition = pos, Parent = workspace.Terrain })
	local l = new("PointLight", { Color = color, Brightness = brightness, Range = range, Shadows = false, Parent = a })
	UI.tween(l, 0.3, { Brightness = 0 })
	Debris:AddItem(a, 0.35)
end

-- a bolt from the sky onto the hit (the Thunderclap, every few hits)
local function lightning(pos)
	local top = pos + Vector3.new((math.random() - 0.5) * 8, 34, (math.random() - 0.5) * 8)
	local pts = { top }
	local n = 8
	for i = 1, n - 1 do
		local p = top:Lerp(pos, i / n)
		local j = 2.2 * (1 - i / n) + 0.4
		table.insert(pts, p + Vector3.new((math.random() - 0.5) * j * 2, 0, (math.random() - 0.5) * j * 2))
	end
	table.insert(pts, pos)
	local folder = new("Model", { Name = "Bolt", Parent = workspace })
	local function seg(a, b, w, color, trans)
		local len = (b - a).Magnitude
		local p = new("Part", { Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false, Material = Enum.Material.Neon,
			Color = color, Transparency = trans, Size = Vector3.new(w, w, len), CFrame = CFrame.lookAt((a + b) / 2, b), Parent = folder })
		UI.tween(p, 0.28, { Transparency = 1, Size = Vector3.new(w * 0.3, w * 0.3, len) })
	end
	for i = 1, #pts - 1 do
		seg(pts[i], pts[i + 1], 0.55, Color3.fromRGB(110, 180, 255), 0.35) -- blue glow
		seg(pts[i], pts[i + 1], 0.2, Color3.fromRGB(240, 250, 255), 0) -- white-hot core
		-- a small fork now and then
		if i > 1 and i < #pts - 1 and math.random() < 0.35 then
			local f = pts[i] + Vector3.new((math.random() - 0.5) * 6, -math.random() * 4 - 1, (math.random() - 0.5) * 6)
			seg(pts[i], f, 0.14, Color3.fromRGB(200, 230, 255), 0.1)
		end
	end
	Debris:AddItem(folder, 0.35)
	lightFlash(pos + Vector3.new(0, 3, 0), Color3.fromRGB(170, 210, 255), 9, 40)
	sound(S.Metal, 0.35, 0.55)
end

local hits = 0
local function burst(tool, pos, mine)
	if not tool or typeof(pos) ~= "Vector3" then return end
	if (pos - camera.CFrame.Position).Magnitude > 160 then return end
	local key = tool:GetAttribute("Key")
	local b = BURST[key]
	if not b then return end
	fxRoot.WorldPosition = pos + Vector3.new(0, 0.6, 0)
	local pe = PE[b[1]]
	pe.Color = b[2]
	pe:Emit(mine and b[3] or math.ceil(b[3] / 2))
	if b[4] then
		PE.bloom.Color = seq(b[4])
		PE.bloom:Emit(1)
		if mine then lightFlash(pos, b[4], 4, 16) end
	end
	if key == "galaxy" then
		PE.sparks.Color = seq(Color3.fromRGB(255, 255, 255), Color3.fromRGB(200, 160, 255))
		PE.sparks:Emit(mine and 8 or 4)
	end
	if Config.StormHammer and key == Config.StormHammer.key then
		hits += 1
		if hits % 3 == 0 or not mine then lightning(pos) end
	end
end

local function heldTool(plr)
	local char = plr and plr.Character
	if not char then return nil end
	for _, c in ipairs(char:GetChildren()) do
		if c:IsA("Tool") and c:GetAttribute("Key") then return c end
	end
end

---------------------------------------------------------------------------
-- 3. the reveal card: a new hammer is a big moment
---------------------------------------------------------------------------
local gui = new("ScreenGui", { Name = "HammerFX", IgnoreGuiInset = true, ResetOnSpawn = false, DisplayOrder = 60, ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	Parent = player:WaitForChild("PlayerGui") })
local scale = new("UIScale", { Parent = gui })
local function updateScale()
	local vp = camera.ViewportSize
	local touch = UIS.TouchEnabled and not UIS.KeyboardEnabled
	if touch then
		scale.Scale = math.clamp(math.min(vp.X / 950, vp.Y / 560), 0.5, 1)
	else
		scale.Scale = math.clamp(math.min(vp.X / 1300, vp.Y / 800), 0.6, 1.15)
	end
end
camera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)
updateScale()

local card -- the one on screen
local function closeCard(fast)
	local c = card
	if not c then return end
	card = nil
	c.closing = true
	gui:SetAttribute("Open", false)
	if fast then c.root:Destroy() return end
	UI.tween(c.sc, 0.2, { Scale = 0.75 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	UI.tween(c.dim, 0.2, { BackgroundTransparency = 1 })
	for _, d in ipairs(c.root:GetDescendants()) do
		if d:IsA("ImageLabel") then UI.tween(d, 0.18, { ImageTransparency = 1 })
		elseif d:IsA("TextLabel") then UI.tween(d, 0.18, { TextTransparency = 1 })
		elseif d:IsA("UIStroke") then UI.tween(d, 0.18, { Transparency = 1 }) end
	end
	task.delay(0.22, function() c.root:Destroy() end)
end

local function reveal(o)
	closeCard(true)
	local c = {}
	card = c
	gui:SetAttribute("Open", true) -- Client's big banners wait while the card is up
	-- the root covers the screen (UIScale makes the design space bigger or smaller than the screen)
	local root = new("Frame", { Name = "Reveal", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1, Parent = gui })
	c.root = root
	local dim = new("TextButton", { Name = "Dim", Text = "", AutoButtonColor = false, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(4, 4), BackgroundColor3 = Color3.fromRGB(8, 6, 20), BackgroundTransparency = 1, ZIndex = 1, Parent = root })
	c.dim = dim
	UI.tween(dim, 0.3, { BackgroundTransparency = 0.3 })
	local box = new("Frame", { Name = "Card", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(560, 480),
		BackgroundTransparency = 1, ZIndex = 2, Parent = root })
	local sc = new("UIScale", { Scale = 0.6, Parent = box })
	c.sc = sc
	UI.tween(sc, 0.45, { Scale = 1 }, Enum.EasingStyle.Back)
	local col = o.color or T.accent

	-- light rays (two layers turning opposite ways) and a soft glow behind the hammer
	local ICON_Y = 200
	local rays = UI.slice("rays", { Name = "Rays", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(280, ICON_Y), Size = UDim2.fromOffset(640, 640),
		ImageColor3 = col, ImageTransparency = 1, ZIndex = 2, Parent = box })
	local rays2 = UI.slice("rays", { Name = "Rays2", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(280, ICON_Y), Size = UDim2.fromOffset(460, 460),
		ImageColor3 = Color3.new(1, 1, 1), ImageTransparency = 1, ZIndex = 2, Parent = box })
	local glow = UI.slice("glow", { Name = "Glow", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(280, ICON_Y), Size = UDim2.fromOffset(420, 420),
		ImageColor3 = col:Lerp(Color3.new(1, 1, 1), 0.25), ImageTransparency = 1, ZIndex = 3, Parent = box })
	UI.tween(rays, 0.5, { ImageTransparency = 0.15 })
	UI.tween(rays2, 0.5, { ImageTransparency = 0.55 })
	UI.tween(glow, 0.5, { ImageTransparency = 0.1 })

	-- the hammer: pops in, then floats
	local icon = new("ImageLabel", { Name = "Hammer", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(280, ICON_Y), Size = UDim2.fromOffset(270, 270),
		BackgroundTransparency = 1, Image = o.icon or "", ScaleType = Enum.ScaleType.Fit, ZIndex = 5, Parent = box })
	local isc = new("UIScale", { Scale = 0, Parent = icon })
	task.delay(0.12, function()
		if c.closing then return end
		UI.tween(isc, 0.5, { Scale = 1 }, Enum.EasingStyle.Back)
		sound(S.Chime, 0.6, o.big and 0.9 or 1.15)
	end)

	-- a ring of sparkles shooting out when it lands
	task.delay(0.2, function()
		if c.closing then return end
		for i = 1, 16 do
			local a = (i / 16) * math.pi * 2 + math.random() * 0.3
			local d = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(280, ICON_Y), Size = UDim2.fromOffset(12, 12), Rotation = 45,
				BackgroundColor3 = (i % 2 == 0) and Color3.new(1, 1, 1) or col:Lerp(Color3.new(1, 1, 1), 0.35), BorderSizePixel = 0, ZIndex = 4, Parent = box })
			UI.corner(3).Parent = d
			local r = 190 + math.random() * 90
			UI.tween(d, 0.7 + math.random() * 0.3, { Position = UDim2.fromOffset(280 + math.cos(a) * r, ICON_Y + math.sin(a) * r), Size = UDim2.fromOffset(4, 4),
				BackgroundTransparency = 1, Rotation = 45 + 180 }, Enum.EasingStyle.Quart)
			Debris:AddItem(d, 1.1)
		end
	end)

	-- header + rarity
	local head = UI.label({ Name = "Head", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromOffset(280, 0), Size = UDim2.fromOffset(540, 40), Text = o.head,
		Font = T.chunky, TextSize = 38, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 6, Parent = box })
	new("UIStroke", { Thickness = 3, Color = T.ink, LineJoinMode = Enum.LineJoinMode.Round, Parent = head })
	new("UIGradient", { Color = ColorSequence.new(Color3.fromRGB(255, 250, 210), Color3.fromRGB(255, 200, 60)), Rotation = 90, Parent = head })
	if o.rarity then
		local chip = K.chip(box, o.rarity[1], o.rarity[2], { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromOffset(280, 46), ZIndex = 6 })
		chip.ZIndex = 6
	end

	-- name, what it does, the button
	local name = UI.label({ Name = "Name", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromOffset(280, 330), Size = UDim2.fromOffset(540, 50), Text = string.upper(o.name),
		Font = T.chunky, TextSize = 46, TextXAlignment = Enum.TextXAlignment.Center, TextTransparency = 1, ZIndex = 6, Parent = box })
	new("UITextSizeConstraint", { MaxTextSize = 46, MinTextSize = 20, Parent = name })
	name.TextScaled = true
	local ns = new("UIStroke", { Thickness = 3.5, Color = T.ink, LineJoinMode = Enum.LineJoinMode.Round, Transparency = 1, Parent = name })
	new("UIGradient", { Color = ColorSequence.new(Color3.new(1, 1, 1), col:Lerp(Color3.new(1, 1, 1), 0.45)), Rotation = 90, Parent = name })
	local eff = UI.label({ Name = "Effect", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromOffset(280, 382), Size = UDim2.fromOffset(540, 26), Text = o.effect or "",
		Font = T.title, TextSize = 21, TextColor3 = Color3.fromRGB(255, 232, 140), TextXAlignment = Enum.TextXAlignment.Center, TextTransparency = 1, ZIndex = 6, Parent = box })
	local es = new("UIStroke", { Thickness = 2, Color = T.ink, LineJoinMode = Enum.LineJoinMode.Round, Transparency = 1, Parent = eff })
	task.delay(0.4, function()
		if c.closing then return end
		UI.tween(name, 0.25, { TextTransparency = 0 }); UI.tween(ns, 0.25, { Transparency = 0 })
		local s2 = new("UIScale", { Scale = 1.4, Parent = name })
		UI.tween(s2, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
	end)
	task.delay(0.6, function()
		if c.closing then return end
		UI.tween(eff, 0.25, { TextTransparency = 0 }); UI.tween(es, 0.25, { Transparency = 0 })
	end)
	local btn = UI.button(o.button or "AWESOME!", K.GREEN, nil, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromOffset(280, 420), Size = UDim2.fromOffset(230, 58),
		TextSize = 26, Font = T.chunky, ZIndex = 7, Shine = true, Parent = box })
	btn.Visible = false
	task.delay(0.75, function() if not c.closing then btn.Visible = true end end)
	btn.Activated:Connect(function() sound(S.Click, 0.35); closeCard() end)
	dim.Activated:Connect(function() if os.clock() - c.t0 > 1.2 then closeCard() end end)
	c.t0 = os.clock()

	-- keep it alive: rays turn, the hammer floats
	local conn
	conn = RunService.RenderStepped:Connect(function()
		if not root.Parent then conn:Disconnect() return end
		local t = os.clock() - c.t0
		rays.Rotation = (t * 18) % 360
		rays2.Rotation = (-t * 30) % 360
		icon.Position = UDim2.fromOffset(280, ICON_Y + math.sin(t * 2.2) * 6)
		icon.Rotation = math.sin(t * 1.6) * 4
		glow.Size = UDim2.fromOffset(420 + math.sin(t * 3) * 18, 420 + math.sin(t * 3) * 18)
	end)
	task.delay(9, function() if card == c then closeCard() end end)
	if o.big then sound(S.Fanfare, 0.45, 1.05) end
end

local function revealTool(name, effect)
	for i, t in ipairs(Config.Tools) do
		if t.name == name then
			local rk, rl = K.rarityOf(i, #Config.Tools)
			reveal({ head = "NEW HAMMER!", name = t.name, icon = t.icon, color = t.color, rarity = { rl, K.RAR[rk] }, big = i >= 10,
				effect = effect or ("x" .. Config.FormatNum(t.power) .. " build power") })
			return true
		end
	end
end

local function revealStorm()
	local sh = Config.StormHammer
	if not sh then return end
	reveal({ head = "⚡ STORM UNLOCKED! ⚡", name = sh.name, icon = sh.icon, color = sh.color or Color3.fromRGB(80, 170, 255), rarity = { "ROBUX ADD-ON", Color3.fromRGB(80, 170, 255) },
		big = true, effect = "x" .. tostring(sh.mult or 3) .. " build power on top of your hammer — your crew too!", button = "LET'S GO!" })
end

---------------------------------------------------------------------------
-- wiring
---------------------------------------------------------------------------
Feedback.OnClientEvent:Connect(function(kind, d)
	if kind == "Hit" then
		if type(d) == "table" then burst(heldTool(player), d.pos, true) end
	elseif kind == "Purchased" and type(d) == "table" then
		if d.kind == "tool" then
			revealTool(d.name, d.effect)
		elseif d.kind == "pass" and Config.StormHammer and d.name == Config.StormHammer.name then
			revealStorm()
		end
	end
end)

HitFX.OnClientEvent:Connect(function(uid, verb, pos)
	-- other players' hits (crew batches are skipped: their hammers are the crew's, not a hero's)
	if verb == "batch" or verb == "celebrate" or verb == "arrive" or verb == "boost" or uid == player.UserId or typeof(pos) ~= "Vector3" then return end
	local plr = Players:GetPlayerByUserId(uid)
	if plr then burst(heldTool(plr), pos, false) end
end)

-- for testing in Studio: _G.__HammerReveal("Galaxy Hammer") / _G.__HammerReveal("storm")
if RunService:IsStudio() then
	_G.__HammerReveal = function(name)
		if name == "storm" then revealStorm() else revealTool(name) end
	end
end
