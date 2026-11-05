# AGENTS.md — 에이전트 공통 규칙

> 이 저장소에서 일하는 모든 AI 에이전트(Claude Code, Codex 등)와 사람이 따르는 규칙.
> 제품 전체 설계는 [docs/PRD.md](docs/PRD.md)가 단일 원천(Single Source of Truth)이다.
> `{ }` 안은 프로젝트에 맞게 바꾼다.

## 프로젝트

**{프로젝트명}** — {한 줄 설명}

- **목표**: {이 프로젝트로 이루려는 것}
- **범위**: {MVP 범위. 범위 밖 기능은 PRD "출품/출시 이후"에 적고 만들지 않는다}
- **마감**: {YYYY-MM-DD}

---

## 문서 맵 (작업 전 여기서 시작하라)

| 문서 | 내용 |
|------|------|
| [docs/PRD.md](docs/PRD.md) | 제품 요약, 화면·기능 목록, 마일스톤별 범위 |
| [docs/progress.md](docs/progress.md) | 마일스톤 체크리스트 진행 현황, 결정 대기(블로커) |
| [docs/milestone-checklist.md](docs/milestone-checklist.md) | 마일스톤 완료 시 사람이 직접 하는 테스트 |
| [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) | 디렉토리 구조, 레이어 의존 규칙, 데이터 흐름 |
| [docs/specs/](docs/specs/) | 시스템·화면별 상세 스펙 (1 시스템 = 1 파일) |
| [docs/ADR.md](docs/ADR.md) | 기술 결정 기록 |
| [docs/UI_GUIDE.md](docs/UI_GUIDE.md) | 디자인 규칙 |
| [docs/tech-debt-tracker.md](docs/tech-debt-tracker.md) | 알려진 기술 부채 |
| [docs/USAGE.md](docs/USAGE.md) | 하네스 사용법 (phase 설계 → 실행 → 리뷰) |

---

## 기술 스택

| 영역 | 선택 |
|---|---|
| 언어 | {예: TypeScript (strict)} |
| 프레임워크 | {예: Vite / Next.js} |
| 테스트 | {예: Vitest (단위), Playwright (E2E)} |
| 패키지 매니저 | {예: npm} |
| 배포 | {예: EC2 + nginx} |

---

## CRITICAL 규칙

> 예시다. 프로젝트에 맞게 고치고, 가능한 규칙은 린트·훅으로 강제한다.

1. **스펙 우선** — 착수 전 `docs/specs/`의 해당 스펙을 확인한다. 없으면 [docs/specs/_TEMPLATE.md](docs/specs/_TEMPLATE.md)로 스펙을 먼저 쓰고 코드는 그다음에 쓴다.
2. **레이어 순수성** — {예: `src/core/`는 UI·DOM·네트워크를 import하지 않는다. 난수·시간은 주입받는다.}
3. **수치 하드코딩 금지** — {예: 가격·확률·시간 같은 값은 `data/*.json`에 두고 스키마 검증 로더로 읽는다.}
4. **UI 문자열 하드코딩 금지** — {예: 사용자에게 보이는 문구는 `i18n/{locale}.json`에서 읽는다.}
5. **TDD** — {`src/core/`, `src/server/`}는 테스트를 먼저 작성한다. 테스트는 `tests/unit/`에 소스 경로를 미러링한다. (`tdd-guard` 훅으로 강제)
6. **타입 안전성** — `any` 금지. 외부 JSON(설정, API 응답, 저장 데이터)은 스키마로 검증한다.
7. **시크릿** — API 키 등 서버 시크릿은 {`src/server/config.ts`}에서만 읽는다. 클라이언트에 노출되는 접두사(`PUBLIC_`, `VITE_`)를 붙이지 않는다. `.env`는 커밋하지 않는다.

> 레이어 의존 방향·디렉토리 상세 → [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)

---

## 작업 단위와 완료 조건

- **작업 단위**: [docs/progress.md](docs/progress.md) 체크리스트 항목 1개 = phase의 step 1개 = 커밋 1개. Phase 1개 = 브랜치 1개(`feat-{phase}`) = PR 1개.
- **완료 조건** — 아래가 모두 통과해야 완료다:
  ```bash
  npm run check      # 타입체크 + 린트 + 단위 테스트
  npm run build      # 프로덕션 빌드
  npm run test:e2e   # UI 변경 시
  ```
- **완료 후** [docs/progress.md](docs/progress.md)의 해당 항목을 체크하고, 새로 생긴 기술 부채는 [docs/tech-debt-tracker.md](docs/tech-debt-tracker.md)에 기록한다.
- 마일스톤이 끝나면 [docs/milestone-checklist.md](docs/milestone-checklist.md)를 모두 통과해야 다음 마일스톤으로 간다.

---

## 명령어

```bash
npm run dev        # 개발 서버
npm run build      # 프로덕션 빌드
npm run check      # typecheck + lint + test (Stop 훅에서 자동 실행)
npm run test       # 단위 테스트
npm run test:e2e   # E2E
```

> 위 스크립트는 첫 phase의 프로젝트 세팅 step에서 만든다.

---

## 개발 원칙

- 커밋 메시지: conventional commits (`feat:`, `fix:`, `docs:`, `refactor:`, `test:`, `chore:`)
- **범위보다 완성도** — MVP 밖 기능은 PRD에 적고 만들지 않는다.
