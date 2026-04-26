#!/usr/bin/env bash
# Codex 사용량 갱신용 LaunchAgent 를 설치하는 헬퍼.
#
# 동작:
#   1) ~/Library/LaunchAgents/com.tmux-aibar.codex-usage.plist 생성 (템플릿 치환)
#   2) launchctl bootstrap 으로 등록
#   3) 즉시 한 번 실행 (kickstart)
#   4) 결과 캐시 출력

set -euo pipefail

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PLUGIN_ROOT="$( cd "$DIR/.." && pwd )"
TEMPLATE="$PLUGIN_ROOT/launchagents/codex-usage.plist.template"
TARGET="$HOME/Library/LaunchAgents/com.tmux-aibar.codex-usage.plist"
LABEL="com.tmux-aibar.codex-usage"

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "✗ 이 스크립트는 macOS 전용입니다."
  echo "  Linux 사용자는 systemd timer 로 refresh-codex-usage.sh 를 1 분마다 실행하세요."
  exit 1
fi

mkdir -p "$(dirname "$TARGET")"

echo "→ 템플릿을 $TARGET 으로 치환 후 저장"
sed "s|REPLACE_PLUGIN_DIR|$PLUGIN_ROOT|g; s|REPLACE_USER|$USER|g" \
  "$TEMPLATE" > "$TARGET"

echo "→ 기존 등록이 있으면 제거 (idempotent)"
launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null && echo "  (기존 unload)" || echo "  (기존 등록 없음)"

echo "→ bootstrap"
launchctl bootstrap "gui/$(id -u)" "$TARGET"

echo "→ 즉시 한 번 강제 실행"
launchctl kickstart -k "gui/$(id -u)/$LABEL"

sleep 2
echo
echo "=== 결과 ==="
echo "캐시: $(cat "$PLUGIN_ROOT/cache/codex-usage.txt" 2>/dev/null || echo '(없음)')"
err="$PLUGIN_ROOT/cache/codex-usage.err"
if [[ -s "$err" ]]; then
  echo
  echo "⚠ stderr 에 메시지가 있습니다:"
  cat "$err"
fi

cat <<EOF

✓ 설치 완료. 매 60 초마다 자동 갱신됩니다.

운영 명령어:
  즉시 실행 : launchctl kickstart -k gui/\$(id -u)/$LABEL
  상태 확인 : launchctl print  gui/\$(id -u)/$LABEL | head -20
  중지     : launchctl bootout gui/\$(id -u)/$LABEL
  재시작   : $0
EOF
