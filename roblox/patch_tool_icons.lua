-- one-off patch (run in Edit): every hammer in ServerStorage.Hammers gets its picture back in the hotbar
-- (rebuilding the hammers made new Tools without a TextureId: the hotbar showed only the name). The picture is the
-- hammer's own (Hammers h.img); hammer_build.lua now sets it on every rebuild.
-- (the module's current Source: in Edit, require hands back the copy from the first require)
local mod = game.ReplicatedStorage.Shared.Hammers
local f = loadstring(mod.Source)
setfenv(f, setmetatable({ script = mod }, { __index = getfenv() }))
local HM = f()
local done, missing = 0, {}
for _, t in ipairs(game.ServerStorage.Hammers:GetChildren()) do
	if t:IsA("Tool") then
		local h = HM.ById[t:GetAttribute("Key") or ""]
		if h and h.img then
			t.TextureId = h.img
			done += 1
		else
			table.insert(missing, t.Name)
		end
	end
end
return "pictures set on " .. done .. " hammers" .. (#missing > 0 and (" | no picture: " .. table.concat(missing, ", ")) or "")
