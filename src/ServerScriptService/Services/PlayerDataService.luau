--!strict
-- PlayerDataService: DataStore-backed profiles with a session lock.
--   Schema: {Level, XP, WinStreak, LastLostStreak, GloryRP, TribeId, Shards={[ItemId]=count},
--            UnlockedItems={[ItemId]=level}, Presets={1..5}, GoldenDropPurchased, Settings, ...}
--   Session lock: the stored record is {Profile, Lock={JobId, Time}}. A server only writes while it
--   holds the lock; a teleporting player's previous server releases it on PlayerRemoving, and the
--   next server retries until the lock is released or goes stale (LOCK_STALE_SECONDS).
--   Studio without "Enable Studio Access to API Services" falls back to in-memory profiles.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Modules = game:GetService("ReplicatedStorage"):WaitForChild("Modules")
local Types = require(Modules.Shared.Types)
local Net = require(Modules.Shared.Net)
local Signal = require(Modules.Shared.Signal)
local EquipmentDatabase = require(Modules.Config.EquipmentDatabase)
local LoadoutBudgetValidator = require(Modules.Shared.LoadoutBudgetValidator)

type Profile = Types.Profile

local PlayerDataService = {}

local STORE_NAME = "Tribes3v3_Profiles_v1"
local PROFILE_VERSION = 1
local AUTOSAVE_SECONDS = 60
local LOCK_STALE_SECONDS = 90
local LOAD_ATTEMPTS = 12
local LOAD_RETRY_SECONDS = 1.5

type LockRecord = { JobId: string, Time: number }
type StoredRecord = { Profile: Profile, Lock: LockRecord? }

type Session = {
	Player: Player,
	Profile: Profile,
	Loaded: boolean,
	Released: boolean,
	Memory: boolean,
}

local sessions: { [Player]: Session } = {}
local store: DataStore? = nil
local useMemory = false

PlayerDataService.ProfileLoaded = Signal.new() :: Signal.Signal<Player, Profile>
PlayerDataService.ProfileChanged = Signal.new() :: Signal.Signal<Player, Profile>

---------------------------------------------------------------------------------------------
-- Defaults and reconciliation
---------------------------------------------------------------------------------------------
function PlayerDataService.DefaultSettings(): Types.PlayerSettings
	return {
		CameraSensitivity = 1,
		FieldOfView = 70,
		ViewBobbing = true,
		PreventFullBotMatches = false,
		FirstPersonDefault = false,
	}
end

function PlayerDataService.DefaultProfile(): Profile
	local unlocked: { [string]: number } = {}
	for _, id in EquipmentDatabase.StarterItems() do
		unlocked[id] = 1
	end
	return {
		Version = PROFILE_VERSION,
		Level = 1,
		XP = 0,
		WinStreak = 0,
		BestStreak = 0,
		LastLostStreak = 0,
		GloryRP = 0,
		TribeId = nil,
		Kills = 0,
		Deaths = 0,
		Wins = 0,
		Losses = 0,
		Shards = {},
		UnlockedItems = unlocked,
		Presets = LoadoutBudgetValidator.DefaultPresets(),
		ActivePreset = 1,
		GoldenDropPurchased = false,
		MatchesPlayed = 0,
		Settings = PlayerDataService.DefaultSettings(),
		ProcessedReceipts = {},
	}
end

local function num(v: any, default: number): number
	if type(v) == "number" and v == v then
		return v
	end
	return default
end

-- Repair a stored profile: fills missing fields, drops unknown item ids, revalidates presets.
function PlayerDataService.Reconcile(raw: any): Profile
	local d = PlayerDataService.DefaultProfile()
	if type(raw) ~= "table" then
		return d
	end
	d.Level = math.max(1, math.floor(num(raw.Level, 1)))
	d.XP = math.max(0, num(raw.XP, 0))
	d.WinStreak = math.max(0, math.floor(num(raw.WinStreak, 0)))
	d.BestStreak = math.max(d.WinStreak, math.floor(num(raw.BestStreak, 0)))
	d.LastLostStreak = math.max(0, math.floor(num(raw.LastLostStreak, 0)))
	d.GloryRP = math.max(0, math.floor(num(raw.GloryRP, 0)))
	d.TribeId = if type(raw.TribeId) == "string" then raw.TribeId else nil
	d.Kills = math.max(0, math.floor(num(raw.Kills, 0)))
	d.Deaths = math.max(0, math.floor(num(raw.Deaths, 0)))
	d.Wins = math.max(0, math.floor(num(raw.Wins, 0)))
	d.Losses = math.max(0, math.floor(num(raw.Losses, 0)))
	d.MatchesPlayed = math.max(0, math.floor(num(raw.MatchesPlayed, 0)))
	d.GoldenDropPurchased = raw.GoldenDropPurchased == true
	if type(raw.Shards) == "table" then
		for id, count in raw.Shards do
			if type(id) == "string" and EquipmentDatabase.Get(id) and type(count) == "number" then
				d.Shards[id] = math.max(0, math.floor(count))
			end
		end
	end
	if type(raw.UnlockedItems) == "table" then
		for id, level in raw.UnlockedItems do
			if type(id) == "string" and EquipmentDatabase.Get(id) and type(level) == "number" then
				d.UnlockedItems[id] = math.clamp(math.floor(level), 1, 10)
			end
		end
	end
	if type(raw.Settings) == "table" then
		local s = raw.Settings
		d.Settings.CameraSensitivity = math.clamp(num(s.CameraSensitivity, 1), 0.1, 3)
		d.Settings.FieldOfView = math.clamp(num(s.FieldOfView, 70), 70, 120)
		d.Settings.ViewBobbing = s.ViewBobbing ~= false
		d.Settings.PreventFullBotMatches = s.PreventFullBotMatches == true
		d.Settings.FirstPersonDefault = s.FirstPersonDefault == true
	end
	if type(raw.ProcessedReceipts) == "table" then
		for _, r in raw.ProcessedReceipts do
			if type(r) == "string" then
				table.insert(d.ProcessedReceipts, r)
			end
		end
	end
	if type(raw.Presets) == "table" then
		for i = 1, 5 do
			local loadout = LoadoutBudgetValidator.Sanitize(raw.Presets[i])
			if loadout then
				local result = LoadoutBudgetValidator.Validate(loadout, PlayerDataService.UnlockTable(d))
				if result.Ok then
					d.Presets[i] = loadout
				end
			end
		end
	end
	d.ActivePreset = math.clamp(math.floor(num(raw.ActivePreset, 1)), 1, 5)
	return d
end

---------------------------------------------------------------------------------------------
-- Ownership helpers
---------------------------------------------------------------------------------------------
function PlayerDataService.IsUnlocked(profile: Profile, itemId: string): boolean
	local spec = EquipmentDatabase.Get(itemId)
	if spec == nil then
		return false
	end
	if profile.UnlockedItems[itemId] ~= nil then
		return true
	end
	if spec.RankedOnly then
		local need = EquipmentDatabase.RankedUnlockGlory[itemId]
		return need ~= nil and profile.GloryRP >= need
	end
	return false
end

-- {ItemId = level} for every owned item, including glory-unlocked ranked melees.
function PlayerDataService.UnlockTable(profile: Profile): { [string]: number }
	local t: { [string]: number } = {}
	for _, id in EquipmentDatabase.Order do
		if PlayerDataService.IsUnlocked(profile, id) then
			t[id] = profile.UnlockedItems[id] or 1
		end
	end
	return t
end

function PlayerDataService.ItemLevel(profile: Profile?, itemId: string): number
	if profile == nil then
		return 1
	end
	return profile.UnlockedItems[itemId] or 1
end

---------------------------------------------------------------------------------------------
-- Storage
---------------------------------------------------------------------------------------------
local function keyFor(userId: number): string
	return "u_" .. tostring(userId)
end

local function probeStore()
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(STORE_NAME)
	end)
	if not ok then
		useMemory = true
		warn("[PlayerData] DataStore unavailable, using in-memory profiles:", result)
		return
	end
	store = result
	if RunService:IsStudio() then
		local probeOk, err = pcall(function()
			(result :: DataStore):GetAsync("__probe")
		end)
		if not probeOk then
			useMemory = true
			warn("[PlayerData] Studio API access disabled, using in-memory profiles:", err)
		end
	end
end

local function loadFromStore(player: Player): (Profile?, string?)
	local ds = store
	if ds == nil then
		return nil, "no store"
	end
	local key = keyFor(player.UserId)
	for attempt = 1, LOAD_ATTEMPTS do
		local acquired = false
		local profile: Profile? = nil
		local force = attempt == LOAD_ATTEMPTS
		local ok, err = pcall(function()
			ds:UpdateAsync(key, function(old: any): any
				local lock = if type(old) == "table" then old.Lock else nil
				if type(lock) == "table" and lock.JobId ~= game.JobId and not force then
					local age = os.time() - num(lock.Time, 0)
					if age < LOCK_STALE_SECONDS then
						return nil -- held by another live server; cancel the write and retry
					end
				end
				local data = PlayerDataService.Reconcile(if type(old) == "table" then old.Profile else nil)
				profile = data
				acquired = true
				local record: StoredRecord = { Profile = data, Lock = { JobId = game.JobId, Time = os.time() } }
				return record
			end)
		end)
		if ok and acquired and profile then
			return profile, nil
		end
		if not ok then
			warn(string.format("[PlayerData] load attempt %d for %s failed: %s", attempt, player.Name, tostring(err)))
		end
		if player.Parent ~= Players then
			return nil, "left"
		end
		task.wait(LOAD_RETRY_SECONDS)
	end
	return nil, "lock timeout"
end

local function saveToStore(session: Session, release: boolean): boolean
	local ds = store
	if ds == nil or session.Memory then
		return true
	end
	local key = keyFor(session.Player.UserId)
	local ok, err = pcall(function()
		ds:UpdateAsync(key, function(old: any): any
			local lock = if type(old) == "table" then old.Lock else nil
			if type(lock) == "table" and lock.JobId ~= game.JobId then
				return nil -- another server took over the session; never overwrite its data
			end
			local record: StoredRecord = {
				Profile = session.Profile,
				Lock = if release then nil else { JobId = game.JobId, Time = os.time() },
			}
			return record
		end)
	end)
	if not ok then
		warn("[PlayerData] save failed for", session.Player.Name, err)
	end
	return ok
end

---------------------------------------------------------------------------------------------
-- Public API
---------------------------------------------------------------------------------------------
function PlayerDataService.Get(player: Player): Profile?
	local s = sessions[player]
	if s and s.Loaded then
		return s.Profile
	end
	return nil
end

function PlayerDataService.WaitFor(player: Player, timeout: number?): Profile?
	local deadline = os.clock() + (timeout or 30)
	while os.clock() < deadline and player.Parent == Players do
		local p = PlayerDataService.Get(player)
		if p then
			return p
		end
		task.wait(0.1)
	end
	return PlayerDataService.Get(player)
end

-- Push the profile to the client and notify listeners. Call after every mutation.
function PlayerDataService.MarkChanged(player: Player)
	local s = sessions[player]
	if s == nil or not s.Loaded then
		return
	end
	Net.Reliable("ProfileSync"):FireClient(player, s.Profile)
	PlayerDataService.ProfileChanged:Fire(player, s.Profile)
end

function PlayerDataService.Save(player: Player): boolean
	local s = sessions[player]
	if s == nil or not s.Loaded then
		return false
	end
	return saveToStore(s, false)
end

function PlayerDataService.Notify(player: Player, text: string, kind: string?)
	Net.Reliable("Notify"):FireClient(player, text, kind or "Info")
end

function PlayerDataService.ActiveLoadout(player: Player): Types.Loadout
	local p = PlayerDataService.Get(player)
	if p == nil then
		return LoadoutBudgetValidator.DefaultPresets()[1]
	end
	return p.Presets[p.ActivePreset] or p.Presets[1]
end

local function onPlayerAdded(player: Player)
	local session: Session = {
		Player = player,
		Profile = PlayerDataService.DefaultProfile(),
		Loaded = false,
		Released = false,
		Memory = useMemory,
	}
	sessions[player] = session
	if not useMemory then
		local profile, err = loadFromStore(player)
		if profile == nil then
			if err == "left" then
				sessions[player] = nil
				return
			end
			player:Kick("Could not load your profile (" .. tostring(err) .. "). Please rejoin.")
			sessions[player] = nil
			return
		end
		session.Profile = profile
	end
	if player.Parent ~= Players then
		saveToStore(session, true)
		sessions[player] = nil
		return
	end
	session.Loaded = true
	player:SetAttribute("Level", session.Profile.Level)
	player:SetAttribute("GloryRP", session.Profile.GloryRP)
	PlayerDataService.MarkChanged(player)
	PlayerDataService.ProfileLoaded:Fire(player, session.Profile)
end

local function onPlayerRemoving(player: Player)
	local s = sessions[player]
	if s == nil then
		return
	end
	if s.Loaded and not s.Released then
		s.Released = true
		saveToStore(s, true)
	end
	sessions[player] = nil
end

---------------------------------------------------------------------------------------------
-- Remotes: SaveLoadout and UpdateSettings
---------------------------------------------------------------------------------------------
local function onSaveLoadout(player: Player, index: any, raw: any, makeActive: any)
	local profile = PlayerDataService.Get(player)
	if profile == nil or type(index) ~= "number" then
		return
	end
	local i = math.floor(index)
	if i < 1 or i > 5 then
		return
	end
	local loadout = LoadoutBudgetValidator.Sanitize(raw)
	if loadout == nil then
		PlayerDataService.Notify(player, "Invalid loadout data", "Error")
		return
	end
	local result = LoadoutBudgetValidator.Validate(loadout, PlayerDataService.UnlockTable(profile))
	if not result.Ok then
		PlayerDataService.Notify(player, result.Errors[1] or "Loadout rejected", "Error")
		Net.Reliable("SaveLoadout"):FireClient(player, false, result.Errors)
		return
	end
	profile.Presets[i] = loadout
	if makeActive == true then
		profile.ActivePreset = i
	end
	PlayerDataService.MarkChanged(player)
	Net.Reliable("SaveLoadout"):FireClient(player, true, {})
end

local function onUpdateSettings(player: Player, raw: any)
	local profile = PlayerDataService.Get(player)
	if profile == nil or type(raw) ~= "table" then
		return
	end
	local s = profile.Settings
	if Net.IsFiniteNumber(raw.CameraSensitivity) then
		s.CameraSensitivity = math.clamp(raw.CameraSensitivity, 0.1, 3)
	end
	if Net.IsFiniteNumber(raw.FieldOfView) then
		s.FieldOfView = math.clamp(math.floor(raw.FieldOfView), 70, 120)
	end
	if type(raw.ViewBobbing) == "boolean" then
		s.ViewBobbing = raw.ViewBobbing
	end
	if type(raw.PreventFullBotMatches) == "boolean" then
		s.PreventFullBotMatches = raw.PreventFullBotMatches
	end
	if type(raw.FirstPersonDefault) == "boolean" then
		s.FirstPersonDefault = raw.FirstPersonDefault
	end
	if Net.IsFiniteNumber(raw.ActivePreset) then
		profile.ActivePreset = math.clamp(math.floor(raw.ActivePreset), 1, 5)
	end
	PlayerDataService.MarkChanged(player)
end

function PlayerDataService.Start()
	probeStore()
	Net.Reliable("SaveLoadout").OnServerEvent:Connect(onSaveLoadout)
	Net.Reliable("UpdateSettings").OnServerEvent:Connect(onUpdateSettings)
	Players.PlayerAdded:Connect(function(player)
		task.spawn(onPlayerAdded, player)
	end)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end
	Players.PlayerRemoving:Connect(onPlayerRemoving)

	task.spawn(function()
		while true do
			task.wait(AUTOSAVE_SECONDS)
			for player, s in sessions do
				if s.Loaded and not s.Released then
					task.spawn(saveToStore, s, false)
				end
			end
		end
	end)

	game:BindToClose(function()
		local pending = 0
		for _, s in sessions do
			if s.Loaded and not s.Released then
				pending += 1
				s.Released = true
				task.spawn(function()
					saveToStore(s, true)
					pending -= 1
				end)
			end
		end
		local deadline = os.clock() + 25
		while pending > 0 and os.clock() < deadline do
			task.wait(0.1)
		end
	end)
end

return PlayerDataService
