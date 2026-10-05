-- one-off patch (run in Edit): window look v3 for the Client script
local Client = game.StarterPlayer.StarterPlayerScripts.Client
local s = Client.Source

local function replaceBetween(src, startMark, endMark, repl)
	local a = src:find(startMark, 1, true)
	assert(a, "start not found: " .. startMark)
	local b = src:find(endMark, a, true)
	assert(b, "end not found: " .. endMark)
	return src:sub(1, a - 1) .. repl .. src:sub(b)
end
local function replaceOnce(src, old, new)
	local a, b = src:find(old, 1, true)
	assert(a, "not found: " .. old:sub(1, 80))
	assert(not src:find(old, b + 1, true), "found twice: " .. old:sub(1, 80))
	return src:sub(1, a - 1) .. new .. src:sub(b + 1)
end

-- 1) window chrome ----------------------------------------------------------------------------------------------
local CHROME = [==[
-- window look v3 (front-page simulator style): 9-slice body with faint stripes, a ribbon header that sticks out of the
-- top with a big tilted icon, a red close button on the corner, a fixed tab bar, a dark well with the list and a thin
-- scroll indicator instead of the scrollbar
local fitWindow
do
	local INK = Color3.fromRGB(20, 17, 32)
	local Icons = require(RS.Shared:WaitForChild("Icons"))
	modal.Name = "Window"
	modal.Active = true -- clicks on the window itself must not reach the dark backdrop (that closes it)
	modal.BackgroundTransparency = 1
	for _, d in ipairs(modal:GetChildren()) do
		if d:IsA("UIStroke") or d:IsA("UIGradient") then d.Enabled = false end
	end
	UI.slice("shadow", { Name = "Shadow", Position = UDim2.fromOffset(-12, -2), Size = UDim2.new(1, 26, 1, 28), ImageTransparency = 0.05, ZIndex = 1, Parent = modal })
	local body = UI.slice("panel", { Name = "Body", ImageColor3 = Color3.new(1, 1, 1), ZIndex = 2, Parent = modal })
	new("UIGradient", { Color = ColorSequence.new(Color3.fromRGB(104, 104, 240), Color3.fromRGB(52, 46, 150)), Rotation = 90, Parent = body })
	local stripes = new("CanvasGroup", { Name = "Stripes", Position = UDim2.fromOffset(5, 5), Size = UDim2.new(1, -10, 1, -10), BackgroundTransparency = 1, ZIndex = 3, Parent = modal })
	UI.corner(17).Parent = stripes
	new("ImageLabel", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Image = UI.PATTERN, ScaleType = Enum.ScaleType.Tile, TileSize = UDim2.fromOffset(128, 128),
		ImageTransparency = 0.6, Parent = stripes })
	local well = UI.slice("inset", { Name = "Well", ImageTransparency = 0.5, ZIndex = 4, Parent = modal })
	local tabBar = new("Frame", { Name = "TabBar", Position = UDim2.fromOffset(24, 62), Size = UDim2.new(1, -48, 0, 54), BackgroundTransparency = 1, Visible = false, ZIndex = 20, Parent = modal })

	-- ribbon header
	for _, f in ipairs(modalHeader:GetChildren()) do
		if f:IsA("Frame") or f:IsA("UIStroke") or f:IsA("UICorner") then f:Destroy() end
	end
	modalHeader.BackgroundTransparency = 1
	modalHeader.Position = UDim2.fromOffset(80, -30)
	modalHeader.Size = UDim2.new(1, -160, 0, 78)
	modalHeader.ZIndex = 24
	local ribbon = UI.slice("button", { Name = "Ribbon", ImageColor3 = T.accent, ZIndex = 1, Parent = modalHeader })
	local hs = new("CanvasGroup", { Name = "Stripes", Position = UDim2.fromOffset(4, 4), Size = UDim2.new(1, -8, 1, -16), BackgroundTransparency = 1, ZIndex = 2, Parent = modalHeader })
	UI.corner(13).Parent = hs
	new("ImageLabel", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Image = UI.PATTERN, ScaleType = Enum.ScaleType.Tile, TileSize = UDim2.fromOffset(96, 96),
		ImageTransparency = 0.3, Parent = hs })
	UI.slice("gloss", { Name = "Gloss", ZIndex = 3, Parent = modalHeader })
	local function tintRibbon()
		local k = headerGrad.Color.Keypoints
		ribbon.ImageColor3 = k[1].Value:Lerp(k[#k].Value, 0.45)
	end
	headerGrad:GetPropertyChangedSignal("Color"):Connect(tintRibbon)
	tintRibbon()
	local headerIcon = Icons.make("star", { Name = "HeaderIcon", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0, 18, 0.5, -12), Size = UDim2.fromOffset(122, 122),
		Rotation = -8, ZIndex = 8, Parent = modalHeader })
	modalTitle.Font = Enum.Font.LuckiestGuy
	modalTitle.TextXAlignment = Enum.TextXAlignment.Left
	modalTitle.Position = UDim2.fromOffset(86, 7)
	modalTitle.Size = UDim2.new(1, -110, 0, 52)
	modalTitle.ZIndex = 5
	modalTitle.TextScaled = true
	new("UITextSizeConstraint", { MaxTextSize = 44, MinTextSize = 16, Parent = modalTitle })
	local ts = modalTitle:FindFirstChildOfClass("UIStroke")
	if ts then ts.Color = INK; ts.Transparency = 0; ts.Thickness = 4 end
	new("UIGradient", { Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(255, 234, 150)), Rotation = 90, Parent = modalTitle })
	modalSub.AnchorPoint = Vector2.new(1, 0.5)
	modalSub.Position = UDim2.new(1, -22, 0, 33)
	modalSub.Size = UDim2.fromOffset(0, 32)
	modalSub.AutomaticSize = Enum.AutomaticSize.X
	modalSub.Font = Enum.Font.FredokaOne
	modalSub.TextSize = 23
	modalSub.ZIndex = 5
	local ss = modalSub:FindFirstChildOfClass("UIStroke")
	if ss then ss.Color = INK; ss.Transparency = 0; ss.Thickness = 2.5 end
	local function fitTitle()
		local sw = modalSub.Text ~= "" and (modalSub.AbsoluteSize.X / math.max(0.01, modalSub.AbsoluteSize.Y / 32) + 18) or 0
		modalTitle.Size = UDim2.new(1, -110 - sw, 0, 52)
	end
	modalSub:GetPropertyChangedSignal("AbsoluteSize"):Connect(fitTitle)
	modalSub:GetPropertyChangedSignal("Text"):Connect(function() task.defer(fitTitle) end)

	-- red close button on the corner
	closeBtn.Parent = modal
	closeBtn.AnchorPoint = Vector2.new(0, 0)
	closeBtn.Position = UDim2.new(1, -50, 0, -22)
	closeBtn.Size = UDim2.fromOffset(66, 66)
	closeBtn.ZIndex = 30
	local xl = closeBtn:FindFirstChild("Label")
	if xl then
		xl.Font = Enum.Font.LuckiestGuy
		local c = xl:FindFirstChildOfClass("UITextSizeConstraint")
		if c then c.MaxTextSize = 36 end
		local st = xl:FindFirstChildOfClass("UIStroke")
		if st then st.Thickness = 3 end
	end

	-- the list: no scrollbar, a thin indicator on the well instead
	content.ScrollBarThickness = 0
	content.ScrollingDirection = Enum.ScrollingDirection.Y
	content.ZIndex = 10
	local ind = UI.slice("pill", { Name = "ScrollBar", AnchorPoint = Vector2.new(1, 0), SliceScale = 0.1, ImageColor3 = Color3.new(1, 1, 1), ImageTransparency = 0.3,
		Size = UDim2.fromOffset(8, 40), Visible = false, ZIndex = 12, Parent = modal })
	local top = 62
	local function updInd()
		local canvas, view = content.AbsoluteCanvasSize.Y, content.AbsoluteWindowSize.Y
		if view <= 0 or canvas <= view + 4 then ind.Visible = false return end
		local trackH = modal.Size.Y.Offset + content.Size.Y.Offset
		local thumb = math.max(40, trackH * view / canvas)
		local k = content.AbsoluteSize.Y / math.max(1, trackH) -- screen px per design px
		local maxPos = (canvas - view) / k
		local frac = math.clamp(content.CanvasPosition.Y / math.max(1, maxPos), 0, 1)
		ind.Size = UDim2.fromOffset(8, thumb)
		ind.Position = UDim2.new(1, -21, 0, content.Position.Y.Offset + (trackH - thumb) * frac)
		ind.Visible = true
	end
	content:GetPropertyChangedSignal("CanvasPosition"):Connect(updInd)
	content:GetPropertyChangedSignal("AbsoluteCanvasSize"):Connect(updInd)
	content:GetPropertyChangedSignal("AbsoluteWindowSize"):Connect(updInd)
	local function layout()
		local hasTabs = #tabBar:GetChildren() > 0
		tabBar.Visible = hasTabs
		top = hasTabs and 124 or 64
		well.Position = UDim2.fromOffset(16, top)
		well.Size = UDim2.new(1, -32, 1, -top - 16)
		content.Position = UDim2.fromOffset(28, top + 12)
		content.Size = UDim2.new(1, -64, 1, -top - 40)
		task.defer(updInd)
	end
	UI.tabHosts[content] = { bar = tabBar, changed = layout }
	_G.__CE_ModalClear = function()
		for _, o in ipairs(tabBar:GetChildren()) do o:Destroy() end
		layout()
	end
	-- the window fits the screen: 860 x 560 on PC, smaller on phones (the header sticks out ~60 px above it)
	fitWindow = function()
		local s = uiScale.Scale
		local dw, dh = gui.AbsoluteSize.X / s, gui.AbsoluteSize.Y / s
		local w = math.floor(math.clamp(dw - 120, 640, 860))
		local h = math.floor(math.clamp(dh - 110, 360, 560))
		modal.Size = UDim2.fromOffset(w, h)
		modal.Position = UDim2.new(0.5, 0, 0.5, 26)
		layout()
	end
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(fitWindow)
	uiScale:GetPropertyChangedSignal("Scale"):Connect(fitWindow)
	fitWindow()
	-- design width of the list, for windows that pick their grid columns
	_G.__CE_ListWidth = function() return modal.Size.X.Offset + content.Size.X.Offset end

	local MODAL_ICON = { Contracts = "jobs", Shop = "shop", Hire = "hire", Property = "home", Missions = "daily", Store = "store", Portfolio = "portfolio",
		Company = "company", Trade = "trade", Garage = "cars", Gifts = "gift", Spin = "spin", Codes = "codes", Upgrades = "upgrades", Rebirth = "rebirth",
		Locations = "locations", Welcome = "star" }
	_G.__CE_ModalIcon = function(name) Icons.set(headerIcon, MODAL_ICON[name] or "star") end
end
]==]
s = replaceBetween(s, "-- premium window look: purple glass", "\nlocal currentModal", CHROME)

-- 2) openModal clears the fixed tab bar too ------------------------------------------------------------------------
s = replaceOnce(s, [[	for _, c in ipairs(content:GetChildren()) do if not c:IsA("UIListLayout") then c:Destroy() end end
	modal.Visible = true; modalBg.Visible = true]], [[	for _, c in ipairs(content:GetChildren()) do if not c:IsA("UIListLayout") then c:Destroy() end end
	if _G.__CE_ModalClear then _G.__CE_ModalClear() end
	modal.Visible = true; modalBg.Visible = true]])

-- 3) chips, cards and status pills on the skin --------------------------------------------------------------------
local PIECES = [==[
-- light colours (muted...) would vanish under white text: darken them for the coloured pills
local function solid(color)
	local l = color.R * 0.299 + color.G * 0.587 + color.B * 0.114
	if l > 0.72 then return color:Lerp(Color3.fromRGB(70, 74, 130), 0.55) end
	return color
end

local function chip(parent, text, color, x)
	local f = UI.slice("pill", { Name = "Chip", Position = UDim2.fromOffset(x, 0), Size = UDim2.fromOffset(0, 26), AutomaticSize = Enum.AutomaticSize.X, SliceScale = 0.36,
		ImageColor3 = solid(color), ZIndex = 22, Parent = parent })
	UI.pad(9, 0).Parent = f
	local l = UI.label({ Size = UDim2.new(0, 0, 1, -2), AutomaticSize = Enum.AutomaticSize.X, Text = text, Font = T.title, TextSize = 15, ZIndex = 23, Parent = f })
	new("UIStroke", { Thickness = 1.8, Color = T.ink, LineJoinMode = Enum.LineJoinMode.Round, Parent = l })
	return f
end

local function card(order, height)
	local f = new("Frame", { Name = "Card", Size = UDim2.new(1, 0, 0, height or 110), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 1, LayoutOrder = order, ZIndex = 21, Parent = content })
	local bg = UI.slice("tile", { Name = "CardBg", ImageColor3 = Color3.new(1, 1, 1), ZIndex = 1, Parent = f })
	new("UIGradient", { Color = ColorSequence.new(Color3.fromRGB(110, 116, 232), Color3.fromRGB(74, 76, 182)), Rotation = 90, Parent = bg })
	-- older windows fade a card with BackgroundTransparency: turn that into a faded card instead of a white box
	f:GetPropertyChangedSignal("BackgroundTransparency"):Connect(function()
		local v = f.BackgroundTransparency
		if v < 1 then
			bg.ImageTransparency = v * 0.75
			f.BackgroundTransparency = 1
		end
	end)
	return f
end

-- status label on the right of a card (not a button: nothing to press)
local function pill(parent, text, color, width)
	local p = UI.slice("pill", { Name = "Action", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -14, 0.5, 0), Size = UDim2.fromOffset(width or 150, 44),
		SliceScale = 0.42, ImageColor3 = solid(color), ZIndex = 22, Parent = parent })
	local l = UI.label({ Position = UDim2.fromOffset(8, 0), Size = UDim2.new(1, -16, 1, -2), Text = text, Font = T.title, TextSize = 19, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 23, Parent = p })
	l.TextScaled = true
	new("UITextSizeConstraint", { MaxTextSize = 19, MinTextSize = 10, Parent = l })
	new("UIStroke", { Thickness = 2, Color = T.ink, LineJoinMode = Enum.LineJoinMode.Round, Parent = l })
	return p
end
]==]
s = replaceBetween(s, "local function chip(parent, text, color, x)", "\nlocal function loadingCard()", PIECES)

-- 4) the auto-mode toggles fade their button image ---------------------------------------------------------------
s = replaceOnce(s, "if bgf then bgf.BackgroundTransparency = on and 0 or 0.45 end", "if bgf then bgf.ImageTransparency = on and 0 or 0.45 end")

Client.Source = s
return "chrome patched, " .. #s .. " chars"
