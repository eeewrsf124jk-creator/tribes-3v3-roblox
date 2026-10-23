--!strict
-- LobbyUIController: the lobby's 2D side.
--   LobbyHUD     profile card, shards, side buttons, PLAY / queue status, party panel + invites,
--                interact hints for the village zones.
--   LoadoutBuilder  5 presets, category tabs, item grid with locks/levels, detail + upgrade
--                panel, 6 slots + armor + ammo bundles, live 12-point budget validation, save.
--   CustomMatches   create / list / join rooms, team pick, host start.
--   TribeHall    found (name + tag), browse / search, join, leave, member list.
--   Settings     sensitivity and FOV sliders, toggles; applied live and saved to the profile.
-- [B] toggles the builder; ProximityPrompts open interfaces through the OpenInterface remote.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local Net = require(Modules.Shared.Net)
local Types = require(Modules.Shared.Types)
local Ballistics = require(Modules.Shared.BallisticsEngine)
local Validator = require(Modules.Shared.LoadoutBudgetValidator)
local EquipmentDatabase = require(Modules.Config.EquipmentDatabase)
local UpgradeScalingMath = require(Modules.Config.UpgradeScalingMath)
local State = require(script.Parent.ClientState)
local UIUtil = require(script.Parent.UIUtil)

local Lobby = {}

local T = UIUtil.Theme
local player = Players.LocalPlayer

local hud: ScreenGui
local builder: ScreenGui
local custom: ScreenGui
local tribeHall: ScreenGui
local settingsGui: ScreenGui

local MODALS = { "LoadoutBuilder", "CustomMatches", "TribeHall", "Settings" }
local modalGuis: { [string]: ScreenGui? } = {}
local lastToggleAt = 0

type QueueStatus = { Queued: boolean, Elapsed: number, InQueue: number, BotFillIn: number, Found: boolean?, ReceivedAt: number }
local queue: QueueStatus? = nil
local myTribe: { [string]: any }? = nil
local rooms: { Types.RoomView } = {}
local fillBots = false

-- builder state
local working: { Types.Loadout } = {}
local presetIndex = 1
local category = "WEAPONS"
local selected: string? = nil

---------------------------------------------------------------------------------------------
-- Modals
---------------------------------------------------------------------------------------------
local function isOpen(name: string): boolean
	local gui = modalGuis[name]
	return gui ~= nil and gui.Enabled
end

local refreshBuilder: () -> ()
local onBuilderOpened: () -> ()

function Lobby.Open(name: string)
	local gui = modalGuis[name]
	if gui == nil then
		return
	end
	if State.Round ~= nil then
		return -- no lobby menus during a match
	end
	for _, other in MODALS do
		if other ~= name and isOpen(other) then
			Lobby.Close(other)
		end
	end
	gui.Enabled = true
	State.SetMenu(name, true)
	UIUtil.Click()
	local modal = gui:FindFirstChild("Modal")
	if modal and modal:IsA("GuiObject") then
		modal.Position = UDim2.fromScale(0.5, 0.54)
		UIUtil.Tween(modal, 0.18, { Position = UDim2.fromScale(0.5, 0.5) }, Enum.EasingStyle.Back)
	end
	if name == "LoadoutBuilder" then
		onBuilderOpened()
	elseif name == "CustomMatches" then
		Net.Reliable("CustomMatchAction"):FireServer("List")
	elseif name == "TribeHall" then
		Net.Reliable("TribeAction"):FireServer("Mine")
		Net.Reliable("TribeAction"):FireServer("Browse")
	end
end

function Lobby.Close(name: string)
	local gui = modalGuis[name]
	if gui and gui.Enabled then
		gui.Enabled = false
		State.SetMenu(name, false)
	end
end

function Lobby.Toggle(name: string)
	lastToggleAt = os.clock()
	if isOpen(name) then
		Lobby.Close(name)
	else
		Lobby.Open(name)
	end
end

function Lobby.CloseAll()
	for _, name in MODALS do
		Lobby.Close(name)
	end
end

function Lobby.AnyOpen(): boolean
	for _, name in MODALS do
		if isOpen(name) then
			return true
		end
	end
	return false
end

---------------------------------------------------------------------------------------------
-- Profile card
---------------------------------------------------------------------------------------------
local function totalShards(profile: Types.Profile): number
	local n = 0
	for _, v in profile.Shards do
		n += v
	end
	return n
end

local function refreshProfileCard()
	local profile = State.Profile
	if profile == nil then
		return
	end
	UIUtil.Label(hud, "ProfileCard/NameLabel").Text = player.DisplayName
	UIUtil.Label(hud, "ProfileCard/LevelLabel").Text = "LV " .. profile.Level
	UIUtil.SetFill(UIUtil.Frame(hud, "ProfileCard/XPBar/Fill"), profile.XP / math.max(UpgradeScalingMath.XPForLevel(profile.Level), 1), 0.4)
	UIUtil.Label(hud, "ProfileCard/StreakLabel").Text = "🔥 " .. profile.WinStreak
	UIUtil.Label(hud, "ProfileCard/GloryLabel").Text = string.format("%d RP", profile.GloryRP)
	local tribe = myTribe
	UIUtil.Label(hud, "ProfileCard/TribeLabel").Text = if tribe then "[" .. tostring(tribe.Tag) .. "]" else "[—]"
	UIUtil.Label(hud, "CurrencyCard/ShardsLabel").Text = string.format("💎 %d SHARDS", totalShards(profile))
	local restore = UIUtil.Button(hud, "SideButtons/RestoreStreakButton")
	restore.Visible = profile.LastLostStreak > 0
	restore.Text = string.format("RESTORE 🔥%d STREAK", profile.LastLostStreak)
end

---------------------------------------------------------------------------------------------
-- Queue + party
---------------------------------------------------------------------------------------------
local function refreshQueue()
	local q = queue
	local play = UIUtil.Button(hud, "PlayPanel/PlayButton")
	local cancel = UIUtil.Button(hud, "PlayPanel/CancelButton")
	local status = UIUtil.Label(hud, "PlayPanel/QueueStatus")
	local botFill = UIUtil.Label(hud, "PlayPanel/BotFillLabel")
	local party = State.Party
	local leader = party == nil or party.Leader == player.UserId
	if q and q.Queued then
		local elapsed = q.Elapsed + (os.clock() - q.ReceivedAt)
		play.Text = "SEARCHING..."
		play.AutoButtonColor = false
		cancel.Visible = leader
		if q.Found then
			status.Text = "MATCH FOUND!"
			status.TextColor3 = T.Good
		else
			status.Text = string.format("Searching %s  ·  %d in queue", UIUtil.FormatTime(elapsed), q.InQueue)
			status.TextColor3 = T.SubText
		end
		if q.BotFillIn < 0 then
			botFill.Text = "Bot fill disabled in your settings"
		else
			local left = math.max(0, q.BotFillIn - (os.clock() - q.ReceivedAt))
			botFill.Text = if left > 0 then string.format("Bots fill empty seats in %ds", math.ceil(left)) else "Filling with bots..."
		end
	else
		play.Text = if party and #party.Members > 1 then string.format("PLAY 3v3 (PARTY %d)", #party.Members) else "PLAY 3v3"
		play.AutoButtonColor = true
		cancel.Visible = false
		status.Text = if leader then "Ready to fight" else "Waiting for the party leader"
		status.TextColor3 = T.SubText
		botFill.Text = ""
	end
end

local function refreshParty()
	local party = State.Party
	local list = UIUtil.Get(hud, "PartyPanel/MemberList")
	UIUtil.ClearClones(list)
	local template = UIUtil.Frame(list, "MemberTemplate")
	local members: { { UserId: number, Name: string } } = if party then party.Members else { { UserId = player.UserId, Name = player.DisplayName } }
	for i, m in members do
		local row = UIUtil.CloneTemplate(template, "Member_" .. m.UserId)
		row.LayoutOrder = i
		UIUtil.Label(row, "Name").Text = m.Name .. (if m.UserId == player.UserId then " (you)" else "")
		local leader = if party then party.Leader == m.UserId else true
		UIUtil.Label(row, "Role").Text = if leader then "LEADER" else ""
		-- the leader can click a member row to remove them
		if party and party.Leader == player.UserId and m.UserId ~= player.UserId then
			row.Active = true
			row.InputBegan:Connect(function(input)
				if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
					Net.Reliable("PartyAction"):FireServer("Kick", m.UserId)
				end
			end)
			UIUtil.Label(row, "Role").Text = "KICK ✕"
		end
	end
	UIUtil.Button(hud, "PartyPanel/LeaveButton").Visible = party ~= nil and #party.Members > 1
	refreshQueue()
end

local function showInvite(fromName: string)
	local invite = UIUtil.Frame(hud, "PartyInvite")
	UIUtil.Label(invite, "InviteText").Text = string.format("%s invited you to a party", fromName)
	invite.Visible = true
	local token = os.clock()
	invite:SetAttribute("Token", token)
	task.delay(30, function()
		if invite:GetAttribute("Token") == token then
			invite.Visible = false
		end
	end)
end

---------------------------------------------------------------------------------------------
-- Interact hints
---------------------------------------------------------------------------------------------
local HINTS: { [string]: string } = {
	LoadoutBuilder = "[B] Open the Loadout Builder",
	TribeHall = "[E] Tribe Hall: found or join a tribe",
	DuelZone = "Duel Pit: stand on a pad and press [E] for a 1v1",
	TrainingZone = "Training Range: your active preset is armed here",
}

local function refreshHint()
	local hint = UIUtil.Label(hud, "InteractHint")
	local root = State.Root()
	if root == nil or State.Round ~= nil or Lobby.AnyOpen() then
		hint.Text = ""
		return
	end
	for _, zone in CollectionService:GetTagged("InterfaceZone") do
		if zone:IsA("BasePart") and Ballistics.PointInOBB(root.Position, zone.CFrame, zone.Size, 0) then
			local interface = zone:GetAttribute("Interface")
			hint.Text = if type(interface) == "string" then (HINTS[interface] or "") else ""
			return
		end
	end
	hint.Text = ""
end

---------------------------------------------------------------------------------------------
-- Loadout builder
---------------------------------------------------------------------------------------------
local function cloneLoadout(l: Types.Loadout): Types.Loadout
	return {
		Name = l.Name,
		Slots = table.clone(l.Slots),
		Armor = l.Armor,
		Ammo = { Arrows = l.Ammo.Arrows, Bullets = l.Ammo.Bullets, FireArrows = l.Ammo.FireArrows },
	}
end

local function isUnlocked(profile: Types.Profile, id: string): boolean
	local spec = EquipmentDatabase.Get(id)
	if spec == nil then
		return false
	end
	if profile.UnlockedItems[id] ~= nil then
		return true
	end
	if spec.RankedOnly then
		local need = EquipmentDatabase.RankedUnlockGlory[id]
		return need ~= nil and profile.GloryRP >= need
	end
	return false
end

local function unlockTable(profile: Types.Profile): { [string]: number }
	local t: { [string]: number } = {}
	for _, id in EquipmentDatabase.Order do
		if isUnlocked(profile, id) then
			t[id] = profile.UnlockedItems[id] or 1
		end
	end
	return t
end

local function current(): Types.Loadout
	local l = working[presetIndex]
	if l == nil then
		l = Validator.EmptyLoadout("Preset " .. presetIndex)
		working[presetIndex] = l
	end
	return l
end

local function statLines(spec: Types.EquipmentSpec, level: number): string
	local mult = UpgradeScalingMath.StatMultiplier(level)
	local lines: { string } = {}
	local function add(label: string, value: string)
		table.insert(lines, string.format("%-10s %s", label, value))
	end
	if spec.BaseDmg then
		add("DAMAGE", string.format("%.0f", spec.BaseDmg * mult))
	end
	if spec.PelletCount and spec.PelletDmg then
		add("PELLETS", string.format("%d × %.0f", spec.PelletCount, spec.PelletDmg * mult))
	end
	if spec.HeadMult and spec.HeadMult > 1 then
		add("HEADSHOT", string.format("×%.2f", spec.HeadMult))
	end
	if spec.DrawTime then
		add("DRAW", string.format("%.2fs", spec.DrawTime))
	end
	if spec.ReloadTime then
		add("RELOAD", string.format("%.1fs", spec.ReloadTime))
	end
	if spec.SwingRate then
		add("SWING", string.format("%.2fs", spec.SwingRate))
	end
	if spec.Range then
		add("RANGE", string.format("%.0f", spec.Range))
	end
	if spec.ProjectileSpeed then
		add("SPEED", string.format("%.0f", spec.ProjectileSpeed))
	end
	if spec.ArmorHP then
		add("ARMOR HP", string.format("%.0f", UpgradeScalingMath.ScaleHealth(spec.ArmorHP, level)))
	end
	if spec.HealAmount then
		add("HEAL", string.format("%.0f", UpgradeScalingMath.ScaleHealth(spec.HealAmount, level)))
	end
	if spec.ShieldHealth then
		add("SHIELD HP", string.format("%.0f", UpgradeScalingMath.ScaleHealth(spec.ShieldHealth, level)))
	end
	if spec.Cooldown then
		add("COOLDOWN", string.format("%.1fs", spec.Cooldown))
	end
	if spec.SpeedPenalty then
		add("SLOW", string.format("-%d%%", math.floor(spec.SpeedPenalty * 100)))
	end
	return table.concat(lines, "\n")
end

local function refreshDetail()
	local profile = State.Profile
	local detail = UIUtil.Get(builder, "Modal/DetailPanel")
	local add = UIUtil.Button(detail, "AddButton")
	local upgrade = UIUtil.Button(detail, "UpgradeButton")
	local robux = UIUtil.Button(detail, "UnlockRobuxButton")
	local id = selected
	local spec = if id then EquipmentDatabase.Get(id) else nil
	if category == "AMMO" then
		UIUtil.Label(detail, "DetailName").Text = "AMMO BUNDLES"
		UIUtil.Label(detail, "DetailLevel").Text = ""
		UIUtil.Label(detail, "DetailDesc").Text = "Each bundle costs 1 point. Arrows ×12 and Fire Arrows ×6 feed bows (press [R] in combat to switch); Bullets ×6 feed firearms. Use + / − on the right."
		UIUtil.Label(detail, "DetailStats").Text = ""
		UIUtil.Label(detail, "ShardLabel").Text = ""
		UIUtil.SetFill(UIUtil.Frame(detail, "ShardBar/Fill"), 0)
		add.Visible, upgrade.Visible, robux.Visible = false, false, false
		return
	end
	if spec == nil or profile == nil or id == nil then
		UIUtil.Label(detail, "DetailName").Text = "Select an item"
		UIUtil.Label(detail, "DetailLevel").Text = ""
		UIUtil.Label(detail, "DetailDesc").Text = ""
		UIUtil.Label(detail, "DetailStats").Text = ""
		UIUtil.Label(detail, "ShardLabel").Text = ""
		UIUtil.SetFill(UIUtil.Frame(detail, "ShardBar/Fill"), 0)
		add.Visible, upgrade.Visible, robux.Visible = false, false, false
		return
	end
	local unlocked = isUnlocked(profile, id)
	local level = profile.UnlockedItems[id] or 1
	local have = profile.Shards[id] or 0
	UIUtil.Label(detail, "DetailName").Text = UIUtil.Glyph(id) .. "  " .. spec.DisplayName
	UIUtil.Label(detail, "DetailLevel").Text = if unlocked then string.format("LV %d / %d", level, UpgradeScalingMath.MaxLevel) else "LOCKED"
	UIUtil.Label(detail, "DetailDesc").Text = spec.Description
	UIUtil.Label(detail, "DetailStats").Text = statLines(spec, level) .. string.format("\n%-10s %d PT", "COST", spec.Cost)
	local need: number? = nil
	if not unlocked then
		need = spec.UnlockShards
	else
		need = UpgradeScalingMath.ShardsForNextLevel(level)
	end
	UIUtil.SetFill(UIUtil.Frame(detail, "ShardBar/Fill"), if need and need > 0 then have / need else 1, 0.25)
	UIUtil.Label(detail, "ShardLabel").Text = if need then string.format("%d / %d SHARDS", have, need) else "MAX LEVEL"

	local l = current()
	local inLoadout = table.find(l.Slots, id) ~= nil or l.Armor == id
	add.Visible = true
	add.AutoButtonColor = unlocked
	if not unlocked then
		add.Text = "LOCKED"
		add.BackgroundColor3 = T.PanelLighter
	elseif inLoadout then
		add.Text = "REMOVE"
		add.BackgroundColor3 = T.Bad
	else
		add.Text = if spec.Category == "ARMOR" then "EQUIP ARMOR" else "ADD TO LOADOUT"
		add.BackgroundColor3 = T.Alpha
	end
	if spec.RankedOnly and not unlocked then
		upgrade.Visible = true
		upgrade.Text = string.format("REACH %d RP", EquipmentDatabase.RankedUnlockGlory[id] or 0)
		upgrade.AutoButtonColor = false
	elseif need then
		upgrade.Visible = true
		upgrade.Text = string.format("%s (%d)", if unlocked then "UPGRADE" else "UNLOCK", need)
		upgrade.AutoButtonColor = have >= need
		upgrade.BackgroundColor3 = if have >= need then Color3.fromRGB(120, 220, 255) else T.PanelLighter
	else
		upgrade.Visible = false
	end
	robux.Visible = not unlocked and spec.RobuxCost ~= nil
	robux.Text = string.format("UNLOCK %d R$", spec.RobuxCost or 0)
end

local function refreshGrid()
	local profile = State.Profile
	local grid = UIUtil.Get(builder, "Modal/ItemGridFrame/ItemGrid")
	UIUtil.ClearClones(grid)
	if profile == nil or category == "AMMO" then
		return
	end
	local template = UIUtil.Button(grid, "ItemCardTemplate")
	local l = current()
	local order = 0
	for _, id in EquipmentDatabase.Order do
		local spec = EquipmentDatabase.Items[id]
		if spec and spec.Category == category then
			order += 1
			local card = UIUtil.CloneTemplate(template, "Item_" .. id)
			card.LayoutOrder = order
			local unlocked = isUnlocked(profile, id)
			UIUtil.Label(card, "Glyph").Text = UIUtil.Glyph(id)
			UIUtil.Label(card, "NameLabel").Text = spec.DisplayName
			UIUtil.Label(card, "CostLabel").Text = spec.Cost .. " PT"
			UIUtil.Label(card, "LevelLabel").Text = if unlocked then "LV" .. (profile.UnlockedItems[id] or 1) else ""
			local lock = UIUtil.Frame(card, "LockOverlay")
			lock.Visible = not unlocked
			UIUtil.Label(lock, "LockText").Text = if spec.RankedOnly then "🏆" else "🔒"
			local stroke = card:FindFirstChildOfClass("UIStroke")
			local inLoadout = table.find(l.Slots, id) ~= nil or l.Armor == id
			if stroke then
				stroke.Color = if inLoadout then T.Gold elseif selected == id then T.White else UIUtil.RarityColor(spec)
				stroke.Thickness = if inLoadout or selected == id then 3 else 1.5
			end
			card.Activated:Connect(function()
				UIUtil.Click()
				selected = id
				refreshBuilder()
			end)
		end
	end
end

local function refreshPanel()
	local l = current()
	local panel = UIUtil.Get(builder, "Modal/LoadoutPanel")
	UIUtil.Label(panel, "PresetName").Text = string.format("PRESET %d · %s", presetIndex, string.upper(l.Name))
	for i = 1, 6 do
		local row = UIUtil.Get(panel, "Slots/Slot" .. i)
		local id = l.Slots[i]
		local spec = if id then EquipmentDatabase.Get(id) else nil
		UIUtil.Label(row, "ItemName").Text = if spec then UIUtil.Glyph(spec.Id) .. "  " .. spec.DisplayName else "— empty —"
		UIUtil.Label(row, "Cost").Text = if spec then spec.Cost .. " PT" else ""
		UIUtil.Button(row, "RemoveButton").Visible = spec ~= nil
	end
	local armorRow = UIUtil.Get(panel, "ArmorSlot")
	local armor = if l.Armor then EquipmentDatabase.Get(l.Armor) else nil
	UIUtil.Label(armorRow, "ItemName").Text = if armor then armor.DisplayName else "No armor"
	UIUtil.Label(armorRow, "Cost").Text = if armor then armor.Cost .. " PT" else ""
	UIUtil.Button(armorRow, "RemoveButton").Visible = armor ~= nil
	for _, kind in { "Arrows", "Bullets", "FireArrows" } do
		local count = if kind == "Arrows" then l.Ammo.Arrows elseif kind == "Bullets" then l.Ammo.Bullets else l.Ammo.FireArrows
		UIUtil.Label(panel, "AmmoRows/" .. kind .. "/Count").Text = tostring(count)
	end
	local profile = State.Profile
	local result = Validator.Validate(l, if profile then unlockTable(profile) else nil)
	local points = UIUtil.Label(panel, "PointsLabel")
	points.Text = string.format("%d / %d PT", result.Points, Validator.MaxPoints)
	points.TextColor3 = if result.Points > Validator.MaxPoints then T.Bad else T.Gold
	UIUtil.Label(panel, "SlotsLabel").Text = string.format("%d / %d SLOTS", result.Slots, Validator.MaxSlots)
	local fill = UIUtil.Frame(panel, "PointsBar/Fill")
	UIUtil.SetFill(fill, result.Points / Validator.MaxPoints, 0.15)
	fill.BackgroundColor3 = if result.Points > Validator.MaxPoints then T.Bad else T.Gold
	UIUtil.Label(panel, "ErrorLabel").Text = if result.Ok then "" else result.Errors[1]
	local save = UIUtil.Button(panel, "SaveButton")
	save.AutoButtonColor = result.Ok
	save.BackgroundColor3 = if result.Ok then T.Good else T.PanelLighter
	local active = profile ~= nil and profile.ActivePreset == presetIndex
	save.Text = if active then "SAVE (ACTIVE)" else "SAVE & EQUIP"
end

local function refreshTabs()
	local profile = State.Profile
	for i = 1, 5 do
		local tab = UIUtil.Button(builder, "Modal/PresetTabs/Preset" .. i)
		local active = profile ~= nil and profile.ActivePreset == i
		tab.Text = if active then i .. " ★" else tostring(i)
		tab.BackgroundColor3 = if i == presetIndex then T.Gold else T.PanelLighter
		tab.TextColor3 = if i == presetIndex then T.Black else T.Text
	end
	for _, c in { "WEAPONS", "UTILITY", "HEALING", "ARMOR", "AMMO" } do
		local b = UIUtil.Button(builder, "Modal/Categories/Cat_" .. c)
		b.BackgroundColor3 = if c == category then T.Alpha else T.PanelLighter
	end
end

refreshBuilder = function()
	if not builder.Enabled then
		return
	end
	refreshTabs()
	refreshGrid()
	refreshPanel()
	refreshDetail()
end

local function resetWorking()
	local profile = State.Profile
	working = {}
	if profile then
		for i = 1, 5 do
			local p = profile.Presets[i]
			working[i] = if p then cloneLoadout(p) else Validator.EmptyLoadout("Preset " .. i)
		end
		presetIndex = math.clamp(profile.ActivePreset, 1, 5)
	end
end

onBuilderOpened = function()
	resetWorking()
	refreshBuilder()
end

local function toggleItem(id: string)
	local profile = State.Profile
	local spec = EquipmentDatabase.Get(id)
	if profile == nil or spec == nil or not isUnlocked(profile, id) then
		return
	end
	local l = current()
	if spec.Category == "ARMOR" then
		l.Armor = if l.Armor == id then nil else id
	else
		local idx = table.find(l.Slots, id)
		if idx then
			table.remove(l.Slots, idx)
		elseif #l.Slots < Validator.MaxSlots then
			table.insert(l.Slots, id)
		else
			State.Notify:Fire("All 6 slots are full", "Error")
		end
	end
	UIUtil.Click()
	refreshBuilder()
end

local function bindBuilder()
	for i = 1, 5 do
		UIUtil.Button(builder, "Modal/PresetTabs/Preset" .. i).Activated:Connect(function()
			UIUtil.Click()
			presetIndex = i
			refreshBuilder()
		end)
	end
	for _, c in { "WEAPONS", "UTILITY", "HEALING", "ARMOR", "AMMO" } do
		UIUtil.Button(builder, "Modal/Categories/Cat_" .. c).Activated:Connect(function()
			UIUtil.Click()
			category = c
			selected = nil
			refreshBuilder()
		end)
	end
	for i = 1, 6 do
		UIUtil.Button(builder, string.format("Modal/LoadoutPanel/Slots/Slot%d/RemoveButton", i)).Activated:Connect(function()
			local l = current()
			if l.Slots[i] then
				table.remove(l.Slots, i)
				UIUtil.Click()
				refreshBuilder()
			end
		end)
	end
	UIUtil.Button(builder, "Modal/LoadoutPanel/ArmorSlot/RemoveButton").Activated:Connect(function()
		current().Armor = nil
		UIUtil.Click()
		refreshBuilder()
	end)
	for _, kind in { "Arrows", "Bullets", "FireArrows" } do
		local function change(delta: number)
			local ammo = current().Ammo :: any
			ammo[kind] = math.clamp((ammo[kind] or 0) + delta, 0, Validator.MaxAmmoBundles)
			UIUtil.Click()
			refreshBuilder()
		end
		UIUtil.Button(builder, string.format("Modal/LoadoutPanel/AmmoRows/%s/Plus", kind)).Activated:Connect(function()
			change(1)
		end)
		UIUtil.Button(builder, string.format("Modal/LoadoutPanel/AmmoRows/%s/Minus", kind)).Activated:Connect(function()
			change(-1)
		end)
	end
	UIUtil.Button(builder, "Modal/LoadoutPanel/SaveButton").Activated:Connect(function()
		local profile = State.Profile
		local l = current()
		local result = Validator.Validate(l, if profile then unlockTable(profile) else nil)
		if not result.Ok then
			State.Notify:Fire(result.Errors[1] or "Loadout is not valid", "Error")
			return
		end
		Net.Reliable("SaveLoadout"):FireServer(presetIndex, l, true)
	end)
	UIUtil.Button(builder, "Modal/DetailPanel/AddButton").Activated:Connect(function()
		if selected then
			toggleItem(selected)
		end
	end)
	UIUtil.Button(builder, "Modal/DetailPanel/UpgradeButton").Activated:Connect(function()
		local id = selected
		local profile = State.Profile
		local spec = if id then EquipmentDatabase.Get(id) else nil
		if id == nil or profile == nil or spec == nil then
			return
		end
		if spec.RankedOnly and not isUnlocked(profile, id) then
			State.Notify:Fire("Win ranked matches to earn Glory and unlock this weapon", "Info")
			return
		end
		Net.Reliable("UpgradeEquipment"):FireServer(id)
	end)
	UIUtil.Button(builder, "Modal/DetailPanel/UnlockRobuxButton").Activated:Connect(function()
		if selected then
			Net.Reliable("PurchaseRequest"):FireServer("ItemUnlock", selected)
		end
	end)
end

---------------------------------------------------------------------------------------------
-- Custom matches
---------------------------------------------------------------------------------------------
local function myRoom(): Types.RoomView?
	for _, r in rooms do
		local teams: { { { UserId: number, Name: string } } } = { r.Alpha, r.Bravo }
		for _, list in teams do
			for _, m in list do
				if m.UserId == player.UserId then
					return r
				end
			end
		end
	end
	return nil
end

local function nameLabel(parent: Instance, text: string, order: number)
	local l = Instance.new("TextLabel")
	l.Name = "Entry"
	l.Text = text
	l.Size = UDim2.fromScale(1, 0.14)
	l.BackgroundTransparency = 1
	l.TextColor3 = T.White
	l.Font = T.Fonts.Bold
	l.TextScaled = true
	l.LayoutOrder = order
	l:SetAttribute("UIClone", true)
	local c = Instance.new("UITextSizeConstraint")
	c.MaxTextSize = 20
	c.Parent = l
	l.Parent = parent
end

local function refreshRooms()
	local list = UIUtil.Get(custom, "Modal/RoomListFrame/RoomList")
	UIUtil.ClearClones(list)
	local template = UIUtil.Frame(list, "RoomTemplate")
	for i, r in rooms do
		local row = UIUtil.CloneTemplate(template, "Room_" .. r.Id)
		row.LayoutOrder = i
		UIUtil.Label(row, "RoomName").Text = r.Name
		UIUtil.Label(row, "ModeLabel").Text = r.Mode .. (if r.FillBots then " 🤖" else "")
		UIUtil.Label(row, "CountLabel").Text = string.format("%d/%d", #r.Alpha + #r.Bravo, r.TeamSize * 2)
		UIUtil.Button(row, "JoinButton").Activated:Connect(function()
			UIUtil.Click()
			local team = if #r.Alpha <= #r.Bravo then "Alpha" else "Bravo"
			Net.Reliable("CustomMatchAction"):FireServer("Join", { RoomId = r.Id, Team = team })
		end)
	end
	local detail = UIUtil.Get(custom, "Modal/RoomDetail")
	local room = myRoom()
	UIUtil.Label(detail, "RoomTitle").Text = if room then string.format("%s · %s", room.Name, room.Mode) else "Not in a room"
	for _, team in { "Alpha", "Bravo" } do
		local col = UIUtil.Get(detail, team .. "List")
		UIUtil.ClearClones(col)
		if room then
			local members: { { UserId: number, Name: string } } = if team == "Alpha" then room.Alpha else room.Bravo
			for i, m in members do
				nameLabel(col, (if m.UserId == room.HostId then "★ " else "") .. m.Name, i)
			end
			for i = #members + 1, room.TeamSize do
				nameLabel(col, if room.FillBots then "🤖 bot" else "· open ·", i)
			end
		end
		UIUtil.Button(detail, "Join" .. team).Visible = room ~= nil
	end
	UIUtil.Button(detail, "StartButton").Visible = room ~= nil and room.HostId == player.UserId
	UIUtil.Button(detail, "LeaveRoomButton").Visible = room ~= nil
end

local function bindCustom()
	for _, mode in { "1v1", "2v2", "3v3" } do
		UIUtil.Button(custom, "Modal/ModeButtons/Create" .. mode).Activated:Connect(function()
			UIUtil.Click()
			Net.Reliable("CustomMatchAction"):FireServer("Create", { Mode = mode, FillBots = fillBots })
		end)
	end
	local toggle = UIUtil.Button(custom, "Modal/FillBotsToggle")
	toggle.Activated:Connect(function()
		UIUtil.Click()
		fillBots = not fillBots
		toggle.Text = if fillBots then "BOT FILL: ON" else "BOT FILL: OFF"
		toggle.BackgroundColor3 = if fillBots then T.Good else T.PanelLighter
	end)
	for _, team in { "Alpha", "Bravo" } do
		UIUtil.Button(custom, "Modal/RoomDetail/Join" .. team).Activated:Connect(function()
			local room = myRoom()
			if room then
				Net.Reliable("CustomMatchAction"):FireServer("Join", { RoomId = room.Id, Team = team })
			end
		end)
	end
	UIUtil.Button(custom, "Modal/RoomDetail/StartButton").Activated:Connect(function()
		UIUtil.Click()
		Net.Reliable("CustomMatchAction"):FireServer("Start")
	end)
	UIUtil.Button(custom, "Modal/RoomDetail/LeaveRoomButton").Activated:Connect(function()
		UIUtil.Click()
		Net.Reliable("CustomMatchAction"):FireServer("Leave")
	end)
	Net.Reliable("CustomMatchAction").OnClientEvent:Connect(function(kind: any, payload: any)
		if kind == "Rooms" and type(payload) == "table" then
			rooms = payload
			refreshRooms()
		end
	end)
	refreshRooms()
end

---------------------------------------------------------------------------------------------
-- Tribe hall
---------------------------------------------------------------------------------------------
local function refreshMyTribe()
	local mine = UIUtil.Get(tribeHall, "Modal/MyTribe")
	local tribe = myTribe
	UIUtil.Label(mine, "MyTribeName").Text = if tribe then string.format("[%s] %s", tostring(tribe.Tag), tostring(tribe.Name)) else "No tribe"
	UIUtil.Label(mine, "MyTribeGlory").Text = if tribe then string.format("%d RP / week", tonumber(tribe.WeeklyGlory) or 0) else ""
	local members = UIUtil.Get(mine, "Members")
	UIUtil.ClearClones(members)
	local template = UIUtil.Label(members, "MemberTemplate")
	if tribe and type(tribe.Members) == "table" then
		for i, m in tribe.Members do
			if type(m) == "table" then
				local row = UIUtil.CloneTemplate(template, "Member" .. i)
				row.LayoutOrder = i
				row.Text = (if m.UserId == tribe.Leader then "★ " else "• ") .. tostring(m.Name)
			end
		end
	end
	UIUtil.Button(mine, "LeaveButton").Visible = tribe ~= nil
	UIUtil.Frame(tribeHall, "Modal/CreateSection").Visible = tribe == nil
	refreshProfileCard()
end

local function showTribeResults(list: { any })
	local container = UIUtil.Get(tribeHall, "Modal/BrowseSection/TribeList")
	UIUtil.ClearClones(container)
	local template = UIUtil.Frame(container, "TribeTemplate")
	for i, t in list do
		if type(t) == "table" then
			local row = UIUtil.CloneTemplate(template, "Tribe" .. i)
			row.LayoutOrder = i
			UIUtil.Label(row, "TagLabel").Text = "[" .. tostring(t.Tag) .. "]"
			UIUtil.Label(row, "NameLabel").Text = tostring(t.Name)
			UIUtil.Label(row, "MembersLabel").Text = string.format("%d/20", tonumber(t.MemberCount) or 0)
			UIUtil.Label(row, "GloryLabel").Text = string.format("%d RP", tonumber(t.WeeklyGlory) or 0)
			local join = UIUtil.Button(row, "JoinButton")
			join.Visible = myTribe == nil
			join.Activated:Connect(function()
				UIUtil.Click()
				Net.Reliable("TribeAction"):FireServer("Join", t.Tag)
			end)
		end
	end
end

local function bindTribe()
	UIUtil.Button(tribeHall, "Modal/CreateSection/CreateButton").Activated:Connect(function()
		UIUtil.Click()
		local name = UIUtil.Box(tribeHall, "Modal/CreateSection/NameBox").Text
		local tag = UIUtil.Box(tribeHall, "Modal/CreateSection/TagBox").Text
		UIUtil.Label(tribeHall, "Modal/CreateSection/CreateStatus").Text = "Founding..."
		Net.Reliable("TribeAction"):FireServer("Create", name, tag)
	end)
	UIUtil.Button(tribeHall, "Modal/MyTribe/LeaveButton").Activated:Connect(function()
		UIUtil.Click()
		Net.Reliable("TribeAction"):FireServer("Leave")
	end)
	UIUtil.Button(tribeHall, "Modal/BrowseSection/SearchButton").Activated:Connect(function()
		UIUtil.Click()
		local q = UIUtil.Box(tribeHall, "Modal/BrowseSection/SearchBox").Text
		if string.match(q, "%w") then
			Net.Reliable("TribeAction"):FireServer("Search", q)
		else
			Net.Reliable("TribeAction"):FireServer("Browse")
		end
	end)
	Net.Reliable("TribeAction").OnClientEvent:Connect(function(kind: any, payload: any)
		if kind == "Mine" then
			myTribe = if type(payload) == "table" then payload else nil
			refreshMyTribe()
		elseif kind == "Results" and type(payload) == "table" then
			showTribeResults(payload)
		elseif kind == "Status" and type(payload) == "string" then
			UIUtil.Label(tribeHall, "Modal/CreateSection/CreateStatus").Text = payload
		end
	end)
end

---------------------------------------------------------------------------------------------
-- Settings
---------------------------------------------------------------------------------------------
type SliderDef = { Name: string, Key: string, Min: number, Max: number, Step: number, Format: string }
local SLIDERS: { SliderDef } = {
	{ Name = "CameraSensitivity", Key = "CameraSensitivity", Min = 0.1, Max = 3, Step = 0.05, Format = "%.2f" },
	{ Name = "FieldOfView", Key = "FieldOfView", Min = 70, Max = 120, Step = 1, Format = "%d" },
}
local TOGGLES = { "ViewBobbing", "PreventFullBotMatches", "FirstPersonDefault" }
local saveToken = 0

local function queueSettingsSave()
	saveToken += 1
	local token = saveToken
	task.delay(0.35, function()
		local profile = State.Profile
		if token == saveToken and profile then
			Net.Reliable("UpdateSettings"):FireServer(table.clone(profile.Settings))
		end
	end)
end

local function refreshSettings()
	local profile = State.Profile
	if profile == nil then
		return
	end
	local s = profile.Settings :: any
	for _, def in SLIDERS do
		local row = UIUtil.Get(settingsGui, "Modal/Rows/" .. def.Name)
		local value = tonumber(s[def.Key]) or def.Min
		local ratio = (value - def.Min) / (def.Max - def.Min)
		UIUtil.Frame(row, "Track/Fill").Size = UDim2.fromScale(math.clamp(ratio, 0, 1), 1)
		UIUtil.Button(row, "Track/Knob").Position = UDim2.fromScale(math.clamp(ratio, 0, 1), 0.5)
		UIUtil.Label(row, "Value").Text = string.format(def.Format, if def.Step >= 1 then math.floor(value + 0.5) else value)
	end
	for _, key in TOGGLES do
		local b = UIUtil.Button(settingsGui, "Modal/Rows/" .. key .. "/Toggle")
		local on = s[key] == true
		b.Text = if on then "ON" else "OFF"
		b.BackgroundColor3 = if on then T.Good else T.PanelLighter
	end
end

local function bindSettings()
	local dragging: SliderDef? = nil
	local function setFromX(def: SliderDef, x: number)
		local profile = State.Profile
		if profile == nil then
			return
		end
		local track = UIUtil.Frame(settingsGui, "Modal/Rows/" .. def.Name .. "/Track")
		local ratio = math.clamp((x - track.AbsolutePosition.X) / math.max(track.AbsoluteSize.X, 1), 0, 1)
		local raw = def.Min + (def.Max - def.Min) * ratio
		local value = math.clamp(math.floor(raw / def.Step + 0.5) * def.Step, def.Min, def.Max)
		local s = profile.Settings :: any
		if s[def.Key] ~= value then
			s[def.Key] = value
			State.ProfileChanged:Fire(profile)
			refreshSettings()
			queueSettingsSave()
		end
	end
	for _, def in SLIDERS do
		local track = UIUtil.Frame(settingsGui, "Modal/Rows/" .. def.Name .. "/Track")
		local knob = UIUtil.Button(track, "Knob")
		local function begin(input: InputObject)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				dragging = def
				setFromX(def, input.Position.X)
			end
		end
		track.InputBegan:Connect(begin)
		knob.InputBegan:Connect(begin)
	end
	UserInputService.InputChanged:Connect(function(input)
		local def = dragging
		if def and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			setFromX(def, input.Position.X)
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = nil
		end
	end)
	for _, key in TOGGLES do
		UIUtil.Button(settingsGui, "Modal/Rows/" .. key .. "/Toggle").Activated:Connect(function()
			local profile = State.Profile
			if profile == nil then
				return
			end
			UIUtil.Click()
			local s = profile.Settings :: any
			s[key] = not (s[key] == true)
			State.ProfileChanged:Fire(profile)
			refreshSettings()
			queueSettingsSave()
		end)
	end
end

---------------------------------------------------------------------------------------------
function Lobby.Init()
	hud = UIUtil.Gui("LobbyHUD")
	builder = UIUtil.Gui("LoadoutBuilder")
	custom = UIUtil.Gui("CustomMatches")
	tribeHall = UIUtil.Gui("TribeHall")
	settingsGui = UIUtil.Gui("Settings")
	modalGuis = { LoadoutBuilder = builder, CustomMatches = custom, TribeHall = tribeHall, Settings = settingsGui }
end

function Lobby.Start()
	for name, g in modalGuis do
		local gui = g :: ScreenGui
		gui.Enabled = false
		UIUtil.Button(gui, "Modal/CloseButton").Activated:Connect(function()
			UIUtil.Click()
			Lobby.Close(name)
		end)
	end
	hud.Enabled = true
	UIUtil.Frame(hud, "PartyInvite").Visible = false

	-- side buttons
	UIUtil.Button(hud, "SideButtons/LoadoutButton").Activated:Connect(function()
		Lobby.Toggle("LoadoutBuilder")
	end)
	UIUtil.Button(hud, "SideButtons/CustomButton").Activated:Connect(function()
		Lobby.Toggle("CustomMatches")
	end)
	UIUtil.Button(hud, "SideButtons/TribeButton").Activated:Connect(function()
		Lobby.Toggle("TribeHall")
	end)
	UIUtil.Button(hud, "SideButtons/SettingsButton").Activated:Connect(function()
		Lobby.Toggle("Settings")
		refreshSettings()
	end)
	UIUtil.Button(hud, "SideButtons/GoldenDropButton").Activated:Connect(function()
		UIUtil.Click()
		Net.Reliable("PurchaseRequest"):FireServer("GoldenDrop")
	end)
	UIUtil.Button(hud, "SideButtons/RestoreStreakButton").Activated:Connect(function()
		UIUtil.Click()
		Net.Reliable("PurchaseRequest"):FireServer("RestoreStreak")
	end)

	-- play / queue
	UIUtil.Button(hud, "PlayPanel/PlayButton").Activated:Connect(function()
		if queue and queue.Queued then
			return
		end
		UIUtil.Click()
		Net.Reliable("QueueAction"):FireServer("Join")
	end)
	UIUtil.Button(hud, "PlayPanel/CancelButton").Activated:Connect(function()
		UIUtil.Click()
		Net.Reliable("QueueAction"):FireServer("Leave")
	end)
	Net.Reliable("QueueAction").OnClientEvent:Connect(function(kind: any, payload: any)
		if kind == "Status" and type(payload) == "table" then
			queue = {
				Queued = payload.Queued == true,
				Elapsed = tonumber(payload.Elapsed) or 0,
				InQueue = tonumber(payload.InQueue) or 0,
				BotFillIn = tonumber(payload.BotFillIn) or 0,
				Found = payload.Found == true,
				ReceivedAt = os.clock(),
			}
			refreshQueue()
		end
	end)

	-- party
	UIUtil.Button(hud, "PartyPanel/InviteButton").Activated:Connect(function()
		local box = UIUtil.Box(hud, "PartyPanel/InviteBox")
		if box.Text ~= "" then
			UIUtil.Click()
			Net.Reliable("PartyAction"):FireServer("Invite", box.Text)
			box.Text = ""
		end
	end)
	UIUtil.Button(hud, "PartyPanel/LeaveButton").Activated:Connect(function()
		UIUtil.Click()
		Net.Reliable("PartyAction"):FireServer("Leave")
	end)
	UIUtil.Button(hud, "PartyInvite/AcceptButton").Activated:Connect(function()
		UIUtil.Click()
		Net.Reliable("PartyAction"):FireServer("Accept")
		UIUtil.Frame(hud, "PartyInvite").Visible = false
	end)
	UIUtil.Button(hud, "PartyInvite/DeclineButton").Activated:Connect(function()
		UIUtil.Click()
		Net.Reliable("PartyAction"):FireServer("Decline")
		UIUtil.Frame(hud, "PartyInvite").Visible = false
	end)
	Net.Reliable("PartyAction").OnClientEvent:Connect(function(kind: any, payload: any)
		if kind == "State" and type(payload) == "table" then
			State.Party = payload :: Types.PartyView
			State.PartyChanged:Fire(State.Party)
			refreshParty()
		elseif kind == "Invite" and type(payload) == "table" then
			showInvite(tostring(payload.FromName))
		end
	end)

	-- interfaces opened from the world
	Net.Reliable("OpenInterface").OnClientEvent:Connect(function(name: any)
		if type(name) ~= "string" or modalGuis[name] == nil then
			return
		end
		-- the builder prompt shares the B key with the toggle: ignore the echo of that press
		if os.clock() - lastToggleAt < 0.6 then
			return
		end
		Lobby.Open(name)
	end)
	Net.Reliable("SaveLoadout").OnClientEvent:Connect(function(ok: any, errors: any)
		if ok == true then
			State.Notify:Fire(string.format("Preset %d saved and equipped", presetIndex), "Success")
		elseif type(errors) == "table" and type(errors[1]) == "string" then
			UIUtil.Label(builder, "Modal/LoadoutPanel/ErrorLabel").Text = errors[1]
		end
	end)
	Net.Reliable("UpgradeEquipment").OnClientEvent:Connect(function(ok: any)
		if ok == true then
			UIUtil.Click()
		end
	end)

	bindBuilder()
	bindCustom()
	bindTribe()
	bindSettings()

	State.ProfileChanged:Connect(function()
		refreshProfileCard()
		if builder.Enabled then
			-- keep unsaved edits; refresh locks, levels and shards
			refreshBuilder()
		end
		if settingsGui.Enabled then
			refreshSettings()
		end
	end)
	State.RoundChanged:Connect(function(round)
		if round ~= nil then
			Lobby.CloseAll()
		end
	end)
	refreshParty()
	refreshProfileCard()
	Net.Reliable("TribeAction"):FireServer("Mine")

	task.spawn(function()
		while true do
			task.wait(0.3)
			refreshHint()
			if queue and queue.Queued then
				refreshQueue()
			end
		end
	end)
end

return Lobby
