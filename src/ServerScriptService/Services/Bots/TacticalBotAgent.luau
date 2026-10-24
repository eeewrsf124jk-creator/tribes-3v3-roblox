--!strict
-- TacticalBotAgent: server-side AI for bot-filled matches.
-- State machine (thinks at 5 Hz, moves every frame):
--   Advance  - path toward the nearest enemy with PathfindingService
--   Engage   - ranged harassment: pick a cover prop (CoverHeight attribute), hide behind it,
--              peek out sideways, draw and release with lead + gravity compensation
--   Rush     - distance-based weapon swap to melee once the target is within ~14 studs
--   Heal     - break off and use a consumable when low and no enemy is close
--   Ring     - move back inside the Ring of Fire when the safe zone shrinks past the bot

local PathfindingService = game:GetService("PathfindingService")
local Workspace = game:GetService("Workspace")

local Modules = game:GetService("ReplicatedStorage"):WaitForChild("Modules")
local Types = require(Modules.Shared.Types)
local GameConfig = require(Modules.Config.GameConfig)
local EquipmentDatabase = require(Modules.Config.EquipmentDatabase)
local Ballistics = require(Modules.Shared.BallisticsEngine)

local Registry = require(script.Parent.Parent.Combat.CombatantRegistry)
local Combat = require(script.Parent.Parent.LagCompensatedCombatService)

type Combatant = Registry.Combatant

local Agent = {}

export type BotState = "Advance" | "Engage" | "Rush" | "Heal" | "Ring" | "Idle"

export type RingInfo = { Center: Vector3, Radius: number, Active: boolean }

export type Brain = {
	C: Combatant,
	State: BotState,
	Skill: number, -- 0..1
	Target: Combatant?,
	Waypoints: { Vector3 },
	WaypointIndex: number,
	NextRepath: number,
	NextThink: number,
	Computing: boolean,
	DrawStart: number?,
	Cover: Vector3?,
	PeekUntil: number,
	HideUntil: number,
	StrafeSign: number,
	BlockUntil: number,
	LastJump: number,
	StuckSince: number,
	LastPos: Vector3,
	Rng: Random,
}

local THINK_INTERVAL = 0.2
local RUSH_DISTANCE = 14
local HEAL_THRESHOLD = 45

local function now(): number
	return Workspace:GetServerTimeNow()
end

function Agent.New(c: Combatant, skill: number): Brain
	local brain: Brain = {
		C = c,
		State = "Idle",
		Skill = math.clamp(skill, 0, 1),
		Target = nil,
		Waypoints = {},
		WaypointIndex = 1,
		NextRepath = 0,
		NextThink = 0,
		Computing = false,
		DrawStart = nil,
		Cover = nil,
		PeekUntil = 0,
		HideUntil = 0,
		StrafeSign = 1,
		BlockUntil = 0,
		LastJump = 0,
		StuckSince = 0,
		LastPos = Vector3.zero,
		Rng = Random.new(),
	}
	c.Brain = brain
	return brain
end

---------------------------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------------------------
local function headOf(c: Combatant): Vector3?
	return Combat.HeadPosition(c)
end

local losParams = RaycastParams.new()
losParams.FilterType = Enum.RaycastFilterType.Exclude

local function visible(from: Vector3, to: Vector3): boolean
	losParams.FilterDescendantsInstances = Registry.Characters()
	local hit = Workspace:Raycast(from, to - from, losParams)
	return hit == nil
end

local function slotWhere(c: Combatant, pred: (Types.EquipmentSpec, Registry.SlotState) -> boolean): number?
	for i, s in c.Slots do
		local spec = EquipmentDatabase.Get(s.ItemId)
		if spec and pred(spec, s) then
			return i
		end
	end
	return nil
end

local function hasAmmo(c: Combatant, spec: Types.EquipmentSpec, slot: Registry.SlotState): boolean
	if spec.SubType == "BOW" then
		return c.Ammo.Arrows + c.Ammo.FireArrows > 0
	elseif spec.SubType == "GUN" then
		return c.Ammo.Bullets > 0
	end
	return slot.Count ~= 0
end

local function rangedSlot(c: Combatant): number?
	return slotWhere(c, function(spec, slot)
		return EquipmentDatabase.IsRanged(spec) and spec.ProjectileSpeed ~= nil and hasAmmo(c, spec, slot)
	end)
end

local function meleeSlot(c: Combatant): number?
	return slotWhere(c, function(spec)
		return spec.SubType == "MELEE"
	end)
end

local function healSlot(c: Combatant): number?
	return slotWhere(c, function(spec, slot)
		return spec.Category == "HEALING" and spec.Id ~= "HealingFlask" and slot.Count ~= 0
	end)
end

local function equip(brain: Brain, slot: number)
	local c = brain.C
	if c.EquippedSlot ~= slot then
		Combat.Equip(c, slot)
		brain.DrawStart = nil
	end
end

local function nearestEnemy(c: Combatant): (Combatant?, number, boolean)
	local root = c.Root
	if root == nil then
		return nil, math.huge, false
	end
	local head = headOf(c)
	local best: Combatant? = nil
	local bestDist = math.huge
	local bestVisible = false
	for _, other in Registry.InContext(c.Context) do
		if other.Alive and Registry.AreEnemies(c, other) and other.Root then
			local d = ((other.Root :: BasePart).Position - root.Position).Magnitude
			local otherHead = headOf(other)
			local seen = head ~= nil and otherHead ~= nil and visible(head :: Vector3, otherHead :: Vector3)
			-- prefer visible targets; a hidden target counts as 40% further away
			local score = if seen then d else d * 1.4
			if score < bestDist then
				best, bestDist, bestVisible = other, score, seen
			end
		end
	end
	if best and best.Root then
		bestDist = ((best.Root :: BasePart).Position - root.Position).Magnitude
	end
	return best, bestDist, bestVisible
end

local function findCover(c: Combatant, threat: Vector3): Vector3?
	local root = c.Root
	if root == nil then
		return nil
	end
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = Registry.Characters()
	local parts = Workspace:GetPartBoundsInRadius(root.Position, 26, params)
	local best: Vector3? = nil
	local bestScore = math.huge
	for _, part in parts do
		local model = part:FindFirstAncestorWhichIsA("Model")
		if model and model:GetAttribute("CoverHeight") ~= nil and part.CanCollide then
			local away = (part.Position - threat)
			away = Vector3.new(away.X, 0, away.Z)
			if away.Magnitude > 0.1 then
				-- stand on the far side of the prop from the threat
				local spot = part.Position + away.Unit * (math.max(part.Size.X, part.Size.Z) / 2 + 2.5)
				spot = Vector3.new(spot.X, root.Position.Y, spot.Z)
				local score = (spot - root.Position).Magnitude
				if score < bestScore then
					best, bestScore = spot, score
				end
			end
		end
	end
	return best
end

local function repath(brain: Brain, goal: Vector3)
	if brain.Computing then
		return
	end
	local root = brain.C.Root
	if root == nil then
		return
	end
	brain.Computing = true
	brain.NextRepath = now() + 1.2
	local start = root.Position
	task.spawn(function()
		local path = PathfindingService:CreatePath({
			AgentRadius = 2,
			AgentHeight = 5,
			AgentCanJump = true,
			WaypointSpacing = 6,
		})
		local ok = pcall(function()
			path:ComputeAsync(start, goal)
		end)
		brain.Computing = false
		if ok and path.Status == Enum.PathStatus.Success then
			local points: { Vector3 } = {}
			for _, wp in path:GetWaypoints() do
				table.insert(points, wp.Position)
			end
			brain.Waypoints = points
			brain.WaypointIndex = math.min(2, #points)
		else
			brain.Waypoints = { goal }
			brain.WaypointIndex = 1
		end
	end)
end

local function moveAlongPath(brain: Brain)
	local c = brain.C
	local humanoid = c.Humanoid
	local root = c.Root
	if humanoid == nil or root == nil then
		return
	end
	if brain.WaypointIndex > #brain.Waypoints then
		humanoid:Move(Vector3.zero)
		return
	end
	local wp = brain.Waypoints[brain.WaypointIndex]
	local offset = wp - root.Position
	if Vector3.new(offset.X, 0, offset.Z).Magnitude < 3 then
		brain.WaypointIndex += 1
		if brain.WaypointIndex > #brain.Waypoints then
			humanoid:Move(Vector3.zero)
			return
		end
		wp = brain.Waypoints[brain.WaypointIndex]
		offset = wp - root.Position
	end
	humanoid:MoveTo(wp)
	if offset.Y > 2.5 and now() - brain.LastJump > 1 then
		brain.LastJump = now()
		humanoid.Jump = true
	end
end

local function faceTowards(c: Combatant, point: Vector3)
	local root = c.Root
	if root == nil then
		return
	end
	local flat = Vector3.new(point.X, root.Position.Y, point.Z)
	if (flat - root.Position).Magnitude > 0.1 then
		root.CFrame = CFrame.lookAt(root.Position, flat)
	end
end

-- Aim point with target lead and gravity compensation, plus skill-scaled cone error.
local function aimDirection(brain: Brain, from: Vector3, target: Combatant, spec: Types.EquipmentSpec): Vector3?
	local tRoot = target.Root
	local tHead = headOf(target)
	if tRoot == nil or tHead == nil then
		return nil
	end
	local aimHead = brain.Rng:NextNumber() < 0.15 + 0.35 * brain.Skill
	local point = if aimHead then tHead :: Vector3 else (tRoot :: BasePart).Position + Vector3.new(0, 0.6, 0)
	local speed = spec.ProjectileSpeed or 200
	local dist = (point - from).Magnitude
	local flight = dist / speed
	point += (tRoot :: BasePart).AssemblyLinearVelocity * flight * (0.6 + 0.4 * brain.Skill)
	local g = Workspace.Gravity * (spec.GravityScale or 0)
	point += Vector3.new(0, 0.5 * g * flight * flight, 0)
	local dir = (point - from).Unit
	local errorDeg = 4.5 - 3.5 * brain.Skill
	return Ballistics.SampleCone(dir, errorDeg, brain.Rng)
end

---------------------------------------------------------------------------------------------
-- Think (5 Hz) and act (every frame)
---------------------------------------------------------------------------------------------
local function think(brain: Brain, ring: RingInfo?)
	local c = brain.C
	local root = c.Root
	local humanoid = c.Humanoid
	if root == nil or humanoid == nil then
		return
	end
	local t = now()

	-- unstick
	if (root.Position - brain.LastPos).Magnitude < 0.6 and humanoid.MoveDirection.Magnitude > 0.1 then
		if brain.StuckSince == 0 then
			brain.StuckSince = t
		elseif t - brain.StuckSince > 1.2 then
			humanoid.Jump = true
			brain.StrafeSign = -brain.StrafeSign
			brain.NextRepath = 0
			brain.StuckSince = 0
		end
	else
		brain.StuckSince = 0
	end
	brain.LastPos = root.Position

	-- ring has priority
	if ring and ring.Active then
		local flatOff = Vector3.new(root.Position.X - ring.Center.X, 0, root.Position.Z - ring.Center.Z)
		if flatOff.Magnitude > ring.Radius - 8 then
			brain.State = "Ring"
			if t >= brain.NextRepath then
				repath(brain, ring.Center)
			end
			return
		end
	end

	local target, dist, seen = nearestEnemy(c)
	brain.Target = target
	if target == nil then
		brain.State = "Idle"
		return
	end

	if humanoid.Health < HEAL_THRESHOLD and dist > 22 then
		local heal = healSlot(c)
		if heal then
			brain.State = "Heal"
			return
		end
	end

	local ranged = rangedSlot(c)
	local melee = meleeSlot(c)
	if melee and (dist <= RUSH_DISTANCE or ranged == nil) then
		brain.State = "Rush"
		equip(brain, melee)
	elseif ranged then
		brain.State = if seen then "Engage" else "Advance"
		equip(brain, ranged)
	else
		brain.State = "Advance"
	end

	if brain.State == "Engage" and target.Root then
		if brain.Cover == nil or t > brain.HideUntil + 4 then
			brain.Cover = findCover(c, (target.Root :: BasePart).Position)
		end
	end

	if (brain.State == "Advance" or brain.State == "Rush") and target.Root and t >= brain.NextRepath then
		repath(brain, (target.Root :: BasePart).Position)
	end
end

local function act(brain: Brain, dt: number)
	local c = brain.C
	local root = c.Root
	local humanoid = c.Humanoid
	if root == nil or humanoid == nil then
		return
	end
	local t = now()
	local speedMult = c.LastSpeedMult
	if speedMult < 0 then
		speedMult = 1
	end
	humanoid.WalkSpeed = GameConfig.Movement.WalkSpeed * speedMult
	local target = brain.Target

	if brain.State == "Ring" or brain.State == "Advance" then
		moveAlongPath(brain)
		return
	end

	if brain.State == "Heal" then
		humanoid:Move(Vector3.zero)
		local heal = healSlot(c)
		if heal and c.Healing == nil then
			equip(brain, heal)
			Combat.Utility.StartHeal(c, heal)
		end
		return
	end

	if target == nil or target.Root == nil then
		humanoid:Move(Vector3.zero)
		return
	end
	local tRoot = target.Root :: BasePart
	local slot = c.Slots[c.EquippedSlot]
	local spec = if slot then EquipmentDatabase.Get(slot.ItemId) else nil
	if slot == nil or spec == nil then
		return
	end

	if brain.State == "Rush" then
		local offset = tRoot.Position - root.Position
		local range = spec.Range or 8
		if offset.Magnitude > range * 0.8 then
			humanoid:MoveTo(tRoot.Position)
		else
			-- circle-strafe inside reach
			local side = Vector3.new(-offset.Z, 0, offset.X).Unit * brain.StrafeSign
			humanoid:Move(side * 0.6 + Vector3.new(offset.X, 0, offset.Z).Unit * 0.2)
		end
		faceTowards(c, tRoot.Position)
		-- opportunistic sword block against a nearby melee enemy
		local theirSpec = Combat.Damage.EquippedSpec(target)
		if spec.CanBlock and theirSpec and theirSpec.SubType == "MELEE" and offset.Magnitude < 10 then
			if t > brain.BlockUntil + 1.5 and brain.Rng:NextNumber() < 0.02 + 0.03 * brain.Skill then
				brain.BlockUntil = t + 0.7
			end
		end
		local blocking = t < brain.BlockUntil
		if c.Blocking ~= blocking then
			c.Blocking = blocking
			if c.Character then
				c.Character:SetAttribute("Blocking", blocking)
			end
		end
		if not blocking and offset.Magnitude <= range + 0.5 and t - slot.LastUse >= (spec.SwingRate or 0.5) then
			Combat.Melee(c, c.EquippedSlot, offset.Unit, t, 1)
		end
		return
	end

	-- Engage: cover peeking + ranged fire
	local hiding = brain.Cover ~= nil and t < brain.HideUntil
	if hiding and brain.Cover then
		local off = (brain.Cover :: Vector3) - root.Position
		if Vector3.new(off.X, 0, off.Z).Magnitude > 2 then
			humanoid:MoveTo(brain.Cover :: Vector3)
		else
			humanoid:Move(Vector3.zero)
		end
		brain.DrawStart = nil
		return
	end
	if t >= brain.PeekUntil and brain.Cover then
		-- finished a peek: go back to cover for a moment
		brain.HideUntil = t + brain.Rng:NextNumber(0.8, 1.8)
		brain.PeekUntil = brain.HideUntil + brain.Rng:NextNumber(2.2, 3.6)
		brain.StrafeSign = if brain.Rng:NextNumber() < 0.5 then -1 else 1
		return
	end
	-- peeking: small strafe while drawing
	local toTarget = tRoot.Position - root.Position
	local side = Vector3.new(-toTarget.Z, 0, toTarget.X)
	if side.Magnitude > 0.1 then
		humanoid:Move(side.Unit * brain.StrafeSign * 0.35)
	end
	faceTowards(c, tRoot.Position)
	local head = headOf(c)
	local tHead = headOf(target)
	if head == nil or tHead == nil or not visible(head :: Vector3, tHead :: Vector3) then
		brain.DrawStart = nil
		return
	end
	local chargeTime = spec.DrawTime or spec.ChargeTime or 0
	if brain.DrawStart == nil then
		brain.DrawStart = t
		if c.Character then
			c.Character:SetAttribute("DrawRatio", 0.1)
		end
	end
	local held = t - (brain.DrawStart :: number)
	local interval = spec.ReloadTime or spec.Cooldown or 0
	local ready = held >= chargeTime * (0.9 + 0.2 * (1 - brain.Skill)) and t - slot.LastUse >= interval
	if ready then
		local dir = aimDirection(brain, head :: Vector3, target, spec)
		if dir then
			Combat.Fire(c, c.EquippedSlot, head :: Vector3, dir, 1, t, brain.Rng:NextInteger(1, 1e6))
		end
		brain.DrawStart = nil
	end
end

function Agent.Step(brain: Brain, dt: number, ring: RingInfo?)
	local c = brain.C
	if not c.Alive or c.Humanoid == nil then
		return
	end
	if not Combat.CanAct(c) then
		-- frozen in the spawn room during PreRoundLoadout / staggered
		if not Combat.IsContextEnabled(c.Context) then
			(c.Humanoid :: Humanoid):Move(Vector3.zero)
		end
		return
	end
	local t = now()
	if t >= brain.NextThink then
		brain.NextThink = t + THINK_INTERVAL
		think(brain, ring)
	end
	act(brain, dt)
end

---------------------------------------------------------------------------------------------
-- Bot body
---------------------------------------------------------------------------------------------
local BOT_NAMES = {
	"Rook", "Kestrel", "Bramble", "Thane", "Vex", "Moss", "Ember", "Sable", "Wren", "Talon",
	"Ash", "Juniper", "Flint", "Gale", "Rune", "Hollow", "Briar", "Cinder", "Fen", "Quill",
}

function Agent.RandomName(rng: Random, used: { [string]: boolean }): string
	for _ = 1, 30 do
		local n = BOT_NAMES[rng:NextInteger(1, #BOT_NAMES)] .. "_" .. tostring(rng:NextInteger(10, 99))
		if not used[n] then
			used[n] = true
			return n
		end
	end
	return "Bot_" .. tostring(rng:NextInteger(100, 999))
end

-- R15 rig built from a randomized HumanoidDescription.
function Agent.BuildBody(name: string, team: Types.TeamName, rng: Random): Model
	local desc = Instance.new("HumanoidDescription")
	local skin = Color3.fromHSV(rng:NextNumber(0.02, 0.1), rng:NextNumber(0.2, 0.6), rng:NextNumber(0.35, 0.95))
	desc.HeadColor = skin
	desc.LeftArmColor = skin
	desc.RightArmColor = skin
	desc.TorsoColor = if team == "Alpha" then Color3.fromRGB(40, 90, 170) else Color3.fromRGB(170, 45, 40)
	desc.LeftLegColor = Color3.fromRGB(60, 50, 40)
	desc.RightLegColor = Color3.fromRGB(60, 50, 40)
	local model = game:GetService("Players"):CreateHumanoidModelFromDescriptionAsync(desc, Enum.HumanoidRigType.R15)
	model.Name = name
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.DisplayName = name
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.Viewer
		humanoid.NameDisplayDistance = 60
		humanoid.HealthDisplayDistance = 60
		humanoid.WalkSpeed = GameConfig.Movement.WalkSpeed
		humanoid.UseJumpPower = true
		humanoid.JumpPower = 50
	end
	model:SetAttribute("IsBot", true)
	return model
end

return Agent
