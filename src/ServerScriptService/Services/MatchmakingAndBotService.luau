--!strict
-- MatchmakingAndBotService: parties, the 3v3 queue, custom rooms and arena hand-off.
--   Queue: whole parties are packed into Alpha/Bravo. Six humans start at once; after
--   BotFillAfterSeconds (15 s) the oldest group starts with TacticalBotAgent bots filling the
--   empty slots - unless someone in it enabled PreventFullBotMatches.
--   Arena hand-off: TeleportService:ReserveServer(ArenaPlaceId) + TeleportAsync with
--   TeleportData {Teams, Mode, Ranked}. With ArenaPlaceId = 0 or in Studio, the match runs
--   locally in the lobby server (practice mode). The arena place boots one match from the
--   joining players' TeleportData and sends everyone back to the lobby afterwards.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")
local Workspace = game:GetService("Workspace")
local HttpService = game:GetService("HttpService")

local Modules = game:GetService("ReplicatedStorage"):WaitForChild("Modules")
local Types = require(Modules.Shared.Types)
local Net = require(Modules.Shared.Net)
local GameConfig = require(Modules.Config.GameConfig)

local PlayerData = require(script.Parent.PlayerDataService)
local Round = require(script.Parent.RoundStateMachineService)

type TeamName = Types.TeamName

local Matchmaking = {}

type Party = {
	Id: string,
	Leader: Player,
	Members: { Player },
	Queued: boolean,
	QueueStartedAt: number,
}

type Room = {
	Id: string,
	Name: string,
	Mode: Round.MatchMode,
	Host: Player,
	FillBots: boolean,
	Alpha: { Player },
	Bravo: { Player },
	Started: boolean,
}

type Invite = { From: Player, At: number }

local partyOf: { [Player]: Party } = {}
local invites: { [Player]: Invite } = {}
local rooms: { [string]: Room } = {}
local MM = GameConfig.Matchmaking

local function now(): number
	return Workspace:GetServerTimeNow()
end

local function canTeleport(): boolean
	return GameConfig.Places.ArenaPlaceId ~= 0 and not RunService:IsStudio()
end

local function inMatch(player: Player): boolean
	return Round.ForPlayer(player) ~= nil
end

---------------------------------------------------------------------------------------------
-- Parties
---------------------------------------------------------------------------------------------
local function soloParty(player: Player): Party
	local p = partyOf[player]
	if p then
		return p
	end
	local party: Party = {
		Id = string.sub(HttpService:GenerateGUID(false), 1, 8),
		Leader = player,
		Members = { player },
		Queued = false,
		QueueStartedAt = 0,
	}
	partyOf[player] = party
	return party
end

local function partyView(party: Party): Types.PartyView
	local members = {}
	for _, m in party.Members do
		table.insert(members, { UserId = m.UserId, Name = m.DisplayName })
	end
	return {
		Leader = party.Leader.UserId,
		Members = members,
		Queued = party.Queued,
		QueueStartedAt = party.QueueStartedAt,
	}
end

local function syncParty(party: Party)
	local view = partyView(party)
	local remote = Net.Reliable("PartyAction")
	for _, m in party.Members do
		remote:FireClient(m, "State", view)
	end
end

local function leaveParty(player: Player)
	local party = partyOf[player]
	if party == nil then
		return
	end
	partyOf[player] = nil
	local idx = table.find(party.Members, player)
	if idx then
		table.remove(party.Members, idx)
	end
	party.Queued = false
	if #party.Members > 0 then
		if party.Leader == player then
			party.Leader = party.Members[1]
		end
		syncParty(party)
	end
	if player.Parent == Players then
		syncParty(soloParty(player))
	end
end

local function onPartyAction(player: Player, action: any, arg: any)
	if type(action) ~= "string" then
		return
	end
	local party = soloParty(player)
	if action == "Invite" then
		if type(arg) ~= "string" or #arg > 32 then
			return
		end
		if party.Leader ~= player then
			PlayerData.Notify(player, "Only the party leader can invite", "Error")
			return
		end
		if #party.Members >= MM.PartyMaxSize then
			PlayerData.Notify(player, "Party is full", "Error")
			return
		end
		local query = string.lower(arg)
		local target: Player? = nil
		for _, p in Players:GetPlayers() do
			if string.lower(p.Name) == query or string.lower(p.DisplayName) == query then
				target = p
				break
			end
		end
		if target == nil or target == player then
			PlayerData.Notify(player, "Player not found", "Error")
			return
		end
		invites[target] = { From = player, At = now() }
		Net.Reliable("PartyAction"):FireClient(target, "Invite", { FromName = player.DisplayName, FromUserId = player.UserId })
		PlayerData.Notify(player, "Invite sent to " .. target.DisplayName, "Info")
	elseif action == "Accept" then
		local invite = invites[player]
		invites[player] = nil
		if invite == nil or now() - invite.At > 60 or invite.From.Parent ~= Players then
			PlayerData.Notify(player, "Invite expired", "Error")
			return
		end
		local target = soloParty(invite.From)
		if #target.Members >= MM.PartyMaxSize or target.Queued then
			PlayerData.Notify(player, "Party unavailable", "Error")
			return
		end
		leaveParty(player)
		partyOf[player] = target
		table.insert(target.Members, player)
		syncParty(target)
	elseif action == "Decline" then
		invites[player] = nil
	elseif action == "Leave" then
		leaveParty(player)
	elseif action == "Kick" then
		if party.Leader ~= player or type(arg) ~= "number" then
			return
		end
		for _, m in party.Members do
			if m.UserId == arg and m ~= player then
				leaveParty(m)
				PlayerData.Notify(m, "You were removed from the party", "Info")
				break
			end
		end
	end
end

---------------------------------------------------------------------------------------------
-- Match start (teleport or local)
---------------------------------------------------------------------------------------------
local function startMatch(spec: Round.MatchSpec)
	local players: { Player } = {}
	for _, e in spec.Players do
		table.insert(players, e.Player)
	end
	if canTeleport() and #players > 0 then
		local ok, err = pcall(function()
			local code = TeleportService:ReserveServer(GameConfig.Places.ArenaPlaceId)
			local options = Instance.new("TeleportOptions")
			options.ReservedServerAccessCode = code
			local teams: { [string]: string } = {}
			for _, e in spec.Players do
				teams[tostring(e.Player.UserId)] = e.Team
			end
			options:SetTeleportData({
				Teams = teams,
				Mode = spec.Mode,
				Kind = spec.Kind,
				Ranked = spec.Ranked,
				FillBots = spec.FillBots,
			})
			TeleportService:TeleportAsync(GameConfig.Places.ArenaPlaceId, players, options)
		end)
		if ok then
			for _, p in players do
				PlayerData.Notify(p, "Match found! Travelling to the arena...", "Success")
			end
			return
		end
		warn("[Matchmaking] teleport failed, running locally:", err)
	end
	Round.StartMatch(spec)
end

---------------------------------------------------------------------------------------------
-- Queue
---------------------------------------------------------------------------------------------
local function queueStatus(party: Party, extra: { [string]: any }?)
	local t = now()
	local queuedPlayers = 0
	for _, p in partyOf do
		if p.Queued then
			queuedPlayers += 1
		end
	end
	local blocks = false
	for _, m in party.Members do
		local profile = PlayerData.Get(m)
		if profile and profile.Settings.PreventFullBotMatches then
			blocks = true
		end
	end
	local status = {
		Queued = party.Queued,
		Elapsed = if party.Queued then t - party.QueueStartedAt else 0,
		InQueue = queuedPlayers,
		BotFillIn = if blocks then -1 else math.max(0, MM.BotFillAfterSeconds - (t - party.QueueStartedAt)),
	}
	if extra then
		for k, v in extra do
			(status :: any)[k] = v
		end
	end
	local remote = Net.Reliable("QueueAction")
	for _, m in party.Members do
		remote:FireClient(m, "Status", status)
	end
end

local function partyBlocksBots(party: Party): boolean
	for _, m in party.Members do
		local profile = PlayerData.Get(m)
		if profile and profile.Settings.PreventFullBotMatches then
			return true
		end
	end
	return false
end

local function joinQueue(player: Player)
	local party = soloParty(player)
	if party.Leader ~= player then
		PlayerData.Notify(player, "Only the party leader can queue", "Error")
		return
	end
	for _, m in party.Members do
		if inMatch(m) then
			PlayerData.Notify(player, "A party member is still in a match", "Error")
			return
		end
	end
	if not party.Queued then
		party.Queued = true
		party.QueueStartedAt = now()
	end
	syncParty(party)
	queueStatus(party)
end

local function leaveQueue(player: Player)
	local party = partyOf[player]
	if party and party.Queued then
		party.Queued = false
		syncParty(party)
		queueStatus(party)
	end
end

local function uniqueQueuedParties(): { Party }
	local list: { Party } = {}
	local seen: { [Party]: boolean } = {}
	for _, p in partyOf do
		if p.Queued and not seen[p] then
			seen[p] = true
			table.insert(list, p)
		end
	end
	table.sort(list, function(a, b)
		return a.QueueStartedAt < b.QueueStartedAt
	end)
	return list
end

-- Greedy packing of whole parties into two teams of `size`.
local function pack(parties: { Party }, size: number): ({ Party }, { Party })
	local alpha, bravo = {}, {}
	local na, nb = 0, 0
	for _, p in parties do
		local n = #p.Members
		if na + n <= size and na <= nb then
			table.insert(alpha, p)
			na += n
		elseif nb + n <= size then
			table.insert(bravo, p)
			nb += n
		elseif na + n <= size then
			table.insert(alpha, p)
			na += n
		end
	end
	return alpha, bravo
end

local function launch(alpha: { Party }, bravo: { Party }, fillBots: boolean)
	local entries: { Round.PlayerEntry } = {}
	for _, list in { alpha, bravo } do
		local team: TeamName = if list == alpha then "Alpha" else "Bravo"
		for _, party in list do
			party.Queued = false
			for _, m in party.Members do
				table.insert(entries, { Player = m, Team = team })
			end
			queueStatus(party, { Found = true })
			syncParty(party)
		end
	end
	startMatch({
		Mode = "3v3",
		Kind = "Queue",
		Ranked = true,
		FillBots = fillBots,
		Players = entries,
	})
end

local function tickQueue()
	local queued = uniqueQueuedParties()
	if #queued == 0 then
		return
	end
	local size = GameConfig.TeamSize
	-- full human match
	local alpha, bravo = pack(queued, size)
	local count = 0
	for _, p in alpha do
		count += #p.Members
	end
	for _, p in bravo do
		count += #p.Members
	end
	if count >= size * 2 then
		launch(alpha, bravo, false)
		return
	end
	-- bot fill for parties that waited long enough and allow bots
	local t = now()
	local allowing: { Party } = {}
	for _, p in queued do
		if not partyBlocksBots(p) then
			table.insert(allowing, p)
		end
	end
	if #allowing > 0 and t - allowing[1].QueueStartedAt >= MM.BotFillAfterSeconds then
		local a2, b2 = pack(allowing, size)
		launch(a2, b2, true)
		return
	end
	for _, p in queued do
		queueStatus(p)
	end
end

local function onQueueAction(player: Player, action: any)
	if action == "Join" then
		joinQueue(player)
	elseif action == "Leave" then
		leaveQueue(player)
	end
end

---------------------------------------------------------------------------------------------
-- Custom rooms
---------------------------------------------------------------------------------------------
local function roomView(room: Room): Types.RoomView
	local function names(list: { Player }): { { UserId: number, Name: string } }
		local out = {}
		for _, p in list do
			table.insert(out, { UserId = p.UserId, Name = p.DisplayName })
		end
		return out
	end
	return {
		Id = room.Id,
		Name = room.Name,
		Mode = room.Mode,
		HostId = room.Host.UserId,
		FillBots = room.FillBots,
		Alpha = names(room.Alpha),
		Bravo = names(room.Bravo),
		TeamSize = if room.Mode == "1v1" then 1 elseif room.Mode == "2v2" then 2 else 3,
	}
end

local function broadcastRooms()
	local list: { Types.RoomView } = {}
	for _, r in rooms do
		if not r.Started then
			table.insert(list, roomView(r))
		end
	end
	Net.Reliable("CustomMatchAction"):FireAllClients("Rooms", list)
end

local function roomOf(player: Player): Room?
	for _, r in rooms do
		if table.find(r.Alpha, player) or table.find(r.Bravo, player) then
			return r
		end
	end
	return nil
end

local function leaveRoom(player: Player)
	local room = roomOf(player)
	if room == nil then
		return
	end
	local ia = table.find(room.Alpha, player)
	if ia then
		table.remove(room.Alpha, ia)
	end
	local ib = table.find(room.Bravo, player)
	if ib then
		table.remove(room.Bravo, ib)
	end
	if room.Host == player then
		local nextHost = room.Alpha[1] or room.Bravo[1]
		if nextHost then
			room.Host = nextHost
		else
			rooms[room.Id] = nil
		end
	end
	broadcastRooms()
end

local function onCustomAction(player: Player, action: any, arg: any)
	if type(action) ~= "string" then
		return
	end
	if action == "List" then
		broadcastRooms()
	elseif action == "Create" then
		if type(arg) ~= "table" then
			return
		end
		local count = 0
		for _ in rooms do
			count += 1
		end
		if count >= MM.CustomRoomMaxRooms then
			PlayerData.Notify(player, "Too many rooms open", "Error")
			return
		end
		local mode: Round.MatchMode = if arg.Mode == "1v1" then "1v1" elseif arg.Mode == "2v2" then "2v2" else "3v3"
		leaveRoom(player)
		local id = string.sub(HttpService:GenerateGUID(false), 1, 6)
		rooms[id] = {
			Id = id,
			Name = player.DisplayName .. "'s Room",
			Mode = mode,
			Host = player,
			FillBots = arg.FillBots == true,
			Alpha = { player },
			Bravo = {},
			Started = false,
		}
		broadcastRooms()
	elseif action == "Join" then
		if type(arg) ~= "table" or type(arg.RoomId) ~= "string" then
			return
		end
		local room = rooms[arg.RoomId]
		if room == nil or room.Started then
			return
		end
		local size = roomView(room).TeamSize
		local want = if arg.Team == "Bravo" then room.Bravo else room.Alpha
		if #want >= size then
			PlayerData.Notify(player, "That team is full", "Error")
			return
		end
		local current = roomOf(player)
		if current and current ~= room then
			leaveRoom(player)
		elseif current == room then
			local ia = table.find(room.Alpha, player)
			if ia then
				table.remove(room.Alpha, ia)
			end
			local ib = table.find(room.Bravo, player)
			if ib then
				table.remove(room.Bravo, ib)
			end
		end
		table.insert(want, player)
		broadcastRooms()
	elseif action == "Leave" then
		leaveRoom(player)
	elseif action == "Start" then
		local room = roomOf(player)
		if room == nil or room.Host ~= player or room.Started then
			return
		end
		if not room.FillBots and (#room.Alpha == 0 or #room.Bravo == 0) then
			PlayerData.Notify(player, "Both teams need a player (or enable Fill Bots)", "Error")
			return
		end
		room.Started = true
		rooms[room.Id] = nil
		local entries: { Round.PlayerEntry } = {}
		for _, p in room.Alpha do
			table.insert(entries, { Player = p, Team = "Alpha" })
		end
		for _, p in room.Bravo do
			table.insert(entries, { Player = p, Team = "Bravo" })
		end
		broadcastRooms()
		startMatch({
			Mode = room.Mode,
			Kind = "Custom",
			Ranked = false,
			FillBots = room.FillBots,
			Players = entries,
		})
	end
end

---------------------------------------------------------------------------------------------
-- Arena place boot
---------------------------------------------------------------------------------------------
local function teleportToLobby(players: { Player }, autoQueue: { [Player]: boolean })
	if GameConfig.Places.LobbyPlaceId == 0 or RunService:IsStudio() then
		return false
	end
	local requeue: { Player } = {}
	local back: { Player } = {}
	for _, p in players do
		if p.Parent == Players then
			table.insert(if autoQueue[p] then requeue else back, p)
		end
	end
	for _, group in { requeue, back } do
		if #group > 0 then
			local options = Instance.new("TeleportOptions")
			options:SetTeleportData({ AutoQueue = group == requeue })
			local ok, err = pcall(function()
				TeleportService:TeleportAsync(GameConfig.Places.LobbyPlaceId, group, options)
			end)
			if not ok then
				warn("[Matchmaking] return teleport failed:", err)
			end
		end
	end
	return true
end

local function arenaSpecFromJoiners(): Round.MatchSpec
	local entries: { Round.PlayerEntry } = {}
	local mode: Round.MatchMode = "3v3"
	local kind: Round.MatchKind = "Queue"
	local ranked = false
	local alpha, bravo = 0, 0
	for _, p in Players:GetPlayers() do
		local data = p:GetJoinData().TeleportData
		local team: TeamName? = nil
		if type(data) == "table" then
			local d = data :: any
			if type(d.Teams) == "table" then
				local t = d.Teams[tostring(p.UserId)]
				if t == "Alpha" or t == "Bravo" then
					team = t
				end
			end
			if d.Mode == "1v1" or d.Mode == "2v2" or d.Mode == "3v3" then
				mode = d.Mode
			end
			if d.Kind == "Custom" then
				kind = "Custom"
			end
			ranked = d.Ranked == true
		end
		if team == nil then
			team = if alpha <= bravo then "Alpha" else "Bravo"
		end
		if team == "Alpha" then
			alpha += 1
		else
			bravo += 1
		end
		table.insert(entries, { Player = p, Team = team :: TeamName })
	end
	if #entries > 0 and #Players:GetPlayers() == 1 and kind == "Queue" and not ranked then
		kind = "Practice"
	end
	return { Mode = mode, Kind = kind, Ranked = ranked, FillBots = true, Players = entries }
end

local function expectedArenaPlayers(): number
	for _, p in Players:GetPlayers() do
		local data = p:GetJoinData().TeleportData
		if type(data) == "table" and type((data :: any).Teams) == "table" then
			local n = 0
			for _ in (data :: any).Teams do
				n += 1
			end
			return n
		end
	end
	return 1
end

function Matchmaking.ArenaBoot()
	task.spawn(function()
		while true do
			while #Players:GetPlayers() == 0 do
				task.wait(0.5)
			end
			local started = os.clock()
			while os.clock() - started < MM.ArenaWaitForPlayersSeconds do
				if #Players:GetPlayers() >= expectedArenaPlayers() then
					break
				end
				task.wait(0.5)
			end
			-- let profiles load before arming loadouts
			for _, p in Players:GetPlayers() do
				PlayerData.WaitFor(p, 15)
			end
			local spec = arenaSpecFromJoiners()
			if #spec.Players == 0 then
				continue
			end
			local done = false
			local playAgain: { [Player]: boolean } = {}
			local match = Round.StartMatch(spec)
			local conn
			conn = Round.MatchEnded:Connect(function(ended: Round.Match, players: { Player })
				if ended.Id ~= match.Id then
					return
				end
				conn:Disconnect()
				for _, m in ended.Members do
					if m.Player and m.PlayAgain then
						playAgain[m.Player] = true
					end
				end
				if not teleportToLobby(players, playAgain) then
					-- Studio / unconfigured lobby: loop straight into another match
					task.wait(3)
				end
				done = true
			end)
			while not done do
				task.wait(0.5)
			end
		end
	end)
end

---------------------------------------------------------------------------------------------
function Matchmaking.Start()
	Net.Reliable("PartyAction").OnServerEvent:Connect(onPartyAction)
	Net.Reliable("QueueAction").OnServerEvent:Connect(onQueueAction)
	Net.Reliable("CustomMatchAction").OnServerEvent:Connect(onCustomAction)

	Players.PlayerAdded:Connect(function(player)
		task.spawn(function()
			PlayerData.WaitFor(player, 30)
			if player.Parent ~= Players then
				return
			end
			syncParty(soloParty(player))
			local data = player:GetJoinData().TeleportData
			if type(data) == "table" and (data :: any).AutoQueue == true then
				joinQueue(player)
			end
		end)
	end)
	Players.PlayerRemoving:Connect(function(player)
		leaveParty(player)
		invites[player] = nil
		leaveRoom(player)
	end)

	-- lobby-local matches: return to the village and honour PLAY AGAIN
	Round.MatchEnded:Connect(function(match: Round.Match, players: { Player })
		if GameConfig.GetPlaceRole() ~= "Lobby" then
			return
		end
		for _, p in players do
			if p.Parent == Players then
				Round.ReturnToLobby(p)
			end
		end
		for _, m in match.Members do
			if m.Player and m.PlayAgain and m.Player.Parent == Players then
				local party = soloParty(m.Player)
				if party.Leader == m.Player then
					joinQueue(m.Player)
				end
			end
		end
	end)

	task.spawn(function()
		while true do
			task.wait(1)
			tickQueue()
		end
	end)
end

return Matchmaking
