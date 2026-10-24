--!strict
-- EquipmentRig: attaches prefab models to R15 characters.
--   Held items  -> Motor6D "WeaponGrip" from the AttachPart (RightHand / LeftLowerArm) to Handle.
--   Offhand     -> Motor6D "OffhandGrip" from the LeftHand to Offhand.OffhandHandle.
--   Armor       -> each piece scaled to the body part and welded with WeldConstraint.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EquipmentDatabase = require(script.Parent.Parent.Config.EquipmentDatabase)
local CollisionGroups = require(script.Parent.CollisionGroups)

local EquipmentRig = {}

EquipmentRig.HeldName = "EquippedItem"
EquipmentRig.ArmorName = "EquippedArmor"

local prefabCache: { [string]: Model } = {}

function EquipmentRig.GetPrefab(itemId: string): Model?
	local cached = prefabCache[itemId]
	if cached and cached.Parent then
		return cached
	end
	local spec = EquipmentDatabase.Get(itemId)
	if spec == nil then
		return nil
	end
	local root = ReplicatedStorage:FindFirstChild("Procedural_3D_Weapon_And_Armor_Prefabs")
	if root == nil then
		return nil
	end
	local found = root:FindFirstChild(spec.ModelName, true)
	if found and found:IsA("Model") then
		prefabCache[itemId] = found
		return found
	end
	return nil
end

local function cosmetic(model: Instance)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = false
			d.Massless = true
			d.CanTouch = false
			if d:GetAttribute("ShieldCollider") == true then
				d.CollisionGroup = CollisionGroups.DestructibleShields
				d.CanQuery = true
				d.CanCollide = false
			else
				d.CanCollide = false
				d.CanQuery = false
				d.CollisionGroup = CollisionGroups.HitboxParts
			end
		end
	end
end

local function grip(part0: BasePart, part1: BasePart, name: string, c0: CFrame): Motor6D
	local m = Instance.new("Motor6D")
	m.Name = name
	m.Part0 = part0
	m.Part1 = part1
	m.C0 = c0
	m.C1 = CFrame.identity
	m.Parent = part0
	return m
end

function EquipmentRig.Unequip(character: Model)
	local held = character:FindFirstChild(EquipmentRig.HeldName)
	if held then
		held:Destroy()
	end
	for _, d in character:GetDescendants() do
		if d:IsA("Motor6D") and (d.Name == "WeaponGrip" or d.Name == "OffhandGrip") then
			d:Destroy()
		end
	end
	local saya = character:FindFirstChild("EquippedWearable")
	if saya then
		saya:Destroy()
	end
end

function EquipmentRig.EquipHeld(character: Model, itemId: string): Model?
	EquipmentRig.Unequip(character)
	local prefab = EquipmentRig.GetPrefab(itemId)
	if prefab == nil then
		return nil
	end
	local model = prefab:Clone()
	model.Name = EquipmentRig.HeldName
	model:SetAttribute("ItemId", itemId)
	local handle = model.PrimaryPart or model:FindFirstChild("Handle") :: BasePart?
	if handle == nil then
		model:Destroy()
		return nil
	end
	local heldScale = model:GetAttribute("HeldScale")
	if type(heldScale) == "number" then
		model:ScaleTo(heldScale)
	end
	local attachName = model:GetAttribute("AttachPart")
	local part0 = character:FindFirstChild(if type(attachName) == "string" then attachName else "RightHand")
	if part0 == nil or not part0:IsA("BasePart") then
		model:Destroy()
		return nil
	end
	local c0 = model:GetAttribute("GripC0")
	cosmetic(model)

	-- offhand piece (gauntlets, twin hatchets)
	local offhand = model:FindFirstChild("Offhand")
	if offhand and offhand:IsA("Model") then
		local offRoot = offhand:FindFirstChild("OffhandHandle")
		local leftName = offhand:GetAttribute("AttachPart")
		local left = character:FindFirstChild(if type(leftName) == "string" then leftName else "LeftHand")
		if offRoot and offRoot:IsA("BasePart") and left and left:IsA("BasePart") then
			local offC0 = offhand:GetAttribute("GripC0")
			offhand.Name = "EquippedOffhand"
			grip(left, offRoot, "OffhandGrip", if typeof(offC0) == "CFrame" then offC0 else CFrame.identity)
		end
	end
	-- worn accessory such as the katana saya
	local wear = model:FindFirstChild("Saya")
	if wear and wear:IsA("Model") and wear.PrimaryPart then
		local partName = wear:GetAttribute("WearPart")
		local wearPart = character:FindFirstChild(if type(partName) == "string" then partName else "LowerTorso")
		local wc0 = wear:GetAttribute("WearC0")
		if wearPart and wearPart:IsA("BasePart") then
			for _, d in wear:GetDescendants() do
				if d:IsA("WeldConstraint") and (d.Part0 == handle or d.Part1 == handle) then
					d:Destroy()
				end
			end
			wear.Name = "EquippedWearable"
			wear.Parent = character
			wear:PivotTo(wearPart.CFrame * (if typeof(wc0) == "CFrame" then wc0 else CFrame.identity))
			local w = Instance.new("WeldConstraint")
			w.Part0 = wearPart
			w.Part1 = wear.PrimaryPart
			w.Parent = wear.PrimaryPart
		end
	end

	model.Parent = character
	grip(part0, handle, "WeaponGrip", if typeof(c0) == "CFrame" then c0 else CFrame.identity)
	return model
end

function EquipmentRig.GetHeld(character: Model): Model?
	local held = character:FindFirstChild(EquipmentRig.HeldName)
	if held and held:IsA("Model") then
		return held
	end
	return nil
end

function EquipmentRig.RemoveArmor(character: Model)
	local existing = character:FindFirstChild(EquipmentRig.ArmorName)
	if existing then
		existing:Destroy()
	end
end

function EquipmentRig.EquipArmor(character: Model, armorId: string): Model?
	EquipmentRig.RemoveArmor(character)
	local prefab = EquipmentRig.GetPrefab(armorId)
	if prefab == nil then
		return nil
	end
	local armor = prefab:Clone()
	armor.Name = EquipmentRig.ArmorName
	armor:SetAttribute("ItemId", armorId)
	cosmetic(armor)
	for _, pieceInst in armor:GetChildren() do
		if pieceInst:IsA("Model") then
			local piece = pieceInst :: Model
			local root = piece:FindFirstChild("Root")
			local partName = piece:GetAttribute("AttachPart")
			local bodyPart = character:FindFirstChild(if type(partName) == "string" then partName else "")
			if root and root:IsA("BasePart") and bodyPart and bodyPart:IsA("BasePart") then
				piece.PrimaryPart = root
				local ref = root:GetAttribute("ReferenceSize")
				if typeof(ref) == "Vector3" then
					local refSize = ref :: Vector3
					local scale = math.max(bodyPart.Size.X / refSize.X, bodyPart.Size.Z / refSize.Z)
					if scale > 0.2 and math.abs(scale - 1) > 0.02 then
						piece:ScaleTo(scale)
					end
				end
				piece:PivotTo(bodyPart.CFrame)
				local w = Instance.new("WeldConstraint")
				w.Part0 = bodyPart
				w.Part1 = root
				w.Parent = root
			else
				piece:Destroy()
			end
		end
	end
	armor.Parent = character
	return armor
end

function EquipmentRig.GetAttachment(model: Model, name: string): Attachment?
	local handle = model.PrimaryPart
	if handle then
		local a = handle:FindFirstChild(name, true)
		if a and a:IsA("Attachment") then
			return a
		end
	end
	local any = model:FindFirstChild(name, true)
	if any and any:IsA("Attachment") then
		return any
	end
	return nil
end

return EquipmentRig
