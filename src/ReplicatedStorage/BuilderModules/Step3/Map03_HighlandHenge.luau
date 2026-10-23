--!strict
-- Map 03: Highland Henge (stone circle ruins on a grassy plateau). 220 x 300 studs.
--   TeamSpawns  thatched cottages; stacked crates on the flank let players climb onto the roof
--               (high ground for Headhunter / Musket)
--   MidLane     8 monolith pillars (14 studs) in a ring with lintel capstones: jiggle-peek zone
--   SideLanes   west: shallow coastal water channel (splash zone) / east: low dry-stone wall
--               (3 studs, slide cover). Both run the full length so each team gets the same lanes.
--   Cover       mossy boulders, wooden carts, hay bales

local GeometryKit = require(script.Parent.Parent.Kit.GeometryKit)
local MapKit = require(script.Parent.Parent.Kit.MapKit)

local K = GeometryKit
local RGB = Color3.fromRGB
local M = Enum.Material

local HALF_X = 110
local HALF_Z = 150

local GRASS = RGB(96, 140, 70)
local STONE = RGB(128, 130, 126)
local MOSS = RGB(80, 120, 60)
local PLASTER = RGB(232, 226, 210)
local TIMBER = RGB(70, 50, 34)
local THATCH = RGB(196, 162, 92)
local CRATE = 4

local Map = {}

local function cottage(sections: MapKit.MapSections, sign: number)
	local team = MapKit.TeamOf(sign)
	local folder = K.Folder(sections.TeamSpawns, team .. "_Cottage")
	local function S(cf: CFrame): CFrame
		return MapKit.Sym(sign, cf)
	end
	local base = S(CFrame.new(0, 0, -138))
	local W, D, H = 24, 14, 9
	-- walls: front (toward mid) with a wide door, back plain, gable ends with windows
	MapKit.Wall(folder, "FrontWall", base * CFrame.new(0, 0, D / 2), W, H, 1, { { Offset = 0, Width = 5, Height = 7 }, { Offset = -7, Width = 3, Height = 2.5, Sill = 3.5 }, { Offset = 7, Width = 3, Height = 2.5, Sill = 3.5 } }, PLASTER, M.Plaster)
	MapKit.Wall(folder, "BackWall", base * CFrame.new(0, 0, -D / 2), W, H, 1, {}, PLASTER, M.Plaster)
	for _, x in { -W / 2, W / 2 } do
		MapKit.Wall(folder, "GableWall", base * CFrame.new(x, 0, 0) * CFrame.Angles(0, math.rad(90), 0), D, H, 1, { { Offset = 0, Width = 2.5, Height = 2.5, Sill = 3.5 } }, PLASTER, M.Plaster)
		-- triangular gable fill (two wedges)
		-- WedgePart's tall face is +Z: the back half keeps it (ridge side), the front half is turned
		K.Wedge(folder, "GableFill", Vector3.new(1, 5, D / 2), base * CFrame.new(x, H + 2.5, -D / 4), PLASTER, M.Plaster)
		K.Wedge(folder, "GableFill", Vector3.new(1, 5, D / 2), base * CFrame.new(x, H + 2.5, D / 4) * CFrame.Angles(0, math.pi, 0), PLASTER, M.Plaster)
	end
	-- timber framing
	for _, x in { -W / 2, -W / 6, W / 6, W / 2 } do
		K.Part(folder, "Beam", Vector3.new(0.6, H, 0.6), base * CFrame.new(x, H / 2, D / 2 + 0.3), TIMBER, M.Wood)
	end
	K.Part(folder, "Lintel", Vector3.new(W + 0.6, 0.6, 0.6), base * CFrame.new(0, H, D / 2 + 0.3), TIMBER, M.Wood)
	-- thatched gable roof: two walkable slopes (rise 5 over 8 = 32 degrees), ridge along X
	local slopeD = D / 2 + 1
	K.Wedge(folder, "ThatchFront", Vector3.new(W + 2, 5, slopeD), base * CFrame.new(0, H + 2.5, slopeD / 2) * CFrame.Angles(0, math.pi, 0), THATCH, M.Grass)
	K.Wedge(folder, "ThatchBack", Vector3.new(W + 2, 5, slopeD), base * CFrame.new(0, H + 2.5, -slopeD / 2), THATCH, M.Grass)
	K.Cylinder(folder, "Ridge", W + 2.4, 1, base * CFrame.new(0, H + 5, 0), RGB(150, 120, 70), M.Grass)
	K.Part(folder, "Chimney", Vector3.new(2, 6, 2), base * CFrame.new(-7, H + 4, -3), STONE, M.Cobblestone)
	K.Part(folder, "Floor", Vector3.new(W, 0.3, D), base * CFrame.new(0, 0.15, 0), RGB(120, 90, 60), M.WoodPlanks)
	-- climbing crates on the east flank: 1-high, 2-high, then the 9 stud eave
	local flank = base * CFrame.new(W / 2 + 3, 0, D / 2 - 2)
	MapKit.Crate(folder, flank * CFrame.new(3.5, 0, 2), CRATE)
	MapKit.Crate(folder, flank, CRATE)
	MapKit.Crate(folder, flank * CFrame.new(0, CRATE, 0), CRATE)
	K.Part(folder, "RoofPlank", Vector3.new(4, 0.4, 3), flank * CFrame.new(-2.5, 2 * CRATE + 0.6, 1) * CFrame.Angles(0, 0, math.rad(-8)), TIMBER, M.WoodPlanks)
	-- spawn yard in front of the cottage
	for i, x in { -8, 0, 8 } do
		MapKit.SpawnPad(folder, team, i, S(CFrame.lookAt(Vector3.new(x, 0, -124), Vector3.new(x, 0, 0))))
	end
	-- low fence enclosing the yard with a gate barrier
	for _, x in { -16, 16 } do
		K.Part(folder, "YardFence", Vector3.new(0.5, 3, 12), S(CFrame.new(x, 1.5, -122)), TIMBER, M.Wood)
	end
	K.Part(folder, "YardFenceFrontL", Vector3.new(10, 3, 0.5), S(CFrame.new(-11, 1.5, -116)), TIMBER, M.Wood)
	K.Part(folder, "YardFenceFrontR", Vector3.new(10, 3, 0.5), S(CFrame.new(11, 1.5, -116)), TIMBER, M.Wood)
	MapKit.SpawnBarrier(folder, team, S(CFrame.new(0, 5, -116)), Vector3.new(12, 10, 1))
	MapKit.SpawnBarrier(folder, team, S(CFrame.new(-16.5, 5, -122)), Vector3.new(1, 10, 12))
	MapKit.SpawnBarrier(folder, team, S(CFrame.new(16.5, 5, -122)), Vector3.new(1, 10, 12))
	MapKit.Campfire(folder, S(CFrame.new(-12, 0, -128)))
end

local function henge(mid: Folder)
	local radius = 26
	local stones: { CFrame } = {}
	for i = 0, 7 do
		local a = math.rad(i * 45)
		local cf = CFrame.new(math.cos(a) * radius, 0, math.sin(a) * radius) * CFrame.Angles(0, -a + math.pi / 2, 0)
		table.insert(stones, cf)
		local m = K.Model(mid, "Monolith" .. (i + 1))
		K.Part(m, "Pillar", Vector3.new(5, 14, 3), cf * CFrame.new(0, 7, 0) * CFrame.Angles(0, 0, math.rad((i % 3 - 1) * 1.5)), STONE, M.Slate)
		K.Part(m, "Moss", Vector3.new(5.1, 2, 3.1), cf * CFrame.new(0, 1, 0), MOSS, M.Grass)
		m:SetAttribute("CoverHeight", 14)
	end
	-- capstone lintels bridging alternating pairs
	for i = 1, 8, 2 do
		local a = stones[i].Position
		local b = stones[(i % 8) + 1].Position
		local mid3 = (a + b) / 2
		local len = (b - a).Magnitude + 4
		K.Part(mid, "Lintel", Vector3.new(len, 2.2, 3.2), CFrame.lookAt(mid3 + Vector3.new(0, 15.1, 0), b + Vector3.new(0, 15.1, 0)) * CFrame.Angles(0, math.rad(90), 0), STONE, M.Slate)
	end
	-- altar stone and low peek rocks inside the ring
	K.Part(mid, "AltarStone", Vector3.new(8, 2.2, 4), CFrame.new(0, 1.1, 0), RGB(110, 112, 108), M.Slate)
	for i, p in { Vector3.new(-12, 0, -8), Vector3.new(12, 0, 8), Vector3.new(-6, 0, 14), Vector3.new(6, 0, -14) } do
		MapKit.Rock(mid, p, 3.4, STONE, M.Rock, 300 + i)
	end
end

local function cart(parent: Instance, cf: CFrame)
	local m = K.Model(parent, "Cart")
	K.Part(m, "Bed", Vector3.new(4.5, 0.5, 8), cf * CFrame.new(0, 2.4, 0), RGB(130, 92, 56), M.WoodPlanks)
	for _, x in { -2.4, 2.4 } do
		K.Part(m, "Side", Vector3.new(0.3, 1.6, 8), cf * CFrame.new(x, 3.4, 0), RGB(110, 76, 46), M.WoodPlanks)
		K.Cylinder(m, "Wheel", 0.4, 3.6, cf * CFrame.new(x + (if x < 0 then -0.4 else 0.4), 1.8, 1.5), TIMBER, M.Wood)
	end
	K.Part(m, "Tongue", Vector3.new(0.4, 0.4, 5), cf * CFrame.new(0, 2, -6.4) * CFrame.Angles(math.rad(-12), 0, 0), TIMBER, M.Wood)
	K.Cylinder(m, "Hay", 3.5, 3, cf * CFrame.new(0, 4, 1.5), THATCH, M.Grass)
	m:SetAttribute("CoverHeight", 4.2)
end

local function hayBale(parent: Instance, cf: CFrame)
	local bale = K.Cylinder(parent, "HayBale", 4, 4, cf * CFrame.new(0, 2, 0), THATCH, M.Grass)
	K.Cylinder(parent, "BaleTwine", 0.15, 4.08, cf * CFrame.new(-1, 2, 0), RGB(150, 110, 60), M.Fabric)
	K.Cylinder(parent, "BaleTwine", 0.15, 4.08, cf * CFrame.new(1, 2, 0), RGB(150, 110, 60), M.Fabric)
	bale:SetAttribute("CoverHeight", 4)
end

function Map.Build(): Model
	local sections = MapKit.NewMap("Map_03_HighlandHenge", "Highland Henge", "MidLane_StonehengeRing", "SideLanes_CoastalTrenchAndWall")
	local model = sections.Model
	MapKit.ApplyLighting(model, 17.2, RGB(140, 150, 140), RGB(190, 205, 210), 650, 0.42)
	model:SetAttribute("Theme", "Highland")

	-- ground: grass plateau, the west channel strip is left open for the water lane
	MapKit.Ground(model, "Plateau", Vector3.new(HALF_X * 2 - 26, 4, HALF_Z * 2), Vector3.new(13, 0, 0), GRASS, M.Grass)
	MapKit.Ground(model, "Shore", Vector3.new(8, 4, HALF_Z * 2), Vector3.new(-HALF_X + 4, 0, 0), RGB(200, 190, 150), M.Sand)

	henge(sections.MidLane)

	-- WEST LANE: coastal water channel (x -102 .. -84), 1.5 deep, gentle banks
	local side = sections.SideLanes
	MapKit.WaterChannel(side, "CoastalChannel", CFrame.new(-93, 0, 0), Vector3.new(18, 1, HALF_Z * 2), 1.5, RGB(120, 110, 90))
	-- banks: wedges inside the channel rising to ground level (tall face turned toward the shore)
	K.Wedge(side, "ChannelBankEast", Vector3.new(HALF_Z * 2, 1.5, 3), CFrame.new(-85.5, -0.75, 0) * CFrame.Angles(0, math.rad(90), 0), GRASS, M.Grass)
	K.Wedge(side, "ChannelBankWest", Vector3.new(HALF_Z * 2, 1.5, 3), CFrame.new(-100.5, -0.75, 0) * CFrame.Angles(0, math.rad(-90), 0), RGB(200, 190, 150), M.Sand)
	for i = 0, 5 do
		MapKit.Rock(side, Vector3.new(-96 + (i % 2) * 6, -1.5, -110 + i * 44), 4, STONE, M.Rock, 400 + i)
	end
	-- EAST LANE: low dry-stone wall, 3 studs tall, in segments with slide gaps
	for i = 0, 6 do
		local z = -120 + i * 40
		local wall = K.Model(side, "StoneWall" .. (i + 1))
		for k = 0, 9 do
			K.Part(wall, "Course", Vector3.new(2.2, 1, 2.6), CFrame.new(78 + (k % 2) * 0.15, 0.5 + (k % 3), z - 12 + k * 2.6) * CFrame.Angles(0, math.rad((k * 37) % 11 - 5), 0), STONE, M.Cobblestone)
		end
		K.Part(wall, "WallCore", Vector3.new(2, 3, 26), CFrame.new(78, 1.5, z), STONE, M.Cobblestone)
		wall:SetAttribute("CoverHeight", 3)
	end

	for _, sign in { -1, 1 } do
		cottage(sections, sign)
	end

	local rocks: { MapKit.Placement } = {
		{ P = Vector3.new(-40, 0, -70), Yaw = 0, Len = 6 },
		{ P = Vector3.new(30, 0, -86), Yaw = 0, Len = 5 },
		{ P = Vector3.new(-58, 0, -30), Yaw = 0, Len = 7 },
		{ P = Vector3.new(50, 0, -40), Yaw = 0, Len = 5 },
		{ P = Vector3.new(-18, 0, -100), Yaw = 0, Len = 4 },
	}
	local carts: { MapKit.Placement } = {
		{ P = Vector3.new(-30, 0, -50), Yaw = 30 },
		{ P = Vector3.new(40, 0, -66), Yaw = -60 },
	}
	local bales: { MapKit.Placement } = {
		{ P = Vector3.new(10, 0, -60), Yaw = 0 },
		{ P = Vector3.new(14, 0, -62), Yaw = 20 },
		{ P = Vector3.new(-60, 0, -96), Yaw = 80 },
		{ P = Vector3.new(62, 0, -100), Yaw = 10 },
		{ P = Vector3.new(-8, 0, -44), Yaw = 45 },
	}
	for _, sign in { -1, 1 } do
		for i, r in rocks do
			local m = MapKit.Rock(sections.Cover, MapKit.SymPos(sign, r.P), r.Len or 5, STONE, M.Rock, i * 17 + (if sign > 0 then 5 else 0))
			local core = m:FindFirstChild("Core") :: BasePart
			K.Part(m, "MossCap", Vector3.new(core.Size.X * 0.9, 0.5, core.Size.Z * 0.9), core.CFrame * CFrame.new(0, core.Size.Y / 2, 0), MOSS, M.Grass)
		end
		for _, c in carts do
			cart(sections.Cover, MapKit.Sym(sign, CFrame.new(c.P) * CFrame.Angles(0, math.rad(c.Yaw), 0)))
		end
		for _, b in bales do
			hayBale(sections.Cover, MapKit.Sym(sign, CFrame.new(b.P) * CFrame.Angles(0, math.rad(b.Yaw), 0)))
		end
	end

	MapKit.FinalizeMap(sections, HALF_X, HALF_Z, 180)
	return model
end

return Map
