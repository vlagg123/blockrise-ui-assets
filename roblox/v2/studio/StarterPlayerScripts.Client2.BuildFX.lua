-- BlockRise 2.0 - the construction show on the client (BUILD_V1, 2026-10-18): the live game's piece animations, ported
-- as they are (drop, rise, grow, fade, steel, beam, deck, the glass panels sliding in, pieces taken away), the tower
-- crane lifting the high pieces, dust / chips / sparks. The server places the parts (Build = the live Construction);
-- every part with an "Anim" attribute that appears in the world gets its animation here.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local M = {}
local NSK = NumberSequenceKeypoint

local function tween(o, t, props, style, dir)
	local tw = TweenService:Create(o, TweenInfo.new(t, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props)
	tw:Play()
	return tw
end

-- particles: dust, chips, sparks, confetti
function M.emit(pos, kind, color, n)
	local p = Instance.new("Part")
	p.Anchored = true p.CanCollide = false p.CanQuery = false p.CanTouch = false p.Transparency = 1 p.Size = Vector3.one
	p.CFrame = CFrame.new(pos)
	p.Parent = workspace
	local e = Instance.new("ParticleEmitter")
	e.Enabled = false
	e.Rotation = NumberRange.new(0, 360)
	if kind == "dust" then
		e.Texture = "rbxasset://textures/particles/smoke_main.dds"
		e.Color = ColorSequence.new(color)
		e.Size = NumberSequence.new({ NSK(0, 1.2), NSK(1, 3.6) })
		e.Transparency = NumberSequence.new({ NSK(0, 0.3), NSK(1, 1) })
		e.Lifetime = NumberRange.new(0.6, 1.2)
		e.Speed = NumberRange.new(4, 9)
		e.SpreadAngle = Vector2.new(80, 80)
		e.Acceleration = Vector3.new(0, 2, 0)
		e.Drag = 4
		e.RotSpeed = NumberRange.new(-60, 60)
	elseif kind == "chips" then
		e.Texture = "rbxasset://textures/particles/smoke_main.dds"
		e.Color = ColorSequence.new(color)
		e.Size = NumberSequence.new({ NSK(0, 0.45), NSK(1, 0.25) })
		e.Transparency = NumberSequence.new({ NSK(0, 0), NSK(0.8, 0), NSK(1, 1) })
		e.Lifetime = NumberRange.new(0.5, 0.9)
		e.Speed = NumberRange.new(12, 20)
		e.SpreadAngle = Vector2.new(45, 45)
		e.Acceleration = Vector3.new(0, -70, 0)
		e.EmissionDirection = Enum.NormalId.Top
	elseif kind == "sparks" then
		e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		e.Color = ColorSequence.new(color)
		e.LightEmission = 1
		e.Size = NumberSequence.new({ NSK(0, 0.6), NSK(1, 0) })
		e.Lifetime = NumberRange.new(0.25, 0.55)
		e.Speed = NumberRange.new(14, 26)
		e.SpreadAngle = Vector2.new(70, 70)
		e.Acceleration = Vector3.new(0, -50, 0)
	elseif kind == "confetti" then
		e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		e.Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 80, 80)), ColorSequenceKeypoint.new(0.25, Color3.fromRGB(255, 200, 40)),
			ColorSequenceKeypoint.new(0.5, Color3.fromRGB(80, 220, 120)), ColorSequenceKeypoint.new(0.75, Color3.fromRGB(80, 160, 255)), ColorSequenceKeypoint.new(1, Color3.fromRGB(200, 100, 255)) })
		e.LightEmission = 0.4
		e.Size = NumberSequence.new({ NSK(0, 1.3), NSK(1, 0.6) })
		e.Lifetime = NumberRange.new(2.2, 3.6)
		e.Speed = NumberRange.new(40, 70)
		e.SpreadAngle = Vector2.new(35, 35)
		e.EmissionDirection = Enum.NormalId.Top
		e.Acceleration = Vector3.new(0, -30, 0)
		e.Drag = 1.2
		e.RotSpeed = NumberRange.new(-200, 200)
	end
	e.Parent = p
	e:Emit(n or 10)
	Debris:AddItem(p, 5)
end
local emit = M.emit

-- sounds (the live game's set): 2D for your own actions, 3D (a short life in the world) for what happens on the sites.
-- The pieces' sounds are rate-limited so a stage that shows many pieces at once stays pleasant
M.S = {
	Hammer = "rbxassetid://9120954412", Brick = "rbxassetid://9118609285", Wood = "rbxassetid://9120871244",
	Pour = "rbxassetid://9117934842", Metal = "rbxassetid://9125672726", Dig = "rbxassetid://9114083746",
	Coins = "rbxassetid://9113849583", Fanfare = "rbxassetid://1843946260", Chime = "rbxassetid://4612374036",
}
local SoundService = game:GetService("SoundService")
local sound2D = {}
local fades = {}
function M.play(key, vol, pitch, dur)
	local id = M.S[key]
	if not id then return end
	local s = sound2D[key]
	if not s then
		s = Instance.new("Sound")
		s.Name = "FX_" .. key
		s.SoundId = id
		s.Parent = SoundService
		sound2D[key] = s
	end
	if fades[key] then fades[key]:Cancel() fades[key] = nil end
	s.Volume = vol or 0.5
	s.PlaybackSpeed = pitch or 1
	s.TimePosition = 0
	s:Play()
	-- a long sound (the fanfare) can be cut short with a fade
	if dur then
		local token = {}
		fades[key .. "_t"] = token
		task.delay(dur, function()
			if fades[key .. "_t"] ~= token or not s.IsPlaying then return end
			local tw = TweenService:Create(s, TweenInfo.new(0.7), { Volume = 0 })
			fades[key] = tw
			tw.Completed:Connect(function(st) if st == Enum.PlaybackState.Completed then s:Stop() end end)
			tw:Play()
		end)
	end
end
function M.play3D(key, pos, vol, pitch, far)
	local id = M.S[key]
	local cam = workspace.CurrentCamera
	if not id or not cam or (cam.CFrame.Position - pos).Magnitude > (far or 160) then return end
	local a = Instance.new("Attachment")
	a.WorldPosition = pos
	a.Parent = workspace.Terrain
	local s = Instance.new("Sound")
	s.SoundId = id
	s.Volume = vol or 0.4
	s.PlaybackSpeed = pitch or 1
	s.RollOffMode = Enum.RollOffMode.InverseTapered
	s.RollOffMinDistance = 14
	s.RollOffMaxDistance = far or 160
	s.Parent = a
	s:Play()
	Debris:AddItem(a, 3)
end
task.spawn(function()
	local list = {}
	for _, id in pairs(M.S) do
		local s = Instance.new("Sound")
		s.SoundId = id
		table.insert(list, s)
	end
	pcall(function() game:GetService("ContentProvider"):PreloadAsync(list) end)
end)
local lastPiece = 0
local function pieceSound(p, anim)
	local now = os.clock()
	if now - lastPiece < 0.085 then return end
	lastPiece = now
	local m = p.Material
	local key, vol = "Brick", 0.28
	if anim == "steel" or anim == "beam" or m == Enum.Material.Metal or m == Enum.Material.DiamondPlate or m == Enum.Material.CorrodedMetal then key, vol = "Metal", 0.14
	elseif m == Enum.Material.Wood or m == Enum.Material.WoodPlanks then key, vol = "Wood", 0.3
	elseif anim == "rise" or m == Enum.Material.Concrete or m == Enum.Material.Slate or m == Enum.Material.Pavement then key, vol = "Pour", 0.22
	elseif m == Enum.Material.Glass then key, vol = "Chime", 0.08
	elseif m == Enum.Material.Ground or m == Enum.Material.Mud or m == Enum.Material.Sand or m == Enum.Material.Grass then key, vol = "Dig", 0.22 end
	M.play3D(key, p.Position, vol, 0.9 + math.random() * 0.25, 120)
end

-- the tower crane lifts the high pieces (the crane section below moves it) -------------------------------------
local lifts = { aim = {}, lift = {} }
local function craneTake(p)
	local m = p.Parent
	if not (m and m:IsA("Model")) then return false end
	local folder = workspace:FindFirstChild("Cranes")
	local crane = folder and folder:FindFirstChild("Crane_" .. m.Name)
	local pivot = crane and crane:GetAttribute("Pivot")
	if typeof(pivot) ~= "CFrame" then return false end
	local target, size = p.CFrame, p.Size
	local base = crane:FindFirstChild("Base")
	local groundY = base and base.Position.Y or (pivot.Position.Y - (crane:GetAttribute("Height") or 30))
	if target.Position.Y - groundY < 9 then return false end
	local now = os.clock()
	local cur = lifts.lift[crane]
	if cur and now < cur.t1 then return false end
	local hook = crane:FindFirstChild("Hook")
	local from = hook and (hook.Position - Vector3.new(0, 0.55 + size.Y / 2, 0)) or (target.Position + Vector3.new(0, 10, 0))
	if (from - target.Position).Magnitude > 70 then from = target.Position + Vector3.new(0, 10, 0) end
	local dur = math.clamp((from - target.Position).Magnitude / 26, 0.45, 1.1)
	lifts.aim[crane] = { pos = target.Position, t = now }
	lifts.lift[crane] = { part = p, t1 = now + dur + 0.12, size = size }
	p.CFrame = CFrame.new(from) * target.Rotation
	tween(p, dur, { CFrame = target }, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
	local anim = p:GetAttribute("Anim")
	task.delay(dur, function()
		if p.Parent and (anim == "steel" or anim == "beam") then emit(target.Position, "sparks", Color3.fromRGB(255, 190, 90), 6) end
		if p.Parent then pieceSound(p, anim) end
	end)
	return true
end

-- the hologram (GHOST_V1): while a building goes up, the finished building stands over its site as a see-through blue
-- shell; every real piece that arrives takes the place of its ghost piece, so the hologram fills in as the work goes on.
-- The server tags the site model with Blueprint, Origin and Scale; the pieces are the blueprint's (as the server builds
-- them), minus the dig and the scaffolding that comes down again
local ghosts = {}
local GHOST, GHOST_T = Color3.fromRGB(120, 210, 255), 0.74
local function gkey(cf, size)
	local p = cf.Position
	local function q(v) return math.floor(v * 4 + 0.5) end
	return q(p.X) .. "," .. q(p.Y) .. "," .. q(p.Z) .. "|" .. q(size.X) .. "," .. q(size.Y) .. "," .. q(size.Z)
end
local function ghostTake(part)
	local gh = ghosts[part.Parent]
	if not gh then return end
	local key = gkey(part.CFrame, part.Size)
	local g = gh.map[key]
	if g then
		gh.map[key] = nil
		g:Destroy()
	end
end
function M.ghost(job)
	if ghosts[job] or job.Name == "Building" then return end
	local bp, origin = job:GetAttribute("Blueprint"), job:GetAttribute("Origin")
	if type(bp) ~= "string" or typeof(origin) ~= "CFrame" then return end
	local cam = workspace.CurrentCamera
	if cam and (cam.CFrame.Position - origin.Position).Magnitude > 600 then return end
	local okB, Blueprints = pcall(require, ReplicatedStorage.Shared:WaitForChild("Blueprints", 10))
	if not okB or not Blueprints[bp] then return end
	local okS, stages = pcall(Blueprints[bp])
	if not okS or type(stages) ~= "table" then return end
	local S = tonumber(job:GetAttribute("Scale")) or 1
	local function place(spec) return origin * (CFrame.new(spec.c.Position * S) * spec.c.Rotation), spec.s * S end
	local gone = {}
	for _, st in ipairs(stages) do
		for _, spec in ipairs(st.removes or {}) do
			if spec.s and spec.c then
				local cf, sz = place(spec)
				gone[gkey(cf, sz)] = true
			end
		end
	end
	local g = Instance.new("Model")
	g.Name = "Ghost_" .. job.Name
	local map, n = {}, 0
	for _, st in ipairs(stages) do
		if st.key ~= "dig" then
			for _, spec in ipairs(st.adds or {}) do
				if n < 1000 and spec.s and spec.c and (spec.t or 0) < 0.9 then
					local cf, sz = place(spec)
					local key = gkey(cf, sz)
					-- (the tiny trims are left out: the shape reads the same and phones draw far fewer see-through parts)
					if not gone[key] and not map[key] and math.max(sz.X, sz.Y, sz.Z) >= 1.5 then
						n += 1
						local p = Instance.new(spec.shape == "Wedge" and "WedgePart" or "Part")
						if spec.shape == "Ball" then p.Shape = Enum.PartType.Ball elseif spec.shape == "Cylinder" then p.Shape = Enum.PartType.Cylinder end
						p.Anchored = true p.CanCollide = false p.CanQuery = false p.CanTouch = false p.CastShadow = false
						p.Size = sz
						p.CFrame = cf
						p.Material = Enum.Material.SmoothPlastic
						p.Color = GHOST
						p.Transparency = 1
						p.Parent = g
						map[key] = p
					end
				end
			end
		end
	end
	local folder = workspace:FindFirstChild("FX2") or workspace
	g.Parent = folder
	local gh = { model = g, map = map }
	ghosts[job] = gh
	-- the pieces already standing (a site seen late) take their place at once
	for _, d in ipairs(job:GetChildren()) do if d:IsA("BasePart") then ghostTake(d) end end
	-- it fades in
	for _, p in pairs(map) do tween(p, 0.8, { Transparency = GHOST_T }) end
	local function finish()
		if ghosts[job] ~= gh then return end
		ghosts[job] = nil
		for _, p in pairs(gh.map) do if p.Parent then tween(p, 0.5, { Transparency = 1 }) end end
		Debris:AddItem(g, 0.6)
	end
	job:GetPropertyChangedSignal("Name"):Connect(function() if job.Name == "Building" then finish() end end)
	job.AncestryChanged:Connect(function() if not job:IsDescendantOf(workspace) then finish() end end)
end
local function maybeGhost(m)
	if not (m:IsA("Model") and m:GetAttribute("JobId") and m.Name:sub(1, 1) == "J") then return end
	task.spawn(function()
		local t0 = os.clock()
		while m.Parent and not m:GetAttribute("Origin") and os.clock() - t0 < 3 do task.wait(0.1) end
		if m.Parent then M.ghost(m) end
	end)
end

-- one piece arriving ----------------------------------------------------------------------------------------
local function animatePart(p)
	local anim = p:GetAttribute("Anim")
	if not anim then return end
	-- (only pieces near the camera get the show: a far site just has its pieces)
	local cam = workspace.CurrentCamera
	if cam and (cam.CFrame.Position - p.Position).Magnitude > 420 then return end
	local target, size, trans = p.CFrame, p.Size, p.Transparency
	if (anim == "drop" or anim == "steel" or anim == "beam" or anim == "deck") and craneTake(p) then return end
	task.delay(anim == "rise" and 0.1 or 0.3, function() if p.Parent then pieceSound(p, anim) end end)
	if anim == "drop" then
		if p.Material == Enum.Material.Glass and size.Y >= 2 and math.min(size.X, size.Z) <= 1.3 then
			-- a glass facade panel slides in from outside and catches the light
			local m = p.Parent
			local jobs = ReplicatedStorage:FindFirstChild("Jobs")
			local job = m and jobs and jobs:FindFirstChild(m.Name)
			local center = job and job:GetAttribute("Center")
			local n = size.Z <= size.X and target.LookVector or target.RightVector
			if typeof(center) == "Vector3" and n:Dot(target.Position - center) < 0 then n = -n end
			local col = p.Color
			p.CFrame = target + n * 3
			p.Transparency = 1
			p.Color = col:Lerp(Color3.new(1, 1, 1), 0.65)
			tween(p, 0.45, { CFrame = target, Transparency = trans })
			tween(p, 0.9, { Color = col }, Enum.EasingStyle.Sine)
		else
			p.CFrame = target + Vector3.new(0, 4, 0)
			p.Transparency = 1
			tween(p, 0.4, { CFrame = target }, Enum.EasingStyle.Back)
			tween(p, 0.2, { Transparency = trans })
			-- a little dust where a heavy piece lands
			if size.X * size.Y * size.Z > 6 and math.random() < 0.18 then
				task.delay(0.32, function()
					if p.Parent then emit(target.Position - Vector3.new(0, size.Y / 2, 0), "dust", p.Color:Lerp(Color3.fromRGB(170, 160, 150), 0.6), 3) end
				end)
			end
		end
	elseif anim == "rise" then
		p.Size = Vector3.new(size.X, 0.05, size.Z)
		p.CFrame = target * CFrame.new(0, -size.Y / 2 + 0.025, 0)
		tween(p, 0.6, { Size = size, CFrame = target })
	elseif anim == "grow" then
		p.Size = size * 0.15
		tween(p, 0.55, { Size = size }, Enum.EasingStyle.Back)
	elseif anim == "fade" then
		p.Transparency = 1
		tween(p, 0.7, { Transparency = trans })
	elseif anim == "steel" then
		p.Size = Vector3.new(size.X, 0.05, size.Z)
		p.CFrame = target * CFrame.new(0, -size.Y / 2 + 0.025, 0)
		tween(p, 0.35, { Size = size, CFrame = target })
		if math.random() < 0.4 then
			task.delay(0.35, function() if p.Parent then emit((target * CFrame.new(0, size.Y / 2, 0)).Position, "sparks", Color3.fromRGB(255, 190, 90), 7) end end)
		end
	elseif anim == "beam" then
		local long = size.X >= size.Z
		local L = long and size.X or size.Z
		p.Size = long and Vector3.new(0.05, size.Y, size.Z) or Vector3.new(size.X, size.Y, 0.05)
		p.CFrame = target * (long and CFrame.new(-L / 2, 0, 0) or CFrame.new(0, 0, -L / 2))
		tween(p, 0.4, { Size = size, CFrame = target })
	elseif anim == "deck" then
		p.Transparency = 1
		p.CFrame = target - Vector3.new(0, 0.6, 0)
		tween(p, 0.45, { CFrame = target, Transparency = trans })
	end
end

-- a piece taken away (debris, soil, the spoil pile, an old building coming down)
local function hookRemove(p)
	p:GetAttributeChangedSignal("Remove"):Connect(function()
		if not p:GetAttribute("Remove") then return end
		local cam = workspace.CurrentCamera
		if cam and (cam.CFrame.Position - p.Position).Magnitude > 420 then return end
		local cf = p.CFrame
		tween(p, 0.45, { Size = p.Size * 0.12, CFrame = cf - Vector3.new(0, p.Size.Y * 0.4, 0), Transparency = 1 }, Enum.EasingStyle.Back, Enum.EasingDirection.In)
		if math.random() < 0.6 then emit(p.Position, "dust", p.Color:Lerp(Color3.fromRGB(160, 140, 120), 0.5), 5) end
		if math.random() < 0.35 then M.play3D("Dig", p.Position, 0.18, 0.85 + math.random() * 0.2, 110) end
	end)
end

function M.start()
	local world = workspace:WaitForChild("World")
	local districts = world:WaitForChild("Districts")
	-- a piece of a building or a site: a part of a model standing in a lot
	local function inLot(d)
		local m = d.Parent
		return m ~= nil and m:IsA("Model") and m.Parent ~= nil and m.Parent:GetAttribute("Lot") ~= nil
	end
	local function watch(root)
		root.DescendantAdded:Connect(function(d)
			if d:IsA("BasePart") and inLot(d) then
				ghostTake(d)
				if d:GetAttribute("Anim") then animatePart(d) end
				hookRemove(d)
			elseif d:IsA("Model") then
				maybeGhost(d)
			end
		end)
		for _, d in ipairs(root:GetDescendants()) do
			if d:IsA("BasePart") and inLot(d) then hookRemove(d) elseif d:IsA("Model") then maybeGhost(d) end
		end
	end
	watch(districts)

	-- the tower cranes: swing the jib, move the trolley, lower and raise the hook (local, smooth)
	local craneCache = {}
	local function towards(cur, want, step)
		if math.abs(want - cur) <= step then return want end
		return cur + math.sign(want - cur) * step
	end
	local function turnTowards(cur, want, step)
		local d = (want - cur + math.pi) % (2 * math.pi) - math.pi
		if math.abs(d) <= step then return cur + d end
		return cur + math.sign(d) * step
	end
	RunService.RenderStepped:Connect(function(dt)
		local folder = workspace:FindFirstChild("Cranes")
		if not folder then return end
		local t = os.clock()
		dt = math.min(dt or 1 / 60, 0.1)
		for _, m in ipairs(folder:GetChildren()) do
			local c = craneCache[m]
			if not c then
				c = { swing = {}, trolley = m:FindFirstChild("Trolley"), cable = m:FindFirstChild("Cable"), hook = m:FindFirstChild("Hook") }
				for _, p in ipairs(m:GetChildren()) do
					local rel = p:IsA("BasePart") and p:GetAttribute("Rel")
					if rel then table.insert(c.swing, { p, rel }) end
				end
				craneCache[m] = c
			end
			local pivot = m:GetAttribute("Pivot")
			if pivot and c.trolley and c.hook and c.cable then
				local seed = m:GetAttribute("Seed") or 0
				local reach = m:GetAttribute("Reach") or 20
				local H = m:GetAttribute("Height") or 30
				local angle = (m:GetAttribute("BaseAngle") or 0) + math.sin(t * 0.11 + seed) * 0.9
				local tx = reach * (0.45 + 0.3 * math.sin(t * 0.17 + seed * 2))
				local drop = 3 + (H - 6) * (0.45 + 0.35 * math.sin(t * 0.23 + seed))
				local aim = lifts.aim[m]
				if aim and t - aim.t < 4 then
					local d = aim.pos - pivot.Position
					angle = math.atan2(-d.Z, d.X)
					tx = math.clamp(Vector2.new(d.X, d.Z).Magnitude, 3, reach - 0.5)
					drop = math.clamp(pivot.Position.Y + 0.35 - (aim.pos.Y + 4), 2, H + 2)
				elseif aim then
					lifts.aim[m] = nil
				end
				c.angle = c.angle and turnTowards(c.angle, angle, 1.4 * dt) or angle
				c.tx = c.tx and towards(c.tx, tx, 16 * dt) or tx
				c.drop = c.drop and towards(c.drop, drop, 20 * dt) or drop
				local rot = pivot * CFrame.Angles(0, c.angle, 0)
				for _, e in ipairs(c.swing) do e[1].CFrame = rot * e[2] end
				c.trolley.CFrame = rot * CFrame.new(c.tx, 0.65, 0)
				local lift = lifts.lift[m]
				local hold = lift and lift.part.Parent and (t < lift.t1 or (t < lift.t1 + 2.5
					and (((rot * CFrame.new(c.tx, 0, 0)).Position - lift.part.Position) * Vector3.new(1, 0, 1)).Magnitude > 1.2))
				if hold then
					local a1 = (rot * CFrame.new(c.tx, 0.35, 0)).Position
					local a2 = lift.part.Position + Vector3.new(0, lift.size.Y / 2 + 1.1, 0)
					local len = math.max(0.5, (a2 - a1).Magnitude)
					c.cable.Size = Vector3.new(0.12, len, 0.12)
					c.cable.CFrame = CFrame.lookAt((a1 + a2) / 2, a2) * CFrame.Angles(-math.pi / 2, 0, 0)
					c.hook.CFrame = CFrame.new(a2 - Vector3.new(0, 0.55, 0))
					c.drop = math.clamp(pivot.Position.Y + 0.35 - a2.Y, 2, H + 2)
				else
					if lift then lifts.lift[m] = nil end
					c.cable.Size = Vector3.new(0.12, c.drop, 0.12)
					c.cable.CFrame = rot * CFrame.new(c.tx, 0.35 - c.drop / 2, 0)
					c.hook.CFrame = rot * CFrame.new(c.tx, 0.35 - c.drop - 0.55, 0)
				end
			end
		end
		for m in pairs(craneCache) do
			if not m.Parent then
				craneCache[m] = nil
				lifts.aim[m] = nil
				lifts.lift[m] = nil
			end
		end
	end)
end

-- a building drawn locally (the cards): the finished blueprint, in `parent`, around CFrame.new()
function M.preview(bpName, parent)
	local ok, Blueprints = pcall(require, ReplicatedStorage.Shared:WaitForChild("Blueprints", 10))
	if not ok or not Blueprints[bpName] then return nil end
	local stages, info = Blueprints[bpName]()
	local m = Instance.new("Model")
	for _, st in ipairs(stages) do
		if st.key ~= "dig" then
			for _, spec in ipairs(st.adds or {}) do
				local p = Instance.new(spec.shape == "Wedge" and "WedgePart" or "Part")
				if spec.shape == "Ball" then p.Shape = Enum.PartType.Ball end
				if spec.shape == "Cylinder" then p.Shape = Enum.PartType.Cylinder end
				p.Anchored = true
				p.TopSurface = Enum.SurfaceType.Smooth
				p.BottomSurface = Enum.SurfaceType.Smooth
				p.Size = spec.s
				p.CFrame = spec.c
				p.Material = spec.m
				if spec.v then p.MaterialVariant = spec.v end
				p.Color = spec.concrete and Color3.fromRGB(200, 200, 196) or spec.col
				p.Transparency = spec.t or 0
				if spec.text then
					local sg = Instance.new("SurfaceGui")
					sg.Face = spec.face or Enum.NormalId.Front
					sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
					sg.PixelsPerStud = 30
					local t = Instance.new("TextLabel")
					t.BackgroundTransparency = 1
					t.Size = UDim2.fromScale(1, 1)
					t.Font = spec.font or Enum.Font.GothamBlack
					t.TextScaled = true
					t.TextColor3 = spec.textCol or Color3.new(1, 1, 1)
					t.Text = spec.text
					t.Parent = sg
					sg.Parent = p
				end
				p.Parent = m
			end
		end
	end
	m.Parent = parent
	return m, info
end

return M
