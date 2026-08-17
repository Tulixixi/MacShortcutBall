#!/bin/bash
# ============================================================
#  编译并打包「快捷键悬浮球」Mac 应用
#  用法: ./build.sh
#  产物: MacShortcutBall.app
# ============================================================
set -euo pipefail
cd "$(dirname "$0")"

APP_NAME="MacShortcutBall"
SWIFT_MAIN="main.swift"

echo "==> 编译 $SWIFT_MAIN ..."
swiftc -O -swift-version 5 \
  -o "$APP_NAME" \
  "$SWIFT_MAIN" \
  -framework Cocoa

echo "==> 打包 $APP_NAME.app ..."
APP_DIR="$APP_NAME.app"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"
mv "$APP_NAME" "$APP_DIR/Contents/MacOS/"
cp shortcuts.json "$APP_DIR/Contents/Resources/" 2>/dev/null || true
cp float.png "$APP_DIR/Contents/Resources/" 2>/dev/null || true

# 应用图标（品牌标志）：每次构建强制从源 PNG 重新生成，避免缓存旧图标
ICON_DIR="icon-source"
echo "==> 生成 AppIcon.icns ..."
mkdir -p "$ICON_DIR/AppIcon.iconset"
SRC="$ICON_DIR/icon.png"
[ -f "$SRC" ] || SRC=$(ls "$ICON_DIR"/*.png 2>/dev/null | head -1)
sips -z 16 16 "$SRC" --out "$ICON_DIR/AppIcon.iconset/icon_16x16.png" >/dev/null
sips -z 32 32 "$SRC" --out "$ICON_DIR/AppIcon.iconset/icon_16x16@2x.png" >/dev/null
sips -z 32 32 "$SRC" --out "$ICON_DIR/AppIcon.iconset/icon_32x32.png" >/dev/null
sips -z 64 64 "$SRC" --out "$ICON_DIR/AppIcon.iconset/icon_32x32@2x.png" >/dev/null
sips -z 128 128 "$SRC" --out "$ICON_DIR/AppIcon.iconset/icon_128x128.png" >/dev/null
sips -z 256 256 "$SRC" --out "$ICON_DIR/AppIcon.iconset/icon_128x128@2x.png" >/dev/null
sips -z 256 256 "$SRC" --out "$ICON_DIR/AppIcon.iconset/icon_256x256.png" >/dev/null
sips -z 512 512 "$SRC" --out "$ICON_DIR/AppIcon.iconset/icon_256x256@2x.png" >/dev/null
sips -z 512 512 "$SRC" --out "$ICON_DIR/AppIcon.iconset/icon_512x512.png" >/dev/null
sips -z 1024 1024 "$SRC" --out "$ICON_DIR/AppIcon.iconset/icon_512x512@2x.png" >/dev/null
iconutil -c icns "$ICON_DIR/AppIcon.iconset" -o "$ICON_DIR/AppIcon.icns"
cp "$ICON_DIR/AppIcon.icns" "$APP_DIR/Contents/Resources/"

cat > "$APP_DIR/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>MacShortcutBall</string>
    <key>CFBundleDisplayName</key>
    <string>快捷键悬浮球</string>
    <key>CFBundleIdentifier</key>
    <string>local.MacShortcutBall</string>
    <key>CFBundleVersion</key>
    <string>1.0</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleExecutable</key>
    <string>MacShortcutBall</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>LSMinimumSystemVersion</key>
    <string>11.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>LSUIElement</key>
    <true/>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
</dict>
</plist>
PLIST

echo ""
echo "✅ 构建完成: $(pwd)/$APP_DIR"
echo "   启动:  open $APP_DIR"
echo "   悬浮球右键 / 菜单栏图标可隐藏、退出"

# ------------------------------------------------------------
#  可选：打包发布用的 .dmg（供 GitHub Releases 分发给其他人）
#  用法: ./build.sh dmg
# ------------------------------------------------------------
if [ "${1:-}" = "dmg" ]; then
  DMG="$APP_NAME-1.0.dmg"
  STAGE="release_stage"
  rm -rf "$STAGE" "$DMG"
  mkdir -p "$STAGE"
  cp -R "$APP_DIR" "$STAGE/"
  # 桌面快捷方式指向「应用程序」文件夹，方便用户安装
  ln -s /Applications "$STAGE/拖入 Applications 文件夹"
  hdiutil create -volname "$APP_NAME" -srcfolder "$STAGE" -ov -format UDZO "$DMG" >/dev/null
  rm -rf "$STAGE"
  echo "✅ 发布包已生成: $(pwd)/$DMG"
  echo "   可上传到 GitHub Releases 供他人下载（Intel 与 Apple Silicon 通用）"
fi
