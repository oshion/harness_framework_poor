# harness_framework_poor 🪙

> 토큰 살 돈이 없어서 만든 하네스.

[jha0313/harness_framework](https://github.com/jha0313/harness_framework)를 가져다 쓰다가, 지갑 사정에 맞게 고친 버전입니다.

---

## 하네스란?

AI 에이전트에게 "앱 만들어 줘"라고 한 번에 맡기면, 대화가 길어질수록 규칙을 잊고 엉뚱한 구조를 만들기 쉽습니다.
하네스(harness, 마구)는 에이전트가 **정해진 길로만 가게** 묶어 두는 장치입니다.

1. **문서가 기준** — 기획(PRD)·아키텍처·기술 결정(ADR)·규칙(AGENTS.md)을 먼저 씁니다.
2. **작게 쪼갠 계획** — `/harness`가 문서를 읽고 작업을 step으로 나눈 지시서(`phases/{phase}/step{N}.md`)를 만듭니다. 사람이 검토하고 승인합니다.
3. **step마다 새 세션** — `scripts/execute.py`가 step 하나마다 새 Claude 세션을 열어 실행합니다. 매번 규칙 문서를 넣어 주고 앞 step의 요약만 넘겨서 맥락이 오염되지 않습니다.
4. **스스로 검증** — 각 step은 실행 가능한 완료 조건(`npm run check` 등)을 통과해야 끝납니다. 실패하면 에러를 다시 넣어 최대 3회 고칩니다.
5. **안전장치** — 훅이 위험한 명령과 테스트 없는 구현을 막고, 끝나면 `/review`로 한 번 더 걸러냅니다.

```
문서 작성 (PRD · ARCHITECTURE · ADR · specs)
   ↓
/harness ── step 계획 생성 → 사람이 승인
   ↓
execute.py ── step마다 새 세션: 구현 → 검증 → 커밋
   ↓
/review ── 규칙 위반 탐지·수정
   ↓
마일스톤 체크리스트로 사람이 직접 테스트 → PR
```

---

## 왜 poor인가

하네스를 돌리면 step마다 새 세션이 열리고, 그때마다 규칙 문서를 통째로 읽습니다. **토큰이 녹습니다.**

부자라면 추가 사용량을 결제하면 됩니다. 저는 가난해서 그럴 돈이 없습니다.
그래서 원래는 이랬습니다.

1. 밤에 phase를 걸어 두고 잔다.
2. 새벽 3시에 사용량 한도에 걸려 step이 실패로 끝난다.
3. 아침에 일어나 그걸 발견한다. 그때부터 리셋까지 다시 기다린다.
4. "이어서 하기"를 직접 누른다.
5. 운다.

그래서 **기다리는 것까지 하네스에게 맡겼습니다.** 돈 대신 시간으로 냅니다.

### ⏳ 사용량 한도 자동 대기·이어 하기 (핵심)

- `claude -p`를 `stream-json`으로 실행해서 **5시간·주간 사용량과 리셋 시각**을 매번 몰래 엿봅니다.
- 사용량이 **95% 이상**이면 새 step을 시작하지 않고, 리셋 시각까지 얌전히 기다렸다가 알아서 시작합니다.
  - 기준은 `--limit-threshold 0.9`처럼 바꿀 수 있습니다. 더 겁이 많으면 낮추세요.
- step 도중에 한도에 걸려 끊겨도 **실패로 치지 않습니다.** 리셋 후 `--resume`으로 **같은 세션을 이어서** 하던 걸 마저 끝냅니다. 하던 맥락도 그대로 남습니다.
- 기다리는 동안 터미널에는 이렇게 뜹니다.
  ```
  ⏳ 사용량 95% 이상 — 11/05 18:02 (KST)까지 대기 후 자동으로 이어서 진행합니다 [173분]
  ```
- Windows에서는 기다리는 동안 PC가 절전으로 들어가지 않게 막습니다. 다만 노트북 덮개를 닫으면 어쩔 수 없으니 전원은 꽂아 두세요.
- 주간 한도까지 다 쓰면 며칠을 기다릴 수도 있습니다. 그건 하네스도 어쩔 수 없습니다. 반성하세요.

```bash
py -3 scripts/execute.py m0-foundation                         # Windows
python3 scripts/execute.py m0-foundation                       # macOS / Linux
py -3 scripts/execute.py m0-foundation --limit-threshold 0.9   # 겁 많은 버전
```

> 이 기능은 Claude 구독 사용량(5시간·주간 창)을 기준으로 동작합니다. API 키 종량제로 쓰고 있다면 한도 대신 청구서가 날아오니 이 기능과는 관계가 없습니다.

---

## 그 밖에 바꾼 것

토큰을 아끼다 보니 "한 번에 제대로" 끝내는 게 제일 싸다는 걸 알게 됐습니다. 그래서 다시 하는 일을 줄이는 쪽을 보강했습니다.

### 📚 문서 체계 추가
| 문서 | 역할 |
|---|---|
| `docs/progress.md` | 마일스톤 체크리스트와 **결정 대기(블로커)** 표. 체크리스트 1개 = step 1개 = 커밋 1개 |
| `docs/milestone-checklist.md` | 마일스톤이 끝나면 **사람이 직접** 확인하는 테스트 목록. 통과해야 다음 단계로 |
| `docs/specs/` + `_TEMPLATE.md` | 시스템별 상세 스펙. **스펙 우선**: 스펙 없이 코드부터 쓰지 않음 |
| `docs/tech-debt-tracker.md` | 에이전트는 git log를 안 읽으므로, 알려진 부채를 여기 남겨 매 step에 전달 |

`docs/specs/`는 step마다 자동으로 넣지 않고, 필요한 스펙만 step 지시서에 적게 했습니다. 다 넣으면 또 토큰이 녹습니다.

### 🧭 `/harness` · `/review` 강화
- `/harness`
  - progress.md 체크리스트 단위로 step을 나눕니다.
  - **레이어 순서**를 지킵니다: 순수 로직·테스트 → 서버 → 클라이언트 → E2E.
  - 스펙이 없거나 결정이 안 된 게 있으면 계획 전에 먼저 물어봅니다.
  - API 키·배포처럼 사람이 해야 하는 지점을 미리 표시합니다.
- `/review`
  - 눈으로 보던 체크리스트를 **grep 자동 탐지**로 바꿨습니다. `any` 타입, 레이어 위반, 시크릿 노출, 테스트 누락을 찾습니다.
  - 그다음 빌드 → 체크리스트 → 위반이 0이 될 때까지 반복합니다.

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
│  ├─ execute.py              # step 순차 실행기 (사용량 대기 포함)
│  ├─ test_execute.py         # 실행기 테스트 (pytest)
│  └─ hooks/                  # 위험 명령 차단, TDD 가드, 서킷 브레이커
├─ docs/
│  ├─ PRD.md · ARCHITECTURE.md · ADR.md · UI_GUIDE.md
│  ├─ progress.md · milestone-checklist.md · tech-debt-tracker.md
│  ├─ USAGE.md
│  └─ specs/ (README.md, _TEMPLATE.md)
└─ phases/index.json          # /harness가 phase를 추가
```

---

## 빠른 시작

**필요한 것**: [Claude Code](https://claude.com/claude-code) CLI, Python 3.10+, Node 20+, git, bash (Windows는 Git for Windows). 그리고 약간의 인내심.

1. 이 저장소 파일을 새 프로젝트 폴더에 복사하고 `git init` 후 첫 커밋을 합니다.
2. `AGENTS.md`, `docs/PRD.md`, `docs/ARCHITECTURE.md`, `docs/ADR.md`의 `{ }` 부분을 채웁니다.
3. `scripts/hooks/tdd-guard.mjs`의 `RULES`와 `/review`의 grep 경로를 프로젝트 구조에 맞춥니다.
4. `docs/progress.md`에 마일스톤 체크리스트를 쓰고, 첫 마일스톤 스펙을 `docs/specs/`에 씁니다.
5. Claude Code에서 `/harness`를 실행하고, step 계획을 검토해 승인합니다.
6. `execute.py`로 실행하고 잡니다.
7. 일어나면 `/review` → `docs/milestone-checklist.md`로 직접 테스트 → PR.

자세한 내용은 [docs/USAGE.md](docs/USAGE.md).

> ⚠️ step 세션은 `--dangerously-skip-permissions`로 실행됩니다(권한 확인 없이 파일 수정·명령 실행). 신뢰할 수 있는 저장소에서만 쓰고, 훅(`.claude/settings.json`)을 끄지 마세요.

---

## 원본

- **원본 저장소**: [jha0313/harness_framework](https://github.com/jha0313/harness_framework)
- 원본이 하네스의 뼈대를 전부 제공합니다.
  - `/harness` 커맨드: 문서 탐색 → 논의 → step 설계 → `phases/` 파일 생성
  - `execute.py`: step 순차 실행, 가드레일(규칙 문서) 주입, 완료 step 요약 누적, 최대 3회 자가 교정, 코드·메타데이터 2단계 커밋, 상태·타임스탬프 기록
  - `/review` 커맨드, Stop·위험 명령 훅, PRD·ARCHITECTURE·ADR·UI_GUIDE 템플릿
- 이 저장소는 그 위에 **가난 대응 기능**과 문서·커맨드 보강을 얹었을 뿐입니다. 좋은 뼈대를 공개해 주신 원작자께 감사드립니다. 🙏
