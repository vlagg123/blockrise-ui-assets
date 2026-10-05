-- one-off patch (run in Edit): start DealerUI (hold-E buttons on the BlockRise Motors display cars)
local Client = game.StarterPlayer.StarterPlayerScripts.Client
local s = Client.Source
if s:find("DealerUI", 1, true) then return "already wired" end
local old = "\t_G.__CE_MoreUI = MoreUI\n"
local a, b = s:find(old, 1, true)
assert(a and not s:find(old, b + 1, true), "anchor")
s = s:sub(1, b) .. "\tlocal DealerUI = require(script:WaitForChild(\"DealerUI\"))\n\tDealerUI.Init(ctx)\n" .. s:sub(b + 1)
Client.Source = s
return "dealer wired"
