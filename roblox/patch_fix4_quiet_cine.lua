-- FIX4 patch (run in Edit, 2026-10-14): no random site events in the tutorial; the build show always ends; the title
-- screen and the HUD's cinematic flag don't depend on frames being drawn
local SES = game:GetService("ScriptEditorService")
local function rep(out, old, new)
	local a = out:find(old, 1, true)
	if not a then error("missing: " .. old:sub(1, 100)) end
	if out:find(old, a + 1, true) then error("not unique: " .. old:sub(1, 100)) end
	return out:sub(1, a - 1) .. new .. out:sub(a + #old)
end
local jobs = {}
local function job(scr, fn)
	local out = fn(scr.Source)
	local f, err = loadstring(out)
	if not f then error(scr.Name .. " compile " .. tostring(err)) end
	table.insert(jobs, { scr, out })
end
local Cl = game.StarterPlayer.StarterPlayerScripts.Client

-- 1) Main: the random site events (tip, rush order, inspection) wait until the tutorial is done (one thing at a time:
--    two SAFETY INSPECTION banners came over the first fence)
job(game.ServerScriptService.Game.Main, function(out)
	if out:find("EVENTS_QUIET", 1, true) then error("already patched") end
	out = rep(out, [=[			if job and not job.done and not st.rush and now - (st.lastEvent or 0) > E.minGap and now - job.startTime > 25 and math.random() < E.chance then]=],
		[=[			-- (EVENTS_QUIET 2026-10-14: none during the tutorial)
			if job and not job.done and not st.rush and now - (st.lastEvent or 0) > E.minGap and now - job.startTime > 25 and math.random() < E.chance
				and not (Config.InTutorial and Config.InTutorial(st.data)) then]=])
	return out
end)

-- 2) Client: the build show ends on time even when no frame is drawn (a minimised window): the reward card comes;
--    the title screen's loading and the HUD's cinematic flag tick on Heartbeat
job(Cl, function(out)
	out = rep(out, [=[		if t >= 1 then finish() end
	end)
	if not tall then]=], [=[		if t >= 1 then finish() end
	end)
	task.delay(dur + 2, finish) -- (CINE_SAFE 2026-10-14: the show always ends, the card always comes)
	if not tall then]=])
	out = rep(out, [=[	local anim = RunService.RenderStepped:Connect(function(dt)]=], [=[	local anim = RunService.Heartbeat:Connect(function(dt) -- (CINE_SAFE: Heartbeat, not RenderStepped)]=])
	out = rep(out, [=[RunService.RenderStepped:Connect(function()
	if gui:GetAttribute("Cinematic") ~= inCinematic then gui:SetAttribute("Cinematic", inCinematic) end]=], [=[RunService.Heartbeat:Connect(function() -- (CINE_SAFE: Heartbeat, not RenderStepped)
	if gui:GetAttribute("Cinematic") ~= inCinematic then gui:SetAttribute("Cinematic", inCinematic) end]=])
	return out
end)

for _, j in ipairs(jobs) do
	local scr, src = j[1], j[2]
	task.spawn(function() SES:UpdateSourceAsync(scr, function() return src end) end)
end
for i = 1, 25 do
	task.wait(2)
	local all = true
	for _, j in ipairs(jobs) do if j[1].Source ~= j[2] then all = false end end
	if all then return "applied " .. i * 2 .. "s" end
end
return "pending"
