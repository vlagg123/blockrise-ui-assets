-- one-off patch (run in Edit): the window header is a flat striped ribbon, not a button: no 3D lip under it, the title
-- and the info pill (cash, gems...) sit in the middle of it, top to bottom (K.window in MenuKit does the same)
local function replaceOnce(src, old, new)
	local a, b = src:find(old, 1, true)
	assert(a, "not found: " .. old:sub(1, 80))
	assert(not src:find(old, b + 1, true), "found twice: " .. old:sub(1, 80))
	return src:sub(1, a - 1) .. new .. src:sub(b + 1)
end
local Client = game.StarterPlayer.StarterPlayerScripts.Client
local s = Client.Source
if s:find('UI.slice("pill", { Name = "Ribbon"', 1, true) then return "already patched" end
s = replaceOnce(s, 'UI.slice("button", { Name = "Ribbon", ImageColor3 = T.accent', 'UI.slice("pill", { Name = "Ribbon", ImageColor3 = T.accent')
s = replaceOnce(s, 'Name = "Stripes", Position = UDim2.fromOffset(4, 4), Size = UDim2.new(1, -8, 1, -16)', 'Name = "Stripes", Position = UDim2.fromOffset(4, 4), Size = UDim2.new(1, -8, 1, -8)')
s = replaceOnce(s, "modalTitle.Position = UDim2.fromOffset(86, 13) -- centred on the ribbon's face (above its 3D lip)", "modalTitle.Position = UDim2.fromOffset(86, 13) -- centred on the ribbon")
s = replaceOnce(s, 'Name = "SubPill", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -18, 0, 33)', 'Name = "SubPill", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -18, 0, 39)')
assert(#s < 200000, "Client too long: " .. #s)
assert(loadstring(s), "Client compile")
Client.Source = s
return "ribbon flat, Client " .. #s
