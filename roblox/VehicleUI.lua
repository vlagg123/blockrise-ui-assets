-- BlockRise Empire - Garage: buy vehicles with cash, get the Robux exclusives, spawn one next to you
local RS = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")
local Models = require(RS.Shared:WaitForChild("VehicleModels"))
local K = require(RS.Shared:WaitForChild("MenuKit"))

local M = {}
local c
local UI, T, new, Config
local RED1, RED2 = Color3.fromRGB(255, 130, 100), Color3.fromRGB(220, 60, 50)
local GOLD = Color3.fromRGB(255, 176, 40)

local function passOf(v)
	for _, p in ipairs(Config.Store.passes) do if p.key == v.pass then return p end end
end
local function cols() return (_G.__CE_ListWidth and _G.__CE_ListWidth() or 780) >= 700 and 3 or 2 end

-- 3D preview of the car on the tile's art
local function preview(v)
	return function(art)
		local vp = new("ViewportFrame", { Position = UDim2.fromOffset(4, 4), Size = UDim2.new(1, -8, 1, -8), BackgroundTransparency = 1,
			Ambient = Color3.fromRGB(170, 170, 180), LightColor = Color3.new(1, 1, 1), LightDirection = Vector3.new(-0.5, -1, -0.6), ZIndex = 6, Parent = art })
		local ok, model = pcall(Models.Build, v, { preview = true })
		if not ok or not model then return vp end
		model:PivotTo(CFrame.new())
		model.Parent = vp
		local cam = Instance.new("Camera")
		cam.FieldOfView = 30
		cam.Parent = vp
		vp.CurrentCamera = cam
		local cf, size = model:GetBoundingBox()
		local dir = Vector3.new(-1, 0.6, -1.2).Unit -- front-left, a little from above
		cam.CFrame = CFrame.lookAt(cf.Position + dir * size.Magnitude * 1.3, cf.Position)
		return vp
	end
end

-- every vehicle has a rarity (the faster and rarer, the higher): the card, the chip and the name wear its look
local RARITY = { kart = "common", pickup = "uncommon", muscle = "rare", sports = "epic", hyper = "legendary", monster = "mythic", goldcar = "divine" }
local RAR_NAME = { common = "COMMON", uncommon = "UNCOMMON", rare = "RARE", epic = "EPIC", legendary = "LEGENDARY", mythic = "MYTHIC", divine = "DIVINE" }
local RAR_COL = { common = Color3.fromRGB(150, 156, 178), uncommon = Color3.fromRGB(80, 200, 100), rare = Color3.fromRGB(60, 150, 255), epic = Color3.fromRGB(165, 90, 255),
	legendary = Color3.fromRGB(255, 170, 30), mythic = Color3.fromRGB(255, 70, 120), divine = Color3.fromRGB(250, 214, 255) }
local function rarityOf(v) return v.rarity or RARITY[v.id] or "common" end

function M.Show()
	local tok = c.openModal("Garage", "Garage", "", RED1, RED2)
	c.modalSub.Text = "" -- (no subtitle pill on the garage)
	local loading = K.loading(c.content)
	local ok, okr, data = pcall(function() return c.R.VehicleAction:InvokeServer("get") end)
	if not c.live(tok) then return end
	loading:Destroy()
	if not ok or not okr or type(data) ~= "table" then c.toast("⚠️ Couldn't open the garage, try again", T.red) return end
	local money = c.player:GetAttribute("Money") or 0
	local maxSpeed = 1
	for _, v in ipairs(Config.Vehicles) do maxSpeed = math.max(maxSpeed, v.speed or 0) end
	local nOwned = 0
	for _, v in ipairs(Config.Vehicles) do if data.owned[v.id] then nOwned += 1 end end
	c.modalSub.Text = nOwned .. " / " .. #Config.Vehicles .. " owned"

	-- one vehicle: its 3D model on a card in its rarity, seats, a speed bar, and what you can do with it
	local function vehicleTile(grid, v, i)
		local owned = data.owned[v.id]
		local rid = rarityOf(v)
		local col = RAR_COL[rid] or RED1
		local o = { order = i, name = v.name, color = col, custom = preview(v), artH = 140,
			badge = { RAR_NAME[rid] or "", col }, tag = { (v.seats + 1) .. (v.seats == 0 and " SEAT" or " SEATS"), K.DARK },
			bar = { (v.speed or 0) / maxSpeed, col:Lerp(Color3.new(0, 0, 0), 0.1), Config.SpeedKmh(v.speed) .. " KM/H" }, spin = owned or v.pass ~= nil }
		if owned then
			local here = data.active == v.id
			o.button = { here and "BRING HERE" or "DRIVE", K.GREEN, function()
				c.click()
				local ok2, res, msg = pcall(function() return c.R.VehicleAction:InvokeServer("spawn", v.id) end)
				if ok2 and res then c.closeModal() else c.toast("⚠️ " .. tostring(msg or "Can't spawn it here"), T.red, 3) end
			end, shine = true }
		elseif v.pass then
			local p = passOf(v)
			if p and (p.id or 0) > 0 then
				o.button = { K.robux(p.price), K.GREEN, function() c.click(); MarketplaceService:PromptGamePassPurchase(c.player, p.id) end, shine = true }
			else
				o.status = { "SOON", K.LOCK }
			end
		else
			local can = money >= v.price
			o.button = { Config.FormatMoney(v.price), can and GOLD or K.LOCK, function()
				c.click()
				if not can then c.toast("💵 Not enough cash yet. Finish more contracts", T.red, 2.5) return end
				local ok2, res, msg = pcall(function() return c.R.VehicleAction:InvokeServer("buy", v.id) end)
				if ok2 and res then
					-- bought: the window closes and the new car is parked right next to you
					c.closeModal()
					-- (the server takes one car action at a time, a quarter of a second apart)
					local ok3, res3, msg3
					for _ = 1, 4 do
						task.wait(0.35)
						ok3, res3, msg3 = pcall(function() return c.R.VehicleAction:InvokeServer("spawn", v.id) end)
						if ok3 and res3 then break end
						if msg3 ~= "Slow down!" and msg3 ~= "One moment..." then break end
					end
					if not (ok3 and res3) then c.toast("⚠️ " .. tostring(msg3 or "Can't park it here: press DRIVE in the Garage"), T.red, 3) end
				else
					c.toast("⚠️ " .. tostring(msg or "Can't buy that"), T.red)
				end
			end, icon = "cash", shine = can }
		end
		local t = K.tile(grid, o)
		-- the rarity look: the chip, the name, and (Legendary and up) the card itself
		local chip = t:FindFirstChild("Chip")
		if chip and K.RARITY_LOOK[rid] then K.rarityChip(chip, rid) end
		local tl = t:FindFirstChild("Title")
		if tl then
			if K.RARITY_LOOK[rid] then K.rarityText(tl, rid) else tl.TextColor3 = col:Lerp(Color3.new(0, 0, 0), 0.25) end
		end
		local art = t:FindFirstChild("Art")
		if art and K.RARITY_LOOK[rid] then K.rarityFX(art, rid) end
		if owned and data.active == v.id then
			K.chip(t, "OUT NOW", K.GREEN, { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 0, 8 + 140 - 6), ZIndex = 9 })
		end
		return t
	end

	local order = 1
	-- the vehicle you have out right now
	local activeCfg = data.active and Config.VehicleById[data.active]
	if activeCfg then
		K.row(c.content, order, { name = "Your " .. activeCfg.name .. " is out", line = "DRIVE brings it next to you · E to drive, SPACE to get out", icon = "garage",
			color = RAR_COL[rarityOf(activeCfg)] or RED2, height = 88, buttonW = 170, button = { "PUT AWAY", K.LOCK, function()
				c.click()
				pcall(function() c.R.VehicleAction:InvokeServer("despawn") end)
				if c.live(tok) then M.Show() end
			end } })
		order += 1
	end
	local mine, shop, robux = {}, {}, {}
	for _, v in ipairs(Config.Vehicles) do
		if data.owned[v.id] then table.insert(mine, v) elseif v.pass then table.insert(robux, v) else table.insert(shop, v) end
	end
	-- YOUR GARAGE: what you own, fastest first
	if #mine > 0 then
		table.sort(mine, function(a, b) return (a.speed or 0) > (b.speed or 0) end)
		K.category(c.content, order, { title = "YOUR GARAGE", line = #mine .. (#mine == 1 and " vehicle" or " vehicles") .. "  ·  DRIVE to bring one next to you", icon = "garage",
			c1 = Color3.fromRGB(255, 120, 90), c2 = Color3.fromRGB(215, 50, 60), first = order == 1 })
		local g = K.grid(c.content, order + 1, cols(), 280)
		for i, v in ipairs(mine) do vehicleTile(g, v, i) end
		order += 2
	end
	-- DEALERSHIP: the cars for cash, cheapest first
	if #shop > 0 then
		table.sort(shop, function(a, b) return (a.price or 0) < (b.price or 0) end)
		K.category(c.content, order, { title = "DEALERSHIP", line = "Buy once, keep forever  ·  faster cars, more seats for your friends", icon = "cars",
			c1 = Color3.fromRGB(255, 200, 70), c2 = Color3.fromRGB(235, 120, 20), first = order == 1 })
		local g = K.grid(c.content, order + 1, cols(), 280)
		for i, v in ipairs(shop) do vehicleTile(g, v, i) end
		order += 2
	end
	-- EXCLUSIVE: Robux only
	if #robux > 0 then
		K.category(c.content, order, { title = "EXCLUSIVE RIDES", line = "Robux only  ·  the rarest rides in the city", icon = "vip",
			c1 = Color3.fromRGB(200, 120, 255), c2 = Color3.fromRGB(120, 60, 220), first = order == 1 })
		local g = K.grid(c.content, order + 1, cols(), 280)
		for i, v in ipairs(robux) do vehicleTile(g, v, i) end
		order += 2
	end
	K.note(c.content, order, "E to drive, SPACE to get out. Your vehicles stay yours through Rebirths.")
end

function M.Init(ctx)
	c = ctx
	UI, T, new, Config = c.UI, c.T, c.new, c.Config
	-- a Robux ride just bought: the Garage closes and it is parked next to you (the server needs a moment to see the pass)
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(plr, passId, bought)
		if plr ~= c.player or not bought then return end
		local v
		for _, x in ipairs(Config.Vehicles) do
			local p = x.pass and passOf(x)
			if p and p.id == passId then v = x end
		end
		if not v then return end
		if c.modalOpen() and c.modalTitle.Text == "Garage" then c.closeModal() end
		task.spawn(function()
			for _ = 1, 8 do
				task.wait(0.75)
				local ok3, res3 = pcall(function() return c.R.VehicleAction:InvokeServer("spawn", v.id) end)
				if ok3 and res3 then return end
			end
		end)
	end)
	c.R.Feedback.OnClientEvent:Connect(function(kind, d)
		if kind == "VehicleBought" then
			c.banner("🚗 NEW VEHICLE!", d.icon .. " " .. d.name .. " is yours forever. Press SPAWN to drive it", RED1)
			c.sound2D(c.S.Fanfare, 0.5, 1.1)
		elseif kind == "VehicleSpawned" then
			c.toast(d.icon .. " Your " .. d.name .. " is parked next to you. Press E to drive", RED1, 3.5)
			c.sound2D(c.S.Chime, 0.5, 1.2)
		elseif kind == "VehicleStored" then
			c.toast("🅿️ Your " .. d.name .. " went back to the garage", T.muted, 3)
		end
	end)
end

return M
