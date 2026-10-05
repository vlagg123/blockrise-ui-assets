-- one-off patch (run in Edit): the welcome / how-to-play window moves to MoreUI.HowTo (menu kit)
local Client = game.StarterPlayer.StarterPlayerScripts.Client
local s = Client.Source
local old = "local function showHowToPlay()\n"
local a, b = s:find(old, 1, true)
assert(a and not s:find(old, b + 1, true), "showHowToPlay not found")
s = s:sub(1, b) .. "\tif _G.__CE_MoreUI then return _G.__CE_MoreUI.HowTo() end\n" .. s:sub(b + 1)
Client.Source = s
return "howto wired"
