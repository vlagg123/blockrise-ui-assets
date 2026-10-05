-- one-off patch (run in Edit): name tags never overlap
--  * VIP and the company name sit on the same spot above the head and are stacked in screen pixels (SizeOffset), so they
--    stay one above the other at any distance
--  * the "<name>'s Site Kart" tag on a car hides while someone drives it (the driver's own tags are right there)
local function replaceOnce(src, old, new)
	local a, b = src:find(old, 1, true)
	assert(a, "not found: " .. old:sub(1, 80))
	assert(not src:find(old, b + 1, true), "found twice: " .. old:sub(1, 80))
	return src:sub(1, a - 1) .. new .. src:sub(b + 1)
end
local G = game.ServerScriptService.Game

local m = G.Main.Source
if not m:find("VipTag stacked", 1, true) then
	m = replaceOnce(m, [[bb.Name = "VipTag"; bb.Size = UDim2.fromOffset(110, 30); bb.StudsOffset = Vector3.new(0, 3.2, 0); bb.MaxDistance = 90]],
		[[bb.Name = "VipTag"; bb.Size = UDim2.fromOffset(110, 30); bb.StudsOffset = Vector3.new(0, 3.4, 0); bb.MaxDistance = 90
	bb.SizeOffset = Vector2.new(0, 0.62) -- VipTag stacked: one line above the company name, at any distance]])
	assert(loadstring(m), "Main compile")
end

local cs = G.CompanyService.Source
if not cs:find("SizeOffset", 1, true) then
	cs = replaceOnce(cs, [[tag.Name = "CompanyTag"; tag.Size = UDim2.fromOffset(200, 26); tag.StudsOffset = Vector3.new(0, 2.5, 0); tag.MaxDistance = 80]],
		[[tag.Name = "CompanyTag"; tag.Size = UDim2.fromOffset(200, 26); tag.StudsOffset = Vector3.new(0, 3.4, 0); tag.MaxDistance = 80
		tag.SizeOffset = Vector2.new(0, -0.62) -- one line under the VIP tag (same spot, stacked in pixels)]])
	assert(loadstring(cs), "CompanyService compile")
end

local vs = G.VehicleService.Source
if not vs:find("OwnerTag hides", 1, true) then
	vs = replaceOnce(vs, [[	local seat = model:FindFirstChild("DriverSeat")
	local a = { model = model, cfg = cfg, root = root, seat = seat, lv = lv, ao = ao, hover = hover, idleSince = os.clock() }]],
		[[	local seat = model:FindFirstChild("DriverSeat")
	-- OwnerTag hides while someone drives: the driver's own tags are right above it
	if seat then
		seat:GetPropertyChangedSignal("Occupant"):Connect(function() bb.Enabled = seat.Occupant == nil end)
	end
	local a = { model = model, cfg = cfg, root = root, seat = seat, lv = lv, ao = ao, hover = hover, idleSince = os.clock() }]])
	assert(loadstring(vs), "VehicleService compile")
end

G.Main.Source = m
G.CompanyService.Source = cs
G.VehicleService.Source = vs
return "tags patched"
