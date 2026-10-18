-- dev tool: every visible part under `roots` within `radius` of `center`, as JSON for the offline preview renderer
-- (tools/preview/render.py in the repo): [shape, size xyz, pos xyz, rotation 3x3, colour rgb, material, transparency]
local HttpService = game:GetService("HttpService")
-- page: which 700-part page to return (1..); the JSON says how many pages there are
return function(roots, center, radius, page)
	page = page or 1
	local out = {}
	local function r3(x) return math.floor(x * 1000 + 0.5) / 1000 end
	for _, root in ipairs(roots) do
		for _, p in ipairs(root:GetDescendants()) do
			if p:IsA("BasePart") and p.Transparency < 0.98 and (not center or (p.Position - center).Magnitude <= (radius or 1e9)) then
				local shape = "Block"
				if p:IsA("WedgePart") then shape = "Wedge"
				elseif p:IsA("Part") then
					if p.Shape == Enum.PartType.Cylinder then shape = "Cylinder" elseif p.Shape == Enum.PartType.Ball then shape = "Ball" end
				end
				local cf = p.CFrame
				local x, y, z, a, b, c, d, e, f, g, h, i = cf:GetComponents()
				local s = p.Size
				local col = p.Color
				table.insert(out, { shape, r3(s.X), r3(s.Y), r3(s.Z), r3(x), r3(y), r3(z), r3(a), r3(b), r3(c), r3(d), r3(e), r3(f), r3(g), r3(h), r3(i),
					r3(col.R), r3(col.G), r3(col.B), p.Material.Name, r3(p.Transparency) })
			end
		end
	end
	local per = 700
	local pages = math.max(1, math.ceil(#out / per))
	local slice = {}
	for i = (page - 1) * per + 1, math.min(#out, page * per) do table.insert(slice, out[i]) end
	return HttpService:JSONEncode({ parts = slice, page = page, pages = pages, total = #out })
end
