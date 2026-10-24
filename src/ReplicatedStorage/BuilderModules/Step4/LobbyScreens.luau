--!strict
-- Step 4a: lobby ScreenGuis - LobbyHUD, LoadoutBuilder (12-point builder), CustomMatches,
-- TribeHall and Settings. Element names are the contract used by the client controllers.

local UIKit = require(script.Parent.Parent.Kit.UIKit)
local MonetizationCatalog = require(script.Parent.Parent.Parent.Modules.Config.MonetizationCatalog)

local U = UIKit
local T = UIKit.Theme
local S = UDim2.fromScale
local V2 = Vector2.new

local LobbyScreens = {}

local goldenDrop = MonetizationCatalog.ByKey("GoldenDrop")
local GOLDEN_DROP_LABEL = if goldenDrop then string.format("GOLDEN DROP %dR$", goldenDrop.PriceRobux) else "GOLDEN DROP"

local function modal(gui: ScreenGui, title: string, size: UDim2, aspect: number): Frame
	local dim = U.Frame(gui, "Dim", S(1, 1), S(0, 0), nil, T.Black, 0.45)
	dim.ZIndex = 0
	local m = U.Panel(gui, "Modal", size, S(0.5, 0.5), V2(0.5, 0.5), aspect)
	U.Text(m, "Title", title, S(0.6, 0.07), S(0.02, 0.015), T.Gold, T.Fonts.Title, Enum.TextXAlignment.Left, 36)
	U.CloseButton(m)
	return m
end

---------------------------------------------------------------------------------------------
function LobbyScreens.LobbyHUD(parent: Instance): ScreenGui
	local gui = U.Screen(parent, "LobbyHUD", 5, true)

	local profile = U.Panel(gui, "ProfileCard", S(0.24, 0.14), S(0.012, 0.02), nil, 3.2)
	U.Text(profile, "NameLabel", "Player", S(0.62, 0.3), S(0.05, 0.08), T.Text, T.Fonts.Title, Enum.TextXAlignment.Left, 30)
	U.Text(profile, "LevelLabel", "LV 1", S(0.28, 0.3), S(0.68, 0.08), T.Gold, T.Fonts.Title, Enum.TextXAlignment.Right, 30)
	local _, xpFill = U.Bar(profile, "XPBar", S(0.9, 0.12), S(0.05, 0.45), T.Gold)
	xpFill.Size = S(0, 1)
	U.Text(profile, "StreakLabel", "🔥 0", S(0.28, 0.26), S(0.05, 0.64), T.Text, T.Fonts.Bold, Enum.TextXAlignment.Left, 24)
	U.Text(profile, "GloryLabel", "0 RP", S(0.3, 0.26), S(0.35, 0.64), T.Gold, T.Fonts.Bold, Enum.TextXAlignment.Center, 24)
	U.Text(profile, "TribeLabel", "[—]", S(0.3, 0.26), S(0.65, 0.64), T.SubText, T.Fonts.Bold, Enum.TextXAlignment.Right, 24)

	local currency = U.Panel(gui, "CurrencyCard", S(0.16, 0.07), S(0.988, 0.02), V2(1, 0), 3.4)
	U.Text(currency, "ShardsLabel", "💎 0 SHARDS", S(0.9, 0.8), S(0.05, 0.1), Color3.fromRGB(120, 220, 255), T.Fonts.Title, Enum.TextXAlignment.Center, 28)

	-- left vertical action list
	local side = U.Group(gui, "SideButtons", S(0.15, 0.46), S(0.012, 0.2))
	U.List(side, Enum.FillDirection.Vertical, 0.025, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Top)
	local actions: { { Name: string, Text: string, Color: Color3 } } = {
		{ Name = "LoadoutButton", Text = "[B] LOADOUT", Color = Color3.fromRGB(40, 110, 220) },
		{ Name = "CustomButton", Text = "CUSTOM MATCH", Color = Color3.fromRGB(120, 80, 50) },
		{ Name = "TribeButton", Text = "TRIBE HALL", Color = Color3.fromRGB(140, 40, 50) },
		{ Name = "SettingsButton", Text = "SETTINGS", Color = T.PanelLighter },
		{ Name = "GoldenDropButton", Text = GOLDEN_DROP_LABEL, Color = Color3.fromRGB(200, 150, 30) },
		{ Name = "RestoreStreakButton", Text = "RESTORE STREAK", Color = Color3.fromRGB(200, 80, 30) },
	}
	for i, a in actions do
		local b = U.Button(side, a.Name, a.Text, S(1, 0.14), S(0, 0), a.Color)
		b.LayoutOrder = i
	end

	-- play panel
	local play = U.Panel(gui, "PlayPanel", S(0.3, 0.17), S(0.5, 0.965), V2(0.5, 1), 3.6)
	local playBtn = U.Button(play, "PlayButton", "PLAY 3v3", S(0.62, 0.5), S(0.04, 0.1), Color3.fromRGB(60, 190, 90))
	U.Gradient(playBtn, U.Grad2(Color3.fromRGB(255, 255, 255), Color3.fromRGB(160, 220, 170)), 90)
	local cancel = U.Button(play, "CancelButton", "CANCEL", S(0.3, 0.5), S(0.67, 0.1), T.Bad)
	cancel.Visible = false
	U.Text(play, "QueueStatus", "Ready to fight", S(0.92, 0.2), S(0.04, 0.62), T.SubText, T.Fonts.Bold, Enum.TextXAlignment.Center, 22)
	U.Text(play, "BotFillLabel", "", S(0.92, 0.14), S(0.04, 0.82), T.Gold, T.Fonts.Body, Enum.TextXAlignment.Center, 16)

	-- party panel
	local party = U.Panel(gui, "PartyPanel", S(0.2, 0.28), S(0.012, 0.965), V2(0, 1), 1.25)
	U.Text(party, "Title", "PARTY", S(0.6, 0.12), S(0.05, 0.03), T.Gold, T.Fonts.Title, Enum.TextXAlignment.Left, 24)
	local members = U.Group(party, "MemberList", S(0.9, 0.45), S(0.05, 0.17))
	U.List(members, Enum.FillDirection.Vertical, 0.03, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Top)
	local template = U.Frame(members, "MemberTemplate", S(1, 0.3), S(0, 0), nil, T.PanelLighter, 0.2)
	U.Corner(template, 0.25, 0)
	U.Text(template, "Name", "Member", S(0.7, 0.8), S(0.04, 0.1), T.Text, T.Fonts.Bold, Enum.TextXAlignment.Left, 20)
	U.Text(template, "Role", "LEADER", S(0.24, 0.8), S(0.74, 0.1), T.Gold, T.Fonts.Bold, Enum.TextXAlignment.Right, 14)
	template.Visible = false
	U.TextBox(party, "InviteBox", "Player name", S(0.58, 0.14), S(0.05, 0.66))
	U.Button(party, "InviteButton", "INVITE", S(0.3, 0.14), S(0.65, 0.66), T.Alpha)
	U.Button(party, "LeaveButton", "LEAVE", S(0.9, 0.12), S(0.05, 0.84), T.PanelLighter)

	local invite = U.Panel(gui, "PartyInvite", S(0.26, 0.12), S(0.5, 0.2), V2(0.5, 0), 3.6)
	invite.Visible = false
	U.Text(invite, "InviteText", "X invited you to a party", S(0.92, 0.42), S(0.04, 0.06), T.Text, T.Fonts.Bold, Enum.TextXAlignment.Center, 22)
	U.Button(invite, "AcceptButton", "ACCEPT", S(0.42, 0.38), S(0.05, 0.55), T.Good)
	U.Button(invite, "DeclineButton", "DECLINE", S(0.42, 0.38), S(0.53, 0.55), T.Bad)

	local toasts = U.Group(gui, "Toasts", S(0.34, 0.3), S(0.5, 0.11), V2(0.5, 0))
	U.List(toasts, Enum.FillDirection.Vertical, 0.04, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Top)
	local toast = U.Frame(toasts, "ToastTemplate", S(1, 0.2), S(0, 0), nil, T.Panel, 0.15)
	U.Corner(toast, 0.3, 0)
	U.Stroke(toast, T.Gold, 1.5, 0.3)
	U.Text(toast, "Message", "", S(0.94, 0.8), S(0.03, 0.1), T.Text, T.Fonts.Bold, Enum.TextXAlignment.Center, 22)
	toast.Visible = false

	local hint = U.Text(gui, "InteractHint", "", S(0.3, 0.04), S(0.5, 0.74), T.Text, T.Fonts.Bold, Enum.TextXAlignment.Center, 22)
	hint.AnchorPoint = V2(0.5, 0)
	return gui
end

---------------------------------------------------------------------------------------------
function LobbyScreens.LoadoutBuilder(parent: Instance): ScreenGui
	local gui = U.Screen(parent, "LoadoutBuilder", 20, false)
	local m = modal(gui, "LOADOUT BUILDER", S(0.9, 0.86), 16 / 9)

	-- preset tabs
	local tabs = U.Group(m, "PresetTabs", S(0.42, 0.06), S(0.4, 0.02))
	U.List(tabs, Enum.FillDirection.Horizontal, 0.012, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center)
	for i = 1, 5 do
		local b = U.Button(tabs, "Preset" .. i, tostring(i), S(0.18, 1), S(0, 0), T.PanelLighter)
		b.LayoutOrder = i
	end

	-- categories
	local cats = U.Group(m, "Categories", S(0.12, 0.5), S(0.02, 0.11))
	U.List(cats, Enum.FillDirection.Vertical, 0.02, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Top)
	for i, c in { "WEAPONS", "UTILITY", "HEALING", "ARMOR", "AMMO" } do
		local b = U.Button(cats, "Cat_" .. c, c, S(1, 0.16), S(0, 0), T.PanelLighter)
		b.LayoutOrder = i
	end

	-- item grid
	local gridFrame = U.Frame(m, "ItemGridFrame", S(0.5, 0.56), S(0.15, 0.11), nil, T.Black, 0.6)
	U.Corner(gridFrame, 0.02, 0)
	local grid = Instance.new("ScrollingFrame")
	grid.Name = "ItemGrid"
	grid.Size = S(0.97, 0.96)
	grid.Position = S(0.015, 0.02)
	grid.BackgroundTransparency = 1
	grid.BorderSizePixel = 0
	grid.ScrollBarThickness = 6
	grid.AutomaticCanvasSize = Enum.AutomaticSize.Y
	grid.CanvasSize = UDim2.new()
	grid.Parent = gridFrame
	U.Grid(grid, S(0.235, 0.3), S(0.012, 0.02), 4)
	local card = Instance.new("TextButton")
	card.Name = "ItemCardTemplate"
	card.Text = ""
	card.BackgroundColor3 = T.PanelLight
	card.BorderSizePixel = 0
	card.AutoButtonColor = true
	card.Visible = false
	card.Parent = grid
	U.Corner(card, 0.08, 0)
	U.Stroke(card, T.Stroke, 1.5, 0.2)
	U.Gradient(card, U.Grad2(T.PanelLighter, T.PanelLight), 90)
	U.Text(card, "Glyph", "⚔", S(0.6, 0.42), S(0.2, 0.06), T.Text, T.Fonts.Title, Enum.TextXAlignment.Center, 40)
	U.Text(card, "NameLabel", "Item", S(0.92, 0.2), S(0.04, 0.5), T.Text, T.Fonts.Bold, Enum.TextXAlignment.Center, 18)
	U.Text(card, "CostLabel", "3 PT", S(0.44, 0.18), S(0.04, 0.76), T.Gold, T.Fonts.Title, Enum.TextXAlignment.Left, 16)
	U.Text(card, "LevelLabel", "LV1", S(0.44, 0.18), S(0.52, 0.76), T.SubText, T.Fonts.Bold, Enum.TextXAlignment.Right, 16)
	local lock = U.Frame(card, "LockOverlay", S(1, 1), S(0, 0), nil, T.Black, 0.45)
	U.Corner(lock, 0.08, 0)
	U.Text(lock, "LockText", "🔒", S(0.5, 0.4), S(0.25, 0.08), T.White, T.Fonts.Title, Enum.TextXAlignment.Center, 36)
	lock.Visible = false

	-- loadout panel (right)
	local panel = U.Frame(m, "LoadoutPanel", S(0.32, 0.86), S(0.665, 0.11), nil, T.Black, 0.6)
	U.Corner(panel, 0.03, 0)
	U.Padding(panel, 0.02)
	U.Text(panel, "PresetName", "PRESET 1", S(1, 0.06), S(0, 0), T.Gold, T.Fonts.Title, Enum.TextXAlignment.Left, 26)
	local slots = U.Group(panel, "Slots", S(1, 0.46), S(0, 0.07))
	U.List(slots, Enum.FillDirection.Vertical, 0.015, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Top)
	for i = 1, 6 do
		local slot = U.Frame(slots, "Slot" .. i, S(1, 0.15), S(0, 0), nil, T.PanelLight, 0.1)
		slot.LayoutOrder = i
		U.Corner(slot, 0.2, 0)
		U.Stroke(slot, T.Stroke, 1, 0.3)
		U.Text(slot, "Key", tostring(i), S(0.1, 0.8), S(0.02, 0.1), T.SubText, T.Fonts.Title, Enum.TextXAlignment.Center, 20)
		U.Text(slot, "ItemName", "— empty —", S(0.56, 0.8), S(0.13, 0.1), T.Text, T.Fonts.Bold, Enum.TextXAlignment.Left, 20)
		U.Text(slot, "Cost", "", S(0.14, 0.8), S(0.68, 0.1), T.Gold, T.Fonts.Title, Enum.TextXAlignment.Right, 18)
		local rm = U.Button(slot, "RemoveButton", "✕", S(0.12, 0.8), S(0.85, 0.1), T.Bad)
		U.Aspect(rm, 1)
	end
	local armor = U.Frame(panel, "ArmorSlot", S(1, 0.07), S(0, 0.54), nil, Color3.fromRGB(20, 40, 70), 0.1)
	U.Corner(armor, 0.2, 0)
	U.Stroke(armor, T.Armor, 1.5, 0.2)
	U.Text(armor, "Key", "🛡", S(0.1, 0.8), S(0.02, 0.1), T.Armor, T.Fonts.Title, Enum.TextXAlignment.Center, 20)
	U.Text(armor, "ItemName", "No armor", S(0.56, 0.8), S(0.13, 0.1), T.Text, T.Fonts.Bold, Enum.TextXAlignment.Left, 20)
	U.Text(armor, "Cost", "", S(0.14, 0.8), S(0.68, 0.1), T.Gold, T.Fonts.Title, Enum.TextXAlignment.Right, 18)
	local arm = U.Button(armor, "RemoveButton", "✕", S(0.12, 0.8), S(0.85, 0.1), T.Bad)
	U.Aspect(arm, 1)
	local ammo = U.Group(panel, "AmmoRows", S(1, 0.17), S(0, 0.62))
	U.List(ammo, Enum.FillDirection.Vertical, 0.04, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Top)
	for i, kind in { "Arrows", "Bullets", "FireArrows" } do
		local row = U.Frame(ammo, kind, S(1, 0.3), S(0, 0), nil, T.PanelLight, 0.2)
		row.LayoutOrder = i
		U.Corner(row, 0.25, 0)
		local label = if kind == "Arrows" then "ARROWS ×12 · 1 PT" elseif kind == "Bullets" then "BULLETS ×6 · 1 PT" else "FIRE ARROWS ×6 · 2 PT"
		U.Text(row, "Label", label, S(0.5, 0.8), S(0.03, 0.1), T.Text, T.Fonts.Bold, Enum.TextXAlignment.Left, 18)
		local minus = U.Button(row, "Minus", "−", S(0.1, 0.8), S(0.58, 0.1), T.PanelLighter)
		U.Aspect(minus, 1)
		U.Text(row, "Count", "0", S(0.12, 0.8), S(0.7, 0.1), T.Gold, T.Fonts.Title, Enum.TextXAlignment.Center, 20)
		local plus = U.Button(row, "Plus", "+", S(0.1, 0.8), S(0.84, 0.1), T.PanelLighter)
		U.Aspect(plus, 1)
	end
	U.Text(panel, "PointsLabel", "0 / 12 PT", S(0.5, 0.05), S(0, 0.8), T.Gold, T.Fonts.Title, Enum.TextXAlignment.Left, 26)
	U.Text(panel, "SlotsLabel", "0 / 6 SLOTS", S(0.5, 0.05), S(0.5, 0.8), T.SubText, T.Fonts.Bold, Enum.TextXAlignment.Right, 20)
	local _, pfill = U.Bar(panel, "PointsBar", S(1, 0.022), S(0, 0.86), T.Gold)
	pfill.Size = S(0, 1)
	U.Text(panel, "ErrorLabel", "", S(1, 0.04), S(0, 0.89), T.Bad, T.Fonts.Bold, Enum.TextXAlignment.Left, 16)
	U.Button(panel, "SaveButton", "SAVE & EQUIP", S(1, 0.07), S(0, 0.93), T.Good)

	-- detail / upgrade panel (bottom of the grid column)
	local detail = U.Frame(m, "DetailPanel", S(0.63, 0.25), S(0.02, 0.72), nil, T.Black, 0.6)
	U.Corner(detail, 0.04, 0)
	U.Padding(detail, 0.03)
	U.Text(detail, "DetailName", "Select an item", S(0.6, 0.2), S(0, 0), T.Text, T.Fonts.Title, Enum.TextXAlignment.Left, 30)
	U.Text(detail, "DetailLevel", "", S(0.38, 0.2), S(0.62, 0), T.Gold, T.Fonts.Title, Enum.TextXAlignment.Right, 26)
	U.Text(detail, "DetailDesc", "", S(0.62, 0.24), S(0, 0.22), T.SubText, T.Fonts.Body, Enum.TextXAlignment.Left, 18)
	U.Text(detail, "DetailStats", "", S(0.62, 0.28), S(0, 0.48), T.Text, T.Fonts.Mono, Enum.TextXAlignment.Left, 16)
	local _, sfill = U.Bar(detail, "ShardBar", S(0.62, 0.1), S(0, 0.82), Color3.fromRGB(120, 220, 255))
	sfill.Size = S(0, 1)
	U.Text(detail, "ShardLabel", "", S(0.62, 0.1), S(0, 0.82), T.White, T.Fonts.Bold, Enum.TextXAlignment.Center, 14)
	U.Button(detail, "AddButton", "ADD TO LOADOUT", S(0.34, 0.26), S(0.66, 0.22), T.Alpha)
	U.Button(detail, "UpgradeButton", "UPGRADE", S(0.34, 0.24), S(0.66, 0.5), Color3.fromRGB(120, 220, 255), T.Black)
	U.Button(detail, "UnlockRobuxButton", "UNLOCK R$", S(0.34, 0.2), S(0.66, 0.78), Color3.fromRGB(60, 190, 90))
	return gui
end

---------------------------------------------------------------------------------------------
function LobbyScreens.CustomMatches(parent: Instance): ScreenGui
	local gui = U.Screen(parent, "CustomMatches", 20, false)
	local m = modal(gui, "CUSTOM MATCHES", S(0.7, 0.72), 16 / 10)
	local modes = U.Group(m, "ModeButtons", S(0.5, 0.08), S(0.02, 0.11))
	U.List(modes, Enum.FillDirection.Horizontal, 0.02, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center)
	for i, mode in { "1v1", "2v2", "3v3" } do
		local b = U.Button(modes, "Create" .. mode, "CREATE " .. mode, S(0.31, 1), S(0, 0), Color3.fromRGB(120, 80, 50))
		b.LayoutOrder = i
	end
	U.Button(m, "FillBotsToggle", "BOT FILL: OFF", S(0.2, 0.08), S(0.55, 0.11), T.PanelLighter)

	local listFrame = U.Frame(m, "RoomListFrame", S(0.46, 0.76), S(0.02, 0.21), nil, T.Black, 0.6)
	U.Corner(listFrame, 0.03, 0)
	local list = Instance.new("ScrollingFrame")
	list.Name = "RoomList"
	list.Size = S(0.96, 0.96)
	list.Position = S(0.02, 0.02)
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.ScrollBarThickness = 6
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.CanvasSize = UDim2.new()
	list.Parent = listFrame
	U.List(list, Enum.FillDirection.Vertical, 0.015, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Top)
	local room = U.Frame(list, "RoomTemplate", S(1, 0.13), S(0, 0), nil, T.PanelLight, 0.1)
	U.Corner(room, 0.2, 0)
	U.Text(room, "RoomName", "Room", S(0.5, 0.8), S(0.03, 0.1), T.Text, T.Fonts.Bold, Enum.TextXAlignment.Left, 20)
	U.Text(room, "ModeLabel", "3v3", S(0.14, 0.8), S(0.5, 0.1), T.Gold, T.Fonts.Title, Enum.TextXAlignment.Center, 20)
	U.Text(room, "CountLabel", "0/6", S(0.14, 0.8), S(0.63, 0.1), T.SubText, T.Fonts.Bold, Enum.TextXAlignment.Center, 18)
	U.Button(room, "JoinButton", "JOIN", S(0.2, 0.8), S(0.78, 0.1), T.Alpha)
	room.Visible = false

	local detail = U.Frame(m, "RoomDetail", S(0.48, 0.76), S(0.5, 0.21), nil, T.Black, 0.6)
	U.Corner(detail, 0.03, 0)
	U.Padding(detail, 0.03)
	U.Text(detail, "RoomTitle", "Not in a room", S(1, 0.1), S(0, 0), T.Gold, T.Fonts.Title, Enum.TextXAlignment.Left, 26)
	for i, team in { "Alpha", "Bravo" } do
		local col = U.Frame(detail, team .. "List", S(0.48, 0.55), S((i - 1) * 0.52, 0.13), nil, if team == "Alpha" then T.Alpha else T.Bravo, 0.75)
		U.Corner(col, 0.06, 0)
		U.List(col, Enum.FillDirection.Vertical, 0.03, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Top)
		U.Padding(col, 0.04)
		local h = U.Text(col, "Header", string.upper(team), S(1, 0.16), S(0, 0), T.White, T.Fonts.Title, Enum.TextXAlignment.Center, 22)
		h.LayoutOrder = 0
		U.Button(detail, "Join" .. team, "JOIN " .. string.upper(team), S(0.48, 0.1), S((i - 1) * 0.52, 0.7), if team == "Alpha" then T.Alpha else T.Bravo)
	end
	U.Button(detail, "StartButton", "START MATCH", S(0.48, 0.12), S(0, 0.84), T.Good)
	U.Button(detail, "LeaveRoomButton", "LEAVE ROOM", S(0.48, 0.12), S(0.52, 0.84), T.PanelLighter)
	return gui
end

---------------------------------------------------------------------------------------------
function LobbyScreens.TribeHall(parent: Instance): ScreenGui
	local gui = U.Screen(parent, "TribeHall", 20, false)
	local m = modal(gui, "TRIBE HALL", S(0.72, 0.74), 16 / 10)

	local create = U.Frame(m, "CreateSection", S(0.46, 0.34), S(0.02, 0.11), nil, T.Black, 0.6)
	U.Corner(create, 0.04, 0)
	U.Padding(create, 0.04)
	U.Text(create, "Header", "FOUND A TRIBE", S(1, 0.18), S(0, 0), T.Gold, T.Fonts.Title, Enum.TextXAlignment.Left, 24)
	U.TextBox(create, "NameBox", "Tribe name (3-20)", S(0.64, 0.2), S(0, 0.24))
	U.TextBox(create, "TagBox", "TAG", S(0.32, 0.2), S(0.68, 0.24))
	U.Button(create, "CreateButton", "CREATE · 299 R$", S(1, 0.24), S(0, 0.52), Color3.fromRGB(60, 190, 90))
	U.Text(create, "CreateStatus", "", S(1, 0.16), S(0, 0.82), T.SubText, T.Fonts.Body, Enum.TextXAlignment.Left, 16)

	local mine = U.Frame(m, "MyTribe", S(0.46, 0.5), S(0.02, 0.47), nil, T.Black, 0.6)
	U.Corner(mine, 0.04, 0)
	U.Padding(mine, 0.04)
	U.Text(mine, "MyTribeName", "No tribe", S(0.7, 0.12), S(0, 0), T.Text, T.Fonts.Title, Enum.TextXAlignment.Left, 24)
	U.Text(mine, "MyTribeGlory", "", S(0.3, 0.12), S(0.7, 0), T.Gold, T.Fonts.Bold, Enum.TextXAlignment.Right, 20)
	local members = Instance.new("ScrollingFrame")
	members.Name = "Members"
	members.Size = S(1, 0.66)
	members.Position = S(0, 0.14)
	members.BackgroundTransparency = 1
	members.BorderSizePixel = 0
	members.ScrollBarThickness = 5
	members.AutomaticCanvasSize = Enum.AutomaticSize.Y
	members.CanvasSize = UDim2.new()
	members.Parent = mine
	U.List(members, Enum.FillDirection.Vertical, 0.01, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Top)
	local mt = U.Text(members, "MemberTemplate", "Member", S(1, 0.12), S(0, 0), T.SubText, T.Fonts.Bold, Enum.TextXAlignment.Left, 18)
	mt.Visible = false
	U.Button(mine, "LeaveButton", "LEAVE TRIBE", S(1, 0.14), S(0, 0.84), T.Bad)

	local browse = U.Frame(m, "BrowseSection", S(0.48, 0.86), S(0.5, 0.11), nil, T.Black, 0.6)
	U.Corner(browse, 0.04, 0)
	U.Padding(browse, 0.03)
	U.Text(browse, "Header", "JOIN A TRIBE", S(0.6, 0.07), S(0, 0), T.Gold, T.Fonts.Title, Enum.TextXAlignment.Left, 24)
	U.TextBox(browse, "SearchBox", "Search by TAG", S(0.6, 0.07), S(0, 0.09))
	U.Button(browse, "SearchButton", "SEARCH", S(0.36, 0.07), S(0.64, 0.09), T.Alpha)
	local list = Instance.new("ScrollingFrame")
	list.Name = "TribeList"
	list.Size = S(1, 0.8)
	list.Position = S(0, 0.19)
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.ScrollBarThickness = 6
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.CanvasSize = UDim2.new()
	list.Parent = browse
	U.List(list, Enum.FillDirection.Vertical, 0.012, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Top)
	local row = U.Frame(list, "TribeTemplate", S(1, 0.1), S(0, 0), nil, T.PanelLight, 0.1)
	U.Corner(row, 0.2, 0)
	U.Text(row, "TagLabel", "[TAG]", S(0.16, 0.8), S(0.02, 0.1), T.Gold, T.Fonts.Title, Enum.TextXAlignment.Left, 18)
	U.Text(row, "NameLabel", "Tribe", S(0.36, 0.8), S(0.19, 0.1), T.Text, T.Fonts.Bold, Enum.TextXAlignment.Left, 18)
	U.Text(row, "MembersLabel", "0/20", S(0.12, 0.8), S(0.55, 0.1), T.SubText, T.Fonts.Bold, Enum.TextXAlignment.Center, 16)
	U.Text(row, "GloryLabel", "0 RP", S(0.14, 0.8), S(0.67, 0.1), T.Gold, T.Fonts.Bold, Enum.TextXAlignment.Center, 16)
	U.Button(row, "JoinButton", "JOIN", S(0.16, 0.8), S(0.82, 0.1), T.Alpha)
	row.Visible = false
	return gui
end

---------------------------------------------------------------------------------------------
local function slider(parent: Instance, name: string, label: string, order: number): Frame
	local row = U.Frame(parent, name, S(1, 0.15), S(0, 0), nil, T.PanelLight, 0.2)
	row.LayoutOrder = order
	U.Corner(row, 0.2, 0)
	U.Text(row, "Label", label, S(0.4, 0.8), S(0.03, 0.1), T.Text, T.Fonts.Bold, Enum.TextXAlignment.Left, 22)
	local track = U.Frame(row, "Track", S(0.38, 0.16), S(0.44, 0.42), nil, T.Black, 0.3)
	U.Corner(track, 0.5, 0)
	local fill = U.Frame(track, "Fill", S(0.5, 1), S(0, 0), nil, T.Gold, 0)
	U.Corner(fill, 0.5, 0)
	local knob = Instance.new("TextButton")
	knob.Name = "Knob"
	knob.Text = ""
	knob.Size = S(0.07, 2.6)
	knob.Position = S(0.5, 0.5)
	knob.AnchorPoint = V2(0.5, 0.5)
	knob.BackgroundColor3 = T.White
	knob.BorderSizePixel = 0
	knob.Parent = track
	U.Corner(knob, 1, 0)
	U.Aspect(knob, 1, Enum.DominantAxis.Height)
	U.Text(row, "Value", "0", S(0.14, 0.8), S(0.84, 0.1), T.Gold, T.Fonts.Title, Enum.TextXAlignment.Center, 22)
	return row
end

local function toggle(parent: Instance, name: string, label: string, order: number): Frame
	local row = U.Frame(parent, name, S(1, 0.15), S(0, 0), nil, T.PanelLight, 0.2)
	row.LayoutOrder = order
	U.Corner(row, 0.2, 0)
	U.Text(row, "Label", label, S(0.66, 0.8), S(0.03, 0.1), T.Text, T.Fonts.Bold, Enum.TextXAlignment.Left, 22)
	U.Button(row, "Toggle", "OFF", S(0.22, 0.7), S(0.75, 0.15), T.PanelLighter)
	return row
end

function LobbyScreens.Settings(parent: Instance): ScreenGui
	local gui = U.Screen(parent, "Settings", 25, false)
	local m = modal(gui, "SETTINGS", S(0.5, 0.62), 4 / 3)
	local rows = U.Group(m, "Rows", S(0.94, 0.82), S(0.03, 0.13))
	U.List(rows, Enum.FillDirection.Vertical, 0.025, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Top)
	slider(rows, "CameraSensitivity", "CAMERA SENSITIVITY", 1)
	slider(rows, "FieldOfView", "FIELD OF VIEW (70~120)", 2)
	toggle(rows, "ViewBobbing", "VIEW BOBBING", 3)
	toggle(rows, "PreventFullBotMatches", "PREVENT FULL BOT MATCHES", 4)
	toggle(rows, "FirstPersonDefault", "START IN FIRST PERSON", 5)
	return gui
end

function LobbyScreens.BuildAll(parent: Instance)
	LobbyScreens.LobbyHUD(parent)
	LobbyScreens.LoadoutBuilder(parent)
	LobbyScreens.CustomMatches(parent)
	LobbyScreens.TribeHall(parent)
	LobbyScreens.Settings(parent)
end

return LobbyScreens
