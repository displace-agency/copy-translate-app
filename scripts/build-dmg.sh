#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

APP_NAME="CopyTranslate"
VERSION="${1:-0.3.0}"
BUILD_ROOT="build"
APP_DIR="${BUILD_ROOT}/${APP_NAME}.app"
DMG_NAME="${APP_NAME}-${VERSION}.dmg"
DMG_PATH="${BUILD_ROOT}/${DMG_NAME}"
TMP_DMG="/tmp/${APP_NAME}-tmp.dmg"
VOLUME_NAME="${APP_NAME} ${VERSION}"

if [ ! -d "${APP_DIR}" ]; then
    echo "Error: ${APP_DIR} not found. Run build-app.sh first." >&2
    exit 1
fi

echo "→ Creating DMG..."
rm -f "${TMP_DMG}" "${DMG_PATH}"

hdiutil create -size 50m -fs HFS+ -volname "${VOLUME_NAME}" "${TMP_DMG}" -ov
MOUNT_DIR=$(hdiutil attach "${TMP_DMG}" -readwrite -noverify | grep -o '/Volumes/.*' | head -1)

cp -R "${APP_DIR}" "${MOUNT_DIR}/"
ln -s /Applications "${MOUNT_DIR}/Applications"

hdiutil detach "${MOUNT_DIR}" -quiet
hdiutil convert "${TMP_DMG}" -format UDZO -o "${DMG_PATH}"
rm -f "${TMP_DMG}"

echo "✓ ${DMG_PATH} ($(du -h "${DMG_PATH}" | cut -f1))"
