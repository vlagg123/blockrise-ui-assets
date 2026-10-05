-- one-off patch (run in Edit): the Skip Build Animation pass (39 R$, id 0 until it is created on the Creator Hub)
--  * during the "building done" camera fly-around a SKIP button shows: free with the pass, R$39 without it
--  * with the pass the fly-around can be switched off for good (Store > PASSES: SKIP ON / OFF); the reward card comes straight away
--  * the choice is saved (data.SkipAnimOff); the player's "SkipAnim" attribute = owns the pass and has it on
local function replaceOnce(src, old, new)
	local a, b = src:find(old, 1, true)
	assert(a, "not found: " .. old:sub(1, 80))
	assert(not src:find(old, b + 1, true), "found twice: " .. old:sub(1, 80))
	return src:sub(1, a - 1) .. new .. src:sub(b + 1)
end

-- Config: the pass
local Cfg = game.ReplicatedStorage.Shared.Config
local cfg = Cfg.Source
if not cfg:find('key = "skipanim"', 1, true) then
	cfg = replaceOnce(cfg, [[		{ key = "stormhammer", id = 0, price = 499,]], [[		{ key = "skipanim", id = 0, price = 39, icon = "⏭️", name = "Skip Build Animation", desc = "Skip the camera fly-around when a building is done: straight to your reward. Turn it on / off any time in the Store." },
		{ key = "stormhammer", id = 0, price = 499,]])
	assert(loadstring(cfg), "Config compile")
end

-- Server: the on / off switch and the attribute
local Main = game.ServerScriptService.Game.Main
local m = Main.Source
if not m:find('kind == "skipanim"', 1, true) then
	m = replaceOnce(m, [[		plr:SetAttribute("AutoTrain", st.autoTrain)
	end
end)]], [[		plr:SetAttribute("AutoTrain", st.autoTrain)
	elseif kind == "skipanim" then
		-- Skip Build Animation: on / off (saved)
		st.data.SkipAnimOff = not on
		plr:SetAttribute("SkipAnim", (st.passes and st.passes.skipanim) == true and not st.data.SkipAnimOff)
	end
end)]])
	m = replaceOnce(m, [[	for _, p in ipairs(Config.Store.passes) do plr:SetAttribute("Pass_" .. p.key, st.passes[p.key] == true) end
	sync(plr)]], [[	for _, p in ipairs(Config.Store.passes) do plr:SetAttribute("Pass_" .. p.key, st.passes[p.key] == true) end
	plr:SetAttribute("SkipAnim", st.passes.skipanim == true and st.data.SkipAnimOff ~= true)
	sync(plr)]])
	assert(loadstring(m), "Main compile")
end

-- Client: the SKIP button on the fly-around, and no fly-around at all when it is switched on
local Client = game.StarterPlayer.StarterPlayerScripts.Client
local c = Client.Source
if not c:find("SkipCine", 1, true) then
	c = replaceOnce(c, [[local function cinematic(center, size, front, done)
	inCinematic = true]], [[local function cinematic(center, size, front, done)
	-- Skip Build Animation (pass, switched on in the Store): no fly-around, the reward card comes straight away
	if player:GetAttribute("SkipAnim") == true then
		emit(center + Vector3.new(0, size.Y / 2, 0), "confetti", nil, 120)
		if done then task.defer(done) end
		return
	end
	inCinematic = true]])
	c = replaceOnce(c, [[	local t0, dur = os.clock(), 4.5
	local conn
	conn = RunService.RenderStepped:Connect(function()]], [[	local t0, dur = os.clock(), 4.5
	local conn, finished, skipGui
	local function finish()
		if finished then return end
		finished = true
		if conn then conn:Disconnect() end
		if skipGui then skipGui:Destroy() end
		camera.CameraType = prevType == Enum.CameraType.Scriptable and Enum.CameraType.Custom or prevType
		inCinematic = false
		if done then done() end
	end
	-- SKIP: free with the pass, otherwise it offers the pass (R$39)
	do
		local pass
		for _, p in ipairs(Config.Store.passes) do if p.key == "skipanim" then pass = p end end
		local owned = player:GetAttribute("Pass_skipanim") == true
		if pass and (owned or (pass.id or 0) > 0 or RunService:IsStudio()) then
			skipGui = new("ScreenGui", { Name = "SkipCine", IgnoreGuiInset = true, ResetOnSpawn = false, DisplayOrder = 70, Parent = player:WaitForChild("PlayerGui") })
			new("UIScale", { Scale = uiScale.Scale, Parent = skipGui })
			local label = owned and "SKIP  ⏭" or ("SKIP  ⏭   R$" .. tostring(pass.price or 39))
			local b = UI.button(label, owned and T.blue or T.accent, owned and T.blue2 or T.accent2, { AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -28, 1, -28),
				Size = UDim2.fromOffset(owned and 170 or 230, 56), TextSize = 22, Shine = not owned, Parent = skipGui })
			b.Activated:Connect(function()
				sound2D(S.Click, 0.4)
				if player:GetAttribute("Pass_skipanim") == true then
					finish()
				elseif (pass.id or 0) > 0 then
					MarketplaceService:PromptGamePassPurchase(player, pass.id)
				else
					toast("⏭️ Skip Build Animation: coming soon (R$" .. tostring(pass.price or 39) .. ")", T.accent, 2.5)
				end
			end)
			-- bought it right here: skip this one too
			local pc
			pc = player:GetAttributeChangedSignal("Pass_skipanim"):Connect(function()
				if player:GetAttribute("Pass_skipanim") == true then pc:Disconnect(); finish() end
			end)
			skipGui.Destroying:Connect(function() pc:Disconnect() end)
		end
	end
	conn = RunService.RenderStepped:Connect(function()]])
	c = replaceOnce(c, [[		camera.CFrame = cf
		if t >= 1 then
			conn:Disconnect()
			camera.CameraType = prevType == Enum.CameraType.Scriptable and Enum.CameraType.Custom or prevType
			inCinematic = false
			if done then done() end
		end
	end)]], [[		camera.CFrame = cf
		if t >= 1 then finish() end
	end)]])
	assert(loadstring(c), "Client compile")
end

Cfg.Source = cfg
Main.Source = m
Client.Source = c
return "skip animation patched"
