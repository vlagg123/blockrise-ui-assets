-- one-off map change (run in Edit):
--  * the spawn's centre piece: the three plain gold cubes become the BLOCKRISE MONUMENT, a tower of coloured blocks
--    rising in a spiral over the spawn with a golden hammer on top (it floats: nothing to bump into, nobody spawns on it;
--    a client script turns it slowly, see StarterPlayerScripts.MonumentFX)
--  * the roof signs of the Machines Depot and the Training Shop get a dark outline (white on yellow could not be read)
local Map = workspace.Map
local backup = game.ServerStorage:FindFirstChild("Backup_pre_monument") or Instance.new("Folder")
backup.Name = "Backup_pre_monument"
backup.Parent = game.ServerStorage
local report = {}

-- 1. roof signs: a thick dark outline around the letters ---------------------------------------------------------------
local n = 0
for _, shop in ipairs({ Map.Plaza:FindFirstChild("MachinesDepot"), Map.Plaza:FindFirstChild("TrainingShop") }) do
	local rs = shop and shop:FindFirstChild("RoofSign")
	if rs then
		for _, l in ipairs(rs:GetDescendants()) do
			if l:IsA("TextLabel") then
				local st = l:FindFirstChildOfClass("UIStroke") or Instance.new("UIStroke")
				st.Thickness = 7
				st.Color = Color3.fromRGB(28, 22, 40)
				st.LineJoinMode = Enum.LineJoinMode.Round
				st.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
				st.Parent = l
				n += 1
			end
		end
	end
end
table.insert(report, "roof sign outlines: " .. n)

-- 2. the monument ---------------------------------------------------------------------------------------------------------
local gp = Map:FindFirstChild("Generated") and Map.Generated:FindFirstChild("Plaza")
local moved = 0
if gp then
	for _, p in ipairs(gp:GetChildren()) do
		if p.Name == "EmblemBlock" then p.Parent = backup; moved += 1 end
	end
end
table.insert(report, "gold cubes moved to backup: " .. moved)
local old = Map.Plaza:FindFirstChild("SpawnMonument")
if old then old:Destroy() end

local spawn = Map:FindFirstChild("Spawn")
local base = spawn and spawn.Position or Vector3.new(0, 1.58, 10)
local C = Vector3.new(base.X, 0, base.Z) -- the monument's axis (the middle of the spawn)
local mdl = Instance.new("Model")
mdl.Name = "SpawnMonument"
mdl.ModelStreamingMode = Enum.ModelStreamingMode.Persistent -- always there (the client animates it)

local function part(props)
	local p = Instance.new("Part")
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	for k, v in pairs(props) do if k ~= "Parent" then p[k] = v end end
	p.Parent = props.Parent or mdl
	return p
end

-- the rising blocks: the game's colours, big at the bottom, smaller going up, each one turned a little more
local COLORS = {
	Color3.fromRGB(255, 150, 40), Color3.fromRGB(255, 214, 60), Color3.fromRGB(70, 160, 255), Color3.fromRGB(80, 210, 110),
	Color3.fromRGB(170, 95, 255), Color3.fromRGB(255, 84, 110), Color3.fromRGB(40, 210, 220),
}
local blocks = Instance.new("Folder")
blocks.Name = "Blocks"
blocks.Parent = mdl
local N = #COLORS
for i = 1, N do
	local k = (i - 1) / (N - 1)
	local size = 3.4 - 1.7 * k
	local y = 9 + i * 2.55
	local a = math.rad(i * 62)
	local r = 2.6 - 1.2 * k
	local pos = C + Vector3.new(math.cos(a) * r, y, math.sin(a) * r)
	local b = part({ Name = "Block" .. i, Size = Vector3.one * size, CFrame = CFrame.new(pos) * CFrame.Angles(math.rad(18), a, math.rad(12)),
		Color = COLORS[i], Material = Enum.Material.SmoothPlastic, Reflectance = 0.05, Parent = blocks })
	-- light edges (a glowing outline)
	local sb = Instance.new("SelectionBox")
	sb.Adornee = b
	sb.LineThickness = 0.06
	sb.Color3 = Color3.new(1, 1, 1)
	sb.SurfaceTransparency = 1
	sb.Transparency = 0.25
	sb.Parent = b
	b:SetAttribute("Spin", 0.35 + 0.25 * ((i % 3) / 2))
	b:SetAttribute("Bob", i * 0.9)
end

-- a golden hammer floating on top, tilted, with a light and a few sparkles
local top = 9 + (N + 1) * 2.55 + 2.2
local hammer = Instance.new("Model")
hammer.Name = "GoldHammer"
hammer.Parent = mdl
local GOLD = Color3.fromRGB(255, 196, 46)
local hcf = CFrame.new(C + Vector3.new(0, top, 0)) * CFrame.Angles(0, 0, math.rad(-28))
part({ Name = "Handle", Shape = Enum.PartType.Cylinder, Size = Vector3.new(7, 0.75, 0.75), CFrame = hcf * CFrame.Angles(0, 0, math.rad(90)),
	Color = Color3.fromRGB(90, 52, 30), Material = Enum.Material.Wood, Parent = hammer })
part({ Name = "Grip", Shape = Enum.PartType.Cylinder, Size = Vector3.new(2.2, 0.9, 0.9), CFrame = hcf * CFrame.new(0, -2.4, 0) * CFrame.Angles(0, 0, math.rad(90)),
	Color = Color3.fromRGB(40, 34, 52), Material = Enum.Material.Fabric, Parent = hammer })
local head = part({ Name = "Head", Size = Vector3.new(4.6, 1.9, 1.9), CFrame = hcf * CFrame.new(0, 3.6, 0), Color = GOLD, Material = Enum.Material.Metal, Reflectance = 0.25, Parent = hammer })
for _, sx in ipairs({ -1, 1 }) do
	part({ Name = "Face", Size = Vector3.new(0.4, 2.2, 2.2), CFrame = hcf * CFrame.new(sx * 2.4, 3.6, 0), Color = Color3.fromRGB(255, 226, 120), Material = Enum.Material.Metal,
		Reflectance = 0.3, Parent = hammer })
end
part({ Name = "Band", Size = Vector3.new(0.5, 2.05, 2.05), CFrame = hcf * CFrame.new(0, 3.6, 0), Color = Color3.fromRGB(255, 120, 40), Material = Enum.Material.Neon, Parent = hammer })
local light = Instance.new("PointLight")
light.Color = Color3.fromRGB(255, 214, 140)
light.Range = 22
light.Brightness = 1.6
light.Parent = head
local sp = Instance.new("ParticleEmitter")
sp.Texture = "rbxasset://textures/particles/sparkles_main.dds"
sp.Rate = 5
sp.Lifetime = NumberRange.new(1, 1.8)
sp.Speed = NumberRange.new(0.5, 1.5)
sp.SpreadAngle = Vector2.new(180, 180)
sp.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 0) })
sp.Color = ColorSequence.new(Color3.fromRGB(255, 240, 180))
sp.LightEmission = 1
sp.Parent = head

-- a soft column of light from the emblem up through the blocks
local beam = part({ Name = "LightColumn", Shape = Enum.PartType.Cylinder, Size = Vector3.new(top - 6, 2.2, 2.2), CFrame = CFrame.new(C + Vector3.new(0, 6 + (top - 6) / 2, 0)) * CFrame.Angles(0, 0, math.rad(90)),
	Color = Color3.fromRGB(255, 230, 150), Material = Enum.Material.Neon, Transparency = 0.82 })
beam:SetAttribute("Pulse", true)

-- two thin golden rings orbiting the tower
for i, rr in ipairs({ { 5.2, 12 }, { 3.8, 22 } }) do
	local ring = Instance.new("Model")
	ring.Name = "Ring" .. i
	ring.Parent = mdl
	local segs = 28
	for s = 1, segs do
		local a = (s / segs) * math.pi * 2
		local len = 2 * math.pi * rr[1] / segs + 0.05
		part({ Name = "Seg", Size = Vector3.new(len, 0.18, 0.35), CFrame = CFrame.new(C + Vector3.new(math.cos(a) * rr[1], rr[2], math.sin(a) * rr[1])) * CFrame.Angles(0, -a + math.pi / 2, 0),
			Color = GOLD, Material = Enum.Material.Neon, Transparency = 0.15, Parent = ring })
	end
	ring:SetAttribute("Tilt", i == 1 and 14 or -18)
	ring:SetAttribute("Speed", i == 1 and 0.5 or -0.7)
end

mdl:SetAttribute("Center", C)
mdl.Parent = Map.Plaza
table.insert(report, "monument: " .. #mdl:GetDescendants() .. " pieces, top at y " .. math.floor(top))
return table.concat(report, " | ")
