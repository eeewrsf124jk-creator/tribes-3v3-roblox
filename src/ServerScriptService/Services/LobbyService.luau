--!strict
-- LobbyService: interactive village features.
--   * ProximityPrompts with an Interface attribute open the matching ScreenGui on the client.
--   * Live 1v1 Duel Pit: two pads; when both are taken the duelists fight with their active
--     presets inside the pit. The [XX LIVE] billboard counts duelists plus spectators on the rim.
--   * Target range: walking into the TrainingZone arms your active preset; the three training
--     dummies (20 / 50 / 100 studs) sway side to side, never die and show the damage you dealt.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local Workspace = game:GetService("Workspace")

local Modules = game:GetService("ReplicatedStorage"):WaitForChild("Modules")
local Types = require(Modules.Shared.Types)
local Net = require(Modules.Shared.Net)
local Ballistics = require(Modules.Shared.BallisticsEngine)

local PlayerData = require(script.Parent.PlayerDataService)
local Combat = require(script.Parent.LagCompensatedCombatService)
local Round = require(script.Parent.RoundStateMachineService)
local Registry = require(script.Parent.Combat.CombatantRegistry)
local DamageModel = require(script.Parent.Combat.DamageModel)

type Combatant = Registry.Combatant

local Lobby = {}

local TRAINING_CONTEXT = "Training"
local DUEL_CONTEXT = "Duel"

type DummyInfo = { C: Combatant, Model: Model, Root: BasePart, Base: CFrame, Amplitude: number, Label: TextLabel?, Distance: number, ResetAt: number }

local dummies: { DummyInfo } = {}
local duelSlots: { [number]: Player? } = { [1] = nil, [2] = nil }
local duelActive = false
local duelists: { Combatant } = {}
local trainees: { [Player]: Combatant } = {}

local function lobbyWorld(): Instance?
	return Workspace:FindFirstChild("Lobby_50Player_World")
end

local function levelLookup(player: Player): (string) -> number
	local profile = PlayerData.Get(player)
	return function(itemId: string): number
		return PlayerData.ItemLevel(profile, itemId)
	end
end

local function busy(player: Player): boolean
	return Round.ForPlayer(player) ~= nil or trainees[player] ~= nil or table.find(duelSlots, player) ~= nil
end

---------------------------------------------------------------------------------------------
-- Interfaces
---------------------------------------------------------------------------------------------
local function bindPrompt(prompt: ProximityPrompt)
	prompt.Triggered:Connect(function(player)
		local interface = prompt:GetAttribute("Interface")
		if type(interface) ~= "string" then
			return
		end
		if interface == "DuelJoin" then
			local slot = prompt:GetAttribute("DuelSlot")
			if type(slot) == "number" then
				Lobby.JoinDuel(player, slot)
			end
			return
		end
		Net.Reliable("OpenInterface"):FireClient(player, interface)
	end)
end

---------------------------------------------------------------------------------------------
-- Duel pit
---------------------------------------------------------------------------------------------
local function duelPads(): { [number]: BasePart }
	local pads: { [number]: BasePart } = {}
	for _, pad in CollectionService:GetTagged("DuelPad") do
		local slot = pad:GetAttribute("DuelSlot")
		if pad:IsA("BasePart") and type(slot) == "number" then
			pads[slot] = pad
		end
	end
	return pads
end

local function endDuel(winner: Combatant?)
	if not duelActive then
		return
	end
	duelActive = false
	Combat.SetContextEnabled(DUEL_CONTEXT, false)
	local text = if winner then winner.Name .. " wins the duel!" else "The duel ended in a draw"
	for _, p in Players:GetPlayers() do
		PlayerData.Notify(p, "⚔ " .. text, "Info")
	end
	local list = duelists
	duelists = {}
	task.delay(3, function()
		for _, c in list do
			local player = c.Player
			Combat.Remove(c)
			if player and player.Parent == Players then
				player:LoadCharacterAsync()
			end
		end
		Combat.ClearContext(DUEL_CONTEXT)
	end)
end

local function startDuel()
	local a, b = duelSlots[1], duelSlots[2]
	if a == nil or b == nil or duelActive then
		return
	end
	duelSlots[1], duelSlots[2] = nil, nil
	local pads = duelPads()
	duelActive = true
	duelists = {}
	for i, player in { a, b } do
		local trainee = trainees[player]
		if trainee then
			Combat.Remove(trainee)
			trainees[player] = nil
		end
		local team: Types.TeamName = if i == 1 then "Alpha" else "Bravo"
		local c = Combat.AddPlayer(player, team, DUEL_CONTEXT)
		local pad = pads[i]
		if c and pad then
			Combat.Arm(c, PlayerData.ActiveLoadout(player), levelLookup(player))
			local other = pads[3 - i]
			local pos = pad.Position + Vector3.new(0, 3.2, 0)
			local look = if other then Vector3.new(other.Position.X, pos.Y, other.Position.Z) else pos + Vector3.zAxis
			Combat.SpawnAt(c, CFrame.lookAt(pos, look))
			table.insert(duelists, c)
			PlayerData.Notify(player, "Duel starts in 3...", "Info")
		end
	end
	if #duelists < 2 then
		endDuel(nil)
		return
	end
	task.delay(3, function()
		if duelActive then
			Combat.SetContextEnabled(DUEL_CONTEXT, true)
			for _, c in duelists do
				if c.Player then
					PlayerData.Notify(c.Player, "FIGHT!", "Success")
				end
			end
		end
	end)
end

function Lobby.JoinDuel(player: Player, slot: number)
	if slot ~= 1 and slot ~= 2 then
		return
	end
	if duelActive then
		PlayerData.Notify(player, "A duel is in progress - wait for it to finish", "Error")
		return
	end
	if Round.ForPlayer(player) then
		return
	end
	if duelSlots[slot] ~= nil and duelSlots[slot] ~= player then
		PlayerData.Notify(player, "That side is taken", "Error")
		return
	end
	local other = 3 - slot
	if duelSlots[other] == player then
		duelSlots[other] = nil
	end
	duelSlots[slot] = player
	PlayerData.Notify(player, "Waiting for an opponent on the other pad...", "Info")
	if duelSlots[1] and duelSlots[2] then
		startDuel()
	end
end

---------------------------------------------------------------------------------------------
-- Training range
---------------------------------------------------------------------------------------------
local function setupDummy(model: Model)
	local root = model:FindFirstChild("HumanoidRootPart")
	if root == nil or not root:IsA("BasePart") then
		return
	end
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid == nil then
		local h = Instance.new("Humanoid")
		h.RequiresNeck = false
		h.BreakJointsOnDeath = false
		h.EvaluateStateMachine = false
		h.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		h.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
		h.MaxHealth = 100
		h.Health = 100
		h.Parent = model
	end
	local c = Registry.New("Dummy_" .. model.Name, "Training Dummy", "Bravo", TRAINING_CONTEXT)
	c.IsDummy = true
	Registry.BindCharacter(c, model)
	c.Alive = true
	Registry.Add(c)
	local amp = model:GetAttribute("Amplitude")
	local dist = model:GetAttribute("Distance")
	local board = model:FindFirstChild("DamageBoard")
	local label = if board then board:FindFirstChild("Label") else nil
	table.insert(dummies, {
		C = c,
		Model = model,
		Root = root,
		Base = root.CFrame,
		Amplitude = if type(amp) == "number" then amp else 5,
		Label = if label and label:IsA("TextLabel") then label else nil,
		Distance = if type(dist) == "number" then dist else 0,
		ResetAt = 0,
	})
end

local function trainingZones(): { BasePart }
	local zones: { BasePart } = {}
	local world = lobbyWorld()
	if world then
		for _, d in world:GetDescendants() do
			if d:IsA("BasePart") and d:GetAttribute("CombatZone") == "Training" then
				table.insert(zones, d)
			end
		end
	end
	return zones
end

local function updateTrainees(zones: { BasePart })
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
		local inside = false
		if root and root:IsA("BasePart") then
			for _, z in zones do
				if Ballistics.PointInOBB(root.Position, z.CFrame, z.Size, 0) then
					inside = true
					break
				end
			end
		end
		local current = trainees[player]
		if inside and current == nil and not busy(player) then
			local c = Combat.AddPlayer(player, "Alpha", TRAINING_CONTEXT)
			if c then
				Combat.Arm(c, PlayerData.ActiveLoadout(player), levelLookup(player))
				c.Alive = true
				-- arm in place without teleporting
				if c.Root then
					Combat.SpawnAt(c, (c.Root :: BasePart).CFrame)
				end
				trainees[player] = c
				Combat.SetContextEnabled(TRAINING_CONTEXT, true)
				PlayerData.Notify(player, "Target range: your active preset is armed", "Info")
			end
		elseif current and (not inside or current.Character ~= character) then
			Combat.Remove(current)
			trainees[player] = nil
		end
	end
end

---------------------------------------------------------------------------------------------
-- Live billboard
---------------------------------------------------------------------------------------------
local function updateBillboard()
	local world = lobbyWorld()
	if world == nil then
		return
	end
	local bb = world:FindFirstChild("LiveBillboard", true)
	local label = if bb then bb:FindFirstChild("LiveLabel", true) else nil
	if label == nil or not label:IsA("TextLabel") then
		return
	end
	local zone = world:FindFirstChild("DuelZone", true)
	local center = if zone and zone:IsA("BasePart") then zone.Position else Vector3.new(0, 0, 130)
	local live = 0
	for _, p in Players:GetPlayers() do
		local character = p.Character
		local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
		if root and root:IsA("BasePart") and (root.Position - center).Magnitude <= 45 then
			live += 1
		end
	end
	label.Text = string.format("DUEL PIT  [%d LIVE]", live)
end

---------------------------------------------------------------------------------------------
function Lobby.Start()
	local world = lobbyWorld()
	if world == nil then
		warn("[Lobby] Lobby_50Player_World is missing; run the builder")
		return
	end
	for _, d in world:GetDescendants() do
		if d:IsA("ProximityPrompt") and d:GetAttribute("Interface") ~= nil then
			bindPrompt(d)
		end
	end
	for _, model in CollectionService:GetTagged("TrainingDummy") do
		if model:IsA("Model") then
			setupDummy(model)
		end
	end
	Combat.SetContextEnabled(TRAINING_CONTEXT, true)

	DamageModel.Damaged:Connect(function(victim: Combatant, attacker: Combatant?, report: Types.DamageReport)
		if not victim.IsDummy then
			return
		end
		for _, d in dummies do
			if d.C == victim and d.Label then
				local total = math.floor(report.Amount + report.ArmorAmount + 0.5)
				local label = d.Label :: TextLabel
				label.Text = if report.Headshot then string.format("HEADSHOT  -%d", total) else string.format("-%d", total)
				label.TextColor3 = if report.Headshot then Color3.fromRGB(255, 220, 60) else Color3.new(1, 1, 1)
				d.ResetAt = os.clock() + 2
			end
		end
	end)
	DamageModel.Killed:Connect(function(victim: Combatant, attacker: Combatant?)
		if victim.Context == DUEL_CONTEXT and duelActive then
			endDuel(attacker)
		end
		if victim.Context == TRAINING_CONTEXT and victim.Player then
			trainees[victim.Player] = nil
			Combat.Remove(victim)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		for slot, p in duelSlots do
			if p == player then
				duelSlots[slot] = nil
			end
		end
		trainees[player] = nil
		if duelActive then
			for _, c in duelists do
				if c.Player == player then
					local other: Combatant? = nil
					for _, o in duelists do
						if o ~= c then
							other = o
						end
					end
					endDuel(other)
					break
				end
			end
		end
	end)

	local zones = trainingZones()
	task.spawn(function()
		while true do
			task.wait(0.5)
			updateTrainees(zones)
			-- duel pad occupants who walked away lose their slot
			local pads = duelPads()
			for slot, p in duelSlots do
				local pad = pads[slot]
				local character = if p then p.Character else nil
				local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
				if p and pad and (root == nil or not root:IsA("BasePart") or (root.Position - pad.Position).Magnitude > 14) then
					duelSlots[slot] = nil
					PlayerData.Notify(p, "You left the duel pad", "Info")
				end
			end
		end
	end)
	task.spawn(function()
		while true do
			updateBillboard()
			task.wait(2)
		end
	end)

	RunService.Heartbeat:Connect(function()
		local t = os.clock()
		for i, d in dummies do
			local offset = math.sin(t * 0.8 + i * 1.3) * d.Amplitude
			d.Root.CFrame = d.Base * CFrame.new(offset, 0, 0)
			if d.ResetAt > 0 and t >= d.ResetAt and d.Label then
				d.ResetAt = 0
				local label = d.Label :: TextLabel
				label.Text = string.format("%d STUDS", d.Distance)
				label.TextColor3 = Color3.new(1, 1, 1)
			end
		end
	end)
end

return Lobby
