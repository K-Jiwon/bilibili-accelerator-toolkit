#!/usr/bin/env bash
# Build the self-contained Windows release zip.
#
#   bash tools/build_windows_release.sh [out_dir]
#
# Requires: curl, unzip, zip, python3, pip3
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT_DIR="${1:-$REPO_ROOT/dist}"
PY_VERSION="${PYTHON_EMBED_VERSION:-3.12.7}"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
BUNDLE="$WORK/BiliAccelerator-Windows"
mkdir -p "$BUNDLE" "$OUT_DIR"

echo "==> generating icons"
python3 "$REPO_ROOT/tools/make_icon.py" "$REPO_ROOT/assets"

echo "==> downloading Python ${PY_VERSION} embeddable runtime"
curl -fsSL -o "$WORK/python-embed.zip" \
  "https://www.python.org/ftp/python/${PY_VERSION}/python-${PY_VERSION}-embed-amd64.zip"
unzip -q "$WORK/python-embed.zip" -d "$BUNDLE/python"

PTH_FILE="$(ls "$BUNDLE"/python/python*._pth | head -1)"
sed -i.bak 's|^#import site|import site|' "$PTH_FILE"
grep -q 'site-packages' "$PTH_FILE" || printf 'Lib\\site-packages\n' >> "$PTH_FILE"
rm -f "$PTH_FILE.bak"

echo "==> fetching websocket-client"
mkdir -p "$WORK/wheels" "$BUNDLE/python/Lib/site-packages"
pip3 download --no-deps --only-binary=:all: -d "$WORK/wheels" websocket-client >/dev/null
for wheel in "$WORK"/wheels/*.whl; do
  unzip -q "$wheel" -d "$BUNDLE/python/Lib/site-packages"
done
find "$BUNDLE/python/Lib/site-packages" -name '__pycache__' -type d -prune -exec rm -rf {} + 2>/dev/null || true

echo "==> assembling bundle"
cp "$REPO_ROOT/injector.py" "$BUNDLE/injector.py"
cp "$REPO_ROOT/userscript/bilibili-accelerator.user.js" "$BUNDLE/bilibili-accelerator.user.js"
cp "$REPO_ROOT/windows/"* "$BUNDLE/"
rm -f "$BUNDLE/config.json"
cp "$REPO_ROOT/assets/icon.ico" "$BUNDLE/bilibili.ico"

rm -f "$OUT_DIR/BiliAccelerator-Windows.zip"
(cd "$WORK" && zip -qr "$OUT_DIR/BiliAccelerator-Windows.zip" BiliAccelerator-Windows)
echo "==> done: $OUT_DIR/BiliAccelerator-Windows.zip"
