-- BlockRise 2.0 - the UI kit v2 (PREMIUM_UI, 2026-10-18): chunky, bright and rounded like the top simulators, with
-- depth everywhere. One font (FredokaOne), white text with a dark outline. Buttons: a gradient face, a light bevel,
-- a gloss on the top half, a darker lip under them that the face presses onto, a soft shadow, a shimmer sweeping
-- over the important ones. Panels: a soft shadow, a white-to-blue body with a faint dot pattern, a glossy coloured
-- header ribbon with an icon. Plus: segmented tabs, progress bars, chips, badges, glows and light rays.
-- Everything is built in code (no images besides the icon atlas).
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local TextService = game:GetService("TextService")
local UserInputService = game:GetService("UserInputService")
local UI = {}

local C3 = Color3.fromRGB
local WHITE = Color3.new(1, 1, 1)
local BLACK = Color3.new(0, 0, 0)
UI.Font = Enum.Font.FredokaOne
UI.Ink = C3(24, 32, 70)          -- outlines and dark text
UI.Muted = C3(100, 110, 152)     -- secondary text on light panels
UI.Colors = {
	green = { C3(126, 240, 104), C3(36, 180, 76) },
	gold = { C3(255, 230, 100), C3(255, 160, 22) },
	orange = { C3(255, 190, 96), C3(244, 110, 30) },
	blue = { C3(110, 202, 255), C3(36, 114, 236) },
	teal = { C3(104, 238, 222), C3(18, 166, 170) },
	purple = { C3(198, 148, 255), C3(122, 68, 232) },
	red = { C3(255, 124, 124), C3(224, 48, 66) },
	pink = { C3(255, 158, 214), C3(230, 70, 156) },
	grey = { C3(208, 214, 230), C3(138, 146, 170) },
	white = { C3(255, 255, 255), C3(226, 234, 252) },
	navy = { C3(72, 88, 156), C3(32, 42, 96) },
	dark = { C3(50, 60, 110), C3(22, 28, 66) },
}
UI.Panel = { C3(255, 255, 255), C3(212, 226, 255) }
UI.Dark = C3(18, 24, 58)          -- the HUD capsules (over the world)

local touchOnly = UserInputService.TouchEnabled and not UserInputService.MouseEnabled

function UI.new(class, props, children)
	local o = Instance.new(class)
	if o:IsA("GuiObject") then o.BorderSizePixel = 0 end
	if props then for k, v in pairs(props) do if k ~= "Parent" then o[k] = v end end end
	if children then for _, c in ipairs(children) do c.Parent = o end end
	if props and props.Parent then o.Parent = props.Parent end
	return o
end
local new = UI.new

function UI.darker(c, k) return c:Lerp(BLACK, k or 0.35) end
function UI.lighter(c, k) return c:Lerp(WHITE, k or 0.35) end
function UI.corner(o, r) return new("UICorner", { CornerRadius = typeof(r) == "UDim" and r or UDim.new(0, r or 12), Parent = o }) end
function UI.stroke(o, th, col, tr) return new("UIStroke", { Thickness = th or 3, Color = col or UI.Ink, Transparency = tr or 0, LineJoinMode = Enum.LineJoinMode.Round, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = o }) end
function UI.gradient(o, top, bottom, rot) return new("UIGradient", { Color = ColorSequence.new(top, bottom), Rotation = rot or 90, Parent = o }) end
-- a transparency gradient (a at the top, b at the bottom)
function UI.fade(o, a, b, rot) return new("UIGradient", { Transparency = NumberSequence.new(a, b), Rotation = rot or 90, Parent = o }) end
function UI.pad(o, l, t, r, b) return new("UIPadding", { PaddingLeft = UDim.new(0, l or 0), PaddingTop = UDim.new(0, t or l or 0), PaddingRight = UDim.new(0, r or l or 0), PaddingBottom = UDim.new(0, b or t or l or 0), Parent = o }) end
function UI.textWidth(text, size) return TextService:GetTextSize(text, size, UI.Font, Vector2.new(4000, 400)).X end

-- outlined text (white with a dark outline unless told otherwise). Shadow = true (or px): a dark copy under it
function UI.text(props)
	local t = new("TextLabel", {
		BackgroundTransparency = 1, Font = props.Font or UI.Font, Text = props.Text or "", TextColor3 = props.Color or WHITE,
		TextScaled = props.Scaled ~= false, TextSize = props.TextSize or 20, Size = props.Size or UDim2.fromScale(1, 1),
		Position = props.Position or UDim2.new(), AnchorPoint = props.AnchorPoint or Vector2.zero, TextXAlignment = props.XAlign or Enum.TextXAlignment.Center,
		TextYAlignment = props.YAlign or Enum.TextYAlignment.Center, ZIndex = props.ZIndex or 2, Name = props.Name or "Text", RichText = props.Rich == true,
		LayoutOrder = props.Order or 0, TextWrapped = props.Wrap == true, Rotation = props.Rotation or 0,
	})
	if props.Stroke ~= false then UI.stroke(t, props.StrokeTh or 2.2, props.StrokeColor or UI.Ink).ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual end
	if props.Max then new("UITextSizeConstraint", { MaxTextSize = props.Max, MinTextSize = props.Min or 8, Parent = t }) end
	if props.Gradient then UI.gradient(t, props.Gradient[1], props.Gradient[2]) end
	if props.Shadow then
		local sh = t:Clone()
		sh.Name = "TextShadow"
		sh.TextColor3 = props.ShadowColor or UI.Ink
		for _, g in ipairs(sh:GetChildren()) do if g:IsA("UIGradient") then g:Destroy() end end
		local px = props.Shadow == true and 3 or props.Shadow
		sh.Position = t.Position + UDim2.fromOffset(0, px)
		sh.ZIndex = math.max(1, t.ZIndex - 1)
		t:GetPropertyChangedSignal("Text"):Connect(function() sh.Text = t.Text end)
		t:GetPropertyChangedSignal("Visible"):Connect(function() sh.Visible = t.Visible end)
		t:GetPropertyChangedSignal("Position"):Connect(function() sh.Position = t.Position + UDim2.fromOffset(0, px) end)
		sh.Parent = props.Parent
	end
	t.Parent = props.Parent
	return t
end

-- Moving things, all on one heartbeat: shimmers (a light band sweeping over), spinners (rays), bobbers
local shimmers, spinners = {}, {}
RunService.Heartbeat:Connect(function(dt)
	local now = os.clock()
	for i = #shimmers, 1, -1 do
		local s = shimmers[i]
		if s.g.Parent == nil then
			table.remove(shimmers, i)
		else
			local ph = ((now + s.seed) % s.period) / s.sweep
			s.g.Offset = Vector2.new(ph <= 1 and (-1.2 + 2.4 * ph) or 1.2, 0)
		end
	end
	for i = #spinners, 1, -1 do
		local s = spinners[i]
		if s.o.Parent == nil then table.remove(spinners, i) else s.o.Rotation = (s.o.Rotation + dt * s.speed) % 360 end
	end
end)

-- a light band sweeping over o every few seconds (o's own shape: give the radius)
function UI.shimmer(o, radius, props)
	props = props or {}
	local f = new("Frame", { Name = "Shimmer", BackgroundColor3 = WHITE, Size = UDim2.fromScale(1, 1), ZIndex = props.ZIndex or (o.ZIndex + 2), Parent = o })
	UI.corner(f, radius or 14)
	local g = new("UIGradient", { Rotation = 18, Offset = Vector2.new(-1.2, 0), Parent = f,
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.40, 1), NumberSequenceKeypoint.new(0.47, props.Strength or 0.5),
			NumberSequenceKeypoint.new(0.53, props.Strength or 0.5), NumberSequenceKeypoint.new(0.60, 1), NumberSequenceKeypoint.new(1, 1) }) })
	table.insert(shimmers, { g = g, seed = math.random() * 4, period = props.Period or 3.4, sweep = props.Sweep or 0.85 })
	return f
end

function UI.spin(o, speed) table.insert(spinners, { o = o, speed = speed or 20 }) return o end

-- a gloss: the top part lighter (a white frame fading out downwards)
function UI.gloss(o, radius, props)
	props = props or {}
	local f = new("Frame", { Name = "Shine", BackgroundColor3 = WHITE, Size = props.Size or UDim2.new(1, -10, 0.46, 0), Position = props.Position or UDim2.fromOffset(5, 3),
		ZIndex = props.ZIndex or (o.ZIndex + 1), Parent = o })
	UI.corner(f, radius or 10)
	UI.fade(f, props.From or 0.45, props.To or 0.9)
	return f
end

-- a 3D button: color = a UI.Colors key. props: Name, Color, Text, Sub (a second, smaller line), Icon (an instance) or
-- IconKey (an atlas key), Size, Position, AnchorPoint, Order, ZIndex, Radius, Max, Depth, Shimmer, OnClick, TextColor.
-- Returns the button (TextButton "Face"), its holder and its label
function UI.button(props)
	local key = props.Color or "green"
	local col = UI.Colors[key] or UI.Colors.green
	local r = props.Radius or 14
	local z = props.ZIndex or 1
	local depth = props.Depth or 5
	local holder = new("Frame", { Name = props.Name or "Button", BackgroundTransparency = 1, Size = props.Size or UDim2.fromOffset(160, 56),
		Position = props.Position or UDim2.new(), AnchorPoint = props.AnchorPoint or Vector2.zero, LayoutOrder = props.Order or 0, ZIndex = z })
	local sc = new("UIScale", { Parent = holder })
	local shadow = new("Frame", { Name = "Shadow", BackgroundColor3 = BLACK, BackgroundTransparency = 0.78, Size = UDim2.fromScale(1, 1), Position = UDim2.fromOffset(0, depth + 4), ZIndex = z, Parent = holder })
	UI.corner(shadow, r)
	local lip = new("Frame", { Name = "Lip", BackgroundColor3 = UI.darker(col[2], 0.4), Size = UDim2.fromScale(1, 1), Position = UDim2.fromOffset(0, depth), ZIndex = z, Parent = holder })
	UI.corner(lip, r)
	UI.stroke(lip, 3)
	local btn = new("TextButton", { Name = "Face", Text = "", AutoButtonColor = false, BackgroundColor3 = WHITE, Size = UDim2.fromScale(1, 1), ZIndex = z + 1, Parent = holder })
	btn:SetAttribute("Color", key)
	UI.corner(btn, r)
	UI.stroke(btn, 3)
	UI.gradient(btn, col[1], col[2])
	local bevel = new("Frame", { Name = "Bevel", BackgroundTransparency = 1, Size = UDim2.new(1, -6, 1, -6), Position = UDim2.fromOffset(3, 3), ZIndex = z + 2, Parent = btn })
	UI.corner(bevel, math.max(3, r - 3))
	UI.stroke(bevel, 1.6, WHITE, 0.6)
	UI.gloss(btn, math.max(3, r - 5), { ZIndex = z + 2, Size = UDim2.new(1, -10, 0.46, 0), Position = UDim2.fromOffset(5, 3) })
	if props.Shimmer then
		local sh = UI.shimmer(btn, r, { ZIndex = z + 2 })
		sh.Visible = key ~= "grey"
	end
	-- the content: an icon on the left (optional), the label, a second line (optional)
	local h = (props.Size and props.Size.Y.Scale == 0 and props.Size.Y.Offset > 0) and props.Size.Y.Offset or 50
	local icon = props.Icon
	if props.IconKey then
		icon = UI.icon(props.IconKey, { Size = UDim2.fromOffset(math.floor(h * 0.86), math.floor(h * 0.86)), Position = UDim2.new(0, 4, 0.5, -math.floor(h * 0.43)) })
	end
	if icon then
		icon.Parent = btn
		icon.ZIndex = z + 3
	end
	local leftPad = (props.IconKey and math.floor(h * 0.86) + 6) or (props.Icon and 40) or 8
	local label
	if props.Text then
		local main = props.Sub and UDim2.new(1, -(leftPad + 8), 0.52, 0) or UDim2.new(1, -(leftPad + 8), 0.66, 0)
		local pos = props.Sub and UDim2.new(0, leftPad, 0.08, 0) or UDim2.new(0, leftPad, 0.17, 0)
		label = UI.text({ Text = props.Text, Parent = btn, Size = main, Position = pos, ZIndex = z + 4, Max = props.Max or 30, Name = "Label",
			StrokeTh = props.StrokeTh or 2.4, Color = props.TextColor })
		if props.Sub then
			UI.text({ Text = props.Sub, Parent = btn, Size = UDim2.new(1, -(leftPad + 8), 0.34, 0), Position = UDim2.new(0, leftPad, 0.58, 0), ZIndex = z + 4,
				Max = props.SubMax or 18, Name = "Sub", StrokeTh = 2, Color = props.SubColor or C3(255, 250, 200) })
		end
	end
	-- press: the face sinks onto the lip; hover: it grows a little
	local function down() TweenService:Create(btn, TweenInfo.new(0.05), { Position = UDim2.fromOffset(0, depth - 1) }):Play() end
	local function up() TweenService:Create(btn, TweenInfo.new(0.16, Enum.EasingStyle.Back), { Position = UDim2.fromOffset(0, 0) }):Play() end
	btn.MouseButton1Down:Connect(down)
	btn.MouseButton1Up:Connect(up)
	if not touchOnly then
		btn.MouseEnter:Connect(function() TweenService:Create(sc, TweenInfo.new(0.12, Enum.EasingStyle.Quad), { Scale = 1.05 }):Play() end)
		btn.MouseLeave:Connect(function() up() TweenService:Create(sc, TweenInfo.new(0.12, Enum.EasingStyle.Quad), { Scale = 1 }):Play() end)
	else
		btn.MouseLeave:Connect(up)
	end
	if props.OnClick then btn.Activated:Connect(function() UI.click() props.OnClick() end) end
	holder.Parent = props.Parent
	return btn, holder, label
end
function UI.recolor(btn, color)
	local col = UI.Colors[color]
	if not col or btn:GetAttribute("Color") == color then return end
	btn:SetAttribute("Color", color)
	local g = btn:FindFirstChildOfClass("UIGradient")
	if g then g.Color = ColorSequence.new(col[1], col[2]) end
	local lip = btn.Parent:FindFirstChild("Lip")
	if lip then lip.BackgroundColor3 = UI.darker(col[2], 0.4) end
	local sh = btn:FindFirstChild("Shimmer")
	if sh then sh.Visible = color ~= "grey" end
end

-- a glyph of rounded bars on a button (an X, a +): first the dark outlines, then the white bars over them
local function glyph(btn, s, angles)
	local th = math.max(6, math.floor(s * 0.17))
	for pass = 1, 2 do
		for _, rot in ipairs(angles) do
			local bar = new("Frame", { Name = "Glyph", BackgroundColor3 = pass == 1 and UI.Ink or WHITE, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
				Size = pass == 1 and UDim2.new(0.58, 5, 0, th + 5) or UDim2.new(0.58, 0, 0, th), Rotation = rot, ZIndex = btn.ZIndex + (pass == 1 and 3 or 4), Parent = btn })
			UI.corner(bar, UDim.new(1, 0))
		end
	end
end

-- a round close button (red, an X)
function UI.close(props)
	local s = props.Size or 50
	local btn, holder = UI.button({ Name = "Close", Color = "red", Size = UDim2.fromOffset(s, s), Position = props.Position, AnchorPoint = props.AnchorPoint, Radius = math.floor(s / 2),
		ZIndex = props.ZIndex, Parent = props.Parent, OnClick = props.OnClick, Depth = 4 })
	glyph(btn, s, { 45, -45 })
	return btn, holder
end

-- a round + button (more cash, more Gems)
function UI.plus(props)
	local s = props.Size or 40
	local btn, holder = UI.button({ Name = props.Name or "Plus", Color = props.Color or "green", Size = UDim2.fromOffset(s, s), Position = props.Position, AnchorPoint = props.AnchorPoint,
		Radius = math.floor(s / 2), ZIndex = props.ZIndex, Parent = props.Parent, OnClick = props.OnClick, Depth = 4 })
	glyph(btn, s, { 0, 90 })
	return btn, holder
end

-- a pill (a counter, a tag): a rounded bar. Style "dark": the translucent navy capsule of the HUD
function UI.pill(props)
	local f = new("Frame", { Name = props.Name or "Pill", BackgroundColor3 = WHITE, Size = props.Size or UDim2.fromOffset(220, 52),
		Position = props.Position or UDim2.new(), AnchorPoint = props.AnchorPoint or Vector2.zero, ZIndex = props.ZIndex or 2, LayoutOrder = props.Order or 0 })
	UI.corner(f, props.Radius or UDim.new(1, 0))
	if props.Style == "dark" then
		f.BackgroundColor3 = UI.Dark
		f.BackgroundTransparency = props.Transparency or 0.08
		UI.stroke(f, props.StrokeTh or 3, UI.Ink)
		UI.gradient(f, C3(255, 255, 255), C3(200, 210, 240))
		local inner = new("Frame", { Name = "Bevel", BackgroundTransparency = 1, Size = UDim2.new(1, -6, 1, -6), Position = UDim2.fromOffset(3, 3), ZIndex = f.ZIndex, Parent = f })
		UI.corner(inner, props.Radius or UDim.new(1, 0))
		UI.stroke(inner, 1.5, WHITE, 0.82)
	else
		UI.stroke(f, props.StrokeTh or 3, UI.Ink)
		local col = UI.Colors[props.Color or "white"] or UI.Colors.white
		UI.gradient(f, col[1], col[2])
		if props.Gloss ~= false then UI.gloss(f, props.Radius or UDim.new(1, 0), { ZIndex = f.ZIndex + 1, Size = UDim2.new(1, -14, 0.44, 0), Position = UDim2.fromOffset(7, 2), From = 0.5, To = 0.92 }) end
	end
	f.Parent = props.Parent
	return f
end

-- a chip: a small pill with an icon and a text that sizes itself. Returns { frame, label, set(text) }
function UI.chip(props)
	local h = props.Height or 30
	local ts = props.TextSize or math.floor(h * 0.6)
	local iconS = math.floor(h * 1.25)
	local left = props.Icon and (iconS - 6) or 12
	local f = UI.pill({ Name = props.Name or "Chip", Color = props.Color or "green", Style = props.Style, Size = UDim2.fromOffset(100, h), Position = props.Position,
		AnchorPoint = props.AnchorPoint, StrokeTh = 2.5, ZIndex = props.ZIndex, Order = props.Order, Parent = props.Parent })
	if props.Icon then UI.icon(props.Icon, { Size = UDim2.fromOffset(iconS, iconS), Position = UDim2.new(0, -8, 0.5, -iconS / 2), ZIndex = f.ZIndex + 3, Parent = f }) end
	local lbl = UI.text({ Text = "", Scaled = false, TextSize = ts, Size = UDim2.new(1, -left - 10, 1, 0), Position = UDim2.fromOffset(left, 0), XAlign = Enum.TextXAlignment.Left,
		ZIndex = f.ZIndex + 2, StrokeTh = props.StrokeTh or 2, Color = props.TextColor, Parent = f })
	local self = { frame = f, label = lbl }
	function self.set(text)
		lbl.Text = text
		f.Size = UDim2.fromOffset(left + UI.textWidth(text, ts) + 14, h)
	end
	self.set(props.Text or "")
	return self
end

-- a notification badge on a corner (red, a count or "!")
function UI.badge(parent, text, color)
	local col = UI.Colors[color or "red"]
	local b = new("Frame", { Name = "Badge", BackgroundColor3 = WHITE, Size = UDim2.fromOffset(30, 30), Position = UDim2.new(1, -20, 0, -10), ZIndex = 30, Parent = parent })
	UI.corner(b, UDim.new(1, 0))
	UI.stroke(b, 2.5)
	UI.gradient(b, col[1], col[2])
	local t = UI.text({ Text = text or "!", ZIndex = 31, StrokeTh = 1.8, Size = UDim2.new(1, -8, 1, -8), Position = UDim2.fromOffset(4, 4), Max = 18, Parent = b })
	return b, t
end

-- a progress bar: a dark track, a glossy coloured fill with a shimmer, a label. Returns { frame, fill, label, set(p, text) }
function UI.progress(props)
	local col = UI.Colors[props.Color or "green"]
	local h = (props.Size and props.Size.Y.Offset > 0) and props.Size.Y.Offset or 24
	local f = new("Frame", { Name = props.Name or "Progress", BackgroundColor3 = props.Track or C3(30, 38, 84), BackgroundTransparency = props.TrackTransparency or 0, Size = props.Size or UDim2.fromOffset(240, 24),
		Position = props.Position or UDim2.new(), AnchorPoint = props.AnchorPoint or Vector2.zero, ZIndex = props.ZIndex or 2, Parent = props.Parent })
	UI.corner(f, UDim.new(1, 0))
	UI.stroke(f, props.StrokeTh or 3)
	-- the track's inner shadow (top)
	local inset = new("Frame", { Name = "Inset", BackgroundColor3 = BLACK, BackgroundTransparency = 0.6, Size = UDim2.new(1, -4, 0.5, 0), Position = UDim2.fromOffset(2, 1), ZIndex = f.ZIndex, Parent = f })
	UI.corner(inset, UDim.new(1, 0))
	UI.fade(inset, 0.55, 1)
	local fill = new("Frame", { Name = "Fill", BackgroundColor3 = WHITE, Size = UDim2.fromScale(0, 1), ZIndex = f.ZIndex + 1, Parent = f })
	UI.corner(fill, UDim.new(1, 0))
	local fg = UI.gradient(fill, col[1], col[2])
	new("UISizeConstraint", { MinSize = Vector2.new(h, 0), Parent = fill })
	UI.gloss(fill, UDim.new(1, 0), { ZIndex = fill.ZIndex + 1, Size = UDim2.new(1, -8, 0.42, 0), Position = UDim2.fromOffset(4, 2), From = 0.35, To = 0.85 })
	UI.shimmer(fill, UDim.new(1, 0), { ZIndex = fill.ZIndex + 1, Strength = 0.55, Period = 2.6 })
	local label = UI.text({ Text = props.Text or "", Size = UDim2.new(1, -16, 0.86, 0), Position = UDim2.new(0, 8, 0.07, 0), ZIndex = f.ZIndex + 4, StrokeTh = props.TextStroke or 2.4,
		Max = props.Max or 22, Parent = f })
	local self = { frame = f, fill = fill, label = label, value = -1 }
	function self.set(p, text, instant)
		p = math.clamp(p or 0, 0, 1)
		if text then label.Text = text end
		if math.abs(p - self.value) < 0.0005 then return end
		self.value = p
		fill.Visible = p > 0.001
		if instant then fill.Size = UDim2.fromScale(p, 1)
		else TweenService:Create(fill, TweenInfo.new(0.25, Enum.EasingStyle.Quad), { Size = UDim2.fromScale(p, 1) }):Play() end
	end
	function self.color(key)
		local c = UI.Colors[key]
		fg.Color = ColorSequence.new(c[1], c[2])
	end
	return self
end

-- a soft round glow (three discs)
function UI.glow(parent, color, props)
	props = props or {}
	local f = new("Frame", { Name = "Glow", BackgroundTransparency = 1, Size = props.Size or UDim2.fromScale(1, 1), Position = props.Position or UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = props.ZIndex or 1, Parent = parent })
	for _, k in ipairs({ { 1, 0.86 }, { 0.76, 0.76 }, { 0.52, 0.62 } }) do
		local c = new("Frame", { BackgroundColor3 = color, BackgroundTransparency = k[2], AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(k[1], k[1]), ZIndex = f.ZIndex, Parent = f })
		UI.corner(c, UDim.new(1, 0))
	end
	return f
end

-- light rays turning slowly behind a prize
function UI.rays(parent, color, props)
	props = props or {}
	local f = new("Frame", { Name = "Rays", BackgroundTransparency = 1, Size = props.Size or UDim2.fromScale(1, 1), Position = props.Position or UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = props.ZIndex or 1, Parent = parent })
	local n = props.Count or 8
	for i = 1, n do
		local ray = new("Frame", { BackgroundColor3 = color or WHITE, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(props.Width or 0.16, 1),
			Rotation = (i - 1) * (180 / n), ZIndex = f.ZIndex, Parent = f })
		new("UIGradient", { Rotation = 90, Parent = ray, Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, props.Strength or 0.55), NumberSequenceKeypoint.new(1, 1) }) })
	end
	UI.spin(f, props.Speed or 18)
	return f
end

-- a faint dot pattern inside a panel (kept clear of the rounded corners by `inset`)
function UI.dots(parent, props)
	props = props or {}
	local inset = props.Inset or 10
	local area = new("Frame", { Name = "Pattern", BackgroundTransparency = 1, ClipsDescendants = true, Size = UDim2.new(1, -2 * inset, 1, -(props.Top or inset) - inset),
		Position = UDim2.fromOffset(inset, props.Top or inset), ZIndex = props.ZIndex or parent.ZIndex, Parent = parent })
	local step = props.Step or 30
	local w, h = props.W or 1000, props.H or 700
	for y = 0, math.ceil(h / step) do
		for x = 0, math.ceil(w / step) do
			local d = new("Frame", { BackgroundColor3 = props.Color or C3(120, 150, 230), BackgroundTransparency = props.Transparency or 0.84, Size = UDim2.fromOffset(6, 6),
				Position = UDim2.fromOffset(x * step + ((y % 2 == 1) and step / 2 or 0) + 4, y * step + 4), ZIndex = area.ZIndex, Parent = area })
			UI.corner(d, UDim.new(1, 0))
		end
	end
	return area
end

-- a header ribbon on top of a panel body: glossy, coloured, an icon popping out on the left, the title
function UI.header(body, props)
	local r = props.Radius or 22
	local h = props.HeadHeight or 62
	local col = UI.Colors[props.Color or "blue"]
	local head = new("Frame", { Name = "Head", BackgroundColor3 = WHITE, Size = UDim2.new(1, 0, 0, h), ZIndex = 4, Parent = body })
	UI.corner(head, r)
	local grad = UI.gradient(head, col[1], col[2])
	-- square bottom corners: a strip in the colour of the ribbon's lower part
	local fill = new("Frame", { Name = "Fill", BackgroundColor3 = WHITE, Size = UDim2.new(1, 0, 0, r), Position = UDim2.new(0, 0, 1, -r), ZIndex = 4, Parent = head })
	local fillGrad = UI.gradient(fill, col[1]:Lerp(col[2], (h - r) / h), col[2])
	new("Frame", { Name = "Edge", BackgroundColor3 = UI.Ink, Size = UDim2.new(1, 0, 0, 4), Position = UDim2.new(0, 0, 1, -2), ZIndex = 6, Parent = head })
	UI.gloss(head, r - 6, { ZIndex = 5, Size = UDim2.new(1, -16, 0, math.floor(h * 0.42)), Position = UDim2.fromOffset(8, 4), From = 0.5, To = 0.94 })
	local tx = 24
	local icon
	if props.Icon then
		icon = UI.icon(props.Icon, { Size = UDim2.fromOffset(h + 16, h + 16), Position = UDim2.new(0, 6, 0.5, -(h + 16) / 2 - 4), ZIndex = 8, Parent = head })
		icon.Rotation = -8
		tx = h + 26
	end
	local title = UI.text({ Text = props.Title or "", Size = UDim2.new(1, -(tx + 90), 0, math.floor(h * 0.62)), Position = UDim2.new(0, tx, 0, math.floor(h * 0.16)),
		XAlign = Enum.TextXAlignment.Left, ZIndex = 8, StrokeTh = 3.2, Max = props.TitleMax or 40, Shadow = 3, Gradient = { WHITE, C3(232, 240, 255) }, Parent = head })
	local self = { frame = head, title = title, icon = icon }
	function self.color(key)
		local c = UI.Colors[key]
		grad.Color = ColorSequence.new(c[1], c[2])
		fillGrad.Color = ColorSequence.new(c[1]:Lerp(c[2], (h - r) / h), c[2])
	end
	function self.setIcon(k)
		if icon then UI.setIcon(icon, k) end
	end
	return self
end

-- a panel: a soft shadow, a gradient body with a dark edge and a light bevel, an optional dot pattern and header.
-- Returns the body, the holder and the header ({ frame, title, color(key) } or nil)
function UI.panel(props)
	local r = props.Radius or 22
	local holder = new("Frame", { Name = props.Name or "Panel", BackgroundTransparency = 1, Size = props.Size or UDim2.fromOffset(400, 300), Position = props.Position or UDim2.new(),
		AnchorPoint = props.AnchorPoint or Vector2.zero, ZIndex = props.ZIndex or 1, Visible = props.Visible ~= false, LayoutOrder = props.Order or 0 })
	if props.Shadow ~= false then
		local s2 = new("Frame", { Name = "Shadow2", BackgroundColor3 = BLACK, BackgroundTransparency = 0.88, Size = UDim2.new(1, 14, 1, 14), Position = UDim2.fromOffset(-7, 6), ZIndex = 1, Parent = holder })
		UI.corner(s2, r + 7)
		local s1 = new("Frame", { Name = "Shadow", BackgroundColor3 = BLACK, BackgroundTransparency = 0.7, Size = UDim2.fromScale(1, 1), Position = UDim2.fromOffset(0, 9), ZIndex = 1, Parent = holder })
		UI.corner(s1, r)
	end
	local body = new("Frame", { Name = "Body", BackgroundColor3 = WHITE, Size = UDim2.fromScale(1, 1), ZIndex = 2, Parent = holder })
	UI.corner(body, r)
	UI.stroke(body, props.StrokeTh or 4)
	UI.gradient(body, props.Top or UI.Panel[1], props.Bottom or UI.Panel[2])
	local bev = new("Frame", { Name = "Bevel", BackgroundTransparency = 1, Size = UDim2.new(1, -8, 1, -8), Position = UDim2.fromOffset(4, 4), ZIndex = 2, Parent = body })
	UI.corner(bev, math.max(4, r - 4))
	UI.stroke(bev, 2, WHITE, 0.25)
	if props.Pattern then
		UI.dots(body, { Inset = math.ceil(r * 0.4) + 2, Top = props.Title and (props.HeadHeight or 62) + 4 or nil, W = props.PatternW, H = props.PatternH, ZIndex = 2 })
	end
	local head
	if props.Title then head = UI.header(body, props) end
	holder.Parent = props.Parent
	return body, holder, head
end

-- an inset well (a darker rounded area inside a panel: lists, stats)
function UI.well(props)
	local f = new("Frame", { Name = props.Name or "Well", BackgroundColor3 = props.Color or C3(196, 212, 248), BackgroundTransparency = props.Transparency or 0.35, Size = props.Size,
		Position = props.Position or UDim2.new(), AnchorPoint = props.AnchorPoint or Vector2.zero, ZIndex = props.ZIndex or 3, Parent = props.Parent })
	UI.corner(f, props.Radius or 16)
	UI.stroke(f, 2.5, UI.Ink, 0.55)
	local inset = new("Frame", { Name = "Inset", BackgroundColor3 = UI.Ink, Size = UDim2.new(1, -6, 0, 10), Position = UDim2.fromOffset(3, 2), ZIndex = f.ZIndex, Parent = f })
	UI.corner(inset, 8)
	UI.fade(inset, 0.86, 1)
	return f
end

-- segmented tabs in a track. props: Parent, Items = { { id, text }, ... }, Selected, Color, Size, Position, OnSelect.
-- Returns { frame, set(id) }
function UI.tabs(props)
	local col = UI.Colors[props.Color or "blue"]
	local track = new("Frame", { Name = "Tabs", BackgroundColor3 = C3(200, 214, 246), Size = props.Size or UDim2.fromOffset(420, 52), Position = props.Position or UDim2.new(),
		AnchorPoint = props.AnchorPoint or Vector2.zero, ZIndex = props.ZIndex or 3, Parent = props.Parent })
	UI.corner(track, 18)
	UI.stroke(track, 3)
	local inset = new("Frame", { BackgroundColor3 = UI.Ink, Size = UDim2.new(1, -8, 0, 12), Position = UDim2.fromOffset(4, 2), ZIndex = track.ZIndex, Parent = track })
	UI.corner(inset, 10)
	UI.fade(inset, 0.8, 1)
	local n = #props.Items
	local gap = 6
	local tabs = {}
	local self = { frame = track }
	for i, it in ipairs(props.Items) do
		local b = new("TextButton", { Name = it[1], Text = "", AutoButtonColor = false, BackgroundColor3 = WHITE, BackgroundTransparency = 1, ZIndex = track.ZIndex + 1,
			Size = UDim2.new(1 / n, -(gap * (n + 1)) / n, 1, -2 * gap), Position = UDim2.new((i - 1) / n, gap + (i - 1) * (gap - (gap * (n + 1)) / n) , 0, gap), Parent = track })
		UI.corner(b, 13)
		local st = UI.stroke(b, 3)
		local g = UI.gradient(b, col[1], col[2])
		local sh = UI.gloss(b, 9, { ZIndex = b.ZIndex + 1, Size = UDim2.new(1, -10, 0.44, 0), Position = UDim2.fromOffset(5, 2) })
		local lbl = UI.text({ Text = it[2], Size = UDim2.new(1, -16, 0.62, 0), Position = UDim2.new(0, 8, 0.19, 0), ZIndex = b.ZIndex + 2, Max = props.Max or 22, StrokeTh = 2.4, Parent = b })
		tabs[it[1]] = { b = b, st = st, g = g, sh = sh, lbl = lbl, lst = lbl:FindFirstChildOfClass("UIStroke") }
		b.Activated:Connect(function()
			if self.selected == it[1] then return end
			UI.click()
			self.set(it[1])
			if props.OnSelect then props.OnSelect(it[1]) end
		end)
	end
	function self.set(id)
		self.selected = id
		for k, t in pairs(tabs) do
			local on = k == id
			t.b.BackgroundTransparency = on and 0 or 1
			t.st.Enabled = on
			t.g.Enabled = on
			t.sh.Visible = on
			t.lbl.TextColor3 = on and WHITE or UI.Muted
			t.lst.Enabled = on
		end
	end
	self.set(props.Selected or props.Items[1][1])
	return self
end

-- an icon from the v1 atlas (Shared.Icons)
local Icons = require(game:GetService("ReplicatedStorage").Shared.Icons)
function UI.icon(key, props) return Icons.make(key, props or {}) end
function UI.setIcon(o, key) if Icons.set then pcall(Icons.set, o, key) end end

-- sounds
local SoundService = game:GetService("SoundService")
local function sound(id, vol)
	local s = Instance.new("Sound")
	s.SoundId = id
	s.Volume = vol or 0.5
	s.Parent = SoundService
	return s
end
local clickS = sound("rbxasset://sounds/electronicpingshort.wav", 0.35)
local coinS = sound("rbxassetid://607665037", 0.4)
function UI.click() clickS.PlaybackSpeed = 1.1 + math.random() * 0.1 clickS:Play() end
function UI.coin() coinS:Play() end

-- a number that counts toward its target
function UI.counter(label, format)
	local shown, target = 0, 0
	local conn
	local self = {}
	function self.set(v, instant)
		target = v
		if instant then shown = v label.Text = format(v) return end
		if conn then return end
		conn = RunService.Heartbeat:Connect(function(dt)
			local diff = target - shown
			if math.abs(diff) < math.max(1, math.abs(target) * 0.0005) then
				shown = target
				label.Text = format(shown)
				conn:Disconnect()
				conn = nil
				return
			end
			shown += diff * math.min(1, dt * 9)
			label.Text = format(shown)
		end)
	end
	return self
end

-- a little pop: scale up then back
function UI.pop(o, s)
	local sc = o:FindFirstChildOfClass("UIScale") or new("UIScale", { Parent = o })
	sc.Scale = s or 1.15
	TweenService:Create(sc, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
end

return UI
