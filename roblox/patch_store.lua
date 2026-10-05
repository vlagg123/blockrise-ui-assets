-- one-off Studio patch: Store split into clear sub-menus (run in the Edit datamodel)
local cl = game.StarterPlayer.StarterPlayerScripts.Client
local s = cl.Source
local a = s:find("\t-- tabs\n\tlocal tabs = new(\"Frame\", { Size = UDim2.new(1, -8, 0, 46), BackgroundTransparency = 1, LayoutOrder = nextOrder(), ZIndex = 21, Parent = content })", 1, true)
local b = s:find("_G.__CE_ShowStore = showStore", 1, true)
assert(a and b, "store markers")
local itemStart = s:find("\tlocal function itemCard(", a, true)
local gemsStart = s:find("\tif storeTab == \"gems\" then\n", a, true)
assert(itemStart and gemsStart, "inner markers")
local helpers = s:sub(itemStart, gemsStart - 1) -- itemCard, robuxButton, visible stay as they are

local newTabs = [[
	-- sub-menus
	local TABS = {
		{ id = "gems", label = "GEMS", c1 = GEM1, c2 = GEM2 },
		{ id = "cash", label = "CASH", c1 = Color3.fromRGB(130, 240, 120), c2 = Color3.fromRGB(30, 160, 70) },
		{ id = "boosts", label = "BOOSTS", c1 = Color3.fromRGB(255, 205, 70), c2 = Color3.fromRGB(240, 130, 20) },
		{ id = "passes", label = "PASSES", c1 = Color3.fromRGB(205, 150, 255), c2 = Color3.fromRGB(125, 65, 230) },
		{ id = "gemshop", label = "GEM SHOP", c1 = Color3.fromRGB(255, 150, 200), c2 = Color3.fromRGB(215, 60, 140) },
	}
	UI.tabs(content, TABS, storeTab, function(id) click(); showStore(id) end, { LayoutOrder = nextOrder() })
]]

local body = [[
	-- the one-time starter pack sits on top of the Robux tabs until it's bought
	local function starterBanner()
		local starter
		for _, p in ipairs(Config.Store.products) do if p.key == "starter" then starter = p end end
		if starter and visible(starter) and not player:GetAttribute("StarterBought") then
			section("🎁 ONE-TIME OFFER", Color3.fromRGB(255, 200, 80))
			local f = itemCard(starter.icon, starter.name, starter.desc .. "  (worth " .. Config.FormatMoney(bestReward() * 20) .. " cash right now)", Color3.fromRGB(255, 120, 80), 100)
			UI.stroke(0.1, Color3.fromRGB(255, 200, 80), 3).Parent = f
			robuxButton(f, starter, false)
		end
	end

	if storeTab == "gemshop" then
		local intro = card(nextOrder(), 50)
		intro.BackgroundTransparency = 0.5
		UI.label({ Position = UDim2.fromOffset(14, 0), Size = UDim2.new(1, -170, 1, 0), Text = "💎 Spend Gems on boosts and helpers. Find Gems while you build, from missions and achievements.",
			TextSize = 14, TextWrapped = true, TextColor3 = T.muted, ZIndex = 22, Parent = intro })
		local more = UI.button("GET GEMS", GEM1, GEM2, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, -2), Size = UDim2.fromOffset(140, 36), TextSize = 17, ZIndex = 23, Parent = intro })
		more.Activated:Connect(function() click(); showStore("gems") end)
		local gems = player:GetAttribute("Gems") or 0
		for _, it in ipairs(Config.GemShop) do
			local desc = it.desc
			local cost = it.gems
			local disabled
			if it.kind == "cash" then
				desc = "Instant " .. Config.FormatMoney(bestReward() * it.mult) .. " (" .. it.mult .. "x your best contract)."
			elseif it.kind == "crewslot" then
				local owned = player:GetAttribute("GemCrewSlots") or 0
				if owned >= Config.MaxGemCrewSlots then disabled = "✔ MAX" else cost = Config.CrewSlotGems(owned) end
				desc = desc .. "  (" .. owned .. "/" .. Config.MaxGemCrewSlots .. " bought)"
			elseif it.kind == "finish" then
				local job = Jobs:FindFirstChild(player:GetAttribute("ContractJob") or "")
				if not job or job:GetAttribute("Done") then disabled = "No contract" else
					local title = job:GetAttribute("Title")
					local ord = 1
					for _, cc in ipairs(Config.Contracts) do if cc.name == title then ord = cc.order end end
					cost = Config.FinishGems(1 - (job:GetAttribute("Total") or 0), ord)
				end
			end
			local f = itemCard(it.icon, it.name, desc, Color3.fromRGB(40, 150, 230))
			if it.kind == "boost" then
				local left = player:GetAttribute("Boost_" .. it.boost) or 0
				if left > 0 then chip(f, "⏱ Active " .. fmtTime(left), T.green, 0).Position = UDim2.new(1, -300, 0, 14) end
			end
			if disabled then
				pill(f, disabled, T.muted)
			else
				local can = gems >= cost
				local bb = UI.button("💎 " .. Config.FormatNum(cost), can and GEM1 or T.bg3, can and GEM2 or T.bg2,
					{ AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -14, 0.5, 0), Size = UDim2.fromOffset(150, 52), TextSize = 21, ZIndex = 23, Parent = f })
				local busy = false
				bb.Activated:Connect(function()
					if busy then return end
					click()
					if not can then
						toast("💎 Not enough Gems — get more in the GEMS tab", T.red, 2.5)
						showStore("gems")
						return
					end
					busy = true
					local ok, res, msg = pcall(function() return R.GemShop:InvokeServer(it.id) end)
					busy = false
					if ok and res then
						if live(tok) then showStore("gemshop") end
					else
						toast("⚠️ " .. tostring(msg or "Can't buy that"), T.red)
					end
				end)
			end
		end
	elseif storeTab == "passes" then
		section("⭐ PERMANENT PASSES — buy once, keep forever", Color3.fromRGB(215, 175, 255))
		for _, p in ipairs(Config.Store.passes) do
			if visible(p) then
				local f = itemCard(p.icon, p.name, p.desc, Color3.fromRGB(255, 180, 40))
				if player:GetAttribute("Pass_" .. p.key) then pill(f, "✔ OWNED", T.green) else robuxButton(f, p, true) end
			end
		end
	elseif storeTab == "cash" then
		starterBanner()
		section("💰 CASH PACKS  <font color='#c9c3ee' size='14'>(they grow with your progress)</font>", T.green)
		for _, p in ipairs(Config.Store.products) do
			if p.cash and visible(p) then
				local f = itemCard(p.icon, p.name, "Instant " .. Config.FormatMoney(bestReward() * p.cash) .. " right now (" .. p.cash .. "x your best contract).", T.green2)
				robuxButton(f, p, false)
			end
		end
	elseif storeTab == "boosts" then
		section("⚡ BOOSTS  <font color='#c9c3ee' size='14'>(2x for a while — they stack with passes)</font>", T.accent)
		for _, p in ipairs(Config.Store.products) do
			if (p.boost or p.key == "rushcrew") and visible(p) then
				local f = itemCard(p.icon, p.name, p.desc, Color3.fromRGB(255, 160, 60))
				local left = p.key == "rushcrew" and ((player:GetAttribute("RushCrewEnds") or 0) - workspace:GetServerTimeNow()) or (player:GetAttribute("Boost_" .. tostring(p.boost)) or 0)
				if left > 0 then chip(f, "⚡ Active " .. fmtTime(left), T.accent, 0).Position = UDim2.new(1, -300, 0, 14) end
				robuxButton(f, p, false)
			end
		end
	else -- gems
		starterBanner()
		section("💎 GEM PACKS", GEM1)
		for _, p in ipairs(Config.Store.products) do
			if p.gems and visible(p) then
				local f = itemCard(p.icon, p.name, p.desc, Color3.fromRGB(40, 150, 230))
				if p.tag then chip(f, p.tag, T.accent, 0).Position = UDim2.new(1, -300, 0, 14) end
				robuxButton(f, p, false)
			end
		end
	end
end
]]
s = s:sub(1, a - 1) .. newTabs .. helpers .. body .. s:sub(b)
-- old tab names still used elsewhere
s = s:gsub('local storeTab = "gems"\nfunction showStore%(tab%)\n\tif type%(tab%) == "string" then storeTab = tab end',
	'local storeTab = "gems"\nfunction showStore(tab)\n\tif type(tab) == "string" then storeTab = (tab == "packs" and "gems") or tab end')
s = s:gsub('openModal%("Store", "💎 Store", "", GEM1, GEM2%)', 'openModal("Store", "Store", "", GEM1, GEM2)')
cl.Source = s
local fn, err = loadstring(s)
return "store patched, compile: " .. (fn and "OK" or tostring(err))
