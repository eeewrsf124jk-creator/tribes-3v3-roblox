# Tribes 3v3 문서

Tribes 3v3 Roblox 프로젝트의 전체 문서입니다. 설명 문서는 사람이 쓴 것이고, `reference/` 아래 문서는 `tools/gendocs.luau`가 소스 코드와 실제 빌드 결과에서 자동으로 만든 것입니다. 숫자나 이름이 궁금하면 레퍼런스 문서가 정답입니다.

## 설명 문서

| # | 문서 | 내용 |
|---|---|---|
| 01 | [게임 개요](01-overview.md) | 어떤 게임인지, 실제 게임과의 관계, 프로젝트 규모 |
| 02 | [구조](02-architecture.md) | 두 플레이스, 단일 진입점, 부팅 순서, 폴더 구조, 충돌 그룹 |
| 03 | [매치 진행](03-match-flow.md) | 파티, 큐, 봇 충원, 커스텀 방, 6단계 라운드 루프, 링, 정산 |
| 04 | [전투](04-combat.md) | 대미지 파이프라인, 방어구, 막기·방패, 백스탭, 투사체와 랙 보정, 상태 이상, 이동 |
| 05 | [장비와 로드아웃](05-equipment.md) | 12포인트 규칙, 탄약, 기본·잠김·랭크 아이템, 기본 프리셋 |
| 06 | [성장과 경제](06-progression-economy.md) | 샤드, 해금, 강화, 승리 상자, 골든 드롭, XP, 연승, Glory, 유료 상품 |
| 07 | [월드와 맵](07-world-and-maps.md) | 로비 마을, 아레나 맵 4종, 공통 장치, 프리팹, VFX, 사운드 |
| 08 | [UI와 HUD](08-ui-and-hud.md) | 화면 11개의 역할과 흐름 |
| 09 | [조작과 카메라](09-controls-camera.md) | 키보드·게임패드·모바일, 카메라, 뷰모델, 설정 |
| 10 | [봇 AI](10-bots.md) | TacticalBotAgent 상태 머신 |
| 11 | [데이터와 서버 서비스](11-data-and-services.md) | 프로필 스키마, 세션 락, 트라이브, 리더보드, 원격 호출 검증 |
| 12 | [빌드·테스트·배포](12-build-test-deploy.md) | Rojo, 빌더 파이프라인, 게시, 상품 설정, 테스트, 문서 재생성, 문제 해결 |
| 13 | [명세 대조표](13-spec-traceability.md) | 원본 명세의 모든 항목과 구현 위치, 바뀐 값 |
| 14 | [변경 기록](14-changelog.md) | 커밋 단위 작업 기록 |

## 레퍼런스 (자동 생성)

| 문서 | 내용 |
|---|---|
| [reference/equipment.md](reference/equipment.md) | 장비 34종의 모든 필드, 카테고리별 요약, 탄약 규칙, 기본 프리셋 |
| [reference/config.md](reference/config.md) | GameConfig 전체, 유료 상품, 레벨별 샤드·배율·XP, 사운드 큐 |
| [reference/remotes.md](reference/remotes.md) | 원격 채널 34개와 보내고 받는 위치 |
| [reference/modules.md](reference/modules.md) | 스크립트 62개 전체: 위치, 종류, 줄 수, 설명, 의존성, 공개 함수 |
| [reference/types.md](reference/types.md) | 서버·클라이언트 공유 타입 원문 |
| [reference/world.md](reference/world.md) | 충돌 매트릭스, 로비와 맵 4종의 구성, 프리팹, VFX 템플릿 |
| [reference/ui.md](reference/ui.md) | ScreenGui 11개의 모든 요소 트리 |

## 그 밖의 문서

- [원본 명세](spec/original-spec.md): 이 프로젝트를 시작한 요청 원문
- [조사 보고서](../replica/thinktank/report.md): 실제 게임 수치 조사와 출처
- [결정 기록](../replica/decisions.md)
- [저장소 README](../README.md): 빠른 시작

## 레퍼런스 다시 만들기

코드를 고친 뒤에는 레퍼런스를 다시 생성해 함께 커밋하세요.

```bash
rojo build -o build/Lobby.rbxl
rojo build arena.project.json -o build/Arena.rbxl
lune run tools/gendocs.luau
```
