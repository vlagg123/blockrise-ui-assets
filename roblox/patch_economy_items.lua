-- one-off patch (run in Edit, with Hammers.lua from the same commit): every hammer is a normal, tradeable item
--  * HammerService: the Thunderclap pass gives its hammer ONCE, as a normal item (trade it, keep it: the pass never
--    takes it back nor gives another); the old pass hammers become normal items. Only the starter Rusty can't be traded.
--  (the Lucky Spin's top prize becomes an Exclusive Crate with patch_spin_exclusive.lua, once the crate opens)
--  * (Hammers.lua: no pity, exclusives only from the Exclusive Crate, Hammers of the Day for Gems only)
local function replaceOnce(src, old, new)
	local a, b = src:find(old, 1, true)
	assert(a, "not found: " .. old:sub(1, 80))
	assert(not src:find(old, b + 1, true), "found twice: " .. old:sub(1, 80))
	return src:sub(1, a - 1) .. new .. src:sub(b + 1)
end
local HS = game.ServerScriptService.Game.HammerService
local hs = HS.Source
if hs:find("ITEMS_TRADEABLE", 1, true) then return "already patched" end

hs = replaceOnce(hs, [[-- the Thunderclap pass: its hammer is a bound item while you own the pass (never tradeable, never duplicable)
function M.SyncPass(plr, st)
	local d = st.data
	local has = st.passes and st.passes.stormhammer == true
	local mine
	for _, it in ipairs(d.Hammers) do if it.k == "thunder" and it.pass then mine = it end end
	if has and not mine then
		local it = M.Give(plr, st, "thunder", "pass", { bound = true, pass = true, force = true })
		if it and not d.EquipHammer then d.EquipHammer = it.id end
	elseif not has and mine then
		for i, it in ipairs(d.Hammers) do if it == mine then table.remove(d.Hammers, i) break end end
		if d.EquipHammer == mine.id then d.EquipHammer = nil end
	end
end]], [[-- ITEMS_TRADEABLE: the Thunderclap pass gives its hammer ONCE, as a normal item you can trade (the pass never takes
-- it back nor gives another one: no copies). The pass hammers from before become normal items.
function M.SyncPass(plr, st)
	local d = st.data
	for _, it in ipairs(d.Hammers) do
		if it.pass then it.pass = nil; it.bound = nil; d.ThunderGiven = true end
	end
	local has = st.passes and st.passes.stormhammer == true
	if has and not d.ThunderGiven then
		local it = M.Give(plr, st, "thunder", "pass", { force = true })
		if it then
			d.ThunderGiven = true
			if not d.EquipHammer then d.EquipHammer = it.id end
		end
	end
end]])
hs = replaceOnce(hs, [[	if it.id == "rusty" or it.bound or it.pass then return false, "That hammer can't be traded" end]],
	[[	if it.id == "rusty" then return false, "Everyone's starter Rusty Hammer stays with you" end]])
assert(loadstring(hs), "HammerService compile")

HS.Source = hs
return "economy items patched"
