--!strict
-- VFX runtime: spawns templates from ReplicatedStorage.VFX_And_Particle_Templates.
-- Burst emitters (EmitCount attribute) fire once; continuous emitters run until cleanup.

local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local VFX = {}

local cache: { [string]: Instance } = {}
local root: Instance? = nil

local function getRoot(): Instance?
	if root == nil then
		root = ReplicatedStorage:WaitForChild("VFX_And_Particle_Templates", 30)
	end
	return root
end

function VFX.Find(name: string): Instance?
	local hit = cache[name]
	if hit and hit.Parent then
		return hit
	end
	local r = getRoot()
	if r == nil then
		return nil
	end
	local found = (r :: Instance):FindFirstChild(name, true)
	if found then
		cache[name] = found
	end
	return found
end

local function emitAll(container: Instance): number
	local longest = 0
	for _, d in container:GetDescendants() do
		if d:IsA("ParticleEmitter") then
			local count = d:GetAttribute("EmitCount")
			if type(count) == "number" then
				d:Emit(count)
			end
			longest = math.max(longest, d.Lifetime.Max)
		end
	end
	if container:IsA("ParticleEmitter") then
		local count = container:GetAttribute("EmitCount")
		if type(count) == "number" then
			container:Emit(count)
		end
		longest = math.max(longest, container.Lifetime.Max)
	end
	return longest
end

-- One-shot burst at a world CFrame. Returns the spawned attachment (already scheduled for cleanup).
function VFX.Burst(name: string, cf: CFrame, scale: number?): Instance?
	local template = VFX.Find(name)
	if template == nil or not template:IsA("Attachment") then
		return nil
	end
	local clone = template:Clone()
	clone.Parent = workspace.Terrain
	clone.WorldCFrame = cf
	if scale and scale ~= 1 then
		for _, d in clone:GetChildren() do
			if d:IsA("ParticleEmitter") then
				local kps = {}
				for _, kp in d.Size.Keypoints do
					table.insert(kps, NumberSequenceKeypoint.new(kp.Time, kp.Value * scale, kp.Envelope * scale))
				end
				d.Size = NumberSequence.new(kps)
			end
		end
	end
	local life = emitAll(clone)
	Debris:AddItem(clone, life + 0.5)
	return clone
end

-- Continuous effect attached to a part (burning, snared, heal aura). Caller destroys it.
function VFX.AttachTo(name: string, part: BasePart, offset: CFrame?): Attachment?
	local template = VFX.Find(name)
	if template == nil or not template:IsA("Attachment") then
		return nil
	end
	local clone = template:Clone() :: Attachment
	clone.CFrame = offset or CFrame.identity
	clone.Parent = part
	emitAll(clone)
	return clone
end

-- Area part effects (smoke cloud, fire patch, war horn pulse). Placed in `parent` for `duration`.
function VFX.SpawnPart(name: string, cf: CFrame, parent: Instance, duration: number?): BasePart?
	local template = VFX.Find(name)
	if template == nil or not template:IsA("BasePart") then
		return nil
	end
	local clone = template:Clone() :: BasePart
	clone.CFrame = cf
	clone.Anchored = true
	clone.Parent = parent
	emitAll(clone)
	if duration then
		Debris:AddItem(clone, duration)
	end
	return clone
end

function VFX.Billboard(name: string, adornee: BasePart, duration: number?): BillboardGui?
	local template = VFX.Find(name)
	if template == nil or not template:IsA("BillboardGui") then
		return nil
	end
	local clone = template:Clone() :: BillboardGui
	clone.Adornee = adornee
	clone.Parent = adornee
	if duration then
		Debris:AddItem(clone, duration)
	end
	return clone
end

function VFX.Clone(name: string): Instance?
	local template = VFX.Find(name)
	if template == nil then
		return nil
	end
	return template:Clone()
end

-- Projectile body model (Arrow, Bolt, Bullet, ...) cloned for rendering.
function VFX.Body(name: string): Model?
	local r = getRoot()
	local bodies = if r then r:FindFirstChild("ProjectileBodies") else nil
	local template = bodies and bodies:FindFirstChild(name)
	if template and template:IsA("Model") then
		return template:Clone()
	end
	return nil
end

-- Stop continuous emitters and destroy after their particles fade.
function VFX.Fade(instance: Instance)
	local longest = 0
	for _, d in instance:GetDescendants() do
		if d:IsA("ParticleEmitter") then
			d.Enabled = false
			longest = math.max(longest, d.Lifetime.Max)
		elseif d:IsA("Light") then
			d.Enabled = false
		end
	end
	if instance:IsA("ParticleEmitter") then
		instance.Enabled = false
	end
	Debris:AddItem(instance, longest + 0.2)
end

return VFX
