-- one-off patch (run in Edit): hammer bugs found in the full test pass
--  1. a better hammer from a crate changed "the hammer in hand" but not the Tool you hold (the check compared the new
--     hammer with itself): the Tool is now rebuilt whenever the hammer in hand changes
--  2. Publish/AddCrate on a profile that wasn't sanitized yet (the Robux ledger restore runs first on join) crashed on a nil
--     Index: both sanitize first
--  3. buying a negative / zero / fractional number of crates is refused (it bought 1)
--  4. debug wipeSim sanitizes the hammers like a real join
local function replaceOnce(src, old, new)
	local a, b = src:find(old, 1, true)
	assert(a, "not found: " .. old:sub(1, 80))
	assert(not src:find(old, b + 1, true), "found twice: " .. old:sub(1, 80))
	return src:sub(1, a - 1) .. new .. src:sub(b + 1)
end
local G = game.ServerScriptService.Game
local HS, Main = G.HammerService, G.Main
local h = HS.Source
if h:find("hand changed: the Tool follows", 1, true) then return "already patched" end

-- 2: sanitize on demand
h = replaceOnce(h, [[local function find(d, id)]], [[local function ready(d)
	if type(d.Hammers) ~= "table" or type(d.Index) ~= "table" or type(d.Crates) ~= "table" or type(d.HammerPity) ~= "table" then M.Sanitize(d) end
end
M.Ready = ready

local function find(d, id)]])
h = replaceOnce(h, [[	local st = ctx.S[plr]
	if not st then return end
	local d = st.data
	local eq = M.Equipped(d)]], [[	local st = ctx.S[plr]
	if not st or not st.data then return end
	local d = st.data
	ready(d)
	local eq = M.Equipped(d)]])
h = replaceOnce(h, [[	if not c then return false end
	local d = st.data
	d.Crates[crateId] = (d.Crates[crateId] or 0) + int(n)]], [[	if not c then return false end
	local d = st.data
	ready(d)
	d.Crates[crateId] = (d.Crates[crateId] or 0) + int(n)]])

-- 1: the Tool follows the hand
h = replaceOnce(h, [[	d.Crates[crateId] -= 1
	local isNew = not d.Index[key]
	local it = M.Give(plr, st, key, "crate:" .. crateId)
	if not it then return false, "Hammer bag full" end
	-- a better hammer than the one in hand goes straight into it (you never miss the upgrade)
	local eq = M.Equipped(d)
	if better(it, eq) and not d.EquipHammer then ctx.giveTool(plr) end]], [[	d.Crates[crateId] -= 1
	local isNew = not d.Index[key]
	local handBefore = M.Equipped(d).id
	local it = M.Give(plr, st, key, "crate:" .. crateId)
	if not it then return false, "Hammer bag full" end
	-- a better hammer than the one in hand goes straight into it (you never miss the upgrade):
	-- hand changed: the Tool follows
	if M.Equipped(d).id ~= handBefore then ctx.giveTool(plr) end]])

-- 3: whole numbers 1..10 only
h = replaceOnce(h, [[	n = math.clamp(math.floor(tonumber(n) or 1), 1, 10)]], [[	n = tonumber(n) or 1
	if n ~= n or n < 1 or n > 10 or n % 1 ~= 0 then return false, "Pick 1 to 10 crates" end]])
assert(loadstring(h), "compile HammerService")
HS.Source = h

-- 4: debug wipe
local m = Main.Source
if not m:find("restorePaid(plr, st)\n\t\t\tHammerService.Sanitize(st.data)", 1, true) then
	m = replaceOnce(m, [[			for k, v in pairs(fresh) do st.data[k] = v end
			restorePaid(plr, st)]], [[			for k, v in pairs(fresh) do st.data[k] = v end
			restorePaid(plr, st)
			HammerService.Sanitize(st.data)
			giveTool(plr)]])
	assert(loadstring(m), "compile Main")
	Main.Source = m
end
return "hammer fixes 3 applied"
