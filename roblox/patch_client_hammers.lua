-- one-off patch (run in Edit): the Client follows the hammer items and the zones opened by Rebirth
--  * build power on the HUD = the hammer in your hand (HammerPower) x your bonuses; swing speed = its rarity
--  * the zone gates and hints say "Rebirth N" instead of a Reputation number
--  * the early hints point to the hammer crates instead of buying the Iron Hammer
local function replaceOnce(src, old, new)
	local a, b = src:find(old, 1, true)
	assert(a, "not found: " .. old:sub(1, 80))
	assert(not src:find(old, b + 1, true), "found twice: " .. old:sub(1, 80))
	return src:sub(1, a - 1) .. new .. src:sub(b + 1)
end
local Client = game.StarterPlayer.StarterPlayerScripts.Client
local s = Client.Source
if s:find("HammerPower", 1, true) then return "already patched" end

s = replaceOnce(s, [[	local t = Config.Tools[player:GetAttribute("ToolTier") or 1] or Config.Tools[1]
	return t.power * (player:GetAttribute("PowerMult") or 1)]], [[	return (player:GetAttribute("HammerPower") or 1) * (player:GetAttribute("PowerMult") or 1)]])
s = replaceOnce(s, [[for _, a in ipairs({ "Strength", "PowerMult", "ToolTier" }) do player:GetAttributeChangedSignal(a):Connect(refreshStrength) end
refreshStrength()]], [[for _, a in ipairs({ "Strength", "PowerMult", "ToolTier", "HammerPower" }) do player:GetAttributeChangedSignal(a):Connect(refreshStrength) end
refreshStrength()]])
s = replaceOnce(s, [[	local tier = player:GetAttribute("ToolTier") or 1
	return (Config.Tools[tier] or Config.Tools[1]).cooldown * (player:GetAttribute("Pass_fasttools") and Config.FastToolsPass or 1)]],
	[[	local H = require(RS.Shared.Hammers)
	local r = H.Rarities[player:GetAttribute("EquipRarity") or 1] or H.Rarities[1]
	return r.cooldown * (player:GetAttribute("Pass_fasttools") and Config.FastToolsPass or 1)]])

-- hints near the gates
s = replaceOnce(s, [[		h = "🔒 The Suburbs open at " .. Config.SuburbsRep .. " Reputation (you have " .. (player:GetAttribute("Rep") or 0) .. ") — finish contracts to earn it"]],
	[[		h = "🔒 The Suburbs open after your first Rebirth: finish the Town's last contract, then press REBIRTH"]])
s = replaceOnce(s, [[		h = "🔒 Downtown opens at " .. Config.DowntownRep .. " Reputation (you have " .. (player:GetAttribute("Rep") or 0) .. ")"]],
	[[		h = "🔒 Downtown opens at Rebirth " .. (Config.Zones.downtown.rebirth or 2) .. " (you have " .. (player:GetAttribute("Rebirths") or 0) .. ")"]])
s = replaceOnce(s, [[		h = tp == "shop" and "🔨 Walk to the EQUIPMENT STORE and buy the Iron Hammer — follow the arrow"]],
	[[		h = tp == "shop" and "🔨 Open the SHOP (HAMMERS tab) and open your first hammer crate"]])
s = replaceOnce(s, [[	elseif not cj and completed >= 1 and completed < 3 and (player:GetAttribute("ToolTier") or 1) == 1 and (player:GetAttribute("Money") or 0) >= Config.Tools[2].price then
		h = "🔨 You can afford the Iron Hammer! Visit the Equipment Store"]],
	[[	elseif not cj and completed >= 1 and (player:GetAttribute("CrateTotal") or 0) > 0 then
		h = "📦 You have a hammer crate! Open it: SHOP → HAMMERS"]])

-- the zone gates: Rebirth, not Reputation
s = replaceOnce(s, [[	local text = "🔒 " .. g.cfg.label .. "\nNeed " .. g.cfg.rep .. " ⭐ Reputation"]],
	[[	local text = "🔒 " .. g.cfg.label .. "\nOpens at Rebirth " .. (g.cfg.rebirth or 1)]])
s = replaceOnce(s, [[	if l then l.Text = "🔒 " .. g.cfg.label .. "\nReputation " .. (player:GetAttribute("Rep") or 0) .. " / " .. g.cfg.rep end]],
	[[	if l then l.Text = "🔒 " .. g.cfg.label .. "\nRebirths " .. (player:GetAttribute("Rebirths") or 0) .. " / " .. (g.cfg.rebirth or 1) end]])

s = replaceOnce(s, [[player:GetAttributeChangedSignal("Rep"):Connect(function() for _, g in pairs(gates) do refreshGate(g) end end)]],
	[[player:GetAttributeChangedSignal("Rebirths"):Connect(function() for _, g in pairs(gates) do refreshGate(g) end end)]])

assert(loadstring(s), "compile")
local L = Client.LocationsUI
local ls = replaceOnce(L.Source, [[badge = { "🔒 " .. Config.FormatNum(z.rep or 0) .. " ⭐", K.DARK }]], [[badge = { "🔒 REBIRTH " .. (z.rebirth or 1), K.DARK }]])
assert(loadstring(ls), "compile LocationsUI")
L.Source = ls
Client.Source = s
return "Client patched"
