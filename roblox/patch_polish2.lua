-- one-off patch (run in Edit): polish round 2
--  * every new player starts with a welcome Supply Crate (the first hammer is a gift, not a purchase)
--  * Road step 4 opens the Inventory (CRATES tab) instead of the Shop; the tutorial hint says so
--  * the hammer list the client gets carries when and where each hammer came from (NEW markers)
local function replaceOnce(src, old, new)
	local a, b = src:find(old, 1, true)
	assert(a, "not found: " .. old:sub(1, 80))
	assert(not src:find(old, b + 1, true), "found twice: " .. old:sub(1, 80))
	return src:sub(1, a - 1) .. new .. src:sub(b + 1)
end
local G = game.ServerScriptService.Game
local Main, HS = G.Main, G.HammerService
local C = game.ReplicatedStorage.Shared.Config
local Client = game.StarterPlayer.StarterPlayerScripts.Client
local report = {}

local m = Main.Source
if not m:find("Crates = { supply = 1 }", 1, true) then
	m = replaceOnce(m, [[		Hammers = {}, Crates = {}, HammerV = 1 }]], [[		Hammers = {}, Crates = { supply = 1 }, HammerV = 1 }]])
	assert(loadstring(m), "compile Main")
	Main.Source = m
	table.insert(report, "welcome crate")
end

local h = HS.Source
if not h:find("t = it.t, s = it.s", 1, true) then
	h = replaceOnce(h, [[		table.insert(list, { id = it.id, k = it.k, lv = it.lv or 1, bound = it.bound == true, pass = it.pass == true, s = it.s })]],
		[[		table.insert(list, { id = it.id, k = it.k, lv = it.lv or 1, bound = it.bound == true, pass = it.pass == true, t = it.t, s = it.s })]])
	assert(loadstring(h), "compile HammerService")
	HS.Source = h
	table.insert(report, "item times")
end

local cs = C.Source
if not cs:find('place = "inventory"', 1, true) then
	cs = replaceOnce(cs, [[R[4] = { title = "Your first crate", desc = "Open the Shop (CRATES tab) and open a Supply Crate: every crate holds a new hammer. Better hammers hit harder.", stat = "Hammers", target = 2, place = "shop", cash = 100, gems = 5 }]],
		[[R[4] = { title = "Your first crate", desc = "You got a welcome SUPPLY CRATE! Open it: INVENTORY → CRATES. Every crate holds a hammer, and better hammers hit harder.", stat = "Hammers", target = 2, place = "inventory", cash = 100, gems = 5 }]])
	assert(loadstring(cs), "compile Config")
	C.Source = cs
	table.insert(report, "road 4")
end

local s = Client.Source
if s:find("Open the SHOP (CRATES tab) and open your first hammer crate", 1, true) then
	s = replaceOnce(s, [[		h = tp == "shop" and "🔨 Open the SHOP (CRATES tab) and open your first hammer crate"]],
		[[		h = tp == "inventory" and "📦 Open your INVENTORY (CRATES tab) and open your welcome crate: a new hammer is inside!"]])
	s = replaceOnce(s, [[		h = "📦 You have a hammer crate! Open it: INVENTORY → HAMMERS"]], [[		h = "📦 You have a hammer crate! Open it: INVENTORY → CRATES"]])
	assert(loadstring(s), "compile Client")
	Client.Source = s
	table.insert(report, "hints")
end
return "polish2: " .. table.concat(report, ", ")
