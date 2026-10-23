--!strict
-- Automated Studio builder pipeline (05_Automated_Studio_Builder_Pipeline).
-- Run once from the Studio command bar after `rojo serve` has synced the project, then save:
--
--   require(game.ReplicatedStorage.BuilderModules.StudioBuilderPipeline).RunAll({ Role = "Lobby" })
--   require(game.ReplicatedStorage.BuilderModules.StudioBuilderPipeline).RunAll({ Role = "Arena", PreviewMap = "Map_01_WinterTimberFort" })
--
-- Steps:
--   1 GenerateCollisionAndFolders   6 PhysicsService collision groups + the runtime folder tree
--   2 BuildProcedural3DAssets       weapon / armor / utility prefabs and VFX templates
--   3 BuildLobbyAnd4ArenaMaps       50-player village or the 4 arena maps (ServerStorage)
--   4 GenerateCompleteStarterGui    every ScreenGui into StarterGui
--   5 InjectStrictLuauScripts       verifies the Rojo-synced ServerMain / ClientMain / services
-- ServerMain runs the same steps at runtime when a place was published without them.

local StarterGui = game:GetService("StarterGui")
local ServerScriptService = game:GetService("ServerScriptService")
local StarterPlayer = game:GetService("StarterPlayer")

local Step1 = require(script.Parent.Step1.CollisionAndFolders)
local Step2 = require(script.Parent.Step2.BuildProcedural3DAssets)
local Step3 = require(script.Parent.Step3.BuildLobbyAndArenaMaps)
local Step4 = require(script.Parent.Step4.GenerateCompleteStarterGui)

local Pipeline = {}

export type Options = {
	Role: string?, -- "Lobby" (default) or "Arena"
	PreviewMap: string?, -- Arena only: also place one map copy in Arena_Maps_Pool for inspection
	RebuildGui: boolean?, -- destroy and regenerate existing ScreenGuis
	SkipMaps: boolean?,
}

local REQUIRED_SCRIPTS: { { Parent: Instance, Path: string } } = {
	{ Parent = ServerScriptService, Path = "ServerMain" },
	{ Parent = ServerScriptService, Path = "Services/PlayerDataService" },
	{ Parent = ServerScriptService, Path = "Services/LagCompensatedCombatService" },
	{ Parent = ServerScriptService, Path = "Services/RoundStateMachineService" },
	{ Parent = ServerScriptService, Path = "Services/MatchmakingAndBotService" },
	{ Parent = ServerScriptService, Path = "Services/POTGRecorderAndScorer" },
	{ Parent = ServerScriptService, Path = "Services/EconomyAndMonetizationService" },
	{ Parent = ServerScriptService, Path = "Services/Bots/TacticalBotAgent" },
	{ Parent = StarterPlayer, Path = "StarterPlayerScripts/ClientMain" },
	{ Parent = StarterPlayer, Path = "StarterPlayerScripts/Controllers/InputAndKeybindController" },
	{ Parent = StarterPlayer, Path = "StarterPlayerScripts/Controllers/CameraAndViewmodelController" },
	{ Parent = StarterPlayer, Path = "StarterPlayerScripts/Controllers/WeaponAndProjectileController" },
	{ Parent = StarterPlayer, Path = "StarterPlayerScripts/Controllers/CombatFeedbackAndHUDController" },
	{ Parent = StarterPlayer, Path = "StarterPlayerScripts/Controllers/POTGAndVictorySequenceController" },
}

local function find(parent: Instance, path: string): Instance?
	local node: Instance? = parent
	for segment in string.gmatch(path, "[^/]+") do
		if node == nil then
			return nil
		end
		node = (node :: Instance):FindFirstChild(segment)
	end
	return node
end

function Pipeline.VerifyScripts(): { string }
	local missing: { string } = {}
	for _, entry in REQUIRED_SCRIPTS do
		if find(entry.Parent, entry.Path) == nil then
			table.insert(missing, entry.Parent.Name .. "/" .. entry.Path)
		end
	end
	return missing
end

function Pipeline.RunAll(options: Options?): Step1.FolderTree
	local opts: Options = options or {}
	local role = if opts.Role == "Arena" then "Arena" else "Lobby"
	workspace:SetAttribute("PlaceRole", role)
	local t0 = os.clock()

	print("[Builder] Step 1/5 collision groups + folders")
	local tree = Step1.Run(role)

	print("[Builder] Step 2/5 procedural 3D assets")
	local prefabCount = Step2.Run(tree)
	print(string.format("[Builder]   %d equipment prefabs", prefabCount))

	if not opts.SkipMaps then
		print("[Builder] Step 3/5 " .. (if role == "Lobby" then "lobby village" else "4 arena maps"))
		Step3.Run(role, tree, opts.PreviewMap)
	end

	print("[Builder] Step 4/5 ScreenGuis")
	local created = Step4.Run(StarterGui, opts.RebuildGui)
	print(string.format("[Builder]   %d ScreenGuis created", #created))

	print("[Builder] Step 5/5 strict Luau scripts")
	local missing = Pipeline.VerifyScripts()
	if #missing > 0 then
		warn("[Builder]   missing scripts (is `rojo serve` connected?): " .. table.concat(missing, ", "))
	else
		print("[Builder]   all ServerMain/ClientMain/service/controller scripts present")
	end
	workspace:SetAttribute("BuilderVersion", 1)
	print(string.format("[Builder] done in %.1f s - save the place (Ctrl+S)", os.clock() - t0))
	return tree
end

return Pipeline
