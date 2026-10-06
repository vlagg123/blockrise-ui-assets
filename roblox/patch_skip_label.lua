-- one-off patch (run in Edit): the owners' SKIP button says SKIP ANIMATION (the ▶▶ glyph is not in the game font)
local Client = game.StarterPlayer.StarterPlayerScripts.Client
local s = Client.Source
local old = [[b = UI.button("SKIP  ▶▶", T.blue, T.blue2,]]
local a, b = s:find(old, 1, true)
if not a then return "already patched" end
s = s:sub(1, a - 1) .. [[b = UI.button("SKIP ANIMATION", T.blue, T.blue2,]] .. s:sub(b + 1)
s = s:gsub('Size = UDim2.fromOffset%(190, 60%),\n(%s+)TextSize = 24, Parent = skipGui', 'Size = UDim2.fromOffset(240, 60),\n%1TextSize = 22, Parent = skipGui', 1)
assert(loadstring(s), "compile Client")
Client.Source = s
return "skip label"
