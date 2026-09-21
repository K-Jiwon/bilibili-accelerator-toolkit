#!/bin/zsh
# 哔哩哔哩 加速 · macOS 卸载脚本
#
# 会删除：
#   后台服务、启动器 App、程序文件与日志
# 不会删除：
#   哔哩哔哩客户端本身（它的文件从来没被改过）
set -u

DIR="$HOME/.bili-accelerator"
APP_USER="$HOME/Applications/哔哩哔哩 加速.app"
APP_SYS="/Applications/哔哩哔哩 加速.app"
AGENT="$HOME/Library/LaunchAgents/com.local.bili-injector.plist"
UID_NUM="$(id -u)"

say() { printf '%s\n' "$*"; }

say "=================================="
say "  哔哩哔哩 加速 · 卸载 (macOS)"
say "=================================="
say ""

if launchctl bootout "gui/$UID_NUM/com.local.bili-injector" 2>/dev/null; then
  say "① 已停止后台服务"
else
  say "① 后台服务本来就没在运行"
fi
rm -f "$AGENT"

pkill -f "$DIR/injector.py" 2>/dev/null

if [ -d "$APP_USER" ]; then
  rm -rf "$APP_USER"
  say "② 已删除启动器（~/Applications）"
fi

if [ -d "$APP_SYS" ]; then
  if [ -w "$APP_SYS" ]; then
    rm -rf "$APP_SYS"
    say "② 已删除启动器（/Applications）"
  else
    say "② 检测到 /Applications/哔哩哔哩 加速.app（需要管理员才能删）"
    say "   请手动把它拖到废纸篓，或在终端运行："
    say "   sudo rm -rf \"$APP_SYS\""
  fi
fi

rm -rf "$DIR" 2>/dev/null || true
if [ -d "$DIR" ]; then
  # Leftovers can be owned by root (e.g. files created by an earlier admin
  # run). Ask for the password once instead of silently leaving junk behind.
  say "③ 有文件需要管理员权限才能删除，正在请求授权…"
  if osascript -e "do shell script \"rm -rf '$DIR'\" with administrator privileges" >/dev/null 2>&1; then
    say "③ 已删除程序文件与日志（~/.bili-accelerator）"
  else
    say "③ 删除失败，请手动运行： sudo rm -rf \"$DIR\""
  fi
else
  say "③ 已删除程序文件与日志（~/.bili-accelerator）"
fi

say ""
say "✅ 卸载完成。客户端本身没有被改动，可以正常使用。"
