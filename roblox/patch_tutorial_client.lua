-- one-off patch (run in Edit): tutorial flow in the main Client script
--  * after your first building the arrow never points back to the Job Board (JOBS opens the board from anywhere)
--  * tutorial hints for the Equipment Store, the Hiring Office and your property
--  * "NEXT STEP" on the first completed contract leads to the next tutorial place
--  * TUTORIAL COMPLETE at the end of the tutorial (step 6), not at step 10
local function replaceOnce(src, old, new)
	local a, b = src:find(old, 1, true)
	assert(a, "not found: " .. old:sub(1, 80))
	assert(not src:find(old, b + 1, true), "found twice: " .. old:sub(1, 80))
	return src:sub(1, a - 1) .. new .. src:sub(b + 1)
end
local Client = game.StarterPlayer.StarterPlayerScripts.Client
local s = Client.Source
if s:find("TUTORIAL_PATCHED", 1, true) then return "already patched" end

-- 1) guidance: the Job Board only before your first building
s = replaceOnce(s, [[		if step and ri <= Config.RoadTutorialSteps and step.place and step.place ~= "site" then]],
	[[		-- TUTORIAL_PATCHED: after the first building the arrow never points back to the Job Board
		if step and ri <= Config.RoadTutorialSteps and step.place and step.place ~= "site" and not (step.place == "board" and completed >= 1) then]])

-- 2) hints for the walking part of the tutorial
s = replaceOnce(s, [[	elseif not cj and completed >= 1 and completed < 3 and (player:GetAttribute("ToolTier") or 1) == 1]],
	[[	elseif not cj and completed >= 1 and (player:GetAttribute("RoadStep") or 1) <= (Config.TutorialSteps or 6)
		and Config.Road[player:GetAttribute("RoadStep") or 1] and Config.Road[player:GetAttribute("RoadStep") or 1].place ~= "site" then
		local tp = Config.Road[player:GetAttribute("RoadStep") or 1].place
		h = tp == "shop" and "🛠️ Walk to the EQUIPMENT STORE and buy Pro Tools — follow the arrow"
			or tp == "hire" and "👷 Walk to the HIRING OFFICE and hire your first worker — follow the arrow"
			or tp == "home" and "🏠 Walk to YOUR PROPERTY in Maple Grove — follow the arrow"
			or ""
	elseif not cj and completed >= 1 and completed < 3 and (player:GetAttribute("ToolTier") or 1) == 1]])

-- 3) the button on the "project complete" card: next tutorial place, or the Job Board window
s = replaceOnce(s, [[			{ "NEXT JOB", T.accent, T.accent2, function() setWaypoint("board") end },]],
	[[			(function()
				local ri = player:GetAttribute("RoadStep") or 1
				local tstep = Config.Road[ri]
				if ri <= (Config.TutorialSteps or 6) and tstep and tstep.place and tstep.place ~= "site" and tstep.place ~= "board" then
					return { "NEXT STEP", T.accent, T.accent2, function() if not waypoint then setWaypoint(tstep.place) end end }
				end
				return { "NEXT JOB", T.accent, T.accent2, function()
					if _G.__CE_ShowContracts then _G.__CE_Toggle("Contracts", _G.__CE_ShowContracts) else setWaypoint("board") end
				end }
			end)(),]])

-- 4) tutorial complete banner at the end of the tutorial
s = replaceOnce(s, [[		local tutorial = d.index <= Config.RoadTutorialSteps]], [[		local tutorial = d.index <= (Config.TutorialSteps or 6)]])
s = replaceOnce(s, [[		if d.index == Config.RoadTutorialSteps then
			task.delay(3, function() banner("🎓 TUTORIAL COMPLETE!", "The Empire Road continues — check the bar at the top", T.accent) end)]],
	[[		if d.index == (Config.TutorialSteps or 6) then
			task.delay(3, function() banner("🎓 TUTORIAL COMPLETE!", "JOBS and SHOP are unlocked — open them from anywhere!", T.accent) end)]])

-- 5) the old side menu's Jobs button follows the same lock
s = replaceOnce(s, [[	if (player:GetAttribute("Completed") or 0) >= 1 and _G.__CE_ShowContracts then
		_G.__CE_Toggle("Contracts", _G.__CE_ShowContracts)
	else
		setWaypoint("board")
	end
end)]], [[	if (player:GetAttribute("RoadStep") or 1) <= (Config.TutorialSteps or 6) then
		if (player:GetAttribute("Completed") or 0) == 0 then setWaypoint("board") else toast("🔒 Complete the tutorial first — follow the arrow!", T.muted, 2.5) end
	elseif _G.__CE_ShowContracts then
		_G.__CE_Toggle("Contracts", _G.__CE_ShowContracts)
	else
		setWaypoint("board")
	end
end)]])

assert(loadstring(s), "Client compile")
Client.Source = s
return "tutorial client patched"
