#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MACOS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
APP_DIR="$MACOS_DIR/dist/HeiBan.app"

# App 與使用手冊共用 Release.json，避免只更新其中一份版本號。
read -r APP_VERSION APP_BUILD < <(python3 -c '
import json, re, sys
release = json.load(open(sys.argv[1], encoding="utf-8"))
assert re.fullmatch(r"[0-9]+\.[0-9]+\.[0-9]+", release["version"])
assert re.fullmatch(r"[0-9]+(?:\.[0-9]+)*", release["build"])
print(release["version"], release["build"])
' "$MACOS_DIR/Release.json")

swift "$SCRIPT_DIR/package_brand_icon.swift" "$MACOS_DIR"
iconutil -c icns "$MACOS_DIR/assets/branding/HeiBan.iconset" -o "$MACOS_DIR/assets/AppIcon.icns"

echo "🔨 Building HeiBanMac release binary..."
cd "$MACOS_DIR"
swift build -c release --product HeiBanMac

RELEASE_BIN="$MACOS_DIR/.build/release/HeiBanMac"
if [ ! -f "$RELEASE_BIN" ]; then
    RELEASE_BIN="$MACOS_DIR/.build/arm64-apple-macosx/release/HeiBanMac"
fi

echo "📦 Creating macOS App Bundle at $APP_DIR..."
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"

cp "$RELEASE_BIN" "$APP_DIR/Contents/MacOS/HeiBanMac"
chmod +x "$APP_DIR/Contents/MacOS/HeiBanMac"
for RESOURCE_BUNDLE in "$MACOS_DIR/.build/release/"*.bundle; do
    if [ -d "$RESOURCE_BUNDLE" ]; then
        cp -R "$RESOURCE_BUNDLE" "$APP_DIR/Contents/Resources/"
    fi
done

if [ -f "$MACOS_DIR/assets/AppIcon.icns" ]; then
    cp "$MACOS_DIR/assets/AppIcon.icns" "$APP_DIR/Contents/Resources/AppIcon.icns"
fi

cat << EOF > "$APP_DIR/Contents/Info.plist"
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
    <string>$APP_VERSION</string>
    <key>CFBundleVersion</key>
    <string>$APP_BUILD</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>UTExportedTypeDeclarations</key>
    <array><dict>
        <key>UTTypeIdentifier</key><string>com.bear.heiban.document</string>
        <key>UTTypeDescription</key><string>黑板可編輯作品</string>
        <key>UTTypeConformsTo</key><array><string>public.json</string></array>
        <key>UTTypeTagSpecification</key><dict>
            <key>public.filename-extension</key><array><string>heiban</string></array>
            <key>public.mime-type</key><string>application/vnd.heiban+json</string>
        </dict>
    </dict></array>
    <key>CFBundleDocumentTypes</key>
    <array><dict>
        <key>CFBundleTypeName</key><string>黑板可編輯作品</string>
        <key>CFBundleTypeRole</key><string>Editor</string>
        <key>LSHandlerRank</key><string>Owner</string>
        <key>CFBundleTypeIconFile</key><string>AppIcon</string>
        <key>LSItemContentTypes</key><array><string>com.bear.heiban.document</string></array>
    </dict></array>
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

# Seal the complete bundle instead of leaving the linker's executable-only
# signature (whose identifier was HeiBanMac and whose Info.plist was unbound).
# Set HEIBAN_SIGNING_IDENTITY to an Apple Development / Developer ID identity
# for builds that must retain broad TCC grants across executable changes.
codesign --force --sign "${HEIBAN_SIGNING_IDENTITY:--}" --identifier com.bear.HeiBan "$APP_DIR"
codesign --verify --strict "$APP_DIR"

touch "$APP_DIR"
# 使用者要求本機只留最新成品；只有完整封裝與簽章成功才清理舊版本。
python3 "$SCRIPT_DIR/cleanup_old_artifacts.py"
echo "✅ App bundle created successfully at: $APP_DIR"
echo "👉 You can run it with: open \"$APP_DIR\""
