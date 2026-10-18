-- BlockRise 3.0 (tycoon prototype, PROTO3_V1) - the world, built once in Edit: a long avenue with six plots (three on
-- each side), each plot an empty lawn with the dirt line of its future Main Street, the faint squares of its lots, a gate
-- with its owner's name, and the vault. Trees, lamps and benches along the avenue; woods behind the plots.
-- World3.build() -> the folder workspace.World3 (rebuilt from scratch)
local ServerStorage = game:GetService("ServerStorage")
local T = require(game:GetService("ReplicatedStorage").Shared3.Tycoon)
local W = {}
local C3 = Color3.fromRGB
local Mat = Enum.Material
local at = CFrame.new

local LAWN = C3(122, 214, 98)
local LAWN_LOT = C3(146, 228, 118)
local DIRT = C3(196, 152, 104)
local WALK = C3(232, 234, 240)
local KERB = C3(250, 250, 250)
local ASPHALT = C3(64, 68, 80)
local GOLD = C3(255, 200, 60)

local function part(parent, size, cf, col, mat, props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Size = size
	p.CFrame = cf
	p.Color = col
	p.Material = mat or Mat.SmoothPlastic
	if props then for k, v in pairs(props) do p[k] = v end end
	p.Parent = parent
	return p
end
local function cyl(parent, r, h, cf, col, mat, props)
	local p = part(parent, Vector3.new(h, r * 2, r * 2), cf * CFrame.Angles(0, 0, math.pi / 2), col, mat, props)
	p.Shape = Enum.PartType.Cylinder
	return p
end
local function label(p, face, text, col, size)
	local sg = Instance.new("SurfaceGui")
	sg.Name = "Label"
	sg.Face = face or Enum.NormalId.Front
	sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	sg.PixelsPerStud = size or 30
	sg.LightInfluence = 0
	local t = Instance.new("TextLabel")
	t.Name = "Text"
	t.BackgroundTransparency = 1
	t.Size = UDim2.fromScale(1, 1)
	t.Font = Enum.Font.FredokaOne
	t.TextScaled = true
	t.TextColor3 = col or Color3.new(1, 1, 1)
	t.Text = text
	local s = Instance.new("UIStroke")
	s.Thickness = 4
	s.Color = C3(24, 32, 70)
	s.Parent = t
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0.04, 0)
	pad.PaddingRight = UDim.new(0.04, 0)
	pad.PaddingTop = UDim.new(0.1, 0)
	pad.PaddingBottom = UDim.new(0.1, 0)
	pad.Parent = t
	t.Parent = sg
	sg.Parent = p
	return t
end
local function kit(name, parent, cf)
	local src = ServerStorage:FindFirstChild("Kit2") and ServerStorage.Kit2:FindFirstChild(name)
	if not src then return nil end
	local m = src:Clone()
	m:PivotTo(cf)
	for _, d in ipairs(m:GetDescendants()) do if d:IsA("BasePart") then d.Anchored = true end end
	m.Parent = parent
	return m
end

-- the plot frames: three on the north side (their back toward -Z), three on the south side
W.PlotX = { -230, 0, 230 }
function W.plotCF(i)
	local x = W.PlotX[(i - 1) % 3 + 1]
	if i <= 3 then return at(x, 0, -23) * CFrame.Angles(0, math.pi, 0) end
	return at(x, 0, 23)
end

local function buildPlot(parent, i)
	local cf = W.plotCF(i)
	local m = Instance.new("Model")
	m.Name = "P" .. i
	m:SetAttribute("Index", i)
	m:SetAttribute("Owner", 0)
	m.Parent = parent
	local PW, PD = T.PlotW, T.PlotD
	-- the lawn and its white border
	local ground = part(m, Vector3.new(PW, 0.4, PD), cf * at(0, 0.2, PD / 2), LAWN, Mat.SmoothPlastic, { Name = "Ground" })
	m.PrimaryPart = ground
	part(m, Vector3.new(PW + 1, 0.9, 1), cf * at(0, 0.45, PD + 0.5), KERB, nil, { Name = "Kerb" })
	part(m, Vector3.new(1, 0.9, PD), cf * at(-PW / 2 - 0.5, 0.45, PD / 2), KERB, nil, { Name = "Kerb" })
	part(m, Vector3.new(1, 0.9, PD), cf * at(PW / 2 + 0.5, 0.45, PD / 2), KERB, nil, { Name = "Kerb" })
	for _, sx in ipairs({ -1, 1 }) do
		part(m, Vector3.new(PW / 2 - 14, 0.9, 1), cf * at(sx * (PW / 4 + 7), 0.45, -0.5), KERB, nil, { Name = "Kerb" })
	end
	-- the future Main Street: a dirt line
	part(m, Vector3.new(T.Road.half * 2 + T.Road.walk * 2, 0.42, PD), cf * at(0, 0.21, PD / 2), DIRT, Mat.SmoothPlastic, { Name = "Dirt" })
	-- the lots: faint lighter squares
	for name, l in pairs(T.Lots) do
		local big = math.abs(l.x) > 50
		part(m, Vector3.new(big and 46 or 44, 0.42, 42), cf * at(l.x, 0.21, l.z), LAWN_LOT, Mat.SmoothPlastic, { Name = "Lot_" .. name })
	end
	-- the gate: two pillars with gold caps, a beam with the owner's name
	local gate = Instance.new("Model")
	gate.Name = "Gate"
	gate.Parent = m
	for _, sx in ipairs({ -1, 1 }) do
		part(gate, Vector3.new(3.4, 16, 3.4), cf * at(sx * 16, 8, 1.5), C3(250, 250, 246), nil, { Name = "Pillar" })
		part(gate, Vector3.new(4.2, 1, 4.2), cf * at(sx * 16, 16.5, 1.5), GOLD, Mat.SmoothPlastic, { Name = "PillarTop" })
		local b = Instance.new("Part")
		b.Shape = Enum.PartType.Ball
		b.Anchored = true
		b.Size = Vector3.one * 2.6
		b.CFrame = cf * at(sx * 16, 18.2, 1.5)
		b.Color = GOLD
		b.Material = Mat.SmoothPlastic
		b.Parent = gate
	end
	local beam = part(gate, Vector3.new(36, 4.4, 1.6), cf * at(0, 13.6, 1.5), C3(36, 48, 110), nil, { Name = "Beam" })
	part(gate, Vector3.new(37, 5.2, 1.2), cf * at(0, 13.6, 1.9), GOLD, nil, { Name = "BeamFrame" })
	-- (the beam's front face, -Z in the plot's frame, looks at the avenue; its back face into the plot)
	local t = label(beam, Enum.NormalId.Front, "FREE PLOT", Color3.new(1, 1, 1), 24)
	t.Name = "OwnerText"
	local t2 = label(beam, Enum.NormalId.Back, "FREE PLOT", Color3.new(1, 1, 1), 24)
	t2.Name = "OwnerTextIn"
	-- the vault: a big steel safe with a gold door, its screen above, the gold pad in front
	local v = Instance.new("Model")
	v.Name = "Vault"
	v.Parent = m
	local vcf = cf * at(T.Vault.x, 0, T.Vault.z) * CFrame.Angles(0, math.pi / 2, 0) -- its front (-Z) toward the street (-X of the plot)
	part(v, Vector3.new(10, 1, 9), vcf * at(0, 0.5, 0), C3(214, 214, 208), nil, { Name = "Base" })
	local body = part(v, Vector3.new(8, 8.5, 7), vcf * at(0, 5.25, 0.5), C3(70, 78, 96), Mat.SmoothPlastic, { Name = "Body" })
	part(v, Vector3.new(8.6, 0.6, 7.6), vcf * at(0, 9.6, 0.5), GOLD, nil, { Name = "Trim" })
	part(v, Vector3.new(8.6, 0.6, 7.6), vcf * at(0, 1.3, 0.5), GOLD, nil, { Name = "Trim" })
	local door = cyl(v, 3, 0.6, vcf * at(0, 5.2, -3.1) * CFrame.Angles(math.pi / 2, 0, 0), GOLD, Mat.SmoothPlastic, { Name = "Door" })
	door.CFrame = vcf * at(0, 5.2, -3.15) * CFrame.Angles(0, math.pi / 2, 0)
	cyl(v, 1, 0.8, vcf * at(0, 5.2, -3.5) * CFrame.Angles(0, 0, 0), C3(220, 160, 40), nil, { Name = "Hub" }).CFrame = vcf * at(0, 5.2, -3.5) * CFrame.Angles(0, math.pi / 2, 0)
	for k = 0, 3 do
		part(v, Vector3.new(0.5, 5, 0.4), vcf * at(0, 5.2, -3.7) * CFrame.Angles(0, 0, k * math.pi / 4), C3(200, 140, 30), nil, { Name = "Spoke" })
	end
	-- the screen with the cash inside
	local screen = part(v, Vector3.new(12, 3.6, 0.6), vcf * at(0, 12.6, 0), C3(24, 30, 60), nil, { Name = "Screen" })
	part(v, Vector3.new(12.8, 4.4, 0.4), vcf * at(0, 12.6, 0.4), GOLD, nil, { Name = "ScreenFrame" })
	part(v, Vector3.new(0.6, 3, 0.6), vcf * at(-4, 9.8, 0.5), GOLD, nil, { Name = "ScreenPost" })
	part(v, Vector3.new(0.6, 3, 0.6), vcf * at(4, 9.8, 0.5), GOLD, nil, { Name = "ScreenPost" })
	local st = label(screen, Enum.NormalId.Front, "$0", C3(140, 255, 120), 30)
	st.Name = "Cash"
	v.PrimaryPart = body
	-- the pad: walk over it to take the cash
	local pad = cyl(m, 3.4, 0.3, cf * at(T.VaultPad.x, 0.5, T.VaultPad.z), GOLD, Mat.Neon, { Name = "VaultPad", CanCollide = false, Transparency = 0.1 })
	cyl(m, 4.1, 0.24, cf * at(T.VaultPad.x, 0.45, T.VaultPad.z), C3(250, 250, 246), nil, { Name = "VaultPadRim", CanCollide = false })
	pad:SetAttribute("Pad", true)
	-- folders for what gets built and the buttons
	local built = Instance.new("Model") built.Name = "Built" built.Parent = m
	local buttons = Instance.new("Folder") buttons.Name = "Buttons" buttons.Parent = m
	return m
end

function W.build()
	local old = workspace:FindFirstChild("World3")
	if old then old:Destroy() end
	local world = Instance.new("Folder")
	world.Name = "World3"
	world.Parent = workspace
	-- the ground
	part(world, Vector3.new(1700, 1, 1150), at(0, -0.5, 0), C3(110, 200, 88), Mat.SmoothPlastic, { Name = "Ground" })
	-- the avenue: asphalt, a double yellow line, lane dashes, sidewalks with kerbs
	local av = Instance.new("Model") av.Name = "Avenue" av.Parent = world
	local L = 820
	part(av, Vector3.new(L, 0.4, 30), at(0, 0.2, 0), ASPHALT, nil, { Name = "Road" })
	part(av, Vector3.new(L, 0.42, 0.5), at(0, 0.21, -0.5), C3(255, 210, 60), nil, { Name = "Line" })
	part(av, Vector3.new(L, 0.42, 0.5), at(0, 0.21, 0.5), C3(255, 210, 60), nil, { Name = "Line" })
	for x = -L / 2 + 6, L / 2 - 6, 18 do
		for _, z in ipairs({ -7.5, 7.5 }) do part(av, Vector3.new(8, 0.42, 0.5), at(x, 0.21, z), Color3.new(1, 1, 1), nil, { Name = "Dash" }) end
	end
	for _, sz in ipairs({ -1, 1 }) do
		part(av, Vector3.new(L, 0.6, 8), at(0, 0.3, sz * 19), WALK, nil, { Name = "Walk" })
		part(av, Vector3.new(L, 0.7, 0.8), at(0, 0.35, sz * 15.4), KERB, nil, { Name = "Kerb" })
	end
	-- crosswalks at the plot gates
	for _, x in ipairs(W.PlotX) do
		for k = -5, 5 do part(av, Vector3.new(1.6, 0.43, 28), at(x + k * 3, 0.215, 0), Color3.new(1, 1, 1), nil, { Name = "Zebra" }) end
	end
	-- the plots
	local plots = Instance.new("Folder") plots.Name = "Plots" plots.Parent = world
	for i = 1, 6 do buildPlot(plots, i) end
	-- the spawn (everyone is taken to their plot's gate right away)
	local sp = Instance.new("SpawnLocation")
	sp.Name = "Spawn"
	sp.Anchored = true
	sp.Size = Vector3.new(8, 1, 8)
	sp.CFrame = at(0, 0.6, 0)
	sp.Transparency = 1
	sp.CanCollide = false
	sp.Neutral = true
	sp.Duration = 0
	sp.Parent = world
	local decal = sp:FindFirstChildOfClass("Decal")
	if decal then decal:Destroy() end
	-- decor: trees and lamps on the sidewalks (not in front of the gates), trees between and behind the plots
	local decor = Instance.new("Folder") decor.Name = "Decor" decor.Parent = world
	local trees = { "TreeA", "TreeB", "TreeC", "TreeD", "TreeE" }
	local rng = Random.new(42)
	for x = -400, 400, 40 do
		local nearGate = false
		for _, gx in ipairs(W.PlotX) do if math.abs(x - gx) < 30 then nearGate = true end end
		if not nearGate then
			for _, sz in ipairs({ -1, 1 }) do
				kit(trees[rng:NextInteger(1, #trees)], decor, at(x, 0.6, sz * 20) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0))
				kit("StreetLight", decor, at(x + 20, 0.6, sz * 16.6) * CFrame.Angles(0, sz < 0 and 0 or math.pi, 0))
			end
		end
	end
	-- between the plots and around them
	for _, gx in ipairs({ -115, 115, -345, 345 }) do
		for _, sz in ipairs({ -1, 1 }) do
			for z = 40, 360, 26 do
				kit(trees[rng:NextInteger(1, #trees)], decor, at(gx + rng:NextNumber(-6, 6), 0, sz * z) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0))
			end
		end
	end
	for _, sz in ipairs({ -1, 1 }) do
		for x = -380, 380, 22 do
			kit(rng:NextNumber() < 0.4 and "Pine" or trees[rng:NextInteger(1, #trees)], decor, at(x + rng:NextNumber(-5, 5), 0, sz * (378 + rng:NextNumber(0, 30))) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0))
		end
	end
	-- soft hills on the horizon
	for k = 1, 14 do
		local x = -800 + k * 110 + rng:NextNumber(-30, 30)
		for _, sz in ipairs({ -1, 1 }) do
			local r = rng:NextNumber(60, 110)
			local h = Instance.new("Part")
			h.Shape = Enum.PartType.Ball
			h.Anchored = true
			h.Size = Vector3.one * r * 2
			h.CFrame = at(x, -r * 0.55, sz * (520 + rng:NextNumber(0, 40)))
			h.Color = C3(96, 186, 92):Lerp(C3(130, 210, 110), rng:NextNumber())
			h.Material = Mat.SmoothPlastic
			h.Parent = decor
		end
	end
	return world
end

return W
