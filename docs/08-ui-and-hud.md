# 08. 화면 (UI와 HUD)

관련 코드: `BuilderModules/Step4/*`(화면 생성), 클라이언트 `LobbyUIController.luau`, `CombatFeedbackAndHUDController.luau`, `POTGAndVictorySequenceController.luau`, `UIUtil.luau`. 요소 이름과 기본 문구는 [reference/ui.md](reference/ui.md)에 하나도 빠짐없이 있습니다.

## 화면 11개

| ScreenGui | 언제 보이나 | 담당 컨트롤러 |
|---|---|---|
| `LobbyHUD` | 로비에 있을 때 | LobbyUIController |
| `LoadoutBuilder` | B 또는 로드아웃 노점 | LobbyUIController |
| `CustomMatches` | 오두막 프롬프트 또는 CUSTOM MATCH 버튼 | LobbyUIController |
| `TribeHall` | 트라이브 홀 프롬프트 또는 TRIBE HALL 버튼 | LobbyUIController |
| `Settings` | SETTINGS 버튼 | LobbyUIController |
| `VSScreen` | 매치 시작 6초 | CombatFeedbackAndHUDController |
| `CombatHUD` | 무장한 동안 (매치, 결투, 사격장) | CombatFeedbackAndHUDController |
| `DeathAndSpectate` | 죽은 뒤 | CombatFeedbackAndHUDController |
| `POTGViewfinder` | 매치 끝 POTG 재생 | POTGAndVictorySequenceController |
| `VictoryDropUI` | 승리 상자, 골든 드롭 | POTGAndVictorySequenceController |
| `ScoreboardSummaryUI` | 결과표 | POTGAndVictorySequenceController |

화면은 Studio 빌더가 StarterGui에 미리 만들고, 빠진 것은 서버와 클라이언트가 실행 중에 다시 만듭니다(`Step4.EnsureAll`). 모든 창은 어두운 반투명 배경, 둥근 모서리(UICorner), 그라데이션, 테두리(UIStroke), 글자 크기 제한(UITextSizeConstraint)을 공통으로 씁니다. 컨트롤러는 요소를 **이름 경로**로 찾기 때문에 이름을 바꾸면 컨트롤러도 같이 바꿔야 합니다.

## 로비

### LobbyHUD

| 요소 | 내용 |
|---|---|
| 프로필 카드 | 이름, `LV n`, XP 막대, `🔥 연승`, `Glory RP`, `[트라이브 태그]` |
| 재화 카드 | `💎 n SHARDS` (모든 아이템 샤드 합) |
| 옆 버튼 | [B] LOADOUT, CUSTOM MATCH, TRIBE HALL, SETTINGS, GOLDEN DROP 9R$, RESTORE 🔥n STREAK (잃은 연승이 있을 때만) |
| 플레이 패널 | PLAY 3v3 (파티면 `PLAY 3v3 (PARTY n)`), 큐에 있으면 SEARCHING... 와 CANCEL, 매치가 잡히면 MATCH FOUND!, 봇 충원 안내 |
| 파티 패널 | 멤버 목록(파티장은 LEADER), 이름 입력 + INVITE, LEAVE. 파티장은 멤버를 눌러 내보낼 수 있음 |
| 초대 창 | "X invited you to a party", ACCEPT / DECLINE |
| 토스트 | 화면 위 알림 (정보·성공·오류 색 구분) |
| 안내 문구 | 마을 구역에 들어가면 표시 ([07번 문서](07-world-and-maps.md#상호작용-프롬프트)) |

### LoadoutBuilder

- 위쪽 **프리셋 탭 5개**. 장착 중인 프리셋에는 `★`, 편집 중인 탭은 금색.
- **분류 탭**: WEAPONS / UTILITY / HEALING / ARMOR / AMMO.
- **아이템 격자**: 아이콘, 이름, `n PT`, `LVn`. 잠긴 아이템은 🔒, 랭크 전용은 🏆 덮개. 로드아웃에 들어간 카드는 금색 테두리, 고른 카드는 흰 테두리, 나머지는 희귀도 색 테두리.
- **상세 패널**: 이름, `LV n / 10` 또는 LOCKED, 설명, 능력치(DAMAGE, PELLETS, HEADSHOT, DRAW, RELOAD, SWING, RANGE, SPEED, ARMOR HP, HEAL, SHIELD HP, COOLDOWN, SLOW, COST). 수치는 현재 레벨의 배율을 반영합니다.
- **버튼**: ADD TO LOADOUT / REMOVE / EQUIP ARMOR, UPGRADE (필요 샤드) 또는 UNLOCK, 랭크 전용은 `REACH n RP`, 잠긴 무기는 `UNLOCK n R$` (로벅스 즉시 해금), 샤드 진행 `have / need SHARDS`.
- **로드아웃 패널**: `PRESET n · 이름`, 6칸(빈칸은 `— empty —`) + 방어구 칸(`No armor`) + 화살·총알·불화살 묶음 수, `n / 12 PT`와 예산 막대(넘으면 빨강), `n / 6 SLOTS`, 첫 번째 오류 문구.
- **저장**: SAVE & EQUIP, 이미 장착 중이면 SAVE (ACTIVE). 규칙에 어긋나면 버튼이 회색으로 꺼지고, 서버도 다시 검증합니다.

### CustomMatches

방 목록(방 이름, 모드, 봇 채우기면 🤖, `현재/최대` 인원), 새로 만들기(1v1 / 2v2 / 3v3, `BOT FILL: ON/OFF`), 내 방 정보(`방 이름 · 모드`, 없으면 Not in a room), 팀 고르기, 나가기, 방장 전용 START.

### TribeHall

만들기(이름 + 태그), 검색, 목록 보기(`[태그]`, 이름, `n/20` 멤버, `n RP` 주간 Glory), 가입, 탈퇴. 내 트라이브 칸에는 `[태그] 이름`(없으면 No tribe), `n RP / week`, 멤버 목록(리더는 `★`)이 나옵니다.

### Settings

| 항목 | 범위 / 기본 |
|---|---|
| CAMERA SENSITIVITY | 0.1 ~ 3, 기본 1 (슬라이더) |
| FIELD OF VIEW (70~120) | 70 ~ 120, 기본 70 (슬라이더) |
| VIEW BOBBING | 켬 / 끔, 기본 켬 |
| PREVENT FULL BOT MATCHES | 켬 / 끔, 기본 끔 ([03번 문서](03-match-flow.md#2-3v3-큐)) |
| START IN FIRST PERSON | 켬 / 끔, 기본 끔 |

바꾸는 즉시 카메라에 적용되고 `UpdateSettings`로 프로필에 저장됩니다.

## 매치

### VSScreen (6초)

맵 이름, `3v3 · BEST OF 5`, ALPHA / BRAVO 열에 최대 3장씩 카드. 카드에는 이름과 `YOU` / `PLAYER` / `AI FIGHTER`(봇이면 레벨 자리에 BOT)가 표시되고, 가운데 VS 글자가 튀어나오며 커집니다.

### CombatHUD

| 요소 | 내용 |
|---|---|
| 위쪽 바 | 팀 점수와 승리 칸 3개(채워지면 진하게), `ROUND n`, 남은 시간(10초 이하 빨강) |
| 생존 아이콘 | 팀별 이니셜 아이콘, 죽으면 ✕ |
| 링 경고 | 전투 끝 10초 전 `RING OF FIRE IN n`, 링이 켜지면 `🔥 RING OF FIRE CLOSING · n studs`, 원 밖이면 깜빡이는 `⚠ YOU ARE IN THE RING OF FIRE - MOVE IN!` |
| 체력·방어구 | 체력 막대와 숫자, 방어구 막대(없으면 NO ARMOR) |
| 상태 칩 | STAGGERED, ROOTED, SNARED, HEALING, BLOCKING, SHIELD n, HASTE |
| 핫바 6칸 | 키 번호, 아이콘, 이름, 남은 개수, 레벨, 쿨다운이 돌아가는 덮개 |
| 조작 안내 | 탄약(`ARROWS n · FIRE n` / `BULLETS n`), 아이템별 안내(`HotbarHint`), `[V] FIRST/THIRD PERSON  [X] SHOULDER  [C] SLIDE` |
| 조준선 | 이동 속도에 따라 벌어지고 조준 중엔 좁아짐. 근접 무기는 점만. 활을 당기면 고리가 줄고 끝까지 당기면 금색. 배율 조준(FOV 45 이하)은 검은 스코프 테두리 |
| 히트마커 | 0.18초. 흰색 일반, 노랑 헤드샷, 파랑 방어구, 회색 막힘, 빨강 처치 |
| 대미지 숫자 | 맞은 곳에서 포물선으로 떠오름(최대 24개): 흰 `40`, 노랑 `70 HEADSHOT!`, 파랑 방어구 대미지, 회색 `BLOCKED`, 파랑 `ARMOR BROKEN`, 흰 `STAGGERED`, 주황 `SHIELD BROKEN` |
| 킬 피드 | 오른쪽 위 `A ⚔ B`, 최대 5줄, 6초 뒤 사라짐. 내가 관련된 줄은 금색 테두리 |
| 처치 배너 | 빨간 `☠ ELIMINATED 이름` 1.8초 |
| 라운드 배너 | ROUND WON(금) / ROUND LOST(빨강) / DRAW + FLAWLESS · ACE · TEAM ACE |
| 카운트다운 | 준비 단계 5..4..3..2..1 → FIGHT! |
| 프리셋 교체 | 준비 단계에 B: `[B] SWITCH PRESET`, 1~5 버튼 |
| 회복 시전 막대 | `붕대...  [Q] cancel` |

내가 받은 피해와 상태 변화는 토스트로도 알립니다: STAGGERED, YOUR ARMOR BROKE, YOUR SHIELD SHATTERED, SNARED!, BACKSTABBED!, `WAR HORN! n enemies revealed`.

### DeathAndSpectate

죽으면 `ELIMINATED BY` 카드가 아래에서 올라옵니다: 처치한 사람(링이면 THE RING), 무기 아이콘과 이름, 처치한 사람의 남은 체력 `❤ n HP`. 2.5초 뒤 살아 있는 팀원 관전으로 넘어가고(`SPECTATING` + 이름), 좌클릭 / 우클릭으로 다음 / 이전 팀원을 봅니다.

## 매치 끝

### POTGViewfinder

1. 검은 화면에 `PLAY OF THE GAME`, 선수 이름, 태그(`HEADSHOT | LONG SHOT | ...`) 2초.
2. 캠코더 화면: 빨간 `● REC` 깜빡임, 타임코드, 진행 막대, 이름과 태그 자막. 맵의 POTG 무대 위 복제 인형들이 서버가 20Hz로 기록한 프레임을 60FPS로 보간(CFrame:Lerp)하며 움직이고, 장비 교체·발사·휘두르기·적중·처치 사건이 시간에 맞춰 재생됩니다. 카메라는 주인공 어깨 뒤에서 천천히 흔들리며 따라갑니다(FOV 62).
3. `SKIP >>`로 건너뛸 수 있습니다.

### VictoryDropUI

1. 제목 VICTORY(금) / DEFEAT(빨강) / GOLDEN DROP, "Tap the chest to open".
2. 상자를 누르면(6초가 지나면 자동) `x3` → `x2` → `x1` 세 번 점점 세게 흔들리고, 뚜껑이 110도 열리며 REWARDS 또는 GOLDEN DROP!.
3. 카드 4장이 0.25초 간격으로 뒤집힙니다: 아이템 이름(새로 해금이면 `NEW!`), `+n` 샤드, 진행 `have / need`(Lv10이면 MAX LEVEL), UPGRADE READY.
4. 아래에 `TOTAL +n SHARDS`가 올라가며 세어지고, 강화 가능한 카드가 있으면 `· UPGRADE READY`. CONTINUE 버튼.

### ScoreboardSummaryUI

- VICTORY / DEFEAT, 최종 점수 `3 - 1`.
- 팀별 3줄: 이름(봇은 `[BOT]`, 나는 `▶`와 금색 테두리), K / D / A / DMG / Glory(내 줄만 `+25`처럼 표시). 처치 → 대미지 순 정렬.
- MVP 카드: 이름, `K / D / A · DMG`, 팀(나면 `THAT'S YOU!`).
- XP 내역이 한 줄씩(0.25초 간격) 나타나고 XP 막대가 차오릅니다. 레벨이 오르면 `LEVEL UP!  LV n`.
- `PLAY AGAIN (n초)` / LOBBY. PLAY AGAIN을 누르면 `QUEUED ✓ (n초)`.
