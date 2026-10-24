-- Run from the repository root:  lune run tests/run.luau
-- Exercises the engine-independent modules and checks balance values against the reference
-- numbers collected in replica/thinktank/report.md.

local process = require("@lune/process")
local roblox = require("@lune/roblox")
local H = require("./harness")

local Vector3 = roblox.Vector3
local MODULES = "src/ReplicatedStorage/Modules"

local DB = H.Load(MODULES .. "/Config/EquipmentDatabase.luau")
local GameConfig = H.Load(MODULES .. "/Config/GameConfig.luau")
local Validator = H.Load(MODULES .. "/Shared/LoadoutBudgetValidator.luau")
local Ballistics = H.Load(MODULES .. "/Shared/BallisticsEngine.luau")
local Scaling = H.Load(MODULES .. "/Config/UpgradeScalingMath.luau")
local Monetization = H.Load(MODULES .. "/Config/MonetizationCatalog.luau")

local function loadout(slots: { string }, armor: string?, arrows: number?, bullets: number?, fire: number?)
	return {
		Name = "Test",
		Slots = slots,
		Armor = armor,
		Ammo = { Arrows = arrows or 0, Bullets = bullets or 0, FireArrows = fire or 0 },
	}
end

print("Match rules")
H.Test("first to three rounds, 3v3", function()
	H.Eq(GameConfig.RoundsToWin, 3, "RoundsToWin")
	H.Eq(GameConfig.TeamSize, 3, "TeamSize")
end)
H.Test("12-point budget, 5 saved presets", function()
	H.Eq(DB.MaxPoints, 12, "MaxPoints")
	H.Eq(#Validator.DefaultPresets(), 5, "preset count")
end)

print("Reference point costs")
local expectedCosts = {
	LeatherArmor = 2,
	IronArmor = 4,
	DiamondArmor = 6,
	DiamondDagger = 2,
	IronSword = 3,
	Hammer = 3,
	WoodBow = 3,
	Crossbow = 4,
	Musket = 4,
	Blunderbuss = 4,
	Sling = 1,
	ThrowingKnives = 1,
	Bandage = 1,
	SmokeBomb = 1,
	SnapTrap = 1,
	GoldenApple = 3,
}
for id, cost in expectedCosts do
	H.Test(id .. " costs " .. cost, function()
		local spec = DB.Get(id)
		H.True(spec ~= nil, "missing item " .. id)
		H.Eq(spec.Cost, cost, id .. ".Cost")
	end)
end

print("Reference damage")
H.Test("crossbow 45-50 body, 86-90 head", function()
	local c = DB.Get("Crossbow")
	H.True(c.BaseDmg >= 45 and c.BaseDmg <= 50, "body " .. c.BaseDmg)
	local head = c.BaseDmg * c.HeadMult
	H.True(head >= 86 and head <= 90, "head " .. head)
end)
H.Test("sling 26-30 per hit", function()
	local s = DB.Get("Sling")
	H.True(s.BaseDmg >= 26 and s.BaseDmg <= 30, "sling " .. s.BaseDmg)
end)
H.Test("throwing knives ~30 damage, five per round", function()
	local k = DB.Get("ThrowingKnives")
	H.Eq(k.BaseDmg, 30, "knife dmg")
	H.Eq(k.MaxStack, 5, "knife stack")
end)
H.Test("blunderbuss: lethal point blank, ~6 per pellet at mid range", function()
	local b = DB.Get("Blunderbuss")
	H.True(b.PelletCount * b.PelletDmg >= 100, "point blank total " .. b.PelletCount * b.PelletDmg)
	local mid = b.PelletDmg * Ballistics.Falloff(60, b.FalloffStart)
	H.True(mid >= 4 and mid <= 7, "mid-range pellet " .. mid)
end)
H.Test("diamond dagger backstab is lethal", function()
	H.True(DB.BackstabDamage >= GameConfig.Combat.MaxHealth * 2, "backstab " .. DB.BackstabDamage)
end)

print("Ammo bundles")
H.Test("12 arrows per point, capped at 36", function()
	H.Eq(DB.AmmoBundles.Arrows, 12)
	H.Eq(Validator.CountPoints(loadout({ "WoodBow" }, nil, 3)), 6, "bow + 3 bundles")
	H.True(Validator.Validate(loadout({ "WoodBow" }, nil, 3)).Ok, "36 arrows allowed")
	H.True(not Validator.Validate(loadout({ "WoodBow" }, nil, 4)).Ok, "48 arrows rejected")
end)
H.Test("fire arrows cost 2 points per 6", function()
	H.Eq(DB.AmmoBundles.FireArrows, 6)
	H.Eq(Validator.CountPoints(loadout({ "WoodBow" }, nil, 0, 0, 1)), 5, "bow + 1 fire bundle")
end)
H.Test("bullets 6 per point, up to 12", function()
	H.Eq(Validator.CountPoints(loadout({ "Musket" }, nil, 0, 2)), 6)
	H.True(not Validator.Validate(loadout({ "Musket" }, nil, 0, 3)).Ok, "18 bullets rejected")
end)
H.Test("bows need arrows, guns need bullets", function()
	H.True(not Validator.Validate(loadout({ "Crossbow" })).Ok, "bow without arrows")
	H.True(not Validator.Validate(loadout({ "Flintlock" })).Ok, "gun without bullets")
end)

print("Loadout validation")
H.Test("every default preset is legal", function()
	for _, preset in Validator.DefaultPresets() do
		local r = Validator.Validate(preset)
		H.True(r.Ok, preset.Name .. ": " .. table.concat(r.Errors, ", ") .. " (" .. r.Points .. " pts)")
		H.True(r.Points <= 12, preset.Name .. " over budget")
	end
end)
H.Test("community starter build fits the budget", function()
	-- bow 3 + dagger 2 + knives 1 + bandage 1 + snap trap 1 + leather 2 + 12 arrows 1
	local l = loadout({ "WoodBow", "DiamondDagger", "ThrowingKnives", "Bandage", "SnapTrap" }, "LeatherArmor", 1)
	H.Eq(Validator.CountPoints(l), 11, "points")
	H.True(Validator.Validate(l).Ok, "valid")
end)
H.Test("over budget is rejected", function()
	local r = Validator.Validate(loadout({ "Crossbow", "Hammer" }, "DiamondArmor", 1))
	H.True(not r.Ok, "14 points accepted")
	H.Eq(r.Points, 14)
end)
H.Test("duplicates, armor in a weapon slot and locked items are rejected", function()
	H.True(not Validator.Validate(loadout({ "IronSword", "IronSword" })).Ok, "duplicate")
	H.True(not Validator.Validate(loadout({ "IronArmor" })).Ok, "armor in slot")
	H.True(not Validator.Validate(loadout({ "Musket" }, nil, 0, 1), { Musket = 0 }).Ok, "locked")
end)
H.Test("sanitize drops junk from the network", function()
	H.Eq(Validator.Sanitize("nope"), nil, "string")
	local clean = Validator.Sanitize({ Name = "x", Slots = { "IronSword", 5 }, Ammo = {} })
	H.True(clean == nil or #clean.Slots <= 1, "non-string slot kept")
end)

print("Equipment table integrity")
H.Test("every item has id, name, category and a positive cost", function()
	for id, spec in DB.Items do
		H.Eq(spec.Id, id, "Id")
		H.True(type(spec.DisplayName) == "string" and #spec.DisplayName > 0, id .. " name")
		H.True(spec.Cost >= 1 and spec.Cost <= 6, id .. " cost " .. spec.Cost)
	end
end)
H.Test("Order lists every item exactly once", function()
	local seen = {}
	for _, id in DB.Order do
		H.True(DB.Items[id] ~= nil, "unknown " .. id)
		H.True(not seen[id], "duplicate " .. id)
		seen[id] = true
	end
	for id in DB.Items do
		H.True(seen[id], "not ordered " .. id)
	end
end)

print("Ballistics")
H.Test("parabola matches the closed form", function()
	local p0, v0 = Vector3.new(0, 10, 0), Vector3.new(50, 30, 0)
	local g = Ballistics.GravityVector(1)
	local p = Ballistics.PositionAt(p0, v0, g, 1.5)
	H.Near(p.X, 75, 1e-3, "x") -- Vector3 is float32
	H.Near(p.Y, 10 + 45 + 0.5 * g.Y * 2.25, 1e-3, "y")
end)
H.Test("reflection keeps speed and flips the normal component", function()
	local r = Ballistics.Reflect(Vector3.new(3, -4, 0), Vector3.new(0, 1, 0))
	H.Near(r.X, 3, 1e-5, "x")
	H.Near(r.Y, 4, 1e-5, "y")
end)
H.Test("pellet pattern is deterministic and stays inside the cone", function()
	local dir = Vector3.new(0, 0, -1)
	local a = Ballistics.PelletDirections(dir, 9, 8, 1234)
	local b = Ballistics.PelletDirections(dir, 9, 8, 1234)
	H.Eq(#a, 8, "count")
	local cosMax = math.cos(math.rad(9))
	for i = 1, 8 do
		H.Near((a[i] - b[i]).Magnitude, 0, 1e-6, "pellet " .. i .. " differs")
		H.True(a[i]:Dot(dir) >= cosMax - 1e-5, "pellet " .. i .. " outside cone")
	end
end)
H.Test("falloff is 1 before start, linear to the floor after", function()
	H.Eq(Ballistics.Falloff(10, 18), 1)
	H.Near(Ballistics.Falloff(18 + 13.5, 18), 0.675, 1e-9, "midpoint")
	H.Near(Ballistics.Falloff(500, 18), 0.35, 1e-9, "floor")
end)

print("Progression and store")
H.Test("shard costs double each level, max level 10", function()
	H.Eq(Scaling.ShardsForNextLevel(1), 10)
	H.Eq(Scaling.ShardsForNextLevel(2), 20)
	H.Eq(Scaling.ShardsForNextLevel(10), nil)
	H.Eq(Scaling.TotalShardsToReach(3), 30)
	H.Near(Scaling.StatMultiplier(10), 1.04 ^ 9, 1e-9, "Lv10 multiplier")
end)
H.Test("Golden Drop costs 9 Robux", function()
	local found = false
	for _, p in Monetization.Products do
		if p.Kind == "GoldenDrop" then
			H.Eq(p.PriceRobux, 9, "Golden Drop price")
			found = true
		end
	end
	H.True(found, "Golden Drop product missing")
end)

process.exit(if H.Summary() then 0 else 1)
