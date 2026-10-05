-- one-off patch (run in Edit): the owner's Admin panel, server side.
-- SECURITY
--  * only the UserIds in ADMINS (the owner's account, game.CreatorId 4285033131) ever get the panel
--  * the panel (ScreenGui + its script) lives in ServerStorage: clients never receive it. The server copies it into the
--    owner's PlayerGui only (a PlayerGui replicates to its own player only), with a fresh RemoteFunction inside it, so no
--    other client has the remote, the code, or the button
--  * every call is checked again on the server (the caller must be that same admin, still in ADMINS), every value is
--    type-checked and clamped, unknown actions / keys are refused, calls are rate limited and logged in the server output
--  * admin gifts don't count as earned money (leaderboards, rebirth progress and analytics stay honest)
-- Passes given from the panel are saved in data.AdminPasses and count as owned on every join.
local function replaceOnce(src, old, new)
	local a, b = src:find(old, 1, true)
	assert(a, "not found: " .. old:sub(1, 80))
	assert(not src:find(old, b + 1, true), "found twice: " .. old:sub(1, 80))
	return src:sub(1, a - 1) .. new .. src:sub(b + 1)
end
local Main = game.ServerScriptService.Game.Main
local s = Main.Source
if s:find("ADMIN PANEL (owner only)", 1, true) then return "already patched" end

-- passes given from the panel count as owned on every join
s = replaceOnce(s, [[	d.OwnedPasses = type(d.OwnedPasses) == "table" and d.OwnedPasses or {}
	local failed = false
]], [[	d.OwnedPasses = type(d.OwnedPasses) == "table" and d.OwnedPasses or {}
	local failed = false
	-- passes the owner gave from the Admin panel (free) are owned like bought ones
	if type(d.AdminPasses) == "table" then
		for k, on in pairs(d.AdminPasses) do if on == true then st.passes[k] = true end end
	end
]])

s = replaceOnce(s, [[print("[BlockRise Empire] server ready — " .. Config.Version)]], [==[-- ADMIN PANEL (owner only) ------------------------------------------------------------------
-- (its own function: Main is close to Luau's 200 locals limit)
;(function()
	local ADMINS = { [4285033131] = true } -- the owner's Roblox account (game.CreatorId). Nobody else, ever.
	local PlayersS = game:GetService("Players")
	local ServerStorageS = game:GetService("ServerStorage")
	local CompanyCfg = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Company"))
	local MAXN = 1e18

	local function isAdmin(plr)
		return typeof(plr) == "Instance" and plr:IsA("Player") and plr.Parent == PlayersS and ADMINS[plr.UserId] == true
	end
	local function num(v, lo, hi)
		if type(v) ~= "number" or v ~= v or v == math.huge or v == -math.huge then return nil end
		return math.clamp(v, lo, hi)
	end
	local function int(v, lo, hi)
		local n = num(v, lo, hi)
		return n and math.floor(n + 0.5)
	end
	local function passByKey(k)
		if type(k) ~= "string" then return nil end
		for _, p in ipairs(Config.Store.passes) do if p.key == k then return p end end
	end
	local function fmt(n) return Config.FormatNum(math.floor(n)) end

	-- numbers the panel can add to / set: { data field, lowest, highest, whole numbers?, after }
	local NUM = {
		money = { "Money", 0, MAXN, false },
		gems = { "Gems", 0, 1e12, true },
		strength = { "Strength", 0, MAXN, false },
		rep = { "Rep", 0, 1e12, true },
		stars = { "Stars", 0, 1e9, true, "rebirth" },
		level = { "Level", 1, 100000, true },
		rebirths = { "Rebirths", 0, 100000, true, "rebirth" },
	}

	local ACT = {}
	for key, f in pairs(NUM) do
		ACT[key] = function(plr, st, v)
			if type(v) ~= "table" or (v.mode ~= "add" and v.mode ~= "set") then return false, "bad request" end
			local n = num(v.n, -MAXN, MAXN)
			if not n then return false, "bad amount" end
			if f[4] then n = math.floor(n + 0.5) end
			local d = st.data
			local before = tonumber(d[f[1]]) or 0
			local after = math.clamp(v.mode == "set" and n or before + n, f[2], f[3])
			if f[4] then after = math.floor(after) end
			d[f[1]] = after
			if key == "level" then d.XP = 0 end
			sync(plr)
			if f[5] == "rebirth" then RebirthService.Publish(plr) end
			if key == "money" and after ~= before then feedback(plr, "Money", { amount = after - before, reason = "🛠️ Admin" }) end
			if key == "gems" and after ~= before then feedback(plr, "Gems", { amount = after - before, reason = "Admin" }) end
			return true, f[1] .. ": " .. fmt(before) .. " → " .. fmt(after)
		end
	end

	function ACT.tool(plr, st, v)
		local n = int(v, 1, #Config.Tools)
		if not n then return false, "bad tier" end
		st.data.ToolTier = n
		if type(st.data.EquipTool) == "number" and st.data.EquipTool > n then st.data.EquipTool = nil end
		giveTool(plr)
		sync(plr)
		return true, "Hammer → " .. Config.Tools[n].name
	end
	function ACT.gear(plr, st, v)
		local n = int(v, 1, #Config.TrainingGear)
		if not n then return false, "bad tier" end
		st.data.GearTier = n
		sync(plr)
		return true, "Training gear → " .. tostring(Config.TrainingGear[n].name or n)
	end
	function ACT.pass(plr, st, v)
		if type(v) ~= "table" or type(v.on) ~= "boolean" then return false, "bad request" end
		local p = passByKey(v.key)
		if not p then return false, "unknown pass" end
		local d = st.data
		d.AdminPasses = type(d.AdminPasses) == "table" and d.AdminPasses or {}
		d.OwnedPasses = type(d.OwnedPasses) == "table" and d.OwnedPasses or {}
		st.passes = st.passes or {}
		if v.on then
			st.passes[p.key] = true
			d.AdminPasses[p.key] = true
			if p.key == Config.StormHammer.pass then
				d.EquipTool = nil
				plr:SetAttribute("EquipTool", "")
				st.stormGiven = false
				feedback(plr, "Purchased", { name = p.name, kind = "pass" })
			end
		else
			st.passes[p.key] = nil
			d.AdminPasses[p.key] = nil
			d.OwnedPasses[p.key] = nil -- (a pass really bought on Roblox comes back on the next join)
			if p.key == "vip" then
				local head = plr.Character and plr.Character:FindFirstChild("Head")
				if head and head:FindFirstChild("VipTag") then head.VipTag:Destroy() end
			end
		end
		applyPasses(plr)
		sync(plr)
		return true, p.name .. (v.on and " given (free)" or " removed")
	end
	function ACT.boost(plr, st, v)
		if type(v) ~= "table" or type(v.key) ~= "string" or not Config.Boosts[v.key] then return false, "unknown boost" end
		local secs = int(v.secs, 60, 7 * 86400)
		if not secs then return false, "bad time" end
		addBoost(plr, v.key, secs)
		return true, (Config.Boosts[v.key].name or v.key) .. " +" .. math.floor(secs / 60) .. " min"
	end
	function ACT.rush(plr, st, v)
		local secs = int(v, 60, 7 * 86400)
		if not secs then return false, "bad time" end
		st.data.RushCrewUntil = math.max(os.time(), tonumber(st.data.RushCrewUntil) or 0) + secs
		syncRushCrew(plr)
		return true, "Rush Crew +" .. math.floor(secs / 60) .. " min"
	end
	function ACT.spins(plr, st, v)
		local n = int(v, 1, 10000)
		if not n then return false, "bad amount" end
		st.data.Spin = type(st.data.Spin) == "table" and st.data.Spin or { last = 0, extra = 0 }
		st.data.Spin.extra = (tonumber(st.data.Spin.extra) or 0) + n
		plr:SetAttribute("SpinExtra", st.data.Spin.extra)
		return true, "+" .. n .. " spins (" .. st.data.Spin.extra .. " waiting)"
	end
	local function items(kind, byId)
		return function(plr, st, v)
			if type(v) ~= "table" or type(v.id) ~= "string" or not byId[v.id] then return false, "unknown item" end
			local n = int(v.n, -1e9, 1e9)
			if not n then return false, "bad amount" end
			local it = st.data.Items
			if type(it) ~= "table" then return false, "no inventory yet" end
			it[kind] = type(it[kind]) == "table" and it[kind] or {}
			it[kind][v.id] = math.max(0, (tonumber(it[kind][v.id]) or 0) + n)
			CompanyService.Publish(plr)
			return true, v.id .. " → " .. it[kind][v.id]
		end
	end
	ACT.mat = items("mats", CompanyCfg.MaterialById)
	ACT.bp = items("bps", CompanyCfg.BlueprintById)
	function ACT.vehicles(plr, st)
		st.data.Vehicles = type(st.data.Vehicles) == "table" and st.data.Vehicles or {}
		local n = 0
		for _, veh in ipairs(Config.Vehicles or {}) do
			if veh.id and not st.data.Vehicles[veh.id] then st.data.Vehicles[veh.id] = true; n += 1 end
		end
		sync(plr)
		pcall(function() if VehicleService.Publish then VehicleService.Publish(plr) end end)
		return true, n .. " cars unlocked"
	end
	function ACT.finish(plr, st)
		local job = st.contractJob
		if not job then return false, "no contract in progress" end
		job:AddWork(job.totalWork, plr.UserId)
		return true, "contract finished"
	end
	function ACT.tutorial(plr, st)
		st.data.Road = math.max(tonumber(st.data.Road) or 1, (Config.TutorialSteps or 6) + 1)
		sync(plr)
		return true, "tutorial done"
	end
	local function root(p) return p.Character and p.Character:FindFirstChild("HumanoidRootPart") end
	function ACT.teleport(plr, st, v, admin)
		local a, b = root(admin), root(plr)
		if not (a and b) then return false, "no character" end
		a.CFrame = b.CFrame * CFrame.new(0, 0, 5)
		return true, "teleported to " .. plr.Name
	end
	function ACT.bring(plr, st, v, admin)
		local a, b = root(admin), root(plr)
		if not (a and b) then return false, "no character" end
		b.CFrame = a.CFrame * CFrame.new(0, 0, -5)
		return true, plr.Name .. " brought to you"
	end

	-- saves soon after a change (one save for a burst of clicks)
	local function saveSoon(plr, st)
		if st.adminSaveQueued then return end
		st.adminSaveQueued = true
		task.delay(6, function()
			st.adminSaveQueued = false
			if S[plr] == st then pcall(saveData, plr) end
		end)
	end

	local function attach(plr)
		if not isAdmin(plr) then return end
		local template = ServerStorageS:FindFirstChild("AdminPanel")
		if not template then warn("[Admin] ServerStorage.AdminPanel is missing") return end
		local pg = plr:WaitForChild("PlayerGui", 60)
		if not pg or not isAdmin(plr) or pg:FindFirstChild("AdminPanel") then return end
		local gui = template:Clone()
		local rf = Instance.new("RemoteFunction")
		rf.Name = "AdminRF"
		local window, count = os.clock(), 0
		rf.OnServerInvoke = function(caller, action, targetId, v)
			-- the caller must be this admin (the remote lives in their PlayerGui only), and still an admin
			if caller ~= plr or not isAdmin(caller) then
				warn("[Admin] refused a call from " .. tostring(caller))
				return false, "not allowed"
			end
			if os.clock() - window > 1 then window, count = os.clock(), 0 end
			count += 1
			if count > 15 then return false, "slow down" end
			if type(action) ~= "string" or not ACT[action] then return false, "unknown action" end
			local target = PlayersS:GetPlayerByUserId(tonumber(targetId) or 0)
			if not target then return false, "player not in this server" end
			local st = S[target]
			if not st or not st.data then return false, "player still loading" end
			local ok, res, msg = pcall(ACT[action], target, st, v, caller)
			if not ok then
				warn("[Admin] " .. action .. " failed: " .. tostring(res))
				return false, "error: " .. tostring(res)
			end
			if res then
				print(string.format("[Admin] %s → %s: %s (%s)", caller.Name, target.Name, action, tostring(msg)))
				saveSoon(target, st)
			end
			return res, msg
		end
		rf.Parent = gui
		gui.Parent = pg
		print("[Admin] panel given to " .. plr.Name)
	end
	PlayersS.PlayerAdded:Connect(attach)
	for _, p in ipairs(PlayersS:GetPlayers()) do task.spawn(attach, p) end
end)()

print("[BlockRise Empire] server ready — " .. Config.Version)]==])

assert(loadstring(s), "Main compile")
Main.Source = s
return "admin server patched"
