#!/bin/zsh
# Build a release .app bundle: ./bundle.sh  →  AppSweep.app & AppSweep.dmg
set -e
cd "$(dirname "$0")"

VERSION=$(tr -d '[:space:]' < VERSION)
BUILD=$(git rev-list --count HEAD 2>/dev/null || echo 1)

echo "🔨 Building release binary (v$VERSION, build $BUILD)..."
swift build -c release

APP=AppSweep.app
rm -rf "$APP" && mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/release/AppSweep "$APP/Contents/MacOS/AppSweep"

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
  <key>CFBundleName</key><string>AppSweep</string>
  <key>CFBundleDisplayName</key><string>AppSweep</string>
  <key>CFBundleIdentifier</key><string>com.appsweep.macos</string>
  <key>CFBundleExecutable</key><string>AppSweep</string>
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

echo "🔏 Ad-hoc code signing AppSweep.app..."
codesign --force --deep --sign - "$APP"

# Package DMG (for drag-to-Applications installer)
echo "📦 Packaging AppSweep.dmg..."
DMG_STAGE=$(mktemp -d)/dmg_stage
mkdir -p "$DMG_STAGE"
cp -R "$APP" "$DMG_STAGE/"
ln -s /Applications "$DMG_STAGE/Applications"
rm -f AppSweep.dmg
hdiutil create -volname "AppSweep" -srcfolder "$DMG_STAGE" -ov -format UDZO AppSweep.dmg >/dev/null
rm -rf "$(dirname "$DMG_STAGE")"

echo "✅ Successfully built $APP and AppSweep.dmg!"
