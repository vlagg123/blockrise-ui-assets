-- one-off patch (run in Edit): trade-ups stop at Divine (Hammers.LadderTop); the 9th rarity, Exclusive, is only shown
local HS = game.ServerScriptService.Game.HammerService
local s = HS.Source
if s:find("Hammers.LadderTop", 1, true) then return "already patched" end
local old = [[if r < 1 or r >= #Hammers.Rarities then return false, "Pick a rarity below Divine" end]]
local a, b = s:find(old, 1, true)
assert(a and not s:find(old, b + 1, true), "tradeup guard not found once")
s = s:sub(1, a - 1) .. [[if r < 1 or r >= (Hammers.LadderTop or #Hammers.Rarities) then return false, "Pick a rarity below Divine" end]] .. s:sub(b + 1)
assert(loadstring(s), "compile HammerService")
HS.Source = s
return "exclusive server: trade-up guard"
