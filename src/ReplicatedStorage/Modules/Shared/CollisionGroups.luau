--!strict
-- The 6-group PhysicsService collision matrix.
--
--                     MapGeo  MoveBox  Hitbox  Proj  Shields  Ragdoll
--   MapGeometry         x       x        x      x      x        x
--   PlayerMovementBox   x       .        .      .      x        .
--   HitboxParts         x       .        .      x      .        .
--   Projectiles         x       .        x      .      x        .
--   DestructibleShields x       x        .      x      .        .
--   RagdollLimbs        x       .        .      .      .        .

local PhysicsService = game:GetService("PhysicsService")

local CollisionGroups = {
	MapGeometry = "MapGeometry",
	PlayerMovementBox = "PlayerMovementBox",
	HitboxParts = "HitboxParts",
	Projectiles = "Projectiles",
	DestructibleShields = "DestructibleShields",
	RagdollLimbs = "RagdollLimbs",
}

CollisionGroups.Ordered = {
	CollisionGroups.MapGeometry,
	CollisionGroups.PlayerMovementBox,
	CollisionGroups.HitboxParts,
	CollisionGroups.Projectiles,
	CollisionGroups.DestructibleShields,
	CollisionGroups.RagdollLimbs,
}

local Collides: { [string]: { [string]: boolean } } = {
	MapGeometry = {
		MapGeometry = true,
		PlayerMovementBox = true,
		HitboxParts = true,
		Projectiles = true,
		DestructibleShields = true,
		RagdollLimbs = true,
	},
	PlayerMovementBox = { DestructibleShields = true },
	HitboxParts = { Projectiles = true },
	Projectiles = { DestructibleShields = true },
	DestructibleShields = {},
	RagdollLimbs = {},
}

CollisionGroups.Matrix = Collides

local function shouldCollide(a: string, b: string): boolean
	local ra = Collides[a]
	local rb = Collides[b]
	return (ra ~= nil and ra[b] == true) or (rb ~= nil and rb[a] == true)
end

CollisionGroups.ShouldCollide = shouldCollide

-- Register all groups and apply the matrix. Safe to call repeatedly (Studio command bar or runtime).
function CollisionGroups.Setup()
	for _, name in CollisionGroups.Ordered do
		if not PhysicsService:IsCollisionGroupRegistered(name) then
			PhysicsService:RegisterCollisionGroup(name)
		end
	end
	for i, a in CollisionGroups.Ordered do
		for j = i, #CollisionGroups.Ordered do
			local b = CollisionGroups.Ordered[j]
			PhysicsService:CollisionGroupSetCollidable(a, b, shouldCollide(a, b))
		end
	end
end

function CollisionGroups.AssignModel(root: Instance, group: string)
	if root:IsA("BasePart") then
		root.CollisionGroup = group
	end
	for _, d in root:GetDescendants() do
		if d:IsA("BasePart") then
			d.CollisionGroup = group
		end
	end
end

-- Character setup: HumanoidRootPart is the movement capsule, every limb is a query-only hitbox.
function CollisionGroups.AssignCharacter(character: Model)
	for _, d in character:GetDescendants() do
		if d:IsA("BasePart") then
			if d.Name == "HumanoidRootPart" then
				d.CollisionGroup = CollisionGroups.PlayerMovementBox
			elseif d:GetAttribute("ShieldCollider") == true then
				d.CollisionGroup = CollisionGroups.DestructibleShields
			elseif d.Parent ~= character then
				-- accessories and equipped prefabs: cosmetic only
				d.CollisionGroup = CollisionGroups.HitboxParts
				d.CanCollide = false
				d.CanQuery = false
				d.CanTouch = false
				d.Massless = true
			else
				d.CollisionGroup = CollisionGroups.HitboxParts
				d.CanCollide = false
				d.CanQuery = true
			end
		end
	end
end

return CollisionGroups
