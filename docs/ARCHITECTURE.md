# 아키텍처

> 예시 구조다. 프로젝트에 맞게 고치고, `tdd-guard.mjs`의 RULES와 `/review`의 grep 경로도 함께 맞춘다.

## 디렉토리 구조
```
├─ src/
│  ├─ core/        # 순수 로직 (UI·DOM·네트워크 의존 금지, TDD 대상)
│  ├─ server/      # API 서버 (시크릿은 config.ts에서만, TDD 대상)
│  └─ client/      # UI·렌더링·입력 (E2E로 검증)
├─ data/           # 수치·설정 JSON (스키마 검증 로더로 읽음)
├─ tests/
│  ├─ unit/        # src/ 경로 미러 (src/core/a/b.ts → tests/unit/core/a/b.test.ts)
│  └─ e2e/         # Playwright
├─ docs/           # 문서 (execute.py가 매 step에 주입, specs/ 제외)
├─ phases/         # /harness가 만드는 phase·step 지시서
└─ scripts/        # execute.py, hooks/
```

## 레이어 의존 규칙
```
client ──HTTP──▶ server
  │                │
  └──────▶ core ◀──┘        core는 아무것도 import하지 않는다
```
- {규칙 1 — 예: client는 server 코드를 import하지 않고 HTTP로만 호출한다}
- {규칙 2 — 예: core는 난수·시간을 주입받는다}

## 데이터 흐름
```
{예: 사용자 입력 → client → core 상태 갱신 → client 렌더링
                         ↘ server API → 외부 API → 스키마 검증 → core 입력}
```

## 상태 관리
{상태 관리 방식}

## 검증 장치
| 장치 | 위치 | 막는 것 |
|---|---|---|
| `npm run check` | package.json | 타입·린트·단위 테스트 실패 |
| tdd-guard 훅 | `scripts/hooks/tdd-guard.mjs` | 테스트 없는 core/server 구현 |
| dangerous-cmd-guard 훅 | `scripts/hooks/dangerous-cmd-guard.sh` | 되돌리기 어려운 명령 |
| CI | `.github/workflows/ci.yml` | 위 전부 실패 시 머지 불가 |
