-- one-off patch (run in Edit):
--  * the last tutorial step: the trip home is a free teleport (PLACES → GO at My Property), free for everyone, any time
--    (the walk to Maple Grove was long and boring); the step tells you so
--  * E on your own lot's sign at the last step finishes the tutorial AND opens the house menu (it took two presses:
--    the first only finished the step, the menu was still "locked" for that moment)
--  * the SKIP FOREVER card: its two lines of text never jump between rows while the card pulses
local function replaceOnce(src, old, new, what)
	local a, b = src:find(old, 1, true)
	assert(a, "not found: " .. (what or old:sub(1, 80)))
	assert(not src:find(old, b + 1, true), "found twice: " .. (what or old:sub(1, 80)))
	return src:sub(1, a - 1) .. new .. src:sub(b + 1)
end
local ConfigM = game:GetService("ReplicatedStorage").Shared.Config
local Main = game:GetService("ServerScriptService").Game.Main
local Client = game.StarterPlayer.StarterPlayerScripts.Client
if Client.Source:find("HOME_FREE_GO", 1, true) then return "already patched" end

local cfg = replaceOnce(ConfigM.Source,
	[==[desc = "Your own lot is in Maple Grove, south of the town. Follow the arrow and walk onto it: that's the end of the tutorial!",]==],
	[==[desc = "Your own lot is in Maple Grove, south of the town. Open PLACES and tap GO at My Property: the trip home is always free!",]==])
assert(loadstring(cfg), "compile Config")

local m = replaceOnce(Main.Source, [==[		pp.Triggered:Connect(function(plr)
			local st = S[plr]
			if st and st.lot == lot then OpenUIRE:FireClient(plr, "Property") end
		end)]==], [==[		pp.Triggered:Connect(function(plr)
			local st = S[plr]
			if st and st.lot == lot then
				-- the tutorial's "Visit your property" is done right here (not a second later in the visit loop), so the
				-- house menu opens on the same press
				local step = Config.Road[st.data.Road]
				if step and step.stat == "VisitedHome" then
					st.data.Stats = st.data.Stats or {}
					st.data.Stats.home = 1
					roadCheck(plr)
				end
				OpenUIRE:FireClient(plr, "Property")
			end
		end)]==])
assert(loadstring(m), "compile Main")

local s = Client.Source
-- HOME_FREE_GO: at the last step the house menu and PLACES open (PLACES is how you get home)
s = replaceOnce(s, [==[	if step <= (Config.TutorialSteps or 7) then
		if name == "Company" or name == "Garage" or name == "Property" or name == "Upgrades" or name == "Inventory" or name == "Rebirth" or name == "Locations" then]==],
	[==[	if step <= (Config.TutorialSteps or 7) then
		-- HOME_FREE_GO: the last step (your property) opens the house menu and PLACES (the free trip home)
		local home = Config.Road[step] and Config.Road[step].place == "home"
		if (name == "Property" or name == "Locations") and home then
			-- (falls through: opens)
		elseif name == "Company" or name == "Garage" or name == "Property" or name == "Upgrades" or name == "Inventory" or name == "Rebirth" or name == "Locations" then]==])
s = replaceOnce(s, [==[			or tp == "home" and "🏠 Last step: walk to YOUR PROPERTY in Maple Grove — follow the arrow"]==],
	[==[			or tp == "home" and "🏠 Last step: open PLACES and tap GO at My Property — the trip home is free!"]==])

-- the SKIP FOREVER card: two fixed lines (no wrapping: under the pulse's UIScale a wrapped word jumped to the next row),
-- and the card as wide as its longest line
s = replaceOnce(s, [==[				local t1 = UI.label({ Position = UDim2.fromOffset(tx, 8), Size = UDim2.new(1, -tx - 90, 0, 30), Text = "SKIP FOREVER", Font = T.title, TextSize = 25,
					TextColor3 = Color3.new(1, 1, 1), ZIndex = 5, Parent = b })
				UI.textStroke(0.1, 2.5).Parent = t1
				local t2 = UI.label({ Position = UDim2.fromOffset(tx, 39), Size = UDim2.new(1, -tx - 90, 0, 36), Text = "Permanent pass: no build animation on any building, ever",
					Font = T.bold, TextSize = 14, TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top, TextColor3 = Color3.fromRGB(236, 255, 236), ZIndex = 5, Parent = b })
				UI.textStroke(0.3, 1.5).Parent = t2]==], [==[				local t1 = UI.label({ Position = UDim2.fromOffset(tx, 8), Size = UDim2.new(1, -tx - 90, 0, 30), Text = "SKIP FOREVER", Font = T.title, TextSize = 25,
					TextWrapped = false, TextColor3 = Color3.new(1, 1, 1), ZIndex = 5, Parent = b })
				UI.textStroke(0.1, 2.5).Parent = t1
				local t2 = UI.label({ Position = UDim2.fromOffset(tx, 39), Size = UDim2.new(1, -tx - 90, 0, 36), Text = "Permanent pass: no build animation\non any building, ever",
					Font = T.bold, TextSize = 14, TextWrapped = false, TextScaled = false, TextYAlignment = Enum.TextYAlignment.Top, TextColor3 = Color3.fromRGB(236, 255, 236), ZIndex = 5, Parent = b })
				UI.textStroke(0.3, 1.5).Parent = t2
				do
					local TS = game:GetService("TextService")
					local wMax = TS:GetTextSize("SKIP FOREVER", 25, t1.Font, Vector2.new(2000, 100)).X
					for line in t2.Text:gmatch("[^\n]+") do wMax = math.max(wMax, TS:GetTextSize(line, 14, t2.Font, Vector2.new(2000, 100)).X) end
					b.Size = UDim2.fromOffset(math.max(350, tx + wMax + 90 + 14), 86)
				end]==])
assert(loadstring(s), "compile Client")

ConfigM.Source = cfg
Main.Source = m
Client.Source = s
return "tutorial v4e"
