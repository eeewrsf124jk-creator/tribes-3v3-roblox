--!strict
-- DamageModel: the single damage pipeline.
--   1. Block / shield (frontal test  L_victim . D_attack < BlockFrontDot):
--        Shield held  -> arrows and bullets are nullified (stuck in the shield), melee drains ShieldHP
--        Sword block  -> melee damage reduced by BlockDamageReduction (80%) with a block spark
--   2. Armor: ranged damage is reduced by RangedDmgReduction (15/30/40%), melee by
--      MeleeDmgReduction, then ArmorHP absorbs before health. ArmorHP 0 -> ARMOR BROKEN broadcast
--      and the worn armor model is destroyed.
--   3. Health, knockback impulse (hammer), stagger, kill credit and assists.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local Modules = game:GetService("ReplicatedStorage"):WaitForChild("Modules")
local Types = require(Modules.Shared.Types)
local Net = require(Modules.Shared.Net)
local Signal = require(Modules.Shared.Signal)
local GameConfig = require(Modules.Config.GameConfig)
local EquipmentDatabase = require(Modules.Config.EquipmentDatabase)
local EquipmentRig = require(Modules.Shared.EquipmentRig)
local VFX = require(Modules.Shared.VFX)
local Registry = require(script.Parent.CombatantRegistry)

type Combatant = Registry.Combatant
type DamageReport = Types.DamageReport

local DamageModel = {}

export type DamageKind = "Ranged" | "Melee" | "Backstab" | "Utility" | "Ring" | "Burn" | "Trap"

export type DamageOpts = {
	Kind: DamageKind,
	WeaponId: string,
	Headshot: boolean?,
	Position: Vector3?,
	Direction: Vector3?, -- travel direction of the attack (attacker -> victim)
	ArmorShred: number?,
	Knockback: number?,
	Stagger: number?,
	IgnoreArmor: boolean?,
	IgnoreBlock: boolean?,
	Distance: number?,
}

DamageModel.Damaged = Signal.new() :: Signal.Signal<Combatant, Combatant?, DamageReport>
DamageModel.Killed = Signal.new() :: Signal.Signal<Combatant, Combatant?, DamageReport, { Combatant }>
DamageModel.ShieldBlocked = Signal.new() :: Signal.Signal<Combatant, Vector3, string>

local function now(): number
	return Workspace:GetServerTimeNow()
end

function DamageModel.Now(): number
	return now()
end

function DamageModel.EquippedSpec(c: Combatant): Types.EquipmentSpec?
	local slot = c.Slots[c.EquippedSlot]
	if slot == nil then
		return nil
	end
	return EquipmentDatabase.Get(slot.ItemId)
end

function DamageModel.EquippedLevel(c: Combatant): number
	local slot = c.Slots[c.EquippedSlot]
	return if slot then slot.Level else 1
end

-- Players who should hear about combat in a context (every player combatant in it).
function DamageModel.ContextPlayers(context: string): { Player }
	local list: { Player } = {}
	for _, c in Registry.InContext(context) do
		if c.Player and c.Player.Parent == Players then
			table.insert(list, c.Player)
		end
	end
	return list
end

function DamageModel.SendEvent(players: { Player }, packet: Types.CombatEventPacket)
	local remote = Net.Reliable("CombatEvent")
	for _, p in players do
		remote:FireClient(p, packet)
	end
end

function DamageModel.SetArmorAttributes(c: Combatant)
	local character = c.Character
	if character then
		character:SetAttribute("Armor", c.Armor)
		character:SetAttribute("ArmorMax", c.ArmorMax)
		character:SetAttribute("ShieldHP", c.ShieldHP)
	end
end

local function flat(v: Vector3): Vector3
	local f = Vector3.new(v.X, 0, v.Z)
	if f.Magnitude < 1e-4 then
		return Vector3.zero
	end
	return f.Unit
end

function DamageModel.Flat(v: Vector3): Vector3
	return flat(v)
end

local function isFrontal(victim: Combatant, direction: Vector3?): boolean
	local root = victim.Root
	if root == nil or direction == nil then
		return false
	end
	local look = flat(root.CFrame.LookVector)
	local d = flat(direction)
	return look:Dot(d) < GameConfig.Combat.BlockFrontDot
end

-- Push a velocity change onto a combatant. Player characters are simulated by their client, so
-- the impulse is sent to that client; bot characters are server-owned and changed directly.
function DamageModel.Impulse(c: Combatant, velocity: Vector3)
	local root = c.Root
	if root == nil then
		return
	end
	if c.Player then
		Net.Reliable("ApplyImpulse"):FireClient(c.Player, velocity)
	elseif not root.Anchored then
		root.AssemblyLinearVelocity += velocity
	end
end

local function stickInShield(victim: Combatant, position: Vector3, weaponId: string)
	local character = victim.Character
	local held = if character then EquipmentRig.GetHeld(character) else nil
	local collider = if held then held:FindFirstChild("ShieldCollider", true) else nil
	if collider == nil or not collider:IsA("BasePart") then
		return
	end
	local spec = EquipmentDatabase.Get(weaponId)
	local bodyName = if spec and spec.SubType == "GUN" then nil elseif weaponId == "Crossbow" then "Bolt" else "Arrow"
	if bodyName == nil then
		return
	end
	local body = VFX.Body(bodyName)
	if body == nil then
		return
	end
	local face = collider.CFrame
	local local_ = face:PointToObjectSpace(position)
	local hx, hy = collider.Size.X * 0.45, collider.Size.Y * 0.45
	local pos = face * Vector3.new(math.clamp(local_.X, -hx, hx), math.clamp(local_.Y, -hy, hy), -collider.Size.Z / 2)
	body:PivotTo(CFrame.lookAt(pos, pos + face.LookVector) * CFrame.new(0, 0, -1.2))
	for _, d in body:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = false
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
			d.Massless = true
		elseif d:IsA("Trail") then
			d.Enabled = false
		end
	end
	local primary = body.PrimaryPart or body:FindFirstChildWhichIsA("BasePart")
	if primary then
		local w = Instance.new("WeldConstraint")
		w.Part0 = collider
		w.Part1 = primary
		w.Parent = primary
	end
	body.Name = "StuckInShield"
	body.Parent = held
end

local function emptyReport(victim: Combatant, attacker: Combatant?, opts: DamageOpts): DamageReport
	local root = victim.Root
	return {
		VictimId = victim.Id,
		AttackerId = if attacker then attacker.Id else nil,
		Amount = 0,
		ArmorAmount = 0,
		Position = opts.Position or (if root then root.Position else Vector3.zero),
		Headshot = opts.Headshot == true,
		ArmorBroken = false,
		Staggered = false,
		Blocked = false,
		Killed = false,
		WeaponId = opts.WeaponId,
	}
end

local function notify(victim: Combatant, attacker: Combatant?, report: DamageReport)
	local packet: Types.CombatEventPacket = { Kind = "Damage", Report = report }
	local targets: { Player } = {}
	if attacker and attacker.Player then
		table.insert(targets, attacker.Player)
	end
	if victim.Player and victim.Player ~= (attacker and attacker.Player) then
		table.insert(targets, victim.Player)
	end
	DamageModel.SendEvent(targets, packet)
end

-- Apply `amount` raw damage. Returns the report (nil when the hit is not allowed).
function DamageModel.Apply(victim: Combatant, attacker: Combatant?, amount: number, opts: DamageOpts): DamageReport?
	if not victim.Alive then
		return nil
	end
	if attacker and not Registry.AreEnemies(attacker, victim) then
		return nil
	end
	local humanoid = victim.Humanoid
	if humanoid == nil then
		return nil
	end
	local t = now()
	local report = emptyReport(victim, attacker, opts)
	local dmg = math.max(0, amount)

	-- 1. Shield / sword block
	if not opts.IgnoreBlock and victim.Blocking and isFrontal(victim, opts.Direction) then
		local spec = DamageModel.EquippedSpec(victim)
		if spec and spec.SubType == "SHIELD" then
			report.Blocked = true
			if opts.Kind == "Ranged" then
				-- arrows and bullets are nullified by a raised shield
				stickInShield(victim, report.Position, opts.WeaponId)
				DamageModel.ShieldBlocked:Fire(victim, report.Position, opts.WeaponId)
				notify(victim, attacker, report)
				return report
			end
			if opts.Kind == "Melee" then
				victim.ShieldHP = math.max(0, victim.ShieldHP - dmg)
				DamageModel.SetArmorAttributes(victim)
				if victim.ShieldHP <= 0 then
					victim.Blocking = false
					DamageModel.SendEvent(DamageModel.ContextPlayers(victim.Context), {
						Kind = "ShieldBroken",
						VictimId = victim.Id,
						VictimName = victim.Name,
						Position = report.Position,
					})
				end
				notify(victim, attacker, report)
				return report
			end
		elseif spec and spec.CanBlock and opts.Kind == "Melee" then
			report.Blocked = true
			dmg *= 1 - (spec.BlockDamageReduction or 0.8)
		end
	end

	-- 2. Armor reduction then ArmorHP absorption
	if victim.Armor > 0 and not opts.IgnoreArmor then
		local armorSpec = if victim.ArmorId then EquipmentDatabase.Get(victim.ArmorId) else nil
		if armorSpec then
			if opts.Kind == "Ranged" or opts.Kind == "Utility" then
				dmg *= 1 - (armorSpec.RangedDmgReduction or 0)
			elseif opts.Kind == "Melee" or opts.Kind == "Backstab" then
				dmg *= 1 - (armorSpec.MeleeDmgReduction or 0)
			end
		end
		local shredMult = 1 + (opts.ArmorShred or 0)
		local armorDmg = dmg * shredMult
		if armorDmg >= victim.Armor then
			report.ArmorAmount = victim.Armor
			dmg = (armorDmg - victim.Armor) / shredMult
			victim.Armor = 0
			report.ArmorBroken = true
		else
			victim.Armor -= armorDmg
			report.ArmorAmount = armorDmg
			dmg = 0
		end
		DamageModel.SetArmorAttributes(victim)
	end

	dmg = math.max(0, dmg)
	report.Amount = dmg

	-- 3. Health
	if victim.IsDummy then
		-- training dummies never die; they only report what the hit would have done
		humanoid.Health = humanoid.MaxHealth
	elseif not victim.Invulnerable then
		humanoid.Health = math.max(0, humanoid.Health - dmg)
	end

	if attacker then
		attacker.Stats.Damage += dmg + report.ArmorAmount
		victim.Damagers[attacker.Id] = t
	end

	if report.ArmorBroken then
		if victim.Character then
			EquipmentRig.RemoveArmor(victim.Character)
		end
		DamageModel.SendEvent(DamageModel.ContextPlayers(victim.Context), {
			Kind = "ArmorBroken",
			VictimId = victim.Id,
			VictimName = victim.Name,
			Position = report.Position,
		})
	end

	if opts.Stagger and opts.Stagger > 0 and not report.Blocked then
		victim.StaggerUntil = math.max(victim.StaggerUntil, t + opts.Stagger)
		victim.Healing = nil
		report.Staggered = true
		if victim.Character then
			victim.Character:SetAttribute("StaggerUntil", victim.StaggerUntil)
		end
	end

	if opts.Knockback and opts.Knockback > 0 and opts.Direction then
		local resist = 0
		local armorSpec = if victim.ArmorId and victim.Armor > 0 then EquipmentDatabase.Get(victim.ArmorId) else nil
		if armorSpec then
			resist = armorSpec.KnockbackResist or 0
		end
		local scale = if report.Blocked then 0.35 else 1
		local impulse = flat(opts.Direction) * opts.Knockback * (1 - resist) * scale + Vector3.new(0, 18 * (1 - resist) * scale, 0)
		DamageModel.Impulse(victim, impulse)
	end

	local killed = (not victim.IsDummy) and (not victim.Invulnerable) and humanoid.Health <= 0
	report.Killed = killed
	DamageModel.Damaged:Fire(victim, attacker, report)
	notify(victim, attacker, report)
	if killed then
		DamageModel.Kill(victim, attacker, report)
	end
	return report
end

function DamageModel.Heal(c: Combatant, amount: number, source: string): number
	local humanoid = c.Humanoid
	if humanoid == nil or not c.Alive or amount <= 0 then
		return 0
	end
	local before = humanoid.Health
	humanoid.Health = math.min(humanoid.MaxHealth, before + amount)
	local healed = humanoid.Health - before
	if healed > 0 and c.Player then
		DamageModel.SendEvent({ c.Player }, { Kind = "Healed", Amount = healed, TargetId = c.Id, WeaponId = source })
	end
	return healed
end

function DamageModel.Kill(victim: Combatant, attacker: Combatant?, report: DamageReport)
	if not victim.Alive then
		return
	end
	local t = now()
	victim.Alive = false
	victim.Blocking = false
	victim.Healing = nil
	victim.BurnUntil = 0
	victim.Stats.Deaths += 1
	local humanoid = victim.Humanoid
	if humanoid and humanoid.Health > 0 then
		humanoid.Health = 0
	end
	if victim.Character then
		victim.Character:SetAttribute("Dead", true)
	end
	local assists: { Combatant } = {}
	if attacker then
		attacker.Stats.Kills += 1
	end
	for id, at in victim.Damagers do
		if (attacker == nil or id ~= attacker.Id) and t - at <= GameConfig.Combat.AssistWindow then
			local helper = Registry.Get(id)
			if helper and helper.Context == victim.Context then
				helper.Stats.Assists += 1
				table.insert(assists, helper)
			end
		end
	end
	local killerHP = 0
	if attacker and attacker.Humanoid then
		killerHP = attacker.Humanoid.Health
	end
	DamageModel.SendEvent(DamageModel.ContextPlayers(victim.Context), {
		Kind = "Kill",
		KillerId = if attacker then attacker.Id else nil,
		KillerName = if attacker then attacker.Name else "The Ring",
		VictimId = victim.Id,
		VictimName = victim.Name,
		WeaponId = report.WeaponId,
		KillerHP = killerHP,
		Headshot = report.Headshot,
		Position = report.Position,
	})
	DamageModel.Killed:Fire(victim, attacker, report, assists)
end

return DamageModel
