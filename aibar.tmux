#!/usr/bin/env bash
# tmux-aibar — Claude Code / Codex CLI 사용량을 tmux status bar 에 표시.
# tpm entry point. tpm 이 본 파일을 실행합니다.
#
# 사용 예 (~/.tmux.conf):
#   set -g @plugin 'boinred/tmux-aibar'
#   set -ag status-right "#{aibar_status}"
#
# status-left / status-right 안의 placeholder 를 실제 명령으로 치환합니다.
#   #{aibar_status}  →  #(<plugin>/scripts/ai-usage.sh)
#   #{aibar_module}  →  alias 동일
# (tmux-cpu / tmux-battery 와 동일 패턴.)

CURRENT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

aibar_command="#(${CURRENT_DIR}/scripts/ai-usage.sh)"

aibar_interpolate() {
  local placeholder="$1"
  local replacement="$2"
  local option current updated
  for option in status-left status-right; do
    current=$(tmux show-option -gqv "$option")
    updated="${current//$placeholder/$replacement}"
    if [[ "$current" != "$updated" ]]; then
      tmux set-option -gq "$option" "$updated"
    fi
  done
}

aibar_interpolate "#{aibar_status}" "$aibar_command"
aibar_interpolate "#{aibar_module}" "$aibar_command"
