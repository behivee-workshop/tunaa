#!/bin/bash
# Builds Tunaa and packages it as a proper .app bundle (needed for WKWebView's
# media pipeline to work reliably) with the icon from design/appicon.png.
set -euo pipefail
cd "$(dirname "$0")"

swift build

APP=Tunaa.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp Packaging/Info.plist "$APP/Contents/Info.plist"
cp .build/debug/Tunaa "$APP/Contents/MacOS/Tunaa"
cp -R Sources/Tunaa/Icons "$APP/Contents/Resources/Icons"

ICONSET="$APP/Contents/Resources/AppIcon.iconset"
mkdir -p "$ICONSET"
SRC=design/appicon.png
for size in 16 32 128 256 512; do
  sips -z $size $size "$SRC" --out "$ICONSET/icon_${size}x${size}.png" >/dev/null
  double=$((size * 2))
  sips -z $double $double "$SRC" --out "$ICONSET/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"
rm -rf "$ICONSET"

codesign --force --sign - "$APP"
echo "Built $APP"
