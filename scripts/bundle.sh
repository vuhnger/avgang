#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
VERSION="${VERSION:-0.0.0}"
BUILD="$(git rev-list --count HEAD)"
swift build -c release
BIN="$(swift build -c release --show-bin-path)/Avgang"
APP=build/Avgang.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$APP/Contents/Frameworks"
cp "$BIN" "$APP/Contents/MacOS/Avgang"
cp -R "$(find .build/artifacts -type d -path '*macos-arm64_x86_64/Sparkle.framework' | head -1)" "$APP/Contents/Frameworks/"
install_name_tool -add_rpath @executable_path/../Frameworks "$APP/Contents/MacOS/Avgang"
plutil -lint -s Resources/*.lproj/*.strings
cp -R Resources/en.lproj Resources/nb.lproj "$APP/Contents/Resources/"
xcrun actool Resources/AppIcon.icon --compile "$APP/Contents/Resources" \
    --output-format human-readable-text --notices --warnings --errors \
    --output-partial-info-plist build/icon-partial.plist \
    --app-icon AppIcon --include-all-app-icons \
    --target-device mac --minimum-deployment-target 26.0 --platform macosx >/dev/null
cat > "$APP/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key><string>en</string>
    <key>CFBundleLocalizations</key><array><string>en</string><string>nb</string></array>
    <key>CFBundleExecutable</key><string>Avgang</string>
    <key>CFBundleIconFile</key><string>AppIcon</string>
    <key>CFBundleIconName</key><string>AppIcon</string>
    <key>CFBundleIdentifier</key><string>com.vuhnger.avgang</string>
    <key>CFBundleName</key><string>Avgang</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>$VERSION</string>
    <key>CFBundleVersion</key><string>$BUILD</string>
    <key>LSMinimumSystemVersion</key><string>26.0</string>
    <key>LSUIElement</key><true/>
    <key>NSLocationUsageDescription</key><string>Avgang shows departures from the stops nearest you.</string>
    <key>NSLocationWhenInUseUsageDescription</key><string>Avgang shows departures from the stops nearest you.</string>
    <key>SUFeedURL</key><string>https://github.com/vuhnger/avgang/releases/latest/download/appcast.xml</string>
    <key>SUPublicEDKey</key><string>HXjoAWMKDG7bO+g2XxoV38lHvAlKoq5XJPBI8jvYzOA=</string>
    <key>SUEnableAutomaticChecks</key><true/>
    <key>SUAllowsAutomaticUpdates</key><false/>
</dict>
</plist>
EOF
SPK="$APP/Contents/Frameworks/Sparkle.framework/Versions/B"
for item in "$SPK"/XPCServices/*.xpc "$SPK/Autoupdate" "$SPK/Updater.app" "$APP/Contents/Frameworks/Sparkle.framework"; do
    codesign --force --sign - "$item"
done
codesign --force --sign - "$APP"
codesign --verify --deep --strict "$APP"
echo "$APP"
