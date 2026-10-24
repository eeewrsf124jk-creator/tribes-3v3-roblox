--!strict
-- Map 02: Desert Colosseum (ancient sandstone temple arena). Point-symmetric 220 x 300 studs.
--   TeamSpawns  sandstone colonnade porticos with 3 pads and a spawn barrier
--   MidLane     circular altar with a giant planted bronze sword (full cover) ringed by
--               red-glyph stone blocks (half cover)
--   SideLanes   two cyan-domed temples: interior corridors (melee chokepoints) + roof stairs
--   Cover       broken sandstone columns, palm trees, clay pots

local GeometryKit = require(script.Parent.Parent.Kit.GeometryKit)
local MapKit = require(script.Parent.Parent.Kit.MapKit)

local K = GeometryKit
local RGB = Color3.fromRGB
local M = Enum.Material

local HALF_X = 110
local HALF_Z = 150

local SAND = RGB(222, 190, 140)
local SANDSTONE = RGB(206, 166, 112)
local DARKSTONE = RGB(170, 132, 88)
local BRONZE = RGB(196, 128, 62)
local CYAN = RGB(52, 196, 196)
local RED = RGB(176, 42, 36)

local Map = {}

local function portico(sections: MapKit.MapSections, sign: number)
	local team = MapKit.TeamOf(sign)
	local folder = K.Folder(sections.TeamSpawns, team .. "_Portico")
	local function S(cf: CFrame): CFrame
		return MapKit.Sym(sign, cf)
	end
	K.Part(folder, "Stylobate", Vector3.new(64, 1.2, 28), S(CFrame.new(0, 0.6, -130)), DARKSTONE, M.Sandstone)
	for i = 0, 7 do
		local x = -28 + i * 8
		K.CylinderY(folder, "Column", 14, 3, S(CFrame.new(x, 8.2, -118)).Position, SANDSTONE, M.Sandstone)
		K.Part(folder, "Capital", Vector3.new(4, 1, 4), S(CFrame.new(x, 15.7, -118)), DARKSTONE, M.Sandstone)
		K.Part(folder, "Base", Vector3.new(4, 0.8, 4), S(CFrame.new(x, 1.6, -118)), DARKSTONE, M.Sandstone)
	end
	K.Part(folder, "Entablature", Vector3.new(64, 2, 28), S(CFrame.new(0, 17.2, -130)), SANDSTONE, M.Sandstone)
	K.Part(folder, "FriezeRed", Vector3.new(64.2, 0.6, 0.4), S(CFrame.new(0, 17, -116)), RED, M.Sandstone)
	K.Part(folder, "BackWall", Vector3.new(64, 16, 2), S(CFrame.new(0, 9, -143)), SANDSTONE, M.Sandstone)
	for _, x in { -31, 31 } do
		MapKit.Wall(folder, "SideWall", S(CFrame.new(x, 1.2, -130) * CFrame.Angles(0, math.rad(90), 0)), 26, 15, 2, {
			{ Offset = 4, Width = 5, Height = 8 },
		}, SANDSTONE, M.Sandstone)
	end
	for i, x in { -8, 0, 8 } do
		MapKit.SpawnPad(folder, team, i, S(CFrame.lookAt(Vector3.new(x, 1.2, -134), Vector3.new(x, 1.2, 0))))
	end
	-- braziers flanking the pads
	for _, x in { -18, 18 } do
		local bowl = K.CylinderY(folder, "Brazier", 1.2, 3, S(CFrame.new(x, 4, -136)).Position, BRONZE, M.Metal)
		K.CylinderY(folder, "BrazierStand", 3, 0.8, S(CFrame.new(x, 2.4, -136)).Position, BRONZE, M.Metal)
		local a = K.Attachment(bowl, "Fire", CFrame.new(0.6, 0, 0))
		K.Emitter(a, {
			Name = "Flame",
			Texture = K.Textures.Fire,
			Color = K.ColorSeq(RGB(255, 230, 140), RGB(255, 120, 30)),
			Size = K.Seq(1.4, 0.2),
			Transparency = K.Seq(0.2, 1),
			Lifetime = NumberRange.new(0.5, 0.9),
			Rate = 30,
			Speed = NumberRange.new(2, 4),
			LightEmission = 1,
			EmissionDirection = Enum.NormalId.Right,
		})
		K.PointLight(bowl, RGB(255, 160, 70), 2, 20)
	end
	MapKit.SpawnBarrier(folder, team, S(CFrame.new(0, 9, -116.5)), Vector3.new(60, 16, 1))
end

local function swordMonument(mid: Folder)
	K.CylinderY(mid, "AltarTier1", 1.5, 42, Vector3.new(0, 0.75, 0), DARKSTONE, M.Sandstone)
	K.CylinderY(mid, "AltarTier2", 1, 28, Vector3.new(0, 2, 0), SANDSTONE, M.Sandstone)
	K.CylinderY(mid, "AltarInlay", 0.06, 27, Vector3.new(0, 2.53, 0), RED, M.Sandstone)
	K.CylinderY(mid, "AltarTop", 0.1, 25, Vector3.new(0, 2.6, 0), SANDSTONE, M.Sandstone)
	-- cracked mound where the blade is planted
	for i = 0, 5 do
		local a = math.rad(i * 60 + 15)
		K.Wedge(mid, "Rubble" .. (i + 1), Vector3.new(4, 2.5, 4), CFrame.new(math.cos(a) * 4.5, 3.8, math.sin(a) * 4.5) * CFrame.Angles(0, -a + math.pi / 2, 0), DARKSTONE, M.Sandstone)
	end
	local statue = K.Model(mid, "SwordStatue")
	local tilt = CFrame.new(0, 2.6, 0) * CFrame.Angles(math.rad(6), math.rad(30), math.rad(4))
	K.Part(statue, "Blade", Vector3.new(5, 22, 1.4), tilt * CFrame.new(0, 11, 0), BRONZE, M.Metal)
	K.Part(statue, "Fuller", Vector3.new(1.2, 18, 1.5), tilt * CFrame.new(0, 12, 0), RGB(150, 96, 44), M.Metal)
	K.Part(statue, "Crossguard", Vector3.new(14, 1.8, 2.2), tilt * CFrame.new(0, 23, 0), BRONZE, M.Metal)
	for _, x in { -7, 7 } do
		K.Ball(statue, "GuardFinial", 2.4, tilt * CFrame.new(x, 23, 0), BRONZE, M.Metal)
	end
	K.Cylinder(statue, "Grip", 6, 1.6, tilt * CFrame.new(0, 27, 0) * CFrame.Angles(0, 0, math.rad(90)), RGB(120, 70, 36), M.Metal)
	K.Ball(statue, "Pommel", 3, tilt * CFrame.new(0, 30.5, 0), BRONZE, M.Metal)
	statue:SetAttribute("CoverHeight", 22)
	-- 8 red-glyph square blocks (3.5 stud half cover)
	for i = 0, 7 do
		local a = math.rad(i * 45 + 22.5)
		local cf = CFrame.new(math.cos(a) * 30, 0, math.sin(a) * 30) * CFrame.Angles(0, -a, 0)
		local block = K.Model(mid, "GlyphBlock" .. (i + 1))
		K.Part(block, "Stone", Vector3.new(4.5, 3.5, 4.5), cf * CFrame.new(0, 1.75, 0), SANDSTONE, M.Sandstone)
		for f = 0, 3 do
			local face = cf * CFrame.Angles(0, math.rad(f * 90), 0) * CFrame.new(0, 1.75, -2.26)
			K.Part(block, "GlyphBar", Vector3.new(3, 0.3, 0.06), face * CFrame.new(0, 0.9, 0), RED, M.Sandstone)
			K.Part(block, "GlyphBar", Vector3.new(0.3, 2, 0.06), face, RED, M.Sandstone)
			K.Part(block, "GlyphBar", Vector3.new(2, 0.3, 0.06), face * CFrame.new(0, -0.9, 0), RED, M.Sandstone)
		end
		block:SetAttribute("CoverHeight", 3.5)
	end
end

local function domeTemple(parent: Instance, name: string, cf: CFrame)
	local m = K.Model(parent, name)
	local W = 24
	local L = 60
	local H = 12
	-- outer walls: long walls along Z, ends along X; the inner long wall has a side door to mid
	MapKit.Wall(m, "OuterLongWall", cf * CFrame.new(W / 2, 0, 0) * CFrame.Angles(0, math.rad(90), 0), L, H, 2, {
		{ Offset = -18, Width = 2.5, Height = 2, Sill = 6 },
		{ Offset = 18, Width = 2.5, Height = 2, Sill = 6 },
	}, SANDSTONE, M.Sandstone)
	MapKit.Wall(m, "InnerLongWall", cf * CFrame.new(-W / 2, 0, 0) * CFrame.Angles(0, math.rad(90), 0), L, H, 2, {
		{ Offset = 0, Width = 6, Height = 8 },
		{ Offset = -20, Width = 2.5, Height = 2, Sill = 6 },
		{ Offset = 20, Width = 2.5, Height = 2, Sill = 6 },
	}, SANDSTONE, M.Sandstone)
	for _, z in { -L / 2, L / 2 } do
		MapKit.Wall(m, "EndWall", cf * CFrame.new(0, 0, z), W + 2, H, 2, {
			{ Offset = 0, Width = 7, Height = 9 },
		}, SANDSTONE, M.Sandstone)
	end
	-- interior: two pillar rows split the hall into a 10 stud corridor and side alcoves
	for z = -24, 24, 8 do
		for _, x in { -5.5, 5.5 } do
			K.Part(m, "HallPillar", Vector3.new(2, H, 2), cf * CFrame.new(x, H / 2, z), DARKSTONE, M.Sandstone)
		end
	end
	K.Part(m, "Floor", Vector3.new(W, 0.3, L), cf * CFrame.new(0, 0.15, 0), RGB(190, 150, 100), M.Sandstone)
	K.Part(m, "CorridorRug", Vector3.new(6, 0.05, L - 6), cf * CFrame.new(0, 0.33, 0), RED, M.Fabric)
	-- roof slab with parapet
	K.Part(m, "Roof", Vector3.new(W + 2, 1, L + 2), cf * CFrame.new(0, H + 0.5, 0), SANDSTONE, M.Sandstone)
	K.Part(m, "ParapetInner", Vector3.new(1, 2.5, L + 2), cf * CFrame.new(-(W / 2 + 0.5), H + 2.25, 0), DARKSTONE, M.Sandstone)
	-- outer parapet leaves a gap where the roof stairs arrive (z -9 .. -3)
	K.Part(m, "ParapetOuterA", Vector3.new(1, 2.5, 22), cf * CFrame.new(W / 2 + 0.5, H + 2.25, -20), DARKSTONE, M.Sandstone)
	K.Part(m, "ParapetOuterB", Vector3.new(1, 2.5, 34), cf * CFrame.new(W / 2 + 0.5, H + 2.25, 14), DARKSTONE, M.Sandstone)
	-- stepped cyan dome (5 courses)
	local y = H + 1
	for i, d in { 20, 17, 13, 8, 3 } do
		local h = if i == 5 then 2 else 1.8
		K.CylinderY(m, "DomeCourse" .. i, h, d, (cf * CFrame.new(0, y + h / 2, 0)).Position, CYAN, M.Marble)
		y += h
	end
	K.Tip(m, "DomeFinial", cf * CFrame.new(0, y, 0), 1.2, 3, RGB(236, 192, 72), M.Foil)
	-- exterior roof stairs on the outer side
	MapKit.Stairs(m, "RoofStairs", cf * CFrame.new(W / 2 + 3, 0, 18), 4, H + 1, 22, 16, DARKSTONE, M.Sandstone)
	K.Part(m, "StairLanding", Vector3.new(4, 1, 4), cf * CFrame.new(W / 2 + 3, H + 0.5, -6), DARKSTONE, M.Sandstone)
	return m
end

local function palm(parent: Instance, pos: Vector3, seed: number)
	local rng = Random.new(seed)
	local m = K.Model(parent, "PalmTree")
	local lean = Vector3.new(rng:NextNumber(-1, 1), 0, rng:NextNumber(-1, 1)).Unit
	local prev = pos
	for i = 1, 6 do
		local t = i / 6
		local p = pos + Vector3.new(0, i * 2.6, 0) + lean * (t * t * 4)
		K.Rod(m, "Trunk" .. i, prev, p, 1.3 - t * 0.4, RGB(140, 104, 64), M.Wood)
		prev = p
	end
	for i = 0, 6 do
		local a = math.rad(i * (360 / 7) + rng:NextNumber(0, 20))
		local dir = Vector3.new(math.cos(a), -0.35, math.sin(a))
		local tip = prev + dir * 6
		K.Beam3(m, "Frond" .. (i + 1), prev, tip, 2.2, 0.15, RGB(70, 140, 60), M.Grass)
	end
	K.Ball(m, "Coconuts", 1.6, CFrame.new(prev - Vector3.new(0, 0.6, 0)), RGB(110, 80, 40), M.Wood)
end

local function brokenColumn(parent: Instance, pos: Vector3, height: number, seed: number)
	local rng = Random.new(seed)
	local m = K.Model(parent, "BrokenColumn")
	K.Part(m, "Plinth", Vector3.new(4, 1, 4), CFrame.new(pos + Vector3.new(0, 0.5, 0)), DARKSTONE, M.Sandstone)
	K.CylinderY(m, "Shaft", height, 3, pos + Vector3.new(0, 1 + height / 2, 0), SANDSTONE, M.Sandstone)
	K.Wedge(m, "BrokenTop", Vector3.new(3, 1.2, 3), CFrame.new(pos + Vector3.new(0, 1.6 + height, 0)) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0), SANDSTONE, M.Sandstone)
	-- fallen drum lying beside
	local a = rng:NextNumber(0, 6.28)
	K.Cylinder(m, "FallenDrum", 3, 3, CFrame.new(pos + Vector3.new(math.cos(a) * 4, 1.5, math.sin(a) * 4)) * CFrame.Angles(0, a, 0), SANDSTONE, M.Sandstone)
	m:SetAttribute("CoverHeight", height)
end

local function pot(parent: Instance, pos: Vector3)
	local m = K.Model(parent, "ClayPot")
	local body = K.Ball(m, "Body", 2.4, CFrame.new(pos + Vector3.new(0, 1.2, 0)), RGB(176, 96, 58), M.Slate)
	K.Mesh(body, Enum.MeshType.Sphere, Vector3.new(1, 1.2, 1))
	K.CylinderY(m, "Neck", 0.8, 1.2, pos + Vector3.new(0, 2.7, 0), RGB(160, 86, 52), M.Slate)
	K.CylinderY(m, "Lip", 0.25, 1.6, pos + Vector3.new(0, 3.1, 0), RGB(150, 80, 48), M.Slate)
end

function Map.Build(): Model
	local sections = MapKit.NewMap("Map_02_DesertColosseum", "Desert Colosseum", "MidLane_SwordMonument", "SideLanes_CyanDomeTemples")
	local model = sections.Model
	MapKit.ApplyLighting(model, 15.5, RGB(190, 160, 120), RGB(235, 210, 170), 900, 0.3)
	model:SetAttribute("Theme", "Desert")

	MapKit.Ground(model, "ArenaSand", Vector3.new(HALF_X * 2, 4, HALF_Z * 2), Vector3.zero, SAND, M.Sand)
	-- colosseum outer walls (visual boundary, 20 tall with blind arches)
	for _, z in { -HALF_Z, HALF_Z } do
		K.Part(model, "ColosseumWall", Vector3.new(HALF_X * 2 + 6, 20, 3), CFrame.new(0, 10, z + (if z < 0 then -1.5 else 1.5)), SANDSTONE, M.Sandstone)
	end
	for _, x in { -HALF_X, HALF_X } do
		K.Part(model, "ColosseumWall", Vector3.new(3, 20, HALF_Z * 2 + 6), CFrame.new(x + (if x < 0 then -1.5 else 1.5), 10, 0), SANDSTONE, M.Sandstone)
		for z = -HALF_Z + 15, HALF_Z - 15, 20 do
			K.Part(model, "BlindArch", Vector3.new(0.4, 12, 8), CFrame.new(x + (if x < 0 then 0.2 else -0.2), 7, z), DARKSTONE, M.Sandstone)
		end
	end

	swordMonument(sections.MidLane)

	for _, sign in { -1, 1 } do
		portico(sections, sign)
	end

	-- side temples at x = +-72 (point symmetric: one per lane)
	domeTemple(sections.SideLanes, "CyanDomeTemple_West", CFrame.new(-72, 0, 0) * CFrame.Angles(0, math.pi, 0))
	domeTemple(sections.SideLanes, "CyanDomeTemple_East", CFrame.new(72, 0, 0))

	local columns: { MapKit.Placement } = {
		{ P = Vector3.new(-30, 0, -70), Yaw = 0, Len = 7 },
		{ P = Vector3.new(26, 0, -60), Yaw = 0, Len = 5 },
		{ P = Vector3.new(-12, 0, -98), Yaw = 0, Len = 9 },
		{ P = Vector3.new(44, 0, -100), Yaw = 0, Len = 6 },
		{ P = Vector3.new(-50, 0, -44), Yaw = 0, Len = 8 },
		{ P = Vector3.new(8, 0, -44), Yaw = 0, Len = 4 },
	}
	local palms = { Vector3.new(-90, 0, -90), Vector3.new(92, 0, -112), Vector3.new(-40, 0, -112), Vector3.new(60, 0, -36) }
	local pots = { Vector3.new(-26, 0, -110), Vector3.new(-23, 0, -108), Vector3.new(33, 0, -76), Vector3.new(-62, 0, -78), Vector3.new(16, 0, -30) }
	for _, sign in { -1, 1 } do
		for i, c in columns do
			brokenColumn(sections.Cover, MapKit.SymPos(sign, c.P), c.Len or 6, i * 13 + (if sign > 0 then 1 else 0))
		end
		for i, p in palms do
			palm(sections.Cover, MapKit.SymPos(sign, p), i * 31)
		end
		for _, p in pots do
			pot(sections.Cover, MapKit.SymPos(sign, p))
		end
	end

	MapKit.FinalizeMap(sections, HALF_X, HALF_Z, 180)
	return model
end

return Map
