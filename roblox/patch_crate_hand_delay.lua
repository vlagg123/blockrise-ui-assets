-- one-off patch (run in Edit): a hammer from a crate goes into your hand (and the hotbar) only when the crate animation
-- ends. It showed up in the hotbar the moment you pressed OPEN, before the strip stopped, and spoiled the surprise.
-- (Quick Open shows the hammer at once, so it changes hands at once too.)
local HS = game:GetService("ServerScriptService").Game.HammerService
local s = HS.Source
if s:find("CRATE_HAND_DELAY", 1, true) then return "already patched" end
local old = [==[	if M.Equipped(d).id ~= handBefore then ctx.giveTool(plr) end]==]
local a, b = s:find(old, 1, true)
assert(a and not s:find(old, b + 1, true), "giveTool line not found once")
s = s:sub(1, a - 1) .. [==[	-- CRATE_HAND_DELAY: the Tool changes when the strip stops (3.6 s spin + 0.75 s) and the reveal card comes up
	if M.Equipped(d).id ~= handBefore then
		local quick = plr:GetAttribute("QuickOpen") == true
		task.delay(quick and 0.2 or 4.5, function()
			if plr.Parent and ctx.S[plr] == st then ctx.giveTool(plr) end
		end)
	end]==] .. s:sub(b + 1)
assert(loadstring(s), "compile HammerService")
HS.Source = s
return "crate hand delay"
