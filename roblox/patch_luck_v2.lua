-- LUCK_V2 patch (run in Edit, 2026-10-14)
local SES = game:GetService("ScriptEditorService")
local function rep(out, old, new)
	local a = out:find(old, 1, true)
	if not a then error("missing: " .. old:sub(1, 100)) end
	if out:find(old, a + 1, true) then error("not unique: " .. old:sub(1, 100)) end
	return out:sub(1, a - 1) .. new .. out:sub(a + #old)
end
local jobs = {}
local function job(scr, fn)
	local out = fn(scr.Source)
	local f, err = loadstring(out)
	if not f then error(scr.Name .. " compile " .. tostring(err)) end
	table.insert(jobs, { scr, out })
end
local Cl = game.StarterPlayer.StarterPlayerScripts.Client

-- 1) Hammers: one luck for every rarity it lifts (no more "more luck, rarer Divines"), a cap, and luck works in every crate
job(game.ReplicatedStorage.Shared.Hammers, function(out)
	if out:find("LUCK_V2", 1, true) then error("already patched") end
	out = rep(out, [=[Hammers.LuckCapTop = 4 -- (LUCK_STACK 2026-10-07: Lucky Builder + Ultra Lucky = x4 stack fully, Secret and Divine too)]=],
		[=[Hammers.LuckCapTop = 4 -- (LUCK_STACK 2026-10-07: Lucky Builder + Ultra Lucky = x4 stack fully, Secret and Divine too)
-- LUCK_V2 (2026-10-14, the owner: "luck must really give much better chances"): every source adds up (Lucky Builder +100%,
-- Ultra Lucky +200%, the 2x Luck boost +100%, the Lucky Rush +100%, the Helmet, the hammer in hand, the Index); the total
-- lifts EVERY rarity from Legendary up that is rarer than the crate's own most common one by the same factor, at most x8.
-- (Before, Secret and Divine stopped at x4 while Legendary and Mythic kept growing: past x4 the top got RARER, and in the
-- Robux crates luck did nothing.) The Secret Hunter is x2 on Secret and Divine on top. The Exclusive never moves.
Hammers.LuckCap = 8]=])
	out = rep(out, [=[	local hunter = 1
	if type(luck) == "table" then hunter = tonumber(luck[2]) or 1; luck = luck[1] end
	luck = tonumber(luck) or 1
	local w, total = {}, 0
	local exW, baseTotal = 0, 0
	for r = 1, Hammers.LadderTop do
		local v = base[r] or 0
		if v > 0 and #Hammers.PoolAt(c, r) > 0 then
			baseTotal += v
			if r == Hammers.ExclusiveR then exW = v -- (no luck, no hunter: the Exclusive odds never move)
			else
				if r >= 7 then v *= math.min(luck, Hammers.LuckCapTop) * hunter
				elseif r >= Hammers.LuckFrom then v *= luck end
				w[r] = v; total += v
			end
		end
	end]=], [=[	local hunter = 1
	if type(luck) == "table" then hunter = tonumber(luck[2]) or 1; luck = luck[1] end
	luck = tonumber(luck) or 1
	if luck ~= luck then luck = 1 end -- (NAN_GUARD)
	if hunter ~= hunter then hunter = 1 end
	luck = math.clamp(luck, 1, Hammers.LuckCap)
	hunter = math.clamp(hunter, 1, 2)
	-- LUCK_V2: the crate's own most common rarity (its floor): luck lifts what is rarer than it
	local floorR, floorV = 0, -1
	for r = 1, Hammers.LadderTop do
		local v = base[r] or 0
		if r ~= Hammers.ExclusiveR and v > floorV and #Hammers.PoolAt(c, r) > 0 then floorR, floorV = r, v end
	end
	local w, total = {}, 0
	local exW, baseTotal = 0, 0
	for r = 1, Hammers.LadderTop do
		local v = base[r] or 0
		if v > 0 and #Hammers.PoolAt(c, r) > 0 then
			baseTotal += v
			if r == Hammers.ExclusiveR then exW = v -- (no luck, no hunter: the Exclusive odds never move)
			else
				if r > floorR then
					if r >= Hammers.LuckFrom then v *= luck end
					if r >= 7 then v *= hunter end
				end
				w[r] = v; total += v
			end
		end
	end]=])
	out = rep(out, [=[-- one hammer of a rarity's pool, by weight (h.w, 1 if not set)]=], [=[-- LUCK_V2: does luck (or the Secret Hunter) change anything in this crate? (a rarity it lifts can drop from it)
function Hammers.LuckAffects(crateId, zone, hunterOnly)
	local c = Hammers.CrateById[crateId]
	if not c or c.soon then return false end
	local base = c.odds or (c.pools and (c.pools[zone] or c.pools.town)) or {}
	local floorR, floorV = 0, -1
	for r = 1, Hammers.LadderTop do
		local v = base[r] or 0
		if r ~= Hammers.ExclusiveR and v > floorV and #Hammers.PoolAt(c, r) > 0 then floorR, floorV = r, v end
	end
	for r = math.max(floorR + 1, hunterOnly and 7 or Hammers.LuckFrom), Hammers.LadderTop do
		if r ~= Hammers.ExclusiveR and (base[r] or 0) > 0 and #Hammers.PoolAt(c, r) > 0 then return true end
	end
	return false
end

-- one hammer of a rarity's pool, by weight (h.w, 1 if not set)]=])
	return out
end)

-- 2) HammerService: the luck and the Secret Hunter of a builder, for Main to publish
job(game.ServerScriptService.Game.HammerService, function(out)
	out = rep(out, [=[-- Trading hooks (TradeService)]=],
		[=[-- LUCK_V2: a builder's luck and Secret Hunter (the same numbers every crate uses; Main publishes them for the windows)
function M.Luck(st) return (ctx and ctx.luck) and ctx.luck(st) or 1 end
function M.Hunter(st) return (ctx and ctx.hunter) and ctx.hunter(st) or 1 end

-- Trading hooks (TradeService)]=])
	return out
end)

-- 3) Main: the player attributes Luck and Hunter, kept up to date every second (a boost ticking, the Lucky Rush)
job(game.ServerScriptService.Game.Main, function(out)
	out = rep(out, [=[		for plr, st in pairs(S) do
			local b = st.data.Boosts
			if b then
				local changed = false]=], [=[		for plr, st in pairs(S) do
			-- LUCK_V2 (2026-10-14): the luck every crate uses right now, for the odds windows
			if st.data and st.data.Hammers then
				local okL, L = pcall(HammerService.Luck, st)
				if okL and type(L) == "number" and L == L then
					L = math.floor(L * 100 + 0.5) / 100
					if plr:GetAttribute("Luck") ~= L then plr:SetAttribute("Luck", L) end
				end
				local okH, H = pcall(HammerService.Hunter, st)
				if okH and type(H) == "number" and plr:GetAttribute("Hunter") ~= H then plr:SetAttribute("Hunter", H) end
			end
			local b = st.data.Boosts
			if b then
				local changed = false]=])
	return out
end)

-- 4) HammersUI: the windows use the live luck; the odds box shows the clover, every luck source and its countdown
job(Cl.HammersUI, function(out)
	out = rep(out, [=[	local luck = data and data.luck or 1
	local lk = { luck, data and data.hunter or 1 } -- (HUNTER_REAL: luck + the Secret Hunter pass)]=],
		[=[	local lk = liveLuck(data) -- (HUNTER_REAL: luck + the Secret Hunter pass; LUCK_V2: live)
	local luck = math.min(lk[1], Hammers.LuckCap or 8)]=])
	out = rep(out, [=[	local luck = data.luck or 1
	local lk = { luck, data.hunter or 1 } -- (HUNTER_REAL)]=], [=[	local lk = liveLuck(data) -- (HUNTER_REAL; LUCK_V2: live)
	local luck = math.min(lk[1], Hammers.LuckCap or 8)]=])
	out = rep(out, [=[		local odds = Hammers.Odds(crateId, zone, { d.luck or 1, d.hunter or 1 })
		if next(odds) then return oddsBar(t, odds, pos, size) end]=], [=[		local odds = Hammers.Odds(crateId, zone, liveLuck(d))
		if next(odds) then return oddsBar(t, odds, pos, size, { crate = crateId, zone = zone }) end]=])
	out = rep(out, [=[local function oddsBar(t, odds, pos, size)]=], [=[local function oddsBar(t, odds, pos, size, info)]=])
	out = rep(out, [=[	oddsTip(t, odds, pos, size)
	return top]=], [=[	oddsTip(t, odds, pos, size, info)
	return top]=])
	out = rep(out, [=[	if next(odds) then top = oddsBar(t, odds, UDim2.fromOffset(16, ART + 48), UDim2.new(1, -32, 0, 12)) end]=],
		[=[	if next(odds) then top = oddsBar(t, odds, UDim2.fromOffset(16, ART + 48), UDim2.new(1, -32, 0, 12), { crate = cr.id, zone = zone }) end]=])
	-- the luck rows
	out = rep(out, [=[local oddsTip
do
local openTip -- the hide() of the tip that is open
function oddsTip(t, odds, pos, size)]=], [=[local oddsTip
do
local openTip -- the hide() of the tip that is open
local RSl = game:GetService("ReplicatedStorage")
local function mmss(s)
	s = math.max(0, math.floor(s))
	local h, m, sec = s // 3600, (s % 3600) // 60, s % 60
	return h > 0 and string.format("%d:%02d:%02d", h, m, sec) or string.format("%d:%02d", m, sec)
end
local function fmtX(x) return (string.format("%.2f", x):gsub("%.?0+$", "")) end
-- LUCK_V2 (2026-10-14, the owner): under the odds, the clover: your luck and every source of it, a pass FOREVER, the 2x
-- Luck boost and the Lucky Rush with their countdowns. { left, right | attr | ends, head }
local function luckRows(info)
	local p = c.player
	local L, H = p:GetAttribute("Luck") or 1, p:GetAttribute("Hunter") or 1
	if L <= 1.001 and H <= 1 then return {} end
	local rows = {}
	local cap = Hammers.LuckCap or 8
	local passL, passU = p:GetAttribute("Pass_luck") == true, p:GetAttribute("Pass_ultraluck") == true
	local boost = (p:GetAttribute("Boost_luck") or 0) > 0
	local rushEnds = RSl:GetAttribute("LuckyHourEnds") or 0
	local rush = rushEnds > workspace:GetServerTimeNow()
	local affects = not info or Hammers.LuckAffects(info.crate, info.zone)
	local hunterAffects = not info or Hammers.LuckAffects(info.crate, info.zone, true)
	if L > 1.001 then
		table.insert(rows, { head = true, left = "🍀 YOUR LUCK x" .. fmtX(math.min(L, cap)) .. (L > cap + 0.001 and " (MAX)" or ""),
			right = affects and "IN THESE ODDS" or "NOT IN THIS CRATE" })
		if passL then table.insert(rows, { left = "Lucky Builder +100%", right = "FOREVER" }) end
		if passU then table.insert(rows, { left = "Ultra Lucky +200%", right = "FOREVER" }) end
		if boost then table.insert(rows, { left = "2x Luck boost +100%", attr = "Boost_luck" }) end
		if rush then table.insert(rows, { left = "Lucky Rush event +100%", ends = rushEnds }) end
		local other = L - 1 - (passL and 1 or 0) - (passU and 2 or 0) - (boost and 1 or 0) - (rush and 1 or 0)
		if other > 0.004 then table.insert(rows, { left = "Helmet, hammer, Index +" .. math.floor(other * 100 + 0.5) .. "%", right = "" }) end
	end
	if H > 1 then table.insert(rows, { head = L <= 1.001, left = "🔍 Secret Hunter: Secret & Divine x2", right = hunterAffects and "FOREVER" or "NOT HERE" }) end
	return rows
end
function oddsTip(t, odds, pos, size, info)]=])
	out = rep(out, [=[	local function show()
		if tip or not hit.Parent then return end
		if openTip then openTip() end
		local rows = {}]=], [=[	local function show()
		if tip or not hit.Parent then return end
		if openTip then openTip() end
		-- LUCK_V2: the odds with your luck right now (a boost or the Lucky Rush may have started or ended)
		if info and info.crate then
			local fresh = Hammers.Odds(info.crate, info.zone, liveLuck())
			if next(fresh) then odds = fresh end
		end
		local lrows = luckRows(info)
		local LH = 20
		local rows = {}]=])
	out = rep(out, [=[			Size = UDim2.fromOffset(W, #rows * RH + PAD * 2), BackgroundTransparency = 1, ZIndex = 200, Parent = sg })]=],
		[=[			Size = UDim2.fromOffset(W, #rows * RH + PAD * 2 + (#lrows > 0 and (#lrows * LH + 10) or 0)), BackgroundTransparency = 1, ZIndex = 200, Parent = sg })]=])
	out = rep(out, [=[		-- sideways: inside the window's list (the arrow stays on the bar)
		local sf = t:FindFirstAncestorWhichIsA("ScrollingFrame")]=], [=[		-- LUCK_V2: the luck rows under a thin line; the countdowns tick while the box is open
		if #lrows > 0 then
			local y0 = PAD + #rows * RH + 4
			new("Frame", { Name = "LuckLine", Position = UDim2.fromOffset(12, y0), Size = UDim2.new(1, -24, 0, 2), BackgroundColor3 = Color3.fromRGB(225, 225, 235),
				BorderSizePixel = 0, ZIndex = 202, Parent = box })
			local live = {}
			for i, lr in ipairs(lrows) do
				local y = y0 + 6 + (i - 1) * LH
				K.text({ Name = "LuckL", Position = UDim2.fromOffset(12, y), Size = UDim2.new(1, -110, 0, LH), Text = lr.left, Font = lr.head and T.chunky or (T.bold or T.body),
					TextSize = lr.head and 14 or 13, Max = lr.head and 14 or 13, TextColor3 = lr.head and Color3.fromRGB(40, 150, 70) or K.DARK, ZIndex = 202, Parent = box })
				local rt = K.text({ Name = "LuckR", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, y), Size = UDim2.fromOffset(92, LH), Text = lr.right or "",
					Font = T.chunky, TextSize = lr.head and 11 or 13, Max = lr.head and 11 or 13, TextXAlignment = Enum.TextXAlignment.Right,
					TextColor3 = lr.head and Color3.fromRGB(40, 150, 70) or Color3.fromRGB(70, 110, 220), ZIndex = 202, Parent = box })
				if lr.attr or lr.ends then table.insert(live, { label = rt, attr = lr.attr, ends = lr.ends }) end
			end
			if #live > 0 then
				local me = tip
				task.spawn(function()
					while tip == me and me.Parent do
						for _, lv in ipairs(live) do
							local left = lv.attr and (c.player:GetAttribute(lv.attr) or 0) or ((lv.ends or 0) - workspace:GetServerTimeNow())
							lv.label.Text = left > 0 and mmss(left) or "ENDED"
						end
						task.wait(0.5)
					end
				end)
			end
		end
		-- sideways: inside the window's list (the arrow stays on the bar)
		local sf = t:FindFirstAncestorWhichIsA("ScrollingFrame")]=])
	-- above the bar when it doesn't fit under it
	out = rep(out, [=[		tip.Position = UDim2.fromOffset(cx / g, (barY + 10 * k) / g)
		nib.Position = UDim2.new(0.5, (barX - cx) / k, 0, 0)]=], [=[		tip.Position = UDim2.fromOffset(cx / g, (barY + 10 * k) / g)
		nib.Position = UDim2.new(0.5, (barX - cx) / k, 0, 0)
		-- (LUCK_V2: a tall box that would run off the bottom of the screen goes above the bar, its arrow pointing down)
		if barY + 10 * k + tip.Size.Y.Offset * k > sg.AbsoluteSize.Y - 8 then
			local barTop = hit.AbsolutePosition.Y + 8 * k
			tip.AnchorPoint = Vector2.new(0.5, 1)
			tip.Position = UDim2.fromOffset(cx / g, (barTop - 10 * k) / g)
			nib.Position = UDim2.new(0.5, (barX - cx) / k, 1, 0)
		end]=])
	-- the live luck helper, before cratePopup
	out = rep(out, [=[-- what's inside a crate: every rarity it can drop, the odds and the hammers at that rarity
local function cratePopup(cr, data)]=], [=[-- LUCK_V2: { luck, hunter } right now (the server's player attributes, kept up to date every second; the Shop's data
-- before they arrive)
local function liveLuck(data)
	return { c.player:GetAttribute("Luck") or (data and data.luck) or 1, c.player:GetAttribute("Hunter") or (data and data.hunter) or 1 }
end

-- what's inside a crate: every rarity it can drop, the odds and the hammers at that rarity
local function cratePopup(cr, data)]=])
	-- the crate card: the luck label only where luck changes something
	out = rep(out, [=[	if luck > 1 and not cr.exclusiveOnly and top then]=], [=[	if luck > 1 and not cr.exclusiveOnly and top and Hammers.LuckAffects(cr.id, zone) then]=])
	return out
end)

for _, j in ipairs(jobs) do
	local scr, src = j[1], j[2]
	task.spawn(function() SES:UpdateSourceAsync(scr, function() return src end) end)
end
for i = 1, 25 do
	task.wait(2)
	local all = true
	for _, j in ipairs(jobs) do if j[1].Source ~= j[2] then all = false end end
	if all then return "applied " .. i * 2 .. "s" end
end
return "pending"
