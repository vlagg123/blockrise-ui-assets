-- one-off patch (run in Edit): the icons without their sparkles (2026-10-07)
--   * Icons: every key below draws its plain picture (icons/plain/*.png, re-rendered in Blender) instead of the atlas cell,
--     everywhere: the HUD buttons, the window headers, the tabs, the banners, the MORE menu, money / Gems on the HUD...
--   * Company / Config: the materials and blueprints get their plain pictures too (icons/plain/items/*.png)
local function replaceOnce(src, old, new)
	local a, b = src:find(old, 1, true)
	assert(a, "not found: " .. old:sub(1, 80))
	assert(not src:find(old, b + 1, true), "found twice: " .. old:sub(1, 80))
	return src:sub(1, a - 1) .. new .. src:sub(b + 1)
end
local report = {}

local Ic = game.ReplicatedStorage.Shared.Icons
local s = Ic.Source
if not s:find("Icons.plain", 1, true) then
	s = replaceOnce(s, "function Icons.has(key)\n\tkey = Icons.alias[key] or key\n\treturn Icons.ATLAS ~= \"\" and Icons.cells[key] ~= nil\nend", [[
-- the same icons without their sparkles (icons/plain, 256 px, re-rendered in Blender): they replace the atlas cell everywhere
Icons.plain = {
	cash = "rbxassetid://93755200441153", codes = "rbxassetid://127903845401837", coins = "rbxassetid://132364406267374",
	gem = "rbxassetid://137229300263435", gift = "rbxassetid://99160095694361", level = "rbxassetid://105769696104354",
	portfolio = "rbxassetid://128249037871446", rebirth = "rbxassetid://107817325591050", rebirth_star = "rbxassetid://103598332763343",
	spin = "rbxassetid://104888703472044", star = "rbxassetid://105769696104354", store = "rbxassetid://114796072763541",
	up_cash = "rbxassetid://100476655379884", up_luck = "rbxassetid://83182543656000", upgrades = "rbxassetid://98958018651853",
	vip = "rbxassetid://120072501383052",
}

function Icons.has(key)
	key = Icons.alias[key] or key
	return Icons.plain[key] ~= nil or (Icons.ATLAS ~= "" and Icons.cells[key] ~= nil)
end]])
	s = replaceOnce(s, [[	if img:IsA("ImageLabel") or img:IsA("ImageButton") then
		img.Image = Icons.ATLAS
		img.ImageRectOffset = Icons.cells[key] or Vector2.zero
		img.ImageRectSize = Icons.CELL]], [[	local plain = Icons.plain[key]
	if img:IsA("ImageLabel") or img:IsA("ImageButton") then
		img.Image = plain or Icons.ATLAS
		img.ImageRectOffset = plain and Vector2.zero or (Icons.cells[key] or Vector2.zero)
		img.ImageRectSize = plain and Vector2.zero or Icons.CELL]])
	s = replaceOnce(s, [[	key = Icons.alias[key] or key
	local o
	if Icons.has(key) then]], [[	key = Icons.alias[key] or key
	if Icons.plain[key] then return Icons.make(Icons.plain[key], props) end
	local o
	if Icons.has(key) then]])
	assert(loadstring(s), "Icons compile")
	Ic.Source = s
	table.insert(report, "Icons: plain")
end

-- materials + blueprints: old picture -> plain picture
local MAP = {
	["106021046585318"] = "122360343832470", -- steel
	["121445839778900"] = "110081082708537", -- copper
	["109991355122402"] = "78454191560706",  -- marble
	["80452030386747"] = "76050270159803",   -- gold
	["90451387449619"] = "138579171777134",  -- diamond
	["98054109382956"] = "116068134549253",  -- bp_silver
	["133224112942902"] = "77419840394146",  -- bp_gold
	["82078762588832"] = "125092282489198",  -- bp_diamond
}
for _, mod in ipairs({ game.ReplicatedStorage.Shared.Company, game.ReplicatedStorage.Shared.Config }) do
	local src = mod.Source
	local n = 0
	for old, new in pairs(MAP) do
		local k
		src, k = src:gsub("rbxassetid://" .. old, "rbxassetid://" .. new)
		n += k
	end
	if n > 0 then
		assert(loadstring(src), mod.Name .. " compile")
		mod.Source = src
	end
	table.insert(report, mod.Name .. ": " .. n)
end
return table.concat(report, " · ")
