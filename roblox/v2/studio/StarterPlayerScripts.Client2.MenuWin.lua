-- BlockRise 2.0 - the MENU window: your empire in numbers, travel (your city / the hub), music on or off.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local SoundService = game:GetService("SoundService")
local C = require(ReplicatedStorage.Shared.Config2)

return function(body, ctx)
	local UI = ctx.UI
	local new = UI.new
	local plr = Players.LocalPlayer
	local attr = ctx.attr
	-- stats
	local stats = new("Frame", { BackgroundColor3 = Color3.new(1, 1, 1), Size = UDim2.new(0.5, -10, 1, 0), Parent = body })
	UI.corner(stats, 18)
	UI.stroke(stats, 3)
	UI.text({ Text = "YOUR EMPIRE", Size = UDim2.new(1, -20, 0, 34), Position = UDim2.fromOffset(10, 10), Color = UI.Ink, Stroke = false, Max = 28, Parent = stats })
	local built, best = 0, 0
	for part in (attr("Lots", "")):gmatch("[^,]+") do
		local lv = tonumber(part:match("%d:(%d+):")) or 0
		if lv > 0 then built += 1 end
		best = math.max(best, lv)
	end
	local rows = {
		{ "Income", C.Money(attr("Income", 0)) .. "/s" },
		{ "Buildings", tostring(built) },
		{ "Tallest", best > 0 and C.Levels[best].name or "-" },
		{ "Rebirths", tostring(attr("Rebirths", 0)) },
		{ "Crew", tostring(attr("Workers", 0)) .. " workers" },
		{ "Hammers", tostring(attr("HammerCount", 1)) },
	}
	for i, r in ipairs(rows) do
		local y = 54 + (i - 1) * 46
		local row = new("Frame", { BackgroundColor3 = i % 2 == 0 and Color3.fromRGB(240, 244, 255) or Color3.fromRGB(228, 236, 255), Size = UDim2.new(1, -24, 0, 40), Position = UDim2.fromOffset(12, y), Parent = stats })
		UI.corner(row, 12)
		UI.text({ Text = r[1], Size = UDim2.new(0.5, -10, 1, -10), Position = UDim2.fromOffset(12, 5), XAlign = Enum.TextXAlignment.Left, Color = Color3.fromRGB(90, 98, 130), Stroke = false, Max = 22, Parent = row })
		UI.text({ Text = r[2], Size = UDim2.new(0.5, -10, 1, -10), Position = UDim2.new(0.5, 0, 0, 5), XAlign = Enum.TextXAlignment.Right, Color = UI.Ink, Stroke = false, Max = 22, Parent = row })
	end
	-- actions
	local side = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(0.5, -10, 1, 0), Position = UDim2.new(0.5, 10, 0, 0), Parent = body })
	new("UIListLayout", { Padding = UDim.new(0, 14), SortOrder = Enum.SortOrder.LayoutOrder, Parent = side })
	local CityRF = ReplicatedStorage.Remotes:WaitForChild("City")
	UI.button({ Name = "Home", Color = "green", Text = "GO TO MY CITY", Size = UDim2.new(1, 0, 0, 60), Order = 1, Parent = side,
		OnClick = function() CityRF:InvokeServer("home") end })
	UI.button({ Name = "Hub", Color = "blue", Text = "GO TO THE PLAZA", Size = UDim2.new(1, 0, 0, 60), Order = 2, Parent = side,
		OnClick = function()
			local ch = plr.Character
			local sp = workspace:FindFirstChild("World") and workspace.World:FindFirstChild("Spawn", true)
			if ch and sp then ch:PivotTo(sp.CFrame + Vector3.new(0, 4, 0)) end
		end })
	local music = SoundService:FindFirstChild("Music2")
	local function musicText() return (music and music.Volume > 0) and "MUSIC: ON" or "MUSIC: OFF" end
	local mb, _, ml
	mb, _, ml = UI.button({ Name = "Music", Color = "purple", Text = musicText(), Size = UDim2.new(1, 0, 0, 60), Order = 3, Parent = side,
		OnClick = function()
			if music then music.Volume = music.Volume > 0 and 0 or 0.16 end
			ml.Text = musicText()
		end })
end
