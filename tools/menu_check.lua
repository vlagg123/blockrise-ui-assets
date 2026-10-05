-- Studio debug helper (run in the Client while a window is open): lists text that doesn't fit, icons with no size,
-- pieces of a card that spill out, overlap, sit closer than 5 px to each other or closer than 6 px to the card edge.
_G.__chk = function()
	local plr = game.Players.LocalPlayer
	local gui = plr.PlayerGui:FindFirstChild("HUD")
	local win = gui and gui:FindFirstChild("Window")
	if not win or not win.Visible then return "no window open" end
	local issues = {}
	local k = win.AbsoluteSize.X / math.max(1, win.Size.X.Offset)
	local function rect(o) return o.AbsolutePosition, o.AbsolutePosition + o.AbsoluteSize end
	local function name(o) return (o:GetFullName():gsub("^.-Window%.", "")) end
	local function gaps(a, b)
		local a0, a1 = rect(a); local b0, b1 = rect(b)
		return (math.min(a1.X, b1.X) - math.max(a0.X, b0.X)) / k, (math.min(a1.Y, b1.Y) - math.max(a0.Y, b0.Y)) / k
	end
	local function shown(o)
		local p = o
		while p and p ~= win do
			if p:IsA("GuiObject") and not p.Visible then return false end
			p = p.Parent
		end
		return true
	end
	for _, d in ipairs(win:GetDescendants()) do
		if (d:IsA("TextLabel") or d:IsA("TextButton")) and d.Text ~= "" and shown(d) and d.AbsoluteSize.X > 0 and not d.TextFits then
			table.insert(issues, "TEXT: " .. name(d) .. " '" .. d.Text:sub(1, 30) .. "'")
		end
		if d.Name == "Icon" and d:IsA("GuiObject") and shown(d) and (d.AbsoluteSize.X < 4 or d.AbsoluteSize.Y < 4) then
			table.insert(issues, "ICON 0: " .. name(d))
		end
	end
	local SKIP = { Bg = true, Art = true, CardBg = true }
	for _, card in ipairs(win:GetDescendants()) do
		if card:IsA("Frame") and (card.Name == "Tile" or card.Name == "Row" or card.Name == "Banner" or card.Name == "Card") and shown(card) then
			local items = {}
			for _, ch in ipairs(card:GetChildren()) do
				if ch:IsA("GuiObject") and ch.Visible and not SKIP[ch.Name] then table.insert(items, ch) end
			end
			local c0, c1 = rect(card)
			for i, a in ipairs(items) do
				local a0, a1 = rect(a)
				local l, t, r, b = (a0.X - c0.X) / k, (a0.Y - c0.Y) / k, (c1.X - a1.X) / k, (c1.Y - a1.Y) / k
				if math.min(l, t, r, b) < -1 then table.insert(issues, "SPILL: " .. name(a))
				elseif a.Name ~= "Chip" and math.min(l, r, b) < 6 then table.insert(issues, string.format("EDGE (%.0f,%.0f,%.0f,%.0f): %s", l, t, r, b, name(a))) end
				for j = i + 1, #items do
					local ox, oy = gaps(a, items[j])
					if ox > 1 and oy > 1 then table.insert(issues, "OVERLAP: " .. name(a) .. " x " .. name(items[j]))
					elseif ox > 1 and oy > -5 then table.insert(issues, string.format("TIGHT %.0fpx: %s / %s", -oy, name(a), name(items[j]))) end
				end
			end
			for _, row in ipairs(card:GetChildren()) do
				if row.Name == "Stats" or row.Name == "Chips" then
					local _, r1 = rect(row)
					for _, ch in ipairs(row:GetChildren()) do
						if ch:IsA("GuiObject") then
							local _, e1 = rect(ch)
							if e1.X > r1.X + 1 then table.insert(issues, "CHIP OUT: " .. name(ch)) end
						end
					end
				end
			end
		end
	end
	local seen, out = {}, {}
	for _, s in ipairs(issues) do if not seen[s] then seen[s] = true; table.insert(out, s) end end
	return #out == 0 and "clean" or table.concat(out, "\n")
end
return _G.__chk()
