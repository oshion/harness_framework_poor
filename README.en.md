# harness_framework_poor 🪙

[한국어](README.md) | **English**

> A harness built by someone who can't afford tokens.

A modified version of [jha0313/harness_framework](https://github.com/jha0313/harness_framework), adapted to fit my wallet.

---

## What is a harness?

If you hand an AI agent "build me an app" in one go, it tends to forget the rules and drift into weird structures as the conversation grows.
A harness is a device that keeps the agent **on a fixed path**.

1. **Docs are the source of truth**: Write the PRD, architecture, technical decisions (ADR), and rules (AGENTS.md) first.
2. **Plans broken into small pieces**: `/harness` reads the docs and splits the work into step instructions (`phases/{phase}/step{N}.md`). A human reviews and approves them.
3. **A fresh session per step**: `scripts/execute.py` opens a new Claude session for each step. It injects the rule docs every time and passes along only summaries of previous steps, so the context never gets polluted.
4. **Self-verification**: Each step must pass an executable completion check (e.g. `npm run check`). On failure, the error is fed back in for up to 3 fix attempts.
5. **Safety nets**: Hooks block dangerous commands and implementations without tests, and `/review` does one more pass at the end.

```
Write docs (PRD · ARCHITECTURE · ADR · specs)
   ↓
/harness ── generate step plan → human approves
   ↓
execute.py ── new session per step: implement → verify → commit
   ↓
/review ── detect & fix rule violations
   ↓
Human tests manually via milestone checklist → PR
```

---

## Why "poor"?

Running the harness opens a new session for every step, and each one reads the full rule docs. **Tokens melt.**

If you're rich, you just pay for extra usage. I'm poor, so I can't.
So it used to go like this:

1. Kick off a phase at night and go to sleep.
2. At 3 a.m., hit the usage limit and the step ends as a failure.
3. Wake up and discover it. Now wait until the reset all over again.
4. Manually hit "continue."
5. Cry.

So I **made the harness do the waiting, too.** I pay in time instead of money.

### ⏳ Auto-wait & resume on usage limits (the core feature)

- Runs `claude -p` with `stream-json` to quietly peek at **5-hour and weekly usage plus reset times** on every call.
- When usage is **95% or higher**, it won't start a new step. It waits patiently until the reset time, then starts on its own.
  - Change the threshold with e.g. `--limit-threshold 0.9`. If you're more of a scaredy-cat, go lower.
- If a step gets cut off mid-run by the limit, **it doesn't count as a failure.** After the reset it uses `--resume` to **continue the same session** and finish the job, with its context intact.
- While waiting, the terminal shows something like this (the message is in Korean):
  ```
  ⏳ 사용량 95% 이상 — 11/05 18:02 (KST)까지 대기 후 자동으로 이어서 진행합니다 [173분]
  ```
  *(= "Usage ≥ 95%: waiting until 11/05 18:02 (KST), then resuming automatically [173 min]")*
- On Windows, it keeps the PC from going to sleep while waiting. It can't help if you close your laptop lid, though, so keep it plugged in.
- If you burn through the weekly limit, you might wait for days. The harness can't fix that. Reflect on your choices.

```bash
py -3 scripts/execute.py m0-foundation                         # Windows
python3 scripts/execute.py m0-foundation                       # macOS / Linux
py -3 scripts/execute.py m0-foundation --limit-threshold 0.9   # scaredy-cat mode
```

> This feature works off Claude subscription usage (5-hour and weekly windows). If you're on pay-as-you-go API keys, you'll get a bill instead of a limit, so this feature doesn't apply to you.

---

## Other changes

Saving tokens taught me that getting it right the first time is the cheapest option. So I strengthened the parts that reduce redoing work.

### 📚 Added documentation system
| Doc | Role |
|---|---|
| `docs/progress.md` | Milestone checklist and a **pending decisions (blockers)** table. 1 checklist item = 1 step = 1 commit |
| `docs/milestone-checklist.md` | Tests a **human** runs by hand when a milestone ends. Must pass before moving on |
| `docs/specs/` + `_TEMPLATE.md` | Detailed per-system specs. **Spec first**: no code before a spec exists |
| `docs/tech-debt-tracker.md` | Agents don't read git log, so known debt is recorded here and passed to every step |

`docs/specs/` is not auto-injected into every step; only the needed specs are listed in each step's instructions. Injecting all of them would melt tokens again.

### 🧭 Enhanced `/harness` · `/review`
- `/harness`
  - Splits steps by progress.md checklist items.
  - Follows **layer order**: pure logic & tests → server → client → E2E.
  - Asks first, before planning, if a spec is missing or a decision is still open.
  - Flags in advance the points that need a human, like API keys and deployment.
- `/review`
  - Turned the eyeball checklist into **automatic grep detection**: `any` types, layer violations, exposed secrets, missing tests.
  - Then loops build → checklist until violations hit zero.

---

## Structure

```
├─ AGENTS.md                  # Shared agent rules (write for your project)
├─ CLAUDE.md                  # Claude Code specific (commands & hooks, refers to AGENTS.md)
├─ .claude/
│  ├─ settings.json           # Hook registration
│  └─ commands/
│     ├─ harness.md           # /harness: phase & step design
│     └─ review.md            # /review: rule-violation review
├─ scripts/
│  ├─ execute.py              # Sequential step runner (includes usage waiting)
│  ├─ test_execute.py         # Runner tests (pytest)
│  └─ hooks/                  # Dangerous-command blocker, TDD guard, circuit breaker
├─ docs/
│  ├─ PRD.md · ARCHITECTURE.md · ADR.md · UI_GUIDE.md
│  ├─ progress.md · milestone-checklist.md · tech-debt-tracker.md
│  ├─ USAGE.md
│  └─ specs/ (README.md, _TEMPLATE.md)
└─ phases/index.json          # /harness adds phases here
```

---

## Quick start

**Requirements**: [Claude Code](https://claude.com/claude-code) CLI, Python 3.10+, Node 20+, git, bash (Git for Windows on Windows). And a little patience.

1. Copy this repo's files into a new project folder, run `git init`, and make the first commit.
2. Fill in the `{ }` placeholders in `AGENTS.md`, `docs/PRD.md`, `docs/ARCHITECTURE.md`, and `docs/ADR.md`.
3. Adjust the `RULES` in `scripts/hooks/tdd-guard.mjs` and the grep paths in `/review` to match your project structure.
4. Write the milestone checklist in `docs/progress.md`, and the first milestone's specs in `docs/specs/`.
5. Run `/harness` in Claude Code, then review and approve the step plan.
6. Run it with `execute.py` and go to sleep.
7. When you wake up: `/review` → test by hand with `docs/milestone-checklist.md` → PR.

See [docs/USAGE.md](docs/USAGE.md) for details (Korean).

> ⚠️ Step sessions run with `--dangerously-skip-permissions` (they edit files and run commands without asking). Only use this in trusted repositories, and don't disable the hooks (`.claude/settings.json`).

---

## Credits

- **Original repo**: [jha0313/harness_framework](https://github.com/jha0313/harness_framework)
- The original provides the entire skeleton of the harness:
  - `/harness` command: explore docs → discuss → design steps → generate `phases/` files
  - `execute.py`: sequential step execution, guardrail (rule doc) injection, accumulated summaries of completed steps, up to 3 self-correction attempts, two-stage commits (code & metadata), status & timestamp logging
  - `/review` command, Stop & dangerous-command hooks, PRD·ARCHITECTURE·ADR·UI_GUIDE templates
- This repo just adds **poverty-coping features** and doc/command enhancements on top. Many thanks to the original author for publishing such a solid foundation. 🙏
