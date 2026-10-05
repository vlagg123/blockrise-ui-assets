-- one-off patch (run in Edit): MZwolf's real account is UserId 2808108421 (display name "MZwolf", given by the owner).
-- 36445780 was a different account that only has the username "MZwolf": it is removed from the admins.
local function replaceOnce(src, old, new)
	local a, b = src:find(old, 1, true)
	assert(a, "not found: " .. old:sub(1, 80))
	assert(not src:find(old, b + 1, true), "found twice: " .. old:sub(1, 80))
	return src:sub(1, a - 1) .. new .. src:sub(b + 1)
end
local Main = game.ServerScriptService.Game.Main
local s = Main.Source
if s:find("[2808108421]", 1, true) then return "already patched" end
s = replaceOnce(s, [[		[36445780] = true, -- MZwolf (added by the owner)]], [[		[2808108421] = true, -- MZwolf (display name; UserId given by the owner)]])
assert(not s:find("36445780", 1, true), "old id still there")
assert(loadstring(s), "Main compile")
Main.Source = s
return "MZwolf = 2808108421"
