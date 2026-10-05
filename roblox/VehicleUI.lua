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

function M.Show()
	local tok = c.openModal("Garage", "Garage", "", RED1, RED2)
	c.modalSub.Text = "" -- (no subtitle pill on the garage)
	local loading = K.loading(c.content)
	local ok, okr, data = pcall(function() return c.R.VehicleAction:InvokeServer("get") end)
	if not c.live(tok) then return end
	loading:Destroy()
	if not ok or not okr or type(data) ~= "table" then c.toast("⚠️ Couldn't open the garage, try again", T.red) return end
	local activeCfg = data.active and Config.VehicleById[data.active]
	if activeCfg then
		K.row(c.content, 1, { name = "Your " .. activeCfg.name .. " is parked out there", line = "Spawn it again to bring it next to you.", icon = "garage", color = RED2,
			height = 96, buttonW = 170, button = { "PUT AWAY", K.LOCK, function()
				c.click()
				pcall(function() c.R.VehicleAction:InvokeServer("despawn") end)
				if c.live(tok) then M.Show() end
			end } })
	end
	local money = c.player:GetAttribute("Money") or 0
	local function vehicleTile(grid, v, i)
		local owned = data.owned[v.id]
		local o = { order = i, name = v.name, color = v.pass and Color3.fromRGB(255, 190, 60) or RED1, custom = preview(v), artH = 136,
			tag = { (v.seats + 1) .. (v.seats == 0 and " SEAT" or " SEATS"), K.DARK }, stats = { { Config.SpeedKmh(v.speed) .. " KM/H", T.blue } }, spin = v.pass ~= nil }
		if owned then
			o.button = { data.active == v.id and "BRING HERE" or "SPAWN", K.GREEN, function()
				c.click()
				local ok2, res, msg = pcall(function() return c.R.VehicleAction:InvokeServer("spawn", v.id) end)
				if ok2 and res then c.closeModal() else c.toast("⚠️ " .. tostring(msg or "Can't spawn it here"), T.red, 3) end
			end, shine = true }
		elseif v.pass then
			local p = passOf(v)
			if p and (p.id or 0) > 0 then
				o.button = { "R$ " .. tostring(p.price or "?"), K.GREEN, function() c.click(); MarketplaceService:PromptGamePassPurchase(c.player, p.id) end, shine = true }
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
					if c.live(tok) then M.Show() end
				else
					c.toast("⚠️ " .. tostring(msg or "Can't buy that"), T.red)
				end
			end, icon = "cash", shine = can }
		end
		K.tile(grid, o)
	end
	K.section(c.content, 2, "VEHICLES", Color3.fromRGB(255, 190, 170), "E to drive, SPACE to get out")
	local g1 = K.grid(c.content, 3, cols(), 276)
	for i, v in ipairs(Config.Vehicles) do if not v.pass then vehicleTile(g1, v, i) end end
	K.section(c.content, 4, "EXCLUSIVE", Color3.fromRGB(255, 220, 110), "Robux only")
	local g2 = K.grid(c.content, 5, cols(), 276)
	for i, v in ipairs(Config.Vehicles) do if v.pass then vehicleTile(g2, v, i) end end
end

function M.Init(ctx)
	c = ctx
	UI, T, new, Config = c.UI, c.T, c.new, c.Config
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
