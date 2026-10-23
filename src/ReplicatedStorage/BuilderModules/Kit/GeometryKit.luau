--!strict
-- GeometryKit: primitives for procedural construction (Part, WedgePart, CornerWedgePart,
-- cylinders, SpecialMesh, CSG unions, WeldConstraint/Motor6D rigging, attachments, VFX).
-- Every builder module composes its models from these helpers so that dimensions stay exact.

local GeometryService = game:GetService("GeometryService")
local RunService = game:GetService("RunService")

local GeometryKit = {}

export type PartOpts = {
	Transparency: number?,
	Anchored: boolean?,
	CanCollide: boolean?,
	CanQuery: boolean?,
	CanTouch: boolean?,
	Reflectance: number?,
	CastShadow: boolean?,
	Group: string?,
	Massless: boolean?,
}

local DEFAULT_OPTS: PartOpts = {}

function GeometryKit.RGB(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

local function applyCommon(p: BasePart, name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material, opts: PartOpts?)
	local o = opts or DEFAULT_OPTS
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Anchored = if o.Anchored == nil then true else o.Anchored
	p.CanCollide = if o.CanCollide == nil then true else o.CanCollide
	p.CanQuery = if o.CanQuery == nil then true else o.CanQuery
	p.CanTouch = if o.CanTouch == nil then false else o.CanTouch
	p.Transparency = o.Transparency or 0
	p.Reflectance = o.Reflectance or 0
	p.CastShadow = if o.CastShadow == nil then true else o.CastShadow
	p.Massless = o.Massless == true
	if o.Group then
		p.CollisionGroup = o.Group
	end
end

function GeometryKit.Part(
	parent: Instance?,
	name: string,
	size: Vector3,
	cf: CFrame,
	color: Color3,
	material: Enum.Material,
	opts: PartOpts?
): Part
	local p = Instance.new("Part")
	applyCommon(p, name, size, cf, color, material, opts)
	p.Parent = parent
	return p
end

function GeometryKit.Wedge(
	parent: Instance?,
	name: string,
	size: Vector3,
	cf: CFrame,
	color: Color3,
	material: Enum.Material,
	opts: PartOpts?
): WedgePart
	local p = Instance.new("WedgePart")
	applyCommon(p, name, size, cf, color, material, opts)
	p.Parent = parent
	return p
end

function GeometryKit.CornerWedge(
	parent: Instance?,
	name: string,
	size: Vector3,
	cf: CFrame,
	color: Color3,
	material: Enum.Material,
	opts: PartOpts?
): CornerWedgePart
	local p = Instance.new("CornerWedgePart")
	applyCommon(p, name, size, cf, color, material, opts)
	p.Parent = parent
	return p
end

-- Cylinder whose axis runs along the CFrame's X (Roblox convention). Use CylinderY for vertical.
function GeometryKit.Cylinder(
	parent: Instance?,
	name: string,
	length: number,
	diameter: number,
	cf: CFrame,
	color: Color3,
	material: Enum.Material,
	opts: PartOpts?
): Part
	local p = GeometryKit.Part(parent, name, Vector3.new(length, diameter, diameter), cf, color, material, opts)
	p.Shape = Enum.PartType.Cylinder
	return p
end

-- Vertical cylinder centred at `position` (axis along world Y) with an optional yaw.
function GeometryKit.CylinderY(
	parent: Instance?,
	name: string,
	height: number,
	diameter: number,
	position: Vector3,
	color: Color3,
	material: Enum.Material,
	opts: PartOpts?
): Part
	return GeometryKit.Cylinder(
		parent,
		name,
		height,
		diameter,
		CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90)),
		color,
		material,
		opts
	)
end

function GeometryKit.Ball(
	parent: Instance?,
	name: string,
	diameter: number,
	cf: CFrame,
	color: Color3,
	material: Enum.Material,
	opts: PartOpts?
): Part
	local p = GeometryKit.Part(parent, name, Vector3.one * diameter, cf, color, material, opts)
	p.Shape = Enum.PartType.Ball
	return p
end

-- Cylinder spanning two points (rope segments, braces, rafters, bow limbs).
function GeometryKit.Rod(
	parent: Instance?,
	name: string,
	a: Vector3,
	b: Vector3,
	diameter: number,
	color: Color3,
	material: Enum.Material,
	opts: PartOpts?
): Part
	local mid = (a + b) / 2
	local len = (b - a).Magnitude
	local cf = CFrame.lookAt(mid, b) * CFrame.Angles(0, math.rad(90), 0)
	return GeometryKit.Cylinder(parent, name, math.max(len, 0.05), diameter, cf, color, material, opts)
end

-- Box spanning two points (planks, beams).
function GeometryKit.Beam3(
	parent: Instance?,
	name: string,
	a: Vector3,
	b: Vector3,
	width: number,
	height: number,
	color: Color3,
	material: Enum.Material,
	opts: PartOpts?
): Part
	local mid = (a + b) / 2
	local len = (b - a).Magnitude
	local up = if math.abs((b - a).Unit.Y) > 0.99 then Vector3.xAxis else Vector3.yAxis
	local cf = CFrame.lookAt(mid, b, up)
	return GeometryKit.Part(parent, name, Vector3.new(width, height, math.max(len, 0.05)), cf, color, material, opts)
end

function GeometryKit.Mesh(part: BasePart, meshType: Enum.MeshType, scale: Vector3?, offset: Vector3?): SpecialMesh
	local m = Instance.new("SpecialMesh")
	m.MeshType = meshType
	m.Scale = scale or Vector3.one
	m.Offset = offset or Vector3.zero
	m.Parent = part
	return m
end

function GeometryKit.Model(parent: Instance?, name: string): Model
	local m = Instance.new("Model")
	m.Name = name
	m.Parent = parent
	return m
end

function GeometryKit.Folder(parent: Instance, name: string): Folder
	local existing = parent:FindFirstChild(name)
	if existing and existing:IsA("Folder") then
		return existing
	end
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent
	return f
end

function GeometryKit.Attachment(parent: BasePart, name: string, cf: CFrame?): Attachment
	local a = Instance.new("Attachment")
	a.Name = name
	a.CFrame = cf or CFrame.identity
	a.Parent = parent
	return a
end

function GeometryKit.Weld(part0: BasePart, part1: BasePart): WeldConstraint
	local w = Instance.new("WeldConstraint")
	w.Part0 = part0
	w.Part1 = part1
	w.Parent = part1
	return w
end

-- Motor6D preserving the current relative offset (for animated sub-parts like a flintlock hammer).
function GeometryKit.Motor(part0: BasePart, part1: BasePart, name: string, pivotWorld: CFrame?): Motor6D
	local m = Instance.new("Motor6D")
	m.Name = name
	m.Part0 = part0
	m.Part1 = part1
	local pivot = pivotWorld or part1.CFrame
	m.C0 = part0.CFrame:ToObjectSpace(pivot)
	m.C1 = part1.CFrame:ToObjectSpace(pivot)
	m.Parent = part0
	return m
end

-- Weld every BasePart in `model` to `root`, set the PrimaryPart and unanchor for character use.
function GeometryKit.WeldAll(model: Model, root: BasePart, keepAnchored: boolean?)
	model.PrimaryPart = root
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d ~= root then
			-- parts already jointed (Motor6D sub-rigs, pre-welded clusters) keep their own joints
			local jointed = false
			for _, j in d:GetJoints() do
				if j:IsA("JointInstance") or j:IsA("WeldConstraint") then
					jointed = true
				end
			end
			if not jointed then
				GeometryKit.Weld(root, d)
			end
			d.Anchored = false
			d.Massless = true
			d.CanCollide = false
			d.CanTouch = false
			if d:GetAttribute("ShieldCollider") ~= true then
				d.CanQuery = false
			end
		end
	end
	root.Anchored = keepAnchored == true
	root.CanCollide = false
	root.CanTouch = false
	root.CanQuery = false
	root.Massless = true
end

function GeometryKit.SetGroup(root: Instance, group: string)
	if root:IsA("BasePart") then
		root.CollisionGroup = group
	end
	for _, d in root:GetDescendants() do
		if d:IsA("BasePart") then
			d.CollisionGroup = group
		end
	end
end

-- Parts placed along an arc in the CFrame's local XY plane. Used for bow limbs, horns, rims.
-- Returns the created segments in order.
function GeometryKit.Arc(
	parent: Instance,
	name: string,
	center: CFrame,
	radius: number,
	startDeg: number,
	endDeg: number,
	segments: number,
	thickness: number,
	depth: number,
	color: Color3,
	material: Enum.Material,
	opts: PartOpts?
): { Part }
	local list = {}
	local step = (endDeg - startDeg) / segments
	local segLen = 2 * radius * math.sin(math.rad(math.abs(step)) / 2) + 0.02
	for i = 0, segments - 1 do
		local mid = math.rad(startDeg + step * (i + 0.5))
		local pos = Vector3.new(math.cos(mid) * radius, math.sin(mid) * radius, 0)
		local cf = center * CFrame.new(pos) * CFrame.Angles(0, 0, mid + math.pi / 2)
		local p = GeometryKit.Part(parent, string.format("%s_%d", name, i + 1), Vector3.new(segLen, thickness, depth), cf, color, material, opts)
		table.insert(list, p)
	end
	return list
end

-- Ring of parts lying in the CFrame's local XZ plane (fountain rims, plazas, stone circles).
function GeometryKit.Ring(
	parent: Instance,
	name: string,
	center: CFrame,
	radius: number,
	segments: number,
	width: number,
	height: number,
	color: Color3,
	material: Enum.Material,
	opts: PartOpts?
): { Part }
	local list = {}
	local segLen = 2 * radius * math.sin(math.pi / segments) + 0.05
	for i = 0, segments - 1 do
		local a = (i / segments) * 2 * math.pi
		local cf = center * CFrame.Angles(0, a, 0) * CFrame.new(0, 0, -radius)
		local p = GeometryKit.Part(parent, string.format("%s_%d", name, i + 1), Vector3.new(segLen, height, width), cf, color, material, opts)
		table.insert(list, p)
	end
	return list
end

-- CSG union through GeometryService (server/Studio only). Falls back to a welded Model when the
-- call is unavailable (client context or CSG failure), so callers always receive geometry.
function GeometryKit.Union(parts: { BasePart }, name: string, parent: Instance?): Instance
	if #parts == 0 then
		local empty = Instance.new("Model")
		empty.Name = name
		empty.Parent = parent
		return empty
	end
	if #parts == 1 then
		parts[1].Name = name
		parts[1].Parent = parent
		return parts[1]
	end
	if RunService:IsServer() or not RunService:IsRunning() then
		local base = parts[1]
		local others = table.move(parts, 2, #parts, 1, {})
		local ok, result = pcall(function()
			return GeometryService:UnionAsync(base, others, {
				CollisionFidelity = Enum.CollisionFidelity.PreciseConvexDecomposition,
				RenderFidelity = Enum.RenderFidelity.Automatic,
				SplitApart = false,
			})
		end)
		if ok and result and #result > 0 then
			local u = result[1]
			u.Name = name
			u.Anchored = base.Anchored
			u.CanCollide = base.CanCollide
			u.CanQuery = base.CanQuery
			u.CanTouch = base.CanTouch
			u.CollisionGroup = base.CollisionGroup
			u.UsePartColor = true
			u.Color = base.Color
			u.Material = base.Material
			u.Parent = parent
			for _, p in parts do
				p:Destroy()
			end
			return u
		end
	end
	local model = Instance.new("Model")
	model.Name = name
	for _, p in parts do
		p.Parent = model
	end
	model.Parent = parent
	return model
end

-- Subtract negative parts from a base part (hollow chakram ring, archways, windows).
function GeometryKit.Subtract(base: BasePart, negatives: { BasePart }, name: string, parent: Instance?): Instance
	if RunService:IsServer() or not RunService:IsRunning() then
		local ok, result = pcall(function()
			return GeometryService:SubtractAsync(base, negatives, {
				CollisionFidelity = Enum.CollisionFidelity.PreciseConvexDecomposition,
				RenderFidelity = Enum.RenderFidelity.Automatic,
				SplitApart = false,
			})
		end)
		if ok and result and #result > 0 then
			local u = result[1]
			u.Name = name
			u.Anchored = base.Anchored
			u.CanCollide = base.CanCollide
			u.CanQuery = base.CanQuery
			u.CollisionGroup = base.CollisionGroup
			u.UsePartColor = true
			u.Color = base.Color
			u.Material = base.Material
			u.Parent = parent
			base:Destroy()
			for _, n in negatives do
				n:Destroy()
			end
			return u
		end
	end
	for _, n in negatives do
		n:Destroy()
	end
	base.Name = name
	base.Parent = parent
	return base
end

function GeometryKit.PointLight(parent: Instance, color: Color3, brightness: number, range: number, shadows: boolean?): PointLight
	local l = Instance.new("PointLight")
	l.Color = color
	l.Brightness = brightness
	l.Range = range
	l.Shadows = shadows == true
	l.Parent = parent
	return l
end

export type EmitterProps = {
	Name: string?,
	Texture: string?,
	Color: ColorSequence?,
	Size: NumberSequence?,
	Transparency: NumberSequence?,
	Lifetime: NumberRange?,
	Rate: number?,
	Speed: NumberRange?,
	SpreadAngle: Vector2?,
	Acceleration: Vector3?,
	Drag: number?,
	RotSpeed: NumberRange?,
	Rotation: NumberRange?,
	LightEmission: number?,
	LightInfluence: number?,
	EmissionDirection: Enum.NormalId?,
	Enabled: boolean?,
	LockedToPart: boolean?,
	ZOffset: number?,
	Shape: Enum.ParticleEmitterShape?,
	ShapeStyle: Enum.ParticleEmitterShapeStyle?,
	ShapeInOut: Enum.ParticleEmitterShapeInOut?,
	Squash: NumberSequence?,
	Orientation: Enum.ParticleOrientation?,
	Brightness: number?,
}

-- Built-in particle textures that ship with every Roblox client (no asset upload required).
GeometryKit.Textures = {
	Spark = "rbxasset://textures/particles/sparkles_main.dds",
	Fire = "rbxasset://textures/particles/fire_main.dds",
	FireSparks = "rbxasset://textures/particles/fire_sparks_main.dds",
	Smoke = "rbxasset://textures/particles/smoke_main.dds",
	Explosion = "rbxasset://textures/particles/explosion01_core_main.dds",
	ExplosionSmoke = "rbxasset://textures/particles/explosion01_smoke_main.dds",
	ExplosionShockwave = "rbxasset://textures/particles/explosion01_shockwave_main.dds",
	ExplosionImplosion = "rbxasset://textures/particles/explosion01_implosion_main.dds",
	ForceField = "rbxasset://textures/particles/forcefield_glow_main.dds",
	ForceFieldVortex = "rbxasset://textures/particles/forcefield_vortex_main.dds",
}

function GeometryKit.Emitter(parent: Instance, props: EmitterProps): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.Name = props.Name or "Emitter"
	e.Texture = props.Texture or GeometryKit.Textures.Spark
	e.Color = props.Color or ColorSequence.new(Color3.new(1, 1, 1))
	e.Size = props.Size or NumberSequence.new(0.5)
	e.Transparency = props.Transparency or NumberSequence.new(0)
	e.Lifetime = props.Lifetime or NumberRange.new(1)
	e.Rate = props.Rate or 10
	e.Speed = props.Speed or NumberRange.new(5)
	e.SpreadAngle = props.SpreadAngle or Vector2.new(0, 0)
	e.Acceleration = props.Acceleration or Vector3.zero
	e.Drag = props.Drag or 0
	e.RotSpeed = props.RotSpeed or NumberRange.new(0)
	e.Rotation = props.Rotation or NumberRange.new(0)
	e.LightEmission = props.LightEmission or 0
	e.LightInfluence = props.LightInfluence or 1
	e.EmissionDirection = props.EmissionDirection or Enum.NormalId.Top
	e.Enabled = if props.Enabled == nil then true else props.Enabled
	e.LockedToPart = props.LockedToPart == true
	e.ZOffset = props.ZOffset or 0
	e.Brightness = props.Brightness or 1
	if props.Shape then
		e.Shape = props.Shape
	end
	if props.ShapeStyle then
		e.ShapeStyle = props.ShapeStyle
	end
	if props.ShapeInOut then
		e.ShapeInOut = props.ShapeInOut
	end
	if props.Squash then
		e.Squash = props.Squash
	end
	if props.Orientation then
		e.Orientation = props.Orientation
	end
	e.Parent = parent
	return e
end

export type BeamProps = {
	Transparency: NumberSequence?,
	LightEmission: number?,
	Texture: string?,
	CurveSize0: number?,
	CurveSize1: number?,
	Segments: number?,
	FaceCamera: boolean?,
	TextureSpeed: number?,
	TextureLength: number?,
	Width1: number?,
}

function GeometryKit.BeamBetween(
	parent: Instance,
	a0: Attachment,
	a1: Attachment,
	color: Color3,
	width: number,
	props: BeamProps?
): Beam
	local b = Instance.new("Beam")
	b.Attachment0 = a0
	b.Attachment1 = a1
	b.Color = ColorSequence.new(color)
	b.Width0 = width
	local p: BeamProps = props or {}
	b.Width1 = p.Width1 or width
	b.Transparency = p.Transparency or NumberSequence.new(0)
	b.LightEmission = p.LightEmission or 0
	b.FaceCamera = if p.FaceCamera == nil then true else p.FaceCamera
	b.Segments = p.Segments or 10
	b.CurveSize0 = p.CurveSize0 or 0
	b.CurveSize1 = p.CurveSize1 or 0
	b.TextureSpeed = p.TextureSpeed or 0
	b.TextureLength = p.TextureLength or 1
	if p.Texture then
		b.Texture = p.Texture
	end
	b.Parent = parent
	return b
end

function GeometryKit.Trail(parent: Instance, a0: Attachment, a1: Attachment, color: ColorSequence, lifetime: number, transparency: NumberSequence?): Trail
	local t = Instance.new("Trail")
	t.Attachment0 = a0
	t.Attachment1 = a1
	t.Color = color
	t.Lifetime = lifetime
	t.Transparency = transparency or NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
	t.LightEmission = 0.6
	t.FaceCamera = true
	t.MinLength = 0.05
	t.WidthScale = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0) })
	t.Enabled = false
	t.Parent = parent
	return t
end

function GeometryKit.Sound(parent: Instance, name: string, soundId: string, volume: number, playbackSpeed: number?, looped: boolean?): Sound
	local s = Instance.new("Sound")
	s.Name = name
	s.SoundId = soundId
	s.Volume = volume
	s.PlaybackSpeed = playbackSpeed or 1
	s.Looped = looped == true
	s.RollOffMaxDistance = 220
	s.RollOffMinDistance = 8
	s.Parent = parent
	return s
end

-- Pointed tip (spear heads, palisade stakes, horns): two pairs of back-to-back WedgeParts crossed
-- at 90 degrees. A WedgePart's tall face is its +Z face and its slope faces -Z, so two wedges
-- whose tall faces meet at the centre plane form a ridge; crossing two ridges gives a 4-sided point.
-- `baseCF` is the centre of the tip's base; the point extends along baseCF.UpVector.
function GeometryKit.Tip(
	parent: Instance,
	name: string,
	baseCF: CFrame,
	width: number,
	height: number,
	color: Color3,
	material: Enum.Material,
	opts: PartOpts?
): { WedgePart }
	local list = {}
	local center = baseCF * CFrame.new(0, height / 2, 0)
	for i, yaw in { 0, 90 } do
		local ridge = center * CFrame.Angles(0, math.rad(yaw), 0)
		local thickness = if i == 1 then width else width * 0.999
		local a = GeometryKit.Wedge(
			parent,
			string.format("%s_%dA", name, i),
			Vector3.new(thickness, height, width / 2),
			ridge * CFrame.new(0, 0, -width / 4),
			color,
			material,
			opts
		)
		local b = GeometryKit.Wedge(
			parent,
			string.format("%s_%dB", name, i),
			Vector3.new(thickness, height, width / 2),
			ridge * CFrame.Angles(0, math.pi, 0) * CFrame.new(0, 0, -width / 4),
			color,
			material,
			opts
		)
		table.insert(list, a)
		table.insert(list, b)
	end
	return list
end

-- Flat blade edge (axe bits, scythe blades): one ridge of two back-to-back wedges, sharp edge
-- along the tip direction, thin across X.
function GeometryKit.Edge(
	parent: Instance,
	name: string,
	baseCF: CFrame,
	thickness: number,
	length: number,
	height: number,
	color: Color3,
	material: Enum.Material,
	opts: PartOpts?
): { WedgePart }
	local center = baseCF * CFrame.new(0, height / 2, 0)
	local a = GeometryKit.Wedge(parent, name .. "_A", Vector3.new(thickness, height, length / 2), center * CFrame.new(0, 0, -length / 4), color, material, opts)
	local b = GeometryKit.Wedge(
		parent,
		name .. "_B",
		Vector3.new(thickness, height, length / 2),
		center * CFrame.Angles(0, math.pi, 0) * CFrame.new(0, 0, -length / 4),
		color,
		material,
		opts
	)
	return { a, b }
end

-- Mirror helper for symmetric arenas: rotate a CFrame 180 degrees around the world Y axis.
function GeometryKit.MirrorCF(cf: CFrame): CFrame
	return CFrame.Angles(0, math.pi, 0) * cf
end

function GeometryKit.Seq(...: number): NumberSequence
	local values = { ... }
	if #values == 1 then
		return NumberSequence.new(values[1])
	end
	local kps = {}
	for i, v in values do
		table.insert(kps, NumberSequenceKeypoint.new((i - 1) / (#values - 1), v))
	end
	return NumberSequence.new(kps)
end

function GeometryKit.ColorSeq(...: Color3): ColorSequence
	local values = { ... }
	if #values == 1 then
		return ColorSequence.new(values[1])
	end
	local kps = {}
	for i, v in values do
		table.insert(kps, ColorSequenceKeypoint.new((i - 1) / (#values - 1), v))
	end
	return ColorSequence.new(kps)
end

return GeometryKit
