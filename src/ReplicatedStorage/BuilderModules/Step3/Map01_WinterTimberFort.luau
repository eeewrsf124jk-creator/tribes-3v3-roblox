--!strict
-- Map 01: Winter Timber Fort (snowfield log forts). Point-symmetric 220 x 300 studs.
--   TeamSpawns   log-palisade citadels with 3 pads, campfire and a spawn barrier at the gate
--   MidLane      frozen river trench crossed by a timber bridge (3.8 stud railing half-cover)
--                with an ice bypass running under the bridge
--   SideLanes    four two-storey watchtowers with stairs and sniper balcony windows
--   Cover        snowy pines (12 studs, full cover), crates (4 studs, half cover), log barricades

local GeometryKit = require(script.Parent.Parent.Kit.GeometryKit)
local MapKit = require(script.Parent.Parent.Kit.MapKit)

local K = GeometryKit
local RGB = Color3.fromRGB
local M = Enum.Material

local HALF_X = 110
local HALF_Z = 150

local SNOW = RGB(236, 241, 248)
local ICE = RGB(160, 205, 235)
local LOG = RGB(112, 78, 48)
local PLANK = RGB(140, 100, 62)
local DARK = RGB(80, 56, 34)

local Map = {}

local function fort(sections: MapKit.MapSections, sign: number)
	local team = MapKit.TeamOf(sign)
	local folder = K.Folder(sections.TeamSpawns, team .. "_Citadel")
	local function S(cf: CFrame): CFrame
		return MapKit.Sym(sign, cf)
	end
	-- palisade walls: back (z = -146), sides (x = +-26), front (z = -114) with a 10 stud gate
	local function logRow(x0: number, z0: number, x1: number, z1: number, gapCenter: number?, gapWidth: number?)
		local a = Vector3.new(x0, 0, z0)
		local b = Vector3.new(x1, 0, z1)
		local len = (b - a).Magnitude
		local count = math.floor(len / 2)
		for i = 0, count do
			local t = i / count
			local p = a:Lerp(b, t)
			local along = (p - a).Magnitude - len / 2
			if gapCenter == nil or math.abs(along - gapCenter) > (gapWidth or 0) / 2 then
				local h = 10 + ((i * 7) % 3) * 0.6
				local world = S(CFrame.new(p))
				K.CylinderY(folder, "PalisadeLog", h, 2.1, world.Position + Vector3.new(0, h / 2, 0), LOG, M.Wood)
				K.Tip(folder, "LogPoint", CFrame.new(world.Position + Vector3.new(0, h, 0)), 1.8, 1.4, RGB(150, 112, 74), M.Wood)
			end
		end
	end
	logRow(-26, -146, 26, -146)
	logRow(-26, -146, -26, -114)
	logRow(26, -146, 26, -114)
	logRow(-26, -114, 26, -114, 0, 11)
	-- inner floor (packed planks) and firing step along the front wall
	K.Part(folder, "CitadelFloor", Vector3.new(50, 0.4, 30), S(CFrame.new(0, 0.2, -130)), PLANK, M.WoodPlanks)
	for _, x in { -16, 16 } do
		K.Part(folder, "FiringStep", Vector3.new(16, 1, 5), S(CFrame.new(x, 5.5, -117)), PLANK, M.WoodPlanks)
		for _, px in { x - 7, x + 7 } do
			K.CylinderY(folder, "StepPost", 6, 0.8, S(CFrame.new(px, 3, -117)).Position, DARK, M.Wood)
		end
		MapKit.Stairs(folder, "FiringStairs", S(CFrame.new(x, 0.4, -126) * CFrame.Angles(0, math.pi, 0)), 4, 5.6, 6.5, 8, PLANK, M.WoodPlanks)
	end
	-- spawn pads facing the enemy
	for i, x in { -8, 0, 8 } do
		MapKit.SpawnPad(folder, team, i, S(CFrame.lookAt(Vector3.new(x, 0.4, -136), Vector3.new(x, 0.4, 0))))
	end
	MapKit.Campfire(folder, S(CFrame.new(-15, 0.4, -128)))
	MapKit.Campfire(folder, S(CFrame.new(15, 0.4, -138)))
	MapKit.SpawnBarrier(folder, team, S(CFrame.new(0, 6, -114)), Vector3.new(11, 12, 1))
	-- banner
	K.CylinderY(folder, "BannerPole", 16, 0.5, S(CFrame.new(0, 8, -144)).Position, DARK, M.Wood)
	local banner = K.Part(folder, "Banner", Vector3.new(4, 5, 0.1), S(CFrame.new(2.2, 13, -144)), (MapKit.TeamColors :: any)[team], M.Fabric)
	banner.CastShadow = true
end

local function watchtower(parent: Instance, name: string, cf: CFrame)
	local m = K.Model(parent, name)
	-- 4 corner posts (20 studs)
	for _, x in { -6, 6 } do
		for _, z in { -6, 6 } do
			K.CylinderY(m, "Post", 20, 1.3, (cf * CFrame.new(x, 10, z)).Position, LOG, M.Wood)
		end
	end
	for _, z in { -6, 6 } do
		K.Beam3(m, "Brace", (cf * CFrame.new(-6, 1, z)).Position, (cf * CFrame.new(6, 6.5, z)).Position, 0.5, 0.5, DARK, M.Wood)
	end
	-- floor 1 (top at y = 7) with low railings on three sides; the +X side opens to the stairs
	K.Part(m, "Floor1", Vector3.new(14, 1, 14), cf * CFrame.new(0, 6.5, 0), PLANK, M.WoodPlanks)
	for _, side in { -1, 1 } do
		K.Part(m, "Rail1", Vector3.new(14, 2.5, 0.4), cf * CFrame.new(0, 8.25, side * 6.8), DARK, M.Wood)
	end
	K.Part(m, "Rail1Back", Vector3.new(0.4, 2.5, 14), cf * CFrame.new(-6.8, 8.25, 0), DARK, M.Wood)
	-- external stairs ground -> floor 1, landing on the +X side
	MapKit.Stairs(m, "StairsGround", cf * CFrame.new(9, 0, 6), 4, 7, 11, 10, PLANK, M.WoodPlanks)
	K.Part(m, "Landing", Vector3.new(4, 1, 4), cf * CFrame.new(9, 6.5, -7), PLANK, M.WoodPlanks)
	-- internal stairs floor 1 -> floor 2 rising toward -Z through a hatch opening
	MapKit.Stairs(m, "StairsUpper", cf * CFrame.new(4, 7, 5), 3.6, 7, 9, 10, PLANK, M.WoodPlanks)
	-- floor 2 (top at y = 14) built around the hatch (x 2..7, z -4.5..5.5)
	K.Part(m, "Floor2Main", Vector3.new(9, 1, 14), cf * CFrame.new(-2.5, 13.5, 0), PLANK, M.WoodPlanks)
	K.Part(m, "Floor2Front", Vector3.new(5, 1, 2.5), cf * CFrame.new(4.5, 13.5, -5.75), PLANK, M.WoodPlanks)
	K.Part(m, "Floor2Back", Vector3.new(5, 1, 1.5), cf * CFrame.new(4.5, 13.5, 6.25), PLANK, M.WoodPlanks)
	-- balcony walls with sniper windows on every side
	for i = 0, 3 do
		local wallCF = cf * CFrame.Angles(0, math.rad(i * 90), 0) * CFrame.new(0, 14, -6.8)
		MapKit.Wall(m, "BalconyWall" .. i, wallCF, 14, 4.5, 0.4, {
			{ Offset = -3, Width = 2.4, Height = 1.4, Sill = 2.4 },
			{ Offset = 3, Width = 2.4, Height = 1.4, Sill = 2.4 },
		}, PLANK, M.WoodPlanks)
	end
	-- roof
	K.Tip(m, "Roof", cf * CFrame.new(0, 18.6, 0), 16, 5, RGB(90, 70, 52), M.WoodPlanks)
	K.Tip(m, "RoofSnow", cf * CFrame.new(0, 19.8, 0), 10, 3.6, SNOW, M.Snow)
	return m
end

function Map.Build(): Model
	local sections = MapKit.NewMap("Map_01_WinterTimberFort", "Winter Timber Fort", "MidLane_FrozenRiverBridge", "SideLanes_Watchtowers")
	local model = sections.Model
	MapKit.ApplyLighting(model, 9.2, RGB(150, 165, 190), RGB(205, 220, 240), 700, 0.38)
	model:SetAttribute("Theme", "Winter")

	-- ground slabs on both banks
	for _, sign in { -1, 1 } do
		MapKit.Ground(model, "SnowField", Vector3.new(HALF_X * 2, 4, HALF_Z - 22), Vector3.new(0, 0, sign * (22 + (HALF_Z - 22) / 2)), SNOW, M.Snow)
	end

	-- MID: frozen river trench (bottom y = -6), banks, bridge with railings
	local mid = sections.MidLane
	K.Part(mid, "FrozenRiver", Vector3.new(HALF_X * 2, 1, 32), CFrame.new(0, -6.5, 0), ICE, M.Ice).Reflectance = 0.15
	K.Wedge(mid, "BankAlpha", Vector3.new(HALF_X * 2, 6, 6), CFrame.new(0, -3, -19) * CFrame.Angles(0, math.pi, 0), SNOW, M.Snow)
	K.Wedge(mid, "BankBravo", Vector3.new(HALF_X * 2, 6, 6), CFrame.new(0, -3, 19), SNOW, M.Snow)
	K.Part(mid, "BridgeDeck", Vector3.new(16, 1, 48), CFrame.new(0, -0.5, 0), PLANK, M.WoodPlanks)
	for i = -3, 3 do
		K.Part(mid, "DeckBeam", Vector3.new(16.4, 0.6, 0.6), CFrame.new(0, -1.2, i * 7), DARK, M.Wood)
	end
	for _, x in { -6, 6 } do
		for _, z in { -10, 0, 10 } do
			K.CylinderY(mid, "BridgePillar", 6.5, 1.6, Vector3.new(x, -3.75, z), LOG, M.Wood)
		end
	end
	for _, x in { -7.7, 7.7 } do
		K.Part(mid, "RailingPlanks", Vector3.new(0.6, 3.8, 48), CFrame.new(x, 1.9, 0), PLANK, M.WoodPlanks)
		K.Cylinder(mid, "RailingTopLog", 48, 0.8, CFrame.new(x, 3.9, 0) * CFrame.Angles(0, math.rad(90), 0), LOG, M.Wood)
		for z = -24, 24, 6 do
			K.CylinderY(mid, "RailPost", 4.6, 0.9, Vector3.new(x, 2.3, z), DARK, M.Wood)
		end
	end
	mid:SetAttribute("RailingHeight", 3.8)
	-- ice floes in the bypass under the bridge
	for i, p in { Vector3.new(-30, -5.6, 4), Vector3.new(34, -5.6, -5), Vector3.new(-70, -5.6, -6), Vector3.new(72, -5.6, 7) } do
		MapKit.Rock(mid, p, 5, RGB(185, 220, 245), M.Glacier, 100 + i)
	end

	-- BASES
	for _, sign in { -1, 1 } do
		fort(sections, sign)
	end

	-- SIDE LANES: watchtowers at (+-65, +-52)
	for _, sign in { -1, 1 } do
		for _, x in { -65, 65 } do
			watchtower(sections.SideLanes, string.format("Watchtower_%s_%s", MapKit.TeamOf(sign), if x < 0 then "L" else "R"), MapKit.Sym(sign, CFrame.new(x, 0, -52)))
		end
	end

	-- COVER (defined for the Alpha half, mirrored for Bravo)
	local pines = {
		Vector3.new(-40, 0, -80),
		Vector3.new(-48, 0, -38),
		Vector3.new(-88, 0, -95),
		Vector3.new(30, 0, -90),
		Vector3.new(88, 0, -30),
		Vector3.new(-95, 0, -30),
		Vector3.new(50, 0, -32),
		Vector3.new(-20, 0, -60),
	}
	local crates: { MapKit.Placement } = {
		{ P = Vector3.new(-12, 0, -40), Yaw = 0 },
		{ P = Vector3.new(14, 0, -48), Yaw = 20 },
		{ P = Vector3.new(-30, 0, -100), Yaw = 10 },
		{ P = Vector3.new(40, 0, -105), Yaw = 35 },
		{ P = Vector3.new(-80, 0, -60), Yaw = 0 },
		{ P = Vector3.new(78, 0, -70), Yaw = 15 },
		{ P = Vector3.new(4, 0, -88), Yaw = 45 },
	}
	local barricades: { MapKit.Placement } = {
		{ P = Vector3.new(0, 0, -62), Yaw = 0, Len = 14 },
		{ P = Vector3.new(-55, 0, -70), Yaw = 30, Len = 12 },
		{ P = Vector3.new(58, 0, -84), Yaw = -25, Len = 12 },
		{ P = Vector3.new(-30, 0, -30), Yaw = 90, Len = 10 },
	}
	for _, sign in { -1, 1 } do
		for _, p in pines do
			MapKit.PineTree(sections.Cover, MapKit.SymPos(sign, p), 12, true)
		end
		for _, c in crates do
			local cf = MapKit.Sym(sign, CFrame.new(c.P) * CFrame.Angles(0, math.rad(c.Yaw), 0))
			MapKit.Crate(sections.Cover, cf, 4)
			MapKit.CornerClip(sections.Clip, cf * CFrame.new(2, 0, 2), 4)
		end
		for _, b in barricades do
			MapKit.LogBarricade(sections.Cover, MapKit.Sym(sign, CFrame.new(b.P) * CFrame.Angles(0, math.rad(b.Yaw), 0)), b.Len or 12)
		end
	end
	-- snow drifts along the boundary (decor)
	for i = -4, 4 do
		for _, x in { -HALF_X + 4, HALF_X - 4 } do
			local p = K.Ball(sections.Cover, "SnowDrift", 12, CFrame.new(x, -2, i * 32), SNOW, M.Snow)
			K.Mesh(p, Enum.MeshType.Sphere, Vector3.new(1, 0.4, 1.6))
		end
	end

	MapKit.FinalizeMap(sections, HALF_X, HALF_Z, 180)
	return model
end

return Map
