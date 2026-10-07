-- one-off patch (run in Edit): the custom materials the hammers use (hammer_build.lua picks them from the palette), made
-- after the Blender renders. Maps: tileable 512 px PNGs generated in Blender (~/.local/share/blockrise_icons/matvar).
local MS = game:GetService("MaterialService")
local T = {
	white = "rbxassetid://108010032630328", flat = "rbxassetid://118773577510699", g15 = "rbxassetid://96287509894672", g22 = "rbxassetid://121075523600629",
	brn = "rbxassetid://122421344295385", brr = "rbxassetid://74839252432875", ham = "rbxassetid://114171987618677",
	woc = "rbxassetid://136211530374184", won = "rbxassetid://109256064692621", wor = "rbxassetid://127991722041910",
	wrc = "rbxassetid://94503505306198", wrn = "rbxassetid://75296480941789", wrr = "rbxassetid://83725066170564",
}
-- name, base material, colour, normal, roughness, metalness, studs per tile
local defs = {
	{ "BR_Hammered", Enum.Material.Metal, T.white, T.ham, T.g22, T.white, 2 },
	{ "BR_Brushed", Enum.Material.Metal, T.white, T.brn, T.brr, T.white, 2 },
	{ "BR_Polished", Enum.Material.Metal, T.white, T.flat, T.g15, T.white, 4 },
	{ "BR_Wood", Enum.Material.Wood, T.woc, T.won, T.wor, nil, 1.5 },
	{ "BR_Wrap", Enum.Material.Fabric, T.wrc, T.wrn, T.wrr, nil, 0.8 },
	{ "BR_Gloss", Enum.Material.SmoothPlastic, T.white, T.flat, T.g22, nil, 4 },
}
for _, d in ipairs(defs) do
	local mv = MS:FindFirstChild(d[1]) or Instance.new("MaterialVariant")
	mv.Name, mv.BaseMaterial = d[1], d[2]
	mv.ColorMap, mv.NormalMap, mv.RoughnessMap, mv.MetalnessMap = d[3], d[4], d[5], d[6] or ""
	mv.StudsPerTile = d[7]
	mv.Parent = MS
end
return "MaterialService: " .. #defs .. " materials"
