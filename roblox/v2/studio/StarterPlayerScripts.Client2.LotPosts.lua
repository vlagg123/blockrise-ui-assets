-- BlockRise 2.0 - lot posts (LOTPOST_V1, 2026-10-18). The owner: the floating tags and bubbles were unreadable ("you
-- cannot tell which belongs to which building"). Now everything about a building stands ON its lot, the way the big
-- tycoons do it, and nothing floats over the roofs any more:
--  * a post at the lot's front corner, on the sidewalk's edge, with a sign that turns to you: the building, its level,
--    the money it makes each second (gold +25% when its block has the bonus). Every city has them.
--  * on your lots, a glowing pad on the ground at the foot of the post, with the action on the sign: BUILD / UPGRADE
--    and the price. Step on the pad (or tap the sign's button) and it is done. Green = you can pay it; grey = the price
--    and what is missing; blue = building now (its progress) or waiting in the crew's queue; no pad at the top level.
-- The signs are sized in studs (they get smaller with distance like real signs) with a small minimum, and are hidden by
-- the buildings in front of them (no AlwaysOnTop).
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local M = {}
local C3 = Color3.fromRGB
local WHITE = Color3.new(1, 1, 1)

local DW, DH, DH_SMALL = 300, 172, 106 -- the sign's design size (pixels before scaling): with an action / info only
local STUDS, MINPX = 11, 90         -- the sign's width in studs (+ a minimum in pixels, so far signs stay readable)
local POLE = 6.2                     -- the pole's height (the sign sits on it)
local PAD_R = 3.2                    -- the pad's radius
local INC_TS = 25                    -- the income's text size

local STATE = {
	go = { col = "green", disc = C3(70, 225, 110) },
	need = { col = "grey", disc = C3(150, 160, 186) },
	busy = { col = "blue", disc = C3(80, 170, 255) },
	full = { col = "grey", disc = C3(150, 160, 186) },
}

function M.start(api)
	local UI, C, attr, lots = api.UI, api.C, api.attr, api.lots
	local new = UI.new
	local plr = Players.LocalPlayer
	local holder = new("Folder", { Name = "LotPosts", Parent = workspace })
	local guiParent = plr:WaitForChild("PlayerGui")
	local posts = {} -- lot model -> post

	-- where a lot's post stands: its front-right corner, just past the kerb (local -Z is the street side)
	local function cornerCF(pad)
		return pad.CFrame * CFrame.new(pad.Size.X / 2 - 4.6, pad.Size.Y / 2, -pad.Size.Z / 2 - 1.6)
	end
	local function padCF(pad)
		return pad.CFrame * CFrame.new(pad.Size.X / 2 - 4.6, pad.Size.Y / 2 + 0.12, -pad.Size.Z / 2 + 4.6)
	end

	local function makePost(m)
		local pad = m:FindFirstChild("Pad")
		if not pad then return nil end
		local cf = cornerCF(pad)
		local model = new("Model", { Name = "Post_" .. m:GetFullName():gsub("%.", "_"), Parent = holder })
		local pole = new("Part", { Name = "Pole", Shape = Enum.PartType.Cylinder, Size = Vector3.new(POLE, 0.42, 0.42), CFrame = cf * CFrame.new(0, POLE / 2, 0) * CFrame.Angles(0, 0, math.rad(90)),
			Color = C3(240, 244, 252), Material = Enum.Material.SmoothPlastic, Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false, Parent = model })
		new("Part", { Name = "Foot", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.3, 1.3, 1.3), CFrame = cf * CFrame.new(0, 0.15, 0) * CFrame.Angles(0, 0, math.rad(90)),
			Color = C3(36, 46, 96), Material = Enum.Material.SmoothPlastic, Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false, Parent = model })
		local anchor = new("Part", { Name = "Anchor", Size = Vector3.new(0.2, 0.2, 0.2), CFrame = cf * CFrame.new(0, POLE, 0), Transparency = 1, Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false, Parent = model })
		-- the sign: a world-sized billboard (studs), the design drawn at DW x DH and scaled to it
		local bb = new("BillboardGui", { Name = "Sign", Adornee = anchor, Size = UDim2.new(STUDS, MINPX, STUDS * DH / DW, MINPX * DH / DW), SizeOffset = Vector2.new(0, 0.5),
			LightInfluence = 0, MaxDistance = 150, Active = true, ResetOnSpawn = false, ClipsDescendants = false, Parent = guiParent })
		local root = new("Frame", { Name = "Root", BackgroundTransparency = 1, Size = UDim2.fromOffset(DW, DH), AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.fromScale(0.5, 1), Parent = bb })
		local sc = new("UIScale", { Parent = root })
		-- (it shrinks with distance; close up it stops at its design size, so it never fills the screen)
		bb:GetPropertyChangedSignal("AbsoluteSize"):Connect(function() sc.Scale = math.min(1, bb.AbsoluteSize.X / DW) end)
		-- the header: level chip + name (tap = the building's card, on your lots)
		local head = UI.pill({ Style = "dark", Size = UDim2.fromOffset(DW - 8, 50), Position = UDim2.fromOffset(4, 4), Transparency = 0.04, ZIndex = 2, Parent = root })
		local lvChip = UI.pill({ Color = "gold", Size = UDim2.fromOffset(62, 34), Position = UDim2.fromOffset(8, 8), StrokeTh = 2.5, ZIndex = 4, Parent = head })
		local lvText = UI.text({ Text = "LV 1", Size = UDim2.new(1, -8, 1, -8), Position = UDim2.fromOffset(4, 4), Max = 20, StrokeTh = 2, ZIndex = 6, Parent = lvChip })
		local nameText = UI.text({ Text = "", Size = UDim2.new(1, -92, 0, 32), Position = UDim2.fromOffset(80, 9), XAlign = Enum.TextXAlignment.Left, Max = 24, StrokeTh = 2.4, ZIndex = 4, Parent = head })
		local headBtn = new("TextButton", { Text = "", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 8, Parent = head })
		-- the action (own lots): a big button with the price
		local act, actHolder, actLabel = UI.button({ Name = "Act", Color = "green", Text = "UPGRADE", Sub = "$0", IconKey = "upgrades", Size = UDim2.fromOffset(DW - 8, 62),
			Position = UDim2.fromOffset(4, 60), Radius = 18, Max = 28, SubMax = 24, Depth = 5, ZIndex = 3, Parent = root })
		local actSub = act:FindFirstChild("Sub")
		local actIcon = act:FindFirstChild("Icon")
		-- (building now: the button shows the progress instead)
		local prog = UI.progress({ Color = "blue", Size = UDim2.fromOffset(DW - 20, 36), Position = UDim2.fromOffset(10, 72), Text = "", Max = 21, ZIndex = 4, Parent = root })
		prog.frame.Visible = false
		-- the income: a green pill under the rest
		local inc = UI.pill({ Color = "green", Size = UDim2.fromOffset(170, 44), AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -2), StrokeTh = 3, ZIndex = 3, Parent = root })
		UI.icon("cash", { Size = UDim2.fromOffset(52, 52), Position = UDim2.new(0, -14, 0.5, -27), ZIndex = 6, Parent = inc })
		local incText = UI.text({ Text = "", Scaled = false, TextSize = INC_TS, Size = UDim2.new(1, -46, 1, 0), Position = UDim2.fromOffset(40, 0), XAlign = Enum.TextXAlignment.Left, StrokeTh = 2.8, ZIndex = 5, Parent = inc })
		local bonus = UI.pill({ Color = "red", Size = UDim2.fromOffset(62, 26), Position = UDim2.new(1, -30, 0, -15), StrokeTh = 2.2, ZIndex = 8, Parent = inc })
		UI.text({ Text = "+25%", Size = UDim2.new(1, -8, 1, -4), Position = UDim2.fromOffset(4, 2), Max = 19, StrokeTh = 1.8, ZIndex = 10, Parent = bonus })
		bonus.Visible = false
		local p = { lot = m, model = model, bb = bb, root = root, head = head, lvText = lvText, name = nameText, act = act, actHolder = actHolder, actLabel = actLabel,
			actSub = actSub, actIcon = actIcon, prog = prog, inc = inc, incText = incText, bonus = bonus, padCF = padCF(pad), state = nil }
		headBtn.Activated:Connect(function() if p.own and api.openCard then UI.click() api.openCard(p.i) end end)
		act.Activated:Connect(function() if p.own then api.act(p) end end)
		m.Destroying:Connect(function() M.drop(m) end)
		posts[m] = p
		return p
	end
	function M.drop(m)
		local p = posts[m]
		if not p then return end
		posts[m] = nil
		p.bb:Destroy()
		p.model:Destroy()
		if p.disc then p.disc.model:Destroy() end
	end

	-- the glowing pad on the ground (own lots with something to do)
	local function makeDisc(p)
		local cf = p.padCF
		local g = new("Model", { Name = "Pad", Parent = p.model })
		local base = new("Part", { Name = "Base", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.26, PAD_R * 2 + 1, PAD_R * 2 + 1), CFrame = cf * CFrame.Angles(0, 0, math.rad(90)),
			Color = WHITE, Material = Enum.Material.SmoothPlastic, Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false, Parent = g })
		local disc = new("Part", { Name = "Disc", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.3, PAD_R * 2, PAD_R * 2), CFrame = cf * CFrame.new(0, 0.05, 0) * CFrame.Angles(0, 0, math.rad(90)),
			Color = STATE.go.disc, Material = Enum.Material.Neon, Transparency = 0.12, Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false, Parent = g })
		local glow = new("Part", { Name = "Glow", Shape = Enum.PartType.Cylinder, Size = Vector3.new(5, PAD_R * 2 - 0.4, PAD_R * 2 - 0.4), CFrame = cf * CFrame.new(0, 2.6, 0) * CFrame.Angles(0, 0, math.rad(90)),
			Color = STATE.go.disc, Material = Enum.Material.Neon, Transparency = 0.9, CastShadow = false, Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false, Parent = g })
		-- the arrow painted on the pad
		local top = new("Part", { Name = "Top", Size = Vector3.new(PAD_R * 1.5, 0.05, PAD_R * 1.5), CFrame = cf * CFrame.new(0, 0.24, 0), Transparency = 1, Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false, Parent = g })
		local sg = new("SurfaceGui", { Face = Enum.NormalId.Top, SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud, PixelsPerStud = 40, LightInfluence = 0, Parent = top })
		local ic = UI.icon("upgrades", { Size = UDim2.fromScale(1, 1), Parent = sg })
		ic.Rotation = 180
		p.disc = { model = g, disc = disc, glow = glow, icon = ic }
	end

	local function setState(p, state)
		if p.state == state then return end
		p.state = state
		local st = STATE[state]
		if not st then
			if p.disc then p.disc.model:Destroy() p.disc = nil end
			return
		end
		if not p.disc then makeDisc(p) end
		p.disc.disc.Color = st.disc
		p.disc.glow.Color = st.disc
		p.disc.glow.Transparency = state == "go" and 0.86 or 0.94
		UI.recolor(p.act, st.col)
	end

	-- the sign's layout: with an action row or info only
	local function layout(p, withAction)
		if p.withAction == withAction then return end
		p.withAction = withAction
		local h = withAction and DH or DH_SMALL
		p.root.Size = UDim2.fromOffset(DW, h)
		p.bb.Size = UDim2.new(STUDS, MINPX, STUDS * h / DW, MINPX * h / DW)
		p.actHolder.Visible = withAction
	end

	local function refresh()
		local districts = workspace:FindFirstChild("World") and workspace.World:FindFirstChild("Districts")
		if not districts then return end
		local mine = api.myDistrict()
		local L = lots()
		local cap = attr("Cap", 4)
		local money = attr("Money", 0)
		local busy = attr("Queue", 0) >= C.QueueSize
		local bl = attr("BuildLot", 0)
		local seen = {}
		for _, d in ipairs(districts:GetChildren()) do
			local lotsF = d:FindFirstChild("City") and d.City:FindFirstChild("Lots")
			for _, m in ipairs(lotsF and lotsF:GetChildren() or {}) do
				local i = m:GetAttribute("Lot")
				local own = m:GetAttribute("District") == mine
				local b = m:FindFirstChild("Building")
				local lv = b and (b:GetAttribute("Level") or 0) or 0
				local l = own and L[i]
				if own and l then lv = l.lv end
				-- a post for every lot with a building, and for every lot of yours
				if (lv > 0 or own) and m:FindFirstChild("Pad") then
					seen[m] = true
					local p = posts[m] or makePost(m)
					if p then
						p.own, p.i = own, i
						p.bb.MaxDistance = own and 170 or 110
						-- the header
						local name = lv > 0 and (C.StyleOf(lv, own and l and l.st or (b and b:GetAttribute("Style")) or 1)) or "EMPTY LOT"
						name = string.upper(tostring(name))
						if p.name.Text ~= name then p.name.Text = name end
						local lvT = lv > 0 and ("LV " .. lv) or "NEW"
						if p.lvText.Text ~= lvT then p.lvText.Text = lvT end
						-- the income
						local rate = m:GetAttribute("Rate") or 0
						p.inc.Visible = rate > 0
						if rate > 0 then
							local t = "+" .. C.Money(rate) .. "/s"
							if p.incText.Text ~= t then
								p.incText.Text = t
								p.inc.Size = UDim2.fromOffset(40 + UI.textWidth(t, INC_TS) + 18, 44)
							end
							local bo = m:GetAttribute("Bonus") == true
							if p.bonusOn ~= bo then
								p.bonusOn = bo
								p.bonus.Visible = bo
								local col = UI.Colors[bo and "gold" or "green"]
								local g = p.inc:FindFirstChildOfClass("UIGradient")
								if g then g.Color = ColorSequence.new(col[1], col[2]) end
							end
						end
						-- the action (yours)
						local state
						if own and l then
							if l.planned > l.lv then
								state = "busy"
								local building = bl == i
								p.actHolder.Visible = false
								p.prog.frame.Visible = true
								if building then
									local pr = math.clamp(attr("BuildProgress", 0), 0, 1)
									p.prog.set(math.max(0.06, pr), "BUILDING " .. math.floor(pr * 100) .. "%  ·  " .. math.ceil(attr("BuildLeft", 0)) .. "s")
								else
									p.prog.set(0.06, "IN THE QUEUE", true)
								end
								layout(p, true)
								p.actHolder.Visible = false
							elseif l.planned < cap then
								p.prog.frame.Visible = false
								local nx = C.Levels[l.planned + 1]
								local free = l.planned == 0 and i == 1 and attr("FreeFirst", false) ~= true
								local price = free and 0 or nx.cost
								p.price = price
								if busy then
									state = "full"
									p.actLabel.Text = "CREW BUSY"
									p.actSub.Text = "Queue " .. attr("Queue", 0) .. "/" .. C.QueueSize
								else
									state = (money >= price) and "go" or "need"
									p.actLabel.Text = l.planned == 0 and "BUILD" or "UPGRADE"
									p.actSub.Text = price == 0 and "FREE" or C.Money(price)
								end
								if p.actIcon then UI.setIcon(p.actIcon, l.planned == 0 and "mega" or "upgrades") end
								layout(p, true)
								p.actHolder.Visible = true
							else
								p.prog.frame.Visible = false
								layout(p, false)
							end
						else
							p.prog.frame.Visible = false
							layout(p, false)
						end
						setState(p, state)
					end
				end
			end
		end
		for m in pairs(posts) do if not seen[m] then M.drop(m) end end
	end
	task.spawn(function()
		while true do
			local ok, err = pcall(refresh)
			if not ok then warn("[LotPosts] " .. tostring(err)) end
			task.wait(0.25)
		end
	end)

	-- the pads: step on one of yours and its action happens (once; step off and on again for the next)
	local lastAct, lastWarn = 0, 0
	function api.act(p)
		if os.clock() - lastAct < 0.8 then return end
		if p.state == "go" then
			lastAct = os.clock()
			local ok = api.order(p.i)
			if ok and p.disc then
				local d = p.disc.disc
				local s0 = d.Size
				d.Size = s0 * Vector3.new(1, 1.25, 1.25)
				TweenService:Create(d, TweenInfo.new(0.35, Enum.EasingStyle.Back), { Size = s0 }):Play()
				if api.burst then api.burst(p.padCF.Position + Vector3.new(0, 1, 0)) end
			end
		elseif p.state == "need" and os.clock() - lastWarn > 2 then
			lastWarn = os.clock()
			api.toast("You need " .. C.Money(math.max(0, (p.price or 0) - attr("Money", 0))) .. " more", "red", 2, "cash")
		elseif p.state == "full" and os.clock() - lastWarn > 2 then
			lastWarn = os.clock()
			api.toast("Your crew is busy: the queue is full", "grey", 2, "crew")
		end
	end
	local on = {}
	RunService.Heartbeat:Connect(function()
		local t = os.clock()
		local char = plr.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		for m, p in pairs(posts) do
			local d = p.disc
			if d then
				-- a soft breathing glow on the pads you can use
				if p.state == "go" then d.glow.Transparency = 0.82 + math.sin(t * 3 + (p.i or 0)) * 0.06 end
				if hrp then
					local rel = hrp.Position - p.padCF.Position
					local inside = Vector2.new(rel.X, rel.Z).Magnitude < PAD_R + 0.6 and rel.Y > -1 and rel.Y < 6
					if inside and not on[m] then
						on[m] = true
						api.act(p)
					elseif not inside and on[m] and Vector2.new(rel.X, rel.Z).Magnitude > PAD_R + 1.5 then
						on[m] = nil
					end
				end
			end
		end
	end)

	-- where the tutorial points (the post of a lot of yours)
	function M.anchor(i)
		for m, p in pairs(posts) do
			if p.own and p.i == i then return p.model:FindFirstChild("Anchor") end
		end
		return nil
	end
end

return M
