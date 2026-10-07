-- one-off patch (run in Edit): the Contractor's Bonus (99 R$) gave 8x your best contract reward ($1,520) while the
-- Cash Stack (49 R$) gives 20 minutes of income ($49,780): now it is worth minutes of income like the other cash packs,
-- 40 minutes for 99 R$ (the same rate per Robux as the others; the Cash Vault stays the best value). The server's
-- receipt already pays product.minutes first, so the Store and the purchase agree.
local function replaceOnce(src, old, new)
	local a, b = src:find(old, 1, true)
	assert(a, "not found: " .. old:sub(1, 80))
	assert(not src:find(old, b + 1, true), "found twice: " .. old:sub(1, 80))
	return src:sub(1, a - 1) .. new .. src:sub(b + 1)
end
local Cfg = game.ReplicatedStorage.Shared.Config
local s = Cfg.Source
if s:find('name = "Contractor\'s Bonus", desc = "Instant cash: 40 minutes', 1, true) then return "already patched" end
s = replaceOnce(s, [[{ key = "cashpack", id = 3716559383, icon = "💰", name = "Contractor's Bonus", desc = "Instant cash: 8x your best contract reward.", cash = 8 },]],
	[[{ key = "cashpack", id = 3716559383, price = 99, icon = "💰", name = "Contractor's Bonus", desc = "Instant cash: 40 minutes of your income, right now.", minutes = 40 },]])
assert(loadstring(s), "Config compile")
Cfg.Source = s
return "Config: Contractor's Bonus = 40 min of income"
