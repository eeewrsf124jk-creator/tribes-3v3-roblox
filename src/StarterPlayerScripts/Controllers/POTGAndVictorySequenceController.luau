--!strict
-- POTGAndVictorySequenceController: the end-of-match show.
--   1. PLAY OF THE GAME: 2 s black splash "PLAY OF THE GAME | {Name} | {Tags}", then the REC
--      camcorder overlay while the server-recorded 20 Hz frames are replayed at 60 FPS on the
--      map's puppet clones (CFrame:Lerp between frames, equips / shots / swings / kills from the
--      event list), the camera riding the featured player's shoulder. [SKIP >>] ends it early.
--   2. VICTORY DROP: the chest idles, then shakes x3 -> x2 -> x1 and bursts open; the four
--      cards flip one after another showing shards gained, shard progress and UPGRADE READY.
--      The same sequence plays for a purchased Golden Drop.
--   3. SCOREBOARD: 6 rows of K / D / A / DMG / Glory, the MVP card, the XP breakdown with an
--      animated XP bar, and [PLAY AGAIN (25s)] counting down.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local Net = require(Modules.Shared.Net)
local Types = require(Modules.Shared.Types)
local VFX = require(Modules.Shared.VFX)
local EquipmentRig = require(Modules.Shared.EquipmentRig)
local EquipmentDatabase = require(Modules.Config.EquipmentDatabase)
local UpgradeScalingMath = require(Modules.Config.UpgradeScalingMath)
local SoundCatalog = require(Modules.Config.SoundCatalog)
local State = require(script.Parent.ClientState)
local UIUtil = require(script.Parent.UIUtil)
local Renderer = require(script.Parent.ProjectileRenderer)
local Poses = require(script.Parent.CharacterPoses)

local Sequence = {}

local T = UIUtil.Theme
local player = Players.LocalPlayer

local viewfinder: ScreenGui
local dropUI: ScreenGui
local scoreboard: ScreenGui

local replayToken = 0
local summary: Types.MatchSummary? = nil
local dropCards: { Types.DropCard }? = nil
local dropTotal = 0
local dropKind = "Victory"
local dropOpened = false
local dropOpening = false
local dropRequested = false
local chestBase: CFrame? = nil
local lidBase: CFrame? = nil
local playAgainDeadline = 0
local playAgainChosen = false

local function now(): number
	return Workspace:GetServerTimeNow()
end

---------------------------------------------------------------------------------------------
-- Play of the Game
---------------------------------------------------------------------------------------------
local hiddenModels: { [BasePart | Decal]: number } = {}

local function hideWorldCharacters()
	local function hide(model: Model)
		for _, d in model:GetDescendants() do
			if d:IsA("BasePart") or d:IsA("Decal") then
				hiddenModels[d] = (d :: any).LocalTransparencyModifier
				;(d :: any).LocalTransparencyModifier = 1
			end
		end
	end
	for _, p in Players:GetPlayers() do
		if p.Character then
			hide(p.Character)
		end
	end
	local runtime = Workspace:FindFirstChild("Runtime_Dynamic_Containers")
	if runtime then
		for _, name in { "AliveCharacters_Alpha", "AliveCharacters_Bravo" } do
			local f = runtime:FindFirstChild(name)
			if f then
				for _, m in f:GetChildren() do
					if m:IsA("Model") then
						hide(m)
					end
				end
			end
		end
	end
end

local function restoreWorldCharacters()
	for d, value in hiddenModels do
		if d.Parent then
			(d :: any).LocalTransparencyModifier = value
		end
	end
	table.clear(hiddenModels)
end

local function findPuppet(actorId: string): Model?
	local pool = Workspace:FindFirstChild("Arena_Maps_Pool")
	if pool == nil then
		return nil
	end
	local found = pool:FindFirstChild("Puppet_" .. actorId, true)
	return if found and found:IsA("Model") then found else nil
end

local function frameCFrame(f: Types.POTGActorFrame): CFrame
	return CFrame.new(f[2], f[3], f[4]) * CFrame.Angles(0, f[5], 0)
end

-- index of the last frame at or before t (frames are time ordered)
local function frameIndex(frames: { Types.POTGActorFrame }, t: number, hint: number): number
	local i = math.clamp(hint, 1, #frames)
	while i < #frames and frames[i + 1][1] <= t do
		i += 1
	end
	while i > 1 and frames[i][1] > t do
		i -= 1
	end
	return i
end

local function setPuppetVisible(puppet: Model, visible: boolean)
	local value = if visible then 0 else 1
	for _, d in puppet:GetDescendants() do
		if d:IsA("BasePart") or d:IsA("Decal") then
			if d.Name ~= "HumanoidRootPart" then
				(d :: any).LocalTransparencyModifier = value
			end
		end
	end
end

local function timecode(t: number): string
	local frames = math.floor((t % 1) * 60)
	return string.format("00:%02d:%02d", math.floor(t), frames)
end

local function endReplay()
	replayToken += 1
	viewfinder.Enabled = false
	UIUtil.Frame(viewfinder, "Splash").Visible = false
	restoreWorldCharacters()
	State.Cinematic = false
	local cam = Workspace.CurrentCamera
	if cam then
		cam.CameraType = Enum.CameraType.Custom
	end
end

local function playPOTG(packet: Types.POTGPacket)
	replayToken += 1
	local token = replayToken
	State.Cinematic = true
	local hud = player:FindFirstChildOfClass("PlayerGui")
	local combat = if hud then hud:FindFirstChild("CombatHUD") else nil
	if combat and combat:IsA("ScreenGui") then
		combat.Enabled = false
	end
	viewfinder.Enabled = true
	local tags = table.concat(packet.Tags, " | ")

	-- 1) splash
	local splash = UIUtil.Frame(viewfinder, "Splash")
	splash.Visible = true
	UIUtil.Label(splash, "SplashName").Text = string.upper(packet.PlayerName)
	UIUtil.Label(splash, "SplashTags").Text = tags
	local stripe = UIUtil.Frame(splash, "Stripe")
	stripe.Size = UDim2.fromScale(0, 0.004)
	UIUtil.Tween(stripe, 0.8, { Size = UDim2.fromScale(1, 0.004) }, Enum.EasingStyle.Quart)
	local title = UIUtil.Label(splash, "SplashTitle")
	title.TextTransparency = 1
	UIUtil.Tween(title, 0.5, { TextTransparency = 0 })
	SoundCatalog.Play("Fight", nil, 0)
	task.wait(2)
	if token ~= replayToken then
		return
	end
	splash.Visible = false

	-- 2) replay
	UIUtil.Label(viewfinder, "Overlay/Caption/PlayerName").Text = packet.PlayerName
	UIUtil.Label(viewfinder, "Overlay/Caption/PlayTags").Text = tags
	local puppets: { [string]: Model? } = {}
	local deadline = os.clock() + 1.5
	repeat
		for id in packet.Frames do
			if puppets[id] == nil then
				local p = findPuppet(id)
				if p then
					puppets[id] = p
					Poses.Track(p)
				end
			end
		end
		task.wait()
	until os.clock() > deadline or next(packet.Frames) == nil or (function(): boolean
		for id in packet.Frames do
			if puppets[id] == nil then
				return false
			end
		end
		return true
	end)()
	hideWorldCharacters()
	for _, puppet in puppets do
		setPuppetVisible(puppet :: Model, true)
	end

	local events = table.clone(packet.Events)
	table.sort(events, function(a, b)
		return a.T < b.T
	end)
	local nextEvent = 1
	local hints: { [string]: number } = {}
	local alive: { [string]: boolean } = {}
	local cam = Workspace.CurrentCamera :: Camera
	cam.CameraType = Enum.CameraType.Scriptable
	cam.FieldOfView = 62
	local camCF: CFrame? = nil
	local t = 0
	local duration = math.max(packet.Duration, 0.5)
	local fill = UIUtil.Frame(viewfinder, "Overlay/ReplayProgress/Fill")
	local recDot = UIUtil.Frame(viewfinder, "Overlay/Rec/RecDot")
	local tc = UIUtil.Label(viewfinder, "Overlay/Timecode")

	local done = false
	local conn: RBXScriptConnection
	conn = RunService.RenderStepped:Connect(function(dt)
		if token ~= replayToken then
			conn:Disconnect()
			return
		end
		t += dt
		-- actors
		for id, frames in packet.Frames do
			local puppet = puppets[id]
			if puppet and #frames > 0 then
				local i = frameIndex(frames, t, hints[id] or 1)
				hints[id] = i
				local a = frames[i]
				local b = frames[math.min(i + 1, #frames)]
				local span = b[1] - a[1]
				local alpha = if span > 1e-4 then math.clamp((t - a[1]) / span, 0, 1) else 0
				local cf = frameCFrame(a):Lerp(frameCFrame(b), alpha)
				puppet:PivotTo(cf)
				local flags = a[7]
				local isAlive = bit32.band(flags, 1) ~= 0
				if alive[id] ~= isAlive then
					alive[id] = isAlive
					setPuppetVisible(puppet, isAlive)
				end
				puppet:SetAttribute("Blocking", bit32.band(flags, 2) ~= 0)
				puppet:SetAttribute("Sliding", bit32.band(flags, 4) ~= 0)
				puppet:SetAttribute("DrawRatio", if bit32.band(flags, 8) ~= 0 then 1 else 0)
				puppet:SetAttribute("Pitch", a[6] + (b[6] - a[6]) * alpha)
			end
		end
		-- events
		while nextEvent <= #events and events[nextEvent].T <= t do
			local e = events[nextEvent]
			nextEvent += 1
			local puppet = puppets[e.ActorId]
			if e.Kind == "Equip" and puppet and e.WeaponId then
				EquipmentRig.EquipHeld(puppet, e.WeaponId)
				puppet:SetAttribute("EquippedItem", e.WeaponId)
			elseif e.Kind == "Shot" and e.Origin and e.Velocity then
				Renderer.Spawn({
					OwnerId = "POTG",
					ItemId = e.WeaponId or "WoodBow",
					Origin = e.Origin,
					Velocity = e.Velocity,
					GravityScale = e.Gravity or 0,
					MaxAge = 3,
				})
				if puppet then
					puppet:SetAttribute("LastShotAt", now())
				end
			elseif e.Kind == "Swing" and puppet then
				puppet:SetAttribute("SwingAt", now())
				SoundCatalog.Play("SwingLight", puppet.PrimaryPart, 0.1)
			elseif e.Kind == "Hit" and e.Position then
				VFX.Burst("HitSpark_Normal", CFrame.new(e.Position))
			elseif e.Kind == "Kill" and e.Position then
				VFX.Burst("SkullBurst", CFrame.new(e.Position + Vector3.new(0, 2, 0)))
				SoundCatalog.Play("Kill", nil, 0)
			end
		end
		-- camera on the featured player's shoulder
		local hero = puppets[packet.ActorId]
		local heroFrames = packet.Frames[packet.ActorId]
		if hero and heroFrames and #heroFrames > 0 then
			local i = hints[packet.ActorId] or 1
			local f = heroFrames[i]
			local root = hero.PrimaryPart
			local pos = if root then root.Position else Vector3.new(f[2], f[3], f[4])
			local rotation = CFrame.Angles(0, f[5], 0) * CFrame.Angles(math.clamp(f[6], -1, 1) * 0.8 - 0.08, 0, 0)
			local orbit = math.sin(t * 0.35) * 0.6
			local target = CFrame.new(pos + Vector3.new(0, 1.8, 0)) * rotation * CFrame.new(2.8 + orbit, 1.2, 8.5)
			camCF = if camCF then (camCF :: CFrame):Lerp(target, math.min(dt * 6, 1)) else target
			cam.CFrame = camCF :: CFrame
		end
		-- overlay
		fill.Size = UDim2.fromScale(math.clamp(t / duration, 0, 1), 1)
		recDot.Visible = math.floor(t * 2) % 2 == 0
		tc.Text = timecode(t)
		if t >= duration + 0.4 then
			done = true
			conn:Disconnect()
		end
	end)
	while not done and token == replayToken do
		task.wait(0.1)
	end
	if token == replayToken then
		endReplay()
	end
end

---------------------------------------------------------------------------------------------
-- Victory Drop
---------------------------------------------------------------------------------------------
local function chest(): Model?
	local vp = dropUI:FindFirstChild("ChestViewport")
	local world = if vp then vp:FindFirstChildOfClass("WorldModel") else nil
	local c = if world then world:FindFirstChild("Chest") else nil
	return if c and c:IsA("Model") then c else nil
end

local function resetChest()
	local c = chest()
	if c == nil then
		return
	end
	if chestBase == nil then
		chestBase = c:GetPivot()
	end
	local lid = c:FindFirstChild("Lid")
	if lid and lid:IsA("Model") then
		if lidBase == nil then
			lidBase = lid:GetPivot()
		end
		lid:PivotTo(lidBase :: CFrame)
	end
	c:PivotTo(chestBase :: CFrame)
end

local function resetCards()
	for i = 1, 4 do
		local card = UIUtil.Frame(dropUI, "Cards/Card" .. i)
		card.Visible = true
		local back = UIUtil.Frame(card, "Back")
		local front = UIUtil.Frame(card, "Front")
		back.Visible = true
		back.AnchorPoint = Vector2.new(0.5, 0.5)
		back.Position = UDim2.fromScale(0.5, 0.5)
		back.Size = UDim2.fromScale(1, 1)
		front.Visible = false
		front.AnchorPoint = Vector2.new(0.5, 0.5)
		front.Position = UDim2.fromScale(0.5, 0.5)
		front.Size = UDim2.fromScale(1, 1)
		UIUtil.Frame(front, "UpgradeReady").Visible = false
		local stroke = card:FindFirstChild("RarityStroke")
		if stroke and stroke:IsA("UIStroke") then
			stroke.Color = T.Gold
		end
	end
	UIUtil.Label(dropUI, "TotalShards").Text = ""
	UIUtil.Button(dropUI, "ContinueButton").Visible = false
end

local function fillCard(i: number, card: Types.DropCard)
	local frame = UIUtil.Frame(dropUI, "Cards/Card" .. i)
	local front = UIUtil.Frame(frame, "Front")
	local spec = EquipmentDatabase.Get(card.ItemId)
	UIUtil.Label(front, "Glyph").Text = UIUtil.Glyph(card.ItemId)
	UIUtil.Label(front, "ItemName").Text = (if card.NewUnlock then "NEW! " else "") .. (if spec then spec.DisplayName else card.ItemId)
	UIUtil.Label(front, "Shards").Text = "+" .. card.Shards
	local profile = State.Profile
	local have = if profile then (profile.Shards[card.ItemId] or 0) else card.Shards
	local level = if profile then profile.UnlockedItems[card.ItemId] else nil
	local need: number? = nil
	if level == nil then
		need = if spec then spec.UnlockShards else nil
	else
		need = UpgradeScalingMath.ShardsForNextLevel(level)
	end
	UIUtil.Label(front, "ShardProgress").Text = if need then string.format("%d / %d", have, need) else "MAX LEVEL"
	UIUtil.SetFill(UIUtil.Frame(front, "ShardBar/Fill"), if need and need > 0 then have / need else 1, 0.6)
	UIUtil.Frame(front, "UpgradeReady").Visible = card.UpgradeReady
	local stroke = frame:FindFirstChild("RarityStroke")
	if stroke and stroke:IsA("UIStroke") then
		stroke.Color = UIUtil.RarityColor(spec)
	end
end

local function flipCard(i: number)
	local frame = UIUtil.Frame(dropUI, "Cards/Card" .. i)
	local back = UIUtil.Frame(frame, "Back")
	local front = UIUtil.Frame(frame, "Front")
	SoundCatalog.Play("CardFlip", nil, 0.05)
	local close = UIUtil.Tween(back, 0.14, { Size = UDim2.fromScale(0, 1) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	close.Completed:Wait()
	back.Visible = false
	front.Visible = true
	front.Size = UDim2.fromScale(0, 1)
	UIUtil.Tween(front, 0.18, { Size = UDim2.fromScale(1, 1) }, Enum.EasingStyle.Back)
	local ready = UIUtil.Frame(front, "UpgradeReady")
	if ready.Visible then
		ready.Size = UDim2.fromScale(1.2, 0.14)
		UIUtil.Tween(ready, 0.35, { Size = UDim2.fromScale(0.9, 0.1) }, Enum.EasingStyle.Elastic)
	end
end

local function openSequence()
	local cards = dropCards
	if cards == nil or dropOpened then
		return
	end
	dropOpened = true
	local c = chest()
	local sub = UIUtil.Label(dropUI, "SubHeader")
	-- shake x3 -> x2 -> x1, harder each time
	for n = 3, 1, -1 do
		sub.Text = "x" .. n
		sub.TextColor3 = T.Gold
		SoundCatalog.Play("ChestShake", nil, 0.05)
		local strength = (4 - n) * 0.06
		local start = os.clock()
		while os.clock() - start < 0.42 do
			if c and chestBase then
				local s = math.sin((os.clock() - start) * 60) * strength
				c:PivotTo((chestBase :: CFrame) * CFrame.Angles(0, 0, s) * CFrame.new(0, math.abs(s) * 0.8, 0))
			end
			task.wait()
		end
		if c and chestBase then
			c:PivotTo(chestBase :: CFrame)
		end
		task.wait(0.12)
	end
	-- burst open
	SoundCatalog.Play("ChestOpen", nil, 0)
	sub.Text = if dropKind == "Golden" then "GOLDEN DROP!" else "REWARDS"
	local lid = if c then c:FindFirstChild("Lid") else nil
	if lid and lid:IsA("Model") and lidBase then
		local start = os.clock()
		while os.clock() - start < 0.35 do
			local a = math.clamp((os.clock() - start) / 0.35, 0, 1)
			local eased = 1 - (1 - a) ^ 3
			lid:PivotTo((lidBase :: CFrame) * CFrame.Angles(math.rad(110) * eased, 0, 0))
			task.wait()
		end
		lid:PivotTo((lidBase :: CFrame) * CFrame.Angles(math.rad(110), 0, 0))
	end
	-- cards
	for i = 1, 4 do
		local card = cards[i]
		local frame = UIUtil.Frame(dropUI, "Cards/Card" .. i)
		if card then
			fillCard(i, card)
			task.wait(0.25)
			flipCard(i)
		else
			frame.Visible = false
		end
	end
	-- total
	local total = UIUtil.Label(dropUI, "TotalShards")
	local shown = 0
	while shown < dropTotal do
		shown = math.min(dropTotal, shown + math.max(1, math.ceil(dropTotal / 20)))
		total.Text = string.format("TOTAL +%d SHARDS", shown)
		task.wait(0.03)
	end
	total.Text = string.format("TOTAL +%d SHARDS", dropTotal)
	for _, card in cards do
		if card.UpgradeReady then
			total.Text ..= "  ·  UPGRADE READY"
			break
		end
	end
	UIUtil.Button(dropUI, "ContinueButton").Visible = true
end

local function requestOpen()
	if dropOpened or dropOpening then
		return
	end
	dropOpening = true
	if dropCards then
		task.spawn(openSequence)
	elseif not dropRequested then
		dropRequested = true
		Net.Reliable("OpenVictoryChest"):FireServer()
	end
end

local function showDrop(kind: string, won: boolean)
	dropKind = kind
	dropOpened = false
	dropOpening = false
	dropRequested = false
	resetChest()
	resetCards()
	State.Cinematic = true
	dropUI.Enabled = true
	local header = UIUtil.Label(dropUI, "Header")
	if kind == "Golden" then
		header.Text = "GOLDEN DROP"
		header.TextColor3 = T.Gold
	else
		header.Text = if won then "VICTORY" else "DEFEAT"
		header.TextColor3 = if won then T.Gold else T.Bad
	end
	local sub = UIUtil.Label(dropUI, "SubHeader")
	sub.Text = "Tap the chest to open"
	sub.TextColor3 = T.SubText
	local glow = chest()
	local g = if glow then glow:FindFirstChild("Glow") else nil
	if g and g:IsA("BasePart") then
		g.Color = if kind == "Golden" then Color3.fromRGB(255, 200, 40) else Color3.fromRGB(255, 220, 120)
	end
	-- auto-open so the scoreboard is always reachable before the play-again timer runs out
	task.delay(6, function()
		if dropUI.Enabled and not dropOpened then
			requestOpen()
		end
	end)
	-- idle bob while waiting
	task.spawn(function()
		local c = chest()
		while dropUI.Enabled and not dropOpened and not dropOpening do
			if c and chestBase then
				c:PivotTo((chestBase :: CFrame) * CFrame.new(0, math.sin(os.clock() * 2) * 0.08, 0) * CFrame.Angles(0, math.sin(os.clock()) * 0.06, 0))
			end
			task.wait()
		end
	end)
end

local function onChestReply(payload: any)
	if type(payload) ~= "table" or type(payload.Cards) ~= "table" then
		return
	end
	dropCards = payload.Cards
	dropTotal = if type(payload.Total) == "number" then payload.Total else 0
	if payload.Kind == "Golden" and not dropUI.Enabled then
		-- purchased from the lobby: show the drop on its own
		showDrop("Golden", true)
		return
	end
	if dropOpening and not dropOpened then
		task.spawn(openSequence)
	end
end

---------------------------------------------------------------------------------------------
-- Scoreboard
---------------------------------------------------------------------------------------------
local function fillRow(row: Instance, r: Types.RosterEntry?, glory: string, me: boolean)
	local frame = row :: GuiObject
	frame.Visible = r ~= nil
	if r == nil then
		return
	end
	UIUtil.Label(row, "Name").Text = (if me then "▶ " else "") .. r.Name .. (if r.IsBot then " [BOT]" else "")
	UIUtil.Label(row, "K").Text = tostring(r.Kills)
	UIUtil.Label(row, "D").Text = tostring(r.Deaths)
	UIUtil.Label(row, "A").Text = tostring(r.Assists)
	UIUtil.Label(row, "DMG").Text = tostring(r.Damage)
	UIUtil.Label(row, "Glory").Text = glory
	local stroke = row:FindFirstChild("MeStroke")
	if me and stroke == nil then
		local s = Instance.new("UIStroke")
		s.Name = "MeStroke"
		s.Color = T.Gold
		s.Thickness = 2
		s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		s.Parent = row
	elseif not me and stroke then
		stroke:Destroy()
	end
end

local function animateXP(s: Types.MatchSummary)
	local lines = UIUtil.Get(scoreboard, "Modal/XPBreakdown/Lines")
	UIUtil.ClearClones(lines)
	local template = UIUtil.Label(lines, "LineTemplate")
	local fill = UIUtil.Frame(scoreboard, "Modal/XPBreakdown/XPBar/Fill")
	local label = UIUtil.Label(scoreboard, "Modal/XPBreakdown/XPLabel")
	local beforeNeed = UpgradeScalingMath.XPForLevel(s.LevelBefore)
	UIUtil.SetFill(fill, s.XPBefore / math.max(beforeNeed, 1))
	label.Text = string.format("LV %d  %d / %d XP", s.LevelBefore, s.XPBefore, beforeNeed)
	task.spawn(function()
		local total = 0
		for i, line in s.XPBreakdown do
			if line.Amount ~= 0 then
				local l = UIUtil.CloneTemplate(template, "Line" .. i)
				l.LayoutOrder = i
				l.Text = string.format('<font color="#FFC83C">+%d</font>  %s', line.Amount, line.Label)
				l.TextTransparency = 1
				UIUtil.Tween(l, 0.25, { TextTransparency = 0 })
				total += line.Amount
				task.wait(0.25)
			end
		end
		if s.LevelAfter > s.LevelBefore then
			UIUtil.SetFill(fill, 1, 0.5)
			task.wait(0.55)
			label.Text = string.format("LEVEL UP!  LV %d", s.LevelAfter)
			label.TextColor3 = T.Gold
			SoundCatalog.Play("UIConfirm", nil, 0)
			fill.Size = UDim2.fromScale(0, 1)
			task.wait(0.3)
		end
		UIUtil.SetFill(fill, s.XPAfter / math.max(s.XPNeeded, 1), 0.7)
		task.wait(0.75)
		label.TextColor3 = T.SubText
		label.Text = string.format("LV %d  %d / %d XP  (+%d)", s.LevelAfter, s.XPAfter, s.XPNeeded, total)
	end)
end

local function showScoreboard()
	local s = summary
	dropUI.Enabled = false
	if s == nil then
		State.Cinematic = false
		return
	end
	State.Cinematic = true
	scoreboard.Enabled = true
	local mine = State.MyTeam()
	local won = s.WinningTeam == mine
	local result = UIUtil.Label(scoreboard, "Modal/ResultLabel")
	result.Text = if won then "VICTORY" else "DEFEAT"
	result.TextColor3 = if won then T.Gold else T.Bad
	UIUtil.Label(scoreboard, "Modal/FinalScore").Text = string.format("%d - %d", s.Score.Alpha, s.Score.Bravo)
	for _, team in { "Alpha", "Bravo" } do
		local list: { Types.RosterEntry } = {}
		for _, r in s.Roster do
			if r.Team == team then
				table.insert(list, r)
			end
		end
		table.sort(list, function(a, b)
			if a.Kills ~= b.Kills then
				return a.Kills > b.Kills
			end
			return a.Damage > b.Damage
		end)
		for i = 1, 3 do
			local r = list[i]
			local me = r ~= nil and r.UserId == player.UserId
			local glory = if me then (if s.GloryDelta > 0 then "+" .. s.GloryDelta elseif s.GloryDelta < 0 then tostring(s.GloryDelta) else "—") else "—"
			fillRow(UIUtil.Get(scoreboard, string.format("Modal/Tables/%sRow%d", team, i)), r, glory, me)
		end
	end
	local mvp: Types.RosterEntry? = nil
	for _, r in s.Roster do
		if r.Id == s.MvpId then
			mvp = r
		end
	end
	UIUtil.Label(scoreboard, "Modal/MVPCard/MVPName").Text = if mvp then mvp.Name else "—"
	UIUtil.Label(scoreboard, "Modal/MVPCard/MVPStats").Text = if mvp then string.format("%d K  /  %d D  /  %d A  ·  %d DMG", mvp.Kills, mvp.Deaths, mvp.Assists, mvp.Damage) else ""
	UIUtil.Label(scoreboard, "Modal/MVPCard/MVPWeapon").Text = if mvp then string.upper(mvp.Team) .. (if mvp.UserId == player.UserId then " · THAT'S YOU!" else "") else ""
	animateXP(s)
	local round = State.Round
	playAgainDeadline = if round and round.Phase == "VictoryDropAndSummary" then round.PhaseEndsAt else now() + s.PlayAgainSeconds
end

local function closeAll()
	replayToken += 1
	viewfinder.Enabled = false
	dropUI.Enabled = false
	scoreboard.Enabled = false
	restoreWorldCharacters()
	State.Cinematic = false
	summary = nil
	dropCards = nil
	playAgainChosen = false
end

---------------------------------------------------------------------------------------------
function Sequence.Init()
	viewfinder = UIUtil.Gui("POTGViewfinder")
	dropUI = UIUtil.Gui("VictoryDropUI")
	scoreboard = UIUtil.Gui("ScoreboardSummaryUI")
end

function Sequence.Start()
	viewfinder.Enabled = false
	dropUI.Enabled = false
	scoreboard.Enabled = false

	UIUtil.Button(viewfinder, "SkipButton").Activated:Connect(function()
		UIUtil.Click()
		endReplay()
	end)
	UIUtil.Button(dropUI, "ChestViewport/OpenChestButton").Activated:Connect(requestOpen)
	UIUtil.Button(dropUI, "ContinueButton").Activated:Connect(function()
		UIUtil.Click()
		if dropKind == "Golden" and summary == nil then
			dropUI.Enabled = false
			State.Cinematic = false
			dropCards = nil
		else
			showScoreboard()
		end
	end)
	local playAgain = UIUtil.Button(scoreboard, "Modal/Buttons/PlayAgainButton")
	playAgain.Activated:Connect(function()
		UIUtil.Click()
		playAgainChosen = true
		Net.Reliable("QueueAction"):FireServer("PlayAgain")
	end)
	UIUtil.Button(scoreboard, "Modal/Buttons/LobbyButton").Activated:Connect(function()
		UIUtil.Click()
		Net.Reliable("QueueAction"):FireServer("Lobby")
		scoreboard.Enabled = false
		State.Cinematic = false
	end)

	Net.Reliable("BroadcastPOTGData").OnClientEvent:Connect(function(packet: any, _origin: any)
		if type(packet) == "table" and type(packet.Frames) == "table" and type(packet.Events) == "table" then
			task.spawn(playPOTG, packet :: Types.POTGPacket)
		end
	end)
	Net.Reliable("MatchSummary").OnClientEvent:Connect(function(s: any)
		if type(s) ~= "table" or type(s.Roster) ~= "table" then
			return
		end
		summary = s :: Types.MatchSummary
		playAgainChosen = false
		dropCards = nil
		if viewfinder.Enabled then
			endReplay()
		end
		local mine = State.MyTeam()
		showDrop("Victory", (s :: Types.MatchSummary).WinningTeam == mine)
	end)
	Net.Reliable("OpenVictoryChest").OnClientEvent:Connect(onChestReply)
	State.RoundChanged:Connect(function(round: Types.RoundState?)
		if round == nil then
			closeAll()
		elseif round.Phase ~= "POTGReplay" and viewfinder.Enabled then
			endReplay()
		end
	end)

	RunService.Heartbeat:Connect(function()
		if scoreboard.Enabled then
			local left = math.max(0, math.ceil(playAgainDeadline - now()))
			playAgain.Text = if playAgainChosen then string.format("QUEUED ✓ (%ds)", left) else string.format("PLAY AGAIN (%ds)", left)
			playAgain.BackgroundColor3 = if playAgainChosen then T.Gold else T.Good
		end
	end)
end

return Sequence
