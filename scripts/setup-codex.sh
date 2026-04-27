#!/usr/bin/env bash
# tmux-aibar — Codex 사용량 표시 setup wizard.
#
# 무엇을 자동 처리하나:
#   1) Codex CLI 설치/인증 상태 감지
#   2) ChatGPT 모드면: 한계 안내 (LaunchAgent 불필요)
#   3) apikey 모드면: 기존 Admin key 검증 → invalid 면 새 key 받아 Keychain 저장
#   4) LaunchAgent 등록 (apikey 모드)
#
# 사용법:
#   ~/.tmux/plugins/tmux-aibar/scripts/setup-codex.sh
#
# 보안 노트:
#   - Admin key 입력은 read -rs 로 화면에 표시되지 않습니다.
#   - 검증/저장 외 어디에도 key 본문을 echo 하지 않습니다.

set -euo pipefail

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

KEYCHAIN_SERVICE="${AIBAR_KEYCHAIN_SERVICE:-openai-admin-key}"
KEYCHAIN_ACCOUNT="${AIBAR_KEYCHAIN_ACCOUNT:-${USER}}"
AUTH_FILE="$HOME/.codex/auth.json"

if [[ "$(uname -s)" != "Darwin" ]]; then
  cat >&2 <<'EOF'
✗ 본 wizard 는 macOS Keychain 전용입니다.
  Linux 사용자는 OPENAI_ADMIN_KEY 환경변수와 systemd timer 로
  refresh-codex-usage.sh 를 1 분마다 실행하는 패턴을 사용하세요.
EOF
  exit 1
fi

for cmd in jq curl security; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "✗ '$cmd' 가 필요합니다. (brew install $cmd)" >&2
    exit 1
  fi
done

# 검증 helper — 1시간짜리 작은 윈도우로 빠르게 ping.
verify_admin_key() {
  local key="$1"
  local since
  since=$(date -u -v-1H +%s 2>/dev/null || date -u -d '1 hour ago' +%s 2>/dev/null || echo 0)
  local resp
  resp=$(curl -s --max-time 8 \
    "https://api.openai.com/v1/organization/usage/completions?start_time=${since}&bucket_width=1h" \
    -H "Authorization: Bearer ${key}" -H "Content-Type: application/json")
  echo "$resp"
}

# ---- 1) Codex CLI / auth.json 확인 -----------------------------------------
if ! command -v codex >/dev/null 2>&1; then
  echo "ℹ Codex CLI 가 설치되어 있지 않습니다. 본 wizard 는 종료합니다."
  echo "  Codex 를 안 쓰시면 그대로 두셔도 Claude pill 은 정상 동작합니다."
  exit 0
fi

CODEX_VER=$(codex --version 2>/dev/null || echo "unknown")
echo "→ Codex CLI 감지: $CODEX_VER"

if [[ ! -r "$AUTH_FILE" ]]; then
  echo "⚠ ~/.codex/auth.json 이 없습니다. 'codex login' 으로 먼저 로그인 후 재실행." >&2
  exit 1
fi

AUTH_MODE=$(jq -r '.auth_mode // "unknown"' "$AUTH_FILE")
echo "→ auth_mode: $AUTH_MODE"
echo

# ---- 2) ChatGPT 모드 분기 ---------------------------------------------------
case "$AUTH_MODE" in
  chatgpt)
    cat <<'EOF'
ℹ ChatGPT 모드 감지

  ChatGPT subscription (Plus/Pro/Business) 은 OpenAI Platform Usage API 와
  별개의 결제 시스템이라, 토큰 사용량을 외부에서 조회할 수 없습니다.

  → tmux-aibar 의 Codex pill 은 다음과 같이 표시됩니다:
       🦊 Codex          (codex 가 active pane 에 있을 때만, 숫자 없음)

  이 모드에서는 LaunchAgent / Admin key 가 불필요합니다.

EOF
    read -rp "그래도 LaunchAgent 를 등록하시겠어요? (Platform 사용량도 따로 보고 싶을 때만) [y/N]: " ans
    case "${ans:-}" in
      y|Y|yes|Yes|YES) ;;
      *) echo "→ 종료. ChatGPT 모드로 정상 동작합니다."; exit 0 ;;
    esac
    ;;
  apikey)
    echo "✓ apikey 모드 — Admin key 등록 진행"
    echo
    ;;
  *)
    echo "⚠ 알 수 없는 auth_mode: $AUTH_MODE"
    read -rp "그래도 진행하시겠어요? [y/N]: " ans
    case "${ans:-}" in y|Y|yes|Yes|YES) ;; *) exit 0 ;; esac
    ;;
esac

# ---- 3) Admin key 검증 / 등록 ------------------------------------------------
KEY_OK=0
existing=$(security find-generic-password -a "$KEYCHAIN_ACCOUNT" -s "$KEYCHAIN_SERVICE" -w 2>/dev/null || true)

if [[ -n "$existing" ]]; then
  echo "→ Keychain 에 기존 key 발견. 유효성 검증..."
  resp=$(verify_admin_key "$existing")
  unset existing
  if echo "$resp" | jq -e 'has("data")' >/dev/null 2>&1; then
    echo "  ✓ 기존 key 정상."
    KEY_OK=1
  elif echo "$resp" | jq -e '.error.code == "invalid_api_key"' >/dev/null 2>&1; then
    echo "  ✗ 기존 key 가 invalid (revoked 또는 expired). 새 key 가 필요합니다."
  else
    err=$(echo "$resp" | jq -r '.error.message // "unknown"')
    echo "  ⚠ 검증 중 다른 에러: $err"
  fi
fi

if [[ "$KEY_OK" -ne 1 ]]; then
  cat <<'EOF'

→ Admin key 발급 안내:
    1) https://platform.openai.com/settings/organization/admin-keys
    2) [+ Create admin key] 클릭
    3) name 자유 (예: tmux-aibar), scope 는 [api.usage.read] 만 체크해도 충분
    4) sk-admin-... 키 복사
    5) 아래에 붙여넣기 (입력 시 화면에 표시 안 됨)
EOF
  read -rsp "Admin key: " new_key
  echo

  if [[ ! "$new_key" =~ ^sk-admin- ]]; then
    echo "✗ sk-admin- 으로 시작하지 않습니다. (Project key sk-proj-... 는 사용 불가)" >&2
    unset new_key
    exit 1
  fi

  resp=$(verify_admin_key "$new_key")
  if ! echo "$resp" | jq -e 'has("data")' >/dev/null 2>&1; then
    err=$(echo "$resp" | jq -r '.error.message // "unknown"')
    echo "✗ 검증 실패: $err" >&2
    unset new_key
    exit 1
  fi

  security add-generic-password -U \
    -a "$KEYCHAIN_ACCOUNT" -s "$KEYCHAIN_SERVICE" -w "$new_key" 2>/dev/null
  unset new_key
  echo "✓ Keychain 저장 완료 (service=$KEYCHAIN_SERVICE, account=$KEYCHAIN_ACCOUNT)"
fi

# ---- 4) LaunchAgent 설치 ----------------------------------------------------
echo
echo "→ LaunchAgent 설치 (1 분마다 자동 갱신)"
"$DIR/install-launchagent.sh"
