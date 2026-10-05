-- one-off patch (run in Edit): premium title screen (big gold logo with rays, EMPIRE ribbon, tagline pill, feature
-- chips with 3D icons, big PLAY button, floating icons); window scrollbars fully hidden
local Client = game.StarterPlayer.StarterPlayerScripts.Client
local s = Client.Source
local function replaceBetween(src, startMark, endMark, repl)
	local a = src:find(startMark, 1, true)
	assert(a, "start not found: " .. startMark:sub(1, 60))
	local b = src:find(endMark, a, true)
	assert(b, "end not found: " .. endMark:sub(1, 60))
	return src:sub(1, a - 1) .. repl .. src:sub(b)
end
local function replaceOnce(src, old, new)
	local a, b = src:find(old, 1, true)
	assert(a, "not found: " .. old:sub(1, 80))
	assert(not src:find(old, b + 1, true), "found twice: " .. old:sub(1, 80))
	return src:sub(1, a - 1) .. new .. src:sub(b + 1)
end

s = replaceBetween(s, "\tlocal box = new(\"Frame\", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(760, 420)", "\tlocal t0 = os.clock()\n", [==[
	local Icons = require(RS.Shared:WaitForChild("Icons"))
	local INK = Color3.fromRGB(20, 17, 32)
	local box = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(1200, 660), BackgroundTransparency = 1, ZIndex = 81, Parent = intro })
	-- slow golden rays + glow behind the logo
	local rays = UI.slice("rays", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(600, 170), Size = UDim2.fromOffset(980, 980), ImageColor3 = Color3.fromRGB(255, 205, 90),
		ImageTransparency = 0.72, ZIndex = 81, Parent = box })
	UI.slice("glow", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(600, 175), Size = UDim2.fromOffset(900, 460), ImageColor3 = Color3.fromRGB(255, 190, 70),
		ImageTransparency = 0.55, ZIndex = 81, Parent = box })
	-- logo
	local title = UI.label({ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromOffset(600, 40), Size = UDim2.fromOffset(1100, 160), Text = "BLOCKRISE", Font = Enum.Font.LuckiestGuy,
		TextSize = 158, TextColor3 = Color3.new(1, 1, 1), TextXAlignment = Enum.TextXAlignment.Center, Rotation = -2, ZIndex = 84, Parent = box })
	new("UIStroke", { Thickness = 9, Color = INK, LineJoinMode = Enum.LineJoinMode.Round, Parent = title })
	new("UIGradient", { Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 246, 170)), ColorSequenceKeypoint.new(0.55, Color3.fromRGB(255, 200, 60)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 140, 30)) }), Rotation = 90, Parent = title })
	-- EMPIRE ribbon
	local ribbon = new("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromOffset(600, 196), Size = UDim2.fromOffset(470, 96), BackgroundTransparency = 1, Rotation = -2, ZIndex = 83, Parent = box })
	UI.slice("button", { ImageColor3 = Color3.fromRGB(240, 90, 70), ZIndex = 83, Parent = ribbon })
	local rs = new("CanvasGroup", { Position = UDim2.fromOffset(5, 5), Size = UDim2.new(1, -10, 1, -20), BackgroundTransparency = 1, ZIndex = 84, Parent = ribbon })
	UI.corner(14).Parent = rs
	new("ImageLabel", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Image = UI.PATTERN, ScaleType = Enum.ScaleType.Tile, TileSize = UDim2.fromOffset(96, 96),
		ImageTransparency = 0.3, Parent = rs })
	UI.slice("gloss", { ZIndex = 85, Parent = ribbon })
	local title2 = UI.label({ Position = UDim2.fromOffset(0, 4), Size = UDim2.new(1, 0, 1, -18), Text = "EMPIRE", Font = Enum.Font.LuckiestGuy, TextSize = 74,
		TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 86, Parent = ribbon })
	new("UIStroke", { Thickness = 6, Color = INK, LineJoinMode = Enum.LineJoinMode.Round, Parent = title2 })
	-- tagline in a white pill
	local tag = UI.slice("pill", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromOffset(600, 316), Size = UDim2.fromOffset(0, 54), AutomaticSize = Enum.AutomaticSize.X,
		SliceScale = 0.45, ImageColor3 = Color3.new(1, 1, 1), ZIndex = 83, Parent = box })
	new("UIPadding", { PaddingLeft = UDim.new(0, 28), PaddingRight = UDim.new(0, 28), Parent = tag })
	UI.label({ Size = UDim2.new(0, 0, 1, -4), AutomaticSize = Enum.AutomaticSize.X, Text = "From a garden fence to the city skyline", Font = Enum.Font.FredokaOne, TextSize = 30,
		TextColor3 = Color3.fromRGB(40, 34, 70), ZIndex = 84, Parent = tag })
	-- what you do, as chips with 3D icons
	local chips = new("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromOffset(600, 392), Size = UDim2.fromOffset(0, 58), AutomaticSize = Enum.AutomaticSize.X,
		BackgroundTransparency = 1, ZIndex = 83, Parent = box })
	new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 14), SortOrder = Enum.SortOrder.LayoutOrder, VerticalAlignment = Enum.VerticalAlignment.Center, Parent = chips })
	for i, ch in ipairs({ { "shop", "BUILD" }, { "crew", "HIRE" }, { "mega", "MACHINES" }, { "home", "YOUR HOUSE" }, { "downtown", "MEGA PROJECTS" } }) do
		local p = UI.slice("pill", { Size = UDim2.fromOffset(0, 54), AutomaticSize = Enum.AutomaticSize.X, SliceScale = 0.42, ImageColor3 = Color3.fromRGB(70, 74, 170), LayoutOrder = i,
			ZIndex = 83, Parent = chips })
		new("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 18), Parent = p })
		new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6), VerticalAlignment = Enum.VerticalAlignment.Center, Parent = p })
		Icons.make(ch[1], { Size = UDim2.fromOffset(50, 50), ZIndex = 84, LayoutOrder = 1, Parent = p })
		local l = UI.label({ Size = UDim2.new(0, 0, 1, -4), AutomaticSize = Enum.AutomaticSize.X, Text = ch[2], Font = Enum.Font.LuckiestGuy, TextSize = 24, LayoutOrder = 2, ZIndex = 84, Parent = p })
		new("UIStroke", { Thickness = 2.5, Color = INK, Parent = l })
	end
	-- PLAY
	local play = UI.button("PLAY", T.green, nil, { Name = "PlayButton", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromOffset(600, 486), Size = UDim2.fromOffset(400, 118),
		TextSize = 72, Font = Enum.Font.LuckiestGuy, ZIndex = 86, Shine = true, Parent = box })
	-- 3D icons floating around the logo
	local floats = {}
	for i, f in ipairs({ { "cash", 95, 120, -12 }, { "gem", 1105, 110, 10 }, { "mega", 120, 480, 8 }, { "store", 1085, 470, -8 } }) do
		local ic = Icons.make(f[1], { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(f[2], f[3]), Size = UDim2.fromOffset(150, 150), Rotation = f[4], ZIndex = 82, Parent = box })
		floats[i] = { ic, f[3], f[4], i * 1.7 }
	end
	local fit = math.clamp(math.min(camera.ViewportSize.X / 1260, camera.ViewportSize.Y / 700), 0.4, 3)
	local sc = new("UIScale", { Scale = fit * 0.7, Parent = box })
	UI.tween(sc, 0.6, { Scale = fit }, Enum.EasingStyle.Back)
	local anim = RunService.RenderStepped:Connect(function()
		local t = os.clock()
		rays.Rotation = (t * 10) % 360
		for _, f in ipairs(floats) do
			f[1].Position = UDim2.fromOffset(f[1].Position.X.Offset, f[2] + math.sin(t * 1.3 + f[4]) * 10)
			f[1].Rotation = f[3] + math.sin(t * 0.9 + f[4]) * 4
		end
	end)
	introGui.Destroying:Connect(function() anim:Disconnect() end)
	task.spawn(function()
		local ps = play:FindFirstChildOfClass("UIScale")
		while ps and ps.Parent and play.Parent do
			UI.tween(ps, 0.6, { Scale = 1.06 }, Enum.EasingStyle.Sine)
			task.wait(0.6)
			if not ps.Parent then break end
			UI.tween(ps, 0.6, { Scale = 1 }, Enum.EasingStyle.Sine)
			task.wait(0.6)
		end
	end)
]==])
-- fade images too when PLAY is pressed
s = replaceOnce(s, [[			if dsc:IsA("UIStroke") then UI.tween(dsc, 0.3, { Transparency = 1 }) end
		end
		task.wait(0.4)
		orbit:Disconnect()]], [[			if dsc:IsA("UIStroke") then UI.tween(dsc, 0.3, { Transparency = 1 }) end
			if dsc:IsA("ImageLabel") then UI.tween(dsc, 0.3, { ImageTransparency = 1 }) end
		end
		task.wait(0.4)
		orbit:Disconnect()]])
-- window list: the scroll bar image fully hidden (a 1 px line stayed visible at thickness 0)
s = replaceOnce(s, "\tcontent.ScrollBarThickness = 0\n", "\tcontent.ScrollBarThickness = 0\n\tcontent.ScrollBarImageTransparency = 1\n")
Client.Source = s
return "title screen patched"
