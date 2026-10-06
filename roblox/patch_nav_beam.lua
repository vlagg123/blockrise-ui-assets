-- one-off patch (run in Edit): the guide line to the next place is easy to see
-- (it was 0.7 studs wide and faded in over the first 12% of its length: on a 400-stud way home that was 50 studs of
-- nothing, so "the line" never seemed to start at your feet)
local Client = game.StarterPlayer.StarterPlayerScripts.Client
local s = Client.Source
if s:find("NAV_BEAM_V2", 1, true) then return "already patched" end
local old = [[local beam = new("Beam", { Attachment1 = a1, FaceCamera = true, Width0 = 0.7, Width1 = 0.7, LightEmission = 1, Segments = 30, CurveSize0 = 0, CurveSize1 = 0,
	Color = ColorSequence.new(T.accent, T.accent2), Transparency = NumberSequence.new({ NSK(0, 1), NSK(0.12, 0.45), NSK(0.8, 0.45), NSK(1, 1) }), Enabled = false, Parent = targetPart })]]
local a, b = s:find(old, 1, true)
assert(a and not s:find(old, b + 1, true), "beam line not found once")
s = s:sub(1, a - 1) .. [[-- NAV_BEAM_V2: wide, bright from your feet on, fading only at the very end
local beam = new("Beam", { Attachment1 = a1, FaceCamera = true, Width0 = 1.25, Width1 = 1.25, LightEmission = 1, Segments = 40, CurveSize0 = 0, CurveSize1 = 0,
	Color = ColorSequence.new(T.accent, T.accent2), Transparency = NumberSequence.new({ NSK(0, 0.6), NSK(0.01, 0.12), NSK(0.88, 0.12), NSK(1, 1) }), Enabled = false, Parent = targetPart })]] .. s:sub(b + 1)
assert(loadstring(s), "compile Client")
Client.Source = s
return "nav beam v2"
