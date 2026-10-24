--!strict
-- Step 4b: match ScreenGuis - VSScreen, CombatHUD (score, timer, vitals, 6-slot hotbar,
-- crosshair/hitmarker, kill feed, banners, countdown, preset switcher, floating damage numbers)
-- and DeathAndSpectate.

local UIKit = require(script.Parent.Parent.Kit.UIKit)

local U = UIKit
local T = UIKit.Theme
local S = UDim2.fromScale
local V2 = Vector2.new
local RGB = Color3.fromRGB

local MatchScreens = {}

function MatchScreens.VSScreen(parent: Instance): ScreenGui
	local gui = U.Screen(parent, "VSScreen", 40, false)
	local bg = U.Frame(gui, "Background", S(1, 1), S(0, 0), nil, T.Black, 0)
	U.Gradient(bg, ColorSequence.new({
		ColorSequenceKeypoint.new(0, RGB(20, 50, 120)),
		ColorSequenceKeypoint.new(0.48, RGB(10, 10, 16)),
		ColorSequenceKeypoint.new(0.52, RGB(10, 10, 16)),
		ColorSequenceKeypoint.new(1, RGB(130, 24, 20)),
	}), 0)
	for i, team in { "Alpha", "Bravo" } do
		local col = U.Group(bg, team .. "Column", S(0.36, 0.62), S(if i == 1 then 0.05 else 0.59, 0.2))
		U.List(col, Enum.FillDirection.Vertical, 0.04, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Center)
		U.Text(col, "TeamLabel", string.upper(team), S(1, 0.14), S(0, 0), if team == "Alpha" then T.Alpha else T.Bravo, T.Fonts.Title, Enum.TextXAlignment.Center, 60).LayoutOrder = 0
		for c = 1, 3 do
			local card = U.Panel(col, "Card" .. c, S(1, 0.22), S(0, 0), nil, 4.2)
			card.LayoutOrder = c
			U.Stroke(card, if team == "Alpha" then T.Alpha else T.Bravo, 2.5, 0)
			U.Text(card, "Name", "Waiting...", S(0.64, 0.5), S(0.05, 0.1), T.Text, T.Fonts.Title, Enum.TextXAlignment.Left, 34)
			U.Text(card, "Level", "", S(0.28, 0.5), S(0.68, 0.1), T.Gold, T.Fonts.Title, Enum.TextXAlignment.Right, 28)
			U.Text(card, "Tag", "", S(0.9, 0.32), S(0.05, 0.6), T.SubText, T.Fonts.Bold, Enum.TextXAlignment.Left, 20)
		end
	end
	local vs = U.Text(bg, "VSLabel", "VS", S(0.16, 0.2), S(0.5, 0.45), T.Gold, T.Fonts.Title, Enum.TextXAlignment.Center, 140)
	vs.AnchorPoint = V2(0.5, 0.5)
	U.Stroke(vs, T.Black, 4, 0, Enum.ApplyStrokeMode.Contextual)
	local map = U.Text(bg, "MapLabel", "MAP", S(0.6, 0.07), S(0.5, 0.06), T.Text, T.Fonts.Title, Enum.TextXAlignment.Center, 48)
	map.AnchorPoint = V2(0.5, 0)
	local mode = U.Text(bg, "ModeLabel", "3v3 · BEST OF 5", S(0.4, 0.045), S(0.5, 0.135), T.SubText, T.Fonts.Bold, Enum.TextXAlignment.Center, 28)
	mode.AnchorPoint = V2(0.5, 0)
	return gui
end

---------------------------------------------------------------------------------------------
local function pips(parent: Instance, name: string, color: Color3, rightAligned: boolean): Frame
	local row = U.Group(parent, name, S(0.28, 0.5), S(if rightAligned then 0.7 else 0.02, 0.25))
	U.List(row, Enum.FillDirection.Horizontal, 0.08, if rightAligned then Enum.HorizontalAlignment.Left else Enum.HorizontalAlignment.Right, Enum.VerticalAlignment.Center)
	for i = 1, 3 do
		local pip = U.Frame(row, "Pip" .. i, S(0.2, 0.7), S(0, 0), nil, color, 0.75)
		pip.LayoutOrder = if rightAligned then i else 4 - i
		U.Corner(pip, 1, 0)
		U.Aspect(pip, 1, Enum.DominantAxis.Height)
		U.Stroke(pip, color, 2, 0)
	end
	return row
end

function MatchScreens.CombatHUD(parent: Instance): ScreenGui
	local gui = U.Screen(parent, "CombatHUD", 10, false)

	-- top score bar
	local top = U.Panel(gui, "TopBar", S(0.34, 0.075), S(0.5, 0.015), V2(0.5, 0), 6.5)
	local alphaScore = U.Frame(top, "AlphaScore", S(0.36, 1), S(0, 0), nil, T.Alpha, 0.55)
	U.Corner(alphaScore, 0.2, 0)
	pips(alphaScore, "AlphaPips", T.Alpha, false)
	U.Text(alphaScore, "Score", "0", S(0.3, 0.8), S(0.66, 0.1), T.White, T.Fonts.Title, Enum.TextXAlignment.Center, 40)
	local bravoScore = U.Frame(top, "BravoScore", S(0.36, 1), S(0.64, 0), nil, T.Bravo, 0.55)
	U.Corner(bravoScore, 0.2, 0)
	pips(bravoScore, "BravoPips", T.Bravo, true)
	U.Text(bravoScore, "Score", "0", S(0.3, 0.8), S(0.04, 0.1), T.White, T.Fonts.Title, Enum.TextXAlignment.Center, 40)
	U.Text(top, "RoundTimer", "1:00", S(0.26, 0.62), S(0.37, 0.02), T.White, T.Fonts.Title, Enum.TextXAlignment.Center, 40)
	U.Text(top, "RoundLabel", "ROUND 1", S(0.26, 0.32), S(0.37, 0.64), T.SubText, T.Fonts.Bold, Enum.TextXAlignment.Center, 18)

	-- alive roster icons under the score bar
	for i, team in { "Alpha", "Bravo" } do
		local row = U.Group(gui, team .. "Alive", S(0.12, 0.035), S(if i == 1 then 0.33 else 0.55, 0.095))
		U.List(row, Enum.FillDirection.Horizontal, 0.04, if i == 1 then Enum.HorizontalAlignment.Right else Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center)
		local icon = U.Frame(row, "IconTemplate", S(0.28, 1), S(0, 0), nil, if team == "Alpha" then T.Alpha else T.Bravo, 0.1)
		U.Corner(icon, 0.3, 0)
		U.Aspect(icon, 1, Enum.DominantAxis.Height)
		U.Text(icon, "Initial", "?", S(1, 1), S(0, 0), T.White, T.Fonts.Title, Enum.TextXAlignment.Center, 20)
		icon.Visible = false
	end

	local ring = U.Text(gui, "RingWarning", "", S(0.4, 0.035), S(0.5, 0.14), RGB(255, 140, 40), T.Fonts.Title, Enum.TextXAlignment.Center, 26)
	ring.AnchorPoint = V2(0.5, 0)

	-- vitals (bottom-left)
	local vitals = U.Panel(gui, "Vitals", S(0.24, 0.11), S(0.012, 0.975), V2(0, 1), 4.4)
	local _, hFill = U.Bar(vitals, "HealthBar", S(0.9, 0.3), S(0.05, 0.12), T.Health)
	U.Text(hFill.Parent :: Instance, "HealthText", "100", S(1, 1), S(0, 0), T.White, T.Fonts.Title, Enum.TextXAlignment.Center, 24)
	local _, aFill = U.Bar(vitals, "ArmorBar", S(0.9, 0.2), S(0.05, 0.5), T.Armor)
	aFill.Size = S(0, 1)
	U.Text(aFill.Parent :: Instance, "ArmorText", "0", S(1, 1), S(0, 0), T.White, T.Fonts.Title, Enum.TextXAlignment.Center, 18)
	local status = U.Group(vitals, "StatusRow", S(0.9, 0.2), S(0.05, 0.76))
	U.List(status, Enum.FillDirection.Horizontal, 0.02, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center)
	local st = U.Frame(status, "StatusTemplate", S(0.3, 1), S(0, 0), nil, T.Bad, 0.2)
	U.Corner(st, 0.3, 0)
	U.Text(st, "Label", "STATUS", S(1, 1), S(0, 0), T.White, T.Fonts.Title, Enum.TextXAlignment.Center, 14)
	st.Visible = false

	-- hotbar (bottom-centre, 6 slots)
	local hotbar = U.Group(gui, "Hotbar", S(0.44, 0.1), S(0.5, 0.975), V2(0.5, 1))
	U.List(hotbar, Enum.FillDirection.Horizontal, 0.012, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Bottom)
	for i = 1, 6 do
		local slot = U.Frame(hotbar, "Slot" .. i, S(0.155, 1), S(0, 0), nil, T.Panel, 0.2)
		slot.LayoutOrder = i
		U.Corner(slot, 0.12, 0)
		U.Aspect(slot, 1.05)
		local stroke = U.Stroke(slot, T.Stroke, 2, 0.3)
		stroke.Name = "SelectStroke"
		local cd = U.Frame(slot, "Cooldown", S(1, 0), S(0, 1), V2(0, 1), T.Black, 0.4)
		U.Corner(cd, 0.12, 0)
		U.Text(slot, "Key", tostring(i), S(0.3, 0.26), S(0.05, 0.03), T.SubText, T.Fonts.Title, Enum.TextXAlignment.Left, 16)
		U.Text(slot, "Glyph", "", S(0.6, 0.44), S(0.2, 0.18), T.White, T.Fonts.Title, Enum.TextXAlignment.Center, 36)
		U.Text(slot, "ItemName", "", S(0.94, 0.2), S(0.03, 0.62), T.Text, T.Fonts.Bold, Enum.TextXAlignment.Center, 14)
		U.Text(slot, "Count", "", S(0.4, 0.24), S(0.57, 0.03), T.Gold, T.Fonts.Title, Enum.TextXAlignment.Right, 18)
		U.Text(slot, "Level", "", S(0.4, 0.16), S(0.05, 0.82), T.SubText, T.Fonts.Bold, Enum.TextXAlignment.Left, 12)
	end

	-- control hints (bottom-right)
	local hints = U.Panel(gui, "ControlHints", S(0.22, 0.13), S(0.988, 0.975), V2(1, 1), 3)
	U.Text(hints, "AmmoLabel", "", S(0.9, 0.3), S(0.05, 0.05), T.Gold, T.Fonts.Title, Enum.TextXAlignment.Right, 28)
	U.Text(hints, "HintText", "", S(0.9, 0.36), S(0.05, 0.36), T.Text, T.Fonts.Bold, Enum.TextXAlignment.Right, 16)
	U.Text(hints, "ViewModeLabel", "[first person V]  [shoulder X]  [slide C]", S(0.9, 0.22), S(0.05, 0.74), T.SubText, T.Fonts.Bold, Enum.TextXAlignment.Right, 14)

	-- crosshair (centre)
	local cross = U.Group(gui, "Crosshair", S(0.06, 0.06), S(0.5, 0.5), V2(0.5, 0.5))
	U.Aspect(cross, 1)
	local dot = U.Frame(cross, "Dot", S(0.06, 0.06), S(0.5, 0.5), V2(0.5, 0.5), T.White, 0)
	U.Corner(dot, 1, 0)
	local lines: { { Name: string, Size: UDim2, Pos: UDim2 } } = {
		{ Name = "Top", Size = S(0.04, 0.22), Pos = S(0.5, 0.18) },
		{ Name = "Bottom", Size = S(0.04, 0.22), Pos = S(0.5, 0.82) },
		{ Name = "Left", Size = S(0.22, 0.04), Pos = S(0.18, 0.5) },
		{ Name = "Right", Size = S(0.22, 0.04), Pos = S(0.82, 0.5) },
	}
	for _, l in lines do
		local f = U.Frame(cross, l.Name, l.Size, l.Pos, V2(0.5, 0.5), T.White, 0)
		U.Stroke(f, T.Black, 1, 0.5)
	end
	local ringF = U.Frame(cross, "DrawRing", S(1, 1), S(0.5, 0.5), V2(0.5, 0.5), T.White, 1)
	U.Corner(ringF, 1, 0)
	local rs = U.Stroke(ringF, T.White, 2, 0.4)
	rs.Name = "RingStroke"
	local hit = U.Group(cross, "Hitmarker", S(0.8, 0.8), S(0.5, 0.5), V2(0.5, 0.5))
	for i, rot in { 45, -45, 135, -135 } do
		local seg = U.Frame(hit, "Seg" .. i, S(0.06, 0.3), S(0.5, 0.5), V2(0.5, 1.6), T.White, 0)
		seg.Rotation = rot
	end
	hit.Visible = false

	-- kill feed (top-right)
	local feed = U.Group(gui, "KillFeed", S(0.24, 0.24), S(0.988, 0.02), V2(1, 0))
	U.List(feed, Enum.FillDirection.Vertical, 0.03, Enum.HorizontalAlignment.Right, Enum.VerticalAlignment.Top)
	local fr = U.Frame(feed, "FeedTemplate", S(1, 0.18), S(0, 0), nil, T.Panel, 0.25)
	U.Corner(fr, 0.25, 0)
	U.Text(fr, "Text", "A ⚔ B", S(0.94, 0.8), S(0.03, 0.1), T.Text, T.Fonts.Bold, Enum.TextXAlignment.Right, 18)
	fr.Visible = false

	-- round banner and countdown
	local banner = U.Group(gui, "Banner", S(0.6, 0.2), S(0.5, 0.26), V2(0.5, 0.5))
	U.Text(banner, "BannerText", "", S(1, 0.65), S(0, 0), T.Gold, T.Fonts.Title, Enum.TextXAlignment.Center, 110)
	U.Text(banner, "BannerSub", "", S(1, 0.3), S(0, 0.68), T.White, T.Fonts.Title, Enum.TextXAlignment.Center, 40)
	banner.Visible = false
	local count = U.Text(gui, "CountdownText", "", S(0.3, 0.2), S(0.5, 0.36), T.White, T.Fonts.Title, Enum.TextXAlignment.Center, 140)
	count.AnchorPoint = V2(0.5, 0.5)
	U.Stroke(count, T.Black, 4, 0, Enum.ApplyStrokeMode.Contextual)

	-- pre-round preset switcher ([B])
	local presets = U.Panel(gui, "PresetSwitcher", S(0.18, 0.36), S(0.012, 0.42), V2(0, 0.5), 0.62)
	presets.Visible = false
	U.Text(presets, "Title", "[B] SWITCH PRESET", S(0.9, 0.1), S(0.05, 0.03), T.Gold, T.Fonts.Title, Enum.TextXAlignment.Center, 22)
	local plist = U.Group(presets, "List", S(0.9, 0.82), S(0.05, 0.15))
	U.List(plist, Enum.FillDirection.Vertical, 0.025, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Top)
	for i = 1, 5 do
		local b = U.Button(plist, "Preset" .. i, i .. ". Preset", S(1, 0.17), S(0, 0), T.PanelLighter)
		b.LayoutOrder = i
	end

	-- kill banner, cast bar, floating damage numbers
	local kb = U.Panel(gui, "KillBanner", S(0.3, 0.07), S(0.5, 0.8), V2(0.5, 1), 6)
	kb.BackgroundColor3 = RGB(140, 20, 20)
	U.Text(kb, "Skull", "☠", S(0.14, 0.9), S(0.02, 0.05), T.White, T.Fonts.Title, Enum.TextXAlignment.Center, 40)
	U.Text(kb, "KillText", "ELIMINATED", S(0.82, 0.9), S(0.16, 0.05), T.White, T.Fonts.Title, Enum.TextXAlignment.Left, 34)
	kb.Visible = false
	local cast = U.Group(gui, "CastBar", S(0.2, 0.05), S(0.5, 0.68), V2(0.5, 0))
	local _, cFill = U.Bar(cast, "Bar", S(1, 0.45), S(0, 0.55), T.Good)
	cFill.Size = S(0, 1)
	U.Text(cast, "Label", "", S(1, 0.5), S(0, 0), T.White, T.Fonts.Bold, Enum.TextXAlignment.Center, 18)
	cast.Visible = false
	local dmg = U.Group(gui, "DamageNumbers", S(1, 1), S(0, 0))
	local dt = U.Text(dmg, "DamageTemplate", "0", S(0.08, 0.05), S(0, 0), T.White, T.Fonts.Title, Enum.TextXAlignment.Center, 40)
	dt.AnchorPoint = V2(0.5, 0.5)
	U.Stroke(dt, T.Black, 2, 0, Enum.ApplyStrokeMode.Contextual)
	dt.Visible = false
	local scope = U.Frame(gui, "ScopeVignette", S(1, 1), S(0, 0), nil, T.Black, 1)
	U.Gradient(scope, ColorSequence.new(T.Black), 0, NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.2),
		NumberSequenceKeypoint.new(0.25, 1),
		NumberSequenceKeypoint.new(0.75, 1),
		NumberSequenceKeypoint.new(1, 0.2),
	}))
	scope.ZIndex = 0
	return gui
end

---------------------------------------------------------------------------------------------
function MatchScreens.DeathAndSpectate(parent: Instance): ScreenGui
	local gui = U.Screen(parent, "DeathAndSpectate", 15, false)
	local card = U.Panel(gui, "EliminatedCard", S(0.3, 0.16), S(0.5, 0.62), V2(0.5, 0), 3.4)
	U.Stroke(card, T.Bad, 2.5, 0)
	U.Text(card, "Header", "ELIMINATED BY", S(0.9, 0.22), S(0.05, 0.06), T.Bad, T.Fonts.Title, Enum.TextXAlignment.Center, 24)
	U.Text(card, "KillerName", "", S(0.9, 0.34), S(0.05, 0.3), T.White, T.Fonts.Title, Enum.TextXAlignment.Center, 40)
	U.Text(card, "WeaponLabel", "", S(0.44, 0.22), S(0.05, 0.7), T.SubText, T.Fonts.Bold, Enum.TextXAlignment.Left, 20)
	U.Text(card, "KillerHP", "", S(0.44, 0.22), S(0.51, 0.7), T.Health, T.Fonts.Bold, Enum.TextXAlignment.Right, 20)
	local bar = U.Panel(gui, "SpectateBar", S(0.32, 0.07), S(0.5, 0.86), V2(0.5, 0), 6)
	U.Text(bar, "Label", "SPECTATING", S(0.4, 0.4), S(0.3, 0.05), T.SubText, T.Fonts.Bold, Enum.TextXAlignment.Center, 18)
	U.Text(bar, "TargetName", "", S(0.56, 0.5), S(0.22, 0.45), T.White, T.Fonts.Title, Enum.TextXAlignment.Center, 28)
	U.Button(bar, "PrevButton", "◀", S(0.14, 0.8), S(0.02, 0.1), T.PanelLighter)
	U.Button(bar, "NextButton", "▶", S(0.14, 0.8), S(0.84, 0.1), T.PanelLighter)
	bar.Visible = false
	return gui
end

function MatchScreens.BuildAll(parent: Instance)
	MatchScreens.VSScreen(parent)
	MatchScreens.CombatHUD(parent)
	MatchScreens.DeathAndSpectate(parent)
end

return MatchScreens
