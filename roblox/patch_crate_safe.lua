-- one-off patch (run in Edit): opening a crate can never lose it (HammerService)
--  * the hammer goes in the bag first, then the crate goes away: one server step, nothing in between can stop it, so a
--    crate is never gone without its hammer (a lost connection, a dead phone, a closed game: the result is saved as one)
--  * the hammer you got is kept as "to show" until your game says you saw it (actions.seen); if the connection dropped
--    while it opened, the reveal comes up again the next time (actions.get -> pending)
local function replaceOnce(src, old, new)
	local a, b = src:find(old, 1, true)
	assert(a, "not found: " .. old:sub(1, 80))
	assert(not src:find(old, b + 1, true), "found twice: " .. old:sub(1, 80))
	return src:sub(1, a - 1) .. new .. src:sub(b + 1)
end
local HS = game.ServerScriptService.Game.HammerService
local s = HS.Source
if s:find("CRATE_SAFE", 1, true) then return "already patched" end
s = replaceOnce(s, [[	d.Crates[crateId] -= 1
	local isNew = not d.Index[key]
	local handBefore = M.Equipped(d).id
	local it = M.Give(plr, st, key, "crate:" .. crateId)
	if not it then return false, "Hammer bag full" end]], [[	-- CRATE_SAFE: the hammer in the bag first, then the crate goes away (one step, nothing in between)
	local isNew = not d.Index[key]
	local handBefore = M.Equipped(d).id
	local it = M.Give(plr, st, key, "crate:" .. crateId, { force = true })
	if not it then return false, "Hammer bag full" end
	d.Crates[crateId] -= 1
	-- shown again next time if you never saw it (the connection dropped while it opened): actions.seen clears it
	d.PendingReveal = { id = it.id, key = key, r = r, crate = crateId, new = isNew, t = os.time() }]])
s = replaceOnce(s, [[	local eq = M.Equipped(d)
	return true, { hammers = list, equip = eq.id, crates = d.Crates,]], [[	local eq = M.Equipped(d)
	-- a crate you opened but never saw (still in the bag, under 3 days old)
	local pending = d.PendingReveal
	if type(pending) ~= "table" or not find(d, pending.id) or os.time() - (tonumber(pending.t) or 0) > 3 * 86400 then pending = nil end
	return true, { pending = pending, hammers = list, equip = eq.id, crates = d.Crates,]])
s = replaceOnce(s, [[function actions.open(plr, st, crateId)]], [[-- your game showed the hammer from the crate: it isn't shown again
function actions.seen(plr, st, id)
	local d = st.data
	if type(d.PendingReveal) == "table" and (id == nil or d.PendingReveal.id == id) then d.PendingReveal = nil end
	return true
end

function actions.open(plr, st, crateId)]])
s = replaceOnce(s, [[		if action ~= "get" and action ~= "odds" then
			if os.clock() - (st.lastHammerAction or 0) < 0.15 then return false, "Slow down!" end]], [[		if action ~= "get" and action ~= "odds" and action ~= "seen" then
			if os.clock() - (st.lastHammerAction or 0) < 0.15 then return false, "Slow down!" end]])
s = replaceOnce(s, [[		if ctx.isTrading and ctx.isTrading(plr) and action ~= "get" and action ~= "odds" then return false, "Finish your trade first" end]],
	[[		if ctx.isTrading and ctx.isTrading(plr) and action ~= "get" and action ~= "odds" and action ~= "seen" then return false, "Finish your trade first" end]])
assert(loadstring(s), "HammerService compile")
HS.Source = s
return "crate safe"
