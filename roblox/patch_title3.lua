-- one-off patch (run in Edit): title screen v3 - rendered 3D logo (Blender), golden rays, a long thin loading bar
-- that follows the real loading (game, images and sounds, your saved data); PLAY pops in when everything is ready
local Client = game.StarterPlayer.StarterPlayerScripts.Client
local s = Client.Source
local function replaceBetween(src, startMark, endMark, repl)
	local a = src:find(startMark, 1, true)
	assert(a, "start not found: " .. startMark:sub(1, 60))
	local b = src:find(endMark, a, true)
	assert(b, "end not found: " .. endMark:sub(1, 60))
	return src:sub(1, a - 1) .. repl .. src:sub(b)
end
s = replaceBetween(s, "\tlocal Icons = require(RS.Shared:WaitForChild(\"Icons\"))\n\tlocal INK = Color3.fromRGB(20, 17, 32)\n", "\tlocal t0 = os.clock()\n", [==[
	local Icons = require(RS.Shared:WaitForChild("Icons"))
	local ContentProvider = game:GetService("ContentProvider")
	local LOGO = "rbxassetid://95302110763174"
	local W, H = 1300, 760
	local cx = W / 2
	local box = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(W, H), BackgroundTransparency = 1, ZIndex = 81, Parent = intro })
	-- slow golden rays + glow behind the logo
	local rays = UI.slice("rays", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(cx, 270), Size = UDim2.fromOffset(1250, 1250), ImageColor3 = Color3.fromRGB(255, 205, 90),
		ImageTransparency = 0.8, ZIndex = 81, Parent = box })
	UI.slice("glow", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(cx, 270), Size = UDim2.fromOffset(1150, 620), ImageColor3 = Color3.fromRGB(255, 190, 70),
		ImageTransparency = 0.62, ZIndex = 81, Parent = box })
	-- the logo (rendered in 3D), gently floating
	local logo = new("ImageLabel", { Name = "Logo", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(cx, 270), Size = UDim2.fromOffset(1060, 530), BackgroundTransparency = 1,
		Image = LOGO, ScaleType = Enum.ScaleType.Fit, ZIndex = 84, Parent = box })
	-- loading: label + long thin bar, then PLAY
	local load = new("Frame", { Name = "Loading", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromOffset(cx, 588), Size = UDim2.fromOffset(760, 80), BackgroundTransparency = 1, ZIndex = 84, Parent = box })
	local loadLbl = UI.label({ Size = UDim2.new(1, 0, 0, 36), Text = "LOADING 0%", Font = Enum.Font.LuckiestGuy, TextSize = 32, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 85, Parent = load })
	local loadStroke = new("UIStroke", { Thickness = 3, Color = Color3.fromRGB(20, 17, 32), Parent = loadLbl })
	local bar, fill = UI.bar({ Position = UDim2.fromOffset(0, 46), Size = UDim2.new(1, 0, 0, 22), ZIndex = 85 }, Color3.fromRGB(255, 205, 60))
	bar.Parent = load
	fill.Size = UDim2.fromScale(0, 1)
	local play = UI.button("PLAY", T.green, nil, { Name = "PlayButton", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(cx, 628), Size = UDim2.fromOffset(440, 128),
		TextSize = 84, Font = Enum.Font.LuckiestGuy, ZIndex = 86, Shine = true, Visible = false, Parent = box })
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
	-- real progress: the game itself, images and sounds, then your saved data
	local prog = { game = game:IsLoaded() and 1 or 0, assets = 0, data = player:GetAttribute("Loaded") == true and 1 or 0 }
	task.spawn(function()
		if not game:IsLoaded() then game.Loaded:Wait() end
		prog.game = 1
	end)
	task.spawn(function()
		local list = { LOGO, UI.SKIN, UI.PATTERN, Icons.ATLAS, gui }
		for _, snd in ipairs(game:GetService("SoundService"):GetDescendants()) do if snd:IsA("Sound") then table.insert(list, snd) end end
		local done = 0
		local watching = true
		task.spawn(function()
			while watching do
				local q = ContentProvider.RequestQueueSize
				prog.assets = math.max(prog.assets, math.min(0.95, done / math.max(1, done + q)))
				task.wait(0.1)
			end
		end)
		pcall(function() ContentProvider:PreloadAsync(list, function() done += 1 end) end)
		watching = false
		prog.assets = 1
	end)
	player:GetAttributeChangedSignal("Loaded"):Connect(function() if player:GetAttribute("Loaded") == true then prog.data = 1 end end)
	local shown, ready, started = 0, false, os.clock()
	local function showPlay()
		ready = true
		loadLbl.Text = "READY!"
		UI.tween(fill, 0.2, { ImageColor3 = T.green })
		task.delay(0.35, function()
			UI.tween(loadLbl, 0.25, { TextTransparency = 1 })
			UI.tween(loadStroke, 0.25, { Transparency = 1 })
			for _, d in ipairs(bar:GetDescendants()) do if d:IsA("ImageLabel") then UI.tween(d, 0.25, { ImageTransparency = 1 }) end end
			task.wait(0.2)
			load.Visible = false
			play.Visible = true
			local ps = play:FindFirstChildOfClass("UIScale")
			if ps then
				ps.Scale = 0.2
				UI.tween(ps, 0.45, { Scale = 1 }, Enum.EasingStyle.Back)
				task.wait(0.5)
				-- gentle pulse while it waits for you
				while ps.Parent and play.Parent do
					UI.tween(ps, 0.6, { Scale = 1.05 }, Enum.EasingStyle.Sine)
					task.wait(0.6)
					if not ps.Parent then break end
					UI.tween(ps, 0.6, { Scale = 1 }, Enum.EasingStyle.Sine)
					task.wait(0.6)
				end
			end
		end)
	end
	local anim = RunService.RenderStepped:Connect(function(dt)
		local t = os.clock()
		rays.Rotation = (t * 10) % 360
		logo.Position = UDim2.fromOffset(cx, 270 + math.sin(t * 1.4) * 8)
		logo.Rotation = math.sin(t * 0.8) * 1.2
		if not ready then
			-- each part creeps forward while it's busy, so the bar never looks stuck; it never passes the real total
			local el = t - started
			local creep = math.min(0.9, el / 6)
			local target = 0.25 * (prog.game > 0 and 1 or creep) + 0.55 * math.max(prog.assets, prog.assets < 1 and creep * 0.6 or 0) + 0.2 * (prog.data > 0 and 1 or creep * 0.5)
			if prog.game >= 1 and prog.assets >= 1 and prog.data >= 1 then target = 1 end
			shown = math.min(target, shown + math.max(0.004, (target - shown) * math.min(1, dt * 4)))
			fill.Size = UDim2.fromScale(math.clamp(shown, 0.02, 1), 1)
			loadLbl.Text = "LOADING " .. math.floor(shown * 100 + 0.5) .. "%"
			if shown >= 0.999 and target >= 1 and t - started > 1.2 then showPlay() end
		end
	end)
	introGui.Destroying:Connect(function() anim:Disconnect() end)
]==])
Client.Source = s
return "title v3"
