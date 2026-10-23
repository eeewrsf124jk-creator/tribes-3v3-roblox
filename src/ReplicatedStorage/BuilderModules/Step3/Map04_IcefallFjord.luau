--!strict
-- Map 04: Icefall Fjord (glacier waterfall harbour). Point-symmetric 220 x 300 studs.
--   TeamSpawns  timber dock decks over icy inlets; a colossal icefall (Beam water curtains +
--               base mist particles) towers behind the west boundary
--   MidLane     a large wooden ship run aground at an angle; stairs on both beams lead to the
--               deck high ground, the mast and furled sail provide cover
--   SideLanes   red timber warehouses with doors at both ends, side window firing angles and a
--               gabled roof to slide down
--   Cover       blue ice rocks, fish barrels, rope coils

local GeometryKit = require(script.Parent.Parent.Kit.GeometryKit)
local MapKit = require(script.Parent.Parent.Kit.MapKit)

local K = GeometryKit
local RGB = Color3.fromRGB
local M = Enum.Material

local HALF_X = 110
local HALF_Z = 150

local SNOW = RGB(226, 234, 242)
local ROCK = RGB(96, 104, 112)
local DECK = RGB(128, 92, 58)
local HULL = RGB(92, 64, 40)
local RED = RGB(150, 40, 34)
local ICE = RGB(150, 210, 240)

local Map = {}

local function dock(sections: MapKit.MapSections, sign: number)
	local team = MapKit.TeamOf(sign)
	local folder = K.Folder(sections.TeamSpawns, team .. "_Dock")
	local function S(cf: CFrame): CFrame
		return MapKit.Sym(sign, cf)
	end
	-- icy inlet under the dock
	MapKit.WaterChannel(folder, "Inlet", S(CFrame.new(0, 0, -134)), Vector3.new(60, 1, 32), 3, RGB(70, 90, 100))
	-- shore on both sides of the inlet
	for _, x in { -70, 70 } do
		MapKit.Ground(folder, "InletShore", Vector3.new(80, 4, 32), S(CFrame.new(x, 0, -134)).Position, SNOW, M.Snow)
	end
	K.Part(folder, "DockDeck", Vector3.new(52, 1, 24), S(CFrame.new(0, 1.5, -134)), DECK, M.WoodPlanks)
	for x = -24, 24, 8 do
		for _, z in { -144, -134, -124 } do
			K.CylinderY(folder, "Piling", 7, 1.2, S(CFrame.new(x, -1.5, z)).Position, HULL, M.Wood)
		end
	end
	for _, x in { -26, 26 } do
		K.Part(folder, "DockRail", Vector3.new(0.5, 2.5, 24), S(CFrame.new(x, 3.25, -134)), HULL, M.Wood)
	end
	-- ramps down to the ice at the front edge
	-- ramps from the shore (z > -118) up to the dock lip, rising toward the dock (-Z)
	MapKit.Ramp(folder, "DockRampL", S(CFrame.new(-16, 0, -115)), Vector3.new(12, 2, 6), DECK, M.WoodPlanks)
	MapKit.Ramp(folder, "DockRampR", S(CFrame.new(16, 0, -115)), Vector3.new(12, 2, 6), DECK, M.WoodPlanks)
	K.Part(folder, "DockFront", Vector3.new(52, 2, 4), S(CFrame.new(0, 1, -120)), DECK, M.WoodPlanks)
	for i, x in { -8, 0, 8 } do
		MapKit.SpawnPad(folder, team, i, S(CFrame.lookAt(Vector3.new(x, 2, -136), Vector3.new(x, 2, 0))))
	end
	MapKit.Campfire(folder, S(CFrame.new(-18, 2, -140)))
	-- moored rowboat
	local boat = K.Model(folder, "Rowboat")
	K.Part(boat, "Hull", Vector3.new(4, 1.2, 10), S(CFrame.new(28, -0.6, -132)), HULL, M.WoodPlanks)
	K.Part(boat, "Bench", Vector3.new(4, 0.3, 1), S(CFrame.new(28, 0.1, -132)), DECK, M.Wood)
	MapKit.SpawnBarrier(folder, team, S(CFrame.new(0, 6, -116)), Vector3.new(52, 10, 1))
end

local function icefall(parent: Instance)
	local m = K.Model(parent, "IcefallBackdrop")
	local wall = K.Part(m, "GlacierWall", Vector3.new(40, 140, 340), CFrame.new(-HALF_X - 40, 70, 0), ICE, M.Glacier)
	for i = 0, 5 do
		local z = -125 + i * 50
		local top = K.Attachment(wall, "FallTop" .. i, CFrame.new(20.5, 68, z))
		local bottom = K.Attachment(wall, "FallBottom" .. i, CFrame.new(24, -66, z))
		K.BeamBetween(wall, top, bottom, RGB(220, 240, 255), 14, {
			Transparency = K.Seq(0.15, 0.35, 0.1),
			LightEmission = 0.35,
			Segments = 20,
			CurveSize0 = 6,
			CurveSize1 = -2,
			FaceCamera = true,
			Width1 = 20,
		}).Name = "WaterCurtain" .. i
		local mistPart = K.Part(m, "MistEmitter" .. i, Vector3.new(10, 2, 18), CFrame.new(-HALF_X - 14, 2, z), Color3.new(1, 1, 1), M.SmoothPlastic, {
			Transparency = 1,
			CanCollide = false,
			CanQuery = false,
		})
		K.Emitter(mistPart, {
			Name = "Mist",
			Texture = K.Textures.Smoke,
			Color = ColorSequence.new(RGB(235, 245, 255)),
			Size = K.Seq(8, 22),
			Transparency = K.Seq(0.4, 1),
			Lifetime = NumberRange.new(3, 5),
			Rate = 12,
			Speed = NumberRange.new(4, 9),
			SpreadAngle = Vector2.new(50, 50),
			Acceleration = Vector3.new(4, 1, 0),
			Shape = Enum.ParticleEmitterShape.Box,
		})
	end
	-- east cliffs
	K.Part(m, "EastCliff", Vector3.new(40, 60, 340), CFrame.new(HALF_X + 40, 30, 0), ROCK, M.Slate)
	K.Part(m, "EastCliffSnow", Vector3.new(40, 2, 340), CFrame.new(HALF_X + 40, 61, 0), SNOW, M.Snow)
end

local function shipwreck(mid: Folder)
	local ship = K.Model(mid, "GroundedShipwreck")
	-- local frame: keel along Z, deck 9 above ground; whole ship yawed 18 degrees and rolled 6
	local frame = CFrame.new(0, 0, 0) * CFrame.Angles(0, math.rad(18), 0) * CFrame.Angles(0, 0, math.rad(6))
	local L = 64
	K.Part(ship, "Keel", Vector3.new(4, 2, L - 8), frame * CFrame.new(0, 1, 0), HULL, M.WoodPlanks)
	for _, side in { -1, 1 } do
		for i = 0, 2 do
			local y = 2.4 + i * 2.6
			local x = side * (5.4 + i * 1.1)
			K.Part(ship, "Strake", Vector3.new(0.8, 2.8, L - 10 + i * 2), frame * CFrame.new(x, y, 0) * CFrame.Angles(0, 0, side * math.rad(-14)), if i == 1 then RGB(70, 48, 30) else HULL, M.WoodPlanks)
		end
		-- gunwale cap
		-- gunwale caps with a boarding gap at z 2..10 where the stairs arrive
		K.Part(ship, "Gunwale", Vector3.new(1, 0.6, 32), frame * CFrame.new(side * 8, 10.4, -14), DECK, M.Wood)
		K.Part(ship, "GunwaleAft", Vector3.new(1, 0.6, 20), frame * CFrame.new(side * 8, 10.4, 20), DECK, M.Wood)
		-- broken plank hole on one side (cover gap)
		if side == 1 then
			K.Part(ship, "HullPatch", Vector3.new(0.9, 3, 6), frame * CFrame.new(side * 6.6, 5, -10), RGB(60, 40, 26), M.WoodPlanks)
		end
	end
	-- bow: converging edge wedges
	for _, side in { -1, 1 } do
		-- wedge laid on its side (extrusion vertical) so the triangle tapers in plan to the stem
		K.Wedge(ship, "Bow", Vector3.new(9, 8, 8), frame * CFrame.new(side * 4, 5.5, -32) * CFrame.Angles(0, 0, -side * math.rad(90)), HULL, M.WoodPlanks)
	end
	K.Part(ship, "Bowsprit", Vector3.new(1, 1, 14), frame * CFrame.new(0, 11, -L / 2 - 8) * CFrame.Angles(math.rad(14), 0, 0), DECK, M.Wood)
	-- stern transom + cabin
	K.Part(ship, "Transom", Vector3.new(16, 10, 1.2), frame * CFrame.new(0, 5.5, L / 2 - 2), HULL, M.WoodPlanks)
	K.Part(ship, "SternCabin", Vector3.new(14, 6, 10), frame * CFrame.new(0, 13, L / 2 - 8), RGB(110, 76, 48), M.WoodPlanks)
	K.Part(ship, "CabinRoof", Vector3.new(15, 0.6, 11), frame * CFrame.new(0, 16.3, L / 2 - 8), RGB(80, 56, 36), M.Wood)
	-- deck in two pieces with a smashed gap amidships
	K.Part(ship, "DeckFore", Vector3.new(15, 1, 26), frame * CFrame.new(0, 9.5, -16), DECK, M.WoodPlanks)
	K.Part(ship, "DeckAft", Vector3.new(15, 1, 22), frame * CFrame.new(0, 9.5, 17), DECK, M.WoodPlanks)
	K.Part(ship, "BrokenBeam", Vector3.new(15, 0.6, 0.8), frame * CFrame.new(0, 9.3, 1.5) * CFrame.Angles(math.rad(20), 0, 0), RGB(70, 48, 30), M.Wood)
	-- mast, yard, torn sail and rigging
	local mast = K.CylinderY(ship, "Mast", 30, 1.8, (frame * CFrame.new(0, 25, -8)).Position, RGB(100, 70, 44), M.Wood)
	K.Cylinder(ship, "Yard", 18, 0.8, frame * CFrame.new(0, 32, -8), RGB(100, 70, 44), M.Wood)
	local sail = K.Part(ship, "TornSail", Vector3.new(16, 10, 0.15), frame * CFrame.new(0, 26.5, -7.4) * CFrame.Angles(math.rad(-6), 0, 0), RGB(232, 226, 210), M.Fabric)
	sail.CastShadow = true
	K.Part(ship, "MastCoverBox", Vector3.new(3, 4, 3), frame * CFrame.new(0, 12, -8), DECK, M.WoodPlanks)
	local mastTop = K.Attachment(mast, "RigTop", CFrame.new(15, 0, 0))
	for i, z in { -14, 14 } do
		local anchor = K.Attachment(ship:FindFirstChild("Gunwale") :: BasePart, "RigAnchor" .. i, CFrame.new(0, 0, z))
		K.BeamBetween(mast, mastTop, anchor, RGB(170, 150, 110), 0.15, { Segments = 1 }).Name = "Rigging" .. i
	end
	-- boarding stairs on both beams (port / starboard), built in the ship frame
	-- stairs stand level on the ice (yaw-only frame) and reach the rolled deck edge height
	local yawFrame = CFrame.Angles(0, math.rad(18), 0)
	for _, side in { -1, 1 } do
		local topY = (frame * CFrame.new(side * 9.5, 10, 6)).Position.Y
		MapKit.Stairs(ship, "BoardingStairs", yawFrame * CFrame.new(side * 23.5, 0, 6) * CFrame.Angles(0, side * math.rad(90), 0), 5, topY, 13, 14, DECK, M.WoodPlanks)
		K.Part(ship, "BoardingLanding", Vector3.new(4, 1, 5), yawFrame * CFrame.new(side * 8.5, topY - 0.5, 6), DECK, M.WoodPlanks)
	end
	ship:SetAttribute("DeckHeight", 10)
	-- ice heaped around the hull
	for i, p in { Vector3.new(-12, 0, -20), Vector3.new(13, 0, 18), Vector3.new(-10, 0, 26), Vector3.new(12, 0, -28) } do
		MapKit.Rock(mid, p, 5, ICE, M.Glacier, 500 + i)
	end
end

local function warehouse(parent: Instance, name: string, cf: CFrame)
	local m = K.Model(parent, name)
	local W, L, H = 26, 44, 12
	for _, z in { -L / 2, L / 2 } do
		MapKit.Wall(m, "EndWall", cf * CFrame.new(0, 0, z), W, H, 1, { { Offset = 0, Width = 8, Height = 9 } }, RED, M.WoodPlanks)
	end
	for _, x in { -W / 2, W / 2 } do
		MapKit.Wall(m, "SideWall", cf * CFrame.new(x, 0, 0) * CFrame.Angles(0, math.rad(90), 0), L, H, 1, {
			{ Offset = -13, Width = 4, Height = 3, Sill = 4 },
			{ Offset = 0, Width = 4, Height = 3, Sill = 4 },
			{ Offset = 13, Width = 4, Height = 3, Sill = 4 },
		}, RED, M.WoodPlanks)
		-- white window trims
		for _, z in { -13, 0, 13 } do
			K.Part(m, "WindowTrim", Vector3.new(1.2, 0.3, 4.6), cf * CFrame.new(x, 4, z), Color3.new(0.95, 0.95, 0.95), M.Wood)
		end
	end
	-- corner posts
	for _, x in { -W / 2, W / 2 } do
		for _, z in { -L / 2, L / 2 } do
			K.Part(m, "CornerPost", Vector3.new(1.4, H, 1.4), cf * CFrame.new(x, H / 2, z), Color3.new(0.95, 0.95, 0.95), M.Wood)
		end
	end
	K.Part(m, "Floor", Vector3.new(W, 0.3, L), cf * CFrame.new(0, 0.15, 0), RGB(110, 80, 52), M.WoodPlanks)
	-- gable roof along Z: two slopes (rise 6 over 14, ~23 degrees) good for slide-jumps
	K.Wedge(m, "RoofEast", Vector3.new(L + 2, 6, W / 2 + 1), cf * CFrame.new((W / 2 + 1) / 2, H + 3, 0) * CFrame.Angles(0, math.rad(-90), 0), RGB(60, 62, 66), M.Slate)
	K.Wedge(m, "RoofWest", Vector3.new(L + 2, 6, W / 2 + 1), cf * CFrame.new(-(W / 2 + 1) / 2, H + 3, 0) * CFrame.Angles(0, math.rad(90), 0), RGB(60, 62, 66), M.Slate)
	K.Part(m, "RoofSnow", Vector3.new(4, 0.6, L + 2), cf * CFrame.new(0, H + 6, 0), SNOW, M.Snow)
	-- interior crates and an access stack on the outside to reach the roof
	MapKit.Crate(m, cf * CFrame.new(-6, 0, -8), 4)
	MapKit.Crate(m, cf * CFrame.new(5, 0, 10) * CFrame.Angles(0, math.rad(20), 0), 4)
	MapKit.Crate(m, cf * CFrame.new(W / 2 + 3, 0, -16), 4)
	MapKit.Crate(m, cf * CFrame.new(W / 2 + 3, 0, -12), 4)
	MapKit.Crate(m, cf * CFrame.new(W / 2 + 3, 4, -12), 4)
	MapKit.Crate(m, cf * CFrame.new(W / 2 + 3, 8, -12), 4)
	return m
end

local function barrel(parent: Instance, pos: Vector3)
	local m = K.Model(parent, "FishBarrel")
	K.CylinderY(m, "Body", 4, 3, pos + Vector3.new(0, 2, 0), RGB(130, 92, 56), M.Wood)
	for _, y in { 0.6, 2, 3.4 } do
		K.CylinderY(m, "Hoop", 0.25, 3.1, pos + Vector3.new(0, y, 0), RGB(80, 82, 88), M.Metal)
	end
	local fish = K.Part(m, "FishTail", Vector3.new(0.1, 0.8, 0.6), CFrame.new(pos + Vector3.new(0.4, 4.3, 0)) * CFrame.Angles(0, 0, math.rad(20)), RGB(150, 170, 180), M.SmoothPlastic)
	fish.Reflectance = 0.3
	m:SetAttribute("CoverHeight", 4)
end

local function ropeCoil(parent: Instance, pos: Vector3)
	for i = 0, 3 do
		K.CylinderY(parent, "RopeCoil", 0.35, 3 - i * 0.2, pos + Vector3.new(0, 0.18 + i * 0.35, 0), RGB(178, 150, 104), M.Fabric)
	end
end

function Map.Build(): Model
	local sections = MapKit.NewMap("Map_04_IcefallFjord", "Icefall Fjord", "MidLane_GroundedShipwreck", "SideLanes_RedWarehouses")
	local model = sections.Model
	MapKit.ApplyLighting(model, 11, RGB(140, 160, 185), RGB(200, 220, 235), 600, 0.45)
	model:SetAttribute("Theme", "Fjord")

	-- main shore between the two dock inlets (z -118 .. 118); inlet shores are built per dock
	MapKit.Ground(model, "FrozenShore", Vector3.new(HALF_X * 2, 4, 236), Vector3.zero, SNOW, M.Snow)
	-- slate outcrops along the edges
	for i = -5, 5 do
		for _, x in { -HALF_X + 6, HALF_X - 6 } do
			MapKit.Rock(model, Vector3.new(x, 0, i * 26), 8, ROCK, M.Slate, 700 + i * 3 + (if x < 0 then 1 else 2))
		end
	end

	icefall(model)
	shipwreck(sections.MidLane)
	for _, sign in { -1, 1 } do
		dock(sections, sign)
	end
	warehouse(sections.SideLanes, "RedWarehouse_West", CFrame.new(-66, 0, 0) * CFrame.Angles(0, math.pi, 0))
	warehouse(sections.SideLanes, "RedWarehouse_East", CFrame.new(66, 0, 0))

	local iceRocks: { MapKit.Placement } = {
		{ P = Vector3.new(-30, 0, -66), Yaw = 0, Len = 6 },
		{ P = Vector3.new(34, 0, -78), Yaw = 0, Len = 5 },
		{ P = Vector3.new(-12, 0, -96), Yaw = 0, Len = 4 },
		{ P = Vector3.new(-80, 0, -50), Yaw = 0, Len = 6 },
		{ P = Vector3.new(18, 0, -48), Yaw = 0, Len = 4 },
	}
	local barrels = { Vector3.new(-40, 0, -100), Vector3.new(-37, 0, -102), Vector3.new(42, 0, -44), Vector3.new(-6, 0, -70), Vector3.new(80, 0, -96) }
	local coils = { Vector3.new(-34, 0, -98), Vector3.new(46, 0, -40), Vector3.new(8, 0, -104) }
	for _, sign in { -1, 1 } do
		for i, r in iceRocks do
			MapKit.Rock(sections.Cover, MapKit.SymPos(sign, r.P), r.Len or 5, ICE, M.Glacier, 800 + i + (if sign > 0 then 50 else 0))
		end
		for _, p in barrels do
			barrel(sections.Cover, MapKit.SymPos(sign, p))
		end
		for _, p in coils do
			ropeCoil(sections.Cover, MapKit.SymPos(sign, p))
		end
	end

	MapKit.FinalizeMap(sections, HALF_X, HALF_Z, 180)
	return model
end

return Map
