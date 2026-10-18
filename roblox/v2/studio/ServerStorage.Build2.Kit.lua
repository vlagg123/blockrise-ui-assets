-- BlockRise 2.0 - the building kit: every level (1..10) in 2 styles, built from parts around the origin
-- (ground at Y = 0, the front facing -Z, the street side). Every part carries the attribute F = the floor it belongs
-- to (0 = the foundation, 1..n the floors, n + 1 the roof), so a construction can reveal it floor by floor.
-- Kit.make(level, style) -> Model (PrimaryPart "Base", attributes Level, Style, Floors, Height)
local Kit = {}
local C3 = Color3.fromRGB
local Mat = Enum.Material

Kit.Col = {
	brick = C3(166, 84, 64), brickTan = C3(198, 146, 104), cream = C3(242, 232, 212), trim = C3(246, 246, 240),
	clay = C3(182, 82, 60), slate = C3(78, 86, 98), awnRed = C3(226, 62, 62), awnWhite = C3(250, 248, 242),
	awnGreen = C3(36, 150, 96), pastelBlue = C3(150, 198, 232), pastelPink = C3(246, 184, 196), wood = C3(150, 104, 68),
	doorGreen = C3(36, 86, 64), doorNavy = C3(38, 52, 92), glass = C3(118, 160, 196), glassDark = C3(52, 74, 98),
	concrete = C3(196, 192, 184), metal = C3(70, 76, 88), gold = C3(255, 196, 60), steel = C3(150, 158, 170),
	grass = C3(98, 168, 74), flower1 = C3(250, 90, 120), flower2 = C3(255, 210, 70), leaf = C3(80, 156, 68),
	sign = C3(28, 36, 64), white = C3(250, 250, 248), sidingBlue = C3(120, 160, 200), sidingSage = C3(156, 180, 146),
}
local K = Kit.Col

-- part helpers (f = floor) --------------------------------------------------------------------------------
local function tag(p, f) p:SetAttribute("F", f) return p end
-- STYLE: clean toy-town surfaces (brick, wood, roof tiles, fabric, glass, metal and neon keep their texture)
local SMOOTH = { [Mat.Concrete] = true, [Mat.Plaster] = true, [Mat.Pavement] = true, [Mat.Limestone] = true, [Mat.Marble] = true, [Mat.Ground] = true }
local function base(p, color, mat, props)
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Color = color
	mat = mat or Mat.SmoothPlastic
	p.Material = SMOOTH[mat] and Mat.SmoothPlastic or mat
	if props then for k, v in pairs(props) do p[k] = v end end
	return p
end
local function box(m, f, size, cf, color, mat, props)
	local p = base(Instance.new("Part"), color, mat, props)
	p.Size = size
	p.CFrame = cf
	p.Parent = m
	return tag(p, f)
end
local function wedge(m, f, size, cf, color, mat, props)
	local p = base(Instance.new("WedgePart"), color, mat, props)
	p.Size = size
	p.CFrame = cf
	p.Parent = m
	return tag(p, f)
end
local function cyl(m, f, r, h, cf, color, mat, props)
	local p = box(m, f, Vector3.new(h, r * 2, r * 2), cf * CFrame.Angles(0, 0, math.pi / 2), color, mat, props)
	p.Shape = Enum.PartType.Cylinder
	return p
end
local function ball(m, f, r, cf, color, mat, props)
	local p = box(m, f, Vector3.one * r * 2, cf, color, mat, props)
	p.Shape = Enum.PartType.Ball
	return p
end
local at = CFrame.new

-- a window on a wall: frame + glass (+ sill). cf = the window centre on the wall surface, looking out (-Z)
local function window(m, f, cf, w, h, frame, glass, sill)
	box(m, f, Vector3.new(w + 0.9, h + 0.9, 0.35), cf * at(0, 0, -0.12), frame, Mat.SmoothPlastic, { CanCollide = false })
	box(m, f, Vector3.new(w, h, 0.3), cf * at(0, 0, -0.22), glass or K.glass, Mat.Glass, { Reflectance = 0.18, CanCollide = false, Name = "Window" })
	if sill then box(m, f, Vector3.new(w + 1.4, 0.4, 0.9), cf * at(0, -h / 2 - 0.55, -0.4), frame, Mat.SmoothPlastic, { CanCollide = false }) end
end
-- a door: frame + panel
local function door(m, f, cf, w, h, color, frame)
	box(m, f, Vector3.new(w + 1, h + 0.6, 0.35), cf * at(0, h / 2 + 0.3, -0.12), frame or K.trim, Mat.SmoothPlastic, { CanCollide = false })
	box(m, f, Vector3.new(w, h, 0.3), cf * at(0, h / 2, -0.22), color, Mat.SmoothPlastic, { CanCollide = false, Name = "Door" })
	box(m, f, Vector3.new(0.3, 0.3, 0.3), cf * at(w * 0.32, h * 0.5, -0.45), K.gold, Mat.Metal, { CanCollide = false })
end
-- a striped awning sloping out over the front: n stripes of two colours
local function awning(m, f, cf, w, depth, drop, c1, c2, n)
	n = n or 6
	local sw = w / n
	for i = 0, n - 1 do
		local x = -w / 2 + sw * (i + 0.5)
		-- the wedge's slope faces front (-Z): full height at the wall
		wedge(m, f, Vector3.new(sw, drop, depth), cf * at(x, -drop / 2, -depth / 2), i % 2 == 0 and c1 or c2, Mat.Fabric, { CanCollide = false })
		box(m, f, Vector3.new(sw, 0.9, 0.25), cf * at(x, -drop - 0.45, -depth - 0.1), i % 2 == 0 and c1 or c2, Mat.Fabric, { CanCollide = false })
	end
end
-- a sign board with text on its front (SurfaceGui)
local function sign(m, f, cf, size, text, bg, fg, font)
	local p = box(m, f, size, cf, bg or K.sign, Mat.SmoothPlastic, { CanCollide = false, Name = "Sign" })
	local sg = Instance.new("SurfaceGui")
	sg.Face = Enum.NormalId.Front
	sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	sg.PixelsPerStud = 30
	sg.LightInfluence = 0.2
	sg.Parent = p
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Size = UDim2.fromScale(1, 1)
	t.Font = font or Enum.Font.FredokaOne
	t.TextScaled = true
	t.Text = text
	t.TextColor3 = fg or K.gold
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0.12, 0) pad.PaddingBottom = UDim.new(0.12, 0) pad.PaddingLeft = UDim.new(0.05, 0) pad.PaddingRight = UDim.new(0.05, 0)
	pad.Parent = t
	t.Parent = sg
	return p
end
local function bush(m, f, cf, r, color)
	ball(m, f, r, cf * at(0, r * 0.6, 0), color or K.leaf, Mat.Grass, { CanCollide = false })
end
local function flowers(m, f, cf, w)
	box(m, f, Vector3.new(w, 0.8, 2), cf * at(0, 0.4, 0), K.wood, Mat.Wood)
	for i = 0, math.floor(w / 1.6) - 1 do
		ball(m, f, 0.6, cf * at(-w / 2 + 0.8 + i * 1.6, 1.1, 0), i % 2 == 0 and K.flower1 or K.flower2, Mat.SmoothPlastic, { CanCollide = false })
	end
end
local function tree(m, f, cf, s)
	cyl(m, f, 0.5 * s, 6 * s, cf * at(0, 3 * s, 0), K.wood, Mat.Wood)
	ball(m, f, 3 * s, cf * at(0, 7 * s, 0), K.leaf, Mat.Grass, { CanCollide = false })
	ball(m, f, 2.2 * s, cf * at(1.6 * s, 6 * s, 0.8 * s), K.leaf:Lerp(Color3.new(0, 0.3, 0), 0.15), Mat.Grass, { CanCollide = false })
end
-- the lot's pad (always shown: the lot looks claimed)
local function pad(m, w, d, color)
	local p = box(m, 0, Vector3.new(w, 0.6, d), at(0, 0.3, 0), color or K.concrete, Mat.Concrete, { Name = "Base" })
	m.PrimaryPart = p
	return p
end
-- a gable roof over a w x d box whose top is at y: two wedges (ridge along X), with gable fill
local function gable(m, f, y, w, d, rise, color, mat)
	local half = d / 2
	-- (a wedge is high at its +Z side: the front half as is, the back half turned around; both high at the ridge)
	wedge(m, f, Vector3.new(w + 1.2, rise, half + 0.7), at(0, y + rise / 2, -half / 2 - 0.35), color, mat or Mat.ClayRoofTiles)
	wedge(m, f, Vector3.new(w + 1.2, rise, half + 0.7), at(0, y + rise / 2, half / 2 + 0.35) * CFrame.Angles(0, math.pi, 0), color, mat or Mat.ClayRoofTiles)
end

local B = {}

-- L1 FOOD STAND -------------------------------------------------------------------------------------------
B[1] = function(m, style)
	pad(m, 16, 16, K.concrete)
	local a, b = K.awnRed, K.awnWhite
	local body = K.white
	local title = "HOT DOGS"
	if style == 2 then a, b, body, title = K.pastelPink, K.awnWhite, K.pastelBlue, "ICE CREAM" end
	-- kiosk
	box(m, 1, Vector3.new(9, 3.4, 6), at(0, 2.3, 1), body, Mat.SmoothPlastic)
	box(m, 1, Vector3.new(9.4, 0.4, 6.8), at(0, 4.2, 0.8), K.trim, Mat.SmoothPlastic)
	box(m, 1, Vector3.new(9, 3.4, 0.4), at(0, 6.1, 3.8), body, Mat.SmoothPlastic)
	for s = -1, 1, 2 do box(m, 1, Vector3.new(0.6, 3.6, 0.6), at(s * 4.2, 6.2, -1.8), K.trim, Mat.SmoothPlastic) end
	box(m, 1, Vector3.new(9.6, 0.6, 7.4), at(0, 8.1, 1), body, Mat.SmoothPlastic)
	awning(m, 2, at(0, 8.1, -2.2), 9.6, 3, 1.6, a, b, 6)
	sign(m, 2, at(0, 9.6, 0.5), Vector3.new(8.4, 2.2, 0.6), title, K.sign, K.gold)
	-- counter + stools
	box(m, 1, Vector3.new(9, 0.4, 1.4), at(0, 4.3, -2.2), K.wood, Mat.Wood)
	for i = -1, 1 do
		cyl(m, 1, 0.2, 2.6, at(i * 2.6, 1.9, -4), K.metal, Mat.Metal)
		cyl(m, 1, 0.8, 0.4, at(i * 2.6, 3.3, -4), a, Mat.SmoothPlastic)
	end
	-- a parasol table
	cyl(m, 2, 1.6, 0.3, at(5.4, 2.9, -5.2), K.white, Mat.SmoothPlastic)
	cyl(m, 2, 0.15, 6, at(5.4, 3.6, -5.2), K.metal, Mat.Metal)
	cyl(m, 2, 3, 0.4, at(5.4, 6.6, -5.2), a, Mat.Fabric)
	cyl(m, 2, 0.6, 0.6, at(5.4, 7.0, -5.2), b, Mat.Fabric)
	flowers(m, 2, at(-5, 0.6, -6.6), 4.8)
end

-- L2 SMALL HOUSE ------------------------------------------------------------------------------------------
B[2] = function(m, style)
	pad(m, 26, 26, K.grass)
	local wall, roof, doorC = K.cream, K.clay, K.doorGreen
	local roofMat = Mat.ClayRoofTiles
	if style == 2 then wall, roof, doorC, roofMat = K.sidingBlue, K.slate, K.doorNavy, Mat.Slate end
	-- path + fence
	box(m, 0, Vector3.new(3.4, 0.2, 9), at(0, 0.7, -8.5), K.concrete, Mat.Pavement)
	for s = -1, 1, 2 do
		box(m, 1, Vector3.new(9.4, 0.4, 0.4), at(s * 7.9, 2.4, -12.6), K.white, Mat.SmoothPlastic)
		box(m, 1, Vector3.new(9.4, 0.4, 0.4), at(s * 7.9, 1.4, -12.6), K.white, Mat.SmoothPlastic)
		for i = 0, 4 do box(m, 1, Vector3.new(0.5, 2.8, 0.5), at(s * (3.6 + i * 2.1), 1.9, -12.6), K.white, Mat.SmoothPlastic) end
	end
	-- the house body: 18 x 10 x 12
	local W, H, D, z0 = 18, 10, 12, 1
	box(m, 1, Vector3.new(W, H, D), at(0, 0.6 + H / 2, z0), wall, style == 2 and Mat.WoodPlanks or Mat.Plaster)
	box(m, 1, Vector3.new(W + 0.6, 0.8, D + 0.6), at(0, 1.0, z0), K.concrete, Mat.Concrete)
	door(m, 1, at(0, 0.6, z0 - D / 2), 3.2, 6.6, doorC)
	for s = -1, 1, 2 do
		window(m, 1, at(s * 5.4, 5.6, z0 - D / 2), 3.6, 3.6, K.trim, K.glass, true)
		window(m, 1, at(s * 5.4, 5.6, z0 + D / 2) * CFrame.Angles(0, math.pi, 0), 3.6, 3.6, K.trim, K.glass, true)
	end
	-- porch roof
	box(m, 1, Vector3.new(6, 0.5, 3), at(0, 8.2, z0 - D / 2 - 1.5), K.trim, Mat.SmoothPlastic)
	for s = -1, 1, 2 do box(m, 1, Vector3.new(0.5, 7.6, 0.5), at(s * 2.7, 4.4, z0 - D / 2 - 2.7), K.trim, Mat.SmoothPlastic) end
	-- roof + chimney
	gable(m, 2, 0.6 + H, W, D, 6, roof, roofMat)
	box(m, 2, Vector3.new(2, 6, 2), at(5.5, 0.6 + H + 3.5, z0 + 2), K.brick, Mat.Brick)
	-- garden
	bush(m, 2, at(-7.5, 0.6, -8), 1.6)
	bush(m, 2, at(7.5, 0.6, -8), 1.6)
	tree(m, 2, at(9, 0.6, 9), 0.9)
	flowers(m, 2, at(-5, 0.6, -6.2), 4.6)
end

-- L3 CORNER SHOP ------------------------------------------------------------------------------------------
B[3] = function(m, style)
	pad(m, 26, 26, K.concrete)
	local wall, awnA, awnB, title, signBg = K.brick, K.awnGreen, K.awnWhite, "CORNER SHOP", K.sign
	if style == 2 then wall, awnA, awnB, title, signBg = K.brickTan, K.awnRed, K.awnWhite, "CAFE", K.doorGreen end
	local W, D, FH = 22, 18, 9
	-- ground floor: shop front
	box(m, 1, Vector3.new(W, FH, D), at(0, 0.6 + FH / 2, 2), wall, Mat.Brick)
	box(m, 1, Vector3.new(W - 4, 6, 0.4), at(0, 0.6 + 3.6, 2 - D / 2 - 0.15), K.glassDark, Mat.Glass, { Reflectance = 0.25, CanCollide = false })
	for i = -2, 2 do box(m, 1, Vector3.new(0.5, 6.4, 0.6), at(i * 4.5, 0.6 + 3.6, 2 - D / 2 - 0.3), K.sign, Mat.SmoothPlastic, { CanCollide = false }) end
	box(m, 1, Vector3.new(W - 3.4, 0.6, 0.8), at(0, 0.6 + 6.9, 2 - D / 2 - 0.3), K.sign, Mat.SmoothPlastic, { CanCollide = false })
	door(m, 1, at(0, 0.6, 2 - D / 2 - 0.2), 3.4, 6.4, K.sign, K.sign)
	awning(m, 2, at(0, 0.6 + FH - 0.2, 2 - D / 2), W - 2, 3.4, 1.8, awnA, awnB, 8)
	-- first floor
	box(m, 2, Vector3.new(W, FH, D), at(0, 0.6 + FH * 1.5, 2), wall, Mat.Brick)
	for i = -1, 1 do
		window(m, 2, at(i * 6.4, 0.6 + FH * 1.5 + 0.4, 2 - D / 2), 3.4, 4.4, K.trim, K.glass, true)
		window(m, 2, at(-W / 2, 0.6 + FH * 1.5 + 0.4, 2 + i * 5) * CFrame.Angles(0, -math.pi / 2, 0), 3.4, 4.4, K.trim, K.glass, true)
	end
	-- cornice + roof
	box(m, 3, Vector3.new(W + 1.2, 1, D + 1.2), at(0, 0.6 + FH * 2 + 0.5, 2), K.trim, Mat.SmoothPlastic)
	box(m, 3, Vector3.new(W - 1, 0.4, D - 1), at(0, 0.6 + FH * 2 + 1.2, 2), K.slate, Mat.Concrete)
	sign(m, 3, at(0, 0.6 + FH * 2 + 2.6, 2 - D / 2 + 1.2), Vector3.new(14, 3, 0.6), title, signBg, K.gold)
	box(m, 3, Vector3.new(2, 2, 2), at(6, 0.6 + FH * 2 + 2.2, 6), K.steel, Mat.Metal) -- a/c unit
	-- outside: tables (cafe) or crates (shop)
	for s = -1, 1, 2 do
		cyl(m, 2, 1.1, 0.3, at(s * 7.5, 2.9, -10.2), K.white, Mat.SmoothPlastic)
		cyl(m, 2, 0.15, 2.4, at(s * 7.5, 1.8, -10.2), K.metal, Mat.Metal)
	end
	flowers(m, 2, at(-8, 0.6, -8.6), 4)
	flowers(m, 2, at(8, 0.6, -8.6), 4)
end

-- L4 TOWNHOUSE --------------------------------------------------------------------------------------------
B[4] = function(m, style)
	pad(m, 30, 30, K.grass)
	local wall, trimC, roofC, doorC = K.brick, K.trim, K.slate, K.doorNavy
	local wallMat = Mat.Brick
	if style == 2 then wall, trimC, roofC, doorC, wallMat = K.white, K.wood, K.metal, K.wood, Mat.Plaster end
	local W, D, FH = 20, 18, 9
	local z0 = 3
	box(m, 0, Vector3.new(W + 1, 1.4, D + 1), at(0, 1.3, z0), K.concrete, Mat.Concrete)
	for fl = 1, 3 do
		local y = 2 + (fl - 1) * FH
		box(m, fl, Vector3.new(W, FH, D), at(0, y + FH / 2, z0), wall, wallMat)
		box(m, fl, Vector3.new(W + 0.6, 0.6, D + 0.6), at(0, y + FH - 0.3, z0), trimC, Mat.SmoothPlastic)
		if fl == 1 then
			door(m, fl, at(-5, y, z0 - D / 2), 3.4, 7, doorC, trimC)
			window(m, fl, at(4, y + 4.4, z0 - D / 2), 6, 4.6, trimC, K.glass, true)
		else
			-- the bay window: a box sticking out with glass on 3 sides
			box(m, fl, Vector3.new(8, FH - 2, 2.4), at(3.5, y + FH / 2, z0 - D / 2 - 1.2), trimC, Mat.SmoothPlastic)
			box(m, fl, Vector3.new(6.8, FH - 3.6, 0.3), at(3.5, y + FH / 2, z0 - D / 2 - 2.45), K.glass, Mat.Glass, { Reflectance = 0.2, CanCollide = false })
			window(m, fl, at(-5, y + 4.6, z0 - D / 2), 3.4, 4.4, trimC, K.glass, true)
		end
		for i = -1, 1, 2 do
			window(m, fl, at(W / 2, y + 4.6, z0 + i * 4.5) * CFrame.Angles(0, math.pi / 2, 0), 3, 4.2, trimC, K.glass, false)
			window(m, fl, at(-W / 2, y + 4.6, z0 + i * 4.5) * CFrame.Angles(0, -math.pi / 2, 0), 3, 4.2, trimC, K.glass, false)
		end
	end
	-- stoop: 3 steps + rails
	for i = 1, 3 do box(m, 1, Vector3.new(4.4, 0.6 * i, 1.2), at(-5, 0.6 + 0.3 * i, z0 - D / 2 - 0.6 - (3 - i) * 1.2), K.concrete, Mat.Concrete) end
	-- roof: parapet + a little roof garden / solar
	local top = 2 + 3 * FH
	box(m, 4, Vector3.new(W + 1, 1.6, D + 1), at(0, top + 0.8, z0), trimC, Mat.SmoothPlastic)
	box(m, 4, Vector3.new(W - 1, 0.5, D - 1), at(0, top + 1.0, z0), roofC, Mat.Concrete)
	if style == 1 then
		for i = -1, 1, 2 do box(m, 4, Vector3.new(6, 0.3, 4), at(i * 4.5, top + 2.2, z0 + 2) * CFrame.Angles(math.rad(-25), 0, 0), K.doorNavy, Mat.Glass, { Reflectance = 0.3 }) end
	else
		bush(m, 4, at(-5, top + 1.2, z0 + 3), 1.4)
		bush(m, 4, at(5, top + 1.2, z0 + 3), 1.4)
		box(m, 4, Vector3.new(8, 2.6, 0.4), at(0, top + 2.5, z0 - 4), K.wood, Mat.Wood)
	end
	box(m, 4, Vector3.new(2.4, 3, 2.4), at(-6, top + 2.5, z0 + 5), K.brick, Mat.Brick)
	-- front garden
	bush(m, 1, at(-10.5, 2, z0 - D / 2 - 2.5), 1.4)
	flowers(m, 1, at(5, 0.6, -10.5), 9)
	tree(m, 2, at(11.5, 0.6, -11), 0.9)
end

-- glass tower helpers ------------------------------------------------------------------------------------------
-- one floor of a glass tower: a white slab band and an inset glass band (2 parts), w x d, from y up FH studs
local function glassFloor(m, f, y, w, d, FH, slab, glass)
	box(m, f, Vector3.new(w + 0.8, 1.4, d + 0.8), at(0, y + 0.7, 0), slab, Mat.SmoothPlastic)
	box(m, f, Vector3.new(w, FH - 1.4, d), at(0, y + 1.4 + (FH - 1.4) / 2, 0), glass, Mat.Glass, { Reflectance = 0.3, Name = "Window" })
end
-- vertical fins on the 4 corners and the middle of each face, from y0 to y1 (one part each)
local function fins(m, f, y0, y1, w, d, color, mid)
	local h = y1 - y0
	for sx = -1, 1, 2 do
		for sz = -1, 1, 2 do box(m, f, Vector3.new(1.6, h, 1.6), at(sx * (w / 2 + 0.2), y0 + h / 2, sz * (d / 2 + 0.2)), color, Mat.SmoothPlastic) end
	end
	if mid then
		for s = -1, 1, 2 do
			box(m, f, Vector3.new(1, h, 1.2), at(0, y0 + h / 2, s * (d / 2 + 0.3)), mid, Mat.Metal)
			box(m, f, Vector3.new(1.2, h, 1), at(s * (w / 2 + 0.3), y0 + h / 2, 0), mid, Mat.Metal)
		end
	end
end
-- a helipad on a roof at height y (r = radius): dark disc, white ring and H, edge lights
function Kit.helipad(m, f, cf, r)
	cyl(m, f, r, 0.8, cf * at(0, 0.4, 0), K.metal, Mat.SmoothPlastic, { Name = "Helipad" })
	cyl(m, f, r - 1.2, 0.84, cf * at(0, 0.42, 0), K.white, Mat.SmoothPlastic)
	cyl(m, f, r - 2, 0.88, cf * at(0, 0.44, 0), C3(60, 66, 82), Mat.SmoothPlastic)
	box(m, f, Vector3.new(1.6, 0.1, 8), at(0, 0, 0) * cf * at(-2.6, 0.9, 0), K.gold, Mat.SmoothPlastic)
	box(m, f, Vector3.new(1.6, 0.1, 8), cf * at(2.6, 0.9, 0), K.gold, Mat.SmoothPlastic)
	box(m, f, Vector3.new(3.6, 0.1, 1.4), cf * at(0, 0.9, 0), K.gold, Mat.SmoothPlastic)
	for i = 0, 7 do
		local a = i * math.pi / 4
		box(m, f, Vector3.new(0.7, 0.5, 0.7), cf * at(math.cos(a) * (r - 0.6), 1.05, math.sin(a) * (r - 0.6)), C3(120, 255, 140), Mat.Neon, { Name = "PadLight" })
	end
end

-- L10 SKY TOWER: a 3-floor glass podium with an entrance canopy, a 26-floor glass shaft with fins and a setback,
-- a crown with a neon ring, a helipad and an antenna
B[10] = function(m, style)
	local glass, slab, accent, podium = K.glass, K.white, K.gold, K.white
	if style == 2 then glass, slab, accent, podium = C3(70, 96, 140), C3(214, 220, 232), C3(90, 210, 255), C3(40, 50, 76) end
	pad(m, 52, 52, K.concrete)
	local FH = 9
	-- podium: floors 1..3, 46 x 46
	for fl = 1, 3 do glassFloor(m, fl, 0.6 + (fl - 1) * FH, 44, 44, FH, podium, glass) end
	fins(m, 3, 0.6, 0.6 + 3 * FH, 44, 44, podium, nil)
	box(m, 3, Vector3.new(47, 1.6, 47), at(0, 0.6 + 3 * FH + 0.8, 0), slab, Mat.SmoothPlastic)
	-- entrance: canopy, gold doors, the name
	box(m, 1, Vector3.new(18, 1, 8), at(0, 9.4, -26), slab, Mat.SmoothPlastic)
	for s = -1, 1, 2 do box(m, 1, Vector3.new(0.8, 8.8, 0.8), at(s * 8.4, 5, -29.4), accent, Mat.Metal) end
	box(m, 1, Vector3.new(10, 7.4, 0.4), at(0, 4.3, -22.3), accent, Mat.Metal, { Name = "Door" })
	box(m, 1, Vector3.new(7, 6.6, 0.3), at(0, 4.1, -22.55), K.glassDark, Mat.Glass, { Reflectance = 0.3 })
	sign(m, 2, at(0, 12.4, -22.4), Vector3.new(20, 3, 0.6), "SKY TOWER", K.sign, accent)
	-- the shaft: floors 4..19 (36 x 36), setback floors 20..28 (30 x 30)
	local y = 0.6 + 3 * FH + 1.6
	for fl = 4, 19 do glassFloor(m, fl, y + (fl - 4) * FH, 36, 36, FH, slab, glass) end
	fins(m, 19, y, y + 16 * FH, 36, 36, slab, accent)
	local y2 = y + 16 * FH
	box(m, 20, Vector3.new(38, 1.6, 38), at(0, y2 + 0.8, 0), slab, Mat.SmoothPlastic)
	y2 += 1.6
	for fl = 20, 28 do glassFloor(m, fl, y2 + (fl - 20) * FH, 30, 30, FH, slab, glass) end
	fins(m, 28, y2, y2 + 9 * FH, 30, 30, slab, accent)
	local top = y2 + 9 * FH
	-- crown: a neon ring band, the roof deck with its helipad, a mechanical box and an antenna
	box(m, 29, Vector3.new(32, 2.4, 32), at(0, top + 1.2, 0), slab, Mat.SmoothPlastic)
	box(m, 29, Vector3.new(32.4, 0.8, 32.4), at(0, top + 2.6, 0), accent, Mat.Neon, { Name = "CrownGlow" })
	box(m, 29, Vector3.new(31, 3, 31), at(0, top + 4.5, 0), slab, Mat.SmoothPlastic)
	Kit.helipad(m, 30, at(0, top + 6, 0), 12)
	box(m, 30, Vector3.new(6, 4, 6), at(11.5, top + 8, 11.5), K.steel, Mat.Metal)
	cyl(m, 30, 0.6, 26, at(-12.5, top + 6 + 13, 12.5), K.steel, Mat.Metal, { Name = "Antenna" })
	ball(m, 30, 0.9, at(-12.5, top + 6 + 26.4, 12.5), C3(255, 60, 60), Mat.Neon, { Name = "Beacon" })
end

Kit.Builders = B
Kit.Floors = { 2, 2, 3, 4, 7, 10, 14, 19, 26, 33 }

function Kit.make(level, style)
	local fn = B[level]
	if not fn then return nil end
	local m = Instance.new("Model")
	m.Name = "B" .. level .. "_" .. (style or 1)
	fn(m, style or 1)
	local maxF = 0
	for _, p in ipairs(m:GetDescendants()) do if p:IsA("BasePart") then maxF = math.max(maxF, p:GetAttribute("F") or 0) end end
	local _, size = m:GetBoundingBox()
	m:SetAttribute("Level", level)
	m:SetAttribute("Style", style or 1)
	m:SetAttribute("Floors", maxF)
	m:SetAttribute("Height", size.Y)
	return m
end

return Kit
