-- FIX3 patch (run in Edit, 2026-10-14): the luck rows fit; a pity floor never raises the Exclusive; FOUND twice can't charge twice
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

-- 1) HammersUI: the box is a little wider when it shows the luck rows (the Secret Hunter's line fits on one line)
job(Cl.HammersUI, function(out)
	if out:find("LUCK_ROWS_FIT", 1, true) then error("already patched") end
	out = rep(out, [=[		local RH, PAD, W = 22, 9, 272 -- (ODDS_SIMPLE 2026-10-14, the owner: the rarity and its "1 in X", nothing else)
]=], [=[		local RH, PAD, W = 22, 9, 272 -- (ODDS_SIMPLE 2026-10-14, the owner: the rarity and its "1 in X", nothing else)
		if #lrows > 0 then W = 300 end -- (LUCK_ROWS_FIT: the luck rows' words on one line)
]=])
	out = rep(out, [=[K.text({ Name = "LuckL", Position = UDim2.fromOffset(12, y), Size = UDim2.new(1, -110, 0, LH),]=],
		[=[K.text({ Name = "LuckL", Position = UDim2.fromOffset(12, y), Size = UDim2.new(1, -100, 0, LH),]=])
	out = rep(out, [=[left = "🔍 Secret Hunter: Secret & Divine x2"]=], [=[left = "🔍 Hunter: Secret & Divine x2"]=])
	return out
end)

-- 2) Hammers: under a pity floor (the first crate: Uncommon or better) the Exclusive keeps its own chance
job(game.ReplicatedStorage.Shared.Hammers, function(out)
	out = rep(out, [=[function Hammers.Roll(crateId, zone, rng, luck, pityMin)
	local c = Hammers.CrateById[crateId]
	local odds = Hammers.Odds(crateId, zone, luck)
]=], [=[function Hammers.Roll(crateId, zone, rng, luck, pityMin)
	local c = Hammers.CrateById[crateId]
	local odds = Hammers.Odds(crateId, zone, luck)
	-- PITY_EXCL (2026-10-14): a pity floor never raises the Exclusive: it is rolled first with its own fixed chance, the
	-- floor shares out the rest
	local ex = Hammers.ExclusiveR
	if pityMin and pityMin < ex and (odds[ex] or 0) > 0 then
		if rng:NextNumber() * 100 < odds[ex] then
			local pool = Hammers.PoolAt(c, ex)
			if #pool > 0 then return pickIn(pool, rng).key, ex end
		end
		local rest = {}
		for r, v in pairs(odds) do if r ~= ex then rest[r] = v end end
		odds = rest
	end
]=])
	return out
end)

-- 3) CompanyService: the name check waits on Roblox; a second tap meanwhile can't found (and pay) twice
job(game.ServerScriptService.Game.CompanyService, function(out)
	out = rep(out, [=[	if filtered ~= name or filtered:find("#") then return false, "That name isn't allowed, try another one" end
]=], [=[	if filtered ~= name or filtered:find("#") then return false, "That name isn't allowed, try another one" end
	-- (FOUND_ONCE 2026-10-14: checked again after the wait)
	if d.Company.founded then return false, "You already run a company" end
	if d.Money < Company.FoundCost or (d.Items.mats.steel or 0) < Company.FoundSteel then return false, "Not enough cash or Steel Beams any more" end
]=])
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
