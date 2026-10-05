-- one-off patch (run in Edit): title screen v2 - fills the screen (scale follows the real screen size), cleaner:
-- big logo with rays, EMPIRE ribbon, tagline, a big PLAY button, four 3D icons on the sides (nothing overlaps)
local Client = game.StarterPlayer.StarterPlayerScripts.Client
local s = Client.Source
local function replaceBetween(src, startMark, endMark, repl)
	local a = src:find(startMark, 1, true)
	assert(a, "start not found: " .. startMark:sub(1, 60))
	local b = src:find(endMark, a, true)
	assert(b, "end not found: " .. endMark:sub(1, 60))
	return src:sub(1, a - 1) .. repl .. src:sub(b)
end
s = replaceBetween(s, "\tlocal Icons = require(RS.Shared:WaitForChild(\"Icons\"))\n\tlocal INK = Color3.fromRGB(20, 17, 32)\n\tlocal box", "\tlocal t0 = os.clock()\n", [==[
	local Icons = require(RS.Shared:WaitForChild("Icons"))
	local INK = Color3.fromRGB(20, 17, 32)
	local W, H = 1300, 760
	local box = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(W, H), BackgroundTransparency = 1, ZIndex = 81, Parent = intro })
	local cx = W / 2
	-- slow golden rays + glow behind the logo
	local rays = UI.slice("rays", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(cx, 230), Size = UDim2.fromOffset(1150, 1150), ImageColor3 = Color3.fromRGB(255, 205, 90),
		ImageTransparency = 0.78, ZIndex = 81, Parent = box })
	UI.slice("glow", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(cx, 230), Size = UDim2.fromOffset(1050, 560), ImageColor3 = Color3.fromRGB(255, 190, 70),
		ImageTransparency = 0.6, ZIndex = 81, Parent = box })
	-- logo
	local title = UI.label({ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromOffset(cx, 70), Size = UDim2.fromOffset(1200, 190), Text = "BLOCKRISE", Font = Enum.Font.LuckiestGuy,
		TextSize = 186, TextColor3 = Color3.new(1, 1, 1), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 84, Parent = box })
	new("UIStroke", { Thickness = 11, Color = INK, LineJoinMode = Enum.LineJoinMode.Round, Parent = title })
	new("UIGradient", { Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 248, 180)), ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 205, 60)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 140, 30)) }), Rotation = 90, Parent = title })
	-- EMPIRE ribbon
	local ribbon = new("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromOffset(cx, 262), Size = UDim2.fromOffset(540, 112), BackgroundTransparency = 1, ZIndex = 83, Parent = box })
	UI.slice("button", { ImageColor3 = Color3.fromRGB(240, 90, 70), ZIndex = 83, Parent = ribbon })
	local rs = new("CanvasGroup", { Position = UDim2.fromOffset(5, 5), Size = UDim2.new(1, -10, 1, -20), BackgroundTransparency = 1, ZIndex = 84, Parent = ribbon })
	UI.corner(14).Parent = rs
	new("ImageLabel", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Image = UI.PATTERN, ScaleType = Enum.ScaleType.Tile, TileSize = UDim2.fromOffset(110, 110),
		ImageTransparency = 0.3, Parent = rs })
	UI.slice("gloss", { ZIndex = 85, Parent = ribbon })
	local title2 = UI.label({ Position = UDim2.fromOffset(0, 6), Size = UDim2.new(1, 0, 1, -20), Text = "EMPIRE", Font = Enum.Font.LuckiestGuy, TextSize = 88,
		TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 86, Parent = ribbon })
	new("UIStroke", { Thickness = 7, Color = INK, LineJoinMode = Enum.LineJoinMode.Round, Parent = title2 })
	-- tagline
	local sub = UI.label({ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromOffset(cx, 398), Size = UDim2.fromOffset(1000, 50), Text = "From a garden fence to the city skyline",
		Font = Enum.Font.FredokaOne, TextSize = 40, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 84, Parent = box })
	new("UIStroke", { Thickness = 4, Color = INK, LineJoinMode = Enum.LineJoinMode.Round, Parent = sub })
	-- PLAY
	local play = UI.button("PLAY", T.green, nil, { Name = "PlayButton", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromOffset(cx, 500), Size = UDim2.fromOffset(460, 136),
		TextSize = 88, Font = Enum.Font.LuckiestGuy, ZIndex = 86, Shine = true, Parent = box })
	-- 3D icons on the sides (well clear of the text and the button)
	local floats = {}
	for i, f in ipairs({ { "cash", 110, 360, -12 }, { "gem", W - 110, 340, 10 }, { "mega", 250, 600, 8 }, { "store", W - 250, 590, -8 } }) do
		local ic = Icons.make(f[1], { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(f[2], f[3]), Size = UDim2.fromOffset(170, 170), Rotation = f[4], ZIndex = 82, Parent = box })
		floats[i] = { ic, f[3], f[4], i * 1.7 }
	end
	-- the screen fills the display: scale from the real size of this layer (the viewport isn't final when the game starts)
	local fit = 1
	local sc = new("UIScale", { Scale = 0.7, Parent = box })
	local function measure()
		local a = introGui.AbsoluteSize
		if a.X < 50 then a = camera.ViewportSize end
		return math.clamp(math.min(a.X / (W + 40), a.Y / (H + 30)), 0.3, 4)
	end
	fit = measure()
	sc.Scale = fit * 0.7
	UI.tween(sc, 0.6, { Scale = fit }, Enum.EasingStyle.Back)
	introGui:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		fit = measure()
		sc.Scale = fit
	end)
	local anim = RunService.RenderStepped:Connect(function()
		local t = os.clock()
		rays.Rotation = (t * 10) % 360
		for _, f in ipairs(floats) do
			f[1].Position = UDim2.fromOffset(f[1].Position.X.Offset, f[2] + math.sin(t * 1.3 + f[4]) * 12)
			f[1].Rotation = f[3] + math.sin(t * 0.9 + f[4]) * 4
		end
	end)
	introGui.Destroying:Connect(function() anim:Disconnect() end)
	task.spawn(function()
		local ps = play:FindFirstChildOfClass("UIScale")
		while ps and ps.Parent and play.Parent do
			UI.tween(ps, 0.6, { Scale = 1.05 }, Enum.EasingStyle.Sine)
			task.wait(0.6)
			if not ps.Parent then break end
			UI.tween(ps, 0.6, { Scale = 1 }, Enum.EasingStyle.Sine)
			task.wait(0.6)
		end
	end)
]==])
Client.Source = s
return "title v2"
