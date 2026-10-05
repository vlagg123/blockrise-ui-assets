-- BlockRise Empire - Shop window: tools, training gear, heavy machines and the crew, as item tiles
local RS = game:GetService("ReplicatedStorage")
local Icons = require(RS.Shared:WaitForChild("Icons"))
local K = require(RS.Shared:WaitForChild("MenuKit"))

local M = {}
local c, UI, T, Config
local tab = "tools"

local TABS = {
	{ id = "tools", label = "TOOLS", icon = "shop", c1 = Color3.fromRGB(110, 200, 255), c2 = Color3.fromRGB(40, 110, 230) },
	{ id = "gear", label = "TRAINING", icon = "strength", c1 = Color3.fromRGB(255, 170, 110), c2 = Color3.fromRGB(225, 85, 40) },
	{ id = "machines", label = "MACHINES", icon = "mega", c1 = Color3.fromRGB(255, 214, 70), c2 = Color3.fromRGB(240, 135, 20) },
	{ id = "crew", label = "CREW", icon = "crew", c1 = Color3.fromRGB(130, 240, 140), c2 = Color3.fromRGB(30, 160, 80) },
}
local THEME = {}
for _, t in ipairs(TABS) do THEME[t.id] = t end

local GOLD = Color3.fromRGB(255, 190, 40)
local MACHINE_ICON = { excavator = "🚜", mixer = "🚚", crane = "mega" }
local MACHINE_COL = { excavator = Color3.fromRGB(255, 186, 60), mixer = Color3.fromRGB(110, 190, 255), crane = Color3.fromRGB(255, 120, 110) }
local WORKER_ICON = { laborer = "crew", builder = "hire", foreman = "up_crew" }
local WORKER_COL = { laborer = Color3.fromRGB(255, 196, 70), builder = Color3.fromRGB(90, 200, 120), foreman = Color3.fromRGB(165, 110, 255) }

local function money() return c.player:GetAttribute("Money") or 0 end
local function fmt(n) return Config.FormatMoney(n) end
local function cols() return (_G.__CE_ListWidth and _G.__CE_ListWidth() or 780) >= 700 and 4 or 3 end

-- buy on the server, then redraw where you were
local function buy(remote, arg, keep)
	c.click()
	local ok, res, msg = pcall(function() return c.R[remote]:InvokeServer(arg) end)
	if ok and res then
		M.Show(nil, keep)
	else
		c.toast("⚠️ " .. tostring(msg or "Can't buy that"), T.red)
	end
end

-- the hammer in your hand: the one you picked, the Thunderclap if you own it, or your best
local function equippedTool()
	local cur = c.player:GetAttribute("ToolTier") or 1
	local eq = tonumber(c.player:GetAttribute("EquipTool") or "")
	if eq and eq >= 1 and eq <= cur then return eq end
	local sh = Config.StormHammer
	if sh and c.player:GetAttribute("Pass_" .. sh.pass) == true then return sh.key end
	return cur
end
local function equipTool(which)
	c.click()
	local rf = RS:FindFirstChild("Remotes") and RS.Remotes:FindFirstChild("EquipTool")
	if not rf then return end
	local ok, res, msg = pcall(function() return rf:InvokeServer(which) end)
	if ok and res then
		local sh = Config.StormHammer
		local name = (sh and which == sh.key) and sh.name or (Config.Tools[which] and Config.Tools[which].name) or "Hammer"
		c.toast("🔨 " .. name .. " equipped", T.green, 2)
		M.Show(nil, true)
	else
		c.toast("⚠️ " .. tostring(msg or "Can't equip that"), T.red)
	end
end
local EQUIP_BLUE = Color3.fromRGB(70, 160, 255)

-- a tier list (tools / gear): every tier, the locked ones show their price; the window opens on your row
-- equip = { which, onEquip }: the hammers you own can be picked (tools only)
local function tierTiles(list, current, remote, icon, stat, keep, equip)
	local n = cols()
	local grid = K.grid(c.content, 2, n, 268)
	local cash = money()
	local mine
	for i, it in ipairs(list) do
		local rk, rl = K.rarityOf(i, #list)
		local o = { order = i, name = it.name, icon = it.icon or (Icons.has((icon .. "_" .. i)) and (icon .. "_" .. i) or icon), color = K.RAR[rk], iconScale = it.icon and 1.08 or nil,
			badge = { rl, K.RAR[rk] }, stats = { stat(it) } }
		if equip and i <= current then
			if i == equip.which then
				o.status = { "EQUIPPED", K.GREEN }
				o.spin = true
			else
				o.button = { "EQUIP", EQUIP_BLUE, function() equip.onEquip(i) end }
			end
		elseif i == current then
			o.status = { "EQUIPPED", K.GREEN }
			o.spin = true
		elseif i < current then
			o.status = { "OWNED", K.LOCK }
		elseif i == current + 1 then
			local can = cash >= it.price
			o.tag = { "NEXT", T.red }
			o.button = { fmt(it.price), can and K.GREEN or K.LOCK, function()
				if not can then c.click(); c.toast("💸 Not enough cash yet", T.red, 2) return end
				buy(remote, i, true)
			end, icon = "cash", shine = can }
		else
			o.dim = true
			o.status = { "🔒 " .. fmt(it.price), K.LOCK }
		end
		local t = K.tile(grid, o)
		if i == current then mine = t end
	end
	-- open on the row with your tier (a redraw after a purchase keeps the scroll instead)
	if mine and not keep and current > n then K.scrollTo(c.content, mine, 4) end
end

local keepNext = false
-- the Thunderclap Hammer: a Robux add-on that triples your build power, on top of the hammer you have
local function stormBanner(order)
	local sh = Config.StormHammer
	if not sh then return end
	local pass
	for _, p in ipairs(Config.Store.passes) do if p.key == sh.pass then pass = p end end
	if not pass then return end
	local studio = game:GetService("RunService"):IsStudio()
	if (pass.id or 0) <= 0 and not studio then return end -- not on sale yet
	local owned = c.player:GetAttribute("Pass_" .. sh.pass) == true
	local o = { name = string.upper(sh.name), line = "A storm in a hammer: x" .. sh.mult .. " build power for you and your crew. Forever.",
		icon = sh.icon or "up_power", color = sh.color, tint = Color3.fromRGB(150, 200, 255), buttonW = 180 }
	if owned and equippedTool() == sh.key then
		o.status = { "EQUIPPED", K.GREEN }
	elseif owned then
		o.button = { "EQUIP", EQUIP_BLUE, function() equipTool(sh.key) end }
	elseif (pass.id or 0) > 0 then
		o.button = { "R$ " .. tostring(pass.price or ""), Color3.fromRGB(80, 170, 255), function()
			c.click()
			game:GetService("MarketplaceService"):PromptGamePassPurchase(c.player, pass.id)
		end }
	else
		o.status = { "SOON · R$" .. tostring(pass.price or "?"), K.LOCK }
	end
	K.banner(c.content, order, o)
end

local function tools()
	stormBanner(0)
	K.section(c.content, 1, "BUILDING TOOLS", Color3.fromRGB(150, 215, 255), "more build power per hit")
	tierTiles(Config.Tools, c.player:GetAttribute("ToolTier") or 1, "BuyTool", "shop", function(t)
		return { "x" .. Config.FormatNum(t.power) .. " POWER", GOLD }
	end, keepNext, { which = equippedTool(), onEquip = equipTool })
end

local function gear()
	K.section(c.content, 1, "TRAINING GEAR", Color3.fromRGB(255, 190, 140), "more Strength per hit")
	tierTiles(Config.TrainingGear, c.player:GetAttribute("GearTier") or 1, "BuyGear", "strength", function(g)
		return { "x" .. Config.FormatNum(g.mult) .. " STRENGTH", Color3.fromRGB(255, 120, 80) }
	end, keepNext)
end

local function machines()
	K.section(c.content, 1, "HEAVY MACHINES", Color3.fromRGB(255, 220, 110), "they build on their own")
	local grid = K.grid(c.content, 2, cols(), 268)
	local lvl = c.player:GetAttribute("Level") or 1
	local cash = money()
	for i, m in ipairs(Config.Machines) do
		local owned = c.player:GetAttribute("M_" .. m.id) == true
		local mlv = owned and math.max(1, c.player:GetAttribute("ML_" .. m.id) or 1) or 1
		local rate = m.rate * Config.MachineMult(mlv) * c.buildPower()
		local o = { order = i, name = m.name, icon = MACHINE_ICON[m.id] or m.icon, color = MACHINE_COL[m.id] or GOLD,
			stats = { { Config.FormatNum(math.floor(rate)) .. " WORK/S", GOLD } } }
		if owned then
			o.tag = { "MK " .. mlv, K.DARK }
			if mlv >= Config.MachineMaxLevel then
				o.status = { "MAX", GOLD }
				o.spin = true
			else
				local cost = Config.MachineUpgradeCost(m, mlv)
				local can = cash >= cost
				o.button = { "⬆ " .. fmt(cost), can and Color3.fromRGB(255, 176, 40) or K.LOCK, function()
					if not can then c.click(); c.toast("💸 Not enough cash yet", T.red, 2) return end
					buy("BuyMachine", m.id, true)
				end, shine = can }
			end
		elseif lvl < m.reqLevel then
			o.dim = true
			o.status = { "🔒 LEVEL " .. m.reqLevel, K.LOCK }
		else
			local can = cash >= m.price
			o.button = { fmt(m.price), can and K.GREEN or K.LOCK, function()
				if not can then c.click(); c.toast("💸 Not enough cash yet", T.red, 2) return end
				buy("BuyMachine", m.id)
			end, icon = "cash", shine = can }
		end
		K.tile(grid, o)
	end
end

local function crew()
	local count, max = c.player:GetAttribute("WorkerCount") or 0, c.player:GetAttribute("MaxWorkers") or 2
	K.section(c.content, 1, "YOUR CREW", Color3.fromRGB(150, 245, 160), count .. " / " .. max .. " workers")
	c.modalSub.Text = "👷 " .. count .. " / " .. max
	local grid = K.grid(c.content, 2, cols(), 268)
	local lvl = c.player:GetAttribute("Level") or 1
	local cash = money()
	for i, w in ipairs(Config.WorkerTypes) do
		local have = c.player:GetAttribute("W_" .. w.id) or 0
		local wps = w.rate * c.buildPower()
		local stat = w.boost and { "CREW +" .. math.floor(w.boost * 100) .. "%", T.purple }
			or { (wps < 10 and string.format("%.1f", wps) or Config.FormatNum(math.floor(wps))) .. " WORK/S", GOLD }
		local o = { order = i, name = w.name, icon = WORKER_ICON[w.id] or "crew", color = WORKER_COL[w.id] or K.GREEN, stats = { stat } }
		if have > 0 then
			o.badge = { "x" .. have, K.DARK }
			-- let one go (50% back) to make room for a better one: two taps
			o.corner = { label = "FIRE", color = T.red, onClick = function(b)
				c.click()
				local l = b:FindFirstChild("Label")
				if l and l.Text ~= "SURE?" then
					l.Text = "SURE?"
					task.delay(2.5, function() if l.Parent then l.Text = "FIRE" end end)
					return
				end
				local ok, res, msg = pcall(function() return c.R.FireWorker:InvokeServer(w.id) end)
				if ok and res then M.Show("crew", true) else c.toast("⚠️ " .. tostring(msg or "Can't fire"), T.red) end
			end }
		end
		if lvl < w.reqLevel then
			o.dim = true
			o.status = { "🔒 LEVEL " .. w.reqLevel, K.LOCK }
		elseif count >= max then
			o.status = { "CREW FULL", K.LOCK }
		else
			local can = cash >= w.price
			o.button = { "HIRE " .. fmt(w.price), can and K.GREEN or K.LOCK, function()
				if not can then c.click(); c.toast("💸 Not enough cash yet", T.red, 2) return end
				buy("Hire", w.id, true)
			end, shine = can }
		end
		K.tile(grid, o)
	end
	K.note(c.content, 3, "Workers build your job on their own. Firing one gives 50% back.")
end

-- which tabs have something you can buy right now (the red dots on the tabs and the "!" on the SHOP button)
function M.Available()
	local p = c.player
	local cash = money()
	local out = { tools = false, gear = false, machines = false, crew = false, count = 0 }
	local tier, gt = p:GetAttribute("ToolTier") or 1, p:GetAttribute("GearTier") or 1
	local nt, ng = Config.Tools[tier + 1], Config.TrainingGear[gt + 1]
	out.tools = nt ~= nil and cash >= nt.price
	out.gear = ng ~= nil and cash >= ng.price
	if out.tools then out.count += 1 end
	if out.gear then out.count += 1 end
	local lvl = p:GetAttribute("Level") or 1
	for _, m in ipairs(Config.Machines) do
		if p:GetAttribute("M_" .. m.id) == true then
			local mlv = math.max(1, p:GetAttribute("ML_" .. m.id) or 1)
			if mlv < Config.MachineMaxLevel and cash >= Config.MachineUpgradeCost(m, mlv) then out.machines = true; out.count += 1 end
		elseif lvl >= m.reqLevel and cash >= m.price then
			out.machines = true
			out.count += 1
		end
	end
	if (p:GetAttribute("WorkerCount") or 0) < (p:GetAttribute("MaxWorkers") or 2) then
		for _, w in ipairs(Config.WorkerTypes) do
			if lvl >= (w.reqLevel or 1) and cash >= w.price then out.crew = true; out.count += 1 end
		end
	end
	return out
end

function M.Show(t, keepScroll)
	-- opening the window (not a redraw while it is open) always starts on the first tab
	if t == nil and not (c.modalOpen() and c.modalTitle.Text == "Shop") then tab = "tools" end
	if type(t) == "string" then tab = t end
	if not THEME[tab] then tab = "tools" end
	local scroll = keepScroll and c.modalOpen() and c.content.CanvasPosition or nil
	keepNext = scroll ~= nil
	local th = THEME[tab]
	c.openModal("Shop", "Shop", "", th.c1, th.c2)
	if scroll then task.defer(function() c.content.CanvasPosition = scroll end) end
	c.modalSub.Text = fmt(money())
	local avail = M.Available()
	local tabs = {}
	for i, t2 in ipairs(TABS) do
		tabs[i] = table.clone(t2)
		tabs[i].badge = avail[t2.id] == true -- a red "!" dot where something can be bought
	end
	UI.tabs(c.content, tabs, tab, function(id)
		c.click()
		c.content.CanvasPosition = Vector2.zero -- a new tab starts at the top
		M.Show(id)
	end)
	if tab == "tools" then tools() elseif tab == "gear" then gear() elseif tab == "machines" then machines() else crew() end
end

function M.Init(ctx)
	c = ctx
	UI, T, Config = c.UI, c.T, c.Config
	c.shopAvailable = M.Available
	-- the cash in the header follows your money while the shop is open
	-- buying the Thunderclap or picking another hammer redraws the TOOLS tab
	local function redrawTools()
		if c.modalOpen() and c.modalTitle.Text == "Shop" and tab == "tools" then M.Show(nil, true) end
	end
	if Config.StormHammer then c.player:GetAttributeChangedSignal("Pass_" .. Config.StormHammer.pass):Connect(redrawTools) end
	c.player:GetAttributeChangedSignal("EquipTool"):Connect(redrawTools)
	c.player:GetAttributeChangedSignal("Money"):Connect(function()
		if c.modalOpen() and c.modalTitle.Text == "Shop" and tab ~= "crew" then c.modalSub.Text = fmt(money()) end
	end)
end

return M
