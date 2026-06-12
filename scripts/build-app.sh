#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

APP_NAME="CopyTranslate"
VERSION="${1:-0.3.1}"
BUILD_ROOT="build"
APP_DIR="${BUILD_ROOT}/${APP_NAME}.app"

echo "→ Building universal binary (arm64 + x86_64)..."
swift build -c release --arch arm64 --arch x86_64
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

# Sign with a STABLE identity so the macOS Accessibility grant survives rebuilds.
# Ad-hoc signing (--sign -) changes the code identity every build and forces the
# user to re-grant Accessibility each time — run scripts/make-signing-cert.sh once.
IDENTITY="${CODESIGN_IDENTITY:-CopyTranslate Self-Signed}"
if security find-identity -v -p codesigning 2>/dev/null | grep -q "${IDENTITY}"; then
    echo "→ Signing with '${IDENTITY}'…"
    codesign --force --deep --sign "${IDENTITY}" "${APP_DIR}"
else
    echo "⚠️  Signing identity '${IDENTITY}' not found — falling back to AD-HOC." >&2
    echo "⚠️  macOS will re-ask for Accessibility on every rebuild." >&2
    echo "⚠️  Fix: run 'bash scripts/make-signing-cert.sh' once, then rebuild." >&2
    codesign --force --deep --sign - "${APP_DIR}"
fi

if codesign -dv "${APP_DIR}" 2>&1 | grep -q "Signature=adhoc"; then
    echo "⚠️  WARNING: bundle is still ad-hoc signed; Accessibility will churn." >&2
fi

echo "✓ Built ${APP_DIR}"
