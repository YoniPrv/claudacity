# Claudacity

A minimal macOS menu bar app that displays your Claude Pro usage.

## Features

- Shows usage percentage in menu bar (○ ◔ ◑ ◕ ●)
- Displays time until quota resets
- Auto-refreshes every 10 minutes
- Session key stored securely in macOS Keychain

## Install

```bash
./build.sh
open Claudacity.app
```

Requires macOS 13+ and Xcode Command Line Tools.

## Setup

1. Click menu bar icon → **Set Session Key...**
2. Get key from [claude.ai](https://claude.ai): `Cmd+Opt+I` → Storage → Cookies → `sessionKey`
3. Paste and click OK

## Security

- Credentials stored in encrypted Keychain
- Only connects to claude.ai
- No telemetry

## Uninstall

Delete `Claudacity.app`. Optionally remove Keychain entry via Keychain Access (search "claudacity").

## License

MIT
