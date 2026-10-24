--!strict
-- Step 2: assemble every equipment prefab and VFX template into ReplicatedStorage.

local WeaponPrefabs = require(script.Parent.WeaponPrefabs)
local ArmorPrefabs = require(script.Parent.ArmorPrefabs)
local UtilityPrefabs = require(script.Parent.UtilityPrefabs)
local VFXTemplates = require(script.Parent.VFXTemplates)
local Step1 = require(script.Parent.Parent.Step1.CollisionAndFolders)

local Step2 = {}

function Step2.Run(tree: Step1.FolderTree): number
	WeaponPrefabs.BuildAll(tree.PrefabSub.Ranged_Weapon_Models, tree.PrefabSub.Melee_Weapon_Models, tree.RankedMelees)
	UtilityPrefabs.BuildAll(tree.PrefabSub.Utility_And_Healing_Models)
	ArmorPrefabs.BuildAll(tree.PrefabSub.Wearable_Armor_Models)
	VFXTemplates.BuildAll(tree.VFX, tree.VFXSub)
	local count = 0
	for _, d in tree.Prefabs:GetDescendants() do
		if d:IsA("Model") and d:GetAttribute("ItemId") ~= nil and d.Parent and d.Parent:IsA("Folder") then
			count += 1
		end
	end
	tree.Prefabs:SetAttribute("Built", true)
	tree.VFX:SetAttribute("Built", true)
	return count
end

return Step2
