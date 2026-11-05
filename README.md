# Harness Framework (확장판)

Claude Code로 **문서 → 단계별 계획 → 자동 구현 → 검증**을 반복하는 개발 하네스.
[jha0313/harness_framework](https://github.com/jha0313/harness_framework)를 실제 프로젝트(9주짜리 웹 게임 개발)에 쓰면서 부족했던 부분을 보강한 버전입니다.

---

## 하네스란?

AI 에이전트에게 "앱 만들어 줘"라고 한 번에 맡기면, 맥락이 길어질수록 규칙을 잊고 엉뚱한 구조를 만들기 쉽습니다.
하네스(harness, 마구)는 에이전트가 **정해진 길로만 가게** 묶어 두는 장치입니다.

1. **문서가 기준** — 기획(PRD)·아키텍처·기술 결정(ADR)·규칙(AGENTS.md)을 먼저 씁니다.
2. **작게 쪼갠 계획** — `/harness`가 문서를 읽고 작업을 step으로 나눈 지시서(`phases/{phase}/step{N}.md`)를 만듭니다. 사람이 검토하고 승인합니다.
3. **step마다 새 세션** — `scripts/execute.py`가 step 하나마다 새 Claude 세션을 열어 실행합니다. 매번 규칙 문서를 프롬프트에 넣어 주고, 앞 step의 요약만 넘겨서 맥락이 오염되지 않습니다.
4. **스스로 검증** — 각 step은 실행 가능한 완료 조건(`npm run check` 등)을 통과해야 끝납니다. 실패하면 에러를 다시 넣어 최대 3회 고칩니다.
5. **안전장치** — 훅이 위험한 명령, 테스트 없는 구현을 막습니다. 끝나면 `/review`로 규칙 위반을 한 번 더 걸러냅니다.

```
문서 작성 (PRD · ARCHITECTURE · ADR · specs)
   ↓
/harness ── step 계획 생성 → 사람이 승인
   ↓
execute.py ── step마다 새 세션: 구현 → 검증 → 커밋 (자동 재시도·사용량 대기)
   ↓
/review ── 규칙 위반 탐지·수정
   ↓
마일스톤 체크리스트로 사람이 직접 테스트 → PR
```

---

## 원본 대비 좋아진 점

### 1. 사용량 한도 자동 대기·이어 하기 (토큰 소진 대응)
원본은 Claude 구독 사용량이 다 차면 step이 실패로 처리되고, 사람이 기다렸다가 다시 실행해야 했습니다.
- `claude -p`를 `stream-json`으로 실행해 **5시간·주간 사용량과 리셋 시각**을 매번 읽습니다.
- 사용량이 **95% 이상**이면 새 step을 시작하지 않고 리셋까지 기다린 뒤 자동으로 시작합니다 (`--limit-threshold`로 조정).
- step 도중 한도에 걸려 끊기면 **재시도 횟수를 쓰지 않고**, 리셋 후 `--resume`으로 **같은 세션을 이어서** 끝냅니다.
- Windows에서는 실행·대기 중 PC 절전을 막습니다.

### 2. Windows에서 실제로 돌아감
원본 `execute.py`는 macOS/Linux 기준이라 Windows에서 막히는 곳이 있었습니다.
- `claude`가 Windows에서는 `claude.cmd`라서 그냥 실행하면 찾지 못함 → `shutil.which`로 경로를 찾습니다.
- 규칙 문서 전체를 명령줄 인자로 넘기면 Windows 명령줄 길이 제한(약 32K)을 넘음 → 프롬프트를 **stdin으로** 넘깁니다.
- 인코딩을 지정하지 않으면 한국어 Windows(cp949)에서 한글 문서를 읽다 깨짐 → 모든 파일·프로세스 입출력을 **UTF-8로 고정**합니다.
- 훅은 Python 없이 Node + bash로 동작하고, `.gitattributes`로 셸 스크립트 줄바꿈을 LF로 고정합니다.
- `py -3` 실행 안내 (Microsoft Store `python3` 스텁 문제).

### 3. 훅이 실제로 막도록 수정 + 훅 추가
| 훅 | 원본 | 확장판 |
|---|---|---|
| 위험 명령 차단 | settings.json 한 줄 명령, **exit 1**(Claude Code는 exit 2만 차단하므로 경고만 됨) | 별도 스크립트, stdin JSON 읽기, **exit 2로 실제 차단**, PowerShell까지 대상, `git clean -f`·`TRUNCATE`·`Remove-Item -Recurse -Force` 등 패턴 추가 |
| TDD 가드 | 없음 (규칙 문구만) | 지정한 레이어의 구현 파일을 만들 때 미러 테스트(`tests/unit/...`)가 없으면 **차단** |
| 서킷 브레이커 | 없음 | 60초 안에 명령이 5번 실패하면 "접근 방식을 바꾸라"고 경고 (같은 실패 반복 방지) |
| Stop 훅 | lint·build·test를 항상 실행 (프로젝트 세팅 전에는 무조건 실패) | `package.json`이 있을 때만 `npm run check` |

### 4. 가드레일 주입 개선
- `CLAUDE.md`만 넣던 것을 **`AGENTS.md`(모든 에이전트 공통 규칙) + `CLAUDE.md`(Claude 전용)**로 나눴습니다. Codex 등 다른 에이전트도 같은 규칙을 읽습니다.
- `docs/*.md` → **`docs/**/*.md`(하위 폴더 포함)**. 단 `docs/specs/`는 제외해서 프롬프트가 비대해지지 않게 하고, step 지시서가 필요한 스펙만 지정합니다.

### 5. 문서 체계 추가
| 문서 | 역할 |
|---|---|
| `docs/progress.md` | 마일스톤 체크리스트와 **결정 대기(블로커)** 표. 체크리스트 1개 = step 1개 = 커밋 1개 |
| `docs/milestone-checklist.md` | 마일스톤이 끝나면 **사람이 직접** 확인하는 테스트 목록. 통과해야 다음 단계로 |
| `docs/specs/` + `_TEMPLATE.md` | 시스템별 상세 스펙. **스펙 우선** — 스펙 없이 코드부터 쓰지 않음 |
| `docs/tech-debt-tracker.md` | 에이전트는 git log를 읽지 않으므로, 알려진 부채를 여기 남겨 매 step에 주입 |
| `docs/USAGE.md` | 하네스 전체 사용법 |
| `docs/ADR.md` | 상태(채택·대체됨·보류)와 목록 표, 결정을 뒤집을 때 지우지 않는 규칙 |

### 6. `/harness` · `/review` 강화
- `/harness`: 체크리스트 단위로 step 분할, **레이어 순서**(순수 로직·테스트 → 서버 → 클라이언트 → E2E), 없는 스펙·블로커를 먼저 논의, 사용자 개입(API 키·배포) 지점 명시, 완료 시 progress.md 체크.
- `/review`: 체크리스트를 눈으로만 보던 것에서 **grep 자동 탐지**(any 타입, 레이어 위반, 시크릿 노출, 테스트 누락) → 빌드 → 체크리스트 → 위반이 0이 될 때까지 반복.

### 7. 테스트
`scripts/test_execute.py` 51개 → **75개**. 사용량 대기·이어 하기, stdin 전달, Windows 실행 파일 해석 등을 검증합니다.

```bash
py -3 -m pytest scripts/test_execute.py -q
```

---

## 구성

```
├─ AGENTS.md                  # 에이전트 공통 규칙 (프로젝트에 맞게 작성)
├─ CLAUDE.md                  # Claude Code 전용 (커맨드·훅 안내, AGENTS.md 참조)
├─ .claude/
│  ├─ settings.json           # 훅 등록
│  └─ commands/
│     ├─ harness.md           # /harness — phase·step 설계
│     └─ review.md            # /review — 규칙 위반 리뷰
├─ scripts/
│  ├─ execute.py              # step 순차 실행기
│  ├─ test_execute.py         # 실행기 테스트 (pytest)
│  └─ hooks/
│     ├─ dangerous-cmd-guard.sh
│     ├─ tdd-guard.mjs        # RULES를 프로젝트 레이어에 맞게 수정
│     └─ circuit-breaker.sh
├─ docs/
│  ├─ PRD.md · ARCHITECTURE.md · ADR.md · UI_GUIDE.md
│  ├─ progress.md · milestone-checklist.md · tech-debt-tracker.md
│  ├─ USAGE.md
│  └─ specs/ (README.md, _TEMPLATE.md)
└─ phases/index.json          # /harness가 phase를 추가
```

---

## 빠른 시작

**필요한 것**: [Claude Code](https://claude.com/claude-code) CLI, Python 3.10+, Node 20+, git, bash (Windows는 Git for Windows)

1. 이 저장소 파일을 새 프로젝트 폴더에 복사하고 `git init` 후 첫 커밋을 합니다.
2. `AGENTS.md`, `docs/PRD.md`, `docs/ARCHITECTURE.md`, `docs/ADR.md`의 `{ }` 부분을 채웁니다.
3. `scripts/hooks/tdd-guard.mjs`의 `RULES`와 `/review`의 grep 경로를 프로젝트 구조에 맞춥니다.
4. `docs/progress.md`에 마일스톤 체크리스트를 쓰고, 첫 마일스톤 스펙을 `docs/specs/`에 씁니다.
5. Claude Code에서 `/harness` → step 계획을 검토·승인합니다.
6. 실행합니다:
   ```bash
   py -3 scripts/execute.py m0-foundation      # Windows
   python3 scripts/execute.py m0-foundation    # macOS / Linux
   ```
7. 끝나면 `/review` → `docs/milestone-checklist.md`로 직접 테스트 → PR.

자세한 내용은 [docs/USAGE.md](docs/USAGE.md).

> ⚠️ step 세션은 `--dangerously-skip-permissions`로 실행됩니다(권한 확인 없이 파일 수정·명령 실행). 신뢰할 수 있는 저장소에서만 쓰고, 훅(`.claude/settings.json`)을 끄지 마세요.

---

## 원본

- **원본 저장소**: [jha0313/harness_framework](https://github.com/jha0313/harness_framework)
- 원본은 Claude Code용 하네스의 뼈대를 제공합니다:
  - `/harness` 커맨드 — 문서 탐색 → 논의 → step 설계 → `phases/` 파일 생성
  - `execute.py` — step 순차 실행, 가드레일(CLAUDE.md + docs) 주입, 완료 step 요약 누적, 최대 3회 자가 교정, 코드·메타데이터 2단계 커밋, 상태·타임스탬프 기록
  - `/review` 커맨드, Stop·위험 명령 훅, PRD·ARCHITECTURE·ADR·UI_GUIDE 템플릿
- 이 저장소의 워크플로우와 `execute.py`의 기본 구조는 원본을 따르며, 위 "원본 대비 좋아진 점"이 추가·수정한 부분입니다.
