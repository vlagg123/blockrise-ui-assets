-- one-off patch (run in Edit): the hammer swings on EVERY hit, also when you spam-click
--  * our own slash animation track, restarted on each hit and sped up to fit the tool's cooldown (the default
--    "toolanim" slash ignores a new hit while the previous one is still playing, so fast clicks looked like misses)
--  * a click that comes a little too early is kept and swings the moment the tool is ready (spam = steady rhythm)
local function replaceOnce(src, old, new)
	local a, b = src:find(old, 1, true)
	assert(a, "not found: " .. old:sub(1, 80))
	assert(not src:find(old, b + 1, true), "found twice: " .. old:sub(1, 80))
	return src:sub(1, a - 1) .. new .. src:sub(b + 1)
end
local Client = game.StarterPlayer.StarterPlayerScripts.Client
local s = Client.Source
if s:find("SWING_TRACK", 1, true) then return "already patched" end

s = replaceOnce(s, [[local function doHit()
	local tool = myTool()
	if not tool then return end
	local tier = player:GetAttribute("ToolTier") or 1
	local cd = Config.Tools[tier].cooldown * (player:GetAttribute("Pass_fasttools") and Config.FastToolsPass or 1)
	local now = os.clock()
	if now - lastHit < cd then return end
	lastHit = now
	local sv = Instance.new("StringValue")
	sv.Name = "toolanim"; sv.Value = "Slash"; sv.Parent = tool
	Debris:AddItem(sv, 0.4)
	R.Work:FireServer()
end]], [[-- SWING_TRACK: our own slash animation, restarted on every hit
local SLASH_R15, SLASH_R6 = "rbxassetid://522635514", "rbxassetid://129967478"
local swingTrack, swingHum
local function toolCooldown()
	local tier = player:GetAttribute("ToolTier") or 1
	return (Config.Tools[tier] or Config.Tools[1]).cooldown * (player:GetAttribute("Pass_fasttools") and Config.FastToolsPass or 1)
end
local function swing(cd)
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not hum then return end
	if swingHum ~= hum or not swingTrack then
		swingHum = hum
		local animator = hum:FindFirstChildOfClass("Animator") or Instance.new("Animator", hum)
		local anim = Instance.new("Animation")
		anim.AnimationId = hum.RigType == Enum.HumanoidRigType.R6 and SLASH_R6 or SLASH_R15
		local ok, tr = pcall(function() return animator:LoadAnimation(anim) end)
		swingTrack = ok and tr or nil
		if swingTrack then
			swingTrack.Priority = Enum.AnimationPriority.Action2
			swingTrack.Looped = false
		end
	end
	if not swingTrack then return end
	swingTrack:Stop(0)
	swingTrack:Play(0.04)
	local len = swingTrack.Length > 0 and swingTrack.Length or 0.6
	-- the whole swing fits in one cooldown, so the next hit always starts a fresh swing
	swingTrack:AdjustSpeed(math.clamp(len / math.max((cd or 0.4) * 0.95, 0.15), 1, 3.5))
end
local hitQueued = false
local function doHit()
	local tool = myTool()
	if not tool then return end
	local cd = toolCooldown()
	local now = os.clock()
	if now - lastHit < cd then
		-- a bit too early: keep the click and swing the moment the tool is ready
		if not hitQueued then
			hitQueued = true
			task.delay(cd - (now - lastHit) + 0.01, function()
				hitQueued = false
				doHit()
			end)
		end
		return
	end
	lastHit = now
	swing(cd)
	R.Work:FireServer()
end]])

-- auto hits (Auto Build / Auto Train passes) swing the same way
local autoOld = [[			local tool = myTool()
			if tool then
				local sv = Instance.new("StringValue")
				sv.Name = "toolanim"; sv.Value = "Slash"; sv.Parent = tool
				Debris:AddItem(sv, 0.4)
			end]]
local n
s, n = s:gsub(autoOld:gsub("%p", "%%%0"), (([[			if myTool() then swing(toolCooldown()) end]]):gsub("%%", "%%%%")))
assert(n == 2, "auto swing blocks: " .. tostring(n))

assert(loadstring(s), "Client compile")
Client.Source = s
return "swing patched"
