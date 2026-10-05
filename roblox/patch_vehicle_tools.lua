-- one-off patch (run in Edit): in a car your hands are on the wheel. Sitting down (driver or passenger) puts the
-- hammer away (no more arm sticking out), getting out gives it back; equipping it while seated is undone.
local function replaceOnce(src, old, new)
	local a, b = src:find(old, 1, true)
	assert(a, "not found: " .. old:sub(1, 80))
	assert(not src:find(old, b + 1, true), "found twice: " .. old:sub(1, 80))
	return src:sub(1, a - 1) .. new .. src:sub(b + 1)
end
local VS = game.ServerScriptService.Game.VehicleService
local s = VS.Source
if s:find("stowTools", 1, true) then return "already patched" end

s = replaceOnce(s, [[local function spawnVehicle(plr, cfg)
]], [[-- in a car your hands are on the wheel: the hammer goes to the backpack while you sit, and comes back when you get out
local function stowTools(seat)
	local hum, held, watch
	seat:GetPropertyChangedSignal("Occupant"):Connect(function()
		local h = seat.Occupant
		if h then
			hum = h
			local char = h.Parent
			held = char and char:FindFirstChildOfClass("Tool")
			if held then h:UnequipTools() end
			if watch then watch:Disconnect() end
			-- equipping it again while seated is undone
			watch = char and char.ChildAdded:Connect(function(c)
				if c:IsA("Tool") and seat.Occupant == h then
					held = c
					task.defer(function() if seat.Occupant == h then h:UnequipTools() end end)
				end
			end)
		else
			if watch then watch:Disconnect(); watch = nil end
			local h0, t = hum, held
			hum, held = nil, nil
			if h0 and t then
				task.delay(0.25, function()
					if h0.Parent and h0.Health > 0 and not h0.SeatPart and t.Parent and t.Parent:IsA("Backpack") then h0:EquipTool(t) end
				end)
			end
		end
	end)
end

local function spawnVehicle(plr, cfg)
]])

s = replaceOnce(s, [[	local seat = model:FindFirstChild("DriverSeat")
	-- OwnerTag hides while someone drives: the driver's own tags are right above it
	if seat then]], [[	local seat = model:FindFirstChild("DriverSeat")
	if seat then stowTools(seat) end
	for _, ps in ipairs(model:GetChildren()) do if ps:IsA("Seat") then stowTools(ps) end end
	-- OwnerTag hides while someone drives: the driver's own tags are right above it
	if seat then]])

assert(loadstring(s), "VehicleService compile")
VS.Source = s
return "vehicle tools patched"
