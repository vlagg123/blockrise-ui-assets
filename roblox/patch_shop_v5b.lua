-- one-off patch (run in Edit, after patch_shop_v5): the Rare Hammer of the Day's Robux product
local ConfigM = game:GetService("ReplicatedStorage").Shared.Config
local s = ConfigM.Source
if s:find('"hammer_rare"', 1, true) then return "already patched" end
local old = [==[	table.insert(P, { key = "hammer_mythic",]==]
local a = s:find(old, 1, true)
assert(a and not s:find(old, a + 1, true), "hammer_mythic product not found once")
s = s:sub(1, a - 1) .. [==[	table.insert(P, { key = "hammer_rare", id = 0, price = 29, icon = "🔨", name = "Rare Hammer of the Day", desc = "Today's Rare hammer from the Hammer Shop, yours at once.", hammerTier = 4 })
]==] .. s:sub(a)
assert(loadstring(s), "compile Config")
ConfigM.Source = s
return "hammer_rare product"
