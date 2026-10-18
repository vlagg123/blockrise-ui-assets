-- BlockRise 2.0 - the MENU window: your empire in numbers, travel (your city / the plaza), music on or off.
-- PREMIUM_UI (2026-10-18): a stats card with an icon per row, big glossy buttons with icons.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local SoundService = game:GetService("SoundService")
local C = require(ReplicatedStorage.Shared.Config2)

local WHITE = Color3.new(1, 1, 1)
local C3 = Color3.fromRGB

return function(body, ctx)
	local UI = ctx.UI
	local new = UI.new
	local plr = Players.LocalPlayer
	local attr = ctx.attr
	-- stats
	local stats = UI.well({ Size = UDim2.new(0.56, -10, 1, 0), ZIndex = 4, Parent = body })
	UI.text({ Text = "YOUR EMPIRE", Size = UDim2.new(1, -24, 0, 34), Position = UDim2.fromOffset(12, 10), Color = UI.Ink, Stroke = false, Max = 28, ZIndex = 6, Parent = stats })
	local built, best = 0, 0
	for part in (attr("Lots", "")):gmatch("[^,]+") do
		local lv = tonumber(part:match("%d:(%d+):")) or 0
		if lv > 0 then built += 1 end
		best = math.max(best, lv)
	end
	local rows = {
		{ "cash", "Income", C.Money(attr("Income", 0)) .. "/s" },
		{ "company", "Buildings", tostring(built) },
		{ "mega", "Tallest", best > 0 and C.Levels[best].name or "-" },
		{ "rebirth", "Rebirths", tostring(attr("Rebirths", 0)) },
		{ "crew", "Crew", tostring(attr("Workers", 0)) .. " workers" },
		{ "rbxassetid://71920003497651", "Hammers", tostring(attr("HammerCount", 1)) },
	}
	local list = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, -24, 1, -58), Position = UDim2.fromOffset(12, 50), ZIndex = 5, Parent = stats })
	new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = list })
	for i, r in ipairs(rows) do
		local row = new("Frame", { BackgroundColor3 = WHITE, Size = UDim2.new(1, 0, 1 / #rows, -6), LayoutOrder = i, ZIndex = 5, Parent = list })
		UI.corner(row, 14)
		UI.stroke(row, 2.5, UI.Ink, 0.4)
		UI.gradient(row, WHITE, i % 2 == 0 and C3(232, 240, 255) or C3(240, 246, 255))
		UI.icon(r[1], { Size = UDim2.new(0, 40, 0, 40), Position = UDim2.new(0, 6, 0.5, -20), ZIndex = 7, Parent = row })
		UI.text({ Text = r[2], Size = UDim2.new(0.5, -50, 0.6, 0), Position = UDim2.new(0, 52, 0.2, 0), XAlign = Enum.TextXAlignment.Left, Color = UI.Muted, Stroke = false, Max = 22, ZIndex = 6, Parent = row })
		UI.text({ Text = r[3], Size = UDim2.new(0.5, -12, 0.6, 0), Position = UDim2.new(0.5, 0, 0.2, 0), XAlign = Enum.TextXAlignment.Right, Color = UI.Ink, Stroke = false, Max = 24, ZIndex = 6, Parent = row })
	end
	-- actions
	local side = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(0.44, -10, 1, 0), Position = UDim2.new(0.56, 10, 0, 0), ZIndex = 4, Parent = body })
	new("UIListLayout", { Padding = UDim.new(0, 18), SortOrder = Enum.SortOrder.LayoutOrder, Parent = side })
	UI.pad(side, 2, 4, 2, 4)
	local CityRF = ReplicatedStorage.Remotes:WaitForChild("City")
	UI.button({ Name = "Home", Color = "green", Text = "MY CITY", IconKey = "home", Size = UDim2.new(1, 0, 0, 66), Order = 1, Max = 28, ZIndex = 5, Parent = side,
		OnClick = function() CityRF:InvokeServer("home") if ctx.close then ctx.close() end end })
	UI.button({ Name = "Hub", Color = "blue", Text = "THE PLAZA", IconKey = "locations", Size = UDim2.new(1, 0, 0, 66), Order = 2, Max = 28, ZIndex = 5, Parent = side,
		OnClick = function()
			local ch = plr.Character
			local sp = workspace:FindFirstChild("World") and workspace.World:FindFirstChild("Spawn", true)
			if ch and sp then ch:PivotTo(sp.CFrame + Vector3.new(0, 4, 0)) end
			if ctx.close then ctx.close() end
		end })
	local music = SoundService:FindFirstChild("Music2")
	local function musicText() return (music and music.Volume > 0) and "MUSIC: ON" or "MUSIC: OFF" end
	local mb, _mh, ml
	mb, _mh, ml = UI.button({ Name = "Music", Color = (music and music.Volume > 0) and "purple" or "grey", Text = musicText(), IconKey = "music", Size = UDim2.new(1, 0, 0, 66), Order = 3, Max = 28, ZIndex = 5, Parent = side,
		OnClick = function()
			if music then music.Volume = music.Volume > 0 and 0 or 0.16 end
			ml.Text = musicText()
			UI.recolor(mb, (music and music.Volume > 0) and "purple" or "grey")
		end })
end
