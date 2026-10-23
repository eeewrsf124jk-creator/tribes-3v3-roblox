--!strict
-- RoundStateMachineService: Best of 5 (first to 3) match loop.
--   Phase 1 PreMatchVS (6 s)        VS splash, characters spawn on their team pads
--   Phase 2 PreRoundLoadout (5 s)   frozen behind the spawn barrier, 5..1..FIGHT countdown,
--                                   [B] preset switching allowed (SwitchPresetInPreRound)
--   Phase 3 ActiveCombat            elimination check every 0.1 s; after 60 s the Ring of Fire
--                                   shrinks 180 -> 0 studs over 30 s (10 dmg / 0.5 s outside)
--   Phase 4 RoundEndBanner (4 s)    ROUND WON/LOST + FLAWLESS / ACE / TEAM ACE tags
--   Phase 5 POTGReplay (8 s)        once a team reaches 3 wins: best highlight broadcast
--   Phase 6 VictoryDropAndSummary   chest drop, XP / streak / MVP settlement, PLAY AGAIN (25 s)

local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local ServerStorage = game:GetService("ServerStorage")
local Teams = game:GetService("Teams")
local Workspace = game:GetService("Workspace")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")

local Modules = game:GetService("ReplicatedStorage"):WaitForChild("Modules")
local Types = require(Modules.Shared.Types)
local Net = require(Modules.Shared.Net)
local Signal = require(Modules.Shared.Signal)
local Janitor = require(Modules.Shared.Janitor)
local GameConfig = require(Modules.Config.GameConfig)
local LoadoutBudgetValidator = require(Modules.Shared.LoadoutBudgetValidator)

local PlayerData = require(script.Parent.PlayerDataService)
local Combat = require(script.Parent.LagCompensatedCombatService)
local Recorder = require(script.Parent.POTGRecorderAndScorer)
local Economy = require(script.Parent.EconomyAndMonetizationService)
local Agent = require(script.Parent.Bots.TacticalBotAgent)

local Registry = require(script.Parent.Combat.CombatantRegistry)
local DamageModel = require(script.Parent.Combat.DamageModel)

type Combatant = Registry.Combatant
type TeamName = Types.TeamName

local Round = {}

export type MatchMode = "1v1" | "2v2" | "3v3"
export type MatchKind = "Queue" | "Custom" | "Practice"

export type PlayerEntry = { Player: Player, Team: TeamName }

export type MatchSpec = {
	Mode: MatchMode,
	Kind: MatchKind,
	Ranked: boolean,
	FillBots: boolean,
	Players: { PlayerEntry },
	MapName: string?,
}

export type Member = {
	Id: string,
	Player: Player?,
	Team: TeamName,
	IsBot: boolean,
	Name: string,
	UserId: number,
	Combatant: Combatant?,
	Brain: Agent.Brain?,
	PresetIndex: number,
	Loadout: Types.Loadout,
	Left: boolean,
	PlayAgain: boolean,
	Spawning: boolean,
	RoundKills: number,
	RoundDeaths: number,
}

-- structural view of Janitor (avoids generic-method invariance when Match values are compared)
type JanitorLike = {
	Add: (self: any, item: any, key: string?) -> any,
	Cleanup: (self: any) -> (),
}

export type Match = {
	Id: string,
	Spec: MatchSpec,
	Context: string,
	TeamSize: number,
	MapName: string,
	Map: Model?,
	Origin: CFrame,
	Slot: number,
	Members: { Member },
	Phase: Types.RoundPhase,
	PhaseEndsAt: number,
	Round: number,
	Score: { Alpha: number, Bravo: number },
	RingActive: boolean,
	RingShrinkStartsAt: number,
	RingCenter: Vector3,
	CombatStartedAt: number,
	Banner: string?,
	BannerTags: { string }?,
	RoundWinner: TeamName?,
	WinningTeam: TeamName?,
	Dirty: boolean,
	Running: boolean,
	Janitor: JanitorLike,
}

Round.MatchEnded = Signal.new() :: Signal.Signal<Match, { Player }>
-- Lobby-place hook: put a player back into the lobby after a local match.
Round.ReturnToLobby = function(player: Player)
	player:LoadCharacterAsync()
end

local matches: { [string]: Match } = {}
local usedSlots: { [number]: boolean } = {}
local rng = Random.new()

local MAP_NAMES = {
	"Map_01_WinterTimberFort",
	"Map_02_DesertColosseum",
	"Map_03_HighlandHenge",
	"Map_04_IcefallFjord",
}

local function now(): number
	return Workspace:GetServerTimeNow()
end

local function teamSizeFor(mode: MatchMode): number
	return if mode == "1v1" then 1 elseif mode == "2v2" then 2 else 3
end

function Round.EnsureTeams()
	for _, data in { { Name = "Alpha", Color = BrickColor.new("Bright blue") }, { Name = "Bravo", Color = BrickColor.new("Bright red") } } do
		if Teams:FindFirstChild(data.Name) == nil then
			local team = Instance.new("Team")
			team.Name = data.Name
			team.TeamColor = data.Color
			team.AutoAssignable = false
			team.Parent = Teams
		end
	end
end

local function teamInstance(team: TeamName): Team?
	local t = Teams:FindFirstChild(team)
	if t and t:IsA("Team") then
		return t
	end
	return nil
end

---------------------------------------------------------------------------------------------
-- State broadcast
---------------------------------------------------------------------------------------------
local function roster(match: Match): { Types.RosterEntry }
	local list: { Types.RosterEntry } = {}
	for _, m in match.Members do
		local c = m.Combatant
		table.insert(list, {
			Id = m.Id,
			Name = m.Name,
			UserId = m.UserId,
			Team = m.Team,
			IsBot = m.IsBot,
			Kills = if c then c.Stats.Kills else 0,
			Deaths = if c then c.Stats.Deaths else 0,
			Assists = if c then c.Stats.Assists else 0,
			Damage = if c then math.floor(c.Stats.Damage) else 0,
			Alive = c ~= nil and c.Alive,
		})
	end
	return list
end

local function ringRadius(match: Match): number
	if not match.RingActive or match.RingShrinkStartsAt == 0 then
		return GameConfig.Ring.StartRadius
	end
	local a = math.clamp((now() - match.RingShrinkStartsAt) / GameConfig.Ring.ShrinkDuration, 0, 1)
	return GameConfig.Ring.StartRadius + (GameConfig.Ring.EndRadius - GameConfig.Ring.StartRadius) * a
end

function Round.State(match: Match): Types.RoundState
	return {
		MatchId = match.Id,
		Mode = match.Spec.Mode,
		Kind = match.Spec.Kind,
		Phase = match.Phase,
		PhaseEndsAt = match.PhaseEndsAt,
		Round = match.Round,
		Score = { Alpha = match.Score.Alpha, Bravo = match.Score.Bravo },
		MapName = match.MapName,
		Roster = roster(match),
		Banner = match.Banner,
		WinningTeam = match.WinningTeam,
		RingRadius = ringRadius(match),
		RingActive = match.RingActive,
		RingCenter = match.RingCenter,
		RingShrinkStartsAt = match.RingShrinkStartsAt,
		RingShrinkDuration = GameConfig.Ring.ShrinkDuration,
		RingStartRadius = GameConfig.Ring.StartRadius,
		BannerTags = match.BannerTags,
		RoundWinner = match.RoundWinner,
	}
end

local function memberPlayers(match: Match): { Player }
	local list: { Player } = {}
	for _, m in match.Members do
		if m.Player and not m.Left and m.Player.Parent == Players then
			table.insert(list, m.Player)
		end
	end
	return list
end

Round.MemberPlayers = memberPlayers

local function broadcast(match: Match)
	match.Dirty = false
	local state = Round.State(match)
	local remote = Net.Reliable("RoundStateChanged")
	for _, p in memberPlayers(match) do
		remote:FireClient(p, state)
	end
end

local function setPhase(match: Match, phase: Types.RoundPhase, duration: number)
	match.Phase = phase
	match.PhaseEndsAt = now() + duration
	broadcast(match)
end

---------------------------------------------------------------------------------------------
-- Map
---------------------------------------------------------------------------------------------
local function allocateSlot(): number
	if GameConfig.GetPlaceRole() == "Arena" then
		return 0
	end
	local i = 1
	while usedSlots[i] do
		i += 1
	end
	usedSlots[i] = true
	return i
end

local function applyMapLighting(map: Model)
	if GameConfig.GetPlaceRole() ~= "Arena" then
		return -- the lobby keeps its own lighting while practice matches run far away
	end
	local clock = map:GetAttribute("ClockTime")
	local ambient = map:GetAttribute("Ambient")
	local fogColor = map:GetAttribute("FogColor")
	local fogEnd = map:GetAttribute("FogEnd")
	local density = map:GetAttribute("AtmosphereDensity")
	if type(clock) == "number" then
		Lighting.ClockTime = clock
	end
	if typeof(ambient) == "Color3" then
		Lighting.OutdoorAmbient = ambient
	end
	if typeof(fogColor) == "Color3" then
		Lighting.FogColor = fogColor
	end
	if type(fogEnd) == "number" then
		Lighting.FogEnd = fogEnd
	end
	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
	if atmosphere == nil then
		atmosphere = Instance.new("Atmosphere")
		atmosphere.Parent = Lighting
	end
	if type(density) == "number" and atmosphere then
		atmosphere.Density = density
		if typeof(fogColor) == "Color3" then
			atmosphere.Color = fogColor
		end
	end
end

local function loadMap(match: Match): boolean
	local storage = ServerStorage:FindFirstChild("ArenaMapStorage")
	local pool = Workspace:FindFirstChild("Arena_Maps_Pool")
	if storage == nil or pool == nil then
		warn("[Round] arena maps are not built")
		return false
	end
	local source = storage:FindFirstChild(match.MapName)
	if source == nil or not source:IsA("Model") then
		warn("[Round] missing map", match.MapName)
		return false
	end
	if GameConfig.GetPlaceRole() == "Arena" then
		pool:ClearAllChildren()
	end
	local map = source:Clone()
	map.Name = match.MapName .. "_" .. match.Id
	map:PivotTo(match.Origin * map:GetPivot())
	map.Parent = pool
	match.Map = map
	match.RingCenter = match.Origin.Position
	match.Janitor:Add(map, "Map")
	applyMapLighting(map)
	return true
end

local function spawnPad(match: Match, team: TeamName, index: number): CFrame
	local map = match.Map
	local pads: { BasePart } = {}
	if map then
		for _, d in map:GetDescendants() do
			if d:IsA("BasePart") and d:HasTag("ArenaSpawnPad") and d:GetAttribute("Team") == team then
				table.insert(pads, d)
			end
		end
	end
	table.sort(pads, function(a, b)
		return (a:GetAttribute("SpawnIndex") :: number? or 0) < (b:GetAttribute("SpawnIndex") :: number? or 0)
	end)
	if #pads == 0 then
		local z = if team == "Alpha" then -120 else 120
		return match.Origin * CFrame.lookAt(Vector3.new(index * 6 - 12, 4, z), Vector3.new(index * 6 - 12, 4, 0))
	end
	local pad = pads[((index - 1) % #pads) + 1]
	local facing = pad:GetAttribute("Facing")
	local pos = pad.Position + Vector3.new(0, 3.2, 0)
	if typeof(facing) == "Vector3" then
		return CFrame.lookAt(pos, pos + Vector3.new((facing :: Vector3).X, 0, (facing :: Vector3).Z))
	end
	return CFrame.new(pos)
end

local function setBarriers(match: Match, closed: boolean)
	local map = match.Map
	if map == nil then
		return
	end
	for _, d in map:GetDescendants() do
		if d:IsA("BasePart") and d:HasTag("SpawnBarrier") then
			d.CanCollide = closed
			d.Transparency = if closed then 0.3 else 1
		end
	end
end

local function setRingVisual(match: Match, active: boolean)
	local map = match.Map
	if map == nil then
		return
	end
	local ring = map:FindFirstChild("RingOfFire_BoundaryCylinder", true)
	if ring then
		ring:SetAttribute("Active", active)
		ring:SetAttribute("ShrinkStartsAt", match.RingShrinkStartsAt)
		local wall = ring:FindFirstChild("FireWall")
		if wall and wall:IsA("BasePart") then
			wall.Transparency = if active then 0.15 else 1
			local h = GameConfig.Ring.Height
			wall.Size = Vector3.new(h, GameConfig.Ring.StartRadius * 2, GameConfig.Ring.StartRadius * 2)
		end
	end
end

---------------------------------------------------------------------------------------------
-- Members, bodies and loadouts
---------------------------------------------------------------------------------------------
local function levelLookup(player: Player?): (string) -> number
	local profile = if player then PlayerData.Get(player) else nil
	return function(itemId: string): number
		return PlayerData.ItemLevel(profile, itemId)
	end
end

local function presetFor(member: Member): Types.Loadout
	local player = member.Player
	if player then
		local profile = PlayerData.Get(player)
		if profile then
			local loadout = profile.Presets[member.PresetIndex] or profile.Presets[1]
			if loadout and LoadoutBudgetValidator.Validate(loadout, PlayerData.UnlockTable(profile)).Ok then
				return loadout
			end
		end
	end
	return member.Loadout
end

local function newBotBody(match: Match, member: Member): Model
	local body = Agent.BuildBody(member.Name, member.Team, rng)
	local runtime = Workspace:FindFirstChild("Runtime_Dynamic_Containers")
	local folder = if runtime then runtime:FindFirstChild("AliveCharacters_" .. member.Team) else nil
	body.Parent = folder or Workspace
	local root = body:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		root:SetNetworkOwner(nil)
	end
	match.Janitor:Add(body, "Body_" .. member.Id)
	return body
end

-- (Re)spawn one member at their pad with a fresh body, armed with their current preset.
local function spawnMember(match: Match, member: Member, index: number)
	if member.Left then
		return
	end
	local cf = spawnPad(match, member.Team, index)
	local c: Combatant? = nil
	if member.IsBot then
		local body = newBotBody(match, member)
		local existing = member.Combatant
		if existing == nil then
			local created = Registry.New(member.Id, member.Name, member.Team, match.Context)
			created.IsBot = true
			member.Combatant = created
			Registry.BindCharacter(created, body)
			Registry.Add(created)
			member.Brain = Agent.New(created, rng:NextNumber(0.35, 0.8))
			c = created
		else
			Registry.BindCharacter(existing, body)
			c = existing
		end
		Combat.WatchCharacter(c :: Combatant)
	else
		local player = member.Player
		if player == nil or player.Parent ~= Players then
			member.Left = true
			return
		end
		member.Spawning = true
		local team = teamInstance(member.Team)
		if team then
			player.Team = team
		end
		player:LoadCharacterAsync()
		member.Spawning = false
		local character = player.Character
		if character == nil then
			return
		end
		local existing = member.Combatant
		if existing == nil then
			c = Combat.AddPlayer(player, member.Team, match.Context)
			member.Combatant = c
		else
			Registry.BindCharacter(existing, character)
			Combat.WatchCharacter(existing)
			c = existing
		end
	end
	if c == nil then
		return
	end
	member.Loadout = presetFor(member)
	Combat.Arm(c, member.Loadout, levelLookup(member.Player))
	Combat.SpawnAt(c, cf)
end

local function spawnAll(match: Match)
	local counters = { Alpha = 0, Bravo = 0 }
	for _, m in match.Members do
		local n = if m.Team == "Alpha" then counters.Alpha + 1 else counters.Bravo + 1
		if m.Team == "Alpha" then
			counters.Alpha = n
		else
			counters.Bravo = n
		end
		m.RoundKills = 0
		m.RoundDeaths = 0
		task.spawn(spawnMember, match, m, n)
	end
	-- LoadCharacter yields per player; wait until every body exists (bounded)
	local deadline = os.clock() + 6
	while os.clock() < deadline do
		local ready = true
		for _, m in match.Members do
			if not m.Left and (m.Combatant == nil or not (m.Combatant :: Combatant).Alive) then
				ready = false
			end
		end
		if ready then
			break
		end
		task.wait(0.1)
	end
end

-- Hold a member that respawned outside our control (lobby auto-respawn) in their spawn room.
local function parkSpectator(match: Match, member: Member, character: Model)
	task.defer(function()
		local root = character:WaitForChild("HumanoidRootPart", 5)
		if root and root:IsA("BasePart") then
			character:PivotTo(spawnPad(match, member.Team, 1) * CFrame.new(0, 0, 6))
			root.Anchored = true
		end
	end)
end

---------------------------------------------------------------------------------------------
-- Round evaluation
---------------------------------------------------------------------------------------------
local function aliveCounts(match: Match): (number, number)
	local a, b = 0, 0
	for _, m in match.Members do
		local c = m.Combatant
		if c and c.Alive and not m.Left then
			if m.Team == "Alpha" then
				a += 1
			else
				b += 1
			end
		end
	end
	return a, b
end

local function teamDamage(match: Match, team: TeamName): number
	local total = 0
	for _, m in match.Members do
		if m.Team == team and m.Combatant then
			total += (m.Combatant :: Combatant).Stats.Damage
		end
	end
	return total
end

local function bannerTags(match: Match, winner: TeamName): { string }
	local tags: { string } = {}
	local deaths = 0
	local everyoneScored = true
	local ace = false
	local winners = 0
	for _, m in match.Members do
		if m.Team == winner and not m.Left then
			winners += 1
			deaths += m.RoundDeaths
			if m.RoundKills == 0 then
				everyoneScored = false
			end
			if m.RoundKills >= math.max(2, match.TeamSize) and match.TeamSize >= 2 then
				ace = true
			end
		end
	end
	if deaths == 0 then
		table.insert(tags, "FLAWLESS")
	end
	if ace then
		table.insert(tags, "ACE")
	end
	if everyoneScored and winners >= 2 then
		table.insert(tags, "TEAM ACE")
	end
	return tags
end

local function runCombat(match: Match): TeamName?
	match.CombatStartedAt = now()
	match.RingActive = false
	match.RingShrinkStartsAt = 0
	Combat.SetContextEnabled(match.Context, true)
	setBarriers(match, false)
	setPhase(match, "ActiveCombat", GameConfig.Phases.ActiveCombat)
	Recorder.StartRound(match.Context, match.Round)

	local nextRingTick = 0
	local lastAlive = { Alpha = 0, Bravo = 0 }
	local ringDelay = GameConfig.Phases.ActiveCombat
	while match.Running do
		local t = now()
		-- Ring of Fire after the 60 s combat timer
		if not match.RingActive and t - match.CombatStartedAt >= ringDelay then
			match.RingActive = true
			match.RingShrinkStartsAt = t
			match.PhaseEndsAt = t + GameConfig.Ring.ShrinkDuration
			setRingVisual(match, true)
			match.Dirty = true
		end
		if match.RingActive and t >= nextRingTick then
			nextRingTick = t + GameConfig.Ring.TickInterval
			local radius = ringRadius(match)
			for _, m in match.Members do
				local c = m.Combatant
				local root = if c then c.Root else nil
				if c and c.Alive and root then
					local off = root.Position - match.RingCenter
					if Vector3.new(off.X, 0, off.Z).Magnitude > radius then
						DamageModel.Apply(c, nil, GameConfig.Ring.TickDamage, {
							Kind = "Ring",
							WeaponId = "RingOfFire",
							IgnoreArmor = true,
							IgnoreBlock = true,
						})
					end
				end
			end
		end
		local a, b = aliveCounts(match)
		if a == 0 or b == 0 then
			if a > 0 then
				return "Alpha"
			elseif b > 0 then
				return "Bravo"
			end
			-- simultaneous wipe: the team that had more fighters left last tick, then damage
			if lastAlive.Alpha ~= lastAlive.Bravo then
				return if lastAlive.Alpha > lastAlive.Bravo then "Alpha" else "Bravo"
			end
			local da, db = teamDamage(match, "Alpha"), teamDamage(match, "Bravo")
			if da == db then
				return nil
			end
			return if da > db then "Alpha" else "Bravo"
		end
		lastAlive.Alpha, lastAlive.Bravo = a, b
		if match.Dirty then
			broadcast(match)
		end
		task.wait(0.1)
	end
	return nil
end

---------------------------------------------------------------------------------------------
-- POTG puppets
---------------------------------------------------------------------------------------------
local function buildPuppets(match: Match)
	local map = match.Map
	if map == nil then
		return
	end
	local stage = map:FindFirstChild("POTG_CinematicStage", true)
	local actors = if stage then stage:FindFirstChild("Actors") else nil
	if actors == nil then
		return
	end
	actors:ClearAllChildren()
	for i, m in match.Members do
		local c = m.Combatant
		local character = if c then c.Character else nil
		if character then
			character.Archivable = true
			local ok, puppet = pcall(function()
				return character:Clone()
			end)
			if ok and puppet then
				for _, d in puppet:GetDescendants() do
					if d:IsA("BaseScript") or d:IsA("Sound") or d:IsA("ForceField") then
						d:Destroy()
					elseif d:IsA("BasePart") then
						d.CanCollide = false
						d.CanQuery = false
						d.CanTouch = false
						d.Anchored = d.Name == "HumanoidRootPart"
					end
				end
				local humanoid = puppet:FindFirstChildOfClass("Humanoid")
				if humanoid then
					humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
					humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
					humanoid.EvaluateStateMachine = false
					humanoid.BreakJointsOnDeath = false
				end
				puppet.Name = "Puppet_" .. m.Id
				puppet:SetAttribute("ActorId", m.Id)
				puppet:SetAttribute("CombatantId", nil)
				puppet.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
				puppet:PivotTo(match.Origin * CFrame.new(i * 8, 260, 0))
				puppet.Parent = actors
			end
		end
	end
end

---------------------------------------------------------------------------------------------
-- Settlement
---------------------------------------------------------------------------------------------
local function mvpOf(match: Match, team: TeamName): Member?
	local best: Member? = nil
	local bestScore = -1
	for _, m in match.Members do
		local c = m.Combatant
		if m.Team == team and c then
			local s = c.Stats.Kills * 100 + c.Stats.Assists * 50 + c.Stats.Damage
			if s > bestScore then
				best, bestScore = m, s
			end
		end
	end
	return best
end

local function settle(match: Match)
	local winner: TeamName = match.WinningTeam or "Alpha"
	local mvp = mvpOf(match, winner)
	local rosterList = roster(match)
	for _, m in match.Members do
		local player = m.Player
		local c = m.Combatant
		if player and not m.Left and player.Parent == Players and c then
			local won = m.Team == winner
			local cards, total = Economy.GenerateVictoryDrop(player, won)
			local result = Economy.Settle(player, {
				Won = won,
				Kills = c.Stats.Kills,
				Deaths = c.Stats.Deaths,
				Assists = c.Stats.Assists,
				IsMvp = mvp == m,
				Ranked = match.Spec.Ranked,
			})
			if result then
				local summary: Types.MatchSummary = {
					WinningTeam = winner,
					Score = { Alpha = match.Score.Alpha, Bravo = match.Score.Bravo },
					Roster = rosterList,
					MvpId = if mvp then mvp.Id else "",
					Drop = cards,
					TotalShards = total,
					XPBreakdown = result.XPBreakdown,
					LevelBefore = result.LevelBefore,
					LevelAfter = result.LevelAfter,
					XPBefore = result.XPBefore,
					XPAfter = result.XPAfter,
					XPNeeded = result.XPNeeded,
					PlayAgainSeconds = GameConfig.Phases.VictoryDropAndSummary,
				}
				Net.Reliable("MatchSummary"):FireClient(player, summary)
			end
			task.spawn(PlayerData.Save, player)
		end
	end
end

---------------------------------------------------------------------------------------------
-- Match loop
---------------------------------------------------------------------------------------------
local function cleanup(match: Match)
	match.Running = false
	Combat.SetContextEnabled(match.Context, false)
	Combat.ClearContext(match.Context)
	for _, m in match.Members do
		local c = m.Combatant
		if c then
			Combat.Remove(c)
		end
		if m.Player and m.Player.Parent == Players then
			(m.Player :: any).Team = nil
		end
	end
	Recorder.End(match.Context)
	match.Janitor:Cleanup()
	matches[match.Id] = nil
	if match.Slot > 0 then
		usedSlots[match.Slot] = nil
	end
end

local function runMatch(match: Match)
	if not loadMap(match) then
		for _, p in memberPlayers(match) do
			PlayerData.Notify(p, "Arena maps are missing - run the builder pipeline", "Error")
		end
		cleanup(match)
		return
	end
	setBarriers(match, true)
	setRingVisual(match, false)

	-- Phase 1: VS splash while everyone spawns
	setPhase(match, "PreMatchVS", GameConfig.Phases.PreMatchVS)
	spawnAll(match)
	local actors: { Combatant } = {}
	for _, m in match.Members do
		if m.Combatant then
			table.insert(actors, m.Combatant :: Combatant)
		end
	end
	Recorder.Begin(match.Context, actors)
	task.wait(math.max(0, match.PhaseEndsAt - now()))

	while match.Running do
		match.Round += 1
		match.RoundWinner = nil
		match.BannerTags = nil
		match.Banner = nil
		match.RingActive = false
		match.RingShrinkStartsAt = 0
		setRingVisual(match, false)
		Combat.SetContextEnabled(match.Context, false)
		Combat.ClearContext(match.Context)
		setBarriers(match, true)
		if match.Round > 1 then
			spawnAll(match)
		end

		-- Phase 2: loadout countdown behind the barrier
		setPhase(match, "PreRoundLoadout", GameConfig.Phases.PreRoundLoadout)
		task.wait(math.max(0, match.PhaseEndsAt - now()))
		if not match.Running then
			break
		end

		-- Phase 3: fight
		local winner: TeamName? = runCombat(match)
		Combat.SetContextEnabled(match.Context, false)
		Recorder.FinishRound(match.Context)
		match.RingActive = false
		setRingVisual(match, false)
		if not match.Running then
			break
		end

		-- Phase 4: banner
		match.RoundWinner = winner
		if winner then
			match.Score[winner] += 1
			match.BannerTags = bannerTags(match, winner)
			match.Banner = "ROUND " .. match.Round
		else
			match.BannerTags = { "DRAW" }
			match.Banner = "DRAW"
		end
		setPhase(match, "RoundEndBanner", GameConfig.Phases.RoundEndBanner)
		task.wait(GameConfig.Phases.RoundEndBanner)

		if match.Score.Alpha >= GameConfig.RoundsToWin or match.Score.Bravo >= GameConfig.RoundsToWin then
			match.WinningTeam = if match.Score.Alpha >= GameConfig.RoundsToWin then "Alpha" else "Bravo"
			break
		end
		-- a team with no remaining members forfeits
		local alphaLeft, bravoLeft = 0, 0
		for _, m in match.Members do
			if not m.Left then
				if m.Team == "Alpha" then
					alphaLeft += 1
				else
					bravoLeft += 1
				end
			end
		end
		if alphaLeft == 0 or bravoLeft == 0 then
			match.WinningTeam = if alphaLeft > 0 then "Alpha" else "Bravo"
			break
		end
	end

	if match.WinningTeam == nil then
		match.WinningTeam = if match.Score.Alpha >= match.Score.Bravo then "Alpha" else "Bravo"
	end

	if #memberPlayers(match) > 0 then
		-- Phase 5: Play of the Game
		local packet = Recorder.Best(match.Context)
		if packet then
			buildPuppets(match)
			setPhase(match, "POTGReplay", GameConfig.Phases.POTGReplay)
			local remote = Net.Reliable("BroadcastPOTGData")
			for _, p in memberPlayers(match) do
				remote:FireClient(p, packet, match.Origin.Position)
			end
			task.wait(GameConfig.Phases.POTGReplay)
		end

		-- Phase 6: drops + summary
		setPhase(match, "VictoryDropAndSummary", GameConfig.Phases.VictoryDropAndSummary)
		settle(match)
		local deadline = now() + GameConfig.Phases.VictoryDropAndSummary
		while now() < deadline do
			local everyoneDecided = true
			for _, m in match.Members do
				if m.Player and not m.Left and m.Player.Parent == Players and not m.PlayAgain then
					everyoneDecided = false
				end
			end
			if everyoneDecided then
				break
			end
			task.wait(0.25)
		end
	end

	local players = memberPlayers(match)
	cleanup(match)
	Round.MatchEnded:Fire(match, players)
end

---------------------------------------------------------------------------------------------
-- Public API
---------------------------------------------------------------------------------------------
function Round.StartMatch(spec: MatchSpec): Match
	local id = string.sub(HttpService:GenerateGUID(false), 1, 8)
	local slot = allocateSlot()
	local origin = if slot == 0 then CFrame.identity else CFrame.new(0, 0, 4000 + (slot - 1) * 1200)
	local match: Match = {
		Id = id,
		Spec = spec,
		Context = "Match:" .. id,
		TeamSize = teamSizeFor(spec.Mode),
		MapName = spec.MapName or MAP_NAMES[rng:NextInteger(1, #MAP_NAMES)],
		Map = nil,
		Origin = origin,
		Slot = slot,
		Members = {},
		Phase = "Waiting",
		PhaseEndsAt = 0,
		Round = 0,
		Score = { Alpha = 0, Bravo = 0 },
		RingActive = false,
		RingShrinkStartsAt = 0,
		RingCenter = origin.Position,
		CombatStartedAt = 0,
		Banner = nil,
		BannerTags = nil,
		RoundWinner = nil,
		WinningTeam = nil,
		Dirty = false,
		Running = true,
		Janitor = Janitor.new() :: any,
	}
	local counts = { Alpha = 0, Bravo = 0 }
	for _, entry in spec.Players do
		local profile = PlayerData.Get(entry.Player)
		local member: Member = {
			Id = Registry.IdForPlayer(entry.Player),
			Player = entry.Player,
			Team = entry.Team,
			IsBot = false,
			Name = entry.Player.DisplayName,
			UserId = entry.Player.UserId,
			Combatant = nil,
			Brain = nil,
			PresetIndex = if profile then profile.ActivePreset else 1,
			Loadout = PlayerData.ActiveLoadout(entry.Player),
			Left = false,
			PlayAgain = false,
			Spawning = false,
			RoundKills = 0,
			RoundDeaths = 0,
		}
		table.insert(match.Members, member)
		if entry.Team == "Alpha" then
			counts.Alpha += 1
		else
			counts.Bravo += 1
		end
		match.Janitor:Add(entry.Player.CharacterAdded:Connect(function(character)
			if match.Running and not member.Spawning and match.Phase ~= "Waiting" then
				parkSpectator(match, member, character)
			end
		end))
	end
	if spec.FillBots then
		local presets = LoadoutBudgetValidator.DefaultPresets()
		local used: { [string]: boolean } = {}
		local botTeams: { TeamName } = { "Alpha", "Bravo" }
		for _, team in botTeams do
			local have = if team == "Alpha" then counts.Alpha else counts.Bravo
			for _ = have + 1, match.TeamSize do
				local name = Agent.RandomName(rng, used)
				local bot: Member = {
					Id = "B" .. id .. "_" .. name,
					Player = nil,
					Team = team :: TeamName,
					IsBot = true,
					Name = name,
					UserId = 0,
					Combatant = nil,
					Brain = nil,
					PresetIndex = 1,
					Loadout = presets[rng:NextInteger(1, #presets)],
					Left = false,
					PlayAgain = false,
					Spawning = false,
					RoundKills = 0,
					RoundDeaths = 0,
				}
				table.insert(match.Members, bot)
			end
		end
	end
	matches[id] = match

	-- kill bookkeeping for banners
	match.Janitor:Add(DamageModel.Killed:Connect(function(victim: Combatant, attacker: Combatant?)
		if victim.Context ~= match.Context then
			return
		end
		for _, m in match.Members do
			if m.Combatant == victim then
				m.RoundDeaths += 1
			elseif attacker and m.Combatant == attacker then
				m.RoundKills += 1
			end
		end
		match.Dirty = true
	end))
	-- bots think every frame
	match.Janitor:Add(RunService.Heartbeat:Connect(function(dt)
		if not match.Running then
			return
		end
		local ring: Agent.RingInfo = { Center = match.RingCenter, Radius = ringRadius(match), Active = match.RingActive }
		for _, m in match.Members do
			if m.Brain then
				Agent.Step(m.Brain, dt, ring)
			end
		end
	end))

	task.spawn(runMatch, match)
	return match
end

function Round.ForPlayer(player: Player): Match?
	for _, match in matches do
		for _, m in match.Members do
			if m.Player == player and not m.Left then
				return match
			end
		end
	end
	return nil
end

function Round.Matches(): { [string]: Match }
	return matches
end

local function memberFor(player: Player): (Match?, Member?)
	local match = Round.ForPlayer(player)
	if match then
		for _, m in match.Members do
			if m.Player == player then
				return match, m
			end
		end
	end
	return nil, nil
end

local function onSwitchPreset(player: Player, index: any)
	if not Net.IsFiniteNumber(index) then
		return
	end
	local match, member = memberFor(player)
	if match == nil or member == nil or match.Phase ~= "PreRoundLoadout" then
		return
	end
	local profile = PlayerData.Get(player)
	local i = math.clamp(math.floor(index), 1, 5)
	if profile == nil or profile.Presets[i] == nil then
		return
	end
	if not LoadoutBudgetValidator.Validate(profile.Presets[i], PlayerData.UnlockTable(profile)).Ok then
		PlayerData.Notify(player, "That preset is not valid", "Error")
		return
	end
	member.PresetIndex = i
	profile.ActivePreset = i
	member.Loadout = profile.Presets[i]
	local c = member.Combatant
	if c and c.Alive and c.Root then
		local cf = (c.Root :: BasePart).CFrame
		Combat.Arm(c, member.Loadout, levelLookup(player))
		Combat.SpawnAt(c, cf)
	end
	PlayerData.MarkChanged(player)
end

local function onQueueAction(player: Player, action: any)
	if action ~= "PlayAgain" then
		return
	end
	local _, member = memberFor(player)
	if member then
		member.PlayAgain = true
	end
end

function Round.Start()
	Round.EnsureTeams()
	Net.Reliable("SwitchPresetInPreRound").OnServerEvent:Connect(onSwitchPreset)
	Net.Reliable("RequestSpawnLoadout").OnServerEvent:Connect(onSwitchPreset)
	Net.Reliable("QueueAction").OnServerEvent:Connect(onQueueAction)
	Players.PlayerRemoving:Connect(function(player)
		local match, member = memberFor(player)
		if match and member then
			member.Left = true
			match.Dirty = true
			local humans = #memberPlayers(match)
			if humans == 0 then
				match.Running = false
			end
		end
	end)
end

return Round
