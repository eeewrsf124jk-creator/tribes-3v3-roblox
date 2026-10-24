# 12. 빌드, 테스트, 게시

## 도구

| 도구 | 버전 | 용도 |
|---|---|---|
| [Aftman](https://github.com/LPGhatguy/aftman) | - | 아래 도구 설치 (`aftman install`) |
| Rojo | 7.4.4 | 소스 → Studio 동기화, `.rbxl` 빌드 |
| Lune | 0.10.4 | Studio 없이 테스트와 문서 생성 실행 |
| Roblox Studio + Rojo 플러그인 | - | 실행, 게시 |
| selene (선택) | - | 린트 (`selene.toml`: `std = "roblox"`) |
| luau-lsp (선택) | - | 엄격 모드 타입 검사 (`.luaurc`: `languageMode = strict`) |

`aftman.toml`에 Rojo와 Lune 버전이 고정돼 있습니다.

## 폴더 구조

```
default.project.json     로비 플레이스 (Tribes3v3_Lobby)
arena.project.json       아레나 플레이스 (Tribes3v3_CombatArena)
src/
  ReplicatedStorage/
    Modules/Config/        GameConfig, EquipmentDatabase, MonetizationCatalog, SoundCatalog, UpgradeScalingMath
    Modules/Shared/        Types, Net, Signal, Janitor, BallisticsEngine, SpringPhysics, LoadoutBudgetValidator, CollisionGroups, EquipmentRig, VFX
    BuilderModules/        StudioBuilderPipeline + Kit(GeometryKit, MapKit, UIKit) + Step1~4
  ServerScriptService/
    ServerMain.server.luau
    Services/              서비스 9개 + Combat/ 4개 + Bots/ 1개
  StarterPlayerScripts/
    ClientMain.client.luau
    Controllers/           컨트롤러와 클라이언트 모듈 11개
tests/                   harness.luau, run.luau, world.luau, place.luau
tools/gendocs.luau       docs/reference 자동 생성
docs/                    이 문서들
replica/                 실제 게임 수치 조사 보고서와 결정 기록
build/                   빌드된 .rbxl (git에 올리지 않음)
```

파일 62개 전체와 각 파일의 공개 함수는 [reference/modules.md](reference/modules.md)에 있습니다.

## Studio에서 실행

### 방법 A: 실시간 동기화 (권장)

```bash
rojo serve                                  # 로비, 포트 34872
rojo serve arena.project.json --port 34873  # 아레나 (다른 Studio 창)
```

Studio에서 빈 Baseplate를 열고 Rojo 플러그인의 **Connect**를 누릅니다. 코드를 저장하면 바로 Studio에 반영됩니다.

### 방법 B: 플레이스 파일

```bash
rojo build -o build/Lobby.rbxl
rojo build arena.project.json -o build/Arena.rbxl
```

`.rbxl`을 Studio에서 열고 **Play**를 누르면 서버가 월드(마을 또는 맵 4종), 프리팹, 화면을 만들고 시작합니다. 처음 실행은 월드 생성 때문에 몇 초 걸립니다.

### 방법 C: 편집 화면에서 월드 미리 만들기

명령 바(View → Command Bar)에 입력하면 플레이하지 않아도 월드가 생깁니다. 이렇게 만들어 두면 서버가 `Built` 속성을 보고 다시 만들지 않습니다.

```lua
require(game.ReplicatedStorage.BuilderModules.StudioBuilderPipeline).RunAll({ Role = "Lobby" })
require(game.ReplicatedStorage.BuilderModules.StudioBuilderPipeline).RunAll({ Role = "Arena", PreviewMap = "Map_01_WinterTimberFort" })
```

`PreviewMap`에는 `Map_01_WinterTimberFort`, `Map_02_DesertColosseum`, `Map_03_HighlandHenge`, `Map_04_IcefallFjord` 중 하나를 넣습니다.

### Studio에서 확인할 것

- 출력 창에 `[ServerMain] ... server ready`, `[ClientMain] client ready`가 보이면 정상입니다.
- **Test → Clients and Servers**로 2~6명을 띄우면 파티, 큐, 3v3를 확인할 수 있습니다. 모자란 자리는 15초 뒤 봇이 채웁니다.
- 로비 Studio 실행에서는 아레나로 텔레포트하지 않고 로비 안에서 매치가 돌아갑니다(멀리 떨어진 곳에 맵 복제).
- 아레나 플레이스를 단독으로 Play하면 혼자 봇 5명과 싸우는 연습 매치가 바로 시작됩니다.
- DataStore를 쓰려면 Game Settings → Security → **Enable Studio Access to API Services**를 켭니다. 꺼져 있으면 저장되지 않는 메모리 프로필로 동작합니다.

## 게시 (하나의 경험에 두 플레이스)

1. 로비 플레이스를 **File → Publish to Roblox**로 새 경험의 시작 플레이스로 게시합니다.
2. Creator Dashboard에서 같은 경험에 플레이스를 하나 추가하고, 아레나 플레이스를 거기에 게시합니다.
3. `Modules/Config/GameConfig.luau`의 `Places.LobbyPlaceId`, `Places.ArenaPlaceId`에 두 PlaceId를 넣고 두 플레이스를 다시 게시합니다. `ArenaPlaceId`가 0이면 로비가 매치를 로비 안에서 돌립니다.
4. 각 플레이스의 최대 인원을 로비 50, 아레나 6으로 맞춥니다(프로젝트 파일에도 들어 있음).
5. 경험 설정에서 API Services(DataStore)를 켭니다.

### 유료 상품 설정

1. Creator Dashboard → 경험 → Monetization → Developer Products에서 아래 8개를 만듭니다.
2. 만든 상품의 ID를 `src/ReplicatedStorage/Modules/Config/MonetizationCatalog.luau`의 같은 Key 항목 `ProductId`에 넣습니다.
3. 다시 게시합니다.

| Key | 이름 | 가격 |
|---|---|---|
| `GoldenDrop` | Golden Drop | 9 R$ |
| `RestoreStreakSmall` | Restore Streak (1-4) | 20 R$ |
| `RestoreStreakMedium` | Restore Streak (5-9) | 39 R$ |
| `RestoreStreakLarge` | Restore Streak (10+) | 79 R$ |
| `ItemUnlock399` | Instant Unlock (Tier 1) | 399 R$ |
| `ItemUnlock599` | Instant Unlock (Tier 2) | 599 R$ |
| `ItemUnlock799` | Instant Unlock (Tier 3) | 799 R$ |
| `TribeCreation` | Found a Tribe | 299 R$ |

`ProductId`가 0인 상품은 실제 서버에서 "not available yet"을 보여 주고 결제 창을 띄우지 않습니다. Studio에서는 결제 없이 바로 지급해 흐름을 시험할 수 있습니다. `TribeCreation`이 0이면 트라이브 만들기가 무료입니다.

## 자동 테스트 (Studio 없이)

저장소 루트에서 실행합니다.

```bash
# 1) 규칙과 수치
lune run tests/run.luau

# 2) 플레이스 빌드
rojo build -o build/Lobby.rbxl
rojo build arena.project.json -o build/Arena.rbxl

# 3) 빌더가 실제로 만드는 월드
lune run tests/world.luau

# 4) 빌드된 플레이스 구조
lune run tests/place.luau build/Lobby.rbxl build/Arena.rbxl
```

| 파일 | 검사 내용 |
|---|---|
| `tests/run.luau` (40개) | 매치 규칙(3선승, 3v3), 12포인트·프리셋 5개, 실제 게임 기준 포인트 17종(가죽·철·다이아 갑옷, 단검, 철검, 해머, 활, 석궁, 머스킷, 블런더버스, 슬링, 투척 단검, 붕대, 연막탄, 곰 덫, 황금 사과), 기준 대미지(석궁 몸 45~50·머리 86~90, 슬링 26~30, 투척 단검 약 30·5개, 블런더버스 근접 즉사·중거리 펠릿 약 6, 단검 백스탭 즉사), 탄약 묶음(화살 12발/1점 최대 36, 불화살 6발/2점, 총알 6발/1점 최대 12), 활·총의 탄약 필수 규칙, 기본 프리셋 합법성, 커뮤니티 시작 빌드, 예산 초과·중복·방어구 칸 오용·잠긴 아이템 거부, 네트워크 입력 정리(`Sanitize`), 데이터베이스 무결성(필드, `Order`), 탄도(포물선 닫힌 식, 반사, 펠릿 결정성과 원뿔, 거리 감쇠), 강화 샤드 2배 증가와 Lv10 한계, 골든 드롭 9 R$ |
| `tests/world.luau` (14개) | Lune 안에서 Studio 빌더 Step 1~5를 그대로 돌려: 충돌 그룹과 런타임 폴더, 11개 화면, 모든 장비에 프리팹이 있는지, 원거리 무기의 `Handle`/`MuzzleAttachment`, 근접 무기의 `DmgPoint` 수, 로비 구역과 스폰 12개, 맵 4종의 `TeamSpawns`·링·POTG 무대 |
| `tests/place.luau` | 두 `.rbxl`을 열어: 모든 스크립트가 `--!strict`이고 컴파일되는지, `PlaceRole`, 진입점 2개(Script / LocalScript)와 위치, 컨트롤러·핵심 모듈 위치, 코드가 부르는 모든 원격 이름이 `Net`에 선언됐는지, 실행 스크립트가 정확히 2개인지 |

`tests/harness.luau`는 Lune에서 Roblox 모듈을 불러오는 장치입니다.

- **모듈 모드** (`H.Load`): 소스 파일을 직접 읽고 가짜 `script` 트리로 `require`를 풀어 줍니다.
- **월드 모드** (`H.UseWorld`): 빌드된 `.rbxl`을 열어 그 안의 ModuleScript를 `.Source`로 실행합니다. `RunService`, `GeometryService`(CSG는 실패시켜 용접 Model로 대체), `PhysicsService`(충돌 그룹 기록), `WaitForChild`, `GetJoints`, `GetPivot/PivotTo`, `ParticleEmitter:Emit` 같은 엔진 기능을 흉내 냅니다.
- Lune의 Vector3는 float32라서 수치 비교에는 오차 허용을 둡니다.

수치 기준과 출처는 [replica/thinktank/report.md](../replica/thinktank/report.md)에 있습니다. 실제 게임에서 다른 값을 확인하면 `EquipmentDatabase.luau`와 `tests/run.luau`의 기대값을 함께 고칩니다.

## 레퍼런스 문서 다시 만들기

`docs/reference/*.md`는 손으로 쓰지 않습니다. 코드를 바꾼 뒤에는 다시 생성합니다.

```bash
rojo build -o build/Lobby.rbxl
rojo build arena.project.json -o build/Arena.rbxl
lune run tools/gendocs.luau
```

| 생성 파일 | 원본 |
|---|---|
| `equipment.md` | `EquipmentDatabase` 34종의 모든 필드, 탄약 묶음, 랭크 해금, 기본 프리셋 |
| `config.md` | `GameConfig` 전체, 유료 상품, 업그레이드 표, 사운드 |
| `remotes.md` | `Net`의 원격 34개와 코드에서 쓰이는 모든 줄 |
| `modules.md` | 파일 62개의 위치·종류·줄 수·머리 주석·의존성·공개 함수·타입 |
| `types.md` | `Types.luau`의 모든 타입 |
| `world.md` | 빌더를 실제로 돌린 결과: 충돌 매트릭스, 로비·맵 트리와 파트 수, 프리팹, VFX |
| `ui.md` | 11개 화면의 모든 요소와 기본 문구 |

## 타입 검사

luau-lsp가 있으면 Rojo sourcemap을 만든 뒤 프로젝트마다 검사합니다.

```bash
rojo sourcemap default.project.json -o sourcemap.json
luau-lsp analyze --platform=roblox --sourcemap=sourcemap.json --definitions=globalTypes.d.luau --base-luaurc=.luaurc src
rojo sourcemap arena.project.json -o sourcemap.json
luau-lsp analyze --platform=roblox --sourcemap=sourcemap.json --definitions=globalTypes.d.luau --base-luaurc=.luaurc src
```

`globalTypes.d.luau`는 luau-lsp 저장소의 `scripts/globalTypes.d.luau`(Roblox API 타입)입니다. 두 프로젝트 모두 오류 0개가 기준입니다. `sourcemap.json`은 git에 올리지 않습니다.

## 문제 해결

| 증상 | 원인과 해결 |
|---|---|
| Rojo 플러그인이 연결되지 않음 | `rojo serve`가 떠 있는지, 플러그인의 포트가 같은지(기본 34872) 확인. 두 프로젝트를 동시에 띄우면 하나는 `--port`로 다른 포트를 씀 |
| 출력 창에 `[PlayerData] Studio API access disabled, using in-memory profiles` | Studio에서 API 접근이 꺼진 상태. 게임은 되지만 저장되지 않음. Game Settings → Security에서 켬 |
| 접속하자마자 "Could not load your profile ... Please rejoin." | 다른 서버가 프로필 락을 쥐고 18초 안에 놓지 않았거나 DataStore 오류. 잠시 뒤 다시 접속하면 락이 만료돼 이어받음 |
| 상점 버튼을 누르면 "... is not available yet" | 해당 상품의 `ProductId`가 0. [유료 상품 설정](#유료-상품-설정) |
| 큐에 들어가도 아레나로 이동하지 않음 | Studio이거나 `ArenaPlaceId`가 0이라 로비 안에서 매치가 돌아가는 것이 정상. 게시한 뒤 PlaceId를 넣어야 텔레포트함 |
| `Infinite yield possible on ...RemoteNetwork_Events...` | `Net.luau` 목록에 없는 이름으로 원격을 찾음. 목록에 이름을 추가하고 `tests/place.luau`로 확인 |
| 편집 화면에 월드가 없음 | 정상. 플레이할 때 서버가 만듦. 미리 보려면 위의 방법 C |
| 월드나 화면을 고쳤는데 Studio에 그대로임 | 편집 화면에서 미리 만든 월드에는 `Built` 속성이 있어 다시 만들지 않음. 해당 폴더를 지우거나 `RunAll({ RebuildGui = true })`로 화면을 다시 만듦 |
