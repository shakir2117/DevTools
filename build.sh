#!/bin/bash
set -euo pipefail
APP=DevKit

swift build -c release --arch arm64
BIN=$(swift build -c release --arch arm64 --show-bin-path)

rm -rf "$APP.app"
mkdir -p "$APP.app/Contents/MacOS" "$APP.app/Contents/Resources"
cp "$BIN/$APP" "$APP.app/Contents/MacOS/$APP"

# Bundle.module only checks the .app root and the absolute .build path.
# The root is not a valid signed bundle location, and .build is deleted with
# the project, so Prettier is copied into Contents/Resources instead.
if [ -d "$BIN/${APP}_${APP}.bundle/Resources/prettier" ]; then
  cp -R "$BIN/${APP}_${APP}.bundle/Resources/prettier" "$APP.app/Contents/Resources/prettier"
fi

cp Info.plist "$APP.app/Contents/Info.plist"
[ -f AppIcon.icns ] && cp AppIcon.icns "$APP.app/Contents/Resources/AppIcon.icns"

codesign --force --deep -s - "$APP.app"
echo "Architectures: $(lipo -archs "$APP.app/Contents/MacOS/$APP")"
echo "Built $APP.app"
