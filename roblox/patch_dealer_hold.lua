-- one-off patch (run in Edit): the car dealer's hold-E button showed nothing while you held E (its fill sat in a
-- CanvasGroup, which a BillboardGui doesn't draw), so it looked broken. Now: a plain rounded fill grows across the
-- button, the key badge squeezes while you hold, and a green message says where your car is when it spawns.
local function replaceOnce(src, old, new)
	local a, b = src:find(old, 1, true)
	assert(a, "not found: " .. old:sub(1, 80))
	assert(not src:find(old, b + 1, true), "found twice: " .. old:sub(1, 80))
	return src:sub(1, a - 1) .. new .. src:sub(b + 1)
end
local D = game.StarterPlayer.StarterPlayerScripts.Client.DealerUI
local V = game.ServerScriptService.Game.VehicleService
local d, v = D.Source, V.Source
if d:find("DEALER_FILL", 1, true) then return "already patched" end

d = replaceOnce(d, [[	-- fill that grows while you hold (clipped to the button face)
	local clip = UI.new("CanvasGroup", { Name = "Clip", Position = UDim2.fromOffset(4, 4), Size = UDim2.new(1, -8, 1, -18), BackgroundTransparency = 1, ZIndex = 3, Parent = btn })
	UI.corner(14).Parent = clip
	local fill = UI.new("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.55, BorderSizePixel = 0, Parent = clip })]],
[[	-- DEALER_FILL: a rounded white fill that grows across the button face while you hold (no CanvasGroup: a
	-- BillboardGui doesn't draw those, so the old fill never showed)
	local fill = UI.new("Frame", { Name = "Fill", Position = UDim2.fromOffset(4, 4), Size = UDim2.new(0, 0, 1, -18), BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.4, BorderSizePixel = 0, ZIndex = 4, Parent = btn })
	UI.corner(14).Parent = fill
	local keyScale = UI.new("UIScale", { Parent = nil })]])
d = replaceOnce(d, [[	UI.new("UIStroke", { Thickness = 2, Color = T.ink, Parent = hold })
]], [[	UI.new("UIStroke", { Thickness = 2, Color = T.ink, Parent = hold })
	keyScale.Parent = key
]])
d = replaceOnce(d, [[	shown[prompt] = { gui = gui, fill = fill, refresh = refresh, scale = sc }]],
	[[	shown[prompt] = { gui = gui, fill = fill, refresh = refresh, scale = sc, key = keyScale }]])
d = replaceOnce(d, [[		s.fill.Size = UDim2.fromScale(0, 1)
		s.tw = TweenService:Create(s.fill, TweenInfo.new(prompt.HoldDuration, Enum.EasingStyle.Linear), { Size = UDim2.fromScale(1, 1) })
		s.tw:Play()]], [[		s.fill.Size = UDim2.new(0, 0, 1, -18)
		s.tw = TweenService:Create(s.fill, TweenInfo.new(prompt.HoldDuration, Enum.EasingStyle.Linear), { Size = UDim2.new(1, -8, 1, -18) })
		s.tw:Play()
		TweenService:Create(s.key, TweenInfo.new(0.12), { Scale = 0.88 }):Play()]])
d = replaceOnce(d, [[		if s.tw then s.tw:Cancel() end
		TweenService:Create(s.fill, TweenInfo.new(0.2), { Size = UDim2.fromScale(0, 1) }):Play()]], [[		if s.tw then s.tw:Cancel() end
		TweenService:Create(s.fill, TweenInfo.new(0.2), { Size = UDim2.new(0, 0, 1, -18) }):Play()
		TweenService:Create(s.key, TweenInfo.new(0.2, Enum.EasingStyle.Back), { Scale = 1 }):Play()]])
d = replaceOnce(d, [[		if kind == "DealerMsg" and d and d.text then c.toast(d.text, T.red, 2.8)]],
	[[		if kind == "DealerMsg" and d and d.text then c.toast(d.text, T.red, 2.8)
		elseif kind == "DealerOk" and d and d.text then c.toast(d.text, T.green, 3.5)]])

-- the server tells you when your car is out (it parks on a free spot next to you, often behind you)
v = replaceOnce(v, [[				local ok, msg = action(plr, "spawn", cfg.id)
				if not ok then ctx.feedback(plr, "DealerMsg", { text = "⚠️ " .. tostring(msg or "Can't spawn it here") }) end]],
[[				local ok, msg = action(plr, "spawn", cfg.id)
				if not ok then ctx.feedback(plr, "DealerMsg", { text = "⚠️ " .. tostring(msg or "Can't spawn it here") })
				else ctx.feedback(plr, "DealerOk", { text = "🚗 Your " .. cfg.name .. " is parked right next to you. Hop in!" }) end]])

assert(loadstring(d), "DealerUI compile")
assert(loadstring(v), "VehicleService compile")
D.Source = d
V.Source = v
return "dealer button fills while you hold E; spawn message"
