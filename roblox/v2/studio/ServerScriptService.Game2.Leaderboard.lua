-- BlockRise 2.0 - the plaza's leaderboards (BOARDS_V1, 2026-10-18): RICHEST CITIES (the best income per second a
-- city ever reached) and TOP EARNERS (all the cash a player ever made). Two OrderedDataStores with new names (the
-- saves are not touched). A player's score is written when it grew (every 3 min at most, and when leaving); the top 10
-- are read every 2 min and drawn on two boards standing in the plaza's north gardens, facing the fountain.
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local C = require(game:GetService("ReplicatedStorage").Shared.Config2)

local L = {}
local ctx
local C3 = Color3.fromRGB
local WHITE = Color3.new(1, 1, 1)
local INK = C3(24, 32, 70)
local FONT = Enum.Font.FredokaOne

L.Boards = {
	{ key = "income", store = "BlockRise2_TopIncome", title = "RICHEST CITIES", sub = "Best income per second", x = -80,
		top = C3(110, 202, 255), bottom = C3(36, 114, 236), value = function(st) return ctx.incomeOf and ctx.incomeOf(st) or 0 end,
		fmt = function(v) return C.Money(v) .. "/s" end },
	{ key = "earned", store = "BlockRise2_TopEarned", title = "TOP EARNERS", sub = "All the cash ever made", x = 80,
		top = C3(255, 230, 100), bottom = C3(255, 160, 22), value = function(st) return st.data.Earned or 0 end,
		fmt = function(v) return C.Money(v) end },
}

local written = {} -- player -> { key -> value }
local names = {}   -- userId -> name

local function nameOf(id)
	if names[id] then return names[id] end
	local p = Players:GetPlayerByUserId(id)
	if p then names[id] = p.Name return p.Name end
	local ok, n = pcall(function() return Players:GetNameFromUserIdAsync(id) end)
	names[id] = ok and n or ("Builder " .. id)
	return names[id]
end

-- the board: a navy panel in a gold frame on two posts, a plinth; the list is a SurfaceGui on its face ---------------
local function part(props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	for k, v in pairs(props) do p[k] = v end
	return p
end
local function new(class, props)
	local o = Instance.new(class)
	for k, v in pairs(props) do if k ~= "Parent" then o[k] = v end end
	o.Parent = props.Parent
	return o
end
local function corner(o, r) new("UICorner", { CornerRadius = UDim.new(0, r), Parent = o }) end
local function stroke(o, th, col) new("UIStroke", { Thickness = th, Color = col or INK, ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual, Parent = o }) end
local function gradient(o, a, b) new("UIGradient", { Color = ColorSequence.new(a, b), Rotation = 90, Parent = o }) end
local function label(props)
	local t = new("TextLabel", { BackgroundTransparency = 1, Font = FONT, TextColor3 = props.Color or WHITE, TextScaled = true, Text = props.Text or "",
		Size = props.Size, Position = props.Position or UDim2.new(), AnchorPoint = props.AnchorPoint or Vector2.zero, TextXAlignment = props.XAlign or Enum.TextXAlignment.Center,
		ZIndex = props.ZIndex or 2, Parent = props.Parent })
	if props.Stroke ~= false then stroke(t, props.StrokeTh or 3) end
	if props.Max then new("UITextSizeConstraint", { MaxTextSize = props.Max, Parent = t }) end
	return t
end

local W, H, PPS = 30, 22, 20 -- the panel in studs, pixels per stud (600 x 440: the top 8, big enough to read)
local function buildBoard(b, folder)
	local base = CFrame.lookAt(Vector3.new(b.x, 0, -62), Vector3.new(0, 0, 0))
	local m = Instance.new("Model")
	m.Name = "Board_" .. b.key
	local gold, navy = C3(255, 196, 60), C3(32, 42, 96)
	part({ Name = "Plinth", Size = Vector3.new(W + 4, 1.2, 5), CFrame = base * CFrame.new(0, 0.6, 0), Color = C3(236, 240, 248), Material = Enum.Material.Concrete, Parent = m })
	for _, sx in ipairs({ -1, 1 }) do
		part({ Name = "Post", Size = Vector3.new(1.8, H + 6, 1.8), CFrame = base * CFrame.new(sx * (W / 2 + 0.4), (H + 6) / 2 + 1.2, 0.6), Color = gold, Parent = m })
		part({ Name = "Cap", Shape = Enum.PartType.Ball, Size = Vector3.new(2.6, 2.6, 2.6), CFrame = base * CFrame.new(sx * (W / 2 + 0.4), H + 8.4, 0.6), Color = gold, Parent = m })
	end
	part({ Name = "Frame", Size = Vector3.new(W + 1.6, H + 1.6, 0.8), CFrame = base * CFrame.new(0, H / 2 + 5, 0.9), Color = gold, Parent = m })
	local panel = part({ Name = "Panel", Size = Vector3.new(W, H, 0.6), CFrame = base * CFrame.new(0, H / 2 + 5, 0.4), Color = navy, Parent = m })
	for _, p in ipairs(m:GetChildren()) do p.CanCollide = p.Name ~= "Cap" end
	m.Parent = folder

	local sg = new("SurfaceGui", { Name = "List", Face = Enum.NormalId.Front, SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud, PixelsPerStud = PPS,
		LightInfluence = 0, Brightness = 1.15, MaxDistance = 260, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, Parent = panel })
	local bg = new("Frame", { BackgroundColor3 = WHITE, Size = UDim2.fromScale(1, 1), Parent = sg })
	gradient(bg, C3(46, 60, 132), C3(20, 26, 64))
	-- the header ribbon
	local head = new("Frame", { BackgroundColor3 = WHITE, Size = UDim2.new(1, -24, 0, 92), Position = UDim2.fromOffset(12, 12), ZIndex = 2, Parent = bg })
	corner(head, 22)
	gradient(head, b.top, b.bottom)
	new("UIStroke", { Thickness = 4, Color = INK, Parent = head })
	label({ Text = b.title, Size = UDim2.new(1, -40, 0, 54), Position = UDim2.fromOffset(20, 6), Max = 52, StrokeTh = 4, ZIndex = 3, Parent = head })
	label({ Text = b.sub, Size = UDim2.new(1, -40, 0, 26), Position = UDim2.fromOffset(20, 58), Max = 24, StrokeTh = 2.4, ZIndex = 3, Parent = head })
	-- the eight rows
	local rows = {}
	for i = 1, 8 do
		local y = 112 + (i - 1) * 40
		local row = new("Frame", { BackgroundColor3 = WHITE, BackgroundTransparency = i % 2 == 1 and 0.9 or 0.95, Size = UDim2.new(1, -24, 0, 37), Position = UDim2.fromOffset(12, y), ZIndex = 2, Parent = bg })
		corner(row, 12)
		local rc = i == 1 and { C3(255, 230, 100), C3(255, 160, 22) } or (i == 2 and { C3(236, 240, 252), C3(160, 170, 196) } or (i == 3 and { C3(255, 196, 150), C3(196, 110, 60) } or { C3(110, 130, 210), C3(60, 74, 150) }))
		local badge = new("Frame", { BackgroundColor3 = WHITE, Size = UDim2.fromOffset(31, 31), Position = UDim2.fromOffset(6, 3), ZIndex = 3, Parent = row })
		corner(badge, 16)
		gradient(badge, rc[1], rc[2])
		new("UIStroke", { Thickness = 2.5, Color = INK, Parent = badge })
		label({ Text = tostring(i), Size = UDim2.new(1, -6, 1, -8), Position = UDim2.fromOffset(3, 4), Max = 24, StrokeTh = 2, ZIndex = 4, Parent = badge })
		local pic = new("ImageLabel", { BackgroundColor3 = C3(70, 86, 160), Size = UDim2.fromOffset(31, 31), Position = UDim2.fromOffset(44, 3), Image = "", ZIndex = 3, Parent = row })
		corner(pic, 16)
		local nm = label({ Text = "", Size = UDim2.new(0.56, -88, 0, 30), Position = UDim2.fromOffset(84, 3), XAlign = Enum.TextXAlignment.Left, Max = 30, StrokeTh = 2.6, ZIndex = 3, Parent = row })
		local val = label({ Text = "", Size = UDim2.new(0.44, -10, 0, 30), Position = UDim2.new(0.56, 0, 0, 3), XAlign = Enum.TextXAlignment.Right, Max = 30, StrokeTh = 2.6,
			Color = i == 1 and C3(255, 226, 90) or C3(190, 255, 170), ZIndex = 3, Parent = row })
		rows[i] = { row = row, pic = pic, name = nm, value = val }
	end
	local empty = label({ Text = "Loading the best cities...", Size = UDim2.new(1, -60, 0, 40), Position = UDim2.new(0, 30, 0.55, -20), Max = 34, ZIndex = 5, Parent = bg })
	b.rows, b.empty = rows, empty
end

local function draw(b, list)
	for i, r in ipairs(b.rows) do
		local e = list[i]
		r.row.Visible = e ~= nil
		if e then
			r.name.Text = nameOf(e.id)
			r.value.Text = b.fmt(e.value)
			r.pic.Image = "rbxthumb://type=AvatarHeadShot&id=" .. e.id .. "&w=150&h=150"
		end
	end
	b.empty.Visible = #list == 0
	b.empty.Text = "Be the first on this board!"
end

-- the data ----------------------------------------------------------------------------------------------------------
local function write(plr, final)
	local st = ctx.S[plr]
	if not st or not st.loaded then return end
	written[plr] = written[plr] or {}
	for _, b in ipairs(L.Boards) do
		local v = math.floor(tonumber(b.value(st)) or 0)
		local last = written[plr][b.key] or 0
		if b.ods and v > 0 and (v > last * 1.01 or (final and v > last)) then
			local ok = pcall(function()
				b.ods:UpdateAsync(tostring(plr.UserId), function(old) return math.max(tonumber(old) or 0, v) end)
			end)
			if ok then written[plr][b.key] = v end
		end
	end
end

local function read()
	for _, b in ipairs(L.Boards) do
		if b.ods then
			local ok, page = pcall(function() return b.ods:GetSortedAsync(false, 10):GetCurrentPage() end)
			if ok and page then
				local list = {}
				for _, e in ipairs(page) do
					local id = tonumber(e.key)
					if id and id > 0 then table.insert(list, { id = id, value = e.value }) end
				end
				draw(b, list)
			end
		end
	end
end

function L.Leave(plr)
	task.spawn(function()
		write(plr, true)
		written[plr] = nil
	end)
end

function L.Init(c)
	ctx = c
	local mall = workspace:WaitForChild("World"):WaitForChild("Mall")
	local folder = mall:FindFirstChild("Boards") or Instance.new("Folder")
	folder.Name = "Boards"
	folder:ClearAllChildren()
	folder.Parent = mall
	for _, b in ipairs(L.Boards) do
		pcall(function() b.ods = DataStoreService:GetOrderedDataStore(b.store) end)
		buildBoard(b, folder)
	end
	task.spawn(function()
		task.wait(8)
		while true do
			read()
			task.wait(120)
		end
	end)
	task.spawn(function()
		task.wait(30)
		while true do
			for _, plr in ipairs(Players:GetPlayers()) do
				write(plr, false)
				task.wait(1)
			end
			task.wait(180)
		end
	end)
end

return L
