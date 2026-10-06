-- one-off patch (run in Edit, after patch_tutorial_v4b): the "Get stronger" step points at the TIRE FLIP (the station
-- a new builder can use) instead of the yard's gate: inside the yard the arrow used to vanish, and the Beam Lift next to
-- the gate needs 3,000 Strength
local function replaceOnce(src, old, new, what)
	local a, b = src:find(old, 1, true)
	assert(a, "not found: " .. (what or old:sub(1, 80)))
	assert(not src:find(old, b + 1, true), "found twice: " .. (what or old:sub(1, 80)))
	return src:sub(1, a - 1) .. new .. src:sub(b + 1)
end
local ConfigM = game:GetService("ReplicatedStorage").Shared.Config
local Client = game.StarterPlayer.StarterPlayerScripts.Client
if ConfigM.Source:find('place = "tires"', 1, true) then return "already patched" end

local cfg = replaceOnce(ConfigM.Source,
	[==[desc = "Go into the TRAINING YARD, stand on a station and click to train. Do 10 reps!", stat = "TrainReps", target = 10, place = "gym",]==],
	[==[desc = "Go into the TRAINING YARD, stand on the TIRE FLIP and click to train. Do 10 reps!", stat = "TrainReps", target = 10, place = "tires",]==])
assert(loadstring(cfg), "compile Config")

local s = Client.Source
s = replaceOnce(s, [==[	if name == "gearshop" then return at("TrainingShop") or Vector3.new(-204, 3, 196) end]==], [==[	if name == "gearshop" then return at("TrainingShop") or Vector3.new(-204, 3, 196) end
	if name == "tires" then
		local y = Map:FindFirstChild("TrainingYard")
		local st = y and y:FindFirstChild("Station_tires")
		return (st and st:GetPivot().Position) or Vector3.new(-238, 3, 234)
	end]==])
s = replaceOnce(s, [==[gearshop = "Training Shop", machines = "Machines Depot",]==], [==[gearshop = "Training Shop", machines = "Machines Depot", tires = "Tire Flip",]==])
s = replaceOnce(s, [==[			or tp == "gym" and "💪 Go into the TRAINING YARD, stand on a station and click to train"]==],
	[==[			or tp == "tires" and "💪 Stand on the TIRE FLIP in the Training Yard and click to train"]==])
assert(loadstring(s), "compile Client")

ConfigM.Source = cfg
Client.Source = s
return "tutorial v4c"
