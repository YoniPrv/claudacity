#!/bin/bash
set -e
cd "$(dirname "$0")"

echo "Building Claudacity..."
swift build -c release

echo "Creating app bundle..."
rm -rf Claudacity.app
mkdir -p Claudacity.app/Contents/{MacOS,Resources}
cp .build/release/Claudacity Claudacity.app/Contents/MacOS/

cat > Claudacity.app/Contents/Info.plist << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key><string>Claudacity</string>
    <key>CFBundleIdentifier</key><string>com.local.claudacity</string>
    <key>CFBundleName</key><string>Claudacity</string>
    <key>CFBundleVersion</key><string>1.0</string>
    <key>LSMinimumSystemVersion</key><string>13.0</string>
    <key>LSUIElement</key><true/>
</dict>
</plist>
EOF

echo "Done: Claudacity.app"
echo "Run: open Claudacity.app"
