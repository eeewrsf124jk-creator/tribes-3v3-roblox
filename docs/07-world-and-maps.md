# 07. 월드와 맵

관련 코드: `BuilderModules/Step3/*`, `BuilderModules/Kit/MapKit.luau`, `LobbyService.luau`, `LeaderboardService.luau`, `RoundStateMachineService.luau`(맵 불러오기). 모든 파트의 트리와 개수는 [reference/world.md](reference/world.md)에 있습니다.

모든 월드는 코드로 만들어집니다. 외부 메시나 에셋은 쓰지 않고 Part, WedgePart, CornerWedgePart, 파티클, 빛으로만 구성합니다. 좌표 규칙은 지면 y = 0, Alpha 팀은 −Z 쪽, Bravo 팀은 +Z 쪽입니다.

## 로비 마을 (`Workspace.Lobby_50Player_World`)

480 × 480 스터드 잔디 위에 지어진 50인 마을입니다. 파트 1,702개. 광장에서 네 방향으로 흙길이 나 있고, 가장자리는 소나무 40그루가 두릅니다.

| 구역 | 위치 (x, z) | 내용 |
|---|---|---|
| 스폰 광장 `SpawnPlaza_Center` | (0, 0) | 반지름 72의 원형 석판 광장(타일 링 10겹 + 연석), 3단 분수(물소리 반복 재생), 반지름 34에 SpawnLocation 12개(분수를 바라봄), 가로등 8개 |
| 로드아웃 노점 `Loadout_Stall` | (92, −22) | 줄무늬 차양, 무기 진열대(철검·나무 활·해머·석궁·창 실물 프리팹 전시), `LoadoutZone` |
| 커스텀 매치 오두막 `CustomMatches_Cabin` | (92, 30) | 통나무 오두막, 매치 게시판, 모닥불 |
| 트라이브 홀 `TribeHall_Building` | (−118, 0) | 돌 1층 + 목조 2층, 깃발 2개, 제단과 불꽃, `TribeZone` |
| 전광판 `Global_3D_Leaderboards` | z = −100 부근 | 3D 전광판 3개(x = −42, 0, 42)와 동상 받침대 3개(z = −88) |
| 결투장 `LiveDuelArena` | (0, 130) | 44 × 44, 6 스터드 깊이로 파인 모래 구덩이, 계단, 결투 패드 2개, `[XX LIVE]` 전광판 |
| 사격장 `TargetPracticeRange` | 사격선 (110, 92) | 허수아비 3개(20 / 50 / 100 스터드), 거리 표지판, 뒤쪽 흙둔덕 |

### 상호작용 프롬프트

| 위치 | 표시 | 키 | 거리 | 여는 것 |
|---|---|---|---|---|
| 로드아웃 노점 카운터 | Loadout Builder · [B] | B | 12 | 로드아웃 빌더 |
| 오두막 책상 | Custom Matches · Cabin | E | 12 | 커스텀 매치 창 |
| 트라이브 홀 제단 | Tribe Hall · Create / Join | E | 14 | 트라이브 창 |
| 결투 패드 1 / 2 | Join Duel · Slot 1 / 2 | E | 10 | 결투 참가 |

프롬프트에는 `Interface` 속성이 붙어 있고, `LobbyService`가 이 값을 보고 해당 화면을 엽니다.

구역(`InterfaceZone` 태그) 안에 들어가면 화면 아래에 안내 문구가 뜹니다.

| 구역 | 안내 |
|---|---|
| LoadoutZone | [B] Open the Loadout Builder |
| TribeZone | [E] Tribe Hall: found or join a tribe |
| DuelZone | Duel Pit: stand on a pad and press [E] for a 1v1 |
| TrainingZone | Training Range: your active preset is armed here |

### 1v1 결투장

1. 패드 위에서 E를 누르면 그 자리를 맡습니다. 이미 다른 사람이 있으면 "That side is taken".
2. 패드에서 14 스터드 넘게 떨어지면 자리를 잃습니다(0.5초마다 확인).
3. 두 자리가 차면 두 사람을 각자의 **현재 프리셋**으로 무장시켜 패드 위에 마주 보게 세우고, 3초 뒤 "FIGHT!"와 함께 전투가 켜집니다.
4. 한 명이 쓰러지거나 나가면 서버 전체에 "⚔ (이름) wins the duel!"을 알리고, 3초 뒤 두 사람을 다시 스폰합니다.
5. 결투가 진행 중이면 새 참가를 받지 않습니다. 매치 중인 플레이어도 참가할 수 없습니다.

전광판은 2초마다 결투장 중심 45 스터드 안의 사람 수(결투자 + 관전자)를 `DUEL PIT  [N LIVE]`로 보여 줍니다.

### 사격장

- `TrainingZone`(44 × 12 × 120)에 들어가면 현재 프리셋으로 무장됩니다. 나가면 해제됩니다.
- 허수아비는 체력 100이지만 **죽지 않고**, 맞은 대미지를 머리 위에 `-35`, 헤드샷이면 노란색 `HEADSHOT  -61`처럼 2초 동안 보여 준 뒤 `20 STUDS` 같은 거리 표시로 돌아갑니다.
- 허수아비는 좌우로 ±5 스터드 사인파로 흔들립니다(`sin(t·0.8 + i·1.3) × 5`).

### 전광판과 동상

| 전광판 | 제목 | 데이터 |
|---|---|---|
| `Board_TopTribes` | TOP TRIBES · WEEKLY GLORY | 트라이브 주간 Glory (`TribeService`) |
| `Board_MostEliminations` | MOST ELIMINATIONS | OrderedDataStore `LB_Eliminations_v1` (누적 처치) |
| `Board_LongestStreaks` | LONGEST STREAKS 🔥 | OrderedDataStore `LB_LongestStreak_v1` (최고 연승) |

- 각 판에 1~50위가 표시됩니다(`LeaderboardSize` 50). 월드의 SurfaceGui는 마우스 입력을 받지 않으므로, 클라이언트가 목록을 자동으로 스크롤합니다(맨 위 3초 → 초당 40픽셀로 내려감 → 맨 아래 3초 → 처음으로).
- 60초(`LeaderboardRefresh`)마다 접속 중인 플레이어 기록을 저장하고 다시 불러옵니다.
- 처치 1~3위의 아바타가 금·은·동색 대리석 동상으로 받침대(높이 5 / 3.5 / 2.5)에 세워집니다.
- DataStore를 쓸 수 없으면(Studio에서 API 접근이 꺼진 경우) 접속 중인 플레이어 기록으로 대신 채웁니다.

## 아레나 맵 4종

아레나 맵은 `ServerStorage.ArenaMapStorage`에 보관되고, 매치가 시작되면 넷 중 하나를 무작위로 골라 `Workspace.Arena_Maps_Pool`에 복제합니다. 모두 **220 × 300 스터드, 점대칭**(Bravo 쪽은 Alpha 쪽을 Y축으로 180도 돌린 것)이라 어느 팀이든 같은 지형에서 싸웁니다.

| 맵 | 테마 | 시간(ClockTime) | 안개 끝 | 대기 밀도 | 파트 |
|---|---|---|---|---|---|
| Winter Timber Fort | 눈 덮인 통나무 요새 | 9.2 (아침) | 700 | 0.38 | 2,120 |
| Desert Colosseum | 사암 신전 투기장 | 15.5 (오후) | 900 | 0.30 | 579 |
| Highland Henge | 고원의 거석 유적 | 17.2 (저녁) | 650 | 0.42 | 475 |
| Icefall Fjord | 빙하 폭포 항구 | 11 (한낮) | 600 | 0.45 | 670 |

아레나 플레이스에서는 맵의 속성으로 `Lighting.ClockTime`, `OutdoorAmbient`, `FogColor`, `FogEnd`, `Atmosphere.Density`를 바꿉니다. 로비 안 연습 매치는 로비 조명을 그대로 두고, 맵을 z = 4000부터 1,200 간격으로 떨어진 곳에 복제해 여러 매치가 겹치지 않게 합니다.

모든 맵은 같은 폴더 구조를 가집니다: `TeamSpawns`, `MidLane_*`, `SideLanes_*`, `CoverAndProps`, `Shared_Map_Mechanics`.

### Map 01: Winter Timber Fort

| 구역 | 내용 |
|---|---|
| 팀 스폰 | 통나무 울타리 요새. 스폰 패드 3개, 모닥불, 정문(폭 10)의 스폰 보호막, 앞벽 안쪽 사격 발판 |
| 중앙 | 얼어붙은 강 참호를 건너는 나무 다리. 난간 높이 3.8로 반엄폐. 다리 밑으로 얼음 우회로 |
| 측면 | 2층 망루 4개. 계단과 저격용 발코니 창 |
| 엄폐물 | 눈 덮인 소나무 16그루(높이 12, 완전 엄폐), 상자 14개(높이 4, 반엄폐), 통나무 바리케이드 8개, 눈더미 18개 |

### Map 02: Desert Colosseum

| 구역 | 내용 |
|---|---|
| 팀 스폰 | 사암 열주 현관. 스폰 패드 3개, 양옆 화로, 스폰 보호막 |
| 중앙 | 원형 제단에 꽂힌 거대한 청동 검(완전 엄폐)과 붉은 문양 석재 블록 8개(반엄폐) |
| 측면 | 청록 돔 신전 2개. 내부 복도는 근접전 병목, 지붕으로 올라가는 계단 |
| 엄폐물 | 부서진 기둥 12개, 야자수 8그루, 토기 항아리 10개. 바깥은 투기장 벽 4면과 장식 아치 28개 |

### Map 03: Highland Henge

| 구역 | 내용 |
|---|---|
| 팀 스폰 | 초가 오두막. 옆에 쌓인 상자(1단 → 2단 → 높이 9의 처마)를 밟고 지붕에 올라가 고지대 확보(헤드헌터·머스킷용). 지붕 경사 32도로 걸을 수 있음 |
| 중앙 | 높이 14의 거석 8개를 둥글게 세우고 덮개돌 4개를 얹은 고리. 숨었다 나왔다 하는 견제 구역 |
| 측면 | 서쪽: 얕은 해안 수로(물 튀김). 동쪽: 높이 3의 낮은 돌담(슬라이드 엄폐). 둘 다 맵 전체 길이 |
| 엄폐물 | 이끼 바위 10개, 수레 4대, 건초 더미 10개 |

### Map 04: Icefall Fjord

| 구역 | 내용 |
|---|---|
| 팀 스폰 | 얼음 바다 위 나무 부두. 서쪽 경계 뒤로 거대한 빙하 폭포(Beam 물줄기 + 아래 물안개 파티클 6곳) |
| 중앙 | 비스듬히 좌초된 큰 나무 배. 양쪽 계단으로 갑판 고지대에 오르고, 돛대와 접은 돛이 엄폐 |
| 측면 | 붉은 목조 창고 2동. 양 끝 문, 옆 창문 사격각, 미끄러져 내려올 수 있는 박공지붕 |
| 엄폐물 | 푸른 얼음 바위 10개, 생선 통 10개, 밧줄 더미 24개. 부두 아래 얼음 물, 묶인 나룻배 |

### 공통 장치 (`Shared_Map_Mechanics`)

| 장치 | 동작 |
|---|---|
| 스폰 패드 (`ArenaSpawnPad` 태그) | 팀별 3개. `Team`, `SpawnIndex`, `Facing` 속성으로 스폰 위치와 바라보는 방향을 정함. 3명보다 많으면 순서대로 돌려 씀 |
| 스폰 보호막 (`SpawnBarrier` 태그) | 팀 색 ForceField 벽. 라운드 준비 5초 동안 닫혀 있다가(반투명 0.3, 충돌 켬) FIGHT! 순간 열림(투명, 충돌 끔) |
| 보이지 않는 벽 `Invisible_ClipBrushes` | 맵 네 변과 천장(높이 70)을 막는 경계, 엄폐물 안쪽 모서리에 끼이지 않게 하는 45도 쐐기 |
| 링 오브 파이어 `RingOfFire_BoundaryCylinder` | 반지름 180, 높이 120의 주황 ForceField 원통 `FireWall`. 링이 켜지면 보이고(투명도 0.15), `Active`, `ShrinkStartsAt` 속성이 붙습니다. 실제 판정 반경은 라운드 상태로 계산하고, HUD가 `🔥 RING OF FIRE CLOSING · N studs`로 현재 반경을, 원 밖이면 깜빡이는 경고를 보여 줍니다. 링 피해는 방어구와 막기를 무시합니다 |
| POTG 무대 `POTG_CinematicStage` | `Actors` 폴더와 카메라 지점(높이 40). POTG 재생 때 참가자 복제 인형을 여기 세움 |

모든 맵 파트는 고정(Anchored)이고 `MapGeometry` 충돌 그룹입니다.

## 장비 프리팹

`ReplicatedStorage.Procedural_3D_Weapon_And_Armor_Prefabs`에 34종 장비가 모두 3D 모델로 만들어집니다.

| 폴더 | 모델 | 붙는 부위 | 주요 Attachment |
|---|---|---|---|
| `Ranged_Weapon_Models` | 활·총·투척 12종 | 오른손 (`Handle`) | `MuzzleAttachment`(발사 위치), `StringAttachment`, 활은 `StringTop/Bottom`(시위 Beam), 슬링 끈, 작살·볼라 밧줄 |
| `Melee_Weapon_Models` | 근접 5종 + `Ranked_Melees` 폴더(랭크 4종) | 오른손 | `TopAttachment`/`BottomAttachment`(휘두르기 Trail), `DmgPoint` 5~8개(타격 판정 지점) |
| 〃 | `Shield_Model` | 왼쪽 아래팔 | `ArrowStickPoint`(막은 화살이 꽂히는 곳) |
| `Utility_And_Healing_Models` | 전술 5종 + 회복 4종 | 오른손 | 연막탄 심지 불꽃, 화염구 불꽃, 황금 사과 반짝임, 뿔피리 끈 |
| `Wearable_Armor_Models` | 가죽·철·다이아몬드 갑옷 | 몸통과 양 위팔 | 없음 |

강철 건틀릿과 쌍손도끼는 왼손용 `Offhand` 모델(`OffhandHandle`)이 따로 있고, 거기에도 `DmgPoint`가 5~8개 있습니다. 갑옷은 몸통·양팔 조각을 `UpperTorso`, `LeftUpperArm`, `RightUpperArm`에 맞춘 뒤 WeldConstraint로 붙입니다. 모델별 파트 수는 [reference/world.md](reference/world.md#장비-프리팹-replicatedstorageprocedural_3d_weapon_and_armor_prefabs)에 있습니다.

## VFX 템플릿

`ReplicatedStorage.VFX_And_Particle_Templates` 아래 다섯 폴더입니다. 클라이언트가 복제해서 씁니다.

| 폴더 | 내용 |
|---|---|
| `ProjectileTrails` | 화살 바람 꼬리, 총알 예광, 차크람 궤적, 불화살·화염구용 불꽃 파티클 |
| `ImpactEffects` | 일반 타격 불꽃, 헤드샷 불꽃, 방어구 타격 파편, 방어구 파괴, 막기 불꽃, 흙먼지, 화염 폭발, 물 튀김 (8종, 파티클 13개) |
| `StatusAndAreaEffects` | 연막 구름, 회복 고리·화상·속박(밧줄 조각) 파티클, 뿔피리 파동과 적 위치 표시(Highlight), 경직 별, 불길 장판 |
| `KillConfirmationVFX` | 처치 순간 파티클, 해골 빌보드 |
| `ProjectileBodies` | 날아가는 투사체 모델 12종: 화살, 석궁 볼트, 총알, 돌, 단검, 투창, 작살촉, 차크람, 볼라, 연막탄, 화염구, 플라스크 |

## 사운드

효과음 34개가 `Modules/Config/SoundCatalog.luau`에 큐 이름으로 정의돼 있습니다(활 당김, 사격, 타격, 헤드샷, 처치, 방어구 파괴, 링 틱, 상자 열기, 카드 뒤집기, UI 클릭 등). 지금은 저작권 문제가 없는 Roblox 기본 내장 소리(`rbxasset://sounds/...`)에 볼륨·피치를 바꿔 쓰고 있습니다. 실제 출시 전에 직접 만든 소리로 바꾸려면 이 파일의 경로만 바꾸면 됩니다. 전체 목록은 [reference/config.md](reference/config.md#사운드-큐-soundcatalog)에 있습니다.
