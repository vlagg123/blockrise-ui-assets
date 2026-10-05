-- one-off patch (run in Edit): the "building complete" camera flies around the FRONT of the building
-- (front = the side with the door, the origin's -Z / LookVector); the server sends it with every completion
local function replaceOnce(src, old, new)
	local a, b = src:find(old, 1, true)
	assert(a, "not found: " .. old:sub(1, 80))
	assert(not src:find(old, b + 1, true), "found twice: " .. old:sub(1, 80))
	return src:sub(1, a - 1) .. new .. src:sub(b + 1)
end

local Main = game.ServerScriptService.Game.Main
local m = Main.Source
if not m:find("front = job.origin.LookVector", 1, true) then
	m = replaceOnce(m, [[time = job.elapsed, target = c.targetTime, center = job:Center(), size = job.size, first = st.data.Portfolio[c.id] == 1 })]],
		[[time = job.elapsed, target = c.targetTime, center = job:Center(), size = job.size, first = st.data.Portfolio[c.id] == 1, front = job.origin.LookVector })]])
	m = replaceOnce(m, [[feedback(plr, "HomeComplete", { name = Config.HouseLevels[level].name, center = job:Center(), size = job.size })]],
		[[feedback(plr, "HomeComplete", { name = Config.HouseLevels[level].name, center = job:Center(), size = job.size, front = job.origin.LookVector })]])
	m = replaceOnce(m, [[feedback(plr, "HomeComplete", { name = cfg.name, center = job:Center(), size = job.size, ext = true, bonus = cfg.bonus })]],
		[[feedback(plr, "HomeComplete", { name = cfg.name, center = job:Center(), size = job.size, ext = true, bonus = cfg.bonus, front = job.origin.LookVector })]])
	m = replaceOnce(m, [[				center = job:Center(), size = job.size })]], [[				center = job:Center(), size = job.size, front = job.origin.LookVector })]])
	assert(loadstring(m), "Main compile")
end

local Client = game.StarterPlayer.StarterPlayerScripts.Client
local s = Client.Source
if not s:find("local sweep = math.pi * 0.85", 1, true) then
	s = replaceOnce(s, [[local function cinematic(center, size, done)]], [[local function cinematic(center, size, front, done)]])
	s = replaceOnce(s, [[	local dir = (startCF.Position - center) * Vector3.new(1, 0, 1)
	local a0 = (dir.Magnitude > 0.1) and math.atan2(dir.Z, dir.X) or 0]], [[	local dir = (startCF.Position - center) * Vector3.new(1, 0, 1)
	local a0 = (dir.Magnitude > 0.1) and math.atan2(dir.Z, dir.X) or 0
	local sweep = math.pi * 0.85
	if typeof(front) == "Vector3" and (front * Vector3.new(1, 0, 1)).Magnitude > 0.1 then
		-- the front stays in view the whole time: from front-left (63 deg) to a 3/4 front-right view (27 deg)
		a0 = math.atan2(front.Z, front.X) - math.pi * 0.35
		sweep = math.pi * 0.5
	end]])
	s = replaceOnce(s, [[		local a = a0 + ease * math.pi * 0.85]], [[		local a = a0 + ease * sweep]])
	local n
	s, n = s:gsub("cinematic%(d%.center, d%.size, ", "cinematic(d.center, d.size, d.front, ")
	assert(n == 3, "cinematic calls: " .. tostring(n))
	assert(loadstring(s), "Client compile")
end

Main.Source = m
Client.Source = s
return "cinematic patched"
