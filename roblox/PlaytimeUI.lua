-- BlockRise Empire - Playtime gifts: a HUD timer to the next present + the gifts window
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local K = require(RS.Shared:WaitForChild("MenuKit"))

local M = {}
local c
local UI, T, new, Config
local PINK1, PINK2 = Color3.fromRGB(255, 140, 200), Color3.fromRGB(210, 60, 140)
local GIFT_COLS = { Color3.fromRGB(255, 120, 180), Color3.fromRGB(165, 110, 255), Color3.fromRGB(70, 170, 255), Color3.fromRGB(60, 200, 150),
	Color3.fromRGB(255, 170, 40), Color3.fromRGB(255, 90, 100), Color3.fromRGB(120, 200, 80), Color3.fromRGB(255, 200, 60) }
local ClaimRF
local secsBase, secsAt = 0, os.clock()
local lastSource, lastSourceAt -- the gift tile you just opened (the celebration starts there)

local function playSecs() return secsBase + (os.clock() - secsAt) end
local function claimed()
	local set = {}
	for n in string.gmatch(c.player:GetAttribute("GiftsClaimed") or "", "%d+") do set[tonumber(n)] = true end
	return set
end
local function fmt(s)
	s = math.max(0, math.floor(s))
	return string.format("%d:%02d", s // 60, s % 60)
end
-- same as the server: the best contract you can take right now
local function bestReward()
	local p = c.player
	local rep, lvl, str, reb = p:GetAttribute("Rep") or 0, p:GetAttribute("Level") or 1, p:GetAttribute("Strength") or 0, p:GetAttribute("Rebirths") or 0
	local b = 60
	for _, ct in ipairs(Config.Contracts) do
		if rep >= ct.reqRep and lvl >= ct.reqLevel and str >= (ct.reqStrength or 0) and reb >= (ct.reqRebirth or 0) then b = math.max(b, ct.reward) end
	end
	return b
end
-- the gift's contents as short chips
local function rewardChips(g)
	local out = {}
	if g.cash then
		local n = math.floor(bestReward() * g.cash)
		table.insert(out, { "$" .. (n >= 1e4 and Config.Short(n) or Config.FormatNum(n)), K.GREEN }) -- short ($780K): two chips fit the tile
	end
	if g.gems then table.insert(out, { g.gems .. " 💎", Color3.fromRGB(60, 160, 255) }) end
	if g.boost then
		local b = Config.Boosts[g.boost]
		table.insert(out, { "2x " .. string.upper(b and b.short or g.boost) .. " " .. math.floor((g.secs or 300) / 60) .. "M", Color3.fromRGB(255, 150, 40) })
	end
	if g.bp then table.insert(out, { "BLUEPRINT", Color3.fromRGB(80, 150, 255) }) end
	while #out > 2 do table.remove(out) end
	return out
end
local function nextGift()
	local done = claimed()
	local s = playSecs()
	for i, g in ipairs(Config.PlaytimeGifts) do
		if not done[i] then return i, g, g.mins * 60 - s end
	end
end

local function claim(i)
	local ok, res, msg = pcall(function() return ClaimRF:InvokeServer(i) end)
	if not (ok and res) then c.toast("⚠️ " .. tostring(msg or "Can't open it yet"), T.red) end
	return ok and res
end
---------------------------------------------------------------------------
-- The celebration when a gift opens: the gift pops and wiggles, bursts into confetti with a flash, the amount pops up,
-- and the coins / gems fly from the gift to their counters on the HUD (each one landing with a clink)
---------------------------------------------------------------------------
local function hudPill(kind)
	local hud = c.player:FindFirstChild("PlayerGui") and c.player.PlayerGui:FindFirstChild("HUD")
	local left = hud and hud:FindFirstChild("Left", true)
	if not left then return nil end
	for _, f in ipairs(left:GetChildren()) do
		if f:IsA("GuiObject") and f:FindFirstChild("Value") then
			local y = f.Position.Y.Offset
			if (kind == "cash" and y < 20) or (kind == "gems" and y >= 20 and y < 70) then return f end
		end
	end
	return nil
end

local function giftFX(src, d)
	local pg = c.player:FindFirstChild("PlayerGui")
	if not pg then return end
	-- (a ScreenGui that keeps the top-bar inset: positions here are the same as every window's AbsolutePosition)
	local gui = new("ScreenGui", { Name = "GiftFX", IgnoreGuiInset = false, DisplayOrder = 130, ResetOnSpawn = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, Parent = pg })
	task.delay(3.2, function() gui:Destroy() end)
	local k = c.uiScale and c.uiScale.Scale or 1
	local center
	if src and src.Parent and src.AbsoluteSize.X > 0 then
		center = src.AbsolutePosition + src.AbsoluteSize / 2
	else
		center = gui.AbsoluteSize / 2
	end
	local function at(v) return UDim2.fromOffset(v.X, v.Y) end
	-- 1) the gift itself pops and wiggles
	if src and src.Parent then
		local sc = src:FindFirstChild("GiftPop") or new("UIScale", { Name = "GiftPop", Parent = src })
		sc.Scale = 1
		UI.tween(sc, 0.12, { Scale = 1.16 }, Enum.EasingStyle.Back)
		task.spawn(function()
			for _, r in ipairs({ -9, 9, -7, 6, -3, 0 }) do
				if not src.Parent then return end
				UI.tween(src, 0.05, { Rotation = r })
				task.wait(0.05)
			end
			if sc.Parent then UI.tween(sc, 0.25, { Scale = 1 }, Enum.EasingStyle.Back) end
		end)
	end
	c.sound2D(c.S.Chime, 0.55, 1.25)
	task.wait(0.3)
	if not gui.Parent then return end
	-- 2) the burst: a flash ring and confetti in the gift colours
	local ring = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = at(center), Size = UDim2.fromOffset(20, 20), BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.25, ZIndex = 5, Parent = gui })
	new("UICorner", { CornerRadius = UDim.new(1, 0), Parent = ring })
	local rs = new("UIStroke", { Thickness = 6, Color = PINK1, Parent = ring })
	UI.tween(ring, 0.45, { Size = UDim2.fromOffset(280 * k, 280 * k), BackgroundTransparency = 1 })
	UI.tween(rs, 0.45, { Transparency = 1, Thickness = 1 })
	for i = 1, 22 do
		local col = (i % 4 == 0) and Color3.new(1, 1, 1) or GIFT_COLS[(i - 1) % #GIFT_COLS + 1]
		local sz = math.random(8, 14) * k
		local p = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = at(center), Size = UDim2.fromOffset(sz, sz * (i % 2 == 0 and 1 or 0.55)),
			BackgroundColor3 = col, BorderSizePixel = 0, Rotation = math.random(0, 360), ZIndex = 6, Parent = gui })
		if i % 3 == 0 then new("UICorner", { CornerRadius = UDim.new(1, 0), Parent = p }) end
		local a = (i / 22) * math.pi * 2 + math.random() * 0.4
		local out = center + Vector2.new(math.cos(a), math.sin(a)) * math.random(90, 170) * k
		UI.tween(p, 0.5, { Position = at(out), Rotation = p.Rotation + math.random(-200, 200) }, Enum.EasingStyle.Quad)
		task.delay(0.45, function()
			if p.Parent then UI.tween(p, 0.45, { Position = at(out + Vector2.new(0, 60 * k)), BackgroundTransparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In) end
		end)
	end
	-- 3) what you got, big, floating up
	local lines = {}
	if d.cash and d.cash > 0 then table.insert(lines, { "+" .. Config.FormatMoney(d.cash), Color3.fromRGB(120, 255, 120) }) end
	if d.gems and d.gems > 0 then table.insert(lines, { "+" .. Config.FormatNum(d.gems) .. " GEMS", Color3.fromRGB(120, 220, 255) }) end
	if d.boost then
		local b = Config.Boosts[d.boost]
		table.insert(lines, { string.upper(b and b.name or d.boost) .. " " .. math.floor((d.secs or 300) / 60) .. " MIN", Color3.fromRGB(255, 190, 80) })
	end
	if d.bp then table.insert(lines, { "+1 " .. string.upper(d.bp) .. " BLUEPRINT", Color3.fromRGB(150, 190, 255) }) end
	for li, ln in ipairs(lines) do
		local y0 = center.Y - 10 * k + (li - 1) * 40 * k
		local lbl = UI.label({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(center.X, y0), Size = UDim2.fromOffset(420 * k, 44 * k), Text = ln[1],
			Font = T.chunky, TextSize = math.floor(38 * k), TextColor3 = ln[2], TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 9, Parent = gui })
		local st = new("UIStroke", { Thickness = 3.5, Color = T.ink, LineJoinMode = Enum.LineJoinMode.Round, Parent = lbl })
		local ls = new("UIScale", { Scale = 0, Parent = lbl })
		task.delay((li - 1) * 0.12, function()
			if not lbl.Parent then return end
			UI.tween(ls, 0.3, { Scale = 1 }, Enum.EasingStyle.Back)
			task.wait(0.9)
			if not lbl.Parent then return end
			UI.tween(lbl, 0.6, { Position = UDim2.fromOffset(center.X, y0 - 70 * k), TextTransparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			UI.tween(st, 0.6, { Transparency = 1 })
		end)
	end
	-- 4) coins and gems fly to their counters
	local function fly(kind, icon, n)
		local pill = hudPill(kind)
		if not pill then return end
		local target = pill.AbsolutePosition + Vector2.new(26 * k, pill.AbsoluteSize.Y / 2)
		local landed = 0
		for i = 1, n do
			local s = 38 * k
			local h = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = at(center), Size = UDim2.fromOffset(s, s), BackgroundTransparency = 1, ZIndex = 8, Parent = gui })
			K.art(h, icon, UDim2.fromScale(1, 1), 8)
			local spread = center + Vector2.new(math.random(-80, 80), math.random(-60, 40)) * k
			task.delay(0.05 * i, function()
				if not h.Parent then return end
				UI.tween(h, 0.25, { Position = at(spread) }, Enum.EasingStyle.Quad)
				task.wait(0.3 + 0.04 * i)
				if not h.Parent then return end
				UI.tween(h, 0.45, { Position = at(target), Size = UDim2.fromOffset(s * 0.6, s * 0.6) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
				task.wait(0.45)
				if h.Parent then h:Destroy() end
				landed += 1
				-- the counter jumps with every one that lands
				if pill.Parent then
					local ps = pill:FindFirstChild("GiftPop") or new("UIScale", { Name = "GiftPop", Parent = pill })
					ps.Scale = 1.1
					UI.tween(ps, 0.18, { Scale = 1 }, Enum.EasingStyle.Back)
				end
				if landed % 2 == 1 then c.sound2D(c.S.Coins, 0.22, 1.3 + landed * 0.03) end
			end)
		end
	end
	if d.cash and d.cash > 0 then fly("cash", "cash", 8) end
	if d.gems and d.gems > 0 then fly("gems", "gem", 6) end
end

-- used by the HUD gift button
M.Next = function() if not c then return nil end return nextGift() end
M.Claim = function(i) return claim(i) end

function M.Show()
	local tok = c.openModal("Gifts", "Playtime Gifts", "", PINK1, PINK2)
	c.modalSub.Text = "⏱ " .. math.floor(playSecs() / 60) .. " min today"
	K.section(c.content, 1, "TODAY'S GIFTS", Color3.fromRGB(255, 190, 225), "play to open them all")
	local done = claimed()
	local grid = K.grid(c.content, 2, (_G.__CE_ListWidth and _G.__CE_ListWidth() or 780) >= 700 and 4 or 3, 268)
	local timers = {}
	for i, g in ipairs(Config.PlaytimeGifts) do
		local left = g.mins * 60 - playSecs()
		local o = { order = i, name = g.mins .. " minutes", icon = "gift", color = GIFT_COLS[(i - 1) % #GIFT_COLS + 1],
			stats = rewardChips(g) }
		if done[i] then
			o.dim = true
			o.status = { "✔ OPENED", K.GREEN }
		elseif left <= 0 then
			o.spin = true
			o.button = { "OPEN!", K.GREEN, function(b)
				c.click()
				-- the celebration starts at this gift (the window shows OPENED once it is done)
				local tile = b and b:FindFirstAncestor("Tile")
				lastSource, lastSourceAt = tile and tile:FindFirstChild("Art") or tile, os.clock()
				if claim(i) then
					local l = b and b:FindFirstChild("Label")
					if l then l.Text = "✔ OPENED" end
					task.delay(1.6, function() if c.live(tok) then M.Show() end end)
				end
			end, shine = true }
		else
			o.status = { "⏱ " .. fmt(left), K.LOCK }
		end
		local t = K.tile(grid, o)
		if not done[i] and left > 0 then
			local st = t:FindFirstChild("Status")
			local l = st and st:FindFirstChildOfClass("TextLabel")
			if l then timers[i] = { l, g } end
		end
	end
	K.note(c.content, 3, "New gifts every day. The timer keeps counting if you rejoin.")
	-- live countdowns; when one hits zero the window redraws with an OPEN button
	task.spawn(function()
		while c.live(tok) do
			task.wait(1)
			for i, e in pairs(timers) do
				local left = e[2].mins * 60 - playSecs()
				if left <= 0 then
					if c.live(tok) then M.Show() end
					return
				end
				if e[1].Parent then e[1].Text = "⏱ " .. fmt(left) end
			end
		end
	end)
end

function M.Init(ctx)
	c = ctx
	UI, T, new, Config = c.UI, c.T, c.new, c.Config
	ClaimRF = c.Remotes:WaitForChild("ClaimGift")
	local function sync()
		secsBase = c.player:GetAttribute("PlaySecs") or 0
		secsAt = os.clock()
	end
	c.player:GetAttributeChangedSignal("PlaySecs"):Connect(sync)
	sync()
	-- HUD widget under the menu buttons
	local w = UI.button("", PINK1, PINK2, { Position = UDim2.fromOffset(16, 606), Size = UDim2.fromOffset(148, 52), Radius = 14, Parent = c.legacy or c.gui })
	local function place() w.Position = UDim2.fromOffset(c.gui:GetAttribute("GiftX") or 16, (c.gui:GetAttribute("NavBottom") or 604) + 2) end
	c.gui:GetAttributeChangedSignal("NavBottom"):Connect(place)
	c.gui:GetAttributeChangedSignal("GiftX"):Connect(place)
	place()
	local icon = UI.label({ Position = UDim2.fromOffset(8, 0), Size = UDim2.fromOffset(36, 52), Text = "🎁", TextSize = 28, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 3, Parent = w })
	local top = UI.label({ Position = UDim2.fromOffset(46, 6), Size = UDim2.fromOffset(96, 18), Text = "NEXT GIFT", Font = T.black, TextSize = 12, ZIndex = 3, Parent = w })
	local line = UI.label({ Position = UDim2.fromOffset(46, 22), Size = UDim2.fromOffset(96, 24), Text = "", Font = T.title, TextSize = 20, ZIndex = 3, Parent = w })
	UI.textStroke(0.4, 1.5).Parent = line
	w.Activated:Connect(function()
		c.click()
		local i, _, left = nextGift()
		if i and left <= 0 then claim(i) else _G.__CE_Toggle("Gifts", M.Show) end
	end)
	local pulse = 0
	RunService.RenderStepped:Connect(function(dt)
		local i, g, left = nextGift()
		if not i then
			top.Text = "ALL GIFTS"
			line.Text = "✔ Done!"
			icon.Rotation = 0
			return
		end
		if left <= 0 then
			top.Text = "GIFT READY"
			line.Text = "OPEN! 🎉"
			pulse += dt
			icon.Rotation = math.sin(pulse * 10) * 12
		else
			top.Text = "NEXT GIFT"
			line.Text = fmt(left)
			icon.Rotation = 0
		end
	end)
	c.R.Feedback.OnClientEvent:Connect(function(kind, d)
		if kind == "GiftReady" then
			c.toast("🎁 A playtime gift is ready! Tap the gift button", PINK1, 3.5)
			c.sound2D(c.S.Chime, 0.5, 1.3)
		elseif kind == "GiftClaimed" then
			local g = Config.PlaytimeGifts[d.index]
			local parts = {}
			if d.cash and d.cash > 0 then table.insert(parts, Config.FormatMoney(d.cash)) end
			if d.gems then table.insert(parts, "💎 " .. d.gems) end
			if d.boost then table.insert(parts, (Config.Boosts[d.boost] and Config.Boosts[d.boost].name or d.boost) .. " " .. math.floor((d.secs or 300) / 60) .. " min") end
			if d.bp then table.insert(parts, "a " .. d.bp .. " Blueprint") end
			c.banner("🎁 GIFT OPENED!", (g and (g.mins .. " min gift: ") or "") .. table.concat(parts, " + "), PINK1)
			-- the celebration (from the gift you tapped, or the middle of the screen)
			local src = (lastSourceAt and os.clock() - lastSourceAt < 4) and lastSource or nil
			lastSource, lastSourceAt = nil, nil
			task.spawn(giftFX, src, d)
		end
	end)
end

return M
