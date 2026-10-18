-- BlockRise 2.0 - turns the AI-generated models (ServerStorage.Gen2, keys b<level>_<style>, props) into the game's
-- library (ServerStorage.Assets2): scaled to their lot, the pivot at the bottom centre, the front toward -Z,
-- anchored, simple collisions. Run once in Edit after new models are generated.
local M = {}

-- each level's size: the height it aims for, its widest side between wMin and wMax (the pad is 52 x 52 and its
-- path to the door starts at the front edge, so 46 at most). A slender model that would get too wide for its
-- height is stretched up a little (at most `stretch`), so every level stands taller than the one before.
M.Size = {
	{ h = 14, wMin = 16, wMax = 24 },
	{ h = 20, wMin = 26, wMax = 34 },
	{ h = 26, wMin = 30, wMax = 38 },
	{ h = 38, wMin = 24, wMax = 40 },
	{ h = 50, wMin = 34, wMax = 44 },
	{ h = 72, wMin = 34, wMax = 46 },
	{ h = 90, wMin = 38, wMax = 46, stretch = 1.3 },
	{ h = 110, wMin = 40, wMax = 46, stretch = 1.3 },
	{ h = 130, wMin = 40, wMax = 46, stretch = 1.3 },
	{ h = 150, wMin = 42, wMax = 48, stretch = 1.45 },
}

-- scale a model: spec = { h, wMin, wMax, stretch } (or a number: its widest side)
local function normalize(src, spec, name)
	local m = src:Clone()
	m.Name = name
	local cf, size = m:GetBoundingBox()
	local w = math.max(size.X, size.Z)
	local s, k = 1, 1
	if type(spec) == "number" then
		s = spec / w
	else
		s = spec.h / size.Y
		if w * s > spec.wMax then
			s = spec.wMax / w
			k = math.min(spec.stretch or 1.15, spec.h / (size.Y * s))
		elseif w * s < spec.wMin then
			s = spec.wMin / w
		end
	end
	m.WorldPivot = CFrame.new(cf.X, cf.Y - size.Y / 2, cf.Z)
	m:ScaleTo(s)
	m:PivotTo(CFrame.new())
	if k > 1.001 then
		-- stretch up from the ground
		for _, p in ipairs(m:GetDescendants()) do
			if p:IsA("BasePart") then
				local pos = p.Position
				p.Size = Vector3.new(p.Size.X, p.Size.Y * k, p.Size.Z)
				p.CFrame = (p.CFrame - pos) + Vector3.new(pos.X, pos.Y * k, pos.Z)
			end
		end
	end
	for _, p in ipairs(m:GetDescendants()) do
		if p:IsA("BasePart") then
			p.Anchored = true
			p.CanTouch = false
			p.CastShadow = true
			if p:IsA("MeshPart") then pcall(function() p.CollisionFidelity = Enum.CollisionFidelity.Box end) end
		end
	end
	local _, s2 = m:GetBoundingBox()
	m:SetAttribute("Height", s2.Y)
	m:SetAttribute("Width", math.max(s2.X, s2.Z))
	return m
end

function M.build()
	local gen = game.ServerStorage:FindFirstChild("Gen2")
	assert(gen, "no Gen2")
	local lib = game.ServerStorage:FindFirstChild("Assets2") or Instance.new("Folder")
	lib.Name = "Assets2"
	lib.Parent = game.ServerStorage
	local bf = lib:FindFirstChild("Buildings") or Instance.new("Folder")
	bf.Name = "Buildings"
	bf.Parent = lib
	local out = {}
	for lv = 1, 10 do
		for st = 1, 2 do
			local src = gen:FindFirstChild("b" .. lv .. "_" .. st)
			if src then
				local old = bf:FindFirstChild("B" .. lv .. "_" .. st)
				if old then old:Destroy() end
				local m = normalize(src, M.Size[lv], "B" .. lv .. "_" .. st)
				m:SetAttribute("Level", lv)
				m:SetAttribute("Style", st)
				m.Parent = bf
				table.insert(out, string.format("B%d_%d h=%.0f", lv, st, m:GetAttribute("Height")))
			end
		end
	end
	-- the props: the size of their widest side, or { h = height }
	local pf = lib:FindFirstChild("Props") or Instance.new("Folder")
	pf.Name = "Props"
	pf.Parent = lib
	for key, spec in pairs(M.Props) do
		local src = gen:FindFirstChild(type(spec) == "table" and spec.src or key)
		if src then
			local old = pf:FindFirstChild(key)
			if old then old:Destroy() end
			local m = normalize(src, spec, key)
			-- STYLE: flat colours instead of the generated texture (crisp, like Pet Simulator): the parts named in
			-- `flat` get that colour (a part not named keeps its texture); `metal`: every part that colour, Metal
			if type(spec) == "table" and (spec.flat or spec.metal) then
				for _, p in ipairs(m:GetDescendants()) do
					if p:IsA("MeshPart") then
						local col = spec.metal
						if spec.flat then for name, c in pairs(spec.flat) do if p.Name:find(name, 1, true) then col = c end end end
						if col then
							p.TextureID = ""
							p.Color = col
							p.Material = spec.metal and Enum.Material.Metal or Enum.Material.SmoothPlastic
							for _, sa in ipairs(p:GetChildren()) do if sa:IsA("SurfaceAppearance") then sa:Destroy() end end
						end
					end
				end
			end
			m.Parent = pf
			table.insert(out, string.format("%s h=%.0f w=%.0f", key, m:GetAttribute("Height"), m:GetAttribute("Width")))
		end
	end
	return table.concat(out, " ")
end
M.Props = {
	lamp = { h = 15, wMin = 3, wMax = 7 },
	bench = 8,
	tree_green = { h = 24, wMin = 16, wMax = 26 },
	tree_mint = { h = 21, wMin = 14, wMax = 24 },
	bush = { h = 4.5, wMin = 4, wMax = 8 },
	shop_hammer = { h = 40, wMin = 40, wMax = 56 },
	hammer_gold = { h = 30, wMin = 8, wMax = 40, metal = Color3.fromRGB(255, 196, 40) },
	tree_flat = { src = "tree_seg", h = 20, wMin = 12, wMax = 22, flat = { canopy = Color3.fromRGB(96, 206, 72), trunk = Color3.fromRGB(170, 112, 66) } },
	pagoda = { h = 70, wMin = 36, wMax = 50 },
}

-- a prop (a clone), nil if none
function M.prop(key)
	local lib = game.ServerStorage:FindFirstChild("Assets2")
	local pf = lib and lib:FindFirstChild("Props")
	local m = pf and pf:FindFirstChild(key)
	return m and m:Clone() or nil
end

-- a building for a lot: the library's model (style 2 falls back to style 1), nil if none
function M.building(level, style)
	local lib = game.ServerStorage:FindFirstChild("Assets2")
	local bf = lib and lib:FindFirstChild("Buildings")
	if not bf then return nil end
	local m = bf:FindFirstChild("B" .. level .. "_" .. (style or 1)) or bf:FindFirstChild("B" .. level .. "_1")
	return m and m:Clone() or nil
end

return M
