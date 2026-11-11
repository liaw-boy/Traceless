#!/bin/zsh
# Builds the release files for the version in VERSION into dist/:
#   Traceless-<version>.zip  Sparkle update archive (EdDSA-signed)
#   Traceless.dmg            first-time installer
#   appcast.xml              signed update feed, served from .../releases/latest/download/appcast.xml
# Upload all three to the GitHub release tagged v<version>; this script never tags or uploads.
# The EdDSA private key is read from the login keychain (account "traceless").
set -euo pipefail
cd "$(dirname "$0")/.."

die() { echo "error: $*" >&2; exit 1; }

REPO_URL="https://github.com/liaw-boy/Traceless"
BIN=".build/artifacts/sparkle/Sparkle/bin"
OUT="dist"
VERSION=$(tr -d '[:space:]' < VERSION)

[[ -z "${TRACELESS_LOCAL_TEST:-}" ]] || die "TRACELESS_LOCAL_TEST is set; releases never use test settings"
[[ -z "$(git status --porcelain)" ]] || die "working tree is not clean; commit first"

./bundle.sh
APP="Traceless.app"
[[ -x "$BIN/sign_update" ]] || die "Sparkle tools missing in $BIN (run swift package resolve)"

plist() { /usr/libexec/PlistBuddy -c "Print :$1" "$APP/Contents/Info.plist"; }
[[ "$(plist CFBundleShortVersionString)" == "$VERSION" ]] || die "app version doesn't match VERSION"
[[ "$(plist SUFeedURL)" == "$REPO_URL/releases/latest/download/appcast.xml" ]] || die "SUFeedURL is not the release feed"
[[ "$(plist SURequireSignedFeed)" == true ]] || die "SURequireSignedFeed must be on"
# The keychain key must match the public key baked into the app, or every install would reject this release.
[[ "$("$BIN/generate_keys" --account traceless -p)" == "$(plist SUPublicEDKey)" ]] || die "keychain key doesn't match SUPublicEDKey"
BUILD="$(plist CFBundleVersion)"
MIN_OS="$(plist LSMinimumSystemVersion)"

rm -rf "$OUT" && mkdir -p "$OUT"
NAME="Traceless-$VERSION.zip"
ditto -c -k --sequesterRsrc --keepParent "$APP" "$OUT/$NAME"
cp Traceless.dmg "$OUT/Traceless.dmg"

# Prints: sparkle:edSignature="..." length="..."
SIGNATURE="$("$BIN/sign_update" --account traceless "$OUT/$NAME")"
[[ "$SIGNATURE" =~ '^sparkle:edSignature="[A-Za-z0-9+/=]+" (sparkle:)?length="[0-9]+"$' ]] || die "unexpected sign_update output"

# Release notes: this version's "- " bullets from CHANGELOG.md, HTML-escaped (covered by the feed signature).
NOTES="$(awk -v v="## $VERSION" '$0 == v {on=1; next} /^## / {on=0} on && /^- /' CHANGELOG.md \
  | sed -e 's/&/\&amp;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g' -e 's#^- \(.*\)#<li>\1</li>#')"
[[ -n "$NOTES" ]] || die "CHANGELOG.md has no '## $VERSION' section with '- ' items"

APPCAST="$OUT/appcast.xml"
cat > "$APPCAST" <<XML
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
  <channel>
    <title>Traceless</title>
    <item>
      <title>$VERSION</title>
      <pubDate>$(LC_ALL=C date -u '+%a, %d %b %Y %H:%M:%S +0000')</pubDate>
      <sparkle:version>$BUILD</sparkle:version>
      <sparkle:shortVersionString>$VERSION</sparkle:shortVersionString>
      <sparkle:minimumSystemVersion>$MIN_OS</sparkle:minimumSystemVersion>
      <description><![CDATA[<ul>
$NOTES
</ul>]]></description>
      <enclosure url="$REPO_URL/releases/download/v$VERSION/$NAME" type="application/octet-stream" $SIGNATURE/>
    </item>
  </channel>
</rss>
XML

# The app requires a signed feed (SURequireSignedFeed); this embeds the signature.
"$BIN/sign_update" --account traceless "$APPCAST" >/dev/null
grep -q 'sparkle-signatures' "$APPCAST" || die "appcast was not signed"

echo "Done: $OUT/$NAME, $OUT/Traceless.dmg, $APPCAST"
echo "Next: gh release create v$VERSION $OUT/$NAME $OUT/Traceless.dmg $APPCAST"
