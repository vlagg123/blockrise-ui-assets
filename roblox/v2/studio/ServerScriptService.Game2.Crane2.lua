-- BlockRise 2.0: the live game's tower crane (Crane), standing next to a lot's tall building while it is built.
-- Tower crane that stands next to tall buildings while they are built.
-- The server builds it once; clients swing the jib and move the trolley/hook locally.
local Crane = {}

local folder = workspace:FindFirstChild("Cranes") or Instance.new("Folder")
folder.Name = "Cranes"
folder.Parent = workspace

local YELLOW = Color3.fromRGB(246, 190, 30)
local DARK = Color3.fromRGB(44, 46, 54)
local CONCRETE = Color3.fromRGB(150, 150, 146)

local function part(model, name, size, cf, color, material)
	local p = Instance.new("Part")
	p.Name = name; p.Size = size; p.CFrame = cf; p.Color = color; p.Material = material or Enum.Material.Metal
	p.Anchored = true; p.CanCollide = false; p.CanQuery = false; p.CanTouch = false
	p.TopSurface = Enum.SurfaceType.Smooth; p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = model
	return p
end

local padParams = RaycastParams.new()
padParams.FilterType = Enum.RaycastFilterType.Include
-- 2.0: it stands on a lot pad, a land field or the grass, never on a street or a sidewalk
local GROUND = { Pad = true, Grass = true, Patch = true, Field = true, Kerb = true }
local function onPad(pos)
	local world = workspace:FindFirstChild("World")
	padParams.FilterDescendantsInstances = { world }
	local hit = workspace:Raycast(pos + Vector3.new(0, 25, 0), Vector3.new(0, -50, 0), padParams)
	return hit ~= nil and GROUND[hit.Instance.Name] == true
end

local overlap = OverlapParams.new()
overlap.FilterType = Enum.RaycastFilterType.Include

function Crane.Spawn(job)
	if not job.size or job.size.Y < 16 then return nil end
	local sx, sz = job.size.X / 2, job.size.Z / 2
	-- pick a free corner on the site
	-- avoid other buildings and pallets (not this site's own debris, which gets cleared anyway)
	-- 2.0: the buildings of the city around (not this site's own model)
	local avoid = {}
	local world = workspace:FindFirstChild("World")
	for _, d in ipairs(world and world:FindFirstChild("Districts") and world.Districts:GetChildren() or {}) do
		local lots = d:FindFirstChild("City") and d.City:FindFirstChild("Lots")
		for _, lot in ipairs(lots and lots:GetChildren() or {}) do
			for _, b in ipairs(lot:GetChildren()) do if b:IsA("Model") and b ~= job.model then table.insert(avoid, b) end end
		end
	end
	overlap.FilterDescendantsInstances = avoid
	local baseCF
	for _, c in ipairs({ { sx + 7, -(sz + 3) }, { -(sx + 7), -(sz + 3) }, { sx + 7, sz + 4 }, { -(sx + 7), sz + 4 }, { sx + 6, 0 }, { -(sx + 6), 0 } }) do
		local cf = job.origin * CFrame.new(c[1], 0, c[2])
		local ok = onPad(cf.Position) and onPad((cf * CFrame.new(3, 0, 3)).Position) and onPad((cf * CFrame.new(-3, 0, -3)).Position)
		if ok and #workspace:GetPartBoundsInBox(cf * CFrame.new(0, 3, 0), Vector3.new(7, 6, 7), overlap) > 0 then ok = false end
		if ok then baseCF = cf break end
	end
	if not baseCF then return nil end
	baseCF = CFrame.new(baseCF.Position)

	local H = math.floor(job.size.Y + 14)
	local reach = math.max(sx, sz) * 1.5 + 8
	local m = Instance.new("Model")
	m.Name = "Crane_" .. job.id
	-- foundation + lattice mast (4 corner chords + rungs)
	part(m, "Base", Vector3.new(7, 1, 7), baseCF * CFrame.new(0, 0.5, 0), CONCRETE, Enum.Material.Concrete)
	for _, sx2 in ipairs({ -1, 1 }) do for _, sz2 in ipairs({ -1, 1 }) do
		part(m, "Chord", Vector3.new(0.4, H, 0.4), baseCF * CFrame.new(sx2 * 1.1, 1 + H / 2, sz2 * 1.1), YELLOW)
	end end
	for y = 3, H - 1, 3 do
		part(m, "Rung", Vector3.new(2.6, 0.22, 0.22), baseCF * CFrame.new(0, 1 + y, -1.1), YELLOW)
		part(m, "Rung", Vector3.new(2.6, 0.22, 0.22), baseCF * CFrame.new(0, 1 + y, 1.1), YELLOW)
		part(m, "Rung", Vector3.new(0.22, 0.22, 2.6), baseCF * CFrame.new(-1.1, 1 + y, 0), YELLOW)
		part(m, "Rung", Vector3.new(0.22, 0.22, 2.6), baseCF * CFrame.new(1.1, 1 + y, 0), YELLOW)
	end
	-- slewing head (everything from here swings around the mast)
	local pivot = baseCF * CFrame.new(0, 1 + H, 0)
	local swing = {}
	local function sp(name, size, rel, color, material)
		local p = part(m, name, size, pivot * rel, color, material)
		p:SetAttribute("Rel", rel)
		table.insert(swing, p)
		return p
	end
	sp("Slew", Vector3.new(3, 1, 3), CFrame.new(0, 0.5, 0), DARK)
	sp("Cab", Vector3.new(1.8, 1.8, 1.8), CFrame.new(1.4, -0.2, 2.1), Color3.fromRGB(240, 240, 236), Enum.Material.SmoothPlastic)
	sp("CabGlass", Vector3.new(1.6, 1, 0.1), CFrame.new(1.4, 0, 3.02), Color3.fromRGB(70, 110, 150), Enum.Material.Glass)
	sp("Peak", Vector3.new(0.5, 5, 0.5), CFrame.new(0, 3.5, 0), YELLOW)
	-- jib (towards +X) and counter-jib (towards -X)
	sp("Jib", Vector3.new(reach, 0.9, 1.2), CFrame.new(reach / 2 + 1, 1.45, 0), YELLOW)
	sp("JibTop", Vector3.new(reach - 2, 0.25, 0.25), CFrame.new(reach / 2 + 1, 2.3, 0), YELLOW)
	sp("Counter", Vector3.new(9, 0.8, 1.6), CFrame.new(-5.5, 1.4, 0), YELLOW)
	for i = 0, 2 do
		sp("Weight", Vector3.new(1.4, 1.8, 1.8), CFrame.new(-7.2 + i * 1.45, 0.3, 0), CONCRETE, Enum.Material.Concrete)
	end
	-- tie bars from the peak to both arms
	local function tie(x)
		local a, b = Vector3.new(0, 6, 0), Vector3.new(x, 2, 0)
		local len = (b - a).Magnitude
		sp("Tie", Vector3.new(0.15, 0.15, len), CFrame.lookAt((a + b) / 2, b), DARK)
	end
	tie(reach * 0.75)
	tie(-8)
	-- trolley, cable and hook are moved by the clients
	part(m, "Trolley", Vector3.new(1.4, 0.6, 1.4), pivot * CFrame.new(reach * 0.6, 0.65, 0), DARK)
	part(m, "Cable", Vector3.new(0.12, 6, 0.12), pivot * CFrame.new(reach * 0.6, -3, 0), DARK)
	part(m, "Hook", Vector3.new(0.9, 1.1, 0.9), pivot * CFrame.new(reach * 0.6, -6.5, 0), Color3.fromRGB(230, 60, 40))
	-- red warning light on the peak
	local beacon = sp("Beacon", Vector3.new(0.6, 0.6, 0.6), CFrame.new(0, 6.3, 0), Color3.fromRGB(255, 40, 40), Enum.Material.Neon)
	local l = Instance.new("PointLight"); l.Color = Color3.fromRGB(255, 60, 60); l.Range = 10; l.Parent = beacon

	m:SetAttribute("Pivot", pivot)
	m:SetAttribute("Reach", reach)
	m:SetAttribute("Height", H)
	m:SetAttribute("Seed", math.random() * 10)
	m:SetAttribute("BaseAngle", math.atan2(-(job.origin.Position.Z - pivot.Position.Z), job.origin.Position.X - pivot.Position.X))
	m.Parent = folder
	job.craneModel = m
	return m
end

return Crane
