-- dev tool: the AI-generated models land in the Workspace under their prompt as a name; collect() files them in
-- ServerStorage.Gen2 under a short key, show(keys) lines them up on the plaza for a screenshot
local M = {}
M.Keys = {
	-- (the more specific ones first: a second style of a level, the hub buildings)
	{ "townhouse for a kids city builder game, pastel pink", "b4_2" }, { "apartment building for a kids city builder game, pastel mint", "b5_2" },
	{ "hammer shop", "shop_hammer" }, { "office building for a kids city builder game, warm", "b6_2" }, { "hotel building for a kids city builder game, mint", "b7_2" },
	{ "tower building for a kids city builder game, purple", "b8_2" }, { "skyscraper for a kids city builder game, teal", "b9_2" },
	{ "sky tower for a kids city builder game, white and gold", "b10_2" }, { "car dealership", "shop_cars" }, { "gym building", "shop_gym" },
	{ "trading post", "shop_trade" }, { "golden cartoon hammer standing", "hammer_gold" }, { "green canopy made of three soft round", "tree_green" },
	{ "several smooth round blobs on a short thick", "tree_seg" }, { "treasure crate", "crate" }, { "rounded grey boulder", "rock" }, { "picket fence", "fence" }, { "flower pot", "flowerpot" },
	{ "street lamp", "lamp" }, { "park bench", "bench" }, { "puffy cartoon bush", "bush" }, { "lying horizontally", "hammerA" },
	{ "sledgehammer", "hammerB" }, { "hot dog", "b1_1" }, { "ice cream", "b1_2" }, { "cottage", "b2_1" }, { "corner shop", "b3_1" },
	{ "townhouse", "b4_1" }, { "apartment", "b5_1" }, { "office", "b6_1" }, { "hotel", "b7_1" }, { "tall tower building", "b8_1" },
	{ "skyscraper", "b9_1" }, { "sky tower", "b10_1" }, { "three soft round blobs", "tree_green" }, { "one big round puffy", "tree_mint" },
}
function M.keyOf(name)
	local low = name:lower()
	for _, k in ipairs(M.Keys) do if low:find(k[1], 1, true) then return k[2] end end
end
function M.collect(extraKeys)
	local gen = game.ServerStorage:FindFirstChild("Gen2") or Instance.new("Folder")
	gen.Name = "Gen2"
	gen.Parent = game.ServerStorage
	local got = {}
	for _, c in ipairs(workspace:GetChildren()) do
		if c:IsA("Model") and c.Name ~= "World" and #c.Name > 30 then
			local k = (extraKeys and extraKeys[c.Name]) or M.keyOf(c.Name)
			c:SetAttribute("Prompt", c.Name)
			if k then
				local old = gen:FindFirstChild(k)
				if old then old.Name = k .. "_old" .. math.random(100, 999) end
				c.Name = k
			end
			c.Parent = gen
			table.insert(got, c.Name)
		end
	end
	return got
end
function M.show(keys, z)
	local gen = game.ServerStorage.Gen2
	local show = workspace:FindFirstChild("GenShow") or Instance.new("Folder")
	show.Name = "GenShow"
	show:ClearAllChildren()
	show.Parent = workspace
	local x = 0
	local items = {}
	for _, k in ipairs(keys) do
		local src = gen:FindFirstChild(k)
		if src then
			local m = src:Clone()
			local cf, size = m:GetBoundingBox()
			table.insert(items, { m = m, cf = cf, size = size, k = k })
			x += size.X + 6
		end
	end
	local cur = -x / 2
	local out = {}
	for _, it in ipairs(items) do
		local target = Vector3.new(cur + it.size.X / 2, it.size.Y / 2 + 0.75, z or -40)
		it.m:PivotTo(it.m:GetPivot() + (target - it.cf.Position))
		it.m.Parent = show
		table.insert(out, string.format("%s x=%.0f size %.0f,%.0f,%.0f", it.k, target.X, it.size.X, it.size.Y, it.size.Z))
		cur += it.size.X + 6
	end
	return table.concat(out, "\n")
end
return M
