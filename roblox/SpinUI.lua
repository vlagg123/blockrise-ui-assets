-- BlockRise Empire - Lucky Spin (a casino-style prize reel), promo codes and the invite button (small HUD row next to the gift)
-- The reel: a velvet well in a golden frame with blinking bulbs, prize tiles coloured by rarity, a glowing selector.
-- Every prize and its exact chance is listed in the window (Roblox rules for paid random items).
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local MarketplaceService = game:GetService("MarketplaceService")
local SocialService = game:GetService("SocialService")
local TweenService = game:GetService("TweenService")
local K = require(RS.Shared:WaitForChild("MenuKit"))

local M = {}
local c
local UI, T, new, Config
local GOLD1, GOLD2 = Color3.fromRGB(255, 210, 70), Color3.fromRGB(235, 130, 20)
local C3 = Color3.fromRGB
local SpinRF, CodeRF
local rng = Random.new()
-- the spin in progress lives here, not in the window: closing the window doesn't stop it (the prize is the server's
-- anyway) and opening it again shows the reel where it is now, as if you never left.
--   cur = { idx, data, t0, ends, jitter, items (the reel), done }
local cur
local asking = false -- (the server is being asked for a spin)
local SPIN_T, PAUSE_T, SETTLE_T = 4.4, 0.12, 0.55
local TARGET = 50 -- the tile the reel lands on
local function busy() return asking or (cur ~= nil and os.clock() < cur.ends) end
-- an update restart is about to move everyone: no new spins (it would land in the new server)
local function updating()
	local ua = RS:GetAttribute("UpdateAt")
	return ua ~= nil and workspace:GetServerTimeNow() > ua - 12
end
local function quintOut(a) return 1 - (1 - a) ^ 5 end
local function backOut(a)
	local s = 1.70158
	a -= 1
	return 1 + (s + 1) * a * a * a + s * a * a
end
local codeTok, codeMsg

-- rarities: label + colour (the game's own rarity colours)
local RAR = {
	common = { "COMMON", K.RAR.common }, uncommon = { "UNCOMMON", K.RAR.uncommon }, rare = { "RARE", K.RAR.rare },
	epic = { "EPIC", K.RAR.epic }, legend = { "LEGENDARY", K.RAR.legend }, mythic = { "MYTHIC", K.RAR.mythic },
}
local RANK = { common = 1, uncommon = 2, rare = 3, epic = 4, legend = 5, mythic = 6 }
local function rarOf(p) return RAR[p.rarity or "common"] or RAR.common end

local function fmtLong(s)
	s = math.max(0, math.floor(s))
	return string.format("%d:%02d:%02d", s // 3600, (s % 3600) // 60, s % 60)
end
local function freeLeft()
	return (c.player:GetAttribute("SpinNext") or 0) - os.time()
end
local function packOf(key)
	for _, p in ipairs(Config.Store.products) do if p.key == key then return p end end
end
local totalWeight = 0
local function odds(p)
	if totalWeight == 0 then for _, q in ipairs(Config.Spin.prizes) do totalWeight += q.weight end end
	return p.weight / totalWeight * 100
end
local function pctText(p)
	local pct = odds(p)
	if pct < 1 then return string.format("%.2f%%", pct) elseif pct < 10 then return string.format("%.1f%%", pct) end
	return math.floor(pct + 0.5) .. "%"
end

-- prize art: an atlas icon (or the Thunderclap's own picture)
local function prizeArt(p)
	if p.art == "storm" then return (Config.StormHammer and Config.StormHammer.icon) or "up_power" end
	if p.art then return p.art end
	local n = string.lower(p.name or "")
	if n:find("gem") then return "gem" end
	if n:find("cash") then return "cash" end
	return p.icon
end

local TILE, GAP = 136, 12
local function tile(parent, p, x)
	local r = rarOf(p)
	local f = new("Frame", { Name = "Prize", Position = UDim2.fromOffset(x, 0), Size = UDim2.fromOffset(TILE, TILE + 16), BackgroundTransparency = 1, ZIndex = 3, Parent = parent })
	UI.slice("tile", { Name = "Bg", ImageColor3 = K.TILE:Lerp(r[2], RANK[p.rarity or "common"] >= 5 and 0.35 or 0.12), ZIndex = 1, Parent = f })
	local art = prizeArt(p)
	K.artBox(f, art, r[2], { Position = UDim2.fromOffset(7, 7), Size = UDim2.new(1, -14, 0, 92), Spin = RANK[p.rarity or "common"] >= 3,
		IconScale = type(art) == "string" and art:find("^rbxassetid://") and 1.1 or nil })
	-- name, and the rarity in its colour under it (nothing covers the picture)
	K.text({ Position = UDim2.fromOffset(6, 101), Size = UDim2.new(1, -12, 0, 24), Text = p.name, TextSize = 17, Max = 17,
		TextXAlignment = Enum.TextXAlignment.Center, TextColor3 = K.DARK, Parent = f })
	K.text({ Position = UDim2.fromOffset(6, 125), Size = UDim2.new(1, -12, 0, 20), Text = r[1], Font = T.chunky, TextSize = 15, Max = 15,
		TextXAlignment = Enum.TextXAlignment.Center, TextColor3 = r[2]:Lerp(Color3.new(0, 0, 0), 0.15), Parent = f })
	return f
end

local function weightedRandom()
	local r = math.random() * totalWeight
	for i, p in ipairs(Config.Spin.prizes) do
		r -= p.weight
		if r <= 0 then return i end
	end
	return 1
end

-- light card with a title, a second line and a button on the right
local function controlRow(order, h)
	local f = new("Frame", { Name = "Row", Size = UDim2.new(1, 0, 0, h), BackgroundTransparency = 1, LayoutOrder = order, ZIndex = 2, Parent = c.content })
	UI.slice("tile", { Name = "Bg", ImageColor3 = K.TILE, ZIndex = 1, Parent = f })
	return f
end

-- a row of little light bulbs along an edge; they chase each other like a casino sign
local function bulbs(parent, y, n, list)
	for i = 1, n do
		local b = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new((i - 0.5) / n, 0, y, 0), Size = UDim2.fromOffset(9, 9), BackgroundColor3 = GOLD1,
			BorderSizePixel = 0, ZIndex = 6, Parent = parent })
		UI.corner(5).Parent = b
		table.insert(list, b)
	end
end

function M.Show()
	local tok = c.openModal("Spin", "Lucky Spin", "", GOLD1, GOLD2)
	-- (the window never waits for the server: the timers are already on the player)
	task.spawn(function() pcall(function() SpinRF:InvokeServer("get") end) end)
	odds(Config.Spin.prizes[1])
	local restricted = c.player:GetAttribute("PaidRandomRestricted") == true

	-- the teaser: the mythic prize
	local top
	for _, p in ipairs(Config.Spin.prizes) do if not top or RANK[p.rarity or "common"] > RANK[top.rarity or "common"] then top = p end end
	if top then
		K.banner(c.content, 1, { name = "WIN THE " .. string.upper(top.name), line = "The rarest prize on the reel: " .. pctText(top) .. " every spin. Feeling lucky?",
			icon = prizeArt(top), color = rarOf(top)[2], tint = C3(255, 200, 225), height = 112 })
	end

	-- the reel: velvet well, golden frame, chasing bulbs, glowing selector
	local reelSlot = new("Frame", { Name = "Reel", Size = UDim2.new(1, 0, 0, 214), BackgroundTransparency = 1, LayoutOrder = 2, ZIndex = 2, Parent = c.content })
	local reel = new("Frame", { Name = "Box", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 2, Parent = reelSlot })
	local well = new("Frame", { Name = "Well", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 1, Parent = reel })
	UI.corner(22).Parent = well
	new("UIGradient", { Color = ColorSequence.new(C3(58, 28, 96), C3(22, 10, 40)), Rotation = 90, Parent = well })
	local frameStroke = new("UIStroke", { Thickness = 6, Color = GOLD1, Parent = well })
	new("UIGradient", { Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, C3(255, 240, 160)), ColorSequenceKeypoint.new(0.5, GOLD2), ColorSequenceKeypoint.new(1, C3(255, 240, 160)) }),
		Rotation = 90, Parent = frameStroke })
	local lights = {}
	bulbs(reel, 0, 26, lights)
	bulbs(reel, 1, 26, lights)
	local clip = new("Frame", { Name = "Clip", Position = UDim2.fromOffset(14, 22), Size = UDim2.new(1, -28, 1, -44), BackgroundTransparency = 1, ClipsDescendants = true, ZIndex = 2, Parent = reel })
	local strip = new("Frame", { Position = UDim2.fromOffset(0, 9), Size = UDim2.fromOffset(60 * (TILE + GAP), TILE + 16), BackgroundTransparency = 1, ZIndex = 3, Parent = clip })
	-- the edges fade into the dark, so your eye goes to the middle
	for _, side in ipairs({ 0, 1 }) do
		local fade = new("Frame", { AnchorPoint = Vector2.new(side, 0), Position = UDim2.fromScale(side, 0), Size = UDim2.new(0.22, 0, 1, 0), BackgroundColor3 = C3(36, 17, 64),
			BorderSizePixel = 0, ZIndex = 7, Parent = clip })
		new("UIGradient", { Rotation = side == 0 and 0 or 180, Transparency = NumberSequence.new(0, 1), Parent = fade })
	end
	-- the same reel as before while a spin is on (or just ended): you come back to it where it is
	local items
	if cur and os.clock() < cur.ends + 30 then
		items = cur.items
		if cur.done and items[TARGET] == cur.idx then
			-- it already stopped: the prize and its neighbours stand in the middle (tile 4), where the next spin starts
			for k = -3, 3 do items[4 + k] = items[TARGET + k] end
		end
	else
		items = {}
		for i = 1, 60 do items[i] = weightedRandom() end
	end
	local tiles = {}
	for i = 1, 60 do tiles[i] = tile(strip, Config.Spin.prizes[items[i]], (i - 1) * (TILE + GAP)) end
	-- selector: a glowing golden frame with arrows and a soft beam
	local marker = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(TILE + 16, TILE + 30), BackgroundTransparency = 1,
		ZIndex = 8, Parent = reel })
	UI.corner(18).Parent = marker
	local markStroke = new("UIStroke", { Thickness = 5, Color = GOLD1, Parent = marker })
	local markScale = new("UIScale", { Parent = marker })
	-- the soft light inside the golden frame: it IS the frame's inside, so it is never taller than the frame and it
	-- grows with it on every tick
	local beam = new("Frame", { Name = "Beam", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(1, -2, 1, -2),
		BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.88, ZIndex = 8, Parent = marker })
	UI.corner(17).Parent = beam
	for _, y in ipairs({ 0, 1 }) do
		local tri = new("TextLabel", { AnchorPoint = Vector2.new(0.5, y), Position = UDim2.new(0.5, 0, y, y == 0 and -6 or 6), Size = UDim2.fromOffset(40, 30), BackgroundTransparency = 1,
			Text = y == 0 and "▼" or "▲", TextSize = 30, Font = Enum.Font.GothamBlack, TextColor3 = GOLD1, ZIndex = 9, Parent = reel })
		UI.textStroke(0, 3).Parent = tri
	end
	-- the big word over the reel when you win (RARE! EPIC! LEGENDARY! MYTHIC!)
	local shout = K.text({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(1, 0, 0, 70), Text = "", Font = T.chunky, TextSize = 64, Max = 64,
		TextColor3 = Color3.new(1, 1, 1), Stroke = 5, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 12, Parent = reel })
	local shoutGrad = new("UIGradient", { Rotation = 90, Parent = shout })
	local shoutScale = new("UIScale", { Scale = 0, Parent = shout })
	local function centerOn(i, jitter)
		-- the reel is scaled with the UI: measure a tile to get the design width of the clip area
		local sc = tiles[1].AbsoluteSize.X / TILE
		local w = sc > 0.05 and clip.AbsoluteSize.X / sc or 740
		return -((i - 1) * (TILE + GAP) + TILE / 2 + (jitter or 0)) + w / 2
	end
	task.defer(function() strip.Position = UDim2.fromOffset(centerOn(4), 9) end)

	-- status + buttons
	local ctrl = controlRow(3, 104)
	local status = K.text({ Position = UDim2.fromOffset(20, 14), Size = UDim2.new(1, -400, 0, 36), Text = "", Font = T.chunky, TextSize = 28, Max = 28, Parent = ctrl })
	local sub = K.text({ Position = UDim2.fromOffset(20, 56), Size = UDim2.new(1, -400, 0, 26), Text = "", TextSize = 17, Max = 17, TextColor3 = K.SUB, Parent = ctrl })
	local btn = UI.button("SPIN!", K.GREEN, nil, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -18, 0.5, 0), Size = UDim2.fromOffset(360, 66), TextSize = 30,
		Font = T.chunky, ZIndex = 7, Shine = true, Parent = ctrl })
	local btnLbl = btn:FindFirstChild("Label")
	local p1 = packOf("spin1")
	local robuxBtn = UI.button("SPIN  \u{E002} " .. tostring(p1 and p1.price or 19), K.GREEN, nil, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -18, 0.5, 0),
		Size = UDim2.fromOffset(190, 66), TextSize = 25, Font = T.chunky, ZIndex = 7, Shine = true, Parent = ctrl })
	local gemBtn = UI.button(tostring(Config.Spin.gemCost), C3(60, 170, 255), nil, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -218, 0.5, 0),
		Size = UDim2.fromOffset(160, 66), TextSize = 27, Font = T.chunky, ZIndex = 7, Icon = "gem", Parent = ctrl })
	local mode = "free"
	local resultUntil = 0
	local statusScale = new("UIScale", { Parent = status })
	local function refresh()
		if not c.live(tok) then return end
		local stText
		local left = freeLeft()
		local extra = c.player:GetAttribute("SpinExtra") or 0
		local gems = c.player:GetAttribute("Gems") or 0
		if updating() then
			mode = "update"
			stText = "UPDATE IN PROGRESS"
			if btnLbl then btnLbl.Text = "🔄 UPDATING..." end
		elseif left <= 0 then
			mode = "free"
			stText = "FREE SPIN READY!"
			if btnLbl then btnLbl.Text = "FREE SPIN!" end
		elseif extra > 0 then
			mode = "free"
			stText = extra .. " SPIN" .. (extra == 1 and "" or "S") .. " WAITING"
			if btnLbl then btnLbl.Text = "SPIN! (" .. extra .. ")" end
		elseif restricted then
			-- Roblox policy: no paid spins in this region, only the free one
			mode = "wait"
			stText = "NEXT FREE SPIN"
			if btnLbl then btnLbl.Text = "⏱ " .. fmtLong(left) end
		else
			mode = "paid"
			stText = "SPIN AGAIN?"
		end
		btn.Visible = mode ~= "paid"
		UI.recolor(btn, (mode == "wait" or mode == "update") and K.LOCK or K.GREEN)
		robuxBtn.Visible = mode == "paid"
		gemBtn.Visible = mode == "paid"
		UI.recolor(gemBtn, gems >= Config.Spin.gemCost and C3(60, 170, 255) or K.LOCK)
		sub.Text = mode == "update" and "Spin again in the new server - your spins are saved" or
			((left > 0 and ("Free spin in " .. fmtLong(left)) or "One free spin every 4 hours") .. (restricted and "" or ("   ·   you have " .. Config.FormatNum(gems) .. " 💎")))
		if os.clock() >= resultUntil then
			status.Text = stText
			status.TextColor3 = K.DARK
		end
	end
	refresh()
	-- the bulbs chase, faster while the reel turns
	local conn
	local phase = 0
	conn = RunService.Heartbeat:Connect(function(dt)
		if not c.live(tok) then conn:Disconnect() return end
		phase += dt * (busy() and 14 or 4)
		local k = math.floor(phase) % 3
		for i, b in ipairs(lights) do
			b.BackgroundColor3 = (i % 3 == k) and Color3.new(1, 1, 1) or GOLD1
			b.BackgroundTransparency = (i % 3 == k) and 0 or 0.35
		end
		beam.BackgroundTransparency = 0.86 + 0.05 * math.sin(os.clock() * 3)
		if not busy() then refresh() end
	end)
	local doSpin
	local waitingBuy = 0
	local lastExtra = c.player:GetAttribute("SpinExtra") or 0
	-- a Robux spin that was just bought starts by itself
	local extraConn = c.player:GetAttributeChangedSignal("SpinExtra"):Connect(function()
		local now = c.player:GetAttribute("SpinExtra") or 0
		if now > lastExtra and os.clock() - waitingBuy < 90 and c.live(tok) and not busy() then
			waitingBuy = 0
			task.defer(doSpin)
		end
		lastExtra = now
	end)
	task.spawn(function()
		while c.live(tok) do task.wait(1) end
		extraConn:Disconnect()
	end)
	btn.Activated:Connect(function()
		if busy() then return end
		c.click()
		if mode == "update" then c.toast("🔄 An update is starting - spin again in the new server", T.accent, 3) return end
		if mode == "wait" then c.toast("⏱ Your next free spin isn't ready yet", T.muted, 2.5) return end
		doSpin()
	end)
	gemBtn.Activated:Connect(function()
		if busy() then return end
		c.click()
		if (c.player:GetAttribute("Gems") or 0) < Config.Spin.gemCost then
			c.toast("💎 Not enough Gems. Spin with Robux or get Gems in the Store", T.red, 3)
			return
		end
		doSpin()
	end)
	robuxBtn.Activated:Connect(function()
		if busy() then return end
		c.click()
		if p1 and (p1.id or 0) > 0 then
			waitingBuy = os.clock()
			MarketplaceService:PromptProductPurchase(c.player, p1.id)
		else
			c.toast("🎰 Robux spins are coming soon", T.muted, 2.5)
		end
	end)

	-- the win, louder the rarer it is
	local function celebrate(p, t)
		local r = rarOf(p)
		local rank = RANK[p.rarity or "common"]
		local bg = t and t:FindFirstChild("Bg")
		if bg then UI.tween(bg, 0.25, { ImageColor3 = K.TILE:Lerp(r[2], 0.55) }) end
		local ps = new("UIScale", { Scale = 1.18, Parent = t })
		UI.tween(ps, 0.45, { Scale = 1 }, Enum.EasingStyle.Back)
		markStroke.Color = r[2]
		frameStroke.Color = r[2]
		task.delay(2.5, function() if markStroke.Parent then markStroke.Color = GOLD1; frameStroke.Color = GOLD1 end end)
		if rank >= 3 then
			shout.Text = r[1] .. "!"
			shoutGrad.Color = ColorSequence.new(Color3.new(1, 1, 1), r[2]:Lerp(Color3.new(1, 1, 1), 0.2))
			shoutScale.Scale = 0
			UI.tween(shoutScale, 0.35, { Scale = rank >= 5 and 1.15 or 1 }, Enum.EasingStyle.Back)
			task.delay(1.6, function() if shout.Parent then UI.tween(shoutScale, 0.25, { Scale = 0 }, Enum.EasingStyle.Back, Enum.EasingDirection.In) end end)
		end
		if rank >= 5 then
			c.sound2D(c.S.Fanfare, 0.6, 1)
			local char = c.player.Character
			if char and char:FindFirstChild("HumanoidRootPart") then c.emit(char.HumanoidRootPart.Position, "confetti", nil, 160) end
			-- the reel shakes
			task.spawn(function()
				for i = 1, 10 do
					if not reel.Parent then break end
					reel.Position = UDim2.fromOffset(math.random(-6, 6), math.random(-3, 3))
					task.wait(0.03)
				end
				reel.Position = UDim2.new()
			end)
		elseif rank >= 3 then
			c.sound2D(c.S.Chime, 0.6, 1.1)
			c.sound2D(c.S.Coins, 0.5, 1.15)
		else
			c.sound2D(c.S.Coins, 0.6, 1.1)
		end
	end

	-- the reel follows the clock (not a tween you have to wait for): a spin can start in one window and be watched in
	-- the next, and nothing gets stuck when the window closes in the middle
	local function landed(sp)
		local p = Config.Spin.prizes[sp.idx]
		local text = p.name
		if p.kind == "cash" and sp.data.cash then text = Config.FormatMoney(sp.data.cash) .. " " .. (p.jackpot and "JACKPOT!" or "cash") end
		return p, text
	end
	local function finish(sp)
		if sp.done then return end
		sp.done = true
		local p, text = landed(sp)
		celebrate(p, tiles[TARGET])
		resultUntil = os.clock() + 3.5
		status.Text = "YOU WON: " .. string.upper(text)
		status.TextColor3 = rarOf(p)[2]:Lerp(Color3.new(0, 0, 0), 0.2)
		statusScale.Scale = 1.15
		UI.tween(statusScale, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
		-- the next spin starts from tile 4: the prize AND its neighbours (all you can see) are copied there, so the
		-- reset can't be seen (before, the tiles left and right of the prize turned into other prizes)
		task.delay(1.4, function()
			if not c.live(tok) or busy() or cur ~= sp then return end
			for k = -3, 3 do
				local from, to = TARGET + k, 4 + k
				items[to] = items[from]
				local oldBg = tiles[from]:FindFirstChild("Bg")
				tiles[to]:Destroy()
				tiles[to] = tile(strip, Config.Spin.prizes[items[to]], (to - 1) * (TILE + GAP))
				-- the winner keeps its glow and fades back like it would have
				local bg = tiles[to]:FindFirstChild("Bg")
				if k == 0 and bg and oldBg then
					local normal = bg.ImageColor3
					bg.ImageColor3 = oldBg.ImageColor3
					UI.tween(bg, 0.8, { ImageColor3 = normal })
				end
			end
			strip.Position = UDim2.fromOffset(centerOn(4), 9)
		end)
		refresh()
	end
	local function play(sp)
		local lastTick
		local conn
		conn = RunService.RenderStepped:Connect(function()
			if not c.live(tok) or not strip.Parent then conn:Disconnect() return end
			if tiles[1].AbsoluteSize.X <= 0 then return end -- (the window is still opening)
			local x0, x1, x2 = centerOn(4), centerOn(TARGET, sp.jitter), centerOn(TARGET)
			local el = os.clock() - sp.t0
			local x
			if el < SPIN_T then
				x = x0 + (x1 - x0) * quintOut(el / SPIN_T)
			elseif el < SPIN_T + PAUSE_T then
				x = x1
			elseif el < SPIN_T + PAUSE_T + SETTLE_T then
				x = x1 + (x2 - x1) * backOut((el - SPIN_T - PAUSE_T) / SETTLE_T)
			else
				x = x2
			end
			strip.Position = UDim2.fromOffset(x, 9)
			local n = math.floor(-x / (TILE + GAP))
			if n ~= lastTick then
				if lastTick then
					c.sound2D(c.S.Click, 0.18, 1.4)
					markScale.Scale = 1.06
					UI.tween(markScale, 0.1, { Scale = 1 })
				end
				lastTick = n
			end
			if el >= SPIN_T + PAUSE_T + SETTLE_T then
				conn:Disconnect()
				finish(sp)
			end
		end)
	end

	doSpin = function()
		if busy() then return end
		if updating() then c.toast("🔄 An update is starting - spin again in the new server", T.accent, 3) return end
		asking = true
		local ok, res, data = pcall(function() return SpinRF:InvokeServer("spin") end)
		asking = false
		if not (ok and res) then
			c.toast("⚠️ " .. tostring(data or "Can't spin right now"), T.red, 3)
			return
		end
		local sp = { idx = data.index, data = data, t0 = os.clock(), items = items,
			-- lands anywhere on the prize (near its left edge, its right edge, or the middle: a new spot every spin),
			-- then glides exactly onto the frame
			jitter = (rng:NextNumber() * 2 - 1) * TILE * 0.44 }
		sp.ends = sp.t0 + SPIN_T + PAUSE_T + SETTLE_T
		cur = sp
		items[TARGET] = sp.idx
		if c.live(tok) then
			shoutScale.Scale = 0
			-- the tile the reel will land on shows the prize
			tiles[TARGET]:Destroy()
			tiles[TARGET] = tile(strip, Config.Spin.prizes[sp.idx], (TARGET - 1) * (TILE + GAP))
			play(sp)
		end
		-- the window was closed before the reel stopped: the win is announced anyway
		task.delay(sp.ends - os.clock() + 0.15, function()
			if sp.done then return end
			sp.done = true
			local p, text = landed(sp)
			c.banner(RANK[p.rarity or "common"] >= 5 and "🤑 " .. rarOf(p)[1] .. "!" or "🎰 YOU WON!", (p.icon or "") .. " " .. text, GOLD1)
		end)
	end
	-- coming back: a spin still turning goes on from where it is; one that just stopped shows what it won
	if cur and os.clock() < cur.ends then
		play(cur)
	elseif cur and os.clock() < cur.ends + 3.5 then
		local p, text = landed(cur)
		resultUntil = cur.ends + 3.5
		status.Text = "YOU WON: " .. string.upper(text)
		status.TextColor3 = rarOf(p)[2]:Lerp(Color3.new(0, 0, 0), 0.2)
	end

	-- spin packs (Robux)
	local pack = packOf("spins3")
	if pack and not restricted and ((pack.id or 0) > 0 or RunService:IsStudio()) then
		K.banner(c.content, 4, { name = string.upper(pack.name), line = "Cheaper than one by one. Every spin can be the " .. (top and top.name or "jackpot") .. "!",
			icon = (Config.ProductImages and Config.ProductImages.spins3) or "spin", color = GOLD2, tint = C3(255, 226, 150), height = 104, buttonW = 190,
			button = (pack.id or 0) > 0 and { "\u{E002} " .. tostring(pack.price or "?"), K.GREEN, function() c.click(); MarketplaceService:PromptProductPurchase(c.player, pack.id) end, shine = true } or nil,
			status = (pack.id or 0) <= 0 and { "SOON · \u{E002} " .. tostring(pack.price or "?"), K.LOCK } or nil })
	end

	-- the best prizes, big
	K.section(c.content, 5, "TOP PRIZES", C3(255, 170, 220), "the rarest things on the reel")
	local best = table.clone(Config.Spin.prizes)
	table.sort(best, function(a, b) return a.weight < b.weight end)
	local grid = K.grid(c.content, 6, (_G.__CE_ListWidth and _G.__CE_ListWidth() or 780) >= 700 and 4 or 3, 206)
	for i = 1, math.min(4, #best) do
		local p = best[i]
		local r = rarOf(p)
		local art = prizeArt(p)
		K.tile(grid, { order = i, name = p.name, icon = art, color = r[2], badge = { r[1], r[2] }, spin = true, artH = 120,
			iconScale = type(art) == "string" and art:find("^rbxassetid://") and 1.1 or nil, stats = { { pctText(p) .. " CHANCE", r[2] } } })
	end

	-- every prize and its chance, rarest first
	K.section(c.content, 7, "ALL PRIZES & ODDS", C3(255, 220, 110), "every spin, the same odds")
	local n = #Config.Spin.prizes
	local box = controlRow(8, 24 + math.ceil(n / 2) * 36)
	local list = new("Frame", { Position = UDim2.fromOffset(16, 12), Size = UDim2.new(1, -32, 1, -24), BackgroundTransparency = 1, ZIndex = 3, Parent = box })
	new("UIGridLayout", { CellSize = UDim2.new(0.5, -8, 0, 32), CellPadding = UDim2.fromOffset(16, 4), SortOrder = Enum.SortOrder.LayoutOrder, Parent = list })
	-- the chances go up: the smallest first, left to right, row by row
	local sorted = {}
	for i, p in ipairs(Config.Spin.prizes) do sorted[i] = { p = p, i = i } end
	table.sort(sorted, function(a, b) if a.p.weight ~= b.p.weight then return a.p.weight < b.p.weight end return a.i < b.i end)
	for i, e in ipairs(sorted) do
		local p = e.p
		local r = rarOf(p)
		local cell = new("Frame", { BackgroundTransparency = 1, LayoutOrder = i, ZIndex = 3, Parent = list })
		local dot = new("Frame", { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 0, 0.5, 0), Size = UDim2.fromOffset(12, 12), BackgroundColor3 = r[2], ZIndex = 4, Parent = cell })
		UI.corner(6).Parent = dot
		local pic = new("Frame", { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 18, 0.5, 0), Size = UDim2.fromOffset(28, 28), BackgroundTransparency = 1, ZIndex = 4, Parent = cell })
		K.art(pic, prizeArt(p), UDim2.fromScale(1.1, 1.1), 5)
		K.text({ Position = UDim2.fromOffset(52, 0), Size = UDim2.new(1, -140, 1, 0), Text = p.name, TextSize = 17, Max = 17, TextColor3 = K.DARK, Parent = cell })
		K.text({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 0), Size = UDim2.fromOffset(90, 32), Text = pctText(p), TextSize = 17, Max = 17,
			TextColor3 = r[2]:Lerp(Color3.new(0, 0, 0), 0.25), TextXAlignment = Enum.TextXAlignment.Right, Parent = cell })
	end
end

function M.ShowCodes()
	local tok = c.openModal("Codes", "Codes", "", Color3.fromRGB(150, 120, 255), Color3.fromRGB(90, 60, 220))
	codeTok = tok
	c.modalSub.Text = ""
	K.banner(c.content, 1, { name = "FREE REWARDS", line = "Codes give Gems, cash and boosts. Each one works once.", icon = "codes", color = Color3.fromRGB(110, 80, 230),
		tint = Color3.fromRGB(205, 190, 255), height = 104 })
	local f = controlRow(2, 84)
	local field = UI.slice("tile", { ImageColor3 = Color3.fromRGB(74, 78, 166), Name = "Field", Position = UDim2.fromOffset(14, 15), Size = UDim2.new(1, -236, 0, 54), SliceScale = 0.4, ZIndex = 2, Parent = f })
	local box = new("TextBox", { Position = UDim2.fromOffset(16, 0), Size = UDim2.new(1, -32, 1, 0), BackgroundTransparency = 1, Text = "", PlaceholderText = "Enter a code",
		Font = T.body, TextSize = 23, TextColor3 = Color3.new(1, 1, 1), PlaceholderColor3 = Color3.fromRGB(205, 210, 240), TextXAlignment = Enum.TextXAlignment.Left,
		ClearTextOnFocus = false, ZIndex = 3, Parent = field })
	local b = UI.button("REDEEM", K.GREEN, nil, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -14, 0.5, 0), Size = UDim2.fromOffset(196, 56), TextSize = 24,
		ZIndex = 7, Shine = true, Parent = f })
	local busy = false
	local function redeem()
		if busy or box.Text == "" then return end
		busy = true
		c.click()
		local ok, res, msg = pcall(function() return CodeRF:InvokeServer(box.Text) end)
		busy = false
		if ok and res then
			box.Text = ""
		elseif c.live(tok) and codeMsg then
			codeMsg.Text = "⚠️ " .. tostring(msg or "Invalid code")
			codeMsg.TextColor3 = Color3.fromRGB(215, 60, 60)
		end
	end
	b.Activated:Connect(redeem)
	box.FocusLost:Connect(function(enter) if enter then redeem() end end)
	local res = controlRow(3, 56)
	codeMsg = K.text({ Position = UDim2.fromOffset(18, 8), Size = UDim2.new(1, -36, 1, -16), TextSize = 20, Max = 20, TextColor3 = K.SUB, Parent = res,
		Text = "Type a code and press REDEEM." })
	K.note(c.content, 4, "👍 Like and favorite the game: new codes at every like milestone!")
end

local function invite()
	local ok, can = pcall(function() return SocialService:CanSendGameInviteAsync(c.player) end)
	if ok and can then
		pcall(function() SocialService:PromptGameInvite(c.player) end)
	else
		c.toast("👋 Invites aren't available on this device right now", T.muted, 3)
	end
end

-- used by the HUD spin button: is a spin waiting, and how long until the free one
function M.Ready()
	if not c then return false, nil end
	local ready = (c.player:GetAttribute("SpinNext") ~= nil and freeLeft() <= 0) or (c.player:GetAttribute("SpinExtra") or 0) > 0
	return ready, c.player:GetAttribute("SpinNext") and freeLeft() or nil
end

function M.Init(ctx)
	c = ctx
	UI, T, new, Config = c.UI, c.T, c.new, c.Config
	SpinRF = c.Remotes:WaitForChild("SpinAction")
	CodeRF = c.Remotes:WaitForChild("RedeemCode")
	_G.__CE_Invite = invite
	_G.__CE_ShowCodes = M.ShowCodes
	-- small HUD buttons right of the gift button: Spin, Invite, Codes
	local function small(icon, label, c1, c2)
		local b = UI.button("", c1, c2, { Size = UDim2.fromOffset(64, 52), Radius = 14, Parent = c.legacy or c.gui })
		local ic = UI.label({ Size = UDim2.new(1, 0, 0, 30), Position = UDim2.fromOffset(0, 3), Text = icon, TextSize = 24, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 3, Parent = b })
		local lb = UI.label({ Size = UDim2.new(1, 0, 0, 16), Position = UDim2.fromOffset(0, 32), Text = label, Font = T.title, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 3, Parent = b })
		UI.textStroke(0.4, 1.5).Parent = lb
		return b, lb, ic
	end
	local spinBtn, spinLbl, spinIcon = small("🎰", "SPIN", GOLD1, GOLD2)
	local invBtn = small("👋", "INVITE", Color3.fromRGB(120, 226, 140), T.green2)
	local codeBtn = small("🎟️", "CODES", Color3.fromRGB(170, 140, 255), Color3.fromRGB(100, 70, 220))
	spinBtn.Name, invBtn.Name, codeBtn.Name = "SpinBtn", "InviteBtn", "CodesBtn"
	local dot = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(1, -6, 0, 6), Size = UDim2.fromOffset(18, 18), BackgroundColor3 = T.red, Visible = false, ZIndex = 5, Parent = spinBtn })
	UI.corner(9).Parent = dot
	UI.stroke(0.2, Color3.new(1, 1, 1), 2).Parent = dot
	local function place()
		local x = (c.gui:GetAttribute("GiftX") or 16) + 156
		local y = (c.gui:GetAttribute("NavBottom") or 604) + 2
		spinBtn.Position = UDim2.fromOffset(x, y)
		invBtn.Position = UDim2.fromOffset(x + 72, y)
		codeBtn.Position = UDim2.fromOffset(x + 144, y)
		-- phones: the row would run into the toasts, Invite + Codes move into the MENU popup
		local compact = c.gui:GetAttribute("Compact") == true
		invBtn.Visible = not compact
		codeBtn.Visible = not compact
	end
	c.gui:GetAttributeChangedSignal("Compact"):Connect(place)
	c.gui:GetAttributeChangedSignal("NavBottom"):Connect(place)
	c.gui:GetAttributeChangedSignal("GiftX"):Connect(place)
	place()
	spinBtn.Activated:Connect(function() c.click(); _G.__CE_Toggle("Spin", M.Show) end)
	invBtn.Activated:Connect(function() c.click(); invite() end)
	codeBtn.Activated:Connect(function() c.click(); _G.__CE_Toggle("Codes", M.ShowCodes) end)
	local wob = 0
	RunService.RenderStepped:Connect(function(dt)
		local ready = (c.player:GetAttribute("SpinNext") ~= nil and freeLeft() <= 0) or (c.player:GetAttribute("SpinExtra") or 0) > 0
		dot.Visible = ready
		if ready then
			wob += dt
			spinIcon.Rotation = math.sin(wob * 8) * 10
			spinLbl.Text = "SPIN!"
		else
			spinIcon.Rotation = 0
			local left = freeLeft()
			spinLbl.Text = c.player:GetAttribute("SpinNext") and (left > 3600 and (math.floor(left / 3600) .. "h " .. math.floor(left % 3600 / 60) .. "m") or (math.floor(left / 60) .. "m")) or "SPIN"
		end
	end)
	c.R.Feedback.OnClientEvent:Connect(function(kind, d)
		if kind == "SpinBig" and type(d) == "table" then
			-- somebody hit something big on the Lucky Spin
			local r = RAR[d.rarity or "epic"] or RAR.epic
			if d.user == c.player.UserId then return end
			c.toast("🎰 " .. tostring(d.name) .. " won " .. tostring(d.prize) .. " (" .. r[1] .. ") on the Lucky Spin!", r[2]:Lerp(Color3.new(1, 1, 1), 0.3), 4.5)
			if d.rarity == "mythic" then c.banner("⚡ " .. string.upper(tostring(d.prize)) .. "!", tostring(d.name) .. " just won it on the Lucky Spin", r[2]) end
			return
		end
		if kind == "CodeRedeemed" then
			local parts = {}
			if d.gems then table.insert(parts, "💎 " .. d.gems) end
			if d.cash then table.insert(parts, Config.FormatMoney(d.cash)) end
			if d.boost then table.insert(parts, (Config.Boosts[d.boost] and Config.Boosts[d.boost].name or d.boost) .. " " .. math.floor((d.secs or 900) / 60) .. " min") end
			if codeTok and c.live(codeTok) and codeMsg then
				codeMsg.Text = "✅ " .. d.code .. ": " .. table.concat(parts, " + ")
				codeMsg.TextColor3 = Color3.fromRGB(40, 150, 70)
			else
				c.banner("🎟️ CODE " .. d.code .. "!", table.concat(parts, " + "), Color3.fromRGB(170, 140, 255))
			end
			c.sound2D(c.S.Coins, 0.6, 1)
		end
	end)
end

return M
