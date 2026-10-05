-- BlockRise Empire - Rebirth window: start a new run much stronger, and the Star Shop
local RS = game:GetService("ReplicatedStorage")
local Company = require(RS.Shared:WaitForChild("Company"))
local Icons = require(RS.Shared:WaitForChild("Icons"))

local M = {}
local c, UI, T, new, Config
local P1, P2 = Color3.fromRGB(205, 150, 255), Color3.fromRGB(125, 65, 230)
local GOLD, GOLD2 = Color3.fromRGB(255, 210, 70), Color3.fromRGB(235, 135, 20)
local INK = Color3.fromRGB(20, 17, 32)

local function money(n) return Config.FormatMoney(n) end

local function big(props)
	local l = UI.label(props)
	l.Font = Enum.Font.LuckiestGuy
	new("UIStroke", { Thickness = 2.5, Color = INK, Parent = l })
	return l
end

function M.Show()
	local tok = c.openModal("Rebirth", "Rebirth", "", P1, P2)
	local loading = c.loadingCard()
	local ok, okr, f = pcall(function() return c.R.FranchiseAction:InvokeServer("get") end)
	if not c.live(tok) then return end
	loading:Destroy()
	if not ok or not okr or type(f) ~= "table" then c.toast("⚠️ Couldn't load the Rebirth info, try again", T.red) return end
	c.modalSub.Text = f.rebirths .. " rebirth" .. (f.rebirths == 1 and "" or "s") .. "  ·  " .. f.stars .. " stars"

	-- main card
	local card = c.card(1, 236)
	new("UIStroke", { Thickness = 3, Color = P1, Transparency = 0.2, Parent = card })
	local tile = new("Frame", { Position = UDim2.fromOffset(14, 14), Size = UDim2.fromOffset(112, 112), BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 22, Parent = card })
	UI.corner(22).Parent = tile
	UI.grad(P1, P2).Parent = tile
	new("UIStroke", { Thickness = 3, Color = INK, Parent = tile })
	Icons.make("rebirth", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(1.05, 1.05), ZIndex = 23, Parent = tile })
	big({ Position = UDim2.fromOffset(142, 10), Size = UDim2.new(1, -156, 0, 36), Text = "REBIRTH #" .. (f.rebirths + 1), TextSize = 32, TextColor3 = GOLD, ZIndex = 22, Parent = card })
	UI.label({ Position = UDim2.fromOffset(142, 46), Size = UDim2.new(1, -156, 0, 52), TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top, TextSize = 14, TextColor3 = Color3.fromRGB(215, 218, 232), ZIndex = 22, Parent = card,
		Text = "Start a new run MUCH stronger: every Rebirth gives you Rebirth Stars and permanent bonuses. Your first Rebirth also unlocks DOWNTOWN." })
	local frac = math.clamp(f.run / math.max(f.cost, 1), 0, 1)
	local bar, fill = UI.bar({ Position = UDim2.fromOffset(142, 102), Size = UDim2.new(1, -156, 0, 24), Radius = 12, ZIndex = 22 }, GOLD, GOLD2)
	bar.Parent = card
	fill.Size = UDim2.fromScale(math.max(frac, 0.02), 1)
	local pct = big({ Size = UDim2.fromScale(1, 1), Text = math.floor(frac * 100) .. "%", TextSize = 15, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 24, Parent = bar })
	pct.ZIndex = 24
	UI.label({ Position = UDim2.fromOffset(142, 128), Size = UDim2.new(1, -156, 0, 20), Text = "Earned this run: " .. money(f.run) .. " / " .. money(f.cost), Font = T.title, TextSize = 15, ZIndex = 22, Parent = card })
	-- rewards row
	local rw = new("Frame", { Position = UDim2.fromOffset(14, 158), Size = UDim2.new(1, -262, 0, 66), BackgroundColor3 = Color3.fromRGB(14, 12, 26), BackgroundTransparency = 0.35, ZIndex = 22, Parent = card })
	UI.corner(14).Parent = rw
	Icons.make("rebirth_star", { Position = UDim2.fromOffset(6, 5), Size = UDim2.fromOffset(56, 56), ZIndex = 23, Parent = rw })
	big({ Position = UDim2.fromOffset(66, 6), Size = UDim2.new(1, -72, 0, 26), Text = "+" .. f.starsNow .. " REBIRTH STARS", TextSize = 20, TextColor3 = GOLD, ZIndex = 23, Parent = rw })
	UI.label({ Position = UDim2.fromOffset(66, 34), Size = UDim2.new(1, -72, 0, 24), Font = T.title, TextSize = 14, TextColor3 = Color3.fromRGB(150, 245, 150), ZIndex = 23, Parent = rw,
		Text = "+" .. math.floor(Company.FranchiseCashPer * 100) .. "% cash  ·  +" .. math.floor(Company.FranchiseStrengthPer * 100) .. "% Strength gains  ·  forever" })
	local ready = f.run >= f.cost
	local confirm = false
	local b = UI.button(ready and "REBIRTH!" or "NOT YET", ready and P1 or T.bg3, ready and P2 or T.bg2,
		{ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -14, 0, 164), Size = UDim2.fromOffset(230, 58), TextSize = 26, ZIndex = 23, Parent = card })
	b.Activated:Connect(function()
		c.click()
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
	end)
	local note = c.card(2, 40)
	note.BackgroundTransparency = 0.55
	UI.label({ Position = UDim2.fromOffset(14, 0), Size = UDim2.new(1, -28, 1, 0), TextWrapped = true, TextSize = 12, TextColor3 = T.muted, ZIndex = 22, Parent = note,
		Text = "Resets: cash, tools, gear, Strength, crew, machines, properties, upgrades.   Keeps: Level, Rep, house, Gems, materials, blueprints, company name, cars." })

	-- Star Shop
	local h = new("Frame", { Size = UDim2.new(1, -8, 0, 36), BackgroundTransparency = 1, LayoutOrder = 3, ZIndex = 21, Parent = c.content })
	big({ Size = UDim2.fromScale(1, 1), Text = "STAR SHOP  <font color='#ffd25a' size='17' face='FredokaOne'>you have " .. f.stars .. " Rebirth Stars</font>", TextSize = 24, ZIndex = 22, Parent = h })
	for i, p in ipairs(Company.StarPerks) do
		local info
		for _, x in ipairs(f.perks) do if x.id == p.id then info = x end end
		if info then
			local pc = c.card(3 + i, 78)
			local sw = new("Frame", { Position = UDim2.fromOffset(12, 11), Size = UDim2.fromOffset(56, 56), BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 22, Parent = pc })
			UI.corner(14).Parent = sw
			UI.grad(GOLD, GOLD2).Parent = sw
			new("UIStroke", { Thickness = 2.5, Color = INK, Parent = sw })
			UI.label({ Size = UDim2.fromScale(1, 1), Text = p.icon, TextSize = 30, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 23, Parent = sw })
			UI.label({ Position = UDim2.fromOffset(82, 8), Size = UDim2.new(1, -240, 0, 28), Text = p.name .. "  <font color='#9ea5b8' size='15'>Lv " .. info.level .. "/" .. p.max .. "</font>", Font = T.title, TextSize = 21, ZIndex = 22, Parent = pc })
			local extra = p.id == "headstart" and ("  (now " .. money(f.headStart) .. ")") or (p.id == "crew" and ("  (now " .. f.keepCrew .. ")") or "")
			UI.label({ Position = UDim2.fromOffset(82, 38), Size = UDim2.new(1, -240, 0, 20), Text = p.desc .. extra, Font = T.bold, TextSize = 13, TextColor3 = T.muted, TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 22, Parent = pc })
			if info.level >= p.max then
				c.pill(pc, "⭐ MAX", GOLD, 140)
			else
				local pb = UI.button(info.cost .. " STARS", GOLD, GOLD2, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -14, 0.5, 0), Size = UDim2.fromOffset(140, 46), TextSize = 18, ZIndex = 23, Parent = pc })
				local busy = false
				pb.Activated:Connect(function()
					if busy then return end
					busy = true
					c.click()
					local ok3, res3, msg3 = pcall(function() return c.R.FranchiseAction:InvokeServer("perk", p.id) end)
					busy = false
					if not (ok3 and res3) then c.toast("⚠️ " .. tostring(msg3 or "Can't buy"), T.red) end
					if c.live(tok) then M.Show() end
				end)
			end
		end
	end
end

function M.Init(ctx)
	c = ctx
	UI, T, new, Config = c.UI, c.T, c.new, c.Config
end

return M
