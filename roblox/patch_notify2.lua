-- one-off patch (run in Edit): notifications never pile up on each other
--  * small notifications: 12 px apart, at most 3 on screen (the oldest goes), the same message twice stays one
--  * big banners ("ROOF DONE / Next: Doors", LEVEL UP...) sit below the small notifications when those reach down
--  * the project completing removes the stage banner on screen too, and "No job here" stays quiet for a few seconds
local function replaceOnce(src, old, new)
	local a, b = src:find(old, 1, true)
	assert(a, "not found: " .. old:sub(1, 80))
	assert(not src:find(old, b + 1, true), "found twice: " .. old:sub(1, 80))
	return src:sub(1, a - 1) .. new .. src:sub(b + 1)
end
local Client = game.StarterPlayer.StarterPlayerScripts.Client
local s = Client.Source
if s:find("NOTIFY2", 1, true) then return "already patched" end

s = replaceOnce(s, [[UI.list(Enum.FillDirection.Vertical, 6, Enum.HorizontalAlignment.Center).Parent = toastHolder]],
	[[UI.list(Enum.FillDirection.Vertical, 12, Enum.HorizontalAlignment.Center).Parent = toastHolder -- NOTIFY2: a little air between them]])

s = replaceOnce(s, [[	toastOrder += 1
	local f = UI.panel({ Size = UDim2.fromOffset(0, 40), AutomaticSize = Enum.AutomaticSize.X, LayoutOrder = toastOrder, Parent = toastHolder })]],
[[	-- at most 3 on screen (the oldest goes), and the same message twice stays one
	local shown = {}
	for _, c in ipairs(toastHolder:GetChildren()) do
		if c:IsA("Frame") and not c:GetAttribute("Gone") then
			if c:GetAttribute("Text") == text then return end
			table.insert(shown, c)
		end
	end
	table.sort(shown, function(a, b) return a.LayoutOrder < b.LayoutOrder end)
	while #shown >= 3 do
		local old = table.remove(shown, 1)
		old:SetAttribute("Gone", true)
		old:Destroy()
	end
	toastOrder += 1
	local f = UI.panel({ Size = UDim2.fromOffset(0, 40), AutomaticSize = Enum.AutomaticSize.X, LayoutOrder = toastOrder, Parent = toastHolder })
	f:SetAttribute("Text", text)]])

s = replaceOnce(s, [[	task.delay(dur or 2.6, function()
		UI.tween(sc, 0.25, { Scale = 0.7 })]], [[	task.delay(dur or 2.6, function()
		if not f.Parent then return end
		f:SetAttribute("Gone", true)
		UI.tween(sc, 0.25, { Scale = 0.7 })]])

s = replaceOnce(s, [[local function showBannerNow(title, sub, color)
	local f = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.3), Size = UDim2.fromOffset(620, 110), BackgroundTransparency = 1, ZIndex = 60, Parent = gui })]],
[[local function showBannerNow(title, sub, color, kind)
	local f = new("Frame", { Name = kind == "stage" and "StageBanner" or "Banner", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.3),
		Size = UDim2.fromOffset(620, 110), BackgroundTransparency = 1, ZIndex = 60, Parent = gui })
	-- never on top of the small notifications: it moves down below them when they reach this far
	local follow
	follow = RunService.RenderStepped:Connect(function()
		if not f.Parent then follow:Disconnect() return end
		local k = math.max(uiScale.Scale, 0.01)
		local lay = toastHolder:FindFirstChildOfClass("UIListLayout")
		local bottom = toastHolder.Position.Y.Offset + (lay and lay.AbsoluteContentSize.Y / k or 0)
		f.Position = UDim2.new(0.5, 0, 0, math.max(gui.AbsoluteSize.Y / k * 0.3, bottom + 72))
	end)]])

s = replaceOnce(s, [[				showBannerNow(b[1], b[2], b[3])]], [[				showBannerNow(b[1], b[2], b[3], b.kind)]])

s = replaceOnce(s, [[local function clearStageBanners()
	for i = #bannerQueue, 1, -1 do if bannerQueue[i].kind == "stage" then table.remove(bannerQueue, i) end end
end]], [[local function clearStageBanners()
	for i = #bannerQueue, 1, -1 do if bannerQueue[i].kind == "stage" then table.remove(bannerQueue, i) end end
	local onScreen = gui:FindFirstChild("StageBanner")
	if onScreen then onScreen:Destroy() end
end]])

s = replaceOnce(s, [[	elseif kind == "Complete" then
		clearStageBanners()]], [[	elseif kind == "Complete" then
		clearStageBanners()
		noJobWarn = os.clock() + 4 -- the last hits after the end: no "No job here" right away]])

assert(loadstring(s), "Client compile")
Client.Source = s
return "notify2 patched"
