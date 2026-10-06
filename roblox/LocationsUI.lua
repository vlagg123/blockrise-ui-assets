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
	{ id = "shop", name = "Hammers Shop", icon = "shop", desc = "Hammer crates: a hammer in every one", tint = Color3.fromRGB(90, 170, 255) },
	{ id = "gearshop", name = "Training Shop", icon = "strength", desc = "Training gear: more Strength from every rep", tint = Color3.fromRGB(255, 150, 90) },
	{ id = "machines", name = "Machines Depot", icon = "mega", art = "excavator", desc = "Heavy machines that build on their own", tint = Color3.fromRGB(255, 196, 60) },
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

local function inTutorial() return (c.player:GetAttribute("RoadStep") or 1) <= (Config.TutorialSteps or 7) end

-- travel: stand a few steps in front of the place (towards the middle of the map), facing it.
-- Without the Teleporter you get the waypoint arrow instead. GO home is free for everyone.
function M.Go(id)
	if not hasTeleporter() and id ~= "home" then
		if id == "site" then
			if (c.player:GetAttribute("ContractJob") or "") == "" then
				c.toast("📋 Take a contract at the Job Board first", T.muted, 2.5)
			else
				c.toast("🏗️ Follow the arrow to your construction site", T.accent, 2.5)
			end
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
	local tut = inTutorial() -- the tutorial's last step: only the free trip home
	-- a redraw (a waypoint taken away) keeps the list where it was
	local scroll = c.modalOpen() and c.modalTitle.Text == "Places" and c.content.CanvasPosition or nil
	c.openModal("Locations", "Places", "", R1, R2)
	if scroll then task.defer(function() c.content.CanvasPosition = scroll end) end
	if not owned and not tut then
		-- the Teleporter offer sits on top
		local pass = teleporterPass()
		K.banner(c.content, 0, { name = "TELEPORTER", line = "Unlock GO and travel anywhere in one tap. Pins stay free.", icon = "locations",
			color = Color3.fromRGB(235, 70, 130), tint = Color3.fromRGB(255, 214, 120), buttonW = 170,
			button = { "\u{E002} " .. tostring(pass and pass.price or 39), K.GREEN, function() c.click(); offerTeleporter() end } })
	end
	-- the waypoint you have now: one tap takes it away (you know the way, or it's in your way). The row is always there
	-- (with no waypoint it says how to set one), so taking it away changes the text and nothing moves
	local wpName = c.waypointName and c.waypointName()
	if not tut then
		if wpName then
			local label = wpName
			for _, p in ipairs(PLACES) do if p.id == wpName then label = p.name end end
			K.row(c.content, 1, { name = "Waypoint: " .. label, line = "The arrow shows you the way there", icon = PIN_ICON, color = Color3.fromRGB(255, 190, 50), height = 88, buttonW = 170,
				button = { "REMOVE", T.red, function()
					c.click()
					if c.clearWaypoint then c.clearWaypoint() end
					c.toast("✖ Waypoint removed", T.muted, 1.8)
					M.Show()
				end } })
		else
			K.row(c.content, 1, { name = "Waypoint: none", line = "Tap the pin on a place: an arrow shows you the way", icon = PIN_ICON, color = Color3.fromRGB(255, 190, 50), height = 88, buttonW = 170,
				status = { "NO WAYPOINT", K.LOCK } })
		end
	end
	local grid = K.grid(c.content, 2, (_G.__CE_ListWidth and _G.__CE_ListWidth() or 780) >= 700 and 4 or 3, 250)
	for i, p in ipairs(PLACES) do
		local locked, badge = false, nil
		if p.zone then
			local z = Config.Zones[p.zone]
			if player:GetAttribute(z.attr) ~= true then
				locked = true
				badge = { "🔒 REBIRTH " .. (z.rebirth or 1), K.DARK }
			end
		end
		if p.needs == "contract" and (player:GetAttribute("ContractJob") or "") == "" then
			locked = true
			badge = { "NO JOB", K.DARK }
		end
		-- GO home is free for everyone (no Teleporter needed)
		local free = p.id == "home"
		if free then badge = { "FREE", K.GREEN } end
		local can = (owned or free) and not locked and not (tut and not free)
		local goText = (owned or free) and (locked and (p.zone and "GATE" or "NO JOB") or "GO") or "🔒 GO"
		-- (the Machines Depot shows the Mini Excavator's picture)
		local art = p.art and Config.MachineById and Config.MachineById[p.art] and Config.MachineById[p.art].image
		local tile = K.tile(grid, { order = (tut and free) and 0 or i, name = p.name, icon = art or p.icon, iconScale = art and 1.06 or nil, color = p.tint, badge = badge, artH = 124, dim = tut and not free, buttons = {
			{ goText, can and K.GREEN or K.LOCK, function()
				c.click()
				if tut and not free then c.toast("🔒 After the tutorial. Now tap GO at My Property!", T.muted, 2.5) return end
				if free then M.Go(p.id) return end
				if not hasTeleporter() then
					c.toast("📍 GO needs the Teleporter. The pin is free!", Color3.fromRGB(255, 214, 80), 3)
					offerTeleporter()
					return
				end
				if p.needs == "contract" and locked then c.toast("📋 Take a contract at the Job Board first", T.muted, 2.5) return end
				M.Go(p.id)
			end },
			-- the pin: sets the waypoint (the window closes, follow the arrow); on the place that has it now (red) it takes it away
			{ "", (wpName == p.id) and T.red or Color3.fromRGB(255, 190, 50), function()
				c.click()
				if tut and not free then c.toast("🔒 After the tutorial. Now tap GO at My Property!", T.muted, 2.5) return end
				if wpName == p.id then
					if c.clearWaypoint then c.clearWaypoint() end
					c.toast("✖ Waypoint removed", T.muted, 1.8)
					M.Show()
					return
				end
				-- no contract: there is no site to point at (the pin stays as it is, the window stays open)
				if p.needs == "contract" and locked then c.toast("📋 Take a contract at the Job Board first", T.muted, 2.5) return end
				c.closeModal()
				if p.id == "site" then c.toast("🏗️ Follow the arrow to your site", T.accent) return end
				c.setWaypoint(p.id)
			end, icon = PIN_ICON, square = true },
		} })
		-- the tutorial: a bouncing arrow on My Property's GO
		if tut and free and tile then
			local go
			for _, d in ipairs(tile:GetDescendants()) do
				if d:IsA("GuiButton") and not go then
					local l = d:FindFirstChildWhichIsA("TextLabel", true)
					if l and l.Text == "GO" then go = d end
				end
			end
			if go then
				-- a glowing ring that breathes around GO, on the tile's top layer (inside the button row the pin
				-- button next to it was drawn over it)
				local ring = new("Frame", { Name = "TutRing", AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1, ZIndex = 50, Parent = tile })
				new("UICorner", { CornerRadius = UDim.new(0, 14), Parent = ring })
				local rs = new("UIStroke", { Thickness = 4, Color = Color3.fromRGB(255, 220, 60), Parent = ring })
				task.spawn(function()
					local t0 = os.clock()
					while ring.Parent and go.Parent do
						local k = math.abs(math.sin((os.clock() - t0) * 4))
						-- the window is scaled: AbsoluteSize / the button's own 50 px height = the scale
						local sc = math.max(go.AbsoluteSize.Y / 50, 0.01)
						local rel = (go.AbsolutePosition - tile.AbsolutePosition) / sc
						local sz = go.AbsoluteSize / sc
						ring.Position = UDim2.fromOffset(rel.X + sz.X / 2, rel.Y + sz.Y / 2)
						ring.Size = UDim2.fromOffset(sz.X + 6 + 6 * k, sz.Y + 6 + 6 * k)
						rs.Transparency = 0.1 + 0.5 * (1 - k)
						rs.Thickness = 3 + 2 * k
						task.wait()
					end
				end)
			end
		end
	end
	K.note(c.content, 3, "The pin shows the way for free.  GO takes you there with the Teleporter (home is always free).")
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
