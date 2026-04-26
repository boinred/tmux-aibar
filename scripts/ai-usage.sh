#!/usr/bin/env bash
# tmux-aibar 메인 모듈.
#
# 현재 active pane 의 프로세스 트리를 검사해서:
#   - claude  떠 있으면 → ccusage 로 비용/토큰 표시 (mauve pill)
#   - codex   떠 있으면 → 캐시 파일 (refresh-codex-usage.sh) 표시 (peach pill)
#   - 둘 다 없으면     → 빈 출력 (모듈 자체가 안 그려짐)
#
# tmux 옵션으로 색상·캐시 위치 등을 override 할 수 있습니다 (README 참고).

set -u

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
# shellcheck source=helpers.sh
source "$DIR/helpers.sh"

# ---- options (tmux set -g @aibar_xxx ...) ----
PILL_BG=$(tmux_get   "@aibar_pill_bg"    "#313244")  # catppuccin surface0
CLAUDE_FG=$(tmux_get "@aibar_claude_fg"  "#cba6f7")  # mauve
CODEX_FG=$(tmux_get  "@aibar_codex_fg"   "#fab387")  # peach
CACHE_DIR=$(tmux_get "@aibar_cache_dir"  "$(aibar_root)/cache")
CLAUDE_LABEL=$(tmux_get "@aibar_claude_label" "🤖 Claude")
CODEX_LABEL=$(tmux_get  "@aibar_codex_label"  "🦊 Codex")

# ---- detect AI process in active pane ----
pane_pid=$(tmux display-message -p '#{pane_pid}' 2>/dev/null || true)
[[ -z "${pane_pid:-}" ]] && exit 0

collect() {
  local p=$1
  echo "$p"
  for c in $(pgrep -P "$p" 2>/dev/null); do
    collect "$c"
  done
}
pids=$(collect "$pane_pid" | tr '\n' ' ')
cmds=$(ps -o args= -p $pids 2>/dev/null || true)

pill() {
  # $1=fg, $2=text
  printf '#[bg=default] #[fg=%s,bg=%s] %s #[bg=default]' "$1" "$PILL_BG" "$2"
}

# ---- Claude ----
if echo "$cmds" | grep -Eqi '(/|^)claude([[:space:]]|$)|claude/cli|claude-code'; then
  runner=""
  if command -v ccusage >/dev/null 2>&1; then runner="ccusage"
  elif command -v bunx   >/dev/null 2>&1; then runner="bunx ccusage"
  elif command -v npx    >/dev/null 2>&1; then runner="npx -y ccusage"
  fi

  if [[ -n "$runner" ]]; then
    json=$($runner blocks --active --json 2>/dev/null || echo '{}')
    cost=$(echo "$json" | jq -r '.blocks[0].costUSD // 0' 2>/dev/null || echo 0)
    tok=$(echo  "$json" | jq -r '.blocks[0].tokenCounts.totalTokens // 0' 2>/dev/null || echo 0)
    text=$(printf '%s $%.2f (%dk)' "$CLAUDE_LABEL" "$cost" "$((tok/1000))")
  else
    text="$CLAUDE_LABEL (install ccusage)"
  fi
  pill "$CLAUDE_FG" "$text"
  exit 0
fi

# ---- Codex ----
if echo "$cmds" | grep -Eqi '(/|^)codex([[:space:]]|$)|/codex/'; then
  cache="$CACHE_DIR/codex-usage.txt"
  if [[ -r "$cache" ]]; then
    text="$CODEX_LABEL $(cat "$cache")"
  else
    text="$CODEX_LABEL (no cache — see README)"
  fi
  pill "$CODEX_FG" "$text"
  exit 0
fi

# 둘 다 없으면 빈 출력 (status-right 에서 모듈이 사라짐).
exit 0
