-- BlockRise 2.0 - the HAMMERS window: your hammers (a grid; tap one: its card with EQUIP and LEVEL UP) and the
-- crates (cash or Gems; where paid random items aren't allowed every crate shows the hammer inside first: X-RAY).
-- Talks to the v1 HammerService (RemoteFunction HammerAction).
-- PREMIUM_UI (2026-10-18): segmented tabs, rarity tiles with a glow, a detail card with light rays, crate cards.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Hammers = require(ReplicatedStorage.Shared.Hammers)
local C = require(ReplicatedStorage.Shared.Config2)

local WHITE = Color3.new(1, 1, 1)

return function(body, ctx)
	local RF = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("HammerAction")
	local UI = ctx.UI
	local new = UI.new
	local tab = ctx.tab or "mine"
	local data
	local selected
	local render

	local function rarity(r) return Hammers.Rarities[r] or Hammers.Rarities[1] end

	-- the tabs, and the power of the hammer in your hand
	UI.tabs({ Parent = body, Items = { { "mine", "MY HAMMERS" }, { "crates", "CRATES" } }, Selected = tab, Color = "blue", Size = UDim2.fromOffset(400, 54), ZIndex = 3,
		OnSelect = function(id) tab = id render() end })
	local powerChip = UI.chip({ Color = "green", Icon = "up_power", Height = 34, TextSize = 19, Text = "", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -4, 0, 27), ZIndex = 4, Parent = body })
	powerChip.frame.Visible = false
	local content = new("Frame", { Name = "Content", BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 68), Size = UDim2.new(1, 0, 1, -68), ZIndex = 3, Parent = body })

	local function clear() for _, c in ipairs(content:GetChildren()) do c:Destroy() end end
	local function msg(t) clear() UI.text({ Text = t, Color = UI.Ink, Stroke = false, Size = UDim2.new(1, 0, 0, 40), Position = UDim2.fromScale(0, 0.4), Max = 28, ZIndex = 5, Parent = content }) end

	local function load()
		local ok, res = RF:InvokeServer("get")
		if ok and type(res) == "table" then data = res return true end
		msg(tostring(res or "Could not load your hammers"))
		return false
	end

	local function showPower()
		for _, it in ipairs(data and data.hammers or {}) do
			if it.id == data.equip and Hammers.ById[it.k] then
				powerChip.set("IN HAND: " .. Hammers.ById[it.k].name .. "  " .. Hammers.PowerLabel(it.k, it.lv or 1, it.pass))
				powerChip.frame.Visible = true
				return
			end
		end
		powerChip.frame.Visible = false
	end

	-- a hammer tile: rarity gradient, a glow, the picture, the name, the level
	local function tile(parent, it, size, onClick)
		local h = Hammers.ById[it.k]
		local rar = rarity(h and h.r or 1)
		local b = new("TextButton", { Name = it.id or it.k, Text = "", AutoButtonColor = false, BackgroundColor3 = WHITE, Size = size, LayoutOrder = it.order or 0, ZIndex = 5, Parent = parent })
		UI.corner(b, 18)
		local st = UI.stroke(b, 3)
		UI.gradient(b, UI.lighter(rar.color, 0.5), rar.color)
		UI.glow(b, WHITE, { Size = UDim2.fromScale(0.86, 0.7), Position = UDim2.fromScale(0.5, 0.4), ZIndex = 5 })
		UI.gloss(b, 12, { ZIndex = 6, Size = UDim2.new(1, -10, 0.3, 0), Position = UDim2.fromOffset(5, 3), From = 0.55, To = 0.95 })
		new("ImageLabel", { Name = "Pic", BackgroundTransparency = 1, Image = h and h.img or "", ScaleType = Enum.ScaleType.Fit, Size = UDim2.new(1, -20, 0.62, 0), Position = UDim2.new(0, 10, 0, 8), ZIndex = 7, Parent = b })
		-- the name on a dark strip
		local strip = new("Frame", { BackgroundColor3 = UI.Ink, BackgroundTransparency = 0.45, Size = UDim2.new(1, -10, 0, 26), Position = UDim2.new(0, 5, 1, -31), ZIndex = 7, Parent = b })
		UI.corner(strip, 10)
		UI.text({ Text = h and h.name or it.k, Size = UDim2.new(1, -8, 1, -6), Position = UDim2.fromOffset(4, 3), ZIndex = 8, Max = 17, StrokeTh = 1.8, Parent = strip })
		if it.lv then
			local lv = UI.pill({ Color = "navy", Size = UDim2.fromOffset(40, 22), Position = UDim2.fromOffset(5, 5), ZIndex = 9, StrokeTh = 2, Parent = b })
			UI.text({ Text = "Lv " .. it.lv, Size = UDim2.new(1, -8, 1, -4), Position = UDim2.fromOffset(4, 2), ZIndex = 11, Max = 15, StrokeTh = 1.5, Parent = lv })
		end
		local sc = new("UIScale", { Parent = b })
		b.MouseEnter:Connect(function() TweenService:Create(sc, TweenInfo.new(0.1), { Scale = 1.05 }):Play() end)
		b.MouseLeave:Connect(function() TweenService:Create(sc, TweenInfo.new(0.1), { Scale = 1 }):Play() end)
		if onClick then b.Activated:Connect(function() UI.click() onClick() end) end
		return b, st
	end

	-- MY HAMMERS ----------------------------------------------------------------------------------------------
	local function renderMine()
		clear()
		showPower()
		local list = {}
		for _, it in ipairs(data.hammers or {}) do
			if Hammers.ById[it.k] then table.insert(list, it) end
		end
		-- the one in your hand first, then by rarity and level
		table.sort(list, function(a, b)
			local ra, rb = Hammers.ById[a.k].r, Hammers.ById[b.k].r
			if a.id == data.equip then return true end
			if b.id == data.equip then return false end
			if ra ~= rb then return ra > rb end
			if (a.lv or 1) ~= (b.lv or 1) then return (a.lv or 1) > (b.lv or 1) end
			return a.id < b.id
		end)
		local PW = 280
		local well = UI.well({ Size = UDim2.new(1, -(PW + 16), 1, 0), Parent = content, ZIndex = 4 })
		local grid = new("ScrollingFrame", { BackgroundTransparency = 1, Size = UDim2.new(1, -8, 1, -8), Position = UDim2.fromOffset(4, 4), CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
			ScrollBarThickness = 8, ScrollBarImageColor3 = UI.Ink, BorderSizePixel = 0, ZIndex = 5, Parent = well })
		new("UIGridLayout", { CellSize = UDim2.fromOffset(110, 132), CellPadding = UDim2.fromOffset(12, 12), SortOrder = Enum.SortOrder.LayoutOrder, Parent = grid })
		UI.pad(grid, 10, 12, 14, 12)

		-- the detail card
		local panel = UI.panel({ Size = UDim2.new(0, PW, 1, 0), Position = UDim2.new(1, -PW, 0, 0), Radius = 20, StrokeTh = 3.5, Shadow = false, ZIndex = 4, Parent = content })
		local tiles = {}
		local function showPanel(it)
			for _, c in ipairs(panel:GetChildren()) do
				if c:GetAttribute("Detail") then c:Destroy() end
			end
			for id, t in pairs(tiles) do
				t.st.Color = id == it.id and Color3.fromRGB(255, 214, 60) or UI.Ink
				t.st.Thickness = id == it.id and 5 or 3
			end
			local function d(o) o:SetAttribute("Detail", true) return o end
			local h = Hammers.ById[it.k]
			local rar = rarity(h.r)
			local H = (ctx.h or 382) - 68 -- the panel's height in the window's units
			local stageH = math.clamp(H - 204, 60, 150)
			-- (a CanvasGroup: it clips the turning rays to its rounded shape; the outline is a frame over it)
			local stage = d(new("CanvasGroup", { BackgroundTransparency = 1, Size = UDim2.new(1, -20, 0, stageH), Position = UDim2.fromOffset(10, 10), ZIndex = 5, Parent = panel }))
			UI.corner(stage, 16)
			local sbg = new("Frame", { BackgroundColor3 = WHITE, Size = UDim2.fromScale(1, 1), ZIndex = 4, Parent = stage })
			UI.gradient(sbg, UI.lighter(rar.color, 0.55), rar.color)
			local outline = d(new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, -20, 0, stageH), Position = UDim2.fromOffset(10, 10), ZIndex = 8, Parent = panel }))
			UI.corner(outline, 16)
			UI.stroke(outline, 3)
			UI.rays(stage, WHITE, { Size = UDim2.fromOffset(stageH * 2.2, stageH * 2.2), ZIndex = 5, Strength = 0.6, Speed = 14 })
			UI.glow(stage, WHITE, { Size = UDim2.fromOffset(stageH * 0.95, stageH * 0.95), ZIndex = 5 })
			new("ImageLabel", { BackgroundTransparency = 1, Image = h.img, ScaleType = Enum.ScaleType.Fit, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromOffset(stageH - 10, stageH - 10), ZIndex = 7, Parent = stage })
			local y = stageH + 18
			d(UI.text({ Text = h.name, Scaled = false, TextSize = 24, Size = UDim2.new(1, -20, 0, 28), Position = UDim2.fromOffset(10, y), Color = UI.Ink, Stroke = false, ZIndex = 6, Parent = panel }))
			-- rarity + level chips, centred
			local row = d(new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, -20, 0, 28), Position = UDim2.fromOffset(10, y + 32), ZIndex = 6, Parent = panel }))
			new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, Padding = UDim.new(0, 8), Parent = row })
			local rc = UI.chip({ Color = "white", Height = 26, TextSize = 16, Text = rar.name:upper(), ZIndex = 6, Order = 1, Parent = row })
			rc.frame:FindFirstChildOfClass("UIGradient").Color = ColorSequence.new(UI.lighter(rar.color, 0.25), rar.color)
			UI.chip({ Color = "navy", Height = 26, TextSize = 16, Text = "LV " .. (it.lv or 1), ZIndex = 6, Order = 2, Parent = row })
			UI.chip({ Color = "green", Height = 26, TextSize = 16, Text = Hammers.PowerLabel(it.k, it.lv or 1, it.pass), ZIndex = 6, Order = 3, Parent = row })
			-- the buttons, from the bottom up
			local equipped = it.id == data.equip
			local _, eh = UI.button({ Name = "Equip", Color = equipped and "grey" or "blue", Text = equipped and "IN YOUR HAND" or "EQUIP", Size = UDim2.new(1, -24, 0, 46), AnchorPoint = Vector2.new(0, 1),
				Position = UDim2.new(0, 12, 1, -72), Max = 22, ZIndex = 6, Parent = panel,
				OnClick = function()
					if equipped then return end
					local ok, res = RF:InvokeServer("equip", it.id)
					if ok then data.equip = it.id ctx.toast("Equipped " .. h.name, "blue", nil, "shop") renderMine() else ctx.toast(tostring(res), "red") end
				end })
			d(eh)
			local cost = Hammers.LevelCost(it.k, it.lv or 1)
			local _, lh = UI.button({ Name = "Level", Color = cost and "green" or "grey", Text = cost and "LEVEL UP" or "MAX LEVEL", Sub = cost and C.Money(cost) or nil, Shimmer = cost ~= nil,
				Size = UDim2.new(1, -24, 0, 54), AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 12, 1, -12), Max = 24, ZIndex = 6, Parent = panel,
				OnClick = function()
					if not cost then return end
					local ok, res = RF:InvokeServer("levelup", it.id)
					if ok then it.lv = res and res.lv or ((it.lv or 1) + 1) UI.coin() renderMine() else ctx.toast(tostring(res), "red") end
				end })
			d(lh)
		end
		for i, it in ipairs(list) do
			it.order = i
			local t, st = tile(grid, it, UDim2.fromOffset(110, 132), function() selected = it.id showPanel(it) end)
			tiles[it.id] = { st = st }
			if it.id == data.equip then
				local tag = UI.pill({ Color = "green", Size = UDim2.fromOffset(50, 22), Position = UDim2.new(1, -55, 0, 5), ZIndex = 9, StrokeTh = 2, Parent = t })
				UI.text({ Text = "HAND", Size = UDim2.new(1, -8, 1, -4), Position = UDim2.fromOffset(4, 2), ZIndex = 11, Max = 14, StrokeTh = 1.5, Parent = tag })
			end
		end
		local first = list[1]
		for _, it in ipairs(list) do if it.id == selected then first = it end end
		if first then showPanel(first) end
	end

	-- CRATES --------------------------------------------------------------------------------------------------
	local function showReveal(res)
		local h = Hammers.ById[res.key]
		if not h then return end
		local rar = rarity(res.r or h.r)
		local f = new("CanvasGroup", { BackgroundColor3 = Color3.fromRGB(14, 20, 52), BackgroundTransparency = 0.12, Size = UDim2.fromScale(1, 1), ZIndex = 40, Parent = content })
		UI.corner(f, 18)
		UI.rays(f, rar.color, { Size = UDim2.fromOffset(620, 620), Position = UDim2.fromScale(0.5, 0.42), ZIndex = 41, Strength = 0.35, Count = 10, Speed = 24 })
		UI.glow(f, rar.color, { Size = UDim2.fromOffset(250, 250), Position = UDim2.fromScale(0.5, 0.42), ZIndex = 42 })
		local img = new("ImageLabel", { BackgroundTransparency = 1, Image = h.img, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.42), Size = UDim2.fromOffset(190, 190),
			ScaleType = Enum.ScaleType.Fit, ZIndex = 43, Parent = f })
		UI.pop(img, 0.2)
		UI.text({ Text = (res.new and "NEW!  " or "") .. h.name, Size = UDim2.new(1, -40, 0, 42), Position = UDim2.new(0, 20, 0.72, 0), ZIndex = 44, Max = 36, StrokeTh = 3.2, Shadow = 3, Parent = f })
		local rc = UI.chip({ Color = "white", Height = 30, TextSize = 19, Text = rar.name:upper(), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0.72, 50), ZIndex = 44, Parent = f })
		rc.frame:FindFirstChildOfClass("UIGradient").Color = ColorSequence.new(UI.lighter(rar.color, 0.25), rar.color)
		UI.text({ Text = "Tap to continue", Scaled = false, TextSize = 16, Size = UDim2.new(1, 0, 0, 20), Position = UDim2.new(0, 0, 1, -28), Color = Color3.fromRGB(190, 200, 235), StrokeTh = 1.5, ZIndex = 44, Parent = f })
		UI.coin()
		RF:InvokeServer("seen", res.id)
		local close = new("TextButton", { Text = "", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 50, Parent = f })
		close.Activated:Connect(function() f:Destroy() end)
		task.delay(5, function() if f.Parent then f:Destroy() end end)
	end

	local function renderCrates()
		clear()
		showPower()
		local reb = data.rebirths or 0
		local row = new("ScrollingFrame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.X,
			ScrollingDirection = Enum.ScrollingDirection.X, ScrollBarThickness = 8, ScrollBarImageColor3 = UI.Ink, BorderSizePixel = 0, ZIndex = 4, Parent = content })
		new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 16), SortOrder = Enum.SortOrder.LayoutOrder, Parent = row })
		UI.pad(row, 6, 6, 6, 16)
		local order = 0
		for _, c in ipairs(Hammers.Crates) do
			-- the crates you can buy here: your zone's Supply Crate (cash) and the Gem crates
			local show = (c.cash and c.id == (data.supplyId or "supply")) or (c.gems and not c.soon)
			if show then
				order += 1
				local open = Hammers.CrateOpen(c, reb)
				local card = new("Frame", { BackgroundColor3 = WHITE, Size = UDim2.new(0, 200, 1, -6), LayoutOrder = order, ZIndex = 5, ClipsDescendants = false, Parent = row })
				UI.corner(card, 20)
				UI.stroke(card, 3.5)
				UI.gradient(card, UI.lighter(c.color, 0.6), c.color)
				UI.gloss(card, 14, { ZIndex = 5, Size = UDim2.new(1, -12, 0, 60), Position = UDim2.fromOffset(6, 4), From = 0.5, To = 0.95 })
				-- from the bottom up: the button, the price, the name; the crate fills the rest (with its rays)
				local stage = new("CanvasGroup", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, -128), ZIndex = 5, Parent = card })
				UI.corner(stage, 20)
				UI.rays(stage, WHITE, { Size = UDim2.fromOffset(300, 300), Position = UDim2.fromScale(0.5, 0.52), ZIndex = 5, Strength = 0.7, Speed = 12 })
				UI.glow(stage, WHITE, { Size = UDim2.fromOffset(140, 140), Position = UDim2.fromScale(0.5, 0.52), ZIndex = 5 })
				local pic = new("ImageLabel", { BackgroundTransparency = 1, Image = c.image or "", ScaleType = Enum.ScaleType.Fit, AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.new(0.84, 0, 1, -146),
					Position = UDim2.new(0.5, 0, 0.5, -62), ZIndex = 7, Parent = card })
				new("UISizeConstraint", { MaxSize = Vector2.new(176, 170), Parent = pic })
				UI.text({ Text = c.name, Size = UDim2.new(1, -16, 0, 26), AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 8, 1, -100), ZIndex = 7, Max = 20, StrokeTh = 2.4, Parent = card })
				local owned = (data.crates and data.crates[c.id]) or 0
				local x = data.xray and data.xray[c.id]
				if x and Hammers.ById[x.key] then
					-- X-RAY: the hammer inside (a strip at the foot of the picture)
					local xh = Hammers.ById[x.key]
					local xr = new("Frame", { BackgroundColor3 = UI.Ink, BackgroundTransparency = 0.35, Size = UDim2.new(1, -16, 0, 24), AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 8, 1, -130), ZIndex = 8, Parent = card })
					UI.corner(xr, 10)
					UI.text({ Text = "INSIDE: " .. xh.name, Size = UDim2.new(1, -10, 1, -6), Position = UDim2.fromOffset(5, 3), ZIndex = 9, Color = UI.lighter(rarity(x.r).color, 0.3), StrokeTh = 1.6, Max = 15, Parent = xr })
				end
				local priceText = owned > 0 and ("You have " .. owned) or (c.cash and C.Money(Hammers.CratePrice(c) or 0) or C.Fmt(c.gems))
				UI.chip({ Color = owned > 0 and "blue" or (c.cash and "green" or "purple"), Icon = owned > 0 and nil or (c.cash and "cash" or "gem"), Height = 28, TextSize = 18, Text = priceText,
					AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 8, 1, -68), ZIndex = 7, Parent = card })
				local label = not open and ("REBIRTH " .. tostring(Hammers.CrateRebirth(c))) or (owned > 0 and "OPEN" or "BUY & OPEN")
				UI.button({ Name = "Buy", Color = open and "green" or "grey", Text = label, Size = UDim2.new(1, -20, 0, 48), AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 10, 1, -14),
					Max = 22, ZIndex = 7, Shimmer = open, Parent = card,
					OnClick = function()
						if not open then return end
						local ok, res
						if owned > 0 then
							ok, res = RF:InvokeServer("open", c.id)
						elseif x then
							ok, res = RF:InvokeServer("buy", c.id, { n = 1, expect = x.key })
						else
							ok, res = RF:InvokeServer("buy", c.id, 1)
							if ok then ok, res = RF:InvokeServer("open", c.id) end
						end
						if ok and type(res) == "table" and res.key then
							load()
							renderCrates()
							showReveal(res)
						elseif not ok then
							ctx.toast(tostring(res), "red")
							if res == "xray" then load() renderCrates() end
						end
					end })
			end
		end
	end

	render = function()
		if not data then msg("Loading...") if not load() then return end end
		if tab == "mine" then renderMine() else renderCrates() end
	end
	render()
end
