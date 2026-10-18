-- BlockRise 2.0 - BLUEPRINTS 2 (STYLE_V1, 2026-10-18; the owner: "new, really cool buildings, in the live game's
-- style"). The live game's construction framework, unchanged (pieces, materials, stages: clearing, excavation, rebar,
-- foundation, walls course by course, windows, roof, doors, finishing; the steel frame of the tall ones), and a new set
-- of 20 buildings for the city's 10 levels (2 styles each), designed for 2.0.
-- Procedural building blueprints. Every building is a list of stages; each stage
-- reveals pieces (adds) and/or removes pieces (removes) as work progresses.
-- Coordinates are relative to the build origin (front of building = local -Z).
-- Rule: no two visible faces may be coplanar & overlapping (no z-fighting).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local M = Config.Mat

local B = {}

local C = {
	wetConcrete = Color3.fromRGB(112, 114, 118),
	concrete = Color3.fromRGB(200, 200, 196),
	brick = Color3.fromRGB(190, 104, 80),
	lumber = Color3.fromRGB(222, 186, 136),
	darkWood = Color3.fromRGB(92, 62, 42),
	shingle = Color3.fromRGB(78, 80, 88),
	redRoof = Color3.fromRGB(170, 70, 55),
	stucco = Color3.fromRGB(244, 238, 226),
	stuccoWarm = Color3.fromRGB(236, 214, 178),
	dirt = Color3.fromRGB(132, 98, 66),
	rebar = Color3.fromRGB(128, 74, 52),
	glass = Color3.fromRGB(150, 196, 228),
	trim = Color3.fromRGB(248, 248, 244),
	darkTrim = Color3.fromRGB(46, 48, 54),
	metal = Color3.fromRGB(206, 210, 216),
}
B.Colors = C

local function P(size, cf, mat, col, extra)
	local p = { s = size, c = (typeof(cf) == "Vector3") and CFrame.new(cf) or cf, m = mat[1], v = mat[2], col = col }
	if extra then for k, v in pairs(extra) do p[k] = v end end
	return p
end
local function plain(material) return { material, nil } end
local function append(dst, src) for _, v in ipairs(src) do table.insert(dst, v) end return dst end

-- Building blocks ---------------------------------------------------------
local function debris(rng, w, d, count)
	local list = {}
	for _ = 1, count do
		local x, z = rng:NextNumber(-w / 2, w / 2), rng:NextNumber(-d / 2, d / 2)
		local kind = rng:NextInteger(1, 3)
		if kind == 1 then
			local s = rng:NextNumber(1.4, 2.8)
			table.insert(list, P(Vector3.new(s, s * 0.7, s * 0.9), CFrame.new(x, s * 0.25, z) * CFrame.Angles(rng:NextNumber(-0.4, 0.4), rng:NextNumber(0, 6), rng:NextNumber(-0.4, 0.4)),
				plain(Enum.Material.Slate), Color3.fromRGB(128, 126, 122)))
		elseif kind == 2 then
			local len = rng:NextNumber(4, 7)
			table.insert(list, P(Vector3.new(len, 0.4, 0.9), CFrame.new(x, 0.45, z) * CFrame.Angles(rng:NextNumber(-0.25, 0.25), rng:NextNumber(0, 6.28), rng:NextNumber(-0.2, 0.2)),
				M.lumber, C.lumber:Lerp(Color3.fromRGB(90, 80, 70), 0.45)))
		else
			local s = rng:NextNumber(2.2, 3.6)
			table.insert(list, P(Vector3.one * s, CFrame.new(x, s * 0.3, z), plain(Enum.Material.LeafyGrass), Color3.fromRGB(86, 126, 62), { shape = "Ball" }))
		end
	end
	return list
end

-- Topsoil cells, removed during excavation (exact tiling, no overlap)
local function soil(w, d, cell, h)
	local list = {}
	local nx, nz = math.max(1, math.round(w / cell)), math.max(1, math.round(d / cell))
	local cx, cz = w / nx, d / nz
	for iz = nz - 1, 0, -1 do
		for ix = 0, nx - 1 do
			local x, z = -w / 2 + cx * (ix + 0.5), -d / 2 + cz * (iz + 0.5)
			table.insert(list, P(Vector3.new(cx, h, cz), Vector3.new(x, h / 2, z), M.dirt, C.dirt))
		end
	end
	return list
end

local function spoilPile(pos, maxSize, n)
	local list = {}
	for i = 1, n do
		local f = i / n
		local s = maxSize * (0.4 + 0.6 * f)
		local off = Vector3.new(((i % 3) - 1) * s * 0.22, s * 0.18, (((i + 1) % 3) - 1) * s * 0.2)
		table.insert(list, P(Vector3.one * s, CFrame.new(pos + off), plain(Enum.Material.Sand),
			Color3.fromRGB(176, 136, 96):Lerp(Color3.fromRGB(150, 112, 78), (i % 2) * 0.5), { shape = "Ball", anim = "grow" }))
	end
	return list
end

local function rebar(w, d, spacing, y)
	local list = {}
	for x = -w / 2 + 1, w / 2 - 1, spacing do
		table.insert(list, P(Vector3.new(0.25, 0.25, d - 1), Vector3.new(x, y, 0), plain(Enum.Material.CorrodedMetal), C.rebar, { anim = "drop", noCollide = true }))
	end
	for z = -d / 2 + 1, d / 2 - 1, spacing do
		table.insert(list, P(Vector3.new(w - 1, 0.25, 0.25), Vector3.new(0, y + 0.25, z), plain(Enum.Material.CorrodedMetal), C.rebar, { anim = "drop", noCollide = true }))
	end
	return list
end

local function slab(w, d, total, layers)
	local list = {}
	local lh = total / layers
	for i = 1, layers do
		table.insert(list, P(Vector3.new(w, lh, d), Vector3.new(0, lh * (i - 0.5), 0), M.concrete, C.wetConcrete, { anim = "rise", concrete = true }))
	end
	return list
end

-- Walls built course by course. Row boundaries are snapped to every opening
-- edge, so openings are cut exactly to size (no gaps, no slivers).
local function walls(w, d, y0, h, t, rowH, mat, col, openings)
	local list = {}
	local rows = math.max(1, math.round(h / rowH))
	local rh = h / rows
	local edges = {}
	for _, o in ipairs(openings) do
		for _, y in ipairs({ o.bottom, o.top }) do
			if y > 0.01 and y < h - 0.01 then table.insert(edges, y) end
		end
	end
	local ys = { 0, h }
	for _, y in ipairs(edges) do table.insert(ys, y) end
	for r = 1, rows - 1 do
		local y = r * rh
		local near = false
		for _, e in ipairs(edges) do if math.abs(e - y) < 0.4 then near = true end end
		if not near then table.insert(ys, y) end
	end
	table.sort(ys)
	local cuts = {}
	for _, y in ipairs(ys) do
		if #cuts == 0 or y - cuts[#cuts] > 0.01 then table.insert(cuts, y) end
	end
	local sides = {
		front = { len = w, axis = "x", pos = function(a, y) return Vector3.new(a, y, -d / 2 + t / 2) end },
		back = { len = w, axis = "x", pos = function(a, y) return Vector3.new(a, y, d / 2 - t / 2) end },
		left = { len = d - 2 * t, axis = "z", pos = function(a, y) return Vector3.new(-w / 2 + t / 2, y, a) end },
		right = { len = d - 2 * t, axis = "z", pos = function(a, y) return Vector3.new(w / 2 - t / 2, y, a) end },
	}
	for r = 1, #cuts - 1 do
		local yb, yt = cuts[r], cuts[r + 1]
		for _, sideName in ipairs({ "front", "right", "back", "left" }) do
			local sd = sides[sideName]
			local segs = { { -sd.len / 2, sd.len / 2 } }
			for _, o in ipairs(openings) do
				if o.side == sideName and yt > o.bottom + 0.001 and yb < o.top - 0.001 then
					local oa, ob = o.a - o.width / 2, o.a + o.width / 2
					local new = {}
					for _, sg in ipairs(segs) do
						if ob <= sg[1] or oa >= sg[2] then
							table.insert(new, sg)
						else
							if oa > sg[1] + 0.05 then table.insert(new, { sg[1], oa }) end
							if ob < sg[2] - 0.05 then table.insert(new, { ob, sg[2] }) end
						end
					end
					segs = new
				end
			end
			for _, sg in ipairs(segs) do
				local len = sg[2] - sg[1]
				local a = (sg[1] + sg[2]) / 2
				local size = sd.axis == "x" and Vector3.new(len, yt - yb, t) or Vector3.new(t, yt - yb, len)
				table.insert(list, P(size, sd.pos(a, y0 + (yb + yt) / 2), mat, col, { anim = "drop", side = sideName }))
			end
		end
	end
	return list
end

-- CFrame of a point on a wall. Local frame: X along wall, -Z points outward.
local function onWall(w, d, side, a, y, out)
	out = out or 0
	if side == "front" then return CFrame.new(a, y, -d / 2 - out)
	elseif side == "back" then return CFrame.new(a, y, d / 2 + out) * CFrame.Angles(0, math.pi, 0)
	elseif side == "left" then return CFrame.new(-w / 2 - out, y, a) * CFrame.Angles(0, math.pi / 2, 0)
	else return CFrame.new(w / 2 + out, y, a) * CFrame.Angles(0, -math.pi / 2, 0) end
end

-- Gable roof: wall-material gable triangles + two sloped roof planes + trims
local function gableRoof(o, w, d, t, y)
	local list = {}
	local rise, over = o.rise or 5, o.over or 1.5
	local segs = o.roofSegs or math.max(3, math.floor(w / 4))
	local mat, col = o.roofMat or M.shingles, o.roofCol or C.shingle
	local run = d / 2
	local theta = math.atan2(rise, run)
	local c, s = math.cos(theta), math.sin(theta)
	local th = 0.6
	local L = w + over * 2
	local seg = L / segs
	local drop = over * math.tan(theta)
	-- gable ends in wall material (sit just under the roof planes)
	for _, sx in ipairs({ -1, 1 }) do
		local x = sx * (w / 2 - t / 2)
		table.insert(list, P(Vector3.new(t, rise, run), CFrame.new(x, y + rise / 2 - 0.05, -run / 2), o.wallMat, o.wallCol, { shape = "Wedge", anim = "rise" }))
		table.insert(list, P(Vector3.new(t, rise, run), CFrame.new(x, y + rise / 2 - 0.05, run / 2) * CFrame.Angles(0, math.pi, 0), o.wallMat, o.wallCol, { shape = "Wedge", anim = "rise" }))
	end
	-- roof planes, segment by segment along the ridge
	for i = 1, segs do
		local x = -L / 2 + seg * (i - 0.5)
		for _, side in ipairs({ -1, 1 }) do
			local eave = Vector3.new(x, y - drop, side * (run + over))
			local ridge = Vector3.new(x, y + rise, 0)
			local normal = Vector3.new(0, c, side * s)
			local mid = (eave + ridge) / 2 + normal * (th / 2)
			local len = (eave - ridge).Magnitude + th * s
			table.insert(list, P(Vector3.new(seg, th, len), CFrame.fromMatrix(mid, Vector3.xAxis, normal), mat, col, { anim = "drop" }))
		end
	end
	-- ridge cap & fascia boards
	table.insert(list, P(Vector3.new(L + 0.3, 0.45, 1.5), Vector3.new(0, y + rise + th / c - 0.08, 0), plain(Enum.Material.SmoothPlastic), o.ridgeCol or C.darkTrim, { anim = "drop" }))
	for _, side in ipairs({ -1, 1 }) do
		local ez = side * (run + over)
		table.insert(list, P(Vector3.new(L + 0.2, 0.8, 0.3), CFrame.new(0, y - drop + 0.15, ez + side * (s * th + 0.05)), plain(Enum.Material.SmoothPlastic), o.fasciaCol or C.trim, { anim = "drop" }))
	end
	return list
end

local function flatRoof(w, d, y, mat, col, trimCol)
	local list = {}
	local n = 4
	for i = 1, n do
		local x = -w / 2 + (w / n) * (i - 0.5)
		table.insert(list, P(Vector3.new(w / n, 1, d + 2), Vector3.new(x, y + 0.5, 0), mat, col, { anim = "drop" }))
	end
	table.insert(list, P(Vector3.new(w + 2.4, 1.8, 1), Vector3.new(0, y + 0.9, -d / 2 - 1.5), plain(Enum.Material.SmoothPlastic), trimCol, { anim = "drop" }))
	table.insert(list, P(Vector3.new(w + 2.4, 1.8, 1), Vector3.new(0, y + 0.9, d / 2 + 1.5), plain(Enum.Material.SmoothPlastic), trimCol, { anim = "drop" }))
	table.insert(list, P(Vector3.new(1.2, 1.8, d + 2), Vector3.new(-w / 2 - 0.6, y + 0.9, 0), plain(Enum.Material.SmoothPlastic), trimCol, { anim = "drop" }))
	table.insert(list, P(Vector3.new(1.2, 1.8, d + 2), Vector3.new(w / 2 + 0.6, y + 0.9, 0), plain(Enum.Material.SmoothPlastic), trimCol, { anim = "drop" }))
	return list
end

local function windowPieces(w, d, t, o, y0, frameCol)
	local list = {}
	local hgt = o.top - o.bottom
	local cy = y0 + (o.bottom + o.top) / 2
	local base = onWall(w, d, o.side, o.a, cy, -t / 2)
	local fw = 0.35 -- frame width
	-- glass sits inside the frame, centred in the wall
	table.insert(list, P(Vector3.new(o.width - fw * 2 + 0.1, hgt - fw * 2 + 0.1, 0.12), base, plain(Enum.Material.Glass), C.glass, { t = 0.3, anim = "fade" }))
	-- frame lies INSIDE the opening (flush), slightly proud of the wall face
	local depth = t + 0.16
	table.insert(list, P(Vector3.new(o.width, fw, depth), base * CFrame.new(0, hgt / 2 - fw / 2, 0), plain(Enum.Material.SmoothPlastic), frameCol, { anim = "drop" }))
	table.insert(list, P(Vector3.new(o.width, fw, depth), base * CFrame.new(0, -hgt / 2 + fw / 2, 0), plain(Enum.Material.SmoothPlastic), frameCol, { anim = "drop" }))
	table.insert(list, P(Vector3.new(fw, hgt - fw * 2, depth), base * CFrame.new(-o.width / 2 + fw / 2, 0, 0), plain(Enum.Material.SmoothPlastic), frameCol, { anim = "drop" }))
	table.insert(list, P(Vector3.new(fw, hgt - fw * 2, depth), base * CFrame.new(o.width / 2 - fw / 2, 0, 0), plain(Enum.Material.SmoothPlastic), frameCol, { anim = "drop" }))
	if o.width > 3.2 then
		table.insert(list, P(Vector3.new(0.22, hgt - fw * 2, 0.3), base, plain(Enum.Material.SmoothPlastic), frameCol, { anim = "drop" }))
	end
	-- sill sticks out below the opening
	table.insert(list, P(Vector3.new(o.width + 0.8, 0.3, 0.7), base * CFrame.new(0, -hgt / 2 - 0.19, -t / 2 - 0.25), plain(Enum.Material.SmoothPlastic), frameCol, { anim = "drop" }))
	for _, p in ipairs(list) do p.side = o.side end
	return list
end

-- TALL_BUILD (2026-10-14): the steel skeleton of a tall building, floor by floor (bottom to top: the columns, the four
-- perimeter beams on top of them, then the floor deck of the next storey). It stands just inside the walls (the facade is
-- hung on it afterwards). Columns every ~14 studs along the perimeter (cheap on parts). Nothing in it collides: players
-- and workers never snag on it. The clients animate it (anim "steel" / "beam" / "deck", Client: animatePart).
local STEEL = Color3.fromRGB(196, 84, 54)   -- primer-red construction steel
local DECK = Color3.fromRGB(170, 172, 170)
local function steelFrame(w, d, y0, h, floorH, t)
	local list = {}
	local inset = (t or 1) + 0.9
	local floors = math.max(1, math.floor(h / floorH + 0.001))
	local fh = h / floors
	local function points(len)
		local n = math.max(1, math.round((len - 2 * inset) / 14))
		local out = {}
		for i = 0, n do table.insert(out, -len / 2 + inset + (len - 2 * inset) * i / n) end
		return out
	end
	local xs, zs = points(w), points(d)
	local cols = {}
	for _, x in ipairs(xs) do table.insert(cols, Vector2.new(x, zs[1])); table.insert(cols, Vector2.new(x, zs[#zs])) end
	for k = 2, #zs - 1 do table.insert(cols, Vector2.new(xs[1], zs[k])); table.insert(cols, Vector2.new(xs[#xs], zs[k])) end
	local ex, ez = w / 2 - inset, d / 2 - inset
	for f = 1, floors do
		local yb = y0 + (f - 1) * fh
		if f > 1 then
			table.insert(list, P(Vector3.new(w - 2 * inset - 0.9, 0.4, d - 2 * inset - 0.9), Vector3.new(0, yb + 0.2, 0), plain(Enum.Material.Concrete), DECK,
				{ anim = "deck", noCollide = true }))
		end
		local ch = fh - 0.8
		for _, c in ipairs(cols) do
			table.insert(list, P(Vector3.new(0.9, ch, 0.9), Vector3.new(c.X, yb + ch / 2, c.Y), plain(Enum.Material.Metal), STEEL, { anim = "steel", noCollide = true }))
		end
		local by = yb + fh - 0.4
		table.insert(list, P(Vector3.new(2 * ex + 0.9, 0.8, 0.8), Vector3.new(0, by, -ez), plain(Enum.Material.Metal), STEEL, { anim = "beam", noCollide = true }))
		table.insert(list, P(Vector3.new(0.8, 0.8, 2 * ez - 0.9), Vector3.new(ex, by, 0), plain(Enum.Material.Metal), STEEL, { anim = "beam", noCollide = true }))
		table.insert(list, P(Vector3.new(2 * ex + 0.9, 0.8, 0.8), Vector3.new(0, by, ez), plain(Enum.Material.Metal), STEEL, { anim = "beam", noCollide = true }))
		table.insert(list, P(Vector3.new(0.8, 0.8, 2 * ez - 0.9), Vector3.new(-ex, by, 0), plain(Enum.Material.Metal), STEEL, { anim = "beam", noCollide = true }))
	end
	return list
end

-- Generic building ---------------------------------------------------------
local function building(o)
	local rng = Random.new(o.seed or 7)
	local stages = {}
	local w, d, h, t = o.w, o.d, o.h, o.t or 1
	local slabH = o.slabH or 1.2
	local openings, windows = {}, {}
	if o.door then table.insert(openings, { side = o.door.side or "front", a = o.door.a or 0, width = o.door.width or 4, bottom = 0, top = o.door.height or 7, door = true }) end
	if o.garageDoor then table.insert(openings, { side = "front", a = o.garageDoor.a or 0, width = o.garageDoor.width, bottom = 0, top = o.garageDoor.height, garage = true }) end
	for _, g in ipairs(o.garageDoors or {}) do table.insert(openings, { side = "front", a = g.a, width = g.width, bottom = 0, top = g.height, garage = true }) end
	-- ZONE_CHAIN: open bays (no door in them: the Car Wash)
	for _, g in ipairs(o.bays or {}) do table.insert(openings, { side = g.side or "front", a = g.a, width = g.width, bottom = 0, top = g.height, bay = true }) end
	for _, wnd in ipairs(o.windows or {}) do table.insert(openings, wnd); table.insert(windows, wnd) end
	for _, sd in ipairs(o.sideDoors or {}) do table.insert(openings, { side = sd.side, a = sd.a, width = sd.width or 3.5, bottom = 0, top = sd.height or 7, door = true }) end

	if o.demolish then
		table.insert(stages, { key = "demolish", name = "Demolition", task = "Tear down the old building", verb = "clear", work = o.work.demolish, removesExisting = true })
	end
	if o.clear then
		table.insert(stages, { key = "clear", name = "Site Clearing", task = "Clear the debris", verb = "clear", work = o.work.clear, removes = debris(rng, w + 10, d + 10, o.debris or 12), split = true })
	end
	if o.dig then
		table.insert(stages, { key = "dig", name = "Excavation", task = "Dig out the foundation", verb = "dig", work = o.work.dig,
			removes = soil(w + 2, d + 2, o.cell or 4, 1), adds = spoilPile(Vector3.new(math.min(w / 2 + 11, 31), 0, d / 4), o.pile or 9, 8), split = true })
	end
	if o.rebar then
		table.insert(stages, { key = "rebar", name = "Rebar", task = "Lay the steel rebar grid", verb = "metal", work = o.work.rebar, adds = rebar(w, d, 3, 0.3) })
	end
	table.insert(stages, { key = "pour", name = "Foundation", task = "Pour the concrete", verb = "pour", work = o.work.pour, adds = slab(w + 1, d + 1, slabH, 5), cure = true })

	if o.frame then
		local fr = {}
		-- corner posts: slightly wider than the wall so they read as corner boards
		for _, sx in ipairs({ -1, 1 }) do for _, sz in ipairs({ -1, 1 }) do
			table.insert(fr, P(Vector3.new(t + 0.24, h - 0.08, t + 0.24), Vector3.new(sx * (w / 2 - t / 2), slabH + h / 2, sz * (d / 2 - t / 2)), M.lumber, C.lumber, { anim = "drop" }))
		end end
		-- studs hidden inside the back wall line
		for x = -w / 2 + 2.5, w / 2 - 2.5, 2.5 do
			table.insert(fr, P(Vector3.new(0.45, h - 0.6, t - 0.12), Vector3.new(x, slabH + 0.04 + (h - 0.6) / 2, d / 2 - t / 2), M.lumber, C.lumber, { anim = "drop" }))
		end
		-- top plates (slightly proud so faces never coincide)
		for _, sz in ipairs({ -1, 1 }) do
			table.insert(fr, P(Vector3.new(w - t * 2 - 0.3, 0.5, t + 0.12), Vector3.new(0, slabH + h - 0.25 + 0.03, sz * (d / 2 - t / 2)), M.lumber, C.lumber, { anim = "drop" }))
		end
		table.insert(stages, { key = "frame", name = "Framing", task = "Raise the wooden frame", verb = "wood", work = o.work.frame, adds = fr })
	end

	-- TALL_BUILD: the steel skeleton first, floor by floor (its work comes out of the walls': same total time)
	local wallsWork = o.work.walls
	if o.steel then
		local sw = math.floor(o.work.walls * 0.35)
		wallsWork = o.work.walls - sw
		table.insert(stages, { key = "steel", name = "Steel Frame", task = "Raise the steel frame floor by floor", verb = "metal", work = sw,
			adds = steelFrame(w, d, slabH, h, o.floorH or 8, t) })
	end

	-- walls: one parallel track per side
	table.insert(stages, { key = "walls", name = o.wallName or "Brick Walls", task = o.wallTask or "Lay the bricks", verb = o.wallVerb or "brick", work = wallsWork,
		adds = walls(w, d, slabH, h, t, o.rowH or 1, o.wallMat, o.wallCol, openings), split = true })

	if #windows > 0 then
		local wp = {}
		for _, wnd in ipairs(windows) do append(wp, windowPieces(w, d, t, wnd, slabH, o.frameCol or C.trim)) end
		-- windows, roof and doors are built at the same time (group "exterior")
		table.insert(stages, { key = "windows", name = "Windows", task = "Install the windows", verb = "glass", work = o.work.windows, adds = wp, split = true, group = "exterior" })
	end

	local roof
	if o.roof == "flat" then
		roof = flatRoof(w, d, slabH + h, o.roofMat or M.concrete, o.roofCol or C.concrete, o.trimCol or C.darkTrim)
	else
		roof = gableRoof(o, w, d, t, slabH + h)
	end
	table.insert(stages, { key = "roof", name = "Roof", task = o.roof == "flat" and "Cast the roof slab" or "Install the roof", verb = o.roof == "flat" and "pour" or "wood", work = o.work.roof, adds = roof, group = "exterior" })

	-- Finishing touches
	local fin = {}
	for _, op in ipairs(openings) do
		local first = #fin + 1
		if op.door then
			local fw = 0.3
			local cf = onWall(w, d, op.side, op.a, slabH + op.top / 2, -t / 2)
			-- door frame inside the opening
			table.insert(fin, P(Vector3.new(fw, op.top, t + 0.16), cf * CFrame.new(-op.width / 2 + fw / 2, 0, 0), plain(Enum.Material.SmoothPlastic), o.frameCol or C.trim, { anim = "drop" }))
			table.insert(fin, P(Vector3.new(fw, op.top, t + 0.16), cf * CFrame.new(op.width / 2 - fw / 2, 0, 0), plain(Enum.Material.SmoothPlastic), o.frameCol or C.trim, { anim = "drop" }))
			table.insert(fin, P(Vector3.new(op.width - fw * 2, fw, t + 0.16), cf * CFrame.new(0, op.top / 2 - fw / 2, 0), plain(Enum.Material.SmoothPlastic), o.frameCol or C.trim, { anim = "drop" }))
			-- door leaf
			local leaf = cf * CFrame.new(0, -fw / 2, -t / 2 + 0.35)
			-- door leaf is walk-through so players are never trapped inside a building
			table.insert(fin, P(Vector3.new(op.width - fw * 2, op.top - fw, 0.3), leaf, plain(Enum.Material.Wood), o.doorCol or C.darkWood, { anim = "fade", noCollide = true }))
			table.insert(fin, P(Vector3.new(op.width - fw * 2 - 1, op.top * 0.32, 0.12), leaf * CFrame.new(0, op.top * 0.18, -0.18), plain(Enum.Material.Wood), (o.doorCol or C.darkWood):Lerp(Color3.new(0, 0, 0), 0.15), { anim = "fade", noCollide = true }))
			table.insert(fin, P(Vector3.new(0.4, 0.4, 0.4), leaf * CFrame.new(op.width / 2 - fw - 0.55, -0.4, -0.3), plain(Enum.Material.Metal), Color3.fromRGB(220, 190, 90), { shape = "Ball", anim = "fade", noCollide = true }))
			if op.side == "front" then
				local lamp = onWall(w, d, op.side, op.a + op.width / 2 + 0.7, slabH + op.top - 1.13, 0.3)
				table.insert(fin, P(Vector3.new(0.6, 1, 0.6), lamp, plain(Enum.Material.Neon), Color3.fromRGB(255, 226, 170), { anim = "fade", light = true }))
				table.insert(fin, P(Vector3.new(0.8, 0.2, 0.8), lamp * CFrame.new(0, 0.63, 0), plain(Enum.Material.Metal), C.darkTrim, { anim = "fade" }))
			end
		elseif op.garage then
			local n = math.max(3, math.floor(op.top))
			local ph = op.top / n
			for i = 1, n do
				local cf = onWall(w, d, "front", op.a, slabH + ph * (i - 0.5), -t / 2 + 0.2)
				table.insert(fin, P(Vector3.new(op.width - 0.1, ph - 0.1, 0.3), cf, plain(Enum.Material.Metal), C.metal, { anim = "drop", noCollide = true }))
			end
			table.insert(fin, P(Vector3.new(op.width + 1.2, 0.6, 0.5), onWall(w, d, "front", op.a, slabH + op.top + 0.3, 0.25), plain(Enum.Material.SmoothPlastic), C.darkTrim, { anim = "drop" }))
			table.insert(fin, P(Vector3.new(op.width + 2, 0.3, 7.4), Vector3.new(op.a, 0.15, -d / 2 - 0.5 - 3.7), M.concrete, C.concrete, { anim = "rise" }))
		end
		for k = first, #fin do fin[k].side = op.side end
	end
	-- door pieces become their own stage that runs alongside windows & roof
	local doors = fin
	fin = {}
	if o.porch then
		-- porch slab starts where the foundation ends and sits a hair lower (no coplanar tops)
		local pz = -d / 2 - 0.5
		table.insert(fin, P(Vector3.new(o.porch.width, slabH - 0.08, 4.5), Vector3.new(o.porch.a or 0, (slabH - 0.08) / 2, pz - 2.25), M.concrete, C.concrete, { anim = "rise" }))
		table.insert(fin, P(Vector3.new(o.porch.width - 2, (slabH - 0.08) / 2, 1.5), Vector3.new(o.porch.a or 0, (slabH - 0.08) / 4, pz - 5.25), M.concrete, C.concrete, { anim = "rise" }))
	end
	if o.chimney then
		local ch = o.rise + 3
		table.insert(fin, P(Vector3.new(2.4, ch, 2.4), Vector3.new(w / 2 - 4, slabH + h + ch / 2, d / 6), o.wallMat, o.wallCol, { anim = "drop" }))
		table.insert(fin, P(Vector3.new(2.9, 0.5, 2.9), Vector3.new(w / 2 - 4, slabH + h + ch + 0.25, d / 6), plain(Enum.Material.SmoothPlastic), C.darkTrim, { anim = "drop" }))
	end
	if o.cornerTrim then
		for _, sx in ipairs({ -1, 1 }) do for _, sz in ipairs({ -1, 1 }) do
			table.insert(fin, P(Vector3.new(t + 0.3, h - 0.06, t + 0.3), Vector3.new(sx * (w / 2 - t / 2), slabH + h / 2, sz * (d / 2 - t / 2)), plain(Enum.Material.SmoothPlastic), o.frameCol or C.trim, { anim = "fade" }))
		end end
	end
	-- base plinth trim around the walls
	if o.plinth ~= false then
		local pc = o.plinthCol or Color3.fromRGB(120, 116, 110)
		-- each side: along-axis range and a function placing a span on that side
		local sideDefs = {
			front = { -w / 2 - 0.3, w / 2 + 0.3, function(a, len) return Vector3.new(len, 0.7, 0.3), Vector3.new(a, slabH + 0.35, -d / 2 - 0.15) end },
			back = { -w / 2 - 0.3, w / 2 + 0.3, function(a, len) return Vector3.new(len, 0.7, 0.3), Vector3.new(a, slabH + 0.35, d / 2 + 0.15) end },
			left = { -d / 2, d / 2, function(a, len) return Vector3.new(0.3, 0.7, len), Vector3.new(-w / 2 - 0.15, slabH + 0.35, a) end },
			right = { -d / 2, d / 2, function(a, len) return Vector3.new(0.3, 0.7, len), Vector3.new(w / 2 + 0.15, slabH + 0.35, a) end },
		}
		for sideName, sd in pairs(sideDefs) do
			local spans = { { sd[1], sd[2] } }
			for _, op in ipairs(openings) do
				if op.side == sideName and (op.door or op.garage or op.bay) then
					local a1, b1 = op.a - op.width / 2, op.a + op.width / 2
					local new = {}
					for _, sg in ipairs(spans) do
						if b1 <= sg[1] or a1 >= sg[2] then table.insert(new, sg) else
							if a1 > sg[1] then table.insert(new, { sg[1], a1 }) end
							if b1 < sg[2] then table.insert(new, { b1, sg[2] }) end
						end
					end
					spans = new
				end
			end
			for _, sg in ipairs(spans) do
				if sg[2] - sg[1] > 0.1 then
					local size, pos = sd[3]((sg[1] + sg[2]) / 2, sg[2] - sg[1])
					table.insert(fin, P(size, pos, plain(Enum.Material.Concrete), pc, { anim = "fade" }))
				end
			end
		end
	end
	if o.extraFinish then append(fin, o.extraFinish(w, d, h, slabH)) end
	local doorWork = (#doors > 0) and math.max(4, math.floor(o.work.finish * 0.4)) or 0
	if #doors > 0 then
		table.insert(stages, { key = "doors", name = "Doors", task = "Hang the doors", verb = "hammer", work = doorWork, adds = doors, split = true, group = "exterior" })
	end
	table.insert(stages, { key = "finish", name = "Finishing", task = "Trims, porch & details", verb = "hammer", work = o.work.finish - doorWork, adds = fin })
	return stages
end

-- floor bands around a building at the given heights (end faces only share edges)
local function bands(w, d, ys, color)
	local list = {}
	for _, y in ipairs(ys) do
		table.insert(list, P(Vector3.new(w + 0.6, 0.6, 0.3), Vector3.new(0, y, -d / 2 - 0.15), plain(Enum.Material.SmoothPlastic), color, { anim = "drop" }))
		table.insert(list, P(Vector3.new(w + 0.6, 0.6, 0.3), Vector3.new(0, y, d / 2 + 0.15), plain(Enum.Material.SmoothPlastic), color, { anim = "drop" }))
		table.insert(list, P(Vector3.new(0.3, 0.6, d), Vector3.new(-w / 2 - 0.15, y, 0), plain(Enum.Material.SmoothPlastic), color, { anim = "drop" }))
		table.insert(list, P(Vector3.new(0.3, 0.6, d), Vector3.new(w / 2 + 0.15, y, 0), plain(Enum.Material.SmoothPlastic), color, { anim = "drop" }))
	end
	return list
end

-- Downtown towers ---------------------------------------------------------------
-- glass curtain-wall towers: no punched windows (cheap on parts), floor bands every storey
local function glassTower(o)
	local floors = math.floor(o.h / o.floorH)
	return building({
		seed = o.seed, w = o.w, d = o.d, h = o.h, t = 1, rowH = o.floorH / 2, steel = true, floorH = o.floorH,
		wallMat = { Enum.Material.Glass, nil }, wallCol = o.glass, wallName = "Glass Facade", wallTask = "Hang the glass panels", wallVerb = "glass",
		door = { side = "front", a = 0, width = o.doorW or 8, height = 8 }, doorCol = Color3.fromRGB(30, 34, 44),
		roof = "flat", roofMat = M.concrete, roofCol = Color3.fromRGB(90, 94, 104), trimCol = o.trim, frameCol = o.trim, cornerTrim = true,
		plinthCol = Color3.fromRGB(60, 64, 74),
		clear = true, dig = true, rebar = true, debris = 24, pile = 12, cell = 6,
		extraFinish = function(w, d, h, slabH)
			local ys = {}
			for k = 1, floors - 1 do table.insert(ys, slabH + o.floorH * k) end
			local list = bands(w, d, ys, o.band)
			if o.extra then append(list, o.extra(w, d, h, slabH)) end
			return list
		end,
		work = o.work,
	})
end

-- the live game's ZONE_CHAIN helpers (Z), at file level
	local SP, NEON, GLASS, METAL, CONC = plain(Enum.Material.SmoothPlastic), plain(Enum.Material.Neon), plain(Enum.Material.Glass), plain(Enum.Material.Metal), plain(Enum.Material.Concrete)
local STONE, MARBLE, FOIL, FABRIC, GRASS = plain(Enum.Material.Limestone), plain(Enum.Material.Marble), plain(Enum.Material.Foil), plain(Enum.Material.Fabric), plain(Enum.Material.Grass)
local rgb = Color3.fromRGB
local Z = {}
-- a vertical cylinder (Roblox cylinders run along X)
function Z.cyl(dia, h, pos, mat, col, anim, extra)
	local e = { shape = "Cylinder", anim = anim or "grow" }
	if extra then for k, v in pairs(extra) do e[k] = v end end
	return P(Vector3.new(h, dia, dia), CFrame.new(pos) * CFrame.Angles(0, 0, math.pi / 2), mat, col, e)
end
-- a flat disc lying on the ground / a roof (a short vertical cylinder)
function Z.disc(dia, h, pos, mat, col, anim, extra) return Z.cyl(dia, h, pos, mat, col, anim or "rise", extra) end
-- striped awning along the front wall (wedges, the high side on the wall, like the Corner Shop's)
function Z.awning(cx, width, y, d, n, c1, c2)
	local list = {}
	for i = 0, n - 1 do
		local x = cx - width / 2 + width / n * (i + 0.5)
		table.insert(list, P(Vector3.new(width / n, 1.3, 3), CFrame.new(x, y, -d / 2 - 1.75), FABRIC, (i % 2 == 0) and c1 or c2, { shape = "Wedge", anim = "drop" }))
	end
	return list
end
-- a triangular pediment over a portico (two wedges, high sides meeting in the middle), facing the front
function Z.pediment(cx, y, z, width, height, depth, mat, col)
	return {
		P(Vector3.new(depth, height, width / 2), CFrame.new(cx - width / 4, y + height / 2, z) * CFrame.Angles(0, math.pi / 2, 0), mat, col, { shape = "Wedge", anim = "drop" }),
		P(Vector3.new(depth, height, width / 2), CFrame.new(cx + width / 4, y + height / 2, z) * CFrame.Angles(0, -math.pi / 2, 0), mat, col, { shape = "Wedge", anim = "drop" }),
	}
end
-- a tree / palm (trunk + leaves)
function Z.tree(x, z, h, leaf, palm)
	local list = { Z.cyl(0.9, h, Vector3.new(x, h / 2, z), plain(Enum.Material.Wood), rgb(112, 80, 54), "grow") }
	if palm then
		for k = 0, 4 do
			local a = k / 5 * math.pi * 2
			table.insert(list, P(Vector3.new(5, 0.4, 1.6), CFrame.new(x + math.cos(a) * 2.2, h + 0.2, z + math.sin(a) * 2.2) * CFrame.Angles(0, -a, 0.3), plain(Enum.Material.LeafyGrass), leaf, { anim = "grow" }))
		end
	else
		table.insert(list, P(Vector3.new(h * 0.8, h * 0.8, h * 0.8), Vector3.new(x, h + h * 0.25, z), plain(Enum.Material.LeafyGrass), leaf, { shape = "Ball", anim = "grow" }))
	end
	return list
end
-- a street lamp
function Z.lamp(x, z, h)
	return { Z.cyl(0.5, h, Vector3.new(x, h / 2, z), METAL, rgb(50, 54, 62), "grow"),
		P(Vector3.new(1.4, 0.8, 1.4), Vector3.new(x, h + 0.4, z), NEON, rgb(255, 232, 180), { anim = "fade", light = true }) }
end
-- a flag on a pole
function Z.flag(x, z, h, col)
	return { Z.cyl(0.35, h, Vector3.new(x, h / 2, z), METAL, rgb(220, 222, 228), "grow"),
		P(Vector3.new(3.2, 2, 0.12), Vector3.new(x + 1.75, h - 1.2, z), FABRIC, col, { anim = "fade" }) }
end
-- moves a list of pieces by a CFrame (towers built off the origin)
function Z.moved(list, cf)
	for _, p in ipairs(list) do p.c = cf * p.c end
	return list
end
-- side of a point (for the parallel wall tracks)
function Z.sideOf(x, z, w, d)
	if math.abs(z) / d > math.abs(x) / w then return z < 0 and "front" or "back" end
	return x < 0 and "left" or "right"
end
-- an extra stage before the finishing one
function Z.stageBeforeFinish(stages, st)
	table.insert(stages, #stages, st)
	return stages
end
-- the 4 standard foundation stages for a custom building (clear, dig, rebar, pour)
function Z.groundworks(rng, w, d, work, slabH, cell)
	return {
		{ key = "clear", name = "Site Clearing", task = "Clear the debris", verb = "clear", work = work.clear, removes = debris(rng, w + 10, d + 10, 26), split = true },
		{ key = "dig", name = "Excavation", task = "Dig out the foundation", verb = "dig", work = work.dig,
			removes = soil(w + 2, d + 2, cell or 6, 1), adds = spoilPile(Vector3.new(math.min(w / 2 + 11, 40), 0, d / 4), 12, 8), split = true },
		{ key = "rebar", name = "Rebar", task = "Lay the steel rebar grid", verb = "metal", work = work.rebar, adds = rebar(w, d, 4, 0.3) },
		{ key = "pour", name = "Foundation", task = "Pour the concrete", verb = "pour", work = work.pour, adds = slab(w + 1, d + 1, slabH, 5), cure = true },
	}
end

-- NEW BUILDINGS ---------------------------------------------------------------------------------------------------
-- 2.0 helpers ------------------------------------------------------------------------------------------------------
local WOOD, LOGS, SLATE, BRICK = plain(Enum.Material.WoodPlanks), plain(Enum.Material.Wood), plain(Enum.Material.Slate), plain(Enum.Material.Brick)
local WHITE, INK = rgb(248, 248, 244), rgb(40, 44, 52)
-- all the pieces of a stage list moved by a CFrame (a wing built beside the main block)
local function shift(stages, cf)
	for _, st in ipairs(stages) do
		for _, p in ipairs(st.adds or {}) do p.c = cf * p.c end
		for _, p in ipairs(st.removes or {}) do p.c = cf * p.c end
	end
	return stages
end
-- two buildings built as one: the stages of b join a's stages with the same key (a new kind goes before the finishing)
local function merge(a, b)
	for _, sb in ipairs(b) do
		local found
		for _, sa in ipairs(a) do if sa.key == sb.key then found = sa end end
		if found then
			found.adds = append(found.adds or {}, sb.adds or {})
			if sb.removes then found.removes = append(found.removes or {}, sb.removes) end
			found.work = (found.work or 0) + (sb.work or 0) * 0.5
		else
			table.insert(a, #a, sb)
		end
	end
	return a
end
-- a sign board with words on its front (Build / the cards draw the text)
local function sign(size, cf, col, text, textCol, neon)
	return P(size, typeof(cf) == "Vector3" and CFrame.new(cf) or cf, neon and NEON or SP, col, { anim = "drop", text = text, textCol = textCol or WHITE })
end
-- a bistro table with its parasol and two stools
local function terraceTable(x, z, parasol)
	return {
		Z.disc(2.6, 0.25, Vector3.new(x, 2.75, z), SP, WHITE, "grow"),
		Z.cyl(0.3, 2.6, Vector3.new(x, 1.3, z), METAL, INK, "grow"),
		Z.cyl(0.2, 3.4, Vector3.new(x, 4.4, z), METAL, INK, "grow"),
		Z.disc(5.4, 0.4, Vector3.new(x, 6.1, z), FABRIC, parasol, "grow"),
		Z.cyl(1.3, 1.7, Vector3.new(x - 2.2, 0.85, z), WOOD, rgb(150, 100, 64), "grow"),
		Z.cyl(1.3, 1.7, Vector3.new(x + 2.2, 0.85, z), WOOD, rgb(150, 100, 64), "grow"),
	}
end
-- a planter box with a round bush
local function planter(x, z, col)
	return {
		P(Vector3.new(2.2, 1.4, 2.2), Vector3.new(x, 0.7, z), CONC, col or rgb(96, 100, 108), { anim = "grow" }),
		P(Vector3.new(2.6, 2.6, 2.6), Vector3.new(x, 2.4, z), plain(Enum.Material.LeafyGrass), rgb(84, 148, 70), { shape = "Ball", anim = "grow" }),
	}
end
-- a run of white picket fence along X (from x0 to x1 at z)
local function picket(x0, x1, z, col)
	local list = {}
	local n = math.max(2, math.floor((x1 - x0) / 1.5))
	for i = 0, n do table.insert(list, P(Vector3.new(0.35, 2.6, 0.35), Vector3.new(x0 + (x1 - x0) * i / n, 1.3, z), WOOD, col or WHITE, { anim = "grow" })) end
	for _, y in ipairs({ 0.9, 2.0 }) do table.insert(list, P(Vector3.new(x1 - x0, 0.3, 0.2), Vector3.new((x0 + x1) / 2, y, z + 0.25), WOOD, col or WHITE, { anim = "drop" })) end
	return list
end
-- a balcony on the front wall: concrete slab, glass panel, metal rail (y = the floor of the room behind)
local function frontBalcony(a, y, d, width, railCol)
	return {
		P(Vector3.new(width, 0.4, 2.6), Vector3.new(a, y - 0.2, -d / 2 - 1.3), M.concrete, C.concrete, { anim = "drop" }),
		P(Vector3.new(width - 0.2, 1.3, 0.12), Vector3.new(a, y + 0.65, -d / 2 - 2.5), GLASS, rgb(180, 210, 230), { t = 0.4, anim = "fade" }),
		P(Vector3.new(width, 0.15, 0.25), Vector3.new(a, y + 1.38, -d / 2 - 2.5), METAL, railCol or INK, { anim = "drop" }),
	}
end
-- a water tank on legs (rooftops)
local function waterTank(x, y, z)
	local list = {}
	for _, sx in ipairs({ -1, 1 }) do for _, sz in ipairs({ -1, 1 }) do
		table.insert(list, P(Vector3.new(0.4, 4, 0.4), Vector3.new(x + sx * 1.6, y + 2, z + sz * 1.6), METAL, INK, { anim = "steel" }))
	end end
	table.insert(list, Z.cyl(5, 5, Vector3.new(x, y + 6.5, z), WOOD, rgb(150, 98, 60), "grow"))
	table.insert(list, Z.cyl(5.4, 0.5, Vector3.new(x, y + 9.25, z), METAL, INK, "grow"))
	table.insert(list, Z.cyl(3, 1, Vector3.new(x, y + 10, z), METAL, INK, "grow"))
	return list
end
-- a rooftop air unit
local function airUnit(x, y, z)
	return {
		P(Vector3.new(4, 2.2, 3), Vector3.new(x, y + 1.1, z), METAL, rgb(186, 190, 196), { anim = "drop" }),
		Z.cyl(2, 0.3, Vector3.new(x, y + 2.35, z), METAL, rgb(120, 124, 130), "grow"),
	}
end
local W = { clear = 40, dig = 80, rebar = 50, pour = 80, walls = 230, windows = 60, roof = 140, finish = 120 }

-- LEVEL 1 ----------------------------------------------------------------------------------------------------------
-- a brick coffee kiosk with a service window, a green awning and a giant cup on the roof
function B.CoffeeKiosk()
	local green = rgb(30, 128, 88)
	return building({
		seed = 301, w = 14, d = 10, h = 8, t = 1, rowH = 1,
		wallMat = M.brick, wallCol = rgb(170, 92, 70),
		door = { side = "right", a = 2, width = 3, height = 7 }, doorCol = green,
		windows = { { side = "front", a = 0, width = 9, bottom = 2.6, top = 6.4 }, { side = "left", a = 0, width = 4, bottom = 3, top = 6 } },
		roof = "flat", roofCol = rgb(120, 124, 130), trimCol = INK, frameCol = INK,
		clear = true, dig = true, rebar = true, debris = 8, pile = 6, cell = 4,
		extraFinish = function(w, d, h, slabH)
			local list = Z.awning(0, 10, slabH + 7.2, d, 5, green, rgb(250, 246, 238))
			table.insert(list, P(Vector3.new(10, 0.4, 1.8), Vector3.new(0, slabH + 2.4, -d / 2 - 0.7), WOOD, rgb(120, 80, 52), { anim = "drop" }))
			-- the giant cup: sleeve, lid, steam
			local y = slabH + h + 1
			table.insert(list, Z.cyl(4.4, 5, Vector3.new(0, y + 2.5, 1), SP, WHITE, "grow"))
			table.insert(list, Z.cyl(4.7, 1.8, Vector3.new(0, y + 2.4, 1), SP, rgb(150, 96, 60), "grow"))
			table.insert(list, Z.cyl(4.9, 0.6, Vector3.new(0, y + 5.3, 1), SP, rgb(70, 44, 32), "grow"))
			table.insert(list, Z.cyl(3, 0.5, Vector3.new(0, y + 5.85, 1), SP, rgb(70, 44, 32), "grow"))
			for i, off in ipairs({ { -0.6, 7.2 }, { 0.5, 8.4 }, { -0.2, 9.6 } }) do
				table.insert(list, P(Vector3.one * (1.6 - i * 0.25), Vector3.new(off[1], y + off[2], 1), SP, WHITE, { shape = "Ball", t = 0.35, anim = "grow" }))
			end
			table.insert(list, sign(Vector3.new(11, 1.6, 0.4), Vector3.new(0, slabH + h - 0.6, -d / 2 - 0.35), green, "COFFEE"))
			append(list, terraceTable(-4.2, -d / 2 - 6.5, rgb(250, 246, 238)))
			append(list, terraceTable(4.2, -d / 2 - 6.5, green))
			append(list, planter(-6.2, -d / 2 - 1.8))
			return list
		end,
		work = W,
	}), { size = Vector3.new(16, 18, 26) }
end

-- a painted wooden flower shop with a pink roof, flower stands and window boxes
function B.FlowerShop()
	local sage, pink = rgb(150, 196, 168), rgb(214, 96, 120)
	return building({
		seed = 311, w = 14, d = 12, h = 7, t = 1, rowH = 0.9,
		wallMat = M.lumber, wallCol = sage,
		door = { side = "front", a = 4, width = 3.4, height = 6.4 }, doorCol = rgb(250, 246, 238),
		windows = { { side = "front", a = -2.4, width = 6, bottom = 2, top = 5.6 }, { side = "left", a = 0, width = 4, bottom = 2.4, top = 5.4 }, { side = "right", a = 0, width = 4, bottom = 2.4, top = 5.4 } },
		rise = 4.5, over = 1.3, roofSegs = 5, roofCol = pink, ridgeCol = rgb(150, 60, 80), fasciaCol = WHITE, frameCol = WHITE, cornerTrim = true,
		clear = true, dig = true, rebar = true, debris = 8, pile = 6, cell = 4,
		extraFinish = function(w, d, h, slabH)
			local list = {}
			-- the window box under the shop window, full of flowers
			table.insert(list, P(Vector3.new(6.4, 0.9, 1.1), Vector3.new(-2.4, slabH + 1.4, -d / 2 - 0.6), WOOD, WHITE, { anim = "drop" }))
			local cols = { rgb(255, 92, 120), rgb(255, 210, 70), rgb(250, 250, 250), rgb(190, 120, 255) }
			for i = 0, 4 do table.insert(list, P(Vector3.one * 1.1, Vector3.new(-5 + i * 1.3, slabH + 2.2, -d / 2 - 0.6), SP, cols[i % 4 + 1], { shape = "Ball", anim = "grow" })) end
			-- two stepped stands with pots out front
			for _, x in ipairs({ -4.5, 3.8 }) do
				table.insert(list, P(Vector3.new(4.4, 1, 2.4), Vector3.new(x, 0.5, -d / 2 - 3.6), WOOD, rgb(150, 100, 64), { anim = "rise" }))
				table.insert(list, P(Vector3.new(4.4, 1, 1.2), Vector3.new(x, 1.5, -d / 2 - 3.0), WOOD, rgb(150, 100, 64), { anim = "rise" }))
				for k = -1, 1 do
					table.insert(list, Z.cyl(1, 0.9, Vector3.new(x + k * 1.4, 1.45, -d / 2 - 4.2), SP, rgb(196, 104, 70), "grow"))
					table.insert(list, P(Vector3.one * 1.2, Vector3.new(x + k * 1.4, 2.4, -d / 2 - 4.2), SP, cols[(k + 2) % 4 + 1], { shape = "Ball", anim = "grow" }))
					table.insert(list, Z.cyl(1, 0.9, Vector3.new(x + k * 1.4, 2.45, -d / 2 - 3.0), SP, rgb(196, 104, 70), "grow"))
					table.insert(list, P(Vector3.one * 1.2, Vector3.new(x + k * 1.4, 3.4, -d / 2 - 3.0), SP, cols[(k + 3) % 4 + 1], { shape = "Ball", anim = "grow" }))
				end
			end
			-- the sign on the gable
			table.insert(list, sign(Vector3.new(8, 1.6, 0.3), Vector3.new(0, slabH + h + 1.6, -d / 2 - 0.25), WHITE, "FLOWERS", pink))
			return list
		end,
		work = W,
	}), { size = Vector3.new(16, 14, 24) }
end

-- LEVEL 2 ----------------------------------------------------------------------------------------------------------
-- a whitewashed brick cottage: navy shutters, a red door under a little porch roof, a picket fence
function B.BrickCottage()
	local navy, red = rgb(48, 62, 96), rgb(186, 40, 44)
	local wins = {
		{ side = "front", a = -6.5, width = 4.2, bottom = 2.6, top = 7.4 }, { side = "front", a = 6.5, width = 4.2, bottom = 2.6, top = 7.4 },
		{ side = "left", a = 0, width = 4.2, bottom = 2.6, top = 7.4 }, { side = "right", a = 0, width = 4.2, bottom = 2.6, top = 7.4 },
		{ side = "back", a = -5, width = 4.2, bottom = 2.6, top = 7.4 }, { side = "back", a = 5, width = 4.2, bottom = 2.6, top = 7.4 },
	}
	return building({
		seed = 321, w = 22, d = 16, h = 9.5, t = 1, rowH = 1,
		wallMat = M.brick, wallCol = rgb(238, 232, 222),
		door = { side = "front", a = 0, width = 4, height = 7.6 }, doorCol = red,
		windows = wins,
		rise = 7.5, over = 1.6, roofSegs = 6, roofCol = rgb(58, 66, 86), ridgeCol = rgb(36, 40, 52), fasciaCol = WHITE, frameCol = WHITE, chimney = true,
		clear = true, dig = true, rebar = true, debris = 12, pile = 8, cell = 4,
		extraFinish = function(w, d, h, slabH)
			local list = {}
			-- shutters beside the front windows
			for _, a in ipairs({ -6.5, 6.5 }) do
				for _, s in ipairs({ -1, 1 }) do
					table.insert(list, P(Vector3.new(1.4, 4.8, 0.25), Vector3.new(a + s * 2.85, slabH + 5, -d / 2 - 0.2), WOOD, navy, { anim = "drop" }))
				end
				-- a flower box
				table.insert(list, P(Vector3.new(4.6, 0.8, 0.9), Vector3.new(a, slabH + 2.0, -d / 2 - 0.55), WOOD, navy, { anim = "drop" }))
				for i = 0, 3 do table.insert(list, P(Vector3.one, Vector3.new(a - 1.6 + i * 1.07, slabH + 2.7, -d / 2 - 0.55), SP, (i % 2 == 0) and rgb(255, 96, 120) or rgb(255, 214, 80), { shape = "Ball", anim = "grow" })) end
			end
			-- the porch roof over the door on two white posts
			append(list, Z.pediment(0, slabH + 8.4, -d / 2 - 1.7, 7.4, 2.2, 3.4, M.shingles, rgb(58, 66, 86)))
			table.insert(list, P(Vector3.new(7.6, 0.5, 3.6), Vector3.new(0, slabH + 8.2, -d / 2 - 1.7), SP, WHITE, { anim = "drop" }))
			for _, x in ipairs({ -3.3, 3.3 }) do table.insert(list, Z.cyl(0.6, 8, Vector3.new(x, slabH + 4, -d / 2 - 3.1), SP, WHITE, "grow")) end
			-- the front garden: a picket fence, a path, a mailbox
			append(list, picket(-11, -2.5, -d / 2 - 8))
			append(list, picket(2.5, 11, -d / 2 - 8))
			table.insert(list, P(Vector3.new(4, 0.2, 7), Vector3.new(0, 0.1, -d / 2 - 4.5), plain(Enum.Material.Slate), rgb(170, 166, 160), { anim = "rise" }))
			table.insert(list, Z.cyl(0.35, 3.2, Vector3.new(-4, 1.6, -d / 2 - 8.6), WOOD, rgb(120, 80, 52), "grow"))
			table.insert(list, P(Vector3.new(1, 1, 1.8), Vector3.new(-4, 3.6, -d / 2 - 8.6), METAL, red, { anim = "grow" }))
			append(list, Z.tree(8.5, -d / 2 - 5, 5, rgb(96, 168, 70)))
			return list
		end,
		work = W,
	}), { size = Vector3.new(26, 20, 34) }
end

-- a log cabin: dark log walls, a green roof, a stone chimney and a deck along the front
function B.TimberCabin()
	local logs = rgb(132, 86, 56)
	local wins = {
		{ side = "front", a = -6, width = 4.4, bottom = 2.4, top = 6.8 }, { side = "front", a = 6, width = 4.4, bottom = 2.4, top = 6.8 },
		{ side = "left", a = 0, width = 4, bottom = 2.4, top = 6.8 }, { side = "right", a = -2, width = 4, bottom = 2.4, top = 6.8 },
		{ side = "back", a = 0, width = 6, bottom = 2.4, top = 6.8 },
	}
	return building({
		seed = 331, w = 22, d = 16, h = 9, t = 1.1, rowH = 0.9,
		wallMat = LOGS, wallCol = logs, wallName = "Log Walls", wallTask = "Stack the logs", wallVerb = "wood",
		door = { side = "front", a = 0, width = 4, height = 7.2 }, doorCol = rgb(70, 46, 30),
		windows = wins,
		rise = 7, over = 2, roofSegs = 6, roofCol = rgb(64, 104, 70), ridgeCol = rgb(40, 66, 44), fasciaCol = rgb(96, 62, 40), frameCol = rgb(236, 226, 206),
		clear = true, dig = true, rebar = true, debris = 14, pile = 8, cell = 4, plinthCol = rgb(110, 106, 100),
		extraFinish = function(w, d, h, slabH)
			local list = {}
			-- round log ends at the corners
			for _, sx in ipairs({ -1, 1 }) do for _, sz in ipairs({ -1, 1 }) do
				table.insert(list, Z.cyl(1.6, h, Vector3.new(sx * (w / 2 - 0.3), slabH + h / 2, sz * (d / 2 - 0.3)), LOGS, logs:Lerp(Color3.new(0, 0, 0), 0.15), "grow"))
			end end
			-- the stone chimney on the side
			table.insert(list, P(Vector3.new(3.4, h + 9, 3), Vector3.new(w / 2 + 1.6, (slabH + h + 9) / 2, 3), SLATE, rgb(128, 124, 118), { anim = "drop" }))
			table.insert(list, P(Vector3.new(3.8, 0.6, 3.4), Vector3.new(w / 2 + 1.6, slabH + h + 9.3 - slabH / 2, 3), SLATE, rgb(90, 88, 84), { anim = "drop" }))
			-- the front deck: boards, posts, a rail, a porch roof
			table.insert(list, P(Vector3.new(w + 2, 0.6, 5), Vector3.new(0, slabH - 0.3, -d / 2 - 2.5), WOOD, rgb(170, 120, 76), { anim = "rise" }))
			for _, x in ipairs({ -w / 2, -4, 4, w / 2 }) do table.insert(list, Z.cyl(0.6, 8, Vector3.new(x, slabH + 4, -d / 2 - 4.6), LOGS, logs, "grow")) end
			for _, seg in ipairs({ { -w / 2, -2.6 }, { 2.6, w / 2 } }) do
				table.insert(list, P(Vector3.new(seg[2] - seg[1], 0.35, 0.35), Vector3.new((seg[1] + seg[2]) / 2, slabH + 2.4, -d / 2 - 4.6), LOGS, logs, { anim = "drop" }))
			end
			table.insert(list, P(Vector3.new(w + 3, 0.5, 5.6), CFrame.new(0, slabH + 8.3, -d / 2 - 2.6) * CFrame.Angles(math.rad(14), 0, 0), M.shingles, rgb(64, 104, 70), { anim = "drop" }))
			-- lanterns, a woodpile, a pine
			for _, x in ipairs({ -2.8, 2.8 }) do table.insert(list, P(Vector3.new(0.7, 1, 0.7), Vector3.new(x, slabH + 6.3, -d / 2 - 0.4), NEON, rgb(255, 210, 140), { anim = "fade", light = true })) end
			for i = 0, 2 do table.insert(list, Z.cyl(1, 4, Vector3.new(-w / 2 - 1.2, 0.5 + i * 0.95, -2 + (i % 2) * 0.5), LOGS, rgb(150, 104, 64), "grow")) end
			return list
		end,
		work = W,
	}), { size = Vector3.new(28, 20, 28) }
end

-- LEVEL 3 ----------------------------------------------------------------------------------------------------------
-- a two-storey family home with a garage wing, a driveway and a hedge
function B.FamilyHome()
	local wins = {
		{ side = "front", a = 5.5, width = 5, bottom = 2.6, top = 6.8 },
		{ side = "front", a = -6.5, width = 4, bottom = 10.6, top = 14.6 }, { side = "front", a = 0, width = 4, bottom = 10.6, top = 14.6 }, { side = "front", a = 6.5, width = 4, bottom = 10.6, top = 14.6 },
		{ side = "left", a = -3.5, width = 4, bottom = 2.6, top = 6.8 }, { side = "left", a = 3.5, width = 4, bottom = 10.6, top = 14.6 },
		{ side = "back", a = -5, width = 5, bottom = 2.6, top = 6.8 }, { side = "back", a = 5, width = 5, bottom = 10.6, top = 14.6 },
	}
	local main = building({
		seed = 341, w = 22, d = 16, h = 17, t = 1, rowH = 1.2,
		wallMat = M.stucco, wallCol = rgb(244, 238, 226),
		door = { side = "front", a = -5, width = 4.2, height = 8 }, doorCol = rgb(36, 82, 130),
		windows = wins,
		rise = 7, over = 1.8, roofSegs = 6, roofCol = rgb(70, 74, 84), frameCol = rgb(60, 64, 74), cornerTrim = true, chimney = true,
		clear = true, dig = true, rebar = true, debris = 16, pile = 9, cell = 5,
		extraFinish = function(w, d, h, slabH)
			local list = bands(w, d, { slabH + 8.6 }, rgb(200, 196, 188))
			table.insert(list, P(Vector3.new(6.4, 0.4, 3), Vector3.new(-5, slabH + 8.4 + 0.5, -d / 2 - 1.5), SP, rgb(60, 64, 74), { anim = "drop" }))
			return list
		end,
		work = W,
	})
	local wing = building({
		seed = 342, w = 11, d = 14, h = 9, t = 1, rowH = 1.2,
		wallMat = M.stucco, wallCol = rgb(236, 228, 214),
		garageDoor = { a = 0, width = 8, height = 6.8 },
		windows = { { side = "right", a = 0, width = 4, bottom = 3, top = 6.6 } },
		rise = 4, over = 1.4, roofSegs = 4, roofCol = rgb(70, 74, 84), frameCol = rgb(60, 64, 74), cornerTrim = true,
		work = { pour = 40, walls = 120, windows = 30, roof = 60, finish = 60 },
	})
	shift(main, CFrame.new(-5, 0, 0))
	shift(wing, CFrame.new(12, 0, -1))
	local stages = merge(main, wing)
	-- the garden: a hedge along the front, a tree, a lamp post
	local fin = stages[#stages].adds
	for i = 0, 4 do table.insert(fin, P(Vector3.new(2.6, 2.4, 2.2), Vector3.new(-15 + i * 2.6, 1.2, -13.5), plain(Enum.Material.LeafyGrass), rgb(78, 140, 66), { anim = "grow" })) end
	append(fin, Z.tree(-14, -4, 6, rgb(110, 176, 80)))
	append(fin, Z.lamp(4, -14, 6))
	return stages, { size = Vector3.new(38, 26, 32) }
end

-- a red-brick pizzeria: big windows, an Italian awning, a neon sign, the oven chimney and a terrace
function B.PizzaPlace()
	local brick, green, red = rgb(150, 66, 50), rgb(30, 140, 70), rgb(206, 40, 44)
	return building({
		seed = 351, w = 26, d = 18, h = 11, t = 1, rowH = 1,
		wallMat = M.brick, wallCol = brick,
		door = { side = "front", a = 0, width = 4.4, height = 8 }, doorCol = rgb(40, 30, 26),
		windows = {
			{ side = "front", a = -7.8, width = 8, bottom = 1.8, top = 8 }, { side = "front", a = 7.8, width = 8, bottom = 1.8, top = 8 },
			{ side = "left", a = 0, width = 7, bottom = 2.4, top = 8 }, { side = "right", a = 0, width = 7, bottom = 2.4, top = 8 },
			{ side = "back", a = 0, width = 6, bottom = 3.5, top = 8 },
		},
		roof = "flat", roofCol = rgb(110, 112, 118), trimCol = rgb(236, 226, 206), frameCol = rgb(36, 30, 28),
		clear = true, dig = true, rebar = true, debris = 14, pile = 9, cell = 5,
		extraFinish = function(w, d, h, slabH)
			-- the awning in green, white and red
			local list = {}
			local cols = { green, WHITE, red }
			for i = 0, 11 do
				table.insert(list, P(Vector3.new(2, 1.3, 3), CFrame.new(-11 + i * 2, slabH + 8.95, -d / 2 - 1.75), FABRIC, cols[i % 3 + 1], { shape = "Wedge", anim = "drop" }))
			end
			-- the neon sign on the roof edge, on two posts
			for _, x in ipairs({ -6, 6 }) do table.insert(list, P(Vector3.new(0.5, 3, 0.5), Vector3.new(x, slabH + h + 2.5, -d / 2 + 1), METAL, INK, { anim = "steel" })) end
			table.insert(list, sign(Vector3.new(16, 3.6, 0.5), Vector3.new(0, slabH + h + 5.6, -d / 2 + 1), red, "PIZZA", rgb(255, 240, 200), true))
			-- the oven chimney
			table.insert(list, Z.cyl(2, 7, Vector3.new(8, slabH + h + 4.5, 5), METAL, rgb(160, 164, 170), "grow"))
			table.insert(list, Z.cyl(3, 0.6, Vector3.new(8, slabH + h + 8.3, 5), METAL, INK, "grow"))
			-- the terrace
			append(list, terraceTable(-8, -d / 2 - 7, green))
			append(list, terraceTable(0.5, -d / 2 - 7.5, red))
			append(list, terraceTable(9, -d / 2 - 7, green))
			append(list, planter(-12, -d / 2 - 2))
			append(list, planter(12, -d / 2 - 2))
			return list
		end,
		work = W,
	}), { size = Vector3.new(30, 22, 34) }
end

-- LEVEL 4 ----------------------------------------------------------------------------------------------------------
-- a corner market under two floors of flats: a fire escape, a water tank on the roof
function B.CornerMarket()
	local wins = {
		{ side = "front", a = -4, width = 13, bottom = 1.6, top = 6.6 },
		{ side = "left", a = -2, width = 8, bottom = 2, top = 6.6 },
	}
	for _, row in ipairs({ { 10, 14.4 }, { 18, 22.4 } }) do
		for _, a in ipairs({ -9, -3, 3, 9 }) do table.insert(wins, { side = "front", a = a, width = 3.6, bottom = row[1], top = row[2] }) end
		for _, a in ipairs({ -6, 0, 6 }) do
			table.insert(wins, { side = "left", a = a, width = 3.6, bottom = row[1], top = row[2] })
			table.insert(wins, { side = "back", a = a * 1.4, width = 3.6, bottom = row[1], top = row[2] })
		end
		for _, a in ipairs({ -6, 6 }) do table.insert(wins, { side = "right", a = a, width = 3.6, bottom = row[1], top = row[2] }) end
	end
	local stripe = rgb(36, 110, 180)
	return building({
		seed = 361, w = 26, d = 20, h = 25, t = 1, rowH = 1.25,
		wallMat = M.brick, wallCol = rgb(196, 116, 82),
		door = { side = "front", a = 8.5, width = 4.4, height = 7.6 }, doorCol = INK,
		windows = wins,
		roof = "flat", roofCol = rgb(110, 112, 118), trimCol = rgb(236, 226, 206), frameCol = rgb(240, 236, 228), cornerTrim = true,
		clear = true, dig = true, rebar = true, debris = 18, pile = 10, cell = 5,
		extraFinish = function(w, d, h, slabH)
			local list = bands(w, d, { slabH + 8.2, slabH + 16.2 }, rgb(236, 226, 206))
			append(list, Z.awning(-4, 14, slabH + 7.25, d, 7, stripe, WHITE))
			table.insert(list, sign(Vector3.new(20, 1.6, 0.4), Vector3.new(-1, slabH + 8.6 - 1.4, -d / 2 - 0.45), stripe, "MARKET"))
			-- the fire escape on the right wall: a landing a floor, rails, a ladder
			for _, y in ipairs({ slabH + 9.4, slabH + 17.4 }) do
				table.insert(list, P(Vector3.new(2.8, 0.3, 12), Vector3.new(w / 2 + 1.6, y, 0), METAL, INK, { anim = "beam" }))
				table.insert(list, P(Vector3.new(0.2, 0.2, 12), Vector3.new(w / 2 + 2.9, y + 2.4, 0), METAL, INK, { anim = "beam" }))
				for _, z in ipairs({ -5.9, 0, 5.9 }) do table.insert(list, P(Vector3.new(0.2, 2.4, 0.2), Vector3.new(w / 2 + 2.9, y + 1.2, z), METAL, INK, { anim = "steel" })) end
				table.insert(list, P(Vector3.new(0.4, 8.6, 1.6), CFrame.new(w / 2 + 1.6, y - 4.2, -3.5) * CFrame.Angles(math.rad(35), 0, 0), METAL, INK, { anim = "drop" }))
			end
			append(list, waterTank(-6, slabH + h + 1, 4))
			append(list, airUnit(6, slabH + h + 1, -2))
			-- crates of fruit out front
			for i, col in ipairs({ rgb(230, 60, 50), rgb(255, 180, 40), rgb(110, 190, 60) }) do
				local x = -10 + i * 3
				table.insert(list, P(Vector3.new(2.6, 1.2, 1.8), Vector3.new(x, 0.6, -d / 2 - 2.2), WOOD, rgb(170, 120, 76), { anim = "drop" }))
				for k = -1, 1 do table.insert(list, P(Vector3.one * 0.8, Vector3.new(x + k * 0.75, 1.5, -d / 2 - 2.2), SP, col, { shape = "Ball", anim = "grow" })) end
			end
			return list
		end,
		work = { clear = 60, dig = 120, rebar = 70, pour = 120, walls = 500, windows = 200, roof = 150, finish = 200 },
	}), { size = Vector3.new(34, 38, 30) }
end

-- a stone police station: two garage bays, a flag, a blue beacon on the roof
function B.PoliceStation()
	local navy, stone = rgb(30, 50, 100), rgb(222, 214, 196)
	local wins = {
		{ side = "front", a = -10, width = 4, bottom = 2.6, top = 7 },
		{ side = "left", a = -4, width = 4, bottom = 2.6, top = 7 }, { side = "left", a = 4, width = 4, bottom = 2.6, top = 7 },
		{ side = "back", a = -8, width = 4, bottom = 2.6, top = 7 }, { side = "back", a = 0, width = 4, bottom = 2.6, top = 7 }, { side = "back", a = 8, width = 4, bottom = 2.6, top = 7 },
	}
	for _, a in ipairs({ -10, -4, 2, 8 }) do table.insert(wins, { side = "front", a = a, width = 4, bottom = 11, top = 15.4 }) end
	for _, a in ipairs({ -5, 5 }) do
		table.insert(wins, { side = "left", a = a, width = 4, bottom = 11, top = 15.4 })
		table.insert(wins, { side = "right", a = a, width = 4, bottom = 11, top = 15.4 })
	end
	return building({
		seed = 371, w = 30, d = 20, h = 18, t = 1, rowH = 1.5,
		wallMat = STONE, wallCol = stone, wallName = "Stone Walls", wallTask = "Set the stone blocks",
		door = { side = "front", a = -3.5, width = 4.6, height = 8 }, doorCol = navy,
		garageDoors = { { a = 4.5, width = 6.5, height = 7 }, { a = 11.2, width = 6.5, height = 7 } },
		windows = wins,
		roof = "flat", roofCol = rgb(110, 112, 118), trimCol = navy, frameCol = navy, cornerTrim = true, plinthCol = rgb(120, 116, 108),
		clear = true, dig = true, rebar = true, debris = 18, pile = 10, cell = 5,
		extraFinish = function(w, d, h, slabH)
			local list = bands(w, d, { slabH + 9 }, navy)
			table.insert(list, sign(Vector3.new(12, 1.8, 0.4), Vector3.new(-6, slabH + h - 1.6, -d / 2 - 0.4), navy, "POLICE"))
			-- the canopy over the door, the steps
			table.insert(list, P(Vector3.new(7, 0.5, 3.2), Vector3.new(-3.5, slabH + 8.6, -d / 2 - 1.6), SP, navy, { anim = "drop" }))
			-- the flag and the beacon
			append(list, Z.flag(-13, -d / 2 - 4, 12, rgb(40, 90, 200)))
			table.insert(list, P(Vector3.new(4, 1, 1.2), Vector3.new(6, slabH + h + 1.9, -3), SP, INK, { anim = "drop" }))
			table.insert(list, P(Vector3.new(1.6, 0.8, 1), Vector3.new(5, slabH + h + 2.8, -3), NEON, rgb(60, 120, 255), { anim = "fade", light = true }))
			table.insert(list, P(Vector3.new(1.6, 0.8, 1), Vector3.new(7, slabH + h + 2.8, -3), NEON, rgb(255, 50, 60), { anim = "fade", light = true }))
			append(list, airUnit(-8, slabH + h + 1, 4))
			-- a patrol car parked by the bays
			local cz = -d / 2 - 7
			table.insert(list, P(Vector3.new(4.4, 1.6, 8.4), Vector3.new(8, 1.5, cz), SP, WHITE, { anim = "drop" }))
			table.insert(list, P(Vector3.new(4.2, 1.4, 4.4), Vector3.new(8, 3, cz + 0.4), SP, INK, { anim = "drop" }))
			table.insert(list, P(Vector3.new(4.5, 0.5, 2), Vector3.new(8, 1.4, cz - 2.6), SP, navy, { anim = "drop" }))
			for _, sx in ipairs({ -1, 1 }) do for _, sz in ipairs({ -1, 1 }) do
				table.insert(list, P(Vector3.new(0.8, 1.6, 1.6), CFrame.new(8 + sx * 2.2, 0.8, cz + sz * 2.8), SP, INK, { shape = "Cylinder", anim = "grow" }))
			end end
			table.insert(list, P(Vector3.new(2.4, 0.4, 0.8), Vector3.new(8, 3.9, cz + 0.4), NEON, rgb(60, 120, 255), { anim = "fade" }))
			return list
		end,
		work = { clear = 60, dig = 120, rebar = 70, pour = 120, walls = 450, windows = 160, roof = 150, finish = 200 },
	}), { size = Vector3.new(34, 26, 40) }
end

-- more helpers for the big ones ---------------------------------------------------------------------------------------
-- a wrought-iron balcony under a front window (y = the floor of the room)
local function ironBalcony(a, y, d, width, col)
	local list = {
		P(Vector3.new(width, 0.4, 2), Vector3.new(a, y - 0.2, -d / 2 - 1), STONE, rgb(232, 224, 210), { anim = "drop" }),
		P(Vector3.new(width, 0.22, 0.22), Vector3.new(a, y + 1.3, -d / 2 - 1.9), METAL, col, { anim = "drop" }),
	}
	for k = 0, 2 do table.insert(list, P(Vector3.new(0.16, 1.3, 0.16), Vector3.new(a - width / 2 + 0.3 + k * (width - 0.6) / 2, y + 0.65, -d / 2 - 1.9), METAL, col, { anim = "drop" })) end
	return list
end
-- vertical piers on a tower's four faces (art deco), full height
local function piers(w, d, y0, h, col, every, mat)
	local list = {}
	for _, side in ipairs({ "front", "back", "left", "right" }) do
		local len = (side == "front" or side == "back") and w or d
		local n = math.max(2, math.floor(len / (every or 6)))
		for i = 1, n - 1 do
			local a = -len / 2 + len * i / n
			table.insert(list, P(Vector3.new(0.9, h, 0.8), onWall(w, d, side, a, y0 + h / 2, 0.35), mat or STONE, col, { anim = "drop", side = side }))
		end
	end
	return list
end
-- a stepped crown of boxes on a tower roof (each one smaller), from y
local function steppedCrown(y, sizes, mat, col, trim)
	local list = {}
	for _, s in ipairs(sizes) do
		table.insert(list, P(Vector3.new(s[1], s[3], s[2]), Vector3.new(0, y + s[3] / 2, 0), mat, col, { anim = "drop" }))
		if trim then table.insert(list, P(Vector3.new(s[1] + 0.6, 0.5, s[2] + 0.6), Vector3.new(0, y + s[3] + 0.25, 0), METAL, trim, { anim = "drop" })) end
		y += s[3] + (trim and 0.5 or 0)
	end
	return list, y
end
-- a spire with a beacon on top
local function spire(y, h, col, beacon)
	return {
		Z.cyl(2.4, h * 0.3, Vector3.new(0, y + h * 0.15, 0), METAL, col, "grow"),
		Z.cyl(1.3, h * 0.45, Vector3.new(0, y + h * 0.3 + h * 0.225, 0), METAL, col, "grow"),
		Z.cyl(0.6, h * 0.25, Vector3.new(0, y + h * 0.75 + h * 0.125, 0), METAL, col, "grow"),
		P(Vector3.one * 1.6, Vector3.new(0, y + h + 0.6, 0), NEON, beacon or rgb(255, 60, 60), { shape = "Ball", anim = "grow", light = true }),
	}
end
-- a helipad on a roof (y = the roof top)
local function helipad(x, y, z, size)
	local list = {
		Z.disc(size, 0.5, Vector3.new(x, y + 0.25, z), SP, rgb(60, 64, 74), "rise"),
		Z.disc(size - 1.6, 0.56, Vector3.new(x, y + 0.28, z), SP, rgb(84, 88, 98), "rise"),
		P(Vector3.new(1, 0.1, size * 0.4), Vector3.new(x - size * 0.12, y + 0.6, z), SP, WHITE, { anim = "fade" }),
		P(Vector3.new(1, 0.1, size * 0.4), Vector3.new(x + size * 0.12, y + 0.6, z), SP, WHITE, { anim = "fade" }),
		P(Vector3.new(size * 0.24, 0.1, 1), Vector3.new(x, y + 0.6, z), SP, WHITE, { anim = "fade" }),
	}
	for i = 0, 5 do
		local a = i / 6 * math.pi * 2
		table.insert(list, P(Vector3.one * 0.7, Vector3.new(x + math.cos(a) * (size / 2 - 0.5), y + 0.75, z + math.sin(a) * (size / 2 - 0.5)), NEON, rgb(255, 210, 70), { shape = "Ball", anim = "grow" }))
	end
	return list
end
local TW = { clear = 300, dig = 600, rebar = 450, pour = 600, walls = 4200, roof = 600, finish = 1250 }

-- LEVEL 5 ----------------------------------------------------------------------------------------------------------
-- a boutique hotel: peach stucco, wrought-iron balconies, burgundy awnings, a vertical HOTEL sign
function B.BoutiqueHotel()
	local burgundy, peach = rgb(128, 36, 52), rgb(248, 222, 198)
	local wins = {
		{ side = "front", a = -9.5, width = 5, bottom = 2, top = 7 }, { side = "front", a = 9.5, width = 5, bottom = 2, top = 7 },
		{ side = "left", a = 0, width = 5, bottom = 2, top = 7 }, { side = "right", a = 0, width = 5, bottom = 2, top = 7 },
	}
	for _, row in ipairs({ { 10.5, 15.5 }, { 18, 23 }, { 25.5, 30.5 } }) do
		for _, a in ipairs({ -9.5, -3.2, 3.2, 9.5 }) do table.insert(wins, { side = "front", a = a, width = 3.6, bottom = row[1], top = row[2] }) end
		for _, a in ipairs({ -5, 5 }) do
			table.insert(wins, { side = "left", a = a, width = 3.6, bottom = row[1], top = row[2] })
			table.insert(wins, { side = "right", a = a, width = 3.6, bottom = row[1], top = row[2] })
		end
		for _, a in ipairs({ -8, 0, 8 }) do table.insert(wins, { side = "back", a = a, width = 3.6, bottom = row[1], top = row[2] }) end
	end
	return building({
		seed = 401, w = 28, d = 20, h = 33, t = 1, rowH = 1.65,
		wallMat = M.stucco, wallCol = peach,
		door = { side = "front", a = 0, width = 5, height = 7.6 }, doorCol = burgundy,
		windows = wins,
		roof = "flat", roofCol = rgb(120, 124, 130), trimCol = burgundy, frameCol = rgb(70, 50, 40), cornerTrim = true,
		clear = true, dig = true, rebar = true, debris = 18, pile = 10, cell = 5,
		extraFinish = function(w, d, h, slabH)
			local list = bands(w, d, { slabH + 8.6, slabH + 16.6, slabH + 24.1 }, rgb(238, 230, 214))
			for _, y in ipairs({ slabH + 10.5, slabH + 18, slabH + 25.5 }) do
				for _, a in ipairs({ -9.5, 9.5 }) do append(list, ironBalcony(a, y, d, 4.6, INK)) end
			end
			append(list, Z.awning(-9.5, 6, slabH + 7.6, d, 3, burgundy, rgb(250, 240, 230)))
			append(list, Z.awning(9.5, 6, slabH + 7.6, d, 3, burgundy, rgb(250, 240, 230)))
			-- the entrance canopy on brass posts, two lanterns
			table.insert(list, P(Vector3.new(8, 0.6, 5), Vector3.new(0, slabH + 8.3, -d / 2 - 2.5), SP, burgundy, { anim = "drop" }))
			for _, x in ipairs({ -3.6, 3.6 }) do table.insert(list, Z.cyl(0.5, 8.3, Vector3.new(x, slabH + 4.15, -d / 2 - 4.8), METAL, rgb(212, 170, 80), "grow")) end
			-- the vertical sign on the corner
			table.insert(list, sign(Vector3.new(2.6, 12, 0.5), Vector3.new(w / 2 - 2, slabH + 21, -d / 2 - 0.6), burgundy, "H\nO\nT\nE\nL", rgb(255, 226, 150), false))
			-- the roof terrace: two parasols, plants
			append(list, Z.moved(terraceTable(-6, 2, burgundy), CFrame.new(0, slabH + h + 1, 0)))
			append(list, Z.moved(terraceTable(5, 2, rgb(250, 240, 230)), CFrame.new(0, slabH + h + 1, 0)))
			append(list, Z.moved(planter(-11, -6), CFrame.new(0, slabH + h + 1, 0)))
			append(list, Z.moved(planter(11, -6), CFrame.new(0, slabH + h + 1, 0)))
			return list
		end,
		work = { clear = 80, dig = 160, rebar = 100, pour = 160, walls = 700, windows = 320, roof = 260, finish = 300 },
	}), { size = Vector3.new(32, 42, 32) }
end

-- a neon arcade: dark metal, a huge glass front, pink and cyan neon, a giant joystick on the roof
function B.Arcade()
	local pink, cyan, dark = rgb(255, 60, 180), rgb(40, 230, 255), rgb(44, 48, 66)
	return building({
		seed = 411, w = 30, d = 24, h = 26, t = 1, rowH = 2,
		wallMat = { Enum.Material.Metal, nil }, wallCol = dark, wallName = "Steel Walls", wallTask = "Bolt the wall panels", wallVerb = "metal",
		door = { side = "front", a = 0, width = 6, height = 8 }, doorCol = rgb(30, 30, 40),
		windows = {
			{ side = "front", a = -9.5, width = 9, bottom = 1.5, top = 8 }, { side = "front", a = 9.5, width = 9, bottom = 1.5, top = 8 },
			{ side = "front", a = 0, width = 24, bottom = 12, top = 22 },
			{ side = "left", a = 0, width = 16, bottom = 12, top = 20 }, { side = "right", a = 0, width = 16, bottom = 12, top = 20 },
		},
		roof = "flat", roofCol = rgb(70, 74, 90), trimCol = pink, frameCol = rgb(30, 30, 40), cornerTrim = true, plinthCol = rgb(30, 30, 40),
		clear = true, dig = true, rebar = true, debris = 18, pile = 10, cell = 5,
		extraFinish = function(w, d, h, slabH)
			local list = {}
			-- neon lines around the building
			for _, y in ipairs({ slabH + 9.6, slabH + 23.4 }) do
				local c = (y < 20) and cyan or pink
				table.insert(list, P(Vector3.new(w + 0.8, 0.5, 0.3), Vector3.new(0, y, -d / 2 - 0.2), NEON, c, { anim = "fade" }))
				table.insert(list, P(Vector3.new(w + 0.8, 0.5, 0.3), Vector3.new(0, y, d / 2 + 0.2), NEON, c, { anim = "fade" }))
				table.insert(list, P(Vector3.new(0.3, 0.5, d), Vector3.new(-w / 2 - 0.2, y, 0), NEON, c, { anim = "fade" }))
				table.insert(list, P(Vector3.new(0.3, 0.5, d), Vector3.new(w / 2 + 0.2, y, 0), NEON, c, { anim = "fade" }))
			end
			-- the big sign over the door
			table.insert(list, sign(Vector3.new(18, 2.6, 0.5), Vector3.new(0, slabH + 10.8, -d / 2 - 0.5), rgb(30, 30, 40), "ARCADE", pink, false))
			-- the giant joystick on the roof
			local y = slabH + h + 1
			table.insert(list, P(Vector3.new(10, 2.4, 8), Vector3.new(-4, y + 1.2, 2), SP, rgb(30, 30, 40), { anim = "drop" }))
			table.insert(list, Z.cyl(1.4, 7, Vector3.new(-6, y + 5.9, 2), METAL, rgb(200, 204, 212), "grow"))
			table.insert(list, P(Vector3.one * 4, Vector3.new(-6, y + 10, 2), SP, rgb(230, 40, 50), { shape = "Ball", anim = "grow" }))
			for i, c in ipairs({ pink, cyan, rgb(255, 220, 60) }) do
				table.insert(list, Z.cyl(1.6, 0.6, Vector3.new(-2.5 + i * 1.8, y + 2.7, 1), NEON, c, "grow"))
			end
			append(list, airUnit(8, y, -4))
			-- neon palm-free entrance: two light posts
			for _, x in ipairs({ -4, 4 }) do
				table.insert(list, Z.cyl(0.5, 5, Vector3.new(x, 2.5, -d / 2 - 3), METAL, rgb(30, 30, 40), "grow"))
				table.insert(list, P(Vector3.one * 1.3, Vector3.new(x, 5.6, -d / 2 - 3), NEON, (x < 0) and pink or cyan, { shape = "Ball", anim = "grow", light = true }))
			end
			return list
		end,
		work = { clear = 80, dig = 160, rebar = 100, pour = 160, walls = 600, windows = 300, roof = 260, finish = 340 },
	}), { size = Vector3.new(34, 42, 34) }
end

-- LEVEL 6 ----------------------------------------------------------------------------------------------------------
-- a brick apartment block: four tall floors, glass balconies, a water tank and a roof garden
function B.ApartmentBlock()
	local wins = {}
	for f = 0, 3 do
		local b, tp = 2.2 + f * 9, 7.6 + f * 9
		for _, a in ipairs(f == 0 and { -11, 11 } or { -11, 0, 11 }) do table.insert(wins, { side = "front", a = a, width = 6, bottom = b, top = tp }) end
		for _, a in ipairs({ -10, 0, 10 }) do table.insert(wins, { side = "back", a = a, width = 6, bottom = b, top = tp }) end
		for _, a in ipairs({ -5, 5 }) do
			table.insert(wins, { side = "left", a = a, width = 4.6, bottom = b, top = tp })
			table.insert(wins, { side = "right", a = a, width = 4.6, bottom = b, top = tp })
		end
	end
	return building({
		seed = 421, w = 34, d = 22, h = 36, t = 1, rowH = 3,
		wallMat = M.brick, wallCol = rgb(168, 96, 76),
		door = { side = "front", a = 0, width = 6, height = 8 }, doorCol = INK,
		windows = wins,
		roof = "flat", roofCol = rgb(110, 112, 118), trimCol = rgb(236, 230, 220), frameCol = rgb(242, 240, 234), cornerTrim = true,
		clear = true, dig = true, rebar = true, debris = 20, pile = 12, cell = 5,
		extraFinish = function(w, d, h, slabH)
			local list = bands(w, d, { slabH + 9, slabH + 18, slabH + 27 }, rgb(236, 230, 220))
			for f = 1, 3 do
				for _, a in ipairs({ -11, 0, 11 }) do append(list, frontBalcony(a, slabH + f * 9 + 0.6, d, 7.2, INK)) end
			end
			table.insert(list, P(Vector3.new(10, 0.5, 3.6), Vector3.new(0, slabH + 8.6, -d / 2 - 1.8), SP, INK, { anim = "drop" }))
			table.insert(list, sign(Vector3.new(6, 1.2, 0.3), Vector3.new(0, slabH + 9.4, -d / 2 - 3.5), INK, "No. 42"))
			local y = slabH + h + 1
			append(list, waterTank(-10, y, 3))
			-- the roof garden
			table.insert(list, P(Vector3.new(14, 0.6, 10), Vector3.new(6, y + 0.3, 0), GRASS, rgb(96, 166, 76), { anim = "rise" }))
			append(list, Z.moved(Z.tree(2, -2, 4, rgb(110, 176, 80)), CFrame.new(0, y + 0.6, 0)))
			append(list, Z.moved(Z.tree(10, 2, 4.5, rgb(96, 160, 70)), CFrame.new(0, y + 0.6, 0)))
			append(list, Z.moved(terraceTable(6, -1, rgb(250, 200, 70)), CFrame.new(0, y + 0.6, 0)))
			return list
		end,
		work = { clear = 120, dig = 240, rebar = 150, pour = 240, walls = 1200, windows = 600, roof = 300, finish = 400 },
	}), { size = Vector3.new(38, 50, 34) }
end

-- a limestone department store: big display windows, a columned portico, a clock, flags on the roof
function B.DepartmentStore()
	local stone, gold, green = rgb(232, 224, 206), rgb(212, 170, 80), rgb(28, 96, 70)
	local wins = {
		{ side = "front", a = -12, width = 7, bottom = 1.5, top = 9 }, { side = "front", a = 12, width = 7, bottom = 1.5, top = 9 },
		{ side = "left", a = -5, width = 6, bottom = 1.5, top = 9 }, { side = "right", a = -5, width = 6, bottom = 1.5, top = 9 },
	}
	for _, row in ipairs({ { 13, 20 }, { 25, 32 } }) do
		for _, a in ipairs({ -12, -6, 0, 6, 12 }) do table.insert(wins, { side = "front", a = a, width = 3.4, bottom = row[1], top = row[2] }) end
		for _, a in ipairs({ -6, 2, 10 }) do
			table.insert(wins, { side = "left", a = a, width = 3.4, bottom = row[1], top = row[2] })
			table.insert(wins, { side = "right", a = a, width = 3.4, bottom = row[1], top = row[2] })
		end
		for _, a in ipairs({ -9, 0, 9 }) do table.insert(wins, { side = "back", a = a, width = 3.4, bottom = row[1], top = row[2] }) end
	end
	return building({
		seed = 431, w = 34, d = 26, h = 36, t = 1, rowH = 2,
		wallMat = STONE, wallCol = stone, wallName = "Stone Walls", wallTask = "Set the stone blocks",
		door = { side = "front", a = 0, width = 7, height = 9.5 }, doorCol = rgb(60, 40, 28),
		windows = wins,
		roof = "flat", roofCol = rgb(120, 124, 130), trimCol = gold, frameCol = rgb(40, 44, 40), cornerTrim = true, plinthCol = rgb(150, 144, 130),
		clear = true, dig = true, rebar = true, debris = 20, pile = 12, cell = 5,
		extraFinish = function(w, d, h, slabH)
			local list = bands(w, d, { slabH + 11, slabH + 23 }, rgb(214, 204, 182))
			-- the portico: four columns, an entablature and a pediment
			for _, x in ipairs({ -6.5, -2.4, 2.4, 6.5 }) do
				table.insert(list, Z.cyl(1.6, 10.6, Vector3.new(x, slabH + 5.3, -d / 2 - 4), MARBLE, rgb(246, 242, 232), "grow"))
			end
			table.insert(list, P(Vector3.new(16, 1.4, 5.6), Vector3.new(0, slabH + 11.3, -d / 2 - 2.8), STONE, stone, { anim = "drop" }))
			append(list, Z.pediment(0, slabH + 12, -d / 2 - 2.8, 16, 3.6, 5.4, STONE, stone))
			table.insert(list, sign(Vector3.new(22, 2.4, 0.4), Vector3.new(0, slabH + h - 1.8, -d / 2 - 0.4), green, "GRAND STORE", gold))
			-- the clock over the entrance
			table.insert(list, P(Vector3.new(0.6, 5, 5), CFrame.new(0, slabH + 18, -d / 2 - 0.35) * CFrame.Angles(0, math.pi / 2, 0), MARBLE, WHITE, { shape = "Cylinder", anim = "grow" }))
		table.insert(list, P(Vector3.new(0.7, 5.6, 5.6), CFrame.new(0, slabH + 18, -d / 2 - 0.25) * CFrame.Angles(0, math.pi / 2, 0), METAL, gold, { shape = "Cylinder", anim = "grow" }))
			table.insert(list, P(Vector3.new(0.3, 1.8, 0.2), Vector3.new(0, slabH + 18.8, -d / 2 - 0.75), SP, INK, { anim = "fade" }))
			table.insert(list, P(Vector3.new(1.4, 0.3, 0.2), CFrame.new(0.5, slabH + 18, -d / 2 - 0.75), SP, INK, { anim = "fade" }))
			-- display window awnings, flags
			append(list, Z.awning(-12, 8, slabH + 9.6, d, 4, green, rgb(250, 246, 236)))
			append(list, Z.awning(12, 8, slabH + 9.6, d, 4, green, rgb(250, 246, 236)))
			for _, x in ipairs({ -14, 14 }) do append(list, Z.moved(Z.flag(x, -8, 8, (x < 0) and green or gold), CFrame.new(0, slabH + h + 1, 0))) end
			return list
		end,
		work = { clear = 120, dig = 240, rebar = 150, pour = 240, walls = 1100, windows = 520, roof = 300, finish = 480 },
	}), { size = Vector3.new(38, 48, 40) }
end

-- TOWERS (WOW_TOWERS, 2026-10-18; the owner: "the big ones look too simple: more unique, more wow") ------------------
-- Each one has its own silhouette: a twisting tower, a round needle with a sky saucer, round twin towers with a sky
-- bridge, a crown of golden spikes, a vertical forest, a slanted media tower, stacked rotated glass blocks, an art deco
-- tower with wings. Built like the live game's towers: groundworks, a frame floor by floor, the facade floor by floor,
-- the crown, the finishing (lights, signs).
local STEELC = rgb(196, 84, 54)
local DECKC = rgb(170, 172, 170)
local CORE = rgb(196, 196, 190)
-- a custom tower: the live groundworks, then (podium), frame, facade, crown, finishing
local function customTower(o)
	local rng = Random.new(o.seed)
	local stages = Z.groundworks(rng, o.w, o.d, o.work, 1.2, 6)
	if o.podium and #o.podium > 0 then
		table.insert(stages, { key = "podium", name = "Podium", task = "Build the base", verb = "brick", work = o.work.podium, adds = o.podium })
	end
	table.insert(stages, { key = "steel", name = o.frameName or "Steel Frame", task = "Raise the frame floor by floor", verb = "metal", work = o.work.steel, adds = o.frame })
	table.insert(stages, { key = "walls", name = o.facadeName or "Glass Facade", task = "Hang the facade floor by floor", verb = "glass", work = o.work.walls, adds = o.facade })
	table.insert(stages, { key = "roof", name = o.crownName or "Crown", task = "Raise the crown", verb = "metal", work = o.work.roof, adds = o.crown })
	table.insert(stages, { key = "finish", name = "Finishing", task = "Lights, signs & details", verb = "hammer", work = o.work.finish, adds = o.finish })
	return stages
end
local CT = { clear = 300, dig = 600, rebar = 450, pour = 600, podium = 700, steel = 1500, walls = 3200, roof = 900, finish = 900 }
-- a vertical cylinder piece standing on y (bottom), with an animation
local function cylAt(d, h, x, y, z, mat, col, anim, extra) return Z.cyl(d, h, Vector3.new(x, y + h / 2, z), mat, col, anim or "grow", extra) end
-- a glass block for stacking: a building without groundworks (its slab is the floor it stands on)
local function glassBlock(seed, w, d, h, floorH, glass, band, ground)
	return building({
		seed = seed, w = w, d = d, h = h, t = 1, rowH = floorH / 2, steel = true, floorH = floorH,
		wallMat = { Enum.Material.Glass, nil }, wallCol = glass, wallName = "Glass Facade", wallTask = "Hang the glass panels", wallVerb = "glass",
		door = ground and { side = "front", a = 0, width = 8, height = 7 } or nil, doorCol = rgb(30, 34, 44),
		roof = "flat", roofMat = M.concrete, roofCol = rgb(90, 94, 104), trimCol = band, frameCol = band, cornerTrim = true, plinth = ground == true,
		plinthCol = rgb(60, 64, 74),
		clear = ground, dig = ground, rebar = ground, debris = 24, pile = 12, cell = 6,
		extraFinish = function(w2, d2, h2, slabH)
			local ys = {}
			for k = 1, math.floor(h2 / floorH) - 1 do table.insert(ys, slabH + floorH * k) end
			return bands(w2, d2, ys, band)
		end,
		work = { clear = 200, dig = 400, rebar = 300, pour = 300, walls = 1400, roof = 300, finish = 300 },
	})
end

-- LEVEL 7 ----------------------------------------------------------------------------------------------------------
-- an art deco hotel: a stone-ribbed tower between two lower wings, a golden sunburst crown, a spire, a blade sign
function B.DecoHotel()
	local gold, stone, glass = rgb(214, 172, 84), rgb(236, 226, 204), rgb(70, 100, 130)
	local main = glassTower({
		seed = 501, w = 22, d = 20, h = 48, floorH = 8, glass = glass, band = gold, trim = gold, doorW = 7,
		extra = function(w, d, h, slabH)
			local list = piers(w, d, slabH, h, stone, 2.8)
			local crown, top = steppedCrown(slabH + h + 1, { { w - 4, d - 4, 5 }, { w - 9, d - 9, 4 }, { w - 13, d - 13, 3 } }, STONE, stone, gold)
			append(list, crown)
			-- the sunburst: golden blades fanning out over the front of the crown
			for k = -3, 3 do
				table.insert(list, P(Vector3.new(1.2, 13, 0.5), CFrame.new(0, slabH + h + 2, -d / 2 + 2.6) * CFrame.Angles(0, 0, math.rad(k * 17)) * CFrame.new(0, 6.5, 0), METAL, gold, { anim = "drop" }))
			end
			append(list, spire(top, 22, gold, rgb(255, 230, 160)))
			table.insert(list, sign(Vector3.new(2.8, 16, 0.6), Vector3.new(w / 2 - 1.6, slabH + 26, -d / 2 - 1.2), rgb(40, 30, 26), "H\nO\nT\nE\nL", rgb(255, 214, 120), true))
			table.insert(list, P(Vector3.new(14, 0.7, 6), Vector3.new(0, slabH + 8.6, -d / 2 - 3), METAL, gold, { anim = "drop" }))
			for _, x in ipairs({ -6, 6 }) do table.insert(list, Z.cyl(0.6, 8.4, Vector3.new(x, slabH + 4.2, -d / 2 - 5.6), METAL, gold, "grow")) end
			return list
		end,
		work = TW,
	})
	local function wing(seed)
		local wins = {}
		for _, row in ipairs({ { 2.5, 7 }, { 10.5, 15 }, { 18.5, 23 } }) do
			for _, a in ipairs({ -4.5, 4.5 }) do table.insert(wins, { side = "front", a = a, width = 3, bottom = row[1], top = row[2] }) end
			for _, a in ipairs({ -5, 5 }) do table.insert(wins, { side = "back", a = a, width = 3, bottom = row[1], top = row[2] }) end
		end
		return building({
			seed = seed, w = 12, d = 18, h = 25, t = 1, rowH = 2.5,
			wallMat = STONE, wallCol = stone, wallName = "Stone Walls", wallTask = "Set the stone blocks",
			windows = wins, roof = "flat", roofCol = rgb(120, 124, 130), trimCol = gold, frameCol = rgb(60, 50, 40), cornerTrim = true,
			extraFinish = function(w, d, h, slabH) return bands(w, d, { slabH + 8.5, slabH + 16.5 }, gold) end,
			work = { pour = 60, walls = 300, windows = 120, roof = 80, finish = 80 },
		})
	end
	local stages = merge(main, shift(wing(502), CFrame.new(-17.2, 0, 0)))
	stages = merge(stages, shift(wing(503), CFrame.new(17.2, 0, 0)))
	return stages, { size = Vector3.new(48, 92, 34) }
end

-- a tech headquarters: three glass blocks stacked and turned against each other, roof gardens, a glowing logo
function B.TechHQ()
	local teal, white = rgb(40, 200, 180), WHITE
	local a = glassBlock(511, 34, 22, 16, 8, rgb(130, 205, 225), white, true)
	local b = shift(glassBlock(512, 30, 24, 16, 8, rgb(110, 185, 215), white, false), CFrame.new(0, 18.2, 0) * CFrame.Angles(0, math.rad(24), 0))
	local c = shift(glassBlock(513, 26, 20, 16, 8, rgb(90, 170, 210), white, false), CFrame.new(1, 36.4, 0) * CFrame.Angles(0, math.rad(-16), 0))
	local stages = merge(merge(a, b), c)
	local fin = stages[#stages].adds
	-- roof gardens on what each block leaves open, solar panels, the logo on top
	local y = 36.4 + 1.2 + 16 + 1
	table.insert(fin, P(Vector3.new(16, 0.6, 10), CFrame.new(1, y + 0.3, 0) * CFrame.Angles(0, math.rad(-16), 0), GRASS, rgb(96, 170, 80), { anim = "rise" }))
	for _, x in ipairs({ -4, 5 }) do append(fin, Z.moved(Z.tree(x, 0, 3.5, rgb(100, 180, 80)), CFrame.new(1, y + 0.6, 0) * CFrame.Angles(0, math.rad(-16), 0))) end
	for i = 0, 2 do
		table.insert(fin, P(Vector3.new(5, 0.3, 3), CFrame.new(-12 + i * 6, 19.6, 9) * CFrame.Angles(math.rad(-22), 0, 0), GLASS, rgb(30, 50, 110), { anim = "drop" }))
	end
	table.insert(fin, P(Vector3.new(0.8, 10, 10), CFrame.new(1, y + 6, 0) * CFrame.Angles(0, math.rad(-16) + math.pi / 2, 0), NEON, teal, { shape = "Cylinder", anim = "grow" }))
	table.insert(fin, P(Vector3.new(1, 6, 6), CFrame.new(1, y + 6, 0) * CFrame.Angles(0, math.rad(-16) + math.pi / 2, 0), SP, rgb(30, 40, 60), { shape = "Cylinder", anim = "grow" }))
	table.insert(fin, sign(Vector3.new(14, 3, 0.5), Vector3.new(0, 15, -11.6), rgb(30, 40, 60), "NOVA", teal))
	append(fin, planter(-14, -15))
	append(fin, planter(14, -15))
	return stages, { size = Vector3.new(44, 72, 44) }
end

-- LEVEL 8 ----------------------------------------------------------------------------------------------------------
-- a vertical forest: a white tower whose balconies on every side carry trees and hanging green, a pool on the roof
function B.ResidenceTower()
	local floors = 10
	return glassTower({
		seed = 601, w = 28, d = 28, h = floors * 8, floorH = 8, glass = rgb(160, 210, 225), band = rgb(246, 246, 242), trim = rgb(246, 246, 242), doorW = 8,
		extra = function(w, d, h, slabH)
			local list = {}
			for f = 1, floors - 1 do
				local y = slabH + f * 8
				for si, side in ipairs({ "front", "right", "back", "left" }) do
					local a = ((f + si) % 2 == 0) and -6 or 6
					local base = onWall(w, d, side, a, y, 0)
					-- the balcony slab and its planter wall, a tree on it, green hanging over the edge
					table.insert(list, P(Vector3.new(11, 0.5, 3.4), base * CFrame.new(0, -0.25, -1.7), CONC, rgb(236, 236, 232), { anim = "drop", side = side }))
					table.insert(list, P(Vector3.new(11, 1.4, 0.6), base * CFrame.new(0, 0.7, -3.2), CONC, rgb(236, 236, 232), { anim = "drop", side = side }))
					table.insert(list, P(Vector3.new(10.4, 1.6, 0.8), base * CFrame.new(0, -0.6, -3.7), plain(Enum.Material.LeafyGrass), rgb(84, 150, 70), { anim = "grow", side = side }))
					table.insert(list, Z.cyl(0.5, 3, (base * CFrame.new(2, 1.5, -1.8)).Position, WOOD, rgb(112, 80, 54), "grow"))
					table.insert(list, P(Vector3.one * 4.2, (base * CFrame.new(2, 4.4, -1.8)).Position, plain(Enum.Material.LeafyGrass), (f % 3 == 0) and rgb(120, 180, 70) or rgb(80, 150, 66), { shape = "Ball", anim = "grow", side = side }))
					table.insert(list, P(Vector3.one * 2.4, (base * CFrame.new(-3, 1.6, -2.2)).Position, plain(Enum.Material.LeafyGrass), rgb(96, 166, 76), { shape = "Ball", anim = "grow", side = side }))
				end
			end
			local y = slabH + h + 1
			table.insert(list, P(Vector3.new(w - 4, 0.6, d - 4), Vector3.new(0, y + 0.3, 0), WOOD, rgb(196, 150, 104), { anim = "rise" }))
			table.insert(list, P(Vector3.new(14, 0.2, 9), Vector3.new(-3, y + 0.72, 3), GLASS, rgb(60, 180, 235), { t = 0.15, anim = "fade" }))
			for _, x in ipairs({ -9, -4.5, 0 }) do table.insert(list, P(Vector3.new(1.8, 0.5, 4.4), Vector3.new(x, y + 0.85, -8.5), FABRIC, WHITE, { anim = "drop" })) end
			append(list, Z.moved(Z.tree(8, 6, 4, rgb(96, 166, 76)), CFrame.new(0, y + 0.6, 0)))
			append(list, Z.moved(Z.tree(8, -6, 3.5, rgb(120, 180, 70)), CFrame.new(0, y + 0.6, 0)))
			table.insert(list, P(Vector3.new(12, 0.6, 5), Vector3.new(0, slabH + 8.6, -d / 2 - 2.5), SP, rgb(60, 64, 74), { anim = "drop" }))
			return list
		end,
		work = TW,
	}), { size = Vector3.new(38, 90, 38) }
end

-- a media tower: dark glass under a slanted glass top, giant screens on two faces, neon edges, a satellite dish
function B.MediaTower()
	local magenta, cyan = rgb(255, 70, 160), rgb(60, 210, 255)
	return glassTower({
		seed = 611, w = 30, d = 28, h = 80, floorH = 8, glass = rgb(46, 58, 84), band = rgb(30, 34, 44), trim = rgb(30, 34, 44), doorW = 8,
		extra = function(w, d, h, slabH)
			local list = {}
			-- the slanted glass top (high at the back) and its neon edge
			local y = slabH + h + 1
			table.insert(list, P(Vector3.new(w, 18, d), Vector3.new(0, y + 9, 0), GLASS, rgb(56, 70, 100), { shape = "Wedge", anim = "drop" }))
			local len = math.sqrt(d * d + 18 * 18)
			for _, x in ipairs({ -w / 2 - 0.2, w / 2 + 0.2 }) do
				table.insert(list, P(Vector3.new(0.5, 0.6, len), CFrame.new(x, y + 9, 0) * CFrame.Angles(-math.atan2(18, d), 0, 0), NEON, magenta, { anim = "fade" }))
			end
			-- neon on the four corners, all the way up
			for _, sx in ipairs({ -1, 1 }) do for _, sz in ipairs({ -1, 1 }) do
				table.insert(list, P(Vector3.new(0.6, h, 0.6), Vector3.new(sx * (w / 2 + 0.35), slabH + h / 2, sz * (d / 2 + 0.35)), NEON, (sz < 0) and cyan or magenta, { anim = "fade" }))
			end end
			-- the screens
			table.insert(list, P(Vector3.new(24, 16, 0.6), Vector3.new(0, slabH + 44, -d / 2 - 1.2), SP, rgb(20, 22, 30), { anim = "drop" }))
			table.insert(list, sign(Vector3.new(22.4, 14.4, 0.4), Vector3.new(0, slabH + 44, -d / 2 - 1.6), rgb(40, 110, 255), "LIVE 24/7", WHITE, true))
			table.insert(list, P(Vector3.new(0.6, 14, 20), Vector3.new(-w / 2 - 1.2, slabH + 28, 0), SP, rgb(20, 22, 30), { anim = "drop" }))
			table.insert(list, P(Vector3.new(18.6, 12.6, 0.4), CFrame.new(-w / 2 - 1.6, slabH + 28, 0) * CFrame.Angles(0, math.pi / 2, 0), NEON, magenta, { anim = "drop", text = "NEWS", textCol = WHITE }))
			-- the dish and the mast on the high end of the top
			table.insert(list, P(Vector3.new(0.8, 9, 9), CFrame.new(6, y + 21, 9) * CFrame.Angles(0, math.rad(-30), math.rad(35)), METAL, WHITE, { shape = "Cylinder", anim = "grow" }))
			for _, sx in ipairs({ -1, 1 }) do for _, sz in ipairs({ -1, 1 }) do
				table.insert(list, P(Vector3.new(0.4, 20, 0.4), Vector3.new(-6 + sx * 1.2, y + 28, 10 + sz * 1.2), METAL, rgb(220, 60, 60), { anim = "steel" }))
			end end
			for k = 1, 3 do table.insert(list, P(Vector3.new(2.8, 0.3, 2.8), Vector3.new(-6, y + 18 + k * 5, 10), METAL, WHITE, { anim = "beam" })) end
			table.insert(list, P(Vector3.one * 1.4, Vector3.new(-6, y + 38.8, 10), NEON, rgb(255, 50, 50), { shape = "Ball", anim = "grow", light = true }))
			return list
		end,
		work = TW,
	}), { size = Vector3.new(36, 130, 34) }
end

-- LEVEL 9 ----------------------------------------------------------------------------------------------------------
-- the Crown Plaza: a stone podium, a blue glass tower with golden piers, crowned by a ring of golden spikes and a dome
function B.CrownPlaza()
	local gold, stone = rgb(232, 186, 70), rgb(230, 222, 204)
	local stages = glassTower({
		seed = 701, w = 30, d = 30, h = 96, floorH = 8, glass = rgb(60, 110, 185), band = rgb(200, 206, 216), trim = gold, doorW = 10,
		extra = function(w, d, h, slabH)
			local list = piers(w, d, slabH + 12, h - 12, gold, 6, METAL)
			local y = slabH + h + 1
			-- the crown: a golden ring, twelve spikes with lights, a glass dome, a spire
			table.insert(list, Z.cyl(30, 3, Vector3.new(0, y + 1.5, 0), METAL, gold, "drop"))
			for i = 0, 11 do
				local a = i / 12 * math.pi * 2
				local x, z = math.cos(a) * 13, math.sin(a) * 13
				local tall = (i % 2 == 0) and 16 or 11
				table.insert(list, Z.cyl(2.2, tall * 0.6, Vector3.new(x, y + 3 + tall * 0.3, z), METAL, gold, "grow"))
				table.insert(list, Z.cyl(1.2, tall * 0.4, Vector3.new(x, y + 3 + tall * 0.8, z), METAL, gold, "grow"))
				table.insert(list, P(Vector3.one * 1.6, Vector3.new(x, y + 3.6 + tall, z), NEON, rgb(255, 236, 170), { shape = "Ball", anim = "grow", light = (i % 4 == 0) }))
			end
			for k = 0, 3 do table.insert(list, Z.cyl(20 - k * 4.5, 2.6, Vector3.new(0, y + 4.3 + k * 2.6, 0), GLASS, rgb(110, 170, 235), "drop")) end
			append(list, spire(y + 13.7, 24, gold, rgb(255, 230, 160)))
			table.insert(list, sign(Vector3.new(18, 2.6, 0.4), Vector3.new(0, slabH + 13.6, -d / 2 - 5.6), rgb(30, 40, 70), "CROWN PLAZA", gold))
			return list
		end,
		work = TW,
	})
	-- the podium: a two-storey stone base with a glass front, around the tower's foot
	local pod = {
		P(Vector3.new(42, 12, 6), Vector3.new(0, 1.2 + 6, -18), STONE, stone, { anim = "drop" }),
		P(Vector3.new(6, 12, 30), Vector3.new(-18, 1.2 + 6, 0), STONE, stone, { anim = "drop" }),
		P(Vector3.new(6, 12, 30), Vector3.new(18, 1.2 + 6, 0), STONE, stone, { anim = "drop" }),
		P(Vector3.new(30, 8, 0.4), Vector3.new(0, 1.2 + 4.6, -21.2), GLASS, rgb(150, 200, 230), { t = 0.2, anim = "fade" }),
		P(Vector3.new(43, 1, 7), Vector3.new(0, 1.2 + 12.5, -18), METAL, gold, { anim = "drop" }),
		P(Vector3.new(7, 1, 31), Vector3.new(-18, 1.2 + 12.5, 0), METAL, gold, { anim = "drop" }),
		P(Vector3.new(7, 1, 31), Vector3.new(18, 1.2 + 12.5, 0), METAL, gold, { anim = "drop" }),
	}
	for _, x in ipairs({ -10, 0, 10 }) do append(pod, Z.moved(planter(x, -23), CFrame.new(0, 0, 0))) end
	-- (right after the foundation: the base goes up before the tower's frame)
	local at = #stages
	for i, st in ipairs(stages) do if st.key == "pour" then at = i + 1 end end
	table.insert(stages, at, { key = "podium", name = "Podium", task = "Build the stone base", verb = "brick", work = 700, adds = pod })
	return stages, { size = Vector3.new(44, 150, 46) }
end

-- twin towers: two round towers tapering in three tiers, joined by a sky bridge, with tall pinnacles
function B.TwinTowers2()
	local frame, facade, crown, fin, podium = {}, {}, {}, {}, {}
	local steel, glass, band = rgb(200, 206, 214), rgb(150, 190, 225), rgb(220, 224, 232)
	local fh = 6
	local tiers = { { 18, 9 }, { 15, 5 }, { 12, 3 } }
	local tops = {}
	for _, tx in ipairs({ -12, 12 }) do
		local y = 1.2
		for _, t in ipairs(tiers) do
			local dia, n = t[1], t[2]
			for f = 1, n do
				table.insert(frame, cylAt(6, fh, tx, y, 0, CONC, CORE, "grow", { noCollide = true }))
				table.insert(frame, cylAt(dia - 2, 0.4, tx, y + fh - 0.4, 0, CONC, DECKC, "deck", { noCollide = true }))
				table.insert(facade, cylAt(dia - 0.6, fh - 0.8, tx, y + 0.4, 0, GLASS, glass, "drop"))
				table.insert(facade, cylAt(dia + 0.8, 0.8, tx, y + fh - 0.8, 0, METAL, band, "drop"))
				y += fh
			end
			-- vertical fins around the tier
			for k = 0, 7 do
				local a = k / 8 * math.pi * 2
				table.insert(fin, P(Vector3.new(0.6, n * fh, 0.9), Vector3.new(tx + math.cos(a) * (dia / 2 + 0.3), y - n * fh / 2, math.sin(a) * (dia / 2 + 0.3)), METAL, steel, { anim = "fade" }))
			end
		end
		tops[#tops + 1] = y
		-- the pinnacle
		table.insert(crown, cylAt(9, 3, tx, y, 0, METAL, steel, "grow"))
		table.insert(crown, cylAt(6, 5, tx, y + 3, 0, GLASS, glass, "grow"))
		table.insert(crown, cylAt(4, 3, tx, y + 8, 0, METAL, steel, "grow"))
		append(crown, Z.moved(spire(y + 11, 22, steel, rgb(255, 240, 200)), CFrame.new(tx, 0, 0)))
	end
	-- the sky bridge (two floors) at floor 7, on two legs
	local by = 1.2 + 6 * fh
	table.insert(fin, P(Vector3.new(8, 5, 6), Vector3.new(0, by + 2.5, 0), GLASS, rgb(170, 210, 235), { anim = "beam" }))
	table.insert(fin, P(Vector3.new(8.4, 0.8, 6.4), Vector3.new(0, by - 0.4, 0), METAL, band, { anim = "beam" }))
	table.insert(fin, P(Vector3.new(8.4, 0.8, 6.4), Vector3.new(0, by + 5.4, 0), METAL, band, { anim = "beam" }))
	for _, s in ipairs({ -1, 1 }) do
		table.insert(fin, P(Vector3.new(0.8, 14, 0.8), CFrame.new(s * 3.5, by - 7, 0) * CFrame.Angles(0, 0, s * math.rad(25)), METAL, band, { anim = "steel" }))
	end
	-- the podium between them
	table.insert(podium, P(Vector3.new(20, 9, 24), Vector3.new(0, 1.2 + 4.5, 2), STONE, rgb(226, 222, 214), { anim = "drop" }))
	table.insert(podium, P(Vector3.new(14, 6, 0.4), Vector3.new(0, 1.2 + 3.4, -10.2), GLASS, rgb(150, 200, 230), { t = 0.2, anim = "fade" }))
	table.insert(podium, P(Vector3.new(21, 0.8, 25), Vector3.new(0, 1.2 + 9.4, 2), METAL, band, { anim = "drop" }))
	table.insert(fin, sign(Vector3.new(12, 2, 0.4), Vector3.new(0, 1.2 + 7.6, -10.5), rgb(40, 60, 90), "TWIN TOWERS"))
	return customTower({ seed = 711, w = 44, d = 24, work = CT, podium = podium, frame = frame, facade = facade, crown = crown, finish = fin, crownName = "Pinnacles" }),
		{ size = Vector3.new(46, 140, 26) }
end

-- LEVEL 10 ---------------------------------------------------------------------------------------------------------
-- the Sky Needle: a round tower tapering up to a glass sky saucer, a long needle with a light
function B.SkyNeedle()
	local frame, facade, crown, fin, podium = {}, {}, {}, {}, {}
	local white, glass = rgb(240, 242, 246), rgb(150, 205, 240)
	-- the round base: stone, a glass lobby ring, a white band
	table.insert(podium, cylAt(40, 2.4, 0, 1.2, 0, STONE, rgb(226, 222, 214), "grow"))
	table.insert(podium, cylAt(38, 5.6, 0, 3.6, 0, GLASS, rgb(170, 215, 240), "grow", { t = 0.2 }))
	table.insert(podium, cylAt(41, 1.6, 0, 9.2, 0, METAL, white, "grow"))
	local y = 10.8
	local n, fh = 18, 6
	for f = 0, n - 1 do
		local dia = 30 - f * 0.45
		table.insert(frame, cylAt(9, fh, 0, y, 0, CONC, CORE, "grow", { noCollide = true }))
		table.insert(frame, cylAt(dia - 2, 0.4, 0, y + fh - 0.4, 0, CONC, DECKC, "deck", { noCollide = true }))
		table.insert(facade, cylAt(dia - 0.6, fh - 0.8, 0, y + 0.4, 0, GLASS, glass, "drop"))
		table.insert(facade, cylAt(dia + 0.8, 0.8, 0, y + fh - 0.8, 0, METAL, white, "drop"))
		y += fh
	end
	-- the saucer: a cone of rings under it, the deck, the glass ring, the roof, a dome
	for k, dia in ipairs({ 24, 30, 36, 42 }) do table.insert(crown, cylAt(dia, 1.2, 0, y + (k - 1) * 1.2, 0, METAL, white, "grow")) end
	y += 4.8
	table.insert(crown, cylAt(50, 2, 0, y, 0, METAL, white, "grow"))
	table.insert(crown, cylAt(46, 5.4, 0, y + 2, 0, GLASS, rgb(190, 228, 250), "grow", { t = 0.15 }))
	table.insert(crown, cylAt(52, 1.6, 0, y + 7.4, 0, METAL, white, "grow"))
	table.insert(crown, cylAt(34, 2.4, 0, y + 9, 0, GLASS, glass, "grow"))
	table.insert(crown, cylAt(22, 2, 0, y + 11.4, 0, METAL, white, "grow"))
	append(crown, spire(y + 13.4, 42, white, rgb(120, 220, 255)))
	-- lights around the saucer rim
	for i = 0, 15 do
		local a = i / 16 * math.pi * 2
		table.insert(fin, P(Vector3.one * 1.1, Vector3.new(math.cos(a) * 26, y + 8.2, math.sin(a) * 26), NEON, rgb(120, 220, 255), { shape = "Ball", anim = "grow", light = (i % 4 == 0) }))
	end
	table.insert(fin, P(Vector3.new(14, 0.7, 6), Vector3.new(0, 9.6, -21), METAL, white, { anim = "drop" }))
	table.insert(fin, sign(Vector3.new(12, 2, 0.4), Vector3.new(0, 7.4, -19.4), rgb(30, 50, 80), "SKY NEEDLE", rgb(160, 225, 255)))
	return customTower({ seed = 801, w = 42, d = 42, work = CT, podium = podium, frame = frame, facade = facade, crown = crown, finish = fin, crownName = "Sky Saucer" }),
		{ size = Vector3.new(52, 196, 52) }
end

-- the Twist Tower: every floor turned a little more than the one below, gold bands, neon corners, a golden crown
function B.DiamondTower()
	local frame, facade, crown, fin = {}, {}, {}, {}
	local s, fh, n = 26, 6.4, 22
	local gold, glass = rgb(240, 196, 70), rgb(40, 90, 170)
	local corners = { { -1, -1 }, { 1, -1 }, { 1, 1 }, { -1, 1 } }
	local function at(turn, x, y, z) return CFrame.new(0, y, 0) * CFrame.Angles(0, turn, 0) * CFrame.new(x, 0, z) end
	for f = 0, n - 1 do
		local y = 1.2 + f * fh
		local turn = math.rad(f * 4)
		if f > 0 then table.insert(frame, P(Vector3.new(s - 3, 0.4, s - 3), at(turn, 0, y + 0.2, 0), CONC, DECKC, { anim = "deck", noCollide = true })) end
		for _, c in ipairs(corners) do
			table.insert(frame, P(Vector3.new(0.9, fh - 0.6, 0.9), at(turn, c[1] * (s / 2 - 2), y + (fh - 0.6) / 2, c[2] * (s / 2 - 2)), METAL, STEELC, { anim = "steel", noCollide = true }))
		end
		table.insert(facade, P(Vector3.new(s - 0.6, fh - 0.8, s - 0.6), at(turn, 0, y + 0.4 + (fh - 0.8) / 2, 0), GLASS, glass, { anim = "drop" }))
		table.insert(facade, P(Vector3.new(s + 0.8, 0.8, s + 0.8), at(turn, 0, y + fh - 0.4, 0), METAL, gold, { anim = "drop" }))
		if f % 2 == 1 then
			for _, c in ipairs(corners) do
				table.insert(fin, P(Vector3.new(0.5, fh * 2 - 1, 0.5), at(math.rad((f - 0.5) * 4), c[1] * (s / 2 + 0.2), y, c[2] * (s / 2 + 0.2)), NEON, rgb(120, 220, 255), { anim = "fade" }))
			end
		end
	end
	-- the crown: three shrinking turned blocks in gold and glass, a spire
	local y = 1.2 + n * fh
	for k, sz in ipairs({ 22, 17, 12 }) do
		local turn = math.rad((n + k * 3) * 4)
		table.insert(crown, P(Vector3.new(sz, 4, sz), at(turn, 0, y + 2, 0), GLASS, rgb(70, 130, 210), { anim = "drop" }))
		table.insert(crown, P(Vector3.new(sz + 1, 0.8, sz + 1), at(turn, 0, y + 4.4, 0), METAL, gold, { anim = "drop" }))
		y += 4.8
	end
	append(crown, spire(y, 30, gold, rgb(255, 230, 160)))
	-- the lobby canopy and the sign
	table.insert(fin, P(Vector3.new(16, 0.7, 6), Vector3.new(0, 8.6, -16), METAL, gold, { anim = "drop" }))
	table.insert(fin, sign(Vector3.new(12, 2.2, 0.4), Vector3.new(0, 10.4, -13.6), rgb(20, 30, 60), "TWIST TOWER", gold))
	return customTower({ seed = 811, w = 34, d = 34, work = CT, frame = frame, facade = facade, crown = crown, finish = fin, crownName = "Golden Crown" }),
		{ size = Vector3.new(40, 192, 40) }
end

return B
