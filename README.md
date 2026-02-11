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
│ Sign Out                 │
│ Notifications        ✓   │
├──────────────────────────┤
│ Quit                     │
└──────────────────────────┘
```

## Features

- Usage percentage in menu bar with color-coded indicator (○ ◔ ◑ ◕ ●)
- Time until quota resets (5-hour rolling window)
- Auto-refreshes every 10 minutes
- macOS notifications at 50%, 80%, and 90% usage thresholds
- Notification when quota resets
- Toggle notifications on/off from the menu
- In-app sign in via embedded browser (no manual cookie copying)
- Session key stored in macOS Keychain

## Requirements

- macOS 13+
- Claude Pro subscription
- Xcode (`xcode-select -s /Applications/Xcode.app/Contents/Developer`)

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

1. Click the Claudacity menu bar icon → **Sign In to Claude...**
2. A browser window opens — log in with your email or Google account
3. The window closes automatically and your usage appears
4. On first launch, allow notifications when prompted

> **Note:** If your session expires (you see ⚠️), just sign in again.

## Security

- Session key stored in encrypted macOS Keychain
- Only connects to `claude.ai` API
- No analytics, telemetry, or third-party services
- [View source code](Sources/Claudacity) — it's ~200 lines

## Uninstall

1. Quit the app
2. Delete `Claudacity.app`
3. (Optional) Open **Keychain Access**, search "claudacity", delete entry

## License

MIT

---

Built with [Claude Code](https://claude.ai/code)
