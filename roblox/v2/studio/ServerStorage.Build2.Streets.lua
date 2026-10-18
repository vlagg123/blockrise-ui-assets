-- BlockRise 2.0 - streets: one road segment or one crossing of a district, built from parts in the district's
-- local frame (Geo). Streets.build returns the model and its parts in build order, so the City can play the
-- self-building animation (asphalt, curbs, sidewalks, markings, lamps, trees).
local Geo = require(script.Parent.Geo)
local P = Geo.Pal
local M = {}

local ROAD_H, WALK_H = 0.7, Geo.WalkY

-- local helper: a CFrame in the district frame
local function at(base, x, y, z) return base * CFrame.new(x, y, z) end

local function stage(list, n, part) list[n] = list[n] or {} table.insert(list[n], part) return part end

-- one straight segment: rect centre (cx, cz), length len, along Z (avenue / side street) or X (cross street)
local function segment(base, m, id, cx, cz, len, alongZ, stages, seed)
	-- rot: the segment's own frame, its run along local X
	local rot = at(base, cx, 0, cz) * (alongZ and CFrame.Angles(0, math.pi / 2, 0) or CFrame.new())
	local half = Geo.StreetW / 2
	local roadHalf = half - Geo.Walk
	stage(stages, 1, Geo.box(m, Vector3.new(len, ROAD_H, roadHalf * 2), rot * CFrame.new(0, Geo.RoadY - ROAD_H / 2, 0), P.asphalt, Enum.Material.Asphalt, { Name = "Road" }))
	for s = -1, 1, 2 do
		stage(stages, 2, Geo.box(m, Vector3.new(len, WALK_H + 0.05, 0.7), rot * CFrame.new(0, (WALK_H + 0.05) / 2, s * (roadHalf + 0.35)), P.curb, Enum.Material.Concrete, { Name = "Curb" }))
		stage(stages, 3, Geo.box(m, Vector3.new(len, WALK_H, Geo.Walk - 0.7), rot * CFrame.new(0, WALK_H / 2, s * (roadHalf + 0.7 + (Geo.Walk - 0.7) / 2)), P.sidewalk, Enum.Material.Pavement, { Name = "Walk" }))
	end
	-- the centre line: dashes
	local n = math.floor((len - 8) / 12)
	for i = 0, n - 1 do
		local x = -((n - 1) * 12) / 2 + i * 12
		stage(stages, 4, Geo.box(m, Vector3.new(6, 0.06, 0.45), rot * CFrame.new(x, Geo.RoadY + 0.02, 0), P.lane, Enum.Material.SmoothPlastic, { Name = "Line", CanCollide = false }))
	end
	-- lamps (one each side, staggered) and trees in the sidewalk
	for s = -1, 1, 2 do
		local walkZ = s * (roadHalf + 0.7 + (Geo.Walk - 0.7) / 2)
		local lx = s * len * 0.22
		local lampCF = rot * CFrame.new(lx, WALK_H, walkZ) * CFrame.Angles(0, s < 0 and 0 or math.pi, 0)
		local lamp = Geo.lamp(m, lampCF)
		stage(stages, 5, lamp)
		for _, tx in ipairs({ -len * 0.36, len * 0.06 * -s, len * 0.36 }) do
			if math.abs(tx - lx) > 10 then
				local pit = Geo.box(m, Vector3.new(3.4, 0.08, 3.4), rot * CFrame.new(tx, WALK_H + 0.02, walkZ), P.dirt, Enum.Material.Ground, { Name = "Pit", CanCollide = false })
				stage(stages, 5, pit)
				stage(stages, 6, Geo.tree(m, rot * CFrame.new(tx, WALK_H, walkZ), 0.85, seed + math.floor(tx * 7 + s * 13)))
			end
		end
	end
end

local function crossing(base, m, cx, cz, stages)
	local c = at(base, cx, 0, cz)
	local half = Geo.StreetW / 2
	local roadHalf = half - Geo.Walk
	stage(stages, 1, Geo.box(m, Vector3.new(Geo.StreetW, ROAD_H, Geo.StreetW), c * CFrame.new(0, Geo.RoadY - ROAD_H / 2, 0), P.asphalt, Enum.Material.Asphalt, { Name = "Road" }))
	-- the 4 sidewalk corners
	for sx = -1, 1, 2 do
		for sz = -1, 1, 2 do
			local o = roadHalf + Geo.Walk / 2
			stage(stages, 3, Geo.box(m, Vector3.new(Geo.Walk, WALK_H, Geo.Walk), c * CFrame.new(sx * o, WALK_H / 2, sz * o), P.sidewalk, Enum.Material.Pavement, { Name = "Corner" }))
		end
	end
	-- crosswalks on the 4 sides (kept inside their own side: the stripes of two sides never touch)
	for side = 0, 3 do
		local r = c * CFrame.Angles(0, side * math.pi / 2, 0)
		for i = -2, 2 do
			stage(stages, 4, Geo.box(m, Vector3.new(1.2, 0.06, 2.6), r * CFrame.new(i * 2.5, Geo.RoadY + 0.02, roadHalf - 1.5), P.lane, Enum.Material.SmoothPlastic, { Name = "Zebra", CanCollide = false }))
		end
	end
end

-- build one street piece (a segment id like "X1_2", "A2", "S1_1" or a crossing "I0_0") in district k
-- returns the model and the stages { [1] = { parts }, ... }
function M.build(parent, k, id)
	local base = Geo.districtCF(k)
	local m = Geo.model(parent, id)
	local stages = {}
	local cx, cz, len, alongZ = Geo.segRect(id)
	if id:sub(1, 1) == "I" then
		crossing(base, m, cx, cz, stages)
	else
		segment(base, m, id, cx, cz, len, alongZ, stages, k * 1000 + #id * 37 + math.floor(cx + cz))
	end
	return m, stages
end

return M
