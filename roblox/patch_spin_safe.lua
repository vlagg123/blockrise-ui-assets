-- one-off patch (run in Edit): the Lucky Spin can never lose a prize, and no spin / crate starts while an update moves
-- everyone to the new version
--  * Main, Lucky Spin: the prize still lands when the reel stops on the screen (4.4 s, no spoiler in the money
--    counter), but it no longer needs the player to still be here: a save (leaving, the update restart, the autosave)
--    gives a prize that is on its way first, so it is always in the saved data
--  * Main, Lucky Spin + HammerService, crates: in the last 12 s before an update restart (UpdateAt) nothing new starts:
--    "An update is starting - ... in the new server"
local function replaceOnce(src, old, new)
	local a, b = src:find(old, 1, true)
	assert(a, "not found: " .. old:sub(1, 80))
	assert(not src:find(old, b + 1, true), "found twice: " .. old:sub(1, 80))
	return src:sub(1, a - 1) .. new .. src:sub(b + 1)
end
local report = {}

local Main = game.ServerScriptService.Game.Main
local s = Main.Source
if not s:find("spinPending", 1, true) then
	-- the save gives a prize that is still on its way
	s = replaceOnce(s, [[local function writeData(plr, release)
	local st = S[plr]
	if not st or not store or not st.loaded then return false end]], [[local function writeData(plr, release)
	local st = S[plr]
	if not st or not store or not st.loaded then return false end
	-- a Lucky Spin prize still on its way (the reel turns 4.4 s) is given now: it is in this save, whatever happens next
	if st.spinPending and st.spinPending.give then st.spinPending.give() end]])
	-- the spin: no new one right before an update; the prize goes through spinPending
	s = replaceOnce(s, [[		if action ~= "spin" then return false, "Unknown action" end
		if os.clock() - (st.lastSpin or 0) < 4.6 then return false, "Wait for the reel to stop" end]], [[		if action ~= "spin" then return false, "Unknown action" end
		local updateAt = ReplicatedStorage:GetAttribute("UpdateAt")
		if restarting or (updateAt and workspace:GetServerTimeNow() > updateAt - 12) then return false, "An update is starting - spin again in the new server" end
		if os.clock() - (st.lastSpin or 0) < 4.6 then return false, "Wait for the reel to stop" end]])
	s = replaceOnce(s, [[		-- the prize lands when the reel stops on the player's screen (no spoiler in the money counter)
		task.delay(4.4, function()
			if S[plr] == st then grant(plr, st, p, cash) end
		end)]], [[		-- the prize lands when the reel stops on the player's screen (no spoiler in the money counter); a save before
		-- that (leaving, an update restart) gives it at once, so a spin is never lost
		local pend = { done = false }
		pend.give = function()
			if pend.done then return end
			pend.done = true
			if st.spinPending == pend then st.spinPending = nil end
			local okG, errG = pcall(grant, plr, st, p, cash)
			if not okG then warn("Lucky Spin grant:", errG) end
		end
		if st.spinPending and st.spinPending.give then st.spinPending.give() end -- (never two on the way)
		st.spinPending = pend
		task.delay(4.4, pend.give)]])
	assert(loadstring(s), "Main compile")
	Main.Source = s
	table.insert(report, "Main: spin safe (" .. #s .. ")")
else
	table.insert(report, "Main: already")
end

local HS = game.ServerScriptService.Game.HammerService
local h = HS.Source
if not h:find("An update is starting", 1, true) then
	h = replaceOnce(h, [[		local fn = type(action) == "string" and actions[action]
		if not fn then return false, "Unknown action" end
		-- never without the Rusty Hammer (whatever happened to the bag)]], [[		local fn = type(action) == "string" and actions[action]
		if not fn then return false, "Unknown action" end
		-- right before an update restart no crate is bought or opened (it would land in the new server)
		if action == "open" or action == "buy" or action == "shopbuy" then
			local updateAt = ReplicatedStorage:GetAttribute("UpdateAt")
			if updateAt and workspace:GetServerTimeNow() > updateAt - 12 then return false, "An update is starting - open it in the new server" end
		end
		-- never without the Rusty Hammer (whatever happened to the bag)]])
	assert(loadstring(h), "HammerService compile")
	HS.Source = h
	table.insert(report, "HammerService: update lock (" .. #h .. ")")
else
	table.insert(report, "HammerService: already")
end
return table.concat(report, " · ")
