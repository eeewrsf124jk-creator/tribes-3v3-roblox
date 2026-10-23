--!strict
-- Step 2a: procedural ranged and melee weapon prefabs.
--
-- Prefab contract (read by the equip code in Modules/Shared/EquipmentRig):
--   * Model.PrimaryPart = "Handle"; the hand grip sits at the Handle origin.
--   * Ranged weapons fire along Handle -Z and include MuzzleAttachment + StringAttachment.
--   * Melee blades run along Handle +Y and include 5-8 "DmgPoint" attachments plus
--     TopAttachment/BottomAttachment driving a disabled "SwingTrail".
--   * Attributes: ItemId, AttachPart (body part the Handle is gripped to), GripC0 (CFrame).
--   * An optional child Model "Offhand" (PrimaryPart "OffhandHandle") is gripped to the left hand.

local GeometryKit = require(script.Parent.Parent.Kit.GeometryKit)

local K = GeometryKit
local RGB = Color3.fromRGB
local M = Enum.Material

local C = {
	Wood = RGB(124, 82, 48),
	LightWood = RGB(160, 115, 72),
	DarkOak = RGB(74, 50, 31),
	Leather = RGB(96, 60, 38),
	BlackLeather = RGB(34, 30, 28),
	Steel = RGB(176, 181, 188),
	DarkSteel = RGB(92, 96, 104),
	Iron = RGB(120, 122, 128),
	Brass = RGB(201, 160, 72),
	Gold = RGB(236, 192, 72),
	Ebony = RGB(28, 22, 20),
	String = RGB(242, 240, 230),
	Diamond = RGB(70, 230, 225),
	DiamondCore = RGB(150, 255, 250),
	Red = RGB(186, 36, 40),
	Rope = RGB(178, 150, 104),
	Stone = RGB(128, 124, 118),
	Silver = RGB(214, 218, 224),
}

local GRIP_RIGHT = CFrame.new(0, -0.25, 0) * CFrame.Angles(-math.pi / 2, 0, 0)

local WeaponPrefabs = {}

local function begin(modelName: string, itemId: string, handleSize: Vector3, color: Color3, material: Enum.Material): (Model, Part)
	local model = K.Model(nil, modelName)
	local handle = K.Part(model, "Handle", handleSize, CFrame.identity, color, material)
	model:SetAttribute("ItemId", itemId)
	model:SetAttribute("AttachPart", "RightHand")
	model:SetAttribute("GripC0", GRIP_RIGHT)
	return model, handle
end

local function finish(model: Model, handle: BasePart)
	K.WeldAll(model, handle)
end

local function dmgPoints(handle: BasePart, fromY: number, toY: number, count: number, z: number?)
	for i = 1, count do
		local y = fromY + (toY - fromY) * ((i - 1) / (count - 1))
		local a = K.Attachment(handle, "DmgPoint", CFrame.new(0, y, z or 0))
		a:SetAttribute("Index", i)
	end
	local top = K.Attachment(handle, "TopAttachment", CFrame.new(0, toY, z or 0))
	local bottom = K.Attachment(handle, "BottomAttachment", CFrame.new(0, fromY, z or 0))
	K.Trail(
		handle,
		top,
		bottom,
		K.ColorSeq(Color3.new(1, 1, 1), RGB(190, 220, 255)),
		0.18,
		K.Seq(0.25, 1)
	).Name = "SwingTrail"
end

-- Bow string: two Beams meeting at the movable StringAttachment so drawing pulls a V shape.
local function bowString(handle: BasePart, topPos: Vector3, bottomPos: Vector3, restZ: number, width: number)
	local topA = K.Attachment(handle, "StringTop", CFrame.new(topPos))
	local bottomA = K.Attachment(handle, "StringBottom", CFrame.new(bottomPos))
	local stringA = K.Attachment(handle, "StringAttachment", CFrame.new(0, (topPos.Y + bottomPos.Y) / 2, restZ))
	stringA:SetAttribute("RestZ", restZ)
	K.BeamBetween(handle, topA, stringA, C.String, width, { FaceCamera = true, Segments = 1 }).Name = "StringBeamTop"
	K.BeamBetween(handle, stringA, bottomA, C.String, width, { FaceCamera = true, Segments = 1 }).Name = "StringBeamBottom"
end

-- Curved limb made of straight segments sampled from z = depth * s^2 for s in [0, 1].
local function limb(parent: Model, name: string, sign: number, length: number, depth: number, seg: number, w: number, d: number, color: Color3, startS: number)
	for i = 0, seg - 1 do
		local s0 = startS + (1 - startS) * (i / seg)
		local s1 = startS + (1 - startS) * ((i + 1) / seg)
		local a = Vector3.new(0, sign * length * s0, depth * s0 * s0)
		local b = Vector3.new(0, sign * length * s1, depth * s1 * s1)
		local taper = 1 - 0.35 * s1
		K.Beam3(parent, string.format("%s_%d", name, i + 1), a, b, w * taper, d * taper, color, M.Wood)
	end
end

---------------------------------------------------------------------------------------------
-- RANGED
---------------------------------------------------------------------------------------------

function WeaponPrefabs.WoodBow(): Model
	local model, handle = begin("WoodBow_Model", "WoodBow", Vector3.new(0.32, 0.85, 0.36), C.Leather, M.Fabric)
	-- 5 angled parts: riser + two segments per limb (sampled from the bow curve)
	K.Beam3(model, "Riser", Vector3.new(0, -0.45, 0), Vector3.new(0, 0.45, 0), 0.26, 0.3, C.Wood, M.Wood)
	limb(model, "UpperLimb", 1, 2.1, 0.6, 2, 0.24, 0.3, C.Wood, 0.2)
	limb(model, "LowerLimb", -1, 2.1, 0.6, 2, 0.24, 0.3, C.Wood, 0.2)
	K.Part(model, "ArrowRest", Vector3.new(0.12, 0.08, 0.22), CFrame.new(-0.18, 0.3, -0.02), C.Leather, M.Fabric)
	K.Ball(model, "TipTop", 0.16, CFrame.new(0, 2.1, 0.6), C.DarkOak, M.Wood)
	K.Ball(model, "TipBottom", 0.16, CFrame.new(0, -2.1, 0.6), C.DarkOak, M.Wood)
	bowString(handle, Vector3.new(0, 2.08, 0.6), Vector3.new(0, -2.08, 0.6), 0.6, 0.05)
	K.Attachment(handle, "MuzzleAttachment", CFrame.new(-0.18, 0.36, -0.15))
	-- nocked arrow shown while drawing
	local nock = K.Rod(model, "NockedArrow", Vector3.new(-0.18, 0.36, 0.6), Vector3.new(-0.18, 0.36, -2.4), 0.08, C.LightWood, M.Wood)
	nock.Transparency = 1
	finish(model, handle)
	model:SetAttribute("DrawDistance", 1.7)
	return model
end

function WeaponPrefabs.Crossbow(): Model
	local model, handle = begin("Crossbow_Model", "Crossbow", Vector3.new(0.3, 0.75, 0.42), C.DarkOak, M.Wood)
	handle.CFrame = CFrame.Angles(math.rad(-12), 0, 0)
	K.Part(model, "Stock", Vector3.new(0.36, 0.42, 3.4), CFrame.new(0, 0.42, -0.5), C.DarkOak, M.Wood)
	K.Part(model, "Butt", Vector3.new(0.4, 0.7, 0.9), CFrame.new(0, 0.3, 1.45), C.DarkOak, M.Wood)
	K.Part(model, "BoltRail", Vector3.new(0.12, 0.06, 2.4), CFrame.new(0, 0.66, -0.9), C.DarkSteel, M.Metal)
	K.Part(model, "TriggerHousing", Vector3.new(0.22, 0.2, 0.5), CFrame.new(0, 0.12, -0.25), C.DarkSteel, M.Metal)
	K.Part(model, "TriggerLever", Vector3.new(0.08, 0.45, 0.1), CFrame.new(0, -0.1, -0.15) * CFrame.Angles(math.rad(15), 0, 0), C.Steel, M.Metal)
	K.Part(model, "Stirrup", Vector3.new(0.7, 0.08, 0.08), CFrame.new(0, 0.42, -2.3), C.Steel, M.Metal)
	-- steel prod (bow arms)
	K.Beam3(model, "ProdLeft", Vector3.new(0, 0.55, -2.05), Vector3.new(-1.45, 0.55, -1.6), 0.14, 0.2, C.Steel, M.Metal)
	K.Beam3(model, "ProdRight", Vector3.new(0, 0.55, -2.05), Vector3.new(1.45, 0.55, -1.6), 0.14, 0.2, C.Steel, M.Metal)
	K.Part(model, "ProdMount", Vector3.new(0.5, 0.32, 0.36), CFrame.new(0, 0.55, -2.0), C.DarkSteel, M.Metal)
	local topA = K.Attachment(handle, "StringTop", CFrame.new(-1.42, 0.62, -1.6))
	local bottomA = K.Attachment(handle, "StringBottom", CFrame.new(1.42, 0.62, -1.6))
	local stringA = K.Attachment(handle, "StringAttachment", CFrame.new(0, 0.66, -0.55))
	stringA:SetAttribute("RestZ", -0.55)
	K.BeamBetween(handle, topA, stringA, C.String, 0.05, { Segments = 1 }).Name = "StringBeamTop"
	K.BeamBetween(handle, stringA, bottomA, C.String, 0.05, { Segments = 1 }).Name = "StringBeamBottom"
	K.Rod(model, "LoadedBolt", Vector3.new(0, 0.72, -0.6), Vector3.new(0, 0.72, -2.2), 0.08, C.DarkOak, M.Wood)
	K.Attachment(handle, "MuzzleAttachment", CFrame.new(0, 0.72, -2.3))
	finish(model, handle)
	return model
end

function WeaponPrefabs.Headhunter(): Model
	local model, handle = begin("Headhunter_Model", "Headhunter", Vector3.new(0.34, 0.9, 0.4), C.BlackLeather, M.Fabric)
	K.Beam3(model, "Riser", Vector3.new(0, -0.6, -0.05), Vector3.new(0, 0.6, -0.05), 0.3, 0.42, C.Ebony, M.Wood)
	K.Part(model, "RiserGoldInlayTop", Vector3.new(0.32, 0.1, 0.44), CFrame.new(0, 0.62, -0.05), C.Gold, M.Foil)
	K.Part(model, "RiserGoldInlayBottom", Vector3.new(0.32, 0.1, 0.44), CFrame.new(0, -0.62, -0.05), C.Gold, M.Foil)
	limb(model, "UpperLimb", 1, 2.6, 0.75, 3, 0.26, 0.34, C.Ebony, 0.24)
	limb(model, "LowerLimb", -1, 2.6, 0.75, 3, 0.26, 0.34, C.Ebony, 0.24)
	-- compound cams at the tips
	K.Cylinder(model, "CamTop", 0.12, 0.42, CFrame.new(0, 2.6, 0.75), C.Gold, M.Foil)
	K.Cylinder(model, "CamBottom", 0.12, 0.42, CFrame.new(0, -2.6, 0.75), C.Gold, M.Foil)
	-- sight pin bracket + glowing pin
	K.Part(model, "SightBracket", Vector3.new(0.06, 0.08, 0.5), CFrame.new(-0.2, 0.55, -0.3), C.Gold, M.Foil)
	K.Part(model, "SightRing", Vector3.new(0.05, 0.32, 0.32), CFrame.new(-0.24, 0.55, -0.55), C.Gold, M.Foil)
	local pin = K.Ball(model, "SightPin", 0.08, CFrame.new(-0.24, 0.55, -0.55), RGB(255, 80, 60), M.Neon)
	pin.CastShadow = false
	K.Part(model, "ArrowRest", Vector3.new(0.12, 0.08, 0.24), CFrame.new(-0.2, 0.35, -0.05), C.Gold, M.Foil)
	bowString(handle, Vector3.new(0, 2.6, 0.75), Vector3.new(0, -2.6, 0.75), 0.75, 0.06)
	K.Attachment(handle, "MuzzleAttachment", CFrame.new(-0.2, 0.42, -0.2))
	local nock = K.Rod(model, "NockedArrow", Vector3.new(-0.2, 0.42, 0.75), Vector3.new(-0.2, 0.42, -2.6), 0.09, C.Ebony, M.Wood)
	nock.Transparency = 1
	finish(model, handle)
	model:SetAttribute("DrawDistance", 2.0)
	return model
end

-- Octagonal barrel: two square boxes rotated 45 degrees about the barrel axis, CSG-unioned.
local function octagonalBarrel(model: Model, name: string, length: number, width: number, cf: CFrame, color: Color3): Instance
	local a = K.Part(nil, name .. "_A", Vector3.new(width, width, length), cf, color, M.Metal)
	local b = K.Part(nil, name .. "_B", Vector3.new(width, width, length), cf * CFrame.Angles(0, 0, math.rad(45)), color, M.Metal)
	return K.Union({ a, b }, name, model)
end

function WeaponPrefabs.Flintlock(): Model
	local model, handle = begin("Flintlock_Model", "Flintlock", Vector3.new(0.28, 0.8, 0.42), C.Wood, M.Wood)
	handle.CFrame = CFrame.Angles(math.rad(22), 0, 0)
	K.Part(model, "GripCurve", Vector3.new(0.3, 0.5, 0.5), CFrame.new(0, 0.45, 0.12) * CFrame.Angles(math.rad(40), 0, 0), C.Wood, M.Wood)
	K.Ball(model, "ButtCap", 0.42, CFrame.new(0, -0.42, 0.2), C.Brass, M.Foil)
	K.Part(model, "Frame", Vector3.new(0.3, 0.3, 1.1), CFrame.new(0, 0.62, -0.35), C.Wood, M.Wood)
	octagonalBarrel(model, "Barrel", 1.7, 0.2, CFrame.new(0, 0.76, -1.3), C.DarkSteel)
	K.Cylinder(model, "MuzzleBand", 0.1, 0.3, CFrame.new(0, 0.76, -2.12) * CFrame.Angles(0, math.rad(90), 0), C.Brass, M.Foil)
	K.Cylinder(model, "BarrelBand", 0.08, 0.28, CFrame.new(0, 0.76, -0.9) * CFrame.Angles(0, math.rad(90), 0), C.Brass, M.Foil)
	K.Arc(model, "TriggerGuard", CFrame.new(0, 0.38, -0.32) * CFrame.Angles(0, math.rad(90), 0), 0.22, 180, 360, 5, 0.05, 0.06, C.Brass, M.Foil)
	K.Part(model, "Trigger", Vector3.new(0.05, 0.22, 0.06), CFrame.new(0, 0.38, -0.3), C.Brass, M.Foil)
	K.Part(model, "LockPlate", Vector3.new(0.04, 0.22, 0.55), CFrame.new(0.17, 0.64, -0.3), C.Steel, M.Metal)
	K.Part(model, "Pan", Vector3.new(0.12, 0.06, 0.14), CFrame.new(0.17, 0.78, -0.45), C.Brass, M.Foil)
	K.Part(model, "Frizzen", Vector3.new(0.06, 0.22, 0.08), CFrame.new(0.17, 0.88, -0.48), C.Steel, M.Metal)
	-- hammer (cock) on a Motor6D so the client can snap it forward on fire
	local hammer = K.Part(model, "Hammer", Vector3.new(0.06, 0.32, 0.1), CFrame.new(0.17, 0.92, -0.1) * CFrame.Angles(math.rad(-25), 0, 0), C.Steel, M.Metal)
	K.Part(model, "Flint", Vector3.new(0.07, 0.07, 0.07), CFrame.new(0.17, 1.06, -0.18), RGB(70, 70, 75), M.Slate)
	local flint = model:FindFirstChild("Flint") :: BasePart
	K.Weld(hammer, flint)
	K.Motor(handle, hammer, "HammerMotor", CFrame.new(0.17, 0.78, -0.08))
	K.Attachment(handle, "MuzzleAttachment", CFrame.new(0, 0.76, -2.2))
	K.Attachment(handle, "StringAttachment", CFrame.new(0.17, 0.8, -0.45))
	finish(model, handle)
	return model
end

function WeaponPrefabs.Blunderbuss(): Model
	local model, handle = begin("Blunderbuss_Model", "Blunderbuss", Vector3.new(0.34, 0.8, 0.5), C.DarkOak, M.Wood)
	handle.CFrame = CFrame.Angles(math.rad(14), 0, 0)
	K.Part(model, "Stock", Vector3.new(0.45, 0.75, 1.5), CFrame.new(0, 0.2, 1.0) * CFrame.Angles(math.rad(-8), 0, 0), C.DarkOak, M.Wood)
	K.Part(model, "ButtPlate", Vector3.new(0.47, 0.8, 0.1), CFrame.new(0, 0.15, 1.78), C.Brass, M.Foil)
	K.Part(model, "Forestock", Vector3.new(0.36, 0.3, 1.6), CFrame.new(0, 0.56, -0.7), C.DarkOak, M.Wood)
	local barrelParts: { BasePart } = {
		K.Cylinder(nil, "B1", 2.2, 0.34, CFrame.new(0, 0.78, -1.3) * CFrame.Angles(0, math.rad(90), 0), C.Brass, M.Foil),
		K.Cylinder(nil, "B2", 0.35, 0.5, CFrame.new(0, 0.78, -2.45) * CFrame.Angles(0, math.rad(90), 0), C.Brass, M.Foil),
		K.Cylinder(nil, "B3", 0.3, 0.68, CFrame.new(0, 0.78, -2.75) * CFrame.Angles(0, math.rad(90), 0), C.Brass, M.Foil),
		K.Cylinder(nil, "B4", 0.22, 0.86, CFrame.new(0, 0.78, -2.98) * CFrame.Angles(0, math.rad(90), 0), C.Brass, M.Foil),
	}
	local barrel = K.Union(barrelParts, "FlaredBarrel", model)
	local bore = K.Cylinder(model, "MuzzleBore", 0.04, 0.6, CFrame.new(0, 0.78, -3.1) * CFrame.Angles(0, math.rad(90), 0), RGB(20, 18, 16), M.SmoothPlastic)
	bore.CastShadow = false
	K.Arc(model, "TriggerGuard", CFrame.new(0, 0.3, -0.25) * CFrame.Angles(0, math.rad(90), 0), 0.24, 180, 360, 5, 0.05, 0.07, C.Brass, M.Foil)
	K.Part(model, "LockPlate", Vector3.new(0.05, 0.25, 0.6), CFrame.new(0.2, 0.65, -0.1), C.Steel, M.Metal)
	local hammer = K.Part(model, "Hammer", Vector3.new(0.07, 0.34, 0.1), CFrame.new(0.2, 0.86, 0.05) * CFrame.Angles(math.rad(-25), 0, 0), C.Steel, M.Metal)
	K.Motor(handle, hammer, "HammerMotor", CFrame.new(0.2, 0.72, 0.08))
	K.Attachment(handle, "MuzzleAttachment", CFrame.new(0, 0.78, -3.15))
	K.Attachment(handle, "StringAttachment", CFrame.new(0.2, 0.75, -0.2))
	model:SetAttribute("BarrelIsUnion", barrel:IsA("UnionOperation"))
	finish(model, handle)
	return model
end

function WeaponPrefabs.Musket(): Model
	local model, handle = begin("Musket_Model", "Musket", Vector3.new(0.3, 0.75, 0.45), C.Wood, M.Wood)
	handle.CFrame = CFrame.Angles(math.rad(16), 0, 0)
	K.Part(model, "Stock", Vector3.new(0.4, 0.7, 1.7), CFrame.new(0, 0.18, 1.1) * CFrame.Angles(math.rad(-8), 0, 0), C.Wood, M.Wood)
	K.Part(model, "ButtPlate", Vector3.new(0.42, 0.74, 0.08), CFrame.new(0, 0.1, 1.98), C.Steel, M.Metal)
	K.Part(model, "LongForestock", Vector3.new(0.32, 0.28, 3.8), CFrame.new(0, 0.55, -1.6), C.Wood, M.Wood)
	K.Cylinder(model, "LongBarrel", 4.8, 0.2, CFrame.new(0, 0.74, -2.1) * CFrame.Angles(0, math.rad(90), 0), C.DarkSteel, M.Metal)
	for i, z in { -0.9, -2.2, -3.4 } do
		K.Cylinder(model, "BarrelBand" .. i, 0.1, 0.38, CFrame.new(0, 0.66, z) * CFrame.Angles(0, math.rad(90), 0), C.Steel, M.Metal)
	end
	K.Part(model, "FrontSight", Vector3.new(0.04, 0.12, 0.08), CFrame.new(0, 0.88, -4.35), C.Steel, M.Metal)
	K.Part(model, "RearSight", Vector3.new(0.18, 0.1, 0.06), CFrame.new(0, 0.87, -0.2), C.Steel, M.Metal)
	K.Part(model, "RearSightNotchL", Vector3.new(0.05, 0.06, 0.06), CFrame.new(-0.06, 0.94, -0.2), C.Steel, M.Metal)
	K.Part(model, "RearSightNotchR", Vector3.new(0.05, 0.06, 0.06), CFrame.new(0.06, 0.94, -0.2), C.Steel, M.Metal)
	K.Cylinder(model, "Ramrod", 3.6, 0.07, CFrame.new(0, 0.42, -2.1) * CFrame.Angles(0, math.rad(90), 0), C.LightWood, M.Wood)
	K.Arc(model, "TriggerGuard", CFrame.new(0, 0.28, -0.2) * CFrame.Angles(0, math.rad(90), 0), 0.22, 180, 360, 5, 0.05, 0.06, C.Steel, M.Metal)
	K.Part(model, "LockPlate", Vector3.new(0.05, 0.22, 0.55), CFrame.new(0.18, 0.62, -0.05), C.Steel, M.Metal)
	local hammer = K.Part(model, "Hammer", Vector3.new(0.06, 0.3, 0.1), CFrame.new(0.18, 0.84, 0.08) * CFrame.Angles(math.rad(-25), 0, 0), C.Steel, M.Metal)
	K.Motor(handle, hammer, "HammerMotor", CFrame.new(0.18, 0.7, 0.1))
	K.Attachment(handle, "MuzzleAttachment", CFrame.new(0, 0.74, -4.55))
	K.Attachment(handle, "StringAttachment", CFrame.new(0.18, 0.72, -0.15))
	finish(model, handle)
	return model
end

function WeaponPrefabs.Sling(): Model
	local model, handle = begin("Sling_Model", "Sling", Vector3.new(0.25, 0.4, 0.25), C.Leather, M.Fabric)
	K.Cylinder(model, "FingerLoop", 0.08, 0.35, CFrame.new(0, 0.25, 0), C.Leather, M.Fabric)
	local pouch = K.Part(model, "Pouch", Vector3.new(0.5, 0.18, 0.4), CFrame.new(0, -1.6, 0), C.Leather, M.Fabric)
	local stone = K.Ball(model, "Stone", 0.32, CFrame.new(0, -1.5, 0), C.Stone, M.Slate)
	K.Weld(pouch, stone)
	K.Motor(handle, pouch, "PouchMotor", CFrame.new(0, 0, 0))
	local hA = K.Attachment(handle, "StrapTopL", CFrame.new(-0.06, -0.15, 0))
	local hB = K.Attachment(handle, "StrapTopR", CFrame.new(0.06, -0.15, 0))
	local pA = K.Attachment(pouch, "StrapBottomL", CFrame.new(-0.24, 0, 0))
	local pB = K.Attachment(pouch, "StrapBottomR", CFrame.new(0.24, 0, 0))
	K.BeamBetween(handle, hA, pA, C.Leather, 0.07, { Segments = 6, CurveSize0 = 0.2, CurveSize1 = -0.2 }).Name = "StrapLeft"
	K.BeamBetween(handle, hB, pB, C.Leather, 0.07, { Segments = 6, CurveSize0 = -0.2, CurveSize1 = 0.2 }).Name = "StrapRight"
	K.Attachment(pouch, "MuzzleAttachment", CFrame.new(0, 0.1, 0))
	K.Attachment(handle, "StringAttachment", CFrame.new(0, -0.15, 0))
	finish(model, handle)
	return model
end

local function knife(parent: Model, name: string, base: CFrame, scale: number): BasePart
	local grip = K.Part(parent, name .. "_Grip", Vector3.new(0.14, 0.42, 0.14) * scale, base, C.BlackLeather, M.Fabric)
	K.Part(parent, name .. "_Knot", Vector3.new(0.18, 0.06, 0.18) * scale, base * CFrame.new(0, -0.12 * scale, 0), C.BlackLeather, M.Fabric)
	K.Part(parent, name .. "_Guard", Vector3.new(0.1, 0.06, 0.4) * scale, base * CFrame.new(0, 0.23 * scale, 0), C.Silver, M.Metal)
	K.Part(parent, name .. "_Blade", Vector3.new(0.04, 0.6, 0.22) * scale, base * CFrame.new(0, 0.56 * scale, 0), C.Silver, M.Metal)
	K.Tip(parent, name .. "_Point", base * CFrame.new(0, 0.86 * scale, 0), 0.22 * scale, 0.3 * scale, C.Silver, M.Metal)
	return grip
end

function WeaponPrefabs.ThrowingKnives(): Model
	local model, handle = begin("ThrowingKnives_Model", "ThrowingKnives", Vector3.new(0.14, 0.42, 0.14), C.BlackLeather, M.Fabric)
	K.Part(model, "Knot", Vector3.new(0.18, 0.06, 0.18), CFrame.new(0, -0.12, 0), C.BlackLeather, M.Fabric)
	K.Part(model, "Guard", Vector3.new(0.1, 0.06, 0.4), CFrame.new(0, 0.23, 0), C.Silver, M.Metal)
	K.Part(model, "Blade", Vector3.new(0.04, 0.6, 0.22), CFrame.new(0, 0.56, 0), C.Silver, M.Metal)
	K.Tip(model, "Point", CFrame.new(0, 0.86, 0), 0.22, 0.3, C.Silver, M.Metal)
	-- 3-knife holster worn on the thigh (stays on the model, hidden from first person)
	local holster = K.Model(model, "Holster")
	local strap = K.Part(holster, "HolsterStrap", Vector3.new(0.7, 0.5, 0.14), CFrame.new(0, -0.8, 0.6), C.Leather, M.Fabric)
	for i = 1, 3 do
		knife(holster, "Spare" .. i, CFrame.new((i - 2) * 0.2, -0.95, 0.68), 0.8)
	end
	holster.PrimaryPart = strap
	K.Attachment(handle, "MuzzleAttachment", CFrame.new(0, 1.0, 0))
	K.Attachment(handle, "StringAttachment", CFrame.new(0, 0, 0))
	finish(model, handle)
	return model
end

function WeaponPrefabs.Javelins(): Model
	local model, handle = begin("Javelins_Model", "Javelins", Vector3.new(0.22, 0.6, 0.22), C.Leather, M.Fabric)
	-- 6 stud shaft through the grip, held at its balance point (along -Z = throw direction)
	K.Cylinder(model, "Shaft", 6, 0.18, CFrame.new(0, 0, -0.6) * CFrame.Angles(0, math.rad(90), 0), C.LightWood, M.Wood)
	K.Tip(model, "IronHead", CFrame.new(0, 0, -3.6) * CFrame.Angles(-math.pi / 2, 0, 0), 0.34, 0.9, C.Iron, M.Metal)
	K.Cylinder(model, "Socket", 0.3, 0.24, CFrame.new(0, 0, -3.5) * CFrame.Angles(0, math.rad(90), 0), C.Iron, M.Metal)
	K.Cylinder(model, "ButtCap", 0.15, 0.22, CFrame.new(0, 0, 2.35) * CFrame.Angles(0, math.rad(90), 0), C.Iron, M.Metal)
	K.Attachment(handle, "MuzzleAttachment", CFrame.new(0, 0, -4.4))
	K.Attachment(handle, "StringAttachment", CFrame.new(0, 0, 0))
	model:SetAttribute("GripC0", CFrame.new(0, -0.2, 0) * CFrame.Angles(-math.pi / 2, 0, 0))
	finish(model, handle)
	return model
end

function WeaponPrefabs.Harpoon(): Model
	local model, handle = begin("Harpoon_Model", "Harpoon", Vector3.new(0.24, 0.6, 0.24), C.DarkOak, M.Wood)
	K.Cylinder(model, "Shaft", 4.2, 0.2, CFrame.new(0, 0, -1.2) * CFrame.Angles(0, math.rad(90), 0), C.DarkOak, M.Wood)
	local head = K.Part(model, "HarpoonHead", Vector3.new(0.18, 0.18, 0.7), CFrame.new(0, 0, -3.6), C.Steel, M.Metal)
	K.Tip(model, "HarpoonPoint", CFrame.new(0, 0, -3.95) * CFrame.Angles(-math.pi / 2, 0, 0), 0.24, 0.55, C.Steel, M.Metal)
	-- swept-back barbs
	for i, sign in { 1, -1 } do
		K.Wedge(model, "Barb" .. i, Vector3.new(0.06, 0.32, 0.4), CFrame.new(sign * 0.16, 0, -3.55) * CFrame.Angles(0, 0, sign * math.rad(90)) * CFrame.Angles(math.rad(180), 0, 0), C.Steel, M.Metal)
	end
	K.Ball(model, "RopeEyelet", 0.22, CFrame.new(0, 0, 0.95), C.Steel, M.Metal)
	-- coiled rope on the shaft + RopeConstraint to the head (visible rope physics)
	for i = 1, 4 do
		K.Cylinder(model, "RopeCoil" .. i, 0.09, 0.32, CFrame.new(0, 0, 0.35 + i * 0.1) * CFrame.Angles(0, math.rad(90), 0), C.Rope, M.Fabric)
	end
	local a0 = K.Attachment(handle, "RopeStart", CFrame.new(0, 0, 0.95))
	local a1 = K.Attachment(head, "RopeEnd", CFrame.new(0, 0, 0.3))
	local rope = Instance.new("RopeConstraint")
	rope.Name = "HarpoonRope"
	rope.Attachment0 = a0
	rope.Attachment1 = a1
	rope.Length = 4.6
	rope.Visible = true
	rope.Color = BrickColor.new("Brick yellow")
	rope.Thickness = 0.05
	rope.Parent = handle
	K.Attachment(handle, "MuzzleAttachment", CFrame.new(0, 0, -4.3))
	K.Attachment(handle, "StringAttachment", CFrame.new(0, 0, 0.95))
	finish(model, handle)
	return model
end

function WeaponPrefabs.Bolas(): Model
	local model, handle = begin("Bolas_Model", "Bolas", Vector3.new(0.3, 0.3, 0.3), C.Rope, M.Fabric)
	handle.Shape = Enum.PartType.Ball
	local knotA = K.Attachment(handle, "Knot", CFrame.identity)
	for i = 1, 3 do
		local angle = math.rad((i - 1) * 120)
		local pos = Vector3.new(math.cos(angle) * 1.1, -1.25, math.sin(angle) * 1.1)
		local weight = K.Ball(model, "Weight" .. i, 0.42, CFrame.new(pos), C.Iron, M.Metal)
		K.Rod(model, "Rope" .. i, Vector3.zero, pos, 0.05, C.Rope, M.Fabric)
		local wA = K.Attachment(weight, "RopeEnd", CFrame.identity)
		K.BeamBetween(handle, knotA, wA, C.Rope, 0.06, { Segments = 8, CurveSize0 = 0.3, CurveSize1 = 0 }).Name = "RopeBeam" .. i
	end
	K.Attachment(handle, "MuzzleAttachment", CFrame.new(0, 0, -0.3))
	K.Attachment(handle, "StringAttachment", CFrame.identity)
	finish(model, handle)
	return model
end

function WeaponPrefabs.Chakram(): Model
	local model, handle = begin("Chakram_Model", "Chakram", Vector3.new(0.18, 0.5, 0.18), C.BlackLeather, M.Fabric)
	-- ring lies in the XZ plane, gripped at its inner edge (handle at ring centre offset)
	local ringCenter = CFrame.new(0, 0, -0.95)
	local disc = K.Cylinder(nil, "Disc", 0.14, 2.6, ringCenter * CFrame.Angles(0, 0, math.rad(90)), C.Silver, M.Metal)
	local hole = K.Cylinder(nil, "Hole", 0.4, 1.7, ringCenter * CFrame.Angles(0, 0, math.rad(90)), C.Silver, M.Metal)
	local ring = K.Subtract(disc, { hole }, "BladeRing", model)
	if ring:IsA("BasePart") and not ring:IsA("UnionOperation") then
		-- CSG unavailable: rebuild the hollow ring from segments
		ring:Destroy()
		K.Ring(model, "BladeRingSeg", ringCenter, 1.08, 16, 0.42, 0.14, C.Silver, M.Metal)
	end
	-- outer edge spikes
	for i = 0, 7 do
		local a = math.rad(i * 45)
		K.Wedge(model, "EdgeSpike" .. (i + 1), Vector3.new(0.06, 0.3, 0.36), ringCenter * CFrame.Angles(0, a, 0) * CFrame.new(0, 0, -1.4) * CFrame.Angles(math.rad(-90), 0, 0), C.Silver, M.Metal)
	end
	-- gold inner filigree ring
	K.Ring(model, "GoldInlay", ringCenter * CFrame.new(0, 0.075, 0), 0.92, 16, 0.08, 0.02, C.Gold, M.Foil)
	K.Attachment(handle, "MuzzleAttachment", CFrame.new(0, 0, -1.2))
	K.Attachment(handle, "StringAttachment", CFrame.identity)
	finish(model, handle)
	model:SetAttribute("GripC0", CFrame.new(0, -0.25, 0))
	return model
end

---------------------------------------------------------------------------------------------
-- MELEE
---------------------------------------------------------------------------------------------

function WeaponPrefabs.DiamondDagger(): Model
	local model, handle = begin("DiamondDagger_Model", "DiamondDagger", Vector3.new(0.2, 0.7, 0.2), C.Leather, M.Fabric)
	K.Ball(model, "Pommel", 0.26, CFrame.new(0, -0.4, 0), C.Gold, M.Foil)
	K.Part(model, "Crossguard", Vector3.new(0.18, 0.14, 0.9), CFrame.new(0, 0.4, 0), C.Gold, M.Foil)
	K.Ball(model, "GuardGemL", 0.12, CFrame.new(0, 0.4, -0.45), C.Diamond, M.Neon)
	K.Ball(model, "GuardGemR", 0.12, CFrame.new(0, 0.4, 0.45), C.Diamond, M.Neon)
	-- 2.2 stud blade: glass shell + neon core (y 0.47 -> 2.67)
	local shell = K.Part(model, "BladeGlass", Vector3.new(0.1, 1.75, 0.42), CFrame.new(0, 1.35, 0), C.Diamond, M.Glass)
	shell.Transparency = 0.25
	K.Part(model, "BladeCore", Vector3.new(0.05, 1.7, 0.16), CFrame.new(0, 1.33, 0), C.DiamondCore, M.Neon)
	for _, w in K.Tip(model, "BladeTip", CFrame.new(0, 2.22, 0), 0.42, 0.45, C.Diamond, M.Glass) do
		w.Transparency = 0.25
	end
	local glow = K.PointLight(handle, C.Diamond, 1.2, 6)
	glow.Name = "DiamondGlow"
	dmgPoints(handle, 0.55, 2.62, 5)
	finish(model, handle)
	return model
end

function WeaponPrefabs.IronSword(): Model
	local model, handle = begin("IronSword_Model", "IronSword", Vector3.new(0.22, 1.0, 0.22), C.Leather, M.Fabric)
	K.Ball(model, "Pommel", 0.32, CFrame.new(0, -0.6, 0), C.Steel, M.Metal)
	K.Part(model, "Crossguard", Vector3.new(0.2, 0.18, 1.4), CFrame.new(0, 0.58, 0), C.Steel, M.Metal)
	K.Part(model, "Ricasso", Vector3.new(0.14, 0.2, 0.4), CFrame.new(0, 0.77, 0), C.Steel, M.Metal)
	-- double-edged blade, 4.2 studs from guard (y 0.67) to point (y 4.87)
	K.Part(model, "Blade", Vector3.new(0.1, 3.75, 0.38), CFrame.new(0, 2.55, 0), C.Steel, M.Metal)
	K.Part(model, "Fuller", Vector3.new(0.11, 3.0, 0.08), CFrame.new(0, 2.4, 0), C.DarkSteel, M.Metal)
	K.Tip(model, "Point", CFrame.new(0, 4.42, 0), 0.38, 0.45, C.Steel, M.Metal)
	dmgPoints(handle, 0.85, 4.8, 7)
	finish(model, handle)
	return model
end

function WeaponPrefabs.Hammer(): Model
	local model, handle = begin("Hammer_Model", "Hammer", Vector3.new(0.3, 1.0, 0.3), C.Leather, M.Fabric)
	K.Cylinder(model, "Shaft", 4.6, 0.26, CFrame.new(0, 1.6, 0) * CFrame.Angles(0, 0, math.rad(90)), C.Wood, M.Wood)
	K.Cylinder(model, "UpperGrip", 0.8, 0.3, CFrame.new(0, 1.6, 0) * CFrame.Angles(0, 0, math.rad(90)), C.Leather, M.Fabric)
	K.Cylinder(model, "Collar", 0.3, 0.42, CFrame.new(0, 3.6, 0) * CFrame.Angles(0, 0, math.rad(90)), C.DarkSteel, M.Metal)
	-- oversized steel head (faces along +-Z)
	K.Part(model, "Head", Vector3.new(1.15, 1.15, 2.3), CFrame.new(0, 4.25, 0), C.DarkSteel, M.Metal)
	for _, z in { -1.2, 1.2 } do
		K.Part(model, "Face" .. (if z < 0 then "Front" else "Back"), Vector3.new(1.3, 1.3, 0.14), CFrame.new(0, 4.25, z), C.Steel, M.Metal)
		for ix = -1, 1, 2 do
			for iy = -1, 1, 2 do
				K.Part(model, "Stud", Vector3.new(0.24, 0.24, 0.16), CFrame.new(ix * 0.35, 4.25 + iy * 0.35, z + (if z < 0 then -0.13 else 0.13)), C.Iron, M.Metal)
			end
		end
	end
	K.Ball(model, "Pommel", 0.38, CFrame.new(0, -0.6, 0), C.DarkSteel, M.Metal)
	dmgPoints(handle, 3.5, 4.85, 6, -1.2)
	model:SetAttribute("TwoHanded", true)
	finish(model, handle)
	return model
end

-- Crescent axe bit: sequence of edge wedges along an arc in the YZ plane on side `sign` (Z).
local function crescent(parent: Model, name: string, centerY: number, sign: number, radius: number, color: Color3)
	local segments = 5
	for i = 0, segments - 1 do
		local a = math.rad(-70 + 140 * ((i + 0.5) / segments))
		local y = centerY + math.sin(a) * radius
		local z = sign * (0.35 + math.cos(a) * radius * 0.55)
		local cf = CFrame.new(0, y, z) * CFrame.Angles(-a * sign, 0, 0)
		K.Part(parent, string.format("%s_Plate%d", name, i + 1), Vector3.new(0.08, radius * 0.62, radius * 0.9), cf * CFrame.new(0, 0, -sign * radius * 0.2), color, M.Metal)
		K.Edge(parent, string.format("%s_Edge%d", name, i + 1), CFrame.new(0, y, z + sign * radius * 0.25) * CFrame.Angles(sign * math.pi / 2, 0, 0), 0.06, 0.12, radius * 0.25, C.Silver, M.Metal)
	end
	K.CornerWedge(parent, name .. "_HornTop", Vector3.new(0.08, 0.5, 0.4), CFrame.new(0, centerY + radius * 0.98, sign * 0.55), color, M.Metal)
	K.CornerWedge(parent, name .. "_HornBottom", Vector3.new(0.08, 0.5, 0.4), CFrame.new(0, centerY - radius * 0.98, sign * 0.55) * CFrame.Angles(math.pi, 0, 0), color, M.Metal)
end

function WeaponPrefabs.BattleAxe(): Model
	local model, handle = begin("BattleAxe_Model", "BattleAxe", Vector3.new(0.28, 1.0, 0.28), C.Leather, M.Fabric)
	K.Cylinder(model, "Haft", 4.2, 0.26, CFrame.new(0, 1.5, 0) * CFrame.Angles(0, 0, math.rad(90)), C.Wood, M.Wood)
	for i, y in { 0.9, 2.1, 3.1 } do
		K.Cylinder(model, "IronBand" .. i, 0.14, 0.31, CFrame.new(0, y, 0) * CFrame.Angles(0, 0, math.rad(90)), C.Iron, M.Metal)
	end
	K.Part(model, "Eye", Vector3.new(0.36, 0.8, 0.6), CFrame.new(0, 3.45, 0), C.DarkSteel, M.Metal)
	crescent(model, "BitFront", 3.45, -1, 0.95, C.Steel)
	crescent(model, "BitBack", 3.45, 1, 0.95, C.Steel)
	K.Tip(model, "TopSpike", CFrame.new(0, 3.85, 0), 0.26, 0.5, C.Steel, M.Metal)
	dmgPoints(handle, 2.6, 4.3, 6, -1.0)
	model:SetAttribute("TwoHanded", true)
	finish(model, handle)
	return model
end

function WeaponPrefabs.Spear(): Model
	local model, handle = begin("Spear_Model", "Spear", Vector3.new(0.24, 0.8, 0.24), C.Leather, M.Fabric)
	-- 7.5 stud total: shaft y -1.5 -> 5.3, head to 6.0
	K.Cylinder(model, "Shaft", 6.8, 0.22, CFrame.new(0, 1.9, 0) * CFrame.Angles(0, 0, math.rad(90)), C.LightWood, M.Wood)
	K.Cylinder(model, "ButtSpike", 0.3, 0.26, CFrame.new(0, -1.5, 0) * CFrame.Angles(0, 0, math.rad(90)), C.Iron, M.Metal)
	K.Cylinder(model, "Socket", 0.5, 0.28, CFrame.new(0, 5.05, 0) * CFrame.Angles(0, 0, math.rad(90)), C.Steel, M.Metal)
	-- diamond head: upward point + short inverted base
	K.Tip(model, "HeadUpper", CFrame.new(0, 5.45, 0), 0.5, 0.7, C.Steel, M.Metal)
	K.Tip(model, "HeadLower", CFrame.new(0, 5.45, 0) * CFrame.Angles(math.pi, 0, 0), 0.5, 0.25, C.Steel, M.Metal)
	-- red feather tassel below the head
	for i = 0, 5 do
		local a = math.rad(i * 60)
		local feather = K.Part(model, "Feather" .. (i + 1), Vector3.new(0.06, 0.55, 0.16), CFrame.new(math.cos(a) * 0.16, 4.6, math.sin(a) * 0.16) * CFrame.Angles(0, -a, math.rad(18)), C.Red, M.Fabric)
		feather.CastShadow = false
	end
	K.Cylinder(model, "TasselBinding", 0.12, 0.3, CFrame.new(0, 4.85, 0) * CFrame.Angles(0, 0, math.rad(90)), C.Gold, M.Foil)
	dmgPoints(handle, 4.6, 6.1, 5)
	model:SetAttribute("TwoHanded", true)
	finish(model, handle)
	return model
end

function WeaponPrefabs.Shield(): Model
	local model, handle = begin("Shield_Model", "Shield", Vector3.new(0.3, 0.9, 0.3), C.Leather, M.Fabric)
	model:SetAttribute("AttachPart", "LeftLowerArm")
	model:SetAttribute("GripC0", CFrame.new(-0.15, 0.35, -0.55))
	local face = CFrame.new(0, 0, -0.35)
	-- wooden planks (round shield, face normal = -Z)
	for i = -3, 3 do
		local w = 0.46
		local h = 3.1 * math.sqrt(math.max(0, 1 - ((i * w) / 1.6) ^ 2))
		K.Part(model, "Plank" .. (i + 4), Vector3.new(w - 0.02, h, 0.22), face * CFrame.new(i * w, 0, 0), if i % 2 == 0 then C.Wood else C.LightWood, M.WoodPlanks)
	end
	-- steel rim around the disc (ring in the XY plane)
	K.Arc(model, "Rim", face * CFrame.new(0, 0, -0.02), 1.6, 0, 360, 20, 0.16, 0.28, C.Steel, M.Metal)
	-- central boss
	local boss = K.Ball(model, "Boss", 0.8, face * CFrame.new(0, 0, -0.2), C.Steel, M.Metal)
	K.Mesh(boss, Enum.MeshType.Sphere, Vector3.new(1, 1, 0.55))
	K.Part(model, "ArmStrap", Vector3.new(0.9, 0.16, 0.1), CFrame.new(0, 0.3, -0.2), C.Leather, M.Fabric)
	-- DestructibleShields collider: query-able so projectiles stick into it
	local collider = K.Part(model, "ShieldCollider", Vector3.new(3.3, 3.3, 0.5), face, Color3.new(1, 1, 1), M.SmoothPlastic)
	collider.Transparency = 1
	collider:SetAttribute("ShieldCollider", true)
	collider.CanQuery = true
	K.Attachment(handle, "ArrowStickPoint", face * CFrame.new(0, 0, -0.15))
	finish(model, handle)
	collider.CanQuery = true
	return model
end

-- Ranked melees ------------------------------------------------------------------------------

function WeaponPrefabs.Katana(): Model
	local model, handle = begin("Katana_Model", "Katana", Vector3.new(0.2, 1.1, 0.24), C.BlackLeather, M.Fabric)
	-- diamond-wrap pattern on the tsuka
	for i = 0, 4 do
		K.Part(model, "Ito" .. (i + 1), Vector3.new(0.22, 0.06, 0.26), CFrame.new(0, -0.4 + i * 0.2, 0) * CFrame.Angles(0, 0, math.rad(if i % 2 == 0 then 18 else -18)), C.Gold, M.Fabric)
	end
	K.Cylinder(model, "Tsuba", 0.08, 0.75, CFrame.new(0, 0.6, 0) * CFrame.Angles(0, 0, math.rad(90)), C.DarkSteel, M.Metal)
	K.Part(model, "Habaki", Vector3.new(0.12, 0.18, 0.3), CFrame.new(0, 0.73, 0), C.Gold, M.Foil)
	-- curved blade: 6 segments, each tilted a little further back (sori)
	local y = 0.82
	local z = 0
	for i = 1, 6 do
		local tilt = math.rad(2.2 * i)
		local len = 0.62
		local cf = CFrame.new(0, y + math.cos(tilt) * len / 2, z + math.sin(tilt) * len / 2) * CFrame.Angles(tilt, 0, 0)
		K.Part(model, "BladeSeg" .. i, Vector3.new(0.07, len, 0.26 - i * 0.012), cf, C.Silver, M.Metal)
		K.Part(model, "Hamon" .. i, Vector3.new(0.075, len, 0.05), cf * CFrame.new(0, 0, -0.1), Color3.new(1, 1, 1), M.SmoothPlastic)
		y += math.cos(tilt) * len
		z += math.sin(tilt) * len
	end
	K.Tip(model, "Kissaki", CFrame.new(0, y, z) * CFrame.Angles(math.rad(14), 0, 0), 0.2, 0.32, C.Silver, M.Metal)
	-- saya (scabbard) worn on the hip
	local saya = K.Model(model, "Saya")
	local sayaRoot = K.Part(saya, "SayaRoot", Vector3.new(0.18, 3.6, 0.32), CFrame.new(1.5, 0, 0), C.Ebony, M.SmoothPlastic)
	K.Part(saya, "Koiguchi", Vector3.new(0.2, 0.15, 0.34), CFrame.new(1.5, 1.8, 0), C.Gold, M.Foil)
	K.Part(saya, "Kojiri", Vector3.new(0.2, 0.15, 0.34), CFrame.new(1.5, -1.8, 0), C.Gold, M.Foil)
	saya.PrimaryPart = sayaRoot
	saya:SetAttribute("WearPart", "LowerTorso")
	saya:SetAttribute("WearC0", CFrame.new(-1.05, -0.2, 0.2) * CFrame.Angles(math.rad(60), 0, math.rad(10)))
	dmgPoints(handle, 0.9, y, 7, z * 0.5)
	finish(model, handle)
	return model
end

function WeaponPrefabs.Scythe(): Model
	local model, handle = begin("Scythe_Model", "Scythe", Vector3.new(0.26, 1.0, 0.26), C.Ebony, M.Wood)
	K.Cylinder(model, "Snath", 6.0, 0.24, CFrame.new(0, 2.2, 0) * CFrame.Angles(0, 0, math.rad(90)), C.Ebony, M.Wood)
	K.Cylinder(model, "Grip2", 0.5, 0.3, CFrame.new(0, 2.6, 0) * CFrame.Angles(0, 0, math.rad(90)), C.BlackLeather, M.Fabric)
	K.Part(model, "BladeMount", Vector3.new(0.3, 0.4, 0.4), CFrame.new(0, 5.15, 0), C.DarkSteel, M.Metal)
	-- long curved blade sweeping toward -Z
	local prev = Vector3.new(0, 5.2, 0)
	for i = 1, 6 do
		local t = i / 6
		local p = Vector3.new(0, 5.2 + math.sin(t * math.pi * 0.5) * 0.9 - t * t * 0.9, -t * 3.2)
		K.Beam3(model, "Blade" .. i, prev, p, 0.06, 0.55 - t * 0.35, C.DarkSteel, M.Metal)
		prev = p
	end
	K.Tip(model, "BladePoint", CFrame.lookAt(prev, prev + Vector3.new(0, -0.4, -1)) * CFrame.Angles(-math.pi / 2, 0, 0), 0.16, 0.4, C.DarkSteel, M.Metal)
	for i = 1, 6 do
		local t = (i - 1) / 5
		K.Attachment(handle, "DmgPoint", CFrame.new(0, 5.2 + math.sin(t * math.pi * 0.5) * 0.9 - t * t * 0.9 - 0.2, -t * 3.1)):SetAttribute("Index", i)
	end
	local top = K.Attachment(handle, "TopAttachment", CFrame.new(prev))
	local bottom = K.Attachment(handle, "BottomAttachment", CFrame.new(0, 5.0, 0))
	K.Trail(handle, top, bottom, K.ColorSeq(RGB(120, 60, 200), RGB(20, 0, 40)), 0.25, K.Seq(0.2, 1)).Name = "SwingTrail"
	model:SetAttribute("TwoHanded", true)
	finish(model, handle)
	return model
end

local function gauntlet(parent: Model, name: string, root: CFrame): Part
	local cuff = K.Part(parent, name .. "Root", Vector3.new(0.75, 0.8, 0.75), root * CFrame.new(0, 0.35, 0), C.DarkSteel, M.Metal)
	K.Part(parent, name .. "Back", Vector3.new(0.7, 0.45, 0.25), root * CFrame.new(0, -0.15, 0.3), C.Steel, M.Metal)
	for i = 0, 3 do
		K.Part(parent, name .. "Knuckle" .. (i + 1), Vector3.new(0.17, 0.2, 0.3), root * CFrame.new(-0.27 + i * 0.18, -0.42, -0.05), C.Silver, M.Metal)
		K.Tip(parent, name .. "Spike" .. (i + 1), root * CFrame.new(-0.27 + i * 0.18, -0.52, -0.05) * CFrame.Angles(math.pi, 0, 0), 0.12, 0.18, C.Silver, M.Metal)
	end
	return cuff
end

function WeaponPrefabs.Gauntlets(): Model
	local model = K.Model(nil, "Gauntlets_Model")
	model:SetAttribute("ItemId", "Gauntlets")
	model:SetAttribute("AttachPart", "RightHand")
	model:SetAttribute("GripC0", CFrame.new(0, 0.15, 0))
	local handle = gauntlet(model, "Right", CFrame.identity)
	handle.Name = "Handle"
	dmgPoints(handle, -0.6, -0.2, 5)
	local off = K.Model(model, "Offhand")
	local offRoot = gauntlet(off, "Left", CFrame.new(3, 0, 0))
	offRoot.Name = "OffhandHandle"
	off:SetAttribute("AttachPart", "LeftHand")
	off:SetAttribute("GripC0", CFrame.new(0, 0.15, 0))
	K.WeldAll(off, offRoot)
	finish(model, handle)
	return model
end

local function hatchet(parent: Model, name: string, root: CFrame): Part
	local grip = K.Part(parent, name .. "Grip", Vector3.new(0.2, 0.9, 0.2), root, C.Wood, M.Wood)
	K.Cylinder(parent, name .. "Haft", 1.6, 0.18, root * CFrame.new(0, 0.9, 0) * CFrame.Angles(0, 0, math.rad(90)), C.Wood, M.Wood)
	K.Part(parent, name .. "Head", Vector3.new(0.22, 0.4, 0.45), root * CFrame.new(0, 1.65, -0.1), C.DarkSteel, M.Metal)
	K.Edge(parent, name .. "Bit", root * CFrame.new(0, 1.65, -0.35) * CFrame.Angles(-math.pi / 2, 0, 0), 0.08, 0.7, 0.45, C.Silver, M.Metal)
	return grip
end

function WeaponPrefabs.TwinHatchets(): Model
	local model = K.Model(nil, "TwinHatchets_Model")
	model:SetAttribute("ItemId", "TwinHatchets")
	model:SetAttribute("AttachPart", "RightHand")
	model:SetAttribute("GripC0", GRIP_RIGHT)
	local handle = hatchet(model, "Right", CFrame.identity)
	handle.Name = "Handle"
	dmgPoints(handle, 1.3, 2.0, 5, -0.4)
	local off = K.Model(model, "Offhand")
	local offRoot = hatchet(off, "Left", CFrame.new(3, 0, 0))
	offRoot.Name = "OffhandHandle"
	off:SetAttribute("AttachPart", "LeftHand")
	off:SetAttribute("GripC0", GRIP_RIGHT)
	K.WeldAll(off, offRoot)
	finish(model, handle)
	return model
end

---------------------------------------------------------------------------------------------

WeaponPrefabs.Ranged = {
	"WoodBow",
	"Crossbow",
	"Headhunter",
	"Flintlock",
	"Blunderbuss",
	"Musket",
	"Sling",
	"ThrowingKnives",
	"Javelins",
	"Harpoon",
	"Bolas",
	"Chakram",
}

WeaponPrefabs.Melee = { "DiamondDagger", "IronSword", "Hammer", "BattleAxe", "Spear", "Shield" }
WeaponPrefabs.RankedMelee = { "Katana", "Scythe", "Gauntlets", "TwinHatchets" }

local Builders: { [string]: () -> Model } = {
	WoodBow = WeaponPrefabs.WoodBow,
	Crossbow = WeaponPrefabs.Crossbow,
	Headhunter = WeaponPrefabs.Headhunter,
	Flintlock = WeaponPrefabs.Flintlock,
	Blunderbuss = WeaponPrefabs.Blunderbuss,
	Musket = WeaponPrefabs.Musket,
	Sling = WeaponPrefabs.Sling,
	ThrowingKnives = WeaponPrefabs.ThrowingKnives,
	Javelins = WeaponPrefabs.Javelins,
	Harpoon = WeaponPrefabs.Harpoon,
	Bolas = WeaponPrefabs.Bolas,
	Chakram = WeaponPrefabs.Chakram,
	DiamondDagger = WeaponPrefabs.DiamondDagger,
	IronSword = WeaponPrefabs.IronSword,
	Hammer = WeaponPrefabs.Hammer,
	BattleAxe = WeaponPrefabs.BattleAxe,
	Spear = WeaponPrefabs.Spear,
	Shield = WeaponPrefabs.Shield,
	Katana = WeaponPrefabs.Katana,
	Scythe = WeaponPrefabs.Scythe,
	Gauntlets = WeaponPrefabs.Gauntlets,
	TwinHatchets = WeaponPrefabs.TwinHatchets,
}
WeaponPrefabs.Builders = Builders

-- Build every weapon into the given folders (replacing older copies).
function WeaponPrefabs.BuildAll(rangedFolder: Folder, meleeFolder: Folder, rankedFolder: Folder)
	local function place(list: { string }, folder: Folder)
		for _, id in list do
			local model = Builders[id]()
			local old = folder:FindFirstChild(model.Name)
			if old then
				old:Destroy()
			end
			model.Parent = folder
		end
	end
	place(WeaponPrefabs.Ranged, rangedFolder)
	place(WeaponPrefabs.Melee, meleeFolder)
	place(WeaponPrefabs.RankedMelee, rankedFolder)
end

return WeaponPrefabs
