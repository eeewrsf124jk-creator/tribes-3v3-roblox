# 02. 구조

## 두 플레이스

하나의 경험(Experience) 안에 플레이스 두 개를 둡니다. 코드는 같고, Rojo 프로젝트 파일과 `Workspace.PlaceRole` 속성만 다릅니다.

| | 로비 (Place 1) | 아레나 (Place 2) |
|---|---|---|
| Rojo 프로젝트 | `default.project.json` (`Tribes3v3_Lobby`) | `arena.project.json` (`Tribes3v3_CombatArena`) |
| 최대 인원 | 50 | 6 |
| `Workspace.PlaceRole` | `Lobby` | `Arena` |
| 차이 | 캐릭터 자동 생성 | `Players.CharacterAutoLoads = false` (라운드 서비스가 직접 스폰) |
| 빌드되는 월드 | 로비 마을 | 아레나 맵 4종 (ServerStorage에 보관) |
| 시작되는 서비스 | 공통 + `LobbyService`, `LeaderboardService` | 공통 |

매치가 잡히면 로비가 `TeleportService:ReserveServer(ArenaPlaceId)`로 전용 아레나 서버를 만들고 6명을 보냅니다. `ArenaPlaceId`가 0이거나 Studio에서 실행 중이면 로비 서버 안에서 매치를 연습 모드로 돌립니다. 아레나 플레이스만 단독으로 실행하면 혼자서 봇과 싸우는 매치가 바로 시작됩니다.

두 프로젝트 공통 설정:

- Workspace: `Gravity = 196.2`, `FallenPartsDestroyHeight = -500`, `StreamingEnabled = true`, `SignalBehavior = Deferred`
- StarterGui: `ResetPlayerGuiOnSpawn = false`
- StarterPlayer: 카메라 줌 0.5~18
- Lighting: `Technology = Future`
- `Teams` 서비스 포함

## Rojo 매핑

| 소스 폴더 | Studio 위치 |
|---|---|
| `src/ReplicatedStorage/Modules` | `ReplicatedStorage.Modules` |
| `src/ReplicatedStorage/BuilderModules` | `ReplicatedStorage.BuilderModules` |
| `src/ServerScriptService/ServerMain.server.luau` | `ServerScriptService.ServerMain` (Script) |
| `src/ServerScriptService/Services` | `ServerScriptService.Services` |
| `src/StarterPlayerScripts/ClientMain.client.luau` | `StarterPlayer.StarterPlayerScripts.ClientMain` (LocalScript) |
| `src/StarterPlayerScripts/Controllers` | `StarterPlayer.StarterPlayerScripts.Controllers` |

## 단일 진입점

실행되는 스크립트는 `ServerMain`과 `ClientMain` 두 개뿐이고, 나머지 60개는 ModuleScript입니다. 진입점이 서비스와 컨트롤러를 정해진 순서로 불러와 시작합니다. `tests/place.luau`가 빌드된 플레이스에서 실행 스크립트가 정확히 2개인지 확인합니다.

### 서버 부팅 순서 (`ServerMain`)

1. `Net.InitServer()`: 원격 채널 34개를 `ReplicatedStorage.RemoteNetwork_Events` 아래에 만듭니다.
2. 월드 준비. 플레이스에 이미 만들어 둔 것이 있으면(`Built` 속성) 건너뜁니다.
   - Step 1: 충돌 그룹 6개 등록, Workspace 속성, 런타임 폴더 트리
   - Step 2: 장비 프리팹과 VFX 템플릿
   - Step 3: 로비 마을 또는 아레나 맵 4종
   - Step 4: 빠진 ScreenGui 생성. 이미 접속한 플레이어에게도 복사
3. `Workspace.WorldReady = true`
4. 서비스 시작: `PlayerData` → `Combat` → `Recorder`(POTG) → `Economy` → `Tribes` → `Round` → `Matchmaking`
5. 로비 플레이스면 `Lobby`, `Leaderboards`도 시작

### 클라이언트 부팅 순서 (`ClientMain`)

1. 상태 브리지 연결: `ProfileSync`, `InventorySync`, `RoundStateChanged`, `Notify`를 `ClientState`에 연결합니다. 컨트롤러보다 먼저 연결해서 그 사이에 온 메시지를 놓치지 않습니다.
2. 화면 준비: PlayerGui에 같은 이름의 ScreenGui가 두 번 생기면 나중 것을 지웁니다. 게임 로드와 `WorldReady`(최대 30초)를 기다린 뒤 `Step4.EnsureAll(PlayerGui)`로 빠진 화면을 직접 만듭니다. 아레나는 캐릭터가 늦게 생겨 StarterGui 복사가 늦기 때문입니다.
3. 컨트롤러를 이 순서로 불러와 모두 `Init()` 한 다음 모두 `Start()` 합니다.
   `MovementController` → `CameraAndViewmodelController` → `WeaponAndProjectileController` → `CombatFeedbackAndHUDController` → `POTGAndVictorySequenceController` → `LobbyUIController` → `InputAndKeybindController`
4. 가장 최근 상태(프로필, 인벤토리, 라운드)를 한 번 더 보내 늦게 시작한 컨트롤러도 따라잡게 합니다.

컨트롤러끼리는 서로를 직접 부르지 않고 `ClientState`의 값과 신호(`ProfileChanged`, `InventoryChanged`, `RoundChanged`, `Notify` 등)로 주고받습니다. 예외는 입력 컨트롤러로, 키 입력을 각 컨트롤러 함수에 바로 연결합니다.

## 서버 서비스 한눈에 보기

| 서비스 | 맡은 일 |
|---|---|
| `PlayerDataService` | DataStore 프로필, 세션 락, 자동 저장, 설정, 로드아웃 저장 |
| `LagCompensatedCombatService` | 전투 원격 검증, 근접 판정, 이동 속도 배율, 상태 복제 |
| `Combat/CombatantRegistry` | 플레이어·봇·허수아비 목록과 20Hz 히트박스 기록 |
| `Combat/DamageModel` | 대미지 계산의 유일한 경로: 막기 → 방어구 → 체력 → 넉백·처치 |
| `Combat/ProjectileSimulator` | 서버 투사체 비행, 되감기 판정, 차크람 반사·귀환 |
| `Combat/UtilityAndHealing` | 덫, 성벽, 연막, 화염구, 회복 플라스크, 뿔피리, 회복 아이템, 화상·지속 회복 |
| `RoundStateMachineService` | 매치 루프 6단계, 스폰, 링, 승패, POTG, 정산 |
| `MatchmakingAndBotService` | 파티, 큐, 커스텀 방, 아레나 이동 |
| `Bots/TacticalBotAgent` | 봇 AI |
| `POTGRecorderAndScorer` | 20Hz 기록, 하이라이트 점수 |
| `EconomyAndMonetizationService` | 상자, 샤드, 해금·강화, 정산, 유료 상품 영수증 |
| `TribeService` | 트라이브 생성·가입·검색, 주간 Glory |
| `LeaderboardService` | 로비 전광판 3개와 동상 |
| `LobbyService` | 부스 상호작용, 1v1 결투장, 사격장 |

각 파일의 공개 함수와 의존성은 [reference/modules.md](reference/modules.md)에 모두 있습니다.

## 클라이언트 컨트롤러 한눈에 보기

| 컨트롤러 | 맡은 일 |
|---|---|
| `ClientState` | 클라이언트 상태의 단일 출처와 신호 |
| `UIUtil` | 화면 요소 찾기, 트윈, 템플릿 복제, 토스트, 아이템 아이콘·색 |
| `MovementController` | 걷기·달리기 속도, 슬라이드, 넉백, 속박 |
| `CameraAndViewmodelController` | 어깨 시점·1인칭 카메라, 뷰모델, 조준 FOV, 반동 |
| `WeaponAndProjectileController` | 입력을 전투 요청으로, 당기기·충전, 근접, 투척 궤적 미리보기, 설치 홀로그램 |
| `ProjectileRenderer` | 투사체 그리기, 내 발사 예측, 서버 결과 맞추기 |
| `CharacterPoses` | 조준 각도, 활 당김, 막기 등 상체 자세 |
| `CombatFeedbackAndHUDController` | 전투 화면 전체 |
| `POTGAndVictorySequenceController` | POTG 재생, 승리 상자, 결과표 |
| `LobbyUIController` | 로비 화면과 모달 |
| `InputAndKeybindController` | 키보드·마우스·게임패드·터치 입력 |

## 충돌 그룹

`Modules/Shared/CollisionGroups.luau`가 등록하는 6개 그룹입니다. "충돌"은 서로 부딪히거나 레이캐스트에 걸린다는 뜻입니다.

| | MapGeometry | PlayerMovementBox | HitboxParts | Projectiles | DestructibleShields | RagdollLimbs |
|---|---|---|---|---|---|---|
| MapGeometry | 충돌 | 충돌 | 충돌 | 충돌 | 충돌 | 충돌 |
| PlayerMovementBox | 충돌 | - | - | - | 충돌 | - |
| HitboxParts | 충돌 | - | - | 충돌 | - | - |
| Projectiles | 충돌 | - | 충돌 | - | 충돌 | - |
| DestructibleShields | 충돌 | 충돌 | - | 충돌 | - | - |
| RagdollLimbs | 충돌 | - | - | - | - | - |

- 캐릭터끼리는 서로 통과해서 끼임이 없습니다.
- 투사체는 맵, 히트박스, 방패·성벽만 맞힙니다.
- 사망 래그돌은 맵에만 부딪혀 산 사람을 막지 않습니다.

## 런타임 폴더

라운드마다 비워지는 Workspace 폴더입니다(`Runtime_Dynamic_Containers`).

| 폴더 | 들어가는 것 |
|---|---|
| `AliveCharacters_Alpha` / `AliveCharacters_Bravo` | 팀별 살아 있는 캐릭터 |
| `ActiveProjectiles_Container` | 날아가는 화살, 탄, 단검, 차크람, 볼라, 작살 |
| `DeployedUtilities_Container` | 설치된 성벽, 덫, 연막, 화염 |
| `Ragdolls_And_StuckArrows` | 래그돌과 박힌 화살 |

라운드가 바뀔 때 `Janitor`(`Modules/Shared/Janitor.luau`)가 인스턴스, 연결, 트윈, 스레드를 한꺼번에 정리해 이전 라운드의 흔적이 남지 않게 합니다.

## 공유 수학 모듈

| 모듈 | 내용 |
|---|---|
| `BallisticsEngine` | 포물선 P(t) = P0 + V0·t + ½·g·t², 반사 R = V − 2(V·N)N, 부메랑 귀환, 원뿔 산탄, 거리 감쇠, 광선-상자 판정 |
| `SpringPhysics` | 감쇠 진동자 x'' + 2ζωx' + ω²x = 0의 정확해. 카메라 반동, 시위 떨림, 착지, 뷰모델 흔들림, FOV |
| `LoadoutBudgetValidator` | 로드아웃 검증 (서버와 클라이언트가 같은 코드 사용) |
| `Signal` | 서비스 사이 이벤트 |
| `Net` | 원격 채널 생성과 인자 검사 (`IsFiniteNumber`, `IsVector3`, `IsString`) |
