-- one-off Studio patch: premium window look for every menu (run in the Edit datamodel)
local cl = game.StarterPlayer.StarterPlayerScripts.Client
local s = cl.Source
local function rep(old, new)
	local a, b = s:find(old, 1, true)
	assert(a, "not found: " .. old:sub(1, 60))
	s = s:sub(1, a - 1) .. new .. s:sub(b + 1)
end

-- 1) after the window is built: restyle it
rep([[	ScrollBarImageColor3 = T.accent, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ZIndex = 21, Parent = modal })
]], [[	ScrollBarImageColor3 = T.accent, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ZIndex = 21, Parent = modal })
-- premium window look: purple glass, thick ink outline, a glossy title plate with a big icon, a round close button
do
	local INK = Color3.fromRGB(20, 17, 32)
	local Icons = require(RS.Shared:WaitForChild("Icons"))
	modal.Size = UDim2.fromOffset(760, 500)
	modal.BackgroundTransparency = 0
	local mg = modal:FindFirstChildOfClass("UIGradient")
	if mg then mg.Color = ColorSequence.new(Color3.fromRGB(66, 60, 110), Color3.fromRGB(34, 30, 58)) end
	local ms = modal:FindFirstChildOfClass("UIStroke")
	if ms then ms.Color = INK; ms.Thickness = 4; ms.Transparency = 0 end
	local mc = modal:FindFirstChildOfClass("UICorner")
	if mc then mc.CornerRadius = UDim.new(0, 24) end
	local rim = new("Frame", { Name = "Rim", Position = UDim2.fromOffset(4, 4), Size = UDim2.new(1, -8, 1, -8), BackgroundTransparency = 1, ZIndex = 21, Parent = modal })
	UI.corner(20).Parent = rim
	new("UIStroke", { Thickness = 1.5, Color = Color3.new(1, 1, 1), Transparency = 0.85, Parent = rim })
	-- title plate
	for _, f in ipairs(modalHeader:GetChildren()) do
		if f:IsA("Frame") then f:Destroy() end -- the old square-bottom filler
	end
	modalHeader.Position = UDim2.fromOffset(12, 12)
	modalHeader.Size = UDim2.new(1, -24, 0, 60)
	local hc = modalHeader:FindFirstChildOfClass("UICorner")
	if hc then hc.CornerRadius = UDim.new(0, 16) end
	new("UIStroke", { Thickness = 3, Color = INK, Parent = modalHeader })
	headerGrad.Rotation = 90
	local gloss = new("Frame", { Name = "Gloss", Position = UDim2.fromOffset(5, 4), Size = UDim2.new(1, -10, 0.42, 0), BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.74, BorderSizePixel = 0, ZIndex = 21, Parent = modalHeader })
	UI.corner(12).Parent = gloss
	local headerIcon = Icons.make("star", { Name = "HeaderIcon", AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 0, 0.5, -6), Size = UDim2.fromOffset(86, 86), ZIndex = 24, Parent = modalHeader })
	modalTitle.Font = Enum.Font.LuckiestGuy
	modalTitle.TextSize = 34
	modalTitle.Position = UDim2.fromOffset(92, 3)
	modalTitle.Size = UDim2.new(1, -400, 1, 0)
	local ts = modalTitle:FindFirstChildOfClass("UIStroke")
	if ts then ts.Color = INK; ts.Transparency = 0; ts.Thickness = 3 end
	modalSub.Position = UDim2.new(1, -52, 0.5, 2)
	modalSub.Size = UDim2.fromOffset(320, 30)
	local ss = modalSub:FindFirstChildOfClass("UIStroke")
	if ss then ss.Color = INK; ss.Transparency = 0; ss.Thickness = 2 end
	-- round close button on the corner of the window
	closeBtn.Parent = modal
	closeBtn.AnchorPoint = Vector2.new(0.5, 0.5)
	closeBtn.Position = UDim2.new(1, -12, 0, 12)
	closeBtn.Size = UDim2.fromOffset(54, 54)
	closeBtn.ZIndex = 26
	for _, d in ipairs(closeBtn:GetDescendants()) do
		if d:IsA("UICorner") then d.CornerRadius = UDim.new(1, 0) end
		if d:IsA("GuiObject") then d.ZIndex = 26 + (d.Name == "Label" and 1 or 0) end
	end
	local xl = closeBtn:FindFirstChild("Label")
	if xl then xl.TextSize = 26 end
	content.Position = UDim2.fromOffset(16, 86)
	content.Size = UDim2.new(1, -32, 1, -100)
	content.ScrollBarThickness = 8
	content.ScrollBarImageColor3 = Color3.fromRGB(255, 214, 80)
	local MODAL_ICON = { Contracts = "jobs", Shop = "shop", Hire = "hire", Property = "home", Missions = "daily", Store = "store", Portfolio = "portfolio",
		Company = "company", Trade = "trade", Garage = "cars", Gifts = "gift", Spin = "spin", Codes = "codes", Upgrades = "upgrades", Rebirth = "rebirth",
		Locations = "locations", Welcome = "star" }
	_G.__CE_ModalIcon = function(name) Icons.set(headerIcon, MODAL_ICON[name] or "star") end
end
]])

-- 2) titles: the icon replaces the leading emoji
rep([[	modalTitle.Text = title
]], [[	modalTitle.Text = (title:gsub("^[^%w]+", ""))
	if _G.__CE_ModalIcon then _G.__CE_ModalIcon(name) end
]])

-- 3) cards: lighter purple glass with an ink outline
rep([[local function card(order, height)
	local f = new("Frame", { Size = UDim2.new(1, -8, 0, height or 110), BackgroundColor3 = T.bg2, BackgroundTransparency = 0.05, LayoutOrder = order, ZIndex = 21, Parent = content })
	UI.corner(12).Parent = f
	UI.stroke(0.9).Parent = f
	return f
end]], [[local function card(order, height)
	local f = new("Frame", { Size = UDim2.new(1, -8, 0, height or 110), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0, LayoutOrder = order, ZIndex = 21, Parent = content })
	UI.corner(16).Parent = f
	new("UIGradient", { Color = ColorSequence.new(Color3.fromRGB(86, 78, 140), Color3.fromRGB(62, 56, 106)), Rotation = 90, Parent = f })
	new("UIStroke", { Thickness = 2.5, Color = Color3.fromRGB(20, 17, 32), Parent = f })
	return f
end]])

cl.Source = s
local fn, err = loadstring(s)
return "patched, compile: " .. (fn and "OK" or tostring(err))
