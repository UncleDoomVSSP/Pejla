#!/usr/bin/env bash
# Builds an .icns file from a 1024x1024 PNG using the tools that ship with macOS.
# Usage: Scripts/make-icns.sh Packaging/icon-1024.png dist/AppIcon.icns
set -euo pipefail

SOURCE="$1"
OUTPUT="$2"
WORK="$(mktemp -d)"
ICONSET="$WORK/AppIcon.iconset"
mkdir -p "$ICONSET"

for size in 16 32 128 256 512; do
  double=$((size * 2))
  sips -z "$size" "$size" "$SOURCE" --out "$ICONSET/icon_${size}x${size}.png" >/dev/null
  sips -z "$double" "$double" "$SOURCE" --out "$ICONSET/icon_${size}x${size}@2x.png" >/dev/null
done

iconutil -c icns "$ICONSET" -o "$OUTPUT"
rm -rf "$WORK"
echo "Wrote $OUTPUT"
