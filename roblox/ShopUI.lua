-- BlockRise Empire - Shop window: hammer crates, training gear, heavy machines and the crew, as item tiles.
-- Every tab is a shop on the map (Hammers Shop, Training Shop, Machines Depot, Hiring Office); in the tutorial the
-- window opens at the shop you walked into, and only that shop's one tutorial buy can be made.
local RS = game:GetService("ReplicatedStorage")
local Icons = require(RS.Shared:WaitForChild("Icons"))
local K = require(RS.Shared:WaitForChild("MenuKit"))
local HammersUI = require(script.Parent:WaitForChild("HammersUI"))

local M = {}
local c, UI, T, Config
local tab = "hammers"
local atShop -- the tab of the shop on the map the window was opened at (in the tutorial only that tab works)
local tutLock = false -- this draw is in the tutorial: one buy per shop, the rest waits for after the tutorial
local function inTutorial() return (c.player:GetAttribute("RoadStep") or 1) <= (Config.TutorialSteps or 7) end
local AFTER = "AFTER TUTORIAL"

local TABS = {
	{ id = "hammers", label = "HAMMERS", icon = "gift", c1 = Color3.fromRGB(110, 200, 255), c2 = Color3.fromRGB(40, 110, 230) },
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

-- Instant purchases: what you buy shows at once (your attributes as they will be: over), the server gets it right after
-- (one at a time, in tap order) and the window follows the server's attributes when they differ from the guess
local over = {}
local pending = 0
local function attr(k)
	local v = over[k]
	if v ~= nil then return v end
	return c.player:GetAttribute(k)
end
local function money() return math.max(0, (c.player:GetAttribute("Money") or 0) - K.spent.cash) end
-- what the crew and the machines build with: your hammer and bonuses, without your own Strength (like on the server)
local function crewPower()
	local sm = Config.StrengthMult and Config.StrengthMult(c.player:GetAttribute("Strength") or 0) or 1
	return c.buildPower() / math.max(sm, 0.0001)
end
local function fmt(n) return Config.FormatMoney(n) end
local function cols() return (_G.__CE_ListWidth and _G.__CE_ListWidth() or 780) >= 700 and 4 or 3 end

local jobs, working = {}, false
local function later(fn)
	table.insert(jobs, fn)
	if working then return end
	working = true
	task.spawn(function()
		while #jobs > 0 do
			local ok, e = pcall(table.remove(jobs, 1))
			if not ok then warn("[shop] " .. tostring(e)) end
		end
		working = false
	end)
end
-- what the window shows from your attributes (the cash aside: it ticks), to redraw only when it changed
local shownSig = ""
local function sigNow()
	local t = { tostring(attr("GearTier")), tostring(attr("WorkerCount")), tostring(attr("MaxWorkers")), tostring(attr("Level")) }
	for _, m in ipairs(Config.Machines) do table.insert(t, tostring(attr("M_" .. m.id)) .. ":" .. tostring(attr("ML_" .. m.id))) end
	for _, w in ipairs(Config.WorkerTypes) do table.insert(t, tostring(attr("W_" .. w.id))) end
	return table.concat(t, "|")
end
local function followServer(keep)
	if pending > 0 or not (c.modalOpen() and c.modalTitle.Text == "Shop") then return end
	if sigNow() ~= shownSig then M.Show(nil, keep ~= false) end
end
-- buy: change(over) = the attributes after the purchase, cost = its cash; drawn at once, then the server
local function buy(remote, arg, keep, change, cost)
	c.click()
	if change then
		change(over)
		K.spent.cash += cost or 0
		pending += 1
		M.Show(nil, keep)
	end
	later(function()
		local ok, res, msg = pcall(function() return c.R[remote]:InvokeServer(arg) end)
		if change then
			K.spent.cash -= cost or 0
			pending -= 1
			if pending == 0 then table.clear(over) end
		end
		if not (ok and res) then c.toast("⚠️ " .. tostring(msg or "Can't buy that"), T.red) end
		if change then followServer(keep) elseif ok and res then M.Show(nil, keep) end
	end)
end

local EQUIP_BLUE = Color3.fromRGB(70, 160, 255)
-- compact item cards (like the shops of the top games): smaller pictures, the price right under the name
local ART_H, CELL_H = 104, 244

-- a tier list (tools / gear): every tier, the locked ones show their price; the window opens on your row
-- equip = { which, onEquip }: the hammers you own can be picked (tools only)
local function tierTiles(list, current, remote, icon, stat, keep, equip)
	local n = cols()
	local grid = K.grid(c.content, 2, n, CELL_H)
	local cash = money()
	local mine
	for i, it in ipairs(list) do
		local rk, rl = K.rarityOf(i, #list)
		local o = { order = i, name = it.name, icon = it.image or it.icon or (Icons.has((icon .. "_" .. i)) and (icon .. "_" .. i) or icon), color = K.RAR[rk], iconScale = (it.image or it.icon) and 1.08 or nil,
			badge = { rl, K.RAR[rk] }, stats = { stat(it) }, artH = ART_H }
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
		elseif i == current + 1 and tutLock and i ~= 2 then
			o.dim = true
			o.status = { AFTER, K.LOCK }
		elseif i == current + 1 then
			local can = cash >= it.price
			o.tag = { "NEXT", T.red }
			o.button = { fmt(it.price), can and K.GREEN or K.LOCK, function()
				if not can then c.click(); c.toast("💸 Not enough cash yet", T.red, 2) return end
				buy(remote, i, true, function(o) o[remote == "BuyGear" and "GearTier" or "ToolTier"] = i end, it.price)
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
	K.category(c.content, 1, { title = "TRAINING GEAR", line = "More Strength from every hit: each one doubles the last", icon = "strength",
		c1 = Color3.fromRGB(255, 150, 70), c2 = Color3.fromRGB(226, 70, 40), first = true })
	tierTiles(Config.TrainingGear, attr("GearTier") or 1, "BuyGear", "strength", function(g)
		return { "x" .. Config.FormatNum(g.mult) .. " STRENGTH", Color3.fromRGB(255, 120, 80) }
	end, keepNext)
end

local function machines()
	K.category(c.content, 1, { title = "HEAVY MACHINES", line = "They build your job on their own  ·  upgrade them for more work", icon = Config.Machines[1].image or "mega",
		c1 = Color3.fromRGB(255, 200, 50), c2 = Color3.fromRGB(240, 120, 20), first = true })
	local grid = K.grid(c.content, 2, cols(), CELL_H)
	local lvl = attr("Level") or 1
	local cash = money()
	for i, m in ipairs(Config.Machines) do
		local owned = attr("M_" .. m.id) == true
		local mlv = owned and math.max(1, attr("ML_" .. m.id) or 1) or 1
		local rate = m.rate * Config.MachineMult(mlv) * crewPower()
		local o = { order = i, name = m.name, icon = m.image or MACHINE_ICON[m.id] or m.icon, iconScale = m.image and 1.06 or nil, color = MACHINE_COL[m.id] or GOLD,
			stats = { { Config.FormatNum(math.floor(rate)) .. " WORK/S", GOLD } }, artH = ART_H }
		if owned then
			o.tag = { "MK " .. mlv, K.DARK }
			if mlv >= Config.MachineMaxLevel then
				o.status = { "MAX", GOLD }
				o.spin = true
			elseif tutLock then
				o.status = { AFTER, K.LOCK }
			else
				local cost = Config.MachineUpgradeCost(m, mlv)
				local can = cash >= cost
				o.button = { "⬆ " .. fmt(cost), can and Color3.fromRGB(255, 176, 40) or K.LOCK, function()
					if not can then c.click(); c.toast("💸 Not enough cash yet", T.red, 2) return end
					buy("BuyMachine", m.id, true, function(o) o["ML_" .. m.id] = mlv + 1 end, cost)
				end, shine = can }
			end
		elseif lvl < m.reqLevel then
			o.dim = true
			o.status = { "🔒 LEVEL " .. m.reqLevel, K.LOCK }
		elseif tutLock and m.id ~= "excavator" then
			o.dim = true
			o.status = { AFTER, K.LOCK }
		else
			local can = cash >= m.price
			o.button = { fmt(m.price), can and K.GREEN or K.LOCK, function()
				if not can then c.click(); c.toast("💸 Not enough cash yet", T.red, 2) return end
				buy("BuyMachine", m.id, true, function(o) o["M_" .. m.id] = true end, m.price)
			end, icon = "cash", shine = can }
		end
		K.tile(grid, o)
	end
end

local function crew()
	local count, max = attr("WorkerCount") or 0, attr("MaxWorkers") or 2
	K.category(c.content, 1, { title = "YOUR CREW  " .. count .. " / " .. max, line = "Workers build your job on their own  ·  firing one gives 50% back", icon = "crew",
		c1 = Color3.fromRGB(90, 210, 110), c2 = Color3.fromRGB(30, 140, 90), first = true })
	c.modalSub.Text = "👷 " .. count .. " / " .. max
	local grid = K.grid(c.content, 2, cols(), CELL_H)
	local lvl = attr("Level") or 1
	local cash = money()
	for i, w in ipairs(Config.WorkerTypes) do
		local have = attr("W_" .. w.id) or 0
		local wps = w.rate * crewPower()
		local stat = w.boost and { "CREW +" .. math.floor(w.boost * 100) .. "%", T.purple }
			or { (wps < 10 and string.format("%.1f", wps) or Config.FormatNum(math.floor(wps))) .. " WORK/S", GOLD }
		local o = { order = i, name = w.name, icon = WORKER_ICON[w.id] or "crew", color = WORKER_COL[w.id] or K.GREEN, stats = { stat }, artH = ART_H }
		if have > 0 then
			o.badge = { "x" .. have, K.DARK }
		end
		if have > 0 and not tutLock then
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
		elseif tutLock and (w.id ~= "laborer" or count >= 1) then
			o.dim = true
			o.status = { AFTER, K.LOCK }
		else
			local can = cash >= w.price
			o.button = { "HIRE " .. fmt(w.price), can and K.GREEN or K.LOCK, function()
				if not can then c.click(); c.toast("💸 Not enough cash yet", T.red, 2) return end
				buy("Hire", w.id, true, function(o) o["W_" .. w.id] = have + 1; o.WorkerCount = count + 1 end, w.price)
			end, shine = can }
		end
		K.tile(grid, o)
	end
end

-- which tabs have something you can buy right now (the red dots on the tabs and the "!" on the SHOP button)
function M.Available()
	local p = c.player
	local cash = money()
	local out = { hammers = false, gear = false, machines = false, crew = false, count = 0 }
	local gt = attr("GearTier") or 1
	local ng = Config.TrainingGear[gt + 1]
	out.hammers = false -- (crates are opened in the Inventory: its button carries the count)
	out.gear = ng ~= nil and cash >= ng.price
	if out.gear then out.count += 1 end
	local lvl = attr("Level") or 1
	for _, m in ipairs(Config.Machines) do
		if attr("M_" .. m.id) == true then
			local mlv = math.max(1, attr("ML_" .. m.id) or 1)
			if mlv < Config.MachineMaxLevel and cash >= Config.MachineUpgradeCost(m, mlv) then out.machines = true; out.count += 1 end
		elseif lvl >= m.reqLevel and cash >= m.price then
			out.machines = true
			out.count += 1
		end
	end
	if (attr("WorkerCount") or 0) < (attr("MaxWorkers") or 2) then
		for _, w in ipairs(Config.WorkerTypes) do
			if lvl >= (w.reqLevel or 1) and cash >= w.price then out.crew = true; out.count += 1 end
		end
	end
	return out
end

-- at = the shop on the map the window opens at ("hammers", "gear", "machines", "crew"); a redraw keeps it
function M.Show(t, keepScroll, at)
	-- opening the window (not a redraw while it is open) always starts on the first tab
	local reopen = c.modalOpen() and c.modalTitle.Text == "Shop"
	if t == nil and not reopen then tab = "hammers" end
	if type(t) == "string" then tab = (t == "tools" or t == "index") and "hammers" or t end
	if not THEME[tab] then tab = "hammers" end
	if at then atShop = at elseif not reopen then atShop = nil end
	tutLock = inTutorial()
	local only = tutLock and THEME[atShop or ""] and atShop or nil -- the tutorial: this shop's tab only
	if only then tab = only end
	local scroll = keepScroll and c.modalOpen() and c.content.CanvasPosition or nil
	keepNext = scroll ~= nil
	local th = THEME[tab]
	local tok = c.openModal("Shop", "Shop", "", th.c1, th.c2)
	if scroll then task.defer(function() c.content.CanvasPosition = scroll end) end
	c.modalSub.Text = fmt(money())
	local avail = M.Available()
	local tabs = {}
	-- the HAMMERS tab shows a golden hammer (the Golden Hammer drawn without sparkles: icons/plain/hammer_gold.png)
	local hammerPic = "rbxassetid://71762305316190"
	for i, t2 in ipairs(TABS) do
		tabs[i] = table.clone(t2)
		if t2.id == "hammers" and hammerPic then tabs[i].icon = hammerPic end
		tabs[i].badge = avail[t2.id] == true and not tutLock -- a red "!" dot where something can be bought (none in the tutorial)
	end
	UI.tabs(c.content, tabs, tab, function(id)
		c.click()
		if only and id ~= only then
			c.toast("🔒 In the tutorial every shop sells its own things: follow the arrow!", T.muted, 2.5)
			return
		end
		c.content.CanvasPosition = Vector2.zero -- a new tab starts at the top
		M.Show(id)
	end)
	if tab == "hammers" then HammersUI.Crates(tok)
	elseif tab == "gear" then gear() elseif tab == "machines" then machines() else crew() end
	shownSig = sigNow()
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
	local follow = false
	c.player.AttributeChanged:Connect(function(name)
		if follow or not (name == "GearTier" or name == "WorkerCount" or name == "MaxWorkers" or name == "Level" or name:match("^M_") or name:match("^ML_") or name:match("^W_")) then return end
		follow = true
		task.delay(0.05, function() follow = false; if tab ~= "hammers" then followServer() end end)
	end)
	c.player:GetAttributeChangedSignal("Money"):Connect(function()
		if c.modalOpen() and c.modalTitle.Text == "Shop" and tab ~= "crew" then c.modalSub.Text = fmt(money()) end
	end)
end

return M
