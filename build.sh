#!/bin/bash
# Builds HourPie.app into ./build.
#   ./build.sh              build for this Mac's architecture
#   ./build.sh --universal  build a universal (arm64 + x86_64) binary
set -euo pipefail
cd "$(dirname "$0")"

APP="build/HourPie.app"
rm -rf build
mkdir -p "$APP/Contents/MacOS"

if [[ "${1:-}" == "--universal" ]]; then
    swiftc -O -parse-as-library -target arm64-apple-macos13 Sources/HourPie.swift -o build/HourPie-arm64
    swiftc -O -parse-as-library -target x86_64-apple-macos13 Sources/HourPie.swift -o build/HourPie-x86_64
    lipo -create build/HourPie-arm64 build/HourPie-x86_64 -output "$APP/Contents/MacOS/HourPie"
    rm build/HourPie-arm64 build/HourPie-x86_64
else
    swiftc -O -parse-as-library Sources/HourPie.swift -o "$APP/Contents/MacOS/HourPie"
fi

cp Info.plist "$APP/Contents/Info.plist"
mkdir -p "$APP/Contents/Resources"
cp Assets/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
printf 'APPL????' > "$APP/Contents/PkgInfo"
codesign --force --sign - "$APP"

echo "Built $APP"
