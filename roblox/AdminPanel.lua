-- BlockRise Empire - Admin panel (owner only), client side: ServerStorage.AdminPanel.AdminClient
-- The server copies this ScreenGui into the owner's PlayerGui only, with the AdminRF remote inside it.
-- Nothing here is trusted: every action is checked again on the server.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local gui = script.Parent
local rf = gui:WaitForChild("AdminRF", 30)
if not rf then return end
local Config = require(RS:WaitForChild("Shared"):WaitForChild("Config"))
local Company = require(RS.Shared:WaitForChild("Company"))
local UI = require(RS.Shared:WaitForChild("UIKit"))
local T = UI.Theme
local new = UI.new
local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

gui.ResetOnSpawn = false
gui.DisplayOrder = 80
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.IgnoreGuiInset = false

-- same scale as the HUD
local scale = new("UIScale", { Parent = gui })
local function updateScale()
	local vp = camera.ViewportSize
	local touch = UIS.TouchEnabled and not UIS.KeyboardEnabled
	scale.Scale = touch and math.clamp(math.min(vp.X / 1000, vp.Y / 620), 0.5, 1) or math.clamp(math.min(vp.X / 1300, vp.Y / 780), 0.6, 1.15)
end
camera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)
updateScale()

local GOLD = Color3.fromRGB(255, 196, 46)
local RED = Color3.fromRGB(235, 70, 80)
local GREEN = Color3.fromRGB(70, 214, 96)
local BLUE = Color3.fromRGB(70, 160, 255)
local PURPLE = Color3.fromRGB(165, 110, 255)
local GREY = Color3.fromRGB(110, 114, 160)

local function fmt(n) return Config.FormatNum(math.floor(tonumber(n) or 0)) end
local function money(n) return Config.FormatMoney(tonumber(n) or 0) end

-- "1.5M", "250k", "2b", "1,000,000", "-5k" -> number
local SUFFIX = { k = 1e3, m = 1e6, b = 1e9, t = 1e12, qa = 1e15, qi = 1e18 }
local function parse(text)
	text = string.lower((text or ""):gsub("[%s,%$]", ""))
	local n, suf = text:match("^(%-?[%d%.]+)(%a*)$")
	n = tonumber(n)
	if not n then return nil end
	if suf ~= "" then
		if not SUFFIX[suf] then return nil end
		n *= SUFFIX[suf]
	end
	return n
end

---------------------------------------------------------------------------
-- the ADMIN button (right side, under MORE) and the window
---------------------------------------------------------------------------
local openBtn = UI.button("🛠️ ADMIN", RED, Color3.fromRGB(170, 30, 50), { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 300),
	Size = UDim2.fromOffset(96, 40), TextSize = 17, Font = T.chunky, ZIndex = 2, Parent = gui })
openBtn.Name = "AdminButton"

local window = UI.panel({ Name = "Window", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(960, 600),
	Visible = false, ZIndex = 10, Parent = gui })
local title = UI.label({ Position = UDim2.fromOffset(20, 10), Size = UDim2.fromOffset(400, 40), Text = "🛠️ ADMIN PANEL", Font = T.chunky, TextSize = 32,
	TextColor3 = GOLD, ZIndex = 11, Parent = window })
UI.textStroke(0, 3).Parent = title
UI.label({ Position = UDim2.fromOffset(330, 16), Size = UDim2.fromOffset(420, 30), Text = "only you can see this · everything is checked on the server",
	TextSize = 14, TextColor3 = T.muted, ZIndex = 11, Parent = window })
local closeBtn = UI.button("X", RED, nil, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -14, 0, 12), Size = UDim2.fromOffset(44, 40), TextSize = 22, ZIndex = 12, Parent = window })
pcall(function() UI.closeStyle(closeBtn, 13) end)

local status = UI.label({ AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 262, 1, -12), Size = UDim2.new(1, -280, 0, 26), Text = "", TextSize = 16,
	TextColor3 = T.muted, TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 11, Parent = window })
local function say(ok, msg)
	status.Text = (ok and "✅ " or "⚠️ ") .. tostring(msg or (ok and "done" or "failed"))
	status.TextColor3 = ok and GREEN or Color3.fromRGB(255, 140, 120)
end

---------------------------------------------------------------------------
-- players list (left)
---------------------------------------------------------------------------
local targetId = player.UserId
local listBox = new("Frame", { Position = UDim2.fromOffset(16, 60), Size = UDim2.fromOffset(230, 524), BackgroundColor3 = Color3.fromRGB(20, 18, 34),
	BackgroundTransparency = 0.25, ZIndex = 11, Parent = window })
UI.corner(12).Parent = listBox
local listTitle = UI.label({ Position = UDim2.fromOffset(12, 6), Size = UDim2.new(1, -24, 0, 28), Text = "PLAYERS", Font = T.chunky, TextSize = 20, ZIndex = 12, Parent = listBox })
local list = new("ScrollingFrame", { Position = UDim2.fromOffset(6, 38), Size = UDim2.new(1, -12, 1, -44), BackgroundTransparency = 1, BorderSizePixel = 0,
	ScrollBarThickness = 6, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ZIndex = 12, Parent = listBox })
UI.list(Enum.FillDirection.Vertical, 6).Parent = list

local redrawList
local function target() return Players:GetPlayerByUserId(targetId) end

function redrawList()
	for _, c in ipairs(list:GetChildren()) do if c:IsA("GuiObject") then c:Destroy() end end
	local all = Players:GetPlayers()
	table.sort(all, function(a, b)
		if a == player then return true elseif b == player then return false end
		return a.Name:lower() < b.Name:lower()
	end)
	listTitle.Text = "PLAYERS (" .. #all .. ")"
	for i, p in ipairs(all) do
		local sel = p.UserId == targetId
		local row = new("TextButton", { Name = p.Name, Size = UDim2.new(1, -8, 0, 52), Text = "", AutoButtonColor = true, LayoutOrder = i,
			BackgroundColor3 = sel and Color3.fromRGB(70, 120, 230) or Color3.fromRGB(46, 42, 78), ZIndex = 13, Parent = list })
		UI.corner(10).Parent = row
		if sel then new("UIStroke", { Thickness = 2, Color = GOLD, Parent = row }) end
		UI.label({ Position = UDim2.fromOffset(10, 4), Size = UDim2.new(1, -16, 0, 22), Text = (p == player and "⭐ " or "") .. p.DisplayName,
			Font = T.title, TextSize = 17, TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 14, Parent = row })
		UI.label({ Position = UDim2.fromOffset(10, 26), Size = UDim2.new(1, -16, 0, 20), Text = "@" .. p.Name .. "  ·  Lv " .. tostring(p:GetAttribute("Level") or "?"),
			TextSize = 13, TextColor3 = T.muted, TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 14, Parent = row })
		row.Activated:Connect(function()
			targetId = p.UserId
			redrawList()
		end)
	end
end
Players.PlayerAdded:Connect(function() if window.Visible then redrawList() end end)
Players.PlayerRemoving:Connect(function(p)
	if p.UserId == targetId then targetId = player.UserId end
	task.defer(function() if window.Visible then redrawList() end end)
end)

---------------------------------------------------------------------------
-- the selected player's numbers (top right)
---------------------------------------------------------------------------
local stats = UI.label({ Position = UDim2.fromOffset(262, 58), Size = UDim2.new(1, -280, 0, 52), Text = "", TextSize = 16, TextWrapped = true,
	TextYAlignment = Enum.TextYAlignment.Top, ZIndex = 11, Parent = window })
local function refreshStats()
	local p = target()
	if not p then stats.Text = "" return end
	local a = function(k, d) local v = p:GetAttribute(k) if v == nil then return d or 0 end return v end
	local passes = 0
	for _, ps in ipairs(Config.Store.passes) do if a("Pass_" .. ps.key, false) == true then passes += 1 end end
	stats.Text = string.format("<b>%s</b>   💵 %s   💎 %s   ⭐ Lv %s   🏅 Rep %s   💪 %s\n✨ Stars %s   🔁 Rebirths %s   🔨 Hammer %s/%d   🏋️ Gear %s   🎟️ Passes %d/%d",
		p.DisplayName, money(a("Money")), fmt(a("Gems")), fmt(a("Level", 1)), fmt(a("Rep")), fmt(a("Strength")), fmt(a("Stars")), fmt(a("Rebirths")),
		tostring(a("ToolTier", 1)), #Config.Tools, tostring(a("GearTier", 1)), passes, #Config.Store.passes)
end

---------------------------------------------------------------------------
-- tabs + content
---------------------------------------------------------------------------
local TABS = { { "currency", "💵 MONEY" }, { "progress", "⭐ PROGRESS" }, { "passes", "🎟️ PASSES" }, { "boosts", "⚡ BOOSTS" }, { "items", "📦 ITEMS" }, { "move", "📍 MOVE" } }
local tab = "currency"
local tabRow = new("Frame", { Position = UDim2.fromOffset(262, 114), Size = UDim2.new(1, -280, 0, 40), BackgroundTransparency = 1, ZIndex = 11, Parent = window })
UI.list(Enum.FillDirection.Horizontal, 6).Parent = tabRow
local content = new("ScrollingFrame", { Position = UDim2.fromOffset(262, 162), Size = UDim2.new(1, -280, 1, -206), BackgroundColor3 = Color3.fromRGB(20, 18, 34),
	BackgroundTransparency = 0.25, BorderSizePixel = 0, ScrollBarThickness = 6, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ZIndex = 11, Parent = window })
UI.corner(12).Parent = content
UI.pad(12, 10).Parent = content
UI.list(Enum.FillDirection.Vertical, 8).Parent = content

local busy = false
local function call(action, v, after)
	if busy then return end
	busy = true
	status.Text = "…"
	task.spawn(function()
		local ok, res, msg = pcall(function() return rf:InvokeServer(action, targetId, v) end)
		busy = false
		if not ok then say(false, res) else say(res == true, msg) end
		task.wait(0.15)
		refreshStats()
		if after then after() end
	end)
end

local order = 0
local function row(h)
	order += 1
	local f = new("Frame", { Size = UDim2.new(1, -4, 0, h or 44), BackgroundTransparency = 1, LayoutOrder = order, ZIndex = 12, Parent = content })
	return f
end
local function heading(text)
	local f = row(30)
	UI.label({ Size = UDim2.fromScale(1, 1), Text = text, Font = T.chunky, TextSize = 20, TextColor3 = GOLD, ZIndex = 13, Parent = f })
end
local function btn(parent, x, w, text, color, fn)
	local b = UI.button(text, color or BLUE, nil, { Position = UDim2.fromOffset(x, 2), Size = UDim2.fromOffset(w, 40), TextSize = 16, ZIndex = 13, Parent = parent })
	b.Activated:Connect(fn)
	return b
end
local function label(parent, text, w)
	return UI.label({ Position = UDim2.fromOffset(0, 0), Size = UDim2.fromOffset(w or 150, 44), Text = text, Font = T.title, TextSize = 17, ZIndex = 13, Parent = parent })
end
local function box(parent, x, w, placeholder)
	local b = new("TextBox", { Position = UDim2.fromOffset(x, 4), Size = UDim2.fromOffset(w, 36), BackgroundColor3 = Color3.fromRGB(245, 245, 255), Text = "",
		PlaceholderText = placeholder or "amount (1.5M, 2B…)", PlaceholderColor3 = Color3.fromRGB(140, 140, 170), TextColor3 = T.dark, Font = T.title, TextSize = 17,
		ClearTextOnFocus = false, ZIndex = 13, Parent = parent })
	UI.corner(8).Parent = b
	return b
end

-- a number you can add to or set: [label][box][ADD][SET][quick buttons]
local function numberRow(text, action, quick, setOnly)
	local f = row()
	label(f, text)
	local b = box(f, 152, 140)
	local x = 298
	local function go(mode)
		local n = parse(b.Text)
		if not n then say(false, "type a number first (e.g. 1.5M)") return end
		call(action, { mode = mode, n = n })
	end
	if not setOnly then btn(f, x, 64, "ADD", GREEN, function() go("add") end); x += 70 end
	btn(f, x, 64, "SET", BLUE, function() go("set") end); x += 76
	for _, q in ipairs(quick or {}) do
		btn(f, x, 64, q[1], PURPLE, function() call(action, { mode = "add", n = q[2] }) end)
		x += 70
	end
end

local function tierRow(text, action, max, attr, names)
	local f = row()
	label(f, text)
	local b = box(f, 152, 90, "1-" .. max)
	btn(f, 250, 70, "SET", BLUE, function()
		local n = parse(b.Text)
		if not n then say(false, "type a tier 1-" .. max) return end
		call(action, math.floor(n))
	end)
	btn(f, 326, 52, "−", GREY, function()
		local p = target()
		call(action, math.max(1, (p and p:GetAttribute(attr) or 1) - 1))
	end)
	btn(f, 384, 52, "+", GREY, function()
		local p = target()
		call(action, math.min(max, (p and p:GetAttribute(attr) or 1) + 1))
	end)
	btn(f, 442, 80, "MAX", GOLD, function() call(action, max) end)
	if names then
		local p = target()
		local cur = p and p:GetAttribute(attr) or 1
		UI.label({ Position = UDim2.fromOffset(530, 0), Size = UDim2.new(1, -530, 1, 0), Text = tostring(names[cur] or ""), TextSize = 14, TextColor3 = T.muted,
			TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 13, Parent = f })
	end
end

local PAGES = {}
function PAGES.currency()
	heading("MONEY & GEMS")
	numberRow("💵 Money", "money", { { "+1M", 1e6 }, { "+1B", 1e9 }, { "+1T", 1e12 } })
	numberRow("💎 Gems", "gems", { { "+1K", 1e3 }, { "+10K", 1e4 }, { "+100K", 1e5 } })
	numberRow("💪 Strength", "strength", { { "+1M", 1e6 }, { "+1B", 1e9 } })
	numberRow("✨ Stars", "stars", { { "+10", 10 }, { "+100", 100 } })
	numberRow("🏅 Reputation", "rep", { { "+1K", 1e3 }, { "+100K", 1e5 } })
end
function PAGES.progress()
	heading("LEVEL & REBIRTH")
	numberRow("⭐ Level", "level", { { "+1", 1 }, { "+10", 10 }, { "+100", 100 } })
	numberRow("🔁 Rebirths", "rebirths", { { "+1", 1 } })
	heading("HAMMER & TRAINING GEAR")
	local tn, gn = {}, {}
	for i, t in ipairs(Config.Tools) do tn[i] = t.name end
	for i, g in ipairs(Config.TrainingGear) do gn[i] = g.name end
	tierRow("🔨 Hammer", "tool", #Config.Tools, "ToolTier", tn)
	tierRow("🏋️ Gear", "gear", #Config.TrainingGear, "GearTier", gn)
	heading("SHORTCUTS")
	local f = row()
	btn(f, 0, 230, "✅ Finish current contract", GREEN, function() call("finish") end)
	btn(f, 238, 200, "🎓 Skip tutorial", BLUE, function() call("tutorial") end)
end
function PAGES.passes()
	heading("GAME PASSES (free from here, saved)")
	local p = target()
	for _, ps in ipairs(Config.Store.passes) do
		local f = row()
		local owned = p and p:GetAttribute("Pass_" .. ps.key) == true
		label(f, (ps.icon and #ps.icon <= 8 and (ps.icon .. " ") or "") .. ps.name, 330)
		UI.label({ Position = UDim2.fromOffset(330, 0), Size = UDim2.fromOffset(120, 44), Text = owned and "OWNED" or "—", Font = T.chunky, TextSize = 17,
			TextColor3 = owned and GREEN or T.muted, ZIndex = 13, Parent = f })
		if owned then
			btn(f, 450, 120, "REMOVE", RED, function() call("pass", { key = ps.key, on = false }, function() PAGES._redraw() end) end)
		else
			btn(f, 450, 120, "GIVE", GREEN, function() call("pass", { key = ps.key, on = true }, function() PAGES._redraw() end) end)
		end
	end
	local f = row()
	btn(f, 0, 200, "🎁 GIVE ALL", GOLD, function()
		task.spawn(function()
			for _, ps in ipairs(Config.Store.passes) do
				local tp = target()
				if tp and tp:GetAttribute("Pass_" .. ps.key) ~= true then
					local ok, res, msg = pcall(function() return rf:InvokeServer("pass", targetId, { key = ps.key, on = true }) end)
					if not (ok and res) then say(false, ok and msg or res) break end
					task.wait(0.1)
				end
			end
			say(true, "all passes given")
			task.wait(0.2)
			refreshStats()
			PAGES._redraw()
		end)
	end)
end
function PAGES.boosts()
	heading("BOOSTS")
	for key, b in pairs(Config.Boosts) do
		local f = row()
		label(f, "⚡ " .. tostring(b.name or key), 220)
		btn(f, 226, 100, "+15 MIN", BLUE, function() call("boost", { key = key, secs = 900 }) end)
		btn(f, 332, 100, "+1 HOUR", PURPLE, function() call("boost", { key = key, secs = 3600 }) end)
		btn(f, 438, 100, "+1 DAY", GOLD, function() call("boost", { key = key, secs = 86400 }) end)
	end
	local f = row()
	label(f, "👷 Rush Crew 2x", 220)
	btn(f, 226, 100, "+30 MIN", BLUE, function() call("rush", 1800) end)
	btn(f, 332, 100, "+2 HOURS", PURPLE, function() call("rush", 7200) end)
	btn(f, 438, 100, "+1 DAY", GOLD, function() call("rush", 86400) end)
	local g = row()
	label(g, "🎰 Free spins", 220)
	btn(g, 226, 100, "+1", BLUE, function() call("spins", 1) end)
	btn(g, 332, 100, "+5", PURPLE, function() call("spins", 5) end)
	btn(g, 438, 100, "+25", GOLD, function() call("spins", 25) end)
end
function PAGES.items()
	heading("MATERIALS")
	for _, m in ipairs(Company.Materials or {}) do
		local f = row()
		label(f, tostring(m.icon or "🧱") .. " " .. tostring(m.name or m.id), 220)
		btn(f, 226, 90, "+10", BLUE, function() call("mat", { id = m.id, n = 10 }) end)
		btn(f, 322, 90, "+100", PURPLE, function() call("mat", { id = m.id, n = 100 }) end)
		btn(f, 418, 90, "+1000", GOLD, function() call("mat", { id = m.id, n = 1000 }) end)
	end
	heading("BLUEPRINTS")
	for _, bp in ipairs(Company.Blueprints or {}) do
		local f = row()
		label(f, tostring(bp.icon or "📘") .. " " .. tostring(bp.name or bp.id), 220)
		btn(f, 226, 90, "+1", BLUE, function() call("bp", { id = bp.id, n = 1 }) end)
		btn(f, 322, 90, "+5", PURPLE, function() call("bp", { id = bp.id, n = 5 }) end)
		btn(f, 418, 90, "+25", GOLD, function() call("bp", { id = bp.id, n = 25 }) end)
	end
	heading("CARS")
	local f = row()
	btn(f, 0, 220, "🚗 Unlock all cars", GOLD, function() call("vehicles") end)
end
function PAGES.move()
	heading("TELEPORT")
	local f = row()
	btn(f, 0, 260, "📍 Go to this player", BLUE, function() call("teleport") end)
	btn(f, 268, 260, "🧲 Bring them to me", PURPLE, function() call("bring") end)
end

local tabButtons = {}
local function redraw()
	for _, c in ipairs(content:GetChildren()) do if c:IsA("GuiObject") then c:Destroy() end end
	order = 0
	PAGES[tab]()
	for id, b in pairs(tabButtons) do
		local bg = b:FindFirstChild("Bg")
		if bg then bg.ImageColor3 = id == tab and Color3.fromRGB(70, 120, 230) or UI.TAB_OFF; bg:SetAttribute("Color", bg.ImageColor3) end
	end
	refreshStats()
end
PAGES._redraw = redraw
for i, t in ipairs(TABS) do
	local b = UI.button(t[2], UI.TAB_OFF, nil, { Size = UDim2.fromOffset(110, 38), TextSize = 14, LayoutOrder = i, ZIndex = 12, Parent = tabRow })
	tabButtons[t[1]] = b
	b.Activated:Connect(function() tab = t[1]; redraw() end)
end

-- the selected player changes: redraw the page (passes show their own state)
local lastTarget
RunService.Heartbeat:Connect(function()
	if not window.Visible then return end
	if lastTarget ~= targetId then
		lastTarget = targetId
		redraw()
	end
end)
task.spawn(function()
	while gui.Parent do
		if window.Visible then refreshStats() end
		task.wait(0.5)
	end
end)

local function setOpen(on)
	window.Visible = on
	if on then
		if not target() then targetId = player.UserId end
		redrawList()
		redraw()
	end
end
openBtn.Activated:Connect(function() setOpen(not window.Visible) end)
closeBtn.Activated:Connect(function() setOpen(false) end)
