# tmux-aibar

> Show **Claude Code** / **Codex** CLI usage in your tmux status bar — auto-detects which AI is running in the active pane.

`tmux-aibar` watches the foreground process tree of your active pane and renders a Catppuccin-style pill with **tokens, cost, and daily quota** for whichever AI CLI you're currently using.

```
... 13.0% | 75.0% | 🤖 Claude $0.42 (8k) | 🔋 85% | 04/26 12:45
... 13.0% | 75.0% | 🦊 Codex 142k today  | 🔋 85% | 04/26 12:45
... 13.0% | 75.0% |                      | 🔋 85% | 04/26 12:45    ← 둘 다 안 떠 있을 때
```

## Features

- 🔍 **Auto-detect** — no wrappers, no env vars; reads the active pane's process tree
- 🤖 **Claude Code** support via [`ccusage`](https://github.com/ryoppippi/ccusage) (local transcript parsing, no network)
- 🦊 **Codex** support via OpenAI Admin Usage API (cached every 60s, no rate-limit risk)
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

### 2) Claude usage — `ccusage` 설치 (선택)

Claude Code 사용량을 표시하려면:

```bash
bun  i -g ccusage    # 또는
npm  i -g ccusage
```

설치 안 하면 `🤖 Claude (install ccusage)`로 표시됩니다.

### 3) Codex usage — Admin Key + LaunchAgent (선택)

Codex 사용량을 표시하려면 **OpenAI Organization Admin Key**(read-only `api.usage.read` scope만 필요)가 필요합니다.

```bash
# (a) Keychain 에 키 저장 — 평문 export 불필요
security add-generic-password -U -a "$USER" -s openai-admin-key -w
# 프롬프트에 sk-admin-... 키 입력

# (b) 1 분마다 자동 갱신하는 LaunchAgent 설치
~/.tmux/plugins/tmux-aibar/scripts/install-launchagent.sh
```

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
| `@aibar_cache_dir`      | 플러그인 폴더의 `cache/` | Codex 캐시 위치 |

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

### `(no key)` 가 계속 표시됨

LaunchAgent 가 Keychain 접근에 실패한 경우입니다:

```bash
cat ~/.tmux/plugins/tmux-aibar/cache/codex-usage.err
launchctl print gui/$(id -u)/com.tmux-aibar.codex-usage | head -20
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
