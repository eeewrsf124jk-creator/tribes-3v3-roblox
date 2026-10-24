--!strict
-- UtilityAndHealing: deployables (Snap Trap, Palisade), thrown utilities (Smoke Bomb, Fireball,
-- Healing Flask), the War Horn, consumable heals (Bandage, Apple, Golden Apple) and the
-- burn / heal-over-time ticks.

local Workspace = game:GetService("Workspace")
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")

local Modules = game:GetService("ReplicatedStorage"):WaitForChild("Modules")
local Types = require(Modules.Shared.Types)
local Net = require(Modules.Shared.Net)
local EquipmentDatabase = require(Modules.Config.EquipmentDatabase)
local UpgradeScalingMath = require(Modules.Config.UpgradeScalingMath)
local EquipmentRig = require(Modules.Shared.EquipmentRig)
local CollisionGroups = require(Modules.Shared.CollisionGroups)
local VFX = require(Modules.Shared.VFX)
local Registry = require(script.Parent.CombatantRegistry)
local DamageModel = require(script.Parent.DamageModel)
local Projectiles = require(script.Parent.ProjectileSimulator)

type Combatant = Registry.Combatant

local Utility = {}

type Deployable = {
	Id: string,
	Kind: "SnapTrap" | "Palisade" | "Smoke" | "FirePatch",
	Owner: Combatant,
	Context: string,
	Model: Instance,
	Position: Vector3,
	Health: number,
	ExpiresAt: number,
	Radius: number,
	Damage: number,
	Level: number,
	NextTick: number,
	Armed: boolean,
}

local deployables: { [string]: Deployable } = {}
local nextDeployId = 0
local PLACE_RANGE = 14

local function now(): number
	return Workspace:GetServerTimeNow()
end

local function container(): Instance
	local runtime = Workspace:FindFirstChild("Runtime_Dynamic_Containers")
	local f = if runtime then runtime:FindFirstChild("DeployedUtilities_Container") else nil
	return f or Workspace
end

local function newId(): string
	nextDeployId += 1
	return "D" .. nextDeployId
end

local function removeDeployable(d: Deployable, fade: boolean)
	deployables[d.Id] = nil
	if fade then
		VFX.Fade(d.Model)
	else
		d.Model:Destroy()
	end
end

-- Notify the combat service that a slot count changed.
Utility.InventoryChanged = function(_c: Combatant) end

local function consume(c: Combatant, slotIndex: number): boolean
	local slot = c.Slots[slotIndex]
	if slot == nil then
		return false
	end
	if slot.Count == 0 then
		return false
	end
	if slot.Count > 0 then
		slot.Count -= 1
	end
	slot.LastUse = now()
	Utility.InventoryChanged(c)
	return true
end

Utility.Consume = consume

---------------------------------------------------------------------------------------------
-- Ground placement
---------------------------------------------------------------------------------------------
local function groundAt(c: Combatant, target: Vector3): CFrame?
	local root = c.Root
	if root == nil then
		return nil
	end
	local flatOffset = Vector3.new(target.X - root.Position.X, 0, target.Z - root.Position.Z)
	if flatOffset.Magnitude > PLACE_RANGE then
		flatOffset = flatOffset.Unit * PLACE_RANGE
	end
	local probe = root.Position + flatOffset + Vector3.new(0, 4, 0)
	local params = Projectiles.WorldParams()
	local hit = Workspace:Raycast(probe, Vector3.new(0, -14, 0), params)
	if hit == nil or hit.Normal.Y < 0.7 then
		return nil
	end
	local facing = DamageModel.Flat(root.CFrame.LookVector)
	if facing.Magnitude < 0.5 then
		facing = Vector3.zAxis
	end
	return CFrame.lookAt(hit.Position, hit.Position + facing)
end

Utility.GroundAt = groundAt

local function anchorAll(model: Instance, group: string?)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanTouch = false
			if group then
				d.CollisionGroup = group
			end
		end
	end
end

local function placeTrap(c: Combatant, slotIndex: number, target: Vector3): boolean
	local spec = EquipmentDatabase.Get("SnapTrap")
	local prefab = EquipmentRig.GetPrefab("SnapTrap")
	local cf = groundAt(c, target)
	if spec == nil or prefab == nil or cf == nil then
		return false
	end
	if not consume(c, slotIndex) then
		return false
	end
	local model = prefab:Clone()
	model.Name = "SnapTrap_Deployed"
	model:PivotTo(cf * CFrame.new(0, 0.08, 0))
	anchorAll(model, CollisionGroups.MapGeometry)
	local handle = model:FindFirstChild("Handle")
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.CanCollide = false
			d.CanQuery = false
			-- only the base plate is anchored so the jaw Motor6Ds can swing shut
			d.Anchored = d == handle
			d.Massless = d ~= handle
		end
	end
	local id = newId()
	model:SetAttribute("DeployableId", id)
	model:SetAttribute("Team", c.Team)
	model:SetAttribute("OwnerId", c.Id)
	model.Parent = container()
	local level = c.Slots[slotIndex].Level
	deployables[id] = {
		Id = id,
		Kind = "SnapTrap",
		Owner = c,
		Context = c.Context,
		Model = model,
		Position = cf.Position,
		Health = 1,
		ExpiresAt = now() + 90,
		Radius = spec.TriggerRadius or 3.5,
		Damage = UpgradeScalingMath.ScaleDamage(spec.Damage or 35, level),
		Level = level,
		NextTick = 0,
		Armed = false,
	}
	-- 0.6 s arming delay so the trap cannot be dropped directly onto an adjacent enemy
	task.delay(0.6, function()
		local d = deployables[id]
		if d then
			d.Armed = true
		end
	end)
	return true
end

local function placePalisade(c: Combatant, slotIndex: number, target: Vector3): boolean
	local spec = EquipmentDatabase.Get("Palisade")
	local prefab = EquipmentRig.GetPrefab("Palisade")
	local cf = groundAt(c, target)
	if spec == nil or prefab == nil or cf == nil then
		return false
	end
	if not consume(c, slotIndex) then
		return false
	end
	local model = prefab:Clone()
	model.Name = "Palisade_Deployed"
	model:PivotTo(cf)
	local id = newId()
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanTouch = false
			if d:GetAttribute("ShieldCollider") == true then
				d.CollisionGroup = CollisionGroups.DestructibleShields
				d.CanCollide = true
				d.CanQuery = true
				d:SetAttribute("DeployableId", id)
			else
				d.CollisionGroup = CollisionGroups.DestructibleShields
				d.CanCollide = false
				d.CanQuery = false
			end
		end
	end
	model:SetAttribute("DeployableId", id)
	model:SetAttribute("Team", c.Team)
	local level = c.Slots[slotIndex].Level
	local hp = UpgradeScalingMath.ScaleHealth(spec.WallHealth or 180, level)
	model:SetAttribute("Health", hp)
	model:SetAttribute("MaxHealth", hp)
	model.Parent = container()
	deployables[id] = {
		Id = id,
		Kind = "Palisade",
		Owner = c,
		Context = c.Context,
		Model = model,
		Position = cf.Position,
		Health = hp,
		ExpiresAt = now() + (spec.Duration or 25),
		Radius = 0,
		Damage = 0,
		Level = level,
		NextTick = 0,
		Armed = true,
	}
	VFX.Burst("ImpactDust", cf)
	-- the logs burst up out of the ground
	local height = model:GetExtentsSize().Y
	model:PivotTo(cf * CFrame.new(0, -height, 0))
	task.spawn(function()
		local start = os.clock()
		while model.Parent do
			local a = math.clamp((os.clock() - start) / 0.25, 0, 1)
			model:PivotTo(cf * CFrame.new(0, -height * (1 - a) ^ 3, 0))
			if a >= 1 then
				break
			end
			task.wait()
		end
	end)
	return true
end

-- Projectile / melee damage against a palisade wall. Returns true when the part was a wall.
function Utility.DamageStructure(part: BasePart, amount: number, attacker: Combatant): boolean
	local id = part:GetAttribute("DeployableId")
	if type(id) ~= "string" then
		return false
	end
	local d = deployables[id]
	if d == nil or d.Kind ~= "Palisade" then
		return false
	end
	d.Health -= amount
	d.Model:SetAttribute("Health", math.max(0, d.Health))
	VFX.Burst("ImpactDust", part.CFrame)
	if d.Health <= 0 then
		VFX.Burst("ImpactDust", CFrame.new(d.Position + Vector3.new(0, 3, 0)), 2)
		removeDeployable(d, false)
	end
	if attacker.Player then
		DamageModel.SendEvent({ attacker.Player }, { Kind = "Damage", Amount = amount, Position = part.Position, WeaponId = "Structure" })
	end
	return true
end

---------------------------------------------------------------------------------------------
-- Thrown utilities
---------------------------------------------------------------------------------------------
local function smokeAt(owner: Combatant, position: Vector3, spec: Types.EquipmentSpec)
	local duration = spec.Duration or 8
	local cloud = VFX.SpawnPart("SmokeCloud_Emitter", CFrame.new(position + Vector3.new(0, 5, 0)), container(), duration + 3)
	if cloud then
		-- stop emitting at the end of the duration; Debris removes the part after particles fade
		task.delay(duration, function()
			for _, e in cloud:GetDescendants() do
				if e:IsA("ParticleEmitter") then
					e.Enabled = false
				end
			end
		end)
		cloud:SetAttribute("SmokeRadius", spec.Radius or 16)
		cloud:AddTag("SmokeCloud")
	end
	VFX.Burst("ImpactDust", CFrame.new(position))
	DamageModel.SendEvent(DamageModel.ContextPlayers(owner.Context), {
		Kind = "Status",
		Status = "Smoke",
		Position = position,
		Duration = duration,
	})
end

local function fireballAt(owner: Combatant, position: Vector3, spec: Types.EquipmentSpec, level: number, direct: Combatant?)
	local radius = spec.Radius or 10
	local impact = UpgradeScalingMath.ScaleDamage(spec.ImpactDmg or 35, level)
	VFX.Burst("FireExplosion", CFrame.new(position))
	for _, c in Registry.InContext(owner.Context) do
		local root = c.Root
		if c.Alive and root and Registry.AreEnemies(owner, c) then
			local dist = (root.Position - position).Magnitude
			if c == direct or dist <= radius then
				local falloff = if c == direct then 1 else math.clamp(1 - dist / radius * 0.5, 0.5, 1)
				local report = DamageModel.Apply(c, owner, impact * falloff, {
					Kind = "Utility",
					WeaponId = "Fireball",
					Position = root.Position,
					Direction = (root.Position - position),
				})
				if report and not report.Killed then
					local t = now()
					c.BurnUntil = t + (spec.BurnDuration or 4)
					c.BurnDPS = spec.BurnDPS or 8
					c.BurnSourceId = owner.Id
					c.BurnNextTick = t + 0.5
				end
			end
		end
	end
	local patch = VFX.SpawnPart("FirePatch", CFrame.new(position + Vector3.new(0, 0.1, 0)), container(), spec.BurnDuration or 4)
	if patch then
		local id = newId()
		deployables[id] = {
			Id = id,
			Kind = "FirePatch",
			Owner = owner,
			Context = owner.Context,
			Model = patch,
			Position = position,
			Health = 1,
			ExpiresAt = now() + (spec.BurnDuration or 4),
			Radius = radius,
			Damage = 0,
			Level = level,
			NextTick = 0,
			Armed = true,
		}
	end
end

local function flaskAt(owner: Combatant, position: Vector3, spec: Types.EquipmentSpec, level: number)
	local radius = spec.SplashRadius or 8
	local amount = UpgradeScalingMath.ScaleHealth(spec.HealAmount or 60, level)
	VFX.Burst("HealAura_GreenRing", CFrame.new(position))
	for _, c in Registry.InContext(owner.Context) do
		local root = c.Root
		if c.Alive and root and (c == owner or not Registry.AreEnemies(owner, c)) then
			if (root.Position - position).Magnitude <= radius then
				DamageModel.Heal(c, amount, "HealingFlask")
				VFX.Burst("HealAura_GreenRing", root.CFrame)
			end
		end
	end
end

-- Throw a utility from `origin` along `direction` (unit). Returns success.
function Utility.Throw(c: Combatant, slotIndex: number, origin: Vector3, direction: Vector3, elapsed: number): boolean
	local slot = c.Slots[slotIndex]
	local spec = if slot then EquipmentDatabase.Get(slot.ItemId) else nil
	if slot == nil or spec == nil or spec.ProjectileSpeed == nil then
		return false
	end
	if not consume(c, slotIndex) then
		return false
	end
	local level = slot.Level
	local itemId = slot.ItemId
	local speed = spec.ProjectileSpeed :: number
	local onImpact = function(_p: Projectiles.Projectile, info: Projectiles.ImpactInfo): boolean
		if itemId == "SmokeBomb" then
			smokeAt(c, info.Position, spec)
		elseif itemId == "Fireball" then
			fireballAt(c, info.Position, spec, level, info.Victim)
		elseif itemId == "HealingFlask" then
			flaskAt(c, info.Position, spec, level)
		end
		return true
	end
	Projectiles.Spawn(c, itemId, origin, direction * speed + Vector3.new(0, speed * 0.12, 0), spec.GravityScale or 1, {
		Damage = 0,
		Elapsed = elapsed,
		HitAllies = itemId == "HealingFlask",
		OnImpact = onImpact,
	})
	return true
end

function Utility.Place(c: Combatant, slotIndex: number, target: Vector3): boolean
	local slot = c.Slots[slotIndex]
	if slot == nil then
		return false
	end
	if slot.ItemId == "SnapTrap" then
		return placeTrap(c, slotIndex, target)
	elseif slot.ItemId == "Palisade" then
		return placePalisade(c, slotIndex, target)
	end
	return false
end

function Utility.WarHorn(c: Combatant, slotIndex: number): boolean
	local slot = c.Slots[slotIndex]
	local spec = EquipmentDatabase.Get("WarHorn")
	if slot == nil or spec == nil or c.Root == nil then
		return false
	end
	local t = now()
	if t - slot.LastUse < (spec.Cooldown or 20) then
		return false
	end
	slot.LastUse = t
	local reveal = spec.RevealDuration or 5
	local boost = spec.TeamSpeedBoost or 1.2
	local revealed: { string } = {}
	for _, other in Registry.InContext(c.Context) do
		if other.Alive then
			if Registry.AreEnemies(c, other) then
				table.insert(revealed, other.Id)
			else
				other.SpeedBoostUntil = t + reveal
				other.SpeedBoostMult = boost
			end
		end
	end
	local pulse = VFX.SpawnPart("WarHorn_Pulse", (c.Root :: BasePart).CFrame, container(), 1.2)
	if pulse then
		pulse:SetAttribute("Expand", true)
	end
	local remote = Net.Reliable("UtilityEvent")
	for _, other in Registry.InContext(c.Context) do
		if other.Player and not Registry.AreEnemies(c, other) then
			remote:FireClient(other.Player, "WarHornReveal", { Targets = revealed, Duration = reveal, Origin = (c.Root :: BasePart).Position })
		elseif other.Player then
			remote:FireClient(other.Player, "WarHornHeard", { Origin = (c.Root :: BasePart).Position })
		end
	end
	Utility.InventoryChanged(c)
	return true
end

---------------------------------------------------------------------------------------------
-- Consumable heals
---------------------------------------------------------------------------------------------
function Utility.StartHeal(c: Combatant, slotIndex: number): boolean
	local slot = c.Slots[slotIndex]
	local spec = if slot then EquipmentDatabase.Get(slot.ItemId) else nil
	if slot == nil or spec == nil or spec.Category ~= "HEALING" or slot.ItemId == "HealingFlask" then
		return false
	end
	if slot.Count == 0 or c.Healing ~= nil or not c.Alive then
		return false
	end
	local humanoid = c.Humanoid
	if humanoid == nil or humanoid.Health >= humanoid.MaxHealth then
		return false
	end
	local castTime = spec.CastTime or 0.6
	c.Healing = {
		Slot = slotIndex,
		ItemId = slot.ItemId,
		EndsAt = now() + castTime,
		Amount = UpgradeScalingMath.ScaleHealth(spec.HealAmount or 35, slot.Level),
	}
	if c.Character then
		c.Character:SetAttribute("HealingUntil", now() + castTime)
	end
	return true
end

function Utility.CancelHeal(c: Combatant)
	c.Healing = nil
	if c.Character then
		c.Character:SetAttribute("HealingUntil", 0)
	end
end

local function finishHeal(c: Combatant)
	local cast = c.Healing
	if cast == nil then
		return
	end
	c.Healing = nil
	if c.Character then
		c.Character:SetAttribute("HealingUntil", 0)
	end
	if not consume(c, cast.Slot) then
		return
	end
	local spec = EquipmentDatabase.Get(cast.ItemId)
	if spec and spec.Duration and cast.ItemId == "GoldenApple" then
		-- Golden Apple: heal over time
		c.HoTPerSecond = cast.Amount / spec.Duration
		c.HoTUntil = now() + spec.Duration
	else
		DamageModel.Heal(c, cast.Amount, cast.ItemId)
	end
	if c.Root then
		VFX.Burst("HealAura_GreenRing", (c.Root :: BasePart).CFrame * CFrame.new(0, -2.5, 0))
	end
end

---------------------------------------------------------------------------------------------
-- Ticking
---------------------------------------------------------------------------------------------
function Utility.Tick(dt: number)
	local t = now()
	for _, c in Registry.All() do
		if c.Alive then
			if c.Healing and t >= c.Healing.EndsAt then
				finishHeal(c)
			end
			if c.HoTUntil > t then
				DamageModel.Heal(c, c.HoTPerSecond * dt, "GoldenApple")
			end
			if c.BurnUntil > t and t >= c.BurnNextTick then
				c.BurnNextTick = t + 0.5
				local source = if c.BurnSourceId then Registry.Get(c.BurnSourceId) else nil
				DamageModel.Apply(c, source, c.BurnDPS * 0.5, {
					Kind = "Burn",
					WeaponId = "Fire",
					IgnoreArmor = true,
					IgnoreBlock = true,
				})
			end
		end
	end

	for _, d in deployables do
		if t >= d.ExpiresAt then
			removeDeployable(d, true)
		elseif d.Kind == "SnapTrap" and d.Armed then
			for _, c in Registry.InContext(d.Context) do
				local root = c.Root
				if c.Alive and root and Registry.AreEnemies(d.Owner, c) then
					local offset = root.Position - d.Position
					if Vector3.new(offset.X, 0, offset.Z).Magnitude <= d.Radius and math.abs(offset.Y) < 5 then
						local spec = EquipmentDatabase.Get("SnapTrap")
						local rootTime = if spec then spec.RootDuration or 2.5 else 2.5
						c.RootUntil = t + rootTime
						DamageModel.Apply(c, d.Owner, d.Damage, {
							Kind = "Trap",
							WeaponId = "SnapTrap",
							Position = d.Position,
							IgnoreBlock = true,
						})
						DamageModel.SendEvent(DamageModel.ContextPlayers(d.Context), {
							Kind = "Status",
							TargetId = c.Id,
							Status = "Rooted",
							Duration = rootTime,
							Position = d.Position,
						})
						-- snap the jaws shut (90 degree tween on each hinge), then remove
						for _, m in d.Model:GetDescendants() do
							if m:IsA("Motor6D") then
								local angle = m:GetAttribute("CloseAngle")
								if type(angle) == "number" then
									TweenService:Create(m, TweenInfo.new(0.09, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
										C0 = m.C0 * CFrame.Angles(0, 0, math.rad(angle)),
									}):Play()
								end
							end
						end
						deployables[d.Id] = nil
						Debris:AddItem(d.Model, 2.5)
						break
					end
				end
			end
		elseif d.Kind == "FirePatch" and t >= d.NextTick then
			d.NextTick = t + 0.5
			local spec = EquipmentDatabase.Get("Fireball")
			for _, c in Registry.InContext(d.Context) do
				local root = c.Root
				if c.Alive and root and Registry.AreEnemies(d.Owner, c) and (root.Position - d.Position).Magnitude <= d.Radius then
					c.BurnUntil = math.max(c.BurnUntil, t + 1)
					c.BurnDPS = if spec then spec.BurnDPS or 8 else 8
					c.BurnSourceId = d.Owner.Id
					if c.BurnNextTick < t then
						c.BurnNextTick = t
					end
				end
			end
		end
	end
end

function Utility.ClearContext(context: string)
	for _, d in deployables do
		if d.Context == context then
			removeDeployable(d, false)
		end
	end
end

function Utility.ClearOwner(c: Combatant)
	for _, d in deployables do
		if d.Owner == c then
			removeDeployable(d, false)
		end
	end
end

return Utility
