--!strict
-- ProjectileSimulator: server-authoritative projectile flight.
--   Flight follows BallisticsEngine (P(t) = P0 + V0 t + 1/2 g t^2) in 1/60 s sub-steps.
--   World geometry is raycast with the Projectiles collision group (characters excluded); every
--   swept segment is then tested against enemy hitboxes REWOUND to (stepTime - shooterRewind)
--   with ray-vs-OBB, so the shooter is favoured by their latency (capped by MaxRewindLatency).
--   Catch-up: a shot fired `elapsed` seconds ago (client timestamp) is fast-forwarded on spawn.
--   Chakram: reflects off walls (R = V - 2(V.N)N) BounceCount times, then homes back to its owner.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local Modules = game:GetService("ReplicatedStorage"):WaitForChild("Modules")
local Types = require(Modules.Shared.Types)
local Net = require(Modules.Shared.Net)
local GameConfig = require(Modules.Config.GameConfig)
local EquipmentDatabase = require(Modules.Config.EquipmentDatabase)
local Ballistics = require(Modules.Shared.BallisticsEngine)
local CollisionGroups = require(Modules.Shared.CollisionGroups)
local VFX = require(Modules.Shared.VFX)
local Registry = require(script.Parent.CombatantRegistry)
local DamageModel = require(script.Parent.DamageModel)

type Combatant = Registry.Combatant

local Projectiles = {}

export type ImpactInfo = {
	Position: Vector3,
	Normal: Vector3,
	Victim: Combatant?,
	PartName: string?,
	Instance: BasePart?,
}

export type Projectile = {
	Id: number,
	Owner: Combatant,
	Context: string,
	ItemId: string,
	Spec: Types.EquipmentSpec,
	Body: string,
	State: Ballistics.ProjectileState,
	GravityScale: number,
	Speed: number,
	Damage: number,
	HeadMult: number,
	Fire: boolean,
	Falloff: boolean,
	Rewind: number,
	Born: number,
	Age: number,
	MaxAge: number,
	Traveled: number,
	Origin: Vector3,
	BouncesLeft: number,
	Returning: boolean,
	Range: number,
	HitAllies: boolean,
	HitIds: { [string]: boolean },
	OnImpact: ((Projectile, ImpactInfo) -> boolean)?, -- return true to stop the projectile
	Done: boolean,
}

export type SpawnOpts = {
	Damage: number,
	HeadMult: number?,
	Fire: boolean?,
	Falloff: boolean?,
	Elapsed: number?,
	Body: string?,
	HitAllies: boolean?,
	OnImpact: ((Projectile, ImpactInfo) -> boolean)?,
	Silent: boolean?,
}

local INTERP_DELAY = 0.1
local SUBSTEP = 1 / 60
local MAX_STUCK = 60

local active: { [number]: Projectile } = {}
local nextId = 0
local stuck: { Instance } = {}

-- Hook for deployables (palisade walls) hit by projectiles: return true if the part absorbed it.
Projectiles.StructureHit = nil :: ((BasePart, number, Combatant) -> boolean)?

local function now(): number
	return Workspace:GetServerTimeNow()
end

local function bodyFor(itemId: string, spec: Types.EquipmentSpec): string
	if itemId == "Crossbow" then
		return "Bolt"
	elseif spec.SubType == "BOW" then
		return "Arrow"
	elseif spec.SubType == "GUN" then
		return "Bullet"
	elseif itemId == "Sling" then
		return "Stone"
	elseif itemId == "ThrowingKnives" then
		return "Knife"
	elseif itemId == "Javelins" then
		return "Javelin"
	elseif itemId == "Harpoon" then
		return "HarpoonBolt"
	elseif itemId == "Chakram" then
		return "ChakramDisc"
	elseif itemId == "Bolas" then
		return "BolasThrown"
	elseif itemId == "SmokeBomb" then
		return "SmokeBombThrown"
	elseif itemId == "Fireball" then
		return "FireballThrown"
	elseif itemId == "HealingFlask" then
		return "FlaskThrown"
	end
	return "Stone"
end

Projectiles.BodyFor = bodyFor

local worldParams = RaycastParams.new()
worldParams.FilterType = Enum.RaycastFilterType.Exclude
worldParams.CollisionGroup = CollisionGroups.Projectiles
worldParams.IgnoreWater = true

local function refreshWorldFilter()
	local exclude: { Instance } = Registry.Characters()
	for _, player in Players:GetPlayers() do
		if player.Character then
			table.insert(exclude, player.Character)
		end
	end
	local runtime = Workspace:FindFirstChild("Runtime_Dynamic_Containers")
	if runtime then
		local p = runtime:FindFirstChild("ActiveProjectiles_Container")
		local r = runtime:FindFirstChild("Ragdolls_And_StuckArrows")
		if p then
			table.insert(exclude, p)
		end
		if r then
			table.insert(exclude, r)
		end
		for _, name in { "AliveCharacters_Alpha", "AliveCharacters_Bravo" } do
			local f = runtime:FindFirstChild(name)
			if f then
				table.insert(exclude, f)
			end
		end
	end
	worldParams.FilterDescendantsInstances = exclude
end

function Projectiles.WorldParams(): RaycastParams
	refreshWorldFilter()
	return worldParams
end

function Projectiles.RewindFor(c: Combatant): number
	return math.clamp(c.Latency + INTERP_DELAY, 0, GameConfig.Combat.MaxRewindLatency)
end

local function broadcast(packet: { [string]: any })
	Net.Reliable("ProjectileReplicate"):FireAllClients(packet)
end

local function resolve(p: Projectile, position: Vector3, normal: Vector3, hitId: string?)
	if p.Done then
		return
	end
	p.Done = true
	active[p.Id] = nil
	Net.Reliable("ProjectileResolved"):FireAllClients({
		Id = p.Id,
		Position = position,
		Normal = normal,
		HitId = hitId,
		ItemId = p.ItemId,
	})
end

local function stickArrow(p: Projectile, position: Vector3, normal: Vector3)
	if p.Body ~= "Arrow" and p.Body ~= "Bolt" and p.Body ~= "Javelin" and p.Body ~= "Knife" then
		return
	end
	local body = VFX.Body(p.Body)
	local runtime = Workspace:FindFirstChild("Runtime_Dynamic_Containers")
	local folder = if runtime then runtime:FindFirstChild("Ragdolls_And_StuckArrows") else nil
	if body == nil or folder == nil then
		return
	end
	local dir = if p.State.Velocity.Magnitude > 0.1 then p.State.Velocity.Unit else -normal
	-- bodies fly along -Z with the tip at the front; bury 35% of the length
	body:PivotTo(CFrame.lookAt(position, position + dir) * CFrame.new(0, 0, 0.5))
	for _, d in body:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
		elseif d:IsA("Trail") then
			d.Enabled = false
		end
	end
	body.Parent = folder
	table.insert(stuck, body)
	if #stuck > MAX_STUCK then
		local old = table.remove(stuck, 1)
		if old then
			old:Destroy()
		end
	end
	task.delay(10, function()
		if body.Parent then
			body:Destroy()
		end
		local idx = table.find(stuck, body)
		if idx then
			table.remove(stuck, idx)
		end
	end)
end

local function hitCombatant(p: Projectile, victim: Combatant, partName: string, position: Vector3)
	local spec = p.Spec
	local headshot = partName == "Head"
	local dmg = p.Damage
	if headshot then
		dmg *= p.HeadMult
	end
	if p.Falloff and spec.FalloffStart then
		dmg *= Ballistics.Falloff((position - p.Origin).Magnitude, spec.FalloffStart)
	end
	local direction = if p.State.Velocity.Magnitude > 0.01 then p.State.Velocity.Unit else Vector3.zAxis
	local report = DamageModel.Apply(victim, p.Owner, dmg, {
		Kind = "Ranged",
		WeaponId = p.ItemId,
		Headshot = headshot,
		Position = position,
		Direction = direction,
		Distance = (position - p.Origin).Magnitude,
	})
	if report == nil or report.Blocked then
		return
	end
	local t = now()
	if p.Fire then
		victim.BurnUntil = t + GameConfig.Combat.FireArrowBurnDuration
		victim.BurnDPS = GameConfig.Combat.FireArrowBurnDPS
		victim.BurnSourceId = p.Owner.Id
		victim.BurnNextTick = t + 0.5
	end
	if spec.SnareDuration then
		victim.SnareUntil = t + spec.SnareDuration
		victim.SnareMult = spec.SnareSpeedMult or 0.25
		DamageModel.SendEvent(DamageModel.ContextPlayers(victim.Context), {
			Kind = "Status",
			TargetId = victim.Id,
			Status = "Snared",
			Duration = spec.SnareDuration,
		})
	end
	if spec.PullForce and victim.Root and p.Owner.Root then
		local toOwner = p.Owner.Root.Position - victim.Root.Position
		local flatDir = DamageModel.Flat(toOwner)
		local strength = math.min(spec.PullForce, toOwner.Magnitude * 2.2)
		DamageModel.Impulse(victim, flatDir * strength + Vector3.new(0, 14, 0))
	end
end

-- Closest enemy hitbox along a segment at rewound time `t`.
local function traceCombatants(p: Projectile, from: Vector3, to: Vector3, t: number): (number?, Combatant?, string?)
	local delta = to - from
	local len = delta.Magnitude
	if len < 1e-4 then
		return nil, nil, nil
	end
	local dir = delta / len
	local mid = (from + to) / 2
	local reach = len / 2 + 8
	local tol = Vector3.one * GameConfig.Combat.HitboxTolerance
	local best: number? = nil
	local bestC: Combatant? = nil
	local bestPart: string? = nil
	for _, c in Registry.InContext(p.Context) do
		local eligible = c.Alive and c ~= p.Owner and not p.HitIds[c.Id]
		if eligible and not p.HitAllies then
			eligible = Registry.AreEnemies(p.Owner, c)
		end
		local root = c.Root
		if eligible and root and (root.Position - mid).Magnitude <= reach then
			for _, pose in Registry.PoseAt(c, t) do
				local hitT = Ballistics.RayOBB(from, dir, len, pose.CFrame, pose.Size + tol)
				if hitT and (best == nil or hitT < best or (pose.Name == "Head" and best and math.abs(hitT - best) < 0.05)) then
					best = hitT
					bestC = c
					bestPart = pose.Name
				end
			end
		end
	end
	return best, bestC, bestPart
end

local function startReturn(p: Projectile)
	p.Returning = true
	p.HitIds = {}
	broadcast({
		Id = p.Id,
		Rebase = true,
		Returning = true,
		Origin = p.State.Position,
		Velocity = p.State.Velocity,
		GravityScale = 0,
		FireTime = now(),
		OwnerId = p.Owner.Id,
	})
end

local function finishChakram(p: Projectile)
	-- caught: refund the throw
	local slotIndex = 0
	for i, s in p.Owner.Slots do
		if s.ItemId == p.ItemId then
			slotIndex = i
		end
	end
	local slot = p.Owner.Slots[slotIndex]
	if slot and slot.Count >= 0 then
		slot.Count += 1
	end
	if p.Owner.Character then
		p.Owner.Character:SetAttribute("ChakramOut", false)
	end
	resolve(p, p.State.Position, Vector3.yAxis, nil)
	Projectiles.InventoryChanged(p.Owner)
end

-- Overridden by the combat service to push the inventory view after refunds.
Projectiles.InventoryChanged = function(_c: Combatant) end

local function stepProjectile(p: Projectile, dt: number, simNow: number)
	local state = p.State
	if p.Returning then
		local ownerRoot = p.Owner.Root
		if ownerRoot == nil or not p.Owner.Alive then
			resolve(p, state.Position, Vector3.yAxis, nil)
			return
		end
		local target = ownerRoot.Position + Vector3.new(0, 1.5, 0)
		if (target - state.Position).Magnitude < 4 then
			finishChakram(p)
			return
		end
		local v = Ballistics.BoomerangVelocity(state.Position, state.Velocity, target, p.Speed, 6, dt)
		Ballistics.Rebase(state, state.Position, v)
		state.Gravity = Vector3.zero
	end

	local from = state.Position
	local worldHit = Ballistics.Step(state, dt, worldParams)
	local to = state.Position
	p.Age += dt
	p.Traveled += (to - from).Magnitude

	local hitTime = simNow - p.Rewind
	local tHit, victim, partName = traceCombatants(p, from, to, hitTime)
	if victim and partName and tHit then
		local pos = from + (to - from).Unit * tHit
		if p.OnImpact then
			local stop = p.OnImpact(p, { Position = pos, Normal = -(to - from).Unit, Victim = victim, PartName = partName })
			if stop then
				resolve(p, pos, Vector3.yAxis, victim.Id)
				return
			end
		else
			hitCombatant(p, victim, partName, pos)
			if p.ItemId == "Chakram" then
				p.HitIds[victim.Id] = true
				if not p.Returning then
					-- rebase from the hit point so clients stay in sync, then come home
					Ballistics.Rebase(state, pos, state.Velocity)
					startReturn(p)
				end
				return
			end
			resolve(p, pos, Vector3.yAxis, victim.Id)
			return
		end
	end

	if worldHit then
		local part = worldHit.Instance
		if Projectiles.StructureHit and part:GetAttribute("DeployableId") ~= nil then
			if Projectiles.StructureHit(part, p.Damage, p.Owner) then
				stickArrow(p, worldHit.Position, worldHit.Normal)
				resolve(p, worldHit.Position, worldHit.Normal, nil)
				return
			end
		end
		if p.OnImpact then
			local stop = p.OnImpact(p, { Position = worldHit.Position, Normal = worldHit.Normal, Instance = part })
			if stop then
				resolve(p, worldHit.Position, worldHit.Normal, nil)
				return
			end
		end
		if p.ItemId == "Chakram" then
			if p.Returning then
				-- returning disc slides along walls: reflect but keep homing
				Ballistics.Rebase(state, worldHit.Position + worldHit.Normal * 0.3, Ballistics.Reflect(state.Velocity, worldHit.Normal))
				return
			end
			if p.BouncesLeft > 0 then
				p.BouncesLeft -= 1
				local v = Ballistics.Reflect(state.Velocity, worldHit.Normal)
				Ballistics.Rebase(state, worldHit.Position + worldHit.Normal * 0.3, v)
				state.Gravity = Vector3.zero
				broadcast({
					Id = p.Id,
					Rebase = true,
					Origin = state.Position,
					Velocity = v,
					GravityScale = 0,
					FireTime = now(),
					OwnerId = p.Owner.Id,
				})
				VFX.Burst("HitSpark_Normal", CFrame.new(worldHit.Position, worldHit.Position + worldHit.Normal))
				return
			end
			startReturn(p)
			Ballistics.Rebase(state, worldHit.Position + worldHit.Normal * 0.3, Ballistics.Reflect(state.Velocity, worldHit.Normal))
			return
		end
		stickArrow(p, worldHit.Position, worldHit.Normal)
		resolve(p, worldHit.Position, worldHit.Normal, nil)
		return
	end

	if p.ItemId == "Chakram" and not p.Returning and p.Traveled >= p.Range then
		startReturn(p)
		return
	end
	if p.Age >= p.MaxAge or state.Position.Y < -200 then
		if p.ItemId == "Chakram" then
			finishChakram(p)
			return
		end
		resolve(p, state.Position, Vector3.yAxis, nil)
	end
end

function Projectiles.Spawn(owner: Combatant, itemId: string, origin: Vector3, velocity: Vector3, gravityScale: number, opts: SpawnOpts): Projectile?
	local spec = EquipmentDatabase.Get(itemId)
	if spec == nil then
		return nil
	end
	nextId += 1
	local t = now()
	local elapsed = math.clamp(opts.Elapsed or 0, 0, GameConfig.Combat.MaxRewindLatency)
	local p: Projectile = {
		Id = nextId,
		Owner = owner,
		Context = owner.Context,
		ItemId = itemId,
		Spec = spec,
		Body = opts.Body or bodyFor(itemId, spec),
		State = Ballistics.NewState(origin, velocity, gravityScale),
		GravityScale = gravityScale,
		Speed = velocity.Magnitude,
		Damage = opts.Damage,
		HeadMult = opts.HeadMult or spec.HeadMult or 1,
		Fire = opts.Fire == true,
		Falloff = opts.Falloff == true,
		Rewind = Projectiles.RewindFor(owner),
		Born = t - elapsed,
		Age = 0,
		MaxAge = if itemId == "Chakram" then 8 else GameConfig.Combat.ProjectileMaxLifetime,
		Traveled = 0,
		Origin = origin,
		BouncesLeft = spec.BounceCount or 0,
		Returning = false,
		Range = spec.Range or 500,
		HitAllies = opts.HitAllies == true,
		HitIds = {},
		OnImpact = opts.OnImpact,
		Done = false,
	}
	active[p.Id] = p
	if not opts.Silent then
		broadcast({
			Id = p.Id,
			OwnerId = owner.Id,
			ItemId = itemId,
			Body = p.Body,
			Origin = origin,
			Velocity = velocity,
			GravityScale = gravityScale,
			FireTime = p.Born,
			Fire = p.Fire,
		})
	end
	-- fast-forward the time the packet spent in flight, testing hitboxes in the past
	refreshWorldFilter()
	local simulated = 0
	while simulated < elapsed - 1e-6 and not p.Done do
		local dt = math.min(SUBSTEP, elapsed - simulated)
		simulated += dt
		stepProjectile(p, dt, p.Born + simulated)
	end
	return p
end

function Projectiles.Step(dt: number)
	if next(active) == nil then
		return
	end
	refreshWorldFilter()
	local t = now()
	local steps = math.max(1, math.ceil(dt / SUBSTEP))
	local sub = dt / steps
	for _, p in active do
		for i = 1, steps do
			if p.Done then
				break
			end
			stepProjectile(p, sub, t - dt + sub * i)
		end
	end
end

function Projectiles.ClearContext(context: string)
	for _, p in active do
		if p.Context == context then
			resolve(p, p.State.Position, Vector3.yAxis, nil)
		end
	end
end

function Projectiles.Active(): { [number]: Projectile }
	return active
end

return Projectiles
