--!strict
-- Shared type vocabulary used by both the server services and the client controllers.

export type TeamName = "Alpha" | "Bravo" | "Neutral"

export type Category = "WEAPONS" | "UTILITY" | "HEALING" | "ARMOR"

export type SubType = "BOW" | "GUN" | "THROWABLE" | "MELEE" | "SHIELD" | "NONE"

export type AmmoKind = "Arrows" | "Bullets" | "FireArrows"

export type EquipmentSpec = {
	Id: string,
	DisplayName: string,
	Description: string,
	Category: Category,
	SubType: SubType,
	Cost: number,
	ModelName: string,
	HotbarHint: string,
	RankedOnly: boolean?,
	UnlockShards: number?,
	RobuxCost: number?,
	AmmoType: string?,
	MaxStack: number?,
	BaseDmg: number?,
	HeadMult: number?,
	DrawTime: number?,
	ChargeTime: number?,
	ReloadTime: number?,
	Cooldown: number?,
	ProjectileSpeed: number?,
	GravityScale: number?,
	ZoomFOV: number?,
	PostShotSlow: number?,
	PelletCount: number?,
	PelletDmg: number?,
	SpreadAngle: number?,
	FalloffStart: number?,
	BounceCount: number?,
	ReturnToSender: boolean?,
	Catchable: boolean?,
	SnareDuration: number?,
	SnareSpeedMult: number?,
	PullForce: number?,
	SwingRate: number?,
	Range: number?,
	WalkSpeedBonus: number?,
	CanBlock: boolean?,
	BlockDamageReduction: number?,
	BackstabMultiplier: number?,
	BackstabInstantKill: boolean?,
	KnockbackImpulse: number?,
	StaggerDuration: number?,
	OverheadDmg: number?,
	ArmorShredRatio: number?,
	ShieldHealth: number?,
	BlocksProjectiles: boolean?,
	Radius: number?,
	Duration: number?,
	TriggerRadius: number?,
	Damage: number?,
	RootDuration: number?,
	WallHealth: number?,
	Size: Vector3?,
	RevealDuration: number?,
	TeamSpeedBoost: number?,
	ImpactDmg: number?,
	BurnDPS: number?,
	BurnDuration: number?,
	HealAmount: number?,
	CastTime: number?,
	SplashRadius: number?,
	ArmorHP: number?,
	RangedDmgReduction: number?,
	MeleeDmgReduction: number?,
	SpeedPenalty: number?,
	KnockbackResist: number?,
	ZoomFOVAds: number?,
}

-- A loadout preset as stored in the profile and sent over the network.
export type Loadout = {
	Name: string,
	Slots: { string }, -- up to 6 item ids, hotbar order
	Armor: string?, -- at most one armor id
	Ammo: { Arrows: number, Bullets: number, FireArrows: number }, -- bundles purchased
}

export type ValidationResult = {
	Ok: boolean,
	Points: number,
	Slots: number,
	Errors: { string },
}

export type PlayerSettings = {
	CameraSensitivity: number,
	FieldOfView: number,
	ViewBobbing: boolean,
	PreventFullBotMatches: boolean,
	FirstPersonDefault: boolean,
}

export type Profile = {
	Version: number,
	Level: number,
	XP: number,
	WinStreak: number,
	BestStreak: number,
	LastLostStreak: number,
	GloryRP: number,
	TribeId: string?,
	Kills: number,
	Deaths: number,
	Wins: number,
	Losses: number,
	Shards: { [string]: number },
	UnlockedItems: { [string]: number },
	Presets: { Loadout },
	ActivePreset: number,
	GoldenDropPurchased: boolean,
	MatchesPlayed: number,
	Settings: PlayerSettings,
	ProcessedReceipts: { string },
}

export type RoundPhase =
	"Waiting"
	| "PreMatchVS"
	| "PreRoundLoadout"
	| "ActiveCombat"
	| "RoundEndBanner"
	| "POTGReplay"
	| "VictoryDropAndSummary"

export type RosterEntry = {
	Id: string,
	Name: string,
	UserId: number,
	Team: TeamName,
	IsBot: boolean,
	Kills: number,
	Deaths: number,
	Assists: number,
	Damage: number,
	Alive: boolean,
}

export type RoundState = {
	MatchId: string,
	Mode: string,
	Kind: string,
	Phase: RoundPhase,
	PhaseEndsAt: number,
	Round: number,
	Score: { Alpha: number, Bravo: number },
	MapName: string,
	Roster: { RosterEntry },
	Banner: string?,
	WinningTeam: TeamName?,
	RingRadius: number,
	RingActive: boolean,
	RingCenter: Vector3,
	RingShrinkStartsAt: number, -- server time; 0 while the ring is idle
	RingShrinkDuration: number,
	RingStartRadius: number,
	BannerTags: { string }?,
	RoundWinner: TeamName?,
}

export type DropCard = {
	ItemId: string,
	Shards: number,
	NewUnlock: boolean,
	UpgradeReady: boolean,
}

export type MatchSummary = {
	WinningTeam: TeamName,
	Score: { Alpha: number, Bravo: number },
	Roster: { RosterEntry },
	MvpId: string,
	Drop: { DropCard },
	TotalShards: number,
	XPBreakdown: { { Label: string, Amount: number } },
	LevelBefore: number,
	LevelAfter: number,
	XPBefore: number,
	XPAfter: number,
	XPNeeded: number,
	GloryDelta: number, -- this player's Glory change (0 outside ranked)
	PlayAgainSeconds: number,
}

export type POTGActorFrame = { number } -- {t, x, y, z, yaw, pitch, flags}

export type POTGEvent = {
	T: number,
	Kind: "Shot" | "Kill" | "Swing" | "Hit" | "Equip",
	ActorId: string,
	TargetId: string?,
	Origin: Vector3?,
	Velocity: Vector3?,
	Gravity: number?,
	WeaponId: string?,
	Position: Vector3?,
}

export type POTGPacket = {
	PlayerName: string,
	ActorId: string,
	Tags: { string },
	Score: number,
	Duration: number,
	FrameRate: number,
	Actors: { [string]: { Name: string, Team: TeamName, UserId: number } },
	Frames: { [string]: { POTGActorFrame } },
	Events: { POTGEvent },
}

export type DamageReport = {
	VictimId: string,
	AttackerId: string?,
	Amount: number,
	ArmorAmount: number,
	Position: Vector3,
	Headshot: boolean,
	ArmorBroken: boolean,
	Staggered: boolean,
	Blocked: boolean,
	Killed: boolean,
	WeaponId: string,
}

export type InventorySlot = { ItemId: string, Count: number, Level: number }

-- Per-combatant inventory snapshot pushed to the owning client on every change.
export type InventoryView = {
	Context: string,
	Slots: { InventorySlot },
	Equipped: number,
	Ammo: { Arrows: number, Bullets: number, FireArrows: number },
	UseFireArrows: boolean,
	ArmorId: string?,
	Armor: number,
	ArmorMax: number,
	ShieldHP: number,
	ShieldMax: number,
}

export type CombatEventKind = "Damage" | "Kill" | "ArmorBroken" | "Blocked" | "ShieldBroken" | "Status" | "Healed"

export type CombatEventPacket = {
	Kind: CombatEventKind,
	Report: DamageReport?,
	KillerId: string?,
	KillerName: string?,
	VictimId: string?,
	VictimName: string?,
	WeaponId: string?,
	KillerHP: number?,
	Headshot: boolean?,
	Status: string?,
	Duration: number?,
	TargetId: string?,
	Amount: number?,
	Position: Vector3?,
}

export type PartyView = { Leader: number, Members: { { UserId: number, Name: string } }, Queued: boolean, QueueStartedAt: number }

export type RoomView = {
	Id: string,
	Name: string,
	Mode: string,
	HostId: number,
	FillBots: boolean,
	Alpha: { { UserId: number, Name: string } },
	Bravo: { { UserId: number, Name: string } },
	TeamSize: number,
}

return {}
