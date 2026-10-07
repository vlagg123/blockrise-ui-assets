-- one-off patch (run in Edit, after Client.HammerSwing exists): every hammer swings its own way (HammerSwing): the
-- Client asks it first on every hit (the old slash animation stays as the fallback) and starts it with the others
local function replaceOnce(src, old, new)
	local a, b = src:find(old, 1, true)
	assert(a, "not found: " .. old:sub(1, 80))
	assert(not src:find(old, b + 1, true), "found twice: " .. old:sub(1, 80))
	return src:sub(1, a - 1) .. new .. src:sub(b + 1)
end
local Client = game.StarterPlayer.StarterPlayerScripts.Client
assert(Client:FindFirstChild("HammerSwing"), "Client.HammerSwing missing")
local c = Client.Source
if c:find("__CE_Swing", 1, true) then return "already patched" end
c = replaceOnce(c, [[	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not hum then return end
	if SW.hum ~= hum or not SW.track then]], [[	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not hum then return end
	if _G.__CE_Swing and _G.__CE_Swing(char, cd) then return end -- (each hammer's own swing: HammerSwing)
	if SW.hum ~= hum or not SW.track then]])
c = replaceOnce(c, [[	SpinUI.Init(ctx)
]], [[	SpinUI.Init(ctx)
	pcall(function() require(script:WaitForChild("HammerSwing")).Init(ctx) end)
]])
assert(#c < 200000, "Client too big: " .. #c)
assert(loadstring(c), "Client compile")
Client.Source = c
return "Client: hammer swings (" .. #c .. ")"
