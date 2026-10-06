-- one-off patch (run in Edit): the window backdrop goes under the HUD menu (HUD2 is raised to z 20 in HUD.lua):
-- with a window open, pressing another menu button opens that window instead of only closing the open one
local Client = game.StarterPlayer.StarterPlayerScripts.Client
local s = Client.Source
local old = [[AutoButtonColor = false, Visible = false, ZIndex = 20, Parent = gui }))]]
local a, b = s:find(old, 1, true)
if not a then return "already patched?" end
assert(not s:find(old, b + 1, true), "found twice")
assert(s:sub(math.max(1, a - 200), a):find("local modalBg", 1, true), "not the backdrop line")
s = s:sub(1, a - 1) .. [[AutoButtonColor = false, Visible = false, ZIndex = 19, Parent = gui }))]] .. s:sub(b + 1)
assert(loadstring(s), "compile")
Client.Source = s
return "backdrop z 19"
