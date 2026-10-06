-- one-off patch (run in Edit), with Hammers.lua (ShopTiers / Featured / ShopOffer) published first:
--  * Hammer Shop: three Hammers of the Day (Epic / Legendary / Mythic) for Gems (shopbuy) or Robux (3 developer
--    products, the hammer you picked is remembered with shopintent), and the Builder's Crate for Robux too
--  * Icons.make takes a picture id ("rbxassetid://...") too (the HAMMERS tab shows a hammer, not a gift)
--  * waypoints: done within 18 studs (a place you can't step right onto never keeps its arrow), and the menus can
--    read / clear the current one (Places: remove it)
--  * COMPANY: the Company Registry opens at Level 5 (when you can found one)
local function replaceOnce(src, old, new, what)
	local a, b = src:find(old, 1, true)
	assert(a, "not found: " .. (what or old:sub(1, 80)))
	assert(not src:find(old, b + 1, true), "found twice: " .. (what or old:sub(1, 80)))
	return src:sub(1, a - 1) .. new .. src:sub(b + 1)
end
local RS = game:GetService("ReplicatedStorage")
local SSS = game:GetService("ServerScriptService")
local ConfigM, IconsM = RS.Shared.Config, RS.Shared.Icons
local Main, HS = SSS.Game.Main, SSS.Game.HammerService
local Client = game.StarterPlayer.StarterPlayerScripts.Client
if HS.Source:find("actions.shopbuy", 1, true) then return "already patched" end
assert(RS.Shared.Hammers.Source:find("Hammers.ShopOffer", 1, true), "publish Hammers.lua (Hammer Shop) first")

-- Config: the products -----------------------------------------------------------------------------------------------
local cfg = replaceOnce(ConfigM.Source, "\nreturn Config", [==[

-- SHOP_V5: the Hammer Shop's Robux products (ids 0 = not created yet: hidden in the live game, "SOON" in Studio)
do
	local P = Config.Store.products
	table.insert(P, { key = "crate_builder", id = 0, price = 39, icon = "📦", name = "Builder's Crate", desc = "A Builder's Crate: Uncommon or better, a real shot at Legendary.", crate = "builder", count = 1 })
	table.insert(P, { key = "hammer_epic", id = 0, price = 99, icon = "🔨", name = "Epic Hammer of the Day", desc = "Today's Epic hammer from the Hammer Shop, yours at once.", hammerTier = 1 })
	table.insert(P, { key = "hammer_legendary", id = 0, price = 249, icon = "🔨", name = "Legendary Hammer of the Day", desc = "Today's Legendary hammer from the Hammer Shop, yours at once.", hammerTier = 2 })
	table.insert(P, { key = "hammer_mythic", id = 0, price = 549, icon = "🔨", name = "Mythic Hammer of the Day", desc = "Today's Mythic hammer from the Hammer Shop, yours at once.", hammerTier = 3 })
	if Config.ProductImages then Config.ProductImages.crate_builder = "rbxassetid://104449117497713" end
end
-- the Company Registry opens at this Level (the Level a company can be founded at)
Config.CompanyLevel = 5

return Config]==], "return Config")
assert(loadstring(cfg), "compile Config")

-- Icons: a picture id works like an atlas name -------------------------------------------------------------------------
local ic = replaceOnce(IconsM.Source, [==[function Icons.make(key, props)
	props = props or {}]==], [==[function Icons.make(key, props)
	props = props or {}
	-- a picture of its own ("rbxassetid://..."): a plain image
	if type(key) == "string" and key:find("^rbxassetid://") then
		local img = Instance.new("ImageLabel")
		img.BackgroundTransparency = 1
		img.ScaleType = Enum.ScaleType.Fit
		img.Image = key
		img.Name = "Icon"
		for k, v in pairs(props) do if k ~= "Parent" then img[k] = v end end
		img.Parent = props.Parent
		return img
	end]==])
assert(loadstring(ic), "compile Icons")

-- HammerService: buy a Hammer of the Day ------------------------------------------------------------------------------
local hs = replaceOnce(HS.Source, [==[function actions.odds(plr, st, crateId)]==], [==[-- Hammer Shop: one of the Hammers of the Day, for Gems (shopbuy) or Robux (shopintent, then the receipt: GrantShopHammer)
local function grantHammer(plr, st, key, src)
	local d = st.data
	local isNew = not d.Index[key]
	local handBefore = M.Equipped(d).id
	local it = M.Give(plr, st, key, src, { force = true }) -- (bought: never lost to a full bag)
	if not it then return nil end
	if M.Equipped(d).id ~= handBefore then ctx.giveTool(plr) end
	if ctx.sync then ctx.sync(plr) else M.Publish(plr) end
	ctx.saveSoon(plr)
	return { id = it.id, key = key, r = Hammers.ById[key].r, lv = 1, new = isNew }
end

function actions.shopbuy(plr, st, key)
	local d = st.data
	if Config.InTutorial and Config.InTutorial(d) then return false, "🔒 The Hammer Shop opens after the tutorial" end
	local o = type(key) == "string" and Hammers.ShopOffer(key)
	if not o then return false, "That hammer isn't in the shop any more" end
	if (d.Gems or 0) < o.gems then return false, "Not enough Gems" end
	ctx.addGems(plr, -o.gems, Hammers.ById[key].name)
	local res = grantHammer(plr, st, key, "shop")
	if not res then return false, "Something went wrong" end
	ctx.feedback(plr, "Hammer", { kind = "shop", key = key, r = res.r, new = res.new, via = "gems" })
	return true, res
end

-- which Hammer of the Day the Robux button was for (the receipt gives that one, even right after midnight)
function actions.shopintent(plr, st, key)
	local o = type(key) == "string" and Hammers.ShopOffer(key)
	if not o then return false, "That hammer isn't in the shop any more" end
	st.shopIntent = { key = key, tier = o.tier, t = os.time() }
	return true
end

function M.GrantShopHammer(plr, st, tier)
	ready(st.data)
	local key
	local it = st.shopIntent
	if it and it.tier == tier and os.time() - it.t < 900 and Hammers.ShopOffer(it.key, it.t) then key = it.key end
	if not key then
		local o = Hammers.Featured(Hammers.ShopDay())[tier]
		key = o and o.key
	end
	if not key then return nil end
	local res = grantHammer(plr, st, key, "robux")
	if res then ctx.feedback(plr, "Hammer", { kind = "shop", key = key, r = res.r, new = res.new, via = "robux" }) end
	return res
end

function actions.odds(plr, st, crateId)]==])
assert(loadstring(hs), "compile HammerService")

-- Main: the receipt of a Hammer of the Day -----------------------------------------------------------------------------
local m = replaceOnce(Main.Source, [==[	elseif product.crate then
		HammerService.AddCrate(plr, st, product.crate, product.count or 1, "robux")]==], [==[	elseif product.hammerTier then
		HammerService.GrantShopHammer(plr, st, product.hammerTier)
	elseif product.crate then
		HammerService.AddCrate(plr, st, product.crate, product.count or 1, "robux")]==])
assert(loadstring(m), "compile Main")

-- Client ----------------------------------------------------------------------------------------------------------------
local s = Client.Source
-- WAYPOINT_V2: done within 18 studs (the spot of a place can be inside a counter or a sign)
s = replaceOnce(s, [==[		if Vector2.new(pos.X - waypoint.pos.X, pos.Z - waypoint.pos.Z).Magnitude < 12 then waypoint = nil]==],
	[==[		if Vector2.new(pos.X - waypoint.pos.X, pos.Z - waypoint.pos.Z).Magnitude < 18 then waypoint = nil -- WAYPOINT_V2]==])
s = replaceOnce(s, [==[	ctx.showHire = showHire]==], [==[	ctx.showHire = showHire
	-- the current waypoint (Places can show it and take it away)
	ctx.waypointName = function() return waypoint and waypoint.name end
	ctx.clearWaypoint = function() waypoint = nil end]==])
-- COMPANY: the Registry opens at Level 5 (or once you have a company)
s = replaceOnce(s, [==[	local Shop = _G.__CE_ShopUI
	if name == "Company" then _G.__CE_ShowCompany()]==], [==[	if name == "Company" and (player:GetAttribute("Level") or 1) < (Config.CompanyLevel or 5) and (player:GetAttribute("CompanyName") or "") == "" then
		toast("🔒 The Company Registry opens at Level " .. (Config.CompanyLevel or 5) .. " (you're Level " .. (player:GetAttribute("Level") or 1) .. ")", T.muted, 3)
		return
	end
	local Shop = _G.__CE_ShopUI
	if name == "Company" then _G.__CE_ShowCompany()]==])
assert(loadstring(s), "compile Client")

ConfigM.Source = cfg
IconsM.Source = ic
HS.Source = hs
Main.Source = m
Client.Source = s
return "shop v5"
