--!strict
-- CameraAndViewmodelController
--   Combat camera (any time the server has armed us, or while spectating): scriptable camera
--   with mouse-locked yaw/pitch, the character turned to the camera yaw.
--     Third person: over-the-shoulder offset (+-2.5, 1.5, 6.5) on a spring, X swaps shoulders,
--                   wall collision pulls the camera in, C slide drops it by 2.2 studs.
--     First person: camera at the head, body hidden with LocalTransparencyModifier = 1 and a
--                   local viewmodel (arms + a clone of the held prefab) drawn in front.
--   ADS: FOV springs to the weapon's ZoomFOVAds (WoodBow 55, Headhunter 40, Musket 45) and the
--   look sensitivity scales with the zoom. Recoil and screen shake are springs added to pitch/yaw.
--   Camera sensitivity, FOV (70-120) and view bobbing come from the profile and apply live.
--   Outside combat the default Roblox camera runs so the lobby HUD stays clickable.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local GameConfig = require(Modules.Config.GameConfig)
local EquipmentDatabase = require(Modules.Config.EquipmentDatabase)
local SpringPhysics = require(Modules.Shared.SpringPhysics)
local EquipmentRig = require(Modules.Shared.EquipmentRig)
local State = require(script.Parent.ClientState)

local CameraController = {}

local CAM = GameConfig.Camera
local MOUSE_RADIANS_PER_PIXEL = 0.0042
local GAMEPAD_RADIANS_PER_SECOND = 4.2
local TOUCH_RADIANS_PER_PIXEL = 0.006
local PITCH_LIMIT = math.rad(80)

local player = Players.LocalPlayer

local yaw = 0
local pitch = 0
local active = false
local lastActive = false
local sensitivity = 1
local baseFov = CAM.DefaultFOV
local bobbingEnabled = true
local bobPhase = 0
local bobAmount = 0

local shoulderSpring = SpringPhysics.new(CAM.RightShoulder, 0.85, 14)
local dropSpring = SpringPhysics.scalar(0, 0.9, 16)
local fovSpring = SpringPhysics.scalar(CAM.DefaultFOV, 0.95, 18)
local recoilSpring = SpringPhysics.new(Vector3.zero, 0.55, 22)
local shakeSpring = SpringPhysics.new(Vector3.zero, 0.35, 30)
local swaySpring = SpringPhysics.new(Vector3.zero, 0.7, 16)
local adsSpring = SpringPhysics.scalar(0, 0.9, 18)

local gamepadLook = Vector2.zero
local touchDelta = Vector2.zero
local lookTouch: InputObject? = nil
local lastMouseDelta = Vector2.zero

-- character parts hidden in first person
local hiddenParts: { BasePart | Decal } = {}
local hiddenChar: Model? = nil
local hiddenApplied = false

-- viewmodel
local viewmodel: Model? = nil
local viewmodelItem: string? = nil
local vmWeapon: Model? = nil
local vmRightArm: BasePart? = nil
local vmLeftArm: BasePart? = nil
local swingStarted = -10
local swingHeavy = false

local function camera(): Camera
	return Workspace.CurrentCamera :: Camera
end

local function rayParams(exclude: { Instance }): RaycastParams
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.IgnoreWater = true
	local list = table.clone(exclude)
	local runtime = Workspace:FindFirstChild("Runtime_Dynamic_Containers")
	if runtime then
		for _, name in { "ActiveProjectiles_Container", "Ragdolls_And_StuckArrows", "AliveCharacters_Alpha", "AliveCharacters_Bravo" } do
			local f = runtime:FindFirstChild(name)
			if f then
				table.insert(list, f)
			end
		end
	end
	for _, p in Players:GetPlayers() do
		if p.Character then
			table.insert(list, p.Character)
		end
	end
	table.insert(list, camera())
	params.FilterDescendantsInstances = list
	return params
end

---------------------------------------------------------------------------------------------
-- Settings
---------------------------------------------------------------------------------------------
local function applySettings()
	local profile = State.Profile
	if profile == nil then
		return
	end
	sensitivity = math.clamp(profile.Settings.CameraSensitivity, 0.1, 3)
	baseFov = math.clamp(profile.Settings.FieldOfView, CAM.MinFOV, CAM.MaxFOV)
	bobbingEnabled = profile.Settings.ViewBobbing
end

---------------------------------------------------------------------------------------------
-- First-person body hiding
---------------------------------------------------------------------------------------------
local function collectHidden(character: Model)
	hiddenChar = character
	table.clear(hiddenParts)
	for _, d in character:GetDescendants() do
		if d:IsA("BasePart") or d:IsA("Decal") then
			table.insert(hiddenParts, d)
		end
	end
	character.DescendantAdded:Connect(function(d)
		if hiddenChar == character and (d:IsA("BasePart") or d:IsA("Decal")) then
			table.insert(hiddenParts, d)
			if hiddenApplied then
				(d :: any).LocalTransparencyModifier = 1
			end
		end
	end)
end

local function setBodyHidden(hidden: boolean)
	local character = State.Character()
	if character and character ~= hiddenChar then
		collectHidden(character)
	end
	if hidden == hiddenApplied and not hidden then
		return
	end
	hiddenApplied = hidden
	local value = if hidden then 1 else 0
	for _, p in hiddenParts do
		if p.Parent then
			(p :: any).LocalTransparencyModifier = value
		end
	end
end

---------------------------------------------------------------------------------------------
-- Viewmodel
---------------------------------------------------------------------------------------------
local function destroyViewmodel()
	if viewmodel then
		viewmodel:Destroy()
	end
	viewmodel = nil
	vmWeapon = nil
	vmRightArm = nil
	vmLeftArm = nil
	viewmodelItem = nil
end

local function armPart(parent: Instance, name: string, color: Color3): BasePart
	local p = Instance.new("Part")
	p.Name = name
	p.Size = Vector3.new(0.42, 0.42, 1.6)
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Parent = parent
	local hand = Instance.new("Part")
	hand.Name = "Hand"
	hand.Shape = Enum.PartType.Ball
	hand.Size = Vector3.new(0.5, 0.5, 0.5)
	hand.Color = color
	hand.Material = Enum.Material.SmoothPlastic
	hand.Anchored = true
	hand.CanCollide = false
	hand.CanQuery = false
	hand.CanTouch = false
	hand.CastShadow = false
	hand.Parent = p
	return p
end

local function bodyColor(character: Model, partName: string, fallback: Color3): Color3
	local part = character:FindFirstChild(partName)
	if part and part:IsA("BasePart") then
		return part.Color
	end
	return fallback
end

local function buildViewmodel(itemId: string?)
	destroyViewmodel()
	local character = State.Character()
	if character == nil then
		return
	end
	local model = Instance.new("Model")
	model.Name = "LocalViewmodel"
	local sleeve = bodyColor(character, "RightUpperArm", Color3.fromRGB(200, 170, 140))
	vmRightArm = armPart(model, "RightArm", bodyColor(character, "RightHand", sleeve))
	vmLeftArm = armPart(model, "LeftArm", bodyColor(character, "LeftHand", sleeve))
	if itemId then
		local prefab = EquipmentRig.GetPrefab(itemId)
		if prefab then
			local weapon = prefab:Clone()
			weapon.Name = "Weapon"
			for _, d in weapon:GetDescendants() do
				if d:IsA("BasePart") then
					d.Anchored = true
					d.CanCollide = false
					d.CanQuery = false
					d.CanTouch = false
					d.CastShadow = false
				elseif d:IsA("BaseScript") or d:IsA("Sound") then
					d:Destroy()
				elseif d:IsA("JointInstance") or d:IsA("WeldConstraint") then
					d:Destroy()
				end
			end
			if weapon.PrimaryPart == nil then
				local handle = weapon:FindFirstChild("Handle", true)
				if handle and handle:IsA("BasePart") then
					weapon.PrimaryPart = handle
				end
			end
			weapon.Parent = model
			vmWeapon = weapon
		end
	end
	model.Parent = camera()
	viewmodel = model
	viewmodelItem = itemId
end

local function placeArm(arm: BasePart?, shoulder: Vector3, hand: Vector3)
	if arm == nil then
		return
	end
	local delta = hand - shoulder
	local length = math.max(delta.Magnitude, 0.3)
	arm.Size = Vector3.new(0.42, 0.42, length)
	arm.CFrame = CFrame.lookAt((shoulder + hand) / 2, hand)
	local h = arm:FindFirstChild("Hand")
	if h and h:IsA("BasePart") then
		h.CFrame = CFrame.new(hand)
	end
end

local function updateViewmodel(camCF: CFrame, dt: number)
	local character = State.Character()
	local itemAttr = if character then character:GetAttribute("EquippedItem") else nil
	local itemId: string? = if type(itemAttr) == "string" then itemAttr else nil
	if viewmodel == nil or viewmodelItem ~= itemId then
		buildViewmodel(itemId)
	end
	local model = viewmodel
	if model == nil then
		return
	end
	local spec = if itemId then EquipmentDatabase.Get(itemId) else nil
	local subType = if spec then spec.SubType else "NONE"

	-- sway from look motion, bob from walking, ADS pulls the weapon to the centre line
	swaySpring:SetTarget(Vector3.new(-lastMouseDelta.X * 0.0035, lastMouseDelta.Y * 0.0035, 0))
	local sway = swaySpring:Update(dt)
	local ads = adsSpring:Update(dt)
	local bob = if bobbingEnabled then Vector3.new(math.cos(bobPhase) * 0.05, math.abs(math.sin(bobPhase)) * 0.06, 0) * bobAmount else Vector3.zero
	local recoil = recoilSpring.Position

	local hip = Vector3.new(0.95, -0.95, -1.9)
	local aimPos = Vector3.new(0, -0.55, -1.55)
	if subType == "BOW" then
		hip = Vector3.new(0.35, -0.75, -2.3)
		aimPos = Vector3.new(0.05, -0.45, -2.1)
	elseif subType == "MELEE" or subType == "SHIELD" then
		hip = Vector3.new(1.05, -1.15, -2.0)
		aimPos = hip
	end
	local offset = hip:Lerp(aimPos, ads) + bob + Vector3.new(sway.X, sway.Y, recoil.X * 0.6)
	local base = camCF * CFrame.new(offset) * CFrame.Angles(sway.Y * 2 + recoil.X * 1.5, sway.X * 2, 0)

	local handleCF = base
	if subType == "MELEE" then
		local tilt = CFrame.Angles(math.rad(-70), math.rad(-12), math.rad(-18))
		local t = (os.clock() - swingStarted) / (if swingHeavy then 0.42 else 0.26)
		if t >= 0 and t <= 1 then
			-- swing arc: wind up, cut across to the lower left, recover
			local cut = math.sin(t * math.pi)
			tilt = tilt * CFrame.Angles(math.rad(-80) * cut, math.rad(55) * cut, math.rad(-40) * cut)
			handleCF = base * CFrame.new(-0.9 * cut, -0.2 * cut, -0.4 * cut)
		end
		handleCF = handleCF * tilt
		if character and character:GetAttribute("Blocking") == true then
			handleCF = base * CFrame.new(-0.6, 0.55, 0.2) * CFrame.Angles(0, 0, math.rad(80)) * CFrame.Angles(math.rad(-10), 0, 0)
		end
	elseif subType == "SHIELD" then
		local raised = character ~= nil and character:GetAttribute("Blocking") == true
		handleCF = if raised then camCF * CFrame.new(-0.2, -0.5, -1.8) else base * CFrame.new(-1.1, 0, 0) * CFrame.Angles(0, math.rad(25), 0)
	elseif subType == "THROWABLE" or subType == "NONE" then
		handleCF = base * CFrame.new(0, 0.1, 0.2)
	end

	local weapon = vmWeapon
	local grip = handleCF
	local offhand: Vector3? = nil
	if weapon then
		weapon:PivotTo(handleCF)
		local str = EquipmentRig.GetAttachment(weapon, "StringAttachment")
		if subType == "BOW" and str then
			local rest = str:GetAttribute("RestZ")
			local draw = weapon:GetAttribute("DrawDistance")
			if type(rest) == "number" and type(draw) == "number" then
				local p = str.Position
				str.Position = Vector3.new(p.X, p.Y, rest + draw * State.DrawRatio)
			end
			-- bow: left hand holds the riser, right hand pulls the string
			offhand = handleCF.Position
			grip = CFrame.new(str.WorldPosition)
		elseif weapon:GetAttribute("TwoHanded") == true then
			offhand = (handleCF * CFrame.new(0, 0, -1.1)).Position
		end
	end
	local rightShoulder = (camCF * CFrame.new(1.25, -1.5, 0.3)).Position
	local leftShoulder = (camCF * CFrame.new(-1.25, -1.5, 0.3)).Position
	placeArm(vmRightArm, rightShoulder, grip.Position)
	local leftHand = offhand or (camCF * CFrame.new(-0.9, -1.6, -1.2)).Position
	placeArm(vmLeftArm, leftShoulder, leftHand)
	if vmLeftArm then
		vmLeftArm.Transparency = if offhand == nil and subType ~= "SHIELD" then 1 else 0
		local h = vmLeftArm:FindFirstChild("Hand")
		if h and h:IsA("BasePart") then
			h.Transparency = vmLeftArm.Transparency
		end
	end
end

---------------------------------------------------------------------------------------------
-- Input
---------------------------------------------------------------------------------------------
local function onInputChanged(input: InputObject, processed: boolean)
	if input.KeyCode == Enum.KeyCode.Thumbstick2 then
		local p = input.Position
		gamepadLook = if math.abs(p.X) + math.abs(p.Y) > 0.15 then Vector2.new(p.X, p.Y) else Vector2.zero
	elseif input.UserInputType == Enum.UserInputType.Touch and input == lookTouch then
		touchDelta += Vector2.new(input.Delta.X, input.Delta.Y)
	end
end

local function onInputBegan(input: InputObject, processed: boolean)
	if input.UserInputType == Enum.UserInputType.Touch and not processed and lookTouch == nil then
		local viewport = camera().ViewportSize
		if input.Position.X > viewport.X * 0.4 then
			lookTouch = input
		end
	end
end

local function onInputEnded(input: InputObject)
	if input == lookTouch then
		lookTouch = nil
	end
end

---------------------------------------------------------------------------------------------
-- Frame update
---------------------------------------------------------------------------------------------
local function targetSubject(): Model?
	if State.SpectateTarget and State.SpectateTarget.Parent then
		return State.SpectateTarget
	end
	return State.Character()
end

local function shouldBeActive(): boolean
	if State.Cinematic then
		return false
	end
	if State.SpectateTarget ~= nil then
		return true
	end
	return State.InCombat() and State.Character() ~= nil
end

local function deactivate()
	local cam = camera()
	cam.CameraType = Enum.CameraType.Custom
	local humanoid = State.Humanoid()
	if humanoid then
		cam.CameraSubject = humanoid
		humanoid.AutoRotate = true
	end
	UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	UserInputService.MouseIconEnabled = true
	setBodyHidden(false)
	destroyViewmodel()
	State.Aiming = false
end

local function update(dt: number)
	active = shouldBeActive()
	if State.Cinematic then
		-- POTG / end screens own the camera and need a free mouse
		lastActive = false
		destroyViewmodel()
		setBodyHidden(false)
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		UserInputService.MouseIconEnabled = true
		return
	end
	if not active then
		if lastActive then
			deactivate()
		end
		lastActive = false
		fovSpring:Snap(baseFov)
		camera().FieldOfView = baseFov
		return
	end
	if not lastActive then
		-- entering combat: start looking the way the character faces
		local root = State.Root()
		if root then
			local look = root.CFrame.LookVector
			yaw = math.atan2(-look.X, -look.Z)
			pitch = 0
		end
	end
	lastActive = true

	local cam = camera()
	cam.CameraType = Enum.CameraType.Scriptable

	-- mouse capture (menus such as the preset switcher release it)
	if State.InMenu() then
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		UserInputService.MouseIconEnabled = true
		lastMouseDelta = Vector2.zero
	else
		UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
		UserInputService.MouseIconEnabled = false
		local zoomScale = fovSpring:Get() / math.max(baseFov, 1)
		local delta = UserInputService:GetMouseDelta()
		lastMouseDelta = delta
		local k = MOUSE_RADIANS_PER_PIXEL * sensitivity * zoomScale
		yaw -= delta.X * k
		pitch -= delta.Y * k
		yaw -= gamepadLook.X * GAMEPAD_RADIANS_PER_SECOND * sensitivity * zoomScale * dt
		pitch += gamepadLook.Y * GAMEPAD_RADIANS_PER_SECOND * 0.7 * sensitivity * zoomScale * dt
		yaw -= touchDelta.X * TOUCH_RADIANS_PER_PIXEL * sensitivity * zoomScale
		pitch -= touchDelta.Y * TOUCH_RADIANS_PER_PIXEL * sensitivity * zoomScale
	end
	touchDelta = Vector2.zero
	pitch = math.clamp(pitch, -PITCH_LIMIT, PITCH_LIMIT)

	local recoil = recoilSpring:Update(dt)
	local shake = shakeSpring:Update(dt)
	local viewPitch = math.clamp(pitch + recoil.X + shake.X, -PITCH_LIMIT, PITCH_LIMIT)
	local viewYaw = yaw + recoil.Y + shake.Y
	local rotation = CFrame.Angles(0, viewYaw, 0) * CFrame.Angles(viewPitch, 0, 0)

	-- FOV: weapon ADS zoom or the player's setting
	local spec = State.EquippedSpec()
	local zoom = if spec then (spec.ZoomFOVAds or spec.ZoomFOV) else nil
	local aimingRanged = State.Aiming and spec ~= nil and EquipmentDatabase.IsRanged(spec)
	fovSpring:SetTarget(if aimingRanged and zoom then zoom else baseFov)
	adsSpring:SetTarget(if aimingRanged then 1 else 0)
	cam.FieldOfView = math.clamp(fovSpring:Update(dt), 20, 120)

	-- turn our own character to the camera yaw
	local character = State.Character()
	local humanoid = State.Humanoid()
	local root = State.Root()
	local alive = State.Alive()
	if humanoid then
		humanoid.AutoRotate = not alive
	end
	if alive and root and not root.Anchored and State.SpectateTarget == nil then
		root.CFrame = CFrame.new(root.Position) * CFrame.Angles(0, yaw, 0)
	end

	-- walking bob
	local speed = if root then Vector3.new(root.AssemblyLinearVelocity.X, 0, root.AssemblyLinearVelocity.Z).Magnitude else 0
	bobAmount += ((if speed > 2 and not State.Sliding then math.clamp(speed / 18, 0, 1.4) else 0) - bobAmount) * math.min(dt * 8, 1)
	bobPhase += dt * speed * 0.55

	local subject = targetSubject()
	local subjectRoot = if subject then subject:FindFirstChild("HumanoidRootPart") else nil
	local spectating = State.SpectateTarget ~= nil
	local firstPerson = State.ViewMode == "First" and alive and not spectating

	dropSpring:SetTarget(if State.Sliding then GameConfig.Movement.SlideCameraDrop else 0)
	local drop = dropSpring:Update(dt)

	if firstPerson and character then
		local head = character:FindFirstChild("Head")
		local headPos = if head and head:IsA("BasePart") then head.Position else (if root then root.Position + Vector3.new(0, 1.5, 0) else cam.CFrame.Position)
		local bob = if bobbingEnabled then Vector3.new(0, math.abs(math.sin(bobPhase)) * 0.12 * bobAmount, 0) else Vector3.zero
		local camCF = CFrame.new(headPos + Vector3.new(0, 0.2 + drop * 0.5, 0) + bob) * rotation
		if bobbingEnabled then
			camCF *= CFrame.Angles(0, 0, math.sin(bobPhase * 0.5) * 0.012 * bobAmount)
		end
		cam.CFrame = camCF
		setBodyHidden(true)
		updateViewmodel(camCF, dt)
	else
		setBodyHidden(false)
		destroyViewmodel()
		if subjectRoot and subjectRoot:IsA("BasePart") then
			shoulderSpring:SetTarget(if State.Shoulder >= 0 then CAM.RightShoulder else CAM.LeftShoulder)
			local offset = shoulderSpring:Update(dt)
			if aimingRanged then
				offset = Vector3.new(offset.X * 0.7, offset.Y * 0.9, offset.Z * 0.55)
			end
			local focus = subjectRoot.Position + Vector3.new(0, 1.6 + drop, 0)
			local pivot = CFrame.new(focus) * rotation
			local shoulderPoint = (pivot * CFrame.new(offset.X, offset.Y, 0)).Position
			local desired = (pivot * CFrame.new(offset)).Position
			local params = rayParams({ subject :: Model })
			-- pull in when a wall is between the shoulder and the camera
			local sideHit = Workspace:Raycast(focus, shoulderPoint - focus, params)
			if sideHit then
				shoulderPoint = sideHit.Position + (focus - shoulderPoint).Unit * 0.4
			end
			local backHit = Workspace:Raycast(shoulderPoint, desired - shoulderPoint, params)
			if backHit then
				desired = backHit.Position + (shoulderPoint - desired).Unit * 0.5
			end
			cam.CFrame = CFrame.new(desired) * rotation
		end
	end
end

---------------------------------------------------------------------------------------------
-- Public API
---------------------------------------------------------------------------------------------
-- Ray from the camera through the screen centre: (origin, unit direction).
function CameraController.AimRay(): (Vector3, Vector3)
	local cam = camera()
	if active then
		return cam.CFrame.Position, cam.CFrame.LookVector
	end
	local ray = cam:ViewportPointToRay(cam.ViewportSize.X / 2, cam.ViewportSize.Y / 2)
	return ray.Origin, ray.Direction.Unit
end

-- World point under the crosshair (up to 1000 studs), ignoring our own character.
function CameraController.AimPoint(): Vector3
	local origin, dir = CameraController.AimRay()
	local character = State.Character()
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local exclude: { Instance } = { camera() }
	if character then
		table.insert(exclude, character)
	end
	local runtime = Workspace:FindFirstChild("Runtime_Dynamic_Containers")
	local proj = if runtime then runtime:FindFirstChild("ActiveProjectiles_Container") else nil
	if proj then
		table.insert(exclude, proj)
	end
	params.FilterDescendantsInstances = exclude
	params.IgnoreWater = true
	local hit = Workspace:Raycast(origin, dir * 1000, params)
	return if hit then hit.Position else origin + dir * 1000
end

function CameraController.Yaw(): number
	return yaw
end

function CameraController.Pitch(): number
	return pitch
end

function CameraController.IsActive(): boolean
	return active
end

function CameraController.ToggleView()
	State.SetViewMode(if State.ViewMode == "First" then "Third" else "First")
end

function CameraController.SwapShoulder()
	State.Shoulder = if State.Shoulder >= 0 then -1 else 1
	State.ViewChanged:Fire(State.ViewMode)
end

function CameraController.Shake(strength: number)
	local s = math.clamp(strength, 0, 3)
	shakeSpring:Impulse(Vector3.new((math.random() - 0.5) * s, (math.random() - 0.5) * s, 0))
end

function CameraController.SetLook(newYaw: number, newPitch: number)
	yaw = newYaw
	pitch = math.clamp(newPitch, -PITCH_LIMIT, PITCH_LIMIT)
end

function CameraController.Init() end

function CameraController.Start()
	State.ProfileChanged:Connect(applySettings)
	applySettings()
	fovSpring:Snap(baseFov)
	State.Recoil:Connect(function(kickPitch: number, kickYaw: number)
		recoilSpring:Impulse(Vector3.new(kickPitch, kickYaw, 0))
	end)
	State.LocalSwing:Connect(function(itemId: string)
		swingStarted = os.clock()
		local spec = EquipmentDatabase.Get(itemId)
		swingHeavy = spec ~= nil and (spec.SwingRate or 0.5) >= 0.8
	end)
	local wasArmed = false
	State.InventoryChanged:Connect(function(view)
		local armed = view ~= nil
		if armed and not wasArmed then
			local profile = State.Profile
			State.SetViewMode(if profile and profile.Settings.FirstPersonDefault then "First" else "Third")
		end
		wasArmed = armed
	end)
	player.CharacterAdded:Connect(function(character)
		destroyViewmodel()
		collectHidden(character)
		hiddenApplied = false
	end)
	UserInputService.InputChanged:Connect(onInputChanged)
	UserInputService.InputBegan:Connect(onInputBegan)
	UserInputService.InputEnded:Connect(onInputEnded)
	RunService:BindToRenderStep("TribesCamera", Enum.RenderPriority.Camera.Value + 1, update)
end

return CameraController
