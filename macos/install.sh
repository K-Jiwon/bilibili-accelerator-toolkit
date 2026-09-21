#!/bin/zsh
# Install the BiliAccelerator launcher and injector on macOS.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DIR="$HOME/.bili-accelerator"
APPS_DIR="$HOME/Applications"
APP="$APPS_DIR/哔哩哔哩 加速.app"
AGENT="$HOME/Library/LaunchAgents/com.local.bili-injector.plist"
BILI_APP="${BILI_APP:-/Applications/哔哩哔哩.app}"
PORT="${BILI_PORT:-9223}"
PYTHON="${PYTHON:-$(command -v python3 || true)}"
WEBSOCKET_CLIENT_VERSION="1.9.2"

if [ ! -d "$BILI_APP" ]; then
  echo "找不到客户端：$BILI_APP"
  echo "如果装在别的位置，可以这样指定："
  echo "  BILI_APP=/Applications/你的客户端.app ./macos/install.sh"
  exit 1
fi

if [ -z "$PYTHON" ]; then
  echo "需要 python3（macOS 可以用 xcode-select --install 安装命令行工具）"
  exit 1
fi

mkdir -p "$DIR" "$APPS_DIR" "$HOME/Library/LaunchAgents"
cp "$REPO_DIR/injector.py" "$DIR/injector.py"
cp "$REPO_DIR/userscript/bilibili-accelerator.user.js" "$DIR/bilibili-accelerator.user.js"
chmod 755 "$DIR/injector.py"

echo "准备运行环境（首次需要联网安装 websocket-client）..."
if [ ! -d "$DIR/venv" ]; then
  "$PYTHON" -m venv "$DIR/venv"
fi
"$DIR/venv/bin/pip" install --quiet --upgrade pip \
  "websocket-client==${WEBSOCKET_CLIENT_VERSION}"

if [ -e "$APP" ]; then
  mv "$APP" "$APP.bak.$(date +%s)"
fi
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
sed -e "s|__DIR__|$DIR|g" \
    -e "s|__BILI_APP__|$BILI_APP|g" \
    -e "s|__PORT__|$PORT|g" \
    "$REPO_DIR/macos/launcher.sh.template" > "$APP/Contents/MacOS/launcher"
chmod 755 "$APP/Contents/MacOS/launcher"
sed -e "s|__NAME__|哔哩哔哩 加速|g" "$REPO_DIR/macos/Info.plist.template" > "$APP/Contents/Info.plist"
if [ -f "$REPO_DIR/assets/icon.icns" ]; then
  cp "$REPO_DIR/assets/icon.icns" "$APP/Contents/Resources/appicon.icns"
fi
/usr/bin/codesign --force --deep --sign - "$APP" >/dev/null 2>&1 || true

sed -e "s|__PYTHON__|$DIR/venv/bin/python|g" \
    -e "s|__INJECTOR__|$DIR/injector.py|g" \
    -e "s|__SCRIPT__|$DIR/bilibili-accelerator.user.js|g" \
    -e "s|__PORT__|$PORT|g" \
    -e "s|__LOG__|$DIR/injector.log|g" \
    -e "s|__ERRLOG__|$DIR/injector.err.log|g" \
    "$REPO_DIR/macos/com.local.bili-injector.plist.template" > "$AGENT"

UID_NUM="$(id -u)"
launchctl bootout "gui/$UID_NUM/com.local.bili-injector" 2>/dev/null || true
launchctl bootstrap "gui/$UID_NUM" "$AGENT"
launchctl enable "gui/$UID_NUM/com.local.bili-injector"
launchctl kickstart -k "gui/$UID_NUM/com.local.bili-injector" >/dev/null 2>&1 || true

echo ""
echo "安装完成！"
echo "· 启动器： $APP（建议拖到 Dock）"
echo "· 注入日志：$DIR/injector.log"
echo "· 以后从「哔哩哔哩 加速」启动客户端即可"
