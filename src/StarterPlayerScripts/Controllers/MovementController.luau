--!strict
-- MovementController: walk/sprint speed (base x SpeedMult attribute x draw/aim slow), the C slide
-- (WalkSpeed x1.65 decaying with friction, PlayerModule controls disabled while the humanoid is
-- driven along the slide direction), server knockback impulses and the Rooted lock.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local Net = require(Modules.Shared.Net)
local GameConfig = require(Modules.Config.GameConfig)
local SoundCatalog = require(Modules.Config.SoundCatalog)
local State = require(script.Parent.ClientState)

local Movement = {}

local MOVE = GameConfig.Movement
local SLIDE_MAX_TIME = 1.1

local player = Players.LocalPlayer
local controls: any = nil

local slideDir = Vector3.zero
local slideSpeed = 0
local slideStarted = 0
local lastSlideEnd = -10
local baseJumpPower = 50

local function getControls(): any
	if controls == nil then
		local ok, module = pcall(function()
			local scripts = player:WaitForChild("PlayerScripts")
			return require(scripts:WaitForChild("PlayerModule") :: ModuleScript) :: any
		end)
		if ok and module then
			controls = module:GetControls()
		end
	end
	return controls
end

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

local function endSlide()
	if not State.Sliding then
		return
	end
	State.Sliding = false
	lastSlideEnd = os.clock()
	local c = getControls()
	if c then
		c:Enable()
	end
	Net.Reliable("SlideRequest"):FireServer(false)
end

function Movement.TrySlide()
	local humanoid = State.Humanoid()
	local root = State.Root()
	if humanoid == nil or root == nil or State.Sliding or not State.Alive() then
		return
	end
	if os.clock() - lastSlideEnd < MOVE.SlideCooldown then
		return
	end
	local character = State.Character()
	if character and character:GetAttribute("Rooted") == true then
		return
	end
	if humanoid.FloorMaterial == Enum.Material.Air then
		return
	end
	local velocity = flat(root.AssemblyLinearVelocity)
	if velocity.Magnitude < MOVE.SlideMinSpeed then
		return
	end
	State.Sliding = true
	slideDir = velocity.Unit
	slideSpeed = math.max(velocity.Magnitude, humanoid.WalkSpeed) * MOVE.SlideBoost
	slideStarted = os.clock()
	local c = getControls()
	if c then
		c:Disable()
	end
	Net.Reliable("SlideRequest"):FireServer(true)
	SoundCatalog.Play("Slide", root, 0.08)
end

function Movement.CancelSlide()
	endSlide()
end

function Movement.SetSprinting(on: boolean)
	State.Sprinting = on
end

local function speedMult(character: Model): number
	local attr = character:GetAttribute("SpeedMult")
	return if type(attr) == "number" then attr else 1
end

local function step(dt: number)
	local humanoid = State.Humanoid()
	local character = State.Character()
	if humanoid == nil or character == nil then
		return
	end
	if humanoid.Health <= 0 then
		if State.Sliding then
			endSlide()
		end
		return
	end
	local rooted = character:GetAttribute("Rooted") == true
	local mult = speedMult(character)

	if State.Sliding then
		slideSpeed *= math.exp(-MOVE.SlideFriction * dt)
		local tooSlow = slideSpeed < MOVE.SlideMinSpeed
		local airborne = humanoid.FloorMaterial == Enum.Material.Air and os.clock() - slideStarted > 0.25
		if tooSlow or airborne or rooted or os.clock() - slideStarted > SLIDE_MAX_TIME then
			endSlide()
		else
			humanoid.WalkSpeed = slideSpeed * math.max(mult, 0.3)
			humanoid:Move(slideDir, false)
			return
		end
	end

	local base = MOVE.WalkSpeed
	local moving = humanoid.MoveDirection.Magnitude > 0.1
	local slowed = State.Drawing or State.Aiming
	if State.Sprinting and moving and not slowed then
		base = MOVE.SprintSpeed
	end
	if slowed then
		base *= MOVE.DrawWalkMultiplier
	end
	humanoid.WalkSpeed = if rooted then 0 else base * mult
	humanoid.UseJumpPower = true
	humanoid.JumpPower = if rooted then 0 else baseJumpPower
end

local function onImpulse(velocity: any)
	if typeof(velocity) ~= "Vector3" then
		return
	end
	local root = State.Root()
	local humanoid = State.Humanoid()
	if root == nil or humanoid == nil or root.Anchored then
		return
	end
	endSlide()
	local v = velocity :: Vector3
	-- lift slightly so the humanoid's ground friction does not eat the knockback
	if v.Y < 8 then
		v += Vector3.new(0, 8 - v.Y, 0)
	end
	root.AssemblyLinearVelocity += v
	humanoid:ChangeState(Enum.HumanoidStateType.Freefall)
end

local function onCharacter(character: Model)
	State.Sliding = false
	local c = getControls()
	if c then
		c:Enable()
	end
	local humanoid = character:WaitForChild("Humanoid", 10)
	if humanoid and humanoid:IsA("Humanoid") then
		baseJumpPower = if humanoid.JumpPower > 0 then humanoid.JumpPower else 50
		humanoid.StateChanged:Connect(function(_, new)
			if new == Enum.HumanoidStateType.Jumping and State.Sliding then
				endSlide()
			end
		end)
	end
end

function Movement.Init() end

function Movement.Start()
	Net.Reliable("ApplyImpulse").OnClientEvent:Connect(onImpulse)
	player.CharacterAdded:Connect(onCharacter)
	if player.Character then
		task.spawn(onCharacter, player.Character)
	end
	task.spawn(getControls)
	RunService.PreSimulation:Connect(step)
end

return Movement
