<!-- 자동 생성 문서: tools/gendocs.luau 가 만듭니다. 직접 고치지 말고 다시 생성하세요. -->

# 설정값 레퍼런스

## GameConfig

`src/ReplicatedStorage/Modules/Config/GameConfig.luau`

### GameConfig

| 키 | 값 |
|---|---|
| RoundsToWin | 3 |
| TeamSize | 3 |

### GameConfig.Camera

| 키 | 값 |
|---|---|
| DefaultFOV | 70 |
| LeftShoulder | (-2.5, 1.5, 6.5) |
| MaxFOV | 120 |
| MinFOV | 70 |
| RightShoulder | (2.5, 1.5, 6.5) |

### GameConfig.Combat

| 키 | 값 |
|---|---|
| ArmorBreakShowSeconds | 1.2 |
| AssistWindow | 8 |
| BackstabDot | 0.5 |
| BlockFrontDot | -0.4 |
| FireArrowBurnDPS | 6 |
| FireArrowBurnDuration | 3 |
| HeadshotPartNames | { Head } |
| HitboxTolerance | 0.6 |
| LongShotDistance | 80 |
| MaxHealth | 100 |
| MaxRewindLatency | 0.4 |
| MeleeArcDegrees | 110 |
| ProjectileMaxLifetime | 4 |
| RewindWindow | 1 |
| SlideHitboxScale | 0.55 |
| SnapshotRate | 20 |
| StateReplicationRate | 20 |

### GameConfig.Lobby

| 키 | 값 |
|---|---|
| LeaderboardRefresh | 60 |
| LeaderboardSize | 50 |
| PlazaRadius | 70 |
| SpawnCount | 12 |

### GameConfig.Matchmaking

| 키 | 값 |
|---|---|
| ArenaWaitForPlayersSeconds | 20 |
| BotFillAfterSeconds | 15 |
| CustomRoomMaxRooms | 12 |
| PartyMaxSize | 3 |

### GameConfig.Movement

| 키 | 값 |
|---|---|
| DrawWalkMultiplier | 0.7 |
| HealWalkMultiplier | 0.45 |
| SlideBoost | 1.65 |
| SlideCameraDrop | -2.2 |
| SlideCooldown | 0.9 |
| SlideFriction | 2.8 |
| SlideMinSpeed | 10 |
| SprintSpeed | 24 |
| WalkSpeed | 18 |

### GameConfig.POTG

| 키 | 값 |
|---|---|
| FrameRate | 20 |
| WindowSeconds | 6 |

### GameConfig.POTG.Weights

| 키 | 값 |
|---|---|
| Headshot | 50 |
| Kill | 100 |
| LongShot | 90 |
| MultiKill2 | 1.5 |
| MultiKill3 | 2.5 |
| TeamWipe | 500 |
| WinningBlow | 80 |

### GameConfig.Phases

| 키 | 값 |
|---|---|
| ActiveCombat | 60 |
| POTGReplay | 8 |
| PreMatchVS | 6 |
| PreRoundLoadout | 5 |
| RoundEndBanner | 4 |
| VictoryDropAndSummary | 25 |

### GameConfig.Places

| 키 | 값 |
|---|---|
| ArenaMaxPlayers | 6 |
| ArenaPlaceId | 0 |
| LobbyMaxPlayers | 50 |
| LobbyPlaceId | 0 |

### GameConfig.Rewards

| 키 | 값 |
|---|---|
| DropCards | 4 |
| GloryLoss | 15 |
| GloryStreakBonus | 3 |
| GloryWin | 25 |
| LossShardsMax | 14 |
| LossShardsMin | 12 |
| WinShardsMax | 25 |
| WinShardsMin | 23 |
| XPLoss | 60 |
| XPMvp | 40 |
| XPPerAssist | 6 |
| XPPerKill | 15 |
| XPStreakBonus | 10 |
| XPWin | 120 |

### GameConfig.Ring

| 키 | 값 |
|---|---|
| EndRadius | 0 |
| Height | 120 |
| ShrinkDuration | 30 |
| StartRadius | 180 |
| TickDamage | 10 |
| TickInterval | 0.5 |

## 유료 상품 (MonetizationCatalog)

ProductId가 0이면 "미설정"으로 표시되고 구매 창이 뜨지 않습니다.

| Key | 종류 | 가격 (R$) | 표시 이름 | Tier | ProductId |
|---|---|---|---|---|---|
| GoldenDrop | GoldenDrop | 9 | Golden Drop |  | 0 |
| RestoreStreakSmall | RestoreStreak | 20 | Restore Streak (1-4) | 4 | 0 |
| RestoreStreakMedium | RestoreStreak | 39 | Restore Streak (5-9) | 9 | 0 |
| RestoreStreakLarge | RestoreStreak | 79 | Restore Streak (10+) | 무제한 | 0 |
| ItemUnlock399 | ItemUnlock | 399 | Instant Unlock (Tier 1) | 399 | 0 |
| ItemUnlock599 | ItemUnlock | 599 | Instant Unlock (Tier 2) | 599 | 0 |
| ItemUnlock799 | ItemUnlock | 799 | Instant Unlock (Tier 3) | 799 | 0 |
| TribeCreation | TribeCreation | 299 | Found a Tribe |  | 0 |

## 업그레이드와 레벨 (UpgradeScalingMath)

| 레벨 | 다음 레벨까지 샤드 | 누적 샤드 | 능력치 배율 (복리) | 배율 (선형) | 계정 XP (다음 레벨) |
|---|---|---|---|---|---|
| 1 | 10 | 0 | 1 | 1 | 250 |
| 2 | 20 | 10 | 1.04 | 1.04 | 574 |
| 3 | 40 | 30 | 1.0816 | 1.08 | 934 |
| 4 | 80 | 70 | 1.1249 | 1.12 | 1319 |
| 5 | 160 | 150 | 1.1699 | 1.16 | 1724 |
| 6 | 320 | 310 | 1.2167 | 1.2 | 2146 |
| 7 | 640 | 630 | 1.2653 | 1.24 | 2582 |
| 8 | 1280 | 1270 | 1.3159 | 1.28 | 3031 |
| 9 | 2560 | 2550 | 1.3686 | 1.32 | 3491 |
| 10 | MAX | 5110 | 1.4233 | 1.36 | 3962 |

## 사운드 큐 (SoundCatalog)

| 큐 | 파일 | 볼륨 | 피치 |
|---|---|---|---|
| ArmorBreak | `rbxasset://sounds/impact_water.mp3` | 0.9 | 2 |
| Block | `rbxasset://sounds/action_footsteps_plastic.mp3` | 1 | 3 |
| BlunderbussFire | `rbxasset://sounds/action_jump_land.mp3` | 1.4 | 0.55 |
| BowDraw | `rbxasset://sounds/action_falling.ogg` | 0.25 | 2.2 |
| BowRelease | `rbxasset://sounds/action_get_up.mp3` | 0.6 | 1.8 |
| CardFlip | `rbxasset://sounds/action_get_up.mp3` | 0.5 | 2.4 |
| ChestOpen | `rbxasset://sounds/impact_water.mp3` | 0.8 | 1.5 |
| ChestShake | `rbxasset://sounds/action_jump_land.mp3` | 0.6 | 1.1 |
| Countdown | `rbxasset://sounds/action_footsteps_plastic.mp3` | 0.8 | 2 |
| CrossbowFire | `rbxasset://sounds/action_jump_land.mp3` | 0.8 | 1.9 |
| Death | `rbxasset://sounds/uuhhh.mp3` | 0.8 | 1 |
| Explosion | `rbxasset://sounds/action_jump_land.mp3` | 1.4 | 0.4 |
| Fight | `rbxasset://sounds/action_jump.mp3` | 1 | 0.9 |
| FireballWhoosh | `rbxasset://sounds/action_falling.ogg` | 0.8 | 0.7 |
| Fountain | `rbxasset://sounds/action_swim.mp3` | 0.25 | 0.8 |
| GunFire | `rbxasset://sounds/action_jump_land.mp3` | 1.2 | 0.75 |
| Heal | `rbxasset://sounds/action_swim.mp3` | 0.5 | 1.6 |
| HitArmor | `rbxasset://sounds/action_footsteps_plastic.mp3` | 0.9 | 2.4 |
| HitFlesh | `rbxasset://sounds/action_jump_land.mp3` | 0.7 | 1.4 |
| HitHeadshot | `rbxasset://sounds/action_jump_land.mp3` | 1 | 2.2 |
| Hitmarker | `rbxasset://sounds/action_footsteps_plastic.mp3` | 0.5 | 3.2 |
| Kill | `rbxasset://sounds/action_jump.mp3` | 0.9 | 1.6 |
| RingTick | `rbxasset://sounds/action_falling.ogg` | 0.35 | 0.5 |
| Slide | `rbxasset://sounds/action_falling.ogg` | 0.4 | 1.3 |
| SmokePop | `rbxasset://sounds/impact_water.mp3` | 0.8 | 0.6 |
| Splash | `rbxasset://sounds/impact_water.mp3` | 0.7 | 1 |
| SwingHeavy | `rbxasset://sounds/action_get_up.mp3` | 0.7 | 1.2 |
| SwingLight | `rbxasset://sounds/action_get_up.mp3` | 0.5 | 2.1 |
| Throw | `rbxasset://sounds/action_get_up.mp3` | 0.5 | 1.5 |
| TrapSnap | `rbxasset://sounds/action_jump_land.mp3` | 1.2 | 2.6 |
| UIClick | `rbxasset://sounds/action_footsteps_plastic.mp3` | 0.4 | 2.8 |
| UIConfirm | `rbxasset://sounds/action_jump.mp3` | 0.5 | 2 |
| WarHorn | `rbxasset://sounds/action_falling.ogg` | 1 | 0.35 |
| WaterWade | `rbxasset://sounds/action_swim.mp3` | 0.5 | 1 |
