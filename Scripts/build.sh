#!/bin/bash
set -e

cd "$(dirname "$0")/.."

APP_NAME="Dclean"
BUILD_DIR=".build/arm64-apple-macosx/debug"
APP_BUNDLE="${APP_NAME}.app"

echo "=== 1. 编译 ==="
swift build 2>&1

echo "=== 2. 创建 .app 结构 ==="
rm -rf "${APP_BUNDLE}"
mkdir -p "${APP_BUNDLE}/Contents/MacOS"
mkdir -p "${APP_BUNDLE}/Contents/Resources"

echo "=== 3. 复制文件 ==="
cp "${BUILD_DIR}/${APP_NAME}" "${APP_BUNDLE}/Contents/MacOS/"
mkdir -p "${APP_BUNDLE}/Contents/Resources/Assets"
cp "Sources/Dclean/Resources/Assets/UI.html" "${APP_BUNDLE}/Contents/Resources/Assets/UI.html"

# 尝试多个位置查找 speedtest
SP_BIN=""
for p in "/usr/local/bin/speedtest" "/opt/homebrew/bin/speedtest"; do
    [ -f "$p" ] && { SP_BIN="$p"; break; }
done
if [ -n "$SP_BIN" ]; then
    cp "$SP_BIN" "${APP_BUNDLE}/Contents/MacOS/speedtest"
    echo "(speedtest 已打包: $SP_BIN)"
else
    echo "(speedtest 未找到 — 可通过 brew install speedtest-cli 安装)"
fi

cp "icon/shield_bolt.icns" "${APP_BUNDLE}/Contents/Resources/AppIcon.icns" 2>/dev/null || echo "(图标使用已安装版本)"

echo "=== 4. 生成 Info.plist ==="
cat > "${APP_BUNDLE}/Contents/Info.plist" << 'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>zh_CN</string>
    <key>CFBundleExecutable</key>
    <string>Dclean</string>
    <key>CFBundleIdentifier</key>
    <string>com.dclean.app</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>Dclean</string>
    <key>CFBundleDisplayName</key>
    <string>Dclean</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>3.1.0</string>
    <key>CFBundleVersion</key>
    <string>4</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSHumanReadableCopyright</key>
    <string>Copyright 2026 Dclean. All rights reserved.</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>LSUIElement</key>
    <false/>
</dict>
</plist>
PLIST

echo "=== 5. 代码签名 ==="
codesign --force --deep --sign - "${APP_BUNDLE}" 2>&1

echo ""
echo "=== 完成: ${APP_BUNDLE} ==="
ls -lh "${APP_BUNDLE}/Contents/MacOS/"
echo ""
echo "安装到 /Applications:"
echo "  cp -R Dclean.app /Applications/"
