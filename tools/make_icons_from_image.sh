#!/usr/bin/env bash
# Regenerate assets/ from a square source image.
#
#   bash tools/make_icons_from_image.sh path/to/icon.png [assets_dir]
#
# Uses sips (macOS) for resizing; the .ico/.icns assembly is pure Python.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC="${1:?usage: make_icons_from_image.sh source.png [assets_dir]}"
ASSETS="${2:-$REPO_ROOT/assets}"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

sips -s format png "$SRC" --out "$WORK/base.png" >/dev/null
for size in 16 32 48 64 128 256 512 1024; do
  sips -z "$size" "$size" "$WORK/base.png" --out "$WORK/icon-$size.png" >/dev/null
done

mkdir -p "$ASSETS"
cp "$WORK/icon-512.png" "$ASSETS/icon.png"
for size in 16 32 48 64 128 256 512; do
  cp "$WORK/icon-$size.png" "$ASSETS/icon-$size.png"
done

python3 "$REPO_ROOT/tools/pack_icons.py" \
  --ico "$ASSETS/icon.ico" \
  --icns "$ASSETS/icon.icns" \
  "$WORK"/icon-16.png "$WORK"/icon-32.png "$WORK"/icon-48.png "$WORK"/icon-64.png \
  "$WORK"/icon-128.png "$WORK"/icon-256.png "$WORK"/icon-512.png

echo "icons updated in $ASSETS"
