-- one-off patch (run in Edit): a fair Mega Project
--  * at the tower everyone hits the same: every hit is 1 work (no hammer, Strength, pass or combo difference) and the
--    swing speed is the same for everyone, so the share of the pay (every stage and the final payout) = your share of
--    the hits. Before, a strong friend's hits were worth thousands of yours and took ~100% of the tower.
--  * the tower's size follows the number of builders (about 600 hits each, ~3 minutes)
--  * standing at the tower, a hit goes to the tower (not to another crew's contract that happens to be in range)
local function replaceOnce(src, old, new)
	local a, b = src:find(old, 1, true)
	assert(a, "not found: " .. old:sub(1, 80))
	assert(not src:find(old, b + 1, true), "found twice: " .. old:sub(1, 80))
	return src:sub(1, a - 1) .. new .. src:sub(b + 1)
end
local Main = game.ServerScriptService.Game.Main
local m = Main.Source
if m:find("isMega", 1, true) then return "already patched" end
m = replaceOnce(m, [[	if auto and not st.autoBuild then return end
	if now - st.lastHit < cd * 0.8 then return end
	local job = findJob(plr, hrp.Position)
	if not job then]], [[	if auto and not st.autoBuild then return end
	local job = findJob(plr, hrp.Position)
	-- the Mega Project: same power and same swing speed for everyone, the pay is split by hits
	local isMega = job ~= nil and job.kind == "mega"
	if isMega then cd = (Config.Mega.hitCooldown or 0.3) * (auto and 1.25 or 1) end
	if now - st.lastHit < cd * 0.8 then return end
	if not job then]])
m = replaceOnce(m, [[	local amount = HammerService.Power(st) * Economy.Mult(st, "power") * st.combo
	local _, pos = job:AddWork(amount, plr.UserId, { pos = hrp.Position })]], [[	local amount = isMega and 1 or (HammerService.Power(st) * Economy.Mult(st, "power") * st.combo)
	local _, pos = job:AddWork(amount, plr.UserId, { pos = hrp.Position })]])
m = replaceOnce(m, [[				if job.kind == "contract" or job.kind == "mega" then best = best or job end]],
	[[				if job.kind == "mega" then best = job elseif job.kind == "contract" and not (best and best.kind == "mega") then best = best or job end]])
m = replaceOnce(m, [[	local megaWork = math.max(0.25, 800 * math.max(1, n) * avgPower / 6400)]],
	[[	-- every hit at the tower is 1 work (the same for everyone): about 600 hits per builder on the server (~3 minutes)
	local megaWork = (Config.Mega.hitsPerBuilder or 600) * math.max(1, n) / 6400]])
assert(loadstring(m), "compile Main")

-- the client swings at the tower's speed too (it waits its hammer's cooldown between hits)
local Client = game.StarterPlayer.StarterPlayerScripts.Client
local s = Client.Source
s = replaceOnce(s, [[function SW.cooldown()
	local H = require(RS.Shared.Hammers)]], [[function SW.cooldown()
	local H = require(RS.Shared.Hammers)
	-- at the Mega Project everyone swings at the same speed
	local ms = RS:GetAttribute("MegaStatus") == "active" and Map:FindFirstChild("MegaSite")
	local so = ms and ms:FindFirstChild("SiteOrigin")
	local me = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if so and me and Vector2.new(me.Position.X - so.Position.X, me.Position.Z - so.Position.Z).Magnitude <= (ms:GetAttribute("Radius") or 58) then
		return Config.Mega.hitCooldown or 0.3
	end]])
assert(loadstring(s), "compile Client")
Main.Source = m
Client.Source = s
return "mega fair"
