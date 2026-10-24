# Tribes 3v3 (Roblox)

3대3 라운드제 원거리/근접 아레나 게임의 Rojo 프로젝트입니다. 모든 맵, 무기, VFX, UI는 코드로 절차적으로 생성되므로 별도의 .rbxl 에셋 없이 동작합니다. 모든 스크립트는 `--!strict` Luau이며 서버는 `ServerMain`, 클라이언트는 `ClientMain` 하나가 진입점입니다.

## 문서

게임 규칙, 수치, 구조, 화면, 데이터, 빌드 방법 전체는 [docs/](docs/README.md)에 있습니다. 장비 34종의 모든 수치, 설정값, 원격 34개, 스크립트 62개의 공개 함수, 월드와 화면의 모든 요소는 코드에서 자동 생성한 [docs/reference/](docs/reference/)에 있습니다. 원본 명세와 구현 대조는 [docs/13-spec-traceability.md](docs/13-spec-traceability.md)를 보세요.

## 구성

| 파일 | 역할 |
| --- | --- |
| `default.project.json` | 로비 플레이스 (최대 50명, 로비 마을, 로드아웃 빌더, 매치메이킹, 트라이브) |
| `arena.project.json` | 아레나 플레이스 (3v3 매치, 맵 4종, POTG, 상자 드롭, 결과 화면) |
| `src/ReplicatedStorage/Modules/Config` | GameConfig, 장비 DB, 수익화 카탈로그, 사운드, 업그레이드 수치 |
| `src/ReplicatedStorage/BuilderModules` | Step 1~4 절차적 빌더 (폴더 트리, 프리팹/VFX, 맵, ScreenGui) |
| `src/ServerScriptService/Services` | 데이터, 전투(랙 보정), 라운드 상태 머신, 매치메이킹/봇, 경제, 트라이브, 리더보드 |
| `src/StarterPlayerScripts/Controllers` | 이동, 카메라/뷰모델, 무기, HUD, POTG/승리 연출, 로비 UI, 입력 |

## 준비

1. [Aftman](https://github.com/LPGhatguy/aftman)을 설치한 뒤 프로젝트 폴더에서 `aftman install`을 실행합니다 (Rojo 7.4.4, Lune 0.10.4).
2. Roblox Studio에 Rojo 플러그인을 설치합니다 (`rojo plugin install` 또는 Creator Store의 Rojo 플러그인).

## Studio와 동기화

**방법 A: 실시간 동기화 (권장)**

```bash
rojo serve                      # 로비 (포트 34872)
rojo serve arena.project.json   # 아레나 (다른 Studio 창에서)
```

Studio에서 빈 Baseplate를 열고 Rojo 플러그인의 **Connect**를 누르면 코드가 들어옵니다. 두 프로젝트를 동시에 띄우려면 `--port`로 포트를 다르게 지정하세요.

**방법 B: 플레이스 파일로 빌드**

```bash
rojo build -o Lobby.rbxl
rojo build arena.project.json -o Arena.rbxl
```

생성된 .rbxl을 Studio에서 열면 됩니다.

**방법 C: 편집 모드에서 월드 미리 만들기 (선택)**

플레이 시 서버가 월드를 자동 생성하지만, 편집 화면에서 보고 싶으면 Studio 명령 바(View → Command Bar)에 입력합니다.

```lua
require(game.ReplicatedStorage.BuilderModules.StudioBuilderPipeline).RunAll({ Role = "Lobby" })
require(game.ReplicatedStorage.BuilderModules.StudioBuilderPipeline).RunAll({ Role = "Arena", PreviewMap = "Map_01_WinterTimberFort" })
```

## 게시 (하나의 경험에 두 플레이스)

1. 로비를 **File → Publish to Roblox**로 새 경험의 시작 플레이스로 게시합니다.
2. Creator Dashboard에서 같은 경험에 플레이스를 하나 더 추가하고 아레나를 그 플레이스로 게시합니다.
3. `src/ReplicatedStorage/Modules/Config/GameConfig.luau`의 `Places.LobbyPlaceId`, `Places.ArenaPlaceId`에 두 PlaceId를 입력하고 두 플레이스를 다시 게시합니다.
   - `ArenaPlaceId`가 0이거나 Studio에서 실행 중이면, 로비가 매치를 로컬 연습전(봇 포함)으로 진행합니다.
4. Game Settings → Security에서 **Enable Studio Access to API Services**를 켜야 Studio에서 DataStore가 동작합니다.
5. 유료 상품: Creator Dashboard에서 Developer Product를 만들고 `MonetizationCatalog.luau`의 각 `ProductId`에 ID를 넣습니다. 0으로 남은 상품은 "미설정"으로 표시되고 구매 창이 뜨지 않습니다.

## 테스트

**자동 테스트 (Studio 없이)**

```bash
lune run tests/run.luau                                   # 로드아웃·탄약·데미지·탄도·업그레이드 규칙 40개
rojo build -o build/Lobby.rbxl && rojo build arena.project.json -o build/Arena.rbxl
lune run tests/world.luau                                 # Studio 빌더를 그대로 돌려 월드·프리팹·화면 14개 검사
lune run tests/place.luau build/Lobby.rbxl build/Arena.rbxl  # 빌드된 플레이스의 스크립트 컴파일, 구조, 원격 이름 검사
lune run tools/gendocs.luau                               # docs/reference 자동 문서 다시 만들기
```

수치 기준과 출처는 `replica/thinktank/report.md`에 있습니다. 실제 게임에서 다른 값을 확인하면 `EquipmentDatabase.luau`와 `tests/run.luau`의 기대값을 함께 고치세요.

**Studio에서 플레이**


- Studio의 **Test → Clients and Servers**로 2~6명 로컬 서버를 띄우면 파티, 매치메이킹, 3v3 흐름을 확인할 수 있습니다. 인원이 모자라면 봇이 채웁니다.
- 출력 창에 `[ServerMain] ... server ready`와 `[ClientMain] client ready`가 보이면 정상입니다.

## 조작법

| 동작 | 키보드/마우스 | 게임패드 |
| --- | --- | --- |
| 발사 / 휘두르기 / 활 당기기 | 좌클릭 | R2 |
| 조준 / 막기 | 우클릭 | L2 |
| 핫바 | 1~6, 마우스 휠 | R1 / L1 |
| 슬라이드 | C | B |
| 1인칭 / 3인칭 | V | Y |
| 어깨 전환 | X | |
| 불화살 | R | |
| 치유 취소 | Q | |
| 차크람 잡기 | F | |
| 달리기 | Shift | L3 |
| 로드아웃 빌더 (로비) / 프리셋 전환 (라운드 준비) | B | DPad 위 |
| 관전 대상 변경 (사망 시) | 좌/우클릭 | |

모바일은 무기를 든 동안 화면에 FIRE, AIM, SLIDE, NEXT, VIEW 버튼이 나타납니다.
