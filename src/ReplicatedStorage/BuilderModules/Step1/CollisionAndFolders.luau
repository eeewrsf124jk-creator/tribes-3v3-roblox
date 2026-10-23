--!strict
-- Step 1: register the 6 collision groups, apply Workspace physics properties and create the
-- complete runtime folder tree. Idempotent: existing folders are reused.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local RunService = game:GetService("RunService")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local CollisionGroups = require(Modules.Shared.CollisionGroups)
local GeometryKit = require(script.Parent.Parent.Kit.GeometryKit)

local Step1 = {}

Step1.RuntimeContainers = {
	"AliveCharacters_Alpha",
	"AliveCharacters_Bravo",
	"ActiveProjectiles_Container",
	"DeployedUtilities_Container",
	"Ragdolls_And_StuckArrows",
}

Step1.PrefabFolders = {
	"Ranged_Weapon_Models",
	"Melee_Weapon_Models",
	"Utility_And_Healing_Models",
	"Wearable_Armor_Models",
}

Step1.VFXFolders = {
	"ProjectileTrails",
	"ImpactEffects",
	"StatusAndAreaEffects",
	"KillConfirmationVFX",
}

function Step1.ApplyWorkspaceProperties()
	workspace.Gravity = 196.2
	workspace.FallenPartsDestroyHeight = -500
	-- StreamingEnabled / SignalBehavior are set by the Rojo project file; they are only writable
	-- with plugin security (Studio command bar), so try them without failing at runtime.
	if not RunService:IsRunning() then
		pcall(function()
			(workspace :: any).StreamingEnabled = true
		end)
		pcall(function()
			(workspace :: any).SignalBehavior = Enum.SignalBehavior.Deferred
		end)
	end
end

export type FolderTree = {
	Runtime: Folder,
	Containers: { [string]: Folder },
	Prefabs: Folder,
	PrefabSub: { [string]: Folder },
	RankedMelees: Folder,
	VFX: Folder,
	VFXSub: { [string]: Folder },
	ArenaPool: Folder,
	ArenaStorage: Folder,
	LobbyWorld: Folder,
}

function Step1.Run(role: string): FolderTree
	CollisionGroups.Setup()
	Step1.ApplyWorkspaceProperties()

	local runtime = GeometryKit.Folder(workspace, "Runtime_Dynamic_Containers")
	local containers: { [string]: Folder } = {}
	for _, name in Step1.RuntimeContainers do
		containers[name] = GeometryKit.Folder(runtime, name)
	end

	local prefabs = GeometryKit.Folder(ReplicatedStorage, "Procedural_3D_Weapon_And_Armor_Prefabs")
	local prefabSub: { [string]: Folder } = {}
	for _, name in Step1.PrefabFolders do
		prefabSub[name] = GeometryKit.Folder(prefabs, name)
	end
	local ranked = GeometryKit.Folder(prefabSub.Melee_Weapon_Models, "Ranked_Melees")

	local vfx = GeometryKit.Folder(ReplicatedStorage, "VFX_And_Particle_Templates")
	local vfxSub: { [string]: Folder } = {}
	for _, name in Step1.VFXFolders do
		vfxSub[name] = GeometryKit.Folder(vfx, name)
	end

	local arenaPool = GeometryKit.Folder(workspace, "Arena_Maps_Pool")
	local arenaStorage = GeometryKit.Folder(ServerStorage, "ArenaMapStorage")
	local lobbyWorld = GeometryKit.Folder(workspace, "Lobby_50Player_World")
	if role == "Arena" then
		lobbyWorld:Destroy()
		lobbyWorld = Instance.new("Folder")
		lobbyWorld.Name = "Lobby_50Player_World"
	end

	return {
		Runtime = runtime,
		Containers = containers,
		Prefabs = prefabs,
		PrefabSub = prefabSub,
		RankedMelees = ranked,
		VFX = vfx,
		VFXSub = vfxSub,
		ArenaPool = arenaPool,
		ArenaStorage = arenaStorage,
		LobbyWorld = lobbyWorld,
	}
end

return Step1
