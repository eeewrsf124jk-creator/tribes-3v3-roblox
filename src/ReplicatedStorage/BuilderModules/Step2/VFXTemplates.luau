--!strict
-- Step 2d: VFX and particle templates. Burst emitters are disabled and carry an "EmitCount"
-- attribute; Modules/Shared/VFX clones a template and calls :Emit(EmitCount) on each emitter.

local GeometryKit = require(script.Parent.Parent.Kit.GeometryKit)

local K = GeometryKit
local T = K.Textures
local RGB = Color3.fromRGB
local M = Enum.Material

local VFXTemplates = {}

local function burst(parent: Instance, count: number, props: GeometryKit.EmitterProps): ParticleEmitter
	props.Enabled = false
	props.Rate = 0
	local e = K.Emitter(parent, props)
	e:SetAttribute("EmitCount", count)
	return e
end

local function holder(folder: Folder, name: string): Attachment
	-- Attachments must live under a BasePart to render; templates are stored on a carrier part
	-- and VFX re-parents the cloned attachment onto a carrier at the effect position.
	local carrier = folder:FindFirstChild("Carrier") :: BasePart?
	if carrier == nil then
		local p = K.Part(folder, "Carrier", Vector3.one * 0.2, CFrame.new(0, -1000, 0), Color3.new(1, 1, 1), M.SmoothPlastic, {
			Transparency = 1,
			CanCollide = false,
			CanQuery = false,
			CanTouch = false,
			CastShadow = false,
		})
		carrier = p
	end
	local old = (carrier :: BasePart):FindFirstChild(name)
	if old then
		old:Destroy()
	end
	return K.Attachment(carrier :: BasePart, name, CFrame.identity)
end

local function replace(folder: Instance, name: string)
	local old = folder:FindFirstChild(name)
	if old then
		old:Destroy()
	end
end

---------------------------------------------------------------------------------------------
function VFXTemplates.BuildProjectileTrails(folder: Folder)
	-- Trails: attachments are assigned at runtime by the projectile renderer
	for _, name in { "ArrowWindTrail", "BulletTracer", "ChakramArc" } do
		replace(folder, name)
	end
	local wind = Instance.new("Trail")
	wind.Name = "ArrowWindTrail"
	wind.Color = ColorSequence.new(Color3.new(1, 1, 1))
	wind.Transparency = K.Seq(0.55, 1)
	wind.Lifetime = 0.22
	wind.WidthScale = K.Seq(1, 0.2)
	wind.LightEmission = 0.2
	wind.FaceCamera = true
	wind.Parent = folder

	local tracer = Instance.new("Trail")
	tracer.Name = "BulletTracer"
	tracer.Color = K.ColorSeq(RGB(255, 245, 160), RGB(255, 200, 60))
	tracer.Transparency = K.Seq(0, 1)
	tracer.Lifetime = 0.09
	tracer.WidthScale = K.Seq(1, 0.4)
	tracer.LightEmission = 1
	tracer.FaceCamera = true
	tracer.Parent = folder

	local arc = Instance.new("Trail")
	arc.Name = "ChakramArc"
	arc.Color = K.ColorSeq(RGB(230, 240, 255), RGB(236, 192, 72))
	arc.Transparency = K.Seq(0.3, 1)
	arc.Lifetime = 0.3
	arc.LightEmission = 0.8
	arc.FaceCamera = true
	arc.Parent = folder

	local flame = holder(folder, "FireArrowFlame")
	K.Emitter(flame, {
		Name = "Flame",
		Texture = T.Fire,
		Color = K.ColorSeq(RGB(255, 230, 140), RGB(255, 120, 30), RGB(150, 40, 10)),
		Size = K.Seq(0.7, 0.3),
		Transparency = K.Seq(0.1, 1),
		Lifetime = NumberRange.new(0.2, 0.4),
		Rate = 80,
		Speed = NumberRange.new(0.5, 1),
		LightEmission = 1,
		RotSpeed = NumberRange.new(-120, 120),
	})
	K.Emitter(flame, {
		Name = "Smoke",
		Texture = T.Smoke,
		Color = ColorSequence.new(RGB(60, 55, 50)),
		Size = K.Seq(0.4, 1.4),
		Transparency = K.Seq(0.5, 1),
		Lifetime = NumberRange.new(0.6, 1),
		Rate = 20,
		Speed = NumberRange.new(0.5, 1.5),
		Acceleration = Vector3.new(0, 3, 0),
	})
end

-- Projectile bodies used by the client renderer and the server's stuck-arrow props.
function VFXTemplates.BuildProjectileBodies(folder: Folder)
	local function body(name: string): (Model, Part)
		replace(folder, name)
		local m = K.Model(folder, name)
		local root = K.Part(m, "Root", Vector3.one * 0.15, CFrame.identity, Color3.new(1, 1, 1), M.SmoothPlastic, {
			Transparency = 1,
			CanCollide = false,
			CanQuery = false,
		})
		m.PrimaryPart = root
		return m, root
	end
	local function seal(m: Model, root: Part, trailLength: number)
		K.Attachment(root, "TrailFront", CFrame.new(0, 0.06, 0))
		K.Attachment(root, "TrailBack", CFrame.new(0, -0.06, trailLength))
		K.WeldAll(m, root, true)
		for _, d in m:GetDescendants() do
			if d:IsA("BasePart") then
				d.CanQuery = false
				d.CastShadow = false
			end
		end
	end

	do -- Arrow: forward is -Z
		local m, root = body("Arrow")
		K.Rod(m, "Shaft", Vector3.new(0, 0, 1.6), Vector3.new(0, 0, -1.4), 0.08, RGB(170, 120, 72), M.Wood)
		K.Tip(m, "Head", CFrame.new(0, 0, -1.4) * CFrame.Angles(-math.pi / 2, 0, 0), 0.18, 0.35, RGB(120, 122, 128), M.Metal)
		for i = 0, 2 do
			local a = math.rad(i * 120)
			K.Part(m, "Fletch" .. (i + 1), Vector3.new(0.02, 0.18, 0.45), CFrame.new(0, 0, 1.3) * CFrame.Angles(0, 0, a) * CFrame.new(0, 0.1, 0), Color3.new(0.95, 0.95, 0.95), M.Fabric)
		end
		seal(m, root, 1.6)
	end
	do -- Crossbow bolt
		local m, root = body("Bolt")
		K.Rod(m, "Shaft", Vector3.new(0, 0, 0.9), Vector3.new(0, 0, -0.9), 0.1, RGB(80, 55, 35), M.Wood)
		K.Tip(m, "Head", CFrame.new(0, 0, -0.9) * CFrame.Angles(-math.pi / 2, 0, 0), 0.2, 0.3, RGB(100, 102, 110), M.Metal)
		seal(m, root, 0.9)
	end
	do -- Bullet / pellet
		local m, root = body("Bullet")
		K.Ball(m, "Ball", 0.22, CFrame.identity, RGB(70, 70, 78), M.Metal)
		seal(m, root, 0.4)
	end
	do -- Sling stone
		local m, root = body("Stone")
		K.Ball(m, "Ball", 0.34, CFrame.identity, RGB(128, 124, 118), M.Slate)
		seal(m, root, 0.3)
	end
	do -- Throwing knife (spins)
		local m, root = body("Knife")
		K.Part(m, "Grip", Vector3.new(0.12, 0.12, 0.4), CFrame.new(0, 0, 0.35), RGB(34, 30, 28), M.Fabric)
		K.Part(m, "Blade", Vector3.new(0.03, 0.18, 0.55), CFrame.new(0, 0, -0.15), RGB(214, 218, 224), M.Metal)
		K.Tip(m, "Point", CFrame.new(0, 0, -0.42) * CFrame.Angles(-math.pi / 2, 0, 0), 0.18, 0.22, RGB(214, 218, 224), M.Metal)
		seal(m, root, 0.3)
	end
	do -- Javelin
		local m, root = body("Javelin")
		K.Rod(m, "Shaft", Vector3.new(0, 0, 3), Vector3.new(0, 0, -2.6), 0.16, RGB(160, 115, 72), M.Wood)
		K.Tip(m, "Head", CFrame.new(0, 0, -2.6) * CFrame.Angles(-math.pi / 2, 0, 0), 0.32, 0.8, RGB(120, 122, 128), M.Metal)
		seal(m, root, 2)
	end
	do -- Harpoon head
		local m, root = body("HarpoonBolt")
		K.Rod(m, "Shaft", Vector3.new(0, 0, 1.5), Vector3.new(0, 0, -0.8), 0.16, RGB(74, 50, 31), M.Wood)
		K.Tip(m, "Head", CFrame.new(0, 0, -0.8) * CFrame.Angles(-math.pi / 2, 0, 0), 0.26, 0.5, RGB(176, 181, 188), M.Metal)
		local a = K.Attachment(root, "RopeAttach", CFrame.new(0, 0, 1.5))
		a:SetAttribute("Rope", true)
		seal(m, root, 1)
	end
	do -- Chakram disc
		local m, root = body("ChakramDisc")
		K.Ring(m, "Blade", CFrame.identity, 1.08, 14, 0.42, 0.12, RGB(214, 218, 224), M.Metal)
		K.Ring(m, "Gold", CFrame.new(0, 0.07, 0), 0.9, 14, 0.08, 0.02, RGB(236, 192, 72), M.Foil)
		seal(m, root, 0.2)
	end
	do -- Bolas
		local m, root = body("BolasThrown")
		K.Ball(m, "Knot", 0.3, CFrame.identity, RGB(178, 150, 104), M.Fabric)
		for i = 1, 3 do
			local a = math.rad(i * 120)
			local p = Vector3.new(math.cos(a) * 1.2, 0, math.sin(a) * 1.2)
			K.Rod(m, "Rope" .. i, Vector3.zero, p, 0.05, RGB(178, 150, 104), M.Fabric)
			K.Ball(m, "Weight" .. i, 0.38, CFrame.new(p), RGB(120, 122, 128), M.Metal)
		end
		seal(m, root, 0.2)
	end
	do -- Thrown utility bodies
		type ThrownSpec = { Name: string, Color: Color3, Material: Enum.Material, Size: number }
		local thrown: { ThrownSpec } = {
			{ Name = "SmokeBombThrown", Color = RGB(140, 138, 132), Material = M.Slate, Size = 0.9 },
			{ Name = "FireballThrown", Color = RGB(255, 140, 30), Material = M.Neon, Size = 1.1 },
			{ Name = "FlaskThrown", Color = RGB(230, 30, 60), Material = M.Glass, Size = 0.9 },
		}
		for _, entry in thrown do
			local name = entry.Name
			local m, root = body(name)
			local ball = K.Ball(m, "Ball", entry.Size, CFrame.identity, entry.Color, entry.Material)
			if name == "FireballThrown" then
				local a = K.Attachment(ball, "Flame", CFrame.identity)
				K.Emitter(a, {
					Name = "Flame",
					Texture = T.Fire,
					Color = K.ColorSeq(RGB(255, 220, 120), RGB(255, 100, 20)),
					Size = K.Seq(1.2, 0.4),
					Transparency = K.Seq(0.1, 1),
					Lifetime = NumberRange.new(0.25, 0.45),
					Rate = 90,
					Speed = NumberRange.new(0.5, 1.5),
					LightEmission = 1,
				})
				K.PointLight(ball, RGB(255, 140, 40), 3, 14)
			end
			seal(m, root, 0.3)
		end
	end
end

---------------------------------------------------------------------------------------------
function VFXTemplates.BuildImpactEffects(folder: Folder)
	local normal = holder(folder, "HitSpark_Normal")
	burst(normal, 14, {
		Name = "Sparks",
		Texture = T.Spark,
		Color = K.ColorSeq(Color3.new(1, 1, 1), RGB(255, 220, 90)),
		Size = K.Seq(0.35, 0),
		Lifetime = NumberRange.new(0.15, 0.3),
		Speed = NumberRange.new(14, 26),
		SpreadAngle = Vector2.new(70, 70),
		Drag = 6,
		LightEmission = 1,
		Orientation = Enum.ParticleOrientation.VelocityParallel,
		Squash = K.Seq(1.5, 0.5),
	})
	burst(normal, 3, {
		Name = "Flash",
		Texture = T.Explosion,
		Color = ColorSequence.new(RGB(255, 245, 210)),
		Size = K.Seq(0.6, 1.4),
		Transparency = K.Seq(0.2, 1),
		Lifetime = NumberRange.new(0.08, 0.12),
		Speed = NumberRange.new(0),
		LightEmission = 1,
	})

	local head = holder(folder, "HitSpark_Headshot")
	burst(head, 28, {
		Name = "CritSparks",
		Texture = T.Spark,
		Color = K.ColorSeq(RGB(255, 60, 40), RGB(255, 210, 60)),
		Size = K.Seq(0.55, 0),
		Lifetime = NumberRange.new(0.25, 0.45),
		Speed = NumberRange.new(18, 34),
		SpreadAngle = Vector2.new(180, 180),
		Drag = 5,
		LightEmission = 1,
		Orientation = Enum.ParticleOrientation.VelocityParallel,
	})
	burst(head, 1, {
		Name = "CritRing",
		Texture = T.ExplosionShockwave,
		Color = ColorSequence.new(RGB(255, 200, 60)),
		Size = K.Seq(0.5, 5),
		Transparency = K.Seq(0, 1),
		Lifetime = NumberRange.new(0.3),
		Speed = NumberRange.new(0),
		LightEmission = 1,
		Orientation = Enum.ParticleOrientation.FacingCamera,
	})
	burst(head, 4, {
		Name = "CritBlast",
		Texture = T.Explosion,
		Color = K.ColorSeq(RGB(255, 230, 120), RGB(255, 60, 30)),
		Size = K.Seq(1, 2.5),
		Transparency = K.Seq(0.1, 1),
		Lifetime = NumberRange.new(0.15, 0.25),
		Speed = NumberRange.new(2, 6),
		SpreadAngle = Vector2.new(180, 180),
		LightEmission = 1,
	})

	local shard = holder(folder, "ArmorHit_BlueShard")
	burst(shard, 12, {
		Name = "Shards",
		Texture = T.Spark,
		Color = K.ColorSeq(RGB(160, 230, 255), RGB(40, 120, 255)),
		Size = K.Seq(0.4, 0.1),
		Lifetime = NumberRange.new(0.3, 0.6),
		Speed = NumberRange.new(10, 18),
		SpreadAngle = Vector2.new(60, 60),
		Acceleration = Vector3.new(0, -60, 0),
		LightEmission = 0.8,
		RotSpeed = NumberRange.new(-360, 360),
		Rotation = NumberRange.new(0, 360),
	})

	local shatter = holder(folder, "ArmorBreak_Shatter")
	burst(shatter, 40, {
		Name = "Crystals",
		Texture = T.Spark,
		Color = K.ColorSeq(RGB(200, 245, 255), RGB(40, 140, 255)),
		Size = K.Seq(0.9, 0.2),
		Lifetime = NumberRange.new(0.6, 1.1),
		Speed = NumberRange.new(16, 30),
		SpreadAngle = Vector2.new(180, 180),
		Acceleration = Vector3.new(0, -70, 0),
		Drag = 1.5,
		LightEmission = 1,
		RotSpeed = NumberRange.new(-400, 400),
		Rotation = NumberRange.new(0, 360),
	})
	burst(shatter, 2, {
		Name = "BlueNova",
		Texture = T.ExplosionShockwave,
		Color = ColorSequence.new(RGB(90, 180, 255)),
		Size = K.Seq(1, 9),
		Transparency = K.Seq(0, 1),
		Lifetime = NumberRange.new(0.4),
		Speed = NumberRange.new(0),
		LightEmission = 1,
	})

	local block = holder(folder, "BlockSpark")
	burst(block, 20, {
		Name = "BlockSparks",
		Texture = T.Spark,
		Color = K.ColorSeq(RGB(255, 255, 255), RGB(255, 200, 80)),
		Size = K.Seq(0.3, 0),
		Lifetime = NumberRange.new(0.2, 0.35),
		Speed = NumberRange.new(20, 30),
		SpreadAngle = Vector2.new(40, 40),
		Drag = 4,
		LightEmission = 1,
		Orientation = Enum.ParticleOrientation.VelocityParallel,
	})

	local dust = holder(folder, "ImpactDust")
	burst(dust, 8, {
		Name = "Dust",
		Texture = T.Smoke,
		Color = ColorSequence.new(RGB(170, 160, 140)),
		Size = K.Seq(0.5, 2.2),
		Transparency = K.Seq(0.4, 1),
		Lifetime = NumberRange.new(0.5, 0.9),
		Speed = NumberRange.new(3, 6),
		SpreadAngle = Vector2.new(50, 50),
		Drag = 3,
	})

	local explosion = holder(folder, "FireExplosion")
	burst(explosion, 30, {
		Name = "Fireburst",
		Texture = T.Fire,
		Color = K.ColorSeq(RGB(255, 240, 160), RGB(255, 110, 20), RGB(80, 20, 10)),
		Size = K.Seq(2.5, 4, 0),
		Transparency = K.Seq(0, 0.3, 1),
		Lifetime = NumberRange.new(0.4, 0.8),
		Speed = NumberRange.new(12, 22),
		SpreadAngle = Vector2.new(180, 180),
		Drag = 4,
		LightEmission = 1,
	})
	burst(explosion, 12, {
		Name = "Smoke",
		Texture = T.ExplosionSmoke,
		Color = ColorSequence.new(RGB(50, 45, 40)),
		Size = K.Seq(3, 7),
		Transparency = K.Seq(0.3, 1),
		Lifetime = NumberRange.new(1, 1.6),
		Speed = NumberRange.new(4, 9),
		SpreadAngle = Vector2.new(180, 180),
		Acceleration = Vector3.new(0, 6, 0),
		Drag = 2,
	})

	local splash = holder(folder, "WaterSplash")
	burst(splash, 18, {
		Name = "Droplets",
		Texture = T.Spark,
		Color = ColorSequence.new(RGB(200, 230, 255)),
		Size = K.Seq(0.35, 0.1),
		Lifetime = NumberRange.new(0.4, 0.7),
		Speed = NumberRange.new(10, 16),
		SpreadAngle = Vector2.new(35, 35),
		Acceleration = Vector3.new(0, -80, 0),
	})
end

---------------------------------------------------------------------------------------------
function VFXTemplates.BuildStatusAndAreaEffects(folder: Folder)
	-- Smoke cloud: an invisible carrier part sized to the 16 stud radius with dense emitters
	replace(folder, "SmokeCloud_Emitter")
	local smoke = K.Part(folder, "SmokeCloud_Emitter", Vector3.new(32, 14, 32), CFrame.new(0, -1000, 0), Color3.new(1, 1, 1), M.SmoothPlastic, {
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		CastShadow = false,
	})
	smoke:SetAttribute("Radius", 16)
	smoke:SetAttribute("Duration", 8)
	K.Emitter(smoke, {
		Name = "DenseSmoke",
		Texture = T.Smoke,
		Color = K.ColorSeq(RGB(110, 110, 112), RGB(80, 80, 84)),
		Size = K.Seq(9, 14),
		Transparency = K.Seq(0.05, 0.15, 1),
		Lifetime = NumberRange.new(3, 4.5),
		Rate = 26,
		Speed = NumberRange.new(0.5, 2),
		SpreadAngle = Vector2.new(180, 180),
		RotSpeed = NumberRange.new(-20, 20),
		Rotation = NumberRange.new(0, 360),
		Shape = Enum.ParticleEmitterShape.Box,
		ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
		LightInfluence = 1,
	})
	burst(smoke, 30, {
		Name = "PopPuff",
		Texture = T.Smoke,
		Color = ColorSequence.new(RGB(150, 150, 152)),
		Size = K.Seq(4, 12),
		Transparency = K.Seq(0, 1),
		Lifetime = NumberRange.new(1.2, 2),
		Speed = NumberRange.new(10, 18),
		SpreadAngle = Vector2.new(180, 180),
		Drag = 3,
	})

	local heal = holder(folder, "HealAura_GreenRing")
	K.Emitter(heal, {
		Name = "RisingCrosses",
		Texture = T.Spark,
		Color = K.ColorSeq(RGB(160, 255, 160), RGB(40, 210, 80)),
		Size = K.Seq(0.5, 0.2),
		Transparency = K.Seq(0.1, 1),
		Lifetime = NumberRange.new(0.8, 1.2),
		Rate = 18,
		Speed = NumberRange.new(3, 5),
		SpreadAngle = Vector2.new(15, 15),
		LightEmission = 1,
		Shape = Enum.ParticleEmitterShape.Disc,
		ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface,
	})
	burst(heal, 2, {
		Name = "GroundPulse",
		Texture = T.ExplosionShockwave,
		Color = ColorSequence.new(RGB(80, 255, 120)),
		Size = K.Seq(1, 7),
		Transparency = K.Seq(0.1, 1),
		Lifetime = NumberRange.new(0.6),
		Speed = NumberRange.new(0),
		LightEmission = 1,
		Orientation = Enum.ParticleOrientation.VelocityPerpendicular,
		EmissionDirection = Enum.NormalId.Top,
	})

	replace(folder, "WarHorn_Pulse")
	local pulse = K.Ball(folder, "WarHorn_Pulse", 2, CFrame.new(0, -1000, 0), RGB(255, 205, 70), M.ForceField, {
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		CastShadow = false,
	})
	pulse.Transparency = 0.2
	pulse:SetAttribute("MaxDiameter", 120)
	replace(folder, "WarHorn_RevealHighlight")
	local hl = Instance.new("Highlight")
	hl.Name = "WarHorn_RevealHighlight"
	hl.FillColor = RGB(255, 40, 40)
	hl.FillTransparency = 0.55
	hl.OutlineColor = RGB(255, 90, 90)
	hl.OutlineTransparency = 0
	hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	hl.Parent = folder

	replace(folder, "Stagger_Stars")
	local stars = Instance.new("BillboardGui")
	stars.Name = "Stagger_Stars"
	stars.Size = UDim2.fromScale(3, 1)
	stars.StudsOffset = Vector3.new(0, 2.2, 0)
	stars.AlwaysOnTop = true
	stars.LightInfluence = 0
	local spin = Instance.new("Frame")
	spin.Name = "Spin"
	spin.BackgroundTransparency = 1
	spin.Size = UDim2.fromScale(1, 1)
	spin.Parent = stars
	for i = 0, 2 do
		local star = Instance.new("TextLabel")
		star.Name = "Star" .. (i + 1)
		star.BackgroundTransparency = 1
		star.Size = UDim2.fromScale(0.3, 0.9)
		star.Position = UDim2.fromScale(0.05 + i * 0.32, 0.05)
		star.Text = "★"
		star.TextScaled = true
		star.TextColor3 = RGB(255, 230, 80)
		star.TextStrokeTransparency = 0.2
		star.Font = Enum.Font.GothamBlack
		star.Parent = spin
	end
	stars.Parent = folder

	local burn = holder(folder, "Burning")
	K.Emitter(burn, {
		Name = "BodyFlames",
		Texture = T.Fire,
		Color = K.ColorSeq(RGB(255, 220, 120), RGB(255, 100, 20)),
		Size = K.Seq(1.2, 0.2),
		Transparency = K.Seq(0.2, 1),
		Lifetime = NumberRange.new(0.3, 0.6),
		Rate = 40,
		Speed = NumberRange.new(2, 4),
		SpreadAngle = Vector2.new(40, 40),
		LightEmission = 1,
	})

	local snare = holder(folder, "Snared")
	K.Emitter(snare, {
		Name = "RopeBits",
		Texture = T.Spark,
		Color = ColorSequence.new(RGB(178, 150, 104)),
		Size = K.Seq(0.3, 0.1),
		Lifetime = NumberRange.new(0.4, 0.6),
		Rate = 12,
		Speed = NumberRange.new(1, 2),
		SpreadAngle = Vector2.new(180, 0),
	})

	replace(folder, "FirePatch")
	local patch = K.CylinderY(folder, "FirePatch", 0.2, 20, Vector3.new(0, -1000, 0), RGB(255, 90, 20), M.Neon, {
		Transparency = 0.7,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		CastShadow = false,
	})
	K.Emitter(patch, {
		Name = "GroundFire",
		Texture = T.Fire,
		Color = K.ColorSeq(RGB(255, 220, 120), RGB(255, 90, 20), RGB(100, 20, 10)),
		Size = K.Seq(2, 3.5, 0),
		Transparency = K.Seq(0.2, 0.4, 1),
		Lifetime = NumberRange.new(0.6, 1.1),
		Rate = 70,
		Speed = NumberRange.new(2, 5),
		LightEmission = 1,
		Shape = Enum.ParticleEmitterShape.Cylinder,
		ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
		EmissionDirection = Enum.NormalId.Right,
	})
	K.PointLight(patch, RGB(255, 120, 40), 4, 18)
end

function VFXTemplates.BuildKillConfirmation(folder: Folder)
	local skull = holder(folder, "SkullBurst")
	burst(skull, 36, {
		Name = "GoldStars",
		Texture = T.Spark,
		Color = K.ColorSeq(RGB(255, 245, 170), RGB(255, 190, 40)),
		Size = K.Seq(0.8, 0),
		Lifetime = NumberRange.new(0.6, 1.1),
		Speed = NumberRange.new(14, 26),
		SpreadAngle = Vector2.new(35, 35),
		Acceleration = Vector3.new(0, -20, 0),
		Drag = 2,
		LightEmission = 1,
		EmissionDirection = Enum.NormalId.Top,
	})
	burst(skull, 2, {
		Name = "GoldNova",
		Texture = T.ExplosionShockwave,
		Color = ColorSequence.new(RGB(255, 210, 70)),
		Size = K.Seq(1, 8),
		Transparency = K.Seq(0, 1),
		Lifetime = NumberRange.new(0.5),
		Speed = NumberRange.new(0),
		LightEmission = 1,
	})
	replace(folder, "SkullBillboard")
	local bb = Instance.new("BillboardGui")
	bb.Name = "SkullBillboard"
	bb.Size = UDim2.fromScale(3, 3)
	bb.StudsOffset = Vector3.new(0, 3, 0)
	bb.AlwaysOnTop = true
	bb.LightInfluence = 0
	local label = Instance.new("TextLabel")
	label.Name = "Skull"
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Text = "☠"
	label.TextScaled = true
	label.TextColor3 = RGB(255, 215, 80)
	label.TextStrokeColor3 = RGB(120, 60, 0)
	label.TextStrokeTransparency = 0
	label.Font = Enum.Font.GothamBlack
	label.Parent = bb
	bb.Parent = folder
end

function VFXTemplates.BuildAll(vfxRoot: Folder, sub: { [string]: Folder })
	VFXTemplates.BuildProjectileTrails(sub.ProjectileTrails)
	local bodies = K.Folder(vfxRoot, "ProjectileBodies")
	VFXTemplates.BuildProjectileBodies(bodies)
	VFXTemplates.BuildImpactEffects(sub.ImpactEffects)
	VFXTemplates.BuildStatusAndAreaEffects(sub.StatusAndAreaEffects)
	VFXTemplates.BuildKillConfirmation(sub.KillConfirmationVFX)
end

return VFXTemplates
