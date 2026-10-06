-- one-off patch (run in Edit), Client: Auto Build / Auto Train a few pixels apart (they looked stuck together)
local function replaceOnce(src, old, new)
	local a, b = src:find(old, 1, true)
	assert(a, "not found: " .. old:sub(1, 80))
	assert(not src:find(old, b + 1, true), "found twice: " .. old:sub(1, 80))
	return src:sub(1, a - 1) .. new .. src:sub(b + 1)
end
local Client = game.StarterPlayer.StarterPlayerScripts.Client
local s = Client.Source
if s:find("UI.list(Enum.FillDirection.Vertical, 14, Enum.HorizontalAlignment.Right, Enum.VerticalAlignment.Bottom).Parent = autoBar", 1, true) then return "already patched" end
s = replaceOnce(s, "UI.list(Enum.FillDirection.Vertical, 6, Enum.HorizontalAlignment.Right, Enum.VerticalAlignment.Bottom).Parent = autoBar",
	"UI.list(Enum.FillDirection.Vertical, 14, Enum.HorizontalAlignment.Right, Enum.VerticalAlignment.Bottom).Parent = autoBar")
assert(#s < 200000, "Client too big")
assert(loadstring(s), "Client compile")
Client.Source = s
return "Client " .. #s
