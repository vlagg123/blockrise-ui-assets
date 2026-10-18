-- BlockRise 2.0 - the static world, built once in Edit: terrain, the BlockRise plaza (fountain with the golden
-- hammer, spawn terrace), the ring road, the 6 avenues and the district gates. The districts' own streets and lots
-- are built at runtime by the City (Streets), from each player's progress.
local Geo = require(script.Parent.Geo)
local P = Geo.Pal
local CS = game:GetService("CollectionService")
local M = {}

local function ring(parent, r, h, top, color, material, name)
	return Geo.cyl(parent, r, h, CFrame.new(0, top - h / 2, 0), color, material, { Name = name or "Disk" })
end

-- STYLE v2 (2026-10-18, the owner: "like Pet Simulator"): no terrain grass; the ground is one flat, bright, smooth
-- green plate (top at Y = 0) with a few softer patches, so every road, plaza and lot sits cleanly on it
function M.terrain(world)
	workspace.Terrain:Clear()
	local g = Geo.folder(world, "Ground")
	-- a round island: the grass, a sandy beach, shallow water, then the sea all the way to the horizon
	Geo.cyl(g, 890, 6, CFrame.new(0, -3, 0), Color3.fromRGB(104, 206, 86), Enum.Material.SmoothPlastic, { Name = "Grass" })
	Geo.cyl(g, 924, 5, CFrame.new(0, -3.2, 0), Color3.fromRGB(255, 228, 160), Enum.Material.SmoothPlastic, { Name = "Beach" })
	Geo.cyl(g, 934, 1, CFrame.new(0, -4.6, 0), Color3.fromRGB(255, 255, 255), Enum.Material.SmoothPlastic, { Name = "Foam", CanCollide = false })
	for ix = -2, 2 do
		for iz = -2, 2 do
			Geo.box(g, Vector3.new(2048, 1, 2048), CFrame.new(ix * 2048, -5.6, iz * 2048), Color3.fromRGB(64, 182, 255), Enum.Material.SmoothPlastic, { Name = "Sea", CanCollide = false })
		end
	end
	local rng = Random.new(7)
	for i = 1, 60 do
		local a = rng:NextNumber() * math.pi * 2
		local r = 300 + rng:NextNumber() * 480
		local s = 40 + rng:NextNumber() * 70
		local c = rng:NextNumber() < 0.5 and Color3.fromRGB(118, 216, 94) or Color3.fromRGB(94, 192, 80)
		Geo.cyl(g, s, 0.2, CFrame.new(math.cos(a) * r, -0.09 + i * 0.0015, math.sin(a) * r), c, Enum.Material.SmoothPlastic, { Name = "Patch", CanCollide = false })
	end
end

-- nature (STYLE): puffy trees everywhere the cities are not: the gaps between the districts and a forest belt
-- along the shore (seeded: the same world every build)
local function inDistrict(p, margin)
	for k = 1, 6 do
		local l = Geo.districtCF(k):PointToObjectSpace(p)
		if math.abs(l.X) < 140 + margin and l.Z > -30 - margin and l.Z < 470 + margin then return true end
	end
	return false
end
function M.nature(world)
	local f = Geo.folder(world, "Nature")
	local rng = Random.new(42)
	local placed = {}
	local function free(p, d)
		for _, q in ipairs(placed) do if (q - p).Magnitude < d then return false end end
		return true
	end
	local function plant(p, big)
		table.insert(placed, p)
		Geo.tree(f, CFrame.new(p), big and (2.4 + rng:NextNumber() * 0.8) or (1.5 + rng:NextNumber() * 0.7), math.floor(p.X * 7 + p.Z * 13))
	end
	-- the shore belt
	for ring = 0, 2 do
		local r = 862 - ring * 36
		local n = math.floor(2 * math.pi * r / (ring == 0 and 34 or 50))
		for i = 1, n do
			local a = (i + rng:NextNumber() * 0.6 + ring * 0.5) / n * math.pi * 2
			local rr = r + (rng:NextNumber() - 0.5) * 14
			local p = Vector3.new(math.sin(a) * rr, 0, math.cos(a) * rr)
			if not inDistrict(p, 25) and free(p, 18) then plant(p, ring == 0) end
		end
	end
	-- the gaps between the districts: groves
	for i = 1, 900 do
		local a = rng:NextNumber() * math.pi * 2
		local r = 285 + rng:NextNumber() * 520
		local p = Vector3.new(math.sin(a) * r, 0, math.cos(a) * r)
		if not inDistrict(p, 30) and free(p, 30) then plant(p, rng:NextNumber() < 0.3) end
	end
	-- flower patches among them
	for i = 1, 300 do
		local a = rng:NextNumber() * math.pi * 2
		local r = 300 + rng:NextNumber() * 480
		local p = Vector3.new(math.sin(a) * r, 0, math.cos(a) * r)
		if not inDistrict(p, 30) and free(p, 16) then
			table.insert(placed, p)
			Geo.flowerBed(f, CFrame.new(p) * CFrame.Angles(0, rng:NextNumber() * math.pi, 0), 6 + rng:NextInteger(0, 2) * 2.2, 4.4, i)
		end
	end
	return #placed
end

-- the hub between the plaza and the ring road: the Hammer Shop facing the fountain, little parks in the other
-- sectors (the avenues run at 30 + 60k)
local function hubSectors(parent)
	local m = Geo.model(parent, "HubParks")
	for s = 0, 5 do
		local deg = s * 60
		local d = Geo.dir(deg)
		local r = 192
		local pos = d * r
		local face = CFrame.lookAt(pos, Vector3.new(0, 0, 0)) -- -Z toward the fountain
		if deg == 0 then
			local shop = Geo.prop(m, "shop_hammer", face, 1, true)
			if shop then
				shop.Name = "HammerShop"
				local _, size = shop:GetBoundingBox()
				local door = Geo.box(shop, Vector3.new(8, 8, 1), face * CFrame.new(0, 4, -size.Z / 2 - 6), P.white, Enum.Material.SmoothPlastic, { Name = "ShopDoor", Transparency = 1, CanCollide = false })
				local pp = Instance.new("ProximityPrompt")
				pp.Name = "Window"
				pp.ActionText = "Open"
				pp.ObjectText = "Hammer Shop"
				pp.MaxActivationDistance = 16
				pp.RequiresLineOfSight = false
				pp:SetAttribute("Window", "HAMMERS")
				pp.Parent = door
				-- the sign over it
				local bb = Instance.new("BillboardGui")
				bb.Size = UDim2.fromOffset(300, 70)
				bb.StudsOffsetWorldSpace = Vector3.new(0, size.Y + 6, 0)
				bb.MaxDistance = 230
				bb.LightInfluence = 0
				bb.Parent = shop.PrimaryPart or shop:FindFirstChildWhichIsA("BasePart")
				local t = Instance.new("TextLabel")
				t.BackgroundTransparency = 1
				t.Size = UDim2.fromScale(1, 1)
				t.Font = Enum.Font.FredokaOne
				t.TextScaled = true
				t.Text = "HAMMER SHOP"
				t.TextColor3 = Color3.fromRGB(255, 220, 70)
				local st = Instance.new("UIStroke") st.Thickness = 4 st.Color = Color3.fromRGB(24, 32, 70) st.Parent = t
				t.Parent = bb
			end
			-- a path from the plaza to its door
			Geo.box(m, Vector3.new(14, 0.6, 32), CFrame.lookAt(d * 156, Vector3.zero) * CFrame.new(0, 0.3, 0), P.plaza, Enum.Material.SmoothPlastic, { Name = "ShopPath" })
		else
			-- a little park: a lawn circle, trees, a ring of flowers, two benches
			Geo.cyl(m, 34, 0.4, face * CFrame.new(0, 0.2, 0), P.grass, Enum.Material.SmoothPlastic, { Name = "Lawn" })
			Geo.cyl(m, 36, 0.3, face * CFrame.new(0, 0.15, 0), P.white, Enum.Material.SmoothPlastic, { Name = "LawnEdge" })
			Geo.tree(m, face * CFrame.new(0, 0.4, 6), 1.7, 500 + s)
			Geo.tree(m, face * CFrame.new(-18, 0.4, 14), 1.2, 520 + s)
			Geo.tree(m, face * CFrame.new(18, 0.4, 14), 1.2, 540 + s)
			for j = 0, 7 do
				local a = j / 8 * math.pi * 2
				Geo.flowerBed(m, face * CFrame.new(math.cos(a) * 28, 0.4, math.sin(a) * 28) * CFrame.Angles(0, -a, 0), 4.4, 6.6, s * 8 + j)
			end
			for sd = -1, 1, 2 do Geo.bench(m, face * CFrame.new(sd * 10, 0.4, -14) * CFrame.Angles(0, math.pi, 0)) end
		end
	end
	return m
end

-- STYLE (2026-10-18): warm afternoon sun, bright saturated colours, soft bloom, a light blue haze
function M.lighting()
	local L = game:GetService("Lighting")
	L.ClockTime = 14.4
	L.GeographicLatitude = 28
	L.Brightness = 2.6
	L.ExposureCompensation = 0.1
	L.Ambient = Color3.fromRGB(96, 98, 120)
	L.OutdoorAmbient = Color3.fromRGB(150, 150, 168)
	L.ColorShift_Top = Color3.fromRGB(255, 240, 214)
	L.ColorShift_Bottom = Color3.fromRGB(0, 0, 0)
	L.EnvironmentDiffuseScale = 1
	L.EnvironmentSpecularScale = 1
	L.GlobalShadows = true
	L.ShadowSoftness = 0.25
	local function get(class, name)
		local x = L:FindFirstChildOfClass(class) or Instance.new(class)
		x.Name = name
		x.Parent = L
		return x
	end
	local atm = get("Atmosphere", "Atmosphere")
	atm.Density = 0.24
	atm.Offset = 0.18
	atm.Color = Color3.fromRGB(206, 228, 255)
	atm.Decay = Color3.fromRGB(140, 170, 220)
	atm.Glare = 0.25
	atm.Haze = 0.9
	local cc = get("ColorCorrectionEffect", "ColorCorrection")
	cc.Brightness = 0.03
	cc.Contrast = 0.1
	cc.Saturation = 0.22
	cc.TintColor = Color3.fromRGB(255, 251, 244)
	local bloom = get("BloomEffect", "Bloom")
	bloom.Intensity = 0.55
	bloom.Size = 28
	bloom.Threshold = 1.6
	local rays = get("SunRaysEffect", "SunRays")
	rays.Intensity = 0.04
	rays.Spread = 0.6
	local sky = get("Sky", "Sky")
	sky.SunAngularSize = 16
	sky.MoonAngularSize = 10
	sky.CelestialBodiesShown = true
	sky.StarCount = 2500
end

-- the plaza (STYLE): a terracotta border, a paved outer field (spawn terrace, kiosks, boards), a garden ring with
-- flowers and trees (64..96) crossed by 12 paths, and the inner court around the fountain with a tiled star
local function plaza(parent)
	local m = Geo.model(parent, "Plaza")
	ring(m, Geo.PlazaR, 1.2, 0.6, P.plazaEdge, Enum.Material.SmoothPlastic, "Border")
	ring(m, Geo.PlazaR - 3, 1.2, 0.62, P.plaza, Enum.Material.SmoothPlastic, "Field")
	ring(m, 104, 1.2, 0.64, P.plazaInlay, Enum.Material.SmoothPlastic, "FieldBand")
	ring(m, 101, 1.2, 0.66, P.plaza, Enum.Material.SmoothPlastic, "FieldInner")
	ring(m, 96, 1.2, 0.68, P.grass, Enum.Material.Grass, "Garden")
	ring(m, 64, 1.2, 0.7, P.plazaEdge, Enum.Material.SmoothPlastic, "CourtBorder")
	ring(m, 62, 1.2, 0.72, P.plaza, Enum.Material.SmoothPlastic, "Court")
	-- the tiled star of the court: 12 rays in two colours
	for i = 0, 11 do
		local a = i * math.pi / 6 + math.pi / 12
		local r0, r1 = 31, 60
		Geo.box(m, Vector3.new(4.5, 0.1, r1 - r0), CFrame.Angles(0, a, 0) * CFrame.new(0, 0.74, (r0 + r1) / 2), i % 2 == 0 and P.plazaInlay or P.plazaEdge, Enum.Material.SmoothPlastic, { Name = "Star", CanCollide = false })
	end
	-- the 12 garden paths
	for i = 0, 11 do
		local a = i * math.pi / 6
		Geo.box(m, Vector3.new(10, 1.2, 34), CFrame.Angles(0, a, 0) * CFrame.new(0, 0.71 - 0.6 + 0.01, 80), P.plaza, Enum.Material.SmoothPlastic, { Name = "Path" })
		for s = -1, 1, 2 do
			Geo.box(m, Vector3.new(0.8, 1.5, 34), CFrame.Angles(0, a, 0) * CFrame.new(s * 5.4, 0.75, 80), P.white, Enum.Material.SmoothPlastic, { Name = "Kerb" })
		end
	end
	return m
end

-- the garden ring's life: a tree and two flower beds in each sector, benches facing the fountain, lamps at the
-- path ends with bunting between them
local function garden(parent)
	local m = Geo.model(parent, "Garden")
	for i = 0, 11 do
		local a = i * math.pi / 6 + math.pi / 12 -- the sector's middle
		local rot = CFrame.Angles(0, a, 0)
		if i % 2 == 0 then Geo.tree(m, rot * CFrame.new(0, 1.3, 80), 1.25, 300 + i) else Geo.pine(m, rot * CFrame.new(0, 1.3, 80), 1.3, 300 + i) end
		Geo.flowerBed(m, rot * CFrame.new(0, 1.3, 69.5), 13, 3.4, i)
		Geo.flowerBed(m, rot * CFrame.new(0, 1.3, 90.5), 16, 3.4, i + 5)
		for s = -1, 1, 2 do
			if not Geo.tree(m, rot * CFrame.new(s * 9, 1.3, 80), 0.42, 600 + i * 2 + s) then
				Geo.ball(m, 1.9, rot * CFrame.new(s * 9, 2.2, 80), P.leafDark, Enum.Material.SmoothPlastic, { Name = "Bush" })
			end
		end
	end
	for i = 0, 5 do
		local a = i * math.pi / 3 + math.pi / 12
		for s = -1, 1, 2 do
			local aa = a + s * math.rad(7)
			Geo.bench(m, CFrame.Angles(0, aa, 0) * CFrame.new(0, 0.72, 57) * CFrame.Angles(0, 0, 0), P.trunk)
		end
	end
	-- lamps on both sides of each path's outer end (not on the spawn path: the terrace steps are there), bunting
	-- from each lamp to the next path's lamp
	local function lampPos(i, s) return (CFrame.Angles(0, i * math.pi / 6, 0) * CFrame.new(s * 7.5, 0.66, 99)) end
	for i = 0, 11 do
		if i ~= 6 then
			for s = -1, 1, 2 do Geo.lamp(m, lampPos(i, s) * CFrame.Angles(0, math.pi, 0)) end
		end
	end
	for i = 0, 11 do
		local j = (i + 1) % 12
		if i ~= 6 and j ~= 6 then
			-- (a lamp's -Z side faces the plaza centre; its head hangs 3.8 studs that way)
			local a = (lampPos(i, -1) * CFrame.new(0, 13.2, 0)).Position
			local b = (lampPos(j, 1) * CFrame.new(0, 13.2, 0)).Position
			Geo.bunting(m, a, b, 2.4, i)
		end
	end
	return m
end

-- the fountain: a stone basin with water, an anvil on a pedestal and a giant golden hammer on a hinge that
-- strikes it (the client animates the swing: tag "FountainHammer", pivot = the model's PrimaryPart "Axle")
local function fountain(parent)
	local m = Geo.model(parent, "Fountain")
	Geo.cyl(m, 27, 3.6, CFrame.new(0, 1.8, 0), P.stone, Enum.Material.Limestone, { Name = "Basin" })
	Geo.cyl(m, 28.2, 1, CFrame.new(0, 0.9, 0), P.stoneDark, Enum.Material.Slate, { Name = "Plinth" })
	Geo.cyl(m, 24.6, 0.4, CFrame.new(0, 3.42, 0), P.water, Enum.Material.Glass, { Name = "Water", Transparency = 0.15, Reflectance = 0.25, CanCollide = false })
	-- pedestal + anvil
	Geo.cyl(m, 6.5, 10, CFrame.new(2, 8.4, 0), P.stone, Enum.Material.Marble, { Name = "Pedestal" })
	Geo.cyl(m, 7.3, 1, CFrame.new(2, 13.9, 0), P.gold, Enum.Material.Metal, { Name = "PedestalCap" })
	local anvilY = 14.4
	Geo.box(m, Vector3.new(9, 2.4, 6), CFrame.new(2, anvilY + 1.2, 0), P.metal, Enum.Material.Metal, { Name = "AnvilFoot" })
	Geo.box(m, Vector3.new(6, 2.2, 4), CFrame.new(2, anvilY + 3.5, 0), P.metal, Enum.Material.Metal, { Name = "AnvilWaist" })
	Geo.box(m, Vector3.new(12, 2.6, 6.4), CFrame.new(2.5, anvilY + 5.9, 0), P.metal, Enum.Material.Metal, { Name = "AnvilTop" })
	Geo.wedge(m, Vector3.new(6.4, 2.6, 6), CFrame.new(11.5, anvilY + 5.9, 0) * CFrame.Angles(0, -math.pi / 2, 0), P.metal, Enum.Material.Metal, { Name = "AnvilHorn" })
	local strikeY = anvilY + 7.2 -- the anvil's face
	-- the hammer (its own model, hinged at the axle): the generated golden hammer laid down, the handle along +X
	-- from the column, the head at the far end resting on the anvil; parts as a fallback
	local hm = Geo.model(m, "Hammer")
	local gold = Geo.prop(hm, "hammer_gold", CFrame.Angles(0, 0, -math.pi / 2), 1)
	local pivotY = strikeY + 6.6
	if gold then
		local lo, hi = Vector3.new(math.huge, math.huge, math.huge), Vector3.new(-math.huge, -math.huge, -math.huge)
		for _, p in ipairs(gold:GetDescendants()) do
			if p:IsA("BasePart") then
				for _, sx in ipairs({ -0.5, 0.5 }) do for _, sy in ipairs({ -0.5, 0.5 }) do for _, sz in ipairs({ -0.5, 0.5 }) do
					local c = p.CFrame * Vector3.new(p.Size.X * sx, p.Size.Y * sy, p.Size.Z * sz)
					lo = lo:Min(c) hi = hi:Max(c)
				end end end
			end
		end
		local W = hi.Y - lo.Y
		pivotY = strikeY + W / 2
		local target = Vector3.new(-25 - lo.X, pivotY - (lo.Y + hi.Y) / 2, -(lo.Z + hi.Z) / 2)
		gold:PivotTo(gold:GetPivot() + target)
		for _, p in ipairs(gold:GetDescendants()) do
			if p:IsA("BasePart") then p.Parent = hm p.Name = "Gold" p.CastShadow = true end
		end
		gold:Destroy()
	end
	-- the hinge column
	Geo.cyl(m, 2.6, pivotY - 1.6 - 3.4, CFrame.new(-23, 3.4 + (pivotY - 1.6 - 3.4) / 2, 0), P.stone, Enum.Material.Marble, { Name = "Column" })
	Geo.cyl(m, 3.2, 1.2, CFrame.new(-23, pivotY - 1.6 - 0.6, 0), P.gold, Enum.Material.Metal, { Name = "ColumnCap" })
	local axle = Geo.box(hm, Vector3.new(2.2, 2.2, 8), CFrame.new(-23, pivotY, 0), P.goldDark, Enum.Material.Metal, { Name = "Axle", CanCollide = false, Transparency = gold and 1 or 0 })
	hm.PrimaryPart = axle
	CS:AddTag(hm, "FountainHammer")
	if gold then
		-- (the parts below are the fallback hammer)
	else
	local handleLen = 25
	Geo.box(hm, Vector3.new(handleLen, 2.4, 2.4), CFrame.new(-23 + handleLen / 2, pivotY, 0), P.goldDark, Enum.Material.Metal, { Name = "Handle", CanCollide = false })
	for i = 1, 3 do
		Geo.box(hm, Vector3.new(1.2, 2.8, 2.8), CFrame.new(-23 + 5 + i * 3, pivotY, 0), P.navy, Enum.Material.SmoothPlastic, { Name = "Grip", CanCollide = false })
	end
	local headX = -23 + handleLen + 1
	Geo.box(hm, Vector3.new(8, 13.2, 8), CFrame.new(headX, pivotY, 0), P.gold, Enum.Material.Metal, { Name = "Head", CanCollide = false })
	Geo.box(hm, Vector3.new(8.6, 1.4, 8.6), CFrame.new(headX, pivotY + 3.6, 0), P.goldDark, Enum.Material.Metal, { Name = "Band", CanCollide = false })
	Geo.box(hm, Vector3.new(8.6, 1.4, 8.6), CFrame.new(headX, pivotY - 3.6, 0), P.goldDark, Enum.Material.Metal, { Name = "Band", CanCollide = false })
	Geo.box(hm, Vector3.new(7, 0.6, 7), CFrame.new(headX, pivotY - 6.85, 0), P.gold:Lerp(Color3.new(1, 1, 1), 0.3), Enum.Material.Metal, { Name = "Face", CanCollide = false })
	end
	-- water jets around the basin (the client bursts them on each strike)
	for i = 0, 7 do
		local a = i * math.pi / 4 + math.pi / 8
		local jet = Geo.box(m, Vector3.new(1, 1, 1), CFrame.new(math.cos(a) * 21, 3.6, math.sin(a) * 21), P.stone, Enum.Material.Marble, { Name = "Jet", Transparency = 1, CanCollide = false })
		local pe = Instance.new("ParticleEmitter")
		pe.Name = "Spray"
		pe.Texture = "rbxasset://textures/particles/smoke_main.dds"
		pe.Color = ColorSequence.new(Color3.fromRGB(220, 245, 255))
		pe.LightEmission = 0.35
		pe.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 2.2) })
		pe.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
		pe.Lifetime = NumberRange.new(1.1, 1.5)
		pe.Speed = NumberRange.new(26, 32)
		pe.SpreadAngle = Vector2.new(6, 6)
		pe.Acceleration = Vector3.new(0, -40, 0)
		pe.Rate = 18
		pe.EmissionDirection = Enum.NormalId.Top
		pe.Parent = jet
		CS:AddTag(jet, "FountainJet")
	end
	return m
end

-- the spawn terrace: a raised stone platform with steps toward the fountain
local function terrace(parent)
	local m = Geo.model(parent, "Terrace")
	local z = -119
	Geo.box(m, Vector3.new(64, 3.2, 26), CFrame.new(0, 1.6, z), P.stone, Enum.Material.Limestone, { Name = "Deck" })
	Geo.box(m, Vector3.new(66, 0.5, 28), CFrame.new(0, 3.35, z), P.plazaEdge, Enum.Material.Sandstone, { Name = "Top" })
	for i = 1, 3 do
		Geo.box(m, Vector3.new(40, 3.2 - i * 0.8, 3), CFrame.new(0, (3.2 - i * 0.8) / 2, z + 13 + i * 3 - 1.5), P.stone, Enum.Material.Limestone, { Name = "Step" })
	end
	-- planters at both ends with a tree each
	for s = -1, 1, 2 do
		Geo.box(m, Vector3.new(10, 2.2, 10), CFrame.new(s * 27, 4.7, z - 3), P.stoneDark, Enum.Material.Slate, { Name = "Planter" })
		Geo.box(m, Vector3.new(9, 0.3, 9), CFrame.new(s * 27, 5.85, z - 3), P.dirt, Enum.Material.Ground, { Name = "Soil" })
		Geo.tree(m, CFrame.new(s * 27, 5.9, z - 3), 1.15, 70 + s)
	end
	local sp = Instance.new("SpawnLocation")
	sp.Name = "Spawn"
	sp.Anchored = true
	sp.Size = Vector3.new(30, 1, 10)
	sp.CFrame = CFrame.new(0, 3.1, z - 2) * CFrame.Angles(0, math.pi, 0)
	sp.Transparency = 1
	sp.CanCollide = false
	sp.Neutral = true
	sp.Duration = 0
	for _, d in ipairs(sp:GetChildren()) do d:Destroy() end
	sp.Parent = m
	return m
end

-- the ring road around the hub, from straight pieces (sidewalks stop where the avenues cross)
local function ringRoad(parent)
	local m = Geo.model(parent, "RingRoad")
	local N = 72
	local R = Geo.RingR
	local roadHalf = Geo.RingW / 2 - Geo.Walk
	for i = 0, N - 1 do
		local deg = (i + 0.5) * 360 / N
		local a = math.rad(deg)
		local cf = CFrame.new(Geo.dir(deg) * R) * CFrame.Angles(0, a, 0) -- local X = the tangent
		local function arc(r) return 2 * math.pi * r / N + 0.6 end
		Geo.box(m, Vector3.new(arc(R + roadHalf), 0.7, roadHalf * 2), cf * CFrame.new(0, Geo.RoadY - 0.35, 0), P.asphalt, Enum.Material.Asphalt, { Name = "Road" })
		if i % 2 == 0 then Geo.box(m, Vector3.new(5, 0.06, 0.45), cf * CFrame.new(0, Geo.RoadY + 0.02, 0), P.laneYellow, Enum.Material.SmoothPlastic, { Name = "Line", CanCollide = false }) end
		-- near an avenue? (avenues at 30 + 60k)
		local off = math.abs(((deg - 30) % 60 + 60) % 60)
		off = math.min(off, 60 - off)
		local crossing = off < (14 / R) * 180 / math.pi + 360 / N / 2 + 0.5
		if not crossing then
			for s = -1, 1, 2 do
				local rr = R + s * (roadHalf + Geo.Walk / 2)
				Geo.box(m, Vector3.new(arc(rr), Geo.WalkY, Geo.Walk), cf * CFrame.new(0, Geo.WalkY / 2, s * (roadHalf + Geo.Walk / 2)), P.sidewalk, Enum.Material.Pavement, { Name = "Walk" })
			end
			if i % 3 == 1 then Geo.lamp(m, cf * CFrame.new(0, Geo.WalkY, roadHalf + Geo.Walk / 2) * CFrame.Angles(0, math.pi, 0)) end
		end
	end
	return m
end

-- an avenue piece: a straight street from r0 to r1 along the angle deg (road, curbs, sidewalks, lamps, trees)
local function avenuePiece(parent, deg, r0, r1, seed)
	local d = Geo.dir(deg)
	local mid = d * ((r0 + r1) / 2)
	local len = r1 - r0
	local cf = CFrame.lookAt(mid, mid + d) * CFrame.Angles(0, math.pi / 2, 0) -- local X along the avenue
	local m = Geo.model(parent, "Avenue")
	local half = Geo.StreetW / 2
	local roadHalf = half - Geo.Walk
	Geo.box(m, Vector3.new(len, 0.7, roadHalf * 2), cf * CFrame.new(0, Geo.RoadY - 0.35, 0), P.asphalt, Enum.Material.Asphalt, { Name = "Road" })
	for s = -1, 1, 2 do
		Geo.box(m, Vector3.new(len, Geo.WalkY + 0.05, 0.7), cf * CFrame.new(0, (Geo.WalkY + 0.05) / 2, s * (roadHalf + 0.35)), P.curb, Enum.Material.Concrete, { Name = "Curb" })
		Geo.box(m, Vector3.new(len, Geo.WalkY, Geo.Walk - 0.7), cf * CFrame.new(0, Geo.WalkY / 2, s * (roadHalf + 0.7 + (Geo.Walk - 0.7) / 2)), P.sidewalk, Enum.Material.Pavement, { Name = "Walk" })
		local walkZ = s * (roadHalf + 0.7 + (Geo.Walk - 0.7) / 2)
		local n = math.max(1, math.floor(len / 30))
		for i = 0, n - 1 do
			local x = -len / 2 + (i + 0.5) * len / n
			if i % 2 == 0 then
				Geo.lamp(m, cf * CFrame.new(x, Geo.WalkY, walkZ) * CFrame.Angles(0, s < 0 and 0 or math.pi, 0))
			else
				Geo.tree(m, cf * CFrame.new(x, Geo.WalkY, walkZ), 0.85, seed + i * 7 + s)
			end
		end
	end
	local n = math.floor((len - 8) / 12)
	for i = 0, n - 1 do
		Geo.box(m, Vector3.new(6, 0.06, 0.45), cf * CFrame.new(-((n - 1) * 12) / 2 + i * 12, Geo.RoadY + 0.02, 0), P.lane, Enum.Material.SmoothPlastic, { Name = "Line", CanCollide = false })
	end
	return m
end

-- the gate of a district: two pillars and a beam over its avenue, with the city's name (set at runtime)
local function gate(parent, k)
	local base = Geo.districtCF(k)
	local m = Geo.model(parent, "Gate")
	m:SetAttribute("District", k)
	for s = -1, 1, 2 do
		Geo.box(m, Vector3.new(4.6, 24, 4.6), base * CFrame.new(s * 17.5, 12 + Geo.WalkY, 10), P.stone, Enum.Material.Limestone, { Name = "Pillar" })
		Geo.box(m, Vector3.new(5.6, 1.4, 5.6), base * CFrame.new(s * 17.5, Geo.WalkY + 0.7, 10), P.stoneDark, Enum.Material.Slate, { Name = "Foot" })
		Geo.box(m, Vector3.new(5.4, 1.2, 5.4), base * CFrame.new(s * 17.5, 24.6 + Geo.WalkY, 10), P.gold, Enum.Material.Metal, { Name = "Cap" })
	end
	local beam = Geo.box(m, Vector3.new(41, 5.4, 3.4), base * CFrame.new(0, 27.5 + Geo.WalkY, 10), P.navy, Enum.Material.SmoothPlastic, { Name = "Sign" })
	Geo.box(m, Vector3.new(42, 0.8, 3.8), base * CFrame.new(0, 30.4 + Geo.WalkY, 10), P.gold, Enum.Material.Metal, { Name = "Trim" })
	Geo.box(m, Vector3.new(42, 0.8, 3.8), base * CFrame.new(0, 24.6 + Geo.WalkY, 10), P.gold, Enum.Material.Metal, { Name = "Trim" })
	for _, face in ipairs({ Enum.NormalId.Front, Enum.NormalId.Back }) do
		local sg = Instance.new("SurfaceGui")
		sg.Name = "Name" .. face.Name
		sg.Face = face
		sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		sg.PixelsPerStud = 24
		sg.LightInfluence = 0
		sg.Parent = beam
		local t = Instance.new("TextLabel")
		t.Name = "Label"
		t.BackgroundTransparency = 1
		t.Size = UDim2.fromScale(1, 1)
		t.Font = Enum.Font.FredokaOne
		t.TextScaled = true
		t.TextColor3 = P.gold
		t.Text = "FREE LAND"
		local pad = Instance.new("UIPadding")
		pad.PaddingTop = UDim.new(0.14, 0) pad.PaddingBottom = UDim.new(0.14, 0) pad.PaddingLeft = UDim.new(0.04, 0) pad.PaddingRight = UDim.new(0.04, 0)
		pad.Parent = t
		t.Parent = sg
	end
	return m
end

function M.build()
	assert(game.PlaceId == 97174353381365, "BlockRise DEV only")
	local old = workspace:FindFirstChild("World")
	if old then old:Destroy() end
	local world = Instance.new("Folder")
	world.Name = "World"
	M.terrain(world)
	local hub = Geo.folder(world, "Hub")
	M.lighting()
	plaza(hub)
	garden(hub)
	fountain(hub)
	terrace(hub)
	ringRoad(hub)
	hubSectors(hub)
	M.nature(world)
	local av = Geo.folder(world, "Avenues")
	for k, deg in ipairs(Geo.DistrictAngles) do
		avenuePiece(av, deg, Geo.PlazaR, Geo.RingR - Geo.RingW / 2, k * 100)
		avenuePiece(av, deg, Geo.RingR + Geo.RingW / 2, Geo.DistrictR + 20, k * 100 + 50)
	end
	local districts = Geo.folder(world, "Districts")
	for k = 1, 6 do
		local f = Geo.folder(districts, "D" .. k)
		gate(f, k)
	end
	world.Parent = workspace
	return world
end

return M
