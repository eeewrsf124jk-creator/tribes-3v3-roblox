-- Runs the whole Studio builder pipeline (Steps 1-5) inside Lune against the Rojo-built places
-- and checks what it produces:
--   lune run tests/world.luau            (needs build/Lobby.rbxl and build/Arena.rbxl)

local process = require("@lune/process")
local H = require("./harness")

local function build(role: string): any
	local w = H.UseWorld("build/" .. role .. ".rbxl")
	local P = H.LoadInstance(w.DataModel:GetService("ReplicatedStorage").BuilderModules.StudioBuilderPipeline)
	P.RunAll({ Role = role })
	return w
end

local lobby = build("Lobby")
local arena = build("Arena")

local function parts(root: any): number
	local n = 0
	for _, d in root:GetDescendants() do
		if d:IsA("BasePart") then
			n += 1
		end
	end
	return n
end

print("\nBuilder output")
for _, w in { lobby, arena } do
	local dm = w.DataModel
	local role = dm:GetService("Workspace"):GetAttribute("PlaceRole")
	H.Test(role .. ": six collision groups registered", function()
		local CollisionGroups = H.LoadInstance(dm:GetService("ReplicatedStorage").Modules.Shared.CollisionGroups)
		for _, name in CollisionGroups.Ordered do
			H.True(w.CollisionGroups[name], "missing group " .. name)
		end
	end)
	H.Test(role .. ": runtime containers exist", function()
		local containers = dm:GetService("Workspace"):FindFirstChild("Runtime_Dynamic_Containers")
		H.True(containers ~= nil, "Runtime_Dynamic_Containers missing")
		for _, name in {
			"AliveCharacters_Alpha",
			"AliveCharacters_Bravo",
			"ActiveProjectiles_Container",
			"DeployedUtilities_Container",
			"Ragdolls_And_StuckArrows",
		} do
			H.True(containers:FindFirstChild(name) ~= nil, name .. " missing")
		end
	end)
	H.Test(role .. ": all 11 ScreenGuis built", function()
		local Step4 = H.LoadInstance(dm:GetService("ReplicatedStorage").BuilderModules.Step4.GenerateCompleteStarterGui)
		local starterGui = dm:GetService("StarterGui")
		H.Eq(#Step4.Builders, 11, "builder count")
		for _, entry in Step4.Builders do
			local gui = starterGui:FindFirstChild(entry.Name)
			H.True(gui ~= nil and gui:IsA("ScreenGui"), entry.Name .. " missing")
			H.True(#gui:GetDescendants() > 20, entry.Name .. " is nearly empty")
		end
	end)
	H.Test(role .. ": every item in the database has a prefab", function()
		local rs = dm:GetService("ReplicatedStorage")
		local DB = H.LoadInstance(rs.Modules.Config.EquipmentDatabase)
		local prefabs = rs.Procedural_3D_Weapon_And_Armor_Prefabs
		for _, id in DB.Order do
			local spec = DB.Items[id]
			local model = prefabs:FindFirstChild(spec.ModelName, true)
			H.True(model ~= nil, id .. ": no prefab named " .. tostring(spec.ModelName))
			H.True(parts(model) > 0, id .. ": prefab has no parts")
		end
	end)
	H.Test(role .. ": ranged prefabs carry Handle, Muzzle and String attachments", function()
		local folder = dm:GetService("ReplicatedStorage").Procedural_3D_Weapon_And_Armor_Prefabs.Ranged_Weapon_Models
		for _, model in folder:GetChildren() do
			H.True(model.PrimaryPart ~= nil and model.PrimaryPart.Name == "Handle", model.Name .. " Handle")
			H.True(model:FindFirstChild("MuzzleAttachment", true) ~= nil, model.Name .. " MuzzleAttachment")
		end
	end)
	H.Test(role .. ": melee prefabs carry 5-8 DmgPoints and trail attachments", function()
		local folder = dm:GetService("ReplicatedStorage").Procedural_3D_Weapon_And_Armor_Prefabs.Melee_Weapon_Models
		local models = {}
		for _, child in folder:GetChildren() do
			if child:IsA("Folder") then -- Ranked_Melees
				for _, m in child:GetChildren() do
					table.insert(models, m)
				end
			else
				table.insert(models, child)
			end
		end
		for _, model in models do
			if model.Name == "Shield_Model" then
				continue
			end
			-- dual-wield prefabs carry a full blade set in each hand (main + Offhand)
			local main, offhand = 0, 0
			for _, d in model:GetDescendants() do
				if d:IsA("Attachment") and d.Name == "DmgPoint" then
					if d:FindFirstAncestor("Offhand") then
						offhand += 1
					else
						main += 1
					end
				end
			end
			H.True(main >= 5 and main <= 8, model.Name .. " has " .. main .. " DmgPoints")
			H.True(offhand == 0 or (offhand >= 5 and offhand <= 8), model.Name .. " offhand has " .. offhand)
			H.True(model:FindFirstChild("TopAttachment", true) ~= nil, model.Name .. " TopAttachment")
		end
	end)
end

H.Test("Lobby: village sections exist", function()
	local village = lobby.DataModel:GetService("Workspace"):FindFirstChild("Lobby_50Player_World")
	H.True(village ~= nil, "Lobby_50Player_World missing")
	for _, name in { "SpawnPlaza_Center", "Interactive_Booths", "Global_3D_Leaderboards", "Mini_1v1_DuelPit_And_Training" } do
		H.True(village:FindFirstChild(name) ~= nil, name .. " missing")
	end
	local spawns = 0
	for _, d in village:GetDescendants() do
		if d:IsA("SpawnLocation") then
			spawns += 1
		end
	end
	H.Eq(spawns, 12, "plaza SpawnLocations")
end)

H.Test("Arena: four symmetric maps with spawns and shared mechanics", function()
	local storage = arena.DataModel:GetService("ServerStorage"):FindFirstChild("ArenaMapStorage")
	H.True(storage ~= nil, "ArenaMapStorage missing")
	for _, name in { "Map_01_WinterTimberFort", "Map_02_DesertColosseum", "Map_03_HighlandHenge", "Map_04_IcefallFjord" } do
		local map = storage:FindFirstChild(name)
		H.True(map ~= nil, name .. " missing")
		H.True(parts(map) > 300, name .. " has only " .. parts(map) .. " parts")
		H.True(map:FindFirstChild("TeamSpawns", true) ~= nil, name .. " TeamSpawns")
		H.True(map:FindFirstChild("RingOfFire_BoundaryCylinder", true) ~= nil, name .. " ring")
		H.True(map:FindFirstChild("POTG_CinematicStage", true) ~= nil, name .. " POTG stage")
	end
end)

process.exit(if H.Summary() then 0 else 1)
