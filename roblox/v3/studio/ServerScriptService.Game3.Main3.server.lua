-- BlockRise 3.0 (tycoon prototype, PROTO3_V1, 2026-10-18) - the server.
-- Each player gets a plot (an empty lawn behind a gate on the avenue). Buttons on the ground: step on one and, if
-- you have the cash, it is built right there: the builders run over with their hammers and the building rises floor by
-- floor (the street is poured stretch by stretch, the lamps and the park drop in piece by piece). When it is done the
-- next buttons appear. Every building makes money; the money piles up in the vault at the gate; step on the gold pad
-- to take it. Tapping near a site while it is being built makes it go faster.
-- (A prototype for the feel: nothing is saved yet.)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local RunService = game:GetService("RunService")
local PhysicsService = game:GetService("PhysicsService")

local T = require(ReplicatedStorage.Shared3.Tycoon)
local B = require(ReplicatedStorage.Shared3.Buildings)
local Hammers = require(ReplicatedStorage.Shared.Hammers)
local World3 = require(ServerStorage.Build3.World3)

local at = CFrame.new
local C3 = Color3.fromRGB

-- remotes ------------------------------------------------------------------------------------------------------
local Remotes = ReplicatedStorage:FindFirstChild("Remotes3") or Instance.new("Folder")
Remotes.Name = "Remotes3"
Remotes.Parent = ReplicatedStorage
local function remote(class, name)
	local r = Remotes:FindFirstChild(name) or Instance.new(class)
	r.Name = name
	r.Parent = Remotes
	return r
end
local EventRE = remote("RemoteEvent", "Event") -- server -> client: kind, data
local TapRE = remote("RemoteEvent", "Tap")     -- client -> server: a hammer tap near a site
local HitsRE = remote("RemoteEvent", "Hits")   -- server -> clients: builders' hammer hits { pos, rarity }

pcall(function() PhysicsService:RegisterCollisionGroup("Builders") end)
pcall(function() PhysicsService:CollisionGroupSetCollidable("Builders", "Builders", false) end)

-- state ----------------------------------------------------------------------------------------------------------
local world = workspace:WaitForChild("World3")
local S = {} -- player -> { money }
local P = {} -- plot index -> plot state
for i = 1, 6 do
	local m = world.Plots:FindFirstChild("P" .. i)
	P[i] = { i = i, model = m, cf = World3.plotCF(i), owned = {}, pending = {}, buttons = {}, jobs = {}, workers = {}, vault = 0, income = 0, bonus = 0, on = {} }
end

local function setMoney(plr, v)
	local st = S[plr]
	if not st then return end
	st.money = v
	plr:SetAttribute("Money", v)
	local ls = plr:FindFirstChild("leaderstats")
	if ls and ls:FindFirstChild("Cash") then ls.Cash.Value = math.floor(v) end
end

-- making parts ---------------------------------------------------------------------------------------------------
local function inst(spec, parent, origin)
	local p = Instance.new(spec.k == "wedge" and "WedgePart" or "Part")
	if spec.k == "cyl" then p.Shape = Enum.PartType.Cylinder elseif spec.k == "ball" then p.Shape = Enum.PartType.Ball end
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Size = spec.s
	p.CFrame = origin * spec.c
	p.Color = spec.col
	p.Material = spec.m
	p.Transparency = spec.t or 0
	if spec.text then
		local sg = Instance.new("SurfaceGui")
		sg.Face = Enum.NormalId.Front
		sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		sg.PixelsPerStud = 40
		sg.LightInfluence = 0
		local t = Instance.new("TextLabel")
		t.BackgroundTransparency = 1
		t.Size = UDim2.fromScale(1, 1)
		t.Font = Enum.Font.FredokaOne
		t.TextScaled = true
		t.TextColor3 = spec.tcol or Color3.new(1, 1, 1)
		t.Text = spec.text
		local s = Instance.new("UIStroke")
		s.Thickness = 3
		s.Color = C3(20, 24, 50)
		s.Parent = t
		t.Parent = sg
		sg.Parent = p
	end
	p.Parent = parent
	return p
end
local function part(parent, size, cf, col, mat, props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Size = size
	p.CFrame = cf
	p.Color = col
	p.Material = mat or Enum.Material.SmoothPlastic
	if props then for k, v in pairs(props) do p[k] = v end end
	p.Parent = parent
	return p
end
local function cyl(parent, r, h, cf, col, mat, props)
	local p = part(parent, Vector3.new(h, r * 2, r * 2), cf * CFrame.Angles(0, 0, math.pi / 2), col, mat, props)
	p.Shape = Enum.PartType.Cylinder
	return p
end
local function kit(name, parent, cf)
	local src = ServerStorage:FindFirstChild("Kit2") and ServerStorage.Kit2:FindFirstChild(name)
	if not src then return nil end
	local m = src:Clone()
	m:PivotTo(cf)
	for _, d in ipairs(m:GetDescendants()) do if d:IsA("BasePart") then d.Anchored = true end end
	m.Parent = parent
	return m
end

-- the builders (NPCs in hard hats with real hammers) -------------------------------------------------------------
local SKIN = { C3(255, 214, 180), C3(234, 184, 146), C3(198, 140, 100), C3(150, 104, 72), C3(104, 70, 50) }
local SHIRTS = { C3(255, 150, 40), C3(70, 150, 240), C3(240, 80, 90), C3(60, 190, 120), C3(160, 110, 240), C3(255, 200, 60) }
local ANIM = { walk = "rbxassetid://507777826", idle = "rbxassetid://507766388", work = "rbxassetid://522635514", hold = "rbxassetid://507768375" }
local REST = CFrame.Angles(math.rad(35), 0, 0)

local function weldTo(part0, p)
	local w = Instance.new("WeldConstraint")
	w.Part0 = part0
	w.Part1 = p
	w.Parent = p
	p.Anchored = false
	p.CanCollide = false
	p.Massless = true
	p.CanQuery = false
	p.CanTouch = false
end
local function makeRig(i)
	local desc = Instance.new("HumanoidDescription")
	local skin = SKIN[(i * 3) % #SKIN + 1]
	desc.HeadColor = skin
	desc.LeftArmColor = skin
	desc.RightArmColor = skin
	desc.TorsoColor = SHIRTS[(i - 1) % #SHIRTS + 1]
	desc.LeftLegColor = C3(44, 60, 110)
	desc.RightLegColor = C3(44, 60, 110)
	local ok, model = pcall(function() return Players:CreateHumanoidModelFromDescription(desc, Enum.HumanoidRigType.R15) end)
	if not ok or not model then warn("[Main3] builder rig failed", model) return nil end
	local animate = model:FindFirstChild("Animate")
	if animate then animate:Destroy() end
	local head = model:FindFirstChild("Head")
	if head then
		local hat = Instance.new("Part")
		hat.Shape = Enum.PartType.Ball
		hat.Size = Vector3.one * head.Size.X * 1.12
		hat.Color = C3(255, 206, 40)
		hat.CFrame = head.CFrame * at(0, head.Size.Y * 0.3, 0)
		hat.Name = "HardHat"
		hat.Parent = model
		weldTo(head, hat)
		local brim = Instance.new("Part")
		brim.Shape = Enum.PartType.Cylinder
		brim.Size = Vector3.new(0.14, head.Size.X * 1.55, head.Size.X * 1.55)
		brim.Color = hat.Color
		brim.CFrame = head.CFrame * at(0, head.Size.Y * 0.16, -0.1) * CFrame.Angles(0, 0, math.pi / 2)
		brim.Name = "Brim"
		brim.Parent = model
		weldTo(head, brim)
	end
	local torso = model:FindFirstChild("UpperTorso")
	if torso then
		for _, y in ipairs({ -0.2, 0.25 }) do
			local s = Instance.new("Part")
			s.Size = Vector3.new(torso.Size.X + 0.06, 0.16, torso.Size.Z + 0.06)
			s.Color = C3(235, 255, 130)
			s.Material = Enum.Material.Neon
			s.CFrame = torso.CFrame * at(0, y, 0)
			s.Name = "Stripe"
			s.Parent = model
			weldTo(torso, s)
		end
	end
	local hum = model:FindFirstChildOfClass("Humanoid")
	hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	hum.WalkSpeed = 26
	for _, s in ipairs({ Enum.HumanoidStateType.Climbing, Enum.HumanoidStateType.Swimming, Enum.HumanoidStateType.Seated, Enum.HumanoidStateType.Ragdoll,
		Enum.HumanoidStateType.FallingDown, Enum.HumanoidStateType.Flying, Enum.HumanoidStateType.PlatformStanding, Enum.HumanoidStateType.GettingUp }) do
		pcall(function() hum:SetStateEnabled(s, false) end)
	end
	hum.BreakJointsOnDeath = false
	hum.RequiresNeck = false
	for _, p in ipairs(model:GetDescendants()) do if p:IsA("BasePart") then p.CollisionGroup = "Builders" end end
	return model, hum
end

-- a hammer (the key's model) in a character's right hand, resting on the shoulder
local function giveHammer(model, key)
	local old = model:FindFirstChild("HeldHammer")
	if old then old:Destroy() end
	local h = Hammers.ById[key] or Hammers.ById.rusty
	local src = ServerStorage:FindFirstChild("Hammers") and ServerStorage.Hammers:FindFirstChild("Hammer_" .. (h.model or "1"))
	local hand = model:FindFirstChild("RightHand")
	if not src or not hand then return nil end
	local tool = src:Clone()
	local handle = tool:FindFirstChild("Handle")
	if not handle then tool:Destroy() return nil end
	local m = Instance.new("Model")
	m.Name = "HeldHammer"
	for _, c in ipairs(tool:GetChildren()) do
		if c:IsA("BaseScript") then c:Destroy() else c.Parent = m end
	end
	local grip = tool.Grip
	tool:Destroy()
	for _, p in ipairs(m:GetDescendants()) do
		if p:IsA("BaseScript") then p:Destroy()
		elseif p:IsA("BasePart") then p.Anchored = false p.CanCollide = false p.Massless = true p.CanQuery = false p.CanTouch = false end
	end
	local att = hand:FindFirstChild("RightGripAttachment")
	local base = att and att.CFrame or at(0, -0.3, 0)
	m:PivotTo(((hand.CFrame * base * REST * grip:Inverse()) * handle.CFrame:Inverse()) * m:GetPivot())
	m.Parent = model
	local wd = Instance.new("Weld")
	wd.Name = "GripWeld"
	wd.Part0 = hand
	wd.Part1 = handle
	wd.C0 = base * REST
	wd.C1 = grip
	wd:SetAttribute("Base", base)
	wd.Parent = handle
	return wd
end

local function play(w, name, speed)
	if w.playing == name then return end
	if w.track then w.track:Stop(0.15) end
	local animator = w.hum:FindFirstChildOfClass("Animator") or Instance.new("Animator", w.hum)
	w.anims = w.anims or {}
	if not w.anims[name] then
		local a = Instance.new("Animation")
		a.AnimationId = ANIM[name]
		local ok, tr = pcall(function() return animator:LoadAnimation(a) end)
		if ok then
			tr.Looped = true
			tr.Priority = name == "work" and Enum.AnimationPriority.Action2 or (name == "walk" and Enum.AnimationPriority.Movement or Enum.AnimationPriority.Idle)
			w.anims[name] = tr
		end
	end
	w.track = w.anims[name]
	w.playing = name
	if w.track then w.track:Play(0.15, 1, speed or 1) end
	if not w.holdTrack then
		local a = Instance.new("Animation")
		a.AnimationId = ANIM.hold
		local ok, tr = pcall(function() return animator:LoadAnimation(a) end)
		if ok then tr.Looped = true tr.Priority = Enum.AnimationPriority.Action w.holdTrack = tr end
	end
	if w.holdTrack then
		if name == "work" then w.holdTrack:Stop(0.1) elseif not w.holdTrack.IsPlaying then w.holdTrack:Play(0.2) end
	end
	if w.grip and w.grip.Parent then
		local base = w.grip:GetAttribute("Base")
		if base then w.grip.C0 = name == "work" and base or base * REST end
	end
end

local function idleSpot(p, i)
	return (p.cf * at(30 + ((i - 1) % 3) * 6, 3, 20 + ((i - 1) // 3) * 5)).Position
end
local function addWorker(p)
	local i = #p.workers + 1
	local model, hum = makeRig(i)
	if not model then return end
	model.Name = "Builder" .. i
	model:PivotTo(CFrame.lookAt(idleSpot(p, i), (p.cf * at(0, 3, 20)).Position))
	model.Parent = p.model.Built
	local root = model:FindFirstChild("HumanoidRootPart")
	if root then pcall(function() root:SetNetworkOwner(nil) end) end
	local w = { model = model, hum = hum, root = root, i = i, key = "rusty" }
	w.grip = giveHammer(model, "rusty")
	table.insert(p.workers, w)
	return w
end

-- the jobs ---------------------------------------------------------------------------------------------------------
local function speedOf(p) return 1 + math.max(0, #p.workers - 1) * T.WorkerSpeed end

-- a building: its foundation, its floors, its roof, one after the other
local function startBuilding(p, u)
	local spec = B.make(u.key)
	local l = T.Lots[u.lot]
	local rot = l.x < 0 and -math.pi / 2 or math.pi / 2
	local origin = p.cf * at(l.x, 0.42, l.z) * CFrame.Angles(0, rot, 0)
	local m = Instance.new("Model")
	m.Name = u.id
	m:SetAttribute("Kind", "building")
	m:SetAttribute("Key", u.key)
	m:SetAttribute("Income", u.income)
	m:SetAttribute("Height", spec.height)
	m:SetAttribute("State", "building")
	m:SetAttribute("Origin", origin)
	m.WorldPivot = origin
	m.Parent = p.model.Built
	local stages = {}
	for i = 0, spec.n + 1 do
		table.insert(stages, function()
			local f = Instance.new("Model")
			f.Name = "F" .. i
			f:SetAttribute("Floor", i)
			for _, s in ipairs(spec.floors[i]) do inst(s, f, origin) end
			f.Parent = m
		end)
	end
	return { u = u, model = m, stages = stages, site = origin, siteR = math.max(spec.w, spec.d) / 2 + 6 }
end

-- a stretch of Main Street, poured in chunks of 20 studs from the front to the back
local function startRoad(p, u)
	local seg = T.Segs[u.seg]
	local m = Instance.new("Model")
	m.Name = u.id
	m:SetAttribute("Kind", "road")
	m:SetAttribute("State", "building")
	m.Parent = p.model.Built
	local stages = {}
	local z0, z1 = seg[1], seg[2]
	local n = math.ceil((z1 - z0) / 20)
	local half, walk = T.Road.half, T.Road.walk
	for k = 1, n do
		local a = z0 + (k - 1) * (z1 - z0) / n
		local b = z0 + k * (z1 - z0) / n
		local len, zc = b - a, (a + b) / 2
		table.insert(stages, function()
			local c = Instance.new("Model")
			c.Name = "C" .. k
			c:SetAttribute("Grow", true)
			part(c, Vector3.new(half * 2, 0.5, len), p.cf * at(0, 0.27, zc), C3(64, 68, 80), nil, { Name = "Asphalt" })
			for _, sx in ipairs({ -1, 1 }) do
				part(c, Vector3.new(walk, 0.7, len), p.cf * at(sx * (half + walk / 2), 0.35, zc), C3(232, 234, 240), nil, { Name = "Walk" })
				part(c, Vector3.new(0.7, 0.8, len), p.cf * at(sx * (half + 0.35), 0.4, zc), Color3.new(1, 1, 1), nil, { Name = "Kerb" })
			end
			-- the centre dashes
			for z = a + 3, b - 3, 10 do part(c, Vector3.new(0.5, 0.52, 5), p.cf * at(0, 0.28, z + 2.5), C3(255, 214, 60), nil, { Name = "Dash" }) end
			c.Parent = m
		end)
	end
	return { u = u, model = m, stages = stages, site = p.cf * at(0, 0, z0 + 10), siteR = 14 }
end

-- street lamps along a stretch, one after the other
local function startLamps(p, u)
	local seg = T.Segs[u.seg]
	local m = Instance.new("Model")
	m.Name = u.id
	m:SetAttribute("Kind", "decor")
	m:SetAttribute("State", "building")
	m.Parent = p.model.Built
	local stages = {}
	for z = seg[1] + 12, seg[2] - 8, 26 do
		for _, sx in ipairs({ -1, 1 }) do
			table.insert(stages, function()
				local lamp = kit("StreetLight", m, p.cf * at(sx * (T.Road.half + 3.2), 0.7, z) * CFrame.Angles(0, sx < 0 and -math.pi / 2 or math.pi / 2, 0))
				if lamp then lamp:SetAttribute("Drop", true) end
			end)
		end
	end
	return { u = u, model = m, stages = stages, site = p.cf * at(0, 0, seg[1] + 30), siteR = 14 }
end

-- a pocket park on the left: grass, a path, trees, benches, flowers
local function startPark(p, u)
	local m = Instance.new("Model")
	m.Name = u.id
	m:SetAttribute("Kind", "decor")
	m:SetAttribute("State", "building")
	m.Parent = p.model.Built
	local cx, z0, z1 = -86, 50, 176
	local stages = {}
	table.insert(stages, function()
		local g = Instance.new("Model") g.Name = "Lawn" g:SetAttribute("Grow", true)
		part(g, Vector3.new(24, 0.5, z1 - z0), p.cf * at(cx, 0.3, (z0 + z1) / 2), C3(96, 190, 80), nil, { Name = "Grass" })
		part(g, Vector3.new(5, 0.56, z1 - z0), p.cf * at(cx, 0.32, (z0 + z1) / 2), C3(232, 214, 176), nil, { Name = "Path" })
		g.Parent = m
	end)
	local trees = { "TreeA", "TreeB", "TreeC", "TreeD" }
	local k = 0
	for z = z0 + 10, z1 - 8, 18 do
		k += 1
		table.insert(stages, function()
			local t = kit(trees[(k % #trees) + 1], m, p.cf * at(cx - 7.5, 0.5, z) * CFrame.Angles(0, k, 0))
			if t then t:SetAttribute("Drop", true) end
			local b = kit(k % 2 == 0 and "Bench" or "BushFlowers", m, p.cf * at(cx + 7, 0.5, z + 6) * CFrame.Angles(0, -math.pi / 2, 0))
			if b then b:SetAttribute("Drop", true) end
		end)
	end
	return { u = u, model = m, stages = stages, site = p.cf * at(cx + 14, 0, 110), siteR = 10 }
end

-- a fountain on the right: a round basin, water, a column, jets, benches around
local function startFountain(p, u)
	local m = Instance.new("Model")
	m.Name = u.id
	m:SetAttribute("Kind", "decor")
	m:SetAttribute("State", "building")
	m.Parent = p.model.Built
	local c = p.cf * at(88, 0, 112)
	local stages = {}
	table.insert(stages, function()
		local g = Instance.new("Model") g.Name = "Plaza" g:SetAttribute("Drop", true)
		cyl(g, 15, 0.5, c * at(0, 0.3, 0), C3(232, 214, 176))
		cyl(g, 9, 2.2, c * at(0, 1.3, 0), C3(240, 240, 236))
		cyl(g, 8.2, 2.3, c * at(0, 1.4, 0), C3(90, 190, 255), Enum.Material.Glass, { Transparency = 0.25 })
		g.Parent = m
	end)
	table.insert(stages, function()
		local g = Instance.new("Model") g.Name = "Column" g:SetAttribute("Drop", true)
		cyl(g, 1.6, 6, c * at(0, 4.5, 0), C3(240, 240, 236))
		cyl(g, 3.4, 0.8, c * at(0, 7.6, 0), C3(240, 240, 236))
		local top = cyl(g, 1, 1.5, c * at(0, 8.6, 0), C3(255, 200, 60))
		local pe = Instance.new("ParticleEmitter")
		pe.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		pe.Color = ColorSequence.new(C3(200, 240, 255))
		pe.LightEmission = 0.5
		pe.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.7), NumberSequenceKeypoint.new(1, 0.2) })
		pe.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
		pe.Lifetime = NumberRange.new(1.2, 1.6)
		pe.Rate = 60
		pe.Speed = NumberRange.new(14, 18)
		pe.SpreadAngle = Vector2.new(18, 18)
		pe.Acceleration = Vector3.new(0, -30, 0)
		pe.EmissionDirection = Enum.NormalId.Right -- (the cylinder's axis points up)
		pe.Parent = top
		g.Parent = m
	end)
	for k = 0, 3 do
		table.insert(stages, function()
			local a = k * math.pi / 2 + math.pi / 4
			local b = kit(k % 2 == 0 and "Bench" or "BushFlowers", m, c * at(math.cos(a) * 12, 0.5, math.sin(a) * 12) * CFrame.Angles(0, -a + math.pi / 2, 0))
			if b then b:SetAttribute("Drop", true) end
		end)
	end
	return { u = u, model = m, stages = stages, site = c * at(-16, 0, 0), siteR = 6 }
end

local starters = { building = startBuilding, road = startRoad, lamps = startLamps, park = startPark, fountain = startFountain }

-- the buttons ------------------------------------------------------------------------------------------------------
local refreshButtons
local function available(p, u)
	if p.owned[u.id] or p.pending[u.id] then return false end
	for _, a in ipairs(u.after) do if not p.owned[a] then return false end end
	return true
end
local function makeButton(p, u)
	local m = Instance.new("Model")
	m.Name = "B_" .. u.id
	m:SetAttribute("Id", u.id)
	m:SetAttribute("Label", u.label)
	m:SetAttribute("Price", u.price)
	m:SetAttribute("Income", u.income or 0)
	m:SetAttribute("Bonus", u.bonus or 0)
	m:SetAttribute("Kind", u.kind)
	m:SetAttribute("Plot", p.i)
	local cf = p.cf * at(u.at[1], 0.5, u.at[2])
	cyl(m, 3.9, 0.3, cf, Color3.new(1, 1, 1), nil, { Name = "Rim", CanCollide = false })
	local disc = cyl(m, 3.3, 0.36, cf * at(0, 0.04, 0), C3(70, 225, 110), Enum.Material.Neon, { Name = "Disc", CanCollide = false })
	m.PrimaryPart = disc
	m.Parent = p.model.Buttons
	p.buttons[u.id] = m
end
refreshButtons = function(p)
	for _, u in ipairs(T.Unlocks) do
		local has = p.buttons[u.id]
		if available(p, u) and not has then makeButton(p, u)
		elseif has and not available(p, u) then has:Destroy() p.buttons[u.id] = nil end
	end
end

local function finish(p, job)
	local u = job.u
	job.model:SetAttribute("State", "done")
	p.pending[u.id] = nil
	p.owned[u.id] = true
	if u.income then p.income += u.income end
	if u.bonus then p.bonus += u.bonus end
	p.model:SetAttribute("Income", p.income * (1 + p.bonus))
	local owner = p.owner
	if owner then EventRE:FireClient(owner, "Built", { id = u.id, label = u.label, income = u.income and u.income * (1 + p.bonus) or 0, kind = u.kind }) end
	refreshButtons(p)
end

local function buy(p, u)
	local plr = p.owner
	local st = plr and S[plr]
	if not st then return end
	if st.money < u.price then
		EventRE:FireClient(plr, "Need", { id = u.id, price = u.price, have = st.money })
		return
	end
	setMoney(plr, st.money - u.price)
	p.pending[u.id] = true
	local btn = p.buttons[u.id]
	if btn then
		btn:SetAttribute("Bought", true)
		p.buttons[u.id] = nil
		task.delay(0.45, function() if btn.Parent then btn:Destroy() end end)
	end
	EventRE:FireClient(plr, "Bought", { id = u.id, label = u.label, price = u.price })
	if u.kind == "worker" then
		task.delay(0.3, function()
			addWorker(p)
			finish(p, { u = u, model = Instance.new("Model") })
		end)
		return
	end
	local job = starters[u.kind](p, u)
	job.t = 0
	job.dur = u.time
	job.done = 0
	table.insert(p.jobs, job)
end

-- plots: claim, reset ----------------------------------------------------------------------------------------------
local function setGate(p, text)
	local gate = p.model:FindFirstChild("Gate")
	local beam = gate and gate:FindFirstChild("Beam")
	if not beam then return end
	for _, sg in ipairs(beam:GetChildren()) do
		local t = sg:FindFirstChildWhichIsA("TextLabel")
		if t then t.Text = text end
	end
end
local function resetPlot(p)
	p.owner = nil
	p.owned, p.pending, p.jobs, p.on = {}, {}, {}, {}
	p.vault, p.income, p.bonus = 0, 0, 0
	for _, w in ipairs(p.workers) do if w.model then w.model:Destroy() end end
	p.workers = {}
	p.model.Built:ClearAllChildren()
	p.model.Buttons:ClearAllChildren()
	p.buttons = {}
	p.model:SetAttribute("Owner", 0)
	p.model:SetAttribute("Vault", 0)
	p.model:SetAttribute("Income", 0)
	setGate(p, "FREE PLOT")
end
for _, p in ipairs(P) do resetPlot(p) end

local function claim(plr)
	for _, p in ipairs(P) do
		if not p.owner then
			p.owner = plr
			p.model:SetAttribute("Owner", plr.UserId)
			plr:SetAttribute("Plot", p.i)
			setGate(p, string.upper(plr.DisplayName) .. "'S CITY")
			for _ = 1, T.StartWorkers do addWorker(p) end
			refreshButtons(p)
			return p
		end
	end
	return nil
end
local function plotOf(plr)
	for _, p in ipairs(P) do if p.owner == plr then return p end end
	return nil
end

-- players ----------------------------------------------------------------------------------------------------------
local function onCharacter(plr, char)
	local p = plotOf(plr)
	if not p then return end
	local hrp = char:WaitForChild("HumanoidRootPart", 5)
	if not hrp then return end
	task.wait(0.1)
	-- at the gate, on the avenue's sidewalk, looking into the plot
	local front = p.cf * at(0, 3, -8)
	char:PivotTo(CFrame.lookAt(front.Position, (p.cf * at(0, 3, 30)).Position))
	giveHammer(char, "rusty")
end
local function onPlayer(plr)
	S[plr] = { money = T.StartMoney }
	local ls = Instance.new("Folder")
	ls.Name = "leaderstats"
	local cash = Instance.new("IntValue")
	cash.Name = "Cash"
	cash.Parent = ls
	ls.Parent = plr
	setMoney(plr, T.StartMoney)
	claim(plr)
	plr.CharacterAdded:Connect(function(c) onCharacter(plr, c) end)
	if plr.Character then task.spawn(onCharacter, plr, plr.Character) end
end
Players.PlayerAdded:Connect(onPlayer)
for _, plr in ipairs(Players:GetPlayers()) do task.spawn(onPlayer, plr) end
Players.PlayerRemoving:Connect(function(plr)
	local p = plotOf(plr)
	if p then resetPlot(p) end
	S[plr] = nil
end)

-- taps: a hammer blow near one of your sites speeds it up
local lastTap = {}
TapRE.OnServerEvent:Connect(function(plr)
	local now = os.clock()
	if now - (lastTap[plr] or 0) < 0.15 then return end
	lastTap[plr] = now
	local p = plotOf(plr)
	local char = plr.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not p or not hrp then return end
	local best, bd
	for _, job in ipairs(p.jobs) do
		local d = (job.site.Position - hrp.Position).Magnitude
		if d < job.siteR + 26 and (not bd or d < bd) then best, bd = job, d end
	end
	if best then
		best.t += 0.05 * best.dur
		HitsRE:FireAllClients({ { hrp.Position + hrp.CFrame.LookVector * 3, 1, true } })
	end
end)

-- the loop: jobs advance, builders move, the vault fills, pads are stepped on -----------------------------------------
local hits = {}
local acc, accW, accV = 0, 0, 0
RunService.Heartbeat:Connect(function(dt)
	acc += dt
	accW += dt
	accV += dt
	-- jobs
	for _, p in ipairs(P) do
		local sp = speedOf(p)
		for k = #p.jobs, 1, -1 do
			local job = p.jobs[k]
			job.t += dt * sp
			local want = math.min(#job.stages, math.floor(job.t / job.dur * #job.stages) + 1)
			while job.done < want do
				job.done += 1
				job.stages[job.done]()
			end
			if job.t >= job.dur and job.done >= #job.stages then
				table.remove(p.jobs, k)
				task.delay(0.5, finish, p, job)
			end
		end
	end
	-- builders (5 times a second)
	if accW >= 0.2 then
		accW = 0
		local now = os.clock()
		for _, p in ipairs(P) do
			for i, w in ipairs(p.workers) do
				if w.root and w.model.Parent then
					local job = #p.jobs > 0 and p.jobs[(i - 1) % #p.jobs + 1] or nil
					local target, face
					if job then
						local n = #p.workers
						local a = (i - (n + 1) / 2) * 0.6
						local c = job.site
						-- in front of the site (its -Z side faces the street)
						local spot = c * CFrame.Angles(0, a, 0) * at(0, 3, -(job.siteR))
						target, face = spot.Position, c.Position
						target = Vector3.new(target.X, (p.cf * at(0, 3, 0)).Y, target.Z)
					else
						target, face = idleSpot(p, i), (p.cf * at(0, 3, 30)).Position
					end
					local pos = w.root.Position
					local flat = Vector3.new(target.X - pos.X, 0, target.Z - pos.Z)
					if flat.Magnitude > 3 then
						if flat.Magnitude > 90 or (w.walkSince and now - w.walkSince > 3) then
							w.model:PivotTo(CFrame.lookAt(target, Vector3.new(face.X, target.Y, face.Z)))
							w.walkSince = nil
						else
							w.walkSince = w.walkSince or now
							w.hum:MoveTo(target)
							play(w, "walk", 1.3)
						end
					else
						w.walkSince = nil
						w.root.CFrame = CFrame.lookAt(w.root.Position, Vector3.new(face.X, w.root.Position.Y, face.Z))
						if job then
							play(w, "work", 1.3)
							if now - (w.lastHit or 0) > 0.7 then
								w.lastHit = now
								local hand = w.model:FindFirstChild("RightHand")
								table.insert(hits, { (hand and hand.Position or pos) + (face - pos).Unit * 2, 1 })
							end
						else
							play(w, "idle", 1)
						end
					end
				end
			end
		end
		if #hits > 0 then
			HitsRE:FireAllClients(hits)
			hits = {}
		end
	end
	-- the vaults fill; the pads (10 times a second)
	if acc >= 0.1 then
		local step = acc
		acc = 0
		for _, p in ipairs(P) do
			local plr = p.owner
			if plr then
				p.vault += p.income * (1 + p.bonus) * step
				local char = plr.Character
				local hrp = char and char:FindFirstChild("HumanoidRootPart")
				if hrp then
					local rel = p.cf:PointToObjectSpace(hrp.Position)
					-- the vault pad
					local dv = Vector2.new(rel.X - T.VaultPad.x, rel.Z - T.VaultPad.z).Magnitude
					if dv < 4.2 and rel.Y < 8 and p.vault >= 1 then
						local amount = math.floor(p.vault)
						p.vault -= amount
						setMoney(plr, S[plr].money + amount)
						EventRE:FireClient(plr, "Collect", { amount = amount })
					end
					-- the buttons
					for id, btn in pairs(p.buttons) do
						local u = T.ById[id]
						local d = Vector2.new(rel.X - u.at[1], rel.Z - u.at[2]).Magnitude
						if d < 3.6 and rel.Y < 8 then
							if not p.on[id] then
								p.on[id] = true
								buy(p, u)
							end
						elseif d > 5 then
							p.on[id] = nil
						end
					end
				end
			end
		end
	end
	if accV >= 0.25 then
		accV = 0
		for _, p in ipairs(P) do
			if p.owner then p.model:SetAttribute("Vault", math.floor(p.vault)) end
		end
	end
end)

print("[Main3] BlockRise 3.0 prototype server ready")
