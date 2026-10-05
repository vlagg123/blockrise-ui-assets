-- BlockRise Empire - Lucky Spin (prize reel), promo codes and the invite button (small HUD row next to the gift)
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
local WIN = Color3.fromRGB(150, 245, 150)
local SpinRF, CodeRF
local spinning = false
local codeTok, codeMsg

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

-- prize art: atlas icons where we have one
local function prizeIcon(p)
	local n = string.lower(p.name or "")
	if p.jackpot and p.kind == "cash" then return "store", GOLD2 end
	if n:find("2x") and n:find("cash") then return "up_cash", Color3.fromRGB(80, 200, 110) end
	if n:find("strength") then return "up_strength", Color3.fromRGB(255, 120, 80) end
	if n:find("gem") then return "gem", p.jackpot and GOLD2 or Color3.fromRGB(60, 160, 255) end
	if n:find("big cash") then return "coins", Color3.fromRGB(80, 200, 110) end
	if n:find("cash") then return "cash", Color3.fromRGB(80, 200, 110) end
	return p.icon, Color3.fromRGB(150, 156, 196)
end

local TILE, GAP = 118, 10
local function tile(parent, p, x)
	local f = new("Frame", { Name = "Prize", Position = UDim2.fromOffset(x, 0), Size = UDim2.fromOffset(TILE, TILE + 10), BackgroundTransparency = 1, ZIndex = 3, Parent = parent })
	UI.slice("tile", { Name = "Bg", ImageColor3 = p.jackpot and Color3.fromRGB(255, 230, 150) or K.TILE, ZIndex = 1, Parent = f })
	local icon, col = prizeIcon(p)
	K.artBox(f, icon, col, { Position = UDim2.fromOffset(7, 7), Size = UDim2.new(1, -14, 0, 74), Spin = p.jackpot })
	K.text({ Position = UDim2.fromOffset(6, 84), Size = UDim2.new(1, -12, 0, 38), Text = p.name, TextSize = 16, Max = 16, TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Center, TextColor3 = K.DARK, Parent = f })
	return f
end
local function light(f, on)
	local bg = f and f:FindFirstChild("Bg")
	if bg then UI.tween(bg, on and 0.25 or 0.6, { ImageColor3 = on and WIN or K.TILE }) end
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

function M.Show()
	local tok = c.openModal("Spin", "Lucky Spin", "", GOLD1, GOLD2)
	pcall(function() SpinRF:InvokeServer("get") end)
	if not c.live(tok) then return end
	odds(Config.Spin.prizes[1])
	-- the reel: a dark well, tiles slide under a golden frame
	local reel = new("Frame", { Name = "Reel", Size = UDim2.new(1, 0, 0, 164), BackgroundTransparency = 1, LayoutOrder = 1, ZIndex = 2, Parent = c.content })
	UI.slice("inset", { Name = "Well", ImageTransparency = 0.25, ZIndex = 1, Parent = reel })
	local clip = new("Frame", { Name = "Clip", Position = UDim2.fromOffset(8, 8), Size = UDim2.new(1, -16, 1, -16), BackgroundTransparency = 1, ClipsDescendants = true, ZIndex = 2, Parent = reel })
	local strip = new("Frame", { Position = UDim2.fromOffset(0, 9), Size = UDim2.fromOffset(60 * (TILE + GAP), TILE + 10), BackgroundTransparency = 1, ZIndex = 3, Parent = clip })
	local items = {}
	for i = 1, 60 do items[i] = weightedRandom() end
	local tiles = {}
	for i = 1, 60 do tiles[i] = tile(strip, Config.Spin.prizes[items[i]], (i - 1) * (TILE + GAP)) end
	local marker = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(TILE + 14, TILE + 24), BackgroundTransparency = 1,
		ZIndex = 8, Parent = reel })
	UI.corner(18).Parent = marker
	new("UIStroke", { Thickness = 5, Color = GOLD1, Parent = marker })
	for _, y in ipairs({ 0, 1 }) do
		local tri = new("TextLabel", { AnchorPoint = Vector2.new(0.5, y), Position = UDim2.new(0.5, 0, y, y == 0 and -2 or 2), Size = UDim2.fromOffset(30, 20), BackgroundTransparency = 1,
			Text = y == 0 and "▼" or "▲", TextSize = 24, Font = Enum.Font.GothamBlack, TextColor3 = GOLD1, ZIndex = 9, Parent = reel })
		UI.textStroke(0, 2.5).Parent = tri
	end
	local function centerOn(i, jitter)
		-- the reel is scaled with the UI: measure a tile to get the design width of the clip area
		local sc = tiles[1].AbsoluteSize.X / TILE
		local w = sc > 0.05 and clip.AbsoluteSize.X / sc or 760
		return -((i - 1) * (TILE + GAP) + TILE / 2 + (jitter or 0)) + w / 2
	end
	task.defer(function() strip.Position = UDim2.fromOffset(centerOn(4), 9) end)
	-- status + button
	local ctrl = controlRow(2, 92)
	local status = K.text({ Position = UDim2.fromOffset(18, 14), Size = UDim2.new(1, -230, 0, 32), Text = "", TextSize = 25, Max = 25, Parent = ctrl })
	local sub = K.text({ Position = UDim2.fromOffset(18, 50), Size = UDim2.new(1, -230, 0, 24), Text = "", TextSize = 17, Max = 17, TextColor3 = K.SUB, Parent = ctrl })
	local btn = UI.button("SPIN!", K.GREEN, nil, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -16, 0.5, 0), Size = UDim2.fromOffset(196, 58), TextSize = 25,
		ZIndex = 7, Shine = true, Parent = ctrl })
	local btnLbl = btn:FindFirstChild("Label")
	local resultUntil = 0
	local statusScale = new("UIScale", { Parent = status })
	local function refresh()
		if not c.live(tok) then return end
		local stText
		local left = freeLeft()
		local extra = c.player:GetAttribute("SpinExtra") or 0
		local gems = c.player:GetAttribute("Gems") or 0
		if left <= 0 then
			stText = "Your FREE spin is ready!"
			if btnLbl then btnLbl.Text = "FREE SPIN" end
		elseif extra > 0 then
			stText = "Extra spins: " .. extra
			if btnLbl then btnLbl.Text = "SPIN (" .. extra .. ")" end
		elseif c.player:GetAttribute("PaidRandomRestricted") == true then
			-- Roblox policy: no paid spins in this region, only the free one
			stText = "Free spin in " .. fmtLong(left)
			if btnLbl then btnLbl.Text = "⏱ " .. fmtLong(left) end
		else
			stText = "Free spin in " .. fmtLong(left)
			if btnLbl then btnLbl.Text = "SPIN · 💎 " .. Config.Spin.gemCost end
		end
		sub.Text = c.player:GetAttribute("PaidRandomRestricted") == true and "One free spin every 4 hours" or ("One free spin every 4 hours · you have " .. Config.FormatNum(gems) .. " 💎")
		if os.clock() >= resultUntil then
			status.Text = stText
			status.TextColor3 = K.DARK
		end
	end
	refresh()
	local conn
	conn = RunService.Heartbeat:Connect(function()
		if not c.live(tok) then conn:Disconnect() return end
		if not spinning then refresh() end
	end)
	btn.Activated:Connect(function()
		if spinning then return end
		c.click()
		spinning = true
		local ok, res, data = pcall(function() return SpinRF:InvokeServer("spin") end)
		if not (ok and res) then
			spinning = false
			c.toast("⚠️ " .. tostring(data or "Can't spin right now"), T.red, 3)
			return
		end
		local idx = data.index
		local p = Config.Spin.prizes[idx]
		-- rebuild the tile the reel will land on (tile 50)
		local target = 50
		tiles[target]:Destroy()
		tiles[target] = tile(strip, p, (target - 1) * (TILE + GAP))
		-- lands a little to one side (suspense), then glides exactly onto the frame
		local jitter = (math.random() < 0.5 and -1 or 1) * TILE * (0.18 + math.random() * 0.22)
		strip.Position = UDim2.fromOffset(centerOn(4), 9)
		local tw = TweenService:Create(strip, TweenInfo.new(4.4, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), { Position = UDim2.fromOffset(centerOn(target, jitter), 9) })
		local lastTick = -1
		local tickConn = RunService.RenderStepped:Connect(function()
			local x = -strip.Position.X.Offset
			local n = math.floor(x / (TILE + GAP))
			if n ~= lastTick then
				lastTick = n
				c.sound2D(c.S.Click, 0.18, 1.4)
			end
		end)
		tw:Play()
		tw.Completed:Wait()
		task.wait(0.12)
		local settle = TweenService:Create(strip, TweenInfo.new(0.55, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Position = UDim2.fromOffset(centerOn(target), 9) })
		settle:Play()
		settle.Completed:Wait()
		strip.Position = UDim2.fromOffset(centerOn(target), 9)
		tickConn:Disconnect()
		spinning = false
		if c.live(tok) then
			light(tiles[target], true)
			-- the prize pops
			local ps = Instance.new("UIScale")
			ps.Parent = tiles[target]
			ps.Scale = 1.14
			UI.tween(ps, 0.4, { Scale = 1 }, Enum.EasingStyle.Back)
			-- the next spin starts from tile 4: show the same prize there so the reset isn't visible
			task.delay(1.2, function()
				if not c.live(tok) or spinning then return end
				tiles[4]:Destroy()
				tiles[4] = tile(strip, p, 3 * (TILE + GAP))
				tiles[4].Bg.ImageColor3 = WIN
				strip.Position = UDim2.fromOffset(centerOn(4), 9)
				light(tiles[4], false)
			end)
		end
		local text = p.name
		if p.kind == "cash" and data.cash then text = Config.FormatMoney(data.cash) .. (p.jackpot and " JACKPOT!" or " cash") end
		if c.live(tok) then
			resultUntil = os.clock() + 3.5
			status.Text = (p.jackpot and "JACKPOT! " or "You won: ") .. text
			status.TextColor3 = Color3.fromRGB(225, 110, 10)
			statusScale.Scale = 1.15
			UI.tween(statusScale, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
		else
			c.banner(p.jackpot and "🤑 JACKPOT!" or "🎰 YOU WON!", p.icon .. " " .. text, GOLD1)
		end
		if p.jackpot then
			c.sound2D(c.S.Fanfare, 0.6, 1)
			local char = c.player.Character
			if char and char:FindFirstChild("HumanoidRootPart") then c.emit(char.HumanoidRootPart.Position, "confetti", nil, 120) end
		else
			c.sound2D(c.S.Coins, 0.6, 1.1)
		end
		refresh()
	end)
	-- Robux pack
	local pack = packOf("spins3")
	if pack and (pack.id or 0) > 0 and c.player:GetAttribute("PaidRandomRestricted") ~= true then
		K.row(c.content, 3, { name = pack.name, icon = "spin", color = GOLD2, height = 92, buttonW = 170,
			button = { "R$ " .. tostring(pack.price or "?"), K.GREEN, function() c.click(); MarketplaceService:PromptProductPurchase(c.player, pack.id) end, shine = true } })
	end
	-- the odds of every prize (always shown)
	K.section(c.content, 4, "ODDS", Color3.fromRGB(255, 220, 110), "every prize and its chance")
	local n = #Config.Spin.prizes
	local box = controlRow(5, 24 + math.ceil(n / 2) * 34)
	local list = new("Frame", { Position = UDim2.fromOffset(18, 12), Size = UDim2.new(1, -36, 1, -24), BackgroundTransparency = 1, ZIndex = 3, Parent = box })
	new("UIGridLayout", { CellSize = UDim2.new(0.5, -6, 0, 30), CellPadding = UDim2.fromOffset(12, 4), SortOrder = Enum.SortOrder.LayoutOrder, Parent = list })
	for i, p in ipairs(Config.Spin.prizes) do
		local pct = odds(p)
		K.text({ Size = UDim2.fromScale(1, 1), LayoutOrder = i, TextSize = 18, Max = 18, TextColor3 = K.DARK, Parent = list,
			Text = string.format("%s  %s  <font color='#7a6fb0'>%s%%</font>", p.icon, p.name, (pct < 10 and string.format("%.1f", pct) or tostring(math.floor(pct + 0.5)))) })
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
