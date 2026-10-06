-- BlockRise Empire - Company window: found your company, then buy properties that pay rent every minute
-- (upgrades and Rebirth have their own windows)
local RS = game:GetService("ReplicatedStorage")
local Company = require(RS.Shared:WaitForChild("Company"))
local K = require(RS.Shared:WaitForChild("MenuKit"))

local M = {}
local c -- context from the main client script
local UI, T, new, Config

local BLUE1, BLUE2 = Color3.fromRGB(120, 190, 255), Color3.fromRGB(40, 100, 220)
local GOLD = Color3.fromRGB(255, 176, 40)
local RED = Color3.fromRGB(235, 80, 80)

local function money(n) return Config.FormatMoney(n) end
local function cols() return (_G.__CE_ListWidth and _G.__CE_ListWidth() or 780) >= 700 and 4 or 3 end

-- material chips (the material's picture and how many), red when you don't have enough
local function matChips(mats, have, times)
	local out = {}
	for _, m in ipairs(Company.Materials) do
		local n = mats and mats[m.id]
		if n and n > 0 then
			local need = n * (times or 1)
			table.insert(out, { Config.FormatNum(need), (have[m.id] or 0) >= need and Color3.fromRGB(80, 200, 110) or RED, pic = m.image or m.icon })
		end
	end
	return out
end

local render
local function act(tok, ...)
	local args = table.pack(...)
	local ok, res, msg = pcall(function() return c.R.CompanyAction:InvokeServer(table.unpack(args, 1, args.n)) end)
	if not ok or not res then c.toast("⚠️ " .. tostring(msg or "Can't do that"), T.red) end
	-- redraw with fresh numbers right away (retry a couple of times if the read is refused)
	for _ = 1, 3 do
		if not c.live(tok) then break end
		local ok2, okr, data = pcall(function() return c.R.CompanyAction:InvokeServer("get") end)
		if ok2 and okr and type(data) == "table" then
			if c.live(tok) then
				local scroll = c.content.CanvasPosition
				render(tok, data)
				task.defer(function() if c.live(tok) then c.content.CanvasPosition = scroll end end)
			end
			break
		end
		task.wait(0.2)
	end
	return ok and res, msg
end

-- buying properties: drawn at once (owned, the next price, the rent, the cash and materials gone), the server right after
local lastData, inst
local function redraw(tok, data)
	if not c.live(tok) then return end
	local scroll = c.content.CanvasPosition
	render(tok, data)
	task.defer(function() if c.live(tok) then c.content.CanvasPosition = scroll end end)
end
local function sig(d)
	local can = {}
	for _, x in ipairs(d.props or {}) do
		local p = Company.PropertyById[x.id]
		local ok = (d.money or 0) >= (x.cost or 0)
		for id, q in pairs(p and p.mats or {}) do if ((d.mats or {})[id] or 0) < q then ok = false end end
		table.insert(can, ok and "1" or "0")
	end
	return K.stateText(d, { "money", "value" }, table.concat(can))
end
-- like the server: as many as you can pay for, up to count; returns the cash it spends
local function buyChange(p, count)
	return function(d)
		local info
		for _, x in ipairs(d.props or {}) do if x.id == p.id then info = x end end
		if not info or not info.unlocked then return false end
		local owned = info.owned
		-- the rent bonuses (passes, perks) as the server counted them
		local base = owned > 0 and Company.Rent(p, owned) or (Company.Rent(p, 1) - Company.Rent(p, 0))
		local mult = base > 0 and ((owned > 0 and info.rent or info.nextRent) / base) or 1
		local bought, spent = 0, 0
		for _ = 1, count do
			local cost = Company.PropertyCost(p, owned + bought)
			if (d.money or 0) - spent < cost then break end
			local okM = true
			for id, q in pairs(p.mats or {}) do if ((d.mats or {})[id] or 0) < q * (bought + 1) then okM = false end end
			if not okM then break end
			spent += cost
			bought += 1
		end
		if bought == 0 then return false end
		for id, q in pairs(p.mats or {}) do d.mats[id] -= q * bought end
		d.money -= spent
		local n, before = owned + bought, info.rent
		info.owned = n
		info.cost = Company.PropertyCost(p, n)
		info.rent = Company.Rent(p, n) * mult
		info.nextRent = (Company.Rent(p, n + 1) - Company.Rent(p, n)) * mult
		d.rent = (d.rent or 0) + (info.rent - before)
		return spent
	end
end

local function clear()
	for _, ch in ipairs(c.content:GetChildren()) do if not ch:IsA("UIListLayout") then ch:Destroy() end end
end

local function renderFound(tok, data)
	c.modalSub.Text = ""
	-- everything fits without scrolling: a short intro, the three requirements in one row, the name field
	K.banner(c.content, 1, { name = "YOUR OWN COMPANY", line = "Properties pay rent every minute, even offline.", icon = "company", color = BLUE2,
		tint = Color3.fromRGB(170, 215, 255), height = 86 })
	local lvl, mon, steel = data.level or 1, data.money or 0, data.mats.steel or 0
	local grid = K.grid(c.content, 2, 3, 92, 10)
	local function need(i, ok, name, icon, color, have)
		K.row(grid, i, { name = name, icon = icon, color = color, height = 92, chips = { ok and { "✔ DONE", K.GREEN } or { have, RED } }, dim = false })
	end
	need(1, lvl >= Company.FoundLevel, "Level " .. Company.FoundLevel, "level", Color3.fromRGB(255, 196, 60), "YOU: " .. lvl)
	need(2, mon >= Company.FoundCost, money(Company.FoundCost), "cash", Color3.fromRGB(90, 200, 110), "YOU: " .. money(mon))
	local st = Company.MaterialById.steel
	need(3, steel >= Company.FoundSteel, Company.FoundSteel .. " Steel", st.image or st.icon, Color3.fromRGB(150, 160, 190), "YOU: " .. steel)
	-- name + found
	local ready = lvl >= Company.FoundLevel and mon >= Company.FoundCost and steel >= Company.FoundSteel
	local row = new("Frame", { Name = "Row", Size = UDim2.new(1, 0, 0, 82), BackgroundTransparency = 1, LayoutOrder = 3, ZIndex = 2, Parent = c.content })
	UI.slice("tile", { Name = "Bg", ImageColor3 = K.TILE, ZIndex = 1, Parent = row })
	local field = UI.slice("tile", { ImageColor3 = Color3.fromRGB(74, 78, 166), Name = "Field", Position = UDim2.fromOffset(14, 14), Size = UDim2.new(1, -244, 0, 54), SliceScale = 0.4,
		ZIndex = 2, Parent = row })
	local box = new("TextBox", { Position = UDim2.fromOffset(16, 0), Size = UDim2.new(1, -32, 1, 0), BackgroundTransparency = 1, Text = "", PlaceholderText = "Company name (3-20 letters)",
		Font = T.body, TextSize = 22, TextColor3 = Color3.new(1, 1, 1), PlaceholderColor3 = Color3.fromRGB(205, 210, 240), TextXAlignment = Enum.TextXAlignment.Left,
		ClearTextOnFocus = false, ZIndex = 3, Parent = field })
	K.button(row, "FOUND IT!", ready and K.GREEN or K.LOCK, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -14, 0.5, 0), Size = UDim2.fromOffset(206, 56),
		TextSize = 24, Shine = ready }, function()
		c.click()
		if not ready then c.toast("📋 You need all three first", T.red, 2) return end
		local ok = act(tok, "found", box.Text)
		if ok then c.sound2D(c.S.Fanfare, 0.5, 1) end
	end)
end

local function renderEstate(tok, data)
	K.section(c.content, 2, "PROPERTIES", Color3.fromRGB(160, 215, 255), "own 10, 25, 50, 100 of one for 2x rent")
	-- every material and how many you have (properties cost materials too)
	local have = {}
	for _, m in ipairs(Company.Materials) do
		local n = (data.mats or {})[m.id] or 0
		table.insert(have, { m.name:match("^(%S+)") .. " " .. Config.FormatNum(n), n > 0 and m.color:Lerp(Color3.new(0, 0, 0), 0.25) or K.LOCK, pic = m.image or m.icon })
	end
	K.haveRow(c.content, 3, have)
	local grid = K.grid(c.content, 4, cols(), 268)
	for i, p in ipairs(Company.Properties) do
		local info
		for _, x in ipairs(data.props) do if x.id == p.id then info = x end end
		if info then
			local o = { order = i, name = (p.name:gsub(" Rentals", "")), icon = K.BUILDING[p.id] or p.icon, color = K.RAR[(K.rarityOf(i, #Company.Properties))] }
			if info.owned > 0 then o.badge = { "x" .. info.owned, K.DARK } end
			if not info.unlocked then
				o.dim = true
				o.stats = { { "BUILD ONE FIRST", K.LOCK } }
				o.status = { "🔒 LOCKED", K.LOCK }
			else
				-- the corner shows what the ones you own pay now; the green chip is what ONE more pays you
				if info.owned > 0 then o.tag = { money(info.rent) .. "/MIN", K.GREEN } end
				o.stats = matChips(p.mats, data.mats)
				table.insert(o.stats, 1, { "+" .. money(info.nextRent) .. "/MIN", Color3.fromRGB(80, 200, 110) })
				while #o.stats > 2 do table.remove(o.stats) end
				-- green only when you have the cash AND every material it needs
				local can = (data.money or 0) >= info.cost
				for id, q in pairs(p.mats or {}) do
					if ((data.mats or {})[id] or 0) < q then can = false end
				end
				o.buttons = {
					{ money(info.cost), can and K.GREEN or K.LOCK, function() c.click(); inst.tap(tok, buyChange(p, 1), nil, "buyProp", p.id, 1) end, shine = can },
					{ "x10", GOLD, function() c.click(); inst.tap(tok, buyChange(p, 10), nil, "buyProp", p.id, 10) end },
				}
			end
			K.tile(grid, o)
		end
	end
end

render = function(tok, data)
	lastData = data
	clear()
	if not data.founded then renderFound(tok, data) return end
	c.modalTitle.Text = data.name
	c.modalSub.Text = money(data.rent) .. "/min"
	renderEstate(tok, data)
end

function M.Show()
	local tok = c.openModal("Company", "Company", "", BLUE1, BLUE2)
	local loading = K.loading(c.content)
	local ok, okr, data = pcall(function() return c.R.CompanyAction:InvokeServer("get") end)
	if not c.live(tok) then return end
	loading:Destroy()
	if not ok or not okr or type(data) ~= "table" then c.toast("⚠️ Couldn't load your company, try again", T.red) return end
	render(tok, data)
end

-- a found material pops out of the building: its picture bounces in, "+N" next to it, and it floats up and fades
local Debris = game:GetService("Debris")
local function lootPop(pos, m, qty)
	if not m.image then c.floatText(pos, "+" .. qty .. " " .. m.icon, m.color, 1.1) return end
	local p = new("Part", { Name = "LootPop", Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false, Transparency = 1, Size = Vector3.one * 0.2,
		CFrame = CFrame.new(pos), Parent = workspace })
	local bb = new("BillboardGui", { Size = UDim2.fromOffset(150, 64), AlwaysOnTop = true, MaxDistance = 150, StudsOffset = Vector3.new(0, 0.5, 0), Parent = p })
	local box = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = bb })
	local pic = new("ImageLabel", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0, 36, 0.5, 0), Size = UDim2.fromOffset(62, 62), BackgroundTransparency = 1,
		Image = m.image, Rotation = -20, Parent = box })
	local l = UI.label({ AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 70, 0.5, 2), Size = UDim2.new(1, -70, 0, 40), Text = "+" .. qty, Font = T.title,
		TextScaled = true, TextColor3 = m.color:Lerp(Color3.new(1, 1, 1), 0.2), TextXAlignment = Enum.TextXAlignment.Left, Parent = box })
	local stroke = UI.textStroke(0.2, 2.5)
	stroke.Parent = l
	local sc = new("UIScale", { Scale = 0.25, Parent = box })
	UI.tween(sc, 0.32, { Scale = 1 }, Enum.EasingStyle.Back)
	UI.tween(pic, 0.45, { Rotation = 0 }, Enum.EasingStyle.Back)
	UI.tween(bb, 1.35, { StudsOffset = Vector3.new(math.random(-8, 8) / 10, 5.5, 0) }, Enum.EasingStyle.Quad)
	task.delay(0.85, function()
		UI.tween(pic, 0.45, { ImageTransparency = 1 })
		UI.tween(l, 0.45, { TextTransparency = 1 })
		if stroke:IsA("UIStroke") then UI.tween(stroke, 0.45, { Transparency = 1 }) end
	end)
	Debris:AddItem(p, 1.5)
end

function M.Init(ctx)
	c = ctx
	UI, T, new, Config = c.UI, c.T, c.new, c.Config
	inst = K.instant({ remote = function() return c.R.CompanyAction end, gap = 0.1, sig = sig,
		state = function() return lastData end, setState = function(d) lastData = d end, draw = redraw,
		cash = function() return (c.player:GetAttribute("Money") or 0) - K.spent.cash end,
		toast = function(msg) c.toast("⚠️ " .. msg, T.red) end })
	c.R.Feedback.OnClientEvent:Connect(function(kind, d)
		if kind == "Loot" then
			local m = Company.MaterialById[d.id]
			if not m then return end
			if d.pos then lootPop(d.pos + Vector3.new(0, 3.5, 0), m, d.qty) end
			if m.order >= 3 then
				c.toast("Rare find: " .. d.qty .. " " .. m.name .. "!", m.color, 3)
				c.sound2D(c.S.Chime, 0.5, 1.3)
			end
		elseif kind == "LootBlueprint" then
			local b = Company.BlueprintById[d.id]
			if b then
				c.banner("BLUEPRINT FOUND!", b.name .. ": " .. b.desc, b.color)
				c.sound2D(c.S.Chime, 0.6, 0.9)
			end
		elseif kind == "CompanyFounded" then
			c.banner("🏢 " .. string.upper(d.name) .. " IS OPEN!", "Buy properties. They pay rent every minute", BLUE1)
			local char = c.player.Character
			if char and char:FindFirstChild("HumanoidRootPart") then c.emit(char.HumanoidRootPart.Position, "confetti", nil, 80) end
		elseif kind == "Rent" then
			c.toast("🏢 Rent  +" .. money(d.amount), Color3.fromRGB(150, 210, 255), 2.2)
		elseif kind == "OfflineRent" then
			local mins = math.floor(d.secs / 60)
			local days, h, mm = mins // 1440, (mins % 1440) // 60, mins % 60
			local away = days > 0 and (days .. "d " .. h .. "h") or ((h > 0 and (h .. "h ") or "") .. mm .. "m")
			c.banner("👋 WELCOME BACK!", "Your properties earned " .. money(d.amount) .. " while you were away (" .. away .. ")", Color3.fromRGB(150, 210, 255))
			c.sound2D(c.S.Coins, 0.6, 1)
		elseif kind == "Franchised" then
			c.banner("♻️ REBIRTH #" .. d.n .. "!", "+" .. d.stars .. " Rebirth Stars · +" .. math.floor(Company.FranchiseCashPer * 100) .. "% cash · +" .. math.floor(Company.FranchiseStrengthPer * 100) .. "% Strength gains forever", Color3.fromRGB(255, 205, 60))
			c.sound2D(c.S.Fanfare, 0.6, 1)
			local char = c.player.Character
			if char and char:FindFirstChild("HumanoidRootPart") then c.emit(char.HumanoidRootPart.Position, "confetti", nil, 120) end
		elseif kind == "PropMilestone" then
			c.banner("⭐ MILESTONE!", d.owned .. " " .. d.name .. ": rent x" .. d.mult, T.accent)
			c.sound2D(c.S.Chime, 0.6, 1.1)
		end
	end)
end

return M
