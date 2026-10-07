-- one-off patch (run in Edit): every crate is its own object now (rendered in Blender, no sparkles):
--   Town Supply Crate      a wooden shipping crate (planks, Z brace, rope handles, straw)
--   Suburbs Supply Crate   a green cantilever toolbox with a little house on the front
--   Downtown Supply Crate  a navy armoured cargo pod with cyan lights and a skyline badge
--   Builder's Crate        a blue steel job-site box: hazard band, a blueprint under the lid, a hard hat
--   Golden Crate           a royal treasure chest: gold, red velvet, gems, a crown clasp, coins
--   Exclusive Crate        an arcane crystal reliquary: crystal petals, orbiting rings of light
-- (until Roblox has reviewed them, the older pictures stand in: MenuKit K.FALLBACK)
local function replaceOnce(src, old, new)
	local a, b = src:find(old, 1, true)
	assert(a, "not found: " .. old:sub(1, 80))
	assert(not src:find(old, b + 1, true), "found twice: " .. old:sub(1, 80))
	return src:sub(1, a - 1) .. new .. src:sub(b + 1)
end
local HM = game.ReplicatedStorage.Shared.Hammers
local h = HM.Source
if h:find("71166572993372", 1, true) then return "Hammers: already" end
local NEW = {
	{ 'id = "supply", zone = "town", family = "supply", image = "rbxassetid://81484084637371"', 'id = "supply", zone = "town", family = "supply", image = "rbxassetid://71166572993372"' },
	{ 'id = "supply_suburbs", zone = "suburbs", family = "supply", image = "rbxassetid://81484084637371"', 'id = "supply_suburbs", zone = "suburbs", family = "supply", image = "rbxassetid://100342110009702"' },
	{ 'id = "supply_downtown", zone = "downtown", family = "supply", image = "rbxassetid://81484084637371"', 'id = "supply_downtown", zone = "downtown", family = "supply", image = "rbxassetid://82076340326872"' },
	{ 'id = "builder", image = "rbxassetid://72301801875933"', 'id = "builder", image = "rbxassetid://139943455261862"' },
	{ 'id = "golden", image = "rbxassetid://111757044275990"', 'id = "golden", image = "rbxassetid://139225612607562"' },
	{ 'id = "exclusive", image = "rbxassetid://140362380150130"', 'id = "exclusive", image = "rbxassetid://106463104658382"' },
}
for _, r in ipairs(NEW) do h = replaceOnce(h, r[1], r[2]) end
assert(loadstring(h), "Hammers compile")
HM.Source = h
return "Hammers: 6 new crate pictures"
