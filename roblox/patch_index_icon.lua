-- one-off patch (run in Edit): the Hammer Index shows a hammer (the Ruby Hammer, drawn without sparkles:
-- icons/plain/hammer_ruby.png) instead of a star: the MORE button, the window header, the banner
local function replaceOnce(src, old, new)
	local a, b = src:find(old, 1, true)
	assert(a, "not found: " .. old:sub(1, 80))
	assert(not src:find(old, b + 1, true), "found twice: " .. old:sub(1, 80))
	return src:sub(1, a - 1) .. new .. src:sub(b + 1)
end
local out = {}
local Ic = game.ReplicatedStorage.Shared.Icons
local s = Ic.Source
if not s:find("hammer_index", 1, true) then
	s = replaceOnce(s, [[	vip = "rbxassetid://120072501383052",
}]], [[	vip = "rbxassetid://120072501383052",
	hammer_index = "rbxassetid://71920003497651", -- the Hammer Index (MORE): the Ruby Hammer
}]])
	assert(loadstring(s), "Icons compile")
	Ic.Source = s
	table.insert(out, "Icons")
end
local Client = game.StarterPlayer.StarterPlayerScripts.Client
local c = Client.Source
if not c:find("Index = \"hammer_index\"", 1, true) then
	c = replaceOnce(c, [[Inventory = "backpack", TradeUp = "upgrades" }]], [[Inventory = "backpack", TradeUp = "upgrades", Index = "hammer_index" }]])
	assert(#c < 200000, "Client too big")
	assert(loadstring(c), "Client compile")
	Client.Source = c
	table.insert(out, "Client " .. #c)
end
return table.concat(out, " · ")
