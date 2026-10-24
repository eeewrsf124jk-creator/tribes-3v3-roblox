<!-- 자동 생성 문서: tools/gendocs.luau 가 만듭니다. 직접 고치지 말고 다시 생성하세요. -->

# 월드 인벤토리

빌더 파이프라인(Step 1~4)을 실제로 실행해 만든 결과입니다. CSG 합치기는 엔진 밖에서는 동작하지 않아 용접된 Model로 대체된 상태로 셌습니다. Studio에서는 같은 자리에 Union 하나가 생기므로 파트 수가 이보다 적을 수 있습니다.

## 충돌 그룹 매트릭스

| | MapGeometry | PlayerMovementBox | HitboxParts | Projectiles | DestructibleShields | RagdollLimbs |
|---|---|---|---|---|---|---|
| MapGeometry | 충돌 | 충돌 | 충돌 | 충돌 | 충돌 | 충돌 |
| PlayerMovementBox | 충돌 | - | - | - | 충돌 | - |
| HitboxParts | 충돌 | - | - | 충돌 | - | - |
| Projectiles | 충돌 | - | 충돌 | - | 충돌 | - |
| DestructibleShields | 충돌 | 충돌 | - | 충돌 | - | - |
| RagdollLimbs | 충돌 | - | - | - | - | - |

## Workspace 런타임 폴더

- **AliveCharacters_Alpha** (Folder) · 파트 0
- **AliveCharacters_Bravo** (Folder) · 파트 0
- **ActiveProjectiles_Container** (Folder) · 파트 0
- **DeployedUtilities_Container** (Folder) · 파트 0
- **Ragdolls_And_StuckArrows** (Folder) · 파트 0

## 로비 마을 (Lobby_50Player_World)

전체 파트 1702개. 구성 요소별 개수: Attachment 59, Beam 4, BillboardGui 4, Folder 5, Frame 4, Model 65, Part 1022, ParticleEmitter 24, PointLight 9, ProximityPrompt 5, ScrollingFrame 3, Sound 1, SpawnLocation 12, SurfaceGui 11, TextLabel 15, Trail 3, UICorner 1, UIGradient 3, UIListLayout 3, UIStroke 1, WedgePart 668, WeldConstraint 94

- **VillageGround** (Part) · 파트 1
- **Path* ×4** (Part) · 파트 4
- **SpawnPlaza_Center** (Folder) · 파트 687
  - **CenterDisc** (Part) · 파트 1
  - **TileRing1* ×22** (Part) · 파트 22
  - **TileRing2* ×30** (Part) · 파트 30
  - **TileRing3* ×37** (Part) · 파트 37
  - **TileRing4* ×45** (Part) · 파트 45
  - **TileRing5* ×52** (Part) · 파트 52
  - **TileRing6* ×60** (Part) · 파트 60
  - **TileRing7* ×67** (Part) · 파트 67
  - **TileRing8* ×75** (Part) · 파트 75
  - **TileRing9* ×82** (Part) · 파트 82
  - **TileRing10* ×90** (Part) · 파트 90
  - **PlazaCurb* ×90** (Part) · 파트 90
  - **Fountain** (Model) · 파트 8
    - **Basin** (Part) · 파트 1
    - **BasinWater** (Part) · 파트 1
    - **Column* ×2** (Part) · 파트 2
    - **Bowl* ×2** (Part) · 파트 2
    - **Bowl2Water** (Part) · 파트 1
    - **Spout** (Part) · 파트 1
  - **SpawnLocations** (Folder) · 파트 12
    - **PlazaSpawn* ×12** (SpawnLocation) · 파트 12
  - **LampPost* ×8** (Part) · 파트 8
  - **Lantern* ×8** (Part) · 파트 8
- **Interactive_Booths** (Folder) · 파트 205
  - **Loadout_Stall** (Model) · 파트 98
    - **Floor** (Part) · 파트 1
    - **Counter** (Part) · 파트 1
    - **CounterTop** (Part) · 파트 1
    - **Pole* ×4** (Part) · 파트 4
    - **AwningStripe* ×10** (WedgePart) · 파트 10
    - **Valance* ×10** (Part) · 파트 10
    - **WeaponRack** (Part) · 파트 1
    - **RackPeg* ×2** (Part) · 파트 2
    - **Display_IronSword** (Model) · 파트 10
    - **Display_WoodBow** (Model) · 파트 10
    - **Display_Hammer** (Model) · 파트 16
    - **Display_Crossbow** (Model) · 파트 11
    - **Display_Spear** (Model) · 파트 19
    - **Sign** (Part) · 파트 1
    - **LoadoutZone** (Part) · 파트 1
  - **CustomMatches_Cabin** (Model) · 파트 55
    - **Log* ×38** (Part) · 파트 38
    - **Floor** (Part) · 파트 1
    - **RoofFront** (WedgePart) · 파트 1
    - **RoofBack** (WedgePart) · 파트 1
    - **MatchBoard** (Part) · 파트 1
    - **Campfire** (Model) · 파트 13
  - **TribeHall_Building** (Model) · 파트 52
    - **StoneFront** (Model) · 파트 9
    - **StoneBack** (Model) · 파트 1
    - **StoneSide* ×2** (Model) · 파트 8
    - **UpperFloor** (Part) · 파트 1
    - **UpperWall* ×4** (Part) · 파트 4
    - **Timber* ×18** (Part) · 파트 18
    - **RoofFront** (WedgePart) · 파트 1
    - **RoofBack** (WedgePart) · 파트 1
    - **TribeBanner* ×2** (Part) · 파트 2
    - **HallFloor** (Part) · 파트 1
    - **TribeAltar** (Part) · 파트 1
    - **AltarFlame** (Part) · 파트 1
    - **TribeZone** (Part) · 파트 1
    - **EntranceSteps** (Model) · 파트 3
- **Global_3D_Leaderboards** (Folder) · 파트 15
  - **Board_TopTribes** (Model) · 파트 4
    - **Post* ×2** (Part) · 파트 2
    - **Panel** (Part) · 파트 1
    - **TopTrim** (Part) · 파트 1
  - **Board_MostEliminations** (Model) · 파트 4
    - **Post* ×2** (Part) · 파트 2
    - **Panel** (Part) · 파트 1
    - **TopTrim** (Part) · 파트 1
  - **Board_LongestStreaks** (Model) · 파트 4
    - **Post* ×2** (Part) · 파트 2
    - **Panel** (Part) · 파트 1
    - **TopTrim** (Part) · 파트 1
  - **EliminationStatues** (Model) · 파트 3
    - **Pedestal* ×3** (Part) · 파트 3
- **Mini_1v1_DuelPit_And_Training** (Folder) · 파트 70
  - **LiveDuelArena** (Model) · 파트 21
    - **PitFloor** (Part) · 파트 1
    - **PitWall* ×4** (Part) · 파트 4
    - **PitStairs** (Model) · 파트 11
    - **PitStairOpening** (Part) · 파트 1
    - **DuelPad* ×2** (Part) · 파트 2
    - **DuelZone** (Part) · 파트 1
    - **BillboardPost** (Part) · 파트 1
  - **TargetPracticeRange** (Model) · 파트 49
    - **ShootingLine** (Part) · 파트 1
    - **FiringBench** (Part) · 파트 1
    - **TrainingZone** (Part) · 파트 1
    - **LaneMarker* ×3** (Part) · 파트 3
    - **DummyRail* ×3** (Part) · 파트 3
    - **Dummy_20Studs** (Model) · 파트 12
    - **DistanceSign* ×3** (Part) · 파트 3
    - **Dummy_50Studs** (Model) · 파트 12
    - **Dummy_100Studs** (Model) · 파트 12
    - **Backstop** (Part) · 파트 1
- **PineTree* ×40** (Model) · 파트 720

## 아레나 맵 4종 (ServerStorage.ArenaMapStorage)


### Map_01_WinterTimberFort

속성: Ambient = RGB(150, 165, 190), AtmosphereDensity = 0.38, ClockTime = 9.2, DisplayName = Winter Timber Fort, FogColor = RGB(205, 220, 240), FogEnd = 700, HalfX = 110, HalfZ = 150, SpawnCount = 6, Theme = Winter

전체 파트 2120개. 구성 요소별 개수: Attachment 4, CornerWedgePart 8, Folder 9, Model 80, Part 882, ParticleEmitter 13, PointLight 4, SpecialMesh 18, WedgePart 1230

- **TeamSpawns** (Folder) · 파트 950
  - **Alpha_Citadel** (Folder) · 파트 475
  - **Bravo_Citadel** (Folder) · 파트 475
- **MidLane_FrozenRiverBridge** (Folder) · 파트 59
  - **FrozenRiver** (Part) · 파트 1
  - **BankAlpha** (WedgePart) · 파트 1
  - **BankBravo** (WedgePart) · 파트 1
  - **BridgeDeck** (Part) · 파트 1
  - **DeckBeam* ×7** (Part) · 파트 7
  - **BridgePillar* ×6** (Part) · 파트 6
  - **RailingPlanks* ×2** (Part) · 파트 2
  - **RailingTopLog* ×2** (Part) · 파트 2
  - **RailPost* ×18** (Part) · 파트 18
  - **Rock* ×4** (Model) · 파트 20
- **SideLanes_Watchtowers** (Folder) · 파트 288
  - **Watchtower_Alpha_L** (Model) · 파트 72
  - **Watchtower_Alpha_R** (Model) · 파트 72
  - **Watchtower_Bravo_L** (Model) · 파트 72
  - **Watchtower_Bravo_R** (Model) · 파트 72
- **CoverAndProps** (Folder) · 파트 800
  - **PineTree* ×16** (Model) · 파트 544
  - **Crate* ×14** (Model) · 파트 182
  - **LogBarricade* ×8** (Model) · 파트 56
  - **SnowDrift* ×18** (Part) · 파트 18
- **Shared_Map_Mechanics** (Folder) · 파트 21
  - **Invisible_ClipBrushes** (Folder) · 파트 19
  - **RingOfFire_BoundaryCylinder** (Model) · 파트 1
  - **POTG_CinematicStage** (Model) · 파트 1
- **SnowField* ×2** (Part) · 파트 2

### Map_02_DesertColosseum

속성: Ambient = RGB(190, 160, 120), AtmosphereDensity = 0.3, ClockTime = 15.5, DisplayName = Desert Colosseum, FogColor = RGB(235, 210, 170), FogEnd = 900, HalfX = 110, HalfZ = 150, SpawnCount = 6, Theme = Desert

전체 파트 579개. 구성 요소별 개수: Attachment 4, Folder 9, Model 57, Part 551, ParticleEmitter 5, PointLight 4, SpecialMesh 10, WedgePart 28

- **TeamSpawns** (Folder) · 파트 90
  - **Alpha_Portico** (Folder) · 파트 45
  - **Bravo_Portico** (Folder) · 파트 45
- **MidLane_SwordMonument** (Folder) · 파트 121
  - **AltarTier* ×2** (Part) · 파트 2
  - **AltarInlay** (Part) · 파트 1
  - **AltarTop** (Part) · 파트 1
  - **Rubble* ×6** (WedgePart) · 파트 6
  - **SwordStatue** (Model) · 파트 7
  - **GlyphBlock* ×8** (Model) · 파트 104
- **SideLanes_CyanDomeTemples** (Folder) · 파트 138
  - **CyanDomeTemple_West** (Model) · 파트 69
  - **CyanDomeTemple_East** (Model) · 파트 69
- **CoverAndProps** (Folder) · 파트 190
  - **BrokenColumn* ×12** (Model) · 파트 48
  - **PalmTree* ×8** (Model) · 파트 112
  - **ClayPot* ×10** (Model) · 파트 30
- **Shared_Map_Mechanics** (Folder) · 파트 7
  - **Invisible_ClipBrushes** (Folder) · 파트 5
  - **RingOfFire_BoundaryCylinder** (Model) · 파트 1
  - **POTG_CinematicStage** (Model) · 파트 1
- **ArenaSand** (Part) · 파트 1
- **ColosseumWall* ×4** (Part) · 파트 4
- **BlindArch* ×28** (Part) · 파트 28

### Map_03_HighlandHenge

속성: Ambient = RGB(140, 150, 140), AtmosphereDensity = 0.42, ClockTime = 17.2, DisplayName = Highland Henge, FogColor = RGB(190, 205, 210), FogEnd = 650, HalfX = 110, HalfZ = 150, SpawnCount = 6, Theme = Highland

전체 파트 475개. 구성 요소별 개수: Attachment 2, CornerWedgePart 40, Folder 9, Model 58, Part 381, ParticleEmitter 7, PointLight 2, WedgePart 54

- **TeamSpawns** (Folder) · 파트 196
  - **Alpha_Cottage** (Folder) · 파트 98
  - **Bravo_Cottage** (Folder) · 파트 98
- **MidLane_StonehengeRing** (Folder) · 파트 41
  - **Monolith* ×8** (Model) · 파트 16
  - **Lintel* ×4** (Part) · 파트 4
  - **AltarStone** (Part) · 파트 1
  - **Rock* ×4** (Model) · 파트 20
- **SideLanes_CoastalTrenchAndWall** (Folder) · 파트 111
  - **CoastalChannel** (Model) · 파트 2
  - **ChannelBankEast** (WedgePart) · 파트 1
  - **ChannelBankWest** (WedgePart) · 파트 1
  - **Rock* ×6** (Model) · 파트 30
  - **StoneWall* ×7** (Model) · 파트 77
- **CoverAndProps** (Folder) · 파트 118
  - **Rock* ×10** (Model) · 파트 60
  - **Cart* ×4** (Model) · 파트 28
  - **HayBale* ×10** (Part) · 파트 10
  - **BaleTwine* ×20** (Part) · 파트 20
- **Shared_Map_Mechanics** (Folder) · 파트 7
  - **Invisible_ClipBrushes** (Folder) · 파트 5
  - **RingOfFire_BoundaryCylinder** (Model) · 파트 1
  - **POTG_CinematicStage** (Model) · 파트 1
- **Plateau** (Part) · 파트 1
- **Shore** (Part) · 파트 1

### Map_04_IcefallFjord

속성: Ambient = RGB(140, 160, 185), AtmosphereDensity = 0.45, ClockTime = 11, DisplayName = Icefall Fjord, FogColor = RGB(200, 220, 235), FogEnd = 600, HalfX = 110, HalfZ = 150, SpawnCount = 6, Theme = Fjord

전체 파트 670개. 구성 요소별 개수: Attachment 17, Beam 8, CornerWedgePart 72, Folder 9, Model 80, Part 514, ParticleEmitter 13, PointLight 2, WedgePart 84

- **TeamSpawns** (Folder) · 파트 106
  - **Alpha_Dock** (Folder) · 파트 53
  - **Bravo_Dock** (Folder) · 파트 53
- **MidLane_GroundedShipwreck** (Folder) · 파트 77
  - **GroundedShipwreck** (Model) · 파트 57
  - **Rock* ×4** (Model) · 파트 20
- **SideLanes_RedWarehouses** (Folder) · 파트 236
  - **RedWarehouse_West** (Model) · 파트 118
  - **RedWarehouse_East** (Model) · 파트 118
- **CoverAndProps** (Folder) · 파트 124
  - **Rock* ×10** (Model) · 파트 50
  - **FishBarrel* ×10** (Model) · 파트 50
  - **RopeCoil* ×24** (Part) · 파트 24
- **Shared_Map_Mechanics** (Folder) · 파트 7
  - **Invisible_ClipBrushes** (Folder) · 파트 5
  - **RingOfFire_BoundaryCylinder** (Model) · 파트 1
  - **POTG_CinematicStage** (Model) · 파트 1
- **FrozenShore** (Part) · 파트 1
- **Rock* ×22** (Model) · 파트 110
- **IcefallBackdrop** (Model) · 파트 9
  - **GlacierWall** (Part) · 파트 1
  - **MistEmitter* ×6** (Part) · 파트 6
  - **EastCliff** (Part) · 파트 1
  - **EastCliffSnow** (Part) · 파트 1

## 장비 프리팹 (ReplicatedStorage.Procedural_3D_Weapon_And_Armor_Prefabs)


### Ranged_Weapon_Models

| 모델 | 파트 | 장착 부위 | Attachment |
|---|---|---|---|
| WoodBow_Model | 10 | RightHand | MuzzleAttachment, StringAttachment, StringBottom, StringTop |
| Crossbow_Model | 11 | RightHand | MuzzleAttachment, StringAttachment, StringBottom, StringTop |
| Headhunter_Model | 17 | RightHand | MuzzleAttachment, StringAttachment, StringBottom, StringTop |
| Flintlock_Model | 19 | RightHand | MuzzleAttachment, StringAttachment |
| Blunderbuss_Model | 16 | RightHand | MuzzleAttachment, StringAttachment |
| Musket_Model | 20 | RightHand | MuzzleAttachment, StringAttachment |
| Sling_Model | 4 | RightHand | MuzzleAttachment, StrapBottomL, StrapBottomR, StrapTopL, StrapTopR, StringAttachment |
| ThrowingKnives_Model | 33 | RightHand | MuzzleAttachment, StringAttachment |
| Javelins_Model | 8 | RightHand | MuzzleAttachment, StringAttachment |
| Harpoon_Model | 14 | RightHand | MuzzleAttachment, RopeEnd, RopeStart, StringAttachment |
| Bolas_Model | 7 | RightHand | Knot, MuzzleAttachment, RopeEnd, StringAttachment |
| Chakram_Model | 41 | RightHand | MuzzleAttachment, StringAttachment |

### Melee_Weapon_Models

| 모델 | 파트 | 장착 부위 | Attachment |
|---|---|---|---|
| Ranked_Melees | 95 | - | BottomAttachment, DmgPoint, TopAttachment |
| DiamondDagger_Model | 11 | RightHand | BottomAttachment, DmgPoint, TopAttachment |
| IronSword_Model | 10 | RightHand | BottomAttachment, DmgPoint, TopAttachment |
| Hammer_Model | 16 | RightHand | BottomAttachment, DmgPoint, TopAttachment |
| BattleAxe_Model | 44 | RightHand | BottomAttachment, DmgPoint, TopAttachment |
| Spear_Model | 19 | RightHand | BottomAttachment, DmgPoint, TopAttachment |
| Shield_Model | 31 | LeftLowerArm | ArrowStickPoint |

### Utility_And_Healing_Models

| 모델 | 파트 | 장착 부위 | Attachment |
|---|---|---|---|
| SmokeBomb_Model | 39 | RightHand | FuseSpark, MuzzleAttachment |
| SnapTrap_Model | 20 | RightHand |  |
| Fireball_Model | 2 | RightHand | FlameCore, MuzzleAttachment |
| Palisade_Model | 39 | RightHand |  |
| WarHorn_Model | 21 | RightHand | MuzzleAttachment, StrapA, StrapB |
| Bandage_Model | 5 | RightHand |  |
| Apple_Model | 3 | RightHand |  |
| GoldenApple_Model | 4 | RightHand | Sparkle |
| HealingFlask_Model | 16 | RightHand | MuzzleAttachment |

### Wearable_Armor_Models

| 모델 | 파트 | 장착 부위 | Attachment |
|---|---|---|---|
| LeatherArmor_Model | 19 | - |  |
| IronArmor_Model | 18 | - |  |
| DiamondArmor_Model | 26 | - |  |

## VFX 템플릿 (ReplicatedStorage.VFX_And_Particle_Templates)


### ProjectileTrails

| 템플릿 | 종류 | 구성 |
|---|---|---|
| ArrowWindTrail | Trail |  |
| BulletTracer | Trail |  |
| ChakramArc | Trail |  |
| Carrier | Part | Attachment 1, ParticleEmitter 2 |

### ImpactEffects

| 템플릿 | 종류 | 구성 |
|---|---|---|
| Carrier | Part | Attachment 8, ParticleEmitter 13 |

### StatusAndAreaEffects

| 템플릿 | 종류 | 구성 |
|---|---|---|
| SmokeCloud_Emitter | Part | ParticleEmitter 2 |
| Carrier | Part | Attachment 3, ParticleEmitter 4 |
| WarHorn_Pulse | Part |  |
| WarHorn_RevealHighlight | Highlight |  |
| Stagger_Stars | BillboardGui | Frame 1, TextLabel 3 |
| FirePatch | Part | ParticleEmitter 1, PointLight 1 |

### KillConfirmationVFX

| 템플릿 | 종류 | 구성 |
|---|---|---|
| Carrier | Part | Attachment 1, ParticleEmitter 2 |
| SkullBillboard | BillboardGui | TextLabel 1 |

### ProjectileBodies

| 템플릿 | 종류 | 구성 |
|---|---|---|
| Arrow | Model | Attachment 2, Part 5, WedgePart 4, WeldConstraint 8 |
| Bolt | Model | Attachment 2, Part 2, WedgePart 4, WeldConstraint 5 |
| Bullet | Model | Attachment 2, Part 2, WeldConstraint 1 |
| Stone | Model | Attachment 2, Part 2, WeldConstraint 1 |
| Knife | Model | Attachment 2, Part 3, WedgePart 4, WeldConstraint 6 |
| Javelin | Model | Attachment 2, Part 2, WedgePart 4, WeldConstraint 5 |
| HarpoonBolt | Model | Attachment 3, Part 2, WedgePart 4, WeldConstraint 5 |
| ChakramDisc | Model | Attachment 2, Part 29, WeldConstraint 28 |
| BolasThrown | Model | Attachment 2, Part 8, WeldConstraint 7 |
| SmokeBombThrown | Model | Attachment 2, Part 2, WeldConstraint 1 |
| FireballThrown | Model | Attachment 3, Part 2, ParticleEmitter 1, PointLight 1, WeldConstraint 1 |
| FlaskThrown | Model | Attachment 2, Part 2, WeldConstraint 1 |
