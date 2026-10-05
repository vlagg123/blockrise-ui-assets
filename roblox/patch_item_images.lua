-- one-off patch (run in Edit): the materials and blueprints get their pictures (rendered in Blender, icons/items.py).
-- `image` sits next to the old emoji `icon`; every window uses `image or icon`.
-- The Lucky Spin prizes that are materials / blueprints show the same pictures.
local function replaceOnce(src, old, new)
	local a, b = src:find(old, 1, true)
	assert(a, "not found: " .. old:sub(1, 80))
	assert(not src:find(old, b + 1, true), "found twice: " .. old:sub(1, 80))
	return src:sub(1, a - 1) .. new .. src:sub(b + 1)
end
local IMG = {
	steel = "rbxassetid://106021046585318", copper = "rbxassetid://121445839778900", marble = "rbxassetid://109991355122402",
	gold = "rbxassetid://80452030386747", diamond = "rbxassetid://90451387449619",
	bp_bronze = "rbxassetid://81717966414458", bp_silver = "rbxassetid://98054109382956", bp_gold = "rbxassetid://133224112942902",
	bp_diamond = "rbxassetid://82078762588832",
}
local Co = game.ReplicatedStorage.Shared.Company
local s = Co.Source
if not s:find("image = ", 1, true) then
	s = replaceOnce(s, [[name = "Steel Beams", icon = "🔩",]], [[name = "Steel Beams", icon = "🔩", image = "]] .. IMG.steel .. [[",]])
	s = replaceOnce(s, [[name = "Copper Wire", icon = "🧶",]], [[name = "Copper Wire", icon = "🧶", image = "]] .. IMG.copper .. [[",]])
	s = replaceOnce(s, [[name = "Marble", icon = "🏛️",]], [[name = "Marble", icon = "🏛️", image = "]] .. IMG.marble .. [[",]])
	s = replaceOnce(s, [[name = "Gold Leaf", icon = "🟨",]], [[name = "Gold Leaf", icon = "🟨", image = "]] .. IMG.gold .. [[",]])
	s = replaceOnce(s, [[name = "Diamond Glass", icon = "💠",]], [[name = "Diamond Glass", icon = "💠", image = "]] .. IMG.diamond .. [[",]])
	for _, t in ipairs({ "Bronze", "Silver", "Gold", "Diamond" }) do
		s = replaceOnce(s, [[name = "]] .. t .. [[ Blueprint", icon = "📜",]], [[name = "]] .. t .. [[ Blueprint", icon = "📜", image = "]] .. IMG["bp_" .. t:lower()] .. [[",]])
	end
	assert(loadstring(s), "Company compile")
	Co.Source = s
end
local Cfg = game.ReplicatedStorage.Shared.Config
local c = Cfg.Source
if not c:find(IMG.steel, 1, true) then
	c = replaceOnce(c, [[art = "backpack", icon = "🔩", name = "10 Steel Beams"]], [[art = "]] .. IMG.steel .. [[", icon = "🔩", name = "10 Steel Beams"]])
	c = replaceOnce(c, [[art = "portfolio", icon = "📜", name = "Gold Blueprint"]], [[art = "]] .. IMG.bp_gold .. [[", icon = "📜", name = "Gold Blueprint"]])
	c = replaceOnce(c, [[art = "portfolio", icon = "📜", name = "Diamond Blueprint"]], [[art = "]] .. IMG.bp_diamond .. [[", icon = "📜", name = "Diamond Blueprint"]])
	assert(loadstring(c), "Config compile")
	Cfg.Source = c
end
return "item images patched"
