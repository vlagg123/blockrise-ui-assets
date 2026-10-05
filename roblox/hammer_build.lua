-- BlockRise Empire - hammer builder (run in Edit, one call per hammer): builds the in-hand hammer Tool templates into
-- ServerStorage.Hammers from hammers/spec.json (the same spec the Blender icons are rendered from).
--   _G.__HB = { tiers = {1, 2, ...}, url = "<raw spec.json>", preview = Vector3 or nil }
-- Tool space: origin = the hand (Handle, Grip = identity), +Y up the handle, -Z = the striking face.
-- Every piece is a Part (box / cylinder / ball) or a ring; "planes" cut it with CSG (bevels, facets, gem points, spikes).
local HS = game:GetService("HttpService")
local SS = game:GetService("ServerStorage")
local args = _G.__HB or {}

local spec = _G.__HB_SPEC
if not spec or args.reload then
	local was = HS.HttpEnabled
	HS.HttpEnabled = true
	local ok, body = pcall(function() return HS:GetAsync(args.url) end)
	HS.HttpEnabled = was
	assert(ok, body)
	spec = HS:JSONDecode(body)
	_G.__HB_SPEC = spec
end

local folder = SS:FindFirstChild("Hammers") or Instance.new("Folder")
folder.Name = "Hammers"
folder.Parent = SS

local CUT = 6 -- size of the cutting blocks (bigger than any piece)
local S = spec.scale or 1 -- the spec is drawn at this scale in Roblox
local GALAXY = args.galaxy or "" -- tiling space texture for the Galaxy core

local function frameOf(p)
	local R = p.R
	return CFrame.new(p.pos[1] * S, p.pos[2] * S, p.pos[3] * S, R[1][1], R[1][2], R[1][3], R[2][1], R[2][2], R[2][3], R[3][1], R[3][2], R[3][3])
end

local function look(center, n)
	local up = math.abs(n.Y) > 0.95 and Vector3.new(1, 0, 0) or Vector3.new(0, 1, 0)
	return CFrame.lookAt(center, center + n, up)
end

local function base(shape, size, cf)
	local p = Instance.new("Part")
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Anchored = true
	if shape == "cyl" then
		p.Shape = Enum.PartType.Cylinder
		p.Size = Vector3.new(size[1] * S, size[2] * 2 * S, size[2] * 2 * S)
		p.CFrame = cf * CFrame.Angles(0, 0, math.pi / 2) -- the part's X axis becomes the spec's Y axis
	elseif shape == "ball" then
		p.Shape = Enum.PartType.Ball
		p.Size = Vector3.one * size[1] * S
		p.CFrame = cf
	else
		p.Size = Vector3.new(size[1] * S, size[2] * S, size[3] * S)
		p.CFrame = cf
	end
	return p
end

local function finishPart(p, mat, pal)
	local m = pal.rbx
	p.Material = Enum.Material[m[1]]
	p.Color = Color3.fromRGB(m[2][1], m[2][2], m[2][3])
	p.Transparency = m[3] or 0
	p.Reflectance = m[4] or 0
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	if p:IsA("UnionOperation") then
		p.UsePartColor = true
		p.RenderFidelity = Enum.RenderFidelity.Precise
		p.CollisionFidelity = Enum.CollisionFidelity.Box
	end
end

local function buildPiece(piece, origin, parent, palette)
	local F = origin * frameOf(piece)
	local part
	if piece.shape == "ring" then
		local t, ro, ri = piece.size[1], piece.size[2], piece.size[3]
		local outer = base("cyl", { t, ro }, F)
		local inner = base("cyl", { t + 0.2, ri }, F)
		outer.Parent = workspace
		inner.Parent = workspace
		local ok, u = pcall(function() return outer:SubtractAsync({ inner }) end)
		outer:Destroy()
		inner:Destroy()
		assert(ok, "ring: " .. tostring(u))
		part = u
	else
		part = base(piece.shape, piece.size, F)
	end
	if #piece.planes > 0 then
		local cutters = {}
		for _, pl in ipairs(piece.planes) do
			local n = Vector3.new(pl[1], pl[2], pl[3])
			local center = n * (pl[4] * S + CUT / 2)
			local c = Instance.new("Part")
			c.Anchored = true
			c.Size = Vector3.one * CUT
			c.CFrame = F * look(center, n)
			c.Parent = workspace
			table.insert(cutters, c)
		end
		part.Parent = workspace
		local ok, u = pcall(function() return part:SubtractAsync(cutters) end)
		for _, c in ipairs(cutters) do c:Destroy() end
		part:Destroy()
		assert(ok, piece.name .. ": " .. tostring(u))
		part = u
	end
	part.Name = piece.name
	finishPart(part, piece.mat, palette[piece.mat])
	if part:IsA("UnionOperation") and (piece.smooth or 0) > 0 then part.SmoothingAngle = piece.smooth end
	part.CastShadow = piece.cast ~= false
	part.Parent = parent
	return part
end

local function color(c) return Color3.fromRGB(c[1], c[2], c[3]) end
local function colorSeq(list)
	if #list == 1 then return ColorSequence.new(color(list[1])) end
	local kp = {}
	for i, c in ipairs(list) do table.insert(kp, ColorSequenceKeypoint.new((i - 1) / (#list - 1), color(c))) end
	return ColorSequence.new(kp)
end

-- particle looks per effect kind
local SPARK = "rbxasset://textures/particles/sparkles_main.dds"
local FIRE = "rbxasset://textures/particles/fire_main.dds"
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"
local FX = {
	flakes = { tex = SMOKE, life = { 0.6, 1.0 }, speed = { 0.2, 0.6 }, accel = Vector3.new(0, -6, 0), light = 0, spread = 180, rot = true, trans = { 0, 1 } },
	glint = { tex = SPARK, life = { 0.25, 0.45 }, speed = { 0, 0.2 }, light = 1, spread = 0, trans = { 0.1, 1 }, grow = true },
	sparkle = { tex = SPARK, life = { 0.4, 0.8 }, speed = { 0.2, 0.6 }, light = 1, spread = 180, trans = { 0, 1 }, grow = true },
	rise = { tex = SPARK, life = { 0.8, 1.4 }, speed = { 0.6, 1.2 }, accel = Vector3.new(0, 1.5, 0), light = 1, spread = 25, trans = { 0.2, 1 } },
	embers = { tex = SPARK, life = { 0.6, 1.2 }, speed = { 1, 2.5 }, accel = Vector3.new(0, 3, 0), light = 1, spread = 35, trans = { 0, 1 }, emit = Vector3.new(0, 1, 0) },
	smoke = { tex = SMOKE, life = { 1.2, 2 }, speed = { 0.5, 1.2 }, accel = Vector3.new(0, 1, 0), light = 0, spread = 25, trans = { 0.55, 1 }, emit = Vector3.new(0, 1, 0), rot = true },
	snow = { tex = SPARK, life = { 0.8, 1.4 }, speed = { 0.2, 0.6 }, accel = Vector3.new(0, -2.5, 0), light = 0.6, spread = 180, trans = { 0, 1 } },
	mist = { tex = SMOKE, life = { 1, 1.6 }, speed = { 0.1, 0.4 }, light = 0.3, spread = 180, trans = { 0.65, 1 }, rot = true },
	rainbow = { tex = SPARK, life = { 0.4, 0.8 }, speed = { 0.3, 0.8 }, light = 1, spread = 180, trans = { 0, 1 }, grow = true },
	sparks = { tex = SPARK, life = { 0.15, 0.35 }, speed = { 3, 6 }, light = 1, spread = 180, trans = { 0, 1 }, drag = 6 },
	fire = { tex = FIRE, life = { 0.35, 0.7 }, speed = { 0.4, 1.2 }, accel = Vector3.new(0, 2, 0), light = 1, spread = 180, trans = { 0.1, 1 }, rot = true },
	stars = { tex = SPARK, life = { 0.6, 1.2 }, speed = { 0.2, 0.7 }, light = 1, spread = 180, trans = { 0, 1 }, grow = true },
}

local function addFx(tool, handle, h)
	for i, f in ipairs(h.fx or {}) do
		local look = FX[f.kind] or FX.sparkle
		local a = Instance.new("Attachment")
		a.Name = "FX_" .. f.kind
		a.Position = Vector3.new(f.pos[1], f.pos[2], f.pos[3]) * S
		a.Parent = handle
		local pe = Instance.new("ParticleEmitter")
		pe.Name = "FX"
		pe.Texture = look.tex
		pe.Color = colorSeq(f.colors)
		pe.Rate = f.rate
		pe.Lifetime = NumberRange.new(look.life[1], look.life[2])
		pe.Speed = NumberRange.new(look.speed[1], look.speed[2])
		pe.SpreadAngle = Vector2.new(look.spread, look.spread)
		pe.Acceleration = look.accel or Vector3.zero
		pe.Drag = look.drag or 0
		pe.LightEmission = look.light
		pe.LightInfluence = 0
		pe.EmissionDirection = Enum.NormalId.Top
		pe.Shape = Enum.ParticleEmitterShape.Box
		pe.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
		pe.Parent = a
		-- the emitter box covers the hammer head
		a:SetAttribute("Area", Vector3.new(f.area[1], f.area[2], f.area[3]))
		local s0, s1 = f.size[1], f.size[2]
		if look.grow then
			pe.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.35, s1), NumberSequenceKeypoint.new(1, 0) })
		else
			pe.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, s0), NumberSequenceKeypoint.new(1, s1 * 0.6) })
		end
		pe.Transparency = NumberSequence.new(look.trans[1], look.trans[2])
		if look.rot then pe.Rotation = NumberRange.new(0, 360); pe.RotSpeed = NumberRange.new(-60, 60) end
		pe.LockedToPart = false
		-- the emitter shape is the attachment's parent part: use a small invisible box part for the area
		local box = Instance.new("Part")
		box.Name = "FXArea_" .. i
		box.Size = Vector3.new(math.max(0.05, f.area[1]), math.max(0.05, f.area[2]), math.max(0.05, f.area[3])) * S
		box.CFrame = handle.CFrame * CFrame.new(a.Position)
		box.Transparency = 1
		box.CanCollide = false; box.CanQuery = false; box.CanTouch = false; box.Massless = true; box.Anchored = true
		box.CastShadow = false
		box.Parent = tool
		local w = Instance.new("WeldConstraint"); w.Part0 = handle; w.Part1 = box; w.Parent = box
		pe.Parent = box
		a:Destroy()
	end
	if h.light then
		local a = Instance.new("Attachment")
		a.Name = "LightAt"
		a.Position = Vector3.new(h.light.pos[1], h.light.pos[2], h.light.pos[3]) * S
		a.Parent = handle
		local l = Instance.new("PointLight")
		l.Color = color(h.light.color)
		l.Brightness = h.light.brightness * 0.7
		l.Range = h.light.range
		l.Shadows = false
		l.Parent = a
	end
	if h.trail then
		local a0 = Instance.new("Attachment"); a0.Name = "TrailTop"; a0.Position = Vector3.new(h.trail.top[1], h.trail.top[2], h.trail.top[3]) * S; a0.Parent = handle
		local a1 = Instance.new("Attachment"); a1.Name = "TrailBottom"; a1.Position = Vector3.new(h.trail.bottom[1], h.trail.bottom[2], h.trail.bottom[3]) * S; a1.Parent = handle
		local tr = Instance.new("Trail")
		tr.Attachment0 = a0; tr.Attachment1 = a1
		tr.Color = colorSeq(h.trail.colors)
		tr.Lifetime = h.trail.life
		tr.LightEmission = 1
		tr.LightInfluence = 0
		tr.MinLength = 0.05
		tr.FaceCamera = true
		tr.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
		tr.WidthScale = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0.2) })
		tr.Parent = handle
	end
end

local function buildHammer(h)
	local origin = CFrame.new(0, 600, 0) -- far above the map while building
	local tool = Instance.new("Tool")
	tool.Name = h.special and ("Hammer_" .. h.key) or ("Hammer_" .. h.tier)
	tool:SetAttribute("Key", h.key)
	tool:SetAttribute("Tier", h.tier)
	tool.CanBeDropped = false
	tool.RequiresHandle = true
	tool.Grip = CFrame.Angles(math.rad(-16), 0, 0) -- leans out a touch: the head never covers your face, and it doesn't hang back either
	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.25, 0.25, 0.25)
	handle.Transparency = 1
	handle.CFrame = origin
	handle.Anchored = true
	handle.CanCollide = false; handle.CanQuery = false; handle.CanTouch = false; handle.Massless = true
	handle.CastShadow = false
	handle.Parent = tool
	tool.Parent = workspace -- CSG needs the parts in the world while it works
	local made, groups, order = {}, {}, {}
	for _, piece in ipairs(h.pieces) do
		local part = buildPiece(piece, origin, tool, spec.palette)
		table.insert(made, part)
		if piece.union then
			if not groups[piece.union] then groups[piece.union] = {}; table.insert(order, piece.union) end
			table.insert(groups[piece.union], { part = part, piece = piece })
		end
	end
	-- pieces that belong together (the halves of a lightning bolt) become one seamless part
	for _, name in ipairs(order) do
		local g = groups[name]
		if #g > 1 then
			local first = g[1].part
			local rest = {}
			for i = 2, #g do table.insert(rest, g[i].part) end
			for _, e in ipairs(g) do e.part.Anchored = true end
			local ok, u = pcall(function() return first:UnionAsync(rest) end)
			if ok then
				u.Name = name
				finishPart(u, g[1].piece.mat, spec.palette[g[1].piece.mat])
				u.CastShadow = false
				u.Parent = tool
				first:Destroy()
				for _, r in ipairs(rest) do r:Destroy() end
			else
				warn("union " .. name .. ": " .. tostring(u))
			end
		end
	end
	-- galaxy: a scrolling space texture on the core (animated on the client)
	if h.scroll then
		local core = tool:FindFirstChild(h.scroll.piece)
		if core then
			core:SetAttribute("Scroll", true)
			-- the galaxy on every face; the client slides the texture (HammerFX)
			for _, face in ipairs(Enum.NormalId:GetEnumItems()) do
				local tx = Instance.new("Texture")
				tx.Name = "Space"
				tx.Texture = GALAXY
				tx.Face = face
				tx.StudsPerTileU = (h.scroll.studs or 1.2) * S
				tx.StudsPerTileV = (h.scroll.studs or 1.2) * S
				tx.Parent = core
			end
		end
	end
	addFx(tool, handle, h)
	for _, p in ipairs(tool:GetDescendants()) do
		if p:IsA("BasePart") and p ~= handle then
			local w = Instance.new("WeldConstraint")
			w.Part0 = handle; w.Part1 = p; w.Parent = p
		end
	end
	for _, p in ipairs(tool:GetDescendants()) do if p:IsA("BasePart") then p.Anchored = false end end
	tool:SetAttribute("Built", os.time())
	return tool
end

local out = {}
for _, tier in ipairs(args.tiers or {}) do
	local h = spec.hammers[tier]
	local t0 = os.clock()
	local old = folder:FindFirstChild(h.special and ("Hammer_" .. h.key) or ("Hammer_" .. tier))
	local ok, tool = pcall(buildHammer, h)
	if ok then
		if old and not args.preview then old:Destroy() end
		if args.preview then
			tool:PivotTo(CFrame.new(args.preview + Vector3.new((tier - 1) * 3.2, 0, 0)) * CFrame.Angles(0, math.rad(args.yaw or 0), 0))
			for _, p in ipairs(tool:GetDescendants()) do if p:IsA("BasePart") then p.Anchored = true end end
			tool.Parent = workspace:FindFirstChild("HammerLab") or workspace
		else
			tool.Parent = folder
		end
		table.insert(out, string.format("%d %s ok (%.1fs, %d parts)", tier, h.key, os.clock() - t0, #tool:GetChildren()))
	else
		for _, ch in ipairs(workspace:GetChildren()) do if ch.Name == "Hammer_" .. tier and ch:IsA("Tool") then ch:Destroy() end end
		table.insert(out, tier .. " " .. h.key .. " FAILED: " .. tostring(tool))
	end
end
return table.concat(out, "\n")
