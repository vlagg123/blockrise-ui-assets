-- one-off patch (run in Edit): the Blender hammer pictures (hotbar TextureId, shop tiles, Store pass)
local ICONS = {
	rusty = "rbxassetid://140017267585797", iron = "rbxassetid://107313245584623", steel = "rbxassetid://92464271681130",
	gold = "rbxassetid://74547073866110", titanium = "rbxassetid://120829940524720", emerald = "rbxassetid://129882943403564",
	ruby = "rbxassetid://110922799386795", sapphire = "rbxassetid://106839534578056", amethyst = "rbxassetid://134714376349769",
	lava = "rbxassetid://94741639706514", frost = "rbxassetid://74436785253267", diamond = "rbxassetid://115516317465770",
	plasma = "rbxassetid://96724178983798", solar = "rbxassetid://89150929634812", galaxy = "rbxassetid://99068699750989",
	thunder = "rbxassetid://79051832898976",
}
local Cfg = game.ReplicatedStorage.Shared.Config
local s = Cfg.Source
if not s:find("rbxassetid://140017267585797", 1, true) then
	for key, id in pairs(ICONS) do
		if key ~= "thunder" then
			local n
			s, n = s:gsub('key = "' .. key .. '", name =', 'key = "' .. key .. '", icon = "' .. id .. '", name =')
			assert(n == 1, "tool " .. key .. ": " .. n)
		end
	end
	local n
	s, n = s:gsub('Config.StormHammer = { pass = "stormhammer", key = "thunder",', 'Config.StormHammer = { pass = "stormhammer", key = "thunder", icon = "' .. ICONS.thunder .. '",')
	assert(n == 1, "storm icon")
	-- (the pass keeps its ⚡: the HUD effect line shows it as text; the Store tile takes Config.StormHammer.icon)
	assert(loadstring(s), "Config compile")
	Cfg.Source = s
end
-- a new hammer gets its own reveal card (HammerFX), so no toast / banner on top of it; big banners wait for the card
local function replaceOnce(src, old, new)
	local a, b = src:find(old, 1, true)
	assert(a, "not found: " .. old:sub(1, 80))
	assert(not src:find(old, b + 1, true), "found twice: " .. old:sub(1, 80))
	return src:sub(1, a - 1) .. new .. src:sub(b + 1)
end
local Client = game.StarterPlayer.StarterPlayerScripts.Client
local c = Client.Source
if not c:find("HammerFX", 1, true) then
	c = replaceOnce(c, "\t\ttoast(\"✅ \" .. d.name .. msg, T.green, 3.5)\n\t\tif d.effect then\n",
		"\t\tif d.kind ~= \"tool\" then toast(\"✅ \" .. d.name .. msg, T.green, 3.5) end\n\t\tif d.effect and d.kind ~= \"tool\" then -- a new hammer: HammerFX shows its reveal card\n")
	c = replaceOnce(c, "return player.PlayerGui:FindFirstChild(\"Intro\") ~= nil or openCards > 0",
		"return player.PlayerGui:FindFirstChild(\"Intro\") ~= nil or (player.PlayerGui:FindFirstChild(\"HammerFX\") and player.PlayerGui.HammerFX:GetAttribute(\"Open\")) == true or openCards > 0")
	assert(loadstring(c), "Client compile")
	Client.Source = c
end
-- the hammers already in the library get their picture too
for key, id in pairs(ICONS) do
	for _, t in ipairs(game.ServerStorage.Hammers:GetChildren()) do
		if t:GetAttribute("Key") == key then t.TextureId = id end
	end
end
return "hammer icons patched"
