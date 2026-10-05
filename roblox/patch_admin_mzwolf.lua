-- one-off patch (run in Edit): a second admin, asked for by the owner: MZwolf (UserId 36445780, username "MZwolf").
-- Same panel, same server checks; only the list of UserIds grows.
local function replaceOnce(src, old, new)
	local a, b = src:find(old, 1, true)
	assert(a, "not found: " .. old:sub(1, 80))
	assert(not src:find(old, b + 1, true), "found twice: " .. old:sub(1, 80))
	return src:sub(1, a - 1) .. new .. src:sub(b + 1)
end
local Main = game.ServerScriptService.Game.Main
local s = Main.Source
if s:find("[36445780]", 1, true) then return "already patched" end
s = replaceOnce(s, [[	local ADMINS = { [4285033131] = true } -- the owner's Roblox account (game.CreatorId). Nobody else, ever.]],
	[[	-- the owner's Roblox account (game.CreatorId), and the accounts the owner chose. Nobody else, ever.
	local ADMINS = {
		[4285033131] = true, -- owner
		[36445780] = true, -- MZwolf (added by the owner)
	}]])
assert(loadstring(s), "Main compile")
Main.Source = s
return "MZwolf is admin"
