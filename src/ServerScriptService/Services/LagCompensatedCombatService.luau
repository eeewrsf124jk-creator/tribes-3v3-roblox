--!strict
-- LagCompensatedCombatService: server-authoritative combat.
--   * Combatant registry + 20 Hz hitbox ring buffer (1.0 s) for rewind.
--   * Remote validation for FireProjectile / MeleeSwing / UseUtility / StartHeal / CancelHeal /
--     ToggleBlock / EquipSlot / SlideRequest and the unreliable state channels.
--   * Melee: rewound arc + ray test, Diamond Dagger backstab (L_attacker . L_victim > 0.5 ->
--     250 instant kill), sword/shield blocks, Hammer knockback impulse + 0.8 s STAGGERED,
--     Battle Axe overhead charge + armor shred.
--   * Movement modifiers (armor, snare, root, stagger, heal cast, post-shot slow, war horn) are
--     folded into a SpeedMult character attribute the client movement controller applies.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Modules = game:GetService("ReplicatedStorage"):WaitForChild("Modules")
local Types = require(Modules.Shared.Types)
local Net = require(Modules.Shared.Net)
local Signal = require(Modules.Shared.Signal)
local GameConfig = require(Modules.Config.GameConfig)
local EquipmentDatabase = require(Modules.Config.EquipmentDatabase)
local UpgradeScalingMath = require(Modules.Config.UpgradeScalingMath)
local LoadoutBudgetValidator = require(Modules.Shared.LoadoutBudgetValidator)
local Ballistics = require(Modules.Shared.BallisticsEngine)
local EquipmentRig = require(Modules.Shared.EquipmentRig)
local CollisionGroups = require(Modules.Shared.CollisionGroups)

local Registry = require(script.Parent.Combat.CombatantRegistry)
local DamageModel = require(script.Parent.Combat.DamageModel)
local Projectiles = require(script.Parent.Combat.ProjectileSimulator)
local Utility = require(script.Parent.Combat.UtilityAndHealing)

type Combatant = Registry.Combatant
type SlotState = Registry.SlotState

local Combat = {}

Combat.Registry = Registry
Combat.Damage = DamageModel
Combat.Projectiles = Projectiles
Combat.Utility = Utility

-- POTG / stats hooks
Combat.Shot = Signal.new() :: Signal.Signal<Combatant, string, Vector3, Vector3, number>
Combat.Swing = Signal.new() :: Signal.Signal<Combatant, string>
Combat.Equipped = Signal.new() :: Signal.Signal<Combatant, string>

local enabledContexts: { [string]: boolean } = {}
local ORIGIN_TOLERANCE = 7
local MELEE_REACH_TOLERANCE = 1.75

local function now(): number
	return Workspace:GetServerTimeNow()
end

function Combat.SetContextEnabled(context: string, enabled: boolean)
	enabledContexts[context] = enabled
end

function Combat.IsContextEnabled(context: string): boolean
	return enabledContexts[context] == true
end

---------------------------------------------------------------------------------------------
-- Inventory
---------------------------------------------------------------------------------------------
local function slotCount(itemId: string, spec: Types.EquipmentSpec): number
	if itemId == "Chakram" then
		return 1
	end
	if itemId == "Sling" or itemId == "WarHorn" then
		return -1
	end
	local stack = EquipmentDatabase.StackSize(spec)
	if stack == 0 then
		return -1
	end
	return stack
end

function Combat.InventoryView(c: Combatant): Types.InventoryView
	local slots: { Types.InventorySlot } = {}
	for _, s in c.Slots do
		table.insert(slots, { ItemId = s.ItemId, Count = s.Count, Level = s.Level })
	end
	return {
		Context = c.Context,
		Slots = slots,
		Equipped = c.EquippedSlot,
		Ammo = { Arrows = c.Ammo.Arrows, Bullets = c.Ammo.Bullets, FireArrows = c.Ammo.FireArrows },
		UseFireArrows = c.UseFireArrows,
		ArmorId = c.ArmorId,
		Armor = c.Armor,
		ArmorMax = c.ArmorMax,
		ShieldHP = c.ShieldHP,
		ShieldMax = c.ShieldMax,
	}
end

function Combat.PushInventory(c: Combatant)
	if c.Player and c.Player.Parent == Players then
		Net.Reliable("InventorySync"):FireClient(c.Player, Combat.InventoryView(c))
	end
end

Projectiles.InventoryChanged = Combat.PushInventory
Utility.InventoryChanged = Combat.PushInventory
Projectiles.StructureHit = Utility.DamageStructure

-- Build slots/ammo/armor from a validated loadout. `levelOf` gives the owner's upgrade level.
function Combat.Arm(c: Combatant, loadout: Types.Loadout, levelOf: (string) -> number)
	c.Loadout = loadout
	c.Slots = {}
	for _, id in loadout.Slots do
		local spec = EquipmentDatabase.Get(id)
		if spec and #c.Slots < EquipmentDatabase.MaxSlots then
			table.insert(c.Slots, { ItemId = id, Count = slotCount(id, spec), Level = levelOf(id), LastUse = 0 })
		end
	end
	local ammo = LoadoutBudgetValidator.AmmoCounts(loadout)
	c.Ammo = { Arrows = ammo.Arrows, Bullets = ammo.Bullets, FireArrows = ammo.FireArrows }
	c.UseFireArrows = false
	c.ArmorId = loadout.Armor
	c.ArmorMax = 0
	if loadout.Armor then
		local armorSpec = EquipmentDatabase.Get(loadout.Armor)
		if armorSpec and armorSpec.ArmorHP then
			c.ArmorMax = UpgradeScalingMath.ScaleHealth(armorSpec.ArmorHP, levelOf(loadout.Armor))
		end
	end
	c.Armor = c.ArmorMax
	c.ShieldMax = 0
	for _, s in c.Slots do
		local spec = EquipmentDatabase.Get(s.ItemId)
		if spec and spec.SubType == "SHIELD" then
			c.ShieldMax = UpgradeScalingMath.ScaleHealth(spec.ShieldHealth or 120, s.Level)
		end
	end
	c.ShieldHP = c.ShieldMax
	c.EquippedSlot = 0
end

function Combat.Equip(c: Combatant, slotIndex: number)
	local character = c.Character
	if character == nil then
		return
	end
	local slot = c.Slots[slotIndex]
	if slot == nil then
		return
	end
	if c.Healing then
		Utility.CancelHeal(c)
	end
	c.EquippedSlot = slotIndex
	c.EquippedAt = now()
	c.Blocking = false
	character:SetAttribute("Blocking", false)
	character:SetAttribute("EquippedItem", slot.ItemId)
	character:SetAttribute("DrawRatio", 0)
	local spec = EquipmentDatabase.Get(slot.ItemId)
	if spec and spec.SubType == "SHIELD" and c.ShieldHP <= 0 then
		-- a broken shield cannot be raised again this round
		EquipmentRig.Unequip(character)
	else
		EquipmentRig.EquipHeld(character, slot.ItemId)
	end
	Combat.Equipped:Fire(c, slot.ItemId)
	Combat.PushInventory(c)
end

-- Put a combatant (re)alive at `cf` with full health, armor and the first slot in hand.
function Combat.SpawnAt(c: Combatant, cf: CFrame)
	local character = c.Character
	local humanoid = c.Humanoid
	if character == nil or humanoid == nil then
		return
	end
	character:PivotTo(cf)
	humanoid.MaxHealth = GameConfig.Combat.MaxHealth
	humanoid.Health = GameConfig.Combat.MaxHealth
	humanoid.BreakJointsOnDeath = true
	c.Alive = true
	c.Damagers = {}
	c.StaggerUntil, c.SnareUntil, c.RootUntil = 0, 0, 0
	c.BurnUntil, c.HoTUntil, c.PostShotSlowUntil, c.SpeedBoostUntil = 0, 0, 0, 0
	c.Healing = nil
	c.Blocking = false
	c.Sliding = false
	c.Armor = c.ArmorMax
	c.ShieldHP = c.ShieldMax
	for _, s in c.Slots do
		s.LastUse = 0
	end
	character:SetAttribute("Dead", false)
	character:SetAttribute("ChakramOut", false)
	character:SetAttribute("StaggerUntil", 0)
	character:SetAttribute("HealingUntil", 0)
	character:SetAttribute("Sliding", false)
	DamageModel.SetArmorAttributes(c)
	CollisionGroups.AssignCharacter(character)
	if c.ArmorId and c.ArmorMax > 0 then
		EquipmentRig.EquipArmor(character, c.ArmorId)
	else
		EquipmentRig.RemoveArmor(character)
	end
	if #c.Slots > 0 then
		Combat.Equip(c, 1)
	else
		EquipmentRig.Unequip(character)
	end
	local runtime = Workspace:FindFirstChild("Runtime_Dynamic_Containers")
	if runtime and (c.Team == "Alpha" or c.Team == "Bravo") then
		local folder = runtime:FindFirstChild("AliveCharacters_" .. c.Team)
		if folder and character.Parent ~= folder then
			character.Parent = folder
		end
	end
	c.Snapshots = {}
	c.SnapshotHead = 0
	Combat.PushInventory(c)
end

-- Register a player as a combatant in `context` and bind their current character.
function Combat.AddPlayer(player: Player, team: Types.TeamName, context: string): Combatant?
	local character = player.Character
	if character == nil then
		return nil
	end
	local c = Registry.New(Registry.IdForPlayer(player), player.DisplayName, team, context)
	c.Player = player
	c.UserId = player.UserId
	Registry.BindCharacter(c, character)
	Registry.Add(c)
	Combat.WatchCharacter(c)
	return c
end

function Combat.Remove(c: Combatant)
	local character = c.Character
	if character and character.Parent then
		EquipmentRig.Unequip(character)
		EquipmentRig.RemoveArmor(character)
		character:SetAttribute("CombatantId", nil)
		character:SetAttribute("SpeedMult", 1)
		character:SetAttribute("EquippedItem", nil)
	end
	Utility.ClearOwner(c)
	Registry.Remove(c)
	if c.Player and c.Player.Parent == Players then
		Net.Reliable("InventorySync"):FireClient(c.Player, nil)
	end
end

-- Deaths that bypass the damage model (fall below FallenPartsDestroyHeight, reset).
function Combat.WatchCharacter(c: Combatant)
	local humanoid = c.Humanoid
	local character = c.Character
	if humanoid == nil or character == nil then
		return
	end
	humanoid.Died:Connect(function()
		if c.Character == character and c.Alive then
			local root = c.Root
			DamageModel.Kill(c, nil, {
				VictimId = c.Id,
				AttackerId = nil,
				Amount = 0,
				ArmorAmount = 0,
				Position = if root then root.Position else Vector3.zero,
				Headshot = false,
				ArmorBroken = false,
				Staggered = false,
				Blocked = false,
				Killed = true,
				WeaponId = "Fall",
			})
		end
	end)
end

---------------------------------------------------------------------------------------------
-- Ranged fire (players and bots)
---------------------------------------------------------------------------------------------
local function headPosition(c: Combatant): Vector3?
	local character = c.Character
	local head = if character then character:FindFirstChild("Head") else nil
	if head and head:IsA("BasePart") then
		return head.Position
	end
	local root = c.Root
	return if root then root.Position + Vector3.new(0, 1.5, 0) else nil
end

Combat.HeadPosition = headPosition

local function canAct(c: Combatant): boolean
	if not c.Alive or not enabledContexts[c.Context] then
		return false
	end
	return now() >= c.StaggerUntil
end

function Combat.CanAct(c: Combatant): boolean
	return canAct(c)
end

local function minInterval(spec: Types.EquipmentSpec): number
	if spec.ReloadTime then
		return spec.ReloadTime
	end
	if spec.Cooldown then
		return spec.Cooldown
	end
	if spec.SubType == "BOW" then
		return 0.25
	end
	return 0.35
end

local function consumeAmmo(c: Combatant, slot: SlotState, spec: Types.EquipmentSpec): (boolean, boolean)
	if spec.SubType == "BOW" then
		if c.UseFireArrows and c.Ammo.FireArrows > 0 then
			c.Ammo.FireArrows -= 1
			return true, true
		end
		if c.Ammo.Arrows > 0 then
			c.Ammo.Arrows -= 1
			return true, false
		end
		if c.Ammo.FireArrows > 0 then
			c.Ammo.FireArrows -= 1
			return true, true
		end
		return false, false
	elseif spec.SubType == "GUN" then
		if c.Ammo.Bullets > 0 then
			c.Ammo.Bullets -= 1
			return true, false
		end
		return false, false
	end
	if slot.Count == 0 then
		return false, false
	end
	if slot.Count > 0 then
		slot.Count -= 1
	end
	return true, false
end

-- Fire the equipped ranged weapon. `draw` is the client-reported draw/charge ratio (0..1).
function Combat.Fire(c: Combatant, slotIndex: number, origin: Vector3, direction: Vector3, draw: number, clientTime: number, seed: number): boolean
	if not canAct(c) or slotIndex ~= c.EquippedSlot then
		return false
	end
	local slot = c.Slots[slotIndex]
	local spec = if slot then EquipmentDatabase.Get(slot.ItemId) else nil
	if slot == nil or spec == nil or not EquipmentDatabase.IsRanged(spec) or spec.ProjectileSpeed == nil then
		return false
	end
	local t = now()
	if t - slot.LastUse < minInterval(spec) * 0.85 then
		return false
	end
	if slot.ItemId == "Chakram" and c.Character and c.Character:GetAttribute("ChakramOut") == true then
		return false
	end
	local head = headPosition(c)
	if head == nil then
		return false
	end
	if (origin - head).Magnitude > ORIGIN_TOLERANCE then
		origin = head
	end
	if direction.Magnitude < 0.5 then
		return false
	end
	direction = direction.Unit

	-- server-side draw clamp: the ratio cannot exceed the time actually spent drawing
	local ratio = 1
	local chargeTime = spec.DrawTime or spec.ChargeTime
	if chargeTime and chargeTime > 0 then
		local heldFor = t - math.max(slot.LastUse, c.EquippedAt)
		ratio = math.clamp(math.min(draw, heldFor / chargeTime + 0.15), 0, 1)
	end
	local ok, fire = consumeAmmo(c, slot, spec)
	if not ok then
		Combat.PushInventory(c)
		return false
	end
	slot.LastUse = t
	if c.Healing then
		Utility.CancelHeal(c)
	end
	local elapsed = math.clamp(t - clientTime, 0, GameConfig.Combat.MaxRewindLatency)
	local speedMult, dmgMult = 1, 1
	if chargeTime then
		speedMult, dmgMult = Ballistics.DrawScale(ratio)
	end
	local level = UpgradeScalingMath.StatMultiplier(slot.Level)
	local speed = spec.ProjectileSpeed * speedMult
	local gravityScale = spec.GravityScale or 0

	if spec.PelletCount and spec.PelletDmg then
		local dirs = Ballistics.PelletDirections(direction, spec.SpreadAngle or 8, spec.PelletCount, seed)
		for _, d in dirs do
			Projectiles.Spawn(c, slot.ItemId, origin, d * speed, gravityScale, {
				Damage = spec.PelletDmg * level,
				HeadMult = spec.HeadMult,
				Falloff = true,
				Elapsed = elapsed,
				Silent = true, -- clients draw the whole volley from the seeded packet below
			})
		end
		Net.Reliable("ProjectileReplicate"):FireAllClients({
			Id = -1,
			OwnerId = c.Id,
			ItemId = slot.ItemId,
			Body = "Bullet",
			Origin = origin,
			Velocity = direction * speed,
			GravityScale = gravityScale,
			FireTime = t - elapsed,
			Seed = seed,
			Pellets = spec.PelletCount,
			Spread = spec.SpreadAngle or 8,
		})
	else
		Projectiles.Spawn(c, slot.ItemId, origin, direction * speed, gravityScale, {
			Damage = (spec.BaseDmg or 0) * dmgMult * level,
			HeadMult = spec.HeadMult,
			Fire = fire,
			Elapsed = elapsed,
		})
	end
	if slot.ItemId == "Chakram" and c.Character then
		c.Character:SetAttribute("ChakramOut", true)
	end
	if spec.PostShotSlow then
		c.PostShotSlowUntil = t + 0.8
		c.PostShotSlowMult = spec.PostShotSlow
	end
	if c.Character then
		c.Character:SetAttribute("DrawRatio", 0)
		c.Character:SetAttribute("LastShotAt", t)
	end
	Combat.Shot:Fire(c, slot.ItemId, origin, direction * speed, gravityScale)
	Combat.PushInventory(c)
	return true
end

---------------------------------------------------------------------------------------------
-- Melee (players and bots)
---------------------------------------------------------------------------------------------
local function lineOfSight(from: Vector3, to: Vector3): boolean
	local params = Projectiles.WorldParams()
	local hit = Workspace:Raycast(from, to - from, params)
	return hit == nil
end

type MeleeTarget = { C: Combatant, Score: number, Head: boolean, Position: Vector3 }

function Combat.Melee(c: Combatant, slotIndex: number, direction: Vector3, clientTime: number, charge: number): boolean
	if not canAct(c) or slotIndex ~= c.EquippedSlot then
		return false
	end
	local slot = c.Slots[slotIndex]
	local spec = if slot then EquipmentDatabase.Get(slot.ItemId) else nil
	if slot == nil or spec == nil or spec.SubType ~= "MELEE" then
		return false
	end
	local t = now()
	if t - slot.LastUse < (spec.SwingRate or 0.5) * 0.85 then
		return false
	end
	local root = c.Root
	local head = headPosition(c)
	if root == nil or head == nil or direction.Magnitude < 0.5 then
		return false
	end
	slot.LastUse = t
	c.Blocking = false
	if c.Character then
		c.Character:SetAttribute("Blocking", false)
		c.Character:SetAttribute("SwingAt", t)
	end
	if c.Healing then
		Utility.CancelHeal(c)
	end
	Combat.Swing:Fire(c, slot.ItemId)

	local dir = direction.Unit
	local flatDir = DamageModel.Flat(dir)
	if flatDir.Magnitude < 0.5 then
		flatDir = DamageModel.Flat(root.CFrame.LookVector)
	end
	local range = (spec.Range or 8) + MELEE_REACH_TOLERANCE
	local cosHalf = math.cos(math.rad(GameConfig.Combat.MeleeArcDegrees / 2))
	local rewind = Projectiles.RewindFor(c)
	local hitTime = math.max(t - rewind, clientTime - 0.05)
	hitTime = math.min(hitTime, t)

	local targets: { MeleeTarget } = {}
	for _, other in Registry.InContext(c.Context) do
		if other.Alive and Registry.AreEnemies(c, other) and other.Root then
			local poses = Registry.PoseAt(other, hitTime)
			local center: Vector3? = nil
			local headHit = false
			for _, pose in poses do
				if pose.Name == "UpperTorso" then
					center = pose.CFrame.Position
				end
				if pose.Name == "Head" then
					local rt = Ballistics.RayOBB(head, dir, range, pose.CFrame, pose.Size + Vector3.one * 0.3)
					if rt then
						headHit = true
					end
				end
			end
			local pos = center or (other.Root :: BasePart).Position
			local offset = pos - root.Position
			local flatOffset = Vector3.new(offset.X, 0, offset.Z)
			local dist = offset.Magnitude
			if dist <= range + 1 then
				local facing = if flatOffset.Magnitude > 0.1 then flatDir:Dot(flatOffset.Unit) else 1
				if facing >= cosHalf and lineOfSight(head, pos) then
					table.insert(targets, { C = other, Score = dist * (2 - facing), Head = headHit, Position = pos })
				end
			end
		end
	end
	table.sort(targets, function(a, b)
		return a.Score < b.Score
	end)

	local cleave = slot.ItemId == "Scythe"
	local level = UpgradeScalingMath.StatMultiplier(slot.Level)
	local hitAny = false
	for i, target in targets do
		if i > 1 and not cleave then
			break
		end
		local victim = target.C
		local victimRoot = victim.Root :: BasePart
		local attackDir = (target.Position - root.Position)
		local base = spec.BaseDmg or 0
		if spec.OverheadDmg and spec.ChargeTime and charge >= 1 then
			base = spec.OverheadDmg
		end
		local amount = base * level
		local headshot = target.Head and (spec.HeadMult or 1) > 1
		if headshot then
			amount *= spec.HeadMult or 1
		end
		-- backstab: attacker and victim facing the same way (attacker is behind the victim)
		local backstab = false
		if spec.BackstabInstantKill then
			local la = DamageModel.Flat(root.CFrame.LookVector)
			local lv = DamageModel.Flat(victimRoot.CFrame.LookVector)
			if la:Dot(lv) > GameConfig.Combat.BackstabDot then
				backstab = true
				amount = EquipmentDatabase.BackstabDamage
			end
		end
		DamageModel.Apply(victim, c, amount, {
			Kind = if backstab then "Backstab" else "Melee",
			WeaponId = slot.ItemId,
			Headshot = headshot,
			Position = target.Position,
			Direction = attackDir,
			ArmorShred = spec.ArmorShredRatio,
			Knockback = spec.KnockbackImpulse,
			Stagger = spec.StaggerDuration,
			IgnoreBlock = backstab,
			IgnoreArmor = backstab,
		})
		if backstab and victim.Player then
			DamageModel.SendEvent({ victim.Player }, { Kind = "Status", Status = "Backstabbed", TargetId = victim.Id })
		end
		hitAny = true
	end

	if not hitAny then
		-- swing into a palisade wall
		local params = Projectiles.WorldParams()
		local hit = Workspace:Raycast(head, dir * range, params)
		if hit and hit.Instance:GetAttribute("DeployableId") ~= nil then
			Utility.DamageStructure(hit.Instance, (spec.BaseDmg or 0) * level, c)
		end
	end
	return true
end

---------------------------------------------------------------------------------------------
-- Movement modifiers
---------------------------------------------------------------------------------------------
function Combat.SpeedMultiplier(c: Combatant): number
	local t = now()
	local mult = 1
	if c.ArmorId and c.Armor > 0 then
		local armor = EquipmentDatabase.Get(c.ArmorId)
		if armor then
			mult *= 1 - (armor.SpeedPenalty or 0)
		end
	end
	local spec = DamageModel.EquippedSpec(c)
	if spec and spec.WalkSpeedBonus then
		mult *= spec.WalkSpeedBonus
	end
	if c.SnareUntil > t then
		mult *= c.SnareMult
	end
	if c.StaggerUntil > t then
		mult *= 0.5
	end
	if c.Healing then
		mult *= GameConfig.Movement.HealWalkMultiplier
	end
	if c.PostShotSlowUntil > t then
		mult *= c.PostShotSlowMult
	end
	if c.SpeedBoostUntil > t then
		mult *= c.SpeedBoostMult
	end
	if c.RootUntil > t then
		mult = 0
	end
	return mult
end

local function updateMovement(c: Combatant)
	local character = c.Character
	if character == nil then
		return
	end
	local mult = if c.Alive then Combat.SpeedMultiplier(c) else 1
	if math.abs(mult - c.LastSpeedMult) > 0.005 then
		c.LastSpeedMult = mult
		character:SetAttribute("SpeedMult", mult)
		character:SetAttribute("Rooted", c.RootUntil > now())
	end
end

---------------------------------------------------------------------------------------------
-- Remote handlers
---------------------------------------------------------------------------------------------
local function combatantFor(player: Player): Combatant?
	return Registry.ForPlayer(player)
end

local function onFire(player: Player, packet: any)
	local c = combatantFor(player)
	if c == nil or type(packet) ~= "table" then
		return
	end
	if not (Net.IsFiniteNumber(packet.Slot) and Net.IsVector3(packet.Origin) and Net.IsVector3(packet.Direction)) then
		return
	end
	local draw = if Net.IsFiniteNumber(packet.Draw) then packet.Draw else 1
	local clientTime = if Net.IsFiniteNumber(packet.ClientTime) then packet.ClientTime else now()
	local seed = if Net.IsFiniteNumber(packet.Seed) then math.floor(packet.Seed) % 2147483647 else 1
	if type(packet.UseFire) == "boolean" then
		c.UseFireArrows = packet.UseFire
	end
	if not Combat.Fire(c, math.floor(packet.Slot), packet.Origin, packet.Direction, draw, clientTime, seed) then
		Combat.PushInventory(c)
	end
end

local function onMelee(player: Player, packet: any)
	local c = combatantFor(player)
	if c == nil or type(packet) ~= "table" then
		return
	end
	if not (Net.IsFiniteNumber(packet.Slot) and Net.IsVector3(packet.Direction)) then
		return
	end
	local clientTime = if Net.IsFiniteNumber(packet.ClientTime) then packet.ClientTime else now()
	local charge = if Net.IsFiniteNumber(packet.Charge) then math.clamp(packet.Charge, 0, 1) else 0
	Combat.Melee(c, math.floor(packet.Slot), packet.Direction, clientTime, charge)
end

local function onUseUtility(player: Player, packet: any)
	local c = combatantFor(player)
	if c == nil or type(packet) ~= "table" or not Net.IsFiniteNumber(packet.Slot) then
		return
	end
	if not canAct(c) then
		return
	end
	local slotIndex = math.floor(packet.Slot)
	local slot = c.Slots[slotIndex]
	if slot == nil or slotIndex ~= c.EquippedSlot then
		return
	end
	local id = slot.ItemId
	local head = headPosition(c)
	if head == nil then
		return
	end
	local ok = false
	if id == "SmokeBomb" or id == "Fireball" or id == "HealingFlask" then
		if Net.IsVector3(packet.Direction) and (packet.Direction :: Vector3).Magnitude > 0.5 then
			local origin = if Net.IsVector3(packet.Origin) and ((packet.Origin :: Vector3) - head).Magnitude <= ORIGIN_TOLERANCE then packet.Origin else head
			local clientTime = if Net.IsFiniteNumber(packet.ClientTime) then packet.ClientTime else now()
			local spec = EquipmentDatabase.Get(id)
			if spec and now() - slot.LastUse >= 0.6 then
				ok = Utility.Throw(c, slotIndex, origin, (packet.Direction :: Vector3).Unit, now() - clientTime)
				if ok then
					Combat.Shot:Fire(c, id, origin, (packet.Direction :: Vector3).Unit * (spec.ProjectileSpeed or 80), spec.GravityScale or 1)
				end
			end
		end
	elseif id == "SnapTrap" or id == "Palisade" then
		if Net.IsVector3(packet.Target) then
			ok = Utility.Place(c, slotIndex, packet.Target)
		end
	elseif id == "WarHorn" then
		ok = Utility.WarHorn(c, slotIndex)
	end
	if ok then
		local s = c.Slots[slotIndex]
		if s and s.Count == 0 then
			-- out of charges: fall back to the first slot that still has uses
			for i, other in c.Slots do
				if other.Count ~= 0 then
					Combat.Equip(c, i)
					break
				end
			end
		end
	end
	Combat.PushInventory(c)
end

local function onStartHeal(player: Player, slotIndex: any)
	local c = combatantFor(player)
	if c == nil or not Net.IsFiniteNumber(slotIndex) or not canAct(c) then
		return
	end
	local i = math.floor(slotIndex)
	if i ~= c.EquippedSlot then
		return
	end
	Utility.StartHeal(c, i)
end

local function onCancelHeal(player: Player)
	local c = combatantFor(player)
	if c then
		Utility.CancelHeal(c)
	end
end

local function onToggleBlock(player: Player, on: any)
	local c = combatantFor(player)
	if c == nil or type(on) ~= "boolean" then
		return
	end
	local spec = DamageModel.EquippedSpec(c)
	local allowed = on and c.Alive and spec ~= nil and (spec.CanBlock == true or (spec.SubType == "SHIELD" and c.ShieldHP > 0))
	c.Blocking = allowed == true
	if c.Character then
		c.Character:SetAttribute("Blocking", c.Blocking)
	end
end

local function onEquip(player: Player, slotIndex: any)
	local c = combatantFor(player)
	if c == nil or not Net.IsFiniteNumber(slotIndex) or not c.Alive then
		return
	end
	local i = math.floor(slotIndex)
	if c.Slots[i] and i ~= c.EquippedSlot then
		Combat.Equip(c, i)
	end
end

local function onSlide(player: Player, active: any)
	local c = combatantFor(player)
	if c == nil or type(active) ~= "boolean" then
		return
	end
	c.Sliding = active and c.Alive
	if c.Character then
		c.Character:SetAttribute("Sliding", c.Sliding)
	end
end

local function onCatchChakram(player: Player)
	-- the server already auto-catches within 4 studs; this widens the catch to 7 studs on input
	local c = combatantFor(player)
	if c == nil or c.Root == nil then
		return
	end
	for _, p in Projectiles.Active() do
		if p.Owner == c and p.ItemId == "Chakram" and p.Returning then
			if (p.State.Position - (c.Root :: BasePart).Position).Magnitude < 7 then
				p.State.Position = (c.Root :: BasePart).Position
			end
		end
	end
end

local stateRelay: { [string]: number } = {}

local function onCharacterState(player: Player, pitch: any)
	local c = combatantFor(player)
	if c == nil or not Net.IsFiniteNumber(pitch) then
		return
	end
	c.Pitch = math.clamp(pitch, -1.5, 1.5)
	stateRelay[c.Id] = c.Pitch
end

local function onDrawRatio(player: Player, ratio: any)
	local c = combatantFor(player)
	if c == nil or not Net.IsFiniteNumber(ratio) or c.Character == nil then
		return
	end
	local r = math.floor(math.clamp(ratio, 0, 1) * 10 + 0.5) / 10
	if c.Character:GetAttribute("DrawRatio") ~= r then
		c.Character:SetAttribute("DrawRatio", r)
	end
end

---------------------------------------------------------------------------------------------
-- Main loop
---------------------------------------------------------------------------------------------
function Combat.Start()
	Net.Reliable("FireProjectile").OnServerEvent:Connect(onFire)
	Net.Reliable("MeleeSwing").OnServerEvent:Connect(onMelee)
	Net.Reliable("UseUtility").OnServerEvent:Connect(onUseUtility)
	Net.Reliable("StartHeal").OnServerEvent:Connect(onStartHeal)
	Net.Reliable("CancelHeal").OnServerEvent:Connect(onCancelHeal)
	Net.Reliable("ToggleBlock").OnServerEvent:Connect(onToggleBlock)
	Net.Reliable("EquipSlot").OnServerEvent:Connect(onEquip)
	Net.Reliable("SlideRequest").OnServerEvent:Connect(onSlide)
	Net.Reliable("CatchChakram").OnServerEvent:Connect(onCatchChakram)
	Net.Unreliable("ReplicateCharacterState").OnServerEvent:Connect(onCharacterState)
	Net.Unreliable("ReplicateBowDrawRatio").OnServerEvent:Connect(onDrawRatio)

	Players.PlayerRemoving:Connect(function(player)
		local c = Registry.ForPlayer(player)
		if c then
			if c.Alive then
				c.Alive = false
				DamageModel.Killed:Fire(c, nil, {
					VictimId = c.Id,
					AttackerId = nil,
					Amount = 0,
					ArmorAmount = 0,
					Position = Vector3.zero,
					Headshot = false,
					ArmorBroken = false,
					Staggered = false,
					Blocked = false,
					Killed = true,
					WeaponId = "Disconnect",
				}, {})
			end
			Combat.Remove(c)
		end
	end)

	local snapshotAccum = 0
	local slowAccum = 0
	local relayAccum = 0
	local snapshotInterval = 1 / GameConfig.Combat.SnapshotRate
	RunService.Heartbeat:Connect(function(dt)
		local t = now()
		snapshotAccum += dt
		if snapshotAccum >= snapshotInterval then
			snapshotAccum = 0
			Registry.RecordSnapshots(t)
		end
		Projectiles.Step(dt)
		Utility.Tick(dt)
		slowAccum += dt
		if slowAccum >= 0.1 then
			slowAccum = 0
			for _, c in Registry.All() do
				updateMovement(c)
				if c.Player and c.Player.Parent == Players then
					c.Latency = math.clamp(c.Player:GetNetworkPing() * 0.5, 0, 1)
				end
			end
		end
		relayAccum += dt
		if relayAccum >= 0.1 then
			relayAccum = 0
			if next(stateRelay) ~= nil then
				Net.Unreliable("ReplicateCharacterState"):FireAllClients(stateRelay)
				stateRelay = {}
			end
		end
	end)
end

-- Round cleanup for one context: projectiles, deployables, stuck arrows stay (timed).
function Combat.ClearContext(context: string)
	Projectiles.ClearContext(context)
	Utility.ClearContext(context)
end

return Combat
