-- one-off patch (run in Edit): properties pay rent for the whole time you're offline (no 2 hour limit)
local Co = game.ReplicatedStorage.Shared.Company
local s = Co.Source
local old = "Company.OfflineHours = 2 -- properties keep earning while you're away (up to this long)"
local a, b = s:find(old, 1, true)
if not a then return "already patched" end
s = s:sub(1, a - 1) .. "Company.OfflineHours = math.huge -- properties keep earning the whole time you're away (no limit)" .. s:sub(b + 1)
assert(loadstring(s), "Company compile")
Co.Source = s
return "offline rent: no limit"
