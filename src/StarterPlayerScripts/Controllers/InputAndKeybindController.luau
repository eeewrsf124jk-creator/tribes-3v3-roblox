--!strict
-- InputAndKeybindController: one place that maps devices to actions.
--   Keyboard/mouse  LMB fire/swing/draw · RMB aim/block · 1-6 + wheel hotbar · B loadout
--                   builder (lobby) / preset switcher (pre-round) · C slide · V first/third
--                   person · X swap shoulder · R fire arrows · Q cancel heal · F catch chakram
--                   · Shift sprint
--   Gamepad         R2 fire · L2 aim · R1/L1 hotbar · B slide · Y view · DPad Up loadout ·
--                   L3 sprint
--   Touch           on-screen FIRE / AIM / SLIDE / NEXT / VIEW buttons (ContextActionService)
-- While dead and spectating, LMB / RMB step through living teammates.

local ContextActionService = game:GetService("ContextActionService")
local UserInputService = game:GetService("UserInputService")

local State = require(script.Parent.ClientState)
local Movement = require(script.Parent.MovementController)
local Camera = require(script.Parent.CameraAndViewmodelController)
local Weapon = require(script.Parent.WeaponAndProjectileController)
local HUD = require(script.Parent.CombatFeedbackAndHUDController)
local Lobby = require(script.Parent.LobbyUIController)

local Input = {}

local HOTBAR_KEYS: { [Enum.KeyCode]: number } = {
	[Enum.KeyCode.One] = 1,
	[Enum.KeyCode.Two] = 2,
	[Enum.KeyCode.Three] = 3,
	[Enum.KeyCode.Four] = 4,
	[Enum.KeyCode.Five] = 5,
	[Enum.KeyCode.Six] = 6,
	[Enum.KeyCode.KeypadOne] = 1,
	[Enum.KeyCode.KeypadTwo] = 2,
	[Enum.KeyCode.KeypadThree] = 3,
	[Enum.KeyCode.KeypadFour] = 4,
	[Enum.KeyCode.KeypadFive] = 5,
	[Enum.KeyCode.KeypadSix] = 6,
}

local function spectatingDead(): boolean
	return State.SpectateTarget ~= nil and not State.Alive()
end

function Input.PressB()
	local round = State.Round
	if round then
		if round.Phase == "PreRoundLoadout" then
			HUD.TogglePresetSwitcher()
		end
		return
	end
	Lobby.Toggle("LoadoutBuilder")
end

local function primary(down: boolean)
	if down and spectatingDead() then
		HUD.CycleSpectate(1)
		return
	end
	if down then
		Weapon.PrimaryDown()
	else
		Weapon.PrimaryUp()
	end
end

local function secondary(down: boolean)
	if down and spectatingDead() then
		HUD.CycleSpectate(-1)
		return
	end
	if down then
		Weapon.SecondaryDown()
	else
		Weapon.SecondaryUp()
	end
end

local function onKey(key: Enum.KeyCode)
	local slot = HOTBAR_KEYS[key]
	if slot then
		Weapon.Equip(slot)
	elseif key == Enum.KeyCode.B or key == Enum.KeyCode.DPadUp then
		Input.PressB()
	elseif key == Enum.KeyCode.C or key == Enum.KeyCode.ButtonB then
		Movement.TrySlide()
	elseif key == Enum.KeyCode.V or key == Enum.KeyCode.ButtonY then
		if State.InCombat() then
			Camera.ToggleView()
		end
	elseif key == Enum.KeyCode.X then
		if State.InCombat() then
			Camera.SwapShoulder()
		end
	elseif key == Enum.KeyCode.R then
		Weapon.ToggleFireArrows()
	elseif key == Enum.KeyCode.Q then
		Weapon.CancelHeal()
	elseif key == Enum.KeyCode.F then
		Weapon.CatchChakram()
	elseif key == Enum.KeyCode.LeftShift or key == Enum.KeyCode.RightShift or key == Enum.KeyCode.ButtonL3 then
		Movement.SetSprinting(true)
	elseif key == Enum.KeyCode.ButtonR1 then
		Weapon.Cycle(1)
	elseif key == Enum.KeyCode.ButtonL1 then
		Weapon.Cycle(-1)
	elseif key == Enum.KeyCode.ButtonR2 then
		primary(true)
	elseif key == Enum.KeyCode.ButtonL2 then
		secondary(true)
	end
end

local function onInputBegan(input: InputObject, processed: boolean)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		if not processed then
			primary(true)
		end
	elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
		if not processed then
			secondary(true)
		end
	elseif input.UserInputType == Enum.UserInputType.Keyboard or input.UserInputType.Name:match("^Gamepad") then
		-- processed keyboard input means a TextBox has focus
		if processed and input.UserInputType == Enum.UserInputType.Keyboard then
			return
		end
		onKey(input.KeyCode)
	end
end

local function onInputEnded(input: InputObject, _processed: boolean)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		primary(false)
	elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
		secondary(false)
	elseif input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.RightShift or input.KeyCode == Enum.KeyCode.ButtonL3 then
		Movement.SetSprinting(false)
	elseif input.KeyCode == Enum.KeyCode.ButtonR2 then
		primary(false)
	elseif input.KeyCode == Enum.KeyCode.ButtonL2 then
		secondary(false)
	end
end

local function onInputChanged(input: InputObject, processed: boolean)
	if input.UserInputType == Enum.UserInputType.MouseWheel and not processed and State.InCombat() then
		Weapon.Cycle(if input.Position.Z > 0 then -1 else 1)
	end
end

---------------------------------------------------------------------------------------------
-- Touch buttons
---------------------------------------------------------------------------------------------
local touchBound = false
local aimToggled = false

local function bindTouch()
	if touchBound or not UserInputService.TouchEnabled then
		return
	end
	touchBound = true
	local function button(name: string, title: string, position: UDim2, handler: (Enum.UserInputState) -> ())
		ContextActionService:BindAction(name, function(_, inputState: Enum.UserInputState)
			handler(inputState)
			return Enum.ContextActionResult.Sink
		end, true)
		ContextActionService:SetTitle(name, title)
		ContextActionService:SetPosition(name, position)
	end
	button("TribesFire", "FIRE", UDim2.new(1, -150, 1, -190), function(s)
		if s == Enum.UserInputState.Begin then
			primary(true)
		elseif s == Enum.UserInputState.End or s == Enum.UserInputState.Cancel then
			primary(false)
		end
	end)
	button("TribesAim", "AIM", UDim2.new(1, -230, 1, -120), function(s)
		if s == Enum.UserInputState.Begin then
			aimToggled = not aimToggled
			secondary(aimToggled)
		end
	end)
	button("TribesSlide", "SLIDE", UDim2.new(1, -90, 1, -260), function(s)
		if s == Enum.UserInputState.Begin then
			Movement.TrySlide()
		end
	end)
	button("TribesNext", "NEXT", UDim2.new(1, -230, 1, -260), function(s)
		if s == Enum.UserInputState.Begin then
			Weapon.Cycle(1)
		end
	end)
	button("TribesView", "VIEW", UDim2.new(1, -300, 1, -190), function(s)
		if s == Enum.UserInputState.Begin then
			Camera.ToggleView()
		end
	end)
end

local function unbindTouch()
	if not touchBound then
		return
	end
	touchBound = false
	aimToggled = false
	for _, name in { "TribesFire", "TribesAim", "TribesSlide", "TribesNext", "TribesView" } do
		ContextActionService:UnbindAction(name)
	end
end

function Input.Init() end

function Input.Start()
	UserInputService.InputBegan:Connect(onInputBegan)
	UserInputService.InputEnded:Connect(onInputEnded)
	UserInputService.InputChanged:Connect(onInputChanged)
	-- touch combat buttons appear only while armed
	State.InventoryChanged:Connect(function(view)
		if view ~= nil then
			bindTouch()
		else
			unbindTouch()
		end
	end)
	UserInputService.WindowFocusReleased:Connect(function()
		Weapon.CancelAll()
		Movement.SetSprinting(false)
	end)
end

return Input
