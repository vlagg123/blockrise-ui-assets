-- BlockRise Empire - the spawn monument (Map.Plaza.SpawnMonument) comes alive on each client: the tower of blocks turns
-- slowly and every block spins and floats on its own, the golden hammer turns, the two rings orbit, the light column
-- breathes. Client-side only: smooth, nothing sent over the network. Skipped while the camera is far away.
local RunService = game:GetService("RunService")
local Plaza = workspace:WaitForChild("Map"):WaitForChild("Plaza")

local cache
local function setup(mdl)
	local C = mdl:GetAttribute("Center")
	if typeof(C) ~= "Vector3" then return nil end
	local parts = {}
	for _, d in ipairs(mdl:GetDescendants()) do
		if d:IsA("BasePart") then
			local group = d.Parent
			local kind = group.Name == "Blocks" and "block" or group.Name == "GoldHammer" and "hammer" or group.Name:match("^Ring") and "ring" or (d.Name == "LightColumn" and "beam") or "still"
			table.insert(parts, { p = d, base = d.CFrame, kind = kind, group = group, trans = d.Transparency })
		end
	end
	return { mdl = mdl, C = C, parts = parts }
end

RunService.RenderStepped:Connect(function()
	local mdl = Plaza:FindFirstChild("SpawnMonument")
	if not mdl then cache = nil return end
	if not cache or cache.mdl ~= mdl then cache = setup(mdl) if not cache then return end end
	local cam = workspace.CurrentCamera
	local C = cache.C
	if cam and (cam.CFrame.Position - C).Magnitude > 420 then return end
	local t = os.clock()
	local around = function(angle, y)
		local pivot = Vector3.new(C.X, y or 0, C.Z)
		return CFrame.new(pivot) * CFrame.Angles(0, angle, 0) * CFrame.new(-pivot)
	end
	local tower = around(t * 0.22)
	for _, e in ipairs(cache.parts) do
		local p, base = e.p, e.base
		if e.kind == "block" then
			local spin = p:GetAttribute("Spin") or 0.4
			local bob = math.sin(t * 1.3 + (p:GetAttribute("Bob") or 0)) * 0.35
			p.CFrame = tower * (CFrame.new(base.Position + Vector3.new(0, bob, 0)) * base.Rotation * CFrame.Angles(0, t * spin, t * spin * 0.35))
		elseif e.kind == "hammer" then
			p.CFrame = around(t * 0.6) * (CFrame.new(0, math.sin(t * 1.1) * 0.5, 0) * base)
		elseif e.kind == "ring" then
			local tilt = math.rad(e.group:GetAttribute("Tilt") or 0)
			local speed = e.group:GetAttribute("Speed") or 0.5
			local pivot = Vector3.new(C.X, base.Position.Y, C.Z)
			p.CFrame = CFrame.new(pivot) * CFrame.Angles(tilt, 0, 0) * CFrame.Angles(0, t * speed, 0) * CFrame.new(-pivot) * base
		elseif e.kind == "beam" then
			p.Transparency = e.trans + 0.07 * math.sin(t * 2)
		end
	end
end)
