-- one-off patch (run in Edit): the Inventory window (materials + blueprints, out of Upgrades) in the main Client script
local function replaceOnce(src, old, new)
	local a, b = src:find(old, 1, true)
	assert(a, "not found: " .. old:sub(1, 80))
	assert(not src:find(old, b + 1, true), "found twice: " .. old:sub(1, 80))
	return src:sub(1, a - 1) .. new .. src:sub(b + 1)
end
local Client = game.StarterPlayer.StarterPlayerScripts.Client
local s = Client.Source
if s:find("ctx.showInventory", 1, true) then return "already patched" end
s = replaceOnce(s, [[	ctx.showUpgrades = UpgradesUI.Show
	_G.__CE_ShowUpgrades = UpgradesUI.Show]], [[	ctx.showUpgrades = UpgradesUI.Show
	_G.__CE_ShowUpgrades = UpgradesUI.Show
	ctx.showInventory = UpgradesUI.Inventory
	_G.__CE_ShowInventory = UpgradesUI.Inventory]])
s = replaceOnce(s, [[Upgrades = "upgrades", Rebirth = "rebirth",
		Locations = "locations", Welcome = "star" }]], [[Upgrades = "upgrades", Rebirth = "rebirth",
		Locations = "locations", Welcome = "star", Inventory = "backpack" }]])
s = replaceOnce(s, [[	elseif name == "Upgrades" then _G.__CE_ShowUpgrades()]], [[	elseif name == "Upgrades" then _G.__CE_ShowUpgrades()
	elseif name == "Inventory" then _G.__CE_ShowInventory()]])
assert(loadstring(s), "Client compile")
Client.Source = s
return "inventory patched"
