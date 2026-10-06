-- one-off patch (run in Edit): the Repair Fence's two flower pots stand OUTSIDE the fence, either side of the gate
-- (they were inside the yard, 2 studs behind the gate)
local B = game.ServerScriptService.Game.Blueprints
local s = B.Source
if s:find("-D / 2 - 2.6", 1, true) then return "already patched" end
local n
s, n = s:gsub("Vector3%.new%((%-?6), (%d%.%d), %-D / 2 %+ 2%)", "Vector3.new(%1, %2, -D / 2 - 2.6)")
assert(n == 4, "expected 4 planter parts, got " .. n)
assert(loadstring(s), "compile Blueprints")
B.Source = s
return "fence pots outside"
