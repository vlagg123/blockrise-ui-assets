-- one-off patch (run in Edit): the pill on the right of every window's title bar ($ money, ★ 0, "18 free sites"...)
-- sits on the same line as the title (its centre was 8 px above the title's)
local Client = game.StarterPlayer.StarterPlayerScripts.Client
local s = Client.Source
local old = [==[local subPill = UI.slice("pill", { Name = "SubPill", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -18, 0, 31),]==]
if not s:find(old, 1, true) then return "already patched" end
local a, b = s:find(old, 1, true)
assert(not s:find(old, b + 1, true), "found twice")
s = s:sub(1, a - 1) .. [==[local subPill = UI.slice("pill", { Name = "SubPill", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -18, 0, 40),]==] .. s:sub(b + 1)
assert(loadstring(s), "compile Client")
Client.Source = s
return "sub pill centred"
