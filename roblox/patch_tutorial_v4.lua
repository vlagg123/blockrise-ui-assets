-- one-off patch (run in Edit): tutorial v4 — the tutorial walks past every shop on the map and buys one thing in each
--   1 Hammers Shop: a Supply Crate (opened at once, the new hammer goes into your hand)
--   2 the Job Board: the first fence
--   3 Training Shop (at the Training Yard gate): Work Gloves
--   4 Training Yard: 10 reps
--   5 Machines Depot: the Mini Excavator
--   6 Hiring Office: a Laborer
--   7 your property → the tutorial is over: every menu unlocks, no more arrows on their own
-- A new builder starts with exactly the money for the four buys; in the tutorial nothing else can be bought.
local function replaceOnce(src, old, new, what)
	local a, b = src:find(old, 1, true)
	assert(a, "not found: " .. (what or old:sub(1, 80)))
	assert(not src:find(old, b + 1, true), "found twice: " .. (what or old:sub(1, 80)))
	return src:sub(1, a - 1) .. new .. src:sub(b + 1)
end

local RS = game:GetService("ReplicatedStorage")
local SSS = game:GetService("ServerScriptService")
local ConfigM = RS.Shared.Config
local Main = SSS.Game.Main
local HS = SSS.Game.HammerService
local VS = SSS.Game.VehicleService
local CS = SSS.Game.CompanyService
local Client = game.StarterPlayer.StarterPlayerScripts.Client

if ConfigM.Source:find("TUTORIAL_V4", 1, true) then return "already patched" end

---------------------------------------------------------------------------------------------------------------------
-- Config
---------------------------------------------------------------------------------------------------------------------
local cfg = ConfigM.Source
cfg = replaceOnce(cfg, "\nreturn Config", [==[

-- TUTORIAL_V4: the tutorial goes past every shop on the map and buys one thing in each
-- (Hammers Shop → the first fence → Training Shop → Training Yard → Machines Depot → Hiring Office → your property).
-- A new builder starts with exactly the money for those four buys (a Supply Crate is $150 in the Town).
Config.NewPlayerMoney = 150 + Config.TrainingGear[2].price + Config.MachineById.excavator.price + Config.WorkerById.laborer.price
-- the Mini Excavator is the tutorial's machine: no Level needed
Config.MachineById.excavator.reqLevel = 1
function Config.InTutorial(d) return (tonumber(d and d.Road) or 1) <= (Config.TutorialSteps or 7) end
do
	local R = Config.Road
	-- buy = what the step buys (the server makes sure it's affordable, once per step)
	R[1] = { title = "Your first hammer", desc = "Your Rusty Hammer is weak. Follow the arrow to the HAMMERS SHOP and buy a Supply Crate: a better hammer is inside, and it goes straight into your hand.", stat = "Hammers", target = 2, place = "shop", buy = "crate", cash = 50, gems = 5 }
	R[2] = { title = "Build your first fence", desc = "Walk to the JOB BOARD and take the Repair Fence contract, then go into your site and CLICK to hit until it's built. Keep a rhythm for a COMBO!", stat = "Completed", target = 1, place = "board", cash = 100, gems = 5 }
	R[3] = { title = "Training gloves", desc = "Strength multiplies your build power. Follow the arrow to the TRAINING SHOP at the Training Yard gate and buy Work Gloves: 2x Strength from every rep.", stat = "GearTier", target = 2, place = "gearshop", buy = "gear", cash = 100, gems = 5 }
	R[4] = { title = "Get stronger", desc = "Go into the TRAINING YARD, stand on a station and click to train. Do 10 reps!", stat = "TrainReps", target = 10, place = "gym", cash = 100, gems = 5 }
	R[5] = { title = "Your first machine", desc = "Machines build your contracts on their own. Follow the arrow to the MACHINES DEPOT and buy the Mini Excavator.", stat = "MachinesOwned", target = 1, place = "machines", buy = "machine", cash = 150, gems = 5 }
	R[6] = { title = "Hire a worker", desc = "At the HIRING OFFICE hire a Laborer. Workers build your contracts with you, even while you rest.", stat = "Workers", target = 1, place = "hire", buy = "worker", cash = 150, gems = 5 }
	R[7] = { title = "Visit your property", desc = "Your own lot is in Maple Grove, south of the town. Follow the arrow and walk onto it: that's the end of the tutorial!", stat = "VisitedHome", target = 1, place = "home", cash = 300, gems = 10 }
	-- the gloves and the excavator are in the tutorial now: the road asks for the next ones
	R[9] = { title = "Lifting Belt", desc = "Buy the Lifting Belt at the TRAINING SHOP: 4x Strength from every rep.", stat = "GearTier", target = 3, place = "gearshop", cash = 300, gems = 10 }
	R[25] = { title = "Concrete Mixer", desc = "Buy the Concrete Mixer Truck at the MACHINES DEPOT (Level 5): one more machine that builds on its own.", stat = "MachinesOwned", target = 2, place = "machines", cash = 12000, gems = 25 }
end

return Config]==], "return Config")
assert(loadstring(cfg), "compile Config")

---------------------------------------------------------------------------------------------------------------------
-- Main
---------------------------------------------------------------------------------------------------------------------
local m = Main.Source
-- new profiles: the tutorial money, no welcome crate (the first one is bought at the Hammers Shop)
m = replaceOnce(m, "return { Money = Config.StartMoney, XP = 0,", "return { Money = Config.NewPlayerMoney or Config.StartMoney, XP = 0,")
m = replaceOnce(m, "Codes = {}, RoadV = 2,", "Codes = {}, RoadV = 3,")
m = replaceOnce(m, "Hammers = {}, Crates = { supply = 1 }, HammerV = 1 }", "Hammers = {}, Crates = {}, HammerV = 1 }")
-- a player still in the old tutorial starts the new one (the steps already done tick off at once, with one summary)
m = replaceOnce(m, "\td.RoadV = 2\n", [==[
	if type(raw) == "table" and raw.Road ~= nil and (tonumber(raw.RoadV) or 0) < 3 and d.Road <= (Config.TutorialSteps or 7) then d.Road = 1 end
	d.RoadV = 3
]==])

-- the tutorial's buy is always affordable (once per step): a builder who spent the starting money, or came from the
-- old tutorial, still gets through
m = replaceOnce(m, [==[			-- "Visit the Training Yard": done when you walk into the yard
			if step and step.stat == "VisitedGym" and plr:GetAttribute("Loaded") then]==], [==[			-- TUTORIAL_V4: the money for the step's buy
			if step and step.buy and st.data and plr:GetAttribute("Loaded") then
				local d = st.data
				local need = 0
				if step.buy == "crate" then need = ((d.Crates or {}).supply or 0) > 0 and 0 or (plr:GetAttribute("SupplyPrice") or 150)
				elseif step.buy == "gear" then need = (d.GearTier or 1) < 2 and Config.TrainingGear[2].price or 0
				elseif step.buy == "machine" then need = Config.MachineById.excavator.price
				elseif step.buy == "worker" then need = Config.WorkerById.laborer.price end
				d.TutTopUp = type(d.TutTopUp) == "table" and d.TutTopUp or {}
				local key = tostring(d.Road)
				if need > 0 and (d.Money or 0) < need and not d.TutTopUp[key] then
					d.TutTopUp[key] = true
					local add = need - (d.Money or 0)
					d.Money = need
					sync(plr)
					feedback(plr, "Money", { amount = add, reason = "Tutorial" })
					saveSoon(plr)
				end
			end
			-- "Visit the Training Yard": done when you walk into the yard
			if step and step.stat == "VisitedGym" and plr:GetAttribute("Loaded") then]==])

-- in the tutorial: the gloves, the first Laborer and the Mini Excavator only; no house, no extensions
m = replaceOnce(m, [==[	if tier ~= cur + 1 then return false, "Buy the previous gear first" end]==], [==[	if tier ~= cur + 1 then return false, "Buy the previous gear first" end
	if Config.InTutorial(st.data) and tier ~= 2 then return false, "🔒 More gear after the tutorial" end]==])
m = replaceOnce(m, [==[	local t = Config.WorkerById[typeId]
	if not t then return false, "Unknown worker" end
	if st.data.Level < t.reqLevel then]==], [==[	local t = Config.WorkerById[typeId]
	if not t then return false, "Unknown worker" end
	if Config.InTutorial(st.data) and (typeId ~= "laborer" or #st.data.Workers >= 1) then return false, "🔒 More workers after the tutorial" end
	if st.data.Level < t.reqLevel then]==])
m = replaceOnce(m, [==[UpgradeHouseRF.OnServerInvoke = function(plr)
	local st = S[plr]
	if not st then return false, "Loading..." end]==], [==[UpgradeHouseRF.OnServerInvoke = function(plr)
	local st = S[plr]
	if not st then return false, "Loading..." end
	if Config.InTutorial(st.data) then return false, "🔒 Your house opens after the tutorial" end]==])
m = replaceOnce(m, [==[BuildExtRF.OnServerInvoke = function(plr, id)
	local st = S[plr]
	if not st then return false, "Loading..." end]==], [==[BuildExtRF.OnServerInvoke = function(plr, id)
	local st = S[plr]
	if not st then return false, "Loading..." end
	if Config.InTutorial(st.data) then return false, "🔒 Extensions open after the tutorial" end]==])
m = replaceOnce(m, [==[	if not cfg then return false, "Unknown machine" end]==], [==[	if not cfg then return false, "Unknown machine" end
	if Config.InTutorial(st.data) and (id ~= "excavator" or table.find(st.data.Machines or {}, id)) then return false, "🔒 Only the Mini Excavator in the tutorial" end]==])

-- the two new shops on the map
m = replaceOnce(m, [==[		elseif d.Name == "HirePrompt" then hookPrompt(d, "Hire")]==], [==[		elseif d.Name == "HirePrompt" then hookPrompt(d, "Hire")
		elseif d.Name == "GearPrompt" then hookPrompt(d, "ShopGear")
		elseif d.Name == "MachinesPrompt" then hookPrompt(d, "ShopMachines")]==])
assert(loadstring(m), "compile Main")

---------------------------------------------------------------------------------------------------------------------
-- HammerService: one Supply Crate in the tutorial, its hammer goes into your hand; no level-ups / trade-ups yet
---------------------------------------------------------------------------------------------------------------------
local hs = HS.Source
hs = replaceOnce(hs, [==[	if n ~= n or n < 1 or n > 10 or n % 1 ~= 0 then return false, "Pick 1 to 10 crates" end]==], [==[	if n ~= n or n < 1 or n > 10 or n % 1 ~= 0 then return false, "Pick 1 to 10 crates" end
	if Config.InTutorial and Config.InTutorial(d) then
		local owned = 0
		for k in pairs(d.Index or {}) do if Hammers.ById[k] then owned += 1 end end
		if crateId ~= "supply" or n ~= 1 or owned >= 2 or (d.Crates.supply or 0) > 0 then return false, "🔒 More crates after the tutorial" end
	end]==])
hs = replaceOnce(hs, [==[function actions.levelup(plr, st, id)
	local d = st.data]==], [==[function actions.levelup(plr, st, id)
	local d = st.data
	if Config.InTutorial and Config.InTutorial(d) then return false, "🔒 Level-ups open after the tutorial" end]==])
hs = replaceOnce(hs, [==[function actions.tradeup(plr, st, rarity, ids)
	local d = st.data]==], [==[function actions.tradeup(plr, st, rarity, ids)
	local d = st.data
	if Config.InTutorial and Config.InTutorial(d) then return false, "🔒 Trade-ups open after the tutorial" end]==])
hs = replaceOnce(hs, [==[	local it = M.Give(plr, st, key, "crate:" .. crateId)
	if not it then return false, "Hammer bag full" end]==], [==[	local it = M.Give(plr, st, key, "crate:" .. crateId)
	if not it then return false, "Hammer bag full" end
	-- TUTORIAL_V4: the hammer from your tutorial crate goes straight into your hand
	if Config.InTutorial and Config.InTutorial(d) then d.EquipHammer = (it == M.Best(d)) and nil or it.id end]==])
assert(loadstring(hs), "compile HammerService")

local vs = replaceOnce(VS.Source, [==[		if cfg.pass then return false, "This one is in the Store" end]==], [==[		if cfg.pass then return false, "This one is in the Store" end
		if Config.InTutorial and Config.InTutorial(st.data) then return false, "🔒 Cars open after the tutorial" end]==])
assert(loadstring(vs), "compile VehicleService")

local cs = replaceOnce(CS.Source, [==[		local fn = type(action) == "string" and actions[action]
		if not fn then return false, "Unknown action" end]==], [==[		local fn = type(action) == "string" and actions[action]
		if not fn then return false, "Unknown action" end
		if action ~= "get" and Config.InTutorial and Config.InTutorial(st.data) then return false, "🔒 Finish the tutorial first" end]==])
assert(loadstring(cs), "compile CompanyService")

---------------------------------------------------------------------------------------------------------------------
-- Client
---------------------------------------------------------------------------------------------------------------------
local s = Client.Source
s = replaceOnce(s, [==[	if name == "hire" then return at("HiringOffice") or Vector3.new(80, 3, -65) end]==], [==[	if name == "hire" then return at("HiringOffice") or Vector3.new(80, 3, -65) end
	if name == "gearshop" then return at("TrainingShop") or Vector3.new(-204, 3, 196) end
	if name == "machines" then return at("MachinesDepot") or Vector3.new(99, 3, 61) end]==])
s = replaceOnce(s, [==[shop = "Equipment Store", hire = "Hiring Office",]==], [==[shop = "Hammers Shop", gearshop = "Training Shop", machines = "Machines Depot", hire = "Hiring Office",]==])

-- the shops on the map open their own tab; in the tutorial only the tutorial's places open
s = replaceOnce(s, [==[R.OpenUI.OnClientEvent:Connect(function(name)
	if name == "Company" then _G.__CE_ShowCompany()
	elseif name == "Trade" then _G.__CE_ShowTrade()
	elseif name == "Garage" then _G.__CE_ShowGarage()
	elseif name == "Contracts" then showContracts()
	elseif name == "Shop" then showShop()
	elseif name == "Hire" then showHire()]==], [==[R.OpenUI.OnClientEvent:Connect(function(name)
	-- TUTORIAL_V4: in the tutorial only its own places open (the next one is where the arrow points)
	local step = player:GetAttribute("RoadStep") or 1
	if step <= (Config.TutorialSteps or 7) then
		if name == "Company" or name == "Garage" or name == "Property" or name == "Upgrades" or name == "Inventory" or name == "Rebirth" or name == "Locations" then
			toast("🔒 That opens after the tutorial — follow the arrow!", T.muted, 2.5)
			return
		end
		if name == "Contracts" and step < 2 then
			toast("🔨 First get a better hammer at the HAMMERS SHOP — follow the arrow!", T.accent, 3)
			return
		end
	end
	local Shop = _G.__CE_ShopUI
	if name == "Company" then _G.__CE_ShowCompany()
	elseif name == "Trade" then _G.__CE_ShowTrade()
	elseif name == "Garage" then _G.__CE_ShowGarage()
	elseif name == "Contracts" then showContracts()
	elseif name == "Shop" then if Shop then Shop.Show("hammers", nil, "hammers") else showShop() end
	elseif name == "ShopGear" then if Shop then Shop.Show("gear", nil, "gear") end
	elseif name == "ShopMachines" then if Shop then Shop.Show("machines", nil, "machines") end
	elseif name == "Hire" then if Shop then Shop.Show("crew", nil, "crew") else showHire() end]==])

s = replaceOnce(s, [==[		if d.index == (Config.TutorialSteps or 6) then
			task.delay(3, function() banner("🎓 TUTORIAL COMPLETE!", "JOBS and SHOP are unlocked — open them from anywhere!", T.accent) end)]==],
	[==[		if d.index == (Config.TutorialSteps or 6) then
			task.delay(3, function() banner("🎓 TUTORIAL COMPLETE!", "Every menu is unlocked — open them from anywhere!", T.accent) end)]==])

-- no arrow of its own to the Job Board: the tutorial's step points where it needs (and after the tutorial, nothing does)
s = replaceOnce(s, [==[	if not tpos and not cj and completed == 0 and player:GetAttribute("Loaded") then
		tpos, tlabel = placePos("board"), "JOB BOARD"
	end
]==], "")

-- the hints follow the tutorial's steps
s = replaceOnce(s, [==[	elseif not cj and completed == 0 then
		h = "📋 Follow the arrow to the JOB BOARD and take your first contract"]==], [==[	elseif not cj and completed == 0 and (player:GetAttribute("RoadStep") or 1) == 2 then
		h = "📋 Follow the arrow to the JOB BOARD and take the Repair Fence contract"]==])
s = replaceOnce(s, [==[	elseif not cj and completed >= 1 and (player:GetAttribute("RoadStep") or 1) <= (Config.TutorialSteps or 6)
		and Config.Road[player:GetAttribute("RoadStep") or 1] and Config.Road[player:GetAttribute("RoadStep") or 1].place ~= "site" then
		local tp = Config.Road[player:GetAttribute("RoadStep") or 1].place
		h = tp == "inventory" and "📦 Open your INVENTORY (CRATES tab) and open your welcome crate: a new hammer is inside!"
			or tp == "hire" and "👷 Walk to the HIRING OFFICE and hire your first worker — follow the arrow"
			or tp == "home" and "🏠 Walk to YOUR PROPERTY in Maple Grove — follow the arrow"
			or tp == "gym" and "💪 Last step: walk to the TRAINING YARD — follow the arrow"
			or ""]==], [==[	elseif not cj and (player:GetAttribute("RoadStep") or 1) <= (Config.TutorialSteps or 7)
		and Config.Road[player:GetAttribute("RoadStep") or 1] and Config.Road[player:GetAttribute("RoadStep") or 1].place ~= "site" then
		local tp = Config.Road[player:GetAttribute("RoadStep") or 1].place
		h = tp == "shop" and ((player:GetAttribute("CrateTotal") or 0) > 0 and "📦 Open your crate at the HAMMERS SHOP: a better hammer is inside!"
				or "🔨 Follow the arrow to the HAMMERS SHOP and buy a Supply Crate")
			or tp == "gearshop" and "🧤 Follow the arrow to the TRAINING SHOP and buy Work Gloves"
			or tp == "gym" and "💪 Go into the TRAINING YARD, stand on a station and click to train"
			or tp == "machines" and "🚜 Follow the arrow to the MACHINES DEPOT and buy the Mini Excavator"
			or tp == "hire" and "👷 Follow the arrow to the HIRING OFFICE and hire a Laborer"
			or tp == "home" and "🏠 Last step: walk to YOUR PROPERTY in Maple Grove — follow the arrow"
			or ""]==])
assert(loadstring(s), "compile Client")

ConfigM.Source = cfg
Main.Source = m
HS.Source = hs
VS.Source = vs
CS.Source = cs
Client.Source = s
return "tutorial v4: Config, Main, HammerService, VehicleService, CompanyService, Client"
