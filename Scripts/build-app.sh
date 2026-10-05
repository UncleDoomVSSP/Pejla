#!/usr/bin/env bash
# Builds Pejla.app, a .dmg and a .zip into dist/.
#
#   Scripts/build-app.sh                 universal release build
#   PEJLA_UNIVERSAL=0 Scripts/build-app.sh   native architecture only (faster)
#
# Environment:
#   PEJLA_VERSION  marketing version, e.g. 1.2.0 (default 0.0.0)
#   PEJLA_BUILD    build number (default 1)
#   PEJLA_SKIP_OUI set to 1 to skip downloading the vendor registry
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION="${PEJLA_VERSION:-0.0.0}"
BUILD="${PEJLA_BUILD:-1}"
DIST="$ROOT/dist"
APP="$DIST/Pejla.app"

cd "$ROOT"

ARCH_FLAGS=()
if [[ "${PEJLA_UNIVERSAL:-1}" == "1" ]]; then
  ARCH_FLAGS=(--arch arm64 --arch x86_64)
fi

echo "==> Building Pejla $VERSION ($BUILD)"
swift build -c release --product Pejla ${ARCH_FLAGS[@]+"${ARCH_FLAGS[@]}"}
BIN_DIR="$(swift build -c release --product Pejla ${ARCH_FLAGS[@]+"${ARCH_FLAGS[@]}"} --show-bin-path)"
BINARY="$BIN_DIR/Pejla"
test -x "$BINARY"

echo "==> Assembling $APP"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BINARY" "$APP/Contents/MacOS/Pejla"
sed -e "s/__VERSION__/$VERSION/g" -e "s/__BUILD__/$BUILD/g" Packaging/Info.plist > "$APP/Contents/Info.plist"
printf 'APPL????' > "$APP/Contents/PkgInfo"
Scripts/make-icns.sh Packaging/icon-1024.png "$APP/Contents/Resources/AppIcon.icns"

if [[ "${PEJLA_SKIP_OUI:-0}" != "1" ]]; then
  Scripts/fetch-oui.sh "$APP/Contents/Resources/oui.csv" || true
fi

echo "==> Signing (ad hoc)"
codesign --force --deep --sign - --timestamp=none "$APP"
codesign --verify --verbose=2 "$APP"

echo "==> Packaging"
STAGING="$DIST/dmg-root"
rm -rf "$STAGING"
mkdir -p "$STAGING"
cp -R "$APP" "$STAGING/"
ln -s /Applications "$STAGING/Applications"
rm -f "$DIST/Pejla-$VERSION.dmg" "$DIST/Pejla-$VERSION.zip"
hdiutil create -volname "Pejla" -srcfolder "$STAGING" -ov -format UDZO -quiet "$DIST/Pejla-$VERSION.dmg"
ditto -c -k --sequesterRsrc --keepParent "$APP" "$DIST/Pejla-$VERSION.zip"
rm -rf "$STAGING"

echo "==> Done"
ls -la "$DIST"
