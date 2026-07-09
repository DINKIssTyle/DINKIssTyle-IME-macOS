#!/bin/bash
set -e

APP_DIR="build/IMETester.app"
CONTENTS="$APP_DIR/Contents"
MACOS="$CONTENTS/MacOS"

mkdir -p "$MACOS"

clang -mmacosx-version-min=10.15 \
  -framework Cocoa -framework WebKit -framework ApplicationServices \
  -o "$MACOS/IMETester" \
  Sources_Tester/IMETester.m \
  Sources/DKSTKeyMap.m \
  Sources/DKSTHangul.m

cat > "$CONTENTS/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key>
  <string>IMETester</string>
  <key>CFBundleIdentifier</key>
  <string>com.dinkisstyle.inputmethod.DKST.imetester</string>
  <key>CFBundleName</key>
  <string>DKST IME Tester</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>LSMinimumSystemVersion</key>
  <string>10.15</string>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
</dict>
</plist>
EOF

echo "Signing $APP_DIR with stable designated requirement..."
codesign --force --sign - --requirements '=designated => identifier "com.dinkisstyle.inputmethod.DKST.imetester"' "$APP_DIR"

echo "Built $APP_DIR"
