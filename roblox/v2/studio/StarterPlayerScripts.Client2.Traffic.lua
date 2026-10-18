-- BlockRise 2.0 - traffic (client): cars driving the permanent streets (the boulevards, the perimeter roads and the
-- arterials, a 4 x 4 grid of crossings), right-hand lanes, a smooth turn at every crossing, a stop when the crossing
-- is taken or a car is close ahead. Drawn on each client (smooth, no network traffic); the car models are in
-- ReplicatedStorage.TrafficCars (copies of the kit's cars, pivot at the base, front -Z).
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local T = {}

local XS = { -752, -180, 180, 752 } -- the N-S lines: perimeter, boulevard, boulevard, perimeter
local ZS = { -564, -188, 188, 564 } -- the E-W arterials
local Y = 0.3                       -- the road's top
local CRUISE, TURN = 34, 17         -- studs per second
local GAP = 16                      -- the distance kept to the car ahead
local COUNT = 18

local function isBlvd(x) return math.abs(math.abs(x) - 180) < 1 end
local function right(d) return Vector3.new(-d.Z, 0, d.X) end

-- the crossings and their links
local nodes = {}
local function node(ix, iz) return nodes[ix * 10 + iz] end
local function build()
	for ix, x in ipairs(XS) do
		for iz, z in ipairs(ZS) do
			nodes[ix * 10 + iz] = { x = x, z = z, pos = Vector3.new(x, Y, z), hx = (isBlvd(x) and 60 or 44) / 2, hz = 22, links = {}, ix = ix, iz = iz }
		end
	end
	for _, n in pairs(nodes) do
		for _, o in ipairs({ { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }) do
			local m = node(n.ix + o[1], n.iz + o[2])
			if m then table.insert(n.links, { to = m, dir = Vector3.new(o[1], 0, o[2]) }) end
		end
	end
end
-- the lane offset of the road going in direction d out of / into node n
local function laneOff(n, d) return (math.abs(d.Z) > 0.5 and isBlvd(n.x)) and 5 or 3.6 end
local function half(n, d) return math.abs(d.X) > 0.5 and n.hx or n.hz end
local function exitPoint(n, d) return n.pos + d * half(n, d) + right(d) * laneOff(n, d) end
local function entryPoint(n, d) return n.pos - d * half(n, d) + right(d) * laneOff(n, d) end

-- a path piece: a straight leg between two crossings, or a turn through one (a quadratic curve)
local function line(a, b, from, dir) return { kind = "leg", a = a, b = b, len = (b - a).Magnitude, from = from, dir = dir } end
local function bezier(a, c, b, at)
	local len, prev = 0, a
	for i = 1, 10 do
		local t = i / 10
		local p = a:Lerp(c, t):Lerp(c:Lerp(b, t), t)
		len += (p - prev).Magnitude
		prev = p
	end
	return { kind = "turn", a = a, c = c, b = b, len = len, at = at }
end
local function pointOn(pc, s)
	local t = math.clamp(s / math.max(pc.len, 0.01), 0, 1)
	if pc.kind == "leg" then return pc.a:Lerp(pc.b, t), (pc.b - pc.a).Unit end
	local p = pc.a:Lerp(pc.c, t):Lerp(pc.c:Lerp(pc.b, t), t)
	local d = (pc.c - pc.a) * (1 - t) + (pc.b - pc.c) * t
	return p, d.Magnitude > 1e-3 and d.Unit or (pc.b - pc.a).Unit
end

-- the next leg out of node n, coming in along `dir`: any link but going back (unless it is the only one)
local function pickLink(n, dir, rng)
	local opts = {}
	for _, l in ipairs(n.links) do
		if not (dir and l.dir:Dot(dir) < -0.5) then table.insert(opts, l) end
	end
	if #opts == 0 then opts = n.links end
	-- straight on a bit more often than a turn
	local w = {}
	for _, l in ipairs(opts) do table.insert(w, (dir and l.dir:Dot(dir) > 0.5) and 2 or 1) end
	local sum = 0
	for _, x in ipairs(w) do sum += x end
	local r = rng:NextNumber(0, sum)
	for i, l in ipairs(opts) do
		r -= w[i]
		if r <= 0 then return l end
	end
	return opts[#opts]
end

local cars = {}
local function legFor(from, l) return line(exitPoint(from, l.dir), entryPoint(l.to, l.dir), from, l.dir) end

function T.start()
	local folder = ReplicatedStorage:WaitForChild("TrafficCars", 30)
	if not folder then return end
	local models = folder:GetChildren()
	if #models == 0 then return end
	build()
	local live = Instance.new("Folder")
	live.Name = "Traffic"
	live.Parent = workspace
	local rng = Random.new(os.clock() * 1000)
	-- every car starts somewhere on a leg, not too close to another one
	local all = {}
	for _, n in pairs(nodes) do for _, l in ipairs(n.links) do table.insert(all, { n = n, l = l }) end end
	for i = 1, COUNT do
		local pick = all[rng:NextInteger(1, #all)]
		local pc = legFor(pick.n, pick.l)
		local s = rng:NextNumber(0, pc.len * 0.8)
		local ok = true
		for _, c in ipairs(cars) do
			if c.piece.kind == "leg" and c.piece.from == pick.n and c.piece.dir == pick.l.dir and math.abs(c.s - s) < GAP * 1.5 then ok = false end
		end
		if ok then
			local m = models[rng:NextInteger(1, #models)]:Clone()
			for _, p in ipairs(m:GetDescendants()) do
				if p:IsA("BasePart") then p.Anchored = true p.CanCollide = false p.CanQuery = false p.CanTouch = false end
			end
			m.Parent = live
			table.insert(cars, { model = m, piece = pc, link = pick.l, s = s, v = CRUISE, rng = Random.new(i * 131) })
		end
	end

	RunService.Heartbeat:Connect(function(dt)
		dt = math.min(dt, 0.1)
		for _, car in ipairs(cars) do
			local pc = car.piece
			-- the speed it wants: cruise on a leg, slower in a turn; stop for the car ahead or a taken crossing
			local want = pc.kind == "leg" and CRUISE or TURN
			if pc.kind == "leg" then
				for _, o in ipairs(cars) do
					if o ~= car then
						local op = o.piece
						local gap
						if op.kind == "leg" and op.from == pc.from and op.dir == pc.dir and o.s > car.s then gap = o.s - car.s
						elseif op.kind == "turn" and op.at == car.link.to and (pc.len - car.s) < GAP then gap = pc.len - car.s + 2 end
						if gap and gap < GAP then want = math.min(want, math.max(0, (gap - 8) * 3)) end
					end
				end
				local toEnd = pc.len - car.s
				if toEnd < 18 then
					local at = car.link.to
					if at.lock and at.lock ~= car then want = math.min(want, math.max(0, (toEnd - 1.5) * 2.5)) else want = math.min(want, TURN + toEnd) end
				end
			end
			car.v += math.clamp(want - car.v, -60 * dt, 22 * dt)
			car.s += car.v * dt
			if car.s >= pc.len then
				local over = car.s - pc.len
				if pc.kind == "leg" then
					-- into the crossing (if it is free; else wait at its edge)
					local at = car.link.to
					if at.lock and at.lock ~= car then
						car.s = pc.len
						car.v = 0
					else
						at.lock = car
						local nl = pickLink(at, car.link.dir, car.rng)
						local a = entryPoint(at, car.link.dir)
						local b = exitPoint(at, nl.dir)
						local c = (nl.dir:Dot(car.link.dir) > 0.5) and (a + b) / 2 or (a + car.link.dir * (b - a):Dot(car.link.dir))
						car.piece = bezier(a, c, b, at)
						car.nextLink = nl
						car.s = over
					end
				else
					-- out of the crossing onto the next leg
					if pc.at.lock == car then pc.at.lock = nil end
					car.link = car.nextLink
					car.piece = legFor(pc.at, car.link)
					car.s = over
				end
			end
			local p, d = pointOn(car.piece, car.s)
			car.model:PivotTo(CFrame.lookAt(p, p + d))
		end
	end)
end

return T
