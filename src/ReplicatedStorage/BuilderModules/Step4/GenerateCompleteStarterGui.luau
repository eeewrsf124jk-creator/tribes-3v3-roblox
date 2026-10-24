--!strict
-- Step 4: generate every ScreenGui (lobby, 12-point loadout builder, VS screen, combat HUD,
-- POTG viewfinder, chest opening, scoreboard). EnsureAll only builds guis that are missing, so it
-- is safe to call from the command-bar pipeline (into StarterGui) and at runtime from the
-- client (into PlayerGui) when the place was synced without a prebuilt StarterGui.

local LobbyScreens = require(script.Parent.LobbyScreens)
local MatchScreens = require(script.Parent.MatchScreens)
local EndScreens = require(script.Parent.EndScreens)

local Step4 = {}

type Builder = { Name: string, Build: (Instance) -> ScreenGui }

Step4.Builders = {
	{ Name = "LobbyHUD", Build = LobbyScreens.LobbyHUD },
	{ Name = "LoadoutBuilder", Build = LobbyScreens.LoadoutBuilder },
	{ Name = "CustomMatches", Build = LobbyScreens.CustomMatches },
	{ Name = "TribeHall", Build = LobbyScreens.TribeHall },
	{ Name = "Settings", Build = LobbyScreens.Settings },
	{ Name = "VSScreen", Build = MatchScreens.VSScreen },
	{ Name = "CombatHUD", Build = MatchScreens.CombatHUD },
	{ Name = "DeathAndSpectate", Build = MatchScreens.DeathAndSpectate },
	{ Name = "POTGViewfinder", Build = EndScreens.POTGViewfinder },
	{ Name = "VictoryDropUI", Build = EndScreens.VictoryDropUI },
	{ Name = "ScoreboardSummaryUI", Build = EndScreens.ScoreboardSummaryUI },
} :: { Builder }

-- Builds the missing ScreenGuis under `parent`; returns the names that were created.
function Step4.EnsureAll(parent: Instance): { string }
	local created = {}
	for _, entry in Step4.Builders do
		if parent:FindFirstChild(entry.Name) == nil then
			local gui = entry.Build(parent)
			assert(gui.Name == entry.Name, "ScreenGui builder produced " .. gui.Name .. ", expected " .. entry.Name)
			table.insert(created, entry.Name)
		end
	end
	return created
end

-- Destroys and rebuilds every ScreenGui (used by the Studio pipeline with Rebuild = true).
function Step4.RebuildAll(parent: Instance): { string }
	for _, entry in Step4.Builders do
		local old = parent:FindFirstChild(entry.Name)
		if old then
			old:Destroy()
		end
	end
	return Step4.EnsureAll(parent)
end

function Step4.Run(starterGui: Instance, rebuild: boolean?): { string }
	if rebuild then
		return Step4.RebuildAll(starterGui)
	end
	return Step4.EnsureAll(starterGui)
end

return Step4
