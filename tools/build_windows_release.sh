#!/usr/bin/env bash
# Build the self-contained Windows release zip.
#
#   bash tools/build_windows_release.sh [out_dir]
#
# Requires: curl, unzip, zip, python3, pip3
#
# Downloads are pinned to exact versions and verified against SHA256 so the
# build is reproducible and the supply chain is checked.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT_DIR="${1:-$REPO_ROOT/dist}"

PY_VERSION="3.12.7"
PY_SHA256="0d57bb6cb078b74d23dbfe91f77d6780d45bed328911609f1f7ee2ba1606bf44"
WS_VERSION="1.9.2"
WS_SHA256="e1a673830a9c7bfa47b1cd3d5e4178f4c9651d80a4eab02c9c23a1c3ec6250ce"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
BUNDLE="$WORK/BiliAccelerator-Windows"
mkdir -p "$BUNDLE" "$OUT_DIR"

sha256_of() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{print $1}'
  else
    shasum -a 256 "$1" | awk '{print $1}'
  fi
}

check_sha256() {
  local file="$1" expected="$2" actual
  actual="$(sha256_of "$file")"
  if [ "$actual" != "$expected" ]; then
    echo "ERROR: checksum mismatch for $(basename "$file")" >&2
    echo "  expected: $expected" >&2
    echo "  actual:   $actual" >&2
    exit 1
  fi
  echo "==> checksum ok: $(basename "$file")"
}

echo "==> generating icons"
python3 "$REPO_ROOT/tools/make_icon.py" "$REPO_ROOT/assets"

echo "==> downloading Python ${PY_VERSION} embeddable runtime"
curl -fsSL -o "$WORK/python-embed.zip" \
  "https://www.python.org/ftp/python/${PY_VERSION}/python-${PY_VERSION}-embed-amd64.zip"
check_sha256 "$WORK/python-embed.zip" "$PY_SHA256"
unzip -q "$WORK/python-embed.zip" -d "$BUNDLE/python"

PTH_FILE="$(ls "$BUNDLE"/python/python*._pth | head -1)"
sed -i.bak 's|^#import site|import site|' "$PTH_FILE"
grep -q 'site-packages' "$PTH_FILE" || printf 'Lib\\site-packages\n' >> "$PTH_FILE"
rm -f "$PTH_FILE.bak"

echo "==> fetching websocket-client==${WS_VERSION}"
mkdir -p "$WORK/wheels" "$BUNDLE/python/Lib/site-packages"
pip3 download --no-deps --only-binary=:all: -d "$WORK/wheels" \
  "websocket-client==${WS_VERSION}" >/dev/null
WHEEL="$(ls "$WORK"/wheels/websocket_client-"${WS_VERSION}"-*.whl | head -1)"
check_sha256 "$WHEEL" "$WS_SHA256"
unzip -q "$WHEEL" -d "$BUNDLE/python/Lib/site-packages"
find "$BUNDLE/python/Lib/site-packages" -name '__pycache__' -type d -prune -exec rm -rf {} + 2>/dev/null || true

echo "==> assembling bundle"
cp "$REPO_ROOT/injector.py" "$BUNDLE/injector.py"
cp "$REPO_ROOT/userscript/bilibili-accelerator.user.js" "$BUNDLE/bilibili-accelerator.user.js"
cp "$REPO_ROOT/windows/"* "$BUNDLE/"
rm -f "$BUNDLE/config.json"
cp "$REPO_ROOT/assets/icon.ico" "$BUNDLE/bilibili.ico"

rm -f "$OUT_DIR/BiliAccelerator-Windows.zip" "$OUT_DIR/BiliAccelerator-Windows.zip.sha256"
(cd "$WORK" && zip -qr "$OUT_DIR/BiliAccelerator-Windows.zip" BiliAccelerator-Windows)

(cd "$OUT_DIR" && if command -v sha256sum >/dev/null 2>&1; then
  sha256sum BiliAccelerator-Windows.zip > BiliAccelerator-Windows.zip.sha256
else
  shasum -a 256 BiliAccelerator-Windows.zip > BiliAccelerator-Windows.zip.sha256
fi)

echo "==> done: $OUT_DIR/BiliAccelerator-Windows.zip"
cat "$OUT_DIR/BiliAccelerator-Windows.zip.sha256"
