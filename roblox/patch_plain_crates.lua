-- one-off patch (run in Edit): the crate pictures without sparkles (icons/plain/crates, re-rendered in Blender)
-- for the crates (Hammers.Crates[].image) and the Robux crate products (Config.ProductImages)
local MAP = {
	["75330431497360"] = "81484084637371",   -- supply
	["104449117497713"] = "72301801875933",  -- builder
	["108198116543312"] = "111757044275990", -- golden
	["117610832518353"] = "140362380150130", -- exclusive
	["99231744226623"] = "129859208894290",  -- 3 golden
	["89642781937720"] = "90526418216758",   -- 3 exclusive
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
	if n > 0 then
		assert(loadstring(s), mod.Name .. " compile")
		mod.Source = s
	end
	table.insert(report, mod.Name .. ": " .. n)
end
return table.concat(report, " · ")
