-- BlockRise 2.0 - the City: each player owns one of the 6 districts while on the server. Lots, blocks, streets,
-- the build queue (the crew builds one order at a time), income every second, offline earnings, land and Rebirth.
-- Data (st.data.City): { lots = { ["i"] = { lv, st } }, blocks = { ["r_b"] = true }, queue = { { lot, to, need,
-- done } }, name, hires, lastSeen }. The world: workspace.World.Districts.D<k>.City (Streets, Lots, Land).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Players = game:GetService("Players")
local C = require(ReplicatedStorage.Shared.Config2)
local Geo = require(ServerStorage.Build2.Geo)
local Streets = require(ServerStorage.Build2.Streets)
-- BUILD_V1 (2026-10-18): the buildings are the live game's blueprints, built stage by stage (Build = its Construction)
local Build = require(script.Parent.Build)
local Crane = require(script.Parent.Crane2)
local Blueprints = require(script.Parent.Blueprints2)

local City = {}
local ctx
local owners = {} -- district k -> player
local jobs = {} -- district k -> { job, lot, to } (the site being built)

-- Data -----------------------------------------------------------------------------------------------
function City.Sanitize(d)
	local c = type(d.City) == "table" and d.City or {}
	c.lots = type(c.lots) == "table" and c.lots or {}
	c.blocks = type(c.blocks) == "table" and c.blocks or {}
	c.blocks["1_1"] = true
	c.queue = type(c.queue) == "table" and c.queue or {}
	c.hires = math.clamp(math.floor(tonumber(c.hires) or 0), 0, #C.HirePrice)
	c.name = type(c.name) == "string" and c.name or ""
	for i = 1, 24 do
		local l = c.lots[tostring(i)]
		if type(l) ~= "table" then l = { lv = 0, st = 1 } c.lots[tostring(i)] = l end
		l.lv = math.clamp(math.floor(tonumber(l.lv) or 0), 0, C.MaxLevel)
		l.st = (l.st == 2) and 2 or 1
	end
	local q = {}
	for _, o in ipairs(c.queue) do
		if type(o) == "table" and tonumber(o.lot) and tonumber(o.to) and #q < C.QueueSize then
			table.insert(q, { lot = math.floor(o.lot), to = math.floor(o.to), need = tonumber(o.need) or 1, done = tonumber(o.done) or 0 })
		end
	end
	c.queue = q
	d.City = c
	return c
end

local function lotRec(c, i) return c.lots[tostring(i)] end
local function blockOf(i) local r, b = Geo.lotOf(i) return r .. "_" .. b end
local function owned(c, i) return c.blocks[blockOf(i)] == true end
-- the level a lot will have once its queued orders are done
local function plannedLevel(c, i)
	local lv = lotRec(c, i).lv
	for _, o in ipairs(c.queue) do if o.lot == i then lv = math.max(lv, o.to) end end
	return lv
end

-- Income -----------------------------------------------------------------------------------------------
-- income per second from the buildings alone (x1), with the block bonuses
function City.BaseIncome(c)
	local total = 0
	for r = 1, 3 do
		for b = 1, 2 do
			local sum, lo, hi = 0, 99, 0
			for s = 1, 4 do
				local lv = lotRec(c, Geo.lotIndex(r, b, s)).lv
				if lv > 0 then sum += C.Levels[lv].income end
				lo, hi = math.min(lo, lv), math.max(hi, lv)
			end
			if lo >= 1 and lo == hi then sum *= 1 + C.BlockBonus end
			total += sum
		end
	end
	return total
end
function City.BlockBonusOn(c, r, b)
	local lo, hi = 99, 0
	for s = 1, 4 do local lv = lotRec(c, Geo.lotIndex(r, b, s)).lv lo, hi = math.min(lo, lv), math.max(hi, lv) end
	return lo >= 1 and lo == hi
end
function City.Income(st)
	return City.BaseIncome(st.data.City) * C.RebirthMultiplier(st.data.Rebirths) * (ctx.cashMult and ctx.cashMult(st) or 1)
end

-- World ------------------------------------------------------------------------------------------------
local function districtFolder(k)
	return workspace.World.Districts:FindFirstChild("D" .. k)
end
local function cityFolder(k)
	local d = districtFolder(k)
	local f = d:FindFirstChild("City")
	if not f then
		f = Instance.new("Folder")
		f.Name = "City"
		f.Parent = d
		for _, n in ipairs({ "Streets", "Lots", "Land", "Crew" }) do Geo.folder(f, n) end
	end
	return f
end

-- streets: the segments and crossings around a block (animate = play the self-building show)
local function ensureStreets(k, row, block, animate)
	local f = cityFolder(k).Streets
	local list = Geo.blockStreets(row, block)
	local new = {}
	for _, id in ipairs(list.segs) do if not f:FindFirstChild(id) then table.insert(new, id) end end
	for _, id in ipairs(list.cross) do if not f:FindFirstChild(id) then table.insert(new, id) end end
	for _, id in ipairs(new) do
		local m, stages = Streets.build(f, k, id)
		if animate then
			-- every part starts sunk and invisible; the stages rise one after the other
			local all = {}
			for si, parts in pairs(stages) do
				for _, p in ipairs(parts) do
					local list2 = p:IsA("Model") and p:GetDescendants() or { p }
					for _, q in ipairs(list2) do
						if q:IsA("BasePart") then
							table.insert(all, { q, si, q.CFrame, q.Transparency })
							q.Transparency = 1
							q.CFrame = q.CFrame - Vector3.new(0, 3, 0)
						end
					end
				end
			end
			m:SetAttribute("Building", true)
			task.spawn(function()
				local TweenService = game:GetService("TweenService")
				for si = 1, 6 do
					for _, e in ipairs(all) do
						if e[2] == si and e[1].Parent then
							TweenService:Create(e[1], TweenInfo.new(0.55, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { CFrame = e[3], Transparency = e[4] }):Play()
						end
					end
					task.wait(0.7)
				end
				m:SetAttribute("Building", nil)
			end)
		end
	end
	return #new
end

-- a lot's model: the pad, the building (if any) and its tag for the client (Lot, Owner)
local function lotModel(k, i)
	local f = cityFolder(k).Lots
	local m = f:FindFirstChild("L" .. i)
	if not m then
		m = Instance.new("Model")
		m.Name = "L" .. i
		m:SetAttribute("Lot", i)
		m:SetAttribute("District", k)
		m.Parent = f
		local cf = Geo.lotCF(k, i)
		local pad = Geo.box(m, Vector3.new(Geo.Lot - 4, 0.5, Geo.Lot - 4), cf * CFrame.new(0, 0.25, 0), Color3.fromRGB(122, 214, 98), Enum.Material.SmoothPlastic, { Name = "Pad" })
		pad:SetAttribute("Lot", i)
		-- a soft path from the sidewalk to the front door
		Geo.box(m, Vector3.new(6, 0.56, 8), cf * CFrame.new(0, 0.28, -24), Color3.fromRGB(244, 238, 226), Enum.Material.SmoothPlastic, { Name = "Path" })
		-- STYLE: a crisp white kerb around the plot (open where the path comes in)
		local e = (Geo.Lot - 4) / 2
		local kerb = Color3.fromRGB(255, 255, 255)
		for _, s in ipairs({ -1, 1 }) do
			Geo.box(m, Vector3.new(1, 0.8, Geo.Lot - 4), cf * CFrame.new(s * (e - 0.5), 0.4, 0), kerb, Enum.Material.SmoothPlastic, { Name = "Kerb" })
			Geo.box(m, Vector3.new(e - 3, 0.8, 1), cf * CFrame.new(s * (3 + (e - 3) / 2), 0.4, -(e - 0.5)), kerb, Enum.Material.SmoothPlastic, { Name = "Kerb" })
		end
		Geo.box(m, Vector3.new(Geo.Lot - 4, 0.8, 1), cf * CFrame.new(0, 0.4, e - 0.5), kerb, Enum.Material.SmoothPlastic, { Name = "Kerb" })
	end
	return m
end

-- where a building stands: the top of the lot's pad, its front (-Z) toward the lot's street
local function lotOrigin(k, i) return Geo.lotCF(k, i) * CFrame.new(0, 0.5, 0) end

-- the finished building standing on a lot (lv 0: none), put up at once (join, style change, Rebirth)
local function setBuilding(k, i, lv, style)
	local m = lotModel(k, i)
	local old = m:FindFirstChild("Building")
	if old and (old:GetAttribute("Level") ~= lv or old:GetAttribute("Style") ~= style) then old:Destroy() old = nil end
	if lv <= 0 or old then return old end
	local name, bp = C.StyleOf(lv, style)
	if not bp or not Blueprints[bp] then return nil end
	local job = Build.new({ id = "B" .. k .. "_" .. i, kind = "city", title = name, blueprint = bp, origin = lotOrigin(k, i), parent = m, instant = true })
	local b = job.model
	b.Name = "Building"
	b:SetAttribute("Level", lv)
	b:SetAttribute("Style", style)
	b:SetAttribute("Height", job.size and job.size.Y or 20)
	return b
end

-- the site of an order: the live game's construction job for that blueprint, its total work = the order's work
local function startJob(plr, st, o, rec)
	local k = st.k
	local name, bp = C.StyleOf(o.to, rec.st)
	local stages = Blueprints[bp]()
	local natural = 0
	for _, s in ipairs(stages) do natural += s.work or 0 end
	local m = lotModel(k, o.lot)
	-- an old building still standing (a rejoin in the middle of an upgrade) comes down quickly
	local old = m:FindFirstChild("Building")
	if old then old.Name = "Old" Build.Demolish(old, 0.6) end
	local job = Build.new({ id = "J" .. k .. "_" .. o.lot, kind = "city", ownerId = plr.UserId, title = name, blueprint = bp,
		origin = lotOrigin(k, o.lot), parent = m, workMult = o.need / math.max(1, natural), meta = {} })
	job.model:SetAttribute("Level", o.to)
	job.model:SetAttribute("Style", rec.st)
	job.model:SetAttribute("Height", job.size and job.size.Y or 20)
	-- tall buildings get the tower crane
	if job.size and job.size.Y >= 30 then pcall(Crane.Spawn, job) end
	-- (resumed after a rejoin: the work already done shows at once)
	if (o.done or 0) > 0 then job:AddWork(o.done) end
	local J = { job = job, lot = o.lot, to = o.to }
	jobs[k] = J
	return J
end
local function dropJob(k)
	local J = jobs[k]
	jobs[k] = nil
	if J and J.job then pcall(function() J.job:Destroy(false) end) end
end

-- the for-sale sign of a block you can buy next (a board on two posts, the price, a prompt)
local function saleSign(k, row, block, price, locked)
	local f = cityFolder(k).Land
	local name = "Sale_" .. row .. "_" .. block
	local m = f:FindFirstChild(name)
	if m then m:Destroy() end
	m = Instance.new("Model")
	m.Name = name
	m:SetAttribute("Block", row .. "_" .. block)
	m:SetAttribute("District", k)
	m.Parent = f
	local side = block == 1 and -1 or 1
	local base = Geo.districtCF(k) * CFrame.new(side * 70, 0, Geo.blockZ(row) + 56)
	-- a soft fenced field: the land itself
	Geo.box(m, Vector3.new(108, 0.3, 108), base * CFrame.new(0, 0.15, 0), Color3.fromRGB(150, 222, 110), Enum.Material.SmoothPlastic, { Name = "Field", CanCollide = false })
	for s = -1, 1, 2 do
		for _, ax in ipairs({ "x", "z" }) do
			local size = ax == "x" and Vector3.new(108, 1.2, 0.6) or Vector3.new(0.6, 1.2, 108)
			local off = ax == "x" and CFrame.new(0, 2.2, s * 54) or CFrame.new(s * 54, 2.2, 0)
			Geo.box(m, size, base * off, Color3.fromRGB(255, 255, 255), Enum.Material.SmoothPlastic, { Name = "Rail" })
		end
	end
	for ix = -2, 2 do
		for _, z in ipairs({ -54, 54 }) do Geo.box(m, Vector3.new(1, 3.4, 1), base * CFrame.new(ix * 27, 1.7, z), Color3.fromRGB(255, 255, 255), Enum.Material.SmoothPlastic, { Name = "Post" }) end
		for _, x in ipairs({ -54, 54 }) do Geo.box(m, Vector3.new(1, 3.4, 1), base * CFrame.new(x, 1.7, ix * 27), Color3.fromRGB(255, 255, 255), Enum.Material.SmoothPlastic, { Name = "Post" }) end
	end
	-- the sign, facing the hub (front -Z)
	local signCF = base * CFrame.new(0, 0, -40)
	for s = -1, 1, 2 do Geo.box(m, Vector3.new(1.2, 12, 1.2), signCF * CFrame.new(s * 9, 6, 0), Color3.fromRGB(150, 104, 64), Enum.Material.Wood) end
	local board = Geo.box(m, Vector3.new(22, 9, 1.2), signCF * CFrame.new(0, 11, 0), locked and Color3.fromRGB(120, 128, 150) or Color3.fromRGB(255, 206, 64), Enum.Material.SmoothPlastic, { Name = "Board" })
	board:SetAttribute("Block", row .. "_" .. block)
	local sg = Instance.new("SurfaceGui")
	sg.Face = Enum.NormalId.Front
	sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	sg.PixelsPerStud = 24
	sg.LightInfluence = 0
	sg.Parent = board
	local t1 = Instance.new("TextLabel")
	t1.BackgroundTransparency = 1
	t1.Size = UDim2.fromScale(1, 0.5)
	t1.Font = Enum.Font.FredokaOne
	t1.TextScaled = true
	t1.TextColor3 = Color3.fromRGB(30, 44, 88)
	t1.Text = locked and ("REBIRTH " .. (row - 1)) or "LAND FOR SALE"
	t1.Parent = sg
	local t2 = t1:Clone()
	t2.Position = UDim2.fromScale(0, 0.48)
	t2.Size = UDim2.fromScale(1, 0.48)
	t2.TextColor3 = locked and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(30, 140, 70)
	t2.Text = locked and "to unlock" or C.Money(price)
	t2.Parent = sg
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0.06, 0) pad.PaddingBottom = UDim.new(0.06, 0) pad.PaddingLeft = UDim.new(0.05, 0) pad.PaddingRight = UDim.new(0.05, 0)
	pad.Parent = sg
	if not locked then
		local pp = Instance.new("ProximityPrompt")
		pp.Name = "Buy"
		pp.ActionText = "Buy land " .. C.Money(price)
		pp.ObjectText = C.RowNames[row]
		pp.HoldDuration = 0.3
		pp.MaxActivationDistance = 22
		pp.RequiresLineOfSight = false
		pp.Parent = board
	end
	return m
end

-- rebuild everything a player's district shows from their data (join, Rebirth, land bought)
function City.Render(plr, st, animateBlock)
	local k = st.k
	if not k then return end
	local c = st.data.City
	local f = cityFolder(k)
	-- streets of every owned block
	for key in pairs(c.blocks) do
		local r, b = key:match("(%d)_(%d)")
		r, b = tonumber(r), tonumber(b)
		if r and b then ensureStreets(k, r, b, animateBlock == key) end
	end
	-- lots
	for i = 1, 24 do
		if owned(c, i) then
			local rec = lotRec(c, i)
			lotModel(k, i)
			local building = false
			for _, o in ipairs(c.queue) do if o.lot == i then building = true end end
			if not building then setBuilding(k, i, rec.lv, rec.st, 0) end
		else
			local m = f.Lots:FindFirstChild("L" .. i)
			if m then m:Destroy() end
		end
	end
	-- land for sale: the next block of each open row (and one locked row to show what is coming)
	f.Land:ClearAllChildren()
	local shownLocked = false
	for r = 1, 3 do
		for b = 1, 2 do
			local key = r .. "_" .. b
			if not c.blocks[key] then
				local open = C.RowOpen(r, st.data.Rebirths)
				if open then
					saleSign(k, r, b, C.BlockPrice[key], false)
				elseif not shownLocked and b == 1 then
					saleSign(k, r, b, C.BlockPrice[key], true)
					shownLocked = true
				end
			end
		end
	end
	-- the gate shows the city's name
	local gate = districtFolder(k):FindFirstChild("Gate")
	if gate and gate:FindFirstChild("Sign") then
		for _, sg in ipairs(gate.Sign:GetChildren()) do
			if sg:IsA("SurfaceGui") and sg:FindFirstChild("Label") then sg.Label.Text = (c.name ~= "" and c.name or (plr.DisplayName .. "'s City")):upper() end
		end
	end
end

-- Assignment ---------------------------------------------------------------------------------------------
function City.Assign(plr, st)
	for k = 1, 6 do
		if not owners[k] then
			owners[k] = plr
			st.k = k
			plr:SetAttribute("District", k)
			City.Render(plr, st)
			return k
		end
	end
	return nil
end
function City.Release(plr, st)
	local k = st and st.k
	if not k then return end
	owners[k] = nil
	dropJob(k)
	local f = districtFolder(k):FindFirstChild("City")
	if f then f:Destroy() end
	local gate = districtFolder(k):FindFirstChild("Gate")
	if gate and gate:FindFirstChild("Sign") then
		for _, sg in ipairs(gate.Sign:GetChildren()) do if sg:IsA("SurfaceGui") and sg:FindFirstChild("Label") then sg.Label.Text = "FREE LAND" end end
	end
end
function City.OwnerOf(k) return owners[k] end
-- where a player arrives in their city: on the avenue just inside the gate, looking in
function City.HomeCF(st)
	return Geo.districtCF(st.k or 1) * CFrame.new(0, 4, 26) * CFrame.Angles(0, math.pi, 0)
end

-- Orders -----------------------------------------------------------------------------------------------------
function City.Power(st) return ctx.crewPower and ctx.crewPower(st) or C.BasePower end

-- build / upgrade lot i to its next level (queued)
function City.Order(plr, st, i)
	local c = st.data.City
	i = math.floor(tonumber(i) or 0)
	if i < 1 or i > 24 then return false, "No such lot" end
	if not owned(c, i) then return false, "Buy this land first" end
	if #c.queue >= C.QueueSize then return false, "Your crew has " .. C.QueueSize .. " jobs already" end
	local to = plannedLevel(c, i) + 1
	local cap = C.Cap(st.data.Rebirths)
	if to > cap then return false, to > C.MaxLevel and "Max level" or ("Rebirth to build higher") end
	for _, o in ipairs(c.queue) do if o.lot == i then return false, "Already on the way" end end
	local price = C.Levels[to].cost
	if st.data.FreeFirst ~= true and to == 1 and i == 1 then price = 0 end
	if st.data.Money < price then return false, "Not enough cash" end
	if price > 0 then ctx.addMoney(plr, -price, C.Levels[to].name) end
	if to == 1 and i == 1 then st.data.FreeFirst = true end
	table.insert(c.queue, { lot = i, to = to, need = C.Levels[to].time * C.BasePower, done = 0, demo = lotRec(c, i).lv > 0 and 1.6 or 0 })
	City.Publish(plr, st)
	ctx.saveSoon(plr)
	return true, { lot = i, to = to, name = C.Levels[to].name }
end

function City.BuyBlock(plr, st, key)
	local c = st.data.City
	if type(key) ~= "string" or not C.BlockPrice[key] then return false, "No such land" end
	if c.blocks[key] then return false, "Already yours" end
	local r, b = key:match("(%d)_(%d)")
	r, b = tonumber(r), tonumber(b)
	if not C.RowOpen(r, st.data.Rebirths) then return false, "Rebirth " .. (r - 1) .. " opens this land" end
	local price = C.BlockPrice[key]
	if st.data.Money < price then return false, "Not enough cash" end
	if price > 0 then ctx.addMoney(plr, -price, "Land " .. key) end
	c.blocks[key] = true
	City.Render(plr, st, key)
	City.Publish(plr, st)
	ctx.feedback(plr, "Land", { key = key })
	ctx.saveSoon(plr)
	return true
end

function City.SetStyle(plr, st, i, style)
	local c = st.data.City
	i = math.floor(tonumber(i) or 0)
	local rec = c.lots[tostring(i)]
	if not rec or not owned(c, i) then return false, "No such lot" end
	rec.st = style == 2 and 2 or 1
	local busy = false
	for _, o in ipairs(c.queue) do if o.lot == i then busy = true end end
	if not busy then setBuilding(st.k, i, rec.lv, rec.st) end
	ctx.saveSoon(plr)
	return true
end

-- a tap on the site of the order being built: the player's own hammer power
function City.Tap(plr, st, i)
	local c = st.data.City
	local o = c.queue[1]
	if not o or o.lot ~= i then return false end
	local now = os.clock()
	if now - (st.lastTap or 0) < 0.12 then return false end
	st.lastTap = now
	if (o.demo or 0) > 0 then return true end
	local add = math.min((ctx.tapPower and ctx.tapPower(st) or 1) * C.TapPower, math.max(0, o.need - o.done))
	o.done += add
	local J = jobs[st.k]
	if J and J.lot == o.lot and not J.job.done then J.job:AddWork(add, plr.UserId) end
	return true
end

-- Rebirth: every open lot at the cap, the cash in hand
function City.RebirthState(st)
	local c = st.data.City
	local reb = st.data.Rebirths or 0
	local cost = C.RebirthCost[reb + 1]
	if not cost then return { max = true } end
	local cap = C.Cap(reb)
	local need, have = 0, 0
	for i = 1, 24 do
		local r = Geo.lotOf(i)
		if C.RowOpen(r, reb) then
			need += cap
			have += owned(c, i) and math.min(cap, lotRec(c, i).lv) or 0
		end
	end
	return { cost = cost, ready = have >= need and #c.queue == 0, progress = need > 0 and have / need or 0, cap = cap }
end
function City.Rebirth(plr, st)
	local s = City.RebirthState(st)
	if s.max then return false, "Max Rebirth for now" end
	if not s.ready then return false, "Build every lot to level " .. s.cap .. " first" end
	if st.data.Money < s.cost then return false, "Not enough cash" end
	st.data.Money = 0
	st.data.Rebirths = (st.data.Rebirths or 0) + 1
	st.data.Stars = (st.data.Stars or 0) + st.data.Rebirths
	City.Render(plr, st)
	City.Publish(plr, st)
	ctx.sync(plr)
	ctx.feedback(plr, "Rebirth", { n = st.data.Rebirths, mult = C.RebirthMultiplier(st.data.Rebirths) })
	task.spawn(ctx.saveData, plr, false, true)
	return true
end

function City.Hire(plr, st)
	local c = st.data.City
	local price = C.HirePrice[c.hires + 1]
	if not price then return false, "Your crew is full" end
	if st.data.Money < price then return false, "Not enough cash" end
	ctx.addMoney(plr, -price, "Hire")
	c.hires += 1
	if ctx.crewChanged then ctx.crewChanged(plr, st) end
	City.Publish(plr, st)
	ctx.saveSoon(plr)
	return true
end

-- What the client sees (attributes on the player) ----------------------------------------------------------
function City.Publish(plr, st)
	local c = st.data.City
	local o = c.queue[1]
	plr:SetAttribute("Income", City.Income(st))
	plr:SetAttribute("Queue", #c.queue)
	plr:SetAttribute("BuildLot", o and o.lot or 0)
	plr:SetAttribute("BuildTo", o and o.to or 0)
	plr:SetAttribute("Hires", c.hires)
	plr:SetAttribute("FreeFirst", st.data.FreeFirst == true)
	local rs = City.RebirthState(st)
	plr:SetAttribute("RebirthProgress", rs.max and 1 or rs.progress)
	plr:SetAttribute("RebirthReady", rs.ready == true and st.data.Money >= (rs.cost or math.huge))
	plr:SetAttribute("RebirthCost", rs.cost or 0)
	local parts = {}
	for i = 1, 24 do
		local rec = c.lots[tostring(i)]
		table.insert(parts, (owned(c, i) and 1 or 0) .. ":" .. rec.lv .. ":" .. rec.st .. ":" .. plannedLevel(c, i))
	end
	plr:SetAttribute("Lots", table.concat(parts, ","))
	local q = {}
	for _, qo in ipairs(c.queue) do table.insert(q, qo.lot .. ":" .. qo.to) end
	plr:SetAttribute("QueueList", table.concat(q, ","))
end

-- The tick: the crew builds the first order; the building rises; done -> the next one ------------------------
function City.Step(plr, st, dt)
	local c = st.data.City
	local o = c.queue[1]
	if not o or not st.k then return end
	local rec = lotRec(c, o.lot)
	local J = jobs[st.k]
	if J and (J.lot ~= o.lot or J.to ~= o.to) then dropJob(st.k) J = nil end
	if (o.demo or 0) > 0 then
		-- the old building comes down piece by piece from the top, in a cloud of dust
		if not o.demoStarted then
			o.demoStarted = true
			local old = lotModel(st.k, o.lot):FindFirstChild("Building")
			if old then old.Name = "Old" Build.Demolish(old, 1.4) end
		end
		o.demo = math.max(0, o.demo - dt)
		plr:SetAttribute("BuildProgress", 0)
		plr:SetAttribute("BuildStage", "Demolition")
		return
	end
	if not J then J = startJob(plr, st, o, rec) end
	local speed = City.Power(st)
	local minSpeed = o.need / C.MinBuildSeconds
	local add = math.min(math.min(speed, minSpeed) * dt, math.max(0, o.need - o.done))
	o.done += add
	if add > 0 and not J.job.done then J.job:AddWork(add) end
	local p = math.clamp(o.done / o.need, 0, 1)
	plr:SetAttribute("BuildProgress", p)
	plr:SetAttribute("BuildLeft", math.max(0, (o.need - o.done) / math.min(speed, minSpeed)))
	local cs = J.job.stages[J.job.stageIndex]
	plr:SetAttribute("BuildStage", cs and cs.name or "Finishing")
	if p >= 1 or J.job.done then
		-- done: whatever is left appears, the spoil pile goes, the site becomes the building
		if not J.job.done then J.job:AddWork(1e12) end
		J.job:ClearTemp()
		local model = J.job.model
		J.job:Release()
		jobs[st.k] = nil
		if model then model.Name = "Building" end
		table.remove(c.queue, 1)
		rec.lv = o.to
		City.Publish(plr, st)
		ctx.sync(plr)
		ctx.feedback(plr, "Built", { lot = o.lot, lv = o.to, name = (C.StyleOf(o.to, rec.st)), income = C.Levels[o.to].income * C.RebirthMultiplier(st.data.Rebirths) })
		if ctx.onBuilt then ctx.onBuilt(plr, st, o.lot, o.to) end
		ctx.saveSoon(plr)
	end
end

-- offline: half the income (up to 8 h) and the crew kept building at its normal speed
function City.Offline(plr, st)
	local c = st.data.City
	local last = tonumber(c.lastSeen) or 0
	if last <= 0 then return 0, 0 end
	local away = math.clamp(os.time() - last, 0, (ctx.offlineHours and ctx.offlineHours(st) or C.OfflineHours) * 3600)
	if away < 60 then return 0, away end
	-- the queue first (at base power: the crew works alone)
	local t = away
	while t > 0 and c.queue[1] do
		local o = c.queue[1]
		o.demo = 0
		local left = (o.need - o.done) / C.BasePower
		if left <= t then
			t -= left
			c.lots[tostring(o.lot)].lv = o.to
			table.remove(c.queue, 1)
		else
			o.done += t * C.BasePower
			t = 0
		end
	end
	local share = ctx.offlineShare and ctx.offlineShare(st) or C.OfflineShare
	local earned = math.floor(City.Income(st) * share * away)
	return earned, away
end

function City.Init(c)
	ctx = c
end

return City
