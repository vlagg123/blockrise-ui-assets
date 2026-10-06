-- BlockRise Empire - Rebirth window: start a new run much stronger, and the Star Shop
local RS = game:GetService("ReplicatedStorage")
local Company = require(RS.Shared:WaitForChild("Company"))
local K = require(RS.Shared:WaitForChild("MenuKit"))

local M = {}
local c, UI, T, new, Config
local P1, P2 = Color3.fromRGB(205, 150, 255), Color3.fromRGB(125, 65, 230)
local GOLD = Color3.fromRGB(255, 190, 40)

local PERK_ICON = { tycoon = "up_cash", genes = "up_strength", lawyer = "up_rent", lucky = "up_luck", headstart = "cash", crew = "up_crew" }
local PERK_COL = { tycoon = Color3.fromRGB(80, 200, 110), genes = Color3.fromRGB(255, 120, 80), lawyer = Color3.fromRGB(160, 110, 255),
	lucky = Color3.fromRGB(70, 200, 120), headstart = Color3.fromRGB(90, 190, 110), crew = Color3.fromRGB(255, 196, 60) }

local function money(n) return Config.FormatMoney(n) end
local function cols() return (_G.__CE_ListWidth and _G.__CE_ListWidth() or 780) >= 700 and 3 or 3 end

local function effect(p, f)
	if p.id == "tycoon" then return "+10% CASH"
	elseif p.id == "genes" then return "+20% STRENGTH"
	elseif p.id == "lawyer" then return "+25% RENT"
	elseif p.id == "lucky" then return "+10% LOOT"
	elseif p.id == "headstart" then return "START " .. money(f.headStart or 0)
	elseif p.id == "crew" then return "KEEP " .. tostring(f.keepCrew or 0)
	end
	return ""
end

-- what a Rebirth takes away (back to the start) and what it never touches: two cards side by side, so nobody is surprised
local RED, GREEN = Color3.fromRGB(226, 64, 72), Color3.fromRGB(46, 170, 90)
local function lines(parent, list, color)
	local box = new("Frame", { Name = "Lines", Position = UDim2.fromOffset(14, 52), Size = UDim2.new(1, -28, 1, -60), BackgroundTransparency = 1, ZIndex = 3, Parent = parent })
	new("UIListLayout", { Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder, Parent = box })
	for i, l in ipairs(list) do
		local row = new("Frame", { Size = UDim2.new(1, 0, 0, 25), BackgroundTransparency = 1, LayoutOrder = i, ZIndex = 3, Parent = box })
		new("Frame", { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 0, 0.5, 0), Size = UDim2.fromOffset(8, 8), BackgroundColor3 = color, BorderSizePixel = 0, ZIndex = 3, Parent = row },
			{ new("UICorner", { CornerRadius = UDim.new(1, 0) }) })
		K.text({ Position = UDim2.fromOffset(16, 0), Size = UDim2.new(1, -16, 1, 0), Text = l, TextSize = 17, Max = 17, Font = T.bold or T.body, ZIndex = 3, Parent = row })
	end
end
local function card(parent, x, title, color, list)
	local f = new("Frame", { Position = UDim2.new(x, x > 0 and 6 or 0, 0, 0), Size = UDim2.new(0.5, -6, 1, 0), BackgroundTransparency = 1, ZIndex = 2, Parent = parent })
	UI.slice("tile", { Name = "Bg", ImageColor3 = K.TILE, ZIndex = 1, Parent = f })
	local head = UI.slice("pill", { Position = UDim2.fromOffset(10, 10), Size = UDim2.new(1, -20, 0, 34), SliceScale = 0.42, ImageColor3 = color, ZIndex = 2, Parent = f })
	K.text({ Size = UDim2.fromScale(1, 1), Text = title, Font = T.chunky, TextSize = 20, Max = 20, TextColor3 = Color3.new(1, 1, 1), Stroke = 2.2,
		TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 3, Parent = head })
	lines(f, list, color)
end
local function resetCards(order, f)
	local p = c.player
	local start = (Config.StartMoney or 0) + (f.headStart or 0)
	local gear1 = Config.TrainingGear[1] and Config.TrainingGear[1].name or "Bare Hands"
	local workers, keep = p:GetAttribute("WorkerCount") or 0, f.keepCrew or 0
	local machines = 0
	for _, m in ipairs(Config.Machines) do if p:GetAttribute("M_" .. m.id) == true then machines += 1 end end
	local fmtN = Config.FormatNum
	local wiped = {
		"<b>Cash</b>  " .. money(p:GetAttribute("Money") or 0) .. "  →  " .. money(start),
		"<b>Strength</b>  " .. fmtN(math.floor(p:GetAttribute("Strength") or 0)) .. "  →  0",
		"<b>Training gear</b>  →  " .. gear1,
		"<b>Crew</b>  " .. workers .. "  →  " .. math.min(keep, workers) .. (keep > 0 and " (Star Shop keeps them)" or ""),
		"<b>Machines</b>  " .. machines .. "  →  0",
		"<b>Upgrades</b>  every level  →  LV 0",
		"<b>Properties</b>  all of them  →  0",
		"<b>Your contract</b>  →  cancelled",
	}
	local kept = {
		"<b>Level</b> and <b>Rep</b>",
		"<b>Hammers</b> (every one, with its level)",
		"<b>Gems</b>",
		"<b>Materials</b> and <b>blueprints</b>",
		"<b>Cars</b> and your <b>house</b>",
		"<b>Your company</b> and its name",
		"<b>Game passes</b>",
		"<b>Stars</b> and the <b>Star Shop</b>",
	}
	local box = new("Frame", { Name = "ResetCards", Size = UDim2.new(1, 0, 0, 62 + 27 * math.max(#wiped, #kept)), BackgroundTransparency = 1, LayoutOrder = order, ZIndex = 2, Parent = c.content })
	card(box, 0, "✖  BACK TO THE START", RED, wiped)
	card(box, 0.5, "✔  YOU KEEP", GREEN, kept)
end

function M.Show(keepScroll)
	local scroll = keepScroll and c.modalOpen() and c.content.CanvasPosition or nil
	local tok = c.openModal("Rebirth", "Rebirth", "", P1, P2)
	if scroll then task.defer(function() c.content.CanvasPosition = scroll end) end
	local loading = K.loading(c.content)
	local ok, okr, f = pcall(function() return c.R.FranchiseAction:InvokeServer("get") end)
	if not c.live(tok) then return end
	loading:Destroy()
	if not ok or not okr or type(f) ~= "table" then c.toast("⚠️ Couldn't load the Rebirth info, try again", T.red) return end
	c.modalSub.Text = "⭐ " .. f.stars

	-- the big card: progress, what you get, the button (two taps)
	local frac = math.clamp(f.run / math.max(f.cost, 1), 0, 1)
	local gateOk = not f.gate or f.gate.done
	local ready = f.run >= f.cost and gateOk
	local confirm = false
	K.banner(c.content, 1, { name = "REBIRTH #" .. (f.rebirths + 1), icon = "rebirth", color = P2, tint = Color3.fromRGB(215, 185, 255), height = 130, buttonW = 210,
		bar = { frac, GOLD, money(f.run) .. " / " .. money(f.cost) },
		chips = { { "+" .. f.starsNow .. (f.starsNow == 1 and " STAR" or " STARS"), Color3.fromRGB(150, 90, 230) }, { "+" .. math.floor(Company.FranchiseCashPer * 100) .. "% CASH", K.GREEN },
			{ "+" .. math.floor(Company.FranchiseStrengthPer * 100) .. "% STRENGTH", Color3.fromRGB(255, 120, 80) } },
		button = { ready and "REBIRTH!" or "NOT YET", ready and P2 or K.LOCK, function(b)
			c.click()
			if not gateOk then c.toast("🏗️ Build the " .. f.gate.name .. " once first (Job Board)", T.muted, 3) return end
			if not ready then c.toast("Earn " .. money(f.cost - f.run) .. " more to Rebirth", T.muted, 3) return end
			local lbl = b:FindFirstChild("Label")
			if not confirm then
				confirm = true
				if lbl then lbl.Text = "SURE? TAP AGAIN" end
				task.delay(3, function() confirm = false; if lbl and lbl.Parent then lbl.Text = "REBIRTH!" end end)
				return
			end
			local ok2, res, msg = pcall(function() return c.R.FranchiseAction:InvokeServer("franchise") end)
			if ok2 and res then c.closeModal() else c.toast("⚠️ " .. tostring(msg or "Can't Rebirth right now"), T.red) end
		end, shine = ready } })
	local opens = f.rebirths == 0 and "Rebirth 1 opens the SUBURBS!  " or (f.rebirths == 1 and "Rebirth 2 opens DOWNTOWN!  " or "")
	K.note(c.content, 3, opens .. "The cash and Strength bonus and your Stars stay forever.")
	resetCards(4, f)
	if f.gate then
		K.row(c.content, 2, { name = (f.gate.done and "✓ " or "") .. "Build the " .. f.gate.name, line = f.gate.done and "Done: this zone is finished" or "Finish this zone's top building once to Rebirth",
			icon = "contract", color = f.gate.done and K.GREEN or Color3.fromRGB(255, 176, 40), height = 84, buttonW = 150,
			status = { f.gate.done and "DONE" or "TO DO", f.gate.done and K.GREEN or K.LOCK } })
	end

	-- Star Shop
	K.section(c.content, 5, "STAR SHOP", Color3.fromRGB(255, 220, 110), "you have " .. f.stars .. " ⭐")
	local grid = K.grid(c.content, 6, cols(), 268)
	for i, p in ipairs(Company.StarPerks) do
		local info
		for _, x in ipairs(f.perks) do if x.id == p.id then info = x end end
		if info then
			local o = { order = i, name = p.name, icon = PERK_ICON[p.id] or p.icon, color = PERK_COL[p.id] or GOLD, tag = { effect(p, f), K.DARK },
				bar = { info.level / p.max, GOLD, "LV " .. info.level .. " / " .. p.max } }
			if info.level >= p.max then
				o.status = { "MAX", GOLD }
				o.spin = true
			else
				local can = f.stars >= info.cost
				o.button = { info.cost .. " ⭐", can and GOLD or K.LOCK, function()
					c.click()
					local ok3, res3, msg3 = pcall(function() return c.R.FranchiseAction:InvokeServer("perk", p.id) end)
					if not (ok3 and res3) then c.toast("⚠️ " .. tostring(msg3 or "Can't buy"), T.red) end
					if c.live(tok) then M.Show(true) end
				end, shine = can }
			end
			K.tile(grid, o)
		end
	end
end

function M.Init(ctx)
	c = ctx
	UI, T, new, Config = c.UI, c.T, c.new, c.Config
end

return M
