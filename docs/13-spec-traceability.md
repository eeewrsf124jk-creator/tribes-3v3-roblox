# 13. 명세 대조표

원본 명세([spec/original-spec.md](spec/original-spec.md))의 항목마다 어디에 구현됐는지, 명세와 다른 점이 있는지 정리했습니다.

표시: ✅ 명세대로 구현 · 🔁 실제 게임 기준으로 값을 바꿈 · ➕ 명세보다 더 구현 · 📝 해석이 필요했던 항목

## 아키텍처 규칙

| 명세 | 상태 | 구현 |
|---|---|---|
| 모든 스크립트 `--!strict`, Luau 타입 명시 | ✅ | 62개 파일 모두. `tests/place.luau`가 첫 줄을 검사, luau-lsp 엄격 모드 오류 0 |
| 단일 진입점 `ServerMain` / `ClientMain` | ✅ | 나머지 60개는 ModuleScript. `tests/place.luau`가 실행 스크립트 2개를 검사 |
| 외부 에셋 없이 Part·Wedge·CornerWedge·Cylinder·SpecialMesh·Union·Weld·Motor6D로 무기와 맵 조립 | ✅ | `BuilderModules/Kit/GeometryKit.luau`. Union은 `GeometryService`로 만들고, 실패하면 같은 모양의 용접 Model로 대체 |
| ScreenGui: Scale 기반, UICorner·UIStroke·UIGradient·UIListLayout·UIGridLayout·UIAspectRatioConstraint 수치 지정 | ✅ | `BuilderModules/Kit/UIKit.luau`, `Step4/*`. 요소 목록은 [reference/ui.md](reference/ui.md) |

## 00 프로젝트 설정

| 명세 | 상태 | 구현 |
|---|---|---|
| `default.project.json`: Workspace, ReplicatedStorage, ServerScriptService, StarterGui, StarterPlayer, SoundService, Lighting 매핑 | ✅ | 모두 있음. Teams 서비스도 추가 |
| Place 1 로비 (최대 50명) | ✅ | `default.project.json` |
| Place 2 아레나 (최대 6명), `ReserveServer` 3v3 Best of 5 | ✅ | `arena.project.json`, `MatchmakingAndBotService` |

## 01 Workspace

| 명세 | 상태 | 구현 |
|---|---|---|
| Gravity 196.2, FallenPartsDestroyHeight −500, StreamingEnabled, SignalBehavior Deferred | ✅ | 두 프로젝트 파일 |
| 충돌 그룹 6개와 매트릭스 | ✅ | `Shared/CollisionGroups.luau`. 표는 [02번 문서](02-architecture.md#충돌-그룹) |
| HitboxParts `CanCollide = false`, `CanQuery = true` | ✅ | `CollisionGroups.AssignCharacter`: 루트 파트는 PlayerMovementBox, 팔다리·몸통은 HitboxParts, 장비·액세서리는 판정 없는 장식 |
| 로비 스폰 광장: 원형 석재 타일, 3단 분수(파티클 물줄기), SpawnLocation 12개 | ✅ | `Step3/LobbyWorld.luau` |
| 로드아웃 노점: 파랑·흰 줄무늬 천막, 무기 거치대, [B] Loadout Builder | ✅ | 〃. 진열대에 실제 무기 프리팹 5종 |
| 커스텀 매치 오두막 (1v1/2v2/3v3 방 만들기) | ✅ | 〃, `CustomMatchAction` |
| 트라이브 홀 (창설·가입) | ✅ | 〃, `TribeService` |
| 전광판 3종 (TOP TRIBES 주간 Glory 1~50위 스크롤, MOST ELIMINATIONS + 1~3위 아바타 동상, LONGEST STREAKS) | ✅ | `LeaderboardService`. 월드 SurfaceGui는 입력을 받지 않아 클라이언트가 자동 스크롤 |
| 1v1 결투장 + `[XX LIVE]` 빌보드 | ✅ | `LobbyService` |
| 사격장: 20/50/100 스터드 움직이는 허수아비 | ✅ | 〃. 죽지 않고 대미지·헤드샷 표시 |
| 아레나 맵 4종의 TeamSpawns·MidLane·SideLanes·CoverAndProps 세부 | ✅ | `Step3/Map01~04`. 내용은 [07번 문서](07-world-and-maps.md#아레나-맵-4종) |
| 윈터 요새: 스폰 패드 3개 + 모닥불(PointLight + 불꽃) + 보호막, 난간 3.8, 소나무 12, 상자 4 | ✅ | `Map01_WinterTimberFort.luau` |
| 하이랜드: 거석 8개 높이 14, 지붕 오르는 상자 | ✅ | `Map03_HighlandHenge.luau` |
| 피오르드: Beam 물줄기 + 안개 파티클 빙하 폭포 | ✅ | `Map04_IcefallFjord.luau` |
| Invisible_ClipBrushes (`Transparency 1`, `CanCollide true`, `CanQuery false`) | ✅ | `MapKit.Clip`. 경계 벽·천장과 모서리 쐐기 |
| RingOfFire 반경 180 → 0, 밖에서 0.5초마다 10 | ✅ | `RoundStateMachineService`, `GameConfig.Ring`. 수축 30초 ➕ |
| POTG_CinematicStage | ✅ | `MapKit.POTGStage` |
| Runtime_Dynamic_Containers 5개 폴더, Janitor로 라운드마다 정리 | ✅ | `Step1/CollisionAndFolders.luau`, `Shared/Janitor.luau` |

## 02 ReplicatedStorage

| 명세 | 상태 | 구현 |
|---|---|---|
| `RemoteNetwork_Events/ReliableRemotes`: 명세의 14개 | ✅ ➕ | 14개 모두 있고, 로비·경제·전투 결과용으로 18개를 더해 32개. `RequestSpawnLoadout`은 `SwitchPresetInPreRound`와 같은 처리기를 쓰는 별칭 |
| `UnreliableRemotes`: `ReplicateCharacterState` 20Hz, `ReplicateBowDrawRatio` | ✅ 📝 | 둘 다 있음. 조준 각도를 20Hz로 보내고 서버가 20Hz로 모아 뿌림. 위치는 Roblox 기본 물리 복제가, 슬라이드는 캐릭터 속성이 맡음 |
| 원거리 무기: `Handle`, `MuzzleAttachment`, `StringAttachment` 필수 | ✅ | `Step2/WeaponPrefabs.luau`. `tests/world.luau`가 검사 |
| 나무 활: 5개 각도 부품 활대 + Beam 시위(당기면 손으로 늘어남) + 화살 거치대 | ✅ | 〃, `WeaponAndProjectileController`(시위 휘기) |
| 플린트락: 부싯돌 공이(격발 시 회전) | ✅ | 프리팹에 `HammerMotor`, `CharacterPoses`가 쏠 때 앞으로 젖히고 장전 동안 되돌림 (블런더버스·머스킷도 같음) |
| 슬링: 가죽끈 2줄 Beam + 돌 주머니, 충전 시 원형 회전 | ✅ | 프리팹, `CharacterPoses`(충전할수록 빨라지는 원 그리기) |
| 투척 단검(3개 홀스터), 투창 6 스터드, 작살 밧줄, 볼라 3추, 차크람 칼날 고리 | ✅ | `Step2/WeaponPrefabs.luau` |
| 근접 무기: `DmgPoint` 5~8개 + Trail용 Top/BottomAttachment | ✅ | 〃. `tests/world.luau`가 검사 |
| 다이아몬드 단검 2.2, 철검 4.2, 창 7.5 스터드 길이 등 근접 모델 세부 | ✅ | 〃 |
| 방패: 왼팔, `DestructibleShields` 충돌 파트 | ✅ | `Shield_Model` (`LeftLowerArm`, `ShieldCollider`) |
| Ranked_Melees (카타나+칼집, 낫, 건틀릿 한 쌍, 손도끼 한 쌍) | ✅ | `Ranked_Melees` 폴더. 건틀릿·손도끼는 왼손 `Offhand` |
| 곰 덫: 작동 시 톱니가 90도 닫히는 Tween | ✅ | 경첩 Motor6D 2개(`CloseAngle` ±90), 밟으면 `UtilityAndHealing`이 0.09초 Tween |
| 나무 성벽: 지면에서 솟는 통나무 5개, 8 × 6.5 | ✅ | 프리팹, 설치 시 0.25초 동안 땅에서 솟아오름 |
| 연막탄 도화선, 화염구 네온 코어 + 소용돌이, 뿔피리, 붕대, 사과, 황금 사과(반짝임), 플라스크 | ✅ 📝 | `Step2/UtilityPrefabs.luau`. 명세의 `Apple_And_GoldenApple_Model`은 아이템마다 프리팹을 찾을 수 있도록 `Apple_Model`, `GoldenApple_Model` 두 개로 나눔 |
| 방어구: `UpperTorso` / `LeftUpperArm` / `RightUpperArm`에 WeldConstraint | ✅ | `Step2/ArmorPrefabs.luau`, `Shared/EquipmentRig.luau` |
| VFX: ArrowWindTrail, FireArrowFlame, BulletTracer / HitSpark_Normal, HitSpark_Headshot, ArmorHit_BlueShard, ArmorBreak_Shatter / SmokeCloud_Emitter(16, 8초), HealAura_GreenRing, WarHorn_Pulse + Highlight, Stagger_Stars / KillConfirmation | ✅ ➕ | `Step2/VFXTemplates.luau`. 차크람 궤적, 막기·흙먼지·폭발·물 튀김, 화상·속박·불길, 투사체 모델 12종 추가 |
| 장비 28종+ | ✅ ➕ | 34종 |
| `UpgradeScalingMath`: 10 → 20 → 40 → 80 … Lv10, +4% 복리/선형 | ✅ | `Config/UpgradeScalingMath.luau` |
| `MonetizationCatalog`: Golden Drop 10R$, 연승 복구 20/39/79, 즉시 해금 399/599/799, 부족 창설 299 | 🔁 | Golden Drop만 **9 R$** (실제 게임). 나머지 그대로 |
| `BallisticsEngine`: 포물선, 반사, 부메랑 귀환, 원뿔 산탄 | ✅ ➕ | 거리 감쇠, 광선-상자 판정 추가 |
| `LoadoutBudgetValidator`: 12점, 6칸, 탄약 묶음 화살 12 / 총알 6 / 불화살 6, 방어구 중복 방지 | ✅ 🔁 | 불화살 묶음은 **2점**(실제 게임). 묶음 상한 화살 3 / 총알 2 / 불화살 2 ➕ |
| `SpringPhysics`: 감쇠 진동자 | ✅ | 정확해 사용. 카메라 반동, 시위 떨림, 착지, 뷰모델, FOV |
| `Janitor` | ✅ | |

### 장비 수치

명세의 장비 표와 현재 `EquipmentDatabase`를 필드별로 비교한 결과, 다른 값은 아래 5개뿐입니다. 근거는 [replica/thinktank/report.md](../replica/thinktank/report.md)의 증거 번호입니다.

| 장비 | 필드 | 명세 | 현재 | 근거 |
|---|---|---|---|---|
| 석궁 | HeadMult | 1.65 | 1.75 (헤드샷 87.5) | E2: 헤드샷 86~90 |
| 머스킷 | Cost | 5 | 4 | E9: 4개 출처 중 다수 |
| 슬링 | BaseDmg | 38 | 28 | E5: 26~30 |
| 투척 단검 | Cost | 2 | 1 | E9 |
| 투척 단검 | MaxStack | 6 | 5 | E4: 라운드당 5개 |

나머지 명세 필드(대미지, 헤드샷 배율, 당김·장전 시간, 탄속, 중력, 해금 샤드, 로벅스 가격, 쿨다운, 범위, 지속 시간, 방어구 감쇄율, 이동 패널티, 넉백 저항 등)는 모두 명세 값 그대로입니다. 명세에 없던 필드(설명, 핫바 안내, 투사체 모양, 근접 원호, 조준 FOV 등)는 추가했습니다. 전체는 [reference/equipment.md](reference/equipment.md).

## 03 ServerScriptService

| 명세 | 상태 | 구현 |
|---|---|---|
| ServerMain: 부트스트랩, 서비스 의존성 주입 | ✅ | [02번 문서](02-architecture.md#서버-부팅-순서-servermain) |
| PlayerDataService: 명세 스키마 + 오토세이브 + 세션 락 | ✅ ➕ | 누적 기록, 최고 연승, 영수증 기록 추가. [11번 문서](11-data-and-services.md) |
| 큐 15초 초과 시 봇 충원, `PreventFullBotMatches` | ✅ | `MatchmakingAndBotService` |
| TacticalBotAgent: Pathfinding + 엄폐 피킹 + 거리별 무기 교체 | ✅ ➕ | 회복, 링 회피, 막기 추가. [10번 문서](10-bots.md) |
| 라운드 6단계 6초 / 5초 / 60초 / 4초 / 8초 / 정산 | ✅ | `RoundStateMachineService`, `GameConfig.Phases` |
| 준비 5초 동안 B로 프리셋 교체 | ✅ | `SwitchPresetInPreRound` |
| FLAWLESS (무사망) | ✅ | |
| ACE (1인 3킬) | ✅ 📝 | 한 명이 팀 인원 수 이상(최소 2) 처치. 3v3에서는 정확히 3킬, 1v1·2v2 커스텀에도 맞게 일반화 |
| TEAM ACE (전원 처치) | 📝 | "이긴 팀 전원이 1킬 이상"으로 해석(2명 이상일 때). 적 전원 처치는 모든 승리 라운드에 해당해 구분이 안 되기 때문 |
| POTG: 3승 시 최고 하이라이트 전원 재생 | ✅ | `POTGRecorderAndScorer` |
| 정산: 4장 카드, 23~25 샤드, XP·연승·MVP, PLAY AGAIN 큐 | ✅ ➕ | 패배 팀도 12~14 샤드 |
| 서버 되감기: 1.0초, 20Hz 링 버퍼 | ✅ | `CombatantRegistry`, `GameConfig.Combat` |
| 방어구 15/30/40% 선차감 → ArmorHP → ARMOR BROKEN + 갑옷 모델 파괴 | ✅ | `Combat/DamageModel.luau` |
| 백스탭: 시선 내적 > 0.5 → 250 즉사 | ✅ | 〃 |
| 막기: 철검 정면(내적 < −0.4) 근접 80% 경감 + 스파크 / 방패: 화살·탄 무효 + 화살 박힘 | ✅ | 〃 |
| 해머: 수평 충격 + 0.8초 사격·충전 취소 + STAGGERED | ✅ | 〃 |
| POTG 6초 창, 점수 +100 / ×1.5 / ×2.5 / +50 / +80 / +90 (80 스터드) / +500 | ✅ | `GameConfig.POTG.Weights` |
| POTG 20Hz 타임라인 직렬화·방송 | ✅ | `BroadcastPOTGData` |
| `GenerateVictoryDrop`: 4슬롯 가중치 추출, 23~25 샤드, 신규 유저 초반 해금 우선 | ✅ | `EconomyAndMonetizationService`. 가중치는 [06번 문서](06-progression-economy.md#승리-상자-victory-drop) |
| ProcessReceipt: Golden Drop(~60 샤드 + 미해금 무기 확정), 연승 복구(LastLostStreak → WinStreak), 즉시 해금 | ✅ 🔁 | 가격만 9 R$. 중복 지급 방지와 저장 성공 확인 ➕ |

## 04 StarterPlayerScripts

| 명세 | 상태 | 구현 |
|---|---|---|
| ClientMain: 초기화, 모듈 조율 | ✅ | [02번 문서](02-architecture.md#클라이언트-부팅-순서-clientmain) |
| B: 로비 빌더 / 라운드 전 5초 프리셋 교체 | ✅ | `InputAndKeybindController` |
| C: 카메라 −2.2, WalkSpeed × 1.65 후 마찰 감속, 히트박스 축소 요청 | ✅ | `MovementController`, `SlideRequest`(서버 히트박스 55%) |
| V: 1인칭 ↔ 3인칭, HUD `[first person V]` 강조 | ✅ | `CameraAndViewmodelController`, HUD `ViewModeLabel`(현재 시점을 금색으로) |
| X: 어깨 (±2.5, 1.5, 6.5) | ✅ | `GameConfig.Camera` |
| 1~6 + 휠, 무기별 조작 힌트 | ✅ | `HotbarHint` |
| 1인칭 몸 숨김 + 팔·무기 뷰모델 | ✅ | |
| 조준 FOV 나무 활 55, 헤드헌터 40, 머스킷 45 + 스프링 + 조준선 수축 | ✅ | 나머지 원거리 무기도 지정 ➕ |
| 설정 감도·FOV(70~120)·View Bobbing 즉시 반영 | ✅ | |
| 활 당기기 게이지, 즉시 클라이언트 화살 + 서버 검증 | ✅ | `WeaponAndProjectileController`, `ProjectileRenderer` |
| 근접: 스윙 + Trail + 우클릭 막기 | ✅ | |
| 성벽·덫 초록/빨강 홀로그램 | ✅ | |
| 히트마커 + 포물선 대미지 숫자(`40`, 노랑 `70 HEADSHOT!`, 파랑 `ARMOR BROKEN`, 흰 `STAGGERED`) | ✅ | `CombatFeedbackAndHUDController` |
| 빨간 해골 배너 `ELIMINATED {Name}` + 킬 사운드 | ✅ | |
| `ELIMINATED BY` 카드 → 2.5초 뒤 아군 관전 | ✅ | |
| POTG: 2초 스플래시 → REC 뷰파인더 60FPS Lerp 재생 + SKIP | ✅ | `POTGAndVictorySequenceController` |
| VICTORY DROP: 상자 흔들림·열림 → 카드 4장 순차 뒤집기 (`x3 → x2 → x1`) → 총 샤드, UPGRADE READY | ✅ 📝 | `x3 → x2 → x1`은 상자가 세 번 흔들리는 단계 표시로 구현하고, 카드는 큰 몫부터 차례로 뒤집힘 |
| 6인 스코어보드 K/D/A/DMG, ⭐ MVP 카드, XP 막대, `PLAY AGAIN (25s)` | ✅ | `ScoreboardSummaryUI`, `★ MVP ★` |

## 05 빌더 파이프라인

| 명세 | 상태 | 구현 |
|---|---|---|
| Step 1 충돌 그룹 + 폴더 트리 | ✅ | `Step1/CollisionAndFolders.luau` |
| Step 2 장비 3D 모델 + 파티클 프리팹 | ✅ | `Step2/*` |
| Step 3 로비 + 맵 4종 | ✅ | `Step3/*`. 맵은 ServerStorage에 보관했다가 매치 때 복제 |
| Step 4 ScreenGui 전체 | ✅ | `Step4/*` (11개) |
| Step 5 스크립트 주입·바인딩 | ✅ 📝 | 스크립트는 Rojo가 넣으므로 Step 5는 필요한 스크립트가 제자리에 있는지 확인. 플레이스에 월드가 없으면 `ServerMain`이 Step 1~4를 실행 중에 돌림 |
| Studio에서 즉시 실행 | ✅ | 명령 바 `StudioBuilderPipeline.RunAll`. Lune으로도 같은 파이프라인을 돌려 검사(`tests/world.luau`) |
