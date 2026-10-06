-- one-off patch (run in Edit): the white pill on the right of a window's title bar sits in the middle of the
-- ribbon's face, from its top edge down to the darker lip at the bottom (y 4..62 -> 33), not of the whole ribbon
local Client = game.StarterPlayer.StarterPlayerScripts.Client
local s = Client.Source
local old = [==[local subPill = UI.slice("pill", { Name = "SubPill", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -18, 0, 40),]==]
local new = [==[local subPill = UI.slice("pill", { Name = "SubPill", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -18, 0, 33),]==]
if s:find(new, 1, true) then return "already patched" end
local a, b = s:find(old, 1, true)
assert(a and not s:find(old, b + 1, true), "SubPill line not found once")
s = s:sub(1, a - 1) .. new .. s:sub(b + 1)
assert(loadstring(s), "compile Client")
Client.Source = s
return "subpill y 33"
