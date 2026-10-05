-- one-off patch (run in Edit): big banners never cover a window, a reward card or a cinematic
--  * they wait until the screen is free (the welcome card, PROJECT COMPLETE, the Shop...)
--  * "X DONE / Next: Y" stage banners are news for a moment: a newer one replaces a waiting one, a stale one is dropped,
--    and they are all dropped when the project completes
local function replaceOnce(src, old, new)
	local a, b = src:find(old, 1, true)
	assert(a, "not found: " .. old:sub(1, 80))
	assert(not src:find(old, b + 1, true), "found twice: " .. old:sub(1, 80))
	return src:sub(1, a - 1) .. new .. src:sub(b + 1)
end
local Client = game.StarterPlayer.StarterPlayerScripts.Client
local s = Client.Source
if s:find("BANNERS_WAIT", 1, true) then return "already patched" end

s = replaceOnce(s, [[-- banners are queued: only one on screen at a time (max 3 waiting)
local bannerQueue, bannerBusy = {}, false
local function banner(title, sub, color)
	if #bannerQueue >= 3 then table.remove(bannerQueue, 1) end
	table.insert(bannerQueue, { title, sub, color })
	if bannerBusy then return end
	bannerBusy = true
	task.spawn(function()
		while #bannerQueue > 0 do
			local b = table.remove(bannerQueue, 1)
			local t0 = os.clock()
			while player.PlayerGui:FindFirstChild("Intro") and os.clock() - t0 < 120 do task.wait(0.3) end
			showBannerNow(b[1], b[2], b[3])
			task.wait(2.8)
		end
		bannerBusy = false
	end)
end]], [[-- banners are queued: only one on screen at a time (max 3 waiting). BANNERS_WAIT: they never cover a window,
-- a reward card or a cinematic (they wait for it to close); "stage done" banners are only news for a moment:
-- a newer one replaces a waiting one and a stale one is dropped
local bannerQueue, bannerBusy = {}, false
local openCards = 0                          -- reward cards on screen (PROJECT COMPLETE...)
local windowOpen = function() return false end -- set once the window exists
local function screenBusy()
	return player.PlayerGui:FindFirstChild("Intro") ~= nil or openCards > 0 or gui:GetAttribute("Cinematic") == true or windowOpen()
end
local function clearStageBanners()
	for i = #bannerQueue, 1, -1 do if bannerQueue[i].kind == "stage" then table.remove(bannerQueue, i) end end
end
local function banner(title, sub, color, kind)
	if kind == "stage" then clearStageBanners() end
	if #bannerQueue >= 3 then table.remove(bannerQueue, 1) end
	table.insert(bannerQueue, { title, sub, color, kind = kind, at = os.clock() })
	if bannerBusy then return end
	bannerBusy = true
	task.spawn(function()
		while #bannerQueue > 0 do
			local b = table.remove(bannerQueue, 1)
			local t0 = os.clock()
			while screenBusy() and os.clock() - t0 < 120 do task.wait(0.3) end
			if not (b.kind == "stage" and os.clock() - b.at > 5) then
				showBannerNow(b[1], b[2], b[3])
				task.wait(2.8)
			end
		end
		bannerBusy = false
	end)
end]])

-- the window exists from here on
s = replaceOnce(s, "local modalScale = new(\"UIScale\", { Parent = modal })\n",
	"local modalScale = new(\"UIScale\", { Parent = modal })\nwindowOpen = function() return modal.Visible end\n")

-- reward cards count while they are on screen
s = replaceOnce(s, [[	local bg = fs(new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 1, ZIndex = 40, Parent = gui }))
	UI.tween(bg, 0.3, { BackgroundTransparency = 0.5 })]], [[	local bg = fs(new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 1, ZIndex = 40, Parent = gui }))
	openCards += 1
	bg.Destroying:Connect(function() openCards = math.max(0, openCards - 1) end)
	UI.tween(bg, 0.3, { BackgroundTransparency = 0.5 })]])

-- stage banners are tagged; the project end drops the waiting ones
s = replaceOnce(s, [[		banner("✔ " .. string.upper(d.name) .. " DONE", d.next and ("Next: " .. d.next) or "", T.green)]],
	[[		banner("✔ " .. string.upper(d.name) .. " DONE", d.next and ("Next: " .. d.next) or "", T.green, "stage")]])
s = replaceOnce(s, [[	elseif kind == "Complete" then
		_G.__CE_ShowComplete(d)
	elseif kind == "HomeComplete" then
		_G.__CE_ShowHome(d)]], [[	elseif kind == "Complete" then
		clearStageBanners()
		_G.__CE_ShowComplete(d)
	elseif kind == "HomeComplete" then
		clearStageBanners()
		_G.__CE_ShowHome(d)]])

assert(loadstring(s), "Client compile")
Client.Source = s
return "banners patched"
