-- one-off patch (run in Edit): pictures of everything sold for Robux (rendered in Blender, icons/robux.py).
-- Store, HUD effects, Admin panel and the Lucky Spin read them (old atlas icons stay as the fallback).
local Cfg = game.ReplicatedStorage.Shared.Config
local s = Cfg.Source
if s:find("Config.ProductImages", 1, true) then return "already patched" end
local a, b = s:find("\nreturn Config%s*$")
assert(a, "no 'return Config' at the end")
s = s:sub(1, a) .. [[
-- pictures of everything sold for Robux (game passes + developer products), by Store key
Config.ProductImages = {
	-- game passes
	skipanim = "rbxassetid://78669686174436", stormhammer = "rbxassetid://76633024269900", teleporter = "rbxassetid://82270262601428",
	vip = "rbxassetid://108353671163801", bigcrew = "rbxassetid://128289749463151", cash2x = "rbxassetid://107634628207210",
	strength2x = "rbxassetid://130345773671135", autobuild = "rbxassetid://94079543192839", autotrain = "rbxassetid://80906721173998",
	gems2x = "rbxassetid://72452064350021", fasttools = "rbxassetid://84953218203861", monster = "rbxassetid://133852132054346",
	goldcar = "rbxassetid://111149747210442",
	-- developer products
	starter = "rbxassetid://112868231776162", rushcrew = "rbxassetid://94687794098300", cashpack = "rbxassetid://102019256140950",
	cashstack = "rbxassetid://103357100990516", cashvault = "rbxassetid://93656024990997", cashbank = "rbxassetid://99237976529745",
	cashboost = "rbxassetid://79278732716652", spin1 = "rbxassetid://98074663629152", spins3 = "rbxassetid://81139063163544",
	gems100 = "rbxassetid://92552699421535", gems300 = "rbxassetid://88490060320126", gems750 = "rbxassetid://111934313191420",
	gems1700 = "rbxassetid://119672075623238", gems4500 = "rbxassetid://122779800900197", gems12000 = "rbxassetid://116606006788305",
}

return Config
]]
assert(loadstring(s), "Config compile")
Cfg.Source = s
return "product images patched"
