#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MACOS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
APP_DIR="$MACOS_DIR/dist/HeiBan.app"

echo "🔨 Building HeiBanMac release binary..."
cd "$MACOS_DIR"
swift build -c release

RELEASE_BIN="$MACOS_DIR/.build/release/HeiBanMac"
if [ ! -f "$RELEASE_BIN" ]; then
    RELEASE_BIN="$MACOS_DIR/.build/arm64-apple-macosx/release/HeiBanMac"
fi

echo "📦 Creating macOS App Bundle at $APP_DIR..."
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"

cp "$RELEASE_BIN" "$APP_DIR/Contents/MacOS/HeiBanMac"
chmod +x "$APP_DIR/Contents/MacOS/HeiBanMac"

if [ -f "$MACOS_DIR/assets/AppIcon.icns" ]; then
    cp "$MACOS_DIR/assets/AppIcon.icns" "$APP_DIR/Contents/Resources/AppIcon.icns"
fi

cat << 'EOF' > "$APP_DIR/Contents/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>zh_TW</string>
    <key>CFBundleExecutable</key>
    <string>HeiBanMac</string>
    <key>CFBundleIdentifier</key>
    <string>com.bear.HeiBan</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>HeiBan 黑板</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSSupportsAutomaticGraphicsSwitching</key>
    <true/>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
</dict>
</plist>
EOF

touch "$APP_DIR"
echo "✅ App bundle created successfully at: $APP_DIR"
echo "👉 You can run it with: open \"$APP_DIR\""
