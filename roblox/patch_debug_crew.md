Studio-only test hooks added directly in Studio to ServerScriptService.Game.Main (inside `if RunService:IsStudio()`), 2026-10-05:
- CE_Debug "crewSet" {laborer=n, builder=n, foreman=n}: replaces the whole crew
- CE_Debug "jobProgress": work done / total on the current contract, crew multiplier, foreman boost

Crew speed test (Brick Garage, same player: tool 1, Strength 60), work done in the first 45 s:
- 11 Foremen: 577 (~12.8 work/s)
- 9 Builders: 480 (~10.7 work/s)
- 7 Builders + 1 Laborer + 3 Foremen: 699 (~15.5 work/s)
