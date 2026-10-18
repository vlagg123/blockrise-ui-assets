-- BlockRise 2.0 - free gifts (GIFTS_V1, 2026-10-18): playtime gifts (8 per visit: the longer you stay, the better
-- they get) and a daily reward (a 7-day streak, one claim per UTC day). Cash rewards are minutes of your city's
-- income right now (at least a little for a brand new city). Remote: Remotes.Gifts (RemoteFunction):
--   "state"  -> { elapsed, list = { { t, kind, amount, crate, claimed } }, daily = { day, claimed, nextIn, list } }
--   "claim", i -> true, reward   |   "daily" -> true, reward
local Hammers = require(game:GetService("ReplicatedStorage").Shared.Hammers)
local G = {}
local ctx
local sessions = {} -- player -> { start = os.clock(), claimed = {} }
local refresh

G.Playtime = {
	{ t = 60, kind = "cash", min = 2 },
	{ t = 180, kind = "gems", n = 5 },
	{ t = 300, kind = "cash", min = 5 },
	{ t = 480, kind = "crate", crate = "supply" },
	{ t = 720, kind = "cash", min = 10 },
	{ t = 960, kind = "gems", n = 10 },
	{ t = 1320, kind = "cash", min = 20 },
	{ t = 1800, kind = "crate", crate = "builder" },
}
G.Daily = {
	{ kind = "cash", min = 10 },
	{ kind = "gems", n = 15 },
	{ kind = "cash", min = 20 },
	{ kind = "crate", crate = "supply" },
	{ kind = "gems", n = 25 },
	{ kind = "cash", min = 40 },
	{ kind = "crate", crate = "builder" },
}

local function today() return math.floor(os.time() / 86400) end

-- what a reward is worth for this player right now
local function amountOf(st, r)
	if r.kind == "cash" then
		local perMin = (ctx.incomeOf and ctx.incomeOf(st) or 0) * 60
		return math.max(100 * r.min, math.floor(perMin * r.min))
	elseif r.kind == "gems" then
		return r.n
	end
	return 1
end
local function crateName(id)
	local c = Hammers.CrateById and Hammers.CrateById[id]
	return c and c.name or id
end
local function view(st, r)
	return { kind = r.kind, amount = amountOf(st, r), crate = r.crate, crateName = r.crate and crateName(r.crate) or nil, min = r.min }
end

local function grant(plr, st, r)
	local a = amountOf(st, r)
	if r.kind == "cash" then
		ctx.addMoney(plr, a, "Gift")
	elseif r.kind == "gems" then
		ctx.addGems(plr, a, "Gift")
	elseif r.kind == "crate" and ctx.HammerService then
		ctx.HammerService.AddCrate(plr, st, r.crate, 1, "silent")
	end
	ctx.saveSoon(plr)
	return view(st, r)
end

local function dailyState(d)
	d.Daily = type(d.Daily) == "table" and d.Daily or { day = 0, streak = 0 }
	local t = today()
	local claimed = d.Daily.day == t
	-- the next day of the streak (back to day 1 after a missed day or after day 7)
	local nextIdx
	if claimed then nextIdx = d.Daily.streak
	elseif d.Daily.day == t - 1 then nextIdx = (d.Daily.streak % #G.Daily) + 1
	else nextIdx = 1 end
	return claimed, nextIdx
end

function G.State(plr, st)
	local s = sessions[plr]
	if not s then return nil end
	local elapsed = os.clock() - s.start
	local list = {}
	for i, r in ipairs(G.Playtime) do
		local v = view(st, r)
		v.t = r.t
		v.claimed = s.claimed[i] == true
		list[i] = v
	end
	local claimed, idx = dailyState(st.data)
	local dl = {}
	for i, r in ipairs(G.Daily) do dl[i] = view(st, r) end
	return { elapsed = elapsed, list = list, daily = { day = idx, claimed = claimed, nextIn = (today() + 1) * 86400 - os.time(), list = dl } }
end

-- the badge on the GIFTS button: how many gifts are waiting (playtime gifts ready + the daily reward) and the
-- seconds to the next playtime gift (-1: none left this visit)
refresh = function(plr)
	local s, st = sessions[plr], ctx and ctx.S[plr]
	if not (s and st and plr.Parent) then return end
	local n, nextT = 0, nil
	local el = os.clock() - s.start
	for i, r in ipairs(G.Playtime) do
		if not s.claimed[i] then
			if el >= r.t then n += 1 elseif not nextT or r.t - el < nextT then nextT = r.t - el end
		end
	end
	if not dailyState(st.data) then n += 1 end
	plr:SetAttribute("GiftsReady", n)
	plr:SetAttribute("GiftNext", nextT and math.ceil(nextT) or -1)
end

function G.Join(plr)
	sessions[plr] = { start = os.clock(), claimed = {} }
	task.defer(refresh, plr)
end
function G.Leave(plr) sessions[plr] = nil end

function G.Init(c)
	ctx = c
	local rf = c.remote("RemoteFunction", "Gifts")
	rf.OnServerInvoke = function(plr, action, i)
		local st = ctx.S[plr]
		local s = sessions[plr]
		if not st or not s then return false, "Loading..." end
		if action == "state" then
			return true, G.State(plr, st)
		elseif action == "claim" then
			i = tonumber(i)
			local r = i and G.Playtime[i]
			if not r then return false, "No such gift" end
			if s.claimed[i] then return false, "Already claimed" end
			if os.clock() - s.start < r.t - 1 then return false, "Not ready yet" end
			s.claimed[i] = true
			local got = grant(plr, st, r)
			refresh(plr)
			return true, got
		elseif action == "daily" then
			local claimed, idx = dailyState(st.data)
			if claimed then return false, "Come back tomorrow!" end
			st.data.Daily.day = today()
			st.data.Daily.streak = idx
			local got = grant(plr, st, G.Daily[idx])
			refresh(plr)
			return true, got
		end
		return false, "Unknown action"
	end
	-- the badge: kept fresh every 2 s
	task.spawn(function()
		while true do
			task.wait(2)
			for plr in pairs(sessions) do refresh(plr) end
		end
	end)
end

return G
