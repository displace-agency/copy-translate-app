#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

APP_NAME="CopyTranslate"
VERSION="${1:-0.3.0}"
BUILD_ROOT="build"
APP_DIR="${BUILD_ROOT}/${APP_NAME}.app"

echo "→ Building universal binary (arm64 + x86_64)..."
BIN_DIR="$(swift build -c release --arch arm64 --arch x86_64 --show-bin-path)"
BIN_PATH="${BIN_DIR}/${APP_NAME}"
if [ ! -f "${BIN_PATH}" ]; then
    BIN_PATH=".build/apple/Products/Release/${APP_NAME}"
fi
if [ ! -f "${BIN_PATH}" ]; then
    echo "Could not locate built binary." >&2
    exit 1
fi
echo "→ Binary: $(file "${BIN_PATH}" | grep -o 'arm64\|x86_64' | tr '\n' '+' | sed 's/+$//')"

echo "→ Assembling ${APP_DIR}…"
rm -rf "${APP_DIR}"
mkdir -p "${APP_DIR}/Contents/MacOS"
mkdir -p "${APP_DIR}/Contents/Resources"
cp "${BIN_PATH}" "${APP_DIR}/Contents/MacOS/${APP_NAME}"
cp "Resources/Info.plist" "${APP_DIR}/Contents/Info.plist"

if [ -f "Resources/AppIcon.icns" ]; then
    cp "Resources/AppIcon.icns" "${APP_DIR}/Contents/Resources/"
    /usr/libexec/PlistBuddy -c "Add :CFBundleIconFile string AppIcon" "${APP_DIR}/Contents/Info.plist" 2>/dev/null || true
fi

/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString ${VERSION}" "${APP_DIR}/Contents/Info.plist"

echo "→ Ad-hoc signing…"
codesign --force --deep --sign - "${APP_DIR}"

echo "✓ Built ${APP_DIR}"
