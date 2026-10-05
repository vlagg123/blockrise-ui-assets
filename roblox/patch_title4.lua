-- one-off patch (run in Edit): logo v3 (EMPIRE lower), static logo, a hand-built premium PLAY button
-- (ink outline, green gradient face on a darker 3D lip, gloss, sweeping shine, text centred on the face)
local Client = game.StarterPlayer.StarterPlayerScripts.Client
local s = Client.Source
local function replaceOnce(src, old, new)
	local a, b = src:find(old, 1, true)
	assert(a, "not found: " .. old:sub(1, 80))
	assert(not src:find(old, b + 1, true), "found twice: " .. old:sub(1, 80))
	return src:sub(1, a - 1) .. new .. src:sub(b + 1)
end
s = replaceOnce(s, 'local LOGO = "rbxassetid://82912323552669"', 'local LOGO = "rbxassetid://130040957021057"')
s = replaceOnce(s, "\t\tlogo.Position = UDim2.fromOffset(cx, 270 + math.sin(t * 1.4) * 8)\n\t\tlogo.Rotation = math.sin(t * 0.8) * 1.2\n", "")
s = replaceOnce(s, [[	local play = UI.button("PLAY", T.green, nil, { Name = "PlayButton", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(cx, 628), Size = UDim2.fromOffset(440, 128),
		TextSize = 84, Font = Enum.Font.LuckiestGuy, ZIndex = 86, Shine = true, Visible = false, Parent = box })]], [==[
	local INK2 = Color3.fromRGB(20, 17, 32)
	local play = new("TextButton", { Name = "PlayButton", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(cx, 632), Size = UDim2.fromOffset(430, 128),
		BackgroundTransparency = 1, Text = "", AutoButtonColor = false, Visible = false, ZIndex = 86, Parent = box })
	new("UIScale", { Parent = play })
	-- dark green 3D lip under the face, thick ink outline around everything
	local lip = new("Frame", { Name = "Lip", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(24, 120, 52), BorderSizePixel = 0, ZIndex = 86, Parent = play })
	UI.corner(32).Parent = lip
	new("UIStroke", { Thickness = 6, Color = INK2, LineJoinMode = Enum.LineJoinMode.Round, Parent = lip })
	local face = new("Frame", { Name = "Face", Size = UDim2.new(1, 0, 1, -16), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, ZIndex = 87, Parent = play })
	UI.corner(32).Parent = face
	local faceGrad = new("UIGradient", { Color = ColorSequence.new(Color3.fromRGB(140, 250, 110), Color3.fromRGB(46, 196, 86)), Rotation = 90, Parent = face })
	local gloss = new("Frame", { Position = UDim2.fromOffset(16, 8), Size = UDim2.new(1, -32, 0.4, 0), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.7,
		BorderSizePixel = 0, ZIndex = 88, Parent = face })
	UI.corner(22).Parent = gloss
	-- a light band sweeps across every few seconds
	local sweepHolder = new("CanvasGroup", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 89, Parent = face })
	UI.corner(32).Parent = sweepHolder
	local sweep = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.35, BorderSizePixel = 0, Parent = sweepHolder })
	local sg = new("UIGradient", { Rotation = 20, Offset = Vector2.new(-1, 0), Parent = sweep,
		Transparency = NumberSequence.new({ NSK(0, 1), NSK(0.42, 1), NSK(0.5, 0.1), NSK(0.58, 1), NSK(1, 1) }) })
	local swTw = game:GetService("TweenService"):Create(sg, TweenInfo.new(0.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, false, 2.2), { Offset = Vector2.new(1, 0) })
	swTw:Play()
	play.Destroying:Connect(function() swTw:Cancel() end)
	-- the word, optically centred on the face (Luckiest Guy sits high in its line box)
	local playText = UI.label({ Name = "Text", Position = UDim2.fromOffset(0, 9), Size = UDim2.fromScale(1, 1), Text = "PLAY", Font = Enum.Font.LuckiestGuy, TextSize = 84,
		TextXAlignment = Enum.TextXAlignment.Center, TextYAlignment = Enum.TextYAlignment.Center, ZIndex = 90, Parent = face })
	new("UIStroke", { Thickness = 6, Color = INK2, LineJoinMode = Enum.LineJoinMode.Round, Parent = playText })
	new("UIGradient", { Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(225, 255, 215)), Rotation = 90, Parent = playText })
	-- hover brightens, press sinks the face onto the lip
	local G1, G2 = Color3.fromRGB(140, 250, 110), Color3.fromRGB(46, 196, 86)
	play.MouseEnter:Connect(function() faceGrad.Color = ColorSequence.new(G1:Lerp(Color3.new(1, 1, 1), 0.15), G2:Lerp(Color3.new(1, 1, 1), 0.12)) end)
	play.MouseLeave:Connect(function() faceGrad.Color = ColorSequence.new(G1, G2); face.Position = UDim2.fromOffset(0, 0) end)
	play.MouseButton1Down:Connect(function() face.Position = UDim2.fromOffset(0, 8) end)
	play.MouseButton1Up:Connect(function() face.Position = UDim2.fromOffset(0, 0) end)
]==])
Client.Source = s
return "title v4"
