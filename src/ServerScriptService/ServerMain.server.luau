--!strict
-- ServerMain: the single server entry point. Creates the remotes, makes sure the procedural world
-- exists (running the builder steps if the place was published without them), then starts the
-- services for this place's role (Lobby or Arena) in dependency order.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local StarterGui = game:GetService("StarterGui")
local Players = game:GetService("Players")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local Net = require(Modules.Shared.Net)
local GameConfig = require(Modules.Config.GameConfig)

-- remotes first so clients can start waiting on them immediately
Net.InitServer()

local role = GameConfig.GetPlaceRole()
workspace:SetAttribute("PlaceRole", role)

---------------------------------------------------------------------------------------------
-- World bootstrap
---------------------------------------------------------------------------------------------
local Builder = ReplicatedStorage:WaitForChild("BuilderModules")
local Step1 = require(Builder.Step1.CollisionAndFolders)
local Step2 = require(Builder.Step2.BuildProcedural3DAssets)
local Step3 = require(Builder.Step3.BuildLobbyAndArenaMaps)
local Step4 = require(Builder.Step4.GenerateCompleteStarterGui)

local tree = Step1.Run(role)
if tree.Prefabs:GetAttribute("Built") ~= true then
	Step2.Run(tree)
end
if role == "Lobby" then
	if tree.LobbyWorld:GetAttribute("Built") ~= true then
		Step3.Run(role, tree, nil)
	end
else
	local storage = ServerStorage:FindFirstChild("ArenaMapStorage")
	if storage == nil or storage:GetAttribute("Built") ~= true then
		Step3.Run(role, tree, nil)
	end
	tree.ArenaPool:ClearAllChildren()
end
local created = Step4.EnsureAll(StarterGui)
if #created > 0 then
	-- players who joined while the GUI was being generated get copies now
	for _, player in Players:GetPlayers() do
		local playerGui = player:FindFirstChildOfClass("PlayerGui")
		if playerGui then
			for _, name in created do
				local gui = StarterGui:FindFirstChild(name)
				if gui and playerGui:FindFirstChild(name) == nil then
					gui:Clone().Parent = playerGui
				end
			end
		end
	end
end
workspace:SetAttribute("WorldReady", true)

---------------------------------------------------------------------------------------------
-- Services
---------------------------------------------------------------------------------------------
local Services = script.Parent:WaitForChild("Services")
local PlayerData = require(Services.PlayerDataService)
local Combat = require(Services.LagCompensatedCombatService)
local Recorder = require(Services.POTGRecorderAndScorer)
local Economy = require(Services.EconomyAndMonetizationService)
local Tribes = require(Services.TribeService)
local Round = require(Services.RoundStateMachineService)
local Matchmaking = require(Services.MatchmakingAndBotService)

PlayerData.Start()
Combat.Start()
Recorder.Start()
Economy.Start()
Tribes.Start()
Round.Start()
Matchmaking.Start()

if role == "Lobby" then
	local Lobby = require(Services.LobbyService)
	local Leaderboards = require(Services.LeaderboardService)
	Lobby.Start()
	Leaderboards.Start()
else
	Matchmaking.ArenaBoot()
end

print(string.format("[ServerMain] %s server ready (PlaceId %d)", role, game.PlaceId))
