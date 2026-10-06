-- BlockRise Empire - menu building blocks, front-page simulator style: light item tiles in a grid (rarity-coloured art
-- with light rays, big 3D icon, name, 1-2 short chips, a chunky price button), wide offer banners, light list rows,
-- section titles. Everything is drawn with UIKit's 9-slice skin, so every window looks the same.
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UI = require(RS.Shared:WaitForChild("UIKit"))
local Icons = require(RS.Shared:WaitForChild("Icons"))
local T = UI.Theme
local new = UI.new

local K = {}
K.TILE = Color3.fromRGB(248, 248, 255)     -- light card
K.DIM = Color3.fromRGB(212, 214, 232)      -- locked card
K.DARK = T.dark                             -- text on light cards
K.SUB = Color3.fromRGB(104, 98, 140)        -- second line on light cards
K.NOTE = Color3.fromRGB(208, 214, 246)      -- small text on the window body
K.GREEN = Color3.fromRGB(70, 214, 96)
K.GOLD = Color3.fromRGB(255, 196, 46)
K.LOCK = Color3.fromRGB(122, 128, 186)
K.RAR = {
	common = Color3.fromRGB(150, 156, 178), uncommon = Color3.fromRGB(80, 200, 100), rare = Color3.fromRGB(60, 150, 255),
	epic = Color3.fromRGB(165, 90, 255), legend = Color3.fromRGB(255, 170, 30), mythic = Color3.fromRGB(255, 70, 120),
}
-- art for buildings (contracts, properties) until each one has its own icon
K.BUILDING = { fence = "site", shed = "home", garage = "garage", house = "home", shop = "home", villa = "suburbs", warehouse = "company",
	apartments = "company", luxvilla = "suburbs", distcenter = "contract", office = "downtown", hotel = "company", skyscraper = "downtown",
	hq = "company", spire = "mega" }
-- rarity by position in a tier list (tools, gear...)
function K.rarityOf(i, n)
	local f = (i - 1) / math.max(1, n - 1)
	if f < 0.15 then return "common", "COMMON" elseif f < 0.35 then return "uncommon", "UNCOMMON" elseif f < 0.55 then return "rare", "RARE"
	elseif f < 0.75 then return "epic", "EPIC" elseif f < 0.92 then return "legend", "LEGEND" else return "mythic", "MYTHIC" end
end

-- slow spinning light rays behind featured art (one loop for all of them)
local spinners = setmetatable({}, { __mode = "k" })
RunService.Heartbeat:Connect(function()
	local r = (os.clock() * 14) % 360
	for im in pairs(spinners) do
		if im.Parent then im.Rotation = r else spinners[im] = nil end
	end
end)

local function text(props)
	local l = new("TextLabel", { BackgroundTransparency = 1, Font = T.body, TextColor3 = K.DARK, TextSize = 16, ZIndex = 3,
		TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Center, RichText = true })
	local maxSize
	for k, v in pairs(props) do
		if k == "Max" then maxSize = v elseif k ~= "Parent" and k ~= "Stroke" then l[k] = v end
	end
	if props.Stroke then new("UIStroke", { Thickness = props.Stroke, Color = T.ink, LineJoinMode = Enum.LineJoinMode.Round, Parent = l }) end
	if maxSize then
		-- shrink to fit instead of spilling out
		new("UITextSizeConstraint", { MaxTextSize = maxSize, MinTextSize = math.min(11, maxSize), Parent = l })
		l.TextScaled = true
	end
	l.Parent = props.Parent
	return l
end
K.text = text

-- art: an atlas icon, or an emoji when the item has no icon yet
function K.art(parent, icon, size, z)
	if type(icon) == "string" and icon:find("^rbxassetid://") then
		-- an image of its own (the hammers rendered in Blender)
		return new("ImageLabel", { Name = "Icon", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = size or UDim2.fromScale(0.95, 0.95),
			BackgroundTransparency = 1, Image = icon, ScaleType = Enum.ScaleType.Fit, ZIndex = z or 6, Parent = parent })
	end
	if Icons.has(icon) then
		return Icons.make(icon, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = size or UDim2.fromScale(0.95, 0.95), ZIndex = z or 6, Parent = parent })
	end
	return new("TextLabel", { Name = "Icon", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.52), Size = size or UDim2.fromScale(0.7, 0.7),
		BackgroundTransparency = 1, Text = icon or "?", TextScaled = true, Font = Enum.Font.SourceSans, ZIndex = z or 6, Parent = parent })
end

-- coloured art box with a gradient, light rays, a soft glow, gloss and the icon on top
function K.artBox(parent, icon, color, props)
	props = props or {}
	color = color or T.blue
	-- clips its rays and glow: nothing from the art ever reaches the tile around it
	local box = UI.slice("tile", { Name = "Art", ImageColor3 = Color3.new(1, 1, 1), ZIndex = 2, ClipsDescendants = true, Parent = parent })
	for k, v in pairs(props) do if k ~= "Spin" and k ~= "Dim" and k ~= "IconScale" and k ~= "Custom" then box[k] = v end end
	local top, bot = color:Lerp(Color3.new(1, 1, 1), 0.3), color:Lerp(Color3.new(0, 0, 0), 0.22)
	if props.Dim then
		local g = Color3.fromRGB(150, 152, 172)
		top, bot = top:Lerp(g, 0.75), bot:Lerp(g, 0.75)
	end
	new("UIGradient", { Color = ColorSequence.new(top, bot), Rotation = 90, Parent = box })
	-- rays and glow are square and fade out before their edges, so they stay inside the box
	local rays = UI.slice("rays", { Name = "Rays", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(1, 1),
		ImageTransparency = props.Dim and 0.85 or 0.45, ZIndex = 3, Parent = box })
	new("UIAspectRatioConstraint", { AspectRatio = 1, DominantAxis = Enum.DominantAxis.Height, Parent = rays })
	if props.Spin then spinners[rays] = true end
	local glow = UI.slice("glow", { Name = "Glow", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.85, 0.85),
		ImageTransparency = props.Dim and 0.85 or 0.5, ZIndex = 3, Parent = box })
	new("UIAspectRatioConstraint", { AspectRatio = 1, DominantAxis = Enum.DominantAxis.Height, Parent = glow })
	UI.slice("gloss", { Name = "Gloss", ImageTransparency = 0.45, ZIndex = 4, Parent = box })
	if props.Custom then
		-- the caller draws its own art (a 3D preview...) on top of the rays
		return box, props.Custom(box)
	end
	local s = props.IconScale or 1
	local pic = K.art(box, icon, UDim2.fromScale(s, s), 6)
	new("UIAspectRatioConstraint", { AspectRatio = 1, DominantAxis = Enum.DominantAxis.Height, Parent = pic })
	if props.Dim then
		if pic:IsA("ImageLabel") then pic.ImageColor3 = Color3.fromRGB(170, 170, 186); pic.ImageTransparency = 0.1 else pic.TextTransparency = 0.35 end
	end
	return box, pic
end

-- section title on the window body (+ an optional short note on the same line)
function K.section(parent, order, title, color, note)
	local f = new("Frame", { Name = "Section", Size = UDim2.new(1, 0, 0, 32), BackgroundTransparency = 1, LayoutOrder = order, ZIndex = 2, Parent = parent })
	new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 12), VerticalAlignment = Enum.VerticalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder, Parent = f })
	text({ Size = UDim2.fromOffset(0, 32), AutomaticSize = Enum.AutomaticSize.X, Text = title, Font = T.chunky, TextSize = 25, TextColor3 = color or Color3.new(1, 1, 1),
		Stroke = 3, LayoutOrder = 1, Parent = f })
	if note then
		text({ Size = UDim2.fromOffset(0, 24), AutomaticSize = Enum.AutomaticSize.X, Text = note, TextSize = 16, TextColor3 = K.NOTE, LayoutOrder = 2, Parent = f })
	end
	return f
end

-- short tip line on the window body
function K.note(parent, order, msg)
	local f = new("Frame", { Name = "Note", Size = UDim2.new(1, 0, 0, 24), BackgroundTransparency = 1, LayoutOrder = order, ZIndex = 2, Parent = parent })
	text({ Size = UDim2.fromScale(1, 1), Text = msg, TextSize = 16, TextColor3 = K.NOTE, TextXAlignment = Enum.TextXAlignment.Center, Max = 16, Parent = f })
	return f
end

-- a grid that grows with its tiles
function K.grid(parent, order, cols, cellH, gap)
	gap = gap or 12
	local f = new("Frame", { Name = "Grid", Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, LayoutOrder = order, ZIndex = 2, Parent = parent })
	local g = new("UIGridLayout", { CellSize = UDim2.new(1 / cols, -math.ceil(gap * (cols - 1) / cols), 0, cellH), CellPadding = UDim2.fromOffset(gap, gap),
		SortOrder = Enum.SortOrder.LayoutOrder, HorizontalAlignment = Enum.HorizontalAlignment.Center, Parent = f })
	-- a short list (fewer tiles than columns) uses fewer, wider columns (at least 3) and sits in the middle
	local function fit()
		local n = 0
		for _, ch in ipairs(f:GetChildren()) do if ch:IsA("GuiObject") then n += 1 end end
		local c = math.min(cols, math.max(n, math.min(3, cols)))
		g.CellSize = UDim2.new(1 / c, -math.ceil(gap * (c - 1) / c), 0, cellH)
	end
	f.ChildAdded:Connect(function() task.defer(fit) end)
	f.ChildRemoved:Connect(function() task.defer(fit) end)
	return f
end

-- small coloured tag (stats, rarity, OWNED...)
-- props.Pic = a picture in front of the text (rbxassetid or atlas icon name: materials, blueprints...)
function K.chip(parent, label, color, props)
	local c = UI.slice("pill", { Name = "Chip", Size = UDim2.fromOffset(0, 26), AutomaticSize = Enum.AutomaticSize.X, SliceScale = 0.36, ImageColor3 = color or T.blue, ZIndex = 5, Parent = parent })
	local pic = props and props.Pic
	for k, v in pairs(props or {}) do if k ~= "Pic" then c[k] = v end end
	new("UIPadding", { PaddingLeft = UDim.new(0, pic and 4 or 9), PaddingRight = UDim.new(0, 9), Parent = c })
	if pic then
		local h = new("Frame", { Name = "Pic", AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 0, 0.5, 0), Size = UDim2.fromOffset(25, 25), BackgroundTransparency = 1, ZIndex = 6, Parent = c })
		K.art(h, pic, UDim2.fromScale(1.12, 1.12), 6)
	end
	text({ Position = UDim2.fromOffset(pic and 26 or 0, 2), Size = UDim2.new(0, 0, 1, 0), AutomaticSize = Enum.AutomaticSize.X, Text = label, Font = T.chunky, TextSize = 15,
		TextColor3 = Color3.new(1, 1, 1), Stroke = 2, TextYAlignment = Enum.TextYAlignment.Center, ZIndex = 6, Parent = c })
	return c
end

-- action button with a busy guard (the click runs once at a time)
function K.button(parent, label, color, props, onClick)
	props = props or {}
	local b = UI.button(label, color or K.GREEN, nil, { Size = UDim2.new(1, 0, 0, 48), TextSize = props.TextSize or 23, ZIndex = 7, Icon = props.Icon, Shine = props.Shine })
	for k, v in pairs(props) do if k ~= "Icon" and k ~= "Shine" and k ~= "TextSize" then b[k] = v end end
	b.Parent = parent
	local busy = false
	if onClick then
		b.Activated:Connect(function()
			if busy then return end
			busy = true
			task.spawn(function()
				local ok, err = pcall(onClick, b)
				if not ok then warn("[menu] " .. tostring(err)) end
				busy = false
			end)
		end)
	end
	return b
end

-- status in place of a button (EQUIPPED, MAX, locked...)
function K.status(parent, label, color, props)
	local s = UI.slice("pill", { Name = "Status", Size = UDim2.new(1, 0, 0, 44), SliceScale = 0.42, ImageColor3 = color or K.LOCK, ZIndex = 7 })
	for k, v in pairs(props or {}) do s[k] = v end
	s.Parent = parent
	text({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(1, -16, 1, -8), Text = label, TextSize = 20, TextColor3 = Color3.new(1, 1, 1),
		Stroke = 2.2, TextXAlignment = Enum.TextXAlignment.Center, Max = 20, ZIndex = 8, Parent = s })
	return s
end

-- small round action on a tile's corner (sell, fire, info...)
local function cornerButton(t, o)
	local cb = UI.button(o.label or "", o.color or T.red, nil, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 12), Size = UDim2.fromOffset(o.w or 58, 34),
		TextSize = 15, ZIndex = 9, Parent = t })
	cb.Name = "Corner"
	local busy = false
	cb.Activated:Connect(function()
		if busy then return end
		busy = true
		task.spawn(function() pcall(o.onClick, cb); busy = false end)
	end)
	return cb
end

--[[ item tile (put it in a K.grid)
	o = { name, icon, color, badge = {label, color} (top-left of the art), tag = {label, color} (top-right of the art),
	      stats = { {label, color}, ... } (1-2 short chips) | bar = {fraction, color, label},
	      button = {label, color, onClick, icon =, shine =} | buttons = { {...}, {...} } | status = {label, color},
	      corner = {label, color, onClick}, dim = true, spin = true, order }
]]
function K.tile(grid, o)
	local t = new("Frame", { Name = "Tile", BackgroundTransparency = 1, LayoutOrder = o.order or 0, ZIndex = 2, Parent = grid })
	UI.slice("tile", { Name = "Bg", ImageColor3 = o.dim and K.DIM or K.TILE, ZIndex = 1, Parent = t })
	local artH = o.artH or 128
	K.artBox(t, o.icon, o.color, { Position = UDim2.fromOffset(8, 8), Size = UDim2.new(1, -16, 0, artH), Spin = o.spin, Dim = o.dim, IconScale = o.iconScale, Custom = o.custom })
	if o.badge then K.chip(t, o.badge[1], o.badge[2] or T.red, { Position = UDim2.fromOffset(16, 16), ZIndex = 8 }) end
	if o.tag then K.chip(t, o.tag[1], o.tag[2] or K.DARK, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -16, 0, 16), ZIndex = 8 }) end
	if o.corner then cornerButton(t, o.corner) end
	local y = artH + 12
	text({ Name = "Title", Position = UDim2.fromOffset(13, y), Size = UDim2.new(1, -26, 0, 26), Text = o.name or "", TextSize = 22, Max = 22, TextColor3 = o.dim and K.SUB or K.DARK, Parent = t })
	y += 32
	if o.bar then
		local bar, fill = UI.bar({ Position = UDim2.fromOffset(12, y + 3), Size = UDim2.new(1, -24, 0, 20), ZIndex = 3 }, o.bar[2] or K.GREEN)
		bar.Parent = t
		fill.Size = UDim2.fromScale(math.clamp(o.bar[1] or 0, 0.06, 1), 1)
		if o.bar[3] then
			text({ Position = UDim2.fromOffset(0, 1), Size = UDim2.fromScale(1, 1), Text = o.bar[3], Font = T.chunky, TextSize = 14, TextColor3 = Color3.new(1, 1, 1), Stroke = 2,
				TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 6, Parent = bar })
		end
	elseif o.stats and #o.stats > 0 then
		local row = new("Frame", { Name = "Stats", Position = UDim2.fromOffset(11, y), Size = UDim2.new(1, -22, 0, 26), BackgroundTransparency = 1, ZIndex = 3, Parent = t })
		local lay = new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 5), SortOrder = Enum.SortOrder.LayoutOrder, Parent = row })
		for i, s in ipairs(o.stats) do K.chip(row, s[1], s[2], { LayoutOrder = i, Pic = s.pic }) end
		-- the chips always fit inside the tile: a row too long for it shrinks a little (never spills onto the next tile)
		local fit = new("UIScale", { Parent = row })
		local function refit()
			local k = math.max(fit.Scale, 0.01)
			local w, cw = row.AbsoluteSize.X / k, lay.AbsoluteContentSize.X / k
			local want = (w > 0 and cw > w) and math.max(0.55, w / cw) or 1
			if math.abs(want - fit.Scale) > 0.005 then fit.Scale = want end
		end
		lay:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(refit)
		row:GetPropertyChangedSignal("AbsoluteSize"):Connect(refit)
		task.defer(refit)
	end
	local bp = { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -10), Size = UDim2.new(1, -20, 0, 50) }
	if o.buttons then
		-- side by side, 6 px apart; a "square" one (icon only) is 50 x 50, the others share the rest
		local holder = new("Frame", { Name = "Buttons", AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 10, 1, -10), Size = UDim2.new(1, -20, 0, 50),
			BackgroundTransparency = 1, ZIndex = 7, Parent = t })
		new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = holder })
		local squares, wide = 0, 0
		for _, bd in ipairs(o.buttons) do if bd.square then squares += 1 else wide += 1 end end
		local fixed = squares * 50 + 6 * (#o.buttons - 1)
		for i, bd in ipairs(o.buttons) do
			local size = bd.square and UDim2.fromOffset(50, 50) or UDim2.new(1 / math.max(1, wide), -math.ceil(fixed / math.max(1, wide)), 0, 50)
			local b = K.button(holder, bd[1], bd[2], { Size = size, TextSize = 21, Icon = bd.icon, Shine = bd.shine, LayoutOrder = i }, bd[3])
			if bd.square then b.Name = "Square" end
		end
	elseif o.button then
		bp.Icon, bp.Shine = o.button.icon, o.button.shine
		K.button(t, o.button[1], o.button[2], bp, o.button[3])
	elseif o.status then
		bp.Size = UDim2.new(1, -20, 0, 44)
		bp.Position = UDim2.new(0.5, 0, 1, -13)
		K.status(t, o.status[1], o.status[2], bp)
	end
	return t
end

--[[ wide offer banner (Teleporter, starter pack, Rebirth, info cards)
	o = { name, line, bar = {fraction, color, label}, chips = {{label, color}, ...}, icon, color, tint (card colour),
	      button = {label, color, onClick, icon, shine}, status, order, height, buttonW }
]]
function K.banner(parent, order, o)
	local h = o.height or 128
	local f = new("Frame", { Name = "Banner", Size = UDim2.new(1, 0, 0, h), BackgroundTransparency = 1, LayoutOrder = order, ZIndex = 2, Parent = parent })
	local bg = UI.slice("tile", { Name = "Bg", ImageColor3 = Color3.new(1, 1, 1), ZIndex = 1, Parent = f })
	local tint = o.tint or Color3.fromRGB(255, 226, 150)
	new("UIGradient", { Color = ColorSequence.new(tint:Lerp(Color3.new(1, 1, 1), 0.55), tint), Rotation = 90, Parent = bg })
	K.artBox(f, o.icon, o.color, { Position = UDim2.fromOffset(10, 10), Size = UDim2.fromOffset(h - 20, h - 20), Spin = true })
	local bw = o.button and (o.buttonW or 190) or (o.status and 170 or 0)
	local x = h + 4
	local tl = text({ Name = "Title", Position = UDim2.fromOffset(x, 14), Size = UDim2.new(1, -x - bw - 26, 0, 34), Text = o.name, Font = T.chunky, TextSize = 30, Max = 30,
		TextColor3 = Color3.new(1, 1, 1), Stroke = 3, Parent = f })
	if o.titleGrad ~= false then
		new("UIGradient", { Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(255, 236, 150)), Rotation = 90, Parent = tl })
	end
	local y = 56
	if o.line then
		local lh = (o.bar or o.chips) and 24 or (h - 68)
		text({ Name = "Line", Position = UDim2.fromOffset(x, y), Size = UDim2.new(1, -x - bw - 26, 0, lh), Text = o.line, TextSize = 18, TextWrapped = not (o.bar or o.chips),
			TextYAlignment = Enum.TextYAlignment.Top, TextColor3 = K.DARK, Max = 18, Parent = f })
		y += lh + 6
	end
	if o.bar then
		local bar, fill = UI.bar({ Name = "Bar", Position = UDim2.fromOffset(x, y), Size = UDim2.new(1, -x - bw - 26, 0, 24), ZIndex = 3 }, o.bar[2] or K.GOLD)
		bar.Parent = f
		fill.Size = UDim2.fromScale(math.clamp(o.bar[1] or 0, 0.04, 1), 1)
		if o.bar[3] then
			text({ Position = UDim2.fromOffset(0, 1), Size = UDim2.fromScale(1, 1), Text = o.bar[3], Font = T.chunky, TextSize = 15, TextColor3 = Color3.new(1, 1, 1), Stroke = 2,
				TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 6, Parent = bar })
		end
		y += 30
	end
	if o.chips then
		local row = new("Frame", { Name = "Chips", Position = UDim2.fromOffset(x - 2, y), Size = UDim2.new(1, -x - bw - 26, 0, 26), BackgroundTransparency = 1, ZIndex = 3, Parent = f })
		new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = row })
		for i, sdef in ipairs(o.chips) do K.chip(row, sdef[1], sdef[2], { LayoutOrder = i, Pic = sdef.pic }) end
	end
	local bp = { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -16, 0.5, 0), Size = UDim2.fromOffset(bw, 58) }
	if o.button then
		bp.Icon, bp.Shine, bp.TextSize = o.button.icon, o.button.shine ~= false, 25
		K.button(f, o.button[1], o.button[2], bp, o.button[3])
	elseif o.status then
		bp.Size = UDim2.fromOffset(bw, 48)
		K.status(f, o.status[1], o.status[2], bp)
	end
	return f
end

--[[ light list row (contracts, upgrades...)
	o = { name, line, icon, color, chips = {{label,color},...}, bar = {fraction, color, label}, button = {...}, status = {...},
	      extra = {label, color, onClick, w, icon} (small button left of the main one),
	      dim, order, height, buttonW }
]]
function K.row(parent, order, o)
	local h = o.height or 112
	local f = new("Frame", { Name = "Row", Size = UDim2.new(1, 0, 0, h), BackgroundTransparency = 1, LayoutOrder = order, ZIndex = 2, Parent = parent })
	UI.slice("tile", { Name = "Bg", ImageColor3 = o.dim and K.DIM or K.TILE, ZIndex = 1, Parent = f })
	K.artBox(f, o.icon, o.color, { Position = UDim2.fromOffset(9, 9), Size = UDim2.fromOffset(h - 18, h - 18), Dim = o.dim, Spin = o.spin })
	local bw = o.buttonW or 170
	local right = (o.button or o.status) and (bw + 28) or 16
	if o.extra then right += (o.extra.w or 60) + 8 end
	local x = h + 4
	local hasChips = o.chips and #o.chips > 0
	-- title, line, bar and chips stacked with even 6 px gaps, the whole block centred in the row
	local total = 28 + (o.line and 26 or 0) + (o.bar and 26 or 0) + (hasChips and 32 or 0)
	local y = math.floor((h - total) / 2)
	local w = UDim2.new(1, -x - right, 0, 0)
	local tx = 0
	if o.new then
		-- NEW: a red pill before the title + a pulsing dot on the picture's corner (until you build it once)
		local pillF = new("Frame", { Name = "New", Position = UDim2.fromOffset(x, y + 2), Size = UDim2.fromOffset(58, 25), BackgroundColor3 = Color3.new(1, 1, 1),
			BorderSizePixel = 0, ZIndex = 4, Parent = f })
		new("UICorner", { CornerRadius = UDim.new(0, 9), Parent = pillF })
		new("UIGradient", { Color = ColorSequence.new(Color3.fromRGB(255, 92, 112), Color3.fromRGB(226, 30, 64)), Rotation = 90, Parent = pillF })
		new("UIStroke", { Thickness = 2.5, Color = T.ink, Parent = pillF })
		text({ Position = UDim2.fromOffset(0, 2), Size = UDim2.fromScale(1, 1), Text = "NEW", Font = T.chunky, TextSize = 16, TextColor3 = Color3.new(1, 1, 1), Stroke = 2,
			TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 5, Parent = pillF })
		local dot = new("Frame", { Name = "NewDot", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(h - 14, 14), Size = UDim2.fromOffset(22, 22),
			BackgroundColor3 = Color3.fromRGB(255, 52, 84), BorderSizePixel = 0, ZIndex = 9, Parent = f })
		new("UICorner", { CornerRadius = UDim.new(1, 0), Parent = dot })
		new("UIStroke", { Thickness = 3, Color = Color3.new(1, 1, 1), Parent = dot })
		local ds = new("UIScale", { Parent = dot })
		game:GetService("TweenService"):Create(ds, TweenInfo.new(0.55, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Scale = 1.22 }):Play()
		tx = 66
	end
	text({ Name = "Title", Position = UDim2.fromOffset(x + tx, y), Size = w + UDim2.fromOffset(-tx, 28), Text = o.name, TextSize = 25, Max = 25,
		TextColor3 = o.dim and K.SUB or K.DARK, Parent = f })
	y += 34
	if o.line then
		text({ Name = "Line", Position = UDim2.fromOffset(x, y), Size = w + UDim2.fromOffset(0, 20), Text = o.line, TextSize = 17, Max = 17, TextColor3 = K.SUB, Parent = f })
		y += 26
	end
	if o.bar then
		local bar, fill = UI.bar({ Position = UDim2.fromOffset(x, y), Size = w + UDim2.fromOffset(0, 20), ZIndex = 3 }, o.bar[2] or K.GREEN)
		bar.Parent = f
		fill.Size = UDim2.fromScale(math.clamp(o.bar[1] or 0, 0.05, 1), 1)
		if o.bar[3] then
			text({ Position = UDim2.fromOffset(0, 1), Size = UDim2.fromScale(1, 1), Text = o.bar[3], Font = T.chunky, TextSize = 14, TextColor3 = Color3.new(1, 1, 1), Stroke = 2,
				TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 6, Parent = bar })
		end
		y += 26
	end
	if hasChips then
		local row = new("Frame", { Name = "Chips", Position = UDim2.fromOffset(x - 2, y), Size = w + UDim2.fromOffset(0, 26), BackgroundTransparency = 1, ZIndex = 3, Parent = f })
		new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = row })
		for i, sdef in ipairs(o.chips) do K.chip(row, sdef[1], sdef[2], { LayoutOrder = i, Pic = sdef.pic }) end
	end
	local bp = { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -14, 0.5, 0), Size = UDim2.fromOffset(bw, 54) }
	if o.button then
		bp.Icon, bp.Shine, bp.TextSize = o.button.icon, o.button.shine, o.button.size or 22
		K.button(f, o.button[1], o.button[2], bp, o.button[3])
	elseif o.status then
		bp.Size = UDim2.fromOffset(bw, 46)
		K.status(f, o.status[1], o.status[2], bp)
	end
	if o.extra then
		local e = o.extra
		local eb = K.button(f, e.label or "", e.color, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -14 - bw - 8, 0.5, 0), Size = UDim2.fromOffset(e.w or 60, 54),
			Icon = e.icon, TextSize = 18 }, e.onClick)
		eb.Name = "Extra"
	end
	return f
end

-- "nothing here yet" card
function K.empty(parent, order, msg, icon)
	return K.row(parent, order, { name = msg, icon = icon or "star", color = K.LOCK, height = 90 })
end

-- a loading line while the server answers
function K.loading(parent)
	local f = K.note(parent, -1, "Loading...")
	local l = f:FindFirstChildOfClass("TextLabel")
	task.spawn(function()
		local i = 0
		while f.Parent do i = i % 3 + 1; l.Text = "Loading" .. string.rep(".", i); task.wait(0.3) end
	end)
	return f
end

-- a stand-alone window in the same style as the main one (trade window, popups): shadow, striped body, ribbon header
-- with a big icon, red close button. Returns the window frame and its close button (nil when noClose).
function K.window(parent, size, title, c1, c2, icon, noClose)
	local w = new("Frame", { Name = "Window", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, 20), Size = size, BackgroundTransparency = 1,
		Active = true, Parent = parent })
	UI.slice("shadow", { Name = "Shadow", Position = UDim2.fromOffset(-12, -2), Size = UDim2.new(1, 26, 1, 28), ImageTransparency = 0.05, ZIndex = 1, Parent = w })
	local body = UI.slice("panel", { Name = "Body", ImageColor3 = Color3.new(1, 1, 1), ZIndex = 2, Active = true, Parent = w })
	new("UIGradient", { Color = ColorSequence.new(Color3.fromRGB(104, 104, 240), Color3.fromRGB(52, 46, 150)), Rotation = 90, Parent = body })
	local stripes = new("CanvasGroup", { Name = "Stripes", Position = UDim2.fromOffset(5, 5), Size = UDim2.new(1, -10, 1, -10), BackgroundTransparency = 1, ZIndex = 3, Parent = w })
	UI.corner(17).Parent = stripes
	new("ImageLabel", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Image = UI.PATTERN, ScaleType = Enum.ScaleType.Tile, TileSize = UDim2.fromOffset(128, 128),
		ImageTransparency = 0.6, Parent = stripes })
	local hdr = new("Frame", { Name = "Header", Position = UDim2.fromOffset(70, -26), Size = UDim2.new(1, -140, 0, 70), BackgroundTransparency = 1, ZIndex = 20, Parent = w })
	UI.slice("button", { Name = "Ribbon", ImageColor3 = c2 and c1:Lerp(c2, 0.45) or c1, ZIndex = 1, Parent = hdr })
	local hs = new("CanvasGroup", { Position = UDim2.fromOffset(4, 4), Size = UDim2.new(1, -8, 1, -16), BackgroundTransparency = 1, ZIndex = 2, Parent = hdr })
	UI.corner(12).Parent = hs
	new("ImageLabel", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Image = UI.PATTERN, ScaleType = Enum.ScaleType.Tile, TileSize = UDim2.fromOffset(96, 96),
		ImageTransparency = 0.3, Parent = hs })
	UI.slice("gloss", { ZIndex = 3, Parent = hdr })
	local tl = text({ Name = "Title", Position = UDim2.fromOffset(icon and 80 or 20, 11), Size = UDim2.new(1, icon and -100 or -40, 0, 48), Text = title, Font = T.chunky, TextSize = 38, Max = 38,
		TextColor3 = Color3.new(1, 1, 1), Stroke = 4, ZIndex = 5, Parent = hdr })
	new("UIGradient", { Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(255, 234, 150)), Rotation = 90, Parent = tl })
	if icon then
		Icons.make(icon, { Name = "HeaderIcon", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0, 16, 0.5, -10), Size = UDim2.fromOffset(108, 108), Rotation = -8,
			ZIndex = 8, Parent = hdr })
	end
	local close
	if not noClose then
		close = UI.button("X", T.red, nil, { Position = UDim2.new(1, -48, 0, -20), Size = UDim2.fromOffset(62, 62), TextSize = 34, Font = T.chunky, ZIndex = 30, Parent = w })
		UI.closeStyle(close)
	end
	return w, close, tl
end

-- scroll a list so that a child (a tile, a row) sits near the top
function K.scrollTo(list, item, pad)
	task.defer(function()
		if not (item and item.Parent and list.Parent) then return end
		local k = list.AbsoluteSize.Y > 0 and list.AbsoluteWindowSize.Y / list.AbsoluteSize.Y or 1
		local y = item.AbsolutePosition.Y - list.AbsolutePosition.Y + list.CanvasPosition.Y * k
		list.CanvasPosition = Vector2.new(0, math.max(0, y / k - (pad or 8)))
	end)
end

-- money text helpers used by the windows
function K.robux(n) return n and ("\u{E002} " .. tostring(n)) or "\u{E002} ..." end

---------------------------------------------------------------------------------------------------------------------
-- Rarity looks: the rare hammers get backgrounds and names you spot from across the room
--   legendary: molten gold + a rainbow name   mythic: hot pink   secret: black metal with a silver sheen
--   divine: a holographic sky that keeps turning   exclusive: electric turquoise
---------------------------------------------------------------------------------------------------------------------
local C3 = Color3.fromRGB
local anims = setmetatable({}, { __mode = "k" }) -- object -> function(now), one loop for all of them
RunService.Heartbeat:Connect(function()
	local now = os.clock()
	for obj, fn in pairs(anims) do
		if obj.Parent then fn(now) else anims[obj] = nil end
	end
end)
local function seqOf(stops)
	local k = {}
	for _, s in ipairs(stops) do table.insert(k, ColorSequenceKeypoint.new(s[1], s[2])) end
	return ColorSequence.new(k)
end
-- a looping colour band (rainbow / holo) as 24 frames, so a moving rainbow never "runs out" at the ends
local function loopFrames(cols, n)
	local frames = {}
	for f = 0, n - 1 do
		local stops, m = {}, #cols
		local shift = f / n
		for i = 0, 8 do
			local t = i / 8
			local u = ((t + shift) % 1) * m
			local a = math.floor(u) % m
			local b = (a + 1) % m
			table.insert(stops, { t, cols[a + 1]:Lerp(cols[b + 1], u - math.floor(u)) })
		end
		frames[f + 1] = seqOf(stops)
	end
	return frames
end
local RAINBOW = loopFrames({ C3(255, 70, 70), C3(255, 160, 30), C3(255, 236, 50), C3(70, 225, 90), C3(50, 175, 255), C3(165, 85, 255) }, 24)
-- divine names: letters of light (white into gold) inside a glowing outline that breathes and turns violet → blue → magenta
local DIVINE_FILL = seqOf({ { 0, C3(255, 255, 255) }, { 0.5, C3(255, 242, 190) }, { 1, C3(255, 206, 110) } })
local DIVINE_HALO = { C3(150, 70, 235), C3(60, 110, 240), C3(215, 60, 175) }
local HOLO_BG = seqOf({ { 0, C3(255, 200, 238) }, { 0.2, C3(220, 196, 255) }, { 0.4, C3(186, 228, 255) }, { 0.6, C3(196, 255, 226) },
	{ 0.8, C3(255, 246, 196) }, { 1, C3(255, 200, 238) } })
local SHEEN = { -- a bright band that sweeps across the text
	metal = seqOf({ { 0, C3(58, 58, 74) }, { 0.36, C3(112, 112, 138) }, { 0.5, C3(255, 255, 255) }, { 0.64, C3(112, 112, 138) }, { 1, C3(58, 58, 74) } }),
	electric = seqOf({ { 0, C3(0, 188, 178) }, { 0.38, C3(30, 228, 214) }, { 0.5, C3(255, 255, 255) }, { 0.62, C3(30, 228, 214) }, { 1, C3(0, 188, 178) } }),
	mythic = seqOf({ { 0, C3(255, 70, 130) }, { 0.38, C3(255, 110, 160) }, { 0.5, C3(255, 235, 245) }, { 0.62, C3(255, 110, 160) }, { 1, C3(235, 40, 105) } }),
}
K.RARITY_LOOK = {
	legendary = { bg = { { 0, C3(255, 242, 150) }, { 0.45, C3(255, 182, 36) }, { 1, C3(210, 92, 6) } }, rays = C3(255, 250, 210), raysT = 0.18,
		glow = C3(255, 236, 140), sweep = C3(255, 255, 235), stars = C3(255, 252, 215), text = "rainbow" },
	mythic = { bg = { { 0, C3(255, 160, 196) }, { 0.5, C3(255, 70, 128) }, { 1, C3(178, 16, 74) } }, rays = C3(255, 225, 238), raysT = 0.3,
		sweep = C3(255, 235, 245), text = "mythic" },
	secret = { bg = { { 0, C3(96, 96, 124) }, { 0.42, C3(30, 30, 42) }, { 1, C3(6, 6, 12) } }, rays = C3(170, 160, 240), raysT = 0.5,
		glow = C3(140, 100, 255), sweep = C3(225, 225, 255), stars = C3(255, 255, 255), text = "metal", stroke = C3(176, 172, 214) },
	divine = { bg = "holo", rays = C3(255, 255, 255), raysT = 0.05, glow = C3(255, 255, 255), sweep = C3(255, 255, 255), stars = C3(255, 236, 170), text = "divine" },
	exclusive = { bg = { { 0, C3(170, 255, 244) }, { 0.45, C3(24, 214, 200) }, { 1, C3(0, 104, 132) } }, rays = C3(215, 255, 250), raysT = 0.18,
		glow = C3(130, 255, 242), sweep = C3(240, 255, 255), stars = C3(205, 255, 250), text = "electric" },
}
local function bgSeq(L) return L.bg == "holo" and HOLO_BG or seqOf(L.bg) end

-- restyle an art box (K.artBox) for its rarity: background, rays, glow, a light band sweeping across, twinkling stars
function K.rarityFX(box, id, o)
	local L = K.RARITY_LOOK[id]
	if not L or not box or (o and o.dim) then return box end
	local g = box:FindFirstChildOfClass("UIGradient")
	if g then
		g.Color = bgSeq(L)
		if L.bg == "holo" then
			g.Rotation = 45
			anims[g] = function(now) g.Rotation = (now * 45) % 360 end
		end
	end
	local rays = box:FindFirstChild("Rays")
	if rays then rays.ImageColor3 = L.rays; rays.ImageTransparency = L.raysT; spinners[rays] = true end
	local glow = box:FindFirstChild("Glow")
	if glow and L.glow then glow.ImageColor3 = L.glow; glow.ImageTransparency = 0.3 end
	if L.sweep then
		-- (not rotated: rotated frames ignore ClipsDescendants; the slant is in the gradient)
		local band = new("Frame", { Name = "Sweep", AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromScale(0.7, 1.2), BackgroundColor3 = L.sweep, BorderSizePixel = 0,
			Visible = false, ZIndex = 5, Parent = box })
		new("UIGradient", { Rotation = 20, Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.42, 1),
			NumberSequenceKeypoint.new(0.5, 0.35), NumberSequenceKeypoint.new(0.58, 1), NumberSequenceKeypoint.new(1, 1) }), Parent = band })
		local period, off = (o and o.small) and 3.2 or 2.6, math.random() * 3
		anims[band] = function(now)
			local t = ((now + off) % period) / period
			if t < 0.5 then band.Visible = true; band.Position = UDim2.fromScale(-0.4 + t / 0.5 * 1.8, 0.5) else band.Visible = false end
		end
	end
	if L.stars then
		-- (a sparkle picture, not a text glyph: the game fonts have no star character and drew empty boxes)
		for i = 1, 3 do
			local s = new("ImageLabel", { Name = "Star", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.18 + math.random() * 0.64, 0.16 + math.random() * 0.58),
				Size = UDim2.fromScale(0.3, 0.3), BackgroundTransparency = 1, Image = "rbxasset://textures/particles/sparkles_main.dds", ImageColor3 = L.stars,
				ImageTransparency = 1, ZIndex = 7, Parent = box })
			new("UIAspectRatioConstraint", { AspectRatio = 1, DominantAxis = Enum.DominantAxis.Height, Parent = s })
			local ph, sp = math.random() * 6, 2.2 + math.random() * 1.6
			anims[s] = function(now)
				local k = math.sin(now * sp + ph)
				s.ImageTransparency = 1 - math.max(0, k) ^ 1.5
			end
		end
	end
	return box
end

-- a hammer name in its rarity's colours: rainbow (legendary), black metal (secret), light with a breathing halo (divine),
-- electric (exclusive)
function K.rarityText(label, id, fallback)
	if not label then return label end
	local L = K.RARITY_LOOK[id]
	local style = L and L.text
	if not style then
		if fallback then label.TextColor3 = fallback end
		return label
	end
	label.TextColor3 = Color3.new(1, 1, 1)
	local g = label:FindFirstChildOfClass("UIGradient") or new("UIGradient", { Parent = label })
	g.Rotation = 0
	g.Offset = Vector2.zero
	if style == "rainbow" then
		g.Color = RAINBOW[1]
		anims[g] = function(now) g.Color = RAINBOW[math.floor(now * 14) % #RAINBOW + 1] end
	elseif style == "divine" then
		g.Color = DIVINE_FILL
		g.Rotation = 90
		anims[g] = nil
	else
		g.Color = SHEEN[style]
		local off = math.random() * 3
		anims[g] = function(now)
			local t = ((now + off) % 2.4) / 2.4
			g.Offset = Vector2.new(t < 0.6 and (-1 + t / 0.6 * 2) or 1, 0)
		end
	end
	-- an outline keeps the bright colours readable on light tiles
	local st = label:FindFirstChildOfClass("UIStroke")
	if not st then st = new("UIStroke", { Thickness = 1.6, Color = T.ink, LineJoinMode = Enum.LineJoinMode.Round, Parent = label }) end
	if L.stroke then st.Color = L.stroke end
	if style == "divine" then
		-- the halo: the outline breathes (thicker / thinner) and slowly turns through the sky's colours
		local base, ph = st.Thickness, math.random() * 6
		anims[st] = function(now)
			local u = ((now * 0.35 + ph) % #DIVINE_HALO)
			local a = math.floor(u)
			st.Color = DIVINE_HALO[a + 1]:Lerp(DIVINE_HALO[(a + 1) % #DIVINE_HALO + 1], u - a)
			st.Thickness = base * (1 + 0.45 * (0.5 + 0.5 * math.sin(now * 3 + ph)))
		end
	end
	return label
end

-- a chip / button background in the rarity's colours (the label keeps its white text)
function K.rarityChip(img, id)
	local L = K.RARITY_LOOK[id]
	if not L or not img then return img end
	img.ImageColor3 = Color3.new(1, 1, 1)
	local g = img:FindFirstChildOfClass("UIGradient") or new("UIGradient", { Parent = img })
	g.Color = bgSeq(L)
	g.Rotation = 90
	if L.bg == "holo" then
		g.Rotation = 0
		anims[g] = function(now) g.Offset = Vector2.new(math.sin(now * 1.3) * 0.35, 0) end
	end
	return img
end

return K
