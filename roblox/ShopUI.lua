-- BlockRise Empire - Shop window: hammers (collection, crates, index), training gear, heavy machines and the crew, as item tiles
local RS = game:GetService("ReplicatedStorage")
local Icons = require(RS.Shared:WaitForChild("Icons"))
local K = require(RS.Shared:WaitForChild("MenuKit"))
local HammersUI = require(script.Parent:WaitForChild("HammersUI"))

local M = {}
local c, UI, T, Config
local tab = "hammers"

local TABS = {
	{ id = "hammers", label = "CRATES", icon = "gift", c1 = Color3.fromRGB(110, 200, 255), c2 = Color3.fromRGB(40, 110, 230) },
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
		local o = { order = i, name = it.name, icon = it.image or it.icon or (Icons.has((icon .. "_" .. i)) and (icon .. "_" .. i) or icon), color = K.RAR[rk], iconScale = (it.image or it.icon) and 1.08 or nil,
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
		local o = { order = i, name = m.name, icon = m.image or MACHINE_ICON[m.id] or m.icon, iconScale = m.image and 1.06 or nil, color = MACHINE_COL[m.id] or GOLD,
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
	local out = { hammers = false, gear = false, machines = false, crew = false, count = 0 }
	local gt = p:GetAttribute("GearTier") or 1
	local ng = Config.TrainingGear[gt + 1]
	out.hammers = false -- (crates are opened in the Inventory: its button carries the count)
	out.gear = ng ~= nil and cash >= ng.price
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
	if t == nil and not (c.modalOpen() and c.modalTitle.Text == "Shop") then tab = "hammers" end
	if type(t) == "string" then tab = (t == "tools" or t == "index") and "hammers" or t end
	if not THEME[tab] then tab = "hammers" end
	local scroll = keepScroll and c.modalOpen() and c.content.CanvasPosition or nil
	keepNext = scroll ~= nil
	local th = THEME[tab]
	local tok = c.openModal("Shop", "Shop", "", th.c1, th.c2)
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
	if tab == "hammers" then HammersUI.Crates(tok)
	elseif tab == "gear" then gear() elseif tab == "machines" then machines() else crew() end
end

function M.Init(ctx)
	c = ctx
	UI, T, Config = c.UI, c.T, c.Config
	c.shopAvailable = M.Available
	HammersUI.Init(ctx)
	-- the hammer tabs redraw when your hammers or crates change (a crate bought with Robux, a trade, the Thunderclap pass);
	-- several changes at once make one redraw, and never while a crate is being opened
	local queued = false
	local function redrawHammers()
		if queued then return end
		queued = true
		task.delay(0.15, function()
			queued = false
			if HammersUI.Showing() and not c.player.PlayerGui:FindFirstChild("CrateShake") and not (_G.__CE_RevealOpen and _G.__CE_RevealOpen()) then
				HammersUI.Redraw()
			end
		end)
	end
	c.shopHammerTab = function() return tab == "hammers" end
	c.redrawShop = function()
		if c.modalOpen() and c.modalTitle.Text == "Shop" then M.Show(nil, true) end
	end
	if Config.StormHammer then c.player:GetAttributeChangedSignal("Pass_" .. Config.StormHammer.pass):Connect(redrawHammers) end
	for _, a in ipairs({ "EquipId", "EquipLevel", "CrateTotal", "HammerCount" }) do c.player:GetAttributeChangedSignal(a):Connect(redrawHammers) end
	c.player:GetAttributeChangedSignal("Money"):Connect(function()
		if c.modalOpen() and c.modalTitle.Text == "Shop" and tab ~= "crew" then c.modalSub.Text = fmt(money()) end
	end)
end

return M
