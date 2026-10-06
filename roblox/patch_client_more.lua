-- one-off patch (run in Edit), Client:
--   * the Trade-Up window (MORE menu) gets the green arrow in its header
--   * "You have a hammer crate!" goes away once you have looked in the Inventory (UpgradesUI sets CrateSeen); a new crate
--     brings it back
local function replaceOnce(src, old, new)
	local a, b = src:find(old, 1, true)
	assert(a, "not found: " .. old:sub(1, 80))
	assert(not src:find(old, b + 1, true), "found twice: " .. old:sub(1, 80))
	return src:sub(1, a - 1) .. new .. src:sub(b + 1)
end
local Client = game.StarterPlayer.StarterPlayerScripts.Client
local s = Client.Source
if s:find("TradeUp = \"upgrades\"", 1, true) then return "already patched" end
s = replaceOnce(s, [[Locations = "locations", Welcome = "star", Inventory = "backpack" }]], [[Locations = "locations", Welcome = "star", Inventory = "backpack", TradeUp = "upgrades" }]])
s = replaceOnce(s, [[	elseif not cj and completed >= 1 and (player:GetAttribute("CrateTotal") or 0) > 0 then
		h = "📦 You have a hammer crate! Open it: INVENTORY → CRATES"]], [[	elseif not cj and completed >= 1 and (player:GetAttribute("CrateTotal") or 0) > (player:GetAttribute("CrateSeen") or 0) then
		h = "📦 You have a hammer crate! Open it: INVENTORY → CRATES"]])
assert(#s < 200000, "Client too big: " .. #s)
assert(loadstring(s), "Client compile")
Client.Source = s
return "Client patched (" .. #s .. " chars)"
