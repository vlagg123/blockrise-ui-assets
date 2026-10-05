-- BlockRise Empire - Places: every location in one list. The pin (waypoint arrow) is free; GO (instant travel)
-- needs the Teleporter game pass.
local RS = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")
local K = require(RS.Shared:WaitForChild("MenuKit"))
local Icons = require(RS.Shared:WaitForChild("Icons"))
local PIN_ICON = Icons.has("pin") and "pin" or "locations"

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
	c.openModal("Locations", "Places", "", R1, R2)
	if not owned then
		-- the Teleporter offer sits on top
		local pass = teleporterPass()
		K.banner(c.content, 0, { name = "TELEPORTER", line = "Unlock GO and travel anywhere in one tap. Pins stay free.", icon = "locations",
			color = Color3.fromRGB(235, 70, 130), tint = Color3.fromRGB(255, 214, 120), buttonW = 170,
			button = { "R$ " .. tostring(pass and pass.price or 39), K.GREEN, function() c.click(); offerTeleporter() end } })
	end
	local grid = K.grid(c.content, 2, (_G.__CE_ListWidth and _G.__CE_ListWidth() or 780) >= 700 and 4 or 3, 250)
	for i, p in ipairs(PLACES) do
		local locked, badge = false, nil
		if p.zone then
			local z = Config.Zones[p.zone]
			if player:GetAttribute(z.attr) ~= true then
				locked = true
				badge = { "🔒 " .. Config.FormatNum(z.rep or 0) .. " ⭐", K.DARK }
			end
		end
		if p.needs == "contract" and (player:GetAttribute("ContractJob") or "") == "" then
			locked = true
			badge = { "NO JOB", K.DARK }
		end
		local goText = owned and (locked and (p.zone and "GATE" or "NO JOB") or "GO") or "🔒 GO"
		K.tile(grid, { order = i, name = p.name, icon = p.icon, color = p.tint, badge = badge, artH = 124, buttons = {
			{ goText, owned and not locked and K.GREEN or K.LOCK, function()
				c.click()
				if not hasTeleporter() then
					c.toast("📍 GO needs the Teleporter. The pin is free!", Color3.fromRGB(255, 214, 80), 3)
					offerTeleporter()
					return
				end
				if p.needs == "contract" and locked then c.toast("📋 Take a contract at the Job Board first", T.muted, 2.5) return end
				M.Go(p.id)
			end },
			{ "", Color3.fromRGB(255, 190, 50), function()
				c.click()
				c.closeModal()
				if p.id == "site" then c.toast("🏗️ Follow the arrow to your site", T.accent) return end
				c.setWaypoint(p.id)
			end, icon = PIN_ICON, square = true },
		} })
	end
	K.note(c.content, 3, "The pin shows the way for free.  GO takes you there with the Teleporter.")
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
