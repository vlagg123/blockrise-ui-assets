-- one-off patch (run in Edit): hold-E buy prompts on the BlockRise Motors display cars (VehicleService)
local VS = game.ServerScriptService.Game.VehicleService
local s = VS.Source
local function replaceOnce(src, old, new)
	local a, b = src:find(old, 1, true)
	assert(a, "not found: " .. old:sub(1, 80))
	assert(not src:find(old, b + 1, true), "found twice: " .. old:sub(1, 80))
	return src:sub(1, a - 1) .. new .. src:sub(b + 1)
end
if s:find("DealerPrompt", 1, true) then return "already patched" end
s = replaceOnce(s, [[	Players.PlayerRemoving:Connect(despawn)
	task.spawn(function()]], [[	Players.PlayerRemoving:Connect(despawn)
	-- BlockRise Motors: hold E (1.5 s) on a display car to buy it right there (owned: spawn it; Robux cars: the pass prompt).
	-- The prompt is drawn by the client (DealerUI) so it can show your own price / OWNED state.
	local MarketplaceService = game:GetService("MarketplaceService")
	local function passOf(cfg)
		for _, p in ipairs(Config.Store.passes) do if p.key == cfg.pass then return p end end
	end
	local function addDealerPrompt(m)
		local id = m:GetAttribute("VehicleId")
		local cfg = id and Config.VehicleById[id]
		local root = m.PrimaryPart or m:FindFirstChildWhichIsA("BasePart")
		if not cfg or not root or root:FindFirstChild("DealerPrompt") then return end
		local pp = Instance.new("ProximityPrompt")
		pp.Name = "DealerPrompt"
		pp.ActionText = cfg.pass and "Get" or "Buy"
		pp.ObjectText = cfg.name
		pp.HoldDuration = 1.5
		pp.KeyboardKeyCode = Enum.KeyCode.E
		pp.GamepadKeyCode = Enum.KeyCode.ButtonX
		pp.MaxActivationDistance = 13
		pp.RequiresLineOfSight = false
		pp.Style = Enum.ProximityPromptStyle.Custom
		pp:SetAttribute("VehicleId", cfg.id)
		pp.Parent = root
		pp.Triggered:Connect(function(plr)
			local st = ctx.S[plr]
			if not st then return end
			if owns(st, cfg) then
				local ok, msg = action(plr, "spawn", cfg.id)
				if not ok then ctx.feedback(plr, "DealerMsg", { text = "⚠️ " .. tostring(msg or "Can't spawn it here") }) end
				return
			end
			if cfg.pass then
				local p = passOf(cfg)
				if p and (p.id or 0) > 0 then
					MarketplaceService:PromptGamePassPurchase(plr, p.id)
				else
					ctx.feedback(plr, "DealerMsg", { text = "⭐ " .. cfg.name .. " is coming soon to the Store" })
				end
				return
			end
			local ok, msg = action(plr, "buy", cfg.id)
			if not ok then ctx.feedback(plr, "DealerMsg", { text = "⚠️ " .. tostring(msg or "Can't buy that") }) end
		end)
	end
	task.spawn(function()
		local map = workspace:WaitForChild("Map", 30)
		local plaza = map and map:WaitForChild("Plaza", 30)
		local dealer = plaza and plaza:WaitForChild("CarDealer", 30)
		if not dealer then return end
		for _, m in ipairs(dealer:GetChildren()) do
			if m:IsA("Model") and m:GetAttribute("VehicleId") then addDealerPrompt(m) end
		end
	end)
	task.spawn(function()]])
assert(loadstring(s), "compile")
VS.Source = s
return "dealer prompts added"
