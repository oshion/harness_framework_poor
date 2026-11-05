이 프로젝트의 변경 사항을 리뷰하라.

먼저 다음 문서들을 읽어라:
- `/AGENTS.md`
- `/docs/ARCHITECTURE.md`
- `/docs/ADR.md`
- 변경된 기능의 `/docs/specs/*.md`

---

## Step 1: 코드 레벨 자동 탐지

아래 명령어를 직접 실행하고 결과를 기록하라. 출력이 있으면 위반 후보, 없으면 통과다.
(린트가 대부분을 강제하더라도, 규칙이 꺼지거나 우회됐는지 이중 확인한다.)
**경로와 패턴은 프로젝트의 AGENTS.md CRITICAL 규칙에 맞게 고친다.**

```bash
# 1. any 타입
grep -rnE ":\s*any\b|<any>|as any" src/ --include="*.ts"

# 2. 레이어 순수성 — 순수 로직 레이어가 UI·DOM·네트워크에 의존하는지 (예: src/core/)
grep -rnE "\b(window|document|localStorage|sessionStorage|requestAnimationFrame|fetch)\b" src/core/

# 3. 결정성 — 순수 로직에서 직접 난수/시간 사용
grep -rnE "Math\.random|Date\.now|new Date\(" src/core/

# 4. 시크릿 노출 — 클라이언트 노출 접두사가 붙은 시크릿, 서버 설정 밖에서 시크릿 참조
grep -rnE "(PUBLIC_|VITE_|NEXT_PUBLIC_)[A-Z_]*(KEY|SECRET|TOKEN|PRIVATE)" src/ .env* 2>/dev/null
grep -rnE "process\.env\.[A-Z_]*(KEY|SECRET|TOKEN)" src/ | grep -v "^src/server/config.ts"

# 5. 클라이언트가 서버 코드를 직접 import
grep -rnE "from ['\"].*server/" src/client/ 2>/dev/null

# 6. 테스트 미러 누락 — TDD 대상 레이어 구현 대비 tests/unit
for f in $(find src/core src/server -name "*.ts" ! -name "index.ts" ! -name "*.d.ts" 2>/dev/null); do t="tests/unit/${f#src/}"; t="${t%.ts}.test.ts"; [ -f "$t" ] || echo "테스트 없음: $f"; done
```

## Step 2: 빌드·검증 실행

```bash
npm run check      # typecheck + lint + unit
npm run build      # 프로덕션 빌드
npm run test:e2e   # UI 변경이 있을 때
```

---

## Step 3: 체크리스트 확인

| 항목 | 확인 방법 | 결과 | 비고 |
|------|-----------|------|------|
| any 타입 없음 | Step1 #1 | ✅/❌ | |
| 레이어 순수성 | Step1 #2, #5 | ✅/❌ | |
| 결정성 (주입된 난수·시계 사용) | Step1 #3 | ✅/❌/해당없음 | |
| 수치·UI 문자열 하드코딩 없음 | diff 육안 확인 | ✅/❌ | |
| 외부 JSON은 스키마 검증 | diff 확인 | ✅/❌/해당없음 | |
| 시크릿 노출 없음 | Step1 #4 | ✅/❌ | |
| TDD 대상 레이어 테스트 존재 | Step1 #6 | ✅/❌ | |
| 저장 포맷 변경 시 버전 + 마이그레이션 테스트 | diff 확인 | ✅/❌/해당없음 | |
| 스펙과 구현 일치 | docs/specs/ 대조 | ✅/❌ | |
| ADR 기술 스택 준수 | package.json 확인 | ✅/❌ | |
| check / build / e2e 통과 | Step 2 | ✅/❌ | |
| progress.md 갱신 | 파일 확인 | ✅/❌ | |

---

## Step 4: 위반 사항 처리

위반이 있으면 수정 후 Step 1부터 다시 실행하라. 모든 항목이 ✅(또는 해당없음)가 될 때까지 반복한다.
당장 고칠 수 없는 항목은 이유와 함께 `docs/tech-debt-tracker.md`에 기록한다.
