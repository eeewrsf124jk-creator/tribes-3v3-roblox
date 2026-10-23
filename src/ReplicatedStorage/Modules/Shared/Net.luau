--!strict
-- Net: owns every remote channel. The server creates ReplicatedStorage.RemoteNetwork_Events with
-- ReliableRemotes (RemoteEvent) and UnreliableRemotes (UnreliableRemoteEvent); clients wait for them.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Net = {}

Net.ReliableNames = {
	-- Spec channels
	"RequestSpawnLoadout",
	"SwitchPresetInPreRound",
	"FireProjectile",
	"MeleeSwing",
	"UseUtility",
	"StartHeal",
	"CancelHeal",
	"ToggleBlock",
	"RoundStateChanged",
	"BroadcastPOTGData",
	"OpenVictoryChest",
	"UpgradeEquipment",
	"PartyAction",
	"QueueAction",
	-- Supporting channels
	"EquipSlot",
	"ProjectileReplicate",
	"ProjectileResolved",
	"CombatEvent",
	"ApplyImpulse",
	"ProfileSync",
	"SaveLoadout",
	"TribeAction",
	"CustomMatchAction",
	"UpdateSettings",
	"PurchaseRequest",
	"DuelAction",
	"Notify",
	"MatchSummary",
	"InventorySync",
	"UtilityEvent",
	"OpenInterface",
	"CatchChakram",
	"SlideRequest",
}

Net.UnreliableNames = {
	"ReplicateCharacterState",
	"ReplicateBowDrawRatio",
}

local ROOT_NAME = "RemoteNetwork_Events"
local cache: { [string]: Instance } = {}

local function ensureFolder(parent: Instance, name: string): Folder
	local existing = parent:FindFirstChild(name)
	if existing and existing:IsA("Folder") then
		return existing
	end
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent
	return f
end

function Net.InitServer()
	assert(RunService:IsServer(), "Net.InitServer must run on the server")
	local root = ensureFolder(ReplicatedStorage, ROOT_NAME)
	local reliable = ensureFolder(root, "ReliableRemotes")
	local unreliable = ensureFolder(root, "UnreliableRemotes")
	for _, name in Net.ReliableNames do
		local r = reliable:FindFirstChild(name)
		if r == nil then
			local ev = Instance.new("RemoteEvent")
			ev.Name = name
			ev.Parent = reliable
			r = ev
		end
		cache[name] = r :: Instance
	end
	for _, name in Net.UnreliableNames do
		local r = unreliable:FindFirstChild(name)
		if r == nil then
			local ev = Instance.new("UnreliableRemoteEvent")
			ev.Name = name
			ev.Parent = unreliable
			r = ev
		end
		cache[name] = r :: Instance
	end
end

function Net.Reliable(name: string): RemoteEvent
	local cached = cache[name]
	if cached then
		return cached :: RemoteEvent
	end
	local root = ReplicatedStorage:WaitForChild(ROOT_NAME)
	local folder = root:WaitForChild("ReliableRemotes")
	local ev = folder:WaitForChild(name) :: RemoteEvent
	cache[name] = ev
	return ev
end

function Net.Unreliable(name: string): UnreliableRemoteEvent
	local cached = cache[name]
	if cached then
		return cached :: UnreliableRemoteEvent
	end
	local root = ReplicatedStorage:WaitForChild(ROOT_NAME)
	local folder = root:WaitForChild("UnreliableRemotes")
	local ev = folder:WaitForChild(name) :: UnreliableRemoteEvent
	cache[name] = ev
	return ev
end

-- Server-side argument guards: remotes accept arbitrary client data, so every handler
-- validates types with these before acting.
function Net.IsFiniteNumber(v: any): boolean
	return type(v) == "number" and v == v and v ~= math.huge and v ~= -math.huge
end

function Net.IsVector3(v: any): boolean
	if typeof(v) ~= "Vector3" then
		return false
	end
	local vec = v :: Vector3
	return Net.IsFiniteNumber(vec.X) and Net.IsFiniteNumber(vec.Y) and Net.IsFiniteNumber(vec.Z)
end

function Net.IsString(v: any, maxLen: number?): boolean
	return type(v) == "string" and #v <= (maxLen or 64)
end

return Net
