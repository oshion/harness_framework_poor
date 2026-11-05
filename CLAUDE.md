# CLAUDE.md

공통 규칙은 AGENTS.md에 있다. 반드시 먼저 읽고 따른다.

@AGENTS.md

---

## Claude Code 전용

### 슬래시 커맨드

| 커맨드 | 용도 |
|--------|------|
| `/harness` | PRD·스펙을 읽고 phase/step 구현 계획을 설계해 `phases/`에 생성 |
| `/review` | AGENTS.md 규칙 기준으로 변경 사항을 자동 탐지·체크리스트 리뷰 |

### 훅 (`.claude/settings.json`, 자동 동작)

| 훅 | 시점 | 동작 |
|----|------|------|
| `dangerous-cmd-guard.sh` | Bash/PowerShell 실행 전 | `rm -rf`, force push, `git reset --hard`, `DROP TABLE` 등 차단 |
| `tdd-guard.mjs` | Edit/Write 전 | TDD 대상 경로 수정 시 `tests/unit/` 미러 테스트가 없으면 차단 |
| `circuit-breaker.sh` | Bash/PowerShell 실패 시 | 60초 내 5회 실패 시 접근 방식 전환 경고 |
| Stop | 응답 종료 시 | `package.json`이 있으면 `npm run check` 실행 |

훅에 차단되면 우회하지 말고 원인(테스트 누락, 위험 명령)을 해결한다.

### Windows 환경 메모

- `python3`/`python`은 Microsoft Store 스텁일 수 있다. 하네스 실행기는 `py -3 scripts/execute.py <phase>`로 실행한다.
- 훅은 Python에 의존하지 않는다 (Node + bash). Git for Windows의 bash가 필요하다.
