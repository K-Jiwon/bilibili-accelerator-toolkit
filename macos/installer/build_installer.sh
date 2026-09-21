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
cp "$REPO_ROOT/wsclient.py" "$STAGE/"
cp "$REPO_ROOT/userscript/bilibili-accelerator.user.js" "$STAGE/userscript/"
cp "$REPO_ROOT/macos/install.sh" "$STAGE/macos/"
cp "$REPO_ROOT/macos/uninstall.sh" "$STAGE/macos/"
cp "$REPO_ROOT/macos/"*.template "$STAGE/macos/"
cp "$REPO_ROOT/assets/icon.icns" "$STAGE/assets/"

cat > "$WORK/使用说明.txt" <<'TXT'
哔哩哔哩 加速 · 安装器（macOS）
==============================

怎么用
-----
1. 双击「哔哩哔哩 加速 安装器.app」
2. 点「安装」
3. 以后从「应用程序」里的「哔哩哔哩 加速」启动客户端就行

如果提示"无法打开，因为来自身份不明的开发者"
-----
在 App 上点右键 → 打开 → 再点一次「打开」。只需要做一次。

为什么这个包只有几百 KB？
-----
它不需要带 Python 运行时：注入器只用 Python 标准库，直接使用 macOS 自带的
python3。所以安装过程**不需要联网**，也不会下载任何东西。

不想用了
-----
再双击一次安装器 → 点「卸载」（会清掉后台服务、启动器、日志）。

出问题
-----
安装时如果报错，把弹窗内容截图；日志在 ~/.bili-accelerator/injector.log
TXT

echo "==> compiling AppleScript app"
osacompile -o "$APP" "$REPO_ROOT/macos/installer/installer.applescript"
cp -R "$STAGE/"* "$APP/Contents/Resources/"
# The installer window uses its own artwork; the launcher keeps assets/icon.icns
INSTALLER_ICON="$REPO_ROOT/assets/installer.icns"
[ -f "$INSTALLER_ICON" ] || INSTALLER_ICON="$REPO_ROOT/assets/icon.icns"
cp "$INSTALLER_ICON" "$APP/Contents/Resources/applet.icns"
plutil -replace CFBundleName -string "哔哩哔哩 加速 安装器" "$APP/Contents/Info.plist" 2>/dev/null || true
plutil -replace CFBundleDisplayName -string "哔哩哔哩 加速 安装器" "$APP/Contents/Info.plist" 2>/dev/null || true
codesign --force --deep --sign - "$APP" >/dev/null 2>&1 || true

mkdir -p "$OUT_DIR"
rm -f "$OUT_DIR/BiliAccelerator-macOS-Installer.zip" "$OUT_DIR/BiliAccelerator-macOS-Installer.zip.sha256"
(cd "$WORK" && zip -qry "$OUT_DIR/BiliAccelerator-macOS-Installer.zip" "哔哩哔哩 加速 安装器.app")
(cd "$WORK" && zip -qry "$OUT_DIR/BiliAccelerator-macOS-Installer.zip" "使用说明.txt")
(cd "$OUT_DIR" && shasum -a 256 BiliAccelerator-macOS-Installer.zip > BiliAccelerator-macOS-Installer.zip.sha256)

echo "==> done: $OUT_DIR/BiliAccelerator-macOS-Installer.zip"
ls -lh "$OUT_DIR/BiliAccelerator-macOS-Installer.zip"
cat "$OUT_DIR/BiliAccelerator-macOS-Installer.zip.sha256"
