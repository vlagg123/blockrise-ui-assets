-- one-off patch (run in Edit): a window can pin one row under its tabs, outside the scrolling list (it stays in view
-- while you scroll): the "YOU HAVE" materials strip in Upgrades and Company. UI.tabHosts[content].sticky is that place
-- (MenuKit's K.haveRow puts itself there).
local function replaceOnce(src, old, new, what)
	local a, b = src:find(old, 1, true)
	assert(a, "not found: " .. (what or old:sub(1, 80)))
	assert(not src:find(old, b + 1, true), "found twice: " .. (what or old:sub(1, 80)))
	return src:sub(1, a - 1) .. new .. src:sub(b + 1)
end
local Client = game.StarterPlayer.StarterPlayerScripts.Client
local s = Client.Source
if s:find("STICKY_BAR", 1, true) then return "already patched" end

s = replaceOnce(s, [==[	local tabBar = new("Frame", { Name = "TabBar", Position = UDim2.fromOffset(24, 62), Size = UDim2.new(1, -48, 0, 54), BackgroundTransparency = 1, Visible = false, ZIndex = 20, Parent = modal })]==],
	[==[	local tabBar = new("Frame", { Name = "TabBar", Position = UDim2.fromOffset(24, 62), Size = UDim2.new(1, -48, 0, 54), BackgroundTransparency = 1, Visible = false, ZIndex = 20, Parent = modal })
	-- STICKY_BAR: one row pinned under the tabs, outside the scrolling list (it stays in view while you scroll)
	local stickyBar = new("Frame", { Name = "StickyBar", Position = UDim2.fromOffset(24, 62), Size = UDim2.new(1, -48, 0, 50), BackgroundTransparency = 1, Visible = false, ZIndex = 20, Parent = modal })]==])

s = replaceOnce(s, [==[		local hasTabs = #tabBar:GetChildren() > 0
		tabBar.Visible = hasTabs
		top = hasTabs and 124 or 64]==], [==[		local hasTabs = #tabBar:GetChildren() > 0
		tabBar.Visible = hasTabs
		top = hasTabs and 124 or 64
		local hasSticky = #stickyBar:GetChildren() > 0
		stickyBar.Visible = hasSticky
		if hasSticky then
			stickyBar.Position = UDim2.fromOffset(16, top + 2)
			stickyBar.Size = UDim2.new(1, -32, 0, 50)
			top += 56
		end]==])

s = replaceOnce(s, [==[	UI.tabHosts[content] = { bar = tabBar, changed = layout }
	_G.__CE_ModalClear = function()
		for _, o in ipairs(tabBar:GetChildren()) do o:Destroy() end]==], [==[	UI.tabHosts[content] = { bar = tabBar, sticky = stickyBar, changed = layout }
	_G.__CE_ModalClear = function()
		for _, o in ipairs(tabBar:GetChildren()) do o:Destroy() end
		for _, o in ipairs(stickyBar:GetChildren()) do o:Destroy() end]==])

assert(loadstring(s), "compile Client")
Client.Source = s
return "sticky bar"
