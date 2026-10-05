-- one-off patch (run in Edit): every Robux price shows Roblox's own Robux symbol (the  glyph, U+E002) instead of "R$",
-- and every button that buys something for Robux is green (the Shop's pass button was blue, the car dealer's gold,
-- the SKIP offer orange).
local function replaceOnce(src, old, new)
	local a, b = src:find(old, 1, true)
	assert(a, "not found: " .. old:sub(1, 80))
	assert(not src:find(old, b + 1, true), "found twice: " .. old:sub(1, 80))
	return src:sub(1, a - 1) .. new .. src:sub(b + 1)
end
local SPS = game.StarterPlayer.StarterPlayerScripts
local Client = SPS.Client
local targets = {
	Client, Client.StoreUI, Client.SpinUI, Client.VehicleUI, Client.LocationsUI, Client.ShopUI, Client.DealerUI,
	game.ReplicatedStorage.Shared.MenuKit,
}
local GLYPH = "\\u{E002} " -- written into the scripts as the escape sequence inside their string literals
local new, report = {}, {}
for _, s in ipairs(targets) do
	local src, n = s.Source:gsub("R%$ ?", GLYPH)
	new[s] = src
	table.insert(report, s.Name .. " x" .. n)
end
-- green buy buttons
new[Client.ShopUI] = replaceOnce(new[Client.ShopUI], [[tostring(pass.price or ""), Color3.fromRGB(80, 170, 255), function()]],
	[[tostring(pass.price or ""), K.GREEN, function()]])
new[Client.DealerUI] = replaceOnce(new[Client.DealerUI], [[tostring(p and p.price or "?"), GOLD]], [[tostring(p and p.price or "?"), GREEN]])
new[Client] = replaceOnce(new[Client], [[UI.button(label, owned and T.blue or T.accent, owned and T.blue2 or T.accent2,]],
	[[UI.button(label, owned and T.blue or T.green, owned and T.blue2 or T.green2,]])
for s, src in pairs(new) do
	assert(loadstring(src), "compile " .. s:GetFullName())
end
for s, src in pairs(new) do
	s.Source = src
end
return "Robux symbol on all prices: " .. table.concat(report, ", ")
