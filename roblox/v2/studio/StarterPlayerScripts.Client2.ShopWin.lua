-- BlockRise 2.0 - the SHOP window: the game passes that matter in 2.0 and the packs (Gems, instant cash, boosts).
-- Prices and ids come from the v1 Config.Store (the owner sets the Robux prices in the Creator Hub).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local Config = require(ReplicatedStorage.Shared.Config)

-- what each pass does in 2.0 (the v1 texts talk about contracts)
local PASSES = {
	{ key = "cash2x", desc = "Double income from your whole city. Forever." },
	{ key = "bigcrew", desc = "+3 workers in your crew: everything builds faster." },
	{ key = "stormhammer", desc = "x3 build power for you and your crew." },
	{ key = "vip", desc = "+20% income and a golden VIP tag." },
	{ key = "offline", desc = "Your city earns 2x while you're away." },
	{ key = "luck", desc = "2x luck in every hammer crate." },
	{ key = "quickopen", desc = "Crates open at once, no spinning." },
	{ key = "autoopen", desc = "Open all your crates in one tap." },
}
local PACKS = { "starter", "rushcrew", "cashboost", "cashstack", "cashpack", "cashvault", "cashbank", "gems100", "gems300", "gems750", "gems1700", "gems4500", "gems12000" }
local PACK_DESC = { rushcrew = "Your crew builds 2x faster for 15 minutes.", cashboost = "2x income for 30 minutes." }

local function find(list, key) for _, p in ipairs(list) do if p.key == key then return p end end end

return function(body, ctx)
	local UI = ctx.UI
	local new = UI.new
	local plr = Players.LocalPlayer
	local tab = "passes"
	local tabs = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 46), Parent = body })
	new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 12), Parent = tabs })
	local content = new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 58), Size = UDim2.new(1, 0, 1, -58), Parent = body })
	local tabBtns, render = {}, nil
	for i, t in ipairs({ { "passes", "GAME PASSES" }, { "packs", "GEMS & CASH" } }) do
		tabBtns[t[1]] = UI.button({ Name = t[1], Color = t[1] == tab and "gold" or "grey", Text = t[2], Size = UDim2.fromOffset(200, 42), Order = i, Max = 24, Parent = tabs,
			OnClick = function()
				tab = t[1]
				for k, b in pairs(tabBtns) do UI.recolor(b, k == tab and "gold" or "grey") end
				render()
			end })
	end

	local function tile(grid, order, p, desc, owned, onBuy)
		local f = new("Frame", { BackgroundColor3 = Color3.new(1, 1, 1), LayoutOrder = order, Parent = grid })
		UI.corner(f, 18)
		UI.stroke(f, 3)
		UI.gradient(f, Color3.fromRGB(255, 255, 255), Color3.fromRGB(214, 228, 255))
		local img = Config.ProductImages and Config.ProductImages[p.key]
		if img then
			new("ImageLabel", { BackgroundTransparency = 1, Image = img, ScaleType = Enum.ScaleType.Fit, Size = UDim2.fromOffset(96, 86), Position = UDim2.new(0.5, -48, 0, 8), ZIndex = 2, Parent = f })
		else
			UI.text({ Text = p.icon or "?", Font = Enum.Font.SourceSans, Stroke = false, Size = UDim2.fromOffset(96, 80), Position = UDim2.new(0.5, -48, 0, 10), Parent = f })
		end
		UI.text({ Text = p.name, Size = UDim2.new(1, -12, 0, 26), Position = UDim2.fromOffset(6, 96), Color = UI.Ink, Stroke = false, Max = 20, ZIndex = 2, Parent = f })
		local d = UI.text({ Text = desc or p.desc or "", Size = UDim2.new(1, -16, 0, 40), Position = UDim2.fromOffset(8, 122), Color = Color3.fromRGB(90, 98, 130), Stroke = false, Max = 14, ZIndex = 2, Parent = f })
		d.TextWrapped = true
		if p.tag then
			local tg = UI.pill({ Color = "red", Size = UDim2.fromOffset(104, 24), Position = UDim2.new(0.5, -52, 0, -10), Parent = f })
			tg.ZIndex = 5
			UI.text({ Text = p.tag, Size = UDim2.new(1, -8, 1, -4), Position = UDim2.fromOffset(4, 2), ZIndex = 6, Max = 14, Parent = tg })
		end
		UI.button({ Name = "Buy", Color = owned and "grey" or "green", Text = owned and "OWNED" or (p.price and ("R$ " .. p.price) or "BUY"), Size = UDim2.new(1, -20, 0, 42), Position = UDim2.new(0, 10, 1, -52), Max = 22, ZIndex = 2, Parent = f,
			OnClick = function() if not owned then onBuy() end end })
	end

	local function grid()
		for _, c in ipairs(content:GetChildren()) do c:Destroy() end
		local g = new("ScrollingFrame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
			ScrollBarThickness = 8, ScrollBarImageColor3 = UI.Ink, BorderSizePixel = 0, Parent = content })
		new("UIGridLayout", { CellSize = UDim2.fromOffset(165, 226), CellPadding = UDim2.fromOffset(12, 16), SortOrder = Enum.SortOrder.LayoutOrder, Parent = g })
		UI.pad(g, 4, 14, 14, 6)
		return g
	end

	render = function()
		local g = grid()
		if tab == "passes" then
			for i, it in ipairs(PASSES) do
				local p = find(Config.Store.passes, it.key)
				if p and (p.id or 0) > 0 then
					tile(g, i, p, it.desc, plr:GetAttribute("Pass_" .. p.key) == true, function() MarketplaceService:PromptGamePassPurchase(plr, p.id) end)
				end
			end
		else
			for i, key in ipairs(PACKS) do
				local p = find(Config.Store.products, key)
				if p and (p.id or 0) > 0 and not p.hidden then
					local done = p.once and plr:GetAttribute("Bought_" .. p.key) == true
					tile(g, i, p, PACK_DESC[key], done, function() MarketplaceService:PromptProductPurchase(plr, p.id) end)
				end
			end
		end
	end
	render()
end
