-- BlockRise 2.0 - the SHOP window: the game passes that matter in 2.0 and the packs (Gems, instant cash, boosts).
-- Prices and ids come from the v1 Config.Store (the owner sets the Robux prices in the Creator Hub).
-- PREMIUM_UI (2026-10-18): segmented tabs, glossy product cards with a glow, a ribbon tag, a shimmering price button.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local Config = require(ReplicatedStorage.Shared.Config)

local WHITE = Color3.new(1, 1, 1)
local C3 = Color3.fromRGB

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
local PACK_DESC = {
	starter = "600 Gems, 2 crates, 90 min of cash and 2x cash for 30 min.", rushcrew = "Your crew builds 2x faster for 15 minutes.", cashboost = "2x income for 30 minutes.",
	cashstack = "Instant cash: 20 minutes of your income.", cashpack = "Instant cash: 40 minutes of your income.", cashvault = "Instant cash: 90 minutes of your income.",
	cashbank = "Instant cash: 5 hours of your income.",
}
-- an atlas icon for the ones without a picture of their own
local FALLBACK = { offline = "timer", luck = "up_luck", rushcrew = "up_crew", cashboost = "up_cash" }

local function find(list, key) for _, p in ipairs(list) do if p.key == key then return p end end end

return function(body, ctx)
	local UI = ctx.UI
	local new = UI.new
	local plr = Players.LocalPlayer
	local tab = ctx.tab or "passes"
	local render
	UI.tabs({ Parent = body, Items = { { "passes", "GAME PASSES" }, { "packs", "GEMS & CASH" } }, Selected = tab, Color = "gold", Size = UDim2.fromOffset(420, 54), ZIndex = 3,
		OnSelect = function(id) tab = id render() end })
	local content = new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 68), Size = UDim2.new(1, 0, 1, -68), ZIndex = 3, Parent = body })

	local function tile(grid, order, p, desc, owned, onBuy)
		local gold = tab == "passes"
		local f = new("Frame", { BackgroundColor3 = WHITE, LayoutOrder = order, ZIndex = 5, Parent = grid })
		UI.corner(f, 20)
		UI.stroke(f, 3.5)
		UI.gradient(f, WHITE, gold and C3(255, 232, 170) or C3(196, 222, 255))
		UI.gloss(f, 14, { ZIndex = 5, Size = UDim2.new(1, -12, 0, 50), Position = UDim2.fromOffset(6, 4), From = 0.4, To = 0.95 })
		UI.glow(f, gold and C3(255, 214, 90) or C3(120, 190, 255), { Size = UDim2.fromOffset(120, 120), Position = UDim2.new(0.5, 0, 0, 62), ZIndex = 5 })
		local img = Config.ProductImages and Config.ProductImages[p.key]
		if img then
			new("ImageLabel", { BackgroundTransparency = 1, Image = img, ScaleType = Enum.ScaleType.Fit, Size = UDim2.fromOffset(108, 96), Position = UDim2.new(0.5, -54, 0, 14), ZIndex = 6, Parent = f })
		else
			UI.icon(FALLBACK[p.key] or "store", { Size = UDim2.fromOffset(96, 96), Position = UDim2.new(0.5, -48, 0, 14), ZIndex = 6, Parent = f })
		end
		UI.text({ Text = p.name, Size = UDim2.new(1, -16, 0, 26), Position = UDim2.fromOffset(8, 110), Color = UI.Ink, Stroke = false, Max = 21, ZIndex = 6, Parent = f })
		UI.text({ Text = desc or p.desc or "", Size = UDim2.new(1, -18, 0, 38), Position = UDim2.fromOffset(9, 138), Color = UI.Muted, Stroke = false, Max = 15, Wrap = true, ZIndex = 6, Parent = f })
		if p.tag then
			local tg = UI.pill({ Color = "red", Size = UDim2.fromOffset(116, 26), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, -12), ZIndex = 9, StrokeTh = 2.5, Parent = f })
			UI.text({ Text = p.tag, Size = UDim2.new(1, -10, 1, -6), Position = UDim2.fromOffset(5, 3), ZIndex = 11, Max = 15, StrokeTh = 1.6, Parent = tg })
		end
		local label = owned and "OWNED" or (p.price and ("R$ " .. p.price) or "BUY")
		UI.button({ Name = "Buy", Color = owned and "grey" or "green", Text = label, Size = UDim2.new(1, -20, 0, 46), AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 10, 1, -13),
			Max = 22, ZIndex = 6, Shimmer = not owned, Parent = f,
			OnClick = function() if not owned then onBuy() end end })
	end

	local function grid()
		for _, c in ipairs(content:GetChildren()) do c:Destroy() end
		local well = UI.well({ Size = UDim2.fromScale(1, 1), ZIndex = 4, Parent = content })
		local g = new("ScrollingFrame", { BackgroundTransparency = 1, Size = UDim2.new(1, -8, 1, -8), Position = UDim2.fromOffset(4, 4), CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
			ScrollBarThickness = 8, ScrollBarImageColor3 = UI.Ink, BorderSizePixel = 0, ZIndex = 5, Parent = well })
		new("UIGridLayout", { CellSize = UDim2.fromOffset(168, 236), CellPadding = UDim2.fromOffset(14, 22), SortOrder = Enum.SortOrder.LayoutOrder, HorizontalAlignment = Enum.HorizontalAlignment.Center, Parent = g })
		UI.pad(g, 6, 16, 14, 10)
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
