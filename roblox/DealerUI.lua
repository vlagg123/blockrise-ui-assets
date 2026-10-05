-- BlockRise Empire - BlockRise Motors: the hold-E button on every display car. The server owns the ProximityPrompt
-- (HoldDuration 1.5 s, style Custom); this draws it: a chunky button with the price that fills up while you hold
-- E (or press and hold the button on touch), then buys / spawns / opens the Robux pass.
local RS = game:GetService("ReplicatedStorage")
local PPS = game:GetService("ProximityPromptService")
local TweenService = game:GetService("TweenService")

local M = {}
local c, UI, T, Config
local owned = {}
local ownedAt = 0
local shown = {} -- [prompt] = { gui, fill, refresh }

local GREEN, BLUE, GOLD = Color3.fromRGB(70, 214, 96), Color3.fromRGB(60, 160, 255), Color3.fromRGB(255, 176, 40)
local GREY = Color3.fromRGB(122, 128, 186)

local function refreshOwned(force)
	if not force and os.clock() - ownedAt < 2 then return end
	ownedAt = os.clock()
	local ok, okr, data = pcall(function() return c.Remotes:WaitForChild("VehicleAction"):InvokeServer("get") end)
	if ok and okr and type(data) == "table" then owned = data.owned or owned end
end

local function passOf(cfg)
	for _, p in ipairs(Config.Store.passes) do if p.key == cfg.pass then return p end end
end

-- what the button says and its colour for this player right now
local function state(cfg)
	if owned[cfg.id] or (cfg.pass and c.player:GetAttribute("Pass_" .. cfg.pass) == true) then
		return "SPAWN", BLUE
	end
	if cfg.pass then
		local p = passOf(cfg)
		return "GET  R$ " .. tostring(p and p.price or "?"), GOLD
	end
	local can = (c.player:GetAttribute("Money") or 0) >= cfg.price
	return "BUY  " .. Config.FormatMoney(cfg.price), can and GREEN or GREY
end

local function build(prompt, inputType)
	local cfg = Config.VehicleById[prompt:GetAttribute("VehicleId") or ""]
	if not cfg then return end
	local gui = UI.new("BillboardGui", { Name = "DealerButton", Adornee = prompt.Parent, Size = UDim2.fromOffset(270, 78), StudsOffset = Vector3.new(0, 0.5, 0),
		AlwaysOnTop = true, LightInfluence = 0, MaxDistance = 40, ResetOnSpawn = false, Active = true, Parent = c.player:WaitForChild("PlayerGui") })
	local holder = UI.new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = gui })
	local sc = UI.new("UIScale", { Scale = 0.6, Parent = holder })
	TweenService:Create(sc, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	-- the button (an ImageButton-like TextButton so touch players can press and hold it)
	local label, color = state(cfg)
	local btn = UI.button(label, color, nil, { Size = UDim2.new(1, -70, 0, 64), Position = UDim2.fromOffset(66, 6), TextSize = 26, ZIndex = 2, Parent = holder })
	-- fill that grows while you hold (clipped to the button face)
	local clip = UI.new("CanvasGroup", { Name = "Clip", Position = UDim2.fromOffset(4, 4), Size = UDim2.new(1, -8, 1, -18), BackgroundTransparency = 1, ZIndex = 3, Parent = btn })
	UI.corner(14).Parent = clip
	local fill = UI.new("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.55, BorderSizePixel = 0, Parent = clip })
	local lbl = btn:FindFirstChild("Label")
	if lbl then lbl.ZIndex = 5 end
	-- key badge on the left: E on keyboard, a hand on touch
	local key = UI.slice("circle", { Name = "Key", Position = UDim2.fromOffset(0, 4), Size = UDim2.fromOffset(62, 62), SliceScale = 0.25, ImageColor3 = Color3.new(1, 1, 1), ZIndex = 2, Parent = holder })
	local touch = inputType == Enum.ProximityPromptInputType.Touch
	local kl = UI.new("TextLabel", { Size = UDim2.new(1, 0, 1, -6), BackgroundTransparency = 1, Text = touch and "👆" or (inputType == Enum.ProximityPromptInputType.Gamepad and "X" or "E"),
		Font = T.chunky, TextSize = touch and 30 or 36, TextColor3 = T.ink, ZIndex = 3, Parent = key })
	local hold = UI.new("TextLabel", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 1, -16), Size = UDim2.fromOffset(60, 16), BackgroundTransparency = 1,
		Text = "HOLD", Font = T.chunky, TextSize = 13, TextColor3 = Color3.new(1, 1, 1), ZIndex = 4, Parent = key })
	UI.new("UIStroke", { Thickness = 2, Color = T.ink, Parent = hold })
	-- touch / mouse: press and hold the button itself
	btn.InputBegan:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.Touch or i.UserInputType == Enum.UserInputType.MouseButton1 then prompt:InputHoldBegin() end
	end)
	btn.InputEnded:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.Touch or i.UserInputType == Enum.UserInputType.MouseButton1 then prompt:InputHoldEnd() end
	end)
	local function refresh()
		local l2, c2 = state(cfg)
		if lbl then lbl.Text = l2 end
		UI.recolor(btn, c2)
	end
	shown[prompt] = { gui = gui, fill = fill, refresh = refresh, scale = sc }
	task.spawn(function()
		refreshOwned()
		if shown[prompt] then refresh() end
	end)
end

function M.Init(ctx)
	c = ctx
	UI, T, Config = c.UI, c.T, c.Config
	PPS.PromptShown:Connect(function(prompt, inputType)
		if prompt.Name ~= "DealerPrompt" or prompt.Style ~= Enum.ProximityPromptStyle.Custom then return end
		if shown[prompt] then shown[prompt].gui:Destroy() end
		build(prompt, inputType)
	end)
	PPS.PromptHidden:Connect(function(prompt)
		local s = shown[prompt]
		if not s then return end
		shown[prompt] = nil
		s.gui:Destroy()
	end)
	PPS.PromptButtonHoldBegan:Connect(function(prompt)
		local s = shown[prompt]
		if not s then return end
		s.fill.Size = UDim2.fromScale(0, 1)
		s.tw = TweenService:Create(s.fill, TweenInfo.new(prompt.HoldDuration, Enum.EasingStyle.Linear), { Size = UDim2.fromScale(1, 1) })
		s.tw:Play()
		c.sound2D(c.S.Click, 0.25, 0.9)
	end)
	PPS.PromptButtonHoldEnded:Connect(function(prompt)
		local s = shown[prompt]
		if not s then return end
		if s.tw then s.tw:Cancel() end
		TweenService:Create(s.fill, TweenInfo.new(0.2), { Size = UDim2.fromScale(0, 1) }):Play()
	end)
	PPS.PromptTriggered:Connect(function(prompt)
		local s = shown[prompt]
		if not s then return end
		c.click()
		s.scale.Scale = 1.12
		TweenService:Create(s.scale, TweenInfo.new(0.3, Enum.EasingStyle.Back), { Scale = 1 }):Play()
		task.delay(0.6, function()
			refreshOwned(true)
			if shown[prompt] then shown[prompt].refresh() end
		end)
	end)
	-- live price colour when your money changes; messages from the server
	c.player:GetAttributeChangedSignal("Money"):Connect(function()
		for _, s in pairs(shown) do s.refresh() end
	end)
	c.R.Feedback.OnClientEvent:Connect(function(kind, d)
		if kind == "DealerMsg" and d and d.text then c.toast(d.text, T.red, 2.8)
		elseif kind == "VehicleBought" then
			if d and d.id then owned[d.id] = true end
			for _, s in pairs(shown) do s.refresh() end
		end
	end)
end

return M
