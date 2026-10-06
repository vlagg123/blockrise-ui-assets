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
	-- streak + countdown to the next missions
	local resetAt = os.clock() + data.resetIn
	local b = K.banner(c.content, 0, { name = "DAY " .. data.streak .. " STREAK", line = "New missions in " .. fmtLong(data.resetIn), icon = "daily", color = PINK2,
		tint = Color3.fromRGB(255, 190, 210), height = 104 })
	local line = b:FindFirstChild("Line")
	task.spawn(function()
		while c.live(tok) and line and line.Parent do
			line.Text = "New missions in " .. fmtLong(resetAt - os.clock())
			task.wait(20)
		end
	end)
	K.section(c.content, 1, "TODAY", Color3.fromRGB(255, 190, 210), "claim them before they reset")
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
					c.sound2D(c.S.Chime, 0.5, 1)
					local char = c.player.Character
					if char and char:FindFirstChild("HumanoidRootPart") then c.emit(char.HumanoidRootPart.Position, "confetti", nil, 40) end
					c.toast("🎁 +" .. Config.FormatMoney(m.reward) .. "  ·  +" .. m.xp .. " XP", T.green, 2.5)
					if c.live(tok) then M.Missions() end
				else
					if l then l.Text = "CLAIM" end
					c.toast("⚠️ Couldn't claim right now, try again", T.red)
				end
			end, shine = true, size = 24 }
		else
			o.status = { math.floor(m.p / m.target * 100) .. "%", K.LOCK }
		end
		K.row(c.content, 1 + i, o)
	end
	K.note(c.content, 20, "New missions every day. Your streak bonus grows for 7 days.")
end

-- Portfolio -------------------------------------------------------------------------------------------------------
local BLUE1, BLUE2 = Color3.fromRGB(110, 170, 255), Color3.fromRGB(50, 100, 220)
function M.Portfolio()
	local tok = c.openModal("Portfolio", "Portfolio", "", BLUE1, BLUE2)
	local loading = K.loading(c.content)
	local ok, data = pcall(function() return c.R.GetProfile:InvokeServer() end)
	if not c.live(tok) then return end
	loading:Destroy()
	if not ok or not data then K.empty(c.content, 1, "Your portfolio didn't load. Try again.", "portfolio") return end
	local doneCount, builtCount = 0, 0
	for _, a in ipairs(data.achievements) do if a.done then doneCount += 1 end end
	for _, b in ipairs(data.built) do if b.count > 0 then builtCount += 1 end end
	c.modalSub.Text = Config.FormatMoney(data.earned) .. " earned"
	K.section(c.content, 1, "BUILDINGS", Color3.fromRGB(160, 205, 255), builtCount .. " / " .. #data.built .. " built · " .. data.completed .. " contracts")
	local grid = K.grid(c.content, 2, cols(), 196)
	for i, b in ipairs(data.built) do
		local id
		for _, cc in ipairs(Config.Contracts) do if cc.name == b.name then id = cc.id end end
		local rk = K.rarityOf(i, #data.built)
		K.tile(grid, { order = i, name = b.name, icon = (id and K.BUILDING[id]) or b.icon, color = K.RAR[rk], artH = 112, dim = b.count == 0,
			stats = { b.count > 0 and { "x" .. b.count .. " BUILT", K.GREEN } or { "NOT YET", K.LOCK } }, spin = b.count >= 10 })
	end
	K.section(c.content, 3, "ACHIEVEMENTS", Color3.fromRGB(255, 220, 110), doneCount .. " / " .. #data.achievements .. " done")
	for i, a in ipairs(data.achievements) do
		local frac = math.clamp(a.value / math.max(1, a.target), 0, 1)
		local prog = a.target >= 1000 and (Config.FormatMoney(a.value) .. " / " .. Config.FormatMoney(a.target)) or (math.min(a.value, a.target) .. " / " .. a.target)
		K.row(c.content, 3 + i, { name = a.name, line = a.desc, icon = a.icon, color = a.done and Color3.fromRGB(255, 196, 46) or Color3.fromRGB(150, 156, 196),
			bar = { frac, a.done and K.GREEN or K.GOLD, prog }, height = 112, buttonW = 150,
			status = a.done and { "✔ DONE", K.GREEN } or { Config.FormatMoney(a.reward), Color3.fromRGB(240, 160, 30) }, spin = a.done })
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
