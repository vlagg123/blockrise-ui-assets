-- one-off patch (run in Edit): a window that is closing (0.18 s fade) no longer counts as open
--  * MORE with a window open: the window closes and the popup stays open (the HUD hid it during the fade)
--  * a redraw (purchase, claim...) that lands during the fade no longer reopens the window you just closed
local function replaceOnce(src, old, new)
	local a, b = src:find(old, 1, true)
	assert(a, "not found: " .. old:sub(1, 80))
	assert(not src:find(old, b + 1, true), "found twice: " .. old:sub(1, 80))
	return src:sub(1, a - 1) .. new .. src:sub(b + 1)
end
local Client = game.StarterPlayer.StarterPlayerScripts.Client
local s = Client.Source
if s:find("modal.Visible and currentModal ~= nil", 1, true) then return "already patched" end
s = replaceOnce(s, [[	ctx.modalOpen = function() return modal.Visible end]],
	[[	ctx.modalOpen = function() return modal.Visible and currentModal ~= nil end -- a window fading out is closed]])
assert(loadstring(s), "compile Client")
Client.Source = s
return "modal closing patched"
