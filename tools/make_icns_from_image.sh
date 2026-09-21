#!/usr/bin/env bash
# Build a single .icns file from a square source image.
#
#   bash tools/make_icns_from_image.sh source.png out.icns
#
# Uses sips (macOS) for resizing; assembly is pure Python.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC="${1:?usage: make_icns_from_image.sh source.png out.icns}"
OUT="${2:?usage: make_icns_from_image.sh source.png out.icns}"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

sips -s format png "$SRC" --out "$WORK/base.png" >/dev/null
for size in 16 32 64 128 256 512; do
  sips -z "$size" "$size" "$WORK/base.png" --out "$WORK/icon-$size.png" >/dev/null
done

mkdir -p "$(dirname "$OUT")"
python3 "$REPO_ROOT/tools/pack_icons.py" --icns "$OUT" \
  "$WORK/icon-16.png" "$WORK/icon-32.png" "$WORK/icon-64.png" \
  "$WORK/icon-128.png" "$WORK/icon-256.png" "$WORK/icon-512.png"

echo "wrote $OUT"
