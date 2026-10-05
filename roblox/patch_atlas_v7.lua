-- one-off patch (run in Edit): icon atlas v7 = v6 + the backpack (Inventory) in the free cell 640,640
local Ic = game.ReplicatedStorage.Shared.Icons
local s = Ic.Source
if s:find("backpack", 1, true) then return "already patched" end
local function replaceOnce(src, old, new)
	local a, b = src:find(old, 1, true)
	assert(a, "not found: " .. old:sub(1, 80))
	assert(not src:find(old, b + 1, true), "found twice: " .. old:sub(1, 80))
	return src:sub(1, a - 1) .. new .. src:sub(b + 1)
end
s = replaceOnce(s, [[Icons.ATLAS = "rbxassetid://83672774709080" -- icons_atlas.png (v6: studio light, CC0 models, upgrade badges, 2026-10-05)]],
	[[Icons.ATLAS = "rbxassetid://89263194293998" -- icons_atlas.png (v7: v6 + backpack for Inventory, 2026-10-05)]])
s = replaceOnce(s, "	vip = Vector2.new(512, 640),\n}", "	vip = Vector2.new(512, 640), backpack = Vector2.new(640, 640),\n}")
s = replaceOnce(s, [[up_strength = "💪", upgrades = "⬆️", vip = "👑",]], [[up_strength = "💪", upgrades = "⬆️", vip = "👑", backpack = "🎒",]])
s = replaceOnce(s, [[stars = "rebirth_star", shopkeeper = "shop", equipment = "shop", crown = "vip" }]],
	[[stars = "rebirth_star", shopkeeper = "shop", equipment = "shop", crown = "vip", inventory = "backpack" }]])
assert(loadstring(s), "Icons compile")
Ic.Source = s
-- the Inventory window header uses it too
local Client = game.StarterPlayer.StarterPlayerScripts.Client
local c = Client.Source
c = c:gsub('Inventory = "portfolio" }', 'Inventory = "backpack" }')
assert(loadstring(c), "Client compile")
Client.Source = c
return "atlas v7"
