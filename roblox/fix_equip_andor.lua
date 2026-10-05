-- one-off fix (run in Edit, after patch_equip): "x and nil or t" is always t in Lua; spell it out
local Main = game.ServerScriptService.Game.Main
local s = Main.Source
local old = "		st.data.EquipTool = (t == st.data.ToolTier and not storm) and nil or t"
local a, b = s:find(old, 1, true)
if not a then return "already fixed" end
s = s:sub(1, a - 1) .. "		if t == st.data.ToolTier and not storm then st.data.EquipTool = nil else st.data.EquipTool = t end" .. s:sub(b + 1)
assert(loadstring(s), "Main compile")
Main.Source = s
return "fixed"
