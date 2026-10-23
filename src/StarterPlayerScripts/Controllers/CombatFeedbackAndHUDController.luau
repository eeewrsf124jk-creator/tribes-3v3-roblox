--!strict
-- CombatFeedbackAndHUDController: everything on screen during a fight.
--   VS splash, pre-round countdown + [B] preset switcher, score pips / timer / alive icons,
--   Ring of Fire warning, round banners (ROUND WON / LOST + FLAWLESS / ACE / TEAM ACE),
--   vitals and status chips, the 6-slot hotbar with cooldown sweeps and per-item hint text,
--   crosshair spread + draw ring + hitmarker, floating damage numbers on a parabola
--   ("40", yellow "70 HEADSHOT!", blue "ARMOR BROKEN", white "STAGGERED"), kill feed,
--   the red "☠ ELIMINATED {Name}" banner, the ELIMINATED BY card and teammate spectating,
--   War Horn reveal highlights.

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local Net = require(Modules.Shared.Net)
local Types = require(Modules.Shared.Types)
local VFX = require(Modules.Shared.VFX)
local EquipmentDatabase = require(Modules.Config.EquipmentDatabase)
local GameConfig = require(Modules.Config.GameConfig)
local SoundCatalog = require(Modules.Config.SoundCatalog)
local State = require(script.Parent.ClientState)
local UIUtil = require(script.Parent.UIUtil)
local Weapon = require(script.Parent.WeaponAndProjectileController)
local Renderer = require(script.Parent.ProjectileRenderer)
local Camera = require(script.Parent.CameraAndViewmodelController)

local HUD = {}

local T = UIUtil.Theme
local player = Players.LocalPlayer

local hud: ScreenGui
local vs: ScreenGui
local death: ScreenGui
local lobby: ScreenGui

type DamageNumber = { Label: TextLabel, World: Vector3, Born: number, Drift: number, Rise: number }
local numbers: { DamageNumber } = {}

local hitmarkerUntil = 0
local hitmarkerColor = T.White
local killBannerToken = 0
local feedCounter = 0
local lastCountdown = -1
local lastPhase: string? = nil
local fightShownUntil = 0
local snareUntil = 0
local spectateIds: { string } = {}
local spectateIndex = 1
local spectating = false
local deathToken = 0
local switcherOpen = false

local function now(): number
	return Workspace:GetServerTimeNow()
end

local function myTeam(): Types.TeamName
	return State.MyTeam()
end

local function rosterEntry(id: string?): Types.RosterEntry?
	local round = State.Round
	if round == nil or id == nil then
		return nil
	end
	for _, r in round.Roster do
		if r.Id == id then
			return r
		end
	end
	return nil
end

local function teamOf(id: string?): string
	local r = rosterEntry(id)
	if r then
		return r.Team
	end
	local model = if id then Renderer.FindCombatantModel(id) else nil
	local team = if model then model:GetAttribute("Team") else nil
	return if type(team) == "string" then team else "Neutral"
end

local function hex(c: Color3): string
	return string.format("#%02X%02X%02X", math.floor(c.R * 255), math.floor(c.G * 255), math.floor(c.B * 255))
end

local function colored(text: string, color: Color3): string
	return string.format('<font color="%s">%s</font>', hex(color), text)
end

---------------------------------------------------------------------------------------------
-- Screen visibility
---------------------------------------------------------------------------------------------
local function setLobbyChrome(visible: boolean)
	for _, child in lobby:GetChildren() do
		if child:IsA("GuiObject") and child.Name ~= "Toasts" then
			if child.Name == "PartyInvite" then
				if not visible then
					child.Visible = false
				end
			elseif child:GetAttribute("HiddenByHUD") == nil then
				if not visible then
					child:SetAttribute("HiddenByHUD", child.Visible)
					child.Visible = false
				end
			elseif visible then
				child.Visible = child:GetAttribute("HiddenByHUD") == true
				child:SetAttribute("HiddenByHUD", nil)
			end
		end
	end
end

local function updateScreens()
	local round = State.Round
	local phase = if round then round.Phase else nil
	local endPhase = phase == "POTGReplay" or phase == "VictoryDropAndSummary"
	local inMatch = round ~= nil
	local armed = State.InCombat()
	hud.Enabled = (armed or (inMatch and not endPhase and phase ~= "PreMatchVS")) and not State.Cinematic and not endPhase
	vs.Enabled = phase == "PreMatchVS" and not State.Cinematic
	setLobbyChrome(not inMatch and not armed)
	local topVisible = inMatch
	UIUtil.Frame(hud, "TopBar").Visible = topVisible
	UIUtil.Frame(hud, "AlphaAlive").Visible = topVisible
	UIUtil.Frame(hud, "BravoAlive").Visible = topVisible
	if not inMatch then
		UIUtil.Label(hud, "RingWarning").Text = ""
		UIUtil.Frame(hud, "Banner").Visible = false
		UIUtil.Label(hud, "CountdownText").Text = ""
	end
	if endPhase or not inMatch then
		death.Enabled = armed and not State.Alive()
	end
end

---------------------------------------------------------------------------------------------
-- VS screen
---------------------------------------------------------------------------------------------
local function fillVS(round: Types.RoundState)
	UIUtil.Label(vs, "Background/MapLabel").Text = UIUtil.PrettyMap(round.MapName)
	UIUtil.Label(vs, "Background/ModeLabel").Text = string.format("%s · BEST OF %d", round.Mode, GameConfig.RoundsToWin * 2 - 1)
	for _, team in { "Alpha", "Bravo" } do
		local i = 0
		for _, r in round.Roster do
			if r.Team == team then
				i += 1
				local card = UIUtil.Find(vs, string.format("Background/%sColumn/Card%d", team, i))
				if card then
					UIUtil.Label(card, "Name").Text = r.Name
					UIUtil.Label(card, "Level").Text = if r.IsBot then "BOT" else ""
					UIUtil.Label(card, "Tag").Text = if r.UserId == player.UserId then "YOU" elseif r.IsBot then "AI FIGHTER" else "PLAYER"
					;(card :: GuiObject).Visible = true
				end
			end
		end
		for j = i + 1, 3 do
			local card = UIUtil.Find(vs, string.format("Background/%sColumn/Card%d", team, j))
			if card then
				(card :: GuiObject).Visible = false
			end
		end
	end
	local label = UIUtil.Label(vs, "Background/VSLabel")
	label.Size = UDim2.fromScale(0.3, 0.36)
	UIUtil.Tween(label, 0.5, { Size = UDim2.fromScale(0.16, 0.2) }, Enum.EasingStyle.Back)
	SoundCatalog.Play("Countdown", nil, 0)
end

---------------------------------------------------------------------------------------------
-- Score bar and alive icons
---------------------------------------------------------------------------------------------
local function fillScore(round: Types.RoundState)
	for _, team in { "Alpha", "Bravo" } do
		local score = if team == "Alpha" then round.Score.Alpha else round.Score.Bravo
		UIUtil.Label(hud, string.format("TopBar/%sScore/Score", team)).Text = tostring(score)
		for i = 1, 3 do
			local pip = UIUtil.Find(hud, string.format("TopBar/%sScore/%sPips/Pip%d", team, team, i))
			if pip and pip:IsA("Frame") then
				pip.BackgroundTransparency = if score >= i then 0 else 0.75
			end
		end
		local row = UIUtil.Get(hud, team .. "Alive")
		UIUtil.ClearClones(row)
		local template = UIUtil.Frame(row, "IconTemplate")
		local order = 0
		for _, r in round.Roster do
			if r.Team == team then
				order += 1
				local icon = UIUtil.CloneTemplate(template, "Icon_" .. r.Id)
				icon.LayoutOrder = order
				icon.BackgroundTransparency = if r.Alive then 0.1 else 0.8
				local initial = icon:FindFirstChild("Initial")
				if initial and initial:IsA("TextLabel") then
					initial.Text = if r.Alive then string.upper(string.sub(r.Name, 1, 1)) else "✕"
					initial.TextTransparency = if r.Alive then 0 else 0.4
				end
			end
		end
	end
	UIUtil.Label(hud, "TopBar/RoundLabel").Text = "ROUND " .. round.Round
end

local function showBanner(text: string, sub: string, color: Color3, seconds: number)
	local banner = UIUtil.Frame(hud, "Banner")
	local label = UIUtil.Label(banner, "BannerText")
	label.Text = text
	label.TextColor3 = color
	UIUtil.Label(banner, "BannerSub").Text = sub
	banner.Visible = true
	banner.Size = UDim2.fromScale(0.9, 0.3)
	UIUtil.Tween(banner, 0.35, { Size = UDim2.fromScale(0.6, 0.2) }, Enum.EasingStyle.Back)
	local token = os.clock()
	banner:SetAttribute("Token", token)
	task.delay(seconds, function()
		if banner:GetAttribute("Token") == token then
			banner.Visible = false
		end
	end)
end

local function roundEndBanner(round: Types.RoundState)
	local mine = myTeam()
	local tags = round.BannerTags or {}
	local tagText = table.concat(tags, "  ·  ")
	if round.RoundWinner == nil then
		showBanner("DRAW", "ROUND " .. round.Round, T.SubText, GameConfig.Phases.RoundEndBanner)
	elseif round.RoundWinner == mine or mine == "Neutral" then
		local sub = if tagText ~= "" then tagText else "ROUND " .. round.Round
		showBanner(if mine == "Neutral" then string.upper(round.RoundWinner) .. " WINS" else "ROUND WON", sub, T.Gold, GameConfig.Phases.RoundEndBanner)
		SoundCatalog.Play("UIConfirm", nil, 0)
	else
		showBanner("ROUND LOST", if tagText ~= "" then "ENEMY " .. tagText else "ROUND " .. round.Round, T.Bad, GameConfig.Phases.RoundEndBanner)
	end
end

---------------------------------------------------------------------------------------------
-- Preset switcher ([B] during PreRoundLoadout)
---------------------------------------------------------------------------------------------
local function refreshSwitcher()
	local profile = State.Profile
	for i = 1, 5 do
		local b = UIUtil.Button(hud, "PresetSwitcher/List/Preset" .. i)
		local preset = if profile then profile.Presets[i] else nil
		b.Text = if preset then string.format("%d. %s", i, preset.Name) else string.format("%d. —", i)
		local active = profile ~= nil and profile.ActivePreset == i
		b.BackgroundColor3 = if active then T.Gold else T.PanelLighter
		b.TextColor3 = if active then T.Black else T.Text
	end
end

local function setSwitcher(open: boolean)
	switcherOpen = open
	UIUtil.Frame(hud, "PresetSwitcher").Visible = open
	State.SetMenu("PresetSwitcher", open)
	if open then
		refreshSwitcher()
	end
end

function HUD.TogglePresetSwitcher()
	local round = State.Round
	if round == nil or round.Phase ~= "PreRoundLoadout" then
		setSwitcher(false)
		return
	end
	setSwitcher(not switcherOpen)
end

---------------------------------------------------------------------------------------------
-- Hotbar, hints, vitals
---------------------------------------------------------------------------------------------
local function countText(slot: Types.InventorySlot, spec: Types.EquipmentSpec?, inv: Types.InventoryView): string
	if spec == nil then
		return ""
	end
	if spec.SubType == "BOW" then
		return tostring(inv.Ammo.Arrows + inv.Ammo.FireArrows)
	elseif spec.SubType == "GUN" then
		return tostring(inv.Ammo.Bullets)
	end
	if slot.Count < 0 then
		return ""
	end
	return "×" .. slot.Count
end

local function refreshHotbar()
	local inv = State.Inventory
	for i = 1, 6 do
		local frame = UIUtil.Frame(hud, "Hotbar/Slot" .. i)
		local slot = if inv then inv.Slots[i] else nil
		local spec = if slot then EquipmentDatabase.Get(slot.ItemId) else nil
		local stroke = frame:FindFirstChild("SelectStroke") :: UIStroke?
		local selected = inv ~= nil and inv.Equipped == i
		UIUtil.Label(frame, "Glyph").Text = if slot then UIUtil.Glyph(slot.ItemId) else ""
		UIUtil.Label(frame, "ItemName").Text = if spec then spec.DisplayName else ""
		UIUtil.Label(frame, "Count").Text = if slot and spec and inv then countText(slot, spec, inv) else ""
		UIUtil.Label(frame, "Level").Text = if slot then "LV" .. slot.Level else ""
		frame.BackgroundTransparency = if slot then (if selected then 0.05 else 0.25) else 0.7
		if stroke then
			stroke.Color = if selected then T.Gold elseif spec then UIUtil.RarityColor(spec) else T.Stroke
			stroke.Thickness = if selected then 3.5 else 1.5
			stroke.Transparency = if slot then 0 else 0.6
		end
		local glyph = UIUtil.Label(frame, "Glyph")
		glyph.TextTransparency = if slot and slot.Count == 0 then 0.6 else 0
	end
	-- hints for the item in hand
	local slot = if inv then inv.Slots[inv.Equipped] else nil
	local spec = if slot then EquipmentDatabase.Get(slot.ItemId) else nil
	UIUtil.Label(hud, "ControlHints/HintText").Text = if spec then spec.HotbarHint else ""
	local ammo = ""
	if inv and spec then
		if spec.SubType == "BOW" then
			local arrows = string.format("ARROWS %d", inv.Ammo.Arrows)
			local fire = string.format("FIRE %d", inv.Ammo.FireArrows)
			ammo = if inv.UseFireArrows then arrows .. "  " .. colored("🔥 " .. fire, Color3.fromRGB(255, 140, 40)) else colored(arrows, T.Gold) .. "  " .. fire
		elseif spec.SubType == "GUN" then
			ammo = string.format("BULLETS %d", inv.Ammo.Bullets)
		elseif slot and slot.Count >= 0 then
			ammo = string.format("%s ×%d", string.upper(spec.DisplayName), slot.Count)
		end
	end
	UIUtil.Label(hud, "ControlHints/AmmoLabel").Text = ammo
end

local function refreshViewLabel()
	local first = State.ViewMode == "First"
	local mode = if first then colored("FIRST PERSON", T.Gold) else colored("THIRD PERSON", T.Gold)
	local shoulder = if State.Shoulder >= 0 then "R" else "L"
	UIUtil.Label(hud, "ControlHints/ViewModeLabel").Text = string.format("[V] %s   [X] SHOULDER %s   [C] SLIDE", mode, shoulder)
end

local function chip(template: GuiObject, text: string, color: Color3, order: number)
	local c = UIUtil.CloneTemplate(template, "Chip_" .. text)
	c.LayoutOrder = order
	c.BackgroundColor3 = color
	local label = c:FindFirstChild("Label")
	if label and label:IsA("TextLabel") then
		label.Text = text
	end
end

local lastChips = ""

local function refreshVitals()
	local humanoid = State.Humanoid()
	local character = State.Character()
	local hp = if humanoid then math.max(0, humanoid.Health) else 0
	local maxHp = if humanoid then math.max(1, humanoid.MaxHealth) else 100
	local hFill = UIUtil.Frame(hud, "Vitals/HealthBar/Fill")
	UIUtil.SetFill(hFill, hp / maxHp)
	hFill.BackgroundColor3 = if hp / maxHp < 0.3 then T.Bad else T.Health
	UIUtil.Label(hud, "Vitals/HealthBar/HealthText").Text = tostring(math.ceil(hp))
	local armor = if character then character:GetAttribute("Armor") else nil
	local armorMax = if character then character:GetAttribute("ArmorMax") else nil
	local a = if type(armor) == "number" then armor else 0
	local am = if type(armorMax) == "number" then armorMax else 0
	UIUtil.SetFill(UIUtil.Frame(hud, "Vitals/ArmorBar/Fill"), if am > 0 then a / am else 0)
	UIUtil.Label(hud, "Vitals/ArmorBar/ArmorText").Text = if am > 0 then string.format("%d", math.ceil(a)) else "NO ARMOR"

	-- status chips
	local t = now()
	local list: { { string } } = {}
	if character then
		local stagger = character:GetAttribute("StaggerUntil")
		if type(stagger) == "number" and stagger > t then
			table.insert(list, { "STAGGERED", "W" })
		end
		if character:GetAttribute("Rooted") == true then
			table.insert(list, { "ROOTED", "B" })
		elseif snareUntil > t then
			table.insert(list, { "SNARED", "B" })
		end
		local heal = character:GetAttribute("HealingUntil")
		if type(heal) == "number" and heal > t then
			table.insert(list, { "HEALING", "G" })
		end
		if character:GetAttribute("Blocking") == true then
			table.insert(list, { "BLOCKING", "S" })
		end
		local shield = character:GetAttribute("ShieldHP")
		local inv = State.Inventory
		if inv and inv.ShieldMax > 0 and type(shield) == "number" then
			table.insert(list, { string.format("SHIELD %d", math.ceil(shield)), "S" })
		end
		local mult = character:GetAttribute("SpeedMult")
		if type(mult) == "number" and mult > 1.05 then
			table.insert(list, { "HASTE", "G" })
		end
	end
	local key = ""
	for _, e in list do
		key ..= e[1] .. ";"
	end
	if key ~= lastChips then
		lastChips = key
		local row = UIUtil.Get(hud, "Vitals/StatusRow")
		UIUtil.ClearClones(row)
		local template = UIUtil.Frame(row, "StatusTemplate")
		for i, e in list do
			local color = if e[2] == "W" then Color3.fromRGB(200, 200, 210) elseif e[2] == "B" then T.Armor elseif e[2] == "G" then T.Good else T.PanelLighter
			chip(template, e[1], color, i)
		end
	end

	-- heal cast bar
	local cast = UIUtil.Frame(hud, "CastBar")
	local healUntil = if character then character:GetAttribute("HealingUntil") else nil
	if type(healUntil) == "number" and healUntil > t then
		cast.Visible = true
		local startAt = cast:GetAttribute("CastStart")
		local total = cast:GetAttribute("CastTotal")
		if cast:GetAttribute("CastEnd") ~= healUntil then
			cast:SetAttribute("CastEnd", healUntil)
			cast:SetAttribute("CastStart", t)
			cast:SetAttribute("CastTotal", healUntil - t)
			startAt = t
			total = healUntil - t
		end
		local s = if type(startAt) == "number" then startAt else t
		local tt = if type(total) == "number" and total > 0 then total else 1
		UIUtil.SetFill(UIUtil.Frame(cast, "Bar/Fill"), (t - s) / tt)
		local spec = State.EquippedSpec()
		UIUtil.Label(cast, "Label").Text = string.format("%s...  [Q] cancel", if spec then string.upper(spec.DisplayName) else "HEALING")
	else
		cast.Visible = false
	end
end

---------------------------------------------------------------------------------------------
-- Crosshair, hitmarker, scope
---------------------------------------------------------------------------------------------
local function refreshCrosshair()
	local cross = UIUtil.Frame(hud, "Crosshair")
	cross.Visible = Camera.IsActive() and not State.InMenu()
	local spec = State.EquippedSpec()
	local root = State.Root()
	local speed = if root then Vector3.new(root.AssemblyLinearVelocity.X, 0, root.AssemblyLinearVelocity.Z).Magnitude else 0
	local spread = math.clamp(speed / 24, 0, 1) * 0.12
	if State.Aiming then
		spread *= 0.3
	end
	local melee = spec ~= nil and (spec.SubType == "MELEE" or spec.SubType == "SHIELD")
	for _, name in { "Top", "Bottom", "Left", "Right" } do
		local line = UIUtil.Frame(cross, name)
		line.Visible = not melee
		if name == "Top" then
			line.Position = UDim2.fromScale(0.5, 0.18 - spread)
		elseif name == "Bottom" then
			line.Position = UDim2.fromScale(0.5, 0.82 + spread)
		elseif name == "Left" then
			line.Position = UDim2.fromScale(0.18 - spread, 0.5)
		else
			line.Position = UDim2.fromScale(0.82 + spread, 0.5)
		end
	end
	-- draw ring shrinks as the bow draws (and further when aiming down sights)
	local ring = UIUtil.Frame(cross, "DrawRing")
	local ranged = spec ~= nil and EquipmentDatabase.IsRanged(spec)
	ring.Visible = ranged and (State.Drawing or State.Aiming)
	local scale = 1 - 0.6 * State.DrawRatio
	if State.Aiming then
		scale *= 0.75
	end
	ring.Size = UDim2.fromScale(math.max(scale, 0.25) * 1.4, math.max(scale, 0.25) * 1.4)
	local rs = ring:FindFirstChild("RingStroke")
	if rs and rs:IsA("UIStroke") then
		rs.Color = if State.DrawRatio >= 0.99 then T.Gold else T.White
	end
	-- hitmarker
	local marker = UIUtil.Frame(cross, "Hitmarker")
	local remaining = hitmarkerUntil - os.clock()
	marker.Visible = remaining > 0
	if remaining > 0 then
		local pop = 1 + remaining * 1.5
		marker.Size = UDim2.fromScale(0.8 * pop, 0.8 * pop)
		for i = 1, 4 do
			local seg = marker:FindFirstChild("Seg" .. i)
			if seg and seg:IsA("Frame") then
				seg.BackgroundColor3 = hitmarkerColor
			end
		end
	end
	-- scope vignette for zoomed sights
	local scope = UIUtil.Frame(hud, "ScopeVignette")
	local zoomed = State.Aiming and spec ~= nil and (spec.ZoomFOVAds or 70) <= 45
	scope.BackgroundTransparency = if zoomed then 0 else 1
end

local function hitmarker(color: Color3)
	hitmarkerUntil = os.clock() + 0.18
	hitmarkerColor = color
end

---------------------------------------------------------------------------------------------
-- Floating damage numbers
---------------------------------------------------------------------------------------------
local function floatText(world: Vector3, text: string, color: Color3, size: number?)
	local template = UIUtil.Label(hud, "DamageNumbers/DamageTemplate")
	local label = UIUtil.CloneTemplate(template, "Num")
	label.Text = text
	label.TextColor3 = color
	local s = size or 1
	label.Size = UDim2.fromScale(0.08 * s, 0.05 * s)
	table.insert(numbers, {
		Label = label,
		World = world,
		Born = os.clock(),
		Drift = (math.random() - 0.5) * 120,
		Rise = 150 + math.random() * 60,
	})
	if #numbers > 24 then
		local old = table.remove(numbers, 1)
		if old then
			old.Label:Destroy()
		end
	end
end

local function stepNumbers()
	local cam = Workspace.CurrentCamera
	if cam == nil then
		return
	end
	local i = 1
	while i <= #numbers do
		local n = numbers[i]
		local age = os.clock() - n.Born
		if age > 1.1 or n.Label.Parent == nil then
			n.Label:Destroy()
			table.remove(numbers, i)
		else
			local screen, onScreen = cam:WorldToViewportPoint(n.World)
			if not onScreen then
				n.Label.Visible = false
			else
				-- parabola: y = v0 t - 1/2 g t^2 (pixels), constant horizontal drift
				local up = n.Rise * age - 0.5 * 420 * age * age
				n.Label.Visible = true
				n.Label.Position = UDim2.fromOffset(screen.X + n.Drift * age, screen.Y - up - 20)
				local fade = math.clamp((age - 0.6) / 0.5, 0, 1)
				n.Label.TextTransparency = fade
				local stroke = n.Label:FindFirstChildOfClass("UIStroke")
				if stroke then
					stroke.Transparency = fade
				end
			end
			i += 1
		end
	end
end

---------------------------------------------------------------------------------------------
-- Kill feed and banners
---------------------------------------------------------------------------------------------
local function feed(packet: Types.CombatEventPacket)
	local template = UIUtil.Frame(hud, "KillFeed/FeedTemplate")
	local entry = UIUtil.CloneTemplate(template, "Feed")
	feedCounter += 1
	entry.LayoutOrder = -feedCounter
	local killer = packet.KillerName or "?"
	local victim = packet.VictimName or "?"
	local weaponSpec = if packet.WeaponId then EquipmentDatabase.Get(packet.WeaponId) else nil
	local weapon = if weaponSpec then UIUtil.Glyph(weaponSpec.Id) else (if packet.WeaponId == "Ring" then "🔥" else "☠")
	local text = string.format(
		"%s %s%s %s",
		colored(killer, UIUtil.TeamColor(teamOf(packet.KillerId))),
		weapon,
		if packet.Headshot then " 🎯" else "",
		colored(victim, UIUtil.TeamColor(teamOf(packet.VictimId)))
	)
	local label = entry:FindFirstChild("Text")
	if label and label:IsA("TextLabel") then
		label.Text = text
	end
	if packet.KillerId == State.MyId() or packet.VictimId == State.MyId() then
		local stroke = Instance.new("UIStroke")
		stroke.Color = T.Gold
		stroke.Thickness = 1.5
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		stroke.Parent = entry
	end
	local count = 0
	for _, child in (template.Parent :: Instance):GetChildren() do
		if child:GetAttribute("UIClone") == true then
			count += 1
		end
	end
	if count > 5 then
		local oldest: Instance? = nil
		local oldestOrder = -math.huge
		for _, child in (template.Parent :: Instance):GetChildren() do
			if child:GetAttribute("UIClone") == true and child:IsA("GuiObject") and child.LayoutOrder > oldestOrder then
				oldest = child
				oldestOrder = child.LayoutOrder
			end
		end
		if oldest then
			oldest:Destroy()
		end
	end
	task.delay(6, function()
		if entry.Parent then
			UIUtil.Tween(entry, 0.4, { BackgroundTransparency = 1 })
			if label and label:IsA("TextLabel") then
				UIUtil.Tween(label, 0.4, { TextTransparency = 1 })
			end
			task.wait(0.45)
			entry:Destroy()
		end
	end)
end

local function killBanner(victimName: string)
	local banner = UIUtil.Frame(hud, "KillBanner")
	UIUtil.Label(banner, "KillText").Text = "ELIMINATED " .. string.upper(victimName)
	banner.Visible = true
	banner.Size = UDim2.fromScale(0.42, 0.1)
	UIUtil.Tween(banner, 0.25, { Size = UDim2.fromScale(0.3, 0.07) }, Enum.EasingStyle.Back)
	killBannerToken += 1
	local token = killBannerToken
	SoundCatalog.Play("Kill", nil, 0)
	task.delay(1.8, function()
		if token == killBannerToken then
			banner.Visible = false
		end
	end)
end

---------------------------------------------------------------------------------------------
-- Death card and spectating
---------------------------------------------------------------------------------------------
local function livingTeammates(): { string }
	local list: { string } = {}
	local round = State.Round
	if round == nil then
		return list
	end
	local mine = myTeam()
	for _, r in round.Roster do
		if r.Team == mine and r.Alive and r.UserId ~= player.UserId then
			table.insert(list, r.Id)
		end
	end
	return list
end

local function spectateCurrent()
	local id = spectateIds[spectateIndex]
	local model = if id then Renderer.FindCombatantModel(id) else nil
	State.SpectateTarget = model
	local entry = rosterEntry(id)
	UIUtil.Label(death, "SpectateBar/TargetName").Text = if entry then entry.Name else ""
end

local function stopSpectating()
	spectating = false
	State.SpectateTarget = nil
	UIUtil.Frame(death, "SpectateBar").Visible = false
	UIUtil.Frame(death, "EliminatedCard").Visible = false
	death.Enabled = false
end

local function startSpectating()
	spectateIds = livingTeammates()
	if #spectateIds == 0 then
		return
	end
	spectating = true
	spectateIndex = 1
	death.Enabled = true
	UIUtil.Frame(death, "EliminatedCard").Visible = false
	UIUtil.Frame(death, "SpectateBar").Visible = true
	UIUtil.Label(death, "SpectateBar/Label").Text = "SPECTATING"
	spectateCurrent()
end

local function cycleSpectate(direction: number)
	if not spectating then
		return
	end
	spectateIds = livingTeammates()
	if #spectateIds == 0 then
		State.SpectateTarget = nil
		return
	end
	spectateIndex = ((spectateIndex - 1 + direction) % #spectateIds) + 1
	spectateCurrent()
end

function HUD.CycleSpectate(direction: number)
	cycleSpectate(direction)
end

local function onDeath(packet: Types.CombatEventPacket)
	deathToken += 1
	local token = deathToken
	death.Enabled = true
	local card = UIUtil.Frame(death, "EliminatedCard")
	card.Visible = true
	UIUtil.Frame(death, "SpectateBar").Visible = false
	UIUtil.Label(card, "KillerName").Text = packet.KillerName or "THE RING"
	local spec = if packet.WeaponId then EquipmentDatabase.Get(packet.WeaponId) else nil
	UIUtil.Label(card, "WeaponLabel").Text = if spec then UIUtil.Glyph(spec.Id) .. " " .. spec.DisplayName else (packet.WeaponId or "")
	UIUtil.Label(card, "KillerHP").Text = if packet.KillerId then string.format("❤ %d HP", math.ceil(packet.KillerHP or 0)) else ""
	card.Position = UDim2.fromScale(0.5, 0.7)
	UIUtil.Tween(card, 0.3, { Position = UDim2.fromScale(0.5, 0.62) }, Enum.EasingStyle.Back)
	SoundCatalog.Play("Death", nil, 0)
	State.Aiming = false
	task.delay(2.5, function()
		if token ~= deathToken or State.Alive() then
			return
		end
		if State.Round then
			startSpectating()
		else
			card.Visible = false
		end
	end)
end

---------------------------------------------------------------------------------------------
-- Combat events
---------------------------------------------------------------------------------------------
local function headOf(id: string?): Vector3?
	local model = if id then Renderer.FindCombatantModel(id) else nil
	local head = if model then model:FindFirstChild("Head") else nil
	return if head and head:IsA("BasePart") then head.Position + Vector3.new(0, 1, 0) else nil
end

local function onDamage(report: Types.DamageReport)
	local me = State.MyId()
	if report.AttackerId == me and report.VictimId ~= me then
		local pos = report.Position
		local amount = math.floor(report.Amount + report.ArmorAmount + 0.5)
		if report.Blocked then
			floatText(pos, if amount > 0 then tostring(amount) .. " BLOCKED" else "BLOCKED", Color3.fromRGB(170, 176, 196))
			hitmarker(Color3.fromRGB(170, 176, 196))
			SoundCatalog.Play("Block", nil, 0.05)
		elseif report.Headshot then
			floatText(pos, string.format("%d HEADSHOT!", amount), Color3.fromRGB(255, 220, 40), 1.3)
			hitmarker(Color3.fromRGB(255, 220, 40))
			SoundCatalog.Play("HitHeadshot", nil, 0.03)
		elseif report.Amount <= 0 and report.ArmorAmount > 0 then
			floatText(pos, tostring(amount), T.Armor)
			hitmarker(T.Armor)
			SoundCatalog.Play("HitArmor", nil, 0.05)
		else
			floatText(pos, tostring(amount), T.White)
			hitmarker(T.White)
			SoundCatalog.Play("Hitmarker", nil, 0.05)
		end
		if report.ArmorBroken then
			floatText(pos + Vector3.new(0, 1.2, 0), "ARMOR BROKEN", Color3.fromRGB(80, 170, 255), 1.2)
			SoundCatalog.Play("ArmorBreak", nil, 0.03)
		end
		if report.Staggered then
			floatText(pos + Vector3.new(0, 0.6, 0), "STAGGERED", T.White, 1.1)
		end
		if report.Killed then
			hitmarker(T.Bad)
		end
	elseif report.VictimId == me then
		Camera.Shake(math.clamp(report.Amount / 40, 0.2, 1.5))
		SoundCatalog.Play(if report.Blocked then "Block" else "HitFlesh", nil, 0.05)
		if report.Staggered then
			State.Notify:Fire("STAGGERED", "Error")
		end
	end
end

local function onCombatEvent(packet: any)
	if type(packet) ~= "table" or type(packet.Kind) ~= "string" then
		return
	end
	local p = packet :: Types.CombatEventPacket
	local me = State.MyId()
	State.CombatEvent:Fire(p)
	if p.Kind == "Damage" and p.Report then
		onDamage(p.Report)
	elseif p.Kind == "Kill" then
		feed(p)
		if p.KillerId == me and p.VictimId ~= me then
			killBanner(p.VictimName or "?")
			hitmarker(T.Bad)
		end
		if p.VictimId == me then
			onDeath(p)
		end
		if p.Position then
			VFX.Burst("SkullBurst", CFrame.new(p.Position + Vector3.new(0, 2, 0)))
		end
		if spectating and State.SpectateTarget and State.SpectateTarget:GetAttribute("CombatantId") == p.VictimId then
			task.delay(1, cycleSpectate, 1)
		end
	elseif p.Kind == "ArmorBroken" then
		if p.VictimId == me then
			State.Notify:Fire("YOUR ARMOR BROKE", "Error")
		end
		if p.Position then
			VFX.Burst("ArmorBreak_Shatter", CFrame.new(p.Position))
		end
	elseif p.Kind == "ShieldBroken" then
		if p.VictimId == me then
			State.Notify:Fire("YOUR SHIELD SHATTERED", "Error")
		end
		if p.Position then
			floatText(p.Position, "SHIELD BROKEN", Color3.fromRGB(255, 170, 60), 1.1)
		end
	elseif p.Kind == "Status" then
		if p.TargetId == me then
			if p.Status == "Snared" then
				snareUntil = now() + (p.Duration or 2)
				State.Notify:Fire("SNARED!", "Error")
			elseif p.Status == "Backstabbed" then
				State.Notify:Fire("BACKSTABBED!", "Error")
			end
		else
			local head = headOf(p.TargetId)
			if head and p.Status then
				floatText(head, string.upper(p.Status), T.White, 0.9)
			end
		end
	elseif p.Kind == "Healed" then
		local head = headOf(p.TargetId)
		if head and p.Amount and p.Amount > 0 then
			floatText(head, string.format("+%d", math.floor(p.Amount)), T.Good)
			SoundCatalog.Play("Heal", nil, 0.05)
		end
	end
end

local function onUtilityEvent(kind: any, payload: any)
	if type(payload) ~= "table" then
		return
	end
	if kind == "WarHornReveal" and type(payload.Targets) == "table" then
		local duration = if type(payload.Duration) == "number" then payload.Duration else 5
		for _, id in payload.Targets do
			if type(id) == "string" then
				local model = Renderer.FindCombatantModel(id)
				local template = VFX.Find("WarHorn_RevealHighlight")
				if model and template and template:IsA("Highlight") then
					local h = template:Clone()
					h.Adornee = model
					h.Enabled = true
					h.Parent = model
					Debris:AddItem(h, duration)
				end
			end
		end
		State.Notify:Fire(string.format("WAR HORN! %d enemies revealed", #payload.Targets), "Success")
		SoundCatalog.Play("WarHorn", nil, 0)
	elseif kind == "WarHornHeard" then
		State.Notify:Fire("An enemy war horn sounds - you are revealed!", "Error")
		SoundCatalog.Play("WarHorn", nil, 0)
	end
end

---------------------------------------------------------------------------------------------
-- Round state
---------------------------------------------------------------------------------------------
local function onRound(round: Types.RoundState?, _previous: Types.RoundState?)
	if round == nil then
		lastPhase = nil
		setSwitcher(false)
		stopSpectating()
		updateScreens()
		return
	end
	local phase = round.Phase
	if phase ~= lastPhase then
		if phase == "PreMatchVS" then
			fillVS(round)
		elseif phase == "PreRoundLoadout" then
			stopSpectating()
			lastCountdown = -1
			UIUtil.Frame(hud, "Banner").Visible = false
		elseif phase == "ActiveCombat" then
			setSwitcher(false)
			fightShownUntil = os.clock() + 1.1
			SoundCatalog.Play("Fight", nil, 0)
		elseif phase == "RoundEndBanner" then
			roundEndBanner(round)
		elseif phase == "POTGReplay" or phase == "VictoryDropAndSummary" then
			setSwitcher(false)
			stopSpectating()
		end
		lastPhase = phase
	end
	if phase ~= "PreRoundLoadout" and switcherOpen then
		setSwitcher(false)
	end
	fillScore(round)
	if spectating then
		local ids = livingTeammates()
		local current = spectateIds[spectateIndex]
		if current == nil or not table.find(ids, current) then
			spectateIds = ids
			spectateIndex = 1
			if #ids == 0 then
				State.SpectateTarget = nil
			else
				spectateCurrent()
			end
		end
	end
	updateScreens()
end

local function ringRadius(round: Types.RoundState, t: number): number
	if not round.RingActive or round.RingShrinkStartsAt == 0 then
		return round.RingStartRadius
	end
	local a = math.clamp((t - round.RingShrinkStartsAt) / math.max(round.RingShrinkDuration, 0.1), 0, 1)
	return round.RingStartRadius + (GameConfig.Ring.EndRadius - round.RingStartRadius) * a
end

local function stepRound()
	local round = State.Round
	if round == nil then
		return
	end
	local t = now()
	local remaining = round.PhaseEndsAt - t
	local countdown = UIUtil.Label(hud, "CountdownText")
	if round.Phase == "PreRoundLoadout" then
		local n = math.max(1, math.ceil(remaining))
		countdown.Text = tostring(n)
		if n ~= lastCountdown then
			lastCountdown = n
			countdown.TextSize = 140
			countdown.Size = UDim2.fromScale(0.42, 0.28)
			UIUtil.Tween(countdown, 0.3, { Size = UDim2.fromScale(0.3, 0.2) }, Enum.EasingStyle.Back)
			SoundCatalog.Play("Countdown", nil, 0)
		end
		UIUtil.Label(hud, "TopBar/RoundTimer").Text = UIUtil.FormatTime(GameConfig.Phases.ActiveCombat)
	elseif os.clock() < fightShownUntil then
		countdown.Text = "FIGHT!"
		countdown.TextColor3 = T.Gold
	else
		countdown.Text = ""
		countdown.TextColor3 = T.White
	end
	if round.Phase == "ActiveCombat" then
		local timer = UIUtil.Label(hud, "TopBar/RoundTimer")
		if round.RingActive then
			timer.Text = "🔥"
			timer.TextColor3 = Color3.fromRGB(255, 140, 40)
		else
			timer.Text = UIUtil.FormatTime(remaining)
			timer.TextColor3 = if remaining <= 10 then T.Bad else T.White
		end
	end
	-- Ring of Fire
	local warning = UIUtil.Label(hud, "RingWarning")
	if round.Phase == "ActiveCombat" and round.RingActive then
		local radius = ringRadius(round, t)
		local root = State.Root()
		local outside = false
		if root then
			local d = root.Position - round.RingCenter
			outside = Vector3.new(d.X, 0, d.Z).Magnitude > radius
		end
		if outside and State.Alive() then
			warning.Text = "⚠ YOU ARE IN THE RING OF FIRE - MOVE IN!"
			warning.TextColor3 = if math.floor(os.clock() * 4) % 2 == 0 then T.Bad else Color3.fromRGB(255, 200, 60)
		else
			warning.Text = string.format("🔥 RING OF FIRE CLOSING · %d studs", math.floor(radius))
			warning.TextColor3 = Color3.fromRGB(255, 140, 40)
		end
	elseif round.Phase == "ActiveCombat" and remaining <= 10 and remaining > 0 then
		warning.Text = string.format("RING OF FIRE IN %d", math.ceil(remaining))
		warning.TextColor3 = Color3.fromRGB(255, 200, 60)
	else
		warning.Text = ""
	end
end

---------------------------------------------------------------------------------------------
function HUD.Init()
	hud = UIUtil.Gui("CombatHUD")
	vs = UIUtil.Gui("VSScreen")
	death = UIUtil.Gui("DeathAndSpectate")
	lobby = UIUtil.Gui("LobbyHUD")
end

function HUD.Start()
	hud.Enabled = false
	vs.Enabled = false
	death.Enabled = false
	for i = 1, 5 do
		UIUtil.Button(hud, "PresetSwitcher/List/Preset" .. i).Activated:Connect(function()
			UIUtil.Click()
			Net.Reliable("SwitchPresetInPreRound"):FireServer(i)
			local profile = State.Profile
			if profile then
				profile.ActivePreset = i
			end
			refreshSwitcher()
			setSwitcher(false)
		end)
	end
	UIUtil.Button(death, "SpectateBar/PrevButton").Activated:Connect(function()
		cycleSpectate(-1)
	end)
	UIUtil.Button(death, "SpectateBar/NextButton").Activated:Connect(function()
		cycleSpectate(1)
	end)

	State.RoundChanged:Connect(onRound)
	State.InventoryChanged:Connect(function()
		refreshHotbar()
		updateScreens()
	end)
	State.ViewChanged:Connect(refreshViewLabel)
	State.ProfileChanged:Connect(function()
		if switcherOpen then
			refreshSwitcher()
		end
	end)
	State.Notify:Connect(function(text: string, kind: string)
		UIUtil.Toast(text, kind)
	end)
	Net.Reliable("CombatEvent").OnClientEvent:Connect(onCombatEvent)
	Net.Reliable("UtilityEvent").OnClientEvent:Connect(onUtilityEvent)
	player.CharacterAdded:Connect(function()
		deathToken += 1
		if not spectating then
			death.Enabled = false
		end
	end)

	refreshHotbar()
	refreshViewLabel()
	local accum = 0
	RunService.RenderStepped:Connect(function(dt)
		if not hud.Enabled then
			if #numbers > 0 then
				stepNumbers()
			end
			return
		end
		stepRound()
		refreshCrosshair()
		stepNumbers()
		-- hotbar cooldown sweeps every frame, vitals at 20 Hz
		for i = 1, 6 do
			local remaining, total = Weapon.SlotCooldown(i)
			local cd = UIUtil.Frame(hud, "Hotbar/Slot" .. i .. "/Cooldown")
			cd.Size = UDim2.fromScale(1, if total > 0 then math.clamp(remaining / total, 0, 1) else 0)
		end
		accum += dt
		if accum >= 0.05 then
			accum = 0
			refreshVitals()
			if spectating and State.Alive() and State.Round and State.Round.Phase ~= "ActiveCombat" then
				stopSpectating()
			end
		end
	end)
end

return HUD
