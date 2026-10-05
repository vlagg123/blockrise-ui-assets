-- one-off patch (run in Edit): the hammers lean a touch more forward in the hand (-25° -> -16°)
local n = 0
for _, t in ipairs(game.ServerStorage.Hammers:GetChildren()) do
	if t:IsA("Tool") then t.Grip = CFrame.Angles(math.rad(-16), 0, 0); n += 1 end
end
return n .. " hammers re-gripped"
