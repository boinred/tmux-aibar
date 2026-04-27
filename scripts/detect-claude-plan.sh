#!/usr/bin/env bash
# Claude Code 가 macOS Keychain 에 저장한 OAuth 자격증명에서
# rateLimitTier 필드를 읽어 plan 이름 (pro / max5 / max20) 으로 매핑하고,
# cache/claude-plan.txt 에 저장합니다.
#
# 한 번 실행해두면 ai-usage.sh 가 매 status 갱신마다 keychain 을 건드리지
# 않고 캐시만 cat 하므로 빠르고, 추가 keychain prompt 도 없습니다.
#
# 사용법:
#   ./scripts/detect-claude-plan.sh         # 기본 (cache/claude-plan.txt)
#   AIBAR_CACHE_DIR=/path ./.../detect-... # 캐시 위치 override
#
# plan 이 변경됐을 때 (예: Pro → Max5 업그레이드) 다시 실행하시면 됩니다.
#
# 참고: 본 스크립트는 OAuth 자격증명 *원문* 을 변수로만 잡고
# 절대 stdout / stderr 로 출력하지 않습니다. 실패 시에도 token 을 노출하지 않습니다.

set -euo pipefail

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PLUGIN_ROOT="$( cd "$DIR/.." && pwd )"
CACHE_DIR="${AIBAR_CACHE_DIR:-$PLUGIN_ROOT/cache}"
CACHE="$CACHE_DIR/claude-plan.txt"

KEYCHAIN_ITEM="${AIBAR_CLAUDE_KEYCHAIN_ITEM:-Claude Code-credentials}"

if [[ "$(uname -s)" != "Darwin" ]]; then
  cat >&2 <<'EOF'
✗ 본 스크립트는 macOS Keychain 전용입니다.
  Linux 사용자는 ~/.tmux.conf 에 다음을 추가해 manual 설정하세요:
    set -g @aibar_claude_plan "max20"   # 또는 max5 / pro
EOF
  exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "✗ jq 가 필요합니다. brew install jq" >&2
  exit 1
fi

# Keychain 에서 자격증명 추출 (raw 변수에만 보관, 어디에도 echo 하지 않음).
if ! raw=$(security find-generic-password -s "$KEYCHAIN_ITEM" -w 2>/dev/null); then
  cat >&2 <<EOF
✗ Keychain 에서 '$KEYCHAIN_ITEM' 을 못 찾았습니다.
  → 'claude' CLI 로 로그인했는지 확인 후 재시도.
EOF
  exit 1
fi

tier=$(printf '%s' "$raw" | jq -r '.claudeAiOauth.rateLimitTier // empty' 2>/dev/null || true)
unset raw  # 메모리에서 빠르게 비움.

case "$tier" in
  default_claude_max_20x) plan=max20 ;;
  default_claude_max_5x)  plan=max5  ;;
  default_claude_pro)     plan=pro   ;;
  '')
    echo "✗ rateLimitTier 필드가 비어있습니다. Claude Code 재로그인 후 재시도." >&2
    exit 1
    ;;
  *)
    echo "⚠ 알 수 없는 tier: $tier — 그대로 저장합니다 (ai-usage.sh 가 fallback 처리)." >&2
    plan="$tier"
    ;;
esac

mkdir -p "$CACHE_DIR"
printf '%s\n' "$plan" > "$CACHE"
echo "✓ 감지된 plan: $plan"
echo "  저장 위치: $CACHE"
