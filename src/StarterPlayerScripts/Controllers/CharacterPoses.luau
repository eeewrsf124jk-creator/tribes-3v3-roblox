--!strict
-- CharacterPoses: procedural upper-body poses layered on top of whatever the Animator plays.
-- Every PreSimulation step (after animations have written Motor6D.Transform for the frame) each
-- tracked R15 rig gets an extra rotation per joint, driven by replicated character attributes:
--   aim pitch (Waist + Neck), bow hold and string draw (DrawRatio), firearm hold, melee idle,
--   swing arc (SwingAt), block guard (Blocking), healing (HealingUntil), slide lean (Sliding),
--   stagger wobble (StaggerUntil).
-- Joints an animation does not touch keep last frame's Transform, so the base pose is
-- remembered per motor and the offset is re-applied to it instead of accumulating.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local EquipmentDatabase = require(Modules.Config.EquipmentDatabase)
local EquipmentRig = require(Modules.Shared.EquipmentRig)
local Net = require(Modules.Shared.Net)
local State = require(script.Parent.ClientState)

local Poses = {}

type Rig = {
	Model: Model,
	Motors: { [string]: Motor6D? },
	Base: { [Motor6D]: CFrame? },
	Written: { [Motor6D]: CFrame? },
	Pitch: number,
}

local JOINTS: { [string]: string } = {
	Waist = "UpperTorso",
	Neck = "Head",
	RightShoulder = "RightUpperArm",
	LeftShoulder = "LeftUpperArm",
	RightElbow = "RightLowerArm",
	LeftElbow = "LeftLowerArm",
	Root = "LowerTorso",
	RightHip = "RightUpperLeg",
	LeftHip = "LeftUpperLeg",
	RightKnee = "RightLowerLeg",
	LeftKnee = "LeftLowerLeg",
}

local rigs: { [Model]: Rig } = {}
local pitchById: { [string]: number } = {}
local ownPitch: (() -> number)? = nil

local rad = math.rad

local function bindRig(model: Model): Rig?
	local motors: { [string]: Motor6D? } = {}
	for joint, partName in JOINTS do
		local part = model:FindFirstChild(partName)
		local motor = if part then part:FindFirstChild(joint) else nil
		if motor and motor:IsA("Motor6D") then
			motors[joint] = motor
		end
	end
	if motors.Waist == nil or motors.RightShoulder == nil then
		return nil
	end
	return { Model = model, Motors = motors, Base = {}, Written = {}, Pitch = 0 }
end

function Poses.Track(model: Model)
	if rigs[model] then
		return
	end
	task.spawn(function()
		-- R15 joints arrive a moment after the model replicates
		local torso = model:WaitForChild("UpperTorso", 10)
		if torso == nil or model.Parent == nil then
			return
		end
		model:WaitForChild("RightUpperArm", 5)
		local rig = bindRig(model)
		if rig then
			rigs[model] = rig
			model.AncestryChanged:Connect(function(_, parent)
				if parent == nil then
					rigs[model] = nil
				end
			end)
		end
	end)
end

function Poses.Untrack(model: Model)
	rigs[model] = nil
end

function Poses.SetOwnPitchSource(fn: () -> number)
	ownPitch = fn
end

-- offsets requested this frame, composed per motor and written once in commit()
local pending: { [Motor6D]: CFrame? } = {}

local function apply(rig: Rig, joint: string, offset: CFrame)
	local motor = rig.Motors[joint]
	if motor == nil then
		return
	end
	pending[motor] = (pending[motor] or CFrame.identity) * offset
end

local function commit(rig: Rig)
	for _, m in rig.Motors do
		local motor = m :: Motor6D
		local current = motor.Transform
		local written = rig.Written[motor]
		-- unchanged since our last write = no animation drives this joint: reuse the stored base
		local base = if written ~= nil and current == written then (rig.Base[motor] or CFrame.identity) else current
		local offset = pending[motor]
		if offset then
			rig.Base[motor] = base
			local result = base * offset
			motor.Transform = result
			rig.Written[motor] = result
		elseif written ~= nil then
			-- pose released: put an undriven joint back to its base
			if current == written then
				motor.Transform = base
			end
			rig.Written[motor] = nil
			rig.Base[motor] = nil
		end
	end
	table.clear(pending)
end

local function num(model: Model, name: string): number
	local v = model:GetAttribute(name)
	return if type(v) == "number" then v else 0
end

local function poseRig(rig: Rig, now: number, dt: number)
	local model = rig.Model
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid == nil or humanoid.Health <= 0 or model:GetAttribute("Dead") == true then
		commit(rig)
		return
	end
	-- aim pitch: our own camera, the server relay for others, or the POTG frame attribute
	local target = 0
	if model == State.Character() and ownPitch then
		target = ownPitch()
	else
		local id = model:GetAttribute("CombatantId")
		if type(id) == "string" and pitchById[id] then
			target = pitchById[id]
		else
			target = num(model, "Pitch")
		end
	end
	rig.Pitch += (target - rig.Pitch) * math.min(dt * 14, 1)
	local pitch = math.clamp(rig.Pitch, -1.2, 1.2)

	local itemId = model:GetAttribute("EquippedItem")
	local spec = if type(itemId) == "string" then EquipmentDatabase.Get(itemId) else nil
	local subType = if spec then spec.SubType else "NONE"
	local blocking = model:GetAttribute("Blocking") == true
	local healing = num(model, "HealingUntil") > now
	local sliding = model:GetAttribute("Sliding") == true
	local staggered = num(model, "StaggerUntil") > now
	local draw = if model == State.Character() then State.DrawRatio else num(model, "DrawRatio")
	local swingAge = now - num(model, "SwingAt")

	apply(rig, "Waist", CFrame.Angles(pitch * 0.45, 0, 0))
	apply(rig, "Neck", CFrame.Angles(pitch * 0.4, 0, 0))

	if healing then
		apply(rig, "RightShoulder", CFrame.Angles(rad(105), 0, rad(-20)))
		apply(rig, "RightElbow", CFrame.Angles(rad(100), 0, 0))
	elseif subType == "BOW" then
		-- bow arm straight out, string hand pulled back to the cheek with the draw
		apply(rig, "LeftShoulder", CFrame.Angles(rad(90) + pitch * 0.5, 0, rad(-10)))
		apply(rig, "RightShoulder", CFrame.Angles(rad(85) + pitch * 0.5, 0, rad(25 + 35 * draw)))
		apply(rig, "RightElbow", CFrame.Angles(rad(30 + 100 * draw), 0, 0))
	elseif subType == "GUN" then
		apply(rig, "RightShoulder", CFrame.Angles(rad(88) + pitch * 0.55, 0, rad(10)))
		apply(rig, "LeftShoulder", CFrame.Angles(rad(80) + pitch * 0.55, 0, rad(-35)))
		apply(rig, "LeftElbow", CFrame.Angles(rad(25), 0, 0))
		-- the lock hammer snaps forward on the shot and re-cocks over the reload
		local held = model:FindFirstChild(EquipmentRig.HeldName)
		local hammer = if held then held:FindFirstChild("HammerMotor", true) else nil
		if hammer and hammer:IsA("Motor6D") then
			local since = now - num(model, "LastShotAt")
			local reload = if spec and spec.ReloadTime then spec.ReloadTime else 1
			local fired = 0
			if since >= 0 and since < reload then
				fired = if since < 0.12 then 1 else 1 - math.clamp((since - 0.12) / math.max(reload * 0.6, 0.1), 0, 1)
			end
			hammer.Transform = CFrame.Angles(rad(-35) * fired, 0, 0)
		end
	elseif subType == "MELEE" then
		local rate = if spec then (spec.SwingRate or 0.5) else 0.5
		local swingTime = math.clamp(rate * 0.7, 0.18, 0.45)
		if swingAge >= 0 and swingAge < swingTime then
			local t = swingAge / swingTime
			local arc = 1 - (1 - t) * (1 - t)
			apply(rig, "RightShoulder", CFrame.Angles(rad(165 - 140 * arc), 0, rad(-30 + 70 * arc)))
			apply(rig, "Waist", CFrame.Angles(0, rad(25 - 55 * arc), 0))
		elseif blocking then
			apply(rig, "RightShoulder", CFrame.Angles(rad(95), 0, rad(-55)))
			apply(rig, "RightElbow", CFrame.Angles(rad(45), 0, 0))
		elseif draw > 0 then
			-- heavy weapon charging an overhead
			apply(rig, "RightShoulder", CFrame.Angles(rad(120 + 45 * draw), 0, rad(-15)))
			apply(rig, "LeftShoulder", CFrame.Angles(rad(110 + 45 * draw), 0, rad(20)))
		else
			apply(rig, "RightShoulder", CFrame.Angles(rad(35), 0, rad(-8)))
			apply(rig, "RightElbow", CFrame.Angles(rad(35), 0, 0))
		end
	elseif subType == "SHIELD" then
		if blocking then
			apply(rig, "LeftShoulder", CFrame.Angles(rad(92) + pitch * 0.4, 0, rad(-40)))
			apply(rig, "LeftElbow", CFrame.Angles(rad(70), 0, 0))
		else
			apply(rig, "LeftShoulder", CFrame.Angles(rad(30), 0, rad(-10)))
		end
	elseif subType == "THROWABLE" or (spec and spec.Category == "UTILITY") then
		local recent = swingAge >= 0 and swingAge < 0.3
		local lastShot = now - num(model, "LastShotAt")
		if (lastShot >= 0 and lastShot < 0.3) or recent then
			local t = math.clamp(lastShot / 0.3, 0, 1)
			apply(rig, "RightShoulder", CFrame.Angles(rad(170 - 120 * t), 0, 0))
		elseif draw > 0 and itemId == "Sling" then
			-- whirl the sling overhead: the hand traces a circle that speeds up with the charge
			local w = now * (10 + 14 * draw)
			apply(rig, "RightShoulder", CFrame.Angles(rad(160) + math.sin(w) * rad(18), 0, math.cos(w) * rad(18)))
			apply(rig, "RightElbow", CFrame.Angles(rad(20), 0, 0))
		elseif draw > 0 then
			apply(rig, "RightShoulder", CFrame.Angles(rad(150 + 20 * draw), 0, rad(-10)))
			apply(rig, "RightElbow", CFrame.Angles(rad(60 * draw), 0, 0))
		else
			apply(rig, "RightShoulder", CFrame.Angles(rad(40) + pitch * 0.3, 0, 0))
		end
	end

	if sliding then
		apply(rig, "Root", CFrame.new(0, -1.1, 0) * CFrame.Angles(rad(-28), 0, 0))
		apply(rig, "RightHip", CFrame.Angles(rad(70), 0, 0))
		apply(rig, "RightKnee", CFrame.Angles(rad(-10), 0, 0))
		apply(rig, "LeftHip", CFrame.Angles(rad(25), 0, 0))
		apply(rig, "LeftKnee", CFrame.Angles(rad(-75), 0, 0))
	end
	if staggered then
		local w = math.sin(now * 22) * rad(9)
		apply(rig, "Waist", CFrame.Angles(rad(-12), w, w * 0.5))
		apply(rig, "Neck", CFrame.Angles(rad(-15), 0, w))
	end
	commit(rig)
end

local function scan(container: Instance)
	for _, m in container:GetChildren() do
		if m:IsA("Model") and m:FindFirstChildOfClass("Humanoid") then
			Poses.Track(m)
		end
	end
end

function Poses.Start()
	local function watchPlayer(p: Player)
		p.CharacterAdded:Connect(Poses.Track)
		if p.Character then
			Poses.Track(p.Character)
		end
	end
	Players.PlayerAdded:Connect(watchPlayer)
	for _, p in Players:GetPlayers() do
		watchPlayer(p)
	end
	-- bots live in the alive-character folders
	task.spawn(function()
		local runtime = Workspace:WaitForChild("Runtime_Dynamic_Containers", 60)
		if runtime == nil then
			return
		end
		for _, name in { "AliveCharacters_Alpha", "AliveCharacters_Bravo" } do
			local f = runtime:WaitForChild(name, 30)
			if f then
				scan(f)
				f.ChildAdded:Connect(function(child)
					if child:IsA("Model") then
						Poses.Track(child)
					end
				end)
			end
		end
	end)
	Net.Unreliable("ReplicateCharacterState").OnClientEvent:Connect(function(relay: any)
		if type(relay) ~= "table" then
			return
		end
		for id, pitch in relay do
			if type(id) == "string" and type(pitch) == "number" then
				pitchById[id] = pitch
			end
		end
	end)
	RunService.PreSimulation:Connect(function(dt)
		local now = Workspace:GetServerTimeNow()
		for model, rig in rigs do
			if model.Parent == nil then
				rigs[model] = nil
			else
				poseRig(rig, now, dt)
			end
		end
	end)
end

return Poses
