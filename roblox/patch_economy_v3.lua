-- one-off patch (run in Edit): ECONOMY V3.
-- Strength is a gate, not an engine (log curve). Contracts need a bit of everything (level, rep, strength, crew size,
-- hammer rarity) and each zone opens with a Rebirth. Foreman builds and boosts the crew (+20%, two at most). Upgrade levels
-- are capped per zone. Cash packs (Robux / Gems) are worth minutes of YOUR income. Rebirth costs follow the zones.
local function replaceOnce(src, old, new)
	local a, b = src:find(old, 1, true)
	assert(a, "not found: " .. old:sub(1, 90))
	assert(not src:find(old, b + 1, true), "found twice: " .. old:sub(1, 90))
	return src:sub(1, a - 1) .. new .. src:sub(b + 1)
end
local RS = game:GetService("ReplicatedStorage")
local Cfg, Comp = RS.Shared.Config, RS.Shared.Company
local G = game.ServerScriptService.Game
local Main, Crew, CS, Reb = G.Main, G.Crew, G.CompanyService, G.RebirthService
local c, co, m, cr, cs, rb = Cfg.Source, Comp.Source, Main.Source, Crew.Source, CS.Source, Reb.Source
if c:find("ECONOMY_V3", 1, true) then return "already patched" end

-- Config ----------------------------------------------------------------------------------------------
c = replaceOnce(c, [[function Config.StrengthMult(s)
	return 1 + math.sqrt(math.max(0, s or 0)) / 10
end]], [[-- ECONOMY_V3: Strength multiplies your power gently (x3 at 10K, x5.6 at 1M, x8 at 1B); it mostly unlocks bigger jobs
function Config.StrengthMult(s)
	return 1 + 0.35 * math.log(1 + math.max(0, s or 0) / 100, 2)
end]])
c = replaceOnce(c, [[	{ id = "foreman", name = "Foreman", price = 3000, rate = 0.2, boost = 0.25, reqLevel = 5,]],
	[[	{ id = "foreman", name = "Foreman", price = 6000, rate = 0.6, boost = 0.20, reqLevel = 5,]])
c = replaceOnce(c, [[		{ key = "cashstack", id = 3716763367, price = 49, icon = "💵", name = "Cash Stack", desc = "Instant cash: 4x your best contract reward.", cash = 4 },
		{ key = "cashvault", id = 3716763403, price = 199, icon = "🏦", name = "Cash Vault", desc = "Instant cash: 20x your best contract reward.", cash = 20 },
		{ key = "cashbank", id = 3716763439, price = 699, icon = "🏛️", name = "Cash Empire", desc = "Instant cash: 80x your best contract reward.", cash = 80 },]],
	[[		{ key = "cashstack", id = 3716763367, price = 49, icon = "💵", name = "Cash Stack", desc = "Instant cash: 20 minutes of your income, right now.", minutes = 20 },
		{ key = "cashvault", id = 3716763403, price = 199, icon = "🏦", name = "Cash Vault", desc = "Instant cash: 1 hour 30 of your income. Best value per Robux.", minutes = 90 },
		{ key = "cashbank", id = 3716763439, price = 699, icon = "🏛️", name = "Cash Empire", desc = "Instant cash: 5 hours of your income. Skip a whole evening of grinding.", minutes = 300 },
		{ key = "crate_golden", id = 0, price = 149, icon = "📦", name = "Golden Crate", desc = "A Golden Crate: Rare or better, up to Divine. Pity: Legendary+ every 20.", crate = "golden", count = 1 },
		{ key = "crate_golden3", id = 0, price = 399, icon = "📦", name = "3 Golden Crates", desc = "Three Golden Crates (save 10%).", crate = "golden", count = 3 },
		{ key = "crate_exclusive", id = 0, price = 399, icon = "🎁", name = "Exclusive Crate", desc = "Hammers nobody else can get. Legendary, Mythic or Secret. Pity: Secret every 25.", crate = "exclusive", count = 1 },
		{ key = "crate_exclusive3", id = 0, price = 999, icon = "🎁", name = "3 Exclusive Crates", desc = "Three Exclusive Crates (save 17%).", crate = "exclusive", count = 3 },]])
c = replaceOnce(c, [[		{ key = "goldcar", id = 2004543731, price = 599, icon = "✨", name = "Golden Supercar", desc = "Exclusive vehicle: the fastest car in BlockRise, made of pure gold." },]],
	[[		{ key = "goldcar", id = 2004543731, price = 599, icon = "✨", name = "Golden Supercar", desc = "Exclusive vehicle: the fastest car in BlockRise, made of pure gold." },
		{ key = "luck", id = 0, price = 299, icon = "🍀", name = "Lucky Builder", desc = "2x luck in every crate: Rare and better hammers drop twice as often, and Builder's Crates drop twice as often. Forever." },
		{ key = "offline", id = 0, price = 199, icon = "🌙", name = "Night Shift", desc = "Your properties earn 2x rent while you're offline. Forever." },]])
c = replaceOnce(c, [[	{ id = "cashbag", kind = "cash", mult = 1.5, gems = 40, name = "Cash Bag", icon = "💵", desc = "Instant cash: 1.5x your best contract reward." },
	{ id = "cashsafe", kind = "cash", mult = 9, gems = 200, name = "Cash Safe", icon = "💼", desc = "Instant cash: 9x your best contract reward." },]],
	[[	{ id = "cashbag", kind = "cash", minutes = 10, gems = 40, name = "Cash Bag", icon = "💵", desc = "Instant cash: 10 minutes of your income." },
	{ id = "cashsafe", kind = "cash", minutes = 60, gems = 200, name = "Cash Safe", icon = "💼", desc = "Instant cash: 1 hour of your income." },]])
-- the per-contract numbers, zones by rebirth, the Road, income per minute: appended before `return Config`
c = replaceOnce(c, "\nreturn Config", [[

-- ECONOMY_V3 ------------------------------------------------------------------------------------------
-- workMult (tuned on the simulator for 25 s ... 6 min first builds), crew size, hammer rarity (1 Common .. 8 Divine), rebirth
do
	local V3 = {
		fence = { 4.35, 0, 1, 0 }, shed = { 3.3, 0, 1, 0 }, garage = { 2.98, 1, 1, 0 }, house = { 3.33, 2, 2, 0 }, shop = { 5.04, 3, 2, 0 },
		villa = { 9.77, 4, 3, 1 }, warehouse = { 13.04, 5, 3, 1 }, apartments = { 9.64, 6, 3, 1 }, luxvilla = { 18.52, 7, 3, 1 }, distcenter = { 28.67, 8, 4, 1 },
		office = { 23.05, 8, 4, 2 }, hotel = { 18.09, 9, 4, 2 }, skyscraper = { 16.81, 10, 4, 2 }, hq = { 16.31, 10, 4, 3 }, spire = { 19.24, 12, 4, 4 },
	}
	for _, ct in ipairs(Config.Contracts) do
		local v = V3[ct.id]
		if v then ct.workMult, ct.reqCrew, ct.reqHammer, ct.reqRebirth = v[1], v[2], v[3], v[4] end
	end
end
-- zones open with a Rebirth (the Rep numbers stay as a hint of when you're ready)
Config.Zones.suburbs.rebirth = 1
Config.Zones.downtown.rebirth = 2
-- Rebirth: permanent crew slots, upgrade caps per zone (10 in Town, 20 with the Suburbs, 30 with Downtown)
Config.RebirthCrewSlots = 1
function Config.DeptCap(rebirths) return math.min(50, 10 * (1 + math.min(2, rebirths or 0))) end
-- what a minute of play is worth at this stage (cash packs are priced in minutes of income)
function Config.IncomePerMin(bestContract, payMult)
	local ct = bestContract or Config.Contracts[1]
	return ct.reward * (payMult or 1) * 1.1 / ((ct.targetTime + 20) / 60)
end
-- the Road follows the new order: Rebirth opens the zones, hammers come from crates
do
	local R = Config.Road
	R[4] = { title = "Your first crate", desc = "Open the Shop (HAMMERS tab) and open a Supply Crate: every crate holds a new hammer. Better hammers hit harder.", stat = "Hammers", target = 2, place = "shop", cash = 100, gems = 5 }
	R[18] = { title = "First Rebirth", desc = "Earn $150K in this run, then press REBIRTH: you restart stronger and the SUBURBS open with bigger contracts.", stat = "Rebirths", target = 1, place = "rebirth", cash = 3000, gems = 25 }
	R[35] = { title = "Second Rebirth", desc = "Earn $40M in this run and Rebirth again: DOWNTOWN opens, with the skyscraper sites.", stat = "Rebirths", target = 2, place = "rebirth", cash = 150000, gems = 60 }
	R[38] = { title = "Third Rebirth", desc = "Earn $10B in this run and Rebirth: the Corporate HQ contract unlocks.", stat = "Rebirths", target = 3, place = "rebirth", cash = 50000, gems = 100 }
	R[42] = { title = "Fourth Rebirth", desc = "Earn $100B in this run and Rebirth: the Landmark Spire unlocks.", stat = "Rebirths", target = 4, place = "rebirth", cash = 250000, gems = 100 }
	R[44] = { title = "Collector", desc = "Own 12 different hammers (Shop → HAMMERS → INDEX). Trade 10 of one rarity up to the next!", stat = "Hammers", target = 12, place = "shop", cash = 500000, gems = 120 }
	R[46] = { title = "Legendary hands", desc = "Own a Legendary (or better) hammer: Golden Crates, trade-ups or a trade with another builder.", stat = "ToolTier", target = 5, place = "shop", cash = 2000000, gems = 150 }
end

return Config]])
assert(loadstring(c), "Config compile")

-- Company: rebirth costs follow the zones ---------------------------------------------------------------
co = replaceOnce(co, [[function Company.FranchiseCost(n) return math.floor(25e6 * 4 ^ (n or 0)) end -- money earned in this run]],
	[[-- ECONOMY_V3: Town -> Suburbs 150K, Suburbs -> Downtown 40M, then 10B, 100B, 1T, x10 after (money earned in this run)
local FRANCHISE = { 150e3, 40e6, 10e9, 100e9, 1e12 }
function Company.FranchiseCost(n)
	n = n or 0
	if n < #FRANCHISE then return FRANCHISE[n + 1] end
	return math.floor(FRANCHISE[#FRANCHISE] * 10 ^ (n - #FRANCHISE + 1))
end]])
assert(loadstring(co), "Company compile")

-- Crew: the foreman boost caps at two foremen -----------------------------------------------------------
cr = replaceOnce(cr, [[					if flat(pos - center) < job.radius then boostNow += (t.boost or 0) end]],
	[[					if flat(pos - center) < job.radius then boostNow = math.min(0.40, boostNow + (t.boost or 0)) end -- ECONOMY_V3: two foremen at most]])
assert(loadstring(cr), "Crew compile")

-- CompanyService: upgrade caps per zone; Night Shift pass doubles offline rent ----------------------------
cs = replaceOnce(cs, [[	local lv = dept(d, id)
	if lv >= Company.DeptMax then return false, "Max level" end]], [[	local lv = dept(d, id)
	if lv >= Company.DeptMax then return false, "Max level" end
	if lv >= Config.DeptCap(d.Rebirths) then return false, "Level " .. Config.DeptCap(d.Rebirths) .. " is the cap for now: Rebirth to raise it" end]])
cs = replaceOnce(cs, [[	local amount = math.floor(M.RentPerMin(st) * secs / 60)
	if amount <= 0 then return end]], [[	local amount = math.floor(M.RentPerMin(st) * secs / 60)
	if st.passes and st.passes.offline then amount *= 2 end
	if amount <= 0 then return end]])
cs = replaceOnce(cs, [[		table.insert(depts, { id = dp.id, level = lv, cash = cash, mats = mats })]],
	[[		table.insert(depts, { id = dp.id, level = lv, cash = cash, mats = mats, cap = Config.DeptCap(d.Rebirths) })]])
assert(loadstring(cs), "CompanyService compile")

-- RebirthService: you must have built the zone's last building first --------------------------------------
rb = replaceOnce(rb, [[	if run < cost then return false, "Earn " .. Config.FormatMoney(cost - run) .. " more before you can Rebirth" end]],
	[[	if run < cost then return false, "Earn " .. Config.FormatMoney(cost - run) .. " more before you can Rebirth" end
	local gate
	for _, ct in ipairs(Config.Contracts) do if (ct.reqRebirth or 0) == d.Rebirths then gate = ct end end
	if gate and (d.Portfolio[gate.id] or 0) < 1 then return false, "Build the " .. gate.name .. " once before you Rebirth" end]])
assert(loadstring(rb), "RebirthService compile")

-- Main -------------------------------------------------------------------------------------------------------
m = replaceOnce(m, [[	elseif stat == "Workers" then return #d.Workers]], [[	elseif stat == "Workers" then return #d.Workers
	elseif stat == "Hammers" then
		local n = 0
		for _ in pairs(d.Index or {}) do n += 1 end
		return n]])
m = replaceOnce(m, [[	return Config.MaxWorkers(d.Level) + ((d.Extensions and d.Extensions.garage) and Config.GarageCrewBonus or 0)
		+ (d.BigCrewPass and Config.BigCrewSlots or 0) + (d.GemCrewSlots or 0) + (d.Company and CompanyService.ExtraCrewSlots(d) or 0)]],
	[[	return Config.MaxWorkers(d.Level) + ((d.Extensions and d.Extensions.garage) and Config.GarageCrewBonus or 0)
		+ (d.BigCrewPass and Config.BigCrewSlots or 0) + (d.GemCrewSlots or 0) + (d.Company and CompanyService.ExtraCrewSlots(d) or 0)
		+ (d.Rebirths or 0) * Config.RebirthCrewSlots]])
-- contractUnlocked is needed by sync (defined earlier): forward declaration
m = replaceOnce(m, [[local roadCheck -- Empire Road (defined below sync)
]], [[local roadCheck -- Empire Road (defined below sync)
local contractUnlocked -- (defined with the contracts; sync needs it for the income estimate)
]])
m = replaceOnce(m, [[local function contractUnlocked(d, c)
	return d.Rep >= c.reqRep and d.Level >= c.reqLevel and (d.Strength or 0) >= (c.reqStrength or 0) and (d.Rebirths or 0) >= (c.reqRebirth or 0)
end
local function lockReason(d, c)
	if (d.Rebirths or 0) < (c.reqRebirth or 0) then return "Requires Rebirth " .. c.reqRebirth .. " (press the REBIRTH button)" end
	if d.Level < c.reqLevel then return "Requires Level " .. c.reqLevel end
	if d.Rep < c.reqRep then return "Requires " .. c.reqRep .. " Reputation" end
	if (d.Strength or 0) < (c.reqStrength or 0) then return "Requires " .. Config.FormatNum(c.reqStrength) .. " Strength - every build hit makes you stronger (the Training Yard is faster)" end
	return "Locked"
end]], [[contractUnlocked = function(d, c)
	return d.Rep >= c.reqRep and d.Level >= c.reqLevel and (d.Strength or 0) >= (c.reqStrength or 0) and (d.Rebirths or 0) >= (c.reqRebirth or 0)
		and #(d.Workers or {}) >= (c.reqCrew or 0) and (d.ToolTier or 1) >= (c.reqHammer or 1)
end
local function lockReason(d, c)
	if (d.Rebirths or 0) < (c.reqRebirth or 0) then return "Requires Rebirth " .. c.reqRebirth .. " (press the REBIRTH button)" end
	if d.Level < c.reqLevel then return "Requires Level " .. c.reqLevel end
	if d.Rep < c.reqRep then return "Requires " .. c.reqRep .. " Reputation" end
	if (d.Strength or 0) < (c.reqStrength or 0) then return "Requires " .. Config.FormatNum(c.reqStrength) .. " Strength - every build hit makes you stronger (the Training Yard is faster)" end
	if #(d.Workers or {}) < (c.reqCrew or 0) then return "Requires a crew of " .. c.reqCrew .. " (Hiring Office)" end
	if (d.ToolTier or 1) < (c.reqHammer or 1) then return "Requires a " .. Hammers.Rarities[c.reqHammer].name .. " hammer or better (Shop → HAMMERS)" end
	return "Locked"
end]])
m = replaceOnce(m, [[				reqRep = c.reqRep, reqLevel = c.reqLevel, reqStrength = c.reqStrength or 0, reqRebirth = c.reqRebirth or 0, targetTime = c.targetTime, unlocked = contractUnlocked(st.data, c),]],
	[[				reqRep = c.reqRep, reqLevel = c.reqLevel, reqStrength = c.reqStrength or 0, reqRebirth = c.reqRebirth or 0, reqCrew = c.reqCrew or 0, reqHammer = c.reqHammer or 1,
				targetTime = c.targetTime, unlocked = contractUnlocked(st.data, c),]])
-- the zone gates open with a Rebirth
m = replaceOnce(m, [[	plr:SetAttribute("SuburbsUnlocked", d.Rep >= Config.SuburbsRep)]], [[	plr:SetAttribute("SuburbsUnlocked", (d.Rebirths or 0) >= Config.Zones.suburbs.rebirth)]])
m = replaceOnce(m, [[	plr:SetAttribute("DowntownUnlocked", d.Rep >= Config.DowntownRep)]], [[	plr:SetAttribute("DowntownUnlocked", (d.Rebirths or 0) >= Config.Zones.downtown.rebirth)
	-- cash packs are worth minutes of your income at this stage
	local bestC
	for _, ct in ipairs(Config.Contracts) do if contractUnlocked and contractUnlocked(d, ct) then bestC = ct end end
	plr:SetAttribute("IncomePerMin", math.floor(Config.IncomePerMin(bestC or Config.Contracts[1], payMult(st))))]])
-- cash products / gem shop cash: minutes of income
m = replaceOnce(m, [[	elseif product.cash then
		-- cash packs grow with your progress: a multiple of your best contract
		addMoney(plr, bestUnlockedReward(st.data) * product.cash, product.name, true)]], [[	elseif product.minutes or product.cash then
		-- cash packs grow with your progress: minutes of your income at this stage
		local amount = product.minutes and math.floor((plr:GetAttribute("IncomePerMin") or Config.IncomePerMin(nil, payMult(st))) * product.minutes)
			or bestUnlockedReward(st.data) * product.cash
		addMoney(plr, amount, product.name, true)]])
m = replaceOnce(m, [[	elseif it.kind == "cash" then
		addMoney(plr, math.floor(bestUnlockedReward(d) * it.mult), it.name, true)]], [[	elseif it.kind == "cash" then
		local amount = it.minutes and math.floor((plr:GetAttribute("IncomePerMin") or Config.IncomePerMin(nil, payMult(st))) * it.minutes) or math.floor(bestUnlockedReward(d) * (it.mult or 1))
		addMoney(plr, amount, it.name, true)]])

assert(loadstring(m), "Main compile")
Cfg.Source = c
Comp.Source = co
Crew.Source = cr
CS.Source = cs
Reb.Source = rb
Main.Source = m
return "economy v3 in place"
