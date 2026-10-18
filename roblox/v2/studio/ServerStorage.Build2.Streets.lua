-- BlockRise 2.0 - streets (MAP v3): straight road pieces and crossings, from parts and the kit (lamps, trees, benches,
-- bins, hydrants, parked cars). Used by WorldGen for the permanent grid (boulevards, arterials, the perimeter road)
-- and by the City for a district's own streets, which build themselves when a block is bought: Streets.build returns
-- the model and its parts in build order (asphalt, curbs, sidewalks, markings, furniture, trees).
local Geo = require(script.Parent.Geo)
local P = Geo.Pal
local M = {}

local ROAD_T = 0.6

local function stage(list, n, item)
	if list then list[n] = list[n] or {} table.insert(list[n], item) end
	return item
end
M.stage = stage

-- the parts' look
local function road(m, size, cf) return Geo.box(m, size, cf, P.asphalt, Enum.Material.Asphalt, { Name = "Road" }) end
local function walk(m, size, cf) return Geo.box(m, size, cf, P.sidewalk, Enum.Material.Pavement, { Name = "Walk" }) end
local function curb(m, size, cf) return Geo.box(m, size, cf, P.curb, Enum.Material.Concrete, { Name = "Curb" }) end
local function paint(m, size, cf, col) return Geo.box(m, size, cf, col or P.lane, Enum.Material.SmoothPlastic, { Name = "Paint", CanCollide = false, CanQuery = false }) end

-- One straight piece: centred at cf (ground level), running along cf's X for `len`, `width` across (Z), with
-- sidewalks of `walkW` on both sides. o.line: "dash" (a white dashed centre line) or "blvd" (a double yellow centre
-- line and dashed lanes). o.dress: lamps, trees, furniture (seeded); o.cars: a few parked cars
function M.segment(m, cf, len, width, walkW, o, stages)
	o = o or {}
	local roadW = width - 2 * walkW
	local rng = Random.new(o.seed or 7)
	stage(stages, 1, road(m, Vector3.new(len, ROAD_T, roadW), cf * CFrame.new(0, Geo.RoadY - ROAD_T / 2, 0)))
	for s = -1, 1, 2 do
		stage(stages, 2, curb(m, Vector3.new(len, Geo.WalkY + 0.1, 0.8), cf * CFrame.new(0, (Geo.WalkY + 0.1) / 2 - 0.05, s * (roadW / 2 + 0.4))))
		stage(stages, 3, walk(m, Vector3.new(len, Geo.WalkY, walkW - 0.8), cf * CFrame.new(0, Geo.WalkY / 2, s * (roadW / 2 + 0.8 + (walkW - 0.8) / 2))))
	end
	-- markings
	local y = Geo.RoadY + 0.03
	if o.line == "blvd" then
		for s = -1, 1, 2 do stage(stages, 4, paint(m, Vector3.new(len, 0.06, 0.4), cf * CFrame.new(0, y, s * 0.45), P.laneYellow)) end
		local n = math.floor(len / 14)
		for s = -1, 1, 2 do
			for i = 0, n - 1 do
				stage(stages, 4, paint(m, Vector3.new(7, 0.06, 0.4), cf * CFrame.new(-len / 2 + 7 + i * 14, y, s * roadW / 4)))
			end
		end
	else
		local n = math.floor(len / 14)
		for i = 0, n - 1 do
			stage(stages, 4, paint(m, Vector3.new(7, 0.06, 0.45), cf * CFrame.new(-len / 2 + 7 + i * 14, y, 0)))
		end
	end
	if o.dress == false then return end
	-- the sidewalks' life: lamps (staggered), trees in pits, now and then a bench, a bin or a hydrant
	for s = -1, 1, 2 do
		local lampZ = s * (roadW / 2 + 2.2)
		local face = s < 0 and CFrame.Angles(0, math.pi, 0) or CFrame.new()  -- the arm toward the road
		local spacing = o.lampSpacing or 64
		local nL = math.max(1, math.floor(len / spacing))
		for i = 0, nL - 1 do
			local x = -len / 2 + (i + 0.5 + (s > 0 and 0.5 or 0)) * (len / nL)
			if x < len / 2 - 6 then
				stage(stages, 5, Geo.lamp(m, cf * CFrame.new(x, Geo.WalkY, lampZ) * face))
			end
		end
		if o.trees ~= false and walkW >= 9 then
			local tSpacing = o.treeSpacing or 32
			local nT = math.max(1, math.floor(len / tSpacing))
			for i = 0, nT - 1 do
				local x = -len / 2 + (i + 0.5) * (len / nT) + (s > 0 and tSpacing * 0.25 or 0)
				if math.abs(x) < len / 2 - 8 then
					local tz = s * (roadW / 2 + walkW * 0.62)
					stage(stages, 5, Geo.box(m, Vector3.new(4.4, 0.1, 4.4), cf * CFrame.new(x, Geo.WalkY + 0.02, tz), P.dirt, Enum.Material.Ground, { Name = "Pit", CanCollide = false }))
					stage(stages, 6, Geo.tree(m, cf * CFrame.new(x, Geo.WalkY, tz), o.treeScale or 0.75, (o.seed or 1) * 31 + i * 7 + s))
				end
			end
		end
		-- furniture by the curb
		local furn = { "TrashBin", "Hydrant", "Bench", "Mailbox" }
		local nF = math.floor(len / 70)
		for i = 1, nF do
			if rng:NextNumber() < 0.75 then
				local key = furn[rng:NextInteger(1, #furn)]
				local x = -len / 2 + i * (len / (nF + 1)) + rng:NextNumber(-6, 6)
				local fz = s * (roadW / 2 + walkW - 1.6)
				local turn = (s < 0) and 0 or math.pi
				if key == "Bench" then fz = s * (roadW / 2 + walkW - 1.4) end
				stage(stages, 6, Geo.kit(m, key, cf * CFrame.new(x, Geo.WalkY, fz) * CFrame.Angles(0, turn, 0), 1, key ~= "Mailbox"))
			end
		end
		-- parked cars by the curb (pointing along the traffic of their lane)
		if o.cars then
			local cars = { "CarHatch", "CarWagon", "Taxi", "CarHatch", "CarWagon", "Police" }
			local nC = math.floor(len / 40)
			for i = 1, nC do
				if rng:NextNumber() < o.cars then
					local x = -len / 2 + i * (len / (nC + 1))
					local cz = s * (roadW / 2 - 3.6)
					stage(stages, 6, Geo.kit(m, cars[rng:NextInteger(1, #cars)], cf * CFrame.new(x, Geo.RoadY, cz) * CFrame.Angles(0, s < 0 and -math.pi / 2 or math.pi / 2, 0), 1, true))
				end
			end
		end
	end
end

-- A crossing: sizeX (the width of the street running along Z) by sizeZ (the width of the street running along X),
-- centred at cf. walkX / walkZ: those streets' sidewalk widths. open = { px = true, nx = true, pz = true, nz = true }:
-- the sides a street leaves through (a closed side gets a straight sidewalk instead of a road mouth)
function M.junction(m, cf, sizeX, sizeZ, walkX, walkZ, open, stages)
	stage(stages, 1, road(m, Vector3.new(sizeX, ROAD_T, sizeZ), cf * CFrame.new(0, Geo.RoadY - ROAD_T / 2, 0)))
	local hx, hz = sizeX / 2, sizeZ / 2
	-- the corner squares
	for sx = -1, 1, 2 do
		for sz = -1, 1, 2 do
			stage(stages, 3, walk(m, Vector3.new(walkX, Geo.WalkY, walkZ), cf * CFrame.new(sx * (hx - walkX / 2), Geo.WalkY / 2, sz * (hz - walkZ / 2))))
		end
	end
	local y = Geo.RoadY + 0.03
	-- the sides: a road mouth with a crosswalk, or a sidewalk closing it
	local sides = {
		{ key = "px", dir = Vector3.new(1, 0, 0), across = sizeZ - 2 * walkZ, depth = walkX, at = hx },
		{ key = "nx", dir = Vector3.new(-1, 0, 0), across = sizeZ - 2 * walkZ, depth = walkX, at = hx },
		{ key = "pz", dir = Vector3.new(0, 0, 1), across = sizeX - 2 * walkX, depth = walkZ, at = hz },
		{ key = "nz", dir = Vector3.new(0, 0, -1), across = sizeX - 2 * walkX, depth = walkZ, at = hz },
	}
	for _, sd in ipairs(sides) do
		local rot = CFrame.lookAt(Vector3.zero, sd.dir) -- local -Z points out of this side
		if open[sd.key] then
			-- zebra stripes across the mouth (each stripe runs along the street)
			local n = math.floor(sd.across / 3.2)
			for i = 0, n - 1 do
				local a = -sd.across / 2 + 1.6 + i * (sd.across / n)
				stage(stages, 4, paint(m, Vector3.new(1.7, 0.06, 6), cf * rot * CFrame.new(a, y, -(sd.at - sd.depth / 2))))
			end
		else
			stage(stages, 3, walk(m, Vector3.new(sd.across, Geo.WalkY, sd.depth), cf * rot * CFrame.new(0, Geo.WalkY / 2, -(sd.at - sd.depth / 2))))
			stage(stages, 2, curb(m, Vector3.new(sd.across, Geo.WalkY + 0.1, 0.8), cf * rot * CFrame.new(0, (Geo.WalkY + 0.1) / 2 - 0.05, -(sd.at - sd.depth - 0.4))))
		end
	end
end

-- a district piece (a centre street segment "A<row>", a cross street "X<j>_<side>" or a crossing "I<j>_0") in district
-- k; returns the model and the stages { [1] = { parts }, ... }
function M.build(parent, k, id)
	local base = Geo.districtCF(k)
	local m = Geo.model(parent, id)
	local stages = {}
	local cx, cz, len, alongZ = Geo.segRect(id)
	if alongZ == nil then
		M.junction(m, base * CFrame.new(cx, 0, cz), Geo.StreetW, Geo.StreetW, Geo.Walk, Geo.Walk, { px = true, nx = true, pz = true, nz = true }, stages)
	else
		local cf = base * CFrame.new(cx, 0, cz) * (alongZ and CFrame.Angles(0, math.pi / 2, 0) or CFrame.new())
		M.segment(m, cf, len, Geo.StreetW, Geo.Walk, { line = "dash", seed = k * 1000 + #id * 37 + math.floor(cx + cz), cars = 0.35 }, stages)
	end
	return m, stages
end

return M
