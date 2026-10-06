-- one-off patch (run in Edit): the arrow on the edge of the screen (a place behind you / off screen) keeps clear of the
-- menu buttons on the left (it sat on top of REBIRTH / UPGRADES when the place was to your left)
local Client = game.StarterPlayer.StarterPlayerScripts.Client
local s = Client.Source
if s:find("NAV_EDGE_MARGIN", 1, true) then return "already patched" end
local old = [==[			local hx, hy = vs.X / 2 - 140, vs.Y / 2 - mg]==]
local a, b = s:find(old, 1, true)
assert(a and not s:find(old, b + 1, true), "edge margin line not found once")
s = s:sub(1, a - 1) .. [==[			-- NAV_EDGE_MARGIN: wider on the left, where the menu buttons are
			local hx, hy = math.max(60, vs.X / 2 - ((dx < 0) and 290 or 150) * uiScale.Scale), vs.Y / 2 - mg]==] .. s:sub(b + 1)
assert(loadstring(s), "compile Client")
Client.Source = s
return "nav edge margin"
