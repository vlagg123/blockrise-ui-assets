-- one-off patch (run in Edit, after patch_hammer_config): back to 15 hammers in the ladder (Galaxy = 15, the last one);
-- the Thunderclap Hammer becomes a Robux add-on (game pass "stormhammer"): your build power x3, forever.
local function replaceOnce(src, old, new)
	local a, b = src:find(old, 1, true)
	assert(a, "not found: " .. old:sub(1, 80))
	assert(not src:find(old, b + 1, true), "found twice: " .. old:sub(1, 80))
	return src:sub(1, a - 1) .. new .. src:sub(b + 1)
end
local Cfg = game.ReplicatedStorage.Shared.Config
local s = Cfg.Source
if s:find("Config.StormHammer", 1, true) then return "already patched" end
s = replaceOnce(s, [[	{ tier = 15, key = "thunder", name = "Thunderclap Hammer", price = 135000000, power = 16384, cooldown = 0.21, color = Color3.fromRGB(80, 170, 255),
	  desc = "x2 build power. Forged inside a storm. Every hit cracks like thunder." },
	{ tier = 16, key = "galaxy", name = "Galaxy Hammer", price = 405000000, power = 32768, cooldown = 0.205, color = Color3.fromRGB(160, 90, 255),
	  desc = "x2 build power. A whole galaxy trapped in crystal. The last hammer." },
}
]], [[	{ tier = 15, key = "galaxy", name = "Galaxy Hammer", price = 135000000, power = 16384, cooldown = 0.21, color = Color3.fromRGB(160, 90, 255),
	  desc = "x2 build power. A whole galaxy trapped in crystal. The last hammer." },
}
-- Robux add-on: the Thunderclap Hammer (game pass "stormhammer") - your build power x3 (you and your crew), forever
Config.StormHammer = { pass = "stormhammer", key = "thunder", name = "Thunderclap Hammer", mult = 3, color = Color3.fromRGB(80, 170, 255) }
]])
-- the pass in the Store (id 0 = not created yet: hidden live, "SOON" in Studio)
s = replaceOnce(s, [[		{ key = "teleporter", id = 0, price = 39,]], [[		{ key = "stormhammer", id = 0, price = 499, icon = "⚡", name = "Thunderclap Hammer", desc = "A storm in a hammer: x3 build power for you and your crew. Yours forever, even after Rebirth." },
		{ key = "teleporter", id = 0, price = 39,]])
assert(loadstring(s), "Config compile")
Cfg.Source = s

-- server: the power multiplier and the tool
local Main = game.ServerScriptService.Game.Main
local m = Main.Source
m = replaceOnce(m, [[	if kind == "strength" and passes.strength2x then m *= 2 end]], [[	if kind == "strength" and passes.strength2x then m *= 2 end
	-- Thunderclap Hammer (Robux add-on): x3 build power, also for the crew (they use your power)
	if kind == "power" and passes[Config.StormHammer.pass] then m *= Config.StormHammer.mult end]])
m = replaceOnce(m, [[	local tool = makeTool(st.data.ToolTier)
	local char = plr.Character]], [[	local tool = makeTool(st.data.ToolTier)
	-- Thunderclap Hammer owners swing it instead (same tool attributes; its power bonus is a multiplier)
	local storm = st.passes and st.passes[Config.StormHammer.pass]
	local lib = game:GetService("ServerStorage"):FindFirstChild("Hammers")
	local sh = storm and lib and lib:FindFirstChild("Hammer_" .. Config.StormHammer.key)
	if sh then
		tool:Destroy()
		tool = sh:Clone()
		tool.Name = Config.StormHammer.name
		tool.ToolTip = "Click / tap on a site to build"
		tool.CanBeDropped = false
		tool:SetAttribute("BuilderTool", true)
		tool:SetAttribute("Tier", st.data.ToolTier)
		tool:SetAttribute("Storm", true)
		if Config.StormHammer.icon then tool.TextureId = Config.StormHammer.icon end
	end
	local char = plr.Character]])
-- buying the pass (or loading it on join) hands the hammer over right away
m = replaceOnce(m, [[	for _, p in ipairs(Config.Store.passes) do plr:SetAttribute("Pass_" .. p.key, st.passes[p.key] == true) end
	sync(plr)
	vipTag(plr)]], [[	for _, p in ipairs(Config.Store.passes) do plr:SetAttribute("Pass_" .. p.key, st.passes[p.key] == true) end
	sync(plr)
	vipTag(plr)
	local storm = st.passes[Config.StormHammer.pass] == true
	if storm ~= (st.stormGiven == true) then
		st.stormGiven = storm
		giveTool(plr)
	end]])
assert(loadstring(m), "Main compile")
Main.Source = m
return "storm hammer add-on patched"
