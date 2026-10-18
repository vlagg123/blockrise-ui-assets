-- BlockRise 2.0 - the GIFTS window (GIFTS_V1): FREE GIFTS (8 per visit, each opens after some minutes of play) and
-- DAILY (a 7-day streak). The server decides (Remotes.Gifts); this draws the boxes, the timers and the claims.
-- Everything fits the window without scrolling on a normal screen (the cells take the height there is).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local C = require(ReplicatedStorage.Shared.Config2)

local WHITE = Color3.new(1, 1, 1)
local C3 = Color3.fromRGB

local function clock(s)
	s = math.max(0, math.ceil(s))
	if s >= 3600 then return string.format("%d:%02d:%02d", s // 3600, (s % 3600) // 60, s % 60) end
	return string.format("%d:%02d", s // 60, s % 60)
end

return function(body, ctx)
	local UI = ctx.UI
	local new = UI.new
	local RF = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Gifts")
	local tab = ctx.tab or "free"
	local render
	local state, fetchedAt
	local busy = false
	UI.tabs({ Parent = body, Items = { { "free", "FREE GIFTS" }, { "daily", "DAILY" } }, Selected = tab, Color = "pink", Size = UDim2.fromOffset(420, 54), ZIndex = 3,
		OnSelect = function(id) tab = id render() end })
	local hint
	local function setHint(icon, text)
		if hint then hint.frame:Destroy() end
		hint = UI.chip({ Color = "pink", Icon = icon, Height = 34, TextSize = 18, Text = text, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -4, 0, 27), ZIndex = 4, Parent = body })
	end
	local content = new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 68), Size = UDim2.new(1, 0, 1, -68), ZIndex = 3, Parent = body })
	local contentH = (ctx.h or 442) - 68
	local timers = {}

	local function load()
		local ok, ok2, res = pcall(function() return RF:InvokeServer("state") end)
		if ok and ok2 and type(res) == "table" then state = res fetchedAt = os.clock() return true end
		return false
	end
	local function elapsed() return state.elapsed + (os.clock() - fetchedAt) end

	-- the picture and the words of a reward
	local function rewardIcon(r) return r.kind == "cash" and "cash" or (r.kind == "gems" and "gem" or "store") end
	local function rewardText(r)
		if r.kind == "cash" then return C.Money(r.amount) end
		if r.kind == "gems" then return r.amount .. " Gems" end
		return r.crateName or "Crate"
	end

	-- a claim: the reward flies from its box to the money / the gems / HAMMERS, and a toast says what it was
	local function claimed(r, from)
		if ctx.fly and from then ctx.fly(rewardIcon(r), from, r.kind) else UI.coin() end
		ctx.toast("You got " .. rewardText(r) .. "!", r.kind == "gems" and "purple" or (r.kind == "cash" and "green" or "gold"), 3, rewardIcon(r))
	end

	-- a green tick in a circle (two bars: the dark outline under, the white over, so the joint stays clean)
	local function tick(parent, pos, s, z)
		local c = new("Frame", { Name = "Tick", BackgroundColor3 = WHITE, AnchorPoint = Vector2.new(0.5, 0.5), Position = pos, Size = UDim2.fromOffset(s, s), ZIndex = z, Parent = parent })
		UI.corner(c, s / 2)
		UI.stroke(c, 3)
		UI.gradient(c, UI.Colors.green[1], UI.Colors.green[2])
		local a, b, d = Vector2.new(0.27, 0.53) * s, Vector2.new(0.44, 0.7) * s, Vector2.new(0.75, 0.33) * s
		local function bar(p1, p2, th, col, zz)
			local m, v = (p1 + p2) / 2, p2 - p1
			local f = new("Frame", { BackgroundColor3 = col, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(m.X, m.Y), Size = UDim2.fromOffset(v.Magnitude + th, th),
				Rotation = math.deg(math.atan2(v.Y, v.X)), ZIndex = zz, Parent = c })
			UI.corner(f, th / 2)
		end
		local th = math.floor(s * 0.15)
		bar(a, b, th + 5, UI.Ink, z + 1)
		bar(b, d, th + 5, UI.Ink, z + 1)
		bar(a, b, th, WHITE, z + 2)
		bar(b, d, th, WHITE, z + 2)
		return c
	end

	-- a gift box tile (w x h): colour by reward, the reward, then a timer / CLAIM / claimed
	local function tile(parent, order, r, opts)
		local h = opts.h
		local col = r.kind == "cash" and { C3(190, 255, 170), C3(60, 190, 90) } or (r.kind == "gems" and { C3(226, 196, 255), C3(140, 90, 240) } or { C3(255, 236, 170), C3(255, 160, 40) })
		local f = new("Frame", { BackgroundColor3 = WHITE, Size = UDim2.fromOffset(opts.w or 166, h), LayoutOrder = order, ZIndex = 5, Parent = parent })
		UI.corner(f, 18)
		UI.stroke(f, opts.current and 5 or 3, opts.current and C3(255, 214, 60) or UI.Ink)
		UI.gradient(f, col[1], col[2])
		local sm = opts.small
		local cy = math.floor(h * (sm and 0.34 or 0.33))
		local isz = sm and 68 or math.min(78, math.floor(h * 0.44))
		UI.glow(f, WHITE, { Size = UDim2.fromOffset(isz + 30, isz + 30), Position = UDim2.new(0.5, 0, 0, cy), ZIndex = 5 })
		UI.gloss(f, 12, { ZIndex = 6, Size = UDim2.new(1, -10, 0, 34), Position = UDim2.fromOffset(5, 3), From = 0.5, To = 0.95 })
		if opts.label then
			local lb = UI.pill({ Color = opts.labelColor or "navy", Size = UDim2.fromOffset(70, 24), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, -10), ZIndex = 9, StrokeTh = 2, Parent = f })
			UI.text({ Text = opts.label, Size = UDim2.new(1, -8, 1, -6), Position = UDim2.fromOffset(4, 3), ZIndex = 11, Max = 15, StrokeTh = 1.5, Parent = lb })
		end
		local ic = UI.icon(opts.closed and "gift" or rewardIcon(r), { Size = UDim2.fromOffset(isz, isz), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0, cy), ZIndex = 7, Parent = f })
		if opts.closed then ic.Rotation = -6 end
		if sm then
			-- two lines for the long crate names
			UI.text({ Text = rewardText(r), Size = UDim2.new(1, -10, 0, 40), Position = UDim2.fromOffset(5, cy + 40), ZIndex = 7, Max = 17, Wrap = true, StrokeTh = 2, Parent = f })
		else
			UI.text({ Text = rewardText(r), Size = UDim2.new(1, -12, 0, 24), Position = UDim2.fromOffset(6, h - 78), ZIndex = 7, Max = 19, StrokeTh = 2.2, Parent = f })
		end
		if opts.done then
			local veil = new("Frame", { BackgroundColor3 = UI.Ink, BackgroundTransparency = 0.55, Size = UDim2.fromScale(1, 1), ZIndex = 8, Parent = f })
			UI.corner(veil, 18)
			tick(f, UDim2.new(0.5, 0, 0, cy), sm and 46 or 54, 10)
			UI.chip({ Color = "grey", Height = 28, TextSize = 16, Text = "CLAIMED", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -10), ZIndex = 9, Parent = f })
		elseif opts.onClaim then
			UI.button({ Name = "Claim", Color = "green", Text = "CLAIM", Size = UDim2.new(1, -20, 0, 38), AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 10, 1, -9),
				Max = 20, ZIndex = 7, Shimmer = true, Depth = 4, Parent = f, OnClick = function() opts.onClaim(f) end })
			UI.pop(ic, 1.25)
		elseif opts.timer then
			local ch = UI.chip({ Color = "dark", Icon = "timer", Height = 30, TextSize = 17, Text = clock(opts.timer()), AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 8, 1, -12), ZIndex = 7, Parent = f })
			table.insert(timers, { chip = ch, left = opts.timer, ready = opts.ready })
		elseif opts.current then
			UI.chip({ Color = "pink", Height = 28, TextSize = 16, Text = "TODAY!", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -10), ZIndex = 9, Parent = f })
		end
		return f
	end

	local function clear()
		timers = {}
		for _, c in ipairs(content:GetChildren()) do c:Destroy() end
	end

	local function renderFree()
		clear()
		local well = UI.well({ Size = UDim2.fromScale(1, 1), ZIndex = 4, Parent = content })
		local grid = new("ScrollingFrame", { BackgroundTransparency = 1, Size = UDim2.new(1, -8, 1, -8), Position = UDim2.fromOffset(4, 4), CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
			ScrollBarThickness = 8, ScrollBarImageColor3 = UI.Ink, BorderSizePixel = 0, ZIndex = 5, Parent = well })
		-- two rows of four in the height there is (a scroll only on a very small screen)
		local cellH = math.clamp(math.floor((contentH - 8 - 14 - 8 - 16) / 2), 140, 180)
		new("UIGridLayout", { CellSize = UDim2.fromOffset(166, cellH), CellPadding = UDim2.fromOffset(14, 16), SortOrder = Enum.SortOrder.LayoutOrder, HorizontalAlignment = Enum.HorizontalAlignment.Center, Parent = grid })
		UI.pad(grid, 6, 14, 14, 8)
		local nextLeft
		for i, r in ipairs(state.list) do
			local left = function() return r.t - elapsed() end
			local ready = left() <= 0
			if not r.claimed and not ready and (not nextLeft or left() < nextLeft) then nextLeft = left() end
			tile(grid, i, r, {
				h = cellH, done = r.claimed, closed = not r.claimed and not ready, timer = (not r.claimed and not ready) and left or nil,
				ready = function() return left() <= 0 end,
				onClaim = (not r.claimed and ready) and function(f)
					if busy then return end
					busy = true
					local ok, res = RF:InvokeServer("claim", i)
					if ok then claimed(res, f) load() if content.Parent then renderFree() end else ctx.toast(tostring(res), "red") end
					busy = false
				end or nil,
			})
		end
		setHint("timer", nextLeft and ("NEXT GIFT IN " .. clock(nextLeft)) or "ALL GIFTS OPEN!")
		if nextLeft then
			local t0, n0 = os.clock(), nextLeft
			table.insert(timers, { chip = hint, left = function() return n0 - (os.clock() - t0) end, prefix = "NEXT GIFT IN " })
		end
	end

	local function renderDaily()
		clear()
		local d = state.daily
		local well = UI.well({ Size = UDim2.fromScale(1, 1), ZIndex = 4, Parent = content })
		UI.text({ Text = d.claimed and "Come back tomorrow for day " .. ((d.day % #d.list) + 1) .. "!" or "Play every day for bigger rewards! Miss a day and it starts again.", Max = 21,
			Size = UDim2.new(1, -40, 0, 30), Position = UDim2.fromOffset(20, 12), Color = UI.Ink, Stroke = false, ZIndex = 6, Parent = well })
		-- the 7 days: as tall as there is room for above the button
		local tileH = math.clamp(contentH - 62 - 108, 170, 190)
		local row = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, -20, 0, tileH), Position = UDim2.fromOffset(10, 62), ZIndex = 5, Parent = well })
		new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8), HorizontalAlignment = Enum.HorizontalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder, Parent = row })
		local todayTile
		for i, r in ipairs(d.list) do
			local done = i < d.day or (i == d.day and d.claimed)
			local cur = i == d.day and not d.claimed
			local f = tile(row, i, r, { w = 98, h = tileH, label = "DAY " .. i, labelColor = i == #d.list and "gold" or (cur and "pink" or "navy"), done = done, current = cur, small = true })
			if cur then todayTile = f end
		end
		-- the claim (or the time until tomorrow)
		if d.claimed then
			local ch = UI.chip({ Color = "dark", Icon = "timer", Height = 40, TextSize = 21, Text = "NEXT IN " .. clock(d.nextIn), AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 10, 1, -26), ZIndex = 7, Parent = well })
			local t0 = os.clock()
			table.insert(timers, { chip = ch, left = function() return d.nextIn - (os.clock() - t0) end, prefix = "NEXT IN " })
		else
			UI.button({ Name = "ClaimDaily", Color = "green", Text = "CLAIM DAY " .. d.day, IconKey = "daily", Size = UDim2.fromOffset(330, 62), AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -20),
				Shimmer = true, Max = 28, ZIndex = 7, Parent = well,
				OnClick = function()
					if busy then return end
					busy = true
					local ok, res = RF:InvokeServer("daily")
					if ok then claimed(res, todayTile) load() if content.Parent then renderDaily() end else ctx.toast(tostring(res), "red") end
					busy = false
				end })
		end
		setHint("daily", d.claimed and ("STREAK: DAY " .. d.day) or ("DAY " .. d.day .. " IS READY!"))
	end

	render = function()
		if not state and not load() then
			UI.text({ Text = "Loading...", Color = UI.Ink, Stroke = false, Size = UDim2.new(1, 0, 0, 40), Position = UDim2.fromScale(0, 0.4), Max = 28, ZIndex = 5, Parent = content })
			return
		end
		if tab == "daily" then renderDaily() else renderFree() end
	end
	render()

	-- the timers tick; a gift that opens redraws the grid
	local acc = 0
	local conn
	conn = RunService.Heartbeat:Connect(function(dt)
		if not content.Parent then conn:Disconnect() return end -- (the window shows something else now)
		acc += dt
		if acc < 0.5 then return end
		acc = 0
		for _, t in ipairs(timers) do
			local left = t.left()
			if t.ready and t.ready() then
				if tab == "free" and not busy then renderFree() end
				return
			end
			t.chip.set((t.prefix or "") .. clock(left))
		end
	end)
end
