#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

VERSION="${1:-0.2.0}"

echo "=== CopyTranslate ${VERSION} Release ==="
echo ""

bash scripts/make-icon.sh
bash scripts/build-app.sh "${VERSION}"
bash scripts/build-dmg.sh "${VERSION}"

echo ""
echo "=== Release artifacts ==="
ls -lh build/CopyTranslate.app/Contents/MacOS/CopyTranslate
ls -lh "build/CopyTranslate-${VERSION}.dmg"
