-- one-off patch (run in Edit, with Hammers.lua without the Rare tier): the Hammer Shop sells three Hammers of the Day
-- (Epic, Legendary, Mythic) in one row with the Thunderclap; the Rare Hammer of the Day's Robux product goes away
local ConfigM = game:GetService("ReplicatedStorage").Shared.Config
local s = ConfigM.Source
local line = [==[	table.insert(P, { key = "hammer_rare", id = 0, price = 29, icon = "🔨", name = "Rare Hammer of the Day", desc = "Today's Rare hammer from the Hammer Shop, yours at once.", hammerTier = 4 })
]==]
local a, b = s:find(line, 1, true)
if not a then return "already patched" end
assert(not s:find(line, b + 1, true), "hammer_rare found twice")
s = s:sub(1, a - 1) .. s:sub(b + 1)
assert(loadstring(s), "compile Config")
ConfigM.Source = s
return "shop v6: hammer_rare product removed"
