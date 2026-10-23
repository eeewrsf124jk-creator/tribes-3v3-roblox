--!strict
-- Validates a 12-point loadout: MaxPoints <= 12, MaxSlots <= 6, ammo bundles
-- (1 PT = 12 arrows / 6 bullets / 6 fire arrows), single armor, no duplicate items,
-- ammo must match a weapon, and every item must be unlocked when an ownership table is given.

local Types = require(script.Parent.Types)
local EquipmentDatabase = require(script.Parent.Parent.Config.EquipmentDatabase)

type Loadout = Types.Loadout
type ValidationResult = Types.ValidationResult

local LoadoutBudgetValidator = {}

LoadoutBudgetValidator.MaxPoints = EquipmentDatabase.MaxPoints
LoadoutBudgetValidator.MaxSlots = EquipmentDatabase.MaxSlots
LoadoutBudgetValidator.MaxAmmoBundles = 6

function LoadoutBudgetValidator.EmptyLoadout(name: string?): Loadout
	return {
		Name = name or "Preset",
		Slots = {},
		Armor = nil,
		Ammo = { Arrows = 0, Bullets = 0, FireArrows = 0 },
	}
end

function LoadoutBudgetValidator.CountPoints(loadout: Loadout): number
	local points = 0
	for _, id in loadout.Slots do
		local spec = EquipmentDatabase.Get(id)
		if spec then
			points += spec.Cost
		end
	end
	if loadout.Armor then
		local armor = EquipmentDatabase.Get(loadout.Armor)
		if armor then
			points += armor.Cost
		end
	end
	points += loadout.Ammo.Arrows + loadout.Ammo.Bullets + loadout.Ammo.FireArrows
	return points
end

local function hasSubType(loadout: Loadout, subType: string): boolean
	for _, id in loadout.Slots do
		local spec = EquipmentDatabase.Get(id)
		if spec and spec.SubType == subType then
			return true
		end
	end
	return false
end

function LoadoutBudgetValidator.Validate(loadout: Loadout, unlocked: { [string]: number }?): ValidationResult
	local errors: { string } = {}
	local seen: { [string]: boolean } = {}

	if #loadout.Slots > LoadoutBudgetValidator.MaxSlots then
		table.insert(errors, string.format("Too many slots (%d/%d)", #loadout.Slots, LoadoutBudgetValidator.MaxSlots))
	end

	for _, id in loadout.Slots do
		local spec = EquipmentDatabase.Get(id)
		if spec == nil then
			table.insert(errors, "Unknown item: " .. tostring(id))
		elseif spec.Category == "ARMOR" then
			table.insert(errors, spec.DisplayName .. " must go in the armor slot")
		elseif seen[id] then
			table.insert(errors, spec.DisplayName .. " is equipped twice")
		else
			seen[id] = true
			if unlocked and (unlocked[id] or 0) < 1 then
				table.insert(errors, spec.DisplayName .. " is locked")
			end
		end
	end

	if loadout.Armor ~= nil then
		local armor = EquipmentDatabase.Get(loadout.Armor)
		if armor == nil or armor.Category ~= "ARMOR" then
			table.insert(errors, "Invalid armor")
		elseif unlocked and (unlocked[loadout.Armor] or 0) < 1 then
			table.insert(errors, armor.DisplayName .. " is locked")
		end
	end

	local ammo = loadout.Ammo
	local ammoKinds: { { Kind: string, Count: number } } = {
		{ Kind = "Arrows", Count = ammo.Arrows },
		{ Kind = "Bullets", Count = ammo.Bullets },
		{ Kind = "FireArrows", Count = ammo.FireArrows },
	}
	for _, entry in ammoKinds do
		local kind, count = entry.Kind, entry.Count
		if count < 0 or count ~= math.floor(count) then
			table.insert(errors, "Invalid " .. kind .. " bundle count")
		elseif count > LoadoutBudgetValidator.MaxAmmoBundles then
			table.insert(errors, "Too many " .. kind .. " bundles")
		end
	end

	local hasBow = hasSubType(loadout, "BOW")
	local hasGun = hasSubType(loadout, "GUN")
	if hasBow and ammo.Arrows + ammo.FireArrows < 1 then
		table.insert(errors, "Bows need at least 1 arrow bundle")
	end
	if hasGun and ammo.Bullets < 1 then
		table.insert(errors, "Guns need at least 1 bullet bundle")
	end
	if not hasBow and (ammo.Arrows > 0 or ammo.FireArrows > 0) then
		table.insert(errors, "Arrows bought without a bow")
	end
	if not hasGun and ammo.Bullets > 0 then
		table.insert(errors, "Bullets bought without a gun")
	end

	local points = LoadoutBudgetValidator.CountPoints(loadout)
	if points > LoadoutBudgetValidator.MaxPoints then
		table.insert(errors, string.format("Over budget (%d/%d PT)", points, LoadoutBudgetValidator.MaxPoints))
	end

	return {
		Ok = #errors == 0,
		Points = points,
		Slots = #loadout.Slots,
		Errors = errors,
	}
end

-- Convert purchased bundles into round counts.
function LoadoutBudgetValidator.AmmoCounts(loadout: Loadout): { Arrows: number, Bullets: number, FireArrows: number }
	return {
		Arrows = loadout.Ammo.Arrows * EquipmentDatabase.AmmoBundles.Arrows,
		Bullets = loadout.Ammo.Bullets * EquipmentDatabase.AmmoBundles.Bullets,
		FireArrows = loadout.Ammo.FireArrows * EquipmentDatabase.AmmoBundles.FireArrows,
	}
end

-- Coerce untrusted network data into a Loadout (or nil when the shape is wrong).
function LoadoutBudgetValidator.Sanitize(raw: any): Loadout?
	if type(raw) ~= "table" then
		return nil
	end
	local slots: { string } = {}
	if type(raw.Slots) == "table" then
		for i = 1, math.min(#raw.Slots, 10) do
			local id = raw.Slots[i]
			if type(id) == "string" and #id <= 32 then
				table.insert(slots, id)
			end
		end
	end
	local armor: string? = nil
	if type(raw.Armor) == "string" and #raw.Armor <= 32 then
		armor = raw.Armor
	end
	local ammoRaw = if type(raw.Ammo) == "table" then raw.Ammo else {}
	local function num(v: any): number
		if type(v) == "number" and v == v then
			return math.clamp(math.floor(v), 0, 99)
		end
		return 0
	end
	local name = if type(raw.Name) == "string" then string.sub(raw.Name, 1, 20) else "Preset"
	return {
		Name = name,
		Slots = slots,
		Armor = armor,
		Ammo = { Arrows = num(ammoRaw.Arrows), Bullets = num(ammoRaw.Bullets), FireArrows = num(ammoRaw.FireArrows) },
	}
end

-- Starter presets every new profile receives (all valid for starter-only ownership).
function LoadoutBudgetValidator.DefaultPresets(): { Loadout }
	return {
		{
			Name = "Skirmisher",
			Slots = { "ThrowingKnives", "IronSword", "Bandage", "SmokeBomb" },
			Armor = "LeatherArmor",
			Ammo = { Arrows = 0, Bullets = 0, FireArrows = 0 },
		},
		{
			Name = "Slinger",
			Slots = { "Sling", "Spear", "Apple", "SnapTrap" },
			Armor = "LeatherArmor",
			Ammo = { Arrows = 0, Bullets = 0, FireArrows = 0 },
		},
		{
			Name = "Bruiser",
			Slots = { "Hammer", "Shield", "Bandage", "Palisade" },
			Armor = "IronArmor",
			Ammo = { Arrows = 0, Bullets = 0, FireArrows = 0 },
		},
		{
			Name = "Assassin",
			Slots = { "DiamondDagger", "Bolas", "SmokeBomb", "Apple", "Bandage" },
			Armor = "LeatherArmor",
			Ammo = { Arrows = 0, Bullets = 0, FireArrows = 0 },
		},
		{
			Name = "Support",
			Slots = { "Chakram", "IronSword", "HealingFlask", "WarHorn", "Bandage" },
			Armor = "LeatherArmor",
			Ammo = { Arrows = 0, Bullets = 0, FireArrows = 0 },
		},
	}
end

return LoadoutBudgetValidator
