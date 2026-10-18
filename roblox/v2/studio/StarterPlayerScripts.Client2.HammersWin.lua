-- BlockRise 2.0 - the HAMMERS window: your hammers (a grid; tap one: its card with EQUIP and LEVEL UP) and the
-- crates (cash or Gems; where paid random items aren't allowed every crate shows the hammer inside first: X-RAY).
-- Talks to the v1 HammerService (RemoteFunction HammerAction).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local Hammers = require(ReplicatedStorage.Shared.Hammers)
local C = require(ReplicatedStorage.Shared.Config2)

return function(body, ctx)
	local RF = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("HammerAction")
	local UI = ctx.UI
	local new = UI.new
	local plr = Players.LocalPlayer
	local tab = "mine"
	local data
	local selected

	-- tabs
	local tabs = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 46), Parent = body })
	new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 12), Parent = tabs })
	local content = new("Frame", { Name = "Content", BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 58), Size = UDim2.new(1, 0, 1, -58), Parent = body })
	local tabBtns = {}
	local render
	local function tabButton(id, text, order)
		local b = UI.button({ Name = id, Color = id == tab and "blue" or "grey", Text = text, Size = UDim2.fromOffset(190, 42), Order = order, Max = 24, Parent = tabs,
			OnClick = function()
				tab = id
				for k, bb in pairs(tabBtns) do UI.recolor(bb, k == tab and "blue" or "grey") end
				render()
			end })
		tabBtns[id] = b
	end
	tabButton("mine", "MY HAMMERS", 1)
	tabButton("crates", "CRATES", 2)

	local function rarity(r) return Hammers.Rarities[r] or Hammers.Rarities[1] end
	local function clear() for _, c in ipairs(content:GetChildren()) do c:Destroy() end end
	local function msg(t) clear() UI.text({ Text = t, Color = UI.Ink, Stroke = false, Size = UDim2.new(1, 0, 0, 40), Position = UDim2.fromScale(0, 0.4), Max = 28, Parent = content }) end

	local function load()
		local ok, res = RF:InvokeServer("get")
		if ok and type(res) == "table" then data = res return true end
		msg(tostring(res or "Could not load your hammers"))
		return false
	end

	-- a hammer tile (rarity gradient, picture, name, level)
	local function tile(parent, it, size, onClick)
		local h = Hammers.ById[it.k]
		local rar = rarity(h and h.r or 1)
		local b = new("TextButton", { Name = it.id or it.k, Text = "", AutoButtonColor = false, BackgroundColor3 = Color3.new(1, 1, 1), Size = size, LayoutOrder = it.order or 0, Parent = parent })
		UI.corner(b, 16)
		UI.stroke(b, 3)
		UI.gradient(b, rar.color:Lerp(Color3.new(1, 1, 1), 0.45), rar.color)
		new("ImageLabel", { BackgroundTransparency = 1, Image = h and h.img or "", ScaleType = Enum.ScaleType.Fit, Size = UDim2.new(1, -16, 0.62, 0), Position = UDim2.new(0, 8, 0, 6), ZIndex = 2, Parent = b })
		UI.text({ Text = h and h.name or it.k, Size = UDim2.new(1, -10, 0.2, 0), Position = UDim2.new(0, 5, 0.62, 0), ZIndex = 3, Max = 18, Parent = b })
		if it.lv then UI.text({ Text = "Lv " .. it.lv, Size = UDim2.new(1, -10, 0.16, 0), Position = UDim2.new(0, 5, 0.82, 0), ZIndex = 3, Max = 16, Color = Color3.fromRGB(255, 240, 160), Parent = b }) end
		if onClick then b.Activated:Connect(function() UI.click() onClick() end) end
		return b
	end

	-- MY HAMMERS ----------------------------------------------------------------------------------------------
	local function renderMine()
		clear()
		local list = {}
		for _, it in ipairs(data.hammers or {}) do
			local h = Hammers.ById[it.k]
			if h then table.insert(list, it) end
		end
		-- the best first: rarity, then level
		table.sort(list, function(a, b)
			local ra, rb = Hammers.ById[a.k].r, Hammers.ById[b.k].r
			if a.id == data.equip then return true end
			if b.id == data.equip then return false end
			if ra ~= rb then return ra > rb end
			if (a.lv or 1) ~= (b.lv or 1) then return (a.lv or 1) > (b.lv or 1) end
			return a.id < b.id
		end)
		local grid = new("ScrollingFrame", { BackgroundTransparency = 1, Size = UDim2.new(1, -262, 1, 0), CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
			ScrollBarThickness = 8, ScrollBarImageColor3 = UI.Ink, BorderSizePixel = 0, Parent = content })
		new("UIGridLayout", { CellSize = UDim2.fromOffset(102, 122), CellPadding = UDim2.fromOffset(10, 10), SortOrder = Enum.SortOrder.LayoutOrder, Parent = grid })
		UI.pad(grid, 4, 4, 12, 4)
		local panel = new("Frame", { BackgroundColor3 = Color3.new(1, 1, 1), Size = UDim2.new(0, 250, 1, 0), Position = UDim2.new(1, -250, 0, 0), Parent = content })
		UI.corner(panel, 18)
		UI.stroke(panel, 3)
		local function showPanel(it)
			for _, c in ipairs(panel:GetChildren()) do if not c:IsA("UICorner") and not c:IsA("UIStroke") then c:Destroy() end end
			local h = Hammers.ById[it.k]
			local rar = rarity(h.r)
			local big = tile(panel, { k = it.k, id = "Big" }, UDim2.fromOffset(150, 150))
			big.Position = UDim2.new(0.5, -75, 0, 12)
			for _, c in ipairs(big:GetChildren()) do if c:IsA("TextLabel") then c:Destroy() end end
			big:FindFirstChildOfClass("ImageLabel").Size = UDim2.new(1, -16, 1, -16)
			UI.text({ Text = h.name, Size = UDim2.new(1, -16, 0, 30), Position = UDim2.fromOffset(8, 168), Color = UI.Ink, Stroke = false, Max = 26, Parent = panel })
			UI.text({ Text = rar.name:upper() .. "  -  Lv " .. (it.lv or 1), Size = UDim2.new(1, -16, 0, 22), Position = UDim2.fromOffset(8, 198), Color = rar.color, StrokeTh = 1.5, Max = 20, Parent = panel })
			UI.text({ Text = "Build power " .. Hammers.PowerLabel(it.k, it.lv or 1, it.pass), Size = UDim2.new(1, -16, 0, 22), Position = UDim2.fromOffset(8, 222), Color = Color3.fromRGB(46, 170, 80), Stroke = false, Max = 20, Parent = panel })
			local equipped = it.id == data.equip
			UI.button({ Name = "Equip", Color = equipped and "grey" or "blue", Text = equipped and "IN YOUR HAND" or "EQUIP", Size = UDim2.new(1, -24, 0, 44), Position = UDim2.fromOffset(12, 252), Max = 22, Parent = panel,
				OnClick = function()
					if equipped then return end
					local ok, res = RF:InvokeServer("equip", it.id)
					if ok then data.equip = it.id ctx.toast("Equipped " .. h.name, "blue") renderMine() else ctx.toast(tostring(res), "red") end
				end })
			local cost = Hammers.LevelCost(it.k, it.lv or 1)
			UI.button({ Name = "Level", Color = cost and "green" or "grey", Text = cost and ("LEVEL UP " .. C.Money(cost)) or "MAX LEVEL", Size = UDim2.new(1, -24, 0, 44), Position = UDim2.fromOffset(12, 304), Max = 22, Parent = panel,
				OnClick = function()
					if not cost then return end
					local ok, res = RF:InvokeServer("levelup", it.id)
					if ok then it.lv = res and res.lv or ((it.lv or 1) + 1) UI.coin() showPanel(it) else ctx.toast(tostring(res), "red") end
				end })
		end
		for i, it in ipairs(list) do
			it.order = i
			local t = tile(grid, it, UDim2.fromOffset(102, 122), function() selected = it.id showPanel(it) end)
			if it.id == data.equip then
				local tag = UI.pill({ Color = "green", Size = UDim2.fromOffset(46, 22), Position = UDim2.new(1, -50, 0, 4), Parent = t })
				tag.ZIndex = 4
				UI.text({ Text = "HAND", Size = UDim2.new(1, -6, 1, -4), Position = UDim2.fromOffset(3, 2), ZIndex = 5, Max = 14, Parent = tag })
			end
		end
		local first = list[1]
		for _, it in ipairs(list) do if it.id == selected then first = it end end
		if first then showPanel(first) end
	end

	-- CRATES --------------------------------------------------------------------------------------------------
	local reveal -- the hammer you just got
	local function showReveal(res)
		local h = Hammers.ById[res.key]
		if not h then return end
		local rar = rarity(res.r or h.r)
		local f = new("Frame", { BackgroundColor3 = Color3.fromRGB(20, 26, 60), BackgroundTransparency = 0.25, Size = UDim2.fromScale(1, 1), ZIndex = 20, Parent = content })
		UI.corner(f, 18)
		local glow = new("Frame", { BackgroundColor3 = rar.color, BackgroundTransparency = 0.3, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.42), Size = UDim2.fromOffset(220, 220), ZIndex = 21, Parent = f })
		UI.corner(glow, UDim.new(1, 0))
		new("ImageLabel", { BackgroundTransparency = 1, Image = h.img, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.42), Size = UDim2.fromOffset(200, 200), ScaleType = Enum.ScaleType.Fit, ZIndex = 22, Parent = f })
		UI.text({ Text = (res.new and "NEW! " or "") .. h.name, Size = UDim2.new(1, 0, 0, 40), Position = UDim2.new(0, 0, 0.74, 0), ZIndex = 23, Max = 34, StrokeTh = 3, Parent = f })
		UI.text({ Text = rar.name:upper(), Size = UDim2.new(1, 0, 0, 28), Position = UDim2.new(0, 0, 0.74, 40), ZIndex = 23, Color = rar.color, StrokeTh = 2.5, Max = 26, Parent = f })
		UI.pop(glow, 0.2)
		TweenService:Create(glow, TweenInfo.new(6, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1), { Rotation = 360 }):Play()
		UI.coin()
		RF:InvokeServer("seen", res.id)
		local close = new("TextButton", { Text = "", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 30, Parent = f })
		close.Activated:Connect(function() f:Destroy() end)
		task.delay(4, function() if f.Parent then f:Destroy() end end)
	end

	local function renderCrates()
		clear()
		local reb = data.rebirths or 0
		local row = new("ScrollingFrame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.X,
			ScrollingDirection = Enum.ScrollingDirection.X, ScrollBarThickness = 8, ScrollBarImageColor3 = UI.Ink, BorderSizePixel = 0, Parent = content })
		new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 14), SortOrder = Enum.SortOrder.LayoutOrder, Parent = row })
		UI.pad(row, 4, 4, 4, 14)
		local order = 0
		for _, c in ipairs(Hammers.Crates) do
			-- the crates you can buy here: your zone's Supply Crate (cash) and the Gem crates
			local show = (c.cash and c.id == (data.supplyId or "supply")) or (c.gems and not c.soon)
			if show then
				order += 1
				local open = Hammers.CrateOpen(c, reb)
				local card = new("Frame", { BackgroundColor3 = Color3.new(1, 1, 1), Size = UDim2.fromOffset(176, 300), LayoutOrder = order, Parent = row })
				UI.corner(card, 18)
				UI.stroke(card, 3)
				UI.gradient(card, c.color:Lerp(Color3.new(1, 1, 1), 0.55), c.color)
				new("ImageLabel", { BackgroundTransparency = 1, Image = c.image or "", ScaleType = Enum.ScaleType.Fit, Size = UDim2.fromOffset(140, 120), Position = UDim2.fromOffset(18, 10), ZIndex = 2, Parent = card })
				UI.text({ Text = c.name, Size = UDim2.new(1, -12, 0, 44), Position = UDim2.fromOffset(6, 132), ZIndex = 3, Max = 22, Parent = card }).TextWrapped = true
				local owned = (data.crates and data.crates[c.id]) or 0
				local x = data.xray and data.xray[c.id]
				if x and Hammers.ById[x.key] then
					-- X-RAY: the hammer inside
					local xh = Hammers.ById[x.key]
					UI.text({ Text = "INSIDE: " .. xh.name, Size = UDim2.new(1, -12, 0, 22), Position = UDim2.fromOffset(6, 178), ZIndex = 3, Color = rarity(x.r).color, StrokeTh = 2, Max = 16, Parent = card })
				end
				local priceText = c.cash and C.Money(Hammers.CratePrice(c) or 0) or (C.Fmt(c.gems) .. " Gems")
				UI.text({ Text = owned > 0 and ("You have " .. owned) or priceText, Size = UDim2.new(1, -12, 0, 24), Position = UDim2.fromOffset(6, 202), ZIndex = 3, Max = 22, Color = Color3.fromRGB(255, 245, 170), Parent = card })
				local label = not open and ("REBIRTH " .. tostring(Hammers.CrateRebirth(c))) or (owned > 0 and "OPEN" or "BUY & OPEN")
				UI.button({ Name = "Buy", Color = open and "green" or "grey", Text = label, Size = UDim2.new(1, -20, 0, 48), Position = UDim2.fromOffset(10, 238), Max = 22, ZIndex = 3, Parent = card,
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
