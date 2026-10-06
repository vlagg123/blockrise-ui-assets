-- one-off patch (run in Edit): Roblox's own server restarts (maintenance) no longer put a 30-minute "NEW UPDATE!"
-- countdown on everyone's screen
--  * the notice shows in the last minute only, players still move to a new server 8 s before the restart
--  * a Roblox maintenance restart says SERVER RESTART (not NEW UPDATE!) and that nothing is lost
local function replaceOnce(src, old, new)
	local a, b = src:find(old, 1, true)
	assert(a, "not found: " .. old:sub(1, 80))
	assert(not src:find(old, b + 1, true), "found twice: " .. old:sub(1, 80))
	return src:sub(1, a - 1) .. new .. src:sub(b + 1)
end
local Main = game.ServerScriptService.Game.Main
local s = Main.Source
if s:find("UPDATE_NOTICE_LAST_MINUTE", 1, true) then return "already patched" end
s = replaceOnce(s, [[		game.ServerRestartScheduled:Connect(function(restartTime, source, attributes)
			local secs = restartTime.UnixTimestamp - DateTime.now().UnixTimestamp
			local msg = type(attributes) == "table" and attributes.message or nil
			if source == Enum.CloseReason.RobloxMaintenance then msg = msg or "Roblox server maintenance" end
			-- move players a little before the hard restart so nobody gets disconnected
			task.spawn(restartForUpdate, math.max(5, secs - 8), msg)
		end)]], [[		game.ServerRestartScheduled:Connect(function(restartTime, source, attributes)
			local msg = type(attributes) == "table" and attributes.message or nil
			if source == Enum.CloseReason.RobloxMaintenance then
				-- Roblox's own restart, not our update: nothing to worry about
				ReplicatedStorage:SetAttribute("UpdateTitle", "🔄 SERVER RESTART")
				msg = msg or "Roblox is restarting the servers: you'll move to a new one, your progress is saved"
			end
			-- UPDATE_NOTICE_LAST_MINUTE: the notice shows in the last minute only (a 30-minute countdown worried players
			-- for nothing); players move a little before the hard restart so nobody gets disconnected
			task.spawn(function()
				local function left() return restartTime.UnixTimestamp - DateTime.now().UnixTimestamp end
				local w = left() - 8 - 60
				if w > 0 then task.wait(w) end
				restartForUpdate(math.max(5, left() - 8), msg)
			end)
		end)]])
assert(loadstring(s), "Main compile")

local Client = game.StarterPlayer.StarterPlayerScripts.Client
local cs = Client.Source
cs = replaceOnce(cs, [[Text = "🔄 NEW UPDATE!", Font = T.title, TextSize = 34]], [[Text = RS:GetAttribute("UpdateTitle") or "🔄 NEW UPDATE!", Font = T.title, TextSize = 34]])
cs = replaceOnce(cs, [[banner("🔄 UPDATE COMING!", (d.message]], [[banner(RS:GetAttribute("UpdateTitle") or "🔄 UPDATE COMING!", (d.message]])
assert(#cs < 200000, "Client too long: " .. #cs)
assert(loadstring(cs), "Client compile")
Main.Source = s
Client.Source = cs
return "update notice patched, Client " .. #cs
