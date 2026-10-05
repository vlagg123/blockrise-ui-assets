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
	if g.cash then table.insert(out, { Config.FormatMoney(math.floor(bestReward() * g.cash)), K.GREEN }) end
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
			o.button = { "OPEN!", K.GREEN, function()
				c.click()
				if claim(i) and c.live(tok) then M.Show() end
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
			c.sound2D(c.S.Coins, 0.6, 1)
		end
	end)
end

return M
