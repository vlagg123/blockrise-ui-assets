-- BlockRise Empire - smaller windows on the menu kit: Daily Missions, Portfolio (buildings + achievements), My Property
local RS = game:GetService("ReplicatedStorage")
local K = require(RS.Shared:WaitForChild("MenuKit"))

local M = {}
local c, UI, T, Config

local function cols() return (_G.__CE_ListWidth and _G.__CE_ListWidth() or 780) >= 700 and 4 or 3 end
local function fmtLong(s)
	s = math.max(0, math.floor(s))
	return string.format("%dh %02dm", s // 3600, (s % 3600) // 60)
end
local function num(n) return (Config.FormatMoney(n):gsub("%$", "")) end

-- Daily Missions ------------------------------------------------------------------------------------------------
local PINK, PINK2 = Color3.fromRGB(255, 120, 150), Color3.fromRGB(210, 50, 90)
local function missionIcon(text)
	local t = string.lower(text or "")
	if t:find("train") or t:find("rep") then return "gym", Color3.fromRGB(255, 130, 90) end
	if t:find("earn") or t:find("%$") then return "cash", Color3.fromRGB(80, 200, 110) end
	if t:find("contract") or t:find("job") then return "jobs", Color3.fromRGB(255, 190, 60) end
	if t:find("hit") or t:find("build") then return "shop", Color3.fromRGB(90, 170, 255) end
	if t:find("gem") then return "gem", Color3.fromRGB(70, 180, 255) end
	return "daily", PINK
end

function M.Missions()
	local tok = c.openModal("Missions", "Daily Missions", "", PINK, PINK2)
	local loading = K.loading(c.content)
	local ok, data = pcall(function() return c.R.GetMissions:InvokeServer() end)
	if not c.live(tok) then return end
	loading:Destroy()
	if not ok or not data then
		K.empty(c.content, 1, "Missions didn't load. Open Daily again.", "daily")
		return
	end
	local claimed = 0
	for _, m in ipairs(data.list) do if m.claimed then claimed += 1 end end
	c.modalSub.Text = claimed .. " / " .. #data.list .. " done"
	-- streak + countdown to the next missions: one slim strip, so the three missions fit without scrolling
	local new = UI.new
	local resetAt = os.clock() + data.resetIn
	local strip = new("Frame", { Name = "Streak", Size = UDim2.new(1, 0, 0, 84), BackgroundTransparency = 1, LayoutOrder = 0, ZIndex = 2, Parent = c.content })
	local sbg = UI.slice("tile", { Name = "Bg", ImageColor3 = Color3.new(1, 1, 1), ZIndex = 1, Parent = strip })
	local tint = Color3.fromRGB(255, 190, 210)
	new("UIGradient", { Color = ColorSequence.new(tint:Lerp(Color3.new(1, 1, 1), 0.55), tint), Rotation = 90, Parent = sbg })
	local pic = new("Frame", { Position = UDim2.fromOffset(10, 8), Size = UDim2.fromOffset(68, 68), BackgroundTransparency = 1, ZIndex = 3, Parent = strip })
	K.art(pic, "daily", UDim2.fromScale(1, 1), 4)
	local st = K.text({ Position = UDim2.fromOffset(88, 8), Size = UDim2.new(1, -370, 0, 32), Text = "DAY " .. data.streak .. " STREAK", Font = T.chunky, TextSize = 28, Max = 28,
		TextColor3 = Color3.new(1, 1, 1), Stroke = 3, ZIndex = 4, Parent = strip })
	new("UIGradient", { Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(255, 236, 150)), Rotation = 90, Parent = st })
	-- the week: a dot per day, lit up to today's streak (the bonus grows for 7 days)
	local week = new("Frame", { Position = UDim2.fromOffset(88, 46), Size = UDim2.fromOffset(7 * 34, 28), BackgroundTransparency = 1, ZIndex = 4, Parent = strip })
	new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, VerticalAlignment = Enum.VerticalAlignment.Center,
		Parent = week })
	for d = 1, 7 do
		local on = d <= (data.streak or 0)
		local dot = new("Frame", { Size = UDim2.fromOffset(28, 28), BackgroundColor3 = on and Color3.fromRGB(255, 200, 60) or Color3.fromRGB(255, 236, 244), BorderSizePixel = 0,
			LayoutOrder = d, ZIndex = 5, Parent = week })
		new("UICorner", { CornerRadius = UDim.new(1, 0), Parent = dot })
		new("UIStroke", { Thickness = 2.5, Color = on and T.ink or Color3.fromRGB(210, 120, 160), Parent = dot })
		K.text({ Size = UDim2.fromScale(1, 1), Position = UDim2.fromOffset(0, 1), Text = tostring(d), Font = T.chunky, TextSize = 15, Max = 15,
			TextColor3 = on and Color3.new(1, 1, 1) or Color3.fromRGB(210, 120, 160), Stroke = on and 1.8 or nil, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 6, Parent = dot })
	end
	local pill = UI.slice("pill", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0), Size = UDim2.fromOffset(250, 40), SliceScale = 0.42,
		ImageColor3 = Color3.fromRGB(70, 28, 56), ZIndex = 3, Parent = strip })
	local line = K.text({ Position = UDim2.fromOffset(0, 2), Size = UDim2.fromScale(1, 1), Text = "", Font = T.chunky, TextSize = 18, Max = 18, TextColor3 = Color3.fromRGB(255, 226, 120), Stroke = 2,
		TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 4, Parent = pill })
	task.spawn(function()
		while c.live(tok) and line.Parent do
			line.Text = "NEW IN " .. string.upper(fmtLong(resetAt - os.clock()))
			task.wait(20)
		end
	end)
	for i, m in ipairs(data.list) do
		local done = m.p >= m.target
		local icon, col = missionIcon(m.text)
		local o = { name = m.text, icon = icon, color = col, height = 112, buttonW = 160,
			bar = { math.clamp(m.p / m.target, 0, 1), done and K.GREEN or PINK, num(math.min(m.p, m.target)) .. " / " .. num(m.target) },
			chips = { { Config.FormatMoney(m.reward), K.GREEN }, { "+" .. m.xp .. " XP", T.blue } } }
		if m.claimed then
			o.status = { "✔ CLAIMED", K.GREEN }
			o.dim = true
		elseif done then
			o.spin = true
			o.button = { "CLAIM", K.GREEN, function(btn)
				c.click()
				local l = btn:FindFirstChild("Label")
				if l then l.Text = "..." end
				local ok2, res = pcall(function() return c.R.ClaimMission:InvokeServer(m.index) end)
				if ok2 and res then
					if l then l.Text = "✔ CLAIMED" end
					-- the celebration (like a playtime gift): the mission's picture pops, confetti, the reward pops up and
					-- the cash flies into the counter on the HUD; the list shows CLAIMED once it is done
					local row = btn:FindFirstAncestor("Row")
					local art = row and row:FindFirstChild("Art")
					if c.playtime and c.playtime.RewardFX then
						c.playtime.RewardFX(art or row, { cash = m.reward, xp = m.xp }, { PINK, Color3.fromRGB(255, 200, 60), Color3.fromRGB(80, 200, 110),
							Color3.fromRGB(90, 170, 255), Color3.fromRGB(165, 110, 255) }, PINK)
					else
						c.sound2D(c.S.Chime, 0.5, 1)
						c.toast("🎁 +" .. Config.FormatMoney(m.reward) .. "  ·  +" .. m.xp .. " XP", T.green, 2.5)
					end
					task.delay(1.6, function() if c.live(tok) then M.Missions() end end)
				else
					if l then l.Text = "CLAIM" end
					c.toast("⚠️ Couldn't claim right now, try again", T.red)
				end
			end, shine = true, size = 24 }
		else
			-- (the progress is on the bar: the button waits, locked, until the mission is done)
			o.status = { "🔒 CLAIM", K.LOCK }
		end
		K.row(c.content, 1 + i, o)
	end
	K.note(c.content, 20, "New missions every day. Your streak bonus grows for 7 days.")
end

-- Trophies (the Portfolio): what you have done, in two tabs ---------------------------------------------------------
local BLUE1, BLUE2 = Color3.fromRGB(110, 170, 255), Color3.fromRGB(50, 100, 220)
local trophyTab = "achievements"

-- one achievement: its picture, name, what to do, a progress bar, and the reward (or DONE) on the right
local function achRow(order, a)
	local new = UI.new
	local H = 100
	local f = new("Frame", { Name = "Ach", Size = UDim2.new(1, 0, 0, H), BackgroundTransparency = 1, LayoutOrder = order, ZIndex = 2, Parent = c.content })
	UI.slice("tile", { Name = "Bg", ImageColor3 = a.done and Color3.fromRGB(232, 250, 236) or K.TILE, ZIndex = 1, Parent = f })
	K.artBox(f, a.icon, a.done and Color3.fromRGB(255, 196, 46) or Color3.fromRGB(150, 156, 196), { Position = UDim2.fromOffset(10, 10), Size = UDim2.fromOffset(H - 20, H - 20),
		Spin = a.done }).ZIndex = 2
	local RIGHT = 186 -- the reward column
	local x = H + 6
	K.text({ Position = UDim2.fromOffset(x, 12), Size = UDim2.new(1, -x - RIGHT, 0, 26), Text = a.name, Font = T.chunky, TextSize = 22, Max = 22,
		TextColor3 = a.done and Color3.fromRGB(30, 130, 60) or K.DARK, ZIndex = 3, Parent = f })
	K.text({ Position = UDim2.fromOffset(x, 40), Size = UDim2.new(1, -x - RIGHT, 0, 18), Text = a.desc, TextSize = 15, Max = 15, TextColor3 = K.SUB, ZIndex = 3, Parent = f })
	local frac = math.clamp(a.value / math.max(1, a.target), 0, 1)
	local prog = a.target >= 1000 and (Config.FormatMoney(math.min(a.value, a.target)) .. " / " .. Config.FormatMoney(a.target)) or (math.min(a.value, a.target) .. " / " .. a.target)
	local bar, fill = UI.bar({ Position = UDim2.fromOffset(x, 66), Size = UDim2.new(1, -x - RIGHT, 0, 20), ZIndex = 3 }, a.done and K.GREEN or K.GOLD)
	bar.Parent = f
	fill.Size = UDim2.fromScale(math.max(frac, 0.05), 1)
	K.text({ Position = UDim2.fromOffset(0, 1), Size = UDim2.fromScale(1, 1), Text = prog, Font = T.chunky, TextSize = 14, Max = 14, TextColor3 = Color3.new(1, 1, 1), Stroke = 2,
		TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 6, Parent = bar })
	-- right: DONE, or the reward you get (a label, not a button)
	local col = new("Frame", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -14, 0.5, 0), Size = UDim2.fromOffset(RIGHT - 30, H - 24), BackgroundTransparency = 1, ZIndex = 3,
		Parent = f })
	if a.done then
		K.status(col, "✔ DONE", K.GREEN, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(1, 0, 0, 44) })
	else
		K.text({ Position = UDim2.fromOffset(0, 6), Size = UDim2.new(1, 0, 0, 16), Text = "REWARD", Font = T.chunky, TextSize = 14, Max = 14, TextColor3 = K.SUB,
			TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 4, Parent = col })
		local row = new("Frame", { Position = UDim2.fromOffset(0, 26), Size = UDim2.new(1, 0, 0, 40), BackgroundTransparency = 1, ZIndex = 4, Parent = col })
		new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0, 4), Parent = row })
		local pic = new("Frame", { Size = UDim2.fromOffset(34, 34), BackgroundTransparency = 1, LayoutOrder = 1, ZIndex = 4, Parent = row })
		K.art(pic, "cash", UDim2.fromScale(1.1, 1.1), 5)
		K.text({ Size = UDim2.fromOffset(0, 40), AutomaticSize = Enum.AutomaticSize.X, Text = Config.FormatMoney(a.reward), Font = T.chunky, TextSize = 24,
			TextColor3 = Color3.fromRGB(60, 190, 90), Stroke = 2.4, LayoutOrder = 2, ZIndex = 5, Parent = row })
	end
	return f
end

function M.Portfolio(tabId)
	if type(tabId) == "string" then trophyTab = tabId end
	local tok = c.openModal("Portfolio", "Trophies", "", BLUE1, BLUE2)
	local loading = K.loading(c.content)
	local ok, data = pcall(function() return c.R.GetProfile:InvokeServer() end)
	if not c.live(tok) then return end
	loading:Destroy()
	if not ok or not data then K.empty(c.content, 1, "Your trophies didn't load. Try again.", "portfolio") return end
	local doneCount, builtCount = 0, 0
	for _, a in ipairs(data.achievements) do if a.done then doneCount += 1 end end
	for _, b in ipairs(data.built) do if b.count > 0 then builtCount += 1 end end
	c.modalSub.Text = Config.FormatMoney(data.earned) .. " earned"
	UI.tabs(c.content, {
		{ id = "achievements", label = "ACHIEVEMENTS " .. doneCount .. "/" .. #data.achievements, icon = "portfolio", c1 = Color3.fromRGB(255, 220, 110), c2 = Color3.fromRGB(230, 145, 25) },
		{ id = "buildings", label = "BUILDINGS " .. builtCount .. "/" .. #data.built, icon = "company", c1 = Color3.fromRGB(150, 200, 255), c2 = Color3.fromRGB(60, 120, 230) },
	}, trophyTab, function(id)
		c.click()
		trophyTab = id
		c.content.CanvasPosition = Vector2.zero
		M.Portfolio()
	end)
	-- your numbers at a glance
	local stats = K.grid(c.content, 1, 4, 84, 10)
	local function stat(i, icon, value, label, color)
		local f = UI.new("Frame", { BackgroundTransparency = 1, LayoutOrder = i, ZIndex = 2, Parent = stats })
		UI.slice("tile", { Name = "Bg", ImageColor3 = K.TILE, ZIndex = 1, Parent = f })
		local pic = UI.new("Frame", { Position = UDim2.fromOffset(8, 12), Size = UDim2.fromOffset(60, 60), BackgroundTransparency = 1, ZIndex = 3, Parent = f })
		K.art(pic, icon, UDim2.fromScale(1, 1), 4)
		K.text({ Position = UDim2.fromOffset(74, 12), Size = UDim2.new(1, -84, 0, 32), Text = value, Font = T.chunky, TextSize = 28, Max = 28, TextColor3 = color, Stroke = 2.4,
			ZIndex = 4, Parent = f })
		K.text({ Position = UDim2.fromOffset(74, 46), Size = UDim2.new(1, -84, 0, 20), Text = label, Font = T.chunky, TextSize = 14, Max = 14, TextColor3 = K.SUB, ZIndex = 4, Parent = f })
	end
	stat(1, "portfolio", doneCount .. "/" .. #data.achievements, "ACHIEVEMENTS", Color3.fromRGB(255, 190, 40))
	stat(2, "company", builtCount .. "/" .. #data.built, "BUILDINGS", Color3.fromRGB(90, 160, 255))
	stat(3, "jobs", Config.FormatNum(data.completed), "CONTRACTS", Color3.fromRGB(255, 150, 60))
	stat(4, "cash", Config.Short and ("$" .. Config.Short(data.earned)) or Config.FormatMoney(data.earned), "EARNED", Color3.fromRGB(70, 200, 100))
	if trophyTab == "buildings" then
		K.section(c.content, 2, "BUILDINGS", Color3.fromRGB(160, 205, 255), "every kind you finished, and how many times")
		local five = (_G.__CE_ListWidth and _G.__CE_ListWidth() or 780) >= 700
		local grid = K.grid(c.content, 3, five and 5 or 3, 178, 10)
		for i, b in ipairs(data.built) do
			local id
			for _, cc in ipairs(Config.Contracts) do if cc.name == b.name then id = cc.id end end
			local rk = K.rarityOf(i, #data.built)
			local t = K.tile(grid, { order = i, name = b.name, icon = (id and K.BUILDING[id]) or b.icon, color = K.RAR[rk], artH = 96, dim = b.count == 0,
				stats = { b.count > 0 and { "x" .. b.count .. " BUILT", K.GREEN } or { "NOT YET", K.LOCK } }, spin = b.count >= 10 })
			local tl = t:FindFirstChild("Title")
			if tl then
				local cons = tl:FindFirstChildOfClass("UITextSizeConstraint")
				if cons then cons.MaxTextSize = 17 end
			end
		end
	else
		K.section(c.content, 2, "ACHIEVEMENTS", Color3.fromRGB(255, 220, 110), "the closest ones first · finished ones at the bottom")
		local list = {}
		for i, a in ipairs(data.achievements) do list[i] = { a = a, i = i } end
		table.sort(list, function(x, y)
			if x.a.done ~= y.a.done then return y.a.done end
			local fx, fy = x.a.value / math.max(1, x.a.target), y.a.value / math.max(1, y.a.target)
			if not x.a.done and math.abs(fx - fy) > 1e-6 then return fx > fy end
			return x.i < y.i
		end)
		for n, e in ipairs(list) do achRow(2 + n, e.a) end
	end
end

-- My Property -----------------------------------------------------------------------------------------------------
local PUR1, PUR2 = Color3.fromRGB(200, 150, 255), Color3.fromRGB(120, 70, 220)
function M.Property()
	local p = c.player
	local hl = p:GetAttribute("HouseLevel") or 1
	c.openModal("Property", "My Property", "House Lv " .. hl, PUR1, PUR2)
	local lvl = p:GetAttribute("Level") or 1
	local pending = (p:GetAttribute("PendingHouse") or 0) > 0
	local pendingExt = p:GetAttribute("PendingExt") or ""
	local busy = pending or pendingExt ~= ""
	local cash = p:GetAttribute("Money") or 0
	K.section(c.content, 1, "YOUR HOUSE", Color3.fromRGB(220, 190, 255), "a bigger house, more bonuses")
	local grid = K.grid(c.content, 2, cols(), 268)
	for i, h in ipairs(Config.HouseLevels) do
		local o = { order = i, name = h.name, icon = "home", color = PUR2:Lerp(Color3.new(1, 1, 1), 0.15 * i), stats = { { "LEVEL " .. h.level, PUR2 } } }
		if i < hl then
			o.status = { "✔ BUILT", K.GREEN }
		elseif i == hl then
			o.status = { "YOU LIVE HERE", Color3.fromRGB(255, 176, 40) }
			o.spin = true
		elseif i == hl + 1 then
			if pending then
				o.status = { "BUILDING...", Color3.fromRGB(255, 176, 40) }
			elseif lvl < h.reqLevel then
				o.status = { "🔒 LEVEL " .. h.reqLevel, K.LOCK }
			else
				local can = cash >= h.price
				o.button = { Config.FormatMoney(h.price), can and PUR2 or K.LOCK, function()
					c.click()
					local ok2, res, msg = pcall(function() return c.R.UpgradeHouse:InvokeServer() end)
					if ok2 and res then c.closeModal() else c.toast("⚠️ " .. tostring(msg or "Can't build"), T.red) end
				end, icon = "cash", shine = can }
			end
		else
			o.dim = true
			o.status = { "🔒 " .. Config.FormatMoney(h.price), K.LOCK }
		end
		K.tile(grid, o)
	end
	K.section(c.content, 3, "EXTENSIONS", Color3.fromRGB(220, 190, 255), "build them next to your house")
	local g2 = K.grid(c.content, 4, cols(), 268)
	for i, e in ipairs(Config.Extensions) do
		local built = p:GetAttribute("X_" .. e.id) == true
		local o = { order = i, name = e.name, icon = e.id == "garage" and "garage" or e.icon, color = Color3.fromRGB(160, 110, 240),
			stats = { { string.upper(e.bonus), K.GREEN } } }
		if built then
			o.status = { "✔ BUILT", K.GREEN }
			o.spin = true
		elseif pendingExt == e.id then
			o.status = { "BUILDING...", Color3.fromRGB(255, 176, 40) }
		elseif lvl < e.reqLevel then
			o.dim = true
			o.status = { "🔒 LEVEL " .. e.reqLevel, K.LOCK }
		else
			local can = cash >= e.price and not busy
			o.button = { Config.FormatMoney(e.price), can and PUR2 or K.LOCK, function()
				c.click()
				if busy then c.toast("Finish the work on your home first", T.accent) return end
				local ok2, res, msg = pcall(function() return c.R.BuildExt:InvokeServer(e.id) end)
				if ok2 and res then c.closeModal() else c.toast("⚠️ " .. tostring(msg or "Can't build"), T.red) end
			end, icon = "cash", shine = can }
		end
		K.tile(g2, o)
	end
end

-- How to play (first join, and from the menu) --------------------------------------------------------------------
local STEPS = {
	{ "Take contracts", "Job Board, build, get paid", "jobs", Color3.fromRGB(255, 190, 60) },
	{ "Grow your crew", "Workers and machines", "crew", Color3.fromRGB(90, 200, 120) },
	{ "Get stronger", "Train at the Training Yard", "strength", Color3.fromRGB(255, 120, 80) },
	{ "Find Gems", "They drop while you build", "gem", Color3.fromRGB(60, 160, 255) },
	{ "Empire Road", "The top bar shows your goal", "quest", Color3.fromRGB(165, 110, 255) },
	{ "Own a company", "Properties pay you rent", "company", Color3.fromRGB(80, 170, 240) },
}
function M.HowTo()
	c.openModal("Welcome", "Welcome, builder!", "", Color3.fromRGB(255, 205, 80), Color3.fromRGB(240, 130, 20))
	local grid = K.grid(c.content, 1, 2, 96, 12)
	for i, st in ipairs(STEPS) do
		K.row(grid, i, { name = st[1], line = st[2], icon = st[3], color = st[4], height = 96 })
	end
	-- the main button, on its own (no card behind it)
	local foot = c.new("Frame", { Name = "Footer", Size = UDim2.new(1, 0, 0, 72), BackgroundTransparency = 1, LayoutOrder = 2, ZIndex = 2, Parent = c.content })
	K.button(foot, "LET'S BUILD!", K.GREEN, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, 2), Size = UDim2.fromOffset(300, 62), TextSize = 30,
		Shine = true }, function()
		c.click()
		c.closeModal()
		-- the tutorial's arrow already shows the way (no arrow of its own on top of it); after the tutorial the
		-- Job Board opens from anywhere
		local tut = (c.player:GetAttribute("RoadStep") or 1) <= (Config.TutorialSteps or 7)
		if not tut and (c.player:GetAttribute("ContractJob") or "") == "" and c.actions and c.actions.jobs then c.actions.jobs() end
	end)
end

function M.Init(ctx)
	c = ctx
	UI, T, Config = c.UI, c.T, c.Config
end

return M
