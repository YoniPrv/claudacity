# Claudacity

A minimal macOS menu bar app that displays your Claude Pro usage.

```
◑ 44%  ← Menu bar
┌──────────────────────────┐
│ Claude Pro Usage         │
├──────────────────────────┤
│ Used: 44%                │
│ Resets: 3h 12m (6:45 PM) │
├──────────────────────────┤
│ Refresh                  │
│ Set Session Key...       │
├──────────────────────────┤
│ Quit                     │
└──────────────────────────┘
```

## Features

- Usage percentage in menu bar with visual indicator (○ ◔ ◑ ◕ ●)
- Time until quota resets (5-hour rolling window)
- Auto-refreshes every 10 minutes
- Session key stored in macOS Keychain

## Requirements

- macOS 13+
- Claude Pro subscription
- Xcode Command Line Tools (`xcode-select --install`)

## Install

```bash
git clone https://github.com/YoniPrv/claudacity.git
cd claudacity
./build.sh
open Claudacity.app
```

To keep it running, copy to Applications:
```bash
cp -r Claudacity.app /Applications/
```

## Setup

1. Log into [claude.ai](https://claude.ai) in Safari
2. Open Developer Tools: `Cmd + Option + I`
3. Go to **Storage** tab → **Cookies** → click on `claude.ai`
4. Find `sessionKey` row and copy the **Value** (starts with `sk-ant-`)
5. Click Claudacity menu bar icon → **Set Session Key...** → paste → OK

> **Note:** Session keys expire periodically. If you see ⚠️, repeat the setup steps.

## Security

- Session key stored in encrypted macOS Keychain
- Only connects to `claude.ai` API
- No analytics, telemetry, or third-party services
- [View source code](Sources/Claudacity) — it's ~150 lines

## Uninstall

1. Quit the app
2. Delete `Claudacity.app`
3. (Optional) Open **Keychain Access**, search "claudacity", delete entry

## License

MIT

---

Built with [Claude Code](https://claude.ai/code)
