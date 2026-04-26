#!/usr/bin/env bash
# Codex (OpenAI) 일일 토큰 사용량을 별도 캐시에 저장.
# tmux status-right 가 매 N 초마다 OpenAI API 를 두드리는 걸 피하려고 분리.
#
# launchd LaunchAgent 로 1 분마다 실행하는 걸 권장합니다 (README 참고).
# cron 은 macOS 에서 Keychain 접근이 막혀 비추천.
#
# 환경변수 / Keychain 둘 다 지원:
#   - $OPENAI_ADMIN_KEY 가 있으면 그걸 사용
#   - 없으면 macOS Keychain 의 generic-password 에서 조회
#       service = $AIBAR_KEYCHAIN_SERVICE  (기본: openai-admin-key)
#       account = $AIBAR_KEYCHAIN_ACCOUNT  (기본: $USER)
#
# 캐시 위치는 $AIBAR_CACHE_DIR (기본: 플러그인 폴더 내 cache/).

set -euo pipefail

# launchd/cron 은 PATH 가 매우 좁음 → 명시 확장.
export PATH="/usr/bin:/bin:/usr/sbin:/sbin:/opt/homebrew/bin:/usr/local/bin:${PATH:-}"

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PLUGIN_ROOT="$( cd "$DIR/.." && pwd )"

CACHE_DIR="${AIBAR_CACHE_DIR:-$PLUGIN_ROOT/cache}"
CACHE="$CACHE_DIR/codex-usage.txt"
mkdir -p "$CACHE_DIR"

KEYCHAIN_SERVICE="${AIBAR_KEYCHAIN_SERVICE:-openai-admin-key}"
KEYCHAIN_ACCOUNT="${AIBAR_KEYCHAIN_ACCOUNT:-${USER:-}}"

# 1) env 우선. 없으면 macOS Keychain fallback.
if [[ -z "${OPENAI_ADMIN_KEY:-}" ]] && [[ "$(uname -s)" == "Darwin" ]]; then
  OPENAI_ADMIN_KEY=$(security find-generic-password \
    -a "$KEYCHAIN_ACCOUNT" -s "$KEYCHAIN_SERVICE" -w 2>/dev/null || true)
fi

if [[ -z "${OPENAI_ADMIN_KEY:-}" ]]; then
  echo "(no key)" > "$CACHE"
  exit 0
fi

# 2) 오늘 자정 epoch (BSD/GNU date 호환).
today_start=$(date -j -f "%H:%M:%S" "00:00:00" +%s 2>/dev/null \
           || date -u -d 'today 00:00' +%s 2>/dev/null \
           || date -u +%s)

# 3) OpenAI Admin API 호출.
resp=$(curl -s --max-time 5 \
  "https://api.openai.com/v1/organization/usage/completions?start_time=${today_start}&bucket_width=1d" \
  -H "Authorization: Bearer ${OPENAI_ADMIN_KEY}" \
  -H "Content-Type: application/json" 2>/dev/null || echo '{}')

tok=$(echo "$resp" | jq -r '
  [.data[]?.results[]? | (.input_tokens // 0) + (.output_tokens // 0)]
  | add // 0
' 2>/dev/null || echo 0)

printf '%dk today\n' "$((tok/1000))" > "$CACHE"
