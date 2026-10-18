-- BlockRise 2.0 - world geometry (MAP v3, 2026-10-18; the owner: "rebuild the map from scratch: no more circle, wide
-- streets, a city in scale with the player, premium assets"). The layout numbers and small helpers that make parts and
-- place the kit (ServerStorage.Kit2: the stylised meshes made in Blender). Used by WorldGen (once, in Edit) and by the
-- City at runtime (streets, lots, land).
--
-- The city is a grid. Down the middle runs the green mall (north park, the plaza with the spawn, south park), with a
-- boulevard on each side. The 6 player districts face the mall, 3 on each side; each is 2 blocks wide and 3 rows deep.
-- World: X east-west, Z north-south, ground top at Y = 0. 1 m ~ 3 studs (the player is ~5.5 studs tall).
local Geo = {}

local C3 = Color3.fromRGB
Geo.Pal = {
	asphalt = C3(62, 66, 76), asphaltDark = C3(52, 55, 64), lane = C3(246, 246, 240), laneYellow = C3(255, 204, 60),
	sidewalk = C3(214, 208, 198), sidewalkDark = C3(190, 184, 174), curb = C3(236, 232, 224), plaza = C3(238, 228, 210),
	plazaEdge = C3(206, 132, 92), plazaInlay = C3(250, 196, 120), gold = C3(255, 200, 58), goldDark = C3(226, 152, 36),
	stone = C3(240, 234, 222), stoneDark = C3(192, 182, 168), water = C3(56, 178, 230), grass = C3(108, 190, 82),
	grassDark = C3(88, 170, 70), grassLight = C3(128, 204, 96), navy = C3(30, 44, 88), white = C3(250, 250, 248),
	glass = C3(132, 196, 236), metal = C3(74, 84, 104), trunk = C3(146, 100, 64), leaf = C3(102, 200, 78),
	leafDark = C3(66, 170, 74), lampPost = C3(52, 58, 72), lampGlow = C3(255, 226, 160), dirt = C3(132, 96, 66),
	gravel = C3(214, 206, 192), sand = C3(244, 222, 168), sandWet = C3(222, 196, 140),
	red = C3(244, 82, 82), blue = C3(70, 152, 244), yellow = C3(255, 212, 70), pink = C3(252, 132, 176),
	purple = C3(162, 112, 244), orange = C3(255, 152, 60), teal = C3(54, 204, 182), cream = C3(255, 246, 228),
}
Geo.Accents = { Geo.Pal.red, Geo.Pal.yellow, Geo.Pal.blue, Geo.Pal.pink, Geo.Pal.teal, Geo.Pal.orange, Geo.Pal.purple }

-- Layout -------------------------------------------------------------------------------------------------------
Geo.Lot = 72            -- a lot (pad 68)
Geo.Block = 144         -- 2 x 2 lots
Geo.StreetW = 44        -- a city street: sidewalk 9 | road 26 (2 lanes) | sidewalk 9
Geo.Walk = 9
Geo.BlvdW = 60          -- a boulevard: sidewalk 11 | road 38 (2 + 2 lanes, a centre line) | sidewalk 11
Geo.BlvdWalk = 11
Geo.RoadY = 0.3         -- road top
Geo.WalkY = 0.9         -- sidewalk top (a 0.6 curb)
Geo.MallHalf = 150      -- the mall: x -150..150
Geo.Rows = 3
Geo.RowStep = 188       -- a block (144) and a street (44)
Geo.Depth = 564         -- a district runs from the boulevard (local z 0) out to the perimeter road's outer edge
Geo.DistrictZ = { -376, -376, 0, 0, 376, 376 }
Geo.EdgeX = Geo.MallHalf + Geo.BlvdW + Geo.Depth   -- 774: the city's east/west edge
Geo.EdgeZ = 586                                    -- the north/south edge (the outer arterials' sidewalks)

function Geo.districtSide(k) return (k % 2 == 1) and -1 or 1 end

-- the district's frame: origin where its centre street meets the boulevard, local +Z outward (away from the mall),
-- +X to the right when looking outward
function Geo.districtCF(k)
	local s = Geo.districtSide(k)
	local out = Vector3.new(s, 0, 0)
	return CFrame.fromMatrix(Vector3.new(s * (Geo.MallHalf + Geo.BlvdW), 0, Geo.DistrictZ[k]), Vector3.yAxis:Cross(out), Vector3.yAxis)
end

-- a lot: row 1..3 (1 = on the boulevard), block 1 (left, -X) / 2 (right), slot 1 front-outer, 2 front-inner,
-- 3 back-outer, 4 back-inner
function Geo.lotIndex(row, block, slot) return (row - 1) * 8 + (block - 1) * 4 + slot end
function Geo.lotOf(index)
	local i = index - 1
	return i // 8 + 1, (i % 8) // 4 + 1, i % 4 + 1
end
-- where a row's blocks start (local z)
function Geo.blockZ(row) return (row - 1) * Geo.RowStep end
-- a block's centre (local)
function Geo.blockCenter(row, block) return (block == 1 and -94 or 94), Geo.blockZ(row) + 72 end
-- the lot's centre (local x, z) and which way its front faces (-1: toward the mall, +1: away)
function Geo.lotLocal(index)
	local row, block, slot = Geo.lotOf(index)
	local side = block == 1 and -1 or 1
	local outer = (slot == 1 or slot == 3)
	local x = side * (outer and 130 or 58)
	local z0 = Geo.blockZ(row)
	local front = slot <= 2
	return x, front and (z0 + 36) or (z0 + 108), front and -1 or 1
end
-- the lot's CFrame in the world at ground level, looking out of its front (toward its street)
function Geo.lotCF(k, index)
	local x, z, face = Geo.lotLocal(index)
	local base = Geo.districtCF(k) * CFrame.new(x, 0, z)
	return face < 0 and base or base * CFrame.Angles(0, math.pi, 0)
end

-- A district's own streets (they build themselves when a block is bought): the centre street along local Z
-- ("A<row>"), the two cross streets between the rows ("X<j>_<side>", j = 1, 2) and their crossings with the centre
-- street ("I<j>_0"). The boulevard, the arterials between districts and the perimeter road are permanent (WorldGen).
function Geo.crossZ(j) return 166 + (j - 1) * Geo.RowStep end
function Geo.blockStreets(row, block)
	local segs, cross = { "A" .. row }, {}
	if row > 1 then table.insert(segs, "X" .. (row - 1) .. "_" .. block) table.insert(cross, "I" .. (row - 1) .. "_0") end
	if row < Geo.Rows then table.insert(segs, "X" .. row .. "_" .. block) table.insert(cross, "I" .. row .. "_0") end
	return { segs = segs, cross = cross }
end
-- a piece's rectangle in local coords: centre x, z, its length along its run, and whether it runs along Z
-- (crossings: nil)
function Geo.segRect(id)
	local kind = id:sub(1, 1)
	if kind == "A" then
		local r = tonumber(id:sub(2))
		return 0, Geo.blockZ(r) + 72, 144, true
	elseif kind == "X" then
		local j, b = id:match("X(%d)_(%d)")
		j, b = tonumber(j), tonumber(b)
		return (b == 1 and -94 or 94), Geo.crossZ(tonumber(j)), 144, false
	elseif kind == "I" then
		local j = tonumber(id:match("I(%d)_"))
		return 0, Geo.crossZ(j), Geo.StreetW, nil
	end
end

-- Part helpers ---------------------------------------------------------------------------------------------------
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
	p.Material = material or Enum.Material.SmoothPlastic
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
	p.Material = material or Enum.Material.SmoothPlastic
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

-- The kit ---------------------------------------------------------------------------------------------------------
-- a mesh from ServerStorage.Kit2 (pivot at the bottom centre, front toward -Z), nil if missing. Decoration: no
-- collisions unless `solid`, taps go through it
function Geo.kit(parent, key, cf, scale, solid)
	local lib = game:GetService("ServerStorage"):FindFirstChild("Kit2")
	local src = lib and lib:FindFirstChild(key)
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
Geo.prop = Geo.kit

-- a tree (a random broad-leaf one, a random turn and size; the same seed always gives the same tree)
local TREES = { "TreeA", "TreeB", "TreeC", "TreeD", "TreeA", "TreeB" }
function Geo.tree(parent, cf, scale, seed)
	local rng = Random.new(seed or 1)
	local key = TREES[rng:NextInteger(1, #TREES)]
	local m = Geo.kit(parent, key, cf * CFrame.Angles(0, rng:NextNumber() * math.pi * 2, 0), (scale or 1) * (0.85 + rng:NextNumber() * 0.3))
	if m then m.Name = "Tree" end
	return m
end
function Geo.pine(parent, cf, scale, seed)
	local rng = Random.new(seed or 1)
	local m = Geo.kit(parent, "Pine", cf * CFrame.Angles(0, rng:NextNumber() * math.pi * 2, 0), (scale or 1) * (0.85 + rng:NextNumber() * 0.3))
	if m then m.Name = "Pine" end
	return m
end
function Geo.palm(parent, cf, scale, seed)
	local rng = Random.new(seed or 1)
	local m = Geo.kit(parent, rng:NextNumber() < 0.5 and "Palm" or "Palm2", cf * CFrame.Angles(0, rng:NextNumber() * math.pi * 2, 0), (scale or 1) * (0.85 + rng:NextNumber() * 0.3))
	if m then m.Name = "Palm" end
	return m
end
function Geo.bush(parent, cf, scale, seed)
	local rng = Random.new(seed or 1)
	local keys = { "BushFlowers", "BushRound", "BushFlowers" }
	local m = Geo.kit(parent, keys[rng:NextInteger(1, #keys)], cf * CFrame.Angles(0, rng:NextNumber() * math.pi * 2, 0), (scale or 1) * (0.8 + rng:NextNumber() * 0.4))
	if m then m.Name = "Bush" end
	return m
end

-- a street lamp at cf (its arm reaching toward -Z of cf, over the road) with a warm light for the night
function Geo.lamp(parent, cf)
	local m = Geo.kit(parent, "StreetLight", cf, 1, true)
	if not m then return nil end
	m.Name = "Lamp"
	local glow = Geo.box(m, Vector3.new(1, 1, 1), cf * CFrame.new(0, 16.6, -4.2), Geo.Pal.lampGlow, Enum.Material.SmoothPlastic, { Name = "Glow", CanCollide = false, CanQuery = false, Transparency = 1 })
	local l = Instance.new("SpotLight")
	l.Face = Enum.NormalId.Bottom
	l.Angle = 120
	l.Range = 34
	l.Brightness = 1.6
	l.Color = Geo.Pal.lampGlow
	l.Enabled = false -- the day/night cycle switches lamps on
	l.Parent = glow
	game:GetService("CollectionService"):AddTag(glow, "NightLight")
	return m
end

-- a park bench at cf (the seat facing -Z of cf)
function Geo.bench(parent, cf)
	local m = Geo.kit(parent, "Bench", cf, 1, true)
	if m then m.Name = "Bench" end
	return m
end

-- a flower bed: a low stone rim, dark soil, the kit's flowers and ferns in rows
function Geo.flowerBed(parent, cf, w, d, seed)
	local P = Geo.Pal
	local rng = Random.new(seed or 3)
	local m = Geo.model(parent, "FlowerBed")
	Geo.box(m, Vector3.new(w, 1.2, d), cf * CFrame.new(0, 0.6, 0), P.stone, Enum.Material.SmoothPlastic)
	Geo.box(m, Vector3.new(w - 1, 0.2, d - 1), cf * CFrame.new(0, 1.25, 0), P.dirt, Enum.Material.Ground)
	local nx, nz = math.max(1, math.floor((w - 1) / 2.4)), math.max(1, math.floor((d - 1) / 2.4))
	for ix = 0, nx - 1 do
		for iz = 0, nz - 1 do
			local x = -((nx - 1) * 2.4) / 2 + ix * 2.4 + rng:NextNumber(-0.4, 0.4)
			local z = -((nz - 1) * 2.4) / 2 + iz * 2.4 + rng:NextNumber(-0.4, 0.4)
			Geo.kit(m, rng:NextNumber() < 0.75 and "Flowers" or "Fern", cf * CFrame.new(x, 1.3, z) * CFrame.Angles(0, rng:NextNumber() * 6.28, 0), 0.9 + rng:NextNumber() * 0.4)
		end
	end
	return m
end

-- a string of triangular flags between two points (bunting), sagging a little
function Geo.bunting(parent, a, b, sag, seed)
	local m = Geo.model(parent, "Bunting")
	local n = math.max(3, math.floor((b - a).Magnitude / 3))
	for i = 0, n - 1 do
		local t0, t1 = i / n, (i + 1) / n
		local p = a:Lerp(b, t0) - Vector3.new(0, math.sin(t0 * math.pi) * (sag or 2), 0)
		local q = a:Lerp(b, t1) - Vector3.new(0, math.sin(t1 * math.pi) * (sag or 2), 0)
		local mid = (p + q) / 2
		Geo.box(m, Vector3.new(0.12, 0.12, (q - p).Magnitude), CFrame.lookAt(mid, q), Geo.Pal.white, Enum.Material.SmoothPlastic, { CanCollide = false, CanQuery = false })
		Geo.wedge(m, Vector3.new(0.1, 1.8, 1.4), CFrame.lookAt(mid, q) * CFrame.new(0, -0.95, 0) * CFrame.Angles(math.pi, 0, 0), Geo.Accents[(i + (seed or 0)) % #Geo.Accents + 1], Enum.Material.Fabric, { CanCollide = false, CanQuery = false })
	end
	return m
end

return Geo
