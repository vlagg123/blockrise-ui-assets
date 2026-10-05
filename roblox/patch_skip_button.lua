-- one-off patch (run in Edit): the SKIP button on the "building done" fly-around
--  * it always shows (before, it stayed hidden in the live game while the pass had no Creator Hub id yet)
--  * the pass picture instead of an emoji; free SKIP with the pass, "SKIP  R$39" without it
--  * while the pass has no id yet, a tap says it is coming soon
local function replaceOnce(src, old, new)
	local a, b = src:find(old, 1, true)
	assert(a, "not found: " .. old:sub(1, 80))
	assert(not src:find(old, b + 1, true), "found twice: " .. old:sub(1, 80))
	return src:sub(1, a - 1) .. new .. src:sub(b + 1)
end
local Client = game.StarterPlayer.StarterPlayerScripts.Client
local c = Client.Source
if c:find("SKIP_V2", 1, true) then return "already patched" end
c = replaceOnce(c, [[		if pass and (owned or (pass.id or 0) > 0 or RunService:IsStudio()) then
			skipGui = new("ScreenGui", { Name = "SkipCine", IgnoreGuiInset = true, ResetOnSpawn = false, DisplayOrder = 70, Parent = player:WaitForChild("PlayerGui") })
			new("UIScale", { Scale = uiScale.Scale, Parent = skipGui })
			local label = owned and "SKIP  ⏭" or ("SKIP  ⏭   R$" .. tostring(pass.price or 39))
			local b = UI.button(label, owned and T.blue or T.accent, owned and T.blue2 or T.accent2, { AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -28, 1, -28),
				Size = UDim2.fromOffset(owned and 170 or 230, 56), TextSize = 22, Shine = not owned, Parent = skipGui })]],
[[		if pass then -- SKIP_V2: always shown
			skipGui = new("ScreenGui", { Name = "SkipCine", IgnoreGuiInset = true, ResetOnSpawn = false, DisplayOrder = 70, Parent = player:WaitForChild("PlayerGui") })
			new("UIScale", { Scale = uiScale.Scale, Parent = skipGui })
			local label = owned and "SKIP" or ("SKIP   R$" .. tostring(pass.price or 39))
			local b = UI.button(label, owned and T.blue or T.accent, owned and T.blue2 or T.accent2, { AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -28, 1, -28),
				Size = UDim2.fromOffset(owned and 190 or 250, 60), TextSize = 24, Shine = not owned, Parent = skipGui })
			-- the pass picture on the left of the button
			local img = Config.ProductImages and Config.ProductImages.skipanim
			if img then
				new("ImageLabel", { Name = "Pic", AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 6, 0.5, -4), Size = UDim2.fromOffset(50, 50),
					BackgroundTransparency = 1, Image = img, ScaleType = Enum.ScaleType.Fit, ZIndex = 4, Parent = b })
				local l = b:FindFirstChild("Label")
				if l then l.Position = UDim2.new(0.5, 24, 0, 3); l.Size = UDim2.new(1, -72, 1, -13) end
			end
			-- a little pulse so it gets noticed
			local sc = b:FindFirstChildOfClass("UIScale")
			if sc then
				task.spawn(function()
					while b.Parent do
						UI.tween(sc, 0.45, { Scale = 1.06 }, Enum.EasingStyle.Sine)
						task.wait(0.5)
						if not b.Parent then break end
						UI.tween(sc, 0.45, { Scale = 1 }, Enum.EasingStyle.Sine)
						task.wait(0.5)
					end
				end)
			end]])
c = replaceOnce(c, [[					toast("⏭️ Skip Build Animation: coming soon (R$" .. tostring(pass.price or 39) .. ")", T.accent, 2.5)]],
	[[					toast("Skip Build Animation: coming soon (R$" .. tostring(pass.price or 39) .. ")", T.accent, 2.5)]])
assert(loadstring(c), "Client compile")
Client.Source = c
return "skip button patched"
