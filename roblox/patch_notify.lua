-- one-off patch (run in Edit): big banners wait until the open window is closed; toasts draw above the window and
-- move to the bottom of the screen while a window is open (so they never sit on the window's header)
local Client = game.StarterPlayer.StarterPlayerScripts.Client
local s = Client.Source
local function replaceOnce(src, old, new)
	local a, b = src:find(old, 1, true)
	assert(a, "not found: " .. old:sub(1, 80))
	assert(not src:find(old, b + 1, true), "found twice: " .. old:sub(1, 80))
	return src:sub(1, a - 1) .. new .. src:sub(b + 1)
end
s = replaceOnce(s, [[			local b = table.remove(bannerQueue, 1)
			showBannerNow(b[1], b[2], b[3])]], [[			local b = table.remove(bannerQueue, 1)
			-- a banner never covers an open window: it waits (up to a minute) until the window is closed
			local w, t0 = gui:FindFirstChild("Window"), os.clock()
			while w and w.Visible and os.clock() - t0 < 60 do task.wait(0.25) end
			showBannerNow(b[1], b[2], b[3])]])
s = replaceOnce(s, [[	_G.__CE_ModalIcon = function(name) Icons.set(headerIcon, MODAL_ICON[name] or "star") end
end]], [[	_G.__CE_ModalIcon = function(name) Icons.set(headerIcon, MODAL_ICON[name] or "star") end
	-- toasts: above the window, and at the bottom of the screen while a window is open
	local th = gui:FindFirstChild("Toasts")
	if th then
		th.ZIndex = 40
		local lay = th:FindFirstChildOfClass("UIListLayout")
		local function placeToasts()
			if modal.Visible then
				th.AnchorPoint = Vector2.new(0.5, 1)
				th.Position = UDim2.new(0.5, 0, 1, -14)
				if lay then lay.VerticalAlignment = Enum.VerticalAlignment.Bottom end
			else
				th.AnchorPoint = Vector2.new(0.5, 0)
				th.Position = UDim2.new(0.5, 0, 0, (gui:GetAttribute("TopBand") or 62) + 8)
				if lay then lay.VerticalAlignment = Enum.VerticalAlignment.Top end
			end
		end
		modal:GetPropertyChangedSignal("Visible"):Connect(placeToasts)
		gui:GetAttributeChangedSignal("TopBand"):Connect(function() task.defer(placeToasts) end)
		placeToasts()
	end
end]])
Client.Source = s
return "notify patched"
