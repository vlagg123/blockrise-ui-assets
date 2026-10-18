-- BlockRise 2.0 - the crew: worker NPCs in hard hats, each with a real hammer from your inventory in hand
-- (EQUIP BEST: your best hammer is yours, the next ones go to the crew). Between orders they take a break on the
-- sidewalks of the first street; they walk to the site of the order being built, then swing; every swing sends a
-- spark (the hammer's rarity colour).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local C = require(ReplicatedStorage.Shared.Config2)
local Geo = require(ServerStorage.Build2.Geo)
local Hammers = require(ReplicatedStorage.Shared.Hammers)

local Crew = {}
local ctx
local crews = {} -- player -> { workers = { { model, hum, track, key, spot } }, k }
local hits = {} -- batched sparks: { pos, rarity }

local ANIM = { walk = "rbxassetid://507777826", idle = "rbxassetid://507766388", work = "rbxassetid://522635514",
	hold = "rbxassetid://507768375" } -- hold: Roblox's tool pose (the arm up, the hammer upright), over walk and idle
local SKIN = { Color3.fromRGB(255, 214, 180), Color3.fromRGB(234, 184, 146), Color3.fromRGB(198, 140, 100), Color3.fromRGB(150, 104, 72), Color3.fromRGB(104, 70, 50) }
local SHIRTS = { Color3.fromRGB(255, 150, 40), Color3.fromRGB(70, 150, 240), Color3.fromRGB(240, 80, 90), Color3.fromRGB(60, 190, 120), Color3.fromRGB(160, 110, 240), Color3.fromRGB(255, 200, 60) }

local function weld(part, base)
	local w = Instance.new("WeldConstraint")
	w.Part0 = base
	w.Part1 = part
	w.Parent = part
	part.Anchored = false
	part.CanCollide = false
	part.Massless = true
	part.CanQuery = false
	part.CanTouch = false
end

local function makeRig(i)
	local desc = Instance.new("HumanoidDescription")
	local skin = SKIN[(i * 3) % #SKIN + 1]
	desc.HeadColor = skin
	desc.LeftArmColor = skin
	desc.RightArmColor = skin
	desc.TorsoColor = SHIRTS[(i - 1) % #SHIRTS + 1]
	desc.LeftLegColor = Color3.fromRGB(44, 60, 110)
	desc.RightLegColor = Color3.fromRGB(44, 60, 110)
	local ok, model = pcall(function() return Players:CreateHumanoidModelFromDescription(desc, Enum.HumanoidRigType.R15) end)
	if not ok or not model then warn("Crew rig failed", model) return nil end
	local animate = model:FindFirstChild("Animate")
	if animate then animate:Destroy() end
	local head = model:FindFirstChild("Head")
	if head then
		local hat = Instance.new("Part")
		hat.Shape = Enum.PartType.Ball
		hat.Size = Vector3.one * head.Size.X * 1.12
		hat.Color = Color3.fromRGB(255, 206, 40)
		hat.Material = Enum.Material.SmoothPlastic
		hat.CFrame = head.CFrame * CFrame.new(0, head.Size.Y * 0.3, 0)
		hat.Name = "HardHat"
		hat.Parent = model
		weld(hat, head)
		local brim = Instance.new("Part")
		brim.Shape = Enum.PartType.Cylinder
		brim.Size = Vector3.new(0.14, head.Size.X * 1.55, head.Size.X * 1.55)
		brim.Color = hat.Color
		brim.Material = Enum.Material.SmoothPlastic
		brim.CFrame = head.CFrame * CFrame.new(0, head.Size.Y * 0.16, -0.1) * CFrame.Angles(0, 0, math.pi / 2)
		brim.Name = "Brim"
		brim.Parent = model
		weld(brim, head)
	end
	local torso = model:FindFirstChild("UpperTorso")
	if torso then
		for _, y in ipairs({ -0.2, 0.25 }) do
			local s = Instance.new("Part")
			s.Size = Vector3.new(torso.Size.X + 0.06, 0.16, torso.Size.Z + 0.06)
			s.Color = Color3.fromRGB(235, 255, 130)
			s.Material = Enum.Material.Neon
			s.CFrame = torso.CFrame * CFrame.new(0, y, 0)
			s.Name = "Stripe"
			s.Parent = model
			weld(s, torso)
		end
	end
	local hum = model:FindFirstChildOfClass("Humanoid")
	hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	hum.WalkSpeed = 18
	for _, s in ipairs({ Enum.HumanoidStateType.Climbing, Enum.HumanoidStateType.Swimming, Enum.HumanoidStateType.Seated,
		Enum.HumanoidStateType.Ragdoll, Enum.HumanoidStateType.FallingDown, Enum.HumanoidStateType.Flying,
		Enum.HumanoidStateType.PlatformStanding, Enum.HumanoidStateType.GettingUp }) do
		pcall(function() hum:SetStateEnabled(s, false) end)
	end
	hum.BreakJointsOnDeath = false
	hum.RequiresNeck = false
	for _, p in ipairs(model:GetDescendants()) do
		if p:IsA("BasePart") then p.CollisionGroup = "Workers" end
	end
	return model, hum
end

-- put a hammer (the key's model from ServerStorage.Hammers) in the worker's right hand. With the tool pose (the
-- "hold" animation) it rests tilted back over the shoulder (REST); a swing straightens it
local REST = CFrame.Angles(math.rad(35), 0, 0)
Crew.REST = REST
local function giveHammer(w, key)
	local old = w.model:FindFirstChild("HeldHammer")
	if old then old:Destroy() end
	w.key = key
	local h = Hammers.ById[key] or Hammers.ById.rusty
	local src = ServerStorage:FindFirstChild("Hammers") and ServerStorage.Hammers:FindFirstChild("Hammer_" .. (h.model or "1"))
	local hand = w.model:FindFirstChild("RightHand")
	if not src or not hand then return end
	local tool = src:Clone()
	local handle = tool:FindFirstChild("Handle")
	if not handle then tool:Destroy() return end
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
	local base = att and att.CFrame or CFrame.new(0, -0.3, 0)
	local target = hand.CFrame * base * REST * grip:Inverse()
	-- move the whole model so its handle lands in the grip (some models' pivots are not at their handle)
	m:PivotTo((target * handle.CFrame:Inverse()) * m:GetPivot())
	m.Parent = w.model
	-- a classic weld (its C0 can change): resting on the shoulder; upright while swinging (see play / the client)
	local wd = Instance.new("Weld")
	wd.Name = "GripWeld"
	wd.Part0 = hand
	wd.Part1 = handle
	wd.C0 = base * REST
	wd.C1 = grip
	wd:SetAttribute("Base", base)
	wd.Parent = handle
	w.grip = wd
end

-- the same for a player's character (their best hammer)
function Crew.GiveHammerTo(char, key)
	giveHammer({ model = char }, key)
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
	-- the hammer: held upright like a tool while walking or waiting; the swing takes the arm while working
	if not w.holdTrack then
		local a = Instance.new("Animation")
		a.AnimationId = ANIM.hold
		local ok, tr = pcall(function() return animator:LoadAnimation(a) end)
		if ok then
			tr.Looped = true
			tr.Priority = Enum.AnimationPriority.Action
			w.holdTrack = tr
		end
	end
	if w.holdTrack then
		if name == "work" then w.holdTrack:Stop(0.1) elseif not w.holdTrack.IsPlaying then w.holdTrack:Play(0.2) end
	end
	if w.grip and w.grip.Parent then
		local base = w.grip:GetAttribute("Base")
		if base then w.grip.C0 = name == "work" and base or base * REST end
	end
end

-- the crew of a player: as many workers as they have (at most C.MaxWorkersShown walk around)
function Crew.Sync(plr, st)
	local cr = crews[plr]
	if not cr then cr = { workers = {}, k = st.k } crews[plr] = cr end
	local n = math.min(C.MaxWorkersShown, ctx.workerCount(st))
	local keys = ctx.crewHammers(st) -- the hammer keys of workers 1..n
	local folder = workspace.World.Districts["D" .. st.k]:FindFirstChild("City") and workspace.World.Districts["D" .. st.k].City:FindFirstChild("Crew")
	if not folder then return end
	while #cr.workers > n do
		local w = table.remove(cr.workers)
		w.model:Destroy()
	end
	while #cr.workers < n do
		local i = #cr.workers + 1
		local model, hum = makeRig(i)
		if not model then break end
		model.Name = "Worker" .. i
		local yard = Geo.districtCF(st.k) * CFrame.new((i % 2 == 0) and 17 or -17, 3, 10 + ((i - 1) // 2) * 26)
		model:PivotTo(yard)
		model.Parent = folder
		local root = model:FindFirstChild("HumanoidRootPart")
		if root then pcall(function() root:SetNetworkOwner(nil) end) end
		table.insert(cr.workers, { model = model, hum = hum, root = root, i = i })
	end
	for i, w in ipairs(cr.workers) do
		if w.key ~= keys[i] then giveHammer(w, keys[i] or "rusty") end
	end
end

function Crew.Remove(plr)
	local cr = crews[plr]
	if not cr then return end
	for _, w in ipairs(cr.workers) do w.model:Destroy() end
	crews[plr] = nil
end

-- every 0.2 s: walk to the site / the yard, swing at the site
function Crew.Update(plr, st, dt)
	local cr = crews[plr]
	if not cr or not st.k then return end
	local o = st.data.City.queue[1]
	local n = #cr.workers
	local now = os.clock()
	for i, w in ipairs(cr.workers) do
		if not w.root or not w.model.Parent then continue end
		local target, face
		if o then
			-- a spot on a ring around the lot, in front of the building
			local lotCF = Geo.lotCF(st.k, o.lot)
			local a = math.pi + (i - (n + 1) / 2) * 0.5
			local r = 30 -- MAP v3: lots of 72
			target = (lotCF * CFrame.new(math.sin(a) * r, 3, math.cos(a) * r)).Position
			face = lotCF.Position
		else
			-- no order: they take a break on the sidewalks of the first street, each in their own spot, and now and
			-- then stroll to another one (a lane between the lamps and the trees); never a row in the road
			if not w.idleAt or now > (w.idleUntil or 0) or w.idleK ~= st.k then
				local rng = Random.new(i * 7919 + math.floor(now * 10))
				local side = (i % 2 == 0) and 1 or -1
				local x = side * rng:NextNumber(16.7, 17.3)
				local z = 10 + ((i - 1) // 2) * 26 + rng:NextNumber(0, 14)
				local base = Geo.districtCF(st.k)
				w.idleAt = (base * CFrame.new(x, 3, z)).Position
				w.idleFace = (base * CFrame.new(0, 3, z + rng:NextNumber(-12, 12))).Position
				w.idleUntil = now + rng:NextNumber(8, 16)
				w.idleK = st.k
			end
			target, face = w.idleAt, w.idleFace
		end
		local pos = w.root.Position
		local flat = Vector3.new(target.X - pos.X, 0, target.Z - pos.Z)
		if flat.Magnitude > 2.5 then
			-- far away (just joined, a new lot across the city): a short hop instead of a long walk
			if flat.Magnitude > 160 or (w.stuckSince and now - w.stuckSince > 6) then
				w.model:PivotTo(CFrame.lookAt(target, Vector3.new(face.X, target.Y, face.Z)))
				w.stuckSince = nil
			else
				w.hum:MoveTo(target)
				play(w, "walk", 1.2)
				if w.lastPos and (w.lastPos - pos).Magnitude < 0.3 then w.stuckSince = w.stuckSince or now else w.stuckSince = nil end
			end
		else
			w.stuckSince = nil
			w.root.CFrame = CFrame.lookAt(w.root.Position, Vector3.new(face.X, w.root.Position.Y, face.Z))
			if o and (o.demo or 0) <= 0 then
				play(w, "work", 1.25)
				if now - (w.lastHit or 0) > 0.8 then
					w.lastHit = now
					local hand = w.model:FindFirstChild("RightHand")
					local h = Hammers.ById[w.key or "rusty"]
					table.insert(hits, { (hand and hand.Position or pos) + (face - pos).Unit * 2, h and h.r or 1 })
				end
			else
				play(w, "idle", 1)
			end
		end
		w.lastPos = pos
	end
end

function Crew.Init(c)
	ctx = c
	local PhysicsService = game:GetService("PhysicsService")
	pcall(function() PhysicsService:RegisterCollisionGroup("Workers") end)
	pcall(function() PhysicsService:CollisionGroupSetCollidable("Workers", "Workers", false) end)
	local re = c.remote("RemoteEvent", "CrewHits")
	task.spawn(function()
		while true do
			task.wait(0.3)
			if #hits > 0 then
				local batch = hits
				hits = {}
				re:FireAllClients(batch)
			end
		end
	end)
end

return Crew
