#!/usr/bin/env bash
# Build the double-clickable macOS installer/uninstaller app.
#
#   bash macos/installer/build_installer.sh [out_dir]
#
# Produces:
#   dist/BiliAccelerator-macOS-Installer.zip
#   dist/BiliAccelerator-macOS-Installer.zip.sha256
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
OUT_DIR="${1:-$REPO_ROOT/dist}"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

APP="$WORK/哔哩哔哩 加速 安装器.app"
STAGE="$WORK/resources"
mkdir -p "$STAGE/macos" "$STAGE/userscript" "$STAGE/assets"

cp "$REPO_ROOT/injector.py" "$STAGE/"
cp "$REPO_ROOT/userscript/bilibili-accelerator.user.js" "$STAGE/userscript/"
cp "$REPO_ROOT/macos/install.sh" "$STAGE/macos/"
cp "$REPO_ROOT/macos/uninstall.sh" "$STAGE/macos/"
cp "$REPO_ROOT/macos/"*.template "$STAGE/macos/"
cp "$REPO_ROOT/assets/icon.icns" "$STAGE/assets/"

echo "==> compiling AppleScript app"
osacompile -o "$APP" "$REPO_ROOT/macos/installer/installer.applescript"
cp -R "$STAGE/"* "$APP/Contents/Resources/"
cp "$REPO_ROOT/assets/icon.icns" "$APP/Contents/Resources/applet.icns"
plutil -replace CFBundleName -string "哔哩哔哩 加速 安装器" "$APP/Contents/Info.plist" 2>/dev/null || true
plutil -replace CFBundleDisplayName -string "哔哩哔哩 加速 安装器" "$APP/Contents/Info.plist" 2>/dev/null || true
codesign --force --deep --sign - "$APP" >/dev/null 2>&1 || true

mkdir -p "$OUT_DIR"
rm -f "$OUT_DIR/BiliAccelerator-macOS-Installer.zip" "$OUT_DIR/BiliAccelerator-macOS-Installer.zip.sha256"
(cd "$WORK" && zip -qry "$OUT_DIR/BiliAccelerator-macOS-Installer.zip" "哔哩哔哩 加速 安装器.app")
(cd "$OUT_DIR" && shasum -a 256 BiliAccelerator-macOS-Installer.zip > BiliAccelerator-macOS-Installer.zip.sha256)

echo "==> done: $OUT_DIR/BiliAccelerator-macOS-Installer.zip"
ls -lh "$OUT_DIR/BiliAccelerator-macOS-Installer.zip"
cat "$OUT_DIR/BiliAccelerator-macOS-Installer.zip.sha256"
