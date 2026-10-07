-- BlockRise Empire - every hammer swings its own way (client). The arm (and the waist, and the hammer in the hand) are
-- moved by code on every client: yours when you hit, everyone else's when the server says they hit (HitFX), so all
-- players see the same swing without any animation asset.
--   chop    the classic: up, down onto the work
--   smash   heavy heads: a big wind-up leaning back, then a slam that bends the body forward
--   double  light, quick tools: two fast taps in one hit
--   twirl   playful ones: a chop while the hammer spins once around its handle
--   sweep   creatures and elements: a wide swing from the side
--   rise    magic ones: an uppercut that ends high, then down onto the work
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local M = {}
local player = Players.LocalPlayer

local STYLE = {
	-- the first 16
	rusty = "chop", iron = "chop", steel = "chop", gold = "double", titanium = "smash", emerald = "chop", ruby = "chop", sapphire = "smash",
	amethyst = "twirl", lava = "smash", frost = "sweep", diamond = "chop", plasma = "twirl", solar = "rise", galaxy = "rise", thunder = "smash",
	-- the 24 new ones
	mallet = "chop", brick = "smash", claw = "double", copper = "double", neon = "double", toolbox = "smash", bronze = "smash",
	obsidian = "smash", jade = "rise", candy = "twirl", dragon = "sweep", clockwork = "twirl", robo = "twirl", phoenix = "sweep",
	tsunami = "sweep", cyber = "double", void = "rise", blackhole = "smash", demon = "smash", celestial = "rise", crown = "twirl",
	ghost = "rise", prism = "twirl", founder = "smash",
}
M.STYLE = STYLE

-- keyframes: { t (0..1), arm pitch, arm yaw, arm roll, waist pitch, hammer spin, waist turn } in degrees (pitch +: the
-- arm goes up / the body leans back; yaw +: the arm swings across to the left; turn +: the chest turns left)
local KEYS = {
	chop = { { 0, 0, 0, 0, 0, 0 }, { 0.38, 62, 8, 0, 4, 0 }, { 0.62, -38, -4, 0, -6, 0 }, { 1, 0, 0, 0, 0, 0 } },
	smash = { { 0, 0, 0, 0, 0, 0 }, { 0.42, 105, 4, 0, 12, 0 }, { 0.66, -52, -2, 0, -16, 0 }, { 0.82, -40, 0, 0, -12, 0 }, { 1, 0, 0, 0, 0, 0 } },
	double = { { 0, 0, 0, 0, 0, 0 }, { 0.2, 42, 6, 0, 2, 0 }, { 0.4, -30, 0, 0, -4, 0 }, { 0.6, 40, 6, 0, 2, 0 }, { 0.8, -32, 0, 0, -4, 0 }, { 1, 0, 0, 0, 0, 0 } },
	twirl = { { 0, 0, 0, 0, 0, 0 }, { 0.38, 58, 10, 0, 4, 180 }, { 0.64, -36, -4, 0, -6, 360 }, { 1, 0, 0, 0, 0, 360 } },
	-- (a forehand: pulled out to the right, then across the front)
	sweep = { { 0, 0, 0, 0, 0, 0, 0 }, { 0.35, 30, -62, -24, 2, 0, -16 }, { 0.68, -16, 38, 10, -4, 0, 14 }, { 1, 0, 0, 0, 0, 0, 0 } },
	rise = { { 0, 0, 0, 0, 0, 0 }, { 0.25, -30, 0, 0, -4, 0 }, { 0.5, 95, 0, 0, 10, 0 }, { 0.72, -40, 0, 0, -8, 0 }, { 1, 0, 0, 0, 0, 0 } },
}
M.KEYS = KEYS

local function smooth(a) return a * a * (3 - 2 * a) end

local function sample(kf, t)
	for i = 1, #kf - 1 do
		local a, b = kf[i], kf[i + 1]
		if t <= b[1] then
			local u = smooth(math.clamp((t - a[1]) / math.max(1e-3, b[1] - a[1]), 0, 1))
			local r = {}
			for j = 2, 7 do r[j] = (a[j] or 0) + ((b[j] or 0) - (a[j] or 0)) * u end
			return r
		end
	end
	local l = kf[#kf]
	return { nil, l[2], l[3], l[4], l[5], l[6], l[7] or 0 }
end
M.sample = sample

-- the joints of a character: Motor6Ds, or the AnimationConstraints of the new avatar joints (their C0 cannot be
-- written). Both have a Transform that the Animator sets every frame; the swing turns it a bit more right after
-- (PreSimulation), in the joint's own frame, so it adds to whatever pose the character is in and nothing has to be
-- put back
local function joint(m)
	return m and (m:IsA("Motor6D") or m:IsA("AnimationConstraint")) and m or nil
end
local function joints(char)
	local ua = char:FindFirstChild("RightUpperArm")
	if ua then
		local ut = char:FindFirstChild("UpperTorso")
		return joint(ua:FindFirstChild("RightShoulder")), joint(ut and ut:FindFirstChild("Waist")), false
	end
	local torso = char:FindFirstChild("Torso")
	return joint(torso and torso:FindFirstChild("Right Shoulder")), nil, true
end

-- one joint: turn its Transform by `rot` this frame (if nothing set it since our last turn, start from the pose before
-- it, so it never adds up)
local function drive(j, st, rot)
	local cur = j.Transform
	if st.wrote and cur == st.wrote then cur = st.pre end
	st.pre = cur
	st.wrote = rot * cur
	j.Transform = st.wrote
end
local function release(j, st)
	if j and st.wrote and j.Parent and j.Transform == st.wrote then j.Transform = st.pre end
end

-- the turn of the arm for one frame of the swing (R6 shoulders are turned 90 degrees: their pitch is about Z)
local function armRot(v, r6)
	local pitch, yaw, roll = math.rad(v[2]), math.rad(v[3]), math.rad(v[4])
	if r6 then return CFrame.Angles(-roll, yaw, pitch) end
	return CFrame.Angles(pitch, yaw, roll)
end
M.armRot = armRot

local playing = setmetatable({}, { __mode = "k" }) -- [character] = the swing in progress (a newer one stops it)

-- play the swing of the hammer `key` on `char`, `dur` seconds long
function M.Play(char, key, dur)
	if not char or not char.Parent then return false end
	local hum = char:FindFirstChildOfClass("Humanoid")
	if not hum or hum.Health <= 0 or hum.SeatPart then return false end
	local shoulder, waist, r6 = joints(char)
	if not shoulder then return false end
	local tool = char:FindFirstChildOfClass("Tool")
	local kf = KEYS[STYLE[key or ""] or "chop"] or KEYS.chop
	dur = math.clamp(dur or 0.38, 0.16, 0.7)
	local me = {}
	playing[char] = me
	local grip0 = tool and (tool:GetAttribute("BaseGrip") or tool.Grip)
	if tool and not tool:GetAttribute("BaseGrip") then tool:SetAttribute("BaseGrip", tool.Grip) end
	local sSh, sWa = {}, {}
	local t0 = os.clock()
	local conn
	local function stop()
		conn:Disconnect()
		release(shoulder, sSh)
		release(waist, sWa)
		if tool and grip0 and tool.Parent then tool.Grip = grip0 end
	end
	conn = RunService.PreSimulation:Connect(function()
		if playing[char] ~= me or not shoulder.Parent then return stop() end
		local t = (os.clock() - t0) / dur
		if t >= 1 then
			playing[char] = nil
			return stop()
		end
		local v = sample(kf, t)
		drive(shoulder, sSh, armRot(v, r6))
		if waist and (v[5] ~= 0 or v[7] ~= 0) then drive(waist, sWa, CFrame.Angles(math.rad(v[5]), math.rad(v[7]), 0)) end
		if tool and grip0 and v[6] ~= 0 and tool.Parent == char then tool.Grip = grip0 * CFrame.Angles(0, math.rad(v[6]), 0) end
	end)
	return true
end

function M.Init(c)
	-- your own hits (Client SW.swing asks first): the swing of the hammer in your hand
	_G.__CE_Swing = function(char, cd)
		return M.Play(char, player:GetAttribute("EquipKey"), (cd or 0.4) * 0.95)
	end
	-- everyone else's hits: the server tells every client who hit
	local H = require(RS.Shared:WaitForChild("Hammers"))
	local rf = RS:WaitForChild("Remotes"):WaitForChild("HitFX")
	local last = {}
	rf.OnClientEvent:Connect(function(uid, verb)
		if type(uid) ~= "number" or uid <= 0 or uid == player.UserId or verb == "celebrate" or verb == "batch" then return end
		local p = Players:GetPlayerByUserId(uid)
		local char = p and p.Character
		local root = char and char:FindFirstChild("HumanoidRootPart")
		local cam = workspace.CurrentCamera
		if not root or not cam or (root.Position - cam.CFrame.Position).Magnitude > 150 then return end
		-- (one swing per hit, never faster than that player's hammer allows)
		local r = H.Rarities[p:GetAttribute("EquipRarity") or 1] or H.Rarities[1]
		local cd = r.cooldown or 0.4
		if os.clock() - (last[uid] or 0) < cd * 0.6 then return end
		last[uid] = os.clock()
		M.Play(char, p:GetAttribute("EquipKey"), cd * 0.95)
	end)
	Players.PlayerRemoving:Connect(function(p) last[p.UserId] = nil end)
end

return M
