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

function M.Show()
	local tok = c.openModal("Rebirth", "Rebirth", "", P1, P2)
	local loading = K.loading(c.content)
	local ok, okr, f = pcall(function() return c.R.FranchiseAction:InvokeServer("get") end)
	if not c.live(tok) then return end
	loading:Destroy()
	if not ok or not okr or type(f) ~= "table" then c.toast("⚠️ Couldn't load the Rebirth info, try again", T.red) return end
	c.modalSub.Text = "⭐ " .. f.stars

	-- the big card: progress, what you get, the button (two taps)
	local frac = math.clamp(f.run / math.max(f.cost, 1), 0, 1)
	local ready = f.run >= f.cost
	local confirm = false
	K.banner(c.content, 1, { name = "REBIRTH #" .. (f.rebirths + 1), icon = "rebirth", color = P2, tint = Color3.fromRGB(215, 185, 255), height = 130, buttonW = 210,
		bar = { frac, GOLD, money(f.run) .. " / " .. money(f.cost) },
		chips = { { "+" .. f.starsNow .. " ⭐", GOLD }, { "+" .. math.floor(Company.FranchiseCashPer * 100) .. "% CASH", K.GREEN },
			{ "+" .. math.floor(Company.FranchiseStrengthPer * 100) .. "% STRENGTH", Color3.fromRGB(255, 120, 80) } },
		button = { ready and "REBIRTH!" or "NOT YET", ready and P2 or K.LOCK, function(b)
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
		end, shine = ready } })
	K.note(c.content, 2, "You keep your Level, Rep, house, Gems, materials, blueprints and cars." .. (f.rebirths == 0 and "  The first Rebirth opens Downtown!" or ""))

	-- Star Shop
	K.section(c.content, 3, "STAR SHOP", Color3.fromRGB(255, 220, 110), "you have " .. f.stars .. " ⭐")
	local grid = K.grid(c.content, 4, cols(), 268)
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
					if c.live(tok) then M.Show() end
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
