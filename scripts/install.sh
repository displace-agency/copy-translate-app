#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

APP_DIR="build/CopyTranslate.app"
if [ ! -d "${APP_DIR}" ]; then
    echo "Missing ${APP_DIR}. Run scripts/build-app.sh first." >&2
    exit 1
fi

# Quit any running instance before replacing.
pkill -x CopyTranslate 2>/dev/null || true
sleep 1

rm -rf "/Applications/CopyTranslate.app"
cp -R "${APP_DIR}" "/Applications/CopyTranslate.app"
open "/Applications/CopyTranslate.app"

echo "✓ Installed to /Applications/CopyTranslate.app and launched"
