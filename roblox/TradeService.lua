-- BlockRise Empire - safe player-to-player trading of hammers, materials, blueprints and cash.
-- Rules: both players Level 5+, every change resets "ready", both must be ready for a 5 second countdown, items are
-- checked again right before the swap (and the swap runs in one go, no yielding: nothing can exist twice), cash pays a
-- 5% trade fee.
--
-- Fair play without false alarms:
--  * an offer always matches what you really have: when something you offered is spent / used elsewhere while the trade
--    is open, the offer shrinks to what is left (READY resets, you get a note) instead of the whole trade failing later
--  * when your PARTNER changes their offer, your READY is locked for a moment (you see the change first); your own
--    changes never lock you
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Company = require(ReplicatedStorage.Shared.Company)
local Config = require(ReplicatedStorage.Shared.Config)
local Hammers = require(ReplicatedStorage.Shared.Hammers)
local HammerService = require(script.Parent:WaitForChild("HammerService"))

local M = {}
local ctx -- { S, sync, feedback, saveData, remote, afterTrade }
M.MinLevel = 5
M.CashFee = 0.05
M.Countdown = 5
M.MaxHammers = 6
M.HammerLock = 3 -- seconds the partner's READY waits after a hammer is added or removed
M.ChangeLock = 1.5 -- ... after anything else of the offer changed
M.MaxQty = 1e12

local sessions = {} -- [Player] = session (both players point to the same session)
local pending = {} -- [targetPlayer] = { from = Player, t = os.clock() }
local lastRequest = {} -- [Player] = os.clock()
local bots = {} -- (Studio only) [fake partner] = its fake state: see the test hook at the end
local pushRE

local function emptyOffer() return { mats = {}, bps = {}, cash = 0, hams = {} } end
local function real(p) return typeof(p) == "Instance" and p:IsA("Player") end
local function stOf(p) return bots[p] or (ctx.S[p]) end
local function present(p) if real(p) then return p.Parent ~= nil end return bots[p] ~= nil end

local function other(s, plr) return s.a == plr and s.b or s.a end

local function view(s)
	local now = os.clock()
	local function lockOf(p) return s.lockUntil[p] and math.max(0, s.lockUntil[p] - now) or 0 end
	return {
		a = s.a.UserId, b = s.b.UserId, aName = s.a.DisplayName, bName = s.b.DisplayName,
		offers = { [tostring(s.a.UserId)] = s.offers[s.a], [tostring(s.b.UserId)] = s.offers[s.b] },
		ready = { [tostring(s.a.UserId)] = s.ready[s.a] == true, [tostring(s.b.UserId)] = s.ready[s.b] == true },
		locks = { [tostring(s.a.UserId)] = lockOf(s.a), [tostring(s.b.UserId)] = lockOf(s.b) },
		countdown = s.countdownEnds and math.max(0, s.countdownEnds - now) or nil,
		version = s.version, fee = M.CashFee, maxHammers = M.MaxHammers,
		lock = 0, -- (older clients)
	}
end

local function fire(p, kind, d)
	if real(p) and p.Parent then pushRE:FireClient(p, kind, d) end
end

local function push(s, kind)
	local v = view(s)
	for _, p in ipairs({ s.a, s.b }) do fire(p, kind or "update", v) end
end

local function note(p, text) fire(p, "note", { text = text }) end

local function close(s, reason)
	if s.closed then return end
	s.closed = true
	for _, p in ipairs({ s.a, s.b }) do
		if sessions[p] == s then sessions[p] = nil end
		fire(p, "closed", { reason = reason })
	end
end

-- the hammer item is still in the bag, the same hammer, at the same level (a level shown in the offer is a promise)
local function hammerOk(d, hm)
	local ok, it = HammerService.CanTrade(d, hm.id)
	return ok and it.k == hm.k and (it.lv or 1) == (hm.lv or 1)
end

local function offerValid(st, offer)
	local d = st.data
	for id, n in pairs(offer.mats) do if (d.Items.mats[id] or 0) < n then return false end end
	for id, n in pairs(offer.bps) do if (d.Items.bps[id] or 0) < n then return false end end
	if (d.Money or 0) < (offer.cash or 0) then return false end
	for _, hm in ipairs(offer.hams or {}) do
		if not hammerOk(d, hm) then return false end
	end
	return true
end

-- shrink an offer to what the player really has; returns a list of what changed (for the note)
local function fitOffer(st, offer)
	local d, what = st.data, {}
	for id, n in pairs(offer.mats) do
		local have = d.Items.mats[id] or 0
		if have < n then
			offer.mats[id] = have > 0 and have or nil
			local m = Company.MaterialById[id]
			table.insert(what, (m and m.name or id) .. " (" .. have .. " left)")
		end
	end
	for id, n in pairs(offer.bps) do
		local have = d.Items.bps[id] or 0
		if have < n then
			offer.bps[id] = have > 0 and have or nil
			local b = Company.BlueprintById[id]
			table.insert(what, (b and b.name or id) .. " (" .. have .. " left)")
		end
	end
	local money = math.floor(d.Money or 0)
	if (offer.cash or 0) > money then
		offer.cash = math.max(0, money)
		table.insert(what, "cash (" .. Config.FormatMoney(offer.cash) .. " left)")
	end
	for i = #(offer.hams or {}), 1, -1 do
		local hm = offer.hams[i]
		if not hammerOk(d, hm) then
			table.remove(offer.hams, i)
			local h = Hammers.ById[hm.k]
			table.insert(what, (h and h.name or "a hammer") .. " (not in your bag any more)")
		end
	end
	return what
end

local function offerEmpty(o)
	return next(o.mats) == nil and next(o.bps) == nil and (o.cash or 0) <= 0 and #(o.hams or {}) == 0
end

local function describe(o)
	local parts = {}
	for _, m in ipairs(Company.Materials) do if (o.mats[m.id] or 0) > 0 then table.insert(parts, o.mats[m.id] .. " " .. m.name) end end
	for _, b in ipairs(Company.Blueprints) do if (o.bps[b.id] or 0) > 0 then table.insert(parts, o.bps[b.id] .. " " .. b.name) end end
	for _, hm in ipairs(o.hams or {}) do
		local hd = Hammers.ById[hm.k]
		if hd then table.insert(parts, hd.name .. " Lv" .. (hm.lv or 1)) end
	end
	if (o.cash or 0) > 0 then table.insert(parts, Config.FormatMoney(o.cash)) end
	return #parts > 0 and table.concat(parts, ", ") or "nothing"
end

-- something changed: READY off for both, the countdown stops. by = the player who changed it (their partner's READY
-- waits a moment, so they see the change first)
local function changed(s, by, lockSecs)
	s.version += 1
	s.ready = {}
	s.countdownEnds = nil
	if by and lockSecs then
		local o = other(s, by)
		s.lockUntil[o] = math.max(s.lockUntil[o] or 0, os.clock() + lockSecs)
	end
	push(s)
end

-- the offers follow what the players really have (spent elsewhere while the trade is open -> the offer shrinks)
local function refit(s)
	local any = false
	for _, p in ipairs({ s.a, s.b }) do
		local st = stOf(p)
		if st and st.data then
			local what = fitOffer(st, s.offers[p])
			if #what > 0 then
				any = true
				note(p, "Your offer changed: " .. table.concat(what, ", "))
				note(other(s, p), (p.DisplayName or "Your partner") .. "'s offer changed - check it before READY")
				s.lockUntil[other(s, p)] = math.max(s.lockUntil[other(s, p)] or 0, os.clock() + M.HammerLock)
			end
		end
	end
	if any then changed(s) end
	return any
end

local function execute(s)
	local sa, sb = stOf(s.a), stOf(s.b)
	if not (sa and sb and present(s.a) and present(s.b)) then close(s, "A player left") return end
	local oa, ob = s.offers[s.a], s.offers[s.b]
	-- (one last check, right before the swap: anything that changed puts the trade back to "press READY")
	if not offerValid(sa, oa) or not offerValid(sb, ob) then
		refit(s)
		return
	end
	-- both hammer bags must have room after the swap
	local na, nb = #(oa.hams or {}), #(ob.hams or {})
	if #sa.data.Hammers - na + nb > Hammers.InventoryCap then
		changed(s); note(s.a, "Your hammer bag would be too full - make room first"); note(s.b, s.a.DisplayName .. "'s hammer bag is full")
		return
	end
	if #sb.data.Hammers - nb + na > Hammers.InventoryCap then
		changed(s); note(s.b, "Your hammer bag would be too full - make room first"); note(s.a, s.b.DisplayName .. "'s hammer bag is full")
		return
	end
	-- the swap itself happens in one go (no yielding in between): everything leaves both players first, then arrives
	local function take(fromSt, o)
		for id, n in pairs(o.mats) do fromSt.data.Items.mats[id] -= n end
		for id, n in pairs(o.bps) do fromSt.data.Items.bps[id] -= n end
		if (o.cash or 0) > 0 then fromSt.data.Money -= o.cash end
	end
	local function give(toSt, o)
		for id, n in pairs(o.mats) do toSt.data.Items.mats[id] = (toSt.data.Items.mats[id] or 0) + n end
		for id, n in pairs(o.bps) do toSt.data.Items.bps[id] = (toSt.data.Items.bps[id] or 0) + n end
		if (o.cash or 0) > 0 then toSt.data.Money += math.floor(o.cash * (1 - M.CashFee)) end
	end
	take(sa, oa)
	take(sb, ob)
	give(sb, oa)
	give(sa, ob)
	-- hammers: every one out first, then in (an item can never be in two bags, or in none)
	local toB, toA = {}, {}
	for _, hm in ipairs(oa.hams or {}) do local it = HammerService.Take(sa, hm.id); if it then table.insert(toB, it) end end
	for _, hm in ipairs(ob.hams or {}) do local it = HammerService.Take(sb, hm.id); if it then table.insert(toA, it) end end
	for _, it in ipairs(toB) do HammerService.Put(sb, it) end
	for _, it in ipairs(toA) do HammerService.Put(sa, it) end
	local now = os.time()
	local function log(st, partner, gave, got)
		st.data.TradeLog = type(st.data.TradeLog) == "table" and st.data.TradeLog or {}
		table.insert(st.data.TradeLog, { t = now, with = partner.UserId, gave = describe(gave), got = describe(got) })
		while #st.data.TradeLog > 20 do table.remove(st.data.TradeLog, 1) end
	end
	log(sa, s.b, oa, ob)
	log(sb, s.a, ob, oa)
	sa.data.Stats = sa.data.Stats or {}
	sb.data.Stats = sb.data.Stats or {}
	sa.data.Stats.trades = (sa.data.Stats.trades or 0) + 1
	sb.data.Stats.trades = (sb.data.Stats.trades or 0) + 1
	for _, p in ipairs({ s.a, s.b }) do
		local partner = other(s, p)
		fire(p, "done", { partner = partner.DisplayName, got = describe(s.offers[partner]), gave = describe(s.offers[p]) })
	end
	close(s, nil)
	-- saved right away, both of them (a trade never waits for the next autosave)
	for _, p in ipairs({ s.a, s.b }) do
		if real(p) then
			pcall(ctx.afterTrade, p)
			pcall(HammerService.AfterTrade, p)
			task.spawn(ctx.saveData, p)
		end
	end
end

local function startCountdown(s)
	local ends = os.clock() + M.Countdown
	s.countdownEnds = ends
	local version = s.version
	push(s)
	task.delay(M.Countdown, function()
		if s.closed or s.version ~= version or s.countdownEnds ~= ends then return end
		if s.ready[s.a] and s.ready[s.b] then execute(s) end
	end)
end

local actions = {}

local function canTradeNow(plr, st)
	if not st.loaded and real(plr) then return false, "Your progress is still loading" end
	return true
end

function actions.request(plr, st, targetId)
	local target = Players:GetPlayerByUserId(tonumber(targetId) or 0)
	if not target or target == plr then return false, "Player not found" end
	local tst = ctx.S[target]
	if not tst or not tst.loaded then return false, "That player is still loading" end
	local okL, why = canTradeNow(plr, st)
	if not okL then return false, why end
	-- Roblox policy (IsPaidItemTradingAllowed): materials and blueprints can come from the paid Lucky Spin,
	-- so players whose region forbids trading paid-random outcomes don't trade at all
	if st.tradingAllowed == false then return false, "Trading isn't available in your region" end
	if tst.tradingAllowed == false then return false, target.DisplayName .. " can't trade in their region" end
	if st.data.Level < M.MinLevel then return false, "Trading unlocks at Level " .. M.MinLevel end
	if tst.data.Level < M.MinLevel then return false, target.DisplayName .. " needs Level " .. M.MinLevel .. " to trade" end
	if sessions[plr] then return false, "Finish your current trade first" end
	if sessions[target] then return false, target.DisplayName .. " is already trading" end
	if os.clock() - (lastRequest[plr] or 0) < 8 then return false, "Wait a few seconds before sending another request" end
	lastRequest[plr] = os.clock()
	pending[target] = { from = plr, t = os.clock() }
	fire(target, "request", { from = plr.UserId, name = plr.DisplayName })
	return true
end

local function openSession(a, b)
	local s = { a = a, b = b, offers = { [a] = emptyOffer(), [b] = emptyOffer() }, ready = {}, lockUntil = {}, version = 1 }
	sessions[a] = s
	sessions[b] = s
	push(s, "open")
	return s
end

function actions.respond(plr, st, fromId, accept)
	local p = pending[plr]
	if not p or p.from.UserId ~= tonumber(fromId) or os.clock() - p.t > 20 then return false, "That request expired" end
	pending[plr] = nil
	local from = p.from
	if not accept then
		fire(from, "declined", { name = plr.DisplayName })
		return true
	end
	if not from.Parent or not ctx.S[from] or not ctx.S[from].loaded then return false, "The other player left" end
	local okL, why = canTradeNow(plr, st)
	if not okL then return false, why end
	if sessions[plr] or sessions[from] then return false, "Someone is already trading" end
	openSession(from, plr)
	return true
end

-- set how much of one thing you offer (kind = "mat" | "bp" | "cash" | "ham"); qty is the new total, not a change
function actions.set(plr, st, kind, id, qty)
	local s = sessions[plr]
	if not s then return false, "No trade open" end
	local o = s.offers[plr]
	qty = tonumber(qty) or 0
	if qty ~= qty then qty = 0 end -- (NaN)
	qty = math.clamp(math.floor(qty), 0, M.MaxQty)
	local d = st.data
	local lockSecs = M.ChangeLock
	if kind == "mat" then
		if type(id) ~= "string" or not Company.MaterialById[id] then return false, "Unknown material" end
		qty = math.min(qty, d.Items.mats[id] or 0)
		if (o.mats[id] or 0) == qty then return true end
		o.mats[id] = qty > 0 and qty or nil
	elseif kind == "bp" then
		if type(id) ~= "string" or not Company.BlueprintById[id] then return false, "Unknown blueprint" end
		qty = math.min(qty, d.Items.bps[id] or 0)
		if (o.bps[id] or 0) == qty then return true end
		o.bps[id] = qty > 0 and qty or nil
	elseif kind == "cash" then
		qty = math.min(qty, math.max(0, math.floor(d.Money or 0)))
		if (o.cash or 0) == qty then return true end
		o.cash = qty
	elseif kind == "ham" then
		-- id = the hammer item, qty 1 = put it in, 0 = take it out
		if type(id) ~= "string" then return false, "Unknown hammer" end
		o.hams = o.hams or {}
		local at
		for i, hm in ipairs(o.hams) do if hm.id == id then at = i end end
		if qty > 0 then
			if at then return true end
			local ok, it = HammerService.CanTrade(d, id)
			if not ok then return false, it end
			if #o.hams >= M.MaxHammers then return false, "Up to " .. M.MaxHammers .. " hammers per trade" end
			table.insert(o.hams, { id = it.id, k = it.k, lv = it.lv or 1 })
		else
			if not at then return true end
			table.remove(o.hams, at)
		end
		lockSecs = M.HammerLock
	else
		return false, "Can't trade that"
	end
	changed(s, plr, lockSecs)
	return true
end

function actions.ready(plr, st, on)
	local s = sessions[plr]
	if not s then return false, "No trade open" end
	on = on == true
	if on then
		if offerEmpty(s.offers[s.a]) and offerEmpty(s.offers[s.b]) then return false, "Add something to the trade first" end
		local lk = s.lockUntil[plr]
		if lk and os.clock() < lk then return false, "Your partner just changed the offer: check it first (" .. math.ceil(lk - os.clock()) .. "s)" end
		-- (READY on an offer that doesn't match your bag any more: it is fixed first, you look again)
		if refit(s) then return false, "The offer changed - check it and press READY again" end
	end
	if (s.ready[plr] == true) == on then return true end
	s.ready[plr] = on
	if s.ready[s.a] and s.ready[s.b] then
		startCountdown(s)
	else
		s.countdownEnds = nil
		push(s)
	end
	return true
end

function actions.cancel(plr, st)
	local s = sessions[plr]
	if s then close(s, plr.DisplayName .. " cancelled the trade") end
	return true
end

-- the trade as it is now (a client that missed an update asks for it)
function actions.state(plr, st)
	local s = sessions[plr]
	if not s then return true, nil end
	return true, view(s)
end

function actions.players(plr, st)
	local list = {}
	for _, p in ipairs(Players:GetPlayers()) do
		local pst = ctx.S[p]
		if p ~= plr and pst then
			table.insert(list, { id = p.UserId, name = p.DisplayName, level = pst.data.Level, busy = sessions[p] ~= nil,
				company = pst.data.Company and pst.data.Company.founded and pst.data.Company.name or "" })
		end
	end
	return true, { players = list, minLevel = M.MinLevel, myLevel = st.data.Level, log = st.data.TradeLog or {} }
end

function M.Init(c)
	ctx = c
	pushRE = c.remote("RemoteEvent", "TradeEvent")
	local rf = c.remote("RemoteFunction", "TradeAction")
	rf.OnServerInvoke = function(plr, action, a, b, d)
		local st = ctx.S[plr]
		if not st or not st.data or not st.data.Items then return false, "Loading..." end
		local fn = type(action) == "string" and actions[action]
		if not fn then return false, "Unknown action" end
		if st.tradingAllowed == false and action ~= "players" and action ~= "cancel" and action ~= "state" then return false, "Trading isn't available in your region" end
		if action == "state" or action == "players" then
			if os.clock() - (st.lastTradeGet or 0) < 0.05 then return false, "Slow down!" end
			st.lastTradeGet = os.clock()
		else
			if os.clock() - (st.lastTradeAction or 0) < 0.08 then return false, "Slow down!" end
			st.lastTradeAction = os.clock()
		end
		local ok, r1, r2 = pcall(fn, plr, st, a, b, d)
		if not ok then warn("TradeAction error:", action, r1) return false, "Something went wrong" end
		return r1, r2
	end
	Players.PlayerRemoving:Connect(function(plr)
		local s = sessions[plr]
		if s then close(s, plr.DisplayName .. " left the game") end
		pending[plr] = nil
		lastRequest[plr] = nil
		for target, p in pairs(pending) do if p.from == plr then pending[target] = nil end end
	end)
	-- the offers follow the bags: something offered and then spent / used elsewhere shrinks the offer at once
	task.spawn(function()
		while true do
			task.wait(0.5)
			local seen = {}
			for _, s in pairs(sessions) do
				if not seen[s] and not s.closed then
					seen[s] = true
					local ok, err = pcall(refit, s)
					if not ok then warn("Trade refit:", err) end
				end
			end
		end
	end)
	-- Studio only: a test partner (ServerStorage.CE_TradeBot:Invoke(player, "open" | "offer" | "ready" | "unready" | "cancel", ...))
	if RunService:IsStudio() then
		local bf = Instance.new("BindableFunction")
		bf.Name = "CE_TradeBot"
		bf.OnInvoke = function(plr, cmd, a, b)
			local s = sessions[plr]
			if cmd == "open" then
				if s then return "already trading" end
				local bot = { UserId = 1, DisplayName = "Test Bot", Name = "TestBot" }
				local items = { mats = {}, bps = {} }
				for _, m in ipairs(Company.Materials) do items.mats[m.id] = 500 end
				for _, bp in ipairs(Company.Blueprints) do items.bps[bp.id] = 5 end
				local hams = {}
				for i, h in ipairs(Hammers.List or {}) do
					if i > 3 and #hams < 4 and not h.soon and not h.exclusive then table.insert(hams, { id = "bot" .. i, k = h.key, lv = 1 + (i % 3) }) end
				end
				bots[bot] = { loaded = true, data = { Items = items, Money = 1e9, Hammers = hams, Index = {}, Level = 99 } }
				openSession(plr, bot)
				return "open"
			end
			if not s then return "no trade" end
			local bot = other(s, plr)
			local bst = bots[bot]
			if not bst then return "partner is not the bot" end
			if cmd == "offer" then
				-- a = kind, b = { id, qty }
				return actions.set(bot, bst, a, b[1], b[2])
			elseif cmd == "ready" or cmd == "unready" then
				return actions.ready(bot, bst, cmd == "ready")
			elseif cmd == "spend" then
				-- the player spends an offered thing elsewhere (the offer must shrink): a = material id, b = how many
				local st = ctx.S[plr]
				st.data.Items.mats[a] = math.max(0, (st.data.Items.mats[a] or 0) - b)
				return "spent"
			elseif cmd == "hams" then
				local ids = {}
				for _, it in ipairs(bst.data.Hammers) do table.insert(ids, it.id .. "=" .. it.k) end
				return table.concat(ids, ",")
			elseif cmd == "cancel" then
				close(s, "Test Bot cancelled the trade")
				return "closed"
			elseif cmd == "leave" then
				close(s, "Test Bot left the game")
				return "left"
			end
			return "?"
		end
		bf.Parent = game:GetService("ServerStorage")
	end
end

-- true while the player is in a trade (shops and selling are blocked so offers can't change underneath)
function M.IsTrading(plr) return sessions[plr] ~= nil end

return M
