-- one-off patch (run in Edit): the tutorial's glowing ring around GO at My Property (PLACES) sat lower and wider than the
-- button. It took the window's scale from the button's height as if the button were 50 px tall; the tile buttons are 47 px
-- now, so every distance came out ~6% too big. The scale is now measured on a 100 px reference frame inside the tile, so the
-- ring hugs the button whatever its size or the screen's scale.
local function replaceOnce(src, old, new, what)
	local a, b = src:find(old, 1, true)
	assert(a, "not found: " .. (what or old:sub(1, 80)))
	assert(not src:find(old, b + 1, true), "found twice: " .. (what or old:sub(1, 80)))
	return src:sub(1, a - 1) .. new .. src:sub(b + 1)
end
local function findModule(name)
	for _, d in ipairs(game:GetDescendants()) do
		if d:IsA("ModuleScript") and d.Name == name and d.Source:find("TutRing", 1, true) then return d end
	end
end
local L = findModule("LocationsUI")
assert(L, "LocationsUI with TutRing not found")
local s = L.Source
if s:find("TutScale", 1, true) then return "already patched" end
s = replaceOnce(s, [==[				task.spawn(function()
					local t0 = os.clock()
					while ring.Parent and go.Parent do
						local k = math.abs(math.sin((os.clock() - t0) * 4))
						-- the window is scaled: AbsoluteSize / the button's own 50 px height = the scale
						local sc = math.max(go.AbsoluteSize.Y / 50, 0.01)]==], [==[				-- the window is scaled (UIScale): a 100 px frame in the tile measures by how much
				local ref = new("Frame", { Name = "TutScale", Size = UDim2.fromOffset(100, 100), BackgroundTransparency = 1, Parent = tile })
				task.spawn(function()
					local t0 = os.clock()
					while ring.Parent and go.Parent do
						local k = math.abs(math.sin((os.clock() - t0) * 4))
						local sc = math.max(ref.AbsoluteSize.X / 100, 0.01)]==], "ring scale")
assert(loadstring(s), "LocationsUI compile")
L.Source = s
return "LocationsUI: tutorial ring fits GO (" .. L:GetFullName() .. ")"
