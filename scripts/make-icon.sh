#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

echo "→ Rendering 1024×1024 master PNG…"
swift scripts/gen-icon.swift /tmp/copytranslate-icon.png

STAGE="/tmp/CopyTranslate.iconset"
rm -rf "${STAGE}"
mkdir -p "${STAGE}"

# Generate all required resolutions for .icns.
for pair in "16 1" "16 2" "32 1" "32 2" "128 1" "128 2" "256 1" "256 2" "512 1" "512 2"; do
    read -r base scale <<<"$pair"
    px=$((base * scale))
    if [ "$scale" = "1" ]; then
        name="icon_${base}x${base}.png"
    else
        name="icon_${base}x${base}@2x.png"
    fi
    sips -z "$px" "$px" /tmp/copytranslate-icon.png --out "${STAGE}/${name}" >/dev/null
done

echo "→ Packaging .icns…"
iconutil -c icns "${STAGE}" -o Resources/AppIcon.icns
rm -rf "${STAGE}" /tmp/copytranslate-icon.png

echo "✓ Wrote Resources/AppIcon.icns"
ls -la Resources/AppIcon.icns
