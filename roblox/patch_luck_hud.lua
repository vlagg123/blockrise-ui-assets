-- one-off patch (run in Edit), the owner's request of 2026-10-07 15:03:
--  * the LUCKY HOUR / 2x LUCK banner under the top strip: the game's rendered clover (Icons "up_luck", dark outline) on a
--    white round badge instead of the 🍀 emoji, so it reads on the green; it shows when a Lucky Hour starts (or a potion
--    is drunk) and stays 30 s or until tapped
--  * the bottom-left list (everything working for you): LUCKY HOUR with its time left; the 2x Luck potion with the clover;
--    every timed line counts down every second (boosts: the server sends the seconds left now and then, the list counts
--    down locally between two updates)
local function replaceOnce(src, old, new, what)
	local a, b = src:find(old, 1, true)
	assert(a, "not found: " .. (what or old:sub(1, 80)))
	assert(not src:find(old, b + 1, true), "found twice: " .. (what or old:sub(1, 80)))
	return src:sub(1, a - 1) .. new .. src:sub(b + 1)
end
local HUD
for _, d in ipairs(game.StarterPlayer:GetDescendants()) do
	if d:IsA("ModuleScript") and d.Source:find("LuckPill", 1, true) and d.Source:find("updateEffects", 1, true) then HUD = d end
end
assert(HUD, "HUD with LuckPill not found")
local s = HUD.Source
if s:find("LUCK_HUD", 1, true) then return "already patched" end

-- 1) the banner -------------------------------------------------------------------------------------------------------
local a = s:find("\t-- ECONOMY_V4: LUCKY HOUR", 1, true)
assert(a, "LuckPill block start")
local b0 = s:find("\t\t\t\ttask.wait(1)\n\t\t\tend\n\t\tend)\n\tend\n", a, true)
assert(b0, "LuckPill block end")
local b = b0 + #"\t\t\t\ttask.wait(1)\n\t\t\tend\n\t\tend)\n\tend\n" - 1
s = s:sub(1, a - 1) .. [==[
	-- ECONOMY_V4 / LUCK_HUD: LUCKY HOUR (x2 luck on every server, 15 min every 3 hours) and the 2x Luck potion. A banner
	-- under the top strip when one starts: the rendered clover on a white badge, 30 s or until tapped. While it lasts it
	-- is also in the bottom-left list, with its time left.
	do
		local RSv = game:GetService("ReplicatedStorage")
		local pill = new("TextButton", { Name = "LuckPill", AutoButtonColor = false, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 62),
			Size = UDim2.fromOffset(380, 42), BackgroundColor3 = Color3.fromRGB(40, 170, 90), Text = "", Visible = false, ZIndex = 25, Parent = root })
		new("UICorner", { CornerRadius = UDim.new(1, 0), Parent = pill })
		new("UIStroke", { Thickness = 2.5, Color = Color3.fromRGB(20, 70, 40), ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = pill })
		local badge = new("Frame", { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 4, 0.5, 0), Size = UDim2.fromOffset(34, 34),
			BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 26, Parent = pill })
		new("UICorner", { CornerRadius = UDim.new(1, 0), Parent = badge })
		new("UIStroke", { Thickness = 2, Color = Color3.fromRGB(20, 70, 40), ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = badge })
		Icons.make("up_luck", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(30, 30), ZIndex = 27, Parent = badge })
		local lbl = new("TextLabel", { Position = UDim2.fromOffset(46, 0), Size = UDim2.new(1, -60, 1, 0), BackgroundTransparency = 1, Text = "",
			TextColor3 = Color3.new(1, 1, 1), Font = Enum.Font.FredokaOne, TextSize = 20, TextScaled = true, TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 26, Parent = pill })
		new("UITextSizeConstraint", { MaxTextSize = 20, Parent = lbl })
		local shownUntil, wasHour, lastPotion = 0, false, 0
		pill.Activated:Connect(function()
			shownUntil = 0
			pill.Visible = false
		end)
		local function mmss(x) x = math.max(0, math.floor(x)); return string.format("%d:%02d", x // 60, x % 60) end
		task.spawn(function()
			while root.Parent do
				local now = workspace:GetServerTimeNow()
				local ends = RSv:GetAttribute("LuckyHourEnds") or 0
				local potion = player:GetAttribute("Boost_luck") or 0
				local hour = ends > now
				if hour and not wasHour then shownUntil = now + 30 end                         -- a Lucky Hour starts
				if potion > lastPotion + 5 then shownUntil = math.max(shownUntil, now + 30) end -- a potion is drunk
				wasHour, lastPotion = hour, potion
				local t
				if hour then
					t = "LUCKY HOUR  x2 luck  " .. mmss(ends - now) .. (potion > 0 and "  +  2x LUCK" or "")
				elseif potion > 0 then
					t = "2x LUCK  " .. mmss(potion)
				end
				lbl.Text = t or ""
				pill.Visible = t ~= nil and now < shownUntil
				task.wait(0.5)
			end
		end)
	end
]==] .. s:sub(b + 1)

-- 2) the bottom-left list ---------------------------------------------------------------------------------------------
s = replaceOnce(s, [==[	local BOOST_ICON = { cash = "up_cash", strength = "up_strength", power = "up_power", crew = "up_crew" }]==],
	[==[	local BOOST_ICON = { cash = "up_cash", strength = "up_strength", power = "up_power", crew = "up_crew", luck = "up_luck" }]==], "BOOST_ICON")
s = replaceOnce(s, [==[crew = Color3.fromRGB(90, 170, 255) }
	-- passes that are cars]==], [==[crew = Color3.fromRGB(90, 170, 255),
		luck = Color3.fromRGB(80, 220, 120) }
	-- LUCK_HUD: the boosts' end times on this client (the server sends the seconds left now and then; the list counts down)
	local boostEnds = {}
	-- passes that are cars]==], "BOOST_COL")
s = replaceOnce(s, [==[			local left = player:GetAttribute("Boost_" .. key) or 0
			if left > 0 then]==], [==[			local raw = player:GetAttribute("Boost_" .. key) or 0
			local e = boostEnds[key]
			if raw <= 0 then
				boostEnds[key] = nil
			elseif not e or math.abs((e - now) - raw) > 2 then
				boostEnds[key] = now + raw
			end
			local left = boostEnds[key] and (boostEnds[key] - now) or 0
			if left > 0 then]==], "boost left")
s = replaceOnce(s, [==[		local rush = (player:GetAttribute("RushCrewEnds") or 0) - now]==], [==[		-- LUCK_HUD: the server's Lucky Hour
		local lh = (RS:GetAttribute("LuckyHourEnds") or 0) - now
		if lh > 0 then add("luckyhour", "up_luck", Color3.fromRGB(80, 220, 120), 2, "LUCKY HOUR X2 LUCK  " .. fmtTime(lh)) end
		local rush = (player:GetAttribute("RushCrewEnds") or 0) - now]==], "rush")
assert(loadstring(s), "HUD compile")
HUD.Source = s
return "HUD: luck banner + list (" .. HUD:GetFullName() .. ")"
