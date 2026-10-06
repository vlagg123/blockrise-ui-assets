-- one-off patch (run in Edit): buttons
--  * the SKIP button on the build cinematic: owners get a clean "SKIP ▶▶"; everyone else gets a card that says what the
--    pass is: SKIP FOREVER, a permanent pass, no build animation on any building (not just this one), with the price
--  * Auto Build / Auto Train: no emojis, the text centred on the button
local function replaceOnce(src, old, new)
	local a, b = src:find(old, 1, true)
	assert(a, "not found: " .. old:sub(1, 80))
	assert(not src:find(old, b + 1, true), "found twice: " .. old:sub(1, 80))
	return src:sub(1, a - 1) .. new .. src:sub(b + 1)
end
local Client = game.StarterPlayer.StarterPlayerScripts.Client
local s = Client.Source
if s:find("SKIP FOREVER", 1, true) then return "already patched" end
s = replaceOnce(s, [[			local label = owned and "SKIP" or ("SKIP   \u{E002} " .. tostring(pass.price or 39))
			local b = UI.button(label, owned and T.blue or T.green, owned and T.blue2 or T.green2, { AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -28, 1, -28),
				Size = UDim2.fromOffset(owned and 190 or 250, 60), TextSize = 24, Shine = not owned, Parent = skipGui })
			-- the pass picture on the left of the button
			local img = Config.ProductImages and Config.ProductImages.skipanim
			if img then
				new("ImageLabel", { Name = "Pic", AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 6, 0.5, -4), Size = UDim2.fromOffset(50, 50),
					BackgroundTransparency = 1, Image = img, ScaleType = Enum.ScaleType.Fit, ZIndex = 4, Parent = b })
				local l = b:FindFirstChild("Label")
				if l then l.Position = UDim2.new(0.5, 24, 0, 3); l.Size = UDim2.new(1, -72, 1, -13) end
			end]], [[			local b
			if owned then
				b = UI.button("SKIP  ▶▶", T.blue, T.blue2, { AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -28, 1, -28), Size = UDim2.fromOffset(190, 60),
					TextSize = 24, Parent = skipGui })
			else
				-- a card that says what you buy: no more build animations, on every building, for good
				b = UI.button("", T.green, T.green2, { AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -28, 1, -28), Size = UDim2.fromOffset(350, 86),
					Shine = true, Parent = skipGui })
				local img = Config.ProductImages and Config.ProductImages.skipanim
				if img then
					new("ImageLabel", { Name = "Pic", AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 8, 0.5, -3), Size = UDim2.fromOffset(62, 62),
						BackgroundTransparency = 1, Image = img, ScaleType = Enum.ScaleType.Fit, ZIndex = 4, Parent = b })
				end
				local tx = img and 78 or 16
				local t1 = UI.label({ Position = UDim2.fromOffset(tx, 8), Size = UDim2.new(1, -tx - 90, 0, 30), Text = "SKIP FOREVER", Font = T.title, TextSize = 25,
					TextColor3 = Color3.new(1, 1, 1), ZIndex = 5, Parent = b })
				UI.textStroke(0.1, 2.5).Parent = t1
				local t2 = UI.label({ Position = UDim2.fromOffset(tx, 39), Size = UDim2.new(1, -tx - 90, 0, 36), Text = "Permanent pass: no build animation on any building, ever",
					Font = T.bold, TextSize = 14, TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top, TextColor3 = Color3.fromRGB(236, 255, 236), ZIndex = 5, Parent = b })
				UI.textStroke(0.3, 1.5).Parent = t2
				local pill = new("Frame", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, -3), Size = UDim2.fromOffset(72, 42), BackgroundColor3 = Color3.new(1, 1, 1),
					ZIndex = 5, Parent = b })
				UI.corner(12).Parent = pill
				new("UIStroke", { Thickness = 2.5, Color = T.ink, Parent = pill })
				UI.label({ Size = UDim2.fromScale(1, 1), Text = "\u{E002} " .. tostring(pass.price or 39), Font = T.title, TextSize = 21, TextColor3 = Color3.fromRGB(28, 130, 54),
					TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 6, Parent = pill })
			end]])
s = replaceOnce(s, [[	autoToggle("build", "Pass_autobuild", "AutoBuild", "🤖 Auto Build", Color3.fromRGB(120, 200, 255), T.blue2, 1)
	autoToggle("train", "Pass_autotrain", "AutoTrain", "🏋️ Auto Train", Color3.fromRGB(255, 160, 100), Color3.fromRGB(220, 80, 40), 2)]],
	[[	autoToggle("build", "Pass_autobuild", "AutoBuild", "Auto Build", Color3.fromRGB(120, 200, 255), T.blue2, 1)
	autoToggle("train", "Pass_autotrain", "AutoTrain", "Auto Train", Color3.fromRGB(255, 160, 100), Color3.fromRGB(220, 80, 40), 2)]])
s = replaceOnce(s, [[		local b = UI.button(label, c1, c2, { Size = UDim2.fromOffset(200, 44), TextSize = 17, LayoutOrder = order, Parent = autoBar })
]], [[		local b = UI.button(label, c1, c2, { Size = UDim2.fromOffset(200, 44), TextSize = 18, Font = T.title, LayoutOrder = order, Parent = autoBar })
		local lb0 = b:FindFirstChild("Label")
		if lb0 then lb0.TextXAlignment = Enum.TextXAlignment.Center end
]])
assert(loadstring(s), "compile Client")
Client.Source = s
return "buttons v2"
