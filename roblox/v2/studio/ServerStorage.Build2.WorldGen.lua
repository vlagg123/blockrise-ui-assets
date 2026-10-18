-- BlockRise 2.0 - the static world (MAP v3, 2026-10-18; the owner: "rebuild the map from scratch, no more circle,
-- wide streets, a city in scale with the player, premium assets"), built once in Edit:
--   * an island in a terrain sea: a beach and a pier to the south, wooded hills to the north, forest belts east/west;
--   * the city grid: two boulevards, four arterials, the perimeter road (all permanent), with lamps, street trees,
--     benches, bins, hydrants and parked cars from the kit (ServerStorage.Kit2);
--   * the green mall down the middle: the north park (a pond), the plaza (the golden hammer fountain, the Hammer Shop,
--     the spawn terrace), the south park (a bandstand) leading to the beach;
--   * the 6 district gates. A district's own streets and lots are built at runtime by the City (Streets, Geo).
local Geo = require(script.Parent.Geo)
local Streets = require(script.Parent.Streets)
local P = Geo.Pal
local CS = game:GetService("CollectionService")
local M = {}

local MH, BW, EX, EZ = Geo.MallHalf, Geo.BlvdW, Geo.EdgeX, Geo.EdgeZ
local SW = Geo.StreetW
local BX = MH + BW / 2              -- 180: the boulevards' centre lines (x = -180, 180)
local PX = EX - SW / 2              -- 752: the perimeter roads' centre lines
local ARTZ = { -564, -188, 188, 564 } -- the arterials (E-W, permanent)
local DZ = { -376, 0, 376 }          -- the districts' centre streets (E-W, built by the districts)
local CROSSX = { 376, 564 }          -- the districts' cross streets (N-S, built by the districts), x = +-

-- Island, beach, sea ---------------------------------------------------------------------------------------------
local ISLAND = { x0 = -1180, x1 = 1180, z0 = -1060, z1 = 700, r = 220 }
-- a rounded rectangle from boxes and corner cylinders (top at `top`)
local function rounded(parent, rect, grow, top, thick, color, material, name)
	local x0, x1, z0, z1, r = rect.x0 - grow, rect.x1 + grow, rect.z0 - grow, rect.z1 + grow, rect.r + grow
	local y = top - thick / 2
	Geo.box(parent, Vector3.new(x1 - x0 - 2 * r, thick, z1 - z0), CFrame.new((x0 + x1) / 2, y, (z0 + z1) / 2), color, material, { Name = name })
	for s = -1, 1, 2 do
		local x = s < 0 and (x0 + r / 2) or (x1 - r / 2)
		Geo.box(parent, Vector3.new(r, thick, z1 - z0 - 2 * r), CFrame.new(x, y, (z0 + z1) / 2), color, material, { Name = name })
	end
	for _, cx in ipairs({ x0 + r, x1 - r }) do
		for _, cz in ipairs({ z0 + r, z1 - r }) do
			Geo.cyl(parent, r, thick, CFrame.new(cx, y, cz), color, material, { Name = name })
		end
	end
end
function M.ground(world)
	local g = Geo.folder(world, "Ground")
	rounded(g, ISLAND, 0, 0, 6, P.grass, Enum.Material.SmoothPlastic, "Grass")
	rounded(g, ISLAND, 70, -0.7, 6, P.sand, Enum.Material.SmoothPlastic, "Beach")
	rounded(g, ISLAND, 110, -2.2, 6, P.sandWet, Enum.Material.SmoothPlastic, "Shallows")
	-- softer and darker patches of grass so the land never reads as one flat plate
	local rng = Random.new(41)
	for i = 1, 70 do
		local x, z = rng:NextNumber(ISLAND.x0 + 120, ISLAND.x1 - 120), rng:NextNumber(ISLAND.z0 + 120, ISLAND.z1 - 60)
		if math.abs(x) > EX + 30 or math.abs(z) > EZ + 30 then
			local s = rng:NextNumber(40, 120)
			Geo.cyl(g, s, 0.2, CFrame.new(x, 0.02 + i * 0.0006, z), (i % 2 == 0) and P.grassDark or P.grassLight, Enum.Material.SmoothPlastic, { Name = "Patch", CanCollide = false })
		end
	end
	-- the sea (terrain water: waves, reflections)
	local T = workspace.Terrain
	T:Clear()
	T:FillBlock(CFrame.new(0, -9, -180), Vector3.new(4400, 14, 4000), Enum.Material.Water)
	T.WaterColor = Color3.fromRGB(38, 168, 214)
	T.WaterTransparency = 0.55
	T.WaterReflectance = 0.6
	T.WaterWaveSize = 0.15
	T.WaterWaveSpeed = 8
	return g
end

-- Streets: the permanent grid ------------------------------------------------------------------------------------
-- N-S lines (run along Z) and E-W lines (run along X): position, width, sidewalk, extent, kind
local function nsLines()
	local t = {}
	for _, s in ipairs({ -1, 1 }) do
		table.insert(t, { x = s * BX, w = BW, walk = Geo.BlvdWalk, z0 = -EZ, z1 = EZ, perm = true, blvd = true })
		table.insert(t, { x = s * PX, w = SW, walk = Geo.Walk, z0 = -EZ, z1 = EZ, perm = true })
		for _, cx in ipairs(CROSSX) do table.insert(t, { x = s * cx, w = SW, walk = Geo.Walk, z0 = -EZ, z1 = EZ, perm = false }) end
	end
	return t
end
local function ewLines()
	local t = {}
	for _, z in ipairs(ARTZ) do table.insert(t, { z = z, w = SW, walk = Geo.Walk, x0 = -EX, x1 = EX, perm = true }) end
	for _, z in ipairs(DZ) do
		for _, s in ipairs({ -1, 1 }) do
			local a, b = s * (MH + BW), s * EX
			table.insert(t, { z = z, w = SW, walk = Geo.Walk, x0 = math.min(a, b), x1 = math.max(a, b), perm = false, district = true })
		end
	end
	return t
end

function M.streets(world)
	local f = Geo.folder(world, "Streets")
	local NS, EW = nsLines(), ewLines()
	local junctions = {}
	-- every crossing of an N-S and an E-W line where one of them is permanent
	for _, a in ipairs(NS) do
		for _, b in ipairs(EW) do
			-- (a line reaches a crossing when the crossing's square lies within its extent)
			local onA = b.z >= a.z0 + b.w / 2 - 0.01 and b.z <= a.z1 - b.w / 2 + 0.01
			local onB = a.x >= b.x0 - a.w / 2 - 0.01 and a.x <= b.x1 + a.w / 2 + 0.01
			if onA and onB and (a.perm or b.perm) then
				local open = {
					nz = b.z - b.w / 2 > a.z0 + 0.5, pz = b.z + b.w / 2 < a.z1 - 0.5,
					nx = a.x - a.w / 2 > b.x0 + 0.5, px = a.x + a.w / 2 < b.x1 - 0.5,
				}
				-- the cross streets come off the arterials only on the district sides (never into the sea / the hills)
				if not a.perm then
					if b.z <= -EZ + SW then open.nz = false end
					if b.z >= EZ - SW then open.pz = false end
				end
				table.insert(junctions, { x = a.x, z = b.z, a = a, b = b, open = open })
			end
		end
	end
	local jf = Geo.folder(f, "Junctions")
	for i, j in ipairs(junctions) do
		local m = Geo.model(jf, "J" .. i)
		Streets.junction(m, CFrame.new(j.x, 0, j.z), j.a.w, j.b.w, j.a.walk, j.b.walk, j.open)
	end
	-- the permanent lines' segments between their crossings
	local sf = Geo.folder(f, "Segments")
	local n = 0
	local function piece(cf, len, line, seed, cars)
		if len < 4 then return end
		n += 1
		local m = Geo.model(sf, "S" .. n)
		Streets.segment(m, cf, len, line.w, line.walk, { line = line.blvd and "blvd" or "dash", seed = seed, cars = cars, treeSpacing = 44, lampSpacing = 66 })
	end
	for li, a in ipairs(NS) do
		if a.perm then
			local stops = {}
			for _, j in ipairs(junctions) do if math.abs(j.x - a.x) < 0.1 then table.insert(stops, { j.z - j.b.w / 2, j.z + j.b.w / 2 }) end end
			table.sort(stops, function(p, q) return p[1] < q[1] end)
			local cur = a.z0
			for _, s in ipairs(stops) do
				if s[1] > cur + 0.5 then
					local len = s[1] - cur
					piece(CFrame.new(a.x, 0, (cur + s[1]) / 2) * CFrame.Angles(0, math.pi / 2, 0), len, a, li * 100 + n, a.blvd and 0.2 or 0.3)
				end
				cur = math.max(cur, s[2])
			end
			if a.z1 > cur + 0.5 then piece(CFrame.new(a.x, 0, (cur + a.z1) / 2) * CFrame.Angles(0, math.pi / 2, 0), a.z1 - cur, a, li * 100 + n, 0.25) end
		end
	end
	for li, b in ipairs(EW) do
		if b.perm then
			local stops = {}
			for _, j in ipairs(junctions) do if math.abs(j.z - b.z) < 0.1 then table.insert(stops, { j.x - j.a.w / 2, j.x + j.a.w / 2 }) end end
			table.sort(stops, function(p, q) return p[1] < q[1] end)
			local cur = b.x0
			for _, s in ipairs(stops) do
				if s[1] > cur + 0.5 then piece(CFrame.new((cur + s[1]) / 2, 0, b.z), s[1] - cur, b, 5000 + li * 100 + n, 0.3) end
				cur = math.max(cur, s[2])
			end
			if b.x1 > cur + 0.5 then piece(CFrame.new((cur + b.x1) / 2, 0, b.z), b.x1 - cur, b, 5000 + li * 100 + n, 0.3) end
		end
	end
	return f
end

-- The plaza ----------------------------------------------------------------------------------------------------
local PZ0, PZ1 = -166, 166        -- the plaza between the two inner arterials' sidewalks
local function plazaFloor(m)
	local w, d = MH * 2, PZ1 - PZ0
	Geo.box(m, Vector3.new(w, Geo.WalkY, d), CFrame.new(0, Geo.WalkY / 2, 0), Color3.fromRGB(226, 214, 194), Enum.Material.SmoothPlastic, { Name = "Floor" })
	-- a tile grid
	for x = -MH + 12, MH - 12, 12 do Geo.box(m, Vector3.new(0.3, 0.04, d), CFrame.new(x, Geo.WalkY + 0.02, 0), P.stoneDark, Enum.Material.SmoothPlastic, { Name = "Grout", CanCollide = false, CanQuery = false }) end
	for z = PZ0 + 12, PZ1 - 12, 12 do Geo.box(m, Vector3.new(w, 0.04, 0.3), CFrame.new(0, Geo.WalkY + 0.02, z), P.stoneDark, Enum.Material.SmoothPlastic, { Name = "Grout", CanCollide = false, CanQuery = false }) end
	-- rings around the fountain: terracotta, gold inlay, cream
	Geo.cyl(m, 70, 0.1, CFrame.new(0, Geo.WalkY + 0.05, 0), P.plazaEdge, Enum.Material.SmoothPlastic, { Name = "Ring", CanCollide = false })
	Geo.cyl(m, 66, 0.1, CFrame.new(0, Geo.WalkY + 0.06, 0), P.plazaInlay, Enum.Material.SmoothPlastic, { Name = "Ring", CanCollide = false })
	Geo.cyl(m, 63, 0.1, CFrame.new(0, Geo.WalkY + 0.07, 0), P.cream, Enum.Material.SmoothPlastic, { Name = "Ring", CanCollide = false })
	for i = 0, 15 do
		local a = i * math.pi / 8
		Geo.box(m, Vector3.new(1.4, 0.1, 26), CFrame.Angles(0, a, 0) * CFrame.new(0, Geo.WalkY + 0.08, 50), i % 2 == 0 and P.plazaEdge or P.plazaInlay, Enum.Material.SmoothPlastic, { Name = "Star", CanCollide = false })
	end
end

-- the fountain: a two-tier stone basin with water, an anvil on a pedestal and a giant golden hammer on a hinge that
-- strikes it (the client animates the swing: tag "FountainHammer", pivot = its PrimaryPart "Axle"; jets: "FountainJet")
local function fountain(parent)
	local m = Geo.model(parent, "Fountain")
	local y0 = Geo.WalkY
	Geo.cyl(m, 40, 1.2, CFrame.new(0, y0 + 0.6, 0), P.stoneDark, Enum.Material.SmoothPlastic, { Name = "Plinth" })
	Geo.cyl(m, 38, 4.2, CFrame.new(0, y0 + 2.1, 0), P.stone, Enum.Material.SmoothPlastic, { Name = "Basin" })
	Geo.cyl(m, 38.8, 0.8, CFrame.new(0, y0 + 4.4, 0), P.cream, Enum.Material.SmoothPlastic, { Name = "Rim" })
	Geo.cyl(m, 35.6, 0.4, CFrame.new(0, y0 + 4.05, 0), P.water, Enum.Material.Glass, { Name = "Water", Transparency = 0.2, Reflectance = 0.2, CanCollide = false })
	-- the upper tier
	Geo.cyl(m, 16, 6, CFrame.new(0, y0 + 7, 0), P.stone, Enum.Material.SmoothPlastic, { Name = "Tier" })
	Geo.cyl(m, 16.8, 0.8, CFrame.new(0, y0 + 10.2, 0), P.gold, Enum.Material.Metal, { Name = "TierRim" })
	Geo.cyl(m, 14.4, 0.3, CFrame.new(0, y0 + 9.9, 0), P.water, Enum.Material.Glass, { Name = "Water2", Transparency = 0.2, Reflectance = 0.2, CanCollide = false })
	-- pedestal + anvil
	Geo.cyl(m, 5.2, 8, CFrame.new(2, y0 + 14, 0), P.stone, Enum.Material.Marble, { Name = "Pedestal" })
	Geo.cyl(m, 6, 1, CFrame.new(2, y0 + 18.5, 0), P.gold, Enum.Material.Metal, { Name = "PedestalCap" })
	local anvilY = y0 + 19
	local S = 1.3
	Geo.box(m, Vector3.new(9, 2.4, 6) * S, CFrame.new(2, anvilY + 1.2 * S, 0), P.metal, Enum.Material.Metal, { Name = "AnvilFoot" })
	Geo.box(m, Vector3.new(6, 2.2, 4) * S, CFrame.new(2, anvilY + 3.5 * S, 0), P.metal, Enum.Material.Metal, { Name = "AnvilWaist" })
	Geo.box(m, Vector3.new(12, 2.6, 6.4) * S, CFrame.new(2.5, anvilY + 5.9 * S, 0), P.metal, Enum.Material.Metal, { Name = "AnvilTop" })
	Geo.wedge(m, Vector3.new(6.4, 2.6, 6) * S, CFrame.new(2.5 + 9 * S, anvilY + 5.9 * S, 0) * CFrame.Angles(0, -math.pi / 2, 0), P.metal, Enum.Material.Metal, { Name = "AnvilHorn" })
	local strikeY = anvilY + 7.2 * S
	-- the hammer: hinged on a column, the handle along +X, the head resting on the anvil
	local hm = Geo.model(m, "Hammer")
	local headH = 16
	local pivotY = strikeY + headH / 2
	local colX = -30
	Geo.cyl(m, 3.2, pivotY - 2 - y0, CFrame.new(colX, y0 + (pivotY - 2 - y0) / 2, 0), P.stone, Enum.Material.Marble, { Name = "Column" })
	Geo.cyl(m, 4, 1.4, CFrame.new(colX, pivotY - 2.7, 0), P.gold, Enum.Material.Metal, { Name = "ColumnCap" })
	local axle = Geo.box(hm, Vector3.new(2.6, 2.6, 9), CFrame.new(colX, pivotY, 0), P.goldDark, Enum.Material.Metal, { Name = "Axle", CanCollide = false })
	hm.PrimaryPart = axle
	CS:AddTag(hm, "FountainHammer")
	local headX = 2.5
	local handleLen = headX - colX - 4
	Geo.box(hm, Vector3.new(handleLen, 3, 3), CFrame.new(colX + handleLen / 2, pivotY, 0), Color3.fromRGB(150, 96, 52), Enum.Material.Wood, { Name = "Handle", CanCollide = false })
	for i = 1, 5 do
		Geo.box(hm, Vector3.new(1.4, 3.5, 3.5), CFrame.new(colX + 4 + i * 2.2, pivotY, 0), P.navy, Enum.Material.Fabric, { Name = "Grip", CanCollide = false })
	end
	Geo.box(hm, Vector3.new(1.6, 3.6, 3.6), CFrame.new(colX + handleLen - 0.8, pivotY, 0), P.gold, Enum.Material.Metal, { Name = "Collar", CanCollide = false })
	Geo.box(hm, Vector3.new(10, headH, 10), CFrame.new(headX, pivotY, 0), P.gold, Enum.Material.Metal, { Name = "Head", CanCollide = false })
	for _, dy in ipairs({ headH / 2 - 2, -(headH / 2 - 2) }) do
		Geo.box(hm, Vector3.new(10.8, 1.6, 10.8), CFrame.new(headX, pivotY + dy, 0), P.goldDark, Enum.Material.Metal, { Name = "Band", CanCollide = false })
	end
	Geo.box(hm, Vector3.new(8.6, 0.8, 8.6), CFrame.new(headX, pivotY - headH / 2 - 0.4, 0), P.gold:Lerp(Color3.new(1, 1, 1), 0.35), Enum.Material.Metal, { Name = "Face", CanCollide = false })
	Geo.box(hm, Vector3.new(8.6, 0.8, 8.6), CFrame.new(headX, pivotY + headH / 2 + 0.4, 0), P.gold:Lerp(Color3.new(1, 1, 1), 0.35), Enum.Material.Metal, { Name = "Top", CanCollide = false })
	-- water jets around the basin (the client bursts them on each strike)
	for i = 0, 11 do
		local a = i * math.pi / 6 + math.pi / 12
		local jet = Geo.box(m, Vector3.new(1, 1, 1), CFrame.new(math.cos(a) * 30, y0 + 4.4, math.sin(a) * 30), P.stone, Enum.Material.Marble, { Name = "Jet", Transparency = 1, CanCollide = false })
		local pe = Instance.new("ParticleEmitter")
		pe.Name = "Spray"
		pe.Texture = "rbxasset://textures/particles/smoke_main.dds"
		pe.Color = ColorSequence.new(Color3.fromRGB(220, 245, 255))
		pe.LightEmission = 0.35
		pe.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.8), NumberSequenceKeypoint.new(1, 2.6) })
		pe.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
		pe.Lifetime = NumberRange.new(1.2, 1.6)
		pe.Speed = NumberRange.new(30, 36)
		pe.SpreadAngle = Vector2.new(6, 6)
		pe.Acceleration = Vector3.new(0, -42, 0)
		pe.Rate = 16
		pe.EmissionDirection = Enum.NormalId.Top
		pe.Parent = jet
		CS:AddTag(jet, "FountainJet")
	end
	return m
end

-- the Hammer Shop: a two-storey brick store on the plaza's north side facing the fountain: a glass shop front under
-- a striped awning, a giant hammer over the cornice, the name in lights; its door opens the HAMMERS window
local function hammerShop(parent)
	local m = Geo.model(parent, "HammerShop")
	local face = CFrame.new(0, Geo.WalkY, -128) -- local -Z toward the fountain? no: the front looks +Z (south)
	face = face * CFrame.Angles(0, math.pi, 0) -- now local -Z points south, toward the fountain
	local W, D, H = 66, 34, 30
	local brick = Color3.fromRGB(176, 84, 64)
	local trim = P.cream
	local function at(x, y, z) return face * CFrame.new(x, y, z) end
	-- the shell (back and sides solid, the front framed around the shop window and door)
	Geo.box(m, Vector3.new(W, H, 1.6), at(0, H / 2, D / 2), brick, Enum.Material.Brick, { Name = "Wall" })
	for s = -1, 1, 2 do Geo.box(m, Vector3.new(1.6, H, D), at(s * (W / 2 - 0.8), H / 2, 0), brick, Enum.Material.Brick, { Name = "Wall" }) end
	Geo.box(m, Vector3.new(W, H - 14, 1.6), at(0, 14 + (H - 14) / 2, -D / 2), brick, Enum.Material.Brick, { Name = "Wall" })
	for _, x in ipairs({ -W / 2 + 3, W / 2 - 3 }) do Geo.box(m, Vector3.new(6, 14, 1.6), at(x, 7, -D / 2), brick, Enum.Material.Brick, { Name = "Wall" }) end
	Geo.box(m, Vector3.new(W - 2, 0.8, D - 2), at(0, 13.6, 0), P.stoneDark, Enum.Material.SmoothPlastic, { Name = "Floor2" })
	Geo.box(m, Vector3.new(W + 2, 1.6, D + 2), at(0, H + 0.8, 0), trim, Enum.Material.SmoothPlastic, { Name = "Cornice" })
	Geo.box(m, Vector3.new(W, 0.4, D), at(0, H + 1.8, 0), P.stoneDark, Enum.Material.SmoothPlastic, { Name = "Roof" })
	-- the shop front: glass panes with mullions, the double door in the middle
	for _, x in ipairs({ -19, 19 }) do
		Geo.box(m, Vector3.new(20, 11, 0.3), at(x, 6.5, -D / 2), P.glass, Enum.Material.Glass, { Name = "Window", Transparency = 0.35 })
		for k = -1, 1 do Geo.box(m, Vector3.new(0.5, 11, 0.6), at(x + k * 6.7, 6.5, -D / 2 - 0.1), P.navy, Enum.Material.Metal, { Name = "Mullion" }) end
	end
	for _, x in ipairs({ -9.4, 9.4 }) do Geo.box(m, Vector3.new(1.2, 14, 1.8), at(x, 7, -D / 2), trim, Enum.Material.SmoothPlastic, { Name = "Pilaster" }) end
	Geo.box(m, Vector3.new(W, 1.2, 2.2), at(0, 14, -D / 2 - 0.2), trim, Enum.Material.SmoothPlastic, { Name = "Fascia" })
	-- upper floor windows
	for i = -2, 2 do
		Geo.box(m, Vector3.new(7, 8, 0.3), at(i * 12.5, 21.5, -D / 2 - 0.1), P.glass, Enum.Material.Glass, { Name = "Window2", Transparency = 0.3 })
		Geo.box(m, Vector3.new(8.4, 0.8, 1.6), at(i * 12.5, 17, -D / 2 - 0.5), trim, Enum.Material.SmoothPlastic, { Name = "Sill" })
		Geo.box(m, Vector3.new(8.4, 1.2, 1), at(i * 12.5, 26.2, -D / 2 - 0.3), trim, Enum.Material.SmoothPlastic, { Name = "Lintel" })
	end
	-- the striped awning
	for i = 0, 10 do
		local x = -W / 2 + 3 + i * ((W - 6) / 11) + (W - 6) / 22
		Geo.wedge(m, Vector3.new((W - 6) / 11, 2.4, 5), at(x, 12.6, -D / 2 - 2.6), i % 2 == 0 and P.red or P.cream, Enum.Material.Fabric, { Name = "Awning" })
	end
	-- the door: a glowing doorway with the prompt
	Geo.box(m, Vector3.new(16, 12, 0.4), at(0, 6, -D / 2 + 0.6), Color3.fromRGB(255, 228, 160), Enum.Material.Neon, { Name = "Doorway" })
	local door = Geo.box(m, Vector3.new(14, 11, 1), at(0, 5.5, -D / 2 - 2), P.white, Enum.Material.SmoothPlastic, { Name = "ShopDoor", Transparency = 1, CanCollide = false })
	local pp = Instance.new("ProximityPrompt")
	pp.Name = "Window"
	pp.ActionText = "Open"
	pp.ObjectText = "Hammer Shop"
	pp.MaxActivationDistance = 18
	pp.RequiresLineOfSight = false
	pp:SetAttribute("Window", "HAMMERS")
	pp.Parent = door
	-- the giant hammer on the roof and the name in lights
	local hy = H + 2
	Geo.box(m, Vector3.new(7, 2, 7), at(-22, hy + 1, 4), P.stoneDark, Enum.Material.SmoothPlastic, { Name = "SignBase" })
	local sign = at(-22, hy + 2, 4) * CFrame.Angles(0, 0, math.rad(-12))
	Geo.box(m, Vector3.new(2.8, 22, 2.8), sign * CFrame.new(0, 11, 0), Color3.fromRGB(150, 96, 52), Enum.Material.Wood, { Name = "SignHandle" })
	for i = 1, 4 do Geo.box(m, Vector3.new(3.2, 1, 3.2), sign * CFrame.new(0, 2 + i * 1.6, 0), P.navy, Enum.Material.Fabric, { Name = "SignGrip" }) end
	Geo.box(m, Vector3.new(18, 8.5, 8.5), sign * CFrame.new(0, 25, 0), P.gold, Enum.Material.Metal, { Name = "SignHead" })
	for _, dx in ipairs({ 6.5, -6.5 }) do Geo.box(m, Vector3.new(1.4, 9.2, 9.2), sign * CFrame.new(dx, 25, 0), P.goldDark, Enum.Material.Metal, { Name = "SignBand" }) end
	local board = Geo.box(m, Vector3.new(44, 7, 1.2), at(0, H - 4.5, -D / 2 - 1), P.navy, Enum.Material.SmoothPlastic, { Name = "NameBoard" })
	local sg = Instance.new("SurfaceGui")
	sg.Face = Enum.NormalId.Front
	sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	sg.PixelsPerStud = 24
	sg.LightInfluence = 0
	sg.MaxDistance = 600
	sg.Parent = board
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Size = UDim2.fromScale(1, 1)
	t.Font = Enum.Font.FredokaOne
	t.TextScaled = true
	t.Text = "HAMMER SHOP"
	t.TextColor3 = Color3.fromRGB(255, 214, 70)
	local st = Instance.new("UIStroke") st.Thickness = 3 st.Color = Color3.fromRGB(120, 60, 0) st.Parent = t
	local pad = Instance.new("UIPadding") pad.PaddingTop = UDim.new(0.12, 0) pad.PaddingBottom = UDim.new(0.12, 0) pad.Parent = t
	t.Parent = sg
	-- planters by the door
	for s = -1, 1, 2 do
		Geo.box(m, Vector3.new(5, 2.4, 5), at(s * 12.5, 1.2, -D / 2 - 6), P.stoneDark, Enum.Material.SmoothPlastic, { Name = "Planter" })
		Geo.kit(m, "BushFlowers", at(s * 12.5, 2.4, -D / 2 - 6), 1)
	end
	m.PrimaryPart = door
	return m
end

-- the spawn terrace: a raised stone deck on the plaza's south side, steps down toward the fountain
local function terrace(parent)
	local m = Geo.model(parent, "Terrace")
	local z = 128
	local y0 = Geo.WalkY
	Geo.box(m, Vector3.new(76, 3.2, 30), CFrame.new(0, y0 + 1.6, z), P.stone, Enum.Material.SmoothPlastic, { Name = "Deck" })
	Geo.box(m, Vector3.new(78, 0.5, 32), CFrame.new(0, y0 + 3.45, z), P.plazaEdge, Enum.Material.SmoothPlastic, { Name = "Top" })
	for i = 1, 3 do
		Geo.box(m, Vector3.new(48, 3.2 - i * 0.8, 3), CFrame.new(0, y0 + (3.2 - i * 0.8) / 2, z - 15 - i * 3 + 1.5), P.stone, Enum.Material.SmoothPlastic, { Name = "Step" })
	end
	for s = -1, 1, 2 do
		Geo.box(m, Vector3.new(12, 2.4, 12), CFrame.new(s * 31, y0 + 4.9, z + 4), P.stoneDark, Enum.Material.SmoothPlastic, { Name = "Planter" })
		Geo.box(m, Vector3.new(11, 0.3, 11), CFrame.new(s * 31, y0 + 6.15, z + 4), P.dirt, Enum.Material.Ground, { Name = "Soil" })
		Geo.tree(m, CFrame.new(s * 31, y0 + 6.2, z + 4), 0.8, 70 + s)
	end
	local sp = Instance.new("SpawnLocation")
	sp.Name = "Spawn"
	sp.Anchored = true
	sp.Size = Vector3.new(34, 1, 12)
	sp.CFrame = CFrame.new(0, y0 + 3.2, z + 2) -- looking north (-Z) at the fountain
	sp.Transparency = 1
	sp.CanCollide = false
	sp.Neutral = true
	sp.Duration = 0
	for _, d in ipairs(sp:GetChildren()) do d:Destroy() end
	sp.Parent = m
	return m
end

local function plaza(mall)
	local m = Geo.model(mall, "Plaza")
	plazaFloor(m)
	fountain(m)
	hammerShop(m)
	terrace(m)
	local y0 = Geo.WalkY
	-- benches facing the fountain, lamps between them, bunting from lamp to lamp
	local lampPos = {}
	for i = 0, 7 do
		local a = i * math.pi / 4 + math.pi / 8
		Geo.bench(m, CFrame.Angles(0, a, 0) * CFrame.new(0, y0, 58) * CFrame.Angles(0, 0, 0))
		local la = a + math.pi / 8
		local lp = CFrame.Angles(0, la, 0) * CFrame.new(0, y0, 70)
		Geo.lamp(m, lp)
		table.insert(lampPos, (lp * CFrame.new(0, 15, 0)).Position)
	end
	for i = 1, #lampPos do Geo.bunting(m, lampPos[i], lampPos[i % #lampPos + 1], 2.5, i) end
	-- four garden quadrants (lawns in a stone border, an L around the fountain's ring) with a big tree, smaller trees,
	-- bushes and flower borders; the paved cross between them leads to the shop, the terrace and the boulevards
	for _, sx in ipairs({ -1, 1 }) do
		for _, sz in ipairs({ -1, 1 }) do
			local g = Geo.model(m, "Garden")
			for _, r in ipairs({ { 84, 142, 40, 158 }, { 46, 84, 82, 158 } }) do
				local x0, x1, z0, z1 = r[1], r[2], r[3], r[4]
				local cx, cz = sx * (x0 + x1) / 2, sz * (z0 + z1) / 2
				Geo.box(g, Vector3.new(x1 - x0, 1, z1 - z0), CFrame.new(cx, y0 + 0.5, cz), P.stoneDark, Enum.Material.SmoothPlastic, { Name = "Border" })
				Geo.box(g, Vector3.new(x1 - x0 - 2, 1.05, z1 - z0 - 2), CFrame.new(cx, y0 + 0.53, cz), P.grass, Enum.Material.SmoothPlastic, { Name = "Lawn" })
			end
			local top = y0 + 1.05
			Geo.tree(g, CFrame.new(sx * 113, top, sz * 116), 1.3, 900 + sx * 3 + sz)
			Geo.tree(g, CFrame.new(sx * 64, top, sz * 138), 0.9, 920 + sx * 3 + sz)
			Geo.tree(g, CFrame.new(sx * 124, top, sz * 60), 0.9, 940 + sx * 3 + sz)
			for k = 0, 5 do Geo.bush(g, CFrame.new(sx * (94 + (k % 3) * 18), top, sz * (150 - (k // 3) * 64)), 1.3, 960 + k + sx * 7 + sz * 13) end
			-- flower borders along the paved cross
			Geo.flowerBed(g, CFrame.new(sx * 50.5, top - 0.6, sz * 120), 5, 72, 980 + sx + sz * 5)
			Geo.flowerBed(g, CFrame.new(sx * 113, top - 0.6, sz * 44.5), 54, 5, 990 + sx + sz * 5)
		end
	end
	return m
end

-- The parks -----------------------------------------------------------------------------------------------------
local function lawn(m, x0, x1, z0, z1)
	Geo.box(m, Vector3.new(x1 - x0, 0.3, z1 - z0), CFrame.new((x0 + x1) / 2, 0.15, (z0 + z1) / 2), P.grassLight, Enum.Material.SmoothPlastic, { Name = "Lawn" })
end
local function path(m, a, b, w)
	local mid = (a + b) / 2
	local len = (b - a).Magnitude
	Geo.box(m, Vector3.new(w, 0.5, len), CFrame.lookAt(mid, b) * CFrame.new(0, 0.25, 0), P.gravel, Enum.Material.SmoothPlastic, { Name = "Path" })
	Geo.box(m, Vector3.new(w + 1.2, 0.35, len), CFrame.lookAt(mid, b) * CFrame.new(0, 0.175, 0), P.stoneDark, Enum.Material.SmoothPlastic, { Name = "PathEdge" })
end
-- trees, bushes and rocks scattered over an area, away from the given keep-out circles
local function scatter(m, x0, x1, z0, z1, n, seed, keep, kinds)
	local rng = Random.new(seed)
	local placed = {}
	local tries = 0
	while #placed < n and tries < n * 30 do
		tries += 1
		local p = Vector3.new(rng:NextNumber(x0, x1), 0, rng:NextNumber(z0, z1))
		local ok = true
		for _, k in ipairs(keep) do if (Vector3.new(p.X, 0, p.Z) - k[1]).Magnitude < k[2] then ok = false break end end
		if ok then for _, q in ipairs(placed) do if (q - p).Magnitude < 22 then ok = false break end end end
		if ok then
			table.insert(placed, p)
			local kind = kinds and kinds(rng) or "tree"
			if kind == "pine" then Geo.pine(m, CFrame.new(p), 1, seed + #placed)
			elseif kind == "palm" then Geo.palm(m, CFrame.new(p), 1, seed + #placed)
			else Geo.tree(m, CFrame.new(p), 1, seed + #placed) end
			if rng:NextNumber() < 0.5 then Geo.bush(m, CFrame.new(p + Vector3.new(rng:NextNumber(-8, 8), 0, rng:NextNumber(-8, 8))), 1.1, seed + #placed * 3) end
			if rng:NextNumber() < 0.12 then Geo.kit(m, rng:NextNumber() < 0.5 and "Rock" or "RockLarge", CFrame.new(p + Vector3.new(rng:NextNumber(-12, 12), 0, rng:NextNumber(-12, 12))) * CFrame.Angles(0, rng:NextNumber() * 6.28, 0), 1, true) end
		end
	end
	return placed
end

-- the north park: a pond with a stone rim and a little island, a loop path, trees, benches, lamps
local function northPark(mall)
	local m = Geo.model(mall, "NorthPark")
	local z0, z1 = -542, -210
	lawn(m, -MH, MH, z0, z1)
	local c = Vector3.new(0, 0, (z0 + z1) / 2)
	local pond = Geo.model(m, "Pond")
	Geo.cyl(pond, 58, 1.2, CFrame.new(c + Vector3.new(0, 0.6, 0)), P.stone, Enum.Material.SmoothPlastic, { Name = "Rim" })
	Geo.cyl(pond, 54, 1.25, CFrame.new(c + Vector3.new(0, 0.62, 0)), P.water, Enum.Material.Glass, { Name = "Water", Transparency = 0.15, Reflectance = 0.25 })
	Geo.cyl(pond, 12, 1.6, CFrame.new(c + Vector3.new(14, 0.8, -8)), P.grassDark, Enum.Material.SmoothPlastic, { Name = "Isle" })
	Geo.tree(pond, CFrame.new(c + Vector3.new(14, 1.6, -8)), 0.9, 77)
	-- the loop path around the pond and paths in from the four sides
	local R = 72
	local seg = 20
	for i = 0, seg - 1 do
		local a0, a1 = i / seg * math.pi * 2, (i + 1) / seg * math.pi * 2
		path(m, c + Vector3.new(math.cos(a0) * R, 0, math.sin(a0) * R), c + Vector3.new(math.cos(a1) * R, 0, math.sin(a1) * R), 10)
	end
	path(m, Vector3.new(0, 0, z0), c + Vector3.new(0, 0, -R), 10)
	path(m, c + Vector3.new(0, 0, R), Vector3.new(0, 0, z1), 10)
	path(m, Vector3.new(-MH, 0, c.Z), c + Vector3.new(-R, 0, 0), 10)
	path(m, c + Vector3.new(R, 0, 0), Vector3.new(MH, 0, c.Z), 10)
	-- benches and lamps along the loop
	for i = 0, 7 do
		local a = i / 8 * math.pi * 2 + math.pi / 8
		local p = c + Vector3.new(math.cos(a) * (R - 8), 0, math.sin(a) * (R - 8))
		Geo.bench(m, CFrame.lookAt(p, c))
		local lp = c + Vector3.new(math.cos(a + 0.2) * (R + 7), 0, math.sin(a + 0.2) * (R + 7))
		Geo.lamp(m, CFrame.lookAt(lp, c))
	end
	for i = 0, 5 do
		local a = i / 6 * math.pi * 2
		Geo.flowerBed(m, CFrame.lookAt(c + Vector3.new(math.cos(a) * (R + 20), 0.3, math.sin(a) * (R + 20)), c), 16, 6, 600 + i)
	end
	scatter(m, -MH + 10, MH - 10, z0 + 10, z1 - 10, 22, 300, { { c, R + 32 } })
	return m
end

-- the south park: a white bandstand on a round lawn, paths to the beach, trees and flowers
local function southPark(mall)
	local m = Geo.model(mall, "SouthPark")
	local z0, z1 = 210, 542
	lawn(m, -MH, MH, z0, z1)
	local c = Vector3.new(0, 0, (z0 + z1) / 2)
	path(m, Vector3.new(0, 0, z0), Vector3.new(0, 0, z1), 14)
	path(m, Vector3.new(-MH, 0, c.Z), Vector3.new(MH, 0, c.Z), 10)
	-- the bandstand: an octagonal deck, white posts, a red roof with a gold finial
	local b = Geo.model(m, "Bandstand")
	Geo.cyl(b, 26, 2.4, CFrame.new(c + Vector3.new(0, 1.2, 0)), P.stone, Enum.Material.SmoothPlastic, { Name = "Deck" })
	Geo.cyl(b, 27, 0.6, CFrame.new(c + Vector3.new(0, 2.5, 0)), P.cream, Enum.Material.SmoothPlastic, { Name = "DeckRim" })
	for i = 0, 7 do
		local a = i / 8 * math.pi * 2
		Geo.cyl(b, 0.8, 14, CFrame.new(c + Vector3.new(math.cos(a) * 22, 9.8, math.sin(a) * 22)), P.white, Enum.Material.SmoothPlastic, { Name = "Post" })
		Geo.box(b, Vector3.new(16, 0.8, 0.8), CFrame.new(c + Vector3.new(math.cos(a + math.pi / 8) * 20.4, 4.6, math.sin(a + math.pi / 8) * 20.4)) * CFrame.Angles(0, -(a + math.pi / 8) + math.pi / 2, 0), P.white, Enum.Material.SmoothPlastic, { Name = "Rail" })
	end
	for i = 0, 7 do
		local a = i / 8 * math.pi * 2
		local r0 = CFrame.new(c + Vector3.new(0, 17, 0)) * CFrame.Angles(0, -a, 0)
		Geo.wedge(b, Vector3.new(19.9, 7, 24), r0 * CFrame.new(0, 3.5, 12) * CFrame.Angles(0, math.pi, 0), i % 2 == 0 and P.red or P.cream, Enum.Material.SmoothPlastic, { Name = "Roof" })
	end
	Geo.ball(b, 1.6, CFrame.new(c + Vector3.new(0, 25, 0)), P.gold, Enum.Material.Metal, { Name = "Finial" })
	for i = 0, 7 do
		local a = i / 8 * math.pi * 2 + math.pi / 8
		Geo.flowerBed(m, CFrame.lookAt(c + Vector3.new(math.cos(a) * 44, 0.3, math.sin(a) * 44), c), 14, 5, 700 + i)
		if i % 2 == 0 then Geo.lamp(m, CFrame.lookAt(c + Vector3.new(math.cos(a) * 56, 0.3, math.sin(a) * 56), c)) end
		if i % 2 == 1 then Geo.bench(m, CFrame.lookAt(c + Vector3.new(math.cos(a) * 36, 0.3, math.sin(a) * 36), c)) end
	end
	scatter(m, -MH + 10, MH - 10, z0 + 10, z1 - 10, 20, 500, { { c, 66 }, { Vector3.new(0, 0, z0 + 40), 14 }, { Vector3.new(0, 0, z1 - 40), 14 } })
	-- a row of palms where the park meets the beach road
	for x = -MH + 15, MH - 15, 30 do Geo.palm(m, CFrame.new(x, 0.3, z1 - 8), 0.9, 800 + x) end
	return m
end

-- The beach and the pier -------------------------------------------------------------------------------------------
local function beach(world)
	local f = Geo.folder(world, "Beach")
	-- palms along the shore, a few beach umbrellas and towels
	local rng = Random.new(61)
	for x = ISLAND.x0 + 120, ISLAND.x1 - 120, 46 do
		local z = ISLAND.z1 + rng:NextNumber(10, 50)
		Geo.palm(f, CFrame.new(x + rng:NextNumber(-10, 10), -0.7, z), 1, math.floor(x))
		if rng:NextNumber() < 0.5 and math.abs(x) > 40 then
			local p = Vector3.new(x + rng:NextNumber(10, 22), -0.7, ISLAND.z1 + rng:NextNumber(30, 60))
			local col = Geo.Accents[rng:NextInteger(1, #Geo.Accents)]
			Geo.cyl(f, 0.3, 9, CFrame.new(p + Vector3.new(0, 4.5, 0)), P.white, Enum.Material.SmoothPlastic, { Name = "UmbrellaPole" })
			for k = 0, 7 do
				local a = k / 8 * math.pi * 2
				Geo.wedge(f, Vector3.new(5, 1.6, 6), CFrame.new(p + Vector3.new(0, 9, 0)) * CFrame.Angles(0, -a, 0) * CFrame.new(0, -0.6, 3) * CFrame.Angles(0, math.pi, 0), k % 2 == 0 and col or P.white, Enum.Material.Fabric, { Name = "Umbrella", CanCollide = false })
			end
			Geo.box(f, Vector3.new(4, 0.1, 9), CFrame.new(p + Vector3.new(4, 0.05, 2)) * CFrame.Angles(0, rng:NextNumber(-0.4, 0.4), 0), Geo.Accents[rng:NextInteger(1, #Geo.Accents)], Enum.Material.Fabric, { Name = "Towel", CanCollide = false })
		end
	end
	-- the pier: from the south park's path straight out to sea
	local pier = Geo.model(f, "Pier")
	local z0, z1 = EZ + 30, ISLAND.z1 + 260
	local wood = Color3.fromRGB(176, 128, 84)
	Geo.box(pier, Vector3.new(18, 1, z1 - z0), CFrame.new(0, 1.2, (z0 + z1) / 2), wood, Enum.Material.WoodPlanks, { Name = "Deck" })
	for z = z0 + 10, z1, 20 do
		for s = -1, 1, 2 do
			Geo.cyl(pier, 0.9, 12, CFrame.new(s * 8, -4.6, z), Color3.fromRGB(120, 86, 56), Enum.Material.Wood, { Name = "Pile" })
			Geo.box(pier, Vector3.new(0.6, 3, 0.6), CFrame.new(s * 8.6, 3.2, z), wood, Enum.Material.Wood, { Name = "Post" })
		end
		if (z - z0) % 60 < 20 then Geo.lamp(pier, CFrame.new(-8.6, 1.7, z) * CFrame.Angles(0, -math.pi / 2, 0)) end
	end
	for s = -1, 1, 2 do Geo.box(pier, Vector3.new(0.6, 0.6, z1 - z0), CFrame.new(s * 8.6, 4.4, (z0 + z1) / 2), wood, Enum.Material.Wood, { Name = "Rail" }) end
	-- the pier head: a wider deck with benches
	Geo.box(pier, Vector3.new(50, 1, 30), CFrame.new(0, 1.2, z1 + 14), wood, Enum.Material.WoodPlanks, { Name = "Head" })
	for s = -1, 1, 2 do Geo.bench(pier, CFrame.new(s * 14, 1.7, z1 + 24) * CFrame.Angles(0, math.pi, 0)) end
	-- the path from the city to the pier across the sand
	Geo.box(f, Vector3.new(16, 0.6, z0 - EZ + 10), CFrame.new(0, 0.3, (EZ + z0) / 2), wood, Enum.Material.WoodPlanks, { Name = "Boardwalk" })
	return f
end

-- Nature: the forest belts around the city and wooded hills to the north ----------------------------------------------
function M.nature(world)
	local f = Geo.folder(world, "Nature")
	-- the hills (soft green mounds) behind the northern forest
	local rng = Random.new(17)
	for i = 0, 9 do
		local x = ISLAND.x0 + 160 + i * ((ISLAND.x1 - ISLAND.x0 - 320) / 9) + rng:NextNumber(-60, 60)
		local z = ISLAND.z0 + 170 + rng:NextNumber(-40, 40)
		local r = rng:NextNumber(150, 230)
		local h = rng:NextNumber(60, 110)
		-- (an ellipsoid: a block with a sphere mesh; nobody walks up there)
		local hill = Geo.box(f, Vector3.new(r * 2, h * 2, r * 2), CFrame.new(x, 0, z), (i % 2 == 0) and P.grassDark or P.grass, Enum.Material.SmoothPlastic, { Name = "Hill", CanCollide = false })
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = hill
	end
	local keep = {}
	local function kinds(r) local v = r:NextNumber() return v < 0.35 and "pine" or "tree" end
	-- north belt (between the city and the hills), east and west belts
	scatter(f, ISLAND.x0 + 60, ISLAND.x1 - 60, ISLAND.z0 + 330, -EZ - 40, 120, 1001, keep, kinds)
	scatter(f, EX + 40, ISLAND.x1 - 50, -EZ - 40, ISLAND.z1 - 40, 70, 2001, keep, kinds)
	scatter(f, ISLAND.x0 + 50, -EX - 40, -EZ - 40, ISLAND.z1 - 40, 70, 3001, keep, kinds)
	-- a strip of lawn trees between the southern arterial and the beach (keep the pier path clear)
	scatter(f, -EX, EX, EZ + 25, ISLAND.z1 - 30, 40, 4001, { { Vector3.new(0, 0, EZ + 60), 40 } }, function(r) return r:NextNumber() < 0.6 and "palm" or "tree" end)
	return f
end

-- The district gates -----------------------------------------------------------------------------------------------------
-- an arch over the district's centre street, just inside the boulevard, with the city's name (set at runtime)
local function gate(parent, k)
	local base = Geo.districtCF(k) * CFrame.new(0, 0, 12)
	local m = Geo.model(parent, "Gate")
	m:SetAttribute("District", k)
	local span = 21.5
	for s = -1, 1, 2 do
		Geo.box(m, Vector3.new(5, 30, 5), base * CFrame.new(s * span, 15 + Geo.WalkY, 0), P.stone, Enum.Material.SmoothPlastic, { Name = "Pillar" })
		Geo.box(m, Vector3.new(6.4, 1.6, 6.4), base * CFrame.new(s * span, Geo.WalkY + 0.8, 0), P.stoneDark, Enum.Material.SmoothPlastic, { Name = "Foot" })
		Geo.box(m, Vector3.new(6, 1.4, 6), base * CFrame.new(s * span, 30.7 + Geo.WalkY, 0), P.gold, Enum.Material.Metal, { Name = "Cap" })
		Geo.ball(m, 1.8, base * CFrame.new(s * span, 33.2 + Geo.WalkY, 0), P.gold, Enum.Material.Metal, { Name = "Orb" })
	end
	local beam = Geo.box(m, Vector3.new(span * 2 + 6, 6.4, 3.6), base * CFrame.new(0, 26 + Geo.WalkY, 0), P.navy, Enum.Material.SmoothPlastic, { Name = "Sign" })
	Geo.box(m, Vector3.new(span * 2 + 7, 0.8, 4), base * CFrame.new(0, 29.6 + Geo.WalkY, 0), P.gold, Enum.Material.Metal, { Name = "Trim" })
	Geo.box(m, Vector3.new(span * 2 + 7, 0.8, 4), base * CFrame.new(0, 22.4 + Geo.WalkY, 0), P.gold, Enum.Material.Metal, { Name = "Trim" })
	for _, face in ipairs({ Enum.NormalId.Front, Enum.NormalId.Back }) do
		local sg = Instance.new("SurfaceGui")
		sg.Name = "Name" .. face.Name
		sg.Face = face
		sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		sg.PixelsPerStud = 24
		sg.LightInfluence = 0
		sg.MaxDistance = 600
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

-- Lighting ------------------------------------------------------------------------------------------------------------
function M.lighting()
	local L = game:GetService("Lighting")
	L.ClockTime = 14.2
	L.GeographicLatitude = 28
	L.Brightness = 2.8
	L.ExposureCompensation = 0.05
	L.Ambient = Color3.fromRGB(100, 104, 124)
	L.OutdoorAmbient = Color3.fromRGB(150, 152, 170)
	L.ColorShift_Top = Color3.fromRGB(255, 240, 214)
	L.ColorShift_Bottom = Color3.fromRGB(0, 0, 0)
	L.EnvironmentDiffuseScale = 1
	L.EnvironmentSpecularScale = 1
	L.GlobalShadows = true
	L.ShadowSoftness = 0.2
	local function get(class, name)
		local x = L:FindFirstChildOfClass(class) or Instance.new(class)
		x.Name = name
		x.Parent = L
		return x
	end
	local atm = get("Atmosphere", "Atmosphere")
	atm.Density = 0.28
	atm.Offset = 0.2
	atm.Color = Color3.fromRGB(206, 226, 255)
	atm.Decay = Color3.fromRGB(130, 160, 214)
	atm.Glare = 0.2
	atm.Haze = 1.1
	local cc = get("ColorCorrectionEffect", "ColorCorrection")
	cc.Brightness = 0.02
	cc.Contrast = 0.12
	cc.Saturation = 0.18
	cc.TintColor = Color3.fromRGB(255, 250, 242)
	local bloom = get("BloomEffect", "Bloom")
	bloom.Intensity = 0.5
	bloom.Size = 26
	bloom.Threshold = 1.7
	local rays = get("SunRaysEffect", "SunRays")
	rays.Intensity = 0.05
	rays.Spread = 0.6
	local sky = get("Sky", "Sky")
	sky.SunAngularSize = 14
	sky.MoonAngularSize = 10
	sky.CelestialBodiesShown = true
	sky.StarCount = 2500
end

function M.build()
	assert(game.PlaceId == 97174353381365, "BlockRise DEV only")
	local old = workspace:FindFirstChild("World")
	if old then old:Destroy() end
	local world = Instance.new("Folder")
	world.Name = "World"
	M.lighting()
	M.ground(world)
	M.streets(world)
	local mall = Geo.folder(world, "Mall")
	plaza(mall)
	northPark(mall)
	southPark(mall)
	beach(world)
	M.nature(world)
	local districts = Geo.folder(world, "Districts")
	for k = 1, 6 do
		local f = Geo.folder(districts, "D" .. k)
		gate(f, k)
	end
	world.Parent = workspace
	return world
end

return M
