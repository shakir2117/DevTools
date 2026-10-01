#!/bin/bash
set -euo pipefail
APP=DevKit

swift build -c release --arch arm64
BIN=$(swift build -c release --arch arm64 --show-bin-path)

rm -rf "$APP.app"
mkdir -p "$APP.app/Contents/MacOS" "$APP.app/Contents/Resources"
cp "$BIN/$APP" "$APP.app/Contents/MacOS/$APP"

# Copy SwiftPM resource bundles (wordlists, Prettier, etc.)
for b in "$BIN"/*.bundle; do
  [ -e "$b" ] && cp -R "$b" "$APP.app/Contents/Resources/"
done

cp Info.plist "$APP.app/Contents/Info.plist"
[ -f AppIcon.icns ] && cp AppIcon.icns "$APP.app/Contents/Resources/AppIcon.icns"

codesign --force --deep -s - "$APP.app"
echo "Architectures: $(lipo -archs "$APP.app/Contents/MacOS/$APP")"
echo "Built $APP.app"
