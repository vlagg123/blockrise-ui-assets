-- BlockRise Empire - UI toolkit. Windows, tiles and bars are drawn with 9-slice images from one skin atlas
-- (ui_skin.png): ink outline, gloss and soft shading are baked in, Roblox tints them with ImageColor3. Buttons are
-- built like the big HUD buttons (a face on a darker base that sinks when pressed).
local TweenService = game:GetService("TweenService")

local UI = {}

UI.Theme = {
	bg = Color3.fromRGB(16, 18, 26),
	bg2 = Color3.fromRGB(28, 31, 42),
	bg3 = Color3.fromRGB(96, 100, 150),     -- "disabled" buttons
	accent = Color3.fromRGB(255, 196, 50),
	accent2 = Color3.fromRGB(255, 136, 30),
	green = Color3.fromRGB(80, 220, 110),
	green2 = Color3.fromRGB(36, 165, 80),
	red = Color3.fromRGB(240, 82, 82),
	blue = Color3.fromRGB(80, 165, 255),
	blue2 = Color3.fromRGB(40, 100, 220),
	purple = Color3.fromRGB(175, 120, 255),
	text = Color3.fromRGB(255, 255, 255),
	muted = Color3.fromRGB(200, 204, 230),
	dark = Color3.fromRGB(40, 34, 70),        -- text on light tiles
	title = Enum.Font.FredokaOne,
	body = Enum.Font.FredokaOne,
	bold = Enum.Font.FredokaOne,
	black = Enum.Font.LuckiestGuy,
	chunky = Enum.Font.LuckiestGuy,
	ink = Color3.fromRGB(20, 17, 32),
	panel1 = Color3.fromRGB(62, 56, 100),
	panel2 = Color3.fromRGB(33, 29, 56),
}
local T = UI.Theme

UI.SKIN = "rbxassetid://107184333530086"
UI.PATTERN = "rbxassetid://74568081749351" -- diagonal stripes, 22% white: fade with ImageTransparency
-- name -> { x, y, slice inset } inside the 512x512 skin atlas (cells are 128x128, drawn at 2x)
local CELLS = {
	panel = { 0, 0, 44 }, button = { 128, 0, 40 }, tile = { 256, 0, 40 }, gloss = { 384, 0, 30 },
	pill = { 0, 128, 34 }, inset = { 128, 128, 28 }, shadow = { 256, 128, 44 }, circle = { 384, 128, 63 },
	fill = { 0, 256, 28 }, rays = { 128, 256, 0 }, glow = { 256, 256, 0 }, face = { 384, 256, 40 },
}
UI.CELLS = CELLS
UI.TAB_OFF = Color3.fromRGB(66, 72, 156)

function UI.new(class, props, children)
	local o = Instance.new(class)
	local parent
	for k, v in pairs(props or {}) do
		if k == "Parent" then parent = v else o[k] = v end
	end
	for _, c in ipairs(children or {}) do c.Parent = o end
	if parent then o.Parent = parent end
	return o
end
local new = UI.new

function UI.corner(r) return new("UICorner", { CornerRadius = UDim.new(0, r or 12) }) end
function UI.stroke(trans, color, thick)
	return new("UIStroke", { Transparency = trans or 0.86, Color = color or Color3.new(1, 1, 1), Thickness = thick or 1.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
end
function UI.textStroke(trans, thick)
	return new("UIStroke", { Transparency = trans or 0.2, Color = T.ink, Thickness = thick or 2, LineJoinMode = Enum.LineJoinMode.Round, ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual })
end
function UI.pad(p, pt)
	return new("UIPadding", { PaddingLeft = UDim.new(0, p), PaddingRight = UDim.new(0, p), PaddingTop = UDim.new(0, pt or p), PaddingBottom = UDim.new(0, pt or p) })
end
function UI.grad(c1, c2, rot)
	return new("UIGradient", { Color = ColorSequence.new(c1, c2), Rotation = rot or 90 })
end
function UI.list(dir, padding, halign, valign)
	return new("UIListLayout", { FillDirection = dir or Enum.FillDirection.Vertical, Padding = UDim.new(0, padding or 8), SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = halign or Enum.HorizontalAlignment.Left, VerticalAlignment = valign or Enum.VerticalAlignment.Top })
end

function UI.tween(o, t, props, style, dir)
	local tw = TweenService:Create(o, TweenInfo.new(t, style or Enum.EasingStyle.Quint, dir or Enum.EasingDirection.Out), props)
	tw:Play()
	return tw
end

-- the number on a red badge (over 9 it says +9), optically centred: a "1" carries its weight on the stem
-- (right of its box), and digits sit a hair low in their line at small sizes
function UI.badgeText(l, t)
	if tonumber(t) and tonumber(t) > 9 then t = "+9" end
	t = tostring(t)
	l.Text = t
	local dx = (t == "1" and -1.25) or (t:sub(1, 1) == "1" and -0.6) or 0
	local dy = -0.5
	l.Position = UDim2.fromOffset(dx, dy)
end

-- a 9-slice piece of the skin atlas
function UI.slice(name, props)
	local c = CELLS[name]
	local im = new("ImageLabel", { Name = name, BackgroundTransparency = 1, Image = UI.SKIN, ImageRectOffset = Vector2.new(c[1], c[2]),
		ImageRectSize = Vector2.new(128, 128), Size = UDim2.fromScale(1, 1) })
	if c[3] > 0 then
		im.ScaleType = Enum.ScaleType.Slice
		im.SliceCenter = Rect.new(c[3], c[3], 128 - c[3], 128 - c[3])
		im.SliceScale = 0.5
	else
		-- stretched cells (rays, glow) fade out before their edges: sample 3 px inside the cell, so the
		-- neighbouring atlas cells never bleed in as thin lines (very visible when the rays spin)
		im.ScaleType = Enum.ScaleType.Stretch
		im.ImageRectOffset = Vector2.new(c[1] + 3, c[2] + 3)
		im.ImageRectSize = Vector2.new(122, 122)
	end
	for k, v in pairs(props or {}) do if k ~= "Parent" then im[k] = v end end
	if props and props.Parent then im.Parent = props.Parent end
	return im
end

-- dark glass with a thick ink outline (toasts, hint, small panels)
function UI.panel(props)
	props = props or {}
	local f = new("Frame", { BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.04, BorderSizePixel = 0 })
	for k, v in pairs(props) do if k ~= "Parent" and k ~= "Radius" then f[k] = v end end
	UI.corner(props.Radius or 14).Parent = f
	new("UIStroke", { Thickness = 3, Color = T.ink, Transparency = 0, LineJoinMode = Enum.LineJoinMode.Round, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }).Parent = f
	new("UIGradient", { Color = ColorSequence.new(T.panel1, T.panel2), Rotation = 90 }).Parent = f
	if props.Parent then f.Parent = props.Parent end
	return f
end

function UI.label(props)
	local l = new("TextLabel", { BackgroundTransparency = 1, Font = T.body, TextColor3 = T.text, TextSize = 16,
		TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Center, RichText = true })
	for k, v in pairs(props or {}) do if k ~= "Parent" then l[k] = v end end
	if props and props.Parent then l.Parent = props.Parent end
	return l
end

-- a light band that sweeps across a button every few seconds (buy buttons, the main action)
function UI.shine(b, z, period)
	local host = b:FindFirstChild("Bg") or b
	local sweep = new("Frame", { Name = "Sweep", BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.45, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1),
		ZIndex = z or 1, Parent = host })
	local hc = host:FindFirstChildOfClass("UICorner")
	new("UICorner", { CornerRadius = hc and hc.CornerRadius or UDim.new(0, 14), Parent = sweep })
	local g = new("UIGradient", { Rotation = 25, Offset = Vector2.new(-1, 0), Parent = sweep,
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.4, 1), NumberSequenceKeypoint.new(0.5, 0.2),
			NumberSequenceKeypoint.new(0.6, 1), NumberSequenceKeypoint.new(1, 1) }) })
	local tw = TweenService:Create(g, TweenInfo.new(0.75, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, false, period or 2.6), { Offset = Vector2.new(1, 0) })
	tw:Play()
	sweep.Destroying:Connect(function() tw:Cancel() end)
	return sweep
end

-- chunky game button, the same as the big HUD buttons: a face (colour gradient, gloss, ink outline) sitting on a darker
-- base. Pressing pushes the face down onto the base (the label and the icon go down with it) and it springs back up
-- when you let go; with a mouse it grows a little under the pointer.
-- Bg is the face: an ImageLabel without an image, so the old way of colouring a button still works (Bg.ImageColor3 =
-- the colour: face gradient and base follow; Bg.ImageTransparency fades the button; Bg.Shine is the gloss).
-- Extra props: Icon (atlas icon shown left of the text), Shine (sweeping light band), Radius (corner radius).
local LABEL_KEYS = { Text = true, TextSize = true, Font = true, TextColor3 = true, Icon = true, Shine = true }
local BTN_DROP, BTN_PRESS, BTN_RADIUS = 6, 5, 14 -- the base shows 6 px under the face; a press sinks the face 5 px
local UIS = game:GetService("UserInputService")
local WHITE, BLACK = Color3.new(1, 1, 1), Color3.new(0, 0, 0)
-- [the button's place in the game (full name)] = when it was last pressed: a button made again in the same place right
-- after (a tab bar redraws as soon as you tap a tab) comes up pressed and springs back, so the press is always seen
local recentPress = {}
function UI.button(text, c1, c2, props)
	props = props or {}
	local z = props.ZIndex or 1
	local color = c2 and c1:Lerp(c2, 0.35) or c1
	local radius = props.Radius or BTN_RADIUS
	local b = new("TextButton", { AutoButtonColor = false, BackgroundTransparency = 1, BorderSizePixel = 0, Text = "" })
	for k, v in pairs(props) do
		if k ~= "Parent" and k ~= "Radius" and not LABEL_KEYS[k] then b[k] = v end
	end
	-- the base: the button's darker 3D side, showing under the face
	local base = new("Frame", { Name = "Base", Position = UDim2.fromOffset(0, BTN_DROP), Size = UDim2.new(1, 0, 1, -BTN_DROP), BorderSizePixel = 0,
		ZIndex = math.max(0, z - 1), Parent = b })
	UI.corner(radius).Parent = base
	local baseStroke = new("UIStroke", { Thickness = 3, Color = T.ink, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = base })
	-- the face
	local bg = new("ImageLabel", { Name = "Bg", Image = "", ImageColor3 = color, BackgroundColor3 = WHITE, BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 1, -BTN_DROP), ZIndex = z, Parent = b })
	UI.corner(radius).Parent = bg
	local faceStroke = new("UIStroke", { Thickness = 3, Color = T.ink, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = bg })
	local grad = new("UIGradient", { Name = "FaceGrad", Rotation = 90, Parent = bg })
	-- the gloss on the top of the face (an ImageLabel too: Shine.ImageTransparency dims it, like before)
	local shine = new("ImageLabel", { Name = "Shine", Image = "", BackgroundColor3 = WHITE, BackgroundTransparency = 0.55, BorderSizePixel = 0,
		Position = UDim2.fromOffset(5, 4), Size = UDim2.new(1, -10, 0.42, 0), ZIndex = z, Parent = bg })
	UI.corner(math.max(4, radius - 4)).Parent = shine
	new("UIGradient", { Transparency = NumberSequence.new(0.2, 1), Rotation = 90, Parent = shine })
	shine:GetPropertyChangedSignal("ImageTransparency"):Connect(function()
		shine.BackgroundTransparency = math.clamp(0.55 + (shine.ImageTransparency - 0.1) * 0.8, 0, 1)
	end)
	local function paint()
		local skin = bg:GetAttribute("Skin")
		if skin == "plain" then return end
		local bot
		if skin then
			-- someone else colours the face (a rarity look): the base follows the bottom of that gradient
			local k = grad.Color.Keypoints
			bot = k[#k].Value
		else
			local col = bg.ImageColor3
			if bg:GetAttribute("Hover") then col = col:Lerp(WHITE, 0.12) end
			bot = col:Lerp(BLACK, 0.12)
			grad.Color = ColorSequence.new(col:Lerp(WHITE, 0.16), bot)
		end
		base.BackgroundColor3 = bot:Lerp(T.ink, 0.4)
		local tr = bg.ImageTransparency
		bg.BackgroundTransparency = tr
		base.BackgroundTransparency = tr
		faceStroke.Transparency = tr
		baseStroke.Transparency = tr
	end
	bg:GetPropertyChangedSignal("ImageColor3"):Connect(paint)
	bg:GetPropertyChangedSignal("ImageTransparency"):Connect(paint)
	bg:GetAttributeChangedSignal("Skin"):Connect(paint)
	bg:GetAttributeChangedSignal("Hover"):Connect(paint)
	grad:GetPropertyChangedSignal("Color"):Connect(function() if bg:GetAttribute("Skin") and bg:GetAttribute("Skin") ~= "plain" then paint() end end)
	bg:SetAttribute("Color", color)
	paint()
	-- the label sits on the face
	local lbl = new("TextLabel", { Name = "Label", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 2), Size = UDim2.new(1, -14, 1, -BTN_DROP - 4),
		BackgroundTransparency = 1, Text = text, Font = props.Font or T.body, TextColor3 = props.TextColor3 or WHITE, TextWrapped = false,
		ZIndex = z + 1, Parent = b })
	new("UITextSizeConstraint", { MaxTextSize = props.TextSize or 20, MinTextSize = 9, Parent = lbl })
	lbl.TextScaled = true
	new("UIStroke", { Thickness = 2.2, Color = T.ink, LineJoinMode = Enum.LineJoinMode.Round, ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual, Parent = lbl })
	-- pressing: one value (0 = up, BTN_PRESS = down) moves the face and what is drawn on it
	local press = Instance.new("NumberValue") -- 0 = up, BTN_PRESS = pushed down onto the base
	local hov = Instance.new("NumberValue")   -- 0 = normal, 1 = grown under the mouse
	local grow = { x = 0, y = 0, left = 0.5 } -- how much the face grows on hover (px) and which share of it goes left
	local rest = {}     -- [label / icon] = where it sits when the button is up and not grown
	local restSize = {} -- [label] = its size then
	-- the face sinks onto the base when pressed (hov / grow stay at 0: a hover only lights the face up)
	local function apply()
		local y, k = press.Value, hov.Value
		local gx, gy = grow.x * k, grow.y * k
		local lx = gx * grow.left
		if bg:GetAttribute("Skin") == "plain" then return end
		bg.Position = UDim2.fromOffset(-lx, y - gy)
		bg.Size = UDim2.new(1, gx, 1, -BTN_DROP + gy)
		if base.Parent then
			base.Position = UDim2.fromOffset(-lx, BTN_DROP - gy)
			base.Size = UDim2.new(1, gx, 1, -BTN_DROP + gy)
		end
		local dx = gx / 2 - lx
		for g, p in pairs(rest) do
			if g.Parent == b then g.Position = p + UDim2.fromOffset(dx, y - gy / 2) end
		end
		if restSize[lbl] then lbl.Size = restSize[lbl] + UDim2.fromOffset(gx, gy) end
	end
	press.Changed:Connect(apply)
	hov.Changed:Connect(apply)
	b.Destroying:Connect(function() press:Destroy(); hov:Destroy() end)
	-- remember where the label sits while the button is at rest (an icon button's layout keeps its own)
	local function capture()
		if math.abs(press.Value) < 0.01 and math.abs(hov.Value) < 0.01 and not props.Icon then
			rest[lbl] = lbl.Position
			restSize[lbl] = lbl.Size
		end
	end
	-- back at rest: forget it (whoever moves the label later is not undone by the next press)
	local function release()
		if math.abs(press.Value) < 0.001 and math.abs(hov.Value) < 0.001 and not props.Icon then
			if restSize[lbl] then lbl.Size = restSize[lbl] end
			rest[lbl], restSize[lbl] = nil, nil
		end
	end
	if props.Icon then
		-- icon + text centred together as one group on the face
		local Icons = require(script.Parent:WaitForChild("Icons"))
		local TextService = game:GetService("TextService")
		local ic = Icons.make(props.Icon, { Name = "Icon", AnchorPoint = Vector2.new(0, 0.5), ZIndex = z + 2, Parent = b })
		if ic:IsA("TextLabel") and not Icons.emoji[props.Icon] then ic.Text = props.Icon end -- an emoji was passed
		local cons = lbl:FindFirstChildOfClass("UITextSizeConstraint")
		if cons then cons:Destroy() end
		lbl.TextScaled = false
		lbl.AnchorPoint = Vector2.new(0, 0)
		lbl.TextXAlignment = Enum.TextXAlignment.Left
		local maxSize = props.TextSize or 20
		local function place()
			local hD = b.Size.Y.Offset
			local k = hD > 0 and b.AbsoluteSize.Y / hD or 1
			if k <= 0 then return end
			local w = b.AbsoluteSize.X / k
			local h = hD > 0 and hD or b.AbsoluteSize.Y
			local iw = math.floor((h - BTN_DROP - 6) * 0.98)
			local gap = lbl.Text ~= "" and 4 or 0
			local size = maxSize
			local function width(sz) return lbl.Text ~= "" and TextService:GetTextSize(lbl.Text, sz, lbl.Font, Vector2.new(4000, 200)).X or 0 end
			local tw = width(size)
			-- a narrow button: the text gives way down to 15, then the icon down to 60%, then the text again
			while size > 15 and tw + iw + gap > w - 12 do size -= 1; tw = width(size) end
			local iwMin = math.floor(iw * 0.6)
			while iw > iwMin and tw + iw + gap > w - 12 do iw -= 1 end
			while size > 9 and tw + iw + gap > w - 12 do size -= 1; tw = width(size) end
			lbl.TextSize = size
			local x0 = math.max(4, (w - (tw + gap + iw)) / 2)
			ic.Size = UDim2.fromOffset(iw, iw)
			rest[ic] = UDim2.new(0, x0, 0.5, -BTN_DROP / 2)
			rest[lbl] = UDim2.new(0, x0 + iw + gap, 0, 2)
			restSize[lbl] = UDim2.new(0, tw + 6, 1, -BTN_DROP - 4)
			lbl.Size = restSize[lbl]
			apply()
		end
		b:GetPropertyChangedSignal("AbsoluteSize"):Connect(place)
		lbl:GetPropertyChangedSignal("Text"):Connect(place)
		place()
	end
	if props.Shine then UI.shine(b, z) end
	local sc = new("UIScale", { Parent = b })
	local hover = false
	local function pressTo(y, t, style)
		if bg:GetAttribute("Skin") == "plain" then
			-- (a flat button, the close X: no base to sink onto, it shrinks a little instead)
			UI.tween(sc, t, { Scale = y > 0 and 0.92 or (hover and 1.05 or 1) }, style)
			return
		end
		if y > 0 then capture() end
		local tw = UI.tween(press, t, { Value = y }, style)
		if y == 0 then tw.Completed:Connect(function(st) if st == Enum.PlaybackState.Completed then release() end end) end
	end
	-- hover: the face lights up a little; nothing grows or moves (a growing button pushed or covered its neighbours)
	local function hoverTo(on)
		if bg:GetAttribute("Skin") == "plain" then
			UI.tween(sc, 0.12, { Scale = on and 1.05 or 1 })
			return
		end
		bg:SetAttribute("Hover", on)
	end
	b.MouseEnter:Connect(function()
		if not UIS.MouseEnabled then return end -- (a finger has no hover: it would stay big)
		hover = true
		hoverTo(true)
	end)
	b.MouseLeave:Connect(function()
		hover = false
		hoverTo(false)
		pressTo(0, 0.1)
	end)
	b.MouseButton1Down:Connect(function()
		recentPress[b:GetFullName()] = os.clock()
		pressTo(BTN_PRESS, 0.05)
	end)
	b.MouseButton1Up:Connect(function() pressTo(0, 0.18, Enum.EasingStyle.Back) end)
	b.Activated:Connect(function() recentPress[b:GetFullName()] = os.clock() end)
	task.defer(function()
		-- (deferred: the caller names and places the button first)
		if not b.Parent or bg:GetAttribute("Skin") == "plain" then return end
		local key = b:GetFullName()
		local t = recentPress[key]
		if not t or os.clock() - t > 0.6 then return end
		recentPress[key] = nil
		capture()
		press.Value = BTN_PRESS
		task.wait(0.06)
		if b.Parent then pressTo(0, 0.24, Enum.EasingStyle.Back) end
	end)
	b.InputEnded:Connect(function(io)
		if io.UserInputType == Enum.UserInputType.Touch or io.UserInputType == Enum.UserInputType.MouseButton1 then pressTo(0, 0.18, Enum.EasingStyle.Back) end
	end)
	if props and props.Parent then b.Parent = props.Parent end
	return b
end

-- a clean drawn X (close buttons): two rounded white bars with an ink outline
function UI.drawX(btn, z, yOff)
	z = z or (btn.ZIndex + 2)
	local l = btn:FindFirstChild("Label")
	if l then l.Visible = false end
	for pass = 1, 2 do
		for _, r in ipairs({ 45, -45 }) do
			local bar = new("Frame", { Name = pass == 1 and "XInk" or "XBar", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, yOff or 0),
				Size = pass == 1 and UDim2.new(0.5, 6, 0.12, 6) or UDim2.new(0.5, 0, 0.12, 0), Rotation = r, BorderSizePixel = 0,
				BackgroundColor3 = pass == 1 and T.ink or Color3.new(1, 1, 1), ZIndex = z + pass, Parent = btn })
			new("UICorner", { CornerRadius = UDim.new(0.5, 0), Parent = bar })
		end
	end
end

-- close button: a plain red rounded square with an ink outline and the X, nothing else (no 3D lip, no gloss, no shadow)
function UI.closeStyle(btn, z)
	local bg = btn:FindFirstChild("Bg")
	if bg then
		bg:SetAttribute("Skin", "plain") -- (the button's own colouring stops here)
		local base = btn:FindFirstChild("Base")
		if base then base:Destroy() end
		bg.Size = UDim2.fromScale(1, 1)
		for _, d in ipairs(bg:GetChildren()) do d:Destroy() end
		bg.ImageTransparency = 1
		bg.BackgroundTransparency = 0
		local red = Color3.fromRGB(235, 64, 72)
		bg.BackgroundColor3 = red
		new("UICorner", { CornerRadius = UDim.new(0, 14), Parent = bg })
		new("UIStroke", { Thickness = 3, Color = T.ink, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = bg })
		btn.MouseEnter:Connect(function() bg.BackgroundColor3 = red:Lerp(Color3.new(1, 1, 1), 0.12) end)
		btn.MouseLeave:Connect(function() bg.BackgroundColor3 = red end)
	end
	UI.drawX(btn, z, 0)
end

-- recolour a button made by UI.button
function UI.recolor(b, color)
	local bg = b:FindFirstChild("Bg")
	if bg then bg:SetAttribute("Color", color); bg.ImageColor3 = color end
end

-- progress bar: dark inset well + a glossy tinted fill (callers resize the returned fill)
function UI.bar(props, c1, c2)
	local f = new("Frame", { BackgroundTransparency = 1, BorderSizePixel = 0 })
	for k, v in pairs(props or {}) do if k ~= "Parent" and k ~= "Radius" then f[k] = v end end
	local z = f.ZIndex
	UI.slice("inset", { Name = "Well", SliceScale = 0.4, ZIndex = z, Parent = f })
	local fill = UI.slice("fill", { Name = "Fill", SliceScale = 0.4, ImageColor3 = c2 and c1:Lerp(c2, 0.4) or c1, Size = UDim2.fromScale(0, 1), ZIndex = z, Parent = f })
	if props and props.Parent then f.Parent = props.Parent end
	return f, fill
end

-- a row of tabs (sub-menus) at the top of a window; returns the row frame
-- a window can register a fixed tab bar for its scrolling list: tabs made "in" the list go to the bar instead
-- UI.tabHosts[listFrame] = { bar = Frame, changed = function() end }
UI.tabHosts = setmetatable({}, { __mode = "k" })
function UI.tabs(parent, list, current, onPick, props)
	props = props or {}
	local host = UI.tabHosts[parent]
	if host then
		for _, o in ipairs(host.bar:GetChildren()) do o:Destroy() end
		parent = host.bar
	end
	local row = new("Frame", { Name = "Tabs", Size = UDim2.new(1, 0, 0, 54), BackgroundTransparency = 1, LayoutOrder = props.LayoutOrder or -100, ZIndex = 21, Parent = parent })
	new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder, VerticalAlignment = Enum.VerticalAlignment.Center, Parent = row })
	for i, t in ipairs(list) do
		local on = t.id == current
		local col = on and (t.c1 and (t.c2 and t.c1:Lerp(t.c2, 0.35) or t.c1) or T.accent) or UI.TAB_OFF
		local b = UI.button(t.label, col, nil, { Size = UDim2.new(1 / #list, -8 * (#list - 1) / #list, 0, 50), TextSize = 19, LayoutOrder = i, ZIndex = 23,
			Icon = t.icon, Parent = row })
		b.Name = "Tab_" .. t.id
		if not on then
			local l = b:FindFirstChild("Label")
			if l then l.TextColor3 = Color3.fromRGB(200, 206, 244) end
			local sh = b.Bg:FindFirstChild("Shine")
			if sh then sh.ImageTransparency = 0.55 end
			local ic = b:FindFirstChild("Icon")
			if ic and ic:IsA("ImageLabel") then ic.ImageTransparency = 0.2 end
		end
		if t.badge == true then
			-- just a red dot (something to do on this tab)
			local d = new("Frame", { Name = "Dot", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(1, -8, 0, 6), Size = UDim2.fromOffset(18, 18),
				BackgroundColor3 = Color3.fromRGB(255, 52, 84), BorderSizePixel = 0, ZIndex = 26, Parent = b })
			new("UICorner", { CornerRadius = UDim.new(1, 0), Parent = d })
			new("UIStroke", { Thickness = 2.5, Color = T.ink, Parent = d })
		elseif type(t.badge) == "number" and t.badge > 0 then
			local d = UI.slice("circle", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(1, -6, 0, 4), Size = UDim2.fromOffset(24, 24), SliceScale = 0.2,
				ImageColor3 = Color3.fromRGB(255, 60, 90), ZIndex = 26, Parent = b })
			local dl = new("TextLabel", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = tostring(t.badge), Font = Enum.Font.FredokaOne, TextSize = 15,
				TextColor3 = Color3.new(1, 1, 1), ZIndex = 27, Parent = d })
			UI.badgeText(dl, t.badge)
			new("UIStroke", { Thickness = 1.5, Color = T.ink, Parent = dl })
		end
		b.Activated:Connect(function() if not on then onPick(t.id) end end)
	end
	if host then
		row.Size = UDim2.fromScale(1, 1)
		host.changed()
	end
	return row
end

return UI
