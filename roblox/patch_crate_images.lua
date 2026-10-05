-- one-off patch (run in Edit): pictures of the Robux crate products (Config.ProductImages)
local C = game.ReplicatedStorage.Shared.Config
local s = C.Source
if s:find("crate_golden3 = ", 1, true) then return "already patched" end
local a, b = s:find("Config.ProductImages = {", 1, true)
assert(a, "no ProductImages")
s = s:sub(1, b) .. [[

	crate_golden = "rbxassetid://89693710220545", crate_golden3 = "rbxassetid://93643298181151",
	crate_exclusive = "rbxassetid://104986103095719", crate_exclusive3 = "rbxassetid://139471522232776",]] .. s:sub(b + 1)
assert(loadstring(s), "compile Config")
C.Source = s
return "crate images set"
