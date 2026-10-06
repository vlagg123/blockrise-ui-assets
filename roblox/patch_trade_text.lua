-- one-off patch (run in Edit): trade refusal text
local HS = game.ServerScriptService.Game.HammerService
local h = HS.Source
local old = [[if not it then return false, "not yours" end]]
local a, b = h:find(old, 1, true)
if not a then return "already patched" end
h = h:sub(1, a - 1) .. [[if not it then return false, "That hammer isn't yours" end]] .. h:sub(b + 1)
assert(loadstring(h))
HS.Source = h
return "trade text ok"
