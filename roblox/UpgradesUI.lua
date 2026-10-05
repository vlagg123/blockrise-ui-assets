-- BlockRise Empire - Upgrades window: the six permanent player upgrades, your materials and blueprints
local RS = game:GetService("ReplicatedStorage")
local Company = require(RS.Shared:WaitForChild("Company"))
local Icons = require(RS.Shared:WaitForChild("Icons"))

local M = {}
local c, UI, T, new, Config
local tab = "upgrades"
local G1, G2 = Color3.fromRGB(130, 240, 120), Color3.fromRGB(30, 160, 70)
local INK = Color3.fromRGB(20, 17, 32)
local TINT = { up_power = Color3.fromRGB(255, 170, 60), up_strength = Color3.fromRGB(255, 120, 80), up_cash = Color3.fromRGB(80, 200, 110),
	up_crew = Color3.fromRGB(255, 200, 60), up_rent = Color3.fromRGB(160, 110, 255), up_luck = Color3.fromRGB(70, 200, 120) }

local function money(n) return Config.FormatMoney(n) end

local function matsText(mats, have)
	local parts = {}
	for _, m in ipairs(Company.Materials) do
		local n = mats and mats[m.id]
		if n and n > 0 then
			local ok = (have[m.id] or 0) >= n
			table.insert(parts, string.format("<font color='%s'>%s %s</font>", ok and "#c8f0d0" or "#ff8a80", Config.FormatNum(n), m.icon))
		end
	end
	return table.concat(parts, "  ")
end

local function iconTile(parent, key, color, size)
	local f = new("Frame", { Position = UDim2.fromOffset(12, 12), Size = UDim2.fromOffset(size, size), BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 22, Parent = parent })
	UI.corner(16).Parent = f
	UI.grad(color:Lerp(Color3.new(1, 1, 1), 0.25), color:Lerp(INK, 0.35)).Parent = f
	new("UIStroke", { Thickness = 2.5, Color = INK, Parent = f })
	Icons.make(key, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(1.0, 1.0), ZIndex = 23, Parent = f })
	return f
end

local function header(order, text, col)
	local h = new("Frame", { Size = UDim2.new(1, -8, 0, 34), BackgroundTransparency = 1, LayoutOrder = order, ZIndex = 21, Parent = c.content })
	local l = UI.label({ Size = UDim2.fromScale(1, 1), Text = text, Font = Enum.Font.LuckiestGuy, TextSize = 22, TextColor3 = col or T.text, ZIndex = 22, Parent = h })
	new("UIStroke", { Thickness = 2, Color = INK, Parent = l })
end

local function actionButton(parent, text, c1, c2, pos, size, fn)
	local b = UI.button(text, c1, c2, { AnchorPoint = Vector2.new(1, 0), Position = pos, Size = size, TextSize = 18, ZIndex = 23, Parent = parent })
	local busy = false
	b.Activated:Connect(function()
		if busy then return end
		busy = true
		c.click()
		task.spawn(function() fn(); busy = false end)
	end)
	return b
end

local render
local function act(tok, ...)
	local args = table.pack(...)
	local ok, res, msg = pcall(function() return c.R.CompanyAction:InvokeServer(table.unpack(args, 1, args.n)) end)
	if not ok or not res then c.toast("⚠️ " .. tostring(msg or "Can't do that"), T.red) end
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
end

render = function(tok, data)
	c.modalSub.Text = money(data.money or 0)
	for _, ch in ipairs(c.content:GetChildren()) do if not ch:IsA("UIListLayout") then ch:Destroy() end end
	local nMats, nBps = 0, 0
	for _, m in ipairs(Company.Materials) do if (data.mats[m.id] or 0) > 0 then nMats += 1 end end
	for _, b in ipairs(Company.Blueprints) do nBps += data.bps[b.id] or 0 end
	UI.tabs(c.content, {
		{ id = "upgrades", label = "UPGRADES", c1 = G1, c2 = G2 },
		{ id = "materials", label = "MATERIALS", c1 = Color3.fromRGB(255, 214, 70), c2 = Color3.fromRGB(240, 135, 20) },
		{ id = "blueprints", label = "BLUEPRINTS", c1 = Color3.fromRGB(120, 200, 255), c2 = Color3.fromRGB(40, 110, 230), badge = nBps },
	}, tab, function(id)
		c.click()
		tab = id
		local scroll = Vector2.zero
		render(tok, data)
		c.content.CanvasPosition = scroll
	end, { LayoutOrder = -100 })
	local order = 1
	if tab == "upgrades" then
	local info = c.card(1, 46)
	info.BackgroundTransparency = 0.5
	UI.label({ Position = UDim2.fromOffset(14, 0), Size = UDim2.new(1, -28, 1, 0), TextSize = 13, TextWrapped = true, TextColor3 = T.muted, ZIndex = 22, Parent = info,
		Text = "💡 Upgrades make you stronger for the whole run (a Rebirth resets them). Higher levels also need materials — they drop while you build." })
	for _, dp in ipairs(Company.Departments) do
		local d
		for _, x in ipairs(data.depts) do if x.id == dp.id then d = x end end
		if d then
			order += 1
			local f = c.card(order, 112)
			local key = dp.iconKey or "upgrades"
			iconTile(f, key, TINT[key] or G2, 88)
			UI.label({ Position = UDim2.fromOffset(114, 8), Size = UDim2.new(1, -290, 0, 30), Text = dp.name, Font = Enum.Font.LuckiestGuy, TextSize = 24, ZIndex = 22, Parent = f })
			UI.label({ Position = UDim2.fromOffset(114, 38), Size = UDim2.new(1, -290, 0, 18), Text = dp.desc, TextSize = 13, TextColor3 = T.muted, TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 22, Parent = f })
			-- level bar
			local bar, fill = UI.bar({ Position = UDim2.fromOffset(114, 62), Size = UDim2.new(1, -290, 0, 14), Radius = 7, ZIndex = 22 }, G1, G2)
			bar.Parent = f
			fill.Size = UDim2.fromScale(math.max(0.02, d.level / Company.DeptMax), 1)
			UI.label({ Position = UDim2.fromOffset(114, 80), Size = UDim2.new(1, -290, 0, 22), ZIndex = 22, Parent = f, Font = T.title, TextSize = 15,
				Text = "Lv " .. d.level .. "/" .. Company.DeptMax .. "   <font color='#8ff09a'>+" .. math.floor(dp.per * d.level * 100 + 0.5) .. "%</font>"
					.. (d.level < Company.DeptMax and ("  →  <font color='#c9ffcf'>+" .. math.floor(dp.per * (d.level + 1) * 100 + 0.5) .. "%</font>") or "") })
			if d.level >= Company.DeptMax then
				c.pill(f, "⭐ MAX", T.accent, 150)
			else
				UI.label({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -14, 0, 12), Size = UDim2.fromOffset(160, 22), Text = money(d.cash), Font = T.title, TextSize = 18,
					TextColor3 = (data.money or 0) >= d.cash and Color3.fromRGB(150, 255, 140) or Color3.fromRGB(255, 140, 130), TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 22, Parent = f })
				UI.label({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -14, 0, 34), Size = UDim2.fromOffset(160, 18), Text = matsText(d.mats, data.mats), Font = T.title, TextSize = 14,
					TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 22, Parent = f })
				actionButton(f, "UPGRADE", G1, G2, UDim2.new(1, -14, 0, 58), UDim2.fromOffset(150, 44), function() act(tok, "upgrade", dp.id) end)
			end
		end
	end
	end
	-- materials
	if tab == "materials" then
	order += 1
	header(order, "MATERIALS  <font color='#9ea5b8' size='15' face='FredokaOne'>drop while you build — bigger contracts drop rarer ones</font>", Color3.fromRGB(255, 205, 70))
	for _, m in ipairs(Company.Materials) do
		order += 1
		local n = data.mats[m.id] or 0
		local f = c.card(order, 64)
		if n == 0 then f.BackgroundTransparency = 0.4 end
		UI.label({ Position = UDim2.fromOffset(14, 0), Size = UDim2.fromOffset(46, 64), Text = m.icon, TextSize = 32, ZIndex = 22, Parent = f })
		UI.label({ Position = UDim2.fromOffset(66, 8), Size = UDim2.fromOffset(300, 26), Text = m.name .. "  <font color='#9ea5b8'>x" .. Config.FormatNum(n) .. "</font>", Font = T.title, TextSize = 20, ZIndex = 22, Parent = f })
		UI.label({ Position = UDim2.fromOffset(66, 34), Size = UDim2.fromOffset(300, 20), Text = "Sells for " .. money(m.sell) .. " each", Font = T.bold, TextSize = 13, TextColor3 = T.muted, ZIndex = 22, Parent = f })
		if n > 0 then
			actionButton(f, "Sell 1", T.bg3, T.bg2, UDim2.new(1, -136, 0, 12), UDim2.fromOffset(100, 40), function() act(tok, "sell", m.id, 1) end)
			actionButton(f, "Sell all", T.red, Color3.fromRGB(170, 40, 40), UDim2.new(1, -14, 0, 12), UDim2.fromOffset(112, 40), function() act(tok, "sell", m.id, n) end)
		end
	end
	end
	if tab == "blueprints" then
	order += 1
	header(order, "BLUEPRINTS  <font color='#9ea5b8' size='15' face='FredokaOne'>use one on the Job Board for a premium contract</font>", Color3.fromRGB(255, 205, 60))
	for _, b in ipairs(Company.Blueprints) do
		order += 1
		local n = data.bps[b.id] or 0
		local f = c.card(order, 60)
		if n == 0 then f.BackgroundTransparency = 0.4 end
		UI.label({ Position = UDim2.fromOffset(14, 0), Size = UDim2.fromOffset(46, 60), Text = b.icon, TextSize = 30, TextColor3 = b.color, ZIndex = 22, Parent = f })
		UI.label({ Position = UDim2.fromOffset(66, 6), Size = UDim2.fromOffset(330, 26), Text = "<font color='#" .. b.color:ToHex() .. "'>" .. b.name .. "</font>  x" .. n, Font = T.title, TextSize = 20, ZIndex = 22, Parent = f })
		UI.label({ Position = UDim2.fromOffset(66, 32), Size = UDim2.fromOffset(420, 20), Text = b.desc .. " (a bit more work)", Font = T.bold, TextSize = 13, TextColor3 = T.muted, ZIndex = 22, Parent = f })
	end
	end
end

function M.Show(t)
	if type(t) == "string" then tab = t end
	local tok = c.openModal("Upgrades", "Upgrades", "", G1, G2)
	local loading = c.loadingCard()
	local ok, okr, data = pcall(function() return c.R.CompanyAction:InvokeServer("get") end)
	if not c.live(tok) then return end
	loading:Destroy()
	if not ok or not okr or type(data) ~= "table" then c.toast("⚠️ Couldn't load your upgrades, try again", T.red) return end
	c.modalSub.Text = money(data.money or 0)
	render(tok, data)
end

function M.Init(ctx)
	c = ctx
	UI, T, new, Config = c.UI, c.T, c.new, c.Config
end

return M
