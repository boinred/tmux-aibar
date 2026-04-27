# tmux-aibar

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![tpm](https://img.shields.io/badge/tpm-compatible-green)](https://github.com/tmux-plugins/tpm)
[![macOS](https://img.shields.io/badge/macOS-14%2B-lightgrey)](https://www.apple.com/macos)

> Show **Claude Code** / **Codex** CLI usage in your tmux status bar — auto-detects which AI is running in the active pane.

`tmux-aibar` watches the foreground process tree of your active pane and renders a Catppuccin-style pill with **tokens, cost, and daily quota** for whichever AI CLI you're currently using.

```
... 13.0% | 75.0% | 🤖 Claude 12%        | 🔋 85% | 04/26 12:45    ← Claude, plan 인식됨
... 13.0% | 75.0% | 🤖 Claude $0.42 (8k) | 🔋 85% | 04/26 12:45    ← Claude, plan 미설정
... 13.0% | 75.0% | 🦊 Codex 142k today  | 🔋 85% | 04/26 12:45    ← Codex, apikey 모드
... 13.0% | 75.0% | 🦊 Codex             | 🔋 85% | 04/26 12:45    ← Codex, ChatGPT 모드 (숫자 N/A)
... 13.0% | 75.0% |                      | 🔋 85% | 04/26 12:45    ← 둘 다 안 떠 있을 때
```

## Features

- 🔍 **Auto-detect** — no wrappers, no env vars; reads the active pane's process tree
- 🤖 **Claude Code** support via [`ccusage`](https://github.com/ryoppippi/ccusage) — shows the **active 5-hour block's API-equivalent cost as a % of your plan price** (`pro $20`, `max5 $100`, `max20 $200`). Plan is auto-detected from Claude Code's keychain credentials; falls back to `$cost (Nk)` if plan is unknown.
- 🦊 **Codex** support — auto-detects `auth_mode` from `~/.codex/auth.json`:
  - `apikey` 모드 (OpenAI Platform 결제) → 일일 토큰 수 표시 (Admin Usage API, 60s 캐시)
  - `chatgpt` 모드 (ChatGPT Plus/Pro 등 구독 결제) → ChatGPT/Platform 결제가 분리되어 있어 사용량은 표시 불가, 라벨만 보입니다
- 🔐 **macOS Keychain** integration — keep your `sk-admin-*` key out of plaintext
- 🎨 **Catppuccin-friendly pill** — colors fully overridable via tmux options

---

## Install

### 1) Plugin (via [tpm](https://github.com/tmux-plugins/tpm))

```tmux
# ~/.tmux.conf
set -g @plugin 'boinred/tmux-aibar'

# 원하는 위치에 모듈 삽입 (예: RAM 옆)
set -ag status-right "#{aibar_status}"
```

`prefix + I` (tpm install) → reload tmux config.

### 2) Claude usage — `ccusage` 설치 + plan 자동 감지

Claude Code 사용량을 표시하려면:

```bash
# (a) ccusage 설치
bun  i -g ccusage    # 또는
npm  i -g ccusage

# (b) plan 자동 감지 — 한 번만 실행 (Keychain 에서 추출 → cache/claude-plan.txt)
~/.tmux/plugins/tmux-aibar/scripts/detect-claude-plan.sh
```

ccusage 가 없으면 `🤖 Claude (install ccusage)` 로 표시됩니다.
plan 감지 실패 또는 Linux 사용자는 manual 설정도 가능:

```tmux
set -g @aibar_claude_plan "max20"   # 또는 "max5" / "pro"
```

> **plan 정보는 어디서 올까?**
> Claude Code 의 OAuth 자격증명 (`security find-generic-password -s 'Claude Code-credentials'`) 안의 `rateLimitTier` 필드를 1회 읽어 캐시합니다. 자격증명 token 자체는 절대 출력/저장하지 않습니다.

### 3) Codex usage — `setup-codex.sh` 한 번 실행 (선택)

```bash
~/.tmux/plugins/tmux-aibar/scripts/setup-codex.sh
```

이 wizard 가 본인 환경을 감지해서 알아서 분기합니다:

| `~/.codex/auth.json` 의 `auth_mode` | wizard 동작 | pill 표시 |
|---|---|---|
| `chatgpt` (ChatGPT Plus/Pro/Business 구독) | "사용량 조회 불가" 안내, LaunchAgent 등록 안 함 (default) | `🦊 Codex` (라벨만) |
| `apikey` (Platform `sk-…` key 인증) | 기존 Admin key 검증 → invalid 면 새 key 입력 → Keychain 저장 → LaunchAgent 등록 | `🦊 Codex 142k today` |
| (Codex 미설치) | 메시지 후 종료 | (안 그려짐) |

검증/저장 외에 Admin key 본문은 어디에도 echo 되지 않습니다 (`read -rs` 로 입력).

> **왜 cron 이 아니라 launchd?**
> macOS 의 cron 은 GUI 세션과 분리되어 Keychain 접근이 차단됩니다. LaunchAgent 는 사용자 세션 안에서 실행되어 자연스럽게 Keychain 을 풀 수 있습니다.

---

## Configuration

모든 옵션은 `~/.tmux.conf` 에서 override 가능합니다 (값은 모두 기본값).

| Option | Default | 설명 |
|---|---|---|
| `@aibar_pill_bg`        | `#313244`  | pill 배경 (catppuccin surface0) |
| `@aibar_claude_fg`      | `#cba6f7`  | Claude 글자색 (catppuccin mauve) |
| `@aibar_codex_fg`       | `#fab387`  | Codex 글자색 (catppuccin peach) |
| `@aibar_claude_label`   | `🤖 Claude`| Claude 라벨 |
| `@aibar_codex_label`    | `🦊 Codex` | Codex 라벨 |
| `@aibar_claude_plan`    | (auto)     | `pro` / `max5` / `max20`. 비워두면 `cache/claude-plan.txt` 자동 사용. 둘 다 없으면 `$cost (Nk)` fallback. |
| `@aibar_cache_dir`      | 플러그인 폴더의 `cache/` | 캐시 위치 |

예 (Dracula 테마 색):

```tmux
set -g @aibar_pill_bg   "#44475a"
set -g @aibar_claude_fg "#bd93f9"
set -g @aibar_codex_fg  "#ffb86c"
```

### 환경변수 (refresh 스크립트용)

| Env | Default | 설명 |
|---|---|---|
| `OPENAI_ADMIN_KEY`      | (없음)            | 직접 지정 시 Keychain 조회 생략 |
| `AIBAR_KEYCHAIN_SERVICE`| `openai-admin-key`| Keychain item service 이름 |
| `AIBAR_KEYCHAIN_ACCOUNT`| `$USER`           | Keychain item account 이름 |
| `AIBAR_CACHE_DIR`       | 플러그인 `cache/` | 캐시 디렉토리 |

---

## How detection works

1. `tmux display-message -p '#{pane_pid}'` 로 active pane 의 root PID 획득
2. `pgrep -P` 를 재귀적으로 돌려 **자식 프로세스 트리 전체** 수집
3. `ps -o args=` 로 풀 명령라인 검사 → `claude` / `codex` 패턴 매칭

→ Claude Code 가 `node /opt/homebrew/.../claude/cli.js` 로 떠 있어도 정확히 잡힙니다.

---

## Troubleshooting

### Codex pill 의 sentinel 별 의미

| pill | 원인 | 해결 |
|---|---|---|
| `🦊 Codex` (숫자 없음) | `auth.json` 이 `chatgpt` 모드 | 정상 — ChatGPT/Platform 결제 분리 한계. Platform 사용량을 보려면 Admin key 환경 별도 구성. |
| `🦊 Codex (setup)` | Keychain 에 admin key 가 없음 | `setup-codex.sh` 실행 |
| `🦊 Codex (key invalid)` | Admin key 가 OpenAI 측에서 거부 (revoked/expired) | `setup-codex.sh` 재실행 → 새 key 입력 |
| `🦊 Codex (api error)` | invalid_api_key 외 다른 API 에러 (네트워크/스코프 등) | `cat ~/.tmux/plugins/tmux-aibar/cache/codex-usage.log` 로 raw 응답 확인 |
| `🦊 Codex 0k today` (실제로는 사용 중인데) | 집계 지연 (~30분), 또는 키가 다른 organization | 30분 후 재확인 / `setup-codex.sh` 로 검증 |

LaunchAgent 직접 진단:
```bash
launchctl print gui/$(id -u)/com.tmux-aibar.codex-usage | head -20
launchctl kickstart -k gui/$(id -u)/com.tmux-aibar.codex-usage   # 즉시 실행
```

처음 실행 시 macOS 가 "tmux-aibar 가 keychain item 에 접근하려 합니다" prompt 를 띄울 수 있습니다 → **항상 허용** 클릭.

### Claude pane 인데 모듈이 안 뜸

```bash
# 직접 실행해서 어떻게 잡히는지 확인
~/.tmux/plugins/tmux-aibar/scripts/ai-usage.sh

# 프로세스 트리 확인
ps -o args= -p $(pgrep -P $(tmux display-message -p '#{pane_pid}'))
```

특이한 wrapper(예: `aichat`, `claude-cli` fork)를 쓰신다면 [`ai-usage.sh`](scripts/ai-usage.sh) 의 정규식만 살짝 조정하면 됩니다 — issue 남겨주세요.

### 모듈을 더 자주 갱신하고 싶음

```tmux
set -g status-interval 5    # 기본 15 초 → 5 초
```

스크립트가 가벼워서 (네트워크 호출 없음, 캐시 cat 만) 부담 없습니다.

---

## Project layout

```
tmux-aibar/
├── aibar.tmux                          # tpm entry point
├── scripts/
│   ├── ai-usage.sh                     # 메인 모듈 (status-right 에 호출됨)
│   ├── helpers.sh                      # tmux 옵션 읽기 유틸
│   ├── refresh-codex-usage.sh          # OpenAI API → 캐시 갱신
│   ├── detect-claude-plan.sh           # Claude plan auto-detect (Keychain → cache)
│   ├── setup-codex.sh                  # Codex onboarding wizard (auth_mode 감지 + key 검증)
│   └── install-launchagent.sh          # LaunchAgent 자동 설치
├── launchagents/
│   └── codex-usage.plist.template      # macOS LaunchAgent 템플릿
└── cache/                              # 런타임 캐시 (gitignore)
```

---

## Why a separate plugin?

- [`ccusage`](https://github.com/ryoppippi/ccusage) 는 훌륭한 Claude 분석 CLI 지만 tmux 통합은 안 함
- 기존 `tmux-cpu` / `tmux-battery` 패턴을 따라가면 누구나 `set -g @plugin` 한 줄로 끝
- Active pane 감지 + Codex 동시 지원은 다른 플러그인에 없는 차별점

---

## License

[MIT](LICENSE) © boinred

## Acknowledgements

- [tmux-plugins/tpm](https://github.com/tmux-plugins/tpm)
- [ryoppippi/ccusage](https://github.com/ryoppippi/ccusage)
- [catppuccin/tmux](https://github.com/catppuccin/tmux)
