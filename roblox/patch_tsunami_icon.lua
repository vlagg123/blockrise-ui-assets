-- one-off patch (run in Edit): the Tsunami Hammer's picture follows its new shape (a barrelling wave, a legendary handle)
local HM = game.ReplicatedStorage.Shared.Hammers
local h = HM.Source
if h:find("83712304493554", 1, true) then return "Hammers: already" end
local a, b = h:find('tsunami = "rbxassetid://115884616655947"', 1, true)
assert(a, "tsunami picture not found")
h = h:sub(1, a - 1) .. 'tsunami = "rbxassetid://83712304493554"' .. h:sub(b + 1)
assert(loadstring(h), "Hammers compile")
HM.Source = h
return "Hammers: new Tsunami picture"
