#!/usr/bin/env bash
# Build the self-contained Windows release zip.
#
#   bash tools/build_windows_release.sh [out_dir]
#
# Requires: curl, unzip, zip, python3
#
# The injector only uses the Python standard library (see wsclient.py), so the
# bundle needs just the embeddable runtime - no pip, no wheels, no network at
# install time. The runtime download is pinned and verified by SHA256.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT_DIR="${1:-$REPO_ROOT/dist}"

PY_VERSION="3.12.7"
PY_SHA256="0d57bb6cb078b74d23dbfe91f77d6780d45bed328911609f1f7ee2ba1606bf44"

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

echo "==> checking icons"
for icon in icon.ico icon.icns icon.png; do
  if [ ! -f "$REPO_ROOT/assets/$icon" ]; then
    echo "ERROR: assets/$icon is missing (run tools/make_icons_from_image.sh)" >&2
    exit 1
  fi
done

echo "==> downloading Python ${PY_VERSION} embeddable runtime"
curl -fsSL -o "$WORK/python-embed.zip" \
  "https://www.python.org/ftp/python/${PY_VERSION}/python-${PY_VERSION}-embed-amd64.zip"

actual="$(sha256_of "$WORK/python-embed.zip")"
if [ "$actual" != "$PY_SHA256" ]; then
  echo "ERROR: checksum mismatch for python-embed.zip" >&2
  echo "  expected: $PY_SHA256" >&2
  echo "  actual:   $actual" >&2
  exit 1
fi
echo "==> checksum ok: python-embed.zip"
unzip -q "$WORK/python-embed.zip" -d "$BUNDLE/python"

echo "==> assembling bundle"
cp "$REPO_ROOT/injector.py" "$BUNDLE/injector.py"
cp "$REPO_ROOT/wsclient.py" "$BUNDLE/wsclient.py"
cp "$REPO_ROOT/userscript/bilibili-accelerator.user.js" "$BUNDLE/bilibili-accelerator.user.js"
find "$REPO_ROOT/windows" -maxdepth 1 -type f -exec cp {} "$BUNDLE/" \;
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
