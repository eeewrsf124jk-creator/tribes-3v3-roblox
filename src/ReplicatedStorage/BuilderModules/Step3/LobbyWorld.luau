--!strict
-- Lobby_50Player_World: social village for the 50-player hub place.
--   SpawnPlaza_Center         circular stone-tile plaza, 3-tier fountain, 12 SpawnLocations
--   Interactive_Booths        Loadout stall ([B] Loadout Builder), Custom Matches cabin, Tribe Hall
--   Global_3D_Leaderboards    3 SurfaceGui boards + 3 statue pedestals for the top eliminators
--   Mini_1v1_DuelPit_And_Training  sunken duel pit with [XX LIVE] billboard, target range with
--                             moving dummies at 20 / 50 / 100 studs

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GeometryKit = require(script.Parent.Parent.Kit.GeometryKit)
local MapKit = require(script.Parent.Parent.Kit.MapKit)
local CollisionGroups = require(ReplicatedStorage:WaitForChild("Modules").Shared.CollisionGroups)

local K = GeometryKit
local RGB = Color3.fromRGB
local M = Enum.Material

local Lobby = {}

local STONE_A = RGB(170, 168, 160)
local STONE_B = RGB(138, 134, 126)
local WOOD = RGB(132, 92, 56)
local DARK = RGB(80, 56, 34)
local GRASS = RGB(92, 150, 72)

local function prompt(parent: BasePart, action: string, object: string, key: Enum.KeyCode, interface: string, distance: number?): ProximityPrompt
	local att = K.Attachment(parent, "PromptAttachment", CFrame.new(0, 2, 0))
	local p = Instance.new("ProximityPrompt")
	p.Name = "InteractPrompt"
	p.ActionText = action
	p.ObjectText = object
	p.KeyboardKeyCode = key
	p.GamepadKeyCode = Enum.KeyCode.ButtonX
	p.HoldDuration = 0
	p.MaxActivationDistance = distance or 12
	p.RequiresLineOfSight = false
	p.Style = Enum.ProximityPromptStyle.Default
	p:SetAttribute("Interface", interface)
	p.Parent = att
	return p
end

local function zone(parent: Instance, name: string, size: Vector3, cf: CFrame, interface: string): Part
	local z = K.Part(parent, name, size, cf, Color3.new(1, 1, 1), M.SmoothPlastic, {
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		CanTouch = true,
		CastShadow = false,
	})
	z:SetAttribute("Interface", interface)
	z:AddTag("InterfaceZone")
	return z
end

---------------------------------------------------------------------------------------------
local function plaza(parent: Folder)
	local f = K.Folder(parent, "SpawnPlaza_Center")
	K.CylinderY(f, "CenterDisc", 0.6, 30, Vector3.new(0, 0.3, 0), STONE_A, M.Slate)
	local radius = 15
	local ring = 0
	while radius < 70 do
		ring += 1
		local width = 6
		local segments = math.floor(2 * math.pi * (radius + width / 2) / 5)
		local tiles = K.Ring(f, "TileRing" .. ring, CFrame.new(0, 0.3, 0), radius + width / 2, segments, width - 0.15, 0.6, STONE_A, M.Slate)
		for i, t in tiles do
			t.Color = if (i + ring) % 2 == 0 then STONE_A else STONE_B
		end
		radius += width
	end
	K.Ring(f, "PlazaCurb", CFrame.new(0, 0.6, 0), 72, 90, 1.5, 1.2, RGB(110, 106, 98), M.Cobblestone)

	-- 3-tier fountain
	local fountain = K.Model(f, "Fountain")
	K.CylinderY(fountain, "Basin", 2.2, 26, Vector3.new(0, 1.7, 0), RGB(190, 186, 176), M.Marble)
	local water1 = K.CylinderY(fountain, "BasinWater", 0.3, 23.5, Vector3.new(0, 2.7, 0), RGB(70, 150, 210), M.Glass, { CanCollide = false })
	water1.Transparency = 0.35
	K.CylinderY(fountain, "Column1", 6, 3.5, Vector3.new(0, 5.6, 0), RGB(200, 196, 186), M.Marble)
	K.CylinderY(fountain, "Bowl2", 1.2, 13, Vector3.new(0, 9, 0), RGB(190, 186, 176), M.Marble)
	local water2 = K.CylinderY(fountain, "Bowl2Water", 0.2, 11.5, Vector3.new(0, 9.65, 0), RGB(70, 150, 210), M.Glass, { CanCollide = false })
	water2.Transparency = 0.35
	K.CylinderY(fountain, "Column2", 4, 2.2, Vector3.new(0, 11.6, 0), RGB(200, 196, 186), M.Marble)
	K.CylinderY(fountain, "Bowl3", 0.9, 7, Vector3.new(0, 13.9, 0), RGB(190, 186, 176), M.Marble)
	local spout = K.Ball(fountain, "Spout", 1.6, CFrame.new(0, 15, 0), RGB(236, 192, 72), M.Foil)
	local jet = K.Attachment(spout, "Jet", CFrame.new(0, 0.6, 0))
	local waterProps: GeometryKit.EmitterProps = {
		Name = "WaterJet",
		Texture = K.Textures.Spark,
		Color = K.ColorSeq(RGB(230, 245, 255), RGB(120, 190, 240)),
		Size = K.Seq(0.5, 0.9),
		Transparency = K.Seq(0.1, 0.8),
		Lifetime = NumberRange.new(1.1, 1.4),
		Rate = 120,
		Speed = NumberRange.new(16, 19),
		SpreadAngle = Vector2.new(9, 9),
		Acceleration = Vector3.new(0, -32, 0),
	}
	K.Emitter(jet, waterProps)
	-- cascade sheets falling from bowl 2 and 3 rims
	for tier, data in { { Y = 9.6, R = 6.3, Count = 12 }, { Y = 14.35, R = 3.4, Count = 8 } } do
		for i = 0, data.Count - 1 do
			local a = (i / data.Count) * 2 * math.pi
			local rim = K.Attachment(fountain:FindFirstChild("Basin") :: BasePart, string.format("Rim%d_%d", tier, i), CFrame.new(math.cos(a) * data.R, data.Y - 1.7, math.sin(a) * data.R))
			K.Emitter(rim, {
				Name = "Cascade",
				Texture = K.Textures.Spark,
				Color = ColorSequence.new(RGB(200, 230, 255)),
				Size = K.Seq(0.4, 0.6),
				Transparency = K.Seq(0.2, 0.9),
				Lifetime = NumberRange.new(0.5, 0.7),
				Rate = 25,
				Speed = NumberRange.new(2, 3),
				SpreadAngle = Vector2.new(10, 10),
				Acceleration = Vector3.new(math.cos(a) * 2, -30, math.sin(a) * 2),
				EmissionDirection = Enum.NormalId.Top,
			})
		end
	end
	local sound = K.Sound(water1, "FountainLoop", "rbxasset://sounds/action_swim.mp3", 0.25, 0.8, true)
	sound.Playing = true

	-- 12 SpawnLocations around the fountain
	local spawns = K.Folder(f, "SpawnLocations")
	for i = 0, 11 do
		local a = (i / 12) * 2 * math.pi
		local pos = Vector3.new(math.cos(a) * 34, 0.9, math.sin(a) * 34)
		local s = Instance.new("SpawnLocation")
		s.Name = "PlazaSpawn" .. (i + 1)
		s.Size = Vector3.new(6, 0.6, 6)
		s.CFrame = CFrame.lookAt(pos, Vector3.new(0, 0.9, 0))
		s.Anchored = true
		s.Neutral = true
		s.Duration = 0
		s.AllowTeamChangeOnTouch = false
		s.Material = M.Marble
		s.Color = RGB(230, 226, 214)
		s.TopSurface = Enum.SurfaceType.Smooth
		s.Parent = spawns
		local decal = s:FindFirstChildOfClass("Decal")
		if decal then
			decal:Destroy()
		end
	end
	-- lamp posts
	for i = 0, 7 do
		local a = (i / 8) * 2 * math.pi + math.rad(22.5)
		local pos = Vector3.new(math.cos(a) * 60, 0, math.sin(a) * 60)
		K.CylinderY(f, "LampPost", 10, 0.6, pos + Vector3.new(0, 5.6, 0), RGB(40, 40, 44), M.Metal)
		local lamp = K.Part(f, "Lantern", Vector3.new(1.4, 1.8, 1.4), CFrame.new(pos + Vector3.new(0, 11.2, 0)), RGB(255, 220, 150), M.Neon)
		K.PointLight(lamp, RGB(255, 210, 140), 1.8, 22)
	end
end

---------------------------------------------------------------------------------------------
local function loadoutStall(parent: Folder, prefabs: Instance?)
	local f = K.Model(parent, "Loadout_Stall")
	local base = CFrame.new(92, 0, -22) * CFrame.Angles(0, math.rad(90), 0) -- faces -X (toward plaza)
	K.Part(f, "Floor", Vector3.new(20, 0.6, 12), base * CFrame.new(0, 0.3, 0), RGB(150, 112, 70), M.WoodPlanks)
	local counter = K.Part(f, "Counter", Vector3.new(16, 3.4, 2), base * CFrame.new(0, 2.3, -4.5), WOOD, M.WoodPlanks)
	K.Part(f, "CounterTop", Vector3.new(16.6, 0.3, 2.6), base * CFrame.new(0, 4.1, -4.5), RGB(230, 230, 236), M.Marble)
	for _, x in { -9.5, 9.5 } do
		for _, z in { -5.5, 5.5 } do
			K.CylinderY(f, "Pole", 11, 0.6, (base * CFrame.new(x, 5.8, z)).Position, RGB(235, 235, 240), M.Wood)
		end
	end
	-- blue/white striped awning (alternating wedges sloping toward the front)
	for i = 0, 9 do
		local color = if i % 2 == 0 then RGB(40, 110, 220) else RGB(245, 245, 250)
		K.Wedge(f, "AwningStripe" .. (i + 1), Vector3.new(2, 2.2, 13), base * CFrame.new(-9 + i * 2, 12.4, 0) * CFrame.Angles(0, math.pi, 0), color, M.Fabric)
		K.Part(f, "Valance" .. (i + 1), Vector3.new(2, 1.2, 0.15), base * CFrame.new(-9 + i * 2, 10.7, -6.55), color, M.Fabric)
	end
	-- weapon rack with real prefab copies
	K.Part(f, "WeaponRack", Vector3.new(14, 6, 0.6), base * CFrame.new(0, 3.6, 5), DARK, M.WoodPlanks)
	for _, y in { 2, 4.5 } do
		K.Part(f, "RackPeg", Vector3.new(14, 0.3, 0.8), base * CFrame.new(0, y, 4.5), RGB(60, 42, 26), M.Wood)
	end
	if prefabs then
		local display = { "IronSword", "WoodBow", "Hammer", "Crossbow", "Spear" }
		for i, id in display do
			local found: Instance? = nil
			for _, d in prefabs:GetDescendants() do
				if d:IsA("Model") and d:GetAttribute("ItemId") == id then
					found = d
					break
				end
			end
			if found then
				local copy = (found :: Model):Clone()
				copy.Name = "Display_" .. id
				for _, d in copy:GetDescendants() do
					if d:IsA("BasePart") then
						d.Anchored = true
						d.CanCollide = false
						d.CanQuery = false
					end
				end
				copy:PivotTo(base * CFrame.new(-6 + (i - 1) * 3, 3.2, 4.4) * CFrame.Angles(0, 0, math.rad(if i % 2 == 0 then 0 else 8)))
				copy.Parent = f
			end
		end
	end
	local sign = K.Part(f, "Sign", Vector3.new(10, 2.2, 0.3), base * CFrame.new(0, 9, -6.4), RGB(30, 60, 140), M.Wood)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "SignGui"
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 0
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Text = "LOADOUT  [B]"
	label.TextScaled = true
	label.Font = Enum.Font.GothamBlack
	label.TextColor3 = Color3.new(1, 1, 1)
	label.Parent = gui
	gui.Parent = sign
	prompt(counter, "Loadout Builder", "[B]", Enum.KeyCode.B, "LoadoutBuilder")
	zone(f, "LoadoutZone", Vector3.new(22, 10, 18), base * CFrame.new(0, 5, -6), "LoadoutBuilder")
end

local function logCabin(parent: Folder)
	local f = K.Model(parent, "CustomMatches_Cabin")
	local base = CFrame.new(92, 0, 30) * CFrame.Angles(0, math.rad(90), 0)
	local W, D = 18, 14
	-- walls from stacked horizontal logs, front wall leaves a door
	for row = 0, 7 do
		local y = 0.7 + row * 1.25
		for _, z in { -D / 2, D / 2 } do
			if z < 0 and y < 7.5 then
				for _, xs in { { -W / 2, -2 }, { 2, W / 2 } } do
					local len = xs[2] - xs[1]
					K.Cylinder(f, "Log", len + 1, 1.3, base * CFrame.new((xs[1] + xs[2]) / 2, y, z), WOOD, M.Wood)
				end
			else
				K.Cylinder(f, "Log", W + 1.4, 1.3, base * CFrame.new(0, y, z), WOOD, M.Wood)
			end
		end
		for _, x in { -W / 2, W / 2 } do
			K.Cylinder(f, "Log", D + 1.4, 1.3, base * CFrame.new(x, y + 0.6, 0) * CFrame.Angles(0, math.rad(90), 0), RGB(118, 82, 50), M.Wood)
		end
	end
	K.Part(f, "Floor", Vector3.new(W, 0.4, D), base * CFrame.new(0, 0.2, 0), RGB(150, 112, 70), M.WoodPlanks)
	K.Wedge(f, "RoofFront", Vector3.new(W + 3, 4.5, D / 2 + 1.5), base * CFrame.new(0, 12.2, -(D / 2 + 1.5) / 2) * CFrame.Angles(0, math.pi, 0), RGB(90, 60, 40), M.WoodPlanks)
	K.Wedge(f, "RoofBack", Vector3.new(W + 3, 4.5, D / 2 + 1.5), base * CFrame.new(0, 12.2, (D / 2 + 1.5) / 2), RGB(90, 60, 40), M.WoodPlanks)
	local desk = K.Part(f, "MatchBoard", Vector3.new(6, 4, 0.5), base * CFrame.new(0, 4, 4), RGB(40, 34, 30), M.Slate)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "BoardGui"
	gui.Face = Enum.NormalId.Front
	gui.LightInfluence = 0
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Text = "CUSTOM MATCHES\n1v1 · 2v2 · 3v3"
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.TextColor3 = RGB(240, 230, 200)
	label.Parent = gui
	gui.Parent = desk
	prompt(desk, "Custom Matches", "Cabin", Enum.KeyCode.E, "CustomMatches")
	MapKit.Campfire(f, base * CFrame.new(-6, 0, -12))
end

local function tribeHall(parent: Folder)
	local f = K.Model(parent, "TribeHall_Building")
	local base = CFrame.new(-118, 0, 0) * CFrame.Angles(0, math.rad(-90), 0) -- faces +X
	local W, D = 40, 30
	-- stone ground storey
	MapKit.Wall(f, "StoneFront", base * CFrame.new(0, 0, -D / 2), W, 12, 2, { { Offset = 0, Width = 8, Height = 9 }, { Offset = -12, Width = 4, Height = 4, Sill = 4 }, { Offset = 12, Width = 4, Height = 4, Sill = 4 } }, RGB(150, 146, 136), M.Cobblestone)
	MapKit.Wall(f, "StoneBack", base * CFrame.new(0, 0, D / 2), W, 12, 2, {}, RGB(150, 146, 136), M.Cobblestone)
	for _, x in { -W / 2, W / 2 } do
		MapKit.Wall(f, "StoneSide", base * CFrame.new(x, 0, 0) * CFrame.Angles(0, math.rad(90), 0), D, 12, 2, { { Offset = 0, Width = 4, Height = 4, Sill = 4 } }, RGB(150, 146, 136), M.Cobblestone)
	end
	-- timber upper storey
	K.Part(f, "UpperFloor", Vector3.new(W + 2, 1, D + 2), base * CFrame.new(0, 12.5, 0), DARK, M.WoodPlanks)
	for _, z in { -D / 2, D / 2 } do
		K.Part(f, "UpperWall", Vector3.new(W, 8, 1), base * CFrame.new(0, 17, z), RGB(220, 210, 190), M.Plaster)
		for x = -W / 2, W / 2, 5 do
			K.Part(f, "Timber", Vector3.new(0.7, 8, 0.4), base * CFrame.new(x, 17, z + (if z < 0 then -0.6 else 0.6)), DARK, M.Wood)
		end
	end
	for _, x in { -W / 2, W / 2 } do
		K.Part(f, "UpperWall", Vector3.new(1, 8, D), base * CFrame.new(x, 17, 0), RGB(220, 210, 190), M.Plaster)
	end
	-- steep roof + ridge
	K.Wedge(f, "RoofFront", Vector3.new(W + 4, 10, D / 2 + 2), base * CFrame.new(0, 26, -(D / 2 + 2) / 2) * CFrame.Angles(0, math.pi, 0), RGB(70, 50, 36), M.WoodPlanks)
	K.Wedge(f, "RoofBack", Vector3.new(W + 4, 10, D / 2 + 2), base * CFrame.new(0, 26, (D / 2 + 2) / 2), RGB(70, 50, 36), M.WoodPlanks)
	-- tribe banners flanking the door
	for i, x in { -6, 6 } do
		local banner = K.Part(f, "TribeBanner" .. i, Vector3.new(3, 7, 0.1), base * CFrame.new(x, 8, -D / 2 - 1.2), if i == 1 then RGB(170, 30, 40) else RGB(30, 80, 170), M.Fabric)
		banner.CastShadow = true
	end
	K.Part(f, "HallFloor", Vector3.new(W, 0.3, D), base * CFrame.new(0, 0.15, 0), RGB(120, 92, 60), M.WoodPlanks)
	local throne = K.Part(f, "TribeAltar", Vector3.new(8, 3, 4), base * CFrame.new(0, 1.5, 9), RGB(110, 106, 98), M.Slate)
	K.Part(f, "AltarFlame", Vector3.new(2, 0.6, 2), base * CFrame.new(0, 3.3, 9), RGB(255, 120, 40), M.Neon)
	prompt(throne, "Tribe Hall", "Create / Join", Enum.KeyCode.E, "TribeHall", 14)
	zone(f, "TribeZone", Vector3.new(W - 4, 10, D - 4), base * CFrame.new(0, 5, 0), "TribeHall")
	MapKit.Stairs(f, "EntranceSteps", base * CFrame.new(0, 0, -D / 2 - 5) * CFrame.Angles(0, math.pi, 0), 10, 0.3, 3, 2, RGB(140, 136, 128), M.Slate)
end

---------------------------------------------------------------------------------------------
local function board(parent: Instance, name: string, title: string, accent: Color3, cf: CFrame): Part
	local f = K.Model(parent, name)
	for _, x in { -8.5, 8.5 } do
		K.Part(f, "Post", Vector3.new(1.2, 22, 1.2), cf * CFrame.new(x, 11, 0.4), DARK, M.Wood)
	end
	local panel = K.Part(f, "Panel", Vector3.new(16, 18, 0.8), cf * CFrame.new(0, 12, 0), RGB(22, 24, 30), M.Slate)
	K.Part(f, "TopTrim", Vector3.new(17.6, 1, 1.2), cf * CFrame.new(0, 21.5, 0), accent, M.Neon)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "BoardGui"
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 32
	gui.LightInfluence = 0
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	local bg = Instance.new("Frame")
	bg.Name = "Background"
	bg.Size = UDim2.fromScale(1, 1)
	bg.BackgroundColor3 = RGB(16, 18, 26)
	bg.BorderSizePixel = 0
	bg.Parent = gui
	local grad = Instance.new("UIGradient")
	grad.Color = K.ColorSeq(RGB(30, 34, 48), RGB(12, 12, 18))
	grad.Rotation = 90
	grad.Parent = bg
	local header = Instance.new("TextLabel")
	header.Name = "Title"
	header.BackgroundTransparency = 1
	header.Size = UDim2.fromScale(0.94, 0.1)
	header.Position = UDim2.fromScale(0.03, 0.02)
	header.Text = title
	header.TextScaled = true
	header.Font = Enum.Font.GothamBlack
	header.TextColor3 = accent
	header.Parent = bg
	local list = Instance.new("ScrollingFrame")
	list.Name = "Rows"
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.Size = UDim2.fromScale(0.94, 0.84)
	list.Position = UDim2.fromScale(0.03, 0.14)
	list.ScrollBarThickness = 6
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.CanvasSize = UDim2.new()
	list.Parent = bg
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 4)
	layout.Parent = list
	gui.Parent = panel
	panel:SetAttribute("Leaderboard", name)
	panel:AddTag("LeaderboardPanel")
	return panel
end

local function leaderboards(parent: Folder)
	local f = K.Folder(parent, "Global_3D_Leaderboards")
	local facing = CFrame.Angles(0, math.pi, 0) -- boards at -Z face +Z (toward the plaza)
	board(f, "Board_TopTribes", "TOP TRIBES · WEEKLY GLORY", RGB(255, 200, 60), CFrame.new(-42, 0, -100) * facing)
	board(f, "Board_MostEliminations", "MOST ELIMINATIONS", RGB(255, 80, 70), CFrame.new(0, 0, -104) * facing)
	board(f, "Board_LongestStreaks", "LONGEST STREAKS 🔥", RGB(255, 140, 40), CFrame.new(42, 0, -100) * facing)
	-- statue podium (1st centre and tallest)
	local podium = K.Model(f, "EliminationStatues")
	for rank, data in { { X = 0, H = 5 }, { X = -9, H = 3.5 }, { X = 9, H = 2.5 } } do
		local ped = K.Part(podium, "Pedestal" .. rank, Vector3.new(7, data.H, 7), CFrame.new(data.X, data.H / 2, -88), if rank == 1 then RGB(236, 192, 72) elseif rank == 2 then RGB(200, 204, 212) else RGB(196, 128, 62), M.Marble)
		ped:SetAttribute("StatueRank", rank)
		ped:AddTag("StatuePedestal")
		local gui = Instance.new("SurfaceGui")
		gui.Face = Enum.NormalId.Back
		gui.LightInfluence = 0
		local l = Instance.new("TextLabel")
		l.Name = "RankLabel"
		l.BackgroundTransparency = 1
		l.Size = UDim2.fromScale(1, 1)
		l.Text = "#" .. rank
		l.TextScaled = true
		l.Font = Enum.Font.GothamBlack
		l.TextColor3 = RGB(40, 30, 20)
		l.Parent = gui
		gui.Parent = ped
	end
end

---------------------------------------------------------------------------------------------
local function trainingDummy(parent: Instance, name: string, base: CFrame, distance: number, amplitude: number): Model
	local m = K.Model(parent, name)
	local burlap = RGB(196, 170, 120)
	local root = K.Part(m, "HumanoidRootPart", Vector3.new(2, 2, 1), base * CFrame.new(0, 3, 0), burlap, M.Fabric, { CanCollide = false, CanQuery = false })
	root.Transparency = 1
	local parts: { { Name: string, Size: Vector3, Offset: Vector3 } } = {
		{ Name = "Head", Size = Vector3.new(1.2, 1.2, 1.2), Offset = Vector3.new(0, 4.6, 0) },
		{ Name = "UpperTorso", Size = Vector3.new(2, 1.6, 1), Offset = Vector3.new(0, 3.4, 0) },
		{ Name = "LowerTorso", Size = Vector3.new(2, 0.4, 1), Offset = Vector3.new(0, 2.4, 0) },
		{ Name = "LeftUpperArm", Size = Vector3.new(1, 1.2, 1), Offset = Vector3.new(-1.5, 3.5, 0) },
		{ Name = "RightUpperArm", Size = Vector3.new(1, 1.2, 1), Offset = Vector3.new(1.5, 3.5, 0) },
		{ Name = "LeftLowerArm", Size = Vector3.new(1, 1.1, 1), Offset = Vector3.new(-1.5, 2.4, 0) },
		{ Name = "RightLowerArm", Size = Vector3.new(1, 1.1, 1), Offset = Vector3.new(1.5, 2.4, 0) },
		{ Name = "LeftUpperLeg", Size = Vector3.new(1, 1.2, 1), Offset = Vector3.new(-0.5, 1.6, 0) },
		{ Name = "RightUpperLeg", Size = Vector3.new(1, 1.2, 1), Offset = Vector3.new(0.5, 1.6, 0) },
	}
	for _, p in parts do
		local part = K.Part(m, p.Name, p.Size, base * CFrame.new(p.Offset), burlap, M.Fabric, { CanCollide = false })
		part.CollisionGroup = CollisionGroups.HitboxParts
		K.Weld(root, part)
	end
	local head = m:FindFirstChild("Head") :: BasePart
	K.Part(m, "TargetRing", Vector3.new(0.05, 1.1, 1.1), base * CFrame.new(0, 3.4, -0.53) * CFrame.Angles(0, math.rad(90), 0), RGB(200, 40, 40), M.SmoothPlastic, { CanCollide = false, CanQuery = false }).Shape = Enum.PartType.Cylinder
	K.CylinderY(m, "Pole", 1.4, 0.4, (base * CFrame.new(0, 0.7, 0)).Position, DARK, M.Wood)
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") and d ~= root and d.Name ~= "Pole" then
			if d.Name == "TargetRing" then
				K.Weld(root, d)
			end
			d.Anchored = false
		end
	end
	local pole = m:FindFirstChild("Pole") :: BasePart
	pole.Anchored = false
	K.Weld(root, pole)
	root.Anchored = true
	m.PrimaryPart = root
	m:SetAttribute("Distance", distance)
	m:SetAttribute("Amplitude", amplitude)
	m:SetAttribute("Origin", base.Position)
	m:AddTag("TrainingDummy")
	local bb = Instance.new("BillboardGui")
	bb.Name = "DamageBoard"
	bb.Size = UDim2.fromScale(5, 1.6)
	bb.StudsOffset = Vector3.new(0, 2.4, 0)
	bb.AlwaysOnTop = true
	bb.LightInfluence = 0
	bb.MaxDistance = 160
	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Text = string.format("%d STUDS", distance)
	label.TextScaled = true
	label.Font = Enum.Font.GothamBlack
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.3
	label.Parent = bb
	bb.Adornee = head
	bb.Parent = m
	return m
end

local function duelAndTraining(parent: Folder)
	local f = K.Folder(parent, "Mini_1v1_DuelPit_And_Training")
	-- Duel pit: 44 x 44 sunken by 6, ramps at both ends, spectator rim
	local pit = K.Model(f, "LiveDuelArena")
	local c = CFrame.new(0, 0, 130)
	K.Part(pit, "PitFloor", Vector3.new(44, 1, 44), c * CFrame.new(0, -6.5, 0), RGB(170, 150, 110), M.Sand)
	for _, x in { -22.5, 22.5 } do
		K.Part(pit, "PitWall", Vector3.new(1, 7, 46), c * CFrame.new(x, -3, 0), RGB(130, 126, 118), M.Cobblestone)
	end
	for _, z in { -22.5, 22.5 } do
		K.Part(pit, "PitWall", Vector3.new(46, 7, 1), c * CFrame.new(0, -3, z), RGB(130, 126, 118), M.Cobblestone)
	end
	MapKit.Stairs(pit, "PitStairs", c * CFrame.new(0, -6, -14) * CFrame.Angles(0, math.pi, 0), 6, 6, 8, 10, RGB(150, 146, 136), M.Cobblestone)
	K.Part(pit, "PitStairOpening", Vector3.new(6, 0.4, 2), c * CFrame.new(0, -0.2, -23), RGB(150, 146, 136), M.Cobblestone)
	-- duel join pads (one per side)
	for i, z in { -14, 14 } do
		local pad = K.CylinderY(pit, "DuelPad" .. i, 0.4, 6, (c * CFrame.new(-14, -5.8, z)).Position, if i == 1 then MapKit.TeamColors.Alpha else MapKit.TeamColors.Bravo, M.Neon)
		pad:SetAttribute("DuelSlot", i)
		pad:AddTag("DuelPad")
		local pp = prompt(pad, "Join Duel", "Slot " .. i, Enum.KeyCode.E, "DuelJoin", 10)
		pp:SetAttribute("DuelSlot", i)
	end
	-- the pit floor is a hitbox-safe combat zone
	local duelZone = zone(pit, "DuelZone", Vector3.new(44, 10, 44), c * CFrame.new(0, -2, 0), "DuelZone")
	duelZone:SetAttribute("CombatZone", "Duel")
	-- [XX LIVE] billboard on a tall post
	local post = K.CylinderY(pit, "BillboardPost", 18, 0.8, (c * CFrame.new(24, 9, -24)).Position, DARK, M.Wood)
	local bb = Instance.new("BillboardGui")
	bb.Name = "LiveBillboard"
	bb.Size = UDim2.fromScale(16, 4)
	bb.StudsOffset = Vector3.new(0, 11, 0)
	bb.LightInfluence = 0
	bb.MaxDistance = 300
	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundColor3 = RGB(20, 20, 26)
	frame.BackgroundTransparency = 0.15
	frame.Parent = bb
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.2, 0)
	corner.Parent = frame
	local stroke = Instance.new("UIStroke")
	stroke.Color = RGB(255, 60, 60)
	stroke.Thickness = 3
	stroke.Parent = frame
	local label = Instance.new("TextLabel")
	label.Name = "LiveLabel"
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(0.94, 0.86)
	label.Position = UDim2.fromScale(0.03, 0.07)
	label.Text = "DUEL PIT  [0 LIVE]"
	label.TextScaled = true
	label.Font = Enum.Font.GothamBlack
	label.TextColor3 = Color3.new(1, 1, 1)
	label.Parent = frame
	bb.Adornee = post
	bb.Parent = post

	-- Target practice range: shooting line at z = 92, lanes going +Z
	local range = K.Model(f, "TargetPracticeRange")
	local line = CFrame.new(110, 0, 92)
	K.Part(range, "ShootingLine", Vector3.new(40, 0.2, 1), line * CFrame.new(0, 0.1, 0), RGB(240, 240, 240), M.SmoothPlastic)
	K.Part(range, "FiringBench", Vector3.new(40, 3, 2), line * CFrame.new(0, 1.5, -2), WOOD, M.WoodPlanks)
	local trainZone = zone(range, "TrainingZone", Vector3.new(44, 12, 120), line * CFrame.new(0, 6, 55), "TrainingZone")
	trainZone:SetAttribute("CombatZone", "Training")
	for li, d in { 20, 50, 100 } do
		local laneX = -12 + (li - 1) * 12
		K.Part(range, "LaneMarker", Vector3.new(0.3, 0.2, d), line * CFrame.new(laneX - 6, 0.1, d / 2), RGB(200, 200, 200), M.SmoothPlastic)
		K.Part(range, "DummyRail" .. d, Vector3.new(14, 0.4, 0.6), line * CFrame.new(laneX, 0.2, d), DARK, M.Metal)
		trainingDummy(range, string.format("Dummy_%dStuds", d), line * CFrame.new(laneX, 0.4, d) * CFrame.Angles(0, math.pi, 0), d, 5)
		local signPart = K.Part(range, "DistanceSign" .. d, Vector3.new(4, 1.5, 0.3), line * CFrame.new(laneX, 1.2, 2), RGB(30, 30, 34), M.Slate)
		local gui = Instance.new("SurfaceGui")
		gui.Face = Enum.NormalId.Back
		gui.LightInfluence = 0
		local l = Instance.new("TextLabel")
		l.BackgroundTransparency = 1
		l.Size = UDim2.fromScale(1, 1)
		l.Text = d .. " STUDS"
		l.TextScaled = true
		l.Font = Enum.Font.GothamBold
		l.TextColor3 = RGB(255, 220, 90)
		l.Parent = gui
		gui.Parent = signPart
	end
	-- backstop berm
	K.Part(range, "Backstop", Vector3.new(44, 14, 4), line * CFrame.new(0, 7, 112), RGB(120, 100, 70), M.Ground)
end

---------------------------------------------------------------------------------------------
function Lobby.Build(parent: Folder, prefabs: Instance?)
	parent:ClearAllChildren()
	K.Part(parent, "VillageGround", Vector3.new(480, 4, 480), CFrame.new(0, -2, 0), GRASS, M.Grass)
	-- dirt paths from the plaza to each district
	for _, data in { { A = 0, L = 60 }, { A = 90, L = 60 }, { A = 180, L = 70 }, { A = 270, L = 50 } } do
		local a = math.rad(data.A)
		local dir = Vector3.new(math.cos(a), 0, math.sin(a))
		K.Part(parent, "Path", Vector3.new(10, 0.2, data.L), CFrame.lookAt(dir * (72 + data.L / 2), dir * 200) + Vector3.new(0, 0.05, 0), RGB(150, 120, 84), M.Ground)
	end
	plaza(parent)
	local booths = K.Folder(parent, "Interactive_Booths")
	loadoutStall(booths, prefabs)
	logCabin(booths)
	tribeHall(booths)
	leaderboards(parent)
	duelAndTraining(parent)
	-- village dressing: pines around the edge
	local rng = Random.new(9001)
	for i = 1, 40 do
		local a = rng:NextNumber(0, 2 * math.pi)
		local r = rng:NextNumber(160, 225)
		MapKit.PineTree(parent, Vector3.new(math.cos(a) * r, 0, math.sin(a) * r), rng:NextNumber(12, 22), false)
	end
	for _, d in parent:GetDescendants() do
		if d:IsA("BasePart") then
			local inDummy = d:FindFirstAncestorWhichIsA("Model")
			if not (inDummy and inDummy:HasTag("TrainingDummy")) then
				d.Anchored = true
				d.CollisionGroup = CollisionGroups.MapGeometry
			end
		end
	end
	parent:SetAttribute("Built", true)
end

return Lobby
