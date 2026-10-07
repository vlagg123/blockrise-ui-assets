-- one-off patch (run in Edit): no sparkles on any picture (2026-10-07)
--  * every hammer has its new Blender render (no sparkles): Hammers.List[...].img for all 40, the old tool icons
--    (Config.Tools, tiers 1-15) and the Thunderclap's picture too
--  * the Store pictures that had sparkles (passes, gem / cash packs, spins, the crate passes) and four training-gear
--    pictures, rendered again without them
-- (MenuKit's K.FALLBACK shows the old pictures until Roblox has reviewed the new ones)
local function replaceOnce(src, old, new)
	local a, b = src:find(old, 1, true)
	assert(a, "not found: " .. old:sub(1, 80))
	assert(not src:find(old, b + 1, true), "found twice: " .. old:sub(1, 80))
	return src:sub(1, a - 1) .. new .. src:sub(b + 1)
end
local report = {}
local HAMMER = {
	rusty = "79621144422162", iron = "136293287602945", steel = "115250332513646", gold = "96534178685358", titanium = "122092536358702",
	emerald = "117994941043100", ruby = "111998947682400", sapphire = "126908235807818", amethyst = "77112451787224", lava = "128398544381380",
	frost = "123265291061806", diamond = "90821017167974", plasma = "94175010730346", solar = "97311092292053", galaxy = "115703594722092",
	thunder = "129897267497558", mallet = "110275707389261", brick = "122300976823007", claw = "72634268686647", copper = "107667721056745",
	neon = "77977142280559", toolbox = "108582824123015", bronze = "138973335886828", obsidian = "132923967523458", jade = "120686817744206",
	candy = "103346052450968", dragon = "131883760103899", clockwork = "126925986803056", robo = "122946142869272", phoenix = "105491534865757",
	tsunami = "115884616655947", cyber = "128511666701616", void = "117224805860749", blackhole = "123688325281268", demon = "124707294911052",
	celestial = "137444330760927", crown = "126956308355764", ghost = "96157713953638", prism = "96956104380447", founder = "111140972435641",
}
-- old picture -> new picture (Config)
local MAP = {
	-- the tool icons (tiers 1-15) and the Thunderclap
	["140017267585797"] = HAMMER.rusty, ["107313245584623"] = HAMMER.iron, ["92464271681130"] = HAMMER.steel, ["74547073866110"] = HAMMER.gold,
	["120829940524720"] = HAMMER.titanium, ["129882943403564"] = HAMMER.emerald, ["110922799386795"] = HAMMER.ruby, ["106839534578056"] = HAMMER.sapphire,
	["134714376349769"] = HAMMER.amethyst, ["94741639706514"] = HAMMER.lava, ["74436785253267"] = HAMMER.frost, ["115516317465770"] = HAMMER.diamond,
	["96724178983798"] = HAMMER.plasma, ["89150929634812"] = HAMMER.solar, ["99068699750989"] = HAMMER.galaxy, ["79051832898976"] = HAMMER.thunder,
	-- Store pictures
	["114002292478180"] = "96499595381268", ["139474241942444"] = "80615650987774", ["123844524251149"] = "102777148756293", ["123085255342882"] = "77129362142929",
	["72451815226274"] = "85854914329871", ["129916717673380"] = "138628569488985", ["111149747210442"] = "80286117552972", ["126109143002031"] = "110051828155957",
	["90790339412602"] = "114944870977030", ["99946262610902"] = "97103017219605", ["98074663629152"] = "94922345578271", ["104220772987659"] = "116593067015504",
	["92552699421535"] = "115596149082454", ["88490060320126"] = "97952651837523", ["91549619059662"] = "121177442701271", ["130810442796727"] = "91052323480380",
	["111400819296862"] = "132614601206685", ["113906745814581"] = "104402252353849",
	-- training gear: kettlebell, anvil, wrecking ball, crane hook
	["75200160905438"] = "84733155791603", ["113707203716255"] = "133276331570922", ["101924819275060"] = "91011730465115", ["108541104556016"] = "89630917528998",
}

local Cfg = game.ReplicatedStorage.Shared.Config
local s = Cfg.Source
local n = 0
for old, new in pairs(MAP) do
	local k
	s, k = s:gsub("rbxassetid://" .. old, "rbxassetid://" .. new)
	n += k
end
if n > 0 then
	assert(loadstring(s), "Config compile")
	Cfg.Source = s
end
table.insert(report, "Config: " .. n)

local Hm = game.ReplicatedStorage.Shared.Hammers
local h = Hm.Source
if not h:find("HAMMER_IMG", 1, true) then
	local parts = {}
	for key, id in pairs(HAMMER) do table.insert(parts, key .. " = \"rbxassetid://" .. id .. "\"") end
	table.sort(parts)
	local block = "-- HAMMER_IMG: every hammer's own picture (rendered in Blender, no sparkles)\nlocal HAMMER_IMG = { " .. table.concat(parts, ", ") ..
		" }\nfor _, h in ipairs(Hammers.List) do if HAMMER_IMG[h.key] then h.img = HAMMER_IMG[h.key] end end\n\nreturn Hammers"
	local a = h:find("\nreturn Hammers%s*$")
	assert(a, "return Hammers not found")
	h = h:sub(1, a) .. block .. "\n"
	assert(loadstring(h), "Hammers compile")
	Hm.Source = h
	table.insert(report, "Hammers: img x40")
end
return table.concat(report, " · ")
