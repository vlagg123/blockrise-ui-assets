-- one-off patch (run in Edit): tutorial v3
--  * the tutorial ends at the TRAINING YARD: step 7 is "Visit the Training Yard" (done the moment you walk in, no more
--    arrow calling you back there); JOBS and SHOP unlock after it (TutorialSteps 7), the TUTORIAL tag counts 1..7
--  * the way home never gets lost: the server tells the client where your lot is (HomePos) when the lot isn't loaded,
--    and a target that is behind you or off the screen gets an arrow on the edge of the screen (with its distance)
--  * the Home button never errors on a lot that isn't loaded
local function replaceOnce(src, old, new)
	local a, b = src:find(old, 1, true)
	assert(a, "not found: " .. old:sub(1, 80))
	assert(not src:find(old, b + 1, true), "found twice: " .. old:sub(1, 80))
	return src:sub(1, a - 1) .. new .. src:sub(b + 1)
end
local C = game.ReplicatedStorage.Shared.Config
local Main = game.ServerScriptService.Game.Main
local Client = game.StarterPlayer.StarterPlayerScripts.Client
if C.Source:find('stat = "VisitedGym"', 1, true) then return "already patched" end

-- Config ---------------------------------------------------------------------------------------------------------
local cs = C.Source
cs = replaceOnce(cs, [[	R[18] = { title = "First Rebirth",]], [[	R[7] = { title = "Visit the Training Yard", desc = "Strength multiplies your build power and unlocks bigger jobs. Follow the arrow to the TRAINING YARD: train there any time (stand on a station and click).", stat = "VisitedGym", target = 1, place = "gym", cash = 150, gems = 5 }
	R[18] = { title = "First Rebirth",]])
cs = replaceOnce(cs, [[Config.RoadTutorialSteps = 11
-- the tutorial: JOBS, SHOP and the contract bar unlock once these first Empire Road steps are done
-- (Job Board, first building, Equipment Store, Hiring Office, your property)
Config.TutorialSteps = 6]], [[Config.RoadTutorialSteps = 7
-- the tutorial: JOBS, SHOP and the contract bar unlock once these first Empire Road steps are done
-- (Job Board, first building, first crate, Hiring Office, your property, Training Yard)
Config.TutorialSteps = 7]])
assert(loadstring(cs), "compile Config")

-- Main -----------------------------------------------------------------------------------------------------------
local m = Main.Source
m = replaceOnce(m, [[	elseif stat == "VisitedHome" then return s.home or 0]], [[	elseif stat == "VisitedHome" then return s.home or 0
	elseif stat == "VisitedGym" then return s.gym or 0]])
m = replaceOnce(m, [[				if here then
					st.data.Stats = st.data.Stats or {}
					st.data.Stats.home = 1
					roadCheck(plr)
					saveSoon(plr)
				end
			end]], [[				if here then
					st.data.Stats = st.data.Stats or {}
					st.data.Stats.home = 1
					roadCheck(plr)
					saveSoon(plr)
				end
			end
			-- "Visit the Training Yard": done when you walk into the yard
			if step and step.stat == "VisitedGym" and plr:GetAttribute("Loaded") then
				local hrp = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
				local map = workspace:FindFirstChild("Map")
				local yard = map and map:FindFirstChild("TrainingYard")
				local here = yard == nil -- no yard on this server: nothing to visit, don't get stuck
				if hrp and yard then
					local cf, size = yard:GetBoundingBox()
					local rel = cf:PointToObjectSpace(hrp.Position)
					here = math.abs(rel.X) < size.X / 2 + 4 and math.abs(rel.Z) < size.Z / 2 + 4
				end
				if here then
					st.data.Stats = st.data.Stats or {}
					st.data.Stats.gym = 1
					roadCheck(plr)
					saveSoon(plr)
				end
			end]])
m = replaceOnce(m, [[		plr:SetAttribute("Lot", st.lotIndex)
]], [[		plr:SetAttribute("Lot", st.lotIndex)
		-- where the lot is, for the arrow home even when the lot isn't loaded on the client
		plr:SetAttribute("HomePos", (st.lot:FindFirstChild("OwnerSign") or st.lot.HouseOrigin).Position)
]])
assert(loadstring(m), "compile Main")

-- Client ---------------------------------------------------------------------------------------------------------
local s = Client.Source
s = replaceOnce(s, [[	if name == "home" then
		local lot = Map.Lots:FindFirstChild("Lot" .. tostring(player:GetAttribute("Lot") or 0))
		return lot and lot.OwnerSign.Position
	end]], [[	if name == "home" then
		-- the sign on your lot, or (lot not loaded yet) the spot the server told us
		local lots = Map:FindFirstChild("Lots")
		local lot = lots and lots:FindFirstChild("Lot" .. tostring(player:GetAttribute("Lot") or 0))
		local sign = lot and lot:FindFirstChild("OwnerSign")
		if sign then return sign.Position end
		local hp = player:GetAttribute("HomePos")
		return typeof(hp) == "Vector3" and hp or nil
	end]])
s = replaceOnce(s, [[UI.textStroke(0.2, 2.5).Parent = markerLbl
]], [[UI.textStroke(0.2, 2.5).Parent = markerLbl
-- off-screen guidance: a place behind you or off the screen gets an arrow on the edge of the screen pointing at it
local edgeGui = new("ScreenGui", { Name = "NavEdge", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 1, Parent = player:WaitForChild("PlayerGui") })
local edge = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(64, 64), BackgroundTransparency = 1, Visible = false, Parent = edgeGui })
local edgeScale = new("UIScale", { Parent = edge })
local edgeArrow = UI.label({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(60, 60), Text = "▲", Font = T.title, TextSize = 52,
	TextColor3 = T.accent, TextXAlignment = Enum.TextXAlignment.Center, Parent = edge })
UI.textStroke(0.15, 3).Parent = edgeArrow
local edgeLbl = UI.label({ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 1, 0), Size = UDim2.fromOffset(240, 26), Text = "", Font = T.title, TextSize = 18,
	TextXAlignment = Enum.TextXAlignment.Center, Parent = edge })
UI.textStroke(0.2, 2.5).Parent = edgeLbl
]])
s = replaceOnce(s, [[	local lot = Map.Lots:FindFirstChild("Lot" .. tostring(player:GetAttribute("Lot") or 0))
	local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if lot and hrp and (hrp.Position - lot.HouseOrigin.Position).Magnitude < 55 then]], [[	local lots = Map:FindFirstChild("Lots")
	local lot = lots and lots:FindFirstChild("Lot" .. tostring(player:GetAttribute("Lot") or 0))
	local ho = lot and lot:FindFirstChild("HouseOrigin")
	local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if ho and hrp and (hrp.Position - ho.Position).Magnitude < 55 then]])
s = replaceOnce(s, [[		marker.Enabled = true
		markerLbl.Text = tlabel .. (dist > 25 and ("  " .. math.floor(dist) .. "m") or "")
		marker.StudsOffset = Vector3.new(0, 6 + math.sin(os.clock() * 4) * 0.6, 0)
	else
		beam.Enabled = false
		marker.Enabled = false
	end]], [[		marker.Enabled = true
		markerLbl.Text = tlabel .. (dist > 25 and ("  " .. math.floor(dist) .. "m") or "")
		marker.StudsOffset = Vector3.new(0, 6 + math.sin(os.clock() * 4) * 0.6, 0)
		-- behind you or off the screen: the arrow on the edge of the screen shows which way to turn
		local vs = camera.ViewportSize
		local vp = camera:WorldToViewportPoint(tpos + Vector3.new(0, 6, 0))
		local mg = 90
		if dist > 18 and not modal.Visible and (vp.Z < 0 or vp.X < mg or vp.X > vs.X - mg or vp.Y < mg or vp.Y > vs.Y - mg) then
			local dx, dy = vp.X - vs.X / 2, vp.Y - vs.Y / 2
			if vp.Z < 0 then dx, dy = -dx, -dy end
			if math.abs(dx) < 1 and math.abs(dy) < 1 then dy = 1 end
			local hx, hy = vs.X / 2 - 140, vs.Y / 2 - mg
			local k = math.min(hx / math.max(math.abs(dx), 1e-3), hy / math.max(math.abs(dy), 1e-3))
			edge.Position = UDim2.fromOffset(vs.X / 2 + dx * k, vs.Y / 2 + dy * k)
			edgeArrow.Rotation = math.deg(math.atan2(dy, dx)) + 90
			edgeLbl.Text = tlabel .. "  " .. math.floor(dist) .. "m"
			edgeScale.Scale = uiScale.Scale
			edge.Visible = true
		else
			edge.Visible = false
		end
	else
		beam.Enabled = false
		marker.Enabled = false
		edge.Visible = false
	end]])
s = replaceOnce(s, [[			or tp == "home" and "🏠 Walk to YOUR PROPERTY in Maple Grove — follow the arrow"
]], [[			or tp == "home" and "🏠 Walk to YOUR PROPERTY in Maple Grove — follow the arrow"
			or tp == "gym" and "💪 Last step: walk to the TRAINING YARD — follow the arrow"
]])
assert(loadstring(s), "compile Client")

C.Source = cs
Main.Source = m
Client.Source = s
return "tutorial v3 applied"
