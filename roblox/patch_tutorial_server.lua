-- one-off patch (run in Edit): the tutorial = the first 6 Empire Road steps
--   1 take a job at the Job Board · 2 start building · 3 finish the first building · 4 Equipment Store (Pro Tools)
--   5 Hiring Office (first worker) · 6 NEW: walk to your own property
-- JOBS / SHOP / the contract bar unlock after step 6 (client). Saved road positions from before this patch move one
-- step on when they are past the new step, so nobody repeats or skips a goal. Also: BuiltIds (the buildings you have
-- built at least once) for the NEW dots on the Job Board.
local function replaceOnce(src, old, new)
	local a, b = src:find(old, 1, true)
	assert(a, "not found: " .. old:sub(1, 80))
	assert(not src:find(old, b + 1, true), "found twice: " .. old:sub(1, 80))
	return src:sub(1, a - 1) .. new .. src:sub(b + 1)
end

-- Config ------------------------------------------------------------------------------------------
local Cfg = game.ReplicatedStorage.Shared.Config
local c = Cfg.Source
if not c:find('stat = "VisitedHome"', 1, true) then
	c = replaceOnce(c, [[stat = "Workers", target = 1, place = "hire", cash = 150, gems = 5 },
]], [[stat = "Workers", target = 1, place = "hire", cash = 150, gems = 5 },
	{ title = "Visit your property", desc = "Your own lot is in Maple Grove, south of the town. Follow the arrow and walk to your property.", stat = "VisitedHome", target = 1, place = "home", cash = 150, gems = 5 },
]])
	c = replaceOnce(c, "Config.RoadTutorialSteps = 10", [[Config.RoadTutorialSteps = 11
-- the tutorial: JOBS, SHOP and the contract bar unlock once these first Empire Road steps are done
-- (Job Board, first building, Equipment Store, Hiring Office, your property)
Config.TutorialSteps = 6]])
	assert(loadstring(c), "Config compile")
end

-- Main --------------------------------------------------------------------------------------------
local Main = game.ServerScriptService.Game.Main
local s = Main.Source
if not s:find("VisitedHome", 1, true) then
	-- new profiles start on the new road numbering
	s = replaceOnce(s, "Spin = { last = 0, extra = 0 }, Codes = {} }", "Spin = { last = 0, extra = 0 }, Codes = {}, RoadV = 2 }")
	-- saved before the new step: a player past "Hire a worker" moves one on (same goal as before)
	s = replaceOnce(s, "	d.Road = math.max(1, math.floor(tonumber(d.Road) or 1))\n", [[	d.Road = math.max(1, math.floor(tonumber(d.Road) or 1))
	if type(raw) == "table" and raw.Road ~= nil and raw.RoadV == nil and d.Road >= 6 then d.Road += 1 end
	d.RoadV = 2
]])
	s = replaceOnce(s, [[	elseif stat:sub(1, 6) == "Built_" then return (d.Portfolio or {})[stat:sub(7)] or 0 end]],
		[[	elseif stat == "VisitedHome" then return s.home or 0
	elseif stat:sub(1, 6) == "Built_" then return (d.Portfolio or {})[stat:sub(7)] or 0 end]])
	-- the buildings you've built at least once (NEW dots on the Job Board until you build one)
	s = replaceOnce(s, [[	plr:SetAttribute("Completed", d.Completed)
]], [[	plr:SetAttribute("Completed", d.Completed)
	local built = {}
	for _, ct in ipairs(Config.Contracts) do if ((d.Portfolio or {})[ct.id] or 0) > 0 then table.insert(built, ct.id) end end
	plr:SetAttribute("BuiltIds", table.concat(built, ","))
]])
	-- "Visit your property": done when you walk onto your own lot
	s = replaceOnce(s, [[-- grants every achievement whose goal is reached (once each)
function checkAchievements(plr)]], [[-- Empire Road "Visit your property": done when you walk onto your own lot
task.spawn(function()
	while true do
		task.wait(1)
		for plr, st in pairs(S) do
			local step = st.data and Config.Road[st.data.Road]
			if step and step.stat == "VisitedHome" and plr:GetAttribute("Loaded") then
				local hrp = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
				local here = st.homeOrigin == nil -- no lot on this server: nothing to visit, don't get stuck
				if hrp and st.homeOrigin then
					local o = st.homeOrigin.Position
					local sign = st.lot and st.lot:FindFirstChild("OwnerSign")
					here = Vector3.new(hrp.Position.X - o.X, 0, hrp.Position.Z - o.Z).Magnitude < 45
						or (sign ~= nil and (hrp.Position - sign.Position).Magnitude < 22)
				end
				if here then
					st.data.Stats = st.data.Stats or {}
					st.data.Stats.home = 1
					roadCheck(plr)
					saveSoon(plr)
				end
			end
		end
	end
end)

-- grants every achievement whose goal is reached (once each)
function checkAchievements(plr)]])
	assert(loadstring(s), "Main compile")
end

Cfg.Source = c
Main.Source = s
return "tutorial server patched"
