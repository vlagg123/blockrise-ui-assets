-- one-off patch (run in Edit): the tool tiers become the 16 hammers (names, colours, the new Thunderclap at 15, Galaxy at 16)
-- prices / power keep the same x3 / x2 ladder; tier 16 is new on top. Saved ToolTier values stay valid (1..15 unchanged).
local function replaceOnce(src, old, new)
	local a, b = src:find(old, 1, true)
	assert(a, "not found: " .. old:sub(1, 80))
	assert(not src:find(old, b + 1, true), "found twice: " .. old:sub(1, 80))
	return src:sub(1, a - 1) .. new .. src:sub(b + 1)
end
local Cfg = game.ReplicatedStorage.Shared.Config
local s = Cfg.Source
if s:find("Thunderclap Hammer", 1, true) then return "already patched" end
local a = s:find("Config.Tools = {", 1, true)
local b = select(2, s:find("\n}\n", a, true))
assert(a and b, "tools block")
s = s:sub(1, a - 1) .. [[Config.Tools = {
	-- the hammers: every tier doubles your build power (and your crew's, they use your tools)
	{ tier = 1, key = "rusty", name = "Rusty Hammer", price = 0, power = 1, cooldown = 0.42, color = Color3.fromRGB(150, 96, 60),
	  desc = "Old, bent and held together with tape. It works. Mostly." },
	{ tier = 2, key = "iron", name = "Iron Hammer", price = 120, power = 2, cooldown = 0.38, color = Color3.fromRGB(130, 136, 150),
	  desc = "x2 build power. Solid iron, honest wood." },
	{ tier = 3, key = "steel", name = "Steel Hammer", price = 350, power = 4, cooldown = 0.34, color = Color3.fromRGB(70, 140, 235),
	  desc = "x2 build power. Polished steel, comfy grip." },
	{ tier = 4, key = "gold", name = "Golden Hammer", price = 1000, power = 8, cooldown = 0.31, color = Color3.fromRGB(255, 190, 40),
	  desc = "x2 build power. Solid gold. Every hit shines." },
	{ tier = 5, key = "titanium", name = "Titanium Sledge", price = 2900, power = 16, cooldown = 0.29, color = Color3.fromRGB(255, 130, 40),
	  desc = "x2 build power. Light as air, hard as rock." },
	{ tier = 6, key = "emerald", name = "Emerald Hammer", price = 8500, power = 32, cooldown = 0.27, color = Color3.fromRGB(30, 200, 110),
	  desc = "x2 build power. A flawless emerald set in gold." },
	{ tier = 7, key = "ruby", name = "Ruby Hammer", price = 24600, power = 64, cooldown = 0.26, color = Color3.fromRGB(230, 30, 70),
	  desc = "x2 build power. Two blazing rubies." },
	{ tier = 8, key = "sapphire", name = "Sapphire War Hammer", price = 71400, power = 128, cooldown = 0.25, color = Color3.fromRGB(40, 100, 255),
	  desc = "x2 build power. A sapphire war hammer with a spike." },
	{ tier = 9, key = "amethyst", name = "Amethyst Crystal Hammer", price = 207000, power = 256, cooldown = 0.24, color = Color3.fromRGB(165, 85, 255),
	  desc = "x2 build power. Crystals that grew on their own." },
	{ tier = 10, key = "lava", name = "Lava Hammer", price = 600000, power = 512, cooldown = 0.235, color = Color3.fromRGB(255, 110, 20),
	  desc = "x2 build power. Forged in a volcano. Still hot." },
	{ tier = 11, key = "frost", name = "Frost Hammer", price = 1740000, power = 1024, cooldown = 0.23, color = Color3.fromRGB(120, 215, 255),
	  desc = "x2 build power. Cold enough to freeze the air." },
	{ tier = 12, key = "diamond", name = "Diamond Hammer", price = 5050000, power = 2048, cooldown = 0.225, color = Color3.fromRGB(170, 235, 255),
	  desc = "x2 build power. The hardest hammer there is." },
	{ tier = 13, key = "plasma", name = "Plasma Hammer", price = 15000000, power = 4096, cooldown = 0.22, color = Color3.fromRGB(40, 200, 255),
	  desc = "x2 build power. Pure energy in a magnetic field." },
	{ tier = 14, key = "solar", name = "Solar Hammer", price = 45000000, power = 8192, cooldown = 0.215, color = Color3.fromRGB(255, 150, 30),
	  desc = "x2 build power. A tiny sun on a stick." },
	{ tier = 15, key = "thunder", name = "Thunderclap Hammer", price = 135000000, power = 16384, cooldown = 0.21, color = Color3.fromRGB(80, 170, 255),
	  desc = "x2 build power. Forged inside a storm. Every hit cracks like thunder." },
	{ tier = 16, key = "galaxy", name = "Galaxy Hammer", price = 405000000, power = 32768, cooldown = 0.205, color = Color3.fromRGB(160, 90, 255),
	  desc = "x2 build power. A whole galaxy trapped in crystal. The last hammer." },
}
]] .. s:sub(b + 1)
s = replaceOnce(s, [[desc = "Visit the EQUIPMENT STORE and buy Pro Tools: every hit builds more."]],
	[[desc = "Visit the EQUIPMENT STORE and buy the Iron Hammer: every hit builds more."]])
s = replaceOnce(s, [[{ title = "Better tools",]], [[{ title = "A better hammer",]])
assert(loadstring(s), "Config compile")

local Client = game.StarterPlayer.StarterPlayerScripts.Client
local c = Client.Source
c = replaceOnce(c, [["🛠️ Walk to the EQUIPMENT STORE and buy Pro Tools — follow the arrow"]], [["🔨 Walk to the EQUIPMENT STORE and buy the Iron Hammer — follow the arrow"]])
c = replaceOnce(c, [["🛠️ You can afford Pro Tools! Visit the Equipment Store"]], [["🔨 You can afford the Iron Hammer! Visit the Equipment Store"]])
assert(loadstring(c), "Client compile")

Cfg.Source = s
Client.Source = c
return "hammer config patched"
