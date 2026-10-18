-- BlockRise 2.0 (BUILD_V1, 2026-10-18): the live game's Construction, used by the City for every lot: the same
-- blueprints and stages, the job model goes into the lot (params.parent), the excavation's spoil pile is temporary
-- (Temp: ClearTemp takes it away at the end) and never part of a finished building.
-- A construction job built from stages. Stages are split into parallel TRACKS
-- (e.g. one per wall side) and consecutive stages that share a `group` run at the
-- same time (windows + doors + roof). Workers on different tracks work in parallel.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PhysicsService = game:GetService("PhysicsService")
local Blueprints = require(script.Parent.Blueprints2)

local Construction = {}
Construction.__index = Construction
Construction.Active = {}

-- collision groups: NPC workers never get trapped inside building pieces
pcall(function() PhysicsService:RegisterCollisionGroup("Build") end)
pcall(function() PhysicsService:RegisterCollisionGroup("Workers") end)
pcall(function()
	PhysicsService:CollisionGroupSetCollidable("Workers", "Build", false)
	PhysicsService:CollisionGroupSetCollidable("Workers", "Workers", false)
end)

local buildFolder = workspace:FindFirstChild("Constructions") or Instance.new("Folder")
buildFolder.Name = "Constructions"
buildFolder.Parent = workspace
local stateFolder = ReplicatedStorage:FindFirstChild("Jobs") or Instance.new("Folder")
stateFolder.Name = "Jobs"
stateFolder.Parent = ReplicatedStorage

local CURED = Blueprints.Colors.concrete
local SIDE_NAME = { front = "front", back = "back", left = "left side", right = "right side" }

local function makePart(spec, originCF, parent, animate)
	local p = Instance.new(spec.shape == "Wedge" and "WedgePart" or "Part")
	if spec.shape == "Ball" then p.Shape = Enum.PartType.Ball end
	if spec.shape == "Cylinder" then p.Shape = Enum.PartType.Cylinder end -- (ZONE_CHAIN: columns, poles, discs)
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Size = spec.s
	p.CFrame = originCF * spec.c
	p.Material = spec.m
	if spec.v then p.MaterialVariant = spec.v end
	p.Color = spec.col
	p.Transparency = spec.t or 0
	-- blueprint themes: Gold Blueprint = a shining golden building, Diamond Blueprint = a glass building
	local theme = parent and parent:GetAttribute("Theme")
	-- THEME_FULL: the gable triangles (wedges that rise) and concrete walls / roofs too; floors and slabs stay
	if theme and not spec.concrete and (spec.anim ~= "rise" or spec.shape == "Wedge") then
		local m = spec.m
		if m == Enum.Material.Brick or m == Enum.Material.Plaster or m == Enum.Material.Metal or m == Enum.Material.WoodPlanks
			or m == Enum.Material.RoofShingles or m == Enum.Material.Wood or m == Enum.Material.SmoothPlastic
			or (m == Enum.Material.Concrete and spec.anim ~= "rise") then
			p.MaterialVariant = ""
			if theme == "gold" then
				p.Material = Enum.Material.Foil
				p.Color = (m == Enum.Material.SmoothPlastic) and Color3.fromRGB(255, 236, 170) or Color3.fromRGB(255, 196, 60)
			elseif theme == "glass" then
				p.Material = Enum.Material.Glass
				p.Color = (m == Enum.Material.SmoothPlastic) and Color3.fromRGB(230, 245, 255) or Color3.fromRGB(130, 210, 255)
				p.Transparency = math.max(p.Transparency, (m == Enum.Material.SmoothPlastic) and 0 or 0.3)
			end
		end
	end
	p.CanCollide = not spec.noCollide
	-- walls/roofs: workers may pass through them; floors (slabs, porch, driveway) stay solid for everyone
	if not (spec.concrete or spec.anim == "rise") then p.CollisionGroup = "Build" end
	if spec.light then
		local l = Instance.new("PointLight")
		l.Range = 14; l.Brightness = 1.2; l.Color = Color3.fromRGB(255, 220, 170)
		l.Parent = p
	end
	if spec.concrete then p:SetAttribute("Concrete", true) end
	-- 2.0: words on a sign (its front face)
	if spec.text then
		local sg = Instance.new("SurfaceGui")
		sg.Face = spec.face or Enum.NormalId.Front
		sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		sg.PixelsPerStud = 30
		sg.MaxDistance = 600
		sg.LightInfluence = (spec.m == Enum.Material.Neon) and 0 or 0.6
		local t = Instance.new("TextLabel")
		t.BackgroundTransparency = 1
		t.Size = UDim2.fromScale(1, 1)
		t.Font = spec.font or Enum.Font.GothamBlack
		t.TextScaled = true
		t.TextColor3 = spec.textCol or Color3.new(1, 1, 1)
		t.Text = spec.text
		local pad = Instance.new("UIPadding")
		pad.PaddingTop = UDim.new(0.12, 0) pad.PaddingBottom = UDim.new(0.12, 0) pad.PaddingLeft = UDim.new(0.05, 0) pad.PaddingRight = UDim.new(0.05, 0)
		pad.Parent = t
		t.Parent = sg
		sg.Parent = p
	end
	if animate then p:SetAttribute("Anim", spec.anim or "drop") end
	p.Parent = parent
	return p
end

local function removePart(p)
	if not p or not p.Parent then return end
	p.CanCollide = false
	p:SetAttribute("Remove", true)
	task.delay(0.7, function() if p then p:Destroy() end end)
end

-- split a stage's pieces into parallel tracks (by wall side when the stage asks for it,
-- or by quarter of the lot for clearing/digging)
local function splitTracks(stage)
	local adds = stage.adds or {}
	local removes = stage.removes or {}
	if stage.split and #removes > 0 and not stage.removesExisting then
		local order, byQ = {}, {}
		for _, spec in ipairs(removes) do
			local p = spec.c.Position
			local q = (p.X >= 0 and "E" or "W") .. (p.Z >= 0 and "S" or "N")
			if not byQ[q] then byQ[q] = {}; table.insert(order, q) end
			table.insert(byQ[q], spec)
		end
		local tracks = {}
		for _, q in ipairs(order) do
			table.insert(tracks, { side = "zone", removeSpecs = byQ[q], adds = {}, work = stage.work * #byQ[q] / #removes })
		end
		-- things that appear (the spoil pile) are shared between the zones
		for i, spec in ipairs(adds) do table.insert(tracks[(i - 1) % #tracks + 1].adds, spec) end
		return tracks
	end
	if stage.split and #adds > 0 then
		local order, bySide = {}, {}
		for _, spec in ipairs(adds) do
			local s = spec.side or "other"
			if not bySide[s] then bySide[s] = {}; table.insert(order, s) end
			table.insert(bySide[s], spec)
		end
		if #order > 1 then
			local tracks = {}
			for _, s in ipairs(order) do
				table.insert(tracks, { side = s, adds = bySide[s], work = stage.work * #bySide[s] / #adds })
			end
			return tracks
		end
	end
	return { { side = "all", adds = adds, work = stage.work } }
end

local function flatDist(a, b) return Vector2.new(a.X - b.X, a.Z - b.Z).Magnitude end

-- params: id, kind, ownerId, title, blueprint, blueprintArg, origin, radius, existing, instant, meta, onStage, onComplete
function Construction.new(params)
	local self = setmetatable({}, Construction)
	self.id = params.id
	self.kind = params.kind
	self.ownerId = params.ownerId
	self.title = params.title
	self.origin = params.origin
	self.radius = params.radius or 50
	self.onStage = params.onStage
	self.onComplete = params.onComplete
	self.meta = params.meta or {}
	local stages, info = Blueprints[params.blueprint](params.blueprintArg)
	-- bigger contract tiers reuse a blueprint with much more work to do
	local wm = tonumber(params.workMult) or 1
	if wm ~= 1 and wm > 0 then
		for _, s in ipairs(stages) do s.work = s.work * wm end
	end
	self.stages = stages
	self.size = info.size
	self.totalWork = 0
	for _, s in ipairs(stages) do self.totalWork += s.work end
	self.doneWork = 0
	self.startTime = os.clock()

	self.model = Instance.new("Model")
	self.model.Name = params.id
	self.model:SetAttribute("JobId", params.id)
	if params.theme then self.model:SetAttribute("Theme", params.theme) end
	self.model.Parent = params.parent or buildFolder

	if params.instant then
		for _, st in ipairs(stages) do
			for _, spec in ipairs(st.key ~= "dig" and st.adds or {}) do
				local p = makePart(spec, self.origin, self.model, false)
				if spec.concrete then p.Color = CURED end
			end
		end
		self.done = true
		return self
	end

	-- tracks per stage; removals live in a single track
	self.tracks = {}
	self.contrib = {}
	for i, st in ipairs(stages) do
		local list = splitTracks(st)
		for _, tr in ipairs(list) do
			tr.stage = i
			tr.progress = 0
			tr.revealed = 0
			tr.removed = 0
			tr.removeParts = {}
			tr.label = st.name .. ((tr.side ~= "all" and SIDE_NAME[tr.side]) and (" (" .. SIDE_NAME[tr.side] .. ")") or "")
			tr.zone = tr.side == "zone"
		end
		-- pre-spawn removable things (debris, topsoil, the old building)
		local rem = list[1].removeParts
		if list[1].removeSpecs then
			for _, tr in ipairs(list) do
				for _, spec in ipairs(tr.removeSpecs) do table.insert(tr.removeParts, makePart(spec, self.origin, self.model, false)) end
				-- dig from the outside of each zone towards the middle
				table.sort(tr.removeParts, function(a, b)
					return (a.Position - self.origin.Position).Magnitude > (b.Position - self.origin.Position).Magnitude
				end)
			end
		elseif st.removesExisting and params.existing then
			for _, d in ipairs(params.existing:GetDescendants()) do
				if d:IsA("BasePart") then table.insert(rem, d) end
			end
			table.sort(rem, function(a, b) return a.Position.Y > b.Position.Y end)
			self.existing = params.existing
		elseif st.removes and not list[1].removeSpecs then
			for _, spec in ipairs(st.removes) do table.insert(rem, makePart(spec, self.origin, self.model, false)) end
		end
		-- track centres (where workers stand)
		for _, tr in ipairs(list) do
			local sum, n = Vector3.zero, 0
			for _, spec in ipairs(tr.adds) do sum += (self.origin * spec.c).Position; n += 1 end
			for _, p in ipairs(tr.removeParts) do sum += p.Position; n += 1 end
			tr.center = n > 0 and (sum / n) or self.origin.Position
		end
		self.tracks[i] = list
		self.contrib[i] = {}
	end

	-- groups of stages that run at the same time
	self.groups = {}
	for i, st in ipairs(stages) do
		local last = self.groups[#self.groups]
		if st.group and last and stages[last[#last]].group == st.group then
			table.insert(last, i)
		else
			table.insert(self.groups, { i })
		end
	end
	self.groupIndex = 1
	self.stageIndex = 1

	self.state = Instance.new("Folder")
	self.state.Name = params.id
	self.state:SetAttribute("Owner", params.ownerId)
	self.state:SetAttribute("Kind", params.kind)
	self.state:SetAttribute("Title", params.title)
	self.state:SetAttribute("Center", self.origin.Position)
	self.state:SetAttribute("Radius", self.radius)
	self.state:SetAttribute("StageCount", #self.groups)
	self.state:SetAttribute("Reward", params.meta and params.meta.reward or 0)
	self.state:SetAttribute("TargetTime", params.meta and params.meta.targetTime or 0)
	self.state:SetAttribute("StartTime", workspace:GetServerTimeNow())
	self:_publish()
	self.state.Parent = stateFolder

	Construction.Active[self.id] = self
	return self
end

-- tracks that can be worked on right now
function Construction:ActiveTracks()
	local out = {}
	if self.done or not self.groups then return out end
	local g = self.groups[self.groupIndex]
	if not g then return out end
	for _, si in ipairs(g) do
		for _, tr in ipairs(self.tracks[si]) do
			if not tr.done then table.insert(out, tr) end
		end
	end
	return out
end

function Construction:CurrentStage()
	return self.stages[self.stageIndex]
end

local function trackFrac(tr) return tr.work > 0 and tr.progress / tr.work or 1 end

function Construction:_leastTrack(active)
	local best, bf
	for _, tr in ipairs(active) do
		local f = trackFrac(tr)
		if not best or f < bf then best, bf = tr, f end
	end
	return best
end

function Construction:_trackPoint(tr)
	local rp = tr.removeParts[tr.removed + 1]
	if rp and rp.Parent then return rp.Position end
	local spec = tr.adds[tr.revealed + 1]
	if spec then return (self.origin * spec.c).Position end
	return tr.center
end

function Construction:TrackPoint(tr)
	return self:_trackPoint(tr)
end

function Construction:_nextPoint()
	local tr = self:_leastTrack(self:ActiveTracks())
	return tr and self:_trackPoint(tr) or self.origin.Position
end

function Construction:_publish()
	local s = self.state
	if not s then return end
	local g = self.groups[self.groupIndex]
	local names, tasks = {}, {}
	local gw, gp = 0, 0
	if g then
		for _, si in ipairs(g) do
			local st = self.stages[si]
			local stageDone = true
			for _, tr in ipairs(self.tracks[si]) do
				gw += tr.work; gp += tr.progress
				if not tr.done then stageDone = false end
			end
			if not stageDone then table.insert(names, st.name); table.insert(tasks, st.task) end
		end
	end
	local active = #self:ActiveTracks()
	local partial = 0
	for i, st in ipairs(self.stages) do
		if not st._completed then for _, tr in ipairs(self.tracks[i]) do partial += tr.progress end end
	end
	local cur = self:CurrentStage()
	s:SetAttribute("Stage", math.min(self.groupIndex, #self.groups))
	s:SetAttribute("StageName", #names > 0 and table.concat(names, " + ") or "Complete")
	s:SetAttribute("Task", #tasks > 0 and (tasks[1] .. (active > 1 and ("  ·  " .. active .. " tasks in parallel") or "")) or "Done!")
	s:SetAttribute("Verb", cur and cur.verb or "hammer")
	s:SetAttribute("StageProgress", gw > 0 and math.clamp(gp / gw, 0, 1) or 1)
	s:SetAttribute("Total", math.clamp((self.doneWork + partial) / self.totalWork, 0, 1))
	s:SetAttribute("WorkPoint", self:_nextPoint())
	s:SetAttribute("Tracks", active)
	s:SetAttribute("Done", self.done == true)
end

function Construction:_revealTrack(tr)
	local lastPos
	local frac = math.clamp(trackFrac(tr), 0, 1)
	local target = tr.done and #tr.adds or math.floor(frac * #tr.adds + 1e-6)
	while tr.revealed < target do
		tr.revealed += 1
		local p = makePart(tr.adds[tr.revealed], self.origin, self.model, true)
		if self.stages[tr.stage].key == "dig" then p:SetAttribute("Temp", true) end
		lastPos = p.Position
	end
	local rtarget = tr.done and #tr.removeParts or math.floor(frac * #tr.removeParts + 1e-6)
	while tr.removed < rtarget do
		tr.removed += 1
		local p = tr.removeParts[tr.removed]
		if p and p.Parent then lastPos = p.Position; removePart(p) end
	end
	return lastPos
end

function Construction:_cure()
	local parts = {}
	for _, p in ipairs(self.model:GetChildren()) do
		if p:GetAttribute("Concrete") and not p:GetAttribute("Cured") then
			p:SetAttribute("Cured", true)
			table.insert(parts, { p, p.Color })
		end
	end
	task.spawn(function()
		for i = 1, 12 do
			task.wait(0.25)
			for _, e in ipairs(parts) do
				if e[1].Parent then e[1].Color = e[2]:Lerp(CURED, i / 12) end
			end
		end
	end)
end

function Construction:_checkStage(si)
	local st = self.stages[si]
	if st._completed then return end
	for _, tr in ipairs(self.tracks[si]) do if not tr.done then return end end
	st._completed = true
	self.doneWork += st.work
	if st.cure then self:_cure() end
	if st.removesExisting and self.existing then
		local ex = self.existing
		self.existing = nil
		task.delay(1, function() if ex then ex:Destroy() end end)
	end
	local contrib = self.contrib[si]
	self.contrib[si] = {}
	-- group finished?
	local g = self.groups[self.groupIndex]
	local groupDone = true
	for _, gi in ipairs(g) do if not self.stages[gi]._completed then groupDone = false end end
	if groupDone then
		self.groupIndex += 1
		if self.groupIndex > #self.groups then
			self.done = true
			self.elapsed = os.clock() - self.startTime
			if self.supplyModel then self.supplyModel:Destroy(); self.supplyModel = nil end
			if self.craneModel then self.craneModel:Destroy(); self.craneModel = nil end
		end
	end
	-- current stage = first unfinished stage of the active group
	local ng = self.groups[self.groupIndex]
	if ng then
		for _, gi in ipairs(ng) do if not self.stages[gi]._completed then self.stageIndex = gi break end end
	else
		self.stageIndex = #self.stages + 1
	end
	if self.onStage then task.spawn(self.onStage, self, si, contrib) end
	if self.done and self.onComplete then task.spawn(self.onComplete, self) end
end

-- Adds work. opts.track targets a specific track; opts.pos picks the nearest track.
-- Extra work spills over to other active tracks so nothing is wasted.
function Construction:AddWork(amount, contributorId, opts)
	if self.done or self.destroyed or not self.tracks then return 0 end
	local active = self:ActiveTracks()
	if #active == 0 then return 0 end
	local tr = opts and opts.track
	if tr and (tr.done or not table.find(active, tr)) then tr = nil end
	if not tr and opts and opts.pos then
		local bd
		for _, t in ipairs(active) do
			local d = flatDist(t.center, opts.pos)
			if not bd or d < bd then tr, bd = t, d end
		end
	end
	tr = tr or self:_leastTrack(active)
	local remaining, applied, lastPos = amount, 0, nil
	local guard = 0
	while tr and remaining > 1e-6 and guard < 20 do
		guard += 1
		local use = math.min(tr.work - tr.progress, remaining)
		tr.progress += use
		remaining -= use
		applied += use
		local c = self.contrib[tr.stage]
		if contributorId and c then c[contributorId] = (c[contributorId] or 0) + use end
		if tr.progress >= tr.work - 1e-6 then tr.done = true end
		lastPos = self:_revealTrack(tr) or lastPos
		if tr.done then self:_checkStage(tr.stage) end
		if self.done then break end
		tr = remaining > 1e-6 and self:_leastTrack(self:ActiveTracks()) or nil
	end
	self:_publish()
	return applied, lastPos or self:_nextPoint()
end

function Construction:Center()
	return self.origin.Position + Vector3.new(0, (self.size and self.size.Y or 10) / 2, 0)
end

function Construction:Release()
	Construction.Active[self.id] = nil
	if self.supplyModel then self.supplyModel:Destroy(); self.supplyModel = nil end
	if self.craneModel then self.craneModel:Destroy(); self.craneModel = nil end
	if self.state then self.state:Destroy(); self.state = nil end
end

function Construction:Destroy(animated)
	if self.destroyed then return end
	self.destroyed = true
	Construction.Active[self.id] = nil
	if self.supplyModel then self.supplyModel:Destroy(); self.supplyModel = nil end
	if self.craneModel then self.craneModel:Destroy(); self.craneModel = nil end
	if self.state then self.state:Destroy(); self.state = nil end
	if self.model then
		if animated then
			local m = self.model
			local parts = m:GetChildren()
			table.sort(parts, function(a, b)
				local ay = a:IsA("BasePart") and a.Position.Y or 0
				local by = b:IsA("BasePart") and b.Position.Y or 0
				return ay > by
			end)
			task.spawn(function()
				local n = #parts
				for i, p in ipairs(parts) do
					if p:IsA("BasePart") then removePart(p) end
					if i % math.max(1, math.floor(n / 40)) == 0 then task.wait(0.05) end
				end
				task.wait(1)
				m:Destroy()
			end)
		else
			self.model:Destroy()
		end
		self.model = nil
	end
end

-- TELEPORT_FIX (2026-10-13) ---------------------------------------------------------------------------------------------
-- Where a builder is put when the game takes them to their site (the first job, GO to the site, the rookie trip): in
-- FRONT of the plot (the side the site's origin looks at: the road), a few steps outside everything the building will
-- ever have, on the ground, with room to stand. Before, the spot was a few steps from the work point, often on the
-- slab: the walls came up around you, pushed you through the ground and you fell under the map.
-- Returns the ground point to stand on and the point to look at.
function Construction:StandPoint()
	local o = self.origin
	local minZ = 0
	local function addSpec(spec)
		if not (spec and spec.c and spec.s) then return end
		local h = spec.s / 2
		for _, sx in ipairs({ -1, 1 }) do
			for _, sy in ipairs({ -1, 1 }) do
				for _, sz in ipairs({ -1, 1 }) do
					local p = spec.c * Vector3.new(h.X * sx, h.Y * sy, h.Z * sz)
					if p.Z < minZ then minZ = p.Z end
				end
			end
		end
	end
	for _, st in ipairs(self.stages or {}) do
		for _, spec in ipairs(st.adds or {}) do addSpec(spec) end
		for _, spec in ipairs(st.removes or {}) do addSpec(spec) end
	end
	local skip = { buildFolder }
	for _, p in ipairs(game:GetService("Players"):GetPlayers()) do
		if p.Character then table.insert(skip, p.Character) end
	end
	local ray = RaycastParams.new()
	ray.FilterType = Enum.RaycastFilterType.Exclude
	ray.FilterDescendantsInstances = skip
	local ov = OverlapParams.new()
	ov.FilterType = Enum.RaycastFilterType.Exclude
	ov.FilterDescendantsInstances = skip
	local maxD = math.max(10, (self.radius or 50) - 3)
	local look = o.Position
	local fallback
	for _, extra in ipairs({ 8, 11, 14, 5 }) do
		local d = math.min(-minZ + extra, maxD)
		for _, side in ipairs({ 0, 5, -5, 10, -10 }) do
			local w = o * Vector3.new(side, 0, -d)
			local hit = workspace:Raycast(Vector3.new(w.X, o.Y + 40, w.Z), Vector3.new(0, -80, 0), ray)
			if hit and hit.Position.Y > o.Y - 3 and hit.Position.Y < o.Y + 3 then
				fallback = fallback or hit.Position
				local free = true
				for _, p in ipairs(workspace:GetPartBoundsInBox(CFrame.new(hit.Position + Vector3.new(0, 3.3, 0)), Vector3.new(3, 5, 3), ov)) do
					local m = p:FindFirstAncestorOfClass("Model")
					if p.CanCollide and not (m and m:FindFirstChildOfClass("Humanoid")) then free = false break end
				end
				if free then return hit.Position, look end
			end
		end
	end
	return fallback or (o * Vector3.new(0, 0, -math.min(-minZ + 8, maxD))), look
end

-- 2.0: the temporary things (the spoil pile) go away; the finished model stays where it is
function Construction:ClearTemp()
	if not self.model then return end
	for _, p in ipairs(self.model:GetChildren()) do
		if p:IsA("BasePart") and p:GetAttribute("Temp") then removePart(p) end
	end
end
-- 2.0: a finished building taken down piece by piece from the top (an upgrade replaces it)
function Construction.Demolish(model, seconds)
	if not model then return end
	local parts = {}
	for _, p in ipairs(model:GetDescendants()) do if p:IsA("BasePart") then table.insert(parts, p) end end
	table.sort(parts, function(a, b) return a.Position.Y > b.Position.Y end)
	local n = #parts
	local batches = 30
	task.spawn(function()
		for i, p in ipairs(parts) do
			removePart(p)
			if i % math.max(1, math.ceil(n / batches)) == 0 then task.wait((seconds or 1.5) / batches) end
		end
		task.wait(0.8)
		model:Destroy()
	end)
end

return Construction
