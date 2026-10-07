-- one-off patch (run in Edit): the 24 hammers made after the first 16 are in the game: each has its in-hand model
-- (ServerStorage.Hammers.Hammer_<key>, built by hammer_build.lua from hammers/spec.json) and its picture, so they drop
-- from the crates of their rarity, show in the Index and can be traded. (The Exclusive Crate stays closed until its
-- Robux products exist; the Founder's Hammer is only for events.)
local KEYS = { "mallet", "brick", "claw", "copper", "neon", "toolbox", "bronze", "obsidian", "jade", "candy", "dragon", "clockwork", "robo",
	"phoenix", "tsunami", "cyber", "void", "blackhole", "demon", "celestial", "crown", "ghost", "prism", "founder" }
local lib = game.ServerStorage:WaitForChild("Hammers")
for _, k in ipairs(KEYS) do assert(lib:FindFirstChild("Hammer_" .. k), "no model for " .. k) end
local Hm = game.ReplicatedStorage.Shared.Hammers
local s = Hm.Source
local n = 0
for _, k in ipairs(KEYS) do
	local a = s:find('{ key = "' .. k .. '",', 1, true)
	assert(a, "no entry for " .. k)
	local e = s:find("\n", a, true)
	local line = s:sub(a, e - 1)
	if line:find("soon = true, ", 1, true) then
		local new = line:gsub("soon = true, ", 'model = "' .. k .. '", ', 1)
		s = s:sub(1, a - 1) .. new .. s:sub(e)
		n += 1
	end
end
if n > 0 then
	s = s:gsub("the 40 hammers %(16 have a model in the game today; the rest are \"coming soon\"%)", "the 40 hammers (every one has its model in the game)", 1)
	assert(loadstring(s), "Hammers compile")
	Hm.Source = s
end
return "Hammers: " .. n .. " now in the game"
