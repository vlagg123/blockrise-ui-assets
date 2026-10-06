-- one-off patch (run in Edit): the save when a player leaves always gets written
--
-- The bug: a player alone on a server leaves (or is kicked by the admin RESET) a few seconds after a save. The leave
-- save waits for the DataStore gap (6.5 s), but the server is empty now and shuts down at once: BindToClose only waited
-- for players still in the game, so the leave save never happened. The profile stayed locked by a server that no longer
-- exists, and the next join waited ~40 s (5 blocked tries) at LOADING 89% before taking it over; whatever changed
-- since the last save was lost.
-- The fix: BindToClose also waits for the saves of players who already left, the admin RESET releases the profile
-- before the kick, and the tutorial money loop skips players who are leaving.
local function replaceOnce(src, old, new, what)
	local a, b = src:find(old, 1, true)
	assert(a, "not found: " .. (what or old:sub(1, 80)))
	assert(not src:find(old, b + 1, true), "found twice: " .. (what or old:sub(1, 80)))
	return src:sub(1, a - 1) .. new .. src:sub(b + 1)
end
local Main = game:GetService("ServerScriptService").Game.Main
local m = Main.Source
if m:find("leavingSaves", 1, true) then return "already patched" end

m = replaceOnce(m, [==[Players.PlayerRemoving:Connect(function(plr)
	local st = S[plr]
	if not st then return end
	saveData(plr, true) -- save and release the profile for the next server
	S[plr] = nil]==], [==[-- saves of players who already left that are still being written (the server must not close before they are)
local leavingSaves = 0
Players.PlayerRemoving:Connect(function(plr)
	local st = S[plr]
	if not st then return end
	leavingSaves += 1
	pcall(saveData, plr, true) -- save and release the profile for the next server
	leavingSaves -= 1
	S[plr] = nil]==])

m = replaceOnce(m, [==[	local waited = 0
	while pending > 0 and waited < 25 do task.wait(0.25); waited += 0.25 end
end)]==], [==[	-- (and the saves of the players who just left: with the last one gone the server closes right away)
	local waited = 0
	while (pending > 0 or leavingSaves > 0) and waited < 25 do task.wait(0.25); waited += 0.25 end
end)]==])

m = replaceOnce(m, [==[		task.spawn(function()
			pcall(saveData, plr, false, true)
			task.wait(1.5)]==], [==[		task.spawn(function()
			-- saved AND released before the kick: the next server loads the fresh profile at once
			local ok, saved = pcall(saveData, plr, true, true)
			if ok and saved and S[plr] == st then st.released = true end
			task.wait(1.5)]==])

m = replaceOnce(m, [==[			if step and step.buy and st.data and plr:GetAttribute("Loaded") then]==],
	[==[			if step and step.buy and st.data and plr.Parent and plr:GetAttribute("Loaded") then]==])

assert(loadstring(m), "compile Main")
Main.Source = m
return "save on leave"
