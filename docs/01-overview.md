# 01. 게임 개요

## 한 줄 소개

3명씩 두 팀이 활, 총, 투척 무기, 근접 무기, 전술 도구를 12포인트 안에서 골라 들고 싸우는 라운드제 아레나 게임입니다. 먼저 3라운드를 이긴 팀이 매치를 가져갑니다.

## 기준이 된 실제 게임

Roblox의 "Tribes 3v3"(개발: Snick Co.)를 기준으로 했습니다. PC 게임 "TRIBES 3: Rivals"(Prophecy Games)와는 다른 게임입니다. 따라 만든 것은 규칙과 흐름뿐이고, 원본의 코드, 로고, 문구, 3D 에셋은 쓰지 않았습니다. 모든 모델과 화면은 코드로 새로 만들었습니다.

실제 게임과 같은 부분은 다음과 같습니다. 근거와 출처는 [조사 보고서](../replica/thinktank/report.md)에 있습니다.

- 3v3, 3라운드 선승
- 12포인트 로드아웃, 저장 프리셋 5개
- 방어구: 가죽 2 / 철 4 / 다이아몬드 6포인트
- 화살 1포인트에 12발(최대 36발), 불화살 2포인트에 6발
- 무기별 샤드로 해금과 강화, 매치 후 승리 상자
- 골든 드롭 9 로벅스
- 조작: B 로드아웃, C 슬라이드, V 1인칭, X 어깨 전환

## 핵심 기능

| 영역 | 내용 | 문서 |
|---|---|---|
| 매치 | 파티(최대 3명), 3v3 큐, 15초 뒤 봇 충원, 1v1/2v2/3v3 커스텀 방, 6단계 라운드 루프, 링 오브 파이어 | [03](03-match-flow.md) |
| 전투 | 서버 권위 판정, 1초 되감기 랙 보정, 방어구 감쇄, 막기와 방패, 백스탭 즉사, 해머 넉백, 상태 이상 | [04](04-combat.md) |
| 장비 | 34종: 원거리 12, 근접 10(랭크 전용 4 포함), 전술 도구 5, 회복 4, 방어구 3 | [05](05-equipment.md) |
| 성장 | 샤드 해금·강화(Lv1~10), 승리 상자 4장, 계정 레벨, 연승, Glory 랭크 점수, 트라이브 | [06](06-progression-economy.md) |
| 월드 | 50인 로비 마을, 대칭형 아레나 맵 4종, 장비 프리팹, 이펙트 | [07](07-world-and-maps.md) |
| 화면 | 로비 HUD, 로드아웃 빌더, 커스텀 방, 트라이브 회관, 설정, VS, 전투 HUD, 사망·관전, POTG, 승리 상자, 결과표 | [08](08-ui-and-hud.md) |
| 조작 | PC, 게임패드, 모바일 터치 | [09](09-controls-camera.md) |
| 봇 | 엄폐, 피킹, 거리별 무기 교체, 회복, 링 회피 | [10](10-bots.md) |

## 프로젝트 규모

| 항목 | 값 |
|---|---|
| 언어 | Luau (모든 파일 `--!strict`) |
| 스크립트 | 62개, 약 2만 2천8백 줄 ([목록](reference/modules.md)) |
| 실행 스크립트 | 2개뿐: `ServerMain`(서버), `ClientMain`(클라이언트). 나머지는 모두 ModuleScript |
| 원격 채널 | 34개 (Reliable 32, Unreliable 2) ([목록](reference/remotes.md)) |
| 화면 | ScreenGui 11개, 요소 약 1,570개 ([트리](reference/ui.md)) |
| 3D | 로비 파트 약 1,700개, 아레나 맵 4종 합계 약 3,800개, 장비 프리팹 34개 ([목록](reference/world.md)) |
| 도구 | Rojo 7.4.4, Lune 0.10.4 |
| 테스트 | 로직 40개, 빌더 실행 14개, 플레이스 구조 검사 ([12번 문서](12-build-test-deploy.md)) |

## 저장소 구조

```text
tribes-3v3-roblox/
├── default.project.json        로비 플레이스 (Rojo)
├── arena.project.json          아레나 플레이스 (Rojo)
├── aftman.toml                 도구 버전 (rojo, lune)
├── src/
│   ├── ReplicatedStorage/
│   │   ├── Modules/Config/     장비, 게임 설정, 상품, 사운드, 업그레이드 수식
│   │   ├── Modules/Shared/     타입, 네트워크, 탄도, 스프링, 충돌 그룹, 검증기 등
│   │   └── BuilderModules/     월드·프리팹·화면을 코드로 조립하는 빌더 (Step 1~4)
│   ├── ServerScriptService/    ServerMain + 서버 서비스 (전투, 라운드, 매치메이킹, 경제 ...)
│   └── StarterPlayerScripts/   ClientMain + 클라이언트 컨트롤러
├── tests/                      Lune 테스트 (로직, 빌더 실행, 플레이스 구조)
├── tools/gendocs.luau          레퍼런스 문서 생성기
├── docs/                       이 문서들
└── replica/                    실제 게임 조사 보고서와 결정 기록
```
