--!strict
-- ClientMain: the single client entry point.
--   1. Bridges the server's state remotes into ClientState (connected first so nothing queued
--      before the controllers start is lost).
--   2. Makes sure every ScreenGui exists in PlayerGui. StarterGui copies arrive with the first
--      character; in the arena characters load late (CharacterAutoLoads = false), so missing
--      screens are generated locally by the Step 4 builder and later duplicates are dropped.
--   3. Initialises and starts the controllers in dependency order.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local Net = require(Modules.Shared.Net)
local Types = require(Modules.Shared.Types)

script.Parent:WaitForChild("Controllers"):WaitForChild("ClientState")
local Controllers = script.Parent.Controllers
local State = require(Controllers.ClientState)

local player = Players.LocalPlayer

---------------------------------------------------------------------------------------------
-- 1. State bridges
---------------------------------------------------------------------------------------------
Net.Reliable("ProfileSync").OnClientEvent:Connect(function(profile: any)
	if type(profile) == "table" then
		State.Profile = profile :: Types.Profile
		State.ProfileChanged:Fire(State.Profile :: Types.Profile)
	end
end)

Net.Reliable("InventorySync").OnClientEvent:Connect(function(view: any)
	State.Inventory = if type(view) == "table" then view :: Types.InventoryView else nil
	State.InventoryChanged:Fire(State.Inventory)
end)

Net.Reliable("RoundStateChanged").OnClientEvent:Connect(function(round: any)
	local previous = State.Round
	State.Round = if type(round) == "table" then round :: Types.RoundState else nil
	State.RoundChanged:Fire(State.Round, previous)
end)

Net.Reliable("Notify").OnClientEvent:Connect(function(text: any, kind: any)
	if type(text) == "string" then
		State.Notify:Fire(text, if type(kind) == "string" then kind else "Info")
	end
end)

---------------------------------------------------------------------------------------------
-- 2. ScreenGuis
---------------------------------------------------------------------------------------------
local playerGui = player:WaitForChild("PlayerGui") :: PlayerGui

-- keep the first copy of every screen; later copies (StarterGui after a late spawn) are removed
playerGui.ChildAdded:Connect(function(child)
	if not child:IsA("ScreenGui") then
		return
	end
	for _, other in playerGui:GetChildren() do
		if other ~= child and other:IsA("ScreenGui") and other.Name == child.Name then
			task.defer(function()
				child:Destroy()
			end)
			return
		end
	end
end)

if not game:IsLoaded() then
	game.Loaded:Wait()
end
if Workspace:GetAttribute("WorldReady") ~= true then
	local deadline = os.clock() + 30
	while Workspace:GetAttribute("WorldReady") ~= true and os.clock() < deadline do
		task.wait(0.25)
	end
end

ReplicatedStorage:WaitForChild("BuilderModules"):WaitForChild("Step4"):WaitForChild("GenerateCompleteStarterGui")
local Step4 = require(ReplicatedStorage.BuilderModules.Step4.GenerateCompleteStarterGui)
-- give the StarterGui copies a moment when a character is on its way
local waitUntil = os.clock() + (if player.Character then 1 else 5)
while os.clock() < waitUntil and playerGui:FindFirstChild("CombatHUD") == nil do
	task.wait(0.1)
end
local created = Step4.EnsureAll(playerGui)
if #created > 0 then
	print(string.format("[ClientMain] generated %d ScreenGuis locally", #created))
end

---------------------------------------------------------------------------------------------
-- 3. Controllers
---------------------------------------------------------------------------------------------
type Controller = { Init: () -> (), Start: () -> () }

local order = {
	"MovementController",
	"CameraAndViewmodelController",
	"WeaponAndProjectileController",
	"CombatFeedbackAndHUDController",
	"POTGAndVictorySequenceController",
	"LobbyUIController",
	"InputAndKeybindController",
}

local loaded: { Controller } = {}
for _, name in order do
	local module = Controllers:WaitForChild(name) :: ModuleScript
	local ok, result = pcall(require, module)
	if ok then
		table.insert(loaded, result :: any)
	else
		warn("[ClientMain] failed to load " .. name .. ": " .. tostring(result))
	end
end
for _, c in loaded do
	c.Init()
end
for _, c in loaded do
	c.Start()
end

-- replay the latest state so controllers that started after the first sync catch up
if State.Profile then
	State.ProfileChanged:Fire(State.Profile :: Types.Profile)
end
State.InventoryChanged:Fire(State.Inventory)
if State.Round then
	State.RoundChanged:Fire(State.Round, nil)
end

print("[ClientMain] client ready")
