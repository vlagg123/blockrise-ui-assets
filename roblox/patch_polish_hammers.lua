-- one-off patch (run in Edit): Rebirth info tells which building is still needed; the level-up toast says "upgraded"
local function replaceOnce(src, old, new)
	local a, b = src:find(old, 1, true)
	assert(a, "not found: " .. old:sub(1, 80))
	assert(not src:find(old, b + 1, true), "found twice: " .. old:sub(1, 80))
	return src:sub(1, a - 1) .. new .. src:sub(b + 1)
end
local RSv = game.ServerScriptService.Game.RebirthService
local r = RSv.Source
if not r:find("gate = gateInfo", 1, true) then
	r = replaceOnce(r, [[function actions.get(plr, st)
	local d = st.data]], [[-- the zone's top building: it must be built once before this Rebirth
local function gateInfo(d)
	local gate
	for _, ct in ipairs(Config.Contracts) do if (ct.reqRebirth or 0) == (d.Rebirths or 0) then gate = ct end end
	if not gate then return nil end
	return { id = gate.id, name = gate.name, done = ((d.Portfolio or {})[gate.id] or 0) >= 1 }
end

function actions.get(plr, st)
	local d = st.data]])
	r = replaceOnce(r, [[keepCrew = perk(d, "crew") }]], [[keepCrew = perk(d, "crew"), gate = gateInfo(d) }]])
	assert(loadstring(r), "compile RebirthService")
	RSv.Source = r
end
local Client = game.StarterPlayer.StarterPlayerScripts.Client
local s = Client.Source
if not s:find('d.kind == "hammer" or d.kind == "dept"', 1, true) then
	s = replaceOnce(s, [[((d.kind == "dept" or d.kind == "machineup") and " upgraded!"]], [[((d.kind == "hammer" or d.kind == "dept" or d.kind == "machineup") and " upgraded!"]])
	assert(loadstring(s), "compile Client")
	Client.Source = s
end
return "polish patched"
