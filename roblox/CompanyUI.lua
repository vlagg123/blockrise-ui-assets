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

-- material chips ("5 🔩"), red when you don't have enough
local function matChips(mats, have, times)
	local out = {}
	for _, m in ipairs(Company.Materials) do
		local n = mats and mats[m.id]
		if n and n > 0 then
			local need = n * (times or 1)
			table.insert(out, { Config.FormatNum(need) .. " " .. m.icon, (have[m.id] or 0) >= need and Color3.fromRGB(80, 200, 110) or RED })
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

local function clear()
	for _, ch in ipairs(c.content:GetChildren()) do if not ch:IsA("UIListLayout") then ch:Destroy() end end
end

local function renderFound(tok, data)
	c.modalSub.Text = ""
	K.banner(c.content, 1, { name = "YOUR OWN COMPANY", line = "Buy properties. They pay rent every minute, even when you're offline.",
		icon = "company", color = BLUE2, tint = Color3.fromRGB(170, 215, 255) })
	-- what you need, as three tiles
	local lvl, mon, steel = data.level or 1, data.money or 0, data.mats.steel or 0
	K.section(c.content, 2, "TO START", Color3.fromRGB(160, 215, 255), "all three, then pick a name")
	local grid = K.grid(c.content, 3, 3, 244)
	local function need(i, ok, name, icon, color, have)
		K.tile(grid, { order = i, name = name, icon = icon, color = color, artH = 104, stats = { { have, ok and K.GREEN or RED } },
			status = ok and { "✔ DONE", K.GREEN } or { "NOT YET", K.LOCK } })
	end
	need(1, lvl >= Company.FoundLevel, "Level " .. Company.FoundLevel, "level", Color3.fromRGB(255, 196, 60), "YOU: " .. lvl)
	need(2, mon >= Company.FoundCost, money(Company.FoundCost), "cash", Color3.fromRGB(90, 200, 110), "YOU: " .. money(mon))
	need(3, steel >= Company.FoundSteel, Company.FoundSteel .. " Steel Beams", "🔩", Color3.fromRGB(150, 160, 190), "YOU: " .. steel)
	-- name + found
	local ready = lvl >= Company.FoundLevel and mon >= Company.FoundCost and steel >= Company.FoundSteel
	local row = new("Frame", { Name = "Row", Size = UDim2.new(1, 0, 0, 78), BackgroundTransparency = 1, LayoutOrder = 4, ZIndex = 2, Parent = c.content })
	UI.slice("tile", { Name = "Bg", ImageColor3 = K.TILE, ZIndex = 1, Parent = row })
	local field = UI.slice("inset", { Name = "Field", Position = UDim2.fromOffset(14, 14), Size = UDim2.new(1, -244, 0, 50), SliceScale = 0.45, ImageTransparency = 0.12,
		ZIndex = 2, Parent = row })
	local box = new("TextBox", { Position = UDim2.fromOffset(14, 0), Size = UDim2.new(1, -28, 1, 0), BackgroundTransparency = 1, Text = "", PlaceholderText = "Company name (3-20 letters)",
		Font = T.body, TextSize = 21, TextColor3 = Color3.new(1, 1, 1), PlaceholderColor3 = Color3.fromRGB(205, 210, 240), TextXAlignment = Enum.TextXAlignment.Left,
		ClearTextOnFocus = false, ZIndex = 3, Parent = field })
	K.button(row, "FOUND IT!", ready and K.GREEN or K.LOCK, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -14, 0.5, 0), Size = UDim2.fromOffset(206, 54),
		TextSize = 24, Shine = ready }, function()
		c.click()
		if not ready then c.toast("📋 You need all three first", T.red, 2) return end
		local ok = act(tok, "found", box.Text)
		if ok then c.sound2D(c.S.Fanfare, 0.5, 1) end
	end)
end

local function renderEstate(tok, data)
	K.section(c.content, 2, "PROPERTIES", Color3.fromRGB(160, 215, 255), "own 10, 25, 50, 100 of one for 2x rent")
	local grid = K.grid(c.content, 3, cols(), 268)
	for i, p in ipairs(Company.Properties) do
		local info
		for _, x in ipairs(data.props) do if x.id == p.id then info = x end end
		if info then
			local o = { order = i, name = (p.name:gsub(" Rentals", "")), icon = K.BUILDING[p.id] or p.icon, color = K.RAR[(K.rarityOf(i, #Company.Properties))] }
			if info.owned > 0 then o.badge = { "x" .. info.owned, K.DARK } end
			if not info.unlocked then
				o.dim = true
				local cname = Config.ContractById[p.contract] and Config.ContractById[p.contract].name or p.contract
				o.stats = { { "BUILD: " .. string.upper(cname), K.LOCK } }
				o.status = { "🔒 LOCKED", K.LOCK }
			else
				o.tag = { money(info.rent) .. "/MIN", K.GREEN }
				o.stats = matChips(p.mats, data.mats)
				table.insert(o.stats, 1, { "+" .. money(info.nextRent), Color3.fromRGB(80, 200, 110) })
				while #o.stats > 2 do table.remove(o.stats) end
				local can = (data.money or 0) >= info.cost
				o.buttons = {
					{ money(info.cost), can and K.GREEN or K.LOCK, function() c.click(); act(tok, "buyProp", p.id, 1) end, shine = can },
					{ "x10", GOLD, function() c.click(); act(tok, "buyProp", p.id, 10) end },
				}
			end
			K.tile(grid, o)
		end
	end
end

render = function(tok, data)
	clear()
	if not data.founded then renderFound(tok, data) return end
	c.modalTitle.Text = data.name
	c.modalSub.Text = money(data.rent) .. "/min"
	-- your materials, one line
	local have = {}
	for _, m in ipairs(Company.Materials) do
		local n = data.mats[m.id] or 0
		if n > 0 then table.insert(have, Config.FormatNum(n) .. " " .. m.icon) end
	end
	K.note(c.content, 1, "Rent every minute, even offline (up to " .. Company.OfflineHours .. "h).   " .. (#have > 0 and ("You have: " .. table.concat(have, "  ")) or "Materials drop while you build."))
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

function M.Init(ctx)
	c = ctx
	UI, T, new, Config = c.UI, c.T, c.new, c.Config
	c.R.Feedback.OnClientEvent:Connect(function(kind, d)
		if kind == "Loot" then
			local m = Company.MaterialById[d.id]
			if not m then return end
			if d.pos then c.floatText(d.pos + Vector3.new(0, 3.5, 0), "+" .. d.qty .. " " .. m.icon, m.color, 1.1) end
			if m.order >= 3 then
				c.toast(m.icon .. " Rare find: " .. d.qty .. " " .. m.name .. "!", m.color, 3)
				c.sound2D(c.S.Chime, 0.5, 1.3)
			end
		elseif kind == "LootBlueprint" then
			local b = Company.BlueprintById[d.id]
			if b then
				c.banner("📜 BLUEPRINT FOUND!", b.name .. ": " .. b.desc, b.color)
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
			local h, mm = mins // 60, mins % 60
			c.banner("👋 WELCOME BACK!", "Your properties earned " .. money(d.amount) .. " in " .. (h > 0 and (h .. "h ") or "") .. mm .. "m", Color3.fromRGB(150, 210, 255))
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
