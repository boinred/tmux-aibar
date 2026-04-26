#!/usr/bin/env bash
# tmux-aibar — Claude Code / Codex CLI 사용량을 tmux status bar 에 표시.
# tpm entry point. tpm 이 본 파일을 source 합니다.
#
# 사용자는 status-right 안에 #{aibar_status} 또는 직접 스크립트를 넣어 사용.
#
# 예:
#   set -g @plugin 'boinred/tmux-aibar'
#   set -ag status-right "#{aibar_status}"

CURRENT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Format string interpolation — status-right 안에서 #{aibar_status} 로 사용.
tmux set-option -gq "@aibar_status" "#(${CURRENT_DIR}/scripts/ai-usage.sh)"

# 사용자 편의를 위한 alias 도 등록 (취향에 맞게 둘 중 하나 사용).
tmux set-option -gq "@aibar_module" "#(${CURRENT_DIR}/scripts/ai-usage.sh)"
