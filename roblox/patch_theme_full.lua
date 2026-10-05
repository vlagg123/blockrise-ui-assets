-- one-off patch (run in Edit): Gold / Diamond Blueprint buildings are gold / glass all over.
-- Before, the gable triangles under the roof (they "rise" like floors do) and concrete walls / roofs kept their
-- normal look (a brick triangle on a glass house). Floors, slabs, porches and driveways still stay as they are.
local function replaceOnce(src, old, new)
	local a, b = src:find(old, 1, true)
	assert(a, "not found: " .. old:sub(1, 80))
	assert(not src:find(old, b + 1, true), "found twice: " .. old:sub(1, 80))
	return src:sub(1, a - 1) .. new .. src:sub(b + 1)
end
local Con = game.ServerScriptService.Game.Construction
local s = Con.Source
if s:find("THEME_FULL", 1, true) then return "already patched" end
s = replaceOnce(s, [[	if theme and not spec.concrete and spec.anim ~= "rise" then
		local m = spec.m
		if m == Enum.Material.Brick or m == Enum.Material.Plaster or m == Enum.Material.Metal or m == Enum.Material.WoodPlanks
			or m == Enum.Material.RoofShingles or m == Enum.Material.Wood or m == Enum.Material.SmoothPlastic then]],
[[	-- THEME_FULL: the gable triangles (wedges that rise) and concrete walls / roofs too; floors and slabs stay
	if theme and not spec.concrete and (spec.anim ~= "rise" or spec.shape == "Wedge") then
		local m = spec.m
		if m == Enum.Material.Brick or m == Enum.Material.Plaster or m == Enum.Material.Metal or m == Enum.Material.WoodPlanks
			or m == Enum.Material.RoofShingles or m == Enum.Material.Wood or m == Enum.Material.SmoothPlastic
			or (m == Enum.Material.Concrete and spec.anim ~= "rise") then]])
assert(loadstring(s), "Construction compile")
Con.Source = s
return "themes cover the whole building"
