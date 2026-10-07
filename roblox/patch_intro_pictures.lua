-- one-off patch (run in Edit): the title screen fetches every picture the menus show before PLAY comes up, so a new
-- player's windows (the Hammer Index, the Inventory, the Shop...) show all their pictures at once
--  * pictures are fetched through a label that shows them (ContentProvider reports a failure for an image id given as
--    a plain rbxassetid string, so the title screen's own pictures were never really fetched either)
--  * the list: the title screen's own pictures + MenuKit.allPictures() (hammers, crates, materials, the Store...)
--  * PLAY never waits more than 12 s for them (a slow connection still gets in; the rest keeps loading)
local function replaceOnce(src, old, new)
	local a, b = src:find(old, 1, true)
	assert(a, "not found: " .. old:sub(1, 80))
	assert(not src:find(old, b + 1, true), "found twice: " .. old:sub(1, 80))
	return src:sub(1, a - 1) .. new .. src:sub(b + 1)
end
local Client = game.StarterPlayer.StarterPlayerScripts.Client
local c = Client.Source
if c:find("allPictures", 1, true) then return "Client: already" end
c = replaceOnce(c, [=[		local list = { LOGO, UI.SKIN, UI.PATTERN, Icons.ATLAS, gui }]=], [=[		-- (pictures through a label: an image id alone isn't fetched) + every picture of the menus (MenuKit)
		local list = { gui }
		local function pic(v)
			if type(v) == "string" and v:find("^rbxasset") then local l = Instance.new("ImageLabel"); l.Image = v; table.insert(list, l)
			elseif type(v) == "table" then for _, x in pairs(v) do pic(x) end end
		end
		pic({ LOGO, UI.SKIN, UI.PATTERN, Icons.ATLAS })
		pcall(function() pic(require(RS.Shared.MenuKit).allPictures()) end)
		task.delay(12, function() prog.assets = 1 end)]=])
assert(#c < 200000, "Client too big: " .. #c)
assert(loadstring(c), "Client compile")
Client.Source = c
return "Client: title screen fetches every menu picture (" .. #c .. ")"
