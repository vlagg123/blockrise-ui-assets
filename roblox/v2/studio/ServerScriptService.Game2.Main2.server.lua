-- BlockRise Empire 2.0 - server entry point: players, saves (session lock, spaced writes: ported from v1), the
-- city (City), the crew (Crew2), hammers and crates (v1 HammerService), income every second.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")
local MarketplaceService = game:GetService("MarketplaceService")
local ProximityPromptService = game:GetService("ProximityPromptService")

local Config = require(ReplicatedStorage.Shared.Config)
local C = require(ReplicatedStorage.Shared.Config2)
local Hammers = require(ReplicatedStorage.Shared.Hammers)
local HammerService = require(game.ServerScriptService.Game.HammerService)
local City = require(script.Parent.City)
local Crew = require(script.Parent.Crew2)
local Store = require(script.Parent.Store)
local Gifts = require(script.Parent.Gifts)
local Leaderboard = require(script.Parent.Leaderboard)

-- 2.0 has its own contextual tutorial: the v1 one (Road steps) never locks crates or level-ups here
Config.InTutorial = function() return false end

-- Remotes ------------------------------------------------------------------------------------------
local Remotes = ReplicatedStorage:FindFirstChild("Remotes") or Instance.new("Folder")
Remotes.Name = "Remotes"
Remotes.Parent = ReplicatedStorage
local function remote(class, name)
	local r = Remotes:FindFirstChild(name) or Instance.new(class)
	r.Name = name
	r.Parent = Remotes
	return r
end
local FeedbackRE = remote("RemoteEvent", "Feedback")
local CityRF = remote("RemoteFunction", "City")
local TapRE = remote("RemoteEvent", "CityTap")

-- BUILD_V1: the client draws the building cards itself from the live game's blueprints (a copy it can require)
do
	local old = ReplicatedStorage:FindFirstChild("BuildingPreviews")
	if old then old:Destroy() end
	local bp = ReplicatedStorage.Shared:FindFirstChild("Blueprints")
	if bp then bp:Destroy() end
	bp = script.Parent.Blueprints2:Clone()
	bp.Name = "Blueprints"
	bp.Parent = ReplicatedStorage.Shared
end

-- Data -------------------------------------------------------------------------------------------------
-- (the same store as v1: never a progress reset unless the owner asks; 2.0 adds its own fields)
local DATA_STORE_NAME = "BlockRise_v6"
local store
pcall(function() store = DataStoreService:GetDataStore(DATA_STORE_NAME) end)

local function defaultData()
	return { Money = 0, Gems = 0, Rebirths = 0, Stars = 0, Earned = 0, Hammers = {}, Crates = {}, HammerV = 1, Boosts = {},
		Receipts = {}, Funnel = {}, Spin = { last = 0, extra = 0 }, Codes = {}, Vehicles = {}, DataVersion = 3, V2 = 1 }
end

local S = {}

local LOCK_TIMEOUT = 150
local function withRetry(fn, tries)
	local lastErr
	for i = 1, tries or 3 do
		local ok, res = pcall(fn)
		if ok then return true, res end
		lastErr = res
		if i < (tries or 3) then task.wait(i * 1.5) end
	end
	return false, lastErr
end
local function lockedByOther(old)
	local lock = type(old) == "table" and old._lock
	return lock and lock.job ~= game.JobId and os.time() - (lock.t or 0) < LOCK_TIMEOUT
end

-- v1 profiles: the old run (contracts, house, company) is left as it is; 2.0 starts the city fresh and keeps
-- hammers, crates, Gems, passes, cars, spins and boosts. (The welcome pack for veterans comes with the launch.)
local function migrate(d)
	if d.V2 ~= 1 then
		d.V2 = 1
		d.V1Money = d.Money
		d.V1Rebirths = d.Rebirths
		d.Money = 0
		d.Rebirths = 0
		d.City = nil
	end
	d.Money = tonumber(d.Money) or 0
	d.Gems = math.max(0, math.floor(tonumber(d.Gems) or 0))
	d.Rebirths = math.max(0, math.floor(tonumber(d.Rebirths) or 0))
	d.Boosts = type(d.Boosts) == "table" and d.Boosts or {}
	City.Sanitize(d)
	HammerService.Sanitize(d)
end

local function loadData(plr)
	local d = defaultData()
	if not store then migrate(d) return d, false end
	local key = "u_" .. plr.UserId
	for attempt = 1, 6 do
		local blocked = false
		local force = attempt == 6
		local ok, res = withRetry(function()
			return store:UpdateAsync(key, function(old)
				if not force and lockedByOther(old) then blocked = true return nil end
				old = type(old) == "table" and old or {}
				old._lock = { job = game.JobId, t = os.time() }
				return old
			end)
		end, 3)
		if not ok then warn("Data load failed:", res) migrate(d) return d, false end
		if not blocked then
			if type(res) == "table" then for k, v in pairs(res) do d[k] = v end end
			d._lock = nil
			migrate(d)
			return d, true
		end
		if not plr.Parent then migrate(d) return d, false end
		task.wait(6.5)
	end
	migrate(d)
	return d, false
end

local function writeData(plr, release)
	local st = S[plr]
	if not st or not store or not st.loaded then return false end
	st.lastWrite = os.clock()
	st.data.City.lastSeen = os.time()
	local snapshot = table.clone(st.data)
	local written = false
	local ok, err = withRetry(function()
		store:UpdateAsync("u_" .. plr.UserId, function(old)
			if lockedByOther(old) then return nil end
			snapshot._lock = (not release) and { job = game.JobId, t = os.time() } or nil
			written = true
			return snapshot
		end)
	end, 3)
	if not ok then warn("Data save failed:", err) end
	return ok and written
end

local SAVE_GAP = 6.5
local function saveData(plr, release, force)
	local st = S[plr]
	if not st or not store or not st.loaded then return false end
	if st.released then return true end
	if release or force then
		while st.writing do task.wait(0.2) end
		local waitFor = SAVE_GAP - (os.clock() - (st.lastWrite or -100))
		if waitFor > 0 then task.wait(waitFor) end
		while st.writing do task.wait(0.2) end
		st.writing = true
		local ok = writeData(plr, release)
		st.writing = false
		return ok
	end
	if st.writing or os.clock() - (st.lastWrite or -100) < SAVE_GAP then
		if not st.deferredSave then
			st.deferredSave = true
			task.delay(math.max(0.5, SAVE_GAP - (os.clock() - (st.lastWrite or -100))), function()
				st.deferredSave = false
				if S[plr] == st then saveData(plr) end
			end)
		end
		return true
	end
	st.writing = true
	local ok = writeData(plr, false)
	st.writing = false
	return ok
end
local function saveSoon(plr)
	local st = S[plr]
	if not st or st.saveQueued then return end
	st.saveQueued = true
	task.delay(8, function()
		if S[plr] == st then st.saveQueued = false saveData(plr) end
	end)
end

local function feedback(plr, kind, payload)
	if plr and plr.Parent then FeedbackRE:FireClient(plr, kind, payload or {}) end
end

-- Passes ------------------------------------------------------------------------------------------------
local function hasPass(st, key) return st.passes and st.passes[key] == true end
local function checkPasses(plr)
	local st = S[plr]
	if not st then return end
	st.passes = st.passes or {}
	local d = st.data
	if type(d.AdminPasses) == "table" then for k, on in pairs(d.AdminPasses) do if on == true then st.passes[k] = true end end end
	-- bought in game (Roblox can take a while to report a fresh purchase)
	if type(d.OwnedPasses) == "table" then for k, on in pairs(d.OwnedPasses) do if on == true then st.passes[k] = true end end end
	for _, p in ipairs(Config.Store.passes) do
		if p.id and p.id > 0 then
			local ok, owns = withRetry(function() return MarketplaceService:UserOwnsGamePassAsync(plr.UserId, p.id) end, 2)
			if S[plr] ~= st then return end
			if ok and owns then st.passes[p.key] = true end
		end
	end
	for _, p in ipairs(Config.Store.passes) do plr:SetAttribute("Pass_" .. p.key, st.passes[p.key] == true) end
end

-- Hammers & crew -------------------------------------------------------------------------------------------
-- the hammers sorted best first (power, then rarity, then level)
local function sortedHammers(d)
	local list = table.clone(d.Hammers or {})
	table.sort(list, function(a, b)
		local pa, pb = Hammers.Power(a.k, a.lv), Hammers.Power(b.k, b.lv)
		if math.abs(pa - pb) > 1e-6 then return pa > pb end
		return (a.lv or 1) > (b.lv or 1)
	end)
	return list
end
local function workerCount(st)
	local d = st.data
	return C.StartWorkers + (d.City.hires or 0) + math.max(0, math.floor(tonumber(d.GemCrewSlots) or 0)) + (hasPass(st, "bigcrew") and 3 or 0)
end
-- you hold the best hammer; workers 1..n the next ones (a worker without one has a plain Rusty)
local function crewHammers(st)
	local list = sortedHammers(st.data)
	local keys = {}
	for i = 1, workerCount(st) do
		local it = list[i + 1]
		keys[i] = it and it.k or "rusty"
	end
	return keys, list
end
local function crewPower(st)
	local keys, list = crewHammers(st)
	local you = list[1]
	local p = you and Hammers.Power(you.k, you.lv) or 1
	for i, k in ipairs(keys) do
		local it = list[i + 1]
		p += it and Hammers.Power(it.k, it.lv) or 1
	end
	-- the hammer in your hand's crew perk, Rush Crew (x2)
	local m = 1 + (you and Hammers.Perk(you.k, "crew") or 0)
	if (st.data.RushCrewUntil or 0) > os.time() then m *= 2 end
	return p * m
end
local function tapPower(st)
	local list = sortedHammers(st.data)
	local you = list[1]
	return (you and Hammers.Power(you.k, you.lv) or 1) * (1 + (you and Hammers.Perk(you.k, "power") or 0))
end
local function cashMult(st)
	local m = 1
	if hasPass(st, "vip") then m += 0.2 end
	m += math.min(0.3, (st.friendCount or 0) * 0.1)
	local list = sortedHammers(st.data)
	if list[1] then m += Hammers.Perk(list[1].k, "cash") end
	if hasPass(st, "cash2x") then m *= 2 end
	if Config.Boosts and Config.Boosts.cash and (st.data.Boosts.cash or 0) > 0 then m *= Config.Boosts.cash.mult or 2 end
	return m
end

-- the player's own best hammer in their right hand (cosmetic; taps play its swing on the client)
local function holdHammer(plr)
	local st = S[plr]
	local char = plr.Character
	if not st or not char then return end
	local list = sortedHammers(st.data)
	local key = list[1] and list[1].k or "rusty"
	if char:GetAttribute("HammerKey") == key and char:FindFirstChild("HeldHammer") then return end
	char:SetAttribute("HammerKey", key)
	Crew.GiveHammerTo(char, key)
	plr:SetAttribute("HammerKey", key)
end

-- Money ------------------------------------------------------------------------------------------------
local function sync(plr)
	local st = S[plr]
	if not st then return end
	local d = st.data
	plr:SetAttribute("Money", d.Money)
	plr:SetAttribute("Gems", d.Gems or 0)
	plr:SetAttribute("Rebirths", d.Rebirths or 0)
	plr:SetAttribute("Stars", d.Stars or 0)
	plr:SetAttribute("Workers", workerCount(st))
	plr:SetAttribute("CrewPower", crewPower(st))
	plr:SetAttribute("Cap", C.Cap(d.Rebirths))
	if d.Hammers then HammerService.Publish(plr) end
	City.Publish(plr, st)
	local ls = plr:FindFirstChild("leaderstats")
	if ls then
		ls.Cash.Value = math.floor(math.min(d.Money, 9e15))
		ls.Rebirths.Value = d.Rebirths or 0
	end
end

local function addMoney(plr, amount, reason)
	local st = S[plr]
	if not st or amount == 0 then return end
	if type(amount) ~= "number" or amount ~= amount or math.abs(amount) == math.huge then return end
	st.data.Money += amount
	if amount > 0 then st.data.Earned = (st.data.Earned or 0) + amount end
	plr:SetAttribute("Money", st.data.Money)
	local ls = plr:FindFirstChild("leaderstats")
	if ls then ls.Cash.Value = math.floor(math.min(st.data.Money, 9e15)) end
end
local function addGems(plr, amount, reason)
	local st = S[plr]
	if not st or amount == 0 then return end
	st.data.Gems = math.max(0, (st.data.Gems or 0) + amount)
	plr:SetAttribute("Gems", st.data.Gems)
	feedback(plr, "Gems", { amount = amount, reason = reason })
end

-- Init the modules ----------------------------------------------------------------------------------------
local ctx = {
	S = S, sync = sync, addMoney = addMoney, addGems = addGems, feedback = feedback, saveSoon = saveSoon, saveData = saveData,
	remote = remote, crewPower = crewPower, tapPower = tapPower, cashMult = cashMult, workerCount = workerCount, crewHammers = crewHammers,
	giveTool = function(plr) holdHammer(plr) local st = S[plr] if st then Crew.Sync(plr, st) end end,
	zoneOf = function() return "town" end,
	luck = function(st)
		local l = 1
		if hasPass(st, "luck") then l += 1 end
		if hasPass(st, "ultraluck") then l += 2 end
		return math.min(Hammers.LuckCap or 8, l)
	end,
	hunter = function(st) return hasPass(st, "hunter") and 2 or 1 end,
	crewChanged = function(plr, st) Crew.Sync(plr, st) sync(plr) end,
}
ctx.HammerService = HammerService
ctx.incomeOf = function(st) return City.Income(st) end
City.Init(ctx)
Crew.Init(ctx)
HammerService.Init(ctx)
Store.Init(ctx)
Gifts.Init(ctx)
Leaderboard.Init(ctx)

-- Players -------------------------------------------------------------------------------------------------
local function onCharacter(plr, char)
	task.wait(0.2)
	holdHammer(plr)
	-- you (re)spawn in your own city, at its gate, looking down your street (the plaza is a walk or a MENU tap away)
	local st = S[plr]
	if st and st.k and char:WaitForChild("HumanoidRootPart", 5) and char.Parent then
		char:PivotTo(City.HomeCF(st))
	end
end

local function onPlayerAdded(plr)
	local ls = Instance.new("Folder")
	ls.Name = "leaderstats"
	local cash = Instance.new("NumberValue") cash.Name = "Cash" cash.Parent = ls
	local reb = Instance.new("IntValue") reb.Name = "Rebirths" reb.Parent = ls
	ls.Parent = plr
	local d, ok = loadData(plr)
	if not plr.Parent then return end
	local st = { data = d, loaded = ok or RunService:IsStudio() and false, passes = {} }
	st.loaded = ok
	S[plr] = st
	Gifts.Join(plr)
	plr:SetAttribute("Loaded", true)
	checkPasses(plr)
	Store.OnJoin(plr, st)
	-- offline earnings (and the crew kept building)
	local earned, away = City.Offline(plr, st)
	if not City.Assign(plr, st) then plr:Kick("The server is full of cities, please join another one") return end
	sync(plr)
	Crew.Sync(plr, st)
	if earned > 0 then
		d.OfflineLast = earned
		d.OfflineLastDoubled = false
		addMoney(plr, earned, "Offline")
		task.delay(4, function() feedback(plr, "Offline", { amount = earned, away = away }) end)
	end
	plr.CharacterAdded:Connect(function(char) onCharacter(plr, char) end)
	if plr.Character then task.spawn(onCharacter, plr, plr.Character) end
end
Players.PlayerAdded:Connect(onPlayerAdded)
for _, p in ipairs(Players:GetPlayers()) do task.spawn(onPlayerAdded, p) end

Players.PlayerRemoving:Connect(function(plr)
	local st = S[plr]
	if not st then return end
	Crew.Remove(plr)
	Gifts.Leave(plr)
	Leaderboard.Leave(plr)
	City.Release(plr, st)
	saveData(plr, true)
	S[plr] = nil
end)

game:BindToClose(function()
	local list = {}
	for plr in pairs(S) do table.insert(list, plr) end
	for _, plr in ipairs(list) do task.spawn(saveData, plr, true) end
	task.wait(RunService:IsStudio() and 1 or 8)
end)

-- Actions ----------------------------------------------------------------------------------------------------
local actions = {}
function actions.order(plr, st, lot) return City.Order(plr, st, lot) end
function actions.buyBlock(plr, st, key) return City.BuyBlock(plr, st, key) end
function actions.style(plr, st, lot, s) return City.SetStyle(plr, st, lot, s) end
function actions.rebirth(plr, st) return City.Rebirth(plr, st) end
function actions.hire(plr, st) return City.Hire(plr, st) end
function actions.home(plr, st)
	local char = plr.Character
	if char and st.k then char:PivotTo(City.HomeCF(st)) end
	return true
end
CityRF.OnServerInvoke = function(plr, action, a, b)
	local st = S[plr]
	if not st then return false, "Loading..." end
	local fn = type(action) == "string" and actions[action]
	if not fn then return false, "Unknown action" end
	local now = os.clock()
	if now - (st.lastAction or 0) < 0.08 then return false, "Slow down!" end
	st.lastAction = now
	local ok, r1, r2 = pcall(fn, plr, st, a, b)
	if not ok then warn("City action error:", action, r1) return false, "Something went wrong" end
	return r1, r2
end
TapRE.OnServerEvent:Connect(function(plr, lot)
	local st = S[plr]
	if st and type(lot) == "number" then City.Tap(plr, st, math.floor(lot)) end
end)
-- the LAND FOR SALE boards
ProximityPromptService.PromptTriggered:Connect(function(prompt, plr)
	local st = S[plr]
	if not st or prompt.Name ~= "Buy" then return end
	local board = prompt.Parent
	local key = board and board:GetAttribute("Block")
	local m = board and board.Parent
	if not key or not m or m:GetAttribute("District") ~= st.k then
		feedback(plr, "Error", { text = "That isn't your city" })
		return
	end
	local ok, err = City.BuyBlock(plr, st, key)
	if not ok then feedback(plr, "Error", { text = err }) end
end)

-- Loops ------------------------------------------------------------------------------------------------------
-- income every second
task.spawn(function()
	while true do
		task.wait(1)
		for plr, st in pairs(S) do
			if st.k then
				local inc = City.Income(st)
				if inc > 0 then addMoney(plr, inc, "Income") end
				plr:SetAttribute("Income", inc)
				pcall(City.PublishRates, st) -- RATE_TAGS: the "+$X/s" over each building
				local rs = City.RebirthState(st)
				plr:SetAttribute("RebirthReady", rs.ready == true and st.data.Money >= (rs.cost or math.huge))
				-- timed boosts run down
				for k, v in pairs(st.data.Boosts) do if type(v) == "number" and v > 0 then st.data.Boosts[k] = math.max(0, v - 1) end end
			end
		end
	end
end)
-- building: 10 times a second; the crew 5 times
task.spawn(function()
	local n = 0
	while true do
		local dt = task.wait(0.1)
		n += 1
		for plr, st in pairs(S) do
			if st.k then
				local ok, err = pcall(City.Step, plr, st, dt)
				if not ok then warn("City.Step", err) end
				if n % 2 == 0 then
					local ok2, err2 = pcall(Crew.Update, plr, st, dt * 2)
					if not ok2 then warn("Crew.Update", err2) end
				end
			end
		end
	end
end)
-- Studio test hooks (execute_luau in the Server context)
if RunService:IsStudio() then
	_G.BR2 = { S = S, City = City, Crew = Crew, actions = actions, addMoney = addMoney, sync = sync }
	-- (the MCP Server context has its own _G: a BindableFunction reaches this script's state)
	local dbg = game:GetService("ServerStorage"):FindFirstChild("BR2Debug") or Instance.new("BindableFunction")
	dbg.Name = "BR2Debug"
	dbg.Parent = game:GetService("ServerStorage")
	dbg.OnInvoke = function(cmd, a, b, c2)
		local plr = Players:GetPlayers()[1]
		local st = plr and S[plr]
		if not st then return "no player state" end
		if cmd == "money" then addMoney(plr, a, "debug") sync(plr) return st.data.Money
		elseif cmd == "set" then st.data[a] = b sync(plr) return true
		elseif cmd == "get" then return st.data[a]
		elseif cmd == "city" then return game:GetService("HttpService"):JSONEncode(st.data.City)
		elseif cmd == "k" then return st.k
		elseif cmd == "finish" then for _, o in ipairs(st.data.City.queue) do o.done = o.need o.demo = 0 end return true
		elseif actions[cmd] then return actions[cmd](plr, st, a, b)
		end
		return "unknown"
	end
end

-- autosave
task.spawn(function()
	while true do
		task.wait(60)
		for plr in pairs(S) do task.spawn(saveData, plr) end
	end
end)
