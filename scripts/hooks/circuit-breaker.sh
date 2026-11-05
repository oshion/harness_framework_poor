#!/bin/bash
# circuit-breaker.sh
# 60초 안에 Bash 도구 실패가 5회 반복되면 전략 변경 경고
#
# PostToolUse에는 exit code/성공 여부 필드가 없어 실패를 판별할 수 없다.
# 대신 PostToolUseFailure 이벤트(도구 호출이 실패했을 때만 발생)에 등록해서
# 이 스크립트가 "호출됐다는 사실 자체"를 실패 신호로 사용한다.

THRESHOLD=5
WINDOW=60
STATE="/tmp/.harness_circuit_breaker"

# stdin 소비 (PostToolUseFailure 훅 데이터는 사용하지 않음, 호출 자체가 실패 신호)
cat >/dev/null 2>&1 || true

NOW=$(date +%s)
echo "$NOW" >> "$STATE"

# WINDOW 이내 실패 횟수 집계
COUNT=$(awk -v now="$NOW" -v w="$WINDOW" '$1 >= (now - w)' "$STATE" 2>/dev/null | wc -l | tr -d ' ')

if [ "${COUNT:-0}" -ge "$THRESHOLD" ]; then
    printf "\n⚡ CIRCUIT BREAKER 발동\n" >&2
    printf "   %s초 안에 실패 %s회 반복 감지\n" "$WINDOW" "$COUNT" >&2
    printf "   현재 전략을 멈추고 다른 접근 방식을 시도하세요.\n\n" >&2
    # 경고 후 카운터 리셋
    > "$STATE"
fi

exit 0
