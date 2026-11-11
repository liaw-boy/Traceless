#!/bin/zsh
# Build a release .app bundle: ./bundle.sh  →  Traceless.app & Traceless.dmg
set -e
cd "$(dirname "$0")"

VERSION=$(tr -d '[:space:]' < VERSION)
BUILD=$(git rev-list --count HEAD 2>/dev/null || echo 1)

echo "🔨 Building release binary (v$VERSION, build $BUILD)..."
swift build -c release

APP=Traceless.app
rm -rf "$APP" && mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/release/Traceless "$APP/Contents/MacOS/Traceless"

# Generate native macOS AppIcon.icns
echo "🎨 Compiling AppIcon.icns and brand assets..."
mkdir -p Resources
swift scripts/generate_icon.swift Resources/AppIcon.iconset
iconutil -c icns Resources/AppIcon.iconset -o Resources/AppIcon.icns

cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"

cat > "$APP/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleName</key><string>Traceless</string>
  <key>CFBundleDisplayName</key><string>Traceless</string>
  <key>CFBundleIdentifier</key><string>app.traceless.mac</string>
  <key>CFBundleExecutable</key><string>Traceless</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>CFBundleIconName</key><string>AppIcon</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>$VERSION</string>
  <key>CFBundleVersion</key><string>$BUILD</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>NSPrincipalClass</key><string>NSApplication</string>
  <key>NSHighResolutionCapable</key><true/>
  <key>NSSupportsAutomaticGraphicsSwitching</key><true/>
  <key>LSApplicationCategoryType</key><string>public.app-category.utilities</string>
</dict></plist>
EOF

# SIGN_IDENTITY="Your Code Signing Cert" ./bundle.sh keeps a stable signature, so macOS privacy
# grants (Full Disk Access) survive rebuilds. Default is ad-hoc ("-").
SIGN_IDENTITY="${SIGN_IDENTITY:--}"
echo "🔏 Code signing Traceless.app (identity: $SIGN_IDENTITY)..."
codesign --force --deep --options runtime --sign "$SIGN_IDENTITY" "$APP"

# Package DMG (for drag-to-Applications installer)
echo "📦 Packaging Traceless.dmg..."
DMG_STAGE=$(mktemp -d)/dmg_stage
mkdir -p "$DMG_STAGE"
cp -R "$APP" "$DMG_STAGE/"
ln -s /Applications "$DMG_STAGE/Applications"
rm -f Traceless.dmg
hdiutil create -volname "Traceless" -srcfolder "$DMG_STAGE" -ov -format UDZO Traceless.dmg >/dev/null
rm -rf "$(dirname "$DMG_STAGE")"

echo "✅ Successfully built $APP and Traceless.dmg!"
