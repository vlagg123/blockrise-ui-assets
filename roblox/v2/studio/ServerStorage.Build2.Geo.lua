-- BlockRise 2.0 - world geometry: the layout numbers (hub, ring road, the 6 districts, blocks, lots, streets) and
-- small helpers that make parts. Used by WorldGen (once, in Edit) and by the City at runtime (streets, lots).
-- Angles: theta from +Z toward +X, dir = (sin theta, 0, cos theta). Ground top at Y = 0.
local Geo = {}

local C3 = Color3.fromRGB
-- STYLE (2026-10-18, the owner: "premium, a game kids want to play"): a bright toy-town look: clean smooth
-- materials (no grey realistic textures), saturated colours, warm light
Geo.Pal = {
	asphalt = C3(66, 71, 90), asphaltDark = C3(54, 58, 76), lane = C3(250, 250, 244), laneYellow = C3(255, 206, 64),
	sidewalk = C3(240, 234, 224), curb = C3(206, 199, 189), plaza = C3(250, 243, 230), plazaEdge = C3(238, 150, 96),
	plazaInlay = C3(255, 200, 112), gold = C3(255, 200, 58), goldDark = C3(232, 158, 36), stone = C3(244, 238, 228),
	stoneDark = C3(196, 186, 174), water = C3(64, 206, 242), grass = C3(112, 202, 86), grassDark = C3(86, 178, 70),
	navy = C3(30, 44, 88), white = C3(250, 250, 248), glass = C3(132, 196, 236), metal = C3(74, 84, 104),
	trunk = C3(146, 100, 64), leaf = C3(102, 200, 78), leafDark = C3(66, 170, 74), lampPost = C3(38, 52, 92),
	lampGlow = C3(255, 230, 160), dirt = C3(176, 124, 82), gravel = C3(214, 206, 192),
	red = C3(244, 82, 82), blue = C3(70, 152, 244), yellow = C3(255, 212, 70), pink = C3(252, 132, 176),
	purple = C3(162, 112, 244), orange = C3(255, 152, 60), teal = C3(54, 204, 182), cream = C3(255, 246, 228),
}
Geo.Accents = { Geo.Pal.red, Geo.Pal.yellow, Geo.Pal.blue, Geo.Pal.pink, Geo.Pal.teal, Geo.Pal.orange, Geo.Pal.purple }
-- realistic Roblox materials -> clean smooth ones (wood, brick, roof tiles, grass, glass, metal and neon stay)
Geo.Smooth = {
	[Enum.Material.Asphalt] = true, [Enum.Material.Pavement] = true, [Enum.Material.Concrete] = true, [Enum.Material.Limestone] = true,
	[Enum.Material.Sandstone] = true, [Enum.Material.Marble] = true, [Enum.Material.Slate] = true, [Enum.Material.Plaster] = true,
	[Enum.Material.Ground] = true, [Enum.Material.Granite] = true, [Enum.Material.Cobblestone] = true,
}

-- Layout -------------------------------------------------------------------------------------------
Geo.PlazaR = 140
Geo.RingR = 253        -- ring road centre line
Geo.RingW = 26
Geo.DistrictR = 330    -- district entrance (local z = 0)
Geo.StreetW = 28       -- sidewalk 5 | road 18 | sidewalk 5
Geo.Walk = 5
Geo.RoadY = 0.35       -- road top
Geo.WalkY = 0.85       -- sidewalk top (curb 0.5)
Geo.Lot = 56
Geo.Block = 112
Geo.RowStep = 140      -- block 112 + street 28
Geo.Rows = 3
Geo.DistrictAngles = { 30, 90, 150, 210, 270, 330 }

function Geo.dir(deg)
	local t = math.rad(deg)
	return Vector3.new(math.sin(t), 0, math.cos(t))
end

-- the district's frame: origin at its entrance on the axis, local +Z outward (away from the hub), +X to the right
function Geo.districtCF(k)
	local d = Geo.dir(Geo.DistrictAngles[k])
	local x = Vector3.new(d.Z, 0, -d.X)
	return CFrame.fromMatrix(d * Geo.DistrictR, x, Vector3.yAxis)
end

-- a lot: row 1..3, block 1 (left, -X) / 2 (right), slot 1 front-outer, 2 front-inner, 3 back-outer, 4 back-inner
function Geo.lotIndex(row, block, slot) return (row - 1) * 8 + (block - 1) * 4 + slot end
function Geo.lotOf(index)
	local i = index - 1
	return i // 8 + 1, (i % 8) // 4 + 1, i % 4 + 1
end
function Geo.blockZ(row) return 48 + (row - 1) * Geo.RowStep end
-- the lot's centre (local x, z) and which way its front faces (-1: toward the hub, +1: away)
function Geo.lotLocal(index)
	local row, block, slot = Geo.lotOf(index)
	local side = block == 1 and -1 or 1
	local outer = (slot == 1 or slot == 3)
	local x = side * (outer and 98 or 42)
	local z0 = Geo.blockZ(row)
	local front = slot <= 2
	return x, front and (z0 + 28) or (z0 + 84), front and -1 or 1
end
-- the lot's CFrame in the world at ground level, looking out of its front (toward its street)
function Geo.lotCF(k, index)
	local x, z, face = Geo.lotLocal(index)
	local base = Geo.districtCF(k) * CFrame.new(x, 0, z)
	-- (a CFrame looks along -Z: a front lot already faces the hub; a back lot is turned around)
	return face < 0 and base or base * CFrame.Angles(0, math.pi, 0)
end

-- Streets of a block: the 4 road segments and 4 crossings around it (ids are shared between neighbours)
-- cross street j (0..3) runs along X at z 20 + 140 j .. 48 + 140 j; the avenue (x -14..14) and the side streets
-- (x -154..-126 and 126..154) run along Z beside each row
function Geo.crossZ(j) return 34 + j * Geo.RowStep end
function Geo.blockStreets(row, block)
	return {
		segs = { "X" .. (row - 1) .. "_" .. block, "X" .. row .. "_" .. block, "A" .. row, "S" .. row .. "_" .. block },
		cross = { "I" .. (row - 1) .. "_0", "I" .. (row - 1) .. "_" .. block, "I" .. row .. "_0", "I" .. row .. "_" .. block },
	}
end
-- a segment's rectangle in local coords: centre x, z, length along its run, and whether it runs along Z
function Geo.segRect(id)
	local kind = id:sub(1, 1)
	if kind == "X" then
		local j, b = id:match("X(%d)_(%d)")
		j, b = tonumber(j), tonumber(b)
		return (b == 1 and -70 or 70), Geo.crossZ(j), 112, false
	elseif kind == "A" then
		local r = tonumber(id:sub(2))
		return 0, Geo.blockZ(r) + 56, 112, true
	elseif kind == "S" then
		local r, b = id:match("S(%d)_(%d)")
		r, b = tonumber(r), tonumber(b)
		return (b == 1 and -140 or 140), Geo.blockZ(r) + 56, 112, true
	elseif kind == "I" then
		local j, c = id:match("I(%d)_(%d)")
		j, c = tonumber(j), tonumber(c)
		return (c == 0 and 0 or (c == 1 and -140 or 140)), Geo.crossZ(j), 28, nil
	end
end

-- Part helpers -----------------------------------------------------------------------------------------
local function apply(p, props)
	if props then for k, v in pairs(props) do p[k] = v end end
	return p
end
function Geo.box(parent, size, cf, color, material, props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Color = color or Geo.Pal.white
	material = material or Enum.Material.SmoothPlastic
	p.Material = Geo.Smooth[material] and Enum.Material.SmoothPlastic or material
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	apply(p, props)
	p.Parent = parent
	return p
end
-- a cylinder standing up (axis along Y)
function Geo.cyl(parent, radius, height, cf, color, material, props)
	local p = Geo.box(parent, Vector3.new(height, radius * 2, radius * 2), cf * CFrame.Angles(0, 0, math.pi / 2), color, material, props)
	p.Shape = Enum.PartType.Cylinder
	return p
end
function Geo.ball(parent, radius, cf, color, material, props)
	local p = Geo.box(parent, Vector3.one * radius * 2, cf, color, material, props)
	p.Shape = Enum.PartType.Ball
	return p
end
function Geo.wedge(parent, size, cf, color, material, props)
	local p = Instance.new("WedgePart")
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Color = color or Geo.Pal.white
	material = material or Enum.Material.SmoothPlastic
	p.Material = Geo.Smooth[material] and Enum.Material.SmoothPlastic or material
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	apply(p, props)
	p.Parent = parent
	return p
end
function Geo.folder(parent, name)
	local f = parent:FindFirstChild(name)
	if not f then f = Instance.new("Folder") f.Name = name f.Parent = parent end
	return f
end
function Geo.model(parent, name)
	local m = Instance.new("Model")
	m.Name = name
	m.Parent = parent
	return m
end

-- Street furniture ---------------------------------------------------------------------------------------
-- a prop from the generated library (ServerStorage.Assets2.Props: pivot at the bottom centre), nil if missing.
-- Decoration only: no collisions unless `solid`, and taps go through it
function Geo.prop(parent, key, cf, scale, solid)
	local lib = game:GetService("ServerStorage"):FindFirstChild("Assets2")
	local src = lib and lib:FindFirstChild("Props") and lib.Props:FindFirstChild(key)
	if not src then return nil end
	local m = src:Clone()
	if scale and math.abs(scale - 1) > 0.01 then m:ScaleTo(scale) end
	m:PivotTo(cf)
	for _, p in ipairs(m:GetDescendants()) do
		if p:IsA("BasePart") then
			p.Anchored = true
			p.CanTouch = false
			if not solid then p.CanCollide = false p.CanQuery = false end
		end
	end
	m.Parent = parent
	return m
end

-- a street lamp at cf (facing the road along -Z of cf): post, arm, lamp head with a soft light
function Geo.lamp(parent, cf)
	local P = Geo.Pal
	local pm = Geo.prop(parent, "lamp", cf * CFrame.Angles(0, math.pi, 0), 1, true)
	if pm then
		pm.Name = "Lamp"
		local _, size = pm:GetBoundingBox()
		local glow = Geo.box(pm, Vector3.new(1, 1, 1), cf * CFrame.new(0, size.Y - 2.2, 0), P.lampGlow, Enum.Material.SmoothPlastic, { CanCollide = false, Transparency = 1, Name = "Glow" })
		glow.CanQuery = false
		local l = Instance.new("PointLight")
		l.Range = 22
		l.Brightness = 1.4
		l.Color = P.lampGlow
		l.Enabled = false -- the day/night cycle switches lamps on
		l.Parent = glow
		game:GetService("CollectionService"):AddTag(glow, "NightLight")
		return pm
	end
	local m = Geo.model(parent, "Lamp")
	Geo.cyl(m, 0.35, 14, cf * CFrame.new(0, 7, 0), P.lampPost, Enum.Material.Metal, { CanCollide = true })
	Geo.cyl(m, 0.7, 1, cf * CFrame.new(0, 0.5, 0), P.lampPost, Enum.Material.Metal)
	Geo.box(m, Vector3.new(0.5, 0.5, 4), cf * CFrame.new(0, 13.8, -2), P.lampPost, Enum.Material.Metal, { CanCollide = false })
	local head = Geo.box(m, Vector3.new(1.6, 0.6, 2.6), cf * CFrame.new(0, 13.5, -3.8), P.lampGlow, Enum.Material.Neon, { CanCollide = false, Name = "Glow" })
	local l = Instance.new("SpotLight")
	l.Face = Enum.NormalId.Bottom
	l.Angle = 110
	l.Range = 26
	l.Brightness = 1.6
	l.Color = P.lampGlow
	l.Enabled = false -- the day/night cycle switches lamps on
	l.Parent = head
	game:GetService("CollectionService"):AddTag(head, "NightLight")
	return m
end

-- the canopy colours (STYLE): mostly fresh greens, now and then a pink blossom, a golden or an orange tree
Geo.Leaves = {
	{ 0.30, Color3.fromRGB(96, 206, 72) }, { 0.22, Color3.fromRGB(124, 222, 84) }, { 0.18, Color3.fromRGB(70, 188, 96) },
	{ 0.12, Color3.fromRGB(255, 150, 196) }, { 0.10, Color3.fromRGB(255, 200, 70) }, { 0.08, Color3.fromRGB(255, 160, 80) },
}
function Geo.leafColor(rng)
	local x = rng:NextNumber()
	for _, l in ipairs(Geo.Leaves) do
		if x < l[1] then return l[2] end
		x -= l[1]
	end
	return Geo.Leaves[1][2]
end

-- a stylised tree: trunk + 3 overlapping leaf balls (seeded so the same spot always gets the same tree)
function Geo.tree(parent, cf, scale, seed)
	local P = Geo.Pal
	local rng = Random.new(seed or 1)
	scale = scale or 1
	local pm = Geo.prop(parent, "tree_flat", cf * CFrame.Angles(0, rng:NextNumber() * math.pi * 2, 0), scale * (0.62 + rng:NextNumber() * 0.14))
	if pm then
		pm.Name = "Tree"
		local c = Geo.leafColor(rng)
		for _, p in ipairs(pm:GetDescendants()) do if p:IsA("BasePart") and p.Name:find("canopy", 1, true) then p.Color = c end end
		return pm
	end
	local m = Geo.model(parent, "Tree")
	local h = (7 + rng:NextNumber() * 3) * scale
	Geo.cyl(m, 0.55 * scale, h, cf * CFrame.new(0, h / 2, 0), P.trunk, Enum.Material.Wood)
	local leaf = rng:NextNumber() < 0.5 and P.leaf or P.leafDark
	local r0 = (3.4 + rng:NextNumber()) * scale
	Geo.ball(m, r0, cf * CFrame.new(0, h + r0 * 0.5, 0), leaf, Enum.Material.SmoothPlastic, { CanCollide = false })
	for i = 1, 2 do
		local a = rng:NextNumber() * math.pi * 2
		local r = r0 * (0.65 + rng:NextNumber() * 0.15)
		Geo.ball(m, r, cf * CFrame.new(math.cos(a) * r0 * 0.6, h + r0 * 0.15 + i * 0.8 * scale, math.sin(a) * r0 * 0.6), leaf:Lerp(Color3.fromRGB(190, 230, 90), 0.12 * i), Enum.Material.SmoothPlastic, { CanCollide = false })
	end
	return m
end

-- a round pine-like tree (cone layers), for variety in parks
function Geo.pine(parent, cf, scale, seed)
	local P = Geo.Pal
	local rng = Random.new(seed or 1)
	scale = scale or 1
	local pm = Geo.prop(parent, "tree_flat", cf * CFrame.Angles(0, rng:NextNumber() * math.pi * 2, 0), scale * (0.55 + rng:NextNumber() * 0.1))
	if pm then
		pm.Name = "Pine"
		local c = rng:NextNumber() < 0.5 and Color3.fromRGB(255, 150, 196) or Color3.fromRGB(255, 196, 70)
		for _, p in ipairs(pm:GetDescendants()) do if p:IsA("BasePart") and p.Name:find("canopy", 1, true) then p.Color = c end end
		return pm
	end
	local m = Geo.model(parent, "Pine")
	Geo.cyl(m, 0.5 * scale, 3 * scale, cf * CFrame.new(0, 1.5 * scale, 0), P.trunk, Enum.Material.Wood)
	for i = 0, 2 do
		local r = (3.6 - i * 0.9) * scale
		local c = P.leafDark:Lerp(P.leaf, i * 0.3 + rng:NextNumber() * 0.1)
		Geo.ball(m, r, cf * CFrame.new(0, (3.2 + i * 2.6) * scale, 0), c, Enum.Material.SmoothPlastic, { CanCollide = false, Size = Vector3.new(r * 2, r * 1.5, r * 2) })
	end
	return m
end

-- a park bench at cf (facing -Z)
function Geo.bench(parent, cf, color)
	local P = Geo.Pal
	local pm = Geo.prop(parent, "bench", cf, 1, true)
	if pm then pm.Name = "Bench" return pm end
	local m = Geo.model(parent, "Bench")
	for i = 0, 2 do Geo.box(m, Vector3.new(6, 0.35, 0.7), cf * CFrame.new(0, 1.7, -0.6 + i * 0.8), color or P.trunk, Enum.Material.Wood) end
	for i = 0, 1 do Geo.box(m, Vector3.new(6, 0.7, 0.3), cf * CFrame.new(0, 2.5 + i * 0.9, 1.3) * CFrame.Angles(math.rad(-12), 0, 0), color or P.trunk, Enum.Material.Wood) end
	for s = -1, 1, 2 do
		Geo.box(m, Vector3.new(0.4, 1.7, 2.6), cf * CFrame.new(s * 2.6, 0.85, 0.2), P.lampPost, Enum.Material.Metal)
		Geo.box(m, Vector3.new(0.4, 2.2, 0.4), cf * CFrame.new(s * 2.6, 2.7, 1.4), P.lampPost, Enum.Material.Metal)
	end
	return m
end

-- a flower bed: a low rim with a soil top and rows of colourful flowers
function Geo.flowerBed(parent, cf, w, d, seed)
	local P = Geo.Pal
	local rng = Random.new(seed or 3)
	local m = Geo.model(parent, "Flowers")
	Geo.box(m, Vector3.new(w, 1.2, d), cf * CFrame.new(0, 0.6, 0), P.white, Enum.Material.SmoothPlastic)
	Geo.box(m, Vector3.new(w - 0.8, 0.2, d - 0.8), cf * CFrame.new(0, 1.25, 0), P.grassDark, Enum.Material.Grass)
	local cols = { P.red, P.yellow, P.pink, P.purple, P.orange, P.white }
	local nx, nz = math.max(1, math.floor((w - 1) / 2.2)), math.max(1, math.floor((d - 1) / 2.2))
	for ix = 0, nx - 1 do
		for iz = 0, nz - 1 do
			local x = -((nx - 1) * 2.2) / 2 + ix * 2.2
			local z = -((nz - 1) * 2.2) / 2 + iz * 2.2
			local c = cols[(ix + iz * 2 + (seed or 0)) % #cols + 1]
			Geo.ball(m, 0.75 + rng:NextNumber() * 0.25, cf * CFrame.new(x, 1.9, z), c, Enum.Material.SmoothPlastic, { CanCollide = false })
		end
	end
	return m
end

-- a string of triangular flags between two points (bunting), sagging a little
function Geo.bunting(parent, a, b, sag, seed)
	local m = Geo.model(parent, "Bunting")
	local n = math.max(3, math.floor((b - a).Magnitude / 3))
	for i = 0, n do
		local t = i / n
		local p = a:Lerp(b, t) - Vector3.new(0, math.sin(t * math.pi) * (sag or 2), 0)
		if i < n then
			local q = a:Lerp(b, (i + 1) / n) - Vector3.new(0, math.sin((i + 1) / n * math.pi) * (sag or 2), 0)
			local mid = (p + q) / 2
			Geo.box(m, Vector3.new(0.12, 0.12, (q - p).Magnitude), CFrame.lookAt(mid, q), Geo.Pal.white, Enum.Material.SmoothPlastic, { CanCollide = false })
			local flag = Geo.wedge(m, Vector3.new(0.1, 1.8, 1.4), CFrame.lookAt(mid, q) * CFrame.new(0, -0.95, 0) * CFrame.Angles(0, 0, 0), Geo.Accents[(i + (seed or 0)) % #Geo.Accents + 1], Enum.Material.Fabric, { CanCollide = false })
			flag.CFrame = CFrame.lookAt(mid, q) * CFrame.new(0, -0.95, 0) * CFrame.Angles(math.pi, 0, 0)
		end
	end
	return m
end

return Geo
