#!/bin/bash
# dangerous-cmd-guard.sh
# 위험한 명령어가 감지되면 실행을 차단한다. (Bash / PowerShell 도구 공용)
# 차단은 exit 2 — Claude Code 훅 규약상 exit 2만 도구 호출을 막는다.

INPUT=$(cat 2>/dev/null || true)

# 차단할 명령어 패턴
BLOCKED_PATTERNS=(
    'rm\s+-rf'
    'git\s+push\s+(-f|--force)'
    'git\s+reset\s+--hard'
    'git\s+clean\s+-[a-z]*f'
    'DROP\s+(TABLE|SCHEMA|DATABASE)'
    'TRUNCATE\s+TABLE'
    'supabase\s+db\s+reset'
    'Remove-Item.*-Recurse.*-Force'
    'Remove-Item.*-Force.*-Recurse'
)

for PATTERN in "${BLOCKED_PATTERNS[@]}"; do
    if echo "$INPUT" | grep -qiE "$PATTERN"; then
        printf "\n🚫 DANGEROUS COMMAND GUARD: 위험한 명령어가 차단되었습니다.\n" >&2
        printf "   패턴: %s\n" "$PATTERN" >&2
        printf "   꼭 필요하면 사용자에게 직접 실행을 요청하세요.\n\n" >&2
        exit 2
    fi
done

exit 0
