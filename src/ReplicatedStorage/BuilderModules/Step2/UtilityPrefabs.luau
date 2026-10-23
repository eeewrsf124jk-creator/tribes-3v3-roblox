--!strict
-- Step 2c: tactical utility and healing consumable prefabs. Same contract as weapons (Handle
-- root, AttachPart/GripC0 attributes). Deployables (Palisade, SnapTrap) are cloned full-size by
-- the server when placed; while held they are shown scaled by the HeldScale attribute.

local GeometryKit = require(script.Parent.Parent.Kit.GeometryKit)

local K = GeometryKit
local RGB = Color3.fromRGB
local M = Enum.Material

local GRIP = CFrame.new(0, -0.3, -0.1)

local UtilityPrefabs = {}

local function begin(modelName: string, itemId: string, size: Vector3, color: Color3, material: Enum.Material): (Model, Part)
	local model = K.Model(nil, modelName)
	local handle = K.Part(model, "Handle", size, CFrame.identity, color, material)
	model:SetAttribute("ItemId", itemId)
	model:SetAttribute("AttachPart", "RightHand")
	model:SetAttribute("GripC0", GRIP)
	return model, handle
end

function UtilityPrefabs.SmokeBomb(): Model
	local model, handle = begin("SmokeBomb_Model", "SmokeBomb", Vector3.one * 0.95, RGB(140, 138, 132), M.Slate)
	handle.Shape = Enum.PartType.Ball
	-- rope bindings wrapped around the ceramic shell
	for i, tilt in { 0, 60, 120 } do
		K.Arc(model, "RopeWrap" .. i, CFrame.Angles(0, math.rad(tilt), 0), 0.49, 0, 360, 12, 0.07, 0.07, RGB(170, 140, 95), M.Fabric)
	end
	K.Cylinder(model, "Neck", 0.18, 0.32, CFrame.new(0, 0.5, 0) * CFrame.Angles(0, 0, math.rad(90)), RGB(110, 108, 104), M.Slate)
	local fuse = K.Cylinder(model, "Fuse", 0.4, 0.06, CFrame.new(0, 0.78, 0) * CFrame.Angles(0, 0, math.rad(90)), RGB(60, 50, 40), M.Fabric)
	local spark = K.Attachment(fuse, "FuseSpark", CFrame.new(0.2, 0, 0))
	K.Emitter(spark, {
		Name = "FuseSparks",
		Texture = K.Textures.Spark,
		Color = K.ColorSeq(RGB(255, 230, 120), RGB(255, 120, 30)),
		Size = K.Seq(0.25, 0),
		Lifetime = NumberRange.new(0.15, 0.35),
		Rate = 40,
		Speed = NumberRange.new(2, 5),
		SpreadAngle = Vector2.new(60, 60),
		LightEmission = 1,
	})
	K.PointLight(fuse, RGB(255, 170, 60), 1.5, 5)
	K.Attachment(handle, "MuzzleAttachment", CFrame.new(0, 0, -0.5))
	K.WeldAll(model, handle)
	return model
end

function UtilityPrefabs.SnapTrap(): Model
	local model, handle = begin("SnapTrap_Model", "SnapTrap", Vector3.new(2.6, 0.14, 2.6), RGB(80, 82, 88), M.DiamondPlate)
	model:SetAttribute("HeldScale", 0.45)
	K.Cylinder(model, "PressurePlate", 0.08, 0.9, CFrame.new(0, 0.1, 0) * CFrame.Angles(0, 0, math.rad(90)), RGB(150, 120, 70), M.Metal)
	K.Part(model, "Spring", Vector3.new(0.2, 0.2, 2.4), CFrame.new(0, 0.12, 0), RGB(120, 122, 128), M.Metal)
	K.Part(model, "Chain", Vector3.new(0.12, 0.08, 1.2), CFrame.new(1.6, 0.05, 0), RGB(70, 70, 74), M.Metal)
	-- two hinged jaws: each a half-ring of toothed segments on its own Motor6D (open = flat)
	for _, side in { "Left", "Right" } do
		local sign = if side == "Left" then -1 else 1
		local hingePos = Vector3.new(0, 0.1, 0)
		local jaw = K.Part(model, "Jaw" .. side, Vector3.new(0.12, 0.12, 2.4), CFrame.new(sign * 1.15, 0.12, 0), RGB(150, 152, 158), M.Metal)
		for t = 0, 6 do
			local z = -1.05 + t * 0.35
			local tooth = K.Wedge(model, string.format("Tooth%s%d", side, t + 1), Vector3.new(0.1, 0.36, 0.22), CFrame.new(sign * 1.05, 0.3, z) * CFrame.Angles(0, if sign < 0 then math.pi / 2 else -math.pi / 2, 0), RGB(200, 202, 208), M.Metal)
			K.Weld(jaw, tooth)
		end
		local motor = K.Motor(handle, jaw, "JawMotor" .. side, CFrame.new(hingePos))
		motor:SetAttribute("CloseAngle", sign * 90)
	end
	K.WeldAll(model, handle)
	return model
end

function UtilityPrefabs.Palisade(): Model
	-- 8 wide x 6.5 tall x 1.5 deep; Handle is the ground anchor at the base centre.
	local model, handle = begin("Palisade_Model", "Palisade", Vector3.new(8, 0.4, 1.5), RGB(90, 64, 40), M.Wood)
	model:SetAttribute("HeldScale", 0.12)
	handle.CFrame = CFrame.new(0, 0.2, 0)
	local logColor = RGB(118, 82, 50)
	for i = 0, 4 do
		local x = -3.2 + i * 1.6
		local h = 5.4 + ((i % 2) * 0.35)
		K.CylinderY(model, "Log" .. (i + 1), h, 1.45, Vector3.new(x, h / 2, 0), logColor, M.Wood)
		K.Tip(model, "Stake" .. (i + 1), CFrame.new(x, h, 0), 1.2, 6.5 - h + 0.1, RGB(150, 112, 74), M.Wood)
	end
	for _, y in { 1.4, 4.1 } do
		K.Part(model, "CrossBeam", Vector3.new(8.2, 0.45, 0.4), CFrame.new(0, y, -0.85), RGB(80, 56, 34), M.WoodPlanks)
		for i = 0, 4 do
			K.Cylinder(model, "Lashing", 0.3, 0.55, CFrame.new(-3.2 + i * 1.6, y, -0.82), RGB(170, 140, 95), M.Fabric)
		end
	end
	local collider = K.Part(model, "WallCollider", Vector3.new(8, 6.5, 1.5), CFrame.new(0, 3.25, 0), Color3.new(1, 1, 1), M.SmoothPlastic)
	collider.Transparency = 1
	collider:SetAttribute("ShieldCollider", true)
	K.WeldAll(model, handle)
	collider.CanCollide = true
	collider.CanQuery = true
	return model
end

function UtilityPrefabs.WarHorn(): Model
	local model, handle = begin("WarHorn_Model", "WarHorn", Vector3.new(0.28, 0.6, 0.28), RGB(80, 52, 32), M.Leather)
	-- curved horn: tapering bone-coloured segments along a quarter arc, widening toward the bell
	local bone = RGB(232, 220, 190)
	local prev = Vector3.new(0, 0.3, 0.2)
	local segs = 7
	for i = 1, segs do
		local t = i / segs
		local a = t * math.rad(110)
		local p = Vector3.new(0, 0.3 + math.sin(a) * 1.3, 0.2 - (1 - math.cos(a)) * 1.3 - t * 0.6)
		K.Rod(model, "HornSeg" .. i, prev, p, 0.18 + t * 0.5, bone, M.Marble)
		prev = p
	end
	K.Rod(model, "Mouthpiece", Vector3.new(0, 0.3, 0.2), Vector3.new(0, 0.2, 0.45), 0.16, RGB(236, 192, 72), M.Foil)
	K.Arc(model, "BellRim", CFrame.lookAt(prev, prev + Vector3.new(0, 0.6, -0.8)), 0.36, 0, 360, 12, 0.08, 0.12, RGB(236, 192, 72), M.Foil)
	local strapA = K.Attachment(handle, "StrapA", CFrame.new(0, 0.3, 0.2))
	local bell = model:FindFirstChild("HornSeg" .. segs) :: BasePart
	local strapB = K.Attachment(bell, "StrapB", CFrame.identity)
	K.BeamBetween(handle, strapA, strapB, RGB(90, 56, 34), 0.1, { Segments = 10, CurveSize0 = 0.8, CurveSize1 = 0.8 }).Name = "LeatherStrap"
	K.Attachment(handle, "MuzzleAttachment", CFrame.new(prev))
	K.WeldAll(model, handle)
	return model
end

function UtilityPrefabs.Fireball(): Model
	local model, handle = begin("Fireball_Model", "Fireball", Vector3.one * 0.9, RGB(255, 140, 30), M.Neon)
	handle.Shape = Enum.PartType.Ball
	local shell = K.Ball(model, "Shell", 1.4, CFrame.identity, RGB(255, 80, 20), M.Neon)
	shell.Transparency = 0.6
	shell.CastShadow = false
	local a = K.Attachment(handle, "FlameCore", CFrame.identity)
	K.Emitter(a, {
		Name = "FlameSwirl",
		Texture = K.Textures.Fire,
		Color = K.ColorSeq(RGB(255, 220, 120), RGB(255, 110, 20), RGB(120, 30, 10)),
		Size = K.Seq(0.9, 1.4, 0),
		Transparency = K.Seq(0.1, 0.4, 1),
		Lifetime = NumberRange.new(0.4, 0.7),
		Rate = 60,
		Speed = NumberRange.new(0.5, 1.5),
		RotSpeed = NumberRange.new(-180, 180),
		Rotation = NumberRange.new(0, 360),
		SpreadAngle = Vector2.new(180, 180),
		LightEmission = 1,
		Acceleration = Vector3.new(0, 4, 0),
	})
	K.Emitter(a, {
		Name = "Embers",
		Texture = K.Textures.FireSparks,
		Color = K.ColorSeq(RGB(255, 200, 80), RGB(255, 80, 20)),
		Size = K.Seq(0.2, 0),
		Lifetime = NumberRange.new(0.5, 1),
		Rate = 25,
		Speed = NumberRange.new(2, 4),
		SpreadAngle = Vector2.new(180, 180),
		LightEmission = 1,
	})
	K.PointLight(handle, RGB(255, 140, 40), 3, 12, true)
	K.Attachment(handle, "MuzzleAttachment", CFrame.new(0, 0, -0.6))
	model:SetAttribute("GripC0", CFrame.new(0, -0.9, -0.3))
	K.WeldAll(model, handle)
	return model
end

function UtilityPrefabs.Bandage(): Model
	local model, handle = begin("Bandage_Model", "Bandage", Vector3.new(0.7, 0.55, 0.55), RGB(245, 242, 235), M.Fabric)
	handle.Shape = Enum.PartType.Cylinder
	K.Cylinder(model, "Core", 0.72, 0.2, CFrame.identity, RGB(220, 210, 190), M.Cardboard)
	K.Part(model, "LooseTail", Vector3.new(0.55, 0.02, 0.7), CFrame.new(0, -0.26, -0.3) * CFrame.Angles(math.rad(-20), 0, 0), RGB(245, 242, 235), M.Fabric)
	K.Part(model, "RedCross1", Vector3.new(0.02, 0.12, 0.3), CFrame.new(0.36, 0, 0), RGB(200, 40, 40), M.SmoothPlastic)
	K.Part(model, "RedCross2", Vector3.new(0.02, 0.3, 0.12), CFrame.new(0.36, 0, 0), RGB(200, 40, 40), M.SmoothPlastic)
	K.WeldAll(model, handle)
	return model
end

local function apple(modelName: string, itemId: string, golden: boolean): Model
	local skin = if golden then RGB(255, 205, 60) else RGB(196, 30, 36)
	local mat = if golden then M.Foil else M.SmoothPlastic
	local model, handle = begin(modelName, itemId, Vector3.one * 0.8, skin, mat)
	handle.Shape = Enum.PartType.Ball
	handle.Reflectance = if golden then 0.35 else 0.08
	K.Mesh(handle, Enum.MeshType.Sphere, Vector3.new(1, 0.9, 1))
	K.Cylinder(model, "Stem", 0.25, 0.07, CFrame.new(0, 0.45, 0) * CFrame.Angles(0, 0, math.rad(80)), RGB(90, 60, 30), M.Wood)
	local leaf = K.Wedge(model, "Leaf", Vector3.new(0.04, 0.12, 0.3), CFrame.new(0.1, 0.5, -0.1) * CFrame.Angles(math.rad(30), math.rad(40), 0), if golden then RGB(255, 230, 120) else RGB(70, 150, 50), if golden then M.Neon else M.Grass)
	leaf.CastShadow = false
	if golden then
		local core = K.Ball(model, "GlowCore", 0.55, CFrame.identity, RGB(255, 240, 160), M.Neon)
		core.Transparency = 0.5
		local a = K.Attachment(handle, "Sparkle", CFrame.identity)
		K.Emitter(a, {
			Name = "GoldenSparkle",
			Texture = K.Textures.Spark,
			Color = K.ColorSeq(RGB(255, 245, 180), RGB(255, 200, 60)),
			Size = K.Seq(0.25, 0),
			Lifetime = NumberRange.new(0.5, 1.0),
			Rate = 14,
			Speed = NumberRange.new(0.5, 1.5),
			SpreadAngle = Vector2.new(180, 180),
			LightEmission = 1,
		})
		K.PointLight(handle, RGB(255, 210, 90), 1.6, 7)
	end
	K.WeldAll(model, handle)
	return model
end

function UtilityPrefabs.Apple(): Model
	return apple("Apple_Model", "Apple", false)
end

function UtilityPrefabs.GoldenApple(): Model
	return apple("GoldenApple_Model", "GoldenApple", true)
end

function UtilityPrefabs.HealingFlask(): Model
	local model, handle = begin("HealingFlask_Model", "HealingFlask", Vector3.one * 0.95, RGB(220, 240, 255), M.Glass)
	handle.Shape = Enum.PartType.Ball
	handle.Transparency = 0.55
	local liquid = K.Ball(model, "Potion", 0.78, CFrame.new(0, -0.06, 0), RGB(230, 30, 60), M.Neon)
	liquid.Transparency = 0.15
	K.Cylinder(model, "Neck", 0.5, 0.3, CFrame.new(0, 0.62, 0) * CFrame.Angles(0, 0, math.rad(90)), RGB(220, 240, 255), M.Glass).Transparency = 0.5
	K.Cylinder(model, "Cork", 0.22, 0.26, CFrame.new(0, 0.96, 0) * CFrame.Angles(0, 0, math.rad(90)), RGB(150, 110, 70), M.Wood)
	K.Arc(model, "LabelBand", CFrame.Angles(math.rad(90), 0, 0) * CFrame.new(0, 0, 0.05), 0.47, 0, 360, 12, 0.03, 0.16, RGB(236, 192, 72), M.Foil)
	K.PointLight(liquid, RGB(255, 60, 90), 0.8, 4)
	K.Attachment(handle, "MuzzleAttachment", CFrame.new(0, 0, -0.5))
	K.WeldAll(model, handle)
	return model
end

local Builders: { [string]: () -> Model } = {
	SmokeBomb = UtilityPrefabs.SmokeBomb,
	SnapTrap = UtilityPrefabs.SnapTrap,
	Palisade = UtilityPrefabs.Palisade,
	WarHorn = UtilityPrefabs.WarHorn,
	Fireball = UtilityPrefabs.Fireball,
	Bandage = UtilityPrefabs.Bandage,
	Apple = UtilityPrefabs.Apple,
	GoldenApple = UtilityPrefabs.GoldenApple,
	HealingFlask = UtilityPrefabs.HealingFlask,
}
UtilityPrefabs.Builders = Builders

UtilityPrefabs.Order = { "SmokeBomb", "SnapTrap", "Fireball", "Palisade", "WarHorn", "Bandage", "Apple", "GoldenApple", "HealingFlask" }

function UtilityPrefabs.BuildAll(folder: Folder)
	for _, id in UtilityPrefabs.Order do
		local model = Builders[id]()
		local old = folder:FindFirstChild(model.Name)
		if old then
			old:Destroy()
		end
		model.Parent = folder
	end
end

return UtilityPrefabs
