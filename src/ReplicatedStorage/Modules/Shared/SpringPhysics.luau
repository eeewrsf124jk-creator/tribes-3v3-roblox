--!strict
-- Second-order damped harmonic oscillator:  x'' + 2*zeta*omega*x' + omega^2*x = 0
-- Integrated with the exact closed-form solution (stable at any dt), for Vector3 or number.
-- Used for camera recoil, bow-string tremble, landing bounce, viewmodel sway and FOV zoom.

export type Spring = {
	Position: Vector3,
	Velocity: Vector3,
	Target: Vector3,
	Damping: number, -- zeta
	Frequency: number, -- omega_n (rad/s)
	Update: (self: Spring, dt: number) -> Vector3,
	Impulse: (self: Spring, velocity: Vector3) -> (),
	SetTarget: (self: Spring, target: Vector3) -> (),
	Snap: (self: Spring, position: Vector3) -> (),
}

export type ScalarSpring = {
	_inner: Spring,
	Update: (self: ScalarSpring, dt: number) -> number,
	Impulse: (self: ScalarSpring, velocity: number) -> (),
	SetTarget: (self: ScalarSpring, target: number) -> (),
	Snap: (self: ScalarSpring, position: number) -> (),
	Get: (self: ScalarSpring) -> number,
	GetTarget: (self: ScalarSpring) -> number,
}

local SpringPhysics = {}

-- Exact displacement/velocity after dt for displacement x0 and velocity v0 (per axis).
function SpringPhysics.Solve(x0: number, v0: number, zeta: number, omega: number, dt: number): (number, number)
	if omega <= 0 then
		return x0 + v0 * dt, v0
	end
	if zeta < 1 then
		local wd = omega * math.sqrt(1 - zeta * zeta)
		local e = math.exp(-zeta * omega * dt)
		local c = math.cos(wd * dt)
		local s = math.sin(wd * dt)
		local b = (v0 + zeta * omega * x0) / wd
		local x = e * (x0 * c + b * s)
		local v = e * (-zeta * omega * (x0 * c + b * s) + (-x0 * wd * s + b * wd * c))
		return x, v
	elseif zeta == 1 then
		local e = math.exp(-omega * dt)
		local a = x0
		local b = v0 + omega * x0
		local x = e * (a + b * dt)
		local v = e * (b - omega * (a + b * dt))
		return x, v
	else
		local root = math.sqrt(zeta * zeta - 1)
		local r1 = -omega * (zeta - root)
		local r2 = -omega * (zeta + root)
		local c1 = (v0 - r2 * x0) / (r1 - r2)
		local c2 = x0 - c1
		local e1 = math.exp(r1 * dt)
		local e2 = math.exp(r2 * dt)
		return c1 * e1 + c2 * e2, c1 * r1 * e1 + c2 * r2 * e2
	end
end

local SpringImpl = {}
SpringImpl.__index = SpringImpl

function SpringImpl.Update(self: Spring, dt: number): Vector3
	local d = self.Position - self.Target
	local v = self.Velocity
	local xx, vx = SpringPhysics.Solve(d.X, v.X, self.Damping, self.Frequency, dt)
	local xy, vy = SpringPhysics.Solve(d.Y, v.Y, self.Damping, self.Frequency, dt)
	local xz, vz = SpringPhysics.Solve(d.Z, v.Z, self.Damping, self.Frequency, dt)
	self.Position = self.Target + Vector3.new(xx, xy, xz)
	self.Velocity = Vector3.new(vx, vy, vz)
	return self.Position
end

function SpringImpl.Impulse(self: Spring, velocity: Vector3)
	self.Velocity += velocity
end

function SpringImpl.SetTarget(self: Spring, target: Vector3)
	self.Target = target
end

function SpringImpl.Snap(self: Spring, position: Vector3)
	self.Position = position
	self.Target = position
	self.Velocity = Vector3.zero
end

function SpringPhysics.new(initial: Vector3?, damping: number?, frequency: number?): Spring
	local p = initial or Vector3.zero
	local self = setmetatable({
		Position = p,
		Velocity = Vector3.zero,
		Target = p,
		Damping = damping or 0.6,
		Frequency = frequency or 12,
	}, SpringImpl)
	return (self :: any) :: Spring
end

local ScalarImpl = {}
ScalarImpl.__index = ScalarImpl

function ScalarImpl.Update(self: ScalarSpring, dt: number): number
	return self._inner:Update(dt).X
end

function ScalarImpl.Impulse(self: ScalarSpring, velocity: number)
	self._inner:Impulse(Vector3.new(velocity, 0, 0))
end

function ScalarImpl.SetTarget(self: ScalarSpring, target: number)
	self._inner:SetTarget(Vector3.new(target, 0, 0))
end

function ScalarImpl.Snap(self: ScalarSpring, position: number)
	self._inner:Snap(Vector3.new(position, 0, 0))
end

function ScalarImpl.Get(self: ScalarSpring): number
	return self._inner.Position.X
end

function ScalarImpl.GetTarget(self: ScalarSpring): number
	return self._inner.Target.X
end

function SpringPhysics.scalar(initial: number?, damping: number?, frequency: number?): ScalarSpring
	local self = setmetatable({
		_inner = SpringPhysics.new(Vector3.new(initial or 0, 0, 0), damping, frequency),
	}, ScalarImpl)
	return (self :: any) :: ScalarSpring
end

-- Damping ratio helpers.
function SpringPhysics.CriticalDamping(): number
	return 1
end

function SpringPhysics.HalfLifeToDamping(halfLife: number, frequency: number): number
	-- envelope e^{-zeta*omega*t} halves at t = halfLife
	return math.log(2) / (frequency * math.max(halfLife, 1e-3))
end

return SpringPhysics
