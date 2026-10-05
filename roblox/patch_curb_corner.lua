-- one-off map fix (run in Edit): the two street corners where the side roads of the houses (lots) meet the big road
-- at z = 356 (x = -440 and x = +440). North of it those roads are 32 wide, south of it 28 wide, so the curb and the
-- outer edge of the sidewalk jumped 2 studs there. Nothing else moves: the sidewalk on the outer side is simply
-- widened (its outer edge now runs straight on), and the curb narrows on a short slant (a wedge) instead of a step.
-- The old pieces are kept in ServerStorage.Backup_pre_curb.
local S = workspace.Map.Generated.Surfaces
local function find(x0, x1, z0, z1)
	for _, p in ipairs(S:GetDescendants()) do
		if p:IsA("BasePart") and p.Orientation.Y % 180 == 0 then
			local sx, sz = p.Size.X, p.Size.Z
			if math.abs(p.Position.X - sx / 2 - x0) < 0.3 and math.abs(p.Position.X + sx / 2 - x1) < 0.3
				and math.abs(p.Position.Z - sz / 2 - z0) < 0.3 and math.abs(p.Position.Z + sz / 2 - z1) < 0.3 then return p end
		end
	end
	error(("piece not found x[%d,%d] z[%d,%d]"):format(x0, x1, z0, z1))
end
local function setBox(p, x0, x1, z0, z1)
	p.Size = Vector3.new(x1 - x0, p.Size.Y, z1 - z0)
	p.CFrame = CFrame.new((x0 + x1) / 2, p.Position.Y, (z0 + z1) / 2)
end
if S:FindFirstChild("CurbTaper") then return "already fixed" end

local westOuter = find(-462, -454, 364, 671)
local westPatch = find(-456, -454, 356, 364)
local eastOuter = find(454, 462, 356, 663)
local eastPatch = find(462, 464, 356, 364)
local bottom = find(-454, 462, 663, 671)
local asphW = find(-454, -426, 356, 663)
local asphE = find(426, 454, 356, 457)

local bk = Instance.new("Folder")
bk.Name = "Backup_pre_curb"
for _, p in ipairs({ westOuter, westPatch, eastOuter, eastPatch, bottom }) do p:Clone().Parent = bk end
bk.Parent = game.ServerStorage

-- outer sidewalks: 8 wide, in line with the sidewalk north of the corner; the 2 studs left to the curb get their own strip
setBox(westOuter, -464, -456, 356, 671)
setBox(westPatch, -456, -454, 366, 671)
setBox(eastOuter, 456, 464, 356, 663)
setBox(eastPatch, 454, 456, 366, 663)
setBox(bottom, -464, 464, 663, 671)

-- the slant: road surface under it, a concrete wedge on top (the curb runs diagonally over 10 studs)
local function taper(x, s, asph)
	local a = asph:Clone()
	a.Name = "CurbTaperRoad"
	setBox(a, x - 1, x + 1, 356, 366)
	a.Parent = asph.Parent
	local w = Instance.new("WedgePart")
	w.Name = "CurbTaper"
	for _, k in ipairs({ "Anchored", "CanCollide", "CanQuery", "CanTouch", "CastShadow", "Color", "Material", "MaterialVariant", "Reflectance",
		"TopSurface", "BottomSurface", "CollisionGroup" }) do
		pcall(function() w[k] = westOuter[k] end)
	end
	w.Size = Vector3.new(westOuter.Size.Y, 2, 10)
	-- wedge X = up/down, Y = across the road (towards the road: thinner), Z = along it (full width at the far end)
	w.CFrame = CFrame.fromMatrix(Vector3.new(x, westOuter.Position.Y, 361), Vector3.new(0, -s, 0), Vector3.new(s, 0, 0), Vector3.new(0, 0, 1))
	w.Parent = westOuter.Parent
end
taper(-455, 1, asphW)
taper(455, -1, asphE)
return "curb corners fixed"
