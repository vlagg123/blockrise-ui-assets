-- one-off patch (run in Edit): the countries where Roblox doesn't allow paid random items (PolicyService
-- ArePaidRandomItemsRestricted; Main sets it on the player as the attribute PaidRandomRestricted)
--  * no crate is sold there for cash, Gems or Robux (cash and Gems can be bought with Robux, so they count too);
--    the server says no, whatever the client asks
--  * those builders still get their crates, free, twice as often while they build: a Supply Crate every 3
--    contracts (6 elsewhere), a Builder's Crate on 6% of contracts (3%), and a rare Golden Crate (0.5%)
--  * the tutorial's Supply Crate is a gift there (its first step still works)
--  * the Hammers of the Day (the hammer you pick, no luck) stay open to them; trade-ups too
local function replaceOnce(src, old, new)
	local a, b = src:find(old, 1, true)
	assert(a, "not found: " .. old:sub(1, 80))
	assert(not src:find(old, b + 1, true), "found twice: " .. old:sub(1, 80))
	return src:sub(1, a - 1) .. new .. src:sub(b + 1)
end
local HS = game.ServerScriptService.Game.HammerService
local s = HS.Source
if s:find("PAID_RANDOM_POLICY", 1, true) then return "HammerService: already" end

s = replaceOnce(s, [=[-- free crates: every 6th finished contract drops a Supply Crate, and 3% of contracts a Builder's Crate
function M.OnContract(plr, st)
	local d = st.data
	d.CrateProgress = (d.CrateProgress or 0) + 1
	if d.CrateProgress >= 6 then
		d.CrateProgress = 0
		M.AddCrate(plr, st, Hammers.SupplyFor(ctx.zoneOf(d)), 1, "drop")
	elseif rng:NextNumber() < 0.03 * (ctx.luck and ctx.luck(st) or 1) then
		M.AddCrate(plr, st, "builder", 1, "drop")
	end]=], [=[-- PAID_RANDOM_POLICY: where Roblox doesn't allow paid random items (PolicyService ArePaidRandomItemsRestricted, the
-- player attribute PaidRandomRestricted set by Main) no crate is sold, for cash, Gems or Robux; those builders get
-- theirs free while they build, twice as often, and the tutorial's Supply Crate is a gift
local function noPaidRandom(plr) return plr:GetAttribute("PaidRandomRestricted") == true end
M.NoPaidRandom = noPaidRandom
-- contracts per free Supply Crate
function M.CrateEvery(plr) return noPaidRandom(plr) and 3 or 6 end

-- free crates: every 6th finished contract drops a Supply Crate, and 3% of contracts a Builder's Crate
-- (no paid crates in your country: every 3rd, 6%, and 0.5% a Golden Crate)
function M.OnContract(plr, st)
	local d = st.data
	local free = noPaidRandom(plr)
	local luck = ctx.luck and ctx.luck(st) or 1
	d.CrateProgress = (d.CrateProgress or 0) + 1
	if d.CrateProgress >= M.CrateEvery(plr) then
		d.CrateProgress = 0
		M.AddCrate(plr, st, Hammers.SupplyFor(ctx.zoneOf(d)), 1, "drop")
	elseif rng:NextNumber() < (free and 0.06 or 0.03) * luck then
		M.AddCrate(plr, st, "builder", 1, "drop")
	elseif free and rng:NextNumber() < 0.005 * luck then
		M.AddCrate(plr, st, "golden", 1, "drop")
	end]=])

s = replaceOnce(s, [=[luck = ctx.luck and ctx.luck(st) or 1, progress = d.CrateProgress or 0 }]=],
	[=[luck = ctx.luck and ctx.luck(st) or 1, progress = d.CrateProgress or 0,
		every = M.CrateEvery(plr), noPaid = noPaidRandom(plr) }]=])

s = replaceOnce(s, [=[	if c.family == "supply" and c.id ~= Hammers.SupplyFor(ctx.zoneOf(d)) then return false, "The Shop sells the Supply Crate of the zone you build in" end
	if c.cash then]=], [=[	if c.family == "supply" and c.id ~= Hammers.SupplyFor(ctx.zoneOf(d)) then return false, "The Shop sells the Supply Crate of the zone you build in" end
	if noPaidRandom(plr) then
		-- the tutorial's Supply Crate (the check above let only that one through): a gift
		if Config.InTutorial and Config.InTutorial(d) then
			d.Crates[crateId] = (d.Crates[crateId] or 0) + 1
			M.Publish(plr)
			ctx.saveSoon(plr)
			return true, { crates = d.Crates[crateId], free = true }
		end
		return false, "Crates can't be bought in your country: you get them free while you build"
	end
	if c.cash then]=])

local f, err = loadstring(s)
assert(f, "HammerService compile: " .. tostring(err))
HS.Source = s
return "HammerService: no paid crates where they aren't allowed, free ones twice as often"
