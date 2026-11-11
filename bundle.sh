#!/bin/zsh
# Build a release .app bundle: ./bundle.sh  →  Traceless.app & Traceless.dmg
#
# Local update testing only: with TRACELESS_LOCAL_TEST=1 these env vars override the defaults
# (refused otherwise, so a release can never point at a test feed):
#   SPARKLE_FEED_URL   appcast URL baked into Info.plist
#   VERSION_OVERRIDE   pretend version, e.g. 1.0.0 to test updating to the current release
set -euo pipefail
cd "$(dirname "$0")"

die() { echo "error: $*" >&2; exit 1; }

REPO_URL="https://github.com/liaw-boy/Traceless"
FEED_URL="$REPO_URL/releases/latest/download/appcast.xml"
# Public half of the EdDSA update key; the private half lives only in the release Mac's
# login keychain (Sparkle generate_keys --account traceless).
PUBLIC_KEY="YACiSaaZOUGUquUwtegjxpqsvaduoyE1lsIjCuApLWg="
VERSION=$(tr -d '[:space:]' < VERSION)

if [[ "${TRACELESS_LOCAL_TEST:-}" == 1 ]]; then
  echo "*** LOCAL TEST BUILD: not for release ***"
  FEED_URL="${SPARKLE_FEED_URL:-$FEED_URL}"
  VERSION="${VERSION_OVERRIDE:-$VERSION}"
  [[ "$FEED_URL" =~ '^https?://[A-Za-z0-9.:/_~%-]+$' ]] || die "bad SPARKLE_FEED_URL"
else
  for v in SPARKLE_FEED_URL VERSION_OVERRIDE; do
    [[ -z "${(P)v:-}" ]] || die "$v is set; unset it, or set TRACELESS_LOCAL_TEST=1 for a test build"
  done
fi

[[ "$VERSION" =~ '^([0-9]+)\.([0-9]{1,2})\.([0-9]{1,2})$' ]] || die "VERSION must look like 1.2.3 (minor/patch < 100)"
# Sparkle compares CFBundleVersion, so derive a number that always grows with the version.
BUILD=$(( match[1] * 10000 + 10#${match[2]} * 100 + 10#${match[3]} ))

echo "🔨 Building release binary (v$VERSION, build $BUILD)..."
# Remap source paths so this Mac's home folder never ends up in the shipped binary.
swift build -c release -Xswiftc -file-prefix-map -Xswiftc "$PWD/=./"

APP=Traceless.app
rm -rf "$APP" && mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$APP/Contents/Frameworks"
cp .build/release/Traceless "$APP/Contents/MacOS/Traceless"
# Debug symbol maps still name the object files' absolute paths: strip them.
strip -S -x "$APP/Contents/MacOS/Traceless"
ditto .build/release/Sparkle.framework "$APP/Contents/Frameworks/Sparkle.framework"
install_name_tool -add_rpath "@executable_path/../Frameworks" "$APP/Contents/MacOS/Traceless"

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
  <key>CFBundleDevelopmentRegion</key><string>zh_TW</string>
  <key>CFBundleAllowMixedLocalizations</key><true/>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>NSPrincipalClass</key><string>NSApplication</string>
  <key>NSHighResolutionCapable</key><true/>
  <key>NSSupportsAutomaticGraphicsSwitching</key><true/>
  <key>LSApplicationCategoryType</key><string>public.app-category.utilities</string>
  <key>SUFeedURL</key><string>$FEED_URL</string>
  <key>SUPublicEDKey</key><string>$PUBLIC_KEY</string>
  <key>SUEnableAutomaticChecks</key><true/>
  <key>SURequireSignedFeed</key><true/>
  <key>SUVerifyUpdateBeforeExtraction</key><true/>
</dict></plist>
EOF

# SIGN_IDENTITY="Your Code Signing Cert" ./bundle.sh keeps a stable signature, so macOS privacy
# grants (Full Disk Access) survive rebuilds. Default is ad-hoc ("-").
SIGN_IDENTITY="${SIGN_IDENTITY:--}"
echo "🔏 Code signing Traceless.app (identity: $SIGN_IDENTITY)..."
# Re-sign Sparkle inside-out with the same identity: under the hardened runtime the app may only load
# code from its own team, and --deep would keep Sparkle's original signature.
SPK="$APP/Contents/Frameworks/Sparkle.framework/Versions/B"
# Hardened runtime (library validation) needs a real Team ID; ad-hoc code has none, so with ad-hoc
# signing the app could not load its own Sparkle. It only matters for notarization anyway.
runtime=(); [[ "$SIGN_IDENTITY" != "-" ]] && runtime=(--options runtime)
sign() { codesign --force "${runtime[@]}" --timestamp=none --sign "$SIGN_IDENTITY" "$@"; }
for xpc in "$SPK"/XPCServices/*.xpc(N); do sign --preserve-metadata=entitlements "$xpc"; done
sign "$SPK/Autoupdate"
sign "$SPK/Updater.app"
sign "$APP/Contents/Frameworks/Sparkle.framework"
sign "$APP"
codesign --verify --deep --strict "$APP" || die "code signature check failed"

# Nothing from this Mac may ship: no home path, user name or local build path.
for needle in "$HOME" "/Users/" "$(id -un)" "$PWD"; do
  if grep -r -a -q -F -- "$needle" "$APP"; then
    die "the app contains '$needle' (personal path or user name); not packaging it"
  fi
done

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
