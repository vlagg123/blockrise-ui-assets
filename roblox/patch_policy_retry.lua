-- one-off patch (run in Edit): Roblox's policy answer for a player (PolicyService) is asked again when it fails
-- (up to 4 times, 3 / 6 / 9 s apart) instead of once: a hiccup no longer leaves a player treated as "no paid random
-- items" (X-ray crates, no paid spins) or "no trading" for the whole session. Until an answer comes the safe side
-- stays on (as before).
local function replaceOnce(src, old, new)
	local a, b = src:find(old, 1, true)
	assert(a, "not found: " .. old:sub(1, 80))
	assert(not src:find(old, b + 1, true), "found twice: " .. old:sub(1, 80))
	return src:sub(1, a - 1) .. new .. src:sub(b + 1)
end
local Main = game.ServerScriptService.Game.Main
local s = Main.Source
if s:find("POLICY_RETRY", 1, true) then return "Main: already" end
s = replaceOnce(s, [=[	task.spawn(function()
		local ok, info = pcall(function() return PolicyService:GetPolicyInfoForPlayerAsync(plr) end)
		if S[plr] == st then]=], [=[	task.spawn(function()
		-- POLICY_RETRY: asked again when it fails (a hiccup must not decide the whole session)
		local ok, info
		for attempt = 1, 4 do
			ok, info = pcall(function() return PolicyService:GetPolicyInfoForPlayerAsync(plr) end)
			if (ok and type(info) == "table") or S[plr] ~= st or not plr.Parent then break end
			task.wait(attempt * 3)
		end
		ok = ok and type(info) == "table"
		if S[plr] == st then]=])
local f, err = loadstring(s)
assert(f, "Main compile: " .. tostring(err))
Main.Source = s
return "Main: the policy answer is asked again when it fails"
