-- one-off patch (run in Edit): a finished building comes down (animated demolition) as soon as
--  * you take your next contract, or
--  * you walk out of its site (after the 5 s celebration), or
--  * 18 s have passed (as before)
-- The next contract prefers another free site, so the new building never starts inside the one coming down.
local function replaceOnce(src, old, new)
	local a, b = src:find(old, 1, true)
	assert(a, "not found: " .. old:sub(1, 80))
	assert(not src:find(old, b + 1, true), "found twice: " .. old:sub(1, 80))
	return src:sub(1, a - 1) .. new .. src:sub(b + 1)
end
local Main = game.ServerScriptService.Game.Main
local s = Main.Source
if s:find("finishedClear", 1, true) then return "already patched" end

s = replaceOnce(s, [[	HitFXRE:FireAllClients(0, "celebrate", job:Center())
	if site then
		setSiteSign(site, "COMPLETED!\n" .. c.name:upper())
		task.delay(18, function()
			job:Destroy(true)
			site.job = nil
			setSiteSign(site, "SITE " .. site.index .. "\nAVAILABLE")
		end)
	else
		task.delay(18, function() job:Destroy(true) end)
	end
end]], [[	HitFXRE:FireAllClients(0, "celebrate", job:Center())
	-- the finished building comes down when you take your next job, when you walk out of its site, or after 18 s
	local function clear()
		if job._cleared then return end
		job._cleared = true
		job:Destroy(true)
		if site and site.job == job then
			site.job = nil
			setSiteSign(site, "SITE " .. site.index .. "\nAVAILABLE")
		end
	end
	if site then setSiteSign(site, "COMPLETED!\n" .. c.name:upper()) end
	if owner and S[owner] then
		S[owner].finishedClear = clear
		S[owner].finishedSite = site
	end
	task.delay(18, clear)
	task.spawn(function()
		local center = job.origin.Position
		local r = ((site and site.radius) or 30) + 8
		task.wait(5) -- the celebration and the camera fly-around first
		while not job._cleared do
			local hrp = owner and owner.Parent and owner.Character and owner.Character:FindFirstChild("HumanoidRootPart")
			if not hrp or ((hrp.Position - center) * Vector3.new(1, 0, 1)).Magnitude > r then
				clear()
				break
			end
			task.wait(0.4)
		end
	end)
end]])

s = replaceOnce(s, [[	if not contractUnlocked(st.data, c) then return false, lockReason(st.data, c) end
	local zone = c.zone or "town"
	local site
	for _, s in ipairs(sites) do if not s.job and s.zone == zone then site = s break end end]], [[	if not contractUnlocked(st.data, c) then return false, lockReason(st.data, c) end
	-- your finished building comes down as soon as you take the next job
	local cleared = st.finishedSite
	if st.finishedClear then
		local f = st.finishedClear
		st.finishedClear, st.finishedSite = nil, nil
		f()
	end
	local zone = c.zone or "town"
	local site
	-- another free site first, so the new building never starts inside the one coming down
	for _, s in ipairs(sites) do if not s.job and s.zone == zone and s ~= cleared then site = s break end end
	if not site and cleared and not cleared.job and cleared.zone == zone then site = cleared end]])

assert(loadstring(s), "Main compile")
Main.Source = s
return "demolish patched"
