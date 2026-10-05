-- one-off patch (run in Edit): the close button gets a clean drawn X; no scroll indicator in the windows
local Client = game.StarterPlayer.StarterPlayerScripts.Client
local s = Client.Source
local function replaceOnce(src, old, new)
	local a, b = src:find(old, 1, true)
	assert(a, "not found: " .. old:sub(1, 80))
	assert(not src:find(old, b + 1, true), "found twice: " .. old:sub(1, 80))
	return src:sub(1, a - 1) .. new .. src:sub(b + 1)
end
s = replaceOnce(s, "\t\tind.Visible = true\n", "\t\tind.Visible = false -- no scrollbar in the menus (scrolling still works)\n")
s = replaceOnce(s, "\t-- the list: no scrollbar, a thin indicator on the well instead\n", "\tUI.drawX(closeBtn, 31)\n\t-- the list: no scrollbar\n")
Client.Source = s
return "close X + no scrollbar"
