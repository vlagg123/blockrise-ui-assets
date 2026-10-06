-- one-off patch (run in Edit): two crate passes
--  * Quick Open (99 R$): press OPEN and the hammer is there at once (no spinning strip); on / off in the Store
--  * Auto Opener (199 R$): an AUTO button on your crates (Inventory → CRATES) that opens all of them by itself
-- (id = 0 until the passes are made on the Creator Hub: the Store shows them as "soon")
local function replaceOnce(src, old, new)
	local a, b = src:find(old, 1, true)
	assert(a, "not found: " .. old:sub(1, 80))
	assert(not src:find(old, b + 1, true), "found twice: " .. old:sub(1, 80))
	return src:sub(1, a - 1) .. new .. src:sub(b + 1)
end
local C = game.ReplicatedStorage.Shared.Config
local Main = game.ServerScriptService.Game.Main
local cs = C.Source
if cs:find('key = "quickopen"', 1, true) then return "already patched" end
cs = replaceOnce(cs, [[Turn it on / off any time in the Store." },
		{ key = "stormhammer",]], [[Turn it on / off any time in the Store." },
		{ key = "quickopen", id = 0, price = 99, icon = "⚡", name = "Quick Open", desc = "Press OPEN and your hammer is there at once: no spinning strip, on every crate. Turn it on / off any time in the Store." },
		{ key = "autoopen", id = 0, price = 199, icon = "🤖", name = "Auto Opener", desc = "An AUTO button on your crates (Inventory → CRATES): it opens all of them by itself, one after another. Forever." },
		{ key = "stormhammer",]])
assert(loadstring(cs), "compile Config")
local m = Main.Source
m = replaceOnce(m, [[	elseif kind == "skipanim" then
		-- Skip Build Animation: on / off (saved)
		st.data.SkipAnimOff = not on
		plr:SetAttribute("SkipAnim", (st.passes and st.passes.skipanim) == true and not st.data.SkipAnimOff)]], [[	elseif kind == "skipanim" then
		-- Skip Build Animation: on / off (saved)
		st.data.SkipAnimOff = not on
		plr:SetAttribute("SkipAnim", (st.passes and st.passes.skipanim) == true and not st.data.SkipAnimOff)
	elseif kind == "quickopen" then
		-- Quick Open: on / off (saved)
		st.data.QuickOpenOff = not on
		plr:SetAttribute("QuickOpen", (st.passes and st.passes.quickopen) == true and not st.data.QuickOpenOff)]])
m = replaceOnce(m, [[	plr:SetAttribute("SkipAnim", st.passes.skipanim == true and st.data.SkipAnimOff ~= true)
	HammerService.SyncPass(plr, st)]], [[	plr:SetAttribute("SkipAnim", st.passes.skipanim == true and st.data.SkipAnimOff ~= true)
	plr:SetAttribute("QuickOpen", st.passes.quickopen == true and st.data.QuickOpenOff ~= true)
	HammerService.SyncPass(plr, st)]])
assert(loadstring(m), "compile Main")
C.Source = cs
Main.Source = m
return "crate passes"
