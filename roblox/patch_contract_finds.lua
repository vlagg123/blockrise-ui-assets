-- one-off patch (run in Edit): a finished contract always gives materials, however fast it was built.
-- Before, materials only dropped per build hit (1 in 30), so a strong player who builds a house in a few hits
-- (or lets the crew / machines do it) got no Steel Beams at all. Now every finished contract guarantees
-- Company.ContractFinds finds (more with a blueprint and with Lucky Finds); the finds its hits already turned up count.
local function replaceOnce(src, old, new)
	local a, b = src:find(old, 1, true)
	assert(a, "not found: " .. old:sub(1, 80))
	assert(not src:find(old, b + 1, true), "found twice: " .. old:sub(1, 80))
	return src:sub(1, a - 1) .. new .. src:sub(b + 1)
end

local RS = game:GetService("ReplicatedStorage")
local CompanyMod = RS.Shared.Company
local CS = game.ServerScriptService.Game.CompanyService
local Main = game.ServerScriptService.Game.Main
if CS.Source:find("CONTRACT_FINDS", 1, true) then return "already patched" end

-- backup of the server module before the change
local SS = game:GetService("ServerStorage")
if not SS:FindFirstChild("Backup_pre_finds") then
	local f = Instance.new("Folder")
	f.Name = "Backup_pre_finds"
	CS:Clone().Parent = f
	CompanyMod:Clone().Parent = f
	f.Parent = SS
end

-- 1) the number of finds a finished contract guarantees
local c = CompanyMod.Source
c = replaceOnce(c, [[function Company.DropAmount(tier) return 1 + math.floor((tier or 1) / 4) end
]], [[function Company.DropAmount(tier) return 1 + math.floor((tier or 1) / 4) end
-- a finished contract always gives at least this many finds, however fast it was built (finds from its build hits count)
Company.ContractFinds = 3
]])

-- 2) count the finds on your own contract, and top them up when it's finished
local s = CS.Source
s = replaceOnce(s, [[	plr:SetAttribute("Mat_" .. id, st.data.Items.mats[id])
	ctx.feedback(plr, "Loot", { id = id, qty = qty, pos = pos })
end
]], [[	plr:SetAttribute("Mat_" .. id, st.data.Items.mats[id])
	ctx.feedback(plr, "Loot", { id = id, qty = qty, pos = pos })
	-- CONTRACT_FINDS: finds on your own contract count towards the ones it guarantees when it's finished
	if job and job.ownerId == plr.UserId then job.ownerFinds = (job.ownerFinds or 0) + 1 end
end

-- a finished contract always gives materials, however fast it was built (a strong player needs only a few hits):
-- the finds its build hits didn't turn up are added now. Blueprint contracts (more work) and Lucky Finds give more.
function M.ContractFinds(plr, st, job, pos)
	local target = (Company.ContractFinds or 3) * ((job.meta and job.meta.timeMult) or 1) * Economy.Mult(st, "loot")
	local n = math.floor(target) + (math.random() < target % 1 and 1 or 0) - (job.ownerFinds or 0)
	if n <= 0 then return end
	local tier = tierOf(job)
	local got, order = {}, {}
	for _ = 1, math.min(n, 60) do
		local id = weighted(Company.DropTable(tier))
		if not got[id] then got[id] = 0; table.insert(order, id) end
		got[id] += Company.DropAmount(tier)
	end
	for i, id in ipairs(order) do
		st.data.Items.mats[id] = (st.data.Items.mats[id] or 0) + got[id]
		plr:SetAttribute("Mat_" .. id, st.data.Items.mats[id])
		-- one pop per material, side by side over the finished building
		local p = pos and pos + Vector3.new((i - (#order + 1) / 2) * 6, 0, 0)
		task.delay(0.3 + 0.35 * (i - 1), ctx.feedback, plr, "Loot", { id = id, qty = got[id], pos = p })
	end
end
]])

-- 3) a finished contract hands them out (guarded: nothing here may stop the contract from paying)
local m = Main.Source
m = replaceOnce(m, [[		CompanyService.RollBlueprint(owner, st, c)
]], [[		CompanyService.RollBlueprint(owner, st, c)
		local okF, errF = pcall(CompanyService.ContractFinds, owner, st, job, job:Center())
		if not okF then warn("ContractFinds:", errF) end
]])

assert(loadstring(c), "Company compile")
assert(loadstring(s), "CompanyService compile")
assert(loadstring(m), "Main compile")
CompanyMod.Source = c
CS.Source = s
Main.Source = m
return "contracts always give materials"
