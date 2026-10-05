-- one-off patch (run in Edit): the Lucky Spin, rebalanced
--  * every spin is worth its price (R$19 / 40 Gems): the most common prizes are already worth about one spin,
--    rarer ones much more, and the odds of everything are shown in the spin window (Roblox rules for paid random items)
--  * rarities (COMMON .. MYTHIC) with colours; the MYTHIC prize is the Thunderclap Hammer (0.1%, a R$499 pass);
--    if you already own it you get 1,500 Gems instead
--  * new prizes: free spins, Rush Crew, 2x Power, materials, blueprints, mega jackpots
--  * Epic+ wins are announced to the whole server
--  * 1 spin = R$19, 5 spins = R$79 (the products keep their keys; their ids are still 0 until created on the Creator Hub)
local function replaceOnce(src, old, new)
	local a, b = src:find(old, 1, true)
	assert(a, "not found: " .. old:sub(1, 80))
	assert(not src:find(old, b + 1, true), "found twice: " .. old:sub(1, 80))
	return src:sub(1, a - 1) .. new .. src:sub(b + 1)
end

local Cfg = game.ReplicatedStorage.Shared.Config
local cfg = Cfg.Source
if not cfg:find("SPIN_V2", 1, true) then
	local a = cfg:find("Config.Spin = {", 1, true)
	local b = select(2, cfg:find("\n}\n", a, true))
	assert(a and b, "spin block")
	cfg = cfg:sub(1, a - 1) .. [[Config.Spin = { -- SPIN_V2
	cooldown = 4 * 3600,
	gemCost = 40,
	-- weights add up to 100, so a weight is the chance in %. art = atlas icon ("storm" = the Thunderclap picture)
	prizes = {
		-- COMMON: already about one spin's worth
		{ kind = "cash", mult = 2, weight = 20, rarity = "common", art = "cash", icon = "💵", name = "Cash Bag" },
		{ kind = "gems", amount = 30, weight = 12, rarity = "common", art = "gem", icon = "💎", name = "30 Gems" },
		{ kind = "boost", boost = "cash", secs = 600, weight = 10, rarity = "common", art = "up_cash", icon = "💰", name = "2x Cash 10 min" },
		{ kind = "boost", boost = "strength", secs = 600, weight = 9, rarity = "common", art = "up_strength", icon = "💪", name = "2x Strength 10 min" },
		-- UNCOMMON
		{ kind = "cash", mult = 5, weight = 10, rarity = "uncommon", art = "coins", icon = "💰", name = "Cash Stack" },
		{ kind = "gems", amount = 60, weight = 8, rarity = "uncommon", art = "gem", icon = "💎", name = "60 Gems" },
		{ kind = "boost", boost = "power", secs = 900, weight = 6, rarity = "uncommon", art = "up_power", icon = "⚡", name = "2x Power 15 min" },
		{ kind = "rush", secs = 900, weight = 5, rarity = "uncommon", art = "up_crew", icon = "👷", name = "Rush Crew 15 min" },
		{ kind = "mat", mat = "steel", amount = 10, weight = 5, rarity = "uncommon", art = "backpack", icon = "🔩", name = "10 Steel Beams" },
		-- RARE
		{ kind = "spins", amount = 3, weight = 4, rarity = "rare", art = "spin", icon = "🎰", name = "3 Free Spins" },
		{ kind = "bp", bp = "gold", weight = 3, rarity = "rare", art = "portfolio", icon = "📜", name = "Gold Blueprint" },
		{ kind = "gems", amount = 150, weight = 3, rarity = "rare", art = "gem", icon = "💎", name = "150 Gems" },
		{ kind = "cash", mult = 12, weight = 2, rarity = "rare", art = "store", icon = "🏦", name = "Cash Vault" },
		-- EPIC
		{ kind = "boost", boost = "cash", secs = 3600, weight = 1.2, rarity = "epic", art = "up_cash", icon = "💰", name = "2x Cash 1 HOUR" },
		{ kind = "bp", bp = "diamond", weight = 0.8, rarity = "epic", art = "portfolio", icon = "📜", name = "Diamond Blueprint" },
		{ kind = "gems", amount = 500, weight = 0.5, rarity = "epic", art = "gem", icon = "💎", name = "500 Gems" },
		-- LEGENDARY
		{ kind = "cash", mult = 40, weight = 0.3, rarity = "legend", art = "store", icon = "🤑", name = "MEGA JACKPOT", jackpot = true },
		{ kind = "gems", amount = 1500, weight = 0.1, rarity = "legend", art = "gem", icon = "💎", name = "1,500 Gems", jackpot = true },
		-- MYTHIC: the Thunderclap Hammer (R$499 pass). Already yours? 1,500 Gems instead.
		{ kind = "pass", pass = "stormhammer", fallbackGems = 1500, weight = 0.1, rarity = "mythic", art = "storm", icon = "⚡", name = "THUNDERCLAP HAMMER", jackpot = true },
	},
}
]] .. cfg:sub(b + 1)
	cfg = replaceOnce(cfg, [[{ key = "spin1", id = 0, price = 10,]], [[{ key = "spin1", id = 0, price = 19,]])
	cfg = replaceOnce(cfg, [[{ key = "spins3", id = 0, price = 99, icon = "🎰", name = "3 Lucky Spins", desc = "Three extra spins on the Lucky Spin (odds shown in the spin window).", spins = 3 },]],
		[[{ key = "spins3", id = 0, price = 79, icon = "🎰", name = "5 Lucky Spins", desc = "Five spins on the Lucky Spin, 17% cheaper than one by one (odds shown in the spin window).", spins = 5 },]])
	assert(loadstring(cfg), "Config compile")
end

local Main = game.ServerScriptService.Game.Main
local m = Main.Source
if not m:find("SpinBig", 1, true) then
	m = replaceOnce(m, [[		elseif p.kind == "bp" and d.Items and d.Items.bps then
			d.Items.bps[p.bp] = (d.Items.bps[p.bp] or 0) + 1
			CompanyService.Publish(plr)
		end
		saveSoon(plr)
	end]], [[		elseif p.kind == "bp" and d.Items and d.Items.bps then
			d.Items.bps[p.bp] = (d.Items.bps[p.bp] or 0) + 1
			CompanyService.Publish(plr)
		elseif p.kind == "rush" then
			d.RushCrewUntil = math.max(os.time(), tonumber(d.RushCrewUntil) or 0) + (p.secs or 900)
			syncRushCrew(plr)
		elseif p.kind == "spins" then
			local sp = spinData(st)
			sp.extra += p.amount or 1
			publishSpin(plr, st)
		elseif p.kind == "pass" then
			-- the Thunderclap Hammer: yours for good (saved like a pass given in game); already yours = Gems instead
			st.passes = st.passes or {}
			if st.passes[p.pass] then
				addGems(plr, p.fallbackGems or 1500, "Lucky Spin")
			else
				st.passes[p.pass] = true
				d.AdminPasses = type(d.AdminPasses) == "table" and d.AdminPasses or {}
				d.AdminPasses[p.pass] = true
				if p.pass == Config.StormHammer.pass then
					d.EquipTool = nil
					plr:SetAttribute("EquipTool", "")
					st.stormGiven = false
				end
				applyPasses(plr)
				local pass
				for _, q in ipairs(Config.Store.passes) do if q.key == p.pass then pass = q end end
				feedback(plr, "Purchased", { name = pass and pass.name or p.name, kind = "pass" })
			end
		end
		-- big wins are news for the whole server
		if p.rarity == "epic" or p.rarity == "legend" or p.rarity == "mythic" then
			FeedbackRE:FireAllClients("SpinBig", { user = plr.UserId, name = plr.DisplayName, prize = p.name, rarity = p.rarity })
		end
		saveSoon(plr)
	end]])
	assert(loadstring(m), "Main compile")
end

Cfg.Source = cfg
Main.Source = m
return "spin patched"
