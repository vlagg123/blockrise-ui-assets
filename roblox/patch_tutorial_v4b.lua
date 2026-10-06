-- one-off patch (run in Edit, after patch_tutorial_v4): the first step is "open a crate from the Hammers Shop" for
-- everyone. Counting different hammers let a Thunderclap owner (2 hammers from the start) skip the shop, and the
-- tutorial's hammer only goes into your hand when it's better than the one you hold (a Thunderclap stays in hand).
local function replaceOnce(src, old, new, what)
	local a, b = src:find(old, 1, true)
	assert(a, "not found: " .. (what or old:sub(1, 80)))
	assert(not src:find(old, b + 1, true), "found twice: " .. (what or old:sub(1, 80)))
	return src:sub(1, a - 1) .. new .. src:sub(b + 1)
end
local RS = game:GetService("ReplicatedStorage")
local SSS = game:GetService("ServerScriptService")
local ConfigM = RS.Shared.Config
local Main = SSS.Game.Main
local HS = SSS.Game.HammerService
if ConfigM.Source:find("FirstCrate", 1, true) then return "already patched" end

local cfg = replaceOnce(ConfigM.Source, [==[stat = "Hammers", target = 2, place = "shop", buy = "crate",]==], [==[stat = "FirstCrate", target = 1, place = "shop", buy = "crate",]==])
assert(loadstring(cfg), "compile Config")

local m = replaceOnce(Main.Source, [==[	elseif stat == "VisitedHome" then return s.home or 0]==], [==[	elseif stat == "FirstCrate" then return d.FirstCrateDone and 1 or 0
	elseif stat == "VisitedHome" then return s.home or 0]==])
assert(loadstring(m), "compile Main")

local hs = HS.Source
hs = replaceOnce(hs, [==[	if Config.InTutorial and Config.InTutorial(d) then
		local owned = 0
		for k in pairs(d.Index or {}) do if Hammers.ById[k] then owned += 1 end end
		if crateId ~= "supply" or n ~= 1 or owned >= 2 or (d.Crates.supply or 0) > 0 then return false, "🔒 More crates after the tutorial" end
	end]==], [==[	if Config.InTutorial and Config.InTutorial(d) then
		-- the tutorial: the one Supply Crate of its first step
		if crateId ~= "supply" or n ~= 1 or (tonumber(d.Road) or 1) ~= 1 or (d.Crates.supply or 0) > 0 then return false, "🔒 More crates after the tutorial" end
	end]==])
hs = replaceOnce(hs, [==[	if Config.InTutorial and Config.InTutorial(d) then d.EquipHammer = (it == M.Best(d)) and nil or it.id end]==],
	[==[	if Config.InTutorial and Config.InTutorial(d) and better(it, M.Equipped(d)) then d.EquipHammer = (it == M.Best(d)) and nil or it.id end]==])
assert(loadstring(hs), "compile HammerService")

ConfigM.Source = cfg
Main.Source = m
HS.Source = hs
return "tutorial v4b"
