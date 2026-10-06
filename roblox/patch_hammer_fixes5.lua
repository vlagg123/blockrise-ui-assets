-- one-off patch (run in Edit): hammer changes run the full sync (it publishes the hammers too), so the Empire Road
-- sees them at once: "Your first crate" (tutorial step 4), "Collector", "Legendary hands" no longer wait for some other
-- event; power-related numbers (crew, income per minute) follow an equip / level-up / trade at once too
local HS = game.ServerScriptService.Game.HammerService
local h = HS.Source
if h:find("-- the full sync: the Road sees it", 1, true) then return "already patched" end
local function replaceOnce(src, old, new)
	local a, b = src:find(old, 1, true)
	assert(a, "not found: " .. old:sub(1, 80))
	assert(not src:find(old, b + 1, true), "found twice: " .. old:sub(1, 80))
	return src:sub(1, a - 1) .. new .. src:sub(b + 1)
end
local SYNC = "-- the full sync: the Road sees it\n\tif ctx.sync then ctx.sync(plr) else M.Publish(plr) end"
h = replaceOnce(h, [[	if not ok then return false, res end
	M.Publish(plr)
	ctx.feedback(plr, "Hammer", { kind = "got"]], [[	if not ok then return false, res end
	]] .. SYNC .. [[

	ctx.feedback(plr, "Hammer", { kind = "got"]])
h = replaceOnce(h, [[	ctx.giveTool(plr)
	M.Publish(plr)
	ctx.feedback(plr, "Hammer", { kind = "tradeup"]], [[	ctx.giveTool(plr)
	]] .. SYNC .. [[

	ctx.feedback(plr, "Hammer", { kind = "tradeup"]])
h = replaceOnce(h, [[	if not st then return end
	ctx.giveTool(plr)
	M.Publish(plr)
end]], [[	if not st then return end
	ctx.giveTool(plr)
	]] .. SYNC .. [[

end]])
h = replaceOnce(h, [[	d.EquipHammer = (it == M.Best(d)) and nil or it.id
	ctx.giveTool(plr)
	M.Publish(plr)]], [[	d.EquipHammer = (it == M.Best(d)) and nil or it.id
	ctx.giveTool(plr)
	]] .. SYNC)
h = replaceOnce(h, [[	if M.Equipped(d) == it then ctx.giveTool(plr) end
	M.Publish(plr)
	ctx.saveSoon(plr)]], [[	if M.Equipped(d) == it then ctx.giveTool(plr) end
	]] .. SYNC .. [[

	ctx.saveSoon(plr)]])
assert(loadstring(h), "compile HammerService")
HS.Source = h
return "fixes5: hammer actions sync"
