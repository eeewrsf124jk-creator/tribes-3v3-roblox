--!strict
-- ClientState: the client's single source of truth (profile, inventory, round, party, camera
-- mode) plus the signals controllers use to talk to each other without requiring each other.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local Types = require(Modules.Shared.Types)
local Signal = require(Modules.Shared.Signal)
local EquipmentDatabase = require(Modules.Config.EquipmentDatabase)

local State = {}

State.Player = Players.LocalPlayer
State.Profile = nil :: Types.Profile?
State.Inventory = nil :: Types.InventoryView?
State.Round = nil :: Types.RoundState?
State.Party = nil :: Types.PartyView?
State.ViewMode = "Third" :: "Third" | "First"
State.Shoulder = 1
State.Aiming = false
State.Drawing = false
State.DrawRatio = 0
State.Sliding = false
State.Sprinting = false
State.Cinematic = false -- POTG / victory sequences own the camera
State.SpectateTarget = nil :: Model?
State.OpenMenus = {} :: { [string]: boolean? }

State.ProfileChanged = Signal.new() :: Signal.Signal<Types.Profile>
State.InventoryChanged = Signal.new() :: Signal.Signal<Types.InventoryView?>
State.RoundChanged = Signal.new() :: Signal.Signal<Types.RoundState?, Types.RoundState?>
State.PartyChanged = Signal.new() :: Signal.Signal<Types.PartyView?>
State.MenuChanged = Signal.new() :: Signal.Signal<boolean>
State.ViewChanged = Signal.new() :: Signal.Signal<string>
State.Recoil = Signal.new() :: Signal.Signal<number, number>
State.LocalSwing = Signal.new() :: Signal.Signal<string>
State.CombatEvent = Signal.new() :: Signal.Signal<Types.CombatEventPacket>
State.Notify = Signal.new() :: Signal.Signal<string, string>

function State.MyId(): string
	return "P" .. tostring(State.Player.UserId)
end

function State.Now(): number
	return Workspace:GetServerTimeNow()
end

function State.Character(): Model?
	return State.Player.Character
end

function State.Root(): BasePart?
	local character = State.Player.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	if root and root:IsA("BasePart") then
		return root
	end
	return nil
end

function State.Humanoid(): Humanoid?
	local character = State.Player.Character
	return if character then character:FindFirstChildOfClass("Humanoid") else nil
end

function State.Alive(): boolean
	local h = State.Humanoid()
	return h ~= nil and h.Health > 0
end

function State.InCombat(): boolean
	return State.Inventory ~= nil
end

function State.EquippedSlot(): Types.InventorySlot?
	local inv = State.Inventory
	if inv == nil then
		return nil
	end
	return inv.Slots[inv.Equipped]
end

function State.EquippedSpec(): Types.EquipmentSpec?
	local slot = State.EquippedSlot()
	return if slot then EquipmentDatabase.Get(slot.ItemId) else nil
end

function State.MyTeam(): Types.TeamName
	local round = State.Round
	if round then
		for _, r in round.Roster do
			if r.UserId == State.Player.UserId then
				return r.Team
			end
		end
	end
	local character = State.Player.Character
	local attr = if character then character:GetAttribute("Team") else nil
	if attr == "Alpha" or attr == "Bravo" then
		return attr
	end
	return "Neutral"
end

function State.InMenu(): boolean
	return next(State.OpenMenus) ~= nil
end

function State.SetMenu(name: string, open: boolean)
	local before = State.InMenu()
	State.OpenMenus[name] = if open then true else nil
	local after = State.InMenu()
	if before ~= after then
		State.MenuChanged:Fire(after)
	end
end

function State.SetViewMode(mode: "Third" | "First")
	if State.ViewMode ~= mode then
		State.ViewMode = mode
		State.ViewChanged:Fire(mode)
	end
end

return State
