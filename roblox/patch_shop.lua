-- one-off Studio patch: Equipment Store split into sub-menus (Tools · Training · Machines · Crew)
local cl = game.StarterPlayer.StarterPlayerScripts.Client
local s = cl.Source
local function rep(old, new)
	local a, b = s:find(old, 1, true)
	assert(a, "not found: " .. old:sub(1, 70))
	s = s:sub(1, a - 1) .. new .. s:sub(b + 1)
end

-- tabs at the top of the shop (the choice is remembered on the HUD gui)
rep([[	openModal("Shop", "🛠️ Equipment Store", "", Color3.fromRGB(110, 190, 255), T.blue2)
	if scroll then task.defer(function() content.CanvasPosition = scroll end) end
	local tier = player:GetAttribute("ToolTier") or 1
]], [[	openModal("Shop", "Equipment Store", "", Color3.fromRGB(110, 190, 255), T.blue2)
	if scroll then task.defer(function() content.CanvasPosition = scroll end) end
	local tier = player:GetAttribute("ToolTier") or 1
	local shopTab = gui:GetAttribute("ShopTab") or "tools"
	modalSub.Text = Config.FormatMoney(player:GetAttribute("Money") or 0)
	UI.tabs(content, {
		{ id = "tools", label = "TOOLS", c1 = Color3.fromRGB(110, 200, 255), c2 = Color3.fromRGB(40, 110, 230) },
		{ id = "gear", label = "TRAINING", c1 = Color3.fromRGB(255, 170, 110), c2 = Color3.fromRGB(225, 85, 40) },
		{ id = "machines", label = "MACHINES", c1 = Color3.fromRGB(255, 214, 70), c2 = Color3.fromRGB(240, 135, 20) },
		{ id = "crew", label = "CREW", c1 = Color3.fromRGB(130, 240, 140), c2 = Color3.fromRGB(30, 160, 80) },
	}, shopTab, function(id)
		click()
		if id == "crew" then
			if _G.__CE_ShowHire then _G.__CE_ShowHire() end
		else
			gui:SetAttribute("ShopTab", id)
			showShop()
		end
	end, { LayoutOrder = -100 })
]])

-- the crew card moved to its own tab (the Hiring window)
local c1 = s:find("\t-- crew: hire workers right from the shop", 1, true)
local c2 = s:find("hb.Activated:Connect(function() click(); if _G.__CE_ShowHire then _G.__CE_ShowHire() end end)\n\tend\n", 1, true)
assert(c1 and c2, "crew block")
local c2e = c2 + #"hb.Activated:Connect(function() click(); if _G.__CE_ShowHire then _G.__CE_ShowHire() end end)\n\tend\n" - 1
s = s:sub(1, c1 - 1) .. s:sub(c2e + 1)

-- tools / gear / machines only on their own tab
rep("\tlocal th = new(\"Frame\", { Size = UDim2.new(1, -8, 0, 30)", "\tif shopTab == \"tools\" then\n\tlocal th = new(\"Frame\", { Size = UDim2.new(1, -8, 0, 30)")
rep("\t-- Training gear section\n", "\tend\n\t-- Training gear section\n\tif shopTab == \"gear\" then\n")
rep("\t-- Machines section\n", "\tend\n\t-- Machines section\n\tif shopTab == \"machines\" then\n")
-- close the machines block right before the end of showShop
local h = s:find("\n%-%- Hiring office %-%-")
assert(h, "hire marker")
local before = s:sub(1, h - 1)
local lastEnd = before:match(".*()\nend\n")
assert(lastEnd, "end of showShop")
s = before:sub(1, lastEnd) .. "\tend\n" .. before:sub(lastEnd + 1) .. s:sub(h)

-- the Hiring window shows the same tabs, with CREW selected
rep([[	openModal("Hire", "👷 Hiring Office", "Crew " .. count .. " / " .. max, Color3.fromRGB(120, 226, 140), T.green2)
]], [[	openModal("Hire", "Hiring Office", "Crew " .. count .. " / " .. max, Color3.fromRGB(120, 226, 140), T.green2)
	UI.tabs(content, {
		{ id = "tools", label = "TOOLS" }, { id = "gear", label = "TRAINING" }, { id = "machines", label = "MACHINES" },
		{ id = "crew", label = "CREW", c1 = Color3.fromRGB(130, 240, 140), c2 = Color3.fromRGB(30, 160, 80) },
	}, "crew", function(id)
		click()
		gui:SetAttribute("ShopTab", id)
		showShop()
	end, { LayoutOrder = -100 })
]])

cl.Source = s
local fn, err = loadstring(s)
return "shop patched, compile: " .. (fn and "OK" or tostring(err))
