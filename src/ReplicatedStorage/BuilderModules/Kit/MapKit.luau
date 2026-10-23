--!strict
-- MapKit: architecture-scale helpers shared by the lobby and the four arena builders.
-- Conventions: ground level y = 0, Alpha spawns at -Z, Bravo at +Z, arenas are point-symmetric
-- (MapKit.Sym rotates a CFrame 180 degrees about the world Y axis for the Bravo half).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GeometryKit = require(script.Parent.GeometryKit)
local CollisionGroups = require(ReplicatedStorage:WaitForChild("Modules").Shared.CollisionGroups)

local K = GeometryKit
local RGB = Color3.fromRGB
local M = Enum.Material

local MapKit = {}

MapKit.TeamColors = {
	Alpha = RGB(60, 140, 255),
	Bravo = RGB(255, 70, 60),
}

export type MapSections = {
	Model: Model,
	TeamSpawns: Folder,
	MidLane: Folder,
	SideLanes: Folder,
	Cover: Folder,
	Mechanics: Folder,
	Clip: Folder,
}

function MapKit.NewMap(modelName: string, displayName: string, midName: string, sideName: string): MapSections
	local model = K.Model(nil, modelName)
	model:SetAttribute("DisplayName", displayName)
	local spawns = K.Folder(model, "TeamSpawns")
	local mid = K.Folder(model, midName)
	local side = K.Folder(model, sideName)
	local cover = K.Folder(model, "CoverAndProps")
	local mech = K.Folder(model, "Shared_Map_Mechanics")
	local clip = K.Folder(mech, "Invisible_ClipBrushes")
	return {
		Model = model,
		TeamSpawns = spawns,
		MidLane = mid,
		SideLanes = side,
		Cover = cover,
		Mechanics = mech,
		Clip = clip,
	}
end

-- Prop placement record for the Alpha half of a symmetric map.
export type Placement = { P: Vector3, Yaw: number, Len: number? }

-- Point symmetry for the Bravo half.
function MapKit.Sym(sign: number, cf: CFrame): CFrame
	if sign > 0 then
		return CFrame.Angles(0, math.pi, 0) * cf
	end
	return cf
end

function MapKit.SymPos(sign: number, p: Vector3): Vector3
	if sign > 0 then
		return Vector3.new(-p.X, p.Y, -p.Z)
	end
	return p
end

function MapKit.TeamOf(sign: number): string
	return if sign < 0 then "Alpha" else "Bravo"
end

function MapKit.Ground(parent: Instance, name: string, size: Vector3, center: Vector3, color: Color3, material: Enum.Material): Part
	return K.Part(parent, name, size, CFrame.new(center - Vector3.new(0, size.Y / 2, 0)), color, material)
end

function MapKit.SpawnPad(parent: Instance, team: string, index: number, cf: CFrame): Part
	local color = (MapKit.TeamColors :: any)[team] :: Color3
	local pad = K.CylinderY(parent, string.format("SpawnPad_%s_%d", team, index), 0.4, 5, cf.Position + Vector3.new(0, 0.2, 0), RGB(70, 70, 76), M.Slate)
	local glow = K.CylinderY(parent, string.format("SpawnGlow_%s_%d", team, index), 0.42, 3.6, cf.Position + Vector3.new(0, 0.22, 0), color, M.Neon, {
		CanCollide = false,
		CanQuery = false,
	})
	glow.CastShadow = false
	pad:SetAttribute("Team", team)
	pad:SetAttribute("SpawnIndex", index)
	pad:SetAttribute("Facing", cf.LookVector)
	pad:AddTag("ArenaSpawnPad")
	return pad
end

-- Force-field gate that blocks the spawn exit until FIGHT (RoundStateMachine toggles it).
function MapKit.SpawnBarrier(parent: Instance, team: string, cf: CFrame, size: Vector3): Part
	local color = (MapKit.TeamColors :: any)[team] :: Color3
	local barrier = K.Part(parent, "SpawnBarrier_" .. team, size, cf, color, M.ForceField, {
		CanQuery = false,
	})
	barrier.Transparency = 0.3
	barrier.CastShadow = false
	barrier:SetAttribute("Team", team)
	barrier:AddTag("SpawnBarrier")
	return barrier
end

function MapKit.Campfire(parent: Instance, cf: CFrame): Model
	local m = K.Model(parent, "Campfire")
	for i = 0, 7 do
		local a = math.rad(i * 45)
		K.Ball(m, "Stone" .. (i + 1), 1.1, cf * CFrame.new(math.cos(a) * 1.8, 0.35, math.sin(a) * 1.8), RGB(110, 108, 104), M.Slate)
	end
	for i = 0, 3 do
		K.Cylinder(m, "Log" .. (i + 1), 3, 0.6, cf * CFrame.new(0, 0.6, 0) * CFrame.Angles(0, math.rad(i * 45), math.rad(18)), RGB(90, 60, 36), M.Wood)
	end
	local ember = K.Part(m, "Embers", Vector3.new(1.6, 0.3, 1.6), cf * CFrame.new(0, 0.3, 0), RGB(255, 110, 30), M.Neon, { CanCollide = false })
	local fire = K.Attachment(ember, "Fire", CFrame.new(0, 0.3, 0))
	K.Emitter(fire, {
		Name = "Flames",
		Texture = K.Textures.Fire,
		Color = K.ColorSeq(RGB(255, 230, 140), RGB(255, 120, 30), RGB(120, 30, 10)),
		Size = K.Seq(1.8, 2.4, 0.2),
		Transparency = K.Seq(0.1, 0.3, 1),
		Lifetime = NumberRange.new(0.6, 1.1),
		Rate = 45,
		Speed = NumberRange.new(3, 6),
		SpreadAngle = Vector2.new(12, 12),
		LightEmission = 1,
		RotSpeed = NumberRange.new(-90, 90),
	})
	K.Emitter(fire, {
		Name = "Smoke",
		Texture = K.Textures.Smoke,
		Color = ColorSequence.new(RGB(70, 66, 62)),
		Size = K.Seq(1.5, 5),
		Transparency = K.Seq(0.5, 1),
		Lifetime = NumberRange.new(2.5, 4),
		Rate = 8,
		Speed = NumberRange.new(4, 7),
		Acceleration = Vector3.new(1.5, 1, 0),
	})
	K.Emitter(fire, {
		Name = "Sparks",
		Texture = K.Textures.FireSparks,
		Color = ColorSequence.new(RGB(255, 190, 80)),
		Size = K.Seq(0.25, 0),
		Lifetime = NumberRange.new(1, 2),
		Rate = 10,
		Speed = NumberRange.new(5, 9),
		SpreadAngle = Vector2.new(25, 25),
		LightEmission = 1,
	})
	K.PointLight(ember, RGB(255, 150, 60), 3, 26, true)
	return m
end

function MapKit.PineTree(parent: Instance, pos: Vector3, height: number, snowy: boolean): Model
	local m = K.Model(parent, "PineTree")
	local trunkH = height * 0.35
	K.CylinderY(m, "Trunk", trunkH + 1, 1.6, pos + Vector3.new(0, (trunkH + 1) / 2, 0), RGB(84, 58, 38), M.Wood)
	local needle = RGB(42, 86, 52)
	local snow = RGB(245, 248, 255)
	local layers = 4
	for i = 0, layers - 1 do
		local t = i / layers
		local w = height * (0.62 - t * 0.38)
		local h = height * 0.32
		local y = trunkH * 0.7 + i * (height - trunkH * 0.7) / layers * 0.85
		K.Tip(m, "Needles" .. (i + 1), CFrame.new(pos + Vector3.new(0, y, 0)) * CFrame.Angles(0, math.rad(i * 22), 0), w, h, needle, M.Grass)
		if snowy then
			K.Tip(m, "Snow" .. (i + 1), CFrame.new(pos + Vector3.new(0, y + h * 0.45, 0)) * CFrame.Angles(0, math.rad(i * 22), 0), w * 0.55, h * 0.58, snow, M.Snow)
		end
	end
	-- full cover collision core so arrows cannot slip through the needle gaps
	local core = K.CylinderY(m, "CoverCore", height, 3.2, pos + Vector3.new(0, height / 2, 0), needle, M.Grass)
	core.Transparency = 1
	m:SetAttribute("CoverHeight", height)
	return m
end

function MapKit.Crate(parent: Instance, cf: CFrame, size: number): Model
	local m = K.Model(parent, "Crate")
	local wood = RGB(150, 108, 64)
	local dark = RGB(100, 70, 40)
	K.Part(m, "Box", Vector3.one * size, cf * CFrame.new(0, size / 2, 0), wood, M.WoodPlanks)
	local e = size / 2 + 0.03
	for _, axis in { Vector3.xAxis, Vector3.zAxis } do
		for _, s in { -1, 1 } do
			local offset = axis * (e * s)
			local face = cf * CFrame.new(offset + Vector3.new(0, size / 2, 0))
			-- frame edges
			K.Part(m, "Trim", if axis == Vector3.xAxis then Vector3.new(0.12, 0.35, size) else Vector3.new(size, 0.35, 0.12), face * CFrame.new(0, size / 2 - 0.18, 0), dark, M.Wood)
			K.Part(m, "Trim", if axis == Vector3.xAxis then Vector3.new(0.12, 0.35, size) else Vector3.new(size, 0.35, 0.12), face * CFrame.new(0, -size / 2 + 0.18, 0), dark, M.Wood)
			-- diagonal brace
			local diag = math.sqrt(2) * size * 0.9
			local rot = if axis == Vector3.xAxis then CFrame.Angles(math.rad(45), 0, 0) else CFrame.Angles(0, 0, math.rad(45))
			K.Part(m, "Brace", if axis == Vector3.xAxis then Vector3.new(0.12, 0.35, diag) else Vector3.new(diag, 0.35, 0.12), face * rot, dark, M.Wood)
		end
	end
	m:SetAttribute("CoverHeight", size)
	return m
end

function MapKit.LogBarricade(parent: Instance, cf: CFrame, length: number): Model
	local m = K.Model(parent, "LogBarricade")
	local wood = RGB(110, 76, 46)
	for i = 0, 2 do
		K.Cylinder(m, "Log" .. (i + 1), length, 1.3, cf * CFrame.new(0, 0.65 + i * 1.15, 0), wood, M.Wood)
	end
	for _, x in { -length / 2 + 0.8, length / 2 - 0.8 } do
		K.Beam3(m, "Stake", (cf * CFrame.new(x, 0, -1.2)).Position, (cf * CFrame.new(x, 4.4, 0.4)).Position, 0.5, 0.5, RGB(90, 62, 38), M.Wood)
		K.Beam3(m, "Stake", (cf * CFrame.new(x, 0, 1.2)).Position, (cf * CFrame.new(x, 4.4, -0.4)).Position, 0.5, 0.5, RGB(90, 62, 38), M.Wood)
	end
	m:SetAttribute("CoverHeight", 3.8)
	return m
end

-- Straight staircase rising along baseCF.LookVector from the base CFrame (bottom front edge).
function MapKit.Stairs(parent: Instance, name: string, baseCF: CFrame, width: number, rise: number, run: number, steps: number, color: Color3, material: Enum.Material): Model
	local m = K.Model(parent, name)
	local stepRise = rise / steps
	local stepRun = run / steps
	for i = 0, steps - 1 do
		local h = stepRise * (i + 1)
		K.Part(m, "Step" .. (i + 1), Vector3.new(width, h, stepRun), baseCF * CFrame.new(0, h / 2, -(i + 0.5) * stepRun), color, material)
	end
	-- smooth clip ramp over the steps so movement doesn't snag
	local clip = K.Wedge(m, "StairClip", Vector3.new(width, rise, run), baseCF * CFrame.new(0, rise / 2, -run / 2) * CFrame.Angles(0, math.pi, 0), color, M.SmoothPlastic, {
		CanQuery = false,
	})
	clip.Transparency = 1
	clip.CastShadow = false
	return m
end

-- Ramp wedge whose high side faces `cf`'s -Z direction (walk up toward LookVector).
function MapKit.Ramp(parent: Instance, name: string, cf: CFrame, size: Vector3, color: Color3, material: Enum.Material): WedgePart
	-- WedgePart: tall face at +Z, slope descends toward -Z. Rotate 180 so the ramp rises along LookVector.
	return K.Wedge(parent, name, size, cf * CFrame.new(0, size.Y / 2, 0) * CFrame.Angles(0, math.pi, 0), color, material)
end

export type Opening = { Offset: number, Width: number, Height: number, Sill: number? }

-- Wall along local X centred on `cf` (bottom centre) with rectangular openings (doors/windows).
function MapKit.Wall(parent: Instance, name: string, cf: CFrame, length: number, height: number, thickness: number, openings: { Opening }, color: Color3, material: Enum.Material): Model
	local m = K.Model(parent, name)
	table.sort(openings, function(a, b)
		return a.Offset < b.Offset
	end)
	local cursor = -length / 2
	local idx = 0
	local function seg(x0: number, x1: number, y0: number, y1: number)
		if x1 - x0 < 0.05 or y1 - y0 < 0.05 then
			return
		end
		idx += 1
		K.Part(m, "Seg" .. idx, Vector3.new(x1 - x0, y1 - y0, thickness), cf * CFrame.new((x0 + x1) / 2, (y0 + y1) / 2, 0), color, material)
	end
	for _, o in openings do
		local x0 = o.Offset - o.Width / 2
		local x1 = o.Offset + o.Width / 2
		local sill = o.Sill or 0
		seg(cursor, x0, 0, height)
		seg(x0, x1, 0, sill)
		seg(x0, x1, sill + o.Height, height)
		cursor = x1
	end
	seg(cursor, length / 2, 0, height)
	return m
end

function MapKit.Rock(parent: Instance, pos: Vector3, size: number, color: Color3, material: Enum.Material, seed: number): Model
	local rng = Random.new(seed)
	local m = K.Model(parent, "Rock")
	K.Part(m, "Core", Vector3.new(size, size * 0.7, size * 0.9), CFrame.new(pos + Vector3.new(0, size * 0.3, 0)) * CFrame.Angles(0, rng:NextNumber() * 6.28, rng:NextNumber() * 0.3), color, material)
	for i = 1, 4 do
		local s = size * rng:NextNumber(0.35, 0.6)
		local offset = Vector3.new(rng:NextNumber(-0.5, 0.5) * size, rng:NextNumber(0.1, 0.6) * size, rng:NextNumber(-0.5, 0.5) * size)
		local cf = CFrame.new(pos + offset) * CFrame.Angles(rng:NextNumber() * 6.28, rng:NextNumber() * 6.28, rng:NextNumber() * 6.28)
		if i % 2 == 0 then
			K.CornerWedge(m, "Chunk" .. i, Vector3.one * s, cf, color, material)
		else
			K.Wedge(m, "Chunk" .. i, Vector3.new(s, s * 0.8, s), cf, color, material)
		end
	end
	m:SetAttribute("CoverHeight", size)
	return m
end

function MapKit.Clip(parent: Instance, name: string, size: Vector3, cf: CFrame, wedge: boolean?): BasePart
	local p: BasePart
	if wedge then
		p = K.Wedge(parent, name, size, cf, Color3.new(1, 1, 1), M.SmoothPlastic)
	else
		p = K.Part(parent, name, size, cf, Color3.new(1, 1, 1), M.SmoothPlastic)
	end
	p.Transparency = 1
	p.CanCollide = true
	p.CanQuery = false
	p.CastShadow = false
	return p
end

-- Invisible boundary walls around the playable rectangle.
function MapKit.Boundary(clipFolder: Instance, halfX: number, halfZ: number, height: number)
	MapKit.Clip(clipFolder, "Boundary_N", Vector3.new(halfX * 2 + 4, height, 2), CFrame.new(0, height / 2, halfZ + 1))
	MapKit.Clip(clipFolder, "Boundary_S", Vector3.new(halfX * 2 + 4, height, 2), CFrame.new(0, height / 2, -halfZ - 1))
	MapKit.Clip(clipFolder, "Boundary_E", Vector3.new(2, height, halfZ * 2 + 4), CFrame.new(halfX + 1, height / 2, 0))
	MapKit.Clip(clipFolder, "Boundary_W", Vector3.new(2, height, halfZ * 2 + 4), CFrame.new(-halfX - 1, height / 2, 0))
	MapKit.Clip(clipFolder, "Boundary_Ceiling", Vector3.new(halfX * 2 + 4, 2, halfZ * 2 + 4), CFrame.new(0, height + 1, 0))
end

-- Corner fillers: invisible 45-degree wedges at the inside corners of cover so characters don't
-- snag on box edges.
function MapKit.CornerClip(clipFolder: Instance, cf: CFrame, height: number)
	MapKit.Clip(clipFolder, "CornerClip", Vector3.new(0.8, height, 0.8), cf * CFrame.new(0, height / 2, 0) * CFrame.Angles(0, math.rad(45), 0))
end

function MapKit.RingOfFire(mechanics: Instance, radius: number, height: number): Model
	local m = K.Model(mechanics, "RingOfFire_BoundaryCylinder")
	local wall = K.Cylinder(m, "FireWall", height, radius * 2, CFrame.new(0, height / 2, 0) * CFrame.Angles(0, 0, math.rad(90)), RGB(255, 110, 30), M.ForceField, {
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
	})
	wall.Transparency = 0.15
	wall.CastShadow = false
	K.Emitter(wall, {
		Name = "WallFlames",
		Texture = K.Textures.Fire,
		Color = K.ColorSeq(RGB(255, 230, 140), RGB(255, 100, 20), RGB(120, 20, 10)),
		Size = K.Seq(4, 6, 0),
		Transparency = K.Seq(0.2, 0.4, 1),
		Lifetime = NumberRange.new(0.8, 1.4),
		Rate = 0,
		Speed = NumberRange.new(4, 8),
		LightEmission = 1,
		Shape = Enum.ParticleEmitterShape.Cylinder,
		ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface,
		ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward,
		EmissionDirection = Enum.NormalId.Right,
	})
	m:SetAttribute("Radius", radius)
	m:SetAttribute("Height", height)
	m:SetAttribute("Active", false)
	m.PrimaryPart = wall
	-- hidden until the ring activates
	wall.Transparency = 1
	return m
end

function MapKit.POTGStage(mechanics: Instance): Model
	local stage = K.Model(mechanics, "POTG_CinematicStage")
	K.Folder(stage, "Actors")
	local dolly = K.Part(stage, "CameraDolly", Vector3.one, CFrame.new(0, 40, 0), Color3.new(1, 1, 1), M.SmoothPlastic, {
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
	})
	dolly.CastShadow = false
	stage.PrimaryPart = dolly
	return stage
end

-- Shallow water channel: a sunken floor plus a translucent surface tagged as a water zone.
function MapKit.WaterChannel(parent: Instance, name: string, cf: CFrame, size: Vector3, depth: number, bedColor: Color3): Model
	local m = K.Model(parent, name)
	K.Part(m, "Bed", Vector3.new(size.X, 1, size.Z), cf * CFrame.new(0, -depth - 0.5, 0), bedColor, M.Pebble)
	local surface = K.Part(m, "WaterSurface", Vector3.new(size.X, 0.2, size.Z), cf * CFrame.new(0, -0.35, 0), RGB(60, 130, 170), M.Glass, {
		CanCollide = false,
		CanQuery = false,
	})
	surface.Transparency = 0.45
	surface.Reflectance = 0.2
	surface.CastShadow = false
	surface:SetAttribute("WaterZone", true)
	surface:AddTag("WaterZone")
	return m
end

function MapKit.FinalizeMap(sections: MapSections, halfX: number, halfZ: number, ringRadius: number)
	MapKit.Boundary(sections.Clip, halfX, halfZ, 70)
	MapKit.RingOfFire(sections.Mechanics, ringRadius, 120)
	MapKit.POTGStage(sections.Mechanics)
	for _, d in sections.Model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
			if d:GetAttribute("ShieldCollider") ~= true then
				d.CollisionGroup = CollisionGroups.MapGeometry
			end
		end
	end
	local spawnCount = 0
	for _, d in sections.TeamSpawns:GetDescendants() do
		if d:HasTag("ArenaSpawnPad") then
			spawnCount += 1
		end
	end
	sections.Model:SetAttribute("SpawnCount", spawnCount)
	sections.Model:SetAttribute("HalfX", halfX)
	sections.Model:SetAttribute("HalfZ", halfZ)
end

function MapKit.ApplyLighting(model: Model, clock: number, ambient: Color3, fogColor: Color3, fogEnd: number, atmosphereDensity: number)
	model:SetAttribute("ClockTime", clock)
	model:SetAttribute("Ambient", ambient)
	model:SetAttribute("FogColor", fogColor)
	model:SetAttribute("FogEnd", fogEnd)
	model:SetAttribute("AtmosphereDensity", atmosphereDensity)
end

return MapKit
