-- one-off patch (run in Edit): crate pictures v3 (a hammer bursting out of each chest, soft coloured light)
-- for the crates (Hammers.Crates[].image) and the Robux crate products (Config.ProductImages)
local MAP = {
	["82594037678634"] = "75330431497360",   -- supply
	["93823486590204"] = "104449117497713",  -- builder
	["89693710220545"] = "108198116543312",  -- golden
	["104986103095719"] = "117610832518353", -- exclusive
	["93643298181151"] = "99231744226623",   -- 3 golden
	["139471522232776"] = "89642781937720",  -- 3 exclusive
}
local report = {}
for _, mod in ipairs({ game.ReplicatedStorage.Shared.Hammers, game.ReplicatedStorage.Shared.Config }) do
	local s = mod.Source
	local n = 0
	for old, new in pairs(MAP) do
		local k
		s, k = s:gsub("rbxassetid://" .. old, "rbxassetid://" .. new)
		n += k
	end
	assert(loadstring(s), "compile " .. mod.Name)
	mod.Source = s
	table.insert(report, mod.Name .. " x" .. n)
end
return "crate images v3: " .. table.concat(report, ", ")
