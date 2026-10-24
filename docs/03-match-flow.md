# 03. 매치 진행

관련 코드: `MatchmakingAndBotService.luau`, `RoundStateMachineService.luau`, `POTGRecorderAndScorer.luau`, `EconomyAndMonetizationService.luau`. 시간 값은 모두 `GameConfig`에 있습니다([reference/config.md](reference/config.md)).

## 1. 파티

`PartyAction` 원격으로 처리합니다. 파티는 최대 3명(`Matchmaking.PartyMaxSize`)입니다.

| 동작 | 설명 |
|---|---|
| `Invite` | 파티장만 가능. 같은 서버의 플레이어를 이름이나 표시 이름으로 초대하면 상대 화면에 수락 창이 뜹니다 |
| `Accept` / `Decline` | 초대 수락·거절 |
| `Leave` | 파티 나가기 |
| `Kick` | 파티장이 멤버를 내보내기 (로비 HUD에서 멤버를 클릭) |

파티는 큐에 통째로 들어가고, 한 팀으로 묶입니다.

## 2. 3v3 큐

`QueueAction("Join" / "Leave")`로 들어가고 나옵니다.

- 큐에 있는 파티를 Alpha/Bravo로 채워 사람 6명이 되면 바로 시작합니다.
- 6명이 안 되면, 가장 오래 기다린 파티가 15초(`BotFillAfterSeconds`)를 넘긴 순간 빈자리를 봇으로 채워 시작합니다.
- 파티 중 한 명이라도 설정에서 `PreventFullBotMatches`(봇 매치 막기)를 켰다면 그 파티는 봇 충원을 기다리지 않고 사람만 기다립니다.
- 큐 매치는 랭크 매치입니다. 이기고 지면 Glory가 바뀝니다.

### 아레나로 이동

- `ArenaPlaceId`가 설정되어 있고 Studio가 아니면: `TeleportService:ReserveServer(ArenaPlaceId)`로 전용 서버를 만들고 `TeleportAsync`로 6명을 보냅니다. TeleportData에는 `{Teams, Mode, Kind, Ranked}`가 들어갑니다.
- 그렇지 않으면: 같은 로비 서버 안에서 매치를 돌립니다(연습 모드).
- 아레나 서버는 들어올 사람 수(TeleportData의 Teams)가 다 모이거나 20초(`ArenaWaitForPlayersSeconds`)가 지나면 매치를 시작합니다. 혼자 들어왔고 랭크 큐가 아니면 연습 매치(`Practice`)로 시작합니다.
- 매치가 끝나면 로비로 돌려보냅니다. PLAY AGAIN을 누른 사람은 `AutoQueue = true`로 돌아가 다시 큐에 들어갑니다.

## 3. 커스텀 방

`CustomMatchAction`으로 처리합니다. 랭크가 아니라 Glory가 바뀌지 않습니다.

| 동작 | 설명 |
|---|---|
| `List` | 열린 방 목록 |
| `Create` | 모드(1v1 / 2v2 / 3v3), 봇 채우기 여부를 정해 방 만들기. 서버당 최대 12개(`CustomRoomMaxRooms`) |
| `Join` | 팀을 골라 들어가기 |
| `Leave` | 나가기 |
| `Start` | 방장이 시작. 봇 채우기를 끈 경우 양 팀에 최소 1명씩 있어야 합니다 |

## 4. 라운드 루프 (Best of 5, 3선승)

| 단계 | 시간 | 하는 일 |
|---|---|---|
| 1. PreMatchVS | 6초 | VS 화면. 캐릭터가 팀 스폰 패드에 생성. POTG 기록 시작 |
| 2. PreRoundLoadout | 5초 | 스폰 보호막 뒤에서 대기, 5..4..3..2..1..FIGHT! 카운트다운. **B로 프리셋 1~5 교체 가능**(`SwitchPresetInPreRound`) |
| 3. ActiveCombat | 60초 + 링 30초 | 0.1초마다 전멸 확인. 60초가 지나면 링 오브 파이어가 수축 |
| 4. RoundEndBanner | 4초 | ROUND WON / LOST / DRAW 배너와 태그 |
| 5. POTGReplay | 8초 | 한 팀이 3승하면: 매치 최고의 장면 재생 |
| 6. VictoryDropAndSummary | 최대 25초 | 승리 상자, XP·연승·MVP 정산, PLAY AGAIN / LOBBY |

2라운드부터는 매 라운드 시작 때 모든 캐릭터가 다시 스폰되고 체력·방어구·탄약이 처음 상태로 돌아갑니다. 투사체, 설치물, 래그돌은 정리됩니다.

### 링 오브 파이어

- 전투 60초가 지나면 반경 180 스터드에서 0까지 30초 동안 줄어듭니다.
- 원 밖에 있으면 0.5초마다 10 화염 대미지를 받습니다.
- 반경이 0이 되면 모두 원 밖이므로 결국 라운드가 끝납니다.

### 라운드 승패

- 한 팀이 전멸하면 남은 팀이 이깁니다.
- 동시에 전멸하면: 직전 틱에 살아 있던 인원이 더 많은 팀 → 그것도 같으면 이번 라운드 총 대미지가 많은 팀 → 그것도 같으면 **무승부(DRAW)**. 무승부는 점수 없이 다음 라운드로 넘어갑니다.
- 한 팀의 사람이 모두 나가면 그 팀이 기권패합니다.

### 배너 태그

| 태그 | 조건 (승리 팀 기준) |
|---|---|
| FLAWLESS | 이긴 팀에서 아무도 죽지 않음 |
| ACE | 한 명이 그 라운드에서 팀 인원 수 이상(최소 2) 처치 |
| TEAM ACE | 이긴 팀 전원(2명 이상)이 1킬 이상 |

## 5. POTG (최고의 플레이)

- 20Hz로 모든 캐릭터의 위치, 방향, 조준 각도, 상태(생존·막기·슬라이드·당김)와 사건(발사, 휘두르기, 적중, 처치, 장비 교체)을 기록합니다.
- 6초 구간마다 점수를 매깁니다.

| 항목 | 점수 |
|---|---|
| 처치 | +100 |
| 헤드샷 처치 (HEADSHOT) | +50 |
| 80 스터드 이상 처치 (LONG SHOT) | +90 |
| 라운드 마지막 처치 (WINNING BLOW) | +80 |
| 2킬 | 합계 ×1.5 |
| 3킬 이상 | 합계 ×2.5 |
| 한 사람이 구간 안에 그 라운드의 적 전원 처치 (TEAM WIPE) | +500 |

- 라운드마다 최고 구간을 잘라 두고, 매치가 끝나면 그중 가장 높은 것을 모든 클라이언트에 보냅니다(`BroadcastPOTGData`).
- 서버는 맵의 `POTG_CinematicStage` 위에 참가자 복제 인형(`Puppet_<id>`)을 만들고, 클라이언트가 기록을 60FPS로 보간해 재생합니다([08번 문서](08-ui-and-hud.md)).

## 6. 정산

### MVP

이긴 팀에서 `처치 × 100 + 도움 × 50 + 대미지`가 가장 높은 사람입니다.

### XP

| 항목 | XP |
|---|---|
| 승리 / 패배 | 120 / 60 |
| 처치 1회 | 15 |
| 도움 1회 | 6 |
| MVP | 40 |
| 연승 보너스 | (연승 수 − 1) × 10 |

계정 레벨 L에서 다음 레벨까지 필요한 XP는 `floor(250 × L^1.2)`입니다.

### 연승과 Glory

- 이기면 연승 +1, 최고 연승 갱신.
- 지면 연승이 0이 되고, 잃은 연승은 `LastLostStreak`에 남아 "연승 복구" 상품으로 되살릴 수 있습니다.
- 랭크 매치 승리: Glory +25 + (연승 − 1) × 3. 패배: Glory −15 (0 아래로는 내려가지 않음).
- 얻은 Glory는 트라이브의 주간 Glory에도 더해집니다.

### 승리 상자

승리 23~25 샤드, 패배 12~14 샤드를 카드 4장에 나눠 줍니다. 자세한 규칙은 [06번 문서](06-progression-economy.md)에 있습니다.

### 다음 매치

결과 화면에서 각자 PLAY AGAIN 또는 LOBBY를 고릅니다. 모두 고르거나 25초가 지나면 매치가 정리됩니다. PLAY AGAIN을 고른 사람은 다시 큐에 들어가고, 나머지는 로비로 돌아갑니다.
