-- one-off patch (applied in Edit): before any hammer action, a bag without the Rusty Hammer gets it back (Sanitize + Publish)
local HS = game.ServerScriptService.Game.HammerService
local s = HS.Source
if s:find("never without the Rusty", 1, true) then return "already patched" end
local old = [[		local fn = type(action) == "string" and actions[action]
		if not fn then return false, "Unknown action" end]]
local a, b = s:find(old, 1, true)
assert(a and not s:find(old, b + 1, true))
s = s:sub(1, a - 1) .. old .. [[

		-- never without the Rusty Hammer (whatever happened to the bag)
		if not find(st.data, "rusty") then M.Sanitize(st.data); M.Publish(plr) end]] .. s:sub(b + 1)
assert(loadstring(s))
HS.Source = s
return "rusty heal patched"
