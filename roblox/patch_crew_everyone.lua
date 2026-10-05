-- one-off patch (run in Edit): the whole crew works all the time
--  * every builder's work feeds the stage together (the least-done task first), so a faster worker never finishes the
--    slower ones' tasks under them and leaves them standing; everybody keeps hammering until the stage is done
--  * materials are not thrown away when the stage changes (bricks -> planks -> glass...): no crew-wide wait at every stage
--  * out of material, a builder keeps working at half speed while a laborer brings more (no standing and watching)
--  * laborers' deliveries feed the stage the same way; bigger loads (16 swings) = fewer trips
--  * Studio probe: CE_Debug "crewProbe" shows how long ago each worker last worked
local function replaceOnce(src, old, new)
	local a, b = src:find(old, 1, true)
	assert(a, "not found: " .. old:sub(1, 80))
	assert(not src:find(old, b + 1, true), "found twice: " .. old:sub(1, 80))
	return src:sub(1, a - 1) .. new .. src:sub(b + 1)
end

local CrewM = game.ServerScriptService.Game.Crew
local s = CrewM.Source
if s:find("CREW_EVERYONE", 1, true) then return "already patched" end

s = replaceOnce(s, "local BUILDER_LOAD = 12 -- swings of work per load of material",
	"local BUILDER_LOAD = 16 -- swings of work per load of material (CREW_EVERYONE)")

-- keep the material when the stage changes (it only changes what they carry)
s = replaceOnce(s, "					if w.stockVerb ~= tverb then w.stock = 0; w.stockVerb = tverb end",
	"					if w.stockVerb ~= tverb then w.stockVerb = tverb end")

-- wait a bit longer for a laborer before walking to the pallet (they keep working meanwhile)
s = replaceOnce(s, "						if not hasCarrier or (now - w.waitSince > 6 and not coming) or now - w.waitSince > 15 then",
	"						if not hasCarrier or (now - w.waitSince > 8 and not coming) or now - w.waitSince > 20 then")

-- no more standing at the spot: out of material = keep working at half speed
s = replaceOnce(s, [=[					elseif needs then
						-- out of material: wait at the spot for a laborer
						if moveTo(w, spot, now) and not w.facedWait then w.facedWait = true; face(w, aim) end
					elseif moveTo(w, spot, now) then
						w.facedWait = nil
						-- a second builder on the same task is less efficient: spreading out pays off
						local same = 0
						for j = 1, k - 1 do if assignment[builders[j]] == track then same += 1 end end
						local eff = (same > 0) and 0.75 or 1
						table.insert(flows, { track = track, rate = t.rate * eff * mult })
						if now - w.lastSwing > t.swing * (0.9 + math.random() * 0.2) then
							w.lastSwing = now
							if not earthStage then w.stock = (w.stock or 0) - 1 end]=],
	[=[					elseif moveTo(w, spot, now) then
						w.facedWait = nil
						-- a second builder on the same task is less efficient: spreading out pays off
						local same = 0
						for j = 1, k - 1 do if assignment[builders[j]] == track then same += 1 end end
						local eff = (same > 0) and 0.75 or 1
						-- out of material: keeps working at half speed until a laborer brings more
						if needs then eff *= 0.5 end
						-- the whole crew feeds the stage together (least-done task first): a faster worker never
						-- finishes the others' tasks under them, so everyone works until the stage is done
						table.insert(flows, { track = nil, rate = t.rate * eff * mult })
						w.lastWork = now
						if now - w.lastSwing > t.swing * (0.9 + math.random() * 0.2) * (needs and 1.5 or 1) then
							w.lastSwing = now
							if not earthStage and not needs then w.stock = (w.stock or 0) - 1 end]=])

-- laborers: their deliveries feed the stage too
s = replaceOnce(s, "								table.insert(bursts, { track = w.dropTrack, amount = amount })",
	"								table.insert(bursts, { track = nil, amount = amount })\n								w.lastWork = now")
-- a laborer picking up material is working as well
s = replaceOnce(s, [[							elseif now - w.pickTimer > 0.8 then
								w.cstate = "drop"; w.pickTimer = nil; w.pickPos = nil]], [[							elseif now - w.pickTimer > 0.8 then
								w.lastWork = now
								w.cstate = "drop"; w.pickTimer = nil; w.pickPos = nil]])
-- foreman
s = replaceOnce(s, "						table.insert(flows, { track = nil, rate = t.rate * mult })", "						table.insert(flows, { track = nil, rate = t.rate * mult })\n						w.lastWork = now")

-- probe for tests
s = replaceOnce(s, "-- Fires one worker of the given type (the most recently hired)", [[-- how long ago each worker last worked (Studio tests)
function Crew:Probe(now)
	local out = {}
	for _, w in ipairs(self.workers) do
		table.insert(out, { type = w.type.id, role = w.role, idle = w.lastWork and math.floor((now - w.lastWork) * 10) / 10 or -1,
			needs = w.needs == true, fetching = w.fetching == true, stock = w.stock or 0, track = w.track and w.track.label or "" })
	end
	return out
end

-- Fires one worker of the given type (the most recently hired)]])

assert(loadstring(s), "Crew compile")

local Main = game.ServerScriptService.Game.Main
local m = Main.Source
if not m:find('cmd == "crewProbe"', 1, true) then
	m = replaceOnce(m, [[		elseif cmd == "rejoinSim" then]], [[		elseif cmd == "crewProbe" then return S[plr].crew and S[plr].crew:Probe(os.clock())
		elseif cmd == "rejoinSim" then]])
	m = replaceOnce(m, "				-- every worker feeds its own task, so tasks advance in parallel\n",
		"				-- the crew's work goes to the least-done task first, so every task (and every worker) keeps going\n")
	assert(loadstring(m), "Main compile")
end

CrewM.Source = s
Main.Source = m
return "crew patched"
