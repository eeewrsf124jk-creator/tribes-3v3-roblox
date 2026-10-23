--!strict
-- Place architecture and match tuning constants.
--
-- 2-place architecture:
--   Place 1  LobbyAndHub  (MaxPlayers 50) - built from default.project.json
--   Place 2  CombatArena  (MaxPlayers 6)  - built from arena.project.json
-- Publish both places into the same experience, then set the two place IDs below. While
-- ArenaPlaceId is 0 (or when running in Studio), the lobby runs matches as local practice
-- matches and the arena place starts a solo-vs-bots match on its own.

local GameConfig = {
	Places = {
		LobbyPlaceId = 0,
		ArenaPlaceId = 0,
		LobbyMaxPlayers = 50,
		ArenaMaxPlayers = 6,
	},

	Phases = {
		PreMatchVS = 6,
		PreRoundLoadout = 5,
		ActiveCombat = 60,
		RoundEndBanner = 4,
		POTGReplay = 8,
		VictoryDropAndSummary = 25,
	},

	RoundsToWin = 3, -- Best of 5
	TeamSize = 3,

	Ring = {
		StartRadius = 180,
		EndRadius = 0,
		ShrinkDuration = 30,
		TickInterval = 0.5,
		TickDamage = 10,
		Height = 120,
	},

	Matchmaking = {
		BotFillAfterSeconds = 15,
		ArenaWaitForPlayersSeconds = 20,
		PartyMaxSize = 3,
		CustomRoomMaxRooms = 12,
	},

	Combat = {
		MaxHealth = 100,
		RewindWindow = 1.0,
		SnapshotRate = 20,
		MaxRewindLatency = 0.4,
		HitboxTolerance = 0.6,
		BackstabDot = 0.5,
		BlockFrontDot = -0.4,
		AssistWindow = 8,
		LongShotDistance = 80,
		HeadshotPartNames = { "Head" },
		MeleeArcDegrees = 110,
		SlideHitboxScale = 0.55,
		StateReplicationRate = 20,
		ProjectileMaxLifetime = 4,
		FireArrowBurnDPS = 6,
		FireArrowBurnDuration = 3,
		ArmorBreakShowSeconds = 1.2,
	},

	Movement = {
		WalkSpeed = 18,
		SprintSpeed = 24,
		SlideBoost = 1.65,
		SlideFriction = 2.8,
		SlideMinSpeed = 10,
		SlideCameraDrop = -2.2,
		SlideCooldown = 0.9,
		HealWalkMultiplier = 0.45,
		DrawWalkMultiplier = 0.7,
	},

	Camera = {
		DefaultFOV = 70,
		MinFOV = 70,
		MaxFOV = 120,
		RightShoulder = Vector3.new(2.5, 1.5, 6.5),
		LeftShoulder = Vector3.new(-2.5, 1.5, 6.5),
	},

	POTG = {
		WindowSeconds = 6,
		FrameRate = 20,
		Weights = {
			Kill = 100,
			MultiKill2 = 1.5,
			MultiKill3 = 2.5,
			Headshot = 50,
			WinningBlow = 80,
			LongShot = 90,
			TeamWipe = 500,
		},
	},

	Rewards = {
		WinShardsMin = 23,
		WinShardsMax = 25,
		LossShardsMin = 12,
		LossShardsMax = 14,
		DropCards = 4,
		XPWin = 120,
		XPLoss = 60,
		XPPerKill = 15,
		XPPerAssist = 6,
		XPMvp = 40,
		XPStreakBonus = 10,
		GloryWin = 25,
		GloryLoss = 15,
		GloryStreakBonus = 3,
	},

	Lobby = {
		PlazaRadius = 70,
		SpawnCount = 12,
		LeaderboardSize = 50,
		LeaderboardRefresh = 60,
	},
}

export type PlaceRole = "Lobby" | "Arena"

function GameConfig.GetPlaceRole(): PlaceRole
	local attr = workspace:GetAttribute("PlaceRole")
	if attr == "Arena" then
		return "Arena"
	end
	if attr == "Lobby" then
		return "Lobby"
	end
	if GameConfig.Places.ArenaPlaceId ~= 0 and game.PlaceId == GameConfig.Places.ArenaPlaceId then
		return "Arena"
	end
	return "Lobby"
end

return GameConfig
