-- one-off patch (run in Edit): PROJECT COMPLETE shows the materials that building gave you (a row of pictures with how
-- many), and a finished contract always gives materials, however fast it was built
--  * CompanyService: the finds on your own contract (build hits) are counted per material on the job (job.found); the
--    finds it guarantees at the end are added to it; a finished contract that found nothing at all gives at least one
--  * Main: the Complete card gets the list (id, how many, name, picture)
--  * Client: the card shows a "Materials" row with the pictures; the old Portfolio window inside the Client (dead code:
--    MoreUI draws it) goes, to keep the Client under 200 000 characters
local function replaceOnce(src, old, new)
	local a, b = src:find(old, 1, true)
	assert(a, "not found: " .. old:sub(1, 80))
	assert(not src:find(old, b + 1, true), "found twice: " .. old:sub(1, 80))
	return src:sub(1, a - 1) .. new .. src:sub(b + 1)
end
local report = {}

-- CompanyService ---------------------------------------------------------------------------------------------
local CS = game.ServerScriptService.Game.CompanyService
local s = CS.Source
if not s:find("job.found", 1, true) then
	s = replaceOnce(s, [=[	if job and job.ownerId == plr.UserId then job.ownerFinds = (job.ownerFinds or 0) + 1 end]=],
		[=[	if job and job.ownerId == plr.UserId then
		job.ownerFinds = (job.ownerFinds or 0) + 1
		job.found = job.found or {}
		job.found[id] = (job.found[id] or 0) + qty -- (the PROJECT COMPLETE card lists them)
	end]=])
	s = replaceOnce(s, [=[	local n = math.floor(target) + (math.random() < target % 1 and 1 or 0) - (job.ownerFinds or 0)
	if n <= 0 then return end]=], [=[	local n = math.floor(target) + (math.random() < target % 1 and 1 or 0) - (job.ownerFinds or 0)
	job.found = job.found or {}
	-- (a finished contract always gives something, however fast the crew built it)
	if n <= 0 and next(job.found) == nil then n = 1 end
	if n <= 0 then return end]=])
	s = replaceOnce(s, [=[	for i, id in ipairs(order) do
		st.data.Items.mats[id] = (st.data.Items.mats[id] or 0) + got[id]]=], [=[	for i, id in ipairs(order) do
		st.data.Items.mats[id] = (st.data.Items.mats[id] or 0) + got[id]
		job.found[id] = (job.found[id] or 0) + got[id]]=])
	assert(loadstring(s), "CompanyService compile")
	CS.Source = s
	table.insert(report, "CompanyService")
end

-- Main: the list on the Complete card -------------------------------------------------------------------------------
local Main = game.ServerScriptService.Game.Main
local m = Main.Source
if not m:find("mats = foundList", 1, true) then
	m = replaceOnce(m, [=[		if not okF then warn("ContractFinds:", errF) end]=], [=[		if not okF then warn("ContractFinds:", errF) end
		-- what this building gave you (its build hits + the finds at the end), for the PROJECT COMPLETE card
		local foundList = {}
		for _, mat in ipairs(CompanyData.Materials) do
			local q = job.found and job.found[mat.id]
			if q and q > 0 then table.insert(foundList, { id = mat.id, qty = q, name = mat.name, image = mat.image }) end
		end]=])
	m = replaceOnce(m, [=[			time = job.elapsed, target = c.targetTime, center = job:Center(), size = job.size, first = st.data.Portfolio[c.id] == 1, front = job.origin.LookVector })]=],
		[=[			time = job.elapsed, target = c.targetTime, center = job:Center(), size = job.size, first = st.data.Portfolio[c.id] == 1, front = job.origin.LookVector,
			mats = foundList })]=])
	assert(loadstring(m), "Main compile")
	Main.Source = m
	table.insert(report, "Main")
end

-- Client: the Materials row ------------------------------------------------------------------------------------------
local Client = game.StarterPlayer.StarterPlayerScripts.Client
local c = Client.Source
if not c:find("row.mats", 1, true) then
	-- the old Portfolio window (MoreUI.Portfolio draws it): only the hand-over stays
	local head = "function showPortfolio()\n\tif _G.__CE_MoreUI then return _G.__CE_MoreUI.Portfolio() end\n"
	local a = c:find(head, 1, true)
	assert(a, "showPortfolio not found")
	local e1, e2 = c:find("\nend\n", a, true)
	c = c:sub(1, a - 1) .. "function showPortfolio()\n\tif _G.__CE_MoreUI then return _G.__CE_MoreUI.Portfolio() end\nend\n" .. c:sub(e2 + 1)
	c = replaceOnce(c, [=[		rf.BackgroundTransparency = 1
		task.delay(0.25 + i * 0.22, function()
			UI.tween(rf, 0.25, { BackgroundTransparency = 0.1 })
			v.Text = row[2]]=], [=[		rf.BackgroundTransparency = 1
		-- the materials it gave: their pictures with how many, on the right
		local hold
		if row.mats then
			hold = new("Frame", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), Size = UDim2.new(0.66, 0, 1, -4), BackgroundTransparency = 1, Visible = false, ZIndex = 43, Parent = rf })
			UI.list(Enum.FillDirection.Horizontal, 10, Enum.HorizontalAlignment.Right, Enum.VerticalAlignment.Center).Parent = hold
			for j, mt in ipairs(row.mats) do
				local ch = new("Frame", { Size = UDim2.fromOffset(0, 34), AutomaticSize = Enum.AutomaticSize.X, BackgroundTransparency = 1, LayoutOrder = j, ZIndex = 43, Parent = hold })
				UI.list(Enum.FillDirection.Horizontal, 3, nil, Enum.VerticalAlignment.Center).Parent = ch
				new("ImageLabel", { Size = UDim2.fromOffset(32, 32), BackgroundTransparency = 1, Image = mt.image or "", ScaleType = Enum.ScaleType.Fit, LayoutOrder = 1, ZIndex = 44, Parent = ch })
				local q = UI.label({ Size = UDim2.fromOffset(0, 32), AutomaticSize = Enum.AutomaticSize.X, Text = "x" .. mt.qty, Font = T.title, TextSize = 21, TextColor3 = Color3.fromRGB(255, 214, 110), LayoutOrder = 2, ZIndex = 44, Parent = ch })
				UI.textStroke(0.2, 2).Parent = q
			end
		end
		task.delay(0.25 + i * 0.22, function()
			UI.tween(rf, 0.25, { BackgroundTransparency = 0.1 })
			if hold then hold.Visible = true; local s3 = new("UIScale", { Scale = 1.5, Parent = hold }); UI.tween(s3, 0.3, { Scale = 1 }, Enum.EasingStyle.Back) end
			v.Text = row[2]]=])
	c = replaceOnce(c, [=[		if d.bonus > 0 then table.insert(rows, 2, { "⚡ Speed Bonus", "+" .. Config.FormatMoney(d.bonus), Color3.fromRGB(255, 140, 60) }) end]=],
		[=[		if d.bonus > 0 then table.insert(rows, 2, { "⚡ Speed Bonus", "+" .. Config.FormatMoney(d.bonus), Color3.fromRGB(255, 140, 60) }) end
		if d.mats and #d.mats > 0 then table.insert(rows, #rows, { "🧱 Materials", "", T.text, mats = d.mats }) end]=])
	assert(#c < 200000, "Client too big: " .. #c)
	assert(loadstring(c), "Client compile")
	Client.Source = c
	table.insert(report, "Client (" .. #c .. ")")
end
return table.concat(report, " · ")
