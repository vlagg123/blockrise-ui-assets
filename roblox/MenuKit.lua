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
	local box = UI.slice("tile", { Name = "Art", ImageColor3 = Color3.new(1, 1, 1), ZIndex = 2, Parent = parent })
	for k, v in pairs(props) do if k ~= "Spin" and k ~= "Dim" and k ~= "IconScale" then box[k] = v end end
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
	new("UIGridLayout", { CellSize = UDim2.new(1 / cols, -math.ceil(gap * (cols - 1) / cols), 0, cellH), CellPadding = UDim2.fromOffset(gap, gap),
		SortOrder = Enum.SortOrder.LayoutOrder, Parent = f })
	return f
end

-- small coloured tag (stats, rarity, OWNED...)
function K.chip(parent, label, color, props)
	local c = UI.slice("pill", { Name = "Chip", Size = UDim2.fromOffset(0, 26), AutomaticSize = Enum.AutomaticSize.X, SliceScale = 0.36, ImageColor3 = color or T.blue, ZIndex = 5, Parent = parent })
	for k, v in pairs(props or {}) do c[k] = v end
	new("UIPadding", { PaddingLeft = UDim.new(0, 9), PaddingRight = UDim.new(0, 9), Parent = c })
	text({ Size = UDim2.new(0, 0, 1, -2), AutomaticSize = Enum.AutomaticSize.X, Text = label, Font = T.chunky, TextSize = 15, TextColor3 = Color3.new(1, 1, 1), Stroke = 2,
		ZIndex = 6, Parent = c })
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
	local artH = o.artH or 138
	K.artBox(t, o.icon, o.color, { Position = UDim2.fromOffset(8, 8), Size = UDim2.new(1, -16, 0, artH), Spin = o.spin, Dim = o.dim, IconScale = o.iconScale })
	if o.badge then K.chip(t, o.badge[1], o.badge[2] or T.red, { Position = UDim2.fromOffset(14, 14), ZIndex = 8 }) end
	if o.tag then K.chip(t, o.tag[1], o.tag[2] or K.DARK, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -14, 0, 14), ZIndex = 8 }) end
	if o.corner then cornerButton(t, o.corner) end
	local y = artH + 14
	text({ Name = "Title", Position = UDim2.fromOffset(13, y), Size = UDim2.new(1, -26, 0, 26), Text = o.name or "", TextSize = 22, Max = 22, TextColor3 = o.dim and K.SUB or K.DARK, Parent = t })
	y += 30
	if o.bar then
		local bar, fill = UI.bar({ Position = UDim2.fromOffset(12, y + 3), Size = UDim2.new(1, -24, 0, 20), ZIndex = 3 }, o.bar[2] or K.GREEN)
		bar.Parent = t
		fill.Size = UDim2.fromScale(math.clamp(o.bar[1] or 0, 0.06, 1), 1)
		if o.bar[3] then
			text({ Size = UDim2.fromScale(1, 1), Text = o.bar[3], Font = T.chunky, TextSize = 14, TextColor3 = Color3.new(1, 1, 1), Stroke = 2,
				TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 6, Parent = bar })
		end
	elseif o.stats and #o.stats > 0 then
		local row = new("Frame", { Name = "Stats", Position = UDim2.fromOffset(11, y), Size = UDim2.new(1, -22, 0, 26), BackgroundTransparency = 1, ZIndex = 3, Parent = t })
		new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 5), SortOrder = Enum.SortOrder.LayoutOrder, Parent = row })
		for i, s in ipairs(o.stats) do K.chip(row, s[1], s[2], { LayoutOrder = i }) end
	end
	local bp = { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -10), Size = UDim2.new(1, -20, 0, 50) }
	if o.buttons then
		local n = #o.buttons
		for i, bd in ipairs(o.buttons) do
			K.button(t, bd[1], bd[2], { AnchorPoint = Vector2.new(0, 1), Position = UDim2.new((i - 1) / n, i == 1 and 10 or 3, 1, -10),
				Size = UDim2.new(1 / n, -13, 0, 50), TextSize = 19, Icon = bd.icon }, bd[3])
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

--[[ wide offer banner (Teleporter, starter pack, info cards)
	o = { name, line, icon, color, tint (card colour), button = {label, color, onClick, icon, shine}, status, order, height }
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
	if o.line then
		text({ Name = "Line", Position = UDim2.fromOffset(x, 52), Size = UDim2.new(1, -x - bw - 26, 0, h - 64), Text = o.line, TextSize = 18, TextWrapped = true,
			TextYAlignment = Enum.TextYAlignment.Top, TextColor3 = K.DARK, Max = 18, Parent = f })
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
	local lines = (o.line and 1 or 0) + (hasChips and 1 or 0) + (o.bar and 1 or 0)
	local nameY = lines >= 2 and 8 or (lines == 1 and 20 or 0)
	text({ Name = "Title", Position = UDim2.fromOffset(x, nameY), Size = UDim2.new(1, -x - right, 0, lines > 0 and 30 or h), Text = o.name, TextSize = 25, Max = 25,
		TextColor3 = o.dim and K.SUB or K.DARK, Parent = f })
	local y = nameY + 30
	if o.line then
		text({ Name = "Line", Position = UDim2.fromOffset(x, y), Size = UDim2.new(1, -x - right, 0, 22), Text = o.line, TextSize = 17, Max = 17, TextColor3 = K.SUB, Parent = f })
		y += 26
	end
	if o.bar then
		local bar, fill = UI.bar({ Position = UDim2.fromOffset(x, y + 2), Size = UDim2.new(1, -x - right, 0, 20), ZIndex = 3 }, o.bar[2] or K.GREEN)
		bar.Parent = f
		fill.Size = UDim2.fromScale(math.clamp(o.bar[1] or 0, 0.05, 1), 1)
		if o.bar[3] then
			text({ Size = UDim2.fromScale(1, 1), Text = o.bar[3], Font = T.chunky, TextSize = 14, TextColor3 = Color3.new(1, 1, 1), Stroke = 2,
				TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 6, Parent = bar })
		end
		y += 28
	end
	if hasChips then
		local row = new("Frame", { Name = "Chips", Position = UDim2.fromOffset(x - 2, y + 2), Size = UDim2.new(1, -x - right, 0, 26), BackgroundTransparency = 1, ZIndex = 3, Parent = f })
		new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = row })
		for i, s in ipairs(o.chips) do K.chip(row, s[1], s[2], { LayoutOrder = i }) end
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
function K.robux(n) return n and ("R$ " .. tostring(n)) or "R$ ..." end

return K
