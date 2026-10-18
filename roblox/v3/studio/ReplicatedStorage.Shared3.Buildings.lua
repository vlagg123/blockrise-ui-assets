-- BlockRise 3.0 (tycoon prototype, PROTO3_V1, 2026-10-18) - the buildings, generated from parts in a bright toy-town
-- style: chunky white trims, striped awnings, big readable signs, rooftop life (AC units, water tanks, antennas, a
-- helipad on the towers). Buildings.make(key) returns the pieces floor by floor, so a construction can raise it one
-- floor at a time:
--   { floors = { [0] = foundation, [1..n] = floors, [n + 1] = roof }, height, w, d, n }
-- Every piece is a spec { k = "box" | "wedge" | "cyl" | "ball", s = size, c = CFrame (local: the ground centre, the
-- front facing -Z), col, m = material, t = transparency, text = sign text, tcol = text colour }.
local B = {}
local C3 = Color3.fromRGB
local Mat = Enum.Material
local at = CFrame.new

local WHITE = C3(250, 250, 246)
local GLASS = C3(150, 205, 240)
local GLASS_DARK = C3(70, 120, 170)
local CONCRETE = C3(214, 214, 208)
local METAL = C3(120, 128, 140)

local function box(list, s, c, col, m, extra)
	local p = { k = "box", s = s, c = c, col = col, m = m or Mat.SmoothPlastic }
	if extra then for k, v in pairs(extra) do p[k] = v end end
	table.insert(list, p)
	return p
end
local function wedge(list, s, c, col, m) table.insert(list, { k = "wedge", s = s, c = c, col = col, m = m or Mat.SmoothPlastic }) end
local function cyl(list, r, h, c, col, m) table.insert(list, { k = "cyl", s = Vector3.new(h, r * 2, r * 2), c = c * CFrame.Angles(0, 0, math.pi / 2), col = col, m = m or Mat.SmoothPlastic }) end
local function ball(list, r, c, col, m) table.insert(list, { k = "ball", s = Vector3.one * r * 2, c = c, col = col, m = m or Mat.SmoothPlastic }) end

-- a window (white frame, glass a little in front of it) on a wall face. face: "front" | "back" | "left" | "right"
local function window(list, w, d, face, x, y, ww, wh, glass)
	local fw = 0.5 -- frame thickness around the glass
	local cf
	if face == "front" then cf = at(x, y, -d / 2 - 0.15)
	elseif face == "back" then cf = at(x, y, d / 2 + 0.15) * CFrame.Angles(0, math.pi, 0)
	elseif face == "left" then cf = at(-w / 2 - 0.15, y, x) * CFrame.Angles(0, math.pi / 2, 0)
	else cf = at(w / 2 + 0.15, y, x) * CFrame.Angles(0, -math.pi / 2, 0) end
	box(list, Vector3.new(ww + fw * 2, wh + fw * 2, 0.4), cf, WHITE)
	box(list, Vector3.new(ww, wh, 0.3), cf * at(0, 0, -0.12), glass or GLASS, Mat.Glass, { t = 0.15 })
	-- the sill
	box(list, Vector3.new(ww + fw * 2 + 0.6, 0.35, 0.9), cf * at(0, -wh / 2 - fw - 0.1, -0.3), WHITE)
end

-- the windows of one floor: n across the front (and back), m along each side
local function windows(list, def, y, fh)
	local w, d = def.w, def.d
	local wh = fh * 0.5
	local nf = math.max(1, math.floor(w / 8))
	local ns = math.max(1, math.floor(d / 9))
	local ww = math.min(4.2, (w / nf) * 0.55)
	local ws = math.min(4.2, (d / ns) * 0.55)
	for i = 1, nf do
		local x = -w / 2 + (i - 0.5) * (w / nf)
		window(list, w, d, "front", x, y, ww, wh, def.glass)
		if def.back ~= false then window(list, w, d, "back", x, y, ww, wh, def.glass) end
	end
	for i = 1, ns do
		local z = -d / 2 + (i - 0.5) * (d / ns)
		window(list, w, d, "left", z, y, ws, wh, def.glass)
		window(list, w, d, "right", z, y, ws, wh, def.glass)
	end
end

-- a striped awning over the front (alternating colours), sloping out
local function awning(list, def, y, width)
	local cols = def.awning or { C3(236, 72, 72), WHITE }
	local n = math.max(3, math.floor(width / 2.4))
	local sw = width / n
	for i = 1, n do
		local x = -width / 2 + (i - 0.5) * sw
		box(list, Vector3.new(sw, 0.3, 4.2), at(x, y, -def.d / 2 - 2) * CFrame.Angles(math.rad(-22), 0, 0), cols[(i % 2) + 1])
	end
	-- the scalloped front edge
	for i = 1, n do
		local x = -width / 2 + (i - 0.5) * sw
		box(list, Vector3.new(sw, 0.9, 0.25), at(x, y - 1.25, -def.d / 2 - 3.95), cols[(i % 2) + 1])
	end
end

-- a sign board with text (drawn by a SurfaceGui made from the spec's text)
local function sign(list, text, cf, s, bg, tcol)
	box(list, s, cf, bg or C3(32, 42, 96), Mat.SmoothPlastic, { text = text, tcol = tcol or WHITE })
	box(list, s + Vector3.new(0.6, 0.6, -0.2), cf * at(0, 0, 0.25), WHITE)
end

-- the walls of a floor (a solid box) with a trim band on top
local function shell(list, def, y0, fh, col)
	box(list, Vector3.new(def.w, fh, def.d), at(0, y0 + fh / 2, 0), col or def.wall)
	box(list, Vector3.new(def.w + 0.8, 0.7, def.d + 0.8), at(0, y0 + fh - 0.35, 0), def.trim or WHITE)
end

-- a glass curtain wall floor: glass walls with white mullions
local function curtain(list, def, y0, fh)
	local w, d = def.w, def.d
	box(list, Vector3.new(w - 0.6, fh, d - 0.6), at(0, y0 + fh / 2, 0), def.glass or GLASS_DARK, Mat.Glass, { t = 0.05 })
	box(list, Vector3.new(w + 0.6, 0.8, d + 0.6), at(0, y0 + fh - 0.4, 0), def.trim or WHITE)
	local nf = math.max(2, math.floor(w / 6))
	for i = 0, nf do
		local x = -w / 2 + i * (w / nf)
		box(list, Vector3.new(0.5, fh, 0.5), at(x, y0 + fh / 2, -d / 2), def.trim or WHITE)
		box(list, Vector3.new(0.5, fh, 0.5), at(x, y0 + fh / 2, d / 2), def.trim or WHITE)
	end
	local ns = math.max(2, math.floor(d / 6))
	for i = 1, ns - 1 do
		local z = -d / 2 + i * (d / ns)
		box(list, Vector3.new(0.5, fh, 0.5), at(-w / 2, y0 + fh / 2, z), def.trim or WHITE)
		box(list, Vector3.new(0.5, fh, 0.5), at(w / 2, y0 + fh / 2, z), def.trim or WHITE)
	end
end

-- rooftop life
local function roofProps(list, def, y)
	local w, d = def.w, def.d
	-- parapet
	box(list, Vector3.new(w + 0.8, 1.4, 0.8), at(0, y + 0.7, -d / 2), def.trim or WHITE)
	box(list, Vector3.new(w + 0.8, 1.4, 0.8), at(0, y + 0.7, d / 2), def.trim or WHITE)
	box(list, Vector3.new(0.8, 1.4, d), at(-w / 2, y + 0.7, 0), def.trim or WHITE)
	box(list, Vector3.new(0.8, 1.4, d), at(w / 2, y + 0.7, 0), def.trim or WHITE)
	local roof = def.roof or "ac"
	if roof == "helipad" then
		cyl(list, math.min(w, d) * 0.4, 0.6, at(0, y + 0.5, 0), C3(60, 66, 80))
		cyl(list, math.min(w, d) * 0.4 - 0.8, 0.62, at(0, y + 0.52, 0), C3(84, 92, 108))
		-- the H
		local hs = math.min(w, d) * 0.22
		box(list, Vector3.new(0.9, 0.1, hs * 1.4), at(-hs * 0.4, y + 0.86, 0), C3(255, 214, 60))
		box(list, Vector3.new(0.9, 0.1, hs * 1.4), at(hs * 0.4, y + 0.86, 0), C3(255, 214, 60))
		box(list, Vector3.new(hs * 0.8, 0.1, 0.9), at(0, y + 0.86, 0), C3(255, 214, 60))
		-- lights on the rim
		for i = 0, 7 do
			local a = i / 8 * math.pi * 2
			local r = math.min(w, d) * 0.4 - 0.5
			ball(list, 0.35, at(math.cos(a) * r, y + 1, math.sin(a) * r), C3(120, 255, 140), Mat.Neon)
		end
	elseif roof == "crown" then
		box(list, Vector3.new(w * 0.7, 4, d * 0.7), at(0, y + 2, 0), def.trim or WHITE)
		box(list, Vector3.new(w * 0.45, 4, d * 0.45), at(0, y + 6, 0), def.glass or GLASS_DARK, Mat.Glass)
		cyl(list, 0.4, 14, at(0, y + 14, 0), METAL)
		ball(list, 0.8, at(0, y + 21, 0), C3(255, 70, 70), Mat.Neon)
	elseif roof == "tank" then
		cyl(list, 2.6, 4.5, at(w * 0.2, y + 5.4, d * 0.15), C3(150, 104, 68), Mat.WoodPlanks)
		wedge(list, Vector3.new(5.4, 1.4, 2.7), at(w * 0.2, y + 8.3, d * 0.15 - 1.35), C3(70, 76, 90))
		wedge(list, Vector3.new(5.4, 1.4, 2.7), at(w * 0.2, y + 8.3, d * 0.15 + 1.35) * CFrame.Angles(0, math.pi, 0), C3(70, 76, 90))
		for _, sx in ipairs({ -1.8, 1.8 }) do for _, sz in ipairs({ -1.8, 1.8 }) do
			box(list, Vector3.new(0.4, 3.2, 0.4), at(w * 0.2 + sx, y + 1.6, d * 0.15 + sz), METAL)
		end end
		box(list, Vector3.new(3, 1.6, 2.4), at(-w * 0.22, y + 0.8, -d * 0.1), C3(200, 204, 212))
	else
		-- AC units and a vent
		box(list, Vector3.new(3, 1.6, 2.4), at(-w * 0.2, y + 0.8, d * 0.12), C3(200, 204, 212))
		box(list, Vector3.new(2.2, 0.3, 2.2), at(-w * 0.2, y + 1.7, d * 0.12), METAL)
		box(list, Vector3.new(3, 1.6, 2.4), at(w * 0.18, y + 0.8, -d * 0.1), C3(200, 204, 212))
		cyl(list, 0.6, 2.4, at(w * 0.3, y + 1.2, d * 0.25), METAL)
	end
	if def.antenna then
		cyl(list, 0.18, 8, at(-w * 0.3, y + 4, -d * 0.3), METAL)
		ball(list, 0.35, at(-w * 0.3, y + 8.2, -d * 0.3), C3(255, 80, 80), Mat.Neon)
	end
end

-- the ground floor kinds -------------------------------------------------------------------------------------
local function groundShop(list, def, y0, fh)
	local w, d = def.w, def.d
	shell(list, def, y0, fh, def.ground or def.wall)
	-- a big shop window across the front with a door in the middle
	local gw = w - 4
	box(list, Vector3.new(gw + 1, fh * 0.62 + 1, 0.4), at(0, y0 + fh * 0.36, -d / 2 - 0.15), WHITE)
	box(list, Vector3.new(gw, fh * 0.62, 0.3), at(0, y0 + fh * 0.36, -d / 2 - 0.3), GLASS, Mat.Glass, { t = 0.2 })
	box(list, Vector3.new(4, fh * 0.66, 0.5), at(0, y0 + fh * 0.33, -d / 2 - 0.4), def.door or C3(52, 70, 120))
	box(list, Vector3.new(0.3, 0.9, 0.3), at(1.2, y0 + fh * 0.33, -d / 2 - 0.75), C3(255, 214, 60), Mat.Metal)
	if def.awning ~= false then awning(list, def, y0 + fh * 0.76, gw) end
	-- the sign over the awning
	if def.sign then sign(list, def.sign, at(0, y0 + fh * 0.93, -d / 2 - 0.7), Vector3.new(math.min(w - 2, 3 + #def.sign * 1.6), 2.6, 0.5), def.signBg, def.signText) end
	-- flower boxes
	for _, sx in ipairs({ -1, 1 }) do
		box(list, Vector3.new(3, 1, 1.4), at(sx * (w / 2 - 2), y0 + 0.5, -d / 2 - 1.1), C3(150, 104, 68), Mat.WoodPlanks)
		for i = -1, 1 do ball(list, 0.55, at(sx * (w / 2 - 2) + i * 0.9, y0 + 1.2, -d / 2 - 1.1), ({ C3(255, 90, 130), C3(255, 210, 70), C3(170, 110, 255) })[i + 2]) end
	end
end
local function groundLobby(list, def, y0, fh)
	local w, d = def.w, def.d
	shell(list, def, y0, fh, def.ground or def.wall)
	box(list, Vector3.new(w * 0.5 + 1, fh * 0.7 + 1, 0.4), at(0, y0 + fh * 0.4, -d / 2 - 0.15), WHITE)
	box(list, Vector3.new(w * 0.5, fh * 0.7, 0.3), at(0, y0 + fh * 0.4, -d / 2 - 0.3), GLASS, Mat.Glass, { t = 0.2 })
	-- a canopy over the entrance on two posts
	box(list, Vector3.new(w * 0.55, 0.6, 6), at(0, y0 + fh * 0.82, -d / 2 - 3), def.trim or WHITE)
	for _, sx in ipairs({ -1, 1 }) do cyl(list, 0.3, fh * 0.82, at(sx * w * 0.26, y0 + fh * 0.41, -d / 2 - 5.6), def.accent or C3(255, 196, 60), Mat.Metal) end
	if def.sign then sign(list, def.sign, at(0, y0 + fh * 0.82 + 1.8, -d / 2 - 0.7), Vector3.new(math.min(w - 2, 3 + #def.sign * 1.7), 2.8, 0.5), def.signBg, def.signText) end
end
local function groundHouse(list, def, y0, fh)
	local w, d = def.w, def.d
	shell(list, def, y0, fh)
	windows(list, { w = w, d = d, glass = def.glass, back = def.back }, y0 + fh * 0.55, fh)
	-- the front door with steps
	box(list, Vector3.new(4.6, fh * 0.72 + 0.8, 0.4), at(0, y0 + fh * 0.36, -d / 2 - 0.2), WHITE)
	box(list, Vector3.new(3.6, fh * 0.72, 0.5), at(0, y0 + fh * 0.36, -d / 2 - 0.35), def.door or C3(40, 110, 80))
	box(list, Vector3.new(6, 0.6, 2.4), at(0, y0 - 0.1, -d / 2 - 1.4), CONCRETE)
end
local function groundColumns(list, def, y0, fh)
	local w, d = def.w, def.d
	shell(list, def, y0, fh)
	-- a portico: steps, columns, a pediment over them
	box(list, Vector3.new(w - 2, 0.8, 5), at(0, y0 - 0.1, -d / 2 - 2.5), CONCRETE)
	box(list, Vector3.new(w - 4, 0.8, 3.6), at(0, y0 + 0.5, -d / 2 - 1.8), CONCRETE)
	local n = 5
	for i = 1, n do
		local x = -(w - 6) / 2 + (i - 1) * ((w - 6) / (n - 1))
		cyl(list, 0.9, fh * 1.8, at(x, y0 + fh * 0.9 + 0.8, -d / 2 - 3), WHITE)
	end
	box(list, Vector3.new(4, fh * 0.72, 0.5), at(0, y0 + fh * 0.36 + 0.8, -d / 2 - 0.35), C3(120, 80, 40), Mat.Wood)
end

-- the catalogue ----------------------------------------------------------------------------------------------
-- w x d footprint, n floors of fh, the ground floor kind, the upper floors kind (windows | curtain), colours, sign, roof
B.Defs = {
	lemonade = { w = 12, d = 9, n = 1, fh = 7, kind = "kiosk", wall = C3(255, 228, 90), awning = { C3(255, 214, 60), WHITE }, sign = "LEMONADE", signBg = C3(255, 120, 40) },
	coffee = { w = 20, d = 16, n = 1, fh = 11, kind = "shop", wall = C3(170, 112, 78), ground = C3(170, 112, 78), awning = { C3(36, 140, 90), WHITE }, sign = "COFFEE", signBg = C3(40, 80, 60), roof = "ac" },
	diner = { w = 28, d = 18, n = 1, fh = 11, kind = "shop", wall = C3(240, 80, 90), ground = C3(240, 80, 90), awning = { C3(255, 255, 255), C3(60, 170, 230) }, sign = "BURGERS", signBg = C3(32, 42, 96), signText = C3(255, 214, 60), roof = "ac" },
	townhouse = { w = 20, d = 18, n = 3, fh = 9, kind = "house", wall = C3(196, 104, 80), trim = WHITE, door = C3(40, 110, 80), roof = "tank" },
	apartment = { w = 26, d = 22, n = 5, fh = 9, kind = "house", wall = C3(120, 170, 220), trim = WHITE, door = C3(36, 52, 110), roof = "ac", antenna = true, balconies = true },
	bakery = { w = 24, d = 20, n = 2, fh = 10, kind = "shop", wall = C3(255, 196, 200), ground = C3(255, 236, 214), awning = { C3(240, 110, 160), WHITE }, sign = "BAKERY", signBg = C3(150, 70, 110), roof = "tank" },
	office = { w = 28, d = 24, n = 7, fh = 9, kind = "lobby", upper = "curtain", wall = C3(220, 224, 232), glass = C3(90, 150, 210), sign = "OFFICES", roof = "ac", antenna = true },
	bank = { w = 30, d = 24, n = 3, fh = 10, kind = "columns", wall = C3(238, 230, 210), trim = C3(255, 252, 240), sign = "BANK", signBg = C3(40, 60, 120), signText = C3(255, 214, 60), roof = "ac" },
	hotel = { w = 30, d = 26, n = 10, fh = 9, kind = "lobby", wall = C3(150, 90, 200), trim = WHITE, sign = "HOTEL", signBg = C3(60, 30, 100), signText = C3(255, 214, 60), roof = "tank", accent = C3(255, 196, 60) },
	cinema = { w = 32, d = 26, n = 2, fh = 13, kind = "shop", wall = C3(60, 60, 90), ground = C3(200, 50, 60), awning = { C3(255, 214, 60), C3(255, 140, 40) }, sign = "CINEMA", signBg = C3(20, 20, 40), signText = C3(255, 90, 90), roof = "ac" },
	tower = { w = 30, d = 28, n = 14, fh = 9, kind = "lobby", upper = "curtain", wall = C3(230, 234, 240), glass = C3(60, 120, 190), sign = "TOWER", roof = "helipad" },
	sky = { w = 34, d = 30, n = 18, fh = 9, kind = "lobby", upper = "curtain", wall = C3(40, 46, 70), glass = C3(40, 90, 160), trim = C3(255, 214, 60), sign = "SKY", signBg = C3(20, 24, 40), signText = C3(255, 214, 60), roof = "crown" },
}

-- balconies on a house floor
local function balconies(list, def, y0)
	local w, d = def.w, def.d
	local n = math.max(1, math.floor(w / 9))
	for i = 1, n do
		local x = -w / 2 + (i - 0.5) * (w / n)
		box(list, Vector3.new(5, 0.4, 2.4), at(x, y0 + 0.2, -d / 2 - 1.2), WHITE)
		box(list, Vector3.new(5, 1.4, 0.25), at(x, y0 + 1.1, -d / 2 - 2.3), WHITE, Mat.SmoothPlastic, { t = 0 })
	end
end

function B.make(key)
	local def = B.Defs[key]
	if not def then return nil end
	local floors = {}
	-- the foundation
	floors[0] = {}
	box(floors[0], Vector3.new(def.w + 2, 1, def.d + 2), at(0, 0.5, 0), CONCRETE)
	local y = 1
	if def.kind == "kiosk" then
		-- a little stand: a counter, posts, a striped roof, a big sign
		local f = {}
		box(f, Vector3.new(def.w, 3.4, def.d * 0.7), at(0, y + 1.7, 0), def.wall)
		box(f, Vector3.new(def.w + 0.6, 0.5, def.d * 0.7 + 0.6), at(0, y + 3.6, 0), WHITE)
		for _, sx in ipairs({ -1, 1 }) do for _, sz in ipairs({ -1, 1 }) do
			box(f, Vector3.new(0.5, def.fh, 0.5), at(sx * (def.w / 2 - 0.3), y + def.fh / 2, sz * (def.d / 2 - 0.3)), WHITE)
		end end
		-- lemons and a jug on the counter
		for i = -2, 2 do ball(f, 0.5, at(i * 1.2, y + 4.3, -def.d * 0.2), C3(255, 236, 60)) end
		cyl(f, 0.9, 1.8, at(3.6, y + 4.8, 0), C3(255, 250, 200), Mat.Glass)
		floors[1] = f
		local r = {}
		local n = 6
		for i = 1, n do
			local x = -def.w / 2 + (i - 0.5) * (def.w / n)
			box(r, Vector3.new(def.w / n, 0.4, def.d + 1.5), at(x, y + def.fh + 0.6, 0) * CFrame.Angles(math.rad(8), 0, 0), def.awning[(i % 2) + 1])
		end
		sign(r, def.sign, at(0, y + def.fh + 2.6, -def.d / 2 - 0.4), Vector3.new(def.w - 1, 2.6, 0.5), def.signBg)
		floors[2] = r
		return { floors = floors, n = 1, height = y + def.fh + 4, w = def.w, d = def.d }
	end
	for i = 1, def.n do
		local f = {}
		local y0 = y + (i - 1) * def.fh
		if i == 1 then
			if def.kind == "shop" then groundShop(f, def, y0, def.fh)
			elseif def.kind == "lobby" then groundLobby(f, def, y0, def.fh)
			elseif def.kind == "columns" then groundColumns(f, def, y0, def.fh)
			else groundHouse(f, def, y0, def.fh) end
		elseif def.upper == "curtain" then
			curtain(f, def, y0, def.fh)
		else
			shell(f, def, y0, def.fh)
			windows(f, def, y0 + def.fh * 0.55, def.fh)
			if def.balconies then balconies(f, def, y0) end
		end
		floors[i] = f
	end
	local top = y + def.n * def.fh
	local r = {}
	box(r, Vector3.new(def.w, 0.6, def.d), at(0, top + 0.3, 0), C3(90, 96, 110))
	roofProps(r, def, top + 0.6)
	-- the name up high on the tall ones
	if def.n >= 7 and def.sign then sign(r, def.sign, at(0, top + 3.4, -def.d / 2 - 0.6), Vector3.new(math.min(def.w - 2, 3 + #def.sign * 2.2), 3.6, 0.5), def.signBg, def.signText) end
	floors[def.n + 1] = r
	return { floors = floors, n = def.n, height = top + (def.roof == "crown" and 22 or 4), w = def.w, d = def.d }
end

return B
