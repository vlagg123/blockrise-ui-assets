-- BlockRise Empire - StarterPlayerScripts.SeatPose (LocalScript)
-- In a car your hands are on the wheel. The server puts the hammer away when you sit (VehicleService.stowTools), but
-- Roblox's Animate script stops updating tool poses while you are seated, so the "holding a tool" arm stayed up.
-- Here that pose is stopped once the hammer is gone. (Your own character's animations replicate to everyone.)
local Players = game:GetService("Players")
local player = Players.LocalPlayer

local TOOL_POSE = { ["507768375"] = true, ["182393478"] = true } -- R15 / R6 "toolnone"
local function isToolPose(t)
	if t.Name == "ToolNoneAnim" then return true end
	local id = t.Animation and t.Animation.AnimationId or ""
	return TOOL_POSE[id:match("%d+$") or ""] == true
end

local function hook(char)
	local hum = char:WaitForChild("Humanoid", 10)
	if not hum then return end
	local animator = hum:WaitForChild("Animator", 10)
	if not animator then return end
	hum.Seated:Connect(function(active)
		if not active then return end
		-- the server takes the hammer a moment after you sit: keep an eye on it for a couple of seconds
		for _ = 1, 14 do
			task.wait(0.15)
			if not hum.SeatPart or not char.Parent then return end
			if not char:FindFirstChildOfClass("Tool") then
				for _, t in ipairs(animator:GetPlayingAnimationTracks()) do
					if isToolPose(t) then t:Stop(0.2) end
				end
			end
		end
	end)
end

player.CharacterAdded:Connect(hook)
if player.Character then task.spawn(hook, player.Character) end
