--!strict
-- ProjectileRenderer: client-side projectile visuals.
--   * Our own shots are predicted: the arrow leaves the muzzle the moment the button is
--     released, then the server's replicate packet for that shot is matched to it by item and
--     order so the server's ProjectileResolved removes it at the authoritative impact point.
--   * Everyone else's shots are rendered from ProjectileReplicate (origin, velocity, gravity,
--     fire time): the parabola is fast-forwarded by the packet's age and stepped every frame.
--   * Rebase packets restart a parabola (chakram wall bounces); Returning discs home back to
--     their thrower with BallisticsEngine.BoomerangVelocity, the same steering the server uses.
--   * Blunderbuss volleys arrive as one packet (Id -1) carrying the seed; pellet directions are
--     regenerated with BallisticsEngine.PelletDirections so every client draws the same spread.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local Net = require(Modules.Shared.Net)
local VFX = require(Modules.Shared.VFX)
local Ballistics = require(Modules.Shared.BallisticsEngine)
local GameConfig = require(Modules.Config.GameConfig)
local EquipmentDatabase = require(Modules.Config.EquipmentDatabase)
local State = require(script.Parent.ClientState)

local Renderer = {}

export type Visual = {
	Id: number?,
	OwnerId: string,
	ItemId: string,
	Body: Model?,
	State: Ballistics.ProjectileState,
	Returning: boolean,
	Speed: number,
	Born: number,
	MaxAge: number,
	Local: boolean,
	Done: boolean,
	Spin: number,
	Impact: ((Vector3, Vector3, BasePart?) -> ())?,
}

local visuals: { Visual } = {}
local byId: { [number]: Visual } = {}
local pendingLocal: { Visual } = {} -- our predicted shots waiting for their server id
local folder: Folder? = nil

local function container(): Folder
	if folder and folder.Parent then
		return folder
	end
	local f = Instance.new("Folder")
	f.Name = "LocalProjectileVisuals"
	f.Parent = Workspace
	folder = f
	return f
end

local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Exclude
params.IgnoreWater = false
local filterAge = math.huge

local function refreshFilter()
	if os.clock() - filterAge < 0.5 then
		return
	end
	filterAge = os.clock()
	local exclude: { Instance } = { container() }
	local cam = Workspace.CurrentCamera
	if cam then
		table.insert(exclude, cam)
	end
	local runtime = Workspace:FindFirstChild("Runtime_Dynamic_Containers")
	if runtime then
		for _, name in { "ActiveProjectiles_Container", "Ragdolls_And_StuckArrows" } do
			local f = runtime:FindFirstChild(name)
			if f then
				table.insert(exclude, f)
			end
		end
	end
	local me = State.Character()
	if me then
		table.insert(exclude, me)
	end
	params.FilterDescendantsInstances = exclude
end

-- Character model for a combatant id ("P<userId>" players, bot ids in the alive folders).
function Renderer.FindCombatantModel(id: string): Model?
	local userId = tonumber(string.match(id, "^P(%d+)$"))
	if userId then
		local p = Players:GetPlayerByUserId(userId)
		return if p then p.Character else nil
	end
	local runtime = Workspace:FindFirstChild("Runtime_Dynamic_Containers")
	if runtime then
		for _, name in { "AliveCharacters_Alpha", "AliveCharacters_Bravo" } do
			local f = runtime:FindFirstChild(name)
			if f then
				for _, m in f:GetChildren() do
					if m:IsA("Model") and m:GetAttribute("CombatantId") == id then
						return m
					end
				end
			end
		end
	end
	return nil
end

local function bodyName(itemId: string): string
	local spec = EquipmentDatabase.Get(itemId)
	if itemId == "Crossbow" then
		return "Bolt"
	elseif spec and spec.SubType == "BOW" then
		return "Arrow"
	elseif spec and spec.SubType == "GUN" then
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

Renderer.BodyName = bodyName

local function makeBody(name: string, fire: boolean): Model?
	local body = VFX.Body(name)
	if body == nil then
		return nil
	end
	for _, d in body:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
		end
	end
	if fire and body.PrimaryPart then
		local flame = VFX.Clone("FireArrowFlame")
		if flame and flame:IsA("Attachment") then
			flame.Parent = body.PrimaryPart
			for _, e in flame:GetDescendants() do
				if e:IsA("ParticleEmitter") then
					e.Enabled = true
				end
			end
		end
	end
	return body
end

export type SpawnOpts = {
	Id: number?,
	OwnerId: string,
	ItemId: string,
	Body: string?,
	Origin: Vector3,
	Velocity: Vector3,
	GravityScale: number,
	Elapsed: number?,
	Fire: boolean?,
	Local: boolean?,
	MaxAge: number?,
	Impact: ((Vector3, Vector3, BasePart?) -> ())?,
}

function Renderer.Spawn(opts: SpawnOpts): Visual
	local state = Ballistics.NewState(opts.Origin, opts.Velocity, opts.GravityScale)
	local body = makeBody(opts.Body or bodyName(opts.ItemId), opts.Fire == true)
	local v: Visual = {
		Id = opts.Id,
		OwnerId = opts.OwnerId,
		ItemId = opts.ItemId,
		Body = body,
		State = state,
		Returning = false,
		Speed = opts.Velocity.Magnitude,
		Born = os.clock(),
		MaxAge = opts.MaxAge or (GameConfig.Combat.ProjectileMaxLifetime + 1),
		Local = opts.Local == true,
		Done = false,
		Spin = 0,
		Impact = opts.Impact,
	}
	if opts.Id then
		byId[opts.Id] = v
	end
	table.insert(visuals, v)
	if body then
		body:PivotTo(CFrame.lookAt(opts.Origin, opts.Origin + opts.Velocity))
		body.Parent = container()
	end
	local elapsed = opts.Elapsed or 0
	if elapsed > 0 then
		refreshFilter()
		local simulated = 0
		while simulated < elapsed and not v.Done do
			local dt = math.min(1 / 60, elapsed - simulated)
			simulated += dt
			local hit = Ballistics.Step(state, dt, params)
			if hit then
				Renderer.Finish(v, hit.Position, hit.Normal, hit.Instance)
			end
		end
	end
	return v
end

local function destroyBody(v: Visual)
	local body = v.Body
	v.Body = nil
	if body then
		-- let trails fade instead of popping
		for _, d in body:GetDescendants() do
			if d:IsA("Trail") then
				d.Enabled = false
			elseif d:IsA("ParticleEmitter") then
				d.Enabled = false
			elseif d:IsA("BasePart") then
				d.Transparency = 1
			elseif d:IsA("Light") then
				d.Enabled = false
			end
		end
		task.delay(0.5, function()
			body:Destroy()
		end)
	end
end

function Renderer.Finish(v: Visual, position: Vector3?, normal: Vector3?, part: BasePart?)
	if v.Done then
		return
	end
	v.Done = true
	if v.Id then
		byId[v.Id] = nil
	end
	local idx = table.find(pendingLocal, v)
	if idx then
		table.remove(pendingLocal, idx)
	end
	if position and v.Body then
		v.Body:PivotTo(CFrame.lookAt(position, position + (if v.State.Velocity.Magnitude > 0.1 then v.State.Velocity else Vector3.zAxis)))
	end
	destroyBody(v)
	if position and v.Impact then
		v.Impact(position, normal or Vector3.yAxis, part)
	end
end

-- Predicted local shot (spawned the instant the client fires).
function Renderer.SpawnLocal(itemId: string, origin: Vector3, velocity: Vector3, gravityScale: number, fire: boolean): Visual
	local v = Renderer.Spawn({
		OwnerId = State.MyId(),
		ItemId = itemId,
		Origin = origin,
		Velocity = velocity,
		GravityScale = gravityScale,
		Fire = fire,
		Local = true,
	})
	table.insert(pendingLocal, v)
	return v
end

local function impactBurst(position: Vector3, normal: Vector3, hitId: any)
	local cf = CFrame.lookAt(position, position + normal)
	if type(hitId) == "string" then
		VFX.Burst("HitSpark_Normal", cf, 0.8)
	else
		VFX.Burst("ImpactDust", cf, 0.5)
	end
end

local function onReplicate(packet: any)
	if type(packet) ~= "table" or type(packet.Id) ~= "number" then
		return
	end
	local myId = State.MyId()
	local now = Workspace:GetServerTimeNow()
	if packet.Rebase == true then
		local v = byId[packet.Id]
		if v == nil and packet.OwnerId == myId then
			-- a predicted disc of ours that never got matched: adopt the oldest pending one
			for _, p in pendingLocal do
				if p.ItemId == "Chakram" then
					v = p
					break
				end
			end
		end
		if v == nil and packet.Returning == true and Net.IsVector3(packet.Origin) and Net.IsVector3(packet.Velocity) then
			v = Renderer.Spawn({
				Id = packet.Id,
				OwnerId = tostring(packet.OwnerId),
				ItemId = "Chakram",
				Body = "ChakramDisc",
				Origin = packet.Origin,
				Velocity = packet.Velocity,
				GravityScale = 0,
			})
		end
		if v and Net.IsVector3(packet.Origin) and Net.IsVector3(packet.Velocity) then
			v.Id = packet.Id
			byId[packet.Id] = v
			local idx = table.find(pendingLocal, v)
			if idx then
				table.remove(pendingLocal, idx)
			end
			Ballistics.Rebase(v.State, packet.Origin, packet.Velocity)
			v.State.Gravity = Vector3.zero
			if packet.Returning == true then
				v.Returning = true
			end
			v.Born = os.clock()
		end
		return
	end
	if not (Net.IsVector3(packet.Origin) and Net.IsVector3(packet.Velocity)) then
		return
	end
	local itemId = if type(packet.ItemId) == "string" then packet.ItemId else "WoodBow"
	local gravityScale = if type(packet.GravityScale) == "number" then packet.GravityScale else 0
	local fireTime = if type(packet.FireTime) == "number" then packet.FireTime else now
	local elapsed = math.clamp(now - fireTime, 0, 0.5)

	if packet.Id == -1 then
		-- blunderbuss volley
		if packet.OwnerId == myId then
			return
		end
		local dir = (packet.Velocity :: Vector3)
		local speed = dir.Magnitude
		if speed < 1 or type(packet.Seed) ~= "number" or type(packet.Pellets) ~= "number" then
			return
		end
		local spread = if type(packet.Spread) == "number" then packet.Spread else 8
		for _, d in Ballistics.PelletDirections(dir.Unit, spread, math.clamp(packet.Pellets, 1, 16), packet.Seed) do
			Renderer.Spawn({
				OwnerId = tostring(packet.OwnerId),
				ItemId = itemId,
				Body = "Bullet",
				Origin = packet.Origin,
				Velocity = d * speed,
				GravityScale = gravityScale,
				Elapsed = elapsed,
				MaxAge = 0.6,
				Impact = function(p: Vector3, n: Vector3)
					VFX.Burst("ImpactDust", CFrame.lookAt(p, p + n), 0.3)
				end,
			})
		end
		return
	end

	if packet.OwnerId == myId then
		-- match the server id to our predicted shot of the same item (oldest first)
		for i, p in pendingLocal do
			if p.ItemId == itemId then
				table.remove(pendingLocal, i)
				p.Id = packet.Id
				byId[packet.Id] = p
				return
			end
		end
		if itemId ~= "Chakram" and itemId ~= "SmokeBomb" and itemId ~= "Fireball" and itemId ~= "HealingFlask" then
			return
		end
	end
	if byId[packet.Id] then
		return
	end
	Renderer.Spawn({
		Id = packet.Id,
		OwnerId = tostring(packet.OwnerId),
		ItemId = itemId,
		Body = if type(packet.Body) == "string" then packet.Body else nil,
		Origin = packet.Origin,
		Velocity = packet.Velocity,
		GravityScale = gravityScale,
		Elapsed = elapsed,
		Fire = packet.Fire == true,
	})
end

local function onResolved(packet: any)
	if type(packet) ~= "table" or type(packet.Id) ~= "number" then
		return
	end
	local v = byId[packet.Id]
	local position = if Net.IsVector3(packet.Position) then packet.Position :: Vector3 else nil
	local normal = if Net.IsVector3(packet.Normal) then packet.Normal :: Vector3 else Vector3.yAxis
	if v then
		Renderer.Finish(v, position, normal, nil)
	end
	if position then
		impactBurst(position, normal, packet.HitId)
	end
end

function Renderer.Step(dt: number)
	if #visuals == 0 then
		return
	end
	refreshFilter()
	local clock = os.clock()
	local i = 1
	while i <= #visuals do
		local v = visuals[i]
		if v.Done then
			table.remove(visuals, i)
		else
			if clock - v.Born > v.MaxAge then
				Renderer.Finish(v, nil, nil, nil)
			else
				if v.Returning then
					local owner = Renderer.FindCombatantModel(v.OwnerId)
					local root = if owner then owner:FindFirstChild("HumanoidRootPart") else nil
					if root and root:IsA("BasePart") then
						local target = root.Position + Vector3.new(0, 1.2, 0)
						local vel = Ballistics.BoomerangVelocity(v.State.Position, v.State.Velocity, target, v.Speed, 6, dt)
						Ballistics.Rebase(v.State, v.State.Position, vel)
						v.State.Gravity = Vector3.zero
						if (target - v.State.Position).Magnitude < 3 then
							Renderer.Finish(v, nil, nil, nil)
						end
					end
				end
				if not v.Done then
					local hit = Ballistics.Step(v.State, dt, params)
					if hit then
						if v.ItemId == "Chakram" and not v.Local then
							-- discs wait for the server's bounce/return packets
							local n = hit.Normal
							Ballistics.Rebase(v.State, hit.Position + n * 0.3, Ballistics.Reflect(v.State.Velocity, n))
							v.State.Gravity = Vector3.zero
						elseif v.Id == nil or v.Local then
							Renderer.Finish(v, hit.Position, hit.Normal, hit.Instance)
						else
							-- remote shot: hold at the impact until the server resolves it
							v.State.Velocity = Vector3.zero
							v.State.Velocity0 = Vector3.zero
							v.State.Gravity = Vector3.zero
							v.State.Origin = hit.Position
							v.MaxAge = math.min(v.MaxAge, clock - v.Born + 0.6)
						end
					end
					local body = v.Body
					if body and not v.Done then
						local pos = v.State.Position
						local vel = v.State.Velocity
						local cf = if vel.Magnitude > 0.1 then CFrame.lookAt(pos, pos + vel) else body:GetPivot().Rotation + pos
						if v.ItemId == "Chakram" then
							v.Spin += dt * 28
							cf = CFrame.new(pos) * CFrame.Angles(0, v.Spin, 0)
						end
						body:PivotTo(cf)
					end
				end
			end
			i += 1
		end
	end
end

function Renderer.Start()
	Net.Reliable("ProjectileReplicate").OnClientEvent:Connect(onReplicate)
	Net.Reliable("ProjectileResolved").OnClientEvent:Connect(onResolved)
end

return Renderer
