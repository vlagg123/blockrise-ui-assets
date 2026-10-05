-- one-off Studio patch: windows swallow clicks (an empty spot inside a window no longer closes it), tab buttons get names
local cl = game.StarterPlayer.StarterPlayerScripts.Client
local s = cl.Source
local a, b = s:find("\tmodal.Size = UDim2.fromOffset(760, 500)\n", 1, true)
assert(a, "style block")
s = s:sub(1, b) .. "\tmodal.Active = true -- clicks on the window itself must not reach the dark backdrop (that closes it)\n" .. s:sub(b + 1)
cl.Source = s
local fn, err = loadstring(s)
local kit = game.ReplicatedStorage.Shared.UIKit
local k = kit.Source
local a2, b2 = k:find("\t\tlocal b = UI.button(t.label, c1, c2, { Size = UDim2.new(1 / #list, -8 * (#list - 1) / #list, 0, 42), TextSize = 17, LayoutOrder = i, ZIndex = 23, Parent = row })\n", 1, true)
assert(a2, "tabs")
k = k:sub(1, b2) .. "\t\tb.Name = \"Tab_\" .. t.id\n" .. k:sub(b2 + 1)
kit.Source = k
local fn2, err2 = loadstring(k)
return "client " .. (fn and "OK" or tostring(err)) .. ", uikit " .. (fn2 and "OK" or tostring(err2))
