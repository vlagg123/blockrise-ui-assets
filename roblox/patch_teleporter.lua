-- one-off Studio patch: Teleporter game pass (39 R$), first thing in the Store until you own it
local cfg = game.ReplicatedStorage.Shared.Config
local s = cfg.Source
local a, b = s:find("Config.Store = {\n\tpasses = {\n", 1, true)
assert(a, "passes")
if not s:find('key = "teleporter"', 1, true) then
	s = s:sub(1, b) .. '\t\t{ key = "teleporter", id = 0, price = 39, icon = "📍", name = "Teleporter", desc = "Travel to any place in one tap with GO in Places, forever." },\n' .. s:sub(b + 1)
	cfg.Source = s
end
local fn1, e1 = loadstring(s)

local cl = game.StarterPlayer.StarterPlayerScripts.Client
local c = cl.Source
local a2, b2 = c:find("\t-- the one-time starter pack sits on top of the Robux tabs until it's bought\n", 1, true)
assert(a2, "store body")
c = c:sub(1, a2 - 1) .. [[
	-- the Teleporter is the first thing in the Store until you own it
	do
		local tpPass
		for _, p in ipairs(Config.Store.passes) do if p.key == "teleporter" then tpPass = p end end
		if tpPass and visible(tpPass) and not player:GetAttribute("Pass_teleporter") and storeTab ~= "passes" then
			section("📍 TELEPORTER  <font color='#c9c3ee' size='14'>travel anywhere in one tap</font>", Color3.fromRGB(255, 200, 80))
			local f = itemCard(tpPass.icon, tpPass.name, tpPass.desc, Color3.fromRGB(235, 70, 130), 96)
			UI.stroke(0.1, Color3.fromRGB(255, 200, 80), 3).Parent = f
			robuxButton(f, tpPass, true)
		end
	end
]] .. c:sub(a2)
cl.Source = c
local fn2, e2 = loadstring(c)
return "config " .. (fn1 and "OK" or tostring(e1)) .. ", client " .. (fn2 and "OK" or tostring(e2))
