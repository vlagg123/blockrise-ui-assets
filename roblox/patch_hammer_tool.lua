-- one-off patch (run in Edit): the builder tool is the hammer of your tier (ServerStorage.Hammers.Hammer_<tier>),
-- always a hammer while building (no shovel / trowel swap). The old part-built tool stays as a fallback.
local function replaceOnce(src, old, new)
	local a, b = src:find(old, 1, true)
	assert(a, "not found: " .. old:sub(1, 80))
	assert(not src:find(old, b + 1, true), "found twice: " .. old:sub(1, 80))
	return src:sub(1, a - 1) .. new .. src:sub(b + 1)
end
local Main = game.ServerScriptService.Game.Main
local s = Main.Source
if s:find("makeToolOld", 1, true) then return "already patched" end
s = replaceOnce(s, "local function makeTool(tier)\n", "local function makeToolOld(tier)\n")
s = replaceOnce(s, "local VERB_MODE = {", [[-- the hammer of your tier, built from hammers/spec.json (ServerStorage.Hammers); same Tool attributes as before
local function makeTool(tier)
	local cfg = Config.Tools[tier] or Config.Tools[1]
	local lib = game:GetService("ServerStorage"):FindFirstChild("Hammers")
	local src = lib and lib:FindFirstChild("Hammer_" .. tier)
	if not src then return makeToolOld(tier) end
	local tool = src:Clone()
	tool.Name = cfg.name
	tool.ToolTip = "Click / tap on a site to build"
	tool.CanBeDropped = false
	tool:SetAttribute("BuilderTool", true)
	tool:SetAttribute("Tier", tier)
	if cfg.icon and cfg.icon ~= "" then tool.TextureId = cfg.icon end
	return tool
end

local VERB_MODE = {]])
-- always the hammer: no tool swap per stage
s = replaceOnce(s, [[	setToolMode(tool, VERB_MODE[verb] or "hammer")]], [[	-- (the builder always swings the hammer: no shovel / trowel swap)]])
assert(loadstring(s), "Main compile")
Main.Source = s
return "hammer tool patched"
