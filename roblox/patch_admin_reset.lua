-- one-off patch (run in Edit): Admin panel "reset MY progress" (owner only, only their own profile).
-- The profile becomes a brand-new one (Robux purchases come back from the ledger, real game passes are checked again
-- on the next join), it is saved right away, and the owner is sent out to rejoin as a brand-new builder (tutorial
-- from step 1). Other players can never be reset from the panel: the server refuses any target but the caller.
local function replaceOnce(src, old, new)
	local a, b = src:find(old, 1, true)
	assert(a, "not found: " .. old:sub(1, 80))
	assert(not src:find(old, b + 1, true), "found twice: " .. old:sub(1, 80))
	return src:sub(1, a - 1) .. new .. src:sub(b + 1)
end
local Main = game.ServerScriptService.Game.Main
local s = Main.Source
if s:find("ACT.resetme", 1, true) then return "already patched" end

s = replaceOnce(s, [[	local function root(p) return p.Character and p.Character:FindFirstChild("HumanoidRootPart") end
	function ACT.teleport(plr, st, v, admin)]], [[	-- start over from zero: your own profile only, and only with the confirmation word
	function ACT.resetme(plr, st, v, admin)
		if plr ~= admin then return false, "only your own progress can be reset" end
		if type(v) ~= "table" or v.confirm ~= "RESET" then return false, "not confirmed" end
		if st.adminResetting then return false, "already resetting" end
		st.adminResetting = true
		local fresh = defaultData()
		for k in pairs(st.data) do st.data[k] = nil end
		for k, val in pairs(fresh) do st.data[k] = val end
		pcall(restorePaid, plr, st) -- Robux purchases come back, like after any wipe
		pcall(CompanyService.Sanitize, st.data)
		pcall(RebirthService.Sanitize, st.data)
		pcall(VehicleService.Sanitize, st.data)
		warn("[Admin] " .. admin.Name .. " reset their own progress")
		task.spawn(function()
			pcall(saveData, plr, false, true)
			task.wait(1.5)
			if plr.Parent then plr:Kick("Progresul tau a fost resetat de la 0. Intra din nou in joc ca sa incepi ca un jucator nou.") end
		end)
		return true, "progress reset: you'll be sent out in a moment, then rejoin"
	end

	local function root(p) return p.Character and p.Character:FindFirstChild("HumanoidRootPart") end
	function ACT.teleport(plr, st, v, admin)]])

assert(loadstring(s), "Main compile")
Main.Source = s
return "admin reset patched"
