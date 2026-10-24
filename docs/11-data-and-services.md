# 11. 데이터 저장과 네트워크

관련 코드: `PlayerDataService.luau`, `TribeService.luau`, `LeaderboardService.luau`, `EconomyAndMonetizationService.luau`, `Modules/Shared/Net.luau`, `Modules/Shared/Types.luau`, 클라이언트 `ClientState.luau`. 타입 정의 전체는 [reference/types.md](reference/types.md), 원격 채널 전체와 사용 위치는 [reference/remotes.md](reference/remotes.md)에 있습니다.

## DataStore 목록

| 이름 | 종류 | 키 | 내용 |
|---|---|---|---|
| `Tribes3v3_Profiles_v1` | DataStore | `u_<UserId>` | `{ Profile, Lock = { JobId, Time } }` |
| `Tribes3v3_Tribes_v1` | DataStore | `tribe_<id>`, `tag_<TAG>` | 트라이브 기록, 태그 → id |
| `Tribes3v3_TribeGlory_W<주차>` | OrderedDataStore | 트라이브 id | 이번 주 트라이브 Glory |
| `LB_Eliminations_v1` | OrderedDataStore | `u_<UserId>` | 누적 처치 |
| `LB_LongestStreak_v1` | OrderedDataStore | `u_<UserId>` | 최고 연승 |

주차는 `floor(os.time() / 604800)`입니다. 유닉스 시간 0이 목요일이라 매주 **목요일 00:00 UTC**(한국 시간 목요일 오전 9시)에 바뀌고, 새 주에는 새 OrderedDataStore를 쓰므로 주간 순위가 자동으로 초기화됩니다.

## 플레이어 프로필

### 필드

| 필드 | 기본값 | 설명 |
|---|---|---|
| `Version` | 1 | 스키마 버전 |
| `Level`, `XP` | 1, 0 | 계정 레벨과 현재 XP |
| `WinStreak`, `BestStreak`, `LastLostStreak` | 0 | 현재 연승, 최고 연승, 마지막으로 잃은 연승 |
| `GloryRP` | 0 | 랭크 점수 |
| `TribeId` | 없음 | 소속 트라이브 |
| `Kills`, `Deaths`, `Wins`, `Losses`, `MatchesPlayed` | 0 | 누적 기록 |
| `Shards` | `{}` | 아이템별 샤드 `{ [ItemId] = 개수 }` |
| `UnlockedItems` | 기본 지급 24종 = 1 | 해금된 아이템과 레벨 `{ [ItemId] = 1..10 }` |
| `Presets` | 기본 프리셋 5종 | 로드아웃 5개 |
| `ActivePreset` | 1 | 장착 중인 프리셋 번호 |
| `GoldenDropPurchased` | false | 골든 드롭을 산 적이 있는지 |
| `Settings` | 아래 표 | 설정 |
| `ProcessedReceipts` | `{}` | 처리한 결제 영수증 id (최근 100개) |

| 설정 | 기본값 | 범위 |
|---|---|---|
| `CameraSensitivity` | 1 | 0.1 ~ 3 |
| `FieldOfView` | 70 | 70 ~ 120 (정수) |
| `ViewBobbing` | true | |
| `PreventFullBotMatches` | false | |
| `FirstPersonDefault` | false | |

### 읽어 올 때 정리 (`Reconcile`)

저장된 값을 그대로 믿지 않고 기본 프로필 위에 하나씩 옮겨 담습니다.

- 숫자가 아니거나 NaN이면 기본값. 음수는 0, 레벨은 1 이상, 아이템 레벨은 1~10으로 자릅니다.
- `BestStreak`는 현재 연승보다 작을 수 없습니다.
- 데이터베이스에 없는 아이템 id의 샤드·해금 기록은 버립니다.
- 설정은 범위를 벗어나면 잘라냅니다.
- 저장된 프리셋은 `LoadoutBudgetValidator`로 다시 검사해, 통과한 것만 쓰고 나머지는 기본 프리셋으로 둡니다.

### 세션 락

같은 계정이 두 서버(로비와 아레나)에서 동시에 프로필을 덮어쓰지 않도록 기록에 `Lock = { JobId, Time }`를 넣습니다.

1. **불러오기**: `UpdateAsync`로 락을 확인합니다. 다른 살아 있는 서버가 90초 안에 갱신한 락이 있으면 쓰지 않고 1.5초 뒤 다시 시도합니다. 최대 12번(약 18초)이고, 마지막 시도에서는 락을 강제로 가져옵니다. 그래도 실패하면 "Could not load your profile ... Please rejoin."으로 내보냅니다.
2. **자동 저장**: 60초마다 락을 갱신하며 저장합니다.
3. **저장 거부**: 저장하려는데 락이 다른 서버 것이면 덮어쓰지 않습니다.
4. **나갈 때**: `PlayerRemoving`에서 저장하면서 락을 풉니다. 로비에서 아레나로 텔레포트하면 로비가 락을 풀고, 아레나가 이어받습니다.
5. **서버 종료**: `BindToClose`에서 남은 모든 세션을 동시에 저장하고 최대 25초 기다립니다.

Studio에서 "Enable Studio Access to API Services"가 꺼져 있으면 DataStore 접근을 한 번 시험해 보고, 실패하면 **메모리 프로필**로 돌립니다(저장되지 않음). 트라이브와 전광판도 같은 방식으로 메모리나 서버 안 플레이어 기록을 씁니다.

### 프로필을 바꾸는 원격

| 원격 | 검사 |
|---|---|
| `SaveLoadout(번호, 로드아웃, 장착 여부)` | 번호 1~5, `Sanitize`로 모양 정리, `Validate`로 예산·슬롯·해금·탄약 검사. 실패하면 첫 오류를 알림으로 보내고 `SaveLoadout(false, 오류들)` 응답 |
| `UpdateSettings(설정)` | 숫자는 유한한지(`Net.IsFiniteNumber`) 확인하고 범위로 자름, 불리언만 받음. `ActivePreset`도 1~5로 바꿀 수 있음 |
| `UpgradeEquipment(아이템)` | 잠긴 무기면 샤드가 `UnlockShards` 이상인지 확인해 해금(랭크 전용은 거부), 해금된 아이템이면 Lv10 미만이고 다음 레벨 샤드가 충분한지 확인해 강화. 결과는 알림으로 보냄 |
| `OpenVictoryChest` | 서버에 보관된 이번 상자(카드와 총량)를 돌려줌. 샤드는 매치 정산 때 이미 지급돼 있어 여러 번 불러도 같은 결과 |
| `PurchaseRequest(상품, 아이템)` | 연승 복구는 잃은 연승이 있어야 하고 그 크기로 가격대를 고름. 즉시 해금은 아직 잠긴 무기여야 함. 상품 id가 설정됐으면 결제 창을 띄우고, 실제 지급은 `ProcessReceipt`에서만. 설정 안 됐으면 Studio에서는 바로 지급, 실제 서버에서는 "not available yet" |

프로필이 바뀌면 `MarkChanged`가 클라이언트에 `ProfileSync`로 새 프로필을 보냅니다.

## 결제 영수증 (`ProcessReceipt`)

1. 영수증의 `PurchaseId`가 `ProcessedReceipts`에 있으면 바로 `PurchaseGranted` (중복 지급 방지).
2. 프로필이 아직 안 불러와졌으면 `NotProcessedYet` (Roblox가 나중에 다시 보냄).
3. 상품을 지급하고 `PurchaseId`를 기록(최근 100개만 유지)한 뒤 **프로필 저장이 성공해야** `PurchaseGranted`. 저장이 실패하면 `NotProcessedYet`으로 다시 받게 합니다.

상품별 효과는 [06번 문서](06-progression-economy.md#유료-상품-developer-products)에 있습니다.

## 트라이브 기록

```
TribeRecord = {
  Id, Name, Tag,
  Leader: UserId,
  Members: { [UserId 문자열] = 표시 이름 },
  WeeklyGlory, Week, TotalGlory,
  Created: os.time()
}
```

- 태그는 `tag_<TAG>` 키로 따로 저장해 중복을 막습니다.
- 주간 Glory를 더할 때 기록의 `Week`가 이번 주가 아니면 0으로 초기화하고 더합니다. `TotalGlory`는 계속 쌓입니다.
- TOP TRIBES 목록은 이번 주 OrderedDataStore에서 내림차순으로 읽습니다(최대 100). 트라이브 창의 목록(`Browse`)은 상위 20개입니다.

## 네트워크 채널

모든 원격은 `Net.InitServer()`가 `ReplicatedStorage.RemoteNetwork_Events` 아래 `ReliableRemotes`(RemoteEvent)와 `UnreliableRemotes`(UnreliableRemoteEvent) 폴더에 만듭니다. 이름은 `Net.luau`의 목록에만 있고, 코드에서는 `Net.Reliable("이름")`, `Net.Unreliable("이름")`로 꺼내 씁니다(한 번 찾으면 캐시). 목록에 없는 이름을 부르면 `WaitForChild`가 끝없이 기다리므로, `tests/place.luau`가 코드에서 부르는 모든 이름이 목록에 있는지 검사합니다.

| 분류 | 채널 |
|---|---|
| 전투 입력 (클라이언트 → 서버) | `FireProjectile`, `MeleeSwing`, `UseUtility`, `StartHeal`, `CancelHeal`, `ToggleBlock`, `EquipSlot`, `CatchChakram`, `SlideRequest` |
| 전투 결과 (서버 → 클라이언트) | `ProjectileReplicate`, `ProjectileResolved`, `CombatEvent`, `UtilityEvent`, `ApplyImpulse`, `InventorySync` |
| 라운드 | `RoundStateChanged`, `SwitchPresetInPreRound`, `RequestSpawnLoadout`(같은 처리기를 쓰는 별칭), `BroadcastPOTGData`, `MatchSummary`, `OpenVictoryChest` |
| 로비·소셜 | `PartyAction`, `QueueAction`, `CustomMatchAction`, `TribeAction`, `OpenInterface` |
| 프로필·경제 | `ProfileSync`, `SaveLoadout`, `UpdateSettings`, `UpgradeEquipment`, `PurchaseRequest`, `Notify` |
| 빠른 상태 (Unreliable) | `ReplicateCharacterState`(조준 각도 등), `ReplicateBowDrawRatio`(활 당김 비율) |

Reliable 32개, Unreliable 2개입니다. 서버는 모든 인자를 `Net.IsFiniteNumber`, `Net.IsVector3`, `Net.IsString`(기본 64자 제한)으로 검사합니다.

## 클라이언트 상태 (`ClientState`)

클라이언트의 단일 상태 저장소입니다. 컨트롤러끼리는 서로 부르지 않고 여기 값과 신호로 주고받습니다.

| 값 | 내용 |
|---|---|
| `Profile`, `Inventory`, `Round`, `Party` | 서버가 보낸 최신 프로필, 무장 정보(슬롯·탄약·장착 칸), 라운드 상태, 파티 |
| `Aiming`, `Drawing`, `DrawRatio`, `Sliding`, `Sprinting` | 지금 조준·당기기·슬라이드·달리기 중인지 |
| `SpectateTarget`, `Cinematic` | 관전 대상, 연출(POTG·상자)이 카메라를 쓰는 중인지 |
| `ViewMode`, `Shoulder` | `Third` / `First`, 어깨 방향(1 오른쪽, −1 왼쪽) |
| `OpenMenus` | 열린 로비 창 |

| 신호 | 언제 |
|---|---|
| `ProfileChanged` | `ProfileSync` 수신 |
| `InventoryChanged` | `InventorySync` 수신, 무장·해제 |
| `RoundChanged` | `RoundStateChanged` 수신 |
| `PartyChanged` | 파티 정보 수신 |
| `MenuChanged`, `ViewChanged` | 로비 창 열림·닫힘, 시점 변경 |
| `CombatEvent` | 처치·피격 등 전투 사건 수신 |
| `LocalSwing` | 내 휘두르기 (뷰모델 동작) |
| `Notify` | 서버 `Notify` 또는 클라이언트 알림 |
| `Recoil` | 발사 반동 |
