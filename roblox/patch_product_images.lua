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
	skipanim = "rbxassetid://99386809391072", stormhammer = "rbxassetid://123844524251149", teleporter = "rbxassetid://82270262601428",
	vip = "rbxassetid://123085255342882", bigcrew = "rbxassetid://117730905386260", cash2x = "rbxassetid://72451815226274",
	strength2x = "rbxassetid://113468068025161", autobuild = "rbxassetid://80064504819514", autotrain = "rbxassetid://115326401206641",
	gems2x = "rbxassetid://129916717673380", fasttools = "rbxassetid://134605171184897", monster = "rbxassetid://133852132054346",
	goldcar = "rbxassetid://111149747210442",
	-- developer products
	starter = "rbxassetid://126109143002031", rushcrew = "rbxassetid://119140570305000", cashpack = "rbxassetid://84828084771225",
	cashstack = "rbxassetid://123590091399618", cashvault = "rbxassetid://90790339412602", cashbank = "rbxassetid://99946262610902",
	cashboost = "rbxassetid://118539020758858", spin1 = "rbxassetid://98074663629152", spins3 = "rbxassetid://104220772987659",
	gems100 = "rbxassetid://92552699421535", gems300 = "rbxassetid://88490060320126", gems750 = "rbxassetid://91549619059662",
	gems1700 = "rbxassetid://130810442796727", gems4500 = "rbxassetid://111400819296862", gems12000 = "rbxassetid://113906745814581",
}

return Config
]]
assert(loadstring(s), "Config compile")
Cfg.Source = s
return "product images patched"
