-- one-off patch (run in Edit): while the SKIP card is up (build cinematic), the Auto Build / Auto Train switches hide
-- (they sat on top of the card in the bottom-right corner)
local Client = game.StarterPlayer.StarterPlayerScripts.Client
local s = Client.Source
if s:find("SKIP_HIDES_AUTOBAR", 1, true) then return "already patched" end
local old = [[			skipGui = new("ScreenGui", { Name = "SkipCine", IgnoreGuiInset = true, ResetOnSpawn = false, DisplayOrder = 70, Parent = player:WaitForChild("PlayerGui") })
]]
local a, b = s:find(old, 1, true)
assert(a and not s:find(old, b + 1, true), "skipGui line not found once")
s = s:sub(1, a - 1) .. old .. [[			-- SKIP_HIDES_AUTOBAR: the Auto Build / Auto Train switches step aside while the card is up
			do
				local ab = gui:FindFirstChild("AutoBar")
				if ab and ab.Visible then
					ab.Visible = false
					skipGui.Destroying:Connect(function() ab.Visible = true end)
				end
			end
]] .. s:sub(b + 1)
assert(loadstring(s), "compile Client")
Client.Source = s
return "skip hides autobar"
