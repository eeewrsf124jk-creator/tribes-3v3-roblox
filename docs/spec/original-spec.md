# 원본 명세

프로젝트를 시작할 때 받은 요청을 그대로 보관합니다. 모델 이름만 지웠고, 나머지 글자는 바꾸지 않았습니다. 이 명세가 실제로 어떻게 구현됐는지, 어디가 달라졌는지는 [13번 문서](../13-spec-traceability.md)에 있습니다.

```text
[ROBLOX STUDIO MCP / ROJO DIRECT EXECUTION PROMPT]
* 역할(Role): Roblox Studio 수석 게임 엔진 아키텍트 및 3D 프로시저럴 빌더
* 목표(Objective): 아래 명세된 'Tribes 3v3' 마스터 데이터모델(DataModel) 트리를 기반으로, 코드 생략(TODO, Placeholder) 없이 모든 폴더, 스크립트(.luau), UI(ScreenGui), 3D 무기/맵 지오메트리(Part/MeshPart/WeldConstraint), 파티클(VFX), 물리 제약조건(Constraints)을 Roblox Studio 내에 100% 자동 생성 및 구현하라[cite: 1, 2].
* 아키텍처 규칙(Strict Rules):
  1. 타입 안전성: 모든 스크립트 최상단에 `--!strict`를 선언하고 Luau 타입을 명시할 것.
  2. 프레임워크: 단일 진입점(Single-Script Architecture: `ServerMain` / `ClientMain`) 구조를 엄수할 것[cite: 2].
  3. 3D 모델 및 맵 생성: 외부 에셋 ID가 없는 모든 무기 모형과 4대 아레나 맵은 `Part`, `WedgePart`, `CornerWedgePart`, `Cylinder`, `SpecialMesh`, `UnionOperation`, `WeldConstraint`, `Motor6D`를 조합한 프로시저럴 생성 스크립트(`BuilderModules`)를 통해 스튜디오에 즉시 조립할 것.
  4. UI 생성: 모든 `ScreenGui`는 `UDim2` 스케일(Scale) 기반 반응형 레이아웃, `UICorner`, `UIStroke`, `UIGradient`, `UIListLayout`, `UIGridLayout`, `UIAspectRatioConstraint` 속성을 수치까지 정확히 지정해 생성할 것.
================================================================================

Tribes3v3_RobloxStudio_Master_DataModel/
│
├── 00_Project_Configuration_And_Rojo_Sync/          -- 스튜디오 동기화 및 플레이스 설정
│   ├── default.project.json                         -- Rojo 루트 매핑 (Workspace, ReplicatedStorage, ServerScriptService, StarterGui, StarterPlayer, SoundService, Lighting)
│   └── Place_Architecture_Config/                   -- 2-Place 멀티 서버 아키텍처 정의
│       ├── Place_1_LobbyAndHub (MaxPlayers: 50)     -- 소셜 로비, 매치메이킹 큐, 부족 회관, 훈련장 호스팅[cite: 1]
│       └── Place_2_CombatArena (MaxPlayers: 6)      -- `TeleportService:ReserveServer()` 기반 3v3(Best of 5) 격리 매치 서버[cite: 1]
│
├── 01_Workspace (월드, 물리 그룹, 맵, 런타임 객체)/
│   ├── Properties/                                  -- `Gravity = 196.2`, `FallenPartsDestroyHeight = -500`, `StreamingEnabled = true`, `SignalBehavior = Deferred`
│   ├── CollisionGroups_Setup/                       -- `PhysicsService` 기반 6대 충돌 매트릭스
│   │   ├── [Group 1] MapGeometry                    -- 벽, 바닥, 지붕, 바리케이드(Palisade) (모든 그룹과 충돌)
│   │   ├── [Group 2] PlayerMovementBox              -- 캐릭터 `HumanoidRootPart` 충돌 캡슐 (`MapGeometry`, `DestructibleShields`와만 충돌 / 아군·적군 캐릭터 간 끼임 방지 통과)
│   │   ├── [Group 3] HitboxParts                    -- 캐릭터 부위별 피격 판정 파트 (`CanCollide = false`, `CanQuery = true`, 레이캐스트 전용)
│   │   ├── [Group 4] Projectiles                    -- 화살, 석궁 볼트, 총탄, 투척 단검, 볼라, 차크람 (`HitboxParts`, `MapGeometry`, `DestructibleShields`와만 쿼리)
│   │   ├── [Group 5] DestructibleShields            -- 방패(Shield) 콜리전 및 나무 성벽(Palisade)
│   │   └── [Group 6] RagdollLimbs                   -- 사망 후 분리된 사지 물리 파트 (`MapGeometry`와만 충돌, 생존 플레이어 이동 방해 차단)
│   │
│   ├── Lobby_50Player_World/                        -- 50인 대기실 마을 맵 구조 (Lobby Place 전용)[cite: 1]
│   │   ├── SpawnPlaza_Center                        -- 원형 석재 타일 광장 + 중앙 3단 물 분수대(`ParticleEmitter` 물줄기) + 12개 `SpawnLocation`
│   │   ├── Interactive_Booths/                      -- `ProximityPrompt` 및 구역 트리거 연동 상점/부스
│   │   │   ├── Loadout_Stall                        -- 파란/흰색 줄무늬 천막 부스 + 무기 거치대 프롭 + 접근 시 `[B] Loadout Builder` UI 오픈
│   │   │   ├── CustomMatches_Cabin                  -- 통나무 오두막 부스 + 커스텀 내전(1v1/2v2/3v3) 방 생성 UI 오픈
│   │   │   └── TribeHall_Building                   -- 대형 석조/목조 부족 회관 + 부족 창설/가입 인터페이스 트리거
│   │   ├── Global_3D_Leaderboards/                  -- `SurfaceGui` 기반 실시간 랭킹 전광판 3종
│   │   │   ├── Board_TopTribes                      -- [TOP TRIBES] 주간 클랜 Glory(RP) 합산 1~50위 스크롤 보드
│   │   │   ├── Board_MostEliminations               -- [MOST ELIMINATIONS] 누적 킬 랭킹 + 1~3위 플레이어 3D 아바타 동상(`HumanoidDescription` 적용)
│   │   │   └── Board_LongestStreaks                 -- [LONGEST STREAKS] 최고 연승(🔥) 기록 보유자 명예의 전당 보드
│   │   └── Mini_1v1_DuelPit_And_Training/           -- 대기 중 실시간 몸풀기 구역
│   │       ├── LiveDuelArena                        -- 로비 내 1v1 결투장 (상단 `[XX LIVE]` 빌보드 표시)
│   │       └── TargetPracticeRange                  -- 거리별(20/50/100 Studs) 움직이는 허수아비 더미 (화살 낙차 및 헤드샷 데미지 테스트용)
│   │
│   ├── Arena_Maps_Pool (4대 대칭형 3v3 전술 맵)/    -- 매치 시작 시 1개 맵이 선택되어 로드되는 전술 경기장
│   │   ├── Map_01_WinterTimberFort (설원 목조 요새)/
│   │   │   ├── TeamSpawns                           -- Alpha/Bravo 통나무 성채 내부 스폰 패드 (각 3개) + 모닥불(`PointLight` + 불꽃 파티클) + 스폰 보호막
│   │   │   ├── MidLane_FrozenRiverBridge            -- 얼어붙은 강 위를 가로지르는 중앙 목조 다리(Bridge) + 다리 난간 반엄폐물(높이 3.8 Studs) + 다리 하부 빙판 우회로
│   │   │   ├── SideLanes_Watchtowers                -- 좌/우측 2층 목조 감시탑(Watchtower) + 경사로/계단 + 상부 저격용 발코니 창문
│   │   │   └── CoverAndProps                        -- 눈 덮인 소나무(전신 엄폐, 높이 12 Studs), 나무 상자 크레이트(반엄폐, 높이 4 Studs), 통나무 바리케이드
│   │   ├── Map_02_DesertColosseum (사막 고대 신전)/
│   │   │   ├── TeamSpawns                           -- 좌/우 대칭 사암(Sandstone) 신전 회랑 스폰 구역
│   │   │   ├── MidLane_SwordMonument                -- 중앙 원형 제단 + 바닥에 꽂힌 거대 청동 검 동상(Sword Statue, 중심 전신 엄폐물) + 주변 붉은 문양 사각 석블록(반엄폐)
│   │   │   ├── SideLanes_CyanDomeTemples            -- 좌/우 청록색 돔 지붕 신전 내부 통로(근접 단검/해머 교전용 초크포인트) + 외벽 옥상 등반용 계단
│   │   │   └── CoverAndProps                        -- 부서진 사암 기둥, 야자수, 항아리 프롭
│   │   ├── Map_03_HighlandHenge (고원 스톤헨지 유적)/
│   │   │   ├── TeamSpawns                           -- 양 끝 초가집(Thatched Cottage) 앞마당 스폰 + 초가집 지붕 등반용 측면 나무 상자 발판(지붕 위 헤드헌터/머스킷 고지대)
│   │   │   ├── MidLane_StonehengeRing               -- 중앙 원형으로 배치된 8개의 거대 입석(Monolith Pillars, 높이 14 Studs) 및 상판 바위 + 지글 피킹(Jiggle Peek) 교전 구역
│   │   │   ├── SideLanes_CoastalTrenchAndWall       -- 좌측 해안가 얕은 수로(물 첨벙 사운드) 및 우측 낮은 돌담(Stone Wall, 슬라이딩 엄폐용)
│   │   │   └── CoverAndProps                        -- 이끼 낀 바위, 나무 수레, 건초 더미
│   │   ├── Map_04_IcefallFjord (빙하 폭포 선착장)/
│   │   │   ├── TeamSpawns                           -- 양측 선착장 목조 데크 스폰 + 배경 거대 빙하 폭포(`Beam` 물줄기 + 하단 안개 파티클)
│   │   │   ├── MidLane_GroundedShipwreck            -- 중앙에 비스듬히 좌초된 대형 목선(Shipwreck) + 양현 계단을 통한 갑판(Deck) 고지대 점거 + 돛대(Mast) 엄폐물
│   │   │   ├── SideLanes_RedWarehouses              -- 좌/우 붉은색 목조 창고 건물 (양방향 출입문 + 측면 창문 사격 각 + 지붕 슬라이딩 점프 루트)
│   │   │   └── CoverAndProps                        -- 푸른 얼음 바위(Ice Rocks), 생선 오크통, 밧줄 더미
│   │   └── Shared_Map_Mechanics/                    -- 모든 맵에 공통 포함되는 시스템 오브젝트
│   │       ├── Invisible_ClipBrushes                -- 캐릭터 모서리 끼임 방지용 투명 경사 파트 (`Transparency = 1`, `CanCollide = true`, `CanQuery = false`)
│   │       ├── RingOfFire_BoundaryCylinder          -- 라운드 60초 종료 시 반경이 `Radius 180 -> 0 Studs`로 축소되는 원통형 화염 장벽 모델 (외부 체류 시 0.5초당 10 화염 대미지)
│   │       └── POTG_CinematicStage                  -- 맵 하부 또는 배경 구역에 위치한 '최고의 플레이' 리플레이 재생용 복제 스테이지[cite: 1, 2]
│   │
│   └── Runtime_Dynamic_Containers/                  -- 라운드 중 생성되고 `Janitor`에 의해 라운드마다 완전 초기화되는 폴더[cite: 2]
│       ├── AliveCharacters_Alpha                    -- Alpha팀 생존 캐릭터 3인 모델 컨테이너
│       ├── AliveCharacters_Bravo                    -- Bravo팀 생존 캐릭터 3인 모델 컨테이너
│       ├── ActiveProjectiles_Container              -- 비행 중인 화살, 총탄, 투척 단검, 차크람, 볼라, 작살 인스턴스
│       ├── DeployedUtilities_Container              -- 설치된 나무 성벽(`Palisade`), 곰 덫(`Snap Trap`), 연막 구름(`Smoke Bomb`), 화염구 불길(`Fireball`)
│       └── Ragdolls_And_StuckArrows                 -- 사망자 물리 래그돌 및 벽/방패/시체에 박힌 화살 모델
│
├── 02_ReplicatedStorage (3D 에셋 프리팹, 설정 데이터, 공유 물리 엔진)/
│   ├── RemoteNetwork_Events/                        -- `Net.luau`에서 관리하는 통신 채널[cite: 2]
│   │   ├── ReliableRemotes (RemoteEvent)            -- `RequestSpawnLoadout`, `SwitchPresetInPreRound`, `FireProjectile`, `MeleeSwing`, `UseUtility`, `StartHeal`, `CancelHeal`, `ToggleBlock`, `RoundStateChanged`, `BroadcastPOTGData`, `OpenVictoryChest`, `UpgradeEquipment`, `PartyAction`, `QueueAction`
│   │   └── UnreliableRemotes (UnreliableRemoteEvent)-- `ReplicateCharacterState` (20Hz 위치/조준각/슬라이딩 상태 브로드캐스트), `ReplicateBowDrawRatio`
│   │
│   ├── Procedural_3D_Weapon_And_Armor_Prefabs/      -- 스튜디오 내 기본 파트로 정교하게 조립된 28종+ 장비 3D 모형 규격
│   │   ├── Ranged_Weapon_Models/                    -- 모든 원거리 무기는 `Handle`(Root), `MuzzleAttachment`(발사 원점), `StringAttachment`(활 시위) 필수 포함
│   │   │   ├── WoodBow_Model                        -- 곡선형 갈색 목재 활대(5개 각도 조절 `Part` 결합) + 흰색 시위(`Beam`, 당김 시 손 위치로 늘어남) + 화살 거치대
│   │   │   ├── Crossbow_Model                       -- 짙은 참나무 몸체(Stock) + 전방 강철 활대(Metal Prod) + 상단 볼트 레일 + 기계식 방아쇠 부품
│   │   │   ├── Headhunter_Model                     -- 흑단(Ebony) & 금장 장식 대형 컴파운드 장궁 모형 + 조준경 핀(Sight Pin) 디테일
│   │   │   ├── Flintlock_Model                      -- 곡선형 목재 권총 그립 + 황동(Brass) 장식 + 팔각형 강철 총열 + 부싯돌 공이치기(Hammer, 격발 시 회전 애니메이션)
│   │   │   ├── Blunderbuss_Model                    -- 묵직한 개머리판 + 나팔 모양으로 넓어지는 대구경 황동 총구(Flared Muzzle)
│   │   │   ├── Musket_Model                         -- 긴 목재 총몸 + 장총열(Long Barrel) + 가늠쇠/가늠자 + 하부 꼬질대(Ramrod) 디테일
│   │   │   ├── Sling_Model                          -- 가죽 스트랩 2줄(`Beam`) + 중앙 돌멩이 파우치 (차징 시 원형 회전 모션)
│   │   │   ├── ThrowingKnives_Model                 -- 은빛 소형 양날 단검 (손잡이 검은 가죽 매듭, 3개 묶음 홀스터 포함)
│   │   │   ├── Javelins_Model                       -- 길이 6 Studs 나무 자루 + 날카로운 철제 피라미드 창촉
│   │   │   ├── Harpoon_Model                        -- 미늘(Barb)이 달린 강철 작살촉 + 후방 연결 로프(`RopeConstraint`/`Beam`)
│   │   │   ├── Bolas_Model                          -- 중앙 매듭에서 뻗어 나온 3줄의 밧줄 끝에 달린 3개의 철제 구형 추(Weights)
│   │   │   └── Chakram_Model                        -- 외곽에 날카로운 은빛 칼날 링이 달린 원형 고리 무기 (`Cylinder` 중공 구조 + 금빛 내부 문양)
│   │   │
│   │   ├── Melee_Weapon_Models/                     -- 모든 근접 무기는 칼날을 따라 5~8개의 `DmgPoint` Attachment(`RayCastHitbox`용) 및 `Trail`용 `Top/BottomAttachment` 포함
│   │   │   ├── DiamondDagger_Model                  -- 금장 크로스가드 + 청록색 빛이 나는 다이아몬드 단검 날(`Material = Glass/Neon` 혼합, 길이 2.2 Studs)
│   │   │   ├── IronSword_Model                      -- 가죽 그립 + 십자형 강철 코등이 + 양날 직검 블레이드(길이 4.2 Studs)
│   │   │   ├── Hammer_Model                         -- 양손잡이 긴 나무 자루 + 양면에 사각 징이 박힌 초대형 강철 해머 헤드(무게감 강조)
│   │   │   ├── BattleAxe_Model                      -- 철제 보강 목재 자루 + 반달형 거대 양날 도끼날(`WedgePart` 곡면 조립)
│   │   │   ├── Spear_Model                          -- 길이 7.5 Studs 장창 자루 + 붉은 깃털 장식 + 다이아몬드형 강철 창날
│   │   │   ├── Shield_Model                         -- 왼팔에 장착되는 원형/카이트형 목재 방패 + 강철 테두리 림(Rim) + 중앙 보스(Boss) 징 (`DestructibleShields` 콜리전 파트 내장)
│   │   │   └── Ranked_Melees (Katana/Scythe/Gauntlets/TwinHatchets) -- 곡도 카타나 및 칼집(Saya), 사신의 대형 낫, 강철 너클 건틀릿(좌/우 한 쌍), 소형 손도끼 한 쌍
│   │   │
│   │   ├── Utility_And_Healing_Models/              -- 전술 도구 및 소모품 3D 모델
│   │   │   ├── SmokeBomb_Model                      -- 밧줄이 감긴 회색 도자기 구형 폭탄 + 상단 타들어가는 도화선 불꽃
│   │   │   ├── SnapTrap_Model                       -- 바닥에 펼쳐지는 톱니 모양 강철 곰 덫 (작동 시 양쪽 톱니 파트가 90도 닫히는 `Tween` 구조)
│   │   │   ├── Fireball_Model                       -- 손바닥 위에서 일렁이는 코어 구형 네온 파트 + 화염 소용돌이 파티클
│   │   │   ├── Palisade_Model                       -- 설치 시 지면에서 솟아오르는 5개의 끝이 뾰족한 통나무 성벽 묶음 (가로 8 Studs x 높이 6.5 Studs)
│   │   │   ├── WarHorn_Model                        -- 금장 테두리와 가죽 끈이 달린 굽은 뿔피리(Curved Horn)
│   │   │   ├── Bandage_Model                        -- 흰색 거즈 붕대 롤
│   │   │   ├── Apple_And_GoldenApple_Model          -- 꼭지와 잎사귀가 달린 빨간 사과 / 황금빛 광택(`Material = Foil/Neon`, 반짝임 파티클) 황금 사과
│   │   │   └── HealingFlask_Model                   -- 유리병 내부에 붉은 회복 물약 액체가 담긴 플라스크
│   │   │
│   │   └── Wearable_Armor_Models/                   -- 장착 시 캐릭터 `UpperTorso`/`LeftUpperArm`/`RightUpperArm`에 `WeldConstraint`로 부착되는 방어구 모델
│   │       ├── LeatherArmor_Model                   -- 갈색 가죽 조끼 + 스터드 어깨 패드 (+25 Armor)
│   │       ├── IronArmor_Model                      -- 은빛 강철 흉갑(Breastplate) + 철제 견갑(Pauldrons) (+50 Armor)
│   │       └── DiamondArmor_Model                   -- 푸른 다이아몬드 결정 광택의 풀플레이트 갑옷 + 망토/중갑 디테일 (+100 Armor)
│   │
│   ├── VFX_And_Particle_Templates/                  -- 타격감 및 시각 피드백 프리팹
│   │   ├── ProjectileTrails                         -- `ArrowWindTrail`(흰색 반투명 공기선), `FireArrowFlame`(불꽃+연기), `BulletTracer`(노란색 고속 탄도선)
│   │   ├── ImpactEffects                            -- `HitSpark_Normal`(흰색/노란색 타격 스파크), `HitSpark_Headshot`(붉은색/황금색 폭발형 크리티컬 스파크), `ArmorHit_BlueShard`(방어구 타격 시 파란 파편), `ArmorBreak_Shatter`(방어구 0 도달 시 대형 파란 결정 파열 이펙트)
│   │   ├── StatusAndAreaEffects                     -- `SmokeCloud_Emitter`(반경 16 Studs 짙은 회색 연기, 8초 지속), `HealAura_GreenRing`(초록색 상승 십자가 및 바닥 원형 파동), `WarHorn_Pulse`(황금색 음파 확장 구 + 적군 빨간색 `Highlight` 객체), `Stagger_Stars`(해머 피격 시 머리 위 회전하는 별 이펙트)
│   │   └── KillConfirmationVFX                      -- 처치 순간 피해자 위치에서 솟구치는 황금색 해골/별 버스트 파티클
│   │
│   └── Modules/                                     -- 클라이언트 & 서버 공유 코어 모듈[cite: 2]
│       ├── Config/
│       │   ├── EquipmentDatabase.luau               -- 전체 장비 28종+ 완벽 스펙 테이블:
│       │   │   ├── `WoodBow`: `{Id="WoodBow", Category="WEAPONS", SubType="BOW", Cost=3, AmmoType="Arrows", BaseDmg=40, HeadMult=1.75, DrawTime=0.75, ProjectileSpeed=220, GravityScale=0.35, UnlockShards=10, RobuxCost=399}`[cite: 2]
│       │   │   ├── `Crossbow`: `{Id="Crossbow", Category="WEAPONS", SubType="BOW", Cost=4, AmmoType="Arrows", BaseDmg=50, HeadMult=1.65, ReloadTime=1.8, ProjectileSpeed=340, GravityScale=0.15, UnlockShards=20, RobuxCost=599}`
│       │   │   ├── `Headhunter`: `{Id="Headhunter", Category="WEAPONS", SubType="BOW", Cost=5, AmmoType="Arrows", BaseDmg=62, HeadMult=2.0, DrawTime=1.1, ZoomFOV=40, PostShotSlow=0.6, UnlockShards=30, RobuxCost=799}`
│       │   │   ├── `Flintlock`: `{Id="Flintlock", Category="WEAPONS", SubType="GUN", Cost=3, AmmoType="Bullets", BaseDmg=45, HeadMult=1.6, ReloadTime=1.6, ProjectileSpeed=450, GravityScale=0.05, UnlockShards=10, RobuxCost=399}`
│       │   │   ├── `Blunderbuss`: `{Id="Blunderbuss", Category="WEAPONS", SubType="GUN", Cost=4, AmmoType="Bullets", PelletCount=8, PelletDmg=14, SpreadAngle=9, FalloffStart=18, ReloadTime=2.2, UnlockShards=20, RobuxCost=599}`
│       │   │   ├── `Musket`: `{Id="Musket", Category="WEAPONS", SubType="GUN", Cost=5, AmmoType="Bullets", BaseDmg=58, HeadMult=1.7, ReloadTime=2.6, ProjectileSpeed=650, GravityScale=0.02, UnlockShards=30, RobuxCost=799}`
│       │   │   ├── `Sling`: `{Id="Sling", Category="WEAPONS", SubType="THROWABLE", Cost=1, AmmoType="Infinite(12)", BaseDmg=38, HeadMult=1.5, ChargeTime=0.5, ProjectileSpeed=180, GravityScale=0.45}`
│       │   │   ├── `ThrowingKnives`: `{Id="ThrowingKnives", Category="WEAPONS", SubType="THROWABLE", Cost=2, MaxStack=6, BaseDmg=30, HeadMult=1.8, Cooldown=0.45, ProjectileSpeed=260}`
│       │   │   ├── `Chakram`: `{Id="Chakram", Category="WEAPONS", SubType="THROWABLE", Cost=2, BaseDmg=45, BounceCount=2, ReturnToSender=true, Catchable=true}`
│       │   │   ├── `Bolas`: `{Id="Bolas", Category="WEAPONS", SubType="THROWABLE", Cost=2, BaseDmg=15, SnareDuration=2.5, SnareSpeedMult=0.25}`
│       │   │   ├── `Harpoon`: `{Id="Harpoon", Category="WEAPONS", SubType="THROWABLE", Cost=3, BaseDmg=35, PullForce=85}`
│       │   │   ├── `DiamondDagger`: `{Id="DiamondDagger", Category="WEAPONS", SubType="MELEE", Cost=2, BaseDmg=25, SwingRate=0.35, Range=6.5, WalkSpeedBonus=1.08, CanBlock=false, BackstabMultiplier=4.0(InstantKill)}`
│       │   │   ├── `IronSword`: `{Id="IronSword", Category="WEAPONS", SubType="MELEE", Cost=3, BaseDmg=34, SwingRate=0.55, Range=8.5, CanBlock=true, BlockDamageReduction=0.8}`
│       │   │   ├── `Hammer`: `{Id="Hammer", Category="WEAPONS", SubType="MELEE", Cost=3, BaseDmg=42, HeadMult=1.45, SwingRate=0.95, Range=9.0, KnockbackImpulse=65, StaggerDuration=0.8}`
│       │   │   ├── `BattleAxe`: `{Id="BattleAxe", Category="WEAPONS", SubType="MELEE", Cost=3, BaseDmg=46, OverheadDmg=58, ArmorShredRatio=0.5}`
│       │   │   ├── `Spear`: `{Id="Spear", Category="WEAPONS", SubType="MELEE", Cost=3, BaseDmg=32, SwingRate=0.6, Range=12.5}`
│       │   │   ├── `Shield`: `{Id="Shield", Category="WEAPONS", SubType="SHIELD", Cost=3, ShieldHealth=120, BlocksProjectiles=true}`
│       │   │   ├── `SmokeBomb`: `{Id="SmokeBomb", Category="UTILITY", Cost=1, MaxStack=2, Radius=16, Duration=8.0}`
│       │   │   ├── `SnapTrap`: `{Id="SnapTrap", Category="UTILITY", Cost=1, MaxStack=2, TriggerRadius=3.5, Damage=35, RootDuration=2.5}`
│       │   │   ├── `Palisade`: `{Id="Palisade", Category="UTILITY", Cost=1, WallHealth=180, Duration=25.0, Size=Vector3.new(8,6.5,1.5)}`
│       │   │   ├── `WarHorn`: `{Id="WarHorn", Category="UTILITY", Cost=2, Cooldown=20.0, RevealDuration=5.0, TeamSpeedBoost=1.2}`
│       │   │   ├── `Fireball`: `{Id="Fireball", Category="UTILITY", Cost=3, ImpactDmg=35, BurnDPS=8, BurnDuration=4.0, Radius=10}`
│       │   │   ├── `Bandage`: `{Id="Bandage", Category="HEALING", Cost=1, MaxStack=3, HealAmount=35, CastTime=2.2}`
│       │   │   ├── `Apple`: `{Id="Apple", Category="HEALING", Cost=2, MaxStack=2, HealAmount=50, CastTime=1.2}`
│       │   │   ├── `HealingFlask`: `{Id="HealingFlask", Category="HEALING", Cost=2, HealAmount=60, SplashRadius=8}`
│       │   │   ├── `GoldenApple`: `{Id="GoldenApple", Category="HEALING", Cost=3, MaxStack=1, HealAmount=100, Duration=3.0}`
│       │   │   ├── `LeatherArmor`: `{Id="LeatherArmor", Category="ARMOR", Cost=2, ArmorHP=25, RangedDmgReduction=0.15, SpeedPenalty=0}`
│       │   │   ├── `IronArmor`: `{Id="IronArmor", Category="ARMOR", Cost=4, ArmorHP=50, RangedDmgReduction=0.30, SpeedPenalty=0.06}`
│       │   │   └── `DiamondArmor`: `{Id="DiamondArmor", Category="ARMOR", Cost=6, ArmorHP=100, RangedDmgReduction=0.40, MeleeDmgReduction=0.15, SpeedPenalty=0.12, KnockbackResist=0.5}`
│       │   ├── UpgradeScalingMath.luau              -- 레벨업(Lv1 ~ Lv10 MAX)당 요구 샤드 수(10 -> 20 -> 40 -> 80...) 및 레벨당 기본 대미지/체력 `+4%` 복리/선형 증가 수식
│       │   └── MonetizationCatalog.luau             -- Developer Product ID 매핑 (Golden Drop 10R$, 연승 복구 20/39/79R$, 장비 즉시 해금 399/599/799R$, 부족 창설 299R$)
│       │
│       └── Shared/
│           ├── BallisticsEngine.luau                -- 포물선 탄도 시뮬레이터 ($\vec{P}(t) = \vec{P}_0 + \vec{V}_0 t + \frac{1}{2}\vec{g}t^2$), 차크람 벽면 반사 벡터($\vec{R} = \vec{V} - 2(\vec{V}\cdot\vec{N})\vec{N}$) 및 부메랑 귀환 보간, 블런더버스 원뿔형 산탄 분포 계산[cite: 2]
│           ├── LoadoutBudgetValidator.luau          -- `MaxPoints <= 12`, `MaxSlots <= 6`, 탄약 번들(1PT당 화살 12발 / 총알 6발 / 화염화살 6발), 방어구 중복 장착 방지 검증기
│           ├── SpringPhysics.luau                   -- 2차 감쇠 조화 진동자($\ddot{x} + 2\zeta\omega_n\dot{x} + \omega_n^2 x = 0$) 기반 카메라 반동, 시위 당김 떨림, 착지 바운스, 뷰모델 스웨이 연산기[cite: 2]
│           └── Janitor.luau                         -- 라운드 전환 시 모든 런타임 객체/이펙트/트윈/커넥션 즉시 정리[cite: 2]
│
├── 03_ServerScriptService (서버 권위 전투, 봇 AI, 리플레이, 경제 엔진)/
│   ├── ServerMain.server.luau                       -- 서버 부트스트래퍼 및 서비스 의존성 주입[cite: 2]
│   └── Services/
│       ├── PlayerDataService.luau                   -- `DataStoreService` 기반 프로필 관리:
│       │   ├── 스키마: `{Level, XP, WinStreak, LastLostStreak, GloryRP, TribeId, Shards={[ItemId]=count}, UnlockedItems={[ItemId]=level}, Presets={1..5}, GoldenDropPurchased, Settings}`
│       │   └── 오토세이브 및 서버 이동(`TeleportData`) 간 세션 락(Session Lock) 처리
│       ├── MatchmakingAndBotService.luau            -- 큐 매칭 및 AI 봇(Bot) 충원 시스템:
│       │   ├── `PreventFullBotMatches` 설정이 꺼진 유저가 큐 대기 15초 초과 시, 부족한 인원을 AI 전술 봇(`TacticalBotAgent`)으로 채워 즉시 3v3 매치 시작
│       │   └── `TacticalBotAgent`: `PathfindingService` + 엄폐물 피킹 + 거리별 무기 스왑(원거리 활 견제 -> 근접 칼/단검 돌진) 상태 머신 내장
│       ├── RoundStateMachineService.luau            -- **Best of 5 (3선승제)** 라운드 루프 제어[cite: 2]:
│       │   ├── `[Phase 1: PreMatchVS (6s)]`         -- 3v3 VS 스플래시 화면 표시 및 캐릭터 초기 스폰
│       │   ├── `[Phase 2: PreRoundLoadout (5s)]`    -- 스폰 구역 대기, `5..4..3..2..1..FIGHT!` 카운트다운 중 `[B]`키로 1~5번 로드아웃 프리셋 실시간 교체 허용
│       │   ├── `[Phase 3: ActiveCombat (60s)]`      -- 전투 개시, 팀 전원 사망 여부 실시간 감지, 60초 경과 시 `Ring of Fire` 자기장 수축 가동
│       │   ├── `[Phase 4: RoundEndBanner (4s)]`     -- 승리 팀 판정 (`ROUND WON/LOST`, 무사망 시 `FLAWLESS`, 1인 3킬 시 `ACE`, 전원 처치 시 `TEAM ACE` 배너 출력)
│       │   ├── `[Phase 5: POTGReplay (8s)]`         -- 한 팀이 3승 달성 시 매치 종료 -> 서버에서 최고 점수 하이라이트 구간 추출 후 전 클라이언트 POTG 재생[cite: 1, 2]
│       │   └── `[Phase 6: VictoryDropAndSummary]`   -- 매치 보상 상자(4장 카드, 23~25 샤드) 지급, XP/연승/MVP 정산 후 `[PLAY AGAIN]` 큐 연동
│       ├── LagCompensatedCombatService.luau         -- 서버 권위 타격 판정 및 특수 기믹 처리기[cite: 2]:
│       │   ├── **히트박스 시간 역산(Server Rewind):** 최근 1.0초간 전 플레이어의 부위별 CFrame을 20Hz 링 버퍼에 기록 -> 사격 패킷의 서버 타임스탬프 기준으로 과거 히트박스 위치 복원 후 검증[cite: 2]
│       │   ├── **방어구(Armor) 및 피해 감소 공식:** 아머 보유 시 원거리 대미지 `15% / 30% / 40%` 선차감 후 `ArmorHP`부터 소모 -> `ArmorHP == 0` 도달 시 `[ARMOR BROKEN]` 이벤트 브로드캐스트 및 캐릭터 갑옷 모델 파괴
│       │   ├── **백스탭(Backstab) 판정:** `Diamond Dagger` 공격 시 공격자 LookVector와 피해자 LookVector의 내적($\vec{L}_{attacker} \cdot \vec{L}_{victim} > 0.5$, 즉 등 뒤 120도 이내)이면 **즉사(Instant Kill, 250 DMG)** 처리
│       │   ├── **블록(Block) 및 방패(Shield) 판정:** 피해자가 `Iron Sword` 우클릭 방어 중이고 공격 방향이 정면($\vec{L}_{victim} \cdot \vec{D}_{attack} < -0.4$)이면 근접 대미지 80% 경감 및 방어 스파크 발생 / `Shield` 홀드 중이면 화살·탄환 무효화 및 방패에 화살 박힘 처리
│       │   └── **해머 넉백 & 경직(Stagger):** `Hammer` 적중 시 피해자에게 수평 물리 충격량($\vec{I}_{knockback}$) 인가 + 0.8초간 사격/차징 취소 및 `[STAGGERED]` 상태 부여
│       ├──POTGRecorderAndScorer.luau                -- 6초 슬라이딩 윈도우 기반 하이라이트 추출 엔진[cite: 1, 2]:
│       │   ├── 가중치 스코어링: 기본 킬(+100), 멀티킬 가산($\times 1.5, \times 2.5$), 헤드샷(+50, `HEADSHOT`), 라운드 마지막 결정타(+80, `WINNING BLOW`), 80 Studs 이상 원거리 저격 킬(+90, `LONG SHOT`), 적 3인 전원 처치(+500, `TEAM WIPE`)[cite: 1]
│       │   └── 최고 점수 구간의 20Hz 캐릭터/투사체/이펙트 타임라인 패킷 직렬화 및 브로드캐스트[cite: 2]
│       └── EconomyAndMonetizationService.luau       -- 상자 드롭, 샤드 강화, Robux 결제 처리:
│           ├── `GenerateVictoryDrop(player)`: 매치 종료 시 4개의 아이템 슬롯을 가중치 랜덤 추출하여 총 23~25개의 샤드 분배 (신규 유저는 초반 해금 장비 우선 배정)
│           └── `ProcessReceipt`: `10 R$ Golden Drop`(즉시 ~60 샤드 + 미해금 무기 확정 지급), `20/39/79 R$ Restore Streak`(`LastLostStreak` 값을 현재 `WinStreak`으로 복원), `399/599/799 R$ Item Unlock` 처리
│
├── 04_StarterPlayerScripts (클라이언트 컨트롤러, 카메라, 뷰모델, UI 렌더러)/
│   ├── ClientMain.client.luau                       -- 클라이언트 초기화 및 모듈 오케스트레이션[cite: 2]
│   └── Controllers/
│       ├── InputAndKeybindController.luau           -- PC/모바일 통합 입력 매핑:
│       │   ├── `[B]`: 로드아웃 빌더 모달 토글 (로비 상시 / 인게임 라운드 시작 전 5초 동안 프리셋 스위처 활성화)
│       │   ├── `[C]`: 질주 중 슬라이딩 발동 (카메라 높이 `-2.2 Studs` 하강 트윈, 이동 방향 초기 속도 `WalkSpeed * 1.65` 부스트 후 마찰 감속, 히트박스 축소 요청)
│       │   ├── `[V]`: 1인칭(First-Person) <-> 3인칭(Third-Person) 카메라 시점 즉시 전환 (하단 HUD `[first person V]` 텍스트 하이라이트 연동)
│       │   ├── `[X]`: 3인칭 상태에서 우측 어깨(`Offset = Vector3.new(2.5, 1.5, 6.5)`) <-> 좌측 어깨(`Offset = Vector3.new(-2.5, 1.5, 6.5)`) 카메라 오프셋 스왑
│       │   └── `[1~6]` & 마우스 휠: 하단 6칸 핫바 슬롯 스왑 (장착 시 우측 하단에 무기별 전용 조작 힌트 동적 변경)
│       ├── CameraAndViewmodelController.luau        -- 시점 렌더링 및 1인칭 절차적 뷰모델[cite: 2]:
│       │   ├── 1인칭 전환 시 캐릭터 본체 투명화(`LocalTransparencyModifier = 1`, 장착 무기와 팔 뷰모델만 화면 렌더링)
│       │   ├── 우클릭 조준(Zoom/ADS) 시 무기별 목표 FOV(`WoodBow: 55`, `Headhunter: 40`, `Musket: 45`)로 `Spring` 보간 및 조준선 원형 수축
│       │   └── 환경설정의 `CAMERA SENSITIVITY`, `FIELD OF VIEW (70~120)`, `VIEW BOBBING` 실시간 반영
│       ├── WeaponAndProjectileController.luau       -- 클라이언트 즉각 반응형 전투 컨트롤러[cite: 2]:
│       │   ├── 원거리 차징: 좌클릭 홀드 시 활 시위 당김 게이지 상승 -> 발사 시 클라이언트에서 즉시 화살 복제본 생성 및 포물선 비행 렌더링과 동시에 서버 검증 패킷 전송
│       │   ├── 근접 전투: 좌클릭 시 무기 스윙 애니메이션 + 검기 `Trail` 활성화 + 우클릭 홀드 시 방어(`Block`) 자세 전환
│       │   └── 설치/투척 프리뷰: `Palisade`(나무 성벽)나 `Snap Trap`(덫) 선택 시 설치될 위치에 반투명 초록색/빨간색 홀로그램 프리뷰 표시
│       ├── CombatFeedbackAndHUDController.luau      -- 타격감(Juice) 및 실시간 전투 UI 업데이트[cite: 2]:
│       │   ├── 적중 시 크로스헤어 히트마커 팝업 + 타격 위치에 데미지 플로팅 텍스트(`40`, 노란색 `70 HEADSHOT!`, 파란색 `ARMOR BROKEN`, 흰색 `STAGGERED`)를 포물선 물리 속도로 튀어 오르게 렌더링
│       │   ├── 킬 달성 시 화면 중앙 하단에 붉은 해골 배너(`ELIMINATED {Name}`) + 경쾌한 킬 사운드 재생
│       │   └── 사망 시 즉시 `ELIMINATED BY` 카드 표시 후 2.5초 뒤 생존 아군 3인칭 관전 카메라(`SPECTATING`) 모드로 자동 전환
│       └── POTGAndVictorySequenceController.luau    -- 매치 종료 연출 시퀀서[cite: 1, 2]:
│           ├── 1단계: 검은 화면 스플래시(`PLAY OF THE GAME | {Name} | {Tags}`) 2초 노출 -> `REC 🔴` 뷰파인더 오버레이와 함께 60FPS `CFrame:Lerp()` 보간 리플레이 재생 (`[SKIP >>]` 버튼 지원)[cite: 1, 2]
│           ├── 2단계: `VICTORY DROP` 화면으로 전환 -> 3D 상자 흔들림 및 열림 연출 -> 4장의 샤드 카드 순차 뒤집기 애니메이션(`x3 -> x2 -> x1`) -> 총 획득 샤드 및 `[UPGRADE READY]` 표시
│           └── 3단계: 6인 최종 스코어보드(`K / D / A / DMG`), 우상단 `⭐ MVP` 하이라이트 카드, 우하단 세부 XP 획득 내역 프로그레스 바 채우기 애니메이션 및 `[PLAY AGAIN (25s)]` 자동 재매칭 카운트다운 실행
│
└── 05_Automated_Studio_Builder_Pipeline/            -- 스튜디오에서 실행할 자동 생성 순서(Execution Order)
    ├── Step_1_GenerateCollisionAndFolders           -- `PhysicsService` 6개 충돌 그룹 등록 및 전체 폴더 트리 생성
    ├── Step_2_BuildProcedural3DAssets               -- 28종 무기/방어구/유틸리티 3D 모델 및 파티클 프리팹을 `ReplicatedStorage`에 조립 생성
    ├── Step_3_BuildLobbyAnd4ArenaMaps               -- 50인 로비 마을과 4대 아레나 맵(설원 요새, 사막 신전, 스톤헨지, 빙하 피오르드)을 `Workspace`에 수치 기반 프로시저럴 생성[cite: 1]
    ├── Step_4_GenerateCompleteStarterGui            -- 로비, 12포인트 로드아웃 빌더, VS 화면, 인게임 전투 HUD, POTG 뷰파인더, 상자 개봉, 스코어보드 `ScreenGui` 전체 생성[cite: 1, 2]
    └── Step_5_InjectStrictLuauScripts               -- 공유 물리 모듈(`Ballistics`, `Spring`), 서버 서비스(`Round`, `CombatRewind`, `POTG`, `BotAI`, `Economy`), 클라이언트 컨트롤러 전체 스크립트 주입 및 바인딩 완료[cite: 2]
roblex STUDIO로 만들어줘
```
