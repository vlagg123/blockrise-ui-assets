-- one-off patch (run in Edit): the Shop, Store and Job Board windows move to their own modules (ShopUI, StoreUI, JobsUI)
local Client = game.StarterPlayer.StarterPlayerScripts.Client
local s = Client.Source
local function replaceOnce(src, old, new)
	local a, b = src:find(old, 1, true)
	assert(a, "not found: " .. old:sub(1, 80))
	assert(not src:find(old, b + 1, true), "found twice: " .. old:sub(1, 80))
	return src:sub(1, a - 1) .. new .. src:sub(b + 1)
end
s = replaceOnce(s, "local function showContracts()\n", "local function showContracts()\n\tif _G.__CE_JobsUI then return _G.__CE_JobsUI.Show() end\n")
s = replaceOnce(s, "local function showShop(keepScroll)\n", "local function showShop(keepScroll)\n\tif _G.__CE_ShopUI then return _G.__CE_ShopUI.Show(nil, keepScroll) end\n")
s = replaceOnce(s, "local function showHire()\n", "local function showHire()\n\tif _G.__CE_ShopUI then return _G.__CE_ShopUI.Show(\"crew\") end\n")
s = replaceOnce(s, "function showStore(tab)\n", "function showStore(tab)\n\tif _G.__CE_StoreUI then return _G.__CE_StoreUI.Show(tab) end\n")
s = replaceOnce(s, "\t_G.__CE_ShowLocations = LocationsUI.Show\n", [[
	_G.__CE_ShowLocations = LocationsUI.Show
	-- Shop, Store and Job Board: item tiles and light rows (the old functions above hand over to these)
	local ShopUI = require(script:WaitForChild("ShopUI"))
	ShopUI.Init(ctx)
	_G.__CE_ShopUI = ShopUI
	local StoreUI = require(script:WaitForChild("StoreUI"))
	StoreUI.Init(ctx)
	_G.__CE_StoreUI = StoreUI
	local JobsUI = require(script:WaitForChild("JobsUI"))
	JobsUI.Init(ctx)
	_G.__CE_JobsUI = JobsUI
]])
Client.Source = s
return "modules wired, " .. #s .. " chars"
