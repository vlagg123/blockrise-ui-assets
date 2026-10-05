-- BlockRise Empire - Places: every location in one list. The pin (waypoint arrow) is free; GO (instant travel)
-- needs the Teleporter game pass.
local RS = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")
local Icons = require(RS.Shared:WaitForChild("Icons"))

local M = {}
local c, UI, T, new, Config
local R1, R2 = Color3.fromRGB(255, 140, 150), Color3.fromRGB(225, 55, 85)
local INK = Color3.fromRGB(20, 17, 32)

local PLACES = {
	{ id = "board", name = "Job Board", icon = "board", desc = "Take new contracts", tint = Color3.fromRGB(255, 190, 70) },
	{ id = "site", name = "My Construction Site", icon = "site", desc = "Back to the contract you're building", tint = Color3.fromRGB(255, 150, 70), needs = "contract" },
	{ id = "shop", name = "Equipment Store", icon = "shop", desc = "Tools, training gear and heavy machines", tint = Color3.fromRGB(90, 170, 255) },
	{ id = "hire", name = "Hiring Office", icon = "hire", desc = "Hire workers for your crew", tint = Color3.fromRGB(110, 210, 120) },
	{ id = "gym", name = "Training Yard", icon = "gym", desc = "Train your Strength", tint = Color3.fromRGB(255, 120, 90) },
	{ id = "home", name = "My Property", icon = "home", desc = "Upgrade your house and build extensions", tint = Color3.fromRGB(190, 140, 255) },
	{ id = "company", name = "Company Registry", icon = "company", desc = "Properties that pay rent every minute", tint = Color3.fromRGB(90, 190, 240) },
	{ id = "garage", name = "BlockRise Motors", icon = "garage", desc = "Cars to get around faster", tint = Color3.fromRGB(255, 110, 110) },
	{ id = "mega", name = "Mega Project", icon = "mega", desc = "Build the City Tower with everyone", tint = Color3.fromRGB(180, 130, 255) },
	{ id = "suburbs", name = "Suburbs", icon = "suburbs", desc = "Bigger homes and villas", tint = Color3.fromRGB(120, 200, 110), zone = "suburbs" },
	{ id = "downtown", name = "Downtown", icon = "downtown", desc = "Skyscraper sites for the big jobs", tint = Color3.fromRGB(100, 160, 255), zone = "downtown" },
}

local lastGo = 0

local function teleporterPass()
	for _, p in ipairs(Config.Store.passes) do if p.key == "teleporter" then return p end end
end
local function hasTeleporter() return c.player:GetAttribute("Pass_teleporter") == true end
local function offerTeleporter()
	local p = teleporterPass()
	if p and (p.id or 0) > 0 then
		MarketplaceService:PromptGamePassPurchase(c.player, p.id)
	else
		c.toast("📍 The Teleporter is coming soon!", T.muted, 2.5)
	end
end
M.Has = hasTeleporter
M.Offer = offerTeleporter

-- travel: stand a few steps in front of the place (towards the middle of the map), facing it.
-- Without the Teleporter you get the waypoint arrow instead.
function M.Go(id)
	if not hasTeleporter() then
		if id == "site" then
			c.toast("🏗️ Follow the arrow to your construction site", T.accent, 2.5)
		else
			c.setWaypoint(id)
		end
		return false
	end
	if os.clock() - lastGo < 1.2 then return end
	local pos
	if id == "site" then
		local js = c.Jobs:FindFirstChild(c.player:GetAttribute("ContractJob") or "")
		pos = js and (js:GetAttribute("WorkPoint") or js:GetAttribute("Center"))
		if typeof(pos) ~= "Vector3" then pos = nil end
		if not pos then c.toast("📋 You don't have a contract yet — take one at the Job Board", T.muted, 3) return end
	else
		pos = c.placePos(id)
	end
	if not pos then c.toast("⚠️ That place is still loading, try again in a second", T.muted, 2.5) return end
	local char = c.player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not (hrp and hum) or hum.Health <= 0 then return end
	lastGo = os.clock()
	c.closeModal()
	task.spawn(function()
		if hum.SeatPart then
			hum.Sit = false
			task.wait(0.25)
		end
		local flat = Vector3.new(pos.X, 0, pos.Z)
		local dir = flat.Magnitude > 1 and -flat.Unit or Vector3.new(0, 0, 1)
		local back = (id == "site" or id == "mega") and 6 or 12
		local spot = pos + dir * back
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = { char }
		local hit = workspace:Raycast(Vector3.new(spot.X, pos.Y + 6, spot.Z), Vector3.new(0, -40, 0), params)
		local y = (hit and hit.Position.Y or pos.Y) + hum.HipHeight + hrp.Size.Y / 2 + 0.3
		local stand = Vector3.new(spot.X, y, spot.Z)
		char:PivotTo(CFrame.lookAt(stand, Vector3.new(pos.X, y, pos.Z)))
		hrp.AssemblyLinearVelocity = Vector3.zero
		-- swing the camera behind you, looking at the place
		local cam = workspace.CurrentCamera
		local look = Vector3.new(pos.X - stand.X, 0, pos.Z - stand.Z)
		look = look.Magnitude > 0.1 and look.Unit or Vector3.new(0, 0, -1)
		cam.CFrame = CFrame.lookAt(stand - look * 14 + Vector3.new(0, 7, 0), stand + look * 8)
		c.sound2D(c.S.Chime, 0.35, 1.4)
		c.emit(stand, "sparks", Color3.fromRGB(255, 230, 140), 18)
	end)
end

function M.Show()
	local player = c.player
	local owned = hasTeleporter()
	local tok = c.openModal("Locations", "Places", owned and "Tap GO to travel" or "Pins are free · GO needs the Teleporter", R1, R2)
	if not owned then
		-- the Teleporter offer sits on top
		local tp = c.card(0, 92)
		new("UIStroke", { Thickness = 3, Color = Color3.fromRGB(255, 205, 70), Parent = tp })
		local tile = new("Frame", { Position = UDim2.fromOffset(10, 10), Size = UDim2.fromOffset(72, 72), BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 22, Parent = tp })
		UI.corner(18).Parent = tile
		UI.grad(Color3.fromRGB(255, 160, 190), Color3.fromRGB(215, 50, 110)).Parent = tile
		new("UIStroke", { Thickness = 2.5, Color = INK, Parent = tile })
		Icons.make("locations", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(1.1, 1.1), ZIndex = 23, Parent = tile })
		local tt = UI.label({ Position = UDim2.fromOffset(96, 10), Size = UDim2.new(1, -280, 0, 32), Text = "TELEPORTER", Font = Enum.Font.LuckiestGuy, TextSize = 26,
			TextColor3 = Color3.fromRGB(255, 214, 80), ZIndex = 22, Parent = tp })
		new("UIStroke", { Thickness = 2.5, Color = INK, Parent = tt })
		UI.label({ Position = UDim2.fromOffset(96, 44), Size = UDim2.new(1, -280, 0, 38), TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top, TextSize = 14,
			TextColor3 = Color3.fromRGB(225, 222, 240), ZIndex = 22, Parent = tp, Text = "Unlock GO: travel to any place in one tap, forever. The pins (arrow to follow) stay free." })
		local pass = teleporterPass()
		local buy = UI.button("R$ " .. tostring(pass and pass.price or 39), Color3.fromRGB(130, 240, 120), Color3.fromRGB(30, 160, 70),
			{ AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -14, 0.5, 0), Size = UDim2.fromOffset(150, 54), TextSize = 24, ZIndex = 23, Parent = tp })
		buy.Activated:Connect(function() c.click(); offerTeleporter() end)
	end
	for i, p in ipairs(PLACES) do
		local f = c.card(i, 84)
		local tile = new("Frame", { Position = UDim2.fromOffset(10, 8), Size = UDim2.fromOffset(68, 68), BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 22, Parent = f })
		UI.corner(16).Parent = tile
		UI.grad(p.tint:Lerp(Color3.new(1, 1, 1), 0.25), p.tint:Lerp(INK, 0.35)).Parent = tile
		new("UIStroke", { Thickness = 2.5, Color = INK, Parent = tile })
		Icons.make(p.icon, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(1.05, 1.05), ZIndex = 23, Parent = tile })
		local title = UI.label({ Position = UDim2.fromOffset(92, 12), Size = UDim2.new(1, -300, 0, 30), Text = p.name, Font = Enum.Font.LuckiestGuy, TextSize = 23, ZIndex = 22, Parent = f })
		new("UIStroke", { Thickness = 2, Color = INK, Parent = title })
		local sub = UI.label({ Position = UDim2.fromOffset(92, 44), Size = UDim2.new(1, -300, 0, 20), Text = p.desc, TextSize = 13, TextColor3 = T.muted, TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 22, Parent = f })
		local locked, lockText = false, nil
		if p.zone then
			local z = Config.Zones[p.zone]
			if player:GetAttribute(z.attr) ~= true then
				locked = true
				lockText = "🔒 " .. Config.FormatNum(z.rep or 0) .. " Rep"
				sub.Text = "Opens at " .. Config.FormatNum(z.rep or 0) .. " Reputation (you have " .. Config.FormatNum(player:GetAttribute("Rep") or 0) .. ")"
			end
		end
		if p.needs == "contract" and (player:GetAttribute("ContractJob") or "") == "" then
			locked = true
			lockText = "NO JOB"
			sub.Text = "Take a contract first"
		end
		if locked then f.BackgroundTransparency = 0.3 end
		local goText = locked and (p.zone and "TO GATE" or lockText) or "GO"
		if not owned and not (p.needs == "contract" and locked) then goText = "🔒 GO" end
		local green = owned and not locked
		local go = UI.button(goText, green and Color3.fromRGB(130, 240, 120) or T.bg3, green and Color3.fromRGB(30, 160, 70) or T.bg2,
			{ AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -66, 0.5, 0), Size = UDim2.fromOffset(130, 50), TextSize = (locked or not owned) and 18 or 24, ZIndex = 23, Parent = f })
		go.Activated:Connect(function()
			c.click()
			if p.needs == "contract" and locked then c.toast("📋 Take a contract at the Job Board first", T.muted, 2.5) return end
			if not hasTeleporter() then
				c.toast("📍 GO needs the Teleporter — or tap the pin to follow the arrow for free", Color3.fromRGB(255, 214, 80), 3)
				offerTeleporter()
				return
			end
			M.Go(p.id)
			if locked and lockText then c.toast(lockText .. " needed to enter " .. p.name, T.muted, 3) end
		end)
		local pin = UI.button("", Color3.fromRGB(255, 214, 70), Color3.fromRGB(240, 135, 20), { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0), Size = UDim2.fromOffset(46, 46), ZIndex = 23, Parent = f })
		Icons.make("locations", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(1.1, 1.1), ZIndex = 25, Parent = pin })
		pin.Activated:Connect(function()
			c.click()
			if p.id == "site" then c.toast("🏗️ Follow the arrow to your site", T.accent) c.closeModal() return end
			c.closeModal()
			c.setWaypoint(p.id)
		end)
	end
	local tip = c.card(40, 40)
	tip.BackgroundTransparency = 0.55
	UI.label({ Position = UDim2.fromOffset(14, 0), Size = UDim2.new(1, -28, 1, 0), TextSize = 12, TextWrapped = true, TextColor3 = T.muted, ZIndex = 22, Parent = tip,
		Text = "The pin shows the way with an arrow (free).  GO takes you there right away (Teleporter)." })
end

function M.Init(ctx)
	c = ctx
	UI, T, new, Config = c.UI, c.T, c.new, c.Config
	c.player:GetAttributeChangedSignal("Pass_teleporter"):Connect(function()
		if hasTeleporter() then
			c.toast("📍 Teleporter unlocked! Tap GO in Places to travel", T.green, 3.5)
			if c.modalOpen() and c.modalTitle.Text == "Places" then M.Show() end
		end
	end)
end

return M
