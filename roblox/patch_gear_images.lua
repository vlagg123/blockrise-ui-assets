-- one-off patch (run in Edit): pictures (Blender, icons/gear.py) for the Shop's TRAINING gear, the MACHINES and the
-- Training Yard stations; the Shop and the station signs use them instead of emoji.
local function replaceOnce(src, old, new)
	local a, b = src:find(old, 1, true)
	assert(a, "not found: " .. old:sub(1, 80))
	assert(not src:find(old, b + 1, true), "found twice: " .. old:sub(1, 80))
	return src:sub(1, a - 1) .. new .. src:sub(b + 1)
end

-- Config: image fields
local Cfg = game.ReplicatedStorage.Shared.Config
local s = Cfg.Source
if not s:find("GEAR_IMAGES", 1, true) then
	local a = s:find("\nreturn Config%s*$")
	assert(a, "no 'return Config' at the end")
	s = s:sub(1, a) .. [[
-- GEAR_IMAGES: pictures for the training gear (by tier), the machines and the Training Yard stations
do
	local gearImg = {
		"rbxassetid://137887060990667", "rbxassetid://100244648837781", "rbxassetid://101401296563260", "rbxassetid://102484263523345",
		"rbxassetid://75200160905438", "rbxassetid://135567021439394", "rbxassetid://122449649779714", "rbxassetid://117063317084660",
		"rbxassetid://113707203716255", "rbxassetid://101924819275060", "rbxassetid://127389695645738", "rbxassetid://108541104556016",
	}
	for i, g in ipairs(Config.TrainingGear or {}) do g.image = gearImg[i] end
	local machineImg = { excavator = "rbxassetid://107454840179191", mixer = "rbxassetid://137384263913223", crane = "rbxassetid://119938480525340" }
	for _, m in ipairs(Config.Machines or {}) do m.image = machineImg[m.id] end
	local stationImg = { tires = "rbxassetid://91446133872711", beam = "rbxassetid://122449649779714", block = "rbxassetid://117063317084660",
		hoist = "rbxassetid://75900718576342" }
	for _, st in ipairs(Config.TrainingStations or {}) do st.image = stationImg[st.id] end
end

return Config
]]
	assert(loadstring(s), "Config compile")
	Cfg.Source = s
end

-- Shop: gear tiles and machine tiles show the pictures
local Shop = game.StarterPlayer.StarterPlayerScripts.Client.ShopUI
local sh = Shop.Source
if not sh:find("it.image or it.icon", 1, true) then
	sh = replaceOnce(sh, [[icon = it.icon or (Icons.has((icon .. "_" .. i)) and (icon .. "_" .. i) or icon), color = K.RAR[rk], iconScale = it.icon and 1.08 or nil,]],
		[[icon = it.image or it.icon or (Icons.has((icon .. "_" .. i)) and (icon .. "_" .. i) or icon), color = K.RAR[rk], iconScale = (it.image or it.icon) and 1.08 or nil,]])
	sh = replaceOnce(sh, [[local o = { order = i, name = m.name, icon = MACHINE_ICON[m.id] or m.icon, color = MACHINE_COL[m.id] or GOLD,]],
		[[local o = { order = i, name = m.name, icon = m.image or MACHINE_ICON[m.id] or m.icon, iconScale = m.image and 1.06 or nil, color = MACHINE_COL[m.id] or GOLD,]])
	assert(loadstring(sh), "ShopUI compile")
	Shop.Source = sh
end

-- Training Yard signs: the station picture next to its name, words instead of emoji
local Client = game.StarterPlayer.StarterPlayerScripts.Client
local c = Client.Source
if not c:find("STATION_PIC", 1, true) then
	c = replaceOnce(c, [[			line(0.07, 0.42, cfg.icon .. " " .. cfg.name, Color3.new(1, 1, 1), 30)
			line(0.5, 0.21, "x" .. cfg.mult .. " 💪 per rep", Color3.fromRGB(255, 170, 110), 18)]],
		[[			if cfg.image then -- STATION_PIC
				new("ImageLabel", { Position = UDim2.fromScale(0.03, 0.02), Size = UDim2.fromScale(0.2, 0.52), BackgroundTransparency = 1, Image = cfg.image,
					ScaleType = Enum.ScaleType.Fit, Parent = panel })
				local tl = line(0.07, 0.42, cfg.name, Color3.new(1, 1, 1), 30)
				tl.Position, tl.Size = UDim2.fromScale(0.24, 0.07), UDim2.fromScale(0.72, 0.42)
			else
				line(0.07, 0.42, cfg.icon .. " " .. cfg.name, Color3.new(1, 1, 1), 30)
			end
			line(0.5, 0.21, "x" .. cfg.mult .. " Strength per rep", Color3.fromRGB(255, 170, 110), 18)]])
	c = replaceOnce(c, [[				sg.t3.Text = open and "✔ Stand here & click to train" or ("🔒 Needs 💪 " .. Config.FormatNum(sg.cfg.req))]],
		[[				sg.t3.Text = open and "Stand here & click to train" or ("Needs " .. Config.FormatNum(sg.cfg.req) .. " Strength")]])
	assert(loadstring(c), "Client compile")
	Client.Source = c
end
return "gear / machine / station pictures patched"
