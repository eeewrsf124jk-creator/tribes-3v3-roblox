--!strict
-- Step 4c: end-of-match ScreenGuis - POTGViewfinder (camcorder overlay + splash),
-- VictoryDropUI (procedural chest in a ViewportFrame, 4 flip cards) and
-- ScoreboardSummaryUI (6 player rows, MVP card, XP breakdown, play again / lobby).

local K = require(script.Parent.Parent.Kit.GeometryKit)
local UIKit = require(script.Parent.Parent.Kit.UIKit)

local U = UIKit
local T = UIKit.Theme
local S = UDim2.fromScale
local V2 = Vector2.new
local RGB = Color3.fromRGB

local EndScreens = {}

---------------------------------------------------------------------------------------------
-- POTG viewfinder
---------------------------------------------------------------------------------------------
local function bracket(parent: Instance, name: string, pos: UDim2, anchor: Vector2, flipX: boolean, flipY: boolean)
	local g = U.Group(parent, name, S(0.08, 0.12), pos, anchor)
	local thick = 0.06
	local h = U.Frame(g, "H", S(1, thick * 1.6), S(0, if flipY then 1 - thick * 1.6 else 0), nil, T.White, 0)
	local v = U.Frame(g, "V", S(thick, 1), S(if flipX then 1 - thick else 0, 0), nil, T.White, 0)
	U.Aspect(g, 1)
	h.Name = "Horizontal"
	v.Name = "Vertical"
end

function EndScreens.POTGViewfinder(parent: Instance): ScreenGui
	local gui = U.Screen(parent, "POTGViewfinder", 60, false)
	gui.ScreenInsets = Enum.ScreenInsets.None

	-- letterbox bars
	U.Frame(gui, "LetterTop", S(1, 0.08), S(0, 0), nil, T.Black, 0)
	U.Frame(gui, "LetterBottom", S(1, 0.08), S(0, 0.92), nil, T.Black, 0)

	local overlay = U.Group(gui, "Overlay", S(0.9, 0.76), S(0.5, 0.5), V2(0.5, 0.5))
	bracket(overlay, "BracketTL", S(0, 0), V2(0, 0), false, false)
	bracket(overlay, "BracketTR", S(1, 0), V2(1, 0), true, false)
	bracket(overlay, "BracketBL", S(0, 1), V2(0, 1), false, true)
	bracket(overlay, "BracketBR", S(1, 1), V2(1, 1), true, true)

	local rec = U.Group(overlay, "Rec", S(0.16, 0.07), S(0.09, 0.03))
	local dot = U.Frame(rec, "RecDot", S(0.22, 0.8), S(0, 0.1), nil, RGB(235, 30, 30), 0)
	U.Corner(dot, 1, 0)
	U.Aspect(dot, 1, Enum.DominantAxis.Height)
	U.Text(rec, "RecLabel", "REC", S(0.6, 1), S(0.3, 0), T.White, T.Fonts.Title, Enum.TextXAlignment.Left, 36)

	local tc = U.Text(overlay, "Timecode", "00:00:00", S(0.22, 0.07), S(0.91, 0.03), T.White, T.Fonts.Mono, Enum.TextXAlignment.Right, 34)
	tc.AnchorPoint = V2(1, 0)

	local title = U.Text(overlay, "TitleTag", "PLAY OF THE GAME", S(0.4, 0.06), S(0.5, 0.03), T.Gold, T.Fonts.Title, Enum.TextXAlignment.Center, 34)
	title.AnchorPoint = V2(0.5, 0)

	local caption = U.Group(overlay, "Caption", S(0.5, 0.12), S(0.09, 0.85))
	U.Text(caption, "PlayerName", "", S(1, 0.6), S(0, 0), T.White, T.Fonts.Title, Enum.TextXAlignment.Left, 44)
	U.Text(caption, "PlayTags", "", S(1, 0.4), S(0, 0.6), T.Gold, T.Fonts.Bold, Enum.TextXAlignment.Left, 26)

	local _, progressFill = U.Bar(overlay, "ReplayProgress", S(0.3, 0.012), S(0.61, 0.93), T.White, RGB(40, 40, 40))
	progressFill.Size = S(0, 1)

	U.Button(gui, "SkipButton", "SKIP >>", S(0.12, 0.06), S(0.97, 0.93), T.PanelLighter, T.White, V2(1, 0.5))

	-- full-screen black splash shown before the replay begins
	local splash = U.Frame(gui, "Splash", S(1, 1), S(0, 0), nil, T.Black, 0)
	splash.ZIndex = 10
	local stripe = U.Frame(splash, "Stripe", S(1, 0.004), S(0, 0.5), V2(0, 0.5), T.Gold, 0)
	stripe.ZIndex = 11
	local st = U.Text(splash, "SplashTitle", "PLAY OF THE GAME", S(0.8, 0.12), S(0.5, 0.38), T.Gold, T.Fonts.Title, Enum.TextXAlignment.Center, 96)
	st.AnchorPoint = V2(0.5, 0.5)
	st.ZIndex = 11
	local sn = U.Text(splash, "SplashName", "", S(0.7, 0.08), S(0.5, 0.58), T.White, T.Fonts.Title, Enum.TextXAlignment.Center, 64)
	sn.AnchorPoint = V2(0.5, 0.5)
	sn.ZIndex = 11
	local stg = U.Text(splash, "SplashTags", "", S(0.7, 0.05), S(0.5, 0.66), T.SubText, T.Fonts.Bold, Enum.TextXAlignment.Center, 34)
	stg.AnchorPoint = V2(0.5, 0.5)
	stg.ZIndex = 11
	splash.Visible = false
	return gui
end

---------------------------------------------------------------------------------------------
-- Victory drop: procedural chest model inside a ViewportFrame
---------------------------------------------------------------------------------------------
-- Builds a chest whose lid is a separate Model "Lid" with PrimaryPart "Hinge" so the client
-- can rotate it open about the back edge with Model:PivotTo.
function EndScreens.BuildChest(parent: Instance): Model
	local wood = RGB(120, 72, 36)
	local woodDark = RGB(84, 48, 22)
	local gold = RGB(240, 190, 60)
	local chest = K.Model(parent, "Chest")
	local W, D, H = 4, 2.6, 2
	local base = K.Part(chest, "Base", Vector3.new(W, H, D), CFrame.new(0, H / 2, 0), wood, Enum.Material.Wood)
	chest.PrimaryPart = base
	-- base planks and gold bands
	for i = -1, 1, 2 do
		K.Part(chest, "Band", Vector3.new(0.25, H + 0.05, D + 0.08), CFrame.new(i * W * 0.32, H / 2, 0), gold, Enum.Material.Metal)
		K.Part(chest, "CornerPost", Vector3.new(0.18, H + 0.04, 0.18), CFrame.new(i * (W / 2 - 0.05), H / 2, D / 2 - 0.05), woodDark, Enum.Material.Wood)
		K.Part(chest, "CornerPost", Vector3.new(0.18, H + 0.04, 0.18), CFrame.new(i * (W / 2 - 0.05), H / 2, -D / 2 + 0.05), woodDark, Enum.Material.Wood)
	end
	K.Part(chest, "Plinth", Vector3.new(W + 0.2, 0.2, D + 0.2), CFrame.new(0, 0.1, 0), woodDark, Enum.Material.Wood)
	-- glowing interior (visible when the lid opens)
	local glow = K.Part(chest, "Glow", Vector3.new(W - 0.3, 0.1, D - 0.3), CFrame.new(0, H - 0.02, 0), RGB(255, 220, 120), Enum.Material.Neon)
	glow.Transparency = 0.2

	-- lid: hinge on the back (+Z) top edge; plank-arc vault on a flat slab
	local lid = K.Model(chest, "Lid")
	local hinge = K.Part(lid, "Hinge", Vector3.new(W, 0.1, 0.1), CFrame.new(0, H, D / 2), woodDark, Enum.Material.Wood)
	hinge.Transparency = 1
	lid.PrimaryPart = hinge
	K.Part(lid, "Slab", Vector3.new(W + 0.02, 0.26, D + 0.02), CFrame.new(0, H + 0.125, 0), wood, Enum.Material.Wood)
	-- rounded vault: plank arc in the YZ plane (Arc builds in local XY; yaw 90° maps X to Z),
	-- spanning the full chest width so the lid stays hollow and reads correctly when opened
	local vaultCF = CFrame.new(0, H + 0.25, 0) * CFrame.Angles(0, math.rad(90), 0)
	K.Arc(lid, "Vault", vaultCF, D / 2 - 0.1, 0, 180, 9, 0.2, W, wood, Enum.Material.Wood)
	for i = -1, 1, 2 do
		K.Arc(lid, "LidBand", CFrame.new(i * W * 0.32, 0, 0) * vaultCF, D / 2 - 0.02, 0, 180, 9, 0.08, 0.27, gold, Enum.Material.Metal)
		-- semicircular end caps stacked from horizontal slices
		local r = D / 2 - 0.1
		local slices = 6
		for k = 0, slices - 1 do
			local y = (k + 0.5) * r / slices
			local width = 2 * math.sqrt(r * r - y * y)
			K.Part(lid, "EndCap", Vector3.new(0.12, r / slices + 0.01, width), CFrame.new(i * (W / 2 - 0.06), H + 0.25 + y, 0), woodDark, Enum.Material.Wood)
		end
	end
	K.Part(lid, "Lock", Vector3.new(0.5, 0.6, 0.15), CFrame.new(0, H - 0.05, -D / 2 - 0.06), gold, Enum.Material.Metal)
	K.Part(lid, "Keyhole", Vector3.new(0.12, 0.22, 0.05), CFrame.new(0, H - 0.1, -D / 2 - 0.15), RGB(20, 20, 20), Enum.Material.SmoothPlastic)
	return chest
end

local function flipCard(parent: Instance, index: number): Frame
	local card = U.Frame(parent, "Card" .. index, S(0.22, 1), S(0, 0), nil, T.Panel, 0)
	card.LayoutOrder = index
	U.Aspect(card, 0.68)
	U.Corner(card, 0.08, 0)
	local stroke = U.Stroke(card, T.Gold, 3, 0)
	stroke.Name = "RarityStroke"
	-- back face (shown until flipped)
	local back = U.Frame(card, "Back", S(1, 1), S(0, 0), nil, RGB(60, 40, 110), 0)
	U.Corner(back, 0.08, 0)
	U.Gradient(back, U.Grad2(RGB(110, 70, 190), RGB(40, 24, 80)), 45)
	local q = U.Text(back, "Mark", "?", S(0.6, 0.4), S(0.5, 0.5), T.Gold, T.Fonts.Title, Enum.TextXAlignment.Center, 90)
	q.AnchorPoint = V2(0.5, 0.5)
	-- front face
	local front = U.Frame(card, "Front", S(1, 1), S(0, 0), nil, T.PanelLight, 0)
	U.Corner(front, 0.08, 0)
	U.Gradient(front, U.Grad2(T.PanelLighter, T.Panel), 90)
	U.Text(front, "Glyph", "", S(0.6, 0.3), S(0.2, 0.08), T.White, T.Fonts.Title, Enum.TextXAlignment.Center, 72)
	U.Text(front, "ItemName", "", S(0.9, 0.14), S(0.05, 0.42), T.White, T.Fonts.Title, Enum.TextXAlignment.Center, 28)
	U.Text(front, "Shards", "+0", S(0.9, 0.16), S(0.05, 0.58), T.Gold, T.Fonts.Title, Enum.TextXAlignment.Center, 40)
	local _, shardFill = U.Bar(front, "ShardBar", S(0.84, 0.05), S(0.08, 0.78), T.Gold)
	shardFill.Size = S(0, 1)
	U.Text(front, "ShardProgress", "0 / 10", S(0.84, 0.07), S(0.08, 0.84), T.SubText, T.Fonts.Bold, Enum.TextXAlignment.Center, 20)
	local ready = U.Frame(front, "UpgradeReady", S(0.9, 0.1), S(0.5, 0.0), V2(0.5, 0.5), T.Good, 0)
	U.Corner(ready, 0.4, 0)
	U.Text(ready, "Label", "UPGRADE READY", S(0.92, 0.8), S(0.04, 0.1), T.Black, T.Fonts.Title, Enum.TextXAlignment.Center, 22)
	ready.Visible = false
	front.Visible = false
	return card
end

function EndScreens.VictoryDropUI(parent: Instance): ScreenGui
	local gui = U.Screen(parent, "VictoryDropUI", 55, false)
	local dim = U.Frame(gui, "Dim", S(1, 1), S(0, 0), nil, T.Black, 0.25)
	U.Gradient(dim, U.Grad2(RGB(40, 30, 70), RGB(5, 5, 10)), 90)

	local header = U.Text(gui, "Header", "VICTORY", S(0.5, 0.1), S(0.5, 0.04), T.Gold, T.Fonts.Title, Enum.TextXAlignment.Center, 90)
	header.AnchorPoint = V2(0.5, 0)
	U.Stroke(header, T.Black, 3, 0, Enum.ApplyStrokeMode.Contextual)
	local sub = U.Text(gui, "SubHeader", "Tap the chest to open", S(0.5, 0.045), S(0.5, 0.14), T.SubText, T.Fonts.Bold, Enum.TextXAlignment.Center, 30)
	sub.AnchorPoint = V2(0.5, 0)

	local vp = Instance.new("ViewportFrame")
	vp.Name = "ChestViewport"
	vp.Size = S(0.36, 0.4)
	vp.Position = S(0.5, 0.2)
	vp.AnchorPoint = V2(0.5, 0)
	vp.BackgroundTransparency = 1
	vp.Ambient = RGB(170, 160, 150)
	vp.LightColor = RGB(255, 240, 210)
	vp.LightDirection = Vector3.new(-1, -2, -1)
	vp.Parent = gui
	U.Aspect(vp, 1.4)
	local world = Instance.new("WorldModel")
	world.Parent = vp
	EndScreens.BuildChest(world)
	local cam = Instance.new("Camera")
	cam.Name = "ViewportCamera"
	cam.FieldOfView = 40
	cam.CFrame = CFrame.lookAt(Vector3.new(4.2, 4.6, -7.5), Vector3.new(0, 1.4, 0))
	cam.Parent = vp
	vp.CurrentCamera = cam

	local openBtn = Instance.new("TextButton")
	openBtn.Name = "OpenChestButton"
	openBtn.Text = ""
	openBtn.BackgroundTransparency = 1
	openBtn.Size = S(1, 1)
	openBtn.Parent = vp

	local cards = U.Group(gui, "Cards", S(0.8, 0.36), S(0.5, 0.6), V2(0.5, 0))
	U.List(cards, Enum.FillDirection.Horizontal, 0.025, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Center)
	for i = 1, 4 do
		flipCard(cards, i)
	end

	local total = U.Text(gui, "TotalShards", "TOTAL +0 SHARDS", S(0.4, 0.05), S(0.5, 0.965), T.Gold, T.Fonts.Title, Enum.TextXAlignment.Center, 36)
	total.AnchorPoint = V2(0.5, 1)
	local cont = U.Button(gui, "ContinueButton", "CONTINUE", S(0.16, 0.065), S(0.97, 0.965), T.Good, T.Black, V2(1, 1))
	cont.Visible = false
	return gui
end

---------------------------------------------------------------------------------------------
-- Scoreboard summary
---------------------------------------------------------------------------------------------
type Column = { Key: string, Width: number }
local COLUMNS: { Column } = {
	{ Key = "Name", Width = 0.34 },
	{ Key = "K", Width = 0.1 },
	{ Key = "D", Width = 0.1 },
	{ Key = "A", Width = 0.1 },
	{ Key = "DMG", Width = 0.16 },
	{ Key = "Glory", Width = 0.16 },
}

local function scoreRow(parent: Instance, name: string, color: Color3, header: boolean): Frame
	local row = U.Frame(parent, name, S(1, 0.13), S(0, 0), nil, if header then T.Panel else color, if header then 1 else 0.7)
	U.Corner(row, 0.2, 0)
	local x = 0.02
	for _, col in COLUMNS do
		local label = col.Key
		local w = col.Width
		local text = if header then string.upper(label) else (if label == "Name" then "" else "0")
		U.Text(row, label, text, S(w, 0.8), S(x, 0.1), if header then T.SubText else T.White,
			if header then T.Fonts.Bold else T.Fonts.Title, if label == "Name" then Enum.TextXAlignment.Left else Enum.TextXAlignment.Center, 26)
		x += w
	end
	return row
end

function EndScreens.ScoreboardSummaryUI(parent: Instance): ScreenGui
	local gui = U.Screen(parent, "ScoreboardSummaryUI", 50, false)
	U.Frame(gui, "Dim", S(1, 1), S(0, 0), nil, T.Black, 0.35)
	local modal = U.Panel(gui, "Modal", S(0.86, 0.86), S(0.5, 0.5), V2(0.5, 0.5), 1.85)

	local result = U.Text(modal, "ResultLabel", "VICTORY", S(0.5, 0.09), S(0.5, 0.025), T.Gold, T.Fonts.Title, Enum.TextXAlignment.Center, 72)
	result.AnchorPoint = V2(0.5, 0)
	local score = U.Text(modal, "FinalScore", "3 - 0", S(0.3, 0.06), S(0.5, 0.115), T.White, T.Fonts.Title, Enum.TextXAlignment.Center, 44)
	score.AnchorPoint = V2(0.5, 0)

	-- left: team tables (3 rows each)
	local tables = U.Group(modal, "Tables", S(0.6, 0.74), S(0.03, 0.2))
	U.List(tables, Enum.FillDirection.Vertical, 0.015, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Top)
	local hdr = scoreRow(tables, "Header", T.Panel, true)
	hdr.LayoutOrder = 0
	local order = 1
	for _, team in { "Alpha", "Bravo" } do
		local label = U.Text(tables, team .. "Label", string.upper(team), S(1, 0.07), S(0, 0), if team == "Alpha" then T.Alpha else T.Bravo, T.Fonts.Title, Enum.TextXAlignment.Left, 26)
		label.LayoutOrder = order
		order += 1
		for i = 1, 3 do
			local r = scoreRow(tables, team .. "Row" .. i, if team == "Alpha" then RGB(30, 60, 120) else RGB(120, 30, 26), false)
			r.LayoutOrder = order
			order += 1
		end
	end

	-- right: MVP card
	local mvp = U.Panel(modal, "MVPCard", S(0.32, 0.42), S(0.65, 0.2), nil)
	U.Stroke(mvp, T.Gold, 3, 0)
	U.Text(mvp, "MVPTag", "★ MVP ★", S(0.9, 0.16), S(0.05, 0.04), T.Gold, T.Fonts.Title, Enum.TextXAlignment.Center, 40)
	U.Text(mvp, "MVPName", "", S(0.9, 0.18), S(0.05, 0.24), T.White, T.Fonts.Title, Enum.TextXAlignment.Center, 40)
	U.Text(mvp, "MVPStats", "", S(0.9, 0.14), S(0.05, 0.46), T.SubText, T.Fonts.Bold, Enum.TextXAlignment.Center, 26)
	U.Text(mvp, "MVPWeapon", "", S(0.9, 0.12), S(0.05, 0.64), T.SubText, T.Fonts.Body, Enum.TextXAlignment.Center, 22)

	-- right: XP breakdown
	local xp = U.Panel(modal, "XPBreakdown", S(0.32, 0.22), S(0.65, 0.64), nil)
	local lines = U.Group(xp, "Lines", S(0.9, 0.55), S(0.05, 0.05))
	U.List(lines, Enum.FillDirection.Vertical, 0.02, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Top)
	local lineTemplate = U.Text(lines, "LineTemplate", "", S(1, 0.3), S(0, 0), T.Text, T.Fonts.Bold, Enum.TextXAlignment.Left, 22)
	lineTemplate.Visible = false
	local _, xpFill = U.Bar(xp, "XPBar", S(0.9, 0.12), S(0.05, 0.66), T.Gold)
	xpFill.Size = S(0, 1)
	U.Text(xp, "XPLabel", "LV 1  0 / 250 XP", S(0.9, 0.15), S(0.05, 0.81), T.SubText, T.Fonts.Bold, Enum.TextXAlignment.Center, 20)

	local buttons = U.Group(modal, "Buttons", S(0.32, 0.08), S(0.65, 0.89))
	U.Button(buttons, "PlayAgainButton", "PLAY AGAIN (25s)", S(0.58, 1), S(0, 0), T.Good, T.Black)
	U.Button(buttons, "LobbyButton", "LOBBY", S(0.38, 1), S(0.62, 0), T.PanelLighter, T.White)
	return gui
end

function EndScreens.BuildAll(parent: Instance)
	EndScreens.POTGViewfinder(parent)
	EndScreens.VictoryDropUI(parent)
	EndScreens.ScoreboardSummaryUI(parent)
end

return EndScreens
