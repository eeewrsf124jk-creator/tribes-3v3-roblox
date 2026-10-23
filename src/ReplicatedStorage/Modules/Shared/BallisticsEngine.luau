--!strict
-- BallisticsEngine: deterministic projectile math shared by client prediction and server authority.
--   Parabola:   P(t) = P0 + V0*t + 1/2*g*t^2,   V(t) = V0 + g*t
--   Reflection: R = V - 2(V.N)N                 (chakram wall bounces)
--   Boomerang:  steer velocity toward the owner with exponential interpolation
--   Spread:     uniform sampling of a spherical cap around the aim direction (blunderbuss)

local BallisticsEngine = {}

export type ProjectileState = {
	Origin: Vector3,
	Velocity0: Vector3,
	Gravity: Vector3,
	Time: number,
	Position: Vector3,
	Velocity: Vector3,
}

export type StepHit = {
	Instance: BasePart,
	Position: Vector3,
	Normal: Vector3,
	Material: Enum.Material,
	Alpha: number, -- fraction of the step where the hit occurred
}

function BallisticsEngine.GravityVector(gravityScale: number): Vector3
	return Vector3.new(0, -workspace.Gravity * gravityScale, 0)
end

function BallisticsEngine.PositionAt(p0: Vector3, v0: Vector3, g: Vector3, t: number): Vector3
	return p0 + v0 * t + g * (0.5 * t * t)
end

function BallisticsEngine.VelocityAt(v0: Vector3, g: Vector3, t: number): Vector3
	return v0 + g * t
end

function BallisticsEngine.NewState(origin: Vector3, velocity: Vector3, gravityScale: number): ProjectileState
	return {
		Origin = origin,
		Velocity0 = velocity,
		Gravity = BallisticsEngine.GravityVector(gravityScale),
		Time = 0,
		Position = origin,
		Velocity = velocity,
	}
end

-- Restart the parabola from the current point with a new velocity (after a bounce).
function BallisticsEngine.Rebase(state: ProjectileState, position: Vector3, velocity: Vector3)
	state.Origin = position
	state.Velocity0 = velocity
	state.Time = 0
	state.Position = position
	state.Velocity = velocity
end

-- Advance a projectile by dt and raycast the swept segment. Returns the hit (if any); the state
-- is advanced to the hit point on impact, otherwise to the end of the step.
function BallisticsEngine.Step(state: ProjectileState, dt: number, params: RaycastParams): StepHit?
	local t1 = state.Time + dt
	local fromPos = state.Position
	local toPos = BallisticsEngine.PositionAt(state.Origin, state.Velocity0, state.Gravity, t1)
	local delta = toPos - fromPos
	local result = if delta.Magnitude > 1e-4 then workspace:Raycast(fromPos, delta, params) else nil
	if result then
		local alpha = (result.Position - fromPos).Magnitude / delta.Magnitude
		state.Time += dt * alpha
		state.Position = result.Position
		state.Velocity = BallisticsEngine.VelocityAt(state.Velocity0, state.Gravity, state.Time)
		return {
			Instance = result.Instance,
			Position = result.Position,
			Normal = result.Normal,
			Material = result.Material,
			Alpha = alpha,
		}
	end
	state.Time = t1
	state.Position = toPos
	state.Velocity = BallisticsEngine.VelocityAt(state.Velocity0, state.Gravity, t1)
	return nil
end

function BallisticsEngine.Reflect(v: Vector3, n: Vector3): Vector3
	local unitN = if n.Magnitude > 0 then n.Unit else Vector3.yAxis
	return v - 2 * v:Dot(unitN) * unitN
end

-- Steer a returning projectile toward `target`. `responsiveness` is the exponential rate (1/s).
function BallisticsEngine.BoomerangVelocity(
	position: Vector3,
	velocity: Vector3,
	target: Vector3,
	speed: number,
	responsiveness: number,
	dt: number
): Vector3
	local toTarget = target - position
	if toTarget.Magnitude < 1e-3 then
		return velocity
	end
	local desired = toTarget.Unit * speed
	local alpha = 1 - math.exp(-responsiveness * dt)
	local blended = velocity:Lerp(desired, alpha)
	if blended.Magnitude < 1e-3 then
		return desired
	end
	return blended.Unit * speed
end

-- Uniform random direction inside a cone of half-angle `angleDeg` around `direction`.
function BallisticsEngine.SampleCone(direction: Vector3, angleDeg: number, rng: Random): Vector3
	local dir = direction.Unit
	local cosMax = math.cos(math.rad(angleDeg))
	local cosTheta = 1 - rng:NextNumber() * (1 - cosMax)
	local sinTheta = math.sqrt(math.max(0, 1 - cosTheta * cosTheta))
	local phi = rng:NextNumber() * 2 * math.pi
	-- Build an orthonormal basis around dir.
	local helper = if math.abs(dir.Y) < 0.99 then Vector3.yAxis else Vector3.xAxis
	local right = dir:Cross(helper).Unit
	local up = right:Cross(dir).Unit
	return (dir * cosTheta + right * (sinTheta * math.cos(phi)) + up * (sinTheta * math.sin(phi))).Unit
end

-- Deterministic pellet pattern shared by client and server via the shot seed.
function BallisticsEngine.PelletDirections(direction: Vector3, angleDeg: number, count: number, seed: number): { Vector3 }
	local rng = Random.new(seed)
	local dirs = table.create(count)
	dirs[1] = direction.Unit
	for i = 2, count do
		dirs[i] = BallisticsEngine.SampleCone(direction, angleDeg, rng)
	end
	return dirs
end

-- Linear damage falloff after `startDist`, reaching `minMult` at startDist + span.
function BallisticsEngine.Falloff(distance: number, startDist: number, span: number?, minMult: number?): number
	local s = span or 27
	local m = minMult or 0.35
	if distance <= startDist then
		return 1
	end
	local a = math.clamp((distance - startDist) / s, 0, 1)
	return 1 + (m - 1) * a
end

-- Ray vs oriented box (slab test in box space). Returns the entry distance along the ray
-- within [0, maxDist], or nil. `dir` must be a unit vector.
function BallisticsEngine.RayOBB(origin: Vector3, dir: Vector3, maxDist: number, boxCFrame: CFrame, boxSize: Vector3): number?
	local o = boxCFrame:PointToObjectSpace(origin)
	local d = boxCFrame:VectorToObjectSpace(dir)
	local half = boxSize * 0.5
	local tMin = 0
	local tMax = maxDist
	local axes = { { o.X, d.X, half.X }, { o.Y, d.Y, half.Y }, { o.Z, d.Z, half.Z } }
	for _, axis in axes do
		local oa, da, ha = axis[1], axis[2], axis[3]
		if math.abs(da) < 1e-8 then
			if oa < -ha or oa > ha then
				return nil
			end
		else
			local inv = 1 / da
			local t1 = (-ha - oa) * inv
			local t2 = (ha - oa) * inv
			if t1 > t2 then
				t1, t2 = t2, t1
			end
			tMin = math.max(tMin, t1)
			tMax = math.min(tMax, t2)
			if tMin > tMax then
				return nil
			end
		end
	end
	return tMin
end

-- Is a point inside a (possibly inflated) oriented box?
function BallisticsEngine.PointInOBB(point: Vector3, boxCFrame: CFrame, boxSize: Vector3, inflate: number?): boolean
	local p = boxCFrame:PointToObjectSpace(point)
	local h = boxSize * 0.5 + Vector3.one * (inflate or 0)
	return math.abs(p.X) <= h.X and math.abs(p.Y) <= h.Y and math.abs(p.Z) <= h.Z
end

-- Sample the arc for previews (throw trajectory lines). Stops at the first hit.
function BallisticsEngine.TraceArc(
	origin: Vector3,
	velocity: Vector3,
	gravityScale: number,
	maxTime: number,
	stepTime: number,
	params: RaycastParams
): ({ Vector3 }, RaycastResult?)
	local g = BallisticsEngine.GravityVector(gravityScale)
	local points = { origin }
	local prev = origin
	local t = 0
	while t < maxTime do
		t += stepTime
		local p = BallisticsEngine.PositionAt(origin, velocity, g, t)
		local hit = workspace:Raycast(prev, p - prev, params)
		if hit then
			table.insert(points, hit.Position)
			return points, hit
		end
		table.insert(points, p)
		prev = p
	end
	return points, nil
end

-- Scale launch speed/damage by draw (bows) or charge (slings, javelins).
function BallisticsEngine.DrawScale(ratio: number): (number, number)
	local r = math.clamp(ratio, 0, 1)
	local speedMult = 0.4 + 0.6 * r
	local dmgMult = 0.35 + 0.65 * r
	return speedMult, dmgMult
end

return BallisticsEngine
