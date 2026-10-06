-- one-off patch (run in Edit, when the Exclusive Crate is open: its hammers have their models): the Lucky Spin's top
-- prize is an Exclusive Crate (the Thunderclap is in it, 1 in 100), not the Thunderclap pass any more
local function replaceOnce(src, old, new)
	local a, b = src:find(old, 1, true)
	assert(a, "not found: " .. old:sub(1, 80))
	assert(not src:find(old, b + 1, true), "found twice: " .. old:sub(1, 80))
	return src:sub(1, a - 1) .. new .. src:sub(b + 1)
end
local Main = game.ServerScriptService.Game.Main
local ConfigM = game.ReplicatedStorage.Shared.Config
local main, cfg = Main.Source, ConfigM.Source
if cfg:find('crate = "exclusive", amount = 1', 1, true) then return "already patched" end
main = replaceOnce(main, [[		elseif p.kind == "pass" then
			-- the Thunderclap Hammer: yours for good]], [[		elseif p.kind == "crate" then
			-- a crate in your bag (the Exclusive Crate: the top prize)
			HammerService.AddCrate(plr, st, p.crate, p.amount or 1, "silent")
		elseif p.kind == "pass" then
			-- the Thunderclap Hammer: yours for good]])
assert(loadstring(main), "Main compile")

cfg = replaceOnce(cfg, [[		-- MYTHIC: the Thunderclap Hammer (R$499 pass). Already yours? 1,500 Gems instead.
		{ kind = "pass", pass = "stormhammer", fallbackGems = 1500, weight = 0.1, rarity = "mythic", art = "storm", icon = "⚡", name = "THUNDERCLAP HAMMER", jackpot = true },]],
	[[		-- MYTHIC: an Exclusive Crate (the Thunderclap is in it, 1 in 100)
		{ kind = "crate", crate = "exclusive", amount = 1, weight = 0.1, rarity = "mythic", art = "rbxassetid://117610832518353", icon = "🎁", name = "EXCLUSIVE CRATE", jackpot = true },]])
assert(loadstring(cfg), "Config compile")

Main.Source = main
ConfigM.Source = cfg
return "spin prize: Exclusive Crate"
