--!strict
-- CombatantRegistry: every damageable actor (players, bots, training dummies) plus the 20 Hz
-- hitbox snapshot ring buffer used for server rewind. Snapshots keep the last
-- GameConfig.Combat.RewindWindow seconds of per-part CFrames.

local Modules = game:GetService("ReplicatedStorage"):WaitForChild("Modules")
local Types = require(Modules.Shared.Types)
local GameConfig = require(Modules.Config.GameConfig)
local Signal = require(Modules.Shared.Signal)

local Registry = {}

Registry.HitboxNames = {
	"Head",
	"UpperTorso",
	"LowerTorso",
	"LeftUpperArm",
	"RightUpperArm",
	"LeftLowerArm",
	"RightLowerArm",
	"LeftUpperLeg",
	"RightUpperLeg",
	"LeftLowerLeg",
	"RightLowerLeg",
}

export type SlotState = {
	ItemId: string,
	Count: number, -- -1 = unlimited
	Level: number,
	LastUse: number,
}

export type Snapshot = {
	T: number,
	Parts: { [string]: CFrame },
	Sliding: boolean,
}

export type HitboxPose = { Name: string, CFrame: CFrame, Size: Vector3 }

export type HealCast = { Slot: number, ItemId: string, EndsAt: number, Amount: number }

export type Stats = { Kills: number, Deaths: number, Assists: number, Damage: number }

export type Combatant = {
	Id: string,
	Name: string,
	UserId: number,
	Team: Types.TeamName,
	IsBot: boolean,
	IsDummy: boolean,
	Player: Player?,
	Character: Model?,
	Humanoid: Humanoid?,
	Root: BasePart?,
	Context: string,
	Alive: boolean,
	Invulnerable: boolean,

	Loadout: Types.Loadout?,
	Slots: { SlotState },
	EquippedSlot: number,
	EquippedAt: number,
	Ammo: { Arrows: number, Bullets: number, FireArrows: number },
	UseFireArrows: boolean,
	ArmorId: string?,
	Armor: number,
	ArmorMax: number,
	ShieldHP: number,
	ShieldMax: number,
	Blocking: boolean,

	StaggerUntil: number,
	SnareUntil: number,
	SnareMult: number,
	RootUntil: number,
	PostShotSlowUntil: number,
	PostShotSlowMult: number,
	SpeedBoostUntil: number,
	SpeedBoostMult: number,
	BurnUntil: number,
	BurnDPS: number,
	BurnSourceId: string?,
	BurnNextTick: number,
	Healing: HealCast?,
	HoTPerSecond: number,
	HoTUntil: number,
	Sliding: boolean,
	Pitch: number,
	LastShotAt: number,
	ShotsThisSecond: number,
	ShotWindowStart: number,

	Damagers: { [string]: number },
	Stats: Stats,
	Latency: number,
	Snapshots: { Snapshot },
	SnapshotHead: number,
	LastSpeedMult: number,
	Brain: any?,
}

local byId: { [string]: Combatant } = {}
local byPlayer: { [Player]: Combatant } = {}
local byCharacter: { [Model]: Combatant } = {}

Registry.Added = Signal.new() :: Signal.Signal<Combatant>
Registry.Removed = Signal.new() :: Signal.Signal<Combatant>

local SNAPSHOT_COUNT = math.ceil(GameConfig.Combat.RewindWindow * GameConfig.Combat.SnapshotRate) + 2

function Registry.IdForPlayer(player: Player): string
	return "P" .. tostring(player.UserId)
end

function Registry.New(id: string, name: string, team: Types.TeamName, context: string): Combatant
	return {
		Id = id,
		Name = name,
		UserId = 0,
		Team = team,
		IsBot = false,
		IsDummy = false,
		Player = nil,
		Character = nil,
		Humanoid = nil,
		Root = nil,
		Context = context,
		Alive = false,
		Invulnerable = false,
		Loadout = nil,
		Slots = {},
		EquippedSlot = 0,
		EquippedAt = 0,
		Ammo = { Arrows = 0, Bullets = 0, FireArrows = 0 },
		UseFireArrows = false,
		ArmorId = nil,
		Armor = 0,
		ArmorMax = 0,
		ShieldHP = 0,
		ShieldMax = 0,
		Blocking = false,
		StaggerUntil = 0,
		SnareUntil = 0,
		SnareMult = 1,
		RootUntil = 0,
		PostShotSlowUntil = 0,
		PostShotSlowMult = 1,
		SpeedBoostUntil = 0,
		SpeedBoostMult = 1,
		BurnUntil = 0,
		BurnDPS = 0,
		BurnSourceId = nil,
		BurnNextTick = 0,
		Healing = nil,
		HoTPerSecond = 0,
		HoTUntil = 0,
		Sliding = false,
		Pitch = 0,
		LastShotAt = 0,
		ShotsThisSecond = 0,
		ShotWindowStart = 0,
		Damagers = {},
		Stats = { Kills = 0, Deaths = 0, Assists = 0, Damage = 0 },
		Latency = 0,
		Snapshots = table.create(SNAPSHOT_COUNT),
		SnapshotHead = 0,
		LastSpeedMult = -1,
		Brain = nil,
	}
end

function Registry.Add(c: Combatant)
	local existing = byId[c.Id]
	if existing and existing ~= c then
		Registry.Remove(existing)
	end
	byId[c.Id] = c
	if c.Player then
		byPlayer[c.Player] = c
	end
	if c.Character then
		byCharacter[c.Character] = c
	end
	Registry.Added:Fire(c)
end

function Registry.Remove(c: Combatant)
	if byId[c.Id] == c then
		byId[c.Id] = nil
	end
	if c.Player and byPlayer[c.Player] == c then
		byPlayer[c.Player] = nil
	end
	if c.Character and byCharacter[c.Character] == c then
		byCharacter[c.Character] = nil
	end
	Registry.Removed:Fire(c)
end

-- Bind a (new) character model to the combatant and reset its snapshot history.
function Registry.BindCharacter(c: Combatant, character: Model)
	if c.Character and byCharacter[c.Character] == c then
		byCharacter[c.Character] = nil
	end
	c.Character = character
	c.Humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	c.Root = if root and root:IsA("BasePart") then root else nil
	c.Snapshots = table.create(SNAPSHOT_COUNT)
	c.SnapshotHead = 0
	byCharacter[character] = c
	character:SetAttribute("CombatantId", c.Id)
	character:SetAttribute("Team", c.Team)
end

function Registry.Get(id: string): Combatant?
	return byId[id]
end

function Registry.ForPlayer(player: Player): Combatant?
	return byPlayer[player]
end

function Registry.ForCharacter(model: Model): Combatant?
	return byCharacter[model]
end

-- Resolve any descendant part (limb, accessory) to its owning combatant.
function Registry.ForPart(part: Instance): Combatant?
	local node: Instance? = part
	while node and node ~= workspace do
		if node:IsA("Model") then
			local c = byCharacter[node]
			if c then
				return c
			end
		end
		node = node.Parent
	end
	return nil
end

function Registry.All(): { Combatant }
	local list = {}
	for _, c in byId do
		table.insert(list, c)
	end
	return list
end

function Registry.InContext(context: string): { Combatant }
	local list = {}
	for _, c in byId do
		if c.Context == context then
			table.insert(list, c)
		end
	end
	return list
end

function Registry.Characters(): { Instance }
	local list: { Instance } = {}
	for model in byCharacter do
		table.insert(list, model)
	end
	return list
end

function Registry.AreEnemies(a: Combatant, b: Combatant): boolean
	if a == b or a.Context ~= b.Context then
		return false
	end
	if a.Team == "Neutral" or b.Team == "Neutral" then
		return true
	end
	return a.Team ~= b.Team
end

---------------------------------------------------------------------------------------------
-- Snapshot ring buffer
---------------------------------------------------------------------------------------------
function Registry.RecordSnapshots(now: number)
	for _, c in byId do
		local character = c.Character
		if c.Alive and character then
			local parts: { [string]: CFrame } = {}
			for _, name in Registry.HitboxNames do
				local p = character:FindFirstChild(name)
				if p and p:IsA("BasePart") then
					parts[name] = p.CFrame
				end
			end
			c.SnapshotHead = (c.SnapshotHead % SNAPSHOT_COUNT) + 1
			c.Snapshots[c.SnapshotHead] = { T = now, Parts = parts, Sliding = c.Sliding }
		end
	end
end

local function partSize(c: Combatant, name: string): Vector3?
	local character = c.Character
	if character == nil then
		return nil
	end
	local p = character:FindFirstChild(name)
	if p and p:IsA("BasePart") then
		return p.Size
	end
	return nil
end

-- Hitbox poses at server time `t` (linear position + spherical rotation interpolation between the
-- two bracketing snapshots). Falls back to the live pose when no history covers `t`.
function Registry.PoseAt(c: Combatant, t: number): { HitboxPose }
	local older: Snapshot? = nil
	local newer: Snapshot? = nil
	for _, snap in c.Snapshots do
		if snap.T <= t and (older == nil or snap.T > (older :: Snapshot).T) then
			older = snap
		end
		if snap.T >= t and (newer == nil or snap.T < (newer :: Snapshot).T) then
			newer = snap
		end
	end
	local poses: { HitboxPose } = {}
	local character = c.Character
	if character == nil then
		return poses
	end
	local a = older or newer
	local b = newer or older
	local sliding = c.Sliding
	if a and b then
		sliding = a.Sliding or b.Sliding
	end
	local alpha = 0
	if a and b and b.T > a.T then
		alpha = math.clamp((t - a.T) / (b.T - a.T), 0, 1)
	end
	for _, name in Registry.HitboxNames do
		local size = partSize(c, name)
		if size then
			local cf: CFrame? = nil
			if a and b then
				local ca, cb = a.Parts[name], b.Parts[name]
				if ca and cb then
					cf = ca:Lerp(cb, alpha)
				elseif ca or cb then
					cf = ca or cb
				end
			end
			if cf == nil then
				local live = character:FindFirstChild(name)
				if live and live:IsA("BasePart") then
					cf = live.CFrame
				end
			end
			if cf then
				local finalCF = cf :: CFrame
				local finalSize = size
				if sliding and name ~= "Head" then
					-- sliding crouch: compress limbs toward the ground plane
					finalSize = Vector3.new(size.X, size.Y * GameConfig.Combat.SlideHitboxScale, size.Z)
				end
				table.insert(poses, { Name = name, CFrame = finalCF, Size = finalSize })
			end
		end
	end
	return poses
end

function Registry.CenterAt(c: Combatant, t: number): Vector3?
	for _, pose in Registry.PoseAt(c, t) do
		if pose.Name == "UpperTorso" then
			return pose.CFrame.Position
		end
	end
	local root = c.Root
	return if root then root.Position else nil
end

return Registry
