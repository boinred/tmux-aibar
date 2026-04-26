#!/usr/bin/env bash
# tmux 옵션 읽기 + 공통 유틸. 다른 스크립트에서 source 해서 사용.

# tmux 옵션을 읽되, 없으면 기본값.
#   $1 = option name (예: "@aibar_claude_fg")
#   $2 = default value
tmux_get() {
  local opt=$1
  local def=$2
  local val
  val=$(tmux show-option -gqv "$opt" 2>/dev/null)
  echo "${val:-$def}"
}

# 플러그인 루트 (이 helpers 가 위치한 폴더의 부모).
aibar_root() {
  local self
  self="${BASH_SOURCE[0]}"
  cd "$(dirname "$self")/.." && pwd
}
