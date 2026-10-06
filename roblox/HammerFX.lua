-- BlockRise Empire - hammer effects (client, StarterPlayerScripts.HammerFX)
--  * the hammers in the world come alive, each its own way: the Galaxy drifts through space with rings of stars,
--    the Solar has fire orbs, the Plasma orbs with arcs, the Diamond shards, the Thunderclap crackles with lightning
--  * hits burst in the hammer's colours, and with the epic+ hammers something happens around the building:
--    crystals, lava columns, frost, diamond showers, plasma chains, sunbeams, meteors, lightning strikes
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
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"
local NSK = NumberSequenceKeypoint.new

local function sound(id, vol, pitch)
	if not id then return end
	local s = new("Sound", { SoundId = id, Volume = vol or 0.5, PlaybackSpeed = pitch or 1, Parent = SoundService })
	s:Play()
	Debris:AddItem(s, 6)
end

---------------------------------------------------------------------------
-- helpers: client-only effect parts, ground under a point, lightning
---------------------------------------------------------------------------
local fxFolder = new("Folder", { Name = "_HammerFX", Parent = workspace }) -- made on this client only: nobody else sees it, nothing saves it
local THUNDER_SFX = "rbxassetid://9126082854" -- Pro Sound Effects: synth thunder crack
local ZAP_SFX = "rbxassetid://9116279560"     -- Pro Sound Effects: quick electrical burst

local function fxPart(props)
	local p = Instance.new("Part")
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
	p.Material = Enum.Material.Neon
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	for k, v in pairs(props) do p[k] = v end
	p.Parent = props.Parent or fxFolder
	return p
end

local soundAt = {}
local function sound3D(id, pos, vol, pitch, gap)
	-- the same sound never stacks up faster than `gap` seconds
	if gap and soundAt[id] and os.clock() - soundAt[id] < gap then return end
	soundAt[id] = os.clock()
	local a = new("Attachment", { WorldPosition = pos, Parent = workspace.Terrain })
	local s = new("Sound", { SoundId = id, Volume = vol or 0.5, PlaybackSpeed = pitch or 1, RollOffMinDistance = 20, RollOffMaxDistance = 220, Parent = a })
	s:Play()
	Debris:AddItem(a, 8)
end

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
local function groundAt(p)
	local skip = { fxFolder }
	for _, pl in ipairs(Players:GetPlayers()) do if pl.Character then table.insert(skip, pl.Character) end end
	rayParams.FilterDescendantsInstances = skip
	local hit = workspace:Raycast(p + Vector3.new(0, 30, 0), Vector3.new(0, -70, 0), rayParams)
	return hit and hit.Position or p
end
local function around(pos, r0, r1)
	local a, d = math.random() * math.pi * 2, r0 + math.random() * (r1 - r0)
	return groundAt(Vector3.new(pos.X + math.cos(a) * d, pos.Y, pos.Z + math.sin(a) * d))
end

local function lightFlash(pos, color, brightness, range, t)
	-- kept soft: on the light roads a strong light burns the ground white (and everyone sees it)
	local a = new("Attachment", { WorldPosition = pos, Parent = workspace.Terrain })
	local l = new("PointLight", { Color = color, Brightness = math.min(brightness * 0.35, 2.2), Range = math.min(range * 0.55, 16), Shadows = false, Parent = a })
	UI.tween(l, t or 0.3, { Brightness = 0 })
	Debris:AddItem(a, (t or 0.3) + 0.05)
end

-- one jagged line of electricity from a to b: a coloured glow with a white-hot core, a fork now and then
local function zap(a, b, o)
	o = o or {}
	local n = o.n or math.clamp(math.floor((b - a).Magnitude / 3) + 3, 3, 9)
	local amp = o.amp or (b - a).Magnitude * 0.12
	local dir = (b - a)
	if dir.Magnitude < 0.01 then return end
	local u = dir.Unit
	local r1 = u:Cross(math.abs(u.Y) > 0.9 and Vector3.xAxis or Vector3.yAxis).Unit
	local r2 = u:Cross(r1).Unit
	local pts = { a }
	for i = 1, n - 1 do
		local t = i / n
		local k = amp * math.sin(math.pi * t)
		table.insert(pts, a:Lerp(b, t) + r1 * (math.random() * 2 - 1) * k + r2 * (math.random() * 2 - 1) * k)
	end
	table.insert(pts, b)
	local w, life = o.w or 0.35, o.life or 0.25
	local color = o.color or Color3.fromRGB(110, 180, 255)
	local function seg(p0, p1, width, col, trans)
		local len = (p1 - p0).Magnitude
		local p = fxPart({ Color = col, Transparency = trans, Size = Vector3.new(width, width, len), CFrame = CFrame.lookAt((p0 + p1) / 2, p1) })
		UI.tween(p, life, { Transparency = 1, Size = Vector3.new(width * 0.25, width * 0.25, len) })
		Debris:AddItem(p, life + 0.05)
	end
	for i = 1, #pts - 1 do
		seg(pts[i], pts[i + 1], w, color, o.glow or 0.35)
		if o.core ~= false then seg(pts[i], pts[i + 1], w * 0.36, Color3.fromRGB(245, 250, 255), 0) end
		if o.forks and i > 1 and i < #pts - 1 and math.random() < o.forks then
			local f = pts[i] + (r1 * (math.random() * 2 - 1) + r2 * (math.random() * 2 - 1) + u * 0.6) * amp * 1.6
			seg(pts[i], f, w * 0.4, color:Lerp(Color3.new(1, 1, 1), 0.4), 0.1)
		end
	end
end

-- a bolt from the sky (or from a storm cloud) onto a point
local function strike(pos, big, from)
	local top = from or (pos + Vector3.new((math.random() - 0.5) * 10, big and 40 or 30, (math.random() - 0.5) * 10))
	zap(top, pos, { n = big and 9 or 7, amp = big and 3.2 or 2.4, w = big and 0.6 or 0.42, forks = 0.4, life = big and 0.32 or 0.24 })
	lightFlash(pos + Vector3.new(0, 3, 0), Color3.fromRGB(170, 210, 255), big and 6 or 3.5, big and 34 or 24)
end

-- particle emitters for bursts (one set, moved to where they are needed)
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
	column = emitter("Column", FIRE, { Lifetime = NumberRange.new(0.5, 0.9), Speed = NumberRange.new(12, 20), Drag = 2, SpreadAngle = Vector2.new(12, 12),
		Acceleration = Vector3.new(0, 4, 0), EmissionDirection = Enum.NormalId.Top, Size = NumberSequence.new({ NSK(0, 1.6), NSK(1, 0.2) }),
		Transparency = NumberSequence.new(0.05, 1), Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-90, 90) }),
	mist = emitter("Mist", SMOKE, { Lifetime = NumberRange.new(0.8, 1.3), Speed = NumberRange.new(3, 6), Drag = 3, SpreadAngle = Vector2.new(90, 10),
		Size = NumberSequence.new({ NSK(0, 1.5), NSK(1, 3.5) }), Transparency = NumberSequence.new(0.45, 1), LightEmission = 0.4, Rotation = NumberRange.new(0, 360) }),
	bloom = emitter("Bloom", SPARK, { Lifetime = NumberRange.new(0.22, 0.22), Speed = NumberRange.new(0, 0),
		Size = NumberSequence.new({ NSK(0, 1), NSK(1, 7) }), Transparency = NumberSequence.new({ NSK(0, 0.25), NSK(1, 1) }) }),
	-- the epic shadow trailing the head (dark smoke), and its glowing version (frost, mythic)
	shade = emitter("Shade", SMOKE, { Lifetime = NumberRange.new(0.5, 0.8), Speed = NumberRange.new(0.2, 0.6), Drag = 2, LightEmission = 0,
		Size = NumberSequence.new({ NSK(0, 0.55), NSK(1, 1.3) }), Transparency = NumberSequence.new({ NSK(0, 0.5), NSK(1, 1) }), Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-40, 40) }),
	aura = emitter("Aura", SMOKE, { Lifetime = NumberRange.new(0.45, 0.75), Speed = NumberRange.new(0.2, 0.6), Drag = 2, LightEmission = 0.8,
		Size = NumberSequence.new({ NSK(0, 0.5), NSK(1, 1.2) }), Transparency = NumberSequence.new({ NSK(0, 0.55), NSK(1, 1) }), Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-40, 40) }),
	scorch = emitter("Scorch", SMOKE, { Lifetime = NumberRange.new(1.2, 1.8), Speed = NumberRange.new(1, 3), Drag = 1.5, LightEmission = 0, SpreadAngle = Vector2.new(60, 60),
		EmissionDirection = Enum.NormalId.Top, Acceleration = Vector3.new(0, 2, 0), Size = NumberSequence.new({ NSK(0, 1.2), NSK(1, 3.2) }),
		Transparency = NumberSequence.new({ NSK(0, 0.35), NSK(1, 1) }), Rotation = NumberRange.new(0, 360) }),
}
local function seq(a, b) return ColorSequence.new(a, b or a) end
local function emitAt(pos, kind, color, n)
	fxRoot.WorldPosition = pos
	local pe = PE[kind]
	pe.Color = typeof(color) == "ColorSequence" and color or seq(color)
	pe:Emit(n)
end

-- little things thrown through the air (diamond shards, meteors): one loop moves them all
local flying = {}
RunService.Heartbeat:Connect(function()
	local now = os.clock()
	for i = #flying, 1, -1 do
		local f = flying[i]
		local t = now - f.t0
		if t >= f.life or not f.part.Parent then
			table.remove(flying, i)
			if f.land then f.land(f.part.Position) end
			if f.part.Parent then f.part:Destroy() end
		else
			local p = f.p0 + f.v * t + Vector3.new(0, -0.5 * (f.g or 0) * t * t, 0)
			f.part.CFrame = CFrame.new(p) * CFrame.Angles(t * (f.spin or 0), t * (f.spin or 0) * 1.3, 0)
		end
	end
end)
local function throw(part, p0, p1, life, arc, land, spin)
	-- reach p1 after `life` seconds, `arc` studs over the straight line at the top
	local g = arc > 0 and 8 * arc / (life * life) or 0
	local v = (p1 - p0) / life + Vector3.new(0, 0.5 * g * life, 0)
	table.insert(flying, { part = part, p0 = p0, v = v, g = g, t0 = os.clock(), life = life, land = land, spin = spin })
end

---------------------------------------------------------------------------
-- 1. hammers in the world: every top hammer has its own life
--    galaxy drift + star rings, solar fire orbs, plasma orbs with arcs, diamond shards, Thunderclap crackling arcs
---------------------------------------------------------------------------
local C3 = Color3.fromRGB
-- the ladder: every rarity a step up, so the next hammer always looks like more
--   RARE: a few tiny sparkles   EPIC: a soft shadow trailing the head (+ sparkles)   LEGENDARY: things orbiting the head
--   MYTHIC: orbiters + an afterimage trailing you when you run + more   THUNDERCLAP: a storm of its own (cloud + rain over you, arcs)
local AURA = {
	emerald = { glints = { every = { 0.35, 0.75 }, color = C3(150, 255, 190) } },
	ruby = { glints = { every = { 0.35, 0.75 }, color = C3(255, 150, 170) } },
	sapphire = { glints = { every = { 0.3, 0.7 }, color = C3(150, 190, 255) } },
	amethyst = { shade = { every = { 0.06, 0.1 }, color = C3(80, 35, 140) }, glints = { every = { 0.45, 0.9 }, color = C3(215, 165, 255) } },
	lava = { shade = { every = { 0.06, 0.1 }, color = C3(50, 20, 12) }, glints = { every = { 0.35, 0.7 }, color = C3(255, 150, 50) } },
	frost = { shade = { every = { 0.06, 0.1 }, color = C3(200, 230, 255), glow = true }, glints = { every = { 0.4, 0.8 }, color = C3(235, 250, 255) } },
	-- (little sparks of light with a trail, circling the head: solid gems looked like glitchy white squares)
	diamond = { rings = { { count = 3, shape = "ball", size = 0.14, colors = { C3(245, 252, 255), C3(180, 235, 255), C3(255, 215, 250) }, speed = 1.8, tilt = 0.35, r = 1.1,
		trail = { C3(190, 235, 255), 0.35 } },
		{ count = 2, shape = "ball", size = 0.1, colors = { C3(255, 255, 255) }, speed = -2.4, tilt = -0.6, r = 1.3, trail = { C3(255, 215, 250), 0.25 } } },
		twinkle = { every = { 0.3, 0.6 } } },
	plasma = { rings = { { count = 2, shape = "ball", size = 0.22, colors = { C3(150, 245, 255) }, speed = 3.4, tilt = 0.5, r = 1.0, trail = { C3(80, 220, 255), 0.22 } },
		{ count = 2, shape = "ball", size = 0.16, colors = { C3(200, 255, 255) }, speed = -2.6, tilt = -0.7, r = 1.25, trail = { C3(120, 200, 255), 0.18 } } },
		arcs = { every = { 0.25, 0.55 }, color = C3(90, 220, 255), toOrbs = true } },
	solar = { rings = { { count = 3, shape = "ball", size = 0.28, colors = { C3(255, 230, 120), C3(255, 160, 40), C3(255, 110, 30) }, speed = 1.2, tilt = 0.25, r = 1.15, trail = { C3(255, 150, 30), 0.4 } },
		{ count = 2, shape = "ball", size = 0.18, colors = { C3(255, 245, 190) }, speed = -2, tilt = -0.8, r = 1.45, trail = { C3(255, 200, 80), 0.3 } } },
		flare = { every = { 0.5, 1.0 } }, shade = { every = { 0.05, 0.09 }, color = C3(255, 150, 40), glow = true },
		ghost = { colors = { C3(255, 200, 80), C3(255, 120, 30) } } },
	galaxy = { rings = { { count = 8, shape = "ball", size = 0.16, colors = { C3(255, 255, 255), C3(255, 170, 240), C3(150, 190, 255) }, speed = 0.9, tilt = 0.45, r = 1.4, trail = { C3(190, 140, 255), 0.4 } },
		{ count = 5, shape = "ball", size = 0.12, colors = { C3(255, 255, 255), C3(170, 220, 255) }, speed = -1.3, tilt = -0.9, r = 1.15, trail = { C3(140, 190, 255), 0.25 } } },
		shade = { every = { 0.05, 0.09 }, color = C3(150, 90, 255), glow = true },
		ghost = { colors = { C3(170, 110, 255), C3(110, 160, 255), C3(255, 150, 235) } },
		shooting = { every = { 1.4, 2.8 } } },
	thunder = { arcs = { every = { 0.05, 0.16 }, color = C3(120, 190, 255) }, cloud = true, bodyArcs = { every = { 0.15, 0.35 } }, groundArcs = { every = { 0.5, 1.1 } },
		cloudBolt = { every = { 1.4, 2.8 } }, shade = { every = { 0.05, 0.08 }, color = C3(110, 170, 255), glow = true },
		ghost = { colors = { C3(110, 180, 255), C3(200, 235, 255) } } },
}

-- hammers without a look of their own get one by rarity (Tool attribute Rarity = 1..8)
local RARITY_AURA = {
	[3] = { glints = { every = { 0.45, 0.9 }, color = C3(170, 210, 255) } },
	[4] = { shade = { every = { 0.07, 0.11 }, color = C3(110, 60, 190) }, glints = { every = { 0.4, 0.8 }, color = C3(215, 170, 255) } },
	[5] = { shade = { every = { 0.06, 0.1 }, color = C3(255, 170, 40), glow = true }, glints = { every = { 0.35, 0.7 }, color = C3(255, 220, 120) } },
	[6] = { rings = { { count = 3, shape = "ball", size = 0.16, colors = { C3(255, 120, 160), C3(255, 220, 240) }, speed = 1.8, tilt = 0.4, r = 1.15, trail = { C3(255, 90, 140), 0.3 } } },
		ghost = { colors = { C3(255, 90, 150), C3(255, 170, 205) } } },
	[7] = { rings = { { count = 4, shape = "ball", size = 0.18, colors = { C3(200, 200, 255), C3(90, 90, 140) }, speed = 1.4, tilt = 0.5, r = 1.25, trail = { C3(160, 150, 255), 0.35 } } },
		shade = { every = { 0.05, 0.09 }, color = C3(40, 40, 70) }, ghost = { colors = { C3(30, 28, 52), C3(90, 76, 170) }, dark = true } },
	[8] = { rings = { { count = 6, shape = "ball", size = 0.16, colors = { C3(255, 245, 200), C3(255, 220, 120) }, speed = 1.0, tilt = 0.45, r = 1.4, trail = { C3(255, 230, 150), 0.4 } } },
		shade = { every = { 0.05, 0.09 }, color = C3(255, 230, 150), glow = true }, ghost = { colors = { C3(255, 236, 190), C3(255, 190, 245), C3(185, 228, 255) } },
		shooting = { every = { 1.6, 3 } } },
}

local live = {} -- tool -> state

local function trailOn(p, size, color, life)
	local a0 = new("Attachment", { Position = Vector3.new(0, size * 0.5, 0), Parent = p })
	local a1 = new("Attachment", { Position = Vector3.new(0, -size * 0.5, 0), Parent = p })
	-- the trail starts once the part is where it belongs (no streak from where it was made)
	local tr = new("Trail", { Attachment0 = a0, Attachment1 = a1, Color = seq(color), Lifetime = life, LightEmission = 1, LightInfluence = 0, FaceCamera = true, Enabled = false,
		MinLength = 0.02, WidthScale = NumberSequence.new(1, 0), Transparency = NumberSequence.new(0.1, 1), Parent = p })
	task.delay(0.08, function() if tr.Parent then tr:Clear(); tr.Enabled = true end end)
end

local function makeOrbs(e, aura)
	e.orbs = {}
	for _, rd in ipairs(aura.rings or {}) do
		for i = 1, rd.count do
			local p = fxPart({ Name = "Orb", Shape = rd.shape == "ball" and Enum.PartType.Ball or Enum.PartType.Block, Size = Vector3.one * rd.size,
				Color = rd.colors[(i - 1) % #rd.colors + 1], Transparency = rd.trans or 0, CFrame = CFrame.new(e.head.Position) })
			if rd.shape == "gem" then new("PointLight", { Color = p.Color, Brightness = 0.6, Range = 3, Shadows = false, Parent = p }) end
			if rd.trail then trailOn(p, rd.size, rd.trail[1], rd.trail[2]) end
			table.insert(e.orbs, { part = p, rd = rd, phase = (i - 1) / rd.count * math.pi * 2 })
		end
	end
end

-- a ring of light turning on the ground around you (mythic + Thunderclap)
local function makeFeet(e, f)
	e.feet = {}
	for i = 1, f.count do
		local p
		if f.kind == "flame" then
			p = fxPart({ Name = "Feet", Size = Vector3.new(0.22, 0.6, 0.22), Color = f.colors[(i - 1) % #f.colors + 1] })
		elseif f.kind == "spark" then
			p = fxPart({ Name = "Feet", Size = Vector3.new(0.12, 0.12, 0.5), Color = f.colors[(i - 1) % #f.colors + 1], CFrame = e.head.CFrame })
			trailOn(p, 0.12, C3(120, 190, 255), 0.2)
		else
			p = fxPart({ Name = "Feet", Shape = Enum.PartType.Ball, Size = Vector3.one * (0.22 + (i % 3) * 0.07), Color = f.colors[(i - 1) % #f.colors + 1] })
		end
		table.insert(e.feet, { part = p, phase = (i - 1) / f.count * math.pi * 2 })
	end
	if f.glow then
		e.feetGlow = fxPart({ Name = "FeetGlow", Shape = Enum.PartType.Cylinder, Color = f.glow, Transparency = 0.88, Size = Vector3.new(0.05, f.r * 2 + 0.6, f.r * 2 + 0.6) })
	end
end

-- an afterimage of the character that fades out behind you while you run (it took the place of the ring on the ground)
local function ghostOf(char, color, dark)
	for _, p in ipairs(char:GetChildren()) do
		if p:IsA("BasePart") and p.Name ~= "HumanoidRootPart" and p.Transparency < 0.9 then
			local ok, g = pcall(function() return p:Clone() end)
			if ok and g then
				for _, ch in ipairs(g:GetChildren()) do if not ch:IsA("DataModelMesh") then ch:Destroy() end end
				g.Anchored, g.CanCollide, g.CanQuery, g.CanTouch, g.CastShadow, g.Massless = true, false, false, false, false, true
				g.Material = dark and Enum.Material.SmoothPlastic or Enum.Material.Neon
				g.Color = color
				g.Transparency = dark and 0.35 or 0.5
				if g:IsA("MeshPart") then pcall(function() g.TextureID = "" end) end
				g.CFrame = p.CFrame
				g.Parent = fxFolder
				UI.tween(g, 0.42, { Transparency = 1 })
				Debris:AddItem(g, 0.45)
			end
		end
	end
end

-- the Thunderclap's own storm cloud: it follows you, and moves over the house while you build
-- a cartoon storm cloud (picture rendered in Blender): three layers facing the camera at different depths, so it looks
-- round from every side; grey-blue normally, lit white for a blink when lightning flashes inside
local CLOUD_IMG = "rbxassetid://84361525477052"
local CLOUD_TINT = C3(134, 142, 176)
local CLOUD_LIT = C3(240, 246, 255)
local function makeCloud(e)
	local core = fxPart({ Name = "Cloud", Transparency = 1, Size = Vector3.new(1, 1, 1) })
	local c = { parts = { { part = core } }, pos = nil, core = core, puffs = {} }
	-- { offset, size (studs), darker }
	local layers = { { Vector3.new(-2.2, -0.3, -0.6), 6.8, 0.16 }, { Vector3.new(2.4, -0.2, -0.5), 7.5, 0.12 }, { Vector3.new(0, 0.2, 0.3), 9.8, 0 } }
	for _, L in ipairs(layers) do
		local bb = new("BillboardGui", { Name = "CloudLayer", Size = UDim2.fromScale(L[2], L[2]), StudsOffsetWorldSpace = L[1], LightInfluence = 0, MaxDistance = 160,
			ResetOnSpawn = false, Adornee = core, Parent = core })
		local tint = CLOUD_TINT:Lerp(Color3.new(0, 0, 0), L[3])
		local img = new("ImageLabel", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Image = CLOUD_IMG, ImageColor3 = tint, Parent = bb })
		table.insert(c.puffs, { img = img, tint = tint })
	end
	c.light = new("PointLight", { Color = C3(150, 200, 255), Brightness = 0, Range = 12, Shadows = false, Parent = core })
	-- rain: thin streaks falling from the cloud, recycled at the bottom
	c.rain = {}
	for i = 1, 20 do
		local d = fxPart({ Name = "Rain", Size = Vector3.new(0.06, 1.0, 0.06), Color = C3(170, 210, 255), Transparency = 0.35 })
		table.insert(c.parts, { part = d })
		table.insert(c.rain, { part = d, y = math.random() * 8, x = (math.random() - 0.5) * 6, z = (math.random() - 0.5) * 4, v = 30 + math.random() * 12 })
	end
	e.cloud = c
end
-- a flash inside the cloud: one layer (or all of them) lights up for a blink
local function cloudBlink(c, all)
	local pick = math.random(#c.puffs)
	for i, pf in ipairs(c.puffs) do
		if all or i == pick then
			pf.img.ImageColor3 = CLOUD_LIT
			task.delay(all and 0.12 or 0.08, function() if pf.img.Parent then pf.img.ImageColor3 = pf.tint end end)
		end
	end
end

local function dropOrbs(e)
	for _, o in ipairs(e.orbs or {}) do o.part:Destroy() end
	e.orbs = {}
	for _, o in ipairs(e.feet or {}) do o.part:Destroy() end
	e.feet = nil
	if e.feetGlow then e.feetGlow:Destroy() end
	e.feetGlow = nil
	if e.cloud then for _, c in ipairs(e.cloud.parts) do c.part:Destroy() end end
	e.cloud = nil
end

local track
function track(tool)
	if live[tool] then return end
	local key = tool:GetAttribute("Key")
	local thunder = Config.StormHammer and key == Config.StormHammer.key
	local e = { key = key, spaces = {}, neon = {}, emitters = {}, galaxy = key == "galaxy", thunder = thunder, nextFlash = os.clock() + 1,
		aura = AURA[key] or RARITY_AURA[tonumber(tool:GetAttribute("Rarity")) or 0], next = {} }
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
	-- the head: the effect box the builder put over it, or the biggest part
	e.head = tool:FindFirstChild("FXArea_1") or tool:FindFirstChild("Head")
	if not e.head then
		local best = 0
		for _, p in ipairs(tool:GetChildren()) do
			if p:IsA("BasePart") and p.Name ~= "Handle" and p.Name ~= "Shaft" and p.Size.Magnitude > best then e.head, best = p, p.Size.Magnitude end
		end
	end
	e.handle = tool:FindFirstChild("Handle")
	if (#e.spaces == 0 and not e.light and not e.aura) or not e.handle or not e.head then
		-- another player's hammer can arrive a moment before its parts: look again once
		if not tool:GetAttribute("FxRetry") then
			tool:SetAttribute("FxRetry", true)
			task.delay(1, function() if tool:IsDescendantOf(workspace) then track(tool) end end)
		end
		return
	end
	e.radius = math.max(0.9, math.max(e.head.Size.X, e.head.Size.Z) * 0.5 + 0.35)
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
		e.light.Brightness = e.base * 1.9
		task.delay(0.05, function() if e.light then e.light.Brightness = e.base * 0.6 end end)
		task.delay(0.1, function() if e.light then e.light.Brightness = e.base * 1.5 end end)
	end
	for _, n in ipairs(e.neon) do
		n.part.Color = n.color:Lerp(Color3.new(1, 1, 1), 0.7)
		task.delay(0.14, function() if n.part.Parent then n.part.Color = n.color end end)
	end
	for _, pe in ipairs(e.emitters) do pe:Emit(3) end
end

-- a random point on the head's box, and the way out of it
local function onHead(e)
	local s = e.head.Size * 0.5
	local lp = Vector3.new((math.random() * 2 - 1) * s.X, (math.random() * 2 - 1) * s.Y, (math.random() * 2 - 1) * s.Z)
	local ax = math.random(3)
	if ax == 1 then lp = Vector3.new(math.sign(lp.X) * s.X, lp.Y, lp.Z) elseif ax == 2 then lp = Vector3.new(lp.X, math.sign(lp.Y) * s.Y, lp.Z) else lp = Vector3.new(lp.X, lp.Y, math.sign(lp.Z) * s.Z) end
	local wp = e.head.CFrame:PointToWorldSpace(lp)
	return wp, (wp - e.head.Position).Unit
end

-- every timer of an aura: true when it is time again (and sets the next one)
local function due(e, name, every, now)
	local t = e.next[name]
	if t and now < t then return false end
	e.next[name] = now + every[1] + math.random() * (every[2] - every[1])
	return t ~= nil -- the first call only starts the clock
end

local lastStep = os.clock()
RunService.RenderStepped:Connect(function()
	local now = os.clock()
	local dt = math.min(now - lastStep, 0.1)
	lastStep = now
	local cam = camera.CFrame.Position
	for tool, e in pairs(live) do
		if not tool.Parent or not tool:IsDescendantOf(workspace) then
			live[tool] = nil
			dropOrbs(e)
		else
			local d = (e.handle.Position - cam).Magnitude
			local aura = e.aura
			local char = tool.Parent
			local root = char and char:FindFirstChild("HumanoidRootPart")
			local hum = char and char:FindFirstChildOfClass("Humanoid")
			-- the orbiters / feet ring / cloud live only near you (far away they are not worth the parts)
			if aura and d < 110 then
				if aura.rings then
					if not e.orbs or #e.orbs == 0 then makeOrbs(e, aura) end
					local base = CFrame.new(e.head.Position) * e.handle.CFrame.Rotation
					for _, o in ipairs(e.orbs) do
						local rd = o.rd
						local a = o.phase + now * rd.speed
						local r = e.radius * (rd.r or 1) * (1 + 0.06 * math.sin(now * 3 + o.phase))
						local p = (base * CFrame.Angles(rd.tilt or 0, 0, (rd.tilt or 0) * 0.5) * CFrame.Angles(0, a, 0) * CFrame.new(r, 0, 0)).Position
						o.part.CFrame = rd.shape == "gem" and (CFrame.new(p) * CFrame.Angles(now * (rd.spin or 1), now * (rd.spin or 1) * 1.3, math.pi / 4)) or CFrame.new(p)
					end
				end
				-- an afterimage trailing you while you run (not in a seat: no ghost cars)
				if aura.ghost and root and hum and not hum.Sit and due(e, "ghost", { 0.08, 0.1 }, now) then
					local v = root.AssemblyLinearVelocity
					if Vector3.new(v.X, 0, v.Z).Magnitude > 5 then
						local gc = aura.ghost.colors
						e.gi = (e.gi or 0) % #gc + 1
						ghostOf(char, gc[e.gi], aura.ghost.dark)
					end
				end
				if aura.cloud and root then
					if not e.cloud then makeCloud(e) end
					local c = e.cloud
					local building = e.site and now - e.site.t < 2.5
					-- a little over the name tags above your head (VIP, company)
					local target = building and (e.site.pos + Vector3.new(0, 14, 0)) or (root.Position + Vector3.new(0, 9, 0))
					c.pos = c.pos and c.pos:Lerp(target, math.clamp(dt * (building and 2 or 4), 0, 1)) or target
					c.core.CFrame = CFrame.new(c.pos + Vector3.new(math.sin(now * 0.7) * 0.3, math.sin(now * 0.9) * 0.2, 0)) * CFrame.Angles(0, now * 0.15, 0)
					-- light flickering inside the cloud
					if c.light.Brightness > 0 then c.light.Brightness = math.max(0, c.light.Brightness - dt * 12) end
					if due(e, "cloudFlick", { 0.5, 1.4 }, now) then
						c.light.Brightness = 0.5 + math.random() * 0.6
						cloudBlink(c)
					end
					-- the rain falls (8 studs) and starts again at the cloud
					for _, d in ipairs(c.rain) do
						d.y += d.v * dt
						if d.y > 8 then d.y = 0; d.x = (math.random() - 0.5) * 6; d.z = (math.random() - 0.5) * 4 end
						d.part.CFrame = CFrame.new(c.pos + Vector3.new(d.x, -1.4 - d.y, d.z))
						d.part.Transparency = 0.3 + 0.6 * (d.y / 8)
					end
				end
			elseif (e.orbs and #e.orbs > 0) or e.feet or e.cloud then
				dropOrbs(e)
			end
			if d < 150 then
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
						e.nextFlash = now + 0.5 + math.random() * 1.2
						flash(e)
					elseif e.light.Brightness < e.base * 2 then
						-- restless glow between the cracks
						e.light.Brightness = e.base * (0.75 + 0.35 * math.noise(now * 6, 0.5))
					end
				end
			end
			if aura and d < 90 then
				-- RARE+: tiny sparkles on the head
				if aura.glints and due(e, "glint", aura.glints.every, now) then
					emitAt(onHead(e), "glint", aura.glints.color, 1)
				end
				-- EPIC+: a soft shadow (or glow) trailing the head: it lingers behind every swing
				if aura.shade and due(e, "shade", aura.shade.every, now) then
					emitAt(e.head.Position + Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * 0.5, aura.shade.glow and "aura" or "shade", aura.shade.color, 1)
				end
				-- little arcs of electricity crawling off the head (Thunderclap), or jumping to the plasma orbs
				local arcs = aura.arcs
				if arcs and due(e, "arc", arcs.every, now) then
					if arcs.toOrbs and e.orbs and #e.orbs > 0 then
						local o = e.orbs[math.random(#e.orbs)]
						zap(e.head.Position, o.part.Position, { n = 4, amp = 0.25, w = 0.09, color = arcs.color, life = 0.1, glow = 0.2, core = false })
					else
						local p0, out = onHead(e)
						local p1 = p0 + (out + Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5)).Unit * (0.7 + math.random() * 1.1)
						zap(p0, p1, { n = 4, amp = 0.3, w = 0.11, color = arcs.color, life = 0.09, glow = 0.1, forks = 0.35, core = false })
					end
				end
				-- Thunderclap: arcs all over you, down to the ground, and bolts from your cloud into the hammer
				if aura.bodyArcs and char and due(e, "body", aura.bodyArcs.every, now) then
					local parts = {}
					for _, p in ipairs(char:GetChildren()) do if p:IsA("BasePart") and p.Name ~= "HumanoidRootPart" then table.insert(parts, p) end end
					if #parts >= 2 then
						local a, b = parts[math.random(#parts)], parts[math.random(#parts)]
						if a ~= b then zap(a.Position, b.Position, { n = 4, amp = 0.35, w = 0.08, color = C3(140, 200, 255), life = 0.08, glow = 0.1, core = false }) end
					end
				end
				if aura.groundArcs and root and due(e, "ground", aura.groundArcs.every, now) then
					local to = around(root.Position, 2, 5)
					zap(e.head.Position, to, { n = 6, amp = 0.6, w = 0.14, color = C3(120, 190, 255), life = 0.14, forks = 0.3 })
					emitAt(to, "sparks", seq(C3(220, 240, 255), C3(90, 170, 255)), 5)
				end
				if aura.cloudBolt and e.cloud and e.cloud.pos and not (e.site and now - e.site.t < 2.5) and due(e, "cloudBolt", aura.cloudBolt.every, now) then
					zap(e.cloud.pos - Vector3.new(0, 1.2, 0), e.head.Position, { n = 7, amp = 1.1, w = 0.3, forks = 0.35, life = 0.2 })
					lightFlash(e.head.Position, C3(170, 210, 255), 6, 20, 0.25)
					e.cloud.light.Brightness = 1.6
					cloudBlink(e.cloud, true)
					flash(e)
				end
				-- the diamond's gems twinkle
				if aura.twinkle and e.orbs and #e.orbs > 0 and due(e, "twinkle", aura.twinkle.every, now) then
					emitAt(e.orbs[math.random(#e.orbs)].part.Position, "glint", Color3.new(1, 1, 1), 2)
				end
				-- the solar hammer throws a little flare now and then
				if aura.flare and due(e, "flare", aura.flare.every, now) then
					emitAt(e.head.Position, "fire", seq(C3(255, 240, 150), C3(255, 120, 20)), 5)
				end
				-- the galaxy: a shooting star crosses the sky near you
				if aura.shooting and root and due(e, "shooting", aura.shooting.every, now) then
					local a = math.random() * math.pi * 2
					local dir = Vector3.new(math.cos(a), 0, math.sin(a))
					local from = root.Position + Vector3.new(0, 30 + math.random() * 10, 0) - dir * 28 + Vector3.new(-dir.Z, 0, dir.X) * (math.random() - 0.5) * 30
					local to = from + dir * 56 - Vector3.new(0, 5, 0)
					local s = fxPart({ Shape = Enum.PartType.Ball, Size = Vector3.one * 0.4, Color = C3(255, 255, 255), CFrame = CFrame.new(from) })
					trailOn(s, 0.4, C3(200, 160, 255), 0.5)
					throw(s, from, to, 1.1, 0, nil)
				end
			end
		end
	end
end)

---------------------------------------------------------------------------
-- 2. hits: a burst on the hit, and with the best hammers something happens around the building
---------------------------------------------------------------------------
-- what each hammer adds to a hit: { burst kind, colours, count, bloom? }
local BURST = {
	gold = { "glint", seq(C3(255, 225, 120), C3(255, 180, 40)), 5 },
	titanium = { "sparks", seq(C3(255, 200, 120), C3(255, 120, 40)), 7 },
	emerald = { "glint", seq(C3(120, 255, 170), C3(20, 200, 110)), 7 },
	ruby = { "glint", seq(C3(255, 120, 150), C3(230, 30, 70)), 8 },
	sapphire = { "glint", seq(C3(130, 180, 255), C3(40, 100, 255)), 9 },
	amethyst = { "glint", seq(C3(220, 170, 255), C3(150, 70, 255)), 10 },
	lava = { "fire", seq(C3(255, 200, 80), C3(255, 70, 10)), 10, C3(255, 120, 30) },
	frost = { "glint", seq(C3(230, 250, 255), C3(120, 215, 255)), 12, C3(160, 230, 255) },
	diamond = { "glint", ColorSequence.new({ ColorSequenceKeypoint.new(0, C3(255, 255, 255)), ColorSequenceKeypoint.new(0.5, C3(170, 235, 255)),
		ColorSequenceKeypoint.new(1, C3(255, 200, 250)) }), 14, C3(210, 245, 255) },
	plasma = { "sparks", seq(C3(180, 250, 255), C3(40, 200, 255)), 16, C3(80, 220, 255) },
	solar = { "fire", seq(C3(255, 240, 150), C3(255, 140, 20)), 14, C3(255, 190, 60) },
	galaxy = { "glint", ColorSequence.new({ ColorSequenceKeypoint.new(0, C3(255, 150, 240)), ColorSequenceKeypoint.new(0.5, C3(160, 110, 255)),
		ColorSequenceKeypoint.new(1, C3(90, 180, 255)) }), 18, C3(170, 120, 255) },
	thunder = { "sparks", seq(C3(230, 245, 255), C3(90, 170, 255)), 18, C3(140, 200, 255) },
}
-- hits of hammers without their own burst: by rarity (Tool attribute Rarity)
local RARITY_BURST = {
	[2] = { "glint", seq(C3(200, 255, 200), C3(80, 200, 100)), 5 },
	[3] = { "glint", seq(C3(190, 220, 255), C3(60, 150, 255)), 8 },
	[4] = { "glint", seq(C3(225, 180, 255), C3(165, 90, 255)), 10 },
	[5] = { "fire", seq(C3(255, 230, 140), C3(255, 150, 30)), 12, C3(255, 180, 60) },
	[6] = { "sparks", seq(C3(255, 200, 220), C3(255, 70, 120)), 14, C3(255, 110, 150) },
	[7] = { "glint", seq(C3(230, 230, 255), C3(80, 70, 160)), 16, C3(150, 140, 255) },
	[8] = { "glint", seq(C3(255, 255, 255), C3(255, 220, 120)), 18, C3(255, 235, 160) },
}

-- crystals that shoot out of the ground and shatter (amethyst / frost / diamond)
local function crystals(pos, n, colors, mat, h0, h1)
	for _ = 1, n do
		local at = around(pos, 3, 10)
		local h = h0 + math.random() * (h1 - h0)
		local w = 0.35 + math.random() * 0.35
		local tilt = CFrame.Angles((math.random() - 0.5) * 0.6, math.random() * math.pi * 2, (math.random() - 0.5) * 0.6)
		local col = colors[math.random(#colors)]
		local p = fxPart({ Material = mat, Color = col, Transparency = 0.15, Reflectance = mat == Enum.Material.Glass and 0.25 or 0,
			Size = Vector3.new(w, 0.1, w), CFrame = CFrame.new(at) * tilt })
		UI.tween(p, 0.22, { Size = Vector3.new(w, h, w), CFrame = CFrame.new(at) * tilt * CFrame.new(0, h / 2, 0) }, Enum.EasingStyle.Back)
		task.delay(0.55 + math.random() * 0.2, function()
			if not p.Parent then return end
			emitAt(p.Position, "glint", col, 6)
			UI.tween(p, 0.2, { Size = Vector3.new(w * 0.2, h * 0.3, w * 0.2), Transparency = 1 })
			Debris:AddItem(p, 0.25)
		end)
	end
end

-- a pulse along the ground (the plasma EMP, the galaxy star ring)
local function ring(pos, color, size)
	local p = fxPart({ Shape = Enum.PartType.Cylinder, Color = color, Transparency = 0.45, Size = Vector3.new(0.12, 1, 1),
		CFrame = CFrame.new(pos + Vector3.new(0, 0.15, 0)) * CFrame.Angles(0, 0, math.pi / 2) })
	UI.tween(p, 0.45, { Size = Vector3.new(0.05, size, size), Transparency = 1 }, Enum.EasingStyle.Quad)
	Debris:AddItem(p, 0.5)
end

-- the screen lights up and shakes a little for the biggest hits (yours only)
local flashGui = new("ScreenGui", { Name = "HammerFlash", IgnoreGuiInset = true, ResetOnSpawn = false, DisplayOrder = 5, Parent = player:WaitForChild("PlayerGui") })
local flashFrame = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 1, BorderSizePixel = 0, Parent = flashGui })
local function screenFlash(color, alpha)
	flashFrame.BackgroundColor3 = color
	flashFrame.BackgroundTransparency = alpha
	UI.tween(flashFrame, 0.22, { BackgroundTransparency = 1 })
end
local shakeAmt = 0
RunService:BindToRenderStep("HammerFXShake", Enum.RenderPriority.Camera.Value + 2, function(dt)
	if shakeAmt > 0.002 then
		camera.CFrame = camera.CFrame * CFrame.new((math.random() - 0.5) * shakeAmt, (math.random() - 0.5) * shakeAmt, 0)
		shakeAmt *= math.exp(-dt * 12)
	end
end)

-- a scorch where the lightning hit: smoke rising from the ground
local function scorch(at)
	emitAt(at + Vector3.new(0, 0.3, 0), "scorch", C3(40, 42, 50), 4)
	emitAt(at + Vector3.new(0, 0.3, 0), "sparks", seq(C3(255, 230, 160), C3(255, 140, 40)), 6)
end

-- a meteor from the sky onto a point, bursting into stars (the galaxy)
local function meteor(at, mine, size)
	size = size or 0.7
	local from = at + Vector3.new((math.random() - 0.5) * 30, 38, (math.random() - 0.5) * 30)
	local m = fxPart({ Shape = Enum.PartType.Ball, Color = C3(235, 220, 255), Size = Vector3.one * size, CFrame = CFrame.new(from) })
	local a0 = new("Attachment", { Position = Vector3.new(0, size / 2, 0), Parent = m })
	local a1 = new("Attachment", { Position = Vector3.new(0, -size / 2, 0), Parent = m })
	new("Trail", { Attachment0 = a0, Attachment1 = a1, Lifetime = 0.35, LightEmission = 1, LightInfluence = 0, FaceCamera = true, WidthScale = NumberSequence.new(1, 0),
		Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, C3(255, 255, 255)), ColorSequenceKeypoint.new(0.5, C3(200, 130, 255)), ColorSequenceKeypoint.new(1, C3(90, 160, 255)) }),
		Transparency = NumberSequence.new(0, 1), Parent = m })
	throw(m, from, at, 0.45, 0, function(hit)
		emitAt(hit, "glint", BURST.galaxy[2], 14)
		emitAt(hit, "bloom", C3(200, 150, 255), 1)
		ring(hit, C3(190, 140, 255), 9 * size / 0.7)
		if mine then lightFlash(hit + Vector3.new(0, 2, 0), C3(190, 140, 255), 6, 24, 0.4) end
	end)
end

-- the sunbeam (solar)
local function sunbeam(at, mine, w)
	w = w or 2.4
	local beam = fxPart({ Shape = Enum.PartType.Cylinder, Color = C3(255, 220, 120), Transparency = 0.35, Size = Vector3.new(60, w, w),
		CFrame = CFrame.new(at + Vector3.new(0, 30, 0)) * CFrame.Angles(0, 0, math.pi / 2) })
	UI.tween(beam, 0.5, { Size = Vector3.new(60, 0.2, 0.2), Transparency = 1 }, Enum.EasingStyle.Quad)
	Debris:AddItem(beam, 0.55)
	emitAt(at, "column", seq(C3(255, 240, 150), C3(255, 110, 20)), 12)
	emitAt(at + Vector3.new(0, 0.5, 0), "bloom", C3(255, 210, 90), 1)
	if mine then lightFlash(at + Vector3.new(0, 3, 0), C3(255, 200, 90), 8, 30, 0.45) end
end

-- what happens around the building with each hammer: { function(hit position, mine, hammer state), seconds between }
-- EPIC: light (one crystal / one lava column / a little frost)   LEGENDARY: a show   MYTHIC: a show + a big moment every few seconds
local SITE = {
	amethyst = { function(pos) crystals(pos, 1, { C3(190, 120, 255), C3(150, 70, 255) }, Enum.Material.Glass, 1.4, 2.6) end, 1.2 },
	lava = { function(pos, mine)
		local at = around(pos, 3, 10)
		emitAt(at, "column", seq(C3(255, 220, 110), C3(255, 70, 10)), 8)
		emitAt(at, "fire", seq(C3(255, 200, 80), C3(255, 70, 10)), 5)
		if mine then lightFlash(at + Vector3.new(0, 2, 0), C3(255, 120, 30), 4, 16, 0.45) end
	end, 1.1 },
	frost = { function(pos)
		local at = around(pos, 2, 8)
		emitAt(at, "mist", C3(220, 245, 255), 6)
		crystals(at, 1, { C3(220, 245, 255), C3(150, 220, 255) }, Enum.Material.Glass, 1.1, 2.2)
	end, 1.2 },
	diamond = { function(pos, mine)
		-- a shower of diamond shards that fly up and land around the house, twinkling
		for _ = 1, mine and 6 or 3 do
			local sz = math.random() * 0.15 + 0.2
			local p = fxPart({ Material = Enum.Material.Glass, Reflectance = 0.35, Color = ({ C3(235, 250, 255), C3(170, 235, 255), C3(255, 210, 250) })[math.random(3)],
				Size = Vector3.new(sz, sz, sz), CFrame = CFrame.new(pos) })
			throw(p, pos + Vector3.new(0, 1, 0), around(pos, 3, 9) + Vector3.new(0, sz / 2, 0), 0.55 + math.random() * 0.2, 4 + math.random() * 3, function(at)
				emitAt(at, "glint", seq(C3(255, 255, 255), C3(170, 235, 255)), 4)
			end, 9)
		end
	end, 0.8 },
	plasma = { function(pos, mine)
		-- the hit jumps to 2-3 points around the building, the ground pulses
		local from = pos + Vector3.new(0, 1, 0)
		for _ = 1, mine and 3 or 2 do
			local to = around(pos, 3, 8) + Vector3.new(0, 0.3, 0)
			zap(from, to, { w = 0.22, amp = 0.9, color = C3(90, 220, 255), life = 0.2, forks = 0.25 })
			emitAt(to, "sparks", seq(C3(200, 250, 255), C3(40, 200, 255)), 6)
			from = to
		end
		ring(groundAt(pos), C3(90, 220, 255), 16)
		if mine then sound3D(ZAP_SFX, pos, 0.35, 1.1 + math.random() * 0.2, 0.3) end
	end, 0.7 },
	solar = { function(pos, mine, e)
		sunbeam(around(pos, 2, 9), mine)
		-- every few seconds: a solar flare, a ring of fire running out over the ground and four sunbeams around the house
		if e and os.clock() - (e.bigT or 0) > 4 then
			e.bigT = os.clock()
			local g = groundAt(pos)
			ring(g, C3(255, 170, 50), 30)
			task.delay(0.12, function() ring(g, C3(255, 230, 140), 22) end)
			for i = 1, 4 do
				local a = i / 4 * math.pi * 2 + math.random() * 0.4
				task.delay(i * 0.1, function() sunbeam(groundAt(g + Vector3.new(math.cos(a) * 8, 0, math.sin(a) * 8)), mine, 1.6) end)
			end
			if mine then screenFlash(C3(255, 200, 100), 0.82); shakeAmt = math.max(shakeAmt, 0.25) end
		end
	end, 0.9 },
	galaxy = { function(pos, mine, e)
		meteor(around(pos, 3, 10), mine)
		-- every few seconds: a meteor shower over the house
		if e and os.clock() - (e.bigT or 0) > 4 then
			e.bigT = os.clock()
			for i = 1, 6 do
				task.delay(i * 0.14, function() meteor(around(pos, 2, 12), mine, 0.45 + math.random() * 0.4) end)
			end
			task.delay(0.9, function()
				ring(groundAt(pos), C3(200, 150, 255), 26)
				if mine then screenFlash(C3(190, 150, 255), 0.85) end
			end)
		end
	end, 0.8 },
	thunder = { function(pos, mine, e)
		-- the storm cloud over the house strikes around it, and the hit crackles across the building
		local cloud = e and e.cloud and e.cloud.pos
		local at = around(pos, 3, 12)
		strike(at, false, cloud and (cloud + Vector3.new((math.random() - 0.5) * 4, -1.5, (math.random() - 0.5) * 3)))
		scorch(at)
		local from = pos + Vector3.new(0, 1, 0)
		for _ = 1, 3 do
			local to = around(pos, 2, 7) + Vector3.new(0, 0.4, 0)
			zap(from, to, { w = 0.2, amp = 0.8, life = 0.18, forks = 0.3 })
			from = to
		end
		if mine then sound3D(ZAP_SFX, pos, 0.3, 0.9 + math.random() * 0.2, 0.3) end
	end, 0.45 },
}

local hits, lastSite = 0, {}
local function burst(tool, pos, mine, who)
	if not tool or typeof(pos) ~= "Vector3" then return end
	if (pos - camera.CFrame.Position).Magnitude > 160 then return end
	local key = tool:GetAttribute("Key")
	local e = live[tool]
	if e then e.site = { pos = pos, t = os.clock() } end
	local b = BURST[key] or RARITY_BURST[tonumber(tool:GetAttribute("Rarity")) or 0]
	if b then
		emitAt(pos + Vector3.new(0, 0.6, 0), b[1], b[2], mine and b[3] or math.ceil(b[3] / 2))
		if b[4] then
			emitAt(pos + Vector3.new(0, 0.6, 0), "bloom", b[4], 1)
			if mine then lightFlash(pos, b[4], 4, 16) end
		end
	end
	local site = SITE[key]
	if site then
		local k = (who or "me") .. key
		local cd = mine and site[2] or site[2] * 2
		if not lastSite[k] or os.clock() - lastSite[k] >= cd then
			lastSite[k] = os.clock()
			site[1](pos, mine, e)
		end
	end
	if Config.StormHammer and key == Config.StormHammer.key then
		hits += 1
		-- every third hit: the big one, from the cloud right onto the hit
		if hits % 3 == 0 or not mine then
			local cloud = e and e.cloud and e.cloud.pos
			strike(pos, true, cloud and (cloud - Vector3.new(0, 1.5, 0)))
			scorch(groundAt(pos))
			if e and e.cloud then e.cloud.light.Brightness = 2; cloudBlink(e.cloud, true) end
			sound3D(THUNDER_SFX, pos, mine and 0.45 or 0.3, 0.95 + math.random() * 0.15, 1.1)
			if mine then
				screenFlash(C3(200, 225, 255), 0.8)
				shakeAmt = math.max(shakeAmt, 0.35)
			end
		end
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
	if c.onClose then task.defer(c.onClose) end
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
	local c = { onClose = o.onClose }
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
		if o.rid and K.rarityChip then K.rarityChip(chip, o.rid) end
	end

	-- name, what it does, the button
	local name = UI.label({ Name = "Name", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromOffset(280, 330), Size = UDim2.fromOffset(540, 50), Text = string.upper(o.name),
		Font = T.chunky, TextSize = 46, TextXAlignment = Enum.TextXAlignment.Center, TextTransparency = 1, ZIndex = 6, Parent = box })
	new("UITextSizeConstraint", { MaxTextSize = 46, MinTextSize = 20, Parent = name })
	name.TextScaled = true
	local ns = new("UIStroke", { Thickness = 3.5, Color = T.ink, LineJoinMode = Enum.LineJoinMode.Round, Transparency = 1, Parent = name })
	new("UIGradient", { Color = ColorSequence.new(Color3.new(1, 1, 1), col:Lerp(Color3.new(1, 1, 1), 0.45)), Rotation = 90, Parent = name })
	if o.rid and K.rarityText and K.RARITY_LOOK[o.rid] then K.rarityText(name, o.rid) end
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
	-- the buttons look like every other button of the game (same font, the label in the middle of the face)
	local btn = UI.button(o.button or "AWESOME!", K.GREEN, nil, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromOffset(o.again and 162 or 280, 418),
		Size = UDim2.fromOffset(o.again and 210 or 250, o.crate and 54 or 62), TextSize = o.crate and 27 or 30, ZIndex = 7, Shine = not o.again, Parent = box })
	btn.Visible = false
	local again
	if o.again then
		-- open the next crate straight from the card
		again = UI.button(o.again.label, Color3.fromRGB(255, 176, 40), nil, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromOffset(394, 418), Size = UDim2.fromOffset(250, 62),
			TextSize = 23, ZIndex = 7, Shine = true, Parent = box })
		again.Visible = false
		again.Activated:Connect(function()
			sound(S.Click, 0.35)
			c.onClose = nil -- the next card follows, the Shop redraws after the last one
			closeCard(true)
			o.again.fn()
		end)
	end
	if o.tag then
		local tg = K.chip(box, o.tag, Color3.fromRGB(255, 176, 40), { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromOffset(280, 80), ZIndex = 6 })
		tg.ZIndex = 6
	end
	task.delay(0.75, function()
		if c.closing then return end
		-- anti autoclicker (crates): the KEEP goes under the row of OPEN buttons, in the middle, a little lower than
		-- usual, so it never touches the OPEN you pressed (nor the others of that row): a clicker left on one spot opens
		-- one crate and stops. The card is at its full size now.
		local av = o.avoid
		if av and not again and btn.AbsoluteSize.X > 0 then
			local k = btn.AbsoluteSize.Y / btn.Size.Y.Offset
			local p0, sz = btn.AbsolutePosition, btn.AbsoluteSize
			local m = 18 * k -- a small gap: their edges never touch, not even when one grows under the mouse
			local top, bottom = av[1].Y, av[1].Y + av[2].Y
			local overlapsY = p0.Y < bottom + m and p0.Y + sz.Y > top - m
			local overlapsX = p0.X < av[1].X + av[2].X + m and p0.X + sz.X > av[1].X - m
			if overlapsY and overlapsX then
				local screenBottom = gui.AbsolutePosition.Y + gui.AbsoluteSize.Y -- (this ScreenGui starts at y = -inset)
				local dy
				if bottom + m + sz.Y < screenBottom - 8 then
					dy = bottom + m - p0.Y -- under the OPEN row
				else
					dy = (top - m - sz.Y) - p0.Y -- (no room under it: above it)
				end
				btn.Position = UDim2.fromOffset(280, 418 + dy / k)
			end
		end
		-- the buttons pop in
		for _, b in ipairs({ btn, again }) do
			b.Visible = true
			local bs = b:FindFirstChildOfClass("UIScale") -- (the button's own: one UIScale per object)
			if bs then
				bs.Scale = 0.6
				UI.tween(bs, 0.3, { Scale = 1 }, Enum.EasingStyle.Back)
			end
		end
	end)
	btn.Activated:Connect(function() sound(S.Click, 0.35); closeCard() end)
	-- (a crate's card closes only with its KEEP: a tap anywhere else does nothing, so an autoclicker can't get past it)
	dim.Activated:Connect(function() if not o.crate and os.clock() - c.t0 > 1.2 then closeCard() end end)
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
	if not o.crate then task.delay(o.again and 30 or 9, function() if card == c then closeCard() end end) end
	if o.big then sound(S.Fanfare, 0.45, (o.tier or 0) >= 7 and 0.9 or 1.05) end
	-- the rarer, the louder: Secret and Divine shake the screen and flash
	if (o.tier or 0) >= 6 then
		local f = new("Frame", { Size = UDim2.fromScale(4, 4), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), BackgroundColor3 = col:Lerp(Color3.new(1, 1, 1), 0.6),
			BackgroundTransparency = 0.2, ZIndex = 10, Parent = root })
		UI.tween(f, 0.6, { BackgroundTransparency = 1 })
		Debris:AddItem(f, 0.7)
	end
end
-- the hammer collection (Client.HammersUI) shows its crates and trade-ups with this card
_G.__CE_RevealHammer = reveal
_G.__CE_RevealOpen = function() return card ~= nil end

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
	reveal({ head = "⚡ STORM UNLOCKED! ⚡", name = sh.name, icon = sh.icon, color = sh.color or Color3.fromRGB(80, 170, 255), rarity = { "EXCLUSIVE", Color3.fromRGB(24, 214, 200) }, rid = "exclusive",
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
	if plr then burst(heldTool(plr), pos, false, tostring(uid)) end
end)

-- for testing in Studio: _G.__HammerReveal("Galaxy Hammer") / _G.__HammerReveal("storm")
if RunService:IsStudio() then
	_G.__HammerReveal = function(name)
		if name == "storm" then revealStorm() else revealTool(name) end
	end
end
