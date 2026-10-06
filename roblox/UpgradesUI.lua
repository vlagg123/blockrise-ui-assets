-- BlockRise Empire - Upgrades window (the six player upgrades) and the Inventory window (your materials and blueprints)
local RS = game:GetService("ReplicatedStorage")
local Company = require(RS.Shared:WaitForChild("Company"))
local K = require(RS.Shared:WaitForChild("MenuKit"))
local HammersUI -- (Client.HammersUI: your hammers, the trade-up contract and the Index live in the Inventory)

local M = {}
local c, UI, T, new, Config
local mode = "upgrades"    -- which window is drawing: "upgrades" or "inventory"
local invTab = "hammers" -- the Inventory tab
local G1, G2 = Color3.fromRGB(130, 240, 120), Color3.fromRGB(30, 160, 70)
local INK = Color3.fromRGB(20, 17, 32)
local TINT = { up_power = Color3.fromRGB(255, 170, 60), up_strength = Color3.fromRGB(255, 120, 80), up_cash = Color3.fromRGB(80, 200, 110),
	up_crew = Color3.fromRGB(255, 200, 60), up_rent = Color3.fromRGB(160, 110, 255), up_luck = Color3.fromRGB(70, 200, 120) }

local function money(n) return Config.FormatMoney(n) end

-- material chips: what the next level needs (red when you don't have enough)
local function matChips(mats, have)
	local out = {}
	for _, m in ipairs(Company.Materials) do
		local n = mats and mats[m.id]
		if n and n > 0 then
			local ok = (have[m.id] or 0) >= n
			table.insert(out, { Config.FormatNum(n), ok and Color3.fromRGB(80, 200, 110) or Color3.fromRGB(235, 80, 80), pic = m.image or m.icon })
		end
	end
	return out
end

-- every material and how many you have (so you see how many levels you can buy)
local function haveChips(have)
	local out = {}
	for _, m in ipairs(Company.Materials) do
		local n = (have or {})[m.id] or 0
		table.insert(out, { m.name:match("^(%S+)") .. " " .. Config.FormatNum(n), n > 0 and m.color:Lerp(Color3.new(0, 0, 0), 0.25) or K.LOCK, pic = m.image or m.icon })
	end
	return out
end

local function cols() return (_G.__CE_ListWidth and _G.__CE_ListWidth() or 780) >= 700 and 4 or 3 end

local render
local lastData -- the last CompanyAction "get" answer (see open)
local function act(tok, ...)
	local args = table.pack(...)
	local ok, res, msg = pcall(function() return c.R.CompanyAction:InvokeServer(table.unpack(args, 1, args.n)) end)
	if not ok or not res then c.toast("⚠️ " .. tostring(msg or "Can't do that"), T.red) end
	for _ = 1, 3 do
		if not c.live(tok) then break end
		local ok2, okr, data = pcall(function() return c.R.CompanyAction:InvokeServer("get") end)
		if ok2 and okr and type(data) == "table" then
			lastData = data
			if c.live(tok) then
				local scroll = c.content.CanvasPosition
				render(tok, data)
				task.defer(function() if c.live(tok) then c.content.CanvasPosition = scroll end end)
			end
			break
		end
		task.wait(0.2)
	end
end

render = function(tok, data)
	c.modalSub.Text = money(data.money or 0)
	for _, ch in ipairs(c.content:GetChildren()) do if not ch:IsA("UIListLayout") then ch:Destroy() end end
	if mode == "inventory" then
		local nBps = 0
		for _, b in ipairs(Company.Blueprints) do nBps += data.bps[b.id] or 0 end
		HammersUI = HammersUI or require(script.Parent:WaitForChild("HammersUI"))
		local hv = HammersUI.Available()
		UI.tabs(c.content, {
			{ id = "hammers", label = "HAMMERS", icon = "shop", c1 = Color3.fromRGB(110, 200, 255), c2 = Color3.fromRGB(40, 110, 230), badge = hv.hammers == true },
			{ id = "crates", label = "CRATES", icon = "gift", c1 = Color3.fromRGB(255, 205, 70), c2 = Color3.fromRGB(240, 130, 20), badge = hv.crates },
			{ id = "tradeup", label = "TRADE-UP", icon = "upgrades", c1 = Color3.fromRGB(205, 150, 255), c2 = Color3.fromRGB(125, 65, 230) },
			{ id = "index", label = "INDEX", icon = "star", c1 = Color3.fromRGB(255, 220, 110), c2 = Color3.fromRGB(220, 140, 30) },
			{ id = "materials", label = "MATERIALS", icon = "site", c1 = Color3.fromRGB(255, 214, 70), c2 = Color3.fromRGB(240, 135, 20) },
			{ id = "blueprints", label = "BLUEPRINTS", icon = "codes", c1 = Color3.fromRGB(120, 200, 255), c2 = Color3.fromRGB(40, 110, 230), badge = nBps },
		}, invTab, function(id)
			c.click()
			invTab = id
			render(tok, data)
			c.content.CanvasPosition = Vector2.zero
		end)
	end
	if mode == "upgrades" then
		K.section(c.content, 0, "UPGRADES", Color3.fromRGB(160, 250, 150), "a Rebirth resets them")
		K.haveRow(c.content, 1, haveChips(data.mats))
		local order = 1
		for _, dp in ipairs(Company.Departments) do
			local d
			for _, x in ipairs(data.depts) do if x.id == dp.id then d = x end end
			if d then
				order += 1
				local key = dp.iconKey or "upgrades"
				local now = math.floor(dp.per * d.level * 100 + 0.5)
				local o = { name = dp.name, icon = key, color = TINT[key] or G2, height = 118, buttonW = 170,
					bar = { d.level / Company.DeptMax, G1, "LV " .. d.level .. " / " .. Company.DeptMax } }
				if d.level >= Company.DeptMax then
					o.chips = { { "+" .. now .. "%", G2 } }
					o.status = { "MAX", Color3.fromRGB(255, 176, 40) }
					o.spin = true
				else
					local nextPct = math.floor(dp.per * (d.level + 1) * 100 + 0.5)
					o.chips = { { "+" .. now .. "% → +" .. nextPct .. "%", G2 } }
					for _, mc in ipairs(matChips(d.mats, data.mats)) do table.insert(o.chips, mc) end
					-- green only when you have the cash AND every material it needs
					local can = (data.money or 0) >= d.cash
					for id, q in pairs(d.mats or {}) do
						if ((data.mats or {})[id] or 0) < q then can = false end
					end
					o.button = { money(d.cash), can and K.GREEN or K.LOCK, function()
						c.click()
						act(tok, "upgrade", dp.id)
					end, icon = "cash", shine = can }
				end
				K.row(c.content, order, o)
			end
		end
	elseif invTab == "hammers" or invTab == "crates" or invTab == "tradeup" or invTab == "index" then
		HammersUI = HammersUI or require(script.Parent:WaitForChild("HammersUI"))
		if invTab == "hammers" then HammersUI.Hammers(tok) elseif invTab == "crates" then HammersUI.MyCrates(tok)
		elseif invTab == "tradeup" then HammersUI.TradeUp(tok) else HammersUI.Index(tok) end
	elseif invTab == "materials" then
		K.section(c.content, 1, "MATERIALS", Color3.fromRGB(255, 220, 110), "they drop while you build · the Job Board shows what each building drops")
		local grid = K.grid(c.content, 2, cols(), 268)
		for i, m in ipairs(Company.Materials) do
			local n = data.mats[m.id] or 0
			-- the art box takes the material's rarity colour: steel common ... diamond glass legendary
			local o = { order = i, name = m.name, icon = m.image or m.icon, iconScale = m.image and 1.08 or nil,
				color = K.RAR[({ "common", "uncommon", "rare", "epic", "legend" })[i] or "legend"], tag = { "x" .. Config.FormatNum(n), K.DARK },
				stats = { { money(m.sell) .. " EACH", K.GREEN } }, dim = n == 0 }
			if n > 0 then
				o.buttons = {
					{ "SELL 1", Color3.fromRGB(110, 120, 200), function() c.click(); act(tok, "sell", m.id, 1) end },
					{ "ALL", T.red, function() c.click(); act(tok, "sell", m.id, n) end },
				}
			else
				o.status = { "NONE YET", K.LOCK }
			end
			K.tile(grid, o)
		end
	else
		K.section(c.content, 1, "BLUEPRINTS", Color3.fromRGB(150, 210, 255), "use one on the Job Board")
		local grid = K.grid(c.content, 2, cols(), 268)
		for i, b in ipairs(Company.Blueprints) do
			local n = data.bps[b.id] or 0
			K.tile(grid, { order = i, name = (b.name:gsub(" Blueprint", "")), icon = b.image or b.icon, iconScale = b.image and 1.08 or nil, color = b.color, tag = { "x" .. n, K.DARK },
				stats = { { "x" .. tostring(b.pay) .. " PAY", Color3.fromRGB(255, 170, 30) } }, dim = n == 0,
				status = n > 0 and { "AT JOB BOARD", Color3.fromRGB(80, 170, 255) } or { "NONE YET", K.LOCK } })
		end
	end
end

-- the last answer of the server: a redraw (a level-up, a crate, a trade-up...) draws with it at once, in the same frame,
-- so the window never empties into a loading spinner and back; the fresh answer then redraws only what it changes
local function open(name, c1, c2)
	local refresh = c.modalOpen() and c.modalTitle.Text == name
	local tok = c.openModal(name, name, "", c1, c2)
	local hammerTab = mode == "inventory" and (invTab == "hammers" or invTab == "crates" or invTab == "tradeup" or invTab == "index")
	if lastData and (refresh or hammerTab) then
		render(tok, lastData)
		c.modalSub.Text = money(c.player:GetAttribute("Money") or lastData.money or 0)
		task.spawn(function()
			local ok, okr, data = pcall(function() return c.R.CompanyAction:InvokeServer("get") end)
			if not (ok and okr and type(data) == "table") then return end
			lastData = data
			-- the hammer tabs don't use it (only the BLUEPRINTS badge); materials, blueprints and upgrades do
			local tabNow = mode == "inventory" and (invTab == "hammers" or invTab == "crates" or invTab == "tradeup" or invTab == "index")
			if c.live(tok) and not tabNow then
				local scroll = c.content.CanvasPosition
				render(tok, data)
				task.defer(function() if c.live(tok) then c.content.CanvasPosition = scroll end end)
			end
		end)
		return
	end
	local loading = K.loading(c.content)
	local ok, okr, data = pcall(function() return c.R.CompanyAction:InvokeServer("get") end)
	if not c.live(tok) then return end
	loading:Destroy()
	if not ok or not okr or type(data) ~= "table" then c.toast("⚠️ Couldn't load it, try again", T.red) return end
	lastData = data
	c.modalSub.Text = money(data.money or 0)
	render(tok, data)
end

function M.Show()
	mode = "upgrades"
	open("Upgrades", G1, G2)
end

-- Inventory: opens on HAMMERS (or the tab asked for); a redraw keeps the tab
local INV_TABS = { hammers = true, crates = true, tradeup = true, index = true, materials = true, blueprints = true }
function M.Inventory(t)
	local reopen = c.modalOpen() and c.modalTitle.Text == "Inventory"
	mode = "inventory"
	if INV_TABS[t] then invTab = t elseif not reopen then invTab = "hammers" end
	open("Inventory", Color3.fromRGB(255, 214, 70), Color3.fromRGB(240, 135, 20))
end

function M.Init(ctx)
	c = ctx
	UI, T, new, Config = c.UI, c.T, c.new, c.Config
	c.redrawInventory = function() M.Inventory(invTab) end
	c.inventoryHammerTab = function() return mode == "inventory" and (invTab == "hammers" or invTab == "crates" or invTab == "tradeup" or invTab == "index") end
end

return M
