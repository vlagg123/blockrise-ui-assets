-- one-off patch (run in Edit): the header's info text (gems, cash, crew...) sits in a white pill that grows with the
-- number; toasts sit above the Roblox hotbar while a window is open
local Client = game.StarterPlayer.StarterPlayerScripts.Client
local s = Client.Source
local function replaceOnce(src, old, new)
	local a, b = src:find(old, 1, true)
	assert(a, "not found: " .. old:sub(1, 80))
	assert(not src:find(old, b + 1, true), "found twice: " .. old:sub(1, 80))
	return src:sub(1, a - 1) .. new .. src:sub(b + 1)
end
s = replaceOnce(s, [[	modalSub.AnchorPoint = Vector2.new(1, 0.5)
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
	modalSub:GetPropertyChangedSignal("Text"):Connect(function() task.defer(fitTitle) end)]], [[	-- the info text (gems, cash, crew...) in a white pill on the right of the ribbon; it grows with the text
	local subPill = UI.slice("pill", { Name = "SubPill", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -18, 0, 31), Size = UDim2.fromOffset(0, 42),
		AutomaticSize = Enum.AutomaticSize.X, SliceScale = 0.42, ImageColor3 = Color3.new(1, 1, 1), Visible = false, ZIndex = 5, Parent = modalHeader })
	new("UIPadding", { PaddingLeft = UDim.new(0, 16), PaddingRight = UDim.new(0, 16), Parent = subPill })
	modalSub.Parent = subPill
	modalSub.AnchorPoint = Vector2.new(0, 0)
	modalSub.Position = UDim2.fromOffset(0, 1)
	modalSub.Size = UDim2.new(0, 0, 1, -2)
	modalSub.AutomaticSize = Enum.AutomaticSize.X
	modalSub.Font = Enum.Font.FredokaOne
	modalSub.TextSize = 23
	modalSub.TextColor3 = Color3.fromRGB(40, 34, 70)
	modalSub.TextXAlignment = Enum.TextXAlignment.Center
	modalSub.ZIndex = 6
	local ss = modalSub:FindFirstChildOfClass("UIStroke")
	if ss then ss.Enabled = false end
	local function fitTitle()
		subPill.Visible = modalSub.Text ~= ""
		local k = subPill.AbsoluteSize.Y > 0 and subPill.AbsoluteSize.Y / 42 or 1
		local sw = subPill.Visible and (subPill.AbsoluteSize.X / k + 18) or 0
		modalTitle.Size = UDim2.new(1, -110 - sw, 0, 52)
	end
	subPill:GetPropertyChangedSignal("AbsoluteSize"):Connect(fitTitle)
	modalSub:GetPropertyChangedSignal("Text"):Connect(function() fitTitle(); task.defer(fitTitle) end)]])
-- toasts above the Roblox hotbar (tool slots at the bottom of the screen)
s = replaceOnce(s, "\t\t\t\tth.Position = UDim2.new(0.5, 0, 1, -14)\n", "\t\t\t\tth.Position = UDim2.new(0.5, 0, 1, -104)\n")
Client.Source = s
return "sub pill + toasts patched"
