-- one-off map change (run in Edit): the shops of the SHOP menu, each one a place in town
--  * the Equipment Store becomes the HAMMERS shop (crates)
--  * MACHINES DEPOT: a new depot on the plaza's east lawn (opposite the Company Registry), a Mini Excavator on show
--  * TRAINING SHOP: a new little shop at the Training Yard gate
-- Anything removed to make room (lawn, trees, benches, a lamp) goes to ServerStorage.Backup_pre_shops.
local Map = workspace.Map
local Plaza = Map.Plaza
-- (run again = rebuilt: the two new shops are made fresh)
for _, n in ipairs({ "MachinesDepot", "TrainingShop" }) do if Plaza:FindFirstChild(n) then Plaza[n]:Destroy() end end
local backup = game.ServerStorage:FindFirstChild("Backup_pre_shops") or Instance.new("Folder")
backup.Name = "Backup_pre_shops"
backup.Parent = game.ServerStorage
local report = {}

local function part(props)
	local p = Instance.new(props.Wedge and "WedgePart" or "Part")
	p.Anchored, p.TopSurface, p.BottomSurface = true, Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	for k, v in pairs(props) do if k ~= "Wedge" and k ~= "Parent" then p[k] = v end end
	p.Parent = props.Parent
	return p
end
local function signText(p, text, color, faces, font)
	for _, face in ipairs(faces or { Enum.NormalId.Front, Enum.NormalId.Back }) do
		local sg = Instance.new("SurfaceGui")
		sg.Face = face; sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud; sg.PixelsPerStud = 30; sg.LightInfluence = 0; sg.Parent = p
		local l = Instance.new("TextLabel")
		l.Name = "Label"; l.Size = UDim2.fromScale(1, 1); l.BackgroundTransparency = 1; l.Font = font or Enum.Font.FredokaOne; l.TextScaled = true
		l.Text = text; l.TextColor3 = color or Color3.new(1, 1, 1); l.Parent = sg
		local pad = Instance.new("UIPadding"); pad.PaddingTop = UDim.new(0.1, 0); pad.PaddingBottom = UDim.new(0.1, 0); pad.Parent = l
	end
end
local function prompt(parent, cf, name, object, action)
	local pp = part({ Name = "PromptPart", Size = Vector3.new(2, 2, 2), CFrame = cf, Transparency = 1, CanCollide = false, CanQuery = false, CanTouch = false, Parent = parent })
	local pr = Instance.new("ProximityPrompt")
	pr.Name = name; pr.ObjectText = object; pr.ActionText = action; pr.HoldDuration = 0; pr.MaxActivationDistance = 14
	pr.RequiresLineOfSight = false; pr.KeyboardKeyCode = Enum.KeyCode.E; pr.Parent = pp
	return pp
end
-- move whatever stands in a box out of the way (into the backup): the smallest whole object (a tree, a bench, a lawn
-- piece), never a folder and never the big ground pieces
local function clear(boxCF, size, roots)
	local params = OverlapParams.new()
	local seen, n = {}, 0
	for _, p in ipairs(workspace:GetPartBoundsInBox(boxCF, size, params)) do
		for _, root in ipairs(roots) do
			if p:IsDescendantOf(root) then
				local obj = p
				while obj.Parent and obj.Parent:IsA("Model") do obj = obj.Parent end
				local big
				if obj:IsA("BasePart") then big = obj.Size.X > 60 or obj.Size.Z > 60
				else local _, sz = obj:GetBoundingBox(); big = sz.X > 60 or sz.Z > 60 end
				if not big and not seen[obj] then
					seen[obj] = true
					obj.Parent = backup
					n += 1
				end
			end
		end
	end
	return n
end

---------------------------------------------------------------------------------------------------------------------
-- 1. the Equipment Store becomes the HAMMERS shop
---------------------------------------------------------------------------------------------------------------------
local es = Plaza.EquipmentStore
for _, d in ipairs(es:GetDescendants()) do
	if d:IsA("TextLabel") then
		if d.Text == "EQUIPMENT" then d.Text = "HAMMERS" elseif d.Text:find("EQUIPMENT") then d.Text = "🔨 HAMMERS & CRATES" end
	elseif d:IsA("ProximityPrompt") and d.Name == "ShopPrompt" then
		d.ObjectText = "HAMMERS SHOP"; d.ActionText = "Buy Crates"
	end
end
table.insert(report, "hammers shop signs")

---------------------------------------------------------------------------------------------------------------------
-- a shop building (local -Z = the front), the town's style: apron, brick walls, roof, parapet, awning, sign
---------------------------------------------------------------------------------------------------------------------
local function building(o)
	local mdl = Instance.new("Model")
	mdl.Name = o.name
	local cf = CFrame.lookAt(o.pos, o.pos + o.face)
	local w, d, h = o.w, o.d, o.h
	local function P(n, size, off, color, mat, extra)
		local props = { Name = n, Size = size, CFrame = cf * off, Color = color, Material = mat or Enum.Material.SmoothPlastic, Parent = mdl }
		for k, v in pairs(extra or {}) do props[k] = v end
		return part(props)
	end
	P("Apron", Vector3.new(w + 8, 0.5, d + 8), CFrame.new(0, 0.25, -1), Color3.fromRGB(200, 194, 184), Enum.Material.Concrete)
	P("Walls", Vector3.new(w, h, d), CFrame.new(0, 0.5 + h / 2, 0), o.wall, o.wallMat or Enum.Material.Brick)
	P("Roof", Vector3.new(w + 1.2, 0.8, d + 1.2), CFrame.new(0, 0.5 + h + 0.4, 0), Color3.fromRGB(70, 72, 80), Enum.Material.Concrete)
	P("Parapet", Vector3.new(w + 1.6, 1.2, 0.8), CFrame.new(0, 0.5 + h + 1.4, -d / 2 - 0.3), o.accent)
	-- a striped canopy over the shop front (flat, a little tilt), the sign over it
	if o.awning ~= false then
		local n = math.max(3, math.floor((w - 1) / 2.4))
		local aw = w - 1
		for k = 0, n - 1 do
			P("Awning", Vector3.new(aw / n + 0.02, 0.3, 3.2), CFrame.new(-aw / 2 + (k + 0.5) * aw / n, 0.5 + h * 0.66, -d / 2 - 1.55) * CFrame.Angles(math.rad(-10), 0, 0),
				(k % 2 == 0) and o.accent or Color3.fromRGB(250, 250, 250), Enum.Material.Fabric)
		end
	end
	local sign = P("Sign", Vector3.new(math.min(w - 2, 28), 3.6, 0.5), CFrame.new(0, 0.5 + h * 0.84, -d / 2 - 0.35), Color3.fromRGB(28, 32, 44))
	signText(sign, o.text, Color3.fromRGB(255, 214, 90))
	-- a board on the roof, seen from far away (like the other shops)
	local rs = P("RoofSign", Vector3.new(math.min(w, 24), 5, 0.8), CFrame.new(0, 0.5 + h + 4.6, -d / 2 + 2), o.accent)
	signText(rs, o.roof, Color3.new(1, 1, 1))
	for _, sx in ipairs({ -1, 1 }) do
		P("SignLeg", Vector3.new(0.4, 4, 0.4), CFrame.new(sx * (math.min(w, 24) / 2 - 1.5), 0.5 + h + 1.9, -d / 2 + 2), Color3.fromRGB(55, 57, 63), Enum.Material.Metal)
	end
	mdl.Parent = o.parent
	return mdl, cf, P
end

---------------------------------------------------------------------------------------------------------------------
-- 2. MACHINES DEPOT on the plaza's east lawn (opposite the Company Registry), front to the plaza (west)
---------------------------------------------------------------------------------------------------------------------
local gen = Map:FindFirstChild("Generated")
local roots = {}
for _, f in ipairs({ "Plaza", "Decor" }) do if gen and gen:FindFirstChild(f) then table.insert(roots, gen[f]) end end
table.insert(report, "east lawn cleared: " .. clear(CFrame.new(106, 6, 61), Vector3.new(50, 30, 52), roots))
do
	local YEL, BLK = Color3.fromRGB(246, 186, 32), Color3.fromRGB(34, 36, 42)
	local mdl, cf, P = building({ name = "MachinesDepot", parent = Plaza, pos = Vector3.new(113, 0, 61), face = Vector3.new(-1, 0, 0), w = 30, d = 20, h = 16,
		wall = Color3.fromRGB(120, 132, 150), wallMat = Enum.Material.Metal, accent = YEL, text = "MACHINES DEPOT", roof = "MACHINES", awning = false })
	local d, h = 20, 16
	-- the big garage door with hazard stripes around it, a small door and windows on the sides
	P("GarageDoor", Vector3.new(14, 10.5, 0.3), CFrame.new(0, 0.5 + 5.25, -d / 2 - 0.12), Color3.fromRGB(70, 76, 88), Enum.Material.DiamondPlate)
	for k = 0, 9 do
		P("DoorSlat", Vector3.new(14, 0.15, 0.4), CFrame.new(0, 0.5 + 0.6 + k * 1.05, -d / 2 - 0.2), Color3.fromRGB(52, 56, 66), Enum.Material.Metal)
	end
	for k = 0, 13 do -- the hazard frame: yellow / black blocks
		local col = (k % 2 == 0) and YEL or BLK
		P("Hazard", Vector3.new(1.2, 1.2, 0.5), CFrame.new(-7.6, 0.5 + 0.6 + k * 0.8, -d / 2 - 0.25), col)
		P("Hazard", Vector3.new(1.2, 1.2, 0.5), CFrame.new(7.6, 0.5 + 0.6 + k * 0.8, -d / 2 - 0.25), col)
	end
	for k = 0, 12 do
		P("Hazard", Vector3.new(1.25, 1.1, 0.5), CFrame.new(-7.5 + k * 1.25, 0.5 + 11.5, -d / 2 - 0.25), (k % 2 == 0) and YEL or BLK)
	end
	for _, sx in ipairs({ -1, 1 }) do
		P("Window", Vector3.new(4.2, 4.5, 0.3), CFrame.new(sx * 11.4, 0.5 + 6.2, -d / 2 - 0.12), Color3.fromRGB(150, 205, 235), Enum.Material.Glass, { Transparency = 0.15, Reflectance = 0.2 })
		P("WindowLight", Vector3.new(3.6, 0.3, 0.2), CFrame.new(sx * 11.4, 0.5 + 8.2, -d / 2 - 0.3), Color3.fromRGB(255, 236, 190), Enum.Material.Neon, { CanCollide = false })
	end
	-- floodlights over the windows
	for _, sx in ipairs({ -11.4, 11.4 }) do
		P("Floodlight", Vector3.new(1.2, 0.8, 1.6), CFrame.new(sx, 0.5 + 10.4, -d / 2 - 0.9), BLK, Enum.Material.Metal)
		local l = P("FloodlightLamp", Vector3.new(1, 0.2, 1.2), CFrame.new(sx, 0.5 + 9.95, -d / 2 - 0.9), Color3.fromRGB(255, 244, 210), Enum.Material.Neon, { CanCollide = false })
		local sl = Instance.new("SpotLight"); sl.Face = Enum.NormalId.Bottom; sl.Brightness = 1.2; sl.Range = 18; sl.Angle = 70; sl.Color = Color3.fromRGB(255, 240, 210); sl.Parent = l
	end
	-- traffic cones on the apron
	for _, off in ipairs({ { -13, -14.5 }, { -10, -15 }, { 10, -15 }, { 13, -14.5 } }) do
		P("Cone", Vector3.new(1.2, 1.8, 1.2), CFrame.new(off[1], 0.5 + 0.9, off[2]), Color3.fromRGB(255, 120, 30), Enum.Material.SmoothPlastic)
		P("ConeStripe", Vector3.new(1.25, 0.3, 1.25), CFrame.new(off[1], 0.5 + 1.1, off[2]), Color3.new(1, 1, 1), Enum.Material.SmoothPlastic)
	end
	prompt(mdl, cf * CFrame.new(0, 3.5, -d / 2 - 4), "MachinesPrompt", "MACHINES DEPOT", "Open Shop")
	-- a Mini Excavator on show (built by the same code as the real ones), on a low plinth in front-left
	local okM, Mach = pcall(function()
		local src = game.ServerScriptService.Game.Machines.Source
		src = src:gsub("folder%.Parent = workspace", "-- (no folder in Edit)")
		src = src:gsub("return Machines%s*$", "return { excavator = buildExcavator, mixer = buildMixer }")
		return assert(loadstring(src))()
	end)
	if okM and Mach then
		local plinth = P("Plinth", Vector3.new(11, 0.8, 9), CFrame.new(-11, 0.9, -21), Color3.fromRGB(60, 62, 70), Enum.Material.DiamondPlate)
		local ex, base = Mach.excavator()
		ex.Name = "ShowExcavator"
		for _, p in ipairs(ex:GetDescendants()) do if p:IsA("BasePart") then p.Anchored = true; p.CanCollide = true end end
		ex:ScaleTo(1.35)
		ex:PivotTo(cf * CFrame.new(-11, 1.3 + base * 1.35, -21) * CFrame.Angles(0, math.rad(-145), 0))
		-- sits on the plinth
		local bcf, bsz = ex:GetBoundingBox()
		ex:PivotTo(ex:GetPivot() + Vector3.new(0, (1.3) - (bcf.Position.Y - bsz.Y / 2), 0))
		ex.Parent = mdl
		local tag = P("ShowSign", Vector3.new(7, 1.6, 0.3), CFrame.new(-11, 1.7, -25.7), Color3.fromRGB(28, 32, 44))
		signText(tag, "MINI EXCAVATOR", YEL, { Enum.NormalId.Back })
		table.insert(report, "excavator on show")
	else
		table.insert(report, "no excavator: " .. tostring(Mach))
	end
	table.insert(report, "machines depot")
end

---------------------------------------------------------------------------------------------------------------------
-- 3. TRAINING SHOP at the Training Yard gate: east of the path, front to the street (south), like the gate
--    (you see its front as you walk up the path, not a brick side wall)
---------------------------------------------------------------------------------------------------------------------
table.insert(report, "yard gate cleared: " .. clear(CFrame.new(-197, 6, 195), Vector3.new(26, 30, 24), roots))
do
	local OR = Color3.fromRGB(255, 120, 40)
	local mdl, cf, P = building({ name = "TrainingShop", parent = Plaza, pos = Vector3.new(-197, 0, 196), face = Vector3.new(0, 0, -1), w = 17, d = 12, h = 11,
		wall = Color3.fromRGB(200, 80, 60), accent = OR, text = "🧤 TRAINING GEAR", roof = "TRAINING" })
	local d = 12
	-- an open front: door, two windows with gear behind them
	P("Door", Vector3.new(4, 7, 0.3), CFrame.new(0, 0.5 + 3.5, -d / 2 - 0.12), Color3.fromRGB(60, 46, 36), Enum.Material.Wood)
	P("DoorFrame", Vector3.new(4.8, 0.5, 0.5), CFrame.new(0, 0.5 + 7.2, -d / 2 - 0.2), Color3.fromRGB(240, 240, 240))
	for _, sx in ipairs({ -1, 1 }) do
		P("Window", Vector3.new(4.6, 4.2, 0.3), CFrame.new(sx * 5.4, 0.5 + 4.6, -d / 2 - 0.12), Color3.fromRGB(150, 205, 235), Enum.Material.Glass, { Transparency = 0.15, Reflectance = 0.2 })
		P("WindowLight", Vector3.new(4, 0.3, 0.2), CFrame.new(sx * 5.4, 0.5 + 6.5, -d / 2 - 0.3), Color3.fromRGB(255, 236, 190), Enum.Material.Neon, { CanCollide = false })
	end
	-- a dumbbell rack and a big glove sign outside
	P("Rack", Vector3.new(5, 0.4, 1.6), CFrame.new(-6.2, 0.5 + 2.2, -d / 2 - 3), Color3.fromRGB(60, 62, 70), Enum.Material.Metal)
	for _, sx in ipairs({ -8.2, -4.2 }) do P("RackLeg", Vector3.new(0.3, 2.2, 1.4), CFrame.new(sx, 0.5 + 1.1, -d / 2 - 3), Color3.fromRGB(60, 62, 70), Enum.Material.Metal) end
	for k = 0, 2 do
		local x = -7.8 + k * 1.6
		P("Bell", Vector3.new(1.6, 0.6, 0.6), CFrame.new(x, 0.5 + 2.75, -d / 2 - 3) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(40, 40, 46), Enum.Material.Metal, { Shape = Enum.PartType.Cylinder })
	end
	P("Kettlebell", Vector3.new(1.6, 1.6, 1.6), CFrame.new(6.5, 0.5 + 0.8, -d / 2 - 3), Color3.fromRGB(230, 70, 50), Enum.Material.SmoothPlastic, { Shape = Enum.PartType.Ball })
	P("KettleHandle", Vector3.new(1.2, 0.9, 0.3), CFrame.new(6.5, 0.5 + 1.9, -d / 2 - 3), Color3.fromRGB(40, 40, 46), Enum.Material.Metal)
	prompt(mdl, cf * CFrame.new(0, 3.5, -d / 2 - 3.5), "GearPrompt", "TRAINING SHOP", "Open Shop")
	table.insert(report, "training shop")
end
return table.concat(report, " | ")
