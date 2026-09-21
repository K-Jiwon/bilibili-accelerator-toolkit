#!/bin/zsh
# Remove the BiliAccelerator launcher, injector and LaunchAgent.
set -u

DIR="$HOME/.bili-accelerator"
APP="$HOME/Applications/哔哩哔哩 加速.app"
AGENT="$HOME/Library/LaunchAgents/com.local.bili-injector.plist"
UID_NUM="$(id -u)"

launchctl bootout "gui/$UID_NUM/com.local.bili-injector" 2>/dev/null
rm -f "$AGENT"

pkill -f "$DIR/injector.py" 2>/dev/null

if [ -d "$APP" ]; then
  rm -rf "$APP"
fi
if [ -d "$DIR" ]; then
  rm -rf "$DIR"
fi

echo "已卸载（客户端本身未被修改）。"
