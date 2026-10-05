-- one-off patch (run in Edit): Daily Missions, Portfolio and My Property move to MoreUI (menu kit)
local Client = game.StarterPlayer.StarterPlayerScripts.Client
local s = Client.Source
local function replaceOnce(src, old, new)
	local a, b = src:find(old, 1, true)
	assert(a, "not found: " .. old:sub(1, 80))
	assert(not src:find(old, b + 1, true), "found twice: " .. old:sub(1, 80))
	return src:sub(1, a - 1) .. new .. src:sub(b + 1)
end
s = replaceOnce(s, "local function showMissions()\n", "local function showMissions()\n\tif _G.__CE_MoreUI then return _G.__CE_MoreUI.Missions() end\n")
s = replaceOnce(s, "local function showPortfolio()\n", "local function showPortfolio()\n\tif _G.__CE_MoreUI then return _G.__CE_MoreUI.Portfolio() end\n")
s = replaceOnce(s, "local function showProperty()\n", "local function showProperty()\n\tif _G.__CE_MoreUI then return _G.__CE_MoreUI.Property() end\n")
s = replaceOnce(s, "\t_G.__CE_JobsUI = JobsUI\n", [[
	_G.__CE_JobsUI = JobsUI
	local MoreUI = require(script:WaitForChild("MoreUI"))
	MoreUI.Init(ctx)
	_G.__CE_MoreUI = MoreUI
]])
Client.Source = s
return "more wired"
