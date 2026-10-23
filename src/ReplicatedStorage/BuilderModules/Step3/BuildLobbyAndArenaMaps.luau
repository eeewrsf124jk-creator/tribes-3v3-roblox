--!strict
-- Step 3: build the lobby village (Lobby place) and the 4 symmetric arena maps (Arena place).
-- Arena maps are stored in ServerStorage.ArenaMapStorage; the round service clones the chosen
-- map into Workspace.Arena_Maps_Pool at match start. In Studio edit mode, `previewMap` also
-- places one copy in the pool so it can be inspected.

local Step1 = require(script.Parent.Parent.Step1.CollisionAndFolders)
local LobbyWorld = require(script.Parent.LobbyWorld)
local Map01 = require(script.Parent.Map01_WinterTimberFort)
local Map02 = require(script.Parent.Map02_DesertColosseum)
local Map03 = require(script.Parent.Map03_HighlandHenge)
local Map04 = require(script.Parent.Map04_IcefallFjord)

local Step3 = {}

Step3.MapBuilders = {
	{ Name = "Map_01_WinterTimberFort", Build = Map01.Build },
	{ Name = "Map_02_DesertColosseum", Build = Map02.Build },
	{ Name = "Map_03_HighlandHenge", Build = Map03.Build },
	{ Name = "Map_04_IcefallFjord", Build = Map04.Build },
}

function Step3.BuildArenaMaps(storage: Folder): { string }
	local names = {}
	for _, entry in Step3.MapBuilders do
		local old = storage:FindFirstChild(entry.Name)
		if old then
			old:Destroy()
		end
		local model = entry.Build()
		model.Parent = storage
		table.insert(names, entry.Name)
		task.wait()
	end
	storage:SetAttribute("Built", true)
	return names
end

function Step3.Run(role: string, tree: Step1.FolderTree, previewMap: string?)
	if role == "Lobby" then
		LobbyWorld.Build(tree.LobbyWorld, tree.Prefabs)
	else
		Step3.BuildArenaMaps(tree.ArenaStorage)
		if previewMap then
			tree.ArenaPool:ClearAllChildren()
			local source = tree.ArenaStorage:FindFirstChild(previewMap)
			if source then
				source:Clone().Parent = tree.ArenaPool
			end
		end
	end
end

return Step3
