-- BlockRise Empire - menu building blocks: item tiles in a grid (big art, name, short stats, price button),
-- light row cards, section titles. Built on UIKit's 9-slice skin, so every window looks the same.
local RS = game:GetService("ReplicatedStorage")
local UI = require(RS.Shared:WaitForChild("UIKit"))
local Icons = require(RS.Shared:WaitForChild("Icons"))
local T = UI.Theme
local new = UI.new

local K = {}
K.INK = T.ink
K.TILE = Color3.fromRGB(246, 246, 255)     -- light item card
K.DARK = T.dark                             -- text on light cards
K.SUB = Color3.fromRGB(105, 100, 140)       -- second line on light cards
K.Z = 22

local function text(props)
	local l = new("TextLabel", { BackgroundTransparency = 1, Font = T.body, TextColor3 = K.DARK, TextSize = 16, ZIndex = K.Z + 2,
		TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Center, RichText = true })
	for k, v in pairs(props) do if k ~= "Parent" and k ~= "Stroke" then l[k] = v end end
	if props.Stroke then new("UIStroke", { Thickness = props.Stroke, Color = T.ink, LineJoinMode = Enum.LineJoinMode.Round, Parent = l }) end
	l.Parent = props.Parent
	return l
end
K.text = text

-- art: an atlas icon, or an emoji when the item has no icon yet
function K.art(parent, icon, size, z)
	if Icons.has(icon) then
		return Icons.make(icon, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = size or UDim2.fromScale(0.95, 0.95), ZIndex = z or K.Z + 3, Parent = parent })
	end
	local l = new("TextLabel", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.52), Size = size or UDim2.fromScale(0.7, 0.7), BackgroundTransparency = 1,
		Text = icon or "?", TextScaled = true, Font = Enum.Font.SourceSans, ZIndex = z or K.Z + 3, Parent = parent })
	return l
end

-- section title inside a window
function K.section(parent, order, title, color, note)
	local f = new("Frame", { Name = "Section", Size = UDim2.new(1, 0, 0, note and 46 or 34), BackgroundTransparency = 1, LayoutOrder = order, ZIndex = K.Z, Parent = parent })
	text({ Size = UDim2.new(1, 0, 0, 30), Text = title, Font = T.chunky, TextSize = 24, TextColor3 = color or Color3.new(1, 1, 1), Stroke = 2.5, Parent = f })
	if note then text({ Position = UDim2.fromOffset(2, 28), Size = UDim2.new(1, 0, 0, 18), Text = note, TextSize = 15, TextColor3 = Color3.fromRGB(205, 210, 240), Parent = f }) end
	return f
end

-- a grid that grows with its tiles
function K.grid(parent, order, cols, cellH, gap)
	gap = gap or 12
	local f = new("Frame", { Name = "Grid", Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, LayoutOrder = order, ZIndex = K.Z, Parent = parent })
	new("UIGridLayout", { CellSize = UDim2.new(1 / cols, -gap * (cols - 1) / cols, 0, cellH), CellPadding = UDim2.fromOffset(gap, gap), SortOrder = Enum.SortOrder.LayoutOrder, Parent = f })
	return f
end

-- small coloured tag (stats, prices, "OWNED"...)
function K.chip(parent, label, color, props)
	local c = UI.slice("pill", { Name = "Chip", Size = UDim2.fromOffset(0, 26), AutomaticSize = Enum.AutomaticSize.X, SliceScale = 0.36, ImageColor3 = color or T.blue, ZIndex = K.Z + 2, Parent = parent })
	for k, v in pairs(props or {}) do c[k] = v end
	new("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10), Parent = c })
	text({ Size = UDim2.fromScale(0, 1), AutomaticSize = Enum.AutomaticSize.X, Text = label, Font = T.chunky, TextSize = 14, TextColor3 = Color3.new(1, 1, 1), Stroke = 1.6, ZIndex = K.Z + 3, Parent = c })
	return c
end

-- price / action button with a busy guard
function K.button(parent, label, color, props, onClick)
	local b = UI.button(label, color, nil, { Size = UDim2.new(1, 0, 0, 46), TextSize = 21, ZIndex = K.Z + 3 })
	for k, v in pairs(props or {}) do b[k] = v end
	b.Parent = parent
	local busy = false
	if onClick then
		b.Activated:Connect(function()
			if busy then return end
			busy = true
			task.spawn(function() onClick(); busy = false end)
		end)
	end
	return b
end

-- status in place of a button (EQUIPPED, MAX, locked...)
function K.status(parent, label, color, props)
	local s = UI.slice("pill", { Size = UDim2.new(1, 0, 0, 42), SliceScale = 0.4, ImageColor3 = color or Color3.fromRGB(150, 150, 190), ZIndex = K.Z + 2 })
	for k, v in pairs(props or {}) do s[k] = v end
	s.Parent = parent
	text({ Size = UDim2.fromScale(1, 1), Text = label, Font = T.chunky, TextSize = 18, TextColor3 = Color3.new(1, 1, 1), Stroke = 2,
		TextXAlignment = Enum.TextXAlignment.Center, Parent = s })
	return s
end

--[[ item tile
	o = { name, icon, color, sub, stats = { {label, color}, ... }, badge = {label, color},
	      button = {label, color, onClick} | status = {label, color}, dim = true, order }
]]
function K.tile(grid, o)
	local t = new("Frame", { Name = "Tile", BackgroundTransparency = 1, LayoutOrder = o.order or 0, ZIndex = K.Z, Parent = grid })
	UI.slice("tile", { ImageColor3 = o.dim and Color3.fromRGB(200, 202, 222) or K.TILE, ZIndex = K.Z, Parent = t })
	-- art
	local artH = o.artH or 104
	local art = UI.slice("tile", { Name = "Art", Position = UDim2.fromOffset(8, 8), Size = UDim2.new(1, -16, 0, artH), ImageColor3 = o.color or T.blue, ZIndex = K.Z + 1, Parent = t })
	UI.slice("gloss", { ImageTransparency = 0.25, ZIndex = K.Z + 2, Parent = art })
	local pic = K.art(art, o.icon, UDim2.new(0, artH + 6, 0, artH + 6))
	if o.dim then
		if pic:IsA("ImageLabel") then pic.ImageTransparency = 0.35 else pic.TextTransparency = 0.35 end
	end
	if o.badge then
		K.chip(t, o.badge[1], o.badge[2] or T.red, { Position = UDim2.fromOffset(4, 2), ZIndex = K.Z + 5 })
	end
	if o.corner then
		-- small round action on the art's top-right corner: { label or icon, color, onClick }
		local cb = UI.button(o.corner.label or "", o.corner[2] or T.accent, nil, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -4, 0, 4),
			Size = UDim2.fromOffset(o.corner.w or 48, 44), TextSize = 15, ZIndex = K.Z + 6, Parent = t })
		if o.corner.icon then K.art(cb, o.corner.icon, UDim2.fromOffset(46, 46), K.Z + 9) end
		cb.Activated:Connect(function() o.corner[3]() end)
	end
	local y = artH + 14
	text({ Name = "Title", Position = UDim2.fromOffset(12, y), Size = UDim2.new(1, -24, 0, 26), Text = o.name or "", Font = T.chunky, TextSize = 21,
		TextColor3 = K.DARK, TextTruncate = Enum.TextTruncate.AtEnd, Parent = t })
	y += 26
	if o.sub then
		text({ Name = "Sub", Position = UDim2.fromOffset(12, y), Size = UDim2.new(1, -24, 0, 20), Text = o.sub, TextSize = 15, TextColor3 = K.SUB,
			TextTruncate = Enum.TextTruncate.AtEnd, Parent = t })
		y += 22
	end
	if o.stats and #o.stats > 0 then
		local row = new("Frame", { Name = "Stats", Position = UDim2.fromOffset(10, y + 2), Size = UDim2.new(1, -20, 0, 26), BackgroundTransparency = 1, ZIndex = K.Z + 1, Parent = t })
		new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = row })
		for i, s in ipairs(o.stats) do K.chip(row, s[1], s[2], { LayoutOrder = i }) end
	end
	local bp = { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -10), Size = UDim2.new(1, -20, 0, 46) }
	if o.buttons then
		-- two buttons side by side
		local n = #o.buttons
		for i, bd in ipairs(o.buttons) do
			K.button(t, bd[1], bd[2] or T.green, { AnchorPoint = Vector2.new(0, 1), Position = UDim2.new((i - 1) / n, 10 - (i - 1) * 4, 1, -10),
				Size = UDim2.new(1 / n, -14 + (n > 1 and -2 or 0), 0, 46), TextSize = 18 }, bd[3])
		end
	elseif o.button then
		K.button(t, o.button[1], o.button[2] or T.green, bp, o.button[3])
	elseif o.status then
		bp.Size = UDim2.new(1, -20, 0, 42)
		K.status(t, o.status[1], o.status[2], bp)
	end
	return t
end

-- light row card for lists (contracts, missions, gifts...): returns the frame; content goes on top
function K.row(parent, order, height, tint)
	local f = new("Frame", { Name = "Row", Size = UDim2.new(1, 0, 0, height or 96), BackgroundTransparency = 1, LayoutOrder = order, ZIndex = K.Z, Parent = parent })
	UI.slice("tile", { ImageColor3 = tint or K.TILE, ZIndex = K.Z, Parent = f })
	return f
end

-- square art box for row cards
function K.artBox(parent, icon, color, size, pos)
	local a = UI.slice("tile", { Name = "Art", Position = pos or UDim2.fromOffset(10, 10), Size = UDim2.fromOffset(size, size), ImageColor3 = color or T.blue, ZIndex = K.Z + 1, Parent = parent })
	UI.slice("gloss", { ImageTransparency = 0.25, ZIndex = K.Z + 2, Parent = a })
	K.art(a, icon, UDim2.fromOffset(size + 4, size + 4))
	return a
end

-- short tip line on the dark window body
function K.note(parent, order, msg)
	local f = new("Frame", { Name = "Note", Size = UDim2.new(1, 0, 0, 26), BackgroundTransparency = 1, LayoutOrder = order, ZIndex = K.Z, Parent = parent })
	text({ Size = UDim2.fromScale(1, 1), Text = msg, TextSize = 15, TextColor3 = Color3.fromRGB(205, 210, 240), TextWrapped = true, Parent = f })
	return f
end

return K
