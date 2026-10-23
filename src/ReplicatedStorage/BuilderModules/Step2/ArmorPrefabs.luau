--!strict
-- Step 2b: wearable armor prefabs. Each armor Model holds pieces (sub-Models) built around the
-- centre of the body part they cover. Every piece has a PrimaryPart "Root" with attributes:
--   AttachPart     body part name (UpperTorso / LeftUpperArm / RightUpperArm)
--   ReferenceSize  body part size the piece was modelled for; the rig scales the piece to fit.
-- EquipmentRig welds pieces with WeldConstraint after aligning Root to the body part CFrame.

local GeometryKit = require(script.Parent.Parent.Kit.GeometryKit)

local K = GeometryKit
local RGB = Color3.fromRGB
local M = Enum.Material

local TORSO_REF = Vector3.new(2, 1.6, 1)
local ARM_REF = Vector3.new(1, 1.2, 1)

local ArmorPrefabs = {}

local function piece(armor: Model, name: string, attachPart: string, ref: Vector3): (Model, Part)
	local m = K.Model(armor, name)
	local root = K.Part(m, "Root", ref, CFrame.identity, Color3.new(1, 1, 1), M.SmoothPlastic)
	root.Transparency = 1
	root:SetAttribute("AttachPart", attachPart)
	root:SetAttribute("ReferenceSize", ref)
	m:SetAttribute("AttachPart", attachPart)
	return m, root
end

local function seal(m: Model, root: BasePart)
	K.WeldAll(m, root)
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then
			d.CastShadow = true
		end
	end
end

local function begin(name: string, itemId: string, armorHP: number): Model
	local armor = K.Model(nil, name)
	armor:SetAttribute("ItemId", itemId)
	armor:SetAttribute("ArmorHP", armorHP)
	return armor
end

function ArmorPrefabs.LeatherArmor(): Model
	local armor = begin("LeatherArmor_Model", "LeatherArmor", 25)
	local brown = RGB(110, 70, 42)
	local dark = RGB(70, 44, 28)
	local stud = RGB(190, 170, 120)
	local torso, troot = piece(armor, "Torso", "UpperTorso", TORSO_REF)
	K.Part(torso, "Vest", Vector3.new(2.12, 1.5, 1.12), CFrame.new(0, -0.02, 0), brown, M.Leather)
	K.Part(torso, "Collar", Vector3.new(1.0, 0.18, 1.16), CFrame.new(0, 0.74, 0), dark, M.Leather)
	K.Part(torso, "Belt", Vector3.new(2.16, 0.2, 1.16), CFrame.new(0, -0.7, 0), dark, M.Leather)
	K.Part(torso, "Buckle", Vector3.new(0.3, 0.24, 0.06), CFrame.new(0, -0.7, -0.6), stud, M.Metal)
	for _, x in { -0.35, 0.35 } do
		K.Part(torso, "Lace", Vector3.new(0.05, 1.1, 0.04), CFrame.new(x * 0.3, 0, -0.57), dark, M.Fabric)
	end
	seal(torso, troot)
	for _, side in { "Left", "Right" } do
		local arm, aroot = piece(armor, side .. "Pad", side .. "UpperArm", ARM_REF)
		local pad = K.Ball(arm, "Pad", 1.18, CFrame.new(0, 0.38, 0), brown, M.Leather)
		K.Mesh(pad, Enum.MeshType.Sphere, Vector3.new(1, 0.55, 1))
		for i = 0, 3 do
			local a = math.rad(i * 90 + 45)
			K.Ball(arm, "Stud" .. (i + 1), 0.14, CFrame.new(math.cos(a) * 0.38, 0.6, math.sin(a) * 0.38), stud, M.Metal)
		end
		seal(arm, aroot)
	end
	return armor
end

function ArmorPrefabs.IronArmor(): Model
	local armor = begin("IronArmor_Model", "IronArmor", 50)
	local steel = RGB(184, 188, 196)
	local dark = RGB(110, 114, 122)
	local torso, troot = piece(armor, "Torso", "UpperTorso", TORSO_REF)
	K.Part(torso, "Breastplate", Vector3.new(2.14, 1.56, 1.14), CFrame.new(0, 0, 0), steel, M.Metal)
	-- central ridge made of two wedges meeting at the sternum line
	K.Wedge(torso, "RidgeLeft", Vector3.new(0.5, 1.3, 0.16), CFrame.new(-0.25, 0, -0.65) * CFrame.Angles(0, math.rad(-90), 0), steel, M.Metal)
	K.Wedge(torso, "RidgeRight", Vector3.new(0.5, 1.3, 0.16), CFrame.new(0.25, 0, -0.65) * CFrame.Angles(0, math.rad(90), 0), steel, M.Metal)
	K.Part(torso, "Gorget", Vector3.new(1.3, 0.22, 1.2), CFrame.new(0, 0.82, 0), dark, M.Metal)
	for i = 0, 2 do
		K.Part(torso, "Fauld" .. (i + 1), Vector3.new(2.2 - i * 0.04, 0.16, 1.2 - i * 0.02), CFrame.new(0, -0.68 - i * 0.14, 0), dark, M.Metal)
	end
	seal(torso, troot)
	for _, side in { "Left", "Right" } do
		local sign = if side == "Left" then -1 else 1
		local arm, aroot = piece(armor, side .. "Pauldron", side .. "UpperArm", ARM_REF)
		for i = 0, 2 do
			K.Part(arm, "Lame" .. (i + 1), Vector3.new(1.25 - i * 0.08, 0.2, 1.22 - i * 0.06), CFrame.new(sign * 0.06 * i, 0.55 - i * 0.2, 0) * CFrame.Angles(0, 0, sign * math.rad(-12 - i * 4)), if i == 0 then steel else dark, M.Metal)
		end
		local cap = K.Ball(arm, "Cap", 1.2, CFrame.new(0, 0.6, 0), steel, M.Metal)
		K.Mesh(cap, Enum.MeshType.Sphere, Vector3.new(1, 0.5, 1))
		seal(arm, aroot)
	end
	return armor
end

function ArmorPrefabs.DiamondArmor(): Model
	local armor = begin("DiamondArmor_Model", "DiamondArmor", 100)
	local diamond = RGB(90, 225, 235)
	local deep = RGB(30, 120, 170)
	local gold = RGB(236, 192, 72)
	local cape = RGB(30, 60, 140)
	local torso, troot = piece(armor, "Torso", "UpperTorso", TORSO_REF)
	local plate = K.Part(torso, "Cuirass", Vector3.new(2.16, 1.58, 1.16), CFrame.identity, diamond, M.Glass)
	plate.Reflectance = 0.25
	plate.Transparency = 0.05
	K.Part(torso, "Underplate", Vector3.new(2.08, 1.5, 1.08), CFrame.identity, deep, M.Metal)
	-- crystal facets on the chest (corner wedges)
	for i, x in { -0.45, 0.45 } do
		K.CornerWedge(torso, "Facet" .. i, Vector3.new(0.5, 0.6, 0.2), CFrame.new(x, 0.25, -0.66) * CFrame.Angles(0, if x < 0 then 0 else math.pi / 2, 0), diamond, M.Glass)
	end
	local core = K.Part(torso, "HeartGem", Vector3.new(0.3, 0.3, 0.1), CFrame.new(0, 0.2, -0.62) * CFrame.Angles(0, 0, math.rad(45)), RGB(160, 255, 255), M.Neon)
	core.CastShadow = false
	K.Part(torso, "GoldTrim", Vector3.new(2.2, 0.12, 1.2), CFrame.new(0, -0.74, 0), gold, M.Foil)
	K.Part(torso, "Gorget", Vector3.new(1.4, 0.26, 1.24), CFrame.new(0, 0.84, 0), gold, M.Foil)
	-- heavy cape hanging behind (+Z is the back of the torso)
	K.Part(torso, "CapeTop", Vector3.new(2.0, 0.2, 0.3), CFrame.new(0, 0.75, 0.62), cape, M.Fabric)
	local capeMain = K.Part(torso, "Cape", Vector3.new(2.1, 3.0, 0.08), CFrame.new(0, -0.8, 0.7) * CFrame.Angles(math.rad(6), 0, 0), cape, M.Fabric)
	capeMain.CastShadow = true
	seal(torso, troot)
	for _, side in { "Left", "Right" } do
		local sign = if side == "Left" then -1 else 1
		local arm, aroot = piece(armor, side .. "Pauldron", side .. "UpperArm", ARM_REF)
		local cap = K.Ball(arm, "Cap", 1.3, CFrame.new(0, 0.55, 0), diamond, M.Glass)
		K.Mesh(cap, Enum.MeshType.Sphere, Vector3.new(1, 0.6, 1))
		K.Part(arm, "Lame", Vector3.new(1.25, 0.24, 1.22), CFrame.new(0, 0.2, 0), deep, M.Metal)
		K.Part(arm, "Trim", Vector3.new(1.32, 0.08, 1.3), CFrame.new(0, 0.34, 0), gold, M.Foil)
		K.Tip(arm, "Crystal", CFrame.new(sign * 0.3, 0.8, 0) * CFrame.Angles(0, 0, sign * math.rad(-25)), 0.28, 0.55, diamond, M.Glass)
		seal(arm, aroot)
	end
	return armor
end

local Builders: { [string]: () -> Model } = {
	LeatherArmor = ArmorPrefabs.LeatherArmor,
	IronArmor = ArmorPrefabs.IronArmor,
	DiamondArmor = ArmorPrefabs.DiamondArmor,
}
ArmorPrefabs.Builders = Builders

function ArmorPrefabs.BuildAll(folder: Folder)
	for _, id in { "LeatherArmor", "IronArmor", "DiamondArmor" } do
		local model = Builders[id]()
		local old = folder:FindFirstChild(model.Name)
		if old then
			old:Destroy()
		end
		model.Parent = folder
	end
end

return ArmorPrefabs
