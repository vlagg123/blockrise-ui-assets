-- one-off patch (run in Edit): the window title sits in the middle of the ribbon's face
-- (the ribbon has a 3D lip at the bottom and the title font draws its capitals high: the title looked stuck to the top)
local Client = game.StarterPlayer.StarterPlayerScripts.Client
local s = Client.Source
local old = [[	modalTitle.Position = UDim2.fromOffset(86, 7)]]
local a, b = s:find(old, 1, true)
if not a then return "already patched" end
assert(not s:find(old, b + 1, true), "found twice")
s = s:sub(1, a - 1) .. [[	modalTitle.Position = UDim2.fromOffset(86, 13) -- centred on the ribbon's face (above its 3D lip)]] .. s:sub(b + 1)
assert(loadstring(s), "compile Client")
Client.Source = s
return "title centred"
