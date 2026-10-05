-- one-off patch (run in Edit): on the title screen (LOADING / PLAY) the hotbar with the hammer and the
-- Auto Build / Auto Train switches showed through. They only appear once you press PLAY.
local function replaceOnce(src, old, new)
	local a, b = src:find(old, 1, true)
	assert(a, "not found: " .. old:sub(1, 80))
	assert(not src:find(old, b + 1, true), "found twice: " .. old:sub(1, 80))
	return src:sub(1, a - 1) .. new .. src:sub(b + 1)
end
local C = game.StarterPlayer.StarterPlayerScripts.Client
local s = C.Source
if s:find("INTRO_HOTBAR", 1, true) then return "already patched" end
s = replaceOnce(s, [[	local introGui = new("ScreenGui", { Name = "Intro", IgnoreGuiInset = true, DisplayOrder = 100, ResetOnSpawn = false, Parent = player:WaitForChild("PlayerGui") })
]], [[	local introGui = new("ScreenGui", { Name = "Intro", IgnoreGuiInset = true, DisplayOrder = 100, ResetOnSpawn = false, Parent = player:WaitForChild("PlayerGui") })
	-- INTRO_HOTBAR: the hotbar (hammer) and the Auto Build / Auto Train switches only show after PLAY
	local StarterGuiI = game:GetService("StarterGui")
	pcall(function() StarterGuiI:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false) end)
	local autoBarI = gui:FindFirstChild("AutoBar")
	if autoBarI then autoBarI.Visible = false end
	introGui.Destroying:Connect(function()
		pcall(function() StarterGuiI:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, true) end)
		if autoBarI then autoBarI.Visible = true end
	end)
]])
assert(loadstring(s), "Client compile")
C.Source = s
return "hotbar hidden on the title screen"
