-- BlockRise 2.0 - the UI kit (STYLE: chunky, bright, rounded, like the top simulators): one font, white text with a
-- dark outline, 3D buttons (a gradient, a dark edge, a shine on top, a darker lip under them that presses down),
-- white rounded panels with a coloured header. Everything here is built in code, no images needed.
local TweenService = game:GetService("TweenService")
local UI = {}

local C3 = Color3.fromRGB
UI.Font = Enum.Font.FredokaOne
UI.Ink = C3(24, 32, 70)          -- outlines and dark text
UI.Colors = {
	green = { C3(118, 236, 110), C3(46, 186, 80) },
	gold = { C3(255, 226, 92), C3(255, 168, 24) },
	blue = { C3(104, 196, 255), C3(40, 120, 240) },
	purple = { C3(190, 140, 255), C3(124, 74, 236) },
	red = { C3(255, 120, 120), C3(232, 58, 70) },
	pink = { C3(255, 150, 210), C3(236, 76, 160) },
	grey = { C3(200, 206, 222), C3(140, 148, 170) },
	white = { C3(255, 255, 255), C3(232, 238, 252) },
	navy = { C3(70, 86, 150), C3(34, 46, 100) },
}

function UI.new(class, props, children)
	local o = Instance.new(class)
	if o:IsA("GuiObject") then o.BorderSizePixel = 0 end
	if props then for k, v in pairs(props) do if k ~= "Parent" then o[k] = v end end end
	if children then for _, c in ipairs(children) do c.Parent = o end end
	if props and props.Parent then o.Parent = props.Parent end
	return o
end
local new = UI.new

function UI.corner(o, r) return new("UICorner", { CornerRadius = typeof(r) == "UDim" and r or UDim.new(0, r or 12), Parent = o }) end
function UI.stroke(o, th, col, tr) return new("UIStroke", { Thickness = th or 3, Color = col or UI.Ink, Transparency = tr or 0, LineJoinMode = Enum.LineJoinMode.Round, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = o }) end
function UI.gradient(o, top, bottom, rot) return new("UIGradient", { Color = ColorSequence.new(top, bottom), Rotation = rot or 90, Parent = o }) end
function UI.pad(o, l, t, r, b) return new("UIPadding", { PaddingLeft = UDim.new(0, l or 0), PaddingTop = UDim.new(0, t or l or 0), PaddingRight = UDim.new(0, r or l or 0), PaddingBottom = UDim.new(0, b or t or l or 0), Parent = o }) end

-- outlined text (white with a dark outline unless told otherwise)
function UI.text(props)
	local t = new("TextLabel", {
		BackgroundTransparency = 1, Font = props.Font or UI.Font, Text = props.Text or "", TextColor3 = props.Color or Color3.new(1, 1, 1),
		TextScaled = props.Scaled ~= false, TextSize = props.TextSize or 20, Size = props.Size or UDim2.fromScale(1, 1),
		Position = props.Position or UDim2.new(), AnchorPoint = props.AnchorPoint or Vector2.zero, TextXAlignment = props.XAlign or Enum.TextXAlignment.Center,
		TextYAlignment = props.YAlign or Enum.TextYAlignment.Center, ZIndex = props.ZIndex or 2, Name = props.Name or "Text", RichText = props.Rich == true,
		LayoutOrder = props.Order or 0,
	})
	if props.Stroke ~= false then UI.stroke(t, props.StrokeTh or 2.2, props.StrokeColor or UI.Ink).ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual end
	if props.Max then new("UITextSizeConstraint", { MaxTextSize = props.Max, MinTextSize = props.Min or 8, Parent = t }) end
	t.Parent = props.Parent
	return t
end

-- a 3D button: color = a UI.Colors key. Returns the button (TextButton), its holder and its label
function UI.button(props)
	local col = UI.Colors[props.Color or "green"]
	local holder = new("Frame", { Name = props.Name or "Button", BackgroundTransparency = 1, Size = props.Size or UDim2.fromOffset(160, 56),
		Position = props.Position or UDim2.new(), AnchorPoint = props.AnchorPoint or Vector2.zero, LayoutOrder = props.Order or 0, ZIndex = props.ZIndex or 1 })
	local lip = new("Frame", { Name = "Lip", BackgroundColor3 = col[2]:Lerp(Color3.new(0, 0, 0), 0.35), Size = UDim2.new(1, 0, 1, 0), Position = UDim2.fromOffset(0, 5), ZIndex = holder.ZIndex, Parent = holder })
	UI.corner(lip, props.Radius or 14)
	UI.stroke(lip, 3, UI.Ink)
	local btn = new("TextButton", { Name = "Face", Text = "", AutoButtonColor = false, BackgroundColor3 = Color3.new(1, 1, 1), Size = UDim2.fromScale(1, 1),
		ZIndex = holder.ZIndex + 1, Parent = holder })
	UI.corner(btn, props.Radius or 14)
	UI.stroke(btn, 3, UI.Ink)
	UI.gradient(btn, col[1], col[2])
	local shine = new("Frame", { Name = "Shine", BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.6, Size = UDim2.new(1, -14, 0.32, 0),
		Position = UDim2.new(0, 7, 0, 5), ZIndex = btn.ZIndex + 1, Parent = btn })
	UI.corner(shine, UDim.new(1, 0))
	local label
	if props.Text then
		label = UI.text({ Text = props.Text, Parent = btn, Size = props.Icon and UDim2.new(1, -46, 0.72, 0) or UDim2.new(1, -16, 0.72, 0),
			Position = props.Icon and UDim2.new(0, 40, 0.14, 0) or UDim2.new(0, 8, 0.14, 0), ZIndex = btn.ZIndex + 2, Max = props.Max or 30, Name = "Label" })
	end
	if props.Icon then
		props.Icon.Parent = btn
		props.Icon.ZIndex = btn.ZIndex + 2
	end
	-- press: the face sinks onto the lip
	local function down() TweenService:Create(btn, TweenInfo.new(0.06), { Position = UDim2.fromOffset(0, 4) }):Play() end
	local function up() TweenService:Create(btn, TweenInfo.new(0.12, Enum.EasingStyle.Back), { Position = UDim2.fromOffset(0, 0) }):Play() end
	btn.MouseButton1Down:Connect(down)
	btn.MouseButton1Up:Connect(up)
	btn.MouseLeave:Connect(up)
	if props.OnClick then btn.Activated:Connect(function() UI.click() props.OnClick() end) end
	holder.Parent = props.Parent
	return btn, holder, label
end
function UI.recolor(btn, color)
	local col = UI.Colors[color]
	local g = btn:FindFirstChildOfClass("UIGradient")
	if g then g.Color = ColorSequence.new(col[1], col[2]) end
	local lip = btn.Parent:FindFirstChild("Lip")
	if lip then lip.BackgroundColor3 = col[2]:Lerp(Color3.new(0, 0, 0), 0.35) end
end

-- a pill (counter): a rounded dark-edged bar
function UI.pill(props)
	local f = new("Frame", { Name = props.Name or "Pill", BackgroundColor3 = Color3.new(1, 1, 1), Size = props.Size or UDim2.fromOffset(220, 52),
		Position = props.Position or UDim2.new(), AnchorPoint = props.AnchorPoint or Vector2.zero, ZIndex = 2 })
	UI.corner(f, UDim.new(1, 0))
	UI.stroke(f, 3, UI.Ink)
	local col = UI.Colors[props.Color or "white"]
	UI.gradient(f, col[1], col[2])
	f.Parent = props.Parent
	return f
end

-- an icon from the v1 atlas (Shared.Icons)
local Icons = require(game:GetService("ReplicatedStorage").Shared.Icons)
function UI.icon(key, props) return Icons.make(key, props or {}) end

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
		conn = game:GetService("RunService").Heartbeat:Connect(function(dt)
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
