-- one-off patch (run in Edit): pictures of the crate passes (Quick Open, Auto Opener)
local C = game.ReplicatedStorage.Shared.Config
local s = C.Source
if s:find("quickopen = \"rbxassetid", 1, true) then return "already patched" end
local a, b = s:find("Config.ProductImages = {", 1, true)
assert(a, "no ProductImages")
s = s:sub(1, b) .. [[

	quickopen = "rbxassetid://114002292478180", autoopen = "rbxassetid://139474241942444",]] .. s:sub(b + 1)
assert(loadstring(s), "compile Config")
C.Source = s
return "crate pass images"
