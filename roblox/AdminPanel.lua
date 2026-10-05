-- BlockRise Empire - Admin panel (owner only), client side: ServerStorage.AdminPanel.AdminClient
-- The server copies this ScreenGui into the owner's PlayerGui only, with the AdminRF remote inside it.
-- Nothing here is trusted: every action is checked again on the server.
-- Simple on purpose: 1) pick a player at the top  2) pick what to give on the left  3) tap a big button.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local UIS = game:GetService("UserInputService")

local gui = script.Parent
local rf = gui:WaitForChild("AdminRF", 30)
if not rf then return end
local Config = require(RS:WaitForChild("Shared"):WaitForChild("Config"))
local Company = require(RS.Shared:WaitForChild("Company"))
local UI = require(RS.Shared:WaitForChild("UIKit"))
local K = require(RS.Shared:WaitForChild("MenuKit"))
local T = UI.Theme
local new = UI.new
local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

gui.ResetOnSpawn = false
gui.DisplayOrder = 80
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

-- same scale as the HUD
local scale = new("UIScale", { Parent = gui })
local function updateScale()
	local vp = camera.ViewportSize
	local touch = UIS.TouchEnabled and not UIS.KeyboardEnabled
	scale.Scale = touch and math.clamp(math.min(vp.X / 1080, vp.Y / 700), 0.45, 1) or math.clamp(math.min(vp.X / 1150, vp.Y / 760), 0.55, 1.1)
end
camera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)
updateScale()

local GOLD = Color3.fromRGB(255, 196, 46)
local RED = Color3.fromRGB(235, 70, 80)
local GREEN = K.GREEN
local BLUE = Color3.fromRGB(70, 160, 255)
local PURPLE = Color3.fromRGB(165, 110, 255)
local C3 = Color3.fromRGB

local function fmt(n) return Config.FormatNum(math.floor(tonumber(n) or 0)) end
local function money(n) return Config.FormatMoney(tonumber(n) or 0) end
local function short(n)
	n = tonumber(n) or 0
	if n >= 1e3 and Config.Short then return Config.Short(n) end
	return fmt(n)
end

-- "1.5M", "250k", "2b", "1,000,000" -> number
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
-- the ADMIN button (right side, under MORE)
---------------------------------------------------------------------------
local openBtn = UI.button("ADMIN", RED, C3(170, 30, 50), { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 300),
	Size = UDim2.fromOffset(100, 44), TextSize = 20, Font = T.chunky, Icon = "vip", ZIndex = 2, Parent = gui })
openBtn.Name = "AdminButton"

---------------------------------------------------------------------------
-- the window (same style as the game's own windows)
---------------------------------------------------------------------------
local back = new("TextButton", { Name = "Backdrop", Text = "", AutoButtonColor = false, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromScale(4, 4), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.45, Visible = false, ZIndex = 1, Parent = gui })
local window, closeBtn = K.window(gui, UDim2.fromOffset(1000, 650), "ADMIN", C3(255, 90, 90), C3(190, 30, 60), "vip")
window.Visible = false
window.ZIndex = 5

-- 1) the player
local who = K.text({ Position = UDim2.fromOffset(28, 56), Size = UDim2.fromOffset(300, 30), Text = "1. ALEGE JUCATORUL", Font = T.chunky, TextSize = 22,
	TextColor3 = GOLD, Stroke = 2.5, ZIndex = 6, Parent = window })
local strip = new("ScrollingFrame", { Position = UDim2.fromOffset(24, 88), Size = UDim2.new(1, -48, 0, 78), BackgroundTransparency = 1, BorderSizePixel = 0,
	ScrollBarThickness = 4, ScrollingDirection = Enum.ScrollingDirection.X, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.X, ZIndex = 6, Parent = window })
new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder, VerticalAlignment = Enum.VerticalAlignment.Center, Parent = strip })

-- what that player has now
local summary = new("Frame", { Position = UDim2.fromOffset(24, 172), Size = UDim2.new(1, -48, 0, 30), BackgroundTransparency = 1, ZIndex = 6, Parent = window })
new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder, Parent = summary })

-- 2) what to give (left) and 3) the buttons (right)
K.text({ Position = UDim2.fromOffset(28, 210), Size = UDim2.fromOffset(200, 30), Text = "2. CE II DAI?", Font = T.chunky, TextSize = 22,
	TextColor3 = GOLD, Stroke = 2.5, ZIndex = 6, Parent = window })
local cats = new("ScrollingFrame", { Position = UDim2.fromOffset(24, 244), Size = UDim2.fromOffset(200, 384), BackgroundTransparency = 1, BorderSizePixel = 0,
	ScrollBarThickness = 4, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ZIndex = 6, Parent = window })
new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder, Parent = cats })
local page = new("ScrollingFrame", { Position = UDim2.fromOffset(238, 214), Size = UDim2.new(1, -262, 0, 414), BackgroundColor3 = C3(36, 30, 92),
	BackgroundTransparency = 0.35, BorderSizePixel = 0, ScrollBarThickness = 6, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ZIndex = 6, Parent = window })
UI.corner(14).Parent = page
UI.pad(14, 12).Parent = page
new("UIListLayout", { Padding = UDim.new(0, 12), SortOrder = Enum.SortOrder.LayoutOrder, Parent = page })

-- the answer: a big pill at the bottom of the window
local toast = new("Frame", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, 26), Size = UDim2.fromOffset(560, 46), BackgroundColor3 = GREEN,
	Visible = false, ZIndex = 40, Parent = window })
UI.corner(23).Parent = toast
new("UIStroke", { Thickness = 3, Color = T.ink, Parent = toast })
local toastLbl = K.text({ Size = UDim2.fromScale(1, 1), Text = "", Font = T.chunky, TextSize = 20, TextColor3 = Color3.new(1, 1, 1), Stroke = 2.5,
	TextXAlignment = Enum.TextXAlignment.Center, Max = 20, ZIndex = 41, Parent = toast })
local toastN = 0
local function say(ok, msg)
	toastN += 1
	local n = toastN
	toast.BackgroundColor3 = ok and GREEN or RED
	toastLbl.Text = (ok and "GATA!  " or "NU MERGE:  ") .. tostring(msg or "")
	toast.Visible = true
	task.delay(3, function() if toastN == n then toast.Visible = false end end)
end

---------------------------------------------------------------------------
-- the selected player
---------------------------------------------------------------------------
local targetId = player.UserId
local function target() return Players:GetPlayerByUserId(targetId) end
local redrawPage, redrawPlayers, redrawSummary

local thumbs = {}
local function headshot(userId)
	if thumbs[userId] then return thumbs[userId] end
	local ok, img = pcall(function() return Players:GetUserThumbnailAsync(userId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100) end)
	thumbs[userId] = ok and img or ""
	return thumbs[userId]
end

function redrawPlayers()
	for _, c in ipairs(strip:GetChildren()) do if c:IsA("GuiObject") then c:Destroy() end end
	local all = Players:GetPlayers()
	table.sort(all, function(a, b)
		if a == player then return true elseif b == player then return false end
		return a.DisplayName:lower() < b.DisplayName:lower()
	end)
	for i, p in ipairs(all) do
		local sel = p.UserId == targetId
		local card = new("TextButton", { Name = p.Name, Text = "", AutoButtonColor = false, Size = UDim2.fromOffset(200, 70), BackgroundTransparency = 1, LayoutOrder = i, ZIndex = 7, Parent = strip })
		UI.slice("tile", { ImageColor3 = sel and C3(255, 226, 120) or K.TILE, ZIndex = 7, Parent = card })
		local pic = new("ImageLabel", { Position = UDim2.fromOffset(10, 9), Size = UDim2.fromOffset(52, 52), BackgroundColor3 = C3(200, 205, 235), Image = "", ZIndex = 8, Parent = card })
		UI.corner(26).Parent = pic
		task.spawn(function() pic.Image = headshot(p.UserId) end)
		K.text({ Position = UDim2.fromOffset(70, 10), Size = UDim2.new(1, -78, 0, 26), Text = (p == player and "TU: " or "") .. p.DisplayName, Font = T.title, TextSize = 19, Max = 19,
			TextColor3 = K.DARK, ZIndex = 8, Parent = card })
		K.text({ Position = UDim2.fromOffset(70, 36), Size = UDim2.new(1, -78, 0, 22), Text = "Nivel " .. tostring(p:GetAttribute("Level") or "?"), TextSize = 15, Max = 15,
			TextColor3 = K.SUB, ZIndex = 8, Parent = card })
		if sel then
			K.chip(card, "ALES", GREEN, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -6, 0, -8), ZIndex = 9 })
		end
		card.Activated:Connect(function()
			targetId = p.UserId
			redrawPlayers()
			redrawPage()
		end)
	end
	who.Text = "1. ALEGE JUCATORUL  (" .. #all .. " pe server)"
end

local lastSummary = ""
function redrawSummary(force)
	local p = target()
	if not p then return end
	local a = function(k, d) local v = p:GetAttribute(k) if v == nil then return d or 0 end return v end
	local passes = 0
	for _, ps in ipairs(Config.Store.passes) do if a("Pass_" .. ps.key, false) == true then passes += 1 end end
	local tool = Config.Tools[a("ToolTier", 1)]
	local chips = {
		{ "BANI " .. money(a("Money")), C3(60, 180, 90) }, { "DIAMANTE " .. short(a("Gems")), C3(40, 150, 230) }, { "NIVEL " .. fmt(a("Level", 1)), C3(230, 150, 30) },
		{ "REP " .. short(a("Rep")), C3(200, 120, 40) }, { (tool and tool.name or "?"):upper(), C3(140, 90, 230) }, { "PASS-URI " .. passes .. "/" .. #Config.Store.passes, C3(230, 70, 120) },
	}
	local key = ""
	for _, c in ipairs(chips) do key ..= c[1] end
	if key == lastSummary and not force then return end
	lastSummary = key
	for _, c in ipairs(summary:GetChildren()) do if c:IsA("GuiObject") then c:Destroy() end end
	for i, c in ipairs(chips) do K.chip(summary, c[1], c[2], { LayoutOrder = i, ZIndex = 7 }) end
end

---------------------------------------------------------------------------
-- talking to the server
---------------------------------------------------------------------------
local busy = false
local function call(action, v, redraw)
	if busy then return end
	busy = true
	task.spawn(function()
		local ok, res, msg = pcall(function() return rf:InvokeServer(action, targetId, v) end)
		busy = false
		if not ok then say(false, "server error") else say(res == true, msg) end
		task.wait(0.2)
		redrawSummary(true)
		if redraw then redrawPage() end
	end)
end

---------------------------------------------------------------------------
-- page building blocks: a title, a row of big buttons, a box for your own number
---------------------------------------------------------------------------
local order = 0
local function nextOrder() order += 1 return order end
local function title(text, sub)
	local f = new("Frame", { Size = UDim2.new(1, 0, 0, sub and 52 or 32), BackgroundTransparency = 1, LayoutOrder = nextOrder(), ZIndex = 7, Parent = page })
	K.text({ Size = UDim2.new(1, 0, 0, 32), Text = text, Font = T.chunky, TextSize = 26, TextColor3 = Color3.new(1, 1, 1), Stroke = 3, Max = 26, ZIndex = 8, Parent = f })
	if sub then K.text({ Position = UDim2.fromOffset(0, 32), Size = UDim2.new(1, 0, 0, 20), Text = sub, TextSize = 15, TextColor3 = K.NOTE, ZIndex = 8, Parent = f }) end
end
-- buttons = { {label, color, fn}, ... } all the same size, in one row
local function bigButtons(buttons, h)
	local f = new("Frame", { Size = UDim2.new(1, 0, 0, h or 56), BackgroundTransparency = 1, LayoutOrder = nextOrder(), ZIndex = 7, Parent = page })
	new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder, Parent = f })
	local n = #buttons
	for i, b in ipairs(buttons) do
		K.button(f, b[1], b[2], { Size = UDim2.new(1 / n, -math.ceil(8 * (n - 1) / n), 1, 0), TextSize = 22, LayoutOrder = i, ZIndex = 8, Shine = b.shine }, b[3])
	end
end
-- [ your number ] [ GIVE ] [ SET TO ] [ RESET ]
local function ownNumber(action, hint, canReset)
	local f = new("Frame", { Size = UDim2.new(1, 0, 0, 50), BackgroundTransparency = 1, LayoutOrder = nextOrder(), ZIndex = 7, Parent = page })
	local boxBg = new("Frame", { Size = UDim2.new(0.4, 0, 1, -6), Position = UDim2.fromOffset(0, 2), BackgroundColor3 = Color3.fromRGB(250, 250, 255), ZIndex = 8, Parent = f })
	UI.corner(14).Parent = boxBg
	new("UIStroke", { Thickness = 3, Color = T.ink, Parent = boxBg })
	local box = new("TextBox", { Position = UDim2.fromOffset(12, 0), Size = UDim2.new(1, -24, 1, 0), BackgroundTransparency = 1, Text = "", PlaceholderText = hint or "alt numar (ex: 2.5M)",
		PlaceholderColor3 = C3(140, 140, 175), TextColor3 = K.DARK, Font = T.title, TextSize = 20, ClearTextOnFocus = false, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 9, Parent = boxBg })
	local function go(mode)
		local n = parse(box.Text)
		if not n then say(false, "scrie un numar (ex: 1.5M, 200K, 3B)") return end
		call(action, { mode = mode, n = n })
	end
	K.button(f, "DA +", GREEN, { Position = UDim2.new(0.4, 8, 0, 0), Size = UDim2.new(0.2, -8, 1, 0), TextSize = 20, ZIndex = 8 }, function() go("add") end)
	K.button(f, "SETEAZA", BLUE, { Position = UDim2.new(0.6, 8, 0, 0), Size = UDim2.new(0.2, -8, 1, 0), TextSize = 20, ZIndex = 8 }, function() go("set") end)
	if canReset then
		K.button(f, "PE 0", RED, { Position = UDim2.new(0.8, 8, 0, 0), Size = UDim2.new(0.2, -8, 1, 0), TextSize = 20, ZIndex = 8 }, function() call(action, { mode = "set", n = 0 }) end)
	end
end
local function add(action, n) return function() call(action, { mode = "add", n = n }) end end
local function grid(cellH)
	return K.grid(page, nextOrder(), 3, cellH or 250)
end

local PASS_ICON = { vip = "vip", bigcrew = "hire", cash2x = "up_cash", strength2x = "up_strength", autobuild = "🤖", autotrain = "gym", gems2x = "gem",
	fasttools = "up_power", monster = "cars", goldcar = "cars", teleporter = "locations", skipanim = "⏭️" }

---------------------------------------------------------------------------
-- the pages
---------------------------------------------------------------------------
local PAGES = {}
PAGES[1] = { "BANI", "cash", C3(70, 200, 100), function()
	title("BANI", "apasa un buton: se adauga imediat")
	bigButtons({ { "+1K", GREEN, add("money", 1e3) }, { "+1M", GREEN, add("money", 1e6) }, { "+1B", GREEN, add("money", 1e9) } })
	bigButtons({ { "+1T", GOLD, add("money", 1e12) }, { "+1Qa", GOLD, add("money", 1e15) }, { "+1Qi", GOLD, add("money", 1e18) } })
	ownNumber("money", nil, true)
end }
PAGES[2] = { "DIAMANTE", "gem", C3(70, 170, 255), function()
	title("DIAMANTE", "apasa un buton: se adauga imediat")
	bigButtons({ { "+100", BLUE, add("gems", 100) }, { "+1K", BLUE, add("gems", 1e3) }, { "+10K", BLUE, add("gems", 1e4) } })
	bigButtons({ { "+100K", PURPLE, add("gems", 1e5) }, { "+1M", PURPLE, add("gems", 1e6) } })
	ownNumber("gems", nil, true)
end }
PAGES[3] = { "NIVEL", "level", C3(255, 170, 40), function()
	title("NIVEL")
	bigButtons({ { "+1", GOLD, add("level", 1) }, { "+10", GOLD, add("level", 10) }, { "+50", GOLD, add("level", 50) }, { "+100", GOLD, add("level", 100) } })
	ownNumber("level", "seteaza nivelul (ex: 75)")
	title("REPUTATIE")
	bigButtons({ { "+1K", C3(230, 140, 50), add("rep", 1e3) }, { "+10K", C3(230, 140, 50), add("rep", 1e4) }, { "+100K", C3(230, 140, 50), add("rep", 1e5) }, { "+1M", C3(230, 140, 50), add("rep", 1e6) } })
	ownNumber("rep", nil, true)
end }
PAGES[4] = { "PUTERE", "strength", C3(255, 120, 80), function()
	title("PUTERE (STRENGTH)")
	bigButtons({ { "+1M", C3(255, 120, 80), add("strength", 1e6) }, { "+1B", C3(255, 120, 80), add("strength", 1e9) }, { "+1T", C3(255, 120, 80), add("strength", 1e12) } })
	ownNumber("strength", nil, true)
	title("ECHIPAMENT DE ANTRENAMENT", "apasa pe cel pe care vrei sa il aiba")
	local p = target()
	local cur = p and p:GetAttribute("GearTier") or 1
	local g = grid(200)
	for i, gear in ipairs(Config.TrainingGear) do
		local o = { order = i, name = gear.name, icon = "strength", color = K.RAR[(K.rarityOf(i, #Config.TrainingGear))], artH = 90 }
		if i == cur then o.status = { "ARE ACUM", GREEN } else o.button = { "DA", BLUE, function() call("gear", i, true) end } end
		K.tile(g, o)
	end
end }
PAGES[5] = { "CIOCANE", "shop", C3(150, 110, 255), function()
	title("CIOCANE", "apasa pe ciocanul pe care vrei sa il aiba (le are si pe toate de dinainte)")
	local p = target()
	local cur = p and p:GetAttribute("ToolTier") or 1
	local g = grid(250)
	for i, t in ipairs(Config.Tools) do
		local rk, rl = K.rarityOf(i, #Config.Tools)
		local o = { order = i, name = t.name, icon = t.icon or "shop", iconScale = t.icon and 1.08 or nil, color = K.RAR[rk], badge = { rl, K.RAR[rk] } }
		if i == cur then o.status = { "ARE ACUM", GREEN }; o.spin = true
		else o.button = { "DA", i > cur and GREEN or BLUE, function() call("tool", i, true) end } end
		K.tile(g, o)
	end
	local sh = Config.StormHammer
	if sh then
		title("THUNDERCLAP (pass Robux)")
		local owned = p and p:GetAttribute("Pass_" .. sh.pass) == true
		K.banner(page, nextOrder(), { name = string.upper(sh.name), line = owned and "Il are deja." or "Il primeste gratis de la tine.", icon = sh.icon or "up_power",
			color = sh.color, tint = C3(150, 200, 255), buttonW = 180,
			button = owned and { "SCOATE", RED, function() call("pass", { key = sh.pass, on = false }, true) end }
				or { "DA GRATIS", GREEN, function() call("pass", { key = sh.pass, on = true }, true) end } })
	end
end }
PAGES[6] = { "PASS-URI", "vip", C3(230, 80, 140), function()
	title("PASS-URI (GRATIS DE AICI)", "raman salvate pentru totdeauna, ca si cum le-ar fi cumparat")
	bigButtons({ { "DA-LE PE TOATE", GOLD, function()
		if busy then return end
		busy = true
		task.spawn(function()
			local given = 0
			for _, ps in ipairs(Config.Store.passes) do
				local tp = target()
				if tp and tp:GetAttribute("Pass_" .. ps.key) ~= true then
					local ok, res = pcall(function() return rf:InvokeServer("pass", targetId, { key = ps.key, on = true }) end)
					if ok and res then given += 1 end
					task.wait(0.1)
				end
			end
			busy = false
			say(true, given .. " pass-uri date")
			task.wait(0.2)
			redrawSummary(true)
			redrawPage()
		end)
	end, shine = true } })
	local p = target()
	local g = grid(240)
	for i, ps in ipairs(Config.Store.passes) do
		local owned = p and p:GetAttribute("Pass_" .. ps.key) == true
		local icon = PASS_ICON[ps.key] or ps.icon
		if ps.key == (Config.StormHammer and Config.StormHammer.pass) then icon = Config.StormHammer.icon or icon end
		local o = { order = i, name = ps.name, icon = icon, color = owned and C3(90, 200, 120) or C3(150, 150, 190), tag = owned and { "ARE", GREEN } or nil, artH = 110 }
		o.button = owned and { "SCOATE", RED, function() call("pass", { key = ps.key, on = false }, true) end }
			or { "DA GRATIS", GREEN, function() call("pass", { key = ps.key, on = true }, true) end }
		K.tile(g, o)
	end
end }
PAGES[7] = { "BOOST-URI", "up_power", C3(255, 200, 60), function()
	title("BOOST-URI", "se aduna la timpul pe care il are deja")
	local g = grid(240)
	local i = 0
	for key, b in pairs(Config.Boosts) do
		i += 1
		K.tile(g, { order = i, name = tostring(b.name or key), icon = ({ cash = "up_cash", crew = "up_crew", power = "up_power", strength = "up_strength" })[key] or "up_power",
			color = C3(255, 170, 50), artH = 110, buttons = {
				{ "15m", BLUE, function() call("boost", { key = key, secs = 900 }) end },
				{ "1h", PURPLE, function() call("boost", { key = key, secs = 3600 }) end },
				{ "1zi", GOLD, function() call("boost", { key = key, secs = 86400 }) end } } })
	end
	K.tile(g, { order = 10, name = "Rush Crew 2x", icon = "crew", color = C3(255, 150, 40), artH = 110, buttons = {
		{ "30m", BLUE, function() call("rush", 1800) end }, { "2h", PURPLE, function() call("rush", 7200) end }, { "1zi", GOLD, function() call("rush", 86400) end } } })
	K.tile(g, { order = 11, name = "Spin-uri gratis", icon = "spin", color = C3(150, 120, 255), artH = 110, buttons = {
		{ "+1", BLUE, function() call("spins", 1) end }, { "+5", PURPLE, function() call("spins", 5) end }, { "+25", GOLD, function() call("spins", 25) end } } })
end }
PAGES[8] = { "MATERIALE", "backpack", C3(120, 200, 255), function()
	title("MATERIALE")
	local g = grid(240)
	for i, m in ipairs(Company.Materials or {}) do
		K.tile(g, { order = i, name = tostring(m.name or m.id), icon = m.icon or "backpack", color = C3(120, 170, 230), artH = 110, buttons = {
			{ "+100", BLUE, function() call("mat", { id = m.id, n = 100 }) end }, { "+1000", GOLD, function() call("mat", { id = m.id, n = 1000 }) end } } })
	end
	title("BLUEPRINTS")
	local g2 = grid(240)
	for i, bp in ipairs(Company.Blueprints or {}) do
		K.tile(g2, { order = i, name = tostring(bp.name or bp.id), icon = bp.icon or "portfolio", color = C3(90, 140, 230), artH = 110, buttons = {
			{ "+5", BLUE, function() call("bp", { id = bp.id, n = 5 }) end }, { "+25", GOLD, function() call("bp", { id = bp.id, n = 25 }) end } } })
	end
end }
PAGES[9] = { "MASINI", "cars", C3(255, 100, 100), function()
	title("MASINI")
	K.banner(page, nextOrder(), { name = "TOATE MASINILE", line = "Deblocheaza toate masinile din dealer.", icon = "cars", color = C3(255, 110, 110), tint = C3(255, 200, 200),
		buttonW = 180, button = { "DEBLOCHEAZA", GREEN, function() call("vehicles") end } })
end }
PAGES[10] = { "TELEPORT", "locations", C3(80, 200, 220), function()
	title("TELEPORT")
	local p = target()
	if p == player then
		K.note(page, nextOrder(), "Alege alt jucator de sus ca sa te teleportezi la el sau sa il aduci la tine.")
		return
	end
	K.banner(page, nextOrder(), { name = "DU-MA LA " .. string.upper(p and p.DisplayName or "?"), line = "Te muta langa el.", icon = "locations", color = C3(80, 200, 220),
		tint = C3(190, 240, 250), buttonW = 180, button = { "DU-MA", BLUE, function() call("teleport") end } })
	K.banner(page, nextOrder(), { name = "ADU-L LA MINE", line = "Il muta langa tine.", icon = "invite", color = C3(170, 120, 255), tint = C3(220, 200, 255),
		buttonW = 180, button = { "ADU-L", PURPLE, function() call("bring") end } })
end }
PAGES[11] = { "ALTELE", "settings", C3(160, 160, 200), function()
	title("ALTELE")
	K.banner(page, nextOrder(), { name = "TERMINA CONTRACTUL", line = "Cladirea la care lucreaza acum se termina pe loc.", icon = "contract", color = C3(90, 200, 120),
		tint = C3(200, 240, 210), buttonW = 180, button = { "TERMINA", GREEN, function() call("finish") end } })
	K.banner(page, nextOrder(), { name = "SARI PESTE TUTORIAL", line = "Deblocheaza JOBS si SHOP imediat.", icon = "quest", color = C3(255, 190, 60),
		tint = C3(255, 235, 180), buttonW = 180, button = { "SARI", BLUE, function() call("tutorial") end } })
	-- start over from zero (yourself only; the server refuses anyone else)
	if target() == player then
		title("ZONA PERICULOASA")
		local armed = false
		local banner = K.banner(page, nextOrder(), { name = "RESETEAZA-MI PROGRESUL", line = "Doar contul tau: incepi de la 0 (tutorial de la pasul 1). Ce ai cumparat cu Robux ramane. Iesi din joc si intri din nou.",
			icon = "rebirth", color = RED, tint = C3(255, 200, 200), buttonW = 210, height = 120 })
		local b = K.button(banner, "RESETEAZA", RED, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -16, 0.5, 0), Size = UDim2.fromOffset(210, 58), TextSize = 22, ZIndex = 8 })
		b.Activated:Connect(function()
			local lbl = b:FindFirstChild("Label")
			if not armed then
				-- first tap only arms it: a second tap within 5 s does it
				armed = true
				if lbl then lbl.Text = "SIGUR? APASA IAR" end
				task.delay(5, function() armed = false; if lbl and lbl.Parent then lbl.Text = "RESETEAZA" end end)
				return
			end
			armed = false
			if lbl then lbl.Text = "SE RESETEAZA..." end
			call("resetme", { confirm = "RESET" })
		end)
	end
	title("STELE & REBIRTH", "stele pentru Star Shop, si numarul de rebirth-uri")
	bigButtons({ { "+100 STELE", PURPLE, add("stars", 100) }, { "+1000 STELE", GOLD, add("stars", 1000) }, { "+1 REBIRTH", C3(200, 120, 255), add("rebirths", 1) } })
end }

local cat = 1
local catButtons = {}
function redrawPage()
	for _, c in ipairs(page:GetChildren()) do if c:IsA("GuiObject") then c:Destroy() end end
	order = 0
	PAGES[cat][4]()
	page.CanvasPosition = Vector2.zero
	for i, b in ipairs(catButtons) do
		local bg = b:FindFirstChild("Bg")
		local col = i == cat and PAGES[i][3] or C3(70, 66, 130)
		if bg then bg.ImageColor3 = col; bg:SetAttribute("Color", col) end
		local s = b:FindFirstChildOfClass("UIStroke")
		if s then s.Enabled = i == cat end
	end
end
for i, pg in ipairs(PAGES) do
	local b = UI.button(pg[1], C3(70, 66, 130), nil, { Size = UDim2.new(1, -8, 0, 50), TextSize = 19, Font = T.chunky, Icon = pg[2], LayoutOrder = i, ZIndex = 7, Parent = cats })
	new("UIStroke", { Thickness = 3, Color = GOLD, Enabled = false, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = b })
	catButtons[i] = b
	b.Activated:Connect(function() cat = i; redrawPage() end)
end

Players.PlayerAdded:Connect(function() if window.Visible then redrawPlayers() end end)
Players.PlayerRemoving:Connect(function(p)
	if p.UserId == targetId then targetId = player.UserId end
	task.defer(function() if window.Visible then redrawPlayers(); redrawPage() end end)
end)
task.spawn(function()
	while gui.Parent do
		if window.Visible then redrawSummary() end
		task.wait(0.5)
	end
end)

local function setOpen(on)
	window.Visible = on
	back.Visible = on
	if on then
		if not target() then targetId = player.UserId end
		redrawPlayers()
		redrawSummary(true)
		redrawPage()
	end
end
openBtn.Activated:Connect(function() setOpen(not window.Visible) end)
if closeBtn then closeBtn.Activated:Connect(function() setOpen(false) end) end
back.Activated:Connect(function() setOpen(false) end)
