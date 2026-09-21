#!/bin/zsh
# 哔哩哔哩 加速 · macOS 安装脚本
#
# 可以用两种方式运行：
#   1) 在仓库里：  ./macos/install.sh
#   2) 在安装器 App 里：由 App 自动调用（文件会放在 App 的 Resources 里）
#
# 安装内容全部在用户目录，不需要管理员密码：
#   ~/.bili-accelerator/                程序 + 日志
#   ~/Applications/哔哩哔哩 加速.app     启动器
#   ~/Library/LaunchAgents/…            开机自启的注入服务
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
if [ -f "$SCRIPT_DIR/../injector.py" ]; then
  ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
else
  ROOT_DIR="$SCRIPT_DIR"
fi

DIR="$HOME/.bili-accelerator"
# 优先装到系统级 /Applications（Finder 侧边栏的「应用程序」就在这儿），
# 没有写权限时退回用户级 ~/Applications。
if [ -w /Applications ]; then
  APPS_DIR="/Applications"
else
  APPS_DIR="$HOME/Applications"
fi
APP="$APPS_DIR/哔哩哔哩 加速.app"
OTHER_APP="$HOME/Applications/哔哩哔哩 加速.app"
AGENT="$HOME/Library/LaunchAgents/com.local.bili-injector.plist"
BILI_APP="${BILI_APP:-/Applications/哔哩哔哩.app}"
PORT="${BILI_PORT:-9223}"
PYTHON="${PYTHON:-$(command -v python3 || true)}"
WS_VERSION="1.9.2"

say() { printf '%s\n' "$*"; }
fail() { say ""; say "❌ $*"; exit 1; }

say "=================================="
say "  哔哩哔哩 加速 · 安装 (macOS)"
say "=================================="
say ""

[ -d "$BILI_APP" ] || fail "没找到客户端：$BILI_APP （请把客户端放在 /Applications 下）"
[ -n "$PYTHON" ] || fail "缺少 python3。请在终端运行：xcode-select --install"

say "① 复制程序文件…"
mkdir -p "$DIR" "$APPS_DIR" "$HOME/Library/LaunchAgents"
cp "$ROOT_DIR/injector.py" "$DIR/injector.py"
cp "$ROOT_DIR/userscript/bilibili-accelerator.user.js" "$DIR/bilibili-accelerator.user.js"
chmod 755 "$DIR/injector.py"

say "② 准备运行环境（第一次需要联网，约 10 秒）…"
if [ ! -d "$DIR/venv" ]; then
  "$PYTHON" -m venv "$DIR/venv"
fi
"$DIR/venv/bin/pip" install --quiet --upgrade pip "websocket-client==${WS_VERSION}"

say "③ 创建启动器…"
if [ -e "$APP" ]; then
  mv "$APP" "$DIR/old-launcher.$(date +%s).app"
fi
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
sed -e "s|__DIR__|$DIR|g" \
    -e "s|__BILI_APP__|$BILI_APP|g" \
    -e "s|__PORT__|$PORT|g" \
    "$ROOT_DIR/macos/launcher.sh.template" > "$APP/Contents/MacOS/launcher"
chmod 755 "$APP/Contents/MacOS/launcher"
sed -e "s|__NAME__|哔哩哔哩 加速|g" \
    "$ROOT_DIR/macos/Info.plist.template" > "$APP/Contents/Info.plist"
if [ -f "$ROOT_DIR/assets/icon.icns" ]; then
  cp "$ROOT_DIR/assets/icon.icns" "$APP/Contents/Resources/appicon.icns"
fi
/usr/bin/codesign --force --deep --sign - "$APP" >/dev/null 2>&1 || true

# 避免两个「哔哩哔哩 加速.app」同时存在造成混乱
if [ "$APPS_DIR" = "/Applications" ] && [ -f "$OTHER_APP/Contents/MacOS/launcher" ]; then
  rm -rf "$OTHER_APP"
  say "   （已清理用户级的旧副本）"
fi

say "④ 注册后台服务…"
sed -e "s|__PYTHON__|$DIR/venv/bin/python|g" \
    -e "s|__INJECTOR__|$DIR/injector.py|g" \
    -e "s|__SCRIPT__|$DIR/bilibili-accelerator.user.js|g" \
    -e "s|__PORT__|$PORT|g" \
    -e "s|__LOG__|$DIR/injector.log|g" \
    -e "s|__ERRLOG__|$DIR/injector.err.log|g" \
    "$ROOT_DIR/macos/com.local.bili-injector.plist.template" > "$AGENT"

UID_NUM="$(id -u)"
launchctl bootout "gui/$UID_NUM/com.local.bili-injector" 2>/dev/null || true
sleep 1
launchctl bootstrap "gui/$UID_NUM" "$AGENT" 2>/dev/null || true
launchctl enable "gui/$UID_NUM/com.local.bili-injector" 2>/dev/null || true
launchctl kickstart -k "gui/$UID_NUM/com.local.bili-injector" >/dev/null 2>&1 || true

say ""
say "✅ 安装完成！接下来这样做："
say ""
say "   1) 把「哔哩哔哩 加速」图标拖到 Dock（图钉）上"
say "      $APP"
say "   2) 以后都用它启动客户端（第一次会自动重启一次客户端）"
say "   3) 客户端里出现小闪电 ⚡ 就说明成功了"
say ""
say "   日志：$DIR/injector.log"
say "   卸载：双击「卸载」或运行 ./macos/uninstall.sh"
