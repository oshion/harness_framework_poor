# 사용법 — 하네스 워크플로우

이 저장소에서 AI 에이전트로 기능을 개발하는 순서. 규칙은 [AGENTS.md](../AGENTS.md), 구조는 [ARCHITECTURE.md](ARCHITECTURE.md).

---

## 0. 사전 준비 (최초 1회)

```bash
git init
git add -A && git commit -m "chore: harness setup"
```

- `scripts/execute.py`는 git 저장소가 아니면 즉시 실패한다 (`feat-{phase}` 브랜치를 자동 생성).
- 필요 도구: Node 20+, Python 3.10+, Claude Code CLI(`claude`), bash(Windows는 Git for Windows).
- **Windows**: `python3`가 Microsoft Store 스텁일 수 있다 → 실행기는 `py -3`로 실행한다.

---

## 1. 문서 작성 (순서 중요)

| 순서 | 문서 | 시점 |
|---|---|---|
| 1 | [PRD.md](PRD.md) | 기획 변경 시 먼저 수정 (단일 원천) |
| 2 | [UI_GUIDE.md](UI_GUIDE.md) | 스펙의 화면 절보다 먼저 확정 (스펙이 참조) |
| 3 | [ADR.md](ADR.md) | 기술 결정이 생길 때마다 |
| 4 | [progress.md](progress.md) | 마일스톤별 체크리스트·블로커 |
| 5 | `docs/specs/{system}.md` | 각 마일스톤 착수 전 (아래) |

### 마일스톤 착수 전 스펙 작성

1. [progress.md](progress.md)에서 다음 마일스톤의 "착수 전 필요 스펙"을 확인한다.
2. [specs/_TEMPLATE.md](specs/_TEMPLATE.md)를 복사해 `docs/specs/{system}.md`를 작성한다. 수치는 `data/` 키로 표기한다.
3. 결정이 필요하면 [ADR.md](ADR.md)에 ADR 항목을 추가한다.
4. [progress.md](progress.md)의 "결정 대기" 중 이 마일스톤을 막는 항목을 먼저 해소한다.

---

## 2. `/harness` 로 phase 설계

`.claude/commands/harness.md`에 정의된 슬래시 커맨드.

1. **탐색** — PRD, progress, ARCHITECTURE, 해당 마일스톤 스펙을 읽는다.
2. **논의** — 스펙 공백·결정 사항을 사용자와 정리한다.
3. **Step 설계** — progress.md 체크리스트 항목 단위로 step을 쪼갠 초안을 제시한다.
4. **파일 생성** (사용자 승인 후):
   - `phases/index.json`에 phase 항목 추가
   - `phases/{phase}/index.json` — step 목록과 상태
   - `phases/{phase}/step{K}.md` — step별 자기완결 지시서

---

## 3. 실행

```bash
py -3 scripts/execute.py {phase}           # Windows
python3 scripts/execute.py {phase}         # macOS / Linux
py -3 scripts/execute.py {phase} --push    # 완료 후 origin push
py -3 scripts/execute.py {phase} --limit-threshold 0.9    # 사용량 대기 기준 변경 (기본 0.95)
```

`execute.py`가 자동으로 처리하는 것:

- `feat-{phase}` 브랜치 생성/checkout
- 가드레일 주입 — `AGENTS.md` + `CLAUDE.md` + `docs/**/*.md` (단 `docs/specs/`는 제외 — step 파일이 필요한 스펙만 지정)
- 컨텍스트 누적 — 완료된 step의 `summary`를 다음 step에 전달
- 자가 교정 — 실패 시 최대 3회 재시도, 이전 에러를 피드백
- 2단계 커밋 — 코드(`feat`)와 메타데이터(`chore`) 분리
- 타임스탬프 기록 (`started_at`, `completed_at`, `failed_at`, `blocked_at`)
- **사용량 한도 자동 대기** — 아래 참고

> step 세션은 `claude -p --dangerously-skip-permissions`로 실행된다 (권한 확인 없이 파일 수정·명령 실행). 훅(위험 명령 차단, TDD 가드)이 안전장치이므로 `.claude/settings.json`을 지우지 않는다.

### 사용량 한도 (토큰 소진) 자동 대기

Claude 구독 사용량(5시간 창·주간 창)을 매 실행마다 읽어서 알아서 멈췄다가 이어 간다. 사람이 "이어서 하기"를 누를 필요가 없다.

- **step 시작 전**: 직전 실행의 사용량이 95%(`--limit-threshold`) 이상이면 새 step을 시작하지 않고, 리셋 시각 + 2분까지 기다린 뒤 시작한다.
- **step 도중 100% 도달**: 세션이 끊기면 재시도 횟수(3회)에 넣지 않는다. 리셋까지 기다린 뒤 같은 세션을 `--resume`으로 이어서 실행한다 (하던 작업 맥락 유지, 최대 10번).
- 대기 중에는 터미널에 재시작 시각이 나온다. Ctrl+C로 멈추고 나중에 같은 명령으로 다시 실행해도 된다 (완료된 step은 건너뜀).
- Windows에서는 실행·대기 중 PC 절전을 막는다. **노트북 덮개 닫기·수동 절전·종료**는 막지 못하니 전원을 연결해 둔다.
- 주간 창이 차면 대기가 며칠이 될 수 있다. 터미널에 나온 시각을 보고 판단한다.
- 시간대 표시는 `StepExecutor.TZ`(기본 KST, UTC+9)를 바꾸면 된다.

### 에러 복구

| 상태 | 대응 |
|------|------|
| `error` | `phases/{phase}/index.json`에서 해당 step `status`를 `"pending"`으로, `error_message` 삭제 후 재실행 |
| `blocked` | `blocked_reason`(API 키, 배포 계정, 결정 대기 등)을 해결한 뒤 `"pending"`으로 바꾸고 재실행 |

---

## 4. `/review` 로 검증

AGENTS.md 규칙 위반을 grep·빌드로 탐지하고 체크리스트를 판정한다. 위반이 없을 때까지 수정 → 재실행.

---

## 5. 마일스톤 마무리

1. 스테이징에 배포하고 [milestone-checklist.md](milestone-checklist.md)로 직접 테스트한다.
2. `progress.md` 체크 · `tech-debt-tracker.md` 갱신.
3. PR 생성 → CI 통과 → 머지.

---

## 훅 (자동, 별도 실행 불필요)

| 훅 | 시점 | 하는 일 |
|----|------|---------|
| `dangerous-cmd-guard.sh` | Bash/PowerShell 실행 전 | `rm -rf`, force push, `git reset --hard`, `git clean -f`, `DROP TABLE`, `Remove-Item -Recurse -Force` 차단 (exit 2) |
| `tdd-guard.mjs` | Edit/Write 전 | RULES에 지정한 경로의 구현 파일에 `tests/unit/` 미러 테스트가 없으면 차단 (exit 2) |
| `circuit-breaker.sh` | Bash/PowerShell 실패 시 | 60초 안에 5회 이상 실패하면 전략 전환 경고 |
| Stop | 응답 종료 시 | `package.json`이 있으면 `npm run check` (스캐폴딩 전에는 스킵) |

> Claude Code 훅은 **exit 2**일 때만 도구 호출을 차단한다. 새 가드 훅을 추가할 때 exit 1을 쓰면 경고만 뜨고 통과된다.

---

## 전체 흐름

```
[마일스톤 N] 스펙 작성 (docs/specs/) + 결정 대기 해소
   ↓
/harness → phases/{phase}/ 생성 → 사람이 검토·승인
   ↓
execute.py → step별 새 세션으로 구현·검증·커밋 (훅·가드레일·사용량 대기 자동)
   ↓
/review → 규칙 위반 0
   ↓
스테이징 배포 → milestone-checklist.md 직접 테스트 → progress.md 갱신 → PR
```
