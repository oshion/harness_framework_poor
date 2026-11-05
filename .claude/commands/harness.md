이 프로젝트는 Harness 프레임워크를 사용한다. 아래 워크플로우에 따라 작업을 진행하라.

---

## 워크플로우

### A. 탐색

아래 문서를 읽고 기획·아키텍처·현재 진행 상태를 파악한다. 필요시 Explore 에이전트를 병렬로 사용한다.

- `/AGENTS.md` — 공통 규칙 (CRITICAL 규칙, 완료 조건)
- `/docs/PRD.md` — 제품 요약, 화면·기능 목록, 마일스톤별 범위 (단일 원천)
- `/docs/progress.md` — 마일스톤 체크리스트, 결정 대기(블로커), 마일스톤별 "착수 전 필요 스펙"
- `/docs/ARCHITECTURE.md` — 레이어 의존 규칙, 데이터 흐름
- `/docs/ADR.md` — 기술 결정
- `/docs/specs/` — 이번 Phase에 필요한 스펙
- 이미 존재하는 코드 (`src/`, `tests/` 등)

### B. 논의

다음이 있으면 step 설계 전에 사용자에게 제시하고 정리한다.

- 이번 Phase에 필요한데 **아직 없는 스펙** → 스펙 초안을 먼저 작성할지 확인한다 (AGENTS.md CRITICAL 1: 스펙 우선).
- progress.md "결정 대기" 중 이번 Phase를 막는 항목.
- 문서 수치가 "가안"이라 초기값을 정해야 하는 항목.

### C. Step 설계

사용자가 구현 계획 작성을 지시하면 여러 step으로 나뉜 초안을 작성해 피드백을 요청한다.

설계 원칙:

1. **체크리스트 단위** — progress.md 체크리스트 항목 1개 ≈ step 1개. 항목이 여러 레이어를 건드리면 레이어별로 쪼갠다 (예: `order-core` → `order-ui`).
2. **레이어 순서** — 같은 기능은 데이터·순수 로직(테스트 먼저) → 서버 → 클라이언트 → E2E 순으로 배치한다. 외부 API(AI 등)를 쓰는 기능은 대체 경로(목업·고정 응답)를 먼저 만들고 실제 호출을 나중에 붙인다.
3. **자기완결성** — 각 step 파일은 독립된 Claude 세션에서 실행된다. "이전 대화에서 논의한 바와 같이" 같은 외부 참조는 금지. 필요한 정보는 전부 파일 안에 적는다.
4. **사전 준비 강제** — 읽어야 할 문서·스펙 경로와 이전 step에서 생성/수정된 파일 경로를 명시한다. **`docs/specs/`는 자동 주입되지 않으므로** 필요한 스펙 파일을 반드시 나열한다.
5. **시그니처 수준 지시** — 함수/타입의 인터페이스만 제시하고 구현은 에이전트 재량. 단 설계 의도에서 벗어나면 안 되는 핵심 규칙(멱등성, 보안, 데이터 무결성, AGENTS.md CRITICAL 규칙)은 명시한다.
6. **AC는 실행 가능한 커맨드** — `npm run check`, `npm run build`, `npm run test:e2e -- tests/e2e/xxx.spec.ts` 등 실제 커맨드로 쓴다.
7. **UI step** — 새 문구는 i18n 파일에 함께 추가하게 하고, 대상 화면 크기의 E2E를 AC에 넣는다.
8. **주의사항은 구체적으로** — "조심해라" 대신 "X를 하지 마라. 이유: Y".
9. **네이밍** — phase 디렉토리는 `m{N}-{kebab}` (예: `m1-core-loop`), step name은 kebab-case slug (예: `order-core`, `checkout-ui`).
10. **사용자 개입 지점** — API 키, 외부 계정, 배포 설정, 수동 테스트가 필요한 step은 그 사실과 `blocked` 처리 기준을 적는다.

### D. 파일 생성

사용자가 승인하면 아래 파일들을 생성한다.

#### D-1. `phases/index.json` (전체 현황)

이미 존재하면 `phases` 배열에 새 항목을 추가한다.

```json
{
  "project": "<프로젝트명>",
  "phases": [
    { "dir": "m0-foundation", "status": "pending" }
  ]
}
```

- `status`: `"pending"` | `"completed"` | `"error"` | `"blocked"`. execute.py가 자동 갱신한다.
- 타임스탬프(`completed_at`, `failed_at`, `blocked_at`)는 execute.py가 기록한다. 생성 시 넣지 않는다.

#### D-2. `phases/{phase}/index.json` (phase 상세)

```json
{
  "project": "<프로젝트명>",
  "phase": "m1-core-loop",
  "steps": [
    { "step": 0, "name": "order-core", "status": "pending" },
    { "step": 1, "name": "order-ui", "status": "pending" }
  ]
}
```

- `phase`: 디렉토리명과 일치시킨다 (브랜치명 `feat-{phase}`가 된다).
- `steps[].status` 초기값은 모두 `"pending"`.

상태 전이와 자동 기록 필드:

| 전이 | 기록되는 필드 | 기록 주체 |
|------|-------------|----------|
| → `completed` | `completed_at`, `summary` | Claude 세션 (summary), execute.py (timestamp) |
| → `error` | `failed_at`, `error_message` | Claude 세션 (message), execute.py (timestamp) |
| → `blocked` | `blocked_at`, `blocked_reason` | Claude 세션 (reason), execute.py (timestamp) |

`summary`는 다음 step 프롬프트에 누적 전달된다. 생성된 파일, 공개 시그니처, 핵심 결정을 담는다.

#### D-3. `phases/{phase}/step{N}.md`

```markdown
# Step {N}: {name}

> progress.md 체크리스트: "{해당 항목 원문}"

## 읽어야 할 파일

먼저 아래 파일들을 읽고 설계 의도를 파악하라:

- `/AGENTS.md`
- `/docs/ARCHITECTURE.md`
- `/docs/specs/{system}.md`
- {이전 step에서 생성/수정된 파일 경로}

## 작업

{파일 경로, 타입/함수 시그니처, 로직 설명. 구현체는 에이전트에게 맡기고 핵심 규칙은 명확히.}

### 테스트 먼저 (TDD 대상 레이어인 경우)
- `tests/unit/{미러 경로}.test.ts` — {검증할 케이스}

## Acceptance Criteria

```bash
npm run check
npm run build
npm run test:e2e     # UI 변경 시
```

## 검증 절차

1. 위 AC 커맨드를 실행한다.
2. 체크리스트:
   - ARCHITECTURE.md 레이어 의존 규칙을 지켰는가?
   - AGENTS.md CRITICAL 규칙을 위반하지 않았는가?
3. `docs/progress.md`의 해당 체크리스트 항목을 체크하고 `(phase/stepN)`을 붙인다.
4. `phases/{phase}/index.json`의 해당 step을 업데이트한다:
   - 성공 → `"status": "completed"`, `"summary": "산출물 한 줄 요약"`
   - 3회 수정 후에도 실패 → `"status": "error"`, `"error_message": "구체적 에러"`
   - 사용자 개입 필요 → `"status": "blocked"`, `"blocked_reason": "구체적 사유"` 후 즉시 중단

## 금지사항

- {"X를 하지 마라. 이유: Y" 형식}
- 기존 테스트를 깨뜨리지 마라.
```

### E. 실행

```bash
py -3 scripts/execute.py {phase}           # Windows
python3 scripts/execute.py {phase}         # macOS / Linux
py -3 scripts/execute.py {phase} --push    # 완료 후 push
```

execute.py가 자동으로 처리하는 것:

- `feat-{phase}` 브랜치 생성/checkout
- 가드레일 주입 — AGENTS.md + CLAUDE.md + docs/**/*.md (docs/specs/ 제외)
- 컨텍스트 누적 — 완료된 step의 summary를 다음 step에 전달
- 자가 교정 — 최대 3회 재시도, 이전 에러 피드백
- 2단계 커밋 — 코드(`feat`)와 메타데이터(`chore`) 분리
- 사용량 한도 자동 대기 — 95% 이상이면 리셋까지 기다렸다가 이어서 진행
- 타임스탬프 자동 기록

에러 복구:

- **error**: 해당 step의 `status`를 `"pending"`으로 바꾸고 `error_message`를 삭제한 뒤 재실행.
- **blocked**: `blocked_reason`을 해결한 뒤 `status`를 `"pending"`으로, `blocked_reason`을 삭제하고 재실행.
